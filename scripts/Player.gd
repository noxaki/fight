extends CharacterBody2D
class_name Player

enum State { IDLE, WALK, JUMP, FLIP_FORWARD, FLIP_BACKWARD, FALL, ATTACK, HIT, KNOCKDOWN, DEAD, RAGDOLL, VICTORY }

signal health_changed(new_health: int)
signal player_died(player: Player)

@export var player_index: int = 1 # 1 for Player 1, 2 for Player 2
@export var opponent: Player

# Match Flow
var input_locked: bool = true
var dead_signal_emitted: bool = false

# Physics and Movement Constants
const SPEED: float = 300.0
const ACCELERATION: float = 2000.0
const FRICTION: float = 3000.0
const JUMP_VELOCITY: float = -750.0
const GRAVITY: float = 2000.0
const AIR_RESISTANCE: float = 1000.0
const AIR_ACCELERATION: float = 1000.0

# Combat Constants
const MAX_HEALTH: int = 1000
var current_weapon: Dictionary
var weapon_cooldown: float = 0.0
const KNOCKBACK_VELOCITY_X: float = 350.0
const KNOCKBACK_VELOCITY_Y: float = -120.0

# Frame Data (60 FPS)
const STARTUP_FRAMES: int = 6
const ACTIVE_FRAMES: int = 3
const RECOVERY_FRAMES: int = 12
const HITSTUN_FRAMES: int = 18

var current_state: State = State.IDLE
var health: int = MAX_HEALTH
var frame_counter: int = 0
var is_facing_right: bool = true

# AI Variables
var is_bot: bool = false
var current_attack_type: String = ""
var ai_move_dir: float = 0.0
var ai_wants_jump: bool = false
var ai_wants_attack: bool = false
var ai_timer: float = 0.0
var ai_reaction_time: float = 0.5

# Node References
# Visuals node holds horizontal flipping components
@onready var visuals = $Visuals
@onready var skeleton = $Visuals/Skeleton2D # Expected to contain PhysicalBone2D setup
@onready var animation_player = $AnimationPlayer
@onready var hurtbox = $Hurtbox
@onready var hitbox = $Visuals/Hitbox
@onready var collision_shape = $CollisionShape2D
@onready var hit_sound = $HitSound
@onready var blood_fx = $BloodFX

