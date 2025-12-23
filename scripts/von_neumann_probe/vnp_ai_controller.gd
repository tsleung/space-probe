extends Node

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const VnpSystems = preload("res://scripts/von_neumann_probe/vnp_systems.gd")

var store = null
var base_positions = {}

# AI decision timers per team
var build_timers = {}
const BUILD_DECISION_INTERVAL = 0.3  # Faster build checks

# Fleet stance per team - player can modify their own
var team_stances = {
	VnpTypes.Team.PLAYER: VnpTypes.FleetStance.BALANCED,
	VnpTypes.Team.ENEMY_1: VnpTypes.FleetStance.BALANCED,
	VnpTypes.Team.NEMESIS: VnpTypes.FleetStance.BALANCED,
}

# Fleet formation per team - tactical movement behavior
var team_formations = {
	VnpTypes.Team.PLAYER: VnpTypes.FleetFormation.OFFENSIVE,
	VnpTypes.Team.ENEMY_1: VnpTypes.FleetFormation.OFFENSIVE,
	VnpTypes.Team.NEMESIS: VnpTypes.FleetFormation.OFFENSIVE,
}

# Fleet adherence per team - how tightly ships stick together
var team_adherence = {
	VnpTypes.Team.PLAYER: VnpTypes.FleetAdherence.LOOSE,
	VnpTypes.Team.ENEMY_1: VnpTypes.FleetAdherence.LOOSE,
	VnpTypes.Team.NEMESIS: VnpTypes.FleetAdherence.LOOSE,
}

# Ship production priorities per team - multipliers for weighted selection
# Values: 1 = normal, 2 = double, 3 = triple, 100 = almost exclusive
const PRIORITY_CYCLE = [1, 2, 3, 100]  # Cycle through these values
var ship_priorities = {
	VnpTypes.Team.PLAYER: {},  # {ship_type: multiplier}
	VnpTypes.Team.ENEMY_1: {},
	VnpTypes.Team.NEMESIS: {},
}

# Signal for UI to react to stance/formation/adherence changes
signal stance_changed(team: int, stance: int)
signal formation_changed(team: int, formation: int)
signal adherence_changed(team: int, adherence: int)
signal priority_changed(team: int, ship_type: int, priority: int)

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
	# Get fleet policy for this team's stance
	var stance = team_stances.get(team, VnpTypes.FleetStance.BALANCED)
	var policy = VnpTypes.get_fleet_policy(stance)
	var weights = policy.get("weights", {})
	var mass = state.teams[team].get("mass", 0)

	# Get all buildable ship types (excluding harvester, starbase, and base turret)
	var all_buildable = []
	var max_energy_cost = 0
	for ship_type in VnpTypes.SHIP_STATS:
		if ship_type == VnpTypes.ShipType.HARVESTER:
			continue
		if ship_type == VnpTypes.ShipType.STARBASE:
			continue
		if ship_type == VnpTypes.ShipType.BASE_TURRET:
			continue
		all_buildable.append(ship_type)
		var cost = VnpTypes.SHIP_STATS[ship_type].cost
		if cost > max_energy_cost:
			max_energy_cost = cost

	# KEY ALGORITHM: Wait until we can afford ALL energy-only ships before building
	# This prevents bias toward cheap ships
	if energy < max_energy_cost:
		return -1  # Save up until we can afford anything

	# Filter to ships we can actually afford (considering mass)
	var affordable = []
	for ship_type in all_buildable:
		var ship_stats = VnpTypes.SHIP_STATS[ship_type]
		var mass_cost = ship_stats.get("mass_cost", 0)
		if mass >= mass_cost:
			affordable.append(ship_type)

	if affordable.is_empty():
		return -1  # Can't afford anything with current mass

	# Analyze enemy composition for counter-picking
	var enemy_weapons = _analyze_enemy_weapons(team, state)

	# Only counter-pick if there are actual enemies to counter
	var total_enemy_weapons = 0
	for w in enemy_weapons.values():
		total_enemy_weapons += w

	if total_enemy_weapons > 0:
		var counter_type = _get_counter_ship_type(enemy_weapons, stance)
		# Counter-pick chance based on policy (reduced to let weights matter more)
		var counter_chance = policy.get("counter_pick_chance", 0.6) * 0.5  # Halved
		# Only counter-pick if we can afford the counter ship
		if counter_type in affordable and randf() < counter_chance:
			return counter_type

	# Weighted random selection from affordable ships
	return _weighted_ship_selection(team, affordable, weights)


