extends Node
class_name CrisisModeController

## CRISIS Mode Controller
## Orchestrates tile-based crisis management with multi-step fetch tasks
## Creates "Overcooked meets Apollo 13" pressure through discrete movement and item logistics

const TileGrid = preload("res://scripts/mars_odyssey_trek/phase2/crisis/tile_grid.gd")
const CrisisTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_types.gd")
const ItemTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/item_types.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal crisis_mode_started(crisis_type: String)
signal crisis_mode_ended(result: String, stats: Dictionary)
signal crisis_spawned(crisis: Dictionary)
signal crisis_resolved(crisis: Dictionary)
signal crisis_escalated(crisis: Dictionary, new_severity: int)
signal catastrophe_occurred(crisis: Dictionary, effect: String)
signal crew_task_started(crew_role: String, task: Dictionary)
signal crew_task_completed(crew_role: String, task: Dictionary)
signal item_shortage(item_type: String)

# ============================================================================
# ENUMS
# ============================================================================

enum CrisisMode {
	INACTIVE,      # Normal gameplay
	ACTIVE,        # CRISIS mode running
	VICTORY,       # All crises resolved
	FAILURE        # Catastrophic failure
}

enum TaskPhase {
	IDLE,           # No task assigned
	MOVING_TO_CARGO,  # Walking to cargo bay for item
	PICKING_UP,       # Picking up item
	MOVING_TO_CRISIS, # Walking to crisis location
	WORKING,          # Performing fix action
	COMPLETED         # Task done, returning to idle
}

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var spawn_interval: float = 2.0  # Seconds between spawn checks
@export var base_spawn_chance: float = 0.35  # 35% per check
@export var max_crises: int = 8  # More than crew can handle
@export var ai_reaction_delay: float = 1.5  # Delay before AI assigns

# Escalation timing (CRISIS mode - faster than normal)
const CRISIS_ESCALATION_TIMES = {
	CrisisTypes.Severity.EMERGING: 6.0,
	CrisisTypes.Severity.ACTIVE: 8.0,
	CrisisTypes.Severity.CRITICAL: 8.0,
	CrisisTypes.Severity.CATASTROPHIC: 6.0  # Time before failure
}

# ============================================================================
# STATE
# ============================================================================

var mode: CrisisMode = CrisisMode.INACTIVE
var crisis_type_name: String = "standard"  # standard, cascade, storm

# Core components
var tile_grid: TileGrid
var cargo_storage: Node  # CargoStorage
var crisis_manager: Node  # CrisisManager
var ship_view: Node2D     # ShipView with crew members

# Crew task tracking
var crew_tasks: Dictionary = {}  # role -> {phase, crisis_id, item_type, progress}

# Timing
var spawn_timer: float = 0.0
var mode_duration: float = 0.0
var catastrophe_timer: float = 0.0  # Time until failure after first catastrophic

# Statistics
var stats: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_init_crew_tasks()

func _init_crew_tasks() -> void:
	crew_tasks = {
		"commander": _create_task_state(),
		"engineer": _create_task_state(),
		"scientist": _create_task_state(),
		"medical": _create_task_state()
	}

func _create_task_state() -> Dictionary:
	return {
		"phase": TaskPhase.IDLE,
		"crisis_id": "",
		"item_type": "",
		"target_tile": Vector2i.ZERO,
		"work_progress": 0.0,
		"work_duration": 0.0
	}

func setup(grid: TileGrid, storage: Node, manager: Node, view: Node2D) -> void:
	## Connect all components for CRISIS mode
	tile_grid = grid
	cargo_storage = storage
	crisis_manager = manager
	ship_view = view

	# Connect crisis manager signals
	if crisis_manager:
		crisis_manager.crisis_spawned.connect(_on_crisis_spawned)
		crisis_manager.crisis_resolved.connect(_on_crisis_resolved)
		crisis_manager.crisis_escalated.connect(_on_crisis_escalated)
		crisis_manager.catastrophe.connect(_on_catastrophe)

# ============================================================================
# MODE CONTROL
# ============================================================================

