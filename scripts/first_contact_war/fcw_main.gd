extends Control

## First Contact War - Main UI Controller
## Real-time strategy with adjustable speed

# Preload FCW scripts
const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWStore = preload("res://scripts/first_contact_war/fcw_store.gd")
const FCWSolarMap = preload("res://scripts/first_contact_war/fcw_solar_map.gd")
const FCWBattleSystem = preload("res://scripts/first_contact_war/fcw_battle_system.gd")
const FCWBattleView = preload("res://scripts/first_contact_war/fcw_battle_view.gd")
const FCWPlanetView = preload("res://scripts/first_contact_war/fcw_planet_view.gd")

# AI Infrastructure (deterministic simulation)
const FCWActionEnumerator = preload("res://scripts/first_contact_war/fcw_action_enumerator.gd")
const FCWStateEvaluator = preload("res://scripts/first_contact_war/fcw_state_evaluator.gd")

# ============================================================================
# CONSTANTS
# ============================================================================

const SPEED_SETTINGS = [0.0, 5.0, 3.0, 1.5, 0.5, 0.2, 0.1]  # Paused, Slow, Normal, Fast, Very Fast, Turbo, Debug
const SPEED_NAMES = ["PAUSED", "SLOW", "NORMAL", "FAST", "VERY FAST", "TURBO", "DEBUG"]

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

# Strategic command buttons
@onready var go_dark_btn: Button = $MainContainer/StrategicCommandsPanel/GoDarkBtn
@onready var create_decoy_btn: Button = $MainContainer/StrategicCommandsPanel/CreateDecoyBtn
@onready var max_evac_btn: Button = $MainContainer/StrategicCommandsPanel/MaxEvacBtn
@onready var blockade_btn: Button = $MainContainer/StrategicCommandsPanel/BlockadeBtn

# Map panel - visual solar system
@onready var map_panel: PanelContainer = $MainContainer/GameArea/MapPanel
var solar_map: FCWSolarMap

# Fleet panel
@onready var fleet_list: ItemList = $MainContainer/GameArea/SidePanel/FleetPanel/VBox/FleetList
@onready var build_buttons: HBoxContainer = $MainContainer/GameArea/SidePanel/FleetPanel/VBox/BuildButtons
@onready var production_label: Label = $MainContainer/GameArea/SidePanel/FleetPanel/VBox/ProductionLabel

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
@onready var main_menu_btn: Button = $MainContainer/Footer/MainMenuBtn
var auto_play_btn: Button  # Created dynamically

# Game over panel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var victory_tier_label: Label = $GameOverPanel/VBox/VictoryTierLabel
@onready var victory_desc_label: Label = $GameOverPanel/VBox/VictoryDescLabel
@onready var final_stats_label: Label = $GameOverPanel/VBox/FinalStatsLabel
@onready var new_game_btn: Button = $GameOverPanel/VBox/Buttons/NewGameBtn
@onready var menu_btn: Button = $GameOverPanel/VBox/Buttons/MenuBtn

# Zone fallen overlay (created dynamically)
var _zone_fallen_overlay: PanelContainer
var _zone_fallen_label: RichTextLabel
var _zone_fallen_sublabel: Label
var _zone_fallen_btn: Button

# State
var _selected_zone: int = -1
var _speed_index: int = 2  # Start at Normal
var _is_paused: bool = false
var _attack_phase_timer: float = 0.0
var _is_in_attack_phase: bool = false
var _auto_play: bool = true  # AI plays autonomously (on by default)
const ATTACK_PHASE_DURATION = 1.5  # Show attack animation for 1.5 seconds

# NEW TIME SYSTEM - Discrete ticks with visual interpolation
# Time advances in 1-hour ticks; visuals interpolate between ticks
var _tick_progress: float = 0.0  # 0.0 to 1.0 progress toward next hour tick
var _accumulated_time: float = 0.0  # Accumulated real time since last tick

# Speed settings: ticks (hours) per real second
# At NORMAL (1.0), 1 hour = 1 second, full week = 168 seconds (~3 min)
# At FAST (4.0), 1 hour = 0.25 sec, full week = 42 seconds
# At VERY_FAST (12.0), 1 hour = ~0.08 sec, full week = 14 seconds
# At TURBO (48.0), full week = ~3.5 seconds
# At DEBUG (168.0), 1 week per second
const TICKS_PER_SECOND = [0.0, 0.5, 1.0, 4.0, 12.0, 48.0, 168.0]  # Paused, Slow, Normal, Fast, Very Fast, Turbo, Debug

# Battle System
var _battle_system: FCWBattleSystem
var _battle_view: FCWBattleView  # Primary battle view
var _extra_battle_views: Array = []  # Additional cascading battle views
var _show_battle_view: bool = true  # Toggle for cinematic battles
const MAX_BATTLE_VIEWS = 4  # Maximum simultaneous battle windows

# Planet Detail View (Picture-in-Picture)
var _planet_view: FCWPlanetView
var _planet_view_close_timer: float = -1.0  # Timer to auto-close planet view
var _planet_view_saved_positions: Dictionary = {}  # zone_id -> Vector2 (user-dragged positions)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_ui()
	_setup_battle_system()
	_setup_planet_view()
	_setup_zone_fallen_overlay()
	_connect_signals()
	_start_new_game()
	_sync_ui()
	_update_guidance()

func _setup_battle_system() -> void:
	# Create battle view in bottom-right corner (doesn't block galaxy view)
	# Note: _battle_system is initialized in _start_new_game()
	_battle_view = FCWBattleView.new()
	_battle_view.name = "BattleView"
	_battle_view.visible = false

	# Critical: Set layout mode to free positioning (not affected by parent layout)
	# layout_mode 0 = free position, not constrained by parent Container
	_battle_view.set_meta("_edit_use_anchors_", true)  # Use anchor mode in editor

	# Set size - position will be set when shown (needs viewport size)
	_battle_view.custom_minimum_size = Vector2(400, 280)
	_battle_view.size = Vector2(400, 280)

	# Disable size flags so parent doesn't try to resize
	_battle_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_battle_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	add_child(_battle_view)

	# Ensure it's on top of other UI elements
	_battle_view.z_index = 100

	# Position in bottom-right (will be updated when battle starts, but set initial position)
	call_deferred("_position_battle_view")

	_battle_view.battle_complete.connect(_on_battle_complete)
	_battle_view.ship_destroyed.connect(_on_ship_destroyed)
	_battle_view.expand_toggled.connect(_on_battle_view_expand_toggled)

func _position_battle_view() -> void:
	if _battle_view:
		var viewport_size = get_viewport_rect().size
		_battle_view.position = Vector2(
			viewport_size.x - 420,
			viewport_size.y - 300
		)
		_battle_view.size = Vector2(400, 280)

func _setup_planet_view() -> void:
	# Create planet detail view - positioned dynamically near focused planet
	_planet_view = FCWPlanetView.new()
	_planet_view.name = "PlanetView"
	_planet_view.visible = false
	_planet_view.custom_minimum_size = Vector2(280, 200)
	_planet_view.size = Vector2(280, 200)
	add_child(_planet_view)
	_planet_view.close_requested.connect(_on_planet_view_close)
	_planet_view.position_changed.connect(_on_planet_view_position_changed)

func _setup_zone_fallen_overlay() -> void:
	# Create dramatic full-screen overlay for zone fallen events
	_zone_fallen_overlay = PanelContainer.new()
	_zone_fallen_overlay.name = "ZoneFallenOverlay"
	_zone_fallen_overlay.visible = false

	# Semi-transparent dark background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.0, 0.0, 0.85)
	style.border_color = Color(0.8, 0.2, 0.2, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	_zone_fallen_overlay.add_theme_stylebox_override("panel", style)

	# Center the overlay
	_zone_fallen_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_zone_fallen_overlay.custom_minimum_size = Vector2(500, 200)

	# Container for content
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	_zone_fallen_overlay.add_child(vbox)

	# Main label - big dramatic text
	_zone_fallen_label = RichTextLabel.new()
	_zone_fallen_label.bbcode_enabled = true
	_zone_fallen_label.fit_content = true
	_zone_fallen_label.scroll_active = false
	_zone_fallen_label.custom_minimum_size = Vector2(480, 60)
	_zone_fallen_label.add_theme_font_size_override("normal_font_size", 32)
	vbox.add_child(_zone_fallen_label)

	# Sub label - lives lost
	_zone_fallen_sublabel = Label.new()
	_zone_fallen_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_fallen_sublabel.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	_zone_fallen_sublabel.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_zone_fallen_sublabel)

	# Continue button
	_zone_fallen_btn = Button.new()
	_zone_fallen_btn.text = "CONTINUE"
	_zone_fallen_btn.custom_minimum_size = Vector2(150, 40)
	_zone_fallen_btn.pressed.connect(_on_zone_fallen_continue)
	vbox.add_child(_zone_fallen_btn)

	# Center button
	var center_container = CenterContainer.new()
	vbox.remove_child(_zone_fallen_btn)
	center_container.add_child(_zone_fallen_btn)
	vbox.add_child(center_container)

	add_child(_zone_fallen_overlay)
	_zone_fallen_overlay.z_index = 200  # Above everything

func _show_zone_fallen_overlay(zone_id: int, lives_lost: int) -> void:
	# Position overlay in center of screen
	var viewport_size = get_viewport_rect().size
	_zone_fallen_overlay.position = Vector2(
		(viewport_size.x - 500) / 2,
		(viewport_size.y - 200) / 2
	)

	var zone_name = FCWTypes.get_zone_name(zone_id)

	# Dramatic message
	_zone_fallen_label.text = "[center][color=red][b]%s HAS FALLEN[/b][/color][/center]" % zone_name.to_upper()

	# Lives lost
	if lives_lost > 0:
		_zone_fallen_sublabel.text = "%s souls lost to the Herald" % FCWTypes.format_population(lives_lost)
	else:
		_zone_fallen_sublabel.text = "The Herald advances..."

	_zone_fallen_overlay.visible = true
	move_child(_zone_fallen_overlay, get_child_count() - 1)  # Bring to front

func _on_zone_fallen_continue() -> void:
	_zone_fallen_overlay.visible = false
	# Resume the game
	_set_paused(false)
	if _speed_index == 0:
		_speed_index = 2  # Default to normal
	speed_slider.value = _speed_index
	_sync_speed_display()

func _start_new_game() -> void:
	store.start_new_game()
	# Generate named ships for starting fleet
	_battle_system = FCWBattleSystem.new()
	_battle_system.generate_starting_fleet(store.get_fleet(), FCWTypes.ZoneId.EARTH)

