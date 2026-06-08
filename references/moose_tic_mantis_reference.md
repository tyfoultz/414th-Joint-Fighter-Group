# MOOSE, Troops in Contact, and MANTIS — Tools Reference

Reference document for the three primary scripting tools used to build DCS missions in this project:

1. **MOOSE** — Lua framework on top of DCS scripting (the substrate everything else uses)
2. **Troops in Contact (TIC)** — third-party MOOSE-based script for immersive AI ground combat
3. **MANTIS** — MOOSE functional module for Integrated Air Defense Systems (IADS)

When working on a mission for this project, check whether these tools apply before answering from general knowledge. Prefer the official docs over recall — DCS and MOOSE change frequently.

---

## MOOSE Framework

### What it is
A large Lua library providing high-level object-oriented classes for DCS mission scripting. Wraps the raw DCS scripting API in classes like `GROUP`, `UNIT`, `SPAWN`, `MENU_*`, `SET_GROUP`, plus large functional modules (MANTIS, AIRBOSS, RAT, RANGE, CTLD).

### Documentation
- **Overview / beginner / advanced guides:** https://flightcontrol-master.github.io/MOOSE/
- **Stable class reference (master-ng branch):** https://flightcontrol-master.github.io/MOOSE_DOCS/
- **Development class reference:** https://flightcontrol-master.github.io/MOOSE_DOCS_DEVELOP/
- **GitHub source:** https://github.com/FlightControl-Master/MOOSE
- **Discord (best for troubleshooting):** linked from the overview page

### Class-doc URL pattern
`https://flightcontrol-master.github.io/MOOSE_DOCS/Documentation/<Category>.<ClassName>.html`

Categories include `Functional`, `Ops`, `Core`, `Wrapper`, `Tasking`, `Cargo`, `AI`. Example: MANTIS lives at `Functional.Mantis.html`.

### Key concepts
- **Two branches:** `master-ng` (stable releases) and `develop` (newest features). Current `Moose.lua` build is master-ng, commit dated 2026-02-06.
- **Single-file build:** `Moose.lua` is ~130k+ lines, all classes concatenated. First ~48 lines are a dev dynamic-loader fallback — static code starts at line 51.
- **De-sanitize DCS** is a prerequisite. Edit `DCS World\Scripts\MissionScripting.lua` and comment out the `sanitizeModule` lines for `io`, `lfs`, `require`. Without this, advanced MOOSE features silently fail. #1 cause of "why isn't this working" reports.
- **Standard load order** in Mission Editor triggers:
  1. `MISSION START` → `DO SCRIPT FILE` → `Moose.lua`
  2. `ONCE` (time > 1) → load TIC.lua or other dependent scripts
  3. `ONCE` (time > 2) → load mission-specific scripts (MANTIS setup, etc.)
  The 1-second gaps prevent race conditions.

---

## Troops in Contact (TIC)

### What it is
A third-party Lua script by "Grendel" that solves DCS's broken AI ground combat. Lets mission makers build large, persistent ground engagements where AI doesn't insta-snipe everything. Built on MOOSE. Current reference is the v1.1 guide PDF (dated 2025-05-21).

### Documentation
- The `Troops in Contact Guide v1.1.pdf` is the primary reference. TIC is third-party — there's no FlightControl-Master docs page for it. Save the PDF in this project folder when available.
- Distribution: typically via DCS forums / Discord communities.

### Key concepts
- **Formations, not groups:** Each unit becomes its own 1-unit group so a stuck unit (on a bridge, tree, building) doesn't halt the whole formation.
- **Naming convention:**
  - `TIC:Armor Co 1#M1A2` — standard formation member
  - `TIC!Armor Co 1#HQ` — designated **leader** (player can issue SetPath move orders to this unit and the rest follow)
  - Append `+` to keep a group intact (e.g., convoys, AutoPilot passenger setups): `TIC:Armor Co 1#M1A2+`

### Waypoint commands