func start_crisis_mode(type: String = "standard") -> void:
	## Enter CRISIS mode
	if mode != CrisisMode.INACTIVE:
		return

	mode = CrisisMode.ACTIVE
	crisis_type_name = type
	spawn_timer = 0.0
	mode_duration = 0.0
	catastrophe_timer = 0.0

	# Initialize statistics
	stats = {
		"crises_spawned": 0,
		"crises_resolved": 0,
		"crises_catastrophic": 0,
		"items_used": 0,
		"total_drain": {},
		"duration": 0.0
	}

	# Initialize cargo storage
	if cargo_storage and cargo_storage.has_method("initialize_for_crisis"):
		cargo_storage.initialize_for_crisis(type)

	# Enable tile mode on all crew
	_enable_tile_mode_on_crew()

	# Reset crew tasks
	_init_crew_tasks()

	# Configure crisis manager for CRISIS mode timing
	if crisis_manager:
		crisis_manager.spawn_interval = spawn_interval
		crisis_manager.base_spawn_chance = base_spawn_chance
		crisis_manager.max_crises = max_crises
		crisis_manager.enabled = true

	print("[CRISIS MODE] Started: %s" % type)
	crisis_mode_started.emit(type)

func end_crisis_mode(result: String) -> void:
	## Exit CRISIS mode
	if mode == CrisisMode.INACTIVE:
		return

	mode = CrisisMode.VICTORY if result == "victory" else CrisisMode.FAILURE
	stats.duration = mode_duration

	# Disable tile mode
	_disable_tile_mode_on_crew()

	# Stop crisis spawning
	if crisis_manager:
		crisis_manager.enabled = false
		crisis_manager.clear_all_crises()

	# Clear cargo
	if cargo_storage and cargo_storage.has_method("clear_storage"):
		cargo_storage.clear_storage()

	print("[CRISIS MODE] Ended: %s (duration: %.1fs)" % [result, mode_duration])
	crisis_mode_ended.emit(result, stats)

	mode = CrisisMode.INACTIVE

func _enable_tile_mode_on_crew() -> void:
	if not ship_view or not tile_grid:
		return

	for role in ["commander", "engineer", "scientist", "medical"]:
		var crew = _get_crew_member(role)
		if crew and crew.has_method("enable_tile_mode"):
			crew.enable_tile_mode(tile_grid)

func _disable_tile_mode_on_crew() -> void:
	if not ship_view:
		return

	for role in ["commander", "engineer", "scientist", "medical"]:
		var crew = _get_crew_member(role)
		if crew and crew.has_method("disable_tile_mode"):
			crew.disable_tile_mode()

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if mode != CrisisMode.ACTIVE:
		return

	mode_duration += delta

	# Process crew tasks
	_process_crew_tasks(delta)

	# Check for victory (no active crises)
	_check_victory_condition()

	# Check for failure (catastrophic timer)
	_check_failure_condition(delta)

func _process_crew_tasks(delta: float) -> void:
	## Update all crew task progress
	for role in crew_tasks:
		var task = crew_tasks[role]
		var crew = _get_crew_member(role)
		if not crew:
			continue

		match task.phase:
			TaskPhase.IDLE:
				pass  # AI will assign tasks

			TaskPhase.MOVING_TO_CARGO:
				if crew.current_state == ShipTypes.CrewState.IDLE:
					# Arrived at cargo, start pickup
					_start_item_pickup(role)

			TaskPhase.PICKING_UP:
				if crew.current_state == ShipTypes.CrewState.IDLE:
					# Pickup complete, move to crisis
					_start_move_to_crisis(role)

			TaskPhase.MOVING_TO_CRISIS:
				if crew.current_state == ShipTypes.CrewState.IDLE:
					# Arrived at crisis, start working
					_start_working(role)

			TaskPhase.WORKING:
				task.work_progress += delta
				if task.work_progress >= task.work_duration:
					_complete_task(role)

			TaskPhase.COMPLETED:
				task.phase = TaskPhase.IDLE
				task.crisis_id = ""

