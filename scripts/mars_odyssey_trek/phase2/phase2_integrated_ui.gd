extends Node

## UI controller for Phase2 integrated scene
## Wires up speed controls and navigation

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")
const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")
const TaskManager = preload("res://scripts/mars_odyssey_trek/phase2/tasks/task_manager.gd")
const TaskPanel = preload("res://scripts/mars_odyssey_trek/phase2/ui/task_panel.gd")
const ShipNavigation = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_navigation.gd")

@onready var store = $"../Phase2Store"
@onready var controller = $"../Phase2Controller"
@onready var hud = $"../HUD"
@onready var speed_controls = $"../SpeedControls"
@onready var ship_systems = $"../ShipSystemsIntegration"
@onready var crisis_controller = $"../CrisisController"
@onready var effects = $"../Effects"
@onready var ship_view = $"../ShipView"

# Task tracking
var task_manager: TaskManager
var task_panel: TaskPanel

func _ready() -> void:
	await get_tree().process_frame

	# Initialize task tracking system
	_setup_task_system()

	# Connect controller to store
	if controller and store:
		controller.connect_to_store(store)

	# Wire up ship systems integration
	if controller and ship_systems:
		controller.setup_ship_systems(ship_systems, crisis_controller, effects, ship_view)
		print("[UI] Ship systems wired to controller")

	# Wire up task manager to controller for crew-aware AI
	if controller and task_manager:
		controller.setup_task_manager(task_manager)
		print("[UI] Task manager wired to controller for crew-aware AI")

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

# ============================================================================
# TASK SYSTEM
# ============================================================================

func _setup_task_system() -> void:
	## Initialize task manager and panel
	# Create task manager
	task_manager = TaskManager.new()
	add_child(task_manager)

	# Setup spinner parent (ship_view for in-world spinners)
	if ship_view:
		task_manager.setup(ship_view)

	# Connect task_penalty_applied signal to dispatch action to store
	task_manager.task_penalty_applied.connect(_on_task_penalty_applied)

	# Create task panel UI (positioned at right side of screen)
	task_panel = TaskPanel.new()
	# Position relative to viewport - use a fixed position that works
	var viewport_size = get_viewport().get_visible_rect().size
	task_panel.position = Vector2(viewport_size.x - 240, 100)
	task_panel.z_index = 100  # Above everything
	add_child(task_panel)
	task_panel.setup(task_manager)
	print("[TASK] Task panel created at position: %s (viewport: %s)" % [task_panel.position, viewport_size])

	# Connect store signals for event-based tasks
	if store:
		store.hour_advanced.connect(_on_hour_advanced_for_tasks)
		store.event_triggered.connect(_on_event_triggered_as_task)
		# Connect solar flare detection for EVA danger
		store.event_resolved.connect(_on_event_resolved_for_solar_flare)

	print("[TASK] Task system initialized with panel")

func _on_hour_advanced_for_tasks(_day: int, _hour: int) -> void:
	## Advance all active tasks when game hour advances
	if task_manager:
		task_manager.advance_hour()

func _on_task_penalty_applied(penalty: Dictionary) -> void:
	## Dispatch task penalty to store for state change
	## This makes failed tasks ACTUALLY affect game state
	if store:
		var action = Phase2Reducer.action_apply_task_penalty(penalty)
		store.dispatch(action)
		print("[TASK] Penalty dispatched to store: %s" % penalty)

var _pending_solar_flare: bool = false  # Track if solar flare is incoming

func _on_event_resolved_for_solar_flare(_choice_index: int) -> void:
	## Check if solar flare was resolved and crew was outside
	if _pending_solar_flare:
		_pending_solar_flare = false
		check_solar_flare_eva_danger()

