class_name SidePlayer
extends CharacterBody3D

@export var base_speed: float = 5.0
@export var jump_speed: float = 8.0
@export var gravity: float = 20.0

var run_speed: float

func _ready() -> void:
	run_speed = base_speed

func update_treasure_speed(great_treasure_amount: int, movement_limiter: float) -> void:
	run_speed = base_speed / (1.0 + great_treasure_amount * movement_limiter)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed

	var horizontal_input := Input.get_axis("move_left", "move_right")
	velocity.x = horizontal_input * run_speed

	# Keep gameplay on a single 2D plane.
	velocity.z = 0.0
	move_and_slide()
