extends RefCounted
class_name ControlSurface

## Control Surface definitions for MOT Phase 2
## 6 Core Systems with meaningful trade-offs (FTL-inspired)
##
## Design: Fewer systems, deeper choices. Each system has states where
## different options are optimal in different situations.
## See: docs/mot/control-surfaces.md

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# ENUMS
# ============================================================================

enum SurfaceType {
	LEVER,      # Multi-position switch (OFF/ON, IDLE/CRUISE/BURN)
	BUTTON      # One-time activation (Emergency Power)
}

enum SurfaceState {
	WORKING,    # Normal operation
	USING,      # Crew currently interacting
	BROKEN      # Damaged, needs repair
}

## The 6 core systems + emergency power button
enum SurfaceId {
	POWER_CORE,      # Engineering - power generation, heat risk
	SHIELDS,         # Bridge - damage reduction
	ENGINE,          # Engineering - speed/fuel trade-off
	LIFE_SUPPORT,    # Life Support Bay - O2 and water production
	MEDICAL_BAY,     # Medical - crew healing
	SENSORS,         # Bridge - early warning
	EMERGENCY_POWER  # Engineering - crisis button
}

# ============================================================================
# SURFACE DEFINITIONS
# ============================================================================

## All power drain values are per hour to match documentation
const SURFACE_DEFINITIONS = {
	SurfaceId.POWER_CORE: {
		"name": "Power Core",
		"short_name": "PWR",
		"type": SurfaceType.LEVER,
		"room": ShipTypes.RoomType.ENGINEERING,
		"tile": Vector2i(4, 6),
		"levels": ["NORMAL", "OVERDRIVE"],
		"power_drain": [0.0, 0.0],  # Generates power, doesn't drain
		"effect": {
			"power_output": [10.0, 15.0],  # Per hour
			"heat_rate": [0.0, 2.0]  # Heat accumulation per hour in overdrive
		},
		"interaction_time": 2.0,
		"repair_time": 15.0
	},
	SurfaceId.SHIELDS: {
		"name": "Shields",
		"short_name": "SHLD",
		"type": SurfaceType.LEVER,
		"room": ShipTypes.RoomType.BRIDGE,
		"tile": Vector2i(28, 4),
		"levels": ["OFF", "ON"],
		"power_drain": [0.0, 6.0],  # 6/hr when on
		"effect": {
			"damage_reduction": [0.0, 0.50]  # 50% when on
		},
		"interaction_time": 1.0,
		"repair_time": 6.0
	},
	SurfaceId.ENGINE: {
		"name": "Engine",
		"short_name": "ENG",
		"type": SurfaceType.LEVER,
		"room": ShipTypes.RoomType.ENGINEERING,
		"tile": Vector2i(8, 6),
		"levels": ["IDLE", "CRUISE", "BURN"],
		"power_drain": [1.0, 3.0, 8.0],  # Per hour
		"effect": {
			"speed_multiplier": [0.5, 1.0, 1.5],
			"fuel_multiplier": [0.25, 1.0, 2.0]
		},
		"interaction_time": 0.8,
		"repair_time": 10.0
	},
	SurfaceId.LIFE_SUPPORT: {
		"name": "Life Support",
		"short_name": "LIFE",
		"type": SurfaceType.LEVER,
		"room": ShipTypes.RoomType.LIFE_SUPPORT,
		"tile": Vector2i(12, 6),
		"levels": ["MINIMAL", "NORMAL", "BOOSTED"],
		"power_drain": [2.0, 4.0, 8.0],  # Per hour
		"effect": {
			"o2_multiplier": [0.5, 1.0, 1.5],
			"water_multiplier": [0.5, 1.0, 1.5]
		},
		"interaction_time": 1.0,
		"repair_time": 8.0
	},
	SurfaceId.MEDICAL_BAY: {
		"name": "Medical Bay",
		"short_name": "MED",
		"type": SurfaceType.LEVER,
		"room": ShipTypes.RoomType.MEDICAL,
		"tile": Vector2i(18, 6),
		"levels": ["OFF", "ON"],
		"power_drain": [0.0, 4.0],  # 4/hr when on
		"effect": {
			"healing_rate": [0.0, 1.0]  # No healing when off
		},
		"interaction_time": 0.8,
		"repair_time": 5.0
	},
	SurfaceId.SENSORS: {
		"name": "Sensors",
		"short_name": "SENS",
		"type": SurfaceType.LEVER,
		"room": ShipTypes.RoomType.BRIDGE,
		"tile": Vector2i(30, 6),
		"levels": ["OFF", "ON"],
		"power_drain": [0.0, 2.0],  # 2/hr when on
		"effect": {
			"event_warning_days": [0, 1]  # +1 day warning when on
		},
		"interaction_time": 0.8,
		"repair_time": 4.0
	},
	SurfaceId.EMERGENCY_POWER: {
		"name": "Emergency Power",
		"short_name": "EMRG",
		"type": SurfaceType.BUTTON,
		"room": ShipTypes.RoomType.ENGINEERING,
		"tile": Vector2i(2, 6),
		"levels": ["STANDBY", "ACTIVE", "DEPLETED"],
		"power_drain": [0.0, 0.0, 0.0],  # Handled specially
		"effect": {
			"power_boost": 10.0,  # +10 power when active
			"duration": 30.0,  # Seconds
			"recharge_time": 300.0  # 5 minutes
		},
		"interaction_time": 0.5,
		"repair_time": 8.0
	}
}

