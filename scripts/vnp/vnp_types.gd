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
		"speed": 150,
		"health": 100,
		"damage": 10,
		"range": 300,
		"fire_rate": 1.5, # shots per second
	},
	ShipType.DESTROYER: {
		"name": "Destroyer",
		"weapon": WeaponType.LASER,
		"cost": 75,
		"speed": 100,
		"health": 150,
		"damage": 20,
		"range": 400,
		"fire_rate": 1.0,
	},
	ShipType.CRUISER: {
		"name": "Cruiser",
		"weapon": WeaponType.MISSILE,
		"cost": 125,
		"speed": 75,
		"health": 250,
		"damage": 30,
		"range": 500,
		"fire_rate": 0.5,
	},
	ShipType.HARVESTER: {
		"name": "Harvester",
		"cost": 60,
		"speed": 120,
		"health": 80,
		"capacity": 100, # resource capacity
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