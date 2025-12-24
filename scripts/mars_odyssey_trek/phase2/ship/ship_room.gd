extends Area2D
class_name ShipRoom

## A room in the ship that crew can enter and work in

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal crew_entered(crew: Node2D)
signal crew_exited(crew: Node2D)
signal damage_started(severity: float)
signal damage_repaired()

# ============================================================================
# PROPERTIES
# ============================================================================

@export var room_type: ShipTypes.RoomType = ShipTypes.RoomType.CORRIDOR
@export var room_size: Vector2 = Vector2(100, 80)

var crew_inside: Array[Node2D] = []
var is_damaged: bool = false
var damage_severity: float = 0.0
var repair_in_progress: bool = false
var repair_progress: float = 0.0

# Visuals
var floor_rect: ColorRect
var label: Label
var damage_overlay: ColorRect
var repair_bar_bg: ColorRect
var repair_bar_fill: ColorRect
var work_position_marker: Marker2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_collision()
	_setup_visuals()
	_connect_signals()

func _setup_collision() -> void:
	# Create collision shape for the room
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = room_size
	collision.shape = shape
	add_child(collision)

func _setup_visuals() -> void:
	# Floor
	floor_rect = ColorRect.new()
	floor_rect.size = room_size
	floor_rect.position = -room_size / 2
	floor_rect.color = ShipTypes.get_room_color(room_type)
	add_child(floor_rect)

	# Room label
	label = Label.new()
	label.text = ShipTypes.get_room_name(room_type)
	label.position = Vector2(-room_size.x / 2 + 5, -room_size.y / 2 + 2)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(label)

	# Damage overlay (initially hidden)
	damage_overlay = ColorRect.new()
	damage_overlay.size = room_size
	damage_overlay.position = -room_size / 2
	damage_overlay.color = Color(1, 0, 0, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)

	# Repair progress bar (initially hidden)
	var bar_width = room_size.x * 0.7
	var bar_height = 6.0

	repair_bar_bg = ColorRect.new()
	repair_bar_bg.size = Vector2(bar_width, bar_height)
	repair_bar_bg.position = Vector2(-bar_width / 2, room_size.y / 2 - bar_height - 4)
	repair_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	repair_bar_bg.visible = false
	add_child(repair_bar_bg)

	repair_bar_fill = ColorRect.new()
	repair_bar_fill.size = Vector2(0, bar_height - 2)
	repair_bar_fill.position = repair_bar_bg.position + Vector2(1, 1)
	repair_bar_fill.color = Color(0.3, 0.8, 0.3)
	repair_bar_fill.visible = false
	add_child(repair_bar_fill)

	# Work position (center of room)
	work_position_marker = Marker2D.new()
	work_position_marker.position = Vector2.ZERO
	add_child(work_position_marker)

func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	_update_damage_visual(delta)

func _update_damage_visual(delta: float) -> void:
	if is_damaged:
		# Pulsing red overlay
		var pulse = 0.2 + sin(Time.get_ticks_msec() * 0.008) * 0.1
		damage_overlay.color = Color(1, 0, 0, pulse * damage_severity)

		# Flicker the room lights
		var flicker = 0.7 + randf() * 0.3 if randf() < 0.1 else 1.0
		floor_rect.modulate = Color(flicker, flicker * 0.8, flicker * 0.8)
	else:
		damage_overlay.color = Color(1, 0, 0, 0)
		floor_rect.modulate = Color.WHITE

# ============================================================================
# DAMAGE SYSTEM
# ============================================================================

func apply_damage(severity: float) -> void:
	is_damaged = true
	damage_severity = clamp(severity, 0.0, 1.0)
	damage_started.emit(severity)

func repair_damage() -> void:
	is_damaged = false
	damage_severity = 0.0
	repair_in_progress = false
	repair_progress = 0.0
	hide_repair_progress()
	damage_repaired.emit()

# ============================================================================
# REPAIR PROGRESS VISUALIZATION
# ============================================================================

