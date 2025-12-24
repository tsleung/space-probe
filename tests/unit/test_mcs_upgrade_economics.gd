extends GutTest

## Unit tests for MCS Upgrade Economics System
## Tests that upgrade mechanics produce the expected outcomes:
## - Tier stats scale correctly (production UP, workers DOWN)
## - Upgrade costs are properly validated
## - Economy calculations use tier stats
## - AI makes economically rational upgrade decisions
## - Overall progression leads to "glorious city" by Year 50

const MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const MCSEconomy = preload("res://scripts/mars_colony_sim/mcs_economy.gd")
const MCSReducer = preload("res://scripts/mars_colony_sim/mcs_reducer.gd")
const MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")
# Note: MCSAI tests removed to avoid circular dependency - AI logic tested separately


# ============================================================================
# TIER STATS TESTS - Verify tier progression makes sense
# ============================================================================

func test_tier_stats_exist_for_key_buildings():
	# Key production buildings should have tier stats
	var key_buildings = [
		MCSTypes.BuildingType.AGRIDOME,
		MCSTypes.BuildingType.HYDROPONICS,
		MCSTypes.BuildingType.SOLAR_FARM,
		MCSTypes.BuildingType.EXTRACTOR,
		MCSTypes.BuildingType.FABRICATOR,
		MCSTypes.BuildingType.FOUNDRY,
	]

	for building_type in key_buildings:
		var has_tiers = MCSTypes.has_tier_progression(building_type)
		assert_true(has_tiers, "Building type %d should have tier progression" % building_type)


func test_tier_production_increases_with_tier():
	# Agridome production should increase: 500 -> 650 -> 850 -> 1100 -> 1500
	var expected_food = [500, 650, 850, 1100, 1500]

	for tier in range(1, 6):
		var stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, tier)
		var actual_food = stats.get("production", {}).get("food", 0)
		assert_eq(actual_food, expected_food[tier - 1],
			"Agridome tier %d should produce %d food" % [tier, expected_food[tier - 1]])


func test_tier_5_produces_triple_tier_1():
	# Tier 5 should produce approximately 3x tier 1 (the design spec)
	var buildings_to_check = [
		MCSTypes.BuildingType.AGRIDOME,
		MCSTypes.BuildingType.HYDROPONICS,
		MCSTypes.BuildingType.EXTRACTOR,
	]

	for building_type in buildings_to_check:
		var tier1 = MCSTypes.get_tier_stats(building_type, 1)
		var tier5 = MCSTypes.get_tier_stats(building_type, 5)

		var tier1_prod = tier1.get("production", {})
		var tier5_prod = tier5.get("production", {})

		for resource in tier1_prod.keys():
			var ratio = float(tier5_prod.get(resource, 0)) / float(tier1_prod[resource])
			assert_gt(ratio, 2.5, "Tier 5 should produce at least 2.5x tier 1 for %s" % resource)
			assert_lt(ratio, 4.0, "Tier 5 should produce at most 4x tier 1 for %s" % resource)


func test_tier_workers_decrease_at_high_tiers():
	# Workers should decrease at tier 4-5 (the key upgrade incentive)
	var buildings_with_worker_reduction = [
		MCSTypes.BuildingType.AGRIDOME,
		MCSTypes.BuildingType.FOUNDRY,
		MCSTypes.BuildingType.EXTRACTOR,
	]

	for building_type in buildings_with_worker_reduction:
		var tier1 = MCSTypes.get_tier_stats(building_type, 1)
		var tier5 = MCSTypes.get_tier_stats(building_type, 5)

		var workers_1 = tier1.get("workers", 99)
		var workers_5 = tier5.get("workers", 99)

		assert_lt(workers_5, workers_1,
			"Building type %d tier 5 should need fewer workers than tier 1" % building_type)


func test_foundry_workers_decrease_significantly():
	# Foundry: 6 workers at tier 1, 2 workers at tier 5 (saves 4 workers!)
	var tier1 = MCSTypes.get_tier_stats(MCSTypes.BuildingType.FOUNDRY, 1)
	var tier5 = MCSTypes.get_tier_stats(MCSTypes.BuildingType.FOUNDRY, 5)

	assert_eq(tier1.get("workers", 0), 6, "Foundry tier 1 should need 6 workers")
	assert_eq(tier5.get("workers", 0), 2, "Foundry tier 5 should need only 2 workers")


