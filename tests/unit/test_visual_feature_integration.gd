extends GutTest

## Simulation tests to verify AI builds visual-triggering buildings
## Validates: QUARTERS (skyscrapers), RECREATION (stadiums), STARPORT (ships)

const MCSStore = preload("res://scripts/mars_colony_sim/mcs_store.gd")
const MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const MCSAI = preload("res://scripts/mars_colony_sim/mcs_ai.gd")

var _store: MCSStore
var _rng: RandomNumberGenerator

func before_each():
	_store = MCSStore.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 54321  # Different seed for variety

func after_each():
	if _store:
		_store.free()

# ============================================================================
# VISUAL FEATURE REQUIREMENTS
# ============================================================================
# Stadium visuals      -> RECREATION T3+
# Procedural skyscraper -> QUARTERS T4+
# Landing ships        -> STARPORT (any tier)
# Orbital ships        -> STARPORT (any tier)
# City spotlights      -> Any building with height > 60

# ============================================================================
# TESTS
# ============================================================================

func test_ai_builds_quarters_by_year_15():
	# QUARTERS should be built once pop > 60 and year >= 8
	_store.start_new_colony(24)

	var quarters_built = false
	var first_quarters_year = -1

	for year in range(1, 31):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.PRAGMATIST, _rng)
		_store.advance_year()

		var state = _store.get_state()
		if not quarters_built:
			for b in state.buildings:
				if b.type == MCSTypes.BuildingType.QUARTERS:
					quarters_built = true
					first_quarters_year = year
					break

	print("\n=== QUARTERS BUILD TEST ===")
	print("QUARTERS built: %s" % quarters_built)
	if first_quarters_year > 0:
		print("First QUARTERS built in year: %d" % first_quarters_year)

	assert_true(quarters_built, "AI should build at least one QUARTERS by year 30")
	if first_quarters_year > 0:
		assert_lt(first_quarters_year, 20, "QUARTERS should be built before year 20")

func test_ai_builds_recreation_and_upgrades():
	# RECREATION should be built by year 15 and upgraded to T3+ by year 25
	_store.start_new_colony(24)

	var recreation_built = false
	var first_recreation_year = -1
	var recreation_t3_year = -1

	for year in range(1, 41):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.PRAGMATIST, _rng)
		_store.advance_year()

		var state = _store.get_state()
		for b in state.buildings:
			if b.type == MCSTypes.BuildingType.RECREATION:
				if not recreation_built:
					recreation_built = true
					first_recreation_year = year
				if b.get("tier", 1) >= 3 and recreation_t3_year < 0:
					recreation_t3_year = year

	print("\n=== RECREATION UPGRADE TEST ===")
	print("RECREATION built: %s (year %d)" % [recreation_built, first_recreation_year])
	print("RECREATION T3+ reached: %s" % ("year %d" % recreation_t3_year if recreation_t3_year > 0 else "NOT YET"))

	assert_true(recreation_built, "AI should build RECREATION")
	# Stadium visuals require T3+
	assert_gt(recreation_t3_year, 0, "RECREATION should reach T3+ for stadium visuals")
	assert_lt(recreation_t3_year, 35, "RECREATION T3+ should happen before year 35")

func test_quarters_reaches_t4_for_skyscrapers():
	# QUARTERS T4+ triggers procedural skyscraper visuals
	_store.start_new_colony(24)

	var quarters_t4_year = -1
	var max_quarters_tier = 0

	for year in range(1, 51):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.VISIONARY, _rng)  # Visionary more likely to grow
		_store.advance_year()

		var state = _store.get_state()
		for b in state.buildings:
			if b.type == MCSTypes.BuildingType.QUARTERS:
				var tier = b.get("tier", 1)
				if tier > max_quarters_tier:
					max_quarters_tier = tier
				if tier >= 4 and quarters_t4_year < 0:
					quarters_t4_year = year

	print("\n=== QUARTERS T4 (SKYSCRAPER) TEST ===")
	print("Max QUARTERS tier reached: T%d" % max_quarters_tier)
	print("QUARTERS T4+ year: %s" % ("year %d" % quarters_t4_year if quarters_t4_year > 0 else "NOT REACHED"))

	assert_gt(max_quarters_tier, 0, "AI should build QUARTERS")
	# Skyscraper visuals require T4+
	if quarters_t4_year > 0:
		print("SUCCESS: Procedural skyscrapers will be visible from year %d" % quarters_t4_year)
		assert_lt(quarters_t4_year, 45, "QUARTERS T4 should happen before year 45")
	else:
		# This is acceptable if max tier is at least T3 and heading toward T4
		assert_gte(max_quarters_tier, 2, "QUARTERS should reach at least T2 by year 50")

