# Sandspire — Rosters (three houses)

**Balance v1 (M3):** authoritative numbers + counters in [balance.md](balance.md).  
Costs in credits. Build time at full power.

Faction: `--player=aureate|ashveil|coilward --enemy=…`  
Difficulty: `--difficulty=easy|normal|hard` (default normal).

## Signatures

| House | Signature |
|-------|-----------|
| **Aureate** | Reliable tank line (siege + MSA) |
| **Ashveil** | Flame Trooper splash |
| **Coilward** | Fortress turrets (`building_mods`) + Ornithopter air at Outpost |

## Shared buildings

| ID | Name | Cost | Power | Prereq | Notes |
|----|------|------|-------|--------|------|
| `b_conyard` | Construction Yard | — | 0 | Start | |
| `b_power` | Windtrap | 300 | +100 | CY | |
| `b_refinery` | Spice Refinery | 400 | −30 | Power | Faction harvester |
| `b_silo` | Spice Silo | 150 | −5 | Refinery | +500 credit cap |
| `b_barracks` | Barracks | 250 | −20 | Power | |
| `b_factory` | Vehicle Factory | 400 | −30 | Refinery | Coilward: 0.65× prod rate |
| `b_turret` | Gun Turret | 200 | −15 | Barracks | Baseline DPS 18; Coilward DPS 32 / HP 520 |
| `b_radar` | Outpost | 300 | −20 | Factory | Coilward produces `coil_air` |

## Aureate

| ID | Cost | HP | DPS | Speed | Label |
|----|------|----|-----|-------|-------|
| `u_infantry` | 50 | 60 | 8 | 100 | TRP |
| `u_trooper_h` | 100 | 90 | 14 | 90 | HVY |
| `u_harvester` | 0* | 400 | 0 | 120 | HV |
| `u_trike` | 150 | 120 | 12 | 180 | TRK |
| `u_quad` | 200 | 180 | 18 | 150 | QAD |
| `u_tank` | 300 | 320 | 28 | 110 | TNK |
| `u_siege` | 450 | 280 | 40 | 85 | SG |
| `u_msa` | 450 | 200 | 35 | 95 | MSL |

## Ashveil (raid)

| ID | Cost | HP | DPS | Speed | Label |
|----|------|----|-----|-------|-------|
| `ash_infantry` | 40 | 55 | 9 | 115 | ARD |
| `ash_flame` | 90 | 80 | 12+splash | 95 | FLM |
| `ash_harvester` | 0* | 380 | 0 | 130 | AHV |
| `ash_trike` | 120 | 100 | 14 | 200 | ATK |
| `ash_quad` | 170 | 160 | 20 | 165 | AQD |
| `ash_tank` | 280 | 260 | 22 | 120 | ATN |

## Coilward (fortress)

Heavier/slower. Factory production ×0.65. Air from Outpost ignores ground path blocks.

| ID | Cost | HP | DPS | Speed | Label |
|----|------|----|-----|-------|-------|
| `coil_infantry` | 60 | 85 | 7 | 85 | CTR |
| `coil_guard` | 120 | 130 | 12 | 75 | GRD |
| `coil_harvester` | 0* | 480 | 0 | 100 | CHV |
| `coil_trike` | 160 | 140 | 10 | 150 | CSK |
| `coil_quad` | 230 | 240 | 16 | 120 | CQD |
| `coil_tank` | 360 | 420 | 26 | 90 | CFT |
| `coil_air` | 350 | 140 | 16 | 190 | ORN (flying) |

\*Free with new refinery.

## AI subset

Enemy AI: faction infantry / quad / tank only.

## Hazards

Sandworm: harvest noise on sand; rock + air safe.
