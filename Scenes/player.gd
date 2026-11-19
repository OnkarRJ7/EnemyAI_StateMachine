extends CharacterBody3D

@export var speed: float = 6.0
@export var gravity: float = 20.0


func _ready() -> void:
	# The enemy finds the player through this group, so it is set in code
	# as well. That way it works even if the editor step was missed.
	add_to_group("player")


func _physics_process(delta: float) -> void:
	# Returns a Vector2 with each axis in [-1, 1], already normalized
	# for diagonal movement.
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Map 2D input onto the ground plane: input Y becomes world Z.
	# "Up" is -Z, which points away from the camera, so it moves up the screen.
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.y * speed

	# Gravity: accumulate downward speed in the air, reset it on the floor.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()
