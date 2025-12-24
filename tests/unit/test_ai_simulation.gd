extends GutTest

## Simulation test to verify AI upgrade behavior over 50 years

const MCSStore = preload("res://scripts/mars_colony_sim/mcs_store.gd")
const MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const MCSAI = preload("res://scripts/mars_colony_sim/mcs_ai.gd")
const MCSReducer = preload("res://scripts/mars_colony_sim/mcs_reducer.gd")

var _store: MCSStore
var _rng: RandomNumberGenerator

func before_each():
	_store = MCSStore.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345

func after_each():
	if _store:
		_store.free()

func test_simulate_50_years():
	# Start a new colony
	_store.start_new_colony(24)

	var state = _store.get_state()
	print("\n=== YEAR 1 STATE ===")
	print("Buildings: %d" % state.buildings.size())
	print("Population: %d" % state.colonists.size())
	print("Resources: materials=%d, parts=%d" % [
		state.resources.get("building_materials", 0),
		state.resources.get("machine_parts", 0)
	])

	# Check initial building tiers
	var tier_counts = _count_tiers(state.buildings)
	print("Initial tiers: T1=%d T2=%d T3=%d T4=%d T5=%d" % [
		tier_counts[1], tier_counts[2], tier_counts[3], tier_counts[4], tier_counts[5]
	])

	# Simulate 50 years with AI
	for year in range(1, 51):
		# Run AI turn
		var ai_result = MCSAI.run_ai_turn(_store, MCSAI.Personality.VISIONARY, _rng)

		# Log upgrade actions
		for action in ai_result.actions:
			if "UPGRADE" in action:
				print("Year %d: %s" % [year, action])

		# Advance the year
		_store.advance_year()

		# Every 10 years, print summary
		if year % 10 == 0:
			state = _store.get_state()
			tier_counts = _count_tiers(state.buildings)
			print("\n=== YEAR %d ===" % year)
			print("Buildings: %d, Population: %d" % [state.buildings.size(), state.colonists.size()])
			print("Tiers: T1=%d T2=%d T3=%d T4=%d T5=%d" % [
				tier_counts[1], tier_counts[2], tier_counts[3], tier_counts[4], tier_counts[5]
			])
			print("Resources: materials=%d, parts=%d" % [
				state.resources.get("building_materials", 0),
				state.resources.get("machine_parts", 0)
			])

			# Print sample building details
			for b in state.buildings.slice(0, 3):
				print("  %s: tier=%d, upgrading=%s" % [
					MCSTypes.get_building_name(b.type),
					b.get("tier", 1),
					b.get("upgrading", false)
				])

	# Final assertions
	state = _store.get_state()
	tier_counts = _count_tiers(state.buildings)

	print("\n=== FINAL STATE (Year 50) ===")
	print("Total buildings: %d" % state.buildings.size())
	print("Tier distribution: T1=%d T2=%d T3=%d T4=%d T5=%d" % [
		tier_counts[1], tier_counts[2], tier_counts[3], tier_counts[4], tier_counts[5]
	])

	# By year 50, we should have many T4/T5 buildings
	var high_tier_count = tier_counts[4] + tier_counts[5]
	assert_gt(high_tier_count, 5, "Should have at least 5 T4/T5 buildings by year 50")
	assert_gt(tier_counts[5], 0, "Should have at least some T5 buildings by year 50")

func test_single_upgrade_cycle():
	# Test that a single upgrade actually works
	_store.start_new_colony(24)

	var state = _store.get_state()
	var first_building = state.buildings[0]
	print("\nBuilding before upgrade: %s tier=%d" % [
		MCSTypes.get_building_name(first_building.type),
		first_building.get("tier", 1)
	])

	# Manually trigger upgrade
	_store.upgrade_building(first_building.id)

	state = _store.get_state()
	first_building = state.buildings[0]
	print("After upgrade_building call: upgrading=%s, target_tier=%s, progress=%s" % [
		first_building.get("upgrading", false),
		first_building.get("target_tier", "none"),
		first_building.get("upgrade_progress", 0)
	])

	# Progress the upgrade
	_store.progress_upgrades()

	state = _store.get_state()
	first_building = state.buildings[0]
	print("After progress_upgrades: tier=%d, upgrading=%s, progress=%s" % [
		first_building.get("tier", 1),
		first_building.get("upgrading", false),
		first_building.get("upgrade_progress", 0)
	])

	# Should be tier 2 now (1-year duration)
	assert_eq(first_building.get("tier", 1), 2, "Building should be tier 2 after upgrade completes")

func test_ai_chooses_upgrades():
	# Test that AI actually selects buildings for upgrade
	_store.start_new_colony(24)

	# Advance to year 2 so buildings are old enough
	_store.advance_year()

	var state = _store.get_state()
	print("\nYear 2 state before AI turn:")
	print("Resources: materials=%d, parts=%d" % [
		state.resources.get("building_materials", 0),
		state.resources.get("machine_parts", 0)
	])

	# Run AI turn
	var ai_result = MCSAI.run_ai_turn(_store, MCSAI.Personality.VISIONARY, _rng)

	print("\nAI actions:")
	for action in ai_result.actions:
		print("  %s" % action)

	# Check if any upgrades were started
	state = _store.get_state()
	var upgrading_count = 0
	for b in state.buildings:
		if b.get("upgrading", false):
			upgrading_count += 1
			print("Building upgrading: %s -> T%d" % [
				MCSTypes.get_building_name(b.type),
				b.get("target_tier", 0)
			])

	print("\nTotal buildings upgrading: %d" % upgrading_count)
	assert_gt(upgrading_count, 0, "AI should have started at least one upgrade")

func _count_tiers(buildings: Array) -> Dictionary:
	var counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for b in buildings:
		var tier = b.get("tier", 1)
		counts[tier] = counts.get(tier, 0) + 1
	return counts