**Persistent (stay in effect for future waypoints):**

| Command | Values | Effect |
|---|---|---|
| `hdg=270` | 0-360 | Rotate formation to heading |
| `scale=1.5` | positive factor | Stretch (>1) or constrict (<1) the formation |
| `roe=simulate\|kill\|hold` | enum | Engagement logic. `simulate` = stormtrooper mode (poor aim, prolonged fights). `kill` = realistic accuracy. |
| `roads=y\|n` | y/n | Try to use roads (default `n`). AI may ignore if off-road is faster. |
| `shift=y\|n` | y/n | Units fidget at waypoint instead of standing like statues (default `y`) |
| `speed=30` | number | km/h |

**Immediate (do not persist past this waypoint):**

| Command | Values | Effect |
|---|---|---|
| `t+5` | minutes | Move to this waypoint after N minutes (relative to activation, not script load) |
| `flag=99` | flag name | Move when flag becomes true |
| `flag+99` | flag name | Set flag true when this waypoint reached |
| `mount` / `dismount` | — | Infantry mount/unmount troop carriers (works for amphibious too) |
| `"Phase Name"` | text in quotes | Coordinated maneuver triggered via F10 menu |
| `direct=y` | y/n | Skip intermediate waypoints, go straight here |
| `strength=0.25` | factor | Retreat to this waypoint if formation drops below N% combat strength (combine with `direct=y`) |

### Configuration flags (set BEFORE loading TIC.lua)
- `tic_init` — auto-scan for TIC-named groups (default true)
- `tic_menu` — create F10 menu (default true; requires aircraft slot to see)
- `tic_activate` — formations start active (default true). Set false to defer activation.
- `tic_stormtrooper` — poor-accuracy mode (default true). Disable for PvP-style missions with two GMs.
- `tic_disableT` — ignore all `t+` commands (default false). Enable when a live GM is directing formations.

### Important gotchas
- **Stormtrooper logic requires invisibility.** TIC marks units invisible to DCS AI so the "near-miss" aim works. Side effect: **Fog of War breaks** for TIC-controlled units.
- **Air defense exempt.** AAA/SAMs use normal DCS AI targeting against air threats — they ignore TIC stormtrooper logic. Intentional, plays well with MANTIS.
- **Manual SetPath cancels t+ commands.** If a player gives a TIC leader manual move orders, all pre-defined `t+` commands for that formation are cancelled.
- **Two demo missions ship with the guide:** `tic_demo.miz` (comprehensive multi-axis assault example) and `tic_total_war.miz` (chaos stress-test).

---

## MANTIS (IADS module)

### What it is
A MOOSE functional module that builds a network-aware Integrated Air Defense System. SAMs stay in dark mode (radar off) until an EWR detects a threat in range, then MANTIS wakes the appropriate SAM site to engage and powers it down when the threat clears. Solves the "every SAM radiating constantly and getting HARMed in 10 minutes" problem.

### Documentation
- **MANTIS class reference:** https://flightcontrol-master.github.io/MOOSE_DOCS/Documentation/Functional.Mantis.html
- **Source in MOOSE repo:** `Moose Development/Moose/Functional/Mantis.lua`
- **Example missions:** https://github.com/FlightControl-Master/MOOSE_MISSIONS/tree/master/Functional/Mantis

### Required mission setup
Like TIC, MANTIS uses naming-convention-based discovery. Each role gets a common prefix:

| Role | Naming convention |
|---|---|
| SAM sites | Common prefix, e.g., `Red SAM SA-10 #001`, `Red SAM SA-15 #002` |
| Early Warning Radars | Common prefix, e.g., `Red EWR 55G6 #001` |
| HQ (optional but recommended) | A single group, e.g., `Red HQ` |

Each SAM group should be its own group (so MANTIS can switch them independently) and set to **weapons hold / radar off** initially so MANTIS controls activation.

