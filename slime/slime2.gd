extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $DetectionArea/AttackArea

const SPEED = 100.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player = null
var can_attack = true
var facing_direction = "front" # 'front', 'back', 'left', 'right'
var state = "idle"

func _ready():
	animated_sprite.play("idle_front")
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

func _physics_process(delta):
	# Always apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	if state == "attack":
		# Don't move horizontally or change animation, but still apply gravity and move_and_slide
		move_and_slide()
		return

	if player:
		var to_player = player.global_position - global_position
		if abs(to_player.x) > abs(to_player.y):
			if to_player.x > 0:
				facing_direction = "right"
				velocity.x = SPEED
			else:
				facing_direction = "left"
				velocity.x = -SPEED
			# Only gravity affects y
		else:
			if to_player.y > 0:
				facing_direction = "front"
				velocity.y = SPEED
			else:
				facing_direction = "back"
				velocity.y = -SPEED
			velocity.x = 0
		state = "walk"
	else:
		velocity.x = 0
		# Let gravity handle velocity.y
		state = "idle"

	if state == "walk":
		animated_sprite.play("run_" + facing_direction)
	elif state == "idle":
		animated_sprite.play("idle_" + facing_direction)

	move_and_slide()

func _on_detection_area_body_entered(body):
	if body.name == "player":
		player = body

func _on_detection_area_body_exited(body):
	if body == player:
		player = null

func _on_attack_area_body_entered(body):
	if body == player and can_attack:
		attack()

func _on_attack_area_body_exited(body):
	pass

func attack():
	state = "attack"
	can_attack = false
	velocity.x = 0 # Only stop horizontal movement, let gravity act on y
	var anim = "attack_" + facing_direction
	if not animated_sprite.sprite_frames.has_animation(anim):
		anim = "attack_front"
	animated_sprite.play(anim)
	await animated_sprite.animation_finished
	state = "idle"
	# If not on floor after attack, force downward velocity
	if not is_on_floor():
		velocity.y = 200
	# Nudge away from player if overlapping
	if player and global_position.distance_to(player.global_position) < 10:
		var away = (global_position - player.global_position).normalized()
		global_position += away * 10
	await get_tree().create_timer(1.5).timeout
	can_attack = true
