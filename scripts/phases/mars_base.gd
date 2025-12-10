extends Control

## Mars Base Phase UI
## Surface operations, experiments, sample collection

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var sol_label: Label = $TopBar/SolLabel
@onready var mission_day_label: Label = $TopBar/MissionDayLabel
@onready var samples_label: Label = $TopBar/SamplesLabel

@onready var crew_container: VBoxContainer = $MainContent/LeftPanel/CrewSection/CrewContainer
@onready var activity_panel: Panel = $MainContent/LeftPanel/ActivityPanel
@onready var activity_list: ItemList = $MainContent/LeftPanel/ActivityPanel/ActivityList
@onready var assign_button: Button = $MainContent/LeftPanel/ActivityPanel/AssignButton

@onready var experiment_list: ItemList = $MainContent/CenterPanel/ExperimentList
@onready var experiment_info: RichTextLabel = $MainContent/CenterPanel/ExperimentInfo
@onready var run_experiment_button: Button = $MainContent/CenterPanel/RunExperimentButton
@onready var crew_select: OptionButton = $MainContent/CenterPanel/CrewSelect

@onready var mission_status: RichTextLabel = $MainContent/RightPanel/MissionStatus
@onready var event_log: RichTextLabel = $MainContent/RightPanel/EventLog

@onready var advance_button: Button = $BottomBar/AdvanceButton
@onready var return_button: Button = $BottomBar/ReturnButton

# ============================================================================
# LOCAL STATE
# ============================================================================

var _selected_crew_id: String = ""
var _selected_experiment: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_connect_signals()
	_populate_experiments()
	_populate_activities()
	_sync_ui()
	_init_log()

	# Start Mars operations if not already
	if GameStore.get_mars_sol() == 0:
		GameStore.start_mars_operations()

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)

	advance_button.pressed.connect(_on_advance_sol)
	return_button.pressed.connect(_on_return_to_earth)
	experiment_list.item_selected.connect(_on_experiment_selected)
	run_experiment_button.pressed.connect(_on_run_experiment)
	assign_button.pressed.connect(_on_assign_activity)
	activity_list.item_selected.connect(_on_activity_selected)

func _init_log():
	event_log.clear()
	var log_entries = GameStore.get_log()
	# Show last 20 entries
	var start = maxi(0, log_entries.size() - 20)
	for i in range(start, log_entries.size()):
		_add_log_entry(log_entries[i])

func _populate_experiments():
	experiment_list.clear()
	var completed = GameStore.get_experiments_completed()
	for exp in MarsLogic.get_all_experiments():
		var status = " [DONE]" if exp.id in completed else ""
		experiment_list.add_item(exp.name + status)

func _populate_activities():
	activity_list.clear()
	for activity in MarsLogic.get_mars_activities():
		activity_list.add_item("%s (%dh)" % [activity.name, activity.hours])

# ============================================================================
# UI SYNC
# ============================================================================

func _sync_ui():
	var sol = GameStore.get_mars_sol()
	var day = GameStore.get_current_day()
	var crew = GameStore.get_crew()
	var samples = GameStore.get_samples_collected()
	var mission_check = MarsLogic.check_mission_complete(GameStore.get_state())

	# Top bar
	sol_label.text = "Sol: %d" % sol
	mission_day_label.text = "Mission Day: %d" % day

	var total_samples = samples.get("soil", 0) + samples.get("ice", 0) + samples.get("atmosphere", 0)
	samples_label.text = "Samples: %d" % total_samples

	# Crew section
	_update_crew_display(crew)
	_update_crew_select(crew)

	# Mission status
	_update_mission_status(mission_check, samples)

	# Buttons
	return_button.disabled = not mission_check.can_return
	return_button.text = "Return to Earth" if mission_check.can_return else "Complete More Objectives"

	# Refresh experiment list
	_populate_experiments()

func _update_crew_display(crew: Array):
	for child in crew_container.get_children():
		child.queue_free()

	for member in crew:
		var panel = _create_crew_panel(member)
		crew_container.add_child(panel)

