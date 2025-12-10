class_name ShipLogic
extends RefCounted

## Pure functions for ship-level operations
## All functions are static, take inputs, return outputs, no side effects

# ============================================================================
# SHIP CALCULATIONS
# ============================================================================

## Calculate total ship mass (pure)
static func calc_total_mass(components: Array) -> float:
	var total = 0.0
	for comp in components:
		total += comp.mass_kg
	return total

## Calculate average ship quality/readiness (pure)
static func calc_readiness(components: Array) -> float:
	if components.is_empty():
		return 0.0

	var total_quality = 0.0
	for comp in components:
		total_quality += comp.quality
	return total_quality / components.size()

## Calculate minimum component quality (pure)
static func calc_min_quality(components: Array) -> float:
	if components.is_empty():
		return 0.0

	var min_q = 100.0
	for comp in components:
		min_q = minf(min_q, comp.quality)
	return min_q

## Check if ship can launch (pure)
static func check_launch_readiness(
	components: Array,
	engine: Dictionary,  # Can be empty dict if no engine
	crew: Array,
	cargo_manifest: Dictionary
) -> Dictionary:
	var issues: Array = []

	# Must have engine
	if engine.is_empty():
		issues.append("No engine installed")

	# Must have cockpit
	var has_cockpit = false
	for comp in components:
		if comp.id == "cockpit":
			has_cockpit = true
			break
	if not has_cockpit:
		issues.append("No cockpit installed")

	# Must have life support
	var has_life_support = false
	for comp in components:
		if comp.id == "life_support":
			has_life_support = true
			break
	if not has_life_support:
		issues.append("No life support system installed")

	# Must have crew rooms for all crew
	var crew_room_count = 0
	for comp in components:
		if comp.id == "crew_room":
			crew_room_count += 1
	if crew_room_count < crew.size():
		issues.append("Not enough crew rooms (%d/%d)" % [crew_room_count, crew.size()])

	# Must have at least one crew member
	if crew.is_empty():
		issues.append("No crew assigned")

	# Must have MAV for Mars mission
	if not cargo_manifest.get("mav", false):
		issues.append("No Mars Ascent Vehicle loaded")

	# All components must be built
	var unbuilt_count = 0
	for comp in components:
		if not comp.is_built:
			unbuilt_count += 1
	if unbuilt_count > 0:
		issues.append("%d component(s) still under construction" % unbuilt_count)

	# Minimum quality check
	var readiness = calc_readiness(components)
	if readiness < 50.0:
		issues.append("Ship readiness too low (%.0f%%, need 50%%)" % readiness)

	return GameTypes.create_launch_check(
		issues.is_empty(),
		issues,
		readiness
	)

## Find component at hex position (pure)
static func get_component_at(hex_grid: Dictionary, pos: Vector2i) -> Dictionary:
	return hex_grid.get(pos, {})

## Check if position is occupied (pure)
static func is_hex_occupied(hex_grid: Dictionary, pos: Vector2i) -> bool:
	return hex_grid.has(pos) and not hex_grid[pos].is_empty()

## Count components by type (pure)
static func count_components_by_id(components: Array, id: String) -> int:
	var count = 0
	for comp in components:
		if comp.id == id:
			count += 1
	return count

## Get all components of a type (pure)
static func filter_components_by_id(components: Array, id: String) -> Array:
	var result = []
	for comp in components:
		if comp.id == id:
			result.append(comp)
	return result

# ============================================================================
# HEX GRID CALCULATIONS (pure)
# ============================================================================

## Convert hex coordinates to pixel position (pure)
static func hex_to_pixel(hex: Vector2i, hex_size: float) -> Vector2:
	var x = hex_size * (sqrt(3) * hex.x + sqrt(3) / 2.0 * hex.y)
	var y = hex_size * (3.0 / 2.0 * hex.y)
	return Vector2(x, y)

