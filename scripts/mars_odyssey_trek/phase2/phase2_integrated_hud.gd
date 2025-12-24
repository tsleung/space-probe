extends CanvasLayer

## Phase2IntegratedHUD - Combined HUD for ship cutaway view
## Integrates Phase2Store resources with visual ship status

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

# ============================================================================
# REFERENCES
# ============================================================================

@export var store_path: NodePath
@export var ship_view_path: NodePath
@export var journey_indicator_path: NodePath

var store: Node
var ship_view: Node2D
var journey_indicator: Node2D

# ============================================================================
# UI ELEMENTS
# ============================================================================

# Top bar
var day_label: Label
var speed_label: Label
var auto_play_label: Label
var crisis_label: Label

# Controller reference for auto-play toggle
var controller: Node
var crisis_controller: Node

# Resource bars
var resource_container: VBoxContainer
var resource_bars: Dictionary = {}  # resource_name -> ProgressBar

# Crew status
var crew_container: VBoxContainer

# Event popup
var event_panel: PanelContainer
var event_title: Label
var event_description: Label
var event_options: VBoxContainer

# Game over
var game_over_panel: PanelContainer
var game_over_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_ui()
	await get_tree().process_frame
	_connect_references()

func _connect_references() -> void:
	# Find store
	if store_path:
		store = get_node(store_path)
	if not store:
		store = get_parent().get_node_or_null("Phase2Store")

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

	# Find controller for auto-play toggle
	controller = get_parent().get_node_or_null("Phase2Controller")
	if controller:
		controller.auto_play_changed.connect(_on_auto_play_changed)
		_update_auto_play_display()

	# Find crisis controller
	crisis_controller = get_parent().get_node_or_null("CrisisController")
	if crisis_controller and crisis_controller.has_signal("crisis_count_changed"):
		crisis_controller.crisis_count_changed.connect(_on_crisis_count_changed)

	if store:
		store.hour_advanced.connect(_on_hour_advanced)
		store.day_advanced.connect(_on_day_advanced)
		store.speed_changed.connect(_on_speed_changed)
		store.resources_changed.connect(_on_resources_changed)
		store.crew_changed.connect(_on_crew_changed)
		store.event_triggered.connect(_on_event_triggered)
		store.event_resolved.connect(_on_event_resolved)
		store.game_over.connect(_on_game_over)
		store.arrival.connect(_on_arrival)

		# Initial sync
		_sync_from_store()

func _on_arrival() -> void:
	## Mars arrival - trigger the ceremony!
	start_arrival_ceremony()

func _create_ui() -> void:
	# Top bar with day and resources
	var top_panel = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 80
	add_child(top_panel)

	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	top_panel.add_theme_stylebox_override("panel", top_style)

	var top_hbox = HBoxContainer.new()
	top_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_panel.add_child(top_hbox)

	# Left: Day display
	var day_container = VBoxContainer.new()
	day_container.custom_minimum_size = Vector2(120, 0)
	top_hbox.add_child(day_container)

	day_label = Label.new()
	day_label.text = "DAY 1 / 183"
	day_label.add_theme_font_size_override("font_size", 20)
	day_container.add_child(day_label)

	speed_label = Label.new()
	speed_label.text = "Speed: Normal"
	speed_label.add_theme_font_size_override("font_size", 11)
	speed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	day_container.add_child(speed_label)

	# Auto-play indicator (clickable to toggle)
	auto_play_label = Label.new()
	auto_play_label.text = "[A] AI: ON"
	auto_play_label.add_theme_font_size_override("font_size", 11)
	auto_play_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	auto_play_label.mouse_filter = Control.MOUSE_FILTER_STOP
	auto_play_label.gui_input.connect(_on_auto_play_clicked)
	day_container.add_child(auto_play_label)

	# Crisis counter
	crisis_label = Label.new()
	crisis_label.text = "CRISES: 0"
	crisis_label.add_theme_font_size_override("font_size", 11)
	crisis_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	day_container.add_child(crisis_label)

	# Center: Resource bars
	resource_container = VBoxContainer.new()
	resource_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(resource_container)

	var resource_row1 = HBoxContainer.new()
	resource_container.add_child(resource_row1)
	_create_resource_bar(resource_row1, "food", "FOOD", Color(0.8, 0.6, 0.3))
	_create_resource_bar(resource_row1, "water", "WATER", Color(0.3, 0.6, 0.9))
	_create_resource_bar(resource_row1, "oxygen", "O2", Color(0.4, 0.8, 0.9))

	var resource_row2 = HBoxContainer.new()
	resource_container.add_child(resource_row2)
	_create_resource_bar(resource_row2, "power", "POWER", Color(0.9, 0.8, 0.3))
	_create_resource_bar(resource_row2, "fuel", "FUEL", Color(0.7, 0.4, 0.7))

	# Right: Crew status
	crew_container = VBoxContainer.new()
	crew_container.custom_minimum_size = Vector2(150, 0)
	top_hbox.add_child(crew_container)

	var crew_title = Label.new()
	crew_title.text = "CREW"
	crew_title.add_theme_font_size_override("font_size", 12)
	crew_container.add_child(crew_title)

	# Event popup (hidden initially)
	_create_event_popup()

	# Game over panel (hidden initially)
	_create_game_over_panel()

