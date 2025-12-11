## Action type definitions for the Redux-style dispatch system.
## Actions are plain dictionaries with a "type" field and payload.
##
## This file defines:
## - All known action types as constants
## - Action creator functions for type safety
## - Action validation helpers
class_name ActionTypes
extends RefCounted


## ============================================================================
## CORE ACTION TYPES
## ============================================================================

## Game lifecycle
const NEW_GAME = "NEW_GAME"
const INITIALIZE_GAME = "INITIALIZE_GAME"
const LOAD_GAME = "LOAD_GAME"
const SAVE_GAME = "SAVE_GAME"
const RESET_GAME = "RESET_GAME"

## Phase transitions
const CHANGE_PHASE = "CHANGE_PHASE"
const START_PHASE = "START_PHASE"
const END_PHASE = "END_PHASE"

## Time progression
const ADVANCE_TIME = "ADVANCE_TIME"
const ADVANCE_DAY = "ADVANCE_DAY"
const PAUSE_TIME = "PAUSE_TIME"
const RESUME_TIME = "RESUME_TIME"
const SET_TIME_SPEED = "SET_TIME_SPEED"

## Logging and flags
const ADD_LOG = "ADD_LOG"
const SET_FLAG = "SET_FLAG"
const CLEAR_FLAG = "CLEAR_FLAG"
const UPDATE_SETTINGS = "UPDATE_SETTINGS"


## ============================================================================
## SHIP BUILDING ACTIONS (Phase 1)
## ============================================================================

const PLACE_COMPONENT = "PLACE_COMPONENT"
const REMOVE_COMPONENT = "REMOVE_COMPONENT"
const ROTATE_COMPONENT = "ROTATE_COMPONENT"
const START_COMPONENT_TEST = "START_COMPONENT_TEST"
const COMPLETE_COMPONENT_TEST = "COMPLETE_COMPONENT_TEST"
const TEST_COMPONENT = "TEST_COMPONENT"
const REPAIR_COMPONENT = "REPAIR_COMPONENT"
const SELECT_ENGINE = "SELECT_ENGINE"
const PURCHASE_SUPPLIES = "PURCHASE_SUPPLIES"
const SET_SUPPLY_AMOUNT = "SET_SUPPLY_AMOUNT"
const LOAD_CARGO = "LOAD_CARGO"
const START_LAUNCH = "START_LAUNCH"
const LAUNCH = "LAUNCH"


## ============================================================================
## CREW ACTIONS
## ============================================================================

const HIRE_CREW = "HIRE_CREW"
const FIRE_CREW = "FIRE_CREW"
const DISMISS_CREW = "DISMISS_CREW"
const ASSIGN_CREW_TASK = "ASSIGN_CREW_TASK"
const TRAIN_CREW = "TRAIN_CREW"
const REST_CREW = "REST_CREW"
const HEAL_CREW = "HEAL_CREW"
const UPDATE_CREW_STATS = "UPDATE_CREW_STATS"
const CREW_DEATH = "CREW_DEATH"
const UPDATE_RELATIONSHIP = "UPDATE_RELATIONSHIP"


## ============================================================================
## RESOURCE ACTIONS
## ============================================================================

const CONSUME_RESOURCE = "CONSUME_RESOURCE"
const ADD_RESOURCE = "ADD_RESOURCE"
const SET_RESOURCE = "SET_RESOURCE"
const TRANSFER_RESOURCE = "TRANSFER_RESOURCE"
const SET_RATIONING = "SET_RATIONING"


## ============================================================================
## EVENT ACTIONS
## ============================================================================

const TRIGGER_EVENT = "TRIGGER_EVENT"
const RESOLVE_EVENT = "RESOLVE_EVENT"
const DISMISS_EVENT = "DISMISS_EVENT"
const SELECT_EVENT_CHOICE = "SELECT_EVENT_CHOICE"
const ADD_EVENT_COOLDOWN = "ADD_EVENT_COOLDOWN"
const SET_EVENT_FLAG = "SET_EVENT_FLAG"


## ============================================================================
## TRAVEL ACTIONS (Phase 2 & 4)
## ============================================================================

