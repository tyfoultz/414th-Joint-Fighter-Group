# 414st Joint Fighter Squadron — DCS Scripts Repository

## What This Is

Shared DCS World Lua scripts for the 414st Joint Fighter Squadron's multiplayer sessions. Scripts here are loaded into DCS missions via the Mission Editor and run server-side during gameplay.

## DCS Scripting Environment

- **Lua 5.1** — no `goto`, no 5.3+ features. Standard DCS scripting API: `coalition`, `Unit`, `Group`, `Object`, `Weapon`, `trigger.action`, `timer`, `land`, `world`, `missionCommands`, `AI.Option`. No `os`/`io` (server-side sandbox).
- **No local Lua interpreter.** You cannot run or compile scripts here. Validation = careful reading. When making changes, tell the user what to watch for in-game.
- **Definition order matters.** Functions must be defined above their first use. If adding a helper, place it before its callers.
- **All vanilla DCS units.** No mods (no HighDigitSAMs, etc.). Scripts should only reference units that ship with base DCS.

## Script Loading

Scripts are loaded in the DCS Mission Editor via **DO SCRIPT FILE** triggers at mission start. Load order matters:

1. `Moose.lua` (MOOSE framework — NOT included in this repo)
2. Mission-specific scripts (IADS, CAP, EW, etc.)
3. Config overrides (e.g., `splash_damage_config.lua`)

MOOSE-dependent scripts (`scripts/iads/`, `scripts/cap/`) will crash if Moose.lua hasn't loaded first.

## Repository Structure

### `scripts/iads/` — MANTIS IADS
MOOSE MANTIS-based Integrated Air Defense System setup. Manages red SAM network behavior: detection intervals, max active sites, engagement ranges, auto-relocation.

Key classes: `MANTIS`, `SET_GROUP`, `ZONE`.

### `scripts/cap/` — AI A2A Dispatcher
MOOSE `AI_A2A_DISPATCHER` for red AI air defense. Layered CAP + GCI across inner/middle/outer rings of airbases. Manages squadron assignments, patrol orbits, engagement/disengage radii, replacement intervals.

Key classes: `AI_A2A_DISPATCHER`, `DETECTION_AREAS`, `SET_GROUP`, `ZONE`, `ZONE_POLYGON`, `AIRBASE`, `TIMER`, `MESSAGE`.

### `scripts/splash-damage/` — Splash Damage 3.4.2
Third-party splash damage script by stevey9062. The main script (`Splash_Damage_3.4.2.lua`) is loaded first; the config override (`splash_damage_config.lua`) is loaded second and overrides defaults via `splash_damage_options.*` variables. See the config file's inline comments for every tunable.

### `scripts/ew-jamming/` — Electronic Warfare

Two independent EW systems:

**EW Script 2.1** (`EW_script_2.1.lua`) — Original by ESA_Matador, adapted for Retribution by Drexyl. Defensive/offensive jamming via proximity bubble layers around designated jammer aircraft. Uses F10 radio menu activation. Standalone, no MOOSE dependency.

**C-130J-30 Mission Systems** (`C-130J-30 Mission Systems.lua`) — ~2,000-line script turning the C-130J into an EC-130H Compass Call (EW) + RC-130H Rivet Joint (ISR) platform. Player-only, static slots only. Features:
- EW: Area/directional/spot jamming, missile spoofing, energy management, pod loadout selection
- ISR: Passive radar detection, two-phase ELINT tracking with map marks, auto-triangulation, SIGINT reports
- Crew coordination: handoff briefs to friendly player groups

**Read `C-130J-30 Mission Systems HANDOFF.md` before editing the C-130 script.** It contains the full architecture, hard constraints (no `enableEmission` toggling — it crashes), file structure, data tables, config knobs, and messaging conventions. The player-facing reference is `C-130J-30 Mission Systems Overview.txt` and must be kept in sync with code changes.

Critical C-130 constraints:
- Do NOT toggle SAM radar emissions (`enableEmission(false)` caused crashes). Suppression is ROE `WEAPON_HOLD` only.
- Burn-through model is intentional: jam probability RISES with distance. Don't flip it.
- Spot jamming has flat altitude-independent range. Don't add altitude gating.
- Missile spoof curve is intentionally steep at close range. Don't flatten it.

## Agent Guidance

1. **Read before editing.** These scripts run in a sandboxed Lua 5.1 environment with no way to test locally. Be conservative; prefer small, verifiable edits.
2. **Preserve load order.** Function definitions must precede their callers. Check before moving code.
3. **Vanilla DCS units only.** If you encounter a modded unit reference, flag it.
4. **For MOOSE questions**, consult the MOOSE documentation (FlightControl-Master/MOOSE on GitHub). Key classes used here: MANTIS, AI_A2A_DISPATCHER, DETECTION_AREAS, SET_GROUP, ZONE, ZONE_POLYGON, TIMER, MESSAGE.
5. **For the C-130 EW script**, always read the HANDOFF.md first. It's the authoritative developer reference.
6. **Keep player-facing docs in sync.** If you change the C-130 script behavior, update the Overview.txt in the same change.
