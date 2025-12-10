extends Control

## Main Menu UI - thin layer, delegates to GameStore

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

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
			_:
				get_tree().change_scene_to_file("res://scenes/phases/ship_building.tscn")

func _on_settings_pressed():
	pass  # TODO: Settings menu

func _on_quit_pressed():
	get_tree().quit()
