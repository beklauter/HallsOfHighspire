extends Control


func _on_button_back_pressed() -> void:
	print("Back Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
