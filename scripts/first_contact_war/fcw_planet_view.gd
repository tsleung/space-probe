extends Control
class_name FCWPlanetView

## Planet Detail View - Picture-in-picture window showing zoomed planet
## Positioned near the focused planet in the solar map

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")

signal close_requested
signal position_changed(new_position: Vector2)  # Emitted when user drags the panel

# ============================================================================
# CONSTANTS
# ============================================================================

const ZONE_COLORS = {
	FCWTypes.ZoneId.EARTH: Color(0.2, 0.5, 1.0),
	FCWTypes.ZoneId.MARS: Color(0.9, 0.4, 0.2),
	FCWTypes.ZoneId.ASTEROID_BELT: Color(0.6, 0.6, 0.6),
	FCWTypes.ZoneId.JUPITER: Color(0.9, 0.7, 0.5),
	FCWTypes.ZoneId.SATURN: Color(0.9, 0.85, 0.6),
	FCWTypes.ZoneId.KUIPER: Color(0.4, 0.5, 0.7)
}

enum StagingType { MOON, ASTEROID_CLUSTER, STATION, RING }

const STAGING_AREAS = {
	FCWTypes.ZoneId.EARTH: [
		{"name": "Luna", "offset": Vector2(-0.35, -0.25), "type": StagingType.MOON, "size": 0.12},
		{"name": "L2 Station", "offset": Vector2(0.4, 0.15), "type": StagingType.STATION, "size": 0.08},
	],
	FCWTypes.ZoneId.MARS: [
		{"name": "Phobos", "offset": Vector2(-0.3, -0.2), "type": StagingType.MOON, "size": 0.08},
		{"name": "Deimos", "offset": Vector2(0.25, 0.22), "type": StagingType.MOON, "size": 0.06},
	],
	FCWTypes.ZoneId.ASTEROID_BELT: [
		{"name": "Ceres Cluster", "offset": Vector2(-0.35, 0), "type": StagingType.ASTEROID_CLUSTER, "size": 0.15},
		{"name": "Vesta Field", "offset": Vector2(0.3, -0.2), "type": StagingType.ASTEROID_CLUSTER, "size": 0.12},
	],
	FCWTypes.ZoneId.JUPITER: [
		{"name": "Europa", "offset": Vector2(-0.38, -0.28), "type": StagingType.MOON, "size": 0.1},
		{"name": "Ganymede", "offset": Vector2(0.4, 0.08), "type": StagingType.MOON, "size": 0.12},
		{"name": "Io Station", "offset": Vector2(-0.25, 0.32), "type": StagingType.STATION, "size": 0.07},
	],
	FCWTypes.ZoneId.SATURN: [
		{"name": "Titan", "offset": Vector2(-0.38, 0.2), "type": StagingType.MOON, "size": 0.11},
		{"name": "Rings", "offset": Vector2(0, 0), "type": StagingType.RING, "size": 0.5},
		{"name": "Enceladus", "offset": Vector2(0.35, -0.18), "type": StagingType.MOON, "size": 0.07},
	],
	FCWTypes.ZoneId.KUIPER: [
		{"name": "Pluto", "offset": Vector2(-0.22, -0.15), "type": StagingType.MOON, "size": 0.09},
		{"name": "Eris Cluster", "offset": Vector2(0.28, 0.18), "type": StagingType.ASTEROID_CLUSTER, "size": 0.1},
	]
}

# ============================================================================
# STATE
# ============================================================================

var _zone_id: int = -1
var _zone_status: int = FCWTypes.ZoneStatus.CONTROLLED
var _zone_defense: int = 0
var _herald_strength: int = 0
var _herald_targeting: bool = false
var _global_time: float = 0.0
var _attack_flash_timer: float = 0.0

# Combat effects
var _lasers: Array = []
var _explosions: Array = []
var _sparks: Array = []
var _combat_intensity: float = 0.0
var _time_since_show: float = 0.0

# Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not visible:
		return

	_global_time += delta
	_time_since_show += delta

	if _herald_targeting:
		_attack_flash_timer += delta * 5.0

	# Update combat effects
	_update_effects(delta)

	# Spawn combat effects if under attack (start immediately, ramp up quickly)
	if _herald_targeting:
		# Start effects immediately with initial intensity, ramp to full quickly
		if _time_since_show > 0.15:  # Very brief delay for visual setup
			_combat_intensity = minf(_combat_intensity + delta * 3.0, 1.0)  # Ramp up over ~0.3s
		_maybe_spawn_combat_effects(delta)  # Spawn effects even during ramp up
	else:
		_combat_intensity = maxf(_combat_intensity - delta * 2.0, 0.0)

	queue_redraw()