func _create_resource_bar(parent: HBoxContainer, resource_id: String, label_text: String, color: Color) -> void:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(100, 0)
	parent.add_child(container)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 12)
	bar.show_percentage = false
	bar.value = 100
	container.add_child(bar)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2)
	bar.add_theme_stylebox_override("background", bg_style)

	resource_bars[resource_id] = bar

func _create_event_popup() -> void:
	event_panel = PanelContainer.new()
	event_panel.set_anchors_preset(Control.PRESET_CENTER)
	event_panel.offset_left = -250
	event_panel.offset_top = -150
	event_panel.offset_right = 250
	event_panel.offset_bottom = 150
	event_panel.visible = false
	add_child(event_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.18, 0.98)
	panel_style.border_color = Color(0.4, 0.5, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	event_panel.add_theme_stylebox_override("panel", panel_style)

	var event_content = VBoxContainer.new()
	event_content.add_theme_constant_override("separation", 10)
	event_panel.add_child(event_content)

	event_title = Label.new()
	event_title.text = "EVENT TITLE"
	event_title.add_theme_font_size_override("font_size", 18)
	event_title.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_content.add_child(event_title)

	var separator = HSeparator.new()
	event_content.add_child(separator)

	event_description = Label.new()
	event_description.text = "Event description goes here..."
	event_description.add_theme_font_size_override("font_size", 13)
	event_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_content.add_child(event_description)

	event_options = VBoxContainer.new()
	event_options.add_theme_constant_override("separation", 8)
	event_content.add_child(event_options)

func _create_game_over_panel() -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.offset_left = -200
	game_over_panel.offset_top = -80
	game_over_panel.offset_right = 200
	game_over_panel.offset_bottom = 80
	game_over_panel.visible = false
	add_child(game_over_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	panel_style.border_color = Color(0.8, 0.2, 0.2)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	game_over_panel.add_theme_stylebox_override("panel", panel_style)

	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(content)

	var title = Label.new()
	title.text = "MISSION FAILED"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	game_over_label = Label.new()
	game_over_label.text = ""
	game_over_label.add_theme_font_size_override("font_size", 14)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(game_over_label)

	# Create arrival panel
	_create_arrival_panel()

# Arrival ceremony
var arrival_panel: PanelContainer
var arrival_phase: int = 0
var arrival_timer: float = 0.0
var arrival_active: bool = false

func _create_arrival_panel() -> void:
	arrival_panel = PanelContainer.new()
	arrival_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrival_panel.visible = false
	add_child(arrival_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)  # Will fade in
	arrival_panel.add_theme_stylebox_override("panel", panel_style)

	var center_content = VBoxContainer.new()
	center_content.set_anchors_preset(Control.PRESET_CENTER)
	center_content.alignment = BoxContainer.ALIGNMENT_CENTER
	arrival_panel.add_child(center_content)

	# Mars visual
	var mars_container = Control.new()
	mars_container.custom_minimum_size = Vector2(200, 200)
	mars_container.name = "MarsVisual"
	center_content.add_child(mars_container)

	# Title
	var title = Label.new()
	title.name = "ArrivalTitle"
	title.text = "🔴 MARS ORBIT ACHIEVED 🔴"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate.a = 0
	center_content.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.name = "ArrivalSubtitle"
	subtitle.text = "183 Days. 225 Million Kilometers. You made it."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate.a = 0
	center_content.add_child(subtitle)

	# Stats
	var stats = Label.new()
	stats.name = "ArrivalStats"
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.modulate.a = 0
	center_content.add_child(stats)

	# Continue button
	var continue_btn = Button.new()
	continue_btn.name = "ContinueBtn"
	continue_btn.text = "Begin Mars Surface Operations"
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_arrival_continue)
	center_content.add_child(continue_btn)

func start_arrival_ceremony() -> void:
	## Begin the Mars arrival celebration!
	arrival_active = true
	arrival_phase = 0
	arrival_timer = 0.0
	arrival_panel.visible = true

	# Calculate stats
	if store:
		var state = store.get_state()
		var stats_node = arrival_panel.find_child("ArrivalStats", true, false)
		if stats_node:
			var crew_alive = 0
			for member in state.crew:
				if member.health > 0:
					crew_alive += 1
			var food_remaining = state.resources.food.current
			var water_remaining = state.resources.water.current

			stats_node.text = "MISSION SUMMARY\n"
			stats_node.text += "━━━━━━━━━━━━━━━━━━━━\n"
			stats_node.text += "Crew Surviving: %d / 4\n" % crew_alive
			stats_node.text += "Food Remaining: %d units\n" % int(food_remaining)
			stats_node.text += "Water Remaining: %d units\n" % int(water_remaining)
			stats_node.text += "━━━━━━━━━━━━━━━━━━━━"

func _process(delta: float) -> void:
	if arrival_active:
		_process_arrival_ceremony(delta)

func _process_arrival_ceremony(delta: float) -> void:
	arrival_timer += delta

	var bg_style = arrival_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var title_node = arrival_panel.find_child("ArrivalTitle", true, false)
	var subtitle_node = arrival_panel.find_child("ArrivalSubtitle", true, false)
	var stats_node = arrival_panel.find_child("ArrivalStats", true, false)
	var continue_btn = arrival_panel.find_child("ContinueBtn", true, false)

	match arrival_phase:
		0:  # Fade background to dark
			if bg_style:
				bg_style.bg_color.a = min(bg_style.bg_color.a + delta * 0.5, 0.9)
			if arrival_timer > 2.0:
				arrival_phase = 1
				arrival_timer = 0.0
		1:  # Fade in title
			if title_node:
				title_node.modulate.a = min(title_node.modulate.a + delta * 1.5, 1.0)
			if arrival_timer > 1.5:
				arrival_phase = 2
				arrival_timer = 0.0
		2:  # Fade in subtitle
			if subtitle_node:
				subtitle_node.modulate.a = min(subtitle_node.modulate.a + delta * 2.0, 1.0)
			if arrival_timer > 1.0:
				arrival_phase = 3
				arrival_timer = 0.0
		3:  # Fade in stats
			if stats_node:
				stats_node.modulate.a = min(stats_node.modulate.a + delta * 2.0, 1.0)
			if arrival_timer > 1.5:
				arrival_phase = 4
				arrival_timer = 0.0
		4:  # Show continue button
			if continue_btn:
				continue_btn.visible = true
			arrival_phase = 5
		5:  # Waiting for user
			pass

func _on_arrival_continue() -> void:
	arrival_active = false
	arrival_panel.visible = false
	# Could emit a signal to transition to Phase 3 here
	print("[HUD] Mars arrival complete - ready for Phase 3!")

# ============================================================================
# STORE SYNC
# ============================================================================

func _sync_from_store() -> void:
	if not store:
		return

	var state = store.get_state()
	var current_hour = state.get("current_hour", 0)
	_update_day_hour(state.current_day, current_hour, state.total_days)
	_update_resources(state.resources)
	_update_crew_display(state.crew)

	if journey_indicator:
		journey_indicator.set_current_day(state.current_day)

func _update_day_hour(day: int, hour: int, total_days: int) -> void:
	## Display day and hour in format "DAY 1, 14:00 / 183"
	day_label.text = "DAY %d, %02d:00 / %d" % [day, hour, total_days]

func _update_resources(resources: Dictionary) -> void:
	for resource_id in resources:
		var bar = resource_bars.get(resource_id)
		if bar:
			var resource = resources[resource_id]
			var current = resource.get("current", 0)
			var max_val = resource.get("max", 100)
			bar.value = (float(current) / float(max_val)) * 100.0 if max_val > 0 else 0

func _update_crew_display(crew: Array) -> void:
	# Clear old crew labels
	for child in crew_container.get_children():
		if child is Label and child.text != "CREW":
			child.queue_free()

	for member in crew:
		var label = Label.new()
		var role = member.get("role", Phase2Types.CrewRole.COMMANDER)
		var role_name = Phase2Types.get_crew_role_name(role)
		var health = member.get("health", 100)
		var status = "OK" if health > 50 else "INJURED" if health > 0 else "DEAD"
		label.text = "%s: %s" % [role_name.substr(0, 4).to_upper(), status]
		label.add_theme_font_size_override("font_size", 10)

		# Color based on health
		if health > 75:
			label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		elif health > 50:
			label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		elif health > 0:
			label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		else:
			label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))

		crew_container.add_child(label)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_hour_advanced(day: int, hour: int) -> void:
	if store:
		var state = store.get_state()
		_update_day_hour(day, hour, state.total_days)

