extends Control
class_name OrbitalSelector

## Orbital Selector - Launch Window Picker for MOT Phase 1
## Shows Earth and Mars positions, calculates transfer windows,
## and lets the player choose when to launch

signal window_selected(window: RefCounted)
signal launch_now_pressed(window: RefCounted)

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var start_year: int = 2040
@export var current_day: int = 0
@export var search_days: int = 200  # How far ahead to show windows

# Visual settings
@export var orbit_scale: float = 100.0  # Pixels per AU
@export var sun_radius: float = 15.0
@export var planet_radius: float = 8.0
@export var orbit_line_width: float = 1.0
@export var animation_speed: float = 30.0  # Days per second when animating (faster to see movement)

# Colors
@export var sun_color: Color = Color(1.0, 0.9, 0.3)
@export var earth_color: Color = Color(0.2, 0.5, 1.0)
@export var mars_color: Color = Color(0.9, 0.3, 0.2)
@export var earth_orbit_color: Color = Color(0.3, 0.4, 0.6, 0.5)
@export var mars_orbit_color: Color = Color(0.6, 0.3, 0.3, 0.5)
@export var transfer_arc_color: Color = Color(0.8, 0.8, 0.2, 0.7)

# ============================================================================
# STATE
# ============================================================================

var selected_window: RefCounted = null
var windows_timeline: Array = []
var hover_day: int = -1
var is_animating: bool = false
var animation_day: float = 0.0

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var solar_view: Control = %SolarView
@onready var timeline_container: Control = %TimelineContainer
@onready var info_panel: Control = %InfoPanel
@onready var launch_now_button: Button = %LaunchNowButton
@onready var animate_button: Button = %AnimateButton
@onready var confirm_button: Button = %ConfirmButton

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_ui()
	_calculate_windows()
	_update_display()

func _process(delta: float) -> void:
	if is_animating:
		animation_day += animation_speed * delta
		solar_view.queue_redraw()

func _setup_ui() -> void:
	# Connect launch now button
	if launch_now_button:
		launch_now_button.pressed.connect(_on_launch_now_pressed)

	# Connect animate button
	if animate_button:
		animate_button.pressed.connect(_on_animate_pressed)

	# Connect confirm button
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

	# Setup solar view drawing
	if solar_view:
		solar_view.draw.connect(_draw_solar_system)

func _calculate_windows() -> void:
	windows_timeline = MOTOrbital.get_window_timeline(current_day, current_day + search_days, start_year)

	# Find and select the best window by default
	for window_data in windows_timeline:
		if window_data.quality == "optimal" or window_data.quality == "good":
			select_day(window_data.day)
			break

func _update_display() -> void:
	_update_info_panel()
	_update_timeline()
	if solar_view:
		solar_view.queue_redraw()

# ============================================================================
# SOLAR SYSTEM DRAWING
# ============================================================================

func _draw_solar_system() -> void:
	if not solar_view:
		return

	var center = solar_view.size / 2

	# Draw orbits
	_draw_orbit(center, EARTH_SEMI_MAJOR * orbit_scale, earth_orbit_color)
	_draw_orbit(center, MARS_SEMI_MAJOR * orbit_scale, mars_orbit_color)

	# Draw Sun
	solar_view.draw_circle(center, sun_radius, sun_color)

	# Get current positions
	var display_day = int(animation_day) if is_animating else current_day
	var earth_pos = MOTOrbital.get_earth_position(display_day, start_year)
	var mars_pos = MOTOrbital.get_mars_position(display_day, start_year)

	# Convert to screen coordinates
	var earth_screen = center + Vector2(earth_pos.x, -earth_pos.y) * orbit_scale
	var mars_screen = center + Vector2(mars_pos.x, -mars_pos.y) * orbit_scale

	# Draw transfer arc if window selected
	if selected_window:
		_draw_transfer_arc(center, display_day)

	# Draw planets
	solar_view.draw_circle(earth_screen, planet_radius, earth_color)
	solar_view.draw_circle(mars_screen, planet_radius, mars_color)

	# Draw labels
	_draw_planet_label(earth_screen, "Earth", earth_color)
	_draw_planet_label(mars_screen, "Mars", mars_color)

	# Draw phase angle indicator
	_draw_phase_indicator(center, earth_pos, mars_pos)

func _draw_orbit(center: Vector2, radius: float, color: Color) -> void:
	var points = 64
	var prev_point = center + Vector2(radius, 0)

	for i in range(1, points + 1):
		var angle = (float(i) / points) * TAU
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		solar_view.draw_line(prev_point, point, color, orbit_line_width)
		prev_point = point

func _draw_transfer_arc(center: Vector2, from_day: int) -> void:
	if not selected_window:
		return

	# Draw a simplified transfer ellipse
	var earth_pos_launch = MOTOrbital.get_earth_position(selected_window.launch_day, start_year)
	var mars_pos_arrival = MOTOrbital.get_mars_position(
		selected_window.launch_day + selected_window.travel_days, start_year
	)

	var start_screen = center + Vector2(earth_pos_launch.x, -earth_pos_launch.y) * orbit_scale
	var end_screen = center + Vector2(mars_pos_arrival.x, -mars_pos_arrival.y) * orbit_scale

	# Draw arc (simplified as bezier curve)
	var control_point = center + (start_screen - center).rotated(PI * 0.3) * 0.8

	# Draw dashed line representing transfer
	var steps = 20
	var prev_pos = start_screen
	for i in range(1, steps + 1):
		var t = float(i) / steps
		# Quadratic bezier approximation
		var pos = start_screen.lerp(control_point, t).lerp(control_point.lerp(end_screen, t), t)
		if i % 2 == 0:  # Dashed
			solar_view.draw_line(prev_pos, pos, transfer_arc_color, 2.0)
		prev_pos = pos

