extends Node2D
class_name HullEvents

## External hull event system for MOT Phase 2
## Handles asteroids, solar flares, micrometeorites, and space debris
## Creates visual spectacle for environmental hazards

const ControlSurface = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal asteroid_impact(room: int, damage: float)
signal solar_flare_hit(intensity: float)
signal micrometeorite_hit(damage: float)
signal debris_collision(damage: float)
signal event_started(event_type: String)
signal event_ended(event_type: String)

# ============================================================================
# REFERENCES
# ============================================================================

var effects: Node  # Phase2Effects reference
var surface_manager: Node  # ControlSurfaceManager reference
var ship_hull: Node2D  # ShipHull reference

# Ship bounds for positioning
var ship_center: Vector2 = Vector2(400, 270)
var ship_width: float = 500.0
var ship_height: float = 200.0

# ============================================================================
# CONFIGURATION
# ============================================================================

const ASTEROID_SIZES = {
	"small": {"radius": 8, "damage": 0.1, "speed": 150.0},
	"medium": {"radius": 16, "damage": 0.25, "speed": 100.0},
	"large": {"radius": 28, "damage": 0.5, "speed": 60.0}
}

const DEBRIS_TYPES = [
	{"name": "metal_chunk", "size": Vector2(12, 8), "color": Color(0.5, 0.5, 0.55)},
	{"name": "panel_fragment", "size": Vector2(20, 6), "color": Color(0.4, 0.45, 0.5)},
	{"name": "cable_bundle", "size": Vector2(4, 25), "color": Color(0.3, 0.3, 0.35)},
	{"name": "insulation", "size": Vector2(15, 15), "color": Color(0.8, 0.7, 0.3)}
]

# ============================================================================
# INITIALIZATION
# ============================================================================

func setup(fx: Node, manager: Node, hull: Node2D) -> void:
	effects = fx
	surface_manager = manager
	ship_hull = hull

	if ship_hull:
		ship_center = ship_hull.global_position
		# Estimate hull size from visual
		ship_width = 500.0
		ship_height = 200.0

# ============================================================================
# ASTEROID EVENTS
# ============================================================================

func trigger_asteroid_impact(size: String = "medium", target_room: int = -1) -> void:
	## Spawn an asteroid that impacts the ship
	event_started.emit("asteroid")

	var config = ASTEROID_SIZES.get(size, ASTEROID_SIZES["medium"])
	var radius = config.radius
	var damage = config.damage
	var speed = config.speed

	# Choose target position
	var target_pos: Vector2
	if target_room >= 0:
		target_pos = _get_room_position(target_room)
	else:
		target_pos = ship_center + Vector2(
			randf_range(-ship_width / 3, ship_width / 3),
			randf_range(-ship_height / 3, ship_height / 3)
		)

	# Spawn from off-screen
	var approach_angle = randf_range(-0.5, 0.5)  # Roughly from the right
	var spawn_distance = 400.0
	var spawn_pos = target_pos + Vector2(spawn_distance, 0).rotated(approach_angle)

	# Create asteroid visual
	var asteroid = _create_asteroid(radius)
	asteroid.position = spawn_pos
	add_child(asteroid)

	# Calculate travel time
	var travel_time = spawn_pos.distance_to(target_pos) / speed

	# Animate approach
	var tween = create_tween()
	tween.tween_property(asteroid, "position", target_pos, travel_time)
	tween.tween_property(asteroid, "rotation", randf_range(-TAU, TAU), travel_time)

	await tween.finished

	# Impact!
	_trigger_asteroid_hit(target_pos, radius, damage, target_room)
	asteroid.queue_free()

	event_ended.emit("asteroid")

