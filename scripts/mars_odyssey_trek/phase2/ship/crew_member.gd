extends CharacterBody2D
class_name CrewMember

## A crew member that moves around the ship and performs tasks
## Supports both continuous movement (normal) and tile-based movement (CRISIS mode)

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const TileGrid = preload("res://scripts/mars_odyssey_trek/phase2/crisis/tile_grid.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: ShipTypes.CrewState)
signal arrived_at_destination(room_type: ShipTypes.RoomType)
signal task_started(task_type: ShipTypes.TaskType)
signal task_completed(task_type: ShipTypes.TaskType)
signal tile_step_completed(tile: Vector2i)
signal item_picked_up(item_type: String)
signal item_dropped(item_type: String)

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

# Game speed multiplier (set externally based on game speed setting)
# 1.0 = normal, higher = faster movement to match faster game time
var game_speed_multiplier: float = 1.0

# Idle wandering state
var idle_timer: float = 0.0
var idle_wander_delay: float = 5.0  # Seconds between wandering
var is_wandering: bool = false
var wander_target: Vector2 = Vector2.ZERO
var current_room_node: Node = null  # Reference to ShipRoom we're in

# Idle productivity state
var is_idle_working: bool = false
var idle_work_activity: String = ""

# Waypoint-based pathfinding
var waypoint_path: Array[Vector2] = []
var waypoint_index: int = 0
var destination_room_node: Node = null

# Navigation (Continuous - Legacy)
var nav_agent: NavigationAgent2D
var path: PackedVector2Array = []
var path_index: int = 0

# Visuals
var sprite: Polygon2D
var role_label: Label
var item_indicator: Polygon2D

# Task progress bar (above crew when working)
var task_bar_bg: ColorRect
var task_bar_fill: ColorRect
var task_label: Label
var current_task_name: String = ""

# Path indicator (animated line showing where crew is going)
var path_indicator: Node2D
var path_dots: Array[Polygon2D] = []
var path_animation_time: float = 0.0
const PATH_DOT_COUNT: int = 6
const PATH_DOT_SPEED: float = 2.0  # How fast dots animate along path

# ============================================================================
# TILE-BASED MOVEMENT (CRISIS Mode)
# ============================================================================

var tile_mode_enabled: bool = false
var tile_grid: TileGrid = null

# Tile position and path
var current_tile: Vector2i = Vector2i.ZERO
var tile_path: Array[Vector2i] = []
var tile_path_index: int = 0
var target_tile: Vector2i = Vector2i.ZERO

# Tile movement state
var tile_move_progress: float = 0.0
var tile_move_duration: float = 0.0
var tile_move_start: Vector2 = Vector2.ZERO
var tile_move_end: Vector2 = Vector2.ZERO
var is_stepping: bool = false

# Inventory (CRISIS mode)
var carried_item: String = ""  # Empty = no item, otherwise item type name
var pickup_progress: float = 0.0
var is_picking_up: bool = false
var is_dropping: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_visuals()
	_setup_navigation()
	_go_to_home_station()

func _setup_visuals() -> void:
	# Create cute astronaut with head and body
	var crew_color = ShipTypes.get_crew_color(role)

	# Container for all parts
	sprite = Polygon2D.new()
	sprite.polygon = PackedVector2Array()  # Empty - just a container
	add_child(sprite)

	# === LEGS (behind body) ===
	var left_leg = Polygon2D.new()
	left_leg.polygon = _create_rounded_rect(Vector2(3, 6), 1)
	left_leg.position = Vector2(-3, 8)
	left_leg.color = crew_color.darkened(0.3)
	sprite.add_child(left_leg)

	var right_leg = Polygon2D.new()
	right_leg.polygon = _create_rounded_rect(Vector2(3, 6), 1)
	right_leg.position = Vector2(3, 8)
	right_leg.color = crew_color.darkened(0.3)
	sprite.add_child(right_leg)

	# === BODY (spacesuit torso) ===
	var body = Polygon2D.new()
	body.polygon = _create_rounded_rect(Vector2(10, 10), 2)
	body.position = Vector2(0, 2)
	body.color = crew_color
	sprite.add_child(body)

	# Suit detail stripe
	var stripe = Polygon2D.new()
	stripe.polygon = PackedVector2Array([
		Vector2(-4, -2), Vector2(4, -2), Vector2(4, 0), Vector2(-4, 0)
	])
	stripe.position = Vector2(0, 2)
	stripe.color = Color.WHITE.darkened(0.1)
	sprite.add_child(stripe)

	# === ARMS ===
	var left_arm = Polygon2D.new()
	left_arm.polygon = _create_rounded_rect(Vector2(3, 5), 1)
	left_arm.position = Vector2(-7, 1)
	left_arm.rotation = 0.3  # Slight angle outward
	left_arm.color = crew_color.darkened(0.2)
	sprite.add_child(left_arm)

	var right_arm = Polygon2D.new()
	right_arm.polygon = _create_rounded_rect(Vector2(3, 5), 1)
	right_arm.position = Vector2(7, 1)
	right_arm.rotation = -0.3
	right_arm.color = crew_color.darkened(0.2)
	sprite.add_child(right_arm)

	# === HEAD (helmet) ===
	var helmet = Polygon2D.new()
	helmet.polygon = _create_circle(7, 10)  # Rounded helmet
	helmet.position = Vector2(0, -7)
	helmet.color = Color(0.9, 0.9, 0.95)  # White helmet
	sprite.add_child(helmet)

	# Visor (darker curved shape)
	var visor = Polygon2D.new()
	visor.polygon = _create_visor(5, 4)
	visor.position = Vector2(0, -7)
	visor.color = Color(0.2, 0.3, 0.5, 0.9)  # Dark blue-tinted glass
	sprite.add_child(visor)

	# Visor reflection (small highlight)
	var reflection = Polygon2D.new()
	reflection.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(-1, -3), Vector2(-2, -1)
	])
	reflection.position = Vector2(0, -7)
	reflection.color = Color(1.0, 1.0, 1.0, 0.4)
	sprite.add_child(reflection)

	# === ROLE INDICATOR (colored band on helmet) ===
	var band = Polygon2D.new()
	band.polygon = PackedVector2Array([
		Vector2(-6, -12), Vector2(6, -12), Vector2(6, -10), Vector2(-6, -10)
	])
	band.color = crew_color
	sprite.add_child(band)

	# Create role label (smaller, above head)
	role_label = Label.new()
	role_label.text = role.substr(0, 1).to_upper()
	role_label.position = Vector2(-3, -24)
	role_label.add_theme_font_size_override("font_size", 8)
	role_label.add_theme_color_override("font_color", crew_color)
	add_child(role_label)

	# Create item indicator (shown when carrying)
	item_indicator = Polygon2D.new()
	item_indicator.polygon = _create_rounded_rect(Vector2(4, 4), 1)
	item_indicator.position = Vector2(10, 0)
	item_indicator.color = Color.YELLOW
	item_indicator.visible = false
	add_child(item_indicator)

	# Create task progress bar (above crew when working)
	_setup_task_progress_bar(crew_color)

	# Create path indicator container
	_setup_path_indicator(crew_color)

