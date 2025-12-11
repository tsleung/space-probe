extends Control

## Colony Sim Main UI
## The core gameplay interface for the colony simulation expansion

# ============================================================================
# NODE REFERENCES
# ============================================================================

# Top bar
@onready var title_label: Label = $TopBar/TitleLabel
@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var year_label: Label = $TopBar/YearLabel
@onready var population_label: Label = $TopBar/PopulationLabel
@onready var stability_label: Label = $TopBar/StabilityLabel

# Left panel - Resources & Buildings
@onready var resource_container: VBoxContainer = $MainContent/LeftPanel/ResourcePanel/ResourceContainer
@onready var building_list: ItemList = $MainContent/LeftPanel/BuildingPanel/BuildingList
@onready var build_button: Button = $MainContent/LeftPanel/BuildingPanel/BuildButton
@onready var repair_button: Button = $MainContent/LeftPanel/BuildingPanel/RepairButton

# Center panel - Population
@onready var tab_container: TabContainer = $MainContent/CenterPanel/PopulationPanel/TabContainer
@onready var colonist_container: VBoxContainer = $MainContent/CenterPanel/PopulationPanel/TabContainer/Colonists/ColonistScroll/ColonistContainer
@onready var stats_label: RichTextLabel = $MainContent/CenterPanel/PopulationPanel/TabContainer/Statistics/StatsLabel
@onready var politics_label: RichTextLabel = $MainContent/CenterPanel/PopulationPanel/TabContainer/Politics/PoliticsLabel
@onready var election_button: Button = $MainContent/CenterPanel/PopulationPanel/TabContainer/Politics/ElectionButton
@onready var independence_button: Button = $MainContent/CenterPanel/PopulationPanel/TabContainer/Politics/IndependenceButton
@onready var projection_label: RichTextLabel = $MainContent/CenterPanel/ProjectionPanel/ProjectionLabel

# Right panel - Events & Log
@onready var event_title: Label = $MainContent/RightPanel/EventPanel/EventTitle
@onready var event_description: RichTextLabel = $MainContent/RightPanel/EventPanel/EventDescription
@onready var choice_container: VBoxContainer = $MainContent/RightPanel/EventPanel/ChoiceContainer
@onready var colony_log: RichTextLabel = $MainContent/RightPanel/LogPanel/ColonyLog

# Bottom bar
@onready var workers_button: Button = $BottomBar/WorkersButton
@onready var advance_button: Button = $BottomBar/AdvanceButton
@onready var advance_5_button: Button = $BottomBar/Advance5Button
@onready var auto_button: Button = $BottomBar/AutoButton
@onready var speed_slider: HSlider = $BottomBar/SpeedSlider
@onready var speed_label: Label = $BottomBar/SpeedLabel
@onready var save_button: Button = $BottomBar/SaveButton
@onready var menu_button: Button = $BottomBar/MenuButton

# Build dialog
@onready var build_dialog: Window = $BuildDialog
@onready var build_type_list: ItemList = $BuildDialog/VBoxContainer/BuildTypeList
@onready var cost_label: Label = $BuildDialog/VBoxContainer/CostLabel
@onready var cancel_build_button: Button = $BuildDialog/VBoxContainer/HBoxContainer/CancelBuildButton
@onready var confirm_build_button: Button = $BuildDialog/VBoxContainer/HBoxContainer/ConfirmBuildButton

# Game over overlay
@onready var game_over_overlay: ColorRect = $GameOverOverlay
@onready var game_over_title: Label = $GameOverOverlay/VBoxContainer/TitleLabel
@onready var game_over_reason: Label = $GameOverOverlay/VBoxContainer/ReasonLabel
@onready var game_over_stats: Label = $GameOverOverlay/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOverOverlay/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $GameOverOverlay/VBoxContainer/MainMenuButton

# ============================================================================
# LOCAL STATE
# ============================================================================

var _colony_store: Node = null
var _auto_advance: bool = false
var _auto_advance_timer: float = 0.0
var _auto_advance_speed: float = 0.5
var _selected_building_idx: int = -1
var _selected_build_type: int = -1
var _peak_population: int = 0

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_init_store()
	_connect_signals()
	_sync_ui()
	_init_log()

