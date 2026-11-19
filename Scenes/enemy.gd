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
@export var hysteresis: float = 1.0

@onready var state_label: Label3D = $Label3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var state: State = State.PATROL
var player: Node3D = null

var home_position: Vector3
var patrol_points: Array[Vector3] = []
var patrol_index: int = 0

var attack_timer: float = 0.0
var enemy_material: StandardMaterial3D = null

# Visual range rings
var detection_ring: MeshInstance3D = null
var attack_ring: MeshInstance3D = null


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("Enemy: no node in group 'player' was found.")
	if attack_range >= detection_range:
		push_warning("Enemy: attack_range should be smaller than detection_range.")

	home_position = global_position
	patrol_points = [
		home_position + Vector3(patrol_distance, 0.0, 0.0),
		home_position - Vector3(patrol_distance, 0.0, 0.0),
	]

	_setup_materials()
	_create_range_rings()
	_apply_state_visuals()


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


func change_state(new_state: State) -> void:
	if new_state == state:
		return
	print("Enemy: %s -> %s" % [State.keys()[state], State.keys()[new_state]])
	state = new_state
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_state_visuals()


# ---------- States ----------

func patrol_state(delta: float) -> void:
	if _distance_to_player() <= detection_range:
		change_state(State.CHASE)
		return

	var target: Vector3 = patrol_points[patrol_index]
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0

	if to_target.length() <= arrive_threshold:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		velocity.x = 0.0
		velocity.z = 0.0
		return

	_move_along(to_target, patrol_speed)

	# Face movement direction smoothly
	if velocity.length_squared() > 0.05:
		var target_rot_y: float = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 10.0 * delta)


func chase_state(delta: float) -> void:
	if not is_instance_valid(player):
		change_state(State.PATROL)
		return

	var distance: float = _distance_to_player()

	if distance > detection_range + hysteresis:
		change_state(State.PATROL)
		return

	if distance <= attack_range:
		change_state(State.ATTACK)
		return

	var to_player: Vector3 = _flat_vector_to_player()
	_move_along(to_player, chase_speed)

	# Smoothly face the player while chasing
	if to_player.length_squared() > 0.05:
		var target_rot_y: float = atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 14.0 * delta)


func attack_state(delta: float) -> void:
	if not is_instance_valid(player):
		change_state(State.PATROL)
		return

	velocity.x = 0.0
	velocity.z = 0.0

	var to_player: Vector3 = _flat_vector_to_player()
	if to_player.length_squared() > 0.05:
		var target_rot_y: float = atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 15.0 * delta)

	var distance: float = _distance_to_player()

	if distance > attack_range + hysteresis:
		change_state(State.CHASE)
		return

	if attack_timer <= 0.0:
		_perform_attack(distance)
		attack_timer = attack_cooldown


# ---------- Helpers & Visuals ----------

func _perform_attack(distance: float) -> void:
	print("Enemy: ATTACK! (distance = %.2f)" % distance)

	# 1. Squash & stretch attack lunge
	if mesh_instance:
		var lunge_tween: Tween = create_tween()
		lunge_tween.tween_property(mesh_instance, "scale", Vector3(1.3, 0.7, 1.3), 0.08)
		lunge_tween.tween_property(mesh_instance, "scale", Vector3(0.85, 1.25, 0.85), 0.12)
		lunge_tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.1)

	# 2. Expanding shockwave ring effect
	_spawn_attack_pulse()

	# 3. Deal damage to player
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(15)


func _spawn_attack_pulse() -> void:
	var pulse: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.4
	pulse.mesh = torus
	pulse.position = Vector3(0.0, -0.9, 0.0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.8)
	pulse.material_override = mat

	add_child(pulse)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3(attack_range * 2.5, 1.0, attack_range * 2.5), 0.28)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.chain().tween_callback(pulse.queue_free)


func _setup_materials() -> void:
	if mesh_instance:
		var existing_mat: Material = mesh_instance.get_active_material(0)
		if existing_mat is StandardMaterial3D:
			enemy_material = existing_mat.duplicate() as StandardMaterial3D
		else:
			enemy_material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, enemy_material)


func _create_range_rings() -> void:
	# Detection range ring (outer amber circle on floor)
	detection_ring = MeshInstance3D.new()
	var det_mesh: TorusMesh = TorusMesh.new()
	det_mesh.inner_radius = detection_range - 0.08
	det_mesh.outer_radius = detection_range + 0.08
	detection_ring.mesh = det_mesh
	detection_ring.position = Vector3(0.0, -0.98, 0.0)

	var det_mat: StandardMaterial3D = StandardMaterial3D.new()
	det_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	det_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	det_mat.albedo_color = Color(1.0, 0.75, 0.15, 0.28)
	detection_ring.material_override = det_mat
	add_child(detection_ring)

	# Attack range ring (inner red circle on floor)
	attack_ring = MeshInstance3D.new()
	var atk_mesh: TorusMesh = TorusMesh.new()
	atk_mesh.inner_radius = attack_range - 0.08
	atk_mesh.outer_radius = attack_range + 0.08
	attack_ring.mesh = atk_mesh
	attack_ring.position = Vector3(0.0, -0.96, 0.0)

	var atk_mat: StandardMaterial3D = StandardMaterial3D.new()
	atk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atk_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.45)
	attack_ring.material_override = atk_mat
	add_child(attack_ring)


func _apply_state_visuals() -> void:
	if state_label == null:
		return

	state_label.text = "[ %s ]" % State.keys()[state]

	match state:
		State.PATROL:
			state_label.modulate = Color(0.35, 1.0, 0.45)
			if enemy_material:
				enemy_material.albedo_color = Color(0.2, 0.75, 0.35)
				enemy_material.emission_enabled = true
				enemy_material.emission = Color(0.1, 0.45, 0.18)
				enemy_material.emission_energy_multiplier = 0.8
		State.CHASE:
			state_label.modulate = Color(1.0, 0.7, 0.15)
			if enemy_material:
				enemy_material.albedo_color = Color(1.0, 0.55, 0.08)
				enemy_material.emission_enabled = true
				enemy_material.emission = Color(0.9, 0.4, 0.02)
				enemy_material.emission_energy_multiplier = 1.2
		State.ATTACK:
			state_label.modulate = Color(1.0, 0.25, 0.25)
			if enemy_material:
				enemy_material.albedo_color = Color(0.95, 0.15, 0.15)
				enemy_material.emission_enabled = true
				enemy_material.emission = Color(0.85, 0.08, 0.08)
				enemy_material.emission_energy_multiplier = 1.8


func _flat_vector_to_player() -> Vector3:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	return to_player


func _distance_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	return _flat_vector_to_player().length()


func _move_along(to_target: Vector3, speed: float) -> void:
	var direction: Vector3 = to_target.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
