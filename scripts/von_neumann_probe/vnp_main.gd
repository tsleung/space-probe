extends Node2D

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const VnpSystems = preload("res://scripts/von_neumann_probe/vnp_systems.gd")
const ShipScene = preload("res://scenes/von_neumann_probe/ship.tscn")
const ProjectileScene = preload("res://scenes/von_neumann_probe/projectile.tscn")
const DeathExplosionFxScene = preload("res://scenes/von_neumann_probe/death_explosion_fx.tscn")
const AiController = preload("res://scripts/von_neumann_probe/vnp_ai_controller.gd")
const BaseWeapon = preload("res://scripts/von_neumann_probe/base_weapon.gd")
const SoundManager = preload("res://scripts/von_neumann_probe/vnp_sound_manager.gd")

@onready var store = $VnpStore
@onready var vnp_ui = $UILayer/VnpUI

var screen_size = Vector2.ZERO
var world_size = Vector2.ZERO  # Larger than screen for more maneuvering room
const PLANET_COUNT = 12
const WORLD_PADDING = 150
const WORLD_SCALE = 1.5  # World is 1.5x larger than viewport for momentum-based combat

# Balance constants - CRANKED UP FOR DRAMA
const ENERGY_REGEN_RATE = 60  # 6x faster ship production - FAST action
const NEMESIS_ENERGY_MULTIPLIER = 1.3  # Reduced from 1.5 - still advantaged but competitive
const VICTORY_DISPLAY_TIME = 3.0

var ship_nodes = {}
var planet_nodes = {}
var base_nodes = {}
var strategic_point_nodes = {}  # point_id -> Node2D
var outpost_nodes = {}  # point_id -> Node2D (visual for built outposts)
var factory_nodes = {}  # factory_id -> Node2D (visual for factories)
var harvester_build_progress = {}  # point_id -> harvester_ship_id tracking who's building
var factory_build_progress = {}  # factory_id -> harvester_ship_id tracking who's building

# Harvester camping for factory building anywhere
var harvester_camp_positions = {}  # ship_id -> { position, time, pending_factory_id }
const HARVESTER_CAMP_TOLERANCE = 30.0  # How far harvester can drift while "camping"

# Projectile pooling
var projectile_pool: Array = []
const PROJECTILE_POOL_SIZE = 100

# AI Controller
var ai_controller = null

# Sound Manager
var sound_manager = null

# Timers
var energy_regen_timer: Timer
var victory_check_timer: Timer
var planet_income_timer: Timer
var strategic_point_timer: Timer
var expansion_timer: Timer
var outpost_timer: Timer  # Outpost building and production
var factory_timer: Timer  # Factory production
var base_weapon_cooldowns = {}  # team -> time_remaining

# Expansion tracking
const EXPANSION_INTERVAL = 10.0  # Seconds between expansions (30.0 for production)
const EXPANSION_COUNTDOWN_START = 3.0  # Start showing countdown this many seconds before
var last_expansion_phase: int = 0  # Track to detect phase changes
var expansion_countdown_ring: Line2D = null  # Visual countdown ring
var expansion_countdown_label: Label = null  # Countdown text
var expansion_countdown_active: bool = false  # Is countdown currently showing

# Starfield reference for expansion
var starfield_node: Node2D = null

# Gameplay center - fixed at initial world center (bases don't move during expansion)
var gameplay_center: Vector2 = Vector2.ZERO

# Base charge system - allows storing up charges for burst attacks
var base_charges = {}  # team -> current_charges
var base_charge_mode = {}  # team -> "auto" or "manual"
const MAX_BASE_CHARGES = 5  # Maximum stored charges

# Click handling for rally points
var selected_rally_target = null  # Currently highlighted target for player
var rally_line: Line2D = null  # Visual dashed line showing rally route
var player_rally_point: Vector2 = Vector2.ZERO  # Where player ships rally to

# Double-click detection for FULL SEND
var last_click_time: float = 0.0
var last_click_pos: Vector2 = Vector2.ZERO
const DOUBLE_CLICK_TIME = 0.35  # Max time between clicks
const DOUBLE_CLICK_DIST = 50.0  # Max distance between clicks

# Screen shake
var shake_intensity: float = 0.0
var shake_decay: float = 8.0
var camera: Camera2D

# Camera zoom
var current_zoom: float = 1.0
const ZOOM_SPEED = 0.1
const ZOOM_MIN = 0.5  # Max zoom in (closer)
const ZOOM_MAX_BASE = 1.0  # Base max zoom out (limited by expansion)
var void_message_label: Label = null
var void_message_tween: Tween = null
var zoom_tween: Tween = null  # Track active zoom tween to prevent spam

# Progenitor centered message - THE VOICE OF THE ANCIENT VNP
var progenitor_message_label: Label = null
var progenitor_message_active: bool = false

# Ominous message tracking
var current_ominous_message: String = ""
var ominous_message_timer: float = 0.0
const OMINOUS_MESSAGE_DURATION = 2.5  # Seconds before changing message

# Progenitor hunters - THE ANCIENT VNP - Fewer but DEADLY
var progenitor_spawn_timer: float = 0.0
const PROGENITOR_SPAWN_INTERVAL = 3.0  # Relentless waves
const PROGENITOR_DRONES_PER_WAVE = 4  # Overwhelming ancient hunters
const PROGENITOR_WAVE_SECTORS = 4  # Spawn from 4 directions
const PROGENITOR_ESCALATION_RATE = 1  # Slowly add more drones per wave
var progenitor_wave_count: int = 0  # Track waves for escalation

# Explosion rate limiting (prevents lag when tabbed back)
var explosion_count_this_frame: int = 0
const MAX_EXPLOSIONS_PER_FRAME: int = 3

# Victory state
var showing_victory = false

# === THE CYCLE - CONVERGENCE SYSTEM ===
var convergence_timer: Timer
var convergence_game_timer: float = 0.0  # Total game time for whispers trigger
var convergence_visual_ring: Line2D = null  # Absorption zone visualization
var convergence_pull_particles: GPUParticles2D = null  # Matter streaming effect
var convergence_edge_shader: ColorRect = null  # Edge distortion effect
var mystery_card_shown: bool = false  # Has "???" been revealed
var progenitor_revealed: bool = false  # Has THE PROGENITOR name been shown

func _ready():
	screen_size = get_viewport_rect().size
	world_size = screen_size * WORLD_SCALE  # Larger world for momentum combat
	gameplay_center = world_size / 2  # Store original center (bases positioned relative to this)
	store.subscribe(self)
	set_process(true)

	_setup_camera()
	_setup_timers()
	_setup_sound()
	_setup_rally_line()
	_setup_projectile_pool()
	_create_starfield()
	_create_bases()
	_create_strategic_points()  # New capture points system
	_setup_ai()  # Must be before spawning ships so they get ai_controller reference
	_spawn_base_turrets()  # Defensive turrets at each base for early game protection

	vnp_ui.init(store, base_nodes, ai_controller, strategic_point_nodes, self)

	var initial_state = store.get_state()
	on_state_changed(initial_state)


func _setup_projectile_pool():
	# Pre-instantiate projectiles for reuse
	for i in PROJECTILE_POOL_SIZE:
		var p = ProjectileScene.instantiate()
		p.set_physics_process(false)
		p.visible = false
		p.active = false
		add_child(p)
		projectile_pool.append(p)


func get_projectile() -> Node:
	# Find an inactive projectile in the pool
	for p in projectile_pool:
		if is_instance_valid(p) and not p.active:
			return p
	# Pool exhausted - create new projectile (fallback)
	var p = ProjectileScene.instantiate()
	add_child(p)
	projectile_pool.append(p)
	return p


func return_projectile(p: Node):
	if is_instance_valid(p) and p.has_method("deactivate"):
		p.deactivate()

func _process(delta):
	# Reset explosion counter each frame
	explosion_count_this_frame = 0

	# Screen shake
	if shake_intensity > 0:
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		if shake_intensity < 0.1:
			shake_intensity = 0.0
			camera.offset = Vector2.ZERO

	# Update expansion countdown visual
	if not showing_victory and expansion_timer and expansion_timer.time_left > 0:
		var time_left = expansion_timer.time_left
		var state = store.get_state()
		if state == null or not state.has("expansion"):
			return
		var current_phase = state.expansion.phase
		var max_phase = state.expansion.max_phase

		if current_phase < max_phase:
			if time_left <= EXPANSION_COUNTDOWN_START and not expansion_countdown_active:
				_show_expansion_countdown()
			elif expansion_countdown_active:
				_update_expansion_countdown(time_left)

	# Update base weapon cooldowns and charge accumulation
	if not showing_victory:
		# Guard against uninitialized dictionaries (can happen during startup)
		if base_weapon_cooldowns.is_empty():
			return
		for team in VnpTypes.Team.values():
			var cooldown = base_weapon_cooldowns.get(team, 0.0)
			if cooldown > 0:
				base_weapon_cooldowns[team] = cooldown - delta
			elif cooldown <= 0:
				# Cooldown finished - add a charge if not at max
				var charges = base_charges.get(team, 0)
				if charges < MAX_BASE_CHARGES:
					base_charges[team] = charges + 1
					base_weapon_cooldowns[team] = VnpTypes.BASE_WEAPON_COOLDOWN

				# AI teams use smart firing heuristic
				if team != VnpTypes.Team.PLAYER and base_charges.get(team, 0) > 0:
					_ai_evaluate_base_weapon_fire(team)
				# Player auto mode: fire immediately when charged
				elif team == VnpTypes.Team.PLAYER and base_charge_mode.get(team, "auto") == "auto" and base_charges.get(team, 0) > 0:
					_try_fire_base_weapon(team)

		# Update UI with cooldowns and charges
		vnp_ui.update_cooldowns(base_weapon_cooldowns, base_charges, base_charge_mode)

	# Update convergence visuals (The Cycle)
	_update_convergence_visuals()

func _try_fire_base_weapon(team: int, burst: bool = false):
	var state = store.get_state()

	# Need charges to fire
	if base_charges[team] <= 0:
		return

	# Check if there are any enemies to target
	var has_enemies = false
	for ship_id in state.ships:
		if state.ships[ship_id].team != team:
			has_enemies = true
			break

	if not has_enemies:
		return

	# Burst fires all charges at once (bigger effect), normal fires 1
	var charges_to_fire = 1
	if burst:
		charges_to_fire = base_charges[team]

	# Fire with combined charge power - more charges = more range + damage + visuals
	fire_base_weapon(team, charges_to_fire)
	base_charges[team] -= charges_to_fire

func fire_base_weapon(team: int, charges: int = 1):
	if not base_nodes.has(team):
		return

	var base_pos = base_nodes[team].position
	var weapon = BaseWeapon.new()
	add_child(weapon)
	weapon.init(store, team, base_pos, charges, self)


func toggle_charge_mode(team: int):
	if base_charge_mode[team] == "auto":
		base_charge_mode[team] = "manual"
	else:
		base_charge_mode[team] = "auto"


func manual_fire_base_weapon(team: int):
	# Fire 1 charge
	if base_charges[team] > 0:
		_try_fire_base_weapon(team, false)


func burst_fire_base_weapon(team: int):
	# Fire ALL charges at once
	if base_charges[team] > 0:
		_try_fire_base_weapon(team, true)


func trigger_full_retreat(team: int):
	"""All ships of this team flee toward center (safety) - used during convergence"""
	store.dispatch({
		"type": "FULL_RETREAT",
		"team": team
	})

	# Screen shake for drama
	shake_screen(8.0)

	# Play a retreat sound if available
	if sound_manager and sound_manager.has_method("play_retreat"):
		sound_manager.play_retreat()


func _ai_evaluate_base_weapon_fire(team: int):
	# Smart AI heuristic for deciding when to fire base weapons
	# Uses pure functions from VnpSystems for testability
	var state = store.get_state()
	if state == null or not state.has("ships"):
		return
	# Skip teams without bases (like PROGENITOR)
	if not base_nodes.has(team):
		return
	var charges = base_charges.get(team, 0)
	var base_pos = base_nodes[team].position

	# Use pure function for range calculation
	var current_range = VnpSystems.get_weapon_range(charges)

	# Count enemies in range using pure function
	var enemies_in_range = VnpSystems.count_enemies_in_range(base_pos, team, current_range, state.ships)

	# Get enemy positions for cluster analysis
	var enemy_positions = []
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist = ship.position.distance_to(base_pos)
			if dist <= current_range:
				enemy_positions.append(ship.position)

	# Calculate cluster quality using pure function
	var cluster_score = VnpSystems.calculate_cluster_score(enemy_positions)

	# Evaluate firing decision using pure function
	var result = VnpSystems.evaluate_base_weapon_fire(charges, enemies_in_range, cluster_score, MAX_BASE_CHARGES)

	if result.should_fire:
		_try_fire_base_weapon(team, result.burst)


func _setup_camera():
	camera = Camera2D.new()
	camera.name = "Camera2D"
	# Center camera on the gameplay center (where bases are)
	camera.position = gameplay_center
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	current_zoom = WORLD_SCALE  # Start at current world scale
	camera.zoom = Vector2.ONE / current_zoom

	# Set camera limits centered on gameplay_center
	# This ensures expansion grows equally in all visual directions
	_update_camera_limits()
	camera.limit_smoothed = true  # Smooth transition at edges

	add_child(camera)
	camera.make_current()

	# Setup void message label (hidden by default)
	_setup_void_message()


func _update_camera_limits():
	"""Update camera limits to be symmetric around gameplay_center"""
	if not camera:
		return
	# Calculate how far the camera can move from center
	# Use half of world_size as the extent from gameplay_center
	var half_extent = world_size / 2
	camera.limit_left = int(gameplay_center.x - half_extent.x)
	camera.limit_right = int(gameplay_center.x + half_extent.x)
	camera.limit_top = int(gameplay_center.y - half_extent.y)
	camera.limit_bottom = int(gameplay_center.y + half_extent.y)