func _on_event_triggered_as_task(event: Dictionary) -> void:
	## Convert certain events into trackable tasks
	## Automatically creates tasks for relevant event types AND assigns crew

	var event_type = event.get("type", 0)

	# Check if this is a solar flare event - flag it for EVA danger check
	if event_type == Phase2Types.EventType.SOLAR_FLARE:
		_pending_solar_flare = true
		print("[SOLAR FLARE] Solar flare event detected! Any EVA crew at risk.")

	if not task_manager:
		print("[TASK] WARNING: task_manager is null!")
		return

	# Automatically create tasks for certain event types (no requires_task flag needed)
	var task_config = _get_auto_task_config(event)
	if not task_config.is_empty():
		# Assign a crew member to work on this task
		var crew_role = _get_crew_for_task(task_config)
		var room_type = _get_room_for_task(task_config)

		# Update position to be at the crew member's destination
		if ship_view and crew_role:
			var room_pos = ship_view.get_room_position(room_type)
			task_config["position"] = room_pos + Vector2(0, -30)  # Above the room
			task_config["crew"] = [crew_role]

			# Send crew to work location
			_send_crew_to_work(crew_role, room_type, task_config)

		var task_id = task_manager.create_task(task_config)
		print("[TASK] Created task: %s (ID: %s) - Assigned: %s at %s" % [
			task_config.get("name", "?"),
			task_id,
			crew_role if crew_role else "none",
			ShipTypes.RoomType.keys()[room_type] if room_type >= 0 else "unknown"
		])

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

func _get_crew_for_task(task_config: Dictionary) -> String:
	## Get the best crew member for a task based on type
	var task_type = task_config.get("type", TaskManager.TaskType.CUSTOM)

	match task_type:
		TaskManager.TaskType.REPAIR:
			return "engineer"
		TaskManager.TaskType.MEDICAL:
			return "medical"
		TaskManager.TaskType.EVA:
			return "engineer"
		TaskManager.TaskType.RESEARCH:
			return "scientist"
		TaskManager.TaskType.CRISIS:
			return "commander"
		_:
			return "engineer"  # Default

func _get_room_for_task(task_config: Dictionary) -> int:
	## Get the room where task should be performed
	var task_type = task_config.get("type", TaskManager.TaskType.CUSTOM)

	match task_type:
		TaskManager.TaskType.REPAIR:
			return ShipTypes.RoomType.ENGINEERING
		TaskManager.TaskType.MEDICAL:
			return ShipTypes.RoomType.MEDICAL
		TaskManager.TaskType.EVA:
			return ShipTypes.RoomType.CARGO_BAY
		TaskManager.TaskType.RESEARCH:
			return ShipTypes.RoomType.LIFE_SUPPORT
		TaskManager.TaskType.CRISIS:
			return ShipTypes.RoomType.BRIDGE
		TaskManager.TaskType.MAINTENANCE:
			return ShipTypes.RoomType.ENGINEERING
		_:
			return ShipTypes.RoomType.BRIDGE

func _send_crew_to_work(crew_role: String, room_type: int, task_config: Dictionary) -> void:
	## Send crew member to work location and start task
	if not ship_view:
		return

	# Map TaskManager.TaskType to ShipTypes.TaskType for crew
	var ship_task_type = ShipTypes.TaskType.REPAIR  # Default
	var task_type = task_config.get("type", TaskManager.TaskType.CUSTOM)

	match task_type:
		TaskManager.TaskType.REPAIR:
			ship_task_type = ShipTypes.TaskType.REPAIR
		TaskManager.TaskType.MEDICAL:
			ship_task_type = ShipTypes.TaskType.TREAT_PATIENT
		TaskManager.TaskType.EVA:
			ship_task_type = ShipTypes.TaskType.EVA_REPAIR
		TaskManager.TaskType.CRISIS:
			ship_task_type = ShipTypes.TaskType.REROUTE_POWER
		_:
			ship_task_type = ShipTypes.TaskType.REPAIR

	# Send crew to room with callback to start working
	ship_view.send_crew_to_room_with_task(crew_role, room_type, ship_task_type)
	print("[TASK] Sent %s to %s to work on %s" % [crew_role, ShipTypes.RoomType.keys()[room_type], task_config.get("name", "task")])