func _process(delta: float) -> void:
	# Guard against store not being initialized yet
	if not store:
		return
	if store.is_game_over():
		return

	# AI-driven cinematic camera (runs even when paused for visual interest)
	if solar_map:
		solar_map.cinematic_update(delta)

	# Update planet view if visible
	if _planet_view and _planet_view.visible:
		_update_planet_view()

	# Handle planet view auto-close timer
	if _planet_view_close_timer > 0:
		_planet_view_close_timer -= delta
		if _planet_view_close_timer <= 0:
			_planet_view_close_timer = -1.0
			if _planet_view:
				_planet_view.hide_view()

	# Battle view runs in corner - no pause needed

	# Handle attack animation phase (but don't block game time!)
	if _is_in_attack_phase:
		_attack_phase_timer += delta
		if _attack_phase_timer >= ATTACK_PHASE_DURATION:
			_is_in_attack_phase = false
			solar_map.set_attacking(false)
			if _planet_view and _planet_view.visible:
				_schedule_planet_view_close(1.5)
		# Don't return here - let game time continue during battles!

	if _is_paused:
		return

	# === NEW TICK-BASED TIME SYSTEM ===
	# Time advances in discrete 1-hour ticks
	# Visuals interpolate between ticks for smoothness
	var ticks_per_second = TICKS_PER_SECOND[_speed_index]
	if ticks_per_second <= 0:
		return  # Paused

	# Accumulate time toward next tick
	_accumulated_time += delta * ticks_per_second

	# Process complete ticks
	while _accumulated_time >= 1.0:
		_accumulated_time -= 1.0
		_process_tick()

	# Calculate tick progress for interpolation (0.0 to 1.0)
	_tick_progress = _accumulated_time

	# Pass tick progress to solar map for interpolation
	if solar_map:
		solar_map.set_tick_progress(_tick_progress, store.get_prev_entity_positions(), store.get_prev_zone_positions())

	# Update header with time display
	_sync_header()

func _process_tick() -> void:
	## Called when a full hour tick completes
	## Dispatches to store which handles all game logic
	var old_week = store.get_current_week()

	# Dispatch the tick - this advances game_time by 1 hour
	store.dispatch_tick()

	var new_week = store.get_current_week()

	# On week boundary, run additional processing
	if new_week > old_week:
		_process_week_boundary()

func _process_week_boundary() -> void:
	## Called when crossing a week boundary
	## Handles AI, visuals, and any week-specific logic
	var week = store.get_turn()
	const PEACE_TURNS = 3

	# Track colony ships for visual spawning
	var colony_ships_before = store.get_colony_ships_in_transit().size()

	# PEACE PERIOD - First few turns are calm before the storm
	if week <= PEACE_TURNS:
		_process_peace_week(week)
		_spawn_visual_colony_ships(colony_ships_before)
		return

	# Run AI decisions if auto-play is enabled
	if _auto_play:
		_run_ai_turn()

	# Update narrative state based on game situation
	_update_narrative_state()

	# Check evacuation milestones
	solar_map.trigger_evacuation_milestone(store.get_lives_evacuated())

	# Check if combat will occur this turn
	var target = store.get_herald_target()
	var target_defense = store.get_zone_defense(target)
	var herald_strength = store.get_herald_strength()
	var zone_status = store.get_zone(target).get("status", 0)

	# Trigger battle view for ALL combat
	var should_show_battle = _show_battle_view and zone_status != FCWTypes.ZoneStatus.FALLEN

	if should_show_battle:
		var defending_ships = _battle_system.get_ships_at_zone(target)
		var herald_count = maxi(int(herald_strength / 15), 3)
		var will_hold = target_defense >= herald_strength and target_defense > 0
		var zone_name = FCWTypes.get_zone_name(target)

		if not _battle_view.visible:
			var viewport_size = get_viewport_rect().size
			_battle_view.position = Vector2(viewport_size.x - 420, viewport_size.y - 300)
			_battle_view.size = Vector2(400, 280)
			move_child(_battle_view, get_child_count() - 1)
			_battle_view.start_battle(zone_name, defending_ships, herald_count, will_hold)
		else:
			_spawn_cascading_battle_view(zone_name, defending_ships, herald_count, will_hold)

	# Start attack animation on galaxy map
	if target_defense < herald_strength * 2:
		_is_in_attack_phase = true
		_attack_phase_timer = 0.0
		solar_map.set_attacking(true)
		_show_planet_view_for_zone(target, true)

		var attack_intensity = clampi(int(herald_strength / 25), 3, 30)
		if target_defense < herald_strength:
			solar_map.spawn_mass_attack(target, attack_intensity + 10)
			solar_map.spawn_skirmish(target, -1, true, attack_intensity)
		else:
			solar_map.spawn_herald_attack_wave(target, mini(attack_intensity, 8))
			if attack_intensity > 5:
				solar_map.spawn_skirmish(target, -1, true, attack_intensity / 2)

	_spawn_visual_colony_ships(colony_ships_before)

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

	# Create auto-play button (on by default)
	auto_play_btn = Button.new()
	auto_play_btn.text = "🤖 AUTO ON"
	auto_play_btn.toggle_mode = true
	auto_play_btn.button_pressed = true  # Start enabled
	auto_play_btn.custom_minimum_size = Vector2(80, 30)
	var footer = $MainContainer/Footer
	footer.add_child(auto_play_btn)
	footer.move_child(auto_play_btn, 0)  # Put at start

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

	# Initialize speed multiplier
	solar_map.set_speed(TICKS_PER_SECOND[_speed_index])

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
	store.ship_completed.connect(_on_ship_completed)

	speed_slider.value_changed.connect(_on_speed_changed)
	pause_btn.pressed.connect(_on_pause_pressed)
	auto_play_btn.toggled.connect(_on_auto_play_toggled)
	main_menu_btn.pressed.connect(_on_main_menu)

	new_game_btn.pressed.connect(_on_new_game)
	menu_btn.pressed.connect(_on_main_menu)

	# Strategic command buttons
	go_dark_btn.pressed.connect(_on_go_dark_pressed)
	create_decoy_btn.pressed.connect(_on_create_decoy_pressed)
	max_evac_btn.pressed.connect(_on_max_evac_pressed)
	blockade_btn.pressed.connect(_on_blockade_pressed)

	# Entity route selection from solar map
	if solar_map:
		solar_map.entity_destination_selected.connect(_on_entity_destination_selected)

# ============================================================================
# UI SYNC
# ============================================================================

func _on_state_changed(_new_state: Dictionary) -> void:
	_sync_ui()
	_update_guidance()

func _sync_ui() -> void:
	# Guard against uninitialized nodes
	if not store or not is_inside_tree():
		return
	_sync_header()
	_sync_fleet()
	_sync_map()
	_sync_event_log()
	_sync_zone_detail()
	_sync_build_buttons()
	_sync_speed_display()

func _sync_header() -> void:
	if not store or not turn_label:
		return
	var week = store.get_current_week()
	const PEACE_TURNS = 3  # Must match fcw_reducer.gd

	# Format time display using new time system: "WEEK X, DAY Y - HH:00"
	var time_str = store.get_formatted_time()

	# Calculate threat level for header styling
	var threat_level = _calculate_threat_level()

	# During peace, show calm info; after detection, show threat info
	if week < PEACE_TURNS:
		turn_label.text = "%s | Solar System at Peace" % time_str
		lives_label.text = "CIVILIAN TRAFFIC: Normal"
		threat_label.text = "STATUS: All Clear"
		_apply_header_urgency(0)  # No urgency
	else:
		# === LEFT: Time display with Herald ETA in days ===
		var herald_eta_days = _calculate_herald_eta_days()
		var target = store.get_herald_target()
		var target_name = FCWTypes.get_zone_name(target)

		if herald_eta_days <= 0:
			turn_label.text = "%s | Herald at %s!" % [time_str, target_name]
		else:
			turn_label.text = "%s | Herald → %s: %dd" % [time_str, target_name, herald_eta_days]

		# === CENTER: Evacuation progress with tier ===
		var lives = store.get_lives_evacuated()
		var tier = FCWTypes.get_victory_tier(lives)
		var tier_name = FCWTypes.get_victory_tier_name(tier)
		lives_label.text = "EVAC: %s [%s]" % [FCWTypes.format_population(lives), tier_name]

		# === RIGHT: Threat level indicator ===
		var threat = store.get_herald_strength()
		var target_defense = store.get_zone_defense(target)

		var status_text: String
		if target == FCWTypes.ZoneId.EARTH:
			status_text = "EARTH THREATENED"
		elif target_defense >= threat * 1.2:
			status_text = "HOLDING"
		elif target_defense >= threat * 0.8:
			status_text = "CONTESTED"
		else:
			status_text = "FALLING"

		threat_label.text = "THREAT: %s | %s" % [_get_threat_level_name(threat_level), status_text]

		# Apply urgency styling to header
		_apply_header_urgency(threat_level)

## Calculate Herald ETA in days to current target
func _calculate_herald_eta_days() -> int:
	var transit = store.get_herald_transit()
	if transit.is_empty():
		return 0  # Already at target

	# Transit remaining is in weeks, convert to days
	var weeks_remaining = transit.get("turns_remaining", 0)
	return weeks_remaining * 7

## Calculate threat level (0-3) based on game state
func _calculate_threat_level() -> int:
	var target = store.get_herald_target()
	var herald_transit = store.get_herald_transit()
	var herald_strength = store.get_herald_strength()
	var target_defense = store.get_zone_defense(target)

	# Level 3: Earth is the target
	if target == FCWTypes.ZoneId.EARTH:
		return 3

	# Level 2: Herald is attacking an inhabited zone and we can't hold
	if herald_transit.is_empty() and target_defense < herald_strength * 0.8:
		return 2

	# Level 1: Herald is close (within 2 zones of Earth)
	var zones_from_earth = _zones_from_earth(target)
	if zones_from_earth <= 2:
		return 1

	return 0

## Get how many zones away from Earth a zone is
func _zones_from_earth(zone_id: int) -> int:
	match zone_id:
		FCWTypes.ZoneId.EARTH:
			return 0
		FCWTypes.ZoneId.MARS:
			return 1
		FCWTypes.ZoneId.ASTEROID_BELT, FCWTypes.ZoneId.JUPITER, FCWTypes.ZoneId.SATURN:
			return 2
		FCWTypes.ZoneId.KUIPER:
			return 3
		_:
			return 4