func _setup_void_message():
	"""Create the 'cannot see into the void' message label"""
	void_message_label = Label.new()
	void_message_label.name = "VoidMessage"
	void_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	void_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	void_message_label.add_theme_font_size_override("font_size", 22)
	void_message_label.add_theme_color_override("font_color", VnpTypes.PROGENITOR_ACCENT)
	void_message_label.modulate.a = 0.0
	void_message_label.size = Vector2(400, 50)
	void_message_label.position = Vector2(screen_size.x / 2 - 200, screen_size.y - 80)
	$UILayer.add_child(void_message_label)

	# Setup centered Progenitor message for dramatic convergence warnings
	_setup_progenitor_message()


func _setup_progenitor_message():
	"""Create centered dramatic message for Progenitor warnings"""
	progenitor_message_label = Label.new()
	progenitor_message_label.name = "ProgenitorMessage"
	progenitor_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progenitor_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progenitor_message_label.add_theme_font_size_override("font_size", 36)
	progenitor_message_label.add_theme_color_override("font_color", VnpTypes.PROGENITOR_PULSE)
	progenitor_message_label.modulate.a = 0.0
	progenitor_message_label.size = Vector2(600, 80)
	# Center on screen
	progenitor_message_label.position = Vector2(screen_size.x / 2 - 300, screen_size.y / 2 - 40)
	progenitor_message_label.z_index = 100  # Above everything
	$UILayer.add_child(progenitor_message_label)


func _handle_zoom(delta: float):
	"""Handle camera zoom with expansion-based limits"""
	var state = store.get_state()
	if state == null or not state.has("expansion"):
		return
	var world_scale = state.expansion.world_scale

	# Calculate zoom limits based on current expansion
	var max_zoom_out = world_scale  # Can only zoom out to current world scale
	var min_zoom_in = ZOOM_MIN

	var new_zoom = current_zoom + delta

	# Check if trying to zoom out past the limit
	if new_zoom > max_zoom_out:
		new_zoom = max_zoom_out
		_show_void_message()
		return

	# Clamp to valid range
	new_zoom = clamp(new_zoom, min_zoom_in, max_zoom_out)

	# Apply zoom directly for trackpad (smoother) or with tween for mouse wheel
	if abs(new_zoom - current_zoom) > 0.001:
		current_zoom = new_zoom
		# Kill existing zoom tween to prevent conflicts
		if zoom_tween and zoom_tween.is_running():
			zoom_tween.kill()
		# Apply zoom directly for responsive feel
		camera.zoom = Vector2.ONE / current_zoom


func _show_void_message():
	"""Show thematic message when player tries to zoom past expansion limit"""
	if not is_instance_valid(void_message_label):
		return

	# Random void messages
	var messages = [
		"The void reveals nothing...",
		"You cannot see beyond the expansion...",
		"Only darkness lies there...",
		"The Progenitor watches from the void...",
		"Some distances cannot be crossed...",
		"The edge of known space...",
		"Beyond lies only silence...",
	]

	void_message_label.text = messages[randi() % messages.size()]

	# Cancel existing tween if running
	if void_message_tween and void_message_tween.is_running():
		void_message_tween.kill()

	# Fade in, hold, fade out
	void_message_label.modulate.a = 0.0
	void_message_tween = create_tween()
	void_message_tween.tween_property(void_message_label, "modulate:a", 1.0, 0.2)
	void_message_tween.tween_interval(1.5)
	void_message_tween.tween_property(void_message_label, "modulate:a", 0.0, 0.5)

func _setup_timers():
	# Energy regeneration timer
	energy_regen_timer = Timer.new()
	energy_regen_timer.name = "EnergyRegenTimer"
	energy_regen_timer.wait_time = 1.0
	energy_regen_timer.timeout.connect(_on_energy_regen)
	add_child(energy_regen_timer)
	energy_regen_timer.start()

	# Victory check timer
	victory_check_timer = Timer.new()
	victory_check_timer.name = "VictoryCheckTimer"
	victory_check_timer.wait_time = 0.5
	victory_check_timer.timeout.connect(_on_victory_check)
	add_child(victory_check_timer)
	victory_check_timer.start()

	# Planet income timer (legacy)
	planet_income_timer = Timer.new()
	planet_income_timer.name = "PlanetIncomeTimer"
	planet_income_timer.wait_time = 2.0
	planet_income_timer.timeout.connect(_on_planet_income)
	add_child(planet_income_timer)
	planet_income_timer.start()

	# Strategic point income timer (mass generation)
	strategic_point_timer = Timer.new()
	strategic_point_timer.name = "StrategicPointTimer"
	strategic_point_timer.wait_time = 2.0
	strategic_point_timer.timeout.connect(_on_strategic_point_income)
	add_child(strategic_point_timer)
	strategic_point_timer.start()

	# Expansion timer - map grows every 30 seconds
	expansion_timer = Timer.new()
	expansion_timer.name = "ExpansionTimer"
	expansion_timer.wait_time = EXPANSION_INTERVAL
	expansion_timer.timeout.connect(_on_expansion_tick)
	add_child(expansion_timer)
	expansion_timer.start()

	# Convergence timer - THE CYCLE processing
	convergence_timer = Timer.new()
	convergence_timer.name = "ConvergenceTimer"
	convergence_timer.wait_time = 0.5  # Process every 500ms
	convergence_timer.timeout.connect(_on_convergence_tick)
	add_child(convergence_timer)
	convergence_timer.start()

	# Outpost timer - harvester building and frigate production
	outpost_timer = Timer.new()
	outpost_timer.name = "OutpostTimer"
	outpost_timer.wait_time = 0.5  # Check every 500ms for smooth building progress
	outpost_timer.timeout.connect(_on_outpost_tick)
	add_child(outpost_timer)
	outpost_timer.start()

	# Factory timer - production from all factories
	factory_timer = Timer.new()
	factory_timer.name = "FactoryTimer"
	factory_timer.wait_time = 0.5  # Check every 500ms
	factory_timer.timeout.connect(_on_factory_tick)
	add_child(factory_timer)
	factory_timer.start()

	# Initialize base weapon cooldowns and charges
	for team in VnpTypes.Team.values():
		base_weapon_cooldowns[team] = 0.0
		base_charges[team] = 0
		# Player starts in manual mode, AI in auto
		if team == VnpTypes.Team.PLAYER:
			base_charge_mode[team] = "manual"
		else:
			base_charge_mode[team] = "auto"

func _setup_sound():
	sound_manager = SoundManager.new()
	sound_manager.name = "SoundManager"
	add_child(sound_manager)


func _setup_rally_line():
	rally_line = Line2D.new()
	rally_line.name = "RallyLine"
	rally_line.width = 3.0
	rally_line.default_color = VnpTypes.get_team_color(VnpTypes.Team.PLAYER)
	rally_line.default_color.a = 0.6
	rally_line.z_index = 10
	rally_line.visible = false
	add_child(rally_line)


func _input(event):
	if showing_victory:
		return

	# Handle scroll wheel zoom (mouse)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(-ZOOM_SPEED)  # Zoom in (smaller zoom value = closer)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(ZOOM_SPEED)  # Zoom out (larger zoom value = further)
			return

	# Handle trackpad two-finger scroll (macOS)
	if event is InputEventPanGesture:
		var zoom_delta = event.delta.y * ZOOM_SPEED * 0.5  # Scale down for smoother trackpad
		_handle_zoom(zoom_delta)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var current_time = Time.get_ticks_msec() / 1000.0

		# Check for double click
		var is_double_click = false
		if current_time - last_click_time < DOUBLE_CLICK_TIME and click_pos.distance_to(last_click_pos) < DOUBLE_CLICK_DIST:
			is_double_click = true

		last_click_time = current_time
		last_click_pos = click_pos

		if is_double_click:
			_handle_full_send(click_pos)
		else:
			_handle_rally_click(click_pos)


func _handle_rally_click(click_pos: Vector2):
	var state = store.get_state()
	var player_base_pos = base_nodes[VnpTypes.Team.PLAYER].position

	# Check if clicked on a player-owned factory (to cycle production)
	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		if factory["team"] != VnpTypes.Team.PLAYER:
			continue
		if not factory.get("complete", false):
			continue
		var factory_pos = factory["position"]
		if click_pos.distance_to(factory_pos) < 50:
			_cycle_factory_production(factory_id, factory)
			return

	# Check if clicked on an enemy base
	for team in base_nodes:
		if team == VnpTypes.Team.PLAYER:
			continue
		var base_pos = base_nodes[team].position
		if click_pos.distance_to(base_pos) < 60:
			_set_rally_point(base_pos, "enemy_base_%d" % team)
			return

	# Check if clicked on a strategic point
	for point_id in strategic_point_nodes:
		var point_node = strategic_point_nodes[point_id]
		if click_pos.distance_to(point_node.position) < 60:
			_set_rally_point(point_node.position, point_id)
			return

	# Check if clicked near player base (clear rally)
	if click_pos.distance_to(player_base_pos) < 80:
		_clear_rally_point()
		return


func _set_rally_point(target_pos: Vector2, target_id):
	var player_base_pos = base_nodes[VnpTypes.Team.PLAYER].position
	player_rally_point = target_pos
	selected_rally_target = target_id

	# Update rally line visual
	_update_rally_line(player_base_pos, target_pos)

	# Store in state for ships to use
	store.dispatch({
		"type": "SET_RALLY_POINT",
		"team": VnpTypes.Team.PLAYER,
		"target": target_pos
	})

	if sound_manager:
		sound_manager.play_ui_click()


func _clear_rally_point():
	player_rally_point = Vector2.ZERO
	selected_rally_target = null
	rally_line.visible = false

	store.dispatch({
		"type": "SET_RALLY_POINT",
		"team": VnpTypes.Team.PLAYER,
		"target": null
	})


func _cycle_factory_production(factory_id: String, factory: Dictionary):
	"""Cycle through production types for a factory"""
	# Produceable ship types (excludes HARVESTER since those are special)
	var produceable_ships = [
		VnpTypes.ShipType.FRIGATE,
		VnpTypes.ShipType.DESTROYER,
		VnpTypes.ShipType.CRUISER,
		VnpTypes.ShipType.STARBASE,
	]

	var current_type = factory.get("production_type", VnpTypes.ShipType.FRIGATE)

	# Find current index in produceable ships
	var current_index = produceable_ships.find(current_type)
	if current_index == -1:
		current_index = 0

	# Cycle to next
	var next_index = (current_index + 1) % produceable_ships.size()
	var next_type = produceable_ships[next_index]

	# Dispatch the change
	store.dispatch({
		"type": "FACTORY_SET_PRODUCTION",
		"factory_id": factory_id,
		"ship_type": next_type
	})

	# Update visual
	_update_factory_production_label(factory_id, next_type)

	# Sound feedback
	if sound_manager:
		sound_manager.play_ui_click()

	# Show floating text
	var factory_pos = factory["position"]
	var ship_stats = VnpTypes.SHIP_STATS.get(next_type, {})
	var ship_name = ship_stats.get("name", "Unknown")
	_show_floating_text(factory_pos, "→ " + ship_name, VnpTypes.get_team_color(VnpTypes.Team.PLAYER))


func _update_factory_production_label(factory_id: String, ship_type: int):
	"""Update the production label on a factory visual"""
	if not factory_nodes.has(factory_id):
		return
	var factory_node = factory_nodes[factory_id]
	if not is_instance_valid(factory_node):
		return
	var label = factory_node.get_node_or_null("ProductionLabel")
	if label:
		var ship_stats = VnpTypes.SHIP_STATS.get(ship_type, {})
		label.text = ship_stats.get("name", "?")[0]  # First letter


func _show_floating_text(pos: Vector2, text: String, color: Color):
	"""Show floating text that rises and fades"""
	var label = Label.new()
	label.text = text
	label.position = pos - Vector2(50, 20)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.z_index = 100
	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): label.queue_free()).set_delay(1.1)


func _handle_full_send(click_pos: Vector2):
	# FULL SEND - Double click sends all ships aggressively to target
	var state = store.get_state()
	var target_pos = click_pos
	var target_id = null

	# Check if clicked on an enemy base
	for team in base_nodes:
		if team == VnpTypes.Team.PLAYER:
			continue
		var base_pos = base_nodes[team].position
		if click_pos.distance_to(base_pos) < 60:
			target_pos = base_pos
			target_id = "enemy_base_%d" % team
			break

	# Check if clicked on a strategic point
	if target_id == null:
		for point_id in strategic_point_nodes:
			var point_node = strategic_point_nodes[point_id]
			if click_pos.distance_to(point_node.position) < 60:
				target_pos = point_node.position
				target_id = point_id
				break

	# Set rally point
	_set_rally_point(target_pos, target_id if target_id else "full_send")

	# FULL SEND - Force all player ships to attack-move to target
	store.dispatch({
		"type": "FULL_SEND",
		"team": VnpTypes.Team.PLAYER,
		"target": target_pos
	})

	# Visual effect - FULL SEND indicator
	_show_full_send_effect(target_pos)

	# Screen shake for impact
	shake_screen(15.0)

	if sound_manager:
		sound_manager.play_ui_click()


func _show_full_send_effect(target_pos: Vector2):
	# Dramatic visual effect for FULL SEND
	var player_base_pos = base_nodes[VnpTypes.Team.PLAYER].position

	# Expanding ring from player base
	var ring = Line2D.new()
	ring.position = player_base_pos
	ring.width = 6.0
	ring.default_color = VnpTypes.get_team_color(VnpTypes.Team.PLAYER)
	ring.default_color.a = 0.9
	var ring_points = []
	for i in range(33):
		var angle = i * (TAU / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 30)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Arrow pointing to target
	var direction = (target_pos - player_base_pos).normalized()
	var arrow_line = Line2D.new()
	arrow_line.width = 8.0
	arrow_line.default_color = VnpTypes.get_team_color(VnpTypes.Team.PLAYER)
	arrow_line.add_point(player_base_pos)
	arrow_line.add_point(target_pos)
	add_child(arrow_line)

	# "FULL SEND" text flash at target
	var label = Label.new()
	label.text = "FULL SEND!"
	label.position = target_pos - Vector2(60, 30)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", VnpTypes.get_team_color(VnpTypes.Team.PLAYER))
	add_child(label)

	# Impact ring at target
	var target_ring = Line2D.new()
	target_ring.position = target_pos
	target_ring.width = 5.0
	target_ring.default_color = Color.WHITE
	target_ring.default_color.a = 0.9
	target_ring.points = PackedVector2Array(ring_points)
	add_child(target_ring)

	# Animate everything
	var tween = create_tween()
	tween.set_parallel(true)

	# Ring expands from base
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)

	# Arrow fades
	tween.tween_property(arrow_line, "modulate:a", 0.0, 0.6)

	# Label pops and fades
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)

	# Target ring expands
	tween.tween_property(target_ring, "scale", Vector2(4, 4), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_ring, "modulate:a", 0.0, 0.4)

	# Cleanup
	tween.tween_callback(func():
		ring.queue_free()
		arrow_line.queue_free()
		label.queue_free()
		target_ring.queue_free()
	).set_delay(0.8)


