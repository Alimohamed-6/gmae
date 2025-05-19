extends Camera2D

@export var shake_decay: float = 12.0

# var shake_amount: float = 0.0
# var shake_direction: Vector2 = Vector2.ZERO
# var shake_offset: Vector2 = Vector2.ZERO

# Camera push variables
var push_offset: Vector2 = Vector2.ZERO
var push_target: Vector2 = Vector2.ZERO
var push_timer: float = 0.0
var push_duration: float = 0.0

# func shake(amount: float = 3.0, direction: Vector2 = Vector2.ZERO):
#     shake_amount = amount
#     shake_direction = direction.normalized()

func push_in_direction(direction: Vector2, amount: float = 40.0, duration: float = 0.15):
	push_target = direction.normalized() * amount
	push_offset = push_target
	push_timer = 0.0
	push_duration = duration

func _process(delta):
	# Camera push logic
	if push_timer < push_duration:
		push_timer += delta
		var t = clamp(push_timer / push_duration, 0.0, 1.0)
		# Ease out for smooth return
		push_offset = push_target.lerp(Vector2.ZERO, t)
	else:
		push_offset = Vector2.ZERO

	# Only push effect (shake commented out)
	offset = push_offset
