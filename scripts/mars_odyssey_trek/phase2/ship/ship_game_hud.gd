extends CanvasLayer

## Ship Game HUD - Shows day counter, crisis timers, crew status

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# NODE REFERENCES
# ============================================================================

var day_label: Label
var day_progress_bar: ProgressBar
var crisis_container: VBoxContainer
var crew_status_container: VBoxContainer
var game_over_panel: PanelContainer
var game_over_label: Label
var speed_label: Label

# Crisis timer UI elements
var crisis_bars: Dictionary = {}  # room_type -> ProgressBar

# ============================================================================
# EXTERNAL REFERENCES
# ============================================================================

@export var game_controller_path: NodePath
@export var ship_view_path: NodePath
@export var journey_indicator_path: NodePath

var game_controller: Node
var ship_view: Node2D
var journey_indicator: Node2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_ui()
	_connect_references()

func _connect_references() -> void:
	# Find controller
	if game_controller_path:
		game_controller = get_node(game_controller_path)
	if not game_controller:
		game_controller = get_parent().get_node_or_null("GameController")

	# Find ship view
	if ship_view_path:
		ship_view = get_node(ship_view_path)
	if not ship_view:
		ship_view = get_parent().get_node_or_null("ShipView")

	# Find journey indicator
	if journey_indicator_path:
		journey_indicator = get_node(journey_indicator_path)
	if not journey_indicator:
		journey_indicator = get_parent().get_node_or_null("JourneyIndicator")

	# Connect signals
	if game_controller:
		game_controller.day_changed.connect(_on_day_changed)
		game_controller.crisis_started.connect(_on_crisis_started)
		game_controller.crisis_resolved.connect(_on_crisis_resolved)
		game_controller.crisis_failed.connect(_on_crisis_failed)
		game_controller.game_over.connect(_on_game_over)