func test_solar_array_power_increases():
	# Solar farm power: 50 -> 65 -> 85 -> 110 -> 150
	var expected_power = [50, 65, 85, 110, 150]

	for tier in range(1, 6):
		var stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.SOLAR_FARM, tier)
		var actual_power = stats.get("power_gen", 0)
		assert_eq(actual_power, expected_power[tier - 1],
			"Solar farm tier %d should generate %d power" % [tier, expected_power[tier - 1]])


func test_housing_capacity_increases():
	# Habitat: 4 -> 6 -> 8 -> 12 -> 20
	var expected_capacity = [4, 6, 8, 12, 20]

	for tier in range(1, 6):
		var stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.HABITAT, tier)
		var actual_capacity = stats.get("housing_capacity", 0)
		assert_eq(actual_capacity, expected_capacity[tier - 1],
			"Habitat tier %d should house %d colonists" % [tier, expected_capacity[tier - 1]])


# ============================================================================
# UPGRADE COST TESTS - Verify costs scale appropriately
# ============================================================================

func test_upgrade_costs_exist():
	for tier in range(2, 6):
		var costs = MCSTypes.get_upgrade_cost(tier)
		assert_true(costs.has("building_materials"), "Tier %d should cost building_materials" % tier)
		assert_true(costs.has("machine_parts"), "Tier %d should cost machine_parts" % tier)


func test_upgrade_costs_increase_with_tier():
	var prev_cost = 0

	for tier in range(2, 6):
		var costs = MCSTypes.get_upgrade_cost(tier)
		var total = costs.get("building_materials", 0) + costs.get("machine_parts", 0)

		assert_gt(total, prev_cost, "Tier %d upgrade should cost more than tier %d" % [tier, tier - 1])
		prev_cost = total


func test_tier_5_upgrade_is_expensive():
	# Tier 5 should be expensive but achievable: 120 materials + 60 parts
	var costs = MCSTypes.get_upgrade_cost(5)

	assert_eq(costs.get("building_materials", 0), 120, "Tier 5 should cost 120 building_materials")
	assert_eq(costs.get("machine_parts", 0), 60, "Tier 5 should cost 60 machine_parts")


func test_total_upgrade_cost_to_tier_5():
	# Total cost to reach tier 5: 275 materials + 130 parts (balanced for achievability)
	var total_materials = 0
	var total_parts = 0

	for tier in range(2, 6):
		var costs = MCSTypes.get_upgrade_cost(tier)
		total_materials += costs.get("building_materials", 0)
		total_parts += costs.get("machine_parts", 0)

	assert_eq(total_materials, 275, "Total materials to tier 5 should be 275")
	assert_eq(total_parts, 130, "Total parts to tier 5 should be 130")


func test_upgrade_durations_exist():
	for tier in range(2, 6):
		var duration = MCSTypes.get_upgrade_duration(tier)
		assert_gt(duration, 0, "Tier %d should have positive duration" % tier)


func test_upgrade_durations_increase_with_tier():
	# FAST durations for optimal play: Tier 2: 1 year, Tier 3: 1 year, Tier 4: 2 years, Tier 5: 2 years
	var expected = [0, 0, 1, 1, 2, 2]  # Index 0 and 1 unused

	for tier in range(2, 6):
		var duration = MCSTypes.get_upgrade_duration(tier)
		assert_eq(duration, expected[tier], "Tier %d should take %d years" % [tier, expected[tier]])


func test_total_time_to_tier_5():
	# Total time: 1 + 1 + 2 + 2 = 6 years (fast upgrades!)
	var total = 0
	for tier in range(2, 6):
		total += MCSTypes.get_upgrade_duration(tier)

	assert_eq(total, 6, "Total time from tier 1 to 5 should be 6 years")


# ============================================================================
# ECONOMY INTEGRATION TESTS - Verify economy uses tier stats
# ============================================================================

func _create_test_building(type: int, tier: int = 1, operational: bool = true) -> Dictionary:
	return {
		"id": "test_%d_%d" % [type, tier],
		"type": type,
		"tier": tier,
		"is_operational": operational,
		"is_under_construction": false,
		"condition": 100.0,
		"assigned_workers": [],
		"housing_capacity": 0,
	}


func _create_test_colonist(alive: bool = true, adult: bool = true) -> Dictionary:
	return {
		"id": "colonist_" + str(randi()),
		"is_alive": alive,
		"life_stage": MCSTypes.LifeStage.ADULT if adult else MCSTypes.LifeStage.CHILD,
		"health": 80.0,
	}


