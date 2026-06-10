-- ============================================================================
-- REACTIVE SCRAMBLE v2.0  (414th JFG — GCI dormant interceptors)
-- ============================================================================
--
-- Turns hand-placed RED interceptor groups into cold-ramp alert fighters that
-- sit UNCONTROLLED on the ground doing NOTHING until a Blue aircraft is detected
-- by the RED radar network, then wakes the nearest one and scrambles it to
-- intercept.
--
-- ── HOW TO USE IN THE MISSION EDITOR ────────────────────────────────────────
--   1. Place a RED fighter/interceptor group at its airbase and put the word
--      "Scramble" in its group name, e.g. "Kuweires Scramble" or "Jirah #1 Scramble".
--   2. Tick the group's "Uncontrolled" box in the ME so it starts cold on the
--      ramp (engines off, no route). A normal cold-start parking spot is enough.
--   3. Load this script via DO SCRIPT FILE at mission start (AFTER Moose.lua).
--
-- Only air-to-air-capable aircraft (Fighters / Interceptors) are eligible — a
-- "Scramble"-named bomber or helo is ignored.
--
-- On a Blue threat within CFG_engageRadius of any RED radar, the nearest
-- available group is woken (StartUncontrolled → cold start, taxi, takeoff) and
-- tasked to hunt air contacts. Nothing flies until a threat appears.
--
-- ── API NOTES ───────────────────────────────────────────────────────────────
--  GROUP:StartUncontrolled() — issues {id='Start'} to a parked uncontrolled group
--  ctrl:setTask()            — replaces the entire task so the group hunts air
--  EngageTargets             — correct DCS task id for air intercept
-- ============================================================================

local CFG_scanInterval  = 15      -- seconds between threat scans
local CFG_engageRadius  = 95000   -- metres (~51 nm)
local CFG_reengageDelay = 180     -- seconds before a busy group re-qualifies
local CFG_spawnDelay    = 1.0     -- seconds between Start command and setTask

local CFG_matchStrings   = { "Scramble" }
local CFG_excludeStrings = { "SEAD" }
-- DCS unit attributes that mark an aircraft as air-to-air capable.
local CFG_aaAttributes   = { "Fighters", "Interceptors" }

local _groups = {}   -- name -> record

-- ── UTILITIES ────────────────────────────────────────────────────────────────

local function log(msg) BASE:E("=== SCRAMBLE: " .. tostring(msg)) end

local function dist3D(p1, p2)
    local dx, dy, dz = p1.x-p2.x, (p1.y or 0)-(p2.y or 0), p1.z-p2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function nameMatches(name)
    for _, ex in ipairs(CFG_excludeStrings) do
        if string.find(name, ex) then return false end
    end
    for _, m in ipairs(CFG_matchStrings) do
        if string.find(name, m) then return true end
    end
    return false
end

-- True if the group's lead unit is an air-to-air aircraft.
local function isAirToAir(dcsGroup)
    local units = dcsGroup:getUnits()
    local u = units and units[1]
    if not (u and u:isExist()) then return false end
    for _, attr in ipairs(CFG_aaAttributes) do
        if u:hasAttribute(attr) then return true end
    end
    return false
end

-- ── TASK APPLICATION ─────────────────────────────────────────────────────────

local function taskIntercept(rec)
    local mg = GROUP:FindByName(rec.name)
    if not mg or not mg:IsAlive() then return end
    rec.group = mg
    mg:OptionROEWeaponFree()
    mg:OptionROTEvadeFire()

    local ctrl = mg:GetController()
    if ctrl then
        ctrl:setTask({
            id     = "EngageTargets",
            params = {
                targetTypes = { "Air" },
                maxDist     = CFG_engageRadius,
                priority    = 0,
            },
        })
    end
end

-- Wake a dormant uncontrolled group, then task it after a short delay so DCS
-- finishes the Start command before setTask fires.
local function spawnAndIntercept(rec)
    local mg = GROUP:FindByName(rec.name)
    if not mg then
        log("ERROR: cannot find group: " .. rec.name)
        return
    end
    rec.group   = mg
    rec.spawned = true
    mg:StartUncontrolled()
    log("Waking dormant group: " .. rec.name)
    timer.scheduleFunction(function()
        taskIntercept(rec)
    end, nil, timer.getTime() + CFG_spawnDelay)
end

