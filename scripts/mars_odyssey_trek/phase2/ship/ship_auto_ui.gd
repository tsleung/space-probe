extends Node

## UI controller for ship auto scene - handles speed controls and navigation

@onready var game_controller = $"../GameController"
@onready var hud = $"../HUD"
@onready var speed_controls = $"../SpeedControls"

func _ready() -> void:
	# Wait a frame for nodes to initialize
	await get_tree().process_frame

	# Connect speed buttons
	var speed1 = speed_controls.get_node_or_null("Speed1")
	var speed2 = speed_controls.get_node_or_null("Speed2")
	var speed5 = speed_controls.get_node_or_null("Speed5")
	var pause_btn = speed_controls.get_node_or_null("Pause")
	var restart_btn = speed_controls.get_node_or_null("Restart")
	var back_btn = speed_controls.get_node_or_null("Back")

	if speed1:
		speed1.pressed.connect(_on_speed_1)
	if speed2:
		speed2.pressed.connect(_on_speed_2)
	if speed5:
		speed5.pressed.connect(_on_speed_5)
	if pause_btn:
		pause_btn.pressed.connect(_on_pause)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart)
	if back_btn:
		back_btn.pressed.connect(_on_back)

func _on_speed_1() -> void:
	if game_controller:
		game_controller.set_speed(1.0)
		if not game_controller.is_game_running():
			game_controller.start_game()
	if hud:
		hud.update_speed_display(1.0)

func _on_speed_2() -> void:
	if game_controller:
		game_controller.set_speed(2.0)
		if not game_controller.is_game_running():
			game_controller.start_game()
	if hud:
		hud.update_speed_display(2.0)

func _on_speed_5() -> void:
	if game_controller:
		game_controller.set_speed(5.0)
		if not game_controller.is_game_running():
			game_controller.start_game()
	if hud:
		hud.update_speed_display(5.0)

func _on_pause() -> void:
	if game_controller:
		if game_controller.is_game_running():
			game_controller.stop_game()
		else:
			game_controller.start_game()

func _on_restart() -> void:
	# Reload the scene
	get_tree().reload_current_scene()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
