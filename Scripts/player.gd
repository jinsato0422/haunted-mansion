class_name SidePlayer
extends CharacterBody3D


signal died

# MOVEMENT SETTINGS

@export_category("Ground Movement")

@export var walk_speed := 6.0
@export var run_speed_base := 10.0
@export var ground_deceleration := 25.0

@export_category("Air Movement")

@export var small_air_acceleration := 20.0
@export var large_air_acceleration := 35.0

@export var normal_max_air_speed := 6.0
@export var max_air_speed := 10.0

@export var air_deceleration := 15.0

@export var gravity_amount := 28.0
@export var max_fall_speed := 25.0


@export_category("Jump")

@export var jump_speed := 10.0
@export var jump_cut_multiplier := 0.45
@export var max_jump_hold := 0.25


@export_category("Wall Jump")

@export var wall_jump_horizontal_speed := 10.0
@export var wall_jump_control_lock := 0.15
@export var wall_slide_fall_speed := 4.0


@export_category("Slide")

@export var slide_friction := 8.0
@export var minimum_slide_speed := 2.0


# TREASURE / GAMEPLAY MODIFIERS

@export_category("Treasure")

@export var treasure_count := 0
@export var slowdown_per_treasure := 0.10
@export var minimum_speed_multiplier := 0.40

@export var movement_multiplier := 1.0
@export var dash_multiplier := 1.0


@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D

@onready var interaction_range: Area3D = $InteractionRange

@onready var upper_right: RayCast3D = $WallCasts/UpperRight
@onready var lower_right: RayCast3D = $WallCasts/LowerRight
@onready var upper_left: RayCast3D = $WallCasts/UpperLeft
@onready var lower_left: RayCast3D = $WallCasts/LowerLeft


# STATE

enum STATE {
	IDLE,
	WALK,
	RUN,
	JUMP,
	SLIDE
}

var move_state := STATE.IDLE

var direction := 0.0
var facing_direction := 1.0

var frame := 0

# JUMP / WALL STATE
var jump_timer := 0.0
var is_wall_sliding := false

# Direction the wall jump should push us.
# -1 = left
#  1 = right
var wall_jump_direction := 0

var wall_jump_lock_timer := 0.0

var is_dead := false

var fixed_z_position := 0.0
var start_position := Vector3.ZERO

var run_speed := 0.0



func _ready() -> void:
	fixed_z_position = global_position.z
	start_position = global_position

	floor_snap_length = 0.35
	floor_constant_speed = true

	change_state(STATE.IDLE)


# PHYSICS

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	frame += 1

	direction = Input.get_axis("move_left", "move_right")

	if direction != 0.0:
		facing_direction = direction

	apply_gravity(delta)

	handle_state(delta)

	# This is what makes the 3D CharacterBody behave like
	# a 2D side-scroller.
	velocity.z = 0.0

	move_and_slide()

	# Never allow collisions or physics to gradually move us
	# into/out of the screen.
	global_position.z = fixed_z_position

	# Death plane.
	if global_position.y < -15.0:
		die()

	if Input.is_action_just_pressed("interact"):
		interact_with_nearest()
		
	check_if_out_of_bounds()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_amount * delta

		if velocity.y < -max_fall_speed:
			velocity.y = -max_fall_speed

	elif velocity.y < 0.0:
		velocity.y = 0.0

func check_if_out_of_bounds():
	if abs(position.y) >= 300.0 or abs(position.x) >= 300.0:
		reset_player()

# STATE MACHINE

func handle_state(delta: float) -> void:
	match move_state:

		STATE.IDLE:
			idle_state()

		STATE.WALK:
			walk_state()

		STATE.RUN:
			run_state()

		STATE.JUMP:
			jump_state(delta)

		STATE.SLIDE:
			slide_state(delta)


# IDLE

func idle_state() -> void:
	if check_jump():
		return

	if not is_on_floor():
		change_state(STATE.JUMP)
		return

	if direction != 0.0:

		if Input.is_action_pressed("run"):
			change_state(STATE.RUN)
		else:
			change_state(STATE.WALK)


# WALK

