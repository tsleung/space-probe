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
@onready var advance_week_button: Button = $BottomBar/AdvanceWeekButton
@onready var auto_button: Button = $BottomBar/AutoButton
@onready var speed_slider: HSlider = $BottomBar/SpeedSlider
@onready var speed_label: Label = $BottomBar/SpeedLabel
@onready var return_button: Button = $BottomBar/ReturnButton

# Departure checklist panel
@onready var departure_panel: Panel = $DeparturePanel
@onready var departure_checklist: RichTextLabel = $DeparturePanel/VBox/ChecklistText
@onready var confirm_departure_button: Button = $DeparturePanel/VBox/ConfirmButton
@onready var cancel_departure_button: Button = $DeparturePanel/VBox/CancelButton

# Event popup
@onready var event_popup = $EventPopup

# ============================================================================
# LOCAL STATE
# ============================================================================

var _selected_crew_id: String = ""
var _selected_experiment: Dictionary = {}
var _auto_advance: bool = false
var _auto_advance_timer: float = 0.0
var _auto_advance_speed: float = 0.2
var _departure_panel_open: bool = false
var _event_paused: bool = false
var _pending_event: Dictionary = {}
var _triggered_events: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_rng.seed = int(Time.get_unix_time_from_system())
	_connect_signals()
	_populate_experiments()
	_populate_activities()
	_sync_ui()
	_init_log()

	# Start Mars operations if not already
	if GameStore.get_mars_sol() == 0:
		GameStore.start_mars_operations()

	# Hide departure panel initially
	if departure_panel:
		departure_panel.visible = false

func _process(delta: float):
	if _auto_advance and not _event_paused:
		_auto_advance_timer += delta
		if _auto_advance_timer >= _auto_advance_speed:
			_auto_advance_timer = 0.0
			_on_advance_sol()

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)

	advance_button.pressed.connect(_on_advance_sol)
	advance_week_button.pressed.connect(_on_advance_week)
	auto_button.toggled.connect(_on_auto_toggled)
	speed_slider.value_changed.connect(_on_speed_changed)
	return_button.pressed.connect(_on_return_to_earth)
	experiment_list.item_selected.connect(_on_experiment_selected)
	run_experiment_button.pressed.connect(_on_run_experiment)
	assign_button.pressed.connect(_on_assign_activity)
	activity_list.item_selected.connect(_on_activity_selected)

	# Connect departure panel buttons if they exist
	if confirm_departure_button:
		confirm_departure_button.pressed.connect(_on_confirm_departure)
	if cancel_departure_button:
		cancel_departure_button.pressed.connect(_on_cancel_departure)

	# Connect event popup signals
	if event_popup:
		event_popup.choice_made.connect(_on_event_choice_made)
		event_popup.popup_closed.connect(_on_event_popup_closed)

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

func _do_sample_collection(activity: Dictionary):
	# Sample collection activity gives samples
	if activity.id == "sample_collection":
		var sample_types = ["soil", "ice", "atmosphere"]
		var rng = RandomNumberGenerator.new()
		rng.seed = int(Time.get_unix_time_from_system())
		var sample_type = sample_types[rng.randi() % sample_types.size()]
		var amount = 1 + rng.randi() % 3  # 1-3 samples
		GameStore.collect_samples(sample_type, amount)

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
	# Advance one Martian sol
	GameStore.advance_day(1)
	GameStore.advance_mars_sol()
	# Check for Mars events
	_check_mars_events()

func _on_advance_week():
	for i in range(7):
		_on_advance_sol()

func _on_auto_toggled(toggled: bool):
	_auto_advance = toggled
	_auto_advance_timer = 0.0
	_sync_auto_ui()

func _on_speed_changed(value: float):
	_auto_advance_speed = 1.0 / value
	speed_label.text = "%dx" % int(value)

func _sync_auto_ui():
	advance_button.disabled = _auto_advance
	advance_week_button.disabled = _auto_advance
	auto_button.text = "Stop" if _auto_advance else "Auto"

func _check_mars_events():
	var state = GameStore.get_state()
	var sol = state.get("mars_sol", 1)

	# Check for interactive event (Oregon Trail style)
	if InteractiveEvents.should_event_trigger(GameTypes.GamePhase.MARS_BASE, sol, _rng.randf()):
		var event = InteractiveEvents.select_event(GameTypes.GamePhase.MARS_BASE, _rng.randf())

		# Don't repeat same event type too often
		if not event.is_empty() and not event.id in _triggered_events:
			_show_interactive_event(event)
			_triggered_events.append(event.id)

			# Clear old triggered events after a while
			if _triggered_events.size() > 5:
				_triggered_events.pop_front()
			return  # Don't also check for MarsLogic events

	# Fallback to MarsLogic events (non-interactive)
	var event_result = MarsLogic.check_daily_event(state, sol, _rng.randf(), _rng.randf(), _rng.randf())
	if event_result.triggered and event_result.event:
		GameStore.add_log(event_result.event.description, "event")

func _show_interactive_event(event: Dictionary):
	_event_paused = true
	_pending_event = event
	if event_popup:
		event_popup.show_event(event)
	GameStore.add_log("[color=yellow]EVENT: %s[/color]" % event.title, "event")

