extends GutTest

## Unit tests for VnpReducer
## Tests state transformation logic for Von Neumann Probe

const VnpReducer = preload("res://scripts/von_neumann_probe/vnp_reducer.gd")
const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

var reducer: VnpReducer


func before_each():
	reducer = VnpReducer.new()


func after_each():
	if reducer:
		reducer.queue_free()


# ============================================================================
# INITIAL STATE TESTS
# ============================================================================

func test_initial_state_has_three_teams():
	var state = reducer.get_initial_state()
	assert_eq(state.teams.size(), 3, "Should have 3 teams")
	assert_true(state.teams.has(VnpTypes.Team.PLAYER), "Should have PLAYER team")
	assert_true(state.teams.has(VnpTypes.Team.ENEMY_1), "Should have ENEMY_1 team")
	assert_true(state.teams.has(VnpTypes.Team.NEMESIS), "Should have NEMESIS team")


func test_initial_state_starting_energy():
	var state = reducer.get_initial_state()
	assert_eq(state.teams[VnpTypes.Team.PLAYER].energy, 800, "Player should start with 800 energy")
	assert_eq(state.teams[VnpTypes.Team.ENEMY_1].energy, 800, "Enemy should start with 800 energy")
	assert_eq(state.teams[VnpTypes.Team.NEMESIS].energy, 1500, "Nemesis should start with 1500 energy")


func test_initial_state_no_ships():
	var state = reducer.get_initial_state()
	assert_eq(state.ships.size(), 0, "Should start with no ships")


func test_initial_state_not_game_over():
	var state = reducer.get_initial_state()
	assert_false(state.game_over, "Should not be game over initially")
	assert_eq(state.winner, -1, "Winner should be -1 initially")


# ============================================================================
# BUILD_SHIP TESTS
# ============================================================================

func test_build_ship_deducts_energy():
	var state = reducer.get_initial_state()
	var frigate_cost = VnpTypes.SHIP_STATS[VnpTypes.ShipType.FRIGATE].cost

	var new_state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(100, 100)
	})

	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].energy, 800 - frigate_cost)


func test_build_ship_creates_ship():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(100, 100)
	})

	assert_eq(new_state.ships.size(), 1, "Should have 1 ship")


func test_build_ship_increments_id():
	var state = reducer.get_initial_state()
	assert_eq(state.next_ship_id, 1, "Initial ship ID should be 1")

	var new_state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(100, 100)
	})

	assert_eq(new_state.next_ship_id, 2, "Next ship ID should be 2")


func test_build_ship_sets_correct_stats():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(150, 200)
	})

	var ship = new_state.ships[1]
	assert_eq(ship.team, VnpTypes.Team.PLAYER)
	assert_eq(ship.type, VnpTypes.ShipType.FRIGATE)
	assert_eq(ship.position, Vector2(150, 200))
	assert_eq(ship.state, "idle")


func test_build_ship_requires_mass_for_advanced_ships():
	var state = reducer.get_initial_state()
	# Cruiser requires mass
	var cruiser_cost = VnpTypes.SHIP_STATS[VnpTypes.ShipType.CRUISER].cost
	var cruiser_mass = VnpTypes.SHIP_STATS[VnpTypes.ShipType.CRUISER].get("mass_cost", 0)

	# Should fail - no mass
	var new_state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.CRUISER,
		"position": Vector2(100, 100)
	})

	assert_eq(new_state.ships.size(), 0, "Should not build cruiser without mass")
	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].energy, 800, "Energy should be unchanged")


# ============================================================================
# DAMAGE_SHIP TESTS
# ============================================================================

func test_damage_ship_reduces_health():
	var state = reducer.get_initial_state()
	# First build a ship
	state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(100, 100)
	})

	var initial_health = state.ships[1].health

	var new_state = reducer.reduce(state, {
		"type": "DAMAGE_SHIP",
		"ship_id": 1,
		"damage": 20
	})

	assert_eq(new_state.ships[1].health, initial_health - 20)


func test_damage_ship_destroys_at_zero():
	var state = reducer.get_initial_state()
	# Build a frigate
	state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(100, 100)
	})

	# Deal lethal damage
	var new_state = reducer.reduce(state, {
		"type": "DAMAGE_SHIP",
		"ship_id": 1,
		"damage": 1000
	})

	assert_false(new_state.ships.has(1), "Ship should be destroyed")


func test_damage_nonexistent_ship():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "DAMAGE_SHIP",
		"ship_id": 999,
		"damage": 50
	})

	# Should not crash, state unchanged
	assert_eq(new_state.ships.size(), 0)


# ============================================================================
# ADD_ENERGY TESTS
# ============================================================================

func test_add_energy_increases_team_energy():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "ADD_ENERGY",
		"team": VnpTypes.Team.PLAYER,
		"amount": 100
	})

	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].energy, 900)