func _draw() -> void:
	if _zone_id < 0:
		return

	var rect = get_rect()
	var center = rect.size / 2

	# Background with border
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.02, 0.02, 0.04, 0.95))

	# Border color based on status
	var border_color = Color(0.3, 0.4, 0.5)
	if _herald_targeting:
		var pulse = sin(_attack_flash_timer * 3.0) * 0.3 + 0.7
		border_color = Color(1.0, 0.3, 0.2, pulse)
	elif _zone_status == FCWTypes.ZoneStatus.FALLEN:
		border_color = Color(0.4, 0.2, 0.2)
	draw_rect(Rect2(Vector2.ZERO, rect.size), border_color, false, 2.0)

	# Starfield background
	_draw_starfield(rect)

	# Zone data
	var zone_color = ZONE_COLORS.get(_zone_id, Color.WHITE)
	if _zone_status == FCWTypes.ZoneStatus.FALLEN:
		zone_color = zone_color.darkened(0.7)
	elif _zone_status == FCWTypes.ZoneStatus.UNDER_ATTACK:
		var pulse = sin(_attack_flash_timer * 4.0) * 0.4 + 0.6
		zone_color = zone_color.lerp(Color.RED, 0.5 * pulse)

	# Planet size relative to window
	var planet_size = minf(rect.size.x, rect.size.y) * 0.25

	# Draw staging areas first (behind planet)
	_draw_staging_areas(center, planet_size, rect)

	# Atmospheric glow
	if _zone_status != FCWTypes.ZoneStatus.FALLEN:
		draw_circle(center, planet_size + 12, Color(zone_color.r, zone_color.g, zone_color.b, 0.1))
		draw_circle(center, planet_size + 6, Color(zone_color.r, zone_color.g, zone_color.b, 0.15))

	# The planet
	draw_circle(center, planet_size, zone_color)

	# Planet surface details
	var rng = RandomNumberGenerator.new()
	rng.seed = _zone_id * 100
	for i in range(6):
		var detail_angle = rng.randf() * TAU
		var detail_dist = rng.randf_range(planet_size * 0.2, planet_size * 0.65)
		var detail_pos = center + Vector2(cos(detail_angle), sin(detail_angle)) * detail_dist
		var detail_size = rng.randf_range(planet_size * 0.05, planet_size * 0.12)
		draw_circle(detail_pos, detail_size, zone_color.darkened(rng.randf_range(0.1, 0.25)))

	# Planet shine
	if _zone_status != FCWTypes.ZoneStatus.FALLEN:
		var shine_pos = center + Vector2(-planet_size * 0.35, -planet_size * 0.35)
		draw_circle(shine_pos, planet_size * 0.18, Color(1, 1, 1, 0.25))

	# Saturn rings
	if _zone_id == FCWTypes.ZoneId.SATURN:
		_draw_saturn_rings(center, planet_size)

	# Draw combat effects
	_draw_lasers()
	_draw_explosions()
	_draw_sparks()

	# UI overlay
	_draw_ui_overlay(rect)

	# Danger vignette if under attack
	if _herald_targeting and _combat_intensity > 0.1:
		_draw_danger_vignette(rect)

func _draw_starfield(rect: Rect2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = _zone_id * 1000 + 54321
	for i in range(60):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var brightness = rng.randf_range(0.15, 0.5)
		var twinkle = sin(_global_time * rng.randf_range(1.0, 3.0) + i) * 0.2 + 0.8
		draw_circle(pos, rng.randf_range(0.5, 1.2), Color(brightness * twinkle, brightness * twinkle, brightness * twinkle * 1.1))

func _draw_staging_areas(center: Vector2, planet_size: float, rect: Rect2) -> void:
	var staging_list = STAGING_AREAS.get(_zone_id, [])
	var scale = minf(rect.size.x, rect.size.y)

	for staging in staging_list:
		var staging_pos = center + staging.offset * scale * 0.4
		var staging_size = staging.size * scale * 0.4

		match staging.type:
			StagingType.MOON:
				_draw_moon(staging_pos, staging_size, staging.name)
			StagingType.ASTEROID_CLUSTER:
				_draw_asteroid_cluster(staging_pos, staging_size, staging.name)
			StagingType.STATION:
				_draw_station(staging_pos, staging_size, staging.name)

func _draw_moon(pos: Vector2, size: float, moon_name: String) -> void:
	var base_color = Color(0.55, 0.55, 0.6)
	draw_circle(pos, size + 2, Color(0.4, 0.4, 0.5, 0.2))
	draw_circle(pos, size, base_color)

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(moon_name)
	for i in range(3):
		var crater_offset = Vector2(rng.randf_range(-size * 0.5, size * 0.5), rng.randf_range(-size * 0.5, size * 0.5))
		draw_circle(pos + crater_offset, size * rng.randf_range(0.1, 0.2), base_color.darkened(0.2))

	draw_circle(pos + Vector2(-size * 0.3, -size * 0.3), size * 0.2, Color(0.7, 0.7, 0.75, 0.4))

	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-20, size + 10), moon_name, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.6, 0.6, 0.7, 0.8))

