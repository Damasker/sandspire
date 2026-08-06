# Sandspire — Art / texture specification

**Style reference:** `assets/units/tank_aureate.png`  
Top-down cartoon, cel-shaded greens/greys, **bold dark outline**, readable at RTS zoom. Transparent PNG (black background OK if keyed to alpha).  

**Engine conventions**
| | |
|--|--|
| Tile size | `GameConstants.TILE_SIZE` = **32 px** |
| Map | 48×36 tiles |
| Unit facing | Sprite faces **+X (right)** = 0°; runtime rotates (`unit.gd`) |
| Buildings | No yaw (except turret barrel aim); “front” toward south/east for readability |
| Format | PNG32, RGBA; no audio in this doc |

**Inventory source:** `data/buildings/*.json`, `data/units/*.json`, `docs/roster.md`, rendering in `scripts/*.gd` (as of commit on `main`).  
Do **not** invent units/buildings absent from data.

---

## Status summary

| Category | Spec rows | Exists | Missing |
|----------|-----------|--------|---------|
| Terrain / fog | 6 | 0 | 6 |
| Buildings (world) | 9 | 0 | 9 |
| Units / worm (world) | 23 | 3* | 20 |
| FX / VFX | 8 | 0 | 8 |
| UI | 36 | 0 | 36 |
| **Total** | **82** | **3** | **79** |

\*One file `assets/units/tank_aureate.png` covers **`u_tank` / `ash_tank` / `coil_tank`** via tint. Unique texture files on disk: **1**.

| Priority | Missing rows |
|----------|--------------|
| **P0** must | **29** |
| **P1** should | **35** |
| **P2** later | **15** |

P0 missing = terrain 4 + buildings 9 + units/worm 14 + FX 2.  
(Unit P0: Aureate 7 + Ashveil infantry/flame 2 + Coilward infantry/guard/air 3 + carryall + worm.)

---

## Global style rules

1. Match tank silhouette weight: thick outline, flat cel fills, small highlight accents (lights OK).
2. Warm sand / amber spice / cool grey rock (see `GameConstants.TERRAIN_COLORS`).
3. Faction paint (when not unique art):
   - **Aureate** — olive/gold-green (tank camo baseline)
   - **Ashveil** — ash orange / scorched metal (code tint: warm)
   - **Coilward** — teal / cold steel (code tint: cyan)
4. Prefer **one facing frame + rotation** over multi-direction sheets (same as tank).
5. Keep on-screen size modest: display height ≈ `radius * 2.2–2.5` for units; buildings fill footprint.

---

## 1. Terrain / tiles

Procedural colors today (`world_map.gd`). Textures replace flat fills.

| Asset ID / path | Entity | View | Size | Facing | Priority | Status |
|-----------------|--------|------|------|--------|----------|--------|
| `assets/terrain/tile_sand.png` | `Terrain.SAND` | top-down tile | **64×64** (or 32×32) seamless | n/a | **P0** | missing |
| `assets/terrain/tile_rock.png` | `Terrain.ROCK` | top-down tile | 64×64 seamless | n/a | **P0** | missing |
| `assets/terrain/tile_spice.png` | `Terrain.SPICE` | top-down tile | 64×64 seamless | n/a | **P0** | missing |
| `assets/terrain/tile_bloom.png` | `Terrain.BLOOM` | top-down tile | 64×64 seamless | n/a | **P0** | missing |
| `assets/terrain/fog_unexplored.png` optional | fog overlay unexplored | tile / 1×1 multiply | 32×32 or solid | n/a | **P2** | missing (procedural OK) |
| `assets/terrain/fog_explored.png` optional | fog explored-dim | tile / multiply | 32×32 | n/a | **P2** | missing (procedural OK) |

**Notes:** Spice/bloom should read amber-ochre (not purple). Rock needs hatch/rim readable vs sand (Ridge/Canyon). Fog may stay code-drawn (`fog_overlay.gd`).

---

## 2. Buildings (world sprites)

Shared building IDs (all houses). Footprint × 32 px = on-map size; source art at **2×** recommended.

