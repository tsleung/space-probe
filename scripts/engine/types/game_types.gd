## Core game type definitions.
## Provides enums, constants, and factory functions for game data structures.
## All functions use immutable-style updates.
class_name GameTypes
extends RefCounted


## ============================================================================
## ENUMS
## ============================================================================

enum GamePhase {
	MAIN_MENU,
	SHIP_BUILDING,
	TRAVEL_TO_MARS,
	MARS_ARRIVAL,
	MARS_BASE,
	MARS_DEPARTURE,
	TRAVEL_TO_EARTH,
	EARTH_ARRIVAL,
	GAME_OVER
}

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

enum ComponentCategory {
	COCKPIT,
	ENGINE,
	CREW_MODULE,
	LIFE_SUPPORT,
	CARGO,
	SPECIAL
}

enum ComponentState {
	OPERATIONAL,
	DEGRADED,
	DAMAGED,
	CRITICAL,
	DESTROYED
}

enum CrewSpecialty {
	COMMANDER,
	PILOT,
	ENGINEER,
	SCIENTIST,
	MEDICAL
}

enum CrewStatus {
	HEALTHY,
	INJURED,
	SICK,
	CRITICAL,
	DEAD
}

enum TaskType {
	PILOTING,
	MAINTENANCE,
	REPAIR,
	RESEARCH,
	MEDICAL_DUTY,
	REST,
	EXERCISE,
	SOCIAL,
	EVA
}

enum ResourceType {
	FOOD,
	WATER,
	OXYGEN,
	FUEL,
	POWER,
	MEDICAL_SUPPLIES,
	SPARE_PARTS
}

enum EventCategory {
	SHIP,
	CREW,
	SPACE,
	ENVIRONMENT,
	DISCOVERY,
	QUIET_MOMENT
}

enum EventSeverity {
	MINOR,
	MODERATE,
	MAJOR,
	CRITICAL
}

enum VictoryTier {
	GOLD,
	SILVER,
	BRONZE,
	PYRRHIC,
	FAILURE
}


## ============================================================================
## PHASE NAME MAPPINGS
## ============================================================================

const PHASE_NAMES = {
	GamePhase.MAIN_MENU: "main_menu",
	GamePhase.SHIP_BUILDING: "ship_building",
	GamePhase.TRAVEL_TO_MARS: "travel_to_mars",
	GamePhase.MARS_ARRIVAL: "mars_arrival",
	GamePhase.MARS_BASE: "mars_base",
	GamePhase.MARS_DEPARTURE: "mars_departure",
	GamePhase.TRAVEL_TO_EARTH: "travel_to_earth",
	GamePhase.EARTH_ARRIVAL: "earth_arrival",
	GamePhase.GAME_OVER: "game_over"
}

const PHASE_FROM_NAME = {
	"main_menu": GamePhase.MAIN_MENU,
	"ship_building": GamePhase.SHIP_BUILDING,
	"travel_to_mars": GamePhase.TRAVEL_TO_MARS,
	"mars_arrival": GamePhase.MARS_ARRIVAL,
	"mars_base": GamePhase.MARS_BASE,
	"mars_departure": GamePhase.MARS_DEPARTURE,
	"travel_to_earth": GamePhase.TRAVEL_TO_EARTH,
	"earth_arrival": GamePhase.EARTH_ARRIVAL,
	"game_over": GamePhase.GAME_OVER
}


## ============================================================================
## IMMUTABLE UPDATE HELPERS
## ============================================================================

## Return a new dictionary with one field updated
static func with_field(dict: Dictionary, key: String, value) -> Dictionary:
	var new_dict = dict.duplicate(true)
	new_dict[key] = value
	return new_dict


## Return a new dictionary with multiple fields updated
static func with_fields(dict: Dictionary, updates: Dictionary) -> Dictionary:
	var new_dict = dict.duplicate(true)
	for key in updates:
		new_dict[key] = updates[key]
	return new_dict


