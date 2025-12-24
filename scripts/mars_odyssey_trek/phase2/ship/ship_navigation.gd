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
	# Corridor waypoints
	CORRIDOR_CENTER,      # Central corridor hub
	CORRIDOR_UPPER_LEFT,  # Between Medical and Quarters
	CORRIDOR_UPPER_RIGHT, # Between Quarters and Bridge
	CORRIDOR_LOWER_LEFT,  # Between Cargo and Life Support
	CORRIDOR_LOWER_RIGHT, # Between Life Support and Engineering
	CORRIDOR_VERTICAL,    # Vertical connection between rows
	# Exterior waypoints (EVA)
	AIRLOCK,              # Exit point from cargo bay
	EXTERIOR_ENGINE,      # Engine maintenance area (right side)
	EXTERIOR_ANTENNA,     # Antenna array (top)
	EXTERIOR_SOLAR,       # Solar panels (left side)
}

## Graph edges - which waypoints connect directly
const CONNECTIONS: Dictionary = {
	Waypoint.BRIDGE: [Waypoint.CORRIDOR_UPPER_RIGHT],
	Waypoint.ENGINEERING: [Waypoint.CORRIDOR_LOWER_RIGHT, Waypoint.CORRIDOR_VERTICAL],
	Waypoint.LIFE_SUPPORT: [Waypoint.CORRIDOR_LOWER_LEFT, Waypoint.CORRIDOR_LOWER_RIGHT],
	Waypoint.MEDICAL: [Waypoint.CORRIDOR_UPPER_LEFT],
	Waypoint.QUARTERS: [Waypoint.CORRIDOR_UPPER_LEFT, Waypoint.CORRIDOR_UPPER_RIGHT, Waypoint.CORRIDOR_CENTER],
	Waypoint.CARGO_BAY: [Waypoint.CORRIDOR_LOWER_LEFT, Waypoint.AIRLOCK],

	# Corridor connections
	Waypoint.CORRIDOR_CENTER: [Waypoint.QUARTERS, Waypoint.CORRIDOR_VERTICAL],
	Waypoint.CORRIDOR_UPPER_LEFT: [Waypoint.MEDICAL, Waypoint.QUARTERS],
	Waypoint.CORRIDOR_UPPER_RIGHT: [Waypoint.QUARTERS, Waypoint.BRIDGE, Waypoint.CORRIDOR_VERTICAL],
	Waypoint.CORRIDOR_LOWER_LEFT: [Waypoint.CARGO_BAY, Waypoint.LIFE_SUPPORT],
	Waypoint.CORRIDOR_LOWER_RIGHT: [Waypoint.LIFE_SUPPORT, Waypoint.ENGINEERING],
	Waypoint.CORRIDOR_VERTICAL: [Waypoint.CORRIDOR_CENTER, Waypoint.CORRIDOR_UPPER_RIGHT, Waypoint.ENGINEERING],

	# Exterior connections (EVA only - must pass through airlock)
	Waypoint.AIRLOCK: [Waypoint.CARGO_BAY, Waypoint.EXTERIOR_ENGINE, Waypoint.EXTERIOR_ANTENNA, Waypoint.EXTERIOR_SOLAR],
	Waypoint.EXTERIOR_ENGINE: [Waypoint.AIRLOCK],
	Waypoint.EXTERIOR_ANTENNA: [Waypoint.AIRLOCK],
	Waypoint.EXTERIOR_SOLAR: [Waypoint.AIRLOCK],
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
	var h = 130.0
	var v = 100.0
	var half_v = v * 0.5

	return {
		# Room centers
		Waypoint.MEDICAL: Vector2(-h * 1.5, -half_v),
		Waypoint.QUARTERS: Vector2(-h * 0.5, -half_v),
		Waypoint.BRIDGE: Vector2(h * 0.5, -half_v),
		Waypoint.CARGO_BAY: Vector2(-h * 1.5, half_v),
		Waypoint.LIFE_SUPPORT: Vector2(-h * 0.5, half_v),
		Waypoint.ENGINEERING: Vector2(h * 0.5, half_v),

		# Corridor waypoints (between rooms)
		Waypoint.CORRIDOR_UPPER_LEFT: Vector2(-h, -half_v),      # Between Medical & Quarters
		Waypoint.CORRIDOR_UPPER_RIGHT: Vector2(0, -half_v),       # Between Quarters & Bridge
		Waypoint.CORRIDOR_LOWER_LEFT: Vector2(-h, half_v),        # Between Cargo & Life Support
		Waypoint.CORRIDOR_LOWER_RIGHT: Vector2(0, half_v),        # Between Life Support & Engineering
		Waypoint.CORRIDOR_CENTER: Vector2(-h * 0.5, 0),           # Central hub
		Waypoint.CORRIDOR_VERTICAL: Vector2(0, 0),                # Vertical connection

		# Exterior waypoints (EVA)
		Waypoint.AIRLOCK: Vector2(-h * 2.0, half_v),              # Left of cargo bay
		Waypoint.EXTERIOR_ENGINE: Vector2(h * 1.5, half_v + 60),  # Behind engine (right side)
		Waypoint.EXTERIOR_ANTENNA: Vector2(h * 0.5, -half_v - 70), # Above bridge
		Waypoint.EXTERIOR_SOLAR: Vector2(-h * 2.0, -20),          # Left side of ship
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

const EXTERIOR_WAYPOINTS = [
	Waypoint.EXTERIOR_ENGINE,
	Waypoint.EXTERIOR_ANTENNA,
	Waypoint.EXTERIOR_SOLAR,
]

static func is_exterior_waypoint(wp: int) -> bool:
	## Check if waypoint is outside the ship (EVA required)
	return wp in EXTERIOR_WAYPOINTS or wp == Waypoint.AIRLOCK

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