func _setup_task_progress_bar(crew_color: Color) -> void:
	## Create a progress bar that appears above crew when working
	var bar_width = 40.0
	var bar_height = 5.0
	var bar_y = -32.0  # Above the crew head

	# Background bar
	task_bar_bg = ColorRect.new()
	task_bar_bg.size = Vector2(bar_width, bar_height)
	task_bar_bg.position = Vector2(-bar_width / 2, bar_y)
	task_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	task_bar_bg.visible = false
	add_child(task_bar_bg)

	# Fill bar
	task_bar_fill = ColorRect.new()
	task_bar_fill.size = Vector2(0, bar_height - 2)
	task_bar_fill.position = Vector2(-bar_width / 2 + 1, bar_y + 1)
	task_bar_fill.color = crew_color.lightened(0.2)
	task_bar_fill.visible = false
	add_child(task_bar_fill)

	# Task label (small text above bar)
	task_label = Label.new()
	task_label.text = ""
	task_label.position = Vector2(-bar_width / 2, bar_y - 12)
	task_label.add_theme_font_size_override("font_size", 7)
	task_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	task_label.visible = false
	add_child(task_label)

func _setup_path_indicator(crew_color: Color) -> void:
	## Create animated path dots to show where crew is moving
	## Each dot is top_level so it renders in world coordinates
	path_indicator = Node2D.new()
	path_indicator.name = "PathIndicator_" + role
	path_indicator.visible = false
	add_child(path_indicator)

	# Pre-create path dots as top_level for world-space positioning
	var dot_color = crew_color.lightened(0.3)
	for i in range(PATH_DOT_COUNT):
		var dot = Polygon2D.new()
		dot.polygon = _create_circle(6, 12)  # Larger, smoother dots
		dot.color = dot_color
		dot.top_level = true  # Each dot renders at world coordinates
		dot.z_index = 8  # Above floor (0), below crew (10)
		dot.visible = false
		path_indicator.add_child(dot)
		path_dots.append(dot)

