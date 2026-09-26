extends Node3D

@export var movement_limiter: float = 0.2
@export var monster_scene: PackedScene

var score: int = 0
var great_treasure_amount: int = 0

@onready var player: CharacterBody3D = $Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var speed_label: Label = $HUD/SpeedLabel
@onready var ghost_spawn: Marker3D = $GhostSpawn

func _ready() -> void:
	update_hud()

func update_hud() -> void: 
	score_label.text = "Score: " + str(score)
	speed_label.text = "Speed: %.2f" % player.run_speed

func _on_treasure_collected(treasure_type: int) -> void:
	match treasure_type:
		Treasure.TreasureType.MINOR:
			score += 1

		Treasure.TreasureType.GREAT:
			score += 3
			great_treasure_amount += 1
			player.update_treasure_speed(
				great_treasure_amount,
				movement_limiter
			)
		Treasure.TreasureType.CURSED:
			score += 10
			spawn_ghost()
	update_hud()

	score_label.text = "Score: " + str(score)
	print("Great treasures: ", great_treasure_amount, " | Speed: ", player.run_speed)

# Monster Spawn
func spawn_ghost() -> void:
	if monster_scene == null:
		push_warning("Assign ghost.tscn to Monster Scene on MainSide.")
		return

	var ghost := monster_scene.instantiate() as Ghost
	add_child(ghost)
	ghost.global_position = ghost_spawn.global_position
	ghost.target = player
