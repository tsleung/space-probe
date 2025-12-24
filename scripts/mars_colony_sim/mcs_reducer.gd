class_name MCSReducer
extends RefCounted

## Redux-style reducer for MCS (Mars Colony Sim) state
## All functions are pure: (state, action) -> new_state
## No side effects, fully deterministic with provided random values

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const _MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")
const _MCSEconomy = preload("res://scripts/mars_colony_sim/mcs_economy.gd")
const _MCSPolitics = preload("res://scripts/mars_colony_sim/mcs_politics.gd")
const _MCSEvents = preload("res://scripts/mars_colony_sim/mcs_events.gd")

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	# Game flow
	START_NEW_COLONY,
	ADVANCE_YEAR,
	ADVANCE_WEEK,  # New: granular weekly tick

	# Population
	ADD_COLONIST,
	REMOVE_COLONIST,
	UPDATE_COLONIST,

	# Buildings
	START_CONSTRUCTION,
	COMPLETE_CONSTRUCTION,
	DEMOLISH_BUILDING,
	REPAIR_BUILDING,
	UPGRADE_BUILDING,
	PROGRESS_UPGRADES,  # Tick upgrade progress each year

	# Resources
	UPDATE_RESOURCE,
	APPLY_PRODUCTION,
	APPLY_CONSUMPTION,

	# Workers
	ASSIGN_WORKER,
	UNASSIGN_WORKER,
	AUTO_ASSIGN_WORKERS,

	# Politics
	HOLD_ELECTION,
	CHANGE_GOVERNMENT,
	UPDATE_FACTION_STANDINGS,
	HOLD_INDEPENDENCE_VOTE,

	# Events
	TRIGGER_EVENT,
	RESOLVE_EVENT_CHOICE,

	# Logging
	ADD_COLONY_LOG,

	# Win/Loss
	CHECK_VICTORY_CONDITIONS,
	END_COLONY
}

# ============================================================================
# MAIN REDUCER
# ============================================================================

## Main reducer function - dispatches to specific handlers
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.START_NEW_COLONY:
			return _reduce_start_new_colony(state, action)
		ActionType.ADVANCE_YEAR:
			return _reduce_advance_year(state, action)
		ActionType.ADVANCE_WEEK:
			return _reduce_advance_week(state, action)
		ActionType.ADD_COLONIST:
			return _reduce_add_colonist(state, action)
		ActionType.REMOVE_COLONIST:
			return _reduce_remove_colonist(state, action)
		ActionType.UPDATE_COLONIST:
			return _reduce_update_colonist(state, action)
		ActionType.START_CONSTRUCTION:
			return _reduce_start_construction(state, action)
		ActionType.COMPLETE_CONSTRUCTION:
			return _reduce_complete_construction(state, action)
		ActionType.DEMOLISH_BUILDING:
			return _reduce_demolish_building(state, action)
		ActionType.REPAIR_BUILDING:
			return _reduce_repair_building(state, action)
		ActionType.UPGRADE_BUILDING:
			return _reduce_upgrade_building(state, action)
		ActionType.PROGRESS_UPGRADES:
			return _reduce_progress_upgrades(state, action)
		ActionType.UPDATE_RESOURCE:
			return _reduce_update_resource(state, action)
		ActionType.APPLY_PRODUCTION:
			return _reduce_apply_production(state, action)
		ActionType.APPLY_CONSUMPTION:
			return _reduce_apply_consumption(state, action)
		ActionType.ASSIGN_WORKER:
			return _reduce_assign_worker(state, action)
		ActionType.UNASSIGN_WORKER:
			return _reduce_unassign_worker(state, action)
		ActionType.AUTO_ASSIGN_WORKERS:
			return _reduce_auto_assign_workers(state, action)
		ActionType.HOLD_ELECTION:
			return _reduce_hold_election(state, action)
		ActionType.CHANGE_GOVERNMENT:
			return _reduce_change_government(state, action)
		ActionType.UPDATE_FACTION_STANDINGS:
			return _reduce_update_faction_standings(state, action)
		ActionType.HOLD_INDEPENDENCE_VOTE:
			return _reduce_hold_independence_vote(state, action)
		ActionType.TRIGGER_EVENT:
			return _reduce_trigger_event(state, action)
		ActionType.RESOLVE_EVENT_CHOICE:
			return _reduce_resolve_event_choice(state, action)
		ActionType.ADD_COLONY_LOG:
			return _reduce_add_log(state, action)
		ActionType.CHECK_VICTORY_CONDITIONS:
			return _reduce_check_victory(state, action)
		ActionType.END_COLONY:
			return _reduce_end_colony(state, action)
		_:
			return state

# ============================================================================
# ACTION CREATORS (pure functions that create action dictionaries)
# ============================================================================

static func action_start_new_colony(founders: Array, seed_value: int = 0, balance: Dictionary = {}) -> Dictionary:
	return {
		"type": ActionType.START_NEW_COLONY,
		"founders": founders,
		"seed": seed_value if seed_value > 0 else int(Time.get_unix_time_from_system()),
		"balance": balance
	}

static func action_advance_year(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.ADVANCE_YEAR,
		"random_values": random_values
	}

static func action_advance_week(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.ADVANCE_WEEK,
		"random_values": random_values
	}

static func action_add_colonist(colonist: Dictionary) -> Dictionary:
	return {
		"type": ActionType.ADD_COLONIST,
		"colonist": colonist
	}

static func action_remove_colonist(colonist_id: String, reason: String = "death") -> Dictionary:
	return {
		"type": ActionType.REMOVE_COLONIST,
		"colonist_id": colonist_id,
		"reason": reason
	}

