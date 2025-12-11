extends Control

## VNP Main UI Controller
## Thin layer that reads from VNPStore and dispatches commands

# ============================================================================
# NODE REFERENCES
# ============================================================================

# Top bar
@onready var turn_label: Label = $TopBar/HBoxContainer/TurnLabel
@onready var year_label: Label = $TopBar/HBoxContainer/YearLabel
@onready var iron_label: Label = $TopBar/HBoxContainer/IronLabel
@onready var energy_label: Label = $TopBar/HBoxContainer/EnergyLabel
@onready var rare_label: Label = $TopBar/HBoxContainer/RareLabel
@onready var probes_label: Label = $TopBar/HBoxContainer/ProbesLabel

# Galaxy view
@onready var galaxy_view: Control = $MainContent/GalaxyPanel/GalaxyView
@onready var galaxy_camera: Camera2D = $MainContent/GalaxyPanel/GalaxyView/Camera2D

# Right sidebar
@onready var probe_list: ItemList = $MainContent/RightSidebar/SidebarContent/ProbeSection/ProbeList
@onready var system_info: RichTextLabel = $MainContent/RightSidebar/SidebarContent/SystemSection/SystemInfo
@onready var action_buttons: VBoxContainer = $MainContent/RightSidebar/SidebarContent/ActionSection/ActionButtons

# Action buttons
@onready var mine_button: Button = $MainContent/RightSidebar/SidebarContent/ActionSection/ActionButtons/MineButton
@onready var replicate_button: Button = $MainContent/RightSidebar/SidebarContent/ActionSection/ActionButtons/ReplicateButton
@onready var idle_button: Button = $MainContent/RightSidebar/SidebarContent/ActionSection/ActionButtons/IdleButton

# Bottom bar
@onready var next_turn_button: Button = $BottomBar/HBoxContainer/NextTurnButton
@onready var auto_button: Button = $BottomBar/HBoxContainer/AutoButton
@onready var speed_slider: HSlider = $BottomBar/HBoxContainer/SpeedSlider

# Event log
@onready var event_log: RichTextLabel = $MainContent/RightSidebar/SidebarContent/LogSection/EventLog

# Event dialog
@onready var event_dialog: Panel = $EventDialog
@onready var event_title: Label = $EventDialog/VBoxContainer/EventTitle
@onready var event_description: RichTextLabel = $EventDialog/VBoxContainer/EventDescription
@onready var event_choices: VBoxContainer = $EventDialog/VBoxContainer/EventChoices

# Game over screen
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_title: Label = $GameOverPanel/VBoxContainer/Title
@onready var game_over_reason: Label = $GameOverPanel/VBoxContainer/Reason
@onready var game_over_score: Label = $GameOverPanel/VBoxContainer/Score
@onready var game_over_stats: RichTextLabel = $GameOverPanel/VBoxContainer/Stats

# ============================================================================
# LOCAL STATE
# ============================================================================

var _selected_probe_id: String = ""
var _selected_system_id: String = ""
var _hovered_system_id: String = ""
var _auto_advance: bool = false
var _auto_timer: float = 0.0
var _auto_speed: float = 0.5

var _camera_drag: bool = false
var _camera_drag_start: Vector2 = Vector2.ZERO

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_connect_signals()
	VNPStore.start_new_run()

	# Select first probe and center on home system
	_selected_probe_id = "probe_1"
	var state = VNPStore.get_state()
	_selected_system_id = state.home_system
	var home_sys = VNPStore.get_system(state.home_system)
	if not home_sys.is_empty():
		galaxy_camera.position = home_sys.position

	_sync_ui()
	event_dialog.visible = false
	game_over_panel.visible = false

