extends RefCounted
class_name TileGrid

## Tile-based grid system for CRISIS mode
## Provides discrete movement costs and A* pathfinding for crew members

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# TILE CONSTANTS
# ============================================================================

const TILE_SIZE = 16  # pixels per tile

# Movement timing (seconds per tile)
const WALK_TIME_PER_TILE = 0.4
const RUN_TIME_PER_TILE = 0.25

# Grid dimensions (calculated from ship layout)
const GRID_WIDTH = 32   # tiles
const GRID_HEIGHT = 12  # tiles

# Ship layout origin (top-left corner of grid in world space)
const GRID_ORIGIN = Vector2(155, 180)

# ============================================================================
# TILE TYPES
# ============================================================================

enum TileType {
	EMPTY,      # Impassable space
	FLOOR,      # Standard walkable floor
	STATION,    # Work station (can work here)
	STORAGE,    # Item pickup location
	BLOCKED     # Temporarily blocked by crew or obstacle
}

# ============================================================================
# ROOM TILE DEFINITIONS
# ============================================================================

# Room bounds in tile coordinates (x, y, width, height)
const ROOM_TILE_BOUNDS = {
	ShipTypes.RoomType.MEDICAL: {"x": 0, "y": 0, "w": 6, "h": 5},
	ShipTypes.RoomType.QUARTERS: {"x": 8, "y": 0, "w": 6, "h": 5},
	ShipTypes.RoomType.CORRIDOR: {"x": 17, "y": 0, "w": 4, "h": 3},
	ShipTypes.RoomType.BRIDGE: {"x": 24, "y": 0, "w": 6, "h": 5},
	ShipTypes.RoomType.CARGO_BAY: {"x": 0, "y": 7, "w": 6, "h": 5},
	ShipTypes.RoomType.LIFE_SUPPORT: {"x": 8, "y": 7, "w": 6, "h": 5},
	ShipTypes.RoomType.ENGINEERING: {"x": 17, "y": 7, "w": 6, "h": 5}
}

# Work station positions within rooms (tile coords)
const ROOM_STATIONS = {
	ShipTypes.RoomType.MEDICAL: Vector2i(3, 2),
	ShipTypes.RoomType.QUARTERS: Vector2i(11, 2),
	ShipTypes.RoomType.CORRIDOR: Vector2i(19, 1),
	ShipTypes.RoomType.BRIDGE: Vector2i(27, 2),
	ShipTypes.RoomType.CARGO_BAY: Vector2i(3, 9),
	ShipTypes.RoomType.LIFE_SUPPORT: Vector2i(11, 9),
	ShipTypes.RoomType.ENGINEERING: Vector2i(20, 9)
}

# Storage locations (only CARGO_BAY has item storage)
const STORAGE_TILES = [
	Vector2i(1, 8),   # Patch Kits
	Vector2i(1, 9),   # Extinguishers
	Vector2i(1, 10),  # Med Kits
	Vector2i(2, 10)   # Sanitizers
]

# Corridor segments connecting rooms (list of tile positions)
# Horizontal corridors (top row)
const CORRIDOR_TOP_1 = [Vector2i(6, 2), Vector2i(7, 2)]  # Medical-Quarters
const CORRIDOR_TOP_2 = [Vector2i(14, 2), Vector2i(15, 2), Vector2i(16, 2)]  # Quarters-Corridor
const CORRIDOR_TOP_3 = [Vector2i(21, 1), Vector2i(22, 1), Vector2i(23, 1)]  # Corridor-Bridge

# Horizontal corridors (bottom row)
const CORRIDOR_BOT_1 = [Vector2i(6, 9), Vector2i(7, 9)]  # Cargo-LifeSupport
const CORRIDOR_BOT_2 = [Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9)]  # LifeSupport-Engineering

# Vertical corridor connecting rows
const CORRIDOR_VERT = [Vector2i(19, 3), Vector2i(19, 4), Vector2i(19, 5), Vector2i(19, 6)]

# ============================================================================
# STATE
# ============================================================================

var tiles: Array[Array] = []  # 2D array of TileType
var blocked_tiles: Dictionary = {}  # Vector2i -> crew_role blocking it

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	_build_tile_map()

