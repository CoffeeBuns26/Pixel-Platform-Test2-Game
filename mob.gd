extends CharacterBody2D

enum State { Idle, Run, Attack, Hurt, Death }

@export var run_speed: float = 130.0
@export var gravity: float = 600.0
@export var max_health: int = 100
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var knockback_force: Vector2 = Vector2(180, -150)

@export var run_left_offset: float = -120.0
@export var run_right_offset: float = 120.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Detection
@onready var attack_area: Area2D = $Attack
@onready var floor_ray: RayCast2D = $FloorRay
@onready var attack_timer: Timer = $AttackTimer

var state: State = State.Idle
var health: int
var start_position: Vector2
var moving_right: bool = true
var target: Node2D = null
var stun_time: float = 0.0
var attacking: bool = false


func _ready():
	start_position = global_position
	health = max_health

	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_area.body_entered.connect(_on_attack_entered)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	match state:
		State.Idle:
			_idle(delta)
		State.Run:
			_run(delta)
		State.Attack:
			velocity.x = 0
		State.Hurt:
			_hurt(delta)
		State.Death:
			return

	move_and_slide()
	_update_sprite()


# ------------------------------------
#               IDLE
# ------------------------------------
func _idle(_delta):
	var left_limit = start_position.x + run_left_offset
	var right_limit = start_position.x + run_right_offset

	velocity.x = run_speed if moving_right else -run_speed

	if global_position.x > right_limit:
		moving_right = false
	elif global_position.x < left_limit:
		moving_right = true

	if not floor_ray.is_colliding():
		moving_right = not moving_right


# ------------------------------------
#               RUN
# ------------------------------------
func _run(_delta):
	if not is_instance_valid(target):
		state = State.Idle
		return

	var direction = sign(target.global_position.x - global_position.x)
	velocity.x = direction * run_speed


# ------------------------------------
#               HURT
# ------------------------------------
func _hurt(delta):
	stun_time -= delta
	if stun_time <= 0:
		state = State.Run if target else State.Idle


# ------------------------------------
#            ATTACK LOGIC
# ------------------------------------
func _on_detection_entered(body):
	if body.is_in_group("player"):
		target = body
		state = State.Run


func _on_detection_exited(body):
	if body == target:
		target = null
		state = State.Idle


func _on_attack_entered(body):
	if body.is_in_group("player") and not attacking:
		if attack_timer.time_left == 0:
			_start_attack(body)


func _start_attack(player):
	attacking = true
	state = State.Attack

	attack_timer.start(attack_cooldown)

	# Deal damage
	if player.has_method("take_damage"):
		var dir = sign(player.global_position.x - global_position.x)
		var knock = Vector2(knockback_force.x * dir, knockback_force.y)
		player.take_damage(attack_damage, knock)

	# Play attack anim fully
	if sprite.sprite_frames.has_animation("Attack"):
		var frames = sprite.sprite_frames.get_frame_count("Attack")
		var fps = sprite.sprite_frames.get_animation_speed("Attack")
		var duration = frames / fps

		sprite.play("Attack")
		await get_tree().create_timer(duration).timeout

	attacking = false

	# Return to run if still chasing
	state = State.Run if target else State.Idle


func _on_attack_timer_timeout():
	pass # cooldown only, attack handled above


# ------------------------------------
#              DAMAGE
# ------------------------------------
func take_damage(amount: int, knockback: Vector2):
	health -= amount
	print("Enemy HP:", health)

	if health <= 0:
		_die()
		return

	velocity = knockback
	stun_time = 0.3
	state = State.Hurt

	if sprite.sprite_frames.has_animation("Hurt"):
		sprite.play("Hurt")


# ------------------------------------
#              DEATH
# ------------------------------------
func _die():
	state = State.Death
	velocity = Vector2.ZERO

	print("Enemy died!")

	if sprite.sprite_frames.has_animation("Death"):
		var frames = sprite.sprite_frames.get_frame_count("Death")
		var fps = sprite.sprite_frames.get_animation_speed("Death")
		var duration = frames / fps

		sprite.play("Death")
		await get_tree().create_timer(duration).timeout

	queue_free()


# ------------------------------------
#         GRAVITY & ANIM
# ------------------------------------
func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0:
			velocity.y = 0


func _update_sprite():
	if state in [State.Attack, State.Hurt, State.Death]:
		return

	if velocity.x > 1:
		sprite.flip_h = false
	elif velocity.x < -1:
		sprite.flip_h = true

	match state:
		State.Idle:
			sprite.play("Idle")
		State.Run:
			sprite.play("Run")
