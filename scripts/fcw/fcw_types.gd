extends RefCounted
class_name FCWTypes

## First Contact War - Type Definitions
## Mindustry-style production + Sins/Rebellion fleet management

# ============================================================================
# ENUMS
# ============================================================================

enum ZoneId {
	KUIPER,
	JUPITER,
	ASTEROID_BELT,
	SATURN,
	MARS,
	EARTH
}

enum ZoneStatus {
	CONTROLLED,
	UNDER_ATTACK,
	FALLEN
}

enum ShipType {
	FRIGATE,
	CRUISER,
	CARRIER,
	DREADNOUGHT
}

enum BuildingType {
	MINE,
	REFINERY,
	POWER_PLANT,
	ELECTRONICS_FACTORY,
	WEAPONS_LAB,
	SHIPYARD
}

enum FleetOrder {
	DEFEND,
	DELAY,
	ESCORT
}

enum VictoryTier {
	LEGENDARY,   # 500M+
	HEROIC,      # 200-500M
	PYRRHIC,     # 50-200M
	TRAGIC,      # 10-50M
	ANNIHILATION # <10M
}

# ============================================================================
# CONSTANTS
# ============================================================================

const ZONE_NAMES = {
	ZoneId.KUIPER: "Kuiper Belt",
	ZoneId.JUPITER: "Jupiter",
	ZoneId.ASTEROID_BELT: "Asteroid Belt",
	ZoneId.SATURN: "Saturn",
	ZoneId.MARS: "Mars",
	ZoneId.EARTH: "Earth"
}

const ZONE_RESOURCES = {
	ZoneId.KUIPER: "rare",
	ZoneId.JUPITER: "energy",
	ZoneId.ASTEROID_BELT: "ore",
	ZoneId.SATURN: "rare",
	ZoneId.MARS: "shipyard_bonus",
	ZoneId.EARTH: "population"
}

# Zone adjacency - which zones connect to which
const ZONE_CONNECTIONS = {
	ZoneId.KUIPER: [ZoneId.JUPITER, ZoneId.ASTEROID_BELT, ZoneId.SATURN],
	ZoneId.JUPITER: [ZoneId.KUIPER, ZoneId.MARS],
	ZoneId.ASTEROID_BELT: [ZoneId.KUIPER, ZoneId.MARS],
	ZoneId.SATURN: [ZoneId.KUIPER, ZoneId.MARS],
	ZoneId.MARS: [ZoneId.JUPITER, ZoneId.ASTEROID_BELT, ZoneId.SATURN, ZoneId.EARTH],
	ZoneId.EARTH: [ZoneId.MARS]
}

# Ship definitions
const SHIP_DEFS = {
	ShipType.FRIGATE: {
		"name": "Frigate",
		"cost": {"steel": 10, "electronics": 5, "weapons": 2},
		"combat_power": 10,
		"build_turns": 1
	},
	ShipType.CRUISER: {
		"name": "Cruiser",
		"cost": {"steel": 30, "electronics": 15, "weapons": 8},
		"combat_power": 40,
		"build_turns": 2
	},
	ShipType.CARRIER: {
		"name": "Carrier",
		"cost": {"steel": 50, "electronics": 30, "weapons": 5},
		"combat_power": 25,
		"build_turns": 2,
		"defense_bonus": 0.5  # +50% zone defense
	},
	ShipType.DREADNOUGHT: {
		"name": "Dreadnought",
		"cost": {"steel": 100, "electronics": 50, "weapons": 20},
		"combat_power": 150,
		"build_turns": 3
	}
}

# Building definitions
const BUILDING_DEFS = {
	BuildingType.MINE: {
		"name": "Mine",
		"input": {},
		"output": {"ore": 10},
		"workers": 100
	},
	BuildingType.REFINERY: {
		"name": "Refinery",
		"input": {"ore": 10},
		"output": {"steel": 5},
		"workers": 50
	},
	BuildingType.POWER_PLANT: {
		"name": "Power Plant",
		"input": {},
		"output": {"energy": 20},
		"workers": 50
	},
	BuildingType.ELECTRONICS_FACTORY: {
		"name": "Electronics Factory",
		"input": {"energy": 5},
		"output": {"electronics": 3},
		"workers": 100
	},
	BuildingType.WEAPONS_LAB: {
		"name": "Weapons Lab",
		"input": {"rare": 5, "energy": 5},
		"output": {"weapons": 2},
		"workers": 200
	},
	BuildingType.SHIPYARD: {
		"name": "Shipyard",
		"input": {},  # Ships consume resources directly
		"output": {},
		"workers": 500
	}
}

# Herald attack scaling
const HERALD_STRENGTH_BY_TURN = [
	50, 60, 70, 80, 100,           # Turns 1-5
	150, 180, 220, 260, 300,       # Turns 6-10
	400, 450, 500, 550, 600,       # Turns 11-15
	800, 900, 1000, 1100, 1200,    # Turns 16-20
	1500, 1700, 1900, 2100, 2500   # Turns 21-25
]

# ============================================================================
# DATA STRUCTURES
# ============================================================================

