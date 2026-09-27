class_name Ghost
extends Area3D

@export var chase_speed: float = 2.0

var target: SidePlayer

@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D

func _process(delta: float) -> void:
	if target == null:
		return
		
	if target.position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

	global_position.x = move_toward(
		global_position.x,
		target.global_position.x,
		chase_speed * delta
	)

	global_position.y = move_toward(
		global_position.y,
		target.global_position.y,
		chase_speed * delta
	)


func _on_body_entered(body: Node3D) -> void:
	if body is SidePlayer:
		get_tree().call_deferred("reload_current_scene")
