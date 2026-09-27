class_name Treasure
extends Area3D

enum TreasureType { MINOR, GREAT, CURSED }

signal collected(treasure_type: TreasureType)

@export var treasure_type: TreasureType = TreasureType.MINOR


func _on_body_entered(body: Node3D) -> void:
	if body is SidePlayer:
		monitoring = false # If this script is on the Area3D
		$MoneyBagModel.hide()
		collected.emit(treasure_type)

		$CPUParticles3D.restart()
		$CPUParticles3D.emitting = true
		await $CPUParticles3D.finished
		queue_free()
