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

	# Connect EVA signals from store to ship_view
	if store and ship_view:
		store.eva_triggered.connect(_on_eva_triggered)
		store.eva_drift_triggered.connect(_on_eva_drift_triggered)
		store.crew_gather.connect(_on_crew_gather)
		print("[UI] EVA and crew signals connected")

	# Connect EVA repair signal to update exterior surfaces
	if ship_view and ship_systems:
		ship_view.eva_repair_completed.connect(_on_eva_repair_completed)
		print("[UI] EVA repair signal connected")

	# Connect speed buttons
	if speed_controls:
		var slow_btn = speed_controls.get_node_or_null("Slow")
		var normal_btn = speed_controls.get_node_or_null("Normal")
		var fast_btn = speed_controls.get_node_or_null("Fast")
		var ludicrous_btn = speed_controls.get_node_or_null("Ludicrous")
		var pause_btn = speed_controls.get_node_or_null("Pause")
		var back_btn = speed_controls.get_node_or_null("Back")

		if slow_btn:
			slow_btn.pressed.connect(_on_slow)
		if normal_btn:
			normal_btn.pressed.connect(_on_normal)
		if fast_btn:
			fast_btn.pressed.connect(_on_fast)
		if ludicrous_btn:
			ludicrous_btn.pressed.connect(_on_ludicrous)
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

func _on_ludicrous() -> void:
	if controller:
		controller.set_speed_ludicrous()
	if hud:
		hud.update_speed_display("LUDICROUS")

func _on_pause() -> void:
	if controller:
		controller.toggle_pause()
	# TODO: update pause button text based on state

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ============================================================================
# DEBUG INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Shift+E = Force trigger EVA for testing
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E and event.shift_pressed:
			print("[EVA-DEBUG] ========== MANUAL EVA TRIGGER (Shift+E) ==========")
			_on_eva_triggered("engineer", "engine")

# ============================================================================
# EVA EVENT HANDLERS
# ============================================================================

func _on_eva_triggered(crew_role: String, target: String) -> void:
	## Trigger visual EVA when event resolves
	print("[EVA-DEBUG] _on_eva_triggered called: crew=%s, target=%s" % [crew_role, target])
	print("[EVA-DEBUG] ship_view is null: %s" % (ship_view == null))

	if not ship_view:
		push_error("[EVA-DEBUG] CRITICAL: ship_view is NULL! Cannot start EVA.")
		return

	# Map target string to waypoint
	var ShipNav = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_navigation.gd")
	var waypoint = ShipNav.Waypoint.EXTERIOR_ENGINE
	match target:
		"engine": waypoint = ShipNav.Waypoint.EXTERIOR_ENGINE
		"antenna": waypoint = ShipNav.Waypoint.EXTERIOR_ANTENNA
		"solar": waypoint = ShipNav.Waypoint.EXTERIOR_SOLAR

	print("[EVA-DEBUG] Mapped target '%s' to waypoint %d" % [target, waypoint])
	print("[EVA-DEBUG] Calling ship_view.start_eva('%s', %d)..." % [crew_role, waypoint])
	ship_view.start_eva(crew_role, waypoint)
	print("[EVA-DEBUG] ship_view.start_eva() call completed")

func _on_eva_drift_triggered(crew_role: String) -> void:
	## Trigger drift when crew member flies off during EVA
	if ship_view and ship_view.eva_ctrl:
		ship_view.eva_ctrl._start_drift(crew_role)
		print("[EVA] %s drifted on tether!" % crew_role.capitalize())

func _on_crew_gather(location: String) -> void:
	## Move all crew to gather at a location (for events like movie night)
	if not ship_view:
		return

	var ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
	var room_type = ShipTypes.RoomType.QUARTERS  # Default

	match location:
		"quarters": room_type = ShipTypes.RoomType.QUARTERS
		"cargo_bay", "cargo": room_type = ShipTypes.RoomType.CARGO_BAY
		"bridge": room_type = ShipTypes.RoomType.BRIDGE
		"engineering": room_type = ShipTypes.RoomType.ENGINEERING
		"medical": room_type = ShipTypes.RoomType.MEDICAL

	print("[CREW] All crew gathering at %s" % location)

	# Send all crew to the gathering location
	for role in ship_view.crew:
		ship_view.send_crew_to_room(role, room_type, false)

func _on_eva_repair_completed(waypoint: int) -> void:
	## Repair the exterior surface when EVA completes
	if ship_systems:
		ship_systems.repair_exterior_by_waypoint(waypoint)
		print("[UI] Exterior surface repaired via EVA")
