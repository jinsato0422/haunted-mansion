extends Node3D

@export var monster_scene: PackedScene
# How much each pickup adds to the bar. Tweak these in the Inspector.
@export_category("Treasure Load")
@export_range(0.0, 100.0, 1.0) var minor_treasure_load: float = 5.0
@export_range(0.0, 100.0, 1.0) var great_treasure_load: float = 15.0
@export_range(0.0, 100.0, 1.0) var cursed_treasure_load: float = 25.0

var score: int = 0
var load_tween: Tween

@onready var player: SidePlayer = $Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var speed_label: Label = $HUD/SpeedLabel
@onready var load_bar: ProgressBar = $HUD/LoadPanel/Rows/LoadBar
@onready var ghost_spawn: Marker3D = $GhostSpawn

func _ready() -> void:
	register_treasures(self)
	# Whenever the player gains or loses load, refresh the bar.
	player.load_changed.connect(update_hud)
	load_bar.max_value = player.carry_capacity
	load_bar.value = player.carried_load
	update_hud()

func register_treasures(node: Node) -> void:
	# Hook up the treasures placed in the level, including ones inside other nodes.
	for child in node.get_children():
		if child is Treasure:
			if not child.collected.is_connected(_on_treasure_collected):
				child.collected.connect(_on_treasure_collected)
		register_treasures(child)

func update_hud() -> void:
	score_label.text = "Score: " + str(score)
	speed_label.text = "Speed: %.2f" % player.get_run_speed()
	load_bar.max_value = player.carry_capacity
	# Another pickup came in? Start from wherever the bar is right now.
	if load_tween:
		load_tween.kill()
	# Let the fill slide over instead of jumping straight to the new amount.
	load_tween = create_tween()
	load_tween.tween_property(load_bar, "value", player.carried_load, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_treasure_collected(treasure_type: int) -> void:
	# Pick the weight based on what we just grabbed.
	var pickup_load: float = 0.0
	match treasure_type:
		Treasure.TreasureType.MINOR:
			score += 1
			pickup_load = minor_treasure_load
		Treasure.TreasureType.GREAT:
			score += 3
			pickup_load = great_treasure_load
		Treasure.TreasureType.CURSED:
			score += 10
			pickup_load = cursed_treasure_load
			spawn_ghost()
	# The player handles the weight and tells the bar to update.
	player.add_load(pickup_load)

func spawn_ghost() -> void:
	if monster_scene == null:
		push_warning("Assign ghost.tscn to Monster Scene on MainSide.")
		return
	var ghost := monster_scene.instantiate() as Ghost
	add_child(ghost)
	ghost.global_position = ghost_spawn.global_position
	ghost.target = player
