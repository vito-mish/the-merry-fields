# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**The Merry Fields** (《樂樂物語》) is a cozy farming RPG built in Godot 4.6 (GDScript, GL Compatibility renderer). The viewport is 320×180 scaled to 1280×720 with nearest-neighbor filtering for pixel-perfect rendering.

## Running & Syntax Checking

There is no build step — open `project.godot` in Godot 4.6 and press F5 to run. The main scene is `scenes/maps/farm.tscn`.

To check GDScript syntax without opening the editor:
```bash
bash check.sh
```

To regenerate pixel art assets (requires Python):
```bash
python tools/generate_sprites.py
python tools/generate_tileset.py
```

## Architecture

### Scene Graph Pattern
Both map scenes (`farm.tscn`, `village.tscn`) share the same structure:
```
MapRoot (Node2D) [map script]
├── TileMap            ← procedurally filled at runtime
├── YSort (Node2D)     ← y_sort_enabled=true; player + trees live here
└── HUD (CanvasLayer)  ← minimap overlay
```
The tilemap and all collision bodies, spawn points, and scene exits are created in code (`_ready()`), not in the .tscn file.

### Autoload Singleton
`TransitionManager` (autoloaded from `scripts/managers/transition_manager.gd`) is the only singleton. All scene transitions go through it:
```gdscript
TransitionManager.change_scene("res://scenes/maps/village.tscn", "from_farm")
```
It fades to black, calls `get_tree().change_scene_to_file()`, then teleports the player to the matching `SpawnPoint` and fades in.

### Group-Based Object Discovery
Nodes find each other via Godot groups — never via hardcoded paths:
- `"player"` — the player CharacterBody2D
- `"tile_map"` — the TileMap in the current scene
- `"spawn_point"` — all SpawnPoint markers; TransitionManager queries these by `spawn_id`

### Collision
Collision is done with `StaticBody2D` nodes added at runtime (not TileMap physics layers). Farm has 5–7 wall bodies; Village adds per-building rectangles. This was a deliberate fix after TileMap physics caused issues.

### Y-Sort Rendering
Trees (`TreeObject.tscn`) and the player must be children of a `Node2D` with `y_sort_enabled = true`. The Farm root node itself should **not** have y_sort enabled (caused player disappearing bug).

## Key Scripts

| Script | Role |
|--------|------|
| `scripts/characters/player.gd` | Movement (80 px/s), 4-dir animation, stamina data |
| `scripts/maps/farm.gd` | Procedural farm tilemap (60×60), colliders, exits, trees |
| `scripts/maps/village.gd` | Procedural village tilemap (80×50), buildings, roads |
| `scripts/managers/transition_manager.gd` | Fade + scene switch + player teleport |
| `scripts/ui/minimap.gd` | Draws tilemap snapshot + player dot each frame |
| `scripts/world/scene_exit.gd` | Area2D that triggers TransitionManager on player contact |
| `scripts/world/spawn_point.gd` | Marker2D with `spawn_id`; added to "spawn_point" group |
| `scripts/world/tree_object.gd` | Procedural pixel-art tree drawn with Polygon2D nodes |

## Tileset

`assets/tilesets/farm_tiles.png` has 8 tile types at 16×16 px each (atlas coords 0–7):
`(0,0)` Grass, `(1,0)` Dirt, `(2,0)` Tilled, `(3,0)` Watered, `(4,0)` Path, `(5,0)` Water, `(6,0)` Fence, `(7,0)` Border

The minimap palette in `minimap.gd` must match these indices exactly.

## Input Map

Defined in `project.godot`. Always add both keyboard and joypad bindings when creating new actions:
- `move_up/down/left/right` — WASD, arrows, left stick
- `action` — Z, Joypad A
- `cancel` — X, Joypad B
- `menu` — Esc, Joypad Start

## Development Roadmap

See `docs/project-spec.md` for the full 14-story task list and `docs/game-design.md` for mechanics design. Current priority order per spec:
1. **S02** — Time system (game clock, day/night)
2. **S04** — Farming system (till → plant → water → harvest)
3. **S11** — Basic HUD (time, stamina, money)
4. **S12** — Save/load

Completed: S01 (player movement), S03 (world map + transitions + minimap).

## Development Workflow (IMPORTANT)

Follow this loop every time you implement a feature:

1. **Develop** — write code, fix bugs
2. **Verify syntax** — run `bash check.sh` after every logical unit; fix errors immediately before continuing
3. **Report to user** — when a feature is ready, STOP and provide:
   - **功能描述**: what was built and how it works
   - **測試案例表**: a table of test cases with steps and expected results
   - End with: "✋ 請測試以上案例，確認後告訴我"
   - Then **wait for the user's response**
4. **Fix bugs** — if the user reports issues, fix them and ask them to re-test
5. **Update spec** — once the user confirms everything is working, IMMEDIATELY update `docs/project-spec.md`: mark completed tasks as `✅ 完成` and update the Story progress count. Do NOT wait to be asked.
6. **Commit only when asked** — NEVER run `git commit` or `git push` unless the user explicitly says "commit" or "commit+push"

Do NOT assume tests pass. Do NOT auto-commit after finishing code.

## Known Issues / Gotchas

- **Minimap is hardcoded to 60×60 tiles** — displays incorrectly in the village (80×50). Needs dynamic map size.
- `scenes/world/main.tscn` is an unused test scene; `farm.tscn` is the actual main scene.
- Stamina fields exist on the player but no UI or consumption logic is wired up yet.
