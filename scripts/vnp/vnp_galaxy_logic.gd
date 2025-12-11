class_name VNPGalaxyLogic
extends RefCounted

## Pure functions for galaxy generation and navigation
## All functions are static and deterministic with provided random values

# ============================================================================
# GALAXY GENERATION
# ============================================================================

## Generate a complete galaxy (pure)
static func generate_galaxy(seed_value: int, system_count: int = 25) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	var systems = {}

	# Generate systems in a roughly circular pattern
	for i in range(system_count):
		var system_id = "sys_%d" % i
		var angle = (float(i) / system_count) * TAU + rng.randf() * 0.5
		var radius = 100.0 + rng.randf() * 300.0

		# Spiral arm effect
		if i > 0:
			angle += (radius / 400.0) * 1.5

		var pos = Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		)

		var star_type = _roll_star_type(rng.randf())
		var resources = _generate_resources(star_type, rng)
		var danger = _calc_danger_level(star_type, rng.randf())

		systems[system_id] = VNPTypes.create_star_system({
			"id": system_id,
			"name": VNPTypes.generate_star_name(i, seed_value),
			"star_type": star_type,
			"position": pos,
			"resources": resources.current,
			"max_resources": resources.max_val,
			"danger_level": danger,
			"has_anomaly": rng.randf() < 0.15  # 15% chance
		})

	# Generate connections (each system connects to 2-4 nearest neighbors)
	for sys_id in systems.keys():
		var sys = systems[sys_id]
		var distances = []

		for other_id in systems.keys():
			if other_id == sys_id:
				continue
			var other = systems[other_id]
			var dist = sys.position.distance_to(other.position)
			distances.append({"id": other_id, "dist": dist})

		# Sort by distance
		distances.sort_custom(func(a, b): return a.dist < b.dist)

		# Connect to 2-4 nearest
		var connection_count = rng.randi_range(2, 4)
		var connections = []
		for j in range(mini(connection_count, distances.size())):
			connections.append(distances[j].id)

		systems[sys_id] = VNPTypes.with_field(sys, "connections", connections)

	# Ensure bidirectional connections
	for sys_id in systems.keys():
		for conn_id in systems[sys_id].connections:
			var conn_system = systems[conn_id]
			if sys_id not in conn_system.connections:
				var new_connections = conn_system.connections.duplicate()
				new_connections.append(sys_id)
				systems[conn_id] = VNPTypes.with_field(conn_system, "connections", new_connections)

	# Pick a safe starting system (yellow or orange, low danger)
	var home_id = _find_home_system(systems, rng)
	systems[home_id] = VNPTypes.with_field(systems[home_id], "is_explored", true)

	return {
		"systems": systems,
		"home_system": home_id,
		"total_systems": system_count
	}

static func _roll_star_type(roll: float) -> int:
	if roll < 0.35:
		return VNPTypes.StarType.RED_DWARF
	elif roll < 0.60:
		return VNPTypes.StarType.YELLOW
	elif roll < 0.80:
		return VNPTypes.StarType.ORANGE
	elif roll < 0.90:
		return VNPTypes.StarType.BLUE_GIANT
	elif roll < 0.97:
		return VNPTypes.StarType.WHITE_DWARF
	else:
		return VNPTypes.StarType.NEUTRON

static func _generate_resources(star_type: int, rng: RandomNumberGenerator) -> Dictionary:
	var base_iron = 0
	var base_rare = 0

	match star_type:
		VNPTypes.StarType.RED_DWARF:
			base_iron = rng.randi_range(50, 150)
			base_rare = rng.randi_range(0, 10)
		VNPTypes.StarType.YELLOW:
			base_iron = rng.randi_range(100, 250)
			base_rare = rng.randi_range(5, 25)
		VNPTypes.StarType.ORANGE:
			base_iron = rng.randi_range(150, 350)
			base_rare = rng.randi_range(10, 40)
		VNPTypes.StarType.BLUE_GIANT:
			base_iron = rng.randi_range(200, 500)
			base_rare = rng.randi_range(30, 80)
		VNPTypes.StarType.WHITE_DWARF:
			base_iron = rng.randi_range(50, 150)
			base_rare = rng.randi_range(50, 120)
		VNPTypes.StarType.NEUTRON:
			base_iron = rng.randi_range(20, 80)
			base_rare = rng.randi_range(100, 250)

	return {
		"current": {"iron": base_iron, "rare": base_rare},
		"max_val": {"iron": base_iron, "rare": base_rare}
	}

static func _calc_danger_level(star_type: int, roll: float) -> float:
	var base_danger = 0.0

	match star_type:
		VNPTypes.StarType.RED_DWARF:
			base_danger = 0.05
		VNPTypes.StarType.YELLOW:
			base_danger = 0.1
		VNPTypes.StarType.ORANGE:
			base_danger = 0.15
		VNPTypes.StarType.BLUE_GIANT:
			base_danger = 0.35
		VNPTypes.StarType.WHITE_DWARF:
			base_danger = 0.25
		VNPTypes.StarType.NEUTRON:
			base_danger = 0.6

	return clampf(base_danger + (roll - 0.5) * 0.1, 0.0, 1.0)

static func _find_home_system(systems: Dictionary, rng: RandomNumberGenerator) -> String:
	var candidates = []
	for sys_id in systems.keys():
		var sys = systems[sys_id]
		if sys.star_type in [VNPTypes.StarType.YELLOW, VNPTypes.StarType.ORANGE]:
			if sys.danger_level < 0.2:
				candidates.append(sys_id)

	if candidates.is_empty():
		# Fallback: pick any low-danger system
		for sys_id in systems.keys():
			if systems[sys_id].danger_level < 0.3:
				candidates.append(sys_id)

	if candidates.is_empty():
		return "sys_0"  # Ultimate fallback

	return candidates[rng.randi() % candidates.size()]

# ============================================================================
# NAVIGATION
# ============================================================================

## Calculate travel time between systems (pure)
static func calc_travel_time(from_system: Dictionary, to_system: Dictionary) -> int:
	var distance = from_system.position.distance_to(to_system.position)
	# ~50 units per turn, minimum 1 turn
	return maxi(1, ceili(distance / 50.0))

## Check if two systems are connected (pure)
static func are_connected(from_system: Dictionary, to_system_id: String) -> bool:
	return to_system_id in from_system.connections

## Get all reachable systems from a given system (for UI highlighting)
static func get_reachable_systems(systems: Dictionary, from_system_id: String) -> Array:
	var from_sys = systems.get(from_system_id, {})
	if from_sys.is_empty():
		return []
	return from_sys.connections.duplicate()

## Find path between two systems using BFS (pure)
static func find_path(systems: Dictionary, from_id: String, to_id: String) -> Dictionary:
	if from_id == to_id:
		return {"found": true, "path": [from_id], "distance": 0}

	var visited = {from_id: null}  # Maps node to previous node
	var queue = [from_id]

	while not queue.is_empty():
		var current = queue.pop_front()
		var current_sys = systems.get(current, {})

		for neighbor_id in current_sys.get("connections", []):
			if neighbor_id not in visited:
				visited[neighbor_id] = current
				queue.append(neighbor_id)

				if neighbor_id == to_id:
					# Reconstruct path
					var path = [to_id]
					var node = to_id
					while visited[node] != null:
						node = visited[node]
						path.push_front(node)
					return {"found": true, "path": path, "distance": path.size() - 1}

	return {"found": false, "path": [], "distance": -1}
