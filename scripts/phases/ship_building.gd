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
@onready var info_panel: Panel = $HBoxContainer/SidePanel/InfoPanel
@onready var info_name: Label = $HBoxContainer/SidePanel/InfoPanel/VBox/NameLabel
@onready var info_desc: RichTextLabel = $HBoxContainer/SidePanel/InfoPanel/VBox/DescLabel
@onready var info_stats: RichTextLabel = $HBoxContainer/SidePanel/InfoPanel/VBox/StatsLabel
@onready var build_button: Button = $HBoxContainer/SidePanel/InfoPanel/VBox/BuildButton
@onready var test_button: Button = $HBoxContainer/SidePanel/InfoPanel/VBox/TestButton
@onready var launch_button: Button = $BottomBar/LaunchButton
@onready var advance_day_button: Button = $BottomBar/AdvanceDayButton
@onready var readiness_bar: ProgressBar = $BottomBar/ReadinessBar
@onready var log_text: RichTextLabel = $HBoxContainer/SidePanel/LogPanel/LogText

# ============================================================================
# LOCAL UI STATE (not game state)
# ============================================================================

var _available_components: Array = []
var _available_engines: Array = []
var _selected_catalog_item: Dictionary = {}
var _selected_placed_component: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_load_catalog()
	_populate_lists()
	_connect_signals()
	_sync_ui_to_state()

func _load_catalog():
	_available_components = ComponentLogic.get_all_components()
	_available_engines = EngineLogic.get_all_engines()

func _populate_lists():
	component_list.clear()
	for comp in _available_components:
		component_list.add_item("%s ($%s)" % [comp.display_name, _format_money(comp.base_cost)])

	engine_list.clear()
	for engine in _available_engines:
		var suffix = " [Space Assembly]" if engine.requires_space_assembly else ""
		engine_list.add_item("%s ($%s)%s" % [engine.display_name, _format_money(engine.base_cost), suffix])

func _connect_signals():
	# UI signals
	component_list.item_selected.connect(_on_component_selected)
	engine_list.item_selected.connect(_on_engine_selected)
	build_button.pressed.connect(_on_build_pressed)
	test_button.pressed.connect(_on_test_pressed)
	launch_button.pressed.connect(_on_launch_pressed)
	advance_day_button.pressed.connect(_on_advance_day_pressed)

	# Hex grid signals
	hex_grid_view.cell_clicked.connect(_on_grid_cell_clicked)

	# Store signals (reactive updates)
	GameStore.state_changed.connect(_on_state_changed)
	GameStore.log_entry_added.connect(_on_log_entry_added)

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
		GameStore.start_travel()
		get_tree().change_scene_to_file("res://scenes/phases/travel.tscn")
	else:
		for issue in check.issues:
			GameStore.add_log("[color=red]Cannot launch: %s[/color]" % issue, "error")

func _on_advance_day_pressed():
	GameStore.advance_day(1)

func _on_grid_cell_clicked(hex_pos: Vector2i):
	if not _selected_catalog_item.is_empty():
		# Try to place selected catalog item
		if GameStore.place_component(_selected_catalog_item.duplicate(true), hex_pos):
			_selected_catalog_item = {}
			hex_grid_view.clear_selection()
	else:
		# Select placed component
		var component = ShipLogic.get_component_at(GameStore.get_hex_grid(), hex_pos)
		if not component.is_empty():
			_selected_placed_component = component
			_update_info_panel_placed(component)

# ============================================================================
# STORE EVENT HANDLERS (reactive)
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui_to_state()

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
