extends Control

## Main Menu UI - thin layer, delegates to GameStore

@onready var mot_button: Button = $VBoxContainer/MOTButton
@onready var mot_phase2_button: Button = $VBoxContainer/MOTPhase2Button
@onready var ship_auto_button: Button = $VBoxContainer/ShipAutoButton
@onready var ship_test_button: Button = $VBoxContainer/ShipTestButton
@onready var voyage_button: Button = $VBoxContainer/VoyageButton
@onready var vnp_game_button: Button = $VBoxContainer/VNPGameButton
@onready var mcs_button: Button = $VBoxContainer/MCSButton
@onready var fcw_button: Button = $VBoxContainer/FCWButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	mot_button.pressed.connect(_on_mot_pressed)
	mot_phase2_button.pressed.connect(_on_mot_phase2_pressed)
	ship_auto_button.pressed.connect(_on_ship_auto_pressed)
	ship_test_button.pressed.connect(_on_ship_test_pressed)
	voyage_button.pressed.connect(_on_voyage_pressed)
	vnp_game_button.pressed.connect(_on_vnp_game_pressed)
	mcs_button.pressed.connect(_on_mcs_pressed)
	fcw_button.pressed.connect(_on_fcw_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_mot_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_odyssey_trek/phase1_main.tscn")

func _on_mot_phase2_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_odyssey_trek/phase2_v2.tscn")

func _on_ship_auto_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_odyssey_trek/ship_cutaway.tscn")

func _on_ship_test_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_odyssey_trek/ship_test.tscn")

func _on_voyage_pressed():
	get_tree().change_scene_to_file("res://scenes/voyage/voyage_map.tscn")

func _on_vnp_game_pressed():
	get_tree().change_scene_to_file("res://scenes/von_neumann_probe/vnp_main.tscn")

func _on_mcs_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_colony_sim/mcs.tscn")

func _on_fcw_pressed():
	get_tree().change_scene_to_file("res://scenes/first_contact_war/fcw_main.tscn")

func _on_quit_pressed():
	get_tree().quit()
