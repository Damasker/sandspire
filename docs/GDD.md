# Sandspire — Game Design Document v0.1

**Status:** living doc · **MVP target:** Milestone M4 (~16 × 2-week sprints)  
**Working title:** Sandspire  
**Pitch:** Top-down desert RTS. Harvest melange-analogue **spice**, power a base, field armies, survive the worm.

## 1. Fantasy

You command a Great House on a deadly desert world. Wealth comes from spice fields. Rock is safe to build on; open sand invites the worm. Expand, tech up, crush rivals.

## 2. Pillars

1. **Harvest tension** — spice is wealth and bait for the worm.
2. **Base as factory** — power, prereqs, production queues matter.
3. **Readable combat** — counters clear; no hero micromanagement in MVP.
4. **Three distinct houses** — same economy rules, different combat fantasies.
5. **Modern UX on classic bones** — box select, attack-move, minimap, hotkeys.

## 3. Core loop (30 seconds)

Scout spice → send harvester → unload at refinery → spend credits on buildings/units → push / defend → expand to next field.

## 4. World rules

| Terrain | Build | Worm risk | Notes |
|---------|-------|-----------|-------|
| Rock | Yes | None | Bases live here |
| Sand | No | High if noisy | Travel + spice |
| Spice | No | High | Harvestable resource |
| Bloom | No | Extreme | Rich spice respawn |

- **Credits** from refinery unload only.
- **Power** from plants; low power slows or disables production/defense.
- **Fog of war** — vision from units/buildings; explored stays dim.
- **Worm** — aggro on harvester activity on sand; swallows units; leaves after feast.

## 5. Win / lose

- **Skirmish:** destroy enemy Construction Yard (or all production + CY).
- **Campaign mission:** scripted objectives (harvest X, survive N, destroy camp).

## 6. Factions

| House | Fantasy | Signature |
|-------|---------|-----------|
| **Aureate** (S9) | Balanced industrial | Reliable tank line (siege + MSA) |
| **Ashveil** (S10) | Aggressive raid | Flame Trooper splash; sandworm pressure |
| **Coilward** (S11) | Defensive tech | Fortress turrets; Ornithopter air at Outpost |

Skirmish: `--player=` / `--enemy=` (`aureate` \| `ashveil` \| `coilward`); `--difficulty=easy|normal|hard`.  
Default Aureate vs Ashveil on normal. Balance v1: [balance.md](balance.md). Roster: [roster.md](roster.md).

## 7. Camera & controls (MVP)

- Pan: WASD / arrows / edge scroll  
- Zoom: wheel  
- Select: click / box; Shift add  
- Move / attack-move: RMB / A+LMB  
- Build menu: sidebar + hotkeys 1–0  
- Minimap click-to-jump  

## 8. Art direction

- **Top-down 2D**, readable silhouettes, warm sand / cool rock palette.
- Placeholder colored rectangles OK until vertical slice ships.
- No photoreal 3D in MVP.

## 9. MVP scope

**In:** 1v1 skirmish vs AI, 3 houses, spice + power + FoW, worm, campaign 6–8 missions, save/load, RU/EN stub.  
**Out:** online MP, workshop mods, public map editor, 4th faction, mobile.

## 10. Tech

- Godot 4.x, GDScript
- Data-driven units/buildings (`data/*.json`)
- Composition over deep inheritance for entities
- Headless smoke test when CI lands

## 11. Vertical slice exit (end S4)

Player can: find spice → harvest → build factory → produce combat unit → destroy a static enemy camp — without editor cheats.

## 12. IP note

Original setting and assets. Mechanics inspired by classic desert RTS; not affiliated with Dune / Westwood / EA / Legendary.

## 13. Open decisions

- [ ] Final house names & lore tone
- [ ] Concrete/slab building (authenticity vs clutter)
- [ ] Carryall: full AI or simplified teleport-assist
- [ ] Skirmish map count for MVP (target: 3)
