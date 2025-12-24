extends Control
class_name FCWSolarMap

## Visual Solar System Map for First Contact War
## DRAMATIC EDITION - Explosions, lasers, warp jumps, and desperation

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWHeraldAI = preload("res://scripts/first_contact_war/fcw_herald_ai.gd")

signal zone_clicked(zone_id: int)
signal zone_hovered(zone_id: int)
signal entity_clicked(entity_id: String)
signal entity_destination_selected(entity_id: String, destination_zone: int, route_type: String)

# ============================================================================
# ZOOM LEVELS - Multi-level view like Star Wars Rebellion
# ============================================================================

enum ZoomLevel {
	GALAXY,   # Sol as tiny point among billions - "Humanity's last light"
	SYSTEM,   # Current strategic view - all 6 zones
	PLANET    # Single zone enlarged with staging areas - intense focus
}

# ============================================================================
# CONSTANTS
# ============================================================================

# Zone positions in normalized coordinates (0-1 range, scaled to control size)
const ZONE_POSITIONS = {
	FCWTypes.ZoneId.EARTH: Vector2(0.85, 0.5),
	FCWTypes.ZoneId.MARS: Vector2(0.65, 0.5),
	FCWTypes.ZoneId.ASTEROID_BELT: Vector2(0.45, 0.3),
	FCWTypes.ZoneId.JUPITER: Vector2(0.45, 0.7),
	FCWTypes.ZoneId.SATURN: Vector2(0.25, 0.35),
	FCWTypes.ZoneId.KUIPER: Vector2(0.1, 0.5)
}

const ZONE_SIZES = {
	FCWTypes.ZoneId.EARTH: 40.0,
	FCWTypes.ZoneId.MARS: 25.0,
	FCWTypes.ZoneId.ASTEROID_BELT: 20.0,
	FCWTypes.ZoneId.JUPITER: 35.0,
	FCWTypes.ZoneId.SATURN: 30.0,
	FCWTypes.ZoneId.KUIPER: 15.0
}

const ZONE_COLORS = {
	FCWTypes.ZoneId.EARTH: Color(0.2, 0.5, 1.0),      # Blue
	FCWTypes.ZoneId.MARS: Color(0.9, 0.4, 0.2),       # Red-orange
	FCWTypes.ZoneId.ASTEROID_BELT: Color(0.6, 0.6, 0.6),  # Gray
	FCWTypes.ZoneId.JUPITER: Color(0.9, 0.7, 0.5),    # Orange-tan
	FCWTypes.ZoneId.SATURN: Color(0.9, 0.85, 0.6),    # Yellow-tan
	FCWTypes.ZoneId.KUIPER: Color(0.4, 0.5, 0.7)      # Cold blue
}

# Staging areas - moons, stations, asteroid clusters around each zone
# Format: {zone_id: [{name, offset, type, size}]}
enum StagingType { MOON, ASTEROID_CLUSTER, STATION, RING }

const STAGING_AREAS = {
	FCWTypes.ZoneId.EARTH: [
		{"name": "Luna", "offset": Vector2(-50, -30), "type": StagingType.MOON, "size": 8},
		{"name": "L2 Station", "offset": Vector2(55, 20), "type": StagingType.STATION, "size": 5},
	],
	FCWTypes.ZoneId.MARS: [
		{"name": "Phobos", "offset": Vector2(-35, -20), "type": StagingType.MOON, "size": 5},
		{"name": "Deimos", "offset": Vector2(30, 25), "type": StagingType.MOON, "size": 4},
	],
	FCWTypes.ZoneId.ASTEROID_BELT: [
		{"name": "Ceres Cluster", "offset": Vector2(-40, 0), "type": StagingType.ASTEROID_CLUSTER, "size": 12},
		{"name": "Vesta Field", "offset": Vector2(35, -25), "type": StagingType.ASTEROID_CLUSTER, "size": 10},
	],
	FCWTypes.ZoneId.JUPITER: [
		{"name": "Europa", "offset": Vector2(-45, -35), "type": StagingType.MOON, "size": 7},
		{"name": "Ganymede", "offset": Vector2(50, 10), "type": StagingType.MOON, "size": 9},
		{"name": "Io Station", "offset": Vector2(-30, 40), "type": StagingType.STATION, "size": 5},
	],
	FCWTypes.ZoneId.SATURN: [
		{"name": "Titan", "offset": Vector2(-45, 25), "type": StagingType.MOON, "size": 8},
		{"name": "Rings", "offset": Vector2(0, 0), "type": StagingType.RING, "size": 45},
		{"name": "Enceladus", "offset": Vector2(40, -20), "type": StagingType.MOON, "size": 5},
	],
	FCWTypes.ZoneId.KUIPER: [
		{"name": "Pluto", "offset": Vector2(-25, -15), "type": StagingType.MOON, "size": 6},
		{"name": "Eris Cluster", "offset": Vector2(30, 20), "type": StagingType.ASTEROID_CLUSTER, "size": 8},
	]
}

# ============================================================================
# PARTICLE TYPES
# ============================================================================

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var life: float
	var max_life: float
	var size: float

class Ship:
	var pos: Vector2
	var start_pos: Vector2
	var target: Vector2
	var control_point: Vector2  # For bezier curve
	var color: Color
	var engine_color: Color
	var progress: float = 0.0
	var trail: Array = []  # Trail positions
	var trail_colors: Array = []  # Trail colors (fade)

	# Flight characteristics
	enum ShipClass { FRIGATE, CRUISER, CARRIER, DREADNOUGHT }
	var ship_class: int = ShipClass.FRIGATE
	var speed: float = 1.0  # Base speed multiplier
	var size: float = 6.0
	var rotation: float = 0.0
	var bank_angle: float = 0.0  # Visual banking

	# Engine effects
	var engine_intensity: float = 1.0
	var afterburner: bool = false
	var afterburner_timer: float = 0.0

	# Formation
	var formation_offset: Vector2 = Vector2.ZERO
	var formation_index: int = 0

	func get_bezier_pos(t: float) -> Vector2:
		# Quadratic bezier curve for smooth flight path
		var t1 = 1.0 - t
		return t1 * t1 * start_pos + 2 * t1 * t * control_point + t * t * target

	func get_bezier_tangent(t: float) -> Vector2:
		# Derivative for direction
		var t1 = 1.0 - t
		return 2 * t1 * (control_point - start_pos) + 2 * t * (target - control_point)

class Laser:
	var start: Vector2
	var end: Vector2
	var color: Color
	var life: float = 0.3
	var width: float = 2.0

class Explosion:
	var pos: Vector2
	var radius: float = 0.0
	var max_radius: float
	var life: float = 1.0
	var color: Color

class Skirmish:
	## Ongoing combat zone near a staging area
	var pos: Vector2
	var radius: float = 30.0
	var intensity: float = 1.0  # 0-1, fades over time
	var staging_name: String = ""
	var zone_id: int = -1
	var ships_engaged: int = 0
	var is_herald_attack: bool = false
	var laser_timer: float = 0.0
	var explosion_timer: float = 0.0

class AttackWave:
	## Incoming Herald attack wave
	var ships: Array = []  # Ship objects in this wave
	var target_zone: int = -1
	var target_staging: Dictionary = {}  # Staging area info
	var wave_size: int = 5
	var spawn_timer: float = 0.0
	var ships_spawned: int = 0
	var spawn_position: Vector2 = Vector2.ZERO  # Where ships spawn FROM (herald position when wave started)

class CivilianShip:
	## Civilian transports, miners, freighters - signs of peaceful life
	enum CivType { TRANSPORT, MINER, FREIGHTER, LINER, TANKER }
	var pos: Vector2
	var start_pos: Vector2
	var target: Vector2
	var control_point: Vector2
	var progress: float = 0.0
	var civ_type: int = CivType.TRANSPORT
	var color: Color = Color(0.6, 0.7, 0.8)
	var size: float = 4.0
	var speed: float = 0.25
	var trail: Array = []
	var from_zone: int = -1
	var to_zone: int = -1

	func get_bezier_pos(t: float) -> Vector2:
		var t1 = 1.0 - t
		return t1 * t1 * start_pos + 2 * t1 * t * control_point + t * t * target

class ColonyShip:
	## Evacuation colony ships - large, slow, precious. Carrying humanity's hope.
	var pos: Vector2
	var start_pos: Vector2
	var target: Vector2  # Edge of map (toward stars)
	var progress: float = 0.0
	var speed: float = 0.08  # Slow, stately departure
	var name: String = "Colony Ship"
	var souls_aboard: int = 0
	var trail: Array = []
	var warp_flash: float = 0.0  # Initial warp flash effect

	static var ship_names: Array = [
		"New Dawn", "Last Hope", "Exodus", "Sanctuary", "Pioneer",
		"Harbinger", "Salvation", "Odyssey", "Perseverance", "Genesis",
		"Horizon", "Eternal", "Vanguard", "Promise", "Aurora"
	]

	static func create(start: Vector2, target: Vector2, population: int) -> ColonyShip:
		var ship = ColonyShip.new()
		ship.pos = start
		ship.start_pos = start
		ship.target = target
		ship.souls_aboard = population
		ship.name = ship_names[randi() % ship_names.size()]
		ship.warp_flash = 1.0
		return ship

class Transmission:
	## Radio transmission overlay - storytelling through comms
	var text: String = ""
	var sender: String = ""
	var pos: Vector2 = Vector2.ZERO
	var life: float = 6.0
	var max_life: float = 6.0
	var priority: int = 0  # 0=routine, 1=important, 2=critical, 3=desperate
	var fade_in: float = 0.0
	var typing_progress: float = 0.0  # For typewriter effect

# ============================================================================
# NARRATIVE CONSTANTS
# ============================================================================

# Transmission templates for different situations
const TRANSMISSIONS_PEACE = [
	{"sender": "Ceres Mining", "text": "Ore shipment en route to Mars. All nominal."},
	{"sender": "Luna Traffic", "text": "Passenger liner departing for Jupiter colonies."},
	{"sender": "Belt Haulers", "text": "Freighter convoy cleared for Earth approach."},
	{"sender": "Titan Refinery", "text": "Fuel reserves at 94%. Production steady."},
	{"sender": "Europa Station", "text": "Research vessel returning with samples."},
	{"sender": "Traffic Control", "text": "Solar lanes clear. Safe travels, all ships."},
]

const TRANSMISSIONS_TENSION = [
	{"sender": "Fleet Command", "text": "All ships maintain defensive positions."},
	{"sender": "Early Warning", "text": "Herald signatures detected. Stand by."},
	{"sender": "Civilian Auth", "text": "Non-essential traffic suspended."},
	{"sender": "Mars Defense", "text": "Scrambling patrol wings. Code Yellow."},
	{"sender": "Intel", "text": "Enemy strength assessment in progress..."},
]

const TRANSMISSIONS_COMBAT = [
	{"sender": "Battlegroup", "text": "Engaging hostile forces! All hands!"},
	{"sender": "Defense Grid", "text": "Shields holding! Return fire!"},
	{"sender": "Squadron Lead", "text": "Break and attack! For Earth!"},
	{"sender": "Flagship", "text": "All batteries, concentrate fire!"},
	{"sender": "Wing Commander", "text": "Stay in formation! Cover each other!"},
]

const TRANSMISSIONS_DESPERATE = [
	{"sender": "Mayday", "text": "Hull breach! Evacuating decks 3 through 7!"},
	{"sender": "Last Stand", "text": "We'll hold them here. Get the civvies out."},
	{"sender": "Evac Fleet", "text": "Transports away! Buying them time!"},
	{"sender": "Command", "text": "All ships, fall back to secondary line!"},
	{"sender": "Distress", "text": "This is our final transmission..."},
]

const TRANSMISSIONS_VICTORY = [
	{"sender": "Fleet Command", "text": "Hostiles retreating! Zone secure!"},
	{"sender": "All Channels", "text": "We held the line! Casualties being assessed."},
	{"sender": "Medical", "text": "Search and rescue underway for survivors."},
	{"sender": "Command", "text": "Outstanding work. Rest while you can."},
]

const TRANSMISSIONS_LOSS = [
	{"sender": "Command", "text": "...zone lost. All surviving ships withdraw."},
	{"sender": "Rescue Ops", "text": "Searching for escape pods... so few..."},
	{"sender": "Memorial", "text": "Moment of silence for the fallen."},
	{"sender": "Intel", "text": "Regrouping. The Herald advances."},
]

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}  # Full game state for entity system access
var _zones: Dictionary = {}
var _is_paused: bool = false  # When true, all ship movement freezes
var _speed_multiplier: float = 1.0  # Game speed (0.5=slow, 1=normal, 4=fast, 12=very fast)
var _herald_position: Vector2 = Vector2.ZERO
var _herald_target_position: Vector2 = Vector2.ZERO
var _herald_start_position: Vector2 = Vector2.ZERO  # Position at start of transit
var _herald_current_zone: int = FCWTypes.ZoneId.KUIPER
var _herald_target_zone: int = FCWTypes.ZoneId.KUIPER
var _herald_strength: int = 50
var _herald_visible: bool = false  # Herald only visible after detection (week 3+)
var _herald_transit: Dictionary = {}  # Current herald transit data
var _current_turn: int = 1
var _selected_zone: int = -1
var _hovered_zone: int = -1
var _fleet_assignments: Dictionary = {}

# Entity selection for route planning
var _selected_entity_id: String = ""  # Currently selected entity
var _hovered_entity_id: String = ""   # Entity under mouse
var _route_selection_mode: bool = false  # True when waiting for destination click
var _route_options_visible: bool = false  # Show route options popup
var _route_options_zone: int = -1  # Destination zone for route options
var _route_options: Array = []  # Cached route options for display
const ENTITY_CLICK_RADIUS = 25.0  # Pixels - click detection radius for entities (larger for ships near planets)

# Stacked entity cycling (for selecting ships at same location)
var _entities_at_click: Array = []  # All entities at last click position
var _entity_cycle_index: int = 0  # Current index in cycle

# Fleet roster tracking
var _starting_fleet: Dictionary = {}  # Starting counts by ship type
var _current_fleet: Dictionary = {}   # Current counts by ship type
var _capital_ship_states: Array = []  # Array of {type, alive, entity_id} for grid display
var _roster_item_rects: Array = []  # Click rects for roster items [{rect, index}]
var _roster_panel_rect: Rect2 = Rect2()  # Panel bounds for click detection
var _fleets_in_transit: Array = []  # Fleets traveling between zones
var _week_progress: float = 0.0  # Continuous progress through current week (0.0-1.0)
var _attack_flash_timer: float = 0.0
var _is_attacking: bool = false
var _global_time: float = 0.0

# Animation
var _herald_travel_progress: float = 1.0  # 0 = at origin, 1 = at target (now controlled by set_time_progress)

# Visual Effects
var _particles: Array = []  # Engine trails, debris, sparks
var _ships: Array = []  # Moving ship sprites
var _lasers: Array = []  # Active laser beams
var _explosions: Array = []  # Active explosions
var _screen_shake: Vector2 = Vector2.ZERO
var _screen_shake_intensity: float = 0.0
var _danger_pulse: float = 0.0  # Red vignette intensity
var _warp_flashes: Array = []  # [{pos, life}]
var _zone_damage_flash: Dictionary = {}  # zone_id -> flash intensity
var _fallen_zones: Array = []  # Track which zones have fallen for debris
var _nebula_offset: float = 0.0  # Slow drift
var _skirmishes: Array = []  # Active skirmish zones
var _attack_waves: Array = []  # Incoming Herald attack waves
var _herald_ships: Array = []  # Herald ships (red, menacing)

# Civilian/Narrative systems
var _civilian_ships: Array = []  # Peaceful traffic
var _transmissions: Array = []  # Radio comms overlay
var _civilian_spawn_timer: float = 0.0
var _transmission_cooldown: float = 0.0
var _narrative_state: int = 0  # 0=peace, 1=tension, 2=combat, 3=desperate
var _last_narrative_state: int = 0
var _mood_transition_timer: float = 0.0

# Exodus system - colony ships escaping to the stars
var _colony_ships: Array = []  # Active colony ships en route
var _exodus_ships_escaped: int = 0  # Total ships that reached safety
var _exodus_souls_escaped: int = 0  # Total people on escaped ships
var _last_evacuation_count: int = 0  # Track when to spawn new colony ships
var _colony_ship_spawn_accumulator: int = 0  # Accumulate evacuation until ship spawns
var _lives_intercepted: int = 0  # Lives lost to Herald interception (from game state)

# Narrative tracking
var _zones_lost_this_session: int = 0
var _total_evacuated: int = 0
var _milestone_flags: Dictionary = {}  # Track which milestones triggered

# Zoom system - multi-level view
var _zoom_level: int = ZoomLevel.SYSTEM  # Current zoom level
var _zoom_target: int = ZoomLevel.SYSTEM  # Target zoom level (for animation)
var _zoom_transition: float = 1.0  # 0 = at origin zoom, 1 = at target zoom
var _zoom_focus_zone: int = -1  # Which zone to focus on in PLANET view
var _zoom_planet_scale: float = 3.0  # How much to enlarge in planet view
var _zoom_galaxy_scale: float = 0.05  # How small Sol is in galaxy view

# Galaxy view state
var _galaxy_stars: Array = []  # Pre-generated star positions for galaxy
var _galaxy_sol_pulse: float = 0.0  # Pulsing effect for Sol marker

# ============================================================================
# LIFECYCLE
# ============================================================================

var _initialized: bool = false

func _ready() -> void:
	# Defer initialization until size is valid
	pass

func _ensure_initialized() -> void:
	# Don't initialize until we have a valid size
	if _initialized or size.x < 10 or size.y < 10:
		return
	_initialized = true
	# Initialize herald at its current zone (starts at Kuiper)
	var herald_pos = _get_zone_pixel_pos(_herald_current_zone)
	_herald_position = herald_pos
	_herald_start_position = herald_pos
	_herald_target_position = herald_pos

func _process(delta: float) -> void:
	_ensure_initialized()
	if not _initialized:
		return  # Wait for valid size

	# Update screen shake (always runs for visual feedback, decays to zero)
	if _screen_shake_intensity > 0:
		_screen_shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _screen_shake_intensity
		_screen_shake_intensity = maxf(_screen_shake_intensity - delta * 20.0, 0.0)
	else:
		_screen_shake = Vector2.ZERO

	# Update zoom transitions (always runs for UI responsiveness)
	_update_zoom(delta)

	# === PAUSED: Skip all time-dependent updates ===
	# This includes _global_time which drives visual animations
	if _is_paused:
		queue_redraw()  # Still redraw so we see current (frozen) state
		return

	# === GAME DELTA: Scale by speed multiplier ===
	# All game-speed-dependent updates use this instead of raw delta
	var game_delta = delta * _speed_multiplier

	# Update global time and nebula drift (scaled by game speed)
	_global_time += game_delta
	_nebula_offset += game_delta * 0.02  # Slow drift

	# NOTE: Herald movement is now handled in set_time_progress() for smooth multi-week travel
	# Trail particles are spawned there when Herald is in transit

	# Flash when attacking - spawn combat effects
	if _is_attacking:
		_attack_flash_timer += game_delta * 5.0
		_danger_pulse = minf(_danger_pulse + game_delta * 2.0, 1.0)
		# Spawn lasers and explosions during combat
		if randf() < game_delta * 15.0:
			_spawn_combat_laser()
		if randf() < game_delta * 8.0:
			_spawn_combat_explosion()
	else:
		_danger_pulse = maxf(_danger_pulse - game_delta * 1.5, 0.0)

	# Update particles
	_update_particles(game_delta)

	# Update ships in transit
	_update_ships(game_delta)

	# Update lasers
	_update_lasers(game_delta)

	# Update explosions
	_update_explosions(game_delta)

	# Update warp flashes
	_update_warp_flashes(game_delta)

	# Update zone damage flashes
	for zone_id in _zone_damage_flash.keys():
		_zone_damage_flash[zone_id] = maxf(_zone_damage_flash[zone_id] - game_delta * 3.0, 0.0)

	# Update skirmishes
	_update_skirmishes(game_delta)

	# Update attack waves
	_update_attack_waves(game_delta)

	# Update herald ships
	_update_herald_ships(game_delta)

	# Update civilian traffic
	_update_civilian_ships(game_delta)
	_maybe_spawn_civilian_ship(game_delta)

	# Update colony ships (exodus fleet)
	_update_colony_ships(game_delta)

	# Update transmissions
	_update_transmissions(game_delta)
	_maybe_spawn_transmission(game_delta)

	# Ambient particles near zones with ships (only in system view)
	if _zoom_level == ZoomLevel.SYSTEM:
		_spawn_ambient_particles(game_delta)

	queue_redraw()

func _draw() -> void:
	if not _initialized:
		return  # Don't draw until positions are valid

	var rect = get_rect()

	# Route to appropriate view based on zoom level
	match _zoom_level:
		ZoomLevel.GALAXY:
			_draw_galaxy_view(rect)
		ZoomLevel.SYSTEM:
			_draw_system_view(rect)
		ZoomLevel.PLANET:
			_draw_planet_view(rect)
		_:
			# Default fallback to system view
			_draw_system_view(rect)

	# Always draw transmissions on top (UI overlay)
	_draw_transmissions(rect)

	# Draw zoom transition overlay if transitioning
	if _zoom_transition < 1.0:
		_draw_zoom_transition(rect)

func _draw_system_view(rect: Rect2) -> void:
	## The main strategic view - all zones visible
	# Apply screen shake offset
	var offset = _screen_shake

	# Draw nebula background
	_draw_nebula(rect, offset)

	# Draw starfield background
	_draw_starfield(rect, offset)

	# Draw zone connections with energy flow
	_draw_connections(rect, offset)

	# Draw fallen zone debris
	_draw_debris(rect, offset)

	# Draw particles (behind zones)
	_draw_particles(offset)

	# Draw staging areas (behind planets)
	for zone_id in FCWTypes.ZoneId.values():
		_draw_staging_areas(zone_id, rect, offset)

	# Draw zones
	for zone_id in FCWTypes.ZoneId.values():
		_draw_zone(zone_id, rect, offset)

	# Draw zone signature bars (detection levels for Herald targeting)
	_draw_zone_signatures(offset)

	# Draw Herald attention arrow (shows where Herald is tracking)
	_draw_herald_attention_arrow(offset)

	# Draw skirmishes (combat zones)
	_draw_skirmishes(offset)

	# Draw warp flashes
	_draw_warp_flashes(offset)

	# Draw civilian traffic (ambient atmosphere)
	_draw_civilian_ships(offset)

	# Draw herald attack ships (drones)
	_draw_herald_ships(offset)

	# Draw player fleets at zones (for zone defense indicator)
	_draw_player_fleets(rect, offset)

	# Entity system visualization
	# Draw Herald observation zone (behind entities)
	_draw_herald_observation_zone(offset)

	# Draw detection probability zones (more detailed concentric rings)
	_draw_detection_probability_zones(offset)

	# Draw traffic patterns that Herald has learned
	_draw_traffic_patterns(offset)

	# Draw entity trajectories (before entities)
	_draw_entity_trajectories(offset)

	# Draw route preview curves when entity is selected (shows possible paths)
	if _route_selection_mode and _selected_entity_id != "" and not _route_options_visible:
		_draw_route_preview_curves(offset)

	# Draw all entities from unified entity system
	_draw_entities(offset)

	# Draw lasers
	_draw_lasers(offset)

	# Draw explosions
	_draw_explosions(offset)

	# Draw Herald fleet
	_draw_herald(rect, offset)

	# Draw attack indicator if attacking
	if _is_attacking:
		_draw_attack_indicator(rect, offset)

	# Draw danger vignette
	if _danger_pulse > 0.01:
		_draw_danger_vignette(rect)

	# Draw exodus counter (top of screen, always visible when ships are escaping)
	_draw_exodus_counter(rect)

	# Draw fleet roster (bottom-right, shows UNN fleet status)
	_draw_fleet_roster(rect)

	# Draw route cost previews when entity is selected (before clicking destination)
	if _route_selection_mode and _selected_entity_id != "" and not _route_options_visible:
		_draw_route_cost_previews(offset)

	# Draw route selection UI (on top of everything else)
	if _route_options_visible:
		_draw_route_options_popup()

# ============================================================================
# DRAWING
# ============================================================================

func _draw_nebula(rect: Rect2, offset: Vector2) -> void:
	# Dark space with subtle colored nebula clouds
	draw_rect(rect, Color(0.01, 0.01, 0.03))

	# Draw subtle nebula patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 54321
	for i in range(8):
		var base_pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var nebula_pos = base_pos + Vector2(sin(_nebula_offset + i), cos(_nebula_offset * 0.7 + i)) * 10 + offset
		var nebula_color = Color(
			rng.randf_range(0.1, 0.3),
			rng.randf_range(0.0, 0.15),
			rng.randf_range(0.15, 0.4),
			0.03
		)
		var nebula_size = rng.randf_range(80, 200)
		# Multiple overlapping circles for cloud effect
		for j in range(5):
			var jitter = Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
			draw_circle(nebula_pos + jitter, nebula_size * (1.0 - j * 0.15), nebula_color)

func _draw_starfield(rect: Rect2, offset: Vector2) -> void:
	# Multi-layer starfield with twinkling
	var rng = RandomNumberGenerator.new()

	# Layer 1: Distant dim stars
	rng.seed = 12345
	for i in range(100):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.3
		var twinkle = sin(_global_time * rng.randf_range(1.0, 3.0) + i) * 0.3 + 0.7
		var brightness = rng.randf_range(0.1, 0.4) * twinkle
		draw_circle(pos, 0.5, Color(brightness, brightness, brightness * 0.9))

	# Layer 2: Brighter stars
	rng.seed = 67890
	for i in range(40):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.5
		var twinkle = sin(_global_time * rng.randf_range(2.0, 5.0) + i * 0.5) * 0.4 + 0.6
		var brightness = rng.randf_range(0.5, 1.0) * twinkle
		var star_color = Color(brightness, brightness * rng.randf_range(0.9, 1.0), brightness * rng.randf_range(0.8, 1.0))
		draw_circle(pos, rng.randf_range(0.8, 1.5), star_color)

	# Layer 3: Occasional bright stars with glow
	rng.seed = 11111
	for i in range(8):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.7
		var twinkle = sin(_global_time * 1.5 + i * 2.0) * 0.3 + 0.7
		draw_circle(pos, 4, Color(1.0, 1.0, 0.9, 0.1 * twinkle))
		draw_circle(pos, 2, Color(1.0, 1.0, 0.95, 0.6 * twinkle))

func _draw_connections(rect: Rect2, offset: Vector2) -> void:
	# Draw lines between connected zones with energy flow effect
	for zone_id in FCWTypes.ZONE_CONNECTIONS:
		var pos1 = _get_zone_pixel_pos(zone_id) + offset
		for connected_zone in FCWTypes.ZONE_CONNECTIONS[zone_id]:
			if connected_zone > zone_id:  # Avoid double-drawing
				var pos2 = _get_zone_pixel_pos(connected_zone) + offset

				# Base connection line
				draw_line(pos1, pos2, Color(0.15, 0.2, 0.3, 0.4), 1.0)

				# Energy pulse traveling along the line (if both zones controlled)
				var zone1_data = _zones.get(zone_id, {})
				var zone2_data = _zones.get(connected_zone, {})
				if zone1_data.get("status", 0) == FCWTypes.ZoneStatus.CONTROLLED and zone2_data.get("status", 0) == FCWTypes.ZoneStatus.CONTROLLED:
					var pulse_pos = fmod(_global_time * 0.3 + zone_id * 0.1, 1.0)
					var pulse_point = pos1.lerp(pos2, pulse_pos)
					draw_circle(pulse_point, 2, Color(0.3, 0.6, 1.0, 0.6))

func _draw_debris(rect: Rect2, offset: Vector2) -> void:
	# Draw debris particles around fallen zones
	var rng = RandomNumberGenerator.new()
	for zone_id in _fallen_zones:
		var pos = _get_zone_pixel_pos(zone_id) + offset
		var base_size = ZONE_SIZES.get(zone_id, 20.0)
		rng.seed = zone_id * 1000 + int(_global_time * 2) % 100

		for i in range(15):
			var angle = rng.randf() * TAU + _global_time * 0.1
			var dist = base_size + rng.randf_range(5, 40)
			var debris_pos = pos + Vector2(cos(angle), sin(angle)) * dist
			var debris_size = rng.randf_range(1, 3)
			var alpha = rng.randf_range(0.2, 0.5)
			draw_circle(debris_pos, debris_size, Color(0.4, 0.3, 0.2, alpha))