func _draw_asteroid_cluster(pos: Vector2, size: float, cluster_name: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(cluster_name)

	for i in range(int(size / 2) + 4):
		var asteroid_offset = Vector2(rng.randf_range(-size, size), rng.randf_range(-size, size))
		var asteroid_size = rng.randf_range(1.5, 4)
		var color = Color(rng.randf_range(0.35, 0.5), rng.randf_range(0.3, 0.45), rng.randf_range(0.25, 0.4))
		draw_circle(pos + asteroid_offset, asteroid_size, color)

	var segment_count = 12
	for i in range(segment_count):
		if i % 2 == 0:
			var angle_start = i * TAU / segment_count + _global_time * 0.1
			draw_arc(pos, size + 3, angle_start, angle_start + TAU / segment_count * 0.6, 4, Color(0.4, 0.4, 0.35, 0.25), 1.0)

	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-25, size + 10), cluster_name, HORIZONTAL_ALIGNMENT_CENTER, 50, 8, Color(0.5, 0.5, 0.5, 0.8))

func _draw_station(pos: Vector2, size: float, station_name: String) -> void:
	var rotation = _global_time * 0.4
	draw_circle(pos, size * 0.6, Color(0.55, 0.6, 0.65))
	draw_circle(pos, size * 0.35, Color(0.65, 0.7, 0.75))

	for i in range(4):
		var arm_angle = rotation + i * TAU / 4
		var arm_end = pos + Vector2(cos(arm_angle), sin(arm_angle)) * size
		draw_line(pos, arm_end, Color(0.55, 0.6, 0.65), 2.0)
		draw_circle(arm_end, size * 0.25, Color(0.6, 0.65, 0.7))

	var blink = sin(_global_time * 3.0) * 0.5 + 0.5
	draw_circle(pos, 2.5, Color(0.2, 1.0, 0.3, blink))

	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-20, size + 8), station_name, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.5, 0.7, 0.6, 0.8))

func _draw_saturn_rings(center: Vector2, planet_size: float) -> void:
	var ring_colors = [Color(0.8, 0.75, 0.6, 0.3), Color(0.85, 0.8, 0.65, 0.25)]
	for i in range(2):
		var ring_radius = planet_size * 1.4 - i * 8
		var points = PackedVector2Array()
		for j in range(33):
			var angle = j * TAU / 32
			points.append(center + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.3))
		for j in range(16):
			var idx = j + 8
			if idx < points.size() - 1:
				draw_line(points[idx], points[idx + 1], ring_colors[i], 3.0)