static func action_update_colonist(colonist_id: String, updates: Dictionary) -> Dictionary:
	return {
		"type": ActionType.UPDATE_COLONIST,
		"colonist_id": colonist_id,
		"updates": updates
	}

static func action_start_construction(building_type: int, priority: int = 1) -> Dictionary:
	return {
		"type": ActionType.START_CONSTRUCTION,
		"building_type": building_type,
		"priority": priority
	}

static func action_complete_construction(building_id: String) -> Dictionary:
	return {
		"type": ActionType.COMPLETE_CONSTRUCTION,
		"building_id": building_id
	}

static func action_demolish_building(building_id: String) -> Dictionary:
	return {
		"type": ActionType.DEMOLISH_BUILDING,
		"building_id": building_id
	}

static func action_repair_building(building_id: String) -> Dictionary:
	return {
		"type": ActionType.REPAIR_BUILDING,
		"building_id": building_id
	}

static func action_upgrade_building(building_id: String) -> Dictionary:
	return {
		"type": ActionType.UPGRADE_BUILDING,
		"building_id": building_id
	}

static func action_progress_upgrades() -> Dictionary:
	return {
		"type": ActionType.PROGRESS_UPGRADES
	}

static func action_update_resource(resource_type: int, delta: float) -> Dictionary:
	return {
		"type": ActionType.UPDATE_RESOURCE,
		"resource_type": resource_type,
		"delta": delta
	}

static func action_apply_production(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.APPLY_PRODUCTION,
		"random_values": random_values
	}

static func action_apply_consumption() -> Dictionary:
	return {
		"type": ActionType.APPLY_CONSUMPTION
	}

static func action_assign_worker(colonist_id: String, building_id: String) -> Dictionary:
	return {
		"type": ActionType.ASSIGN_WORKER,
		"colonist_id": colonist_id,
		"building_id": building_id
	}

static func action_unassign_worker(colonist_id: String) -> Dictionary:
	return {
		"type": ActionType.UNASSIGN_WORKER,
		"colonist_id": colonist_id
	}

static func action_auto_assign_workers() -> Dictionary:
	return {
		"type": ActionType.AUTO_ASSIGN_WORKERS
	}

static func action_hold_election(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.HOLD_ELECTION,
		"random_values": random_values
	}

static func action_change_government(new_system: int) -> Dictionary:
	return {
		"type": ActionType.CHANGE_GOVERNMENT,
		"new_system": new_system
	}

static func action_update_faction_standings() -> Dictionary:
	return {
		"type": ActionType.UPDATE_FACTION_STANDINGS
	}

static func action_hold_independence_vote(random_value: float) -> Dictionary:
	return {
		"type": ActionType.HOLD_INDEPENDENCE_VOTE,
		"random_value": random_value
	}

static func action_trigger_event(event: Dictionary) -> Dictionary:
	return {
		"type": ActionType.TRIGGER_EVENT,
		"event": event
	}

static func action_resolve_event_choice(event_id: String, choice_index: int, random_value: float) -> Dictionary:
	return {
		"type": ActionType.RESOLVE_EVENT_CHOICE,
		"event_id": event_id,
		"choice_index": choice_index,
		"random_value": random_value
	}

static func action_add_log(message: String, log_type: String = "info", year: int = -1) -> Dictionary:
	return {
		"type": ActionType.ADD_COLONY_LOG,
		"message": message,
		"log_type": log_type,
		"year": year
	}

static func action_check_victory() -> Dictionary:
	return {
		"type": ActionType.CHECK_VICTORY_CONDITIONS
	}

static func action_end_colony(reason: String, is_victory: bool) -> Dictionary:
	return {
		"type": ActionType.END_COLONY,
		"reason": reason,
		"is_victory": is_victory
	}

# ============================================================================
# REDUCER IMPLEMENTATIONS (all pure)
# ============================================================================

