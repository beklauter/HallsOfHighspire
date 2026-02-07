extends CharacterBody2D

const SPEED = 280.0
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
const WALL_STICK_TIME = 0.10

const DASH_SPEED = 500.0
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

const CAM_LOOKAHEAD_MAX_X = 110.0
const CAM_LOOKAHEAD_MAX_Y = 80.0
const CAM_LOOKAHEAD_SPEED = 6.0
const CAM_POS_SMOOTH = 8.5
const CAM_POS_SMOOTH_FALL = 6.5
const CAM_VEL_FILTER = 10.0
const CAM_FASTFALL_LOOKDOWN = 90.0
const CAM_DEADZONE_Y = 70.0
const CAM_Y_RECENTER_SPEED = 2.2
const CAM_VERTICAL_BIAS = -130.0

const WALL_JUMP_REARM_MIN_TIME = 0.06

const INVINCIBLE_TIME = 0.5
const DAMAGE_KNOCKBACK_X = 260.0
const DAMAGE_KNOCKBACK_Y = -120.0

var max_hp: int = 5
var hp: int = 5
var invincible: bool = false
var invincible_timer: float = 0.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var wall_stick_timer: float = 0.0
var last_wall_dir: int = 0

var wall_jump_rearm_timer: float = 0.0
var wall_jump_rearm_needed: bool = false
var last_wall_jump_dir: int = 0

var max_air_jumps: int = 1
var jump_count: int = 0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: int = 0
var dash_anim_name: StringName = &"ground_dash"
var last_dash_was_air: bool = false
var air_dash_available: bool = true

var animation_locked: bool = false
var stop_control_timer: float = 0.0

var was_on_floor: bool = false
var prev_vy: float = 0.0

var cam_pos: Vector2 = Vector2.ZERO
var cam_vel_f: Vector2 = Vector2.ZERO
var cam_look: Vector2 = Vector2.ZERO
var cam_target_y: float = 0.0

var attack_hit_once: Dictionary = {}

enum PlayerState { IDLE, RUN, JUMP, WALLSLIDE, DASH, DASHSTOP, ATTACK }
var state: PlayerState = PlayerState.IDLE

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D")
@onready var attack_hitbox: Area2D = $AttackHitbox

var sprite_base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	sprite_base_pos = animated_sprite_2d.position
	play_anim(&"idle")
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	_force_no_loop(&"attack")
	attack_hitbox.monitoring = false
	hp = max_hp

	if camera_2d:
		camera_2d.position_smoothing_enabled = false
		cam_pos = camera_2d.global_position
		cam_target_y = global_position.y + CAM_VERTICAL_BIAS

func _physics_process(delta: float) -> void:
	prev_vy = velocity.y

	if invincible:
		invincible_timer -= delta
		if invincible_timer <= 0.0:
			invincible = false

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if stop_control_timer > 0.0:
		stop_control_timer -= delta
	if wall_stick_timer > 0.0:
		wall_stick_timer -= delta
	if wall_jump_rearm_timer > 0.0:
		wall_jump_rearm_timer -= delta

	if is_on_floor():
		air_dash_available = true
		coyote_timer = COYOTE_TIME
		jump_count = 0
		wall_jump_rearm_needed = false
		last_wall_jump_dir = 0
		wall_jump_rearm_timer = 0.0
	else:
		coyote_timer -= delta

	if wall_jump_rearm_needed:
		if not is_on_wall_only():
			wall_jump_rearm_needed = false
		else:
			var wd: int = get_wall_directions()
			if wd != 0 and wd != last_wall_jump_dir:
				wall_jump_rearm_needed = false
			elif wall_jump_rearm_timer <= 0.0:
				var away: float = Input.get_axis("left", "right")
				if away != 0.0 and sign(away) == last_wall_jump_dir:
					wall_jump_rearm_needed = false

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if Input.is_action_just_pressed("attack1"):
		try_attack()

	if Input.is_action_just_pressed("dash"):
		try_dash()

	if is_dashing:
		handle_dash(delta)
	else:
		apply_gravity(delta)
		apply_wall_slide(delta)
		handle_jump_logic()
		handle_movement(delta)

	if state == PlayerState.ATTACK and attack_hitbox.monitoring:
		_apply_attack_hits()

	move_and_slide()

	var landed: bool = (not was_on_floor) and is_on_floor()
	if landed:
		on_landed(prev_vy)

	update_state_and_animation()
	update_visual_snap()
	update_camera(delta)

	was_on_floor = is_on_floor()

