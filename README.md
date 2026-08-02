# Sandspire

Desert real-time strategy — spiritual successor to classic harvest-and-conquer RTS (Dune II DNA), original IP.

| | |
|---|---|
| **Version** | **0.4.0 MVP (M4)** |
| **Engine** | Godot 4.7 |
| **Language** | GDScript |
| **View** | Top-down 2D |
| **Lab host** | server 110 = `home-mike` / `192.168.168.110` (R620) |
| **Server path** | `/home/mike/projects/sandspire` |

## How to play (server 110)

```bash
ssh home-mike
cd /home/mike/projects/sandspire

# once (engine)
bash scripts/install_godot_linux.sh

# GUI — main menu (Campaign / Skirmish / Options / Quit)
~/.local/bin/godot --path .

# jump straight into campaign picker / next mission
~/.local/bin/godot --path . -- --campaign=rise_of_sand
~/.local/bin/godot --path . -- --campaign=rise_of_sand --mission=m01_first_blood

# headless verification
make smoke-all
```

### Campaign start

1. Main menu → **Campaign** (or `res://scenes/campaign_menu.tscn`).
2. Play **First Blood** (tutorial) — harvest → build/produce → destroy the Ashveil camp.
3. Wins unlock the next mission in `rise_of_sand` (7 missions).

### Skirmish

Main menu → **Skirmish**, or load `res://scenes/main.tscn` with no mission flags.

### Linux export

```bash
bash scripts/install_export_templates.sh
make export-linux
./build/linux/Sandspire.x86_64
```

See [docs/export.md](docs/export.md).

### From Windows workstation

```powershell
# sync mirror → server
scp -r C:\Users\Admin\Projects\sandspire\* home-mike:/home/mike/projects/sandspire/
ssh home-mike 'cd /home/mike/projects/sandspire && python3 scripts/fix_crlf.py && make smoke-all'
```

## Controls (summary)

| Input | Action |
|-------|--------|
| WASD / arrows | Pan |
| Wheel | Zoom |
| LMB / Shift+LMB | Select |
| RMB | Move / attack |
| A / S / H | Attack-move / Stop / Hold |
| 1–6 | Place buildings |
| Q–Y | Produce (selected factory) |
| B | Advisor |
| O | Options |
| ? / F1 | Hotkeys |
| F5 / F9 | Quicksave / Quickload |

## Docs

- [GDD](docs/GDD.md) · [Roster](docs/roster.md) · [Balance](docs/balance.md)
- [Missions & campaign](docs/missions.md) · [Roadmap](docs/roadmap.md)
- [Known issues (MVP)](docs/known-issues.md) · [Export](docs/export.md) · [Trailer notes](docs/trailer-notes.md)

## Layout

```
data/           units, buildings, factions, missions, campaigns, AI
docs/           design + ship notes
scenes/         main_menu, campaign_menu, main, entities
scripts/        gameplay + smoke + export helpers
build/          export artifacts (generated)
```

## License

Code: MIT (unless noted). Not affiliated with Dune, Westwood, EA, or Legendary.
