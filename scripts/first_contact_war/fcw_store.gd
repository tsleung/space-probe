extends Node
class_name FCWStore

## First Contact War - State Store
## Manages mutable state, signals, and RNG
## Movement-based space combat: position, velocity, time, detection
##
## Time System:
##   - game_time: float in HOURS (single source of truth)
##   - Advances in discrete 1-hour ticks via dispatch_tick()
##   - Visual interpolation handled externally using tick_progress

const FCWTime = preload("res://scripts/first_contact_war/fcw_time.gd")
const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWReducer = preload("res://scripts/first_contact_war/fcw_reducer.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: Dictionary)
signal turn_ended(turn: int)
signal hour_ticked(game_time: float)
signal day_boundary(day: int)
signal week_boundary(week: int)
signal zone_fallen(zone_id: int)
signal battle_resolved(zone_id: int, defended: bool)
signal game_over(victory_tier: int)
signal ship_completed(ship_type: int)

# New entity system signals
signal entity_spawned(entity: Dictionary)
signal entity_destroyed(entity: Dictionary)
signal entity_detected(entity: Dictionary, by_herald: bool)
signal entity_arrived(entity: Dictionary, zone_id: int)
signal intercept_started(pursuer: Dictionary, target: Dictionary)

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

func dispatch_tick() -> void:
	## Advance game time by 1 hour (the base time unit)
	## This is the primary way time advances in the game
	var random_values: Array = []
	for i in range(10):
		random_values.append(_rng.randf())

	var old_state = _state
	var old_time = old_state.get("game_time", 0.0)

	dispatch(FCWReducer.action_tick(random_values))

	var new_time = _state.get("game_time", 0.0)

	# Emit time-based signals
	hour_ticked.emit(new_time)

	# Check for day boundary (every 24 hours)
	if FCWTime.is_day_boundary(old_time, new_time):
		day_boundary.emit(FCWTime.get_total_days(new_time))

	# Check for week boundary (every 168 hours)
	if FCWTime.is_week_boundary(old_time, new_time):
		week_boundary.emit(FCWTime.get_week(new_time))

	# Legacy turn signal (turn advances on week boundary)
	if _state.turn != old_state.turn:
		turn_ended.emit(_state.turn)

func dispatch_end_turn() -> void:
	## DEPRECATED: Use dispatch_tick() instead
	## Kept for backward compatibility - advances by 1 full week
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

func dispatch_recall_fleet(from_zone: int, to_zone: int, ship_type: int, count: int) -> void:
	## Recall ships from one zone to another (to_zone=-1 for reserve pool)
	dispatch(FCWReducer.action_recall_fleet(from_zone, to_zone, ship_type, count))

func dispatch_set_fleet_order(zone_id: int, order: int) -> void:
	dispatch(FCWReducer.action_set_fleet_order(zone_id, order))

# ============================================================================
# ENTITY DISPATCH HELPERS (New unified entity system)
# ============================================================================

func dispatch_spawn_entity(entity: Dictionary) -> void:
	## Spawn a new entity (warship, transport, weapon)
	dispatch(FCWReducer.action_spawn_entity(entity))

func dispatch_set_entity_destination(entity_id: String, zone_id: int, route_type: String = "direct") -> void:
	## Set destination for an entity
	## route_type: "direct" (fast, visible), "coast" (slow, stealthy)
	dispatch(FCWReducer.action_set_destination(entity_id, zone_id, route_type))

func dispatch_set_entity_movement_state(entity_id: String, movement_state: int) -> void:
	## Change entity movement state (BURNING, COASTING, ORBITING)
	dispatch(FCWReducer.action_set_movement_state(entity_id, movement_state))

func dispatch_split_entity(entity_id: String, split_count: int, new_destination: int) -> void:
	## Split a fleet entity for decoy tactics
	dispatch(FCWReducer.action_split_entity(entity_id, split_count, new_destination))

func dispatch_launch_weapon(entity_id: String, target_entity_id: String, weapon_power: float, powered: bool = false) -> void:
	## Launch a weapon from entity toward target
	## powered=false: ballistic/stealthy, powered=true: visible/tracking
	dispatch(FCWReducer.action_launch_weapon(entity_id, target_entity_id, weapon_power, powered))

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

	# Check for entity changes
	_emit_entity_signals(old_state, new_state)

func _emit_entity_signals(old_state: Dictionary, new_state: Dictionary) -> void:
	## Compare entity arrays and emit appropriate signals
	var old_entities = old_state.get("entities", [])
	var new_entities = new_state.get("entities", [])

	# Build lookup maps by entity ID
	var old_by_id: Dictionary = {}
	for entity in old_entities:
		old_by_id[entity.id] = entity

	var new_by_id: Dictionary = {}
	for entity in new_entities:
		new_by_id[entity.id] = entity

	# Check for new entities (spawned)
	for entity in new_entities:
		if not old_by_id.has(entity.id):
			entity_spawned.emit(entity)

	# Check for removed entities (destroyed) and state changes
	for entity in old_entities:
		if not new_by_id.has(entity.id):
			# Entity was removed - it was destroyed
			entity_destroyed.emit(entity)
		else:
			var new_entity = new_by_id[entity.id]
			# Check for arrival (was moving, now orbiting)
			var was_moving = entity.movement_state in [FCWTypes.MovementState.BURNING, FCWTypes.MovementState.COASTING]
			var now_orbiting = new_entity.movement_state == FCWTypes.MovementState.ORBITING
			if was_moving and now_orbiting:
				entity_arrived.emit(new_entity, new_entity.get("destination", -1))

	# Emit intercept events from tick_events
	var tick_events = new_state.get("tick_events", {})
	for intercept in tick_events.get("intercepts", []):
		var pursuer = old_by_id.get(intercept.pursuer_id, {})
		var target = old_by_id.get(intercept.target_id, {})
		if not pursuer.is_empty() and not target.is_empty():
			intercept_started.emit(pursuer, target)

	# Emit detection events from tick_events
	for detection in tick_events.get("detections", []):
		var detected_entity = new_by_id.get(detection.entity_id, {})
		if not detected_entity.is_empty():
			entity_detected.emit(detected_entity, true)

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

func get_fleets_in_transit() -> Array:
	return _state.get("fleets_in_transit", []).duplicate(true)

func get_lives_evacuated() -> int:
	return _state.lives_evacuated

func get_lives_lost() -> int:
	return _state.lives_lost

func get_herald_strength() -> int:
	return _state.herald_strength

func get_herald_target() -> int:
	return _state.herald_attack_target

func get_herald_current_zone() -> int:
	return _state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)

