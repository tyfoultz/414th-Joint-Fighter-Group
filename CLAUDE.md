# 414th Joint Fighter Group — DCS Scripts & Missions

## WHERE TO PUSH — READ THIS FIRST

**All scripting and mission-generator work goes to `bradyccox/414Ret`.** That is the 414th's fork of DCS Retribution and is the canonical repo for everything that ends up in the dynamic campaign. Local path: `414Ret/` (gitignored here).

**This repo (`tyfoultz/414th-Joint-Fighter-Group`) is for standalone DCS scripts only** — things loaded directly in the Mission Editor that have no dependency on Retribution. If you are unsure which repo a change belongs in, it almost certainly belongs in 414Ret.

Do **not** create PRs from `bradys-changes` on this repo for Retribution-related work. Push to `bradyccox/414Ret` instead.

## What This Is

DCS World scripts and mission-building workspace for the 414th Joint Fighter Group. The repo has two layers:

- **`scripts/` and `references/`** — shared on GitHub, collaborative
- **`missions/`** — local only (gitignored), contains campaign plans, .miz files, and mission-specific docs that shouldn't be public

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

### `scripts/iads/` — MANTIS IADS (tracked)
MOOSE MANTIS-based Integrated Air Defense System setup. Manages red SAM network behavior: detection intervals, max active sites, engagement ranges, auto-relocation.

### `scripts/cap/` — Red Air Defense (tracked)

**AI A2A Dispatcher** — MOOSE `AI_A2A_DISPATCHER` for red AI air defense. Layered CAP + GCI across inner/middle/outer rings of airbases. Manages squadron assignments, patrol orbits, engagement/disengage radii, replacement intervals.

**Reactive Scramble** (`reactive_scramble.lua`) — Standalone (MOOSE-dependent) cold-ramp GCI interceptor system. Hand-placed RED fighter/interceptor groups whose name contains "Scramble" and that are **set Uncontrolled in the ME** sit cold on the ramp doing nothing until a Blue aircraft is detected by the RED radar network within `CFG_engageRadius`, then the nearest one is woken (`GROUP:StartUncontrolled()` → cold start, taxi, takeoff) and tasked to intercept via `setTask(EngageTargets)`. Only air-to-air aircraft (DCS attributes `Fighters`/`Interceptors`) are eligible; SEAD-named groups are excluded. Radar-range based only — zone mode was removed in v2.0. Tunables at top of file: `CFG_scanInterval`, `CFG_engageRadius`, `CFG_reengageDelay`, `CFG_spawnDelay`. (A Retribution-plugin variant lives in the retribution repo at `resources/plugins/scramble/reactive_scramble.lua`. It does **not** key off group names — instead the mission generator collects RED untasked uncontrolled A/A aircraft into `dcsRetribution.scramble_pool` and the script wakes those. It requires the "Disable untasked OPFOR aircraft at airfields" setting to be **unchecked** so the pool exists.)

### `scripts/splash-damage/` — Splash Damage 3.4.2 (tracked)
Third-party splash damage script by stevey9062. Main script loaded first; config override loaded second. See config file comments for every tunable.

### `scripts/ew-jamming/` — Electronic Warfare (tracked)

**EW Script 2.1** (`EW_script_2.1.lua`) — Original by ESA_Matador, adapted for Retribution by Drexyl. Defensive/offensive jamming via proximity bubble layers. Standalone, no MOOSE dependency.

**C-130J-30 Mission Systems** (`C-130J-30 Mission Systems.lua`) — ~2,000-line script turning the C-130J into an EC-130H Compass Call (EW) + RC-130H Rivet Joint (ISR) platform. Player-only, static slots only. Features:
- EW: Area/directional/spot jamming, missile spoofing, energy management, pod loadout selection
- ISR: Passive radar detection, two-phase ELINT tracking with map marks, auto-triangulation, SIGINT reports
- Crew coordination: handoff briefs to friendly player groups