func _draw_particles(offset: Vector2) -> void:
	for p in _particles:
		var alpha = p.life / p.max_life
		var color = Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
		draw_circle(p.pos + offset, p.size * alpha, color)

func _draw_zone(zone_id: int, _rect: Rect2, offset: Vector2) -> void:
	var pos = _get_zone_pixel_pos(zone_id) + offset
	var base_size = ZONE_SIZES.get(zone_id, 20.0)
	var color = ZONE_COLORS.get(zone_id, Color.WHITE)

	var zone_data = _zones.get(zone_id, {})
	var status = zone_data.get("status", FCWTypes.ZoneStatus.CONTROLLED)

	# Status-based modifications
	match status:
		FCWTypes.ZoneStatus.FALLEN:
			color = color.darkened(0.7)
			# Draw cracked/damaged effect
			var crack_intensity = 0.3
			draw_circle(pos, base_size + 3, Color(0.3, 0.1, 0.0, crack_intensity))
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			# Intense pulse effect
			var pulse = sin(_attack_flash_timer * 4.0) * 0.4 + 0.6
			color = color.lerp(Color.RED, 0.6 * pulse)
			# Shield flicker effect
			var shield_alpha = sin(_attack_flash_timer * 8.0) * 0.3 + 0.4
			draw_arc(pos, base_size + 5, 0, TAU, 32, Color(0.5, 0.8, 1.0, shield_alpha), 2.0)

	# Damage flash overlay
	var damage_flash = _zone_damage_flash.get(zone_id, 0.0)
	if damage_flash > 0:
		color = color.lerp(Color.WHITE, damage_flash)

	# Selection/hover highlight
	if zone_id == _selected_zone:
		draw_circle(pos, base_size + 10, Color(1.0, 1.0, 0.5, 0.3))
		draw_arc(pos, base_size + 10, 0, TAU, 32, Color(1.0, 1.0, 0.5, 0.8), 2.0)
	elif zone_id == _hovered_zone:
		draw_circle(pos, base_size + 6, Color(1.0, 1.0, 1.0, 0.15))

	# Herald target indicator - TERRIFYING ATTACK WARNING
	if zone_id == _herald_target_zone and status != FCWTypes.ZoneStatus.FALLEN:
		var target_pulse = sin(_attack_flash_timer * 3.0) * 0.4 + 0.6
		var fast_pulse = sin(_attack_flash_timer * 8.0) * 0.5 + 0.5

		# Outer danger zone - large pulsing red ring
		draw_arc(pos, base_size + 30, 0, TAU, 48, Color(1.0, 0.0, 0.0, target_pulse * 0.4), 4.0)
		draw_arc(pos, base_size + 35, 0, TAU, 48, Color(1.0, 0.0, 0.0, target_pulse * 0.2), 2.0)

		# Multiple warning rings - closing in
		draw_arc(pos, base_size + 15, 0, TAU, 32, Color(1.0, 0.2, 0.1, target_pulse * 0.9), 3.0)
		draw_arc(pos, base_size + 20, 0, TAU, 32, Color(1.0, 0.1, 0.0, target_pulse * 0.6), 2.0)

		# Rotating warning segments
		var rot = _global_time * 2.0
		for i in range(6):
			var start_angle = rot + i * TAU / 6
			draw_arc(pos, base_size + 40, start_angle, start_angle + 0.2, 8, Color(1.0, 0.3, 0.1, fast_pulse * 0.8), 3.0)

		# ATTACK LABEL - BIG and SCARY
		var font = ThemeDB.fallback_font
		var label_pos = pos + Vector2(-50, -base_size - 50)
		var label_bg = Rect2(label_pos - Vector2(5, 12), Vector2(100, 18))
		draw_rect(label_bg, Color(0.5, 0.0, 0.0, fast_pulse * 0.9))
		draw_rect(label_bg, Color(1.0, 0.3, 0.2, fast_pulse), false, 2.0)
		draw_string(font, label_pos, "⚠ UNDER ATTACK ⚠", HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color(1.0, 1.0, 1.0, fast_pulse))

		# Show overwhelming numbers if herald is stronger
		if _herald_strength > 0:
			var threat_ratio = float(_herald_strength) / maxf(zone_data.get("defense", 1), 1)
			var threat_text = ""
			var threat_color = Color.WHITE
			if threat_ratio > 2.0:
				threat_text = "OVERWHELMING FORCE"
				threat_color = Color(1.0, 0.2, 0.2)
			elif threat_ratio > 1.5:
				threat_text = "SUPERIOR NUMBERS"
				threat_color = Color(1.0, 0.5, 0.3)
			elif threat_ratio > 1.0:
				threat_text = "OUTNUMBERED"
				threat_color = Color(1.0, 0.7, 0.4)
			else:
				threat_text = "HOLDING"
				threat_color = Color(0.5, 1.0, 0.5)

			if threat_text.length() > 0:
				draw_string(font, pos + Vector2(-40, base_size + 25), threat_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(threat_color.r, threat_color.g, threat_color.b, target_pulse))

	# Planet glow (atmospheric effect)
	if status != FCWTypes.ZoneStatus.FALLEN:
		draw_circle(pos, base_size + 3, Color(color.r, color.g, color.b, 0.2))

	# Draw the planet
	draw_circle(pos, base_size, color)

	# Planet shine highlight
	if status != FCWTypes.ZoneStatus.FALLEN:
		var highlight_pos = pos + Vector2(-base_size * 0.3, -base_size * 0.3)
		draw_circle(highlight_pos, base_size * 0.3, Color(1, 1, 1, 0.2))

	# Draw zone name
	var font = ThemeDB.fallback_font
	var font_size = 12
	var zone_name = FCWTypes.get_zone_name(zone_id)
	var text_size = font.get_string_size(zone_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var name_color = Color.WHITE if status != FCWTypes.ZoneStatus.FALLEN else Color(0.5, 0.5, 0.5)
	draw_string(font, pos + Vector2(-text_size.x / 2, base_size + 18), zone_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, name_color)

	# Draw defense value with color coding
	if status != FCWTypes.ZoneStatus.FALLEN:
		var defense = zone_data.get("defense", 0)
		var def_text = "DEF: %d" % defense
		var def_color: Color
		if defense >= _herald_strength * 1.3:
			def_color = Color(0.3, 1.0, 0.3)  # Strong
		elif defense >= _herald_strength:
			def_color = Color(1.0, 1.0, 0.3)  # Marginal
		else:
			def_color = Color(1.0, 0.3, 0.3)  # Weak
		draw_string(font, pos + Vector2(-25, base_size + 30), def_text, HORIZONTAL_ALIGNMENT_CENTER, 50, 10, def_color)

func _draw_staging_areas(zone_id: int, _rect: Rect2, offset: Vector2) -> void:
	var zone_pos = _get_zone_pixel_pos(zone_id) + offset
	var staging_list = STAGING_AREAS.get(zone_id, [])

	for staging in staging_list:
		var staging_pos = zone_pos + staging.offset
		var staging_size = staging.size
		var staging_type = staging.type

		match staging_type:
			StagingType.MOON:
				_draw_moon(staging_pos, staging_size, staging.name)
			StagingType.ASTEROID_CLUSTER:
				_draw_asteroid_cluster(staging_pos, staging_size, staging.name)
			StagingType.STATION:
				_draw_station(staging_pos, staging_size, staging.name)
			StagingType.RING:
				_draw_ring(zone_pos, staging_size)

func _draw_moon(pos: Vector2, size: float, moon_name: String) -> void:
	# Gray rocky moon with crater detail
	var base_color = Color(0.5, 0.5, 0.55)

	# Outer glow
	draw_circle(pos, size + 2, Color(0.4, 0.4, 0.5, 0.2))

	# Main body
	draw_circle(pos, size, base_color)

	# Crater shadows (darker spots)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(moon_name)
	for i in range(3):
		var crater_offset = Vector2(rng.randf_range(-size * 0.5, size * 0.5),
									 rng.randf_range(-size * 0.5, size * 0.5))
		var crater_size = size * rng.randf_range(0.15, 0.3)
		draw_circle(pos + crater_offset, crater_size, base_color.darkened(0.2))

	# Highlight
	draw_circle(pos + Vector2(-size * 0.3, -size * 0.3), size * 0.25, Color(0.7, 0.7, 0.75, 0.4))

	# Name label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-20, size + 10), moon_name, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.6, 0.6, 0.7, 0.8))

func _draw_asteroid_cluster(pos: Vector2, size: float, cluster_name: String) -> void:
	# Multiple small irregular rocks
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(cluster_name)

	var asteroid_count = int(size / 2) + 3
	for i in range(asteroid_count):
		var asteroid_offset = Vector2(rng.randf_range(-size, size),
									   rng.randf_range(-size, size))
		var asteroid_size = rng.randf_range(1.5, 4)
		var color = Color(rng.randf_range(0.35, 0.5),
						  rng.randf_range(0.3, 0.45),
						  rng.randf_range(0.25, 0.4))

		# Slightly irregular shape via multiple circles
		draw_circle(pos + asteroid_offset, asteroid_size, color)
		if asteroid_size > 2.5:
			var jitter = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			draw_circle(pos + asteroid_offset + jitter, asteroid_size * 0.7, color.lightened(0.1))

	# Dashed boundary circle to show the area
	var segment_count = 16
	for i in range(segment_count):
		if i % 2 == 0:
			var angle_start = i * TAU / segment_count + _global_time * 0.1
			var angle_end = angle_start + TAU / segment_count * 0.7
			draw_arc(pos, size + 5, angle_start, angle_end, 4, Color(0.4, 0.4, 0.35, 0.3), 1.0)

	# Label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-30, size + 12), cluster_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color(0.5, 0.5, 0.5, 0.8))

func _draw_station(pos: Vector2, size: float, station_name: String) -> void:
	# Rotating space station with arms
	var rotation = _global_time * 0.5

	# Central hub
	draw_circle(pos, size * 0.6, Color(0.5, 0.55, 0.6))
	draw_circle(pos, size * 0.4, Color(0.6, 0.65, 0.7))

	# Rotating arms (4 of them)
	for i in range(4):
		var arm_angle = rotation + i * TAU / 4
		var arm_end = pos + Vector2(cos(arm_angle), sin(arm_angle)) * size
		draw_line(pos, arm_end, Color(0.5, 0.55, 0.6), 2.0)
		# End modules
		draw_circle(arm_end, size * 0.25, Color(0.55, 0.6, 0.65))

	# Blinking lights
	var blink = sin(_global_time * 3.0) * 0.5 + 0.5
	draw_circle(pos, 2, Color(0.2, 1.0, 0.3, blink))

	# Label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-25, size + 8), station_name, HORIZONTAL_ALIGNMENT_CENTER, 50, 8, Color(0.5, 0.7, 0.6, 0.8))

func _draw_ring(center_pos: Vector2, size: float) -> void:
	# Saturn-style rings (elliptical)
	var ring_colors = [
		Color(0.8, 0.75, 0.6, 0.3),
		Color(0.85, 0.8, 0.65, 0.25),
		Color(0.75, 0.7, 0.55, 0.2),
	]

	for i in range(3):
		var ring_radius = size - i * 8
		if ring_radius > 0:
			# Draw ellipse as scaled arc
			var points = PackedVector2Array()
			var point_count = 32
			for j in range(point_count + 1):
				var angle = j * TAU / point_count
				var point = center_pos + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.3)
				points.append(point)

			# Draw only the far half (behind planet)
			for j in range(point_count / 2):
				var idx = j + point_count / 4
				if idx < points.size() - 1:
					draw_line(points[idx], points[idx + 1], ring_colors[i], 3.0)

func _draw_skirmishes(offset: Vector2) -> void:
	for skirmish in _skirmishes:
		var pos = skirmish.pos + offset
		var alpha = skirmish.intensity

		# Combat zone indicator - pulsing danger circle
		var pulse = sin(_global_time * 4.0) * 0.3 + 0.7
		var radius = skirmish.radius * pulse

		# Red combat zone ring
		if skirmish.is_herald_attack:
			draw_arc(pos, radius, 0, TAU, 24, Color(1.0, 0.2, 0.1, alpha * 0.6), 2.0)
			draw_arc(pos, radius * 0.8, 0, TAU, 20, Color(1.0, 0.4, 0.2, alpha * 0.3), 1.5)
		else:
			# Defender skirmish (blue)
			draw_arc(pos, radius, 0, TAU, 24, Color(0.3, 0.6, 1.0, alpha * 0.5), 2.0)

		# Battle sparks
		var spark_count = int(skirmish.ships_engaged * 0.5)
		var rng = RandomNumberGenerator.new()
		rng.seed = int(_global_time * 10) % 1000
		for i in range(mini(spark_count, 8)):
			var spark_pos = pos + Vector2(rng.randf_range(-radius, radius),
										   rng.randf_range(-radius, radius))
			var spark_alpha = rng.randf_range(0.3, 0.8) * alpha
			draw_circle(spark_pos, rng.randf_range(1, 3), Color(1.0, 0.8, 0.3, spark_alpha))

		# Label showing engagement
		if skirmish.staging_name != "":
			var font = ThemeDB.fallback_font
			var label = "BATTLE: %s" % skirmish.staging_name
			var label_color = Color(1.0, 0.4, 0.3, alpha) if skirmish.is_herald_attack else Color(0.5, 0.8, 1.0, alpha)
			draw_string(font, pos + Vector2(-40, -radius - 5), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 9, label_color)

func _draw_herald_ships(offset: Vector2) -> void:
	# Herald ships only visible after detection (week 3+)
	if not _herald_visible:
		return

	for ship in _herald_ships:
		var pos = ship.pos + offset

		# Get direction from bezier tangent
		var tangent = ship.get_bezier_tangent(ship.progress)
		var dir = tangent.normalized() if tangent.length() > 0.1 else Vector2(1, 0)
		var perp = Vector2(-dir.y, dir.x)

		# Menacing red trail
		if ship.trail.size() > 1:
			for i in range(ship.trail.size() - 1):
				var t1 = ship.trail[i] + offset
				var t2 = ship.trail[i + 1] + offset
				var alpha = float(i) / ship.trail.size()
				var width = 1.5 + alpha * 2.5
				# Red-orange trail
				var trail_color = Color(1.0, 0.3, 0.1, alpha * 0.7)
				draw_line(t1, t2, trail_color, width)

		# Herald ship hull - angular, aggressive shape
		var ship_size = ship.size
		var hull_color = Color(0.5, 0.1, 0.4)  # Dark purple (alien)

		# Aggressive pointed design
		var points = PackedVector2Array([
			pos + dir * ship_size * 1.5,  # Sharp front
			pos + dir * ship_size * 0.2 + perp * ship_size * 0.6,
			pos - dir * ship_size * 0.5 + perp * ship_size * 0.8,
			pos - dir * ship_size * 1.0 + perp * ship_size * 0.4,
			pos - dir * ship_size * 0.8,  # Notched back
			pos - dir * ship_size * 1.0 - perp * ship_size * 0.4,
			pos - dir * ship_size * 0.5 - perp * ship_size * 0.8,
			pos + dir * ship_size * 0.2 - perp * ship_size * 0.6,
		])
		draw_colored_polygon(points, hull_color)

		# Glowing alien purple/magenta core
		draw_circle(pos, ship_size * 0.3, Color(0.9, 0.2, 0.7, 0.8))
		draw_circle(pos, ship_size * 0.15, Color(1.0, 0.6, 0.9))

		# Purple/magenta engine glow
		var engine_pos = pos - dir * ship_size * 0.9
		draw_circle(engine_pos, 4, Color(0.9, 0.1, 0.7, 0.9))
		draw_circle(engine_pos, 7, Color(0.7, 0.0, 0.5, 0.4))

func _draw_warp_flashes(offset: Vector2) -> void:
	for flash in _warp_flashes:
		var alpha = flash.life
		var ring_size = (1.0 - flash.life) * 30 + 5
		# Use custom color if provided, otherwise default cyan-blue
		var ring_color = flash.get("color", Color(0.3, 0.7, 1.0))
		draw_arc(flash.pos + offset, ring_size, 0, TAU, 16, Color(ring_color.r, ring_color.g, ring_color.b, alpha), 2.0)
		draw_circle(flash.pos + offset, 5 * alpha, Color(ring_color.r * 1.2, ring_color.g * 1.1, ring_color.b, alpha))

func _draw_ships(offset: Vector2) -> void:
	for ship in _ships:
		var pos = ship.pos + offset

		# Get direction from bezier tangent
		var tangent = ship.get_bezier_tangent(ship.progress)
		var dir = tangent.normalized() if tangent.length() > 0.1 else Vector2(1, 0)
		var perp = Vector2(-dir.y, dir.x)

		# --- ENGINE TRAIL (Long, bright, fading) ---
		if ship.trail.size() > 1:
			for i in range(ship.trail.size() - 1):
				var t1 = ship.trail[i] + offset
				var t2 = ship.trail[i + 1] + offset
				var alpha = float(i) / ship.trail.size()
				var width = 1.0 + alpha * 2.0

				# Core trail (bright)
				var core_color = Color(ship.engine_color.r, ship.engine_color.g, ship.engine_color.b, alpha * 0.8)
				draw_line(t1, t2, core_color, width)

				# Outer glow
				var glow_color = Color(ship.engine_color.r * 0.8, ship.engine_color.g * 0.8, ship.engine_color.b, alpha * 0.3)
				draw_line(t1, t2, glow_color, width * 2.5)

		# --- AFTERBURNER EFFECT ---
		if ship.afterburner:
			var afterburner_length = 15 + sin(ship.afterburner_timer * 20) * 5
			var ab_start = pos - dir * (ship.size * 0.8)
			var ab_end = ab_start - dir * afterburner_length

			# Bright core
			draw_line(ab_start, ab_end, Color(1.0, 0.9, 0.5, 0.9), 3)
			# Orange outer
			draw_line(ab_start, ab_end, Color(1.0, 0.5, 0.1, 0.6), 6)
			# Wide glow
			draw_line(ab_start, ab_end, Color(1.0, 0.3, 0.0, 0.2), 12)

		# --- SHIP HULL ---
		var ship_size = ship.size

		# Apply banking rotation for visual effect
		var bank_offset = perp * sin(ship.bank_angle) * 2

		match ship.ship_class:
			Ship.ShipClass.FRIGATE:
				# Small, fast, arrow-shaped
				var points = PackedVector2Array([
					pos + dir * ship_size + bank_offset,
					pos - dir * ship_size * 0.6 + perp * ship_size * 0.4,
					pos - dir * ship_size * 0.3,
					pos - dir * ship_size * 0.6 - perp * ship_size * 0.4
				])
				draw_colored_polygon(points, ship.color)

			Ship.ShipClass.CRUISER:
				# Medium, angular hull
				var points = PackedVector2Array([
					pos + dir * ship_size * 1.2 + bank_offset,
					pos + dir * ship_size * 0.3 + perp * ship_size * 0.5,
					pos - dir * ship_size * 0.8 + perp * ship_size * 0.6,
					pos - dir * ship_size + perp * ship_size * 0.3,
					pos - dir * ship_size - perp * ship_size * 0.3,
					pos - dir * ship_size * 0.8 - perp * ship_size * 0.6,
					pos + dir * ship_size * 0.3 - perp * ship_size * 0.5
				])
				draw_colored_polygon(points, ship.color)
				# Bridge
				draw_circle(pos + dir * ship_size * 0.4 + bank_offset, ship_size * 0.2, ship.color.lightened(0.3))

			Ship.ShipClass.CARRIER:
				# Large, flat carrier deck
				var points = PackedVector2Array([
					pos + dir * ship_size * 1.5 + bank_offset,
					pos + dir * ship_size * 0.5 + perp * ship_size * 0.8,
					pos - dir * ship_size * 1.2 + perp * ship_size * 0.8,
					pos - dir * ship_size * 1.5,
					pos - dir * ship_size * 1.2 - perp * ship_size * 0.8,
					pos + dir * ship_size * 0.5 - perp * ship_size * 0.8
				])
				draw_colored_polygon(points, ship.color)
				# Flight deck marking
				draw_line(pos - dir * ship_size * 0.8 + perp * ship_size * 0.3,
						  pos + dir * ship_size * 0.3 + perp * ship_size * 0.3,
						  Color(0.2, 0.8, 0.2, 0.6), 2)
				draw_line(pos - dir * ship_size * 0.8 - perp * ship_size * 0.3,
						  pos + dir * ship_size * 0.3 - perp * ship_size * 0.3,
						  Color(0.2, 0.8, 0.2, 0.6), 2)

			Ship.ShipClass.DREADNOUGHT:
				# Massive, imposing
				var points = PackedVector2Array([
					pos + dir * ship_size * 1.8 + bank_offset,
					pos + dir * ship_size + perp * ship_size * 0.4,
					pos + dir * ship_size * 0.5 + perp * ship_size * 0.7,
					pos - dir * ship_size * 0.5 + perp * ship_size * 0.8,
					pos - dir * ship_size * 1.5 + perp * ship_size * 0.5,
					pos - dir * ship_size * 1.5 - perp * ship_size * 0.5,
					pos - dir * ship_size * 0.5 - perp * ship_size * 0.8,
					pos + dir * ship_size * 0.5 - perp * ship_size * 0.7,
					pos + dir * ship_size - perp * ship_size * 0.4
				])
				draw_colored_polygon(points, ship.color)
				# Command tower
				var tower_points = PackedVector2Array([
					pos + dir * ship_size * 0.6 + bank_offset * 1.5,
					pos + dir * ship_size * 0.2 + perp * ship_size * 0.25 + bank_offset,
					pos - dir * ship_size * 0.3 + perp * ship_size * 0.2 + bank_offset,
					pos - dir * ship_size * 0.3 - perp * ship_size * 0.2 + bank_offset,
					pos + dir * ship_size * 0.2 - perp * ship_size * 0.25 + bank_offset
				])
				draw_colored_polygon(tower_points, ship.color.lightened(0.2))

			_:
				# Default triangle
				var points = PackedVector2Array([
					pos + dir * ship_size + bank_offset,
					pos - dir * ship_size * 0.6 + perp * ship_size * 0.5,
					pos - dir * ship_size * 0.6 - perp * ship_size * 0.5
				])
				draw_colored_polygon(points, ship.color)

		# --- ENGINE GLOW ---
		var engine_pos = pos - dir * ship_size * 0.7
		var glow_size = 3 + ship.engine_intensity * 2
		var glow_alpha = 0.4 + ship.engine_intensity * 0.4

		# Engine core (bright)
		draw_circle(engine_pos, glow_size * 0.5, Color(1, 1, 1, glow_alpha))
		# Inner glow
		draw_circle(engine_pos, glow_size, Color(ship.engine_color.r, ship.engine_color.g, ship.engine_color.b, glow_alpha * 0.7))
		# Outer glow
		draw_circle(engine_pos, glow_size * 2, Color(ship.engine_color.r, ship.engine_color.g, ship.engine_color.b, glow_alpha * 0.3))

		# Second engine for larger ships
		if ship.ship_class in [Ship.ShipClass.CRUISER, Ship.ShipClass.CARRIER, Ship.ShipClass.DREADNOUGHT]:
			var engine2_offset = perp * ship_size * 0.4
			draw_circle(engine_pos + engine2_offset, glow_size * 0.7, Color(ship.engine_color.r, ship.engine_color.g, ship.engine_color.b, glow_alpha * 0.6))
			draw_circle(engine_pos - engine2_offset, glow_size * 0.7, Color(ship.engine_color.r, ship.engine_color.g, ship.engine_color.b, glow_alpha * 0.6))

func _draw_player_fleets(rect: Rect2, offset: Vector2) -> void:
	# Draw fleet formations at each zone with assigned ships
	for zone_id in _fleet_assignments:
		var assignment = _fleet_assignments[zone_id]
		var total_ships = 0
		for ship_type in assignment:
			total_ships += assignment[ship_type]

		if total_ships <= 0:
			continue

		var pos = _get_zone_pixel_pos(zone_id) + offset
		var zone_size = ZONE_SIZES.get(zone_id, 20.0)

		# Draw multiple small ship icons in formation
		var fleet_center = pos + Vector2(zone_size + 20, 0)
		var ships_to_draw = mini(total_ships, 12)  # Cap visual ships

		for i in range(ships_to_draw):
			var angle = (float(i) / ships_to_draw) * TAU + _global_time * 0.5
			var orbit_radius = 8 + (i % 3) * 4
			var ship_pos = fleet_center + Vector2(cos(angle), sin(angle)) * orbit_radius

			# Tiny ship triangle
			var ship_dir = Vector2(cos(angle + PI/2), sin(angle + PI/2))
			var ship_perp = Vector2(-ship_dir.y, ship_dir.x)
			var points = PackedVector2Array([
				ship_pos + ship_dir * 3,
				ship_pos - ship_dir * 2 + ship_perp * 2,
				ship_pos - ship_dir * 2 - ship_perp * 2
			])
			draw_colored_polygon(points, Color(0.4, 0.9, 0.4))

		# Draw ship count
		var font = ThemeDB.fallback_font
		draw_string(font, fleet_center + Vector2(15, 4), "x%d" % total_ships, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 1.0, 0.5))

func _draw_lasers(offset: Vector2) -> void:
	for laser in _lasers:
		var alpha = laser.life / 0.3
		var glow_color = Color(laser.color.r, laser.color.g, laser.color.b, alpha * 0.3)
		var core_color = Color(laser.color.r, laser.color.g, laser.color.b, alpha)

		# Glow
		draw_line(laser.start + offset, laser.end + offset, glow_color, laser.width * 3)
		# Core
		draw_line(laser.start + offset, laser.end + offset, core_color, laser.width)
		# Bright center
		draw_line(laser.start + offset, laser.end + offset, Color(1, 1, 1, alpha * 0.8), laser.width * 0.5)

func _draw_explosions(offset: Vector2) -> void:
	for exp in _explosions:
		var progress = 1.0 - exp.life
		var current_radius = exp.max_radius * progress

		# Outer ring
		var ring_alpha = exp.life * 0.8
		draw_arc(exp.pos + offset, current_radius, 0, TAU, 24, Color(exp.color.r, exp.color.g * 0.5, 0, ring_alpha), 3.0)

		# Inner flash
		var flash_radius = current_radius * 0.6
		var flash_alpha = exp.life
		draw_circle(exp.pos + offset, flash_radius, Color(1, 1, 0.8, flash_alpha * 0.5))

		# Core
		var core_radius = current_radius * 0.3 * exp.life
		draw_circle(exp.pos + offset, core_radius, Color(1, 1, 1, exp.life))

