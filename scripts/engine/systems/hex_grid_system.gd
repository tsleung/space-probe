## Hex grid system for component placement.
## Handles placement, validation, and queries on hex grids.
##
## All functions are static and pure.
class_name HexGridSystem
extends RefCounted


## ============================================================================
## PLACEMENT VALIDATION
## ============================================================================

## Check if a component can be placed at the given position
static func can_place_component(
	ship: Dictionary,
	component_def: Dictionary,
	position: Vector2i,
	rotation: int = 0
) -> Result:
	var hex_size = component_def.get("stats", {}).get("hex_size", 1)
	var hexes = HexMath.get_component_hexes(position, hex_size, rotation)
	var components = ship.get("components", {})

	# Check each hex the component would occupy
	for hex in hexes:
		var key = HexMath.hex_key_v(hex)

		# Check if already occupied
		if components.has(key):
			return Result.error(
				"POSITION_OCCUPIED",
				"Position (%d, %d) is already occupied" % [hex.x, hex.y],
				{"position": hex, "occupying": components[key].get("id", "unknown")}
			)

		# Check grid bounds (if defined)
		if not _is_within_bounds(hex, ship):
			return Result.error(
				"OUT_OF_BOUNDS",
				"Position (%d, %d) is outside grid bounds" % [hex.x, hex.y],
				{"position": hex}
			)

	# Check placement rules
	var placement = component_def.get("placement", {})

	# Must be rear?
	if placement.get("must_be_rear", false):
		if position.r < _get_rear_row(ship):
			return Result.error(
				"MUST_BE_REAR",
				"This component must be placed at the rear of the ship",
				{"component_id": component_def.get("id")}
			)

	# Adjacent requirements?
	var adjacent_to = placement.get("adjacent_to", [])
	if not adjacent_to.is_empty():
		if not _has_adjacent_component(ship, position, adjacent_to):
			return Result.error(
				"ADJACENCY_REQUIRED",
				"Must be adjacent to: %s" % ", ".join(adjacent_to),
				{"required_adjacent": adjacent_to}
			)

	return Result.ok({"hexes": hexes})


## Check if position is within grid bounds
static func _is_within_bounds(hex: Vector2i, ship: Dictionary) -> bool:
	var bounds = ship.get("grid_bounds", {})
	var min_q = bounds.get("min_q", -10)
	var max_q = bounds.get("max_q", 10)
	var min_r = bounds.get("min_r", -10)
	var max_r = bounds.get("max_r", 10)

	return hex.x >= min_q and hex.x <= max_q and hex.y >= min_r and hex.y <= max_r


## Get the rear row of the ship grid
static func _get_rear_row(ship: Dictionary) -> int:
	var bounds = ship.get("grid_bounds", {})
	return bounds.get("max_r", 5)


## Check if there's an adjacent component of the required type
static func _has_adjacent_component(ship: Dictionary, position: Vector2i, required_types: Array) -> bool:
	var components = ship.get("components", {})
	var neighbors = HexMath.get_neighbors_v(position)

	for neighbor in neighbors:
		var key = HexMath.hex_key_v(neighbor)
		if components.has(key):
			var comp = components[key]
			var comp_id = comp.get("definition_id", comp.get("id", ""))
			if comp_id in required_types:
				return true

	return false


## ============================================================================
## PLACEMENT OPERATIONS
## ============================================================================

## Place a component on the grid (returns new ship state)
static func place_component(
	ship: Dictionary,
	component: Dictionary,
	position: Vector2i,
	rotation: int = 0
) -> Dictionary:
	var new_ship = ship.duplicate(true)
	var hex_size = component.get("stats", {}).get("hex_size", 1)
	var hexes = HexMath.get_component_hexes(position, hex_size, rotation)

	# Place component at each hex
	for hex in hexes:
		var key = HexMath.hex_key_v(hex)
		new_ship.components[key] = {
			"component_ref": HexMath.hex_key_v(position),  # Reference to primary hex
			"is_primary": hex == position
		}

	# Store full component data at primary position
	var primary_key = HexMath.hex_key_v(position)
	new_ship.components[primary_key] = component.duplicate(true)
	new_ship.components[primary_key]["position"] = {"q": position.x, "r": position.y}
	new_ship.components[primary_key]["rotation"] = rotation
	new_ship.components[primary_key]["hexes"] = []
	for hex in hexes:
		new_ship.components[primary_key]["hexes"].append({"q": hex.x, "r": hex.y})

	# Update ship totals
	new_ship = _recalculate_ship_stats(new_ship)

	return new_ship


## Remove a component from the grid (returns new ship state)
static func remove_component(ship: Dictionary, position: Vector2i) -> Dictionary:
	var new_ship = ship.duplicate(true)
	var key = HexMath.hex_key_v(position)

	if not new_ship.components.has(key):
		return new_ship

	var component = new_ship.components[key]

	# If this is a reference, get the primary
	if component.has("component_ref"):
		key = component.component_ref
		position = HexMath.parse_hex_key(key)
		component = new_ship.components.get(key, {})

	# Remove all hexes this component occupies
	var hexes = component.get("hexes", [{"q": position.x, "r": position.y}])
	for hex_data in hexes:
		var hex_key = HexMath.hex_key(hex_data.q, hex_data.r)
		new_ship.components.erase(hex_key)

	# Update ship totals
	new_ship = _recalculate_ship_stats(new_ship)

	return new_ship


