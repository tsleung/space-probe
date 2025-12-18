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

# Zone travel times (in weeks/turns) - represents realistic space travel
# Earth <-> Mars: 2 weeks (relatively close)
# Mars <-> Outer planets: 3 weeks
# Outer planets <-> Kuiper: 2 weeks
# Direct transit to non-adjacent zones takes sum of path segments
const ZONE_TRAVEL_TIMES = {
	# From Earth
	"EARTH_MARS": 2,
	"EARTH_JUPITER": 5,    # Via Mars
	"EARTH_ASTEROID_BELT": 5,
	"EARTH_SATURN": 5,
	"EARTH_KUIPER": 7,     # Via Mars + outer planet
	# From Mars
	"MARS_EARTH": 2,
	"MARS_JUPITER": 3,
	"MARS_ASTEROID_BELT": 3,
	"MARS_SATURN": 3,
	"MARS_KUIPER": 5,
	# From outer planets to each other (via Mars or Kuiper)
	"JUPITER_MARS": 3,
	"JUPITER_KUIPER": 2,
	"JUPITER_ASTEROID_BELT": 4,  # Via Mars
	"JUPITER_SATURN": 4,
	"ASTEROID_BELT_MARS": 3,
	"ASTEROID_BELT_KUIPER": 2,
	"ASTEROID_BELT_JUPITER": 4,
	"ASTEROID_BELT_SATURN": 4,
	"SATURN_MARS": 3,
	"SATURN_KUIPER": 2,
	"SATURN_JUPITER": 4,
	"SATURN_ASTEROID_BELT": 4,
	# From Kuiper
	"KUIPER_JUPITER": 2,
	"KUIPER_ASTEROID_BELT": 2,
	"KUIPER_SATURN": 2,
	"KUIPER_MARS": 5,
	"KUIPER_EARTH": 7,
}

static func get_travel_time(from_zone: int, to_zone: int) -> int:
	## Get travel time in weeks between two zones
	if from_zone == to_zone:
		return 0
	var key = "%s_%s" % [ZONE_NAMES.get(from_zone, "").to_upper().replace(" ", "_"),
						  ZONE_NAMES.get(to_zone, "").to_upper().replace(" ", "_")]
	# Simplify zone names for lookup
	key = key.replace("KUIPER_BELT", "KUIPER").replace("_BELT", "")
	return ZONE_TRAVEL_TIMES.get(key, 3)  # Default 3 weeks if not found

# Ship definitions
# speed_modifier: Multiplier for travel time (lower = faster)
#   Frigates: 0.7x (fast scouts)
#   Cruisers: 1.0x (standard)
#   Carriers: 1.4x (large, slow evacuation vessels)
#   Dreadnoughts: 1.3x (heavy but powerful)
const SHIP_DEFS = {
	ShipType.FRIGATE: {
		"name": "Frigate",
		"cost": {"steel": 10, "electronics": 5, "weapons": 2},
		"combat_power": 10,
		"build_turns": 1,
		"speed_modifier": 0.7  # Fast scouts
	},
	ShipType.CRUISER: {
		"name": "Cruiser",
		"cost": {"steel": 30, "electronics": 15, "weapons": 8},
		"combat_power": 40,
		"build_turns": 2,
		"speed_modifier": 1.0  # Standard speed
	},
	ShipType.CARRIER: {
		"name": "Carrier",
		"cost": {"steel": 50, "electronics": 30, "weapons": 5},
		"combat_power": 25,
		"build_turns": 2,
		"defense_bonus": 0.5,  # +50% zone defense
		"speed_modifier": 1.4  # Slow but essential for evacuation
	},
	ShipType.DREADNOUGHT: {
		"name": "Dreadnought",
		"cost": {"steel": 100, "electronics": 50, "weapons": 20},
		"combat_power": 150,
		"build_turns": 3,
		"speed_modifier": 1.3  # Heavy capital ship
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
		"fleets_in_transit": [],  # [{from_zone, to_zone, ship_type, count, turns_remaining}]
		"colony_ships_in_transit": [],  # [{souls_aboard, turns_remaining, total_turns, name, intercepted}]
		"colony_ships_safe": 0,  # Number of ships that reached safety
		"lives_evacuated": 0,
		"lives_lost": 0,
		"lives_intercepted": 0,  # Lives lost to Herald interception
		"total_population": 8_000_000_000,  # 8 billion
		"herald_attack_target": ZoneId.KUIPER,
		"herald_current_zone": ZoneId.KUIPER,  # Where Herald physically is
		"herald_transit": {},  # {from_zone, to_zone, turns_remaining, total_turns} when traveling
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

static func create_transit_order(from_zone: int, to_zone: int, ship_type: int, count: int) -> Dictionary:
	## Create a fleet transit order - ships traveling between zones
	## Travel time is modified by ship speed (Frigates fast, Carriers slow)
	var base_travel_time = get_travel_time(from_zone, to_zone)
	var speed_mod = get_ship_speed_modifier(ship_type)
	var travel_time = maxi(1, int(ceil(base_travel_time * speed_mod)))  # At least 1 week
	return {
		"from_zone": from_zone,
		"to_zone": to_zone,
		"ship_type": ship_type,
		"count": count,
		"turns_remaining": travel_time,
		"total_turns": travel_time  # Store original for visualization
	}

static func create_herald_transit(from_zone: int, to_zone: int) -> Dictionary:
	## Create Herald transit order - Herald fleet traveling between zones
	var travel_time = get_travel_time(from_zone, to_zone)
	return {
		"from_zone": from_zone,
		"to_zone": to_zone,
		"turns_remaining": travel_time,
		"total_turns": travel_time
	}

static func get_ship_speed_modifier(ship_type: int) -> float:
	## Get speed modifier for ship type (lower = faster)
	return SHIP_DEFS.get(ship_type, {}).get("speed_modifier", 1.0)

# Colony ship constants
const COLONY_SHIP_TRAVEL_TIME = 4  # Weeks to reach safety (slow, heavily loaded)
const COLONY_SHIP_NAMES = [
	"New Dawn", "Last Hope", "Exodus", "Sanctuary", "Pioneer",
	"Harbinger", "Salvation", "Odyssey", "Perseverance", "Genesis",
	"Horizon", "Eternal", "Vanguard", "Promise", "Aurora"
]

static func create_colony_ship(souls_aboard: int) -> Dictionary:
	## Create a colony ship transit order
	return {
		"souls_aboard": souls_aboard,
		"turns_remaining": COLONY_SHIP_TRAVEL_TIME,
		"total_turns": COLONY_SHIP_TRAVEL_TIME,
		"name": COLONY_SHIP_NAMES[randi() % COLONY_SHIP_NAMES.size()],
		"intercepted": false
	}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

static func _merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result = base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
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
	# Thresholds balanced so skilled play can reach LEGENDARY
	# Total possible with optimal play: ~200M over 25 turns
	if lives_evacuated >= 80_000_000:
		return VictoryTier.LEGENDARY
	elif lives_evacuated >= 40_000_000:
		return VictoryTier.HEROIC
	elif lives_evacuated >= 15_000_000:
		return VictoryTier.PYRRHIC
	elif lives_evacuated >= 5_000_000:
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
