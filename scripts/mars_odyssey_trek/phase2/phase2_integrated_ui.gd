extends Node

## UI controller for Phase2 integrated scene
## Wires up speed controls and navigation

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

@onready var store = $"../Phase2Store"
@onready var controller = $"../Phase2Controller"
@onready var hud = $"../HUD"
@onready var speed_controls = $"../SpeedControls"
@onready var ship_systems = $"../ShipSystemsIntegration"
@onready var crisis_controller = $"../CrisisController"
@onready var effects = $"../Effects"
@onready var ship_view = $"../ShipView"

func _ready() -> void:
	await get_tree().process_frame

	# Connect controller to store
	if controller and store:
		controller.connect_to_store(store)

	# Wire up ship systems integration
	if controller and ship_systems:
		controller.setup_ship_systems(ship_systems, crisis_controller, effects, ship_view)
		print("[UI] Ship systems wired to controller")

	# Connect speed buttons
	if speed_controls:
		var slow_btn = speed_controls.get_node_or_null("Slow")
		var normal_btn = speed_controls.get_node_or_null("Normal")
		var fast_btn = speed_controls.get_node_or_null("Fast")
		var pause_btn = speed_controls.get_node_or_null("Pause")
		var back_btn = speed_controls.get_node_or_null("Back")

		if slow_btn:
			slow_btn.pressed.connect(_on_slow)
		if normal_btn:
			normal_btn.pressed.connect(_on_normal)
		if fast_btn:
			fast_btn.pressed.connect(_on_fast)
		if pause_btn:
			pause_btn.pressed.connect(_on_pause)
		if back_btn:
			back_btn.pressed.connect(_on_back)

func _on_slow() -> void:
	if controller:
		controller.set_speed_slow()
	if hud:
		hud.update_speed_display("Slow")

func _on_normal() -> void:
	if controller:
		controller.set_speed_normal()
	if hud:
		hud.update_speed_display("Normal")

func _on_fast() -> void:
	if controller:
		controller.set_speed_fast()
	if hud:
		hud.update_speed_display("Fast")

func _on_pause() -> void:
	if controller:
		controller.toggle_pause()
	# TODO: update pause button text based on state

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
