extends RefCounted
class_name FCWBattleSystem

## Named Ships, Battle Reports, and Tactical Combat
## "They have names. They have crews. They die for us."

# ============================================================================
# SHIP NAME GENERATION
# ============================================================================

const SHIP_PREFIXES = {
	"earth": ["UNN", "ESS", "HMS", "UNSC"],  # United Nations Navy, Earth Space Ship, etc.
	"mars": ["MCR", "MCRN", "Donnager-class"],
	"belt": ["OPA", "Tycho", "Ceres"]
}

const SHIP_NAMES_HEROIC = [
	"Defiant", "Indomitable", "Resolute", "Valiant", "Dauntless",
	"Intrepid", "Fearless", "Relentless", "Vigilant", "Stalwart",
	"Thunderchild", "Agamemnon", "Scipio", "Wellington", "Nelson"
]

const SHIP_NAMES_MYTHIC = [
	"Prometheus", "Athena", "Ares", "Hercules", "Perseus",
	"Odysseus", "Achilles", "Ajax", "Hector", "Orion",
	"Andromeda", "Cassandra", "Aurora", "Phoenix", "Titan"
]

const SHIP_NAMES_MEMORIAL = [
	"Armstrong", "Gagarin", "Shepard", "Glenn", "Aldrin",
	"Collins", "Ride", "Jemison", "Hadfield", "Kelly",
	"Yeager", "Lindbergh", "Earhart", "Wright", "Goddard"
]

const SHIP_NAMES_CITIES = [
	"New York", "Shanghai", "Tokyo", "London", "Mumbai",
	"São Paulo", "Lagos", "Cairo", "Sydney", "Moscow",
	"Berlin", "Paris", "Rome", "Toronto", "Singapore"
]

const CAPTAIN_FIRST_NAMES = [
	"James", "Sarah", "Chen", "Maria", "Yuki", "Ahmed", "Olga",
	"Marcus", "Elena", "Raj", "Fatima", "Thor", "Kenji", "Amara",
	"Viktor", "Isabella", "David", "Mei", "Aleksei", "Zara"
]

const CAPTAIN_LAST_NAMES = [
	"Rodriguez", "Chen", "Patel", "Okonkwo", "Petrov", "Tanaka",
	"Schmidt", "Al-Rashid", "Johansson", "da Silva", "Kim",
	"Müller", "Singh", "Nakamura", "Volkov", "Martinez",
	"O'Brien", "Andersen", "Kowalski", "Yamamoto"
]

# ============================================================================
# SHIP CLASS
# ============================================================================

class NamedShip:
	var id: String
	var name: String
	var ship_class: String  # Frigate, Cruiser, Carrier, Dreadnought
	var captain: String
	var crew_count: int
	var home_zone: int
	var current_zone: int
	var health: float = 1.0  # 0-1
	var kills: int = 0
	var battles_survived: int = 0
	var is_destroyed: bool = false
	var destruction_report: String = ""

	func get_full_name() -> String:
		return "%s %s" % [ship_class.substr(0, 3).to_upper(), name]

	func get_status_report() -> String:
		if is_destroyed:
			return "[DESTROYED] %s - %s" % [get_full_name(), destruction_report]
		var health_status = "OPERATIONAL" if health > 0.5 else "DAMAGED" if health > 0.2 else "CRITICAL"
		return "%s - %s (Capt. %s, %d crew)" % [get_full_name(), health_status, captain, crew_count]

# ============================================================================
# BATTLE REPORT CLASS
# ============================================================================

class BattleReport:
	var timestamp: int  # Turn number
	var zone_id: int
	var report_type: String  # "combat", "destruction", "heroic", "evacuation", "distress"
	var headline: String
	var details: String
	var ships_involved: Array = []
	var casualties: int = 0
	var is_critical: bool = false

# ============================================================================
# STATE
# ============================================================================

var _ship_registry: Dictionary = {}  # id -> NamedShip
var _next_ship_id: int = 1
var _battle_reports: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _used_names: Array = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	_rng.randomize()

