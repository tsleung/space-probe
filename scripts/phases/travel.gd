extends Control

## Travel to Mars Phase UI
## Displays journey progress, crew management, and random events

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

# ============================================================================
# LOCAL STATE
# ============================================================================

var _selected_crew_id: String = ""
var _auto_travel: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_connect_signals()
	_populate_activities()
	_sync_ui()
	_init_log()

func _process(_delta):
	if _auto_travel:
		_do_auto_travel()

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)

	advance_button.pressed.connect(_on_advance_day)
	advance_week_button.pressed.connect(_on_advance_week)
	auto_travel_button.pressed.connect(_on_toggle_auto_travel)
	assign_button.pressed.connect(_on_assign_activity)
	activity_list.item_selected.connect(_on_activity_selected)

func _init_log():
	event_log.clear()
	for entry in GameStore.get_log():
		_add_log_entry(entry)

func _populate_activities():
	activity_list.clear()
	for activity in GameStore.get_available_activities():
		activity_list.add_item("%s (%dh)" % [activity.name, activity.hours])

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
	advance_button.disabled = _auto_travel
	advance_week_button.disabled = _auto_travel
	auto_travel_button.text = "Stop Auto" if _auto_travel else "Auto Travel"

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
	vbox.add_child(name_label)

	# Status
	var status_label = Label.new()
	status_label.text = CrewLogic.get_status_summary(member)
	var effectiveness = CrewLogic.calc_effectiveness(member)
	status_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	vbox.add_child(status_label)

	# Stats bar
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

	var text = "[b]Ship Status[/b]\n\n"
	text += "Overall Readiness: %.1f%%\n\n" % readiness

	text += "[b]Components:[/b]\n"
	for comp in components:
		var quality_color = "green" if comp.quality > 70 else ("yellow" if comp.quality > 40 else "red")
		text += "  %s: [color=%s]%.0f%%[/color]\n" % [comp.display_name, quality_color, comp.quality]

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
	GameStore.advance_travel_day()

func _on_advance_week():
	for i in range(7):
		GameStore.advance_travel_day()
		await get_tree().process_frame

func _on_toggle_auto_travel():
	_auto_travel = not _auto_travel
	_sync_ui()

func _do_auto_travel():
	# Called each frame during auto travel
	if GameStore.get_phase() != GameTypes.GamePhase.TRAVEL_TO_MARS:
		_auto_travel = false
		return

	GameStore.advance_travel_day()

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
