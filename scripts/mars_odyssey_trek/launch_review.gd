extends Control
class_name LaunchReview

## Launch Review for MOT Phase 1
## Summary of all choices and final launch confirmation

signal launch_pressed()

# ============================================================================
# STATE
# ============================================================================

var store: MOTStore = null
var is_ready: bool = false
var issues: Array = []

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var summary_container: VBoxContainer = %SummaryContainer
@onready var launch_button: Button = %LaunchButton
@onready var issues_label: Label = %IssuesLabel
@onready var reliability_label: Label = %ReliabilityLabel
@onready var budget_label: Label = %BudgetLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	if launch_button:
		launch_button.pressed.connect(_on_launch_pressed)

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	_update_summary(state)
	_update_readiness(state)

func set_readiness(ready: bool, issue_list: Array) -> void:
	is_ready = ready
	issues = issue_list
	_update_launch_button()
	_update_issues_display()

# ============================================================================
# SUMMARY DISPLAY
# ============================================================================

func _update_summary(state: Dictionary) -> void:
	if not summary_container:
		return

	for child in summary_container.get_children():
		child.queue_free()

	# Launch Window
	_add_summary_section("Launch Window", _get_window_summary(state))

	# Construction Approach
	_add_summary_section("Construction", _get_construction_summary(state))

	# Engine
	_add_summary_section("Engine", _get_engine_summary(state))

	# Ship Class
	_add_summary_section("Ship", _get_ship_summary(state))

	# Life Support
	_add_summary_section("Life Support", _get_life_support_summary(state))

	# Crew
	_add_summary_section("Crew", _get_crew_summary(state))

	# Cargo
	_add_summary_section("Cargo", _get_cargo_summary(state))

	# Update other displays
	_update_reliability(state)
	_update_budget(state)

func _add_summary_section(title: String, content: String) -> void:
	var section = HBoxContainer.new()
	section.add_theme_constant_override("separation", 15)

	var title_label = Label.new()
	title_label.text = title + ":"
	title_label.custom_minimum_size = Vector2(120, 0)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	section.add_child(title_label)

	var content_label = Label.new()
	content_label.text = content
	content_label.add_theme_font_size_override("font_size", 14)
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(content_label)

	summary_container.add_child(section)

func _get_window_summary(state: Dictionary) -> String:
	var window = state.get("launch_window")
	if window == null:
		return "Not selected"

	return "Day %d (%s) - %d day travel" % [
		window.get("launch_day", 0),
		window.get("quality", "unknown").capitalize(),
		window.get("travel_days", 180)
	]

func _get_construction_summary(state: Dictionary) -> String:
	var approach = state.get("construction_approach")
	if approach == null:
		return "Not selected"

	return MOTTypes.CONSTRUCTION_APPROACHES[approach].name

func _get_engine_summary(state: Dictionary) -> String:
	var engine = state.get("engine")
	if engine == null:
		return "Not selected"

	return MOTTypes.ENGINES[engine].name

func _get_ship_summary(state: Dictionary) -> String:
	var ship_class = state.get("ship_class")
	if ship_class == null:
		return "Not selected"

	var name = MOTTypes.SHIP_CLASSES[ship_class].name
	var upgrades = state.get("upgrades", [])

	if upgrades.size() > 0:
		return "%s + %d upgrade(s)" % [name, upgrades.size()]
	return name

func _get_life_support_summary(state: Dictionary) -> String:
	var tier = state.get("life_support")
	if tier == null:
		return "Not selected"

	return MOTTypes.LIFE_SUPPORT_TIERS[tier].name

func _get_crew_summary(state: Dictionary) -> String:
	var crew = state.get("crew", [])
	if crew.size() == 0:
		return "None selected"

	return "%d crew members" % crew.size()

func _get_cargo_summary(state: Dictionary) -> String:
	var used = state.get("cargo_used", 0)
	var capacity = state.get("cargo_capacity", 0)

	return "%d / %d kg" % [used, capacity]

# ============================================================================
# STATISTICS
# ============================================================================

func _update_reliability(state: Dictionary) -> void:
	if not reliability_label:
		return

	var reliability = state.get("reliability_estimate", 0.9)
	var pct = int(reliability * 100)

	reliability_label.text = "Mission Reliability: %d%%" % pct

	if reliability >= 0.8:
		reliability_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	elif reliability >= 0.6:
		reliability_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	else:
		reliability_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

func _update_budget(state: Dictionary) -> void:
	if not budget_label:
		return

	var remaining = state.get("budget_remaining", 0)
	var total = state.get("budget_total", 0)

	budget_label.text = "Budget: $%dM / $%dM" % [remaining / 1000000, total / 1000000]

	if remaining < 0:
		budget_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	elif remaining < total * 0.1:
		budget_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	else:
		budget_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

# ============================================================================
# READINESS
# ============================================================================

func _update_readiness(state: Dictionary) -> void:
	var readiness = MOTTypes.check_launch_readiness(state)
	is_ready = readiness.is_ready
	issues = readiness.issues
	_update_launch_button()
	_update_issues_display()

func _update_launch_button() -> void:
	if not launch_button:
		return

	if is_ready:
		launch_button.text = "LAUNCH MISSION"
		launch_button.disabled = false

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.5, 0.3)
		style.set_corner_radius_all(8)
		launch_button.add_theme_stylebox_override("normal", style)

		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.25, 0.6, 0.35)
		hover_style.set_corner_radius_all(8)
		launch_button.add_theme_stylebox_override("hover", hover_style)
	else:
		launch_button.text = "NOT READY"
		launch_button.disabled = true

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3)
		style.set_corner_radius_all(8)
		launch_button.add_theme_stylebox_override("normal", style)

func _update_issues_display() -> void:
	if not issues_label:
		return

	if issues.size() > 0:
		issues_label.text = "Issues:\n- " + "\n- ".join(issues)
		issues_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		issues_label.visible = true
	else:
		issues_label.text = "All systems ready for launch!"
		issues_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		issues_label.visible = true

# ============================================================================
# ACTIONS
# ============================================================================

func _on_launch_pressed() -> void:
	if is_ready:
		launch_pressed.emit()