func _weighted_ship_selection(team: int, affordable: Array, weights: Dictionary) -> int:
	# Get team's ship priorities
	var priorities = ship_priorities.get(team, {})

	# Calculate total weight for affordable ships (with priority multipliers)
	var total_weight = 0.0
	for ship_type in affordable:
		var base_weight = weights.get(ship_type, 1.0)
		var priority_mult = priorities.get(ship_type, 1)  # Default 1x
		total_weight += base_weight * priority_mult

	if total_weight <= 0:
		return affordable[randi() % affordable.size()]

	# Roll and select
	var roll = randf() * total_weight
	var cumulative = 0.0
	for ship_type in affordable:
		var base_weight = weights.get(ship_type, 1.0)
		var priority_mult = priorities.get(ship_type, 1)
		cumulative += base_weight * priority_mult
		if roll <= cumulative:
			return ship_type

	# Fallback
	return affordable[affordable.size() - 1]


func get_ship_priority(team: int, ship_type: int) -> int:
	return ship_priorities.get(team, {}).get(ship_type, 1)


func cycle_ship_priority(team: int, ship_type: int):
	# Cycle through priority values: 1 -> 2 -> 3 -> 100 -> 1
	var current = get_ship_priority(team, ship_type)
	var idx = PRIORITY_CYCLE.find(current)
	var next_idx = (idx + 1) % PRIORITY_CYCLE.size()
	var new_priority = PRIORITY_CYCLE[next_idx]

	if not ship_priorities.has(team):
		ship_priorities[team] = {}
	ship_priorities[team][ship_type] = new_priority

	priority_changed.emit(team, ship_type, new_priority)

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
			# Only count standard combat weapons (GUN, LASER, MISSILE)
			if weapon != null and weapon_counts.has(weapon):
				weapon_counts[weapon] += 1

	return weapon_counts

func _get_counter_ship_type(enemy_weapons: Dictionary, stance: int) -> int:
	# Find most common enemy weapon
	var max_count = 0
	var dominant_weapon = VnpTypes.WeaponType.GUN

	for weapon in enemy_weapons:
		if enemy_weapons[weapon] > max_count:
			max_count = enemy_weapons[weapon]
			dominant_weapon = weapon

	# Counter ship options - stance affects which counter we prefer
	# Defensive stance prefers support ships, Aggressive prefers combat ships
	var defensive_bias = 0.4
	if stance == VnpTypes.FleetStance.DEFENSIVE:
		defensive_bias = 0.7  # 70% chance for defensive counter
	elif stance == VnpTypes.FleetStance.AGGRESSIVE:
		defensive_bias = 0.2  # Only 20% chance for defensive counter

	match dominant_weapon:
		VnpTypes.WeaponType.GUN:
			# Graviton deflects railguns, Cruiser (missiles) beats Gun
			if randf() < defensive_bias:
				return VnpTypes.ShipType.GRAVITON
			return VnpTypes.ShipType.CRUISER
		VnpTypes.WeaponType.LASER:
			# Shielder counters lasers, Frigate (gun) beats Laser
			if randf() < defensive_bias:
				return VnpTypes.ShipType.SHIELDER
			return VnpTypes.ShipType.FRIGATE
		VnpTypes.WeaponType.MISSILE:
			# Defender intercepts missiles, Destroyer (laser) beats Missile
			if randf() < defensive_bias:
				return VnpTypes.ShipType.DEFENDER
			return VnpTypes.ShipType.DESTROYER

	return VnpTypes.ShipType.FRIGATE

func stop_all():
	for team in build_timers:
		build_timers[team].stop()

func start_all():
	for team in build_timers:
		build_timers[team].start()


# === Fleet Formation Info for Ships ===

func get_formation(team: int) -> int:
	return team_formations.get(team, VnpTypes.FleetFormation.OFFENSIVE)


func get_adherence(team: int) -> int:
	return team_adherence.get(team, VnpTypes.FleetAdherence.LOOSE)


func get_fleet_center(team: int) -> Vector2:
	"""Get center of gravity for a team's fleet, biased toward rally point for attack-move"""
	var state = store.get_state()
	var formation = get_formation(team)
	var base_pos = base_positions.get(team, Vector2.ZERO)
	var rally_point = get_rally_point(team)
	var include_base_anchor = formation == VnpTypes.FleetFormation.DEFENSIVE

	# Use pure function from VnpSystems
	return VnpSystems.calculate_fleet_center(
		team, state.ships, base_pos, rally_point, include_base_anchor
	)


func get_rally_point(team: int) -> Vector2:
	"""Get rally point for a team from state"""
	var state = store.get_state()
	if not state.teams.has(team):
		return Vector2.ZERO
	var team_data = state.teams[team]
	var rally = team_data.get("rally_point", null)
	if rally is Vector2:
		return rally
	return Vector2.ZERO


func get_fleet_front_line(team: int) -> Vector2:
	"""Get the front line of engagement - where the fighting is happening"""
	var state = store.get_state()
	var fleet_center = get_fleet_center(team)

	# Find nearest enemy
	var nearest_enemy_center = Vector2.ZERO
	var nearest_dist = INF

	for enemy_team in VnpTypes.Team.values():
		if enemy_team == team:
			continue
		var enemy_center = get_fleet_center(enemy_team)
		var dist = fleet_center.distance_to(enemy_center)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy_center = enemy_center

	if nearest_dist == INF:
		return fleet_center

	# Front line is between our center and enemy center
	return fleet_center.lerp(nearest_enemy_center, 0.4)


