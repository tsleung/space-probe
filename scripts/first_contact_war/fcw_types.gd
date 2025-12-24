extends RefCounted
class_name FCWTypes

## First Contact War - Type Definitions
## Movement-based space combat: position, velocity, time, detection

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

# New unified entity system
enum EntityType {
	WARSHIP,      # Combat vessels
	TRANSPORT,    # Civilian evacuation ships
	WEAPON,       # Torpedoes, missiles (follow same physics)
	HERALD_SHIP   # Enemy vessels
}

enum Faction {
	HUMAN,
	HERALD
}

enum MovementState {
	BURNING,      # Engine active, high signature, changing velocity
	COASTING,     # Engine off, low signature, constant velocity
	ORBITING,     # Stationed at a body
	DESTROYED     # No longer active
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

# Evacuation lanes - predefined routes that can be toggled on/off
# These are the paths transports can take. Disabling a lane:
# - Reverses transports already on it (switch to coasting, return to origin)
# - Blocks new transport launches on that route
const EVACUATION_LANES = {
	"earth_mars": {"from": ZoneId.EARTH, "to": ZoneId.MARS, "name": "Earth → Mars"},
	"mars_earth": {"from": ZoneId.MARS, "to": ZoneId.EARTH, "name": "Mars → Earth"},
	"mars_jupiter": {"from": ZoneId.MARS, "to": ZoneId.JUPITER, "name": "Mars → Jupiter"},
	"mars_asteroid": {"from": ZoneId.MARS, "to": ZoneId.ASTEROID_BELT, "name": "Mars → Belt"},
	"mars_saturn": {"from": ZoneId.MARS, "to": ZoneId.SATURN, "name": "Mars → Saturn"},
	"jupiter_kuiper": {"from": ZoneId.JUPITER, "to": ZoneId.KUIPER, "name": "Jupiter → Kuiper"},
	"asteroid_kuiper": {"from": ZoneId.ASTEROID_BELT, "to": ZoneId.KUIPER, "name": "Belt → Kuiper"},
	"saturn_kuiper": {"from": ZoneId.SATURN, "to": ZoneId.KUIPER, "name": "Saturn → Kuiper"},
}

# Helper: Get lane key for a given from/to zone pair
static func get_lane_key(from_zone: int, to_zone: int) -> String:
	for key in EVACUATION_LANES:
		var lane = EVACUATION_LANES[key]
		if lane.from == from_zone and lane.to == to_zone:
			return key
	return ""

# Helper: Get all lanes involving a specific zone (either as origin or destination)
static func get_lanes_for_zone(zone_id: int) -> Array:
	var lanes = []
	for key in EVACUATION_LANES:
		var lane = EVACUATION_LANES[key]
		if lane.from == zone_id or lane.to == zone_id:
			lanes.append(key)
	return lanes

# Helper: Get all lanes FROM Earth (for GO DARK)
static func get_earth_lanes() -> Array:
	var lanes = []
	for key in EVACUATION_LANES:
		var lane = EVACUATION_LANES[key]
		if lane.from == ZoneId.EARTH or lane.to == ZoneId.EARTH:
			lanes.append(key)
	return lanes

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
# ORBITAL MECHANICS
# ============================================================================

# Zone orbital data - positions change over time
# All positions in AU (astronomical units), centered on Sun
# Orbital periods in Earth years
const ZONE_ORBITAL_DATA = {
	ZoneId.EARTH: {
		"semi_major_axis": 1.0,      # 1 AU
		"orbital_period": 1.0,       # 1 year
		"base_angle": 0.0            # Starting angle (radians)
	},
	ZoneId.MARS: {
		"semi_major_axis": 1.52,     # 1.52 AU
		"orbital_period": 1.88,      # 1.88 years
		"base_angle": 0.5
	},
	ZoneId.ASTEROID_BELT: {
		"semi_major_axis": 2.7,      # 2.7 AU (middle of belt)
		"orbital_period": 4.4,       # ~4.4 years
		"base_angle": 1.0
	},
	ZoneId.JUPITER: {
		"semi_major_axis": 5.2,      # 5.2 AU
		"orbital_period": 11.86,     # 11.86 years
		"base_angle": 2.0
	},
	ZoneId.SATURN: {
		"semi_major_axis": 9.5,      # 9.5 AU
		"orbital_period": 29.46,     # 29.46 years
		"base_angle": 3.5
	},
	ZoneId.KUIPER: {
		"semi_major_axis": 40.0,     # ~40 AU (inner Kuiper belt)
		"orbital_period": 250.0,     # ~250 years
		"base_angle": 4.0
	}
}

# Ship thrust capabilities (acceleration in AU/week^2)
# Higher = faster travel, but all ships have unlimited fuel
const SHIP_THRUST = {
	ShipType.FRIGATE: 0.08,       # Fast scouts
	ShipType.CRUISER: 0.05,       # Standard
	ShipType.CARRIER: 0.03,       # Slow evacuation vessels
	ShipType.DREADNOUGHT: 0.04    # Heavy but decent thrust
}

# Detection constants
const BURN_SIGNATURE = 1.0         # Full visibility when burning
const COAST_SIGNATURE = 0.1        # Low visibility when coasting
const WEAPON_SIGNATURE = 0.05      # Very low (small, cold)
const HERALD_OBSERVATION_RADIUS = 5.0  # AU - Herald can see burns within this range

# Detection probability constants (per day, as fraction)
# These represent the chance Herald detects something in a region
const DETECTION_RATE_IDLE = 0.001      # 0.1% per day - minimal background
const DETECTION_RATE_LOW = 0.01        # 1% per day - occasional traffic
const DETECTION_RATE_MEDIUM = 0.05     # 5% per day - regular traffic
const DETECTION_RATE_HIGH = 0.10       # 10% per day - heavy traffic
const DETECTION_RATE_BURNING = 0.50    # 50% per day - active burn in range

# Traffic accumulation - how quickly lanes become "known"
const TRAFFIC_DECAY_RATE = 0.1         # Per week, how much traffic memory fades
const TRAFFIC_PER_TRANSIT = 0.2        # Each ship transit adds this to route traffic

# Detection zone visual thresholds
const DETECTION_ZONE_LOW = 0.01        # Start showing faint zone
const DETECTION_ZONE_MEDIUM = 0.05     # More visible zone
const DETECTION_ZONE_HIGH = 0.10       # Danger zone visualization

# ============================================================================
# HERALD TIMELINE MODEL
# ============================================================================
# The Herald advances weekly, choosing targets based on detection signatures.
# Players can manipulate signatures to lead Herald away from Earth.

# Zone adjacency - which zones Herald can reach from each position
# Key insight: Herald can "skip" zones if detection is high enough
const ZONE_ADJACENCY = {
	ZoneId.KUIPER: {
		"adjacent": [ZoneId.SATURN, ZoneId.JUPITER],  # Can reach Saturn or Jupiter
		"skip": [],  # No skip from starting position
	},
	ZoneId.SATURN: {
		"adjacent": [ZoneId.JUPITER, ZoneId.ASTEROID_BELT],
		"skip": [ZoneId.MARS],  # Can skip to Mars if sig > threshold
	},
	ZoneId.JUPITER: {
		"adjacent": [ZoneId.SATURN, ZoneId.ASTEROID_BELT],
		"skip": [ZoneId.MARS],  # Can skip to Mars if sig > threshold
	},
	ZoneId.ASTEROID_BELT: {
		"adjacent": [ZoneId.JUPITER, ZoneId.MARS],
		"skip": [],
	},
	ZoneId.MARS: {
		"adjacent": [ZoneId.ASTEROID_BELT, ZoneId.EARTH],
		"skip": [],  # Earth is adjacent, no skip needed
	},
	ZoneId.EARTH: {
		"adjacent": [],  # End of the line
		"skip": [],
	},
}

# Zone orbital order (higher = further from Sun)
# Used for "inward bias" - Herald prefers moving toward Sun
const ZONE_ORBIT_ORDER = {
	ZoneId.KUIPER: 6,
	ZoneId.SATURN: 5,
	ZoneId.JUPITER: 4,
	ZoneId.ASTEROID_BELT: 3,
	ZoneId.MARS: 2,
	ZoneId.EARTH: 1,
}

# Default inward path (if no strong detection, Herald follows this)
const ZONE_DEFAULT_NEXT = {
	ZoneId.KUIPER: ZoneId.JUPITER,       # Default: straight to Jupiter
	ZoneId.SATURN: ZoneId.ASTEROID_BELT, # Saturn → Asteroid Belt
	ZoneId.JUPITER: ZoneId.ASTEROID_BELT,# Jupiter → Asteroid Belt
	ZoneId.ASTEROID_BELT: ZoneId.MARS,   # Asteroid Belt → Mars
	ZoneId.MARS: ZoneId.EARTH,           # Mars → Earth
	ZoneId.EARTH: -1,                    # End
}

# Signature contribution weights
# These determine how much each activity adds to zone detection
const SIG_POPULATION = 0.00000001       # Per person (10B people = 0.1)
const SIG_STATIONED_SHIP = 0.02         # Per ship stationed
const SIG_PRODUCTION = 0.10             # Per ship built this week
const SIG_TRANSIT = 0.15                # Per ship transiting through
const SIG_ACTIVE_BURN = 0.30            # Per ship burning (very visible!)
const SIG_COMBAT = 0.50                 # Per combat event (explosions)
const SIG_EVACUATION = 0.20             # Per 1M people evacuating

# Herald behavior constants
const HERALD_SIG_DECAY = 0.6            # Signatures decay 40% per week
const HERALD_SKIP_THRESHOLD = 0.4       # Must have this sig to skip zones
const HERALD_INWARD_BIAS = 0.15         # Preference for moving toward Sun
const HERALD_MIN_SIG_TO_ATTRACT = 0.1   # Below this, zone doesn't attract

# Herald movement timing
const HERALD_ATTACK_DURATION = 0        # Weeks to attack a zone (instant)
const HERALD_TRAVEL_TIME = 1            # Weeks to travel between zones

# ============================================================================
# ENTITY SYSTEM
# ============================================================================

static var _next_entity_id: int = 0

static func create_entity(overrides: Dictionary = {}) -> Dictionary:
	## Create a unified entity (warship, transport, weapon, or herald ship)
	## All entities follow the same physics and detection rules
	_next_entity_id += 1
	var defaults = {
		"id": "entity_%d" % _next_entity_id,
		"entity_type": EntityType.WARSHIP,
		"faction": Faction.HUMAN,
		"ship_type": ShipType.FRIGATE,  # For warships, determines stats

		# Physics - all in AU and AU/week
		"position": Vector2.ZERO,       # Solar system coordinates
		"velocity": Vector2.ZERO,       # Current velocity vector
		"acceleration": 0.05,           # Max thrust (AU/week^2)

		# Detection
		"signature": COAST_SIGNATURE,   # Current detectability
		"movement_state": MovementState.ORBITING,

		# Payload
		"combat_power": 10.0,           # Damage capability
		"hull": 100.0,                  # Health
		"cargo": {},                    # People, resources aboard
		"count": 1,                     # Number of ships in this group

		# Orders
		"destination": -1,              # Target zone/body (-1 = none)
		"route": [],                    # Waypoints (gravity assists)
		"route_type": "direct",         # Route type: "direct", "coast", "gravity_assist"
		"waypoint_zone": -1,            # Zone ID for gravity assist control point
		"eta": 0.0,                     # Time to arrival (weeks)
		"origin": -1                    # Where this entity came from
	}
	return _merge(defaults, overrides)

static func create_warship(ship_type: int, position: Vector2, count: int = 1) -> Dictionary:
	## Create a warship entity with stats from SHIP_DEFS
	var ship_def = SHIP_DEFS.get(ship_type, SHIP_DEFS[ShipType.FRIGATE])
	var thrust = SHIP_THRUST.get(ship_type, 0.05)
	return create_entity({
		"entity_type": EntityType.WARSHIP,
		"faction": Faction.HUMAN,
		"ship_type": ship_type,
		"position": position,
		"acceleration": thrust,
		"combat_power": ship_def.combat_power * count,
		"hull": 100.0 * count,
		"count": count,
		"movement_state": MovementState.ORBITING
	})

static func create_transport(position: Vector2, souls_aboard: int, name: String = "") -> Dictionary:
	## Create a civilian transport/evacuation ship
	if name.is_empty():
		# Deterministic name selection based on next entity ID
		name = COLONY_SHIP_NAMES[(_next_entity_id + 1) % COLONY_SHIP_NAMES.size()]
	return create_entity({
		"entity_type": EntityType.TRANSPORT,
		"faction": Faction.HUMAN,
		"position": position,
		"acceleration": 0.02,  # Slow, heavily loaded
		"combat_power": 0.0,   # No combat capability
		"hull": 50.0,
		"cargo": {"souls": souls_aboard},
		"count": 1,
		"name": name,
		"movement_state": MovementState.ORBITING
	})

static func create_weapon(position: Vector2, velocity: Vector2, combat_power: float) -> Dictionary:
	## Create a weapon entity (torpedo, missile)
	## Inherits velocity from launcher, can coast silently or burn to track
	return create_entity({
		"entity_type": EntityType.WEAPON,
		"faction": Faction.HUMAN,
		"position": position,
		"velocity": velocity,
		"acceleration": 0.1,  # High thrust for terminal guidance
		"combat_power": combat_power,
		"hull": 10.0,  # Fragile
		"signature": WEAPON_SIGNATURE,
		"movement_state": MovementState.COASTING  # Default: silent running
	})

static func create_herald_ship(position: Vector2, combat_power: float) -> Dictionary:
	## Create a Herald attack ship
	return create_entity({
		"entity_type": EntityType.HERALD_SHIP,
		"faction": Faction.HERALD,
		"position": position,
		"acceleration": 0.1,  # Herald ships are fast
		"combat_power": combat_power,
		"hull": combat_power * 2.0,  # Tough
		"signature": BURN_SIGNATURE,
		"movement_state": MovementState.BURNING  # Herald always visible when moving
	})

# Herald entity constant ID - used to find the main Herald in entities array
const HERALD_ENTITY_ID = "herald_main"

# Capital ship names for the UNN fleet
const CAPITAL_SHIP_NAMES = {
	ShipType.CRUISER: ["UNN Defiant", "UNN Resolute", "UNN Valiant", "UNN Indomitable", "UNN Vigilant"],
	ShipType.CARRIER: ["CVN Prometheus", "CVN Atlas", "CVN Titan"],
	ShipType.DREADNOUGHT: ["BB Armstrong", "BB Gagarin", "BB Korolev"]
}

static func create_capital_ship(ship_type: int, zone_id: int, name: String, game_time: float = 0.0) -> Dictionary:
	## Create a named capital ship entity stationed at a zone
	var zone_pos = get_zone_position(zone_id, game_time)
	var ship_def = SHIP_DEFS.get(ship_type, SHIP_DEFS[ShipType.CRUISER])
	var thrust = SHIP_THRUST.get(ship_type, 0.03)

