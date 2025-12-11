extends Control

## Ship Building Phase UI
## Thin UI layer - all logic delegated to pure functions via GameStore

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var hex_grid_view: Node2D = $HBoxContainer/GridPanel/GridViewport/SubViewport/HexGrid
@onready var budget_label: Label = $TopBar/BudgetLabel
@onready var days_label: Label = $TopBar/DaysLabel
@onready var launch_window_label: Label = $TopBar/LaunchWindowLabel
@onready var component_list: ItemList = $HBoxContainer/SidePanel/TabContainer/Components/ComponentList
@onready var engine_list: ItemList = $HBoxContainer/SidePanel/TabContainer/Engines/EngineList
@onready var crew_list: ItemList = $HBoxContainer/SidePanel/TabContainer/Crew/VBox/CrewList
@onready var crew_options: OptionButton = $HBoxContainer/SidePanel/TabContainer/Crew/VBox/CrewOptions
@onready var hire_button: Button = $HBoxContainer/SidePanel/TabContainer/Crew/VBox/HireButton
@onready var mav_check: CheckBox = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/MAVCheck
@onready var rovers_check: CheckBox = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/RoversCheck
# Supply sliders
@onready var food_slider: HSlider = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/FoodHBox/FoodSlider
@onready var food_value_label: Label = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/FoodHBox/FoodValue
@onready var water_slider: HSlider = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/WaterHBox/WaterSlider
@onready var water_value_label: Label = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/WaterHBox/WaterValue
@onready var oxygen_slider: HSlider = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/OxygenHBox/OxygenSlider
@onready var oxygen_value_label: Label = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/OxygenHBox/OxygenValue
@onready var spare_parts_spin: SpinBox = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/SparePartsHBox/SparePartsSpin
@onready var spare_parts_cost: Label = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/SparePartsHBox/SparePartsCost
@onready var med_kits_spin: SpinBox = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/MedKitsHBox/MedKitsSpin
@onready var med_kits_cost: Label = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/MedKitsHBox/MedKitsCost
@onready var supply_cost_label: Label = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/SupplyCostLabel
@onready var survival_preview: RichTextLabel = $HBoxContainer/SidePanel/TabContainer/Cargo/VBox/SurvivalPreview
@onready var info_panel: Panel = $HBoxContainer/SidePanel/InfoPanel
@onready var info_name: Label = $HBoxContainer/SidePanel/InfoPanel/VBox/NameLabel
@onready var info_desc: RichTextLabel = $HBoxContainer/SidePanel/InfoPanel/VBox/DescLabel
@onready var info_stats: RichTextLabel = $HBoxContainer/SidePanel/InfoPanel/VBox/StatsLabel
@onready var build_button: Button = $HBoxContainer/SidePanel/InfoPanel/VBox/BuildButton
@onready var test_button: Button = $HBoxContainer/SidePanel/InfoPanel/VBox/TestButton
@onready var launch_button: Button = $BottomBar/LaunchButton
@onready var advance_day_button: Button = $BottomBar/AdvanceDayButton
@onready var advance_week_button: Button = $BottomBar/AdvanceWeekButton
@onready var auto_advance_button: Button = $BottomBar/AutoAdvanceButton
@onready var speed_slider: HSlider = $BottomBar/SpeedSlider
@onready var speed_label: Label = $BottomBar/SpeedLabel
@onready var readiness_bar: ProgressBar = $BottomBar/ReadinessBar
@onready var log_text: RichTextLabel = $HBoxContainer/SidePanel/LogPanel/LogText
@onready var launch_sequence = $LaunchSequence
@onready var event_popup = $EventPopup
@onready var primary_hint: RichTextLabel = $HBoxContainer/SidePanel/HintsPanel/HintsVBox/PrimaryHint
@onready var secondary_hints: Label = $HBoxContainer/SidePanel/HintsPanel/HintsVBox/SecondaryHints
@onready var tab_container: TabContainer = $HBoxContainer/SidePanel/TabContainer

# ============================================================================
# LOCAL UI STATE (not game state)
# ============================================================================