# ============================================================================
# HEAT MECHANIC CONSTANTS
# ============================================================================

const HEAT_DISSIPATION_RATE = 1.0  # Heat lost per hour in NORMAL mode
const HEAT_WARNING_THRESHOLD = 6.0
const HEAT_DANGER_THRESHOLD = 8.0
const HEAT_CRITICAL_THRESHOLD = 10.0
const HEAT_EXPLOSION_TIME = 10.0  # Seconds at critical before explosion

# ============================================================================
# POWER CONSTANTS (for reference, actual calc in manager)
# ============================================================================

const SOLAR_PANEL_OUTPUT = 5.0  # Per hour (passive, not a surface)

# ============================================================================
# VISUAL DEFINITIONS
# ============================================================================

const STATE_COLORS = {
	SurfaceState.WORKING: Color(0.2, 0.8, 0.2),   # Green
	SurfaceState.USING: Color(1.0, 0.9, 0.3),     # Yellow
	SurfaceState.BROKEN: Color(0.9, 0.2, 0.2)     # Red
}

const LEVEL_COLORS = {
	"OFF": Color(0.3, 0.3, 0.3),        # Gray
	"ON": Color(0.2, 0.8, 0.2),         # Green
	"NORMAL": Color(0.2, 0.8, 0.2),     # Green
	"MINIMAL": Color(0.8, 0.6, 0.2),    # Orange
	"BOOSTED": Color(0.3, 0.7, 1.0),    # Blue
	"IDLE": Color(0.5, 0.5, 0.5),       # Gray
	"CRUISE": Color(0.2, 0.8, 0.2),     # Green
	"BURN": Color(1.0, 0.5, 0.2),       # Orange
	"OVERDRIVE": Color(1.0, 0.3, 0.2),  # Red-orange
	"STANDBY": Color(0.8, 0.8, 0.2),    # Yellow
	"ACTIVE": Color(0.2, 1.0, 0.4),     # Bright green
	"DEPLETED": Color(0.4, 0.4, 0.4)    # Dark gray
}

# ============================================================================
# FACTORY FUNCTIONS
# ============================================================================

static func create_surface_state(surface_id: SurfaceId) -> Dictionary:
	## Create initial state for a control surface
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	var levels = def.get("levels", [])

	# Default to middle/normal level
	var default_level = 0
	if surface_id == SurfaceId.ENGINE:
		default_level = 1  # CRUISE
	elif surface_id == SurfaceId.LIFE_SUPPORT:
		default_level = 1  # NORMAL
	elif surface_id == SurfaceId.POWER_CORE:
		default_level = 0  # NORMAL (not overdrive)

	return {
		"id": surface_id,
		"state": SurfaceState.WORKING,
		"level": default_level,
		"heat": 0.0,  # For power core
		"use_timer": 0.0,
		"broken_time": 0.0,
		"cooldown": 0.0,  # For emergency power
		"active_duration": 0.0  # For emergency power active state
	}

static func get_all_surface_ids() -> Array:
	return SURFACE_DEFINITIONS.keys()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func get_definition(surface_id: SurfaceId) -> Dictionary:
	return SURFACE_DEFINITIONS.get(surface_id, {})

static func get_name(surface_id: SurfaceId) -> String:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("name", "Unknown")

static func get_short_name(surface_id: SurfaceId) -> String:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("short_name", "???")

static func get_type(surface_id: SurfaceId) -> SurfaceType:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("type", SurfaceType.LEVER)

static func get_room(surface_id: SurfaceId) -> ShipTypes.RoomType:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("room", ShipTypes.RoomType.BRIDGE)

static func get_tile(surface_id: SurfaceId) -> Vector2i:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("tile", Vector2i.ZERO)

static func get_levels(surface_id: SurfaceId) -> Array:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("levels", [])

static func get_level_name(surface_id: SurfaceId, level: int) -> String:
	var levels = get_levels(surface_id)
	if level >= 0 and level < levels.size():
		return levels[level]
	return "UNKNOWN"

static func get_power_drain(surface_id: SurfaceId, level: int) -> float:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	var drains = def.get("power_drain", [0.0])
	if level >= 0 and level < drains.size():
		return drains[level]
	return 0.0