func _draw_herald(rect: Rect2, offset: Vector2) -> void:
	# Herald only visible after detection (week 3+)
	if not _herald_visible:
		return

	var pos = _herald_position + offset

	# === HERALD MOTHERSHIP FLEET ===
	# Large imposing capital ship with escort vessels

	# Ominous dark PURPLE void aura (massive)
	var aura_pulse = sin(_global_time * 1.2) * 0.15 + 0.85
	for i in range(6):
		var aura_size = 55 - i * 8
		var aura_alpha = 0.06 * aura_pulse * (6 - i) / 6.0
		draw_circle(pos, aura_size, Color(0.35, 0.0, 0.3, aura_alpha))

	# Void distortion rings (rotating)
	var ring_rot = _global_time * 0.4
	for ring in range(3):
		var ring_size = 35 - ring * 8
		var ring_alpha = 0.15 - ring * 0.04
		draw_arc(pos, ring_size, ring_rot + ring * 0.5, ring_rot + ring * 0.5 + PI * 1.5, 20,
			Color(0.7, 0.1, 0.5, ring_alpha * aura_pulse), 2)

	# === ESCORT SHIPS (smaller vessels orbiting the mothership) ===
	var escort_count = 4
	for e in range(escort_count):
		var escort_angle = _global_time * 0.8 + e * TAU / escort_count
		var escort_dist = 28 + sin(_global_time * 2 + e) * 4
		var escort_pos = pos + Vector2(cos(escort_angle), sin(escort_angle)) * escort_dist
		var escort_dir = Vector2(cos(escort_angle + PI/2), sin(escort_angle + PI/2))
		var escort_perp = Vector2(-escort_dir.y, escort_dir.x)

		# Escort ship shape (small triangular)
		var escort_points = PackedVector2Array([
			escort_pos + escort_dir * 5,
			escort_pos - escort_dir * 3 + escort_perp * 3,
			escort_pos - escort_dir * 3 - escort_perp * 3,
		])
		draw_colored_polygon(escort_points, Color(0.45, 0.08, 0.35))
		# Escort engine glow
		draw_circle(escort_pos - escort_dir * 3, 2, Color(0.9, 0.2, 0.7, 0.8))

	# === MOTHERSHIP (large central vessel) ===
	var mothership_size = 18.0
	var rot = _global_time * 0.15  # Slow rotation

	# Mothership hull - elongated hexagonal shape
	var hull_points = PackedVector2Array()
	var hull_radii = [1.4, 0.9, 1.0, 1.4, 0.9, 1.0]  # Varied radii for asymmetric look
	for i in range(6):
		var angle = rot + i * TAU / 6
		var radius = mothership_size * hull_radii[i]
		hull_points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(hull_points, Color(0.5, 0.06, 0.4))

	# Hull detail lines
	for i in range(6):
		var angle1 = rot + i * TAU / 6
		var angle2 = rot + (i + 1) * TAU / 6
		var p1 = pos + Vector2(cos(angle1), sin(angle1)) * mothership_size * 0.5
		var p2 = pos + Vector2(cos(angle2), sin(angle2)) * mothership_size * 0.5
		draw_line(p1, p2, Color(0.7, 0.15, 0.55, 0.6), 1)

	# Bridge/command section (raised center)
	var bridge_points = PackedVector2Array()
	for i in range(6):
		var angle = rot + TAU / 12 + i * TAU / 6
		bridge_points.append(pos + Vector2(cos(angle), sin(angle)) * mothership_size * 0.45)
	draw_colored_polygon(bridge_points, Color(0.35, 0.02, 0.28))

	# Central void core (pulsing bright)
	var core_pulse = sin(_global_time * 3) * 0.3 + 0.7
	draw_circle(pos, 6 * core_pulse, Color(0.8, 0.15, 0.6, 0.5))
	draw_circle(pos, 4 * core_pulse, Color(0.95, 0.3, 0.8, 0.8))
	draw_circle(pos, 2, Color(1.0, 0.7, 0.95))

	# Engine glows (rear of mothership)
	var engine_dir = Vector2(cos(rot + PI), sin(rot + PI))
	for eng in range(3):
		var eng_offset = Vector2(-engine_dir.y, engine_dir.x) * (eng - 1) * 6
		var eng_pos = pos + engine_dir * mothership_size * 0.8 + eng_offset
		draw_circle(eng_pos, 3, Color(0.9, 0.15, 0.65, 0.9))
		draw_circle(eng_pos, 5, Color(0.7, 0.1, 0.5, 0.4))

	# Draw herald strength label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-30, -45), "HERALD FLEET", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color(0.8, 0.35, 0.65, 0.9))
	draw_string(font, pos + Vector2(-20, -32), "STR: %d" % _herald_strength, HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color(1.0, 0.4, 0.85))

func _draw_attack_indicator(_rect: Rect2, offset: Vector2) -> void:
	var target_pos = _get_zone_pixel_pos(_herald_target_zone) + offset
	var herald_pos = _herald_position + offset

	# Multiple PURPLE attack beams
	var rng = RandomNumberGenerator.new()
	for beam in range(5):
		rng.seed = int(_attack_flash_timer * 20 + beam * 100) % 10000
		var beam_offset = Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var flash = sin(_attack_flash_timer * 10.0 + beam) * 0.5 + 0.5

		# PURPLE/magenta attack beam (alien void)
		draw_line(herald_pos + beam_offset, target_pos + beam_offset * 0.3, Color(0.9, 0.1, 0.7, flash * 0.8), 2.0)
		# Bright magenta core
		draw_line(herald_pos + beam_offset, target_pos + beam_offset * 0.3, Color(1.0, 0.6, 0.95, flash * 0.5), 1.0)

	# Impact flashes at target
	for i in range(3):
		rng.seed = int(_attack_flash_timer * 15 + i * 50) % 10000
		var impact_offset = Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		var impact_flash = sin(_attack_flash_timer * 12.0 + i * 2) * 0.5 + 0.5
		draw_circle(target_pos + impact_offset, 5 * impact_flash, Color(1.0, 0.5, 0.0, impact_flash * 0.7))

func _draw_danger_vignette(rect: Rect2) -> void:
	# Red vignette around edges during danger
	var center = rect.size / 2
	var max_dist = center.length()

	# Draw gradient rectangles on edges
	var edge_color = Color(0.8, 0.0, 0.0, _danger_pulse * 0.4)
	var edge_size = 60 * _danger_pulse

	# Top
	draw_rect(Rect2(0, 0, rect.size.x, edge_size), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.5))
	# Bottom
	draw_rect(Rect2(0, rect.size.y - edge_size, rect.size.x, edge_size), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.5))
	# Left
	draw_rect(Rect2(0, 0, edge_size, rect.size.y), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.3))
	# Right
	draw_rect(Rect2(rect.size.x - edge_size, 0, edge_size, rect.size.y), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.3))

# ============================================================================
# ZOOM VIEWS - Galaxy, System, Planet
# ============================================================================

func _draw_galaxy_view(rect: Rect2) -> void:
	## Galaxy view - Sol as a tiny point among billions
	## Emotional purpose: Scale, loneliness - "Humanity's last light"

	# Pure black space
	draw_rect(rect, Color(0.005, 0.005, 0.01))

	# Generate galaxy stars (spiral arms pattern)
	var rng = RandomNumberGenerator.new()
	var center = rect.size / 2

	# Distant galaxy background - thousands of dim stars
	rng.seed = 99999
	for i in range(800):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(30, maxf(rect.size.x, rect.size.y) * 0.8)
		# Spiral arm distribution
		var arm_offset = fmod(angle * 2 + dist * 0.005, TAU)
		var arm_strength = sin(arm_offset) * 0.4 + 0.6
		var pos = center + Vector2(cos(angle), sin(angle)) * dist * arm_strength

		var brightness = rng.randf_range(0.05, 0.3)
		var twinkle = sin(_global_time * rng.randf_range(0.5, 2.0) + i * 0.1) * 0.15 + 0.85
		brightness *= twinkle

		# Various star colors
		var star_hue = rng.randf()
		var star_color: Color
		if star_hue < 0.5:
			star_color = Color(brightness, brightness, brightness * 1.1)  # Blue-white
		elif star_hue < 0.7:
			star_color = Color(brightness * 1.1, brightness * 0.9, brightness * 0.7)  # Yellow
		elif star_hue < 0.85:
			star_color = Color(brightness * 1.2, brightness * 0.7, brightness * 0.5)  # Orange
		else:
			star_color = Color(brightness * 1.3, brightness * 0.5, brightness * 0.4)  # Red giant

		draw_circle(pos, rng.randf_range(0.3, 1.2), star_color)

	# Draw galaxy dust lanes (darker areas)
	rng.seed = 88888
	for i in range(15):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(100, 300)
		var dust_pos = center + Vector2(cos(angle), sin(angle)) * dist
		var dust_size = rng.randf_range(40, 100)
		draw_circle(dust_pos, dust_size, Color(0.0, 0.0, 0.02, 0.15))

	# Draw nebula clouds in galaxy
	rng.seed = 77777
	for i in range(6):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(150, 350)
		var nebula_pos = center + Vector2(cos(angle), sin(angle)) * dist
		var nebula_color = Color(
			rng.randf_range(0.1, 0.4),
			rng.randf_range(0.0, 0.2),
			rng.randf_range(0.2, 0.5),
			0.02
		)
		for j in range(4):
			var jitter = Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
			draw_circle(nebula_pos + jitter, rng.randf_range(30, 70), nebula_color)

	# *** SOL - Humanity's Last Light ***
	# Sol is a tiny but distinct point
	var sol_pos = center + Vector2(rect.size.x * 0.15, rect.size.y * 0.1)  # Off-center (not special in the galaxy)

	# Pulsing marker - the hope of humanity
	var pulse = sin(_galaxy_sol_pulse * 2.0) * 0.3 + 0.7
	var danger_color = Color(1.0, 0.3, 0.2) if _narrative_state >= 2 else Color(0.3, 0.8, 1.0)

	# Soft outer glow (larger when in danger)
	var glow_size = 20 * pulse if _narrative_state >= 2 else 12 * pulse
	draw_circle(sol_pos, glow_size, Color(danger_color.r, danger_color.g, danger_color.b, 0.1))
	draw_circle(sol_pos, glow_size * 0.6, Color(danger_color.r, danger_color.g, danger_color.b, 0.2))

	# Sol itself - bright yellow-white point
	draw_circle(sol_pos, 4, Color(1.0, 0.95, 0.7))
	draw_circle(sol_pos, 2, Color(1.0, 1.0, 1.0))

	# Crosshair marker
	var cross_len = 15 * pulse
	var cross_color = Color(danger_color.r, danger_color.g, danger_color.b, 0.7 * pulse)
	draw_line(sol_pos - Vector2(cross_len + 8, 0), sol_pos - Vector2(8, 0), cross_color, 1.0)
	draw_line(sol_pos + Vector2(8, 0), sol_pos + Vector2(cross_len + 8, 0), cross_color, 1.0)
	draw_line(sol_pos - Vector2(0, cross_len + 8), sol_pos - Vector2(0, 8), cross_color, 1.0)
	draw_line(sol_pos + Vector2(0, 8), sol_pos + Vector2(0, cross_len + 8), cross_color, 1.0)

	# "SOL" label
	var font = ThemeDB.fallback_font
	var label_text = "SOL"
	draw_string(font, sol_pos + Vector2(-10, -25), label_text, HORIZONTAL_ALIGNMENT_CENTER, 20, 10, cross_color)

	# Status text based on narrative state
	var status_text: String
	var status_color: Color
	match _narrative_state:
		0:
			status_text = "ALL QUIET"
			status_color = Color(0.3, 0.8, 0.3, 0.7 * pulse)
		1:
			status_text = "CONTACT DETECTED"
			status_color = Color(1.0, 0.9, 0.3, 0.8 * pulse)
		2:
			status_text = "UNDER ATTACK"
			status_color = Color(1.0, 0.4, 0.2, 0.9 * pulse)
		3:
			status_text = "CRITICAL - FINAL STAND"
			status_color = Color(1.0, 0.2, 0.2, pulse)

	draw_string(font, sol_pos + Vector2(-50, 30), status_text, HORIZONTAL_ALIGNMENT_CENTER, 100, 9, status_color)

	# Draw herald origin (menacing PURPLE presence at edge)
	if _narrative_state > 0:
		var herald_galaxy_pos = Vector2(rect.size.x * 0.05, rect.size.y * 0.5)
		var herald_pulse = sin(_global_time * 1.5) * 0.3 + 0.7

		# Dark PURPLE void presence
		for i in range(5):
			draw_circle(herald_galaxy_pos, 30 - i * 5, Color(0.35, 0.0, 0.3, 0.05 * herald_pulse))
		draw_circle(herald_galaxy_pos, 8, Color(0.6, 0.1, 0.5, 0.6 * herald_pulse))
		draw_circle(herald_galaxy_pos, 3, Color(0.9, 0.3, 0.8))

		# Threat indicator line pointing toward Sol (purple)
		if _narrative_state >= 2:
			var threat_dir = (sol_pos - herald_galaxy_pos).normalized()
			var dash_count = 8
			for i in range(dash_count):
				var progress = float(i) / dash_count
				var dash_start = herald_galaxy_pos + threat_dir * (40 + progress * 60)
				var dash_end = dash_start + threat_dir * 6
				var dash_alpha = (1.0 - progress) * 0.5 * herald_pulse
				draw_line(dash_start, dash_end, Color(0.8, 0.15, 0.6, dash_alpha), 2.0)

		draw_string(font, herald_galaxy_pos + Vector2(-20, -20), "HERALD", HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.7, 0.2, 0.6, 0.8 * herald_pulse))

	# Caption at bottom
	var caption = "AMONG THE STARS, ONE LIGHT FLICKERS"
	var caption_color = Color(0.5, 0.5, 0.6, 0.6)
	draw_string(font, Vector2(rect.size.x / 2 - 100, rect.size.y - 30), caption, HORIZONTAL_ALIGNMENT_CENTER, 200, 11, caption_color)

func _draw_planet_view(rect: Rect2) -> void:
	## Planet view - Single zone enlarged with staging areas
	## Emotional purpose: Intense focus during attacks

	if _zoom_focus_zone < 0:
		# No zone focused, fall back to system view
		_draw_system_view(rect)
		return

	var offset = _screen_shake
	var center = rect.size / 2
	var zone_id = _zoom_focus_zone

	# Dark space background
	draw_rect(rect, Color(0.01, 0.01, 0.02))

	# Localized starfield
	var rng = RandomNumberGenerator.new()
	rng.seed = zone_id * 1000 + 12345
	for i in range(150):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var brightness = rng.randf_range(0.15, 0.6)
		var twinkle = sin(_global_time * rng.randf_range(1.0, 3.0) + i) * 0.2 + 0.8
		draw_circle(pos, rng.randf_range(0.5, 1.5), Color(brightness * twinkle, brightness * twinkle, brightness * twinkle * 1.1))

	# Zone data
	var zone_data = _zones.get(zone_id, {})
	var status = zone_data.get("status", FCWTypes.ZoneStatus.CONTROLLED)
	var zone_color = ZONE_COLORS.get(zone_id, Color.WHITE)
	var zone_name = FCWTypes.get_zone_name(zone_id)

	# Modify color based on status
	if status == FCWTypes.ZoneStatus.FALLEN:
		zone_color = zone_color.darkened(0.7)
	elif status == FCWTypes.ZoneStatus.UNDER_ATTACK:
		var pulse = sin(_attack_flash_timer * 4.0) * 0.4 + 0.6
		zone_color = zone_color.lerp(Color.RED, 0.5 * pulse)

	# Large planet in center
	var planet_size = minf(rect.size.x, rect.size.y) * 0.25
	var planet_pos = center + offset

	# Atmospheric glow
	if status != FCWTypes.ZoneStatus.FALLEN:
		draw_circle(planet_pos, planet_size + 20, Color(zone_color.r, zone_color.g, zone_color.b, 0.1))
		draw_circle(planet_pos, planet_size + 10, Color(zone_color.r, zone_color.g, zone_color.b, 0.15))

	# The planet
	draw_circle(planet_pos, planet_size, zone_color)

	# Planet surface details
	rng.seed = zone_id * 100
	for i in range(8):
		var detail_angle = rng.randf() * TAU
		var detail_dist = rng.randf_range(planet_size * 0.2, planet_size * 0.7)
		var detail_pos = planet_pos + Vector2(cos(detail_angle), sin(detail_angle)) * detail_dist
		var detail_size = rng.randf_range(planet_size * 0.05, planet_size * 0.15)
		var detail_color = zone_color.darkened(rng.randf_range(0.1, 0.3))
		draw_circle(detail_pos, detail_size, detail_color)

	# Planet shine
	if status != FCWTypes.ZoneStatus.FALLEN:
		var shine_pos = planet_pos + Vector2(-planet_size * 0.35, -planet_size * 0.35)
		draw_circle(shine_pos, planet_size * 0.2, Color(1, 1, 1, 0.25))

	# Zone rings if Saturn
	if zone_id == FCWTypes.ZoneId.SATURN:
		_draw_planet_view_rings(planet_pos, planet_size)

	# Draw staging areas around the planet (enlarged)
	var staging_list = STAGING_AREAS.get(zone_id, [])
	for staging in staging_list:
		var staging_pos = planet_pos + staging.offset * 2.5  # Enlarge offsets
		var staging_size = staging.size * 2.0  # Bigger staging areas

		match staging.type:
			StagingType.MOON:
				_draw_planet_view_moon(staging_pos, staging_size, staging.name)
			StagingType.ASTEROID_CLUSTER:
				_draw_planet_view_asteroid_cluster(staging_pos, staging_size, staging.name)
			StagingType.STATION:
				_draw_planet_view_station(staging_pos, staging_size, staging.name)

	# Draw active skirmishes in this zone
	for skirmish in _skirmishes:
		if skirmish.zone_id == zone_id:
			var skirmish_pos = planet_pos + (skirmish.pos - _get_zone_pixel_pos(zone_id)) * 2.5
			_draw_planet_view_skirmish(skirmish, skirmish_pos)

	# Draw herald attack ships if targeting this zone
	if _herald_target_zone == zone_id:
		for ship in _herald_ships:
			var ship_world_pos = ship.pos
			var zone_world_pos = _get_zone_pixel_pos(zone_id)
			var relative_pos = ship_world_pos - zone_world_pos
			var planet_view_pos = planet_pos + relative_pos * 2.0
			_draw_planet_view_herald_ship(ship, planet_view_pos)

	# Defense status UI
	var font = ThemeDB.fallback_font
	var defense = zone_data.get("defense", 0)

	# Zone name (large)
	draw_string(font, Vector2(rect.size.x / 2 - 60, 40), zone_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color.WHITE)

	# Status
	var status_text: String
	var status_color: Color
	match status:
		FCWTypes.ZoneStatus.CONTROLLED:
			status_text = "CONTROLLED"
			status_color = Color(0.3, 0.9, 0.3)
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			status_text = "UNDER ATTACK"
			status_color = Color(1.0, 0.3, 0.2)
		FCWTypes.ZoneStatus.FALLEN:
			status_text = "FALLEN"
			status_color = Color(0.5, 0.3, 0.3)
	draw_string(font, Vector2(rect.size.x / 2 - 40, 60), status_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 12, status_color)

	# Defense value
	var def_text = "DEFENSE: %d" % defense
	var def_color: Color
	if defense >= _herald_strength * 1.3:
		def_color = Color(0.3, 1.0, 0.3)
	elif defense >= _herald_strength:
		def_color = Color(1.0, 1.0, 0.3)
	else:
		def_color = Color(1.0, 0.3, 0.3)
	draw_string(font, Vector2(20, rect.size.y - 60), def_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, def_color)

	# Herald strength if attacking
	if _herald_target_zone == zone_id:
		var threat_text = "HERALD STRENGTH: %d" % _herald_strength
		draw_string(font, Vector2(20, rect.size.y - 40), threat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.3, 0.2))

	# Danger vignette if under attack
	if status == FCWTypes.ZoneStatus.UNDER_ATTACK or _danger_pulse > 0.01:
		_draw_danger_vignette(rect)

func _draw_planet_view_rings(center: Vector2, planet_size: float) -> void:
	var ring_colors = [
		Color(0.8, 0.75, 0.6, 0.3),
		Color(0.85, 0.8, 0.65, 0.25),
		Color(0.75, 0.7, 0.55, 0.2),
	]
	for i in range(3):
		var ring_radius = planet_size * 1.5 - i * 15
		if ring_radius > 0:
			var points = PackedVector2Array()
			var point_count = 48
			for j in range(point_count + 1):
				var angle = j * TAU / point_count
				var point = center + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.3)
				points.append(point)
			for j in range(point_count / 2):
				var idx = j + point_count / 4
				if idx < points.size() - 1:
					draw_line(points[idx], points[idx + 1], ring_colors[i], 4.0)

func _draw_planet_view_moon(pos: Vector2, size: float, moon_name: String) -> void:
	var base_color = Color(0.55, 0.55, 0.6)

	# Glow
	draw_circle(pos, size + 4, Color(0.4, 0.4, 0.5, 0.2))
	draw_circle(pos, size, base_color)

	# Craters
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(moon_name)
	for i in range(5):
		var crater_offset = Vector2(rng.randf_range(-size * 0.6, size * 0.6),
									 rng.randf_range(-size * 0.6, size * 0.6))
		var crater_size = size * rng.randf_range(0.1, 0.25)
		draw_circle(pos + crater_offset, crater_size, base_color.darkened(0.2))

	# Highlight
	draw_circle(pos + Vector2(-size * 0.3, -size * 0.3), size * 0.25, Color(0.75, 0.75, 0.8, 0.5))

	# Label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-30, size + 15), moon_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.7, 0.7, 0.8))

func _draw_planet_view_asteroid_cluster(pos: Vector2, size: float, cluster_name: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(cluster_name)

	var asteroid_count = int(size / 1.5) + 5
	for i in range(asteroid_count):
		var asteroid_offset = Vector2(rng.randf_range(-size * 1.2, size * 1.2),
									   rng.randf_range(-size * 1.2, size * 1.2))
		var asteroid_size = rng.randf_range(2, 6)
		var color = Color(rng.randf_range(0.35, 0.55),
						  rng.randf_range(0.3, 0.5),
						  rng.randf_range(0.25, 0.45))
		draw_circle(pos + asteroid_offset, asteroid_size, color)

	# Dashed boundary
	var segment_count = 24
	for i in range(segment_count):
		if i % 2 == 0:
			var angle_start = i * TAU / segment_count + _global_time * 0.05
			var angle_end = angle_start + TAU / segment_count * 0.6
			draw_arc(pos, size * 1.5, angle_start, angle_end, 6, Color(0.4, 0.4, 0.35, 0.3), 1.5)

	# Label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-40, size * 1.5 + 15), cluster_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(0.6, 0.6, 0.5))

func _draw_planet_view_station(pos: Vector2, size: float, station_name: String) -> void:
	var rotation = _global_time * 0.3

	# Central hub (larger)
	draw_circle(pos, size * 0.8, Color(0.55, 0.6, 0.65))
	draw_circle(pos, size * 0.5, Color(0.65, 0.7, 0.75))

	# Rotating arms
	for i in range(4):
		var arm_angle = rotation + i * TAU / 4
		var arm_end = pos + Vector2(cos(arm_angle), sin(arm_angle)) * size * 1.5
		draw_line(pos, arm_end, Color(0.55, 0.6, 0.65), 3.0)
		draw_circle(arm_end, size * 0.35, Color(0.6, 0.65, 0.7))

	# Blinking lights
	var blink = sin(_global_time * 3.0) * 0.5 + 0.5
	draw_circle(pos, 4, Color(0.2, 1.0, 0.3, blink))

	# Label
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-35, size * 1.5 + 12), station_name, HORIZONTAL_ALIGNMENT_CENTER, 70, 10, Color(0.6, 0.8, 0.7))

func _draw_planet_view_skirmish(skirmish: Skirmish, pos: Vector2) -> void:
	var alpha = skirmish.intensity
	var pulse = sin(_global_time * 4.0) * 0.3 + 0.7
	var radius = skirmish.radius * 1.5 * pulse

	# Combat zone rings
	if skirmish.is_herald_attack:
		draw_arc(pos, radius, 0, TAU, 32, Color(1.0, 0.2, 0.1, alpha * 0.7), 3.0)
		draw_arc(pos, radius * 0.7, 0, TAU, 28, Color(1.0, 0.4, 0.2, alpha * 0.4), 2.0)
	else:
		draw_arc(pos, radius, 0, TAU, 32, Color(0.3, 0.6, 1.0, alpha * 0.6), 2.5)

	# Battle sparks
	var rng = RandomNumberGenerator.new()
	rng.seed = int(_global_time * 10) % 1000
	for i in range(12):
		var spark_pos = pos + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		var spark_alpha = rng.randf_range(0.4, 0.9) * alpha
		draw_circle(spark_pos, rng.randf_range(2, 5), Color(1.0, 0.8, 0.3, spark_alpha))

	# Label
	if skirmish.staging_name != "":
		var font = ThemeDB.fallback_font
		var label = "BATTLE: %s" % skirmish.staging_name
		var label_color = Color(1.0, 0.4, 0.3, alpha) if skirmish.is_herald_attack else Color(0.5, 0.8, 1.0, alpha)
		draw_string(font, pos + Vector2(-50, -radius - 10), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 11, label_color)

func _draw_planet_view_herald_ship(ship: Ship, pos: Vector2) -> void:
	# Simplified herald ship for planet view - PURPLE alien colors
	var tangent = ship.get_bezier_tangent(ship.progress)
	var dir = tangent.normalized() if tangent.length() > 0.1 else Vector2(1, 0)
	var perp = Vector2(-dir.y, dir.x)
	var ship_size = ship.size * 1.5

	# PURPLE engine trail
	var trail_end = pos - dir * ship_size * 2
	draw_line(pos, trail_end, Color(0.9, 0.2, 0.7, 0.6), 3.0)
	draw_line(pos, trail_end, Color(0.7, 0.3, 0.6, 0.3), 6.0)

	# Hull (dark purple)
	var points = PackedVector2Array([
		pos + dir * ship_size * 1.5,
		pos + perp * ship_size * 0.6,
		pos - dir * ship_size,
		pos - perp * ship_size * 0.6,
	])
	draw_colored_polygon(points, Color(0.5, 0.1, 0.4))

	# Core glow (magenta)
	draw_circle(pos, ship_size * 0.3, Color(0.9, 0.3, 0.8, 0.8))

func _draw_zoom_transition(rect: Rect2) -> void:
	## Draw transition overlay between zoom levels
	var alpha = sin(_zoom_transition * PI) * 0.3  # Fade in/out during middle of transition

	# Flash overlay
	draw_rect(rect, Color(1.0, 1.0, 1.0, alpha))

func _update_zoom(delta: float) -> void:
	## Update zoom transition animation
	if _zoom_level != _zoom_target:
		_zoom_transition += delta * 2.0  # 0.5 second transition
		if _zoom_transition >= 1.0:
			_zoom_transition = 1.0
			_zoom_level = _zoom_target

	# Update galaxy Sol pulse
	_galaxy_sol_pulse += delta

# ============================================================================
# POSITIONING
# ============================================================================

func _get_zone_pixel_pos(zone_id: int) -> Vector2:
	var normalized_pos = ZONE_POSITIONS.get(zone_id, Vector2(0.5, 0.5))
	return normalized_pos * size

func get_zone_screen_position(zone_id: int) -> Vector2:
	## Returns the global screen position of a zone (for positioning UI elements near it)
	var local_pos = _get_zone_pixel_pos(zone_id)
	return global_position + local_pos

func get_zone_size(zone_id: int) -> float:
	## Returns the display size of a zone
	return ZONE_SIZES.get(zone_id, 25.0)

# ============================================================================
# EFFECTS - UPDATE FUNCTIONS
# ============================================================================

func _update_particles(delta: float) -> void:
	var i = 0
	while i < _particles.size():
		var p = _particles[i]
		p.pos += p.vel * delta
		p.life -= delta
		if p.life <= 0:
			_particles.remove_at(i)
		else:
			i += 1

func _update_ships(delta: float) -> void:
	var i = 0
	while i < _ships.size():
		var ship = _ships[i]

		# Handle delayed start (negative progress)
		if ship.progress < 0:
			ship.progress += delta * 2.0  # Tick up waiting ships
			i += 1
			continue

		# Speed varies by ship class
		var base_speed = 0.4
		match ship.ship_class:
			Ship.ShipClass.FRIGATE:
				base_speed = 0.6  # Fast
			Ship.ShipClass.CRUISER:
				base_speed = 0.45
			Ship.ShipClass.CARRIER:
				base_speed = 0.3  # Slow
			Ship.ShipClass.DREADNOUGHT:
				base_speed = 0.35

		# Acceleration curve: fast start, cruise, slow arrival
		var accel_curve = 1.0
		if ship.progress < 0.15:
			# Accelerating (afterburner)
			accel_curve = 0.5 + ship.progress * 3.3  # 0.5 -> 1.0
			ship.afterburner = true
			ship.engine_intensity = 1.5
		elif ship.progress > 0.85:
			# Decelerating
			accel_curve = 1.0 - (ship.progress - 0.85) * 4  # 1.0 -> 0.4
			ship.afterburner = false
			ship.engine_intensity = 0.6
		else:
			# Cruising
			ship.afterburner = false
			ship.engine_intensity = 1.0 + sin(_global_time * 3 + float(i)) * 0.2

		ship.progress += delta * base_speed * ship.speed * accel_curve

		# Update afterburner timer
		if ship.afterburner:
			ship.afterburner_timer += delta

		# Position along bezier curve
		var old_pos = ship.pos
		ship.pos = ship.get_bezier_pos(minf(ship.progress, 1.0)) + ship.formation_offset

		# Calculate banking based on curve direction change
		var tangent = ship.get_bezier_tangent(ship.progress)
		var target_rotation = tangent.angle()
		var rotation_delta = angle_difference(ship.rotation, target_rotation)
		ship.bank_angle = clampf(rotation_delta * 3, -0.5, 0.5)  # Bank into turns
		ship.rotation = target_rotation

		# Add to trail (longer trails)
		ship.trail.append(ship.pos)
		var max_trail = 25 if ship.ship_class == Ship.ShipClass.FRIGATE else 20
		if ship.afterburner:
			max_trail += 10
		while ship.trail.size() > max_trail:
			ship.trail.pop_front()

		# Spawn engine particles
		if randf() < delta * 10 * ship.engine_intensity:
			_spawn_engine_particle(ship, tangent.normalized())

		if ship.progress >= 1.0:
			# Ship arrived - spawn dramatic warp-in flash
			_spawn_arrival_effect(ship.target + ship.formation_offset)
			_ships.remove_at(i)
		else:
			i += 1

