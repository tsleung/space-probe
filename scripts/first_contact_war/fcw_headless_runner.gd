extends RefCounted
class_name FCWHeadlessRunner

## FCW Headless Runner - Run games without UI for AI optimization
##
## Use cases:
## - Run thousands of simulations to find optimal strategies
## - Test balance changes across many games
## - Generate training data for AI
## - Verify determinism across runs

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWReducer = preload("res://scripts/first_contact_war/fcw_reducer.gd")
const FCWReplayManager = preload("res://scripts/first_contact_war/fcw_replay_manager.gd")

# ============================================================================
# SINGLE GAME SIMULATION
# ============================================================================

static func run_game(seed: int, strategy: Callable = Callable(), max_ticks: int = 10000) -> Dictionary:
	## Run a single game with optional AI strategy
	## strategy: Callable(state: Dictionary) -> Array[Dictionary] of actions to dispatch
	## Returns: {seed, ticks, lives_evacuated, lives_lost, victory_tier, game_over, recording}

	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var state = FCWTypes.create_initial_state()
	var action_history: Array = []
	var tick_count = 0

	while not state.game_over and tick_count < max_ticks:
		# Let strategy make decisions before tick
		if strategy.is_valid():
			var decisions = strategy.call(state)
			for decision in decisions:
				state = FCWReducer.reduce(state, decision)
				action_history.append({"tick": tick_count, "action": decision})

		# Advance time by 1 hour
		var random_values: Array = []
		for _i in range(20):
			random_values.append(rng.randf())

		var tick_action = FCWReducer.action_tick(random_values)
		state = FCWReducer.reduce(state, tick_action)

		# Record without random_values (they're deterministic from seed)
		var recorded = tick_action.duplicate()
		recorded.erase("random_values")
		action_history.append({"tick": tick_count, "action": recorded})

		tick_count += 1

	return {
		"seed": seed,
		"ticks": tick_count,
		"lives_evacuated": state.get("lives_evacuated", 0),
		"lives_lost": state.get("lives_lost", 0),
		"lives_intercepted": state.get("lives_intercepted", 0),
		"victory_tier": state.get("victory_tier", 0),
		"game_over": state.get("game_over", false),
		"final_turn": state.get("turn", 0),
		"recording": FCWReplayManager.create_recording(seed, action_history, state)
	}

# ============================================================================
# BATCH SIMULATION
# ============================================================================

static func run_batch(count: int, strategy: Callable = Callable(), base_seed: int = -1) -> Dictionary:
	## Run multiple games and collect statistics
	## Returns: {
	##   count: int,
	##   average_lives_evacuated: float,
	##   average_lives_lost: float,
	##   tier_distribution: {0: count, 1: count, 2: count, 3: count},
	##   best_result: {...},
	##   worst_result: {...},
	##   results: Array[...]
	## }

	var rng = RandomNumberGenerator.new()
	if base_seed == -1:
		rng.randomize()
		base_seed = rng.randi()
	else:
		rng.seed = base_seed

	var results: Array = []
	var total_evacuated = 0
	var total_lost = 0
	var tier_counts = {0: 0, 1: 0, 2: 0, 3: 0}
	var best_result = null
	var worst_result = null

	for i in range(count):
		var game_seed = rng.randi()
		var result = run_game(game_seed, strategy)

		# Don't store full recordings in batch results (memory)
		var summary = result.duplicate()
		summary.erase("recording")
		results.append(summary)

		total_evacuated += result.lives_evacuated
		total_lost += result.lives_lost
		tier_counts[result.victory_tier] = tier_counts.get(result.victory_tier, 0) + 1

		if best_result == null or result.lives_evacuated > best_result.lives_evacuated:
			best_result = summary.duplicate()
		if worst_result == null or result.lives_evacuated < worst_result.lives_evacuated:
			worst_result = summary.duplicate()

	return {
		"count": count,
		"base_seed": base_seed,
		"average_lives_evacuated": float(total_evacuated) / count if count > 0 else 0.0,
		"average_lives_lost": float(total_lost) / count if count > 0 else 0.0,
		"tier_distribution": tier_counts,
		"best_result": best_result,
		"worst_result": worst_result,
		"results": results
	}

# ============================================================================
# STRATEGY TESTING
# ============================================================================

static func compare_strategies(strategies: Array, games_per_strategy: int = 100, base_seed: int = -1) -> Dictionary:
	## Compare multiple strategies on the same set of seeds
	## strategies: Array of {name: String, strategy: Callable}
	## Returns: {strategies: [{name, stats}], ranking: [name]}

	var rng = RandomNumberGenerator.new()
	if base_seed == -1:
		rng.randomize()
		base_seed = rng.randi()
	else:
		rng.seed = base_seed

	# Generate seeds to use for all strategies
	var seeds: Array = []
	for _i in range(games_per_strategy):
		seeds.append(rng.randi())

	var strategy_results: Array = []

	for strat_info in strategies:
		var name = strat_info.get("name", "Unnamed")
		var strategy = strat_info.get("strategy", Callable())

		var total_evacuated = 0
		var total_lost = 0
		var tier_counts = {0: 0, 1: 0, 2: 0, 3: 0}

		for game_seed in seeds:
			var result = run_game(game_seed, strategy)
			total_evacuated += result.lives_evacuated
			total_lost += result.lives_lost
			tier_counts[result.victory_tier] = tier_counts.get(result.victory_tier, 0) + 1

		strategy_results.append({
			"name": name,
			"average_lives_evacuated": float(total_evacuated) / games_per_strategy,
			"average_lives_lost": float(total_lost) / games_per_strategy,
			"tier_distribution": tier_counts
		})

	# Rank by average lives evacuated
	strategy_results.sort_custom(func(a, b): return a.average_lives_evacuated > b.average_lives_evacuated)
	var ranking = []
	for result in strategy_results:
		ranking.append(result.name)

	return {
		"games_per_strategy": games_per_strategy,
		"base_seed": base_seed,
		"seeds_used": seeds,
		"strategies": strategy_results,
		"ranking": ranking
	}