func _check_victory_condition() -> void:
	## Check if all crises are resolved
	if not crisis_manager:
		return

	var active = crisis_manager.get_crisis_count()
	if active == 0 and stats.crises_spawned > 0 and mode_duration > 10.0:
		# Brief delay before declaring victory
		end_crisis_mode("victory")

func _check_failure_condition(delta: float) -> void:
	## Check for catastrophic failure
	if not crisis_manager:
		return

	# Check for any catastrophic crises
	var crises = crisis_manager.get_active_crises()
	var has_catastrophic = false

	for crisis in crises:
		if crisis.severity == CrisisTypes.Severity.CATASTROPHIC:
			has_catastrophic = true
			break

	if has_catastrophic:
		catastrophe_timer += delta
		if catastrophe_timer >= CRISIS_ESCALATION_TIMES[CrisisTypes.Severity.CATASTROPHIC]:
			end_crisis_mode("failure")
	else:
		catastrophe_timer = 0.0

# ============================================================================
# TASK ASSIGNMENT (Called by AI)
# ============================================================================

func assign_crisis_to_crew(crew_role: String, crisis_id: String) -> bool:
	## Assign a crew member to fix a crisis
	## Returns false if crew is busy or crisis invalid

	var task = crew_tasks.get(crew_role)
	if not task or task.phase != TaskPhase.IDLE:
		return false

	if not crisis_manager:
		return false

	var crisis = crisis_manager.get_crisis_by_id(crisis_id)
	if crisis.is_empty():
		return false

	var crisis_type = crisis.type
	task.crisis_id = crisis_id

	# Determine if we need to fetch an item
	if CrisisTypes.crisis_requires_item(crisis_type):
		var item_needed = CrisisTypes.get_required_item(crisis_type)
		var crew = _get_crew_member(crew_role)

		# Check if crew already has the item
		if crew and crew.has_method("get_carried_item") and crew.get_carried_item() == item_needed:
			# Already have item, go straight to crisis
			task.item_type = item_needed
			_start_move_to_crisis(crew_role)
		else:
			# Need to fetch item first
			if cargo_storage and cargo_storage.has_method("has_item"):
				var item_enum = ItemTypes.string_to_item_type(item_needed)
				if not cargo_storage.has_item(item_enum):
					# Item not available!
					item_shortage.emit(item_needed)
					task.crisis_id = ""
					return false

			task.item_type = item_needed
			_start_move_to_cargo(crew_role)
	else:
		# Station task - go directly to crisis room
		task.item_type = ""
		_start_move_to_crisis(crew_role)

	task.work_duration = CrisisTypes.get_crisis_work_time(crisis_type)
	crew_task_started.emit(crew_role, task.duplicate())
	return true

func _start_move_to_cargo(crew_role: String) -> void:
	var task = crew_tasks[crew_role]
	var crew = _get_crew_member(crew_role)
	if not crew:
		return

	task.phase = TaskPhase.MOVING_TO_CARGO

	# Get item pickup tile
	var item_enum = ItemTypes.string_to_item_type(task.item_type)
	var cargo_tile = cargo_storage.get_item_tile(item_enum) if cargo_storage else Vector2i(1, 9)
	task.target_tile = cargo_tile

	# Send crew to cargo
	crew.move_to_tile(cargo_tile, true)  # Emergency speed
	print("[CRISIS] %s moving to cargo for %s" % [crew_role, task.item_type])

func _start_item_pickup(crew_role: String) -> void:
	var task = crew_tasks[crew_role]
	var crew = _get_crew_member(crew_role)
	if not crew:
		return

	task.phase = TaskPhase.PICKING_UP

	# Take item from storage
	var item_enum = ItemTypes.string_to_item_type(task.item_type)
	if cargo_storage and cargo_storage.has_method("take_item"):
		if cargo_storage.take_item(item_enum):
			crew.pickup_item(task.item_type)
			stats.items_used = stats.get("items_used", 0) + 1
			print("[CRISIS] %s picked up %s" % [crew_role, task.item_type])
		else:
			# Item ran out while we were walking!
			item_shortage.emit(task.item_type)
			task.phase = TaskPhase.IDLE
			task.crisis_id = ""
			print("[CRISIS] %s couldn't get %s - out of stock!" % [crew_role, task.item_type])