func _create_rounded_rect(size: Vector2, radius: float) -> PackedVector2Array:
	## Create a simple rounded rectangle polygon
	var points = PackedVector2Array()
	var hw = size.x / 2
	var hh = size.y / 2
	var r = min(radius, min(hw, hh))

	# Top edge
	points.append(Vector2(-hw + r, -hh))
	points.append(Vector2(hw - r, -hh))
	# Top-right corner
	points.append(Vector2(hw, -hh + r))
	# Right edge
	points.append(Vector2(hw, hh - r))
	# Bottom-right corner
	points.append(Vector2(hw - r, hh))
	# Bottom edge
	points.append(Vector2(-hw + r, hh))
	# Bottom-left corner
	points.append(Vector2(-hw, hh - r))
	# Left edge
	points.append(Vector2(-hw, -hh + r))

	return points

func _create_circle(radius: float, segments: int = 12) -> PackedVector2Array:
	## Create a circle polygon
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _create_visor(width: float, height: float) -> PackedVector2Array:
	## Create a curved visor shape
	var points = PackedVector2Array()
	# Top curve
	points.append(Vector2(-width, -height * 0.3))
	points.append(Vector2(-width * 0.7, -height))
	points.append(Vector2(0, -height * 1.1))
	points.append(Vector2(width * 0.7, -height))
	points.append(Vector2(width, -height * 0.3))
	# Bottom curve
	points.append(Vector2(width * 0.8, height * 0.5))
	points.append(Vector2(0, height * 0.7))
	points.append(Vector2(-width * 0.8, height * 0.5))
	return points

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
	# Handle tile-based movement if enabled
	if tile_mode_enabled:
		_process_tile_mode(delta)
	else:
		# Smooth continuous movement (default mode)
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
			ShipTypes.CrewState.EVA:
				_process_eva(delta)
			ShipTypes.CrewState.TETHERED:
				_process_tethered(delta)

	_update_visuals()

	# Update path indicator animation when moving
	if current_state == ShipTypes.CrewState.MOVING or current_state == ShipTypes.CrewState.EMERGENCY:
		_update_path_indicator(delta)
	elif current_state == ShipTypes.CrewState.EVA and waypoint_path.size() > 0:
		_update_path_indicator(delta)

func _process_eva(delta: float) -> void:
	## EVA movement - same as normal but slower and floaty
	if waypoint_path.size() > 0:
		_process_waypoint_movement_eva(delta)
		return

	# Working at exterior location
	if current_state == ShipTypes.CrewState.EVA:
		_process_working(delta)

func _process_waypoint_movement_eva(delta: float) -> void:
	## Move along waypoint path in EVA mode (slower, floaty)
	if waypoint_index >= waypoint_path.size():
		_arrive_at_waypoint_destination()
		return

	var target = waypoint_path[waypoint_index]
	var distance = global_position.distance_to(target)

	if distance < 8.0:
		waypoint_index += 1
		if waypoint_index >= waypoint_path.size():
			_arrive_at_waypoint_destination()
		return

	# Slower EVA movement with slight drift
	var direction = global_position.direction_to(target)
	var eva_speed = ShipTypes.CREW_WALK_SPEED * 0.6 * game_speed_multiplier  # 60% normal speed
	var drift = Vector2(sin(Time.get_ticks_msec() * 0.002) * 0.1, cos(Time.get_ticks_msec() * 0.003) * 0.1)
	global_position += (direction + drift).normalized() * eva_speed * delta

func _process_tethered(delta: float) -> void:
	## Floating on tether - handled by EVAController
	# Add subtle spinning/tumbling motion
	sprite.rotation += delta * 0.5

func _process_idle(delta: float) -> void:
	# Check for idle productivity opportunities
	_check_idle_productivity()

	# Occasional wandering within the room when idle
	if is_wandering:
		_process_wandering(delta)
		return

	idle_timer += delta
	if idle_timer >= idle_wander_delay:
		idle_timer = 0.0
		idle_wander_delay = randf_range(3.0, 10.0)  # Randomize next wander time

		# 40% chance to wander to a new spot
		if randf() < 0.4 and current_room_node and current_room_node.has_method("get_random_idle_position"):
			_start_wander()