func _build_tile_map() -> void:
	## Build the tile map from room definitions

	# Initialize with EMPTY
	tiles.clear()
	for y in range(GRID_HEIGHT):
		var row: Array[TileType] = []
		row.resize(GRID_WIDTH)
		row.fill(TileType.EMPTY)
		tiles.append(row)

	# Fill rooms with FLOOR
	for room_type in ROOM_TILE_BOUNDS:
		var bounds = ROOM_TILE_BOUNDS[room_type]
		for dy in range(bounds.h):
			for dx in range(bounds.w):
				var tx = bounds.x + dx
				var ty = bounds.y + dy
				if _in_bounds(tx, ty):
					tiles[ty][tx] = TileType.FLOOR

	# Add corridor tiles
	for tile in CORRIDOR_TOP_1 + CORRIDOR_TOP_2 + CORRIDOR_TOP_3:
		if _in_bounds(tile.x, tile.y):
			tiles[tile.y][tile.x] = TileType.FLOOR
	for tile in CORRIDOR_BOT_1 + CORRIDOR_BOT_2:
		if _in_bounds(tile.x, tile.y):
			tiles[tile.y][tile.x] = TileType.FLOOR
	for tile in CORRIDOR_VERT:
		if _in_bounds(tile.x, tile.y):
			tiles[tile.y][tile.x] = TileType.FLOOR

	# Mark station tiles
	for room_type in ROOM_STATIONS:
		var station = ROOM_STATIONS[room_type]
		if _in_bounds(station.x, station.y):
			tiles[station.y][station.x] = TileType.STATION

	# Mark storage tiles
	for storage in STORAGE_TILES:
		if _in_bounds(storage.x, storage.y):
			tiles[storage.y][storage.x] = TileType.STORAGE

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

# ============================================================================
# COORDINATE CONVERSION
# ============================================================================

static func world_to_tile(world_pos: Vector2) -> Vector2i:
	## Convert world position to tile coordinates
	var local = world_pos - GRID_ORIGIN
	return Vector2i(
		int(floor(local.x / TILE_SIZE)),
		int(floor(local.y / TILE_SIZE))
	)

static func tile_to_world(tile_pos: Vector2i) -> Vector2:
	## Convert tile coordinates to world position (center of tile)
	return GRID_ORIGIN + Vector2(
		tile_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
		tile_pos.y * TILE_SIZE + TILE_SIZE / 2.0
	)

static func get_room_center_tile(room_type: ShipTypes.RoomType) -> Vector2i:
	## Get the center tile of a room
	if not ROOM_TILE_BOUNDS.has(room_type):
		return Vector2i(16, 6)  # Default center
	var bounds = ROOM_TILE_BOUNDS[room_type]
	return Vector2i(bounds.x + bounds.w / 2, bounds.y + bounds.h / 2)

static func get_room_station_tile(room_type: ShipTypes.RoomType) -> Vector2i:
	## Get the work station tile for a room
	return ROOM_STATIONS.get(room_type, Vector2i(16, 6))

# ============================================================================
# PATHFINDING (A*)
# ============================================================================

func find_path(from_tile: Vector2i, to_tile: Vector2i, respect_blocking: bool = true) -> Array[Vector2i]:
	## A* pathfinding from one tile to another
	## Returns array of tiles to walk through (empty if no path)

	if not _in_bounds(from_tile.x, from_tile.y) or not _in_bounds(to_tile.x, to_tile.y):
		return []

	if not _is_walkable(to_tile, respect_blocking):
		# Try to find nearest walkable tile to destination
		to_tile = _find_nearest_walkable(to_tile, respect_blocking)
		if to_tile == Vector2i(-1, -1):
			return []

	# A* implementation
	var open_set: Array[Vector2i] = [from_tile]
	var came_from: Dictionary = {}  # Vector2i -> Vector2i
	var g_score: Dictionary = {from_tile: 0}  # Cost from start
	var f_score: Dictionary = {from_tile: _heuristic(from_tile, to_tile)}  # Estimated total cost

	while not open_set.is_empty():
		# Find node with lowest f_score
		var current = _get_lowest_f(open_set, f_score)

		if current == to_tile:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		# Check neighbors (4-directional, no diagonals)
		for neighbor in _get_neighbors(current):
			if not _is_walkable(neighbor, respect_blocking):
				continue

			var tentative_g = g_score.get(current, INF) + 1  # Each step costs 1

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to_tile)

				if neighbor not in open_set:
					open_set.append(neighbor)

	return []  # No path found

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	## Manhattan distance (no diagonals)
	return abs(a.x - b.x) + abs(a.y - b.y)

func _get_neighbors(tile: Vector2i) -> Array[Vector2i]:
	## Get orthogonal neighbors (no diagonals)
	var neighbors: Array[Vector2i] = []
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in dirs:
		var n = tile + dir
		if _in_bounds(n.x, n.y):
			neighbors.append(n)
	return neighbors