## Return a new dictionary with a nested field updated
## Example: with_nested_field(state, ["crew", 0, "health"], 80)
static func with_nested_field(dict: Dictionary, path: Array, value) -> Dictionary:
	if path.is_empty():
		return dict

	var new_dict = dict.duplicate(true)
	var current = new_dict

	for i in range(path.size() - 1):
		var key = path[i]
		if current is Dictionary:
			current[key] = current[key].duplicate(true) if current[key] is Dictionary else current[key].duplicate()
			current = current[key]
		elif current is Array:
			current[key] = current[key].duplicate(true) if current[key] is Dictionary else current[key].duplicate() if current[key] is Array else current[key]
			current = current[key]

	current[path[-1]] = value
	return new_dict


## Return new array with item at index replaced
static func with_array_item(arr: Array, index: int, value) -> Array:
	var new_arr = arr.duplicate(true)
	new_arr[index] = value
	return new_arr


## Return new array with item appended
static func with_array_append(arr: Array, value) -> Array:
	var new_arr = arr.duplicate(true)
	new_arr.append(value)
	return new_arr


## Return new array with item removed at index
static func with_array_removed(arr: Array, index: int) -> Array:
	var new_arr = arr.duplicate(true)
	new_arr.remove_at(index)
	return new_arr


## Return new array with item matching predicate removed
static func with_array_filter(arr: Array, predicate: Callable) -> Array:
	var new_arr = arr.duplicate(true)
	return new_arr.filter(predicate)


## ============================================================================
## FACTORY FUNCTIONS - Create new instances of game objects
## ============================================================================

## Create initial game state
static func create_game_state(game_id: String, difficulty: String = "normal") -> Dictionary:
	return {
		"game_id": game_id,
		"difficulty": difficulty,
		"current_phase": "ship_building",
		"current_day": 1,
		"current_sol": 0,
		"total_travel_days": 0,
		"travel_day": 0,

		"ship": create_ship(),
		"crew": [],
		"resources": create_initial_resources(),

		"active_events": [],
		"event_cooldowns": {},
		"triggered_flags": [],

		"mission_log": [],
		"action_history": [],

		"score": 0,
		"victory_tier": null,

		"meta": {
			"created_at": Time.get_datetime_string_from_system(),
			"last_saved": null,
			"play_time_seconds": 0
		}
	}


## Create empty ship structure
static func create_ship() -> Dictionary:
	return {
		"components": {},  # hex position string -> component
		"selected_engine": null,
		"total_mass": 0.0,
		"power_capacity": 0.0,
		"power_draw": 0.0,
		"cargo_capacity": 0.0,
		"cargo_used": 0.0,
		"average_quality": 0.0
	}


## Create a placed component
static func create_component(
	component_id: String,
	definition: Dictionary,
	position: Vector2i,
	rotation: int = 0
) -> Dictionary:
	return {
		"id": component_id,
		"definition_id": definition.get("id", component_id),
		"name": definition.get("name", component_id),
		"category": definition.get("category", "special"),
		"position": {"q": position.x, "r": position.y},
		"rotation": rotation,
		"quality": definition.get("stats", {}).get("base_quality", 50),
		"state": ComponentState.OPERATIONAL,
		"damage": 0.0,
		"wear": 0.0,
		"testing_in_progress": false,
		"test_days_remaining": 0,
		"active_failures": []
	}


## Create a crew member from roster definition
static func create_crew_member(definition: Dictionary) -> Dictionary:
	return {
		"id": definition.get("id", "unknown"),
		"name": definition.get("name", "Unknown"),
		"role": definition.get("role", "crew"),
		"specialty": definition.get("specialty", CrewSpecialty.SCIENTIST),

		"health": 100.0,
		"max_health": 100.0,
		"morale": 75.0,
		"fatigue": 0.0,
		"stress": 0.0,

		"status": CrewStatus.HEALTHY,
		"current_task": null,
		"injuries": [],
		"conditions": [],

		"skills": definition.get("stats", {}).duplicate(),
		"traits": definition.get("traits", []).duplicate(),

		"relationships": {},
		"arc_progress": {},

		"days_worked": 0,
		"days_rested": 0,
		"eva_count": 0,
		"radiation_exposure": 0.0
	}


