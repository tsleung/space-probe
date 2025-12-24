extends Node2D
class_name ControlSurfaceVisual

## Visual representation of a single control surface
## Handles drawing, animations, and particle effects for broken state

const ControlSurface = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal clicked(surface_id: int)
signal hover_started(surface_id: int)
signal hover_ended(surface_id: int)

# ============================================================================
# CONFIGURATION
# ============================================================================

var surface_id: int = -1
var surface_def: Dictionary = {}

# Visual state
var current_state: int = ControlSurface.SurfaceState.WORKING
var level: int = 0
var use_progress: float = 0.0
var is_hovered: bool = false

# Animation
var animation_timer: float = 0.0
var spark_timer: float = 0.0
var glow_pulse: float = 0.0

# Nodes
var base_sprite: Sprite2D
var lever_sprite: Sprite2D
var glow_indicator: Node2D
var status_label: Label
var spark_particles: GPUParticles2D
var smoke_particles: GPUParticles2D

# ============================================================================
# VISUAL CONSTANTS
# ============================================================================

const SURFACE_SIZE = Vector2(24, 24)
const LEVER_SIZE = Vector2(8, 20)
const BUTTON_SIZE = Vector2(16, 16)

const GLOW_COLORS = {
	ControlSurface.SurfaceState.WORKING: Color(0.2, 0.8, 0.2, 0.6),
	ControlSurface.SurfaceState.USING: Color(1.0, 0.9, 0.3, 0.8),
	ControlSurface.SurfaceState.BROKEN: Color(0.9, 0.2, 0.2, 0.8)
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	z_index = 5

func setup(id: int) -> void:
	surface_id = id
	surface_def = ControlSurface.get_definition(id)

	_create_visuals()
	_update_visuals()

func _create_visuals() -> void:
	var surface_type = surface_def.get("type", ControlSurface.SurfaceType.LEVER)

	# Base/background
	base_sprite = Sprite2D.new()
	base_sprite.name = "Base"
	add_child(base_sprite)

	# Create appropriate visual based on type
	match surface_type:
		ControlSurface.SurfaceType.LEVER:
			_create_lever_visual()
		ControlSurface.SurfaceType.BUTTON:
			_create_button_visual()

	# Glow indicator (drawn behind)
	_create_glow_indicator()

	# Status label
	_create_status_label()

	# Particle systems for broken state
	_create_spark_particles()
	_create_smoke_particles()

func _create_lever_visual() -> void:
	# Draw a simple lever with base plate

	# Base plate (rectangle)
	var base_img = Image.create(int(SURFACE_SIZE.x), int(SURFACE_SIZE.y), false, Image.FORMAT_RGBA8)
	base_img.fill(Color(0.25, 0.25, 0.3))
	# Add border
	for x in range(int(SURFACE_SIZE.x)):
		base_img.set_pixel(x, 0, Color(0.4, 0.4, 0.45))
		base_img.set_pixel(x, int(SURFACE_SIZE.y) - 1, Color(0.15, 0.15, 0.2))
	for y in range(int(SURFACE_SIZE.y)):
		base_img.set_pixel(0, y, Color(0.4, 0.4, 0.45))
		base_img.set_pixel(int(SURFACE_SIZE.x) - 1, y, Color(0.15, 0.15, 0.2))

	var base_tex = ImageTexture.create_from_image(base_img)
	base_sprite.texture = base_tex

	# Lever handle
	lever_sprite = Sprite2D.new()
	lever_sprite.name = "Lever"

	var lever_img = Image.create(int(LEVER_SIZE.x), int(LEVER_SIZE.y), false, Image.FORMAT_RGBA8)
	lever_img.fill(Color(0.6, 0.6, 0.65))
	# Handle grip at top
	for x in range(int(LEVER_SIZE.x)):
		for y in range(4):
			lever_img.set_pixel(x, y, Color(0.8, 0.3, 0.3))  # Red grip

	var lever_tex = ImageTexture.create_from_image(lever_img)
	lever_sprite.texture = lever_tex
	lever_sprite.position = Vector2(0, -4)  # Above center
	add_child(lever_sprite)

func _create_button_visual() -> void:
	# Draw a round button

	var btn_img = Image.create(int(BUTTON_SIZE.x), int(BUTTON_SIZE.y), false, Image.FORMAT_RGBA8)
	btn_img.fill(Color(0.0, 0.0, 0.0, 0.0))

	# Draw circular button
	var center = BUTTON_SIZE / 2
	var radius = min(BUTTON_SIZE.x, BUTTON_SIZE.y) / 2 - 1

	for x in range(int(BUTTON_SIZE.x)):
		for y in range(int(BUTTON_SIZE.y)):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var shade = 1.0 - (dist / radius) * 0.3
				btn_img.set_pixel(x, y, Color(0.7 * shade, 0.2 * shade, 0.2 * shade))
			elif dist < radius + 1:
				btn_img.set_pixel(x, y, Color(0.3, 0.3, 0.3))  # Border

	var btn_tex = ImageTexture.create_from_image(btn_img)
	base_sprite.texture = btn_tex

func _create_glow_indicator() -> void:
	glow_indicator = Node2D.new()
	glow_indicator.name = "Glow"
	glow_indicator.z_index = -1  # Behind base
	add_child(glow_indicator)
	move_child(glow_indicator, 0)  # Move to back

func _create_status_label() -> void:
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Use small font
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 1)

	status_label.position = Vector2(-16, 14)
	status_label.size = Vector2(32, 12)
	add_child(status_label)