func walk_state() -> void:
	if check_jump():
		return

	if not is_on_floor():
		change_state(STATE.JUMP)
		return

	move_horizontal(get_walk_speed())

	if Input.is_action_pressed("run"):
		change_state(STATE.RUN)
		return

	if Input.is_action_just_pressed("down"):
		change_state(STATE.SLIDE)
		return


# ============================================================
# RUN
# ============================================================

func run_state() -> void:
	if check_jump():
		return

	if not is_on_floor():
		change_state(STATE.JUMP)
		return

	move_horizontal(get_run_speed())

	if not Input.is_action_pressed("run"):
		change_state(STATE.WALK)
		return

	if Input.is_action_just_pressed("down"):
		change_state(STATE.SLIDE)
		return


# ============================================================
# JUMP / AIR
# ============================================================

func jump_state(delta: float) -> void:
	print("JUMP STATE | grab: ", Input.is_action_pressed("grab"),
		" | UR: ", upper_right.is_colliding(),
		" | LR: ", lower_right.is_colliding(),
		" | UL: ", upper_left.is_colliding(),
		" | LL: ", lower_left.is_colliding())
	if Input.is_action_pressed("grab"):
		print("Player: ", global_position)
		print("UpperRight starts: ", upper_right.global_position)
		print("UpperRight ends: ", upper_right.to_global(upper_right.target_position))
		print("UpperRight mask: ", upper_right.collision_mask)
	is_wall_sliding = check_wall_slide()
	var is_wall_grabbing := is_wall_sliding and Input.is_action_pressed("grab")
	

	if is_wall_sliding:
		if is_wall_grabbing:
			velocity.x = 0.0
			velocity.y = 0.0
		elif velocity.y < -wall_slide_fall_speed:
			velocity.y = -wall_slide_fall_speed

		if Input.is_action_just_pressed("jump"):
			perform_wall_jump()
			is_wall_grabbing = false
	else:
		if velocity.y < 0:
			animated_sprite.play("falling")
		else:
			animated_sprite.play("rising")

	# Variable-height jump.
	jump_timer -= delta

	if Input.is_action_pressed("jump") and jump_timer > 0.0:
		if velocity.y > 0.0:
			velocity.y = jump_speed

	if Input.is_action_just_released("jump"):
		jump_timer = 0.0

		if velocity.y > 0.0:
			velocity.y *= jump_cut_multiplier

	if not is_wall_grabbing:
		move_air(delta)

	if is_on_floor():
		change_state(STATE.IDLE)


# ============================================================
# SLIDE
# ============================================================

func slide_state(delta):
	if not is_on_floor():
		change_state(STATE.JUMP)
		return
		
	''' THIS STUFF IS FOR SLDING DOWN SLOPES WILL IMPLEMENT LATER '''
		
	'if frame >= 28:
		if check_jump():
			return'
		
	#var floor_normal := get_floor_normal()
	#var downhill := get_slope_down_direction()
	#var gravity := get_gravity()


	#var slope_acceleration := gravity.dot(downhill)
	#var slope_direction = -1.0 if downhill.x < 0 else 1.0
	#animated_sprite.rotation = get_floor_angle() * slope_direction
	#velocity.x += slope_acceleration * delta * slope_direction * 0.5
	
	'if floor_normal == Vector2(0.0, -1.0) and frame >= 28:
		if velocity.x < 0.0:
			velocity.x += 500.0 * delta
		else:
			velocity.x -= 500.0 * delta'
			
	if frame >= 28:
		change_state(STATE.IDLE)
		return


func check_jump() -> bool:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed

		jump_timer = max_jump_hold

		change_state(STATE.JUMP)

		return true

	return false


# GROUND MOVEMENT

func move_horizontal(speed: float) -> void:
	if direction != 0.0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			ground_deceleration
		)

	if direction == 0.0 and is_on_floor():
		change_state(STATE.IDLE)

	update_facing()


# AIR MOVEMENT

func move_air(delta: float) -> void:
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta

		if wall_jump_lock_timer < 0.0:
			wall_jump_lock_timer = 0.0

	if direction != 0.0 and wall_jump_lock_timer <= 0.0:

		var acceleration: float
		var top_speed: float

		if Input.is_action_pressed("run"):
			acceleration = large_air_acceleration
			top_speed = max_air_speed
		else:
			acceleration = small_air_acceleration
			top_speed = normal_max_air_speed

		top_speed *= get_speed_multiplier()

		velocity.x += direction * acceleration * delta

		velocity.x = clamp(
			velocity.x,
			-top_speed,
			top_speed
		)

	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			air_deceleration * delta
		)
	update_facing()