const START_TRAVEL = "START_TRAVEL"
const ADVANCE_TRAVEL_DAY = "ADVANCE_TRAVEL_DAY"
const CHANGE_SPEED = "CHANGE_SPEED"
const COURSE_CORRECTION = "COURSE_CORRECTION"
const EMERGENCY_MANEUVER = "EMERGENCY_MANEUVER"
const ARRIVE_AT_DESTINATION = "ARRIVE_AT_DESTINATION"


## ============================================================================
## MARS BASE ACTIONS (Phase 3)
## ============================================================================

const LAND_ON_MARS = "LAND_ON_MARS"
const SELECT_LANDING_SITE = "SELECT_LANDING_SITE"
const BUILD_MODULE = "BUILD_MODULE"
const START_EXPERIMENT = "START_EXPERIMENT"
const COMPLETE_EXPERIMENT = "COMPLETE_EXPERIMENT"
const START_EVA = "START_EVA"
const END_EVA = "END_EVA"
const COLLECT_SAMPLE = "COLLECT_SAMPLE"
const ADVANCE_SOL = "ADVANCE_SOL"
const PREPARE_DEPARTURE = "PREPARE_DEPARTURE"


## ============================================================================
## LOG ACTIONS
## ============================================================================

const ADD_LOG_ENTRY = "ADD_LOG_ENTRY"
const ADD_MISSION_MILESTONE = "ADD_MISSION_MILESTONE"


## ============================================================================
## GAME END ACTIONS
## ============================================================================

const BEGIN_REENTRY = "BEGIN_REENTRY"
const RESTART_GAME = "RESTART_GAME"


## ============================================================================
## ACTION CREATORS
## These functions create properly-typed action dictionaries.
## ============================================================================

static func initialize_game(game_id: String, difficulty: String = "normal", seed: int = -1) -> Dictionary:
	return {
		"type": INITIALIZE_GAME,
		"game_id": game_id,
		"difficulty": difficulty,
		"seed": seed
	}


static func change_phase(new_phase: String) -> Dictionary:
	return {
		"type": CHANGE_PHASE,
		"new_phase": new_phase
	}


static func advance_time(amount: int = 1) -> Dictionary:
	return {
		"type": ADVANCE_TIME,
		"amount": amount
	}


static func place_component(component_id: String, position: Vector2i, rotation: int = 0) -> Dictionary:
	return {
		"type": PLACE_COMPONENT,
		"component_id": component_id,
		"position": {"q": position.x, "r": position.y},
		"rotation": rotation
	}


static func remove_component(position: Vector2i) -> Dictionary:
	return {
		"type": REMOVE_COMPONENT,
		"position": {"q": position.x, "r": position.y}
	}


static func start_component_test(position: Vector2i) -> Dictionary:
	return {
		"type": START_COMPONENT_TEST,
		"position": {"q": position.x, "r": position.y}
	}


static func complete_component_test(position: Vector2i, random_value: float) -> Dictionary:
	return {
		"type": COMPLETE_COMPONENT_TEST,
		"position": {"q": position.x, "r": position.y},
		"random_value": random_value
	}


static func select_engine(engine_id: String) -> Dictionary:
	return {
		"type": SELECT_ENGINE,
		"engine_id": engine_id
	}


static func hire_crew(crew_id: String) -> Dictionary:
	return {
		"type": HIRE_CREW,
		"crew_id": crew_id
	}


static func fire_crew(crew_id: String) -> Dictionary:
	return {
		"type": FIRE_CREW,
		"crew_id": crew_id
	}


static func assign_crew_task(crew_id: String, task: String) -> Dictionary:
	return {
		"type": ASSIGN_CREW_TASK,
		"crew_id": crew_id,
		"task": task
	}


static func consume_resource(resource_id: String, amount: float) -> Dictionary:
	return {
		"type": CONSUME_RESOURCE,
		"resource_id": resource_id,
		"amount": amount
	}


static func add_resource(resource_id: String, amount: float) -> Dictionary:
	return {
		"type": ADD_RESOURCE,
		"resource_id": resource_id,
		"amount": amount
	}


static func set_rationing(level: String) -> Dictionary:
	return {
		"type": SET_RATIONING,
		"level": level  # "none", "light", "moderate", "severe", "starvation"
	}


static func trigger_event(event_id: String, context: Dictionary = {}) -> Dictionary:
	return {
		"type": TRIGGER_EVENT,
		"event_id": event_id,
		"context": context
	}


