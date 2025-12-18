extends Node

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")

# Minimum cost to build any combat ship
const MIN_SHIP_COST = 50  # Frigate cost

# Initial state of the game
func get_initial_state():
	return {
		"teams": {
			VnpTypes.Team.PLAYER: {"energy": 500},
			VnpTypes.Team.ENEMY_1: {"energy": 500},
			VnpTypes.Team.NEMESIS: {"energy": 1000},
		},
		"ships": {}, # { id: { team, type, position, health, target... } }
		"planets": {}, # { id: { position, resource_amount, owner } }
		"next_ship_id": 1,
		"game_over": false,
		"winner": -1,
	}

# Reducer function to update state based on actions
func reduce(state, action):
	var new_state = state # Start with the current state

	match action["type"]:
		"BUILD_SHIP":
			var team = action["team"]
			var ship_type = action["ship_type"]
			var ship_cost = VnpTypes.SHIP_STATS[ship_type]["cost"]
			
			if new_state["teams"][team]["energy"] >= ship_cost:
				new_state["teams"][team]["energy"] -= ship_cost
				
				var ship_id = new_state["next_ship_id"]
				new_state["next_ship_id"] += 1
				
				new_state["ships"][ship_id] = {
					"id": ship_id,
					"team": team,
					"type": ship_type,
					"position": action["position"], # Initial position from action
					"health": VnpTypes.SHIP_STATS[ship_type]["health"],
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