func _ready() -> void:
	if Global.is_menu_demo:
		is_bot = true
		Global.bot_difficulty = "boss"
	elif player_index == 2 and Global.is_botfight:
		is_bot = true

	var weapon_id = Global.p1_equipped_weapon if player_index == 1 else Global.p2_equipped_weapon
	for w in Global.store_weapons:
		if w["id"] == weapon_id:
			current_weapon = w
			break
	if current_weapon.is_empty():
		current_weapon = Global.store_weapons[0]

	# Colors - Clothes (T-shirt and Black Jeans)
	var tshirt_color = Color(0.2, 0.4, 0.8) # Team Blue
	if player_index == 2:
		tshirt_color = Color(0.8, 0.2, 0.2) # Team Red

	var jeans_color = Color(0.1, 0.1, 0.15) # Black Jeans
	var skin_color = Color(0.96, 0.82, 0.69)

	# G-Bot Coloring logic
	var body_poly = get_node_or_null("Visuals/Polygons/Body")
	var head_poly = get_node_or_null("Visuals/Polygons/Head")
	var chin_poly = get_node_or_null("Visuals/Polygons/Chin")
	var arm_l_poly = get_node_or_null("Visuals/Polygons/LeftArm")
	var arm_r_poly = get_node_or_null("Visuals/Polygons/RightArm")
	var leg_l_poly = get_node_or_null("Visuals/Polygons/LeftLeg")
	var leg_r_poly = get_node_or_null("Visuals/Polygons/RightLeg")

	if body_poly: body_poly.modulate = tshirt_color
	if arm_l_poly: arm_l_poly.modulate = skin_color
	if arm_r_poly: arm_r_poly.modulate = skin_color
	if leg_l_poly: leg_l_poly.modulate = jeans_color
	if leg_r_poly: leg_r_poly.modulate = jeans_color
	if head_poly: head_poly.modulate = skin_color
	if chin_poly: chin_poly.modulate = skin_color
	
	# Re-add Hair to G-Bot Head Bone if needed
	var gbot_head_bone = get_node_or_null("Visuals/Skeleton2D/Hip/Chest/Head")
	if gbot_head_bone and not gbot_head_bone.has_node("HairSprite"):
		var hair = Sprite2D.new()
		hair.name = "HairSprite"
		hair.texture = preload("res://assets/sprites/hair.svg")
		hair.position = Vector2(0, -50) # Adjust for G-Bot scale
		hair.scale = Vector2(5, 5) # G-Bot visuals are scaled 0.4, but internal bones might be different.
		# Actually Visuals is 0.4.
		hair.set_script(preload("res://scripts/JigglePhysics2D.gd"))
		gbot_head_bone.add_child(hair)
		hair.modulate = Color(0.2, 0.15, 0.1)

	# Reset visuals modulation in case it was set globally before
	visuals.modulate = Color(1, 1, 1, 1)		
	# Configure collision layers and masks to prevent self-hitting
	# Layer 1: P1 Hurtbox, Layer 2: P2 Hurtbox
	if player_index == 1:
		hurtbox.collision_layer = 1
		hurtbox.collision_mask = 0
		hitbox.collision_layer = 0
		hitbox.collision_mask = 2 # P1 hits P2's hurtbox
		is_facing_right = true
	else:
		hurtbox.collision_layer = 2
		hurtbox.collision_mask = 0
		hitbox.collision_layer = 0
		hitbox.collision_mask = 1 # P2 hits P1's hurtbox
		is_facing_right = false
		if visuals:
			var base_scale_y = abs(visuals.scale.y)
			visuals.scale.x = -base_scale_y
			visuals.scale.y = base_scale_y
			
	hitbox.monitoring = false
	if hitbox.has_signal("area_entered"):
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or current_state == State.RAGDOLL:
		return

	if weapon_cooldown > 0.0:
		weapon_cooldown -= delta

	if is_bot and not input_locked:
		_process_ai(delta)

	_update_facing_direction()
	_apply_gravity(delta)
	_handle_state_machine(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _process_ai(delta: float) -> void:
	if not opponent or current_state in [State.HIT, State.KNOCKDOWN, State.DEAD, State.RAGDOLL]:
		ai_move_dir = 0.0
		return
		
	var dist_x = opponent.global_position.x - global_position.x
	var abs_dist_x = abs(dist_x)
	var difficulty = Global.bot_difficulty
	
	if current_state in [State.ATTACK, State.JUMP, State.FLIP_FORWARD, State.FLIP_BACKWARD]:
		ai_move_dir = 0.0 # Maintain momentum but stop active driving while locked
		return # Let current action finish before deciding next
		
	ai_timer -= delta
	if ai_timer > 0:
		return # Waiting for reaction time
		
	# Reset inputs
	ai_move_dir = 0.0
	ai_wants_jump = false
	ai_wants_attack = false
	
	match difficulty:
		"easy":
			ai_reaction_time = 0.5
			if abs_dist_x > 250:
				ai_move_dir = sign(dist_x)
			elif abs_dist_x <= 250 and randf() < 0.6:
				ai_wants_attack = true
		"medium":
			ai_reaction_time = 0.25
			if abs_dist_x > 230:
				ai_move_dir = sign(dist_x)
				if randf() < 0.2: ai_wants_jump = true
			elif abs_dist_x <= 230 and randf() < 0.8:
				ai_wants_attack = true
			else:
				if randf() < 0.1: ai_move_dir = -sign(dist_x) # slight retreat
		"hard":
			ai_reaction_time = 0.1
			if abs_dist_x > 220:
				ai_move_dir = sign(dist_x)
				if opponent.current_state == State.ATTACK and randf() < 0.6:
					ai_wants_jump = true
			elif abs_dist_x <= 220:
				ai_wants_attack = true
			if opponent.current_state in [State.JUMP, State.FLIP_FORWARD]:
				if randf() < 0.7:
					ai_move_dir = -sign(dist_x)
					ai_wants_jump = true
		"boss":
			ai_reaction_time = 0.02
			if abs_dist_x > 200:
				ai_move_dir = sign(dist_x)
				if randf() < 0.5:
					ai_wants_jump = true # This will trigger flips since we are moving
			else:
				ai_wants_attack = true
			
			# Instantly react to player attacks
			if opponent.current_state == State.ATTACK and abs_dist_x < 250:
				if randf() < 0.9:
					ai_wants_jump = true
					ai_move_dir = -sign(dist_x)
					
	# IMPORTANT: Reset timer ONLY if we actually executed an action or changed state
	if ai_wants_attack or ai_wants_jump or ai_move_dir != 0:
		ai_timer = ai_reaction_time

func _update_facing_direction() -> void:
	# Only update facing direction if we are not in locked states
	if current_state in [State.IDLE, State.WALK, State.JUMP, State.FALL]:
		if opponent:
			var direction_to_opponent = sign(opponent.global_position.x - global_position.x)
			if direction_to_opponent != 0:
				var new_facing_right = direction_to_opponent > 0
				if is_facing_right != new_facing_right:
					is_facing_right = new_facing_right
					if visuals:
						# Preserve the base scale while flipping X
						var base_scale_y = abs(visuals.scale.y)
						visuals.scale.x = base_scale_y if is_facing_right else -base_scale_y
						visuals.scale.y = base_scale_y

func _handle_state_machine(delta: float) -> void:
	match current_state:
		State.IDLE:
			_apply_friction(delta)
			_handle_movement_input(delta)
			_handle_jump_input()
			_handle_attack_input()
			
			# Transition to FALL if walking off an edge
			if not is_on_floor():
				_change_state(State.FALL)
			# Transition to WALK if horizontal input is applied
			elif abs(velocity.x) > 0:
				_change_state(State.WALK)

		State.WALK:
			_handle_movement_input(delta)
			_handle_jump_input()
			_handle_attack_input()

			# Transition to FALL if walking off an edge
			if not is_on_floor():
				_change_state(State.FALL)
			# Transition to IDLE if movement stops
			elif velocity.x == 0:
				_change_state(State.IDLE)

		State.JUMP:
			_handle_movement_input(delta, true)
			_handle_attack_input()
			# Transition to FALL at the peak of the jump arc
			if velocity.y >= 0:
				_change_state(State.FALL)
				
		State.FLIP_FORWARD:
			_handle_movement_input(delta, true)
			_handle_attack_input()
			if velocity.y >= 0:
				_change_state(State.FALL)

		State.FLIP_BACKWARD:
			_handle_movement_input(delta, true)
			_handle_attack_input()
			if velocity.y >= 0:
				_change_state(State.FALL)

		State.FALL:
			_handle_movement_input(delta, true)
			_handle_attack_input()
			# Transition to IDLE upon landing on the ground
			if is_on_floor():
				_change_state(State.IDLE)

		State.ATTACK:
			if is_on_floor():
				_apply_friction(delta) # Slow down to a stop during grounded attack
			else:
				_handle_movement_input(delta, true) # Allow air drifting during attack
			_process_attack_frames() # Internal transition to IDLE handled here

		State.HIT:
			_apply_friction(delta)
			_process_hitstun_frames() # Internal transition to IDLE/FALL/DEAD handled here

		State.KNOCKDOWN:
			_apply_friction(delta)
			# Transition to IDLE (Wake-up) once grounded and momentum stops
			if is_on_floor() and abs(velocity.x) < 10:
				_change_state(State.IDLE) # Basic wake-up

func _get_input_direction() -> float:
	if is_bot:
		return ai_move_dir
		
	var move_left_key = KEY_A if player_index == 1 else KEY_LEFT
	var move_right_key = KEY_D if player_index == 1 else KEY_RIGHT
	
	var dir = 0.0
	if Input.is_physical_key_pressed(move_right_key): dir += 1.0
	if Input.is_physical_key_pressed(move_left_key): dir -= 1.0
	return dir

func _handle_movement_input(delta: float, in_air: bool = false) -> void:
	var direction = _get_input_direction() if not input_locked else 0.0
	var accel = AIR_ACCELERATION if in_air else ACCELERATION
	
	# Horizontal movement with acceleration and air resistance
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
	else:
		if in_air:
			velocity.x = move_toward(velocity.x, 0, AIR_RESISTANCE * delta)

func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func _handle_jump_input() -> void:
	if input_locked: return
	var jump_key = KEY_W if player_index == 1 else KEY_UP
	
	var wants_jump = false
	if is_bot:
		wants_jump = ai_wants_jump
	else:
		wants_jump = Input.is_physical_key_pressed(jump_key)
	
	if wants_jump and is_on_floor():
		if is_bot: ai_wants_jump = false # consume
		velocity.y = JUMP_VELOCITY

		# If we have horizontal speed, execute a flip
		if abs(velocity.x) > 0:
			var is_moving_forward = (velocity.x > 0 and is_facing_right) or (velocity.x < 0 and not is_facing_right)
			if is_moving_forward:
				_change_state(State.FLIP_FORWARD)
			else:
				_change_state(State.FLIP_BACKWARD)
		else:
			_change_state(State.JUMP)

func _handle_attack_input() -> void:
	if input_locked: return
	var attack_key = KEY_F if player_index == 1 else KEY_L
	
	var wants_attack = false
	if is_bot:
		wants_attack = ai_wants_attack
	else:
		wants_attack = Input.is_physical_key_pressed(attack_key)
	
	if wants_attack:
		if weapon_cooldown > 0.0:
			if is_bot: ai_wants_attack = false
			return
		if is_bot: ai_wants_attack = false # consume
		_change_state(State.ATTACK)

func _change_state(new_state: State) -> void:
	if current_state == new_state: 
		return
	
	# Exit state logic
	if current_state == State.ATTACK:
		hitbox.set_deferred("monitoring", false)
		
	current_state = new_state
	frame_counter = 0
	
	# Enter state logic (optional animation triggers)
	match current_state:
		State.IDLE:
			_play_animation("idle")
		State.WALK:
			_play_animation("walk")
		State.JUMP:
			_play_animation("jump")
		State.FLIP_FORWARD:
			_play_animation("jump")
			_start_flip_tween(1.0)
		State.FLIP_BACKWARD:
			_play_animation("jump")
			_start_flip_tween(-1.0)
		State.FALL:
			_play_animation("fall")
		State.ATTACK:
			if current_weapon.get("recharge_time", 0.0) > 0.0:
				weapon_cooldown = current_weapon["recharge_time"]
			var attacks = ["attack_hand", "attack_head", "attack_leg"]
			current_attack_type = attacks[randi() % attacks.size()]
			_play_animation(current_attack_type)
			_start_attack_tween(current_attack_type)
		State.HIT:
			_play_animation("hit")
		State.KNOCKDOWN:
			_play_animation("knockdown")
		State.DEAD:
			if animation_player: animation_player.stop()
			_die()
		State.VICTORY:
			_play_animation("victory")
		State.RAGDOLL:
			if animation_player: animation_player.stop()

func _play_animation(anim_name: String) -> void:
	if animation_player:
		# Check if we have a gbot version of the animation
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
		elif animation_player.has_animation("gbot_" + anim_name):
			animation_player.play("gbot_" + anim_name)
		elif anim_name == "walk" and animation_player.has_animation("run"):
			animation_player.play("run") # G-Bot has run instead of walk sometimes? No it has walk.


func _process_attack_frames() -> void:
	# Increment frame based on a 60 FPS assumption
	frame_counter += 1

	var active_start = STARTUP_FRAMES
	var recovery_start = active_start + ACTIVE_FRAMES
	var attack_end = recovery_start + RECOVERY_FRAMES

	if frame_counter == active_start:
		# Hitbox becomes active
		if current_weapon.get("is_ranged", false):
			hitbox.scale.x = 20.0
		else:
			hitbox.scale.x = 2.0 # Make melee wider
		hitbox.set_deferred("monitoring", true)
	elif frame_counter == recovery_start:
		# Hitbox becomes inactive (recovery phase)
		hitbox.set_deferred("monitoring", false)
		hitbox.scale.x = 1.0
	elif frame_counter >= attack_end:
		# End of attack, transition to IDLE
		_change_state(State.IDLE)

var _active_tween: Tween

func _start_attack_tween(attack_type: String) -> void:
	if _active_tween: _active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	
	if attack_type == "attack_hand":
		var arm = get_node_or_null("Visuals/Skeleton2D/Hip/Chest/RightArm")
		var forearm = get_node_or_null("Visuals/Skeleton2D/Hip/Chest/RightArm/RightForearm")
		if arm:
			var orig_rot = arm.rotation
			# Negative rotation points the arm forward
			_active_tween.tween_property(arm, "rotation", orig_rot - deg_to_rad(100), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tween.chain().tween_property(arm, "rotation", orig_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if forearm:
			var orig_rot = forearm.rotation
			_active_tween.parallel().tween_property(forearm, "rotation", orig_rot - deg_to_rad(40), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tween.chain().tween_property(forearm, "rotation", orig_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
	elif attack_type == "attack_head":
		var chest = get_node_or_null("Visuals/Skeleton2D/Hip/Chest")
		var head = get_node_or_null("Visuals/Skeleton2D/Hip/Chest/Head")
		if chest:
			var orig_rot = chest.rotation
			_active_tween.tween_property(chest, "rotation", orig_rot + deg_to_rad(30), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tween.chain().tween_property(chest, "rotation", orig_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if head:
			var orig_rot = head.rotation
			_active_tween.parallel().tween_property(head, "rotation", orig_rot + deg_to_rad(45), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tween.chain().tween_property(head, "rotation", orig_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
	elif attack_type == "attack_leg":
		var leg = get_node_or_null("Visuals/Skeleton2D/Hip/RightLeg")
		var lower_leg = get_node_or_null("Visuals/Skeleton2D/Hip/RightLeg/RightLowerLeg")
		if leg:
			var orig_rot = leg.rotation
			# Negative rotation points the leg forward/up
			_active_tween.tween_property(leg, "rotation", orig_rot - deg_to_rad(100), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tween.chain().tween_property(leg, "rotation", orig_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if lower_leg:
			var orig_rot = lower_leg.rotation
			_active_tween.parallel().tween_property(lower_leg, "rotation", orig_rot + deg_to_rad(30), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tween.chain().tween_property(lower_leg, "rotation", orig_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _start_flip_tween(dir: float) -> void:
	if _active_tween: _active_tween.kill()
	_active_tween = create_tween()
	var visual_node = get_node_or_null("Visuals")
	if visual_node:
		var target_rot = deg_to_rad(360.0 * dir)
		_active_tween.tween_property(visual_node, "rotation", target_rot, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tween.tween_callback(func(): visual_node.rotation = 0.0)

func _process_hitstun_frames() -> void:
	frame_counter += 1
	if frame_counter >= HITSTUN_FRAMES:
		if health <= 0:
			_change_state(State.DEAD)
		elif not is_on_floor():
			_change_state(State.FALL)
		else:
			_change_state(State.IDLE)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Triggered during active frames if overlapping opponent's hurtbox
	var opponent_player = area.owner as Player
	if opponent_player and opponent_player != self:
		# Calculate knockback direction away from attacker
		var knockback_dir = 1.0 if is_facing_right else -1.0
		var dmg = current_weapon.get("damage", 15)
		opponent_player.take_damage(dmg, knockback_dir, current_attack_type)
		# Turn off hitbox to avoid multi-hitting on the same attack
		hitbox.set_deferred("monitoring", false)

func take_damage(amount: int, knockback_dir: float, _attack_type: String = "") -> void:
	if current_state == State.DEAD or current_state == State.RAGDOLL:
		return

	health -= amount

	if Global.is_menu_demo and health <= 0:
		health = MAX_HEALTH # Infinite fighting in demo mode

	health_changed.emit(health)

	if hit_sound and Global.sfx_enabled:
		hit_sound.stream = preload("res://assets/sounds/handpunch.mp3")
		hit_sound.play()
	if blood_fx and Global.blood_fx_enabled:
		blood_fx.direction = Vector2(knockback_dir, -1)
		blood_fx.restart()
		blood_fx.emitting = true

	# Apply strict physics knockback
	velocity.x = KNOCKBACK_VELOCITY_X * knockback_dir
	velocity.y = KNOCKBACK_VELOCITY_Y
	
	if health <= 0:
		health = 0
		_change_state(State.DEAD)
	else:
		_change_state(State.HIT)

func _die() -> void:
	if not dead_signal_emitted:
		dead_signal_emitted = true
		player_died.emit(self)
		
	# Apply a strong final 'death' force to make the ragdoll tumble dramatically
	var death_punch_dir = -1.0 if is_facing_right else 1.0 # Momentum from the hit
	velocity.y = -400.0 # Significant pop up
	velocity.x = 500.0 * death_punch_dir # Dramatic backward tumble
	
	if visuals:
		# Lean the whole body back
		visuals.rotation = -0.5 * death_punch_dir
	
	# Transition into the Ragdoll state
	_change_state(State.RAGDOLL)
	_enable_ragdoll()
	
	# Disable CharacterBody2D logic after a tiny delay or just now
	# If we disable it now, move_and_slide stops.
	# But PhysicalBone2D will start from the current visual positions.
	
	# Shut down base CharacterBody2D control
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)

func _enable_ragdoll() -> void:
	if skeleton:
		_start_physical_bones(skeleton)

func _start_physical_bones(node: Node) -> void:
	if node is PhysicalBone2D:
		node.simulate_physics = true
		node.collision_mask = 1 # Collide with Floor
		# Apply a small initial force to make it tumble
		var push = Vector2(randf_range(-100, 100), randf_range(-50, -150))
		node.apply_central_impulse(push)
	for child in node.get_children():
		_start_physical_bones(child)

func _stop_physical_bones(node: Node) -> void:
	if node is PhysicalBone2D:
		node.simulate_physics = false
		# Reset position to snap back to the skeleton
		node.transform = Transform2D() 
	for child in node.get_children():
		_stop_physical_bones(child)