static func _reduce_start_new_colony(_state: Dictionary, action: Dictionary) -> Dictionary:
	var new_state = _MCSTypes.create_colony_state()
	new_state.random_seed = action.seed
	new_state.colony_phase = _MCSTypes.ColonyPhase.ACT_1_FOUNDERS
	new_state.current_year = 1

	# Store balance configuration for use by economy functions
	var balance = action.get("balance", {})
	new_state["balance"] = balance

	# Add founders
	for founder in action.founders:
		new_state.colonists.append(founder)

	# =========================================================================
	# EPIC STARTING BUILDINGS - More for faster visual progression!
	# =========================================================================

	# 4 Hab Pods for housing (capacity comes from BUILDING_TIER_STATS: T1 = 4 each)
	for i in range(4):
		var hab = _MCSTypes.create_building({
			"type": _MCSTypes.BuildingType.HAB_POD,
			"id": "hab_%03d" % (i + 1),
			"is_operational": true,
			"construction_progress": 1.0,
			"constructed_year": 1  # Enables upgrades from year 2+
		})
		new_state.buildings.append(hab)

	# 3 Greenhouses for food
	for i in range(3):
		var farm = _MCSTypes.create_building({
			"type": _MCSTypes.BuildingType.GREENHOUSE,
			"id": "farm_%03d" % (i + 1),
			"is_operational": true,
			"construction_progress": 1.0,
			"constructed_year": 1
		})
		new_state.buildings.append(farm)

	# 4 Solar Arrays for power
	for i in range(4):
		var power = _MCSTypes.create_building({
			"type": _MCSTypes.BuildingType.SOLAR_ARRAY,
			"id": "solar_%03d" % (i + 1),
			"is_operational": true,
			"construction_progress": 1.0,
			"constructed_year": 1
		})
		new_state.buildings.append(power)

	# 2 Water Extractors
	for i in range(2):
		var water = _MCSTypes.create_building({
			"type": _MCSTypes.BuildingType.WATER_EXTRACTOR,
			"id": "water_%03d" % (i + 1),
			"is_operational": true,
			"construction_progress": 1.0,
			"constructed_year": 1
		})
		new_state.buildings.append(water)

	# 1 Oxygenator for life support
	var oxygenator = _MCSTypes.create_building({
		"type": _MCSTypes.BuildingType.OXYGENATOR,
		"id": "oxy_001",
		"is_operational": true,
		"construction_progress": 1.0,
		"constructed_year": 1
	})
	new_state.buildings.append(oxygenator)

	# 1 Workshop for production
	var workshop = _MCSTypes.create_building({
		"type": _MCSTypes.BuildingType.WORKSHOP,
		"id": "workshop_001",
		"is_operational": true,
		"construction_progress": 1.0,
		"constructed_year": 1
	})
	new_state.buildings.append(workshop)

	# 1 Medical Bay
	var medical = _MCSTypes.create_building({
		"type": _MCSTypes.BuildingType.MEDICAL_BAY,
		"id": "medical_001",
		"is_operational": true,
		"construction_progress": 1.0,
		"constructed_year": 1
	})
	new_state.buildings.append(medical)

	# =========================================================================
	# STARTING RESOURCES - Read from balance.json with difficulty multiplier
	# =========================================================================
	var starting = balance.get("starting_conditions", {}).get("starting_resources", {})
	var difficulty = balance.get("difficulty", {})
	var resource_mult = difficulty.get("starting_resource_multiplier", 1.0)

	new_state.resources.food = starting.get("food", 10000.0) * resource_mult
	new_state.resources.water = starting.get("water", 5000.0) * resource_mult
	new_state.resources.oxygen = starting.get("oxygen", 2500.0) * resource_mult
	new_state.resources.fuel = starting.get("fuel", 800.0) * resource_mult
	new_state.resources.building_materials = starting.get("building_materials", 3000.0) * resource_mult
	new_state.resources.machine_parts = starting.get("machine_parts", 800.0) * resource_mult
	new_state.resources.medicine = starting.get("medicine", 200.0) * resource_mult

	# Initialize log
	new_state.mission_log = [{
		"year": 1,
		"message": "Colony founded on Mars. %d pioneers begin humanity's greatest adventure." % action.founders.size(),
		"log_type": "milestone"
	}]

	return new_state

static func _reduce_advance_year(state: Dictionary, action: Dictionary) -> Dictionary:
	var current_year = state.get("current_year", 1)
	var new_year = current_year + 1
	var updates: Dictionary = {"current_year": new_year}
	var new_log = state.get("mission_log", []).duplicate()
	var rand_idx = 0

	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var buildings = state.get("buildings", [])
	var random_values = action.get("random_values", [])

	# === POPULATION PHASE ===
	var pop_result = _MCSPopulation.advance_year(
		colonists,
		new_year,
		resources,
		buildings,
		random_values.slice(rand_idx, rand_idx + colonists.size() * 5)
	)
	rand_idx += colonists.size() * 5

	updates["colonists"] = pop_result.colonists

	# Log births (natural)
	for birth in pop_result.births:
		new_log.append({
			"year": new_year,
			"message": "%s was born to the colony!" % birth.display_name,
			"log_type": "birth"
		})

	# Log deaths
	for death in pop_result.deaths:
		new_log.append({
			"year": new_year,
			"message": "%s has passed away. %s" % [death.name, death.cause],
			"log_type": "death"
		})

	# Log coming of age
	for adult in pop_result.new_adults:
		new_log.append({
			"year": new_year,
			"message": "%s has come of age and joined the workforce." % adult.display_name,
			"log_type": "milestone"
		})

	# === ARTIFICIAL BIRTHS (Colony Gestation Program) ===
	var birth_rand_values = random_values.slice(rand_idx, rand_idx + 50)
	rand_idx += 50
	var artificial_birth_result = _MCSPopulation.calculate_artificial_births(
		updates["colonists"],
		buildings,
		resources,
		new_year,
		birth_rand_values
	)

	# Add artificial births to colonists
	if artificial_birth_result.births.size() > 0:
		updates["colonists"] = updates["colonists"] + artificial_birth_result.births
		# Consume medicine for births
		var medicine_used = artificial_birth_result.medicine_consumed
		var updated_resources = resources.duplicate(true)
		updated_resources["medicine"] = maxf(0, updated_resources.get("medicine", 0) - medicine_used)
		resources = updated_resources

		# Log artificial births
		for birth in artificial_birth_result.births:
			new_log.append({
				"year": new_year,
				"message": "%s was born via colony gestation program!" % birth.get("display_name", "Baby"),
				"log_type": "birth"
			})

	# === IMMIGRATION (Starport/Space Station) ===
	var immigration_rand_values = random_values.slice(rand_idx, rand_idx + 100)
	rand_idx += 100
	var immigration_result = _MCSPopulation.calculate_immigration(
		buildings,
		resources,
		new_year,
		immigration_rand_values
	)

	# Add immigrants to colonists
	if immigration_result.immigrants.size() > 0:
		updates["colonists"] = updates["colonists"] + immigration_result.immigrants

		# Log immigration batch (summarize if many)
		var immigrant_count = immigration_result.immigrants.size()
		if immigrant_count == 1:
			var first_immigrant = immigration_result.immigrants[0]
			new_log.append({
				"year": new_year,
				"message": "%s arrived from Earth!" % first_immigrant.get("display_name", "Colonist"),
				"log_type": "immigration"
			})
		elif immigrant_count <= 5:
			for immigrant in immigration_result.immigrants:
				new_log.append({
					"year": new_year,
					"message": "%s arrived from Earth!" % immigrant.get("display_name", "Colonist"),
					"log_type": "immigration"
				})
		else:
			new_log.append({
				"year": new_year,
				"message": "%d colonists arrived from Earth!" % immigrant_count,
				"log_type": "immigration"
			})

	# === ECONOMY PHASE ===
	var balance = state.get("balance", {})
	var production = _MCSEconomy.calc_yearly_production(
		buildings,
		updates["colonists"],
		resources
	)
	var consumption = _MCSEconomy.calc_yearly_consumption(
		updates["colonists"],
		buildings,
		balance
	)

	var resource_result = _MCSEconomy.apply_yearly_resources(
		resources,
		production,
		consumption
	)
	updates["resources"] = resource_result.resources

	# Log shortages (creates drama!)
	for shortage in resource_result.shortages:
		new_log.append({
			"year": new_year,
			"message": "SHORTAGE: %s supplies critically low!" % shortage.to_upper(),
			"log_type": "crisis"
		})

	# === BUILDING MAINTENANCE ===
	var maint_rand_count = buildings.size() + 5
	var maint_rand_values = random_values.slice(rand_idx, rand_idx + maint_rand_count)
	rand_idx += maint_rand_count
	var maint_result = _MCSEconomy.apply_building_maintenance(
		buildings,
		updates["resources"],
		new_year,
		maint_rand_values
	)
	updates["buildings"] = maint_result.buildings
	updates["resources"] = maint_result.resources

	for breakdown in maint_result.breakdowns:
		new_log.append({
			"year": new_year,
			"message": "%s has broken down and needs repair!" % breakdown,
			"log_type": "crisis"
		})

	# === POLITICS PHASE ===
	var politics = state.get("politics", {})
	var pol_result = _MCSPolitics.update_faction_standings(
		politics,
		updates["colonists"],
		updates["resources"]
	)
	updates["politics"] = pol_result

	# Check for election year (every 4 years after year 5)
	if new_year >= 5 and (new_year - 5) % 4 == 0:
		var election_rand = random_values.slice(rand_idx, rand_idx + 10)
		rand_idx += 10
		var election_result = _MCSPolitics.hold_election(
			updates["politics"],
			updates["colonists"],
			election_rand
		)
		updates["politics"] = election_result.politics

		new_log.append({
			"year": new_year,
			"message": "Colony election held. %s" % election_result.summary,
			"log_type": "politics"
		})

	# Update stability
	updates["politics"] = _MCSPolitics.update_stability(
		updates["politics"],
		updates["colonists"],
		updates["resources"],
		resource_result.shortages.size() > 0
	)

	# === PHASE TRANSITIONS ===
	var colony_phase = state.get("colony_phase", 0)
	updates["colony_phase"] = _check_phase_transition(colony_phase, updates, new_year)
	if updates["colony_phase"] != colony_phase:
		new_log.append({
			"year": new_year,
			"message": "Colony has entered a new era: %s" % _MCSTypes.get_phase_name(updates["colony_phase"]),
			"log_type": "milestone"
		})

	updates["mission_log"] = new_log

	return _with_fields(state, updates)

