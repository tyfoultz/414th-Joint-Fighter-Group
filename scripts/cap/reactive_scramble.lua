-- ============================================================================
-- REACTIVE SCRAMBLE v1.1  (414th JFG — GCI dormant interceptors)
-- ============================================================================
--
-- Turns hand-placed RED interceptor groups into dormant alert fighters that sit
-- on the ground / in a holding orbit doing NOTHING until a Blue aircraft is
-- detected by the RED radar network, then scramble to intercept.
--
-- ── HOW TO USE IN THE MISSION EDITOR ────────────────────────────────────────
--   1. Place a RED aircraft group and put the word "Scramble" in its group name,
--      e.g. "Kuweires Scramble" or "Jirah Scramble #1".
--   2. Give the group a CAP task with a holding orbit near its airbase, ROE
--      Weapon Hold (this script also forces Weapon Hold at registration).
--   3. Load this script via DO SCRIPT FILE at mission start (AFTER Moose.lua).
--
-- The text before "Scramble" in the group name is treated as the airbase label
-- and is only used for messages / zone lookup.
--
-- ── TWO-MODE OPERATION ──────────────────────────────────────────────────────
--
--  ZONE MODE  — a trigger zone named "SCRAMBLE_<AirbaseName>" exists in the ME
--    (e.g. zone "SCRAMBLE_Kuweires" for group "Kuweires Scramble"):
--    The group holds until a Blue airplane enters its zone, then scrambles.
--
--  GLOBAL MODE — no matching zone:
--    Activated immediately at registration; hunts any Blue contact within
--    CFG_engageRadius of any RED radar.
--
-- ── API NOTES ───────────────────────────────────────────────────────────────
--  ctrl:setTask()  — replaces the entire task/route (used here, not pushTask)
--  ctrl:pushTask() — only adds on top; underlying waypoints survive underneath
--  EngageTargets   — correct DCS task id for air intercept
-- ============================================================================

local CFG_scanInterval  = 15      -- seconds between threat scans
local CFG_engageRadius  = 95000   -- metres (~51 nm)
local CFG_reengageDelay = 180     -- seconds before a busy group re-qualifies

local CFG_matchStrings   = { "Scramble" }
local CFG_excludeStrings = { "SEAD" }

local _groups    = {}   -- name -> record
local _processed = {}   -- dedup across startup scan + BIRTH events

-- ── UTILITIES ────────────────────────────────────────────────────────────────

local function log(msg) BASE:E("=== SCRAMBLE: " .. tostring(msg)) end

local function dist3D(p1, p2)
    local dx, dy, dz = p1.x-p2.x, (p1.y or 0)-(p2.y or 0), p1.z-p2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- "Kuweires Scramble #1" → "Kuweires"
local function extractAirbase(groupName)
    for _, task in ipairs(CFG_matchStrings) do
        local ab = groupName:match("^(.-)%s+" .. task)
        if ab and #ab > 0 then return ab end
    end
    return nil
end

local function getCoverageZone(airbaseName)
    if not airbaseName then return nil end
    local manual = "SCRAMBLE_" .. airbaseName
    if trigger.misc.getZone(manual) then return manual end
    return nil
end

local function posInZone(pos, zoneName)
    local z = trigger.misc.getZone(zoneName)
    if not z then return false end
    local dx = pos.x - z.point.x
    local dz = pos.z - z.point.z
    return math.sqrt(dx*dx + dz*dz) <= z.radius
end

local function shouldHijack(name)
    for _, ex in ipairs(CFG_excludeStrings) do
        if string.find(name, ex) then return false end
    end
    for _, m in ipairs(CFG_matchStrings) do
        if string.find(name, m) then return true end
    end
    return false
end

-- ── TASK APPLICATION ─────────────────────────────────────────────────────────

local function activateIntercept(rec)
    rec.group:OptionROEWeaponFree()
    rec.group:OptionReactionOnThreatEvadeFireAndBoost()

    local ctrl = rec.group:GetController()
    if ctrl then
        -- setTask fully replaces the current task/route so the group stops
        -- orbiting and immediately hunts Blue air contacts within CFG_engageRadius.
        -- pushTask would only layer on top, leaving the CAP orbit underneath.
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

-- ── GROUP REGISTRATION ───────────────────────────────────────────────────────

