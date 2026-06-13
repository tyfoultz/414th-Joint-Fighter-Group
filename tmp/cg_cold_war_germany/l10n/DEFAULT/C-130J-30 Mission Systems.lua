--[[
C-130J-30 Mission Systems Script for DCS World.
Combines EC-130H Compass Call electronic warfare and RC-130H Rivet Joint ISR capabilities.

EW:  Area and directional jamming, spot SAM suppression, missile spoofing,
     overheat energy management, pod loadout selection, radar-type jam difficulty.
ISR: Altitude-gated radar detection, up to 3 simultaneous ELINT tracks with progressive
     location refinement, displacement alerting, high-priority threat alerts,
     F10 map marks, Bullseye reporting, ELINT Lock coalition alert.
COORD: EW/ISR handoff brief deliverable to any selected friendly group.

Original EW script by Timberwolf, C-130 conversion by claude and Flash.
ISR conversion and merge by bradyccox.
--]]

-- ===========================================================================
-- CONFIGURATION
-- Adjust these values to tune difficulty and behaviour.
-- No other part of the script needs to be touched.
-- ===========================================================================

-- ── EW — energy ────────────────────────────────────────────────────────────
local CFG_regenPerSec      = 5      -- capacity regen per second when idle
local CFG_drainAreaPerSec  = 3      -- capacity drain per second: area jamming
local CFG_drainDirPerSec   = 1      -- capacity drain per second: directional jamming
local CFG_spotDrainPerSec  = 5      -- capacity drain per second: spot jamming
local CFG_overheatResetCap = 450    -- minimum capacity required to clear an overheat
local CFG_jamMaxRange      = 75000  -- maximum offensive jam range in metres (~40nm)
local CFG_lowCapWarnPct    = 0.20   -- warn crew when capacity falls below this fraction of max (0.20 = 20%)

-- ── EW — missile spoofing ──────────────────────────────────────────────────
-- One roll per second. Only the tightest matching zone fires (no stacking).
-- pk = percent chance (0-100) of spoofing the missile that tick.
local CFG_spoofZones = {
    { dist = 37000, pk = 25 },  -- ~20nm: jamming begins degrading guidance
    { dist = 27800, pk = 40 },  -- ~15nm: increasing effect at closer range
    { dist = 18500, pk = 55 },  -- ~10nm: meaningful but not reliable
    { dist = 11100, pk = 70 },  -- ~6nm:  good chance of a spoof
    { dist = 5556,  pk = 85 },  -- ~3nm:  high probability, still not guaranteed
}

-- ── ISR ────────────────────────────────────────────────────────────────────
local CFG_sweepInterval         = 5    -- seconds between radar sweeps
local CFG_markRefreshInterval   = 15   -- seconds between F10 map mark updates
local CFG_trackMinTime          = 60   -- fastest ELINT lock time in seconds (close range)
local CFG_trackMaxTime          = 360  -- slowest ELINT lock time in seconds (max range)
local CFG_displacementThreshold = 500  -- metres an emitter must move to trigger displacement alert
local CFG_maxTracks             = 3    -- maximum simultaneous ELINT tracks

-- ── Messages ───────────────────────────────────────────────────────────────
local CFG_msgGap            = 10   -- seconds between message queue flushes
local CFG_msgDur            = 15   -- seconds a flushed message stays on screen
local CFG_ewStatusInterval  = 30   -- minimum seconds between EW status line updates
local CFG_isrStatusInterval = 30   -- minimum seconds between ISR status line updates

-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Shared utility
-- ---------------------------------------------------------------------------

local function getHeading(unit)
    if not unit or not unit.isExist or not unit:isExist() then return 0 end
    local pos = unit:getPosition()
    if not pos or not pos.x then return 0 end
    local hdg = math.atan2(pos.x.z, pos.x.x)
    if hdg < 0 then hdg = hdg + 2 * math.pi end
    return hdg
end

local function get3DDist(p1, p2)
    local dx = (p1.x or 0) - (p2.x or 0)
    local dy = (p1.y or 0) - (p2.y or 0)
    local dz = (p1.z or 0) - (p2.z or 0)
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function getBearing(from, to)
    local dx = to.x - from.x
    local dz = to.z - from.z
    local b  = math.deg(math.atan2(dz, dx))
    if b < 0 then b = b + 360 end
    return math.floor(b + 0.5)
end

local function getClockBearing(fromUnit, targetPos)
    if not fromUnit or not fromUnit:isExist() then return "?" end
    local jp  = fromUnit:getPosition().p
    local hdg = getHeading(fromUnit)
    local dx  = targetPos.x - jp.x
    local dz  = targetPos.z - jp.z
    local ang = math.atan2(dz, dx)
    local rel = ang - hdg
    if rel < 0 then rel = rel + 2 * math.pi end
    local hours = math.floor((rel / (2 * math.pi)) * 12 + 0.5)
    if hours == 0 then hours = 12 end
    return tostring(hours) .. " o'clock"
end

local nonEmitterAttributes = { "AAA", "Armored vehicles", "APC", "IFV", "Tanks", "Infantry" }

local function isRadarUnit(u)
    if not u or not u:isExist() then return false end
    for _, attr in ipairs(nonEmitterAttributes) do
        if u:hasAttribute(attr) then return false end
    end
    local d = u:getDesc()
    if not d then return false end
    if d.sensor and d.sensor.radar then return true end
    return u:hasAttribute("SAM TR") or u:hasAttribute("SAM SR") or u:hasAttribute("SAM STR")
end

local function getNatoName(unit)
    local t = unit:getTypeName()
    local m = {
        ["S-300PS 40B6M tr"]    = "SA-10", ["S-300PS 40B6MD sr"]    = "SA-10",
        ["S-300PS 64H6E sr"]    = "SA-10", ["S-300PS 5P85C ln"]     = "SA-10",
        ["S-300PS 5P85D ln"]    = "SA-10", ["S-300PS 54K6 cp"]      = "SA-10",
        ["SA-11 Buk SR 9S18M1"] = "SA-11", ["SA-11 Buk LN 9A310M1"] = "SA-11",
        ["SA-17 Buk M1-2 LN"]  = "SA-17", ["SA-15 Tor 9A331"]      = "SA-15",
        ["SA-8 Osa 9A33 ln"]   = "SA-8",  ["Kub 1S91 str"]         = "SA-6",
        ["SNR_75V"]             = "SA-2",  ["p-19 s-125 sr"]        = "SA-3",
        ["Dog Ear radar"]       = "Dog Ear",
        ["1L13 EWR"]            = "EWR",   ["55G6 EWR"]             = "EWR",
        ["Patriot str"]         = "Patriot",
        ["Hawk tr"]             = "Hawk TR", ["Hawk sr"]             = "Hawk SR",
        ["Hawk cwar"]           = "Hawk CWAR",
        ["HQ-7_STR_SP"]         = "HQ-7",  ["HQ-7_SR"]             = "HQ-7 SR",
        ["Roland ADS"]          = "Roland", ["Roland Radar"]        = "Roland",
        ["ZSU-23-4 Shilka"]     = "ZSU-23",
    }
    return m[t] or t:gsub("^CHAP_", "")
end

local function bullseyeStr(pos)
    local be = coalition.getMainRefPoint(coalition.side.BLUE)
    if not be then return "No bullseye" end
    local brg  = getBearing(be, pos)
    local dist = math.floor(get3DDist(be, pos) / 1852 + 0.5)
    return string.format("BULLSEYE %03d/%d", brg, dist)
end

-- ---------------------------------------------------------------------------
-- Eligible aircraft
-- ---------------------------------------------------------------------------

local eligibleTypeNames = { ["C-130J-30"] = true }

-- ---------------------------------------------------------------------------
-- Shared unit registry
-- ---------------------------------------------------------------------------

local unitNames    = {}   -- list of registered unit names
local groupIDs     = {}   -- name -> groupID
local rootMenus    = {}   -- name -> root menu handle
local ewMenus      = {}   -- name -> EW submenu handle
local isrMenus     = {}   -- name -> ISR submenu handle
local coordMenus   = {}   -- name -> Crew Coordination submenu handle
local _staticSlots = {}   -- set of unit names that existed at mission start

-- ---------------------------------------------------------------------------
-- EW state
-- ---------------------------------------------------------------------------