# ============================================================================
# WEEKLY TICK - More granular simulation
# ============================================================================

static func _reduce_advance_week(state: Dictionary, action: Dictionary) -> Dictionary:
	var current_week = state.get("current_week", 1)
	var current_year = state.get("current_year", 1)
	var new_week = current_week + 1
	var random_values = action.get("random_values", [])
	var rand_idx = 0

	var updates: Dictionary = {}
	var new_log = state.get("mission_log", []).duplicate()

	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {}).duplicate(true)
	var buildings = state.get("buildings", []).duplicate(true)

	# === WEEKLY RESOURCE TICK (1/52 of yearly rates) ===
	var balance = state.get("balance", {})
	var weekly_production = _MCSEconomy.calc_yearly_production(buildings, colonists, resources)
	var weekly_consumption = _MCSEconomy.calc_yearly_consumption(colonists, buildings, balance)

	# Apply 1/52 of production and consumption
	for key in weekly_production.keys():
		var amount = weekly_production[key] / 52.0
		resources[key] = resources.get(key, 0) + amount

	for key in weekly_consumption.keys():
		var amount = weekly_consumption[key] / 52.0
		var current = resources.get(key, 0)
		resources[key] = maxf(0, current - amount)

		# Check for critical shortage this week
		if current > 10 and resources[key] <= 10:
			new_log.append({
				"year": current_year,
				"week": new_week,
				"message": "WARNING: %s supplies running low!" % key.to_upper(),
				"log_type": "crisis"
			})

	updates["resources"] = resources

	# === CONSTRUCTION PROGRESS (1/52 per week = ~1 year to build) ===
	for i in range(buildings.size()):
		var building = buildings[i]
		if building.get("construction_progress", 1.0) < 1.0:
			var new_progress = minf(1.0, building.construction_progress + (1.0 / 52.0))
			buildings[i] = building.duplicate()
			buildings[i]["construction_progress"] = new_progress

			# Completed this week!
			if new_progress >= 1.0 and building.construction_progress < 1.0:
				buildings[i]["is_operational"] = true
				new_log.append({
					"year": current_year,
					"week": new_week,
					"message": "Construction complete: %s is now operational!" % _MCSTypes.get_building_name(building.type),
					"log_type": "success"
				})

	updates["buildings"] = buildings

	# === MINOR WEEKLY EVENTS (5% chance per week) ===
	if random_values.size() > rand_idx and random_values[rand_idx] < 0.05:
		rand_idx += 1
		var event_roll = random_values[rand_idx] if random_values.size() > rand_idx else 0.5
		rand_idx += 1

		if event_roll < 0.3:
			# Small morale event
			new_log.append({
				"year": current_year,
				"week": new_week,
				"message": "A community gathering lifts spirits.",
				"log_type": "info"
			})
		elif event_roll < 0.6:
			# Minor maintenance
			new_log.append({
				"year": current_year,
				"week": new_week,
				"message": "Routine maintenance completed successfully.",
				"log_type": "info"
			})

	# === CHECK FOR YEAR END ===
	if new_week > 52:
		# Reset week, advance year
		updates["current_week"] = 1
		updates["current_year"] = current_year + 1
		var new_year = current_year + 1

		# === YEARLY POPULATION PHASE ===
		var pop_rand_count = colonists.size() * 5 + 20
		var pop_random = random_values.slice(rand_idx, rand_idx + pop_rand_count)
		rand_idx += pop_rand_count

		var pop_result = _MCSPopulation.advance_year(
			colonists,
			new_year,
			resources,
			buildings,
			pop_random
		)
		updates["colonists"] = pop_result.colonists

		for birth in pop_result.births:
			new_log.append({
				"year": new_year,
				"message": "%s was born to the colony!" % birth.display_name,
				"log_type": "birth"
			})

		for death in pop_result.deaths:
			new_log.append({
				"year": new_year,
				"message": "%s has passed away. %s" % [death.name, death.cause],
				"log_type": "death"
			})

		for adult in pop_result.new_adults:
			new_log.append({
				"year": new_year,
				"message": "%s has come of age and joined the workforce." % adult.display_name,
				"log_type": "milestone"
			})

		# === YEARLY BUILDING MAINTENANCE ===
		var maint_rand = random_values.slice(rand_idx, rand_idx + buildings.size() + 5)
		rand_idx += buildings.size() + 5
		var maint_result = _MCSEconomy.apply_building_maintenance(
			updates.get("buildings", buildings),
			updates["resources"],
			new_year,
			maint_rand
		)
		updates["buildings"] = maint_result.buildings
		updates["resources"] = maint_result.resources

		for breakdown in maint_result.breakdowns:
			new_log.append({
				"year": new_year,
				"message": "%s has broken down and needs repair!" % breakdown,
				"log_type": "crisis"
			})

		# === YEARLY POLITICS ===
		var politics = state.get("politics", {})
		var pol_result = _MCSPolitics.update_faction_standings(
			politics,
			updates.get("colonists", colonists),
			updates["resources"]
		)
		updates["politics"] = pol_result

		# Election every 4 years after year 5
		if new_year >= 5 and (new_year - 5) % 4 == 0:
			var election_rand = random_values.slice(rand_idx, rand_idx + 10)
			rand_idx += 10
			var election_result = _MCSPolitics.hold_election(
				updates["politics"],
				updates.get("colonists", colonists),
				election_rand
			)
			updates["politics"] = election_result.politics
			new_log.append({
				"year": new_year,
				"message": "Colony election held. %s" % election_result.summary,
				"log_type": "political"
			})

		# Update stability
		var had_shortages = false
		for key in ["food", "water", "oxygen"]:
			if updates["resources"].get(key, 100) < 20:
				had_shortages = true
				break

		updates["politics"] = _MCSPolitics.update_stability(
			updates["politics"],
			updates.get("colonists", colonists),
			updates["resources"],
			had_shortages
		)

		# === PHASE TRANSITIONS ===
		var colony_phase = state.get("colony_phase", 0)
		updates["colony_phase"] = _check_phase_transition(colony_phase, updates, new_year)
		if updates["colony_phase"] != colony_phase:
			new_log.append({
				"year": new_year,
				"message": "Colony has entered a new era: %s" % _MCSTypes.get_phase_name(updates["colony_phase"]),
				"log_type": "milestone"
			})

		# === VICTORY CHECK ===
		var victory_result = _check_victory_conditions(
			updates.get("colonists", colonists),
			updates.get("politics", politics),
			new_year
		)
		if victory_result.game_over:
			updates["is_game_over"] = true
			updates["is_victory"] = victory_result.is_victory
			updates["end_reason"] = victory_result.reason
			new_log.append({
				"year": new_year,
				"message": victory_result.reason,
				"log_type": "milestone" if victory_result.is_victory else "crisis"
			})
	else:
		updates["current_week"] = new_week

	updates["mission_log"] = new_log
	return _with_fields(state, updates)

