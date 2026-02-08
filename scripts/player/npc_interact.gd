extends Area2D

@export var ui: Control

var player_in_range := false
var player_ref: Node = null

func _ready():
	ui.visible = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if player_ref == body:
			player_ref = null

func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		open_ui()

	if ui.visible and Input.is_action_just_pressed("ui_cancel"):
		close_ui()

func open_ui():
	ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if player_ref:
		player_ref.set_physics_process(false)
		player_ref.set_process(false)

func close_ui():
	ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if player_ref:
		player_ref.set_physics_process(true)
		player_ref.set_process(true)