func _get_auto_task_config(event: Dictionary) -> Dictionary:
	## Automatically generate task config for certain event types
	var event_type = event.get("type", 0)
	var title = event.get("title", "Task")

	match event_type:
		Phase2Types.EventType.MEDICAL_EMERGENCY:
			return {
				"name": title,
				"type": TaskManager.TaskType.MEDICAL,
				"hours": 4,
				"position": _get_event_task_position(event),
				"color": Color(0.8, 0.3, 0.3),
				"penalty": {"type": "health_damage", "amount": 25.0}
			}

		Phase2Types.EventType.COMPONENT_MALFUNCTION:
			return {
				"name": title,
				"type": TaskManager.TaskType.REPAIR,
				"hours": 3,
				"position": _get_event_task_position(event),
				"color": Color(0.8, 0.5, 0.2),
				"penalty": {"type": "system_damage", "amount": 15.0}
			}

		Phase2Types.EventType.POWER_SURGE:
			return {
				"name": title,
				"type": TaskManager.TaskType.REPAIR,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.9, 0.8, 0.2),
				"penalty": {"type": "resource_drain", "amount": 10.0}
			}

		Phase2Types.EventType.SOLAR_FLARE:
			return {
				"name": "Solar Flare Response",
				"type": TaskManager.TaskType.CRISIS,
				"hours": 1,
				"position": _get_event_task_position(event),
				"color": Color(1.0, 0.5, 0.0),
				"penalty": {"type": "health_damage", "amount": 20.0}
			}

		Phase2Types.EventType.MICROMETEORITE:
			return {
				"name": title,
				"type": TaskManager.TaskType.REPAIR,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.6, 0.6, 0.7),
				"penalty": {"type": "system_damage", "amount": 10.0}
			}

		Phase2Types.EventType.MIDPOINT_CRISIS:
			return {
				"name": "CRITICAL: Multi-System Failure",
				"type": TaskManager.TaskType.CRISIS,
				"hours": 6,
				"position": _get_event_task_position(event),
				"color": Color(1.0, 0.2, 0.2),
				"penalty": {"type": "health_damage", "amount": 40.0}
			}

		Phase2Types.EventType.CREW_CONFLICT:
			return {
				"name": "Mediate Crew Conflict",
				"type": TaskManager.TaskType.CUSTOM,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.7, 0.5, 0.8),
				"penalty": {"type": "morale_damage", "amount": 15.0}
			}

		Phase2Types.EventType.NAVIGATION_DRIFT:
			return {
				"name": "Course Correction",
				"type": TaskManager.TaskType.MAINTENANCE,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.3, 0.5, 0.8),
				"penalty": {"type": "resource_drain", "amount": 5.0}
			}

		Phase2Types.EventType.WATER_RECYCLER_ISSUE:
			return {
				"name": "Repair Water Recycler",
				"type": TaskManager.TaskType.REPAIR,
				"hours": 3,
				"position": _get_event_task_position(event),
				"color": Color(0.3, 0.6, 0.9),
				"penalty": {"type": "resource_drain", "amount": 10.0}
			}

		Phase2Types.EventType.OXYGEN_FLUCTUATION:
			return {
				"name": "Stabilize O2 Systems",
				"type": TaskManager.TaskType.REPAIR,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.4, 0.7, 0.9),
				"penalty": {"type": "health_damage", "amount": 10.0}
			}

		Phase2Types.EventType.COMMUNICATION_STATIC:
			return {
				"name": "Fix Communications",
				"type": TaskManager.TaskType.REPAIR,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.5, 0.5, 0.6),
				"penalty": {"type": "morale_damage", "amount": 5.0}
			}

		Phase2Types.EventType.CARGO_LOOSE:
			return {
				"name": "Secure Loose Cargo",
				"type": TaskManager.TaskType.MAINTENANCE,
				"hours": 1,
				"position": _get_event_task_position(event),
				"color": Color(0.6, 0.5, 0.3),
				"penalty": {"type": "system_damage", "amount": 10.0}
			}

		Phase2Types.EventType.SECTION_BLOCKAGE:
			return {
				"name": "Clear Blockage",
				"type": TaskManager.TaskType.MAINTENANCE,
				"hours": 2,
				"position": _get_event_task_position(event),
				"color": Color(0.5, 0.4, 0.3),
				"penalty": {"type": "efficiency_loss", "amount": 0.2}
			}

		_:
			# No automatic task for other event types (MESSAGE_FROM_EARTH, MORALE_MILESTONE, etc.)
			return {}

