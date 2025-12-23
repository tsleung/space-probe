extends Node2D
class_name Phase2Effects

## Visual effects manager for MOT Phase 2
## Handles screen shake, particles, arrival ceremony, and camera focus

# ============================================================================
# SIGNALS
# ============================================================================

signal arrival_complete()
signal camera_focus_changed(focus_type: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var camera_path: NodePath
@export var ship_view_path: NodePath
@export var ship_hull_path: NodePath

# Screen shake
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_position: Vector2 = Vector2.ZERO

# Camera focus
var focus_target: Node2D = null
var focus_zoom: float = 1.0
var base_zoom: Vector2 = Vector2(1, 1)
var camera: Camera2D = null
var ship_view: Node2D = null
var ship_hull: Node2D = null

# Arrival ceremony state
var arrival_active: bool = false
var arrival_phase: int = 0
var arrival_timer: float = 0.0

# Mars visual for arrival (separate large Mars)
var arrival_mars: Node2D = null
var arrival_overlay: CanvasLayer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	await get_tree().process_frame
	_connect_references()

func _connect_references() -> void:
	if camera_path:
		camera = get_node_or_null(camera_path)
	if ship_view_path:
		ship_view = get_node_or_null(ship_view_path)
	if ship_hull_path:
		ship_hull = get_node_or_null(ship_hull_path)

	if camera:
		original_position = camera.position
		base_zoom = camera.zoom

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	_process_screen_shake(delta)
	_process_camera_focus(delta)
	_process_arrival(delta)

# ============================================================================
# SCREEN SHAKE
# ============================================================================

func shake_screen(intensity: float, duration: float) -> void:
	## Trigger screen shake effect
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func _process_screen_shake(delta: float) -> void:
	if shake_timer <= 0:
		if camera and camera.position != original_position:
			camera.position = original_position
		return

	shake_timer -= delta
	var progress = shake_timer / shake_duration
	var current_intensity = shake_intensity * progress

	if camera:
		var offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		camera.position = original_position + offset

# ============================================================================
# CAMERA FOCUS
# ============================================================================

func focus_on_room(room_type: int) -> void:
	## Zoom camera to focus on a specific room
	if not ship_view:
		return

	var room = ship_view.get_room(room_type)
	if room:
		focus_target = room
		focus_zoom = 1.5
		camera_focus_changed.emit("room")

func focus_on_crew(role: String) -> void:
	## Zoom camera to follow a specific crew member
	if not ship_view:
		return

	var crew = ship_view.get_crew_member(role)
	if crew:
		focus_target = crew
		focus_zoom = 1.8
		camera_focus_changed.emit("crew")

func clear_focus() -> void:
	## Return camera to normal view
	focus_target = null
	focus_zoom = 1.0
	camera_focus_changed.emit("normal")

func _process_camera_focus(delta: float) -> void:
	if not camera:
		return

	# Smooth zoom transition
	var target_zoom = base_zoom * focus_zoom
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 3.0)

	# Follow target if set
	if focus_target and is_instance_valid(focus_target):
		var target_pos = focus_target.global_position
		camera.position = camera.position.lerp(target_pos, delta * 5.0)
	else:
		camera.position = camera.position.lerp(original_position, delta * 3.0)

# ============================================================================
# MARS ARRIVAL CEREMONY
# ============================================================================

func start_arrival_ceremony() -> void:
	## Begin the Mars arrival celebration sequence
	arrival_active = true
	arrival_phase = 0
	arrival_timer = 0.0

	# Create arrival overlay
	_create_arrival_overlay()

func _create_arrival_overlay() -> void:
	arrival_overlay = CanvasLayer.new()
	arrival_overlay.layer = 10
	add_child(arrival_overlay)

	# Background fade
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.name = "ArrivalBG"
	arrival_overlay.add_child(bg)

	# Mars visual (large, growing)
	var mars_container = Control.new()
	mars_container.set_anchors_preset(Control.PRESET_CENTER)
	mars_container.name = "MarsContainer"
	arrival_overlay.add_child(mars_container)

	# Title text
	var title = Label.new()
	title.text = "MARS ORBIT ACHIEVED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -200)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
	title.modulate.a = 0
	title.name = "ArrivalTitle"
	arrival_overlay.add_child(title)

	# Stats summary
	var stats = Label.new()
	stats.text = ""  # Will be populated during ceremony
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.set_anchors_preset(Control.PRESET_CENTER)
	stats.position = Vector2(-200, -100)
	stats.size = Vector2(400, 200)
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	stats.modulate.a = 0
	stats.name = "ArrivalStats"
	arrival_overlay.add_child(stats)

	# Continue button (hidden initially)
	var continue_btn = Button.new()
	continue_btn.text = "Continue to Mars Surface"
	continue_btn.set_anchors_preset(Control.PRESET_CENTER)
	continue_btn.position = Vector2(-100, 150)
	continue_btn.size = Vector2(200, 40)
	continue_btn.visible = false
	continue_btn.name = "ContinueBtn"
	continue_btn.pressed.connect(_on_continue_pressed)
	arrival_overlay.add_child(continue_btn)

