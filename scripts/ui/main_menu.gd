extends Control

## Main Menu UI - thin layer, delegates to GameStore

@onready var voyage_button: Button = $VBoxContainer/VoyageButton
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var vnp_game_button: Button = $VBoxContainer/VNPGameButton
@onready var colony_sim_button: Button = $VBoxContainer/ColonySimButton
@onready var fcw_button: Button = $VBoxContainer/FCWButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	voyage_button.pressed.connect(_on_voyage_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	vnp_game_button.pressed.connect(_on_vnp_game_pressed)
	colony_sim_button.pressed.connect(_on_colony_sim_pressed)
	fcw_button.pressed.connect(_on_fcw_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_voyage_pressed():
	get_tree().change_scene_to_file("res://scenes/voyage/voyage_map.tscn")

func _on_vnp_game_pressed():
	get_tree().change_scene_to_file("res://scenes/vnp/vnp_main.tscn")

func _on_colony_sim_pressed():
	get_tree().change_scene_to_file("res://scenes/colonysim/colony_sim.tscn")

func _on_fcw_pressed():
	get_tree().change_scene_to_file("res://scenes/fcw/fcw_main.tscn")

func _on_new_game_pressed():
	GameStore.start_new_game()
	get_tree().change_scene_to_file("res://scenes/phases/ship_building.tscn")

func _on_load_pressed():
	if GameStore.load_game(0):
		var phase = GameStore.get_phase()
		match phase:
			GameTypes.GamePhase.SHIP_BUILDING:
				get_tree().change_scene_to_file("res://scenes/phases/ship_building.tscn")
			GameTypes.GamePhase.TRAVEL_TO_MARS:
				get_tree().change_scene_to_file("res://scenes/phases/travel.tscn")
			GameTypes.GamePhase.MARS_BASE:
				get_tree().change_scene_to_file("res://scenes/phases/mars_base.tscn")
			GameTypes.GamePhase.TRAVEL_TO_EARTH:
				get_tree().change_scene_to_file("res://scenes/phases/return_journey.tscn")
			GameTypes.GamePhase.GAME_OVER:
				get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
			_:
				get_tree().change_scene_to_file("res://scenes/phases/ship_building.tscn")

func _on_settings_pressed():
	pass  # TODO: Settings menu

func _on_quit_pressed():
	get_tree().quit()