func _spawn_engine_particle(ship: Ship, dir: Vector2) -> void:
	var p = Particle.new()
	p.pos = ship.pos - dir * ship.size * 0.7
	p.pos += Vector2(randf_range(-3, 3), randf_range(-3, 3))
	p.vel = -dir * randf_range(20, 50) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	p.color = Color(ship.engine_color.r, ship.engine_color.g, ship.engine_color.b, 0.8)
	p.life = randf_range(0.2, 0.4)
	p.max_life = p.life
	p.size = randf_range(1, 3)
	_particles.append(p)

func _spawn_arrival_effect(pos: Vector2) -> void:
	# Warp flash
	_warp_flashes.append({"pos": pos, "life": 1.0})

	# Arrival particles burst
	for j in range(15):
		var p = Particle.new()
		p.pos = pos
		var angle = randf() * TAU
		var speed = randf_range(30, 80)
		p.vel = Vector2(cos(angle), sin(angle)) * speed
		p.color = Color(0.5, 0.8, 1.0, 1.0)
		p.life = randf_range(0.3, 0.6)
		p.max_life = p.life
		p.size = randf_range(2, 4)
		_particles.append(p)

func _update_lasers(delta: float) -> void:
	var i = 0
	while i < _lasers.size():
		_lasers[i].life -= delta
		if _lasers[i].life <= 0:
			_lasers.remove_at(i)
		else:
			i += 1

func _update_explosions(delta: float) -> void:
	var i = 0
	while i < _explosions.size():
		_explosions[i].life -= delta
		if _explosions[i].life <= 0:
			_explosions.remove_at(i)
		else:
			i += 1

func _update_warp_flashes(delta: float) -> void:
	var i = 0
	while i < _warp_flashes.size():
		_warp_flashes[i].life -= delta * 2.0
		if _warp_flashes[i].life <= 0:
			_warp_flashes.remove_at(i)
		else:
			i += 1

func _update_skirmishes(delta: float) -> void:
	var i = 0
	while i < _skirmishes.size():
		var skirmish = _skirmishes[i]

		# Spawn combat effects
		skirmish.laser_timer -= delta
		skirmish.explosion_timer -= delta

		if skirmish.laser_timer <= 0 and skirmish.intensity > 0.2:
			_spawn_skirmish_laser(skirmish)
			skirmish.laser_timer = randf_range(0.05, 0.15) / skirmish.intensity

		if skirmish.explosion_timer <= 0 and skirmish.intensity > 0.3:
			_spawn_skirmish_explosion(skirmish)
			skirmish.explosion_timer = randf_range(0.2, 0.5) / skirmish.intensity

		# Fade intensity over time
		skirmish.intensity -= delta * 0.1

		if skirmish.intensity <= 0:
			_skirmishes.remove_at(i)
		else:
			i += 1

func _update_attack_waves(delta: float) -> void:
	var i = 0
	while i < _attack_waves.size():
		var wave = _attack_waves[i]

		wave.spawn_timer -= delta

		# Spawn herald ships in waves
		if wave.spawn_timer <= 0 and wave.ships_spawned < wave.wave_size:
			_spawn_herald_attack_ship(wave)
			wave.ships_spawned += 1
			wave.spawn_timer = randf_range(0.1, 0.3)  # Staggered spawning

		# Remove wave when all ships spawned
		if wave.ships_spawned >= wave.wave_size:
			_attack_waves.remove_at(i)
		else:
			i += 1

func _update_herald_ships(delta: float) -> void:
	var i = 0
	while i < _herald_ships.size():
		var ship = _herald_ships[i]

		# Similar to regular ships but with different behavior
		if ship.progress < 0:
			ship.progress += delta * 2.0
			i += 1
			continue

		# Herald ships are fast and aggressive
		var speed = 0.5 * ship.speed
		ship.progress += delta * speed

		# Update position
		ship.pos = ship.get_bezier_pos(minf(ship.progress, 1.0)) + ship.formation_offset

		# Trail
		ship.trail.append(ship.pos)
		while ship.trail.size() > 15:
			ship.trail.pop_front()

		# Spawn ALIEN menacing particles - purple/magenta
		if randf() < delta * 8:
			var p = Particle.new()
			var tangent = ship.get_bezier_tangent(ship.progress).normalized()
			p.pos = ship.pos - tangent * ship.size
			p.vel = -tangent * randf_range(30, 60) + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			# Purple/magenta alien engine trail
			p.color = Color(0.9, randf_range(0.1, 0.3), randf_range(0.5, 0.8), 0.8)
			p.life = randf_range(0.3, 0.5)
			p.max_life = p.life
			p.size = randf_range(2, 5)
			_particles.append(p)

		if ship.progress >= 1.0:
			# Herald ship arrived - start skirmish at staging area
			if not ship.formation_offset.is_zero_approx():
				# This was part of a wave targeting a staging area
				_spawn_herald_arrival_effect(ship.target + ship.formation_offset)
			else:
				_spawn_herald_arrival_effect(ship.target)
			_herald_ships.remove_at(i)
		else:
			i += 1

func _spawn_herald_arrival_effect(pos: Vector2) -> void:
	# ALIEN purple/magenta warp flash (distinct from human blue)
	_warp_flashes.append({"pos": pos, "life": 1.2, "color": Color(0.8, 0.1, 0.6)})

	# Alien void burst - purple/magenta swirling particles
	for j in range(15):
		var p = Particle.new()
		p.pos = pos
		var angle = randf() * TAU
		var speed = randf_range(30, 70)
		p.vel = Vector2(cos(angle), sin(angle)) * speed
		# Purple/magenta alien colors - distinctly NOT red
		p.color = Color(0.8, randf_range(0.1, 0.3), randf_range(0.5, 0.9), 1.0)
		p.life = randf_range(0.4, 0.8)
		p.max_life = p.life
		p.size = randf_range(3, 6)
		_particles.append(p)

	# Inner void core (bright purple)
	for j in range(5):
		var p = Particle.new()
		p.pos = pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		p.vel = Vector2.ZERO
		p.color = Color(1.0, 0.5, 1.0, 1.0)  # Bright magenta
		p.life = 0.3
		p.max_life = p.life
		p.size = randf_range(4, 8)
		_particles.append(p)

	# Screen shake
	_screen_shake_intensity = maxf(_screen_shake_intensity, 6.0)

func _spawn_skirmish_laser(skirmish: Skirmish) -> void:
	var laser = Laser.new()

	# Random positions within skirmish zone
	var angle1 = randf() * TAU
	var angle2 = randf() * TAU
	var dist1 = randf_range(5, skirmish.radius * 0.8)
	var dist2 = randf_range(5, skirmish.radius * 0.8)

	laser.start = skirmish.pos + Vector2(cos(angle1), sin(angle1)) * dist1
	laser.end = skirmish.pos + Vector2(cos(angle2), sin(angle2)) * dist2

	# Color based on who's shooting
	if skirmish.is_herald_attack:
		# Mixed - Herald purple vs Earth blue
		if randf() > 0.5:
			laser.color = Color(0.9, 0.2, 0.8)  # Alien purple/magenta
		else:
			laser.color = Color(0.3, 0.7, 1.0)  # Earth blue (defenders)
	else:
		laser.color = Color(0.3, 0.7, 1.0)  # Earth blue

	laser.life = randf_range(0.1, 0.2)
	laser.width = randf_range(1.0, 2.5)
	_lasers.append(laser)

func _spawn_skirmish_explosion(skirmish: Skirmish) -> void:
	var exp = Explosion.new()

	var angle = randf() * TAU
	var dist = randf_range(0, skirmish.radius * 0.7)
	exp.pos = skirmish.pos + Vector2(cos(angle), sin(angle)) * dist

	exp.max_radius = randf_range(8, 20)
	exp.life = randf_range(0.3, 0.5)
	# Mixed colors for battle explosions - purple for alien, blue/orange for human
	if skirmish.is_herald_attack and randf() > 0.4:
		exp.color = Color(0.8, randf_range(0.2, 0.5), randf_range(0.6, 0.9))  # Purple/magenta
	else:
		exp.color = Color(0.3, randf_range(0.5, 0.8), 1.0)  # Blue human
	_explosions.append(exp)

	# Small debris
	for j in range(3):
		var p = Particle.new()
		p.pos = exp.pos
		p.vel = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		p.color = Color(1.0, 0.5, 0.2, 1.0)
		p.life = randf_range(0.2, 0.4)
		p.max_life = p.life
		p.size = randf_range(1, 2)
		_particles.append(p)

func _spawn_herald_attack_ship(wave: AttackWave) -> void:
	var ship = Ship.new()

	# Start from where the wave originated (NOT current herald position)
	# This prevents ships from spawning at wrong locations when herald has moved
	var from_pos = wave.spawn_position if wave.spawn_position != Vector2.ZERO else _herald_position
	var to_zone_pos = _get_zone_pixel_pos(wave.target_zone)

	# Target the staging area if specified
	var target_pos = to_zone_pos
	if not wave.target_staging.is_empty():
		target_pos = to_zone_pos + wave.target_staging.offset

	ship.start_pos = from_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	ship.target = target_pos
	ship.pos = ship.start_pos

	# Curved aggressive flight path
	var midpoint = (ship.start_pos + ship.target) / 2
	var direction = (ship.target - ship.start_pos).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)
	var curve_strength = ship.start_pos.distance_to(ship.target) * randf_range(0.15, 0.35)
	ship.control_point = midpoint + perpendicular * curve_strength * (1 if randf() > 0.5 else -1)

	# Herald ship properties
	ship.ship_class = Ship.ShipClass.FRIGATE  # Herald use frigate-like small attack craft
	ship.size = randf_range(6, 10)
	ship.speed = randf_range(1.2, 1.6)  # Fast and aggressive
	# ALIEN purple/magenta colors - distinctly different from Earth blue
	ship.color = Color(0.5, 0.1, 0.4)  # Dark purple hull
	ship.engine_color = Color(0.9, 0.2, 0.7)  # Bright magenta engine

	# Stagger spawning
	ship.progress = -wave.ships_spawned * 0.08
	ship.formation_offset = perpendicular * (wave.ships_spawned - wave.wave_size / 2.0) * 15

	ship.trail = []
	ship.rotation = direction.angle()
	_herald_ships.append(ship)

# ============================================================================
# EFFECTS - SPAWN FUNCTIONS
# ============================================================================

func _spawn_herald_trail(from_pos: Vector2) -> void:
	# Spawn menacing red particles behind herald
	for j in range(2):
		var p = Particle.new()
		p.pos = from_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		p.vel = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		p.color = Color(1.0, randf_range(0.0, 0.3), 0.0, 0.8)
		p.life = randf_range(0.3, 0.8)
		p.max_life = p.life
		p.size = randf_range(2, 5)
		_particles.append(p)

func _spawn_combat_laser() -> void:
	# Spawn laser between herald and target zone
	var target_pos = _get_zone_pixel_pos(_herald_target_zone)
	var zone_size = ZONE_SIZES.get(_herald_target_zone, 20.0)

	var laser = Laser.new()
	# From herald or from defenders
	if randf() > 0.4:
		# HERALD attacking - purple/magenta alien beams
		laser.start = _herald_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		laser.end = target_pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		laser.color = Color(0.9, 0.2, 0.75)  # Purple/magenta (alien)
	else:
		# Defenders shooting back - BLUE (human)
		laser.start = target_pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		laser.end = _herald_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		laser.color = Color(0.3, 0.8, 1.0)  # Blue (human)

	laser.life = 0.15 + randf() * 0.15
	laser.width = 1.0 + randf() * 2.0
	_lasers.append(laser)

func _spawn_combat_explosion() -> void:
	var target_pos = _get_zone_pixel_pos(_herald_target_zone)
	var zone_size = ZONE_SIZES.get(_herald_target_zone, 20.0)

	var exp = Explosion.new()
	# Explosions around the battle area
	exp.pos = target_pos + Vector2(randf_range(-zone_size - 20, zone_size + 20), randf_range(-zone_size - 20, zone_size + 20))
	exp.max_radius = randf_range(8, 25)
	exp.life = 0.4 + randf() * 0.3
	# Mixed combat colors - purple alien, blue human
	if randf() > 0.5:
		exp.color = Color(0.8, randf_range(0.2, 0.4), randf_range(0.6, 0.9))  # Purple/magenta alien
	else:
		exp.color = Color(0.3, randf_range(0.5, 0.8), 1.0)  # Blue human
	_explosions.append(exp)

	# Screen shake on bigger explosions
	if exp.max_radius > 18:
		_screen_shake_intensity = maxf(_screen_shake_intensity, exp.max_radius * 0.3)

	# Spawn debris particles (mixed colors)
	for j in range(5):
		var p = Particle.new()
		p.pos = exp.pos
		p.vel = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		if randf() > 0.5:
			p.color = Color(0.7, 0.4, 0.9, 1.0)  # Purple debris
		else:
			p.color = Color(0.4, 0.7, 1.0, 1.0)  # Blue debris
		p.life = randf_range(0.3, 0.6)
		p.max_life = p.life
		p.size = randf_range(1, 3)
		_particles.append(p)

func _spawn_ambient_particles(delta: float) -> void:
	# Engine glow particles near fleet formations
	if randf() < delta * 3.0:
		for zone_id in _fleet_assignments:
			var assignment = _fleet_assignments[zone_id]
			var total_ships = 0
			for ship_type in assignment:
				total_ships += assignment[ship_type]

			if total_ships > 0 and randf() < 0.3:
				var pos = _get_zone_pixel_pos(zone_id)
				var zone_size = ZONE_SIZES.get(zone_id, 20.0)
				var fleet_center = pos + Vector2(zone_size + 20, 0)

				var p = Particle.new()
				p.pos = fleet_center + Vector2(randf_range(-15, 15), randf_range(-15, 15))
				p.vel = Vector2(randf_range(-10, 10), randf_range(-10, 10))
				p.color = Color(0.3, 0.7, 1.0, 0.6)
				p.life = randf_range(0.3, 0.6)
				p.max_life = p.life
				p.size = randf_range(1, 2)
				_particles.append(p)

# ============================================================================
# CIVILIAN TRAFFIC SYSTEM
# ============================================================================

func _update_civilian_ships(delta: float) -> void:
	var i = 0
	while i < _civilian_ships.size():
		var ship = _civilian_ships[i]
		ship.progress += delta * ship.speed

		# Update position
		ship.pos = ship.get_bezier_pos(minf(ship.progress, 1.0))

		# Trail (shorter for civilians)
		ship.trail.append(ship.pos)
		while ship.trail.size() > 8:
			ship.trail.pop_front()

		if ship.progress >= 1.0:
			_civilian_ships.remove_at(i)
		else:
			i += 1

func _maybe_spawn_civilian_ship(delta: float) -> void:
	# Only spawn during peacetime (low narrative state)
	if _narrative_state >= 2:  # Combat or desperate
		return

	_civilian_spawn_timer -= delta

	# Spawn rate depends on how peaceful things are
	var spawn_interval = 3.0 if _narrative_state == 0 else 6.0

	if _civilian_spawn_timer <= 0:
		_civilian_spawn_timer = spawn_interval + randf_range(-1, 2)

		# Only spawn if we have controlled zones to travel between
		var controlled: Array = []
		for zone_id in _zones:
			if _zones[zone_id].get("status", 0) == FCWTypes.ZoneStatus.CONTROLLED:
				controlled.append(zone_id)

		if controlled.size() >= 2:
			_spawn_civilian_ship(controlled)

func _spawn_civilian_ship(controlled_zones: Array) -> void:
	var ship = CivilianShip.new()

	# Pick random start and end from controlled zones
	var from_idx = randi() % controlled_zones.size()
	var to_idx = (from_idx + 1 + randi() % (controlled_zones.size() - 1)) % controlled_zones.size()

	ship.from_zone = controlled_zones[from_idx]
	ship.to_zone = controlled_zones[to_idx]

	var from_pos = _get_zone_pixel_pos(ship.from_zone)
	var to_pos = _get_zone_pixel_pos(ship.to_zone)

	# Random offset from zone centers
	ship.start_pos = from_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	ship.target = to_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	ship.pos = ship.start_pos

	# Gentle curve
	var midpoint = (ship.start_pos + ship.target) / 2
	var perpendicular = (ship.target - ship.start_pos).normalized()
	perpendicular = Vector2(-perpendicular.y, perpendicular.x)
	ship.control_point = midpoint + perpendicular * randf_range(-50, 50)

	# Randomize ship type
	ship.civ_type = randi() % 5
	match ship.civ_type:
		CivilianShip.CivType.TRANSPORT:
			ship.color = Color(0.6, 0.7, 0.9)  # Blue-white
			ship.size = 3.0
			ship.speed = 0.2
		CivilianShip.CivType.MINER:
			ship.color = Color(0.8, 0.6, 0.4)  # Orange-brown
			ship.size = 4.0
			ship.speed = 0.15
		CivilianShip.CivType.FREIGHTER:
			ship.color = Color(0.5, 0.6, 0.5)  # Gray-green
			ship.size = 5.0
			ship.speed = 0.12
		CivilianShip.CivType.LINER:
			ship.color = Color(0.9, 0.9, 1.0)  # Bright white
			ship.size = 4.5
			ship.speed = 0.25
		CivilianShip.CivType.TANKER:
			ship.color = Color(0.7, 0.5, 0.3)  # Brown
			ship.size = 6.0
			ship.speed = 0.1

	ship.trail = []
	_civilian_ships.append(ship)

func _draw_civilian_ships(offset: Vector2) -> void:
	for ship in _civilian_ships:
		var pos = ship.pos + offset

		# Get direction
		var dir = Vector2(1, 0)
		if ship.trail.size() > 1:
			dir = (ship.pos - ship.trail[ship.trail.size() - 2]).normalized()
		var perp = Vector2(-dir.y, dir.x)

		# Faint trail
		if ship.trail.size() > 1:
			for i in range(ship.trail.size() - 1):
				var t1 = ship.trail[i] + offset
				var t2 = ship.trail[i + 1] + offset
				var alpha = float(i) / ship.trail.size() * 0.3
				draw_line(t1, t2, Color(ship.color.r, ship.color.g, ship.color.b, alpha), 1.0)

		# Simple ship shape (smaller, less detailed than military)
		match ship.civ_type:
			CivilianShip.CivType.TRANSPORT, CivilianShip.CivType.LINER:
				# Rounded passenger ship
				draw_circle(pos, ship.size, ship.color)
				draw_circle(pos + dir * ship.size * 0.5, ship.size * 0.4, ship.color.lightened(0.2))
			CivilianShip.CivType.FREIGHTER, CivilianShip.CivType.TANKER:
				# Boxy cargo ship
				var points = PackedVector2Array([
					pos + dir * ship.size,
					pos + dir * ship.size * 0.3 + perp * ship.size * 0.6,
					pos - dir * ship.size + perp * ship.size * 0.6,
					pos - dir * ship.size - perp * ship.size * 0.6,
					pos + dir * ship.size * 0.3 - perp * ship.size * 0.6,
				])
				draw_colored_polygon(points, ship.color)
			CivilianShip.CivType.MINER:
				# Industrial with arms
				draw_circle(pos, ship.size * 0.7, ship.color)
				draw_line(pos, pos + dir * ship.size * 1.2, ship.color, 2.0)
				draw_line(pos, pos + perp * ship.size, ship.color.darkened(0.2), 1.5)
				draw_line(pos, pos - perp * ship.size, ship.color.darkened(0.2), 1.5)

		# Small engine glow
		var engine_pos = pos - dir * ship.size * 0.8
		draw_circle(engine_pos, 2, Color(0.5, 0.7, 1.0, 0.5))

# ============================================================================
# COLONY SHIP (EXODUS) SYSTEM
# ============================================================================

func _update_colony_ships(delta: float) -> void:
	var i = 0
	while i < _colony_ships.size():
		var ship = _colony_ships[i]

		# Update warp flash (fades quickly)
		ship.warp_flash = maxf(ship.warp_flash - delta * 2.0, 0.0)

		# Move toward target (edge of screen/stars)
		ship.progress += delta * ship.speed
		ship.pos = ship.start_pos.lerp(ship.target, ship.progress)

		# Update trail
		ship.trail.append(ship.pos)
		if ship.trail.size() > 30:
			ship.trail.pop_front()

		# Ship has escaped! (reached edge)
		if ship.progress >= 1.0:
			_exodus_ships_escaped += 1
			_exodus_souls_escaped += ship.souls_aboard
			# Spawn a hopeful transmission
			_spawn_exodus_transmission(ship)
			_colony_ships.remove_at(i)
		else:
			i += 1

func _draw_colony_ships(offset: Vector2) -> void:
	for ship in _colony_ships:
		var pos = ship.pos + offset

		# Direction of travel
		var dir = (ship.target - ship.start_pos).normalized()
		var perp = Vector2(-dir.y, dir.x)

		# Long, hopeful green trail
		if ship.trail.size() > 1:
			for j in range(ship.trail.size() - 1):
				var t1 = ship.trail[j] + offset
				var t2 = ship.trail[j + 1] + offset
				var alpha = float(j) / ship.trail.size() * 0.6
				draw_line(t1, t2, Color(0.3, 0.9, 0.4, alpha), 2.0)

		# Warp flash effect (when departing)
		if ship.warp_flash > 0:
			var flash_size = 30 * ship.warp_flash
			draw_circle(pos, flash_size, Color(0.5, 1.0, 0.6, ship.warp_flash * 0.5))
			draw_circle(pos, flash_size * 0.5, Color(0.8, 1.0, 0.9, ship.warp_flash * 0.7))

		# Large, majestic colony ship shape (green/white)
		var ship_size = 12.0
		var ship_color = Color(0.4, 0.9, 0.5)
		var hull_color = Color(0.8, 0.9, 0.85)

		# Main hull (elongated ellipse)
		var hull_points = PackedVector2Array()
		for angle_idx in range(12):
			var angle = angle_idx * TAU / 12
			var radius_x = ship_size * 2.0
			var radius_y = ship_size * 0.6
			var hull_offset = Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
			hull_points.append(pos + hull_offset.rotated(dir.angle()))
		draw_colored_polygon(hull_points, hull_color)

		# Central module
		draw_circle(pos, ship_size * 0.5, ship_color)

		# Engine pods (two large green glows at back)
		var engine1 = pos - dir * ship_size * 1.8 + perp * ship_size * 0.4
		var engine2 = pos - dir * ship_size * 1.8 - perp * ship_size * 0.4
		draw_circle(engine1, 5, Color(0.3, 1.0, 0.5, 0.8))
		draw_circle(engine2, 5, Color(0.3, 1.0, 0.5, 0.8))
		draw_circle(engine1, 8, Color(0.3, 1.0, 0.5, 0.3))
		draw_circle(engine2, 8, Color(0.3, 1.0, 0.5, 0.3))

		# Ship name and souls aboard (if not too far)
		if ship.progress < 0.7:
			var font = ThemeDB.fallback_font
			var label = "%s" % ship.name
			var souls_label = "%s souls" % FCWTypes.format_population(ship.souls_aboard)
			draw_string(font, pos + Vector2(-30, -ship_size - 8), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color(0.5, 1.0, 0.6, 0.9))
			draw_string(font, pos + Vector2(-30, -ship_size + 2), souls_label, HORIZONTAL_ALIGNMENT_CENTER, 60, 7, Color(0.4, 0.8, 0.5, 0.7))

func _draw_fleets_in_transit(offset: Vector2) -> void:
	## Draw military fleets traveling between zones
	## Uses continuous time for smooth animation (not jerky week-by-week jumps)
	if _fleets_in_transit.is_empty():
		return

	var font = ThemeDB.fallback_font

	for transit in _fleets_in_transit:
		# Calculate positions
		var from_pos = _get_zone_pixel_pos(transit.from_zone) + offset
		var to_pos = _get_zone_pixel_pos(transit.to_zone) + offset

		# Calculate travel progress with CONTINUOUS time interpolation
		# This makes ships move smoothly, not jump at week boundaries
		var total_travel = FCWTypes.get_travel_time(transit.from_zone, transit.to_zone)
		var weeks_elapsed = total_travel - transit.turns_remaining
		# Add current week progress for smooth interpolation
		var continuous_progress = (weeks_elapsed + _week_progress) / maxf(total_travel, 1)
		var progress = clampf(continuous_progress, 0.0, 1.0)

		# Position along path - smooth continuous movement
		var current_pos = from_pos.lerp(to_pos, progress)

		# Direction of travel
		var dir = (to_pos - from_pos).normalized()
		var perp = Vector2(-dir.y, dir.x)

		# Draw travel path (dashed line)
		var path_color = Color(0.3, 0.5, 0.8, 0.3)
		var num_dashes = 8
		for i in range(num_dashes):
			var t1 = float(i) / num_dashes
			var t2 = float(i + 0.5) / num_dashes
			if t2 > progress:  # Only draw path ahead of fleet
				var dash_start = from_pos.lerp(to_pos, maxf(t1, progress))
				var dash_end = from_pos.lerp(to_pos, t2)
				draw_line(dash_start, dash_end, path_color, 1.5)

		# Draw fleet icon based on ship type
		var ship_size = 8.0
		var fleet_color = Color(0.4, 0.7, 1.0)  # Blue for friendly fleets

		match transit.ship_type:
			FCWTypes.ShipType.DREADNOUGHT:
				ship_size = 12.0
				fleet_color = Color(0.6, 0.4, 1.0)  # Purple for dreadnoughts
			FCWTypes.ShipType.CARRIER:
				ship_size = 10.0
				fleet_color = Color(0.4, 1.0, 0.6)  # Green for carriers
			FCWTypes.ShipType.CRUISER:
				ship_size = 9.0
				fleet_color = Color(0.5, 0.7, 1.0)

		# Draw multiple ship icons based on count (up to 3 visible)
		var visible_ships = mini(transit.count, 3)
		for i in range(visible_ships):
			var ship_offset = perp * (i - (visible_ships - 1) * 0.5) * 6
			var ship_pos = current_pos + ship_offset

			# Simple ship shape (chevron pointing forward)
			var points = PackedVector2Array([
				ship_pos + dir * ship_size,
				ship_pos - dir * ship_size * 0.5 + perp * ship_size * 0.5,
				ship_pos - dir * ship_size * 0.3,
				ship_pos - dir * ship_size * 0.5 - perp * ship_size * 0.5
			])
			draw_colored_polygon(points, fleet_color)

			# Engine glow
			draw_circle(ship_pos - dir * ship_size * 0.4, 2, Color(0.5, 0.8, 1.0, 0.8))

		# Fleet label (count, destination, ETA)
		var ship_name = FCWTypes.get_ship_name(transit.ship_type)
		var dest_name = FCWTypes.get_zone_name(transit.to_zone)
		var label = "%dx %s" % [transit.count, ship_name.substr(0, 4)]
		var eta_label = "→%s %dw" % [dest_name.substr(0, 4), transit.turns_remaining]

		draw_string(font, current_pos + Vector2(-25, -ship_size - 6), label, HORIZONTAL_ALIGNMENT_CENTER, 50, 7, Color(0.6, 0.8, 1.0, 0.9))
		draw_string(font, current_pos + Vector2(-25, ship_size + 10), eta_label, HORIZONTAL_ALIGNMENT_CENTER, 50, 6, Color(0.5, 0.7, 0.9, 0.7))