func _create_asteroid(radius: float) -> Node2D:
	var asteroid = Node2D.new()

	# Main body - irregular shape
	asteroid.draw.connect(func():
		# Draw irregular polygon
		var points: PackedVector2Array = []
		var segments = 8
		for i in range(segments):
			var angle = (float(i) / segments) * TAU
			var r = radius * randf_range(0.7, 1.0)
			points.append(Vector2(cos(angle), sin(angle)) * r)

		# Dark rock color
		var color = Color(0.3, 0.28, 0.25)
		asteroid.draw_colored_polygon(points, color)

		# Crater spots
		for j in range(3):
			var crater_pos = Vector2(randf_range(-radius * 0.5, radius * 0.5),
									  randf_range(-radius * 0.5, radius * 0.5))
			asteroid.draw_circle(crater_pos, radius * 0.15, Color(0.2, 0.18, 0.15))
	)

	# Add trailing particles
	var trail = GPUParticles2D.new()
	trail.amount = 8
	trail.lifetime = 0.5
	trail.emitting = true

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0, 0)  # Trail behind
	material.spread = 20.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 40.0
	material.gravity = Vector3.ZERO
	material.color = Color(0.4, 0.35, 0.3, 0.5)

	trail.process_material = material
	asteroid.add_child(trail)

	return asteroid

func _trigger_asteroid_hit(pos: Vector2, radius: float, damage: float, target_room: int) -> void:
	# Visual impact
	if effects:
		effects.spawn_explosion(pos, radius / 16.0)
		effects.shake_screen(10.0, 0.5)

	# Spawn debris
	for i in range(int(radius / 4)):
		var debris_pos = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		if effects:
			effects.spawn_debris(debris_pos, 3)

	# Create dent/damage mark on hull
	_create_impact_mark(pos, radius)

	# Apply damage
	var room = target_room if target_room >= 0 else _get_nearest_room(pos)
	asteroid_impact.emit(room, damage)

	# Chance to damage control surfaces in room
	if surface_manager and randf() < 0.3:
		var surfaces = ControlSurface.get_surfaces_in_room(room)
		if surfaces.size() > 0:
			var surface_id = surfaces[randi() % surfaces.size()]
			surface_manager.break_surface(surface_id, "asteroid_impact")

func _create_impact_mark(pos: Vector2, radius: float) -> void:
	var mark = Node2D.new()
	mark.position = pos
	mark.z_index = -1  # Behind ship interior

	mark.draw.connect(func():
		# Crater shape
		mark.draw_circle(Vector2.ZERO, radius * 0.8, Color(0.15, 0.15, 0.15, 0.8))
		mark.draw_arc(Vector2.ZERO, radius * 0.7, 0, TAU, 16, Color(0.25, 0.25, 0.25), 2.0)
	)
	mark.queue_redraw()

	add_child(mark)

	# Fade out over time
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(mark, "modulate:a", 0.0, 3.0)
	tween.tween_callback(mark.queue_free)

# ============================================================================
# SOLAR FLARE EVENTS
# ============================================================================

func trigger_solar_flare(intensity: float = 1.0) -> void:
	## Trigger a solar flare event with visual sweep
	event_started.emit("solar_flare")

	# Create flare overlay
	var flare = CanvasLayer.new()
	flare.layer = 4
	add_child(flare)

	# Yellow-orange wash
	var wash = ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1.0, 0.8, 0.3, 0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare.add_child(wash)

	# Lens flare effect (sweeping)
	var lens = _create_lens_flare()
	lens.position = Vector2(-100, 300)  # Start off-screen left
	flare.add_child(lens)

	# Animate
	var tween = create_tween()

	# Fade in wash
	tween.tween_property(wash, "color:a", 0.3 * intensity, 0.5)

	# Sweep lens flare across
	tween.parallel().tween_property(lens, "position:x", 1000, 2.0)

	# Hold at peak
	tween.tween_interval(0.5)

	# Fade out
	tween.tween_property(wash, "color:a", 0.0, 1.0)

	await tween.finished

	# Apply effects
	solar_flare_hit.emit(intensity)

	# Chance to cause power surge (damage electronics)
	if surface_manager and randf() < 0.4 * intensity:
		_trigger_power_surge()

	flare.queue_free()
	event_ended.emit("solar_flare")

