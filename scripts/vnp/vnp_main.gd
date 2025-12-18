extends Node2D

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")
const ShipScene = preload("res://scenes/vnp/ship.tscn")
const DeathExplosionFxScene = preload("res://scenes/vnp/death_explosion_fx.tscn")
const AiController = preload("res://scripts/vnp/vnp_ai_controller.gd")
const BaseWeapon = preload("res://scripts/vnp/base_weapon.gd")

@onready var store = $VnpStore
@onready var vnp_ui = $VnpUI

var screen_size = Vector2.ZERO
const PLANET_COUNT = 10
const WORLD_PADDING = 100

# Balance constants - CRANKED UP FOR DRAMA
const ENERGY_REGEN_RATE = 30  # 3x faster ship production
const NEMESIS_ENERGY_MULTIPLIER = 1.5
const VICTORY_DISPLAY_TIME = 3.0

var ship_nodes = {}
var planet_nodes = {}
var base_nodes = {}

# AI Controller
var ai_controller = null

# Timers
var energy_regen_timer: Timer
var victory_check_timer: Timer
var planet_income_timer: Timer
var base_weapon_cooldowns = {}  # team -> time_remaining

# Screen shake
var shake_intensity: float = 0.0
var shake_decay: float = 8.0
var camera: Camera2D

# Victory state
var showing_victory = false

func _ready():
	screen_size = get_viewport_rect().size
	store.subscribe(self)
	set_process(true)

	_setup_camera()
	_setup_timers()
	_initialize_game_world()
	_setup_ai()

	vnp_ui.init(store, base_nodes)

	var initial_state = store.get_state()
	on_state_changed(initial_state)

func _process(delta):
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

	# Update base weapon cooldowns and auto-fire for AI
	if not showing_victory:
		for team in VnpTypes.Team.values():
			if base_weapon_cooldowns[team] > 0:
				base_weapon_cooldowns[team] -= delta
			elif base_weapon_cooldowns[team] <= 0:
				# AI teams auto-fire when ready
				if team != VnpTypes.Team.PLAYER or true:  # All teams auto-fire for spectacle
					_try_fire_base_weapon(team)

		# Update UI with cooldowns
		vnp_ui.update_cooldowns(base_weapon_cooldowns)

func _try_fire_base_weapon(team: int):
	var state = store.get_state()

	# Check if there are any enemies to target
	var has_enemies = false
	for ship_id in state.ships:
		if state.ships[ship_id].team != team:
			has_enemies = true
			break

	if not has_enemies:
		return

	# Fire!
	fire_base_weapon(team)
	base_weapon_cooldowns[team] = VnpTypes.BASE_WEAPON_COOLDOWN

func fire_base_weapon(team: int):
	if not base_nodes.has(team):
		return

	var base_pos = base_nodes[team].position
	var weapon = BaseWeapon.new()
	add_child(weapon)
	weapon.init(store, team, base_pos)

func _setup_camera():
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2.ZERO
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
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

	# Planet income timer
	planet_income_timer = Timer.new()
	planet_income_timer.name = "PlanetIncomeTimer"
	planet_income_timer.wait_time = 2.0
	planet_income_timer.timeout.connect(_on_planet_income)
	add_child(planet_income_timer)
	planet_income_timer.start()

	# Initialize base weapon cooldowns
	for team in VnpTypes.Team.values():
		base_weapon_cooldowns[team] = 0.0

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

func on_state_changed(state):
	# Handle victory
	if state.get("game_over", false) and not showing_victory:
		_handle_victory(state.winner)
		return

	# Update planet visuals based on ownership
	_update_planet_visuals(state)

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

func _spawn_death_explosion(pos: Vector2, size: int, team: int):
	var explosion = DeathExplosionFxScene.instantiate()
	add_child(explosion)
	explosion.global_position = pos
	explosion.emitting = true

	# Scale explosion and shake based on ship size - DRAMATIC
	var shake_amounts = {
		VnpTypes.ShipSize.SMALL: 10.0,
		VnpTypes.ShipSize.MEDIUM: 25.0,
		VnpTypes.ShipSize.LARGE: 50.0,
	}
	var scale_amounts = {
		VnpTypes.ShipSize.SMALL: 2.0,
		VnpTypes.ShipSize.MEDIUM: 3.5,
		VnpTypes.ShipSize.LARGE: 6.0,
	}

	explosion.scale = Vector2.ONE * scale_amounts.get(size, 1.0)
	shake_screen(shake_amounts.get(size, 5.0))

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

	# Reset base weapon cooldowns
	for team in VnpTypes.Team.values():
		base_weapon_cooldowns[team] = 0.0

	# Reset state
	store.dispatch({"type": "RESET_GAME"})

	# Reinitialize planets
	_create_planets()

	# Restart AI
	ai_controller.start_all()

	vnp_ui.hide_victory()

func _initialize_game_world():
	_create_starfield()
	_create_bases()
	_create_planets()

func _create_starfield():
	# Background layer of distant stars
	var starfield = Node2D.new()
	starfield.name = "Starfield"
	starfield.z_index = -100
	add_child(starfield)

	# Create many small stars
	for i in range(200):
		var star = Polygon2D.new()
		var size = randf_range(1.0, 3.0)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		star.color = Color(1, 1, 1, randf_range(0.3, 0.8))
		star.position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
		starfield.add_child(star)

	# Create some larger bright stars
	for i in range(30):
		var star = Polygon2D.new()
		var size = randf_range(2.0, 5.0)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		var star_colors = [Color(0.8, 0.9, 1.0), Color(1.0, 0.95, 0.8), Color(1.0, 0.8, 0.7), Color(0.7, 0.8, 1.0)]
		star.color = star_colors[randi() % star_colors.size()]
		star.position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
		starfield.add_child(star)

	# Create nebula clouds (subtle colored regions)
	for i in range(5):
		var nebula = Polygon2D.new()
		var points = []
		var center = Vector2(randf_range(100, screen_size.x - 100), randf_range(100, screen_size.y - 100))
		var radius = randf_range(150, 400)
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
	var player_base_pos = Vector2(WORLD_PADDING, screen_size.y - WORLD_PADDING)
	base_nodes[VnpTypes.Team.PLAYER] = _create_world_object("Base", player_base_pos, Color.BLUE)
	
	var enemy1_base_pos = Vector2(screen_size.x - WORLD_PADDING, screen_size.y - WORLD_PADDING)
	base_nodes[VnpTypes.Team.ENEMY_1] = _create_world_object("Base", enemy1_base_pos, Color.ORANGE)

	var nemesis_base_pos = Vector2(screen_size.x / 2, WORLD_PADDING)
	base_nodes[VnpTypes.Team.NEMESIS] = _create_world_object("Base", nemesis_base_pos, Color.RED)

func _create_planets():
	var planets_data = {}
	var central_area = Rect2(WORLD_PADDING * 2, WORLD_PADDING * 2, screen_size.x - WORLD_PADDING * 4, screen_size.y - WORLD_PADDING * 4)
	
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

func _spawn_ship(ship_id, ship_data):
	var ship_instance = ShipScene.instantiate()
	add_child(ship_instance)
	ship_instance.init(store, ship_data)
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
