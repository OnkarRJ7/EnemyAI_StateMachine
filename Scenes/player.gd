extends CharacterBody3D

@export var speed: float = 6.0
@export var gravity: float = 20.0
@export var max_health: int = 100

var current_health: int = 100

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hp_label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	_update_hp_display()


func _physics_process(delta: float) -> void:
	# Support both Godot UI arrow keys and standard WASD
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir == Vector2.ZERO:
		var x: float = 0.0
		var y: float = 0.0
		if Input.is_physical_key_pressed(KEY_A): x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): x += 1.0
		if Input.is_physical_key_pressed(KEY_W): y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): y += 1.0
		input_dir = Vector2(x, y).normalized()

	# Map 2D input onto the ground plane: input Y becomes world Z
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.y * speed

	# Face movement direction smoothly
	if input_dir.length_squared() > 0.01:
		var target_rotation_y: float = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 14.0 * delta)

	# Gravity
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()


func take_damage(amount: int) -> void:
	current_health = maxi(0, current_health - amount)
	_update_hp_display()

	# Visual hit reaction: brief red flash and subtle scale bump
	var mat: StandardMaterial3D = mesh_instance.get_active_material(0) as StandardMaterial3D
	if mat:
		var original_color: Color = Color(0.18, 0.55, 0.95, 1.0)
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(mat, "albedo_color", Color(1.0, 0.2, 0.2, 1.0), 0.06)
		flash_tween.tween_property(mat, "albedo_color", original_color, 0.16)

	var bump_tween: Tween = create_tween()
	bump_tween.tween_property(mesh_instance, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	bump_tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.14)


func _update_hp_display() -> void:
	if hp_label:
		hp_label.text = "PLAYER (HP: %d)" % current_health
		if current_health <= 25:
			hp_label.modulate = Color(1.0, 0.2, 0.2)
		elif current_health <= 60:
			hp_label.modulate = Color(1.0, 0.85, 0.2)
		else:
			hp_label.modulate = Color(1.0, 1.0, 1.0)
