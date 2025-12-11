extends Control

## First Contact War - Main UI Controller
## Real-time strategy with adjustable speed

# ============================================================================
# CONSTANTS
# ============================================================================

const SPEED_SETTINGS = [0.0, 5.0, 3.0, 1.5, 0.5]  # Paused, Slow, Normal, Fast, Very Fast
const SPEED_NAMES = ["PAUSED", "SLOW", "NORMAL", "FAST", "VERY FAST"]

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var store: FCWStore = $FCWStore

# Header
@onready var turn_label: Label = $MainContainer/Header/TurnLabel
@onready var lives_label: Label = $MainContainer/Header/LivesLabel
@onready var threat_label: Label = $MainContainer/Header/ThreatLabel

# Guidance panel
@onready var guidance_panel: PanelContainer = $MainContainer/GuidancePanel
@onready var guidance_label: RichTextLabel = $MainContainer/GuidancePanel/GuidanceLabel

# Map panel - visual solar system
@onready var map_panel: PanelContainer = $MainContainer/GameArea/MapPanel
var solar_map: FCWSolarMap

# Resources panel
@onready var resources_container: VBoxContainer = $MainContainer/GameArea/SidePanel/ResourcesPanel/ResourcesContainer

# Fleet panel
@onready var fleet_list: ItemList = $MainContainer/GameArea/SidePanel/FleetPanel/FleetList
@onready var build_buttons: HBoxContainer = $MainContainer/GameArea/SidePanel/FleetPanel/BuildButtons
@onready var production_label: Label = $MainContainer/GameArea/SidePanel/FleetPanel/ProductionLabel

# Zone detail panel
@onready var zone_detail: PanelContainer = $MainContainer/GameArea/SidePanel/ZoneDetailPanel
@onready var zone_name_label: RichTextLabel = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneNameLabel
@onready var zone_status_label: RichTextLabel = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneStatusLabel
@onready var zone_pop_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZonePopLabel
@onready var zone_defense_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneDefenseLabel
@onready var zone_buildings_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneBuildingsLabel
@onready var assign_buttons: HBoxContainer = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/AssignButtons

# Event log
@onready var event_log: RichTextLabel = $MainContainer/GameArea/SidePanel/EventLog/LogText

# Speed controls
@onready var speed_label: Label = $MainContainer/Footer/SpeedLabel
@onready var speed_slider: HSlider = $MainContainer/Footer/SpeedSlider
@onready var pause_btn: Button = $MainContainer/Footer/PauseBtn

# Game over panel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var victory_tier_label: Label = $GameOverPanel/VBox/VictoryTierLabel
@onready var victory_desc_label: Label = $GameOverPanel/VBox/VictoryDescLabel
@onready var final_stats_label: Label = $GameOverPanel/VBox/FinalStatsLabel
@onready var new_game_btn: Button = $GameOverPanel/VBox/Buttons/NewGameBtn
@onready var menu_btn: Button = $GameOverPanel/VBox/Buttons/MenuBtn

# State
var _selected_zone: int = -1
var _speed_index: int = 2  # Start at Normal
var _turn_timer: float = 0.0
var _is_paused: bool = false
var _attack_phase_timer: float = 0.0
var _is_in_attack_phase: bool = false
const ATTACK_PHASE_DURATION = 1.5  # Show attack animation for 1.5 seconds

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	store.start_new_game()
	_sync_ui()
	_update_guidance()

func _process(delta: float) -> void:
	if store.is_game_over():
		return

	# Handle attack animation phase
	if _is_in_attack_phase:
		_attack_phase_timer += delta
		if _attack_phase_timer >= ATTACK_PHASE_DURATION:
			_is_in_attack_phase = false
			solar_map.set_attacking(false)
		return

	if _is_paused:
		return

	var turn_duration = SPEED_SETTINGS[_speed_index]
	if turn_duration <= 0:
		return  # Paused

	_turn_timer += delta
	if _turn_timer >= turn_duration:
		_turn_timer = 0.0
		_process_turn()

