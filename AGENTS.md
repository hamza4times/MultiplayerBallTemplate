# Agents.md

## Project

Godot 4.6 project — "Multiplayer Tag", a high-level multiplayer (HLAPI) demo with ENet.

## Entrypoints

- Main scene: `res://scenes/Menu/Menu.tscn`
- Autoload singleton: `globals/Lobby.gd` (registered as `Lobby` in `project.godot:18-20`)
- `Player` has `class_name Player` (`scenes/Player/Player.gd:2`) — usable as a type without a path reference

## Architecture

- **Lobby** (autoload) — manages ENet server/client peers, player registry, and `@rpc` game-load protocol. Port 7000, max 12 connections.
- **Menu** — host/join UI; calls `Lobby.create_game()` / `Lobby.join_game(address)`; host-only start button calls `Lobby.load_game.rpc("res://scenes/Game/World.tscn")`
- **World** — server-authoritative game loop; uses `MultiplayerSpawner` with a custom `spawn_function`; manages "it" tag via `broadcast_it_change.rpc()`. Spawns players evenly distributed in a circle of radius 5 at y=1.0 (above the floor), with `TAU / total_players` angular spacing so no two players share a spawn point.
- **Player** — `CharacterBody3D` with camera attached to `SpringArm3D`; movement via WASD (custom InputMap actions registered by `Lobby._setup_inputs`); `send_transform.rpc("unreliable")` for position sync
- **GameUI** — `CanvasLayer` child of World; shows who is "IT" and player list

## Lobby / Locker

- **Menu** now uses a `TabContainer` (2 tabs: "Play", "Locker").
  - `Play` tab: original host/join UI.
  - `Locker` tab: 3D character preview (`SubViewportContainer` → `SubViewport` → `Camera3D` + `MeshInstance3D` sphere) on the left; 7 color‑preset buttons on the right; Save button at bottom.
- Color is stored to `user://player_data.cfg` via `FileAccess.store_var()` / `get_var()`.
- `Lobby.player_info` now includes key `"color"` alongside `"name"`. It is transmitted automatically through the existing `register_me` / `_add_player` RPCs — no additional networking code.
- Saved color is loaded by `Lobby.load_player_data()` on `_ready()`, so it persists across sessions.
- Color can only be changed before hosting/joining (pre‑game only).

## Tag indicator

- Instead of turning the player red, the "it" player gets a red torus‑mesh crown (`TorusMesh` with `inner_radius=0.25`, `outer_radius=0.35`) positioned at `(0, 0.75, 0)` above the sphere.
- The crown is hidden by default and toggled via `set_it()` → `halo.visible = value`.
- A `_process(delta)` loop rotates the crown at `2.0 rad/s` when visible (runs on every peer, not just authority).
- The node is declared in `Player.tscn` as `Halo` (a `MeshInstance3D` child).

## Color application

- `Player._ready()` reads `Lobby.players.get(peer_id, {}).get("color", Lobby.COLORS["Blue"])` and applies it to the mesh material.
- Since `Lobby.players` is populated on all peers before `spawn_all_players()`, the color is correctly applied for every player on every machine.

## Networking model

- ENet via `ENetMultiplayerPeer` (TCP-like reliability, UDP transport)
- Server is authoritative: tag detection and spawn logic run only on server (`multiplayer.is_server()` gates)
- RPC annotations used:
  - `"authority", "reliable"` — server-to-client only
  - `"any_peer", "reliable"` — clients can call
  - `"unreliable"` — position sync (frequency: every physics frame)
- No `MultiplayerSpawner` `spawn_path` — spawn function is set in code at `World._ready()`
- Players are nodes named by `str(peer_id)`, looked up via `get_node_or_null(str(id))`

## Running

- Open in Godot 4.6.x, run `Menu.tscn` as main scene
- To test multiplayer locally: run two instances; host on one, join `127.0.0.1:7000` on the other
- No tests, no CI, no formatter/linter config — this is a tutorial scratch project

## Gotchas

- `InputMap` actions (`move_left`, `move_right`, `move_forward`, `move_back`) are registered *at runtime* by `Lobby._setup_inputs()`, not in the project settings. They will not appear in the editor's Input Map tab.
- `_contact_state` dictionary on World tracks tag contact per unordered peer pair to avoid re-tagging on consecutive frames
- Players are spawned with `set_multiplayer_authority(peer_id)`, so client input and `is_multiplayer_authority()` checks work per-player
- Directory `.godot/` is gitignored; import caches, shader caches, and editor metadata are local-only
- `Lobby.COLORS` is a `Dictionary` with insertion order (Red, Orange, Yellow, Green, Blue, Purple, Pink). Iteration order is stable in Godot 4.x.

## What not to touch

- `.godot/` — auto-generated, should never be committed or edited

## Engine reference

- **Always read `ai_context/GodotEngine.txt` first** before writing any GDScript, editing scenes, or making engine-related decisions. It is a local snapshot of the Godot 4.7 documentation and is the authoritative source for available classes, methods, signals, annotations, and engine behavior. Do not rely on general knowledge — the snapshot may differ from what you remember.
