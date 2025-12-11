extends Node
class_name ColonySimStore

## Colony Sim Store - The ONLY place with side effects for colony simulation
## Wraps the pure reducer and provides:
## 1. Signal emissions for UI reactivity
## 2. Random number generation
## 3. Event selection and triggering
## 4. Persistence (save/load)
##
## Think of this like a Redux store - it holds state and dispatches actions

# ============================================================================
# SIGNALS (for UI reactivity)
# ============================================================================

signal state_changed(new_state: Dictionary)
signal year_advanced(year: int)
signal phase_changed(phase: int)
signal population_changed(count: int)
signal resources_changed(resources: Dictionary)
signal building_constructed(building: Dictionary)
signal building_demolished(building: Dictionary)
signal colonist_born(colonist: Dictionary)
signal colonist_died(colonist: Dictionary, cause: String)
signal event_triggered(event: Dictionary)
signal event_resolved(event_id: String, choice: int, outcome: String)
signal election_held(result: Dictionary)
signal stability_changed(stability: float)
signal log_entry_added(entry: Dictionary)
signal game_ended(is_victory: bool, reason: String)

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_state = ColonySimTypes.create_colony_state()

## Get current state (read-only copy)
func get_state() -> Dictionary:
	return _state.duplicate(true)

# ============================================================================
# STATE GETTERS
# ============================================================================

func get_year() -> int:
	return _state.current_year

func get_phase() -> int:
	return _state.colony_phase

func get_phase_name() -> String:
	return ColonySimTypes.get_phase_name(_state.colony_phase)

func get_colonists() -> Array:
	return _state.colonists.duplicate(true)

func get_colonist_count() -> int:
	return _state.colonists.size()

func get_workforce() -> Array:
	return ColonySimPopulation.get_workforce(_state.colonists)

func get_buildings() -> Array:
	return _state.buildings.duplicate(true)

func get_operational_buildings() -> Array:
	var result: Array = []
	for building in _state.buildings:
		if building.is_operational:
			result.append(building.duplicate(true))
	return result

func get_resources() -> Dictionary:
	return _state.resources.duplicate(true)

func get_resource(resource_type: int) -> float:
	var name = ColonySimTypes.get_resource_name(resource_type)
	return _state.resources.get(name, 0.0)

func get_political() -> Dictionary:
	return _state.politics.duplicate(true)

func get_stability() -> float:
	return _state.politics.stability

func get_active_events() -> Array:
	return _state.active_events.duplicate(true)

func get_colony_log() -> Array:
	return _state.mission_log.duplicate(true)

func is_game_over() -> bool:
	return _state.get("game_over", false)

func is_victory() -> bool:
	return _state.get("victory", false)

func is_independent() -> bool:
	return _state.get("is_independent", false)

# ============================================================================
# DISPATCH (the only way to modify state)
# ============================================================================

func dispatch(action: Dictionary) -> void:
	var old_state = _state
	_state = ColonySimReducer.reduce(_state, action)

	# Emit appropriate signals based on what changed
	_emit_change_signals(old_state, _state, action)
	state_changed.emit(_state)

## Helper to dispatch with auto-generated random values
func dispatch_with_random(action: Dictionary, random_count: int = 50) -> void:
	var random_values: Array = []
	for i in range(random_count):
		random_values.append(_rng.randf())

	action["random_values"] = random_values
	dispatch(action)

# ============================================================================
# HIGH-LEVEL ACTIONS (convenience methods that dispatch)
# ============================================================================

func start_new_colony(founder_count: int = 12) -> void:
	_rng.seed = int(Time.get_unix_time_from_system())

	# Create founding colonists
	var founders: Array = []
	for i in range(founder_count):
		var colonist = ColonySimTypes.create_colonist()
		colonist.id = "founder_%03d" % i
		colonist.generation = ColonySimTypes.Generation.EARTH_BORN
		colonist.age = 25 + _rng.randi_range(0, 15)
		colonist.life_stage = ColonySimTypes.LifeStage.ADULT

		# Assign specialties (ensure coverage)
		var specialty_pool = [
			ColonySimTypes.Specialty.ENGINEER,
			ColonySimTypes.Specialty.SCIENTIST,
			ColonySimTypes.Specialty.MEDIC,
			ColonySimTypes.Specialty.FARMER,
			ColonySimTypes.Specialty.PILOT,
			ColonySimTypes.Specialty.ADMINISTRATOR
		]
		colonist.specialty = specialty_pool[i % specialty_pool.size()]

		# Generate name
		colonist.display_name = _generate_name(colonist, i)

		# Random traits
		var trait_pool = ColonySimTypes.ColonistTrait.values()
		colonist.traits.append(trait_pool[_rng.randi() % trait_pool.size()])

		# Random faction leaning
		var faction_pool = ColonySimTypes.Faction.values()
		colonist.faction = faction_pool[_rng.randi() % faction_pool.size()]

		founders.append(colonist)

	dispatch(ColonySimReducer.action_start_new_colony(founders, _rng.seed))