static func get_effect(surface_id: SurfaceId, effect_name: String, level: int):
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	var effects = def.get("effect", {})
	var values = effects.get(effect_name)

	if values is Array and level >= 0 and level < values.size():
		return values[level]
	elif values != null and not values is Array:
		return values  # Single value effect (like emergency power boost)
	return null

static func get_interaction_time(surface_id: SurfaceId) -> float:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("interaction_time", 1.0)

static func get_repair_time(surface_id: SurfaceId) -> float:
	var def = SURFACE_DEFINITIONS.get(surface_id, {})
	return def.get("repair_time", 5.0)

static func get_state_color(state: SurfaceState) -> Color:
	return STATE_COLORS.get(state, Color.WHITE)

static func get_level_color(level_name: String) -> Color:
	return LEVEL_COLORS.get(level_name, Color.WHITE)

static func can_interact(surface_id: SurfaceId) -> bool:
	## All our systems are interactive
	return true

static func get_surfaces_in_room(room: ShipTypes.RoomType) -> Array:
	## Get all surface IDs in a given room
	var surfaces = []
	for id in SURFACE_DEFINITIONS:
		if SURFACE_DEFINITIONS[id].get("room") == room:
			surfaces.append(id)
	return surfaces

# ============================================================================
# POWER CALCULATIONS
# ============================================================================

static func calculate_total_drain(surface_states: Dictionary) -> float:
	## Calculate total power drain from all active surfaces (per hour)
	var total = 0.0
	for surface_id in surface_states:
		var state = surface_states[surface_id]
		if state.state == SurfaceState.WORKING or state.state == SurfaceState.USING:
			total += get_power_drain(surface_id, state.level)
	return total

static func calculate_total_generation(surface_states: Dictionary) -> float:
	## Calculate total power generation (per hour)
	var total = SOLAR_PANEL_OUTPUT  # Passive solar

	# Power Core
	var core = surface_states.get(SurfaceId.POWER_CORE, {})
	if core.get("state", SurfaceState.BROKEN) != SurfaceState.BROKEN:
		var output = get_effect(SurfaceId.POWER_CORE, "power_output", core.get("level", 0))
		if output != null:
			total += output

	# Emergency Power (when active)
	var emergency = surface_states.get(SurfaceId.EMERGENCY_POWER, {})
	if emergency.get("level", 0) == 1:  # ACTIVE
		var boost = get_effect(SurfaceId.EMERGENCY_POWER, "power_boost", 0)
		if boost != null:
			total += boost

	return total

static func calculate_net_power(surface_states: Dictionary) -> float:
	return calculate_total_generation(surface_states) - calculate_total_drain(surface_states)

# ============================================================================
# EFFECT AGGREGATION
# ============================================================================

static func get_damage_reduction(surface_states: Dictionary) -> float:
	var shields = surface_states.get(SurfaceId.SHIELDS, {})
	if shields.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0.0
	var reduction = get_effect(SurfaceId.SHIELDS, "damage_reduction", shields.get("level", 0))
	return reduction if reduction != null else 0.0

static func get_speed_multiplier(surface_states: Dictionary) -> float:
	var engine = surface_states.get(SurfaceId.ENGINE, {})
	if engine.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0.0  # No thrust
	var speed = get_effect(SurfaceId.ENGINE, "speed_multiplier", engine.get("level", 1))
	return speed if speed != null else 1.0

static func get_fuel_multiplier(surface_states: Dictionary) -> float:
	var engine = surface_states.get(SurfaceId.ENGINE, {})
	if engine.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0.0
	var fuel = get_effect(SurfaceId.ENGINE, "fuel_multiplier", engine.get("level", 1))
	return fuel if fuel != null else 1.0

static func get_o2_multiplier(surface_states: Dictionary) -> float:
	var life = surface_states.get(SurfaceId.LIFE_SUPPORT, {})
	if life.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0.0  # No O2 production
	var mult = get_effect(SurfaceId.LIFE_SUPPORT, "o2_multiplier", life.get("level", 1))
	return mult if mult != null else 1.0

static func get_water_multiplier(surface_states: Dictionary) -> float:
	var life = surface_states.get(SurfaceId.LIFE_SUPPORT, {})
	if life.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0.0
	var mult = get_effect(SurfaceId.LIFE_SUPPORT, "water_multiplier", life.get("level", 1))
	return mult if mult != null else 1.0

static func get_healing_rate(surface_states: Dictionary) -> float:
	var med = surface_states.get(SurfaceId.MEDICAL_BAY, {})
	if med.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0.0
	var rate = get_effect(SurfaceId.MEDICAL_BAY, "healing_rate", med.get("level", 0))
	return rate if rate != null else 0.0

static func get_event_warning_days(surface_states: Dictionary) -> int:
	var sensors = surface_states.get(SurfaceId.SENSORS, {})
	if sensors.get("state", SurfaceState.BROKEN) == SurfaceState.BROKEN:
		return 0
	var days = get_effect(SurfaceId.SENSORS, "event_warning_days", sensors.get("level", 0))
	return days if days != null else 0
