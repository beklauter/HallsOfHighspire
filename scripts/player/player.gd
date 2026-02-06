extends CharacterBody2D

const SPEED = 320.0
const ACCELERATION = 2200.0
const AIR_ACCELERATION = 1400.0
const FRICTION = 2000.0

const JUMP_VELOCITY = -520.0
const GRAVITY_MULTIPLIER_FALL = 1.4
const GRAVITY_MULTIPLIER_RISE = 1.0

const WALL_JUMP_HORIZONTAL_SPEED = 380.0
const WALL_JUMP_VERTICAL_SPEED = -420.0

const WALL_SLIDE_MAX_SPEED = 160.0
const WALL_SLIDE_GRAVITY_MULTIPLIER = 0.35
const WALL_STICK_SPEED = 40.0
const WALLSLIDE_VISUAL_SNAP = 8.0
const WALL_COYOTE_TIME = 0.12
const WALL_STICK_TIME = 0.10

const DASH_SPEED = 700.0
const DASH_TIME = 0.15
const DASH_COOLDOWN = 0.3

const DASH_STOP_CONTROL_LOCK = 0.06
const DASH_STOP_X_MULTIPLIER = 0.35
const DASH_STOP_X_CAP = 240.0
const DASH_STOP_MIN_SLIDE = 90.0

const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

const FASTFALL_GRAVITY_MULTIPLIER = 2.6
const FASTFALL_MAX_SPEED = 1100.0

const LAND_SQUASH_THRESHOLD = 720.0
const LAND_HEAVY_THRESHOLD = 980.0
const LAND_SQUASH_TIME = 0.08
const LAND_SQUASH_LIGHT = Vector2(1.08, 0.92)
const LAND_SQUASH_HEAVY = Vector2(1.16, 0.86)

const CAM_LOOKAHEAD_X = 120.0
const CAM_LOOKAHEAD_SPEED = 520.0
const CAM_DEADZONE_Y = 70.0
const CAM_Y_SPEED = 520.0
const CAM_FASTFALL_LOOKDOWN = 90.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var wall_coyote_timer: float = 0.0
var wall_stick_timer: float = 0.0
var last_wall_dir: int = 0

var max_air_jumps: int = 1
var jump_count: int = 0

var wall_jump_timer: float = 0.0
var wall_jump_cooldown: float = 0.2

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: int = 0
var dash_anim_name: StringName = &"ground_dash"
var last_dash_was_air: bool = false
var air_dash_available: bool = true

var animation_locked: bool = false
var dash_anim_done: bool = true
var stop_control_timer: float = 0.0

var was_on_floor: bool = false
var prev_vy: float = 0.0

enum PlayerState { IDLE, RUN, JUMP, WALLSLIDE, DASH, DASHSTOP }
var state: PlayerState = PlayerState.IDLE

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D")

var sprite_base_pos: Vector2 = Vector2.ZERO
var cam_base_offset: Vector2 = Vector2.ZERO
var cam_target_y: float = 0.0
var cam_offset_x: float = 0.0
var cam_offset_y: float = 0.0

func _ready() -> void:
	sprite_base_pos = animated_sprite_2d.position
	play_anim(&"idle")
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

	if camera_2d:
		camera_2d.position_smoothing_enabled = true
		camera_2d.position_smoothing_speed = 8.0
		cam_base_offset = camera_2d.offset
		cam_target_y = global_position.y

