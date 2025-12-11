## Hex grid math utilities.
## Uses axial coordinates (q, r) for hex grids.
##
## All functions are static and pure.
class_name HexMath
extends RefCounted

## Hex size in pixels (for rendering)
const HEX_SIZE: float = 40.0

## Direction vectors for the 6 hex neighbors (pointy-top orientation)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # East
	Vector2i(1, -1),  # Northeast
	Vector2i(0, -1),  # Northwest
	Vector2i(-1, 0),  # West
	Vector2i(-1, 1),  # Southwest
	Vector2i(0, 1)    # Southeast
]


## ============================================================================
## COORDINATE CONVERSIONS
## ============================================================================

## Convert axial coordinates to pixel position (pointy-top hex)
static func hex_to_pixel(q: int, r: int, size: float = HEX_SIZE) -> Vector2:
	var x = size * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var y = size * (3.0 / 2.0 * r)
	return Vector2(x, y)


## Convert axial coordinates from Vector2i to pixel position
static func hex_to_pixel_v(hex: Vector2i, size: float = HEX_SIZE) -> Vector2:
	return hex_to_pixel(hex.x, hex.y, size)


## Convert pixel position to axial coordinates
static func pixel_to_hex(pos: Vector2, size: float = HEX_SIZE) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / size
	var r = (2.0 / 3.0 * pos.y) / size
	return hex_round(q, r)


## Round fractional hex coordinates to nearest hex
static func hex_round(q: float, r: float) -> Vector2i:
	var s = -q - r

	var rq = round(q)
	var rr = round(r)
	var rs = round(s)

	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs

	return Vector2i(int(rq), int(rr))


## ============================================================================
## NEIGHBOR AND DISTANCE
## ============================================================================

## Get all 6 neighbor coordinates
static func get_neighbors(q: int, r: int) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		neighbors.append(Vector2i(q + dir.x, r + dir.y))
	return neighbors


## Get all 6 neighbor coordinates from Vector2i
static func get_neighbors_v(hex: Vector2i) -> Array[Vector2i]:
	return get_neighbors(hex.x, hex.y)


## Get neighbor in specific direction (0-5)
static func get_neighbor(q: int, r: int, direction: int) -> Vector2i:
	var dir = DIRECTIONS[direction % 6]
	return Vector2i(q + dir.x, r + dir.y)


## Calculate hex distance between two hexes
static func distance(q1: int, r1: int, q2: int, r2: int) -> int:
	# Convert to cube coordinates and use cube distance
	var s1 = -q1 - r1
	var s2 = -q2 - r2
	return (abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2


## Calculate hex distance from Vector2i
static func distance_v(a: Vector2i, b: Vector2i) -> int:
	return distance(a.x, a.y, b.x, b.y)


## Check if two hexes are adjacent
static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return distance_v(a, b) == 1


## ============================================================================
## RINGS AND AREAS
## ============================================================================

## Get all hexes in a ring at given radius
static func get_ring(center_q: int, center_r: int, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []

	if radius == 0:
		results.append(Vector2i(center_q, center_r))
		return results

	# Start at the hex radius steps away in direction 4 (southwest)
	var hex = Vector2i(center_q - radius, center_r + radius)

	for i in range(6):
		for j in range(radius):
			results.append(hex)
			hex = get_neighbor(hex.x, hex.y, i)

	return results


## Get all hexes within given radius (filled circle)
static func get_hexes_in_range(center_q: int, center_r: int, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []

	for q in range(-radius, radius + 1):
		for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			results.append(Vector2i(center_q + q, center_r + r))

	return results


## Get all hexes within range from Vector2i center
static func get_hexes_in_range_v(center: Vector2i, radius: int) -> Array[Vector2i]:
	return get_hexes_in_range(center.x, center.y, radius)


## ============================================================================
## LINE AND PATH
## ============================================================================

## Get hexes along a line from a to b
static func get_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n = distance_v(a, b)
	if n == 0:
		return [a]

	var results: Array[Vector2i] = []
	for i in range(n + 1):
		var t = float(i) / float(n)
		var q = lerp(float(a.x), float(b.x), t)
		var r = lerp(float(a.y), float(b.y), t)
		results.append(hex_round(q, r))

	return results


## ============================================================================
## ROTATION
## ============================================================================

## Rotate hex coordinates around origin by 60 degrees clockwise
static func rotate_cw(q: int, r: int) -> Vector2i:
	var s = -q - r
	return Vector2i(-r, -s)


## Rotate hex coordinates around origin by 60 degrees counter-clockwise
static func rotate_ccw(q: int, r: int) -> Vector2i:
	var s = -q - r
	return Vector2i(-s, -q)


## Rotate hex around a center point
static func rotate_around(hex: Vector2i, center: Vector2i, steps: int) -> Vector2i:
	# Translate to origin
	var relative = hex - center

	# Rotate
	for i in range(abs(steps)):
		if steps > 0:
			relative = rotate_cw(relative.x, relative.y)
		else:
			relative = rotate_ccw(relative.x, relative.y)

	# Translate back
	return relative + center


## ============================================================================
## SHAPE GENERATION
## ============================================================================

## Get hexes for a multi-hex shape centered at origin
## shape_type: "single", "double_h", "double_v", "triple_line", "triple_triangle", "quad"
static func get_shape_hexes(shape_type: String, rotation: int = 0) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []

	match shape_type:
		"single":
			hexes = [Vector2i(0, 0)]
		"double_h":
			hexes = [Vector2i(0, 0), Vector2i(1, 0)]
		"double_v":
			hexes = [Vector2i(0, 0), Vector2i(0, 1)]
		"triple_line":
			hexes = [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]
		"triple_triangle":
			hexes = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
		"quad":
			hexes = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, -1)]
		_:
			hexes = [Vector2i(0, 0)]

	# Apply rotation
	if rotation != 0:
		var rotated: Array[Vector2i] = []
		for hex in hexes:
			var new_hex = hex
			for i in range(rotation % 6):
				new_hex = rotate_cw(new_hex.x, new_hex.y)
			rotated.append(new_hex)
		return rotated

	return hexes


## Get hexes occupied by a component at given position
static func get_component_hexes(position: Vector2i, hex_size: int, rotation: int = 0) -> Array[Vector2i]:
	var shape_type: String
	match hex_size:
		1:
			shape_type = "single"
		2:
			shape_type = "double_h"
		3:
			shape_type = "triple_line"
		4:
			shape_type = "quad"
		_:
			shape_type = "single"

	var shape = get_shape_hexes(shape_type, rotation)
	var result: Array[Vector2i] = []

	for hex in shape:
		result.append(position + hex)

	return result


## ============================================================================
## UTILITY
## ============================================================================

## Get hex position as string key (for dictionary storage)
static func hex_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


## Get hex position as string key from Vector2i
static func hex_key_v(hex: Vector2i) -> String:
	return hex_key(hex.x, hex.y)


## Parse hex key back to Vector2i
static func parse_hex_key(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


## Get vertices of a hex for rendering (pointy-top)
static func get_hex_vertices(center: Vector2, size: float = HEX_SIZE) -> PackedVector2Array:
	var vertices = PackedVector2Array()
	for i in range(6):
		var angle = PI / 3.0 * i - PI / 6.0  # Start at top-right
		vertices.append(center + Vector2(cos(angle), sin(angle)) * size)
	return vertices