static func _reduce_add_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists = state.get("colonists", []).duplicate()
	var colonist = action.get("colonist", {})
	new_colonists.append(colonist)

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "%s has joined the colony." % colonist.get("display_name", "Unknown"),
		"log_type": "info"
	})

	return _with_fields(state, {
		"colonists": new_colonists,
		"mission_log": new_log
	})

static func _reduce_remove_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists: Array = []
	var removed_name = ""

	for colonist in state.get("colonists", []):
		if colonist.get("id", "") != action.get("colonist_id", ""):
			new_colonists.append(colonist)
		else:
			removed_name = colonist.get("display_name", "Unknown")

	if removed_name.is_empty():
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "%s has left the colony. Reason: %s" % [removed_name, action.get("reason", "")],
		"log_type": "info"
	})

	return _with_fields(state, {
		"colonists": new_colonists,
		"mission_log": new_log
	})

static func _reduce_update_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists: Array = []
	for colonist in state.get("colonists", []):
		if colonist.get("id", "") == action.get("colonist_id", ""):
			new_colonists.append(_with_fields(colonist, action.get("updates", {})))
		else:
			new_colonists.append(colonist)

	return _with_field(state, "colonists", new_colonists)

static func _reduce_start_construction(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = _MCSEconomy.start_construction(
		state.get("buildings", []),
		state.get("resources", {}),
		action.get("building_type", 0),
		action.get("priority", 1)
	)

	if not result.get("success", false):
		return state

	# Add constructed_year to the newly added building
	var new_buildings = result.get("buildings", [])
	if new_buildings.size() > 0:
		var last_building = new_buildings[new_buildings.size() - 1].duplicate(true)
		last_building["constructed_year"] = state.get("current_year", 1)
		new_buildings = new_buildings.duplicate()
		new_buildings[new_buildings.size() - 1] = last_building

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Construction started: %s" % _MCSTypes.get_building_name(action.get("building_type", 0)),
		"log_type": "info"
	})

	return _with_fields(state, {
		"buildings": new_buildings,
		"resources": result.get("resources", {}),
		"mission_log": new_log
	})

