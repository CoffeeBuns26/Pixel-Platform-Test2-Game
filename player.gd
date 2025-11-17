extends CharacterBody2D

# -----------------------------
#          SETTINGS
# -----------------------------
@export var move_speed: float = 180.0
@export var jump_force: float = 400.0
@export var gravity: float = 650.0

@export var max_health: int = 100
@export var invincibility_time: float = 0.6

@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.4

var health: int
var invincible: bool = false
var inv_timer: float = 0.0
var dead: bool = false

var attacking: bool = false
var attack_timer: float = 0.0


# -----------------------------
#            NODES
# -----------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $Attack
@onready var attack_start_x: float = attack_area.position.x

func _ready():
	health = max_health
	attack_area.monitoring = false
	add_to_group("player")


# -----------------------------
#        PHYSICS PROCESS
# -----------------------------
func _physics_process(delta: float) -> void:
	if dead:
		move_and_slide()
		return

	_apply_gravity(delta)

	if not attacking:
		_movement(delta)

	_process_invincibility(delta)
	_process_attack(delta)

	move_and_slide()
	_update_sprite()


# -----------------------------
#           INPUT
# -----------------------------
func _input(event):
	if event.is_action_pressed("attack"):
		_start_attack()


# -----------------------------
#           MOVEMENT
# -----------------------------
func _movement(_delta):
	var input_dir = Input.get_axis("ui_left", "ui_right")
	velocity.x = input_dir * move_speed

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = -jump_force


func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0:
			velocity.y = 0


# -----------------------------
#       ATTACK SYSTEM
# -----------------------------
func _start_attack():
	if attacking or dead:
		return

	attacking = true

	if sprite.sprite_frames.has_animation("Attack1"):
		var frames = sprite.sprite_frames.get_frame_count("Attack1")
		var fps = sprite.sprite_frames.get_animation_speed("Attack1")
		attack_timer = frames / fps

		sprite.play("Attack1")

	attack_area.monitoring = true


func _process_attack(delta):
	if attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			attacking = false
			attack_area.monitoring = false


func _on_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		var dir = -1 if sprite.flip_h else 1
		var knockback = Vector2(150 * dir, -100)
		body.take_damage(attack_damage, knockback)


# -----------------------------
#       DAMAGE & KNOCKBACK
# -----------------------------
func take_damage(amount: int, knockback_vec: Vector2):
	if invincible or dead:
		return

	health -= amount
	print("Player HP:", health)

	velocity = knockback_vec

	invincible = true
	inv_timer = invincibility_time

	if sprite.sprite_frames.has_animation("Hurt"):
		sprite.play("Hurt")

	if health <= 0:
		die()


func _process_invincibility(delta):
	if invincible:
		inv_timer -= delta
		if inv_timer <= 0:
			invincible = false


# -----------------------------
#             DEATH
# -----------------------------
func die():
	if dead:
		return

	dead = true
	velocity = Vector2.ZERO

	print("Player died!")

	if sprite.sprite_frames.has_animation("Death"):
		sprite.play("Death")
		await sprite.animation_finished

	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://main.tscn")


# -----------------------------
#            ANIMATION
# -----------------------------
func _update_sprite():
	if sprite == null or dead:
		return

	# Update sprite direction from movement input
	if velocity.x > 1:
		sprite.flip_h = false
	elif velocity.x < -1:
		sprite.flip_h = true

	# Flip the attack hitbox relative to original offset
	if sprite.flip_h:
		attack_area.position.x = -attack_start_x
	else:
		attack_area.position.x = attack_start_x

	# Play animations only when not attacking
	if attacking:
		return

	if not is_on_floor():
		if sprite.sprite_frames.has_animation("Jump"):
			sprite.play("Jump")
	elif abs(velocity.x) > 10:
		if sprite.sprite_frames.has_animation("Run"):
			sprite.play("Run")
	else:
		if sprite.sprite_frames.has_animation("Idle"):
			sprite.play("Idle")