**Read `C-130J-30 Mission Systems HANDOFF.md` before editing the C-130 script.** It contains the full architecture, hard constraints, file structure, data tables, config knobs, and messaging conventions. The player-facing reference is `C-130J-30 Mission Systems Overview.txt` — keep it in sync with code changes.

Critical C-130 constraints:
- Do NOT toggle SAM radar emissions (`enableEmission(false)` caused crashes). Suppression is ROE `WEAPON_HOLD` only.
- Burn-through model is intentional: jam probability RISES with distance. Don't flip it.
- Spot jamming has flat altitude-independent range. Don't add altitude gating.
- Missile spoof curve is intentionally steep at close range. Don't flatten it.

### `references/` — DCS & MOOSE Reference Docs (tracked)
- `DCS_Instructions.md` — General DCS guidance (Chuck's Guides for modules, Retribution wiki)
- `moose_tic_mantis_reference.md` — MOOSE framework + Troops in Contact + MANTIS IADS reference. Load when working with mission scripting, AI ground combat, or IADS setup.
- `splash_damage_reference.html` — Splash Damage feature reference
- `DCS User Manual EN.pdf` — Official DCS manual (gitignored due to size, local only)

### `missions/` — Campaign & Mission Files (LOCAL ONLY, gitignored)

**Not pushed to GitHub.** Contains campaign plans, narrative, .miz files, extracted mission data, and maps.

#### `missions/operation-broken-chain/`
4-mission campaign for the 414th JFG. Syria map, 16-25 human players, all red AI. Key files:
- `operation_broken_chain.md` — Master campaign plan (narrative, force structure, taskings, mission design)
- `sam_network.md` — SAM network layout, SEAD target list, ME unit compositions
- `campaign_backstory.md` — Campaign narrative backstory
- `campaign_brief.html` — Styled campaign briefing
- `sam_threat_chart.html` — SAM threat visualization
- `gci_cap_setup.md` — GCI/CAP design notes
- `dispatcher_migration_plan.md` — Migration notes for the A2A dispatcher
- `Syria_map_origin.jpg` — Annotated map (front line, blue/red territory)
- `.miz` files — Mission Editor save files
- `miz_*_extracted/` — Extracted mission internals for diffing/inspection

Campaign decisions (defer to `operation_broken_chain.md` for full detail):
- 4 missions: Cut the Path, The Run, Hold the Line, Counter-Punch
- Front line at Turkish-Syrian border. Blue = Turkey + Cyprus + carrier. Red = all Syria.
- Aleppo International is a blue pocket inside red territory
- Minakh airfield is the FARP
- Carrier in Eastern Med (~100-130nm from Aleppo)
- Red airbases: Kuweires, Jirah, Abu al-Duhur, Taftanaz
- Enemy: Syrian regime with Russian equipment, vanilla DCS units only
- MOOSE available for scripting (MANTIS IADS, AI_A2A_DISPATCHER, optional TIC)
- Cold start, day missions, fun over realism

#### `missions/retribution/`
Retribution dynamic campaign files and save comparisons.

## Agent Guidance

1. **Read before editing.** Scripts run in sandboxed Lua 5.1 with no way to test locally. Be conservative; prefer small, verifiable edits.
2. **Preserve load order.** Function definitions must precede their callers.
3. **Vanilla DCS units only.** Flag any modded unit references.
4. **For MOOSE questions**, consult `references/moose_tic_mantis_reference.md` first, then MOOSE GitHub docs.
5. **For the C-130 EW script**, always read `scripts/ew-jamming/C-130J-30 Mission Systems HANDOFF.md` first.
6. **For Operation Broken Chain**, defer to existing campaign decisions in `missions/operation-broken-chain/operation_broken_chain.md`. Flag inconsistencies before changing direction.
7. **Keep player-facing docs in sync.** If you change C-130 script behavior, update the Overview.txt.
8. **`missions/` is gitignored.** Never commit files from it. Scripts in `scripts/` are the shared, public layer.
