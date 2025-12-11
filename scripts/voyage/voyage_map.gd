extends Control

## Main voyage map controller
## Single screen game: navigate from Earth to Mars with limited fuel

# ============================================================================
# SIGNALS
# ============================================================================

signal node_clicked(node_id: String)
signal route_confirmed(from_id: String, to_id: String)

# ============================================================================
# STATE
# ============================================================================

var state: VoyageState
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Travel animation
var _travel_speed: float = 0.05  # Progress per second (full edge in 20 seconds)
var _paused: bool = false

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var graph_canvas: Node2D = $GraphCanvas
@onready var fuel_bar: ProgressBar = $UI/TopBar/FuelBar
@onready var fuel_label: Label = $UI/TopBar/FuelPercent
@onready var day_label: Label = $UI/TopBar/DayLabel
@onready var status_label: Label = $UI/BottomBar/StatusLabel
@onready var game_over_panel: Panel = $UI/GameOverPanel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_rng.seed = int(Time.get_unix_time_from_system())
	game_over_panel.visible = false

	# Generate the voyage graph
	state = VoyageState.generate_graph(_rng.randi())

	# Render initial state
	_render_graph()
	_update_ui()

	# Auto-select first connected node
	var connections = state.get_connected_nodes("earth")
	if not connections.is_empty():
		_on_node_clicked(connections[0])

func _process(delta: float):
	if state.game_over or _paused:
		return

	if state.traveling:
		_advance_travel(delta)

func _advance_travel(delta: float):
	var new_progress = state.ship_progress + _travel_speed * delta

	if new_progress >= 1.0:
		# Arrived at destination
		state = state.with_arrival()
		_on_arrival()
	else:
		state = state.with_progress(new_progress)
		_update_ship_position()

func _on_arrival():
	_update_ui()
	_render_graph()

	if state.game_over:
		_show_game_over()
		return

	# Random chance to spawn hazard
	if _rng.randf() < 0.3:
		_spawn_random_hazard()

	# Age existing hazards
	state = state.with_hazards_aged()

	# Wait for player to select next node
	status_label.text = "Select your next waypoint"

func _spawn_random_hazard():
	# Pick a random future edge
	var future_edges: Array = []
	for edge in state.edges:
		# Only edges we haven't passed yet
		if _is_future_edge(edge.from, edge.to):
			future_edges.append(edge)

	if future_edges.is_empty():
		return

	var edge = future_edges[_rng.randi() % future_edges.size()]
	var hazard_types = ["debris", "flare", "gravity_assist"]
	var hazard_type = hazard_types[_rng.randi() % hazard_types.size()]

	state = state.with_hazard(edge.from, edge.to, hazard_type)
	_render_graph()

func _is_future_edge(from_id: String, to_id: String) -> bool:
	# Check if this edge is reachable from current position
	var reachable = _get_reachable_nodes(state.current_node)
	return from_id in reachable or from_id == state.current_node

func _get_reachable_nodes(from_id: String) -> Array:
	var reachable: Array = [from_id]
	var to_check: Array = [from_id]

	while not to_check.is_empty():
		var current = to_check.pop_front()
		for connected in state.get_connected_nodes(current):
			if connected not in reachable:
				reachable.append(connected)
				to_check.append(connected)

	return reachable

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _on_node_clicked(node_id: String):
	if state.traveling or state.game_over:
		return

	# Check if this node is connected to current position
	var connected = state.get_connected_nodes(state.current_node)
	if node_id not in connected:
		return

	# Select this as destination
	state = state.with_next_node(node_id)
	_render_graph()
	_update_preview()

func _on_confirm_route():
	if state.next_node.is_empty() or state.traveling:
		return

	# Start traveling
	state = state.with_travel_started()
	status_label.text = "Traveling..."
	_update_ui()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if not state.next_node.is_empty() and not state.traveling:
				_on_confirm_route()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ============================================================================
# RENDERING
# ============================================================================

func _render_graph():
	# Clear existing
	for child in graph_canvas.get_children():
		child.queue_free()

	# Draw edges first (behind nodes)
	for edge in state.edges:
		_draw_edge(edge)

	# Draw hazards
	for hazard in state.hazards:
		_draw_hazard(hazard)

	# Draw nodes
	for node in state.nodes:
		_draw_node(node)

	# Draw ship
	_draw_ship()

func _draw_edge(edge: Dictionary):
	var from_node = state.get_node(edge.from)
	var to_node = state.get_node(edge.to)
	if from_node.is_empty() or to_node.is_empty():
		return

	var line = Line2D.new()
	line.add_point(from_node.pos)
	line.add_point(to_node.pos)

	# Width based on fuel cost (thicker = more expensive)
	var cost = state.get_edge_cost(edge.from, edge.to)
	line.width = remap(cost, 5.0, 25.0, 2.0, 8.0)

	# Color based on selection state
	var is_selected = (edge.from == state.current_node and edge.to == state.next_node)
	var is_past = _is_past_edge(edge.from)

	if is_selected:
		line.default_color = Color("#00ffff")  # Cyan for selected
		line.width += 2
	elif is_past:
		line.default_color = Color("#222222")  # Dim for past
	else:
		line.default_color = Color("#444444")  # Gray for available

	# Hazard tinting
	var edge_id = edge.from + "-" + edge.to
	for hazard in state.hazards:
		if hazard.edge_id == edge_id:
			match hazard.type:
				"debris":
					line.default_color = line.default_color.lerp(Color("#ff6600"), 0.5)
				"flare":
					line.default_color = line.default_color.lerp(Color("#ff0000"), 0.5)
				"gravity_assist":
					line.default_color = line.default_color.lerp(Color("#0066ff"), 0.5)

	graph_canvas.add_child(line)