func _connect_signals():
	# Store signals
	VNPStore.state_changed.connect(_on_state_changed)
	VNPStore.turn_advanced.connect(_on_turn_advanced)
	VNPStore.event_triggered.connect(_on_event_triggered)
	VNPStore.game_over.connect(_on_game_over)
	VNPStore.probe_created.connect(_on_probe_created)

	# UI signals
	next_turn_button.pressed.connect(_on_next_turn_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	speed_slider.value_changed.connect(_on_speed_changed)
	mine_button.pressed.connect(_on_mine_pressed)
	replicate_button.pressed.connect(_on_replicate_pressed)
	idle_button.pressed.connect(_on_idle_pressed)
	probe_list.item_selected.connect(_on_probe_selected)

	# Game over buttons
	var new_game_btn = $GameOverPanel/VBoxContainer/ButtonsContainer/NewGameButton
	var main_menu_btn = $GameOverPanel/VBoxContainer/ButtonsContainer/MainMenuButton
	new_game_btn.pressed.connect(_on_new_game_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

func _process(delta: float):
	if _auto_advance and not VNPStore.is_game_over():
		_auto_timer += delta
		if _auto_timer >= _auto_speed:
			_auto_timer = 0.0
			VNPStore.advance_turn()

	# Camera drag
	if _camera_drag:
		var mouse_pos = get_global_mouse_position()
		galaxy_camera.position -= (mouse_pos - _camera_drag_start) / galaxy_camera.zoom.x
		_camera_drag_start = mouse_pos

	galaxy_view.queue_redraw()

func _input(event: InputEvent):
	# Handle keyboard camera controls anywhere
	if event is InputEventKey and event.pressed:
		var move_speed = 20.0 / galaxy_camera.zoom.x
		match event.keycode:
			KEY_W, KEY_UP:
				galaxy_camera.position.y -= move_speed
			KEY_S, KEY_DOWN:
				galaxy_camera.position.y += move_speed
			KEY_A, KEY_LEFT:
				galaxy_camera.position.x -= move_speed
			KEY_D, KEY_RIGHT:
				galaxy_camera.position.x += move_speed
			KEY_SPACE:
				# Advance turn with space
				if not VNPStore.is_game_over():
					VNPStore.advance_turn()

	if not galaxy_view.get_global_rect().has_point(get_global_mouse_position()):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_galaxy_click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_camera_drag = event.pressed
			if event.pressed:
				_camera_drag_start = get_global_mouse_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			galaxy_camera.zoom *= 1.1
			galaxy_camera.zoom = galaxy_camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			galaxy_camera.zoom /= 1.1
			galaxy_camera.zoom = galaxy_camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))

	if event is InputEventMouseMotion:
		_update_hover_system(get_global_mouse_position())

# ============================================================================
# UI SYNC
# ============================================================================

func _sync_ui():
	_sync_resources()
	_sync_probes()
	_sync_system_info()
	_sync_action_buttons()
	_sync_event_log()

func _sync_resources():
	var resources = VNPStore.get_resources()
	var state = VNPStore.get_state()

	turn_label.text = "Turn: %d" % state.current_turn
	year_label.text = "Year: %d" % state.year
	iron_label.text = "Iron: %d" % resources.get("iron", 0)
	energy_label.text = "Energy: %d" % resources.get("energy", 0)
	rare_label.text = "Rare: %d" % resources.get("rare", 0)
	probes_label.text = "Probes: %d" % VNPStore.get_active_probe_count()

func _sync_probes():
	probe_list.clear()
	var probes = VNPStore.get_probes()

	for probe_id in probes.keys():
		var probe = probes[probe_id]
		var status = VNPTypes.get_status_name(probe.status)
		var text = "%s [%s]" % [probe.name, status]
		probe_list.add_item(text)
		probe_list.set_item_metadata(probe_list.item_count - 1, probe_id)

		# Highlight selected
		if probe_id == _selected_probe_id:
			probe_list.select(probe_list.item_count - 1)

func _sync_system_info():
	if _selected_system_id.is_empty():
		system_info.text = "Select a system on the map"
		return

	var system = VNPStore.get_system(_selected_system_id)
	if system.is_empty():
		system_info.text = "Unknown system"
		return

	var star_type_names = ["Red Dwarf", "Yellow", "Orange", "Blue Giant", "White Dwarf", "Neutron"]
	var type_name = star_type_names[system.star_type] if system.star_type < star_type_names.size() else "Unknown"

	var text = "[b]%s[/b]\n" % system.name
	text += "Type: %s\n" % type_name
	text += "Iron: %d / %d\n" % [system.resources.iron, system.max_resources.iron]
	text += "Rare: %d / %d\n" % [system.resources.rare, system.max_resources.rare]
	text += "Danger: %.0f%%\n" % (system.danger_level * 100)

	if system.is_explored:
		text += "[color=green]Explored[/color]\n"
	else:
		text += "[color=gray]Unexplored[/color]\n"

	if system.has_anomaly:
		if system.anomaly_investigated:
			text += "[color=gray]Anomaly: Investigated[/color]\n"
		else:
			text += "[color=yellow]Anomaly: Present![/color]\n"

	# Show probes in this system
	var probes = VNPStore.get_probes()
	var probes_here = []
	for probe in probes.values():
		if probe.current_system == _selected_system_id:
			probes_here.append(probe.name)

	if not probes_here.is_empty():
		text += "\nProbes: %s" % ", ".join(probes_here)

	system_info.text = text