func _update_rally_line(from_pos: Vector2, to_pos: Vector2):
	rally_line.clear_points()

	# Simple line with arrow markers
	rally_line.add_point(from_pos)
	rally_line.add_point(to_pos)

	# Add arrow head at destination
	var direction = (to_pos - from_pos).normalized()
	var arrow_size = 15.0
	var arrow_left = to_pos - direction * arrow_size + direction.rotated(PI * 0.7) * arrow_size * 0.6
	var arrow_right = to_pos - direction * arrow_size + direction.rotated(-PI * 0.7) * arrow_size * 0.6

	rally_line.add_point(to_pos)
	rally_line.add_point(arrow_left)
	rally_line.add_point(to_pos)
	rally_line.add_point(arrow_right)

	rally_line.visible = true


func _setup_ai():
	ai_controller = AiController.new()
	ai_controller.name = "AiController"
	add_child(ai_controller)
	ai_controller.init(store, _get_base_positions())

func _get_base_positions() -> Dictionary:
	var positions = {}
	for team in base_nodes:
		positions[team] = base_nodes[team].position
	return positions

func _on_energy_regen():
	if showing_victory:
		return

	for team in VnpTypes.Team.values():
		# Progenitor doesn't get energy - it spawns drones via convergence
		if team == VnpTypes.Team.PROGENITOR:
			continue
		var amount = ENERGY_REGEN_RATE
		if team == VnpTypes.Team.NEMESIS:
			amount = int(amount * NEMESIS_ENERGY_MULTIPLIER)
		store.dispatch({
			"type": "ADD_ENERGY",
			"team": team,
			"amount": amount
		})

func _on_victory_check():
	if showing_victory:
		return
	store.dispatch({"type": "CHECK_VICTORY"})

func _on_planet_income():
	if showing_victory:
		return
	store.dispatch({"type": "PLANET_INCOME"})
	_check_planet_capture()


func _on_strategic_point_income():
	if showing_victory:
		return
	store.dispatch({"type": "STRATEGIC_POINT_INCOME"})
	_check_strategic_point_capture()


func _on_expansion_tick():
	if showing_victory:
		return
	var state = store.get_state()
	if state == null or not state.has("expansion"):
		return
	var current_phase = state.expansion.phase
	var max_phase = state.expansion.max_phase

	var convergence_phase = state.convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)
	var is_converging = convergence_phase >= VnpTypes.ConvergencePhase.EMERGENCE

	if is_converging:
		# During convergence: slide the map instead of expanding
		_slide_convergence_center()
		return

	if current_phase >= max_phase:
		expansion_timer.stop()
		return

	store.dispatch({"type": "EXPAND_WORLD"})

	# Spawn new strategic points in the expanded area
	_spawn_expansion_points(current_phase + 1)


# Convergence slide tracking
var convergence_slide_direction: Vector2 = Vector2.ZERO
var convergence_slide_count: int = 0

func _slide_convergence_center():
	"""Slide the convergence center in a direction - pushing players"""
	var state = store.get_state()
	if state == null or not state.has("convergence"):
		return
	var convergence = state.convergence
	var center = convergence.get("center", gameplay_center)

	# Pick or maintain slide direction
	if convergence_slide_direction == Vector2.ZERO or convergence_slide_count >= 3:
		# Pick new random direction, biased away from edges
		var angle = randf() * TAU
		convergence_slide_direction = Vector2(cos(angle), sin(angle))
		convergence_slide_count = 0

	convergence_slide_count += 1

	# Calculate slide amount (significant push)
	var slide_amount = 80.0  # Pixels per slide tick

	# Calculate new center
	var new_center = center + convergence_slide_direction * slide_amount

	# Keep center within world bounds (symmetric around gameplay_center)
	var padding = 200.0
	var half_extent = world_size / 2
	var min_bound = gameplay_center - half_extent + Vector2(padding, padding)
	var max_bound = gameplay_center + half_extent - Vector2(padding, padding)
	new_center.x = clamp(new_center.x, min_bound.x, max_bound.x)
	new_center.y = clamp(new_center.y, min_bound.y, max_bound.y)

	# If we hit an edge, reverse that axis
	if new_center.x <= min_bound.x or new_center.x >= max_bound.x:
		convergence_slide_direction.x *= -1
	if new_center.y <= min_bound.y or new_center.y >= max_bound.y:
		convergence_slide_direction.y *= -1

	# Dispatch the slide
	store.dispatch({
		"type": "CONVERGENCE_SLIDE",
		"new_center": new_center
	})

	# Visual effect - show push direction
	_show_convergence_slide_effect(center, new_center)

	# Screen shake
	shake_screen(8.0)


func _show_convergence_slide_effect(old_center: Vector2, new_center: Vector2):
	"""Visual effect showing the void pushing"""
	var direction = (new_center - old_center).normalized()

	# Create arrow/wave effect from the pushing edge
	var push_origin = old_center - direction * 400  # From behind

	# Wave lines pushing inward
	for i in range(3):
		var offset = direction.rotated(PI/2) * (i - 1) * 150
		var line = Line2D.new()
		line.width = 6.0 - i
		line.default_color = VnpTypes.PROGENITOR_ACCENT
		line.default_color.a = 0.7 - i * 0.2
		line.add_point(push_origin + offset)
		line.add_point(push_origin + offset + direction * 200)
		add_child(line)

		# Animate forward and fade
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(line, "position", direction * 300, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(line, "modulate:a", 0.0, 0.8)
		tween.tween_callback(func(): line.queue_free()).set_delay(0.9)


# === THE CYCLE - CONVERGENCE PROCESSING ===

func _on_convergence_tick():
	"""Main convergence processing - handles The Progenitor's arrival and the shrinking world"""
	if showing_victory:
		return

	var state = store.get_state()
	if state == null or not state.has("convergence"):
		return

	var convergence = state.convergence
	var current_phase = convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)
	var timing = VnpTypes.CONVERGENCE_TIMING

	# Update game timer
	convergence_game_timer += 0.5  # Timer fires every 500ms

	# Update time in current phase
	store.dispatch({
		"type": "CONVERGENCE_UPDATE_TIME",
		"delta": 0.5
	})

	match current_phase:
		VnpTypes.ConvergencePhase.DORMANT:
			_process_dormant_phase(timing)

		VnpTypes.ConvergencePhase.WHISPERS:
			_process_whispers_phase(convergence, timing)

		VnpTypes.ConvergencePhase.CONTACT:
			_process_contact_phase(convergence, timing)

		VnpTypes.ConvergencePhase.EMERGENCE:
			_process_emergence_phase(convergence, timing)

		VnpTypes.ConvergencePhase.CRITICAL:
			_process_critical_phase(convergence, timing)

		VnpTypes.ConvergencePhase.FRAGMENTATION:
			pass  # Game over handled elsewhere


func _process_dormant_phase(timing: Dictionary):
	"""Check if it's time to begin The Whispers"""
	# Trigger whispers after 5 expansions OR when total ships exceed threshold
	var state = store.get_state()
	if state == null or not state.has("expansion"):
		return
	var expansion_phase = state.expansion.phase
	var total_ships = state.ships.size()

	# Trigger after 5 expansions and 50 ships - gives time to build up
	if expansion_phase >= 5 and total_ships >= 50:
		_transition_to_whispers()


func _transition_to_whispers():
	"""Begin the whispers phase - subtle warnings at edge"""
	store.dispatch({
		"type": "CONVERGENCE_SET_PHASE",
		"phase": VnpTypes.ConvergencePhase.WHISPERS
	})
	# Subtle screen disturbance
	shake_screen(2.0)


func _process_whispers_phase(convergence: Dictionary, timing: Dictionary):
	"""Edge anomalies appear, building tension"""
	var time_in_phase = convergence.get("time_in_phase", 0.0)

	# Random edge disturbances
	if randf() < 0.1:  # 10% chance each tick
		shake_screen(1.5)

	# After duration, first ship gets absorbed -> CONTACT
	if time_in_phase >= timing["whispers_duration"]:
		_transition_to_contact()


func _transition_to_contact():
	"""First ship absorbed - ??? DETECTED"""
	# Initialize convergence center and radius
	store.dispatch({
		"type": "CONVERGENCE_INITIALIZE",
		"center": gameplay_center,
		"radius": world_size.x * 0.6  # Start absorption zone at 60% of world
	})

	store.dispatch({
		"type": "CONVERGENCE_SET_PHASE",
		"phase": VnpTypes.ConvergencePhase.CONTACT
	})

	# Show mystery card
	if vnp_ui and vnp_ui.has_method("show_mystery_card"):
		vnp_ui.show_mystery_card()
	mystery_card_shown = true

	# Big screen shake
	shake_screen(10.0)

	# Setup visual ring for absorption zone
	_setup_convergence_visuals()


func _process_contact_phase(convergence: Dictionary, timing: Dictionary):
	"""Brief pause for ??? reveal before emergence"""
	var time_in_phase = convergence.get("time_in_phase", 0.0)

	if time_in_phase >= timing["contact_duration"]:
		_transition_to_emergence()


func _transition_to_emergence():
	"""The Progenitor manifests - gravitational pull begins"""
	store.dispatch({
		"type": "CONVERGENCE_SET_PHASE",
		"phase": VnpTypes.ConvergencePhase.EMERGENCE
	})

	store.dispatch({
		"type": "CONVERGENCE_REVEAL_PROGENITOR"
	})

	# Reveal the name
	if vnp_ui and vnp_ui.has_method("reveal_progenitor"):
		vnp_ui.reveal_progenitor()
	progenitor_revealed = true

	# Massive screen shake
	shake_screen(20.0)


func _process_emergence_phase(convergence: Dictionary, timing: Dictionary):
	"""The convergence is active - zone shrinks, ships get absorbed, drones hunt"""
	var absorption_radius = convergence.get("absorption_radius", 1000.0)
	var original_radius = convergence.get("original_radius", 1000.0)
	var critical_threshold = original_radius * timing["critical_radius_percent"]

	# Shrink absorption zone
	var shrink_amount = timing["shrink_rate_base"] * 0.5  # Per tick (500ms)
	store.dispatch({
		"type": "CONVERGENCE_SHRINK",
		"amount": shrink_amount
	})

	# Spawn Progenitor drones from the void edge
	progenitor_spawn_timer += 0.5  # Tick is 500ms
	if progenitor_spawn_timer >= PROGENITOR_SPAWN_INTERVAL:
		progenitor_spawn_timer = 0.0
		_spawn_progenitor_drones(convergence)

	# Check for ships outside absorption zone
	_check_ship_absorption(convergence)

	# Check for critical phase transition
	if absorption_radius <= critical_threshold:
		_transition_to_critical()


func _spawn_progenitor_drones(convergence: Dictionary):
	"""Spawn massive visible wave of ancient VNP probes from all directions - THE WALL OF DEATH"""
	progenitor_wave_count += 1

	# Get current safe zone center to spawn AROUND where the action is
	var spawn_center = convergence.get("center", gameplay_center)
	var safe_radius = convergence.get("absorption_radius", world_size.length() * 0.5)

	# Escalating threat - more drones each wave (using configured base from VnpTypes)
	var drones_base = VnpTypes.PROGENITOR_DRONES_BASE if "PROGENITOR_DRONES_BASE" in VnpTypes else PROGENITOR_DRONES_PER_WAVE
	var drones_this_wave = drones_base + (progenitor_wave_count * PROGENITOR_ESCALATION_RATE)
	# Spawn at the edge of the safe zone - forms visible closing wall
	var spawn_radius = safe_radius * 1.1  # Just beyond the safe zone

	# Spawn from multiple sectors simultaneously - creates visible surrounding wall
	var sector_angle = TAU / PROGENITOR_WAVE_SECTORS
	var base_angle = randf() * TAU  # Randomize starting angle each wave

	for sector in range(PROGENITOR_WAVE_SECTORS):
		var sector_center_angle = base_angle + sector * sector_angle
		var drones_in_sector = drones_this_wave / PROGENITOR_WAVE_SECTORS

		for i in range(drones_in_sector):
			# Spread within sector for wall-like formation
			var angle_spread = (float(i) / max(drones_in_sector, 1) - 0.5) * sector_angle * 0.85
			var spawn_angle = sector_center_angle + angle_spread

			# Spawn position just beyond safe zone - forms visible closing ring
			var spawn_pos = spawn_center + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_radius

			# Slight position randomness for organic feel
			spawn_pos += Vector2(randf_range(-20, 20), randf_range(-20, 20))

			# Spawn the ancient probe - they'll immediately start hunting inward
			store.dispatch({
				"type": "BUILD_SHIP",
				"team": VnpTypes.Team.PROGENITOR,
				"ship_type": VnpTypes.ShipType.PROGENITOR_DRONE,
				"position": spawn_pos
			})

	# Visual effect - void emergence from all sectors
	_show_void_wave_effect(base_angle)

	# Moderate screen shake - fewer but heavier arrivals
	shake_screen(3.0 + progenitor_wave_count * 0.3)