static func create_initial_state() -> Dictionary:
	return {
		"turn": 1,
		"resources": {
			"ore": 100,
			"steel": 50,
			"energy": 100,
			"electronics": 20,
			"rare": 30,
			"weapons": 10
		},
		"zones": _create_initial_zones(),
		"fleet": {
			ShipType.FRIGATE: 10,
			ShipType.CRUISER: 3,
			ShipType.CARRIER: 1,
			ShipType.DREADNOUGHT: 0
		},
		"fleet_assignments": {},  # zone_id -> {ship_type -> count}
		"fleet_orders": {},       # zone_id -> FleetOrder
		"production_queue": [],   # [{type: ShipType, turns_remaining: int}]
		"lives_evacuated": 0,
		"lives_lost": 0,
		"total_population": 8_000_000_000,  # 8 billion
		"herald_attack_target": ZoneId.KUIPER,
		"herald_strength": 50,
		"event_log": [],
		"game_over": false,
		"victory_tier": VictoryTier.ANNIHILATION
	}

static func _create_initial_zones() -> Dictionary:
	return {
		ZoneId.KUIPER: create_zone({
			"id": ZoneId.KUIPER,
			"population": 50_000,
			"workers": 30_000,
			"buildings": {BuildingType.MINE: 1, BuildingType.WEAPONS_LAB: 1}
		}),
		ZoneId.JUPITER: create_zone({
			"id": ZoneId.JUPITER,
			"population": 2_000_000,
			"workers": 500_000,
			"buildings": {BuildingType.POWER_PLANT: 3, BuildingType.ELECTRONICS_FACTORY: 2}
		}),
		ZoneId.ASTEROID_BELT: create_zone({
			"id": ZoneId.ASTEROID_BELT,
			"population": 500_000,
			"workers": 300_000,
			"buildings": {BuildingType.MINE: 5, BuildingType.REFINERY: 3}
		}),
		ZoneId.SATURN: create_zone({
			"id": ZoneId.SATURN,
			"population": 1_000_000,
			"workers": 400_000,
			"buildings": {BuildingType.MINE: 2, BuildingType.WEAPONS_LAB: 2}
		}),
		ZoneId.MARS: create_zone({
			"id": ZoneId.MARS,
			"population": 50_000_000,
			"workers": 10_000_000,
			"buildings": {BuildingType.SHIPYARD: 3, BuildingType.REFINERY: 2, BuildingType.POWER_PLANT: 2}
		}),
		ZoneId.EARTH: create_zone({
			"id": ZoneId.EARTH,
			"population": 8_000_000_000,
			"workers": 500_000_000,
			"buildings": {
				BuildingType.MINE: 10, BuildingType.REFINERY: 8,
				BuildingType.POWER_PLANT: 10, BuildingType.ELECTRONICS_FACTORY: 5,
				BuildingType.WEAPONS_LAB: 3, BuildingType.SHIPYARD: 5
			}
		})
	}

static func create_zone(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"id": ZoneId.EARTH,
		"status": ZoneStatus.CONTROLLED,
		"population": 0,
		"workers": 0,
		"buildings": {},
		"assigned_fleet": {}  # ship_type -> count
	}
	return _merge(defaults, overrides)

static func create_production_order(ship_type: int) -> Dictionary:
	var ship_def = SHIP_DEFS[ship_type]
	return {
		"ship_type": ship_type,
		"turns_remaining": ship_def.build_turns
	}

static func create_event(title: String, description: String, choices: Array) -> Dictionary:
	return {
		"title": title,
		"description": description,
		"choices": choices
	}

static func create_log_entry(turn: int, message: String, is_critical: bool = false) -> Dictionary:
	return {
		"turn": turn,
		"message": message,
		"is_critical": is_critical
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

static func get_zone_name(zone_id: int) -> String:
	return ZONE_NAMES.get(zone_id, "Unknown")

static func get_ship_name(ship_type: int) -> String:
	return SHIP_DEFS.get(ship_type, {}).get("name", "Unknown")

static func get_ship_combat_power(ship_type: int) -> int:
	return SHIP_DEFS.get(ship_type, {}).get("combat_power", 0)

static func get_building_name(building_type: int) -> String:
	return BUILDING_DEFS.get(building_type, {}).get("name", "Unknown")

static func get_victory_tier(lives_evacuated: int) -> int:
	if lives_evacuated >= 500_000_000:
		return VictoryTier.LEGENDARY
	elif lives_evacuated >= 200_000_000:
		return VictoryTier.HEROIC
	elif lives_evacuated >= 50_000_000:
		return VictoryTier.PYRRHIC
	elif lives_evacuated >= 10_000_000:
		return VictoryTier.TRAGIC
	else:
		return VictoryTier.ANNIHILATION

static func get_victory_tier_name(tier: int) -> String:
	match tier:
		VictoryTier.LEGENDARY: return "LEGENDARY"
		VictoryTier.HEROIC: return "HEROIC"
		VictoryTier.PYRRHIC: return "PYRRHIC"
		VictoryTier.TRAGIC: return "TRAGIC"
		_: return "ANNIHILATION"

static func get_victory_description(tier: int) -> String:
	match tier:
		VictoryTier.LEGENDARY: return "They will remember what we did here"
		VictoryTier.HEROIC: return "Enough to rebuild"
		VictoryTier.PYRRHIC: return "A remnant survives"
		VictoryTier.TRAGIC: return "Scattered survivors"
		_: return "Humanity's light flickers"

static func get_herald_strength_for_turn(turn: int) -> int:
	var idx = mini(turn - 1, HERALD_STRENGTH_BY_TURN.size() - 1)
	return HERALD_STRENGTH_BY_TURN[idx]

static func format_population(pop: int) -> String:
	if pop >= 1_000_000_000:
		return "%.1fB" % (pop / 1_000_000_000.0)
	elif pop >= 1_000_000:
		return "%.1fM" % (pop / 1_000_000.0)
	elif pop >= 1_000:
		return "%.0fK" % (pop / 1_000.0)
	return str(pop)