func _create_lens_flare() -> Node2D:
	var flare = Node2D.new()

	flare.draw.connect(func():
		# Main flare circle
		flare.draw_circle(Vector2.ZERO, 40, Color(1.0, 0.9, 0.5, 0.4))
		flare.draw_circle(Vector2.ZERO, 25, Color(1.0, 0.95, 0.7, 0.6))
		flare.draw_circle(Vector2.ZERO, 10, Color(1.0, 1.0, 0.9, 0.9))

		# Secondary flares along line
		for i in range(5):
			var offset = Vector2(50 + i * 60, 0)
			var size = 8.0 - i * 1.5
			var alpha = 0.3 - i * 0.05
			flare.draw_circle(offset, size, Color(1.0, 0.8, 0.4, alpha))
	)
	flare.queue_redraw()

	return flare

func _trigger_power_surge() -> void:
	## Electrical damage from solar flare
	if effects:
		# Multiple electrical arcs across ship
		for i in range(3):
			var from_pos = ship_center + Vector2(randf_range(-100, 100), randf_range(-50, 50))
			var to_pos = from_pos + Vector2(randf_range(-50, 50), randf_range(-30, 30))
			effects.spawn_electrical_arc(from_pos, to_pos, 0.3)

	# Damage a random electronic surface
	var electronic_surfaces = [
		ControlSurface.SurfaceId.SENSORS,
		ControlSurface.SurfaceId.MEDICAL_BAY,
		ControlSurface.SurfaceId.SHIELDS
	]

	var target = electronic_surfaces[randi() % electronic_surfaces.size()]
	surface_manager.break_surface(target, "power_surge")

# ============================================================================
# MICROMETEORITE SHOWER
# ============================================================================

func trigger_micrometeorite_shower(count: int = 5, duration: float = 3.0) -> void:
	## Trigger a shower of small micrometeorites
	event_started.emit("micrometeorite")

	var interval = duration / count

	for i in range(count):
		await get_tree().create_timer(interval * randf_range(0.5, 1.5)).timeout
		_spawn_micrometeorite()

	event_ended.emit("micrometeorite")

func _spawn_micrometeorite() -> void:
	# Small, fast projectile
	var target_pos = ship_center + Vector2(
		randf_range(-ship_width / 2, ship_width / 2),
		randf_range(-ship_height / 2, ship_height / 2)
	)

	var spawn_pos = target_pos + Vector2(300, randf_range(-50, 50))

	# Create small particle
	var meteor = ColorRect.new()
	meteor.size = Vector2(3, 3)
	meteor.color = Color(0.6, 0.55, 0.5)
	meteor.position = spawn_pos
	add_child(meteor)

	# Fast travel with trail
	var tween = create_tween()
	tween.tween_property(meteor, "position", target_pos, 0.2)

	await tween.finished

	# Small impact
	if effects:
		effects.spawn_sparks(target_pos, 5)

	var damage = 0.05
	micrometeorite_hit.emit(damage)

	meteor.queue_free()

# ============================================================================
# SPACE DEBRIS COLLISION
# ============================================================================

func trigger_debris_collision(debris_count: int = 1) -> void:
	## Trigger collision with space debris
	event_started.emit("debris")

	for i in range(debris_count):
		await _spawn_debris_object()
		await get_tree().create_timer(0.5).timeout

	event_ended.emit("debris")

func _spawn_debris_object() -> void:
	var debris_type = DEBRIS_TYPES[randi() % DEBRIS_TYPES.size()]

	# Random approach direction
	var approach_dir = Vector2(-1, randf_range(-0.3, 0.3)).normalized()
	var spawn_pos = ship_center - approach_dir * 400

	var target_pos = ship_center + Vector2(
		randf_range(-50, 50),
		randf_range(-30, 30)
	)

	# Create debris visual
	var debris = ColorRect.new()
	debris.size = debris_type.size
	debris.color = debris_type.color
	debris.position = spawn_pos
	debris.pivot_offset = debris_type.size / 2
	add_child(debris)

	# Tumbling approach
	var travel_time = 1.5
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(debris, "position", target_pos, travel_time)
	tween.tween_property(debris, "rotation", randf_range(-TAU * 2, TAU * 2), travel_time)

	await tween.finished

	# Impact or bounce
	var will_bounce = randf() < 0.4

	if will_bounce:
		# Bounce off hull
		var bounce_dir = Vector2(randf_range(0.5, 1.0), randf_range(-1, 1)).normalized()
		var bounce_pos = target_pos + bounce_dir * 200

		if effects:
			effects.spawn_sparks(target_pos, 8)
			effects.shake_screen(3.0, 0.15)

		var bounce_tween = create_tween()
		bounce_tween.tween_property(debris, "position", bounce_pos, 1.0)
		bounce_tween.parallel().tween_property(debris, "modulate:a", 0.0, 1.0)
		await bounce_tween.finished
	else:
		# Stick/embed
		if effects:
			effects.spawn_sparks(target_pos, 12)
			effects.spawn_debris(target_pos, 4)
			effects.shake_screen(5.0, 0.25)

		var damage = 0.15
		debris_collision.emit(damage)

		# Fade embedded debris
		var fade_tween = create_tween()
		fade_tween.tween_interval(3.0)
		fade_tween.tween_property(debris, "modulate:a", 0.0, 2.0)
		await fade_tween.finished

	debris.queue_free()