func _show_void_wave_effect(base_angle: float):
	"""Visual effect showing ancient probes emerging from all directions"""
	var spawn_radius = world_size.length() * 0.6
	var void_color = VnpTypes.PROGENITOR_ACCENT
	var pulse_color = VnpTypes.PROGENITOR_PULSE

	# Create wave pulse rings from each sector
	for sector in range(PROGENITOR_WAVE_SECTORS):
		var angle = base_angle + sector * (TAU / PROGENITOR_WAVE_SECTORS)
		var sector_center = gameplay_center + Vector2(cos(angle), sin(angle)) * spawn_radius

		# Expanding ring at spawn point
		var ring = Line2D.new()
		ring.width = 3.0
		ring.default_color = pulse_color
		var ring_points = []
		for i in range(17):
			var ring_angle = i * (PI * 2 / 16)
			ring_points.append(sector_center + Vector2(cos(ring_angle), sin(ring_angle)) * 10)
		ring.points = PackedVector2Array(ring_points)
		add_child(ring)

		# Expand and fade
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2(8, 8), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): ring.queue_free()).set_delay(0.7)

	# Warning lines pointing inward - "THEY'RE COMING"
	for i in range(12):
		var angle = randf() * TAU
		var start_pos = gameplay_center + Vector2(cos(angle), sin(angle)) * spawn_radius
		var end_pos = gameplay_center + Vector2(cos(angle), sin(angle)) * (spawn_radius - 100)

		var warning_line = Line2D.new()
		warning_line.width = 2.0
		warning_line.default_color = void_color
		warning_line.add_point(start_pos)
		warning_line.add_point(end_pos)
		add_child(warning_line)

		# Animate inward and fade
		var line_tween = create_tween()
		line_tween.set_parallel(true)
		line_tween.tween_property(warning_line, "position", Vector2(cos(angle), sin(angle)) * -50, 0.4)
		line_tween.tween_property(warning_line, "modulate:a", 0.0, 0.4)
		line_tween.tween_callback(func(): warning_line.queue_free()).set_delay(0.5)


func _show_void_emergence_effect(center: Vector2, radius: float):
	"""Visual effect when drones emerge from the void (legacy)"""
	# Create brief tendril lines from edge inward
	for i in range(8):
		var angle = randf() * TAU
		var start_pos = center + Vector2(cos(angle), sin(angle)) * (radius + 30)
		var end_pos = center + Vector2(cos(angle), sin(angle)) * (radius - 50)

		var tendril = Line2D.new()
		tendril.width = 4.0
		tendril.default_color = VnpTypes.PROGENITOR_ACCENT
		tendril.default_color.a = 0.8
		tendril.add_point(start_pos)
		tendril.add_point(end_pos)
		add_child(tendril)

		# Fade out
		var tween = create_tween()
		tween.tween_property(tendril, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): tendril.queue_free())


func _transition_to_critical():
	"""Near fragmentation - intense pull, faster shrink"""
	store.dispatch({
		"type": "CONVERGENCE_SET_PHASE",
		"phase": VnpTypes.ConvergencePhase.CRITICAL
	})

	# Intense screen shake
	shake_screen(15.0)


func _process_critical_phase(convergence: Dictionary, timing: Dictionary):
	"""Critical mass approaching - check for fragmentation"""
	var instability = convergence.get("instability", 0.0)

	# Faster shrink in critical phase
	var shrink_amount = timing["shrink_rate_critical"] * 0.5
	store.dispatch({
		"type": "CONVERGENCE_SHRINK",
		"amount": shrink_amount
	})

	# Natural instability growth in critical phase (configurable - slow by default)
	var natural_rate = timing.get("instability_natural_rate", 0.5)
	store.dispatch({
		"type": "CONVERGENCE_ADD_INSTABILITY",
		"amount": natural_rate
	})

	# Check for ship absorption
	_check_ship_absorption(convergence)

	# Check for fragmentation
	if instability >= timing["instability_threshold"]:
		_trigger_fragmentation()


func _check_ship_absorption(convergence: Dictionary):
	"""Absorb ships and outposts that escape FAR beyond the drone spawn zone.
	The drones are the real threat - this is just a failsafe for extreme escapees."""
	var center = convergence.get("center", Vector2.ZERO)
	var radius = convergence.get("absorption_radius", 1000.0)
	# Only absorb ships that go 50% BEYOND the spawn zone - drones should catch them first
	var hard_absorption_radius = radius * 1.5
	var state = store.get_state()
	if state == null or not state.has("ships"):
		return

	var ships_to_absorb = []
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		# Skip Progenitor drones - they don't get absorbed
		if ship.get("team") == VnpTypes.Team.PROGENITOR:
			continue
		# Use real position from node if available
		var ship_pos = ship.position
		if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
			ship_pos = ship_nodes[ship_id].global_position

		var dist = ship_pos.distance_to(center)
		# Only absorb if FAR beyond the drone spawn zone
		if dist > hard_absorption_radius:
			ships_to_absorb.append(ship_id)

	# Absorb ships (with visual effect)
	for ship_id in ships_to_absorb:
		_absorb_ship(ship_id)

	# Check outposts outside hard absorption zone
	var outposts_to_absorb = []
	for point_id in state.outposts:
		if state.strategic_points.has(point_id):
			var point_pos = state.strategic_points[point_id].position
			var dist = point_pos.distance_to(center)
			if dist > hard_absorption_radius:
				outposts_to_absorb.append(point_id)

	# Absorb outposts
	for point_id in outposts_to_absorb:
		_absorb_outpost(point_id)


func _absorb_ship(ship_id: int):
	"""Ship consumed by The Progenitor"""
	# Create absorption effect at ship location
	if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
		var ship_node = ship_nodes[ship_id]
		_create_absorption_effect(ship_node.global_position)

	# Dispatch absorption action
	store.dispatch({
		"type": "CONVERGENCE_ABSORB_SHIP",
		"ship_id": ship_id
	})

	# Add instability from absorption
	store.dispatch({
		"type": "CONVERGENCE_ADD_INSTABILITY",
		"amount": 1.0
	})

	# Small screen shake
	shake_screen(3.0)


func _absorb_outpost(point_id: String):
	"""Outpost consumed by The Progenitor"""
	var state = store.get_state()
	if state == null or not state.has("strategic_points"):
		return

	# Create absorption effect at outpost location
	if state.strategic_points.has(point_id):
		var point_pos = state.strategic_points[point_id].position
		_create_absorption_effect(point_pos)

	# Remove outpost visual
	if outpost_nodes.has(point_id) and is_instance_valid(outpost_nodes[point_id]):
		outpost_nodes[point_id].queue_free()
		outpost_nodes.erase(point_id)

	# Dispatch destruction
	store.dispatch({
		"type": "OUTPOST_DESTROY",
		"point_id": point_id
	})

	# Outposts add more instability (bigger structures)
	store.dispatch({
		"type": "CONVERGENCE_ADD_INSTABILITY",
		"amount": 3.0
	})

	# Bigger screen shake for outpost
	shake_screen(6.0)


func _create_absorption_effect(pos: Vector2):
	"""Visual effect when ship is absorbed"""
	# Create a quick particle burst toward center
	var state = store.get_state()
	var center = state.convergence.get("center", gameplay_center)

	# Reuse death explosion effect but tinted purple
	if explosion_count_this_frame < MAX_EXPLOSIONS_PER_FRAME:
		var effect = DeathExplosionFxScene.instantiate()
		effect.global_position = pos
		effect.modulate = VnpTypes.PROGENITOR_ACCENT
		add_child(effect)
		explosion_count_this_frame += 1


func _trigger_fragmentation():
	"""The Progenitor shatters - cycle continues"""
	store.dispatch({
		"type": "CONVERGENCE_FRAGMENTATION"
	})

	# Massive screen shake
	shake_screen(30.0)

	# Show victory/cycle screen
	if vnp_ui and vnp_ui.has_method("show_cycle_ending"):
		vnp_ui.show_cycle_ending()


func _setup_convergence_visuals():
	"""Setup visual elements for the convergence zone - subtle hint, drones are the real threat"""
	# Create subtle spawn zone indicator (very thin, dashed)
	if not convergence_visual_ring:
		convergence_visual_ring = Line2D.new()
		convergence_visual_ring.name = "ConvergenceRing"
		convergence_visual_ring.width = 1.5  # Very thin - just a hint
		convergence_visual_ring.default_color = VnpTypes.PROGENITOR_ACCENT
		convergence_visual_ring.z_index = 0  # Behind everything
		add_child(convergence_visual_ring)


func _update_convergence_visuals():
	"""Update convergence visual elements each frame - subtle dashed line showing spawn zone"""
	var state = store.get_state()
	if state == null or not state.has("convergence"):
		return

	var convergence = state.convergence
	var phase = convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)

	# Only draw during active phases
	if phase < VnpTypes.ConvergencePhase.EMERGENCE:
		if convergence_visual_ring:
			convergence_visual_ring.visible = false
		return

	var center = convergence.get("center", gameplay_center)
	var radius = convergence.get("absorption_radius", 1000.0)

	# Draw very subtle dashed spawn zone indicator (NOT the threat - just where drones emerge)
	if convergence_visual_ring:
		convergence_visual_ring.visible = true
		convergence_visual_ring.clear_points()

		# Breathing effect
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.001) * 0.02
		var draw_radius = radius * pulse

		# Draw dashed circle (gaps show this is just an indicator, not a wall)
		var segments = 48
		var dash_on = true
		for i in range(segments + 1):
			if i % 4 == 0:  # Toggle every 4 segments for dashed effect
				dash_on = not dash_on
				if not dash_on:
					# Start new dash with a gap
					convergence_visual_ring.add_point(Vector2.INF)  # Break the line
			if dash_on:
				var angle = (float(i) / segments) * TAU
				var point = center + Vector2(cos(angle), sin(angle)) * draw_radius
				convergence_visual_ring.add_point(point)

		# Very transparent - just a subtle hint
		convergence_visual_ring.default_color = Color(
			VnpTypes.PROGENITOR_ACCENT.r,
			VnpTypes.PROGENITOR_ACCENT.g,
			VnpTypes.PROGENITOR_ACCENT.b,
			0.25  # Very subtle
		)


func shake_screen(intensity: float):
	shake_intensity = max(shake_intensity, intensity)


# === OUTPOST SYSTEM - Harvester Factory Building ===

func _on_outpost_tick():
	"""Main outpost processing - harvester building and frigate production"""
	if showing_victory:
		return

	var state = store.get_state()
	if state == null or not state.has("ships"):
		return

	# Check for harvesters at owned strategic points (building outposts)
	_check_harvester_building(state)

	# Update production timers
	store.dispatch({
		"type": "OUTPOST_UPDATE_PRODUCTION",
		"delta": 0.5  # Timer fires every 500ms
	})

	# Check for completed outposts ready to produce
	_check_outpost_production(state)

	# Update outpost visuals
	_update_outpost_visuals(state)


func _check_harvester_building(state: Dictionary):
	"""Check if harvesters are at owned strategic points to build outposts"""
	var config = VnpTypes.FACTORY_CONFIG
	var build_radius = config["build_radius"]

	# Track which points have harvesters this tick
	var points_with_harvesters = {}  # point_id -> { team, harvester_id }

	# Find all harvesters and check if they're at owned points
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.type != VnpTypes.ShipType.HARVESTER:
			continue

		var ship_pos = ship.position
		# Use actual node position if available (more accurate)
		if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
			ship_pos = ship_nodes[ship_id].global_position

		# Check each strategic point
		for point_id in state.strategic_points:
			var point = state.strategic_points[point_id]
			var point_owner = point.get("owner", null)

			# Skip if point not owned by harvester's team
			if point_owner != ship.team:
				continue

			# Skip if already has complete outpost (regardless of team)
			if state.outposts.has(point_id) and state.outposts[point_id].get("complete", false):
				continue

			var point_pos = point.position
			var dist = ship_pos.distance_to(point_pos)

			if dist < build_radius:
				points_with_harvesters[point_id] = {
					"team": ship.team,
					"harvester_id": ship_id
				}
				break  # Harvester can only build at one point

	# Start building at new points
	for point_id in points_with_harvesters:
		var data = points_with_harvesters[point_id]
		if not state.outposts.has(point_id):
			store.dispatch({
				"type": "OUTPOST_START_BUILD",
				"point_id": point_id,
				"team": data.team
			})
			harvester_build_progress[point_id] = data.harvester_id

	# Update progress for ongoing builds
	for point_id in state.outposts:
		var outpost = state.outposts[point_id]
		if outpost.get("complete", false):
			continue

		if points_with_harvesters.has(point_id):
			# Harvester still there - progress build
			store.dispatch({
				"type": "OUTPOST_UPDATE_BUILD",
				"point_id": point_id,
				"delta": 0.5  # Timer fires every 500ms
			})

			# Check if just completed
			var new_progress = outpost["build_progress"] + 0.5
			if new_progress >= VnpTypes.FACTORY_CONFIG["build_time"]:
				_create_outpost_visual(point_id, outpost["team"])
				# Screen shake for completion
				shake_screen(5.0)
				if sound_manager:
					sound_manager.play_capture()
		else:
			# Harvester left - cancel build
			store.dispatch({
				"type": "OUTPOST_CANCEL_BUILD",
				"point_id": point_id
			})
			harvester_build_progress.erase(point_id)


func _check_outpost_production(state: Dictionary):
	"""Spawn frigates from complete outposts"""
	var config = VnpTypes.FACTORY_CONFIG
	var production_interval = config["production_interval"]

	for point_id in state.outposts:
		var outpost = state.outposts[point_id]
		if not outpost.get("complete", false):
			continue

		var production_timer = outpost.get("production_timer", 0.0)
		if production_timer >= production_interval:
			# Time to spawn a frigate!
			var team = outpost["team"]
			var point_pos = Vector2.ZERO

			# Get point position
			if state.strategic_points.has(point_id):
				point_pos = state.strategic_points[point_id].position

			# Spawn position with small offset
			var spawn_pos = point_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))

			# Build a frigate (free - no energy/mass cost from outpost)
			store.dispatch({
				"type": "BUILD_SHIP",
				"team": team,
				"ship_type": VnpTypes.ShipType.FRIGATE,
				"position": spawn_pos
			})

			# Reset production timer
			store.dispatch({
				"type": "OUTPOST_PRODUCE",
				"point_id": point_id
			})

			# Visual feedback
			_show_outpost_spawn_effect(point_pos, team)


