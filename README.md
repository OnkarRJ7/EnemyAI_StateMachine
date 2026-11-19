# 3D Enemy AI – State Machine

A 3D enemy AI built with **Godot 4.7.2** and **GDScript** for a game development assignment.

The enemy uses an enum-based finite state machine (FSM) to patrol an area, detect and chase the player, and attack when the player gets close. It returns to patrol when the player escapes.

## Features

- **Patrol:** moves back and forth between two patrol points defined relative to its start position.
- **Player detection:** notices the player inside a configurable detection range.
- **Chase:** follows the player on the ground plane.
- **Attack with cooldown:** attacks only when its timer allows, never every physics frame.
- **Return to patrol:** gives up the chase when the player leaves detection range.
- **Hysteresis:** a small buffer around each range prevents rapid flipping between states at the boundary.
- **State visualization:** a `Label3D` above the enemy shows the current state, and every transition is printed to the Output panel.
- **Arena boundaries:** static collision walls keep the player and enemy inside the arena.

## AI State Machine

| State | Behaviour |
|---|---|
| `PATROL` | Walks between two patrol points and checks for the player every physics tick. |
| `CHASE` | Moves toward the player at `chase_speed`. |
| `ATTACK` | Stands still, faces no extra movement, and attacks once per `attack_cooldown`. |

### State diagram

```text
              player within detection_range
   PATROL  ──────────────────────────────────▶  CHASE
      ▲                                           │  ▲
      │   player beyond                           │  │ player beyond
      │   detection_range + hysteresis            │  │ attack_range + hysteresis
      └───────────────────────────────────────────┘  │
                                                     ▼  │
                                                    ATTACK
                          (player within attack_range)
```

### Transitions

| From | To | Condition |
|---|---|---|
| PATROL | CHASE | Player is within `detection_range` |
| CHASE | ATTACK | Player is within `attack_range` |
| ATTACK | CHASE | Player is beyond `attack_range + hysteresis` |
| CHASE | PATROL | Player is beyond `detection_range + hysteresis` |
| Any | PATROL | Player reference is no longer valid |

There is no direct PATROL → ATTACK transition. Everything goes through CHASE, which keeps the logic easy to follow.

## Design Notes

- **Single place for state changes:** only `change_state()` modifies `state`. It logs the transition, clears horizontal velocity and updates the label, so there is one spot to debug.
- **Dispatch with `match`:** `_physics_process()` calls one function per state (`patrol_state`, `chase_state`, `attack_state`).
- **Movement:** each state only sets `velocity`. `move_and_slide()` is called once per tick at the end of `_physics_process()`, and gravity is the only thing that writes `velocity.y`.
- **Ground-plane distance:** all range checks zero the Y component first, so height differences never affect detection and the enemy never tries to move vertically.
- **Hysteresis:** a state is entered at the exact range but only left after the player passes `range + hysteresis`, the same dead-band idea used to debounce a noisy signal.
- **Attack cooldown:** a single timer counts down every physics tick, independent of the current state, so stepping in and out of range cannot be used to attack faster.
- **Null safety:** `_distance_to_player()` returns `INF` when the player is missing or freed (`is_instance_valid`), so every range check simply fails.

## Technical Implementation

### Player
- `CharacterBody3D` with a capsule collider and mesh.
- Moves with the arrow keys through `Input.get_vector()`.
- Applies gravity and collision through `move_and_slide()`.
- Adds itself to the `player` group so the enemy can find it with `get_first_node_in_group()`.

### Enemy
- `CharacterBody3D` with a capsule collider, a capsule mesh and a `Label3D` child.
- Enum-based FSM in a single script, `enemy.gd`.
- Direct movement toward targets. Obstacle navigation is intentionally not used.

### Environment
- `StaticBody3D` ground and boundary walls with `CollisionShape3D` nodes.
- Player and enemy live in separate scenes and are instanced into `main.tscn`.

## Project Structure

```text
EnemyAI_StateMachine/
│
├── Scenes/
│   ├── main.tscn
│   ├── player.tscn
│   ├── player.gd
│   ├── enemy.tscn
│   └── enemy.gd
│
├── project.godot
├── icon.svg
├── .gitignore
├── .gitattributes
├── .editorconfig
└── README.md
```

## How to Run

1. Clone or download this repository.
2. Open **Godot 4.7.2** (the standard version, not .NET).
3. Click **Import** and select `project.godot`.
4. Open `Scenes/main.tscn`.
5. Press **F6** (Run Current Scene), or set it as the main scene and press **F5**.

## Controls

| Key | Action |
|---|---|
| Arrow keys | Move the player |

## Configuration

These variables are exported, so they can be changed in the Inspector on the `Enemy` node without touching the code:

| Group | Variable | Default | Description |
|---|---|---|---|
| Movement | `gravity` | 20.0 | Downward acceleration |
| Movement | `patrol_speed` | 2.0 | Speed while patrolling |
| Movement | `chase_speed` | 4.0 | Speed while chasing (lower than the player's 6.0) |
| Patrol | `patrol_distance` | 4.0 | Distance of each patrol point from the start, along X |
| Patrol | `arrive_threshold` | 0.2 | How close counts as "reached" |
| Detection and Attack | `detection_range` | 10.0 | Distance at which the player is noticed |
| Detection and Attack | `attack_range` | 2.0 | Distance at which the enemy attacks |
| Detection and Attack | `attack_cooldown` | 1.0 | Seconds between attacks |
| Detection and Attack | `hysteresis` | 1.0 | Extra distance needed before leaving a state |

`attack_range` should stay smaller than `detection_range`. The script warns if it is not.

## Testing the Behaviour

Run `main.tscn` with the Output panel open and the player starting far from the enemy.

1. The enemy patrols and the label reads `PATROL`.
2. Walk into detection range. Output: `Enemy: PATROL -> CHASE`.
3. Let the enemy reach you. Output: `Enemy: CHASE -> ATTACK`, then `Enemy: ATTACK! (distance = ...)` about once per cooldown.
4. Walk away. Output: `Enemy: ATTACK -> CHASE`.
5. Keep going beyond the detection range. Output: `Enemy: CHASE -> PATROL`, and the enemy resumes patrolling.

Example output for a full cycle:

```text
Enemy: PATROL -> CHASE
Enemy: CHASE -> ATTACK
Enemy: ATTACK! (distance = 1.99)
Enemy: ATTACK! (distance = 1.99)
Enemy: ATTACK -> CHASE
Enemy: CHASE -> PATROL
```

## Possible Improvements

- Line-of-sight raycast so walls block detection.
- Rotate the enemy to face its movement direction and add a field-of-view check.
- Obstacle avoidance with `NavigationAgent3D`.
- Node-based state machine, with each state as its own script.
- A simple player health system so attacks deal damage.

## Technologies Used

- Godot Engine 4.7.2
- GDScript
- 3D physics and collision (`CharacterBody3D`, `StaticBody3D`)
- Finite state machine (FSM)
- Git and GitHub

## Notes

Attacks are represented by a message in the Output panel. A health or damage system is outside the scope of this assignment, which focuses on the AI logic, state transitions and movement.

## Author

**Onkar R. Jadhav**

GitHub: [@OnkarRJ7](https://github.com/OnkarRJ7)