func _draw_planet_label(pos: Vector2, text: String, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 12
	var offset = Vector2(planet_radius + 5, -5)
	solar_view.draw_string(font, pos + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_phase_indicator(center: Vector2, earth_pos: Vector2, mars_pos: Vector2) -> void:
	# Draw a small arc showing the phase angle
	var earth_angle = atan2(-earth_pos.y, earth_pos.x)
	var mars_angle = atan2(-mars_pos.y, mars_pos.x)

	var arc_radius = 30.0
	var arc_color = Color(0.8, 0.8, 0.8, 0.5)

	# Draw arc from Earth angle to Mars angle
	var points = 16
	var angle_diff = mars_angle - earth_angle
	if angle_diff < 0:
		angle_diff += TAU

	var prev_point = center + Vector2(cos(earth_angle), sin(earth_angle)) * arc_radius
	for i in range(1, points + 1):
		var t = float(i) / points
		var angle = earth_angle + angle_diff * t
		var point = center + Vector2(cos(angle), sin(angle)) * arc_radius
		solar_view.draw_line(prev_point, point, arc_color, 1.0)
		prev_point = point

# ============================================================================
# CONSTANTS (duplicated for drawing access)
# ============================================================================

const EARTH_SEMI_MAJOR := 1.0
const MARS_SEMI_MAJOR := 1.52

# ============================================================================
# INFO PANEL
# ============================================================================

func _update_info_panel() -> void:
	if not info_panel:
		return

	# Find or create labels (nested in InfoContent)
	var title_label = info_panel.get_node_or_null("InfoContent/TitleLabel")
	var details_label = info_panel.get_node_or_null("InfoContent/DetailsLabel")
	var edu_label = info_panel.get_node_or_null("InfoContent/EducationalLabel")

	if selected_window:
		if title_label:
			var quality_text = selected_window.quality.capitalize()
			title_label.text = "%s Launch Window" % quality_text

		if details_label:
			var text = ""
			text += "Launch: Day %d\n" % selected_window.launch_day
			text += "Travel Time: %s\n" % MOTOrbital.format_travel_time(selected_window.travel_days)
			text += "Fuel Cost: %s\n" % MOTOrbital.format_fuel_cost(selected_window.fuel_multiplier)
			text += "Efficiency: %.0f%%\n" % (100.0 / selected_window.fuel_multiplier)
			details_label.text = text

		if edu_label:
			edu_label.text = MOTOrbital.get_educational_text(selected_window)
	else:
		if title_label:
			title_label.text = "Select a Launch Window"
		if details_label:
			details_label.text = "Click on the timeline or use LAUNCH NOW"
		if edu_label:
			edu_label.text = ""

# ============================================================================
# TIMELINE
# ============================================================================

func _update_timeline() -> void:
	if not timeline_container:
		return

	# Clear existing timeline items
	for child in timeline_container.get_children():
		child.queue_free()

	# Create timeline items
	for window_data in windows_timeline:
		var item = _create_timeline_item(window_data)
		timeline_container.add_child(item)

func _create_timeline_item(window_data: Dictionary) -> Control:
	var item = Button.new()
	item.text = window_data.label
	item.custom_minimum_size = Vector2(100, 40)

	# Color based on quality
	var quality_color = MOTOrbital.get_quality_color(window_data.quality)
	var style = StyleBoxFlat.new()
	style.bg_color = quality_color.darkened(0.5)
	style.border_color = quality_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	item.add_theme_stylebox_override("normal", style)

	# Highlight if selected
	if selected_window and window_data.day == selected_window.launch_day:
		style.bg_color = quality_color.darkened(0.2)

	# Tooltip with details
	item.tooltip_text = "%s\nTravel: %d days\nFuel: %.1fx" % [
		window_data.quality.capitalize(),
		window_data.travel_days,
		window_data.fuel_multiplier
	]

	# Connect click
	var day = window_data.day
	item.pressed.connect(func(): select_day(day))

	return item

# ============================================================================
# SELECTION
# ============================================================================

func select_day(day: int) -> void:
	selected_window = MOTOrbital.calculate_launch_window(day, start_year)
	_update_display()
	window_selected.emit(selected_window)

func get_selected_window() -> RefCounted:
	return selected_window

# ============================================================================
# ACTIONS
# ============================================================================

func _on_launch_now_pressed() -> void:
	var rush_window = MOTOrbital.calculate_rush_launch(current_day, 10, start_year)
	selected_window = rush_window
	_update_display()
	launch_now_pressed.emit(rush_window)

func set_current_day(day: int) -> void:
	current_day = day
	_calculate_windows()
	_update_display()

func start_animation() -> void:
	is_animating = true
	animation_day = float(current_day)

func stop_animation() -> void:
	is_animating = false

func toggle_animation() -> void:
	if is_animating:
		stop_animation()
	else:
		start_animation()

func _on_animate_pressed() -> void:
	toggle_animation()
	# Update button text
	if animate_button:
		if is_animating:
			animate_button.text = "Stop Animation"
		else:
			animate_button.text = "Animate Orbits"

func _on_confirm_pressed() -> void:
	if selected_window:
		window_selected.emit(selected_window)
