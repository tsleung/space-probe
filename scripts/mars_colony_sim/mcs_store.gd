extends Node
class_name MCSStore

## MCS (Mars Colony Sim) Store - The ONLY place with side effects for colony simulation
## Wraps the pure reducer and provides:
## 1. Signal emissions for UI reactivity
## 2. Random number generation
## 3. Event selection and triggering
## 4. Persistence (save/load)
##
## Think of this like a Redux store - it holds state and dispatches actions

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const _MCSReducer = preload("res://scripts/mars_colony_sim/mcs_reducer.gd")
const _MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")
const _MCSEconomy = preload("res://scripts/mars_colony_sim/mcs_economy.gd")
const _MCSEvents = preload("res://scripts/mars_colony_sim/mcs_events.gd")

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

var _state: Dictionary = _MCSTypes.create_colony_state()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Ensure state is initialized immediately (not waiting for _ready)
	if _state.is_empty():
		_state = _MCSTypes.create_colony_state()

func _ready():
	pass  # State already initialized in _init

## Get current state (read-only copy)
func get_state() -> Dictionary:
	return _state.duplicate(true)

# ============================================================================
# STATE GETTERS
# ============================================================================

func get_year() -> int:
	return _state.get("current_year", 1)

func get_phase() -> int:
	return _state.get("colony_phase", 0)

func get_phase_name() -> String:
	return _MCSTypes.get_phase_name(_state.get("colony_phase", 0))

func get_colonists() -> Array:
	return _state.get("colonists", []).duplicate(true)

func get_colonist_count() -> int:
	return _state.get("colonists", []).size()

func get_workforce() -> Array:
	return _MCSPopulation.get_workforce(_state.get("colonists", []))

func get_buildings() -> Array:
	return _state.get("buildings", []).duplicate(true)

func get_operational_buildings() -> Array:
	var result: Array = []
	for building in _state.get("buildings", []):
		if building.get("is_operational", false):
			result.append(building.duplicate(true))
	return result

func get_resources() -> Dictionary:
	return _state.get("resources", {}).duplicate(true)

func get_resource(resource_type: int) -> float:
	var res_name = _MCSTypes.get_resource_name(resource_type)
	return _state.get("resources", {}).get(res_name, 0.0)

func get_political() -> Dictionary:
	return _state.get("politics", {}).duplicate(true)

func get_stability() -> float:
	return _state.get("politics", {}).get("stability", 75.0)

func get_active_events() -> Array:
	return _state.get("active_events", []).duplicate(true)

func get_colony_log() -> Array:
	return _state.get("mission_log", []).duplicate(true)

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
	_state = _MCSReducer.reduce(_state, action)

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

func start_new_colony(founder_count: int = 24) -> void:
	_rng.seed = int(Time.get_unix_time_from_system())

	# Create founding colonists
	var founders: Array = []
	for i in range(founder_count):
		var colonist = _MCSTypes.create_colonist()
		colonist.id = "founder_%03d" % i
		colonist.generation = _MCSTypes.Generation.EARTH_BORN
		colonist.age = 25 + _rng.randi_range(0, 15)
		colonist.life_stage = _MCSTypes.LifeStage.ADULT

		# Assign specialties (ensure coverage)
		var specialty_pool = [
			_MCSTypes.Specialty.ENGINEER,
			_MCSTypes.Specialty.SCIENTIST,
			_MCSTypes.Specialty.MEDIC,
			_MCSTypes.Specialty.FARMER,
			_MCSTypes.Specialty.PILOT,
			_MCSTypes.Specialty.ADMINISTRATOR
		]
		colonist.specialty = specialty_pool[i % specialty_pool.size()]

		# Generate name
		colonist.display_name = _generate_name(colonist, i)

		# Random traits
		var trait_pool = _MCSTypes.ColonistTrait.values()
		colonist.traits.append(trait_pool[_rng.randi() % trait_pool.size()])

		# Random faction leaning
		var faction_pool = _MCSTypes.Faction.values()
		colonist.faction = faction_pool[_rng.randi() % faction_pool.size()]

		founders.append(colonist)

	dispatch(_MCSReducer.action_start_new_colony(founders, _rng.seed))

func advance_year() -> void:
	if is_game_over():
		return

	# Generate random values for the year
	var random_count = _state.get("colonists", []).size() * 10 + 50
	dispatch_with_random(_MCSReducer.action_advance_year([]), random_count)

	# Check for events
	_check_yearly_events()

	# Check victory/loss conditions
	dispatch(_MCSReducer.action_check_victory())

