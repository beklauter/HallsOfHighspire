extends Control
@onready var panel: Panel = $Panel
@onready var enemy_name: Label = $EnemyName
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var life_bar: Control = $"."
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemy_name.text = get_parent().name
	progress_bar.max_value = get_parent().max_hp


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	progress_bar.value = get_parent().hp
	
	
	if get_parent().hp == get_parent().max_hp:
		progress_bar.modulate = Color.GREEN
	if get_parent().hp <= get_parent().max_hp * 0.66:
		progress_bar.modulate = Color.YELLOW
	if get_parent().hp <= get_parent().max_hp * 0.33:
		progress_bar.modulate = Color.RED
	if get_parent().hp == 0:
		animation_player.play("fade_out")