func _is_walkable(tile: Vector2i, respect_blocking: bool) -> bool:
	## Check if a tile can be walked on
	if not _in_bounds(tile.x, tile.y):
		return false

	var tile_type = tiles[tile.y][tile.x]
	if tile_type == TileType.EMPTY:
		return false

	if respect_blocking and blocked_tiles.has(tile):
		return false

	return true

func _find_nearest_walkable(target: Vector2i, respect_blocking: bool) -> Vector2i:
	## Find nearest walkable tile to target
	var best = Vector2i(-1, -1)
	var best_dist = INF

	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var check = target + Vector2i(dx, dy)
			if _is_walkable(check, respect_blocking):
				var dist = abs(dx) + abs(dy)
				if dist < best_dist:
					best_dist = dist
					best = check

	return best

func _get_lowest_f(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	## Get node with lowest f_score from open set
	var lowest = open_set[0]
	var lowest_f = f_score.get(lowest, INF)

	for node in open_set:
		var f = f_score.get(node, INF)
		if f < lowest_f:
			lowest_f = f
			lowest = node

	return lowest

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	## Reconstruct path from A* result
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	return path

# ============================================================================
# CREW BLOCKING
# ============================================================================

func block_tile(tile: Vector2i, crew_role: String) -> void:
	## Mark a tile as blocked by a crew member
	blocked_tiles[tile] = crew_role

func unblock_tile(tile: Vector2i) -> void:
	## Remove blocking from a tile
	blocked_tiles.erase(tile)

func unblock_crew(crew_role: String) -> void:
	## Remove all blocked tiles for a specific crew member
	var to_remove: Array[Vector2i] = []
	for tile in blocked_tiles:
		if blocked_tiles[tile] == crew_role:
			to_remove.append(tile)
	for tile in to_remove:
		blocked_tiles.erase(tile)

func is_tile_blocked(tile: Vector2i) -> bool:
	return blocked_tiles.has(tile)

func get_blocking_crew(tile: Vector2i) -> String:
	return blocked_tiles.get(tile, "")

# ============================================================================
# DISTANCE CALCULATIONS
# ============================================================================

func get_tile_distance(from_tile: Vector2i, to_tile: Vector2i) -> int:
	## Get path length between two tiles (considering obstacles)
	var path = find_path(from_tile, to_tile, false)  # Ignore crew blocking for estimate
	return path.size() - 1 if path.size() > 1 else _heuristic(from_tile, to_tile)

func get_travel_time(from_tile: Vector2i, to_tile: Vector2i, is_running: bool = false) -> float:
	## Get estimated travel time in seconds
	var distance = get_tile_distance(from_tile, to_tile)
	var time_per_tile = RUN_TIME_PER_TILE if is_running else WALK_TIME_PER_TILE
	return distance * time_per_tile

func get_room_at_tile(tile: Vector2i) -> ShipTypes.RoomType:
	## Get which room a tile belongs to
	for room_type in ROOM_TILE_BOUNDS:
		var bounds = ROOM_TILE_BOUNDS[room_type]
		if tile.x >= bounds.x and tile.x < bounds.x + bounds.w:
			if tile.y >= bounds.y and tile.y < bounds.y + bounds.h:
				return room_type
	return ShipTypes.RoomType.CORRIDOR  # Default for corridor tiles

# ============================================================================
# UTILITY
# ============================================================================

func get_tile_type(tile: Vector2i) -> TileType:
	if not _in_bounds(tile.x, tile.y):
		return TileType.EMPTY
	return tiles[tile.y][tile.x]

func is_storage_tile(tile: Vector2i) -> bool:
	return tile in STORAGE_TILES

func get_storage_tiles() -> Array:
	return STORAGE_TILES.duplicate()

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_grid() -> void:
	## Print ASCII representation of tile grid
	print("=== TILE GRID (%dx%d) ===" % [GRID_WIDTH, GRID_HEIGHT])
	for y in range(GRID_HEIGHT):
		var line = ""
		for x in range(GRID_WIDTH):
			var tile = Vector2i(x, y)
			if blocked_tiles.has(tile):
				line += "X"
			else:
				match tiles[y][x]:
					TileType.EMPTY: line += " "
					TileType.FLOOR: line += "."
					TileType.STATION: line += "S"
					TileType.STORAGE: line += "$"
					_: line += "?"
		print(line)
	print("========================")
