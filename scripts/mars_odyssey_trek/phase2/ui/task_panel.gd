extends Control
class_name TaskPanel

## Task Panel UI - Shows all active tasks with progress and penalties
## Displays at the side of the screen with expandable task list

const TaskManager = preload("res://scripts/mars_odyssey_trek/phase2/tasks/task_manager.gd")
const CircleSpinner = preload("res://scripts/mars_odyssey_trek/phase2/ui/circle_spinner.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal task_selected(task_id: String)
signal task_cancelled(task_id: String)

# ============================================================================
# CONSTANTS
# ============================================================================

const PANEL_WIDTH = 220
const TASK_ROW_HEIGHT = 50
const HEADER_HEIGHT = 30
const PADDING = 8

const BG_COLOR = Color(0.1, 0.12, 0.15, 0.9)
const HEADER_COLOR = Color(0.15, 0.18, 0.22)
const TASK_BG_COLOR = Color(0.12, 0.14, 0.18, 0.8)
const TASK_HOVER_COLOR = Color(0.18, 0.22, 0.28, 0.9)
const BORDER_COLOR = Color(0.3, 0.35, 0.4)
const TEXT_COLOR = Color(0.85, 0.85, 0.85)
const SUBTEXT_COLOR = Color(0.6, 0.65, 0.7)
const PENALTY_COLOR = Color(0.9, 0.4, 0.3)

# ============================================================================
# STATE
# ============================================================================

var task_manager: TaskManager = null
var task_rows: Dictionary = {}  # task_id -> task row node
var expanded: bool = true
var minimized_width: float = 40

# ============================================================================
# NODES
# ============================================================================

var background: ColorRect
var header: Control
var header_label: Label
var expand_button: Button
var task_container: VBoxContainer
var scroll_container: ScrollContainer
var no_tasks_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_ui()
	_update_layout()

func setup(manager: TaskManager) -> void:
	task_manager = manager

	# Connect signals
	task_manager.task_started.connect(_on_task_started)
	task_manager.task_progress.connect(_on_task_progress)
	task_manager.task_completed.connect(_on_task_completed)
	task_manager.task_failed.connect(_on_task_failed)

	# Initial update
	_refresh_task_list()

func _create_ui() -> void:
	# Main background
	background = ColorRect.new()
	background.color = BG_COLOR
	add_child(background)

	# Header
	header = Control.new()
	header.custom_minimum_size.y = HEADER_HEIGHT
	add_child(header)

	var header_bg = ColorRect.new()
	header_bg.color = HEADER_COLOR
	header_bg.size = Vector2(PANEL_WIDTH, HEADER_HEIGHT)
	header.add_child(header_bg)

	header_label = Label.new()
	header_label.text = "ACTIVE TASKS"
	header_label.position = Vector2(PADDING, 6)
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_child(header_label)

	# Task count badge
	var count_badge = Label.new()
	count_badge.name = "CountBadge"
	count_badge.text = "0"
	count_badge.position = Vector2(PANEL_WIDTH - 35, 6)
	count_badge.add_theme_font_size_override("font_size", 10)
	count_badge.add_theme_color_override("font_color", SUBTEXT_COLOR)
	header.add_child(count_badge)

	# Expand/minimize button
	expand_button = Button.new()
	expand_button.text = "−"
	expand_button.size = Vector2(20, 20)
	expand_button.position = Vector2(PANEL_WIDTH - 25, 5)
	expand_button.pressed.connect(_toggle_expanded)
	header.add_child(expand_button)

	# Scroll container for tasks
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(0, HEADER_HEIGHT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	# Task container
	task_container = VBoxContainer.new()
	task_container.add_theme_constant_override("separation", 4)
	scroll_container.add_child(task_container)

	# No tasks label
	no_tasks_label = Label.new()
	no_tasks_label.text = "No active tasks"
	no_tasks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_tasks_label.add_theme_font_size_override("font_size", 10)
	no_tasks_label.add_theme_color_override("font_color", SUBTEXT_COLOR)
	task_container.add_child(no_tasks_label)

func _update_layout() -> void:
	var width = PANEL_WIDTH if expanded else minimized_width
	var height = HEADER_HEIGHT + (task_rows.size() * (TASK_ROW_HEIGHT + 4)) + PADDING * 2

	if not expanded:
		height = HEADER_HEIGHT

	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size

	background.size = size
	scroll_container.size = Vector2(width, height - HEADER_HEIGHT)
	task_container.custom_minimum_size.x = width - PADDING * 2

	# Update visibility
	scroll_container.visible = expanded
	header_label.visible = expanded
	no_tasks_label.visible = expanded and task_rows.is_empty()

	# Update header elements
	var header_bg = header.get_child(0)
	if header_bg:
		header_bg.size.x = width

	expand_button.position.x = width - 25
	expand_button.text = "−" if expanded else "+"

	var count_badge = header.get_node_or_null("CountBadge")
	if count_badge:
		count_badge.visible = expanded
		count_badge.text = str(task_rows.size())

func _toggle_expanded() -> void:
	expanded = not expanded
	_update_layout()

# ============================================================================
# TASK ROW CREATION
# ============================================================================

func _create_task_row(task: Dictionary) -> Control:
	var row = Control.new()
	row.custom_minimum_size = Vector2(PANEL_WIDTH - PADDING * 2, TASK_ROW_HEIGHT)
	row.name = "TaskRow_" + task.id

	# Background
	var bg = ColorRect.new()
	bg.color = TASK_BG_COLOR
	bg.size = row.custom_minimum_size
	bg.name = "Background"
	row.add_child(bg)

	# Left color indicator
	var indicator = ColorRect.new()
	indicator.color = task.get("color", Color.WHITE)
	indicator.size = Vector2(4, TASK_ROW_HEIGHT)
	indicator.name = "Indicator"
	row.add_child(indicator)

	# Task name
	var name_label = Label.new()
	name_label.text = task.get("name", "Task")
	name_label.position = Vector2(12, 4)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.name = "NameLabel"
	row.add_child(name_label)

	# Progress bar background
	var progress_bg = ColorRect.new()
	progress_bg.color = Color(0.2, 0.22, 0.25)
	progress_bg.position = Vector2(12, 22)
	progress_bg.size = Vector2(PANEL_WIDTH - PADDING * 2 - 60, 8)
	progress_bg.name = "ProgressBg"
	row.add_child(progress_bg)

	# Progress bar fill
	var progress_fill = ColorRect.new()
	progress_fill.color = task.get("color", Color(0.4, 0.7, 0.4))
	progress_fill.position = Vector2(12, 22)
	progress_fill.size = Vector2(0, 8)
	progress_fill.name = "ProgressFill"
	row.add_child(progress_fill)

	# Time remaining label
	var time_label = Label.new()
	var remaining = task.total_hours - task.elapsed_hours
	time_label.text = "%.1fh" % remaining
	time_label.position = Vector2(PANEL_WIDTH - PADDING * 2 - 45, 18)
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.add_theme_color_override("font_color", SUBTEXT_COLOR)
	time_label.name = "TimeLabel"
	row.add_child(time_label)

	# Penalty indicator (if task has penalty)
	var penalty = task.get("penalty", {})
	if penalty.get("type", "none") != "none":
		var penalty_label = Label.new()
		var penalty_type = penalty.get("type", "")
		var penalty_amount = penalty.get("amount", 0)
		penalty_label.text = "⚠ %s: -%.0f" % [_get_penalty_short_name(penalty_type), penalty_amount]
		penalty_label.position = Vector2(12, 34)
		penalty_label.add_theme_font_size_override("font_size", 9)
		penalty_label.add_theme_color_override("font_color", PENALTY_COLOR)
		penalty_label.name = "PenaltyLabel"
		row.add_child(penalty_label)

	# Crew assignment
	var crew = task.get("crew", [])
	if not crew.is_empty():
		var crew_label = Label.new()
		var crew_names = []
		for role in crew:
			crew_names.append(role.capitalize().substr(0, 3))
		crew_label.text = "[%s]" % ", ".join(crew_names)
		crew_label.position = Vector2(PANEL_WIDTH - PADDING * 2 - 45, 4)
		crew_label.add_theme_font_size_override("font_size", 8)
		crew_label.add_theme_color_override("font_color", SUBTEXT_COLOR)
		crew_label.name = "CrewLabel"
		row.add_child(crew_label)

	return row

func _get_penalty_short_name(penalty_type: String) -> String:
	match penalty_type:
		"system_damage": return "Sys"
		"health_damage": return "HP"
		"morale_damage": return "Morale"
		"resource_drain": return "Res"
		"efficiency_loss": return "Eff"
		_: return "Pen"

func _update_task_row(task_id: String, task: Dictionary) -> void:
	var row = task_rows.get(task_id)
	if not row:
		return

	var progress = task.elapsed_hours / task.total_hours
	var remaining = task.total_hours - task.elapsed_hours

	# Update progress bar
	var progress_bg = row.get_node_or_null("ProgressBg")
	var progress_fill = row.get_node_or_null("ProgressFill")
	if progress_bg and progress_fill:
		progress_fill.size.x = progress_bg.size.x * progress

	# Update time label
	var time_label = row.get_node_or_null("TimeLabel")
	if time_label:
		if remaining >= 1.0:
			time_label.text = "%.0fh" % remaining
		else:
			time_label.text = "%.1fh" % remaining

		# Color based on remaining time
		if remaining < 1.0:
			time_label.add_theme_color_override("font_color", PENALTY_COLOR)
		else:
			time_label.add_theme_color_override("font_color", SUBTEXT_COLOR)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_task_started(task: Dictionary) -> void:
	var row = _create_task_row(task)
	task_container.add_child(row)
	task_rows[task.id] = row
	no_tasks_label.visible = false
	_update_layout()

func _on_task_progress(task_id: String, progress: float) -> void:
	if task_manager:
		var task = task_manager.get_task(task_id)
		if not task.is_empty():
			_update_task_row(task_id, task)

func _on_task_completed(task_id: String, success: bool) -> void:
	var row = task_rows.get(task_id)
	if row:
		# Flash green for success, red for failure
		var color = Color(0.3, 0.8, 0.3, 0.5) if success else Color(0.8, 0.3, 0.3, 0.5)
		var bg = row.get_node_or_null("Background")
		if bg:
			var tween = create_tween()
			tween.tween_property(bg, "color", color, 0.2)
			tween.tween_property(bg, "color", Color(0, 0, 0, 0), 0.3)
			tween.tween_callback(row.queue_free)

		task_rows.erase(task_id)
		_update_layout()

	if task_rows.is_empty():
		no_tasks_label.visible = true

func _on_task_failed(task_id: String, penalty: Dictionary) -> void:
	# Show penalty notification
	_show_penalty_notification(penalty)

func _show_penalty_notification(penalty: Dictionary) -> void:
	## Show a floating penalty notification
	var penalty_type = penalty.get("type", "unknown")
	var amount = penalty.get("amount", 0)

	var notification = Label.new()
	notification.text = "PENALTY: %s -%.0f" % [penalty_type.replace("_", " ").capitalize(), amount]
	notification.add_theme_font_size_override("font_size", 12)
	notification.add_theme_color_override("font_color", PENALTY_COLOR)
	notification.position = Vector2(PADDING, -30)
	add_child(notification)

	# Animate and remove
	var tween = create_tween()
	tween.tween_property(notification, "position:y", -60, 1.0)
	tween.parallel().tween_property(notification, "modulate:a", 0.0, 1.0)
	tween.tween_callback(notification.queue_free)

# ============================================================================
# REFRESH
# ============================================================================

func _refresh_task_list() -> void:
	## Rebuild the task list from task manager
	if not task_manager:
		return

	# Clear existing rows
	for row in task_rows.values():
		row.queue_free()
	task_rows.clear()

	# Add current tasks
	for task in task_manager.get_active_tasks():
		var row = _create_task_row(task)
		task_container.add_child(row)
		task_rows[task.id] = row

	no_tasks_label.visible = task_rows.is_empty()
	_update_layout()
