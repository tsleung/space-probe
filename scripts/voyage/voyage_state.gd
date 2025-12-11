class_name VoyageState
extends RefCounted

## Pure state container for the voyage graph
## No side effects - just data

# ============================================================================
# GRAPH DATA
# ============================================================================

var nodes: Array = []  # {id, pos, label}
var edges: Array = []  # {from, to, base_cost}

# ============================================================================
# GAME STATE
# ============================================================================

var current_node: String = "earth"
var next_node: String = ""  # Selected next destination
var fuel: float = 100.0
var day: int = 0
var ship_progress: float = 0.0  # 0.0-1.0 along current edge
var traveling: bool = false
var hazards: Array = []  # {edge_id, type, severity, duration}
var game_over: bool = false
var victory: bool = false

# ============================================================================
# GRAPH GENERATION
# ============================================================================

static func generate_graph(seed_value: int = 0) -> VoyageState:
	var state = VoyageState.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value > 0 else int(Time.get_unix_time_from_system())

	# Fixed structure: Earth -> 2 waypoints -> 3 waypoints -> 2 waypoints -> Mars
	# This creates meaningful routing decisions

	var screen_width = 1000.0
	var screen_height = 600.0
	var margin = 80.0

	state.nodes = [
		# Start
		{"id": "earth", "pos": Vector2(margin, screen_height / 2), "label": "Earth"},

		# Layer 1 (2 nodes)
		{"id": "w1a", "pos": Vector2(margin + screen_width * 0.2, screen_height * 0.3 + rng.randf_range(-30, 30)), "label": ""},
		{"id": "w1b", "pos": Vector2(margin + screen_width * 0.2, screen_height * 0.7 + rng.randf_range(-30, 30)), "label": ""},

		# Layer 2 (3 nodes) - most routing options here
		{"id": "w2a", "pos": Vector2(margin + screen_width * 0.45, screen_height * 0.2 + rng.randf_range(-20, 20)), "label": ""},
		{"id": "w2b", "pos": Vector2(margin + screen_width * 0.45, screen_height * 0.5 + rng.randf_range(-20, 20)), "label": ""},
		{"id": "w2c", "pos": Vector2(margin + screen_width * 0.45, screen_height * 0.8 + rng.randf_range(-20, 20)), "label": ""},

		# Layer 3 (2 nodes)
		{"id": "w3a", "pos": Vector2(margin + screen_width * 0.7, screen_height * 0.35 + rng.randf_range(-30, 30)), "label": ""},
		{"id": "w3b", "pos": Vector2(margin + screen_width * 0.7, screen_height * 0.65 + rng.randf_range(-30, 30)), "label": ""},

		# End
		{"id": "mars", "pos": Vector2(screen_width - margin, screen_height / 2), "label": "Mars"}
	]

	# Generate edges with fuel costs
	# Shorter visual distance = higher cost (it's a fuel-efficient detour vs direct burn)
	state.edges = [
		# Earth to Layer 1
		{"from": "earth", "to": "w1a", "base_cost": _calc_edge_cost(state, "earth", "w1a", rng)},
		{"from": "earth", "to": "w1b", "base_cost": _calc_edge_cost(state, "earth", "w1b", rng)},

		# Layer 1 to Layer 2
		{"from": "w1a", "to": "w2a", "base_cost": _calc_edge_cost(state, "w1a", "w2a", rng)},
		{"from": "w1a", "to": "w2b", "base_cost": _calc_edge_cost(state, "w1a", "w2b", rng)},
		{"from": "w1b", "to": "w2b", "base_cost": _calc_edge_cost(state, "w1b", "w2b", rng)},
		{"from": "w1b", "to": "w2c", "base_cost": _calc_edge_cost(state, "w1b", "w2c", rng)},

		# Layer 2 to Layer 3
		{"from": "w2a", "to": "w3a", "base_cost": _calc_edge_cost(state, "w2a", "w3a", rng)},
		{"from": "w2b", "to": "w3a", "base_cost": _calc_edge_cost(state, "w2b", "w3a", rng)},
		{"from": "w2b", "to": "w3b", "base_cost": _calc_edge_cost(state, "w2b", "w3b", rng)},
		{"from": "w2c", "to": "w3b", "base_cost": _calc_edge_cost(state, "w2c", "w3b", rng)},

		# Layer 3 to Mars
		{"from": "w3a", "to": "mars", "base_cost": _calc_edge_cost(state, "w3a", "mars", rng)},
		{"from": "w3b", "to": "mars", "base_cost": _calc_edge_cost(state, "w3b", "mars", rng)},
	]

	return state