func _sync_action_buttons():
	var probe = VNPStore.get_probe(_selected_probe_id)
	var system = VNPStore.get_system(_selected_system_id)

	var can_act = not probe.is_empty() and probe.status == VNPTypes.ProbeStatus.IDLE
	var has_resources = not system.is_empty() and (system.resources.iron > 0 or system.resources.rare > 0)
	var can_afford_replicate = VNPStore.can_replicate()

	mine_button.disabled = not (can_act and has_resources and probe.current_system == _selected_system_id)
	replicate_button.disabled = not (can_act and can_afford_replicate)
	idle_button.disabled = probe.is_empty() or probe.status == VNPTypes.ProbeStatus.IDLE or probe.status == VNPTypes.ProbeStatus.TRAVELING

	# Update replicate button text with cost
	var cost = VNPTypes.REPLICATION_COST
	replicate_button.text = "Replicate (%d iron, %d energy)" % [cost.iron, cost.energy]

func _sync_event_log():
	var log_entries = VNPStore.get_event_log()
	event_log.clear()

	# Show last 20 entries
	var start = maxi(0, log_entries.size() - 20)
	for i in range(start, log_entries.size()):
		var entry = log_entries[i]
		var color = "white"
		match entry.category:
			"success": color = "green"
			"warning": color = "yellow"
			"error": color = "red"
			"info": color = "gray"

		event_log.append_text("[color=%s][T%d] %s[/color]\n" % [color, entry.turn, entry.message])

	# Scroll to bottom
	event_log.scroll_to_line(event_log.get_line_count())

# ============================================================================
# GALAXY DRAWING
# ============================================================================

func _draw_galaxy():
	# This is called from galaxy_view's _draw
	pass

# Transform world position to screen position (accounts for camera position and zoom)
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var center = galaxy_view.size / 2.0
	return center + (world_pos - galaxy_camera.position) * galaxy_camera.zoom.x

