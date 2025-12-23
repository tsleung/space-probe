extends Node

## Ship Game Controller - Runs the automatic ship survival game
## Time passes, random damage occurs, crew AI responds autonomously

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal day_changed(day: int)
signal crisis_started(room_type: ShipTypes.RoomType, time_remaining: float)
signal crisis_resolved(room_type: ShipTypes.RoomType)
signal crisis_failed(room_type: ShipTypes.RoomType)
signal game_over(reason: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var ship_view_path: NodePath
@export var seconds_per_day: float = 10.0  # Real seconds per game day
@export var event_chance_per_day: float = 0.4  # 40% chance of event each day
@export var crisis_time_limit: float = 15.0  # Seconds to fix before disaster

# ============================================================================
# STATE
# ============================================================================

var ship_view: Node2D
var current_day: int = 1
var day_timer: float = 0.0
var is_running: bool = false
var game_speed: float = 1.0

# Active crises: room_type -> { time_remaining, severity, assigned_crew }
var active_crises: Dictionary = {}

# Crew task assignments: role -> { task, target_room, crisis_ref }
var crew_assignments: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if ship_view_path:
		ship_view = get_node(ship_view_path)

	# Auto-find if not set
	if not ship_view:
		ship_view = get_parent().get_node_or_null("ShipView")

	if ship_view:
		_connect_ship_signals()
		start_game()

func _connect_ship_signals() -> void:
	ship_view.crew_arrived.connect(_on_crew_arrived)
	ship_view.task_completed.connect(_on_task_completed)
	ship_view.room_damaged.connect(_on_room_damaged)
	ship_view.room_repaired.connect(_on_room_repaired)

# ============================================================================
# GAME LOOP
# ============================================================================

func start_game() -> void:
	current_day = 1
	day_timer = 0.0
	is_running = true
	active_crises.clear()
	crew_assignments.clear()
	day_changed.emit(current_day)

func stop_game() -> void:
	is_running = false

func set_speed(speed: float) -> void:
	game_speed = speed

func _process(delta: float) -> void:
	if not is_running:
		return

	var scaled_delta = delta * game_speed

	# Advance day timer
	day_timer += scaled_delta
	if day_timer >= seconds_per_day:
		day_timer -= seconds_per_day
		_advance_day()

	# Update crisis timers
	_update_crises(scaled_delta)

	# Run crew AI
	_run_crew_ai()

func _advance_day() -> void:
	current_day += 1
	day_changed.emit(current_day)

	# Random event roll
	if randf() < event_chance_per_day:
		_trigger_random_event()

# ============================================================================
# EVENT SYSTEM
# ============================================================================

func _trigger_random_event() -> void:
	# Pick a random room to damage (not corridor)
	var damageable_rooms = [
		ShipTypes.RoomType.BRIDGE,
		ShipTypes.RoomType.ENGINEERING,
		ShipTypes.RoomType.LIFE_SUPPORT,
		ShipTypes.RoomType.MEDICAL,
		ShipTypes.RoomType.CARGO_BAY,
	]

	# Don't damage already damaged rooms
	var available_rooms = damageable_rooms.filter(func(r): return not active_crises.has(r))

	if available_rooms.is_empty():
		return  # All rooms already in crisis!

	var target_room = available_rooms[randi() % available_rooms.size()]
	var severity = randf_range(0.4, 0.9)

	_start_crisis(target_room, severity)

func _start_crisis(room_type: ShipTypes.RoomType, severity: float) -> void:
	# Apply damage to room visually
	ship_view.damage_room(room_type, severity)

	# Track the crisis
	active_crises[room_type] = {
		"time_remaining": crisis_time_limit,
		"severity": severity,
		"assigned_crew": ""
	}

	crisis_started.emit(room_type, crisis_time_limit)

func _update_crises(delta: float) -> void:
	var resolved_crises = []
	var failed_crises = []

	for room_type in active_crises:
		var crisis = active_crises[room_type]

		# Check if crew is working on it
		if crisis.assigned_crew != "":
			var crew_member = ship_view.get_crew_member(crisis.assigned_crew)
			if crew_member and crew_member.current_state == ShipTypes.CrewState.WORKING:
				# Crew is actively repairing - reduce timer slower or hold
				crisis.time_remaining -= delta * 0.3  # Slow decay while repairing
				if crisis.time_remaining <= -5.0:  # Extra time needed to fully repair
					resolved_crises.append(room_type)
				continue

		# No one working - time ticks down
		crisis.time_remaining -= delta

		if crisis.time_remaining <= 0:
			failed_crises.append(room_type)

	# Process resolutions
	for room_type in resolved_crises:
		_resolve_crisis(room_type)

	for room_type in failed_crises:
		_fail_crisis(room_type)

func _resolve_crisis(room_type: ShipTypes.RoomType) -> void:
	var crisis = active_crises[room_type]

	# Clear crew assignment
	if crisis.assigned_crew != "":
		crew_assignments.erase(crisis.assigned_crew)
		# Return crew to idle
		var crew_member = ship_view.get_crew_member(crisis.assigned_crew)
		if crew_member:
			crew_member.finish_task()

	# Repair room visually
	ship_view.repair_room(room_type)

	# Remove crisis
	active_crises.erase(room_type)

	crisis_resolved.emit(room_type)

func _fail_crisis(room_type: ShipTypes.RoomType) -> void:
	var crisis = active_crises[room_type]

	# Clear crew assignment
	if crisis.assigned_crew != "":
		crew_assignments.erase(crisis.assigned_crew)

	active_crises.erase(room_type)

	crisis_failed.emit(room_type)

	# Check for game over conditions
	_check_game_over(room_type)

func _check_game_over(failed_room: ShipTypes.RoomType) -> void:
	# Critical rooms cause immediate game over
	match failed_room:
		ShipTypes.RoomType.LIFE_SUPPORT:
			game_over.emit("Life support failure - crew cannot breathe!")
			stop_game()
		ShipTypes.RoomType.BRIDGE:
			game_over.emit("Bridge destroyed - ship is uncontrollable!")
			stop_game()
		ShipTypes.RoomType.ENGINEERING:
			game_over.emit("Engineering catastrophe - engines offline!")
			stop_game()
		_:
			# Non-critical failure - continue but with consequences
			pass

# ============================================================================
# CREW AI
# ============================================================================

func _run_crew_ai() -> void:
	if active_crises.is_empty():
		return

	# Find unassigned crises
	var unassigned_crises = []
	for room_type in active_crises:
		var crisis = active_crises[room_type]
		if crisis.assigned_crew == "":
			unassigned_crises.append(room_type)

	if unassigned_crises.is_empty():
		return

	# Find available crew
	var available_crew = _get_available_crew()

	if available_crew.is_empty():
		return

	# Sort crises by urgency (lowest time remaining first)
	unassigned_crises.sort_custom(func(a, b):
		return active_crises[a].time_remaining < active_crises[b].time_remaining
	)

	# Assign crew to crises
	for room_type in unassigned_crises:
		if available_crew.is_empty():
			break

		# Find best crew for this crisis
		var best_crew = _find_best_crew_for_crisis(room_type, available_crew)
		if best_crew != "":
			_assign_crew_to_crisis(best_crew, room_type)
			available_crew.erase(best_crew)

func _get_available_crew() -> Array:
	var available = []
	var crew_status = ship_view.get_crew_status()

	for role in crew_status:
		# Check if already assigned
		if crew_assignments.has(role):
			continue

		var member = ship_view.get_crew_member(role)
		if member and member.current_state == ShipTypes.CrewState.IDLE:
			available.append(role)

	return available

func _find_best_crew_for_crisis(room_type: ShipTypes.RoomType, available_crew: Array) -> String:
	if available_crew.is_empty():
		return ""

	# Preference based on room type and crew role
	var preferred_role = _get_preferred_role_for_room(room_type)

	# If preferred role is available, use them
	if preferred_role in available_crew:
		return preferred_role

	# Otherwise find nearest crew
	var room = ship_view.get_room(room_type)
	if not room:
		return available_crew[0]

	var nearest_role = ""
	var nearest_dist = INF

	for role in available_crew:
		var member = ship_view.get_crew_member(role)
		if member:
			var dist = member.global_position.distance_to(room.get_work_position())
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_role = role

	return nearest_role

func _get_preferred_role_for_room(room_type: ShipTypes.RoomType) -> String:
	match room_type:
		ShipTypes.RoomType.BRIDGE:
			return "commander"
		ShipTypes.RoomType.ENGINEERING:
			return "engineer"
		ShipTypes.RoomType.LIFE_SUPPORT:
			return "engineer"
		ShipTypes.RoomType.MEDICAL:
			return "medical"
		ShipTypes.RoomType.CARGO_BAY:
			return "scientist"
		_:
			return ""

func _assign_crew_to_crisis(role: String, room_type: ShipTypes.RoomType) -> void:
	# Record assignment
	crew_assignments[role] = {
		"task": ShipTypes.TaskType.REPAIR,
		"target_room": room_type
	}
	active_crises[room_type].assigned_crew = role

	# Send crew to room (emergency speed)
	ship_view.send_crew_to_room(role, room_type, true)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_crew_arrived(role: String, room_type: ShipTypes.RoomType) -> void:
	# Check if this arrival is for an assigned crisis
	if crew_assignments.has(role):
		var assignment = crew_assignments[role]
		if assignment.target_room == room_type:
			# Start repair task
			ship_view.assign_task_to_crew(role, ShipTypes.TaskType.REPAIR)

func _on_task_completed(role: String, task_type: ShipTypes.TaskType) -> void:
	# Task done - clear assignment
	if crew_assignments.has(role):
		crew_assignments.erase(role)

func _on_room_damaged(room_type: ShipTypes.RoomType, severity: float) -> void:
	# External damage (not from our event system) - track it
	if not active_crises.has(room_type):
		active_crises[room_type] = {
			"time_remaining": crisis_time_limit,
			"severity": severity,
			"assigned_crew": ""
		}
		crisis_started.emit(room_type, crisis_time_limit)

func _on_room_repaired(room_type: ShipTypes.RoomType) -> void:
	# External repair - clear our tracking
	if active_crises.has(room_type):
		var crisis = active_crises[room_type]
		if crisis.assigned_crew != "":
			crew_assignments.erase(crisis.assigned_crew)
		active_crises.erase(room_type)
		crisis_resolved.emit(room_type)

# ============================================================================
# GETTERS
# ============================================================================

func get_current_day() -> int:
	return current_day

func get_day_progress() -> float:
	return day_timer / seconds_per_day

func get_active_crises() -> Dictionary:
	return active_crises

func is_game_running() -> bool:
	return is_running
