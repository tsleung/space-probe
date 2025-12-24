extends Node2D
class_name ShipView

## The visual ship view for MOT Phase 2
## Shows the ship interior with rooms and crew moving around

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const ShipRoom = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_room.gd")
const CrewMember = preload("res://scripts/mars_odyssey_trek/phase2/ship/crew_member.gd")
const ShipNavigation = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_navigation.gd")
const EVAController = preload("res://scripts/mars_odyssey_trek/phase2/ship/eva_controller.gd")
const LifeSupportSystems = preload("res://scripts/mars_odyssey_trek/phase2/ship/life_support_systems.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal crew_arrived(crew_role: String, room_type: ShipTypes.RoomType)
signal task_completed(crew_role: String, task_type: ShipTypes.TaskType)
signal room_damaged(room_type: ShipTypes.RoomType, severity: float)
signal room_repaired(room_type: ShipTypes.RoomType)
signal eva_repair_completed(waypoint: int)  # Emitted when EVA repairs exterior surface
signal food_produced(amount: float)  # From hydroponics
signal water_efficiency_changed(efficiency: float)  # From water reclaimer
signal life_support_damaged(system_name: String)
signal life_support_repaired(system_name: String)

# ============================================================================
# SHIP LAYOUT CONSTANTS
# ============================================================================

const ROOM_WIDTH = 100
const ROOM_HEIGHT = 80
const CORRIDOR_WIDTH = 30
const SHIP_PADDING = 15

# Layout offset - positions the interior within the hull cutaway
@export var layout_center: Vector2 = Vector2(400, 270)

# ============================================================================
# ZOOM SETTINGS
# ============================================================================

const ZOOM_MIN: float = 0.5   # Maximum zoom out
const ZOOM_MAX: float = 3.0   # Maximum zoom in
const ZOOM_STEP: float = 0.15  # Zoom increment per scroll
const ZOOM_SMOOTH: float = 0.15  # Tween duration for smooth zoom

var current_zoom: float = 1.0
var target_zoom: float = 1.0
var zoom_center: Vector2 = Vector2.ZERO  # Point to zoom towards
var zoom_tween: Tween = null
var default_position: Vector2 = Vector2.ZERO  # Store original position for reset

# ============================================================================
# NODES
# ============================================================================

var rooms: Dictionary = {}  # RoomType -> ShipRoom
var crew: Dictionary = {}   # role -> CrewMember
var navigation_region: NavigationRegion2D
var ship_nav: ShipNavigation  # Graph-based pathfinding
var eva_ctrl: EVAController   # EVA mechanics controller
var life_support_sys: LifeSupportSystems  # Hydroponics & Water Reclaimer

# ============================================================================
# EVA STATE (managed by EVAController)
# ============================================================================

# Note: EVA state is now managed by EVAController (eva_ctrl)
# These legacy variables are kept for compatibility but not used

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	default_position = position
	_create_navigation_region()
	_create_ship_layout()
	_setup_navigation_graph()
	_setup_eva_controller()
	_setup_life_support_systems()
	_create_crew()
	_position_crew_at_stations()

func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse wheel zoom (works with touchpad pinch gestures too)
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_point(mouse_event.global_position, ZOOM_STEP)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_point(mouse_event.global_position, -ZOOM_STEP)

	# Handle touchpad magnify gesture (macOS)
	if event is InputEventMagnifyGesture:
		var magnify_event = event as InputEventMagnifyGesture
		var zoom_delta = (magnify_event.factor - 1.0) * 0.5
		_zoom_at_point(magnify_event.position, zoom_delta)

	# Reset zoom with 0 key or Home key
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_0 or key_event.keycode == KEY_HOME:
				reset_zoom()

func _zoom_at_point(screen_point: Vector2, zoom_delta: float) -> void:
	## Zoom towards a point on screen
	var old_zoom = target_zoom
	target_zoom = clamp(target_zoom + zoom_delta, ZOOM_MIN, ZOOM_MAX)

	if target_zoom == old_zoom:
		return  # No change

	# Calculate the world position under the cursor before zoom
	var world_point_before = (screen_point - global_position) / current_zoom

	# Kill any existing tween
	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	# Create smooth zoom tween
	zoom_tween = create_tween()
	zoom_tween.set_parallel(true)

	# Tween the scale
	zoom_tween.tween_property(self, "scale", Vector2(target_zoom, target_zoom), ZOOM_SMOOTH)

	# Calculate new position to keep the cursor point stationary
	var new_position = screen_point - world_point_before * target_zoom
	zoom_tween.tween_property(self, "position", new_position, ZOOM_SMOOTH)

	# Update current zoom after tween completes
	zoom_tween.chain().tween_callback(func(): current_zoom = target_zoom)

func reset_zoom() -> void:
	## Reset zoom to default (1.0) and position
	target_zoom = 1.0
	current_zoom = 1.0

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.set_parallel(true)
	zoom_tween.tween_property(self, "scale", Vector2.ONE, ZOOM_SMOOTH * 2)
	zoom_tween.tween_property(self, "position", default_position, ZOOM_SMOOTH * 2)

func _setup_eva_controller() -> void:
	## Initialize the EVA controller with exterior surfaces
	eva_ctrl = EVAController.new()
	eva_ctrl.name = "EVAController"
	add_child(eva_ctrl)
	eva_ctrl.setup(self, ship_nav)

	# Connect EVA signals
	eva_ctrl.eva_started.connect(_on_eva_started)
	eva_ctrl.eva_completed.connect(_on_eva_completed)
	eva_ctrl.crew_drifted.connect(_on_crew_drifted)
	eva_ctrl.rescue_completed.connect(_on_rescue_completed)
	eva_ctrl.eva_repair_completed.connect(_on_eva_repair_completed)

func _setup_life_support_systems() -> void:
	## Initialize hydroponics in Hydroponics room, water reclaimer in Life Support room
	life_support_sys = LifeSupportSystems.new()
	life_support_sys.name = "LifeSupportSystems"
	add_child(life_support_sys)

	# Position hydroponics in the dedicated Hydroponics room
	var hydroponics_room = rooms.get(ShipTypes.RoomType.HYDROPONICS)
	# Position water reclaimer in Life Support room
	var life_support_room = rooms.get(ShipTypes.RoomType.LIFE_SUPPORT)

	if hydroponics_room and life_support_room:
		life_support_sys.setup_separate(hydroponics_room.position, life_support_room.position)
	elif hydroponics_room:
		life_support_sys.setup(hydroponics_room.position)
	elif life_support_room:
		life_support_sys.setup(life_support_room.position)

	# Connect signals
	life_support_sys.food_produced.connect(_on_food_produced)
	life_support_sys.water_recycled.connect(_on_water_recycled)
	life_support_sys.system_damaged.connect(_on_life_support_damaged)
	life_support_sys.system_repaired.connect(_on_life_support_repaired)

func _on_food_produced(amount: float) -> void:
	print("[LIFE SUPPORT] Hydroponics produced %.2f food" % amount)
	food_produced.emit(amount)

func _on_water_recycled(efficiency: float) -> void:
	water_efficiency_changed.emit(efficiency)

func _on_life_support_damaged(system_name: String) -> void:
	print("[LIFE SUPPORT] %s is damaged!" % system_name.capitalize())
	flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(1.0, 0.5, 0.0))
	life_support_damaged.emit(system_name)

