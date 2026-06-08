-- Operation Broken Chain — AI_A2A_DISPATCHER (replaces EASYGCICAP V1)
-- Red AI air defense: layered CAP + GCI with CAP-first intercept priority
-- Inner ring: standing CAP patrols + GCI reserve
-- Middle ring: GCI only (scramble when inner CAP overwhelmed)
-- Outer ring: GCI deep reserve
-- Load after Moose.lua via DO SCRIPT FILE trigger (time > 2s)

------------------------------------------------------------------------
-- DEBUG / TESTING — set false before going live
------------------------------------------------------------------------

OBS_DEBUG = true

------------------------------------------------------------------------
-- DETECTION NETWORK
-- EWR + SAM radars feed the dispatcher. 30km grouping radius means
-- nearby blue aircraft are treated as a single threat group.
------------------------------------------------------------------------

local DetectionSetGroup = SET_GROUP:New()
DetectionSetGroup:FilterPrefixes({"Red EWR", "Red SAM"})
DetectionSetGroup:FilterStart()

local Detection = DETECTION_AREAS:New(DetectionSetGroup, 30000)

-- Only react to threats inside Syrian airspace — ignore blue in Turkey
Detection:SetAcceptZones({
  ZONE_POLYGON:FindByName("Syria CAP Zone 1"),
  ZONE_POLYGON:FindByName("Syria CAP Zone 2")
})

------------------------------------------------------------------------
-- DISPATCHER
------------------------------------------------------------------------

OBS_A2A = AI_A2A_DISPATCHER:New(Detection)

OBS_A2A:SetEngageRadius(100000)         -- 100km — CAP will intercept within this range
OBS_A2A:SetGciRadius(150000)            -- 150km — max distance for GCI scramble
OBS_A2A:SetDisengageRadius(300000)      -- 300km — RTB if pursuit goes too far
OBS_A2A:SetDefaultTakeoffFromParkingHot()
OBS_A2A:SetDefaultLandingNearAirbase()
OBS_A2A:SetDefaultFuelThreshold(0)      -- never RTB for fuel — patrol until killed

------------------------------------------------------------------------
-- INNER RING — CAP + GCI (standing patrol + reserve scramble)
-- These bases maintain a 2-ship CAP orbit. Remaining airframes sit
-- on the ground as GCI reserve. When CAP is busy or dead, GCI
-- scrambles automatically. Replacement CAP launches 2-5 min after loss.
------------------------------------------------------------------------

-- KUWEIRES (15nm east of Aleppo) — MiG-29
OBS_A2A:SetSquadron("Kuweires", AIRBASE.Syria.Kuweires,
  {"Red CAP Mig-29 Kuweires"}, 6)
OBS_A2A:SetSquadronGrouping("Kuweires", 2)
OBS_A2A:SetSquadronOverhead("Kuweires", 1)
OBS_A2A:SetSquadronCap("Kuweires",
  ZONE:New("Red CAP Orbit Kuweires"),
  7620, 8534,        -- floor/ceiling (m) = 25,000-28,000 ft
  500, 650,          -- patrol speed (km/h)
  800, 1200,         -- engage speed (km/h)
  "BARO")
OBS_A2A:SetSquadronCapInterval("Kuweires", 1, 30, 60, 1)
OBS_A2A:SetSquadronGci("Kuweires", 800, 1200)

-- JIRAH (35nm east) — MiG-29
OBS_A2A:SetSquadron("Jirah", AIRBASE.Syria.Jirah,
  {"Red CAP Mig-29 Jirah"}, 4)
OBS_A2A:SetSquadronGrouping("Jirah", 2)
OBS_A2A:SetSquadronOverhead("Jirah", 1)
OBS_A2A:SetSquadronCap("Jirah",
  ZONE:New("Red CAP Orbit Jirah"),
  7620, 8534,        -- floor/ceiling (m) = 25,000-28,000 ft
  500, 650,          -- patrol speed (km/h)
  800, 1200,
  "BARO")
OBS_A2A:SetSquadronCapInterval("Jirah", 1, 30, 60, 1)
OBS_A2A:SetSquadronGci("Jirah", 800, 1200)

-- ABU AL-DUHUR (40nm south) — Su-27 CAP + MiG-29 GCI mix
OBS_A2A:SetSquadron("Abu al-Duhur", AIRBASE.Syria.Abu_al_Duhur,
  {"Red CAP SU-27 Abu Al-Duhur", "Red CAP Mig-29 Abu al-Duhur"}, 6)
OBS_A2A:SetSquadronGrouping("Abu al-Duhur", 2)
OBS_A2A:SetSquadronOverhead("Abu al-Duhur", 1)
OBS_A2A:SetSquadronCap("Abu al-Duhur",
  ZONE:New("Red CAP Orbit Abu al-Duhur"),
  7620, 9144,        -- floor/ceiling (m) = 25,000-30,000 ft
  500, 700,          -- patrol speed (km/h)
  900, 1400,
  "BARO")
