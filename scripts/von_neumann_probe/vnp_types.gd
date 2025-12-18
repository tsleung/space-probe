class_name VnpTypes

enum Team { PLAYER, ENEMY_1, NEMESIS }
enum ShipType { FRIGATE, DESTROYER, CRUISER, HARVESTER, DEFENDER, SHIELDER, GRAVITON, STARBASE, BASE_TURRET }
enum WeaponType { GUN, LASER, MISSILE, PDC, SHIELD, GRAVITY, TURBOLASER }
enum ShipSize { SMALL, MEDIUM, LARGE, MASSIVE }

# Strategic capture point types
enum PointType { CENTER, ASTEROID_FIELD, RELAY }

const POINT_TYPE_NAMES = {
	PointType.CENTER: "Command Center",
	PointType.ASTEROID_FIELD: "Asteroid Field",
	PointType.RELAY: "Relay Station",
}

# What each point type provides
const POINT_BONUSES = {
	PointType.CENTER: {
		"damage_bonus": 0.15,  # +15% damage for all ships
		"mass_income": 3,      # Some mass too
	},
	PointType.ASTEROID_FIELD: {
		"mass_income": 5,      # Primary mass source
	},
	PointType.RELAY: {
		"health_bonus": 0.10,  # Ships spawn with +10% health
		"mass_income": 2,
	},
}

static func get_point_name(point_type: int) -> String:
	return POINT_TYPE_NAMES.get(point_type, "Unknown")

const TEAM_NAMES = {
	Team.PLAYER: "Player",
	Team.ENEMY_1: "Enemy",
	Team.NEMESIS: "Nemesis",
}

const TEAM_COLORS = {
	Team.PLAYER: Color.DEEP_SKY_BLUE,
	Team.ENEMY_1: Color.ORANGE_RED,
	Team.NEMESIS: Color.DARK_VIOLET,
}

# Faction-specific weapon visuals
const WEAPON_COLORS = {
	Team.PLAYER: {
		WeaponType.GUN: Color(0.7, 0.85, 1.0),    # Ice blue railgun
		WeaponType.LASER: Color(0.2, 0.9, 1.0),   # Cyan laser
		WeaponType.MISSILE: Color(0.4, 0.7, 1.0), # Blue missile trail
		WeaponType.PDC: Color(0.9, 0.95, 1.0),    # White-blue tracers
		WeaponType.SHIELD: Color(0.3, 0.6, 1.0, 0.4),  # Blue shield bubble
		WeaponType.GRAVITY: Color(0.2, 0.1, 0.4, 0.6),  # Dark blue void
		WeaponType.TURBOLASER: Color(0.3, 0.8, 1.0),  # Bright cyan turbolaser
	},
	Team.ENEMY_1: {
		WeaponType.GUN: Color(1.0, 0.9, 0.3),     # Yellow autocannon
		WeaponType.LASER: Color(0.5, 1.0, 0.3),   # Green plasma
		WeaponType.MISSILE: Color(1.0, 0.5, 0.2), # Orange torpedo
		WeaponType.PDC: Color(1.0, 1.0, 0.7),     # Yellow-white tracers
		WeaponType.SHIELD: Color(1.0, 0.6, 0.2, 0.4),  # Orange shield bubble
		WeaponType.GRAVITY: Color(0.3, 0.15, 0.1, 0.6),  # Dark orange void
		WeaponType.TURBOLASER: Color(0.2, 1.0, 0.3),  # Green turbolaser
	},
	Team.NEMESIS: {
		WeaponType.GUN: Color(0.8, 0.3, 1.0),     # Purple pulse
		WeaponType.LASER: Color(0.6, 0.2, 0.9),   # Purple disruptor
		WeaponType.MISSILE: Color(0.9, 0.2, 0.8), # Magenta antimatter
		WeaponType.PDC: Color(0.9, 0.7, 1.0),     # Light purple tracers
		WeaponType.SHIELD: Color(0.7, 0.2, 0.9, 0.4),  # Purple shield bubble
		WeaponType.GRAVITY: Color(0.15, 0.0, 0.2, 0.6),  # Deep purple void
		WeaponType.TURBOLASER: Color(0.9, 0.2, 0.9),  # Magenta turbolaser
	},
}

# Base weapon types per faction
enum BaseWeapon { ION_CANNON, MISSILE_BARRAGE, SINGULARITY }

const BASE_WEAPONS = {
	Team.PLAYER: BaseWeapon.ION_CANNON,
	Team.ENEMY_1: BaseWeapon.MISSILE_BARRAGE,
	Team.NEMESIS: BaseWeapon.SINGULARITY,
}

const BASE_WEAPON_COOLDOWN = 15.0  # seconds
const BASE_WEAPON_DAMAGE = 100