func _on_life_support_repaired(system_name: String) -> void:
	print("[LIFE SUPPORT] %s repaired" % system_name.capitalize())
	flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.3, 0.9, 0.3))
	life_support_repaired.emit(system_name)

func _on_eva_started(crew_role: String, target: int) -> void:
	print("[SHIP] EVA started: %s -> %s" % [crew_role, ShipNavigation.get_exterior_name(target)])

func _on_eva_completed(crew_role: String, success: bool) -> void:
	print("[SHIP] EVA completed: %s (success=%s)" % [crew_role, success])

func _on_crew_drifted(crew_role: String) -> void:
	print("[SHIP] ALERT: %s drifted on tether!" % crew_role.capitalize())
	flash_all_rooms(Color(1.0, 0.5, 0.0))  # Orange warning flash

func _on_rescue_completed(victim_role: String) -> void:
	print("[SHIP] %s safely rescued" % victim_role.capitalize())
	flash_all_rooms(Color(0.3, 0.8, 0.3))  # Green success flash

func _on_eva_repair_completed(waypoint: int) -> void:
	## Forward repair signal to be connected by phase2_integrated_ui
	print("[SHIP] EVA repair completed at %s" % ShipNavigation.get_exterior_name(waypoint))
	flash_all_rooms(Color(0.2, 0.9, 0.4))  # Bright green for repair
	eva_repair_completed.emit(waypoint)

