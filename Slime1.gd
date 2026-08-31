extends CharacterBody2D

@export var max_health: int = 10
@export var damage = 5

var health: int = max_health
var player_in_attack_range = false
var can_damage_player = true
var is_dead = false
var is_attacking = false

var SPEED = 25
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var chase = false
var attacking = false
var player

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_attack: Area2D = $PlayerAttack

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	velocity.y += gravity * delta

	if attacking:
		velocity.x = 0

	elif chase:
		sprite.play("Run")

		player = get_node("../../Player/Player")
		var direction = (player.position - position).normalized()

		if direction.x > 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false

		velocity.x = direction.x * SPEED

	else:
		sprite.play("Idle")
		velocity.x = 0

	move_and_slide()

	if player_in_attack_range and can_damage_player:
		attack_player()

func _on_player_detect_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		chase = true

func _on_player_detect_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		chase = false

func _on_player_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_attack_range = true

func _on_player_attack_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_attack_range = false

func _ready() -> void:
	add_to_group("enemies")

func attack_player() -> void:
	if is_dead or attacking:
		return

	attacking = true
	can_damage_player = false
	velocity.x = 0
	sprite.play("Attack")

	for body in player_attack.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(damage)

	await sprite.animation_finished

	if not is_dead:
		attacking = false
	
		await get_tree().create_timer(5.0).timeout
	
		if not is_dead:
			can_damage_player = true

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	print("Slime HP: ", health)

	if health <= 0:
		die()

	if health <= 0:
		chase = false
		sprite.play("Death")
		$CollisionShape2D.set_deferred("disabled", true)
		player_attack.set_deferred("monitoring", false)

func die() -> void:
	is_dead = true
	chase = false
	attacking = false
	velocity = Vector2.ZERO

	sprite.play("Death")

	$CollisionShape2D.set_deferred("disabled", true)
	$PlayerDetect.set_deferred("monitoring", false)
	player_attack.set_deferred("monitoring", false)

	set_physics_process(false)

	await sprite.animation_finished
	
	remove_from_group("enemies")
	get_tree().call_group("level_manager", "check_all_slimes_defeated")
	queue_free()
