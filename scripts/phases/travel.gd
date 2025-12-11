extends Control

## Travel to Mars Phase UI
## Displays journey progress, crew management, and interactive random events

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var day_label: Label = $TopBar/DayLabel
@onready var progress_label: Label = $TopBar/ProgressLabel
@onready var distance_label: Label = $TopBar/DistanceLabel

@onready var progress_bar: ProgressBar = $MainContent/LeftPanel/ProgressSection/ProgressBar
@onready var eta_label: Label = $MainContent/LeftPanel/ProgressSection/ETALabel

@onready var crew_container: VBoxContainer = $MainContent/LeftPanel/CrewSection/CrewContainer
@onready var activity_panel: Panel = $MainContent/LeftPanel/ActivityPanel
@onready var activity_list: ItemList = $MainContent/LeftPanel/ActivityPanel/ActivityList
@onready var assign_button: Button = $MainContent/LeftPanel/ActivityPanel/AssignButton

@onready var ship_status_label: RichTextLabel = $MainContent/CenterPanel/ShipStatus
@onready var event_log: RichTextLabel = $MainContent/RightPanel/EventLog

@onready var advance_button: Button = $BottomBar/AdvanceButton
@onready var advance_week_button: Button = $BottomBar/AdvanceWeekButton
@onready var auto_travel_button: Button = $BottomBar/AutoTravelButton
@onready var speed_slider: HSlider = $BottomBar/SpeedSlider
@onready var speed_label: Label = $BottomBar/SpeedLabel

@onready var event_popup = $EventPopup

# ============================================================================
# LOCAL STATE
# ============================================================================

var _selected_crew_id: String = ""
var _auto_travel: bool = false
var _auto_travel_timer: float = 0.0
var _auto_travel_speed: float = 0.2  # seconds per day
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _event_paused: bool = false  # Pause auto-travel during events
var _pending_event: Dictionary = {}

# Track triggered events to avoid repeats
var _triggered_events: Array = []

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_rng.seed = int(Time.get_unix_time_from_system())
	_connect_signals()
	_populate_activities()
	_sync_ui()
	_init_log()

func _process(delta: float):
	if _auto_travel and not _event_paused:
		_auto_travel_timer += delta
		if _auto_travel_timer >= _auto_travel_speed:
			_auto_travel_timer = 0.0
			_do_auto_travel()

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)

	advance_button.pressed.connect(_on_advance_day)
	advance_week_button.pressed.connect(_on_advance_week)
	auto_travel_button.toggled.connect(_on_toggle_auto_travel)
	speed_slider.value_changed.connect(_on_speed_changed)
	assign_button.pressed.connect(_on_assign_activity)
	activity_list.item_selected.connect(_on_activity_selected)

	# Connect event popup signals
	event_popup.choice_made.connect(_on_event_choice_made)
	event_popup.popup_closed.connect(_on_event_popup_closed)

func _init_log():
	event_log.clear()
	for entry in GameStore.get_log():
		_add_log_entry(entry)

func _populate_activities():
	activity_list.clear()
	var supplies = GameStore.get_supplies()
	for activity in GameStore.get_available_activities():
		var label = activity.name
		if activity.hours > 0:
			label += " (%dh)" % activity.hours

		# Show resource cost
		if activity.get("requires_resource") != null:
			var resource = activity.requires_resource
			var cost = activity.get("resource_cost", 1)
			var available = int(supplies.get(resource, 0))
			if available >= cost:
				label += " [%d %s]" % [cost, resource.replace("_", " ")]
			else:
				label += " [NO %s!]" % resource.replace("_", " ").to_upper()

		activity_list.add_item(label)

# ============================================================================
# UI SYNC
# ============================================================================

func _sync_ui():
	var progress = GameStore.get_travel_progress()
	var crew = GameStore.get_crew()
	var day = GameStore.get_current_day()

	# Top bar
	day_label.text = "Mission Day: %d" % day
	progress_label.text = "Day %d of %d" % [progress.current_day, progress.total_days]
	distance_label.text = "%.1f M km traveled" % (progress.distance_traveled_km / 1_000_000.0)

	# Progress section
	progress_bar.value = progress.progress_percent
	var days_remaining = progress.total_days - progress.current_day
	eta_label.text = "ETA: %d days remaining" % days_remaining

	# Crew section
	_update_crew_display(crew)

	# Ship status
	_update_ship_status()

	# Button states
	var buttons_disabled = _auto_travel or _event_paused
	advance_button.disabled = buttons_disabled
	advance_week_button.disabled = buttons_disabled
	auto_travel_button.text = "Stop" if _auto_travel else "Auto"

