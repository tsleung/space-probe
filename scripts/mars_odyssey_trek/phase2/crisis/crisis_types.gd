extends RefCounted
class_name CrisisTypes

## Real-Time Crisis System Type Definitions
## Enables Overcooked-style simultaneous crisis management

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# ENUMS
# ============================================================================

enum CrisisType {
	O2_LEAK,           # Life Support - oxygen drains
	POWER_FLUCTUATION, # Engineering - power drains, lights flicker
	WATER_RECYCLER,    # Life Support - water drains
	HULL_STRESS,       # Cargo Bay - risk of breach
	MEDICAL_EMERGENCY, # Medical - crew health drains
	NAVIGATION_DRIFT,  # Bridge - fuel waste
	COMMS_FAILURE,     # Bridge - morale drain
	FIRE,              # Any room - spreads if ignored
	EQUIPMENT_FAULT,   # Engineering - general malfunction
	FOOD_CONTAMINATION # Cargo Bay - food loss
}

enum Severity {
	EMERGING,     # Just started - yellow, low drain
	ACTIVE,       # Needs attention - orange, normal drain
	CRITICAL,     # Urgent! - red, high drain
	CATASTROPHIC  # Emergency! - flashing red, extreme drain
}

enum CrewRole {
	COMMANDER,
	ENGINEER,
	SCIENTIST,
	MEDICAL
}

# ============================================================================
# TIMING CONSTANTS
# ============================================================================

# How long each severity lasts before escalating (seconds)
const ESCALATION_TIMES = {
	Severity.EMERGING: 4.0,
	Severity.ACTIVE: 8.0,
	Severity.CRITICAL: 12.0,
	Severity.CATASTROPHIC: -1  # Doesn't escalate, just gets worse
}

# Base time to fix a crisis (modified by crew skill)
const BASE_FIX_TIME = 5.0

# Maximum simultaneous crises
const MAX_ACTIVE_CRISES = 4

# Base spawn interval (seconds between crisis checks)
const CRISIS_CHECK_INTERVAL = 2.0

# Base spawn chance per check (increases with journey progress)
const BASE_SPAWN_CHANCE = 0.15

# ============================================================================
# CRISIS DEFINITIONS
# ============================================================================