func advance_year() -> void:
	if is_game_over():
		return

	# Generate random values for the year
	var random_count = _state.colonists.size() * 10 + 50
	dispatch_with_random(ColonySimReducer.action_advance_year([]), random_count)

	# Check for events
	_check_yearly_events()

	# Check victory/loss conditions
	dispatch(ColonySimReducer.action_check_victory())

func start_construction(building_type: int) -> bool:
	var old_count = _state.buildings.size()
	dispatch(ColonySimReducer.action_start_construction(building_type))
	return _state.buildings.size() > old_count

func complete_construction(building_id: String) -> void:
	dispatch(ColonySimReducer.action_complete_construction(building_id))

func demolish_building(building_id: String) -> void:
	dispatch(ColonySimReducer.action_demolish_building(building_id))

func repair_building(building_id: String) -> void:
	dispatch(ColonySimReducer.action_repair_building(building_id))

func assign_worker(colonist_id: String, building_id: String) -> void:
	dispatch(ColonySimReducer.action_assign_worker(colonist_id, building_id))

func unassign_worker(colonist_id: String) -> void:
	dispatch(ColonySimReducer.action_unassign_worker(colonist_id))

func auto_assign_workers() -> void:
	dispatch(ColonySimReducer.action_auto_assign_workers())

func hold_election() -> void:
	dispatch_with_random(ColonySimReducer.action_hold_election([]), 20)

func change_government(new_system: int) -> void:
	dispatch(ColonySimReducer.action_change_government(new_system))

func hold_independence_vote() -> void:
	dispatch(ColonySimReducer.action_hold_independence_vote(_rng.randf()))

func resolve_event(event_id: String, choice_index: int) -> void:
	dispatch(ColonySimReducer.action_resolve_event_choice(event_id, choice_index, _rng.randf()))

func add_log(message: String, log_type: String = "info") -> void:
	dispatch(ColonySimReducer.action_add_log(message, log_type))

# ============================================================================
# EVENT CHECKING (side effect: uses RNG)
# ============================================================================

func _check_yearly_events() -> void:
	# Get eligible events for this year
	var eligible = ColonySimEvents.get_eligible_events(_state)

	if eligible.is_empty():
		return

	# Select events for this year (usually 1-2)
	var selected = ColonySimEvents.select_yearly_events(
		eligible,
		_state,
		_rng.randf(),
		_rng.randf()
	)

	# Trigger each selected event
	for event in selected:
		dispatch(ColonySimReducer.action_trigger_event(event))

# ============================================================================
# PROJECTIONS & CALCULATIONS (read-only)
# ============================================================================

func project_next_year() -> Dictionary:
	"""Preview what will happen next year (for planning UI)"""
	var production = ColonySimEconomy.calc_yearly_production(
		_state.buildings,
		_state.colonists,
		_state.resources
	)
	var consumption = ColonySimEconomy.calc_yearly_consumption(
		_state.colonists,
		_state.buildings
	)

	var net: Dictionary = {}
	for key in production.keys():
		net[key] = production.get(key, 0) - consumption.get(key, 0)

	return {
		"production": production,
		"consumption": consumption,
		"net": net,
		"food_surplus_years": _state.resources.food / maxf(1, consumption.get("food", 1)),
		"power_balance": ColonySimEconomy.calc_power_balance(_state.buildings, _state.colonists),
		"housing_balance": ColonySimEconomy.calc_housing_balance(_state.buildings, _state.colonists)
	}

func get_building_efficiency(building_id: String) -> float:
	for building in _state.buildings:
		if building.id == building_id:
			return ColonySimEconomy.calc_building_efficiency(building, _state.colonists)
	return 0.0

func get_colonist_effectiveness(colonist_id: String) -> float:
	for colonist in _state.colonists:
		if colonist.id == colonist_id:
			return ColonySimPopulation.calc_effectiveness(colonist)
	return 0.0

func get_faction_breakdown() -> Dictionary:
	var counts: Dictionary = {}
	for faction in ColonySimTypes.Faction.values():
		counts[faction] = 0

	for colonist in _state.colonists:
		counts[colonist.faction] = counts.get(colonist.faction, 0) + 1

	return counts

func get_generation_breakdown() -> Dictionary:
	var counts: Dictionary = {}
	for gen in ColonySimTypes.Generation.values():
		counts[gen] = 0

	for colonist in _state.colonists:
		counts[colonist.generation] = counts.get(colonist.generation, 0) + 1

	return counts

