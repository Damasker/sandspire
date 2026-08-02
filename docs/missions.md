# Sandspire — Missions & campaign (S13–S14)

## Mission JSON

Files: `data/missions/*.json`. Load with `--mission=<id>` or `SANDSPIRE_MISSION=<id>`.

| Field | Notes |
|-------|--------|
| `id` / `title` | Identity + HUD |
| `map.scene` | Usually `res://scenes/main.tscn` |
| `map.params` | Variants: `map_seed`, `enemy_force` (`light`/`standard`/`heavy`), `player_force` (`tutorial`/`standard`/`raid`/`siege`), `tag_enemy_base` |
| `player_faction` / `enemy_faction` / `difficulty` | Applied at load |
| `ai_enabled` / `worm_enabled` / `starting_credits` | Runtime toggles |
| `briefing.advisor` / `briefing.text` | Mentat-like panel |
| `objectives[]` | Win trackers (`required` gates victory) |
| `fail_conditions[]` | Instant lose |
| `win_text` / `lose_text` | Banner copy |

### Objective types

| type | Fields | Done when |
|------|--------|-----------|
| `destroy` | `group`, `count` | Group empty (e.g. `enemy_camp`, `enemy_base`) |
| `harvest` | `amount` | `Economy.lifetime_earned >= amount` |
| `survive` | `seconds` | Mission timer ≥ seconds without fail |

### Fail types

| type | Fields |
|------|--------|
| `building_lost` | `building_id`, `team` (`player`/`enemy`) |
| `timeout` | `seconds` (>0) |

## Campaign

Definition: `data/campaigns/rise_of_sand.json` (7 missions).

| # | Mission | Focus |
|---|---------|--------|
| 1 | `m01_first_blood` | Tutorial destroy camp (AI off) |
| 2 | `m02_spice_run` | Harvest 300 |
| 3 | `m03_hold_the_line` | Survive 90s |
| 4 | `m04_ash_raid` | Play Ashveil |
| 5 | `m05_coil_wall` | Harvest + destroy vs Coilward |
| 6 | `m06_dune_hunger` | Survive + worm (play Coilward) |
| 7 | `m07_throne_of_sand` | Finale: destroy `enemy_base` (camp+CY) |

Progress: `user://campaign_progress.json` — win unlocks the next mission.

### Launch

```bash
# Next unlocked mission in campaign
godot --path . -- --campaign=rise_of_sand

# Specific mission (must be unlocked)
godot --path . -- --campaign=rise_of_sand --mission=m03_hold_the_line

# Campaign menu UI
godot --path . res://scenes/campaign_menu.tscn
# or: godot --path . -- --campaign-menu
```

Env: `SANDSPIRE_CAMPAIGN`, `SANDSPIRE_MISSION`, `SANDSPIRE_CAMPAIGN_MENU=1`.

## Save / load (skirmish/mission)

`user://saves/slot_N.json`, `autosave.json`. **F5** / **F9**. Snapshot includes units/buildings/objectives.

## UX (S15)

| Key | Action |
|-----|--------|
| `?` / F1 | Hotkey help |
| O | Options (scroll, edge scroll, volume, UI scale, EN/RU) |
| B | Advisor |

Options persist to `user://options.json`. SFX are procedural beeps (`SfxBus`) — no WAV/OGG assets yet.