func _update_crew_display(crew: Array):
	# Clear existing crew displays
	for child in crew_container.get_children():
		child.queue_free()

	for member in crew:
		var crew_panel = _create_crew_panel(member)
		crew_container.add_child(crew_panel)

func _create_crew_panel(member: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Name and role
	var name_label = Label.new()
	name_label.text = "%s - %s" % [member.display_name, CrewLogic.get_specialty_name(member.specialty)]
	if member.health <= 0:
		name_label.text += " [DECEASED]"
		name_label.modulate = Color.GRAY
	vbox.add_child(name_label)

	# Status
	var status_label = Label.new()
	status_label.text = CrewLogic.get_status_summary(member)
	var effectiveness = CrewLogic.calc_effectiveness(member)
	status_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	vbox.add_child(status_label)

	# Stats bar
	if member.health > 0:
		var stats_hbox = HBoxContainer.new()
		vbox.add_child(stats_hbox)

		_add_stat_bar(stats_hbox, "H", member.health, Color.RED)
		_add_stat_bar(stats_hbox, "M", member.morale, Color.YELLOW)
		_add_stat_bar(stats_hbox, "F", 100.0 - member.fatigue, Color.CYAN)

		# Make clickable
		var button = Button.new()
		button.text = "Select"
		button.pressed.connect(func(): _select_crew(member.id))
		vbox.add_child(button)

	return panel

func _add_stat_bar(container: HBoxContainer, label_text: String, value: float, color: Color):
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(15, 0)
	container.add_child(label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(50, 15)
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.modulate = color
	container.add_child(bar)

func _update_ship_status():
	var components = GameStore.get_components()
	var readiness = GameStore.get_readiness()
	var supplies = GameStore.get_supplies()
	var crew = GameStore.get_crew()
	var progress = GameStore.get_travel_progress()

	var text = "[b]Ship Status[/b]\n\n"
	text += "Overall Readiness: %.1f%%\n\n" % readiness

	# SUPPLIES - The core survival display
	text += "[b]SUPPLIES[/b]\n"
	var days_remaining = progress.total_days - progress.current_day

	# Calculate daily consumption for estimates
	var alive_crew = 0
	for member in crew:
		if member.health > 0:
			alive_crew += 1

	if alive_crew > 0:
		var life_support_quality = 70.0
		for comp in components:
			if comp.id == "life_support":
				life_support_quality = comp.quality
				break

		var daily = TravelLogic.calc_daily_consumption(alive_crew, life_support_quality)

		# Food
		var food_days = supplies.get("food_kg", 0.0) / maxf(daily.food_kg, 0.1)
		var food_color = "green" if food_days > days_remaining else ("yellow" if food_days > 7 else "red")
		text += "[color=%s]Food: %.0f kg (%.0f days)[/color]\n" % [food_color, supplies.get("food_kg", 0.0), food_days]

		# Water
		var water_days = supplies.get("water_kg", 0.0) / maxf(daily.water_kg, 0.1)
		var water_color = "green" if water_days > days_remaining else ("yellow" if water_days > 7 else "red")
		text += "[color=%s]Water: %.0f kg (%.0f days)[/color]\n" % [water_color, supplies.get("water_kg", 0.0), water_days]

		# Oxygen
		var oxygen_days = supplies.get("oxygen_kg", 0.0) / maxf(daily.oxygen_kg, 0.1)
		var oxygen_color = "green" if oxygen_days > days_remaining else ("yellow" if oxygen_days > 3 else "red")
		text += "[color=%s]Oxygen: %.0f kg (%.0f days)[/color]\n" % [oxygen_color, supplies.get("oxygen_kg", 0.0), oxygen_days]
	else:
		text += "[color=red]NO LIVING CREW[/color]\n"

	text += "\n[b]Other Supplies:[/b]\n"
	text += "Spare Parts: %d\n" % supplies.get("spare_parts", 0)
	text += "Medical Kits: %d\n" % supplies.get("medical_kits", 0)

	text += "\n[b]Components:[/b]\n"
	for comp in components:
		var quality_color = "green" if comp.quality > 70 else ("yellow" if comp.quality > 40 else "red")
		text += "  %s: [color=%s]%.0f%%[/color]\n" % [comp.display_name, quality_color, comp.quality]

	# Show crew deaths if any
	var deaths = GameStore.get_crew_deaths()
	if deaths > 0:
		text += "\n[color=red][b]CREW LOSSES: %d[/b][/color]\n" % deaths

	ship_status_label.text = text

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_log_entry(entry: Dictionary):
	_add_log_entry(entry)

func _on_phase_changed(new_phase: GameTypes.GamePhase):
	_auto_travel = false
	if new_phase == GameTypes.GamePhase.MARS_BASE:
		get_tree().change_scene_to_file("res://scenes/phases/mars_base.tscn")
	elif new_phase == GameTypes.GamePhase.GAME_OVER:
		get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")

func _on_advance_day():
	_advance_one_day()

func _on_advance_week():
	for i in range(7):
		_advance_one_day()
		await get_tree().process_frame
		if _event_paused:
			break

func _on_toggle_auto_travel(toggled: bool):
	_auto_travel = toggled
	_auto_travel_timer = 0.0
	_sync_ui()

func _on_speed_changed(value: float):
	_auto_travel_speed = 1.0 / value
	speed_label.text = "%dx" % int(value)

func _do_auto_travel():
	# Called each frame during auto travel
	if GameStore.get_phase() != GameTypes.GamePhase.TRAVEL_TO_MARS:
		_auto_travel = false
		return

	if _event_paused:
		return

	_advance_one_day()

func _advance_one_day():
	# Advance the travel day (consumes supplies, etc.)
	GameStore.advance_travel_day()

	# Check for interactive event
	_check_for_interactive_event()

func _check_for_interactive_event():
	var progress = GameStore.get_travel_progress()
	var day = progress.current_day

	# Check if we should trigger an event
	if InteractiveEvents.should_event_trigger(GameTypes.GamePhase.TRAVEL_TO_MARS, day, _rng.randf()):
		var event = InteractiveEvents.select_event(GameTypes.GamePhase.TRAVEL_TO_MARS, _rng.randf())

		# Don't repeat same event type too often
		if not event.is_empty() and not event.id in _triggered_events:
			_show_interactive_event(event)
			_triggered_events.append(event.id)

			# Clear old triggered events after a while
			if _triggered_events.size() > 5:
				_triggered_events.pop_front()

func _show_interactive_event(event: Dictionary):
	_event_paused = true
	_pending_event = event
	event_popup.show_event(event)
	GameStore.add_log("[color=yellow]EVENT: %s[/color]" % event.title, "event")

func _on_event_choice_made(event: Dictionary, choice_id: String):
	# Apply the choice effects
	var new_state = InteractiveEvents.apply_choice_effects(GameStore.get_state(), event, choice_id)

	# Find the choice for logging
	var choice_text = ""
	for choice in event.choices:
		if choice.id == choice_id:
			choice_text = choice.consequence_text
			break

	# Log the choice
	GameStore.add_log("You chose: %s" % choice_text, "info")

	# Apply state changes through GameStore
	_apply_event_state_changes(new_state)

func _on_event_popup_closed():
	_event_paused = false
	_pending_event = {}
	_sync_ui()

func _apply_event_state_changes(new_state: Dictionary):
	# Apply crew changes
	if new_state.has("crew"):
		for i in range(new_state.crew.size()):
			var crew_member = new_state.crew[i]
			GameStore.dispatch(GameReducer.action_update_crew(crew_member.id, crew_member))

	# Apply supply changes
	if new_state.has("supplies"):
		GameStore.set_supplies(new_state.supplies)

	# Apply component changes
	if new_state.has("ship_components"):
		for comp in new_state.ship_components:
			GameStore.dispatch(GameReducer.action_update_component(comp.hex_position, comp))

func _select_crew(crew_id: String):
	_selected_crew_id = crew_id
	activity_panel.visible = true

func _on_activity_selected(_index: int):
	pass  # Just enables assign button

func _on_assign_activity():
	if _selected_crew_id.is_empty():
		return

	var selected = activity_list.get_selected_items()
	if selected.is_empty():
		return

	var activities = GameStore.get_available_activities()
	var activity = activities[selected[0]]
	GameStore.assign_crew_activity(_selected_crew_id, activity.id)

	activity_panel.visible = false
	_selected_crew_id = ""

func _add_log_entry(entry: Dictionary):
	var color = "white"
	match entry.event_type:
		"error": color = "red"
		"success": color = "green"
		"event": color = "yellow"
		"info": color = "gray"

	event_log.append_text("[color=%s][Day %d] %s[/color]\n" % [color, entry.day, entry.message])
