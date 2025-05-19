extends CharacterBody2D

# Set your movement speed (pixels per second)
var speed := 200
var jump_velocity := -400 # Adjust as needed for your jump height
var gravity := 900 # Adjust as needed
var jump_gravity := 1800 # Extra gravity when jump is released

# Dash variables
var dash_speed := 1200  # Keep original speed
var dash_duration := 0.2  # Total animation time (start: 0.12s + main: 0.16s)
var dash_cooldown := 0.3
var can_dash := true
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 0  # Store dash direction
var dash_frame := 0  # Track dash animation frame
var afterimages = []  # Store afterimage sprites
var max_afterimages = 6  # Reduced from 12 to 6 for shorter dash
var afterimage_spacing = 0.02  # Keep original spacing
var last_afterimage_time = 0.0  # Track when we last created an afterimage
var screen_shake_intensity := 0.0  # For screen shake effect
var motion_blur := 0.0  # For motion blur effect

# New dash momentum variables
var dash_momentum_speed := 400  # Speed after dash ends
var dash_momentum_duration := 0.1  # Reduced from 0.15 to 0.1 for shorter momentum
var dash_momentum_timer := 0.0
var is_in_momentum := false

# New dash wind-up variables
var dash_windup_duration := 0.03  # Reduced from 0.05 to 0.03 for faster wind-up
var dash_windup_timer := 0.0
var is_winding_up := false

var jump_start_timer = 0.0
const JUMP_START_DURATION = 0.12
var was_on_floor = true
var y_velocity_at_impact_check: float = 0.0

var dash_slowdown_timer := 0.0
var dash_slowdown_duration := 0.1
var dash_slowdown_active := false

var dash_time_tween: Tween = null

# Add a timer for echo spawning during dash
var echo_trail_timer := 0.0
var echo_trail_interval := 0.05  # seconds between echoes

# Add variables for dash animation frame cycling
var dash_anim_frames = [4, 5, 2, 0]  # Using jump frames for dash in specific order, adding frame 0 at the end
var dash_anim_index = 0
var dash_anim_timer := 0.0
var dash_anim_interval := 0.04  # Faster interval for jump sequence
var dash_start_frames = [0, 1, 2]  # Running animation frames for dash start
var dash_start_index = 0
var dash_start_timer := 0.0
var is_dash_start := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_collision: CollisionShape2D = $jumpCollisionShape2D
@onready var run_collision: CollisionPolygon2D = $runCollisionPolygon2D
@onready var idle_collision: CollisionPolygon2D = $idleCollisionPolygon2D
@onready var attack_collision: CollisionShape2D = $attackCollisionShape2D
@onready var SpeedLines: CPUParticles2D = $Camera2D/SpeedLines

func _ready():
	print("Available animations: ", sprite.sprite_frames.get_animation_names())
	sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	# Reset any attack-related states when animation finishes
	if sprite.animation.begins_with("attack"):
		attack_collision.disabled = true

