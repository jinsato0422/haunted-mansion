extends CharacterBody3D

# Handles all the basic player stuff - walking, jumping, dashing,
# and interacting with things like doors or treasure.

signal died

# Feel free to tweak these in the Inspector to change how the player feels.
@export var walk_speed = 6.0
@export var dash_speed = 18.0
@export var speed_up_rate = 35.0
@export var dash_speed_up_rate = 12.0
@export var slow_down_rate = 55.0
@export var jump_speed = 10.0
@export var gravity_amount = 28.0
@export var movement_multiplier = 1.0
@export var dash_multiplier = 1.0

# The more big treasure you're carrying, the slower you move.
@export var treasure_count = 0
@export var slowdown_per_treasure = 0.10
@export var minimum_speed_multiplier = 0.40

# The nodes we need to grab a reference to.
@onready var visual = $Visual
@onready var interaction_range = $InteractionRange
@onready var wall_movement = $WallMovement

# Stuff that changes as the game runs.
var facing_direction = 1.0
var is_dashing = false
var is_dead = false
var fixed_z_position = 0.0
var start_position = Vector3.ZERO


func _ready():
	# Save our starting spot so we can respawn here later and
	# stay locked to this z-position (we only move left/right).
	fixed_z_position = global_position.z
	start_position = global_position
	floor_snap_length = 0.35
	floor_constant_speed = true


func _physics_process(delta):
	if is_dead:
		return

	# Which way is the player pressing?
	var input_direction = Input.get_axis("move_left", "move_right")
	if input_direction != 0:
		if input_direction > 0:
			facing_direction = 1.0
		else:
			facing_direction = -1.0

	# Pull the player down when they're in the air.
	if not is_on_floor():
		velocity.y = velocity.y - gravity_amount * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	# Jump, but only if we're actually standing on something.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed

	# Work out our max speed right now (treasure weighs us down a bit).
	var load_factor = 1.0 - treasure_count * slowdown_per_treasure
	if load_factor < minimum_speed_multiplier:
		load_factor = minimum_speed_multiplier

	var speed_multiplier = movement_multiplier
	if speed_multiplier < 0.1:
		speed_multiplier = 0.1
	var speed_factor = speed_multiplier * load_factor

	var normal_top_speed = walk_speed * speed_factor
	var dash_top_speed = dash_speed * speed_factor * dash_multiplier
	if dash_top_speed < normal_top_speed:
		dash_top_speed = normal_top_speed

	# Figure out the speed we're aiming for and how fast to get there.
	var target_speed = input_direction * normal_top_speed
	var change_rate = speed_up_rate

	is_dashing = Input.is_action_pressed("dash")
	if is_dashing:
		target_speed = facing_direction * dash_top_speed
		if velocity.x * facing_direction < 0.0:
			# We're dashing but facing the opposite way we're moving,
			# so brake hard first instead of just speeding up.
			change_rate = slow_down_rate
		else:
			change_rate = dash_speed_up_rate
	elif input_direction == 0 or abs(velocity.x) > normal_top_speed:
		change_rate = slow_down_rate

	# Nudge velocity.x toward target_speed, being careful not to overshoot.
	var speed_step = change_rate * delta
	if velocity.x < target_speed:
		velocity.x = velocity.x + speed_step
		if velocity.x > target_speed:
			velocity.x = target_speed
	elif velocity.x > target_speed:
		velocity.x = velocity.x - speed_step
		if velocity.x < target_speed:
			velocity.x = target_speed

	# If we're on a wall, let that script take full control of our movement -
	# it overrides whatever dashing or walking we just calculated above.
	var on_wall = wall_movement.apply_motion(self, input_direction, delta)
	if on_wall:
		is_dashing = false

	# Wrap up the frame.
	visual.rotation.y = -facing_direction * PI / 2.0
	velocity.z = 0.0
	move_and_slide()
	global_position.z = fixed_z_position

	if global_position.y < -15.0:
		die()
	elif Input.is_action_just_pressed("interact"):
		interact_with_nearest()


func interact_with_nearest():
	# Look at everything in range and pick whichever interactable thing
	# is closest to us.
	var nearest_area = null
	var nearest_distance = INF

	for area in interaction_range.get_overlapping_areas():
		if area.has_method("interact"):
			var distance = global_position.distance_squared_to(area.global_position)
			if distance < nearest_distance:
				nearest_area = area
				nearest_distance = distance

	if nearest_area != null:
		nearest_area.call("interact", self)


func teleport_to(destination):
	global_position = destination
	fixed_z_position = destination.z
	velocity = Vector3.ZERO
	wall_movement.reset()


func reset_player():
	is_dead = false
	treasure_count = 0
	movement_multiplier = 1.0
	dash_multiplier = 1.0
	is_dashing = false
	teleport_to(start_position)


func die():
	if is_dead:
		return
	is_dead = true
	is_dashing = false
	velocity = Vector3.ZERO
	wall_movement.reset()
	died.emit()