# Each crisis type's properties
# CRISIS mode adds: requires_item, is_station_task, crisis_work_time
const CRISIS_DEFINITIONS = {
	CrisisType.O2_LEAK: {
		"name": "O2 Leak",
		"room": ShipTypes.RoomType.LIFE_SUPPORT,
		"resource_drain": "oxygen",
		"drain_rate": 2.0,  # Per second at ACTIVE severity
		"fix_time": 6.0,
		"best_crew": CrewRole.SCIENTIST,
		"icon": "O2",
		"sound": "hiss",
		# CRISIS mode properties
		"requires_item": "spare_part",
		"is_station_task": false,
		"crisis_work_time": 4.0  # Work time after item delivered
	},
	CrisisType.POWER_FLUCTUATION: {
		"name": "Power Fluctuation",
		"room": ShipTypes.RoomType.ENGINEERING,
		"resource_drain": "power",
		"drain_rate": 3.0,
		"fix_time": 5.0,
		"best_crew": CrewRole.ENGINEER,
		"icon": "PWR",
		"sound": "electrical",
		# CRISIS mode: station task (no item needed)
		"requires_item": "",
		"is_station_task": true,
		"crisis_work_time": 5.0  # Console work time
	},
	CrisisType.WATER_RECYCLER: {
		"name": "Water Recycler Jam",
		"room": ShipTypes.RoomType.LIFE_SUPPORT,
		"resource_drain": "water",
		"drain_rate": 1.5,
		"fix_time": 7.0,
		"best_crew": CrewRole.SCIENTIST,
		"icon": "H2O",
		"sound": "gurgle",
		# CRISIS mode properties
		"requires_item": "spare_part",
		"is_station_task": false,
		"crisis_work_time": 4.0
	},
	CrisisType.HULL_STRESS: {
		"name": "Hull Stress",
		"room": ShipTypes.RoomType.CARGO_BAY,
		"resource_drain": "none",  # Special: risk of breach
		"drain_rate": 0.0,
		"fix_time": 10.0,
		"best_crew": CrewRole.ENGINEER,
		"icon": "HULL",
		"sound": "creak",
		"special": "breach_risk",  # Can cause sudden O2 loss
		# CRISIS mode properties
		"requires_item": "patch_kit",
		"is_station_task": false,
		"crisis_work_time": 5.0
	},
	CrisisType.MEDICAL_EMERGENCY: {
		"name": "Medical Emergency",
		"room": ShipTypes.RoomType.MEDICAL,
		"resource_drain": "crew_health",
		"drain_rate": 5.0,  # Health per second
		"fix_time": 5.0,
		"best_crew": CrewRole.MEDICAL,
		"icon": "MED",
		"sound": "alarm",
		# CRISIS mode properties
		"requires_item": "med_kit",
		"is_station_task": false,
		"crisis_work_time": 4.0
	},
	CrisisType.NAVIGATION_DRIFT: {
		"name": "Navigation Drift",
		"room": ShipTypes.RoomType.BRIDGE,
		"resource_drain": "fuel",
		"drain_rate": 1.0,
		"fix_time": 8.0,
		"best_crew": CrewRole.COMMANDER,
		"icon": "NAV",
		"sound": "beep",
		# CRISIS mode: station task (no item needed)
		"requires_item": "",
		"is_station_task": true,
		"crisis_work_time": 4.0
	},
	CrisisType.COMMS_FAILURE: {
		"name": "Comms Failure",
		"room": ShipTypes.RoomType.BRIDGE,
		"resource_drain": "morale",
		"drain_rate": 2.0,
		"fix_time": 6.0,
		"best_crew": CrewRole.COMMANDER,
		"icon": "COM",
		"sound": "static",
		# CRISIS mode: station task (no item needed)
		"requires_item": "",
		"is_station_task": true,
		"crisis_work_time": 3.0
	},
	CrisisType.FIRE: {
		"name": "Fire!",
		"room": null,  # Can be any room
		"resource_drain": "oxygen",
		"drain_rate": 4.0,
		"fix_time": 4.0,
		"best_crew": CrewRole.ENGINEER,
		"icon": "FIRE",
		"sound": "fire",
		"special": "spreads",  # Can spread to adjacent rooms
		# CRISIS mode properties
		"requires_item": "extinguisher",
		"is_station_task": false,
		"crisis_work_time": 3.0
	},
	CrisisType.EQUIPMENT_FAULT: {
		"name": "Equipment Fault",
		"room": ShipTypes.RoomType.ENGINEERING,
		"resource_drain": "power",
		"drain_rate": 1.5,
		"fix_time": 6.0,
		"best_crew": CrewRole.ENGINEER,
		"icon": "EQPT",
		"sound": "mechanical",
		# CRISIS mode properties
		"requires_item": "spare_part",
		"is_station_task": false,
		"crisis_work_time": 4.0
	},
	CrisisType.FOOD_CONTAMINATION: {
		"name": "Food Contamination",
		"room": ShipTypes.RoomType.CARGO_BAY,
		"resource_drain": "food",
		"drain_rate": 3.0,
		"fix_time": 8.0,
		"best_crew": CrewRole.SCIENTIST,
		"icon": "FOOD",
		"sound": "squelch",
		# CRISIS mode properties
		"requires_item": "sanitizer",
		"is_station_task": false,
		"crisis_work_time": 4.0
	}
}

# ============================================================================
# SEVERITY MULTIPLIERS
# ============================================================================

const SEVERITY_DRAIN_MULTIPLIER = {
	Severity.EMERGING: 0.5,
	Severity.ACTIVE: 1.0,
	Severity.CRITICAL: 2.0,
	Severity.CATASTROPHIC: 4.0
}

const SEVERITY_COLORS = {
	Severity.EMERGING: Color(0.9, 0.8, 0.2),      # Yellow
	Severity.ACTIVE: Color(1.0, 0.6, 0.2),        # Orange
	Severity.CRITICAL: Color(1.0, 0.2, 0.2),      # Red
	Severity.CATASTROPHIC: Color(1.0, 0.1, 0.1)  # Bright red (flashes)
}

# ============================================================================
# CREW EFFICIENCY
# ============================================================================

# Multiplier for fix time when crew matches best_crew
const SPECIALIST_BONUS = 0.2  # 20% faster (1.2x)

# Commander provides this bonus to adjacent crew
const COMMANDER_ADJACENT_BONUS = 0.25  # 25% faster

# ============================================================================
# FACTORY FUNCTIONS
# ============================================================================

