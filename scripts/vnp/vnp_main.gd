extends Node2D

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")
const ShipScene = preload("res://scenes/vnp/ship.tscn")
const DeathExplosionFxScene = preload("res://scenes/vnp/death_explosion_fx.tscn")
const AiController = preload("res://scripts/vnp/vnp_ai_controller.gd")

@onready var store = $VnpStore
@onready var vnp_ui = $VnpUI

var screen_size = Vector2.ZERO
const PLANET_COUNT = 10
const WORLD_PADDING = 100

# Balance constants
const ENERGY_REGEN_RATE = 10
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

func shake_screen(intensity: float):
	shake_intensity = max(shake_intensity, intensity)

func on_state_changed(state):
	# Handle victory
	if state.get("game_over", false) and not showing_victory:
		_handle_victory(state.winner)
		return

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

func _spawn_death_explosion(pos: Vector2, size: int, team: int):
	var explosion = DeathExplosionFxScene.instantiate()
	add_child(explosion)
	explosion.global_position = pos
	explosion.emitting = true

	# Scale explosion and shake based on ship size
	var shake_amounts = {
		VnpTypes.ShipSize.SMALL: 5.0,
		VnpTypes.ShipSize.MEDIUM: 12.0,
		VnpTypes.ShipSize.LARGE: 25.0,
	}
	var scale_amounts = {
		VnpTypes.ShipSize.SMALL: 1.0,
		VnpTypes.ShipSize.MEDIUM: 1.8,
		VnpTypes.ShipSize.LARGE: 3.0,
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

	# Reset state
	store.dispatch({"type": "RESET_GAME"})

	# Reinitialize planets
	_create_planets()

	# Restart AI
	ai_controller.start_all()

	vnp_ui.hide_victory()

func _initialize_game_world():
	_create_bases()
	_create_planets()

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