func _setup_ui() -> void:
	# Create visual solar system map
	_create_solar_map()

	# Create build buttons
	_create_build_buttons()

	# Create assign buttons
	_create_assign_buttons()

	# Setup speed slider
	speed_slider.min_value = 0
	speed_slider.max_value = SPEED_SETTINGS.size() - 1
	speed_slider.step = 1
	speed_slider.value = _speed_index

func _create_solar_map() -> void:
	# Remove the old MapContainer if it exists
	var old_container = map_panel.get_node_or_null("MapContainer")
	if old_container:
		old_container.queue_free()

	# Create the visual solar map
	solar_map = FCWSolarMap.new()
	solar_map.name = "SolarMap"
	solar_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solar_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(solar_map)

	# Connect signals
	solar_map.zone_clicked.connect(_on_zone_clicked)
	solar_map.zone_hovered.connect(_on_zone_hovered)

func _create_build_buttons() -> void:
	for child in build_buttons.get_children():
		child.queue_free()

	var ships = [
		[FCWTypes.ShipType.FRIGATE, "Frigate\n10S 5E 2W"],
		[FCWTypes.ShipType.CRUISER, "Cruiser\n30S 15E 8W"],
		[FCWTypes.ShipType.CARRIER, "Carrier\n50S 30E 5W"],
		[FCWTypes.ShipType.DREADNOUGHT, "Dread\n100S 50E 20W"]
	]

	for ship_data in ships:
		var btn = Button.new()
		btn.text = ship_data[1]
		btn.custom_minimum_size = Vector2(80, 50)
		btn.pressed.connect(_build_ship.bind(ship_data[0]))
		build_buttons.add_child(btn)

func _create_assign_buttons() -> void:
	for child in assign_buttons.get_children():
		child.queue_free()

	# Add ship assignment buttons
	var label = Label.new()
	label.text = "Assign:"
	assign_buttons.add_child(label)

	for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.DREADNOUGHT]:
		var btn = Button.new()
		btn.text = "+%s" % FCWTypes.get_ship_name(ship_type).substr(0, 4)
		btn.pressed.connect(_assign_ship_to_zone.bind(ship_type))
		assign_buttons.add_child(btn)

func _connect_signals() -> void:
	store.state_changed.connect(_on_state_changed)
	store.turn_ended.connect(_on_turn_ended)
	store.zone_fallen.connect(_on_zone_fallen)
	store.game_over.connect(_on_game_over)

	speed_slider.value_changed.connect(_on_speed_changed)
	pause_btn.pressed.connect(_on_pause_pressed)

	new_game_btn.pressed.connect(_on_new_game)
	menu_btn.pressed.connect(_on_main_menu)

# ============================================================================
# UI SYNC
# ============================================================================

func _on_state_changed(_new_state: Dictionary) -> void:
	_sync_ui()
	_update_guidance()

func _sync_ui() -> void:
	_sync_header()
	_sync_resources()
	_sync_fleet()
	_sync_map()
	_sync_event_log()
	_sync_zone_detail()
	_sync_build_buttons()
	_sync_speed_display()

func _sync_header() -> void:
	var turn = store.get_turn()
	var eta = store.estimate_turns_until_earth()
	turn_label.text = "WEEK %d | ~%d weeks until Earth assault" % [turn, eta]

	var lives = store.get_lives_evacuated()
	var tier = FCWTypes.get_victory_tier(lives)
	var tier_name = FCWTypes.get_victory_tier_name(tier)
	lives_label.text = "EVACUATED: %s [%s]" % [FCWTypes.format_population(lives), tier_name]

	var threat = store.get_herald_strength()
	var target = store.get_herald_target()
	var target_defense = store.get_zone_defense(target)
	var status = "WILL HOLD" if target_defense >= threat else "WILL FALL"
	threat_label.text = "HERALD: %d → %s (%s)" % [threat, FCWTypes.get_zone_name(target), status]

func _sync_resources() -> void:
	# Clear and rebuild
	for child in resources_container.get_children():
		if child is Label and child.name != "Title":
			child.queue_free()

	var res = store.get_resources()
	var resource_order = ["ore", "steel", "energy", "electronics", "rare", "weapons"]

	for res_name in resource_order:
		var label = Label.new()
		label.text = "%s: %d" % [res_name.capitalize(), res.get(res_name, 0)]
		resources_container.add_child(label)