func generate_starting_fleet(fleet: Dictionary, starting_zone: int = FCWTypes.ZoneId.EARTH) -> void:
	# Generate named ships for starting fleet
	for ship_type in fleet:
		var count = fleet[ship_type]
		for i in range(count):
			var ship = _create_named_ship(ship_type, starting_zone)
			_ship_registry[ship.id] = ship

# ============================================================================
# SHIP GENERATION
# ============================================================================

func _create_named_ship(ship_type: int, home_zone: int) -> NamedShip:
	var ship = NamedShip.new()
	ship.id = "ship_%d" % _next_ship_id
	_next_ship_id += 1

	ship.name = _generate_unique_name()
	ship.ship_class = FCWTypes.get_ship_name(ship_type)
	ship.captain = _generate_captain_name()
	ship.crew_count = _get_crew_count(ship_type)
	ship.home_zone = home_zone
	ship.current_zone = home_zone

	return ship

func _generate_unique_name() -> String:
	var all_names = SHIP_NAMES_HEROIC + SHIP_NAMES_MYTHIC + SHIP_NAMES_MEMORIAL + SHIP_NAMES_CITIES
	var available = all_names.filter(func(n): return n not in _used_names)

	if available.is_empty():
		# Generate a numbered name
		return "Victory-%d" % _rng.randi_range(100, 999)

	var name = available[_rng.randi() % available.size()]
	_used_names.append(name)
	return name

func _generate_captain_name() -> String:
	var first = CAPTAIN_FIRST_NAMES[_rng.randi() % CAPTAIN_FIRST_NAMES.size()]
	var last = CAPTAIN_LAST_NAMES[_rng.randi() % CAPTAIN_LAST_NAMES.size()]
	return "%s %s" % [first, last]

func _get_crew_count(ship_type: int) -> int:
	match ship_type:
		FCWTypes.ShipType.FRIGATE: return _rng.randi_range(45, 80)
		FCWTypes.ShipType.CRUISER: return _rng.randi_range(150, 300)
		FCWTypes.ShipType.CARRIER: return _rng.randi_range(800, 1500)
		FCWTypes.ShipType.DREADNOUGHT: return _rng.randi_range(400, 600)
		_: return 50

# ============================================================================
# BATTLE SIMULATION
# ============================================================================

func simulate_battle(zone_id: int, defender_strength: int, herald_strength: int,
					 zone_fleet: Dictionary, did_hold: bool) -> Array[BattleReport]:
	var reports: Array[BattleReport] = []
	var zone_name = FCWTypes.get_zone_name(zone_id)

	# Get ships assigned to this zone
	var defending_ships = get_ships_at_zone(zone_id)

	if defending_ships.is_empty():
		# No named ships here, generate a brief report
		var report = BattleReport.new()
		report.timestamp = 0  # Will be set by caller
		report.zone_id = zone_id
		report.report_type = "combat"
		report.headline = "BATTLE AT %s" % zone_name.to_upper()
		report.details = "Automated defenses engaged Herald forces."
		report.is_critical = not did_hold
		reports.append(report)
		return reports

	# Opening report
	var opening = BattleReport.new()
	opening.zone_id = zone_id
	opening.report_type = "combat"
	opening.headline = "ENGAGEMENT AT %s" % zone_name.to_upper()
	opening.details = "%d ships engaging Herald fleet. Strength ratio: %d vs %d" % [
		defending_ships.size(), defender_strength, herald_strength
	]
	opening.ships_involved = defending_ships.map(func(s): return s.id)
	reports.append(opening)

	# Simulate individual ship fates
	var loss_ratio = 0.3 if did_hold else 0.8  # 30% losses if held, 80% if fell
	var ships_to_lose = int(defending_ships.size() * loss_ratio)

	# Shuffle and pick ships to lose
	defending_ships.shuffle()
	var lost_ships = defending_ships.slice(0, ships_to_lose)
	var surviving_ships = defending_ships.slice(ships_to_lose)

	# Generate dramatic reports for lost ships
	for ship in lost_ships:
		var death_report = _generate_ship_destruction_report(ship, zone_id, herald_strength)
		reports.append(death_report)
		_destroy_ship(ship, death_report.details)

	# Generate heroic moments for survivors
	for ship in surviving_ships:
		ship.battles_survived += 1
		ship.kills += _rng.randi_range(1, 5)
		ship.health = _rng.randf_range(0.2, 0.8)

		# Chance for heroic report
		if _rng.randf() < 0.3:
			var heroic = _generate_heroic_report(ship, zone_id)
			reports.append(heroic)

	# Final battle summary
	var summary = BattleReport.new()
	summary.zone_id = zone_id
	summary.report_type = "combat"
	summary.headline = "%s %s" % [zone_name.to_upper(), "HOLDS!" if did_hold else "HAS FALLEN"]
	summary.casualties = lost_ships.reduce(func(acc, s): return acc + s.crew_count, 0)
	summary.details = "%d ships lost. %d crew killed. %d ships combat effective." % [
		lost_ships.size(), summary.casualties, surviving_ships.size()
	]
	summary.is_critical = not did_hold
	reports.append(summary)

	_battle_reports.append_array(reports)
	return reports