func _check_idle_productivity() -> void:
	## Check if crew can help with life support systems while idle
	var new_activity = ""

	match current_room:
		ShipTypes.RoomType.HYDROPONICS:
			# Crew helps tend the plants
			new_activity = "Tending plants"
		ShipTypes.RoomType.LIFE_SUPPORT:
			# Crew monitors the water reclaimer
			new_activity = "Checking systems"
		ShipTypes.RoomType.ENGINEERING:
			# Engineer/scientist can do maintenance
			if role == "engineer" or role == "scientist":
				new_activity = "Maintenance"
		ShipTypes.RoomType.MEDICAL:
			# Medical officer organizes supplies
			if role == "medical":
				new_activity = "Organizing meds"
		ShipTypes.RoomType.BRIDGE:
			# Commander monitors status
			if role == "commander":
				new_activity = "Monitoring"
		_:
			new_activity = ""

	# Update idle work state
	if new_activity != idle_work_activity:
		idle_work_activity = new_activity
		is_idle_working = (new_activity != "")

		# Show/hide idle activity label
		if is_idle_working:
			_show_idle_activity(new_activity)
		else:
			_hide_idle_activity()

func _show_idle_activity(activity: String) -> void:
	## Show subtle idle activity indicator
	if not task_label:
		return

	# Use the task label but with dimmer styling for idle work
	task_label.text = activity
	task_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6, 0.8))
	task_label.visible = true

	# Don't show the progress bar for idle activities
	if task_bar_bg:
		task_bar_bg.visible = false
	if task_bar_fill:
		task_bar_fill.visible = false

func _hide_idle_activity() -> void:
	## Hide idle activity indicator
	if task_label and is_idle_working:
		task_label.visible = false

	is_idle_working = false
	idle_work_activity = ""

func _start_wander() -> void:
	## Start wandering to a random spot in current room
	if not current_room_node:
		return

	wander_target = current_room_node.get_random_idle_position()
	is_wandering = true

func _process_wandering(delta: float) -> void:
	## Move slowly toward wander target
	var distance = global_position.distance_to(wander_target)
	if distance < 3.0:
		is_wandering = false
		return

	var direction = global_position.direction_to(wander_target)
	var wander_speed = ShipTypes.CREW_WALK_SPEED * 0.4 * game_speed_multiplier  # Slow casual walk
	global_position += direction * wander_speed * delta

func _process_moving(delta: float) -> void:
	# Use waypoint path if available
	if waypoint_path.size() > 0:
		_process_waypoint_movement(delta)
		return

	# Fallback to nav agent (legacy)
	if nav_agent.is_navigation_finished():
		_arrive_at_destination()
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_pos)
	var base_speed = ShipTypes.CREW_RUN_SPEED if is_emergency else ShipTypes.CREW_WALK_SPEED
	var speed = base_speed * game_speed_multiplier

	velocity = direction * speed
	move_and_slide()

func _process_waypoint_movement(delta: float) -> void:
	## Move along waypoint path through corridors
	if waypoint_index >= waypoint_path.size():
		_arrive_at_waypoint_destination()
		return

	var target = waypoint_path[waypoint_index]
	var distance = global_position.distance_to(target)

	if distance < 5.0:
		# Reached this waypoint, move to next
		waypoint_index += 1
		if waypoint_index >= waypoint_path.size():
			_arrive_at_waypoint_destination()
		return

	# Move toward current waypoint
	var direction = global_position.direction_to(target)
	var base_speed = ShipTypes.CREW_RUN_SPEED if is_emergency else ShipTypes.CREW_WALK_SPEED
	var speed = base_speed * game_speed_multiplier
	global_position += direction * speed * delta

func _arrive_at_waypoint_destination() -> void:
	## Called when crew reaches final waypoint
	waypoint_path.clear()
	waypoint_index = 0
	current_room = target_room
	current_room_node = destination_room_node
	destination_room_node = null
	_hide_path_indicator()  # Hide path dots when we arrive
	set_state(ShipTypes.CrewState.IDLE)
	arrived_at_destination.emit(current_room)

func _process_working(delta: float) -> void:
	if task_duration > 0:
		task_progress += delta
		# Update progress bar
		var progress = clamp(task_progress / task_duration, 0.0, 1.0)
		update_task_progress(progress)
		if task_progress >= task_duration:
			_complete_task()

func _process_resting(delta: float) -> void:
	# Resting is just a long task
	_process_working(delta)

func _process_emergency(delta: float) -> void:
	# Same as moving but faster (handled by is_emergency flag)
	_process_moving(delta)

