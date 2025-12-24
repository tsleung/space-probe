extends Node
class_name TaskManager

## Task Manager - Tracks all active tasks with progress spinners
## Tasks have durations (in hours), assigned crew, and penalties for failure
## Integrates with CircleSpinner for visual feedback

const CircleSpinner = preload("res://scripts/mars_odyssey_trek/phase2/ui/circle_spinner.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal task_started(task: Dictionary)
signal task_progress(task_id: String, progress: float)
signal task_completed(task_id: String, success: bool)
signal task_failed(task_id: String, penalty: Dictionary)
signal task_penalty_applied(penalty: Dictionary)  # New: dispatched to Store for state changes

# ============================================================================
# TASK TYPES
# ============================================================================

enum TaskType {
	REPAIR,           # Fix broken systems
	MEDICAL,          # Treat injured crew
	EVA,              # Exterior work
	MAINTENANCE,      # Routine maintenance
	RESEARCH,         # Science tasks
	CRISIS,           # Emergency response
	CUSTOM            # Event-specific tasks
}

# Default task configurations
const TASK_CONFIGS = {
	TaskType.REPAIR: {
		"base_hours": 4,
		"crew_required": ["engineer"],
		"penalty_type": "system_damage",
		"penalty_amount": 20.0,
		"color": Color(0.8, 0.5, 0.2)
	},
	TaskType.MEDICAL: {
		"base_hours": 2,
		"crew_required": ["medical"],
		"penalty_type": "health_damage",
		"penalty_amount": 15.0,
		"color": Color(0.8, 0.3, 0.3)
	},
	TaskType.EVA: {
		"base_hours": 6,
		"crew_required": ["engineer"],
		"penalty_type": "morale_damage",
		"penalty_amount": 10.0,
		"color": Color(0.3, 0.6, 0.9)
	},
	TaskType.MAINTENANCE: {
		"base_hours": 3,
		"crew_required": ["engineer", "scientist"],
		"penalty_type": "efficiency_loss",
		"penalty_amount": 0.1,
		"color": Color(0.5, 0.7, 0.4)
	},
	TaskType.RESEARCH: {
		"base_hours": 8,
		"crew_required": ["scientist"],
		"penalty_type": "none",
		"penalty_amount": 0.0,
		"color": Color(0.4, 0.5, 0.8)
	},
	TaskType.CRISIS: {
		"base_hours": 1,
		"crew_required": [],  # Depends on crisis type
		"penalty_type": "resource_drain",
		"penalty_amount": 5.0,
		"color": Color(0.9, 0.2, 0.2)
	},
	TaskType.CUSTOM: {
		"base_hours": 2,
		"crew_required": [],
		"penalty_type": "morale_damage",
		"penalty_amount": 5.0,
		"color": Color(0.6, 0.6, 0.6)
	}
}

# ============================================================================
# STATE
# ============================================================================

var active_tasks: Dictionary = {}  # task_id -> task data
var task_spinners: Dictionary = {}  # task_id -> CircleSpinner
var next_task_id: int = 0

# Parent node for spinners
var spinner_parent: Node = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	pass

func setup(parent: Node) -> void:
	spinner_parent = parent

# ============================================================================
# TASK CREATION
# ============================================================================

func create_task(config: Dictionary) -> String:
	## Create a new task and return its ID
	## Config should include:
	##   - name: Display name
	##   - type: TaskType enum value
	##   - hours: Duration in hours (optional, uses default)
	##   - crew: Array of crew roles assigned (optional)
	##   - position: Vector2 for spinner placement
	##   - penalty: Custom penalty config (optional)
	##   - on_complete: Callable to run on completion (optional)
	##   - on_fail: Callable to run on failure (optional)

	var task_id = "task_%d" % next_task_id
	next_task_id += 1

	var task_type = config.get("type", TaskType.CUSTOM)
	var type_config = TASK_CONFIGS.get(task_type, TASK_CONFIGS[TaskType.CUSTOM])

	var task = {
		"id": task_id,
		"name": config.get("name", "Task"),
		"type": task_type,
		"total_hours": config.get("hours", type_config.base_hours),
		"elapsed_hours": 0.0,
		"crew": config.get("crew", type_config.crew_required),
		"position": config.get("position", Vector2.ZERO),
		"color": config.get("color", type_config.color),
		"penalty": config.get("penalty", {
			"type": type_config.penalty_type,
			"amount": type_config.penalty_amount
		}),
		"on_complete": config.get("on_complete", Callable()),
		"on_fail": config.get("on_fail", Callable()),
		"started_at": Time.get_ticks_msec(),
		"paused": false
	}

	active_tasks[task_id] = task

	# Create visual spinner
	_create_task_spinner(task)

	task_started.emit(task)
	return task_id

func _create_task_spinner(task: Dictionary) -> void:
	if not spinner_parent:
		return

	var spinner = CircleSpinner.new()
	spinner.position = task.position
	spinner.radius = 20.0
	spinner.progress_color = task.color
	spinner.show_label = true
	spinner.label_suffix = "h"

	spinner_parent.add_child(spinner)
	spinner.start(task.total_hours, false)

	# Connect completion signal
	spinner.completed.connect(_on_spinner_completed.bind(task.id))

	task_spinners[task.id] = spinner

func _on_spinner_completed(task_id: String) -> void:
	complete_task(task_id, true)

# ============================================================================
# TASK UPDATES
# ============================================================================

func advance_hour() -> void:
	## Called every game hour to advance all active tasks
	for task_id in active_tasks.keys():
		var task = active_tasks[task_id]
		if task.paused:
			continue

		task.elapsed_hours += 1.0

		# Update spinner
		var spinner = task_spinners.get(task_id)
		if spinner:
			spinner.advance(1.0)

		task_progress.emit(task_id, task.elapsed_hours / task.total_hours)

		# Check for completion
		if task.elapsed_hours >= task.total_hours:
			complete_task(task_id, true)

func complete_task(task_id: String, success: bool) -> void:
	## Complete a task (success or failure)
	if not active_tasks.has(task_id):
		return

	var task = active_tasks[task_id]

	# Remove spinner
	var spinner = task_spinners.get(task_id)
	if spinner:
		spinner.queue_free()
		task_spinners.erase(task_id)

	if success:
		# Run completion callback
		if task.on_complete.is_valid():
			task.on_complete.call()
		task_completed.emit(task_id, true)
	else:
		# Apply penalty
		_apply_penalty(task)
		if task.on_fail.is_valid():
			task.on_fail.call()
		task_failed.emit(task_id, task.penalty)
		task_completed.emit(task_id, false)

	active_tasks.erase(task_id)

func cancel_task(task_id: String) -> void:
	## Cancel a task and apply failure penalty
	complete_task(task_id, false)

func pause_task(task_id: String) -> void:
	if active_tasks.has(task_id):
		active_tasks[task_id].paused = true
		var spinner = task_spinners.get(task_id)
		if spinner:
			spinner.stop()

func resume_task(task_id: String) -> void:
	if active_tasks.has(task_id):
		active_tasks[task_id].paused = false
		var spinner = task_spinners.get(task_id)
		if spinner:
			spinner.is_running = true

# ============================================================================
# PENALTIES
# ============================================================================

func _apply_penalty(task: Dictionary) -> void:
	## Apply the penalty for a failed/cancelled task
	## Emits task_penalty_applied signal for Store to dispatch action
	var penalty = task.penalty.duplicate()
	var penalty_type = penalty.get("type", "none")
	var amount = penalty.get("amount", 0.0)

	if penalty_type == "none" or amount == 0.0:
		print("[TASK] No penalty for task '%s'" % task.name)
		return

	# Add task context to penalty for logging
	penalty["task_name"] = task.name
	penalty["task_type"] = task.type

	# Emit signal for Store to handle - this is the key change!
	# Store will dispatch APPLY_TASK_PENALTY action to reducer
	task_penalty_applied.emit(penalty)

	print("[TASK] Penalty emitted: %s (%.1f) for task '%s'" % [penalty_type, amount, task.name])

# ============================================================================
# QUERIES
# ============================================================================

func get_active_tasks() -> Array:
	return active_tasks.values()

func get_task(task_id: String) -> Dictionary:
	return active_tasks.get(task_id, {})

func has_active_tasks() -> bool:
	return not active_tasks.is_empty()

func get_task_count() -> int:
	return active_tasks.size()

func is_crew_busy(crew_role: String) -> bool:
	## Check if a crew member is assigned to any active task
	for task in active_tasks.values():
		if crew_role in task.crew:
			return true
	return false

func get_tasks_by_type(task_type: int) -> Array:
	var result = []
	for task in active_tasks.values():
		if task.type == task_type:
			result.append(task)
	return result

func get_tasks_by_crew(crew_role: String) -> Array:
	var result = []
	for task in active_tasks.values():
		if crew_role in task.crew:
			result.append(task)
	return result

# ============================================================================
# FACTORY METHODS
# ============================================================================

static func create_repair_task(name: String, hours: float, position: Vector2, on_complete: Callable = Callable()) -> Dictionary:
	return {
		"name": name,
		"type": TaskType.REPAIR,
		"hours": hours,
		"position": position,
		"on_complete": on_complete
	}

static func create_medical_task(patient: String, hours: float, position: Vector2) -> Dictionary:
	return {
		"name": "Treating %s" % patient.capitalize(),
		"type": TaskType.MEDICAL,
		"hours": hours,
		"crew": ["medical"],
		"position": position,
		"penalty": {
			"type": "health_damage",
			"amount": 20.0,
			"target": patient
		}
	}

static func create_eva_task(target: String, hours: float, position: Vector2) -> Dictionary:
	return {
		"name": "EVA: %s" % target,
		"type": TaskType.EVA,
		"hours": hours,
		"position": position
	}

static func create_crisis_task(crisis_name: String, hours: float, position: Vector2, penalty_per_hour: float) -> Dictionary:
	return {
		"name": crisis_name,
		"type": TaskType.CRISIS,
		"hours": hours,
		"position": position,
		"color": Color(0.9, 0.2, 0.2),
		"penalty": {
			"type": "resource_drain",
			"amount": penalty_per_hour
		}
	}

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save_state() -> Dictionary:
	var tasks_data = []
	for task in active_tasks.values():
		var task_copy = task.duplicate()
		# Remove non-serializable callables
		task_copy.erase("on_complete")
		task_copy.erase("on_fail")
		tasks_data.append(task_copy)

	return {
		"active_tasks": tasks_data,
		"next_task_id": next_task_id
	}

func load_state(state: Dictionary) -> void:
	next_task_id = state.get("next_task_id", 0)

	# Clear existing tasks
	for task_id in active_tasks.keys():
		var spinner = task_spinners.get(task_id)
		if spinner:
			spinner.queue_free()
	active_tasks.clear()
	task_spinners.clear()

	# Restore tasks
	for task_data in state.get("active_tasks", []):
		var task_id = task_data.id
		active_tasks[task_id] = task_data
		_create_task_spinner(task_data)