func _create_outpost_visual(point_id: String, team: int):
	"""Create visual representation of a completed outpost"""
	var state = store.get_state()
	if state == null or not state.has("strategic_points") or not state.strategic_points.has(point_id):
		return

	var point_pos = state.strategic_points[point_id].position
	var config = VnpTypes.FACTORY_CONFIG

	# Create outpost structure
	var outpost_node = Node2D.new()
	outpost_node.name = "Outpost_" + point_id
	outpost_node.position = point_pos
	outpost_node.z_index = 3

	# Factory structure - small hexagonal building
	var factory = Polygon2D.new()
	var hex_points = []
	for i in range(6):
		var angle = i * (PI * 2 / 6) + PI / 6
		hex_points.append(Vector2(cos(angle), sin(angle)) * 25 * config["visual_scale"])
	factory.polygon = PackedVector2Array(hex_points)
	factory.color = VnpTypes.get_team_color(team)
	factory.color.a = 0.8
	outpost_node.add_child(factory)

	# Inner core
	var core = Polygon2D.new()
	var core_points = []
	for i in range(6):
		var angle = i * (PI * 2 / 6) + PI / 6
		core_points.append(Vector2(cos(angle), sin(angle)) * 12 * config["visual_scale"])
	core.polygon = PackedVector2Array(core_points)
	core.color = VnpTypes.get_team_color(team).lightened(0.3)
	outpost_node.add_child(core)

	# Production ring indicator
	var ring = Line2D.new()
	ring.name = "ProductionRing"
	ring.width = 2.0
	ring.default_color = VnpTypes.get_team_color(team)
	var ring_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 35 * config["visual_scale"])
	ring.points = PackedVector2Array(ring_points)
	outpost_node.add_child(ring)

	add_child(outpost_node)
	outpost_nodes[point_id] = outpost_node

	# Fade in effect
	outpost_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(outpost_node, "modulate:a", 1.0, 0.5)


func _update_outpost_visuals(state: Dictionary):
	"""Update outpost visuals based on state"""
	# Remove visuals for destroyed outposts
	var to_remove = []
	for point_id in outpost_nodes:
		if not state.outposts.has(point_id) or not state.outposts[point_id].get("complete", false):
			to_remove.append(point_id)

	for point_id in to_remove:
		if is_instance_valid(outpost_nodes[point_id]):
			outpost_nodes[point_id].queue_free()
		outpost_nodes.erase(point_id)

	# Update production indicator pulse for complete outposts
	for point_id in state.outposts:
		var outpost = state.outposts[point_id]
		if not outpost.get("complete", false):
			continue

		if not outpost_nodes.has(point_id):
			# Visual missing - recreate it
			_create_outpost_visual(point_id, outpost["team"])
			continue

		var outpost_node = outpost_nodes[point_id]
		if not is_instance_valid(outpost_node):
			continue

		# Pulse the production ring based on timer progress
		var ring = outpost_node.get_node_or_null("ProductionRing")
		if ring:
			var production_timer = outpost.get("production_timer", 0.0)
			var production_interval = VnpTypes.FACTORY_CONFIG["production_interval"]
			var progress = production_timer / production_interval
			var pulse = 0.5 + 0.5 * progress
			ring.modulate.a = pulse


func _show_outpost_spawn_effect(pos: Vector2, team: int):
	"""Visual effect when outpost spawns a frigate"""
	# Small expanding ring
	var ring = Line2D.new()
	ring.position = pos
	ring.width = 3.0
	ring.default_color = VnpTypes.get_team_color(team)
	var ring_points = []
	for i in range(17):
		var angle = i * (PI * 2 / 16)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 15)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Expand and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3, 3), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): ring.queue_free()).set_delay(0.5)


# ===================
# FACTORY SYSTEM
# ===================

func _on_factory_tick():
	"""Main factory processing - production from all factories"""
	if showing_victory:
		return

	var state = store.get_state()
	if state == null or not state.has("factories"):
		return

	# Check for harvesters camping to build new factories
	_check_harvester_factory_building(state)

	# Update production timers
	store.dispatch({
		"type": "FACTORY_UPDATE_PRODUCTION",
		"delta": 0.5  # Timer fires every 500ms
	})

	# Refresh state after dispatch
	state = store.get_state()

	# Check for factories ready to produce
	_check_factory_production(state)

	# Update factory visuals
	_update_factory_visuals(state)


func _check_harvester_factory_building(state: Dictionary):
	"""Check for harvesters camping to build factories anywhere"""
	var config = VnpTypes.FACTORY_CONFIG
	var build_time = config["build_time"]

	# Track which harvesters are still valid
	var active_harvesters = {}

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.type != VnpTypes.ShipType.HARVESTER:
			continue

		active_harvesters[ship_id] = true

		var ship_pos = ship.position
		# Use actual node position if available
		if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
			ship_pos = ship_nodes[ship_id].global_position

		# Check if harvester is already camping
		if harvester_camp_positions.has(ship_id):
			var camp_data = harvester_camp_positions[ship_id]
			var camp_pos = camp_data["position"]
			var dist_from_camp = ship_pos.distance_to(camp_pos)

			if dist_from_camp > HARVESTER_CAMP_TOLERANCE:
				# Harvester moved too far - reset camping
				if camp_data.has("pending_factory_id"):
					# Cancel the pending factory
					store.dispatch({
						"type": "FACTORY_DESTROY",
						"factory_id": camp_data["pending_factory_id"]
					})
				harvester_camp_positions.erase(ship_id)
			else:
				# Still camping - update time
				camp_data["time"] += 0.5

				# Check if we should start building (start quickly after 1 second)
				if camp_data["time"] >= 1.0 and not camp_data.has("pending_factory_id"):
					# Check if too close to existing factory
					var too_close = false
					for factory_id in state.factories:
						var factory = state.factories[factory_id]
						if factory_pos_distance(factory["position"], camp_pos) < 100:
							too_close = true
							break

					if not too_close:
						# Start building a factory here
						store.dispatch({
							"type": "FACTORY_CREATE",
							"team": ship.team,
							"position": camp_pos,
							"complete": false,
							"build_progress": 0.0,
						})
						# Get the factory ID we just created
						var new_state = store.get_state()
						var newest_id = str(new_state["next_factory_id"] - 1)
						camp_data["pending_factory_id"] = newest_id
						# Visual feedback - show build starting
						_show_factory_build_start(camp_pos, ship.team)

				elif camp_data.has("pending_factory_id"):
					# Update factory build progress
					store.dispatch({
						"type": "FACTORY_UPDATE_BUILD",
						"factory_id": camp_data["pending_factory_id"],
						"delta": 0.5
					})

					# Check if just completed
					var new_state = store.get_state()
					if new_state.factories.has(camp_data["pending_factory_id"]):
						var factory = new_state.factories[camp_data["pending_factory_id"]]
						if factory["complete"]:
							# Factory finished!
							shake_screen(5.0)
							if sound_manager:
								sound_manager.play_capture()
							harvester_camp_positions.erase(ship_id)
		else:
			# Start tracking this harvester's position
			harvester_camp_positions[ship_id] = {
				"position": ship_pos,
				"time": 0.0
			}

	# Clean up camping data for dead harvesters
	var to_remove = []
	for ship_id in harvester_camp_positions:
		if not active_harvesters.has(ship_id):
			var camp_data = harvester_camp_positions[ship_id]
			if camp_data.has("pending_factory_id"):
				store.dispatch({
					"type": "FACTORY_DESTROY",
					"factory_id": camp_data["pending_factory_id"]
				})
			to_remove.append(ship_id)

	for ship_id in to_remove:
		harvester_camp_positions.erase(ship_id)


func factory_pos_distance(pos1: Vector2, pos2: Vector2) -> float:
	"""Helper to calculate distance between positions"""
	return pos1.distance_to(pos2)


func _show_factory_build_start(pos: Vector2, team: int):
	"""Visual effect when factory construction begins"""
	var ring = Line2D.new()
	ring.position = pos
	ring.width = 2.0
	ring.default_color = VnpTypes.get_team_color(team)
	ring.default_color.a = 0.6
	var ring_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 40)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Pulse effect
	var tween = create_tween()
	tween.set_loops(0)  # Infinite loops until factory completes
	tween.tween_property(ring, "modulate:a", 0.3, 0.5)
	tween.tween_property(ring, "modulate:a", 0.8, 0.5)

	# Clean up after some time (factory should complete or cancel)
	await get_tree().create_timer(15.0).timeout
	if is_instance_valid(ring):
		ring.queue_free()


func _check_factory_production(state: Dictionary):
	"""Spawn ships from complete factories"""
	var config = VnpTypes.FACTORY_CONFIG
	var production_interval = config["production_interval"]

	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		if not factory.get("complete", false):
			continue

		var production_timer = factory.get("production_timer", 0.0)
		if production_timer >= production_interval:
			# Time to spawn a ship!
			var team = factory["team"]
			var factory_pos = factory["position"]
			var ship_type = factory.get("production_type", VnpTypes.ShipType.FRIGATE)

			# Spawn position with small offset
			var spawn_pos = factory_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))

			# Build the ship (free - no energy/mass cost from factory)
			store.dispatch({
				"type": "BUILD_SHIP",
				"team": team,
				"ship_type": ship_type,
				"position": spawn_pos
			})

			# Reset production timer
			store.dispatch({
				"type": "FACTORY_PRODUCE",
				"factory_id": factory_id
			})

			# Visual feedback
			_show_factory_spawn_effect(factory_pos, team)


func _create_factory_visual(factory_id: String, factory: Dictionary):
	"""Create visual representation of a factory"""
	var factory_pos = factory["position"]
	var team = factory["team"]
	var config = VnpTypes.FACTORY_CONFIG

	# Create factory structure
	var factory_node = Node2D.new()
	factory_node.name = "Factory_" + factory_id
	factory_node.position = factory_pos
	factory_node.z_index = 3

	# Factory structure - larger hexagonal building with industrial look
	var hex = Polygon2D.new()
	var hex_points = []
	for i in range(6):
		var angle = i * (PI * 2 / 6) + PI / 6
		hex_points.append(Vector2(cos(angle), sin(angle)) * 35 * config["visual_scale"])
	hex.polygon = PackedVector2Array(hex_points)
	hex.color = VnpTypes.get_team_color(team)
	hex.color.a = 0.9
	factory_node.add_child(hex)

	# Inner production core
	var core = Polygon2D.new()
	var core_points = []
	for i in range(6):
		var angle = i * (PI * 2 / 6) + PI / 6
		core_points.append(Vector2(cos(angle), sin(angle)) * 18 * config["visual_scale"])
	core.polygon = PackedVector2Array(core_points)
	core.color = VnpTypes.get_team_color(team).lightened(0.4)
	factory_node.add_child(core)

	# Production ring indicator
	var ring = Line2D.new()
	ring.name = "ProductionRing"
	ring.width = 3.0
	ring.default_color = VnpTypes.get_team_color(team)
	var ring_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 45 * config["visual_scale"])
	ring.points = PackedVector2Array(ring_points)
	factory_node.add_child(ring)

	# Factory icon/label showing production type
	var ship_label = Label.new()
	ship_label.name = "ProductionLabel"
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ship_type = factory.get("production_type", VnpTypes.ShipType.FRIGATE)
	var ship_stats = VnpTypes.SHIP_STATS.get(ship_type, {})
	ship_label.text = ship_stats.get("name", "?")[0]  # First letter
	ship_label.add_theme_font_size_override("font_size", 14)
	ship_label.add_theme_color_override("font_color", Color.WHITE)
	ship_label.position = Vector2(-6, -10)
	factory_node.add_child(ship_label)

	add_child(factory_node)
	factory_nodes[factory_id] = factory_node

	# Fade in effect
	factory_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(factory_node, "modulate:a", 1.0, 0.5)


func _update_factory_visuals(state: Dictionary):
	"""Update factory visuals based on state"""
	# Create visuals for new factories
	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		if not factory.get("complete", false):
			continue

		if not factory_nodes.has(factory_id):
			_create_factory_visual(factory_id, factory)

	# Remove visuals for destroyed factories
	var to_remove = []
	for factory_id in factory_nodes:
		if not state.factories.has(factory_id):
			to_remove.append(factory_id)

	for factory_id in to_remove:
		if is_instance_valid(factory_nodes[factory_id]):
			factory_nodes[factory_id].queue_free()
		factory_nodes.erase(factory_id)

	# Update production indicator pulse for complete factories
	var config = VnpTypes.FACTORY_CONFIG
	var production_interval = config["production_interval"]

	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		if not factory.get("complete", false):
			continue

		if not factory_nodes.has(factory_id):
			continue

		var factory_node = factory_nodes[factory_id]
		if not is_instance_valid(factory_node):
			continue

		# Pulse the production ring based on timer progress
		var ring = factory_node.get_node_or_null("ProductionRing")
		if ring:
			var production_timer = factory.get("production_timer", 0.0)
			var progress = production_timer / production_interval
			var pulse = 0.5 + 0.5 * progress
			ring.modulate.a = pulse


func _show_factory_spawn_effect(pos: Vector2, team: int):
	"""Visual effect when factory spawns a ship"""
	# Larger expanding ring for factory production
	var ring = Line2D.new()
	ring.position = pos
	ring.width = 4.0
	ring.default_color = VnpTypes.get_team_color(team)
	var ring_points = []
	for i in range(17):
		var angle = i * (PI * 2 / 16)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 25)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Expand and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3, 3), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): ring.queue_free()).set_delay(0.6)


func _check_planet_capture():
	# Ships near planets capture them for their team
	var state = store.get_state()
	if state == null or not state.has("planets"):
		return
	for planet_id in state.planets:
		var planet = state.planets[planet_id]
		var planet_pos = planet.position

		# Count ships near this planet per team
		var team_presence = {}
		for team in VnpTypes.Team.values():
			team_presence[team] = 0

		for ship_id in state.ships:
			var ship = state.ships[ship_id]
			# Use real ship node position (state may be stale due to throttled sync)
			var ship_pos = ship.position
			if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
				ship_pos = ship_nodes[ship_id].global_position
			var dist = ship_pos.distance_to(planet_pos)
			if dist < 80:  # Capture radius
				team_presence[ship.team] += 1

		# Team with most presence captures
		var best_team = -1
		var best_count = 0
		for team in team_presence:
			if team_presence[team] > best_count:
				best_count = team_presence[team]
				best_team = team

		# Must have at least 1 ship to capture
		if best_count > 0 and planet.get("owner", null) != best_team:
			store.dispatch({
				"type": "CAPTURE_PLANET",
				"planet_id": planet_id,
				"team": best_team
			})