var _available_components: Array = []
var _available_engines: Array = []
var _available_crew: Array = []
var _selected_catalog_item: Dictionary = {}
var _selected_placed_component: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Auto-advance state
var _auto_advance: bool = false
var _auto_advance_timer: float = 0.0
var _auto_advance_speed: float = 0.2  # seconds per day

# Event state
var _event_paused: bool = false
var _pending_event: Dictionary = {}
var _triggered_events: Array = []

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_rng.seed = int(Time.get_unix_time_from_system())
	_load_catalog()
	_populate_lists()
	_connect_signals()
	_sync_ui_to_state()
	_update_supply_display()  # Initialize supply cost display
	_update_hints()  # Initialize hints panel

func _process(delta: float):
	if _auto_advance and not _event_paused:
		_auto_advance_timer += delta
		if _auto_advance_timer >= _auto_advance_speed:
			_auto_advance_timer = 0.0
			_advance_day_with_events()

func _load_catalog():
	_available_components = ComponentLogic.get_all_components()
	_available_engines = EngineLogic.get_all_engines()
	_generate_available_crew()

func _populate_lists():
	component_list.clear()
	for comp in _available_components:
		component_list.add_item("%s ($%s)" % [comp.display_name, GameTypes.format_money(comp.base_cost)])

	engine_list.clear()
	for engine in _available_engines:
		var suffix = " [Space Assembly]" if engine.requires_space_assembly else ""
		engine_list.add_item("%s ($%s)%s" % [engine.display_name, GameTypes.format_money(engine.base_cost), suffix])

	_populate_crew_options()

func _generate_available_crew():
	# Use the pre-made crew roster with personalities and backstories
	_available_crew = CrewRoster.get_available_crew()

func _populate_crew_options():
	crew_options.clear()
	for crew in _available_crew:
		var specialty_name = CrewLogic.get_specialty_name(crew.specialty)
		var personality_name = GameTypes.PersonalityTrait.keys()[crew.personality]
		crew_options.add_item("%s - %s (%s)" % [crew.display_name, specialty_name, personality_name])

func _connect_signals():
	# UI signals
	component_list.item_selected.connect(_on_component_selected)
	engine_list.item_selected.connect(_on_engine_selected)
	build_button.pressed.connect(_on_build_pressed)
	test_button.pressed.connect(_on_test_pressed)
	launch_button.pressed.connect(_on_launch_pressed)
	advance_day_button.pressed.connect(_on_advance_day_pressed)
	advance_week_button.pressed.connect(_on_advance_week_pressed)
	auto_advance_button.toggled.connect(_on_auto_advance_toggled)
	speed_slider.value_changed.connect(_on_speed_changed)

	# Crew and cargo signals
	hire_button.pressed.connect(_on_hire_crew_pressed)
	mav_check.toggled.connect(_on_mav_toggled)
	rovers_check.toggled.connect(_on_rovers_toggled)
	crew_options.item_selected.connect(_on_crew_option_selected)
	crew_list.item_selected.connect(_on_hired_crew_selected)

	# Supply slider signals
	food_slider.value_changed.connect(_on_supply_slider_changed)
	water_slider.value_changed.connect(_on_supply_slider_changed)
	oxygen_slider.value_changed.connect(_on_supply_slider_changed)
	spare_parts_spin.value_changed.connect(_on_supply_slider_changed)
	med_kits_spin.value_changed.connect(_on_supply_slider_changed)

	# Hex grid signals
	hex_grid_view.cell_clicked.connect(_on_grid_cell_clicked)

	# Store signals (reactive updates)
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry_added)

	# Launch sequence
	launch_sequence.sequence_complete.connect(_on_launch_sequence_complete)

	# Event popup signals
	if event_popup:
		event_popup.choice_made.connect(_on_event_choice_made)
		event_popup.popup_closed.connect(_on_event_popup_closed)

# ============================================================================
# UI EVENT HANDLERS
# ============================================================================

func _on_component_selected(index: int):
	_selected_catalog_item = _available_components[index].duplicate(true)
	_selected_placed_component = {}
	_update_info_panel_catalog(_selected_catalog_item)
	hex_grid_view.set_selected_component(_selected_catalog_item)