| Asset path | Entity ID | Name | Footprint | Source px (2×) | Facing | Priority | Status |
|------------|-----------|------|-----------|----------------|--------|----------|--------|
| `assets/buildings/b_conyard.png` | `b_conyard` | Construction Yard | 3×3 → 96×96 | **192×192** | fixed / pad south | **P0** | missing |
| `assets/buildings/b_power.png` | `b_power` | Windtrap | 2×2 → 64×64 | **128×128** | fixed | **P0** | missing |
| `assets/buildings/b_refinery.png` | `b_refinery` | Spice Refinery | 3×2 → 96×64 | **192×128** | unload bay visible | **P0** | missing |
| `assets/buildings/b_silo.png` | `b_silo` | Spice Silo | 2×2 | **128×128** | fixed | **P0** | missing |
| `assets/buildings/b_barracks.png` | `b_barracks` | Barracks | 2×2 | **128×128** | fixed | **P0** | missing |
| `assets/buildings/b_factory.png` | `b_factory` | Vehicle Factory | 3×2 | **192×128** | fixed | **P0** | missing |
| `assets/buildings/b_turret.png` | `b_turret` | Gun Turret | 1×1 → 32×32 | **64×64** base | base fixed; barrel +X optional separate | **P0** | missing |
| `assets/buildings/b_radar.png` | `b_radar` | Outpost | 2×2 | **128×128** | dish readable | **P0** | missing |
| `assets/buildings/b_camp.png` | `b_camp` | Enemy Outpost | 2×2 | **128×128** | hostile red accents | **P0** | missing |

**Faction variants:** not in data as separate IDs. **P1** optional recolors (`b_turret_coil.png`) — Coilward uses stronger turret stats via `building_mods` only. Default: one art + team/faction modulate.

**Ghost placement:** can reuse building sprite at 40% alpha (**P2** dedicated ghost atlas optional).

---

## 3. Units (world sprites)

### 3.1 Aureate (`faction: aureate`)

| Asset path | Unit ID | Name | radius | Source px (guide) | Facing | Priority | Status |
|------------|---------|------|--------|-------------------|--------|----------|--------|
| `assets/units/infantry_aureate.png` | `u_infantry` | Trooper | 8 | **64×64** | +X | **P0** | missing |
| `assets/units/trooper_h_aureate.png` | `u_trooper_h` | Heavy Trooper | 10 | **80×80** | +X | **P0** | missing |
| `assets/units/harvester_aureate.png` | `u_harvester` | Spice Harvester | 16 | **160×96** | +X / scoop forward | **P0** | missing |
| `assets/units/trike_aureate.png` | `u_trike` | Scout Trike | 11 | **96×64** | +X | **P0** | missing |
| `assets/units/quad_aureate.png` | `u_quad` | Assault Quad | 13 | **112×80** | +X | **P0** | missing |
| `assets/units/tank_aureate.png` | `u_tank` | Battle Tank | 15 | ~583×371 (ok) | **+X gun** | **P0** | **exists** |
| `assets/units/siege_aureate.png` | `u_siege` | Siege Tank | 16 | **160×96** | +X barrel | **P0** | missing |
| `assets/units/msa_aureate.png` | `u_msa` | Missile Launcher | 14 | **128×96** | +X / racks up | **P0** | missing |

### 3.2 Ashveil (`faction: ashveil`)

Unique chassis preferred for signature; tint of Aureate OK short-term (**P1** unique).

| Asset path | Unit ID | Name | radius | Source px | Facing | Priority | Status |
|------------|---------|------|--------|-----------|--------|----------|--------|
| `assets/units/infantry_ashveil.png` | `ash_infantry` | Ash Raider | 8 | 64×64 | +X | **P0** | missing |
| `assets/units/flame_ashveil.png` | `ash_flame` | Flame Trooper | 10 | 80×80 | +X + nozzle FX cue | **P0** | missing |
| `assets/units/harvester_ashveil.png` | `ash_harvester` | Ash Harvester | 15 | 160×96 | +X | **P1** | missing (tint aureate harvester OK for P0) |
| `assets/units/trike_ashveil.png` | `ash_trike` | Ash Trike | 10 | 96×64 | +X | **P1** | missing |
| `assets/units/quad_ashveil.png` | `ash_quad` | Ash Quad | 12 | 112×80 | +X | **P1** | missing |
| *(reuse)* `tank_aureate.png` + tint | `ash_tank` | Ash Tank | 14 | — | +X | **P0** | **exists** (tint) |