## Convert pixel position to hex coordinates (pure)
static func pixel_to_hex(pixel: Vector2, hex_size: float) -> Vector2i:
	var q = (sqrt(3) / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y) / hex_size
	var r = (2.0 / 3.0 * pixel.y) / hex_size
	return hex_round(Vector2(q, r))

## Round fractional hex to nearest hex (pure)
static func hex_round(hex: Vector2) -> Vector2i:
	var q = round(hex.x)
	var r = round(hex.y)
	var s = round(-hex.x - hex.y)

	var q_diff = abs(q - hex.x)
	var r_diff = abs(r - hex.y)
	var s_diff = abs(s - (-hex.x - hex.y))

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s

	return Vector2i(int(q), int(r))

## Get the 6 neighboring hex positions (pure)
static func get_hex_neighbors(hex: Vector2i) -> Array:
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var neighbors: Array = []
	for dir in directions:
		neighbors.append(hex + dir)
	return neighbors

## Get all hexes for a multi-hex component (pure)
static func get_component_hexes(
	origin: Vector2i,
	size: int,
	valid_positions: Array  # All valid hex positions in grid
) -> Array:
	var hexes: Array = [origin]

	if size <= 1:
		return hexes

	var current_ring = [origin]
	while hexes.size() < size:
		var next_ring: Array = []
		for hex in current_ring:
			for neighbor in get_hex_neighbors(hex):
				if not hexes.has(neighbor) and valid_positions.has(neighbor):
					hexes.append(neighbor)
					next_ring.append(neighbor)
					if hexes.size() >= size:
						break
			if hexes.size() >= size:
				break
		current_ring = next_ring
		if current_ring.is_empty():
			break

	return hexes

## Check if component can be placed at position (pure)
static func can_place_component(
	hex_grid: Dictionary,
	position: Vector2i,
	component_size: int,
	valid_positions: Array
) -> bool:
	if not valid_positions.has(position):
		return false

	var required_hexes = get_component_hexes(position, component_size, valid_positions)
	if required_hexes.size() < component_size:
		return false

	for hex in required_hexes:
		if is_hex_occupied(hex_grid, hex):
			return false

	return true

## Place component on grid, returns new grid state (pure)
static func place_component(
	hex_grid: Dictionary,
	component: Dictionary,
	position: Vector2i,
	valid_positions: Array
) -> Dictionary:
	var new_grid = hex_grid.duplicate(true)
	var hexes = get_component_hexes(position, component.hex_size, valid_positions)

	var placed_component = GameTypes.with_field(component, "hex_position", position)

	for hex in hexes:
		new_grid[hex] = placed_component

	return {
		"grid": new_grid,
		"component": placed_component,
		"hexes": hexes
	}

## Remove component from grid, returns new grid state (pure)
static func remove_component(
	hex_grid: Dictionary,
	position: Vector2i,
	valid_positions: Array
) -> Dictionary:
	var component = get_component_at(hex_grid, position)
	if component.is_empty():
		return {"grid": hex_grid, "component": {}, "hexes": []}

	var origin = component.hex_position
	var hexes = get_component_hexes(origin, component.hex_size, valid_positions)

	var new_grid = hex_grid.duplicate(true)
	for hex in hexes:
		new_grid[hex] = {}

	return {
		"grid": new_grid,
		"component": component,
		"hexes": hexes
	}

# ============================================================================
# SHIP STATE TRANSITIONS (pure - returns new state)
# ============================================================================

## Process one day of construction for all components (pure)
static func advance_construction_day(components: Array) -> Dictionary:
	var new_components: Array = []
	var completed: Array = []

	for comp in components:
		var updated = ComponentLogic.advance_construction(comp)
		new_components.append(updated)

		if not comp.is_built and updated.is_built:
			completed.append(updated)

	return {
		"components": new_components,
		"completed": completed
	}

## Calculate refund amount for removing a component (pure)
static func calc_refund(component: Dictionary, refund_percentage: float = 0.5) -> int:
	return int(component.base_cost * refund_percentage)
