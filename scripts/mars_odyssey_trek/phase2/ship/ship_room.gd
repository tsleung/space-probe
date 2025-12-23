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

# Visuals
var floor_rect: ColorRect
var label: Label
var damage_overlay: ColorRect
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
	damage_repaired.emit()

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

func has_crew_with_role(role: String) -> bool:
	for crew in crew_inside:
		if crew.role == role:
			return true
	return false

func get_crew_count() -> int:
	return crew_inside.size()
