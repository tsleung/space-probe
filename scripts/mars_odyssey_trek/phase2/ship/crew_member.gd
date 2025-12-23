extends CharacterBody2D
class_name CrewMember

## A crew member that moves around the ship and performs tasks

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: ShipTypes.CrewState)
signal arrived_at_destination(room_type: ShipTypes.RoomType)
signal task_started(task_type: ShipTypes.TaskType)
signal task_completed(task_type: ShipTypes.TaskType)

# ============================================================================
# PROPERTIES
# ============================================================================

@export var role: String = "commander"  # commander, engineer, scientist, medical

var current_state: ShipTypes.CrewState = ShipTypes.CrewState.IDLE
var current_room: ShipTypes.RoomType = ShipTypes.RoomType.BRIDGE
var target_room: ShipTypes.RoomType = ShipTypes.RoomType.BRIDGE
var target_position: Vector2 = Vector2.ZERO

var current_task: ShipTypes.TaskType = ShipTypes.TaskType.MONITOR
var task_progress: float = 0.0
var task_duration: float = 0.0

var is_emergency: bool = false

# Navigation
var nav_agent: NavigationAgent2D
var path: PackedVector2Array = []
var path_index: int = 0

# Visuals
var sprite: Polygon2D
var role_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_visuals()
	_setup_navigation()
	_go_to_home_station()

func _setup_visuals() -> void:
	# Create crew dot
	sprite = Polygon2D.new()
	sprite.polygon = PackedVector2Array([
		Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
	])
	sprite.color = ShipTypes.get_crew_color(role)
	add_child(sprite)

	# Create role indicator
	role_label = Label.new()
	role_label.text = role.substr(0, 1).to_upper()  # First letter
	role_label.position = Vector2(-4, -20)
	role_label.add_theme_font_size_override("font_size", 10)
	role_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(role_label)

func _setup_navigation() -> void:
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	add_child(nav_agent)

	# Connect navigation signals
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_on_navigation_finished)

func _go_to_home_station() -> void:
	var home = ShipTypes.CREW_HOME_ROOMS.get(role, ShipTypes.RoomType.BRIDGE)
	current_room = home
	target_room = home

# ============================================================================
# PROCESS
# ============================================================================

func _physics_process(delta: float) -> void:
	match current_state:
		ShipTypes.CrewState.IDLE:
			_process_idle(delta)
		ShipTypes.CrewState.MOVING:
			_process_moving(delta)
		ShipTypes.CrewState.WORKING:
			_process_working(delta)
		ShipTypes.CrewState.RESTING:
			_process_resting(delta)
		ShipTypes.CrewState.EMERGENCY:
			_process_emergency(delta)

	_update_visuals()

func _process_idle(_delta: float) -> void:
	# Idle at station - could add subtle animation
	pass

func _process_moving(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_arrive_at_destination()
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_pos)
	var speed = ShipTypes.CREW_RUN_SPEED if is_emergency else ShipTypes.CREW_WALK_SPEED

	velocity = direction * speed
	move_and_slide()

func _process_working(delta: float) -> void:
	if task_duration > 0:
		task_progress += delta
		if task_progress >= task_duration:
			_complete_task()

func _process_resting(delta: float) -> void:
	# Resting is just a long task
	_process_working(delta)

func _process_emergency(delta: float) -> void:
	# Same as moving but faster (handled by is_emergency flag)
	_process_moving(delta)

# ============================================================================
# STATE CHANGES
# ============================================================================

func set_state(new_state: ShipTypes.CrewState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)

func move_to_room(room_type: ShipTypes.RoomType, room_position: Vector2, emergency: bool = false) -> void:
	target_room = room_type
	target_position = room_position
	is_emergency = emergency

	nav_agent.target_position = room_position
	set_state(ShipTypes.CrewState.EMERGENCY if emergency else ShipTypes.CrewState.MOVING)

func start_task(task_type: ShipTypes.TaskType) -> void:
	current_task = task_type
	task_progress = 0.0
	task_duration = ShipTypes.TASK_DURATIONS.get(task_type, 10.0)

	if task_type == ShipTypes.TaskType.REST:
		set_state(ShipTypes.CrewState.RESTING)
	else:
		set_state(ShipTypes.CrewState.WORKING)

	task_started.emit(task_type)

func _arrive_at_destination() -> void:
	current_room = target_room
	set_state(ShipTypes.CrewState.IDLE)
	arrived_at_destination.emit(current_room)

func _complete_task() -> void:
	var completed_task = current_task
	current_task = ShipTypes.TaskType.MONITOR
	task_progress = 0.0
	task_duration = 0.0
	set_state(ShipTypes.CrewState.IDLE)
	task_completed.emit(completed_task)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visuals() -> void:
	# Pulse when working
	if current_state == ShipTypes.CrewState.WORKING:
		var pulse = 0.8 + sin(Time.get_ticks_msec() * 0.01) * 0.2
		sprite.modulate = Color(pulse, pulse, pulse)
	elif current_state == ShipTypes.CrewState.EMERGENCY:
		# Flash when emergency
		var flash = 1.0 if fmod(Time.get_ticks_msec(), 500) < 250 else 0.7
		sprite.modulate = Color(flash, flash * 0.5, flash * 0.5)
	else:
		sprite.modulate = Color.WHITE

func get_state_text() -> String:
	match current_state:
		ShipTypes.CrewState.IDLE: return "Monitoring"
		ShipTypes.CrewState.MOVING: return "Moving"
		ShipTypes.CrewState.WORKING: return _get_task_text()
		ShipTypes.CrewState.RESTING: return "Resting"
		ShipTypes.CrewState.EMERGENCY: return "EMERGENCY"
		_: return "Unknown"

func _get_task_text() -> String:
	match current_task:
		ShipTypes.TaskType.REPAIR: return "Repairing"
		ShipTypes.TaskType.SEAL_BREACH: return "Sealing Breach"
		ShipTypes.TaskType.REROUTE_POWER: return "Rerouting Power"
		ShipTypes.TaskType.TREAT_PATIENT: return "Treating"
		ShipTypes.TaskType.RETRIEVE_SUPPLIES: return "Getting Supplies"
		_: return "Working"

# ============================================================================
# NAVIGATION CALLBACKS
# ============================================================================

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func _on_navigation_finished() -> void:
	if current_state == ShipTypes.CrewState.MOVING or current_state == ShipTypes.CrewState.EMERGENCY:
		_arrive_at_destination()
