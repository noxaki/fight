





extends Node2D
class_name MainLevel

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var camera: Camera2D = $Camera2D

# Arena Bounds for Camera Clamping
@export var arena_left_bound: float = -1000.0
@export var arena_right_bound: float = 1000.0

# Camera Zoom Configuration
@export var min_zoom: float = 0.6 # Wide shot (zoomed out)
@export var max_zoom: float = 1.0 # Max zoom to keep players at 55% height
@export var max_distance_for_zoom: float = 1000.0 # Distance where min zoom applies

@onready var p1_health_bar = $CanvasLayer/UI/HealthBars/P1Health
@onready var p2_health_bar = $CanvasLayer/UI/HealthBars/P2Health
@onready var p1_label = $CanvasLayer/UI/HealthBars/P1Health/P1Label
@onready var p2_label = $CanvasLayer/UI/HealthBars/P2Health/P2Label
@onready var name_input_overlay = $CanvasLayer/UI/NameInputOverlay
@onready var p1_name_input = $CanvasLayer/UI/NameInputOverlay/VBoxContainer/P1NameInput
@onready var p2_name_input = $CanvasLayer/UI/NameInputOverlay/VBoxContainer/P2NameInput
@onready var start_button = $CanvasLayer/UI/NameInputOverlay/VBoxContainer/StartButton
@onready var name_input_back_btn = $CanvasLayer/UI/NameInputOverlay/VBoxContainer/BackButton
@onready var help_overlay = $CanvasLayer/UI/HelpOverlay
@onready var announcer_label = $CanvasLayer/UI/AnnouncerLabel
@onready var main_menu_overlay = $CanvasLayer/UI/MainMenuOverlay
@onready var new_game_btn = $CanvasLayer/UI/MainMenuOverlay/VBoxContainer/StartNewGameButton
@onready var botfight_btn = $CanvasLayer/UI/MainMenuOverlay/VBoxContainer/BotfightButton
@onready var store_btn = $CanvasLayer/UI/MainMenuOverlay/VBoxContainer/StoreButton
@onready var settings_btn = $CanvasLayer/UI/MainMenuOverlay/VBoxContainer/SettingsButton
@onready var quit_btn = $CanvasLayer/UI/MainMenuOverlay/VBoxContainer/QuitButton

@onready var info_overlay = $CanvasLayer/UI/InfoOverlay
@onready var info_label = $CanvasLayer/UI/InfoOverlay/VBox/InfoLabel
@onready var close_info_btn = $CanvasLayer/UI/InfoOverlay/VBox/CloseInfoButton

@onready var bot_diff_overlay = $CanvasLayer/UI/BotDifficultyOverlay
@onready var bot_easy_btn = $CanvasLayer/UI/BotDifficultyOverlay/VBoxContainer/EasyButton
@onready var bot_medium_btn = $CanvasLayer/UI/BotDifficultyOverlay/VBoxContainer/MediumButton
@onready var bot_hard_btn = $CanvasLayer/UI/BotDifficultyOverlay/VBoxContainer/HardButton
@onready var bot_boss_btn = $CanvasLayer/UI/BotDifficultyOverlay/VBoxContainer/BossButton
@onready var bot_back_btn = $CanvasLayer/UI/BotDifficultyOverlay/VBoxContainer/BackButton

@onready var settings_overlay = $CanvasLayer/UI/SettingsOverlay
@onready var screams_check = $CanvasLayer/UI/SettingsOverlay/VBox/ScreamsCheck
@onready var blood_check = $CanvasLayer/UI/SettingsOverlay/VBox/BloodCheck
@onready var sfx_check = $CanvasLayer/UI/SettingsOverlay/VBox/SFXCheck
@onready var settings_back_btn = $CanvasLayer/UI/SettingsOverlay/VBox/BackButton

@onready var coin_display = $CanvasLayer/UI/CoinDisplay

@onready var audio_3 = $Audio/Voice3
@onready var audio_2 = $Audio/Voice2
@onready var audio_1 = $Audio/Voice1
@onready var audio_fight = $Audio/VoiceFight
@onready var audio_p1_wins = $Audio/VoiceP1Wins
@onready var audio_p2_wins = $Audio/VoiceP2Wins