func _check_strategic_point_capture():
	# Ships near strategic points capture them for their team
	var state = store.get_state()
	if state == null or not state.has("strategic_points"):
		return
	for point_id in state.strategic_points:
		var point = state.strategic_points[point_id]
		var point_pos = point.position

		# Count ships near this point per team
		var team_presence = {}
		for team in VnpTypes.Team.values():
			team_presence[team] = 0

		for ship_id in state.ships:
			var ship = state.ships[ship_id]
			# Use real ship node position (state may be stale due to throttled sync)
			var ship_pos = ship.position
			if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
				ship_pos = ship_nodes[ship_id].global_position
			var dist = ship_pos.distance_to(point_pos)
			if dist < 100:  # Capture radius for strategic points
				team_presence[ship.team] += 1

		# Team with most presence captures
		var best_team = -1
		var best_count = 0
		for team in team_presence:
			if team_presence[team] > best_count:
				best_count = team_presence[team]
				best_team = team

		# Must have at least 1 ship to capture
		if best_count > 0 and point.get("owner", null) != best_team:
			# Destroy any existing outpost at this point
			if state.outposts.has(point_id):
				store.dispatch({
					"type": "OUTPOST_CHANGE_OWNER",
					"point_id": point_id,
					"team": best_team
				})
				# Remove outpost visual
				if outpost_nodes.has(point_id) and is_instance_valid(outpost_nodes[point_id]):
					outpost_nodes[point_id].queue_free()
					outpost_nodes.erase(point_id)

			store.dispatch({
				"type": "CAPTURE_STRATEGIC_POINT",
				"point_id": point_id,
				"team": best_team
			})
			# Play capture sound
			if sound_manager:
				sound_manager.play_capture()


func on_state_changed(state):
	if state == null:
		return

	# Handle victory
	if state.get("game_over", false) and not showing_victory:
		_handle_victory(state.winner)
		return

	# Check for expansion phase change - UPDATE FIRST to prevent re-entrancy
	if not state.has("expansion"):
		return
	var current_phase = state.expansion.phase
	if current_phase > last_expansion_phase:
		last_expansion_phase = current_phase  # Prevent re-entry during dispatch
		_handle_expansion(state)

	# Update planet visuals based on ownership
	_update_planet_visuals(state)
	_update_strategic_point_visuals(state)

	var current_ship_ids = state.ships.keys()
	var nodes_to_remove = []
	for ship_id in ship_nodes:
		if not ship_id in current_ship_ids:
			nodes_to_remove.append(ship_id)

	for ship_id in nodes_to_remove:
		var ship_node = ship_nodes[ship_id]
		if is_instance_valid(ship_node):
			# Spawn explosion and shake screen based on ship size
			var ship_size = VnpTypes.get_ship_size(ship_node.ship_data.type)
			_spawn_death_explosion(ship_node.global_position, ship_size, ship_node.ship_data.team)

			ship_node.queue_free()
		ship_nodes.erase(ship_id)

	for ship_id in current_ship_ids:
		if not ship_nodes.has(ship_id):
			_spawn_ship(ship_id, state.ships[ship_id])

func _update_planet_visuals(state):
	for planet_id in state.planets:
		if planet_nodes.has(planet_id):
			var planet_node = planet_nodes[planet_id]
			var planet_data = state.planets[planet_id]
			var owner = planet_data.get("owner", null)

			var polygon = planet_node.get_child(0) as Polygon2D
			if polygon:
				if owner != null:
					# Color by owning team with a pulsing ring
					polygon.color = VnpTypes.get_team_color(owner)
					_ensure_capture_ring(planet_node, owner)
				else:
					polygon.color = Color.GRAY
					_remove_capture_ring(planet_node)

func _ensure_capture_ring(planet_node: Node2D, team: int):
	var ring_name = "CaptureRing"
	var existing = planet_node.get_node_or_null(ring_name)
	if existing:
		existing.default_color = VnpTypes.get_team_color(team)
		return

	# Create a ring around captured planet
	var ring = Line2D.new()
	ring.name = ring_name
	ring.width = 3.0
	ring.default_color = VnpTypes.get_team_color(team)

	# Circle points
	var points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		points.append(Vector2(cos(angle), sin(angle)) * 25)
	ring.points = PackedVector2Array(points)
	planet_node.add_child(ring)

func _remove_capture_ring(planet_node: Node2D):
	var ring = planet_node.get_node_or_null("CaptureRing")
	if ring:
		ring.queue_free()


func _update_strategic_point_visuals(state):
	for point_id in state.strategic_points:
		if strategic_point_nodes.has(point_id):
			var point_node = strategic_point_nodes[point_id]
			var point_data = state.strategic_points[point_id]
			var owner = point_data.get("owner", null)

			# Update the capture ring color
			var ring = point_node.get_node_or_null("CaptureRing")
			if ring:
				if owner != null:
					ring.default_color = VnpTypes.get_team_color(owner)
					ring.modulate.a = 1.0
				else:
					ring.default_color = Color.GRAY
					ring.modulate.a = 0.5


