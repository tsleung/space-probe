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
const NEMESIS_ENERGY_MULTIPLIER = 1.5
const VICTORY_DISPLAY_TIME = 3.0

var ship_nodes = {}
var planet_nodes = {}
var base_nodes = {}
var strategic_point_nodes = {}  # point_id -> Node2D
var outpost_nodes = {}  # point_id -> Node2D (visual for built outposts)
var harvester_build_progress = {}  # point_id -> harvester_ship_id tracking who's building

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
	# Center camera on the world and zoom out to fit larger arena
	camera.position = world_size / 2
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	current_zoom = WORLD_SCALE  # Start at current world scale
	camera.zoom = Vector2.ONE / current_zoom
	add_child(camera)
	camera.make_current()

	# Setup void message label (hidden by default)
	_setup_void_message()


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


func _handle_zoom(delta: float):
	"""Handle camera zoom with expansion-based limits"""
	var state = store.get_state()
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


# Convergence slide tracking
var convergence_slide_direction: Vector2 = Vector2.ZERO
var convergence_slide_count: int = 0

func _slide_convergence_center():
	"""Slide the convergence center in a direction - pushing players"""
	var state = store.get_state()
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

	# Keep center within world bounds (with padding)
	var padding = 200.0
	new_center.x = clamp(new_center.x, padding, world_size.x - padding)
	new_center.y = clamp(new_center.y, padding, world_size.y - padding)

	# If we hit an edge, reverse that axis
	if new_center.x <= padding or new_center.x >= world_size.x - padding:
		convergence_slide_direction.x *= -1
	if new_center.y <= padding or new_center.y >= world_size.y - padding:
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
	if not state.has("convergence"):
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
	# Trigger whispers after 3 expansions OR when total ships exceed threshold
	var state = store.get_state()
	var expansion_phase = state.expansion.phase
	var total_ships = state.ships.size()

	# Trigger after 3 expansions (more thematic - tied to world growth)
	if expansion_phase >= 3 or total_ships >= 30:  # 30 ships for debugging
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
	"""The convergence is active - zone shrinks, ships get absorbed"""
	var absorption_radius = convergence.get("absorption_radius", 1000.0)
	var original_radius = convergence.get("original_radius", 1000.0)
	var critical_threshold = original_radius * timing["critical_radius_percent"]

	# Shrink absorption zone
	var shrink_amount = timing["shrink_rate_base"] * 0.5  # Per tick (500ms)
	store.dispatch({
		"type": "CONVERGENCE_SHRINK",
		"amount": shrink_amount
	})

	# Check for ships outside absorption zone
	_check_ship_absorption(convergence)

	# Check for critical phase transition
	if absorption_radius <= critical_threshold:
		_transition_to_critical()


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

	# Natural instability growth in critical phase
	store.dispatch({
		"type": "CONVERGENCE_ADD_INSTABILITY",
		"amount": 2.0  # Per tick
	})

	# Check for ship absorption
	_check_ship_absorption(convergence)

	# Check for fragmentation
	if instability >= timing["instability_threshold"]:
		_trigger_fragmentation()


func _check_ship_absorption(convergence: Dictionary):
	"""Absorb ships and outposts outside the safe zone"""
	var center = convergence.get("center", Vector2.ZERO)
	var radius = convergence.get("absorption_radius", 1000.0)
	var state = store.get_state()

	var ships_to_absorb = []
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		# Use real position from node if available
		var ship_pos = ship.position
		if ship_nodes.has(ship_id) and is_instance_valid(ship_nodes[ship_id]):
			ship_pos = ship_nodes[ship_id].global_position

		var dist = ship_pos.distance_to(center)
		if dist > radius:
			ships_to_absorb.append(ship_id)

	# Absorb ships (with visual effect)
	for ship_id in ships_to_absorb:
		_absorb_ship(ship_id)

	# Check outposts outside absorption zone
	var outposts_to_absorb = []
	for point_id in state.outposts:
		if state.strategic_points.has(point_id):
			var point_pos = state.strategic_points[point_id].position
			var dist = point_pos.distance_to(center)
			if dist > radius:
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
	"""Setup visual elements for the convergence zone"""
	# Create absorption zone ring
	if not convergence_visual_ring:
		convergence_visual_ring = Line2D.new()
		convergence_visual_ring.name = "ConvergenceRing"
		convergence_visual_ring.width = 4.0
		convergence_visual_ring.default_color = VnpTypes.PROGENITOR_ACCENT
		convergence_visual_ring.z_index = 5
		add_child(convergence_visual_ring)


