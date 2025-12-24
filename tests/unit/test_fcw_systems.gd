extends GutTest
## Unit tests for FCW critical path systems
## Tests: Combat resolution, Evacuation calculation, Victory tier thresholds
## Run via GUT panel in editor, or CLI: godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_fcw_systems.gd

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWReducer = preload("res://scripts/first_contact_war/fcw_reducer.gd")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _create_test_state() -> Dictionary:
	## Create minimal valid state for testing
	var zones = {}
	for zone_id in FCWTypes.ZoneId.values():
		zones[zone_id] = {
			"id": zone_id,
			"status": FCWTypes.ZoneStatus.CONTROLLED,
			"population": 1_000_000 if zone_id == FCWTypes.ZoneId.EARTH else 100_000,
			"assigned_fleet": {},
			"buildings": {}
		}

	return {
		"turn": 1,
		"game_time": 0.0,
		"zones": zones,
		"resources": {
			"ore": 100, "steel": 50, "energy": 100,
			"electronics": 20, "rare": 30, "weapons": 10
		},
		"fleet": {
			FCWTypes.ShipType.FRIGATE: 10,
			FCWTypes.ShipType.CRUISER: 3,
			FCWTypes.ShipType.CARRIER: 1,
			FCWTypes.ShipType.DREADNOUGHT: 0
		},
		"production_queue": [],
		"fleets_in_transit": [],
		"herald_current_zone": FCWTypes.ZoneId.KUIPER,
		"herald_strength": 50,
		"lives_evacuated": 0,
		"lives_lost": 0,
		"event_log": [],
		"entities": [],
		"game_over": false,
		"victory_tier": FCWTypes.VictoryTier.ANNIHILATION
	}


# =============================================================================
# COMBAT RESOLUTION TESTS
# =============================================================================

func test_zone_defense_basic():
	## Single frigate should contribute 10 combat power
	var state = _create_test_state()
	state.zones[FCWTypes.ZoneId.MARS].assigned_fleet = {
		FCWTypes.ShipType.FRIGATE: 1
	}

	var defense = FCWReducer.calc_zone_defense(state, FCWTypes.ZoneId.MARS)
	assert_eq(defense, 10, "1 Frigate = 10 combat power")


func test_zone_defense_multiple_ships():
	## Multiple ships should add their power together
	var state = _create_test_state()
	state.zones[FCWTypes.ZoneId.MARS].assigned_fleet = {
		FCWTypes.ShipType.FRIGATE: 5,   # 5 × 10 = 50
		FCWTypes.ShipType.CRUISER: 2    # 2 × 40 = 80
	}

	var defense = FCWReducer.calc_zone_defense(state, FCWTypes.ZoneId.MARS)
	assert_eq(defense, 130, "5 Frigates + 2 Cruisers = 50 + 80 = 130")


func test_zone_defense_carrier_bonus():
	## Carriers provide +50% defense bonus per carrier
	var state = _create_test_state()
	state.zones[FCWTypes.ZoneId.MARS].assigned_fleet = {
		FCWTypes.ShipType.FRIGATE: 4,   # 4 × 10 = 40 base
		FCWTypes.ShipType.CARRIER: 1    # 25 combat + 50% bonus
	}

	var defense = FCWReducer.calc_zone_defense(state, FCWTypes.ZoneId.MARS)
	# Base: 40 + 25 = 65
	# With 1 carrier bonus (1.5x): 65 × 1.5 = 97.5 → 97
	assert_eq(defense, 97, "4 Frigates + 1 Carrier with 50% bonus = 97")


func test_zone_defense_multiple_carriers():
	## Multiple carriers should stack their defense bonus
	var state = _create_test_state()
	state.zones[FCWTypes.ZoneId.EARTH].assigned_fleet = {
		FCWTypes.ShipType.CRUISER: 2,   # 2 × 40 = 80
		FCWTypes.ShipType.CARRIER: 2    # 2 × 25 = 50, bonus = 2 × 0.5 = 1.0 extra
	}

	var defense = FCWReducer.calc_zone_defense(state, FCWTypes.ZoneId.EARTH)
	# Base: 80 + 50 = 130
	# With 2 carrier bonus (2.0x): 130 × 2.0 = 260
	assert_eq(defense, 260, "2 Cruisers + 2 Carriers = 130 × 2.0 = 260")


func test_zone_defense_dreadnought():
	## Dreadnoughts should contribute 150 combat power each
	var state = _create_test_state()
	state.zones[FCWTypes.ZoneId.MARS].assigned_fleet = {
		FCWTypes.ShipType.DREADNOUGHT: 1
	}

	var defense = FCWReducer.calc_zone_defense(state, FCWTypes.ZoneId.MARS)
	assert_eq(defense, 150, "1 Dreadnought = 150 combat power")


func test_zone_defense_empty():
	## Empty zone should have 0 defense
	var state = _create_test_state()

	var defense = FCWReducer.calc_zone_defense(state, FCWTypes.ZoneId.MARS)
	assert_eq(defense, 0, "Empty zone = 0 defense")


# =============================================================================
# EVACUATION CALCULATION TESTS
# =============================================================================

func test_evacuation_frigate_rate():
	## 1 Frigate = 1 × (10/10) × 100K × 1 = 100K per turn
	var power = FCWTypes.get_ship_combat_power(FCWTypes.ShipType.FRIGATE)
	var multiplier = 1.0  # Non-carrier
	var rate = int(1 * (power / 10.0) * 100_000 * multiplier)

	assert_eq(rate, 100_000, "1 Frigate evacuates 100K per turn")


