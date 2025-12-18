extends Control
class_name MCSView

## MCS Visual Colony Renderer - Dynamic & Exciting!
## Shows colony with weather effects, rescue animations, activity particles
## Buildings as colored blocks with activity indicators, colonists moving with purpose

# Store reference for direct state access
var _store: Node = null

# ============================================================================
# CONSTANTS
# ============================================================================

const GRID_SIZE = 16  # 16x16 grid
const CELL_SIZE = 32  # Pixels per cell
const COLONIST_SIZE = 6
const BUILDING_PADDING = 2

# Building colors by type - brighter for more visual pop
const BUILDING_COLORS = {
	"hab": Color(0.4, 0.6, 0.85),      # Bright Blue - housing
	"food": Color(0.3, 0.75, 0.35),    # Vibrant Green - food production
	"power": Color(0.95, 0.85, 0.2),   # Bright Yellow - power
	"medical": Color(0.9, 0.35, 0.35), # Bright Red - medical
	"science": Color(0.7, 0.4, 0.85),  # Vibrant Purple - science
	"industry": Color(0.7, 0.55, 0.35),# Warm Brown - industry
	"social": Color(0.85, 0.6, 0.7),   # Warm Pink - social
	"infra": Color(0.55, 0.55, 0.55),  # Medium Gray - infrastructure
}

# Generation colors for colonists - more vibrant
const GEN_COLORS = {
	0: Color(1.0, 0.9, 0.3),   # Earth-born - Bright Gold
	1: Color(0.3, 0.95, 1.0),  # First gen - Bright Cyan
	2: Color(0.3, 1.0, 0.45),  # Second gen - Bright Green
	3: Color(1.0, 1.0, 0.4),   # Third gen+ - Bright Yellow
}

# Robot colors
const ROBOT_COLOR = Color(0.6, 0.8, 1.0)  # Light blue-white for robots
const RESCUE_ROBOT_COLOR = Color(1.0, 0.5, 0.2)  # Orange for rescue bots

# ============================================================================
# STATE
# ============================================================================

var _buildings: Array = []
var _colonists: Array = []
var _grid_occupancy: Array = []  # 2D array of building indices
var _colonist_positions: Dictionary = {}  # id -> Vector2
var _colonist_targets: Dictionary = {}  # id -> Vector2
var _time_accumulator: float = 0.0

# Visual state
var _building_placements: Dictionary = {}  # building_id -> grid position

# ============================================================================
# VISUAL EFFECTS STATE
# ============================================================================

# Weather effects
var _sandstorm_active: bool = false
var _sandstorm_intensity: float = 0.0
var _sandstorm_particles: Array = []  # Array of {pos, vel, alpha}

# Rescue/Crisis effects
var _active_rescues: Array = []  # Array of {from, to, progress, robot_pos}
var _crisis_buildings: Array = []  # Building IDs with active crises
var _alert_flash_timer: float = 0.0

# Activity effects
var _work_particles: Array = []  # Sparks, harvest particles, etc.
var _building_activity: Dictionary = {}  # building_id -> activity_type

# Robots - separate from colonists
var _robots: Array = []  # Array of {id, pos, target, task, color}
var _robot_count: int = 3  # Start with 3 worker robots

# Dust/ambient particles
var _dust_particles: Array = []

# Event-driven visual state
var _current_event_effect: String = ""  # "sandstorm", "rescue", "construction", etc.
var _event_effect_timer: float = 0.0

# Priority alerts - set by UI based on state analysis
var _priority_alerts: Array = []  # Array of {priority, message, icon}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Initialize grid
	_grid_occupancy = []
	for x in range(GRID_SIZE):
		var row = []
		for y in range(GRID_SIZE):
			row.append(-1)
		_grid_occupancy.append(row)

	# Initialize robots
	_init_robots()

	# Initialize ambient dust
	_init_dust_particles()

func _process(delta: float):
	_time_accumulator += delta
	_alert_flash_timer += delta * 4.0  # Fast flash

	# Update all movement and effects
	_update_colonist_movement(delta)
	_update_robot_movement(delta)
	_update_sandstorm(delta)
	_update_rescue_animations(delta)
	_update_work_particles(delta)
	_update_dust_particles(delta)
	_update_event_effects(delta)

	queue_redraw()

func _draw():
	# Always refresh from store to ensure we have the latest data
	if _store:
		_refresh_from_store()

	# Draw layers from back to front
	_draw_mars_surface()       # Background terrain
	_draw_grid()
	_draw_sandstorm_back()     # Sandstorm behind buildings
	_draw_buildings()
	_draw_work_particles()     # Sparks and harvest effects
	_draw_robots()             # Worker and rescue robots
	_draw_colonists()
	_draw_rescue_lines()       # Rescue operation indicators
	_draw_sandstorm_front()    # Sandstorm in front
	_draw_dust_particles()     # Ambient dust
	_draw_crisis_indicators()  # Flashing alerts
	_draw_stats_overlay()