static func select_event_choice(event_id: String, choice_id: String, random_values: Array = []) -> Dictionary:
	return {
		"type": SELECT_EVENT_CHOICE,
		"event_id": event_id,
		"choice_id": choice_id,
		"random_values": random_values
	}


static func advance_travel_day(random_values: Array[float]) -> Dictionary:
	return {
		"type": ADVANCE_TRAVEL_DAY,
		"random_values": random_values
	}


static func start_travel(destination: String) -> Dictionary:
	return {
		"type": START_TRAVEL,
		"destination": destination
	}


static func land_on_mars(landing_site: String) -> Dictionary:
	return {
		"type": LAND_ON_MARS,
		"landing_site": landing_site
	}


static func advance_sol(random_values: Array[float]) -> Dictionary:
	return {
		"type": ADVANCE_SOL,
		"random_values": random_values
	}


static func start_experiment(experiment_id: String, crew_id: String) -> Dictionary:
	return {
		"type": START_EXPERIMENT,
		"experiment_id": experiment_id,
		"crew_id": crew_id
	}


static func start_eva(crew_ids: Array[String], destination: String, duration: float) -> Dictionary:
	return {
		"type": START_EVA,
		"crew_ids": crew_ids,
		"destination": destination,
		"duration": duration
	}


static func add_log_entry(message: String, entry_type: String = "general") -> Dictionary:
	return {
		"type": ADD_LOG_ENTRY,
		"message": message,
		"entry_type": entry_type
	}


## ============================================================================
## VALIDATION HELPERS
## ============================================================================

## All known action types
static func get_all_types() -> Array[String]:
	return [
		INITIALIZE_GAME, LOAD_GAME, SAVE_GAME, RESET_GAME,
		CHANGE_PHASE, START_PHASE, END_PHASE,
		ADVANCE_TIME, PAUSE_TIME, RESUME_TIME, SET_TIME_SPEED,
		PLACE_COMPONENT, REMOVE_COMPONENT, ROTATE_COMPONENT,
		START_COMPONENT_TEST, COMPLETE_COMPONENT_TEST, REPAIR_COMPONENT,
		SELECT_ENGINE, PURCHASE_SUPPLIES, SET_SUPPLY_AMOUNT, START_LAUNCH,
		HIRE_CREW, FIRE_CREW, ASSIGN_CREW_TASK, TRAIN_CREW,
		REST_CREW, HEAL_CREW, UPDATE_CREW_STATS, CREW_DEATH, UPDATE_RELATIONSHIP,
		CONSUME_RESOURCE, ADD_RESOURCE, SET_RESOURCE, TRANSFER_RESOURCE, SET_RATIONING,
		TRIGGER_EVENT, RESOLVE_EVENT, DISMISS_EVENT, SELECT_EVENT_CHOICE,
		ADD_EVENT_COOLDOWN, SET_EVENT_FLAG,
		START_TRAVEL, ADVANCE_TRAVEL_DAY, CHANGE_SPEED, COURSE_CORRECTION,
		EMERGENCY_MANEUVER, ARRIVE_AT_DESTINATION,
		LAND_ON_MARS, SELECT_LANDING_SITE, BUILD_MODULE,
		START_EXPERIMENT, COMPLETE_EXPERIMENT,
		START_EVA, END_EVA, COLLECT_SAMPLE,
		ADVANCE_SOL, PREPARE_DEPARTURE,
		ADD_LOG_ENTRY, ADD_MISSION_MILESTONE
	]


## Check if action type is valid
static func is_valid_type(action_type: String) -> bool:
	return action_type in get_all_types()


## Get required fields for an action type
static func get_required_fields(action_type: String) -> Array[String]:
	match action_type:
		INITIALIZE_GAME:
			return ["game_id"]
		CHANGE_PHASE:
			return ["new_phase"]
		PLACE_COMPONENT:
			return ["component_id", "position"]
		REMOVE_COMPONENT:
			return ["position"]
		HIRE_CREW, FIRE_CREW:
			return ["crew_id"]
		ASSIGN_CREW_TASK:
			return ["crew_id", "task"]
		CONSUME_RESOURCE, ADD_RESOURCE:
			return ["resource_id", "amount"]
		TRIGGER_EVENT:
			return ["event_id"]
		SELECT_EVENT_CHOICE:
			return ["event_id", "choice_id"]
		_:
			return []