static func _reduce_complete_construction(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var completed_name = ""

	for building in state.get("buildings", []):
		if building.get("id", "") == action.get("building_id", ""):
			var updated = building.duplicate(true)
			updated["is_operational"] = true
			updated["construction_progress"] = 1.0
			new_buildings.append(updated)
			completed_name = _MCSTypes.get_building_name(building.get("type", 0))
		else:
			new_buildings.append(building)

	if completed_name.is_empty():
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Construction complete: %s is now operational!" % completed_name,
		"log_type": "success"
	})

	return _with_fields(state, {
		"buildings": new_buildings,
		"mission_log": new_log
	})

static func _reduce_demolish_building(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var demolished_name = ""

	for building in state.get("buildings", []):
		if building.get("id", "") != action.get("building_id", ""):
			new_buildings.append(building)
		else:
			demolished_name = _MCSTypes.get_building_name(building.get("type", 0))

	if demolished_name.is_empty():
		return state

	# Return some materials
	var new_resources = state.get("resources", {}).duplicate(true)
	new_resources["building_materials"] = new_resources.get("building_materials", 0.0) + 25.0  # Salvage value

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "%s has been demolished. Materials salvaged." % demolished_name,
		"log_type": "info"
	})

	return _with_fields(state, {
		"buildings": new_buildings,
		"resources": new_resources,
		"mission_log": new_log
	})

static func _reduce_repair_building(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = _MCSEconomy.repair_building(
		state.get("buildings", []),
		state.get("resources", {}),
		action.get("building_id", "")
	)

	if not result.get("success", false):
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Building repaired and back online.",
		"log_type": "success"
	})

	return _with_fields(state, {
		"buildings": result.get("buildings", []),
		"resources": result.get("resources", {}),
		"mission_log": new_log
	})

static func _reduce_upgrade_building(state: Dictionary, action: Dictionary) -> Dictionary:
	"""START upgrading a building - costs resources, gradual process with construction visuals"""
	var building_id = action.get("building_id", "")
	var resources = state.get("resources", {}).duplicate(true)
	var new_buildings: Array = []
	var upgrade_started = false

	for building in state.get("buildings", []):
		if building.get("id", "") == building_id and not upgrade_started:
			var tier = building.get("tier", 1)
			var already_upgrading = building.get("upgrading", false)
			var target_tier = tier + 1

			if tier >= 5 or already_upgrading:
				# Can't upgrade past tier 5 or already upgrading
				new_buildings.append(building)
				continue

			# Check upgrade cost
			var costs = _MCSTypes.get_upgrade_cost(target_tier)
			var can_afford = true
			for resource_name in costs.keys():
				if resources.get(resource_name, 0) < costs[resource_name]:
					can_afford = false
					break

			if not can_afford:
				# Can't afford upgrade
				new_buildings.append(building)
				continue

			# Deduct costs
			for resource_name in costs.keys():
				resources[resource_name] = resources.get(resource_name, 0) - costs[resource_name]

			# Start upgrade
			var upgraded = building.duplicate(true)
			upgraded["upgrading"] = true
			upgraded["upgrade_progress"] = 0.0
			upgraded["target_tier"] = target_tier
			new_buildings.append(upgraded)
			upgrade_started = true
		else:
			new_buildings.append(building)

	return _with_fields(state, {
		"buildings": new_buildings,
		"resources": resources
	})

static func _reduce_progress_upgrades(state: Dictionary, _action: Dictionary) -> Dictionary:
	"""Progress all building upgrades - tier-based durations, stats come from BUILDING_TIER_STATS"""
	var new_buildings: Array = []
	var upgrade_log: Array = []

	for building in state.get("buildings", []):
		if building.get("upgrading", false):
			var upgraded = building.duplicate(true)
			var target_tier = upgraded.get("target_tier", 2)

			# Get tier-based duration (higher tiers take longer)
			var duration = _MCSTypes.get_upgrade_duration(target_tier)
			var upgrade_speed = 1.0 / maxf(duration, 1)  # Progress per year

			var progress = upgraded.get("upgrade_progress", 0.0) + upgrade_speed

			if progress >= 1.0:
				# Upgrade complete! Apply the tier change
				var old_tier = upgraded.get("tier", 1)
				upgraded["tier"] = target_tier
				upgraded["upgrading"] = false
				upgraded["upgrade_progress"] = 1.0
				upgraded.erase("target_tier")

				# Stats now come from BUILDING_TIER_STATS (no manual boosts needed)
				# The economy functions will automatically use tier-based values
				upgrade_log.append({
					"building_type": _MCSTypes.get_building_name(upgraded.get("type", 0)),
					"old_tier": old_tier,
					"new_tier": target_tier
				})
			else:
				upgraded["upgrade_progress"] = progress

			new_buildings.append(upgraded)
		else:
			new_buildings.append(building)

	var new_state = _with_field(state, "buildings", new_buildings)

	# Log completed upgrades
	if not upgrade_log.is_empty():
		var log = new_state.get("mission_log", []).duplicate()
		for upgrade in upgrade_log:
			log.append({
				"year": state.get("current_year", 1),
				"message": "%s upgraded to Tier %d!" % [upgrade.building_type, upgrade.new_tier],
				"log_type": "success"
			})
		new_state = _with_field(new_state, "mission_log", log)

	return new_state

