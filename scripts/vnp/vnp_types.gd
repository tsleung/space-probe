class_name VNPTypes
extends RefCounted

## Pure data types for Von Neumann Probe game mode
## Following the pattern from game_types.gd

# ============================================================================
# ENUMS
# ============================================================================

enum StarType {
	RED_DWARF,      # Common, low resources, safe
	YELLOW,         # Balanced resources
	ORANGE,         # Good resources
	BLUE_GIANT,     # Rich but dangerous
	WHITE_DWARF,    # Rare elements
	NEUTRON         # Exotic, very dangerous
}

enum ProbeStatus {
	IDLE,           # Ready for orders
	MINING,         # Extracting resources
	TRAVELING,      # Moving between stars
	REPLICATING,    # Building new probe
	DAMAGED         # Reduced efficiency
}

enum EventCategory {
	ANOMALY,        # Research opportunity
	HAZARD,         # Danger
	DISCOVERY,      # Resource/tech find
	ENCOUNTER       # Alien contact
}

# ============================================================================
# CONSTANTS
# ============================================================================

const REPLICATION_COST = {
	"iron": 80,
	"energy": 200
}
const REPLICATION_TURNS = 3

const STAR_COLORS = {
	StarType.RED_DWARF: Color(1.0, 0.4, 0.3),
	StarType.YELLOW: Color(1.0, 1.0, 0.5),
	StarType.ORANGE: Color(1.0, 0.7, 0.3),
	StarType.BLUE_GIANT: Color(0.5, 0.7, 1.0),
	StarType.WHITE_DWARF: Color(0.95, 0.95, 1.0),
	StarType.NEUTRON: Color(0.8, 0.5, 1.0)
}

const STAR_NAMES_PREFIX = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa"]
const STAR_NAMES_SUFFIX = ["Centauri", "Cygni", "Eridani", "Draconis", "Pegasi", "Lyrae", "Orionis", "Tauri", "Aquarii", "Phoenicis"]

# ============================================================================
# DATA STRUCTURES
# ============================================================================

## Creates a Probe record
static func create_probe(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"id": "",
		"name": "",
		"status": ProbeStatus.IDLE,
		"current_system": "",       # System ID where probe is located
		"target_system": "",        # Destination if traveling
		"travel_progress": 0,       # Turns remaining for travel
		"task_progress": 0,         # Turns remaining for current task
		"health": 100.0,
		"efficiency": 1.0,
		"generation": 1,            # Which generation (1 = original)
		"created_turn": 0
	}
	return _merge(defaults, overrides)

## Creates a StarSystem record
static func create_star_system(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"id": "",
		"name": "",
		"star_type": StarType.YELLOW,
		"position": Vector2.ZERO,   # Position on galaxy map
		"connections": [],          # IDs of connected systems
		"resources": {
			"iron": 0,
			"rare": 0
		},
		"max_resources": {
			"iron": 0,
			"rare": 0
		},
		"danger_level": 0.0,        # 0-1, affects hazard events
		"is_explored": false,
		"has_anomaly": false,
		"anomaly_investigated": false
	}
	return _merge(defaults, overrides)

## Creates the main VNP game state
static func create_vnp_state(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		# Time
		"current_turn": 1,
		"year": 2200,               # Display year

		# Global resources (shared pool)
		"resources": {
			"iron": 100,
			"energy": 500,
			"rare": 0
		},

		# Probes
		"probes": {},               # probe_id -> ProbeData
		"next_probe_id": 2,
		"total_probes_built": 1,
		"probes_lost": 0,

		# Galaxy
		"systems": {},              # system_id -> StarSystemData
		"home_system": "",
		"systems_explored": 0,
		"total_systems": 0,

		# Events
		"pending_event": {},        # Current event needing resolution
		"event_log": [],

		# Win/Lose
		"is_game_over": false,
		"victory": false,
		"game_over_reason": "",
		"final_score": 0,

		# Stats
		"peak_probes": 1,
		"total_iron_mined": 0,
		"total_rare_mined": 0,

		"random_seed": 0
	}
	return _merge(defaults, overrides)

## Creates an Event record
static func create_event(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"id": "",
		"category": EventCategory.ANOMALY,
		"title": "",
		"description": "",
		"choices": [],              # Array of {id, text, effects}
		"affected_probe": "",       # Probe ID this affects
		"affected_system": ""       # System ID this affects
	}
	return _merge(defaults, overrides)

## Creates an event choice
static func create_choice(id: String, text: String, effects: Dictionary) -> Dictionary:
	return {
		"id": id,
		"text": text,
		"effects": effects
	}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

static func _merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result = base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
	return result

static func with_field(record: Dictionary, field: String, value) -> Dictionary:
	var result = record.duplicate(true)
	result[field] = value
	return result

static func with_fields(record: Dictionary, updates: Dictionary) -> Dictionary:
	return _merge(record, updates)

## Generate a star name from seed
static func generate_star_name(index: int, seed: int) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed + index * 7919  # Prime for variety
	var prefix = STAR_NAMES_PREFIX[rng.randi() % STAR_NAMES_PREFIX.size()]
	var suffix = STAR_NAMES_SUFFIX[rng.randi() % STAR_NAMES_SUFFIX.size()]
	var num = rng.randi_range(1, 99)
	return "%s %s-%d" % [prefix, suffix, num]

## Get color for star type
static func get_star_color(star_type: int) -> Color:
	return STAR_COLORS.get(star_type, Color.WHITE)

## Get display name for probe status
static func get_status_name(status: int) -> String:
	match status:
		ProbeStatus.IDLE: return "Idle"
		ProbeStatus.MINING: return "Mining"
		ProbeStatus.TRAVELING: return "Traveling"
		ProbeStatus.REPLICATING: return "Replicating"
		ProbeStatus.DAMAGED: return "Damaged"
		_: return "Unknown"
