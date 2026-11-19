# 3D Enemy AI – State Machine

A 3D enemy AI built with **Godot 4.7.2** and **GDScript** for a game development assignment.

The enemy uses an enum-based finite state machine (FSM) to patrol an area, detect and chase the player, and attack when the player gets close. It returns to patrol when the player escapes.

---

## Features

- **Patrol:** Moves back and forth between two patrol points defined relative to its start position, smoothly rotating to face its movement direction.
- **Player Detection:** Detects the player inside a configurable detection range (\(10.0\text{ m}\)).
- **Dynamic 3D Range Rings:** Visual circular boundaries rendered on the arena floor indicating the **Detection Range** (amber ring) and **Attack Range** (red ring).
- **Chase:** Follows the player on the ground plane, accelerating and facing the player directly.
- **Attack with Cooldown & Visual Effects:** Attacks only when the timer allows. Features an animated squash-and-stretch attack lunge and an expanding shockwave pulse ring.
- **Dynamic State Visuals:** The enemy's material and floating `Label3D` dynamically transition between states:
  - 🟢 **PATROL**: Emerald green with soft emission.
  - 🟠 **CHASE**: Alert amber/orange with bright emission.
  - 🔴 **ATTACK**: Aggressive crimson red with intense glow.
- **Player Health & Damage System:** Attacks deal damage to the player, updating a floating `Label3D` HP counter and triggering a visual red hit flash.
- **Return to Patrol:** Gives up the chase when the player leaves detection range.
- **Hysteresis:** A dead-band buffer around each range boundary prevents rapid flipping between states.
- **Enclosed Arena:** 3.5m tall, 1.0m thick perimeter walls with glowing cyan neon strips surround all 4 sides of the 30×30 ground, keeping entities safely inside.
- **Modern 3D Lighting:** WorldEnvironment with procedural sky, ambient lighting, bloom/glow, and real-time directional shadows.

---

## AI State Machine

| State | Behaviour | Visual Indication |
|---|---|---|
| `PATROL` | Walks between patrol waypoints and checks for the player every tick. | Emerald Green material, `[ PATROL ]` label |
| `CHASE` | Accelerates toward the player at `chase_speed`. | Amber/Orange material, `[ CHASE ]` label |
| `ATTACK` | Stands still, faces player, attacks with cooldown, lunge & shockwave. | Crimson Red material, `[ ATTACK ]` label |

### State Diagram

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
| `PATROL` | `CHASE` | Player is within `detection_range` |
| `CHASE` | `ATTACK` | Player is within `attack_range` |
| `ATTACK` | `CHASE` | Player is beyond `attack_range + hysteresis` |
| `CHASE` | `PATROL` | Player is beyond `detection_range + hysteresis` |
| Any | `PATROL` | Player reference is no longer valid |

There is no direct `PATROL` → `ATTACK` transition; all engagement transitions route through `CHASE` for clean logic.

---

## Design Notes

- **Single Place for State Changes:** Only `change_state()` modifies `state`. It logs transitions, resets horizontal velocity, updates the billboard label, and switches material colors and emissions.
- **Dispatch with `match`:** `_physics_process()` calls one modular function per state (`patrol_state`, `chase_state`, `attack_state`).
- **Smooth Rotation:** Both player and enemy use `lerp_angle` on the Y-axis to face their target or direction of movement.
- **Ground-Plane Distance:** Range calculations zero the Y component, ensuring height differences never interfere with detection or ground physics.
- **Hysteresis Debouncing:** States are entered at exact thresholds and exited only after `threshold + hysteresis`, eliminating state flickering near boundaries.
- **Independent Cooldown:** The attack timer decrements every physics tick independently of state, preventing attack spam through rapid boundary crossing.
- **Null Safety:** `_distance_to_player()` returns `INF` when the player is invalid or freed, causing range checks to safely fail.

---

## Technical Implementation

### Player (`player.tscn` / `player.gd`)
- `CharacterBody3D` with a capsule collider and mesh.
- Styled in cobalt blue with a glowing cyan front visor.
- Dual input support: **Arrow Keys** and **WASD**.
- Smooth rotation towards movement direction.
- Health tracking (`max_health = 100`, current health display) and `take_damage()` callback with visual hit flash.
- Registers in the `"player"` group on `_ready()`.

