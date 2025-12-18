class_name VnpTypes

enum Team { PLAYER, ENEMY_1, NEMESIS }
enum ShipType { FRIGATE, DESTROYER, CRUISER, HARVESTER }
enum WeaponType { GUN, LASER, MISSILE }
enum ShipSize { SMALL, MEDIUM, LARGE }

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
	},
	Team.ENEMY_1: {
		WeaponType.GUN: Color(1.0, 0.9, 0.3),     # Yellow autocannon
		WeaponType.LASER: Color(0.5, 1.0, 0.3),   # Green plasma
		WeaponType.MISSILE: Color(1.0, 0.5, 0.2), # Orange torpedo
	},
	Team.NEMESIS: {
		WeaponType.GUN: Color(0.8, 0.3, 1.0),     # Purple pulse
		WeaponType.LASER: Color(0.6, 0.2, 0.9),   # Purple disruptor
		WeaponType.MISSILE: Color(0.9, 0.2, 0.8), # Magenta antimatter
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
		"speed": 280,   # FAST - get in close
		"health": 70,   # Fragile glass cannon
		"damage": 18,   # Piercing damage adds up
		"range": 200,   # Short range, must close distance
		"fire_rate": 4.0,  # Rapid railgun fire
	},
	ShipType.DESTROYER: {
		"name": "Destroyer",
		"weapon": WeaponType.LASER,
		"cost": 75,
		"speed": 180,
		"health": 130,
		"damage": 40,   # Precise burn damage
		"range": 400,   # Good range - sniper
		"fire_rate": 1.5,  # Slower but guaranteed hits
	},
	ShipType.CRUISER: {
		"name": "Cruiser",
		"weapon": WeaponType.MISSILE,
		"cost": 125,
		"speed": 100,   # Slow but deadly
		"health": 220,  # Tanky
		"damage": 50,   # Base damage, splash adds more
		"range": 500,   # Long range bombardment
		"fire_rate": 0.8,  # Slow reload, big impact
	},
	ShipType.HARVESTER: {
		"name": "Harvester",
		"cost": 60,
		"speed": 200,
		"health": 60,
		"capacity": 100,
	},
}

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