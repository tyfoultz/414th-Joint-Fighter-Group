-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Splash Damage 3.4.2 — Standalone Configuration Override
--
-- USAGE: In the Mission Editor, create two DO SCRIPT FILE triggers at MISSION START:
--   1. First:  Splash_Damage_3.4.2_Standard_With_Ground_Ordnance.lua   (the main script)
--   2. Second: This file (splash_damage_config.lua)                     (overrides defaults)
--
-- This file overrides the defaults defined inside the main script.
-- Retribution-compatible: uses the same variable names and structure.
-- Every setting from the full 3.4.2 script is listed below, grouped by feature.
-- Uncomment and change any value you want to test. Commented lines = script default stays.
-------------------------------------------------------------------------------------------------------------------------------------------------------------


--==============================================================================================================================================================
--  SECTION 1: RETRIBUTION-EXPOSED SETTINGS
--  These are the settings Retribution's UI lets you configure. Values below match the Retribution defaults from your screenshot.
--==============================================================================================================================================================

-------- Debug & Messages --------
splash_damage_options.game_messages                 = true      -- Show on-screen text when explosions happen
splash_damage_options.debug                         = false     -- Detailed diagnostics to DCS.log
splash_damage_options.weapon_missing_message         = false     -- Alert when a weapon isn't in the explosion table
splash_damage_options.enable_radio_menu              = false     -- F10 radio menu to tweak settings in-game

-------- Core Explosion Behavior --------
splash_damage_options.wave_explosions                = true      -- Blast wave: secondary explosions radiating outward from impact, scaled by object size/distance
splash_damage_options.larger_explosions              = true      -- Extra explosion at impact point using per-weapon values from the built-in table
splash_damage_options.use_dynamic_blast_radius       = true      -- Calculate blast radius from weapon power (false = fixed 90m radius)
splash_damage_options.dynamic_blast_radius_modifier  = 1         -- Multiplier on the dynamic radius (Retribution divides UI value by 100, so UI "1" = script 0.01... but default script value is 2)
splash_damage_options.damage_model                   = true      -- Blast wave can disable ground unit movement/weapons based on health thresholds
splash_damage_options.static_damage_boost            = 1         -- Extra damage to buildings/structures (DCS structures are tanky; raise to make bombs more effective vs buildings)
splash_damage_options.overall_scaling                = 0.7       -- Global multiplier on all explosive power (Retribution divides UI value by 100)

-------- Unit Health Thresholds (requires damage_model = true) --------
splash_damage_options.unit_disabled_health            = 30       -- Below this HP%, ground unit can't move
splash_damage_options.unit_cant_fire_health           = 40       -- Below this HP%, ground unit ROE set to HOLD (simulates busted weapons)
splash_damage_options.infantry_cant_fire_health       = 60       -- Same for infantry (higher because infantry are fragile)

-------- Cluster Munitions --------
splash_damage_options.cluster_enabled                     = true      -- Enable the script's cluster bomb spread simulation
splash_damage_options.cluster_bomblet_reductionmodifier    = true      -- Use equation to reduce bomblet count (looks more realistic)
splash_damage_options.cluster_bomblet_damage_modifier      = 1         -- Global multiplier for individual bomblet explosive power

-------- Rockets --------
splash_damage_options.rocket_multiplier              = 0.8       -- Multiplier on rocket explosive values. Tuned down for smaller splash AoE (APKWS/Hydra etc.); native direct-hit damage is unaffected.

-------- Retribution-Specific --------
splash_damage_options.shipRadarDamageEnable          = true      -- ARMs (HARMs etc.) can damage/disable ship radar systems
splash_damage_options.oca_aircraft_damage_boost       = 1         -- Extra damage to parked aircraft from wave explosions (OCA/airfield attack)