	return create_entity({
		"entity_type": EntityType.WARSHIP,
		"faction": Faction.HUMAN,
		"ship_type": ship_type,
		"position": zone_pos,
		"acceleration": thrust,
		"combat_power": ship_def.combat_power,
		"hull": 100.0,
		"count": 1,
		"name": name,
		"origin": zone_id,
		"destination": -1,
		"movement_state": MovementState.ORBITING
	})

static func _create_initial_fleet_entities(game_time: float = 0.0) -> Array:
	## Create the starting UNN capital ships as entities
	## These are the named ships that appear on the map
	var entities = []

	# Earth defense fleet - main force
	entities.append(create_capital_ship(ShipType.CRUISER, ZoneId.EARTH, "UNN Defiant", game_time))
	entities.append(create_capital_ship(ShipType.CRUISER, ZoneId.EARTH, "UNN Resolute", game_time))
	entities.append(create_capital_ship(ShipType.CARRIER, ZoneId.EARTH, "CVN Prometheus", game_time))

	# Mars garrison
	entities.append(create_capital_ship(ShipType.CRUISER, ZoneId.MARS, "UNN Valiant", game_time))

	# Outer system patrol
	entities.append(create_capital_ship(ShipType.CRUISER, ZoneId.JUPITER, "UNN Vigilant", game_time))

