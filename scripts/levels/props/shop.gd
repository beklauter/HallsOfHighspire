extends Area2D

@export var animated_sprite_2d: AnimatedSprite2D
var player_in_range = false
var player_ref: Node = null
@export var shop_ui: Control

func _ready() -> void:
	animated_sprite_2d.play("default")
	shop_ui.visible = false
	
func _on_body_entered(body):
	print("ENTER:", body.name, " groups:", body.get_groups())
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body):
	print("Exit:", body.name, " groups:", body.get_groups())
	if body.is_in_group("player"):
		player_in_range = false
		if player_ref == body:
			player_ref = null
		
func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		print("INTERACT pressed in range")
		open_shop()
	if Input.is_action_just_pressed("ui_cancel"):
		close_shop()
		
func open_shop():
	shop_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if player_ref and player_ref is CharacterBody2D:
		player_ref.velocity = Vector2.ZERO
		player_ref.set_physics_process(false)
		player_ref.set_process(false)

func close_shop():
	shop_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if player_ref:
		player_ref.set_physics_process(true)
		player_ref.set_process(true)