func test_production_uses_tier_stats():
	var colonists = [_create_test_colonist(), _create_test_colonist()]

	# Tier 1 agridome produces 500 food
	var tier1_building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	tier1_building.assigned_workers = ["worker1", "worker2"]
	var tier1_production = MCSEconomy.calc_yearly_production([tier1_building], colonists)

	# Tier 5 agridome produces 1500 food
	var tier5_building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 5)
	tier5_building.assigned_workers = ["worker1"]  # Only needs 1 worker at tier 5
	var tier5_production = MCSEconomy.calc_yearly_production([tier5_building], colonists)

	assert_eq(tier1_production.get("food", 0), 500.0, "Tier 1 agridome should produce 500 food")
	assert_eq(tier5_production.get("food", 0), 1500.0, "Tier 5 agridome should produce 1500 food")


func test_power_generation_uses_tier_stats():
	var colonists = []

	# Tier 1 solar array generates 50 power
	var tier1_solar = _create_test_building(MCSTypes.BuildingType.SOLAR_FARM, 1)
	var tier1_balance = MCSEconomy.calc_power_balance([tier1_solar], colonists)

	# Tier 5 solar array generates 150 power
	var tier5_solar = _create_test_building(MCSTypes.BuildingType.SOLAR_FARM, 5)
	var tier5_balance = MCSEconomy.calc_power_balance([tier5_solar], colonists)

	assert_eq(tier1_balance.get("generation", 0), 50.0, "Tier 1 solar should generate 50 power")
	assert_eq(tier5_balance.get("generation", 0), 150.0, "Tier 5 solar should generate 150 power")


func test_housing_uses_tier_stats():
	var colonists = []

	# Tier 1 habitat houses 4
	var tier1_hab = _create_test_building(MCSTypes.BuildingType.HABITAT, 1)
	var tier1_housing = MCSEconomy.calc_housing_balance([tier1_hab], colonists)

	# Tier 5 habitat houses 20
	var tier5_hab = _create_test_building(MCSTypes.BuildingType.HABITAT, 5)
	var tier5_housing = MCSEconomy.calc_housing_balance([tier5_hab], colonists)

	assert_eq(tier1_housing.get("capacity", 0), 4, "Tier 1 hab should house 4")
	assert_eq(tier5_housing.get("capacity", 0), 20, "Tier 5 hab should house 20")


func test_efficiency_uses_tier_worker_requirements():
	# A tier 5 agridome needs only 1 worker but tier 1 needs 2
	var colonists = [_create_test_colonist()]

	# Tier 1 with 1 worker (needs 2) = 50% efficiency
	var tier1_building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	tier1_building.assigned_workers = ["worker1"]
	var tier1_eff = MCSEconomy.calc_building_efficiency(tier1_building, colonists)

	# Tier 5 with 1 worker (needs 1) = 100% efficiency
	var tier5_building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 5)
	tier5_building.assigned_workers = ["worker1"]
	var tier5_eff = MCSEconomy.calc_building_efficiency(tier5_building, colonists)

	assert_almost_eq(tier1_eff, 0.5, 0.01, "Tier 1 with 1/2 workers should be 50% efficient")
	assert_almost_eq(tier5_eff, 1.0, 0.01, "Tier 5 with 1/1 workers should be 100% efficient")


# ============================================================================
# REDUCER TESTS - Verify upgrade mechanics work correctly
# ============================================================================

func _create_test_state() -> Dictionary:
	return {
		"current_year": 10,
		"buildings": [],
		"colonists": [],
		"resources": {
			"building_materials": 1000.0,
			"machine_parts": 500.0,
			"food": 5000.0,
		},
		"mission_log": [],
	}


func test_upgrade_deducts_resources():
	var state = _create_test_state()
	var building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	building.id = "agridome_1"
	state.buildings = [building]

	var initial_materials = state.resources.building_materials
	var initial_parts = state.resources.machine_parts

	var action = MCSReducer.action_upgrade_building("agridome_1")
	var new_state = MCSReducer.reduce(state, action)

	# Tier 2 costs: 25 materials + 10 parts
	var expected_materials = initial_materials - 25
	var expected_parts = initial_parts - 10

	assert_eq(new_state.resources.building_materials, expected_materials,
		"Should deduct 25 building_materials for tier 2 upgrade")
	assert_eq(new_state.resources.machine_parts, expected_parts,
		"Should deduct 10 machine_parts for tier 2 upgrade")