func _create_ui() -> void:
	# Top bar container
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 10
	top_bar.offset_bottom = 60
	top_bar.offset_left = 10
	top_bar.offset_right = -10
	add_child(top_bar)

	# Day display
	var day_container = VBoxContainer.new()
	day_container.custom_minimum_size = Vector2(150, 0)
	top_bar.add_child(day_container)

	day_label = Label.new()
	day_label.text = "DAY 1"
	day_label.add_theme_font_size_override("font_size", 24)
	day_container.add_child(day_label)

	day_progress_bar = ProgressBar.new()
	day_progress_bar.custom_minimum_size = Vector2(140, 8)
	day_progress_bar.show_percentage = false
	day_progress_bar.value = 0
	day_container.add_child(day_progress_bar)

	# Speed label
	speed_label = Label.new()
	speed_label.text = "Speed: 1x"
	speed_label.add_theme_font_size_override("font_size", 12)
	day_container.add_child(speed_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Crisis alerts (right side of top bar)
	crisis_container = VBoxContainer.new()
	crisis_container.custom_minimum_size = Vector2(250, 0)
	top_bar.add_child(crisis_container)

	var crisis_title = Label.new()
	crisis_title.text = "ACTIVE CRISES"
	crisis_title.add_theme_font_size_override("font_size", 14)
	crisis_title.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	crisis_container.add_child(crisis_title)

	# Crew status (bottom right)
	crew_status_container = VBoxContainer.new()
	crew_status_container.name = "CrewStatus"
	crew_status_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	crew_status_container.offset_left = -200
	crew_status_container.offset_top = -180
	crew_status_container.offset_right = -10
	crew_status_container.offset_bottom = -10
	add_child(crew_status_container)

	var crew_title = Label.new()
	crew_title.text = "CREW"
	crew_title.add_theme_font_size_override("font_size", 14)
	crew_status_container.add_child(crew_title)

	# Game over panel (hidden initially)
	game_over_panel = PanelContainer.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.offset_left = -200
	game_over_panel.offset_top = -100
	game_over_panel.offset_right = 200
	game_over_panel.offset_bottom = 100
	game_over_panel.visible = false
	add_child(game_over_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.05, 0.05, 0.95)
	panel_style.border_color = Color(1, 0.2, 0.2)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	game_over_panel.add_theme_stylebox_override("panel", panel_style)

	var game_over_content = VBoxContainer.new()
	game_over_content.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(game_over_content)

	var game_over_title = Label.new()
	game_over_title.text = "MISSION FAILED"
	game_over_title.add_theme_font_size_override("font_size", 32)
	game_over_title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_content.add_child(game_over_title)

	game_over_label = Label.new()
	game_over_label.text = ""
	game_over_label.add_theme_font_size_override("font_size", 16)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	game_over_content.add_child(game_over_label)

# ============================================================================
# UPDATE LOOP
# ============================================================================

func _process(_delta: float) -> void:
	_update_day_progress()
	_update_crisis_bars()
	_update_crew_status()

func _update_day_progress() -> void:
	if game_controller:
		day_progress_bar.value = game_controller.get_day_progress() * 100

func _update_crisis_bars() -> void:
	if not game_controller:
		return

	var crises = game_controller.get_active_crises()

	for room_type in crisis_bars:
		if not crises.has(room_type):
			# Crisis resolved - remove bar
			crisis_bars[room_type].queue_free()
			crisis_bars.erase(room_type)

	for room_type in crises:
		var crisis = crises[room_type]
		if crisis_bars.has(room_type):
			# Update existing bar
			var bar = crisis_bars[room_type]
			var progress = (crisis.time_remaining / game_controller.crisis_time_limit) * 100
			bar.value = max(0, progress)

			# Color based on urgency
			var style = bar.get_theme_stylebox("fill").duplicate()
			if progress < 25:
				style.bg_color = Color(1, 0, 0)  # Red - critical
			elif progress < 50:
				style.bg_color = Color(1, 0.5, 0)  # Orange - warning
			else:
				style.bg_color = Color(1, 0.8, 0)  # Yellow - attention
			bar.add_theme_stylebox_override("fill", style)

func _update_crew_status() -> void:
	if not ship_view:
		return

	# Remove old status labels (except title)
	for child in crew_status_container.get_children():
		if child is Label and child.text != "CREW":
			child.queue_free()

	var crew_status = ship_view.get_crew_status()
	for role in ["commander", "engineer", "scientist", "medical"]:
		if crew_status.has(role):
			var status = crew_status[role]
			var label = Label.new()
			label.text = "%s: %s" % [role.substr(0, 4).to_upper(), status.state]
			label.add_theme_font_size_override("font_size", 11)

			# Color by state
			match status.state:
				"Idle":
					label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				"Moving":
					label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
				"Running":
					label.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
				"Working":
					label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
				_:
					label.add_theme_color_override("font_color", Color(1, 1, 1))

			crew_status_container.add_child(label)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_day_changed(day: int) -> void:
	day_label.text = "DAY %d" % day
	if journey_indicator:
		journey_indicator.set_current_day(day)

func _on_crisis_started(room_type: ShipTypes.RoomType, time_remaining: float) -> void:
	# Create crisis bar
	var crisis_item = HBoxContainer.new()
	crisis_item.name = "Crisis_%d" % room_type

	var room_label = Label.new()
	room_label.text = ShipTypes.get_room_name(room_type)
	room_label.custom_minimum_size = Vector2(100, 0)
	room_label.add_theme_font_size_override("font_size", 12)
	room_label.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	crisis_item.add_child(room_label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 16)
	bar.show_percentage = false
	bar.value = 100

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1, 0.8, 0)
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.1, 0.1)
	bar.add_theme_stylebox_override("background", bg_style)

	crisis_item.add_child(bar)

	crisis_container.add_child(crisis_item)
	crisis_bars[room_type] = bar

func _on_crisis_resolved(room_type: ShipTypes.RoomType) -> void:
	# Find and remove the crisis item
	var item_name = "Crisis_%d" % room_type
	var item = crisis_container.get_node_or_null(item_name)
	if item:
		item.queue_free()
	crisis_bars.erase(room_type)

func _on_crisis_failed(room_type: ShipTypes.RoomType) -> void:
	# Same as resolved for UI cleanup
	_on_crisis_resolved(room_type)

func _on_game_over(reason: String) -> void:
	game_over_label.text = reason
	game_over_panel.visible = true

# ============================================================================
# PUBLIC API
# ============================================================================

func update_speed_display(speed: float) -> void:
	speed_label.text = "Speed: %dx" % int(speed)