func _draw_exodus_counter(rect: Rect2) -> void:
	# Only show if we have ships in flight, escaped, or intercepted
	var ships_in_flight = _colony_ships.size()
	var souls_in_flight = 0
	for ship in _colony_ships:
		souls_in_flight += ship.souls_aboard

	if ships_in_flight == 0 and _exodus_ships_escaped == 0 and _lives_intercepted == 0:
		return

	var font = ThemeDB.fallback_font

	# Expand panel height if we have intercepted losses to show
	var has_losses = _lives_intercepted > 0
	var panel_h = 50 if has_losses else 40

	# Background panel at top-right
	var panel_w = 200
	var panel_x = rect.size.x - panel_w - 10
	var panel_y = 10

	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), Color(0.0, 0.1, 0.05, 0.8))
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), Color(0.3, 0.8, 0.4, 0.6), false, 1.0)

	# Title
	draw_string(font, Vector2(panel_x + 5, panel_y + 12), "EXODUS FLEET", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 1.0, 0.5))

	# Stats
	if ships_in_flight > 0:
		var line1 = "%d ships en route" % ships_in_flight
		var line2 = "%s souls aboard" % FCWTypes.format_population(souls_in_flight)
		draw_string(font, Vector2(panel_x + 5, panel_y + 24), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.9, 0.7))
		draw_string(font, Vector2(panel_x + 5, panel_y + 34), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.8, 0.6))
	else:
		var safe_text = "%d ships safe | %s souls" % [_exodus_ships_escaped, FCWTypes.format_population(_exodus_souls_escaped)]
		draw_string(font, Vector2(panel_x + 5, panel_y + 24), safe_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.9, 0.6))

	# Show intercepted losses (in red, at bottom of panel)
	if has_losses:
		var loss_text = "LOST: %s souls intercepted" % FCWTypes.format_population(_lives_intercepted)
		var y_offset = panel_y + panel_h - 8
		draw_string(font, Vector2(panel_x + 5, y_offset), loss_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 0.4, 0.3, 0.9))

func _spawn_exodus_transmission(ship: ColonyShip) -> void:
	var trans = Transmission.new()
	trans.sender = ship.name
	trans.text = "We're clear! %s souls bound for the stars." % FCWTypes.format_population(ship.souls_aboard)
	trans.pos = ship.pos
	trans.life = 5.0
	trans.max_life = 5.0
	trans.priority = 1  # Important
	_transmissions.append(trans)

func spawn_colony_ship(evacuated_this_turn: int) -> void:
	## Called from fcw_main when evacuation occurs - spawns colony ships
	if evacuated_this_turn <= 0:
		return

	# Limit visual colony ships to avoid clutter at high speeds
	const MAX_COLONY_SHIPS = 15
	if _colony_ships.size() >= MAX_COLONY_SHIPS:
		return  # Don't spawn more, evacuation still tracked in game state

	# Accumulate evacuation - spawn a ship per ~500K evacuated
	_colony_ship_spawn_accumulator += evacuated_this_turn
	const SOULS_PER_SHIP = 500_000

	while _colony_ship_spawn_accumulator >= SOULS_PER_SHIP and _colony_ships.size() < MAX_COLONY_SHIPS:
		_colony_ship_spawn_accumulator -= SOULS_PER_SHIP

		# Get Earth position as start
		var earth_pos = _get_zone_pixel_pos(FCWTypes.ZoneId.EARTH)

		# Target is top-right corner (toward the stars)
		var target = Vector2(size.x + 100, -50)

		var ship = ColonyShip.create(earth_pos, target, SOULS_PER_SHIP)
		_colony_ships.append(ship)

		# Spawn departure transmission
		var trans = Transmission.new()
		trans.sender = "Exodus Control"
		trans.text = "Colony ship '%s' departing with %s souls." % [ship.name, FCWTypes.format_population(SOULS_PER_SHIP)]
		trans.pos = earth_pos
		trans.life = 4.0
		trans.max_life = 4.0
		trans.priority = 1
		_transmissions.append(trans)

func spawn_colony_ship_from_data(ship_data: Dictionary) -> void:
	## Spawn a visual colony ship from game state data
	## Called when reducer creates a new colony ship in transit
	# Limit visual colony ships to avoid clutter at high speeds
	const MAX_COLONY_SHIPS = 15
	if _colony_ships.size() >= MAX_COLONY_SHIPS:
		return  # Don't spawn more, evacuation still tracked in game state

	var souls = ship_data.get("souls_aboard", 500000)
	var ship_name = ship_data.get("name", "Exodus")

	# Get Earth position as start
	var earth_pos = _get_zone_pixel_pos(FCWTypes.ZoneId.EARTH)

	# Target is top-right corner (toward the stars)
	var target = Vector2(size.x + 100, -50)

	var ship = ColonyShip.create(earth_pos, target, souls)
	ship.name = ship_name  # Use the name from game state
	_colony_ships.append(ship)

	# Spawn departure transmission
	var trans = Transmission.new()
	trans.sender = "Exodus Control"
	trans.text = "Colony ship '%s' departing with %s souls." % [ship_name, FCWTypes.format_population(souls)]
	trans.pos = earth_pos
	trans.life = 4.0
	trans.max_life = 4.0
	trans.priority = 1
	_transmissions.append(trans)

func set_lives_intercepted(count: int) -> void:
	## Update the intercepted lives count from game state
	_lives_intercepted = count

# ============================================================================
# TRANSMISSION SYSTEM
# ============================================================================

func _update_transmissions(delta: float) -> void:
	var i = 0
	while i < _transmissions.size():
		var trans = _transmissions[i]

		# Fade in
		trans.fade_in = minf(trans.fade_in + delta * 3.0, 1.0)

		# Typewriter effect
		trans.typing_progress = minf(trans.typing_progress + delta * 30.0, len(trans.text))

		# Life countdown
		trans.life -= delta

		if trans.life <= 0:
			_transmissions.remove_at(i)
		else:
			i += 1

func _maybe_spawn_transmission(delta: float) -> void:
	_transmission_cooldown -= delta

	if _transmission_cooldown > 0:
		return

	# Cooldown varies by narrative state
	var cooldown = 8.0
	match _narrative_state:
		0:  # Peace - occasional chatter
			cooldown = randf_range(10.0, 18.0)
		1:  # Tension - more frequent updates
			cooldown = randf_range(6.0, 12.0)
		2:  # Combat - rapid comms
			cooldown = randf_range(3.0, 6.0)
		3:  # Desperate - constant
			cooldown = randf_range(2.0, 4.0)

	_transmission_cooldown = cooldown

	# Pick appropriate transmission
	var templates: Array
	match _narrative_state:
		0:
			templates = TRANSMISSIONS_PEACE
		1:
			templates = TRANSMISSIONS_TENSION
		2:
			templates = TRANSMISSIONS_COMBAT
		3:
			templates = TRANSMISSIONS_DESPERATE

	if templates.size() > 0:
		var template = templates[randi() % templates.size()]
		spawn_transmission(template.sender, template.text, _narrative_state)

func spawn_transmission(sender: String, text: String, priority: int = 0) -> void:
	var trans = Transmission.new()
	trans.sender = sender
	trans.text = text
	trans.priority = priority
	trans.life = 5.0 + len(text) * 0.05  # Longer text stays longer
	trans.max_life = trans.life
	trans.fade_in = 0.0
	trans.typing_progress = 0.0

	# Position in bottom-left corner, stacked
	var y_offset = _transmissions.size() * 45
	trans.pos = Vector2(20, size.y - 80 - y_offset)

	# Limit number of transmissions
	if _transmissions.size() >= 4:
		_transmissions.pop_front()

	_transmissions.append(trans)

func _draw_transmissions(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var y_pos = rect.size.y - 60

	for trans in _transmissions:
		var alpha = trans.fade_in * minf(trans.life / 1.0, 1.0)  # Fade out in last second

		# Calculate box height based on text length (roughly 40 chars per line)
		var box_width = 400
		var chars_per_line = 45
		var display_text = trans.text.substr(0, int(trans.typing_progress))
		var num_lines = ceili(float(display_text.length()) / chars_per_line)
		num_lines = maxi(num_lines, 1)
		var box_height = 22 + num_lines * 14  # Header + lines
		var box_pos = Vector2(15, y_pos - box_height)

		# Priority colors
		var bg_color: Color
		var text_color: Color
		var sender_color: Color
		match trans.priority:
			0:  # Routine - subtle blue
				bg_color = Color(0.1, 0.15, 0.2, alpha * 0.85)
				text_color = Color(0.7, 0.8, 0.9, alpha)
				sender_color = Color(0.5, 0.7, 0.8, alpha)
			1:  # Important - yellow
				bg_color = Color(0.2, 0.18, 0.1, alpha * 0.9)
				text_color = Color(1.0, 0.95, 0.7, alpha)
				sender_color = Color(0.9, 0.8, 0.4, alpha)
			2:  # Critical - orange/red pulse
				var pulse = sin(_global_time * 4.0) * 0.1
				bg_color = Color(0.3 + pulse, 0.1, 0.05, alpha * 0.95)
				text_color = Color(1.0, 0.85, 0.6, alpha)
				sender_color = Color(1.0, 0.5, 0.2, alpha)
			3:  # Desperate - red with intense pulse
				var pulse = sin(_global_time * 6.0) * 0.15
				bg_color = Color(0.4 + pulse, 0.05, 0.05, alpha * 0.95)
				text_color = Color(1.0, 0.8, 0.8, alpha)
				sender_color = Color(1.0, 0.3, 0.3, alpha)

		# Draw background with border
		draw_rect(Rect2(box_pos, Vector2(box_width, box_height)), bg_color)
		var border_color = sender_color
		border_color.a = alpha * 0.6
		draw_rect(Rect2(box_pos, Vector2(box_width, box_height)), border_color, false, 1.5)

		# Draw sender
		draw_string(font, box_pos + Vector2(8, 14), "[%s]" % trans.sender, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, sender_color)

		# Draw text with word wrap - split into lines
		var y_offset = 28
		var remaining_text = display_text
		while remaining_text.length() > 0:
			var line_text = remaining_text.substr(0, chars_per_line)
			# Try to break at word boundary
			if remaining_text.length() > chars_per_line:
				var last_space = line_text.rfind(" ")
				if last_space > chars_per_line * 0.5:
					line_text = remaining_text.substr(0, last_space)
			draw_string(font, box_pos + Vector2(8, y_offset), line_text, HORIZONTAL_ALIGNMENT_LEFT, box_width - 16, 11, text_color)
			remaining_text = remaining_text.substr(line_text.length()).strip_edges()
			y_offset += 14

		y_pos -= box_height + 8  # Stack upward with gap

func spawn_warp_in(zone_id: int) -> void:
	# Called when ships warp to a zone
	var pos = _get_zone_pixel_pos(zone_id)
	var zone_size = ZONE_SIZES.get(zone_id, 20.0)

	_warp_flashes.append({"pos": pos + Vector2(zone_size + 20, 0), "life": 1.0})

	# Spawn arrival particles
	for i in range(10):
		var p = Particle.new()
		p.pos = pos + Vector2(zone_size + 20, 0)
		p.vel = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		p.color = Color(0.5, 0.8, 1.0, 1.0)
		p.life = randf_range(0.3, 0.6)
		p.max_life = p.life
		p.size = randf_range(2, 4)
		_particles.append(p)

func spawn_zone_destroyed(zone_id: int) -> void:
	# MASSIVE explosion when zone falls
	var pos = _get_zone_pixel_pos(zone_id)
	var zone_size = ZONE_SIZES.get(zone_id, 20.0)

	# Add to fallen zones for debris
	if zone_id not in _fallen_zones:
		_fallen_zones.append(zone_id)

	# Multiple large explosions - PURPLE alien victory explosions
	for i in range(8):
		var exp = Explosion.new()
		exp.pos = pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		exp.max_radius = randf_range(30, 60)
		exp.life = 0.8 + randf() * 0.5
		# Alien void consuming the zone - purple/magenta destruction
		exp.color = Color(0.7, randf_range(0.1, 0.4), randf_range(0.5, 0.8))
		_explosions.append(exp)

	# Big screen shake
	_screen_shake_intensity = 15.0

	# Damage flash on zone
	_zone_damage_flash[zone_id] = 1.0

	# LOTS of debris particles
	for i in range(40):
		var p = Particle.new()
		p.pos = pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		p.vel = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		p.color = Color(randf_range(0.8, 1.0), randf_range(0.3, 0.7), randf_range(0.0, 0.2), 1.0)
		p.life = randf_range(0.5, 1.5)
		p.max_life = p.life
		p.size = randf_range(2, 6)
		_particles.append(p)

func spawn_ship_transit(from_zone: int, to_zone: int, ship_type: int = -1) -> void:
	# Spawn a ship moving between zones with full visual effects
	# Limit visual ships to avoid clutter at high speeds
	const MAX_VISUAL_SHIPS = 30
	if _ships.size() >= MAX_VISUAL_SHIPS:
		return  # Don't spawn more visual ships, game state still tracks them

	var from_pos = _get_zone_pixel_pos(from_zone)
	var to_pos = _get_zone_pixel_pos(to_zone)
	var from_size = ZONE_SIZES.get(from_zone, 20.0)
	var to_size = ZONE_SIZES.get(to_zone, 20.0)

	# Determine ship class
	var ship_class = Ship.ShipClass.FRIGATE
	if ship_type >= 0:
		match ship_type:
			FCWTypes.ShipType.FRIGATE:
				ship_class = Ship.ShipClass.FRIGATE
			FCWTypes.ShipType.CRUISER:
				ship_class = Ship.ShipClass.CRUISER
			FCWTypes.ShipType.CARRIER:
				ship_class = Ship.ShipClass.CARRIER
			FCWTypes.ShipType.DREADNOUGHT:
				ship_class = Ship.ShipClass.DREADNOUGHT
	else:
		# Random ship type weighted toward frigates
		var roll = randf()
		if roll < 0.6:
			ship_class = Ship.ShipClass.FRIGATE
		elif roll < 0.85:
			ship_class = Ship.ShipClass.CRUISER
		elif roll < 0.95:
			ship_class = Ship.ShipClass.CARRIER
		else:
			ship_class = Ship.ShipClass.DREADNOUGHT

	var ship = Ship.new()

	# Starting position with slight randomization
	var start_offset = Vector2(from_size + 20 + randf_range(-10, 10), randf_range(-15, 15))
	ship.start_pos = from_pos + start_offset
	ship.pos = ship.start_pos

	# Target position
	var end_offset = Vector2(to_size + 20 + randf_range(-10, 10), randf_range(-15, 15))
	ship.target = to_pos + end_offset

	# Calculate curved flight path (bezier control point)
	var midpoint = (ship.start_pos + ship.target) / 2
	var perpendicular = (ship.target - ship.start_pos).normalized()
	perpendicular = Vector2(-perpendicular.y, perpendicular.x)
	# Curve away from center, more dramatic curve
	var curve_strength = ship.start_pos.distance_to(ship.target) * randf_range(0.2, 0.4)
	var curve_dir = 1 if randf() > 0.5 else -1
	ship.control_point = midpoint + perpendicular * curve_strength * curve_dir

	# Ship class properties - Earth Fleet colors (blue/cyan engines, cool hull colors)
	ship.ship_class = ship_class
	match ship_class:
		Ship.ShipClass.FRIGATE:
			ship.size = randf_range(5, 7)
			ship.speed = randf_range(1.1, 1.3)
			ship.color = Color(0.5, 0.7, 0.9)  # Light blue-gray
			ship.engine_color = Color(0.3, 0.7, 1.0)  # Cyan blue
		Ship.ShipClass.CRUISER:
			ship.size = randf_range(8, 10)
			ship.speed = randf_range(0.9, 1.0)
			ship.color = Color(0.4, 0.55, 0.75)  # Navy blue
			ship.engine_color = Color(0.2, 0.6, 1.0)  # Blue
		Ship.ShipClass.CARRIER:
			ship.size = randf_range(12, 15)
			ship.speed = randf_range(0.7, 0.85)
			ship.color = Color(0.5, 0.6, 0.7)  # Steel gray-blue
			ship.engine_color = Color(0.3, 0.8, 1.0)  # Cyan
		Ship.ShipClass.DREADNOUGHT:
			ship.size = randf_range(14, 18)
			ship.speed = randf_range(0.75, 0.9)
			ship.color = Color(0.3, 0.45, 0.6)  # Dark steel blue
			ship.engine_color = Color(0.4, 0.7, 1.0)  # Bright cyan

	ship.progress = 0.0
	ship.trail = []
	ship.rotation = (ship.target - ship.pos).angle()
	_ships.append(ship)

	# Dramatic warp-out effect
	_spawn_warp_out_effect(ship.start_pos, ship_class)

func _spawn_warp_out_effect(pos: Vector2, ship_class: int) -> void:
	# Blue warp ring for Earth Fleet departure
	_warp_flashes.append({"pos": pos, "life": 0.8, "color": Color(0.3, 0.6, 1.0)})

	# Intensity based on ship size
	var booster_count = 4
	var trail_length = 25
	match ship_class:
		Ship.ShipClass.CRUISER:
			booster_count = 6
			trail_length = 35
		Ship.ShipClass.CARRIER:
			booster_count = 8
			trail_length = 40
		Ship.ShipClass.DREADNOUGHT:
			booster_count = 10
			trail_length = 50

	# BOOSTER IGNITION - bright cyan exhaust trails shooting backward
	for j in range(booster_count):
		var p = Particle.new()
		# Stagger starting positions slightly
		p.pos = pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		# Exhaust shoots away from departure direction (mostly backward)
		var exhaust_angle = randf_range(-0.5, 0.5)  # Slight spread
		p.vel = Vector2(cos(PI + exhaust_angle), sin(PI + exhaust_angle)) * randf_range(trail_length, trail_length * 1.5)
		p.color = Color(0.5, 0.85, 1.0, 0.95)  # Bright cyan
		p.life = randf_range(0.5, 0.8)
		p.max_life = p.life
		p.size = randf_range(3, 5)
		_particles.append(p)

	# Secondary exhaust glow (wider, dimmer)
	for j in range(booster_count / 2):
		var p = Particle.new()
		p.pos = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var exhaust_angle = randf_range(-0.8, 0.8)
		p.vel = Vector2(cos(PI + exhaust_angle), sin(PI + exhaust_angle)) * randf_range(15, 30)
		p.color = Color(0.3, 0.6, 1.0, 0.6)  # Dimmer blue
		p.life = randf_range(0.6, 0.9)
		p.max_life = p.life
		p.size = randf_range(4, 7)
		_particles.append(p)

	# Engine ignition flash (bright white-blue center)
	var flash_p = Particle.new()
	flash_p.pos = pos
	flash_p.vel = Vector2.ZERO
	flash_p.color = Color(0.8, 0.95, 1.0, 1.0)  # Bright white-blue
	flash_p.life = 0.25
	flash_p.max_life = 0.25
	flash_p.size = 8
	_particles.append(flash_p)

func spawn_fleet_transit(from_zone: int, to_zone: int, ship_count: int, ship_type: int = -1) -> void:
	## Spawn multiple ships in formation
	# Limit visual ships to avoid clutter at high speeds
	const MAX_VISUAL_SHIPS = 30
	if _ships.size() >= MAX_VISUAL_SHIPS:
		return  # Don't spawn more visual ships, game state still tracks them

	var from_pos = _get_zone_pixel_pos(from_zone)
	var to_pos = _get_zone_pixel_pos(to_zone)
	var direction = (to_pos - from_pos).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)

	# Formation patterns based on count
	var offsets: Array = []
	if ship_count <= 3:
		# V formation
		for i in range(ship_count):
			var row = i
			var col = i - ship_count / 2.0
			offsets.append(Vector2(-row * 15, col * 20))
	elif ship_count <= 6:
		# Double V
		for i in range(ship_count):
			var row = i / 3
			var col = (i % 3) - 1
			offsets.append(Vector2(-row * 20, col * 25))
	else:
		# Staggered block
		for i in range(ship_count):
			var row = i / 4
			var col = (i % 4) - 1.5
			offsets.append(Vector2(-row * 18 + (row % 2) * 8, col * 22))

	# Spawn ships with staggered timing using formation offsets
	for i in range(mini(ship_count, len(offsets))):
		# Slight delay between ships (handled by progress offset)
		var ship = Ship.new()

		var from_size = ZONE_SIZES.get(from_zone, 20.0)
		var to_size = ZONE_SIZES.get(to_zone, 20.0)

		ship.start_pos = from_pos + Vector2(from_size + 20, 0)
		ship.target = to_pos + Vector2(to_size + 20, 0)
		ship.pos = ship.start_pos

		# Transform formation offset to world space
		var world_offset = direction * offsets[i].x + perpendicular * offsets[i].y
		ship.formation_offset = world_offset
		ship.formation_index = i

		# Bezier control point
		var midpoint = (ship.start_pos + ship.target) / 2
		var curve_perpendicular = Vector2(-direction.y, direction.x)
		var curve_strength = ship.start_pos.distance_to(ship.target) * 0.25
		ship.control_point = midpoint + curve_perpendicular * curve_strength * (1 if i % 2 == 0 else -1)

		# Determine ship class
		var ship_class = Ship.ShipClass.FRIGATE
		if ship_type >= 0:
			match ship_type:
				FCWTypes.ShipType.FRIGATE: ship_class = Ship.ShipClass.FRIGATE
				FCWTypes.ShipType.CRUISER: ship_class = Ship.ShipClass.CRUISER
				FCWTypes.ShipType.CARRIER: ship_class = Ship.ShipClass.CARRIER
				FCWTypes.ShipType.DREADNOUGHT: ship_class = Ship.ShipClass.DREADNOUGHT
		else:
			ship_class = Ship.ShipClass.FRIGATE if randf() < 0.7 else Ship.ShipClass.CRUISER

		ship.ship_class = ship_class
		# Earth Fleet colors (blue/cyan theme)
		match ship_class:
			Ship.ShipClass.FRIGATE:
				ship.size = randf_range(5, 7)
				ship.speed = randf_range(1.1, 1.3)
				ship.color = Color(0.5, 0.7, 0.9)  # Light blue-gray
				ship.engine_color = Color(0.3, 0.7, 1.0)  # Cyan
			Ship.ShipClass.CRUISER:
				ship.size = randf_range(8, 10)
				ship.speed = randf_range(0.9, 1.0)
				ship.color = Color(0.4, 0.55, 0.75)  # Navy blue
				ship.engine_color = Color(0.2, 0.6, 1.0)  # Blue
			_:
				ship.size = randf_range(6, 8)
				ship.speed = 1.0
				ship.color = Color(0.45, 0.6, 0.8)  # Blue
				ship.engine_color = Color(0.3, 0.7, 1.0)  # Cyan

		# Stagger start times
		ship.progress = -i * 0.05  # Negative progress = delayed start

		ship.trail = []
		ship.rotation = direction.angle()
		_ships.append(ship)

	# Single warp-out effect for the formation
	_spawn_warp_out_effect(from_pos + Vector2(ZONE_SIZES.get(from_zone, 20.0) + 20, 0), Ship.ShipClass.CRUISER)

# ============================================================================
# INPUT
# ============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos = event.position
		var offset = _screen_shake

		# Check for entity hover first
		var new_hovered_entity = _get_entity_at_position(mouse_pos, offset)
		if new_hovered_entity != _hovered_entity_id:
			_hovered_entity_id = new_hovered_entity
			queue_redraw()

		# Then check zone hover
		var new_hovered = _get_zone_at_position(mouse_pos)
		if new_hovered != _hovered_zone:
			_hovered_zone = new_hovered
			if _hovered_zone >= 0:
				zone_hovered.emit(_hovered_zone)
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos = event.position
			var offset = _screen_shake

			# If route options popup is visible, check for option click
			if _route_options_visible:
				var option_clicked = _get_route_option_at_position(mouse_pos)
				if option_clicked >= 0:
					_select_route_option(option_clicked)
					return
				# Click outside dismisses popup
				_route_options_visible = false
				_route_selection_mode = false
				queue_redraw()
				return

			# Check for roster panel click (select capital ship from menu)
			var roster_index = _get_roster_item_at_position(mouse_pos)
			if roster_index >= 0:
				var entity_id = _find_entity_for_roster_item(roster_index)
				if entity_id != "":
					# If clicking the same ship again, cancel selection
					if entity_id == _selected_entity_id:
						_selected_entity_id = ""
						_route_selection_mode = false
						queue_redraw()
					else:
						_select_entity(entity_id)
				return

			# ALWAYS check for entity click first (with cycling for stacked ships)
			# This ensures ships at planets can be selected
			var clicked_entity = _select_entity_with_cycling(mouse_pos, offset)
			if clicked_entity != "":
				_select_entity(clicked_entity)
				return

			# If in route selection mode, left-click on zone uses default route (stealth coast)
			if _route_selection_mode and _selected_entity_id != "":
				var clicked_zone = _get_zone_at_position(mouse_pos)
				if clicked_zone >= 0:
					_select_default_route(_selected_entity_id, clicked_zone)
					return

			# Normal zone click (when not in route selection mode)
			var clicked_zone = _get_zone_at_position(mouse_pos)
			if clicked_zone >= 0:
				_selected_zone = clicked_zone
				_selected_entity_id = ""  # Deselect entity when clicking zone
				_route_selection_mode = false
				zone_clicked.emit(clicked_zone)
				queue_redraw()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse_pos = event.position
			# Right-click in route selection mode shows route options popup
			if _route_selection_mode and _selected_entity_id != "":
				var clicked_zone = _get_zone_at_position(mouse_pos)
				if clicked_zone >= 0:
					_show_route_options(_selected_entity_id, clicked_zone)
					return
			# Otherwise, right-click cancels selection
			_selected_entity_id = ""
			_route_selection_mode = false
			_route_options_visible = false
			queue_redraw()

func _get_zone_at_position(pos: Vector2) -> int:
	for zone_id in FCWTypes.ZoneId.values():
		var zone_pos = _get_zone_pixel_pos(zone_id)
		var zone_size = ZONE_SIZES.get(zone_id, 20.0) + 10  # Some padding
		if pos.distance_to(zone_pos) <= zone_size:
			return zone_id
	return -1

## Get entity ID at screen position (for click detection)
## Returns first entity found, or cycles if clicking same spot
func _get_entity_at_position(pos: Vector2, offset: Vector2) -> String:
	var entities_here = _get_all_entities_at_position(pos, offset)
	if entities_here.is_empty():
		return ""
	return entities_here[0]

## Get ALL entity IDs at screen position (for stacked ship selection)
func _get_all_entities_at_position(pos: Vector2, offset: Vector2) -> Array:
	var entities = _state.get("entities", [])
	var game_time = _state.get("game_time", 0.0)
	var found: Array = []

	for entity in entities:
		# Skip Herald and destroyed entities
		if entity.faction == FCWTypes.Faction.HERALD:
			continue
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		# Get entity screen position
		var entity_pos = _get_entity_screen_pos(entity, game_time) + offset

		# Check distance
		if pos.distance_to(entity_pos) <= ENTITY_CLICK_RADIUS:
			found.append(entity.id)

	return found

## Select entity with cycling support for stacked ships
func _select_entity_with_cycling(pos: Vector2, offset: Vector2) -> String:
	var entities_here = _get_all_entities_at_position(pos, offset)

	if entities_here.is_empty():
		_entities_at_click = []
		_entity_cycle_index = 0
		return ""

	# Check if clicking same location as before
	if entities_here == _entities_at_click and entities_here.size() > 1:
		# Cycle to next entity
		_entity_cycle_index = (_entity_cycle_index + 1) % entities_here.size()
	else:
		# New location - reset cycle
		_entities_at_click = entities_here
		_entity_cycle_index = 0

	return entities_here[_entity_cycle_index]

## Get entity screen position from AU coordinates
func _get_entity_screen_pos(entity: Dictionary, game_time: float) -> Vector2:
	# If entity is orbiting, use zone position
	if entity.movement_state == FCWTypes.MovementState.ORBITING:
		var zone_id = entity.get("origin", -1)
		if zone_id >= 0:
			var zone_pos = _get_zone_pixel_pos(zone_id)
			# Offset slightly from zone center based on entity index
			# Keep ships close to planet edge, not floating far away
			var entity_index = hash(entity.id) % 8
			var angle = entity_index * TAU / 8.0
			var zone_size = ZONE_SIZES.get(zone_id, 20.0)
			var orbit_radius = zone_size * 0.7  # Stay within zone visual
			return zone_pos + Vector2(cos(angle), sin(angle)) * orbit_radius

	# For moving entities, interpolate between zones
	var origin = entity.get("origin", -1)
	var destination = entity.get("destination", -1)

	if origin >= 0 and destination >= 0 and origin != destination:
		var from_pos = _get_zone_pixel_pos(origin)
		var to_pos = _get_zone_pixel_pos(destination)

		# Calculate progress based on entity position
		var entity_au = entity.position
		var from_au = FCWTypes.get_zone_position(origin, game_time)
		var to_au = FCWTypes.get_zone_position(destination, game_time)
		var total_dist = from_au.distance_to(to_au)
		var current_dist = from_au.distance_to(entity_au)
		var progress = clampf(current_dist / maxf(total_dist, 0.1), 0.0, 1.0)

		return from_pos.lerp(to_pos, progress)

	# Fallback to origin zone
	if origin >= 0:
		return _get_zone_pixel_pos(origin)

	return Vector2.ZERO