## Get threat level name
func _get_threat_level_name(level: int) -> String:
	match level:
		0:
			return "LOW"
		1:
			return "ELEVATED"
		2:
			return "HIGH"
		3:
			return "CRITICAL"
		_:
			return "UNKNOWN"

## Apply visual urgency to header based on threat level
func _apply_header_urgency(level: int) -> void:
	var header = $MainContainer/Header

	match level:
		0:  # Normal - standard colors
			turn_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			lives_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			threat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		1:  # Elevated - yellow tint
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
			lives_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
			threat_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		2:  # High - orange tint
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
			lives_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
			threat_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		3:  # Critical - red with pulse effect
			var pulse = sin(Time.get_ticks_msec() / 300.0) * 0.2 + 0.8
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.4 * pulse, 0.4 * pulse))
			lives_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
			threat_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _sync_fleet() -> void:
	if not store or not fleet_list:
		return
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

	# Show ships in transit
	var transit = store.get_fleets_in_transit()
	if not transit.is_empty():
		fleet_list.add_item("--- IN TRANSIT ---")
		for t in transit:
			var ship_name = FCWTypes.get_ship_name(t.ship_type)
			var dest_name = FCWTypes.get_zone_name(t.to_zone)
			fleet_list.add_item("%d %s → %s (%dw)" % [t.count, ship_name.substr(0, 4), dest_name.substr(0, 4), t.turns_remaining])

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
	if not store or not solar_map:
		return

	var state = store.get_state()

	# Build zone defenses dictionary
	var zone_defenses: Dictionary = {}
	for zone_id in state.zones:
		zone_defenses[zone_id] = store.get_zone_defense(zone_id)

	# Get fleets in transit for visualization
	var fleets_in_transit = store.get_fleets_in_transit()

	solar_map.update_state(state, zone_defenses, fleets_in_transit)
	solar_map.set_selected_zone(_selected_zone)

func _sync_event_log() -> void:
	if not store or not event_log:
		return
	var log = store.get_event_log()
	var text = ""
	var start = maxi(0, log.size() - 8)
	for i in range(start, log.size()):
		var entry = log[i]
		var prefix = "[color=red]▶[/color] " if entry.is_critical else "  "
		text += "%sW%d: %s\n" % [prefix, entry.turn, entry.message]

	event_log.text = text

func _sync_zone_detail() -> void:
	if not store or not zone_detail:
		return
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
	if not store or not build_buttons:
		return
	var capacity = store.get_production_capacity()
	var idx = 0
	for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.DREADNOUGHT]:
		if idx < build_buttons.get_child_count():
			var btn = build_buttons.get_child(idx) as Button
			btn.disabled = not store.can_afford_ship(ship_type) or capacity <= 0
		idx += 1

func _sync_speed_display() -> void:
	if not speed_label or not pause_btn:
		return
	speed_label.text = "Speed: %s" % SPEED_NAMES[_speed_index]
	pause_btn.text = "▶ PLAY" if _is_paused else "⏸ PAUSE"

# ============================================================================
# PLAYER GUIDANCE
# ============================================================================

func _update_guidance() -> void:
	if not store:
		return
	var state = store.get_state()
	var turn = state.turn
	const PEACE_TURNS = 3
	var text = ""

	# ========== PEACE PERIOD GUIDANCE ==========
	if turn < PEACE_TURNS:
		text += "[b][color=cyan]PEACE TIME - PREPARE FOR WAR[/color][/b]\n\n"
		text += "The solar system is at peace... for now.\n\n"
		text += "[color=yellow]WHAT'S COMING:[/color]\n"
		text += "• An unstoppable alien force - the Herald\n"
		text += "• Earth WILL fall. You cannot prevent this.\n"
		text += "• Your mission: EVACUATE as many civilians as possible\n\n"
		text += "[color=cyan]PREPARE NOW:[/color]\n"
		text += "• Build ships (Frigates are cheap, Carriers evacuate best)\n"
		text += "• Ships at frontier zones slow the Herald's advance\n"
		text += "• Ships at Earth evacuate civilians each turn\n"
		guidance_label.text = text
		return

	# ========== HERALD TRACKING (Top Priority) ==========
	text += _build_herald_tracking_text(state)
	text += "\n"

	# ========== ZONE SIGNATURES ==========
	text += _build_signature_list_text(state)
	text += "\n"

	# ========== EVACUATION PROGRESS ==========
	text += _build_evacuation_progress_text(state)

	guidance_label.text = text

func _build_herald_tracking_text(state: Dictionary) -> String:
	## Build Herald tracking section with position, target, and ETA
	var text = "[b]HERALD TRACKING[/b]\n"

	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var herald_transit = state.get("herald_transit", {})
	var zone_signatures = state.get("zone_signatures", {})

	# Current position
	var zone_name = FCWTypes.get_zone_name(herald_zone)
	var zone_status = state.zones.get(herald_zone, {}).get("status", FCWTypes.ZoneStatus.CONTROLLED)

	if not herald_transit.is_empty():
		# Herald is in transit
		var to_zone = herald_transit.get("to_zone", herald_zone)
		var turns_remaining = herald_transit.get("turns_remaining", 0)
		var to_name = FCWTypes.get_zone_name(to_zone)
		text += "Position: [color=orange]EN ROUTE[/color] → %s\n" % to_name
		text += "ETA: [color=yellow]%d days[/color]\n" % (turns_remaining * 7)
	elif zone_status == FCWTypes.ZoneStatus.UNDER_ATTACK:
		text += "Position: [color=red]ATTACKING %s[/color]\n" % zone_name.to_upper()
	else:
		text += "Position: %s\n" % zone_name

	# Next target prediction
	var next_target = _predict_herald_next_target(state)
	if next_target.zone_id >= 0:
		var next_name = FCWTypes.get_zone_name(next_target.zone_id)
		var next_sig = zone_signatures.get(next_target.zone_id, 0.0)
		var sig_percent = int(next_sig * 100)

		if next_target.is_skip:
			text += "Next: [color=red]%s (sig: %d%%) - SKIP![/color]\n" % [next_name, sig_percent]
		elif next_sig >= FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
			text += "Next: [color=orange]%s (sig: %d%%) - DRAWN[/color]\n" % [next_name, sig_percent]
		else:
			text += "Next: [color=gray]%s (default path)[/color]\n" % next_name

		# Show ETA to Earth
		var eta_to_earth = _calculate_eta_to_earth(state, herald_zone)
		if eta_to_earth > 0:
			var eta_color = "red" if eta_to_earth <= 14 else ("orange" if eta_to_earth <= 28 else "yellow")
			text += "Earth ETA: [color=%s]%d days[/color]\n" % [eta_color, eta_to_earth]

	return text

func _predict_herald_next_target(state: Dictionary) -> Dictionary:
	## Predict where Herald will go next based on signatures
	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var zone_signatures = state.get("zone_signatures", {})

	var adjacent = FCWTypes.get_zone_adjacent(herald_zone)
	var skip_targets = FCWTypes.get_zone_skip_targets(herald_zone)
	var default_next = FCWTypes.get_zone_default_next(herald_zone)

	# Check for skip targets first (high signature required)
	for zone_id in skip_targets:
		var zone_data = state.zones.get(zone_id, {})
		if zone_data.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue
		var sig = zone_signatures.get(zone_id, 0.0)
		if sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
			return {"zone_id": zone_id, "is_skip": true}

	# Find highest signature adjacent zone
	var highest_sig = -1.0
	var best_zone = -1
	for zone_id in adjacent:
		var zone_data = state.zones.get(zone_id, {})
		if zone_data.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue
		var sig = zone_signatures.get(zone_id, 0.0)
		if sig > highest_sig:
			highest_sig = sig
			best_zone = zone_id

	# If no strong signal, use default
	if highest_sig < FCWTypes.HERALD_MIN_SIG_TO_ATTRACT and default_next >= 0:
		var zone_data = state.zones.get(default_next, {})
		if zone_data.get("status", 0) != FCWTypes.ZoneStatus.FALLEN:
			return {"zone_id": default_next, "is_skip": false}

	return {"zone_id": best_zone, "is_skip": false}

func _calculate_eta_to_earth(state: Dictionary, from_zone: int) -> int:
	## Calculate estimated days until Herald reaches Earth from given zone
	if from_zone == FCWTypes.ZoneId.EARTH:
		return 0

	# Simple path calculation following default route
	var current = from_zone
	var total_weeks = 0
	var visited = {}

	while current != FCWTypes.ZoneId.EARTH and total_weeks < 100:
		if visited.has(current):
			break
		visited[current] = true

		var next = FCWTypes.get_zone_default_next(current)
		if next < 0:
			break

		total_weeks += FCWTypes.get_travel_time(current, next)
		total_weeks += 1  # Attack time
		current = next

	return total_weeks * 7

func _build_signature_list_text(state: Dictionary) -> String:
	## Build zone signature list for Herald targeting awareness
	var text = "[b]ZONE SIGNATURES[/b]\n"
	var zone_signatures = state.get("zone_signatures", {})
	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)

	# Get reachable zones from Herald's position
	var reachable = FCWTypes.get_all_reachable_zones(herald_zone)

	# Sort zones by signature (highest first)
	var zone_list = []
	for zone_id in FCWTypes.ZoneId.values():
		var zone_data = state.zones.get(zone_id, {})
		if zone_data.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue
		zone_list.append({"id": zone_id, "sig": zone_signatures.get(zone_id, 0.0)})

	zone_list.sort_custom(func(a, b): return a.sig > b.sig)

	for zone_info in zone_list:
		var zone_id = zone_info.id
		var sig = zone_info.sig
		var zone_name = FCWTypes.get_zone_name(zone_id)

		# Build visual bar (10 chars)
		var bar_filled = int(sig * 10)
		var bar_empty = 10 - bar_filled
		var bar_str = ""
		for _i in range(bar_filled):
			bar_str += "█"
		for _i in range(bar_empty):
			bar_str += "░"

		# Color based on danger level
		var color = _get_signature_bbcode_color(sig)
		var percent = "%2d%%" % int(sig * 100)

		# Warning indicators
		var warning = ""
		if zone_id in reachable:
			if sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
				warning = " [color=red]⚠ SKIP TARGET[/color]"
			elif sig >= FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
				warning = " [color=orange]← DRAWING[/color]"

		text += "[color=%s]%s[/color] %s %s%s\n" % [color, zone_name.substr(0, 8).rpad(8), bar_str, percent, warning]

	return text

