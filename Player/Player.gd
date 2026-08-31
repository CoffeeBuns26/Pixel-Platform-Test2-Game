extends CharacterBody2D


@export var SPEED: float = 200.0
@export var JUMP_VELOCITY: float = -300.0
@export var double_JUMP_Velocity:float = -250
@export var max_health = 100
@export var attack_damage = 2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_zone = $AttackZone

@export var gravity = 1000
var has_double_jump: bool = false
var animation_locked: bool = false
var direction: Vector2 = Vector2.ZERO
var was_in_air: bool = false

var health = max_health
var hit_bodies: Array[Node2D] = []

func _ready() -> void:
	add_to_group("player")
	attack_zone.body_entered.connect(_on_attack_zone_body_entered)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor() and !Game.is_climbing:
		velocity.y += gravity * delta
		was_in_air = true
	else:
		has_double_jump = false
		
		if was_in_air == true:
			land()
			
		was_in_air = false
	if Game.is_climbing:
		if Input.is_action_pressed("ui_down"):
			$AnimatedSprite2D.play("Climb")
			velocity.y = SPEED * delta * 10
		elif Input.is_action_pressed("ui_up"):
			$AnimatedSprite2D.play("Climb")
			velocity.y = -SPEED * delta * 10
		else:
			$AnimatedSprite2D.play("Idle")
			velocity.y = 0

	# Attack
	if Input.is_action_just_pressed("ui_attack") and !Game.is_attacking:
		start_attack("Attack")
	elif Input.is_action_just_pressed("ui_rattack") and !Game.is_attacking:
		start_attack("DoubleAttack")

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			jump()
		elif not has_double_jump:
			double_jump()

	# Get the input direction and handle the movement/deceleration.
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if direction.x != 0 && animated_sprite.animation != "Fall":
		velocity.x = direction.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	update_animation()
	update_facing_direction()

@warning_ignore("shadowed_variable_base_class")
func start_attack(name: String) -> void:
	if animation_locked:
		return
	
	Game.is_attacking = true
	animation_locked = true
	velocity.x = 0
	hit_bodies.clear()
	animated_sprite.play(name)
	
	await get_tree().physics_frame

	hit_bodies.clear()
	hit_enemies_in_attack_zone()

	if name == "DoubleAttack":
		await get_tree().create_timer(0.18).timeout

		hit_bodies.clear()
		hit_enemies_in_attack_zone()

	await animated_sprite.animation_finished

	Game.is_attacking = false
	animation_locked = false

func update_animation() -> void:
	if animation_locked or Game.is_attacking:
		return
		
	if not is_on_floor():
		animated_sprite.play("Jumploop")
	elif direction.x != 0:
		animated_sprite.play("Run")
	else:
		animated_sprite.play("Idle")

func update_facing_direction():
	if direction.x > 0:
		animated_sprite.flip_h = false
		attack_zone.scale.x = 1
	elif direction.x < 0:
		animated_sprite.flip_h = true
		attack_zone.scale.x = -1

func jump():
	velocity.y = JUMP_VELOCITY
	animated_sprite.play("Jump")
	animation_locked = true

func double_jump():
	velocity.y = double_JUMP_Velocity
	animated_sprite.play("DoubleJump")
	animation_locked = true
	has_double_jump = true

func land():
	animated_sprite.play("Fall")
	Game.is_attacking = false
	animation_locked = false

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation in ["Attack", "DoubleAttack"]:
		Game.is_attacking = false
	if animated_sprite.animation in ["Jump", "DoubleJump", "Fall"]:
		animation_locked = false

func _on_attack_zone_body_entered(body: Node2D) -> void:
	if Game.is_attacking:
		_damage_enemy(body)

func _damage_enemy(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if body in hit_bodies:
		return

	hit_bodies.append(body)
	body.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	health -= amount
	Game.playerHP = health

	print("Player HP: ", health)

	if health <= 0:
		get_tree().change_scene_to_file("res://main.tscn")

func hit_enemies_in_attack_zone() -> void:
	for body in attack_zone.get_overlapping_bodies():
		_damage_enemy(body)
