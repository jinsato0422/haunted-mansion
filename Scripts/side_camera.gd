extends Camera3D

@onready var player: CharacterBody3D = $"../PlayerSide"

#This follows the player in the x-axis position
func _process(delta: float) -> void:
	# The third arguement is the speed in how you want to transition the camera from 0-1
	# The 5.0 is the follow strength: increase it for a tighter camera, or decrease it for more lag.
	position.x = lerpf(position.x, player.position.x, minf(1.0, 5.0 * delta))
	position.y = lerpf(position.y, player.position.y, minf(1.0, 5.0 * delta))
