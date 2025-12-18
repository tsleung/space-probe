extends Control
class_name ColonyView

## Visual Colony Renderer
## RimWorld-lite style view - shows colony growing on one screen
## Buildings as colored blocks, colonists as dots

# Store reference for direct state access
var _store: Node = null

# ============================================================================
# CONSTANTS
# ============================================================================

const GRID_SIZE = 16  # 16x16 grid
const CELL_SIZE = 32  # Pixels per cell
const COLONIST_SIZE = 6
const BUILDING_PADDING = 2

# Building colors by type
const BUILDING_COLORS = {
	"hab": Color(0.3, 0.5, 0.7),      # Blue - housing
	"food": Color(0.3, 0.6, 0.3),     # Green - food production
	"power": Color(0.8, 0.7, 0.2),    # Yellow - power
	"medical": Color(0.8, 0.3, 0.3),  # Red - medical
	"science": Color(0.6, 0.3, 0.7),  # Purple - science
	"industry": Color(0.5, 0.4, 0.3), # Brown - industry
	"social": Color(0.7, 0.5, 0.6),   # Pink - social
	"infra": Color(0.4, 0.4, 0.4),    # Gray - infrastructure
}

# Generation colors for colonists
const GEN_COLORS = {
	0: Color(0.9, 0.8, 0.3),  # Earth-born - Gold
	1: Color(0.3, 0.8, 0.9),  # First gen - Cyan
	2: Color(0.3, 0.9, 0.4),  # Second gen - Green
	3: Color(0.9, 0.9, 0.3),  # Third gen+ - Yellow
}

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

func _process(delta: float):
	_time_accumulator += delta
	# Update colonist positions smoothly
	_update_colonist_movement(delta)
	queue_redraw()

func _draw():
	# Refresh from store if arrays are empty but store has data
	if _colonists.is_empty() and _store:
		_refresh_from_store()
	_draw_grid()
	_draw_buildings()
	_draw_colonists()
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
		_buildings = state.get("buildings", []).duplicate(true)
		_colonists = state.get("colonists", []).duplicate(true)

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
		var pos = _building_placements.get(building.id, Vector2(-1, -1))
		if pos.x < 0:
			continue

		var rect = Rect2(
			pos.x * CELL_SIZE + BUILDING_PADDING,
			pos.y * CELL_SIZE + BUILDING_PADDING,
			CELL_SIZE - BUILDING_PADDING * 2,
			CELL_SIZE - BUILDING_PADDING * 2
		)

		# Get color by building category
		var color = _get_building_color(building.type)

		# Dim if under construction
		if building.is_under_construction:
			color = color.darkened(0.5)
			# Draw construction progress
			var progress_rect = Rect2(
				rect.position.x,
				rect.position.y + rect.size.y - 4,
				rect.size.x * building.construction_progress,
				4
			)
			draw_rect(rect, color, true)
			draw_rect(progress_rect, Color.WHITE, true)
		elif not building.is_operational:
			# Broken - show red outline
			draw_rect(rect, color.darkened(0.3), true)
			draw_rect(rect, Color.RED, false, 2.0)
		else:
			draw_rect(rect, color, true)

		# Draw building icon/letter
		var label = _get_building_label(building.type)
		var font = ThemeDB.fallback_font
		var font_size = 14
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = rect.position + (rect.size - text_size) / 2 + Vector2(0, text_size.y * 0.7)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_colonists():
	for colonist in _colonists:
		if not colonist.is_alive:
			continue

		var pos = _colonist_positions.get(colonist.id, Vector2(-1, -1))
		if pos.x < 0:
			# Assign initial position
			pos = _random_position_in_colony()
			_colonist_positions[colonist.id] = pos

		# Color by generation
		var color = GEN_COLORS.get(colonist.generation, Color.WHITE)

		# Size by life stage
		var size = COLONIST_SIZE
		if colonist.life_stage == ColonySimTypes.LifeStage.CHILD or colonist.life_stage == ColonySimTypes.LifeStage.INFANT:
			size = COLONIST_SIZE * 0.6
		elif colonist.life_stage == ColonySimTypes.LifeStage.ELDER:
			color = color.darkened(0.2)

		# Health affects brightness
		if colonist.health < 50:
			color = color.darkened(0.3)

		draw_circle(pos, size, color)