func _generate_ship_destruction_report(ship: NamedShip, zone_id: int, herald_strength: int) -> BattleReport:
	var report = BattleReport.new()
	report.zone_id = zone_id
	report.report_type = "destruction"
	report.ships_involved = [ship.id]
	report.casualties = ship.crew_count
	report.is_critical = true

	# Dramatic destruction narratives
	var narratives = [
		"%s took a direct hit to the reactor. No survivors.",
		"%s rammed a Herald cruiser, buying time for evacuation ships.",
		"Last transmission from %s: 'Tell them we held the line.'",
		"%s broke apart under concentrated Herald fire. Captain %s ordered crew to escape pods.",
		"The %s went down fighting, taking three Herald ships with her.",
		"%s's PDC grid failed. Torpedo impact amidships. %d souls lost.",
		"Captain %s of the %s ordered ramming speed. Herald carrier destroyed.",
		"%s covered the retreat. She didn't make it out.",
	]

	var narrative = narratives[_rng.randi() % narratives.size()]
	narrative = narrative.replace("%s", ship.get_full_name())
	narrative = narrative.replace("%d", str(ship.crew_count))
	narrative = narrative.replace("Captain %s", "Captain " + ship.captain)

	report.headline = "SHIP LOST: %s" % ship.get_full_name()
	report.details = narrative

	return report

func _generate_heroic_report(ship: NamedShip, zone_id: int) -> BattleReport:
	var report = BattleReport.new()
	report.zone_id = zone_id
	report.report_type = "heroic"
	report.ships_involved = [ship.id]

	var heroics = [
		"%s destroyed %d Herald fighters with precision PDC fire.",
		"Captain %s of the %s led a flanking maneuver that broke the Herald line.",
		"%s's torpedo spread disabled a Herald command ship.",
		"Against all odds, %s held the gap for 47 minutes.",
		"%s rescued escape pods from three destroyed vessels under fire.",
		"The %s scored a direct hit on Herald flagship's engines.",
	]

	var narrative = heroics[_rng.randi() % heroics.size()]
	narrative = narrative.replace("%s", ship.get_full_name())
	narrative = narrative.replace("%d", str(ship.kills))
	narrative = narrative.replace("Captain %s", "Captain " + ship.captain)

	report.headline = "COMMENDATION: %s" % ship.get_full_name()
	report.details = narrative

	return report

func _destroy_ship(ship: NamedShip, reason: String) -> void:
	ship.is_destroyed = true
	ship.destruction_report = reason
	ship.health = 0.0

# ============================================================================
# DISTRESS CALLS & TRANSMISSIONS
# ============================================================================