func advance_week() -> void:
	"""Advance simulation by one week - more granular ticks for better feedback"""
	if is_game_over():
		return

	# Generate random values for the week
	var colonist_count = _state.get("colonists", []).size()
	var building_count = _state.get("buildings", []).size()
	var random_count = colonist_count * 6 + building_count + 30

	var old_year = _state.get("current_year", 1)
	dispatch_with_random(_MCSReducer.action_advance_week([]), random_count)
	var new_year = _state.get("current_year", 1)

	# If year changed (week 52 → week 1), do yearly events
	if new_year != old_year:
		year_advanced.emit(new_year)
		_check_yearly_events()
		dispatch(_MCSReducer.action_check_victory())

func get_week() -> int:
	return _state.get("current_week", 1)

func start_construction(building_type: int) -> bool:
	var old_count = _state.get("buildings", []).size()
	dispatch(_MCSReducer.action_start_construction(building_type))
	return _state.get("buildings", []).size() > old_count

func complete_construction(building_id: String) -> void:
	dispatch(_MCSReducer.action_complete_construction(building_id))

func demolish_building(building_id: String) -> void:
	dispatch(_MCSReducer.action_demolish_building(building_id))

func repair_building(building_id: String) -> void:
	dispatch(_MCSReducer.action_repair_building(building_id))

func assign_worker(colonist_id: String, building_id: String) -> void:
	dispatch(_MCSReducer.action_assign_worker(colonist_id, building_id))

func unassign_worker(colonist_id: String) -> void:
	dispatch(_MCSReducer.action_unassign_worker(colonist_id))

func auto_assign_workers() -> void:
	dispatch(_MCSReducer.action_auto_assign_workers())

func hold_election() -> void:
	dispatch_with_random(_MCSReducer.action_hold_election([]), 20)

func change_government(new_system: int) -> void:
	dispatch(_MCSReducer.action_change_government(new_system))

func hold_independence_vote() -> void:
	dispatch(_MCSReducer.action_hold_independence_vote(_rng.randf()))

func resolve_event(event_id: String, choice_index: int) -> void:
	dispatch(_MCSReducer.action_resolve_event_choice(event_id, choice_index, _rng.randf()))

func add_log(message: String, log_type: String = "info") -> void:
	dispatch(_MCSReducer.action_add_log(message, log_type))

# ============================================================================
# EVENT CHECKING (side effect: uses RNG)
# ============================================================================

func _check_yearly_events() -> void:
	# Get eligible events for this year
	var eligible = _MCSEvents.get_eligible_events(_state)

	if eligible.is_empty():
		return

	# Select events for this year (usually 1-2)
	var selected = _MCSEvents.select_yearly_events(
		eligible,
		_state,
		_rng.randf(),
		_rng.randf()
	)

	# Trigger each selected event
	for event in selected:
		dispatch(_MCSReducer.action_trigger_event(event))

# ============================================================================
# PROJECTIONS & CALCULATIONS (read-only)
# ============================================================================

func project_next_year() -> Dictionary:
	"""Preview what will happen next year (for planning UI)"""
	var buildings = _state.get("buildings", [])
	var colonists = _state.get("colonists", [])
	var resources = _state.get("resources", {})

	var production = _MCSEconomy.calc_yearly_production(buildings, colonists, resources)
	var consumption = _MCSEconomy.calc_yearly_consumption(colonists, buildings)

	var net: Dictionary = {}
	for key in production.keys():
		net[key] = production.get(key, 0) - consumption.get(key, 0)

	return {
		"production": production,
		"consumption": consumption,
		"net": net,
		"food_surplus_years": resources.get("food", 0.0) / maxf(1, consumption.get("food", 1)),
		"power_balance": _MCSEconomy.calc_power_balance(buildings, colonists),
		"housing_balance": _MCSEconomy.calc_housing_balance(buildings, colonists)
	}

func get_building_efficiency(building_id: String) -> float:
	var colonists = _state.get("colonists", [])
	for building in _state.get("buildings", []):
		if building.get("id", "") == building_id:
			return _MCSEconomy.calc_building_efficiency(building, colonists)
	return 0.0

func get_colonist_effectiveness(colonist_id: String) -> float:
	for colonist in _state.get("colonists", []):
		if colonist.get("id", "") == colonist_id:
			return _MCSPopulation.calc_effectiveness(colonist)
	return 0.0

func get_faction_breakdown() -> Dictionary:
	var counts: Dictionary = {}
	for faction in _MCSTypes.Faction.values():
		counts[faction] = 0

	for colonist in _state.get("colonists", []):
		var faction = colonist.get("faction", 0)
		counts[faction] = counts.get(faction, 0) + 1

	return counts

func get_generation_breakdown() -> Dictionary:
	var counts: Dictionary = {}
	for gen in _MCSTypes.Generation.values():
		counts[gen] = 0

	for colonist in _state.get("colonists", []):
		var generation = colonist.get("generation", 0)
		counts[generation] = counts.get(generation, 0) + 1

	return counts