# Called from GalaxyView node
func draw_galaxy_on(canvas: CanvasItem):
	var systems = VNPStore.get_systems()
	var probes = VNPStore.get_probes()
	var state = VNPStore.get_state()
	var zoom = galaxy_camera.zoom.x

	# Get reachable systems if we have an idle probe selected
	var reachable_systems: Array = []
	var selected_probe = VNPStore.get_probe(_selected_probe_id)
	if not selected_probe.is_empty() and selected_probe.status == VNPTypes.ProbeStatus.IDLE:
		var probe_sys = systems.get(selected_probe.current_system, {})
		if not probe_sys.is_empty():
			reachable_systems = probe_sys.get("connections", [])

	# Draw connections first
	for sys_id in systems.keys():
		var sys = systems[sys_id]
		var from_pos = _world_to_screen(sys.position)

		for conn_id in sys.connections:
			var conn_sys = systems.get(conn_id, {})
			if conn_sys.is_empty():
				continue

			var to_pos = _world_to_screen(conn_sys.position)

			# Only draw if at least one end is explored
			var color = Color(0.2, 0.25, 0.3, 0.3)
			if sys.is_explored and conn_sys.is_explored:
				color = Color(0.4, 0.5, 0.6, 0.5)
			elif sys.is_explored or conn_sys.is_explored:
				color = Color(0.3, 0.35, 0.4, 0.4)

			canvas.draw_line(from_pos, to_pos, color, 1.0)

	# Draw systems
	for sys_id in systems.keys():
		var sys = systems[sys_id]
		var pos = _world_to_screen(sys.position)

		# Star size based on type (scaled by zoom)
		var base_sizes = [6, 8, 10, 14, 5, 4]
		var base_size = base_sizes[sys.star_type] if sys.star_type < base_sizes.size() else 8
		var size = base_size * zoom

		var color = VNPTypes.get_star_color(sys.star_type)

		# Dim unexplored systems
		if not sys.is_explored:
			color = Color(0.4, 0.4, 0.5, 0.5)
			size = 4 * zoom

		# Glow effect
		canvas.draw_circle(pos, size * 1.5, Color(color.r, color.g, color.b, 0.2))

		# Main star
		canvas.draw_circle(pos, size, color)

		# Anomaly indicator
		if sys.is_explored and sys.has_anomaly and not sys.anomaly_investigated:
			canvas.draw_arc(pos, size + 4 * zoom, 0, TAU, 16, Color.YELLOW, 2.0)

		# Selection indicator
		if sys_id == _selected_system_id:
			canvas.draw_arc(pos, size + 6 * zoom, 0, TAU, 16, Color.WHITE, 2.0)

		# Hover indicator
		if sys_id == _hovered_system_id and sys_id != _selected_system_id:
			canvas.draw_arc(pos, size + 4 * zoom, 0, TAU, 16, Color(1, 1, 1, 0.5), 1.0)

		# Home system indicator
		if sys_id == state.home_system:
			canvas.draw_arc(pos, size + 8 * zoom, 0, TAU, 16, Color.CYAN, 1.0)

		# Reachable system indicator (green dashed)
		if sys_id in reachable_systems:
			canvas.draw_arc(pos, size + 10 * zoom, 0, TAU, 16, Color(0.3, 1.0, 0.3, 0.6), 2.0)

	# Draw probes
	for probe in probes.values():
		var world_pos: Vector2

		if probe.status == VNPTypes.ProbeStatus.TRAVELING:
			# Interpolate position
			var from_sys = systems.get(probe.current_system, {})
			var to_sys = systems.get(probe.target_system, {})
			if not from_sys.is_empty() and not to_sys.is_empty():
				var travel_total = VNPGalaxyLogic.calc_travel_time(from_sys, to_sys)
				var progress = 1.0 - (float(probe.travel_progress) / float(travel_total))
				world_pos = from_sys.position.lerp(to_sys.position, progress)
			else:
				continue
		else:
			var sys = systems.get(probe.current_system, {})
			if sys.is_empty():
				continue
			world_pos = sys.position + Vector2(12, 0)  # Offset from star

		var pos = _world_to_screen(world_pos)

		# Draw probe triangle (scaled by zoom)
		var probe_size = 5.0 * zoom
		var points = PackedVector2Array([
			pos + Vector2(0, -probe_size),
			pos + Vector2(-probe_size * 0.7, probe_size * 0.5),
			pos + Vector2(probe_size * 0.7, probe_size * 0.5)
		])

		var probe_color = Color.GOLD
		match probe.status:
			VNPTypes.ProbeStatus.MINING:
				probe_color = Color.GREEN
			VNPTypes.ProbeStatus.REPLICATING:
				probe_color = Color.CYAN
			VNPTypes.ProbeStatus.TRAVELING:
				probe_color = Color.ORANGE
			VNPTypes.ProbeStatus.DAMAGED:
				probe_color = Color.RED

		canvas.draw_colored_polygon(points, probe_color)

		# Selection indicator for probe
		if probe.id == _selected_probe_id:
			canvas.draw_arc(pos, probe_size + 3 * zoom, 0, TAU, 12, Color.WHITE, 1.5)

# ============================================================================
# INPUT HANDLERS
# ============================================================================

# Transform screen position to world position (inverse of _world_to_screen)
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var local_pos = screen_pos - galaxy_view.global_position
	var center = galaxy_view.size / 2.0
	return (local_pos - center) / galaxy_camera.zoom.x + galaxy_camera.position

func _handle_galaxy_click(screen_pos: Vector2):
	var world_pos = _screen_to_world(screen_pos)

	# Find clicked system
	var systems = VNPStore.get_systems()
	var closest_id = ""
	var closest_dist = 30.0 / galaxy_camera.zoom.x  # Click radius (adjusted for zoom)

	for sys_id in systems.keys():
		var sys = systems[sys_id]
		var dist = world_pos.distance_to(sys.position)
		if dist < closest_dist:
			closest_dist = dist
			closest_id = sys_id

	if not closest_id.is_empty():
		# Check if we have a selected probe that can travel
		var probe = VNPStore.get_probe(_selected_probe_id)
		if not probe.is_empty() and probe.status == VNPTypes.ProbeStatus.IDLE:
			var from_sys = VNPStore.get_system(probe.current_system)
			if closest_id != probe.current_system and VNPGalaxyLogic.are_connected(from_sys, closest_id):
				# Travel to this system
				VNPStore.move_probe(_selected_probe_id, closest_id)
				return

		# Otherwise, select this system
		_selected_system_id = closest_id
		_sync_system_info()
		_sync_action_buttons()