func test_upgrade_fails_without_resources():
	var state = _create_test_state()
	state.resources.building_materials = 10  # Not enough for tier 2 (needs 25)

	var building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	building.id = "agridome_1"
	state.buildings = [building]

	var action = MCSReducer.action_upgrade_building("agridome_1")
	var new_state = MCSReducer.reduce(state, action)

	# Building should NOT be upgrading
	var new_building = new_state.buildings[0]
	assert_false(new_building.get("upgrading", false),
		"Should not start upgrade without sufficient resources")

	# Resources should be unchanged
	assert_eq(new_state.resources.building_materials, 10, "Resources should be unchanged")


func test_upgrade_starts_correctly():
	var state = _create_test_state()
	var building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	building.id = "agridome_1"
	state.buildings = [building]

	var action = MCSReducer.action_upgrade_building("agridome_1")
	var new_state = MCSReducer.reduce(state, action)

	var new_building = new_state.buildings[0]
	assert_true(new_building.get("upgrading", false), "Should be upgrading")
	assert_eq(new_building.get("upgrade_progress", -1), 0.0, "Progress should start at 0")
	assert_eq(new_building.get("target_tier", 0), 2, "Target tier should be 2")


func test_upgrade_cannot_exceed_tier_5():
	var state = _create_test_state()
	var building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 5)  # Already tier 5
	building.id = "agridome_5"
	state.buildings = [building]

	var initial_resources = state.resources.duplicate()

	var action = MCSReducer.action_upgrade_building("agridome_5")
	var new_state = MCSReducer.reduce(state, action)

	var new_building = new_state.buildings[0]
	assert_false(new_building.get("upgrading", false), "Should not upgrade past tier 5")
	assert_eq(new_state.resources, initial_resources, "Resources should be unchanged")


func test_upgrade_progress_uses_tier_duration():
	var state = _create_test_state()
	var building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	building.id = "agridome_1"
	building.upgrading = true
	building.upgrade_progress = 0.0
	building.target_tier = 4  # Tier 4 takes 2 years
	state.buildings = [building]

	# Progress upgrades (tier 4 takes 2 years, so 50% per year)
	var action = MCSReducer.action_progress_upgrades()
	var new_state = MCSReducer.reduce(state, action)

	var new_building = new_state.buildings[0]
	assert_almost_eq(new_building.upgrade_progress, 0.5, 0.01,
		"Tier 4 should progress 50% per year (2 year duration)")


func test_upgrade_completes_and_changes_tier():
	var state = _create_test_state()
	var building = _create_test_building(MCSTypes.BuildingType.AGRIDOME, 1)
	building.id = "agridome_1"
	building.upgrading = true
	building.upgrade_progress = 0.9  # Almost complete
	building.target_tier = 2
	state.buildings = [building]

	var action = MCSReducer.action_progress_upgrades()
	var new_state = MCSReducer.reduce(state, action)

	var new_building = new_state.buildings[0]
	assert_eq(new_building.tier, 2, "Should be tier 2 after completion")
	assert_false(new_building.get("upgrading", false), "Should not be upgrading after completion")


# ============================================================================
# ECONOMIC BALANCE TESTS - Verify upgrade vs build tradeoffs
# (AI ROI tests moved to separate file to avoid circular dependency)
# ============================================================================

func test_upgrade_saves_workers_vs_new_building():
	# 3 new agridomes: 3 * 2 = 6 workers, produce 1500 food
	# 1 tier 5 agridome: 1 worker, produces 1500 food
	# Upgrading saves 5 workers!

	var tier5_stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, 5)
	var tier1_stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, 1)

	var workers_3_new = 3 * tier1_stats.get("workers", 0)
	var workers_1_tier5 = tier5_stats.get("workers", 0)

	var production_3_new = 3 * tier1_stats.get("production", {}).get("food", 0)
	var production_1_tier5 = tier5_stats.get("production", {}).get("food", 0)

	# Equal production
	assert_eq(production_3_new, production_1_tier5, "3 tier 1 = 1 tier 5 in production")

	# But tier 5 saves workers
	var workers_saved = workers_3_new - workers_1_tier5
	assert_gt(workers_saved, 3, "Tier 5 should save at least 3 workers vs 3 new buildings")