static func _reduce_update_resource(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_resources = state.get("resources", {}).duplicate(true)
	var resource_name = _MCSTypes.get_resource_name(action.get("resource_type", 0))
	new_resources[resource_name] = maxf(0, new_resources.get(resource_name, 0) + action.get("delta", 0))

	return _with_field(state, "resources", new_resources)

static func _reduce_apply_production(state: Dictionary, _action: Dictionary) -> Dictionary:
	var buildings = state.get("buildings", [])
	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var production = _MCSEconomy.calc_yearly_production(buildings, colonists, resources)

	var new_resources = resources.duplicate(true)
	for key in production.keys():
		new_resources[key] = new_resources.get(key, 0) + production[key]

	return _with_field(state, "resources", new_resources)

static func _reduce_apply_consumption(state: Dictionary, _action: Dictionary) -> Dictionary:
	var colonists = state.get("colonists", [])
	var buildings = state.get("buildings", [])
	var balance = state.get("balance", {})
	var consumption = _MCSEconomy.calc_yearly_consumption(colonists, buildings, balance)

	var new_resources = state.get("resources", {}).duplicate(true)
	for key in consumption.keys():
		new_resources[key] = maxf(0, new_resources.get(key, 0) - consumption[key])

	return _with_field(state, "resources", new_resources)

static func _reduce_assign_worker(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []

	for building in state.get("buildings", []):
		if building.get("id", "") == action.get("building_id", ""):
			var updated = building.duplicate(true)
			var workers = updated.get("assigned_workers", [])
			if action.get("colonist_id", "") not in workers:
				workers.append(action.get("colonist_id", ""))
			updated["assigned_workers"] = workers
			new_buildings.append(updated)
		else:
			new_buildings.append(building)

	return _with_field(state, "buildings", new_buildings)

static func _reduce_unassign_worker(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var colonist_id = action.get("colonist_id", "")

	for building in state.get("buildings", []):
		var updated = building.duplicate(true)
		var workers = updated.get("assigned_workers", [])
		updated["assigned_workers"] = workers.filter(func(id): return id != colonist_id)
		new_buildings.append(updated)

	return _with_field(state, "buildings", new_buildings)

static func _reduce_auto_assign_workers(state: Dictionary, _action: Dictionary) -> Dictionary:
	var colonists = state.get("colonists", [])
	var buildings = state.get("buildings", [])
	var result = _MCSEconomy.auto_assign_workers(colonists, buildings)
	return _with_field(state, "buildings", result.get("buildings", buildings))

static func _reduce_hold_election(state: Dictionary, action: Dictionary) -> Dictionary:
	var politics = state.get("politics", {})
	var colonists = state.get("colonists", [])
	var result = _MCSPolitics.hold_election(politics, colonists, action.get("random_values", []))

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Colony election: %s" % result.get("summary", ""),
		"log_type": "politics"
	})

	return _with_fields(state, {
		"politics": result.get("politics", {}),
		"mission_log": new_log
	})

static func _reduce_change_government(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_politics = state.get("politics", {}).duplicate(true)
	new_politics["government_type"] = action.get("new_system", 0)

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Government changed to: %s" % _MCSTypes.get_political_system_name(action.get("new_system", 0)),
		"log_type": "politics"
	})

	return _with_fields(state, {
		"politics": new_politics,
		"mission_log": new_log
	})

static func _reduce_update_faction_standings(state: Dictionary, _action: Dictionary) -> Dictionary:
	var politics = state.get("politics", {})
	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var new_politics = _MCSPolitics.update_faction_standings(politics, colonists, resources)
	return _with_field(state, "politics", new_politics)

static func _reduce_hold_independence_vote(state: Dictionary, action: Dictionary) -> Dictionary:
	var politics = state.get("politics", {})
	var colonists = state.get("colonists", [])
	var result = _MCSPolitics.hold_independence_vote(politics, colonists, action.get("random_value", 0.5))

	var new_log = state.get("mission_log", []).duplicate()

	var current_year = state.get("current_year", 1)
	if result.get("passed", false):
		new_log.append({
			"year": current_year,
			"message": "INDEPENDENCE DECLARED! Mars is now a sovereign world!",
			"log_type": "milestone"
		})
	else:
		new_log.append({
			"year": current_year,
			"message": "Independence vote failed. The colony remains tied to Earth.",
			"log_type": "politics"
		})

	return _with_fields(state, {
		"politics": result.get("politics", {}),
		"is_independent": result.get("passed", false),
		"mission_log": new_log
	})

static func _reduce_trigger_event(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_active_events = state.get("active_events", []).duplicate()
	var event = action.get("event", {})
	new_active_events.append(event)

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "EVENT: %s" % event.get("title", "Unknown"),
		"log_type": "event"
	})

	return _with_fields(state, {
		"active_events": new_active_events,
		"mission_log": new_log
	})