## Handle entity selection
func _select_entity(entity_id: String) -> void:
	_selected_entity_id = entity_id
	_selected_zone = -1  # Deselect zone
	_route_selection_mode = true  # Enter route selection mode
	_route_options_visible = false
	entity_clicked.emit(entity_id)
	queue_redraw()

## Show route options popup for selected entity to destination
func _show_route_options(entity_id: String, destination_zone: int) -> void:
	var entity = _get_entity_by_id(entity_id)
	if entity.is_empty():
		return

	var origin = entity.get("origin", -1)
	if origin < 0 or origin == destination_zone:
		return

	# Get route options from orbital calculator
	var game_time = _state.get("game_time", 0.0)
	var ship_type = FCWTypes.ShipType.CRUISER  # Default thrust
	if entity.entity_type == FCWTypes.EntityType.TRANSPORT:
		ship_type = FCWTypes.ShipType.FRIGATE

	# Load FCWOrbital
	var FCWOrbital = load("res://scripts/first_contact_war/fcw_orbital.gd")
	_route_options = FCWOrbital.get_route_summary(origin, destination_zone, game_time, ship_type)
	_route_options_zone = destination_zone
	_route_options_visible = true
	queue_redraw()

## Get entity by ID from state
func _get_entity_by_id(entity_id: String) -> Dictionary:
	for entity in _state.get("entities", []):
		if entity.id == entity_id:
			return entity
	return {}

## Get roster item index at screen position
func _get_roster_item_at_position(pos: Vector2) -> int:
	for item in _roster_item_rects:
		if item.rect.has_point(pos) and item.alive:
			return item.index
	return -1

## Find entity matching a roster ship (by type and availability)
func _find_entity_for_roster_item(roster_index: int) -> String:
	if roster_index < 0 or roster_index >= _capital_ship_states.size():
		return ""

	var roster_ship = _capital_ship_states[roster_index]
	if not roster_ship.alive:
		return ""

	# If we already have an entity_id cached, use it
	if roster_ship.get("entity_id", "") != "":
		var entity = _get_entity_by_id(roster_ship.entity_id)
		if not entity.is_empty() and entity.movement_state != FCWTypes.MovementState.DESTROYED:
			return roster_ship.entity_id

	# Find a warship entity of this type
	var target_type = roster_ship.type
	var entities = _state.get("entities", [])

	# Collect all candidate entities matching this ship type
	var candidates: Array = []
	for entity in entities:
		if entity.get("entity_type") != FCWTypes.EntityType.WARSHIP:
			continue
		if entity.get("faction") != FCWTypes.Faction.HUMAN:
			continue
		if entity.get("ship_type") != target_type:
			continue
		if entity.get("movement_state") == FCWTypes.MovementState.DESTROYED:
			continue
		candidates.append(entity)

	# If we found any candidates, prefer ones that are orbiting (available)
	if candidates.size() > 0:
		# Sort: orbiting entities first, then by ID for consistency
		candidates.sort_custom(func(a, b):
			var a_orbiting = a.movement_state == FCWTypes.MovementState.ORBITING
			var b_orbiting = b.movement_state == FCWTypes.MovementState.ORBITING
			if a_orbiting != b_orbiting:
				return a_orbiting  # Orbiting comes first
			return a.id < b.id
		)

		# Find one that's not already mapped to another roster item
		var used_ids: Array = []
		for i in range(_capital_ship_states.size()):
			if i != roster_index:
				var other_id = _capital_ship_states[i].get("entity_id", "")
				if other_id != "":
					used_ids.append(other_id)

		for candidate in candidates:
			if candidate.id not in used_ids:
				# Cache this mapping
				_capital_ship_states[roster_index]["entity_id"] = candidate.id
				return candidate.id

	return ""

## Get route option index at screen position
func _get_route_option_at_position(pos: Vector2) -> int:
	if not _route_options_visible or _route_options.is_empty():
		return -1

	# Route options popup position (near selected entity)
	var popup_pos = _get_route_options_popup_pos()
	var option_height = 35
	var popup_width = 250

	for i in range(_route_options.size()):
		var option_rect = Rect2(
			popup_pos.x,
			popup_pos.y + 30 + i * option_height,
			popup_width,
			option_height - 5
		)
		if option_rect.has_point(pos):
			return i

	return -1

## Get position for route options popup
func _get_route_options_popup_pos() -> Vector2:
	if _route_options_zone < 0:
		return Vector2(100, 100)

	var zone_pos = _get_zone_pixel_pos(_route_options_zone)
	return zone_pos + Vector2(50, -50)

## Handle route option selection
func _select_route_option(option_index: int) -> void:
	if option_index < 0 or option_index >= _route_options.size():
		return

	var route = _route_options[option_index]
	var route_type = route.get("type", "direct")

	# Emit signal for main controller to handle
	entity_destination_selected.emit(_selected_entity_id, _route_options_zone, route_type)

	# Trigger warp effect for dramatic departure
	_trigger_capital_ship_launch(_selected_entity_id)

	# Clear selection state
	_selected_entity_id = ""
	_route_selection_mode = false
	_route_options_visible = false
	_route_options_zone = -1
	_route_options.clear()
	queue_redraw()

## Select default route (stealth coast) - simplified 2-click flow
func _select_default_route(entity_id: String, destination_zone: int) -> void:
	var entity = _get_entity_by_id(entity_id)
	if entity.is_empty():
		return

	var origin = entity.get("origin", -1)
	if origin < 0 or origin == destination_zone:
		return

	# Default to "coast" (stealth) - the safer option
	var route_type = "coast"

	# Emit signal for main controller to handle
	entity_destination_selected.emit(entity_id, destination_zone, route_type)

	# Trigger warp effect for dramatic departure
	_trigger_capital_ship_launch(entity_id)

	# Clear selection state
	_selected_entity_id = ""
	_route_selection_mode = false
	_route_options_visible = false
	_route_options_zone = -1
	_route_options.clear()
	queue_redraw()

## Trigger dramatic warp zoom effect for capital ship launch
func _trigger_capital_ship_launch(entity_id: String) -> void:
	var entity = _get_entity_by_id(entity_id)
	if entity.is_empty():
		return

	var game_time = _state.get("game_time", 0.0)
	var entity_pos = _get_entity_screen_pos(entity, game_time)

	# Spawn dramatic warp flash
	_warp_flashes.append({
		"pos": entity_pos,
		"life": 2.0,
		"max_life": 2.0,
		"is_capital": true  # Flag for extra dramatic effect
	})

	# Screen shake
	_screen_shake_intensity = 15.0

	# Add particles
	for i in range(20):
		var p = Particle.new()
		p.pos = entity_pos
		var angle = randf() * TAU
		p.vel = Vector2(cos(angle), sin(angle)) * randf_range(50, 150)
		p.color = Color(0.3, 0.6, 1.0, 1.0)
		p.life = randf_range(0.5, 1.5)
		p.max_life = p.life
		p.size = randf_range(2, 5)
		_particles.append(p)

## Draw bezier curve previews from selected entity to each possible destination
## Shows visual paths with color-coded route types (direct, coast, gravity assist)
func _draw_route_preview_curves(offset: Vector2) -> void:
	var entity = _get_entity_by_id(_selected_entity_id)
	if entity.is_empty():
		return

	var origin_zone = entity.get("origin", -1)
	if origin_zone < 0:
		return

	var game_time = _state.get("game_time", 0.0)
	var entity_pos = _get_entity_screen_pos(entity, game_time) + offset

	# Determine ship type for route calculations
	var ship_type = FCWTypes.ShipType.CRUISER
	if entity.entity_type == FCWTypes.EntityType.TRANSPORT:
		ship_type = FCWTypes.ShipType.FRIGATE

	var FCWOrbital = load("res://scripts/first_contact_war/fcw_orbital.gd")

	# Draw curves to each valid destination
	for zone_id in FCWTypes.ZoneId.values():
		if zone_id == origin_zone:
			continue

		var zone = _state.zones.get(zone_id, {})
		if zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue

		var dest_pos = _get_zone_pixel_pos(zone_id) + offset
		var is_hovered = _hovered_zone == zone_id

		# Get route options for this destination
		var routes = FCWOrbital.get_route_summary(origin_zone, zone_id, game_time, ship_type)
		if routes.is_empty():
			continue

		# Draw curve for fastest route (primary preview)
		var fastest_route = routes[0]
		var route_type = fastest_route.get("type", "direct")

		# Calculate bezier control point based on route type
		var control_point = _calc_route_control_point(entity_pos, dest_pos, route_type, game_time)

		# Determine curve color and style based on route type and hover state
		var base_alpha = 0.15 if not is_hovered else 0.5
		var curve_width = 1.5 if not is_hovered else 3.0
		var curve_color: Color

		match route_type:
			"direct":
				curve_color = Color(1.0, 0.5, 0.3, base_alpha)  # Orange - fast but visible
			"coast":
				curve_color = Color(0.4, 0.9, 0.5, base_alpha)  # Green - stealthy
			"gravity_assist":
				curve_color = Color(0.5, 0.6, 1.0, base_alpha)  # Blue - efficient
			_:
				curve_color = Color(0.7, 0.7, 0.7, base_alpha)  # Gray - unknown

		# Draw animated bezier curve
		_draw_animated_bezier(entity_pos, control_point, dest_pos, curve_color, curve_width)

		# Draw destination marker with matching color
		if is_hovered:
			var pulse = sin(_global_time * 3.0) * 0.2 + 0.8
			draw_arc(dest_pos, 12.0 * pulse, 0, TAU, 24, curve_color.lightened(0.3), 2.0)

## Calculate bezier control point for route preview curve
func _calc_route_control_point(start_pos: Vector2, end_pos: Vector2, route_type: String, _game_time: float) -> Vector2:
	var midpoint = start_pos.lerp(end_pos, 0.5)
	var perpendicular = (end_pos - start_pos).rotated(PI / 2).normalized()
	var distance = start_pos.distance_to(end_pos)

	# Sun is roughly at center-right of map (Earth position)
	var sun_pos = Vector2(0.85, 0.5) * size
	var to_sun = (sun_pos - midpoint).normalized()

	match route_type:
		"direct":
			# Slight curve toward sun (brachistochrone approximation)
			return midpoint + to_sun * distance * 0.08
		"coast":
			# Wider arc perpendicular to path (Hohmann-like transfer)
			# Choose direction away from sun for realistic orbital path
			var away_from_sun = -to_sun
			return midpoint + away_from_sun * distance * 0.2
		"gravity_assist":
			# More pronounced curve (using gravity well)
			return midpoint + perpendicular * distance * 0.25
		_:
			return midpoint

## Calculate bezier control point for entity trajectory (used when entity already has route assigned)
func _calc_trajectory_control_point(start_pos: Vector2, end_pos: Vector2, route_type: String, waypoint_zone: int) -> Vector2:
	var midpoint = start_pos.lerp(end_pos, 0.5)
	var perpendicular = (end_pos - start_pos).rotated(PI / 2).normalized()
	var distance = start_pos.distance_to(end_pos)

	# Sun is roughly at center-right of map (Earth position)
	var sun_pos = Vector2(0.85, 0.5) * size
	var to_sun = (sun_pos - midpoint).normalized()

	match route_type:
		"direct":
			# Slight curve toward sun
			return midpoint + to_sun * distance * 0.08
		"coast":
			# Wider arc away from sun
			var away_from_sun = -to_sun
			return midpoint + away_from_sun * distance * 0.2
		"gravity_assist":
			# Use waypoint zone as control point if valid
			if waypoint_zone >= 0:
				return _get_zone_pixel_pos(waypoint_zone)
			# Fallback to perpendicular curve
			return midpoint + perpendicular * distance * 0.25
		_:
			# Default: slight curve for visual interest
			return midpoint + perpendicular * distance * 0.1

## Draw animated dashed bezier curve with flowing dash effect
func _draw_animated_bezier(p0: Vector2, p1: Vector2, p2: Vector2, color: Color, width: float) -> void:
	var segments = 24
	var dash_length = 12.0
	var gap_length = 6.0

	# Generate curve points
	var points: Array[Vector2] = []
	for i in range(segments + 1):
		var t = float(i) / segments
		var t1 = 1.0 - t
		# Quadratic bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
		var point = t1 * t1 * p0 + 2 * t1 * t * p1 + t * t * p2
		points.append(point)

	# Calculate arc lengths between points
	var arc_lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		arc_lengths.append(arc_lengths[i - 1] + points[i - 1].distance_to(points[i]))
	var total_length = arc_lengths[arc_lengths.size() - 1]

	# Animated offset for flowing effect
	var dash_offset = fmod(_global_time * 40.0, dash_length + gap_length)

	# Draw dashes along the curve
	var current_dist = -dash_offset
	var drawing = true

	while current_dist < total_length:
		var segment_end_dist = current_dist + (dash_length if drawing else gap_length)

		if drawing and current_dist < total_length:
			var start_dist = maxf(0.0, current_dist)
			var end_dist = minf(total_length, segment_end_dist)

			if start_dist < end_dist:
				var start_point = _get_point_at_arc_length(points, arc_lengths, start_dist)
				var end_point = _get_point_at_arc_length(points, arc_lengths, end_dist)
				draw_line(start_point, end_point, color, width)

		current_dist = segment_end_dist
		drawing = not drawing

## Get point along bezier curve at specific arc length distance
func _get_point_at_arc_length(points: Array[Vector2], arc_lengths: Array[float], target_dist: float) -> Vector2:
	# Binary search for segment containing target distance
	var low = 0
	var high = arc_lengths.size() - 1

	while low < high - 1:
		var mid = (low + high) / 2
		if arc_lengths[mid] < target_dist:
			low = mid
		else:
			high = mid

	# Interpolate within segment
	var segment_start = arc_lengths[low]
	var segment_end = arc_lengths[high]
	var segment_length = segment_end - segment_start

	if segment_length < 0.001:
		return points[low]

	var t = (target_dist - segment_start) / segment_length
	return points[low].lerp(points[high], t)

## Draw route cost preview at each possible destination zone
func _draw_route_cost_previews(offset: Vector2) -> void:
	var entity = _get_entity_by_id(_selected_entity_id)
	if entity.is_empty():
		return

	var origin_zone = entity.get("origin", -1)
	if origin_zone < 0:
		return

	var game_time = _state.get("game_time", 0.0)
	var font = ThemeDB.fallback_font

	# Determine ship thrust for route calculations
	var ship_type = FCWTypes.ShipType.CRUISER
	if entity.entity_type == FCWTypes.EntityType.TRANSPORT:
		ship_type = FCWTypes.ShipType.FRIGATE

	var FCWOrbital = load("res://scripts/first_contact_war/fcw_orbital.gd")

	# Draw route preview for each zone
	for zone_id in FCWTypes.ZoneId.values():
		if zone_id == origin_zone:
			continue  # Skip origin zone

		var zone = _state.zones.get(zone_id, {})
		if zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue  # Skip fallen zones

		var zone_pos = _get_zone_pixel_pos(zone_id) + offset
		var zone_size = ZONE_SIZES.get(zone_id, 20.0)

		# Get fastest route summary
		var routes = FCWOrbital.get_route_summary(origin_zone, zone_id, game_time, ship_type)
		if routes.is_empty():
			continue

		# Get fastest and stealthiest options
		var fastest = routes[0]  # Already sorted by travel time
		var stealthiest = routes[0]
		for route in routes:
			if route.exposure_time < stealthiest.exposure_time:
				stealthiest = route

		# Calculate display position (below zone)
		var preview_pos = zone_pos + Vector2(-40, zone_size + 15)

		# Draw preview background
		var preview_width = 85.0
		var preview_height = 32.0
		var bg_rect = Rect2(preview_pos, Vector2(preview_width, preview_height))

		# Highlight if this zone is hovered
		var is_hovered = _hovered_zone == zone_id
		var bg_alpha = 0.85 if is_hovered else 0.7
		var border_color = Color(0.4, 0.8, 1.0, 0.8) if is_hovered else Color(0.3, 0.5, 0.7, 0.5)

		draw_rect(bg_rect, Color(0.02, 0.05, 0.1, bg_alpha))
		draw_rect(bg_rect, border_color, false, 1.5 if is_hovered else 1.0)

		# Draw connection line from entity to zone (faint)
		var entity_pos = _get_entity_screen_pos(entity, game_time) + offset
		var line_alpha = 0.4 if is_hovered else 0.15
		draw_line(entity_pos, zone_pos, Color(0.3, 0.6, 1.0, line_alpha), 1.0)

		# Format travel time
		var time_str = FCWOrbital.format_travel_time(fastest.travel_time)

		# Calculate detection risk
		var exposure_pct = int(stealthiest.exposure_time / maxf(stealthiest.travel_time, 0.1) * 100)
		var risk_str: String
		var risk_color: Color
		if exposure_pct < 20:
			risk_str = "LOW"
			risk_color = Color(0.4, 0.9, 0.4)
		elif exposure_pct < 50:
			risk_str = "MED"
			risk_color = Color(1.0, 0.8, 0.3)
		else:
			risk_str = "HIGH"
			risk_color = Color(1.0, 0.4, 0.3)

		# Draw fastest time
		var time_pos = preview_pos + Vector2(5, 12)
		draw_string(font, time_pos, time_str, HORIZONTAL_ALIGNMENT_LEFT, 50, 9, Color(0.8, 0.9, 1.0))

		# Draw detection risk
		var risk_pos = preview_pos + Vector2(5, 25)
		draw_string(font, risk_pos, "Risk: ", HORIZONTAL_ALIGNMENT_LEFT, 30, 8, Color(0.6, 0.6, 0.7))
		draw_string(font, risk_pos + Vector2(28, 0), risk_str, HORIZONTAL_ALIGNMENT_LEFT, 30, 8, risk_color)

		# If hovered, show "CLICK" prompt
		if is_hovered:
			var click_pos = preview_pos + Vector2(preview_width + 5, 18)
			var pulse = sin(_global_time * 5.0) * 0.3 + 0.7
			draw_string(font, click_pos, "CLICK", HORIZONTAL_ALIGNMENT_LEFT, 40, 9, Color(0.3, 1.0, 0.8, pulse))

## Draw capital ship callout with line and name label
func _draw_capital_ship_callout(ship_pos: Vector2, entity: Dictionary, ship_size: float, base_color: Color, is_selected: bool) -> void:
	var font = ThemeDB.fallback_font
	var ship_name = entity.get("name", "UNN Fleet")
	var combat_power = entity.get("combat_power", 0)

	# Determine callout direction based on position on screen to avoid overlaps
	var callout_angle: float
	var screen_center = size * 0.5
	var to_center = (screen_center - ship_pos).normalized()
	# Point callout away from center
	callout_angle = (-to_center).angle()

	# Callout line length and label offset
	var line_length = 40.0 if not is_selected else 50.0
	var callout_end = ship_pos + Vector2(cos(callout_angle), sin(callout_angle)) * line_length

	# Colors - brighter when selected
	var line_color = base_color.lightened(0.3) if is_selected else base_color.darkened(0.1)
	var label_color = Color(0.9, 0.95, 1.0) if is_selected else Color(0.7, 0.8, 0.9)
	var line_width = 2.0 if is_selected else 1.0
	line_color.a = 0.9 if is_selected else 0.6

	# Draw callout line
	draw_line(ship_pos + Vector2(cos(callout_angle), sin(callout_angle)) * (ship_size + 2), callout_end, line_color, line_width)

	# Draw small circle at line end
	draw_circle(callout_end, 3.0, line_color)

	# Label position - offset from line end
	var label_offset = Vector2(8, 4) if callout_angle > -PI/2 and callout_angle < PI/2 else Vector2(-100, 4)
	var alignment = HORIZONTAL_ALIGNMENT_LEFT if callout_angle > -PI/2 and callout_angle < PI/2 else HORIZONTAL_ALIGNMENT_RIGHT

	# Draw ship name
	var name_pos = callout_end + label_offset
	draw_string(font, name_pos, ship_name, alignment, 120, 10, label_color)

	# Show stacked indicator if multiple ships at same location (only for selected)
	var extra_offset = 0.0
	if is_selected and _entities_at_click.size() > 1:
		var stack_str = "[%d/%d]" % [_entity_cycle_index + 1, _entities_at_click.size()]
		var stack_pos = name_pos + Vector2(0, 11)
		var pulse = sin(_global_time * 3.0) * 0.2 + 0.8
		draw_string(font, stack_pos, stack_str + " CLICK TO CYCLE", alignment, 140, 8, Color(0.3, 0.9, 1.0, pulse))
		extra_offset = 11.0

	# Draw combat power below name
	var power_str = "Power: %d" % combat_power
	var power_pos = name_pos + Vector2(0, 12 + extra_offset)
	draw_string(font, power_pos, power_str, alignment, 80, 8, label_color.darkened(0.2))

	# Draw status indicator
	var status_str: String
	var status_color: Color
	match entity.movement_state:
		FCWTypes.MovementState.ORBITING:
			status_str = "STATIONED"
			status_color = Color(0.5, 0.8, 0.5)
		FCWTypes.MovementState.BURNING:
			status_str = "IN TRANSIT"
			status_color = Color(1.0, 0.7, 0.3)
		FCWTypes.MovementState.COASTING:
			status_str = "COASTING"
			status_color = Color(0.6, 0.7, 0.8)
		_:
			status_str = ""
			status_color = Color.WHITE

	# Calculate status position (always needed for instruction below)
	var status_pos = power_pos + Vector2(0, 11)

	if status_str != "":
		draw_string(font, status_pos, status_str, alignment, 80, 8, status_color)

	# If selected, draw destination instruction with controls hint
	if is_selected and _route_selection_mode and not _route_options_visible:
		var instr_pos = status_pos + Vector2(0, 14) if status_str != "" else power_pos + Vector2(0, 14)
		var pulse = sin(_global_time * 4.0) * 0.3 + 0.7
		# Main instruction
		draw_string(font, instr_pos, "L-CLICK: STEALTH", alignment, 100, 9, Color(0.3, 0.9, 1.0, pulse))
		# Secondary hint
		var hint_pos = instr_pos + Vector2(0, 11)
		draw_string(font, hint_pos, "R-CLICK: OPTIONS", alignment, 100, 8, Color(0.5, 0.7, 0.8, pulse * 0.7))

## Draw route options popup near destination zone
func _draw_route_options_popup() -> void:
	if _route_options.is_empty() or _route_options_zone < 0:
		return

	var font = ThemeDB.fallback_font
	var popup_pos = _get_route_options_popup_pos()
	var popup_width = 250.0
	var option_height = 35.0
	var header_height = 30.0
	var popup_height = header_height + option_height * _route_options.size() + 10

	# Draw connection line from selected entity to popup
	if _selected_entity_id != "":
		var entity = _get_entity_by_id(_selected_entity_id)
		if not entity.is_empty():
			var game_time = _state.get("game_time", 0.0)
			var entity_pos = _get_entity_screen_pos(entity, game_time)
			var zone_pos = _get_zone_pixel_pos(_route_options_zone)
			# Line from entity to destination zone
			draw_line(entity_pos, zone_pos, Color(0.3, 0.7, 1.0, 0.5), 2.0)

	# Popup background
	var bg_rect = Rect2(popup_pos, Vector2(popup_width, popup_height))
	draw_rect(bg_rect, Color(0.03, 0.06, 0.12, 0.95))
	draw_rect(bg_rect, Color(0.3, 0.6, 0.9, 0.6), false, 2.0)

	# Header - destination name
	var dest_name = FCWTypes.get_zone_name(_route_options_zone)
	draw_string(font, popup_pos + Vector2(10, 18), "ROUTE TO " + dest_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, popup_width - 20, 11, Color(0.7, 0.9, 1.0))

	# Draw each route option
	for i in range(_route_options.size()):
		var option = _route_options[i]
		var option_y = popup_pos.y + header_height + i * option_height

		# Option background (highlight on hover)
		var option_rect = Rect2(popup_pos.x + 5, option_y, popup_width - 10, option_height - 5)
		var is_hovered = option_rect.has_point(get_local_mouse_position())

		if is_hovered:
			draw_rect(option_rect, Color(0.2, 0.4, 0.7, 0.4))
		else:
			draw_rect(option_rect, Color(0.1, 0.15, 0.25, 0.3))

		# Route type icon and name
		var route_type = option.get("type", "direct")
		var route_name: String
		var route_color: Color

		match route_type:
			"direct":
				route_name = "FAST BURN"
				route_color = Color(1.0, 0.5, 0.3)  # Orange - fast but visible
			"coast":
				route_name = "STEALTH COAST"
				route_color = Color(0.5, 0.8, 0.5)  # Green - slow but hidden
			"gravity_assist":
				route_name = "GRAVITY ASSIST"
				route_color = Color(0.7, 0.7, 1.0)  # Blue - balanced
			_:
				route_name = route_type.to_upper()
				route_color = Color.WHITE

		var name_pos = popup_pos + Vector2(15, header_height + 12 + i * option_height)
		draw_string(font, name_pos, route_name, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, route_color)

		# Travel time
		var travel_weeks = option.get("travel_time", 0.0)
		var FCWOrbital = load("res://scripts/first_contact_war/fcw_orbital.gd")
		var time_str = FCWOrbital.format_travel_time(travel_weeks)
		var time_pos = popup_pos + Vector2(130, header_height + 12 + i * option_height)
		draw_string(font, time_pos, time_str, HORIZONTAL_ALIGNMENT_LEFT, 60, 9, Color(0.8, 0.8, 0.8))

		# Detection exposure
		var exposure = option.get("exposure_time", 0.0)
		var exposure_pct = int(exposure / maxf(travel_weeks, 0.1) * 100)
		var exposure_str = "%d%% vis" % exposure_pct
		var exposure_color = Color(0.5, 0.8, 0.5) if exposure_pct < 30 else (Color(1.0, 0.8, 0.3) if exposure_pct < 70 else Color(1.0, 0.4, 0.3))
		var exposure_pos = popup_pos + Vector2(195, header_height + 12 + i * option_height)
		draw_string(font, exposure_pos, exposure_str, HORIZONTAL_ALIGNMENT_LEFT, 50, 9, exposure_color)

	# Instructions at bottom
	var instr_pos = popup_pos + Vector2(10, popup_height - 5)
	draw_string(font, instr_pos, "Click to select • Right-click to cancel", HORIZONTAL_ALIGNMENT_LEFT, popup_width - 20, 8, Color(0.5, 0.6, 0.7))

# ============================================================================
# PUBLIC API
# ============================================================================

func update_state(state: Dictionary, zone_defenses: Dictionary, fleets_in_transit: Array = []) -> void:
	# Store full state for entity system access
	_state = state

	_zones = {}
	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		_zones[zone_id] = {
			"status": zone.status,
			"population": zone.population,
			"defense": zone_defenses.get(zone_id, 0),
			"assigned_fleet": zone.assigned_fleet.duplicate()
		}

	_fleet_assignments = {}
	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		if not zone.assigned_fleet.is_empty():
			_fleet_assignments[zone_id] = zone.assigned_fleet.duplicate()

	# Store fleets in transit for visualization
	_fleets_in_transit = fleets_in_transit

	# Update fleet tracking for roster display
	_current_fleet = state.get("fleet", {}).duplicate()
	if _starting_fleet.is_empty() and not _current_fleet.is_empty():
		# Initialize starting fleet on first update
		_starting_fleet = _current_fleet.duplicate()
		_init_capital_ship_grid()
	elif not _current_fleet.is_empty():
		# Update capital ship states based on losses
		_update_capital_ship_states()

	# Update herald from entity system
	var new_target = state.herald_attack_target
	var herald_entity = FCWTypes.get_herald_entity(state)

	# Check if target changed (zone fell and Herald is moving to new target)
	if new_target != _herald_target_zone:
		_herald_target_zone = new_target

		# Clear old attack waves targeting the fallen zone (prevent weird visuals)
		var i = 0
		while i < _attack_waves.size():
			if _attack_waves[i].target_zone == _herald_current_zone:
				_attack_waves.remove_at(i)
			else:
				i += 1

		# Clear herald ships targeting old zone
		_herald_ships.clear()

	# Always use herald_current_zone from state (this is what the game logic updates)
	# The entity system is not currently synced with Herald movement
	var new_current_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var new_transit = state.get("herald_transit", {})
	_herald_current_zone = new_current_zone
	_herald_transit = new_transit.duplicate()

	# Update positions based on transit state
	if _initialized:
		if not _herald_transit.is_empty():
			_herald_start_position = _get_zone_pixel_pos(_herald_transit.from_zone)
			_herald_target_position = _get_zone_pixel_pos(_herald_transit.to_zone)
			# Calculate transit progress for smooth interpolation
			var total = _herald_transit.get("total_turns", 1)
			var remaining = _herald_transit.get("turns_remaining", 0)
			var progress = 1.0 - (float(remaining) / maxf(float(total), 1.0))
			_herald_travel_progress = clampf(progress, 0.0, 1.0)
			_herald_position = _herald_start_position.lerp(_herald_target_position, _herald_travel_progress)
		else:
			var current_pos = _get_zone_pixel_pos(_herald_current_zone)
			_herald_position = current_pos
			_herald_start_position = current_pos
			_herald_target_position = current_pos
			_herald_travel_progress = 1.0

	_herald_strength = state.herald_strength

	# Track turn and herald visibility
	_current_turn = state.turn
	# Herald becomes visible on week 3 ("Unidentified objects approaching")
	_herald_visible = _current_turn >= 3

	queue_redraw()