static func create_crisis(crisis_type: CrisisType, room_override = null) -> Dictionary:
	var definition = CRISIS_DEFINITIONS.get(crisis_type, {})
	var room = room_override if room_override != null else definition.get("room")

	return {
		"id": _generate_id(),
		"type": crisis_type,
		"name": definition.get("name", "Unknown Crisis"),
		"room": room,
		"severity": Severity.EMERGING,
		"time_in_severity": 0.0,
		"total_time": 0.0,
		"resource_drain": definition.get("resource_drain", "none"),
		"drain_rate": definition.get("drain_rate", 1.0),
		"fix_time": definition.get("fix_time", BASE_FIX_TIME),
		"fix_progress": 0.0,
		"assigned_crew": "",  # Role of assigned crew, empty if none
		"best_crew": definition.get("best_crew", CrewRole.ENGINEER),
		"icon": definition.get("icon", "???"),
		"special": definition.get("special", "")
	}

static var _id_counter: int = 0

static func _generate_id() -> String:
	_id_counter += 1
	return "crisis_%d_%d" % [Time.get_ticks_msec(), _id_counter]

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func get_severity_name(severity: Severity) -> String:
	match severity:
		Severity.EMERGING: return "Emerging"
		Severity.ACTIVE: return "Active"
		Severity.CRITICAL: return "CRITICAL"
		Severity.CATASTROPHIC: return "CATASTROPHIC"
	return "Unknown"

static func get_severity_color(severity: Severity) -> Color:
	return SEVERITY_COLORS.get(severity, Color.WHITE)

static func get_drain_multiplier(severity: Severity) -> float:
	return SEVERITY_DRAIN_MULTIPLIER.get(severity, 1.0)

static func get_escalation_time(severity: Severity) -> float:
	return ESCALATION_TIMES.get(severity, -1.0)

static func get_crisis_definition(crisis_type: CrisisType) -> Dictionary:
	return CRISIS_DEFINITIONS.get(crisis_type, {})

static func get_crew_efficiency(crisis: Dictionary, crew_role: String) -> float:
	## Returns fix speed multiplier (higher = faster)
	var best_crew = crisis.get("best_crew", CrewRole.ENGINEER)
	var role_enum = _role_string_to_enum(crew_role)

	if role_enum == best_crew:
		return 1.0 + SPECIALIST_BONUS  # 1.2x speed
	elif role_enum == CrewRole.COMMANDER:
		return 1.0 + COMMANDER_ADJACENT_BONUS  # 1.25x speed
	else:
		return 1.0  # Normal speed

static func _role_string_to_enum(role: String) -> CrewRole:
	match role.to_lower():
		"commander": return CrewRole.COMMANDER
		"engineer": return CrewRole.ENGINEER
		"scientist": return CrewRole.SCIENTIST
		"medical": return CrewRole.MEDICAL
	return CrewRole.ENGINEER  # Default

static func get_random_crisis_type() -> CrisisType:
	var types = CRISIS_DEFINITIONS.keys()
	return types[randi() % types.size()]

static func get_random_room() -> ShipTypes.RoomType:
	var rooms = [
		ShipTypes.RoomType.BRIDGE,
		ShipTypes.RoomType.ENGINEERING,
		ShipTypes.RoomType.LIFE_SUPPORT,
		ShipTypes.RoomType.MEDICAL,
		ShipTypes.RoomType.CARGO_BAY
	]
	return rooms[randi() % rooms.size()]

# ============================================================================
# CRISIS MODE HELPERS
# ============================================================================

static func crisis_requires_item(crisis_type: CrisisType) -> bool:
	## Check if crisis needs an item to fix (vs station task)
	var def = CRISIS_DEFINITIONS.get(crisis_type, {})
	var item = def.get("requires_item", "")
	return item != ""

static func get_required_item(crisis_type: CrisisType) -> String:
	## Get the item type string needed to fix this crisis
	var def = CRISIS_DEFINITIONS.get(crisis_type, {})
	return def.get("requires_item", "")

static func is_station_task(crisis_type: CrisisType) -> bool:
	## Check if crisis is a station task (no item needed)
	var def = CRISIS_DEFINITIONS.get(crisis_type, {})
	return def.get("is_station_task", false)

static func get_crisis_work_time(crisis_type: CrisisType) -> float:
	## Get the work time for CRISIS mode (after reaching location/delivering item)
	var def = CRISIS_DEFINITIONS.get(crisis_type, {})
	return def.get("crisis_work_time", 4.0)

static func get_crisis_room(crisis: Dictionary) -> ShipTypes.RoomType:
	## Get the room where a crisis is happening
	return crisis.get("room", ShipTypes.RoomType.ENGINEERING)
