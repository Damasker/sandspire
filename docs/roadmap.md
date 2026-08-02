# Sandspire — Roadmap (compressed)

Cadence: 2-week sprints. Full canvas plan may live in Cursor; this is the repo source of truth.

## Milestones

| ID | Sprint | Name | Exit |
|----|--------|------|------|
| M0 | S0 | Pitch lock | GDD + engine + scope freeze |
| M1 | S4 | Playable sand | Harvest → produce → kill camp |
| M2 | S8 | RTS skeleton | Power, FoW, pathfinding, AI skirmish |
| M3 | S12 | Three houses | 3 rosters + balance v1 |
| M4 | S16 | MVP ship | Campaign 6–8 + public build |

## M4 exit criteria (met at S16)

- [x] Campaign 6–8 missions (`rise_of_sand` × 7) + tutorial
- [x] Mission framework, save/load, UX polish (S13–S15)
- [x] Main menu (Campaign / Skirmish / Options / Quit)
- [x] Export presets + Linux build path documented (`docs/export.md`)
- [x] Known issues + README play instructions
- [x] Version **0.4.0** in UI / `project.godot`

## Current: S16 — Ship MVP → M4

- [x] Export presets Linux (+ Windows preset); templates install script
- [x] Main menu scene
- [x] `docs/known-issues.md`
- [x] Version string in UI
- [x] Crash hardening on critical main paths
- [x] README play / controls / campaign
- [x] Trailer capture notes (text)
- [x] `make smoke-menu` + `smoke-all` green
- [x] **M4 marked complete**

## Done earlier

### S15 — UX polish

- [x] Help, tooltips, options, locale stub, SFX beeps, `smoke-ux`

### S14 — Campaign

- [x] 7 missions, unlock progress, campaign menu

### S13 — Mission framework

- [x] Objectives, advisor, save/load

### S12 → M3 · S11–S0

- [x] Three houses, balance v1, AI/path/FoW/power, M1 slice

## Post-MVP

- [x] Skirmish lobby: faction picker + Canyon map #2
- [ ] Art pass v0.1 / carryall / more maps

## Out of MVP

Multiplayer, workshop mods, public map editor, mobile, voiced Mentat, full RU mission text, Steam packaging.