func _create_crew_panel(member: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "%s - %s" % [member.display_name, CrewLogic.get_specialty_name(member.specialty)]
	vbox.add_child(name_label)

	var status_label = Label.new()
	status_label.text = CrewLogic.get_status_summary(member)
	var effectiveness = CrewLogic.calc_effectiveness(member)
	status_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	vbox.add_child(status_label)

	var stats_hbox = HBoxContainer.new()
	vbox.add_child(stats_hbox)
	_add_stat_bar(stats_hbox, "H", member.health, Color.RED)
	_add_stat_bar(stats_hbox, "M", member.morale, Color.YELLOW)
	_add_stat_bar(stats_hbox, "F", 100.0 - member.fatigue, Color.CYAN)

	var button = Button.new()
	button.text = "Assign"
	button.pressed.connect(func(): _select_crew(member.id))
	vbox.add_child(button)

	return panel

func _add_stat_bar(container: HBoxContainer, label_text: String, value: float, color: Color):
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(15, 0)
	container.add_child(label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(40, 12)
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.modulate = color
	container.add_child(bar)

func _update_crew_select(crew: Array):
	crew_select.clear()
	for member in crew:
		var effectiveness = CrewLogic.calc_effectiveness(member)
		var status = " (%.0f%%)" % (effectiveness * 100)
		crew_select.add_item(member.display_name + status)

func _update_mission_status(mission_check: Dictionary, samples: Dictionary):
	var text = "[b]Mission Objectives[/b]\n\n"

	text += "[b]Experiments:[/b] %d/%d required\n" % [mission_check.experiments_done, mission_check.experiments_required]
	text += "[b]Samples:[/b] %d/%d target\n\n" % [mission_check.samples_collected, mission_check.samples_target]

	text += "[b]Sample Breakdown:[/b]\n"
	text += "  Soil: %d\n" % samples.get("soil", 0)
	text += "  Ice: %d\n" % samples.get("ice", 0)
	text += "  Atmosphere: %d\n\n" % samples.get("atmosphere", 0)

	if mission_check.mission_success:
		text += "[color=green][b]MISSION SUCCESS![/b][/color]\n"
		text += "All primary objectives complete.\n"
	elif mission_check.can_return:
		text += "[color=yellow]Minimum objectives met.[/color]\n"
		text += "Can return, but more science possible.\n"
	else:
		text += "[color=red]Objectives incomplete.[/color]\n"
		text += "Continue experiments before returning.\n"

	mission_status.text = text

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_log_entry(entry: Dictionary):
	_add_log_entry(entry)

func _on_phase_changed(new_phase: GameTypes.GamePhase):
	if new_phase == GameTypes.GamePhase.TRAVEL_TO_EARTH:
		get_tree().change_scene_to_file("res://scenes/phases/return_journey.tscn")
	elif new_phase == GameTypes.GamePhase.GAME_OVER:
		get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")

func _on_advance_sol():
	# Advance one Martian sol (slightly longer than Earth day)
	GameStore.advance_day(1)
	# TODO: Add Mars-specific daily events

func _on_return_to_earth():
	var mission_check = MarsLogic.check_mission_complete(GameStore.get_state())
	if mission_check.can_return:
		GameStore.add_log("Initiating Mars departure sequence...", "success")
		GameStore.change_phase(GameTypes.GamePhase.TRAVEL_TO_EARTH)

func _on_experiment_selected(index: int):
	var experiments = MarsLogic.get_all_experiments()
	_selected_experiment = experiments[index]
	_update_experiment_info()

func _update_experiment_info():
	if _selected_experiment.is_empty():
		experiment_info.text = "Select an experiment"
		run_experiment_button.disabled = true
		return

	var exp = _selected_experiment
	var completed = GameStore.get_experiments_completed()
	var is_done = exp.id in completed

	var text = "[b]%s[/b]\n\n" % exp.name
	text += "%s\n\n" % exp.description
	text += "[b]Duration:[/b] %d hours\n" % exp.duration_hours
	text += "[b]Difficulty:[/b] %.0f%%\n" % (exp.difficulty * 100)
	text += "[b]Required Skill:[/b] %s\n" % exp.required_skill.replace("skill_", "").capitalize()

	if exp.sample_type:
		text += "[b]Samples:[/b] %d %s\n" % [exp.samples_required, exp.sample_type]

	if is_done:
		text += "\n[color=green]COMPLETED[/color]"

	experiment_info.text = text
	run_experiment_button.disabled = is_done or crew_select.selected < 0

func _on_run_experiment():
	if _selected_experiment.is_empty():
		return

	var crew = GameStore.get_crew()
	var selected_idx = crew_select.selected
	if selected_idx < 0 or selected_idx >= crew.size():
		return

	var crew_member = crew[selected_idx]
	GameStore.conduct_experiment(_selected_experiment.id, crew_member.id)

func _select_crew(crew_id: String):
	_selected_crew_id = crew_id
	activity_panel.visible = true

func _on_activity_selected(_index: int):
	pass

func _on_assign_activity():
	if _selected_crew_id.is_empty():
		return

	var selected = activity_list.get_selected_items()
	if selected.is_empty():
		return

	var activities = MarsLogic.get_mars_activities()
	var activity = activities[selected[0]]

	# Apply activity through store
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