# ============================================================================
# TILE-BASED MOVEMENT (CRISIS Mode)
# ============================================================================

func _process_tile_mode(delta: float) -> void:
	## Process tile-based discrete movement

	# Handle pickup/drop actions first
	if is_picking_up or is_dropping:
		_process_pickup_drop(delta)
		return

	# Handle tile stepping
	if is_stepping:
		_process_tile_step(delta)
		return

	# Handle working
	if current_state == ShipTypes.CrewState.WORKING:
		_process_working(delta)
		return

	# Start next step if we have a path
	if tile_path_index < tile_path.size():
		_start_next_tile_step()

func _process_tile_step(delta: float) -> void:
	## Animate movement from one tile to the next
	tile_move_progress += delta

	if tile_move_progress >= tile_move_duration:
		# Step complete - snap to target tile
		global_position = tile_move_end
		is_stepping = false

		# Update tile grid blocking
		if tile_grid:
			tile_grid.unblock_tile(current_tile)
			current_tile = tile_path[tile_path_index]
			tile_grid.block_tile(current_tile, role)

		tile_step_completed.emit(current_tile)
		tile_path_index += 1

		# Check if we've reached destination
		if tile_path_index >= tile_path.size():
			_arrive_at_tile_destination()
	else:
		# Lerp position
		var t = tile_move_progress / tile_move_duration
		global_position = tile_move_start.lerp(tile_move_end, t)

func _start_next_tile_step() -> void:
	## Begin movement to next tile in path
	if tile_path_index >= tile_path.size():
		return

	var next_tile = tile_path[tile_path_index]

	# Check if next tile is blocked by another crew
	if tile_grid and tile_grid.is_tile_blocked(next_tile):
		var blocker = tile_grid.get_blocking_crew(next_tile)
		if blocker != role:
			# Wait for the blocking crew to move (adds delay pressure!)
			return

	is_stepping = true
	tile_move_progress = 0.0
	tile_move_duration = ShipTypes.TILE_RUN_TIME if is_emergency else ShipTypes.TILE_WALK_TIME
	tile_move_start = global_position
	tile_move_end = TileGrid.tile_to_world(next_tile)

	set_state(ShipTypes.CrewState.EMERGENCY if is_emergency else ShipTypes.CrewState.MOVING)

func _arrive_at_tile_destination() -> void:
	## Called when crew reaches final tile in path
	current_room = tile_grid.get_room_at_tile(current_tile) if tile_grid else current_room
	tile_path.clear()
	tile_path_index = 0
	_hide_path_indicator()  # Hide path dots when we arrive
	set_state(ShipTypes.CrewState.IDLE)
	arrived_at_destination.emit(current_room)

func _process_pickup_drop(delta: float) -> void:
	## Process item pickup/drop action
	pickup_progress += delta

	var target_time = ShipTypes.PICKUP_TIME if is_picking_up else ShipTypes.DROP_TIME

	if pickup_progress >= target_time:
		if is_picking_up:
			_complete_pickup()
		else:
			_complete_drop()

func _complete_pickup() -> void:
	is_picking_up = false
	pickup_progress = 0.0
	item_indicator.visible = true
	item_picked_up.emit(carried_item)
	set_state(ShipTypes.CrewState.IDLE)

func _complete_drop() -> void:
	var dropped = carried_item
	carried_item = ""
	is_dropping = false
	pickup_progress = 0.0
	item_indicator.visible = false
	item_dropped.emit(dropped)
	set_state(ShipTypes.CrewState.IDLE)

# ============================================================================
# TILE MODE API
# ============================================================================

func enable_tile_mode(grid: TileGrid) -> void:
	## Switch to tile-based movement mode
	tile_mode_enabled = true
	tile_grid = grid

	# Initialize tile position from current world position
	current_tile = TileGrid.world_to_tile(global_position)

	# Block our current tile
	if tile_grid:
		tile_grid.block_tile(current_tile, role)

func disable_tile_mode() -> void:
	## Switch back to continuous movement
	if tile_grid:
		tile_grid.unblock_crew(role)

	tile_mode_enabled = false
	tile_grid = null
	tile_path.clear()
	is_stepping = false

