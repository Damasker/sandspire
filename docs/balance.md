# Sandspire — Balance v1 (S12 / M3)

Living table. Values match `data/units/*.json` after S12 tune.  
**Armor:** none=0, light=0, medium=3, heavy=6 damage reduction per hit (see `GameConstants`).

## Design goals

| House | Fantasy | Win condition | Softness |
|-------|---------|---------------|----------|
| **Aureate** | Balanced industrial | Mid/late tanks + siege/MSA | Baseline |
| **Ashveil** | Raid | Early map control, flame clumps | Soft tanks, fragile if stalled |
| **Coilward** | Fortress | Turrets + air spike after Outpost | Slow factory (×0.65), expensive heavies |

No income cheats by faction. AI difficulty only changes start credits / wave cadence / think rate (see `data/ai/`).

## Counters (v1 sketch)

- **Light vehicles (trike/quad)** beat **infantry**; lose to **tanks** and **turrets**.
- **Flame (Ashveil)** shreds **clumped light infantry/vehicles**; dies to **range** and **tanks**.
- **Battle / Fortress tanks** beat **lights**; pressured by **siege/MSA** and **air**.
- **Siege / MSA (Aureate)** delete **buildings / heavies** at range; fragile to **raids**.
- **Ornithopter (Coilward)** ignores ground blocks; weak HP — answer with **volume DPS** / focus fire.
- **Gun Turret** (Coilward fortified) anchors rock; bypass with **siege** or **air**.

## Combat units

### Aureate

| ID | Cost | HP | Armor | DPS | Range | Speed | Build | Role |
|----|------|----|-------|-----|-------|-------|-------|------|
| u_infantry | 50 | 60 | light | 8 | short | 100 | 2.5 | meat |
| u_trooper_h | 100 | 90 | light | 14 | med | 90 | 3.5 | anti-light |
| u_trike | 150 | 120 | light | 12 | short | 180 | 3.0 | scout |
| u_quad | 200 | 180 | light | 18 | med | 150 | 4.0 | generalist |
| u_tank | 300 | 320 | medium | 28 | med | 110 | 5.0 | frontline |
| u_siege | 450 | 280 | medium | **36** | long | 85 | 6.5 | anti-building |
| u_msa | 450 | **180** | light | 35 | long | 95 | 6.0 | glass cannon |

Signature: siege + MSA unlocks.

### Ashveil

| ID | Cost | HP | Armor | DPS | Range | Speed | Build | Role |
|----|------|----|-------|-----|-------|-------|-------|------|
| ash_infantry | 40 | 55 | light | 9 | short | 115 | 2.0 | cheap raid |
| ash_flame | 90 | 80 | light | 12+splash | short | 95 | 3.0 | area |
| ash_trike | **130** | 100 | light | **13** | short | 200 | 2.5 | early raid |
| ash_quad | 170 | 160 | light | 20 | med | 165 | 3.5 | raid mid |
| ash_tank | 280 | **280** | medium | **24** | med | 120 | 4.5 | soft tank |

Signature: flame splash (`splash_radius` 48, `splash_ratio` **0.40**).

### Coilward

| ID | Cost | HP | Armor | DPS | Range | Speed | Build | Role |
|----|------|----|-------|-----|-------|-------|-------|------|
| coil_infantry | **55** | 85 | medium | 7 | short | 85 | 3.0 | armoured meat |
| coil_guard | 120 | 130 | medium | 12 | med | 75 | 4.0 | heavy inf |
| coil_trike | 160 | 140 | light | 10 | short | 150 | 3.5 | slow scout |
| coil_quad | 230 | 240 | medium | 16 | med | 120 | 5.0 | armoured mid |
| coil_tank | **340** | 420 | heavy | 26 | med | **95** | 6.5 | fortress tank |
| coil_air | **375** | **130** | light | 16 | med | 190 | 5.5 | flying |

Signature: fortress turret mods + Ornithopter at Outpost. Factory `prod_rate_mult` **0.65**.

### Economy (all houses)

Harvesters cost **0** with refinery (queue time still applies). Tuned cargo/speed differ by fantasy; not a win-button.

## Building combat (turrets)

| Faction | Turret HP | DPS | Range px |
|---------|-----------|-----|----------|
| Shared baseline | 350 | 18 | med (~150) |
| Coilward mod | **520** | **32** | **210** |

## AI difficulty (`data/ai/`)

| Profile | Start credits | Think | Wave min | Wave CD | Max harvesters | Notes |
|---------|---------------|-------|----------|---------|----------------|-------|
| easy | 250 | 1.25s | 4 | 55s | 1 | Late weak waves |
| **normal** | 500 | 0.8s | 3 | 40s | 2 | Polished default |
| hard | 900 | 0.45s | 2 | 22s | 3 | Start boost only — no unit stat cheat |

Select: `--difficulty=easy|normal|hard` or `SANDSPIRE_DIFFICULTY`.

## S12 tune rationale

1. **Ash trike** slightly costlier / lower DPS — curb free map control.  
2. **Ash tank** +HP/DPS — raid house still fields a real mid tank.  
3. **Flame splash_ratio** 0.45→0.40 — strong in clumps, not delete blobs alone.  
4. **Aureate siege** 40→36 DPS — keeps anti-building identity without instant CY delete.  
5. **MSA** −20 HP — punish positioning.  
6. **Coil air** +cost −HP — air pathing advantage taxed.  
7. **Coil tank** −cost +speed — fortress tank reachable before Outpost air spike.

## Telemetry

HUD `Army` label: living combat unit count + summed unit costs per team (`CombatTelemetry`).