func _on_day_advanced(day: int) -> void:
	## Day boundary crossed - update journey indicator
	if journey_indicator:
		journey_indicator.set_current_day(day)

func _on_speed_changed(speed: int) -> void:
	var speed_names = ["Paused", "Slow", "Normal", "Fast", "ULTRA"]
	speed_label.text = "Speed: %s" % speed_names[clampi(speed, 0, 4)]

func _on_resources_changed(resources: Dictionary) -> void:
	_update_resources(resources)

func _on_crew_changed(crew: Array) -> void:
	_update_crew_display(crew)

func _on_event_triggered(event: Dictionary) -> void:
	event_title.text = event.get("title", "EVENT")
	event_description.text = event.get("description", "")

	# Clear old options
	for child in event_options.get_children():
		child.queue_free()

	# Get current state for prerequisite checking
	var state = store.get_state() if store else {}
	var crew = state.get("crew", [])

	# Add option buttons with blue option styling and task preview
	var options = event.get("options", [])
	for i in range(options.size()):
		var option = options[i]

		# Create option container (button + task preview)
		var option_container = VBoxContainer.new()
		option_container.add_theme_constant_override("separation", 2)

		var button = Button.new()
		var label = option.get("label", "Option %d" % (i + 1))
		var description = option.get("description", "")
		var is_blue = option.get("is_blue_option", false)

		# Check prerequisites
		var meets_prereqs = _check_option_prerequisites(option, state, crew)

		# Style the button
		if is_blue:
			if meets_prereqs:
				# Blue option available - highlight it
				button.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
				button.add_theme_color_override("font_hover_color", Color(0.6, 0.85, 1.0))
			else:
				# Blue option not available - grey out
				button.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
				label = label + " (unavailable)"
				button.disabled = true

		button.text = label
		if description != "":
			button.tooltip_text = description

		if meets_prereqs:
			button.pressed.connect(_on_option_selected.bind(i))
		option_container.add_child(button)

		# Add task preview if task_config exists
		var task_config = option.get("task_config")
		if task_config != null and task_config is Dictionary and not task_config.is_empty():
			var task_preview = _create_task_preview(task_config)
			option_container.add_child(task_preview)

		event_options.add_child(option_container)

	event_panel.visible = true

