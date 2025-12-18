extends Node

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")

var store = null
var base_positions = {}

# AI decision timers per team
var build_timers = {}
const BUILD_DECISION_INTERVAL = 0.5

# AI personality per team (affects ship preferences)
const TEAM_PREFERENCES = {
	VnpTypes.Team.PLAYER: [VnpTypes.ShipType.FRIGATE, VnpTypes.ShipType.DESTROYER, VnpTypes.ShipType.CRUISER],
	VnpTypes.Team.ENEMY_1: [VnpTypes.ShipType.DESTROYER, VnpTypes.ShipType.CRUISER, VnpTypes.ShipType.FRIGATE],
	VnpTypes.Team.NEMESIS: [VnpTypes.ShipType.CRUISER, VnpTypes.ShipType.FRIGATE, VnpTypes.ShipType.DESTROYER],
}

func init(vnp_store, bases: Dictionary):
	self.store = vnp_store
	self.base_positions = bases

	for team in [VnpTypes.Team.PLAYER, VnpTypes.Team.ENEMY_1, VnpTypes.Team.NEMESIS]:
		var timer = Timer.new()
		timer.wait_time = BUILD_DECISION_INTERVAL + randf() * 0.3
		timer.one_shot = false  # Keep repeating
		timer.timeout.connect(_on_build_decision.bind(team))
		add_child(timer)
		build_timers[team] = timer
		timer.start()

func _on_build_decision(team: int):
	var state = store.get_state()

	if state.get("game_over", false):
		return

	var energy = state.teams[team].energy
	var ship_to_build = _choose_ship_type(team, energy, state)

	if ship_to_build != -1:
		var base_pos = base_positions[team]
		var spawn_offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		store.dispatch({
			"type": "BUILD_SHIP",
			"team": team,
			"ship_type": ship_to_build,
			"position": base_pos + spawn_offset
		})

func _choose_ship_type(team: int, energy: int, state: Dictionary) -> int:
	# Get affordable ships
	var affordable = []
	for ship_type in VnpTypes.SHIP_STATS:
		if ship_type == VnpTypes.ShipType.HARVESTER:
			continue  # Skip harvesters for combat AI
		if VnpTypes.SHIP_STATS[ship_type].cost <= energy:
			affordable.append(ship_type)

	if affordable.is_empty():
		return -1

	# Analyze enemy composition for counter-picking
	var enemy_weapons = _analyze_enemy_weapons(team, state)
	var counter_type = _get_counter_ship_type(enemy_weapons)

	# 60% chance to counter-pick, 40% chance to follow team preference
	if counter_type in affordable and randf() < 0.6:
		return counter_type

	# Follow team preference
	var preferences = TEAM_PREFERENCES[team]
	for pref in preferences:
		if pref in affordable:
			return pref

	# Fallback to random affordable
	return affordable[randi() % affordable.size()]

func _analyze_enemy_weapons(team: int, state: Dictionary) -> Dictionary:
	var weapon_counts = {
		VnpTypes.WeaponType.GUN: 0,
		VnpTypes.WeaponType.LASER: 0,
		VnpTypes.WeaponType.MISSILE: 0,
	}

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var ship_stats = VnpTypes.SHIP_STATS.get(ship.type, {})
			var weapon = ship_stats.get("weapon", null)
			if weapon != null:
				weapon_counts[weapon] += 1

	return weapon_counts

func _get_counter_ship_type(enemy_weapons: Dictionary) -> int:
	# Find most common enemy weapon
	var max_count = 0
	var dominant_weapon = VnpTypes.WeaponType.GUN

	for weapon in enemy_weapons:
		if enemy_weapons[weapon] > max_count:
			max_count = enemy_weapons[weapon]
			dominant_weapon = weapon

	# Return ship that counters the dominant weapon
	# Gun beats Laser, Laser beats Missile, Missile beats Gun
	match dominant_weapon:
		VnpTypes.WeaponType.GUN:
			return VnpTypes.ShipType.CRUISER  # Missile beats Gun
		VnpTypes.WeaponType.LASER:
			return VnpTypes.ShipType.FRIGATE  # Gun beats Laser
		VnpTypes.WeaponType.MISSILE:
			return VnpTypes.ShipType.DESTROYER  # Laser beats Missile

	return VnpTypes.ShipType.FRIGATE

func stop_all():
	for team in build_timers:
		build_timers[team].stop()

func start_all():
	for team in build_timers:
		build_timers[team].start()
