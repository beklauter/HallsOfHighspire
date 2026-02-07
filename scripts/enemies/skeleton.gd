extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox

@export var speed: float = 60.0
@export var walk_time_range: Vector2 = Vector2(0.6, 1.4)
@export var idle_time_range: Vector2 = Vector2(0.4, 1.2)

@export var use_gravity: bool = true
@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@export var max_hp: int = 3
@export var hit_stun_time: float = 0.12
@export var knockback_x: float = 140.0
@export var knockback_y: float = -120.0

@export var aggro_range: float = 220.0
@export var give_up_range: float = 320.0
@export var chase_speed: float = 95.0

@export var attack_range: float = 34.0
@export var attack_damage: int = 1
@export var attack_windup: float = 0.10
@export var attack_active_time: float = 0.12
@export var attack_cooldown: float = 0.55

@export var wander_turn_chance_percent: int = 35
@export var accel_ground: float = 900.0
@export var friction_ground: float = 1200.0

enum State { IDLE, WALK, HIT, ATTACK, DEAD, AGGRO, CHASE }
var state: State = State.IDLE

var dir: int = 1
var state_timer: float = 0.0
var hp: int = 3

var player: Node2D = null

var attack_cd_timer: float = 0.0
var attack_windup_timer: float = 0.0
var attack_active_timer: float = 0.0
var attack_hit_once: Dictionary = {}

func _ready() -> void:
	randomize()
	hp = max_hp
	_pick_new_state(State.IDLE)
	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = 0.0
		_play_if_not("dead")
		_apply_gravity(delta)
		move_and_slide()
		return

	if use_gravity and not is_on_floor():
		velocity.y += gravity * delta
	elif use_gravity and is_on_floor():
		velocity.y = 0.0

	if attack_cd_timer > 0.0:
		attack_cd_timer -= delta

	_find_player()

	if state == State.ATTACK:
		_handle_attack(delta)
		move_and_slide()
		return

	if state == State.HIT:
		state_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, friction_ground * delta)
		_play_if_not("hit")
		move_and_slide()
		if state_timer <= 0.0 and state == State.HIT:
			_pick_new_state(State.IDLE)
		return

	var has_p: bool = player != null and is_instance_valid(player)
	if has_p:
		var dist: float = global_position.distance_to(player.global_position)
		if state in [State.IDLE, State.WALK] and dist <= aggro_range:
			state = State.AGGRO
			state_timer = randf_range(0.06, 0.14)
		elif state in [State.AGGRO, State.CHASE] and dist >= give_up_range:
			player = null
			_pick_new_state(State.IDLE)

	if state == State.AGGRO:
		_handle_aggro(delta)
		move_and_slide()
		return

	if state == State.CHASE:
		_handle_chase(delta)
		move_and_slide()
		return

	state_timer -= delta
	if state_timer <= 0.0 and state in [State.IDLE, State.WALK]:
		if state == State.IDLE:
			_pick_new_state(State.WALK)
		else:
			_pick_new_state(State.IDLE)

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, friction_ground * delta)
			_play_if_not("idle")
		State.WALK:
			var target_w: float = float(dir) * speed
			velocity.x = move_toward(velocity.x, target_w, accel_ground * delta)
			_play_if_not("walk")

	move_and_slide()

func _handle_aggro(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, friction_ground * delta)
	if player != null and is_instance_valid(player):
		_set_facing(signi(player.global_position.x - global_position.x))
	_play_if_not("idle")
	if state_timer <= 0.0:
		state = State.CHASE

func _handle_chase(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_pick_new_state(State.IDLE)
		return

	var dx: float = player.global_position.x - global_position.x
	var distx: float = absf(dx)

	_set_facing(signi(dx))

	if distx <= attack_range and attack_cd_timer <= 0.0:
		do_attack()
		return

	var target: float = float(signi(dx)) * chase_speed
	velocity.x = move_toward(velocity.x, target, accel_ground * delta)
	_play_if_not("walk")

func _handle_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction_ground * delta)

	if attack_windup_timer > 0.0:
		attack_windup_timer -= delta
		if attack_windup_timer <= 0.0:
			attack_hit_once.clear()
			attack_hitbox.monitoring = true
			attack_active_timer = attack_active_time

	if attack_hitbox.monitoring:
		attack_active_timer -= delta
		if attack_active_timer <= 0.0:
			attack_hitbox.monitoring = false

	_play_if_not("attack")

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if state != State.ATTACK:
		return
	if not attack_hitbox.monitoring:
		return
	if attack_hit_once.has(body):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", attack_damage, global_position.x)
		attack_hit_once[body] = true

func do_attack() -> void:
	if state in [State.DEAD, State.HIT]:
		return
	if attack_cd_timer > 0.0:
		return
	state = State.ATTACK
	attack_cd_timer = attack_cooldown
	attack_windup_timer = attack_windup
	attack_active_timer = 0.0
	attack_hitbox.monitoring = false
	anim.play("attack")

func take_damage(amount: int, attacker_global_x: float) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	if hp <= 0:
		do_die()
		return

	state = State.HIT
	state_timer = hit_stun_time
	anim.play("hit")
	print("Skeleton HP: ", hp)

	var kb_dir: float = sign(global_position.x - attacker_global_x)
	if kb_dir == 0.0:
		kb_dir = 1.0
	velocity.x = kb_dir * knockback_x
	velocity.y = minf(velocity.y, 0.0) + knockback_y

func do_die() -> void:
	state = State.DEAD
	anim.play("dead")
	print("Skeleton Died")
	velocity = Vector2.ZERO
	use_gravity = false
	attack_hitbox.monitoring = false

func _pick_new_state(new_state: State) -> void:
	state = new_state

	if state == State.WALK:
		if randi() % 100 < wander_turn_chance_percent:
			dir = (randi() % 2) * 2 - 1
		state_timer = randf_range(walk_time_range.x, walk_time_range.y)
		_set_facing(dir)
	elif state == State.IDLE:
		state_timer = randf_range(idle_time_range.x, idle_time_range.y)
	elif state == State.HIT:
		state_timer = hit_stun_time
	elif state == State.ATTACK:
		state_timer = 0.0

func _find_player() -> void:
	if player != null and is_instance_valid(player):
		return
	var arr := get_tree().get_nodes_in_group("player")
	if arr.size() > 0:
		player = arr[0] as Node2D

func _set_facing(d: int) -> void:
	if d == 0:
		return
	dir = d
	anim.flip_h = (d < 0)
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * (-1.0 if anim.flip_h else 1.0)

func _play_if_not(name: String) -> void:
	if anim.animation != name:
		anim.play(name)

func _on_animated_sprite_2d_animation_finished() -> void:
	if state == State.ATTACK:
		state = State.CHASE if (player != null and is_instance_valid(player)) else State.IDLE
	elif state == State.DEAD:
		pass

func signi(v: float) -> int:
	return -1 if v < 0.0 else (1 if v > 0.0 else 0)
	
func _apply_gravity(delta: float) -> void:
	if not use_gravity:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