func show_repair_progress(progress: float) -> void:
	## Show repair progress bar (0.0 to 1.0)
	repair_in_progress = true
	repair_progress = clamp(progress, 0.0, 1.0)

	repair_bar_bg.visible = true
	repair_bar_fill.visible = true

	# Update fill width based on progress
	var max_width = repair_bar_bg.size.x - 2
	repair_bar_fill.size.x = max_width * repair_progress

	# Color transitions: red → yellow → green
	if repair_progress < 0.5:
		var t = repair_progress * 2.0
		repair_bar_fill.color = Color(1.0, t, 0.0)  # Red to yellow
	else:
		var t = (repair_progress - 0.5) * 2.0
		repair_bar_fill.color = Color(1.0 - t, 1.0, 0.0)  # Yellow to green

func hide_repair_progress() -> void:
	## Hide repair progress bar
	repair_in_progress = false
	repair_progress = 0.0
	repair_bar_bg.visible = false
	repair_bar_fill.visible = false

# ============================================================================
# CREW TRACKING
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	# Check if it's a crew member by checking for the role property
	if body.has_method("get_state_text"):
		if body not in crew_inside:
			crew_inside.append(body)
			crew_entered.emit(body)

func _on_body_exited(body: Node2D) -> void:
	if body in crew_inside:
		crew_inside.erase(body)
		crew_exited.emit(body)

# ============================================================================
# GETTERS
# ============================================================================

func get_work_position() -> Vector2:
	return global_position + work_position_marker.position

func get_random_idle_position() -> Vector2:
	## Get a random position within the room for varied idle spots
	var padding = 10.0
	var half_w = (room_size.x / 2) - padding
	var half_h = (room_size.y / 2) - padding

	var offset = Vector2(
		randf_range(-half_w, half_w),
		randf_range(-half_h, half_h)
	)
	return global_position + offset

func get_idle_spots() -> Array[Vector2]:
	## Get predefined idle spots within the room (corners, center, sides)
	var spots: Array[Vector2] = []
	var padding = 12.0
	var hw = (room_size.x / 2) - padding
	var hh = (room_size.y / 2) - padding

	# Center (work position)
	spots.append(global_position)
	# Four corners
	spots.append(global_position + Vector2(-hw, -hh))
	spots.append(global_position + Vector2(hw, -hh))
	spots.append(global_position + Vector2(-hw, hh))
	spots.append(global_position + Vector2(hw, hh))
	# Midpoints
	spots.append(global_position + Vector2(0, -hh))
	spots.append(global_position + Vector2(0, hh))
	spots.append(global_position + Vector2(-hw, 0))
	spots.append(global_position + Vector2(hw, 0))

	return spots

func has_crew_with_role(role: String) -> bool:
	for crew in crew_inside:
		if crew.role == role:
			return true
	return false

func get_crew_count() -> int:
	return crew_inside.size()

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

var flash_tween: Tween
var original_color: Color

func flash(color: Color, duration: float = 0.8) -> void:
	## Flash the room with a color to indicate activity
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()

	original_color = floor_rect.color

	# Create flash effect
	flash_tween = create_tween()
	flash_tween.tween_property(floor_rect, "color", color, duration * 0.2)
	flash_tween.tween_property(floor_rect, "color", original_color, duration * 0.8)

	# Also flash the modulate for extra effect
	var flash_modulate = Color(1.0 + color.r * 0.5, 1.0 + color.g * 0.5, 1.0 + color.b * 0.5)
	var mod_tween = create_tween()
	mod_tween.tween_property(floor_rect, "modulate", flash_modulate, duration * 0.15)
	mod_tween.tween_property(floor_rect, "modulate", Color.WHITE, duration * 0.85)

func hide_label() -> void:
	## Hide the room label (for junction corridors, etc.)
	if label:
		label.visible = false

func show_label() -> void:
	## Show the room label
	if label:
		label.visible = true