func test_add_energy_different_teams():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "ADD_ENERGY",
		"team": VnpTypes.Team.NEMESIS,
		"amount": 50
	})

	assert_eq(new_state.teams[VnpTypes.Team.NEMESIS].energy, 1550)
	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].energy, 800, "Other teams unaffected")


# ============================================================================
# ADD_MASS TESTS
# ============================================================================

func test_add_mass_increases_team_mass():
	var state = reducer.get_initial_state()
	assert_eq(state.teams[VnpTypes.Team.PLAYER].mass, 0, "Start with 0 mass")

	var new_state = reducer.reduce(state, {
		"type": "ADD_MASS",
		"team": VnpTypes.Team.PLAYER,
		"amount": 25
	})

	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].mass, 25)


# ============================================================================
# SET_RALLY_POINT TESTS
# ============================================================================

func test_set_rally_point():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "SET_RALLY_POINT",
		"team": VnpTypes.Team.PLAYER,
		"target": Vector2(500, 500)
	})

	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].rally_point, Vector2(500, 500))


func test_set_rally_point_string_target():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {
		"type": "SET_RALLY_POINT",
		"team": VnpTypes.Team.PLAYER,
		"target": "enemy_base"
	})

	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].rally_point, "enemy_base")


# ============================================================================
# STRATEGIC POINT TESTS
# ============================================================================

func test_initialize_strategic_points():
	var state = reducer.get_initial_state()
	var points = {
		"center": {"type": VnpTypes.PointType.CENTER, "position": Vector2(500, 400)},
		"asteroid1": {"type": VnpTypes.PointType.ASTEROID_FIELD, "position": Vector2(200, 200)}
	}

	var new_state = reducer.reduce(state, {
		"type": "INITIALIZE_STRATEGIC_POINTS",
		"points": points
	})

	assert_eq(new_state.strategic_points.size(), 2)


func test_capture_strategic_point():
	var state = reducer.get_initial_state()
	# Initialize a point
	state = reducer.reduce(state, {
		"type": "INITIALIZE_STRATEGIC_POINTS",
		"points": {
			"center": {"type": VnpTypes.PointType.CENTER, "position": Vector2(500, 400), "owner": null}
		}
	})

	var new_state = reducer.reduce(state, {
		"type": "CAPTURE_STRATEGIC_POINT",
		"point_id": "center",
		"team": VnpTypes.Team.PLAYER
	})

	assert_eq(new_state.strategic_points["center"].owner, VnpTypes.Team.PLAYER)
	# Capture bonus
	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].energy, 850, "Capture bonus of 50 energy")
	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].mass, 10, "Capture bonus of 10 mass")


# ============================================================================
# CHECK_VICTORY TESTS
# ============================================================================

func test_check_victory_no_winner_early():
	var state = reducer.get_initial_state()

	var new_state = reducer.reduce(state, {"type": "CHECK_VICTORY"})

	assert_false(new_state.game_over, "Game should continue when all teams can build")


func test_check_victory_single_team_remaining():
	var state = reducer.get_initial_state()
	# Drain two teams of energy and ships
	state.teams[VnpTypes.Team.ENEMY_1].energy = 0
	state.teams[VnpTypes.Team.NEMESIS].energy = 0
	# Player still has energy to build

	var new_state = reducer.reduce(state, {"type": "CHECK_VICTORY"})

	assert_true(new_state.game_over, "Game should end")
	assert_eq(new_state.winner, VnpTypes.Team.PLAYER, "Player should win")


# ============================================================================
# RESET_GAME TESTS
# ============================================================================

func test_reset_game():
	var state = reducer.get_initial_state()
	# Modify state
	state.teams[VnpTypes.Team.PLAYER].energy = 0
	state.game_over = true
	state.winner = VnpTypes.Team.ENEMY_1

	var new_state = reducer.reduce(state, {"type": "RESET_GAME"})

	assert_eq(new_state.teams[VnpTypes.Team.PLAYER].energy, 800, "Energy should reset")
	assert_false(new_state.game_over, "Game over should reset")
	assert_eq(new_state.winner, -1, "Winner should reset")


# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_reduce_does_not_mutate_original():
	var state = reducer.get_initial_state()
	var original_energy = state.teams[VnpTypes.Team.PLAYER].energy

	var _new_state = reducer.reduce(state, {
		"type": "BUILD_SHIP",
		"team": VnpTypes.Team.PLAYER,
		"ship_type": VnpTypes.ShipType.FRIGATE,
		"position": Vector2(100, 100)
	})

	# Original state should be unchanged
	assert_eq(state.teams[VnpTypes.Team.PLAYER].energy, original_energy, "Original state should be unchanged")
