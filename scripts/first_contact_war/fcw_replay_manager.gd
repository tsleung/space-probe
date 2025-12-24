extends RefCounted
class_name FCWReplayManager

## FCW Replay Manager - Record and replay deterministic games
##
## Recording Format:
## {
##   "version": "1.0.0",
##   "seed": 12345678901234,
##   "initial_state": {...},  # Optional, for verification
##   "actions": [
##     {"tick": 0, "action": {...}},
##     {"tick": 1, "action": {...}}
##   ],
##   "outcome": {
##     "lives_evacuated": 45000000,
##     "lives_lost": 120000000,
##     "victory_tier": 1,
##     "final_turn": 52
##   }
## }

const VERSION = "1.0.0"

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWReducer = preload("res://scripts/first_contact_war/fcw_reducer.gd")

# ============================================================================
# RECORDING
# ============================================================================

static func create_recording(seed: int, action_history: Array, final_state: Dictionary) -> Dictionary:
	## Create a recording from a completed game
	return {
		"version": VERSION,
		"seed": seed,
		"actions": action_history.duplicate(true),
		"outcome": {
			"lives_evacuated": final_state.get("lives_evacuated", 0),
			"lives_lost": final_state.get("lives_lost", 0),
			"lives_intercepted": final_state.get("lives_intercepted", 0),
			"victory_tier": final_state.get("victory_tier", 0),
			"final_turn": final_state.get("turn", 0),
			"game_over": final_state.get("game_over", false)
		}
	}

static func save_recording(recording: Dictionary, filepath: String) -> bool:
	## Save recording to JSON file
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("FCWReplayManager: Failed to open file for writing: %s" % filepath)
		return false

	file.store_string(JSON.stringify(recording, "\t"))
	file.close()
	return true

static func load_recording(filepath: String) -> Dictionary:
	## Load recording from JSON file
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("FCWReplayManager: Failed to open file for reading: %s" % filepath)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("FCWReplayManager: JSON parse error: %s" % json.get_error_message())
		return {}

	return json.data

# ============================================================================
# REPLAY
# ============================================================================

static func replay(recording: Dictionary, verify_outcome: bool = true) -> Dictionary:
	## Replay a recorded game and optionally verify the outcome matches
	## Returns: {success: bool, final_state: Dictionary, mismatch: String or null}

	if recording.is_empty():
		return {"success": false, "final_state": {}, "mismatch": "Empty recording"}

	var seed = recording.get("seed", -1)
	if seed == -1:
		return {"success": false, "final_state": {}, "mismatch": "No seed in recording"}

	# Initialize RNG with recorded seed
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Create initial state
	var state = FCWTypes.create_initial_state()
	var tick_count = 0

	# Replay each action
	var actions = recording.get("actions", [])
	for record in actions:
		var action = record.get("action", {})
		var expected_tick = record.get("tick", -1)

		# Verify tick alignment
		if expected_tick >= 0 and expected_tick != tick_count:
			push_warning("FCWReplayManager: Tick mismatch at %d (expected %d)" % [tick_count, expected_tick])

		# Regenerate random values for TICK actions
		if action.get("type") == "TICK":
			var random_values: Array = []
			for i in range(20):
				random_values.append(rng.randf())
			action = action.duplicate()
			action["random_values"] = random_values
		elif action.get("type") == "END_TURN":
			# Legacy action
			var random_values: Array = []
			for i in range(10):
				random_values.append(rng.randf())
			action = action.duplicate()
			action["random_values"] = random_values

		# Apply action
		state = FCWReducer.reduce(state, action)

		if action.get("type") == "TICK":
			tick_count += 1

	# Verify outcome if requested
	var mismatch = null
	if verify_outcome and recording.has("outcome"):
		var outcome = recording["outcome"]

		if state.get("lives_evacuated", 0) != outcome.get("lives_evacuated", 0):
			mismatch = "lives_evacuated: got %d, expected %d" % [
				state.get("lives_evacuated", 0),
				outcome.get("lives_evacuated", 0)
			]
		elif state.get("victory_tier", -1) != outcome.get("victory_tier", -1):
			mismatch = "victory_tier: got %d, expected %d" % [
				state.get("victory_tier", -1),
				outcome.get("victory_tier", -1)
			]
		elif state.get("turn", 0) != outcome.get("final_turn", 0):
			mismatch = "final_turn: got %d, expected %d" % [
				state.get("turn", 0),
				outcome.get("final_turn", 0)
			]

	return {
		"success": mismatch == null,
		"final_state": state,
		"mismatch": mismatch
	}