func _draw_ui_overlay(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var zone_name = FCWTypes.get_zone_name(_zone_id)

	# Zone name at top
	draw_string(font, Vector2(8, 16), zone_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Status
	var status_text: String
	var status_color: Color
	match _zone_status:
		FCWTypes.ZoneStatus.CONTROLLED:
			status_text = "CONTROLLED"
			status_color = Color(0.3, 0.9, 0.3)
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			status_text = "UNDER ATTACK"
			status_color = Color(1.0, 0.3, 0.2)
		FCWTypes.ZoneStatus.FALLEN:
			status_text = "FALLEN"
			status_color = Color(0.5, 0.3, 0.3)
	draw_string(font, Vector2(8, 30), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, status_color)

	# Close button hint
	draw_string(font, Vector2(rect.size.x - 20, 14), "X", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(0.6, 0.6, 0.6))

	# ========== BOTTOM PANEL (battle stats or peace info) ==========
	var panel_y = rect.size.y - 75
	var panel_h = 70
	draw_rect(Rect2(4, panel_y, rect.size.x - 8, panel_h), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(4, panel_y, rect.size.x - 8, panel_h), Color(0.3, 0.3, 0.4, 0.5), false, 1.0)

	# During peace (herald_strength = 0), show peaceful info
	if _herald_strength == 0:
		draw_string(font, Vector2(8, panel_y + 12), "ZONE STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.7, 0.8))
		draw_string(font, Vector2(8, panel_y + 30), "No threats detected", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.8, 0.4))
		draw_string(font, Vector2(8, panel_y + 48), "Defense: %d" % _zone_defense, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.6, 0.7))
		draw_string(font, Vector2(8, panel_y + 62), "Civilian traffic normal", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.6))
		return

	# Force comparison header
	draw_string(font, Vector2(8, panel_y + 12), "BATTLE STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.7, 0.8))

	# Defense vs Attack values
	var def_color: Color
	var ratio = float(_zone_defense) / maxf(_herald_strength, 1)
	if ratio >= 1.3:
		def_color = Color(0.3, 1.0, 0.3)
	elif ratio >= 1.0:
		def_color = Color(1.0, 1.0, 0.3)
	else:
		def_color = Color(1.0, 0.3, 0.3)

	# Left side: Our forces
	draw_string(font, Vector2(8, panel_y + 26), "DEFENSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.5, 0.6, 0.7))
	draw_string(font, Vector2(8, panel_y + 40), "%d" % _zone_defense, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.7, 1.0))

	# Center: VS
	draw_string(font, Vector2(rect.size.x / 2 - 8, panel_y + 35), "vs", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.5, 0.5, 0.5))

	# Right side: Herald forces
	draw_string(font, Vector2(rect.size.x - 8, panel_y + 26), "HERALD", HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16, 7, Color(0.7, 0.5, 0.5))
	draw_string(font, Vector2(rect.size.x - 8, panel_y + 40), "%d" % _herald_strength, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16, 14, Color(0.9, 0.3, 0.5))

	# Outcome prediction bar
	var bar_y = panel_y + 48
	var bar_w = rect.size.x - 16
	var bar_h = 6

	# Background bar
	draw_rect(Rect2(8, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.2))

	# Fill based on defense ratio (capped at 2x for visual)
	var fill_ratio = clampf(ratio / 2.0, 0.0, 1.0)
	var fill_color = def_color
	draw_rect(Rect2(8, bar_y, bar_w * fill_ratio, bar_h), fill_color)

	# Outcome text
	var outcome_text: String
	var outcome_color: Color
	if _zone_defense == 0:
		outcome_text = "UNDEFENDED - WILL FALL"
		outcome_color = Color(1.0, 0.2, 0.2)
	elif ratio >= 1.3:
		outcome_text = "STRONG DEFENSE - WILL HOLD"
		outcome_color = Color(0.3, 1.0, 0.3)
	elif ratio >= 1.0:
		outcome_text = "MARGINAL - SHOULD HOLD"
		outcome_color = Color(1.0, 1.0, 0.3)
	elif ratio >= 0.7:
		outcome_text = "WEAK - LIKELY TO FALL"
		outcome_color = Color(1.0, 0.5, 0.2)
	else:
		outcome_text = "CRITICAL - WILL FALL"
		outcome_color = Color(1.0, 0.2, 0.2)

	draw_string(font, Vector2(8, panel_y + 64), outcome_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 8, outcome_color)

	# If under attack, show what's happening
	if _herald_targeting:
		var pulse = sin(_attack_flash_timer * 2.0) * 0.3 + 0.7
		draw_string(font, Vector2(rect.size.x - 8, panel_y + 64), "COMBAT", HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, Color(1.0, 0.3, 0.2, pulse))

func _draw_danger_vignette(rect: Rect2) -> void:
	var edge_color = Color(0.8, 0.0, 0.0, _combat_intensity * 0.3)
	var edge_size = 30 * _combat_intensity
	draw_rect(Rect2(0, 0, rect.size.x, edge_size), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.5))
	draw_rect(Rect2(0, rect.size.y - edge_size, rect.size.x, edge_size), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.5))

# ============================================================================
# COMBAT EFFECTS
# ============================================================================

func _maybe_spawn_combat_effects(delta: float) -> void:
	# Spawn lasers frequently
	if randf() < delta * 15.0 * _combat_intensity:
		_spawn_laser()

	# Spawn explosions occasionally
	if randf() < delta * 5.0 * _combat_intensity:
		_spawn_explosion()

	# Spawn sparks
	if randf() < delta * 20.0 * _combat_intensity:
		_spawn_spark()