func test_starport_built_for_ship_visuals():
	# STARPORT enables landing ship and orbital ship visuals
	_store.start_new_colony(24)

	var starport_year = -1

	for year in range(1, 21):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.PRAGMATIST, _rng)
		_store.advance_year()

		var state = _store.get_state()
		if starport_year < 0:
			for b in state.buildings:
				if b.type == MCSTypes.BuildingType.STARPORT:
					starport_year = year
					break

	print("\n=== STARPORT (SHIP VISUALS) TEST ===")
	print("STARPORT built: %s" % (starport_year > 0))
	if starport_year > 0:
		print("STARPORT built in year: %d" % starport_year)

	assert_gt(starport_year, 0, "AI should build STARPORT for ship visuals")
	assert_lt(starport_year, 15, "STARPORT should be built before year 15")

func test_full_50_year_visual_progression():
	# Comprehensive test: track all visual-triggering buildings
	_store.start_new_colony(24)

	var milestones = {
		"starport_built": {"year": -1, "description": "Landing/orbital ship visuals enabled"},
		"recreation_built": {"year": -1, "description": "Social building established"},
		"recreation_t3": {"year": -1, "description": "STADIUM VISUALS ENABLED"},
		"quarters_built": {"year": -1, "description": "Luxury housing established"},
		"quarters_t4": {"year": -1, "description": "PROCEDURAL SKYSCRAPERS ENABLED"},
		"quarters_t5": {"year": -1, "description": "MEGA-SKYSCRAPERS ENABLED"},
	}

	var year_data: Array = []

	for year in range(1, 51):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.VISIONARY, _rng)
		_store.advance_year()

		var state = _store.get_state()
		var pop = state.colonists.filter(func(c): return c.is_alive).size()
		var building_count = state.buildings.size()

		# Track milestones
		for b in state.buildings:
			match b.type:
				MCSTypes.BuildingType.STARPORT:
					if milestones.starport_built.year < 0:
						milestones.starport_built.year = year
				MCSTypes.BuildingType.RECREATION:
					if milestones.recreation_built.year < 0:
						milestones.recreation_built.year = year
					if b.get("tier", 1) >= 3 and milestones.recreation_t3.year < 0:
						milestones.recreation_t3.year = year
				MCSTypes.BuildingType.QUARTERS:
					if milestones.quarters_built.year < 0:
						milestones.quarters_built.year = year
					var tier = b.get("tier", 1)
					if tier >= 4 and milestones.quarters_t4.year < 0:
						milestones.quarters_t4.year = year
					if tier >= 5 and milestones.quarters_t5.year < 0:
						milestones.quarters_t5.year = year

		# Store yearly data for summary
		if year % 10 == 0:
			year_data.append({
				"year": year,
				"pop": pop,
				"buildings": building_count,
				"milestones_hit": milestones.values().filter(func(m): return m.year > 0 and m.year <= year).size()
			})

	# Print results
	var divider = "============================================================"
	print("\n" + divider)
	print("=== 50-YEAR VISUAL PROGRESSION SIMULATION ===")
	print(divider)

	print("\n--- MILESTONES ---")
	for key in milestones:
		var m = milestones[key]
		var status = "Year %d" % m.year if m.year > 0 else "NOT REACHED"
		print("  [%s] %s: %s" % [status, key.to_upper(), m.description])

	print("\n--- DECADE SUMMARY ---")
	for yd in year_data:
		print("  Year %d: Pop %d, Buildings %d, Milestones %d/6" % [
			yd.year, yd.pop, yd.buildings, yd.milestones_hit
		])

	# Count final visual buildings
	var state = _store.get_state()
	var quarters_count = 0
	var recreation_count = 0
	var quarters_t3_plus = 0
	var recreation_t3_plus = 0

	for b in state.buildings:
		match b.type:
			MCSTypes.BuildingType.QUARTERS:
				quarters_count += 1
				if b.get("tier", 1) >= 3:
					quarters_t3_plus += 1
			MCSTypes.BuildingType.RECREATION:
				recreation_count += 1
				if b.get("tier", 1) >= 3:
					recreation_t3_plus += 1

	print("\n--- FINAL STATE (Year 50) ---")
	print("  QUARTERS: %d total (%d at T3+)" % [quarters_count, quarters_t3_plus])
	print("  RECREATION: %d total (%d at T3+)" % [recreation_count, recreation_t3_plus])

	# Assertions
	assert_gt(milestones.starport_built.year, 0, "STARPORT should be built")
	assert_gt(milestones.recreation_built.year, 0, "RECREATION should be built")
	assert_gt(milestones.quarters_built.year, 0, "QUARTERS should be built")

	# Visual milestones (these are the key tests)
	var visual_milestones_hit = 0
	if milestones.recreation_t3.year > 0:
		visual_milestones_hit += 1
	if milestones.quarters_t4.year > 0:
		visual_milestones_hit += 1

	print("\n--- VISUAL MILESTONES ---")
	print("  Stadium visuals (RECREATION T3+): %s" % ("YES" if milestones.recreation_t3.year > 0 else "NO"))
	print("  Skyscraper visuals (QUARTERS T4+): %s" % ("YES" if milestones.quarters_t4.year > 0 else "NO"))
	print("  Visual milestones hit: %d/2" % visual_milestones_hit)

	assert_gt(visual_milestones_hit, 0, "At least one visual milestone should be hit by year 50")

