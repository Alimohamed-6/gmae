extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $DetectionArea/AttackArea

# Set up properties for enemy behavior
const SPEED = 70.0
const ATTACK_RANGE = 50.0  # Distance at which the slime will attack

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state = "idle"
var facing_direction = "front" # can be 'front', 'back', 'left', 'right'
var can_attack = true
var health = 100
var player = null
var is_player_in_attack_area_flag = false

func _ready():
	# Start idle animation
	animated_sprite.play("idle_front")
	
	# Connect the area detection signals
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

# Helper function to check if the tracked player is in a given area
func is_player_still_in_area(area_node: Area2D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(area_node):
		return false
	for body_in_area in area_node.get_overlapping_bodies():
		if body_in_area == player:
			return true
	return false

func _physics_process(delta):
	# Declare previous state and direction for comparison
	var previous_state = current_state
	var previous_facing_direction = facing_direction

	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	var desired_velocity_x = 0.0
	var desired_velocity_y = 0.0

	# 2. Determine Horizontal and Vertical Movement and State based on player presence
	if player and current_state != "attack":
		var to_player = player.global_position - global_position
		# Determine facing direction
		if abs(to_player.x) > abs(to_player.y):
			if to_player.x > 0:
				facing_direction = "right"
				desired_velocity_x = SPEED
			else:
				facing_direction = "left"
				desired_velocity_x = -SPEED
			# No vertical movement
		else:
			if to_player.y > 0:
				facing_direction = "front"
				desired_velocity_y = SPEED
			else:
				facing_direction = "back"
				desired_velocity_y = -SPEED
		current_state = "walk"
	elif not player:
		current_state = "idle"
		desired_velocity_x = 0.0
		desired_velocity_y = 0.0

	# 3. Set Velocity
	velocity.x = desired_velocity_x
	velocity.y = desired_velocity_y

	# 4. Handle Animations (only walk/idle here)
	if current_state == "walk":
		animated_sprite.play("walk_" + facing_direction)
	elif current_state == "idle":
		animated_sprite.play("idle_" + facing_direction)

	# 5. Move the slime
	move_and_slide()

	# Reduce debug output to only significant changes
	if current_state != previous_state:
		print("State changed to: ", current_state)
	if facing_direction != previous_facing_direction:
		print("Facing direction changed to: ", facing_direction)

	# Ensure player detection and state transitions are correct
	if player and current_state != "attack":
		var to_player = player.global_position - global_position
		if abs(to_player.x) > abs(to_player.y):
			if to_player.x > 0:
				facing_direction = "right"
			else:
				facing_direction = "left"
		else:
			if to_player.y > 0:
				facing_direction = "front"
			else:
				facing_direction = "back"
		current_state = "walk"
	elif not player:
		current_state = "idle"

	# Handle attack area logic
	if is_player_in_attack_area_flag and can_attack:
		attack()

func attack():
	if not can_attack: return # Already attacking or on cooldown

	current_state = "attack"
	can_attack = false
	# Ensure facing_direction is correct (might have been set in _on_attack_area_body_entered or _physics_process)
	var attack_anim = "attack_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(attack_anim):
		animated_sprite.play(attack_anim)
	else: # Fallback if specific directional attack animation doesn't exist
		print("Warning: Attack animation " + attack_anim + " not found. Playing default attack.")
		if animated_sprite.sprite_frames.has_animation("attack_front"): # Or a generic "attack"
			animated_sprite.play("attack_front")
		else: # Absolute fallback
			animated_sprite.play("idle_front") 

	await animated_sprite.animation_finished
	current_state = "idle" # Revert to idle after attack animation
	await get_tree().create_timer(2.0).timeout # Cooldown
	can_attack = true

# Signal handlers for detection and attack areas
func _on_detection_area_body_entered(body):
	print("DetectionArea: body entered:", body.name)
	if body.is_in_group("player"):
		print("Player detected by DetectionArea!")
		player = body
		# State will be determined by _physics_process based on distance/attack_flag
		# but good to set to walk if not attacking to initiate movement.
		if current_state != "attack":
			current_state = "walk" # Tentatively set to walk

func _on_detection_area_body_exited(body):
	print("DetectionArea: body exited:", body.name)
	if body == player: # Check if the exiting body is our tracked player
		print("Tracked player left DetectionArea!")
		if not is_player_still_in_area(attack_area):
			print("Player also confirmed out of AttackArea. Disengaging.")
			player = null
			current_state = "idle"
			is_player_in_attack_area_flag = false # Ensure flag is reset
			velocity.x = move_toward(velocity.x, 0, SPEED) # Stop horizontal movement
		else:
			print("Player left DetectionArea, but is still in AttackArea (should be handled by AttackArea logic).")
			# If player is still in attack_area, is_player_in_attack_area_flag should be true.
			# _physics_process will then make the slime idle, waiting for attack or cooldown.

func _on_attack_area_body_entered(body):
	print("AttackArea: body entered:", body.name)
	if body.is_in_group("player"):
		if not is_instance_valid(player): # If detection missed or player teleported in
			player = body
		print("Player now in AttackArea.")
		is_player_in_attack_area_flag = true
		if can_attack:
			# Update facing direction just before attack
			if player.global_position.x > global_position.x:
				facing_direction = "right"
			elif player.global_position.x < global_position.x:
				facing_direction = "left"
			attack()

func _on_attack_area_body_exited(body):
	print("AttackArea: body exited:", body.name)
	if body == player: # Check if the exiting body is our tracked player
		print("Tracked player left AttackArea.")
		is_player_in_attack_area_flag = false
		# Player left attack range. current_state should not be "attack" unless attack() is finishing.
		# If an attack was ongoing, let attack() complete its state transition.
		# If not mid-attack, decide if we should walk or idle.
		if current_state != "attack":
			if is_player_still_in_area(detection_area):
				print("Player still in DetectionArea. Switching to walk.")
				current_state = "walk"
			else:
				print("Player also confirmed out of DetectionArea. Disengaging fully.")
				player = null # Player is completely out of range
				current_state = "idle"
				velocity.x = move_toward(velocity.x, 0, SPEED) # Stop horizontal movement

func take_damage(amount):
	health -= amount
	if health <= 0:
		queue_free()  # Remove slime when health depleted
	else:
		# Flash red when hit
		animated_sprite.modulate = Color(1, 0, 0, 1)
		await get_tree().create_timer(0.1).timeout
		animated_sprite.modulate = Color(1, 1, 1, 1)
