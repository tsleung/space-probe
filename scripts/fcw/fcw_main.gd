extends Control

## First Contact War - Main UI Controller

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var store: FCWStore = $FCWStore

# Header
@onready var turn_label: Label = $MainContainer/Header/TurnLabel
@onready var lives_label: Label = $MainContainer/Header/LivesLabel
@onready var threat_label: Label = $MainContainer/Header/ThreatLabel

# Map panel
@onready var map_container: VBoxContainer = $MainContainer/GameArea/MapPanel/MapContainer
@onready var zone_buttons: Dictionary = {}

# Resources panel
@onready var ore_label: Label = $MainContainer/GameArea/SidePanel/ResourcesPanel/OreLabel
@onready var steel_label: Label = $MainContainer/GameArea/SidePanel/ResourcesPanel/SteelLabel
@onready var energy_label: Label = $MainContainer/GameArea/SidePanel/ResourcesPanel/EnergyLabel
@onready var electronics_label: Label = $MainContainer/GameArea/SidePanel/ResourcesPanel/ElectronicsLabel
@onready var rare_label: Label = $MainContainer/GameArea/SidePanel/ResourcesPanel/RareLabel
@onready var weapons_label: Label = $MainContainer/GameArea/SidePanel/ResourcesPanel/WeaponsLabel

# Fleet panel
@onready var fleet_list: ItemList = $MainContainer/GameArea/SidePanel/FleetPanel/FleetList
@onready var build_frigate_btn: Button = $MainContainer/GameArea/SidePanel/FleetPanel/BuildButtons/FrigateBtn
@onready var build_cruiser_btn: Button = $MainContainer/GameArea/SidePanel/FleetPanel/BuildButtons/CruiserBtn
@onready var build_carrier_btn: Button = $MainContainer/GameArea/SidePanel/FleetPanel/BuildButtons/CarrierBtn
@onready var build_dread_btn: Button = $MainContainer/GameArea/SidePanel/FleetPanel/BuildButtons/DreadBtn
@onready var production_label: Label = $MainContainer/GameArea/SidePanel/FleetPanel/ProductionLabel

# Zone detail panel
@onready var zone_detail: PanelContainer = $MainContainer/GameArea/SidePanel/ZoneDetailPanel
@onready var zone_name_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneNameLabel
@onready var zone_status_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneStatusLabel
@onready var zone_pop_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZonePopLabel
@onready var zone_defense_label: Label = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/ZoneDefenseLabel
@onready var assign_fleet_container: HBoxContainer = $MainContainer/GameArea/SidePanel/ZoneDetailPanel/VBox/AssignFleet

# Event log
@onready var event_log: RichTextLabel = $MainContainer/GameArea/SidePanel/EventLog/LogText

# Action buttons
@onready var end_turn_btn: Button = $MainContainer/Footer/EndTurnBtn
@onready var main_menu_btn: Button = $MainContainer/Footer/MainMenuBtn

# Game over panel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var victory_tier_label: Label = $GameOverPanel/VBox/VictoryTierLabel
@onready var victory_desc_label: Label = $GameOverPanel/VBox/VictoryDescLabel
@onready var final_stats_label: Label = $GameOverPanel/VBox/FinalStatsLabel

var _selected_zone: int = -1

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_connect_signals()
	store.start_new_game()
	_sync_ui()

func _connect_signals() -> void:
	store.state_changed.connect(_on_state_changed)
	store.turn_ended.connect(_on_turn_ended)
	store.zone_fallen.connect(_on_zone_fallen)
	store.game_over.connect(_on_game_over)

	end_turn_btn.pressed.connect(_on_end_turn)
	main_menu_btn.pressed.connect(_on_main_menu)

	build_frigate_btn.pressed.connect(func(): _build_ship(FCWTypes.ShipType.FRIGATE))
	build_cruiser_btn.pressed.connect(func(): _build_ship(FCWTypes.ShipType.CRUISER))
	build_carrier_btn.pressed.connect(func(): _build_ship(FCWTypes.ShipType.CARRIER))
	build_dread_btn.pressed.connect(func(): _build_ship(FCWTypes.ShipType.DREADNOUGHT))

# ============================================================================
# UI SYNC
# ============================================================================

func _on_state_changed(_new_state: Dictionary) -> void:
	_sync_ui()

func _sync_ui() -> void:
	_sync_header()
	_sync_resources()
	_sync_fleet()
	_sync_map()
	_sync_event_log()
	_sync_zone_detail()
	_sync_build_buttons()

func _sync_header() -> void:
	var turn = store.get_turn()
	var eta = store.estimate_turns_until_earth()
	turn_label.text = "TURN %d | ~%d turns until Earth assault" % [turn, eta]

	var lives = store.get_lives_evacuated()
	lives_label.text = "EVACUATED: %s" % FCWTypes.format_population(lives)

	var threat = store.get_herald_strength()
	var target = store.get_herald_target()
	threat_label.text = "HERALD: %d -> %s" % [threat, FCWTypes.get_zone_name(target)]

func _sync_resources() -> void:
	var res = store.get_resources()
	ore_label.text = "Ore: %d" % res.get("ore", 0)
	steel_label.text = "Steel: %d" % res.get("steel", 0)
	energy_label.text = "Energy: %d" % res.get("energy", 0)
	electronics_label.text = "Electronics: %d" % res.get("electronics", 0)
	rare_label.text = "Rare: %d" % res.get("rare", 0)
	weapons_label.text = "Weapons: %d" % res.get("weapons", 0)

