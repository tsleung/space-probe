extends RefCounted
class_name ShipNavigation

## Graph-based navigation for crew movement through the ship
## Defines waypoints and connections so crew walk through corridors, not walls

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# WAYPOINT DEFINITIONS
# ============================================================================

## Waypoint IDs - rooms and corridor junctions
enum Waypoint {
	# Rooms (match RoomType enum)
	BRIDGE,
	ENGINEERING,
	LIFE_SUPPORT,
	MEDICAL,
	QUARTERS,
	CARGO_BAY,
	HYDROPONICS,          # New: Potato farm room
	# Corridor waypoints
	CORRIDOR_CENTER,      # Central corridor hub
	CORRIDOR_UPPER_LEFT,  # Between Medical and Quarters
	CORRIDOR_UPPER_RIGHT, # Between Quarters and Bridge
	CORRIDOR_MIDDLE_LEFT, # Between Hydroponics and Life Support
	CORRIDOR_MIDDLE_RIGHT,# Between Life Support and Engineering
	CORRIDOR_VERTICAL,    # Vertical connection between rows
	CORRIDOR_HYDRO_CARGO, # Vertical between Hydroponics and Cargo Bay
	# Exterior waypoints (EVA)
	AIRLOCK,              # Exit point from cargo bay
	# Hull traversal waypoints - crew walks along hull exterior
	HULL_TOP,             # Top of hull (crew climbs up from airlock)
	HULL_LEFT,            # Left side of hull (toward solar panels)
	HULL_RIGHT,           # Right side of hull (toward engine)
	# Exterior work destinations
	EXTERIOR_ENGINE,      # Engine maintenance area (right side)
	EXTERIOR_ANTENNA,     # Antenna array (top/nose)
	EXTERIOR_SOLAR,       # Solar panels (left/top side)
}

## Graph edges - which waypoints connect directly
## Layout:
##   [MEDICAL]---[QUARTERS]---[CORRIDOR]---[BRIDGE]
##                               |
##   [HYDRO ]---[LIFE SUP]---[ENGINEERING]
##      |
##   [CARGO ]
const CONNECTIONS: Dictionary = {
	# Room connections to corridors
	Waypoint.BRIDGE: [Waypoint.CORRIDOR_UPPER_RIGHT],
	Waypoint.ENGINEERING: [Waypoint.CORRIDOR_MIDDLE_RIGHT, Waypoint.CORRIDOR_VERTICAL],
	Waypoint.LIFE_SUPPORT: [Waypoint.CORRIDOR_MIDDLE_LEFT, Waypoint.CORRIDOR_MIDDLE_RIGHT],
	Waypoint.MEDICAL: [Waypoint.CORRIDOR_UPPER_LEFT],
	Waypoint.QUARTERS: [Waypoint.CORRIDOR_UPPER_LEFT, Waypoint.CORRIDOR_UPPER_RIGHT, Waypoint.CORRIDOR_CENTER],
	Waypoint.HYDROPONICS: [Waypoint.CORRIDOR_MIDDLE_LEFT, Waypoint.CORRIDOR_HYDRO_CARGO],
	Waypoint.CARGO_BAY: [Waypoint.CORRIDOR_HYDRO_CARGO, Waypoint.AIRLOCK],

	# Corridor connections
	Waypoint.CORRIDOR_CENTER: [Waypoint.QUARTERS, Waypoint.CORRIDOR_VERTICAL],
	Waypoint.CORRIDOR_UPPER_LEFT: [Waypoint.MEDICAL, Waypoint.QUARTERS],
	Waypoint.CORRIDOR_UPPER_RIGHT: [Waypoint.QUARTERS, Waypoint.BRIDGE, Waypoint.CORRIDOR_VERTICAL],
	Waypoint.CORRIDOR_MIDDLE_LEFT: [Waypoint.HYDROPONICS, Waypoint.LIFE_SUPPORT],
	Waypoint.CORRIDOR_MIDDLE_RIGHT: [Waypoint.LIFE_SUPPORT, Waypoint.ENGINEERING],
	Waypoint.CORRIDOR_VERTICAL: [Waypoint.CORRIDOR_CENTER, Waypoint.CORRIDOR_UPPER_RIGHT, Waypoint.ENGINEERING],
	Waypoint.CORRIDOR_HYDRO_CARGO: [Waypoint.HYDROPONICS, Waypoint.CARGO_BAY],

	# Exterior connections (EVA only - crew walks along hull, never through ship)
	# Path: AIRLOCK -> HULL_TOP -> (branch to left/right) -> destinations
	Waypoint.AIRLOCK: [Waypoint.CARGO_BAY, Waypoint.HULL_TOP],
	Waypoint.HULL_TOP: [Waypoint.AIRLOCK, Waypoint.HULL_LEFT, Waypoint.HULL_RIGHT, Waypoint.EXTERIOR_ANTENNA],
	Waypoint.HULL_LEFT: [Waypoint.HULL_TOP, Waypoint.EXTERIOR_SOLAR],
	Waypoint.HULL_RIGHT: [Waypoint.HULL_TOP, Waypoint.EXTERIOR_ENGINE],
	Waypoint.EXTERIOR_ENGINE: [Waypoint.HULL_RIGHT],
	Waypoint.EXTERIOR_ANTENNA: [Waypoint.HULL_TOP],
	Waypoint.EXTERIOR_SOLAR: [Waypoint.HULL_LEFT],
}

