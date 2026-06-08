# 414st Joint Fighter Squadron — DCS Scripts & Builds

Shared scripts and mission resources for the 414st JFS multiplayer DCS sessions.

## Repository Structure

```
scripts/
├── iads/            # MOOSE MANTIS IADS setup
├── cap/             # MOOSE AI A2A dispatcher (layered CAP/GCI)
├── splash-damage/   # Splash Damage 3.4.2 + config overrides
└── ew-jamming/      # Electronic warfare & ISR
    ├── EW_script_2.1.lua                        # Proximity-bubble jammer (standalone)
    ├── C-130J-30 Mission Systems.lua            # EC-130H EW + RC-130H ISR platform
    ├── C-130J-30 Mission Systems Overview.txt   # Player-facing reference
    └── C-130J-30 Mission Systems HANDOFF.md     # Developer reference (read before editing)
```

## Usage

Scripts are loaded in the DCS Mission Editor via **DO SCRIPT FILE** triggers at mission start. Load order matters — `Moose.lua` must load before any MOOSE-dependent script.

Typical trigger order:
1. `Moose.lua` (MOOSE framework — not included here, download from [MOOSE GitHub](https://github.com/FlightControl-Master/MOOSE))
2. Mission-specific scripts (IADS, CAP, etc.)
3. Config overrides (e.g., `splash_damage_config.lua`)

The C-130J Mission Systems script and EW Script 2.1 are standalone — no MOOSE dependency.

## Contributing

Drop scripts into the appropriate folder. If a script needs setup notes or special load order, add a short comment block at the top of the file. See `CLAUDE.md` for detailed developer guidance.
