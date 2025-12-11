extends Control

## Return Journey Phase UI
## The desperate final stretch - worn equipment, limited supplies, Earth calling

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

var _auto_travel: bool = false
var _auto_travel_timer: float = 0.0
var _auto_travel_speed: float = 0.2
var _return_travel_day: int = 0
var _return_travel_total: int = 180
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	_rng.seed = int(Time.get_unix_time_from_system())
	_connect_signals()
	_init_return_journey()
	_init_log()
	_sync_ui()

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)
	advance_button.pressed.connect(_on_advance_day)
	advance_week_button.pressed.connect(_on_advance_week)
	auto_button.toggled.connect(_on_toggle_auto)
	speed_slider.value_changed.connect(_on_speed_changed)

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

	# Check for arrival
	if _return_travel_day >= _return_travel_total:
		_complete_mission()

func _complete_mission():
	var crew = GameStore.get_crew()
	var alive_count = 0
	for member in crew:
		if member.health > 0:
			alive_count += 1

	if alive_count > 0:
		GameStore.add_log("EARTH ORBIT ACHIEVED!", "success")
		GameStore.add_log("%d crew member(s) returning home safely." % alive_count, "success")
		if alive_count == 4:
			GameStore.add_log("PERFECT MISSION - All crew survived!", "success")
	else:
		GameStore.add_log("Ship reached Earth but no surviving crew.", "error")
		GameStore.add_log("The sacrifice of the crew will be remembered.", "event")

	GameStore.change_phase(GameTypes.GamePhase.GAME_OVER)