func _spawn_laser() -> void:
	var rect = get_rect()
	var center = rect.size / 2
	var radius = minf(rect.size.x, rect.size.y) * 0.35

	var laser = {
		"start": center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)),
		"end": center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)),
		"color": Color(1.0, 0.3, 0.0) if randf() > 0.4 else Color(0.3, 0.7, 1.0),
		"life": randf_range(0.1, 0.2),
		"width": randf_range(1.0, 2.5)
	}
	_lasers.append(laser)

func _spawn_explosion() -> void:
	var rect = get_rect()
	var center = rect.size / 2
	var radius = minf(rect.size.x, rect.size.y) * 0.35

	var exp = {
		"pos": center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)),
		"radius": 0.0,
		"max_radius": randf_range(10, 25),
		"life": randf_range(0.3, 0.5),
		"color": Color(1.0, randf_range(0.3, 0.7), 0.0)
	}
	_explosions.append(exp)

func _spawn_spark() -> void:
	var rect = get_rect()
	var center = rect.size / 2
	var radius = minf(rect.size.x, rect.size.y) * 0.35

	var spark = {
		"pos": center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)),
		"vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
		"life": randf_range(0.2, 0.4),
		"size": randf_range(1, 3),
		"color": Color(1.0, randf_range(0.5, 0.9), 0.2)
	}
	_sparks.append(spark)

func _update_effects(delta: float) -> void:
	# Update lasers
	var i = 0
	while i < _lasers.size():
		_lasers[i].life -= delta
		if _lasers[i].life <= 0:
			_lasers.remove_at(i)
		else:
			i += 1

	# Update explosions
	i = 0
	while i < _explosions.size():
		var exp = _explosions[i]
		exp.life -= delta
		exp.radius = exp.max_radius * (1.0 - exp.life / 0.5)
		if exp.life <= 0:
			_explosions.remove_at(i)
		else:
			i += 1

	# Update sparks
	i = 0
	while i < _sparks.size():
		var spark = _sparks[i]
		spark.pos += spark.vel * delta
		spark.life -= delta
		if spark.life <= 0:
			_sparks.remove_at(i)
		else:
			i += 1

func _draw_lasers() -> void:
	for laser in _lasers:
		var alpha = laser.life / 0.2
		draw_line(laser.start, laser.end, Color(laser.color.r, laser.color.g, laser.color.b, alpha * 0.3), laser.width * 3)
		draw_line(laser.start, laser.end, Color(laser.color.r, laser.color.g, laser.color.b, alpha), laser.width)

func _draw_explosions() -> void:
	for exp in _explosions:
		var alpha = exp.life / 0.5
		draw_arc(exp.pos, exp.radius, 0, TAU, 16, Color(exp.color.r, exp.color.g * 0.5, 0, alpha * 0.8), 2.0)
		draw_circle(exp.pos, exp.radius * 0.5, Color(1, 1, 0.8, alpha * 0.4))

func _draw_sparks() -> void:
	for spark in _sparks:
		var alpha = spark.life / 0.4
		draw_circle(spark.pos, spark.size * alpha, Color(spark.color.r, spark.color.g, spark.color.b, alpha))

# ============================================================================
# PUBLIC API
# ============================================================================

func show_zone(zone_id: int, zone_status: int, zone_defense: int, herald_strength: int, is_herald_target: bool) -> void:
	_zone_id = zone_id
	_zone_status = zone_status
	_zone_defense = zone_defense
	_herald_strength = herald_strength
	_herald_targeting = is_herald_target
	_time_since_show = 0.0
	_combat_intensity = 0.0 if not is_herald_target else 0.3  # Start with some intensity if under attack
	_lasers.clear()
	_explosions.clear()
	_sparks.clear()
	visible = true
	queue_redraw()

func hide_view() -> void:
	visible = false
	_zone_id = -1

func update_zone_state(zone_status: int, zone_defense: int, herald_strength: int, is_herald_target: bool) -> void:
	_zone_status = zone_status
	_zone_defense = zone_defense
	_herald_strength = herald_strength
	_herald_targeting = is_herald_target

func get_focused_zone() -> int:
	return _zone_id

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var rect = get_rect()
			if event.pressed:
				# Check if clicked close button area (top-right corner)
				if event.position.x > rect.size.x - 25 and event.position.y < 25:
					close_requested.emit()
					hide_view()
				else:
					# Start dragging
					_dragging = true
					_drag_offset = event.position
					accept_event()
			else:
				# Stop dragging - emit new position so it can be saved
				if _dragging:
					position_changed.emit(position)
				_dragging = false

	elif event is InputEventMouseMotion and _dragging:
		# Move the panel
		position += event.position - _drag_offset
		accept_event()
