-- ============================================================
-- Operation Broken Chain — MANTIS IADS (red air-defense network)
-- Cleaned-up V2. Changes from V1 are noted inline.
-- MANTIS:New(name, SAMprefix, EWRprefix, HQname, coalition, dynamic, AWACSprefix)
-- ============================================================

OBSMantis = MANTIS:New("OBS MANTIS", "Red SAM", "Red EWR", "Red HQ", "red", true, "Red AWACS")

OBSMantis:SetDetectInterval(10)            -- re-evaluate threats every 10s (default 30; example uses 20)
OBSMantis:SetAccousticDetectionOn(3000)    -- acoustic/visual backup detection within 3 km
OBSMantis:SetMaxActiveSAMs(6, 5, 2, false, 6)  -- max active sites per band: short, mid, long, <flag>, point-def
OBSMantis:SetSAMRange(75)                  -- engage at 75% of max range (0-100). Removed duplicate SetSAMRange(110).

-- CHANGED: use the method, not the property. Set to false to keep SAMs on their
-- designed grid squares (matches sam_network.md). Flip to true if you want roaming SAMs.
OBSMantis:SetAutoRelocate(false)

-- DISABLED for players: these two lines were flooding the screen during your test flight.
-- Debug(true)  -> on-screen "Check: Checking SAM..." / "Looking at Group..." messages + DCS.log tracing
-- verbose=true -> on-screen "MANTIS Status" box (SAM RED/GREEN/SHORAD counts)
-- Re-enable temporarily ONLY while tuning the IADS, then comment out again before players fly.
-- OBSMantis:Debug(true)
-- OBSMantis.verbose = true

OBSMantis:Start()