func _is_past_edge(from_id: String) -> bool:
	# An edge is "past" if its origin is not reachable from current position
	return not _is_future_edge(from_id, "")

func _draw_node(node: Dictionary):
	var node_visual = Control.new()
	node_visual.position = node.pos - Vector2(20, 20)
	node_visual.custom_minimum_size = Vector2(40, 40)

	# Circle
	var circle = ColorRect.new()
	circle.custom_minimum_size = Vector2(24, 24)
	circle.position = Vector2(8, 8)
	circle.color = Color.WHITE

	# Highlight current node
	if node.id == state.current_node:
		circle.color = Color("#00ffff")
	elif node.id == state.next_node:
		circle.color = Color("#00ff00")
	elif node.id in state.get_connected_nodes(state.current_node):
		circle.color = Color("#ffffff")
	else:
		circle.color = Color("#666666")

	node_visual.add_child(circle)

	# Label
	if not node.label.is_empty():
		var label = Label.new()
		label.text = node.label
		label.position = Vector2(0, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(40, 20)
		node_visual.add_child(label)

	# Make clickable
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(40, 40)
	button.position = Vector2.ZERO
	button.modulate = Color(1, 1, 1, 0)  # Invisible
	button.pressed.connect(func(): _on_node_clicked(node.id))
	node_visual.add_child(button)

	graph_canvas.add_child(node_visual)

func _draw_hazard(hazard: Dictionary):
	var parts = hazard.edge_id.split("-")
	if parts.size() != 2:
		return

	var from_node = state.get_node(parts[0])
	var to_node = state.get_node(parts[1])
	if from_node.is_empty() or to_node.is_empty():
		return

	var mid_point = (from_node.pos + to_node.pos) / 2

	var hazard_visual = ColorRect.new()
	hazard_visual.custom_minimum_size = Vector2(30, 30)
	hazard_visual.position = mid_point - Vector2(15, 15)

	match hazard.type:
		"debris":
			hazard_visual.color = Color("#ff6600", 0.5)
		"flare":
			hazard_visual.color = Color("#ff0000", 0.5)
		"gravity_assist":
			hazard_visual.color = Color("#0066ff", 0.5)

	graph_canvas.add_child(hazard_visual)

func _draw_ship():
	var ship = Polygon2D.new()
	ship.polygon = PackedVector2Array([
		Vector2(15, 0),
		Vector2(-10, -8),
		Vector2(-5, 0),
		Vector2(-10, 8)
	])
	ship.color = Color("#00ffff")
	ship.position = state.get_ship_position()

	# Rotate to face direction of travel
	if state.traveling and not state.next_node.is_empty():
		var from_node = state.get_node(state.current_node)
		var to_node = state.get_node(state.next_node)
		if not from_node.is_empty() and not to_node.is_empty():
			var direction = (to_node.pos - from_node.pos).normalized()
			ship.rotation = direction.angle()

	graph_canvas.add_child(ship)

func _update_ship_position():
	# Find ship in canvas and update position
	for child in graph_canvas.get_children():
		if child is Polygon2D:
			child.position = state.get_ship_position()
			break

# ============================================================================
# UI
# ============================================================================

func _update_ui():
	fuel_bar.value = state.fuel
	fuel_label.text = "%.0f%%" % state.fuel
	day_label.text = "Day %d" % state.day

	# Color fuel bar based on level
	if state.fuel > 50:
		fuel_bar.modulate = Color("#00ff00")
	elif state.fuel > 25:
		fuel_bar.modulate = Color("#ffff00")
	else:
		fuel_bar.modulate = Color("#ff0000")

func _update_preview():
	if state.next_node.is_empty():
		status_label.text = "Select a waypoint"
		return

	var cost = state.get_edge_cost(state.current_node, state.next_node)
	var remaining = state.fuel - cost

	if remaining > 0:
		status_label.text = "Cost: %.0f%% fuel | Press SPACE to confirm" % cost
	else:
		status_label.text = "WARNING: Not enough fuel! (%.0f%% needed)" % cost

func _show_game_over():
	game_over_panel.visible = true

	var title = game_over_panel.get_node("VBox/TitleLabel")
	var message = game_over_panel.get_node("VBox/MessageLabel")

	if state.victory:
		title.text = "MARS REACHED!"
		message.text = "You arrived with %.0f%% fuel remaining.\nJourney took %d days." % [state.fuel, state.day]
		title.modulate = Color("#00ff00")
	else:
		title.text = "MISSION FAILED"
		message.text = "Your ship ran out of fuel.\nYou were stranded in space on day %d." % state.day
		title.modulate = Color("#ff0000")

func _on_restart_pressed():
	state = VoyageState.generate_graph(_rng.randi())
	game_over_panel.visible = false
	_render_graph()
	_update_ui()

	var connections = state.get_connected_nodes("earth")
	if not connections.is_empty():
		_on_node_clicked(connections[0])

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