func _on_engine_selected(index: int):
	_selected_catalog_item = _available_engines[index].duplicate(true)
	_selected_placed_component = {}
	_update_info_panel_catalog(_selected_catalog_item)
	hex_grid_view.set_selected_component(_selected_catalog_item)

func _on_build_pressed():
	# Build is handled by clicking on grid
	pass

func _on_test_pressed():
	if _selected_placed_component.is_empty():
		return
	GameStore.test_component(_selected_placed_component.hex_position)

func _on_launch_pressed():
	var check = GameStore.get_launch_check()
	if check.can_launch:
		# Calculate travel days for the launch sequence
		var engine = GameStore.get_engine()
		var ship_mass = ShipLogic.calc_total_mass(GameStore.get_components())
		var days_past = maxi(0, GameStore.get_current_day() - GameStore.get_launch_window_day())
		var travel_days = TravelLogic.calc_travel_days(engine, ship_mass, days_past)

		# Show dramatic launch sequence
		_auto_advance = false
		launch_sequence.start_sequence(GameStore.get_crew(), travel_days)
	else:
		for issue in check.issues:
			GameStore.add_log("[color=red]Cannot launch: %s[/color]" % issue, "error")

func _on_launch_sequence_complete():
	# Set supplies based on player choices before starting travel
	if not _supply_settings.is_empty():
		GameStore.set_supply_levels(
			_supply_settings.food_percent / 100.0,
			_supply_settings.water_percent / 100.0,
			_supply_settings.oxygen_percent / 100.0,
			_supply_settings.spare_parts,
			_supply_settings.medical_kits
		)

	# Now actually start the travel phase
	GameStore.start_travel()
	get_tree().change_scene_to_file("res://scenes/phases/travel.tscn")

func _on_advance_day_pressed():
	_advance_day_with_events()

func _on_advance_week_pressed():
	for i in range(7):
		if _event_paused:
			break
		_advance_day_with_events()

func _advance_day_with_events():
	GameStore.advance_day(1)
	_check_for_interactive_event()

func _check_for_interactive_event():
	var day = GameStore.get_current_day()

	# Check if we should trigger an interactive event (lower frequency in ship building)
	if InteractiveEvents.should_event_trigger(GameTypes.GamePhase.SHIP_BUILDING, day, _rng.randf()):
		var event = InteractiveEvents.select_event(GameTypes.GamePhase.SHIP_BUILDING, _rng.randf())

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
	_sync_ui_to_state()

func _apply_event_state_changes(new_state: Dictionary):
	# Apply crew changes
	if new_state.has("crew"):
		for i in range(new_state.crew.size()):
			var crew_member = new_state.crew[i]
			GameStore.dispatch(GameReducer.action_update_crew(crew_member.id, crew_member))

	# Apply component changes
	if new_state.has("ship_components"):
		for comp in new_state.ship_components:
			GameStore.dispatch(GameReducer.action_update_component(comp.hex_position, comp))

	# Apply budget changes
	if new_state.has("budget"):
		var current = GameStore.get_budget()
		var diff = new_state.budget - current
		if diff > 0:
			GameStore.dispatch(GameReducer.action_add_budget(diff))
		elif diff < 0:
			GameStore.dispatch(GameReducer.action_spend_budget(-diff))

	# Apply days lost (skip ahead)
	if new_state.has("days_lost") and new_state.days_lost > 0:
		GameStore.advance_day(new_state.days_lost)
		GameStore.add_log("Lost %d days due to event." % new_state.days_lost, "event")

func _on_auto_advance_toggled(toggled: bool):
	_auto_advance = toggled
	_auto_advance_timer = 0.0
	_sync_auto_ui()

func _on_speed_changed(value: float):
	# Speed 1 = 1 day per second, Speed 10 = 10 days per second
	_auto_advance_speed = 1.0 / value
	speed_label.text = "%dx" % int(value)

func _sync_auto_ui():
	advance_day_button.disabled = _auto_advance
	advance_week_button.disabled = _auto_advance
	auto_advance_button.text = "Stop" if _auto_advance else "Auto"