func _setup_navigation_graph() -> void:
	## Initialize the waypoint-based navigation system
	ship_nav = ShipNavigation.new()

	# Collect room positions
	var room_positions: Dictionary = {}
	for room_type in rooms:
		room_positions[room_type] = rooms[room_type].global_position

	ship_nav.setup(layout_center, room_positions)

func _create_navigation_region() -> void:
	navigation_region = NavigationRegion2D.new()
	add_child(navigation_region)

	# Create navigation polygon covering the whole ship
	# Will be refined when rooms are created
	var nav_poly = NavigationPolygon.new()
	navigation_region.navigation_polygon = nav_poly

func _create_ship_layout() -> void:
	# Ship layout (horizontal orientation for space travel):
	#
	#  [MEDICAL]---[QUARTERS]---[CORRIDOR]---[BRIDGE]  (nose/front)
	#                              |
	#  [HYDRO ]---[LIFE SUP]---[ENGINEERING]
	#     |
	#  [CARGO ]
	#
	# Ship travels nose-first (right side) toward Mars
	# Hydroponics is connected to Cargo Bay (supplies) and Life Support (water/O2)

	var center = layout_center
	var h_spacing = 130  # Horizontal spacing between rooms
	var v_spacing = 100  # Vertical spacing between rows

	# Top row (left to right: rear to front)
	_create_room(ShipTypes.RoomType.MEDICAL, center + Vector2(-h_spacing * 1.5, -v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.QUARTERS, center + Vector2(-h_spacing * 0.5, -v_spacing * 0.5))
	# Corridor junction is minimal - just a small connector, no label
	var corridor_room = _create_room(ShipTypes.RoomType.CORRIDOR, center + Vector2(h_spacing * 0.5, -v_spacing * 0.5), Vector2(30, 30))
	corridor_room.hide_label()  # Don't show "Corridor" label
	_create_room(ShipTypes.RoomType.BRIDGE, center + Vector2(h_spacing * 1.5, -v_spacing * 0.5))

	# Middle row (left to right: rear to front)
	_create_room(ShipTypes.RoomType.HYDROPONICS, center + Vector2(-h_spacing * 1.5, v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.LIFE_SUPPORT, center + Vector2(-h_spacing * 0.5, v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.ENGINEERING, center + Vector2(h_spacing * 0.5, v_spacing * 0.5))

	# Bottom row - Cargo Bay (larger, below Hydroponics for easy supply access)
	_create_room(ShipTypes.RoomType.CARGO_BAY, center + Vector2(-h_spacing * 1.5, v_spacing * 1.5), Vector2(ROOM_WIDTH, ROOM_HEIGHT * 0.8))

	# Create connecting corridors
	_create_corridors(center, h_spacing, v_spacing)

	# Build navigation mesh
	_build_navigation_mesh()

func _create_room(room_type: ShipTypes.RoomType, pos: Vector2, size: Vector2 = Vector2(ROOM_WIDTH, ROOM_HEIGHT)) -> ShipRoom:
	var room = ShipRoom.new()
	room.room_type = room_type
	room.room_size = size
	room.position = pos
	room.name = "Room_" + ShipTypes.get_room_name(room_type).replace(" ", "_")

	# Connect signals
	room.damage_started.connect(_on_room_damage_started.bind(room_type))
	room.damage_repaired.connect(_on_room_damage_repaired.bind(room_type))

	add_child(room)
	rooms[room_type] = room
	return room

func _create_corridors(center: Vector2, h_spacing: float, v_spacing: float) -> void:
	# Minimal corridor indicators - just thin lines connecting rooms
	# Less visually cluttered than full corridor segments

	# Horizontal connectors - Top row (thin lines)
	_create_corridor_line(
		center + Vector2(-h_spacing * 1.5 + 50, -v_spacing * 0.5),
		center + Vector2(-h_spacing * 0.5 - 50, -v_spacing * 0.5)
	)  # Medical -> Quarters

	_create_corridor_line(
		center + Vector2(-h_spacing * 0.5 + 50, -v_spacing * 0.5),
		center + Vector2(h_spacing * 0.5 - 30, -v_spacing * 0.5)
	)  # Quarters -> Corridor junction

	_create_corridor_line(
		center + Vector2(h_spacing * 0.5 + 30, -v_spacing * 0.5),
		center + Vector2(h_spacing * 1.5 - 50, -v_spacing * 0.5)
	)  # Corridor junction -> Bridge

	# Horizontal connectors - Middle row
	_create_corridor_line(
		center + Vector2(-h_spacing * 1.5 + 50, v_spacing * 0.5),
		center + Vector2(-h_spacing * 0.5 - 50, v_spacing * 0.5)
	)  # Hydro -> Life Support

	_create_corridor_line(
		center + Vector2(-h_spacing * 0.5 + 50, v_spacing * 0.5),
		center + Vector2(h_spacing * 0.5 - 50, v_spacing * 0.5)
	)  # Life Support -> Engineering

	# Vertical connector - Top to Middle row (through corridor junction)
	_create_corridor_line(
		center + Vector2(h_spacing * 0.5, -v_spacing * 0.5 + 25),
		center + Vector2(h_spacing * 0.5, v_spacing * 0.5 - 40)
	)

	# Vertical connector - Hydroponics to Cargo Bay
	_create_corridor_line(
		center + Vector2(-h_spacing * 1.5, v_spacing * 0.5 + 40),
		center + Vector2(-h_spacing * 1.5, v_spacing * 1.5 - 40)
	)

func _create_corridor_line(from: Vector2, to: Vector2) -> void:
	## Create a thin corridor line connecting two points
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 8  # Thin corridor
	line.default_color = Color(0.3, 0.3, 0.35, 0.6)  # Semi-transparent dark gray
	line.z_index = -1  # Behind rooms
	add_child(line)

func _create_corridor_segment(pos: Vector2, size: Vector2) -> void:
	# Kept for backward compatibility but made more subtle
	var corridor = ColorRect.new()
	corridor.size = size
	corridor.position = pos - size / 2
	corridor.color = Color(0.25, 0.25, 0.3, 0.4)  # More transparent
	corridor.z_index = -1  # Behind rooms
	add_child(corridor)

func _build_navigation_mesh() -> void:
	# Create a simple navigation polygon covering all walkable areas
	var nav_poly = NavigationPolygon.new()

	# Cover the ship interior based on layout_center
	var center = layout_center
	var half_width = 220.0
	var half_height = 100.0

	var outline = PackedVector2Array([
		center + Vector2(-half_width, -half_height),   # Top-left
		center + Vector2(half_width, -half_height),    # Top-right
		center + Vector2(half_width, half_height),     # Bottom-right
		center + Vector2(-half_width, half_height)     # Bottom-left
	])

	nav_poly.add_outline(outline)

	# Use the newer navigation mesh baking API
	var source_geometry = NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geometry, navigation_region)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)

	navigation_region.navigation_polygon = nav_poly

func _create_crew() -> void:
	var roles = ["commander", "engineer", "scientist", "medical"]

	for role in roles:
		var crew_member = CrewMember.new()
		crew_member.role = role
		crew_member.name = "Crew_" + role.capitalize()

		# Connect signals
		crew_member.arrived_at_destination.connect(_on_crew_arrived.bind(role))
		crew_member.task_completed.connect(_on_crew_task_completed.bind(role))

		add_child(crew_member)
		crew[role] = crew_member

func _position_crew_at_stations() -> void:
	for role in crew:
		var member = crew[role]
		var home_room_type = ShipTypes.CREW_HOME_ROOMS.get(role, ShipTypes.RoomType.BRIDGE)
		var home_room = rooms.get(home_room_type)

		if home_room:
			# Start at a random spot in the room for variety
			member.global_position = home_room.get_random_idle_position()
			member.current_room = home_room_type
			member.target_room = home_room_type
			member.current_room_node = home_room  # Enable idle wandering

# ============================================================================
# CREW COMMANDS
# ============================================================================

func send_crew_to_room(role: String, room_type: ShipTypes.RoomType, emergency: bool = false) -> void:
	var member = crew.get(role)
	var room = rooms.get(room_type)

	if member and room:
		# Get waypoint path through corridors
		var waypoint_path = ship_nav.find_path(member.current_room, room_type)
		# Add final destination (random spot in room)
		waypoint_path.append(room.get_random_idle_position())
		member.move_along_path(room_type, waypoint_path, room, emergency)

func assign_task_to_crew(role: String, task_type: ShipTypes.TaskType) -> void:
	var member = crew.get(role)
	if member:
		member.start_task(task_type)

func send_crew_to_room_with_task(role: String, room_type: int, task_type: ShipTypes.TaskType) -> void:
	## Send crew to a room and start a task when they arrive
	var member = crew.get(role)
	var room = rooms.get(room_type)

	if not member:
		print("[SHIP] Warning: No crew member with role '%s'" % role)
		return
	if not room:
		print("[SHIP] Warning: No room of type %d" % room_type)
		return

	# Store the task to start on arrival
	if not member.has_meta("pending_task"):
		pass  # OK to add new meta
	member.set_meta("pending_task", task_type)

	# Connect to arrival signal (one-shot)
	var callback = func(arrived_room: int):
		if arrived_room == room_type:
			var pending = member.get_meta("pending_task", -1)
			if pending >= 0:
				member.start_task(pending)
				member.remove_meta("pending_task")
				print("[SHIP] %s arrived at %s, starting task" % [role, ShipTypes.get_room_name(room_type)])

	member.arrived_at_destination.connect(callback, CONNECT_ONE_SHOT)

	# Get waypoint path and send crew
	var waypoint_path = ship_nav.find_path(member.current_room, room_type)
	waypoint_path.append(room.get_work_position())  # Go to work position, not random spot
	member.move_along_path(room_type, waypoint_path, room, false)
	print("[SHIP] Sending %s to %s for task" % [role, ShipTypes.get_room_name(room_type)])

func send_nearest_crew_to_room(room_type: ShipTypes.RoomType, emergency: bool = false) -> String:
	var room = rooms.get(room_type)
	if not room:
		return ""

	var nearest_role = ""
	var nearest_dist = INF

	for role in crew:
		var member = crew[role]
		if member.current_state == ShipTypes.CrewState.IDLE:
			var dist = member.global_position.distance_to(room.get_work_position())
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_role = role

	if nearest_role:
		send_crew_to_room(nearest_role, room_type, emergency)

	return nearest_role

# ============================================================================
# DAMAGE SYSTEM
# ============================================================================

func damage_room(room_type: ShipTypes.RoomType, severity: float = 0.5) -> void:
	var room = rooms.get(room_type)
	if room:
		room.apply_damage(severity)
		room_damaged.emit(room_type, severity)

func repair_room(room_type: ShipTypes.RoomType) -> void:
	var room = rooms.get(room_type)
	if room:
		room.repair_damage()
		room_repaired.emit(room_type)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_crew_arrived(room_type: ShipTypes.RoomType, role: String) -> void:
	crew_arrived.emit(role, room_type)

func _on_crew_task_completed(task_type: ShipTypes.TaskType, role: String) -> void:
	task_completed.emit(role, task_type)

func _on_room_damage_started(severity: float, room_type: ShipTypes.RoomType) -> void:
	room_damaged.emit(room_type, severity)

func _on_room_damage_repaired(room_type: ShipTypes.RoomType) -> void:
	room_repaired.emit(room_type)

# ============================================================================
# GETTERS
# ============================================================================

func get_crew_status() -> Dictionary:
	var status = {}
	for role in crew:
		var member = crew[role]
		status[role] = {
			"state": member.get_state_text(),
			"room": ShipTypes.get_room_name(member.current_room),
			"position": member.global_position
		}
	return status

func get_room(room_type: ShipTypes.RoomType) -> ShipRoom:
	return rooms.get(room_type)

func get_room_position(room_type: int) -> Vector2:
	## Get the center position of a room
	var room = rooms.get(room_type)
	if room:
		return room.position
	return layout_center  # Fallback to ship center

func get_crew_member(role: String) -> CrewMember:
	return crew.get(role)

func set_crew_game_speed(multiplier: float) -> void:
	## Set the game speed multiplier for all crew members
	## This makes crew move proportionally faster when game speed increases
	for role in crew:
		var member = crew[role]
		member.game_speed_multiplier = multiplier

# ============================================================================
# PHASE 2 STORE INTEGRATION
# ============================================================================

func show_repair_progress(room_type: ShipTypes.RoomType, progress: float) -> void:
	## Show repair progress overlay on a room (0.0 to 1.0)
	var room = rooms.get(room_type)
	if room and room.has_method("show_repair_progress"):
		room.show_repair_progress(progress)

func hide_repair_progress(room_type: ShipTypes.RoomType) -> void:
	## Hide repair progress overlay on a room
	var room = rooms.get(room_type)
	if room and room.has_method("hide_repair_progress"):
		room.hide_repair_progress()

func start_eva(crew_role: String, target_waypoint: int = -1) -> void:
	## Start an EVA for the specified crew member
	## If target_waypoint is -1, picks a random exterior target
	print("[EVA-DEBUG] ShipView.start_eva called: role=%s, waypoint=%d" % [crew_role, target_waypoint])
	print("[EVA-DEBUG] eva_ctrl is null: %s" % (eva_ctrl == null))
	print("[EVA-DEBUG] crew dict keys: %s" % str(crew.keys()))
	print("[EVA-DEBUG] ship_nav is null: %s" % (ship_nav == null))

	if not eva_ctrl:
		push_error("[EVA-DEBUG] CRITICAL: eva_ctrl is NULL!")
		return

	if target_waypoint == -1:
		target_waypoint = ShipNavigation.get_random_exterior_target()
		print("[EVA-DEBUG] Random target selected: %d" % target_waypoint)

	print("[EVA-DEBUG] Calling eva_ctrl.start_eva('%s', %d)..." % [crew_role, target_waypoint])
	eva_ctrl.start_eva(crew_role, target_waypoint)
	print("[EVA-DEBUG] eva_ctrl.start_eva() returned")

func complete_eva(crew_role: String, success: bool = true) -> void:
	## Complete an active EVA
	eva_ctrl.complete_eva(crew_role, success)

func check_eva_drift(crew_role: String) -> bool:
	## Check if crew drifts during EVA work (call after work is done)
	return eva_ctrl.check_for_drift(crew_role)

func is_crew_on_eva(crew_role: String) -> bool:
	return eva_ctrl.is_on_eva(crew_role)

func update_crew_from_state(p2_crew: Array) -> void:
	## Sync visual crew with Phase2Store crew state
	for p2_member in p2_crew:
		var role_name = p2_member.get("role", "")
		var visual_role = ShipTypes.get_visual_role(role_name)

		var visual_member = crew.get(visual_role)
		if not visual_member:
			continue

		# Update visual based on crew stats
		var health = p2_member.get("health", 100)
		var morale = p2_member.get("morale", 100)
		var fatigue = p2_member.get("fatigue", 0)

		# Apply visual effects
		if visual_member.has_method("set_health_visual"):
			visual_member.set_health_visual(health)

		if visual_member.has_method("set_morale_visual"):
			visual_member.set_morale_visual(morale)

		# High fatigue = crew should go rest
		if fatigue > 80 and visual_member.current_state == ShipTypes.CrewState.IDLE:
			send_crew_to_room(visual_role, ShipTypes.RoomType.QUARTERS, false)
			visual_member.start_task(ShipTypes.TaskType.REST)

func sync_container_status(containers: Array) -> void:
	## Sync room damage states with P2 container status
	for container in containers:
		var container_id = container.get("id", "")
		var status = container.get("status", 0)  # 0 = NOMINAL
		var room_type = ShipTypes.get_room_for_container(container_id)

		var room = rooms.get(room_type)
		if not room:
			continue

		# NOMINAL = 0, anything else = damaged/blocked
		if status == 0:
			if room.is_damaged:
				room.repair_damage()
		else:
			if not room.is_damaged:
				room.apply_damage(0.7)

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func flash_room(room_type: ShipTypes.RoomType, color: Color) -> void:
	## Flash a room with a color to indicate activity
	var room = rooms.get(room_type)
	if room and room.has_method("flash"):
		room.flash(color)

func flash_all_rooms(color: Color) -> void:
	## Flash all rooms (for ship-wide alerts)
	for room_type in rooms:
		var room = rooms[room_type]
		if room and room.has_method("flash"):
			room.flash(color)

# ============================================================================
# LIFE SUPPORT SYSTEMS
# ============================================================================

func process_life_support_hour(current_power: float) -> Dictionary:
	## Process one hour of life support systems
	## Returns: {food_produced, water_efficiency, power_consumed}
	if not life_support_sys:
		return {"food_produced": 0.0, "water_efficiency": 0.85, "power_consumed": 0.0}

	# Update idle crew counts for efficiency boost
	_update_idle_crew_counts()

	return life_support_sys.process_hour(current_power)

func _update_idle_crew_counts() -> void:
	## Count idle crew in hydroponics and life support rooms
	var hydroponics_count = 0
	var life_support_count = 0

	for role in crew:
		var member = crew[role]
		if member.current_state == ShipTypes.CrewState.IDLE:
			if member.current_room == ShipTypes.RoomType.HYDROPONICS:
				hydroponics_count += 1
			elif member.current_room == ShipTypes.RoomType.LIFE_SUPPORT:
				life_support_count += 1

	if life_support_sys:
		life_support_sys.set_idle_crew_counts(hydroponics_count, life_support_count)

func set_hydroponics_power_level(level: int) -> void:
	## Set hydroponics power level (0=OFF, 1=LOW, 2=NORMAL, 3=HIGH)
	if life_support_sys:
		life_support_sys.set_hydroponics_power(level)

func get_hydroponics_status() -> Dictionary:
	if not life_support_sys:
		return {}
	return life_support_sys.get_hydroponics_status()

func get_water_reclaimer_status() -> Dictionary:
	if not life_support_sys:
		return {}
	return life_support_sys.get_water_reclaimer_status()

func get_current_water_efficiency() -> float:
	if not life_support_sys:
		return 0.85
	return life_support_sys.get_current_water_efficiency()

func damage_life_support_system(system_name: String, amount: float) -> void:
	## Damage a life support system (hydroponics, water_reclaimer, solar_panels, co2_scrubber)
	if not life_support_sys:
		return
	match system_name:
		"hydroponics":
			life_support_sys.damage_hydroponics(amount)
		"water_reclaimer":
			life_support_sys.damage_water_reclaimer(amount)
		"solar_panels":
			life_support_sys.damage_solar_panels(amount)
		"co2_scrubber":
			life_support_sys.damage_co2_scrubber(amount)

func repair_life_support_system(system_name: String, amount: float) -> void:
	## Repair a life support system
	if not life_support_sys:
		return
	match system_name:
		"hydroponics":
			life_support_sys.repair_hydroponics(amount)
		"water_reclaimer":
			life_support_sys.repair_water_reclaimer(amount)
		"solar_panels":
			life_support_sys.repair_solar_panels(amount)
		"co2_scrubber":
			life_support_sys.repair_co2_scrubber(amount)

func get_solar_panels_status() -> Dictionary:
	if not life_support_sys:
		return {}
	return life_support_sys.get_solar_panels_status()

func get_co2_scrubber_status() -> Dictionary:
	if not life_support_sys:
		return {}
	return life_support_sys.get_co2_scrubber_status()

func get_all_systems_status() -> Dictionary:
	if not life_support_sys:
		return {}
	return life_support_sys.get_all_systems_status()

func save_life_support_state() -> Dictionary:
	if not life_support_sys:
		return {}
	return life_support_sys.save_state()

func load_life_support_state(state: Dictionary) -> void:
	if life_support_sys:
		life_support_sys.load_state(state)