func _get_event_task_position(event: Dictionary) -> Vector2:
	## Get position for task spinner based on event type
	var event_type = event.get("type", "")

	# Default to ship center
	if ship_view:
		return ship_view.layout_center
	return Vector2(400, 300)

func _get_event_task_color(event_type: String) -> Color:
	## Get color for task based on event type
	match event_type:
		"medical_emergency": return Color(0.8, 0.3, 0.3)  # Red
		"system_failure": return Color(0.8, 0.5, 0.2)     # Orange
		"eva_required": return Color(0.3, 0.6, 0.9)       # Blue
		"crisis": return Color(0.9, 0.2, 0.2)             # Bright red
		_: return Color(0.6, 0.6, 0.6)                    # Gray

func _on_event_task_completed(event: Dictionary) -> void:
	## Handle successful event task completion
	print("[TASK] Event task completed successfully: %s" % event.get("title", "?"))
	# Event resolution is handled by the event system

func _on_event_task_failed(event: Dictionary) -> void:
	## Handle failed event task - apply penalties
	print("[TASK] Event task FAILED: %s" % event.get("title", "?"))
	# Penalties are applied by task_manager

# ============================================================================
# SOLAR FLARE EVA DANGER
# ============================================================================

func check_solar_flare_eva_danger() -> void:
	## Check if crew outside ship when solar flare hits
	## Triggers incapacitating medical event requiring constant crew maintenance
	if not ship_view or not ship_view.eva_ctrl:
		return

	# Check if anyone is on EVA
	var eva_crew = ship_view.eva_ctrl.get_active_eva_crew()
	if eva_crew.is_empty():
		return

	print("[SOLAR FLARE] WARNING: Crew outside during solar flare!")

	for crew_role in eva_crew:
		_trigger_radiation_incapacitation(crew_role)

func _trigger_radiation_incapacitation(crew_role: String) -> void:
	## Crew member hit by solar flare during EVA - severe radiation sickness
	print("[SOLAR FLARE] %s hit by radiation! Initiating emergency return..." % crew_role.capitalize())

	# Force immediate EVA return
	if ship_view and ship_view.eva_ctrl:
		ship_view.eva_ctrl._force_emergency_return(crew_role)

	# Create ongoing medical task for radiation treatment
	if task_manager:
		var task_config = {
			"name": "Radiation Treatment: %s" % crew_role.capitalize(),
			"type": TaskManager.TaskType.MEDICAL,
			"hours": 24,  # 24 hours of constant treatment
			"crew": ["medical"],
			"position": Vector2(400, 300),  # Medical bay area
			"color": Color(0.9, 0.3, 0.9),  # Purple/radiation color
			"penalty": {
				"type": "health_damage",
				"amount": 50.0,  # Severe health penalty if not treated
				"target": crew_role
			}
		}

		task_manager.create_task(task_config)
		print("[SOLAR FLARE] Created 24-hour radiation treatment task for %s" % crew_role.capitalize())

	# Dispatch to store for state changes
	if store:
		store.dispatch({
			"type": "CREW_RADIATION_EXPOSURE",
			"crew": crew_role,
			"severity": "severe",
			"source": "solar_flare_eva"
		})