func _on_grid_cell_clicked(hex_pos: Vector2i):
	if not _selected_catalog_item.is_empty():
		# Try to place selected catalog item
		var item = _selected_catalog_item.duplicate(true)
		if GameStore.place_component(item, hex_pos):
			# If this is an engine, also select it as the ship's engine
			if item.has("engine_class"):
				GameStore.select_engine(item)
			_selected_catalog_item = {}
			hex_grid_view.clear_selection()
	else:
		# Select placed component
		var component = ShipLogic.get_component_at(GameStore.get_hex_grid(), hex_pos)
		if not component.is_empty():
			_selected_placed_component = component
			_update_info_panel_placed(component)

func _on_hire_crew_pressed():
	var selected_idx = crew_options.selected
	if selected_idx < 0 or selected_idx >= _available_crew.size():
		return

	var crew = _available_crew[selected_idx]
	if GameStore.add_crew_member(crew):
		_available_crew.remove_at(selected_idx)
		_populate_crew_options()
		_sync_crew_list()

func _on_mav_toggled(toggled: bool):
	GameStore.update_cargo("mav", toggled)

func _on_rovers_toggled(toggled: bool):
	GameStore.update_cargo("rovers", 2 if toggled else 0)

func _on_supply_slider_changed(_value: float):
	_update_supply_display()

func _update_supply_display():
	# Update slider labels
	food_value_label.text = "%d%%" % int(food_slider.value)
	water_value_label.text = "%d%%" % int(water_slider.value)
	oxygen_value_label.text = "%d%%" % int(oxygen_slider.value)

	# Calculate costs - EXPENSIVE! Real trade-offs required
	# Spare parts: $2M each (critical for repairs)
	# Med kits: $2M each (critical for crew survival)
	# Base supply cost: $30M for 100% supplies
	# Extra supplies: $500K/% food, $300K/% water, $400K/% oxygen
	var spare_parts_count = int(spare_parts_spin.value)
	var med_kits_count = int(med_kits_spin.value)

	var spare_cost = spare_parts_count * 2_000_000
	var med_cost = med_kits_count * 2_000_000

	# Supply costs - significant investment required
	var food_extra = (food_slider.value - 100) * 500_000  # $500K per % over 100%
	var water_extra = (water_slider.value - 100) * 300_000  # $300K per %
	var oxygen_extra = (oxygen_slider.value - 100) * 400_000  # $400K per %

	var base_supply_cost = 30_000_000  # $30M base for minimum supplies
	var supply_total = base_supply_cost + food_extra + water_extra + oxygen_extra

	var total_cost = spare_cost + med_cost + supply_total

	spare_parts_cost.text = "($%dM)" % (spare_cost / 1_000_000)
	med_kits_cost.text = "($%dM)" % (med_cost / 1_000_000)

	if total_cost >= 0:
		supply_cost_label.text = "Supply Cost: $%dM" % (total_cost / 1_000_000)
		if total_cost > 50_000_000:
			supply_cost_label.modulate = Color.ORANGE  # Warn about high cost
		else:
			supply_cost_label.modulate = Color.WHITE
	else:
		supply_cost_label.text = "Supply Savings: -$%dM (DANGEROUS!)" % (absi(int(total_cost)) / 1_000_000)
		supply_cost_label.modulate = Color.RED

	# Store supply settings for launch
	_supply_settings = {
		"food_percent": food_slider.value,
		"water_percent": water_slider.value,
		"oxygen_percent": oxygen_slider.value,
		"spare_parts": spare_parts_count,
		"medical_kits": med_kits_count,
		"total_cost": total_cost
	}

	# Update survival preview
	_update_survival_preview()

var _supply_settings: Dictionary = {}

