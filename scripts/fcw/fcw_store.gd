extends Node
class_name FCWStore

## First Contact War - State Store
## Manages mutable state, signals, and RNG

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: Dictionary)
signal turn_ended(turn: int)
signal zone_fallen(zone_id: int)
signal battle_resolved(zone_id: int, defended: bool)
signal game_over(victory_tier: int)
signal ship_completed(ship_type: int)

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_rng.randomize()

func start_new_game() -> void:
	_state = FCWTypes.create_initial_state()
	state_changed.emit(_state)

# ============================================================================
# DISPATCH
# ============================================================================

func dispatch(action: Dictionary) -> void:
	var old_state = _state
	_state = FCWReducer.reduce(_state, action)

	# Emit specific signals based on changes
	_emit_change_signals(old_state, _state, action)

	state_changed.emit(_state)

func dispatch_end_turn() -> void:
	var random_values: Array = []
	for i in range(10):
		random_values.append(_rng.randf())

	var old_state = _state
	dispatch(FCWReducer.action_end_turn(random_values))

	if _state.turn != old_state.turn:
		turn_ended.emit(_state.turn)

func dispatch_build_ship(ship_type: int) -> void:
	dispatch(FCWReducer.action_build_ship(ship_type))

func dispatch_assign_fleet(zone_id: int, ship_type: int, count: int) -> void:
	dispatch(FCWReducer.action_assign_fleet(zone_id, ship_type, count))

func dispatch_set_fleet_order(zone_id: int, order: int) -> void:
	dispatch(FCWReducer.action_set_fleet_order(zone_id, order))

# ============================================================================
# SIGNAL EMISSION
# ============================================================================

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, _action: Dictionary) -> void:
	# Check for zone status changes
	for zone_id in new_state.zones:
		var old_zone = old_state.zones.get(zone_id, {})
		var new_zone = new_state.zones[zone_id]

		if old_zone.get("status") != new_zone.status:
			if new_zone.status == FCWTypes.ZoneStatus.FALLEN:
				zone_fallen.emit(zone_id)

	# Check for game over
	if not old_state.game_over and new_state.game_over:
		game_over.emit(new_state.victory_tier)

	# Check for completed ships
	if new_state.fleet != old_state.fleet:
		for ship_type in new_state.fleet:
			if new_state.fleet[ship_type] > old_state.fleet.get(ship_type, 0):
				ship_completed.emit(ship_type)

# ============================================================================
# GETTERS (Read-only access to state)
# ============================================================================

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_turn() -> int:
	return _state.turn

func get_resources() -> Dictionary:
	return _state.resources.duplicate()

func get_zones() -> Dictionary:
	return _state.zones.duplicate(true)

func get_zone(zone_id: int) -> Dictionary:
	return _state.zones.get(zone_id, {}).duplicate(true)

func get_fleet() -> Dictionary:
	return _state.fleet.duplicate()

func get_available_ships() -> Dictionary:
	return FCWReducer.get_available_ships(_state)

func get_production_queue() -> Array:
	return _state.production_queue.duplicate(true)

func get_lives_evacuated() -> int:
	return _state.lives_evacuated

func get_lives_lost() -> int:
	return _state.lives_lost

func get_herald_strength() -> int:
	return _state.herald_strength

func get_herald_target() -> int:
	return _state.herald_attack_target

func get_event_log() -> Array:
	return _state.event_log.duplicate(true)

func is_game_over() -> bool:
	return _state.game_over

func get_victory_tier() -> int:
	return _state.victory_tier

func can_afford_ship(ship_type: int) -> bool:
	return FCWReducer.can_afford_ship(_state, ship_type)

func get_production_capacity() -> int:
	return FCWReducer.get_production_capacity(_state)

func get_total_fleet_strength() -> int:
	return FCWReducer.get_total_fleet_strength(_state)

func get_zone_defense(zone_id: int) -> int:
	return FCWReducer._calc_zone_defense(_state, zone_id)

func get_controlled_zones() -> Array:
	return FCWReducer.get_controlled_zones(_state)

func estimate_turns_until_earth() -> int:
	return FCWReducer.estimate_turns_until_earth_attack(_state)
