extends RefCounted
class_name FCWStateEvaluator

## FCW State Evaluator - Objective functions and heuristics for AI
##
## The primary objective is LIVES EVACUATED.
## Secondary factors influence decision-making mid-game:
## - Fleet strength (ability to delay Herald)
## - Zone control (resource generation, evacuation capacity)
## - Time remaining (urgency of evacuation)
##
## "Every number is a life. Every decision matters."

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWReducer = preload("res://scripts/first_contact_war/fcw_reducer.gd")

# ============================================================================
# PRIMARY OBJECTIVE
# ============================================================================

static func evaluate(state: Dictionary) -> float:
	## Primary evaluation: lives evacuated
	## This is THE objective function for optimization
	return float(state.get("lives_evacuated", 0))

static func evaluate_terminal(state: Dictionary) -> float:
	## Evaluation for terminal (game over) states
	## Includes victory tier bonus for tie-breaking
	var lives = float(state.get("lives_evacuated", 0))
	var tier = state.get("victory_tier", 0)

	# Victory tier serves as a small bonus (doesn't override lives saved)
	var tier_bonus = tier * 1000000  # 1M bonus per tier

	return lives + tier_bonus

# ============================================================================
# COMPOSITE HEURISTICS (for mid-game decisions)
# ============================================================================

static func evaluate_composite(state: Dictionary, weights: Dictionary = {}) -> float:
	## Weighted evaluation combining multiple factors
	## Default weights emphasize lives_evacuated but include strategic factors
	##
	## Available factors:
	## - lives_evacuated: Primary objective
	## - fleet_strength: Military capability
	## - zone_control: Resource/evacuation capacity
	## - evacuation_rate: Current evacuation throughput
	## - time_pressure: Urgency multiplier
	## - defense_ratio: Fleet strength vs Herald strength

	var w = {
		"lives_evacuated": weights.get("lives_evacuated", 1.0),
		"fleet_strength": weights.get("fleet_strength", 0.001),
		"zone_control": weights.get("zone_control", 0.1),
		"evacuation_rate": weights.get("evacuation_rate", 0.01),
		"defense_ratio": weights.get("defense_ratio", 0.05)
	}

	var score = 0.0

	# Primary: Lives evacuated (normalized to millions)
	score += w.lives_evacuated * state.get("lives_evacuated", 0) / 1000000.0

	# Fleet strength (combat power available)
	score += w.fleet_strength * get_fleet_strength(state)

	# Zone control (number of controlled zones)
	score += w.zone_control * FCWReducer.get_controlled_zones(state).size()

	# Evacuation capacity (potential throughput)
	score += w.evacuation_rate * get_evacuation_capacity(state)

	# Defense ratio (can we hold the line?)
	score += w.defense_ratio * get_defense_ratio(state)

	return score

# ============================================================================
# STRATEGIC FACTORS
# ============================================================================

static func get_fleet_strength(state: Dictionary) -> float:
	## Total combat power of player fleet
	return float(FCWReducer.get_total_fleet_strength(state))

static func get_evacuation_capacity(state: Dictionary) -> float:
	## Estimated evacuation rate (lives per turn)
	var controlled = FCWReducer.get_controlled_zones(state)
	var total_pop = 0

	for zone_id in controlled:
		var zone = state.zones.get(zone_id, {})
		total_pop += zone.get("population", 0)

	# Rough estimate: 1% of population can evacuate per turn
	return total_pop * 0.01

static func get_defense_ratio(state: Dictionary) -> float:
	## Player fleet strength vs Herald strength (>1 = advantage)
	var fleet = FCWReducer.get_total_fleet_strength(state)
	var herald = state.get("herald_strength", 1)
	if herald <= 0:
		return 10.0  # Arbitrary high value
	return float(fleet) / float(herald)

static func get_zone_vulnerability(state: Dictionary, zone_id: int) -> float:
	## How vulnerable is a zone? (0 = safe, 1 = falling)
	var zone = state.zones.get(zone_id, {})
	if zone.get("status") == FCWTypes.ZoneStatus.FALLEN:
		return 1.0

	var defense = FCWReducer.calc_zone_defense(state, zone_id)
	var herald_strength = state.get("herald_strength", 100)

	if defense >= herald_strength:
		return 0.0

	return 1.0 - (float(defense) / float(herald_strength))

