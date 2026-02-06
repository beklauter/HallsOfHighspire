extends Control


func _on_button_start_pressed() -> void:
	print("Start Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/GameUI.tscn")


func _on_button_options_pressed() -> void:
	print("Options Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/OptionsMenu.tscn")


func _on_button_exit_pressed() -> void:
	print("Exit Button pressed")
	get_tree().quit()