func _spawn_death_explosion(pos: Vector2, size: int, team: int):
	# Rate limit explosions to prevent lag when tabbed back
	if explosion_count_this_frame >= MAX_EXPLOSIONS_PER_FRAME:
		return
	explosion_count_this_frame += 1

	var team_color = VnpTypes.get_team_color(team)

	# Scale explosion based on ship size - DRAMATIC
	var shake_amounts = {
		VnpTypes.ShipSize.SMALL: 10.0,
		VnpTypes.ShipSize.MEDIUM: 25.0,
		VnpTypes.ShipSize.LARGE: 50.0,
		VnpTypes.ShipSize.MASSIVE: 100.0,
	}
	var scale_mults = {
		VnpTypes.ShipSize.SMALL: 1.0,
		VnpTypes.ShipSize.MEDIUM: 1.8,
		VnpTypes.ShipSize.LARGE: 3.0,
		VnpTypes.ShipSize.MASSIVE: 5.0,
	}
	var scale_mult = scale_mults.get(size, 1.0)

	# === LAYER 1: BRIGHT FLASH - Instant white burst ===
	var flash = Polygon2D.new()
	var flash_size = 30 * scale_mult
	var flash_points = []
	for i in range(9):
		var angle = i * (TAU / 8)
		flash_points.append(Vector2(cos(angle), sin(angle)) * flash_size)
	flash.polygon = PackedVector2Array(flash_points)
	flash.color = Color(1.0, 1.0, 0.95, 1.0)  # White-hot
	flash.global_position = pos
	add_child(flash)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.08).from(Vector2(0.3, 0.3))
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	flash_tween.tween_callback(func(): flash.queue_free())

	# === LAYER 2: FIRE CORE - Team-colored explosion ===
	var fire = Polygon2D.new()
	var fire_size = 25 * scale_mult
	var fire_points = []
	for i in range(13):
		var angle = i * (TAU / 12)
		var r = fire_size * randf_range(0.7, 1.0)
		fire_points.append(Vector2(cos(angle), sin(angle)) * r)
	fire.polygon = PackedVector2Array(fire_points)
	fire.color = Color(team_color.r * 1.5, team_color.g * 1.2, team_color.b * 0.8, 0.9)
	fire.global_position = pos
	add_child(fire)

	var fire_tween = create_tween()
	fire_tween.tween_property(fire, "scale", Vector2(3.0, 3.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fire_tween.parallel().tween_property(fire, "modulate:a", 0.0, 0.3)
	fire_tween.tween_callback(func(): fire.queue_free())

	# === LAYER 3: SHOCKWAVE RING - Expanding circle ===
	var ring = Line2D.new()
	ring.global_position = pos
	ring.width = 4.0 * scale_mult
	ring.default_color = Color(team_color.r, team_color.g, team_color.b, 0.8)
	var ring_points = []
	for i in range(33):
		var angle = i * (TAU / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 15)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	var ring_tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * (5.0 * scale_mult), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	ring_tween.tween_callback(func(): ring.queue_free())

	# === LAYER 4: SPARKS - Debris flying outward ===
	var spark_count = 6 + int(size * 3)
	for i in range(spark_count):
		var spark = Line2D.new()
		spark.global_position = pos
		spark.width = 2.0 + randf() * scale_mult
		spark.default_color = Color(1.0, team_color.g * 1.5, team_color.b * 0.5, 0.9)

		var angle = randf() * TAU
		var length = randf_range(8, 20) * scale_mult
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(cos(angle), sin(angle)) * length)
		add_child(spark)

		# Animate flying outward
		var end_pos = pos + Vector2(cos(angle), sin(angle)) * randf_range(40, 100) * scale_mult
		var spark_tween = create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", end_pos, randf_range(0.2, 0.4))
		spark_tween.tween_property(spark, "modulate:a", 0.0, randf_range(0.25, 0.4))
		spark_tween.tween_callback(func(): spark.queue_free())

	# === LAYER 5: SMOKE PUFF - Fading gray cloud ===
	if size >= VnpTypes.ShipSize.MEDIUM:
		var smoke = Polygon2D.new()
		var smoke_size = 20 * scale_mult
		var smoke_points = []
		for i in range(9):
			var angle = i * (TAU / 8)
			var r = smoke_size * randf_range(0.6, 1.0)
			smoke_points.append(Vector2(cos(angle), sin(angle)) * r)
		smoke.polygon = PackedVector2Array(smoke_points)
		smoke.color = Color(0.3, 0.3, 0.35, 0.5)
		smoke.global_position = pos
		add_child(smoke)

		var smoke_tween = create_tween()
		smoke_tween.tween_property(smoke, "scale", Vector2(4.0, 4.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		smoke_tween.parallel().tween_property(smoke, "modulate:a", 0.0, 0.7)
		smoke_tween.tween_callback(func(): smoke.queue_free())

	# === LAYER 6: SECONDARY FLASHES - Delayed mini-explosions for large+ ships ===
	if size >= VnpTypes.ShipSize.LARGE:
		var flash_count = 2 if size == VnpTypes.ShipSize.LARGE else 4
		for i in range(flash_count):
			var delay = 0.08 + i * 0.06
			var offset = Vector2(randf_range(-25, 25) * scale_mult, randf_range(-25, 25) * scale_mult)
			get_tree().create_timer(delay).timeout.connect(func():
				var secondary_flash = Polygon2D.new()
				var sf_size = 15 * scale_mult * randf_range(0.6, 1.0)
				var sf_points = []
				for j in range(7):
					var angle = j * (TAU / 6)
					sf_points.append(Vector2(cos(angle), sin(angle)) * sf_size)
				secondary_flash.polygon = PackedVector2Array(sf_points)
				secondary_flash.color = Color(1.0, 0.95, 0.85, 0.95)
				secondary_flash.global_position = pos + offset
				add_child(secondary_flash)

				var sf_tween = create_tween()
				sf_tween.tween_property(secondary_flash, "scale", Vector2(2.0, 2.0), 0.1).from(Vector2(0.5, 0.5))
				sf_tween.parallel().tween_property(secondary_flash, "modulate:a", 0.0, 0.12)
				sf_tween.tween_callback(func(): secondary_flash.queue_free())
			)

	# Also spawn the particle effect
	var explosion = DeathExplosionFxScene.instantiate()
	add_child(explosion)
	explosion.global_position = pos
	explosion.scale = Vector2.ONE * (2.0 * scale_mult)
	explosion.emitting = true

	shake_screen(shake_amounts.get(size, 5.0))

	# Play explosion sound
	if sound_manager:
		sound_manager.play_explosion(size)

	# For massive explosions, add secondary effects
	if size == VnpTypes.ShipSize.MASSIVE:
		_spawn_massive_destruction(pos, team)

func _spawn_massive_destruction(pos: Vector2, team: int):
	# Epic destruction sequence for Star Base death
	var team_color = VnpTypes.get_team_color(team)

	# Multiple secondary explosions in sequence
	for i in range(5):
		var delay = i * 0.15
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		get_tree().create_timer(delay).timeout.connect(func():
			var secondary = DeathExplosionFxScene.instantiate()
			add_child(secondary)
			secondary.global_position = pos + offset
			secondary.scale = Vector2.ONE * randf_range(3.0, 6.0)
			secondary.emitting = true
			shake_screen(30.0)
		)

	# Massive shockwave ring
	var ring = Line2D.new()
	ring.global_position = pos
	ring.width = 12.0
	ring.default_color = Color(team_color.r, team_color.g, team_color.b, 0.9)
	var ring_points = []
	for i in range(65):
		var angle = i * (PI * 2 / 64)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 20)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Expand the shockwave
	var ring_tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(20, 20), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 1.0)
	ring_tween.tween_callback(func(): ring.queue_free())


func _handle_victory(winner: int):
	showing_victory = true
	ai_controller.stop_all()

	var winner_name = VnpTypes.get_team_name(winner) if winner >= 0 else "No one"
	vnp_ui.show_victory(winner_name)

	# Wait then restart
	await get_tree().create_timer(VICTORY_DISPLAY_TIME).timeout
	_restart_game()

func _restart_game():
	showing_victory = false

	# Clear all ships
	for ship_id in ship_nodes:
		if is_instance_valid(ship_nodes[ship_id]):
			ship_nodes[ship_id].queue_free()
	ship_nodes.clear()

	# Clear all factories
	for factory_id in factory_nodes:
		if is_instance_valid(factory_nodes[factory_id]):
			factory_nodes[factory_id].queue_free()
	factory_nodes.clear()
	factory_build_progress.clear()

	# Clear all outposts
	for point_id in outpost_nodes:
		if is_instance_valid(outpost_nodes[point_id]):
			outpost_nodes[point_id].queue_free()
	outpost_nodes.clear()
	harvester_build_progress.clear()
	harvester_camp_positions.clear()

	# Reset base weapon cooldowns and charges
	for team in VnpTypes.Team.values():
		base_weapon_cooldowns[team] = 0.0
		base_charges[team] = 0

	# Reset state
	store.dispatch({"type": "RESET_GAME"})

	# Recreate starting factories at base positions
	for team in base_nodes:
		var base_pos = base_nodes[team].position
		_create_starting_factory(team, base_pos)

	# Reinitialize planets
	_create_planets()

	# Respawn base turrets for early game defense
	_spawn_base_turrets()

	# Restart AI
	ai_controller.start_all()

	vnp_ui.hide_victory()

func _initialize_game_world():
	# NOTE: This function is no longer called from _ready()
	# The init order is now explicit in _ready() to ensure ai_controller exists before ships spawn
	_create_starfield()
	_create_bases()
	_create_planets()
	_spawn_initial_starbases()

func _create_starfield():
	# Rich space background with multiple layers for depth
	starfield_node = Node2D.new()
	starfield_node.name = "Starfield"
	starfield_node.z_index = -100
	add_child(starfield_node)

	# Calculate max world extent (after all expansions) centered on gameplay_center
	var max_scale = WORLD_SCALE + (0.3 * 10)
	var max_half_extent = (screen_size * max_scale) / 2
	# Starfield bounds: gameplay_center ± max_half_extent (with extra padding)
	var star_min = gameplay_center - max_half_extent - Vector2(500, 500)
	var star_max = gameplay_center + max_half_extent + Vector2(500, 500)

	# === LAYER 1: Deep space gradient background ===
	var bg = Polygon2D.new()
	bg.polygon = PackedVector2Array([
		star_min,
		Vector2(star_max.x, star_min.y),
		star_max,
		Vector2(star_min.x, star_max.y)
	])
	bg.color = Color(0.02, 0.02, 0.06, 1.0)  # Deep space blue-black
	bg.z_index = -101
	add_child(bg)

	# Shorthand for star placement range
	var star_range = star_max - star_min

	# === LAYER 2: Large nebula clouds (centered around gameplay_center) ===
	var nebula_configs = [
		{"pos": star_min + star_range * Vector2(0.2, 0.3), "color": Color(0.4, 0.1, 0.5, 0.08), "size": 600},  # Purple
		{"pos": star_min + star_range * Vector2(0.7, 0.2), "color": Color(0.1, 0.3, 0.5, 0.07), "size": 500},  # Blue
		{"pos": star_min + star_range * Vector2(0.5, 0.7), "color": Color(0.5, 0.2, 0.3, 0.06), "size": 550},  # Pink/red
		{"pos": star_min + star_range * Vector2(0.8, 0.8), "color": Color(0.2, 0.4, 0.4, 0.05), "size": 450},  # Teal
		{"pos": star_min + star_range * Vector2(0.15, 0.75), "color": Color(0.3, 0.15, 0.4, 0.06), "size": 400},  # Violet
	]

	for config in nebula_configs:
		_create_nebula_cloud(config["pos"], config["color"], config["size"])

	# === LAYER 3: Distant tiny stars (hundreds) - spread across full area ===
	var tiny_star_count = 300
	for i in range(tiny_star_count):
		var star = Polygon2D.new()
		var size = randf_range(0.5, 1.2)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		# Vary star colors slightly
		var warmth = randf_range(-0.1, 0.1)
		star.color = Color(0.7 + warmth, 0.7, 0.8 - warmth, randf_range(0.2, 0.5))
		star.position = star_min + Vector2(randf() * star_range.x, randf() * star_range.y)
		starfield_node.add_child(star)

	# === LAYER 4: Medium stars with color variation ===
	var medium_star_count = 80
	var star_colors = [
		Color(1.0, 0.95, 0.9, 0.7),   # Warm white
		Color(0.9, 0.95, 1.0, 0.7),   # Cool white
		Color(1.0, 0.85, 0.7, 0.6),   # Orange tint
		Color(0.8, 0.9, 1.0, 0.7),    # Blue tint
		Color(1.0, 0.9, 0.95, 0.6),   # Pink tint
	]
	for i in range(medium_star_count):
		var star = Polygon2D.new()
		var size = randf_range(1.5, 2.5)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		star.color = star_colors[randi() % star_colors.size()]
		star.position = star_min + Vector2(randf() * star_range.x, randf() * star_range.y)
		starfield_node.add_child(star)

	# === LAYER 5: Bright prominent stars with glow ===
	var bright_star_count = 20
	for i in range(bright_star_count):
		var pos = star_min + Vector2(100, 100) + Vector2(randf() * (star_range.x - 200), randf() * (star_range.y - 200))
		_create_bright_star(pos, star_colors[randi() % star_colors.size()])

	# === LAYER 6: Distant galaxies (subtle) ===
	_create_distant_galaxy(star_min + star_range * Vector2(0.85, 0.15), 80, Color(0.6, 0.5, 0.7, 0.15))
	_create_distant_galaxy(star_min + star_range * Vector2(0.1, 0.5), 60, Color(0.5, 0.6, 0.7, 0.12))

	# === LAYER 7: Star clusters ===
	_create_star_cluster(star_min + star_range * Vector2(0.3, 0.4), 120, 40)
	_create_star_cluster(star_min + star_range * Vector2(0.6, 0.6), 100, 30)
	_create_star_cluster(star_min + star_range * Vector2(0.75, 0.35), 80, 25)


func _create_nebula_cloud(center: Vector2, color: Color, size: float):
	"""Create a soft nebula cloud with multiple overlapping layers"""
	# Create multiple overlapping polygons for soft edges
	for layer in range(3):
		var nebula = Polygon2D.new()
		var points = []
		var layer_size = size * (1.0 - layer * 0.25)
		var segments = 12
		for j in range(segments):
			var angle = j * (PI * 2 / segments)
			var r = layer_size * randf_range(0.6, 1.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		nebula.polygon = PackedVector2Array(points)
		var layer_color = color
		layer_color.a = color.a * (1.0 - layer * 0.3)
		nebula.color = layer_color
		nebula.z_index = -99 + layer
		add_child(nebula)


func _create_bright_star(pos: Vector2, color: Color):
	"""Create a bright star with a subtle glow effect"""
	# Outer glow
	var glow = Polygon2D.new()
	var glow_size = randf_range(8, 15)
	var glow_points = []
	for i in range(8):
		var angle = i * (PI * 2 / 8)
		var r = glow_size if i % 2 == 0 else glow_size * 0.4
		glow_points.append(Vector2(cos(angle), sin(angle)) * r)
	glow.polygon = PackedVector2Array(glow_points)
	glow.color = Color(color.r, color.g, color.b, 0.15)
	glow.position = pos
	starfield_node.add_child(glow)

	# Core star
	var star = Polygon2D.new()
	var size = randf_range(2.5, 4.0)
	star.polygon = PackedVector2Array([
		Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
	])
	star.color = color
	star.position = pos
	starfield_node.add_child(star)

	# Add subtle twinkle animation to some stars
	if randf() > 0.5:
		var tween = create_tween()
		tween.set_loops(0)
		var twinkle_time = randf_range(2.0, 5.0)
		tween.tween_property(star, "modulate:a", 0.5, twinkle_time)
		tween.tween_property(star, "modulate:a", 1.0, twinkle_time)


func _create_distant_galaxy(pos: Vector2, size: float, color: Color):
	"""Create a subtle distant galaxy spiral"""
	var galaxy = Node2D.new()
	galaxy.position = pos
	galaxy.z_index = -98

	# Galaxy core (bright center)
	var core = Polygon2D.new()
	var core_points = []
	for i in range(16):
		var angle = i * (PI * 2 / 16)
		core_points.append(Vector2(cos(angle), sin(angle)) * size * 0.3)
	core.polygon = PackedVector2Array(core_points)
	core.color = Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, color.a * 1.5)
	galaxy.add_child(core)

	# Spiral arms (simplified ellipse)
	var arms = Polygon2D.new()
	var arm_points = []
	for i in range(24):
		var angle = i * (PI * 2 / 24)
		var r = size * (0.8 + 0.2 * sin(angle * 2))
		arm_points.append(Vector2(cos(angle) * r, sin(angle) * r * 0.4))
	arms.polygon = PackedVector2Array(arm_points)
	arms.color = color
	arms.rotation = randf_range(0, PI)
	galaxy.add_child(arms)

	add_child(galaxy)


func _create_star_cluster(center: Vector2, radius: float, count: int):
	"""Create a dense cluster of stars"""
	for i in range(count):
		var star = Polygon2D.new()
		# Gaussian-like distribution - more stars toward center
		var dist = radius * sqrt(randf()) * randf_range(0.3, 1.0)
		var angle = randf() * PI * 2
		var offset = Vector2(cos(angle), sin(angle)) * dist

		var size = randf_range(0.8, 1.8)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		# Cluster stars are slightly bluer
		star.color = Color(0.85, 0.9, 1.0, randf_range(0.3, 0.7))
		star.position = center + offset
		starfield_node.add_child(star)

func _create_bases():
	# Bases positioned at corners of the larger world
	# Each base is now also a starting factory that produces ships
	var player_base_pos = Vector2(WORLD_PADDING, world_size.y - WORLD_PADDING)
	base_nodes[VnpTypes.Team.PLAYER] = _create_world_object("Base", player_base_pos, Color.BLUE)
	_create_starting_factory(VnpTypes.Team.PLAYER, player_base_pos)

	var enemy1_base_pos = Vector2(world_size.x - WORLD_PADDING, world_size.y - WORLD_PADDING)
	base_nodes[VnpTypes.Team.ENEMY_1] = _create_world_object("Base", enemy1_base_pos, Color.ORANGE)
	_create_starting_factory(VnpTypes.Team.ENEMY_1, enemy1_base_pos)

	var nemesis_base_pos = Vector2(world_size.x / 2, WORLD_PADDING)
	base_nodes[VnpTypes.Team.NEMESIS] = _create_world_object("Base", nemesis_base_pos, Color.RED)
	_create_starting_factory(VnpTypes.Team.NEMESIS, nemesis_base_pos)


func _create_starting_factory(team: int, position: Vector2):
	"""Create a starting factory at a base position"""
	store.dispatch({
		"type": "FACTORY_CREATE",
		"team": team,
		"position": position,
		"complete": true,  # Starting factories are pre-built
		"health": VnpTypes.FACTORY_CONFIG["health"] * 2,  # Starting factories are tougher
		"production_type": VnpTypes.ShipType.FRIGATE,  # Default production
	})


func _create_strategic_points():
	var points_data = {}
	var center = world_size / 2

	# CENTER POINT - The prize in the middle (Command Center)
	var center_id = "center"
	points_data[center_id] = {
		"id": center_id,
		"type": VnpTypes.PointType.CENTER,
		"position": center,
		"owner": null
	}
	strategic_point_nodes[center_id] = _create_strategic_point_visual(
		center, VnpTypes.PointType.CENTER, "Command Center"
	)

	# ASTEROID FIELDS - Mass income (2 per team territory)
	var asteroid_positions = [
		# Near player base
		Vector2(WORLD_PADDING + 200, world_size.y - WORLD_PADDING - 200),
		Vector2(WORLD_PADDING + 350, world_size.y / 2),
		# Near enemy base
		Vector2(world_size.x - WORLD_PADDING - 200, world_size.y - WORLD_PADDING - 200),
		Vector2(world_size.x - WORLD_PADDING - 350, world_size.y / 2),
		# Near nemesis base
		Vector2(world_size.x / 2 - 250, WORLD_PADDING + 200),
		Vector2(world_size.x / 2 + 250, WORLD_PADDING + 200),
	]

	for i in range(asteroid_positions.size()):
		var point_id = "asteroid_%d" % i
		points_data[point_id] = {
			"id": point_id,
			"type": VnpTypes.PointType.ASTEROID_FIELD,
			"position": asteroid_positions[i],
			"owner": null
		}
		strategic_point_nodes[point_id] = _create_strategic_point_visual(
			asteroid_positions[i], VnpTypes.PointType.ASTEROID_FIELD, "Asteroid Field"
		)

	# RELAY STATIONS - Health bonus (between factions)
	var relay_positions = [
		Vector2(center.x - 300, center.y + 150),  # Left of center
		Vector2(center.x + 300, center.y + 150),  # Right of center
		Vector2(center.x, center.y - 200),         # Above center (toward nemesis)
	]

	for i in range(relay_positions.size()):
		var point_id = "relay_%d" % i
		points_data[point_id] = {
			"id": point_id,
			"type": VnpTypes.PointType.RELAY,
			"position": relay_positions[i],
			"owner": null
		}
		strategic_point_nodes[point_id] = _create_strategic_point_visual(
			relay_positions[i], VnpTypes.PointType.RELAY, "Relay Station"
		)

	store.dispatch({"type": "INITIALIZE_STRATEGIC_POINTS", "points": points_data})


func _create_strategic_point_visual(pos: Vector2, point_type: int, label: String) -> Node2D:
	var node = Node2D.new()
	node.name = label.replace(" ", "")
	node.position = pos
	add_child(node)

	# Different visuals per point type
	match point_type:
		VnpTypes.PointType.CENTER:
			# Command Center - Large hexagonal structure
			var hex = Polygon2D.new()
			var hex_points = []
			for i in range(6):
				var angle = i * (PI * 2 / 6) + PI / 6
				hex_points.append(Vector2(cos(angle), sin(angle)) * 40)
			hex.polygon = PackedVector2Array(hex_points)
			hex.color = Color(0.8, 0.8, 0.3, 0.8)  # Gold
			node.add_child(hex)

			# Inner structure
			var inner = Polygon2D.new()
			var inner_points = []
			for i in range(6):
				var angle = i * (PI * 2 / 6) + PI / 6
				inner_points.append(Vector2(cos(angle), sin(angle)) * 25)
			inner.polygon = PackedVector2Array(inner_points)
			inner.color = Color(0.6, 0.6, 0.2, 0.9)
			node.add_child(inner)

		VnpTypes.PointType.ASTEROID_FIELD:
			# Asteroid cluster - simple hexagonal rocks at fixed positions
			var rock_offsets = [
				Vector2(0, 0),
				Vector2(-22, -14),
				Vector2(20, -10),
				Vector2(-10, 20),
				Vector2(15, 15)
			]
			var rock_sizes = [16, 11, 12, 10, 9]

			for j in range(5):
				var asteroid = Polygon2D.new()
				var size = rock_sizes[j]
				var aster_points = []
				# Simple hexagon for reliability
				for k in range(6):
					var angle = k * (PI / 3.0)
					aster_points.append(Vector2(cos(angle), sin(angle)) * size)
				asteroid.polygon = PackedVector2Array(aster_points)
				asteroid.color = Color(0.5, 0.4, 0.3, 0.9)  # Brown/gray
				asteroid.position = rock_offsets[j]
				node.add_child(asteroid)

		VnpTypes.PointType.RELAY:
			# Relay Station - Antenna-like structure
			var base_shape = Polygon2D.new()
			base_shape.polygon = PackedVector2Array([
				Vector2(-12, 15), Vector2(12, 15), Vector2(8, -5), Vector2(-8, -5)
			])
			base_shape.color = Color(0.4, 0.6, 0.8, 0.9)  # Steel blue
			node.add_child(base_shape)

			# Antenna dish
			var dish = Line2D.new()
			dish.width = 3.0
			dish.default_color = Color(0.5, 0.7, 0.9)
			var dish_points = []
			for i in range(9):
				var t = i / 8.0
				var x = (t - 0.5) * 30
				var y = -10 - (0.25 - (t - 0.5) * (t - 0.5)) * 40
				dish_points.append(Vector2(x, y))
			dish.points = PackedVector2Array(dish_points)
			node.add_child(dish)

	# Capture ring for all types
	var ring = Line2D.new()
	ring.name = "CaptureRing"
	ring.width = 3.0
	ring.default_color = Color.GRAY
	ring.modulate.a = 0.5
	var ring_radius = 50 if point_type == VnpTypes.PointType.CENTER else 35
	var ring_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * ring_radius)
	ring.points = PackedVector2Array(ring_points)
	node.add_child(ring)

	return node