func get_herald_transit() -> Dictionary:
	return _state.get("herald_transit", {}).duplicate(true)

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
	return FCWReducer.calc_zone_defense(_state, zone_id)

func get_controlled_zones() -> Array:
	return FCWReducer.get_controlled_zones(_state)

func estimate_turns_until_earth() -> int:
	return FCWReducer.estimate_turns_until_earth_attack(_state)

func get_colony_ships_in_transit() -> Array:
	return _state.get("colony_ships_in_transit", []).duplicate(true)

func get_colony_ships_safe() -> int:
	return _state.get("colony_ships_safe", 0)

func get_lives_intercepted() -> int:
	return _state.get("lives_intercepted", 0)

# ============================================================================
# TIME SYSTEM GETTERS
# ============================================================================

func get_game_time() -> float:
	## Returns game time in HOURS (the base unit)
	return _state.get("game_time", 0.0)

func get_current_hour() -> int:
	## Returns hour of day (0-23)
	return FCWTime.get_hour_of_day(get_game_time())

func get_current_day() -> int:
	## Returns day of week (1-7)
	return FCWTime.get_day_of_week(get_game_time())

func get_current_week() -> int:
	## Returns week number (1-indexed)
	return FCWTime.get_week(get_game_time())

func get_formatted_time() -> String:
	## Returns formatted time string "WEEK X, DAY Y - HH:00"
	return FCWTime.format_time(get_game_time())

func get_prev_entity_positions() -> Dictionary:
	## Returns entity positions at start of current tick (for interpolation)
	return _state.get("prev_entity_positions", {}).duplicate()

func get_prev_zone_positions() -> Dictionary:
	## Returns zone positions at start of current tick (for interpolation)
	return _state.get("prev_zone_positions", {}).duplicate()

func get_interpolated_entity_position(entity_id: String, tick_progress: float) -> Vector2:
	## Get interpolated entity position between ticks
	var prev_pos = _state.get("prev_entity_positions", {}).get(entity_id, Vector2.ZERO)
	var entity = get_entity(entity_id)
	if entity.is_empty():
		return prev_pos
	return FCWTime.lerp_position(prev_pos, entity.position, tick_progress)

func get_interpolated_zone_position(zone_id: int, tick_progress: float) -> Vector2:
	## Get interpolated zone position between ticks
	var prev_pos = _state.get("prev_zone_positions", {}).get(zone_id, Vector2.ZERO)
	var curr_pos = FCWTypes.get_zone_position(zone_id, get_game_time())
	return FCWTime.lerp_position(prev_pos, curr_pos, tick_progress)

# ============================================================================
# NEW ENTITY SYSTEM GETTERS
# ============================================================================

func get_entities() -> Array:
	return _state.get("entities", []).duplicate(true)

func get_entity(entity_id: String) -> Dictionary:
	for entity in _state.get("entities", []):
		if entity.id == entity_id:
			return entity.duplicate(true)
	return {}

func get_entities_by_type(entity_type: int) -> Array:
	var result = []
	for entity in _state.get("entities", []):
		if entity.entity_type == entity_type:
			result.append(entity.duplicate(true))
	return result

func get_entities_by_faction(faction: int) -> Array:
	var result = []
	for entity in _state.get("entities", []):
		if entity.faction == faction:
			result.append(entity.duplicate(true))
	return result

func get_entities_at_zone(zone_id: int) -> Array:
	## Get all entities currently orbiting a zone
	var result = []
	for entity in _state.get("entities", []):
		if entity.movement_state == FCWTypes.MovementState.ORBITING:
			if entity.get("destination", -1) == zone_id or entity.get("origin", -1) == zone_id:
				result.append(entity.duplicate(true))
	return result

func get_entities_in_transit() -> Array:
	## Get all entities that are currently moving (burning or coasting)
	var result = []
	for entity in _state.get("entities", []):
		if entity.movement_state in [FCWTypes.MovementState.BURNING, FCWTypes.MovementState.COASTING]:
			result.append(entity.duplicate(true))
	return result

func get_zone_position(zone_id: int) -> Vector2:
	## Get current position of a zone based on game time
	return FCWTypes.get_zone_position(zone_id, get_game_time())

func get_all_zone_positions() -> Dictionary:
	## Get current positions of all zones
	return FCWTypes.get_all_zone_positions(get_game_time())

func get_herald_intel() -> Dictionary:
	return _state.get("herald_intel", {}).duplicate(true)