-- ── REGISTRATION ─────────────────────────────────────────────────────────────
-- Scan all RED airplane groups for "Scramble"-named, A/A-capable interceptors.

timer.scheduleFunction(function()
    for _, g in ipairs(coalition.getGroups(coalition.side.RED, Group.Category.AIRPLANE) or {}) do
        if g and g:isExist() then
            local name = g:getName()
            if name and not _groups[name] and nameMatches(name) and isAirToAir(g) then
                _groups[name] = {
                    name       = name,
                    group      = GROUP:FindByName(name),
                    busy       = false,
                    lastTasked = 0,
                    spawned    = false,
                }
                log("Registered dormant interceptor: " .. name)
            end
        end
    end
end, nil, timer.getTime() + 0.1)

-- ── THREAT SCAN ──────────────────────────────────────────────────────────────

local function getRedRadarPositions()
    local pts = {}
    for _, cat in ipairs({ Group.Category.GROUND, Group.Category.SHIP }) do
        for _, g in ipairs(coalition.getGroups(coalition.side.RED, cat) or {}) do
            if g and g:isExist() then
                for _, u in ipairs(g:getUnits() or {}) do
                    if u and u:isExist() then
                        local d = u:getDesc()
                        if d and d.sensor and d.sensor.radar then
                            pts[#pts + 1] = u:getPoint()
                            break
                        end
                    end
                end
            end
        end
    end
    return pts
end

local function detectBlueThreats(radarPts)
    local threats, seen = {}, {}
    for _, g in ipairs(coalition.getGroups(coalition.side.BLUE, Group.Category.AIRPLANE) or {}) do
        if g and g:isExist() and not seen[g:getName()] then
            local units = g:getUnits()
            local u = units and units[1]
            if u and u:isExist() then
                local pos = u:getPoint()
                for _, rp in ipairs(radarPts) do
                    if dist3D(pos, rp) <= CFG_engageRadius then
                        threats[#threats + 1] = { group = g, pos = pos }
                        seen[g:getName()] = true
                        break
                    end
                end
            end
        end
    end
    return threats
end

-- Nearest available group to the threat. Dormant groups report their parked
-- position fine, so distance ranking works before they spawn.
local function selectGroup(threatPos)
    local now = timer.getTime()
    local best, bestDist = nil, math.huge
    for _, rec in pairs(_groups) do
        local available = not rec.busy or (now - rec.lastTasked) > CFG_reengageDelay
        local mg = rec.group or GROUP:FindByName(rec.name)
        if available and mg and mg:IsAlive() then
            rec.group = mg
            local u1 = mg:GetUnit(1)
            if u1 and u1:IsAlive() then
                local d = dist3D(u1:GetVec3(), threatPos)
                if d < bestDist then
                    best, bestDist = rec, d
                end
            end
        end
    end
    return best
end

SCHEDULER:New(nil, function()
    local radars = getRedRadarPositions()
    if #radars == 0 then return end

    local threats = detectBlueThreats(radars)

    if #threats == 0 then
        local now = timer.getTime()
        for _, rec in pairs(_groups) do
            if rec.busy and (now - rec.lastTasked) > CFG_reengageDelay then
                rec.busy = false
                log("Released: " .. rec.name)
            end
        end
        return
    end

    for _, threat in ipairs(threats) do
        local rec = selectGroup(threat.pos)
        if rec then
            local now = timer.getTime()
            if not rec.busy or (now - rec.lastTasked) > CFG_reengageDelay then
                rec.busy       = true
                rec.lastTasked = now
                if rec.spawned then
                    taskIntercept(rec)
                else
                    spawnAndIntercept(rec)
                end
                log("Scramble: " .. rec.name .. " -> " .. threat.group:getName())
                MESSAGE:New("SCRAMBLE: interceptors launching!", 12):ToAll()
            end
        end
    end
end, {}, 10, CFG_scanInterval)

-- ── STARTUP REPORT ───────────────────────────────────────────────────────────

timer.scheduleFunction(function()
    local n = 0
    for _ in pairs(_groups) do n = n + 1 end
    log(string.format("ONLINE — %d dormant interceptor group(s)", n))
    MESSAGE:New(string.format(
        "REACTIVE SCRAMBLE ONLINE: %d dormant interceptor group(s)", n), 12):ToAll()
end, nil, timer.getTime() + 2)