### 3.3 Coilward (`faction: coilward`)

| Asset path | Unit ID | Name | radius | Source px | Facing | Priority | Status |
|------------|---------|------|--------|-----------|--------|----------|--------|
| `assets/units/infantry_coilward.png` | `coil_infantry` | Coil Trooper | 9 | 64×64 | +X | **P0** | missing |
| `assets/units/guard_coilward.png` | `coil_guard` | Coil Guard | 11 | 80×80 | +X | **P0** | missing |
| `assets/units/harvester_coilward.png` | `coil_harvester` | Coil Harvester | 16 | 160×96 | +X | **P1** | missing |
| `assets/units/trike_coilward.png` | `coil_trike` | Coil Scout | 11 | 96×64 | +X | **P1** | missing |
| `assets/units/quad_coilward.png` | `coil_quad` | Coil Quad | 13 | 112×80 | +X | **P1** | missing |
| *(reuse)* `tank_aureate.png` + tint | `coil_tank` | Coil Fortress Tank | 16 | — | +X | **P0** | **exists** (tint) |
| `assets/units/air_coilward.png` | `coil_air` | Ornithopter | 12 | **128×96** | +X nose / wings | **P0** | missing |

### 3.4 Shared utility

| Asset path | Unit ID | Name | radius | Source px | Facing | Priority | Status |
|------------|---------|------|--------|-----------|--------|----------|--------|
| `assets/units/carryall.png` | `u_carryall` | Carryall | 16 | **160×80** | +X fuselage | **P0** | missing |

### 3.5 Hazard (not a `data/units` ID; scene node `Sandworm`)

| Asset path | Entity | View | Size | Facing | Priority | Status |
|------------|--------|------|------|--------|----------|--------|
| `assets/hazards/sandworm.png` | Sandworm FSM | top-down body / maw | **256×128** or 128×128 | +X mouth optional | **P0** | missing |

---

## 4. FX / VFX

Drawn as lines/circles today. Soft particle sheets or single frames.

| Asset path | Use | View | Size | Facing | Priority | Status |
|------------|-----|------|------|--------|----------|--------|
| `assets/fx/projectile_bolt.png` | Default ballistic (trike/tank/turret) | sprite | **32×16** | +X tip | **P0** | missing |
| `assets/fx/projectile_missile.png` | `u_msa` | sprite | **48×16** | +X | **P1** | missing |
| `assets/fx/projectile_flame.png` | `ash_flame` splash cue | sprite / cone | **64×32** | +X | **P1** | missing |
| `assets/fx/explosion_small.png` | Unit death / light hit | omni | **64×64** | n/a | **P0** | missing |
| `assets/fx/explosion_large.png` | Building destroy / siege | omni | **128×128** | n/a | **P1** | missing |
| `assets/fx/harvest_spark.png` | Harvester spice take | particle | **32×32** | n/a | **P1** | missing |
| `assets/fx/worm_sandburst.png` | Worm emerge / feast | omni | **128×128** | n/a | **P1** | missing |
| `assets/fx/muzzle_flash.png` | Shot feedback | sprite | **32×32** | +X | **P2** | missing |

Selection rings / HP bars stay code-drawn (**no texture required**).

---

## 5. UI textures

Build/produce menus are **text buttons** today (`build_menu.gd`). Icons are art-pass, not blockers for play.

### 5.1 Build menu icons (one per building ID)

| Asset path | Entity | Size | Priority | Status |
|------------|--------|------|----------|--------|
| `assets/ui/icons/build_conyard.png` | `b_conyard` | **64×64** | **P1** | missing |
| `assets/ui/icons/build_power.png` | `b_power` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_refinery.png` | `b_refinery` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_silo.png` | `b_silo` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_barracks.png` | `b_barracks` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_factory.png` | `b_factory` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_turret.png` | `b_turret` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_radar.png` | `b_radar` | 64×64 | **P1** | missing |
| `assets/ui/icons/build_camp.png` | `b_camp` (debug/enemy) | 64×64 | **P2** | missing |

### 5.2 Produce icons (unit IDs that appear in faction `produces`)

Crop/silhouette of world sprite at **64×64** is enough.

