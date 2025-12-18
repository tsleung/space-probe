extends Node2D

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const ShipScene = preload("res://scenes/von_neumann_probe/ship.tscn")
const DeathExplosionFxScene = preload("res://scenes/von_neumann_probe/death_explosion_fx.tscn")
const AiController = preload("res://scripts/von_neumann_probe/vnp_ai_controller.gd")
const BaseWeapon = preload("res://scripts/von_neumann_probe/base_weapon.gd")
const SoundManager = preload("res://scripts/von_neumann_probe/vnp_sound_manager.gd")

@onready var store = $VnpStore
@onready var vnp_ui = $VnpUI

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

# AI Controller
var ai_controller = null

# Sound Manager
var sound_manager = null

# Timers
var energy_regen_timer: Timer
var victory_check_timer: Timer
var planet_income_timer: Timer
var strategic_point_timer: Timer
var base_weapon_cooldowns = {}  # team -> time_remaining

# Base charge system - allows storing up charges for burst attacks
var base_charges = {}  # team -> current_charges
var base_charge_mode = {}  # team -> "auto" or "manual"
const MAX_BASE_CHARGES = 5  # Maximum stored charges

# Click handling for rally points
var selected_rally_target = null  # Currently highlighted target for player
var rally_line: Line2D = null  # Visual dashed line showing rally route
var player_rally_point: Vector2 = Vector2.ZERO  # Where player ships rally to

# Screen shake
var shake_intensity: float = 0.0
var shake_decay: float = 8.0
var camera: Camera2D

# Explosion rate limiting (prevents lag when tabbed back)
var explosion_count_this_frame: int = 0
const MAX_EXPLOSIONS_PER_FRAME: int = 3

# Victory state
var showing_victory = false

func _ready():
	screen_size = get_viewport_rect().size
	world_size = screen_size * WORLD_SCALE  # Larger world for momentum combat
	store.subscribe(self)
	set_process(true)

	_setup_camera()
	_setup_timers()
	_setup_sound()
	_setup_rally_line()
	_create_starfield()
	_create_bases()
	_create_strategic_points()  # New capture points system
	_setup_ai()  # Must be before spawning ships so they get ai_controller reference
	_spawn_base_turrets()  # Defensive turrets at each base for early game protection

	vnp_ui.init(store, base_nodes, ai_controller, strategic_point_nodes)

	var initial_state = store.get_state()
	on_state_changed(initial_state)

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

				# Auto mode: fire immediately when charged
				if base_charge_mode.get(team, "auto") == "auto" and base_charges.get(team, 0) > 0:
					_try_fire_base_weapon(team)

		# Update UI with cooldowns and charges
		vnp_ui.update_cooldowns(base_weapon_cooldowns, base_charges, base_charge_mode)

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
	weapon.init(store, team, base_pos, charges)


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

func _setup_camera():
	camera = Camera2D.new()
	camera.name = "Camera2D"
	# Center camera on the world and zoom out to fit larger arena
	camera.position = world_size / 2
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.zoom = Vector2.ONE / WORLD_SCALE  # Zoom out to show larger world
	add_child(camera)
	camera.make_current()

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

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
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


func shake_screen(intensity: float):
	shake_intensity = max(shake_intensity, intensity)

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
			var dist = ship.position.distance_to(planet_pos)
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
			var dist = ship.position.distance_to(point_pos)
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
	# Background layer of distant stars covering the larger world
	var starfield = Node2D.new()
	starfield.name = "Starfield"
	starfield.z_index = -100
	add_child(starfield)

	# Create many small stars - more for larger world
	var star_count = int(300 * WORLD_SCALE)
	for i in range(star_count):
		var star = Polygon2D.new()
		var size = randf_range(1.0, 3.0)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		star.color = Color(1, 1, 1, randf_range(0.3, 0.8))
		star.position = Vector2(randf_range(0, world_size.x), randf_range(0, world_size.y))
		starfield.add_child(star)

	# Create some larger bright stars
	var bright_star_count = int(45 * WORLD_SCALE)
	for i in range(bright_star_count):
		var star = Polygon2D.new()
		var size = randf_range(2.0, 5.0)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		var star_colors = [Color(0.8, 0.9, 1.0), Color(1.0, 0.95, 0.8), Color(1.0, 0.8, 0.7), Color(0.7, 0.8, 1.0)]
		star.color = star_colors[randi() % star_colors.size()]
		star.position = Vector2(randf_range(0, world_size.x), randf_range(0, world_size.y))
		starfield.add_child(star)

	# Create nebula clouds (subtle colored regions)
	var nebula_count = int(7 * WORLD_SCALE)
	for i in range(nebula_count):
		var nebula = Polygon2D.new()
		var points = []
		var center = Vector2(randf_range(100, world_size.x - 100), randf_range(100, world_size.y - 100))
		var radius = randf_range(200, 500)
		for j in range(8):
			var angle = j * (PI * 2 / 8)
			var r = radius * randf_range(0.6, 1.4)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		nebula.polygon = PackedVector2Array(points)
		var nebula_colors = [
			Color(0.2, 0.1, 0.4, 0.15),  # Purple
			Color(0.1, 0.2, 0.4, 0.12),  # Blue
			Color(0.3, 0.1, 0.2, 0.1),   # Red/pink
			Color(0.1, 0.3, 0.3, 0.1),   # Teal
		]
		nebula.color = nebula_colors[randi() % nebula_colors.size()]
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
			# Asteroid cluster - Multiple small irregular shapes
			for j in range(5):
				var asteroid = Polygon2D.new()
				var aster_points = []
				var num_verts = randi_range(5, 8)
				var base_size = randf_range(8, 18)
				for i in range(num_verts):
					var angle = i * (PI * 2 / num_verts)
					var r = base_size * randf_range(0.7, 1.3)
					aster_points.append(Vector2(cos(angle), sin(angle)) * r)
				asteroid.polygon = PackedVector2Array(aster_points)
				asteroid.color = Color(0.5, 0.4, 0.3, 0.9)  # Brown/gray
				asteroid.position = Vector2(randf_range(-30, 30), randf_range(-30, 30))
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


func _spawn_ship(ship_id, ship_data):
	var ship_instance = ShipScene.instantiate()
	add_child(ship_instance)
	ship_instance.init(store, ship_data, ai_controller, sound_manager)
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