func _ready() -> void:
	# Link the players to each other so they can track facing directions
	camera.make_current()
	if player1 and player2:
		if player1.has_method("set"): player1.opponent = player2
		if player2.has_method("set"): player2.opponent = player1
		
		# Set Health Bar Colors
		var p1_sb = StyleBoxFlat.new()
		p1_sb.bg_color = Color(0.4, 0.6, 1.0)
		p1_health_bar.add_theme_stylebox_override("fill", p1_sb)
		
		var p2_sb = StyleBoxFlat.new()
		p2_sb.bg_color = Color(1.0, 0.4, 0.4)
		p2_health_bar.add_theme_stylebox_override("fill", p2_sb)
		
		# Connect health signals to UI
		if player1.has_signal("health_changed"): 
			p1_health_bar.max_value = player1.MAX_HEALTH
			p1_health_bar.value = player1.health
			player1.health_changed.connect(func(val): p1_health_bar.value = val)
		if player2.has_signal("health_changed"): 
			p2_health_bar.max_value = player2.MAX_HEALTH
			p2_health_bar.value = player2.health
			player2.health_changed.connect(func(val): p2_health_bar.value = val)

		if player1.has_signal("player_died"): player1.player_died.connect(_on_player_died)
		if player2.has_signal("player_died"): player2.player_died.connect(_on_player_died)
		
	# Connect Menu Buttons
	if new_game_btn: new_game_btn.pressed.connect(_on_new_game_pressed)
	if botfight_btn: botfight_btn.pressed.connect(_on_botfight_pressed)
	if store_btn: store_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Store.tscn"))
	if settings_btn: settings_btn.pressed.connect(_on_settings_pressed)
	if quit_btn: quit_btn.pressed.connect(_on_quit_pressed)
	
	if settings_back_btn: settings_back_btn.pressed.connect(func(): settings_overlay.visible = false; main_menu_overlay.visible = true)
	
	# Connect Checkboxes
	if screams_check:
		screams_check.button_pressed = Global.screams_enabled
		screams_check.toggled.connect(func(v): 
			Global.screams_enabled = v
			if not v:
				if audio_1: audio_1.stop()
				if audio_2: audio_2.stop()
				if audio_3: audio_3.stop()
				if audio_fight: audio_fight.stop()
				if audio_p1_wins: audio_p1_wins.stop()
				if audio_p2_wins: audio_p2_wins.stop()
		)
	if blood_check:
		blood_check.button_pressed = Global.blood_fx_enabled
		blood_check.toggled.connect(func(v): Global.blood_fx_enabled = v)
	if sfx_check:
		sfx_check.button_pressed = Global.sfx_enabled
		sfx_check.toggled.connect(func(v): Global.sfx_enabled = v)
	
	if start_button: start_button.pressed.connect(_on_start_button_pressed)
	if name_input_back_btn: name_input_back_btn.pressed.connect(func():
		name_input_overlay.visible = false
		main_menu_overlay.visible = true
	)
	if close_info_btn: close_info_btn.pressed.connect(func(): info_overlay.visible = false)
	
	if bot_easy_btn: bot_easy_btn.pressed.connect(func(): _start_bot_game("easy"))
	if bot_medium_btn: bot_medium_btn.pressed.connect(func(): _start_bot_game("medium"))
	if bot_hard_btn: bot_hard_btn.pressed.connect(func(): _start_bot_game("hard"))
	if bot_boss_btn: bot_boss_btn.pressed.connect(func(): _start_bot_game("boss"))
	if bot_back_btn: bot_back_btn.pressed.connect(func(): 
		bot_diff_overlay.visible = false
		main_menu_overlay.visible = true
	)
		
	# Initial Flow
	if Global.is_menu_demo:
		Engine.time_scale = 0.3
		main_menu_overlay.visible = true
		player1.input_locked = false
		player2.input_locked = false
		
		# Hide UI in demo
		p1_health_bar.visible = false
		p2_health_bar.visible = false
		if coin_display: coin_display.visible = false
	elif Global.is_botfight:
		Engine.time_scale = 1.0
		if coin_display: coin_display.visible = true
		_setup_names()
		_start_match_sequence()
	elif Global.names_set:
		Global.is_botfight = false # Ensure botfight is false if coming from New Game
		Engine.time_scale = 1.0
		if coin_display: coin_display.visible = false
		_setup_names()
		_start_match_sequence()
	else:
		Engine.time_scale = 1.0
		if coin_display: coin_display.visible = false
		player1.input_locked = true
		player2.input_locked = true
		main_menu_overlay.visible = true

