extends GutTest

## Unit tests for Phase2Reducer
## Tests state transformation logic for MOT Phase 2 (Travel to Mars)

const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")
const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

var initial_state: Dictionary


func before_each():
	initial_state = Phase2Types.create_phase2_state()


func after_each():
	initial_state = {}


# ============================================================================
# INITIAL STATE TESTS
# ============================================================================

func test_initial_state_has_correct_day():
	assert_eq(initial_state.current_day, 1, "Should start on day 1")
	assert_eq(initial_state.total_days, 183, "Should have 183 total days")


func test_initial_state_has_four_containers():
	assert_eq(initial_state.storage_containers.size(), 4, "Should have 4 storage containers")


func test_initial_state_has_four_crew():
	assert_eq(initial_state.crew.size(), 4, "Should have 4 crew members")


func test_initial_state_containers_accessible():
	for container in initial_state.storage_containers:
		assert_true(container.accessible, "Container %s should be accessible" % container.id)


func test_initial_state_no_active_event():
	assert_true(initial_state.active_event.is_empty(), "Should have no active event")


func test_initial_state_repair_not_in_progress():
	assert_false(initial_state.repair.in_progress, "Repair should not be in progress")


func test_initial_state_mars_not_visible():
	assert_false(initial_state.mars_visible, "Mars should not be visible initially")


func test_initial_state_resources_computed():
	# Total food should be 250 + 300 + 200 + 50 = 800
	assert_eq(initial_state.resources.food.current, 800.0, "Food total should be 800")
	# Total water should be 100 + 150 + 100 + 50 = 400
	assert_eq(initial_state.resources.water.current, 400.0, "Water total should be 400")


# ============================================================================
# ADVANCE_DAY TESTS
# ============================================================================

func test_advance_day_increments_counter():
	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	assert_eq(new_state.current_day, 2, "Day should increment to 2")


func test_advance_day_consumes_food():
	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var initial_food = initial_state.resources.food.current

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	# 4 crew * 1 food per day = 4 food consumed
	assert_lt(new_state.resources.food.current, initial_food, "Food should decrease")


func test_advance_day_consumes_water():
	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var initial_water = initial_state.resources.water.current

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	# 4 crew * 0.5 water per day = 2 water consumed
	assert_lt(new_state.resources.water.current, initial_water, "Water should decrease")


func test_advance_day_consumes_oxygen():
	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var initial_oxygen = initial_state.resources.oxygen.current

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	assert_lt(new_state.resources.oxygen.current, initial_oxygen, "Oxygen should decrease slightly")


func test_advance_day_decays_morale():
	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var initial_morale = initial_state.crew[0].morale

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	assert_lt(new_state.crew[0].morale, initial_morale, "Morale should decay")


func test_advance_day_accumulates_fatigue():
	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var initial_fatigue = initial_state.crew[0].fatigue

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	assert_gt(new_state.crew[0].fatigue, initial_fatigue, "Fatigue should increase")


func test_advance_day_triggers_mars_visible_at_day_140():
	var state = initial_state.duplicate(true)
	state.current_day = 139  # Will become 140 after advance

	var random_values = [0.9, 0.9, 0.9, 0.9, 0.9]  # High rolls to avoid events
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_advance_day(random_values))

	assert_true(new_state.mars_visible, "Mars should become visible at day 140")


# ============================================================================
# RESOURCE CONSUMPTION TESTS
# ============================================================================

func test_consume_from_first_accessible_container():
	var random_values = [0.9, 0.9, 0.9, 0.9, 0.9]  # High rolls to avoid events
	var initial_container_food = initial_state.storage_containers[0].food

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	assert_lt(new_state.storage_containers[0].food, initial_container_food, "First container should have less food")


func test_blocked_container_not_consumed():
	var state = initial_state.duplicate(true)
	# Block the first container
	state.storage_containers[0].accessible = false
	var blocked_food = state.storage_containers[0].food
	var second_container_food = state.storage_containers[1].food

	var random_values = [0.9, 0.9, 0.9, 0.9, 0.9]
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_advance_day(random_values))

	assert_eq(new_state.storage_containers[0].food, blocked_food, "Blocked container food unchanged")
	assert_lt(new_state.storage_containers[1].food, second_container_food, "Second container should be used")


func test_resources_recomputed_after_consumption():
	var random_values = [0.9, 0.9, 0.9, 0.9, 0.9]

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	# Recompute manually
	var expected_food = 0.0
	for container in new_state.storage_containers:
		if container.accessible:
			expected_food += container.food

	assert_eq(new_state.resources.food.current, expected_food, "Resource totals should match containers")


# ============================================================================
# SPEED CONTROL TESTS
# ============================================================================

func test_set_speed_changes_speed():
	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_set_speed(Phase2Types.Speed.FAST))

	assert_eq(new_state.speed, Phase2Types.Speed.FAST, "Speed should be FAST")


func test_set_speed_enables_auto_advance():
	var state = initial_state.duplicate(true)
	state.auto_advance = false

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_set_speed(Phase2Types.Speed.NORMAL))

	assert_true(new_state.auto_advance, "Auto advance should be enabled")


