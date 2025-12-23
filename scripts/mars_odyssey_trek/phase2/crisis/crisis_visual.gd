extends Node2D
class_name CrisisVisual

## Visual representation of the crisis system
## Shows crisis overlays on rooms, assignment lines, and status indicators

const CrisisTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_types.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# REFERENCES
# ============================================================================

var crisis_manager: Node  # CrisisManager
var ship_view: Node2D  # ShipView with rooms

# ============================================================================
# VISUAL ELEMENTS
# ============================================================================

var room_overlays: Dictionary = {}  # room_type -> overlay node
var assignment_lines: Dictionary = {}  # crisis_id -> Line2D
var crisis_badges: Dictionary = {}  # crisis_id -> badge node

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var flash_speed: float = 4.0  # Flashes per second for CATASTROPHIC
@export var pulse_speed: float = 2.0  # Pulses per second for normal

# ============================================================================
# INITIALIZATION
# ============================================================================

func setup(manager: Node, view: Node2D) -> void:
	crisis_manager = manager
	ship_view = view

	# Connect to crisis signals
	crisis_manager.crisis_spawned.connect(_on_crisis_spawned)
	crisis_manager.crisis_resolved.connect(_on_crisis_resolved)
	crisis_manager.crisis_escalated.connect(_on_crisis_escalated)
	crisis_manager.crew_assigned.connect(_on_crew_assigned)
	crisis_manager.crew_unassigned.connect(_on_crew_unassigned)

	# Create room overlays
	_create_room_overlays()

func _create_room_overlays() -> void:
	## Create invisible overlays for each room that we'll show during crises
	if not ship_view:
		return

	var room_types = [
		ShipTypes.RoomType.BRIDGE,
		ShipTypes.RoomType.ENGINEERING,
		ShipTypes.RoomType.LIFE_SUPPORT,
		ShipTypes.RoomType.MEDICAL,
		ShipTypes.RoomType.CARGO_BAY,
		ShipTypes.RoomType.QUARTERS
	]

	for room_type in room_types:
		var room = ship_view.get_room(room_type)
		if room:
			var overlay = _create_overlay(room)
			room_overlays[room_type] = overlay

func _create_overlay(room: Node2D) -> Node2D:
	## Create a crisis overlay for a room
	var overlay = Node2D.new()
	overlay.name = "CrisisOverlay"
	overlay.visible = false
	room.add_child(overlay)

	# Border flash effect
	var border = Line2D.new()
	border.name = "Border"
	border.width = 4.0
	border.default_color = Color.RED
	border.closed = true

	# Get room size (approximate)
	var size = room.room_size if room.get("room_size") else Vector2(100, 80)
	var half = size / 2
	border.add_point(Vector2(-half.x, -half.y))
	border.add_point(Vector2(half.x, -half.y))
	border.add_point(Vector2(half.x, half.y))
	border.add_point(Vector2(-half.x, half.y))
	overlay.add_child(border)

	# Crisis icon label
	var icon = Label.new()
	icon.name = "Icon"
	icon.text = "!!!"
	icon.add_theme_font_size_override("font_size", 16)
	icon.add_theme_color_override("font_color", Color.WHITE)
	icon.position = Vector2(-15, -size.y / 2 - 20)
	overlay.add_child(icon)

	# Progress bar (for fix progress)
	var progress_bg = ColorRect.new()
	progress_bg.name = "ProgressBG"
	progress_bg.size = Vector2(60, 8)
	progress_bg.position = Vector2(-30, size.y / 2 + 5)
	progress_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	progress_bg.visible = false
	overlay.add_child(progress_bg)

	var progress_fill = ColorRect.new()
	progress_fill.name = "ProgressFill"
	progress_fill.size = Vector2(0, 6)
	progress_fill.position = Vector2(-29, size.y / 2 + 6)
	progress_fill.color = Color(0.3, 0.9, 0.3)
	progress_fill.visible = false
	overlay.add_child(progress_fill)

	return overlay

# ============================================================================
# PROCESS - ANIMATION
# ============================================================================

func _process(delta: float) -> void:
	if not crisis_manager:
		return

	var time = Time.get_ticks_msec() / 1000.0

	# Update each active crisis visual
	for crisis in crisis_manager.get_active_crises():
		_update_crisis_visual(crisis, time)

	# Update assignment lines
	_update_assignment_lines()