func _physics_process(delta: float) -> void:
	prev_vy = velocity.y

	if wall_jump_timer > 0.0:
		wall_jump_timer -= delta
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if stop_control_timer > 0.0:
		stop_control_timer -= delta

	if is_on_floor():
		air_dash_available = true

	if is_on_wall_only() and not is_on_floor() and not is_dashing:
		last_wall_dir = get_wall_directions()
		wall_coyote_timer = WALL_COYOTE_TIME
	else:
		wall_coyote_timer = maxf(0.0, wall_coyote_timer - delta)

	if wall_stick_timer > 0.0:
		wall_stick_timer -= delta

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jump_count = 0
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if Input.is_action_just_pressed("dash"):
		try_dash()

	if is_dashing:
		handle_dash(delta)
	else:
		apply_gravity(delta)
		apply_wall_slide(delta)
		handle_jump_logic()
		handle_movement(delta)

	move_and_slide()

	var landed: bool = (not was_on_floor) and is_on_floor()
	if landed:
		on_landed(prev_vy)

	update_state_and_animation()
	update_visual_snap()
	update_camera(delta)

	was_on_floor = is_on_floor()

func on_landed(last_vy: float) -> void:
	if last_dash_was_air:
		last_dash_was_air = false
		play_dash_stop()

	var impact: float = absf(last_vy)
	if impact >= LAND_SQUASH_THRESHOLD:
		var squash: Vector2 = LAND_SQUASH_HEAVY if impact >= LAND_HEAVY_THRESHOLD else LAND_SQUASH_LIGHT
		apply_squash(squash, LAND_SQUASH_TIME)

func play_dash_stop() -> void:
	var dir: int = sign(velocity.x)
	if dir == 0:
		dir = -1 if animated_sprite_2d.flip_h else 1

	velocity.x = clamp(velocity.x * DASH_STOP_X_MULTIPLIER, -DASH_STOP_X_CAP, DASH_STOP_X_CAP)
	if absf(velocity.x) < DASH_STOP_MIN_SLIDE:
		velocity.x = dir * DASH_STOP_MIN_SLIDE

	state = PlayerState.DASHSTOP
	animation_locked = true
	stop_control_timer = DASH_STOP_CONTROL_LOCK
	play_anim_restart(&"dash_stop")

func apply_squash(target_scale: Vector2, time_sec: float) -> void:
	var t: Tween = create_tween()
	t.tween_property(animated_sprite_2d, "scale", target_scale, time_sec)
	t.tween_property(animated_sprite_2d, "scale", Vector2.ONE, time_sec * 1.2)

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gravity: Vector2 = get_gravity()
	if velocity.y > 0.0:
		var fall_mult: float = GRAVITY_MULTIPLIER_FALL
		if Input.is_action_pressed("drop"):
			fall_mult *= FASTFALL_GRAVITY_MULTIPLIER
		gravity *= fall_mult
	else:
		gravity *= GRAVITY_MULTIPLIER_RISE

	velocity += gravity * delta

	if Input.is_action_pressed("drop") and velocity.y > FASTFALL_MAX_SPEED:
		velocity.y = FASTFALL_MAX_SPEED

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

func apply_wall_slide(delta: float) -> void:
	if not is_on_wall_only() or is_on_floor() or is_dashing:
		return

	var input_dir: float = Input.get_axis("left", "right")
	var wall_dir: int = get_wall_directions()

	if input_dir != 0.0 and sign(input_dir) == -wall_dir:
		last_wall_dir = wall_dir
		wall_stick_timer = WALL_STICK_TIME

	if wall_stick_timer <= 0.0:
		return

	var gravity: Vector2 = get_gravity() * WALL_SLIDE_GRAVITY_MULTIPLIER
	velocity += gravity * delta
	velocity.y = minf(velocity.y, WALL_SLIDE_MAX_SPEED)
	velocity.x = move_toward(velocity.x, -wall_dir * WALL_STICK_SPEED, AIR_ACCELERATION * delta)

func handle_jump_logic() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if is_on_wall_only():
		var dir: int = get_wall_directions()
		velocity.y = WALL_JUMP_VERTICAL_SPEED
		velocity.x = -dir * WALL_JUMP_HORIZONTAL_SPEED
		jump_buffer_timer = 0.0
		return

	if coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		return

	if jump_count < max_air_jumps:
		jump_count += 1
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0