func _physics_process(delta):
	var direction = 0

	# Check if we're currently in an attack animation
	var is_attacking = sprite.animation.begins_with("attack") and sprite.is_playing()

	# Handle dash cooldown
	if not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	# Handle dash wind-up
	if is_winding_up:
		if dash_windup_timer == null:
			dash_windup_timer = 0.0
		dash_windup_timer -= delta
		if dash_windup_timer <= 0:
			is_winding_up = false
			is_dashing = true
			is_dash_start = true  # Start with running animation
			dash_start_timer = dash_anim_interval
			dash_start_index = 0
			sprite.play("run")  # Start with run animation
			sprite.frame = dash_start_frames[0]  # Start with first run frame
			if dash_timer == null:
				dash_timer = 0.0
			dash_timer = dash_duration
			can_dash = false
			dash_cooldown_timer = dash_cooldown
			dash_frame = 0
			$Camera2D.push_in_direction(Vector2(dash_direction, 0), 70.0, 0.15)
			print("Dashing!")
			$Camera2D/SpeedLines.scale.x = -dash_direction
			$Camera2D/SpeedLines.emitting = true
			if dash_time_tween:
				dash_time_tween.kill()
			dash_time_tween = create_tween()
			dash_time_tween.tween_property(Engine, "time_scale", 0.7, 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			dash_time_tween.tween_property(Engine, "time_scale", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			dash_slowdown_timer = dash_slowdown_duration
			dash_slowdown_active = true
			echo_trail_timer = 0.0  # Reset echo trail timer
			dash_anim_index = 0
			dash_anim_timer = 0.0

	# Handle dash duration (continuous echo trail)
	if is_dashing:
		if dash_timer == null:
			dash_timer = 0.0
		dash_timer -= delta

		# Handle dash start animation
		if is_dash_start:
			dash_start_timer -= delta
			if dash_start_timer <= 0.0:
				sprite.play("run")
				sprite.frame = dash_start_frames[dash_start_index]
				dash_start_index = (dash_start_index + 1) % dash_start_frames.size()
				dash_start_timer = dash_anim_interval
				if dash_start_index == 0:  # After one complete cycle
					is_dash_start = false
					dash_anim_index = 0
					dash_anim_timer = 0.0
					sprite.play("jump")  # Switch to jump animation
					sprite.frame = dash_anim_frames[0]  # Start with first jump frame
		else:
			# Dash animation frame cycling
			dash_anim_timer -= delta
			if dash_anim_timer <= 0.0:
				sprite.play("jump")  # Use jump animation
				sprite.frame = dash_anim_frames[dash_anim_index]
				dash_anim_index = (dash_anim_index + 1) % dash_anim_frames.size()
				dash_anim_timer = dash_anim_interval
				# Reset animation index when dash is about to end
				if dash_timer <= dash_anim_interval:
					dash_anim_index = 0

		# Spawn echo at intervals during dash
		echo_trail_timer -= delta
		if echo_trail_timer <= 0.0:
			create_burst_echo(global_position, 1, 1)  # Use idx=1, total=1 for full opacity
			echo_trail_timer = echo_trail_interval

		if dash_timer <= 0:
			is_dashing = false
			dash_frame = 0
			sprite.scale = Vector2(1, 1)  # Reset scale
			sprite.rotation = 0.0  # Reset rotation
			$Camera2D/SpeedLines.emitting = false
			motion_blur = 0.0  # Reset motion blur
			# Start momentum phase
			is_in_momentum = true
			if dash_momentum_timer == null:
				dash_momentum_timer = 0.0
			dash_momentum_timer = dash_momentum_duration
			# Add impact effect
			$Camera2D.push_in_direction(Vector2(dash_direction, 0), 30.0, 0.1)
		else:
			# No sprite stretching during dash
			sprite.scale = Vector2(1, 1)
			# Add slight screen stretch in dash direction
			var screen_stretch = lerp(1.1, 1.0, dash_timer / dash_duration)
			$Camera2D.scale = Vector2(
				screen_stretch if dash_direction > 0 else 1.0,
				screen_stretch if dash_direction < 0 else 1.0
			)
			$Camera2D/SpeedLines.emitting = true
			$Camera2D/SpeedLines.scale.x = -dash_direction
			$Camera2D/SpeedLines.scale.y = 1.0

	# Handle dash momentum
	if is_in_momentum:
		if dash_momentum_timer == null:
			dash_momentum_timer = 0.0
		dash_momentum_timer -= delta
		if dash_momentum_timer <= 0:
			is_in_momentum = false
		else:
			# Gradually reduce speed during momentum phase
			var momentum_progress = dash_momentum_timer / dash_momentum_duration
			velocity.x = dash_direction * dash_momentum_speed * momentum_progress

	# Failsafe for Engine.time_scale
	if not is_dashing and not is_in_momentum and not is_winding_up:
		if Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
		# If time_scale was potentially corrected, ensure dash_slowdown_active is false too,
		# as its corresponding timer might have been stalled if time_scale was very low.
		# This prevents dash_slowdown_active's logic from redundantly running after a manual fix.
		if dash_slowdown_active: # Only change if it was true
			dash_slowdown_active = false

	# Only process movement input if not attacking
	if not is_attacking:
		if Input.is_action_pressed("move_left"):
			direction -= 1
		if Input.is_action_pressed("move_right"):
			direction += 1

	# Handle dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing and not is_winding_up and direction != 0:
		is_winding_up = true
		dash_windup_timer = dash_windup_duration
		dash_direction = direction  # Store the direction when dash starts
		# Add wind-up effect
		sprite.scale = Vector2(0.9, 1.1)  # Slight compression
		sprite.rotation = -0.1 * dash_direction  # Slight rotation
		$Camera2D.push_in_direction(Vector2(-dash_direction, 0), 20.0, 0.05)  # Small camera push

	# Handle movement
	if is_dashing:
		velocity.x = dash_direction * dash_speed
	elif not is_in_momentum:  # Only apply normal movement if not in momentum
		velocity.x = direction * speed

	# Sprite flipping
	if direction < 0:
		sprite.flip_h = true
		run_collision.scale.x = -1
		idle_collision.scale.x = -1
	elif direction > 0:
		sprite.flip_h = false
		run_collision.scale.x = 1
		idle_collision.scale.x = 1

	# Store y-velocity before collision processing for landing animation decision
	y_velocity_at_impact_check = velocity.y

	# --- JUMP LOGIC ---
	var intent_jump = Input.is_action_just_pressed("jump") and is_on_floor()

	if intent_jump:
		velocity.y = jump_velocity
		jump_start_timer = JUMP_START_DURATION

	# Variable jump height logic
	if velocity.y < 0 and not Input.is_action_pressed("jump"):
		# If going up and jump is released, apply extra gravity
		velocity.y += jump_gravity * delta
	elif not is_on_floor():
		# Normal gravity when falling or holding jump
		velocity.y += gravity * delta

	move_and_slide()

	# Track landing state after move_and_slide
	var landed_this_frame = (not was_on_floor) and is_on_floor()
	was_on_floor = is_on_floor()

	# --- ANIMATION STATE MACHINE ---
	# Handle attack inputs
	if not is_attacking:
		if Input.is_action_just_pressed("attack_1"):
			sprite.play("attack_1")
			print("Playing attack_1")
		elif Input.is_action_just_pressed("attack_2"):
			sprite.play("attack_2")
			print("Playing attack_2")
		elif Input.is_action_just_pressed("attack_3"):
			sprite.play("attack_3")
			print("Playing attack_3")
		# Handle movement animations only if not attacking
		elif is_dashing:
			# Dash animation is handled in the dash section above
			pass
		elif jump_start_timer > 0:
			jump_start_timer -= delta
			var progress = 1.0 - (jump_start_timer / JUMP_START_DURATION)
			if progress < 0.33:
				sprite.play("jump")
				sprite.frame = 0
			elif progress < 0.66:
				sprite.play("jump")
				sprite.frame = 1
			else:
				sprite.play("jump")
				sprite.frame = 2
		elif not is_on_floor():
			sprite.play("jump")
			if velocity.y < 0:
				if abs(velocity.y) > abs(jump_velocity) * 0.5:
					sprite.frame = 3
				else:
					sprite.frame = 4
			else:
				if abs(velocity.y) < speed * 0.5:
					sprite.frame = 5
				else:
					sprite.frame = 6
		elif landed_this_frame and sprite.animation == "jump":
			if abs(y_velocity_at_impact_check) >= speed * 0.9:
				sprite.play("jump")
				sprite.frame = 7
			else:
				sprite.play("jump")
				sprite.frame = 8
			if direction != 0:
				sprite.play("run")
			else:
				sprite.play("idle")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	# --- COLLISION SHAPE MANAGEMENT ---
	# Disable all by default
	jump_collision.disabled = true
	run_collision.disabled = true
	idle_collision.disabled = true
	attack_collision.disabled = true

	if jump_start_timer > 0 or not is_on_floor():
		jump_collision.disabled = false
	elif is_attacking:
		attack_collision.disabled = false
		attack_collision.scale.x = -1 if sprite.flip_h else 1
	elif direction != 0:
		run_collision.disabled = false
	else:
		idle_collision.disabled = false

	# Handle dash slowdown timer
	if dash_slowdown_active:
		dash_slowdown_timer -= delta
		if dash_slowdown_timer <= 0.0:
			Engine.time_scale = 1.0
			dash_slowdown_active = false

func spawn_dash_echoes():
	var echo_count = 5
	var echo_spacing = 24  # pixels between echoes
	for i in range(1, echo_count + 1):
		var offset = Vector2(dash_direction * i * echo_spacing, 0)
		create_burst_echo(global_position + offset, i, echo_count)

func create_burst_echo(pos: Vector2, idx: int, total: int):
	var afterimage = AnimatedSprite2D.new()
	afterimage.sprite_frames = sprite.sprite_frames
	afterimage.animation = sprite.animation
	afterimage.frame = sprite.frame
	afterimage.flip_h = sprite.flip_h
	afterimage.global_position = pos
	var alpha = lerp(0.5, 0.1, float(idx) / float(total))
	afterimage.modulate = Color(0.3, 0.5, 1.0, alpha)
	afterimage.scale = Vector2(1, 1)
	afterimage.rotation = 0.0
	get_parent().add_child(afterimage)  # Add to parent so echoes stay in world space
	var tween = create_tween()
	var fade_color = Color(0.3, 0.5, 1.0, 0.0)
	tween.tween_property(afterimage, "modulate", fade_color, 0.4)  # Longer fade
	tween.tween_callback(afterimage.queue_free)