func _draw_stats_overlay():
	# Draw a small stats overlay in the corner
	var font = ThemeDB.fallback_font
	var font_size = 12

	var alive_count = 0
	for c in _colonists:
		if c.is_alive:
			alive_count += 1

	var building_count = _buildings.size()
	var operational = 0
	for b in _buildings:
		if b.is_operational and not b.is_under_construction:
			operational += 1

	# Semi-transparent background
	var overlay_rect = Rect2(GRID_SIZE * CELL_SIZE - 90, 5, 85, 45)
	draw_rect(overlay_rect, Color(0, 0, 0, 0.6), true)

	var y_offset = 18
	draw_string(font, Vector2(overlay_rect.position.x + 5, overlay_rect.position.y + y_offset),
		"Pop: %d" % alive_count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(overlay_rect.position.x + 5, overlay_rect.position.y + y_offset + 14),
		"Bldg: %d/%d" % [operational, building_count], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

# ============================================================================
# BUILDING PLACEMENT
# ============================================================================

func _update_building_placements():
	# Place new buildings that don't have positions yet
	for building in _buildings:
		if not _building_placements.has(building.id):
			var pos = _find_building_position()
			if pos.x >= 0:
				_building_placements[building.id] = pos
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
		ColonySimTypes.BuildingType.HAB_POD, ColonySimTypes.BuildingType.APARTMENT_BLOCK, \
		ColonySimTypes.BuildingType.LUXURY_QUARTERS, ColonySimTypes.BuildingType.BARRACKS:
			return BUILDING_COLORS["hab"]
		ColonySimTypes.BuildingType.GREENHOUSE, ColonySimTypes.BuildingType.HYDROPONICS, \
		ColonySimTypes.BuildingType.PROTEIN_VATS:
			return BUILDING_COLORS["food"]
		ColonySimTypes.BuildingType.SOLAR_ARRAY, ColonySimTypes.BuildingType.WIND_TURBINE, \
		ColonySimTypes.BuildingType.RTG, ColonySimTypes.BuildingType.FISSION_REACTOR:
			return BUILDING_COLORS["power"]
		ColonySimTypes.BuildingType.MEDICAL_BAY, ColonySimTypes.BuildingType.HOSPITAL:
			return BUILDING_COLORS["medical"]
		ColonySimTypes.BuildingType.LAB, ColonySimTypes.BuildingType.RESEARCH_CENTER, \
		ColonySimTypes.BuildingType.SCHOOL, ColonySimTypes.BuildingType.UNIVERSITY:
			return BUILDING_COLORS["science"]
		ColonySimTypes.BuildingType.WORKSHOP, ColonySimTypes.BuildingType.FACTORY:
			return BUILDING_COLORS["industry"]
		ColonySimTypes.BuildingType.RECREATION_CENTER, ColonySimTypes.BuildingType.TEMPLE, \
		ColonySimTypes.BuildingType.GOVERNMENT_HALL:
			return BUILDING_COLORS["social"]
		_:
			return BUILDING_COLORS["infra"]

func _get_building_label(building_type: int) -> String:
	match building_type:
		ColonySimTypes.BuildingType.HAB_POD: return "H"
		ColonySimTypes.BuildingType.APARTMENT_BLOCK: return "A"
		ColonySimTypes.BuildingType.GREENHOUSE: return "G"
		ColonySimTypes.BuildingType.HYDROPONICS: return "Hy"
		ColonySimTypes.BuildingType.SOLAR_ARRAY: return "S"
		ColonySimTypes.BuildingType.FISSION_REACTOR: return "R"
		ColonySimTypes.BuildingType.MEDICAL_BAY: return "M"
		ColonySimTypes.BuildingType.HOSPITAL: return "H+"
		ColonySimTypes.BuildingType.SCHOOL: return "Sc"
		ColonySimTypes.BuildingType.LAB: return "L"
		ColonySimTypes.BuildingType.WORKSHOP: return "W"
		ColonySimTypes.BuildingType.FACTORY: return "F"
		ColonySimTypes.BuildingType.WATER_EXTRACTOR: return "We"
		ColonySimTypes.BuildingType.RECREATION_CENTER: return "Re"
		ColonySimTypes.BuildingType.GOVERNMENT_HALL: return "Go"
		_: return "?"

# ============================================================================
# COLONIST MOVEMENT
# ============================================================================

func _update_colonist_targets():
	# Occasionally assign new targets for colonists to walk to
	for colonist in _colonists:
		if not colonist.is_alive:
			continue

		if not _colonist_targets.has(colonist.id) or randf() < 0.02:
			_colonist_targets[colonist.id] = _random_position_in_colony()

func _update_colonist_movement(delta: float):
	var speed = 30.0  # Pixels per second

	for colonist in _colonists:
		if not colonist.is_alive:
			continue

		var current = _colonist_positions.get(colonist.id, Vector2(-1, -1))
		var target = _colonist_targets.get(colonist.id, current)

		if current.x < 0:
			current = _random_position_in_colony()
			_colonist_positions[colonist.id] = current

		# Move toward target
		var direction = (target - current).normalized()
		var distance = current.distance_to(target)

		if distance > 5:
			var move = direction * speed * delta
			if move.length() > distance:
				_colonist_positions[colonist.id] = target
			else:
				_colonist_positions[colonist.id] = current + move
		else:
			# Reached target, get new one
			if randf() < 0.1:
				_colonist_targets[colonist.id] = _random_position_in_colony()

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
