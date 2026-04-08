extends Node

var p1_name: String = "Player 1"
var p2_name: String = "Player 2"
var names_set: bool = false

var is_botfight: bool = false
var bot_difficulty: String = "medium"

var is_menu_demo: bool = true

var p1_coins: int = 0

var screams_enabled: bool = true
var blood_fx_enabled: bool = true
var sfx_enabled: bool = true

# --- STORE DATA ---
var store_weapons: Array = [
	{"id": "punch", "name": "Punch", "cost": 0, "damage": 100, "is_ranged": false},
	{"id": "knife", "name": "Knife", "cost": 200, "damage": 150, "is_ranged": false},
	{"id": "bat", "name": "Bat", "cost": 330, "damage": 180, "is_ranged": false},
	{"id": "sword", "name": "Sword", "cost": 520, "damage": 250, "is_ranged": false},
	{"id": "baseball_bat", "name": "Baseball Bat", "cost": 700, "damage": 280, "is_ranged": false},
	{"id": "champagne_bottle", "name": "Champagne Bottle", "cost": 1000, "damage": 350, "is_ranged": false},
	{"id": "king_sword", "name": "King Sword", "cost": 1500, "damage": 450, "is_ranged": false},
	{"id": "golden_knife", "name": "Golden Knife", "cost": 10000, "damage": 550, "is_ranged": false},
	{"id": "golden_sword", "name": "Golden Sword", "cost": 20000, "damage": 750, "is_ranged": false},
	{"id": "old_pirate_pistol", "name": "Old Pirate Pistol", "cost": 50000, "damage": 1000, "is_ranged": true, "recharge_time": 5.0}
]

var store_clothes: Array = [
	{"id": "default", "name": "Default Clothes", "cost": 0}
]

var p1_unlocked_weapons: Array = ["punch"]
var p2_unlocked_weapons: Array = ["punch"]
var p1_equipped_weapon: String = "punch"
var p2_equipped_weapon: String = "punch"

var p1_unlocked_clothes: Array = ["default"]
var p2_unlocked_clothes: Array = ["default"]
var p1_equipped_clothes: String = "default"
var p2_equipped_clothes: String = "default"