static func get_weapon_color(team: int, weapon: int) -> Color:
	if WEAPON_COLORS.has(team) and WEAPON_COLORS[team].has(weapon):
		return WEAPON_COLORS[team][weapon]
	return Color.WHITE

const SHIP_SIZES = {
	ShipType.FRIGATE: ShipSize.SMALL,
	ShipType.DESTROYER: ShipSize.MEDIUM,
	ShipType.CRUISER: ShipSize.LARGE,
	ShipType.HARVESTER: ShipSize.SMALL,
	ShipType.DEFENDER: ShipSize.MEDIUM,
	ShipType.SHIELDER: ShipSize.MEDIUM,
	ShipType.GRAVITON: ShipSize.LARGE,
	ShipType.STARBASE: ShipSize.MASSIVE,
	ShipType.BASE_TURRET: ShipSize.MEDIUM,
}

static func get_team_name(team: int) -> String:
	return TEAM_NAMES.get(team, "Unknown")

static func get_team_color(team: int) -> Color:
	return TEAM_COLORS.get(team, Color.WHITE)

static func get_ship_size(ship_type: int) -> int:
	return SHIP_SIZES.get(ship_type, ShipSize.SMALL)

const SHIP_STATS = {
	ShipType.FRIGATE: {
		"name": "Frigate",
		"weapon": WeaponType.GUN,
		"cost": 50,
		"mass_cost": 0,         # No mass needed - swarm unit
		"speed": 280,           # FAST - get in close
		"health": 70,           # Fragile glass cannon
		"damage": 18,           # Piercing damage adds up
		"range": 200,           # Short range, must close distance
		"fire_rate": 4.0,       # Rapid railgun fire
	},
	ShipType.DESTROYER: {
		"name": "Destroyer",
		"weapon": WeaponType.LASER,
		"cost": 75,
		"mass_cost": 0,         # No mass needed - accessible mid-tier
		"speed": 180,
		"health": 130,
		"damage": 40,           # Precise burn damage
		"range": 400,           # Good range - sniper
		"fire_rate": 1.5,       # Slower but guaranteed hits
	},
	ShipType.CRUISER: {
		"name": "Cruiser",
		"weapon": WeaponType.MISSILE,
		"cost": 100,
		"mass_cost": 25,        # Requires mass - capital ship
		"speed": 100,           # Slow but deadly
		"health": 220,          # Tanky
		"damage": 50,           # Base damage, splash adds more
		"range": 500,           # Long range bombardment
		"fire_rate": 0.8,       # Slow reload, big impact
	},
	ShipType.HARVESTER: {
		"name": "Harvester",
		"cost": 60,
		"mass_cost": 0,
		"speed": 200,
		"health": 60,
		"capacity": 100,
	},
	ShipType.DEFENDER: {
		"name": "Defender",
		"weapon": WeaponType.PDC,
		"cost": 80,
		"mass_cost": 0,         # No mass - accessible support
		"speed": 160,
		"health": 100,
		"damage": 25,           # Damage to missiles it intercepts
		"range": 250,           # PDC interception range
		"fire_rate": 8.0,       # Very rapid PDC fire
		"intercept_chance": 0.4,  # 40% chance to intercept each missile
	},
	ShipType.SHIELDER: {
		"name": "Shielder",
		"weapon": WeaponType.SHIELD,
		"cost": 90,
		"mass_cost": 10,        # Small mass cost
		"speed": 140,
		"health": 80,           # Fragile hull, relies on shields
		"shield_radius": 120,   # Protection radius
		"shield_strength": 50,  # Damage absorbed per second
		"range": 150,           # Stay close to allies
		"fire_rate": 0,         # No direct attack
	},
	ShipType.GRAVITON: {
		"name": "Graviton",
		"weapon": WeaponType.GRAVITY,
		"cost": 120,
		"mass_cost": 40,        # Heavy mass cost - powerful support
		"speed": 80,            # Slow, hulking mass manipulator
		"health": 180,          # Tanky - needs to survive to protect
		"gravity_radius": 140,  # Gravity well radius (scaled down from 200)
		"deflect_strength": 0.85, # 85% chance to deflect railguns
		"range": 140,           # Gravity well range from ship
		"fire_rate": 0,         # No direct attack - pure support
	},
	# STAR BASE: Massive stationary structure - like a Star Destroyer
	# Dangerous for capital ships, but small fighters can dodge turbolasers
	ShipType.STARBASE: {
		"name": "Star Base",
		"weapon": WeaponType.TURBOLASER,
		"cost": 400,
		"mass_cost": 100,       # Huge mass investment
		"speed": 0,             # Completely stationary
		"health": 800,          # Massive health pool
		"damage": 120,          # Devastating per-hit damage
		"range": 600,           # Long range - area denial
		"fire_rate": 0.5,       # Slow rate - 2 seconds between shots
		"turbolaser_speed": 180, # Slow projectile - dodgeable by fast ships
		"turbolaser_size": 12,  # Big visible bolt
	},
	# BASE TURRET: Defensive structure spawned at game start near each base
	# Provides early-game protection while fleets build up
	ShipType.BASE_TURRET: {
		"name": "Base Turret",
		"weapon": WeaponType.GUN,  # Rapid-fire railgun for anti-ship
		"cost": 0,              # Not buildable - spawned at start
		"mass_cost": 0,
		"speed": 0,             # Completely stationary
		"health": 350,          # Durable - survives early skirmishes
		"damage": 25,           # Moderate damage per shot
		"range": 350,           # Good defensive range
		"fire_rate": 3.0,       # Fast fire rate - 3 shots per second
		"is_structure": true,   # Flag to identify as non-buildable structure
	},
}