local function registerGroup(mooseGroup)
    if not mooseGroup or not mooseGroup:IsAlive() then return end
    local name = mooseGroup:GetName()
    if _processed[name] then return end
    if not shouldHijack(name) then return end

    _processed[name] = true

    local airbase  = extractAirbase(name)
    local zone     = getCoverageZone(airbase)
    local zoneMode = (zone ~= nil)

    local rec = {
        name       = name,
        group      = mooseGroup,
        airbase    = airbase or name,
        zone       = zone,
        zoneMode   = zoneMode,
        busy       = false,
        lastTasked = 0,
    }
    _groups[name] = rec

    if zoneMode then
        rec.group:OptionROEWeaponHold()
        rec.group:OptionReactionOnThreatEvadeFireAndBoost()
        log("Zone guard: " .. name .. " [zone: " .. zone .. "]")
        MESSAGE:New("GCI: " .. rec.airbase .. " on guard — zone: " .. zone, 8):ToAll()
    else
        activateIntercept(rec)
        log("Global intercept: " .. name)
        MESSAGE:New("GCI: " .. rec.airbase .. " active (global)", 8):ToAll()
    end
end

-- ── REGISTRATION: PASS 1 (groups active at T=0) ──────────────────────────────

local _startSet = SET_GROUP:New():FilterCoalitions("red"):FilterStart()
_startSet:ForEachGroup(registerGroup)

-- ── REGISTRATION: PASS 2 (late-activated groups) ─────────────────────────────
-- Groups activated via triggers after T=0 fire a BIRTH event.
-- 0.1s delay lets MOOSE register the group before GROUP:FindByName().

local _birthHandler = {}
function _birthHandler:onEvent(event)
    if event.id ~= world.event.S_EVENT_BIRTH then return end
    local u = event.initiator
    if not u then return end
    if not u.getCoalition or u:getCoalition() ~= coalition.side.RED then return end
    timer.scheduleFunction(function()
        if not u or not u.isExist or not u:isExist() then return end
        local dcsGrp = u.getGroup and u:getGroup()
        if not dcsGrp then return end
        local mg = GROUP:FindByName(dcsGrp:getName())
        if mg then registerGroup(mg) end
    end, nil, timer.getTime() + 0.1)
end
world.addEventHandler(_birthHandler)

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

local function selectGroup(threatPos)
    local now = timer.getTime()
    local bestZone, bestZoneDist   = nil, math.huge
    local bestGlobal, bestGlobalDist = nil, math.huge

    for _, rec in pairs(_groups) do
        local available = not rec.busy or (now - rec.lastTasked) > CFG_reengageDelay
        if available and rec.group:IsAlive() then
            local u1 = rec.group:GetUnit(1)
            if u1 and u1:IsAlive() then
                local d = dist3D(u1:GetVec3(), threatPos)
                if rec.zoneMode then
                    if posInZone(threatPos, rec.zone) and d < bestZoneDist then
                        bestZone, bestZoneDist = rec, d
                    end
                else
                    if d < bestGlobalDist then
                        bestGlobal, bestGlobalDist = rec, d
                    end
                end
            end
        end
    end
    return bestZone or bestGlobal
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
                if rec.zoneMode then
                    activateIntercept(rec)
                    log("Zone scramble: " .. rec.name .. " -> " .. threat.group:getName())
                    MESSAGE:New("SCRAMBLE: " .. rec.airbase .. " — threat in zone!", 12):ToAll()
                else
                    log("Global vector: " .. rec.name .. " -> " .. threat.group:getName())
                end
            end
        end
    end
end, {}, 10, CFG_scanInterval)

-- ── STARTUP REPORT ───────────────────────────────────────────────────────────

timer.scheduleFunction(function()
    local nZone, nGlobal = 0, 0
    for _, rec in pairs(_groups) do
        if rec.zoneMode then nZone = nZone + 1 else nGlobal = nGlobal + 1 end
    end
    local total = nZone + nGlobal
    log(string.format("ONLINE — %d groups (%d zone, %d global)", total, nZone, nGlobal))
    MESSAGE:New(string.format(
        "REACTIVE SCRAMBLE ONLINE: %d intercept group(s) (%d zone, %d global)",
        total, nZone, nGlobal), 12):ToAll()
end, nil, timer.getTime() + 2)