func _update_survival_preview():
	# Calculate estimated journey length based on selected engine
	var engine = GameStore.get_engine()
	var ship_mass = ShipLogic.calc_total_mass(GameStore.get_components())
	var days_past = maxi(0, GameStore.get_current_day() - GameStore.get_launch_window_day())

	var travel_days = TravelLogic.calc_travel_days(engine, ship_mass, days_past)

	# Calculate supply duration with selected settings
	var crew_count = GameStore.get_crew().size()
	if crew_count == 0:
		crew_count = 4  # Assume full crew for preview

	# Get daily consumption (assume 70% life support quality)
	var daily = TravelLogic.calc_daily_consumption(crew_count, 70.0)

	# Calculate base supplies for 100% (180 day reference journey)
	var base_journey_days = 180
	var base_food = daily.food_kg * base_journey_days
	var base_water = daily.water_kg * base_journey_days
	var base_oxygen = daily.oxygen_kg * base_journey_days

	# Apply player's supply percentages
	var actual_food = base_food * (food_slider.value / 100.0)
	var actual_water = base_water * (water_slider.value / 100.0)
	var actual_oxygen = base_oxygen * (oxygen_slider.value / 100.0)

	# Calculate how many days each supply lasts
	var food_days = actual_food / daily.food_kg if daily.food_kg > 0 else 999
	var water_days = actual_water / daily.water_kg if daily.water_kg > 0 else 999
	var oxygen_days = actual_oxygen / daily.oxygen_kg if daily.oxygen_kg > 0 else 999

	# The limiting factor is the supply that runs out first
	var min_supply_days = mini(int(food_days), mini(int(water_days), int(oxygen_days)))
	var margin_days = min_supply_days - travel_days

	# Build the preview text
	var text = "[b]Journey Preview[/b]\n"
	text += "Est. travel: %d days\n" % travel_days

	# Show supply days with color coding
	var food_color = "green" if food_days >= travel_days + 14 else ("yellow" if food_days >= travel_days else "red")
	var water_color = "green" if water_days >= travel_days + 14 else ("yellow" if water_days >= travel_days else "red")
	var oxygen_color = "green" if oxygen_days >= travel_days + 14 else ("yellow" if oxygen_days >= travel_days else "red")

	text += "[color=%s]Food: %d days[/color]\n" % [food_color, int(food_days)]
	text += "[color=%s]Water: %d days[/color]\n" % [water_color, int(water_days)]
	text += "[color=%s]Oxygen: %d days[/color]\n" % [oxygen_color, int(oxygen_days)]

	# Show overall margin
	if margin_days >= 14:
		text += "\n[color=green]Margin: +%d days (SAFE)[/color]" % margin_days
	elif margin_days >= 7:
		text += "\n[color=yellow]Margin: +%d days (TIGHT)[/color]" % margin_days
	elif margin_days >= 0:
		text += "\n[color=orange]Margin: +%d days (RISKY!)[/color]" % margin_days
	else:
		text += "\n[color=red]DEFICIT: %d days (DEATH!)[/color]" % abs(margin_days)

	survival_preview.text = text

func _on_crew_option_selected(index: int):
	if index >= 0 and index < _available_crew.size():
		_update_info_panel_crew(_available_crew[index])

func _on_hired_crew_selected(index: int):
	var hired_crew = GameStore.get_crew()
	if index >= 0 and index < hired_crew.size():
		_update_info_panel_crew(hired_crew[index])

func _update_info_panel_crew(crew: Dictionary):
	info_panel.visible = true
	info_name.text = crew.display_name

	var personality_desc = CrewRoster.get_personality_description(crew.personality)

	info_desc.text = "[b]%s[/b]\n%s\n\n[b]Background:[/b] %s" % [
		CrewLogic.get_specialty_name(crew.specialty),
		personality_desc,
		crew.backstory
	]

	var stats = ""
	stats += "[b]Skills:[/b]\n"
	stats += "  Piloting: %.0f\n" % crew.skill_piloting
	stats += "  Engineering: %.0f\n" % crew.skill_engineering
	stats += "  Science: %.0f\n" % crew.skill_science
	stats += "  Medical: %.0f\n" % crew.skill_medical
	stats += "  Leadership: %.0f\n" % crew.skill_leadership

	if not crew.personal_goal.is_empty():
		stats += "\n[b]Personal Goal:[/b]\n%s\n" % crew.personal_goal

	if not crew.quirk.is_empty():
		stats += "\n[b]Quirk:[/b] %s" % crew.quirk

	info_stats.text = stats
	build_button.visible = false
	test_button.visible = false

