extends Control

## Return Journey Phase UI
## Similar to travel to Mars, but heading home

@onready var day_label: Label = $TopBar/DayLabel
@onready var progress_label: Label = $TopBar/ProgressLabel
@onready var progress_bar: ProgressBar = $MainContent/LeftPanel/ProgressSection/ProgressBar
@onready var eta_label: Label = $MainContent/LeftPanel/ProgressSection/ETALabel
@onready var crew_container: VBoxContainer = $MainContent/LeftPanel/CrewSection/CrewContainer
@onready var ship_status: RichTextLabel = $MainContent/CenterPanel/ShipStatus
@onready var event_log: RichTextLabel = $MainContent/RightPanel/EventLog
@onready var advance_button: Button = $BottomBar/AdvanceButton
@onready var auto_button: Button = $BottomBar/AutoButton

var _auto_travel: bool = false
var _return_travel_day: int = 0
var _return_travel_total: int = 180

func _ready():
	_connect_signals()
	_init_return_journey()
	_sync_ui()

func _connect_signals():
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry)
	GameStore.phase_changed.connect(_on_phase_changed)
	advance_button.pressed.connect(_on_advance_day)
	auto_button.pressed.connect(_on_toggle_auto)

func _init_return_journey():
	# Calculate return journey time (usually similar to outbound)
	var state = GameStore.get_state()
	_return_travel_total = state.get("travel_total_days", 180)
	_return_travel_day = 0
	GameStore.add_log("Beginning return journey to Earth. Estimated time: %d days." % _return_travel_total, "success")

func _process(_delta):
	if _auto_travel:
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
	auto_button.text = "Stop" if _auto_travel else "Auto Return"

func _update_crew_display(crew: Array):
	for child in crew_container.get_children():
		child.queue_free()

	for member in crew:
		var panel = _create_crew_panel(member)
		crew_container.add_child(panel)

func _create_crew_panel(member: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = member.display_name
	vbox.add_child(name_label)

	var status_label = Label.new()
	status_label.text = CrewLogic.get_status_summary(member)
	var effectiveness = CrewLogic.calc_effectiveness(member)
	status_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	vbox.add_child(status_label)

	return panel

func _update_ship_status():
	var components = GameStore.get_components()
	var readiness = GameStore.get_readiness()
	var score = MarsLogic.calc_mission_score(GameStore.get_state())

	var text = "[b]Ship Status[/b]\n"
	text += "Readiness: %.1f%%\n\n" % readiness

	text += "[b]Mission Score[/b]\n"
	text += "Grade: %s\n" % score.grade
	text += "Points: %d\n" % score.score
	text += "Crew Alive: %d\n" % score.crew_alive
	text += "Experiments: %d\n" % score.experiments
	text += "Samples: %d\n" % score.samples

	ship_status.text = text

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_log_entry(entry: Dictionary):
	var color = "white"
	match entry.event_type:
		"error": color = "red"
		"success": color = "green"
		"event": color = "yellow"
	event_log.append_text("[color=%s][Day %d] %s[/color]\n" % [color, entry.day, entry.message])

func _on_phase_changed(new_phase: GameTypes.GamePhase):
	_auto_travel = false
	if new_phase == GameTypes.GamePhase.GAME_OVER:
		get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")

func _on_advance_day():
	_advance_return_day()

func _on_toggle_auto():
	_auto_travel = not _auto_travel
	_sync_ui()

func _do_auto_travel():
	if _return_travel_day >= _return_travel_total:
		_auto_travel = false
		return
	_advance_return_day()

func _advance_return_day():
	_return_travel_day += 1
	GameStore.advance_day(1)

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
		GameStore.add_log("Earth orbit achieved! Crew safely returned.", "success")
		GameStore.add_log("Mission complete!", "success")
	else:
		GameStore.add_log("Ship reached Earth but no surviving crew.", "error")

	GameStore.change_phase(GameTypes.GamePhase.GAME_OVER)