func _on_event_choice_made(event: Dictionary, choice_id: String):
	# Apply the choice effects using InteractiveEvents pure function
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

	# Apply samples changes
	if new_state.has("samples_collected"):
		var samples = new_state.samples_collected
		for sample_type in samples.keys():
			var current = GameStore.get_samples_collected().get(sample_type, 0)
			var diff = samples[sample_type] - current
			if diff > 0:
				GameStore.collect_samples(sample_type, diff)

	# Apply science points
	if new_state.has("science_points"):
		GameStore.add_log("Earned %d science points!" % new_state.get("science_points", 0), "success")

func _on_return_to_earth():
	# Show departure checklist panel
	_show_departure_panel()

func _show_departure_panel():
	if not departure_panel:
		# If no panel exists, just do the transition directly
		_do_departure()
		return

	_departure_panel_open = true
	departure_panel.visible = true

	# Build checklist
	var state = GameStore.get_state()
	var mission_check = MarsLogic.check_mission_complete(state)
	var samples = GameStore.get_samples_collected()
	var crew = GameStore.get_crew()
	var components = GameStore.get_components()

	var text = "[center][b]DEPARTURE CHECKLIST[/b][/center]\n\n"

	# MAV Status
	var has_mav = state.get("cargo_manifest", {}).get("mav", false)
	var mav_color = "green" if has_mav else "red"
	text += "[color=%s]%s MAV (Mars Ascent Vehicle)[/color]\n" % [mav_color, "[X]" if has_mav else "[ ]"]

	# Crew alive check
	var alive_count = 0
	for member in crew:
		if member.health > 0:
			alive_count += 1
	var crew_color = "green" if alive_count > 0 else "red"
	text += "[color=%s][X] Crew for return: %d alive[/color]\n" % [crew_color, alive_count]

	# Experiments check
	var exp_done = mission_check.experiments_done >= 2
	var exp_color = "green" if exp_done else "yellow"
	text += "[color=%s]%s Minimum experiments: %d/2[/color]\n" % [exp_color, "[X]" if exp_done else "[ ]", mission_check.experiments_done]

	# Samples check
	var total_samples = samples.get("soil", 0) + samples.get("ice", 0) + samples.get("atmosphere", 0)
	var samples_ok = total_samples >= 10
	var samples_color = "green" if samples_ok else "yellow"
	text += "[color=%s]%s Sample collection: %d/10[/color]\n" % [samples_color, "[X]" if samples_ok else "[ ]", total_samples]

	# Ship systems check
	var critical_systems_ok = true
	var heat_shield_quality = 50.0
	var nav_quality = 50.0

	for comp in components:
		if comp.id == "heat_shield":
			heat_shield_quality = comp.quality
		if comp.id == "navigation" or comp.id == "computer":
			nav_quality = comp.quality

	var heat_ok = heat_shield_quality >= 40.0
	var heat_color = "green" if heat_ok else "red"
	text += "[color=%s]%s Heat shield integrity: %.0f%%[/color]\n" % [heat_color, "[X]" if heat_ok else "[!]", heat_shield_quality]

	var nav_ok = nav_quality >= 40.0
	var nav_color = "green" if nav_ok else "yellow"
	text += "[color=%s]%s Navigation systems: %.0f%%[/color]\n" % [nav_color, "[X]" if nav_ok else "[!]", nav_quality]

	text += "\n"

	# Warning if systems are degraded
	if not heat_ok:
		text += "[color=red]WARNING: Heat shield is critically degraded!\nReentry survival is at risk![/color]\n\n"
	elif heat_shield_quality < 70.0:
		text += "[color=yellow]CAUTION: Heat shield shows wear.\nReentry may be turbulent.[/color]\n\n"

	# Final check
	if mission_check.can_return:
		text += "[color=green]Ready for departure.[/color]\n"
		text += "Return journey: ~%d days" % int(state.get("travel_total_days", 180) * 1.1)
		confirm_departure_button.disabled = false
	else:
		text += "[color=red]Cannot depart yet.[/color]\n"
		text += "Complete more objectives."
		confirm_departure_button.disabled = true

	departure_checklist.text = text

func _on_confirm_departure():
	_departure_panel_open = false
	if departure_panel:
		departure_panel.visible = false
	_do_departure()

func _on_cancel_departure():
	_departure_panel_open = false
	if departure_panel:
		departure_panel.visible = false

func _do_departure():
	var mission_check = MarsLogic.check_mission_complete(GameStore.get_state())
	if mission_check.can_return:
		GameStore.add_log("Initiating Mars departure sequence...", "success")
		GameStore.add_log("MAV lifting off from Martian surface!", "event")
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

	# Check if experiment will succeed (for sample collection)
	var old_completed = GameStore.get_experiments_completed().duplicate()

	GameStore.conduct_experiment(_selected_experiment.id, crew_member.id)

	# If experiment was completed, collect its samples
	var new_completed = GameStore.get_experiments_completed()
	if new_completed.size() > old_completed.size():
		var exp = _selected_experiment
		if exp.sample_type and exp.samples_required > 0:
			GameStore.collect_samples(exp.sample_type, exp.samples_required)

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

	# If it's sample collection, actually collect samples
	_do_sample_collection(activity)

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