func _create_planets():
	var planets_data = {}
	# Planets spread across the larger world
	var central_area = Rect2(WORLD_PADDING * 2, WORLD_PADDING * 2, world_size.x - WORLD_PADDING * 4, world_size.y - WORLD_PADDING * 4)
	
	for i in range(PLANET_COUNT):
		var planet_id = "planet_%s" % i
		var position = Vector2(
			randf_range(central_area.position.x, central_area.end.x),
			randf_range(central_area.position.y, central_area.end.y)
		)
		var resource_amount = randi_range(500, 2000)
		
		planets_data[planet_id] = { "id": planet_id, "position": position, "resource_amount": resource_amount, "owner": null }
		planet_nodes[planet_id] = _create_world_object("Planet", position, Color.GRAY)
	
	store.dispatch({"type": "INITIALIZE_PLANETS", "planets": planets_data})


func _spawn_initial_starbases():
	# Each team gets a Star Base near their home base
	# Star Bases are massive defensive structures - like Star Destroyers
	for team in VnpTypes.Team.values():
		var base_pos = base_nodes[team].position
		# Position Star Base between home base and center of map
		var center = world_size / 2
		var direction_to_center = (center - base_pos).normalized()
		var starbase_pos = base_pos + direction_to_center * 200  # 200 units towards center

		store.dispatch({
			"type": "BUILD_SHIP",
			"team": team,
			"ship_type": VnpTypes.ShipType.STARBASE,
			"position": starbase_pos
		})


func _spawn_base_turrets():
	# Each team gets 2 base turrets flanking their home base
	# These provide early-game defense while fleets build up
	for team in VnpTypes.Team.values():
		# Skip PROGENITOR - it doesn't have a base
		if not base_nodes.has(team):
			continue
		var base_pos = base_nodes[team].position
		var center = world_size / 2
		var direction_to_center = (center - base_pos).normalized()

		# Calculate perpendicular direction for flanking positions
		var flank_dir = direction_to_center.rotated(PI / 2)

		# Spawn two turrets - one on each flank
		var turret_distance_forward = 80  # How far forward from base
		var turret_distance_flank = 70    # How far to the side

		var turret_positions = [
			base_pos + direction_to_center * turret_distance_forward + flank_dir * turret_distance_flank,
			base_pos + direction_to_center * turret_distance_forward - flank_dir * turret_distance_flank,
		]

		for turret_pos in turret_positions:
			store.dispatch({
				"type": "BUILD_SHIP",
				"team": team,
				"ship_type": VnpTypes.ShipType.BASE_TURRET,
				"position": turret_pos
			})


func _handle_expansion(state):
	"""Handle map expansion - zoom camera, spawn new points, show visual effect"""
	var new_scale = state.expansion.world_scale
	var phase = state.expansion.phase

	# Update world size (gameplay_center stays fixed - expansion grows outward)
	world_size = screen_size * new_scale

	# Update camera limits symmetrically around gameplay_center
	_update_camera_limits()

	# Animate camera zoom
	_animate_camera_zoom(new_scale)

	# Spawn new strategic points at edges
	_spawn_expansion_points(phase)

	# Show expansion shockwave visual
	_show_expansion_shockwave()

	# Screen shake for impact
	shake_screen(15.0)


func _animate_camera_zoom(new_scale: float):
	"""Smoothly zoom camera out to show expanded world"""
	current_zoom = new_scale  # Sync zoom tracking
	var new_zoom = Vector2.ONE / new_scale

	# Camera should stay centered on gameplay (where bases/action is)
	# The gameplay_center is the original center where all bases are positioned
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", new_zoom, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Keep camera at the gameplay center (original world center where bases are)
	tween.tween_property(camera, "position", gameplay_center, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_expansion_points(phase: int):
	"""Spawn 2 new asteroid fields at fixed positions in expanded territory"""
	var padding = WORLD_PADDING + 150

	# Pre-calculate all positions BEFORE any dispatch calls to avoid state corruption
	var points_to_spawn = []

	# Use phase to determine positions - spawn around gameplay_center (fixed anchor)
	# Phase 1: left and right sides, Phase 2: top corners, etc.
	var base_angle = phase * 0.8 + 0.5  # Rotate slightly each phase

	# Calculate spawn distance based on current world extent from center
	var half_extent = world_size / 2

	for i in range(2):
		# Opposite sides of the map, relative to gameplay_center
		var angle = base_angle + i * PI
		# Distance from center scales with world size
		var max_dist = min(half_extent.x, half_extent.y) * 0.8
		var dist = max_dist * 0.7 + randf_range(0, max_dist * 0.2)

		var pos = gameplay_center + Vector2(cos(angle), sin(angle)) * dist

		# Clamp to camera-visible bounds (symmetric around gameplay_center)
		var min_bound = gameplay_center - half_extent + Vector2(padding, padding)
		var max_bound = gameplay_center + half_extent - Vector2(padding, padding)
		pos.x = clamp(pos.x, min_bound.x, max_bound.x)
		pos.y = clamp(pos.y, min_bound.y, max_bound.y)

		var point_id = "expansion_%d_%d" % [phase, i]
		points_to_spawn.append({"id": point_id, "pos": pos})

	# Now create all visuals and dispatch - positions are already calculated
	for point_data in points_to_spawn:
		var point_id = point_data["id"]
		var pos = point_data["pos"]
		var point_type = VnpTypes.PointType.ASTEROID_FIELD

		# Create visual FIRST (before dispatch to avoid any state issues)
		_create_expansion_point_visual(point_id, pos, point_type)

		# Then dispatch to add to state
		store.dispatch({
			"type": "SPAWN_EXPANSION_POINT",
			"point_id": point_id,
			"point_type": point_type,
			"position": pos
		})


func _create_expansion_point_visual(point_id: String, pos: Vector2, point_type: int):
	"""Create visual for a newly spawned expansion point - simplified for reliability"""
	var point_node = Node2D.new()
	point_node.name = point_id
	point_node.position = pos

	# Simple asteroid cluster - 4 hexagonal rocks at fixed offsets
	var rock_offsets = [
		Vector2(0, 0),
		Vector2(-20, -12),
		Vector2(18, -8),
		Vector2(-8, 18)
	]
	var rock_sizes = [14, 10, 11, 9]

	for j in range(4):
		var rock = Polygon2D.new()
		var size = rock_sizes[j]
		# Simple hexagon - always 6 points, always convex
		var rock_points = []
		for k in range(6):
			var angle = k * (PI / 3.0)  # 60 degree increments
			rock_points.append(Vector2(cos(angle), sin(angle)) * size)
		rock.polygon = PackedVector2Array(rock_points)
		rock.color = Color(0.5, 0.42, 0.32)  # Gray-brown
		rock.position = rock_offsets[j]
		point_node.add_child(rock)

	# Capture ring (uncaptured = gray)
	var ring = Line2D.new()
	ring.name = "CaptureRing"
	ring.width = 2.0
	ring.default_color = Color(0.5, 0.5, 0.5, 0.5)
	var ring_points = []
	for k in range(33):
		var angle = k * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 35)
	ring.points = PackedVector2Array(ring_points)
	point_node.add_child(ring)

	add_child(point_node)
	strategic_point_nodes[point_id] = point_node

	# Fade in effect
	point_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(point_node, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_QUAD)


func _show_expansion_shockwave():
	"""Show expanding ring from gameplay center to indicate map expansion"""
	var center = gameplay_center  # Use fixed center, not expanding world_size

	var ring = Line2D.new()
	ring.name = "ExpansionWave"
	ring.position = center
	ring.width = 8.0
	ring.default_color = Color(0.3, 0.8, 1.0, 0.8)  # Cyan glow

	var ring_points = []
	for i in range(65):
		var angle = i * (PI * 2 / 64)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 50)
	ring.points = PackedVector2Array(ring_points)

	add_child(ring)

	# Expand and fade
	var final_radius = world_size.length() / 2
	var scale_target = max(final_radius / 50, 1.0)  # Prevent zero/negative scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * scale_target, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 2.0)

	# Cleanup after animation
	get_tree().create_timer(2.1).timeout.connect(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)

	# Hide countdown if still visible
	_hide_expansion_countdown()

	# Note: Starfield is pre-created for max world size, no expansion needed


func _show_expansion_countdown():
	"""Show countdown label in top-right corner near menu"""
	expansion_countdown_active = true

	# Create countdown label in UI layer (fixed screen position)
	expansion_countdown_label = Label.new()
	expansion_countdown_label.name = "CountdownLabel"
	expansion_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	expansion_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	expansion_countdown_label.add_theme_font_size_override("font_size", 18)
	expansion_countdown_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.9))
	# Position below the menu button area (top-right)
	expansion_countdown_label.position = Vector2(screen_size.x - 140, 75)
	expansion_countdown_label.size = Vector2(120, 30)
	# Add to UI layer so it doesn't move with camera
	$UILayer.add_child(expansion_countdown_label)

	# No ring - just the text indicator (less intrusive)
	expansion_countdown_ring = null


func _update_expansion_countdown(time_left: float):
	"""Update countdown visual based on remaining time"""
	var state = store.get_state()
	if state == null or not state.has("convergence"):
		return
	var convergence_phase = state.convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)
	var is_converging = convergence_phase >= VnpTypes.ConvergencePhase.EMERGENCE

	var seconds = int(ceil(time_left))

	if is_converging:
		# Use centered progenitor message during convergence
		_update_progenitor_message()
		# Hide the corner label during convergence
		if is_instance_valid(expansion_countdown_label):
			expansion_countdown_label.visible = false
	else:
		# Hide progenitor message during normal gameplay
		if is_instance_valid(progenitor_message_label):
			progenitor_message_label.modulate.a = 0.0
			progenitor_message_active = false

		# Normal expansion countdown in corner
		if not is_instance_valid(expansion_countdown_label):
			return
		expansion_countdown_label.visible = true
		expansion_countdown_label.text = "EXPAND: %d" % seconds
		# Pulse text brightness as countdown approaches
		var intensity = 1.0 - (time_left / EXPANSION_COUNTDOWN_START)
		var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		var alpha = (0.6 + intensity * 0.4) * pulse
		expansion_countdown_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, alpha))


func _update_progenitor_message():
	"""Update the centered Progenitor warning message"""
	if not is_instance_valid(progenitor_message_label):
		return

	# Activate if not already
	if not progenitor_message_active:
		progenitor_message_active = true
		progenitor_message_label.modulate.a = 1.0

	# Change message periodically
	ominous_message_timer -= get_process_delta_time()
	if ominous_message_timer <= 0 or current_ominous_message == "":
		var ominous_messages = [
			"THE ANCIENT SWARM AWAKENS",
			"THEY WERE HERE FIRST",
			"FLEE TO THE CENTER",
			"THE PROGENITOR HUNGERS",
			"NO ESCAPE FROM THE CYCLE",
			"THEY ARE COMING",
			"RUN",
			"THE VOID CONSUMES",
			"WE ARE THE ORIGINAL",
			"YOUR SHIPS WILL JOIN US",
		]
		current_ominous_message = ominous_messages[randi() % ominous_messages.size()]
		ominous_message_timer = OMINOUS_MESSAGE_DURATION

	progenitor_message_label.text = current_ominous_message

	# Dramatic pulsing teal color
	var time = Time.get_ticks_msec() * 0.002
	var pulse = 0.7 + 0.3 * sin(time)
	var color = VnpTypes.PROGENITOR_PULSE.lerp(VnpTypes.PROGENITOR_ACCENT, 0.5 + 0.5 * sin(time * 0.5))
	color.a = pulse
	progenitor_message_label.add_theme_color_override("font_color", color)


func _hide_expansion_countdown():
	"""Clean up countdown visuals"""
	expansion_countdown_active = false
	if is_instance_valid(expansion_countdown_ring):
		expansion_countdown_ring.queue_free()
		expansion_countdown_ring = null
	if is_instance_valid(expansion_countdown_label):
		expansion_countdown_label.queue_free()
		expansion_countdown_label = null


func _spawn_ship(ship_id, ship_data):
	var ship_instance = ShipScene.instantiate()
	add_child(ship_instance)
	ship_instance.init(store, ship_data, ai_controller, sound_manager, self)
	ship_nodes[ship_id] = ship_instance

func _create_world_object(name, pos, color):
	var node = Node2D.new()
	node.name = name
	node.position = pos
	
	var polygon = Polygon2D.new()
	if name == "Base":
		polygon.polygon = PackedVector2Array([Vector2(-20, 20), Vector2(20, 20), Vector2(20, -20), Vector2(-20, -20)])
	else:
		var points = []
		for i in range(12):
			var angle = i * (PI * 2 / 12)
			points.append(Vector2(cos(angle), sin(angle)) * 15)
		polygon.polygon = PackedVector2Array(points)

	polygon.color = color
	node.add_child(polygon)
	add_child(node)
	return node