	return entities

static func _create_herald_entity() -> Dictionary:
	## Create the main Herald entity for initial state
	## Starts at Kuiper Belt, orbiting
	var kuiper_pos = get_zone_position(ZoneId.KUIPER, 0.0)
	return {
		"id": HERALD_ENTITY_ID,
		"entity_type": EntityType.HERALD_SHIP,
		"faction": Faction.HERALD,
		"position": kuiper_pos,
		"velocity": Vector2.ZERO,
		"acceleration": 0.08,  # Herald is fast but not as fast as drones
		"signature": COAST_SIGNATURE,  # Herald is stealthy when not moving
		"movement_state": MovementState.ORBITING,
		"combat_power": 50.0,  # Initial strength (increases each turn)
		"hull": 1000.0,  # Very tough
		"cargo": {},
		"count": 1,
		"destination": ZoneId.KUIPER,  # Current target zone
		"origin": ZoneId.KUIPER,  # Starting zone
		"route": [],
		"eta": 0.0
	}

static func get_herald_entity(state: Dictionary) -> Dictionary:
	## Find and return the main Herald entity from state
	## Returns empty dict if not found
	for entity in state.get("entities", []):
		if entity.get("id") == HERALD_ENTITY_ID:
			return entity
	return {}

static func get_zone_position(zone_id: int, game_time: float) -> Vector2:
	## Get the current position of a zone/body at a given game time
	## game_time is in HOURS (the base unit of the new time system)
	## Returns position in AU as Vector2
	var orbital = ZONE_ORBITAL_DATA.get(zone_id)
	if not orbital:
		return Vector2.ZERO