func _on_new_game_pressed() -> void:
	main_menu_overlay.visible = false
	name_input_overlay.visible = true

func _setup_names() -> void:
	if p1_label: p1_label.text = "1 " + Global.p1_name
	if p2_label: p2_label.text = "2 " + Global.p2_name

func _on_start_button_pressed() -> void:
	if p1_name_input.text.strip_edges() != "":
		Global.p1_name = p1_name_input.text.strip_edges()
	if p2_name_input.text.strip_edges() != "":
		Global.p2_name = p2_name_input.text.strip_edges()
		
	Global.is_menu_demo = false
	Global.is_botfight = false
	Global.names_set = true
	name_input_overlay.visible = false
	get_tree().reload_current_scene()

func _start_match_sequence() -> void:
	if Global.is_menu_demo:
		player1.input_locked = false
		player2.input_locked = false
		return
		
	player1.input_locked = true
	player2.input_locked = true
	
	announcer_label.text = "3"
	if Global.screams_enabled: audio_3.play()
	await get_tree().create_timer(1.0).timeout
	
	announcer_label.text = "2"
	if Global.screams_enabled: audio_2.play()
	await get_tree().create_timer(1.0).timeout
	
	announcer_label.text = "1"
	if Global.screams_enabled: audio_1.play()
	await get_tree().create_timer(1.0).timeout
	
	announcer_label.text = "FIGHT!"
	if Global.screams_enabled: audio_fight.play()
	
	player1.input_locked = false
	player2.input_locked = false
	
	await get_tree().create_timer(1.0).timeout
	announcer_label.text = ""

func _on_player_died(dead_player: Node) -> void:
	if Global.is_menu_demo:
		# Just resurrect them for infinite demo fighting
		player1.health = player1.MAX_HEALTH
		player2.health = player2.MAX_HEALTH
		player1.health_changed.emit(player1.health)
		player2.health_changed.emit(player2.health)
		player1._change_state(player1.State.IDLE)
		player2._change_state(player2.State.IDLE)
		player1.global_position = Vector2(-200, 250)
		player2.global_position = Vector2(200, 250)
		player1.dead_signal_emitted = false
		player2.dead_signal_emitted = false
		
		# Re-enable physics and collision if they died
		for p in [player1, player2]:
			p.set_physics_process(true)
			p.collision_shape.set_deferred("disabled", false)
			p.hurtbox.set_deferred("monitoring", true)
			p.hurtbox.set_deferred("monitorable", true)
			if p.skeleton:
				for child in p.skeleton.get_children():
					p._stop_physical_bones(child)
		return
		
	player1.input_locked = true
	player2.input_locked = true
	
	# Identify Winner safely
	var dead_index = dead_player.get("player_index")
	var winner_index = 1 if dead_index == 2 else 2
	var winner_node = player1 if winner_index == 1 else player2
	var winner_name = Global.p1_name if winner_index == 1 else Global.p2_name
	
	announcer_label.text = winner_name + " Wins!"
	
	# Calculate Reward - ONLY for Botfight
	if Global.is_botfight:
		if winner_index == 1:
			var reward = 0
			match Global.bot_difficulty:
				"easy": reward = 2
				"medium": reward = 3
				"hard": reward = 4
				"boss": reward = 5
			
			Global.p1_coins += reward
			announcer_label.text += "\n+" + str(reward) + " Coins!"
	
	if Global.screams_enabled:
		if winner_index == 1:
			audio_p1_wins.play()
		else:
			audio_p2_wins.play()
	
	if winner_node.has_method("_change_state"): winner_node._change_state(Player.State.VICTORY)
		
	await get_tree().create_timer(4.0).timeout
	get_tree().reload_current_scene()

