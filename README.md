# Chicken War — Godot 4 FPS prototype

A small single-player Chicken War–style FPS built with **Godot 4.7** and Forward+ rendering.

You play as an armed chicken fighting a squad of rival chickens for control of the capture point in the middle of the map.

## Features

- First-person controller with sprint, crouch, jump, mouse look, and ADS
- Low-poly AKM viewmodel with arms, textures, and `Idle` / `Shoot` / `Reload` animations
- Procedural audio for gunshots, reloads, hitmarkers, distant bot fire, and grenade explosions
- Hit-scan rifle with recoil, spread, tracers, muzzle flash, and headshots
- Frag grenades with physics and area damage
- Material You–style main menu with large `PLAY` / `LEAVE` actions and a match-settings card
- Match editor: 0–8 AI allies, 1–12 enemies, and three AI difficulty levels, saved automatically
- AI chicken squads with FOV perception, target memory, reaction delay, aim settling, cover seeking, suppression, flanking, ally alerts, obstacle avoidance, and friendly-fire checks
- Role-based AI (`assault`, `support`, `flank`, `escort`) that pushes, holds angles, and contests the capture point
- Capture-point progress bar, kill/death stats, team-alive counters, health, ammo, and hitmarker HUD
- Procedural low-poly map with buildings, trees, crates, and a central objective

## Controls

| Input | Action |
| --- | --- |
| `WASD` | Move |
| Mouse | Look |
| `Shift` | Sprint |
| `Ctrl` / `C` | Crouch |
| `Space` | Jump |
| Left mouse | Fire |
| Right mouse | Aim down sights |
| `R` | Reload |
| `G` | Throw grenade |
| `Esc` | Pause / resume |

The game starts from the main menu. Use the settings card to choose ally/enemy counts and AI difficulty, then press `PLAY`. Click or press `Enter` anywhere outside the card to start with the current settings. Match settings persist in `user://chickenwar_settings.cfg`.

## Running

1. Install [Godot 4.7](https://godotengine.org/download/) or newer.
2. Open `project.godot` in the editor.
3. Press `F5`.

The project also supports headless validation:

```powershell
godot --headless --path . --quit-after 120 -- --test
```

Developer flags (after `--`): `--test`, `--menu`, `--aidiag`, `--menutest`, `--allies=N`, `--enemies=N`, `--difficulty=0..2`, `--screenshot=<path>`, `--ads`, `--fire`, `--reload`.

## Screenshots

![Main menu](screenshots/main_menu.png)
![AI gameplay](screenshots/gameplay_ai.png)
![Hip fire](screenshots/hipfire.png)
![ADS](screenshots/ads.png)
![Firing](screenshots/firing.png)
![Reload](screenshots/reload.png)

## Credits

- **AKM FPS Rig** and **AKM** by **J-Toastie** — [Poly Pizza](https://poly.pizza/m/U6l6wjxFhC), licensed under [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/). See [CREDITS.md](CREDITS.md).
- Made with [Godot Engine](https://godotengine.org/) (MIT).

All other game code, level geometry, chickens, and UI were created for this prototype.
