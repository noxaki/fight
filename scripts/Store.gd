extends Control

@onready var item_list = $VBoxContainer/ScrollContainer/ItemList
@onready var buy_button = $VBoxContainer/HBoxContainer/BuyButton
@onready var equip_p1_button = $VBoxContainer/HBoxContainer/EquipP1Button
@onready var equip_p2_button = $VBoxContainer/HBoxContainer/EquipP2Button
@onready var back_button = $VBoxContainer/BackButton
@onready var coins_label = $VBoxContainer/CoinsLabel

var selected_item_idx: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	
	back_button.pressed.connect(_on_back_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	equip_p1_button.pressed.connect(_on_equip_p1_pressed)
	equip_p2_button.pressed.connect(_on_equip_p2_pressed)
	item_list.item_selected.connect(_on_item_selected)
	
	_refresh_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()

func _refresh_ui() -> void:
	item_list.clear()
	coins_label.text = "Coins: %d\n(Earn more by winning Botfights!)" % [Global.p1_coins]
	
	for i in range(Global.store_weapons.size()):
		var w = Global.store_weapons[i]
		var item_text = "%s - %d coins - Dmg: %d" % [w.name, w.cost, w.damage]
		if w.id in Global.p1_unlocked_weapons:
			item_text += " [Owned]"
		item_list.add_item(item_text)
		
	_update_buttons()

func _on_item_selected(index: int) -> void:
	selected_item_idx = index
	_update_buttons()

func _update_buttons() -> void:
	if selected_item_idx < 0 or selected_item_idx >= Global.store_weapons.size():
		buy_button.disabled = true
		equip_p1_button.disabled = true
		equip_p2_button.disabled = true
		return
		
	var w = Global.store_weapons[selected_item_idx]
	var owns = w.id in Global.p1_unlocked_weapons
	
	buy_button.disabled = owns or Global.p1_coins < w.cost
	equip_p1_button.disabled = not owns
	equip_p2_button.disabled = not owns
	
	equip_p1_button.text = "P1 Equipped" if Global.p1_equipped_weapon == w.id else "Equip P1"
	equip_p2_button.text = "P2 Equipped" if Global.p2_equipped_weapon == w.id else "Equip P2"

func _on_buy_pressed() -> void:
	var w = Global.store_weapons[selected_item_idx]
	if not (w.id in Global.p1_unlocked_weapons) and Global.p1_coins >= w.cost:
		Global.p1_coins -= w.cost
		Global.p1_unlocked_weapons.append(w.id)
		# Automatically unlock for P2 as well, using the shared coin pool
		if not (w.id in Global.p2_unlocked_weapons):
			Global.p2_unlocked_weapons.append(w.id)
		
	_refresh_ui()

func _on_equip_p1_pressed() -> void:
	var w = Global.store_weapons[selected_item_idx]
	Global.p1_equipped_weapon = w.id
	_refresh_ui()

func _on_equip_p2_pressed() -> void:
	var w = Global.store_weapons[selected_item_idx]
	Global.p2_equipped_weapon = w.id
	_refresh_ui()

func _on_back_pressed() -> void:
	Global.is_menu_demo = true
	Global.is_botfight = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