func move_to_tile(destination: Vector2i, emergency: bool = false) -> bool:
	## Request movement to a tile (CRISIS mode)
	## Returns true if path found, false otherwise

	if not tile_mode_enabled or not tile_grid:
		return false

	is_emergency = emergency
	target_tile = destination

	# Find path
	tile_path = tile_grid.find_path(current_tile, destination, true)

	if tile_path.is_empty():
		return false

	tile_path_index = 1  # Skip current tile (index 0)

	if tile_path.size() > 1:
		set_state(ShipTypes.CrewState.EMERGENCY if emergency else ShipTypes.CrewState.MOVING)

	return true

func move_to_room_tile(room_type: ShipTypes.RoomType, emergency: bool = false) -> bool:
	## Move to a room's work station (CRISIS mode)
	var station_tile = TileGrid.get_room_station_tile(room_type)
	target_room = room_type
	return move_to_tile(station_tile, emergency)

func pickup_item(item_type: String) -> void:
	## Start picking up an item (CRISIS mode)
	if carried_item != "":
		return  # Already carrying something

	carried_item = item_type
	is_picking_up = true
	pickup_progress = 0.0
	set_state(ShipTypes.CrewState.WORKING)

func drop_item() -> void:
	## Start dropping carried item (CRISIS mode)
	if carried_item == "":
		return  # Nothing to drop

	is_dropping = true
	pickup_progress = 0.0
	set_state(ShipTypes.CrewState.WORKING)

func has_item() -> bool:
	return carried_item != ""

func get_carried_item() -> String:
	return carried_item

func get_current_tile() -> Vector2i:
	return current_tile

func get_tile_distance_to(destination: Vector2i) -> int:
	## Get tile distance to a destination
	if tile_grid:
		return tile_grid.get_tile_distance(current_tile, destination)
	return TileGrid.new()._heuristic(current_tile, destination)

func is_at_tile(tile: Vector2i) -> bool:
	return current_tile == tile and not is_stepping

# ============================================================================
# STATE CHANGES
# ============================================================================

func set_state(new_state: ShipTypes.CrewState) -> void:
	if current_state == new_state:
		return

	# Hide idle activity when leaving IDLE state
	if current_state == ShipTypes.CrewState.IDLE and new_state != ShipTypes.CrewState.IDLE:
		_hide_idle_activity()

	current_state = new_state
	state_changed.emit(new_state)

func move_along_path(room_type: ShipTypes.RoomType, path: Array[Vector2], room_node: Node, emergency: bool = false) -> void:
	## Move through a series of waypoints (corridors) to reach destination
	target_room = room_type
	destination_room_node = room_node
	is_emergency = emergency

	# Store waypoint path
	waypoint_path = path
	waypoint_index = 0

	# Start moving to first waypoint
	if waypoint_path.size() > 0:
		target_position = waypoint_path[0]
		_show_path_indicator()  # Show animated path dots
		set_state(ShipTypes.CrewState.EMERGENCY if emergency else ShipTypes.CrewState.MOVING)
	else:
		# No path needed (already there)
		_arrive_at_destination()

func start_task(task_type: ShipTypes.TaskType) -> void:
	current_task = task_type
	task_progress = 0.0
	task_duration = ShipTypes.TASK_DURATIONS.get(task_type, 10.0)

	if task_type == ShipTypes.TaskType.REST:
		set_state(ShipTypes.CrewState.RESTING)
		show_task_progress(_get_task_text(), 0.0)  # Show "Resting" bar
	else:
		set_state(ShipTypes.CrewState.WORKING)
		show_task_progress(_get_task_text(), 0.0)

	task_started.emit(task_type)

func start_named_task(task_name: String, duration: float) -> void:
	## Start a task with a custom name (from TaskManager)
	current_task_name = task_name
	task_progress = 0.0
	task_duration = duration
	set_state(ShipTypes.CrewState.WORKING)
	show_task_progress(task_name, 0.0)
	task_started.emit(ShipTypes.TaskType.MONITOR)  # Generic task type

func _arrive_at_destination() -> void:
	current_room = target_room
	_find_current_room_node()
	_hide_path_indicator()  # Hide path dots when we arrive
	set_state(ShipTypes.CrewState.IDLE)
	arrived_at_destination.emit(current_room)

func _find_current_room_node() -> void:
	## Find the ShipRoom node we're currently in
	current_room_node = null
	var ship_view = get_parent()
	if ship_view and ship_view.has_method("get_room"):
		current_room_node = ship_view.get_room(current_room)

func _complete_task() -> void:
	var completed_task = current_task
	current_task = ShipTypes.TaskType.MONITOR
	current_task_name = ""
	task_progress = 0.0
	task_duration = 0.0
	hide_task_progress()
	set_state(ShipTypes.CrewState.IDLE)
	task_completed.emit(completed_task)