# ============================================================================
# SOLAR FLARE AI RISK ASSESSMENT
# ============================================================================
# Mathematical model to discourage EVA during solar flare conditions
#
# Base EVA Utility = expected_repair_value - (drift_risk * drift_penalty)
# Modified EVA Utility = Base_Utility * solar_flare_multiplier
#
# Where solar_flare_multiplier depends on:
# - Time until solar flare (hours)
# - Current EVA duration estimate
# - Crew specialization (engineer gets slight bonus)

const SOLAR_FLARE_DETECTION_HOURS = 6  # Hours of warning before flare hits

static func calculate_eva_risk_modifier(hours_until_flare: float, eva_duration_hours: float, crew_role: String) -> float:
	## Calculate a multiplier [0.0 - 1.0] for EVA utility during solar flare conditions
	## Lower values = more risky, AI should avoid EVA
	## Returns 1.0 if no solar flare risk

	if hours_until_flare <= 0:
		# Flare already happening - NO EVA under any circumstances
		return 0.0

	# Calculate if EVA would complete before flare
	var safety_margin = hours_until_flare - eva_duration_hours

	if safety_margin < 0:
		# EVA would not complete in time - very bad
		# Exponential penalty based on how much time we'd be outside during flare
		var exposure_hours = abs(safety_margin)
		return max(0.05, exp(-exposure_hours * 0.5))  # Approaches 0 as exposure increases

	if safety_margin < 1.0:
		# Less than 1 hour margin - risky
		# Linear decrease from 0.5 to 0.1 as margin approaches 0
		return 0.1 + (safety_margin * 0.4)

	if safety_margin < 2.0:
		# 1-2 hour margin - somewhat risky
		return 0.5 + ((safety_margin - 1.0) * 0.3)  # 0.5 to 0.8

	if safety_margin < 4.0:
		# 2-4 hour margin - acceptable risk
		return 0.8 + ((safety_margin - 2.0) * 0.1)  # 0.8 to 1.0

	# 4+ hour margin - safe
	return 1.0

static func get_eva_utility(base_repair_value: float, drift_risk: float, drift_penalty: float,
							hours_until_flare: float, eva_duration_hours: float, crew_role: String) -> float:
	## Calculate overall EVA utility for AI decision making
	## Higher values = more attractive option

	# Base utility from repair value minus drift risk
	var base_utility = base_repair_value - (drift_risk * drift_penalty)

	# Apply solar flare risk modifier
	var flare_modifier = calculate_eva_risk_modifier(hours_until_flare, eva_duration_hours, crew_role)

	# Crew role bonuses (specialists are slightly better at their tasks)
	var role_bonus = 1.0
	if crew_role == "engineer":
		role_bonus = 1.1  # Engineers are 10% more effective at EVA repairs
	elif crew_role == "scientist":
		role_bonus = 1.05  # Scientists are 5% better at antenna calibration

	return base_utility * flare_modifier * role_bonus

static func should_recommend_eva(hours_until_flare: float, eva_duration_hours: float) -> bool:
	## Simple binary check: is EVA advisable given current solar flare conditions?
	var modifier = calculate_eva_risk_modifier(hours_until_flare, eva_duration_hours, "")
	return modifier >= 0.5  # Only recommend EVA if risk modifier is 50% or better

static func get_eva_risk_description(hours_until_flare: float, eva_duration_hours: float) -> String:
	## Get human-readable description of EVA risk level
	var modifier = calculate_eva_risk_modifier(hours_until_flare, eva_duration_hours, "")

	if modifier >= 1.0:
		return "Safe - No solar activity detected"
	elif modifier >= 0.8:
		return "Low Risk - Adequate safety margin"
	elif modifier >= 0.5:
		return "Moderate Risk - Solar flare approaching"
	elif modifier >= 0.2:
		return "HIGH RISK - Limited time before flare"
	else:
		return "EXTREME RISK - EVA NOT RECOMMENDED"