func test_paused_speed_keeps_auto_advance():
	var state = initial_state.duplicate(true)
	state.auto_advance = false

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_set_speed(Phase2Types.Speed.PAUSED))

	assert_false(new_state.auto_advance, "Paused should not enable auto advance")


func test_set_auto_advance():
	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_set_auto_advance(false))

	assert_false(new_state.auto_advance, "Auto advance should be disabled")


# ============================================================================
# EVENT TESTS
# ============================================================================

func test_trigger_event_sets_active_event():
	var event = Phase2Types.create_event({
		"title": "TEST EVENT",
		"description": "A test event"
	})

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_trigger_event(event))

	assert_eq(new_state.active_event.title, "TEST EVENT", "Event should be active")


func test_trigger_event_pauses_auto_advance():
	var event = Phase2Types.create_event({"title": "TEST"})

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_trigger_event(event))

	assert_false(new_state.auto_advance, "Auto advance should be paused during event")


func test_resolve_event_clears_active_event():
	var state = initial_state.duplicate(true)
	state.active_event = Phase2Types.create_event({
		"title": "TEST",
		"options": [
			Phase2Types.create_event_option({"label": "Choice 1", "effect": "morale_boost"})
		]
	})

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_resolve_event(0, 0.5))

	assert_true(new_state.active_event.is_empty(), "Active event should be cleared")


func test_resolve_event_resumes_auto_advance():
	var state = initial_state.duplicate(true)
	state.auto_advance = false
	state.active_event = Phase2Types.create_event({
		"title": "TEST",
		"options": [
			Phase2Types.create_event_option({"label": "Choice 1", "effect": "morale_boost"})
		]
	})

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_resolve_event(0, 0.5))

	assert_true(new_state.auto_advance, "Auto advance should resume after event")


func test_morale_boost_effect():
	var state = initial_state.duplicate(true)
	var initial_morale = state.crew[0].morale
	state.active_event = Phase2Types.create_event({
		"title": "TEST",
		"options": [
			Phase2Types.create_event_option({"label": "Boost", "effect": "morale_boost", "effect_value": 15})
		]
	})

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_resolve_event(0, 0.5))

	assert_gt(new_state.crew[0].morale, initial_morale, "Morale should increase")


func test_power_drain_effect():
	var state = initial_state.duplicate(true)
	var initial_power = state.resources.power.current
	state.active_event = Phase2Types.create_event({
		"title": "TEST",
		"options": [
			Phase2Types.create_event_option({"label": "Drain", "effect": "power_drain", "effect_value": 10})
		]
	})

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_resolve_event(0, 0.5))

	assert_lt(new_state.resources.power.current, initial_power, "Power should decrease")


# ============================================================================
# SECTION BLOCKAGE TESTS
# ============================================================================

func test_block_section_makes_container_inaccessible():
	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_block_section(
		"cargo_a",
		Phase2Types.ContainerStatus.BLOCKED,
		0.5
	))

	var container = null
	for c in new_state.storage_containers:
		if c.id == "cargo_a":
			container = c
			break

	assert_not_null(container, "Container should exist")
	assert_false(container.accessible, "Container should be inaccessible")
	assert_eq(container.status, Phase2Types.ContainerStatus.BLOCKED, "Status should be BLOCKED")


func test_blocked_container_reduces_accessible_resources():
	var initial_accessible_food = Phase2Reducer.get_accessible_food(initial_state)

	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_block_section(
		"cargo_a",
		Phase2Types.ContainerStatus.BLOCKED,
		0.5
	))

	var new_accessible_food = Phase2Reducer.get_accessible_food(new_state)
	assert_lt(new_accessible_food, initial_accessible_food, "Accessible food should decrease")


# ============================================================================
# REPAIR TESTS
# ============================================================================

func test_start_repair_sets_repair_state():
	var new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_start_repair("cargo_a", 3))

	assert_true(new_state.repair.in_progress, "Repair should be in progress")
	assert_eq(new_state.repair.days_remaining, 3, "Should have 3 days remaining")
	assert_eq(new_state.repair.target_container_id, "cargo_a", "Should target cargo_a")


func test_start_repair_fatigues_engineer():
	var state = initial_state.duplicate(true)
	var engineer_idx = -1
	for i in range(state.crew.size()):
		if state.crew[i].role == Phase2Types.CrewRole.ENGINEER:
			engineer_idx = i
			break

	var initial_fatigue = state.crew[engineer_idx].fatigue

	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_start_repair("cargo_a", 3))

	assert_gt(new_state.crew[engineer_idx].fatigue, initial_fatigue, "Engineer should be fatigued")


func test_repair_progress_decrements_days():
	var state = initial_state.duplicate(true)
	state.repair = {
		"in_progress": true,
		"days_remaining": 3,
		"target_container_id": "cargo_a"
	}

	var random_values = [0.9, 0.9, 0.9, 0.9, 0.9]
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_advance_day(random_values))

	assert_eq(new_state.repair.days_remaining, 2, "Days remaining should decrement")