static func _calc_edge_cost(state: VoyageState, from_id: String, to_id: String, rng: RandomNumberGenerator) -> float:
	var from_node = state.get_node(from_id)
	var to_node = state.get_node(to_id)
	if from_node.is_empty() or to_node.is_empty():
		return 15.0

	# Base cost with some randomness
	# Costs are tuned so total journey is ~90-100% of fuel
	var base = rng.randf_range(10.0, 18.0)
	return snappedf(base, 1.0)

# ============================================================================
# GETTERS
# ============================================================================

func get_node(id: String) -> Dictionary:
	for node in nodes:
		if node.id == id:
			return node
	return {}

func get_edge(from_id: String, to_id: String) -> Dictionary:
	for edge in edges:
		if edge.from == from_id and edge.to == to_id:
			return edge
	return {}

func get_edges_from(node_id: String) -> Array:
	var result: Array = []
	for edge in edges:
		if edge.from == node_id:
			result.append(edge)
	return result

func get_connected_nodes(node_id: String) -> Array:
	var result: Array = []
	for edge in edges:
		if edge.from == node_id:
			result.append(edge.to)
	return result

func get_edge_cost(from_id: String, to_id: String) -> float:
	var edge = get_edge(from_id, to_id)
	if edge.is_empty():
		return 0.0

	var base_cost = edge.base_cost

	# Apply hazard modifiers
	var edge_id = from_id + "-" + to_id
	for hazard in hazards:
		if hazard.edge_id == edge_id:
			match hazard.type:
				"debris":
					base_cost *= 1.3  # +30% fuel through debris
				"flare":
					base_cost *= 1.5  # +50% through solar flare
				"gravity_assist":
					base_cost *= 0.7  # -30% with gravity assist

	return base_cost

func get_ship_position() -> Vector2:
	if not traveling or next_node.is_empty():
		var node = get_node(current_node)
		return node.pos if not node.is_empty() else Vector2.ZERO

	var from_node = get_node(current_node)
	var to_node = get_node(next_node)
	if from_node.is_empty() or to_node.is_empty():
		return Vector2.ZERO

	return from_node.pos.lerp(to_node.pos, ship_progress)

# ============================================================================
# STATE MUTATIONS (return new state)
# ============================================================================

func with_next_node(node_id: String) -> VoyageState:
	var new_state = _duplicate()
	new_state.next_node = node_id
	return new_state

func with_travel_started() -> VoyageState:
	var new_state = _duplicate()
	new_state.traveling = true
	new_state.ship_progress = 0.0
	return new_state

func with_progress(progress: float) -> VoyageState:
	var new_state = _duplicate()
	new_state.ship_progress = clampf(progress, 0.0, 1.0)
	return new_state

func with_arrival() -> VoyageState:
	var new_state = _duplicate()
	var cost = get_edge_cost(current_node, next_node)

	new_state.fuel = maxf(0.0, fuel - cost)
	new_state.current_node = next_node
	new_state.next_node = ""
	new_state.traveling = false
	new_state.ship_progress = 0.0
	new_state.day += _get_travel_days()

	# Check win/lose
	if new_state.current_node == "mars":
		new_state.victory = true
		new_state.game_over = true
	elif new_state.fuel <= 0:
		new_state.game_over = true

	return new_state

func with_hazard(edge_from: String, edge_to: String, hazard_type: String, severity: float = 1.0) -> VoyageState:
	var new_state = _duplicate()
	new_state.hazards = hazards.duplicate()
	new_state.hazards.append({
		"edge_id": edge_from + "-" + edge_to,
		"type": hazard_type,
		"severity": severity,
		"duration": 3  # Days until hazard clears
	})
	return new_state

func with_hazards_aged() -> VoyageState:
	var new_state = _duplicate()
	var remaining: Array = []
	for hazard in hazards:
		var aged = hazard.duplicate()
		aged.duration -= 1
		if aged.duration > 0:
			remaining.append(aged)
	new_state.hazards = remaining
	return new_state

func _get_travel_days() -> int:
	# Each segment takes ~15-25 days
	return 20

func _duplicate() -> VoyageState:
	var new_state = VoyageState.new()
	new_state.nodes = nodes.duplicate(true)
	new_state.edges = edges.duplicate(true)
	new_state.current_node = current_node
	new_state.next_node = next_node
	new_state.fuel = fuel
	new_state.day = day
	new_state.ship_progress = ship_progress
	new_state.traveling = traveling
	new_state.hazards = hazards.duplicate(true)
	new_state.game_over = game_over
	new_state.victory = victory
	return new_state