func _sync_fleet() -> void:
	fleet_list.clear()
	var fleet = store.get_fleet()
	var available = store.get_available_ships()

	var total_power = 0
	for ship_type in fleet:
		var count = fleet[ship_type]
		if count <= 0:
			continue
		var avail = available.get(ship_type, 0)
		var power = FCWTypes.get_ship_combat_power(ship_type) * count
		total_power += power
		fleet_list.add_item("%s: %d (%d free) = %d power" % [
			FCWTypes.get_ship_name(ship_type), count, avail, power
		])

	fleet_list.add_item("--- TOTAL: %d power ---" % total_power)

	# Production queue
	var queue = store.get_production_queue()
	var capacity = store.get_production_capacity()
	if queue.is_empty():
		production_label.text = "Shipyards: %d idle" % capacity
	else:
		var items: Array = []
		for order in queue:
			items.append("%s(%d)" % [FCWTypes.get_ship_name(order.ship_type).substr(0, 4), order.turns_remaining])
		production_label.text = "Building: %s [%d/%d]" % [", ".join(items), queue.size(), queue.size() + capacity]

func _sync_map() -> void:
	if not solar_map:
		return

	var state = store.get_state()

	# Build zone defenses dictionary
	var zone_defenses: Dictionary = {}
	for zone_id in state.zones:
		zone_defenses[zone_id] = store.get_zone_defense(zone_id)

	solar_map.update_state(state, zone_defenses)
	solar_map.set_selected_zone(_selected_zone)

func _sync_event_log() -> void:
	var log = store.get_event_log()
	var text = ""
	var start = maxi(0, log.size() - 8)
	for i in range(start, log.size()):
		var entry = log[i]
		var prefix = "[color=red]▶[/color] " if entry.is_critical else "  "
		text += "%sW%d: %s\n" % [prefix, entry.turn, entry.message]

	event_log.text = text

func _sync_zone_detail() -> void:
	if _selected_zone < 0:
		zone_detail.visible = false
		return

	zone_detail.visible = true
	var zone = store.get_zone(_selected_zone)

	zone_name_label.text = "[b]%s[/b]" % FCWTypes.get_zone_name(_selected_zone)

	match zone.status:
		FCWTypes.ZoneStatus.CONTROLLED:
			zone_status_label.text = "Status: [color=green]CONTROLLED[/color]"
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			zone_status_label.text = "Status: [color=orange]UNDER ATTACK[/color]"
		FCWTypes.ZoneStatus.FALLEN:
			zone_status_label.text = "Status: [color=red]FALLEN[/color]"

	zone_pop_label.text = "Population: %s" % FCWTypes.format_population(zone.population)
	zone_defense_label.text = "Defense Power: %d" % store.get_zone_defense(_selected_zone)

	# Buildings
	var buildings_text = "Buildings: "
	for btype in zone.buildings:
		var count = zone.buildings[btype]
		if count > 0:
			buildings_text += "%s×%d " % [FCWTypes.get_building_name(btype).substr(0, 4), count]
	zone_buildings_label.text = buildings_text

	# Fleet in zone
	var fleet_text = "Fleet: "
	for stype in zone.assigned_fleet:
		var count = zone.assigned_fleet[stype]
		if count > 0:
			fleet_text += "%s×%d " % [FCWTypes.get_ship_name(stype).substr(0, 4), count]
	if fleet_text == "Fleet: ":
		fleet_text = "Fleet: None"
	zone_defense_label.text += "\n" + fleet_text

func _sync_build_buttons() -> void:
	var capacity = store.get_production_capacity()
	var idx = 0
	for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.DREADNOUGHT]:
		if idx < build_buttons.get_child_count():
			var btn = build_buttons.get_child(idx) as Button
			btn.disabled = not store.can_afford_ship(ship_type) or capacity <= 0
		idx += 1

func _sync_speed_display() -> void:
	speed_label.text = "Speed: %s" % SPEED_NAMES[_speed_index]
	pause_btn.text = "▶ PLAY" if _is_paused else "⏸ PAUSE"

# ============================================================================
# PLAYER GUIDANCE
# ============================================================================