func _get_signature_bbcode_color(sig: float) -> String:
	## Get BBCode color name for signature level
	if sig >= 0.6:
		return "red"
	elif sig >= 0.4:
		return "orange"
	elif sig >= 0.2:
		return "yellow"
	elif sig >= 0.1:
		return "#99cc66"  # Yellow-green
	else:
		return "#66aa66"  # Green

func _build_evacuation_progress_text(state: Dictionary) -> String:
	## Build evacuation progress section with tier advancement
	var text = "[b]EVACUATION[/b]\n"

	var lives = state.get("lives_evacuated", 0)
	var tier = FCWTypes.get_victory_tier(lives)
	var tier_name = FCWTypes.get_victory_tier_name(tier)

	# Tier thresholds
	var tier_thresholds = {
		FCWTypes.VictoryTier.ANNIHILATION: {"next": "TRAGIC", "goal": 5_000_000},
		FCWTypes.VictoryTier.TRAGIC: {"next": "PYRRHIC", "goal": 15_000_000},
		FCWTypes.VictoryTier.PYRRHIC: {"next": "HEROIC", "goal": 40_000_000},
		FCWTypes.VictoryTier.HEROIC: {"next": "LEGENDARY", "goal": 80_000_000},
		FCWTypes.VictoryTier.LEGENDARY: {"next": "LEGENDARY+", "goal": 150_000_000},
	}

	# Get tier color
	var tier_color = "gray"
	match tier:
		FCWTypes.VictoryTier.LEGENDARY: tier_color = "#cc66ff"  # Purple
		FCWTypes.VictoryTier.HEROIC: tier_color = "#ffcc00"     # Gold
		FCWTypes.VictoryTier.PYRRHIC: tier_color = "#cccccc"    # Silver
		FCWTypes.VictoryTier.TRAGIC: tier_color = "#cc9966"     # Bronze
		_: tier_color = "#666666"

	text += "Saved: [color=%s]%s[/color] [[color=%s]%s[/color]]\n" % [
		tier_color, FCWTypes.format_population(lives), tier_color, tier_name]

	# Progress to next tier
	var tier_info = tier_thresholds.get(tier, {})
	if not tier_info.is_empty():
		var goal = tier_info.goal
		var next_name = tier_info.next
		var needed = goal - lives
		var progress = float(lives) / float(goal)

		# Build progress bar (15 chars)
		var bar_filled = int(progress * 15)
		var bar_empty = 15 - bar_filled
		var bar_str = ""
		for _i in range(bar_filled):
			bar_str += "█"
		for _i in range(bar_empty):
			bar_str += "░"

		text += "[%s] → %s\n" % [bar_str, next_name]
		text += "Need: %s more\n" % FCWTypes.format_population(needed)

	return text

# ============================================================================
# STRATEGIC COMMANDS - Quick action buttons for common strategies
# ============================================================================

func _on_go_dark_pressed() -> void:
	## GO DARK: Cancel all fleet movement to minimize signatures
	## Strategy: Reduce detection by halting all burns
	var state = store.get_state()
	var fleets_in_transit = state.get("fleets_in_transit", [])

	if fleets_in_transit.is_empty():
		_add_log_entry("GO DARK: No fleets in transit to cancel.")
		return

	# Cancel all transits by recalling ships
	# Note: This is simplified - in reality we'd need a proper cancel action
	var cancelled = 0
	for transit in fleets_in_transit:
		# Ships in transit can't be instantly recalled, but we log the order
		cancelled += transit.get("count", 1)

	_add_log_entry("[color=cyan]GO DARK ORDER ISSUED[/color]: Fleet movement halted. Signatures will decay over time.")
	_add_log_entry("Note: Ships currently in transit cannot be recalled mid-flight.")
	_sync_ui()

func _on_create_decoy_pressed() -> void:
	## CREATE DECOY: Send frigates to Saturn to raise its signature
	## Strategy: Draw Herald away from Earth/Mars by creating a false target
	var state = store.get_state()
	var free_frigates = store.get_free_ships(FCWTypes.ShipType.FRIGATE)

	if free_frigates < 3:
		_add_log_entry("DECOY FAILED: Need at least 3 free frigates (have %d)." % free_frigates)
		return

	# Check if Saturn is still controlled
	var saturn_zone = state.zones.get(FCWTypes.ZoneId.SATURN, {})
	if saturn_zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
		_add_log_entry("DECOY FAILED: Saturn has fallen.")
		return

	# Send 3 frigates to Saturn
	store.dispatch_assign_fleet(FCWTypes.ZoneId.SATURN, FCWTypes.ShipType.FRIGATE, 3)

	_add_log_entry("[color=orange]DECOY ORDER ISSUED[/color]: 3 Frigates burning to Saturn.")
	_add_log_entry("This will raise Saturn's signature and may draw the Herald there.")
	_sync_ui()

func _on_max_evac_pressed() -> void:
	## MAX EVAC: Move all available carriers to Earth for maximum evacuation
	## Strategy: Prioritize saving lives when Herald is close
	var state = store.get_state()

	# Check if Earth is still controlled
	var earth_zone = state.zones.get(FCWTypes.ZoneId.EARTH, {})
	if earth_zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
		_add_log_entry("MAX EVAC FAILED: Earth has fallen.")
		return

	# Find carriers not at Earth
	var moved_carriers = 0
	for zone_id in FCWTypes.ZoneId.values():
		if zone_id == FCWTypes.ZoneId.EARTH:
			continue

		var zone = state.zones.get(zone_id, {})
		if zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue

		var assigned = zone.get("assigned_fleet", {})
		var carriers = assigned.get(FCWTypes.ShipType.CARRIER, 0)
		if carriers > 0:
			# Recall to reserve (-1) then assign to Earth
			store.dispatch_recall_fleet(zone_id, -1, FCWTypes.ShipType.CARRIER, carriers)
			store.dispatch_assign_fleet(FCWTypes.ZoneId.EARTH, FCWTypes.ShipType.CARRIER, carriers)
			moved_carriers += carriers

	if moved_carriers > 0:
		_add_log_entry("[color=green]MAX EVAC ORDER ISSUED[/color]: %d Carriers redirecting to Earth." % moved_carriers)
		_add_log_entry("Evacuation capacity maximized. Save as many as possible.")
	else:
		var earth_carriers = earth_zone.get("assigned_fleet", {}).get(FCWTypes.ShipType.CARRIER, 0)
		_add_log_entry("MAX EVAC: All carriers already at Earth (%d stationed)." % earth_carriers)

	_sync_ui()

func _on_blockade_pressed() -> void:
	## BLOCKADE: Concentrate all combat ships at Mars for maximum defense
	## Strategy: Hold Mars as long as possible to buy evacuation time
	var state = store.get_state()

	# Check if Mars is still controlled
	var mars_zone = state.zones.get(FCWTypes.ZoneId.MARS, {})
	if mars_zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
		_add_log_entry("BLOCKADE FAILED: Mars has fallen.")
		return

	# Move all combat ships (Cruisers, Dreadnoughts) to Mars
	var moved_ships = 0
	var ship_types_to_move = [FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.DREADNOUGHT, FCWTypes.ShipType.FRIGATE]

	for zone_id in FCWTypes.ZoneId.values():
		if zone_id == FCWTypes.ZoneId.MARS:
			continue

		var zone = state.zones.get(zone_id, {})
		if zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue

		var assigned = zone.get("assigned_fleet", {})
		for ship_type in ship_types_to_move:
			var count = assigned.get(ship_type, 0)
			if count > 0:
				# Recall to reserve (-1) then assign to Mars
				store.dispatch_recall_fleet(zone_id, -1, ship_type, count)
				store.dispatch_assign_fleet(FCWTypes.ZoneId.MARS, ship_type, count)
				moved_ships += count

	if moved_ships > 0:
		_add_log_entry("[color=red]BLOCKADE ORDER ISSUED[/color]: %d ships converging on Mars." % moved_ships)
		_add_log_entry("Mars defense maximized. This is our Thermopylae.")
	else:
		var mars_defense = store.get_zone_defense(FCWTypes.ZoneId.MARS)
		_add_log_entry("BLOCKADE: All combat ships already at Mars (DEF: %d)." % mars_defense)

	_sync_ui()

func _add_log_entry(message: String) -> void:
	## Add a message to the event log
	var state = store.get_state()
	var turn = state.get("turn", 1)
	# Direct log update without going through store (visual feedback only)
	var log_text = "[color=gray]W%d:[/color] %s" % [turn, message]
	if event_log:
		event_log.text = log_text + "\n" + event_log.text

# ============================================================================
# ACTIONS
# ============================================================================

func _process_week_end() -> void:
	## DEPRECATED: Use _process_week_boundary() instead
	## This was the old week-end handler that called dispatch_end_turn()
	## Now replaced by tick-based system where _process_tick() handles dispatch
	## and _process_week_boundary() handles visual/AI effects
	var week = store.get_turn()
	const PEACE_TURNS = 3  # Must match fcw_reducer.gd

	# Track colony ships for visual spawning (ships entering transit, not arriving)
	var colony_ships_before = store.get_colony_ships_in_transit().size()

	# PEACE PERIOD - First few turns are calm before the storm
	if week <= PEACE_TURNS:
		_process_peace_week(week)
		store.dispatch_end_turn()
		# Spawn visual colony ships for any that entered transit
		_spawn_visual_colony_ships(colony_ships_before)
		return

	# Run AI decisions if auto-play is enabled
	if _auto_play:
		_run_ai_turn()

	# Update narrative state based on game situation
	_update_narrative_state()

	# Check evacuation milestones
	solar_map.trigger_evacuation_milestone(store.get_lives_evacuated())

	# Check if combat will occur this turn
	var target = store.get_herald_target()
	var target_defense = store.get_zone_defense(target)
	var herald_strength = store.get_herald_strength()
	var zone_status = store.get_zone(target).get("status", 0)

	# Trigger battle view for ALL combat (show every battle!)
	var should_show_battle = _show_battle_view and zone_status != FCWTypes.ZoneStatus.FALLEN

	if should_show_battle:
		# Get ships at target zone for battle view
		var defending_ships = _battle_system.get_ships_at_zone(target)
		var herald_count = maxi(int(herald_strength / 15), 3)  # At least 3 herald ships

		# Show battle even if no defenders (one-sided attack)
		var will_hold = target_defense >= herald_strength and target_defense > 0
		var zone_name = FCWTypes.get_zone_name(target)

		# Use primary view if available, otherwise spawn cascading view
		if not _battle_view.visible:
			# Position battle view in bottom-right corner
			var viewport_size = get_viewport_rect().size
			_battle_view.position = Vector2(
				viewport_size.x - 420,
				viewport_size.y - 300
			)
			_battle_view.size = Vector2(400, 280)  # Ensure size is set

			# Move to top of z-order to ensure visibility
			move_child(_battle_view, get_child_count() - 1)

			_battle_view.start_battle(zone_name, defending_ships, herald_count, will_hold)
		else:
			# Primary view busy, spawn a cascading view
			_spawn_cascading_battle_view(zone_name, defending_ships, herald_count, will_hold)

	# Start attack animation on galaxy map
	if target_defense < herald_strength * 2:
		_is_in_attack_phase = true
		_attack_phase_timer = 0.0
		solar_map.set_attacking(true)

		# Show planet view window (picture-in-picture) for the attack
		_show_planet_view_for_zone(target, true)

		# Spawn Herald attack waves on the solar map
		var attack_intensity = int(herald_strength / 25)  # 2-50+ ships based on strength
		attack_intensity = clampi(attack_intensity, 3, 30)

		if target_defense < herald_strength:
			# MASSIVE attack - zone will likely fall
			solar_map.spawn_mass_attack(target, attack_intensity + 10)
			# Start skirmish at staging areas
			solar_map.spawn_skirmish(target, -1, true, attack_intensity)
		else:
			# Standard attack wave
			solar_map.spawn_herald_attack_wave(target, mini(attack_intensity, 8))
			# Smaller skirmish
			if attack_intensity > 5:
				solar_map.spawn_skirmish(target, -1, true, attack_intensity / 2)

	store.dispatch_end_turn()

	# Spawn visual colony ships for any that entered transit this turn
	_spawn_visual_colony_ships(colony_ships_before)

