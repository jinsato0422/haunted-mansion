class_name Treasure
extends Area3D

enum TreasureType { MINOR, GREAT, CURSED }

signal collected(treasure_type: TreasureType)

@export var treasure_type: TreasureType = TreasureType.MINOR

var is_collected := false


func _on_body_entered(body: Node3D) -> void:
	if body is SidePlayer and not is_collected:
		is_collected = true
		set_deferred("monitoring", false)
		
		hide()
		collected.emit(treasure_type)

		$CPUParticles3D.restart()
		$CPUParticles3D.emitting = true
		await $CPUParticles3D.finished
		queue_free()