func _sync_crew_list():
	crew_list.clear()
	for crew in GameStore.get_crew():
		var specialty = CrewLogic.get_specialty_name(crew.specialty)
		crew_list.add_item("%s - %s" % [crew.display_name, specialty])

# ============================================================================
# STORE EVENT HANDLERS (reactive)
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui_to_state()
	_sync_crew_list()
	_sync_cargo_ui()
	_update_survival_preview()  # Recalculate when engine/crew changes
	_update_hints()  # Update guidance panel

func _on_log_entry_added(entry: Dictionary):
	var color = "white"
	match entry.event_type:
		"error": color = "red"
		"success": color = "green"
		"event": color = "yellow"

	log_text.append_text("[color=%s][Day %d] %s[/color]\n" % [color, entry.day, entry.message])

# ============================================================================
# UI SYNC (pure rendering from state)
# ============================================================================

func _sync_ui_to_state():
	var budget = GameStore.get_budget()
	var day = GameStore.get_current_day()
	var days_to_launch = GameStore.get_days_until_launch()
	var readiness = GameStore.get_readiness()
	var check = GameStore.get_launch_check()

	budget_label.text = "Budget: $%s" % GameTypes.format_money(budget)
	days_label.text = "Day: %d" % day

	if days_to_launch >= 0:
		launch_window_label.text = "Launch Window: %d days" % days_to_launch
		launch_window_label.modulate = Color.WHITE
	else:
		launch_window_label.text = "Launch Window: %d days OVERDUE" % abs(days_to_launch)
		launch_window_label.modulate = Color.RED

	readiness_bar.value = readiness
	launch_button.disabled = not check.can_launch

	# Disable hire button if max crew
	hire_button.disabled = GameStore.get_crew().size() >= 4

	# Update hex grid display
	hex_grid_view.sync_grid(GameStore.get_hex_grid())

	# Update selected placed component if it changed
	if not _selected_placed_component.is_empty():
		var updated = ShipLogic.get_component_at(
			GameStore.get_hex_grid(),
			_selected_placed_component.hex_position
		)
		if not updated.is_empty():
			_selected_placed_component = updated
			_update_info_panel_placed(updated)

func _sync_cargo_ui():
	var cargo = GameStore.get_cargo()
	mav_check.set_pressed_no_signal(cargo.get("mav", false))
	rovers_check.set_pressed_no_signal(cargo.get("rovers", 0) > 0)

# ============================================================================
# INFO PANEL RENDERING
# ============================================================================

func _update_info_panel_catalog(item: Dictionary):
	info_panel.visible = true
	info_name.text = item.display_name
	info_desc.text = item.description

	var stats = ""
	stats += "[b]Cost:[/b] $%s\n" % GameTypes.format_money(item.base_cost)
	stats += "[b]Build Time:[/b] %d days\n" % item.build_days
	stats += "[b]Mass:[/b] %.0f kg\n" % item.mass_kg
	stats += "[b]Size:[/b] %d hex(es)\n" % item.hex_size

	if item.has("engine_class"):
		stats += "\n[b]Engine Stats:[/b]\n"
		stats += "Thrust: %.2f N\n" % item.thrust_n
		stats += "Specific Impulse: %.0f s\n" % item.specific_impulse_s
		stats += "Fuel: %s\n" % item.fuel_type
		if item.requires_space_assembly:
			stats += "[color=yellow]Requires space assembly[/color]\n"
		if item.has_radiation_risk:
			stats += "[color=red]Radiation risk: %.0f%%[/color]\n" % (item.containment_leak_chance * 100)

	info_stats.text = stats
	build_button.visible = true
	build_button.disabled = item.base_cost > GameStore.get_budget()
	build_button.text = "Click grid to place"
	test_button.visible = false