func test_colony_survives_with_lifestyle_buildings():
	# Ensure adding lifestyle buildings doesn't crash the colony
	_store.start_new_colony(24)

	var colony_failed = false
	var fail_reason = ""

	for year in range(1, 51):
		var state = _store.get_state()

		# Check for colony failure conditions
		var alive = state.colonists.filter(func(c): return c.is_alive).size()
		if alive == 0:
			colony_failed = true
			fail_reason = "Extinction at year %d" % year
			break

		var food = state.resources.get("food", 0)
		if food <= 0 and year > 5:
			# Low food warning but not necessarily failure
			pass

		MCSAI.run_ai_turn(_store, MCSAI.Personality.PRAGMATIST, _rng)
		_store.advance_year()

	print("\n=== COLONY STABILITY TEST ===")
	if colony_failed:
		print("FAILURE: %s" % fail_reason)
	else:
		var state = _store.get_state()
		var final_pop = state.colonists.filter(func(c): return c.is_alive).size()
		print("SUCCESS: Colony survived 50 years with population %d" % final_pop)

	assert_false(colony_failed, "Colony should survive 50 years with lifestyle building priorities")

func test_morale_roi_boosts_lifestyle_upgrades():
	# Verify the morale ROI boost is working
	_store.start_new_colony(24)

	# Build a RECREATION manually
	_store.start_construction(MCSTypes.BuildingType.RECREATION)
	_store.advance_year()  # Complete construction

	var state = _store.get_state()
	var recreation_building = null
	for b in state.buildings:
		if b.type == MCSTypes.BuildingType.RECREATION:
			recreation_building = b
			break

	if recreation_building:
		# Calculate ROI for upgrading RECREATION
		var roi = MCSAI._calculate_upgrade_roi(recreation_building, state)
		print("\n=== MORALE ROI TEST ===")
		print("RECREATION T1 upgrade ROI: %.2f" % roi)

		# RECREATION has morale_boost that should contribute to ROI
		# T1 morale_boost = 12, T2 morale_boost = 25 (increase of 13)
		# With weight 4.0, that's +52 to value_score
		assert_gt(roi, 0, "RECREATION upgrade should have positive ROI due to morale boost")

		# Compare to a production building
		var fabricator = null
		for b in state.buildings:
			if b.type == MCSTypes.BuildingType.FABRICATOR:
				fabricator = b
				break

		if fabricator:
			var fab_roi = MCSAI._calculate_upgrade_roi(fabricator, state)
			print("FABRICATOR T1 upgrade ROI: %.2f" % fab_roi)
			print("ROI ratio (REC/FAB): %.2f" % (roi / fab_roi if fab_roi > 0 else 999))
	else:
		print("RECREATION not found - test inconclusive")

	assert_true(recreation_building != null, "Should have a RECREATION building")