func _check_option_prerequisites(option: Dictionary, state: Dictionary, crew: Array) -> bool:
	## Check if the player meets the prerequisites for this option
	var requires_crew = option.get("requires_crew", "")
	var requires_resource = option.get("requires_resource", "")
	var requires_min = option.get("requires_min", 0)

	# Check crew requirement
	if requires_crew != "":
		var has_crew = false
		var role_map = {
			"commander": Phase2Types.CrewRole.COMMANDER,
			"engineer": Phase2Types.CrewRole.ENGINEER,
			"scientist": Phase2Types.CrewRole.SCIENTIST,
			"medical": Phase2Types.CrewRole.MEDICAL
		}
		var required_role = role_map.get(requires_crew.to_lower(), -1)
		for member in crew:
			if member.role == required_role and member.health > 20:
				has_crew = true
				break
		if not has_crew:
			return false

	# Check resource requirement (simplified - just check if we have any)
	if requires_resource != "" and requires_min > 0:
		# For now, assume we have resources if not specified otherwise
		# This could be expanded to check actual resource amounts
		pass

	return true

func _create_task_preview(task_config: Dictionary) -> HBoxContainer:
	## Create a compact task preview showing: hours, location, crew
	var preview = HBoxContainer.new()
	preview.add_theme_constant_override("separation", 8)

	# Container margin to indent it slightly
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	preview.add_child(margin)

	# Task info in a smaller, greyed style
	var info_container = HBoxContainer.new()
	info_container.add_theme_constant_override("separation", 6)
	margin.add_child(info_container)

	# Hours indicator
	var hours = task_config.get("hours", 0)
	if hours > 0:
		var hours_label = Label.new()
		hours_label.text = "⏱ %dh" % hours
		hours_label.add_theme_font_size_override("font_size", 10)
		hours_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		info_container.add_child(hours_label)

	# Location indicator
	var location = task_config.get("location", "")
	if location != "":
		var location_label = Label.new()
		var location_display = _get_location_display_name(location)
		location_label.text = "📍 %s" % location_display
		location_label.add_theme_font_size_override("font_size", 10)
		location_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		info_container.add_child(location_label)

	# Crew indicator
	var crew = task_config.get("crew", [])
	if crew.size() > 0:
		var crew_label = Label.new()
		var crew_names = []
		for role in crew:
			crew_names.append(_get_crew_display_name(role))
		crew_label.text = "👤 %s" % ", ".join(crew_names)
		crew_label.add_theme_font_size_override("font_size", 10)
		crew_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		info_container.add_child(crew_label)

	# EVA indicator if present
	var eva_target = task_config.get("eva_target", "")
	if eva_target != "":
		var eva_label = Label.new()
		eva_label.text = "🚀 EVA"
		eva_label.add_theme_font_size_override("font_size", 10)
		eva_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		info_container.add_child(eva_label)

	return preview

