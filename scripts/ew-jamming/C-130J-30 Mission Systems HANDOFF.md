# C-130J-30 Mission Systems — Maintainer Handoff

A handoff for the next AI agent (or human) picking up this project. This is the
**developer-facing** doc; the player-facing doc is `C-130J-30 Mission Systems Overview.txt`
and must be kept in sync with code changes.

---

## 1. What this is

A single-file **DCS World Lua script** that turns the C-130J-30 into a combined
**EC-130H Compass Call (Electronic Warfare)** + **RC-130H Rivet Joint (ISR)** platform.
It runs server-side, gives player crews an F10 radio menu, jams RED SAMs, spoofs inbound
missiles, and geolocates RED radar emitters (ELINT) with map marks and coalition broadcasts.

It is **player-only** and **static-slot-only** (not dynamic slots).

### Files & locations
| File | Purpose |
|---|---|
| `C-130J-30 Mission Systems.lua` | The entire script (~2050 lines). |
| `C-130J-30 Mission Systems Overview.txt` | Player-facing reference. **Keep in sync.** |
| `C-130J-30 Mission Systems HANDOFF.md` | This file. |
| `C-130J-30 Mission Systems BACKUP.lua` | A manual user backup (untracked, ignore). |

All live in `C:\Users\brady\Saved Games\DCS\Scripts\`.

### Git
A git repo is initialized **in the Scripts folder**, but `.gitignore` is an allowlist
(`*` then `!`-includes) so it tracks **only** the three C-130 files + `.gitignore`. The
folder also contains unrelated DCS files (DCSDTC, Hooks, Export.lua…) — do **not** `git add -A`.
Commits use a `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer. Commit
messages are descriptive (subject + bullet body). The repo is local-only (no remote).

---

## 2. Hard constraints / gotchas (read before editing)

- **DCS Lua 5.1.** No `goto`-heavy code, no 5.3 features. Standard DCS scripting env
  (`coalition`, `Unit`, `Group`, `Object`, `Weapon`, `trigger.action`, `timer`, `land`,
  `world`, `missionCommands`, `AI.Option`). No `os`/`io`.
- **No Lua interpreter on the dev machine.** You cannot compile/run it here. Validation =
  careful reading + the **user testing in-game** and reporting symptoms. Be conservative;
  prefer small, verifiable edits. When you finish a change, tell the user *what to watch for*
  in-game.
- **Definition order matters.** Everything is `local function`. A function must be defined
  *above* its first use. There is one forward-declared `local buildMenusFor`. If you add a
  helper, place it before callers.
- **Do NOT toggle SAM radar emissions.** An earlier `Unit/Group:enableEmission(false)` "radar
  blinding" feature **caused crashes** and was reverted. Suppression is **ROE `WEAPON_HOLD`
  only** — the radar stays online and keeps tracking but cannot engage. The user prefers this
  (more realistic) and it's stable. Don't reintroduce emission toggling.
- **Skynet IADS coexistence:** if a mission also runs Skynet, both manipulate SAM ROE and
  will contend. Standalone is fine. Not something to "fix," just be aware.
- **Only RED is detected/jammed.** Friendly Patriot/NASAMS were removed from the data tables
  (see §6) — they're BLUE and never jammable anyway, and they skewed the balance reference.

---

## 3. File structure (top to bottom)

1. **CONFIG block** (`local CFG_*`, lines ~16–92). All tunables live here; comment says "no
   other part needs touching" to change balance. See §7 for the full list.
2. **Shared utility** — geometry (`getHeading`, `get3DDist`, `getBearing`, `getClockBearing`),
   `hasLOS` (LOS check that lifts the radar +30m to dodge dug-in 3D models), `bullseyeStr`
   (returns `"BE %03d/%d"`), `isRadarUnit`, `isImportantRadar`, `getNatoName`.
3. **State tables** — per-unit hashes keyed by unit name (EW state, ISR state). Plus the data
   tables: `jamDifficulty`, `jamDuration`, `loBandSystems`, `highPriorityThreats`,
   `CFG_spoofZones` etc.