func _init_store():
	# Create colony store instance if needed
	_colony_store = ColonySimStore.new()
	add_child(_colony_store)

	# Start new colony if no existing game
	if _colony_store.get_year() == 0:
		_colony_store.start_new_colony(12)

func _connect_signals():
	# Store signals
	_colony_store.state_changed.connect(_on_state_changed)
	_colony_store.year_advanced.connect(_on_year_advanced)
	_colony_store.event_triggered.connect(_on_event_triggered)
	_colony_store.event_resolved.connect(_on_event_resolved)
	_colony_store.game_ended.connect(_on_game_ended)
	_colony_store.log_entry_added.connect(_on_log_entry)

	# UI signals
	advance_button.pressed.connect(_on_advance_year)
	advance_5_button.pressed.connect(_on_advance_5_years)
	auto_button.toggled.connect(_on_auto_toggled)
	speed_slider.value_changed.connect(_on_speed_changed)
	workers_button.pressed.connect(_on_auto_assign_workers)
	save_button.pressed.connect(_on_save)
	menu_button.pressed.connect(_on_menu)

	build_button.pressed.connect(_on_build_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	building_list.item_selected.connect(_on_building_selected)

	election_button.pressed.connect(_on_election)
	independence_button.pressed.connect(_on_independence_vote)

	# Build dialog
	build_type_list.item_selected.connect(_on_build_type_selected)
	cancel_build_button.pressed.connect(_on_build_cancel)
	confirm_build_button.pressed.connect(_on_build_confirm)
	build_dialog.close_requested.connect(_on_build_cancel)

	# Game over
	restart_button.pressed.connect(_on_restart)
	main_menu_button.pressed.connect(_on_menu)

func _process(delta: float):
	if _auto_advance and not _colony_store.is_game_over():
		_auto_advance_timer += delta
		if _auto_advance_timer >= _auto_advance_speed:
			_auto_advance_timer = 0.0
			_on_advance_year()

func _init_log():
	colony_log.clear()
	var log_entries = _colony_store.get_colony_log()
	var start = maxi(0, log_entries.size() - 30)
	for i in range(start, log_entries.size()):
		_add_log_entry(log_entries[i])

# ============================================================================
# UI SYNC
# ============================================================================

func _sync_ui():
	var state = _colony_store.get_state()

	# Track peak population
	_peak_population = maxi(_peak_population, state.colonists.size())

	# Top bar
	phase_label.text = "Era: %s" % _colony_store.get_phase_name()
	year_label.text = "Year: %d" % state.current_year
	population_label.text = "Pop: %d" % state.colonists.size()
	stability_label.text = "Stability: %.0f%%" % state.politics.stability

	# Color stability based on value
	if state.politics.stability < 30:
		stability_label.modulate = Color.RED
	elif state.politics.stability < 60:
		stability_label.modulate = Color.YELLOW
	else:
		stability_label.modulate = Color.GREEN

	# Resources
	_update_resources(state.resources)

	# Buildings
	_update_buildings(state.buildings)

	# Population tabs
	_update_colonists(state.colonists)
	_update_statistics(state)
	_update_politics(state)

	# Projections
	_update_projections()

	# Events
	_update_events(state.active_events)

	# Button states
	_update_button_states(state)

func _update_resources(resources: Dictionary):
	for child in resource_container.get_children():
		child.queue_free()

	var resource_order = ["food", "water", "oxygen", "power", "materials", "fuel", "science", "culture"]

	for resource_name in resource_order:
		if resources.has(resource_name):
			var amount = resources[resource_name]
			var hbox = HBoxContainer.new()
			resource_container.add_child(hbox)

			var name_label = Label.new()
			name_label.text = resource_name.capitalize()
			name_label.custom_minimum_size = Vector2(80, 0)
			hbox.add_child(name_label)

			var bar = ProgressBar.new()
			bar.custom_minimum_size = Vector2(100, 16)
			bar.max_value = 500.0  # Cap for display
			bar.value = minf(amount, 500.0)
			bar.show_percentage = false
			hbox.add_child(bar)

			var value_label = Label.new()
			value_label.text = "%.0f" % amount
			value_label.custom_minimum_size = Vector2(50, 0)
			hbox.add_child(value_label)

			# Color based on amount (low = red, high = green)
			if amount < 50:
				bar.modulate = Color.RED
			elif amount < 150:
				bar.modulate = Color.YELLOW
			else:
				bar.modulate = Color.GREEN

func _update_buildings(buildings: Array):
	building_list.clear()
	for building in buildings:
		var status = ""
		if not building.is_operational:
			if building.construction_progress < 1.0:
				status = " [BUILDING %.0f%%]" % (building.construction_progress * 100)
			else:
				status = " [BROKEN]"

		var workers = building.assigned_workers.size()
		var capacity = building.worker_capacity
		var worker_text = " (%d/%d)" % [workers, capacity] if capacity > 0 else ""

		var name = ColonySimTypes.get_building_name(building.type)
		building_list.add_item("%s%s%s" % [name, worker_text, status])

		# Color based on status
		var idx = building_list.item_count - 1
		if not building.is_operational:
			building_list.set_item_custom_fg_color(idx, Color.ORANGE if building.construction_progress < 1.0 else Color.RED)

func _update_colonists(colonists: Array):
	for child in colonist_container.get_children():
		child.queue_free()

	# Sort by generation then age
	var sorted = colonists.duplicate()
	sorted.sort_custom(func(a, b): return a.generation * 1000 + a.age < b.generation * 1000 + b.age)

	for colonist in sorted:
		var panel = _create_colonist_entry(colonist)
		colonist_container.add_child(panel)

func _create_colonist_entry(colonist: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 30)

	var name_label = Label.new()
	name_label.text = "%s (%d)" % [colonist.display_name, colonist.age]
	name_label.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(name_label)

	var gen_label = Label.new()
	gen_label.text = ColonySimTypes.get_generation_name(colonist.generation)
	gen_label.custom_minimum_size = Vector2(80, 0)
	gen_label.modulate = _get_generation_color(colonist.generation)
	hbox.add_child(gen_label)

	var specialty_label = Label.new()
	specialty_label.text = ColonySimTypes.get_specialty_name(colonist.specialty)
	specialty_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(specialty_label)

	var effectiveness = ColonySimPopulation.calc_effectiveness(colonist)
	var eff_label = Label.new()
	eff_label.text = "%.0f%%" % (effectiveness * 100)
	eff_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	hbox.add_child(eff_label)

	return hbox

func _get_generation_color(generation: int) -> Color:
	match generation:
		ColonySimTypes.Generation.FOUNDER: return Color.GOLD
		ColonySimTypes.Generation.FIRST: return Color.CYAN
		ColonySimTypes.Generation.SECOND: return Color.GREEN
		ColonySimTypes.Generation.THIRD: return Color.YELLOW
		_: return Color.WHITE

func _update_statistics(state: Dictionary):
	var gen_breakdown = _colony_store.get_generation_breakdown()
	var faction_breakdown = _colony_store.get_faction_breakdown()

	var text = "[b]Population Breakdown[/b]\n\n"

	text += "[u]By Generation:[/u]\n"
	for gen in ColonySimTypes.Generation.values():
		var count = gen_breakdown.get(gen, 0)
		if count > 0:
			text += "  %s: %d\n" % [ColonySimTypes.get_generation_name(gen), count]

	text += "\n[u]By Faction:[/u]\n"
	for faction in ColonySimTypes.Faction.values():
		var count = faction_breakdown.get(faction, 0)
		if count > 0:
			text += "  %s: %d\n" % [ColonySimTypes.get_faction_name(faction), count]

	text += "\n[u]Workforce:[/u]\n"
	var workforce = _colony_store.get_workforce()
	text += "  Workers: %d\n" % workforce.size()

	var children = 0
	var elderly = 0
	for c in state.colonists:
		if c.life_stage == ColonySimTypes.LifeStage.CHILD:
			children += 1
		elif c.life_stage == ColonySimTypes.LifeStage.ELDERLY:
			elderly += 1
	text += "  Children: %d\n" % children
	text += "  Elderly: %d\n" % elderly

	stats_label.text = text

func _update_politics(state: Dictionary):
	var pol = state.politics

	var text = "[b]Political Overview[/b]\n\n"

	text += "[u]Government:[/u] %s\n" % ColonySimTypes.get_political_system_name(pol.government_type)
	text += "[u]Stability:[/u] %.0f%%\n" % pol.stability
	text += "[u]Independence:[/u] %.0f%%\n\n" % pol.independence_sentiment

	if pol.current_leader:
		text += "[u]Leader:[/u] %s\n" % pol.current_leader
		text += "[u]Ruling Faction:[/u] %s\n\n" % ColonySimTypes.get_faction_name(pol.ruling_faction)

	text += "[u]Faction Support:[/u]\n"
	for faction in ColonySimTypes.Faction.values():
		var support = pol.faction_standings.get(faction, 0.0)
		if support > 0:
			text += "  %s: %.0f%%\n" % [ColonySimTypes.get_faction_name(faction), support * 100]

	politics_label.text = text

	# Button visibility
	election_button.visible = state.current_year >= 5
	independence_button.visible = state.current_year >= 20 and pol.independence_sentiment >= 50

func _update_projections():
	var projection = _colony_store.project_next_year()

	var text = "[b]Next Year Forecast[/b]\n\n"

	text += "[u]Net Resources:[/u]\n"
	for key in projection.net.keys():
		var net = projection.net[key]
		var color = "green" if net >= 0 else "red"
		var sign = "+" if net >= 0 else ""
		text += "  %s: [color=%s]%s%.0f[/color]\n" % [key.capitalize(), color, sign, net]

	text += "\n[u]Capacity:[/u]\n"
	var power = projection.power_balance
	var housing = projection.housing_balance
	text += "  Power: [color=%s]%s%.0f[/color]\n" % ["green" if power >= 0 else "red", "+" if power >= 0 else "", power]
	text += "  Housing: [color=%s]%s%d[/color]\n" % ["green" if housing >= 0 else "red", "+" if housing >= 0 else "", housing]

	text += "\n[u]Food Security:[/u] %.1f years" % projection.food_surplus_years

	projection_label.text = text

func _update_events(active_events: Array):
	# Clear existing choice buttons
	for child in choice_container.get_children():
		child.queue_free()

	if active_events.is_empty():
		event_title.text = "No Active Event"
		event_description.text = "Events will appear here as the colony develops."
		return

	var event = active_events[0]  # Show first active event
	event_title.text = event.title
	event_description.text = event.description

	# Create choice buttons
	for i in range(event.choices.size()):
		var choice = event.choices[i]
		var button = Button.new()
		button.text = choice.text
		button.pressed.connect(func(): _on_choice_selected(event.id, i))
		choice_container.add_child(button)

func _update_button_states(state: Dictionary):
	# Disable controls during events that need resolution
	var has_active_event = not state.active_events.is_empty()

	advance_button.disabled = has_active_event
	advance_5_button.disabled = has_active_event
	auto_button.disabled = has_active_event

	if has_active_event and _auto_advance:
		_auto_advance = false
		auto_button.button_pressed = false

	# Repair button
	repair_button.disabled = _selected_building_idx < 0

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_year_advanced(year: int):
	year_label.text = "Year: %d" % year

func _on_event_triggered(event: Dictionary):
	_update_events([event])
	# Pause auto-advance during events
	if _auto_advance:
		_auto_advance = false
		auto_button.button_pressed = false

func _on_event_resolved(_event_id: String, _choice: int, outcome: String):
	_add_log_entry({"year": _colony_store.get_year(), "message": outcome, "log_type": "event"})
	_sync_ui()

func _on_game_ended(is_victory: bool, reason: String):
	_auto_advance = false
	auto_button.button_pressed = false

	game_over_overlay.visible = true
	game_over_title.text = "VICTORY!" if is_victory else "COLONY LOST"
	game_over_title.modulate = Color.GOLD if is_victory else Color.RED
	game_over_reason.text = reason
	game_over_stats.text = "Years survived: %d\nPeak population: %d\nFinal population: %d" % [
		_colony_store.get_year(),
		_peak_population,
		_colony_store.get_colonist_count()
	]

func _on_log_entry(entry: Dictionary):
	_add_log_entry(entry)

func _add_log_entry(entry: Dictionary):
	var color = "white"
	match entry.log_type:
		"crisis": color = "red"
		"death": color = "orange"
		"birth": color = "cyan"
		"milestone": color = "gold"
		"political": color = "purple"
		"event": color = "yellow"
		"success": color = "green"
		"info": color = "gray"

	colony_log.append_text("[color=%s][Year %d] %s[/color]\n" % [color, entry.year, entry.message])

func _on_advance_year():
	if not _colony_store.is_game_over():
		_colony_store.advance_year()

func _on_advance_5_years():
	for i in range(5):
		if not _colony_store.is_game_over() and _colony_store.get_active_events().is_empty():
			_colony_store.advance_year()

func _on_auto_toggled(toggled: bool):
	_auto_advance = toggled
	_auto_advance_timer = 0.0

func _on_speed_changed(value: float):
	_auto_advance_speed = 1.0 / value
	speed_label.text = "%dx" % int(value)

func _on_auto_assign_workers():
	_colony_store.auto_assign_workers()
	_sync_ui()

func _on_save():
	if _colony_store.save_colony(0):
		_add_log_entry({"year": _colony_store.get_year(), "message": "Colony saved.", "log_type": "info"})

func _on_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_restart():
	game_over_overlay.visible = false
	_peak_population = 0
	_colony_store.start_new_colony(12)
	colony_log.clear()
	_init_log()
	_sync_ui()

func _on_building_selected(index: int):
	_selected_building_idx = index
	repair_button.disabled = false

func _on_build_pressed():
	build_dialog.visible = true
	_populate_build_types()

func _on_repair_pressed():
	if _selected_building_idx < 0:
		return

	var buildings = _colony_store.get_buildings()
	if _selected_building_idx < buildings.size():
		var building = buildings[_selected_building_idx]
		_colony_store.repair_building(building.id)

func _on_build_type_selected(index: int):
	_selected_build_type = index
	_update_build_cost()

func _on_build_cancel():
	build_dialog.visible = false
	_selected_build_type = -1

func _on_build_confirm():
	if _selected_build_type >= 0:
		var building_types = ColonySimTypes.BuildingType.values()
		if _selected_build_type < building_types.size():
			_colony_store.start_construction(building_types[_selected_build_type])
	build_dialog.visible = false
	_selected_build_type = -1

func _populate_build_types():
	build_type_list.clear()
	for building_type in ColonySimTypes.BuildingType.values():
		build_type_list.add_item(ColonySimTypes.get_building_name(building_type))

func _update_build_cost():
	if _selected_build_type < 0:
		cost_label.text = "Select a building type"
		return

	# Building costs (simplified)
	var costs = {
		ColonySimTypes.BuildingType.HABITAT: {"materials": 50, "power": 10},
		ColonySimTypes.BuildingType.GREENHOUSE: {"materials": 40, "power": 15},
		ColonySimTypes.BuildingType.SOLAR_ARRAY: {"materials": 30, "power": 0},
		ColonySimTypes.BuildingType.WATER_EXTRACTOR: {"materials": 60, "power": 20},
		ColonySimTypes.BuildingType.MINING_RIG: {"materials": 80, "power": 25},
		ColonySimTypes.BuildingType.WORKSHOP: {"materials": 70, "power": 15},
		ColonySimTypes.BuildingType.MEDICAL_BAY: {"materials": 100, "power": 20},
		ColonySimTypes.BuildingType.SCHOOL: {"materials": 60, "power": 10},
		ColonySimTypes.BuildingType.LAB: {"materials": 90, "power": 25},
		ColonySimTypes.BuildingType.COMMAND_CENTER: {"materials": 120, "power": 30},
		ColonySimTypes.BuildingType.REACTOR: {"materials": 150, "power": 0},
		ColonySimTypes.BuildingType.SPACEPORT: {"materials": 200, "power": 50},
	}

	var building_types = ColonySimTypes.BuildingType.values()
	if _selected_build_type < building_types.size():
		var type = building_types[_selected_build_type]
		var cost = costs.get(type, {"materials": 50, "power": 10})
		cost_label.text = "Cost: %d materials, %d power/yr" % [cost.materials, cost.power]

func _on_choice_selected(event_id: String, choice_index: int):
	_colony_store.resolve_event(event_id, choice_index)

func _on_election():
	_colony_store.hold_election()

func _on_independence_vote():
	_colony_store.hold_independence_vote()