func test_repair_completion_restores_container():
	var state = initial_state.duplicate(true)
	# Block a container
	state.storage_containers[0].accessible = false
	state.storage_containers[0].status = Phase2Types.ContainerStatus.BLOCKED
	# Set repair to complete on next day
	state.repair = {
		"in_progress": true,
		"days_remaining": 1,
		"target_container_id": "cargo_a"
	}

	var random_values = [0.9, 0.9, 0.9, 0.9, 0.9]
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_advance_day(random_values))

	assert_false(new_state.repair.in_progress, "Repair should be complete")
	assert_true(new_state.storage_containers[0].accessible, "Container should be accessible again")
	assert_eq(new_state.storage_containers[0].status, Phase2Types.ContainerStatus.NOMINAL, "Status should be NOMINAL")


# ============================================================================
# EVA RETRIEVAL TESTS
# ============================================================================

func test_eva_success_retrieves_supplies():
	var state = initial_state.duplicate(true)
	# Block a container with supplies
	state.storage_containers[0].accessible = false
	var trapped_food = state.storage_containers[0].food
	var emergency_food = state.storage_containers[3].food  # Emergency container

	# High random value = success
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_eva_retrieval("cargo_a", 0.1))

	assert_gt(new_state.storage_containers[3].food, emergency_food, "Emergency container should have more food")
	assert_eq(new_state.storage_containers[0].food, 0, "Original container should be empty")


func test_eva_failure_injures_crew():
	var state = initial_state.duplicate(true)
	state.storage_containers[0].accessible = false

	# Low random value (above success chance) = failure
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_eva_retrieval("cargo_a", 0.9))

	var injured = false
	for i in range(new_state.crew.size()):
		if new_state.crew[i].health < initial_state.crew[i].health:
			injured = true
			break

	assert_true(injured, "Someone should be injured")


func test_eva_failure_partial_retrieval():
	var state = initial_state.duplicate(true)
	state.storage_containers[0].accessible = false
	var trapped_food = state.storage_containers[0].food
	var emergency_food = state.storage_containers[3].food

	# Failure case
	var new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_eva_retrieval("cargo_a", 0.9))

	# Should still have some supplies retrieved (partial)
	assert_gt(new_state.storage_containers[3].food, emergency_food, "Should have partial retrieval")
	assert_lt(new_state.storage_containers[3].food, emergency_food + trapped_food, "Should not have full retrieval")


# ============================================================================
# QUERY FUNCTION TESTS
# ============================================================================

func test_get_accessible_food():
	var food = Phase2Reducer.get_accessible_food(initial_state)
	assert_eq(food, 800.0, "All food should be accessible initially")


func test_get_trapped_food_when_blocked():
	var state = initial_state.duplicate(true)
	state.storage_containers[0].accessible = false

	var trapped = Phase2Reducer.get_trapped_food(state)
	assert_eq(trapped, 250.0, "Should have 250 trapped food")


func test_get_average_morale():
	var morale = Phase2Reducer.get_average_morale(initial_state)
	# (85 + 80 + 90 + 75) / 4 = 82.5
	assert_almost_eq(morale, 82.5, 0.1, "Average morale should be 82.5")


func test_get_journey_progress():
	var state = initial_state.duplicate(true)
	state.current_day = 92  # About halfway

	var progress = Phase2Reducer.get_journey_progress(state)
	assert_almost_eq(progress, 0.503, 0.01, "Progress should be about 50%")


func test_has_arrived():
	var state = initial_state.duplicate(true)
	state.current_day = 183

	assert_true(Phase2Reducer.has_arrived(state), "Should have arrived at day 183")


func test_is_repair_in_progress():
	var state = initial_state.duplicate(true)
	state.repair.in_progress = true

	assert_true(Phase2Reducer.is_repair_in_progress(state), "Should detect repair in progress")


# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_reduce_does_not_mutate_original():
	var original_day = initial_state.current_day
	var original_food = initial_state.storage_containers[0].food

	var random_values = [0.5, 0.5, 0.5, 0.5, 0.5]
	var _new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_advance_day(random_values))

	assert_eq(initial_state.current_day, original_day, "Original day should be unchanged")
	assert_eq(initial_state.storage_containers[0].food, original_food, "Original container food should be unchanged")


func test_container_mutation_does_not_affect_original():
	var original_accessible = initial_state.storage_containers[0].accessible

	var _new_state = Phase2Reducer.reduce(initial_state, Phase2Reducer.action_block_section(
		"cargo_a",
		Phase2Types.ContainerStatus.BLOCKED,
		0.5
	))

	assert_eq(initial_state.storage_containers[0].accessible, original_accessible, "Original container should be unchanged")


func test_crew_mutation_does_not_affect_original():
	var original_morale = initial_state.crew[0].morale

	var state = initial_state.duplicate(true)
	state.active_event = Phase2Types.create_event({
		"title": "TEST",
		"options": [
			Phase2Types.create_event_option({"label": "Boost", "effect": "morale_boost", "effect_value": 20})
		]
	})

	var _new_state = Phase2Reducer.reduce(state, Phase2Reducer.action_resolve_event(0, 0.5))

	assert_eq(initial_state.crew[0].morale, original_morale, "Original crew morale should be unchanged")