4. **Message queue** — `emitEvent` (batched), `emitImmediate` (instant popup),
   `emitEWStatus`/`emitISRStatus` (status lines), `ewActive`, `emitISR` (muted while jamming).
5. **EW helpers & tactics** — `computeJamAttemptCooldown`, `getJamRange`, `countAreaSuppressions`,
   `computeModeAndDrainPerSec`, `ewStatusBrief`, `defensiveLoop` (missile spoof),
   `offensiveLoop` (area/directional jam), `restoreSAMs`, `endSpotBroadcast`, `spotJammingTick`.
6. **ISR** — `getDetectionRange`, `computeTrackTime`, `getConfidence`, `confidenceLabel`,
   `stopTrack`, `stopAllTracks`, `bumpAutoTrack`, `autoTriangulateFill`, `trackDisplayScale`,
   `buildMarkText`, `updateMapMark`, `sweepEmitters`, `trackingTick`, `isrStatusBrief`,
   `sigintReport`.
7. **Crew coordination** — `sendHandoffBrief`, `groupHasPlayer`, `refreshCoordTargets`.
8. **Menu building** — `refreshTrackTargets`, `refreshStopTrackMenu`, `refreshSpotTargetList`,
   `buildEWPostLoadoutMenus`, `buildEWLoadoutMenu`, `buildEWSubMenu`, `buildISRSubMenu`,
   `buildCoordSubMenu`, `buildMenusFor`.
9. **Registration** — `registerUnit` / `unregisterByName` (lifecycle: init/teardown of all
   per-unit state). `_staticSlots` gates eligibility.
10. **Main ticks** — `ewTick` (1s), `isrTick` (1s), `statusDisplayTick` (1s),
    `refreshMenusTick` (10s), all `timer.scheduleFunction`.
11. **Event handler** — `S_EVENT_SHOT` (track inbound RED radar missiles), `S_EVENT_BIRTH`/
    `PLAYER_ENTER_UNIT` (register), death/leave events (unregister).
12. **Startup** — `recordStaticSlots` (+0.1s), `autoRegisterAtStart` (+1s), `ensureMenus` (+2s).

---

## 4. EW subsystem

### Loadouts (3 configs)
Selected from the F10 menu before any jamming works. All three carry full mode availability;
they differ in **band coverage** and **power pool** (`maxEmitterCapacity`):

| Config | Power pool | Bands (`loadoutBands`) |
|---|---|---|
| Defensive | 2,500 | hi only |
| Offensive | 4,500 | lo only |
| Full Spectrum | 5,500 | hi + lo |

`loadoutBands[name] = { hi=bool, lo=bool }` drives the **cross-band penalty**: jamming a
system whose band you don't cover multiplies probability by `CFG_crossBandPenalty` (0.60).
Band per system comes from `loBandSystems` (listed = lo-band; unlisted = hi-band).

### Power / energy
- `emitterCapacity[name]` drains while jamming, regens `CFG_regenPerSec` when idle.
- Drain = base per active mode + `CFG_drainPerSuppressed × countAreaSuppressions()` (so
  shutting down a whole IADS costs more). Computed in `computeModeAndDrainPerSec`.
- Hits 0 → `overheated[name]=true`, all modes off until `CFG_overheatResetCap` (450) recovered.
- **Displayed everywhere as "Power: N%"** (a percentage of the pool), never raw N/M.
  The pool size is internal only.

### Jamming model (the important part)
`offensiveLoop` rolls **once per second per in-range RED radar**. Final probability:
```
prob = band(dist) × jamDifficulty[nato] × crossBandPenalty(if wrong band) × modePower
```
- **`CFG_jamProbBands` = BURN-THROUGH**: probability RISES with distance (weak up close,
  strong at standoff). This is intentional/realistic and the user chose it. Don't flip it back.
