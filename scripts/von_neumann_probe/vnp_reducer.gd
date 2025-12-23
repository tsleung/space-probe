extends Node

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

# Minimum cost to build any combat ship
const MIN_SHIP_COST = 50  # Frigate cost

# Expansion constants
const INITIAL_WORLD_SCALE = 1.5
const EXPANSION_SCALE_INCREMENT = 0.3
const MAX_EXPANSIONS = 10

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
		"expansion": {
			"phase": 0,
			"world_scale": INITIAL_WORLD_SCALE,
			"max_phase": MAX_EXPANSIONS,
		},
		# The Cycle - Convergence system
		"convergence": {
			"phase": VnpTypes.ConvergencePhase.DORMANT,
			"center": Vector2.ZERO,           # Set by vnp_main when initialized
			"original_radius": 0.0,           # Set when convergence starts
			"absorption_radius": 0.0,         # Current safe zone (shrinks)
			"pull_strength": 0.0,             # Current gravitational pull
			"instability": 0.0,               # 0-100, fragmentation at 100
			"absorbed_count": 0,              # Ships consumed by the Progenitor
			"time_in_phase": 0.0,             # Time tracker for transitions
			"progenitor_revealed": false,     # Has ??? become THE PROGENITOR?
		},
		# Outpost system - mini-factories at strategic points
		"outposts": {},  # point_id -> { team, build_progress, production_timer }
		"next_ship_id": 1,
		"next_expansion_point_id": 0,
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

		"FULL_SEND":
			# Force ALL ships of this team to aggressively move to target
			var team = action["team"]
			var target = action["target"]
			if new_state["teams"].has(team):
				new_state["teams"][team]["rally_point"] = target
				new_state["teams"][team]["full_send_target"] = target
				# Set all ships to moving state toward target
				for ship_id in new_state["ships"]:
					var ship = new_state["ships"][ship_id]
					if ship["team"] == team:
						# Add some spread so ships don't all stack
						var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
						new_state["ships"][ship_id]["state"] = "moving"
						new_state["ships"][ship_id]["target"] = target + offset

		"EXPAND_WORLD":
			# Expand the map - increase world scale and phase
			var current_phase = new_state["expansion"]["phase"]
			var max_phase = new_state["expansion"]["max_phase"]
			if current_phase < max_phase:
				new_state["expansion"]["phase"] = current_phase + 1
				new_state["expansion"]["world_scale"] += EXPANSION_SCALE_INCREMENT

		"SPAWN_EXPANSION_POINT":
			# Spawn a new strategic point at the edge of expanded territory
			var point_id = action["point_id"]
			var point_type = action.get("point_type", VnpTypes.PointType.ASTEROID_FIELD)
			var position = action["position"]
			new_state["strategic_points"][point_id] = {
				"type": point_type,
				"position": position,
				"owner": null,
			}
			new_state["next_expansion_point_id"] += 1

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

		# === THE CYCLE - CONVERGENCE ACTIONS ===

		"CONVERGENCE_SET_PHASE":
			var phase = action["phase"]
			new_state["convergence"]["phase"] = phase
			new_state["convergence"]["time_in_phase"] = 0.0

			# Set pull strength based on phase
			var timing = VnpTypes.CONVERGENCE_TIMING
			match phase:
				VnpTypes.ConvergencePhase.EMERGENCE:
					new_state["convergence"]["pull_strength"] = timing["pull_strength_base"]
				VnpTypes.ConvergencePhase.CRITICAL:
					new_state["convergence"]["pull_strength"] = timing["pull_strength_critical"]
				_:
					new_state["convergence"]["pull_strength"] = 0.0

		"CONVERGENCE_INITIALIZE":
			# Called when convergence first triggers
			var center = action["center"]
			var radius = action["radius"]
			new_state["convergence"]["center"] = center
			new_state["convergence"]["original_radius"] = radius
			new_state["convergence"]["absorption_radius"] = radius

		"CONVERGENCE_SHRINK":
			# Shrink the absorption zone
			var amount = action["amount"]
			var min_radius = 100.0  # Never shrink smaller than this
			new_state["convergence"]["absorption_radius"] = max(
				new_state["convergence"]["absorption_radius"] - amount,
				min_radius
			)

		"CONVERGENCE_UPDATE_TIME":
			# Update time in current phase
			var delta = action["delta"]
			new_state["convergence"]["time_in_phase"] += delta

		"CONVERGENCE_ABSORB_SHIP":
			# A ship was absorbed by the Progenitor
			var ship_id = action["ship_id"]
			if new_state["ships"].has(ship_id):
				new_state["ships"].erase(ship_id)
				new_state["convergence"]["absorbed_count"] += 1

		"CONVERGENCE_ADD_INSTABILITY":
			# Increase instability (toward fragmentation)
			var amount = action["amount"]
			new_state["convergence"]["instability"] = min(
				new_state["convergence"]["instability"] + amount,
				VnpTypes.CONVERGENCE_TIMING["instability_threshold"]
			)

		"CONVERGENCE_REVEAL_PROGENITOR":
			# Transition from ??? to THE PROGENITOR
			new_state["convergence"]["progenitor_revealed"] = true

		"CONVERGENCE_SLIDE":
			# Slide the convergence center (pushing the safe zone)
			var new_center = action["new_center"]
			new_state["convergence"]["center"] = new_center

		"CONVERGENCE_FRAGMENTATION":
			# The Progenitor shatters - player survives
			new_state["convergence"]["phase"] = VnpTypes.ConvergencePhase.FRAGMENTATION
			new_state["game_over"] = true
			# Winner is whoever has the most ships (they become next Progenitor)
			var team_counts = {}
			for ship_id in new_state["ships"]:
				var team = new_state["ships"][ship_id]["team"]
				team_counts[team] = team_counts.get(team, 0) + 1
			var best_team = -1
			var best_count = 0
			for team in team_counts:
				if team_counts[team] > best_count:
					best_count = team_counts[team]
					best_team = team
			new_state["winner"] = best_team

		"FULL_RETREAT":
			# The flip of FULL_SEND - flee toward center (safety)
			var team = action["team"]
			var safe_center = new_state["convergence"]["center"]
			if new_state["teams"].has(team):
				new_state["teams"][team]["rally_point"] = safe_center
				new_state["teams"][team]["full_retreat_active"] = true
				# Set all ships to flee toward center
				for ship_id in new_state["ships"]:
					var ship = new_state["ships"][ship_id]
					if ship["team"] == team:
						var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
						new_state["ships"][ship_id]["state"] = "moving"
						new_state["ships"][ship_id]["target"] = safe_center + offset

		# === OUTPOST SYSTEM ACTIONS ===

		"OUTPOST_START_BUILD":
			# Harvester begins building at a strategic point
			var point_id = action["point_id"]
			var team = action["team"]
			if not new_state["outposts"].has(point_id):
				new_state["outposts"][point_id] = {
					"team": team,
					"build_progress": 0.0,
					"production_timer": 0.0,
					"complete": false,
				}

		"OUTPOST_UPDATE_BUILD":
			# Update build progress for an outpost
			var point_id = action["point_id"]
			var delta = action["delta"]
			if new_state["outposts"].has(point_id):
				var outpost = new_state["outposts"][point_id]
				if not outpost["complete"]:
					outpost["build_progress"] += delta
					var build_time = VnpTypes.OUTPOST_CONFIG["build_time"]
					if outpost["build_progress"] >= build_time:
						outpost["complete"] = true
						outpost["production_timer"] = 0.0

		"OUTPOST_CANCEL_BUILD":
			# Harvester left before completion - cancel build
			var point_id = action["point_id"]
			if new_state["outposts"].has(point_id):
				if not new_state["outposts"][point_id]["complete"]:
					new_state["outposts"].erase(point_id)

		"OUTPOST_PRODUCE":
			# Outpost produces a ship (handled by vnp_main for spawning)
			var point_id = action["point_id"]
			if new_state["outposts"].has(point_id):
				new_state["outposts"][point_id]["production_timer"] = 0.0

		"OUTPOST_UPDATE_PRODUCTION":
			# Tick production timers for all complete outposts
			var delta = action["delta"]
			for point_id in new_state["outposts"]:
				var outpost = new_state["outposts"][point_id]
				if outpost["complete"]:
					outpost["production_timer"] += delta

		"OUTPOST_DESTROY":
			# Outpost consumed by Progenitor or captured
			var point_id = action["point_id"]
			if new_state["outposts"].has(point_id):
				new_state["outposts"].erase(point_id)

		"OUTPOST_CHANGE_OWNER":
			# Strategic point captured - outpost changes team or is destroyed
			var point_id = action["point_id"]
			var new_team = action["team"]
			if new_state["outposts"].has(point_id):
				# Outpost is destroyed when point changes hands
				new_state["outposts"].erase(point_id)

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