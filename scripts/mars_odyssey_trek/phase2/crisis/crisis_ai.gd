extends Node
class_name CrisisAI

## AI Controller for CRISIS Mode
## Assigns crew to crises with local awareness and travel cost consideration
## Designed to "barely cope" - creates visible struggle under pressure

const CrisisTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_types.gd")
const TileGrid = preload("res://scripts/mars_odyssey_trek/phase2/crisis/tile_grid.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# REFERENCES
# ============================================================================

var crisis_manager: Node  # CrisisManager
var crisis_controller: Node  # CrisisModeController (for tile-based tasks)
var tile_grid: TileGrid
var ship_view: Node2D

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var enabled: bool = true
@export var reaction_delay: float = 1.5  # Longer delay for visible hesitation
@export var reassignment_interval: float = 2.5  # How often to re-evaluate

# Panic thresholds
const PANIC_THRESHOLD = 3  # Start panicking at this many active crises
const PANIC_MISTAKE_CHANCE = 0.20  # 20% chance of suboptimal choice when panicking
const PANIC_FORGET_ITEM_CHANCE = 0.10  # 10% chance to forget item

# Priority weights
const WEIGHT_SEVERITY = 100
const WEIGHT_TIME = 5
const WEIGHT_SPECIALIST = 20
const WEIGHT_TRAVEL_COST = -3  # Penalty per tile of distance
const WEIGHT_FETCH_COST = -2   # Additional penalty if needs item

# ============================================================================
# STATE
# ============================================================================

var reaction_queue: Array = []  # Crises waiting for reaction delay
var reassignment_timer: float = 0.0
var is_panicking: bool = false
var crew_positions: Dictionary = {}  # role -> current tile (cached)

# ============================================================================
# INITIALIZATION
# ============================================================================

func connect_to_manager(manager: Node) -> void:
	crisis_manager = manager
	if crisis_manager:
		crisis_manager.crisis_spawned.connect(_on_crisis_spawned)
		crisis_manager.crisis_resolved.connect(_on_crisis_resolved)
		crisis_manager.crisis_escalated.connect(_on_crisis_escalated)

func setup_tile_mode(controller: Node, grid: TileGrid, view: Node2D) -> void:
	## Set up for CRISIS mode with tile-based movement
	crisis_controller = controller
	tile_grid = grid
	ship_view = view

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if not enabled:
		return

	# Update panic state
	_update_panic_state()

	# Update crew position cache
	_update_crew_positions()

	# Process reaction queue
	_process_reaction_queue(delta)

	# Periodic reassignment check
	reassignment_timer += delta
	if reassignment_timer >= reassignment_interval:
		reassignment_timer = 0.0
		_evaluate_assignments()

func _update_panic_state() -> void:
	## Check if AI should be panicking
	if not crisis_manager:
		is_panicking = false
		return

	var active_count = crisis_manager.get_crisis_count()
	is_panicking = active_count >= PANIC_THRESHOLD

func _update_crew_positions() -> void:
	## Cache crew tile positions for distance calculations
	if not ship_view:
		return

	for role in ["commander", "engineer", "scientist", "medical"]:
		var crew = _get_crew_member(role)
		if crew and crew.has_method("get_current_tile"):
			crew_positions[role] = crew.get_current_tile()

func _process_reaction_queue(delta: float) -> void:
	var to_remove: Array = []

	for i in range(reaction_queue.size()):
		var item = reaction_queue[i]
		item.delay -= delta

		if item.delay <= 0:
			_try_assign_crew_to_crisis(item.crisis)
			to_remove.append(i)

	# Remove processed items (reverse order to maintain indices)
	for i in range(to_remove.size() - 1, -1, -1):
		reaction_queue.remove_at(to_remove[i])

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_crisis_spawned(crisis: Dictionary) -> void:
	# Queue for assignment after reaction delay
	var delay = reaction_delay
	if is_panicking:
		# Slower reaction when panicking
		delay *= 1.5

	reaction_queue.append({
		"crisis": crisis,
		"delay": delay
	})

func _on_crisis_resolved(_crisis: Dictionary) -> void:
	# Re-evaluate when a crisis is resolved
	_evaluate_assignments()

func _on_crisis_escalated(crisis: Dictionary, _old_severity: int, new_severity: int) -> void:
	# If crisis escalated to CRITICAL or higher, prioritize it
	if new_severity >= CrisisTypes.Severity.CRITICAL:
		_prioritize_crisis(crisis)

# ============================================================================
# LOCAL AWARENESS
# ============================================================================

func _get_visible_crises(crew_role: String) -> Array:
	## Get crises visible to this crew member based on local awareness
	## Crew can see:
	## 1. Crises in their current room
	## 2. Crises in adjacent rooms
	## 3. Any crisis at severity >= ACTIVE (ship-wide alarm)

	if not crisis_manager:
		return []

	var all_crises = crisis_manager.get_active_crises()
	var visible = []

	var crew_tile = crew_positions.get(crew_role, Vector2i(15, 6))
	var crew_room = tile_grid.get_room_at_tile(crew_tile) if tile_grid else ShipTypes.RoomType.BRIDGE

	for crisis in all_crises:
		# Always see crises at ACTIVE or higher (alarm heard ship-wide)
		if crisis.severity >= CrisisTypes.Severity.ACTIVE:
			visible.append(crisis)
			continue

		# See crises in same room
		var crisis_room = crisis.get("room", ShipTypes.RoomType.ENGINEERING)
		if crisis_room == crew_room:
			visible.append(crisis)
			continue

		# See crises in adjacent rooms
		if _are_rooms_adjacent(crew_room, crisis_room):
			visible.append(crisis)

	return visible

func _are_rooms_adjacent(room_a: ShipTypes.RoomType, room_b: ShipTypes.RoomType) -> bool:
	## Check if two rooms are adjacent (share a corridor)
	const ADJACENT_ROOMS = {
		ShipTypes.RoomType.MEDICAL: [ShipTypes.RoomType.QUARTERS, ShipTypes.RoomType.CARGO_BAY],
		ShipTypes.RoomType.QUARTERS: [ShipTypes.RoomType.MEDICAL, ShipTypes.RoomType.CORRIDOR, ShipTypes.RoomType.LIFE_SUPPORT],
		ShipTypes.RoomType.CORRIDOR: [ShipTypes.RoomType.QUARTERS, ShipTypes.RoomType.BRIDGE, ShipTypes.RoomType.ENGINEERING],
		ShipTypes.RoomType.BRIDGE: [ShipTypes.RoomType.CORRIDOR],
		ShipTypes.RoomType.CARGO_BAY: [ShipTypes.RoomType.MEDICAL, ShipTypes.RoomType.LIFE_SUPPORT],
		ShipTypes.RoomType.LIFE_SUPPORT: [ShipTypes.RoomType.CARGO_BAY, ShipTypes.RoomType.QUARTERS, ShipTypes.RoomType.ENGINEERING],
		ShipTypes.RoomType.ENGINEERING: [ShipTypes.RoomType.LIFE_SUPPORT, ShipTypes.RoomType.CORRIDOR]
	}

	var adjacent = ADJACENT_ROOMS.get(room_a, [])
	return room_b in adjacent

# ============================================================================
# ASSIGNMENT LOGIC (CRISIS Mode)
# ============================================================================

func _try_assign_crew_to_crisis(crisis: Dictionary) -> void:
	## Find and assign the best crew for this crisis
	if crisis.assigned_crew != "":
		return  # Already assigned

	var best_crew = _find_best_crew_for_crisis(crisis)
	if best_crew != "":
		_assign_crew(best_crew, crisis)

func _find_best_crew_for_crisis(crisis: Dictionary) -> String:
	## Returns the best available crew role, considering travel costs
	var available_crew = _get_available_crew()
	if available_crew.is_empty():
		return ""

	var best_role = ""
	var best_score = -INF

	for role in available_crew:
		# Check if crew can see this crisis (local awareness)
		var visible = _get_visible_crises(role)
		var can_see = false
		for v in visible:
			if v.id == crisis.id:
				can_see = true
				break

		if not can_see:
			continue  # Can't assign to crisis they can't see!

		var score = _calculate_crew_score(role, crisis)

		# Panic behavior: sometimes pick non-optimal
		if is_panicking and randf() < PANIC_MISTAKE_CHANCE:
			score += randf_range(-30, 30)  # Add randomness

		if score > best_score:
			best_score = score
			best_role = role

	return best_role

func _get_available_crew() -> Array:
	## Returns list of crew roles not currently busy
	var available = []
	for role in ["commander", "engineer", "scientist", "medical"]:
		if crisis_controller and crisis_controller.has_method("is_crew_busy"):
			if not crisis_controller.is_crew_busy(role):
				available.append(role)
		elif crisis_manager and not crisis_manager.is_crew_busy(role):
			available.append(role)
	return available

func _calculate_crew_score(crew_role: String, crisis: Dictionary) -> float:
	## Score how well this crew member matches this crisis
	## Includes travel cost and fetch requirements

	var score = 0.0

	# Severity urgency (most important)
	score += crisis.severity * WEIGHT_SEVERITY

	# Time waiting (prioritize older crises)
	score += min(crisis.total_time * WEIGHT_TIME, 25)

	# Specialist bonus
	var efficiency = CrisisTypes.get_crew_efficiency(crisis, crew_role)
	if efficiency > 1.0:
		score += WEIGHT_SPECIALIST

	# TRAVEL COST (key for pressure)
	var travel_tiles = _get_travel_distance(crew_role, crisis)
	score += travel_tiles * WEIGHT_TRAVEL_COST

	# FETCH COST (if item required)
	var crisis_type = crisis.get("type", 0)
	if CrisisTypes.crisis_requires_item(crisis_type):
		var crew = _get_crew_member(crew_role)
		var has_item = false
		if crew and crew.has_method("get_carried_item"):
			var needed = CrisisTypes.get_required_item(crisis_type)
			has_item = crew.get_carried_item() == needed

		if not has_item:
			# Need to go to cargo first
			var cargo_tiles = _get_distance_to_cargo(crew_role)
			score += cargo_tiles * WEIGHT_FETCH_COST

	return score

func _get_travel_distance(crew_role: String, crisis: Dictionary) -> int:
	## Calculate tile distance from crew to crisis location
	if not tile_grid:
		return 10  # Default estimate

	var crew_tile = crew_positions.get(crew_role, Vector2i(15, 6))
	var crisis_room = crisis.get("room", ShipTypes.RoomType.ENGINEERING)
	var crisis_tile = TileGrid.get_room_station_tile(crisis_room)

	return tile_grid.get_tile_distance(crew_tile, crisis_tile)

func _get_distance_to_cargo(crew_role: String) -> int:
	## Calculate tile distance from crew to cargo bay
	if not tile_grid:
		return 8  # Default estimate

	var crew_tile = crew_positions.get(crew_role, Vector2i(15, 6))
	var cargo_tile = TileGrid.get_room_station_tile(ShipTypes.RoomType.CARGO_BAY)

	return tile_grid.get_tile_distance(crew_tile, cargo_tile)

func _assign_crew(crew_role: String, crisis: Dictionary) -> void:
	## Assign crew to crisis through the controller
	if crisis_controller and crisis_controller.has_method("assign_crisis_to_crew"):
		# Panic behavior: sometimes forget to grab item
		if is_panicking and randf() < PANIC_FORGET_ITEM_CHANCE:
			print("[AI] %s panicking - might forget item!" % crew_role.capitalize())
			# Still assign, but controller will handle the failure

		crisis_controller.assign_crisis_to_crew(crew_role, crisis.id)
	elif crisis_manager:
		# Fallback to direct assignment
		crisis_manager.assign_crew(crew_role, crisis.id)

# ============================================================================
# REASSIGNMENT
# ============================================================================

func _evaluate_assignments() -> void:
	## Re-evaluate all assignments to optimize
	if not crisis_manager:
		return

	var unassigned_crises = crisis_manager.get_unassigned_crises()
	if unassigned_crises.is_empty():
		return

	# Sort by urgency (highest severity first)
	unassigned_crises.sort_custom(_compare_crisis_urgency)

	# Try to assign each unassigned crisis
	for crisis in unassigned_crises:
		_try_assign_crew_to_crisis(crisis)

	# Check if we should steal crew from lower-priority crises
	_consider_reassignments()

func _compare_crisis_urgency(a: Dictionary, b: Dictionary) -> bool:
	if a.severity != b.severity:
		return a.severity > b.severity
	return a.total_time > b.total_time

func _prioritize_crisis(crisis: Dictionary) -> void:
	## A crisis has become critical - consider stealing crew
	if crisis.assigned_crew != "":
		return

	# Find any crew working on lower-severity crisis
	var best_steal = ""
	var lowest_severity = crisis.severity

	for role in ["commander", "engineer", "scientist", "medical"]:
		var assignment = ""
		if crisis_controller:
			var task = crisis_controller.get_crew_task(role)
			assignment = task.get("crisis_id", "")
		elif crisis_manager:
			assignment = crisis_manager.get_crew_assignment(role)

		if assignment == "":
			continue

		var current_crisis = crisis_manager.get_crisis_by_id(assignment)
		if current_crisis.is_empty():
			continue

		if current_crisis.severity < lowest_severity:
			lowest_severity = current_crisis.severity
			best_steal = role

	if best_steal != "":
		print("[AI] CRITICAL! Reassigning %s to %s" % [best_steal.capitalize(), crisis.name])
		_assign_crew(best_steal, crisis)

func _consider_reassignments() -> void:
	## Ensure critical crises have someone assigned
	if not crisis_manager:
		return

	var crises = crisis_manager.get_active_crises()

	for crisis in crises:
		if crisis.severity >= CrisisTypes.Severity.CRITICAL and crisis.assigned_crew == "":
			_prioritize_crisis(crisis)

# ============================================================================
# HELPERS
# ============================================================================

func _get_crew_member(role: String) -> Node:
	if not ship_view:
		return null

	if ship_view.has_method("get_crew_member"):
		return ship_view.get_crew_member(role)

	for child in ship_view.get_children():
		if child is CharacterBody2D and child.get("role") == role:
			return child

	return null

# ============================================================================
# CONTROL
# ============================================================================

func set_enabled(e: bool) -> void:
	enabled = e
	if not enabled:
		reaction_queue.clear()

func is_ai_panicking() -> bool:
	return is_panicking