func test_evacuation_cruiser_rate():
	## 1 Cruiser = 1 × (40/10) × 100K × 1 = 400K per turn
	var power = FCWTypes.get_ship_combat_power(FCWTypes.ShipType.CRUISER)
	var multiplier = 1.0  # Non-carrier
	var rate = int(1 * (power / 10.0) * 100_000 * multiplier)

	assert_eq(rate, 400_000, "1 Cruiser evacuates 400K per turn")


func test_evacuation_carrier_multiplier():
	## Carriers get 8x evacuation multiplier
	## 1 Carrier = 1 × (25/10) × 100K × 8 = 2M per turn
	var power = FCWTypes.get_ship_combat_power(FCWTypes.ShipType.CARRIER)
	var multiplier = 8.0  # Carrier bonus!
	var rate = int(1 * (power / 10.0) * 100_000 * multiplier)

	assert_eq(rate, 2_000_000, "1 Carrier evacuates 2M per turn (8x multiplier)")


func test_evacuation_dreadnought_rate():
	## 1 Dreadnought = 1 × (150/10) × 100K × 1 = 1.5M per turn
	var power = FCWTypes.get_ship_combat_power(FCWTypes.ShipType.DREADNOUGHT)
	var multiplier = 1.0  # Non-carrier
	var rate = int(1 * (power / 10.0) * 100_000 * multiplier)

	assert_eq(rate, 1_500_000, "1 Dreadnought evacuates 1.5M per turn")


func test_evacuation_carrier_vs_dreadnought():
	## Carrier should evacuate more than Dreadnought despite lower combat power
	var carrier_power = FCWTypes.get_ship_combat_power(FCWTypes.ShipType.CARRIER)
	var dread_power = FCWTypes.get_ship_combat_power(FCWTypes.ShipType.DREADNOUGHT)

	var carrier_rate = int(1 * (carrier_power / 10.0) * 100_000 * 8.0)
	var dread_rate = int(1 * (dread_power / 10.0) * 100_000 * 1.0)

	assert_gt(carrier_rate, dread_rate, "Carrier evacuates more than Dreadnought")
	# Carrier: 2M, Dreadnought: 1.5M
	assert_eq(carrier_rate, 2_000_000, "Carrier rate correct")
	assert_eq(dread_rate, 1_500_000, "Dreadnought rate correct")


# =============================================================================
# VICTORY TIER TESTS
# =============================================================================

func test_victory_tier_legendary():
	## >= 80M lives = LEGENDARY
	var tier = FCWTypes.get_victory_tier(80_000_000)
	assert_eq(tier, FCWTypes.VictoryTier.LEGENDARY, "80M = LEGENDARY")

	tier = FCWTypes.get_victory_tier(100_000_000)
	assert_eq(tier, FCWTypes.VictoryTier.LEGENDARY, "100M = LEGENDARY")


func test_victory_tier_heroic():
	## 40-80M lives = HEROIC
	var tier = FCWTypes.get_victory_tier(40_000_000)
	assert_eq(tier, FCWTypes.VictoryTier.HEROIC, "40M = HEROIC")

	tier = FCWTypes.get_victory_tier(79_999_999)
	assert_eq(tier, FCWTypes.VictoryTier.HEROIC, "79.999M = HEROIC")


func test_victory_tier_pyrrhic():
	## 15-40M lives = PYRRHIC
	var tier = FCWTypes.get_victory_tier(15_000_000)
	assert_eq(tier, FCWTypes.VictoryTier.PYRRHIC, "15M = PYRRHIC")

	tier = FCWTypes.get_victory_tier(39_999_999)
	assert_eq(tier, FCWTypes.VictoryTier.PYRRHIC, "39.999M = PYRRHIC")


func test_victory_tier_tragic():
	## 5-15M lives = TRAGIC
	var tier = FCWTypes.get_victory_tier(5_000_000)
	assert_eq(tier, FCWTypes.VictoryTier.TRAGIC, "5M = TRAGIC")

	tier = FCWTypes.get_victory_tier(14_999_999)
	assert_eq(tier, FCWTypes.VictoryTier.TRAGIC, "14.999M = TRAGIC")


func test_victory_tier_annihilation():
	## < 5M lives = ANNIHILATION
	var tier = FCWTypes.get_victory_tier(0)
	assert_eq(tier, FCWTypes.VictoryTier.ANNIHILATION, "0 = ANNIHILATION")

	tier = FCWTypes.get_victory_tier(4_999_999)
	assert_eq(tier, FCWTypes.VictoryTier.ANNIHILATION, "4.999M = ANNIHILATION")


func test_victory_tier_boundary_legendary():
	## Exact boundary test at 80M
	var tier_below = FCWTypes.get_victory_tier(79_999_999)
	var tier_at = FCWTypes.get_victory_tier(80_000_000)

	assert_eq(tier_below, FCWTypes.VictoryTier.HEROIC, "Just below 80M = HEROIC")
	assert_eq(tier_at, FCWTypes.VictoryTier.LEGENDARY, "Exactly 80M = LEGENDARY")


func test_victory_tier_names():
	## Victory tier names should match expected strings
	assert_eq(FCWTypes.get_victory_tier_name(FCWTypes.VictoryTier.LEGENDARY), "LEGENDARY")
	assert_eq(FCWTypes.get_victory_tier_name(FCWTypes.VictoryTier.HEROIC), "HEROIC")
	assert_eq(FCWTypes.get_victory_tier_name(FCWTypes.VictoryTier.PYRRHIC), "PYRRHIC")
	assert_eq(FCWTypes.get_victory_tier_name(FCWTypes.VictoryTier.TRAGIC), "TRAGIC")
	assert_eq(FCWTypes.get_victory_tier_name(FCWTypes.VictoryTier.ANNIHILATION), "ANNIHILATION")