# ============================================================================
# PUBLIC API
# ============================================================================

func set_store(store: Node):
	_store = store

func update_state(buildings: Array, colonists: Array):
	# Store copies to avoid reference issues
	_buildings = buildings.duplicate(true)
	_colonists = colonists.duplicate(true)
	_update_building_placements()
	_update_colonist_targets()

func _refresh_from_store():
	if _store and _store.has_method("get_state"):
		var state = _store.get_state()
		var new_buildings = state.get("buildings", []).duplicate(true)
		var new_colonists = state.get("colonists", []).duplicate(true)

		# Check if data actually changed before updating
		var buildings_changed = _buildings.size() != new_buildings.size()
		var colonists_changed = _colonists.size() != new_colonists.size()

		_buildings = new_buildings
		_colonists = new_colonists

		# Update placements when buildings change
		if buildings_changed or _building_placements.is_empty():
			_update_building_placements()

		# Update colonist targets when population changes
		if colonists_changed:
			_update_colonist_targets()

# ============================================================================
# DRAWING
# ============================================================================

func _draw_grid():
	var grid_color = Color(0.2, 0.15, 0.1, 0.3)

	# Draw vertical lines
	for x in range(GRID_SIZE + 1):
		var start = Vector2(x * CELL_SIZE, 0)
		var end = Vector2(x * CELL_SIZE, GRID_SIZE * CELL_SIZE)
		draw_line(start, end, grid_color, 1.0)

	# Draw horizontal lines
	for y in range(GRID_SIZE + 1):
		var start = Vector2(0, y * CELL_SIZE)
		var end = Vector2(GRID_SIZE * CELL_SIZE, y * CELL_SIZE)
		draw_line(start, end, grid_color, 1.0)

	# Draw border
	var border_rect = Rect2(0, 0, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
	draw_rect(border_rect, Color(0.4, 0.3, 0.2), false, 2.0)

func _draw_buildings():
	for building in _buildings:
		var building_id = building.get("id", "")
		var pos = _building_placements.get(building_id, Vector2(-1, -1))
		if pos.x < 0:
			continue

		var rect = Rect2(
			pos.x * CELL_SIZE + BUILDING_PADDING,
			pos.y * CELL_SIZE + BUILDING_PADDING,
			CELL_SIZE - BUILDING_PADDING * 2,
			CELL_SIZE - BUILDING_PADDING * 2
		)

		# Get color by building category
		var building_type = building.get("type", 0)
		var color = _get_building_color(building_type)

		# Dim if under construction
		if building.get("is_under_construction", false):
			color = color.darkened(0.5)
			# Draw construction progress
			var progress = building.get("construction_progress", 0.0)
			var progress_rect = Rect2(
				rect.position.x,
				rect.position.y + rect.size.y - 4,
				rect.size.x * progress,
				4
			)
			draw_rect(rect, color, true)
			draw_rect(progress_rect, Color.WHITE, true)
		elif not building.get("is_operational", true):
			# Broken - show red outline
			draw_rect(rect, color.darkened(0.3), true)
			draw_rect(rect, Color.RED, false, 2.0)
		else:
			draw_rect(rect, color, true)

		# Draw building icon/letter
		var label = _get_building_label(building_type)
		var font = ThemeDB.fallback_font
		var font_size = 14
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = rect.position + (rect.size - text_size) / 2 + Vector2(0, text_size.y * 0.7)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_colonists():
	for colonist in _colonists:
		if not colonist.get("is_alive", false):
			continue

		var colonist_id = colonist.get("id", "")
		var pos = _colonist_positions.get(colonist_id, Vector2(-1, -1))
		if pos.x < 0:
			# Assign initial position
			pos = _random_position_in_colony()
			_colonist_positions[colonist_id] = pos

		# Color by generation
		var generation = colonist.get("generation", 0)
		var color = GEN_COLORS.get(generation, Color.WHITE)

		# Size by life stage
		var size = COLONIST_SIZE
		var life_stage = colonist.get("life_stage", MCSTypes.LifeStage.ADULT)
		if life_stage == MCSTypes.LifeStage.CHILD or life_stage == MCSTypes.LifeStage.INFANT:
			size = COLONIST_SIZE * 0.6
		elif life_stage == MCSTypes.LifeStage.ELDER:
			color = color.darkened(0.2)

		# Health affects brightness
		if colonist.get("health", 100.0) < 50:
			color = color.darkened(0.3)

		draw_circle(pos, size, color)

func _draw_stats_overlay():
	# Draw a small stats overlay in the corner
	var font = ThemeDB.fallback_font
	var font_size = 12

	var alive_count = 0
	for c in _colonists:
		if c.get("is_alive", true):  # Default to true for colonists
			alive_count += 1

	var building_count = _buildings.size()
	var operational = 0
	var broken_count = 0
	var under_construction = 0
	for b in _buildings:
		if b.get("is_under_construction", false):
			under_construction += 1
		elif b.get("is_operational", true):
			operational += 1
		else:
			broken_count += 1

	# Semi-transparent background - taller to fit more info
	var overlay_rect = Rect2(GRID_SIZE * CELL_SIZE - 95, 5, 90, 75)
	draw_rect(overlay_rect, Color(0, 0, 0, 0.7), true)

	var y_offset = 16
	var x_start = overlay_rect.position.x + 5

	# Population with robot count
	draw_string(font, Vector2(x_start, overlay_rect.position.y + y_offset),
		"Pop: %d" % alive_count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	y_offset += 14
	draw_string(font, Vector2(x_start, overlay_rect.position.y + y_offset),
		"Robots: %d" % _robots.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ROBOT_COLOR)

	y_offset += 14
	var bldg_color = Color.WHITE
	if broken_count > 0:
		bldg_color = Color.ORANGE
	draw_string(font, Vector2(x_start, overlay_rect.position.y + y_offset),
		"Bldg: %d/%d" % [operational, building_count], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, bldg_color)

	# Show construction/repair status
	y_offset += 14
	if under_construction > 0:
		draw_string(font, Vector2(x_start, overlay_rect.position.y + y_offset),
			"Building: %d" % under_construction, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)
	elif broken_count > 0:
		draw_string(font, Vector2(x_start, overlay_rect.position.y + y_offset),
			"Broken: %d" % broken_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.RED)

	# Draw robot task summary
	_draw_robot_task_summary()

	# Draw priority alerts
	_draw_priority_alerts()

func _draw_robot_task_summary():
	"""Show what robots are currently doing"""
	var font = ThemeDB.fallback_font
	var task_counts = {"working": 0, "patrol": 0, "rescue": 0, "idle": 0}

	for robot in _robots:
		var task = robot.get("task", "idle")
		if task_counts.has(task):
			task_counts[task] += 1
		else:
			task_counts["idle"] += 1

	# Draw at bottom left
	var y_pos = GRID_SIZE * CELL_SIZE - 25
	var x_pos = 5

	# Background
	var bg_rect = Rect2(x_pos - 2, y_pos - 12, 120, 20)
	draw_rect(bg_rect, Color(0, 0, 0, 0.6), true)

	var task_text = ""
	if task_counts["working"] > 0:
		task_text += "⚙%d " % task_counts["working"]
	if task_counts["rescue"] > 0:
		task_text += "🚨%d " % task_counts["rescue"]
	if task_counts["patrol"] > 0:
		task_text += "👁%d" % task_counts["patrol"]

	if task_text.is_empty():
		task_text = "Robots idle"

	draw_string(font, Vector2(x_pos, y_pos), task_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _draw_priority_alerts():
	"""Draw priority alerts at top of screen"""
	if _priority_alerts.is_empty():
		return

	var font = ThemeDB.fallback_font
	var y_pos = 8
	var x_pos = 10

	for alert in _priority_alerts:
		var priority = alert.get("priority", 0)
		var message = alert.get("message", "")
		var icon = alert.get("icon", "⚠")

		# Color based on priority (0=info, 1=warning, 2=critical)
		var color = Color.WHITE
		var bg_color = Color(0, 0, 0, 0.5)
		match priority:
			2:  # Critical
				color = Color.RED
				bg_color = Color(0.3, 0, 0, 0.7)
				# Pulse effect for critical
				color.a = 0.7 + sin(_time_accumulator * 4) * 0.3
			1:  # Warning
				color = Color.YELLOW
				bg_color = Color(0.2, 0.15, 0, 0.6)
			0:  # Info
				color = Color.CYAN

		# Draw background pill
		var text_width = font.get_string_size(icon + " " + message, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var pill_rect = Rect2(x_pos - 4, y_pos - 10, text_width + 12, 16)
		draw_rect(pill_rect, bg_color, true)

		# Draw text
		draw_string(font, Vector2(x_pos, y_pos), icon + " " + message, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

		x_pos += text_width + 20
		if x_pos > GRID_SIZE * CELL_SIZE - 100:
			# Wrap to next line
			x_pos = 10
			y_pos += 18

# ============================================================================
# BUILDING PLACEMENT
# ============================================================================

func _update_building_placements():
	# Place new buildings that don't have positions yet
	for building in _buildings:
		var building_id = building.get("id", "")
		if building_id and not _building_placements.has(building_id):
			var pos = _find_building_position()
			if pos.x >= 0:
				_building_placements[building_id] = pos
				_grid_occupancy[int(pos.x)][int(pos.y)] = _buildings.find(building)

func _find_building_position() -> Vector2:
	# Start from center and spiral outward
	var center = Vector2(GRID_SIZE / 2, GRID_SIZE / 2)

	# Spiral search
	for radius in range(0, GRID_SIZE / 2):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check perimeter

				var x = int(center.x + dx)
				var y = int(center.y + dy)

				if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
					if _grid_occupancy[x][y] < 0:
						return Vector2(x, y)

	return Vector2(-1, -1)  # Grid full

func _get_building_color(building_type: int) -> Color:
	match building_type:
		MCSTypes.BuildingType.HAB_POD, MCSTypes.BuildingType.APARTMENT_BLOCK, \
		MCSTypes.BuildingType.LUXURY_QUARTERS, MCSTypes.BuildingType.BARRACKS:
			return BUILDING_COLORS["hab"]
		MCSTypes.BuildingType.GREENHOUSE, MCSTypes.BuildingType.HYDROPONICS, \
		MCSTypes.BuildingType.PROTEIN_VATS:
			return BUILDING_COLORS["food"]
		MCSTypes.BuildingType.SOLAR_ARRAY, MCSTypes.BuildingType.WIND_TURBINE, \
		MCSTypes.BuildingType.RTG, MCSTypes.BuildingType.FISSION_REACTOR:
			return BUILDING_COLORS["power"]
		MCSTypes.BuildingType.MEDICAL_BAY, MCSTypes.BuildingType.HOSPITAL:
			return BUILDING_COLORS["medical"]
		MCSTypes.BuildingType.LAB, MCSTypes.BuildingType.RESEARCH_CENTER, \
		MCSTypes.BuildingType.SCHOOL, MCSTypes.BuildingType.UNIVERSITY:
			return BUILDING_COLORS["science"]
		MCSTypes.BuildingType.WORKSHOP, MCSTypes.BuildingType.FACTORY:
			return BUILDING_COLORS["industry"]
		MCSTypes.BuildingType.RECREATION_CENTER, MCSTypes.BuildingType.TEMPLE, \
		MCSTypes.BuildingType.GOVERNMENT_HALL:
			return BUILDING_COLORS["social"]
		_:
			return BUILDING_COLORS["infra"]

func _get_building_label(building_type: int) -> String:
	match building_type:
		MCSTypes.BuildingType.HAB_POD: return "H"
		MCSTypes.BuildingType.APARTMENT_BLOCK: return "A"
		MCSTypes.BuildingType.GREENHOUSE: return "G"
		MCSTypes.BuildingType.HYDROPONICS: return "Hy"
		MCSTypes.BuildingType.SOLAR_ARRAY: return "S"
		MCSTypes.BuildingType.FISSION_REACTOR: return "R"
		MCSTypes.BuildingType.MEDICAL_BAY: return "M"
		MCSTypes.BuildingType.HOSPITAL: return "H+"
		MCSTypes.BuildingType.SCHOOL: return "Sc"
		MCSTypes.BuildingType.LAB: return "L"
		MCSTypes.BuildingType.WORKSHOP: return "W"
		MCSTypes.BuildingType.FACTORY: return "F"
		MCSTypes.BuildingType.WATER_EXTRACTOR: return "We"
		MCSTypes.BuildingType.RECREATION_CENTER: return "Re"
		MCSTypes.BuildingType.GOVERNMENT_HALL: return "Go"
		_: return "?"

# ============================================================================
# COLONIST MOVEMENT
# ============================================================================

func _update_colonist_targets():
	# Occasionally assign new targets for colonists to walk to
	for colonist in _colonists:
		if not colonist.get("is_alive", false):
			continue

		var colonist_id = colonist.get("id", "")
		if colonist_id and (not _colonist_targets.has(colonist_id) or randf() < 0.02):
			_colonist_targets[colonist_id] = _random_position_in_colony()

func _update_colonist_movement(delta: float):
	var speed = 30.0  # Pixels per second

	for colonist in _colonists:
		if not colonist.get("is_alive", false):
			continue

		var colonist_id = colonist.get("id", "")
		if not colonist_id:
			continue

		var current = _colonist_positions.get(colonist_id, Vector2(-1, -1))
		var target = _colonist_targets.get(colonist_id, current)

		if current.x < 0:
			current = _random_position_in_colony()
			_colonist_positions[colonist_id] = current

		# Move toward target
		var direction = (target - current).normalized()
		var distance = current.distance_to(target)

		if distance > 5:
			var move = direction * speed * delta
			if move.length() > distance:
				_colonist_positions[colonist_id] = target
			else:
				_colonist_positions[colonist_id] = current + move
		else:
			# Reached target, get new one
			if randf() < 0.1:
				_colonist_targets[colonist_id] = _random_position_in_colony()

func _random_position_in_colony() -> Vector2:
	# Random position within the colony area (biased toward center)
	var margin = CELL_SIZE * 2
	var area_size = GRID_SIZE * CELL_SIZE - margin * 2

	# Gaussian-ish distribution toward center
	var center = Vector2(GRID_SIZE * CELL_SIZE / 2, GRID_SIZE * CELL_SIZE / 2)
	var offset = Vector2(
		(randf() - 0.5) * area_size * 0.7,
		(randf() - 0.5) * area_size * 0.7
	)

	return center + offset

# ============================================================================
# MARS SURFACE BACKGROUND
# ============================================================================

func _draw_mars_surface():
	# Draw a rust-red Mars surface background with subtle texture
	var bg_color = Color(0.35, 0.18, 0.12)  # Mars red-brown
	var full_rect = Rect2(0, 0, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
	draw_rect(full_rect, bg_color, true)

	# Add some subtle crater/rock shadows for texture
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent look
	for i in range(20):
		var x = rng.randf() * GRID_SIZE * CELL_SIZE
		var y = rng.randf() * GRID_SIZE * CELL_SIZE
		var r = rng.randf_range(5, 25)
		var shade = bg_color.darkened(rng.randf_range(0.1, 0.25))
		draw_circle(Vector2(x, y), r, shade)

# ============================================================================
# ROBOT SYSTEM
# ============================================================================

func _init_robots():
	_robots = []
	for i in range(_robot_count):
		var robot = {
			"id": "robot_%d" % i,
			"pos": _random_position_in_colony(),
			"target": _random_position_in_colony(),
			"task": "idle",  # idle, working, rescue, building
			"color": ROBOT_COLOR,
			"trail": []  # Position history for motion blur
		}
		_robots.append(robot)

func _update_robot_movement(delta: float):
	var speed = 80.0  # Robots move faster than colonists

	for robot in _robots:
		var current = robot.get("pos", Vector2.ZERO)
		var target = robot.get("target", current)

		# Store trail for motion effect
		var trail = robot.get("trail", [])
		trail.push_front(current)
		if trail.size() > 5:
			trail.pop_back()
		robot["trail"] = trail

		var direction = (target - current).normalized()
		var distance = current.distance_to(target)

		if distance > 10:
			var move = direction * speed * delta
			if move.length() > distance:
				robot["pos"] = target
			else:
				robot["pos"] = current + move
		else:
			# Reached target - assign new task
			_assign_robot_task(robot)

func _assign_robot_task(robot: Dictionary):
	# Pick a task based on colony state
	var roll = randf()

	if not _buildings.is_empty() and roll < 0.6:
		# Go to a building to "work"
		var building = _buildings[randi() % _buildings.size()]
		var building_id = building.get("id", "")
		var pos = _building_placements.get(building_id, Vector2(-1, -1))
		if pos.x >= 0:
			robot["target"] = Vector2(
				pos.x * CELL_SIZE + CELL_SIZE / 2 + randf_range(-10, 10),
				pos.y * CELL_SIZE + CELL_SIZE / 2 + randf_range(-10, 10)
			)
			robot["task"] = "working"

			# Spawn work particles at destination
			_spawn_work_particles_at(robot["target"], _get_building_work_type(building.get("type", 0)))
	else:
		# Patrol/explore
		robot["target"] = _random_position_in_colony()
		robot["task"] = "patrol"

func _get_building_work_type(building_type: int) -> String:
	match building_type:
		MCSTypes.BuildingType.GREENHOUSE, MCSTypes.BuildingType.HYDROPONICS:
			return "harvest"
		MCSTypes.BuildingType.WORKSHOP, MCSTypes.BuildingType.FACTORY:
			return "sparks"
		MCSTypes.BuildingType.SOLAR_ARRAY:
			return "energy"
		MCSTypes.BuildingType.WATER_EXTRACTOR:
			return "water"
		_:
			return "generic"

func _draw_robots():
	for robot in _robots:
		var pos = robot.get("pos", Vector2.ZERO)
		var task = robot.get("task", "idle")
		var trail = robot.get("trail", [])

		# Draw motion trail
		for i in range(trail.size()):
			var trail_pos = trail[i]
			var alpha = 0.3 * (1.0 - float(i) / trail.size())
			draw_circle(trail_pos, 4 - i * 0.5, Color(0.5, 0.7, 1.0, alpha))

		# Robot body color based on task
		var body_color = ROBOT_COLOR
		if task == "rescue":
			body_color = RESCUE_ROBOT_COLOR
		elif task == "working":
			body_color = Color(0.5, 1.0, 0.6)  # Green for working

		# Draw robot - square body with antenna
		var robot_size = 8
		var body_rect = Rect2(pos - Vector2(robot_size/2, robot_size/2), Vector2(robot_size, robot_size))
		draw_rect(body_rect, body_color, true)
		draw_rect(body_rect, Color.WHITE, false, 1.0)

		# Antenna with blinking light
		var antenna_height = 6
		draw_line(pos + Vector2(0, -robot_size/2), pos + Vector2(0, -robot_size/2 - antenna_height), Color.GRAY, 1.0)
		var blink = sin(_time_accumulator * 8.0 + hash(robot.get("id", "")) * 0.1) > 0
		if blink:
			draw_circle(pos + Vector2(0, -robot_size/2 - antenna_height), 2, Color.RED)

		# Task indicator
		if task == "working":
			# Small wrench icon (just lines)
			draw_line(pos + Vector2(5, -5), pos + Vector2(8, -2), Color.YELLOW, 1.5)

# ============================================================================
# SANDSTORM EFFECTS
# ============================================================================

func _init_sandstorm_particles():
	_sandstorm_particles = []
	for i in range(100):
		_sandstorm_particles.append({
			"pos": Vector2(randf() * GRID_SIZE * CELL_SIZE, randf() * GRID_SIZE * CELL_SIZE),
			"vel": Vector2(randf_range(100, 200), randf_range(-20, 20)),
			"alpha": randf_range(0.3, 0.7),
			"size": randf_range(2, 6)
		})

func _update_sandstorm(delta: float):
	if not _sandstorm_active:
		# Fade out
		_sandstorm_intensity = maxf(0.0, _sandstorm_intensity - delta * 0.5)
		if _sandstorm_intensity <= 0 and _sandstorm_particles.size() > 0:
			_sandstorm_particles.clear()
		return

	# Fade in
	_sandstorm_intensity = minf(1.0, _sandstorm_intensity + delta * 0.3)

	# Initialize particles if needed
	if _sandstorm_particles.is_empty():
		_init_sandstorm_particles()

	# Update particle positions
	var bounds = GRID_SIZE * CELL_SIZE
	for particle in _sandstorm_particles:
		particle["pos"] += particle["vel"] * delta * _sandstorm_intensity

		# Wrap around
		if particle["pos"].x > bounds:
			particle["pos"].x = -10
			particle["pos"].y = randf() * bounds
		if particle["pos"].y < 0:
			particle["pos"].y = bounds
		elif particle["pos"].y > bounds:
			particle["pos"].y = 0

func _draw_sandstorm_back():
	if _sandstorm_intensity <= 0:
		return

	# Draw a subtle orange tint over the background
	var tint_color = Color(0.8, 0.5, 0.2, 0.2 * _sandstorm_intensity)
	var full_rect = Rect2(0, 0, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
	draw_rect(full_rect, tint_color, true)

func _draw_sandstorm_front():
	if _sandstorm_intensity <= 0:
		return

	# Draw particles
	var dust_color = Color(0.85, 0.6, 0.3)
	for particle in _sandstorm_particles:
		var alpha = particle["alpha"] * _sandstorm_intensity
		var col = Color(dust_color.r, dust_color.g, dust_color.b, alpha)
		var s = particle["size"]
		# Elongated particles for wind effect
		var wind_stretch = Vector2(s * 3, s * 0.5)
		draw_rect(Rect2(particle["pos"] - wind_stretch / 2, wind_stretch), col, true)

	# Draw "SANDSTORM" warning if intense
	if _sandstorm_intensity > 0.5:
		var font = ThemeDB.fallback_font
		var warning_alpha = 0.5 + sin(_time_accumulator * 4) * 0.3
		var warning_color = Color(1, 0.5, 0, warning_alpha * _sandstorm_intensity)
		draw_string(font, Vector2(10, 30), "⚠ SANDSTORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, warning_color)

# ============================================================================
# RESCUE ANIMATIONS
# ============================================================================

func trigger_rescue(from_pos: Vector2, to_pos: Vector2):
	"""Called when a rescue event happens - show robots going to help"""
	_active_rescues.append({
		"from": from_pos,
		"to": to_pos,
		"progress": 0.0,
		"robot_pos": from_pos,
		"returning": false
	})

	# Assign a robot to rescue duty
	if not _robots.is_empty():
		var robot = _robots[0]
		robot["task"] = "rescue"
		robot["target"] = to_pos
		robot["color"] = RESCUE_ROBOT_COLOR

func _update_rescue_animations(delta: float):
	var completed = []
	for i in range(_active_rescues.size()):
		var rescue = _active_rescues[i]
		rescue["progress"] += delta * 0.5  # Speed of rescue

		if not rescue["returning"]:
			# Going to rescue site
			rescue["robot_pos"] = rescue["from"].lerp(rescue["to"], minf(rescue["progress"], 1.0))
			if rescue["progress"] >= 1.0:
				rescue["returning"] = true
				rescue["progress"] = 0.0
		else:
			# Returning with rescued
			rescue["robot_pos"] = rescue["to"].lerp(rescue["from"], minf(rescue["progress"], 1.0))
			if rescue["progress"] >= 1.0:
				completed.append(i)

	# Remove completed rescues
	for i in range(completed.size() - 1, -1, -1):
		_active_rescues.remove_at(completed[i])

func _draw_rescue_lines():
	for rescue in _active_rescues:
		var from = rescue["from"]
		var to = rescue["to"]
		var robot_pos = rescue["robot_pos"]

		# Draw dashed line path
		var dash_color = Color(1, 0.5, 0, 0.5)
		_draw_dashed_line(from, to, dash_color, 2.0, 8.0)

		# Draw rescue robot
		draw_circle(robot_pos, 6, RESCUE_ROBOT_COLOR)
		draw_circle(robot_pos, 6, Color.WHITE, false, 1.5)

		# Flashing emergency light
		if sin(_time_accumulator * 10) > 0:
			draw_circle(robot_pos + Vector2(0, -8), 3, Color.RED)

		# If returning, show rescued colonist
		if rescue["returning"]:
			draw_circle(robot_pos + Vector2(8, 0), 4, Color.CYAN)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float):
	var direction = (to - from).normalized()
	var total_length = from.distance_to(to)
	var drawn = 0.0
	var drawing = true

	while drawn < total_length:
		var segment_length = minf(dash_length, total_length - drawn)
		var start = from + direction * drawn
		var end = from + direction * (drawn + segment_length)

		if drawing:
			draw_line(start, end, color, width)

		drawn += dash_length
		drawing = not drawing

# ============================================================================
# WORK PARTICLES
# ============================================================================

func _spawn_work_particles_at(pos: Vector2, work_type: String):
	var count = 5
	var color = Color.YELLOW
	var velocity_range = 30.0

	match work_type:
		"harvest":
			color = Color.GREEN
			count = 8
		"sparks":
			color = Color.ORANGE
			velocity_range = 50.0
		"energy":
			color = Color.YELLOW
			count = 3
		"water":
			color = Color.CYAN

	for i in range(count):
		_work_particles.append({
			"pos": pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)),
			"vel": Vector2(randf_range(-velocity_range, velocity_range), randf_range(-velocity_range, -10)),
			"color": color,
			"life": 1.0,
			"size": randf_range(2, 4)
		})

func _update_work_particles(delta: float):
	var to_remove = []
	for i in range(_work_particles.size()):
		var p = _work_particles[i]
		p["pos"] += p["vel"] * delta
		p["vel"].y += 50 * delta  # Gravity
		p["life"] -= delta * 2
		if p["life"] <= 0:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		_work_particles.remove_at(to_remove[i])

	# Occasionally spawn particles at active buildings
	if randf() < delta * 2:  # ~2 spawns per second
		_spawn_random_work_particle()

func _spawn_random_work_particle():
	if _buildings.is_empty():
		return

	var building = _buildings[randi() % _buildings.size()]
	if not building.get("is_operational", true):
		return

	var building_id = building.get("id", "")
	var pos = _building_placements.get(building_id, Vector2(-1, -1))
	if pos.x < 0:
		return

	var center = Vector2(pos.x * CELL_SIZE + CELL_SIZE / 2, pos.y * CELL_SIZE + CELL_SIZE / 2)
	var work_type = _get_building_work_type(building.get("type", 0))
	_spawn_work_particles_at(center, work_type)

func _draw_work_particles():
	for p in _work_particles:
		var alpha = p["life"]
		var col = p["color"]
		col.a = alpha
		draw_circle(p["pos"], p["size"] * p["life"], col)

# ============================================================================
# DUST PARTICLES (AMBIENT)
# ============================================================================

func _init_dust_particles():
	_dust_particles = []
	for i in range(30):
		_dust_particles.append({
			"pos": Vector2(randf() * GRID_SIZE * CELL_SIZE, randf() * GRID_SIZE * CELL_SIZE),
			"vel": Vector2(randf_range(-5, 5), randf_range(-2, 2)),
			"alpha": randf_range(0.1, 0.3),
			"size": randf_range(1, 3)
		})

func _update_dust_particles(delta: float):
	var bounds = GRID_SIZE * CELL_SIZE
	for p in _dust_particles:
		p["pos"] += p["vel"] * delta

		# Gentle random drift
		p["vel"] += Vector2(randf_range(-10, 10), randf_range(-5, 5)) * delta
		p["vel"] = p["vel"].clamp(Vector2(-10, -5), Vector2(10, 5))

		# Wrap around
		if p["pos"].x < 0: p["pos"].x = bounds
		if p["pos"].x > bounds: p["pos"].x = 0
		if p["pos"].y < 0: p["pos"].y = bounds
		if p["pos"].y > bounds: p["pos"].y = 0

func _draw_dust_particles():
	var dust_color = Color(0.8, 0.6, 0.4)
	for p in _dust_particles:
		var col = Color(dust_color.r, dust_color.g, dust_color.b, p["alpha"])
		draw_circle(p["pos"], p["size"], col)

# ============================================================================
# CRISIS INDICATORS
# ============================================================================

func set_crisis_building(building_id: String, is_crisis: bool):
	if is_crisis and building_id not in _crisis_buildings:
		_crisis_buildings.append(building_id)
	elif not is_crisis and building_id in _crisis_buildings:
		_crisis_buildings.erase(building_id)

func _draw_crisis_indicators():
	var flash = sin(_alert_flash_timer) > 0

	for building_id in _crisis_buildings:
		var pos = _building_placements.get(building_id, Vector2(-1, -1))
		if pos.x < 0:
			continue

		var center = Vector2(
			pos.x * CELL_SIZE + CELL_SIZE / 2,
			pos.y * CELL_SIZE + CELL_SIZE / 2
		)

		# Flashing red circle
		if flash:
			draw_circle(center, CELL_SIZE * 0.7, Color(1, 0, 0, 0.3))
			draw_circle(center, CELL_SIZE * 0.7, Color.RED, false, 2.0)

		# Warning icon
		var font = ThemeDB.fallback_font
		draw_string(font, center + Vector2(-6, -CELL_SIZE/2 - 5), "⚠", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.RED)

# ============================================================================
# EVENT EFFECTS INTEGRATION
# ============================================================================

func trigger_event_effect(effect_type: String, duration: float = 5.0):
	"""Called by the UI when events happen to trigger visual feedback"""
	_current_event_effect = effect_type
	_event_effect_timer = duration

	match effect_type:
		"sandstorm":
			_sandstorm_active = true
		"rescue":
			# Trigger a rescue animation from a random building to another
			if _building_placements.size() >= 2:
				var keys = _building_placements.keys()
				var from_pos = _building_placements[keys[0]]
				var to_pos = _building_placements[keys[randi() % keys.size()]]
				trigger_rescue(
					Vector2(from_pos.x * CELL_SIZE + CELL_SIZE/2, from_pos.y * CELL_SIZE + CELL_SIZE/2),
					Vector2(to_pos.x * CELL_SIZE + CELL_SIZE/2, to_pos.y * CELL_SIZE + CELL_SIZE/2)
				)
		"construction":
			# Add extra work particles
			for i in range(20):
				_spawn_random_work_particle()
		"crisis":
			# Mark a random building as in crisis
			if not _buildings.is_empty():
				var building = _buildings[randi() % _buildings.size()]
				set_crisis_building(building.get("id", ""), true)

func _update_event_effects(delta: float):
	if _event_effect_timer > 0:
		_event_effect_timer -= delta
		if _event_effect_timer <= 0:
			# Effect ended
			match _current_event_effect:
				"sandstorm":
					_sandstorm_active = false
				"crisis":
					_crisis_buildings.clear()
			_current_event_effect = ""

# ============================================================================
# PUBLIC EFFECT TRIGGERS
# ============================================================================

func start_sandstorm():
	trigger_event_effect("sandstorm", 8.0)

func stop_sandstorm():
	_sandstorm_active = false

func trigger_building_crisis(building_id: String):
	set_crisis_building(building_id, true)
	trigger_event_effect("crisis", 5.0)

func clear_building_crisis(building_id: String):
	set_crisis_building(building_id, false)

func set_robot_count(count: int):
	"""Dynamically adjust robot count based on colony needs"""
	var current = _robots.size()
	if count > current:
		# Add more robots
		for i in range(count - current):
			var robot = {
				"id": "robot_%d" % (_robots.size()),
				"pos": _random_position_in_colony(),
				"target": _random_position_in_colony(),
				"task": "idle",
				"color": ROBOT_COLOR,
				"trail": []
			}
			_robots.append(robot)
	elif count < current:
		# Remove excess robots (from the end)
		_robots.resize(count)

func get_robot_count() -> int:
	return _robots.size()

func set_priority_alerts(alerts: Array):
	"""Set the current priority alerts to display
	Each alert: {priority: 0-2, message: String, icon: String}
	priority 0=info (cyan), 1=warning (yellow), 2=critical (red pulsing)"""
	_priority_alerts = alerts

func clear_priority_alerts():
	_priority_alerts.clear()
