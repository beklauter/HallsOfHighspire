extends Control

@onready var music_slider := $Panel/Control/VBoxContainer/MusicVolumeSlider
@onready var sfx_slider := $Panel/Control/VBoxContainer/SFXVolumeSlider


func _ready():
	music_slider.value = AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("Music")
	)
	sfx_slider.value = AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("SFX")
	)

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

func _on_music_changed(value: float):
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		value
	)

func _on_sfx_changed(value: float):
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		value
	)

func mute_music(mute: bool):
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index("Music"),
		mute
	)

func _on_button_back_pressed() -> void:
	print("Back Button pressed")
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_button_save_pressed() -> void:
	print("Save Button pressed")
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.save("user://settings.cfg")
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
