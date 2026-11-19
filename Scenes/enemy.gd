extends CharacterBody3D

enum State { PATROL, CHASE, ATTACK }

@export_group("Movement")
@export var gravity: float = 20.0
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 4.0

@export_group("Patrol")
@export var patrol_distance: float = 4.0
@export var arrive_threshold: float = 0.2

@export_group("Detection and Attack")
@export var detection_range: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
# Extra distance the player must travel past a range before the enemy
# gives up on it. Prevents rapid flip-flopping right at the boundary.
@export var hysteresis: float = 1.0

@onready var state_label: Label3D = $Label3D

var state: State = State.PATROL
var player: Node3D = null

var home_position: Vector3
var patrol_points: Array[Vector3] = []
var patrol_index: int = 0

var attack_timer: float = 0.0  # seconds until the next attack is allowed


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("Enemy: no node in group 'player' was found.")
	if attack_range >= detection_range:
		push_warning("Enemy: attack_range should be smaller than detection_range.")

	# Patrol route is defined relative to where the enemy is placed in the scene.
	home_position = global_position
	patrol_points = [
		home_position + Vector3(patrol_distance, 0.0, 0.0),
		home_position - Vector3(patrol_distance, 0.0, 0.0),
	]
	_update_label()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	attack_timer = maxf(attack_timer - delta, 0.0)

	match state:
		State.PATROL:
			patrol_state(delta)
		State.CHASE:
			chase_state(delta)
		State.ATTACK:
			attack_state(delta)

	move_and_slide()


# The only place where the state is changed.
func change_state(new_state: State) -> void:
	if new_state == state:
		return
	print("Enemy: %s -> %s" % [State.keys()[state], State.keys()[new_state]])
	state = new_state
	# Clear horizontal motion so no state inherits the previous state's velocity.
	velocity.x = 0.0
	velocity.z = 0.0
	_update_label()


# ---------- States ----------

func patrol_state(_delta: float) -> void:
	# Transition: player came into detection range -> CHASE.
	if _distance_to_player() <= detection_range:
		change_state(State.CHASE)
		return

	var target: Vector3 = patrol_points[patrol_index]

	# Compare on the ground plane only, so gravity and height never matter.
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0

	if to_target.length() <= arrive_threshold:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		velocity.x = 0.0
		velocity.z = 0.0
		return

	_move_along(to_target, patrol_speed)


func chase_state(_delta: float) -> void:
	# Player missing (null or freed): nothing to chase.
	if not is_instance_valid(player):
		change_state(State.PATROL)
		return

	var distance: float = _distance_to_player()

	# Transition: player escaped -> PATROL (with hysteresis margin).
	if distance > detection_range + hysteresis:
		change_state(State.PATROL)
		return

	# Transition: player is close enough -> ATTACK.
	if distance <= attack_range:
		change_state(State.ATTACK)
		return

	_move_along(_flat_vector_to_player(), chase_speed)


func attack_state(_delta: float) -> void:
	if not is_instance_valid(player):
		change_state(State.PATROL)
		return

	# Stand still while attacking.
	velocity.x = 0.0
	velocity.z = 0.0

	var distance: float = _distance_to_player()

	# Transition: player stepped out of attack range -> CHASE.
	if distance > attack_range + hysteresis:
		change_state(State.CHASE)
		return

	# Attack only when the cooldown has run out.
	if attack_timer <= 0.0:
		_perform_attack(distance)
		attack_timer = attack_cooldown


# ---------- Helpers ----------

func _perform_attack(distance: float) -> void:
	# Placeholder for real damage, e.g. player.take_damage(...).
	print("Enemy: ATTACK! (distance = %.2f)" % distance)


# Vector from the enemy to the player with Y removed (ground plane only).
func _flat_vector_to_player() -> Vector3:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	return to_player


# Horizontal distance to the player. INF if there is no valid player,
# so every "is the player in range?" check simply fails.
func _distance_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	return _flat_vector_to_player().length()


# Sets horizontal velocity toward a direction. Y is left to gravity.
func _move_along(to_target: Vector3, speed: float) -> void:
	var direction: Vector3 = to_target.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta


func _update_label() -> void:
	state_label.text = State.keys()[state]