func generate_distress_call(zone_id: int, herald_strength: int) -> BattleReport:
	var zone_name = FCWTypes.get_zone_name(zone_id)
	var ships = get_ships_at_zone(zone_id)

	var report = BattleReport.new()
	report.zone_id = zone_id
	report.report_type = "distress"
	report.is_critical = true

	var calls = [
		"MAYDAY MAYDAY - %s Station under attack! Herald fleet strength %d!",
		"Priority Alpha - %s perimeter breached. Requesting immediate reinforcement.",
		"All ships, all ships - %s is falling. Evacuation protocol initiated.",
		"This is %s Command - We are overwhelmed. Send everything you have.",
		"Emergency broadcast from %s - Civilian transports taking fire!",
		"Flash traffic - Herald forces at %s. We cannot hold!",
	]

	var call_text = calls[_rng.randi() % calls.size()]
	call_text = call_text.replace("%s", zone_name)
	call_text = call_text % herald_strength if "%d" in call_text else call_text

	report.headline = "DISTRESS - %s" % zone_name.to_upper()
	report.details = call_text

	if not ships.is_empty():
		var ship = ships[_rng.randi() % ships.size()]
		report.details = "[%s] %s" % [ship.get_full_name(), call_text]
		report.ships_involved = [ship.id]

	return report

func generate_evacuation_report(zone_id: int, evacuated: int) -> BattleReport:
	var zone_name = FCWTypes.get_zone_name(zone_id)

	var report = BattleReport.new()
	report.zone_id = zone_id
	report.report_type = "evacuation"

	if evacuated > 10_000_000:
		report.headline = "MASS EVACUATION SUCCESS"
		report.details = "%s million civilians cleared from %s. Convoy escorts holding corridor." % [
			evacuated / 1_000_000, zone_name
		]
	elif evacuated > 1_000_000:
		report.headline = "EVACUATION CONVOY AWAY"
		report.details = "%s thousand aboard transports from %s. Some ships still loading." % [
			evacuated / 1_000, zone_name
		]
	else:
		report.headline = "EVACUATION UNDERWAY"
		report.details = "Transports departing %s with %s civilians. More awaiting extraction." % [
			zone_name, FCWTypes.format_population(evacuated)
		]

	return report

# ============================================================================
# QUERIES
# ============================================================================

func get_ships_at_zone(zone_id: int) -> Array:
	var ships: Array = []
	for ship_id in _ship_registry:
		var ship = _ship_registry[ship_id]
		if ship.current_zone == zone_id and not ship.is_destroyed:
			ships.append(ship)
	return ships

func get_all_active_ships() -> Array:
	var ships: Array = []
	for ship_id in _ship_registry:
		var ship = _ship_registry[ship_id]
		if not ship.is_destroyed:
			ships.append(ship)
	return ships

func get_destroyed_ships() -> Array:
	var ships: Array = []
	for ship_id in _ship_registry:
		var ship = _ship_registry[ship_id]
		if ship.is_destroyed:
			ships.append(ship)
	return ships

func get_total_casualties() -> int:
	var total = 0
	for ship_id in _ship_registry:
		var ship = _ship_registry[ship_id]
		if ship.is_destroyed:
			total += ship.crew_count
	return total

func get_recent_reports(count: int = 10) -> Array:
	var start = maxi(0, _battle_reports.size() - count)
	return _battle_reports.slice(start)

func get_ship_by_id(ship_id: String) -> NamedShip:
	return _ship_registry.get(ship_id)

# ============================================================================
# FLEET MANAGEMENT
# ============================================================================

func assign_ships_to_zone(from_zone: int, to_zone: int, ship_type: int, count: int) -> void:
	var ships = get_ships_at_zone(from_zone).filter(func(s):
		return FCWTypes.get_ship_name(ship_type) == s.ship_class
	)

	var to_move = mini(count, ships.size())
	for i in range(to_move):
		ships[i].current_zone = to_zone

func create_new_ship(ship_type: int, zone_id: int) -> NamedShip:
	var ship = _create_named_ship(ship_type, zone_id)
	_ship_registry[ship.id] = ship
	return ship

func get_fleet_roster_text() -> String:
	var text = "=== FLEET ROSTER ===\n\n"

	var active = get_all_active_ships()
	var destroyed = get_destroyed_ships()

	text += "ACTIVE SHIPS: %d\n" % active.size()
	for ship in active:
		text += "  %s\n" % ship.get_status_report()

	text += "\nLOST IN ACTION: %d\n" % destroyed.size()
	for ship in destroyed:
		text += "  [KIA] %s - %s\n" % [ship.get_full_name(), ship.captain]

	text += "\nTOTAL CASUALTIES: %d crew\n" % get_total_casualties()

	return text