### Enemy (`enemy.tscn` / `enemy.gd`)
- `CharacterBody3D` with a capsule collider, capsule mesh, glowing visor, and `Label3D`.
- Dynamic `StandardMaterial3D` shifting colors between green, orange, and red.
- Ground range rings dynamically generated using `TorusMesh`.
- Animated lunge (squash-and-stretch tween) and expanding shockwave ring on attack execution.

### Environment & Arena (`main.tscn`)
- Ground: 30×30 static body with dark slate material.
- Walls: 4 interlocking 3.5m tall static barrier walls with cyan neon accent strips enclosing all 4 sides.
- Lighting: `DirectionalLight3D` with soft shadows, paired with a `WorldEnvironment` for procedural sky, ambient illumination, and bloom.

---

## Project Structure

```text
EnemyAI_StateMachine/
│
├── Scenes/
│   ├── main.tscn       # Main scene with arena, walls, lights, player, and enemy
│   ├── player.tscn     # Player scene (CharacterBody3D, mesh, visor, label)
│   ├── player.gd       # Player movement, rotation, WASD/arrows, health system
│   ├── enemy.tscn      # Enemy scene (CharacterBody3D, mesh, visor, label)
│   └── enemy.gd        # Enemy FSM, range rings, state visuals, attack effects
│
├── project.godot       # Configured with main_scene set to main.tscn
├── icon.svg
├── .gitignore
├── .gitattributes
└── README.md
```

---

## How to Run

1. Open **Godot 4.7.2** (standard version).
2. Click **Import** and select `project.godot` inside `EnemyAI_StateMachine`.
3. Press **F5** (or the Play button in the top-right) to launch the game directly.

---

## Controls

| Key | Action |
|---|---|
| **W, A, S, D** or **Arrow Keys** | Move player |

---

## Configuration (Inspector)

These variables are exported on the `Enemy` node and can be tweaked in the Inspector without editing code:

| Group | Variable | Default | Description |
|---|---|---|---|
| Movement | `gravity` | `20.0` | Downward acceleration |
| Movement | `patrol_speed` | `2.0` | Movement speed while patrolling |
| Movement | `chase_speed` | `4.0` | Movement speed while chasing |
| Patrol | `patrol_distance` | `4.0` | Distance of patrol points along X relative to start |
| Patrol | `arrive_threshold` | `0.2` | Distance threshold considered "arrived" |
| Detection & Attack | `detection_range` | `10.0` | Distance to detect and chase player |
| Detection & Attack | `attack_range` | `2.0` | Distance to engage in attack |
| Detection & Attack | `attack_cooldown` | `1.0` | Seconds between attacks |
| Detection & Attack | `hysteresis` | `1.0` | Buffer margin before leaving state |

---

## Testing the Behaviour

Run `main.tscn` with the Output panel open:

1. **Patrol**: The enemy walks between waypoints; mesh and label are **Green**.
2. **Detection**: Walk inside the amber floor ring (\(\le 10\text{m}\)). The enemy turns **Orange** and chases you:
   ```text
   Enemy: PATROL -> CHASE
   ```
3. **Attack**: Step inside the red floor ring (\(\le 2\text{m}\)). The enemy turns **Red**, executes an attack lunge, spawns a shockwave ring, deals damage to the player HP, and prints:
   ```text
   Enemy: CHASE -> ATTACK
   Enemy: ATTACK! (distance = 1.95)
   ```
4. **Disengage**: Walk away beyond the attack range (+ hysteresis). Enemy returns to chase, and beyond detection range (+ hysteresis) returns to patrol:
   ```text
   Enemy: ATTACK -> CHASE
   Enemy: CHASE -> PATROL
   ```

---

## Technologies Used

- **Godot Engine 4.7.2** (Forward+ / Jolt Physics)
- **GDScript**
- 3D Physics & Collision (`CharacterBody3D`, `StaticBody3D`, `BoxShape3D`, `CapsuleShape3D`)
- Finite State Machine (FSM)
- Procedural Meshes (`TorusMesh`, `StandardMaterial3D`)

---

## Author

**Onkar R. Jadhav**  
GitHub: [@OnkarRJ7](https://github.com/OnkarRJ7)