# ============================================================================
# SIGNAL EMISSION HELPERS
# ============================================================================

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, action: Dictionary) -> void:
	if old_state.current_year != new_state.current_year:
		year_advanced.emit(new_state.current_year)

	if old_state.colony_phase != new_state.colony_phase:
		phase_changed.emit(new_state.colony_phase)

	if old_state.colonists.size() != new_state.colonists.size():
		population_changed.emit(new_state.colonists.size())

	if old_state.resources != new_state.resources:
		resources_changed.emit(new_state.resources)

	if old_state.politics.stability != new_state.politics.stability:
		stability_changed.emit(new_state.politics.stability)

	if new_state.mission_log.size() > old_state.mission_log.size():
		var new_entry = new_state.mission_log[-1]
		log_entry_added.emit(new_entry)

	# Action-specific signals
	match action.type:
		ColonySimReducer.ActionType.START_CONSTRUCTION:
			if new_state.buildings.size() > old_state.buildings.size():
				building_constructed.emit(new_state.buildings[-1])

		ColonySimReducer.ActionType.DEMOLISH_BUILDING:
			for building in old_state.buildings:
				var found = false
				for b in new_state.buildings:
					if b.id == building.id:
						found = true
						break
				if not found:
					building_demolished.emit(building)

		ColonySimReducer.ActionType.TRIGGER_EVENT:
			event_triggered.emit(action.event)

		ColonySimReducer.ActionType.RESOLVE_EVENT_CHOICE:
			var outcome = ""
			if new_state.resolved_events.size() > old_state.resolved_events.size():
				outcome = new_state.resolved_events[-1].get("outcome", "")
			event_resolved.emit(action.event_id, action.choice_index, outcome)

		ColonySimReducer.ActionType.HOLD_ELECTION:
			election_held.emit(new_state.politics)

		ColonySimReducer.ActionType.CHECK_VICTORY_CONDITIONS:
			if new_state.get("game_over", false) and not old_state.get("game_over", false):
				game_ended.emit(new_state.get("victory", false), new_state.get("end_reason", ""))

		ColonySimReducer.ActionType.END_COLONY:
			game_ended.emit(action.is_victory, action.reason)

	# Check for births and deaths during ADVANCE_YEAR
	if action.type == ColonySimReducer.ActionType.ADVANCE_YEAR:
		# Find new colonists (births)
		var old_ids = {}
		for c in old_state.colonists:
			old_ids[c.id] = true

		for colonist in new_state.colonists:
			if not old_ids.has(colonist.id):
				colonist_born.emit(colonist)

		# Find removed colonists (deaths)
		var new_ids = {}
		for c in new_state.colonists:
			new_ids[c.id] = true

		for colonist in old_state.colonists:
			if not new_ids.has(colonist.id):
				# Find death cause from log
				var cause = "unknown"
				for entry in new_state.colony_log:
					if colonist.display_name in entry.get("message", "") and entry.log_type == "death":
						cause = entry.message
						break
				colonist_died.emit(colonist, cause)

# ============================================================================
# NAME GENERATION
# ============================================================================

const FIRST_NAMES_MALE = ["James", "Wei", "Mohammed", "Hiroshi", "Viktor", "Carlos", "Raj", "Ahmed", "Yuki", "Marcus", "Chen", "Ivan", "Diego", "Kofi", "Sven"]
const FIRST_NAMES_FEMALE = ["Sarah", "Mei", "Fatima", "Yuki", "Elena", "Maria", "Priya", "Aisha", "Sakura", "Julia", "Lin", "Olga", "Sofia", "Ama", "Ingrid"]
const LAST_NAMES = ["Chen", "Rodriguez", "Nakamura", "Okonkwo", "Singh", "Mueller", "Santos", "Kim", "Ali", "Petrov", "Johansson", "Tanaka", "Diaz", "Ibrahim", "Kowalski"]

func _generate_name(colonist: Dictionary, index: int) -> String:
	var first_names = FIRST_NAMES_MALE if index % 2 == 0 else FIRST_NAMES_FEMALE
	var first = first_names[_rng.randi() % first_names.size()]
	var last = LAST_NAMES[_rng.randi() % LAST_NAMES.size()]
	return "%s %s" % [first, last]

# ============================================================================
# PERSISTENCE (side effects: file I/O)
# ============================================================================

func save_colony(slot: int = 0) -> bool:
	var save_path = "user://colony_save_%d.json" % slot
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return false

	var save_data = _state.duplicate(true)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_colony(slot: int = 0) -> bool:
	var save_path = "user://colony_save_%d.json" % slot
	if not FileAccess.file_exists(save_path):
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		return false

	_state = json.data
	state_changed.emit(_state)
	return true

func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists("user://colony_save_%d.json" % slot)

func delete_save(slot: int = 0) -> bool:
	var save_path = "user://colony_save_%d.json" % slot
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false

# ============================================================================
# DEBUG HELPERS
# ============================================================================

func debug_add_colonists(count: int) -> void:
	for i in range(count):
		var colonist = ColonySimTypes.create_colonist()
		colonist.id = "debug_%d_%03d" % [_state.year, i]
		colonist.generation = ColonySimTypes.Generation.FIRST
		colonist.age = 20 + _rng.randi_range(0, 20)
		colonist.life_stage = ColonySimTypes.LifeStage.ADULT
		colonist.display_name = _generate_name(colonist, i)
		dispatch(ColonySimReducer.action_add_colonist(colonist))

func debug_add_resources(amount: float) -> void:
	for resource_type in ColonySimTypes.ResourceType.values():
		dispatch(ColonySimReducer.action_update_resource(resource_type, amount))

func debug_trigger_event(event_id: String) -> void:
	var all_events = ColonySimEvents.get_all_events()
	for event in all_events:
		if event.id == event_id:
			dispatch(ColonySimReducer.action_trigger_event(event))
			return
