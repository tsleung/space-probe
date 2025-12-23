extends Control

## Main Menu UI - thin layer, delegates to GameStore

@onready var mot_button: Button = $VBoxContainer/MOTButton
@onready var mot_phase2_button: Button = $VBoxContainer/MOTPhase2Button
@onready var vnp_game_button: Button = $VBoxContainer/VNPGameButton
@onready var mcs_button: Button = $VBoxContainer/MCSButton
@onready var fcw_button: Button = $VBoxContainer/FCWButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	mot_button.pressed.connect(_on_mot_pressed)
	mot_phase2_button.pressed.connect(_on_mot_phase2_pressed)
	vnp_game_button.pressed.connect(_on_vnp_game_pressed)
	mcs_button.pressed.connect(_on_mcs_pressed)
	fcw_button.pressed.connect(_on_fcw_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_mot_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_odyssey_trek/phase1_main.tscn")

func _on_mot_phase2_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_odyssey_trek/phase2_integrated.tscn")

func _on_vnp_game_pressed():
	get_tree().change_scene_to_file("res://scenes/von_neumann_probe/vnp_main.tscn")

func _on_mcs_pressed():
	get_tree().change_scene_to_file("res://scenes/mars_colony_sim/mcs.tscn")

func _on_fcw_pressed():
	get_tree().change_scene_to_file("res://scenes/first_contact_war/fcw_main.tscn")

func _on_quit_pressed():
	get_tree().quit()