func _update_guidance() -> void:
	var state = store.get_state()
	var text = ""

	# Priority guidance based on game state
	var target = store.get_herald_target()
	var target_defense = store.get_zone_defense(target)
	var herald_strength = store.get_herald_strength()
	var available = store.get_available_ships()
	var total_available = 0
	for st in available:
		total_available += available[st]

	# Check critical situations
	if target_defense < herald_strength:
		var deficit = herald_strength - target_defense
		text += "[color=red][b]⚠ %s WILL FALL![/b][/color]\n" % FCWTypes.get_zone_name(target)
		text += "Need %d more defense power. " % deficit
		if total_available > 0:
			text += "[color=yellow]Click zone → Assign ships![/color]\n"
		else:
			text += "Build more ships!\n"
	elif target_defense < herald_strength * 1.2:
		text += "[color=yellow]⚠ %s defense is tight.[/color] Consider reinforcing.\n" % FCWTypes.get_zone_name(target)
	else:
		text += "[color=green]✓ %s should hold.[/color]\n" % FCWTypes.get_zone_name(target)

	# Production guidance
	var capacity = store.get_production_capacity()
	if capacity > 0:
		text += "\n[color=cyan]💡 You have %d shipyard slots free. Build ships![/color]\n" % capacity

	# Evacuation reminder
	var lives = store.get_lives_evacuated()
	if lives < 50_000_000:
		text += "\n[color=gray]Tip: Assign ships to ESCORT order to evacuate civilians.[/color]"

	# Turn info
	text += "\n\n[i]Week %d | Herald strength: %d[/i]" % [state.turn, herald_strength]

	guidance_label.text = text

# ============================================================================
# ACTIONS
# ============================================================================

func _process_turn() -> void:
	# Check if combat will occur this turn
	var target = store.get_herald_target()
	var target_defense = store.get_zone_defense(target)
	var herald_strength = store.get_herald_strength()

	# Start attack animation if Herald is at target and attacking
	if target_defense < herald_strength * 2:  # Close enough to attack
		_is_in_attack_phase = true
		_attack_phase_timer = 0.0
		solar_map.set_attacking(true)

	store.dispatch_end_turn()

func _on_zone_clicked(zone_id: int) -> void:
	_select_zone(zone_id)

func _on_zone_hovered(_zone_id: int) -> void:
	pass  # Could show tooltip

func _select_zone(zone_id: int) -> void:
	_selected_zone = zone_id
	_sync_zone_detail()
	_sync_map()

func _build_ship(ship_type: int) -> void:
	store.dispatch_build_ship(ship_type)

func _assign_ship_to_zone(ship_type: int) -> void:
	if _selected_zone < 0:
		return
	store.dispatch_assign_fleet(_selected_zone, ship_type, 1)

func _on_speed_changed(value: float) -> void:
	_speed_index = int(value)
	if _speed_index == 0:
		_is_paused = true
	else:
		_is_paused = false
	_sync_speed_display()

func _on_pause_pressed() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		speed_slider.value = 0
	else:
		if _speed_index == 0:
			_speed_index = 2  # Default to normal
		speed_slider.value = _speed_index
	_sync_speed_display()

func _on_turn_ended(_turn: int) -> void:
	_update_guidance()

func _on_zone_fallen(zone_id: int) -> void:
	# Brief pause on zone fall for drama
	_is_paused = true
	_sync_speed_display()

func _on_game_over(victory_tier: int) -> void:
	game_over_panel.visible = true
	_is_paused = true

	victory_tier_label.text = FCWTypes.get_victory_tier_name(victory_tier)
	victory_desc_label.text = '"%s"' % FCWTypes.get_victory_description(victory_tier)

	var stats = ""
	stats += "Lives Evacuated: %s\n" % FCWTypes.format_population(store.get_lives_evacuated())
	stats += "Lives Lost: %s\n" % FCWTypes.format_population(store.get_lives_lost())
	stats += "Weeks Survived: %d\n" % store.get_turn()
	stats += "Final Fleet Strength: %d\n" % store.get_total_fleet_strength()
	final_stats_label.text = stats

func _on_new_game() -> void:
	game_over_panel.visible = false
	_is_paused = false
	_speed_index = 2
	speed_slider.value = 2
	store.start_new_game()

func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