# ============================================================================
# BUILTIN STRATEGIES
# ============================================================================

static func strategy_passive() -> Callable:
	## Do nothing strategy - let events unfold
	return func(_state: Dictionary) -> Array:
		return []

static func strategy_build_cruisers() -> Callable:
	## Always build cruisers when possible
	return func(state: Dictionary) -> Array:
		var actions = []
		if FCWReducer.can_afford_ship(state, FCWTypes.ShipType.CRUISER):
			if state.production_queue.size() < FCWReducer.get_production_capacity(state):
				actions.append(FCWReducer.action_build_ship(FCWTypes.ShipType.CRUISER))
		return actions

static func strategy_build_carriers() -> Callable:
	## Prioritize carriers for long-term fleet strength
	return func(state: Dictionary) -> Array:
		var actions = []
		if FCWReducer.can_afford_ship(state, FCWTypes.ShipType.CARRIER):
			if state.production_queue.size() < FCWReducer.get_production_capacity(state):
				actions.append(FCWReducer.action_build_ship(FCWTypes.ShipType.CARRIER))
		return actions

static func strategy_defend_earth() -> Callable:
	## Focus all forces on Earth defense
	return func(state: Dictionary) -> Array:
		var actions = []

		# Build ships
		if FCWReducer.can_afford_ship(state, FCWTypes.ShipType.CRUISER):
			if state.production_queue.size() < FCWReducer.get_production_capacity(state):
				actions.append(FCWReducer.action_build_ship(FCWTypes.ShipType.CRUISER))

		# Assign all available ships to Earth
		var available = FCWReducer.get_available_ships(state)
		for ship_type in available:
			if available[ship_type] > 0:
				actions.append(FCWReducer.action_assign_fleet(FCWTypes.ZoneId.EARTH, ship_type, available[ship_type]))

		return actions

static func strategy_forward_defense() -> Callable:
	## Defend outer zones to delay Herald
	return func(state: Dictionary) -> Array:
		var actions = []

		# Build mix of ships
		if FCWReducer.can_afford_ship(state, FCWTypes.ShipType.CRUISER):
			if state.production_queue.size() < FCWReducer.get_production_capacity(state):
				actions.append(FCWReducer.action_build_ship(FCWTypes.ShipType.CRUISER))

		# Get the outermost controlled zone
		var controlled = FCWReducer.get_controlled_zones(state)
		if controlled.is_empty():
			return actions

		# Sort by distance from sun (outer first)
		controlled.sort_custom(func(a, b):
			return FCWTypes.get_zone_orbital_radius(a) > FCWTypes.get_zone_orbital_radius(b)
		)

		var outer_zone = controlled[0]

		# Assign ships to outer zone
		var available = FCWReducer.get_available_ships(state)
		for ship_type in available:
			if available[ship_type] > 0:
				actions.append(FCWReducer.action_assign_fleet(outer_zone, ship_type, available[ship_type]))

		return actions

# ============================================================================
# UTILITY
# ============================================================================

static func print_batch_summary(batch_result: Dictionary) -> void:
	## Print a human-readable summary of batch results
	print("=== FCW Batch Simulation Results ===")
	print("Games: %d" % batch_result.count)
	print("Average Lives Evacuated: %s" % FCWTypes.format_population(int(batch_result.average_lives_evacuated)))
	print("Average Lives Lost: %s" % FCWTypes.format_population(int(batch_result.average_lives_lost)))
	print("Victory Tier Distribution:")
	for tier in batch_result.tier_distribution:
		var pct = 100.0 * batch_result.tier_distribution[tier] / batch_result.count
		print("  Tier %d: %d (%.1f%%)" % [tier, batch_result.tier_distribution[tier], pct])
	print("Best: %s evacuated (seed %d)" % [
		FCWTypes.format_population(batch_result.best_result.lives_evacuated),
		batch_result.best_result.seed
	])
	print("Worst: %s evacuated (seed %d)" % [
		FCWTypes.format_population(batch_result.worst_result.lives_evacuated),
		batch_result.worst_result.seed
	])

static func print_comparison_summary(comparison: Dictionary) -> void:
	## Print strategy comparison results
	print("=== FCW Strategy Comparison ===")
	print("Games per strategy: %d" % comparison.games_per_strategy)
	print("")
	print("Ranking:")
	for i in range(comparison.strategies.size()):
		var strat = comparison.strategies[i]
		print("%d. %s - %s avg evacuated" % [
			i + 1,
			strat.name,
			FCWTypes.format_population(int(strat.average_lives_evacuated))
		])