static func get_strategic_value(state: Dictionary, zone_id: int) -> float:
	## Strategic value of a zone (higher = more important)
	var zone = state.zones.get(zone_id, {})

	var value = 0.0

	# Population matters most
	value += zone.get("population", 0) / 10000000.0  # Normalize to ~1-10 range

	# Resource production
	value += zone.get("production", 0) * 0.5

	# Key zones get bonus
	if zone_id == FCWTypes.ZoneId.EARTH:
		value += 10.0  # Earth is critical
	elif zone_id == FCWTypes.ZoneId.MARS:
		value += 3.0

	return value

static func get_urgency(state: Dictionary) -> float:
	## How urgent is action? (based on Herald progress)
	var turns_remaining = FCWReducer.estimate_turns_until_earth_attack(state)
	if turns_remaining <= 0:
		return 1.0  # Maximum urgency

	# Urgency increases as Herald approaches
	return 1.0 / (1.0 + turns_remaining * 0.1)

# ============================================================================
# DECISION SCORING
# ============================================================================

static func score_action(state: Dictionary, action: Dictionary) -> float:
	## Score an action by simulating it and comparing states
	## Higher score = better action

	# Simulate action
	var next_state = FCWReducer.reduce(state, action)

	# Compare evaluations
	var before = evaluate_composite(state)
	var after = evaluate_composite(next_state)

	return after - before

static func rank_actions(state: Dictionary, actions: Array) -> Array:
	## Rank actions by their scores
	## Returns array of {action, score} sorted by score descending

	var scored: Array = []
	for action in actions:
		scored.append({
			"action": action,
			"score": score_action(state, action)
		})

	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored

static func get_best_action(state: Dictionary, actions: Array) -> Dictionary:
	## Get the highest-scored action
	if actions.is_empty():
		return {}

	var ranked = rank_actions(state, actions)
	return ranked[0].action

# ============================================================================
# GAME PHASE DETECTION
# ============================================================================

enum GamePhase {
	EARLY,      # Building up, Herald far away
	MID,        # Active defense, evacuation ramping
	LATE,       # Desperate, Herald at inner zones
	ENDGAME     # Earth threatened, all-out evacuation
}

static func get_game_phase(state: Dictionary) -> int:
	## Detect current game phase for strategy adaptation
	var turn = state.get("turn", 0)
	var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var earth_status = state.zones.get(FCWTypes.ZoneId.EARTH, {}).get("status", 0)

	if earth_status == FCWTypes.ZoneStatus.UNDER_ATTACK:
		return GamePhase.ENDGAME

	if herald_zone in [FCWTypes.ZoneId.EARTH, FCWTypes.ZoneId.MARS]:
		return GamePhase.LATE

	if turn > 10 or herald_zone in [FCWTypes.ZoneId.ASTEROID_BELT, FCWTypes.ZoneId.JUPITER]:
		return GamePhase.MID

	return GamePhase.EARLY

static func get_phase_weights(phase: int) -> Dictionary:
	## Get evaluation weights appropriate for game phase
	match phase:
		GamePhase.EARLY:
			# Focus on building up
			return {
				"lives_evacuated": 0.5,
				"fleet_strength": 0.3,
				"zone_control": 0.2,
				"evacuation_rate": 0.0,
				"defense_ratio": 0.0
			}
		GamePhase.MID:
			# Balanced
			return {
				"lives_evacuated": 0.7,
				"fleet_strength": 0.1,
				"zone_control": 0.1,
				"evacuation_rate": 0.05,
				"defense_ratio": 0.05
			}
		GamePhase.LATE:
			# Focus on evacuation
			return {
				"lives_evacuated": 0.85,
				"fleet_strength": 0.05,
				"zone_control": 0.05,
				"evacuation_rate": 0.05,
				"defense_ratio": 0.0
			}
		GamePhase.ENDGAME:
			# Pure survival
			return {
				"lives_evacuated": 1.0,
				"fleet_strength": 0.0,
				"zone_control": 0.0,
				"evacuation_rate": 0.0,
				"defense_ratio": 0.0
			}
		_:
			return {}

# ============================================================================
# UTILITY
# ============================================================================

static func format_evaluation(state: Dictionary) -> String:
	## Format evaluation as human-readable string
	var phase = get_game_phase(state)
	var phase_name = GamePhase.keys()[phase]
	var weights = get_phase_weights(phase)

	return """=== State Evaluation ===
Phase: %s
Lives Evacuated: %s
Fleet Strength: %d
Defense Ratio: %.2f
Controlled Zones: %d
Urgency: %.2f
Composite Score: %.2f""" % [
		phase_name,
		FCWTypes.format_population(state.get("lives_evacuated", 0)),
		get_fleet_strength(state),
		get_defense_ratio(state),
		FCWReducer.get_controlled_zones(state).size(),
		get_urgency(state),
		evaluate_composite(state, weights)
	]