func _get_location_display_name(location: String) -> String:
	## Convert location string to display-friendly name
	match location:
		"bridge": return "Bridge"
		"engineering": return "Engineering"
		"medical": return "Medical"
		"life_support": return "Life Support"
		"quarters": return "Quarters"
		"cargo_bay": return "Cargo"
		"hydroponics": return "Hydroponics"
		"airlock": return "Airlock"
		_: return location.capitalize()

func _get_crew_display_name(role: String) -> String:
	## Convert crew role to display-friendly name
	match role:
		"commander": return "Chen"
		"engineer": return "Mitchell"
		"scientist": return "Tanaka"
		"medic": return "Okafor"
		"medical": return "Okafor"
		_: return role.capitalize()

func _on_event_resolved(choice_index: int) -> void:
	event_panel.visible = false

func _on_game_over(reason: String) -> void:
	game_over_label.text = reason
	game_over_panel.visible = true

func _on_option_selected(choice_index: int) -> void:
	if store and store.has_method("resolve_event"):
		store.resolve_event(choice_index)
	event_panel.visible = false

# ============================================================================
# PUBLIC API
# ============================================================================

func update_speed_display(speed_name: String) -> void:
	speed_label.text = "Speed: %s" % speed_name

# ============================================================================
# AUTO-PLAY TOGGLE
# ============================================================================

func _on_auto_play_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_auto_play()

func _on_auto_play_changed(_enabled: bool) -> void:
	_update_auto_play_display()

func _toggle_auto_play() -> void:
	if controller and controller.has_method("toggle_auto_play"):
		controller.toggle_auto_play()

func _update_auto_play_display() -> void:
	if not controller or not auto_play_label:
		return

	var is_on = controller.get("auto_play")
	if is_on:
		auto_play_label.text = "[A] AI: ON"
		auto_play_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		auto_play_label.text = "[A] AI: OFF"
		auto_play_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))

# ============================================================================
# CRISIS DISPLAY
# ============================================================================

func _on_crisis_count_changed(count: int) -> void:
	if not crisis_label:
		return

	crisis_label.text = "CRISES: %d" % count

	# Color based on count
	if count == 0:
		crisis_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	elif count == 1:
		crisis_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	elif count == 2:
		crisis_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		crisis_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