static func _reduce_resolve_event_choice(state: Dictionary, action: Dictionary) -> Dictionary:
	var active_events = state.get("active_events", [])
	var event = null
	var event_index = -1

	for i in range(active_events.size()):
		var e = active_events[i]
		if e.get("id", "") == action.get("event_id", ""):
			event = e
			event_index = i
			break

	if event == null:
		return state

	# Apply choice effects
	var result = _MCSEvents.apply_event_choice(
		state,
		event,
		action.get("choice_index", 0),
		action.get("random_value", 0.5)
	)

	# Remove from active events
	var new_active = active_events.duplicate()
	new_active.remove_at(event_index)

	# Add to resolved
	var new_resolved = state.get("resolved_events", []).duplicate()
	new_resolved.append({
		"event_id": event.get("id", ""),
		"choice_index": action.get("choice_index", 0),
		"year": state.get("current_year", 1),
		"outcome": result.get("outcome", "")
	})

	# Merge result state with event removal
	var final_state = _with_fields(result.get("state", state), {
		"active_events": new_active,
		"resolved_events": new_resolved
	})

	# Add outcome to log
	var new_log = final_state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": result.get("outcome", ""),
		"log_type": "event"
	})
	final_state["mission_log"] = new_log

	return final_state

static func _reduce_add_log(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.get("mission_log", []).duplicate()
	var action_year = action.get("year", -1)
	new_log.append({
		"year": action_year if action_year >= 0 else state.get("current_year", 1),
		"message": action.get("message", ""),
		"log_type": action.get("log_type", "info")
	})

	return _with_field(state, "mission_log", new_log)

static func _reduce_check_victory(state: Dictionary, _action: Dictionary) -> Dictionary:
	var updates: Dictionary = {}
	var colonists = state.get("colonists", [])
	var politics = state.get("politics", {})
	var stability = politics.get("stability", 75.0)
	var is_independent = state.get("is_independent", false)
	var current_year = state.get("current_year", 1)

	# Check loss conditions
	if colonists.size() == 0:
		updates["game_over"] = true
		updates["victory"] = false
		updates["end_reason"] = "Colony has perished. No survivors remain."
	elif stability <= 0:
		updates["game_over"] = true
		updates["victory"] = false
		updates["end_reason"] = "Colony collapsed due to civil unrest."

	# Check victory conditions
	elif is_independent and colonists.size() >= 1000:
		updates["game_over"] = true
		updates["victory"] = true
		updates["end_reason"] = "Mars is free! A thriving nation of %d souls has secured humanity's future." % colonists.size()
	elif current_year >= 100 and colonists.size() >= 500:
		updates["game_over"] = true
		updates["victory"] = true
		updates["end_reason"] = "After 100 years, the colony stands strong. Humanity has become a multi-planetary species."

	if updates.is_empty():
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": current_year,
		"message": updates.get("end_reason", ""),
		"log_type": "milestone" if updates.get("victory", false) else "crisis"
	})
	updates["mission_log"] = new_log

	return _with_fields(state, updates)

static func _reduce_end_colony(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.get("mission_log", []).duplicate()
	var is_victory = action.get("is_victory", false)
	var reason = action.get("reason", "")
	new_log.append({
		"year": state.get("current_year", 1),
		"message": reason,
		"log_type": "milestone" if is_victory else "crisis"
	})

	return _with_fields(state, {
		"game_over": true,
		"victory": is_victory,
		"end_reason": reason,
		"mission_log": new_log
	})

# ============================================================================
# HELPERS
# ============================================================================

static func _check_phase_transition(current_phase: int, state_updates: Dictionary, year: int) -> int:
	var pop_count = state_updates.get("colonists", []).size()

	match current_phase:
		_MCSTypes.ColonyPhase.ACT_1_FOUNDERS:
			# Transition to ACT_2_SETTLEMENT when stable food + 30 pop + year 5
			if year >= 5 and pop_count >= 30:
				var resources = state_updates.get("resources", {})
				if resources.get("food", 0) >= 100:
					return _MCSTypes.ColonyPhase.ACT_2_SETTLEMENT

		_MCSTypes.ColonyPhase.ACT_2_SETTLEMENT:
			# Transition to ACT_3_COLONY when 100 pop + year 20
			if year >= 20 and pop_count >= 100:
				return _MCSTypes.ColonyPhase.ACT_3_COLONY

		_MCSTypes.ColonyPhase.ACT_3_COLONY:
			# Transition to ACT_4_INDEPENDENCE when 300 pop + year 50
			if year >= 50 and pop_count >= 300:
				return _MCSTypes.ColonyPhase.ACT_4_INDEPENDENCE

	return current_phase

static func _check_victory_conditions(colonists: Array, politics: Dictionary, year: int) -> Dictionary:
	"""Check victory and loss conditions, return result dictionary"""
	var stability = politics.get("stability", 75.0)
	var is_independent = politics.get("is_independent", false)

	# Check loss conditions
	if colonists.size() == 0:
		return {
			"game_over": true,
			"is_victory": false,
			"reason": "Colony has perished. No survivors remain."
		}
	elif stability <= 0:
		return {
			"game_over": true,
			"is_victory": false,
			"reason": "Colony collapsed due to civil unrest."
		}

	# Check victory conditions
	elif is_independent and colonists.size() >= 1000:
		return {
			"game_over": true,
			"is_victory": true,
			"reason": "Mars is free! A thriving nation of %d souls has secured humanity's future." % colonists.size()
		}
	elif year >= 100 and colonists.size() >= 500:
		return {
			"game_over": true,
			"is_victory": true,
			"reason": "After 100 years, the colony stands strong. Humanity has become a multi-planetary species."
		}

	# No end condition reached
	return {"game_over": false, "is_victory": false, "reason": ""}

## Immutable-style field update
static func _with_field(dict: Dictionary, key: String, value) -> Dictionary:
	var new_dict = dict.duplicate(true)
	new_dict[key] = value
	return new_dict

## Immutable-style multi-field update
static func _with_fields(dict: Dictionary, updates: Dictionary) -> Dictionary:
	var new_dict = dict.duplicate(true)
	for key in updates.keys():
		new_dict[key] = updates[key]
	return new_dict