# ============================================================================
# HEALTH/MORALE VISUALS
# ============================================================================

var health_visual: float = 100.0
var morale_visual: float = 100.0
var base_color: Color = Color.WHITE

func set_health_visual(health: float) -> void:
	## Update visual based on crew health
	health_visual = health
	_update_base_color()

func set_morale_visual(morale: float) -> void:
	## Update visual based on crew morale
	morale_visual = morale
	_update_base_color()

func _update_base_color() -> void:
	## Calculate base color from health and morale
	var health_factor = clamp(health_visual / 100.0, 0.3, 1.0)
	var morale_factor = clamp(morale_visual / 100.0, 0.5, 1.0)

	# Low health = more red/dim
	# Low morale = slightly blue/grey
	if health_visual < 50:
		base_color = Color(1.0, health_factor, health_factor)
	elif morale_visual < 40:
		base_color = Color(morale_factor, morale_factor, 1.0)
	else:
		base_color = Color(health_factor, health_factor * morale_factor, morale_factor)

func start_resting() -> void:
	## Crew is too tired - go rest
	start_task(ShipTypes.TaskType.REST)

func finish_task() -> void:
	## External call to finish current task early
	_complete_task()

# ============================================================================
# TASK PROGRESS BAR
# ============================================================================

func show_task_progress(task_name: String, progress: float) -> void:
	## Show task progress bar with name and initial progress
	if not task_bar_bg:
		return

	current_task_name = task_name
	task_bar_bg.visible = true
	task_bar_fill.visible = true
	task_label.visible = true
	task_label.text = task_name
	update_task_progress(progress)

func update_task_progress(progress: float) -> void:
	## Update the task progress bar fill (0.0 to 1.0)
	if not task_bar_fill:
		return

	var max_width = task_bar_bg.size.x - 2
	task_bar_fill.size.x = max_width * clamp(progress, 0.0, 1.0)

	# Color transitions: crew color -> lighter as progress increases
	var base_color = ShipTypes.get_crew_color(role)
	if progress < 0.5:
		# Darker at start
		task_bar_fill.color = base_color.darkened(0.2)
	elif progress < 0.9:
		# Normal in middle
		task_bar_fill.color = base_color.lightened(0.1)
	else:
		# Bright green near completion
		task_bar_fill.color = Color(0.3, 0.9, 0.3)

func hide_task_progress() -> void:
	## Hide the task progress bar
	if task_bar_bg:
		task_bar_bg.visible = false
	if task_bar_fill:
		task_bar_fill.visible = false
	if task_label:
		task_label.visible = false

func set_task_progress_external(progress: float, task_name: String = "") -> void:
	## Set task progress from external source (TaskManager)
	## Used when TaskManager controls task timing instead of CrewMember
	if task_name != "":
		current_task_name = task_name
		if task_label:
			task_label.text = task_name

	if not task_bar_bg or not task_bar_bg.visible:
		show_task_progress(current_task_name if current_task_name else "Working", progress)
	else:
		update_task_progress(progress)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visuals() -> void:
	var final_color = base_color

	# Pulse when working
	if current_state == ShipTypes.CrewState.WORKING:
		var pulse = 0.8 + sin(Time.get_ticks_msec() * 0.01) * 0.2
		final_color = Color(pulse * base_color.r, pulse * base_color.g, pulse * base_color.b)
	elif current_state == ShipTypes.CrewState.EMERGENCY:
		# Flash when emergency
		var flash = 1.0 if fmod(Time.get_ticks_msec(), 500) < 250 else 0.7
		final_color = Color(flash, flash * 0.5 * base_color.g, flash * 0.5 * base_color.b)
	elif current_state == ShipTypes.CrewState.RESTING:
		# Dim when resting
		final_color = base_color * 0.6
	elif current_state == ShipTypes.CrewState.EVA:
		# Bright white-blue tint for EVA suit
		final_color = Color(0.9, 0.95, 1.2)
		z_index = 15  # Above ship hull
	elif current_state == ShipTypes.CrewState.TETHERED:
		# Flashing warning for tethered/drifting
		var flash = 1.0 if fmod(Time.get_ticks_msec(), 300) < 150 else 0.5
		final_color = Color(1.0, flash * 0.8, 0.2)  # Yellow-orange warning
		z_index = 15

	# Reset z_index when back inside
	if current_state != ShipTypes.CrewState.EVA and current_state != ShipTypes.CrewState.TETHERED:
		z_index = 10
		sprite.rotation = 0  # Reset any tumbling

	# Apply fatigue dimming (low health dims the whole sprite)
	if health_visual < 30:
		final_color = final_color.darkened(0.4)
	elif health_visual < 60:
		final_color = final_color.darkened(0.2)

	sprite.modulate = final_color

