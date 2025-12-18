extends Node

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

# Minimum cost to build any combat ship
const MIN_SHIP_COST = 50  # Frigate cost

# Initial state of the game
func get_initial_state():
	return {
		"teams": {
			VnpTypes.Team.PLAYER: {"energy": 800, "mass": 0, "rally_point": null},
			VnpTypes.Team.ENEMY_1: {"energy": 800, "mass": 0, "rally_point": null},
			VnpTypes.Team.NEMESIS: {"energy": 1500, "mass": 0, "rally_point": null},
		},
		"ships": {}, # { id: { team, type, position, health, target... } }
		"planets": {}, # { id: { position, resource_amount, owner } } - legacy, keeping for compat
		"strategic_points": {}, # { id: { type, position, owner, capture_progress } }
		"next_ship_id": 1,
		"game_over": false,
		"winner": -1,
	}

# Reducer function to update state based on actions
func reduce(state, action):
	var new_state = state.duplicate(true)  # Deep copy to detect changes

	match action["type"]:
		"BUILD_SHIP":
			var team = action["team"]
			var ship_type = action["ship_type"]
			var ship_stats = VnpTypes.SHIP_STATS[ship_type]
			var energy_cost = ship_stats["cost"]
			var mass_cost = ship_stats.get("mass_cost", 0)

			var has_energy = new_state["teams"][team]["energy"] >= energy_cost
			var has_mass = new_state["teams"][team]["mass"] >= mass_cost

			if has_energy and has_mass:
				new_state["teams"][team]["energy"] -= energy_cost
				new_state["teams"][team]["mass"] -= mass_cost

				var ship_id = new_state["next_ship_id"]
				new_state["next_ship_id"] += 1

				# Check for health bonus from relay control
				var base_health = ship_stats["health"]
				var health_bonus = _get_team_health_bonus(new_state, team)
				var final_health = int(base_health * (1.0 + health_bonus))

				new_state["ships"][ship_id] = {
					"id": ship_id,
					"team": team,
					"type": ship_type,
					"position": action["position"], # Initial position from action
					"health": final_health,
					"state": "idle", # e.g., idle, moving, attacking, harvesting
					"target": null, # Target can be a ship ID or a planet ID
				}
		
		"SET_SHIP_STATE":
			var ship_id = action["ship_id"]
			if new_state["ships"].has(ship_id):
				new_state["ships"][ship_id]["state"] = action["state"]
				new_state["ships"][ship_id]["target"] = action.get("target", null)

		"UPDATE_SHIP_POSITION":
			var ship_id = action["ship_id"]
			if new_state["ships"].has(ship_id):
				new_state["ships"][ship_id]["position"] = action["position"]
		
		"DAMAGE_SHIP":
			var ship_id = action["ship_id"]
			if new_state["ships"].has(ship_id):
				new_state["ships"][ship_id]["health"] -= action["damage"]
				if new_state["ships"][ship_id]["health"] <= 0:
					new_state["ships"].erase(ship_id)
		
		"ADD_ENERGY":
			var team = action["team"]
			var amount = action["amount"]
			if new_state["teams"].has(team):
				new_state["teams"][team]["energy"] += amount
				
		"INITIALIZE_PLANETS":
			new_state["planets"] = action["planets"]

		"CAPTURE_PLANET":
			var planet_id = action["planet_id"]
			var team = action["team"]
			if new_state["planets"].has(planet_id):
				var old_owner = new_state["planets"][planet_id].get("owner", null)
				new_state["planets"][planet_id]["owner"] = team
				# Capturing a planet gives bonus energy
				if old_owner != team:
					var bonus = 100  # Capture bonus
					new_state["teams"][team]["energy"] += bonus

		"PLANET_INCOME":
			# Each owned planet generates passive income (legacy)
			for planet_id in new_state["planets"]:
				var planet = new_state["planets"][planet_id]
				var owner = planet.get("owner", null)
				if owner != null and new_state["teams"].has(owner):
					var income = 5  # Energy per planet per tick
					new_state["teams"][owner]["energy"] += income

		"INITIALIZE_STRATEGIC_POINTS":
			new_state["strategic_points"] = action["points"]

		"CAPTURE_STRATEGIC_POINT":
			var point_id = action["point_id"]
			var team = action["team"]
			if new_state["strategic_points"].has(point_id):
				var old_owner = new_state["strategic_points"][point_id].get("owner", null)
				new_state["strategic_points"][point_id]["owner"] = team
				# Capturing gives instant bonus
				if old_owner != team:
					new_state["teams"][team]["energy"] += 50
					new_state["teams"][team]["mass"] += 10

		"STRATEGIC_POINT_INCOME":
			# Each owned strategic point generates mass income
			for point_id in new_state["strategic_points"]:
				var point = new_state["strategic_points"][point_id]
				var owner = point.get("owner", null)
				if owner != null and new_state["teams"].has(owner):
					var point_type = point.get("type", VnpTypes.PointType.ASTEROID_FIELD)
					var bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
					var mass_income = bonuses.get("mass_income", 0)
					new_state["teams"][owner]["mass"] += mass_income

		"ADD_MASS":
			var team = action["team"]
			var amount = action["amount"]
			if new_state["teams"].has(team):
				new_state["teams"][team]["mass"] += amount

		"SET_RALLY_POINT":
			var team = action["team"]
			var target = action["target"]  # Can be point_id, "enemy_base", or position Vector2
			if new_state["teams"].has(team):
				new_state["teams"][team]["rally_point"] = target

		"CHECK_VICTORY":
			if not new_state.get("game_over", false):
				var teams_alive = []
				for team in new_state.teams:
					var has_ships = _team_has_ships(new_state, team)
					var can_build = new_state.teams[team].energy >= MIN_SHIP_COST
					if has_ships or can_build:
						teams_alive.append(team)

				if teams_alive.size() <= 1:
					new_state["game_over"] = true
					new_state["winner"] = teams_alive[0] if teams_alive.size() == 1 else -1

		"RESET_GAME":
			new_state = get_initial_state()

	return new_state

func _team_has_ships(state: Dictionary, team: int) -> bool:
	for ship_id in state.ships:
		if state.ships[ship_id].team == team:
			return true
	return false


func _get_team_health_bonus(state: Dictionary, team: int) -> float:
	"""Calculate health bonus from controlled relay stations"""
	var bonus = 0.0
	for point_id in state.strategic_points:
		var point = state.strategic_points[point_id]
		if point.get("owner", null) == team:
			var point_type = point.get("type", -1)
			var point_bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
			bonus += point_bonuses.get("health_bonus", 0.0)
	return bonus


func _get_team_damage_bonus(state: Dictionary, team: int) -> float:
	"""Calculate damage bonus from controlled center point"""
	var bonus = 0.0
	for point_id in state.strategic_points:
		var point = state.strategic_points[point_id]
		if point.get("owner", null) == team:
			var point_type = point.get("type", -1)
			var point_bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
			bonus += point_bonuses.get("damage_bonus", 0.0)
	return bonus


static func get_team_damage_bonus_static(state: Dictionary, team: int) -> float:
	"""Static version for use from ship.gd"""
	var bonus = 0.0
	for point_id in state.strategic_points:
		var point = state.strategic_points[point_id]
		if point.get("owner", null) == team:
			var point_type = point.get("type", -1)
			var point_bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
			bonus += point_bonuses.get("damage_bonus", 0.0)
	return bonus