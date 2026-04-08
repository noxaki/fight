extends Sprite2D

@export var stiffness: float = 0.5
@export var damping: float = 0.85
@export var max_angle: float = 45.0 # Degrees
@export var motion_multiplier: float = 1.0

var velocity: float = 0.0
var previous_global_pos: Vector2

func _ready() -> void:
	previous_global_pos = global_position

func _physics_process(delta: float) -> void:
	var current_global_pos = global_position
	# Compute horizontal acceleration of this node
	var horizontal_movement = (current_global_pos.x - previous_global_pos.x) * motion_multiplier
	
	# Apply force based on movement
	velocity -= horizontal_movement * delta
	
	# Spring towards 0 rotation
	velocity -= rotation * stiffness
	
	# Apply damping
	velocity *= damping
	
	# Apply to rotation
	rotation += velocity
	
	# Clamp rotation so it doesn't spin wildly
	rotation = clamp(rotation, deg_to_rad(-max_angle), deg_to_rad(max_angle))
	
	previous_global_pos = current_global_pos