func _update_crisis_visual(crisis: Dictionary, time: float) -> void:
	var room_type = crisis.room
	if room_type == null:
		return

	var overlay = room_overlays.get(room_type)
	if not overlay:
		return

	overlay.visible = true

	# Get color based on severity
	var color = CrisisTypes.get_severity_color(crisis.severity)

	# Calculate pulse/flash intensity
	var intensity = 1.0
	if crisis.severity == CrisisTypes.Severity.CATASTROPHIC:
		# Fast flash for catastrophic
		intensity = 0.5 + 0.5 * sin(time * flash_speed * TAU)
	else:
		# Slower pulse for other severities
		intensity = 0.7 + 0.3 * sin(time * pulse_speed * TAU)

	# Apply to border
	var border = overlay.get_node_or_null("Border") as Line2D
	if border:
		border.default_color = color
		border.modulate.a = intensity

	# Update icon
	var icon = overlay.get_node_or_null("Icon") as Label
	if icon:
		icon.text = crisis.icon
		icon.add_theme_color_override("font_color", color)

	# Update progress bar if crew assigned
	var progress_bg = overlay.get_node_or_null("ProgressBG")
	var progress_fill = overlay.get_node_or_null("ProgressFill")
	if progress_bg and progress_fill:
		if crisis.assigned_crew != "":
			progress_bg.visible = true
			progress_fill.visible = true
			progress_fill.size.x = 58 * crisis.fix_progress
		else:
			progress_bg.visible = false
			progress_fill.visible = false

func _update_assignment_lines() -> void:
	## Update lines connecting crew to their assigned crises
	for crisis_id in assignment_lines:
		var line = assignment_lines[crisis_id]
		var crisis = crisis_manager.get_crisis_by_id(crisis_id)

		if crisis.is_empty() or crisis.assigned_crew == "":
			line.visible = false
			continue

		# Get crew position
		var crew_member = ship_view.get_crew_member(crisis.assigned_crew)
		if not crew_member:
			line.visible = false
			continue

		# Get room position
		var room = ship_view.get_room(crisis.room)
		if not room:
			line.visible = false
			continue

		line.visible = true
		line.clear_points()
		line.add_point(crew_member.global_position)
		line.add_point(room.global_position)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_crisis_spawned(crisis: Dictionary) -> void:
	# Show overlay for the room
	var room_type = crisis.room
	if room_type != null and room_overlays.has(room_type):
		room_overlays[room_type].visible = true

	# Create assignment line (hidden until assigned)
	var line = Line2D.new()
	line.name = "AssignmentLine_" + crisis.id
	line.width = 2.0
	line.default_color = Color(0.5, 0.8, 1.0, 0.6)
	line.visible = false
	add_child(line)
	assignment_lines[crisis.id] = line

func _on_crisis_resolved(crisis: Dictionary) -> void:
	# Hide overlay for the room (if no other crisis there)
	var room_type = crisis.room
	if room_type != null:
		# Check if any other crisis in this room
		var other_crisis = crisis_manager.get_crisis_at_room(room_type)
		if other_crisis.is_empty() and room_overlays.has(room_type):
			room_overlays[room_type].visible = false

	# Remove assignment line
	if assignment_lines.has(crisis.id):
		assignment_lines[crisis.id].queue_free()
		assignment_lines.erase(crisis.id)

func _on_crisis_escalated(crisis: Dictionary, _old: int, _new: int) -> void:
	# Flash effect handled in _process
	pass

func _on_crew_assigned(crisis_id: String, _crew_role: String) -> void:
	# Show assignment line
	if assignment_lines.has(crisis_id):
		assignment_lines[crisis_id].visible = true

func _on_crew_unassigned(crisis_id: String, _crew_role: String) -> void:
	# Hide assignment line
	if assignment_lines.has(crisis_id):
		assignment_lines[crisis_id].visible = false

# ============================================================================
# PUBLIC API
# ============================================================================

func get_crisis_at_screen_position(screen_pos: Vector2) -> Dictionary:
	## Returns crisis if click is on a room with an active crisis
	for room_type in room_overlays:
		var overlay = room_overlays[room_type]
		if not overlay.visible:
			continue

		var room = ship_view.get_room(room_type)
		if not room:
			continue

		# Simple distance check
		var dist = screen_pos.distance_to(room.global_position)
		if dist < 60:  # Click radius
			return crisis_manager.get_crisis_at_room(room_type)

	return {}
