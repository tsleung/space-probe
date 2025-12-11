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

func _process(delta: float):
	if _auto_advance:
		_auto_advance_timer += delta
		if _auto_advance_timer >= _auto_advance_speed:
			_auto_advance_timer = 0.0
			GameStore.advance_day(1)

func _load_catalog():
	_available_components = ComponentLogic.get_all_components()
	_available_engines = EngineLogic.get_all_engines()
	_generate_available_crew()

func _populate_lists():
	component_list.clear()
	for comp in _available_components:
		component_list.add_item("%s ($%s)" % [comp.display_name, _format_money(comp.base_cost)])

	engine_list.clear()
	for engine in _available_engines:
		var suffix = " [Space Assembly]" if engine.requires_space_assembly else ""
		engine_list.add_item("%s ($%s)%s" % [engine.display_name, _format_money(engine.base_cost), suffix])

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
	GameStore.advance_day(1)

func _on_advance_week_pressed():
	GameStore.advance_day(7)

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

	# Calculate costs
	# Spare parts: $1M each
	# Med kits: $1M each
	# Extra supplies beyond 100%: $100K per percentage point per resource
	var spare_parts_count = int(spare_parts_spin.value)
	var med_kits_count = int(med_kits_spin.value)

	var spare_cost = spare_parts_count * 1_000_000
	var med_cost = med_kits_count * 1_000_000

	# Supply costs - more than 100% costs extra, less than 100% saves money
	var food_extra = (food_slider.value - 100) * 100_000  # $100K per % over 100%
	var water_extra = (water_slider.value - 100) * 50_000  # $50K per % (water is cheaper)
	var oxygen_extra = (oxygen_slider.value - 100) * 80_000  # $80K per %

	var base_supply_cost = 10_000_000  # $10M base for minimum supplies
	var supply_total = base_supply_cost + food_extra + water_extra + oxygen_extra

	var total_cost = spare_cost + med_cost + supply_total

	spare_parts_cost.text = "($%dM)" % (spare_cost / 1_000_000)
	med_kits_cost.text = "($%dM)" % (med_cost / 1_000_000)

	if total_cost >= 0:
		supply_cost_label.text = "Supply Cost: $%dM" % (total_cost / 1_000_000)
		supply_cost_label.modulate = Color.WHITE
	else:
		supply_cost_label.text = "Supply Savings: -$%dM (risky!)" % (absi(int(total_cost)) / 1_000_000)
		supply_cost_label.modulate = Color.ORANGE

	# Store supply settings for launch
	_supply_settings = {
		"food_percent": food_slider.value,
		"water_percent": water_slider.value,
		"oxygen_percent": oxygen_slider.value,
		"spare_parts": spare_parts_count,
		"medical_kits": med_kits_count,
		"total_cost": total_cost
	}

var _supply_settings: Dictionary = {}

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

	budget_label.text = "Budget: $%s" % _format_money(budget)
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
	stats += "[b]Cost:[/b] $%s\n" % _format_money(item.base_cost)
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
	test_button.text = "Test ($%s, %dd)" % [_format_money(item.test_cost_per_cycle), item.test_days_per_cycle]

# ============================================================================
# UTILITIES
# ============================================================================

static func _format_money(amount: int) -> String:
	if amount >= 1_000_000_000:
		return "%.2fB" % (amount / 1_000_000_000.0)
	elif amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK" % (amount / 1_000.0)
	return str(amount)