# ============================================================================
# WAYPOINT POSITIONS (relative to ship center)
# ============================================================================

## These offsets are relative to layout_center
## Updated by setup() with actual positions from ShipView
var waypoint_positions: Dictionary = {}

static func get_default_offsets() -> Dictionary:
	## Default waypoint offsets from ship center
	## Based on ship layout: h_spacing=130, v_spacing=100
	## Layout:
	##   [MEDICAL]---[QUARTERS]---[CORRIDOR]---[BRIDGE]    (top row, y = -50)
	##                               |
	##   [HYDRO ]---[LIFE SUP]---[ENGINEERING]             (middle row, y = +50)
	##      |
	##   [CARGO ]                                          (bottom row, y = +150)
	var h = 130.0
	var v = 100.0
	var half_v = v * 0.5

	return {
		# Room centers - Top row
		Waypoint.MEDICAL: Vector2(-h * 1.5, -half_v),
		Waypoint.QUARTERS: Vector2(-h * 0.5, -half_v),
		Waypoint.BRIDGE: Vector2(h * 0.5, -half_v),

		# Room centers - Middle row
		Waypoint.HYDROPONICS: Vector2(-h * 1.5, half_v),
		Waypoint.LIFE_SUPPORT: Vector2(-h * 0.5, half_v),
		Waypoint.ENGINEERING: Vector2(h * 0.5, half_v),

		# Room centers - Bottom row
		Waypoint.CARGO_BAY: Vector2(-h * 1.5, v * 1.5),

		# Corridor waypoints - Top row
		Waypoint.CORRIDOR_UPPER_LEFT: Vector2(-h, -half_v),       # Between Medical & Quarters
		Waypoint.CORRIDOR_UPPER_RIGHT: Vector2(0, -half_v),       # Between Quarters & Corridor/Bridge
		Waypoint.CORRIDOR_CENTER: Vector2(-h * 0.5, 0),           # Central hub

		# Corridor waypoints - Middle row
		Waypoint.CORRIDOR_MIDDLE_LEFT: Vector2(-h, half_v),       # Between Hydro & Life Support
		Waypoint.CORRIDOR_MIDDLE_RIGHT: Vector2(0, half_v),       # Between Life Support & Engineering
		Waypoint.CORRIDOR_VERTICAL: Vector2(0, 0),                # Vertical connection top-middle

		# Corridor waypoints - Vertical Hydro-Cargo
		Waypoint.CORRIDOR_HYDRO_CARGO: Vector2(-h * 1.5, v),      # Between Hydroponics & Cargo

		# Exterior waypoints (EVA) - positioned OUTSIDE the hull visual
		# Airlock moved further left to not overlap cargo bay
		Waypoint.AIRLOCK: Vector2(-360, 150),             # Outside hull, left of cargo bay

		# Hull traversal waypoints - crew walks along the hull exterior
		Waypoint.HULL_TOP: Vector2(-250, -180),          # Top of hull
		Waypoint.HULL_LEFT: Vector2(-380, -100),         # Left side, toward solar
		Waypoint.HULL_RIGHT: Vector2(-380, 50),          # Right side, toward engine

		# Exterior work destinations - positioned beyond hull traversal points
		Waypoint.EXTERIOR_ENGINE: Vector2(-420, 100),    # At engine bells (far left, below)
		Waypoint.EXTERIOR_ANTENNA: Vector2(380, -30),    # At nose antenna (far right)
		Waypoint.EXTERIOR_SOLAR: Vector2(-320, -200),    # At top solar panel (upper left)
	}