func _create_spark_particles() -> void:
	spark_particles = GPUParticles2D.new()
	spark_particles.name = "Sparks"
	spark_particles.emitting = false
	spark_particles.amount = 8
	spark_particles.lifetime = 0.4
	spark_particles.explosiveness = 0.8
	spark_particles.randomness = 0.5

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 60.0
	material.gravity = Vector3(0, 100, 0)
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 80.0
	material.scale_min = 1.0
	material.scale_max = 3.0
	material.color = Color(1.0, 0.7, 0.2)

	spark_particles.process_material = material
	add_child(spark_particles)

func _create_smoke_particles() -> void:
	smoke_particles = GPUParticles2D.new()
	smoke_particles.name = "Smoke"
	smoke_particles.emitting = false
	smoke_particles.amount = 5
	smoke_particles.lifetime = 1.5
	smoke_particles.randomness = 0.3

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 20.0
	material.gravity = Vector3(0, -20, 0)  # Rises
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 25.0
	material.scale_min = 2.0
	material.scale_max = 5.0
	material.color = Color(0.4, 0.4, 0.4, 0.6)

	smoke_particles.process_material = material
	add_child(smoke_particles)

# ============================================================================
# UPDATE
# ============================================================================

func _process(delta: float) -> void:
	animation_timer += delta
	glow_pulse = (sin(animation_timer * 3.0) + 1.0) / 2.0

	if current_state == ControlSurface.SurfaceState.BROKEN:
		_process_broken_effects(delta)

	if current_state == ControlSurface.SurfaceState.USING:
		_process_using_animation(delta)

	queue_redraw()

func _process_broken_effects(delta: float) -> void:
	spark_timer += delta

	# Random sparks
	if spark_timer >= randf_range(0.5, 2.0):
		spark_timer = 0.0
		spark_particles.emitting = true

	# Continuous smoke
	if not smoke_particles.emitting:
		smoke_particles.emitting = true

func _process_using_animation(delta: float) -> void:
	# Animate lever/button while being used
	if lever_sprite:
		var wobble = sin(animation_timer * 10.0) * 3.0
		lever_sprite.rotation_degrees = wobble

# ============================================================================
# STATE UPDATES
# ============================================================================

func set_state(new_state: int) -> void:
	var old_state = current_state
	current_state = new_state
	_update_visuals()

	# Stop effects when fixed
	if old_state == ControlSurface.SurfaceState.BROKEN and new_state != ControlSurface.SurfaceState.BROKEN:
		spark_particles.emitting = false
		smoke_particles.emitting = false

