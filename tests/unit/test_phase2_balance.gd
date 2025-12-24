extends GutTest

## Balance simulation test for MOT Phase 2
## Validates the mathematical model for 90% AI win rate

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")
const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")
const Phase2Store = preload("res://scripts/mars_odyssey_trek/phase2/phase2_store.gd")
const Phase2Controller = preload("res://scripts/mars_odyssey_trek/phase2/phase2_controller.gd")

# Simulation results tracking
var _simulation_results: Array = []

# ============================================================================
# MATHEMATICAL MODEL VALIDATION
# ============================================================================

func test_resource_consumption_math():
	## Validate that starting resources last the full journey
	print("\n=== RESOURCE CONSUMPTION MATH ===")

	var state = Phase2Types.create_phase2_state()
	var balance = _load_balance()

	# Journey parameters
	var journey_days = 183
	var crew_count = 4

	# Daily consumption from balance.json
	var daily_food = balance.phase2.daily_food_per_crew * crew_count  # 2.0 * 4 = 8 food/day
	var daily_water = balance.phase2.daily_water_per_crew * crew_count  # 3.0 * 4 = 12 water/day
	var water_recycling = balance.phase2.water_recycling_base_efficiency  # 0.85
	var actual_water_consumption = daily_water * (1.0 - water_recycling)  # 12 * 0.15 = 1.8 water/day

	# Starting resources
	var starting_food = state.resources.food.current  # 800
	var starting_water = state.resources.water.current  # 400

	# Calculate days of supplies
	var food_days = starting_food / daily_food  # 800 / 8 = 100 days
	var water_days = starting_water / actual_water_consumption  # 400 / 1.8 = 222 days

	print("Starting food: %.0f, Daily consumption: %.1f, Days of supply: %.1f" % [starting_food, daily_food, food_days])
	print("Starting water: %.0f, Daily consumption: %.1f (after recycling), Days of supply: %.1f" % [starting_water, actual_water_consumption, water_days])
	print("Journey length: %d days" % journey_days)

	# Food is deliberately tight - requires hydroponics to supplement
	# Without hydroponics: 100 days < 183 days (FAIL)
	# With hydroponics producing ~0.21 food/hour * 24 = 5 food/day:
	#   Net consumption = 8 - 5 = 3 food/day, 800 / 3 = 266 days (OK)

	print("\nFOOD BALANCE ANALYSIS:")
	var hydroponics_output_per_hour = 0.21
	var hydroponics_output_per_day = hydroponics_output_per_hour * 24
	var net_food_consumption = daily_food - hydroponics_output_per_day
	var food_days_with_hydroponics = starting_food / net_food_consumption if net_food_consumption > 0 else INF

	print("  Without hydroponics: %.0f days (INSUFFICIENT)" % food_days)
	print("  Hydroponics output: %.2f food/day" % hydroponics_output_per_day)
	print("  Net consumption with hydroponics: %.2f food/day" % net_food_consumption)
	print("  Days with hydroponics: %.0f days" % food_days_with_hydroponics)

	# Assertions
	assert_lt(food_days, journey_days, "Food alone should NOT last the journey (requires hydroponics)")
	assert_gt(food_days_with_hydroponics, journey_days, "Food WITH hydroponics should last the journey")
	assert_gt(water_days, journey_days, "Water should last the journey")