# ============================================================================
# WARNING SYSTEM
# ============================================================================

func show_incoming_warning(event_type: String, seconds: float = 3.0) -> void:
	## Show warning indicator for incoming event
	var warning = _create_warning_indicator(event_type)
	add_child(warning)

	# Flash warning
	var tween = create_tween().set_loops(int(seconds * 2))
	tween.tween_property(warning, "modulate:a", 0.3, 0.25)
	tween.tween_property(warning, "modulate:a", 1.0, 0.25)

	await get_tree().create_timer(seconds).timeout
	warning.queue_free()

func _create_warning_indicator(event_type: String) -> Node2D:
	var indicator = Node2D.new()
	indicator.position = Vector2(ship_center.x + ship_width / 2 + 50, ship_center.y)

	# Warning arrow pointing at ship
	indicator.draw.connect(func():
		# Triangle pointing left
		var points = PackedVector2Array([
			Vector2(0, 0),
			Vector2(20, -15),
			Vector2(20, 15)
		])
		indicator.draw_colored_polygon(points, Color(1.0, 0.3, 0.2))

		# Exclamation mark
		indicator.draw_circle(Vector2(35, -5), 3, Color.WHITE)
		indicator.draw_rect(Rect2(32, 2, 6, 15), Color.WHITE)
	)
	indicator.queue_redraw()

	# Warning label
	var label = Label.new()
	label.text = event_type.to_upper().replace("_", " ")
	label.position = Vector2(50, -10)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	indicator.add_child(label)

	return indicator

# ============================================================================
# HELPERS
# ============================================================================

func _get_room_position(room_type: int) -> Vector2:
	## Get approximate world position of a room
	# These should match the layout in ship_view.gd
	var room_offsets = {
		ShipTypes.RoomType.MEDICAL: Vector2(-195, -50),
		ShipTypes.RoomType.QUARTERS: Vector2(-65, -50),
		ShipTypes.RoomType.CORRIDOR: Vector2(65, -50),
		ShipTypes.RoomType.BRIDGE: Vector2(195, -50),
		ShipTypes.RoomType.CARGO_BAY: Vector2(-195, 50),
		ShipTypes.RoomType.LIFE_SUPPORT: Vector2(-65, 50),
		ShipTypes.RoomType.ENGINEERING: Vector2(65, 50)
	}

	return ship_center + room_offsets.get(room_type, Vector2.ZERO)

func _get_nearest_room(pos: Vector2) -> int:
	## Find the room nearest to a position
	var nearest_room = ShipTypes.RoomType.CORRIDOR
	var nearest_dist = INF

	for room_type in [
		ShipTypes.RoomType.MEDICAL,
		ShipTypes.RoomType.QUARTERS,
		ShipTypes.RoomType.CORRIDOR,
		ShipTypes.RoomType.BRIDGE,
		ShipTypes.RoomType.CARGO_BAY,
		ShipTypes.RoomType.LIFE_SUPPORT,
		ShipTypes.RoomType.ENGINEERING
	]:
		var room_pos = _get_room_position(room_type)
		var dist = pos.distance_to(room_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_room = room_type

	return nearest_room