func set_level(new_level: int) -> void:
	level = new_level
	_update_lever_position()
	_update_status_label()

func set_use_progress(progress: float) -> void:
	use_progress = progress

func _update_visuals() -> void:
	_update_lever_position()
	_update_status_label()
	_update_base_color()

func _update_lever_position() -> void:
	if not lever_sprite:
		return

	# Position lever based on level
	var levels = surface_def.get("levels", [])
	if levels.is_empty():
		return

	var level_count = levels.size()
	var angle_range = 60.0  # Total degrees of rotation

	# Map level to angle
	var normalized = float(level) / max(1, level_count - 1)
	var target_angle = -angle_range / 2 + normalized * angle_range

	# Smooth transition
	lever_sprite.rotation_degrees = lerp(lever_sprite.rotation_degrees, target_angle, 0.2)

func _update_status_label() -> void:
	if not status_label:
		return

	var levels = surface_def.get("levels", [])
	if level >= 0 and level < levels.size():
		status_label.text = levels[level]
	else:
		status_label.text = ControlSurface.get_short_name(surface_id)

	# Color based on state
	match current_state:
		ControlSurface.SurfaceState.WORKING:
			status_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		ControlSurface.SurfaceState.USING:
			status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
		ControlSurface.SurfaceState.BROKEN:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _update_base_color() -> void:
	if not base_sprite:
		return

	match current_state:
		ControlSurface.SurfaceState.BROKEN:
			base_sprite.modulate = Color(0.6, 0.4, 0.4)
		_:
			base_sprite.modulate = Color.WHITE

# ============================================================================
# DRAWING
# ============================================================================

func _draw() -> void:
	_draw_glow()

	if is_hovered:
		_draw_highlight()

func _draw_glow() -> void:
	var glow_color = GLOW_COLORS.get(current_state, Color(0.5, 0.5, 0.5, 0.3))

	# Pulse effect for active states
	if current_state == ControlSurface.SurfaceState.WORKING:
		glow_color.a = 0.3 + glow_pulse * 0.2
	elif current_state == ControlSurface.SurfaceState.BROKEN:
		# Flicker effect
		glow_color.a = 0.4 + randf() * 0.4
	elif current_state == ControlSurface.SurfaceState.USING:
		glow_color.a = 0.6 + glow_pulse * 0.3

	# Draw glow circle
	draw_circle(Vector2.ZERO, 18, glow_color)

func _draw_highlight() -> void:
	# Draw hover highlight
	draw_arc(Vector2.ZERO, 16, 0, TAU, 16, Color(1.0, 1.0, 1.0, 0.5), 2.0)

# ============================================================================
# INTERACTION
# ============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_mouse_over():
				clicked.emit(surface_id)

	if event is InputEventMouseMotion:
		var was_hovered = is_hovered
		is_hovered = _is_mouse_over()

		if is_hovered and not was_hovered:
			hover_started.emit(surface_id)
		elif not is_hovered and was_hovered:
			hover_ended.emit(surface_id)

func _is_mouse_over() -> bool:
	var mouse_pos = get_local_mouse_position()
	return mouse_pos.length() < 16

# ============================================================================
# EFFECTS
# ============================================================================

func trigger_interaction_flash() -> void:
	## Flash when crew starts interaction
	var tween = create_tween()
	tween.tween_property(base_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(base_sprite, "modulate", Color.WHITE, 0.3)

func trigger_break_effect() -> void:
	## Visual effect when surface breaks
	spark_particles.emitting = true

	# Screen shake (small)
	var original_pos = position
	var tween = create_tween()
	for i in range(5):
		var offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		tween.tween_property(self, "position", original_pos + offset, 0.03)
	tween.tween_property(self, "position", original_pos, 0.05)

func trigger_repair_effect() -> void:
	## Visual effect when surface is repaired
	spark_particles.emitting = false
	smoke_particles.emitting = false

	# Flash green
	var tween = create_tween()
	tween.tween_property(base_sprite, "modulate", Color(0.5, 2.0, 0.5), 0.2)
	tween.tween_property(base_sprite, "modulate", Color.WHITE, 0.5)