OBS_A2A:SetSquadronCapInterval("Abu al-Duhur", 1, 30, 60, 1)
OBS_A2A:SetSquadronGci("Abu al-Duhur", 900, 1400)

------------------------------------------------------------------------
-- MIDDLE RING — GCI only (scramble when inner CAP is overwhelmed)
-- These bases sit cold. The dispatcher only scrambles them when
-- airborne CAP can't cover all detected threats.
------------------------------------------------------------------------

-- TABQA (~80nm east) — MiG-29
OBS_A2A:SetSquadron("Tabqa", AIRBASE.Syria.Tabqa,
  {"Red CAP Mig-29 Tabqa"}, 4)
OBS_A2A:SetSquadronGrouping("Tabqa", 2)
OBS_A2A:SetSquadronOverhead("Tabqa", 0.75)
OBS_A2A:SetSquadronGci("Tabqa", 800, 1200)

-- HAMA (~70nm south) — MiG-29
OBS_A2A:SetSquadron("Hama", AIRBASE.Syria.Hama,
  {"Red CAP Mig-29 Hama"}, 4)
OBS_A2A:SetSquadronGrouping("Hama", 2)
OBS_A2A:SetSquadronOverhead("Hama", 0.75)
OBS_A2A:SetSquadronGci("Hama", 800, 1200)

-- BASSEL AL-ASSAD (~100nm SW) — MiG-29 + Su-27 mix, western approach CAP
OBS_A2A:SetSquadron("Bassel", AIRBASE.Syria.Bassel_Al_Assad,
  {"Red CAP Mig-29 Bassel Al-Assad", "Red CAP SU-27 Bassel Al-Assad-2"}, 8)
OBS_A2A:SetSquadronGrouping("Bassel", 2)
OBS_A2A:SetSquadronOverhead("Bassel", 1)
OBS_A2A:SetSquadronCap("Bassel",
  ZONE:New("Red CAP Orbit Bassel Al-Assad"),
  7620, 9144,        -- floor/ceiling (m) = 25,000-30,000 ft
  500, 700,          -- patrol speed (km/h)
  800, 1400,
  "BARO")
OBS_A2A:SetSquadronCapInterval("Bassel", 1, 30, 60, 1)
OBS_A2A:SetSquadronGci("Bassel", 800, 1400)

------------------------------------------------------------------------
-- OUTER RING — GCI deep reserve
-- Only activated when inner + middle can't handle the threat.
-- Lower overhead (0.5) prevents overwhelming late-game swarms.
------------------------------------------------------------------------

-- AL QUSAYR (~120nm south) — Su-27 + MiG-29 mix
OBS_A2A:SetSquadron("Al Qusayr", AIRBASE.Syria.Al_Qusayr,
  {"Red CAP SU-27 Al Qusayr", "Red CAP Mig-29 Al Qusayr-1"}, 8)
OBS_A2A:SetSquadronGrouping("Al Qusayr", 2)
OBS_A2A:SetSquadronOverhead("Al Qusayr", 0.5)
OBS_A2A:SetSquadronGci("Al Qusayr", 900, 1400)

-- PALMYRA (~150nm east) — Su-27
OBS_A2A:SetSquadron("Palmyra", AIRBASE.Syria.Palmyra,
  {"Red CAP SU-27 Palmyra"}, 6)
OBS_A2A:SetSquadronGrouping("Palmyra", 2)
OBS_A2A:SetSquadronOverhead("Palmyra", 0.5)
OBS_A2A:SetSquadronGci("Palmyra", 900, 1400)

------------------------------------------------------------------------
-- SLOW REPLACEMENT: swap to 10-12 min intervals after initial CAP launches
------------------------------------------------------------------------

TIMER:New(function()
  OBS_A2A:SetSquadronCapInterval("Kuweires", 1, 600, 720, 1)
  OBS_A2A:SetSquadronCapInterval("Jirah", 1, 600, 720, 1)
  OBS_A2A:SetSquadronCapInterval("Abu al-Duhur", 1, 600, 720, 1)
  OBS_A2A:SetSquadronCapInterval("Bassel", 1, 600, 720, 1)
end):Start(180)

------------------------------------------------------------------------
-- DEBUG
------------------------------------------------------------------------

if OBS_DEBUG then
  OBS_A2A:SetTacticalDisplay(true)

  TIMER:New(function()
    local msg = "=== RED A2A DISPATCHER ACTIVE ===\n"
    msg = msg .. "CAP+GCI: Kuweires(6) / Jirah(4) / Abu al-Duhur(6) / Bassel(8)\n"
    msg = msg .. "GCI only: Tabqa(4) / Hama(4)\n"
    msg = msg .. "Outer (GCI): Al Qusayr(8) / Palmyra(6)\n"
    msg = msg .. "Total: 46 airframes | CAP-first priority\n"
    msg = msg .. "Tactical display: ON (F10 map)"
    MESSAGE:New(msg, 30):ToAll()
  end):Start(10)
end
