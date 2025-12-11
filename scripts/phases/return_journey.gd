extends Control

## Return Journey Phase UI
## The desperate final stretch - worn equipment, limited supplies, Earth calling

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var day_label: Label = $TopBar/DayLabel
@onready var progress_label: Label = $TopBar/ProgressLabel
@onready var progress_bar: ProgressBar = $MainContent/LeftPanel/ProgressSection/ProgressBar
@onready var eta_label: Label = $MainContent/LeftPanel/ProgressSection/ETALabel
@onready var crew_container: VBoxContainer = $MainContent/LeftPanel/CrewSection/CrewContainer
@onready var ship_status: RichTextLabel = $MainContent/CenterPanel/ShipStatus
@onready var event_log: RichTextLabel = $MainContent/RightPanel/EventLog
@onready var advance_button: Button = $BottomBar/AdvanceButton
@onready var advance_week_button: Button = $BottomBar/AdvanceWeekButton
@onready var auto_button: Button = $BottomBar/AutoButton
@onready var speed_slider: HSlider = $BottomBar/SpeedSlider
@onready var speed_label: Label = $BottomBar/SpeedLabel

# Reentry sequence panel
@onready var reentry_panel: Panel = $ReentrySequence
@onready var reentry_title: Label = $ReentrySequence/VBox/TitleLabel
@onready var reentry_status: RichTextLabel = $ReentrySequence/VBox/StatusText
@onready var reentry_progress: ProgressBar = $ReentrySequence/VBox/ProgressBar
@onready var reentry_button: Button = $ReentrySequence/VBox/ContinueButton

# Event popup
@onready var event_popup = $EventPopup

# ============================================================================
# LOCAL STATE
# ============================================================================

var _auto_travel: bool = false
var _auto_travel_timer: float = 0.0
var _auto_travel_speed: float = 0.2
var _return_travel_day: int = 0
var _return_travel_total: int = 180
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _event_paused: bool = false
var _pending_event: Dictionary = {}
var _triggered_events: Array = []

# Reentry sequence state
enum ReentryStage { NONE, APPROACH, HEAT_SHIELD, PARACHUTE, LANDING, COMPLETE, FAILED }
var _reentry_stage: ReentryStage = ReentryStage.NONE
var _reentry_timer: float = 0.0
var _reentry_results: Dictionary = {}

func _ready():
	_rng.seed = int(Time.get_unix_time_from_system())
	_connect_signals()
	_init_return_journey()
	_init_log()
	_sync_ui()

	# Hide reentry panel initially
	if reentry_panel:
		reentry_panel.visible = false

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)
	advance_button.pressed.connect(_on_advance_day)
	advance_week_button.pressed.connect(_on_advance_week)
	auto_button.toggled.connect(_on_toggle_auto)
	speed_slider.value_changed.connect(_on_speed_changed)

	# Connect reentry button if it exists
	if reentry_button:
		reentry_button.pressed.connect(_on_reentry_continue)

	# Connect event popup signals
	if event_popup:
		event_popup.choice_made.connect(_on_event_choice_made)
		event_popup.popup_closed.connect(_on_event_popup_closed)

func _init_log():
	event_log.clear()
	var log_entries = GameStore.get_log()
	var start = maxi(0, log_entries.size() - 20)
	for i in range(start, log_entries.size()):
		_add_log_entry(log_entries[i])

func _init_return_journey():
	# Return journey is often 10% longer due to orbital mechanics
	var state = GameStore.get_state()
	_return_travel_total = int(state.get("travel_total_days", 180) * 1.1)
	_return_travel_day = 0

	# Calculate remaining supplies for return journey
	var crew_count = 0
	for member in state.get("crew", []):
		if member.health > 0:
			crew_count += 1

	# Resupply for return journey - ISRU produced what it could, but it's tight
	var recommended = TravelLogic.calc_recommended_supplies(crew_count, _return_travel_total, 1.1)

	# Return supplies are TIGHT - Mars ISRU can only produce so much
	# This creates the "desperate survivor" tension from the design doc
	GameStore.set_supplies({
		"food_kg": recommended.food_kg * 0.85,  # Only 85% - real tension!
		"water_kg": recommended.water_kg * 0.95,
		"oxygen_kg": recommended.oxygen_kg,  # Oxygen is fine (MOXIE)
		"spare_parts": maxi(0, state.get("supplies", {}).get("spare_parts", 2) - 1),
		"medical_kits": maxi(0, state.get("supplies", {}).get("medical_kits", 1))
	})

	var supplies = GameStore.get_supplies()
	GameStore.add_log("Beginning return journey to Earth. Estimated time: %d days." % _return_travel_total, "success")
	GameStore.add_log("Return supplies: %.0f kg food, %.0f kg water, %.0f kg oxygen" % [
		supplies.food_kg, supplies.water_kg, supplies.oxygen_kg
	], "info")
	GameStore.add_log("Ship systems showing wear after Mars operations. Stay vigilant.", "event")