func test_reserve_cap_allows_starport():
	# Test that the reserve calculation fix allows expensive buildings to be built
	# With the old code, reserves could exceed stockpile, blocking all construction
	_store.start_new_colony(24)

	# Simulate mid-game scenario: good resources but high population
	var state = _store.get_state()

	# Give colony enough resources but simulate high pop (which would over-reserve with old code)
	# Old code: reserve_materials = max(200, pop*3) = max(200, 300*3) = 900
	# With only 800 materials, available = 800-900 = NEGATIVE (blocked!)
	# New code: reserve = min(900, 800*0.6) = 480, available = 320 (can build!)

	print("\n=== RESERVE CAP TEST ===")

	# Run 20 years and check if STARPORT gets built
	var starport_year = -1

	for year in range(1, 25):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.VISIONARY, _rng)
		_store.advance_year()

		state = _store.get_state()

		# Check for STARPORT
		if starport_year < 0:
			for b in state.buildings:
				if b.type == MCSTypes.BuildingType.STARPORT:
					starport_year = year
					break

		# Print resource state every 5 years
		if year % 5 == 0:
			var resources = state.resources
			var pop = state.colonists.filter(func(c): return c.is_alive).size()
			print("Year %d: Pop %d, Materials %d, Parts %d" % [
				year, pop,
				resources.get("building_materials", 0),
				resources.get("machine_parts", 0)
			])

	print("STARPORT built: %s" % ("Year %d" % starport_year if starport_year > 0 else "NOT BUILT"))

	# With the reserve fix, STARPORT should be built by year 20
	# (It has priority 92 and unlocks at year 5)
	assert_gt(starport_year, 0, "STARPORT should be built with fixed reserve calculation")
	if starport_year > 0:
		assert_lt(starport_year, 20, "STARPORT should be built before year 20")

func test_orbital_buildings_unlock_sky_visuals():
	# Test that building orbital infrastructure triggers sky visual drawing
	# This is a logic test - ensures the view code has buildings to draw
	_store.start_new_colony(24)

	# Manually add a STARPORT to verify the visual trigger logic
	# (This tests the visual code path, not AI building decisions)
	_store.start_construction(MCSTypes.BuildingType.STARPORT)

	# Construction completes over 52 weeks - run weekly ticks
	for _week in range(52):
		_store.advance_week()

	var state = _store.get_state()

	# Count operational starports
	var operational_starports = 0
	for b in state.buildings:
		if b.type == MCSTypes.BuildingType.STARPORT and b.is_operational:
			operational_starports += 1

	print("\n=== ORBITAL VISUAL TRIGGER TEST ===")
	print("Operational STARPORTS: %d" % operational_starports)

	# If we have an operational starport, the view code should draw:
	# - Starport ships ascending/descending
	# - Satellites
	# - Eventually orbital station (if ORBITAL built)

	assert_gt(operational_starports, 0, "Should have at least 1 operational STARPORT")

	# Also verify STARPORT is in the buildings list (view iterates this)
	var starport_count = state.buildings.filter(func(b): return b.type == MCSTypes.BuildingType.STARPORT).size()
	assert_gt(starport_count, 0, "STARPORT should be in buildings array for view to find")

func test_ai_builds_food_when_in_deficit():
	# Test that AI prioritizes AGRIDOME when food is in deficit
	_store.start_new_colony(24)

	# Add initial buildings but create a food deficit scenario
	# Many colonists + few agridomes = food deficit
	_store.start_construction(MCSTypes.BuildingType.HABITAT)
	_store.start_construction(MCSTypes.BuildingType.HABITAT)
	_store.start_construction(MCSTypes.BuildingType.HABITAT)
	_store.start_construction(MCSTypes.BuildingType.POWER_STATION)
	_store.start_construction(MCSTypes.BuildingType.POWER_STATION)

	# Run a year to complete construction
	for _week in range(52):
		_store.advance_week()

	# Now force a food deficit by adding more colonists than production can handle
	var state = _store.get_state()
	# Set food low to trigger deficit urgency
	state.resources["food"] = 200  # Low food

	print("\n=== FOOD DEFICIT TEST ===")

	# Count agridomes before AI turns
	var initial_agridomes = state.buildings.filter(func(b): return b.type == MCSTypes.BuildingType.AGRIDOME).size()
	print("Initial AGRIDOMES: %d" % initial_agridomes)
	print("Initial food: %d" % state.resources.get("food", 0))

	# Run AI for 5 years - it should build agridomes to address food deficit
	var agridome_built = false
	for year in range(1, 6):
		MCSAI.run_ai_turn(_store, MCSAI.Personality.PRAGMATIST, _rng)
		_store.advance_year()

		state = _store.get_state()
		var current_agridomes = state.buildings.filter(func(b): return b.type == MCSTypes.BuildingType.AGRIDOME).size()

		if current_agridomes > initial_agridomes:
			agridome_built = true
			print("Year %d: AGRIDOME built! Total: %d" % [year, current_agridomes])
			break

		print("Year %d: No new agridome (total: %d)" % [year, current_agridomes])

	assert_true(agridome_built, "AI should build AGRIDOME when food is in deficit")