# ============================================================================
# INITIALIZATION
# ============================================================================

func setup(layout_center: Vector2, room_positions: Dictionary = {}) -> void:
	## Initialize waypoint positions based on actual ship layout
	var offsets = get_default_offsets()

	for wp in offsets:
		waypoint_positions[wp] = layout_center + offsets[wp]

	# Override room waypoints with actual room positions if provided
	if room_positions.has(ShipTypes.RoomType.BRIDGE):
		waypoint_positions[Waypoint.BRIDGE] = room_positions[ShipTypes.RoomType.BRIDGE]
	if room_positions.has(ShipTypes.RoomType.ENGINEERING):
		waypoint_positions[Waypoint.ENGINEERING] = room_positions[ShipTypes.RoomType.ENGINEERING]
	if room_positions.has(ShipTypes.RoomType.LIFE_SUPPORT):
		waypoint_positions[Waypoint.LIFE_SUPPORT] = room_positions[ShipTypes.RoomType.LIFE_SUPPORT]
	if room_positions.has(ShipTypes.RoomType.MEDICAL):
		waypoint_positions[Waypoint.MEDICAL] = room_positions[ShipTypes.RoomType.MEDICAL]
	if room_positions.has(ShipTypes.RoomType.QUARTERS):
		waypoint_positions[Waypoint.QUARTERS] = room_positions[ShipTypes.RoomType.QUARTERS]
	if room_positions.has(ShipTypes.RoomType.CARGO_BAY):
		waypoint_positions[Waypoint.CARGO_BAY] = room_positions[ShipTypes.RoomType.CARGO_BAY]

# ============================================================================
# PATHFINDING
# ============================================================================

func find_path(from_room: int, to_room: int) -> Array[Vector2]:
	## Find path of positions from one room to another
	## Returns array of Vector2 positions to walk through

	var from_wp = room_to_waypoint(from_room)
	var to_wp = room_to_waypoint(to_room)

	if from_wp == to_wp:
		return []

	# BFS to find shortest path through waypoints
	var waypoint_path = _bfs(from_wp, to_wp)

	# Convert waypoints to positions
	var positions: Array[Vector2] = []
	for wp in waypoint_path:
		if waypoint_positions.has(wp):
			positions.append(waypoint_positions[wp])

	return positions

func _bfs(start: int, goal: int) -> Array:
	## Breadth-first search for shortest path
	var queue: Array = [[start]]
	var visited: Dictionary = {start: true}

	while queue.size() > 0:
		var path = queue.pop_front()
		var current = path[-1]

		if current == goal:
			return path

		# Get neighbors
		var neighbors = CONNECTIONS.get(current, [])
		for neighbor in neighbors:
			if not visited.has(neighbor):
				visited[neighbor] = true
				var new_path = path.duplicate()
				new_path.append(neighbor)
				queue.append(new_path)

	# No path found - return direct (fallback)
	return [start, goal]

# ============================================================================
# HELPERS
# ============================================================================

static func room_to_waypoint(room_type: int) -> int:
	## Convert RoomType to Waypoint enum
	match room_type:
		ShipTypes.RoomType.BRIDGE: return Waypoint.BRIDGE
		ShipTypes.RoomType.ENGINEERING: return Waypoint.ENGINEERING
		ShipTypes.RoomType.LIFE_SUPPORT: return Waypoint.LIFE_SUPPORT
		ShipTypes.RoomType.MEDICAL: return Waypoint.MEDICAL
		ShipTypes.RoomType.QUARTERS: return Waypoint.QUARTERS
		ShipTypes.RoomType.CARGO_BAY: return Waypoint.CARGO_BAY
		ShipTypes.RoomType.HYDROPONICS: return Waypoint.HYDROPONICS
		_: return Waypoint.CORRIDOR_CENTER