func _process(delta: float):
	# Handle reentry sequence animation
	if _reentry_stage != ReentryStage.NONE and _reentry_stage != ReentryStage.COMPLETE and _reentry_stage != ReentryStage.FAILED:
		_reentry_timer += delta
		if _reentry_timer >= 2.0:  # 2 seconds per stage
			_reentry_timer = 0.0
			_advance_reentry_stage()
		else:
			# Update progress bar during animation
			if reentry_progress:
				var stage_progress = (_reentry_timer / 2.0) * 100.0
				reentry_progress.value = stage_progress
		return

	if _auto_travel:
		_auto_travel_timer += delta
		if _auto_travel_timer >= _auto_travel_speed:
			_auto_travel_timer = 0.0
			_do_auto_travel()

func _sync_ui():
	var day = GameStore.get_current_day()
	var crew = GameStore.get_crew()

	day_label.text = "Mission Day: %d" % day
	progress_label.text = "Return Day %d of %d" % [_return_travel_day, _return_travel_total]

	var progress_pct = (float(_return_travel_day) / float(_return_travel_total)) * 100.0
	progress_bar.value = progress_pct
	eta_label.text = "ETA Earth: %d days" % (_return_travel_total - _return_travel_day)

	_update_crew_display(crew)
	_update_ship_status()

	advance_button.disabled = _auto_travel
	advance_week_button.disabled = _auto_travel
	auto_button.text = "Stop" if _auto_travel else "Auto"

func _update_crew_display(crew: Array):
	for child in crew_container.get_children():
		child.queue_free()

	for member in crew:
		var panel = _create_crew_panel(member)
		crew_container.add_child(panel)