	# Convert game time (hours) to years
	# 168 hours/week * 52 weeks/year = 8736 hours/year
	const HOURS_PER_YEAR = 168.0 * 52.0
	var time_years = game_time / HOURS_PER_YEAR

	# Calculate orbital angle (radians)
	var angular_velocity = TAU / orbital.orbital_period  # radians per year
	var angle = orbital.base_angle + (angular_velocity * time_years)

	# Calculate position (circular orbit approximation)
	var radius = orbital.semi_major_axis
	return Vector2(
		radius * cos(angle),
		radius * sin(angle)
	)

static func get_zone_position_at_week(zone_id: int, week: float) -> Vector2:
	## Legacy helper - get zone position given time in weeks
	## Converts to hours internally
	return get_zone_position(zone_id, week * 168.0)

static func get_all_zone_positions(game_time: float) -> Dictionary:
	## Get positions of all zones at a given time
	var positions = {}
	for zone_id in ZoneId.values():
		positions[zone_id] = get_zone_position(zone_id, game_time)
	return positions

static func get_zone_orbital_radius(zone_id: int) -> float:
	## Get the orbital radius (semi-major axis) of a zone in AU
	var orbital = ZONE_ORBITAL_DATA.get(zone_id)
	if not orbital:
		return 0.0
	return orbital.semi_major_axis

# Detection calculation moved to FCWHeraldAI.calc_detection_probability()
# See scripts/first_contact_war/fcw_herald_ai.gd for the detection system

static func calc_route_traffic_key(from_zone: int, to_zone: int) -> String:
	## Generate a unique key for a route between two zones
	## Keys are normalized so A->B and B->A use the same key
	var min_zone = mini(from_zone, to_zone)
	var max_zone = maxi(from_zone, to_zone)
	return "%d_%d" % [min_zone, max_zone]

static func get_detection_visual_level(detection_rate: float) -> int:
	## Get visual level for detection zone display
	## Returns 0 (none), 1 (low), 2 (medium), 3 (high)
	if detection_rate >= DETECTION_ZONE_HIGH:
		return 3
	elif detection_rate >= DETECTION_ZONE_MEDIUM:
		return 2
	elif detection_rate >= DETECTION_ZONE_LOW:
		return 1
	return 0

# ============================================================================
# DATA STRUCTURES
# ============================================================================

static func create_initial_state() -> Dictionary:
	return {
		"turn": 1,
		"game_time": 0.0,  # HOURS elapsed (base unit of time system)

		# Snapshot system for visual interpolation
		# Stores positions at the start of current tick for smooth animation
		"prev_entity_positions": {},  # entity_id -> Vector2 (position at tick start)
		"prev_zone_positions": {},    # zone_id -> Vector2 (orbital positions at tick start)
		"resources": {
			"ore": 100,
			"steel": 50,
			"energy": 100,
			"electronics": 20,
			"rare": 30,
			"weapons": 10
		},
		"zones": _create_initial_zones(),

		# New unified entity system - Herald + capital ships
		"entities": [_create_herald_entity()] + _create_initial_fleet_entities(),  # Array of FCWEntity dictionaries

		# Legacy fleet system (kept for backward compatibility during migration)
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

		# Evacuation tracking
		"lives_evacuated": 0,
		"lives_lost": 0,
		"lives_intercepted": 0,  # Lives lost to Herald interception
		"total_population": 8_000_000_000,  # 8 billion

		# Herald tracking (will migrate to entity system)
		"herald_attack_target": ZoneId.KUIPER,
		"herald_current_zone": ZoneId.KUIPER,  # Where Herald physically is
		"herald_transit": {},  # {from_zone, to_zone, turns_remaining, total_turns} when traveling
		"herald_strength": 50,
		"herald_hold_weeks": 0,  # Weeks Herald has held position (no movement)
		"herald_departed": false,  # True when Herald gives up and leaves

		# Detection system (new)
		"herald_intel": {
			"known_routes": {},      # route_key -> observation_count
			"last_detected": {},     # entity_id -> {position, velocity, time}
			"activity_zones": {}     # zone_id -> activity_level (0-1)
		},

		# Zone detection signatures (Herald uses these to choose targets)
		# Higher signature = more likely Herald moves there
		# Decays each week, player can manipulate via decoys/stealth
		"zone_signatures": {
			ZoneId.KUIPER: 0.0,
			ZoneId.SATURN: 0.0,
			ZoneId.JUPITER: 0.0,
			ZoneId.ASTEROID_BELT: 0.0,
			ZoneId.MARS: 0.0,
			ZoneId.EARTH: 0.1,  # Earth always has baseline (civilization)
		},

		# Evacuation lane states - which routes are active
		# Disabling a lane reverses transports on it and blocks new launches
		"lane_states": {
			"earth_mars": true,
			"mars_earth": true,
			"mars_jupiter": true,
			"mars_asteroid": true,
			"mars_saturn": true,
			"jupiter_kuiper": true,
			"asteroid_kuiper": true,
			"saturn_kuiper": true,
		},
		"earth_isolated": false,  # GO DARK state - all Earth lanes disabled

		# Weekly activity tracking (resets each week, contributes to signatures)
		"weekly_activity": {
			"ships_built": {},       # zone_id -> count
			"ships_transited": {},   # zone_id -> count
			"burns_detected": {},    # zone_id -> count
			"combat_events": {},     # zone_id -> count
			"evacuations": {},       # zone_id -> lives evacuated
		},

		# Events that occurred this tick (cleared each tick, used for signal emission)
		"tick_events": {
			"intercepts": [],        # [{pursuer_id, target_id, souls_lost}]
			"detections": [],        # [{entity_id, position}]
			"arrivals": []           # [{entity_id, zone_id}]
		},

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

static var _next_colony_ship_id: int = 0

static func create_colony_ship(souls_aboard: int) -> Dictionary:
	## Create a colony ship transit order
	_next_colony_ship_id += 1
	return {
		"souls_aboard": souls_aboard,
		"turns_remaining": COLONY_SHIP_TRAVEL_TIME,
		"total_turns": COLONY_SHIP_TRAVEL_TIME,
		# Deterministic name selection based on colony ship ID
		"name": COLONY_SHIP_NAMES[_next_colony_ship_id % COLONY_SHIP_NAMES.size()],
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

static func get_zone_orbit_order(zone_id: int) -> int:
	## Get orbital order (higher = further from Sun)
	return ZONE_ORBIT_ORDER.get(zone_id, 0)

static func get_zone_adjacent(zone_id: int) -> Array:
	## Get zones Herald can reach from this zone (adjacent)
	var adj = ZONE_ADJACENCY.get(zone_id, {})
	return adj.get("adjacent", [])

static func get_zone_skip_targets(zone_id: int) -> Array:
	## Get zones Herald can skip to (requires high signature)
	var adj = ZONE_ADJACENCY.get(zone_id, {})
	return adj.get("skip", [])

static func get_zone_default_next(zone_id: int) -> int:
	## Get default next zone if no strong detection
	return ZONE_DEFAULT_NEXT.get(zone_id, -1)

static func get_all_reachable_zones(zone_id: int) -> Array:
	## Get all zones Herald could potentially reach (adjacent + skip)
	var result = get_zone_adjacent(zone_id).duplicate()
	result.append_array(get_zone_skip_targets(zone_id))
	return result

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