-------- Ordnance Protection (prevents bombs in a stick from fratricide mid-air) --------
splash_damage_options.ordnance_protection                            = true     -- Shield falling bombs from sibling explosions
splash_damage_options.ordnance_protection_radius                     = 800      -- Protection radius in meters (Retribution uses 800; script default is 20)
splash_damage_options.detect_ordnance_destruction                    = true     -- Detect when a bomb is destroyed mid-air by another explosion
splash_damage_options.snap_to_ground_if_destroyed_by_large_explosion = false    -- If a bomb IS fratricide'd, place its explosion on the ground anyway
splash_damage_options.max_snapped_height                             = 80       -- Only snap-to-ground if destroyed bomb was below this altitude AGL
splash_damage_options.recent_large_explosion_snap                    = true     -- Check for a recent nearby script explosion before snapping (avoids duplicates)
splash_damage_options.recent_large_explosion_range                   = 100      -- Radius (m) to check for recent explosion
splash_damage_options.recent_large_explosion_time                    = 4        -- How far back (sec) to look

-------- Ground Unit Ordnance Tracking --------
splash_damage_options.groundunitordnance_damage_modifier             = 1        -- Multiplier for shell explosive power (tanks, artillery)
splash_damage_options.groundunitordnance_blastwave_modifier          = 2        -- Additional multiplier for blast wave intensity from ground unit shells

-------- Critical Component (lucky shot instant-kill) --------
splash_damage_options.CriticalComponent                  = false    -- Enable random chance that a single hit kills a vehicle
splash_damage_options.CriticalComponent_Chance           = 0.01     -- Probability per hit (0.01 = 1%)
splash_damage_options.CriticalComponent_Explosion_Power  = 50       -- Size of the explosion when a crit triggers


--==============================================================================================================================================================
--  SECTION 2: ADDITIONAL SETTINGS NOT EXPOSED BY RETRIBUTION
--  These exist in the full script but Retribution's UI doesn't surface them.
--  All values below are the SCRIPT DEFAULTS. Uncomment any line to override.
--==============================================================================================================================================================

-------- Debug Flags (one per subsystem — turn on to troubleshoot specific features) --------
-- splash_damage_options.track_pre_explosion_debug          = false     -- Pre-explosion tracking debug
-- splash_damage_options.track_groundunitordnance_debug     = false     -- Ground ordnance tracking debug
-- splash_damage_options.napalm_unitdamage_debug            = false     -- Napalm damage debug
-- splash_damage_options.damage_model_game_messages         = false     -- On-screen messages when units get movement/weapons disabled
-- splash_damage_options.killfeed_debug                     = false     -- Kill feed debug
-- splash_damage_options.events_debug                       = false     -- All event handler logging (VERY noisy)
-- splash_damage_options.vehicleied_debug                   = false     -- Vehicle IED debug
-- splash_damage_options.MurderMode_debug                   = false     -- Murder Mode debug
-- splash_damage_options.trophy_debug                       = false     -- Trophy APS debug
-- splash_damage_options.cargocookoff_debug                 = false     -- Cargo cook-off debug
-- splash_damage_options.CriticalComponent_debug            = false     -- Critical Component debug
-- splash_damage_options.GU_Explode_debug                   = false     -- Ground Unit Explode on Death debug
-- splash_damage_options.CBU_Bomblet_Hit_debug              = false     -- CBU Bomblet Hit debug
-- splash_damage_options.StrobeMarker_debug                 = false     -- Strobe Marker debug

-------- Fixed Blast Radius (only used if use_dynamic_blast_radius = false) --------
-- splash_damage_options.blast_search_radius                = 90        -- Fixed blast wave search radius in meters

-------- Player-Only Tracking --------
-- splash_damage_options.only_players_weapons               = false     -- true = only track weapons launched by players (ignore AI weapons)

-------- Shaped Charge Munitions (ATGMs, Mavericks, etc.) --------
-- splash_damage_options.apply_shaped_charge_effects        = true      -- Reduce blast radius for shaped charge weapons (realistic: they focus energy forward, not outward)
-- splash_damage_options.shaped_charge_multiplier           = 0.2       -- How much to reduce blast radius/power (0.2 = 80% reduction)

