class_name Treasure
extends Area3D

enum TreasureType { MINOR, GREAT, CURSED }

signal collected(treasure_type: TreasureType)

@export var treasure_type: TreasureType = TreasureType.MINOR


func _on_body_entered(body: Node3D) -> void:
	if body is SidePlayer:
		collected.emit(treasure_type)
		queue_free()