func _update_convergence_visuals():
	"""Update convergence visual elements each frame"""
	var state = store.get_state()
	if not state.has("convergence"):
		return

	var convergence = state.convergence
	var phase = convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)

	# Only draw during active phases
	if phase < VnpTypes.ConvergencePhase.CONTACT:
		if convergence_visual_ring:
			convergence_visual_ring.visible = false
		return

	var center = convergence.get("center", gameplay_center)
	var radius = convergence.get("absorption_radius", 1000.0)

	# Draw absorption zone ring
	if convergence_visual_ring:
		convergence_visual_ring.visible = true
		convergence_visual_ring.clear_points()

		# Pulsing effect
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.05
		var draw_radius = radius * pulse

		# Draw circle
		var segments = 64
		for i in range(segments + 1):
			var angle = (float(i) / segments) * TAU
			var point = center + Vector2(cos(angle), sin(angle)) * draw_radius
			convergence_visual_ring.add_point(point)

		# Color intensity based on phase
		var alpha = 0.5 if phase == VnpTypes.ConvergencePhase.EMERGENCE else 0.8
		convergence_visual_ring.default_color = Color(
			VnpTypes.PROGENITOR_ACCENT.r,
			VnpTypes.PROGENITOR_ACCENT.g,
			VnpTypes.PROGENITOR_ACCENT.b,
			alpha
		)


func shake_screen(intensity: float):
	shake_intensity = max(shake_intensity, intensity)


# === OUTPOST SYSTEM - Harvester Factory Building ===

func _on_outpost_tick():
	"""Main outpost processing - harvester building and frigate production"""
	if showing_victory:
		return

	var state = store.get_state()

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
	var config = VnpTypes.OUTPOST_CONFIG
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
			if new_progress >= VnpTypes.OUTPOST_CONFIG["build_time"]:
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
	var config = VnpTypes.OUTPOST_CONFIG
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
	if not state.strategic_points.has(point_id):
		return

	var point_pos = state.strategic_points[point_id].position
	var config = VnpTypes.OUTPOST_CONFIG

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
			var production_interval = VnpTypes.OUTPOST_CONFIG["production_interval"]
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


func _check_planet_capture():
	# Ships near planets capture them for their team
	var state = store.get_state()
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
	# Handle victory
	if state.get("game_over", false) and not showing_victory:
		_handle_victory(state.winner)
		return

	# Check for expansion phase change - UPDATE FIRST to prevent re-entrancy
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

	var explosion = DeathExplosionFxScene.instantiate()
	add_child(explosion)
	explosion.global_position = pos
	explosion.emitting = true

	# Scale explosion and shake based on ship size - DRAMATIC
	var shake_amounts = {
		VnpTypes.ShipSize.SMALL: 10.0,
		VnpTypes.ShipSize.MEDIUM: 25.0,
		VnpTypes.ShipSize.LARGE: 50.0,
		VnpTypes.ShipSize.MASSIVE: 100.0,  # Star Base destruction = HUGE shake
	}
	var scale_amounts = {
		VnpTypes.ShipSize.SMALL: 2.0,
		VnpTypes.ShipSize.MEDIUM: 3.5,
		VnpTypes.ShipSize.LARGE: 6.0,
		VnpTypes.ShipSize.MASSIVE: 12.0,  # Massive explosion for Star Base
	}

	explosion.scale = Vector2.ONE * scale_amounts.get(size, 1.0)
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

	# Reset base weapon cooldowns and charges
	for team in VnpTypes.Team.values():
		base_weapon_cooldowns[team] = 0.0
		base_charges[team] = 0

	# Reset state
	store.dispatch({"type": "RESET_GAME"})

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
	# Background layer of distant stars - covers MAX expanded size for consistency
	starfield_node = Node2D.new()
	starfield_node.name = "Starfield"
	starfield_node.z_index = -100
	add_child(starfield_node)

	# Calculate max world size (after all expansions)
	var max_scale = WORLD_SCALE + (0.3 * 10)  # Initial + max expansions
	var max_world = screen_size * max_scale

	# Evenly distributed dim stars across entire max area
	var star_count = 120
	for i in range(star_count):
		var star = Polygon2D.new()
		var size = randf_range(1.0, 2.0)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		star.color = Color(1, 1, 1, randf_range(0.15, 0.4))
		star.position = Vector2(randf_range(0, max_world.x), randf_range(0, max_world.y))
		starfield_node.add_child(star)

	# Bright stars spread across max area
	var bright_star_count = 25
	var star_colors = [Color(0.8, 0.9, 1.0), Color(1.0, 0.95, 0.8), Color(0.7, 0.8, 1.0)]
	for i in range(bright_star_count):
		var star = Polygon2D.new()
		var size = randf_range(2.0, 3.0)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		star.color = star_colors[randi() % star_colors.size()]
		star.position = Vector2(randf_range(0, max_world.x), randf_range(0, max_world.y))
		starfield_node.add_child(star)

	# Subtle nebula clouds spread across max area
	for i in range(4):
		var nebula = Polygon2D.new()
		var points = []
		var center = Vector2(randf_range(300, max_world.x - 300), randf_range(300, max_world.y - 300))
		var radius = randf_range(300, 500)
		for j in range(8):
			var angle = j * (PI * 2 / 8)
			var r = radius * randf_range(0.7, 1.3)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		nebula.polygon = PackedVector2Array(points)
		var nebula_colors = [
			Color(0.12, 0.08, 0.2, 0.06),   # Purple
			Color(0.08, 0.12, 0.2, 0.06),   # Blue
			Color(0.15, 0.08, 0.12, 0.05),  # Red/pink
			Color(0.08, 0.15, 0.15, 0.05),  # Teal
		]
		nebula.color = nebula_colors[i % nebula_colors.size()]
		nebula.z_index = -99
		add_child(nebula)