func get_state_text() -> String:
	match current_state:
		ShipTypes.CrewState.IDLE: return "Monitoring"
		ShipTypes.CrewState.MOVING: return "Moving"
		ShipTypes.CrewState.WORKING: return _get_task_text()
		ShipTypes.CrewState.RESTING: return "Resting"
		ShipTypes.CrewState.EMERGENCY: return "EMERGENCY"
		ShipTypes.CrewState.EVA: return "EVA"
		ShipTypes.CrewState.TETHERED: return "DRIFTING!"
		_: return "Unknown"

func _get_task_text() -> String:
	match current_task:
		ShipTypes.TaskType.REPAIR: return "Repairing"
		ShipTypes.TaskType.SEAL_BREACH: return "Sealing Breach"
		ShipTypes.TaskType.REROUTE_POWER: return "Rerouting Power"
		ShipTypes.TaskType.TREAT_PATIENT: return "Treating"
		ShipTypes.TaskType.RETRIEVE_SUPPLIES: return "Getting Supplies"
		ShipTypes.TaskType.EVA_REPAIR: return "EVA Repair"
		ShipTypes.TaskType.EVA_RESCUE: return "EVA Rescue"
		_: return "Working"

# ============================================================================
# PATH INDICATOR
# ============================================================================

func _update_path_indicator(delta: float) -> void:
	## Animate path dots along the remaining waypoint path
	if waypoint_path.is_empty() or waypoint_index >= waypoint_path.size():
		_hide_path_indicator()
		return

	path_animation_time += delta * PATH_DOT_SPEED

	# Build remaining path from current position
	var remaining_path: Array[Vector2] = [global_position]
	for i in range(waypoint_index, waypoint_path.size()):
		remaining_path.append(waypoint_path[i])

	# Calculate total path length
	var total_length = 0.0
	var segment_lengths: Array[float] = []
	for i in range(remaining_path.size() - 1):
		var seg_len = remaining_path[i].distance_to(remaining_path[i + 1])
		segment_lengths.append(seg_len)
		total_length += seg_len

	if total_length < 20.0:
		# Path too short, hide indicator
		_hide_path_indicator()
		return

	# Position dots along path with animation offset
	var dot_spacing = total_length / float(PATH_DOT_COUNT + 1)
	var animation_offset = fmod(path_animation_time, 1.0) * dot_spacing

	for i in range(PATH_DOT_COUNT):
		var dot = path_dots[i]
		var target_dist = animation_offset + (i + 1) * dot_spacing

		# Skip if beyond path
		if target_dist >= total_length:
			dot.visible = false
			continue

		# Find position along path and set directly
		var pos = _get_position_along_path(remaining_path, segment_lengths, target_dist)
		dot.global_position = pos
		dot.visible = true

		# Fade dots: bright in middle, fade at ends
		var path_progress = target_dist / total_length
		var fade = 1.0 - abs(path_progress - 0.5) * 1.2  # Brightest in middle
		fade = clamp(fade, 0.3, 1.0)
		dot.modulate.a = fade

func _get_position_along_path(path_points: Array[Vector2], segment_lengths: Array[float], distance: float) -> Vector2:
	## Get a position along the path at the given distance from start
	var remaining_dist = distance
	for i in range(segment_lengths.size()):
		if remaining_dist <= segment_lengths[i]:
			var t = remaining_dist / segment_lengths[i]
			return path_points[i].lerp(path_points[i + 1], t)
		remaining_dist -= segment_lengths[i]
	# Return last point if we exceeded path length
	return path_points[path_points.size() - 1]

func _hide_path_indicator() -> void:
	## Hide all path dots
	if path_indicator:
		path_indicator.visible = false
		for dot in path_dots:
			dot.visible = false

func _show_path_indicator() -> void:
	## Show path indicator when movement starts
	path_animation_time = 0.0
	# Dots will be made visible in _update_path_indicator when positions are calculated

# ============================================================================
# NAVIGATION CALLBACKS
# ============================================================================

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func _on_navigation_finished() -> void:
	if current_state == ShipTypes.CrewState.MOVING or current_state == ShipTypes.CrewState.EMERGENCY:
		_arrive_at_destination()