func _update_info_panel_placed(item: Dictionary):
	info_panel.visible = true
	info_name.text = item.display_name
	info_desc.text = item.description

	var stats = ""
	stats += "[b]Quality:[/b] %.1f%%\n" % item.quality
	stats += "[b]Mass:[/b] %.0f kg\n" % item.mass_kg

	if item.is_built:
		stats += "[color=green]Construction complete[/color]\n"
	else:
		stats += "[color=yellow]Under construction (%d days remaining)[/color]\n" % item.days_remaining

	info_stats.text = stats
	build_button.visible = false
	test_button.visible = item.is_built
	test_button.disabled = item.test_cost_per_cycle > GameStore.get_budget()
	test_button.text = "Test ($%s, %dd)" % [GameTypes.format_money(item.test_cost_per_cycle), item.test_days_per_cycle]

# ============================================================================
# HINTS PANEL (contextual guidance)
# ============================================================================

func _update_hints():
	var hints = _get_current_hints()

	if hints.primary.is_empty():
		primary_hint.text = "[color=green]Ready to launch![/color]"
		secondary_hints.text = "Click LAUNCH when ready"
	else:
		primary_hint.text = hints.primary
		secondary_hints.text = hints.secondary

func _get_current_hints() -> Dictionary:
	var components = GameStore.get_components()
	var engine = GameStore.get_engine()
	var crew = GameStore.get_crew()

	# Check what's missing in priority order
	var has_cockpit = _has_component(components, "cockpit")
	var has_engine_mount = _has_component(components, "engine_mount")
	var has_life_support = _has_component(components, "life_support")
	var crew_rooms = _count_component(components, "crew_room")
	var has_engine = not engine.is_empty()
	var has_mav_dock = _has_component(components, "mav_dock")

	# Priority 1: Cockpit (required first)
	if not has_cockpit:
		return {
			"primary": "[b]1.[/b] Place a [color=yellow]Cockpit[/color] on the grid",
			"secondary": "Select it from Components tab, then click grid"
		}

	# Priority 2: Engine Mount
	if not has_engine_mount:
		return {
			"primary": "[b]2.[/b] Add an [color=yellow]Engine Mount[/color]",
			"secondary": "Required to install your engine"
		}

	# Priority 3: Select an engine
	if not has_engine:
		return {
			"primary": "[b]3.[/b] Choose an [color=yellow]Engine[/color]",
			"secondary": "Go to Engines tab - this determines travel time"
		}

	# Priority 4: Life Support
	if not has_life_support:
		return {
			"primary": "[b]4.[/b] Add [color=yellow]Life Support[/color]",
			"secondary": "Critical for crew survival"
		}

	# Priority 5: Crew
	if crew.size() == 0:
		return {
			"primary": "[b]5.[/b] Hire your [color=yellow]Crew[/color]",
			"secondary": "Go to Crew tab - need at least 1"
		}

	# Priority 6: Crew Rooms (match crew count)
	if crew_rooms < crew.size():
		return {
			"primary": "[b]6.[/b] Add [color=yellow]Crew Quarters[/color]",
			"secondary": "Need %d more (1 per crew member)" % (crew.size() - crew_rooms)
		}

	# Priority 7: MAV Dock (for return trip)
	if not has_mav_dock:
		return {
			"primary": "[b]7.[/b] Add [color=yellow]MAV Docking Bay[/color]",
			"secondary": "Required for the return journey"
		}

	# Check for components still building
	var building_count = 0
	for comp in components:
		if not comp.is_built:
			building_count += 1

	if building_count > 0:
		return {
			"primary": "[color=cyan]Waiting...[/color] %d component(s) building" % building_count,
			"secondary": "Use +1 Day or Auto to advance time"
		}

	# Check for low quality components
	var low_quality = []
	for comp in components:
		if comp.quality < 70:
			low_quality.append(comp.display_name)

	if low_quality.size() > 0:
		return {
			"primary": "[color=orange]Optional:[/color] Test low-quality parts",
			"secondary": "%s at <70%% - click to test" % low_quality[0]
		}

	# All good!
	return {"primary": "", "secondary": ""}

func _has_component(components: Array, id: String) -> bool:
	for comp in components:
		if comp.id == id:
			return true
	return false

func _count_component(components: Array, id: String) -> int:
	var count = 0
	for comp in components:
		if comp.id == id:
			count += 1
	return count