- **Range is altitude-scaled** via `getJamRange(unit)` (`CFG_jamFloorRange` ~25nm on the deck →
  `CFG_jamMaxRange` ~200nm at altitude). Area & directional only.
- **Mode power hierarchy**: Area = `CFG_areaSpreadFactor` (0.65, broad/weak); Directional =
  1.0 (focused sector, full power); Spot = its own model (see below).
- On success → ROE `WEAPON_HOLD`, record `suppressedSAMs[gname] = {sam, lastSuppressed,
  spot=false, duration=jamDuration[nato] or 60, nato}`.
- On failure → `_lastJamAttempt[gname] = {time, cooldown=computeJamAttemptCooldown(dist)}`
  (1s point-blank → 30s at 200nm; scales with distance). This cooldown is the hidden
  "resilience" knob — see the player overview / git history for the duty-cycle math.
- `restoreSAMs()` (called each `ewTick`) restores `OPEN_FIRE` when the window expires or the
  jammer leaves range/LOS, and fires `THREAT NEUTRALIZED` (immediate, all jammer crews) if the
  SAM was destroyed while suppressed.

### Spot jamming (`spotJammingTick`)
The focused single-target tool. **Flat, altitude-INDEPENDENT** reach (`CFG_spotMaxRange` 100nm,
full power inside `CFG_spotFullEff` 70nm) — deliberately *not* altitude-gated (that was a bug
that collapsed its range; fixed). Softens ECCM via `CFG_spotPunchThrough`. Broadcasts state
changes coalition-wide (`SPOT JAM: X SUPPRESSED (BE) …` / `LIVE again` / `ENDED`) via the
`_spotState` machine + `endSpotBroadcast`. Reconciled in `ewTick` to catch menu-disable.

### Missile spoofing (`defensiveLoop`)
Tracks RED radar-guided missiles (guidance 3/4) from `S_EVENT_SHOT`. Requires **hi-band**
pods (Defensive/Full Spectrum). One roll/sec, single tightest `CFG_spoofZones` zone (no
stacking). On success `Object.destroy(missile)`. **Guard:** never spoofs until the missile has
flown `CFG_spoofMinTravel` (~3nm) from its recorded `launchPos` — otherwise destroying it
damages the launch vehicle ("explodes on launch" bug, fixed). `purgeDeadMissiles` cleans the
table each tick regardless of mode.
**Zone curve is intentionally steep at close range** (3% at 20nm → 95% at 1.5nm) so most
missiles fly in close before being defeated — sweet spot is ~4-5nm (48% pk at 6nm band),
3nm is the backstop. Don't flatten it back to a uniform gradient.

---

## 5. ISR subsystem

### Detection
`sweepEmitters` runs every `CFG_sweepInterval` (5s), fills `knownEmitters[name][gname] =
{pos, seenAt, unit, nato}`. Uses **`isImportantRadar`** = `isRadarUnit and not AAA attribute`.
**AAA / CIWS / SA-19 Tunguska are intentionally NOT detected** (all carry the "AAA" attribute).
`getDetectionRange` is altitude-scaled (50nm deck → 200nm high).
> `isRadarUnit` (includes radar AAA) is used ONLY by `offensiveLoop` so area jamming still
> incidentally suppresses AAA. Everything ISR-facing uses `isImportantRadar`.

### Two-phase ELINT tracking
A track lives in `markedTarget[name][gname]`. `getConfidence(track)` is two-phase:
- **Phase 1 (0→85%)** over `timeToFull` (`computeTrackTime`, 60–360s by range).
- **Phase 2 (85→100%)** over `timeToFull × CFG_refinementMult` (4× longer), gated on
  `phase2Start` (stamped in `updateMapMark` when elapsed ≥ timeToFull).
Error margin / mark displacement shrink with confidence (`trackDisplayScale`, `buildMarkText`,
`CFG_errorInitial*`/`CFG_errorPhase1*`). At 85% → coalition `RIVET ELINT LOCK` + permanent
mark. At 100% → `RIVET PRECISE FIX` + entry appended to `_preciseFixLog` (see below).