func _update_hover_system(screen_pos: Vector2):
	var world_pos = _screen_to_world(screen_pos)

	var systems = VNPStore.get_systems()
	var closest_id = ""
	var closest_dist = 30.0 / galaxy_camera.zoom.x  # Adjusted for zoom

	for sys_id in systems.keys():
		var sys = systems[sys_id]
		var dist = world_pos.distance_to(sys.position)
		if dist < closest_dist:
			closest_dist = dist
			closest_id = sys_id

	_hovered_system_id = closest_id

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_next_turn_pressed():
	VNPStore.advance_turn()

func _on_auto_pressed():
	_auto_advance = not _auto_advance
	auto_button.text = "Stop" if _auto_advance else "Auto"

func _on_speed_changed(value: float):
	# Slider is 0-100, convert to delay between turns (1.0 to 0.1 seconds)
	_auto_speed = 1.0 - (value / 100.0 * 0.9)  # 0.1 to 1.0 seconds

func _on_mine_pressed():
	if not _selected_probe_id.is_empty():
		VNPStore.start_mining(_selected_probe_id)

func _on_replicate_pressed():
	if not _selected_probe_id.is_empty():
		VNPStore.start_replication(_selected_probe_id)

func _on_idle_pressed():
	if not _selected_probe_id.is_empty():
		VNPStore.set_probe_idle(_selected_probe_id)

func _on_probe_selected(index: int):
	_selected_probe_id = probe_list.get_item_metadata(index)
	var probe = VNPStore.get_probe(_selected_probe_id)
	if not probe.is_empty():
		_selected_system_id = probe.current_system
		# Center camera on probe's system
		var system = VNPStore.get_system(probe.current_system)
		if not system.is_empty():
			galaxy_camera.position = system.position
	_sync_system_info()
	_sync_action_buttons()

# ============================================================================
# STORE SIGNAL HANDLERS
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_turn_advanced(_turn: int, _year: int):
	pass  # UI already synced via state_changed

func _on_event_triggered(event: Dictionary):
	_show_event_dialog(event)

func _on_game_over(victory: bool, reason: String, score: int):
	_auto_advance = false
	auto_button.text = "Auto"
	_show_game_over(victory, reason, score)

func _on_probe_created(_probe: Dictionary):
	# Select the new probe
	_selected_probe_id = _probe.id

# ============================================================================
# EVENT DIALOG
# ============================================================================

func _show_event_dialog(event: Dictionary):
	event_title.text = event.title
	event_description.text = event.description

	# Clear old choices
	for child in event_choices.get_children():
		child.queue_free()

	# Add choice buttons
	for choice in event.choices:
		var btn = Button.new()
		btn.text = choice.text
		btn.pressed.connect(_on_event_choice.bind(choice.id))
		event_choices.add_child(btn)

	event_dialog.visible = true

func _on_event_choice(choice_id: String):
	VNPStore.resolve_event(choice_id)
	event_dialog.visible = false

# ============================================================================
# GAME OVER
# ============================================================================

func _show_game_over(victory: bool, reason: String, score: int):
	game_over_title.text = "VICTORY!" if victory else "GAME OVER"
	game_over_title.add_theme_color_override("font_color", Color.GREEN if victory else Color.RED)
	game_over_reason.text = reason
	game_over_score.text = "Score: %d" % score

	var state = VNPStore.get_state()
	var stats_text = "[b]Statistics[/b]\n"
	stats_text += "Turns survived: %d\n" % state.current_turn
	stats_text += "Systems explored: %d / %d\n" % [state.systems_explored, state.total_systems]
	stats_text += "Peak probes: %d\n" % state.peak_probes
	stats_text += "Total probes built: %d\n" % state.total_probes_built
	stats_text += "Probes lost: %d\n" % state.probes_lost
	stats_text += "Iron mined: %d\n" % state.total_iron_mined
	stats_text += "Rare mined: %d\n" % state.total_rare_mined

	game_over_stats.text = stats_text
	game_over_panel.visible = true

func _on_new_game_pressed():
	game_over_panel.visible = false
	VNPStore.start_new_run()
	_selected_probe_id = "probe_1"
	_selected_system_id = ""
	_sync_ui()

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