local ewSettings         = {}
local spotTargetMenus    = {}
local spotTargetCmds     = {}
local emitterCapacity    = {}
local maxEmitterCapacity = {}
local overheated         = {}
local loadoutConfigured   = {}
local selectedPods        = {}
local selectedLoadoutName = {}   -- name -> active preset label (e.g. "Full Spectrum")
local loadoutBands        = {}   -- name -> { hi = bool, lo = bool }
local podEnabled          = {}
local trackedMissiles    = {}
local missileUID         = 1
local suppressedSAMs     = {}
local _lastJamAttempt    = {}   -- gname -> { time, cooldown }
local _lowCapWarned      = {}   -- name -> bool, true once low-cap alert has fired this drain cycle
local autoTrackEnabled   = {}   -- name -> bool, auto-track high-priority threats when slot available

-- (EW scalars defined in CONFIG block above)

-- Jam difficulty multiplier by NATO name.
-- Represents the effective probability reduction from ECCM, frequency agility,
-- and radar generation.  1.0 = no penalty, 0.0 = totally unjammable.
-- Final jam probability = base_prob_by_distance * jamDifficulty[nato].
-- Systems not listed default to 1.0 (full probability).
local jamDifficulty = {

    -- ── Tier 1: Modern long-range / phased-array (very high ECCM) ──────────
    -- SA-10 / S-300PS: frequency agile, advanced ECCM, designed to defeat
    --   standoff jamming.  Higher probability but short jam window (30s) —
    --   its ECCM actively burns through the jamming signal.
    ["SA-10"]    = 0.62,

    -- Patriot PAC-2/3: phased-array, highly frequency agile, excellent ECCM.
    --   Slightly more permissive than SA-10; 35s jam window.
    ["Patriot"]  = 0.62,

    -- ── Tier 2: Modern medium-range (capable ECCM) ─────────────────────────
    -- SA-11 / Buk M1: semi-active radar, some frequency agility, reasonable ECCM.
    --   Jammable but re-acquires in 40s.
    ["SA-11"]    = 0.74,

    -- SA-15 / Tor M1: autonomous short-range, frequency agile, good ECCM.
    --   Smaller footprint makes it harder to spot and jam simultaneously; 45s window.
    ["SA-15"]    = 0.76,

    -- NASAMS: modern NATO system, frequency agile, network-centric.
    --   Rarely seen in DCS Red order of battle but included for completeness; 40s window.
    ["NASAMS"]   = 0.68,

    -- ── Tier 3: Semi-modern medium-range (partial ECCM) ───────────────────
    -- Hawk TR (tracking radar): narrowband CW, moderate ECCM.
    --   Lo-band pods have a harder time; hi-band more effective.
    ["Hawk TR"]  = 0.70,

    -- Hawk CWAR (continuous-wave acquisition radar): older design, lower ECCM.
    ["Hawk CWAR"] = 0.76,

    -- Hawk SR (search radar): lower frequency, moderate jam resistance.
    ["Hawk SR"]  = 0.80,

    -- ── Tier 4: Cold-War era mobile systems (limited ECCM) ─────────────────
    -- SA-19 / 2S6 Tunguska: gun+missile combo, radar-guided guns,
    --   limited ECCM but fast engagement radar. Harder to break than SA-6.
    ["SA-19"]    = 0.76,

    -- SA-6 / Kub: continuous-wave illuminator, older ECCM, well-studied.
    ["SA-6"]     = 0.82,

    -- SA-8 / Osa: self-contained, J-band, aging ECCM.
    ["SA-8"]     = 0.87,

    -- Roland: French/German short-range, K-band, moderate ECCM for its era.
    ["Roland"]   = 0.88,

    -- HQ-7: Chinese Crotale derivative, similar ECM resistance to Roland.
    ["HQ-7"]     = 0.86,

    -- ── Tier 5: Legacy / early Cold-War (poor ECCM) ────────────────────────
    -- SA-3 / S-125: low-frequency E-band, old but low-band pods less effective.
    --   Notoriously difficult to jam with hi-band pods alone.
    ["SA-3"]     = 0.88,

    -- SA-2 / S-75: very old G/H-band, minimal ECCM, easily defeated.
    ["SA-2"]     = 0.93,

    -- ZSU-23 / Shilka: gun radar, simple J-band fire-control, minimal ECCM.
    ["ZSU-23"]   = 0.93,

    -- ── Tier 6: Radars / EWR (minimal jam resistance) ──────────────────────
    -- Dog Ear (P-19): simple VHF acquisition radar, no meaningful ECCM.
    ["Dog Ear"]  = 0.96,

    -- Generic early-warning radars: designed to detect, not to survive jamming.
    ["EWR"]      = 0.98,
}

-- How long (seconds) a successful jam holds before the next dice roll.
-- Modern systems with active ECCM burn through jamming faster.
-- Systems not listed use the default of 60s.
local jamDuration = {
    ["SA-10"]   = 30,   -- actively frequency-hops to break jamming
    ["Patriot"] = 35,   -- phased array re-acquires quickly
    ["NASAMS"]  = 40,   -- net-centric fallback shortens window
    ["SA-11"]   = 40,   -- semi-modern ECCM
    ["SA-15"]   = 45,   -- fast autonomous re-acquisition
}

-- Frequency band classification.
-- Lo-band (L/S/C-band) pods target long-range acquisition and search radars.
-- Hi-band (X/K-band) pods target tracking radars and terminal guidance systems.
-- Systems not listed here are treated as hi-band (tracking/short-range).
local loBandSystems = {
    ["SA-10"]    = true,   -- S-band acquisition / Flap Lid
    ["SA-2"]     = true,   -- G/H-band early Cold-War
    ["SA-3"]     = true,   -- E-band low-alt
    ["SA-6"]     = true,   -- C-band CW illuminator
    ["Hawk SR"]  = true,   -- L-band search radar
    ["Hawk CWAR"]= true,   -- S-band CWAR
    ["Dog Ear"]  = true,   -- VHF/UHF acquisition
    ["EWR"]      = true,   -- early-warning / long-range surveillance
}

-- ---------------------------------------------------------------------------
-- ISR state
-- ---------------------------------------------------------------------------

local trackMenus         = {}   -- name -> Track Emitter submenu
local trackCmds          = {}   -- name -> list of track commands
local stopTrackMenus     = {}   -- name -> Stop Track submenu
local stopTrackCmds      = {}   -- name -> list of stop-track commands
local coordCmds          = {}   -- name -> list of coord brief commands
local knownEmitters      = {}   -- name -> { gname = { pos, seenAt } }
local markedTarget       = {}   -- name -> { gname = track }  (multi-track)
local lockedMarkIDs      = {}   -- name -> list of permanently kept markIDs
local _lastSweep         = {}

-- (ISR scalars defined in CONFIG block above)

-- High-priority NATO names that trigger an immediate crew-only threat alert
-- on first detection (bypasses the message queue).
local highPriorityThreats = {
    ["SA-10"]   = true,   -- S-300: long-range, aircraft-killing threat
    ["SA-11"]   = true,   -- Buk M1: medium-range, high-speed engagement
    ["SA-15"]   = true,   -- Tor M1: point-defense, very fast reaction
    ["Patriot"] = true,   -- PAC-2/3: long-range, highly lethal
    ["NASAMS"]  = true,   -- modern NATO net-centric system
}

local markIDCounter = 3000
local function nextMarkID()
    markIDCounter = markIDCounter + 1
    return markIDCounter
end

local function countTracks(name)
    local n = 0
    for _ in pairs(markedTarget[name] or {}) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Message queue
-- ---------------------------------------------------------------------------

-- (message queue scalars defined in CONFIG block above)

local _msgQueue          = {}
local _flushTimer        = {}
local _evtSeenInSlot     = {}
local _lastEWStatusTime  = {}
local _lastISRStatusTime = {}

local function _nextAligned(now, gap)
    return (math.floor(now / gap) + 1) * gap
end

local function _ensureQueue(name)
    local q = _msgQueue[name]
    if not q then
        q = { ewStatus = nil, isrStatus = nil, events = {},
              target = _nextAligned(timer.getTime(), CFG_msgGap) }
        _msgQueue[name] = q
    elseif not q.target then
        q.target = _nextAligned(timer.getTime(), CFG_msgGap)
    end
    return q
end

local function _scheduleFlush(name)
    if _flushTimer[name] then return end
    local q = _msgQueue[name]; if not q then return end
    _flushTimer[name] = timer.scheduleFunction(function()
        local cur = _msgQueue[name]; _flushTimer[name] = nil
        if cur then
            local lines = {}
            if cur.ewStatus  and #cur.ewStatus  > 0 then lines[#lines+1] = cur.ewStatus  end
            if cur.isrStatus and #cur.isrStatus > 0 then lines[#lines+1] = cur.isrStatus end
            if cur.events    and #cur.events    > 0 then lines[#lines+1] = table.concat(cur.events, " | ") end
            if #lines > 0 then
                local gid = groupIDs[name]
                if gid then trigger.action.outTextForGroup(gid, table.concat(lines, "\n"), CFG_msgDur) end
            end
        end
        _msgQueue[name]      = nil
        _evtSeenInSlot[name] = nil
        return nil
    end, {}, q.target)
