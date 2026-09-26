extends Node

# Handles wall grabbing, wall sliding, and jumping off walls.
# Needs the player to have two RayCast3D nodes, "WallLeft" and "WallRight",
# so we can tell if there's a wall on either side.

@export var slide_speed = 2.5
@export var jump_away_speed = 9.0
@export var jump_up_speed = 11.0
@export var jump_control_lock_time = 0.20

var is_grabbing = false
var is_sliding = false
var lock_time_left = 0.0
var locked_speed = 0.0


func reset():
	is_grabbing = false
	is_sliding = false
	lock_time_left = 0.0
	locked_speed = 0.0


# Runs every physics frame from the player script.
# Returns true if we took over the player's movement this frame.
func apply_motion(player, input_direction, delta):
	is_grabbing = false
	is_sliding = false

	# Right after jumping off a wall, lock in that speed for a moment
	# so the player can't immediately cancel the jump.
	if lock_time_left > 0.0:
		lock_time_left = lock_time_left - delta
		if lock_time_left < 0.0:
			lock_time_left = 0.0
		player.velocity.x = locked_speed
		return true

	# Can't grab or slide on a wall if we're standing on the ground.
	if player.is_on_floor():
		return false

	var left_ray = player.get_node("WallLeft")
	var right_ray = player.get_node("WallRight")
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()

	# Check whichever side we're pressing toward first - if both rays
	# happen to be touching a wall, we want the one that actually matters.
	var first_ray = left_ray
	var second_ray = right_ray
	if input_direction < 0.0:
		first_ray = right_ray
		second_ray = left_ray

	var wall_normal = Vector3.ZERO
	if first_ray.is_colliding():
		var normal = first_ray.get_collision_normal()
		if abs(normal.x) > 0.85 and abs(normal.y) < 0.3:
			wall_normal = normal
	if second_ray.is_colliding():
		var normal = second_ray.get_collision_normal()
		if abs(normal.x) > 0.85 and abs(normal.y) < 0.3:
			wall_normal = normal

	if wall_normal == Vector3.ZERO:
		return false

	# Jump off the wall, away from it.
	if Input.is_action_just_pressed("jump"):
		var away_direction = 1.0
		if wall_normal.x < 0.0:
			away_direction = -1.0

		locked_speed = away_direction * jump_away_speed
		player.velocity.x = locked_speed
		player.velocity.y = jump_up_speed
		lock_time_left = jump_control_lock_time
		player.set("facing_direction", away_direction)
		return true

	# Otherwise either grab on and hang still, or slide down slowly.
	if Input.is_action_pressed("grab"):
		is_grabbing = true
		player.velocity.y = 0.0
	elif input_direction * wall_normal.x < 0.0 and player.velocity.y <= 0.0:
		is_sliding = true
		if player.velocity.y < -slide_speed:
			player.velocity.y = -slide_speed
	else:
		return false

	# Give a tiny push into the wall so we don't slowly drift off it.
	var push_direction = 1.0
	if wall_normal.x > 0.0:
		push_direction = -1.0
	player.velocity.x = push_direction * 0.5

	return true