func _on_botfight_pressed() -> void:
	main_menu_overlay.visible = false
	bot_diff_overlay.visible = true

func _on_settings_pressed() -> void:
	main_menu_overlay.visible = false
	settings_overlay.visible = true

func _start_bot_game(difficulty: String) -> void:
	Global.is_menu_demo = false
	Global.is_botfight = true
	Global.bot_difficulty = difficulty
	Global.p2_name = "BOT (" + difficulty.capitalize() + ")"
	Global.names_set = false # Use this to distinguish from New Game flow
	if Global.p1_name == "Player 1":
		Global.p1_name = "Player" # Default fallback
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_info(msg: String) -> void:
	info_label.text = msg
	info_overlay.visible = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			help_overlay.visible = !help_overlay.visible
		elif event.keycode == KEY_ESCAPE:
			if info_overlay.visible:
				info_overlay.visible = false
			elif name_input_overlay.visible or bot_diff_overlay.visible or settings_overlay.visible:
				name_input_overlay.visible = false
				bot_diff_overlay.visible = false
				settings_overlay.visible = false
				main_menu_overlay.visible = true
				get_tree().paused = true
			else:
				main_menu_overlay.visible = !main_menu_overlay.visible
				get_tree().paused = main_menu_overlay.visible

func _process(_delta: float) -> void:
	_handle_dynamic_camera()
	_check_falling()
	_update_coin_display()

func _update_coin_display() -> void:
	if coin_display:
		coin_display.text = "Coins: " + str(Global.p1_coins)

func _check_falling() -> void:
	if get_tree().paused: return
	if player1.input_locked or player2.input_locked: return
	
	if player1.global_position.y > 600:
		_on_player_died(player1)
	elif player2.global_position.y > 600:
		_on_player_died(player2)

func _handle_dynamic_camera() -> void:
	if not player1 or not player2 or not camera:
		return
		
	# 1. Calculate Midpoint between players
	var p1_pos = player1.global_position
	var p2_pos = player2.global_position
	var midpoint = (p1_pos + p2_pos) / 2.0
	
	# 2. Dynamic Zoom based on distance
	# We want to ensure both players AND their full height are visible.
	var distance_x = abs(p1_pos.x - p2_pos.x)
	var distance_y = abs(p1_pos.y - p2_pos.y)
	
	# Horizontal zoom requirement
	var margin_x = 300.0
	var zoom_x = get_viewport_rect().size.x / (distance_x + margin_x)
	
	# Vertical zoom requirement (players are ~240px tall)
	var margin_y = 350.0
	var zoom_y = get_viewport_rect().size.y / (distance_y + margin_y)

	var target_zoom_val = clamp(min(zoom_x, zoom_y), min_zoom, max_zoom)
	camera.zoom = camera.zoom.lerp(Vector2(target_zoom_val, target_zoom_val), 0.1)

	# 3. Ground-Anchored Y Positioning
	# The ground surface is at Y=250.
	# We'll aim to keep some floor visible.
	var viewport_height = get_viewport_rect().size.y
	var target_camera_y = 300.0 - (viewport_height / 2.0 / camera.zoom.y)

	# If players jump high, we might need to lift the camera slightly to keep them in view
	var highest_player_y = min(p1_pos.y, p2_pos.y) - 220.0 # Head headroom
	var top_of_screen_y = target_camera_y - (viewport_height / 2.0 / camera.zoom.y)
	
	if highest_player_y < top_of_screen_y:
		target_camera_y -= (top_of_screen_y - highest_player_y)
	
	# 4. Final Midpoint and Clamping
	midpoint.y = target_camera_y
	
	var half_screen_width = get_viewport_rect().size.x / 2.0 / camera.zoom.x
	var min_x = arena_left_bound + half_screen_width
	var max_x = arena_right_bound - half_screen_width
	
	if min_x < max_x:
		midpoint.x = clamp(midpoint.x, min_x, max_x)
	else:
		midpoint.x = (arena_left_bound + arena_right_bound) / 2.0
	
	camera.global_position = midpoint