func _spawn_visual_colony_ships(ships_before: int) -> void:
	## Spawn visual colony ships on the solar map for newly departed ships
	## Reads from game state to find ships that just entered transit
	if not solar_map:
		return

	var current_ships = store.get_colony_ships_in_transit()
	var new_ship_count = current_ships.size() - ships_before

	# Spawn visual ships for each new ship (the last N ships are new)
	if new_ship_count > 0:
		# Get the newly spawned ships (they're at the end of the array)
		var start_idx = maxi(0, current_ships.size() - new_ship_count)
		for i in range(start_idx, current_ships.size()):
			var ship_data = current_ships[i]
			solar_map.spawn_colony_ship_from_data(ship_data)

	# Update solar map with intercepted count for display
	solar_map.set_lives_intercepted(store.get_lives_intercepted())

func _process_peace_week(week: int) -> void:
	## Handle peaceful weeks before the Herald attacks
	## Show civilian life, build anticipation, introduce the world

	# Set peaceful narrative state
	solar_map.set_narrative_state(0)  # Peace

	# Peace-time transmissions that tell a story
	match week:
		1:
			# Opening - establish the world
			solar_map.spawn_transmission(
				"Sol Traffic Control",
				"All lanes clear. Civilian traffic proceeding normally across the solar system.",
				0
			)
			_add_to_event_log("Week 1: Solar system at peace", false)

		2:
			# Hint at what's coming
			solar_map.spawn_transmission(
				"Deep Space Array",
				"Long-range sensors detecting anomalous readings beyond the Kuiper Belt. Probably nothing.",
				1
			)
			_add_to_event_log("Week 2: Anomalous readings detected", false)

		3:
			# The calm before the storm
			solar_map.spawn_transmission(
				"Earth Command",
				"All defense stations: Unidentified objects approaching. This is not a drill. Repeat, not a drill.",
				2
			)
			_add_to_event_log("Week 3: ALERT - Unknown contact approaching!", true)

	# AI can still build ships during peace (preparation)
	if _auto_play:
		_ai_build_ships(week, 50)  # Low herald strength estimate for early building

func _run_ai_turn() -> void:
	## STRATEGIC AI - Phase-adaptive with action evaluation
	## Uses FCWStateEvaluator for game phase detection and action ranking
	## Uses FCWActionEnumerator for valid action discovery
	##
	## Strategy by Phase:
	## - EARLY: Build fleet aggressively, minimize detection signature
	## - MID: Mars blockade + start evacuation, balanced defense
	## - LATE: Maximize evacuation, sacrifice outer zones
	## - ENDGAME: Pure evacuation, all ships protect transports

	var state = store.get_state()
	var phase = FCWStateEvaluator.get_game_phase(state)

	# Phase-adaptive strategy
	match phase:
		FCWStateEvaluator.GamePhase.EARLY:
			_ai_early_game(state)
		FCWStateEvaluator.GamePhase.MID:
			_ai_mid_game(state)
		FCWStateEvaluator.GamePhase.LATE:
			_ai_late_game(state)
		FCWStateEvaluator.GamePhase.ENDGAME:
			_ai_endgame(state)

func _ai_early_game(state: Dictionary) -> void:
	## EARLY PHASE: Herald at Kuiper/outer zones
	## STRATEGY: Build carriers (for evacuation) + create decoy at Saturn
	## Goal: Lure Herald toward Saturn, away from default Jupiter path
	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)

	# Build carriers first (8x evacuation multiplier!)
	_ai_build_priority_ships(state, [FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.CRUISER])

	# Create decoy at Saturn to lure Herald away from Jupiter→Mars path
	# Send a few frigates to burn visibly (high signature)
	if herald_zone == FCWTypes.ZoneId.KUIPER:
		var available = FCWReducer.get_available_ships(state)
		var frigates = available.get(FCWTypes.ShipType.FRIGATE, 0)
		if frigates >= 3:
			# Send decoy fleet to Saturn (creates burn signature)
			store.dispatch_assign_fleet(FCWTypes.ZoneId.SATURN, FCWTypes.ShipType.FRIGATE, 3)
			_log_ai_action("DECOY: Sending frigates to Saturn to create detection signature")

func _ai_mid_game(state: Dictionary) -> void:
	## MID PHASE: Herald at Jupiter/Saturn/Asteroid Belt
	## STRATEGY: Maintain decoy at Saturn, keep Mars DARK, start quiet evac
	## Goal: Herald follows decoy to Saturn while we evacuate quietly
	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.JUPITER)
	var sigs = state.get("zone_signatures", {})
	var mars_sig = sigs.get(FCWTypes.ZoneId.MARS, 0.0)
	var saturn_sig = sigs.get(FCWTypes.ZoneId.SATURN, 0.0)

	# Keep building carriers
	_ai_build_priority_ships(state, [FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.CRUISER])

	# Reinforce Saturn decoy if signature is dropping
	if saturn_sig < 0.3 and herald_zone != FCWTypes.ZoneId.SATURN:
		var available = FCWReducer.get_available_ships(state)
		var frigates = available.get(FCWTypes.ShipType.FRIGATE, 0)
		if frigates >= 2:
			store.dispatch_assign_fleet(FCWTypes.ZoneId.SATURN, FCWTypes.ShipType.FRIGATE, 2)
			_log_ai_action("DECOY: Reinforcing Saturn signature (%.0f%% → target 30%%+)" % [saturn_sig * 100])

	# WARNING: If Mars signature is rising, we need to go dark there
	if mars_sig > 0.2:
		_log_ai_action("WARNING: Mars signature at %.0f%% - reducing activity!" % [mars_sig * 100])
		# Don't send anything to Mars - let it go dark

	# Start quiet evacuation (carriers at Earth evacuate automatically)
	_ai_evacuation_fleet()

	# Only defend if Herald is at our decoy (sacrifice it to buy time)
	if herald_zone == FCWTypes.ZoneId.SATURN:
		_log_ai_action("SACRIFICE: Herald attacking Saturn decoy - buying time for evacuation")

func _ai_late_game(state: Dictionary) -> void:
	## LATE PHASE: Herald at Mars or approaching Earth
	## STRATEGY: Maximum evacuation, sacrifice outer zones, blockade Mars
	## Goal: Delay Herald at Mars while transports escape
	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.MARS)
	var herald_strength = state.get("herald_strength", 100)

	# Still build carriers if possible
	_ai_build_priority_ships(state, [FCWTypes.ShipType.CARRIER])

	# Maximum evacuation effort
	_ai_evacuation_fleet()

	# If Herald is at Mars, establish blockade to buy time
	if herald_zone == FCWTypes.ZoneId.MARS:
		var mars_defense = store.get_zone_defense(FCWTypes.ZoneId.MARS)
		if mars_defense < herald_strength:
			# Send combat ships to Mars (this will draw Herald but buys evac time)
			_ai_establish_blockade(FCWTypes.ZoneId.MARS)
			_log_ai_action("BLOCKADE: Reinforcing Mars to delay Herald - every day counts!")

	# Recall all ships from fallen/outer zones to Earth
	_ai_redistribute_fleet(herald_zone)

func _ai_endgame(state: Dictionary) -> void:
	## ENDGAME PHASE: Earth directly threatened
	## STRATEGY: Pure evacuation, every transport counts
	## Goal: Get as many souls out as possible before the end
	var herald_strength = state.get("herald_strength", 100)

	_log_ai_action("ENDGAME: Earth under threat - maximum evacuation priority!")

	# All carriers to Earth for evacuation
	_ai_evacuation_fleet()

	# Bring all remaining ships to protect transports
	var earth_defense = store.get_zone_defense(FCWTypes.ZoneId.EARTH)
	if earth_defense < herald_strength:
		_ai_emergency_response(FCWTypes.ZoneId.EARTH, herald_strength - earth_defense)

	# Pull everything from everywhere
	_ai_redistribute_fleet(FCWTypes.ZoneId.EARTH)

func _ai_build_priority_ships(state: Dictionary, priority_types: Array) -> void:
	## Build ships in priority order (carriers first for evacuation!)
	var capacity = store.get_production_capacity()
	if capacity <= 0:
		return

	for ship_type in priority_types:
		if capacity <= 0:
			break
		if FCWReducer.can_afford_ship(state, ship_type):
			store.dispatch_build_ship(ship_type)
			capacity -= 1
			state = store.get_state()  # Refresh state after build

	# Fill remaining capacity with whatever we can afford
	if capacity > 0:
		_execute_ranked_build_actions(state)

func _log_ai_action(message: String) -> void:
	## Log AI strategic decisions for player visibility
	var state = store.get_state()
	store._state.event_log.append(FCWTypes.create_log_entry(
		state.turn,
		"[AI] " + message,
		false
	))
	store.state_changed.emit(store._state)