### Minimal setup code
```lua
-- MANTIS:New(name, SAMprefix, EWRprefix, HQname, coalition, groupingRadius, awacs)
local redIADS = MANTIS:New("RedIADS", "Red SAM", "Red EWR", "Red HQ", "red", 5000, false)
redIADS:Start()
```

### Useful tunables (call before `:Start()`)
- `:SetAdvancedMode(true, 90)` — degraded behavior if HQ/EWR network is damaged
- `:SetSAMRadius(25000)` — meters; enemy must be this close to wake a SAM
- `:SetEWRGrouping(5000)` — clusters EWRs
- `:AddShorad(SHORAD_object, 18000)` — link short-range AD to the IADS
- `:SetAutoRelocate(false)` — keep mobile SAMs in place

### MANTIS vs. Skynet IADS
Skynet IADS (mentioned in `sam_network.md`) is the older, more established IADS script. MANTIS is the MOOSE-native equivalent and has the advantage of being part of the framework you're already loading. Both achieve similar end results — pick MANTIS if you're already committed to MOOSE; pick Skynet if you find better examples or community support for your specific scenario.

---

## Combining MOOSE + TIC + MANTIS

These don't conflict — they cover different domains:
- **TIC** handles ground-vs-ground (formations, scripted maneuvers, stormtrooper aim).
- **MANTIS** handles ground-vs-air (smart SAM network with normal accuracy).
- **MOOSE** is the substrate for both.

### Integration rules
1. **Load order:** `Moose.lua` → `TIC.lua` → custom script with `MANTIS:New(...)`. Stagger by 1–2 seconds via ONCE triggers.
2. **Keep unit pools separate.** Don't give SAM/EWR groups the `TIC:` prefix. TIC owns ground formations, MANTIS owns air defenses. Breaking a SAM site into individual units would defeat per-site MANTIS control.
3. **Stormtrooper and air defense don't collide.** MANTIS units aren't TIC-controlled, so they keep normal accuracy — exactly what you want for IADS.
4. **Edge case: mobile SAMs moving with ground formations.** Either MANTIS owns it (stays put) or TIC owns it (loses radar discipline). Pick one. Cleaner: keep MANTIS for fixed/semi-fixed AD, keep TIC for direct-fire ground.

---

## Related tools

- **HighDigitSAMs (HDS) mod** — third-party mod adding modern Russian/Chinese SAMs (SA-12, SA-17, SA-20, SA-21, HQ-9/22) not in vanilla DCS. Operation Broken Chain explicitly uses **vanilla DCS units only** — no HDS. If a mission file references HDS units, replace them: SA-20/21/23/HQ-9 → SA-10; SA-17 → SA-11; etc. Or enable `Allow ignoring missing units` in ME options to let them silently fail.
- **Supercarrier module** — paid DCS module. Required for ACLS, the LSO, and deck crew. Mission features like `ACLS activate` task won't work without it.

---

## Quick reference — common patterns

### Carrier nav-aids heartbeat (vanilla DCS, no MOOSE)
DCS carriers can drop TACAN/ICLS/Link 4/ACLS tasks over long missions. Standard fix:
1. Define the four nav-aid tasks as **Triggered Actions** on the carrier group (separate panel accessible via icon strip above the waypoint list — not waypoint tasks).
2. Create a `REPETITIVE ACTION` trigger with condition `TIME SINCE FLAG ("414", 480)` that pushes all four tasks, then toggles flag 414 off→on to reset the timer.
3. `MISSION START` trigger sets flag 414 on once.

Result: every 8 minutes the carrier re-activates all nav aids.

### Carrier wind-over-deck
- DCS reports wind as "blows TO" — flip 180° to get the conventional "wind FROM" direction.
- For recovery ops, point the carrier ~9° to the left of the wind source (angled deck offset).
- Stationary carriers in light wind don't have enough WOD for jets (~25-30 kts needed). Either: sail into the wind, use the `Turn Into Wind` Triggered Action, or cheat the weather.
