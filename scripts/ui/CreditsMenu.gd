extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("start_credits")


func _on_button_back_pressed() -> void:
	print("Back Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
