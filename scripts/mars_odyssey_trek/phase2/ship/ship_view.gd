extends Node2D
class_name ShipView

## The visual ship view for MOT Phase 2
## Shows the ship interior with rooms and crew moving around

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const ShipRoom = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_room.gd")
const CrewMember = preload("res://scripts/mars_odyssey_trek/phase2/ship/crew_member.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal crew_arrived(crew_role: String, room_type: ShipTypes.RoomType)
signal task_completed(crew_role: String, task_type: ShipTypes.TaskType)
signal room_damaged(room_type: ShipTypes.RoomType, severity: float)
signal room_repaired(room_type: ShipTypes.RoomType)

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
# NODES
# ============================================================================

var rooms: Dictionary = {}  # RoomType -> ShipRoom
var crew: Dictionary = {}   # role -> CrewMember
var navigation_region: NavigationRegion2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_navigation_region()
	_create_ship_layout()
	_create_crew()
	_position_crew_at_stations()

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
	#  [CARGO ]---[LIFE SUP]---[ENGINEERING]
	#
	# Ship travels nose-first (right side) toward Mars

	var center = layout_center
	var h_spacing = 130  # Horizontal spacing between rooms
	var v_spacing = 100  # Vertical spacing between rows

	# Top row (left to right: rear to front)
	_create_room(ShipTypes.RoomType.MEDICAL, center + Vector2(-h_spacing * 1.5, -v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.QUARTERS, center + Vector2(-h_spacing * 0.5, -v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.CORRIDOR, center + Vector2(h_spacing * 0.5, -v_spacing * 0.5), Vector2(60, 50))
	_create_room(ShipTypes.RoomType.BRIDGE, center + Vector2(h_spacing * 1.5, -v_spacing * 0.5))

	# Bottom row (left to right: rear to front)
	_create_room(ShipTypes.RoomType.CARGO_BAY, center + Vector2(-h_spacing * 1.5, v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.LIFE_SUPPORT, center + Vector2(-h_spacing * 0.5, v_spacing * 0.5))
	_create_room(ShipTypes.RoomType.ENGINEERING, center + Vector2(h_spacing * 0.5, v_spacing * 0.5))

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
	# Horizontal corridors connecting rooms in each row
	# Top row connections
	_create_corridor_segment(center + Vector2(-h_spacing, -v_spacing * 0.5), Vector2(30, CORRIDOR_WIDTH))  # Medical-Quarters
	_create_corridor_segment(center + Vector2(0, -v_spacing * 0.5), Vector2(30, CORRIDOR_WIDTH))           # Quarters-Corridor
	_create_corridor_segment(center + Vector2(h_spacing, -v_spacing * 0.5), Vector2(30, CORRIDOR_WIDTH))   # Corridor-Bridge

	# Bottom row connections
	_create_corridor_segment(center + Vector2(-h_spacing, v_spacing * 0.5), Vector2(30, CORRIDOR_WIDTH))   # Cargo-LifeSupport
	_create_corridor_segment(center + Vector2(0, v_spacing * 0.5), Vector2(30, CORRIDOR_WIDTH))            # LifeSupport-Engineering

	# Vertical corridor connecting the two rows (through corridor room)
	_create_corridor_segment(center + Vector2(h_spacing * 0.5, 0), Vector2(CORRIDOR_WIDTH, v_spacing - 40))

func _create_corridor_segment(pos: Vector2, size: Vector2) -> void:
	var corridor = ColorRect.new()
	corridor.size = size
	corridor.position = pos - size / 2
	corridor.color = ShipTypes.get_room_color(ShipTypes.RoomType.CORRIDOR)
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
			member.global_position = home_room.get_work_position()
			member.current_room = home_room_type
			member.target_room = home_room_type

# ============================================================================
# CREW COMMANDS
# ============================================================================

func send_crew_to_room(role: String, room_type: ShipTypes.RoomType, emergency: bool = false) -> void:
	var member = crew.get(role)
	var room = rooms.get(room_type)

	if member and room:
		member.move_to_room(room_type, room.get_work_position(), emergency)

func assign_task_to_crew(role: String, task_type: ShipTypes.TaskType) -> void:
	var member = crew.get(role)
	if member:
		member.start_task(task_type)

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

func get_crew_member(role: String) -> CrewMember:
	return crew.get(role)