func _process_arrival(delta: float) -> void:
	if not arrival_active:
		return

	arrival_timer += delta

	match arrival_phase:
		0:  # Fade background
			var bg = arrival_overlay.get_node_or_null("ArrivalBG")
			if bg:
				bg.color.a = min(bg.color.a + delta * 0.5, 0.8)
			if arrival_timer > 2.0:
				arrival_phase = 1
				arrival_timer = 0.0

		1:  # Fade in title
			var title = arrival_overlay.get_node_or_null("ArrivalTitle")
			if title:
				title.modulate.a = min(title.modulate.a + delta * 2.0, 1.0)
			if arrival_timer > 1.5:
				arrival_phase = 2
				arrival_timer = 0.0

		2:  # Show stats
			var stats = arrival_overlay.get_node_or_null("ArrivalStats")
			if stats:
				stats.modulate.a = min(stats.modulate.a + delta * 2.0, 1.0)
			if arrival_timer > 2.0:
				arrival_phase = 3
				arrival_timer = 0.0

		3:  # Show continue button
			var btn = arrival_overlay.get_node_or_null("ContinueBtn")
			if btn:
				btn.visible = true
			arrival_phase = 4  # Wait for button press

		4:  # Waiting for user
			pass

func set_arrival_stats(stats_text: String) -> void:
	## Set the stats text for the arrival ceremony
	if arrival_overlay:
		var stats = arrival_overlay.get_node_or_null("ArrivalStats")
		if stats:
			stats.text = stats_text

func _on_continue_pressed() -> void:
	arrival_active = false
	if arrival_overlay:
		arrival_overlay.queue_free()
		arrival_overlay = null
	arrival_complete.emit()

# ============================================================================
# PARTICLE EFFECTS
# ============================================================================

func spawn_sparks(pos: Vector2, count: int = 10) -> void:
	## Spawn spark particles at position
	for i in range(count):
		_spawn_particle(pos, Color(1.0, 0.8, 0.3), 0.5)

func spawn_debris(pos: Vector2, count: int = 5) -> void:
	## Spawn debris particles at position
	for i in range(count):
		_spawn_particle(pos, Color(0.5, 0.5, 0.5), 1.0, 3.0)

func spawn_steam(pos: Vector2, count: int = 8) -> void:
	## Spawn steam/gas particles at position
	for i in range(count):
		_spawn_particle(pos, Color(0.9, 0.9, 1.0, 0.5), 1.5, 2.0, true)

func _spawn_particle(pos: Vector2, color: Color, lifetime: float, size: float = 2.0, floats: bool = false) -> void:
	var particle = ColorRect.new()
	particle.color = color
	particle.size = Vector2(size, size)
	particle.position = pos
	add_child(particle)

	# Random velocity
	var velocity = Vector2(randf_range(-50, 50), randf_range(-80, -20) if floats else randf_range(-50, 50))
	var gravity = 0.0 if floats else 100.0

	# Animate and remove
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "position", pos + velocity * lifetime, lifetime)
	tween.tween_property(particle, "modulate:a", 0.0, lifetime)
	tween.chain().tween_callback(particle.queue_free)

# ============================================================================
# IMPACT EFFECTS
# ============================================================================

func trigger_impact(intensity: float = 1.0) -> void:
	## Full impact effect with shake, particles, and flash
	shake_screen(5.0 * intensity, 0.3)

	# Flash the screen red briefly
	var flash = ColorRect.new()
	flash.color = Color(1, 0.3, 0.2, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Need to add to a CanvasLayer for proper overlay
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	layer.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(layer.queue_free)

func trigger_solar_flare_effect() -> void:
	## Yellow flash for solar flare
	var flash = ColorRect.new()
	flash.color = Color(1, 0.9, 0.3, 0.4)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	layer.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)

# ============================================================================
# MARS VISUAL (Growing as approach)
# ============================================================================

var mars_node: Node2D = null

func setup_mars_visual(parent: Node) -> void:
	## Create a separate Mars visual that grows during approach
	mars_node = Node2D.new()
	mars_node.name = "VisualMars"
	mars_node.z_index = -5
	parent.add_child(mars_node)
	# Mars will be drawn in journey_indicator.gd

func update_mars_size(progress: float) -> void:
	## Update Mars visual size based on journey progress (0.0 to 1.0)
	if mars_node:
		var scale = lerp(0.2, 2.0, progress * progress)
		mars_node.scale = Vector2(scale, scale)