-------- Cascading Explosions (chain reactions when units near the blast are already damaged) --------
-- splash_damage_options.cascade_scaling                    = 2         -- Multiplier for secondary cascade blast damage (1 fades too fast, 2-3 is good)
-- splash_damage_options.cascade_damage_threshold           = 0.1       -- Minimum calculated damage to trigger a cascade explosion (prevents tiny distant pops)
-- splash_damage_options.cascade_explode_threshold          = 60        -- Unit must be at or below this HP% to cascade (blows up jeeps, spares tanks)
-- splash_damage_options.always_cascade_explode             = false     -- true = everything in the blast chain-explodes like the original script

-------- Cargo Cook-Off / Fuel Truck Explosions --------
-- splash_damage_options.track_pre_explosion                = true      -- Track unit state before explosions (needed for cook-off to work)
-- splash_damage_options.enable_cargo_effects               = true      -- Enable fuel truck fireballs and ammo truck cook-offs
-- splash_damage_options.cargo_effects_chance               = 1         -- Chance of cargo effects (1 = 100%, 0.5 = 50%)
-- splash_damage_options.cargo_damage_threshold             = 25        -- HP% below which cargo explodes (0 = only on full destruction)
-- splash_damage_options.debris_effects                     = true      -- Debris flies out from cook-offs
-- splash_damage_options.debris_power                       = 1         -- Explosive power of each debris piece
-- splash_damage_options.debris_count_min                   = 6         -- Min debris pieces per cook-off
-- splash_damage_options.debris_count_max                   = 12        -- Max debris pieces per cook-off
-- splash_damage_options.debris_max_distance                = 8         -- Max debris travel distance (meters)

-------- Cook-Off Flare Effects --------
-- splash_damage_options.cookoff_flares_enabled             = true      -- Phosphor-style flare sparks shoot out during cook-offs
-- splash_damage_options.cookoff_flare_color                = 2         -- Flare color index
-- splash_damage_options.cookoff_flare_instant              = true      -- true = all flares spawn instantly; false = spawn over time
-- splash_damage_options.cookoff_flare_instant_min          = 2         -- Min instant flares
-- splash_damage_options.cookoff_flare_instant_max          = 5         -- Max instant flares
-- splash_damage_options.cookoff_flare_count_modifier       = 1         -- Multiplier for non-instant flare count
-- splash_damage_options.cookoff_flare_offset               = 0.5       -- Max horizontal offset for flare spawn (meters)
-- splash_damage_options.cookoff_flare_chance               = 0.5       -- Chance flares fire (1 = 100%)