func take_damage(amount: int, from_x: float) -> void:
	if invincible:
		return

	hp -= amount
	print("Player HP:", hp)

	if hp <= 0:
		print("Player died")
		queue_free()
		return

	invincible = true
	invincible_timer = INVINCIBLE_TIME

	var kb_dir: float = sign(global_position.x - from_x)
	if kb_dir == 0.0:
		kb_dir = 1.0

	velocity.x = kb_dir * DAMAGE_KNOCKBACK_X

	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y = minf(velocity.y, 0.0) + DAMAGE_KNOCKBACK_Y



func try_attack() -> void:
	if state == PlayerState.ATTACK and animation_locked:
		return
	if is_dashing:
		cancel_dash()

	if is_on_floor():
		velocity.x = 0.0
	else:
		velocity.x *= 0.4

	state = PlayerState.ATTACK
	animation_locked = true
	play_anim_restart(&"attack")
	_start_attack_hitbox()

func _start_attack_hitbox() -> void:
	attack_hit_once.clear()
	_set_attack_hitbox_active(true)
	_apply_attack_hits()

func _apply_attack_hits() -> void:
	var bodies := attack_hitbox.get_overlapping_bodies()
	for b in bodies:
		if b == null:
			continue
		if attack_hit_once.has(b):
			continue
		if b.has_method("take_damage"):
			b.call("take_damage", 1, global_position.x)
			attack_hit_once[b] = true

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

func update_camera(delta: float) -> void:
	if camera_2d == null:
		return

	cam_vel_f = cam_vel_f.lerp(velocity, 1.0 - exp(-CAM_VEL_FILTER * delta))

	var desired_look_x: float = clamp(cam_vel_f.x * 0.22, -CAM_LOOKAHEAD_MAX_X, CAM_LOOKAHEAD_MAX_X)
	var desired_look_y: float = clamp(cam_vel_f.y * 0.12, -CAM_LOOKAHEAD_MAX_Y, CAM_LOOKAHEAD_MAX_Y)

	var lookdown: float = 0.0
	if Input.is_action_pressed("drop") and velocity.y > 0.0 and not is_on_floor():
		lookdown = CAM_FASTFALL_LOOKDOWN

	cam_look.x = lerp(cam_look.x, desired_look_x, 1.0 - exp(-CAM_LOOKAHEAD_SPEED * delta))
	cam_look.y = lerp(cam_look.y, desired_look_y + lookdown, 1.0 - exp(-CAM_LOOKAHEAD_SPEED * delta))

	var dy: float = global_position.y + CAM_VERTICAL_BIAS - cam_target_y
	if absf(dy) > CAM_DEADZONE_Y:
		cam_target_y = global_position.y + CAM_VERTICAL_BIAS - sign(dy) * CAM_DEADZONE_Y
	else:
		if is_on_floor():
			cam_target_y = lerp(cam_target_y, global_position.y + CAM_VERTICAL_BIAS, 1.0 - exp(-CAM_Y_RECENTER_SPEED * delta))

	var target: Vector2 = Vector2(global_position.x, cam_target_y) + cam_look
	var smooth: float = CAM_POS_SMOOTH_FALL if (not is_on_floor() and velocity.y > 0.0) else CAM_POS_SMOOTH
	cam_pos = cam_pos.lerp(target, 1.0 - exp(-smooth * delta))
	camera_2d.global_position = cam_pos

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
	if velocity.y <= 0.0:
		return

	var gravity: Vector2 = get_gravity() * WALL_SLIDE_GRAVITY_MULTIPLIER
	velocity += gravity * delta
	velocity.y = minf(velocity.y, WALL_SLIDE_MAX_SPEED)
	velocity.x = move_toward(velocity.x, -wall_dir * WALL_STICK_SPEED, AIR_ACCELERATION * delta)