static func waypoint_to_room(waypoint: int) -> int:
	## Convert Waypoint to RoomType (-1 if corridor)
	match waypoint:
		Waypoint.BRIDGE: return ShipTypes.RoomType.BRIDGE
		Waypoint.ENGINEERING: return ShipTypes.RoomType.ENGINEERING
		Waypoint.LIFE_SUPPORT: return ShipTypes.RoomType.LIFE_SUPPORT
		Waypoint.MEDICAL: return ShipTypes.RoomType.MEDICAL
		Waypoint.QUARTERS: return ShipTypes.RoomType.QUARTERS
		Waypoint.CARGO_BAY: return ShipTypes.RoomType.CARGO_BAY
		Waypoint.HYDROPONICS: return ShipTypes.RoomType.HYDROPONICS
		_: return -1  # Corridor waypoints don't map to rooms

func get_waypoint_position(waypoint: int) -> Vector2:
	return waypoint_positions.get(waypoint, Vector2.ZERO)

func get_room_position(room_type: int) -> Vector2:
	var wp = room_to_waypoint(room_type)
	return get_waypoint_position(wp)

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_graph() -> void:
	print("=== SHIP NAVIGATION GRAPH ===")
	for wp in waypoint_positions:
		var pos = waypoint_positions[wp]
		var connections = CONNECTIONS.get(wp, [])
		print("  %s at %s -> %s" % [Waypoint.keys()[wp], pos, connections])

# ============================================================================
# EVA HELPERS
# ============================================================================

# Work destinations (where repairs happen)
const EXTERIOR_WORK_WAYPOINTS = [
	Waypoint.EXTERIOR_ENGINE,
	Waypoint.EXTERIOR_ANTENNA,
	Waypoint.EXTERIOR_SOLAR,
]

# Hull traversal waypoints (path along hull)
const HULL_WAYPOINTS = [
	Waypoint.HULL_TOP,
	Waypoint.HULL_LEFT,
	Waypoint.HULL_RIGHT,
]

# All exterior waypoints (used for legacy compatibility)
const EXTERIOR_WAYPOINTS = [
	Waypoint.EXTERIOR_ENGINE,
	Waypoint.EXTERIOR_ANTENNA,
	Waypoint.EXTERIOR_SOLAR,
]

static func is_exterior_waypoint(wp: int) -> bool:
	## Check if waypoint is outside the ship (EVA required)
	return wp in EXTERIOR_WORK_WAYPOINTS or wp in HULL_WAYPOINTS or wp == Waypoint.AIRLOCK

static func is_hull_waypoint(wp: int) -> bool:
	## Check if waypoint is on the hull traversal path
	return wp in HULL_WAYPOINTS

static func get_random_exterior_target() -> int:
	## Get a random exterior work location for EVA
	return EXTERIOR_WAYPOINTS[randi() % EXTERIOR_WAYPOINTS.size()]

static func get_exterior_name(wp: int) -> String:
	## Get display name for exterior location
	match wp:
		Waypoint.EXTERIOR_ENGINE: return "Engine"
		Waypoint.EXTERIOR_ANTENNA: return "Antenna"
		Waypoint.EXTERIOR_SOLAR: return "Solar Panel"
		Waypoint.AIRLOCK: return "Airlock"
		_: return "Exterior"

func find_eva_path(from_room: int, exterior_target: int) -> Array[Vector2]:
	## Find path from inside ship to exterior location
	var from_wp = room_to_waypoint(from_room)

	# BFS from room through airlock to exterior target
	var waypoint_path = _bfs(from_wp, exterior_target)

	# Convert to positions
	var positions: Array[Vector2] = []
	for wp in waypoint_path:
		if waypoint_positions.has(wp):
			positions.append(waypoint_positions[wp])

	return positions