func _execute_ranked_build_actions(state: Dictionary) -> void:
	## Use action enumeration + evaluation for ship building
	var capacity = store.get_production_capacity()
	if capacity <= 0:
		return

	# Get all valid build actions
	var all_actions = FCWActionEnumerator.get_valid_actions(state)
	var build_actions = all_actions.filter(func(a): return a.get("type") == FCWReducer.ActionType.BUILD_SHIP)

	if build_actions.is_empty():
		return

	# Rank by state evaluation
	var ranked = FCWStateEvaluator.rank_actions(state, build_actions)

	# Execute top actions within capacity
	var built = 0
	for entry in ranked:
		if built >= capacity:
			break
		var action = entry.action
		var ship_type = action.get("ship_type", 0)
		store.dispatch_build_ship(ship_type)
		built += 1

		# Log significant builds
		if ship_type == FCWTypes.ShipType.DREADNOUGHT:
			_add_to_event_log("Dreadnought commissioned for defense", false)
		elif ship_type == FCWTypes.ShipType.CARRIER:
			_add_to_event_log("Carrier commissioned for evacuation", false)

func _ai_build_ships(_turn: int, herald_strength: int) -> void:
	## Need-based ship building: analyze strategic situation and build accordingly
	var capacity = store.get_production_capacity()
	if capacity <= 0:
		return

	# Calculate strategic needs
	var target = store.get_herald_target()
	var target_defense = store.get_zone_defense(target)
	var total_fleet_power = store.get_total_fleet_strength()

	# Calculate defense deficit: how much more power do we need?
	var defense_deficit = herald_strength * 1.3 - target_defense
	var overall_deficit = herald_strength * 2.0 - total_fleet_power  # Want 2x Herald strength overall

	# Calculate evacuation capacity at Earth
	var earth_zone = store.get_zone(FCWTypes.ZoneId.EARTH)
	var earth_fleet = earth_zone.get("assigned_fleet", {}) if earth_zone else {}
	var carrier_count = earth_fleet.get(FCWTypes.ShipType.CARRIER, 0)
	var fleet_carriers = store.get_fleet().get(FCWTypes.ShipType.CARRIER, 0)
	var total_carriers = carrier_count  # Carriers at Earth

	# Target: 1 carrier per 10M population remaining (very rough)
	var earth_pop = earth_zone.get("population", 0) if earth_zone else 0
	var target_carriers = ceili(float(earth_pop) / 10_000_000.0)
	var carrier_deficit = target_carriers - fleet_carriers  # Total carriers owned, not just at Earth

	# Estimate turns until Earth is reached
	var eta = store.estimate_turns_until_earth()

	while capacity > 0:
		var built = false

		# PRIORITY 1: Urgent defense need - dreadnoughts for heavy firepower
		if defense_deficit > 200 and store.can_afford_ship(FCWTypes.ShipType.DREADNOUGHT):
			store.dispatch_build_ship(FCWTypes.ShipType.DREADNOUGHT)
			defense_deficit -= FCWTypes.get_ship_combat_power(FCWTypes.ShipType.DREADNOUGHT)
			_add_to_event_log("Dreadnought commissioned - urgent defense!", false)
			built = true

		# PRIORITY 2: Evacuation capacity - carriers save lives
		elif carrier_deficit > 0 and store.can_afford_ship(FCWTypes.ShipType.CARRIER):
			store.dispatch_build_ship(FCWTypes.ShipType.CARRIER)
			carrier_deficit -= 1
			built = true

		# PRIORITY 3: Moderate defense need - cruisers for balanced power
		elif defense_deficit > 50 and store.can_afford_ship(FCWTypes.ShipType.CRUISER):
			store.dispatch_build_ship(FCWTypes.ShipType.CRUISER)
			defense_deficit -= FCWTypes.get_ship_combat_power(FCWTypes.ShipType.CRUISER)
			built = true

		# PRIORITY 4: Late game heavy investment - dreadnoughts if herald is strong
		elif herald_strength > 400 and overall_deficit > 0 and store.can_afford_ship(FCWTypes.ShipType.DREADNOUGHT):
			store.dispatch_build_ship(FCWTypes.ShipType.DREADNOUGHT)
			overall_deficit -= FCWTypes.get_ship_combat_power(FCWTypes.ShipType.DREADNOUGHT)
			built = true

		# PRIORITY 5: Build up fleet reserves - cruisers preferred
		elif overall_deficit > 100 and store.can_afford_ship(FCWTypes.ShipType.CRUISER):
			store.dispatch_build_ship(FCWTypes.ShipType.CRUISER)
			overall_deficit -= FCWTypes.get_ship_combat_power(FCWTypes.ShipType.CRUISER)
			built = true

		# PRIORITY 6: Cheap frigates to fill gaps
		elif overall_deficit > 0 and store.can_afford_ship(FCWTypes.ShipType.FRIGATE):
			store.dispatch_build_ship(FCWTypes.ShipType.FRIGATE)
			overall_deficit -= FCWTypes.get_ship_combat_power(FCWTypes.ShipType.FRIGATE)
			built = true

		# PRIORITY 7: Always build something if we can afford frigates
		elif store.can_afford_ship(FCWTypes.ShipType.FRIGATE):
			store.dispatch_build_ship(FCWTypes.ShipType.FRIGATE)
			built = true

		if not built:
			break
		capacity = store.get_production_capacity()

func _ai_emergency_response(zone_id: int, deficit: int) -> void:
	## SCRAMBLE! Pull ships from everywhere to save the zone
	## Uses recall_fleet to actually move ships from other zones
	_add_to_event_log("⚠ EMERGENCY: Scrambling all available ships to %s!" % FCWTypes.get_zone_name(zone_id), true)

	var power_gathered = 0
	var total_ships_scrambled = 0

	# STEP 1: Send all available ships first (fastest response)
	var available = store.get_available_ships()
	for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.DREADNOUGHT]:
		if power_gathered >= deficit:
			break
		var avail_count = available.get(ship_type, 0)
		if avail_count > 0:
			var ship_power = FCWTypes.get_ship_combat_power(ship_type)
			var to_send = mini(avail_count, ceili(float(deficit - power_gathered) / ship_power))

			# Game state handles visualization via _draw_fleets_in_transit
			store.dispatch_assign_fleet(zone_id, ship_type, to_send)
			if _battle_system:
				_battle_system.assign_ships_to_zone(FCWTypes.ZoneId.EARTH, zone_id, ship_type, to_send)
			power_gathered += ship_power * to_send
			total_ships_scrambled += to_send

	# STEP 2: Pull ships from other zones if still not enough
	if power_gathered < deficit:
		# Find donor zones (not the target, not Earth, not fallen)
		var donor_zones: Array = []
		for zid in FCWTypes.ZoneId.values():
			if zid == zone_id or zid == FCWTypes.ZoneId.EARTH:
				continue
			var zone = store.get_zone(zid)
			if zone.status != FCWTypes.ZoneStatus.CONTROLLED:
				continue
			var zone_fleet = zone.get("assigned_fleet", {})
			var has_ships = false
			for st in zone_fleet:
				if zone_fleet[st] > 0:
					has_ships = true
					break
			if has_ships:
				donor_zones.append(zid)

		# Pull ships from donor zones using recall_fleet
		for donor_id in donor_zones:
			if power_gathered >= deficit:
				break

			var donor_zone = store.get_zone(donor_id)
			var donor_fleet = donor_zone.get("assigned_fleet", {})

			# Send combat ships (leave carriers for evacuation)
			for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.DREADNOUGHT]:
				if power_gathered >= deficit:
					break
				var count = donor_fleet.get(ship_type, 0)
				if count <= 0:
					continue

				var ships_to_send = mini(count, 5)  # Send up to 5 at a time in emergency
				var power = FCWTypes.get_ship_combat_power(ship_type) * ships_to_send

				# Actually recall the ships from the donor zone to the target
				# Game state handles visualization via entities or fleets_in_transit
				store.dispatch_recall_fleet(donor_id, zone_id, ship_type, ships_to_send)

				if _battle_system:
					_battle_system.assign_ships_to_zone(donor_id, zone_id, ship_type, ships_to_send)

				power_gathered += power
				total_ships_scrambled += ships_to_send

	if total_ships_scrambled > 0:
		_add_to_event_log("SCRAMBLE COMPLETE: %d ships en route to %s" % [
			total_ships_scrambled, FCWTypes.get_zone_name(zone_id)
		], true)

func _ai_reinforce_zone(zone_id: int, deficit: int) -> void:
	## Standard reinforcement - send available ships
	var available = store.get_available_ships()
	var total_ships_sent = 0
	var zone_name = FCWTypes.get_zone_name(zone_id)

	for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.DREADNOUGHT]:
		if deficit <= 0:
			break
		var avail_count = available.get(ship_type, 0)
		if avail_count > 0:
			var ship_power = FCWTypes.get_ship_combat_power(ship_type)
			var ships_to_send = mini(avail_count, ceili(float(deficit) / ship_power))
			if ships_to_send > 0:
				# Game state handles visualization via _draw_fleets_in_transit
				store.dispatch_assign_fleet(zone_id, ship_type, ships_to_send)
				if _battle_system:
					_battle_system.assign_ships_to_zone(FCWTypes.ZoneId.EARTH, zone_id, ship_type, ships_to_send)
				deficit -= ships_to_send * ship_power
				available[ship_type] = avail_count - ships_to_send
				total_ships_sent += ships_to_send

	if total_ships_sent > 0:
		_add_to_event_log("DEPLOYING %d ships to %s" % [total_ships_sent, zone_name], false)

func _ai_establish_blockade(zone_id: int) -> void:
	## Create a defensive line at a chokepoint (usually Mars)
	var current_defense = store.get_zone_defense(zone_id)
	var herald_strength = store.get_herald_strength()
	var zone_name = FCWTypes.get_zone_name(zone_id)

	# Want 50% of herald strength as blockade
	var blockade_target = int(herald_strength * 0.5)
	if current_defense >= blockade_target:
		return  # Blockade already established

	var deficit = blockade_target - current_defense
	var available = store.get_available_ships()
	var total_ships_sent = 0

	# Prefer cruisers and dreadnoughts for blockade (staying power)
	for ship_type in [FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.DREADNOUGHT, FCWTypes.ShipType.FRIGATE]:
		if deficit <= 0:
			break
		var avail_count = available.get(ship_type, 0)
		# Only send half of available to blockade (keep reserves)
		avail_count = avail_count / 2
		if avail_count > 0:
			var ship_power = FCWTypes.get_ship_combat_power(ship_type)
			var ships_to_send = mini(avail_count, ceili(float(deficit) / ship_power))
			if ships_to_send > 0:
				# Game state handles visualization via _draw_fleets_in_transit
				store.dispatch_assign_fleet(zone_id, ship_type, ships_to_send)
				if _battle_system:
					_battle_system.assign_ships_to_zone(FCWTypes.ZoneId.EARTH, zone_id, ship_type, ships_to_send)
				deficit -= ships_to_send * ship_power
				total_ships_sent += ships_to_send

	if total_ships_sent > 0:
		_add_to_event_log("Blockade forming at %s (%d ships)" % [zone_name, total_ships_sent], false)