func set_selected_zone(zone_id: int) -> void:
	_selected_zone = zone_id
	queue_redraw()

func set_time_progress(progress: float, fleets_in_transit: Array, herald_transit: Dictionary = {}) -> void:
	## DEPRECATED: Use set_tick_progress() instead
	## Called continuously to update time-based animations
	## progress: 0.0 to 1.0 representing progress through current week
	## fleets_in_transit: current fleet transit data for smooth animation
	## herald_transit: current Herald transit data
	_week_progress = progress
	_fleets_in_transit = fleets_in_transit

	# Update Herald position based on transit progress
	if not herald_transit.is_empty() and herald_transit.has("total_turns"):
		# Herald is in transit - interpolate position smoothly
		var total_travel = herald_transit.total_turns
		var weeks_remaining = herald_transit.turns_remaining
		var weeks_elapsed = total_travel - weeks_remaining

		# Calculate continuous progress: (completed weeks + current week progress) / total weeks
		var continuous_progress = (float(weeks_elapsed) + progress) / maxf(float(total_travel), 1.0)
		continuous_progress = clampf(continuous_progress, 0.0, 1.0)

		# Store old position for trail spawning
		var old_pos = _herald_position

		# Interpolate Herald position
		_herald_position = _herald_start_position.lerp(_herald_target_position, continuous_progress)
		_herald_travel_progress = continuous_progress

		# Spawn trail particles during movement
		if continuous_progress < 1.0 and old_pos.distance_to(_herald_position) > 0.5:
			_spawn_herald_trail(old_pos)
	elif _herald_transit.is_empty():
		# Herald is stationary - ensure position is at current zone
		_herald_travel_progress = 1.0

	queue_redraw()

# Snapshot data for interpolation
var _prev_entity_positions: Dictionary = {}
var _prev_zone_positions: Dictionary = {}
var _tick_progress: float = 0.0

func set_tick_progress(progress: float, prev_entity_positions: Dictionary, prev_zone_positions: Dictionary) -> void:
	## NEW TIME SYSTEM: Update interpolation state for smooth animation between discrete ticks
	##
	## progress: 0.0 to 1.0 representing progress toward the next hour tick
	## prev_entity_positions: entity_id -> Vector2 positions at start of current tick
	## prev_zone_positions: zone_id -> Vector2 positions at start of current tick
	##
	## All entity positions are interpolated between prev_position and current_position
	## based on the tick progress.
	_tick_progress = progress
	_prev_entity_positions = prev_entity_positions
	_prev_zone_positions = prev_zone_positions

	# Also update legacy _week_progress for any code that still uses it
	# Convert hourly progress to weekly context (rough approximation)
	_week_progress = progress

	queue_redraw()

func get_interpolated_entity_pos(entity_id: String, current_pos: Vector2) -> Vector2:
	## Get interpolated position for an entity
	var prev_pos = _prev_entity_positions.get(entity_id, current_pos)
	return prev_pos.lerp(current_pos, _tick_progress)

func get_interpolated_zone_pos(zone_id: int, current_pos: Vector2) -> Vector2:
	## Get interpolated position for a zone (orbital bodies)
	var prev_pos = _prev_zone_positions.get(zone_id, current_pos)
	return prev_pos.lerp(current_pos, _tick_progress)

func set_attacking(is_attacking: bool) -> void:
	_is_attacking = is_attacking
	if is_attacking:
		_attack_flash_timer = 0.0
	queue_redraw()

func set_paused(paused: bool) -> void:
	## Set pause state - when paused, all ship movement freezes
	_is_paused = paused

func set_speed(multiplier: float) -> void:
	## Set game speed multiplier - affects all visual animations
	## 0.5 = slow, 1.0 = normal, 4.0 = fast, 12.0 = very fast
	_speed_multiplier = multiplier

func get_selected_zone() -> int:
	return _selected_zone

func spawn_herald_attack_wave(target_zone: int, wave_size: int = 5, target_staging_index: int = -1) -> void:
	## Spawn a wave of Herald attack ships targeting a zone
	## If target_staging_index >= 0, targets a specific staging area
	var wave = AttackWave.new()
	wave.target_zone = target_zone
	wave.wave_size = wave_size
	wave.spawn_timer = 0.0
	wave.ships_spawned = 0
	wave.spawn_position = _herald_position  # Store where herald is NOW

	# Optionally target a staging area
	var staging_list = STAGING_AREAS.get(target_zone, [])
	if target_staging_index >= 0 and target_staging_index < staging_list.size():
		wave.target_staging = staging_list[target_staging_index]
	elif staging_list.size() > 0 and randf() > 0.3:
		# Random chance to target a staging area
		wave.target_staging = staging_list[randi() % staging_list.size()]

	_attack_waves.append(wave)

	# Red warp flash at herald
	_warp_flashes.append({"pos": _herald_position, "life": 1.0})

func spawn_skirmish(zone_id: int, staging_index: int = -1, is_herald_attack: bool = true, ship_count: int = 10) -> void:
	## Start a skirmish battle at a zone or staging area
	var skirmish = Skirmish.new()
	skirmish.zone_id = zone_id
	skirmish.is_herald_attack = is_herald_attack
	skirmish.ships_engaged = ship_count
	skirmish.intensity = 1.0

	var zone_pos = _get_zone_pixel_pos(zone_id)

	# Position at staging area if specified
	var staging_list = STAGING_AREAS.get(zone_id, [])
	if staging_index >= 0 and staging_index < staging_list.size():
		var staging = staging_list[staging_index]
		skirmish.pos = zone_pos + staging.offset
		skirmish.staging_name = staging.name
		skirmish.radius = staging.size + 20
	elif staging_list.size() > 0:
		# Random staging area
		var staging = staging_list[randi() % staging_list.size()]
		skirmish.pos = zone_pos + staging.offset
		skirmish.staging_name = staging.name
		skirmish.radius = staging.size + 20
	else:
		# Near the zone
		skirmish.pos = zone_pos + Vector2(ZONE_SIZES.get(zone_id, 20.0) + 30, 0)
		skirmish.radius = 35

	_skirmishes.append(skirmish)

func spawn_mass_attack(target_zone: int, total_ships: int = 20) -> void:
	## Spawn a massive Herald assault with multiple waves
	var waves = ceili(total_ships / 6.0)
	for i in range(waves):
		var wave_size = mini(6, total_ships - i * 6)
		if wave_size > 0:
			# Stagger wave spawns
			var wave = AttackWave.new()
			wave.target_zone = target_zone
			wave.wave_size = wave_size
			wave.spawn_timer = i * 0.8  # Delay between waves
			wave.ships_spawned = 0
			wave.spawn_position = _herald_position  # Store where herald is NOW

			# Distribute among staging areas
			var staging_list = STAGING_AREAS.get(target_zone, [])
			if staging_list.size() > 0:
				wave.target_staging = staging_list[i % staging_list.size()]

			_attack_waves.append(wave)

	# Big warp flash
	_warp_flashes.append({"pos": _herald_position, "life": 1.0})
	_screen_shake_intensity = maxf(_screen_shake_intensity, 8.0)
	_danger_pulse = 0.8

func get_staging_area_position(zone_id: int, staging_index: int) -> Vector2:
	## Get world position of a staging area
	var zone_pos = _get_zone_pixel_pos(zone_id)
	var staging_list = STAGING_AREAS.get(zone_id, [])
	if staging_index >= 0 and staging_index < staging_list.size():
		return zone_pos + staging_list[staging_index].offset
	return zone_pos

func get_staging_areas_for_zone(zone_id: int) -> Array:
	## Return list of staging areas for a zone
	return STAGING_AREAS.get(zone_id, [])

# ============================================================================
# NARRATIVE STATE MANAGEMENT
# ============================================================================

func set_narrative_state(state: int) -> void:
	## Set the current narrative mood: 0=peace, 1=tension, 2=combat, 3=desperate
	_last_narrative_state = _narrative_state
	_narrative_state = state

	# Trigger transmissions on state changes
	if state != _last_narrative_state:
		_mood_transition_timer = 1.0  # Brief transition effect

		match state:
			0:  # Peace
				if _last_narrative_state > 0:
					var victory = TRANSMISSIONS_VICTORY[randi() % TRANSMISSIONS_VICTORY.size()]
					spawn_transmission(victory.sender, victory.text, 1)
			1:  # Tension
				var tension = TRANSMISSIONS_TENSION[randi() % TRANSMISSIONS_TENSION.size()]
				spawn_transmission(tension.sender, tension.text, 1)
			2:  # Combat
				var combat = TRANSMISSIONS_COMBAT[randi() % TRANSMISSIONS_COMBAT.size()]
				spawn_transmission(combat.sender, combat.text, 2)
			3:  # Desperate
				var desperate = TRANSMISSIONS_DESPERATE[randi() % TRANSMISSIONS_DESPERATE.size()]
				spawn_transmission(desperate.sender, desperate.text, 3)

func get_narrative_state() -> int:
	return _narrative_state

func trigger_zone_loss_narrative(zone_id: int, lives_lost: int) -> void:
	## Called when a zone falls - triggers DEFIANT narrative
	## Key tone: Focus on courage and sacrifice, not horror. What did they BUY us?
	_zones_lost_this_session += 1

	var zone_name = FCWTypes.get_zone_name(zone_id)
	var pop_str = FCWTypes.format_population(lives_lost)

	# Defiant zone-specific messages - honor the sacrifice, emphasize what it achieved
	match zone_id:
		FCWTypes.ZoneId.KUIPER:
			spawn_transmission(
				"Kuiper Command",
				"Kuiper Station has fallen. They held for three days. Three days of evacuation ships escaping. Their sacrifice was not in vain.",
				2
			)
		FCWTypes.ZoneId.SATURN:
			spawn_transmission(
				"Titan Defense",
				"Saturn sector lost. %s souls. The Titan garrison's last transmission: 'We bought you time. Use it.' We will." % pop_str,
				2
			)
		FCWTypes.ZoneId.JUPITER:
			spawn_transmission(
				"Admiral Chen",
				"Jupiter has fallen. The fleet held until the last evac transport cleared Ganymede. Every soul on those ships owes their lives to Jupiter's stand.",
				2
			)
		FCWTypes.ZoneId.ASTEROID_BELT:
			spawn_transmission(
				"Belt Command",
				"The Belt has fallen. Miners aren't soldiers, but they fought like legends. Ceres bought us another week. That's a million more lives saved.",
				2
			)
		FCWTypes.ZoneId.MARS:
			spawn_transmission(
				"Mars Final",
				"Mars... the red planet bleeds. %s defending their homes. Their last stand gave Earth one more day. One more day of hope." % pop_str,
				3
			)
		FCWTypes.ZoneId.EARTH:
			# Earth falling is handled by endgame sequence - but have a defiant message anyway
			spawn_transmission(
				"Earth Final",
				"This is Earth's last broadcast. Not a surrender. A testament. Humanity fought. Humanity ENDURED. Find us among the stars.",
				3
			)

	# Follow-up defiant message after delay
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		# Defiant follow-up that focuses on hope, not despair
		var defiant_followups = [
			{"sender": "Fleet Command", "text": "All stations: The sacrifice of %s will be remembered. The evacuation continues." % zone_name},
			{"sender": "Admiral", "text": "%s held longer than anyone expected. That's who we are. That's why we'll survive." % zone_name},
			{"sender": "Evac Fleet", "text": "Dedicating Colony Ship '%s Memorial' in honor of those who stood." % zone_name},
		]
		var followup = defiant_followups[randi() % defiant_followups.size()]
		spawn_transmission(followup.sender, followup.text, 1)

func trigger_defense_success_narrative(zone_id: int) -> void:
	## Called when a zone successfully defends
	var zone_name = FCWTypes.get_zone_name(zone_id)

	var victory = TRANSMISSIONS_VICTORY[randi() % TRANSMISSIONS_VICTORY.size()]
	spawn_transmission(victory.sender, "%s holds! %s" % [zone_name, victory.text], 1)

func trigger_evacuation_milestone(total_evacuated: int) -> void:
	## Called when evacuation reaches a milestone - humanizing the numbers
	## Each milestone tells a story about WHO we're saving, not just how many
	_total_evacuated = total_evacuated

	# Milestone story beats - ordered from lowest to highest so we trigger each once
	# These are designed to create emotional connection to the evacuation effort

	# 1M - The first milestone. The pioneers.
	if total_evacuated >= 1_000_000 and not _milestone_flags.get("1M", false):
		_milestone_flags["1M"] = true
		spawn_transmission(
			"CS Svalbard",
			"The first million. The Vault team is aboard. Seeds of every crop humanity ever grew. We carry tomorrow.",
			0  # High priority - important milestone
		)

	# 5M - Artists and culture bearers
	if total_evacuated >= 5_000_000 and not _milestone_flags.get("5M", false):
		_milestone_flags["5M"] = true
		spawn_transmission(
			"CS Hope",
			"Colony Ship Hope departing with the world's artists, musicians, poets. Humanity's soul sails with us.",
			1
		)

	# 10M - The children
	if total_evacuated >= 10_000_000 and not _milestone_flags.get("10M", false):
		_milestone_flags["10M"] = true
		spawn_transmission(
			"CS Little Star",
			"Ten million. The children. We prioritized the children. They'll grow up among the stars.",
			0
		)

	# 25M - Scientists and dreamers
	if total_evacuated >= 25_000_000 and not _milestone_flags.get("25M", false):
		_milestone_flags["25M"] = true
		spawn_transmission(
			"CS Discovery",
			"25 million souls. Enough scientists to understand the universe. Enough dreamers to try.",
			1
		)

	# 40M - HEROIC threshold
	if total_evacuated >= 40_000_000 and not _milestone_flags.get("40M", false):
		_milestone_flags["40M"] = true
		spawn_transmission(
			"Fleet Command",
			"HEROIC THRESHOLD REACHED. 40 million evacuated. History will remember this as victory. Don't stop.",
			0
		)

	# 60M - Beyond hope
	if total_evacuated >= 60_000_000 and not _milestone_flags.get("60M", false):
		_milestone_flags["60M"] = true
		spawn_transmission(
			"Admiral Chen",
			"60 million. More than we dared hope. More than we deserved. Every soul is a miracle.",
			1
		)

	# 80M - LEGENDARY
	if total_evacuated >= 80_000_000 and not _milestone_flags.get("80M", false):
		_milestone_flags["80M"] = true
		spawn_transmission(
			"All Channels",
			"LEGENDARY. 80 million humans will survive. Against all odds, against the void itself, humanity endures.",
			0
		)

func spawn_custom_transmission(sender: String, text: String, priority: int = 1) -> void:
	## Public API to spawn custom transmissions from game logic
	spawn_transmission(sender, text, priority)

# ============================================================================
# ZOOM CONTROL - Multi-Level View System
# ============================================================================

func set_zoom_level(level: int, focus_zone: int = -1) -> void:
	## Set the zoom level: ZoomLevel.GALAXY, ZoomLevel.SYSTEM, or ZoomLevel.PLANET
	## For PLANET view, focus_zone specifies which zone to focus on
	if level == _zoom_level and (level != ZoomLevel.PLANET or focus_zone == _zoom_focus_zone):
		return  # No change

	_zoom_target = level
	_zoom_transition = 0.0

	if level == ZoomLevel.PLANET:
		_zoom_focus_zone = focus_zone if focus_zone >= 0 else _herald_target_zone

func get_zoom_level() -> int:
	return _zoom_level

func get_zoom_focus_zone() -> int:
	return _zoom_focus_zone

func zoom_to_galaxy() -> void:
	## Zoom out to galaxy view - "Among the stars, one light flickers"
	set_zoom_level(ZoomLevel.GALAXY)
	spawn_transmission("Perspective", "Among the billions of stars... one light flickers.", 0)

func zoom_to_system() -> void:
	## Return to system view - strategic overview
	set_zoom_level(ZoomLevel.SYSTEM)

func zoom_to_planet(zone_id: int) -> void:
	## Zoom into a specific planet/zone for intense focus
	set_zoom_level(ZoomLevel.PLANET, zone_id)
	var zone_name = FCWTypes.get_zone_name(zone_id)
	spawn_transmission("Focus", "Attention: %s sector." % zone_name, 1)

func zoom_to_battle(zone_id: int = -1) -> void:
	## Zoom to where combat is happening
	var target = zone_id if zone_id >= 0 else _herald_target_zone
	zoom_to_planet(target)

func is_zooming() -> bool:
	## Returns true if currently transitioning between zoom levels
	return _zoom_transition < 1.0

# ============================================================================
# CINEMATIC PACING - AI-Driven Camera Control
# ============================================================================

func cinematic_update(delta: float) -> void:
	## Called by fcw_main to let the camera make cinematic decisions
	## This implements AI-driven dramatic pacing
	## NOTE: Planet-level zoom is handled by the FCWPlanetView picture-in-picture window

	# Don't make changes during a zoom transition
	if is_zooming():
		return

	# Pacing rules based on narrative state:
	# Solar map stays at SYSTEM level most of the time
	# Planet closeups are shown via FCWPlanetView window (handled by fcw_main)
	match _narrative_state:
		0:  # Peace - occasionally pull to galaxy for scale
			if _zoom_level == ZoomLevel.SYSTEM and randf() < delta * 0.005:  # ~1 in 200 frames
				zoom_to_galaxy()
			elif _zoom_level == ZoomLevel.GALAXY and randf() < delta * 0.02:  # Return faster
				zoom_to_system()

		1:  # Tension - stay at system level, drift toward threatened zone
			if _zoom_level != ZoomLevel.SYSTEM:
				zoom_to_system()

		2:  # Combat - stay at system to see the whole battle
			# Planet closeup is shown via FCWPlanetView window
			if _zoom_level != ZoomLevel.SYSTEM:
				zoom_to_system()

		3:  # Desperate - stay at system for strategic overview
			# Rapid cuts between zones could be disorienting, stay steady
			if _zoom_level != ZoomLevel.SYSTEM:
				zoom_to_system()

func cinematic_zone_fallen(zone_id: int) -> void:
	## Called when a zone falls - dramatic camera response
	# Stay at system level, the FCWPlanetView handles the closeup
	# The zone destruction effects will be visible on the main map
	if _zoom_level != ZoomLevel.SYSTEM:
		zoom_to_system()

func cinematic_victory_moment() -> void:
	## Called when a defense succeeds - celebratory camera
	zoom_to_system()

func cinematic_game_over() -> void:
	## Called when the game ends - pull back to galaxy
	zoom_to_galaxy()

# ============================================================================
# ENTITY SYSTEM VISUALIZATION (Phase 6 - Movement as Core Mechanic)
# ============================================================================
# "Everything is Trajectory" - entities rendered at actual positions in AU
# "The Tyranny of Time" - trajectories show where ships will be
# "Detection & Signatures" - Herald observation zones visible

## Convert AU coordinates to screen pixels
## AU range: roughly -50 to +50 for the solar system
func _au_to_screen_pos(au_pos: Vector2) -> Vector2:
	# Scale factor: map ~100 AU range to screen width
	var center = size * 0.5
	var scale_factor = size.x / 100.0  # 100 AU across screen
	return center + au_pos * scale_factor

## Draw all entities from the new unified entity system
func _draw_entities(offset: Vector2) -> void:
	var entities = _state.get("entities", [])
	var game_time = _state.get("game_time", 0.0)

	for entity in entities:
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		# Skip Herald entity - drawn by _draw_herald for detailed visuals
		if entity.get("id") == FCWTypes.HERALD_ENTITY_ID:
			continue

		# Calculate screen position based on entity's origin/destination zones
		var screen_pos: Vector2
		var origin_zone = entity.get("origin", -1)
		var dest_zone = entity.get("destination", -1)

		if entity.movement_state == FCWTypes.MovementState.ORBITING and origin_zone >= 0:
			# Orbiting at origin zone
			screen_pos = _get_zone_pixel_pos(origin_zone) + offset
		elif dest_zone >= 0 and origin_zone >= 0:
			# In transit - interpolate between zones
			var origin_pos = _get_zone_pixel_pos(origin_zone)
			var dest_pos = _get_zone_pixel_pos(dest_zone)

			# Calculate travel progress from AU positions
			var origin_au = FCWTypes.get_zone_position(origin_zone, game_time)
			var dest_au = FCWTypes.get_zone_position(dest_zone, game_time)
			var total_dist = origin_au.distance_to(dest_au)
			var current_dist = entity.position.distance_to(dest_au)
			var travel_progress = clampf(1.0 - (current_dist / maxf(total_dist, 0.1)), 0.0, 1.0)

			screen_pos = origin_pos.lerp(dest_pos, travel_progress) + offset
		else:
			# Fallback to AU conversion
			screen_pos = _au_to_screen_pos(entity.position) + offset

		# Determine color and size based on entity type and faction
		var entity_color: Color
		var entity_size: float = 4.0

		if entity.faction == FCWTypes.Faction.HERALD:
			entity_color = Color(1.0, 0.2, 0.3)  # Red for Herald
			entity_size = 6.0 if entity.get("is_drone", false) else 8.0
		else:
			match entity.entity_type:
				FCWTypes.EntityType.WARSHIP:
					entity_color = Color(0.3, 0.7, 1.0)  # Blue for warships
					entity_size = 5.0 + entity.combat_power * 0.02
				FCWTypes.EntityType.TRANSPORT:
					entity_color = Color(0.2, 0.9, 0.4)  # Green for transports
					entity_size = 4.0
				FCWTypes.EntityType.WEAPON:
					entity_color = Color(1.0, 0.8, 0.2)  # Yellow for weapons
					entity_size = 3.0
				_:
					entity_color = Color.WHITE
					entity_size = 4.0

		# Movement state visual effects
		match entity.movement_state:
			FCWTypes.MovementState.BURNING:
				# Engine glow - "burning ships are visible"
				var pulse = sin(_global_time * 6.0) * 0.3 + 0.7
				var engine_size = entity_size * 2.0 * pulse
				draw_circle(screen_pos, engine_size, Color(1.0, 0.6, 0.2, 0.4 * pulse))
				draw_circle(screen_pos, engine_size * 0.6, Color(1.0, 0.9, 0.5, 0.6 * pulse))

				# Draw engine trail
				var trail_dir = -entity.velocity.normalized() if entity.velocity.length() > 0.01 else Vector2.DOWN
				var trail_end = screen_pos + trail_dir * entity_size * 3.0
				draw_line(screen_pos, trail_end, Color(1.0, 0.5, 0.1, 0.6), 2.0)

			FCWTypes.MovementState.COASTING:
				# Dim, stealthy appearance - "coasting ships are nearly invisible"
				entity_color = entity_color.darkened(0.3)
				entity_color.a = 0.7

			FCWTypes.MovementState.ORBITING:
				# Subtle station-keeping indicator
				draw_arc(screen_pos, entity_size + 3, 0, TAU, 16, entity_color.darkened(0.4), 1.0)

		# Draw entity body
		draw_circle(screen_pos, entity_size, entity_color)

		# === SELECTION AND HOVER HIGHLIGHTS ===
		var entity_id = entity.get("id", "")

		# Hover highlight
		if entity_id == _hovered_entity_id and entity_id != _selected_entity_id:
			var hover_pulse = sin(_global_time * 4.0) * 0.2 + 0.8
			draw_arc(screen_pos, entity_size + 6, 0, TAU, 24, Color(0.8, 0.9, 1.0, 0.5 * hover_pulse), 2.0)

		# Selection highlight (stronger, with instructions)
		if entity_id == _selected_entity_id:
			var select_pulse = sin(_global_time * 3.0) * 0.3 + 0.7
			# Outer selection ring
			draw_arc(screen_pos, entity_size + 8, 0, TAU, 32, Color(0.3, 0.8, 1.0, select_pulse), 3.0)
			# Inner glow
			draw_circle(screen_pos, entity_size + 4, Color(0.3, 0.6, 1.0, 0.15))

			# Draw "Click destination" instruction if in route selection mode
			if _route_selection_mode and not _route_options_visible:
				var font = ThemeDB.fallback_font
				var instruction_pos = screen_pos + Vector2(0, entity_size + 20)
				draw_string(font, instruction_pos, "Click destination zone", HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(0.7, 0.9, 1.0, select_pulse))

		# Drone indicator
		if entity.get("is_drone", false):
			# Sharp triangular shape for drones
			var drone_pulse = sin(_global_time * 8.0) * 0.2 + 0.8
			draw_circle(screen_pos, entity_size * 0.6, Color(1.0, 0.3, 0.3, drone_pulse))

		# === CAPITAL SHIP CALLOUTS ===
		# Show callout line and name label for capital ships (Cruiser+)
		if entity.faction != FCWTypes.Faction.HERALD and entity.entity_type == FCWTypes.EntityType.WARSHIP:
			# Show callout for any named ship or combat_power >= 25 (Carrier/Cruiser/Dreadnought)
			if entity.get("name", "") != "" or entity.combat_power >= 25:
				_draw_capital_ship_callout(screen_pos, entity, entity_size, entity_color, entity_id == _selected_entity_id)

## Draw projected trajectories for entities
func _draw_entity_trajectories(offset: Vector2) -> void:
	var entities = _state.get("entities", [])
	var game_time = _state.get("game_time", 0.0)

	for entity in entities:
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue
		if entity.movement_state == FCWTypes.MovementState.ORBITING:
			continue  # Stationary entities don't need trajectories
		if entity.destination < 0:
			continue  # No destination set
		# Skip Herald - has its own visualization
		if entity.get("id") == FCWTypes.HERALD_ENTITY_ID:
			continue

		# Use zone-based positions for trajectories
		var origin_zone = entity.get("origin", -1)
		var dest_zone = entity.destination

		if origin_zone < 0 or dest_zone < 0:
			continue

		var origin_pos = _get_zone_pixel_pos(origin_zone)
		var dest_pos = _get_zone_pixel_pos(dest_zone)

		# Calculate current position along trajectory
		var origin_au = FCWTypes.get_zone_position(origin_zone, game_time)
		var dest_au = FCWTypes.get_zone_position(dest_zone, game_time)
		var total_dist = origin_au.distance_to(dest_au)
		var current_dist = entity.position.distance_to(dest_au)
		var travel_progress = clampf(1.0 - (current_dist / maxf(total_dist, 0.1)), 0.0, 1.0)

		var start_pos = origin_pos.lerp(dest_pos, travel_progress) + offset
		dest_pos = dest_pos + offset

		# Trajectory color based on faction
		var traj_color: Color
		if entity.faction == FCWTypes.Faction.HERALD:
			traj_color = Color(1.0, 0.2, 0.3, 0.4)
		else:
			traj_color = Color(0.4, 0.7, 1.0, 0.3)

		# Get route type from entity (default to "direct" if not set)
		var route_type = entity.get("route_type", "direct")

		# Calculate bezier control point based on route type
		var control_point = _calc_trajectory_control_point(start_pos, dest_pos, route_type, entity.get("waypoint_zone", -1))

		# Draw trajectory as animated bezier curve
		_draw_animated_bezier(start_pos, control_point, dest_pos, traj_color, 1.5)

		# Draw destination marker
		draw_arc(dest_pos, 8.0, 0, TAU, 16, traj_color, 1.0)

		# Show ETA at curve midpoint (use bezier midpoint for better placement)
		if entity.eta > 0 and entity.eta < 100:
			var eta_text = "%.1fw" % entity.eta
			var font = ThemeDB.fallback_font
			# Bezier midpoint: 0.25*p0 + 0.5*p1 + 0.25*p2
			var mid_pos = 0.25 * start_pos + 0.5 * control_point + 0.25 * dest_pos
			draw_string(font, mid_pos + Vector2(5, -5), eta_text, HORIZONTAL_ALIGNMENT_LEFT, 50, 10, traj_color)

