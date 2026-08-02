# Sandspire — Known issues (MVP / M4)

Honest limitations of the **0.4.0 MVP** build. Not a bug tracker — expectations for playtesters.

## Gameplay / content

- **One procedural map layout** with seed/force variants — not unique authored maps per mission.
- **Skirmish win** is still “destroy enemy camp” (or tagged `enemy_base` in finale), not full base annihilation / CY-only GDD ideal.
- **Balance v1** only — factions are distinct but not tournament-tuned.
- **AI** is utility waves + economy stub; no high-level strategy or tech switching mid-game.
- **Sandworm** is a simple FSM; can feel unfair or quiet depending on harvest noise.
- **Campaign briefings** are English-only; RU locale covers HUD chrome, not mission text.
- **Survive missions** can be cheesed by turtling; timers are short for MVP pacing.

## Tech / UX

- **No multiplayer**, no lobby, no replays.
- **Save/load** is pragmatic (buildings/units/credits/objectives) — not bit-perfect; edge cases after load may need a restart.
- **SFX** are procedural beeps — no music, no unit VO, no Mentat voice.
- **Placeholder art** — colored rects / simple draw, not production sprites.
- **Fog of war** and pathfinding are good-enough; large armies can crowd chokepoints oddly.
- **Headless / CI** is the primary verification path; GPU/driver quirks on desktops are lightly tested.
- **Export**: Windows binary needs templates on the build machine; Linux export is the lab default on server 110.

## Not in MVP

Multiplayer, workshop mods, public map editor, mobile, Steam page polish, achievements, full localization of campaigns.