func _ai_evacuation_fleet() -> void:
	## Manage evacuation fleet at Earth with proper escort ratios
	## Carriers need escorts to protect transports from Herald interception
	var available = store.get_available_ships()
	var earth_zone = store.get_zone(FCWTypes.ZoneId.EARTH)
	var earth_fleet = earth_zone.get("assigned_fleet", {}) if earth_zone else {}

	# Current carriers at Earth
	var carriers_at_earth = earth_fleet.get(FCWTypes.ShipType.CARRIER, 0)
	var frigates_at_earth = earth_fleet.get(FCWTypes.ShipType.FRIGATE, 0)
	var cruisers_at_earth = earth_fleet.get(FCWTypes.ShipType.CRUISER, 0)

	# All available carriers go to Earth for evacuation
	var carriers = available.get(FCWTypes.ShipType.CARRIER, 0)
	if carriers > 0:
		store.dispatch_assign_fleet(FCWTypes.ZoneId.EARTH, FCWTypes.ShipType.CARRIER, carriers)
		carriers_at_earth += carriers

	# ESCORT LOGIC: Each carrier needs 2 frigates or 1 cruiser for escort
	# This protects evacuation transports from Herald drone interception
	var escort_needed = carriers_at_earth * 2  # 2 escorts per carrier
	var current_escorts = frigates_at_earth + (cruisers_at_earth * 2)  # Cruisers count as 2 frigates
	var escort_deficit = escort_needed - current_escorts

	if escort_deficit > 0:
		# Prefer cruisers for escort (more firepower per ship)
		var cruisers = available.get(FCWTypes.ShipType.CRUISER, 0)
		var cruisers_to_assign = mini(cruisers / 2, escort_deficit / 2)  # Keep half for frontline
		if cruisers_to_assign > 0:
			store.dispatch_assign_fleet(FCWTypes.ZoneId.EARTH, FCWTypes.ShipType.CRUISER, cruisers_to_assign)
			escort_deficit -= cruisers_to_assign * 2

		# Fill remaining escort need with frigates
		if escort_deficit > 0:
			var frigates = available.get(FCWTypes.ShipType.FRIGATE, 0)
			var frigates_to_assign = mini(frigates / 2, escort_deficit)  # Keep half for frontline
			if frigates_to_assign > 0:
				store.dispatch_assign_fleet(FCWTypes.ZoneId.EARTH, FCWTypes.ShipType.FRIGATE, frigates_to_assign)

	# Log escort status if we have significant evacuation fleet
	if carriers_at_earth >= 2:
		var total_escorts = frigates_at_earth + cruisers_at_earth
		if total_escorts < carriers_at_earth:
			_add_to_event_log("⚠ Evacuation fleet needs more escorts at Earth", false)

func _ai_redistribute_fleet(herald_target: int) -> void:
	## Pull ships from zones far from the action and redeploy them
	## Safe zones = not adjacent to Herald target, not Earth
	var herald_strength = store.get_herald_strength()
	var target_defense = store.get_zone_defense(herald_target)

	# Only redistribute if target zone needs reinforcement
	if target_defense >= herald_strength * 1.5:
		return  # Target is well defended, no need to strip other zones

	var deficit = int(herald_strength * 1.3) - target_defense
	if deficit <= 0:
		return

	# Find safe zones with ships we can pull
	var safe_zones: Array = []
	for zone_id in FCWTypes.ZoneId.values():
		if zone_id == herald_target or zone_id == FCWTypes.ZoneId.EARTH:
			continue
		var zone = store.get_zone(zone_id)
		if zone.status != FCWTypes.ZoneStatus.CONTROLLED:
			continue

		# Check if this zone is adjacent to Herald target
		var is_adjacent = zone_id in FCWTypes.ZONE_CONNECTIONS.get(herald_target, [])
		if is_adjacent:
			continue  # Don't pull from adjacent zones - they may be attacked next

		# Check if zone has ships
		var zone_fleet = zone.get("assigned_fleet", {})
		var has_ships = false
		for st in zone_fleet:
			if zone_fleet[st] > 0:
				has_ships = true
				break
		if has_ships:
			safe_zones.append(zone_id)

	# Pull ships from safe zones toward the threatened zone
	var power_gathered = 0
	var total_ships_moved = 0

	for donor_id in safe_zones:
		if power_gathered >= deficit:
			break

		var donor_zone = store.get_zone(donor_id)
		var donor_fleet = donor_zone.get("assigned_fleet", {})

		# Pull combat ships (not carriers - those stay for evacuation if needed)
		for ship_type in [FCWTypes.ShipType.FRIGATE, FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.DREADNOUGHT]:
			var count = donor_fleet.get(ship_type, 0)
			if count <= 0:
				continue

			# Keep at least 1 ship for scouting/early warning
			var ships_to_pull = maxi(0, count - 1)
			if ships_to_pull <= 0:
				continue

			var power = FCWTypes.get_ship_combat_power(ship_type) * ships_to_pull

			# Actually move the ships - game state handles visualization
			store.dispatch_recall_fleet(donor_id, herald_target, ship_type, ships_to_pull)

			# Update battle system tracking
			if _battle_system:
				_battle_system.assign_ships_to_zone(donor_id, herald_target, ship_type, ships_to_pull)

			power_gathered += power
			total_ships_moved += ships_to_pull

			if power_gathered >= deficit:
				break

	if total_ships_moved > 0:
		_add_to_event_log("REDEPLOYMENT: %d ships recalled from safe zones to %s" % [
			total_ships_moved, FCWTypes.get_zone_name(herald_target)
		], false)

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
	# Visual warp effect
	solar_map.spawn_warp_in(_selected_zone)
	store.dispatch_assign_fleet(_selected_zone, ship_type, 1)
	# Sync battle system ship locations
	if _battle_system:
		_battle_system.assign_ships_to_zone(FCWTypes.ZoneId.EARTH, _selected_zone, ship_type, 1)

func _set_paused(paused: bool) -> void:
	## Central function to set pause state - keeps solar_map in sync
	_is_paused = paused
	if solar_map:
		solar_map.set_paused(paused)

func _on_speed_changed(value: float) -> void:
	_speed_index = int(value)
	if _speed_index == 0:
		_set_paused(true)
	else:
		_set_paused(false)
	# Sync speed multiplier to solar map for visual animations
	if solar_map:
		solar_map.set_speed(TICKS_PER_SECOND[_speed_index])
	_sync_speed_display()

func _on_pause_pressed() -> void:
	_set_paused(not _is_paused)
	if _is_paused:
		speed_slider.value = 0
	else:
		if _speed_index == 0:
			_speed_index = 2  # Default to normal
		speed_slider.value = _speed_index
	# Sync speed multiplier to solar map
	if solar_map:
		solar_map.set_speed(TICKS_PER_SECOND[_speed_index])
	_sync_speed_display()

func _on_auto_play_toggled(pressed: bool) -> void:
	_auto_play = pressed
	auto_play_btn.text = "🤖 AUTO ON" if _auto_play else "🤖 AUTO"
	# When enabling auto-play, also unpause and set to fast speed
	if _auto_play:
		_set_paused(false)
		_speed_index = 3  # Fast
		speed_slider.value = _speed_index
		# Sync speed multiplier to solar map
		if solar_map:
			solar_map.set_speed(TICKS_PER_SECOND[_speed_index])
		_sync_speed_display()
		# Log AI takeover
		_add_to_event_log("=== AI COMMAND ACTIVATED ===", true)
	else:
		_add_to_event_log("=== MANUAL CONTROL RESUMED ===", false)

func _on_battle_complete() -> void:
	# Resume normal game flow after battle view
	_sync_ui()
	# Reset to small view when battle ends
	if _battle_view.is_expanded():
		_battle_view.set_expanded(false)
		_set_battle_view_size(false)

func _on_extra_battle_complete(battle_view: FCWBattleView) -> void:
	# Remove and free the extra battle view when its battle ends
	if battle_view in _extra_battle_views:
		_extra_battle_views.erase(battle_view)
	battle_view.queue_free()

func _spawn_cascading_battle_view(_zone_name: String, defenders: Array, herald_count: int, _will_hold: bool) -> void:
	## Reinforce the existing battle instead of spawning new windows
	## This makes fleet sizes grow larger for epic battles
	if _battle_view and _battle_view.visible and _battle_view.is_active():
		_battle_view.reinforce_battle(defenders, herald_count)

func _on_ship_destroyed(ship_name: String) -> void:
	# Log ship destruction
	_add_to_event_log("SHIP LOST: %s" % ship_name, true)

func _on_battle_view_expand_toggled(is_expanded: bool) -> void:
	_set_battle_view_size(is_expanded)

func _on_planet_view_close() -> void:
	_planet_view.hide_view()
	_planet_view_close_timer = -1.0  # Cancel any pending auto-close

func _on_planet_view_position_changed(new_position: Vector2) -> void:
	## Save the user's dragged position for this zone
	var zone_id = _planet_view.get_focused_zone()
	if zone_id >= 0:
		_planet_view_saved_positions[zone_id] = new_position

func _schedule_planet_view_close(delay: float) -> void:
	## Schedule the planet view to auto-close after a delay
	_planet_view_close_timer = delay

func _show_planet_view_for_zone(zone_id: int, is_under_attack: bool) -> void:
	## Show the planet detail window for a specific zone, positioned near the planet
	_planet_view_close_timer = -1.0  # Cancel any pending auto-close
	var zone = store.get_zone(zone_id)
	var zone_defense = store.get_zone_defense(zone_id)
	var herald_strength = store.get_herald_strength()
	var herald_target = store.get_herald_target()
	var turn = store.get_turn()
	const PEACE_TURNS = 3

	# Position the window near the planet on the map
	_position_planet_view_near_zone(zone_id)

	# During peace, don't show Herald info
	var show_herald = turn >= PEACE_TURNS
	_planet_view.show_zone(
		zone_id,
		zone.status,
		zone_defense,
		herald_strength if show_herald else 0,
		is_under_attack and zone_id == herald_target and show_herald
	)