# Fleet Policy System - Controls AI ship building preferences
enum FleetStance { AGGRESSIVE, BALANCED, DEFENSIVE }

# Fleet Formation - Controls tactical movement behavior
enum FleetFormation { DEFENSIVE, OFFENSIVE }

const FLEET_FORMATION_NAMES = {
	FleetFormation.DEFENSIVE: "Defensive",
	FleetFormation.OFFENSIVE: "Offensive",
}

static func get_formation_name(formation: int) -> String:
	return FLEET_FORMATION_NAMES.get(formation, "Unknown")

# Fleet Adherence - How tightly ships stick together
enum FleetAdherence { LOOSE, TIGHT }

const FLEET_ADHERENCE_NAMES = {
	FleetAdherence.LOOSE: "Loose",
	FleetAdherence.TIGHT: "Tight",
}

static func get_adherence_name(adherence: int) -> String:
	return FLEET_ADHERENCE_NAMES.get(adherence, "Unknown")

const FLEET_STANCE_NAMES = {
	FleetStance.AGGRESSIVE: "Aggressive",
	FleetStance.BALANCED: "Balanced",
	FleetStance.DEFENSIVE: "Defensive",
}

# Default fleet policies per stance
const FLEET_POLICIES = {
	FleetStance.AGGRESSIVE: {
		"counter_pick_chance": 0.4,  # Less reactive, more committed
		"preferences": [ShipType.FRIGATE, ShipType.CRUISER, ShipType.DESTROYER],
		"weights": {
			ShipType.FRIGATE: 3.0,      # Swarm with frigates
			ShipType.DESTROYER: 2.0,
			ShipType.CRUISER: 2.5,
			ShipType.DEFENDER: 0.5,
			ShipType.SHIELDER: 0.3,
			ShipType.GRAVITON: 0.5,
		}
	},
	FleetStance.BALANCED: {
		"counter_pick_chance": 0.6,  # Reactive and adaptive
		"preferences": [ShipType.DESTROYER, ShipType.FRIGATE, ShipType.CRUISER, ShipType.DEFENDER],
		"weights": {
			ShipType.FRIGATE: 1.5,
			ShipType.DESTROYER: 2.0,
			ShipType.CRUISER: 1.5,
			ShipType.DEFENDER: 1.0,
			ShipType.SHIELDER: 1.0,
			ShipType.GRAVITON: 1.0,
		}
	},
	FleetStance.DEFENSIVE: {
		"counter_pick_chance": 0.7,  # Very reactive
		"preferences": [ShipType.DEFENDER, ShipType.SHIELDER, ShipType.GRAVITON, ShipType.CRUISER],
		"weights": {
			ShipType.FRIGATE: 0.5,
			ShipType.DESTROYER: 1.0,
			ShipType.CRUISER: 1.5,
			ShipType.DEFENDER: 3.0,      # Lots of point defense
			ShipType.SHIELDER: 2.5,
			ShipType.GRAVITON: 2.0,
		}
	}
}

static func get_stance_name(stance: int) -> String:
	return FLEET_STANCE_NAMES.get(stance, "Unknown")

static func get_fleet_policy(stance: int) -> Dictionary:
	return FLEET_POLICIES.get(stance, FLEET_POLICIES[FleetStance.BALANCED])

# Rock-paper-scissors damage multipliers
const DAMAGE_MULTIPLIERS = {
	WeaponType.GUN: {
		WeaponType.LASER: 2.0,
		WeaponType.MISSILE: 0.5,
		WeaponType.GUN: 1.0,
	},
	WeaponType.LASER: {
		WeaponType.MISSILE: 2.0,
		WeaponType.GUN: 0.5,
		WeaponType.LASER: 1.0,
	},
	WeaponType.MISSILE: {
		WeaponType.GUN: 2.0,
		WeaponType.LASER: 0.5,
		WeaponType.MISSILE: 1.0,
	}
}