func _sync_fleet() -> void:
	fleet_list.clear()
	var fleet = store.get_fleet()
	var available = store.get_available_ships()

	for ship_type in fleet:
		var total = fleet[ship_type]
		var avail = available.get(ship_type, 0)
		var power = FCWTypes.get_ship_combat_power(ship_type) * total
		fleet_list.add_item("%s: %d (%d avail) [%d power]" % [
			FCWTypes.get_ship_name(ship_type), total, avail, power
		])

	# Production queue
	var queue = store.get_production_queue()
	var capacity = store.get_production_capacity()
	if queue.is_empty():
		production_label.text = "Production: Idle (%d slots)" % capacity
	else:
		var building = queue[0]
		production_label.text = "Building: %s (%d turns) [%d/%d slots]" % [
			FCWTypes.get_ship_name(building.ship_type),
			building.turns_remaining,
			queue.size(),
			queue.size() + capacity
		]

func _sync_map() -> void:
	var zones = store.get_zones()
	var target = store.get_herald_target()

	# Update zone button colors based on status
	for zone_id in zones:
		var zone = zones[zone_id]
		var btn = _get_or_create_zone_button(zone_id)

		var status_text = ""
		var color = Color.GREEN

		match zone.status:
			FCWTypes.ZoneStatus.CONTROLLED:
				status_text = "[CONTROLLED]"
				color = Color.GREEN
			FCWTypes.ZoneStatus.UNDER_ATTACK:
				status_text = "[UNDER ATTACK]"
				color = Color.ORANGE
			FCWTypes.ZoneStatus.FALLEN:
				status_text = "[FALLEN]"
				color = Color.RED

		if zone_id == target and zone.status != FCWTypes.ZoneStatus.FALLEN:
			status_text = "[TARGET]"
			color = Color.YELLOW

		var defense = store.get_zone_defense(zone_id)
		btn.text = "%s\n%s\nDef: %d" % [FCWTypes.get_zone_name(zone_id), status_text, defense]
		btn.modulate = color
		btn.disabled = zone.status == FCWTypes.ZoneStatus.FALLEN

func _get_or_create_zone_button(zone_id: int) -> Button:
	if zone_buttons.has(zone_id):
		return zone_buttons[zone_id]

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 60)
	btn.pressed.connect(func(): _select_zone(zone_id))
	zone_buttons[zone_id] = btn
	map_container.add_child(btn)
	return btn

func _sync_event_log() -> void:
	var log = store.get_event_log()
	var text = ""
	# Show last 10 entries
	var start = maxi(0, log.size() - 10)
	for i in range(start, log.size()):
		var entry = log[i]
		var prefix = "[color=red]![/color] " if entry.is_critical else ""
		text += "%sT%d: %s\n" % [prefix, entry.turn, entry.message]

	event_log.text = text

func _sync_zone_detail() -> void:
	if _selected_zone < 0:
		zone_detail.visible = false
		return

	zone_detail.visible = true
	var zone = store.get_zone(_selected_zone)

	zone_name_label.text = FCWTypes.get_zone_name(_selected_zone)

	match zone.status:
		FCWTypes.ZoneStatus.CONTROLLED:
			zone_status_label.text = "Status: CONTROLLED"
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			zone_status_label.text = "Status: UNDER ATTACK"
		FCWTypes.ZoneStatus.FALLEN:
			zone_status_label.text = "Status: FALLEN"

	zone_pop_label.text = "Population: %s" % FCWTypes.format_population(zone.population)
	zone_defense_label.text = "Defense: %d" % store.get_zone_defense(_selected_zone)

func _sync_build_buttons() -> void:
	build_frigate_btn.disabled = not store.can_afford_ship(FCWTypes.ShipType.FRIGATE) or store.get_production_capacity() <= 0
	build_cruiser_btn.disabled = not store.can_afford_ship(FCWTypes.ShipType.CRUISER) or store.get_production_capacity() <= 0
	build_carrier_btn.disabled = not store.can_afford_ship(FCWTypes.ShipType.CARRIER) or store.get_production_capacity() <= 0
	build_dread_btn.disabled = not store.can_afford_ship(FCWTypes.ShipType.DREADNOUGHT) or store.get_production_capacity() <= 0

# ============================================================================
# ACTIONS
# ============================================================================

func _select_zone(zone_id: int) -> void:
	_selected_zone = zone_id
	_sync_zone_detail()

func _build_ship(ship_type: int) -> void:
	store.dispatch_build_ship(ship_type)

func _on_end_turn() -> void:
	store.dispatch_end_turn()

func _on_turn_ended(_turn: int) -> void:
	# Could play sound or animation here
	pass

func _on_zone_fallen(zone_id: int) -> void:
	# Could show dramatic notification
	print("ZONE FALLEN: ", FCWTypes.get_zone_name(zone_id))

func _on_game_over(victory_tier: int) -> void:
	game_over_panel.visible = true

	victory_tier_label.text = FCWTypes.get_victory_tier_name(victory_tier)
	victory_desc_label.text = FCWTypes.get_victory_description(victory_tier)

	var stats = "Lives Evacuated: %s\n" % FCWTypes.format_population(store.get_lives_evacuated())
	stats += "Lives Lost: %s\n" % FCWTypes.format_population(store.get_lives_lost())
	stats += "Turns Survived: %d\n" % store.get_turn()
	final_stats_label.text = stats

func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