## Draw Herald observation zone - clean circle showing detection radius
## Simplified: just radius circles + detection labels at zones
func _draw_herald_observation_zone(offset: Vector2) -> void:
	var screen_pos = _herald_position + offset

	# Get observation zone settings from Herald AI
	var game_time = _state.get("game_time", 0.0)
	var herald_au_pos = _get_herald_au_position(game_time)
	var obs = FCWHeraldAI.get_observation_zone(herald_au_pos)

	# Scale radii from AU to pixels
	var visual_scale = size.x / 80.0
	var outer_radius = obs.radius * visual_scale
	var drone_range = obs.drone_range * visual_scale

	# Subtle pulse for life
	var pulse = sin(_global_time * 1.2) * 0.15 + 0.85

	# Outer observation radius - clean arc with subtle fill
	var outer_color = Color(0.8, 0.2, 0.3, 0.08 * pulse)
	draw_circle(screen_pos, outer_radius * pulse, outer_color)
	draw_arc(screen_pos, outer_radius * pulse, 0, TAU, 64, Color(0.9, 0.3, 0.4, 0.3), 1.5)

	# Drone range - danger zone indicator
	var drone_color = Color(1.0, 0.2, 0.2, 0.2 * pulse)
	draw_arc(screen_pos, drone_range * pulse, 0, TAU, 48, drone_color, 2.0)

	# Detection labels at zones (the most useful info)
	_draw_zone_detection_labels(offset, herald_au_pos)

## Draw detection probability labels at each zone
func _draw_zone_detection_labels(offset: Vector2, herald_au_pos: Vector2) -> void:
	var font = ThemeDB.fallback_font
	var herald_intel = _state.get("herald_intel", {})
	var activity_zones = herald_intel.get("activity_zones", {})
	var known_routes = herald_intel.get("known_routes", {})
	var game_time = _state.get("game_time", 0.0)

	for zone_id in FCWTypes.ZoneId.values():
		var zone = _state.zones.get(zone_id, {})
		if zone.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue

		var zone_pos = _get_zone_pixel_pos(zone_id) + offset
		var zone_au_pos = FCWTypes.get_zone_position(zone_id, game_time)

		# Calculate detection probability for this zone
		var traffic_level = activity_zones.get(zone_id, 0.0)

		# Add traffic from connected routes
		for route_key in known_routes:
			var parts = route_key.split("_")
			if parts.size() == 2:
				var zone_a = int(parts[0])
				var zone_b = int(parts[1])
				if zone_a == zone_id or zone_b == zone_id:
					traffic_level = maxf(traffic_level, known_routes[route_key] * 0.5)

		# Use Herald AI's detection probability calculation
		var detection_prob = FCWHeraldAI.calc_detection_probability(zone_au_pos, herald_au_pos, false, traffic_level)

		# Only show label if there's meaningful detection risk
		if detection_prob < 0.001:
			continue

		# Format as percentage per day
		var percent_text: String
		if detection_prob >= 0.1:
			percent_text = "%.0f%%" % (detection_prob * 100)
		elif detection_prob >= 0.01:
			percent_text = "%.1f%%" % (detection_prob * 100)
		else:
			percent_text = "%.2f%%" % (detection_prob * 100)

		# Determine color based on danger level
		var label_color: Color
		var glow_color: Color
		if detection_prob >= 0.1:
			label_color = Color(1.0, 0.3, 0.3)  # Red - dangerous
			glow_color = Color(1.0, 0.2, 0.2, 0.3)
		elif detection_prob >= 0.05:
			label_color = Color(1.0, 0.6, 0.2)  # Orange - risky
			glow_color = Color(1.0, 0.5, 0.1, 0.2)
		elif detection_prob >= 0.01:
			label_color = Color(1.0, 1.0, 0.4)  # Yellow - caution
			glow_color = Color(1.0, 0.9, 0.2, 0.15)
		else:
			label_color = Color(0.5, 0.7, 0.5, 0.7)  # Dim green - safe
			glow_color = Color(0.3, 0.6, 0.3, 0.1)

		# Draw glow behind label
		var zone_size = ZONE_SIZES.get(zone_id, 20.0)
		var label_pos = zone_pos + Vector2(zone_size + 8, -zone_size - 5)

		# Pulsing effect for high danger
		if detection_prob >= 0.05:
			var pulse = sin(_global_time * 3.0) * 0.3 + 0.7
			label_color.a = pulse
			draw_circle(label_pos + Vector2(15, 5), 18.0, glow_color)

		# Draw detection percentage
		draw_string(font, label_pos, "[" + percent_text + "]", HORIZONTAL_ALIGNMENT_LEFT, 60, 10, label_color)

## Draw detection probability zones - concentric rings showing detection risk at distances
## Provides visual gradient from high probability (close to Herald) to low probability (far)
func _draw_detection_probability_zones(offset: Vector2) -> void:
	var screen_pos = _herald_position + offset

	# Visual scale: map AU to pixels
	var visual_scale = size.x / 80.0

	# Observation radius in pixels
	var base_radius = FCWHeraldAI.OBSERVATION_RADIUS * visual_scale

	# Detection probability thresholds to visualize (outer to inner)
	var thresholds = [0.1, 0.3, 0.5, 0.7, 0.9]

	# Calculate radii for each threshold
	# At base_radius (5 AU), detection is ~80% for burning ships
	# Radius inversely related to detection probability
	var pulse = sin(_global_time * 1.2) * 0.08 + 0.92

	for i in range(thresholds.size()):
		var prob = thresholds[i]
		# Lower probability = larger radius (farther from Herald)
		var ring_radius = base_radius * (2.0 - prob) * pulse

		# Color gradient: red (high prob) -> orange -> yellow -> green (low prob)
		var ring_color: Color
		var fill_alpha = 0.03 - i * 0.005  # Subtle fill, fainter for outer rings

		if prob >= 0.7:
			ring_color = Color(1.0, 0.2, 0.2, 0.25)  # Red - very dangerous
		elif prob >= 0.5:
			ring_color = Color(1.0, 0.5, 0.2, 0.2)   # Orange - dangerous
		elif prob >= 0.3:
			ring_color = Color(1.0, 0.8, 0.3, 0.15)  # Yellow - risky
		else:
			ring_color = Color(0.7, 0.9, 0.4, 0.1)   # Yellow-green - safer

		# Draw filled band between this ring and next outer ring
		if i > 0:
			var prev_radius = base_radius * (2.0 - thresholds[i - 1]) * pulse
			_draw_ring_band(screen_pos, ring_radius, prev_radius, Color(ring_color.r, ring_color.g, ring_color.b, fill_alpha))

		# Draw ring outline with subtle pulsing
		var ring_pulse = sin(_global_time * 2.0 + i * 0.4) * 0.15 + 0.85
		var outline_alpha = ring_color.a * ring_pulse
		var line_width = 1.0 + (1.0 - prob) * 0.5  # Thicker for outer rings

		draw_arc(screen_pos, ring_radius, 0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, outline_alpha), line_width)

		# Label key thresholds at right edge of ring
		if prob == 0.5 or prob == 0.1:
			var label_pos = screen_pos + Vector2(ring_radius + 5, 0)
			var font = ThemeDB.fallback_font
			var label_text = "%d%%" % int(prob * 100)
			draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, 40, 9, ring_color)

## Draw a filled ring band between two radii
func _draw_ring_band(center: Vector2, inner_radius: float, outer_radius: float, color: Color) -> void:
	if inner_radius >= outer_radius:
		return

	var segments = 32
	var angle_step = TAU / segments

	# Draw as series of quads
	for i in range(segments):
		var angle1 = i * angle_step
		var angle2 = (i + 1) * angle_step

		var inner1 = center + Vector2(cos(angle1), sin(angle1)) * inner_radius
		var inner2 = center + Vector2(cos(angle2), sin(angle2)) * inner_radius
		var outer1 = center + Vector2(cos(angle1), sin(angle1)) * outer_radius
		var outer2 = center + Vector2(cos(angle2), sin(angle2)) * outer_radius

		# Draw quad as two triangles
		var points = PackedVector2Array([inner1, outer1, outer2, inner2])
		draw_colored_polygon(points, color)

## Get Herald position in AU coordinates
func _get_herald_au_position(game_time: float) -> Vector2:
	# Read from Herald entity if available
	var herald_entity = FCWTypes.get_herald_entity(_state)
	if not herald_entity.is_empty():
		return herald_entity.position

	# Fallback to legacy state
	var herald_zone = _state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var herald_transit = _state.get("herald_transit", {})

	if herald_transit.is_empty():
		return FCWTypes.get_zone_position(herald_zone, game_time)
	else:
		var from_pos = FCWTypes.get_zone_position(herald_transit.from_zone, game_time)
		var to_pos = FCWTypes.get_zone_position(herald_transit.to_zone, game_time)
		var progress = 1.0 - (float(herald_transit.turns_remaining) / float(herald_transit.total_turns))
		return from_pos.lerp(to_pos, progress)

## Draw traffic pattern visualization - simple lines showing known routes
## Simplified: thin lines with intensity based on traffic level
func _draw_traffic_patterns(offset: Vector2) -> void:
	var herald_intel = _state.get("herald_intel", {})
	var known_routes = herald_intel.get("known_routes", {})

	for route_key in known_routes:
		var traffic = known_routes[route_key]
		if traffic < 0.1:
			continue  # Don't show minimal traffic

		# Parse route key
		var parts = route_key.split("_")
		if parts.size() != 2:
			continue

		var zone_a = int(parts[0])
		var zone_b = int(parts[1])

		var pos_a = _get_zone_pixel_pos(zone_a) + offset
		var pos_b = _get_zone_pixel_pos(zone_b) + offset

		# Simple line - width and opacity based on traffic
		var line_alpha = 0.2 + traffic * 0.5
		var line_width = 1.0 + traffic * 2.0
		var line_color = Color(1.0, 0.5, 0.2, line_alpha)

		# Danger coloring for heavy traffic
		if traffic >= 0.5:
			line_color = Color(1.0, 0.3, 0.2, line_alpha)

		draw_line(pos_a, pos_b, line_color, line_width)

		# Show percentage at midpoint for significant traffic
		if traffic >= 0.3:
			var mid_point = pos_a.lerp(pos_b, 0.5)
			var font = ThemeDB.fallback_font
			var percent = "%.0f%%" % (traffic * 100)
			draw_string(font, mid_point + Vector2(5, -5), percent, HORIZONTAL_ALIGNMENT_LEFT, 40, 9, line_color)

# ============================================================================
# FLEET ROSTER - Visual display of UNN fleet status
# ============================================================================

func _init_capital_ship_grid() -> void:
	## Initialize the capital ship grid from starting fleet
	_capital_ship_states.clear()

	# Add capital ships (Cruisers, Carriers, Dreadnoughts) to grid
	# Frigates are too numerous to show individually
	for ship_type in [FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.DREADNOUGHT]:
		var count = _starting_fleet.get(ship_type, 0)
		for i in range(count):
			_capital_ship_states.append({"type": ship_type, "alive": true})

func _update_capital_ship_states() -> void:
	## Update ship states based on current vs starting counts
	# Count how many of each type should be alive
	var alive_counts = {}
	for ship_type in [FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.DREADNOUGHT]:
		alive_counts[ship_type] = _current_fleet.get(ship_type, 0)

	# Mark ships as dead from the end (most recently lost)
	for i in range(_capital_ship_states.size() - 1, -1, -1):
		var ship = _capital_ship_states[i]
		var ship_type = ship.type
		if alive_counts.get(ship_type, 0) > 0:
			ship.alive = true
			alive_counts[ship_type] -= 1
		else:
			ship.alive = false

func _draw_fleet_roster(rect: Rect2) -> void:
	## Draw fleet status panel in top-right corner with ship outlines and names
	## Clicking an alive ship selects it for route assignment
	var panel_width = 280  # Wider to show location info
	var row_height = 18
	var max_ships_shown = 30  # Limit to prevent overflow
	var ships_to_show = mini(_capital_ship_states.size(), max_ships_shown)
	var panel_height = 30 + ships_to_show * row_height
	var margin = 10
	var panel_pos = Vector2(rect.size.x - panel_width - margin, margin)

	# Store panel rect for click detection
	_roster_panel_rect = Rect2(panel_pos, Vector2(panel_width, panel_height))
	_roster_item_rects.clear()

	# Panel background
	draw_rect(Rect2(panel_pos, Vector2(panel_width, panel_height)), Color(0.02, 0.04, 0.08, 0.9))
	draw_rect(Rect2(panel_pos, Vector2(panel_width, panel_height)), Color(0.3, 0.5, 0.7, 0.4), false, 1.0)

	# Title with ship counts
	var font = ThemeDB.fallback_font
	var total_alive = _capital_ship_states.filter(func(s): return s.alive).size()
	var total_ships = _capital_ship_states.size()
	var title = "UNN CAPITAL FLEET  %d/%d" % [total_alive, total_ships]
	draw_string(font, panel_pos + Vector2(8, 14), title, HORIZONTAL_ALIGNMENT_LEFT, panel_width - 16, 9, Color(0.6, 0.8, 1.0))

	# Draw each capital ship with outline and name
	var y_offset = 24
	for i in range(ships_to_show):
		var ship = _capital_ship_states[i]
		var ship_y = panel_pos.y + y_offset + i * row_height
		var ship_x = panel_pos.x + 8

		# Store click rect for this row (only for alive ships)
		var row_rect = Rect2(Vector2(panel_pos.x, ship_y), Vector2(panel_width, row_height))
		_roster_item_rects.append({"rect": row_rect, "index": i, "alive": ship.alive})

		# Ship outline (simplified silhouette)
		var outline_width = 24
		var outline_height = 10
		var outline_pos = Vector2(ship_x, ship_y + 2)

		# Get ship color and name based on type
		var base_color: Color
		var type_prefix: String
		match ship.type:
			FCWTypes.ShipType.CRUISER:
				base_color = Color(0.4, 0.5, 0.9)
				type_prefix = "CRS"
			FCWTypes.ShipType.CARRIER:
				base_color = Color(0.9, 0.7, 0.3)
				type_prefix = "CVR"
			FCWTypes.ShipType.DREADNOUGHT:
				base_color = Color(0.9, 0.4, 0.4)
				type_prefix = "DRN"
			_:
				base_color = Color(0.5, 0.5, 0.5)
				type_prefix = "SHP"

		# Generate consistent name from index
		var ship_name = _get_capital_ship_name(i, ship.type)

		# Get entity location and escort fleet info for alive ships
		var location_text = ""
		var location_color = Color(0.5, 0.5, 0.5, 0.7)
		var escort_count = 0
		var entity_id = _find_entity_for_roster_item(i)
		if entity_id != "" and ship.alive:
			var entity = _get_entity_by_id(entity_id)
			if not entity.is_empty():
				# Count escorting fleet
				var escorting = entity.get("escorting_fleet", {})
				for escort_type in escorting:
					escort_count += escorting[escort_type]

				var move_state = entity.get("movement_state", FCWTypes.MovementState.ORBITING)
				if move_state == FCWTypes.MovementState.ORBITING:
					var origin = entity.get("origin", -1)
					if origin >= 0:
						location_text = "@ %s" % FCWTypes.get_zone_name(origin)
						location_color = Color(0.4, 0.6, 0.4, 0.8)  # Green for stationed
				elif move_state == FCWTypes.MovementState.BURNING or move_state == FCWTypes.MovementState.COASTING:
					var dest = entity.get("destination", -1)
					if dest >= 0:
						var arrow = "→" if move_state == FCWTypes.MovementState.BURNING else "⟶"
						location_text = "%s %s" % [arrow, FCWTypes.get_zone_name(dest)]
						location_color = Color(0.6, 0.5, 0.3, 0.8)  # Orange for in transit

		# Check if this ship's entity is currently selected
		var is_selected = ship.get("entity_id", "") == _selected_entity_id and _selected_entity_id != ""

		if ship.alive:
			# Draw selection highlight if selected
			if is_selected:
				draw_rect(row_rect, Color(0.3, 0.5, 0.8, 0.3))
				draw_rect(row_rect, Color(0.4, 0.6, 1.0, 0.8), false, 2.0)

			# Draw ship outline (alive)
			var display_color = base_color if not is_selected else base_color.lightened(0.3)
			_draw_ship_silhouette(outline_pos, outline_width, outline_height, ship.type, display_color)

			# Ship name with escort count
			var name_with_escort = ship_name
			if escort_count > 0:
				name_with_escort += " +%d" % escort_count
			draw_string(font, Vector2(ship_x + outline_width + 6, ship_y + 11), name_with_escort, HORIZONTAL_ALIGNMENT_LEFT, 100, 8, display_color)

			# Location/destination (right side of row)
			if location_text != "":
				draw_string(font, Vector2(ship_x + outline_width + 110, ship_y + 11), location_text, HORIZONTAL_ALIGNMENT_LEFT, 130, 7, location_color)
		else:
			# Draw ship outline (destroyed - red X through it)
			_draw_ship_silhouette(outline_pos, outline_width, outline_height, ship.type, Color(0.3, 0.3, 0.3, 0.5))
			# Red X over the ship
			draw_line(outline_pos, outline_pos + Vector2(outline_width, outline_height), Color(0.8, 0.2, 0.2, 0.9), 2.0)
			draw_line(outline_pos + Vector2(outline_width, 0), outline_pos + Vector2(0, outline_height), Color(0.8, 0.2, 0.2, 0.9), 2.0)
			# Ship name (struck through)
			draw_string(font, Vector2(ship_x + outline_width + 6, ship_y + 11), ship_name, HORIZONTAL_ALIGNMENT_LEFT, 150, 8, Color(0.5, 0.3, 0.3, 0.7))

func _draw_ship_silhouette(pos: Vector2, w: float, h: float, ship_type: int, color: Color) -> void:
	## Draw a simple ship silhouette based on type
	var points: PackedVector2Array

	match ship_type:
		FCWTypes.ShipType.CRUISER:
			# Sleek cruiser shape
			points = PackedVector2Array([
				pos + Vector2(0, h * 0.5),
				pos + Vector2(w * 0.15, 0),
				pos + Vector2(w * 0.7, 0),
				pos + Vector2(w, h * 0.5),
				pos + Vector2(w * 0.7, h),
				pos + Vector2(w * 0.15, h),
			])
		FCWTypes.ShipType.CARRIER:
			# Wide carrier shape
			points = PackedVector2Array([
				pos + Vector2(0, h * 0.3),
				pos + Vector2(w * 0.1, 0),
				pos + Vector2(w * 0.9, 0),
				pos + Vector2(w, h * 0.3),
				pos + Vector2(w, h * 0.7),
				pos + Vector2(w * 0.9, h),
				pos + Vector2(w * 0.1, h),
				pos + Vector2(0, h * 0.7),
			])
		FCWTypes.ShipType.DREADNOUGHT:
			# Heavy dreadnought shape
			points = PackedVector2Array([
				pos + Vector2(0, h * 0.5),
				pos + Vector2(w * 0.2, 0),
				pos + Vector2(w * 0.5, 0),
				pos + Vector2(w * 0.6, h * 0.2),
				pos + Vector2(w, h * 0.5),
				pos + Vector2(w * 0.6, h * 0.8),
				pos + Vector2(w * 0.5, h),
				pos + Vector2(w * 0.2, h),
			])
		_:
			# Default rectangle
			points = PackedVector2Array([
				pos,
				pos + Vector2(w, 0),
				pos + Vector2(w, h),
				pos + Vector2(0, h),
			])

	draw_colored_polygon(points, color)
	draw_polyline(points, color.lightened(0.3), 1.0, true)

func _get_capital_ship_name(index: int, ship_type: int) -> String:
	## Generate consistent ship name from index
	var type_prefix: String
	match ship_type:
		FCWTypes.ShipType.CRUISER:
			type_prefix = "UNN"
		FCWTypes.ShipType.CARRIER:
			type_prefix = "CVN"
		FCWTypes.ShipType.DREADNOUGHT:
			type_prefix = "BB"
		_:
			type_prefix = "UNN"

	# Famous ship names
	var names = [
		"Defiant", "Resolute", "Intrepid", "Valiant", "Dauntless",
		"Prometheus", "Athena", "Hercules", "Perseus", "Orion",
		"Armstrong", "Gagarin", "Shepard", "Aldrin", "Collins",
		"Tokyo", "Shanghai", "Mumbai", "Lagos", "Sydney",
		"Wellington", "Nelson", "Yamamoto", "Nimitz", "Halsey",
		"Aurora", "Phoenix", "Titan", "Atlas", "Nova",
		"Victory", "Triumph", "Glory", "Honor", "Valor",
		"Endeavor", "Discovery", "Challenger", "Columbia", "Enterprise",
		"Constellation", "Constitution", "Independence", "Liberty", "Freedom",
		"Vanguard", "Sentinel", "Guardian", "Warden", "Bulwark"
	]

	var name_idx = index % names.size()
	return "%s %s" % [type_prefix, names[name_idx]]

# ============================================================================
# ZONE SIGNATURE VISUALIZATION - Shows detection risk for Herald targeting
# ============================================================================

func _draw_zone_signatures(offset: Vector2) -> void:
	## Draw signature bars below each zone showing detection level
	## This is the core mechanic visualization - player sees why Herald targets zones
	var zone_signatures = _state.get("zone_signatures", {})
	var herald_current_zone = _state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)

	for zone_id in FCWTypes.ZoneId.values():
		var zone_data = _zones.get(zone_id, {})
		if zone_data.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue

		var sig = zone_signatures.get(zone_id, 0.0)
		var zone_pos = _get_zone_pixel_pos(zone_id) + offset
		var zone_size = ZONE_SIZES.get(zone_id, 20.0)

		# Position signature bar below zone name and defense
		var bar_y = zone_size + 42
		var bar_width = 60.0
		var bar_height = 6.0
		var bar_x = -bar_width / 2.0

		# Background bar (dark)
		var bar_rect = Rect2(zone_pos.x + bar_x, zone_pos.y + bar_y, bar_width, bar_height)
		draw_rect(bar_rect, Color(0.1, 0.1, 0.1, 0.8))

		# Fill bar based on signature level
		var fill_width = bar_width * clampf(sig, 0.0, 1.0)
		var sig_color = _get_signature_color(sig)
		if fill_width > 0:
			var fill_rect = Rect2(zone_pos.x + bar_x, zone_pos.y + bar_y, fill_width, bar_height)
			draw_rect(fill_rect, sig_color)

		# Bar border
		draw_rect(bar_rect, sig_color.lightened(0.3), false, 1.0)

		# Signature label text
		var font = ThemeDB.fallback_font
		var sig_text = _get_signature_label(sig)
		var text_color = sig_color

		# Pulsing warning for high signatures
		if sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
			var pulse = sin(_global_time * 4.0) * 0.3 + 0.7
			text_color.a = pulse
			# Warning border around bar
			var warn_rect = Rect2(zone_pos.x + bar_x - 2, zone_pos.y + bar_y - 2, bar_width + 4, bar_height + 4)
			draw_rect(warn_rect, Color(1.0, 0.3, 0.1, pulse * 0.5), false, 2.0)

		# Draw percentage and label
		var percent_text = "%d%%" % int(sig * 100)
		draw_string(font, Vector2(zone_pos.x + bar_x, zone_pos.y + bar_y + bar_height + 12),
			percent_text, HORIZONTAL_ALIGNMENT_LEFT, 30, 9, text_color)
		draw_string(font, Vector2(zone_pos.x + bar_x + 32, zone_pos.y + bar_y + bar_height + 12),
			sig_text, HORIZONTAL_ALIGNMENT_LEFT, 60, 9, text_color.darkened(0.2))

func _get_signature_color(sig: float) -> Color:
	## Get color for signature level
	## Green (safe) -> Yellow (caution) -> Orange (risky) -> Red (danger)
	if sig >= 0.6:
		return Color(1.0, 0.2, 0.1)  # Red - critical
	elif sig >= 0.4:  # Skip threshold
		return Color(1.0, 0.5, 0.1)  # Orange - danger (can trigger skip)
	elif sig >= 0.2:
		return Color(1.0, 0.8, 0.2)  # Yellow - moderate
	elif sig >= 0.1:
		return Color(0.6, 0.8, 0.3)  # Yellow-green - low
	else:
		return Color(0.3, 0.7, 0.3)  # Green - dark/safe

func _get_signature_label(sig: float) -> String:
	## Get human-readable label for signature level
	if sig >= 0.6:
		return "CRITICAL"
	elif sig >= 0.4:
		return "High"
	elif sig >= 0.2:
		return "Moderate"
	elif sig >= 0.1:
		return "Low"
	else:
		return "Dark"

func _draw_herald_attention_arrow(offset: Vector2) -> void:
	## Draw arrow from Herald to its highest-priority target zone
	## Shows player WHERE Herald is looking and WHY
	var herald_current_zone = _state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var zone_signatures = _state.get("zone_signatures", {})

	# Find zones Herald can reach from current position
	var reachable = FCWTypes.get_all_reachable_zones(herald_current_zone)
	if reachable.is_empty():
		return

	# Find highest signature zone that's reachable and not fallen
	var highest_sig = -1.0
	var target_zone = -1
	for zone_id in reachable:
		var zone_data = _zones.get(zone_id, {})
		if zone_data.get("status", 0) == FCWTypes.ZoneStatus.FALLEN:
			continue
		var sig = zone_signatures.get(zone_id, 0.0)
		if sig > highest_sig:
			highest_sig = sig
			target_zone = zone_id

	# Also consider default inward path if no strong signal
	if highest_sig < FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
		var default_next = FCWTypes.get_zone_default_next(herald_current_zone)
		if default_next >= 0:
			var zone_data = _zones.get(default_next, {})
			if zone_data.get("status", 0) != FCWTypes.ZoneStatus.FALLEN:
				target_zone = default_next

	if target_zone < 0:
		return

	# Get positions
	var herald_pos = _get_zone_pixel_pos(herald_current_zone) + offset
	var target_pos = _get_zone_pixel_pos(target_zone) + offset

	# Calculate arrow properties
	var direction = (target_pos - herald_pos).normalized()
	var distance = herald_pos.distance_to(target_pos)
	var herald_size = ZONE_SIZES.get(herald_current_zone, 20.0)
	var target_size = ZONE_SIZES.get(target_zone, 20.0)

	# Start arrow from edge of Herald zone, end before target zone
	var start_pos = herald_pos + direction * (herald_size + 45)
	var end_pos = target_pos - direction * (target_size + 60)

	# Only draw if there's enough distance
	if start_pos.distance_to(end_pos) < 50:
		return

	# Arrow color based on signature strength
	var arrow_color = _get_signature_color(highest_sig)
	var pulse = sin(_global_time * 2.5) * 0.2 + 0.8
	arrow_color.a = pulse * 0.7

	# Draw dashed line
	var dash_length = 15.0
	var gap_length = 8.0
	var current_dist = 0.0
	var total_dist = start_pos.distance_to(end_pos)
	var drawing = true

	while current_dist < total_dist:
		var segment_length = dash_length if drawing else gap_length
		var segment_end = minf(current_dist + segment_length, total_dist)

		if drawing:
			var seg_start = start_pos + direction * current_dist
			var seg_end = start_pos + direction * segment_end
			draw_line(seg_start, seg_end, arrow_color, 2.0)

		current_dist = segment_end
		drawing = not drawing

	# Draw arrowhead
	var arrow_size = 12.0
	var arrow_angle = 0.4  # radians
	var arrow_left = end_pos - direction.rotated(arrow_angle) * arrow_size
	var arrow_right = end_pos - direction.rotated(-arrow_angle) * arrow_size
	var arrow_points = PackedVector2Array([end_pos, arrow_left, arrow_right])
	draw_colored_polygon(arrow_points, arrow_color)

	# Draw "TRACKING" label at midpoint for high signatures
	if highest_sig >= FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
		var mid_pos = start_pos.lerp(end_pos, 0.5)
		var font = ThemeDB.fallback_font
		var label_offset = direction.orthogonal() * 15
		var tracking_text = "TRACKING"
		if highest_sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
			tracking_text = "LOCKED"
		draw_string(font, mid_pos + label_offset + Vector2(-25, 4),
			tracking_text, HORIZONTAL_ALIGNMENT_CENTER, 60, 9, arrow_color)