### Breadth-first auto-triangulate (`autoTriangulateFill`, ON by default)
Strategy: **get a Phase-1 lock on EVERY in-range emitter first, THEN refine to precise**.
- Only `CFG_maxTracks` (3) tracks are *actively worked* at once.
- A Phase-1 lock is **parked**: `elintParked[name][gname] = {stage="locked"|"precise", markID}`,
  the slot freed, the **mark ID carried through and reused** for Phase 2 (one mark per emitter —
  critical, don't break this).
- Phase 2 resumes by seeding a track at 85% (`trackStart = now - timeToFull`, `phase2Start=now`,
  `sentLockMsg=true`, reusing the parked `markID`).
- **Priority preemption**: a `highPriorityThreats` SAM coming online preempts the
  least-important active track via `bumpAutoTrack` (refining track first, else farthest
  non-priority; never bumps manual or priority Phase-1 tracks).
- Tracks tagged `auto` (true/false) and `work` ("p1"/"p2"/"manual"). Manual picks (Track
  Emitter menu) take priority and are never auto-bumped.
- `trackingTick` does the park/precise/lost transitions; releases slots outside the `pairs()`
  loop; always calls `autoTriangulateFill` when auto is on.

### SIGINT report
`sigintReport` — on-demand from the ISR menu, **broadcast to all BLUE** (`outTextForCoalition`),
sorted by threat level then distance, bullseye + range per line, `*` flags priority threats.

### Precise-fix export log
`_preciseFixLog` — module-level list; one entry `{nato, be, missionTime}` appended inside
`updateMapMark` each time a track crosses 100% (gated by `sentPreciseFix` — fires exactly once
per emitter). `writeISRPreciseFixLog` is **forward-declared** near `_preciseFixLog` so
`updateMapMark` can call it directly; the actual `writeISRPreciseFixLog = function()` assignment
is before the event handler. Called on each new fix AND on `S_EVENT_MISSION_END` — file is
always current on disk even if the server is left without a clean shutdown.
`_C130_ISR_log_num` is a GUI-state global: reset to nil by the mission script at load, set to
the next available `_NNN` on the first write of a mission, reused for all subsequent writes so
the same file is updated in-place. File: `Saved Games\DCS\Logs\C130_ISR_Report_NNN.txt`.

### Crew coordination
`sendHandoffBrief` → one selected **player** group (`groupHasPlayer` filter — never AI flights).
EW status + SIGINT contacts + active tracks.

---

## 6. Data tables (current contents)

- **`jamDifficulty`** (multiplier, lower = harder): SA-10 0.80, SA-11 0.85, SA-15 0.86,
  Hawk TR 0.84, SA-19 0.86, SA-6 0.89, SA-5 0.86, HQ-7 0.91, SA-8 0.92, Roland 0.92,
  SA-3 0.93, SA-2 0.96, ZSU-23 0.96, Hawk CWAR 0.86, Hawk SR 0.88, Dog Ear 0.98, EWR 0.99.
  Unlisted = 1.0.
- **`jamDuration`** (suppression window s): SA-10 30, SA-11 40, SA-15 45. Unlisted = 60.
- **`loBandSystems`**: SA-10, SA-2, SA-3, SA-5, SA-6, Hawk SR, Hawk CWAR, Dog Ear, EWR. (lo-band)
- **`highPriorityThreats`**: SA-10, SA-5, SA-11, SA-15. (instant alert + auto-track priority)
- **`getNatoName`**: exact type-name map + a lowercase **substring fallback** (`{kw, name}`
  pairs, most-specific first) for variant type names. AAA names like ZSU-23/Gepard return but
  are filtered by `isImportantRadar`.

**Removed on purpose** (don't re-add without reason): SA-23, SA-20, SA-12, SA-17, Patriot,
NASAMS. They were friendly or unused and skewed the balance reference numbers.

---

## 7. CONFIG knobs (current values)

```
EW energy:    regenPerSec=5  drainArea=3  drainDir=1  spotDrain=5  overheatResetCap=450
              jamMaxRange=370400(~200nm)  lowCapWarnPct=0.20
Spoof:        spoofZones(20/15/10/6/3/1.5nm = 3/8/18/48/82/95%)  spoofMinTravel=5556(~3nm)
Offensive:    jamProbBands(10/25/50/100/200nm = 0.40/0.62/0.82/0.93/0.98 — BURN-THROUGH)
              crossBandPenalty=0.60  jamFloorRange=46300(~25nm)
              areaSpreadFactor=0.65  spotPunchThrough=0.50  drainPerSuppressed=0.5
              spotMaxRange=185200(~100nm)  spotFullEff=129600(~70nm)
ISR:          sweepInterval=5  markRefreshInterval=15  trackMinTime=60  trackMaxTime=360
              refinementMult=4  errorInitialNm=50  errorPhase1Nm=10
              errorInitialBrg=30  errorPhase1Brg=5  displacementThreshold=500  maxTracks=3
Messages:     msgGap=10  msgDur=15  ewStatusInterval=30  isrStatusInterval=30
```

---

## 8. Messaging conventions

- **Bullseye everywhere** for location: `bullseyeStr` → `"BE 312/48"`. This is how players
  call out positions; prefer it over raw bearing/range from the aircraft.
- **Concise messages.** Short prefixes: `CONTACT`, `THREAT`, `MOVED`, `LOST`, `AUTO`/`AUTO*`,
  `REFINE`, `SPOT JAM`, `RIVET ELINT LOCK`. Don't reintroduce verbosity.
- **ISR muted while jamming.** `emitISR` drops routine ISR chatter (contacts, moved, auto
  pickups, refine, track-lost, ISR status) whenever `ewActive(name)` is true. **Threat alerts
  and coalition broadcasts always fire.** Deliberate clicks (toggles, selections, SIGINT)
  use `emitImmediate`.
- **Suppression confirm bypasses the queue.** On a successful jam, `offensiveLoop` calls
  `trigger.action.outTextForGroup` directly (not `emitEvent`) with the system's actual
  suppression duration as the display time — so "Suppressed: X — clear to engage" stays on
  screen for exactly as long as the SAM is held. The spot-jam coalition broadcast reads the
  same duration from `suppressedSAMs[tgtGroup].duration`. Don't route suppression confirms
  back through `emitEvent`; it would cap them at `CFG_msgDur` (15s).
- **Jam failure aggregation.** `offensiveLoop` tracks `failCount` and `anySuccess` locals.
  Individual `emitEvent("Jam failed: X")` calls are gone. Instead: if the tick produced any
  success, failures are silent (persistent banners already communicate the state); if the tick
  produced only failures, a single `emitEvent("Jam: no lock (N site(s))")` fires. Don't
  restore per-target failure lines — they spam badly in a dense IADS.
- **SPOT JAM coalition broadcast durations.** All three spot-jam state-change messages
  (`SUPPRESSED`, `LIVE again`, `ENDED`) now use `jamDuration[nato] or 60` rather than any
  hardcoded value. `_spotState[name]` carries a `duration` field set when the entry is
  first created, so `endSpotBroadcast` has the duration even after `suppressedSAMs` is cleared.
- **Audience:** crew-only = `emitEvent`/`emitImmediate` (group). Coalition-wide =
  `outTextForCoalition(BLUE)` (ELINT LOCK, PRECISE FIX, SPOT JAM status, SIGINT report).
  Map marks = `markToCoalition(BLUE)` (invisible to RED).

---

## 9. How to make a change safely

1. Read the relevant function(s) fully before editing (line numbers drift — `grep` by name).
2. Keep helpers defined before use; nil-guard DCS object access (`u and u:isExist()`).
3. If it's player-facing, **update `…Overview.txt`** in the same change.
4. Verify by `grep` (no dangling refs, balanced edits) — you can't run it.
5. Commit each logical change with a clear message + the `Co-Authored-By` trailer; stage only
   the C-130 files.
6. Tell the user the concrete in-game symptom to check, since they validate by flying.

---

## 10. Known limitations / open items

- **Multi-aircraft:** `countAreaSuppressions` counts suppressions globally, so per-target drain
  over-counts if multiple C-130s fly at once. Fine single-player; scope per-jammer if needed.
- **Phase-2 start plateau:** `phase2Start` is stamped on the next mark refresh, so Phase 2 can
  begin up to `CFG_markRefreshInterval` (15s) late. Cosmetic.
- **SA-19 Tunguska** is excluded from ISR (AAA attribute). Intentional per user; whitelist it
  in `isImportantRadar` if that ever needs to change.
- **No automated tests.** The only validation loop is the user flying the mission.
- **ISR export requires `net.dostring_in`.** Available in both SP and MP in modern DCS builds.
  The file is written on each precise fix (not just mission end), so leaving the server without
  a clean shutdown is fine — the log is already on disk. If the file never appears, the fallback
  is a hook script in `Scripts\Hooks\` (full `io`/`lfs`, no `net` dependency).

---

## 11. Recent change history (newest first, for context)

- Missile spoof tune: sweet spot shifted to 3-5nm (6nm pk 32→48%, 3nm 60→82%, 1.5nm 88→95%).
- Missile spoof rebalance: zone curve shifted steep-at-close (3%@20nm → 95%@1.5nm, new 1.5nm
  zone added) so most missiles fly in close before guidance breaks rather than dying silently
  at range.
- ISR log write-on-fix: `writeISRPreciseFixLog` forward-declared and called from `updateMapMark`
  on each precise fix so the file is always current; `_C130_ISR_log_num` GUI global caches the
  file number for the mission (reset at load, found once, reused) — no clean shutdown required.
- Three QoL fixes: (1) SPOT JAM ENDED / LIVE again coalition broadcasts now use system jam
  duration via `_spotState[name].duration` instead of hardcoded 20s; (2) `offensiveLoop` jam
  failure messages aggregated — no individual "Jam failed: X" lines, one "Jam: no lock (N
  site(s))" only when nothing suppressed this tick; (3) ISR log auto-increments filename
  (`C130_ISR_Report_001.txt`, `_002.txt`…) via a `repeat/until` existence-check loop inside
  the GUI Lua snippet — prior missions never overwritten.
- ISR precise-fix export: `_preciseFixLog` accumulates 100%-confidence fixes; `S_EVENT_MISSION_END`
  triggers `writeISRPreciseFixLog` → `net.dostring_in('gui',…)` writes `Logs/C130_ISR_Report_NNN.txt`.
- Suppression confirm message duration now equals the jam window: `offensiveLoop` bypasses
  `emitEvent` and calls `outTextForGroup` directly with `dur`; spot-jam coalition broadcast
  uses `suppressedSAMs[tgtGroup].duration` instead of hardcoded 20s.
- `Power` rename + everything shown as `%` (was raw capacity N/M).
- SIGINT report broadcasts to all BLUE.
- AAA/Tunguska excluded from ALL ISR (and the spot list) via `isImportantRadar`.
- Missile spoof min-travel gate (no launcher damage).
- ISR chatter muted while jamming; all messages tightened; BE abbreviation.
- Spot jamming reverted to flat altitude-independent range (altitude-gating was a bug).
- Removed SA-23/20/12/17, Patriot, NASAMS.
- Breadth-first auto-triangulate (Phase-1-all-then-Phase-2 + priority preempt).
- SIGINT sort by threat+distance; stop-track shows system+BE (no group-name leak).
- Crew handoff → player groups only.
- Reverted `enableEmission` radar-blinding (crash + preference); fixed empty Track Emitter menu.
- Theater-jammer rebalance + burn-through model; Skynet-DB-derived radar data.

Full detail is in `git log`.