-------- All-Vehicle Smoke & Cook-Off (vehicles NOT in the cargoUnits table) --------
-- splash_damage_options.smokeandcookoffeffectallvehicles           = true      -- Enable smoke/cook-off for ALL ground vehicles
-- splash_damage_options.allunits_enable_smoke                      = true      -- Enable smoke effects
-- splash_damage_options.allunits_enable_cookoff                    = true      -- Enable cook-off effects
-- splash_damage_options.allunits_damage_threshold                  = 25        -- HP% below which effects trigger
-- splash_damage_options.allunits_explode_power                     = 40        -- Initial vehicle explosion power
-- splash_damage_options.allunits_default_flame_size                = 6         -- Smoke size: 5=small, 6=medium, 7=large, 8=huge (smoke only; 1-4 = smoke+fire)
-- splash_damage_options.allunits_default_flame_duration            = 240       -- How long smoke persists (seconds)
-- splash_damage_options.allunits_cookoff_count                     = 4         -- Number of cook-off pops scheduled
-- splash_damage_options.allunits_cookoff_duration                  = 30        -- Time window for cook-off pops (randomly spread across 0 to this)
-- splash_damage_options.allunits_cookoff_power                     = 10        -- Power of each cook-off pop
-- splash_damage_options.allunits_cookoff_powerrandom               = 50        -- +/- random variance on cook-off power (%)
-- splash_damage_options.allunits_cookoff_chance                    = 0.4       -- Chance of cook-off (0.4 = 40%)
-- splash_damage_options.allunits_smokewithcookoff                  = true      -- Auto-add smoke whenever a cook-off triggers
-- splash_damage_options.allunits_smoke_chance                      = 0.7       -- Chance of smoke-only effect (if cook-off doesn't trigger)
-- splash_damage_options.allunits_explode_on_smoke_only             = true      -- If smoke-only, still add an explosion to finish the vehicle

-------- Advanced Effect Sequence (scripted multi-phase smoke/fire/cook-off timeline) --------
-- splash_damage_options.allunits_advanced_effect_sequence               = true         -- Enable advanced sequences (overrides standard cook-off when triggered)
-- splash_damage_options.allunits_advanced_effect_sequence_chance        = 0.2          -- Chance this triggers instead of standard (0.2 = 20%)
-- splash_damage_options.allunits_advanced_effect_force_on_name          = true         -- Force advanced sequence on units with "AdvSeq" in their name
-- splash_damage_options.allunits_advanced_effect_order                  = {"2", "7", "6", "5"}    -- Sequence of effects (1-4=smoke+fire, 5-8=smoke only, sizes small→huge)
-- splash_damage_options.allunits_advanced_effect_timing                 = {"30", "90", "120", "600"} -- Duration in seconds for each step above
-- splash_damage_options.allunits_advanced_effect_cookoff_chance         = 1            -- Chance of cook-off during advanced sequence
-- splash_damage_options.allunits_advanced_effect_cookoff_count          = 4            -- Cook-off pops in advanced sequence
-- splash_damage_options.allunits_advanced_effect_cookoff_duration       = 30           -- Time window for advanced cook-off pops
-- splash_damage_options.allunits_advanced_effect_cookoff_power          = 10           -- Power of each advanced cook-off pop
-- splash_damage_options.allunits_advanced_effect_cookoff_powerrandom    = 50           -- +/- variance (%)
-- splash_damage_options.allunits_advanced_effect_cookoff_flares_enabled = true         -- Phosphor flares during advanced sequence
-- splash_damage_options.allunits_advanced_effect_explode_power          = 40           -- Initial explosion power in advanced sequence

-------- Cluster Bomb Spread (full settings beyond the Retribution-exposed ones) --------
-- splash_damage_options.cluster_base_length            = 150       -- Base forward spread (meters)
-- splash_damage_options.cluster_base_width             = 200       -- Base lateral spread (meters)
-- splash_damage_options.cluster_max_length             = 300       -- Max forward spread
-- splash_damage_options.cluster_max_width              = 400       -- Max lateral spread
-- splash_damage_options.cluster_min_length             = 100       -- Min forward spread
-- splash_damage_options.cluster_min_width              = 150       -- Min lateral spread

-------- Giant Explosions (units named "GiantExplosionTarget(X)" blow up spectacularly) --------
-- splash_damage_options.giant_explosion_enabled        = false     -- Master toggle
-- splash_damage_options.giant_explosion_power          = 6000      -- Power in kg TNT equivalent
-- splash_damage_options.giant_explosion_scale          = 1         -- Visual size scale factor
-- splash_damage_options.giant_explosion_duration       = 3.0       -- Total explosion duration (seconds)
-- splash_damage_options.giant_explosion_count          = 250       -- Number of sub-explosions in the effect
-- splash_damage_options.giantexplosion_ondamage        = true      -- Trigger on damage (not just death)
-- splash_damage_options.giantexplosion_ondeath         = true      -- Trigger on destruction
splash_damage_options.giantexplosion_testmode        = false     -- Adds radio commands for testing

-------- Ground/Ship Ordnance (full settings) --------
-- splash_damage_options.track_groundunitordnance               = true      -- Track shells from ground units for splash effects
-- splash_damage_options.groundunitordnance_maxtrackedcount     = 100       -- Max tracked shells at once (performance limiter)
-- splash_damage_options.scan_50m_for_groundordnance            = true      -- Use fixed 50m scan instead of dynamic radius for ground shells

-------- Napalm (MK-77 and override weapons) --------
-- splash_damage_options.napalm_mk77_enabled           = true      -- Enable napalm effects for MK-77 bombs
-- splash_damage_options.napalmoverride_enabled         = false     -- Enable napalm effects for custom weapons (list below)
-- splash_damage_options.napalm_override_weapons        = "Mk_82,SAMP125LD"  -- Comma-separated weapon names to treat as napalm
-- splash_damage_options.napalm_spread_points           = 4         -- Fireball spawn points per bomb (more = longer fire line)
-- splash_damage_options.napalm_spread_spacing          = 25        -- Distance between fireballs (meters)
-- splash_damage_options.napalm_phosphor_enabled        = true      -- White phosphor-style flare sparks
-- splash_damage_options.napalm_phosphor_multiplier     = 0.5       -- Flare count multiplier
-- splash_damage_options.napalm_addflame               = true      -- Persistent fire effect at napalm points
-- splash_damage_options.napalm_addflame_size           = 3         -- Flame size (1-4 small→huge fire+smoke, 5-8 smoke only)
-- splash_damage_options.napalm_addflame_duration       = 180       -- How long fire burns (seconds)
-- splash_damage_options.napalm_flame_delay             = 0.01      -- Delay before flame spawns (seconds)
-- splash_damage_options.napalm_explode_delay           = 0.01      -- Delay before ground explosion
-- splash_damage_options.napalm_destroy_delay           = 0.02      -- Delay before fuel tank prop is cleaned up
-- splash_damage_options.napalm_doublewide_enabled      = false     -- Double-width napalm (two fire points per spread point, ~28m wide)
-- splash_damage_options.napalm_doublewide_spread       = 15        -- Meters to each side for double-wide
-- splash_damage_options.napalm_unitdamage_enable       = true      -- Napalm damages units in the fire zone
-- splash_damage_options.napalm_unitdamage_scandistance = 70        -- Scan radius for napalm damage (meters)
-- splash_damage_options.napalm_unitdamage_startdelay   = 0.1       -- Delay between napalm landing and damage starting
-- splash_damage_options.napalm_unitdamage_spreaddelay  = 0         -- Gap between per-unit damage ticks (ordered by distance)

-------- Kill Feed (MP only — tracks and displays kills from splash damage) --------
-- splash_damage_options.killfeed_enable                       = false     -- Master toggle (required for Lekas Foothold)
-- splash_damage_options.killfeed_game_messages                = false     -- Show kill messages on screen
-- splash_damage_options.killfeed_game_message_duration        = 15        -- How long kill messages stay on screen (seconds)
-- splash_damage_options.killfeed_splashdelay                  = 8         -- Wait time to let DCS register kills before attributing to splash (seconds)
-- splash_damage_options.killfeed_lekas_foothold_integration   = false     -- Feed splash kills into Lekas Foothold point system
-- splash_damage_options.killfeed_lekas_contribution_delay     = 240       -- Delay before processing splash kills into Lekas (seconds)

-------- Vehicle IEDs (units named "VehicleIEDTarget" or "VBID" explode massively) --------
-- splash_damage_options.vehicleied_enabled             = false     -- Master toggle
-- splash_damage_options.vehicleied_targetname          = "VehicleIEDTarget,VBID"  -- Comma-separated name triggers
-- splash_damage_options.vehicleied_scaling             = 1         -- Global scaling for all IED explosion values
-- splash_damage_options.vehicleied_central_power       = 600       -- Central explosion power
-- splash_damage_options.vehicleied_explosion_power     = 400       -- Secondary explosion base power
-- splash_damage_options.vehicleied_explosion_count_min = 10        -- Min secondary explosions
-- splash_damage_options.vehicleied_explosion_count_max = 14        -- Max secondary explosions
-- splash_damage_options.vehicleied_power_variance      = 0.3       -- Random power variance (+/- 30%)
-- splash_damage_options.vehicleied_radius              = 35        -- Max radius for secondary explosions (meters)
-- splash_damage_options.vehicleied_explosion_delay_max = 0.4       -- Max delay multiplier for staggered secondaries
-- splash_damage_options.vehicleied_fueltankspawn       = true      -- Spawn a fuel tank for fire/smoke visual
-- splash_damage_options.vehicleied_destroy_vehicle     = false     -- Instantly destroy the vehicle (can glitch smoke)
-- splash_damage_options.vehicleied_explode_on_hit      = true      -- Explode on hit event (false = only on death)

-------- A-10 / Named Unit Murder Mode (extra explosion on every hit event) --------
-- splash_damage_options.A10MurderMode                  = false     -- Every A-10 hit spawns an explosion on target
-- splash_damage_options.A10MurderMode_Power            = 5         -- Explosion power per hit
-- splash_damage_options.A10MurderMode__Chance          = 1         -- Chance per hit (1 = 100%)
-- splash_damage_options.NamedUnitMurderMode            = false     -- Same as above but for any unit with "MurderMode" in pilot name
-- splash_damage_options.NamedUnitMurderMode_Power      = 5         -- Explosion power
-- splash_damage_options.NamedUnitMurderMode_Chance     = 1         -- Chance per hit

-------- Trophy APS (Active Protection System simulation for named vehicles) --------
-- splash_damage_options.trophy_enabled                 = false     -- Master toggle
-- splash_damage_options.trophy_selfExplosionSize       = 1         -- Explosion at launcher point (mimics Trophy firing)
-- splash_damage_options.trophy_explosionOffsetDistance  = 2         -- Launcher offset from vehicle center (meters)
-- splash_damage_options.trophy_weaponExplosionSize     = 20        -- Explosion to destroy incoming weapon
-- splash_damage_options.trophy_detectRange             = 200       -- Start fast-tracking incoming weapon at this range (meters)
-- splash_damage_options.trophy_interceptRange          = 30        -- Intercept at this range (meters)
-- splash_damage_options.trophy_frontRightRounds        = 4         -- Rounds in front-right launcher
-- splash_damage_options.trophy_backLeftRounds          = 4         -- Rounds in back-left launcher
-- splash_damage_options.trophy_failureChance           = 0.00      -- Chance interception fails (0.05 = 5%)
-- splash_damage_options.trophy_markShooterOrigin       = true      -- Mark shooter origin on the F10 map
-- splash_damage_options.trophy_drawOriginLine          = true      -- Draw line from tank to shooter on F10 map
-- splash_damage_options.trophy_maxMapMarkerDistance     = 1000      -- Max distance for map marker/line (meters)
-- splash_damage_options.trophy_markerDuration          = 120       -- How long map markers last (seconds)
-- splash_damage_options.trophy_showInterceptionMessage  = true      -- Show interception message on screen
-- splash_damage_options.trophy_messageDuration         = 10        -- How long interception message displays (seconds)

-------- Critical Component (full settings) --------
-- splash_damage_options.CriticalComponent_Specific_Weapons_Only = {"GAU8_30_HE", "GAU8_30_AP", "GAU8_30_TP"}  -- {} = all weapons; or list specific weapon names

-------- Ground Unit Explosion on Death (vehicles pop when they start burning) --------
-- splash_damage_options.GU_Explode_on_Death                = true      -- Trigger explosion when vehicle starts its "on fire" death animation
-- splash_damage_options.GU_Explode_on_Death_Chance         = 0.5       -- Chance it triggers (0.5 = 50%); units with "GUED" in name always trigger
-- splash_damage_options.GU_Explode_on_Death_Explosion_Power = 30       -- Explosion power
-- splash_damage_options.GU_Explode_on_Death_Height         = 1         -- Height above ground (low = more dirt, high = more smoke puff)
-- splash_damage_options.GU_Explode_Exclude_Infantry        = true      -- true = infantry don't pop; false = they do

-------- CBU Bomblet Hit Spread (scans area around bomblet hits for more targets) --------
-- splash_damage_options.CBU_Bomblet_Hit_Explosion              = false     -- Master toggle (tested primarily with JSOW-A)
-- splash_damage_options.CBU_Bomblet_Hit_Explosion_Scaling      = 35        -- Overall damage multiplier for bomblet hits
-- splash_damage_options.CBU_Bomblet_Hit_Mimic_Spread           = true      -- Scan area around hit target for additional units to damage
-- splash_damage_options.CBU_Bomblet_Hit_Spread                 = 50        -- Primary scan radius (meters)
-- splash_damage_options.CBU_Bomblet_Hit_Spread_SecondaryScan   = 50        -- Secondary scan radius from found units (meters)
-- splash_damage_options.CBU_Bomblet_Hit_Spread_Duration        = 2         -- Spread additional explosions over this many seconds
-- splash_damage_options.CBU_Bomblet_NonArmored_Dmg_Modifier    = 1.0       -- Damage multiplier vs unarmored (trucks, infantry)
-- splash_damage_options.CBU_Bomblet_LightlyArmored_Dmg_Modifier = 0.8     -- Damage multiplier vs light armor (BTR, ZSU)
-- splash_damage_options.CBU_Bomblet_Armored_Dmg_Modifier       = 0.6       -- Damage multiplier vs heavy armor (T-90, BMP-3)
-- splash_damage_options.CBU_Bomblet_Hit_Chance                 = 0.8       -- Chance a found unit gets hit (0.8 = 80%)
-- splash_damage_options.CBU_Bomblet_Indirect_Hit_Chance        = 0.2       -- Chance the hit is indirect/glancing
-- splash_damage_options.CBU_Bomblet_Indirect_Dmg_Modifier      = 0.4       -- Damage reduction for indirect hits (0.4 = 40% damage)
-- splash_damage_options.CBU_Bomblet_Explosion_Height           = 0.1       -- Height offset for bomblet explosions (ground-level = more dirt kick-up)

-------- Strobe Marker / Beacon (units with "Strobe" in name pulse a visible flash — good for FAC marking) --------
-- splash_damage_options.StrobeMarker_allstrobeunits    = false     -- Auto-strobe all living units with "Strobe" in name
-- splash_damage_options.StrobeMarker_individuals       = false     -- Enable/disable individual strobes via radio commands
-- splash_damage_options.StrobeMarker_interval          = 2         -- Seconds between strobe flashes

-------- Tactical Explosion (large scripted explosion, like IED but bigger — can be assigned to weapons) --------
-- splash_damage_options.tactical_explosion                         = false     -- Master toggle
-- splash_damage_options.tactical_explosion_override_enabled        = false     -- Enable weapon override list
-- splash_damage_options.tactical_explosion_override_weapons        = "BGM_109B,Mk_82"  -- Weapons to treat as tactical explosions
-- splash_damage_options.tactical_explosion_max_height              = 40        -- Only trigger below this altitude AGL (meters)
-- splash_damage_options.tactical_explosion_scaling                 = 1         -- Global scaling for tactical explosion values
-- splash_damage_options.tactical_explosion_central_power           = 4000      -- Central explosion power
-- splash_damage_options.tactical_explosion_explosion_power         = 1000      -- Secondary explosion base power
-- splash_damage_options.tactical_explosion_explosion_count_min     = 35        -- Min secondary explosions
-- splash_damage_options.tactical_explosion_explosion_count_max     = 35        -- Max secondary explosions
-- splash_damage_options.tactical_explosion_radius                  = 100       -- Max radius for secondaries (meters)
-- splash_damage_options.tactical_explosion_explosion_delay_max     = 0.4       -- Max delay multiplier for staggered secondaries
-- splash_damage_options.tactical_explosion_fueltankspawn           = false     -- Spawn fuel tank for fire/smoke visual


env.info("Splash Damage config override loaded successfully")