func _start_move_to_crisis(crew_role: String) -> void:
	var task = crew_tasks[crew_role]
	var crew = _get_crew_member(crew_role)
	if not crew or not crisis_manager:
		return

	task.phase = TaskPhase.MOVING_TO_CRISIS

	var crisis = crisis_manager.get_crisis_by_id(task.crisis_id)
	if crisis.is_empty():
		task.phase = TaskPhase.IDLE
		return

	var room = crisis.room
	if room == null:
		room = ShipTypes.RoomType.ENGINEERING  # Default

	var station_tile = TileGrid.get_room_station_tile(room)
	task.target_tile = station_tile

	crew.move_to_tile(station_tile, true)
	print("[CRISIS] %s moving to %s" % [crew_role, ShipTypes.get_room_name(room)])

func _start_working(crew_role: String) -> void:
	var task = crew_tasks[crew_role]
	var crew = _get_crew_member(crew_role)
	if not crew:
		return

	task.phase = TaskPhase.WORKING
	task.work_progress = 0.0

	# Drop item if carrying (consume it)
	if task.item_type != "" and crew.has_method("drop_item"):
		crew.drop_item()

	# Start work animation
	crew.start_task(ShipTypes.TaskType.REPAIR)
	print("[CRISIS] %s working on crisis (%.1fs)" % [crew_role, task.work_duration])

func _complete_task(crew_role: String) -> void:
	var task = crew_tasks[crew_role]

	# Resolve the crisis
	if crisis_manager and task.crisis_id != "":
		var crisis = crisis_manager.get_crisis_by_id(task.crisis_id)
		if not crisis.is_empty():
			crisis.fix_progress = 1.0  # Force completion
			crisis_manager._remove_crisis(task.crisis_id)
			crisis_resolved.emit(crisis)
			stats.crises_resolved = stats.get("crises_resolved", 0) + 1
			print("[CRISIS] %s resolved crisis!" % crew_role)

	task.phase = TaskPhase.COMPLETED
	crew_task_completed.emit(crew_role, task.duplicate())

# ============================================================================
# CRISIS SIGNAL HANDLERS
# ============================================================================

func _on_crisis_spawned(crisis: Dictionary) -> void:
	stats.crises_spawned = stats.get("crises_spawned", 0) + 1
	crisis_spawned.emit(crisis)

func _on_crisis_resolved(crisis: Dictionary) -> void:
	# Stats already updated in _complete_task
	pass

func _on_crisis_escalated(crisis: Dictionary, _old_severity: int, new_severity: int) -> void:
	crisis_escalated.emit(crisis, new_severity)

func _on_catastrophe(crisis: Dictionary, effect: String) -> void:
	stats.crises_catastrophic = stats.get("crises_catastrophic", 0) + 1
	catastrophe_occurred.emit(crisis, effect)

# ============================================================================
# QUERIES
# ============================================================================

func get_crew_task(crew_role: String) -> Dictionary:
	return crew_tasks.get(crew_role, {})

func is_crew_busy(crew_role: String) -> bool:
	var task = crew_tasks.get(crew_role, {})
	return task.get("phase", TaskPhase.IDLE) != TaskPhase.IDLE

func get_idle_crew() -> Array:
	var idle = []
	for role in crew_tasks:
		if crew_tasks[role].phase == TaskPhase.IDLE:
			idle.append(role)
	return idle

func get_mode() -> CrisisMode:
	return mode

func is_active() -> bool:
	return mode == CrisisMode.ACTIVE

func get_stats() -> Dictionary:
	return stats.duplicate()

# ============================================================================
# HELPERS
# ============================================================================

func _get_crew_member(role: String) -> Node:
	## Get crew member node from ship view
	if not ship_view:
		return null

	# Try different methods to find crew
	if ship_view.has_method("get_crew_member"):
		return ship_view.get_crew_member(role)

	# Fall back to finding by name
	for child in ship_view.get_children():
		if child is CharacterBody2D and child.get("role") == role:
			return child

	return null