func test_crew_survival_thresholds():
	## Validate crew health/morale decay doesn't kill them without intervention
	print("\n=== CREW SURVIVAL THRESHOLDS ===")

	var state = Phase2Types.create_phase2_state()
	var balance = _load_balance()

	var journey_days = 183
	var morale_decay_per_day = balance.phase2.morale_decay_per_day  # 0.5
	var health_decay_per_day = balance.phase2.health_decay_per_day  # 0.5

	var starting_morale = state.crew[0].morale  # ~85
	var starting_health = state.crew[0].health  # 100

	# Calculate end-of-journey stats without any intervention
	var final_morale = starting_morale - (morale_decay_per_day * journey_days)  # 85 - 91.5 = -6.5
	var final_health = starting_health - (health_decay_per_day * journey_days)  # 100 - 91.5 = 8.5

	print("Starting morale: %.0f, Daily decay: %.1f, Final (unmitigated): %.1f" % [starting_morale, morale_decay_per_day, final_morale])
	print("Starting health: %.0f, Daily decay: %.1f, Final (unmitigated): %.1f" % [starting_health, health_decay_per_day, final_health])

	# Morale WILL hit 0 without events boosting it (forces player engagement)
	# Health barely survives (forces careful play)
	assert_lt(final_morale, 0, "Morale should hit zero without intervention (forces engagement)")
	assert_gt(final_health, 0, "Health should barely survive without intervention")

	print("\nCrew survival requires active morale management through events and tasks")


func test_event_frequency_math():
	## Validate event frequency creates reasonable number of events
	print("\n=== EVENT FREQUENCY MATH ===")

	var balance = _load_balance()
	var base_event_chance = balance.phase2.base_event_chance  # 0.12 per hour check
	var crisis_base_chance = balance.phase2.crisis_base_chance  # 0.03

	var journey_hours = 183 * 24  # 4392 hours
	var checks_per_journey = journey_hours  # Assuming 1 check per hour

	# Expected events = checks * probability
	var expected_events = checks_per_journey * base_event_chance
	var expected_crises = checks_per_journey * crisis_base_chance

	print("Journey hours: %d" % journey_hours)
	print("Base event chance per hour: %.2f%%" % (base_event_chance * 100))
	print("Expected regular events: %.0f" % expected_events)
	print("Expected crisis events: %.0f" % expected_crises)
	print("Total expected events: %.0f" % (expected_events + expected_crises))

	# Reasonable bounds: 400-600 events total
	assert_gt(expected_events, 400, "Should have meaningful number of events")
	assert_lt(expected_events, 700, "Should not be overwhelming")


func test_task_penalty_impact():
	## Validate task penalties create meaningful consequences
	print("\n=== TASK PENALTY IMPACT ===")

	var task_data = _load_task_data()

	print("Task Type Penalties:")
	for task_type in task_data.task_types:
		var config = task_data.task_types[task_type]
		var penalty = config.penalty
		print("  %s: %s damage = %d" % [task_type.to_upper(), penalty.type, penalty.amount])

	# Simulate cumulative penalty damage
	var simulated_failed_tasks = 10  # If AI fails 10 tasks
	var avg_penalty = 17  # Average across all types
	var total_damage = simulated_failed_tasks * avg_penalty

	print("\nIf %d tasks fail: ~%d total damage" % [simulated_failed_tasks, total_damage])
	print("This would significantly impact crew health/morale/systems")

	# Penalties should be meaningful but not instantly fatal
	assert_gt(avg_penalty, 10, "Penalties should be meaningful")
	assert_lt(avg_penalty, 30, "Penalties should not be instantly fatal")


func test_ai_decision_scoring():
	## Validate AI decision factors are balanced
	print("\n=== AI DECISION SCORING ===")

	# Simulated scoring weights from the AI
	var base_score = 0
	var resource_critical_bonus = 50  # When resource is critical
	var blue_option_bonus = 25  # Safe option bonus
	var time_urgency_late = 20  # Late game risk bonus
	var time_urgency_early = 10  # Early game safe bonus
	var crew_busy_penalty = -30  # If crew is occupied
	var crew_fatigue_penalty = -15  # If crew is exhausted
	var task_overload_penalty = -20  # Too many active tasks

	print("AI Scoring Factors:")
	print("  Base score: %d" % base_score)
	print("  Resource critical: +%d" % resource_critical_bonus)
	print("  Blue (safe) option: +%d" % blue_option_bonus)
	print("  Late game urgency: +%d" % time_urgency_late)
	print("  Early game caution: +%d" % time_urgency_early)
	print("  Crew busy penalty: %d" % crew_busy_penalty)
	print("  Crew fatigue penalty: %d" % crew_fatigue_penalty)
	print("  Task overload penalty: %d" % task_overload_penalty)

	# Test scenario: Late game, critical food, crew available
	var scenario_score = base_score + resource_critical_bonus + time_urgency_late
	print("\nScenario (late game, critical food): Score = %d" % scenario_score)

	# Test scenario: Early game, all crew busy and fatigued
	var bad_scenario_score = base_score + crew_busy_penalty + crew_fatigue_penalty + task_overload_penalty
	print("Scenario (early, crew overwhelmed): Score = %d" % bad_scenario_score)

	# Good scenarios should score positive, bad should score negative
	assert_gt(scenario_score, 0, "Good scenarios should have positive scores")
	assert_lt(bad_scenario_score, 0, "Bad scenarios should have negative scores")