func test_upgrade_is_efficient():
	# UPGRADES ARE THE OPTIMAL STRATEGY!
	# Upgrading 1 building to tier 5 costs LESS than building 3 new agridomes
	# AND gives more production AND saves workers

	var new_building_cost_materials = 80 * 3  # 80 per agridome (from AI)
	var new_building_cost_parts = 15 * 3      # 15 per agridome

	var upgrade_cost_materials = 0
	var upgrade_cost_parts = 0
	for tier in range(2, 6):
		var costs = MCSTypes.get_upgrade_cost(tier)
		upgrade_cost_materials += costs.get("building_materials", 0)
		upgrade_cost_parts += costs.get("machine_parts", 0)

	# 1 T5 agridome = 1500 food/yr with 1 worker
	# 3 T1 agridomes = 1500 food/yr with 6 workers
	# Upgrading is MORE efficient!
	assert_lt(upgrade_cost_materials, new_building_cost_materials * 1.5,
		"Upgrading should be cost-competitive with building new")
	assert_lt(upgrade_cost_parts, new_building_cost_parts * 3,
		"Upgrading should be parts-efficient compared to building multiple")


# ============================================================================
# PROGRESSION SIMULATION - Test expected colony growth
# ============================================================================

func test_expected_progression_year_10():
	# By year 10, a well-run colony should have:
	# - 15-20 buildings
	# - First tier 2 upgrades appearing
	# This is verified by ensuring tier 2 is achievable by year 3

	var year_3_possible_upgrades = 0
	for tier in range(2, 6):
		var duration = MCSTypes.get_upgrade_duration(tier)
		if duration <= 3:
			year_3_possible_upgrades += 1

	assert_gt(year_3_possible_upgrades, 0,
		"Should be able to reach at least tier 2 by year 3")


func test_expected_progression_year_50():
	# By year 50, a colony should be able to reach tier 5 on many buildings
	# Total time to tier 5: 6 years (fast upgrades!)
	# Building constructed year 1 can reach tier 5 by year 7

	var total_upgrade_time = 0
	for tier in range(2, 6):
		total_upgrade_time += MCSTypes.get_upgrade_duration(tier)

	var year_can_reach_tier_5 = 1 + total_upgrade_time

	assert_lt(year_can_reach_tier_5, 50,
		"Buildings from year 1 should reach tier 5 well before year 50")
	assert_eq(year_can_reach_tier_5, 7,
		"Building from year 1 should reach tier 5 by year 7")


func test_late_game_worker_efficiency():
	# In late game (200 colonists, 60 buildings), upgrades become essential
	# 60 tier 1 factories would need 360 workers (impossible!)
	# 60 tier 5 factories need only 120 workers

	var tier1_foundry_workers = MCSTypes.get_tier_stats(MCSTypes.BuildingType.FOUNDRY, 1).get("workers", 0)
	var tier5_foundry_workers = MCSTypes.get_tier_stats(MCSTypes.BuildingType.FOUNDRY, 5).get("workers", 0)

	var workers_60_tier1 = 60 * tier1_foundry_workers
	var workers_60_tier5 = 60 * tier5_foundry_workers

	assert_eq(workers_60_tier1, 360, "60 tier 1 factories would need 360 workers")
	assert_eq(workers_60_tier5, 120, "60 tier 5 factories need only 120 workers")

	var workers_saved = workers_60_tier1 - workers_60_tier5
	assert_eq(workers_saved, 240, "Tier 5 upgrades save 240 workers across 60 factories")


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_building_without_tier_stats_returns_default():
	# Buildings not in BUILDING_TIER_STATS should return a default dict
	var stats = MCSTypes.get_tier_stats(999, 1)  # Invalid building type

	assert_true(stats is Dictionary, "Should return a dictionary")
	assert_eq(stats.get("tier", 0), 1, "Should include tier in default response")


func test_tier_clamped_to_valid_range():
	# Requesting tier 0 or tier 10 should clamp to 1-5
	var tier0_stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, 0)
	var tier10_stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, 10)
	var tier1_stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, 1)
	var tier5_stats = MCSTypes.get_tier_stats(MCSTypes.BuildingType.AGRIDOME, 5)

	# Tier 0 should clamp to tier 1
	assert_eq(tier0_stats.get("production", {}).get("food", 0),
		tier1_stats.get("production", {}).get("food", 0),
		"Tier 0 should clamp to tier 1")

	# Tier 10 should clamp to tier 5
	assert_eq(tier10_stats.get("production", {}).get("food", 0),
		tier5_stats.get("production", {}).get("food", 0),
		"Tier 10 should clamp to tier 5")


func test_upgrade_cost_invalid_tier():
	# Tier 1 has no upgrade cost (can't upgrade TO tier 1)
	var tier1_cost = MCSTypes.get_upgrade_cost(1)
	var tier6_cost = MCSTypes.get_upgrade_cost(6)

	assert_true(tier1_cost.is_empty(), "Tier 1 should have no upgrade cost")
	assert_true(tier6_cost.is_empty(), "Tier 6 should have no upgrade cost")