func handle_movement(delta: float) -> void:
	if stop_control_timer > 0.0:
		return

	var direction: float = Input.get_axis("left", "right")
	var target_speed: float = direction * SPEED

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, (ACCELERATION if is_on_floor() else AIR_ACCELERATION) * delta)
		animated_sprite_2d.flip_h = direction < 0.0
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

func try_dash() -> void:
	if dash_cooldown_timer > 0.0:
		return
	if not is_on_floor() and not air_dash_available:
		return

	dash_direction = sign(Input.get_axis("left", "right"))
	if dash_direction == 0:
		dash_direction = -1 if animated_sprite_2d.flip_h else 1

	is_dashing = true
	dash_timer = DASH_TIME
	dash_cooldown_timer = DASH_COOLDOWN
	velocity = Vector2(dash_direction * DASH_SPEED, 0.0)

	last_dash_was_air = not is_on_floor()
	if last_dash_was_air:
		air_dash_available = false

	dash_anim_name = &"ground_dash" if is_on_floor() else &"air_dash"
	state = PlayerState.DASH
	animation_locked = true
	dash_anim_done = false
	play_anim_restart(dash_anim_name)

func handle_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.y = 0.0
	velocity.x = dash_direction * DASH_SPEED
	if dash_timer <= 0.0:
		is_dashing = false
		animation_locked = false

func update_state_and_animation() -> void:
	if animation_locked:
		return

	if is_on_wall_only() and velocity.y > 0.0:
		state = PlayerState.WALLSLIDE
		play_anim(&"wallslide")
		return

	if not is_on_floor():
		state = PlayerState.JUMP
		play_anim(&"jump")
		return

	if absf(velocity.x) > 10.0:
		state = PlayerState.RUN
		play_anim(&"run")
	else:
		state = PlayerState.IDLE
		play_anim(&"idle")

func update_visual_snap() -> void:
	animated_sprite_2d.position = sprite_base_pos
	if state == PlayerState.WALLSLIDE and is_on_wall_only():
		animated_sprite_2d.position.x = sprite_base_pos.x - get_wall_directions() * WALLSLIDE_VISUAL_SNAP

func update_camera(delta: float) -> void:
	if camera_2d == null:
		return

	var input_dir: float = Input.get_axis("left", "right")
	var look_dir: float = input_dir if input_dir != 0.0 else sign(velocity.x)
	var desired_x: float = look_dir * CAM_LOOKAHEAD_X
	cam_offset_x = move_toward(cam_offset_x, desired_x, CAM_LOOKAHEAD_SPEED * delta)

	var dy: float = global_position.y - cam_target_y
	if absf(dy) > CAM_DEADZONE_Y:
		cam_target_y = global_position.y - sign(dy) * CAM_DEADZONE_Y

	var desired_y: float = cam_target_y - global_position.y
	if Input.is_action_pressed("drop") and velocity.y > 0.0:
		desired_y += CAM_FASTFALL_LOOKDOWN

	cam_offset_y = move_toward(cam_offset_y, desired_y, CAM_Y_SPEED * delta)
	camera_2d.offset = cam_base_offset + Vector2(cam_offset_x, cam_offset_y)

func play_anim(anim_name: StringName) -> void:
	if animated_sprite_2d.animation != anim_name:
		animated_sprite_2d.play(anim_name)

func play_anim_restart(anim_name: StringName) -> void:
	animated_sprite_2d.stop()
	animated_sprite_2d.animation = anim_name
	animated_sprite_2d.frame = 0
	animated_sprite_2d.play(anim_name)

func _on_animation_finished() -> void:
	if state == PlayerState.DASH:
		dash_anim_done = true
		animation_locked = false

func get_wall_directions() -> int:
	var c := get_last_slide_collision()
	if c:
		return 1 if c.get_normal().x > 0.0 else -1
	return sign(velocity.x) if velocity.x != 0.0 else (-1 if animated_sprite_2d.flip_h else 1)
