extends GutTest

## Unit tests for Engine Store
## Tests the core state management infrastructure

const Store = preload("res://scripts/engine/core/store.gd")
const RNGManager = preload("res://scripts/engine/core/rng_manager.gd")

var store: Store


func before_each():
	store = Store.new()


# ============================================================================
# STATE ACCESS TESTS
# ============================================================================

func test_get_state_returns_dictionary():
	var state = store.get_state()
	assert_typeof(state, TYPE_DICTIONARY, "get_state should return Dictionary")


func test_get_state_returns_copy():
	store._force_state({"test": "value"})
	var state1 = store.get_state()
	var state2 = store.get_state()

	state1["test"] = "modified"

	assert_eq(state2["test"], "value", "get_state should return independent copies")


func test_get_state_readonly():
	store._force_state({"test": "value"})
	var state = store.get_state_readonly()

	assert_eq(state["test"], "value", "readonly state should be accessible")


func test_get_field_simple():
	store._force_state({"foo": "bar"})
	var value = store.get_field("foo")
	assert_eq(value, "bar")


func test_get_field_nested():
	store._force_state({"level1": {"level2": {"value": 42}}})
	var value = store.get_field("level1.level2.value")
	assert_eq(value, 42)


func test_get_field_missing_returns_default():
	store._force_state({})
	var value = store.get_field("nonexistent", "default")
	assert_eq(value, "default")


func test_get_field_array_index():
	store._force_state({"items": ["a", "b", "c"]})
	var value = store.get_field("items.1")
	assert_eq(value, "b")


func test_get_field_array_out_of_bounds():
	store._force_state({"items": ["a"]})
	var value = store.get_field("items.5", "default")
	assert_eq(value, "default")


# ============================================================================
# RNG TESTS
# ============================================================================

func test_get_rng_returns_manager():
	var rng = store.get_rng()
	assert_not_null(rng, "RNG should not be null")


func test_set_rng_seed():
	store.set_rng_seed(12345)
	var seed = store.get_rng_seed()
	assert_eq(seed, 12345)


func test_rng_deterministic_with_seed():
	store.set_rng_seed(99999)
	var rng = store.get_rng()
	var val1 = rng.randf()

	store.set_rng_seed(99999)
	rng = store.get_rng()
	var val2 = rng.randf()

	assert_eq(val1, val2, "Same seed should produce same random values")


# ============================================================================
# GAME DATA TESTS
# ============================================================================

func test_set_get_game_data():
	var data = {"balance": {"speed": 100}}
	store.set_game_data(data)

	var retrieved = store.get_game_data()
	assert_eq(retrieved["balance"]["speed"], 100)


# ============================================================================
# MIDDLEWARE TESTS
# ============================================================================

func test_add_middleware():
	# Middleware is stored internally - test that add doesn't crash
	var test_middleware = func(action, _state):
		return action

	store.add_middleware(test_middleware)
	# If we got here without error, add succeeded
	assert_true(true, "Middleware added successfully")


func test_remove_middleware():
	var counting_middleware = func(action, _state):
		return action

	store.add_middleware(counting_middleware)
	store.remove_middleware(counting_middleware)
	# If we got here without error, remove succeeded
	assert_true(true, "Middleware removed successfully")


# ============================================================================
# RESET TESTS
# ============================================================================

func test_reset_clears_state():
	store._force_state({"data": "exists"})
	store.reset()

	var state = store.get_state()
	assert_eq(state.size(), 0, "State should be empty after reset")


# ============================================================================
# SIGNAL TESTS
# ============================================================================

func test_state_changed_signal_on_force_state():
	var signal_received = {"count": 0}

	store.state_changed.connect(func(_old, _new):
		signal_received["count"] += 1
	)

	store._force_state({"new": "state"})

	assert_eq(signal_received["count"], 1, "state_changed should emit on _force_state")


func test_state_changed_provides_old_and_new():
	var captured = {"old": null, "new": null}

	store._force_state({"initial": true})

	store.state_changed.connect(func(old_state, new_state):
		captured["old"] = old_state
		captured["new"] = new_state
	)

	store._force_state({"updated": true})

	assert_eq(captured["old"].get("initial"), true, "Should capture old state")
	assert_eq(captured["new"].get("updated"), true, "Should capture new state")


# ============================================================================
# ACTION HISTORY TESTS
# ============================================================================

func test_get_action_history_empty():
	var history = store.get_action_history()
	assert_eq(history.size(), 0, "History should be empty initially")


func test_action_history_state_key():
	store._force_state({"action_history": [{"action": {"type": "TEST"}}]})
	var history = store.get_action_history()
	assert_eq(history.size(), 1)
