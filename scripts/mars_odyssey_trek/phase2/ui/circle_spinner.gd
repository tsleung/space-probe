extends Control
class_name CircleSpinner

## Universal task progress indicator showing time remaining
## Displays a circular progress arc with hours remaining in center
## Used for EVA work, interior repairs, crisis tasks, and all timed activities

# ============================================================================
# SIGNALS
# ============================================================================

signal completed
signal progress_updated(progress: float)

# ============================================================================
# CONSTANTS
# ============================================================================

const DEFAULT_RADIUS: float = 16.0
const DEFAULT_LINE_WIDTH: float = 3.0
const DEFAULT_BG_COLOR: Color = Color(0.3, 0.3, 0.3, 0.6)
const DEFAULT_PROGRESS_COLOR: Color = Color(0.2, 0.8, 0.3, 0.9)
const DEFAULT_CRITICAL_COLOR: Color = Color(0.9, 0.3, 0.2, 0.9)
const CRITICAL_THRESHOLD: float = 0.2  # Show critical color when < 20% time left

# ============================================================================
# EXPORTS
# ============================================================================

@export var radius: float = DEFAULT_RADIUS
@export var line_width: float = DEFAULT_LINE_WIDTH
@export var bg_color: Color = DEFAULT_BG_COLOR
@export var progress_color: Color = DEFAULT_PROGRESS_COLOR
@export var critical_color: Color = DEFAULT_CRITICAL_COLOR
@export var show_label: bool = true
@export var label_suffix: String = "h"  # "h" for hours, "s" for seconds, etc.

# ============================================================================
# STATE
# ============================================================================

var total_time: float = 1.0  # Total time in hours (or any unit)
var elapsed_time: float = 0.0
var is_running: bool = false
var auto_advance: bool = false  # If true, advances based on delta time

var _label: Label = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 4, radius * 2 + 4)

	if show_label:
		_create_label()

func _process(delta: float) -> void:
	if not is_running:
		return

	if auto_advance:
		advance(delta)

func _draw() -> void:
	var center = size / 2
	var draw_radius = min(size.x, size.y) / 2 - line_width

	# Background circle (full ring)
	draw_arc(center, draw_radius, 0, TAU, 32, bg_color, line_width, true)

	# Progress arc (starts at top, goes clockwise)
	var progress = get_progress()
	if progress > 0.001:
		var current_color = _get_current_color()
		var end_angle = -PI / 2 + TAU * progress
		draw_arc(center, draw_radius, -PI / 2, end_angle, 32, current_color, line_width, true)

	# Update label
	if _label and show_label:
		_update_label()

# ============================================================================
# PUBLIC API
# ============================================================================

func start(total: float, auto: bool = false) -> void:
	## Start the spinner with total time
	total_time = max(0.001, total)
	elapsed_time = 0.0
	is_running = true
	auto_advance = auto
	queue_redraw()

func stop() -> void:
	## Stop the spinner
	is_running = false
	queue_redraw()

func reset() -> void:
	## Reset to beginning
	elapsed_time = 0.0
	is_running = false
	queue_redraw()

func advance(delta_time: float) -> void:
	## Advance the spinner by delta_time
	if not is_running:
		return

	elapsed_time = min(elapsed_time + delta_time, total_time)
	progress_updated.emit(get_progress())
	queue_redraw()

	if elapsed_time >= total_time:
		is_running = false
		completed.emit()

func set_progress(progress: float) -> void:
	## Set progress directly (0.0 to 1.0)
	elapsed_time = clamp(progress, 0.0, 1.0) * total_time
	queue_redraw()

func get_progress() -> float:
	## Get current progress (0.0 to 1.0)
	if total_time <= 0:
		return 0.0
	return clamp(elapsed_time / total_time, 0.0, 1.0)

func get_remaining() -> float:
	## Get remaining time
	return max(0.0, total_time - elapsed_time)

func is_complete() -> bool:
	return elapsed_time >= total_time

# ============================================================================
# INTERNAL
# ============================================================================

func _create_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", int(radius * 0.8))
	add_child(_label)

func _update_label() -> void:
	if not _label:
		return

	_label.size = size
	_label.position = Vector2.ZERO

	var remaining = get_remaining()
	if remaining >= 1.0:
		_label.text = "%d%s" % [int(ceil(remaining)), label_suffix]
	elif remaining > 0:
		# Show decimal for < 1 hour
		_label.text = "%.1f%s" % [remaining, label_suffix]
	else:
		_label.text = "0%s" % label_suffix

	# Color the label based on progress
	_label.add_theme_color_override("font_color", _get_current_color())

func _get_current_color() -> Color:
	## Get color based on remaining time
	var remaining_ratio = 1.0 - get_progress()
	if remaining_ratio < CRITICAL_THRESHOLD:
		return critical_color
	return progress_color

# ============================================================================
# FACTORY
# ============================================================================

static func create_for_task(parent: Node, pos: Vector2, hours: float, suffix: String = "h") -> CircleSpinner:
	## Factory method to create and position a spinner
	var spinner = CircleSpinner.new()
	spinner.position = pos
	spinner.label_suffix = suffix
	parent.add_child(spinner)
	spinner.start(hours, false)
	return spinner

static func create_attached(target: Node2D, offset: Vector2, hours: float) -> CircleSpinner:
	## Create spinner attached above a target node
	var spinner = CircleSpinner.new()
	spinner.position = offset
	spinner.radius = 12.0  # Smaller for attached spinners
	target.add_child(spinner)
	spinner.start(hours, false)
	return spinner