## Create initial resources structure
static func create_initial_resources() -> Dictionary:
	return {
		"food": {"current": 0.0, "max": 0.0, "daily_consumption": 0.0},
		"water": {"current": 0.0, "max": 0.0, "daily_consumption": 0.0},
		"oxygen": {"current": 0.0, "max": 0.0, "daily_consumption": 0.0},
		"fuel": {"current": 0.0, "max": 0.0, "daily_consumption": 0.0},
		"power": {"generation": 0.0, "consumption": 0.0, "storage": 0.0, "current": 0.0},
		"medical_supplies": {"current": 0.0, "max": 0.0},
		"spare_parts": {"current": 0.0, "max": 0.0}
	}


## Create a resource entry
static func create_resource(current: float, max_val: float, daily_consumption: float = 0.0) -> Dictionary:
	return {
		"current": current,
		"max": max_val,
		"daily_consumption": daily_consumption
	}


## Create a mission log entry
static func create_log_entry(
	day: int,
	phase: String,
	message: String,
	entry_type: String = "general"
) -> Dictionary:
	return {
		"day": day,
		"phase": phase,
		"message": message,
		"type": entry_type,
		"timestamp": Time.get_datetime_string_from_system()
	}


## Create an active event
static func create_active_event(event_definition: Dictionary, context: Dictionary = {}) -> Dictionary:
	return {
		"id": event_definition.get("id", "unknown"),
		"definition": event_definition,
		"context": context,
		"triggered_day": context.get("current_day", 0),
		"resolved": false,
		"chosen_option": null,
		"outcome": null
	}


## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

## Convert hex position dict to Vector2i
static func hex_dict_to_vector(hex_dict: Dictionary) -> Vector2i:
	return Vector2i(hex_dict.get("q", 0), hex_dict.get("r", 0))


## Convert Vector2i to hex position dict
static func vector_to_hex_dict(vec: Vector2i) -> Dictionary:
	return {"q": vec.x, "r": vec.y}


## Get hex position as string key (for dictionary storage)
static func hex_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


## Parse hex key back to Vector2i
static func parse_hex_key(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


## Get phase name from enum
static func get_phase_name(phase: GamePhase) -> String:
	return PHASE_NAMES.get(phase, "unknown")


## Get phase enum from name
static func get_phase_from_name(name: String) -> GamePhase:
	return PHASE_FROM_NAME.get(name, GamePhase.MAIN_MENU)


## Calculate component state from damage
static func get_component_state_from_damage(damage: float) -> ComponentState:
	if damage >= 100:
		return ComponentState.DESTROYED
	elif damage >= 75:
		return ComponentState.CRITICAL
	elif damage >= 50:
		return ComponentState.DAMAGED
	elif damage >= 25:
		return ComponentState.DEGRADED
	else:
		return ComponentState.OPERATIONAL


## Calculate crew status from health
static func get_crew_status_from_health(health: float) -> CrewStatus:
	if health <= 0:
		return CrewStatus.DEAD
	elif health < 20:
		return CrewStatus.CRITICAL
	elif health < 50:
		return CrewStatus.INJURED
	else:
		return CrewStatus.HEALTHY


## Calculate victory tier from final state
static func calculate_victory_tier(
	surviving_crew: int,
	total_crew: int,
	science_percent: float,
	budget_remaining_percent: float,
	total_score: int
) -> VictoryTier:
	if surviving_crew == 0:
		if total_score >= 1000:
			return VictoryTier.PYRRHIC
		return VictoryTier.FAILURE

	if surviving_crew == total_crew and science_percent >= 0.8 and budget_remaining_percent >= 0.1:
		return VictoryTier.GOLD

	if surviving_crew >= 3 and science_percent >= 0.6:
		return VictoryTier.SILVER

	if surviving_crew >= 2 and science_percent >= 0.4:
		return VictoryTier.BRONZE

	return VictoryTier.PYRRHIC