## ============================================================================
## QUERIES
## ============================================================================

## Get component at position
static func get_component_at(ship: Dictionary, position: Vector2i) -> Dictionary:
	var key = HexMath.hex_key_v(position)
	var components = ship.get("components", {})

	if not components.has(key):
		return {}

	var entry = components[key]

	# If this is a reference, get the actual component
	if entry.has("component_ref"):
		return components.get(entry.component_ref, {})

	return entry


## Get all placed components (not references)
static func get_all_components(ship: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var components = ship.get("components", {})

	for key in components:
		var comp = components[key]
		# Skip references, only return primary components
		if not comp.has("component_ref") or comp.get("is_primary", false):
			if comp.has("id") or comp.has("definition_id"):
				result.append(comp)

	return result


## Get components by category
static func get_components_by_category(ship: Dictionary, category: String) -> Array[Dictionary]:
	var all = get_all_components(ship)
	var result: Array[Dictionary] = []

	for comp in all:
		if comp.get("category", "") == category:
			result.append(comp)

	return result


## Get component by ID
static func get_component_by_id(ship: Dictionary, component_id: String) -> Dictionary:
	var all = get_all_components(ship)

	for comp in all:
		if comp.get("id", "") == component_id or comp.get("definition_id", "") == component_id:
			return comp

	return {}


## Get all occupied hexes
static func get_occupied_hexes(ship: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var components = ship.get("components", {})

	for key in components:
		result.append(HexMath.parse_hex_key(key))

	return result


## Get adjacent components to a position
static func get_adjacent_components(ship: Dictionary, position: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var neighbors = HexMath.get_neighbors_v(position)

	for neighbor in neighbors:
		var comp = get_component_at(ship, neighbor)
		if not comp.is_empty() and comp not in result:
			result.append(comp)

	return result


## ============================================================================
## SHIP STATS
## ============================================================================

## Recalculate all ship stats from components
static func _recalculate_ship_stats(ship: Dictionary) -> Dictionary:
	var new_ship = ship.duplicate(true)
	var components = get_all_components(new_ship)

	var total_mass: float = 0.0
	var power_generation: float = 0.0
	var power_draw: float = 0.0
	var cargo_capacity: float = 0.0
	var fuel_capacity: float = 0.0
	var crew_capacity: int = 0
	var quality_sum: float = 0.0
	var quality_count: int = 0

	for comp in components:
		var stats = comp.get("stats", {})

		total_mass += stats.get("mass_kg", 0) / 1000.0  # Convert to tons
		power_generation += stats.get("power_generation", 0)
		power_draw += stats.get("power_draw", 0)
		cargo_capacity += stats.get("cargo_capacity", 0)
		fuel_capacity += stats.get("fuel_capacity", 0)
		crew_capacity += stats.get("crew_capacity", 0)

		var quality = comp.get("quality", stats.get("base_quality", 50))
		quality_sum += quality
		quality_count += 1

	new_ship["total_mass"] = total_mass
	new_ship["power_capacity"] = power_generation
	new_ship["power_draw"] = power_draw
	new_ship["cargo_capacity"] = cargo_capacity
	new_ship["fuel_capacity"] = fuel_capacity
	new_ship["crew_capacity"] = crew_capacity
	new_ship["average_quality"] = quality_sum / max(quality_count, 1)

	return new_ship


## Calculate total ship quality (weighted average)
static func calculate_ship_quality(ship: Dictionary) -> float:
	var components = get_all_components(ship)

	if components.is_empty():
		return 0.0

	var quality_sum: float = 0.0
	var weight_sum: float = 0.0

	for comp in components:
		var stats = comp.get("stats", {})
		var quality = comp.get("quality", stats.get("base_quality", 50))
		var weight = 1.0

		# Critical components weighted more heavily
		if comp.get("critical", false):
			weight = 2.0
		elif comp.get("required", false):
			weight = 1.5

		quality_sum += quality * weight
		weight_sum += weight

	return quality_sum / max(weight_sum, 1.0)


## Check if ship meets launch requirements
static func check_launch_readiness(ship: Dictionary, required_components: Array[String]) -> Result:
	var missing: Array[String] = []

	for required_id in required_components:
		var comp = get_component_by_id(ship, required_id)
		if comp.is_empty():
			missing.append(required_id)

	if not missing.is_empty():
		return Result.error(
			"MISSING_COMPONENTS",
			"Missing required components: %s" % ", ".join(missing),
			{"missing": missing}
		)

	# Check minimum quality
	var quality = calculate_ship_quality(ship)
	if quality < 20:
		return Result.error(
			"QUALITY_TOO_LOW",
			"Ship quality (%.1f%%) is below minimum (20%%)" % quality,
			{"quality": quality, "minimum": 20}
		)

	return Result.ok({"quality": quality, "ready": true})