func get_formation_position(team: int, ship_type: int, current_pos: Vector2) -> Vector2:
	"""Get ideal position for a ship type based on fleet formation"""
	var formation = get_formation(team)
	var fleet_center = get_fleet_center(team)
	var front_line = get_fleet_front_line(team)

	var ship_stats = VnpTypes.SHIP_STATS.get(ship_type, {})
	var weapon_range = ship_stats.get("range", 200)
	var ship_role = _get_ship_role(ship_type)

	if formation == VnpTypes.FleetFormation.DEFENSIVE:
		# Defensive: Overlap weapon ranges, longer range in back
		return _get_defensive_position(fleet_center, front_line, weapon_range, ship_role)
	else:
		# Offensive: Individual target optimization
		return _get_offensive_position(current_pos, front_line, weapon_range, ship_role)


func _get_ship_role(ship_type: int) -> String:
	match ship_type:
		VnpTypes.ShipType.FRIGATE:
			return "assault"  # Fast, short range - dart in and out
		VnpTypes.ShipType.DESTROYER:
			return "sniper"   # Mid range, precise
		VnpTypes.ShipType.CRUISER:
			return "artillery"  # Long range, slow
		VnpTypes.ShipType.DEFENDER:
			return "support"   # Protect fleet from missiles
		VnpTypes.ShipType.SHIELDER:
			return "support"   # Provide shields to allies
		VnpTypes.ShipType.GRAVITON:
			return "support"   # Deflect railguns
		VnpTypes.ShipType.STARBASE:
			return "anchor"    # Immobile fortress
	return "assault"


func _get_defensive_position(fleet_center: Vector2, front_line: Vector2, weapon_range: float, role: String) -> Vector2:
	"""Position ship in defensive formation - layered defense with overlapping ranges"""
	var front_dir = (front_line - fleet_center).normalized()
	if front_dir == Vector2.ZERO:
		front_dir = Vector2.RIGHT

	# Perpendicular for spreading ships across the line
	var spread_dir = front_dir.rotated(PI/2)

	match role:
		"assault":
			# Frigates: Front line but within support range, spread out
			var spread = randf_range(-80, 80)
			return fleet_center + front_dir * 100 + spread_dir * spread
		"sniper":
			# Destroyers: Behind frigates, good firing position
			var spread = randf_range(-60, 60)
			return fleet_center + front_dir * 40 + spread_dir * spread
		"artillery":
			# Cruisers: Back line, clustered for protection
			var spread = randf_range(-40, 40)
			return fleet_center - front_dir * 60 + spread_dir * spread
		"support":
			# Support ships: Center of formation for maximum coverage
			var spread = randf_range(-50, 50)
			return fleet_center + spread_dir * spread
		"anchor":
			# Starbases don't move
			return fleet_center

	return fleet_center


func _get_offensive_position(current_pos: Vector2, front_line: Vector2, weapon_range: float, role: String) -> Vector2:
	"""Position ship in offensive formation - aggressive push toward enemies"""
	match role:
		"assault":
			# Frigates: Push hard toward front line
			return current_pos.lerp(front_line, 0.4)
		"sniper":
			# Destroyers: Move to optimal firing range
			return current_pos.lerp(front_line, 0.25)
		"artillery":
			# Cruisers: Advance but maintain range
			return current_pos.lerp(front_line, 0.15)
		"support":
			# Support: Follow the assault ships
			return current_pos.lerp(front_line, 0.3)
		"anchor":
			return current_pos  # Starbases don't move

	return current_pos.lerp(front_line, 0.2)


func should_stay_with_fleet(team: int, ship_type: int) -> bool:
	"""Check if ship should prioritize staying with fleet over chasing enemies"""
	var formation = get_formation(team)
	if formation == VnpTypes.FleetFormation.DEFENSIVE:
		# In defensive formation, support ships always stay with fleet
		var role = _get_ship_role(ship_type)
		return role == "support" or role == "artillery"
	return false


func get_max_chase_distance(team: int, ship_type: int) -> float:
	"""Get maximum distance a ship should chase from fleet center"""
	var formation = get_formation(team)
	var role = _get_ship_role(ship_type)

	if formation == VnpTypes.FleetFormation.DEFENSIVE:
		match role:
			"assault":
				return 300.0  # Frigates can venture out but return
			"sniper":
				return 250.0
			"artillery":
				return 150.0  # Cruisers stay close
			"support":
				return 120.0  # Support stays very close
	else:  # Offensive
		match role:
			"assault":
				return 600.0  # Chase far
			"sniper":
				return 500.0
			"artillery":
				return 400.0
			"support":
				return 450.0

	return 400.0
