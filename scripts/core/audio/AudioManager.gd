extends Node

@onready var music := $MusicPlayer
@onready var sfx := $SFXPlayer

func play_music(stream: AudioStream):
	if music.stream == stream and music.playing:
		return
	music.stream = stream
	music.play()

func stop_music():
	music.stop()

func play_sfx(stream: AudioStream):
	sfx.stream = stream
	sfx.play()