# WALL SLIDE

func check_wall_slide() -> bool:
	wall_jump_direction = 0
	if upper_right.is_colliding():
		print("UR hit: ", upper_right.get_collider())

	if lower_right.is_colliding():
		print("LR hit: ", lower_right.get_collider())

	if upper_left.is_colliding():
		print("UL hit: ", upper_left.get_collider())

	if lower_left.is_colliding():
		print("LL hit: ", lower_left.get_collider())

	# Right wall -> jump left.
	if upper_right.is_colliding() or lower_right.is_colliding():
		print("yayah")
		wall_jump_direction = -1
		return true

	# Left wall -> jump right.
	if upper_left.is_colliding() or lower_left.is_colliding():
		print("yayah")
		wall_jump_direction = 1
		return true

	return false


func perform_wall_jump() -> void:
	velocity.y = jump_speed

	velocity.x = (
		wall_jump_horizontal_speed
		* wall_jump_direction
	)

	jump_timer = max_jump_hold / 2.0

	wall_jump_lock_timer = wall_jump_control_lock

	is_wall_sliding = false


# FACING

func update_facing() -> void:
	if velocity.x < 0.0:
		facing_direction = -1.0
		animated_sprite.flip_h = true

	elif velocity.x > 0.0:
		facing_direction = 1.0
		animated_sprite.flip_h = false


# STATE CHANGES

func change_state(new_state: STATE) -> void:
	if move_state == new_state:
		return

	exit_state(move_state)

	move_state = new_state
	frame = 0

	match move_state:

		STATE.IDLE:
			velocity.x = 0
			animated_sprite.play("idle")

		STATE.WALK:
			animated_sprite.play("walk")

		STATE.RUN:
			animated_sprite.play("run")

		STATE.JUMP:
			animated_sprite.play("jump")

		STATE.SLIDE:
			animated_sprite.play("slide")


func exit_state(old_state: STATE) -> void:
	match old_state:

		STATE.JUMP:
			jump_timer = 0.0
			is_wall_sliding = false

		STATE.SLIDE:
			# If you rotate the sprite during sliding,
			# reset it here.
			animated_sprite.rotation.z = 0.0
			velocity.x = 0


# TREASURE SPEED

func get_speed_multiplier() -> float:
	var load_factor: float = (
		1.0
		- treasure_count * slowdown_per_treasure
	)

	load_factor = maxf(
		load_factor,
		minimum_speed_multiplier
	)

	var multiplier: float = maxf(
		movement_multiplier,
		0.1
	)

	return multiplier * load_factor


func get_walk_speed() -> float:
	return walk_speed * get_speed_multiplier()


func get_run_speed() -> float:
	var speed := (
		run_speed_base
		* get_speed_multiplier()
		* dash_multiplier
	)

	# Keep this because main_side.gd reads it.
	run_speed = speed
	return speed


func update_treasure_speed(great_treasure_amount, movement_limiter) -> void:

	treasure_count = great_treasure_amount
	slowdown_per_treasure = movement_limiter


# ============================================================
# INTERACTION
# ============================================================

func interact_with_nearest() -> void:
	var nearest_area = null
	var nearest_distance := INF

	for area in interaction_range.get_overlapping_areas():
		if area.has_method("interact"):
			var distance := (
				global_position.distance_squared_to(
					area.global_position
				)
			)

			if distance < nearest_distance:
				nearest_area = area
				nearest_distance = distance

	if nearest_area != null:
		nearest_area.call("interact", self)


# TELEPORT/RESET/DEATH

func teleport_to(destination: Vector3) -> void:
	global_position = destination
	fixed_z_position = destination.z
	velocity = Vector3.ZERO


func reset_player() -> void:
	is_dead = false
	treasure_count = 0
	movement_multiplier = 1.0
	dash_multiplier = 1.0
	velocity = Vector3.ZERO
	teleport_to(start_position)
	change_state(STATE.IDLE)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO

	died.emit()