end

local function emitEWStatus(name, msg)
    if not groupIDs[name] then return end
    local q = _ensureQueue(name); q.ewStatus = msg; _scheduleFlush(name)
end

local function emitISRStatus(name, msg)
    if not groupIDs[name] then return end
    local q = _ensureQueue(name); q.isrStatus = msg; _scheduleFlush(name)
end

local function emitEvent(name, msg)
    if not groupIDs[name] then return end
    local q    = _ensureQueue(name)
    local slot = q.target or 0
    local seen = _evtSeenInSlot[name]
    if not seen or seen.slot ~= slot then
        seen = { slot = slot, set = {} }; _evtSeenInSlot[name] = seen
    end
    if not seen.set[msg] then
        seen.set[msg] = true; table.insert(q.events, msg)
    end
    _scheduleFlush(name)
end

-- Immediate display bypassing the queue (for threat alerts)
local function emitImmediate(name, msg)
    local gid = groupIDs[name]; if not gid then return end
    trigger.action.outTextForGroup(gid, msg, CFG_msgDur)
end

-- ---------------------------------------------------------------------------
-- EW helpers
-- ---------------------------------------------------------------------------

local function formatPodsText(name)
    return selectedLoadoutName[name] or "None"
end

local function capacityFromPreset(n99, n249)
    if (n249 or 0) >= 2 and (n99 or 0) >= 1 then return 5500 end
    if (n249 or 0) >= 2 then return 4500 end
    if (n99 or 0) >= 3  then return 2500 end
    if (n99 or 0) >= 2  then return 1600 end
    if (n99 or 0) >= 1  then return 800  end
    return 0
end

local function closeAllEW(name, silent)
    ewSettings[name] = ewSettings[name] or {}
    ewSettings[name].defensive  = false
    ewSettings[name].offensive  = false
    ewSettings[name].defDir     = nil
    ewSettings[name].offDir     = nil
    ewSettings[name].spotTarget = nil
    if not silent then emitEvent(name, "EW disabled: all modes off") end
end

local function inSector(jammerUnit, targetPos, sector)
    if not jammerUnit or not jammerUnit:isExist() then return false end
    local jp  = jammerUnit:getPosition().p
    local hdg = math.deg(getHeading(jammerUnit))
    local ang = math.deg(math.atan2(targetPos.z - jp.z, targetPos.x - jp.x))
    local rel = (ang - hdg) % 360
    if sector == "front" then return rel >= 315 or rel <= 45
    elseif sector == "right" then return rel > 45  and rel <= 135
    elseif sector == "rear"  then return rel > 135 and rel <= 225
    elseif sector == "left"  then return rel > 225 and rel <  315 end
    return false
end

local function computeJamAttemptCooldown(distMeters)
    local frac = math.min(distMeters / CFG_jamMaxRange, 1.0)
    return 1 + frac * 29
end