# ============================================================================
# SIGNAL EMISSION HELPERS
# ============================================================================

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, action: Dictionary) -> void:
	var old_year = old_state.get("current_year", 1)
	var new_year = new_state.get("current_year", 1)
	if old_year != new_year:
		year_advanced.emit(new_year)

	var old_phase = old_state.get("colony_phase", 0)
	var new_phase = new_state.get("colony_phase", 0)
	if old_phase != new_phase:
		phase_changed.emit(new_phase)

	var old_colonists = old_state.get("colonists", [])
	var new_colonists = new_state.get("colonists", [])
	if old_colonists.size() != new_colonists.size():
		population_changed.emit(new_colonists.size())

	var old_resources = old_state.get("resources", {})
	var new_resources = new_state.get("resources", {})
	if old_resources != new_resources:
		resources_changed.emit(new_resources)

	var old_stability = old_state.get("politics", {}).get("stability", 75.0)
	var new_stability = new_state.get("politics", {}).get("stability", 75.0)
	if old_stability != new_stability:
		stability_changed.emit(new_stability)

	var old_log = old_state.get("mission_log", [])
	var new_log = new_state.get("mission_log", [])
	if new_log.size() > old_log.size():
		var new_entry = new_log[-1]
		log_entry_added.emit(new_entry)

	var old_buildings = old_state.get("buildings", [])
	var new_buildings = new_state.get("buildings", [])

	# Action-specific signals
	match action.get("type", -1):
		_MCSReducer.ActionType.START_CONSTRUCTION:
			if new_buildings.size() > old_buildings.size():
				building_constructed.emit(new_buildings[-1])

		_MCSReducer.ActionType.DEMOLISH_BUILDING:
			for building in old_buildings:
				var found = false
				for b in new_buildings:
					if b.get("id", "") == building.get("id", ""):
						found = true
						break
				if not found:
					building_demolished.emit(building)

		_MCSReducer.ActionType.TRIGGER_EVENT:
			event_triggered.emit(action.get("event", {}))

		_MCSReducer.ActionType.RESOLVE_EVENT_CHOICE:
			var outcome = ""
			var old_resolved = old_state.get("resolved_events", [])
			var new_resolved = new_state.get("resolved_events", [])
			if new_resolved.size() > old_resolved.size():
				outcome = new_resolved[-1].get("outcome", "")
			event_resolved.emit(action.get("event_id", ""), action.get("choice_index", 0), outcome)

		_MCSReducer.ActionType.HOLD_ELECTION:
			election_held.emit(new_state.get("politics", {}))

		_MCSReducer.ActionType.CHECK_VICTORY_CONDITIONS:
			if new_state.get("game_over", false) and not old_state.get("game_over", false):
				game_ended.emit(new_state.get("victory", false), new_state.get("end_reason", ""))

		_MCSReducer.ActionType.END_COLONY:
			game_ended.emit(action.get("is_victory", false), action.get("reason", ""))

	# Check for births and deaths during ADVANCE_YEAR
	if action.get("type", -1) == _MCSReducer.ActionType.ADVANCE_YEAR:
		# Find new colonists (births)
		var old_ids = {}
		for c in old_colonists:
			old_ids[c.get("id", "")] = true

		for colonist in new_colonists:
			if not old_ids.has(colonist.get("id", "")):
				colonist_born.emit(colonist)

		# Find removed colonists (deaths)
		var new_ids = {}
		for c in new_colonists:
			new_ids[c.get("id", "")] = true

		for colonist in old_colonists:
			if not new_ids.has(colonist.get("id", "")):
				# Find death cause from log
				var cause = "unknown"
				for entry in new_log:
					if colonist.get("display_name", "") in entry.get("message", "") and entry.get("log_type", "") == "death":
						cause = entry.get("message", "unknown")
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
	var current_year = _state.get("current_year", 1)
	for i in range(count):
		var colonist = _MCSTypes.create_colonist()
		colonist["id"] = "debug_%d_%03d" % [current_year, i]
		colonist.generation = _MCSTypes.Generation.FIRST_GEN
		colonist.age = 20 + _rng.randi_range(0, 20)
		colonist.life_stage = _MCSTypes.LifeStage.ADULT
		colonist.display_name = _generate_name(colonist, i)
		dispatch(_MCSReducer.action_add_colonist(colonist))

func debug_add_resources(amount: float) -> void:
	for resource_type in _MCSTypes.ResourceType.values():
		dispatch(_MCSReducer.action_update_resource(resource_type, amount))

func debug_trigger_event(event_id: String) -> void:
	var all_events = _MCSEvents.get_all_events()
	for event in all_events:
		if event.id == event_id:
			dispatch(_MCSReducer.action_trigger_event(event))
			return
