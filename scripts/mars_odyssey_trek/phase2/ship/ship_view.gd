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
# EVA STATE
# ============================================================================

var eva_active: bool = false
var eva_crew_role: String = ""
var eva_tether: Line2D
var eva_airlock_position: Vector2

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_navigation_region()
	_create_ship_layout()
	_create_crew()
	_create_eva_tether()
	_position_crew_at_stations()

func _process(delta: float) -> void:
	# Update EVA tether position
	if eva_active and eva_tether and eva_crew_role:
		var crew_member = crew.get(eva_crew_role)
		if crew_member:
			eva_tether.set_point_position(1, crew_member.global_position)
			# Add slight wave to tether for visual interest
			var time = Time.get_ticks_msec() / 1000.0
			var wave_offset = Vector2(0, sin(time * 3.0) * 3.0)
			eva_tether.set_point_position(1, crew_member.global_position + wave_offset)

func _create_eva_tether() -> void:
	## Create the tether line for EVA operations
	eva_tether = Line2D.new()
	eva_tether.name = "EVATether"
	eva_tether.width = 2.0
	eva_tether.default_color = Color(0.8, 0.8, 0.2, 0.9)  # Yellow safety tether
	eva_tether.begin_cap_mode = Line2D.LINE_CAP_ROUND
	eva_tether.end_cap_mode = Line2D.LINE_CAP_ROUND
	eva_tether.joint_mode = Line2D.LINE_JOINT_ROUND
	eva_tether.visible = false
	eva_tether.z_index = 9  # Behind crew (z_index 10) but above ship
	add_child(eva_tether)

	# Set airlock position (left side of cargo bay)
	eva_airlock_position = layout_center + Vector2(-195, 50)  # Near cargo bay, left edge

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

func trigger_eva_visual(crew_role: String) -> void:
	## Visual effect for EVA - crew member goes "outside" the ship with tether
	var member = crew.get(crew_role)
	if not member:
		return

	eva_active = true
	eva_crew_role = crew_role

	# Store original z-index to restore later
	var original_z = member.z_index

	# ========================================
	# PHASE 1: Crew goes to airlock (cargo bay)
	# ========================================
	print("[EVA] %s heading to airlock..." % crew_role.capitalize())
	send_crew_to_room(crew_role, ShipTypes.RoomType.CARGO_BAY, true)
	await get_tree().create_timer(1.5).timeout

	# Move to specific airlock position within cargo bay
	var airlock_tween = create_tween()
	airlock_tween.tween_property(member, "global_position", eva_airlock_position, 0.8)
	await airlock_tween.finished
	await get_tree().create_timer(0.5).timeout  # Suiting up

	# ========================================
	# PHASE 2: Setup tether and exit airlock
	# ========================================
	print("[EVA] Exiting airlock, tether attached...")

	# Initialize tether from airlock to crew position
	eva_tether.clear_points()
	eva_tether.add_point(eva_airlock_position)
	eva_tether.add_point(member.global_position)
	eva_tether.visible = true

	# Move outside ship (higher z-index to appear on top of hull)
	member.z_index = 10

	# Change appearance to indicate EVA suit (brighter, blue-white tint)
	member.sprite.modulate = Color(0.9, 0.95, 1.3)

	# Exit airlock - move outside hull
	var exit_position = Vector2(layout_center.x - 280, layout_center.y + 30)
	var exit_tween = create_tween()
	exit_tween.tween_property(member, "global_position", exit_position, 1.2)
	await exit_tween.finished

	# ========================================
	# PHASE 3: Work along hull (inspection/retrieval)
	# ========================================
	print("[EVA] Performing EVA work along hull...")

	# EVA work path - moves along the outside of the ship
	var work_points = [
		Vector2(layout_center.x - 300, layout_center.y - 30),   # Move up along hull
		Vector2(layout_center.x - 330, layout_center.y - 60),   # Top inspection point
		Vector2(layout_center.x - 350, layout_center.y),        # Far point - fully extended tether
		Vector2(layout_center.x - 330, layout_center.y + 60),   # Bottom inspection point
		Vector2(layout_center.x - 300, layout_center.y + 30),   # Return toward airlock side
	]

	for point in work_points:
		var work_tween = create_tween()
		work_tween.tween_property(member, "global_position", point, 0.8)
		await work_tween.finished
		await get_tree().create_timer(0.3).timeout  # Brief pause at each work point

	# ========================================
	# PHASE 4: Return through airlock
	# ========================================
	print("[EVA] Returning to airlock...")

	# Return to exit position
	var return_exit_tween = create_tween()
	return_exit_tween.tween_property(member, "global_position", exit_position, 0.8)
	await return_exit_tween.finished

	# Return to airlock
	var return_airlock_tween = create_tween()
	return_airlock_tween.tween_property(member, "global_position", eva_airlock_position, 1.0)
	await return_airlock_tween.finished

	# Hide tether
	eva_tether.visible = false
	eva_active = false
	eva_crew_role = ""

	await get_tree().create_timer(0.3).timeout  # Removing suit

	# ========================================
	# PHASE 5: Return to interior
	# ========================================
	print("[EVA] EVA complete, %s returning to station" % crew_role.capitalize())

	# Restore normal appearance and z-index
	member.z_index = original_z
	member.sprite.modulate = Color.WHITE

	# Return to cargo bay interior position
	var cargo_position = rooms[ShipTypes.RoomType.CARGO_BAY].get_work_position()
	var interior_tween = create_tween()
	interior_tween.tween_property(member, "global_position", cargo_position, 0.6)
	await interior_tween.finished

	# Flash room to indicate successful return
	flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.3, 0.8, 0.3))

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