local function computeModeAndDrainPerSec(name)
    local s = ewSettings[name] or {}
    local drain, modeOn = 0, {}
    if s.defensive  then drain = drain + CFG_drainAreaPerSec; modeOn[#modeOn+1] = "Area Defense"               end
    if s.offensive  then drain = drain + CFG_drainAreaPerSec; modeOn[#modeOn+1] = "Area Offense"               end
    if s.defDir     then drain = drain + CFG_drainDirPerSec;  modeOn[#modeOn+1] = "Dir Defense:" .. s.defDir   end
    if s.offDir     then drain = drain + CFG_drainDirPerSec;  modeOn[#modeOn+1] = "Dir Offense:" .. s.offDir   end
    if s.spotTarget then drain = drain + CFG_spotDrainPerSec; modeOn[#modeOn+1] = "Spot"                       end
    return (#modeOn > 0) and table.concat(modeOn, ", ") or "Off", drain
end

-- ---------------------------------------------------------------------------
-- EW status line
-- ---------------------------------------------------------------------------

local function ewStatusBrief(name)
    if not loadoutConfigured[name]
    or not emitterCapacity[name]
    or (maxEmitterCapacity[name] or 0) <= 0
    or podEnabled[name] == false then return end

    local now = timer.getTime()
    if _lastEWStatusTime[name] and (now - _lastEWStatusTime[name]) < CFG_ewStatusInterval then return end
    _lastEWStatusTime[name] = now

    local u = Unit.getByName(name); if not u or not u:isExist() then return end

    local cap    = emitterCapacity[name] or 0
    local capMax = maxEmitterCapacity[name] or 0
    local modeText, drainPerSec = computeModeAndDrainPerSec(name)

    if overheated[name] and cap < CFG_overheatResetCap then
        emitEWStatus(name, string.format(
            "EW | Pods: %s | Cap: %d/%d | OVERHEAT (need >=%d)",
            formatPodsText(name), cap, capMax, CFG_overheatResetCap))
        return
    end

    local state = drainPerSec > 0 and "draining"
        or (capMax > 0 and cap >= capMax) and "full" or "recharging"

    emitEWStatus(name, string.format(
        "EW | Pods: %s | Cap: %d/%d | Mode: %s | %s",
        formatPodsText(name), cap, capMax, modeText, state))
end

-- ---------------------------------------------------------------------------
-- EW tactics
-- ---------------------------------------------------------------------------

local function defensiveLoop(name)
    local s    = ewSettings[name] or {}
    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local pos  = unit:getPoint()
    -- Missile spoofing requires hi-band pods (X/K-band guidance jamming)
    local bands = loadoutBands[name]
    if bands and not bands.hi then return end
    local spoof = CFG_spoofZones  -- zones defined in CONFIG block at top of file
    for id, entry in pairs(trackedMissiles) do
        local m = entry.missile
        if m and Object.isExist(m) then
            local mp      = m:getPoint()
            local dist    = get3DDist(pos, mp)
            local allowed = s.defensive or (s.defDir and inSector(unit, mp, s.defDir))
            if allowed then
                -- Find the tightest applicable zone and roll once
                local pk = nil
                for _, z in ipairs(spoof) do
                    if dist < z.dist then pk = z.pk end
                end
                if pk and math.random(100) <= pk then
                    emitEvent(name, "Spoofed missile, ~" .. math.floor(dist/1852) .. "nm (" .. getClockBearing(unit, mp) .. ")")
                    Object.destroy(m)
                    trackedMissiles[id] = nil
                end
            end
        else
            trackedMissiles[id] = nil
        end
    end
end

local function offensiveLoop(name)
    local s    = ewSettings[name] or {}
    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local jp   = unit:getPoint()
    local cats = { Group.Category.GROUND, Group.Category.SHIP }
    for _, cat in ipairs(cats) do
        local groups = coalition.getGroups(coalition.side.RED, cat) or {}
        for _, g in ipairs(groups) do
            if g and g.isExist and g:isExist() then
                for _, u in ipairs(g:getUnits() or {}) do
                    if u and u.isExist and u:isExist() and isRadarUnit(u) then
                        local up    = u:getPoint()
                        local dist  = get3DDist(jp, up)
                        local gname = g:getName()
                        local now   = timer.getTime()
                        local allowed = s.offensive or (s.offDir and inSector(unit, up, s.offDir))

                        local existing = suppressedSAMs[gname]
                        local alreadySuppressed = existing and not existing.spot
                            and (now - (existing.lastSuppressed or 0) <= (existing.duration or 60))

                        local attempt    = _lastJamAttempt[gname]
                        local onCooldown = attempt and (now - attempt.time) < attempt.cooldown

                        if allowed and not alreadySuppressed and not onCooldown
                        and dist < CFG_jamMaxRange and land.isVisible(up, jp) then
                            local prob
                            if dist <= 30000 then prob = 0.95
                            elseif dist <= 50000 then prob = 0.75
                            elseif dist <= 65000 then prob = 0.50
                            else prob = 0.25
                            end
                            -- Apply radar-type jam difficulty
                            local nato = getNatoName(u)
                            prob = prob * (jamDifficulty[nato] or 1.0)
                            -- Apply cross-band penalty if pods don't cover this system's frequency
                            local bands = loadoutBands[name]
                            if bands then
                                local isLo = loBandSystems[nato]
                                if isLo and not bands.lo then
                                    prob = prob * 0.35  -- hi-band pods vs lo-band radar
                                elseif not isLo and not bands.hi then
                                    prob = prob * 0.35  -- lo-band pods vs hi-band radar
                                end
                            end

                            if math.random() < prob then
                                local ctrl = g:getController()
                                if ctrl and ctrl.setOption then ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.WEAPON_HOLD) end
                                local dur = jamDuration[nato] or 60
                                suppressedSAMs[gname] = { sam = u, lastSuppressed = now, spot = false, duration = dur, nato = nato }
                                _lastJamAttempt[gname] = nil
                                emitEvent(name, "Suppressed: " .. nato)
                            else
                                _lastJamAttempt[gname] = { time = now, cooldown = computeJamAttemptCooldown(dist) }
                                emitEvent(name, "Jam failed: " .. nato)
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end

local function restoreSAMs()
    for gname, info in pairs(suppressedSAMs) do
        local sam  = info.sam
        local keep = false
        if info.spot then
            for _, jammer in ipairs(unitNames) do
                local s = ewSettings[jammer]
                if s and s.spotTarget == gname then
                    local ju = Unit.getByName(jammer)
                    if ju and ju:isExist() and sam and sam:isExist() then
                        local maxCap   = maxEmitterCapacity[jammer] or 0
                        local maxRange = (maxCap >= 3000) and 185200 or 148160
                        if get3DDist(ju:getPoint(), sam:getPoint()) <= maxRange
                        and land.isVisible(sam:getPoint(), ju:getPoint())
                        and (emitterCapacity[jammer] or 0) > 15 then
                            keep = true; break
                        end
                    end
                end
            end
        else
            keep = (timer.getTime() - (info.lastSuppressed or 0) <= (info.duration or 60))
        end
        if not keep then
            if sam and sam.isExist and sam:isExist() then
                -- Jam window expired normally — restore ROE
                local ctrl = sam:getGroup():getController()
                if ctrl and ctrl.setOption then ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE) end
            else
                -- Radar unit no longer exists — site was destroyed while suppressed
                local label = info.nato or gname
                for _, jname in ipairs(unitNames) do
                    emitImmediate(jname, "THREAT NEUTRALIZED: " .. label)
                end
            end
            suppressedSAMs[gname] = nil
        end
    end
end

local function spotJammingTick(name)
    local s        = ewSettings[name] or {}
    local tgtGroup = s.spotTarget
    if not tgtGroup then return end

    if (emitterCapacity[name] or 0) <= CFG_spotDrainPerSec then
        ewSettings[name].spotTarget = nil
        emitEvent(name, "Spot jamming stopped: insufficient capacity"); return
    end

    local ju = Unit.getByName(name); if not ju or not ju:isExist() then return end
    local g  = Group.getByName(tgtGroup)
    if not g or not g:isExist() then
        ewSettings[name].spotTarget = nil
        emitEvent(name, "Spot jamming cancelled: target lost"); return
    end

    local tu = nil
    for _, u in ipairs(g:getUnits() or {}) do if u and u.isExist and u:isExist() then tu = u; break end end
    if not tu then
        ewSettings[name].spotTarget = nil
        emitEvent(name, "Spot jamming cancelled: target destroyed"); return
    end

    local jp       = ju:getPoint()
    local tp       = tu:getPoint()
    local dist     = get3DDist(jp, tp)
    local maxCap   = maxEmitterCapacity[name] or 0
    local maxRange = (maxCap >= 3000) and 185200 or 148160
    local fullEff  = (maxCap >= 3000) and 129600 or 92600
    local altBoost = math.min((jp.y or 0) / 10000, 0.2)

    if dist <= maxRange and land.isVisible(tp, jp) then
        local prob
        if dist <= fullEff then prob = 1.0 else prob = 0.2 + ((fullEff / dist) * 0.8) end
        -- Apply radar-type difficulty to spot jamming as well
        local nato = getNatoName(tu)
        prob = prob + altBoost
        prob = prob * (jamDifficulty[nato] or 1.0)
        -- Apply cross-band penalty if pods don't cover this system's frequency
        local bands = loadoutBands[name]
        if bands then
            local isLo = loBandSystems[nato]
            if isLo and not bands.lo then
                prob = prob * 0.35  -- hi-band pods vs lo-band radar
            elseif not isLo and not bands.hi then
                prob = prob * 0.35  -- lo-band pods vs hi-band radar
            end
        end
        prob = math.min(prob, 1.0)
        if math.random() < prob then
            local ctrl = g:getController()
            if ctrl and ctrl.setOption then ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.WEAPON_HOLD) end
            local dur = jamDuration[nato] or 60
            suppressedSAMs[tgtGroup] = { sam = tu, lastSuppressed = timer.getTime(), spot = true, duration = dur, nato = nato }
            emitEvent(name, "Spot jam: " .. nato)
        else
            emitEvent(name, "Spot jam failed: " .. nato)
        end
        emitterCapacity[name] = math.max(0, (emitterCapacity[name] or 0) - CFG_spotDrainPerSec)
    else
        ewSettings[name].spotTarget = nil
        emitEvent(name, "Spot jamming cancelled: out of range/LOS")
    end
end

-- ---------------------------------------------------------------------------
-- ISR helpers
-- ---------------------------------------------------------------------------

local function getDetectionRange(unit)
    if not unit or not unit:isExist() then return 92600 end
    local alt = math.max(0, unit:getPoint().y)
    return math.min(92600 + alt * 20, 370400)
end

local function computeTrackTime(distMeters)
    local frac = math.min(distMeters / 370400, 1.0)
    return CFG_trackMinTime + frac * (CFG_trackMaxTime - CFG_trackMinTime)
end

local function getConfidence(trackStart, timeToFull)
    return math.min((timer.getTime() - trackStart) / timeToFull, 1.0)
end

local function confidenceLabel(c)
    if c < 0.25 then return "Initial Contact"
    elseif c < 0.50 then return "Tracking"
    elseif c < 0.85 then return "Refined"
    else return "ELINT Lock"
    end
end

-- Stop one track by group name.
-- If ELINT Lock was reached the map mark is preserved, otherwise removed.
local function stopTrack(name, gname, msg)
    local tracks = markedTarget[name]; if not tracks then return end
    local track  = tracks[gname];     if not track  then return end
    if track.markID then
        if track.sentLockMsg then
            lockedMarkIDs[name] = lockedMarkIDs[name] or {}
            table.insert(lockedMarkIDs[name], track.markID)
        else
            trigger.action.removeMark(track.markID)
        end
    end
    tracks[gname] = nil
    if msg then emitEvent(name, msg) end
end

local function stopAllTracks(name)
    for gname in pairs(markedTarget[name] or {}) do
        stopTrack(name, gname, nil)
    end
end

local function buildMarkText(natoName, bearing, rangeNm, confidence, displayPos)
    local bErr  = math.floor(20 * (1 - confidence))
    local rErr  = math.floor(25 * (1 - confidence))
    local lines = {
        confidenceLabel(confidence) .. ": " .. natoName,
        string.format("Bearing: %d (+/-%d)", bearing, bErr),
        string.format("Range:   ~%dnm (+/-%dnm)", rangeNm, rErr),
        string.format("Confidence: %d%%", math.floor(confidence * 100)),
    }
    if confidence >= 0.85 then lines[#lines+1] = bullseyeStr(displayPos) end
    return table.concat(lines, "\n")
end

local function updateMapMark(name, gname, track)
    if not groupIDs[name] then return end
    local u = track.unit; if not u or not u:isExist() then return end

    local actualPos  = u:getPoint()
    local confidence = getConfidence(track.trackStart, track.timeToFull)
    local scale      = 1 - confidence
    local displayPos = {
        x = actualPos.x + track.offsetX * scale,
        y = actualPos.y,
        z = actualPos.z + track.offsetZ * scale,
    }

    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local jp   = unit:getPoint()
    local brg  = getBearing(jp, displayPos)
    local rnm  = math.floor(get3DDist(jp, displayPos) / 1852 + 0.5)
    local nato = getNatoName(u)
    local text = buildMarkText(nato, brg, rnm, confidence, displayPos)

    if track.markID then trigger.action.removeMark(track.markID) end
    local mid = nextMarkID()
    track.markID         = mid
    track.lastMarkUpdate = timer.getTime()
    trigger.action.markToCoalition(mid, text, displayPos, coalition.side.BLUE, true, "")

    if confidence >= 0.85 and not track.sentLockMsg then
        track.sentLockMsg = true
        trigger.action.outTextForCoalition(coalition.side.BLUE,
            string.format("RC-130H Rivet: ELINT LOCK - %s\n", nato) .. text, 25)
    end
end

local function sweepEmitters(name)
    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local jp    = unit:getPoint()
    local range = getDetectionRange(unit)
    local prev  = knownEmitters[name] or {}
    local now   = {}
    local nowT  = timer.getTime()

    local cats = { Group.Category.GROUND, Group.Category.SHIP }
    for _, cat in ipairs(cats) do
        local groups = coalition.getGroups(coalition.side.RED, cat) or {}
        for _, g in ipairs(groups) do
            if g and g.isExist and g:isExist() then
                for _, u in ipairs(g:getUnits() or {}) do
                    if u and u.isExist and u:isExist() and isRadarUnit(u) then
                        local tp    = u:getPoint()
                        local dist  = get3DDist(jp, tp)
                        if dist <= range then
                            local gname = g:getName()
                            local nato  = getNatoName(u)
                            now[gname]  = { pos = tp, seenAt = nowT }

                            if not prev[gname] then
                                -- New contact
                                local brg    = getBearing(jp, tp)
                                local distNm = math.floor(dist/1852+0.5)
                                emitEvent(name, string.format(
                                    "NEW CONTACT: %s | %d | ~%dnm (%s)",
                                    nato, brg, distNm, getClockBearing(unit, tp)))
                                -- Immediate alert for high-priority threats
                                if highPriorityThreats[nato] then
                                    emitImmediate(name, string.format(
                                        "*** THREAT ALERT: %s | %d | ~%dnm (%s) ***",
                                        nato, brg, distNm, getClockBearing(unit, tp)))
                                    -- Auto-track if enabled and a slot is available
                                    if autoTrackEnabled[name] and countTracks(name) < CFG_maxTracks
                                    and not (markedTarget[name] or {})[gname] then
                                        local angle = math.random() * 2 * math.pi
                                        markedTarget[name] = markedTarget[name] or {}
                                        markedTarget[name][gname] = {
                                            groupName      = gname,
                                            unit           = u,
                                            trackStart     = nowT,
                                            timeToFull     = computeTrackTime(dist),
                                            offsetX        = math.cos(angle) * 49500,
                                            offsetZ        = math.sin(angle) * 49500,
                                            markID         = nil,
                                            lastMarkUpdate = nil,
                                            sentLockMsg    = false,
                                        }
                                        emitEvent(name, "AUTO-TRACK: " .. nato)
                                    end
                                end
                            else
                                -- Existing contact — check for displacement
                                local prevPos  = prev[gname].pos
                                local moveDist = get3DDist(prevPos, tp)
                                if moveDist > CFG_displacementThreshold then
                                    emitEvent(name, string.format(
                                        "DISPLACEMENT: %s moved %.1fnm", nato, moveDist/1852))
                                end
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    for gname in pairs(prev) do
        if not now[gname] then
            -- Contact gone — stop any active track on this group
            if (markedTarget[name] or {})[gname] then
                stopTrack(name, gname, "TRACK LOST: " .. gname .. " - out of range or destroyed")
            else
                emitEvent(name, "CONTACT LOST: " .. gname)
            end
        end
    end

    knownEmitters[name] = now
end

local function trackingTick(name)
    local tracks = markedTarget[name]; if not tracks then return end
    local unit   = Unit.getByName(name)
    local now    = timer.getTime()

    for gname, track in pairs(tracks) do
        local u = track.unit
        if not u or not u:isExist() then
            stopTrack(name, gname, "TRACK LOST: target destroyed")
        elseif unit and unit:isExist() and
               get3DDist(unit:getPoint(), u:getPoint()) > getDetectionRange(unit) then
            stopTrack(name, gname, "TRACK LOST: " .. gname .. " - out of range")
        elseif not track.lastMarkUpdate or (now - track.lastMarkUpdate) >= CFG_markRefreshInterval then
            updateMapMark(name, gname, track)
        end
    end
end

local function isrStatusBrief(name)
    local now = timer.getTime()
    if _lastISRStatusTime[name] and (now - _lastISRStatusTime[name]) < CFG_isrStatusInterval then return end
    _lastISRStatusTime[name] = now

    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local range    = getDetectionRange(unit)
    local contacts = 0
    for _ in pairs(knownEmitters[name] or {}) do contacts = contacts + 1 end
    local nTracks  = countTracks(name)

    -- Build per-track time-to-lock summary
    local trackParts = {}
    for _, track in pairs(markedTarget[name] or {}) do
        if track.unit and track.unit:isExist() then
            local c = getConfidence(track.trackStart, track.timeToFull)
            local nato = getNatoName(track.unit)
            if c >= 0.85 then
                trackParts[#trackParts+1] = nato .. " LOCKED"
            else
                local remaining = math.max(0, track.timeToFull - (now - track.trackStart))
                local mins = math.ceil(remaining / 60)
                trackParts[#trackParts+1] = string.format("%s ~%dmin", nato, mins)
            end
        end
    end

    local trackSuffix = (#trackParts > 0) and (" [" .. table.concat(trackParts, " | ") .. "]") or ""
    emitISRStatus(name, string.format(
        "ISR | Range: %dnm | Contacts: %d | Tracks: %d/%d%s",
        math.floor(range/1852+0.5), contacts, nTracks, CFG_maxTracks, trackSuffix))
end

local function sigintReport(name)
    local unit = Unit.getByName(name)
    local gid  = groupIDs[name]
    if not unit or not unit:isExist() or not gid then return end

    local jp    = unit:getPoint()
    local range = getDetectionRange(unit)
    local lines = { string.format("=== SIGINT REPORT | Det. range: %dnm ===", math.floor(range/1852+0.5)) }
    local count = 0

    local cats = { Group.Category.GROUND, Group.Category.SHIP }
    for _, cat in ipairs(cats) do
        local groups = coalition.getGroups(coalition.side.RED, cat) or {}
        for _, g in ipairs(groups) do
            local radar = nil
            for _, u in ipairs(g:getUnits() or {}) do
                if u and u.isExist and u:isExist() and isRadarUnit(u) then radar = u; break end
            end
            if radar then
                local tp   = radar:getPoint()
                local dist = get3DDist(jp, tp)
                if dist <= range then
                    lines[#lines+1] = string.format("  %s | %d | %dnm (%s)",
                        getNatoName(radar), getBearing(jp, tp),
                        math.floor(dist/1852+0.5), getClockBearing(unit, tp))
                    count = count + 1
                end
            end
        end
    end

    if count == 0 then lines[#lines+1] = "  No emitters detected in range" end
    trigger.action.outTextForGroup(gid, table.concat(lines, "\n"), 15)
end

-- ---------------------------------------------------------------------------
-- Crew coordination — EW/ISR handoff brief
-- ---------------------------------------------------------------------------

local function sendHandoffBrief(fromName, toGID)
    local unit = Unit.getByName(fromName)
    if not unit or not unit:isExist() then return end

    local jp    = unit:getPoint()
    local range = getDetectionRange(unit)
    local lines = { "=== C-130J-30 MISSION SYSTEMS HANDOFF BRIEF ===" }

    -- EW status
    if loadoutConfigured[fromName] then
        local modeText, _ = computeModeAndDrainPerSec(fromName)
        local cap    = emitterCapacity[fromName] or 0
        local capMax = maxEmitterCapacity[fromName] or 0
        lines[#lines+1] = string.format("EW: Pods: %s | Cap: %d/%d | Mode: %s",
            formatPodsText(fromName), cap, capMax, modeText)
    else
        lines[#lines+1] = "EW: No loadout configured"
    end

    -- SIGINT contacts
    local contacts = {}
    local cats = { Group.Category.GROUND, Group.Category.SHIP }
    for _, cat in ipairs(cats) do
        for _, g in ipairs(coalition.getGroups(coalition.side.RED, cat) or {}) do
            local radar = nil
            for _, u in ipairs(g:getUnits() or {}) do
                if u and u.isExist and u:isExist() and isRadarUnit(u) then radar = u; break end
            end
            if radar and get3DDist(jp, radar:getPoint()) <= range then
                local nato = getNatoName(radar)
                local tp   = radar:getPoint()
                contacts[#contacts+1] = string.format("  %-10s %s | %d | %dnm",
                    nato, bullseyeStr(tp),
                    getBearing(jp, tp), math.floor(get3DDist(jp, tp)/1852+0.5))
            end
        end
    end
    lines[#lines+1] = string.format("SIGINT: %d contact(s)", #contacts)
    for _, c in ipairs(contacts) do lines[#lines+1] = c end

    -- Active tracks
    local nTracks = countTracks(fromName)
    lines[#lines+1] = string.format("Tracks: %d active", nTracks)
    for gname, track in pairs(markedTarget[fromName] or {}) do
        if track.unit and track.unit:isExist() then
            local c  = getConfidence(track.trackStart, track.timeToFull)
            local ap = track.unit:getPoint()
            local dp = { x = ap.x + track.offsetX*(1-c), y = ap.y, z = ap.z + track.offsetZ*(1-c) }
            lines[#lines+1] = string.format("  %s [%s %d%%] %s",
                getNatoName(track.unit), confidenceLabel(c),
                math.floor(c*100), bullseyeStr(dp))
        end
    end

    trigger.action.outTextForGroup(toGID, table.concat(lines, "\n"), 30)
    emitEvent(fromName, "Handoff brief sent")
end

local function refreshCoordTargets(name, gid, cmenu)
    if coordCmds[name] then
        for _, cmd in ipairs(coordCmds[name]) do
            if cmd then missionCommands.removeItemForGroup(gid, cmd) end
        end
    end
    coordCmds[name] = {}
    local myGID = groupIDs[name]
    local cats  = { Group.Category.AIRPLANE, Group.Category.HELICOPTER }
    for _, cat in ipairs(cats) do
        for _, g in ipairs(coalition.getGroups(coalition.side.BLUE, cat) or {}) do
            if g and g.isExist and g:isExist() and g:getID() ~= myGID then
                local toGID = g:getID()
                local label = g:getName()
                local cmd = missionCommands.addCommandForGroup(gid, label, cmenu, function()
                    sendHandoffBrief(name, toGID)
                end)
                table.insert(coordCmds[name], cmd)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- ISR track emitter menu
-- ---------------------------------------------------------------------------

local function refreshTrackTargets(name, gid, tsMenu)
    if trackCmds[name] then
        for _, cmd in ipairs(trackCmds[name]) do
            if cmd then missionCommands.removeItemForGroup(gid, cmd) end
        end
    end
    trackCmds[name] = {}

    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local jp    = unit:getPoint()
    local range = getDetectionRange(unit)
    local nTracks = countTracks(name)

    if nTracks >= CFG_maxTracks then return end   -- slots full

    local cats = { Group.Category.GROUND, Group.Category.SHIP }
    for _, cat in ipairs(cats) do
        local groups = coalition.getGroups(coalition.side.RED, cat) or {}
        for _, g in ipairs(groups) do
            local radar = nil
            for _, u in ipairs(g:getUnits() or {}) do
                if u and u.isExist and u:isExist() and isRadarUnit(u) then radar = u; break end
            end
            if radar then
                local tp    = radar:getPoint()
                local dist  = get3DDist(jp, tp)
                local gname = g:getName()
                if dist <= range and not (markedTarget[name] or {})[gname] then
                    local brg    = getBearing(jp, tp)
                    local distNm = math.floor(dist/1852+0.5)
                    local label  = getNatoName(radar) .. " | " .. brg .. " | " .. distNm .. "nm"
                    local cmd = missionCommands.addCommandForGroup(gid, label, tsMenu, function()
                        if countTracks(name) >= CFG_maxTracks then
                            emitEvent(name, "Track limit reached (" .. CFG_maxTracks .. " max)"); return
                        end
                        local angle = math.random() * 2 * math.pi
                        local rU = nil
                        for _, u in ipairs(g:getUnits() or {}) do
                            if u and u.isExist and u:isExist() then rU = u; break end
                        end
                        markedTarget[name] = markedTarget[name] or {}
                        markedTarget[name][gname] = {
                            groupName      = gname,
                            unit           = rU,
                            trackStart     = timer.getTime(),
                            timeToFull     = computeTrackTime(dist),
                            offsetX        = math.cos(angle) * 49500,
                            offsetZ        = math.sin(angle) * 49500,
                            markID         = nil,
                            lastMarkUpdate = nil,
                            sentLockMsg    = false,
                        }
                        local ttf = math.floor(computeTrackTime(dist) / 60 + 0.5)
                        emitEvent(name, string.format("Tracking: %s - est. lock in %d min", label, ttf))
                    end)
                    table.insert(trackCmds[name], cmd)
                end
            end
        end
    end
end

local function refreshStopTrackMenu(name, gid, stMenu)
    if stopTrackCmds[name] then
        for _, cmd in ipairs(stopTrackCmds[name]) do
            if cmd then missionCommands.removeItemForGroup(gid, cmd) end
        end
    end
    stopTrackCmds[name] = {}

    for gname, track in pairs(markedTarget[name] or {}) do
        local c     = getConfidence(track.trackStart, track.timeToFull)
        local label = string.format("%s [%d%%]", gname, math.floor(c*100))
        local g     = gname   -- capture for closure
        local cmd = missionCommands.addCommandForGroup(gid, label, stMenu, function()
            stopTrack(name, g, "Stopped tracking: " .. g)
        end)
        table.insert(stopTrackCmds[name], cmd)
    end
end

-- ---------------------------------------------------------------------------
-- EW spot jam target menu
-- ---------------------------------------------------------------------------

local function refreshSpotTargetList(name, gid, tsMenu)
    if spotTargetCmds[name] then
        for _, cmd in ipairs(spotTargetCmds[name]) do
            if cmd then missionCommands.removeItemForGroup(gid, cmd) end
        end
    end
    spotTargetCmds[name] = {}

    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local jp   = unit:getPoint()

    local cats = { Group.Category.GROUND, Group.Category.SHIP }
    for _, cat in ipairs(cats) do
        local groups = coalition.getGroups(coalition.side.RED, cat) or {}
        for _, g in ipairs(groups) do
            local radar = nil
            for _, u in ipairs(g:getUnits() or {}) do
                if u and u.isExist and u:isExist() and isRadarUnit(u) then radar = u; break end
            end
            if radar then
                local tp   = radar:getPoint()
                local dist = get3DDist(jp, tp)
                if dist <= 185200 then
                    local brg    = getBearing(jp, tp)
                    local distNm = math.floor(dist/1852+0.5)
                    local label  = getNatoName(radar) .. " | " .. brg .. " | " .. distNm .. "nm"
                    local gname  = g:getName()
                    local cmd = missionCommands.addCommandForGroup(gid, label, tsMenu, function()
                        if overheated[name] and (emitterCapacity[name] or 0) < CFG_overheatResetCap then
                            emitEvent(name, "Overheat (need >=" .. CFG_overheatResetCap .. ")"); return
                        end
                        ewSettings[name] = ewSettings[name] or {}
                        ewSettings[name].spotTarget = gname
                        emitEvent(name, "Spot jamming: " .. label)
                    end)
                    table.insert(spotTargetCmds[name], cmd)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Menu building
-- ---------------------------------------------------------------------------

local buildMenusFor  -- forward declaration

local function buildEWPostLoadoutMenus(name, ewRoot, gid)
    local dmenu = missionCommands.addSubMenuForGroup(gid, "Area Defense Jamming", ewRoot)
    missionCommands.addCommandForGroup(gid, "Enable", dmenu, function()
        if overheated[name] and (emitterCapacity[name] or 0) < CFG_overheatResetCap then
            emitEvent(name, "Overheat (need >=" .. CFG_overheatResetCap .. ")"); return
        end
        ewSettings[name] = ewSettings[name] or {}; ewSettings[name].defensive = true
        emitEvent(name, "Area Defense Jamming: ON")
    end)
    missionCommands.addCommandForGroup(gid, "Disable", dmenu, function()
        ewSettings[name] = ewSettings[name] or {}; ewSettings[name].defensive = false
        emitEvent(name, "Area Defense Jamming: OFF")
    end)

    local amenu = missionCommands.addSubMenuForGroup(gid, "Area Offense Jamming", ewRoot)
    missionCommands.addCommandForGroup(gid, "Enable", amenu, function()
        if overheated[name] and (emitterCapacity[name] or 0) < CFG_overheatResetCap then
            emitEvent(name, "Overheat (need >=" .. CFG_overheatResetCap .. ")"); return
        end
        ewSettings[name] = ewSettings[name] or {}; ewSettings[name].offensive = true
        emitEvent(name, "Area Offense Jamming: ON")
    end)
    missionCommands.addCommandForGroup(gid, "Disable", amenu, function()
        ewSettings[name] = ewSettings[name] or {}; ewSettings[name].offensive = false
        emitEvent(name, "Area Offense Jamming: OFF")
    end)

    for _, mode in ipairs({ "Offense", "Defense" }) do
        local key     = (mode == "Offense") and "offDir" or "defDir"
        local submenu = missionCommands.addSubMenuForGroup(gid, "Directional " .. mode .. " Jamming", ewRoot)
        for _, dir in ipairs({ "front", "left", "right", "rear" }) do
            missionCommands.addCommandForGroup(gid, "Enable " .. dir, submenu, function()
                if overheated[name] and (emitterCapacity[name] or 0) < CFG_overheatResetCap then
                    emitEvent(name, "Overheat (need >=" .. CFG_overheatResetCap .. ")"); return
                end
                ewSettings[name] = ewSettings[name] or {}; ewSettings[name][key] = dir
                emitEvent(name, "Directional " .. mode .. " Jamming: " .. dir)
            end)
        end
        missionCommands.addCommandForGroup(gid, "Disable", submenu, function()
            ewSettings[name] = ewSettings[name] or {}; ewSettings[name][key] = nil
            emitEvent(name, "Directional " .. mode .. " Jamming: OFF")
        end)
    end

    local sjMenu = missionCommands.addSubMenuForGroup(gid, "Spot Jamming", ewRoot)
    missionCommands.addCommandForGroup(gid, "Disable", sjMenu, function()
        ewSettings[name] = ewSettings[name] or {}; ewSettings[name].spotTarget = nil
        emitEvent(name, "Spot Jamming: OFF")
    end)
    local tsMenu = missionCommands.addSubMenuForGroup(gid, "Select Target", sjMenu)
    spotTargetMenus[name] = tsMenu

    missionCommands.addCommandForGroup(gid, "Disable All EW Modes", ewRoot, function()
        closeAllEW(name, true); emitEvent(name, "All EW modes OFF")
    end)

    missionCommands.addCommandForGroup(gid, "Power OFF Jammer Pods", ewRoot, function()
        closeAllEW(name, true)
        podEnabled[name] = false
        if ewMenus[name] then missionCommands.removeItemForGroup(gid, ewMenus[name]); ewMenus[name] = nil end
        local stub = missionCommands.addSubMenuForGroup(gid, "EW - Electronic Warfare [OFF]", rootMenus[name])
        ewMenus[name] = stub
        missionCommands.addCommandForGroup(gid, "Power ON Jammer Pods", stub, function()
            if ewMenus[name] then missionCommands.removeItemForGroup(gid, ewMenus[name]); ewMenus[name] = nil end
            podEnabled[name] = true
            local newEW = missionCommands.addSubMenuForGroup(gid, "EW - Electronic Warfare", rootMenus[name])
            ewMenus[name] = newEW
            buildEWPostLoadoutMenus(name, newEW, gid)
            ewStatusBrief(name)
            emitEvent(name, "Jammer pods powered ON")
        end)
    end)
end

local function buildEWLoadoutMenu(name, ewRoot, gid)
    local loadout = missionCommands.addSubMenuForGroup(gid, "Equipment Setup", ewRoot)
    local presets = {
        { label = "Defensive",     cap = 2500, hi = true,  lo = false,
          pods = "3x hi-band",              coverage = "Hi-band (tracking radars, missile spoofing)" },
        { label = "Offensive",     cap = 4500, hi = false, lo = true,
          pods = "2x lo-band",              coverage = "Lo-band (acquisition / search radars)" },
        { label = "Full Spectrum", cap = 5500, hi = true,  lo = true,
          pods = "2x lo-band + 1x hi-band", coverage = "Low-band + Hi-band" },
    }
    for _, p in ipairs(presets) do
        missionCommands.addCommandForGroup(gid, p.label, loadout, function()
            local cap                 = p.cap
            maxEmitterCapacity[name]  = cap
            emitterCapacity[name]     = cap
            overheated[name]          = false
            loadoutConfigured[name]   = true
            selectedLoadoutName[name] = p.label
            loadoutBands[name]        = { hi = p.hi, lo = p.lo }
            podEnabled[name]          = true
            if ewMenus[name] then missionCommands.removeItemForGroup(gid, ewMenus[name]); ewMenus[name] = nil end
            local newEW = missionCommands.addSubMenuForGroup(gid, "EW - Electronic Warfare", rootMenus[name])
            ewMenus[name] = newEW
            buildEWPostLoadoutMenus(name, newEW, gid)
            emitImmediate(name, string.format(
                "EW PODS ONLINE\nLoadout : %s  [%s]\nCapacity: %d / %d\nCoverage: %s\nStatus  : All modes available",
                p.label, p.pods, cap, cap, p.coverage))
        end)
    end
end

local function buildEWSubMenu(name, root, gid)
    local ewRoot = missionCommands.addSubMenuForGroup(gid, "EW - Electronic Warfare", root)
    ewMenus[name] = ewRoot
    if not loadoutConfigured[name] then
        buildEWLoadoutMenu(name, ewRoot, gid)
    else
        buildEWPostLoadoutMenus(name, ewRoot, gid)
    end
end

local function buildISRSubMenu(name, root, gid)
    local isrRoot = missionCommands.addSubMenuForGroup(gid, "ISR - Intelligence Surveillance Recon", root)
    isrMenus[name] = isrRoot

    missionCommands.addCommandForGroup(gid, "SIGINT Report", isrRoot, function()
        sigintReport(name)
    end)

    local tkMenu = missionCommands.addSubMenuForGroup(gid, "Track Emitter", isrRoot)
    trackMenus[name] = tkMenu

    local stMenu = missionCommands.addSubMenuForGroup(gid, "Stop Track", isrRoot)
    stopTrackMenus[name] = stMenu

    missionCommands.addCommandForGroup(gid, "Stop All Tracks", isrRoot, function()
        stopAllTracks(name)
        emitEvent(name, "All tracks stopped")
    end)

    missionCommands.addCommandForGroup(gid, "Toggle Auto-Track [High-Priority]", isrRoot, function()
        autoTrackEnabled[name] = not autoTrackEnabled[name]
        local state = autoTrackEnabled[name] and "ON" or "OFF"
        emitImmediate(name, "Auto-Track High-Priority: " .. state ..
            (autoTrackEnabled[name] and "\nSA-10 / SA-11 / SA-15 / Patriot / NASAMS will be tracked automatically." or ""))
    end)

    missionCommands.addCommandForGroup(gid, "Clear Map Marks", isrRoot, function()
        for gname in pairs(markedTarget[name] or {}) do
            local track = (markedTarget[name] or {})[gname]
            if track and track.markID then trigger.action.removeMark(track.markID) end
        end
        for _, mid in ipairs(lockedMarkIDs[name] or {}) do trigger.action.removeMark(mid) end
        lockedMarkIDs[name] = {}
        emitEvent(name, "Map marks cleared")
    end)
end

local function buildCoordSubMenu(name, root, gid)
    local cRoot = missionCommands.addSubMenuForGroup(gid, "Crew Coordination", root)
    coordMenus[name] = cRoot
    local briefMenu = missionCommands.addSubMenuForGroup(gid, "Send Handoff Brief To", cRoot)
    -- coordCmds populated by refreshCoordTargets each tick
    coordCmds[name] = {}
    -- store briefMenu handle so refresh knows where to add commands
    coordMenus[name .. "_brief"] = briefMenu
end

buildMenusFor = function(name)
    local unit = Unit.getByName(name); if not unit or not unit:isExist() then return end
    local gid  = unit:getGroup():getID()
    local root = missionCommands.addSubMenuForGroup(gid, "C-130J-30 | Mission Systems")
    rootMenus[name] = root
    buildEWSubMenu(name, root, gid)
    buildISRSubMenu(name, root, gid)
    buildCoordSubMenu(name, root, gid)
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

local function pushUnique(t, v) for i = 1, #t do if t[i] == v then return end end t[#t+1] = v end

local function isEligible(unit)
    if not unit or not unit.isExist or not unit:isExist() then return false end
    if eligibleTypeNames[unit:getTypeName() or ""] then return true end
    local nm = unit:getName() or ""
    return string.find(nm, "Compass Call") or string.find(nm, "Rivet")
end

local function registerUnit(unit)
    if not unit or not unit:isExist() then return end
    local name = unit:getName()
    if not _staticSlots[name] then return end
    local gid  = unit:getGroup():getID()
    if rootMenus[name] and groupIDs[name] == gid then return end
    if rootMenus[name] then
        missionCommands.removeItemForGroup(groupIDs[name], rootMenus[name])
        rootMenus[name] = nil
    end
    pushUnique(unitNames, name)
    groupIDs[name]           = gid
    ewSettings[name]         = {}
    emitterCapacity[name]    = nil
    maxEmitterCapacity[name] = 0
    loadoutConfigured[name]  = false
    selectedPods[name]       = { n99 = 0, n249 = 0 }
    overheated[name]         = false
    podEnabled[name]         = true
    knownEmitters[name]      = {}
    markedTarget[name]       = {}
    lockedMarkIDs[name]      = {}
    buildMenusFor(name)
end

local function unregisterByName(name)
    if not name then return end
    local gid = groupIDs[name]
    if gid and rootMenus[name] then missionCommands.removeItemForGroup(gid, rootMenus[name]) end
    stopAllTracks(name)
    for _, mid in ipairs(lockedMarkIDs[name] or {}) do trigger.action.removeMark(mid) end
    rootMenus[name]                  = nil
    ewMenus[name]                    = nil
    isrMenus[name]                   = nil
    coordMenus[name]                 = nil
    coordMenus[name .. "_brief"]     = nil
    groupIDs[name]                   = nil
    ewSettings[name]                 = nil
    emitterCapacity[name]            = nil
    maxEmitterCapacity[name]         = nil
    loadoutConfigured[name]          = nil
    selectedPods[name]               = nil
    selectedLoadoutName[name]        = nil
    overheated[name]                 = nil
    podEnabled[name]                 = nil
    spotTargetMenus[name]            = nil
    spotTargetCmds[name]             = nil
    knownEmitters[name]              = nil
    markedTarget[name]               = nil
    lockedMarkIDs[name]              = nil
    trackMenus[name]                 = nil
    trackCmds[name]                  = nil
    stopTrackMenus[name]             = nil
    stopTrackCmds[name]              = nil
    coordCmds[name]                  = nil
    _lastSweep[name]                 = nil
    _lastEWStatusTime[name]          = nil
    _lastISRStatusTime[name]         = nil
    _lowCapWarned[name]              = nil
    autoTrackEnabled[name]           = nil
    for i = #unitNames, 1, -1 do if unitNames[i] == name then table.remove(unitNames, i) end end
end

-- ---------------------------------------------------------------------------
-- Main ticks
-- ---------------------------------------------------------------------------

local function ewTick()
    for _, name in ipairs(unitNames) do
        local proceed = loadoutConfigured[name]
            and emitterCapacity[name] ~= nil
            and (maxEmitterCapacity[name] or 0) > 0
            and podEnabled[name] ~= false

        if proceed then
            local cap    = emitterCapacity[name]
            local capMax = maxEmitterCapacity[name] or 0
            local _, drainPerSec = computeModeAndDrainPerSec(name)

            if overheated[name] and cap >= CFG_overheatResetCap then
                overheated[name] = false
                emitEvent(name, "Overheat cleared, EW available")
            end

            local wasCap = cap
            if drainPerSec > 0 and not overheated[name] then
                cap = math.max(0, cap - drainPerSec)
            else
                cap = math.min(capMax, cap + CFG_regenPerSec)
            end

            if wasCap > 0 and drainPerSec > 0 and cap == 0 and not overheated[name] then
                overheated[name] = true
                closeAllEW(name, true)
                emitEvent(name, "OVERHEAT - need >=" .. CFG_overheatResetCap .. " to enable")
            end

            emitterCapacity[name] = cap

            -- Low capacity warning
            local warnThresh = capMax * CFG_lowCapWarnPct
            if cap <= warnThresh and cap > 0 and not overheated[name] then
                if not _lowCapWarned[name] then
                    _lowCapWarned[name] = true
                    emitImmediate(name, string.format(
                        "EW | LOW CAPACITY: %d/%d (%.0f%%) — consider reducing modes",
                        cap, capMax, (cap / capMax) * 100))
                end
            elseif cap > warnThresh then
                _lowCapWarned[name] = false  -- reset so it fires again next drain cycle
            end

            local s = ewSettings[name] or {}
            if s.spotTarget then spotJammingTick(name) end
            if s.defensive or s.defDir then defensiveLoop(name) end
            if s.offensive or s.offDir then offensiveLoop(name) end
        end
    end
    restoreSAMs()
    return timer.getTime() + 1
end

local function isrTick()
    local now = timer.getTime()
    for _, name in ipairs(unitNames) do
        local u = Unit.getByName(name)
        if u and u:isExist() then
            if not _lastSweep[name] or (now - _lastSweep[name]) >= CFG_sweepInterval then
                sweepEmitters(name)
                _lastSweep[name] = now
            end
            trackingTick(name)
        end
    end
    return now + 1
end

local function statusDisplayTick()
    for _, name in ipairs(unitNames) do
        ewStatusBrief(name)
        isrStatusBrief(name)
    end
    return timer.getTime() + 1
end

local function refreshMenusTick()
    for _, name in ipairs(unitNames) do
        local gid = groupIDs[name]
        if gid then
            if spotTargetMenus[name] then
                refreshSpotTargetList(name, gid, spotTargetMenus[name])
            end
            if trackMenus[name] then
                refreshTrackTargets(name, gid, trackMenus[name])
            end
            if stopTrackMenus[name] then
                refreshStopTrackMenu(name, gid, stopTrackMenus[name])
            end
            local briefMenu = coordMenus[name .. "_brief"]
            if briefMenu then
                refreshCoordTargets(name, gid, briefMenu)
            end
        end
    end
    return timer.getTime() + 10
end

timer.scheduleFunction(ewTick,            {}, timer.getTime() + 1)
timer.scheduleFunction(isrTick,           {}, timer.getTime() + 1)
timer.scheduleFunction(statusDisplayTick, {}, timer.getTime() + 1)
timer.scheduleFunction(refreshMenusTick,  {}, timer.getTime() + 10)

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local EventHandler = {}
function EventHandler:onEvent(event)
    if not event then return end

    if event.id == world.event.S_EVENT_SHOT and event.weapon then
        local shooter = event.initiator
        if shooter and shooter.getCoalition and shooter:getCoalition() == coalition.side.RED then
            local desc = event.weapon:getDesc()
            if desc and (desc.guidance == 3 or desc.guidance == 4) then
                local tgt = (Weapon and Weapon.getTarget and Weapon.getTarget(event.weapon))
                         or (event.weapon.getTarget and event.weapon:getTarget()) or nil
                if tgt and tgt.isExist and tgt:isExist() then
                    trackedMissiles[missileUID] = { missile = event.weapon, target = tgt, uid = missileUID }
                    missileUID = missileUID + 1
                end
            end
        end
        return
    end

    if event.id == world.event.S_EVENT_BIRTH or event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
        local u = event.initiator
        if u and u.getPlayerName and u:getPlayerName() and isEligible(u) then
            timer.scheduleFunction(function()
                if u and u:isExist() then registerUnit(u) end
            end, nil, timer.getTime() + 0.1)
        end
        return
    end

    if event.id == world.event.S_EVENT_CRASH    or event.id == world.event.S_EVENT_DEAD
    or event.id == world.event.S_EVENT_EJECTION or event.id == world.event.S_EVENT_PILOT_DEAD
    or event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
        local u = event.initiator
        if u then
            local ok, name = pcall(function() return u:getName() end)
            if ok and name then unregisterByName(name) end
        end
        return
    end
end

if not _G.C130_Systems_EventHandler_Registered then
    world.addEventHandler(EventHandler)
    _G.C130_Systems_EventHandler_Registered = true
end

-- ---------------------------------------------------------------------------
-- Auto-register & startup
-- ---------------------------------------------------------------------------

local _staticSlots_ready = false
local function recordStaticSlots()
    for _, g in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        if g and g.isExist and g:isExist() then
            for _, u in ipairs(g:getUnits() or {}) do
                if u and u.isExist and u:isExist() and isEligible(u) then
                    _staticSlots[u:getName()] = true
                end
            end
        end
    end
    _staticSlots_ready = true
end
timer.scheduleFunction(function() recordStaticSlots() end, {}, timer.getTime() + 0.1)

local function autoRegisterAtStart()
    for _, g in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        if g and g.isExist and g:isExist() then
            for _, u in ipairs(g:getUnits() or {}) do
                if u and u.isExist and u:isExist()
                and u.getPlayerName and u:getPlayerName()
                and isEligible(u) then
                    registerUnit(u)
                end
            end
        end
    end
end
timer.scheduleFunction(function() autoRegisterAtStart() end, {}, timer.getTime() + 1)

local function ensureMenus()
    for _, name in ipairs(unitNames) do
        if not rootMenus[name] then
            local u = Unit.getByName(name)
            if u and u:isExist() then buildMenusFor(name) end
        end
    end
    return timer.getTime() + 2
end
timer.scheduleFunction(ensureMenus, {}, timer.getTime() + 2)