# ============================================================================
# VERIFICATION
# ============================================================================

static func verify_determinism(seed: int, num_ticks: int = 100) -> bool:
	## Run the same seed twice and verify identical results
	var result1 = _run_simulation(seed, num_ticks)
	var result2 = _run_simulation(seed, num_ticks)

	if result1.lives_evacuated != result2.lives_evacuated:
		push_error("Determinism failure: lives_evacuated mismatch (%d vs %d)" % [
			result1.lives_evacuated, result2.lives_evacuated
		])
		return false

	if result1.turn != result2.turn:
		push_error("Determinism failure: turn mismatch (%d vs %d)" % [
			result1.turn, result2.turn
		])
		return false

	if result1.herald_strength != result2.herald_strength:
		push_error("Determinism failure: herald_strength mismatch (%d vs %d)" % [
			result1.herald_strength, result2.herald_strength
		])
		return false

	print("FCWReplayManager: Determinism verified for seed %d (%d ticks)" % [seed, num_ticks])
	return true

static func _run_simulation(seed: int, num_ticks: int) -> Dictionary:
	## Run a simulation for N ticks and return final state
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var state = FCWTypes.create_initial_state()

	for _i in range(num_ticks):
		if state.game_over:
			break

		var random_values: Array = []
		for _j in range(20):
			random_values.append(rng.randf())

		state = FCWReducer.reduce(state, FCWReducer.action_tick(random_values))

	return state

# ============================================================================
# ANALYSIS
# ============================================================================

static func get_key_moments(recording: Dictionary) -> Array:
	## Extract key narrative moments from a recording
	## Returns array of {tick, event_type, description}
	var moments = []
	var state = FCWTypes.create_initial_state()
	var rng = RandomNumberGenerator.new()
	rng.seed = recording.get("seed", 0)

	var prev_zones_status = {}
	for zone_id in state.zones:
		prev_zones_status[zone_id] = state.zones[zone_id].get("status", 0)

	for record in recording.get("actions", []):
		var action = record.get("action", {})
		var tick = record.get("tick", 0)

		# Regenerate random values
		if action.get("type") == "TICK":
			var random_values: Array = []
			for i in range(20):
				random_values.append(rng.randf())
			action = action.duplicate()
			action["random_values"] = random_values

		# Apply action
		var prev_state = state.duplicate(true)
		state = FCWReducer.reduce(state, action)

		# Check for zone fallen
		for zone_id in state.zones:
			var new_status = state.zones[zone_id].get("status", 0)
			if new_status == FCWTypes.ZoneStatus.FALLEN and prev_zones_status.get(zone_id, 0) != FCWTypes.ZoneStatus.FALLEN:
				moments.append({
					"tick": tick,
					"event_type": "zone_fallen",
					"description": "%s has fallen to the Herald" % FCWTypes.get_zone_name(zone_id)
				})
			prev_zones_status[zone_id] = new_status

		# Check for game over
		if state.game_over and not prev_state.game_over:
			moments.append({
				"tick": tick,
				"event_type": "game_over",
				"description": "Game ended with victory tier %d" % state.victory_tier
			})

	return moments

static func get_decision_points(recording: Dictionary) -> Array:
	## Extract player decision points from a recording
	## Returns array of {tick, action_type, details}
	var decisions = []

	for record in recording.get("actions", []):
		var action = record.get("action", {})
		var action_type = action.get("type", "")

		# Filter to player decisions (not TICK or END_TURN)
		if action_type in ["BUILD_SHIP", "ASSIGN_FLEET", "RECALL_FLEET", "SET_FLEET_ORDER",
						   "SPAWN_ENTITY", "SET_DESTINATION", "LAUNCH_WEAPON", "SPLIT_ENTITY"]:
			decisions.append({
				"tick": record.get("tick", 0),
				"action_type": action_type,
				"details": action
			})

	return decisions