func handle_jump_logic() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if is_dashing:
		cancel_dash()

	if is_on_wall_only() and wall_stick_timer > 0.0 and not wall_jump_rearm_needed:
		var dir: int = get_wall_directions()
		velocity.y = WALL_JUMP_VERTICAL_SPEED
		velocity.x = -dir * WALL_JUMP_HORIZONTAL_SPEED
		jump_buffer_timer = 0.0
		wall_stick_timer = 0.0
		wall_jump_rearm_needed = true
		last_wall_jump_dir = dir
		wall_jump_rearm_timer = WALL_JUMP_REARM_MIN_TIME
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

	if state == PlayerState.ATTACK and animation_locked:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		else:
			var direction_air: float = Input.get_axis("left", "right")
			var target_air: float = direction_air * SPEED * 0.35
			velocity.x = move_toward(velocity.x, target_air, AIR_ACCELERATION * 0.35 * delta)
			if direction_air != 0.0:
				animated_sprite_2d.flip_h = direction_air < 0.0
				attack_hitbox.position.x = absf(attack_hitbox.position.x) * (-1.0 if animated_sprite_2d.flip_h else 1.0)
		return

	var direction: float = Input.get_axis("left", "right")
	var target_speed: float = direction * SPEED

	if direction != 0.0:
		var accel: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
		animated_sprite_2d.flip_h = direction < 0.0
		attack_hitbox.position.x = absf(attack_hitbox.position.x) * (-1.0 if animated_sprite_2d.flip_h else 1.0)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

func try_dash() -> void:
	if dash_cooldown_timer > 0.0:
		return
	if not is_on_floor() and not air_dash_available:
		return
	if state == PlayerState.ATTACK and animation_locked:
		return

	_set_attack_hitbox_active(false)

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
	play_anim_restart(dash_anim_name)

func handle_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.y = 0.0
	velocity.x = dash_direction * DASH_SPEED
	if dash_timer <= 0.0:
		is_dashing = false
		animation_locked = false

func cancel_dash() -> void:
	is_dashing = false
	dash_timer = 0.0
	animation_locked = false

func update_state_and_animation() -> void:
	if animation_locked:
		return

	if is_on_wall_only() and wall_stick_timer > 0.0 and not is_on_floor() and velocity.y > 0.0:
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

func play_anim(anim_name: StringName) -> void:
	if animated_sprite_2d.animation != anim_name:
		animated_sprite_2d.play(anim_name)

func play_anim_restart(anim_name: StringName) -> void:
	animated_sprite_2d.stop()
	animated_sprite_2d.animation = anim_name
	animated_sprite_2d.frame = 0
	animated_sprite_2d.play(anim_name)

func _force_no_loop(anim_name: StringName) -> void:
	var sf: SpriteFrames = animated_sprite_2d.sprite_frames
	if sf and sf.has_animation(anim_name):
		sf.set_animation_loop(anim_name, false)

func _on_animation_finished() -> void:
	if state == PlayerState.DASH and (animated_sprite_2d.animation == &"ground_dash" or animated_sprite_2d.animation == &"air_dash"):
		animation_locked = false
	if state == PlayerState.DASHSTOP and animated_sprite_2d.animation == &"dash_stop":
		animation_locked = false
	if state == PlayerState.ATTACK and animated_sprite_2d.animation == &"attack":
		_set_attack_hitbox_active(false)
		animation_locked = false

func get_wall_directions() -> int:
	var c := get_last_slide_collision()
	if c:
		return 1 if c.get_normal().x > 0.0 else -1
	return sign(velocity.x) if velocity.x != 0.0 else (-1 if animated_sprite_2d.flip_h else 1)

func _set_attack_hitbox_active(active: bool) -> void:
	attack_hitbox.monitoring = active
	if not active:
		attack_hit_once.clear()