func _create_crew_panel(member: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_label = Label.new()
	var status_icon = "" if member.health > 0 else " [DECEASED]"
	name_label.text = member.display_name + status_icon
	if member.health <= 0:
		name_label.modulate = Color.GRAY
	vbox.add_child(name_label)

	var status_label = Label.new()
	status_label.text = CrewLogic.get_status_summary(member)
	var effectiveness = CrewLogic.calc_effectiveness(member)
	status_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	vbox.add_child(status_label)

	# Health bar
	if member.health > 0:
		var stats_hbox = HBoxContainer.new()
		vbox.add_child(stats_hbox)
		_add_stat_bar(stats_hbox, "H", member.health, Color.RED)
		_add_stat_bar(stats_hbox, "M", member.morale, Color.YELLOW)

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
	var score = MarsLogic.calc_mission_score(GameStore.get_state())

	var text = "[b]RETURN TO EARTH[/b]\n\n"

	# Supplies status (critical info first)
	text += "[b]SUPPLIES[/b]\n"
	var days_remaining = _return_travel_total - _return_travel_day

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

		var food_days = supplies.get("food_kg", 0.0) / maxf(daily.food_kg, 0.1)
		var food_color = "green" if food_days > days_remaining else ("yellow" if food_days > 7 else "red")
		text += "[color=%s]Food: %.0f kg (%.0f days)[/color]\n" % [food_color, supplies.get("food_kg", 0.0), food_days]

		var water_days = supplies.get("water_kg", 0.0) / maxf(daily.water_kg, 0.1)
		var water_color = "green" if water_days > days_remaining else ("yellow" if water_days > 7 else "red")
		text += "[color=%s]Water: %.0f kg (%.0f days)[/color]\n" % [water_color, supplies.get("water_kg", 0.0), water_days]

		var oxygen_days = supplies.get("oxygen_kg", 0.0) / maxf(daily.oxygen_kg, 0.1)
		var oxygen_color = "green" if oxygen_days > days_remaining else ("yellow" if oxygen_days > 3 else "red")
		text += "[color=%s]Oxygen: %.0f kg (%.0f days)[/color]\n" % [oxygen_color, supplies.get("oxygen_kg", 0.0), oxygen_days]
	else:
		text += "[color=red]NO LIVING CREW[/color]\n"

	text += "\nShip Readiness: %.1f%%\n" % readiness

	text += "\n[b]MISSION SCORE[/b]\n"
	text += "Grade: %s\n" % score.grade
	text += "Crew Alive: %d/4\n" % score.crew_alive
	text += "Experiments: %d\n" % score.experiments
	text += "Samples: %d\n" % score.samples

	# Show crew deaths
	var deaths = GameStore.get_crew_deaths()
	if deaths > 0:
		text += "\n[color=red]CREW LOSSES: %d[/color]\n" % deaths

	ship_status.text = text

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_log_entry(entry: Dictionary):
	_add_log_entry(entry)

func _add_log_entry(entry: Dictionary):
	var color = "white"
	match entry.event_type:
		"error": color = "red"
		"success": color = "green"
		"event": color = "yellow"
		"info": color = "gray"
	event_log.append_text("[color=%s][Day %d] %s[/color]\n" % [color, entry.day, entry.message])

func _on_phase_changed(new_phase: GameTypes.GamePhase):
	_auto_travel = false
	if new_phase == GameTypes.GamePhase.GAME_OVER:
		get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")

func _on_advance_day():
	_advance_return_day()

func _on_advance_week():
	for i in range(7):
		_advance_return_day()
		await get_tree().process_frame
		if _return_travel_day >= _return_travel_total:
			break
		# Check for game over
		if GameStore.get_phase() == GameTypes.GamePhase.GAME_OVER:
			break

func _on_toggle_auto(toggled: bool):
	_auto_travel = toggled
	_auto_travel_timer = 0.0
	_sync_ui()

func _on_speed_changed(value: float):
	_auto_travel_speed = 1.0 / value
	speed_label.text = "%dx" % int(value)

func _do_auto_travel():
	if _return_travel_day >= _return_travel_total:
		_auto_travel = false
		return
	if GameStore.get_phase() == GameTypes.GamePhase.GAME_OVER:
		_auto_travel = false
		return
	if _event_paused:
		return
	_advance_return_day()

func _advance_return_day():
	_return_travel_day += 1

	# Use the same travel day advancement which consumes supplies and triggers events
	GameStore.advance_travel_day()

	# Check for crew status after advancement
	var crew = GameStore.get_crew()
	var alive_count = 0
	for member in crew:
		if member.health > 0:
			alive_count += 1

	# Check for total crew loss
	if alive_count == 0:
		GameStore.add_log("All crew lost during return journey...", "error")
		GameStore.change_phase(GameTypes.GamePhase.GAME_OVER)
		return

	# Check for interactive events
	_check_for_interactive_event()

	# Check for arrival - start reentry sequence
	if _return_travel_day >= _return_travel_total:
		_start_reentry_sequence()

func _check_for_interactive_event():
	# Check if we should trigger an interactive event
	if InteractiveEvents.should_event_trigger(GameTypes.GamePhase.TRAVEL_TO_EARTH, _return_travel_day, _rng.randf()):
		var event = InteractiveEvents.select_event(GameTypes.GamePhase.TRAVEL_TO_EARTH, _rng.randf())

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

	# Apply science points
	if new_state.has("science_points"):
		GameStore.add_log("Earned %d science points!" % new_state.get("science_points", 0), "success")

# ============================================================================
# REENTRY SEQUENCE
# ============================================================================

func _start_reentry_sequence():
	_auto_travel = false
	_reentry_stage = ReentryStage.APPROACH
	_reentry_timer = 0.0
	_reentry_results = {
		"heat_shield_success": false,
		"parachute_success": false,
		"landing_success": false,
		"crew_survived": []
	}

	# Show reentry panel
	if reentry_panel:
		reentry_panel.visible = true

	# Disable other controls
	advance_button.disabled = true
	advance_week_button.disabled = true
	auto_button.disabled = true

	GameStore.add_log("APPROACHING EARTH ORBIT - Beginning reentry sequence!", "event")
	_update_reentry_display()

func _advance_reentry_stage():
	match _reentry_stage:
		ReentryStage.APPROACH:
			_do_approach_check()
		ReentryStage.HEAT_SHIELD:
			_do_heat_shield_check()
		ReentryStage.PARACHUTE:
			_do_parachute_check()
		ReentryStage.LANDING:
			_do_landing_check()

func _do_approach_check():
	# Approach is always successful if we got here
	GameStore.add_log("Earth orbit insertion successful. Preparing for atmospheric entry.", "success")
	_reentry_stage = ReentryStage.HEAT_SHIELD
	_update_reentry_display()

func _do_heat_shield_check():
	# Get heat shield quality from components
	var components = GameStore.get_components()
	var heat_shield_quality = 50.0  # Default if not found

	for comp in components:
		if comp.id == "heat_shield":
			heat_shield_quality = comp.quality
			break

	# Success chance based on quality
	var success_chance = heat_shield_quality / 100.0 * 0.95 + 0.05  # 5-100% based on quality
	var roll = _rng.randf()

	if roll < success_chance:
		_reentry_results.heat_shield_success = true
		GameStore.add_log("Heat shield holding! Temperature: 1600C - within tolerance.", "success")
		_reentry_stage = ReentryStage.PARACHUTE
	else:
		# Heat shield failure - catastrophic
		_reentry_results.heat_shield_success = false
		GameStore.add_log("HEAT SHIELD FAILURE! Hull breach detected!", "error")
		_handle_reentry_failure("heat_shield")
		return

	_update_reentry_display()

func _do_parachute_check():
	# Get parachute/landing system quality
	var components = GameStore.get_components()
	var parachute_quality = 50.0

	for comp in components:
		if comp.id == "landing_system" or comp.id == "parachute":
			parachute_quality = comp.quality
			break

	var success_chance = parachute_quality / 100.0 * 0.9 + 0.1
	var roll = _rng.randf()

	if roll < success_chance:
		_reentry_results.parachute_success = true
		GameStore.add_log("Main chutes deployed successfully! Descent rate nominal.", "success")
		_reentry_stage = ReentryStage.LANDING
	else:
		# Parachute failure - some crew may survive with backup
		_reentry_results.parachute_success = false
		GameStore.add_log("PRIMARY PARACHUTE FAILURE! Deploying backup systems!", "error")

		# 50% of crew survive with backup chutes
		var crew = GameStore.get_crew()
		for member in crew:
			if member.health > 0 and _rng.randf() < 0.5:
				_reentry_results.crew_survived.append(member.id)

		if _reentry_results.crew_survived.is_empty():
			_handle_reentry_failure("parachute")
			return

		GameStore.add_log("Emergency systems activated. Hard landing imminent.", "event")
		_reentry_stage = ReentryStage.LANDING

	_update_reentry_display()

func _do_landing_check():
	# Navigation quality affects landing
	var components = GameStore.get_components()
	var nav_quality = 50.0

	for comp in components:
		if comp.id == "navigation" or comp.id == "computer":
			nav_quality = comp.quality
			break

	var success_chance = nav_quality / 100.0 * 0.85 + 0.15

	# If parachutes failed, landing is much harder
	if not _reentry_results.parachute_success:
		success_chance *= 0.5

	var roll = _rng.randf()

	if roll < success_chance:
		_reentry_results.landing_success = true
		GameStore.add_log("TOUCHDOWN! Welcome home!", "success")

		# All surviving crew make it
		var crew = GameStore.get_crew()
		if _reentry_results.parachute_success:
			for member in crew:
				if member.health > 0:
					_reentry_results.crew_survived.append(member.id)
		# else: crew_survived was already set in parachute check

		_reentry_stage = ReentryStage.COMPLETE
	else:
		# Hard landing - crew injuries
		_reentry_results.landing_success = false
		GameStore.add_log("HARD LANDING! Impact outside target zone!", "error")

		# Some crew survive
		var crew = GameStore.get_crew()
		for member in crew:
			if member.health > 0:
				if _rng.randf() < 0.7:  # 70% survival chance per person
					_reentry_results.crew_survived.append(member.id)

		if _reentry_results.crew_survived.is_empty():
			_handle_reentry_failure("landing")
			return

		GameStore.add_log("Search and rescue teams deployed.", "event")
		_reentry_stage = ReentryStage.COMPLETE

	_update_reentry_display()

func _handle_reentry_failure(stage: String):
	_reentry_stage = ReentryStage.FAILED

	match stage:
		"heat_shield":
			GameStore.add_log("The spacecraft disintegrated during atmospheric entry.", "error")
			GameStore.add_log("All crew members were lost.", "error")
		"parachute":
			GameStore.add_log("No parachutes deployed. Impact was fatal.", "error")
			GameStore.add_log("The mission payload and samples were destroyed.", "error")
		"landing":
			GameStore.add_log("The landing was unsurvivable.", "error")

	_update_reentry_display()

func _update_reentry_display():
	if not reentry_panel:
		return

	var stage_names = {
		ReentryStage.APPROACH: "Earth Approach",
		ReentryStage.HEAT_SHIELD: "Atmospheric Entry",
		ReentryStage.PARACHUTE: "Parachute Deployment",
		ReentryStage.LANDING: "Final Approach",
		ReentryStage.COMPLETE: "Mission Complete",
		ReentryStage.FAILED: "Mission Failed"
	}

	reentry_title.text = stage_names.get(_reentry_stage, "Reentry")

	var status_text = "[center][b]REENTRY SEQUENCE[/b][/center]\n\n"

	# Show all stages with status
	var stages = [
		["Earth Approach", ReentryStage.APPROACH, true],
		["Heat Shield Check", ReentryStage.HEAT_SHIELD, _reentry_results.heat_shield_success],
		["Parachute Deploy", ReentryStage.PARACHUTE, _reentry_results.parachute_success],
		["Landing", ReentryStage.LANDING, _reentry_results.landing_success]
	]

	for stage_info in stages:
		var name = stage_info[0]
		var stage_enum = stage_info[1]
		var success = stage_info[2]

		if _reentry_stage > stage_enum or _reentry_stage == ReentryStage.COMPLETE:
			# Completed stage
			if success:
				status_text += "[color=green][ OK ][/color] %s\n" % name
			else:
				status_text += "[color=red][FAIL][/color] %s\n" % name
		elif _reentry_stage == stage_enum:
			# Current stage
			status_text += "[color=yellow][ >> ][/color] %s...\n" % name
		else:
			# Future stage
			status_text += "[color=gray][ -- ][/color] %s\n" % name

	if _reentry_stage == ReentryStage.COMPLETE:
		status_text += "\n[color=green][b]MISSION COMPLETE[/b][/color]\n"
		status_text += "Crew survivors: %d\n" % _reentry_results.crew_survived.size()
		reentry_button.visible = true
		reentry_button.text = "View Mission Results"
	elif _reentry_stage == ReentryStage.FAILED:
		status_text += "\n[color=red][b]MISSION FAILED[/b][/color]\n"
		status_text += "No survivors.\n"
		reentry_button.visible = true
		reentry_button.text = "View Mission Results"
	else:
		reentry_button.visible = false

	reentry_status.text = status_text

func _on_reentry_continue():
	# Store reentry results in state for game_over screen
	var state = GameStore.get_state()
	state = GameTypes.with_field(state, "reentry_results", _reentry_results)

	# Update crew death count if needed
	var crew = GameStore.get_crew()
	var deaths = 0
	for member in crew:
		if member.health > 0 and not member.id in _reentry_results.crew_survived:
			deaths += 1

	# Log final status
	if _reentry_stage == ReentryStage.COMPLETE:
		var survivors = _reentry_results.crew_survived.size()
		if survivors == 4:
			GameStore.add_log("PERFECT MISSION - All crew returned home safely!", "success")
		elif survivors > 0:
			GameStore.add_log("%d crew member(s) returned to Earth." % survivors, "success")
			GameStore.add_log("%d crew member(s) lost during reentry." % deaths, "error")
		else:
			GameStore.add_log("Ship reached Earth but no surviving crew.", "error")
	else:
		GameStore.add_log("The mission ended in tragedy.", "error")

	GameStore.change_phase(GameTypes.GamePhase.GAME_OVER)