func _create_bases():
	# Bases positioned at corners of the larger world
	var player_base_pos = Vector2(WORLD_PADDING, world_size.y - WORLD_PADDING)
	base_nodes[VnpTypes.Team.PLAYER] = _create_world_object("Base", player_base_pos, Color.BLUE)

	var enemy1_base_pos = Vector2(world_size.x - WORLD_PADDING, world_size.y - WORLD_PADDING)
	base_nodes[VnpTypes.Team.ENEMY_1] = _create_world_object("Base", enemy1_base_pos, Color.ORANGE)

	var nemesis_base_pos = Vector2(world_size.x / 2, WORLD_PADDING)
	base_nodes[VnpTypes.Team.NEMESIS] = _create_world_object("Base", nemesis_base_pos, Color.RED)


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

	# Update world size
	world_size = screen_size * new_scale

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
	var tween = create_tween()
	tween.tween_property(camera, "zoom", new_zoom, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_expansion_points(phase: int):
	"""Spawn 2 new asteroid fields at fixed positions in expanded territory"""
	var padding = WORLD_PADDING + 150
	var center = world_size / 2

	# Pre-calculate all positions BEFORE any dispatch calls to avoid state corruption
	var points_to_spawn = []

	# Use phase to determine positions - simple grid approach for reliability
	# Phase 1: left and right sides, Phase 2: top corners, etc.
	var base_angle = phase * 0.8 + 0.5  # Rotate slightly each phase

	for i in range(2):
		# Opposite sides of the map
		var angle = base_angle + i * PI
		# Use half of the smaller dimension for distance to stay in bounds
		var max_dist = min(world_size.x, world_size.y) * 0.4
		var dist = max_dist * 0.7 + randf_range(0, max_dist * 0.2)

		var pos = center + Vector2(cos(angle), sin(angle)) * dist

		# Clamp to world bounds
		pos.x = clamp(pos.x, padding, world_size.x - padding)
		pos.y = clamp(pos.y, padding, world_size.y - padding)

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
	if not is_instance_valid(expansion_countdown_label):
		return

	var state = store.get_state()
	var convergence_phase = state.convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)
	var is_converging = convergence_phase >= VnpTypes.ConvergencePhase.EMERGENCE

	var seconds = int(ceil(time_left))

	if is_converging:
		# Ominous messages during convergence
		var ominous_messages = [
			"IT PUSHES...",
			"THE VOID SHIFTS...",
			"FLEE...",
			"IT HUNGERS...",
			"NO ESCAPE...",
			"CONSOLIDATE...",
		]
		expansion_countdown_label.text = ominous_messages[randi() % ominous_messages.size()]
		# Purple color during convergence
		var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		expansion_countdown_label.add_theme_color_override("font_color", Color(VnpTypes.PROGENITOR_ACCENT.r, VnpTypes.PROGENITOR_ACCENT.g, VnpTypes.PROGENITOR_ACCENT.b, pulse))
	else:
		# Normal expansion countdown
		expansion_countdown_label.text = "EXPAND: %d" % seconds
		# Pulse text brightness as countdown approaches
		var intensity = 1.0 - (time_left / EXPANSION_COUNTDOWN_START)
		var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		var alpha = (0.6 + intensity * 0.4) * pulse
		expansion_countdown_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, alpha))


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