| Asset path | Unit IDs | Priority | Status |
|------------|----------|----------|--------|
| `assets/ui/icons/unit_infantry.png` | `u_infantry` | **P1** | missing |
| `assets/ui/icons/unit_trooper_h.png` | `u_trooper_h` | **P1** | missing |
| `assets/ui/icons/unit_trike.png` | `u_trike` | **P1** | missing |
| `assets/ui/icons/unit_quad.png` | `u_quad` | **P1** | missing |
| `assets/ui/icons/unit_tank.png` | `u_tank` (+ ash/coil via tint) | **P1** | missing |
| `assets/ui/icons/unit_siege.png` | `u_siege` | **P1** | missing |
| `assets/ui/icons/unit_msa.png` | `u_msa` | **P1** | missing |
| `assets/ui/icons/unit_harvester.png` | `u_harvester` / ash / coil | **P1** | missing |
| `assets/ui/icons/unit_ash_infantry.png` | `ash_infantry` | **P1** | missing |
| `assets/ui/icons/unit_ash_flame.png` | `ash_flame` | **P1** | missing |
| `assets/ui/icons/unit_ash_trike.png` | `ash_trike` | **P2** | missing |
| `assets/ui/icons/unit_ash_quad.png` | `ash_quad` | **P2** | missing |
| `assets/ui/icons/unit_coil_infantry.png` | `coil_infantry` | **P1** | missing |
| `assets/ui/icons/unit_coil_guard.png` | `coil_guard` | **P1** | missing |
| `assets/ui/icons/unit_coil_trike.png` | `coil_trike` | **P2** | missing |
| `assets/ui/icons/unit_coil_quad.png` | `coil_quad` | **P2** | missing |
| `assets/ui/icons/unit_coil_air.png` | `coil_air` | **P1** | missing |
| `assets/ui/icons/unit_carryall.png` | `u_carryall` | **P1** | missing |

### 5.3 Cursors, emblems, advisor

| Asset path | Use | Size | Priority | Status |
|------------|-----|------|----------|--------|
| `assets/ui/cursor_select.png` | Default select | 32×32 hotspot | **P1** | missing |
| `assets/ui/cursor_move.png` | Move order | 32×32 | **P1** | missing |
| `assets/ui/cursor_attack.png` | Attack | 32×32 | **P1** | missing |
| `assets/ui/cursor_harvest.png` | Optional harvest | 32×32 | **P2** | missing |
| `assets/ui/emblem_aureate.png` | Lobby / HUD | **128×128** | **P1** | missing |
| `assets/ui/emblem_ashveil.png` | Lobby / HUD | 128×128 | **P1** | missing |
| `assets/ui/emblem_coilward.png` | Lobby / HUD | 128×128 | **P1** | missing |
| `assets/ui/advisor_portrait.png` | Advisor panel | **256×256** | **P2** | missing |
| `assets/ui/logo_sandspire.png` | Main menu | 512×256 | **P2** | missing |

**Minimap:** terrain + dots are code-drawn (`minimap.gd`) — **no texture required** (P2 optional parchment frame).

---

## 6. Suggested production order (P0)

1. Terrain tiles (sand/rock/spice/bloom)  
2. Buildings pack (9)  
3. Aureate missing combat + harvester (infantry → MSA)  
4. Carryall + sandworm + coil_air  
5. Ashveil infantry + flame (signature)  
6. Coilward infantry + guard  
7. FX: bolt + small explosion  

Then P1: remaining house variants, UI icons, cursors, emblems.

---

## 7. Wiring notes (for implementers)

| Area | Current code | Hook |
|------|--------------|------|
| Units | `unit.gd` tank path | Extend `_setup_sprite()` map `unit_id` → path; keep +X facing |
| Harvester / carryall | Own `_draw()` | Same texture draw helper or Sprite2D child |
| Buildings | `building.gd` rects | `draw_texture_rect` by `building_id` |
| Terrain | `world_map.gd` | Tile atlas or per-cell texture |
| Worm | `sandworm.gd` | Replace circle maw with sprite |
| UI icons | `build_menu.gd` | Button icon textures |

---

## 8. Explicit non-goals (this pass)

- Audio / music  
- Multi-direction walk cycles (8-dir)  
- Unique building art per faction (optional P2)  
- Photoreal / 3D renders  
- Units not in `data/units/` (no 4th faction)

---

*Generated from live roster inventory. Update this file when `data/*.json` gains entities.*