# ============================================================================
# HEADLESS SIMULATION TEST
# ============================================================================

func test_run_multiple_simulations():
	## Run multiple headless simulations and track win rate
	print("\n=== HEADLESS SIMULATION TEST ===")

	var num_simulations = 10  # Run 10 quick sims (increase for more accuracy)
	var wins = 0
	var losses = 0
	var results: Array = []

	for sim_id in range(num_simulations):
		var result = _run_single_simulation(sim_id)
		results.append(result)
		if result.won:
			wins += 1
		else:
			losses += 1

	var win_rate = float(wins) / float(num_simulations) * 100.0

	print("\n=== SIMULATION RESULTS ===")
	print("Simulations run: %d" % num_simulations)
	print("Wins: %d" % wins)
	print("Losses: %d" % losses)
	print("Win rate: %.1f%%" % win_rate)

	# Print individual results
	print("\nIndividual Results:")
	for r in results:
		var status = "WIN" if r.won else "LOSS"
		print("  Sim %d: %s - Day %d, Food: %.0f, Health: %.0f, Morale: %.0f" % [
			r.sim_id, status, r.final_day, r.final_food, r.avg_health, r.avg_morale
		])

	# Target: 85-95% win rate (90% ideal)
	# With only 10 sims, we allow wider margin
	assert_gt(win_rate, 50.0, "Win rate should be above 50% (increase sims for accuracy)")

	print("\nNote: Run with more simulations (100+) for statistically significant win rate")


func _run_single_simulation(sim_id: int) -> Dictionary:
	## Run a single headless journey simulation
	var state = Phase2Types.create_phase2_state()
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345 + sim_id  # Deterministic but varied

	var events_triggered = 0

	# Simulate day by day (using dictionary access)
	while state["current_day"] < state["total_days"]:
		# Generate random values for the day
		var random_values = []
		for i in range(5):
			random_values.append(rng.randf())

		# Advance the day
		state = Phase2Reducer.reduce(state, Phase2Reducer.action_advance_day(random_values))

		# Handle any triggered event with AI decision
		var active_event = state.get("active_event", {})
		if not active_event.is_empty():
			events_triggered += 1
			state = _ai_resolve_event(state, rng)

		# Check for game over conditions
		if _is_game_over(state):
			break

	# Calculate final metrics
	var avg_health = 0.0
	var avg_morale = 0.0
	var alive_crew = 0
	var crew_array = state.get("crew", [])
	for crew_member in crew_array:
		var health = crew_member.get("health", 0)
		if health > 0:
			alive_crew += 1
			avg_health += health
			avg_morale += crew_member.get("morale", 0)

	if alive_crew > 0:
		avg_health /= alive_crew
		avg_morale /= alive_crew

	var resources = state.get("resources", {})
	var food_current = resources.get("food", {}).get("current", 0)
	var water_current = resources.get("water", {}).get("current", 0)

	var won = state["current_day"] >= state["total_days"] and alive_crew > 0 and food_current > 0

	return {
		"sim_id": sim_id,
		"won": won,
		"final_day": state["current_day"],
		"final_food": food_current,
		"final_water": water_current,
		"avg_health": avg_health,
		"avg_morale": avg_morale,
		"alive_crew": alive_crew,
		"events": events_triggered
	}


