extends Camera2D

@export var player1: Node2D
@export var player2: Node2D

@export var min_zoom: float = 0.8 # Wide
@export var max_zoom: float = 1.5 # Close
@export var max_distance: float = 1000.0 # Distance at which zoom is min_zoom

func _process(_delta):
	if player1 == null or player2 == null:
		return
		
	# Follow midpoint
	var midpoint = (player1.global_position + player2.global_position) / 2.0
	global_position = midpoint
	
	# Adjust zoom based on distance
	var distance = player1.global_position.distance_to(player2.global_position)
	var target_zoom_factor = clamp(1.0 - (distance / max_distance), 0.0, 1.0)
	var target_zoom = lerp(min_zoom, max_zoom, target_zoom_factor)
	
	# Smoothly interpolate zoom
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 0.1)

	# Clamp to arena bounds if necessary (implement bounds check here later)
