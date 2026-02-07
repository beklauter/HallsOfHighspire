extends Control
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var v_box_container: VBoxContainer = $VBoxContainer


func _on_button_start_pressed() -> void:
	print("Start Button pressed")
	v_box_container.visible = false
	animation_player.play("fade_start_2s")
	animation_player.animation_finished.connect(_startGame)


func _on_button_options_pressed() -> void:
	print("Options Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/OptionsMenu.tscn")


func _on_button_exit_pressed() -> void:
	print("Exit Button pressed")
	get_tree().quit()

func _startGame(anim_name: String) -> void:
	if anim_name == "fade_start_2s":
		get_tree().change_scene_to_file("res://scenes/levels/debug/TestScene.tscn")

func _on_button_credits_pressed() -> void:
	print("Credits Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/CreditsMenu.tscn")