func _position_planet_view_near_zone(zone_id: int) -> void:
	## Position the planet view window near the specified zone on the solar map
	## If user has dragged this zone's view before, use saved position
	if not solar_map:
		return

	# Check if we have a saved position for this zone
	if _planet_view_saved_positions.has(zone_id):
		_planet_view.position = _planet_view_saved_positions[zone_id]
		return

	var view_size = _planet_view.size
	var zone_screen_pos = solar_map.get_zone_screen_position(zone_id)
	var zone_size = solar_map.get_zone_size(zone_id)

	# Offset the window to be below-right of the planet by default
	var offset = Vector2(zone_size + 20, zone_size + 10)

	# Check screen boundaries and adjust position
	var screen_size = get_viewport_rect().size
	var target_pos = zone_screen_pos + offset

	# If window would go off right edge, position to the left of planet instead
	if target_pos.x + view_size.x > screen_size.x - 20:
		target_pos.x = zone_screen_pos.x - view_size.x - zone_size - 20

	# If window would go off bottom edge, position above planet instead
	if target_pos.y + view_size.y > screen_size.y - 80:  # Leave room for footer
		target_pos.y = zone_screen_pos.y - view_size.y - zone_size - 10

	# Clamp to screen bounds with padding
	target_pos.x = clampf(target_pos.x, 10, screen_size.x - view_size.x - 10)
	target_pos.y = clampf(target_pos.y, 60, screen_size.y - view_size.y - 60)  # Header/footer padding

	_planet_view.position = target_pos

func _update_planet_view() -> void:
	## Update the planet view with current zone state
	var focused_zone = _planet_view.get_focused_zone()
	if focused_zone < 0:
		return

	var zone = store.get_zone(focused_zone)
	var zone_defense = store.get_zone_defense(focused_zone)
	var herald_strength = store.get_herald_strength()
	var herald_target = store.get_herald_target()
	var turn = store.get_turn()
	const PEACE_TURNS = 3

	# During peace, don't show Herald info
	var show_herald = turn >= PEACE_TURNS
	_planet_view.update_zone_state(
		zone.status,
		zone_defense,
		herald_strength if show_herald else 0,
		focused_zone == herald_target and _is_in_attack_phase and show_herald
	)

func _set_battle_view_size(expanded: bool) -> void:
	if expanded:
		# Expanded view: larger, centered on screen
		var viewport_size = get_viewport_rect().size
		_battle_view.custom_minimum_size = Vector2(1000, 700)
		_battle_view.size = Vector2(1000, 700)
		_battle_view.position = Vector2(
			(viewport_size.x - 1000) / 2,
			(viewport_size.y - 700) / 2
		)
	else:
		# Corner view: small, bottom-right
		var viewport_size = get_viewport_rect().size
		_battle_view.custom_minimum_size = Vector2(400, 280)
		_battle_view.size = Vector2(400, 280)
		_battle_view.position = Vector2(
			viewport_size.x - 420,
			viewport_size.y - 300
		)

func _add_to_event_log(message: String, is_critical: bool) -> void:
	# Add a custom message to the event log display
	var turn = store.get_turn()
	var prefix = "[color=red]▶[/color] " if is_critical else "  "
	var current_text = event_log.text
	current_text += "%sW%d: %s\n" % [prefix, turn, message]
	event_log.text = current_text

func _update_narrative_state() -> void:
	## Determine narrative mood based on game situation
	## 0 = Peace, 1 = Tension, 2 = Combat, 3 = Desperate

	var herald_target = store.get_herald_target()
	var herald_strength = store.get_herald_strength()
	var target_defense = store.get_zone_defense(herald_target)
	var turn = store.get_turn()

	# Count controlled zones
	var controlled_count = 0
	for zone_id in FCWTypes.ZoneId.values():
		var zone = store.get_zone(zone_id)
		if zone.status == FCWTypes.ZoneStatus.CONTROLLED:
			controlled_count += 1

	# Determine narrative state
	var new_state = 0

	# Desperate: Earth under attack OR only 1-2 zones left OR massively outgunned
	if herald_target == FCWTypes.ZoneId.EARTH:
		new_state = 3
	elif controlled_count <= 2:
		new_state = 3
	elif target_defense < herald_strength * 0.5:
		new_state = 3  # Going to lose badly

	# Combat: Active attack happening
	elif _is_in_attack_phase:
		new_state = 2

	# Tension: Herald close or defense is marginal
	elif herald_target in [FCWTypes.ZoneId.MARS, FCWTypes.ZoneId.ASTEROID_BELT]:
		new_state = 1
	elif target_defense < herald_strength * 1.2:
		new_state = 1

	# Peace: Early game, Herald far away, strong defenses
	elif turn < 5 and herald_strength < 100:
		new_state = 0
	elif target_defense > herald_strength * 2:
		new_state = 0

	# Default to tension in mid-late game
	else:
		new_state = 1

	# Apply the state
	solar_map.set_narrative_state(new_state)

	# Trigger defense success narrative if we just survived an attack
	if _is_in_attack_phase == false and solar_map.get_narrative_state() < 2:
		var zone = store.get_zone(herald_target)
		if zone.status == FCWTypes.ZoneStatus.CONTROLLED and target_defense >= herald_strength:
			# We held! (check occasionally, not every turn)
			if turn % 3 == 0:
				solar_map.trigger_defense_success_narrative(herald_target)

func _on_turn_ended(_turn: int) -> void:
	_update_guidance()

func _on_ship_completed(ship_type: int) -> void:
	# Create a named ship in the battle system when a ship is completed
	if _battle_system:
		_battle_system.create_new_ship(ship_type, FCWTypes.ZoneId.EARTH)

func _on_zone_fallen(zone_id: int) -> void:
	# DRAMATIC zone destruction effects
	solar_map.spawn_zone_destroyed(zone_id)

	# Cinematic camera response
	solar_map.cinematic_zone_fallen(zone_id)

	# Show planet view for the fallen zone (dramatic closeup)
	_show_planet_view_for_zone(zone_id, false)  # Not under active attack anymore, it fell

	# Trigger narrative transmission for zone loss
	var zone = store.get_zone(zone_id)
	var lives_lost = zone.get("population", 0)
	solar_map.trigger_zone_loss_narrative(zone_id, lives_lost)

	# Set desperate narrative state
	solar_map.set_narrative_state(3)  # Desperate

	# Pause and show dramatic overlay
	_set_paused(true)
	_sync_speed_display()
	_show_zone_fallen_overlay(zone_id, lives_lost)

func _on_entity_destination_selected(entity_id: String, destination_zone: int, route_type: String) -> void:
	## Handle entity route selection from solar map
	## This is the player sending a capital ship to a new destination
	print("Route selected: %s → zone %d via %s" % [entity_id, destination_zone, route_type])

	# Dispatch the route change to store
	store.dispatch_set_entity_destination(entity_id, destination_zone, route_type)

	# Log the event
	var entity = store.get_entity(entity_id)
	if not entity.is_empty():
		var entity_name = entity.get("name", "Fleet")
		var dest_name = FCWTypes.get_zone_name(destination_zone)
		var route_desc = "direct burn" if route_type == "direct" else ("stealth coast" if route_type == "coast" else "gravity assist")
		store.dispatch({
			"type": "LOG_EVENT",
			"message": "%s departing for %s via %s" % [entity_name, dest_name, route_desc],
			"is_critical": true
		})

	# Sync UI
	_sync_ui()

func _on_game_over(victory_tier: int) -> void:
	_set_paused(true)

	# Cinematic camera - pull back to galaxy for final perspective
	if solar_map:
		solar_map.cinematic_game_over()

	# Trigger defiant final transmission sequence before showing panel
	var evacuated = store.get_lives_evacuated()
	var pop_str = FCWTypes.format_population(evacuated)

	# The defiant final message - not surrender, but testament
	if solar_map:
		solar_map.spawn_transmission(
			"Admiral Chen",
			"This is Admiral Chen to all evacuation vessels. Earth's defense fleet is engaging. We will hold them as long as we can.",
			0
		)

	# Delay before showing game over panel to let transmission display
	await get_tree().create_timer(3.0).timeout

	# Second transmission - the defiant words
	if solar_map and is_inside_tree():
		var defiant_message = ""
		defiant_message += "To the %s souls now bound for the stars: " % pop_str
		defiant_message += "You carry everything we were. Our music. Our stories. Our hope."
		solar_map.spawn_transmission("Earth Final", defiant_message, 0)

	await get_tree().create_timer(3.5).timeout

	# Third transmission - the ending
	if solar_map and is_inside_tree():
		solar_map.spawn_transmission(
			"Last Transmission",
			"The Herald came for humanity. They found us wanting to live. We did not go quietly. We will survive.",
			0
		)

	await get_tree().create_timer(3.0).timeout

	# Now show the game over panel
	if not is_inside_tree():
		return

	game_over_panel.visible = true

	# Victory tier with defiant framing
	var tier_name = FCWTypes.get_victory_tier_name(victory_tier)
	victory_tier_label.text = tier_name

	# Victory description - already defiant in fcw_types.gd
	victory_desc_label.text = '"%s"' % FCWTypes.get_victory_description(victory_tier)

	# Enhanced stats with defiant framing
	var stats = ""
	stats += "SOULS SAVED: %s\n" % FCWTypes.format_population(evacuated)

	# Add context based on tier
	match victory_tier:
		FCWTypes.VictoryTier.LEGENDARY:
			stats += "Against all odds. Against the void itself.\n"
		FCWTypes.VictoryTier.HEROIC:
			stats += "Enough to rebuild. Enough to remember.\n"
		FCWTypes.VictoryTier.PYRRHIC:
			stats += "A remnant survives. Hope endures.\n"
		FCWTypes.VictoryTier.TRAGIC:
			stats += "Scattered, but not broken.\n"
		_:
			stats += "The light flickers, but does not die.\n"

	stats += "\n"
	stats += "Weeks of Defiance: %d\n" % store.get_turn()
	stats += "Final Fleet Strength: %d\n" % store.get_total_fleet_strength()
	stats += "\nThey will find us among the stars."
	final_stats_label.text = stats

func _on_new_game() -> void:
	game_over_panel.visible = false
	if _zone_fallen_overlay:
		_zone_fallen_overlay.visible = false
	_set_paused(false)
	_speed_index = 2
	speed_slider.value = 2
	_auto_play = false
	auto_play_btn.button_pressed = false
	auto_play_btn.text = "🤖 AUTO"
	store.start_new_game()

func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