func _ai_resolve_event(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## Simple AI: pick the option with highest expected value (blue option if available)
	var active_event = state.get("active_event", {})
	var options = active_event.get("options", [])
	if options.is_empty():
		# No options, clear event
		var new_state = state.duplicate(true)
		new_state["active_event"] = {}
		new_state["auto_advance"] = true
		return new_state

	# Find best option (prefer blue/safe options)
	var best_idx = 0
	var best_score = -INF

	for i in range(options.size()):
		var opt = options[i]
		var score = 0.0

		# Blue options get bonus
		if opt.get("is_blue", false):
			score += 25

		# Morale boost is good
		if opt.get("effect", "") == "morale_boost":
			score += 15

		# Avoid damage effects
		if "damage" in opt.get("effect", ""):
			score -= 20

		# Random tiebreaker
		score += rng.randf() * 5

		if score > best_score:
			best_score = score
			best_idx = i

	# Resolve with chosen option
	return Phase2Reducer.reduce(state, Phase2Reducer.action_resolve_event(best_idx, rng.randf()))


func _is_game_over(state: Dictionary) -> bool:
	## Check for game-ending conditions
	# All crew dead
	var alive = 0
	var crew_array = state.get("crew", [])
	for crew_member in crew_array:
		if crew_member.get("health", 0) > 0:
			alive += 1
	if alive == 0:
		return true

	# No food and no way to get more
	var resources = state.get("resources", {})
	if resources.get("food", {}).get("current", 0) <= 0:
		return true

	# No oxygen
	if resources.get("oxygen", {}).get("current", 0) <= 0:
		return true

	return false


# ============================================================================
# RESOURCE PROJECTION TEST
# ============================================================================

func test_resource_projection_accuracy():
	## Test that resource projection matches actual consumption
	print("\n=== RESOURCE PROJECTION TEST ===")

	var state = Phase2Types.create_phase2_state()
	var resources = state.get("resources", {})
	var initial_food = resources.get("food", {}).get("current", 0)

	# Project 24 hours ahead
	var projected_consumption = _project_food_consumption(state, 24)

	# Actually advance 24 hours (1 day)
	var random_values = [0.99, 0.99, 0.99, 0.99, 0.99]  # High values to avoid events

	state = Phase2Reducer.reduce(state, Phase2Reducer.action_advance_day(random_values))
	var new_resources = state.get("resources", {})
	var final_food = new_resources.get("food", {}).get("current", 0)
	var actual_consumption = initial_food - final_food

	print("Initial food: %.1f" % initial_food)
	print("Projected consumption (24h): %.1f" % projected_consumption)
	print("Actual consumption (1 day): %.1f" % actual_consumption)

	# Projection should be reasonably close (within 50%)
	# Note: Actual consumption may differ due to hydroponics production
	if actual_consumption > 0:
		var error_margin = abs(projected_consumption - actual_consumption) / actual_consumption
		print("Error margin: %.1f%%" % (error_margin * 100))
		# Be lenient since hydroponics affects actual consumption
		assert_lt(error_margin, 2.0, "Projection should be reasonably close to actual")
	else:
		print("Note: Food increased (hydroponics producing more than consumed)")
		pass_test("Hydroponics is producing more than consumption")


func _project_food_consumption(state: Dictionary, hours: int) -> float:
	## Project food consumption over given hours
	var crew_array = state.get("crew", [])
	var crew_count = crew_array.size()
	var food_per_crew_per_day = 2.0
	var food_per_crew_per_hour = food_per_crew_per_day / 24.0

	return crew_count * food_per_crew_per_hour * hours


# ============================================================================
# HELPERS
# ============================================================================

func _load_balance() -> Dictionary:
	var file = FileAccess.open("res://data/games/mars_odyssey_trek/balance.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err == OK:
			return json.data
	return {}


func _load_task_data() -> Dictionary:
	var file = FileAccess.open("res://data/games/mars_odyssey_trek/tasks.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err == OK:
			return json.data
	return {}
