extends Control
class_name FCWBattleView

## Zoomed Tactical Battle View
const FCWBattleSystemScript = preload("res://scripts/fcw/fcw_battle_system.gd")
## Shows PDC fire, torpedoes, named ships fighting and dying
## Inspired by The Expanse's visceral space combat

# ============================================================================
# DESIGN NOTES (for iteration)
# ============================================================================
# Goal: Make players FEEL the battle, not just see numbers change
# - Ships should have visible PDC (Point Defense Cannon) fire - rapid small tracers
# - Torpedoes should be slower, more deliberate, more deadly
# - Ships should visibly take damage and explode
# - Named ships dying should hurt
# - Herald forces should feel overwhelming, alien, wrong
#
# Visual language:
# - Human ships: Blue engine glow, white/blue weapons
# - Herald: Red/orange, organic-feeling, numerous
# - Explosions: Orange/yellow with debris
# - PDC: Rapid white tracers
# - Torpedoes: Slow moving dots with trails

signal battle_complete
signal ship_destroyed(ship_name: String)

# ============================================================================
# VISUAL ENTITIES
# ============================================================================

class BattleShip:
	var pos: Vector2
	var vel: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var ship_data = null  # FCWBattleSystem.NamedShip
	var health: float = 1.0
	var is_player: bool = true
	var size: float = 20.0
	var target: BattleShip = null
	var pdc_cooldown: float = 0.0
	var torpedo_cooldown: float = 0.0
	var is_destroyed: bool = false
	var destruction_timer: float = 0.0

class Projectile:
	var pos: Vector2
	var vel: Vector2
	var is_torpedo: bool = false
	var is_player: bool = true
	var damage: float = 0.1
	var life: float = 2.0
	var trail: Array = []

class BattleExplosion:
	var pos: Vector2
	var radius: float = 0.0
	var max_radius: float = 30.0
	var life: float = 1.0
	var is_ship_death: bool = false
	var ship_name: String = ""

class Debris:
	var pos: Vector2
	var vel: Vector2
	var rotation: float
	var spin: float
	var size: float
	var life: float

# ============================================================================
# STATE
# ============================================================================

var _player_ships: Array = []
var _herald_ships: Array = []
var _projectiles: Array = []
var _explosions: Array = []
var _debris: Array = []
var _battle_time: float = 0.0
var _battle_duration: float = 8.0  # Seconds of battle
var _is_active: bool = false
var _zone_name: String = ""
var _outcome_decided: bool = false
var _player_won: bool = false

# Transmission queue
var _transmissions: Array = []
var _current_transmission: String = ""
var _transmission_timer: float = 0.0

# Camera
var _camera_shake: Vector2 = Vector2.ZERO
var _shake_intensity: float = 0.0

# ============================================================================
# LIFECYCLE
# ============================================================================

func _process(delta: float) -> void:
	if not _is_active:
		return

	_battle_time += delta

	# Update camera shake
	if _shake_intensity > 0:
		_camera_shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
		_shake_intensity = maxf(_shake_intensity - delta * 15.0, 0.0)
	else:
		_camera_shake = Vector2.ZERO

	# Update all entities
	_update_ships(delta)
	_update_projectiles(delta)
	_update_explosions(delta)
	_update_debris(delta)
	_update_transmissions(delta)

	# Check battle end
	if _battle_time >= _battle_duration and not _outcome_decided:
		_end_battle()

	queue_redraw()

func _draw() -> void:
	var rect = get_rect()
	var offset = _camera_shake

	# Dark space background
	draw_rect(rect, Color(0.02, 0.02, 0.04))

	# Starfield
	_draw_stars(rect, offset)

	# Draw debris (behind ships)
	for d in _debris:
		_draw_debris_piece(d, offset)

	# Draw projectiles
	for p in _projectiles:
		_draw_projectile(p, offset)

	# Draw ships
	for ship in _player_ships:
		if not ship.is_destroyed:
			_draw_ship(ship, offset, true)

	for ship in _herald_ships:
		if not ship.is_destroyed:
			_draw_ship(ship, offset, false)

	# Draw explosions (on top)
	for exp in _explosions:
		_draw_explosion(exp, offset)

	# Draw UI overlay
	_draw_battle_ui(rect)

	# Draw transmission
	if not _current_transmission.is_empty():
		_draw_transmission(rect)

# ============================================================================
# DRAWING FUNCTIONS
# ============================================================================

func _draw_stars(rect: Rect2, offset: Vector2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99999
	for i in range(60):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.2
		var brightness = rng.randf_range(0.2, 0.6)
		draw_circle(pos, 1, Color(brightness, brightness, brightness))

func _draw_ship(ship: BattleShip, offset: Vector2, is_player: bool) -> void:
	var pos = ship.pos + offset

	if is_player:
		# Human ship - angular, military
		var dir = Vector2.from_angle(ship.rotation)
		var perp = Vector2(-dir.y, dir.x)
		var s = ship.size

		# Hull
		var hull_points = PackedVector2Array([
			pos + dir * s,  # Nose
			pos + dir * s * 0.3 + perp * s * 0.4,
			pos - dir * s * 0.8 + perp * s * 0.3,
			pos - dir * s * 0.8 - perp * s * 0.3,
			pos + dir * s * 0.3 - perp * s * 0.4,
		])
		var hull_color = Color(0.3, 0.35, 0.4) if ship.health > 0.3 else Color(0.4, 0.2, 0.1)
		draw_colored_polygon(hull_points, hull_color)

		# Engine glow
		var engine_pos = pos - dir * s * 0.7
		draw_circle(engine_pos + perp * s * 0.15, 4, Color(0.3, 0.6, 1.0, 0.8))
		draw_circle(engine_pos - perp * s * 0.15, 4, Color(0.3, 0.6, 1.0, 0.8))

		# Damage sparks
		if ship.health < 0.5:
			if randf() < 0.3:
				var spark_pos = pos + Vector2(randf_range(-s, s), randf_range(-s, s)) * 0.5
				draw_circle(spark_pos, 2, Color(1, 0.5, 0, randf()))

		# Ship name (small)
		if ship.ship_data:
			var font = ThemeDB.fallback_font
			draw_string(font, pos + Vector2(-25, -s - 5), ship.ship_data.name, HORIZONTAL_ALIGNMENT_CENTER, 50, 8, Color(0.6, 0.8, 1.0, 0.8))

	else:
		# Herald ship - organic, alien, wrong
		var pulse = sin(_battle_time * 3.0 + ship.pos.x * 0.1) * 0.2 + 0.8
		var s = ship.size * pulse

		# Organic blob shape
		draw_circle(pos, s, Color(0.5, 0.1, 0.05, 0.8))
		draw_circle(pos, s * 0.7, Color(0.7, 0.15, 0.05, 0.9))

		# Glowing core
		draw_circle(pos, s * 0.3, Color(1.0, 0.3, 0.0, pulse))

		# Tendrils
		for i in range(4):
			var angle = _battle_time * 0.5 + i * TAU / 4
			var tendril_end = pos + Vector2.from_angle(angle) * s * 1.5
			draw_line(pos, tendril_end, Color(0.6, 0.1, 0.0, 0.5), 2)

func _draw_projectile(p: Projectile, offset: Vector2) -> void:
	var pos = p.pos + offset

	if p.is_torpedo:
		# Torpedo - larger, with trail
		var trail_color = Color(0.3, 0.8, 1.0, 0.3) if p.is_player else Color(1.0, 0.3, 0.0, 0.3)
		for i in range(p.trail.size()):
			var trail_pos = p.trail[i] + offset
			var alpha = float(i) / p.trail.size() * 0.5
			draw_circle(trail_pos, 3, Color(trail_color.r, trail_color.g, trail_color.b, alpha))

		var torp_color = Color(0.5, 0.9, 1.0) if p.is_player else Color(1.0, 0.4, 0.0)
		draw_circle(pos, 4, torp_color)
		draw_circle(pos, 2, Color.WHITE)
	else:
		# PDC round - tiny, fast, numerous
		var pdc_color = Color(1, 1, 0.8, 0.9) if p.is_player else Color(1.0, 0.3, 0.0, 0.9)
		draw_circle(pos, 1.5, pdc_color)

func _draw_explosion(exp: BattleExplosion, offset: Vector2) -> void:
	var pos = exp.pos + offset
	var progress = 1.0 - exp.life
	var current_radius = exp.max_radius * progress

	# Outer ring
	draw_arc(pos, current_radius, 0, TAU, 24, Color(1.0, 0.5, 0.0, exp.life * 0.8), 3.0)

	# Inner flash
	var flash_radius = current_radius * 0.6
	draw_circle(pos, flash_radius, Color(1, 1, 0.8, exp.life * 0.5))

	# Core
	draw_circle(pos, current_radius * 0.2 * exp.life, Color(1, 1, 1, exp.life))

	# Ship death - extra drama
	if exp.is_ship_death and exp.life > 0.7:
		# Secondary explosions
		for i in range(3):
			var secondary_pos = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			draw_circle(secondary_pos, 10 * exp.life, Color(1, 0.6, 0.2, exp.life))

func _draw_debris_piece(d: Debris, offset: Vector2) -> void:
	var pos = d.pos + offset
	var alpha = d.life
	# Simple triangle debris
	var points = PackedVector2Array()
	for i in range(3):
		var angle = d.rotation + i * TAU / 3
		points.append(pos + Vector2.from_angle(angle) * d.size)
	draw_colored_polygon(points, Color(0.4, 0.3, 0.3, alpha))

func _draw_battle_ui(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font

	# Zone name header
	draw_string(font, Vector2(rect.size.x / 2 - 80, 30), "BATTLE FOR %s" % _zone_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color.WHITE)

	# Ship counts
	var player_alive = _player_ships.filter(func(s): return not s.is_destroyed).size()
	var herald_alive = _herald_ships.filter(func(s): return not s.is_destroyed).size()

	draw_string(font, Vector2(20, 60), "DEFENDERS: %d" % player_alive,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.8, 1.0))
	draw_string(font, Vector2(rect.size.x - 120, 60), "HERALD: %d" % herald_alive,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.4, 0.3))

	# Battle timer bar
	var bar_width = 200
	var bar_x = rect.size.x / 2 - bar_width / 2
	var progress = _battle_time / _battle_duration
	draw_rect(Rect2(bar_x, 50, bar_width, 8), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(bar_x, 50, bar_width * progress, 8), Color(1.0, 0.5, 0.0))

func _draw_transmission(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font

	# Transmission box at bottom
	var box_height = 60
	var box_y = rect.size.y - box_height - 10
	draw_rect(Rect2(10, box_y, rect.size.x - 20, box_height), Color(0.0, 0.1, 0.2, 0.9))
	draw_rect(Rect2(10, box_y, rect.size.x - 20, box_height), Color(0.3, 0.5, 0.7, 0.8), false, 2.0)

	# Transmission text with typing effect
	var visible_chars = int(_transmission_timer * 50)
	var display_text = _current_transmission.substr(0, visible_chars)
	draw_string(font, Vector2(20, box_y + 35), display_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40, 12, Color(0.7, 0.9, 1.0))

	# Blinking cursor
	if fmod(_transmission_timer, 0.5) < 0.25:
		var cursor_x = 20 + font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(cursor_x, box_y + 25, 8, 14), Color(0.7, 0.9, 1.0))

# ============================================================================
# UPDATE FUNCTIONS
# ============================================================================

func _update_ships(delta: float) -> void:
	# Player ships behavior
	for ship in _player_ships:
		if ship.is_destroyed:
			continue

		# Find nearest herald target
		if ship.target == null or ship.target.is_destroyed:
			ship.target = _find_nearest_target(ship, _herald_ships)

		if ship.target:
			# Rotate toward target
			var to_target = ship.target.pos - ship.pos
			var target_angle = to_target.angle()
			ship.rotation = lerp_angle(ship.rotation, target_angle, delta * 2.0)

			# Fire weapons
			ship.pdc_cooldown -= delta
			ship.torpedo_cooldown -= delta

			if ship.pdc_cooldown <= 0:
				_fire_pdc(ship, true)
				ship.pdc_cooldown = 0.1  # Rapid fire

			if ship.torpedo_cooldown <= 0 and randf() < 0.02:
				_fire_torpedo(ship, true)
				ship.torpedo_cooldown = 2.0

		# Slight movement
		ship.pos += Vector2.from_angle(ship.rotation) * 20 * delta

	# Herald ships behavior - more aggressive, swarming
	for ship in _herald_ships:
		if ship.is_destroyed:
			continue

		if ship.target == null or ship.target.is_destroyed:
			ship.target = _find_nearest_target(ship, _player_ships)

		if ship.target:
			var to_target = ship.target.pos - ship.pos
			var target_angle = to_target.angle()
			ship.rotation = lerp_angle(ship.rotation, target_angle, delta * 3.0)

			# Herald weapons
			ship.pdc_cooldown -= delta
			if ship.pdc_cooldown <= 0:
				_fire_pdc(ship, false)
				ship.pdc_cooldown = 0.15

			# Move toward target aggressively
			if to_target.length() > 100:
				ship.pos += to_target.normalized() * 40 * delta

func _update_projectiles(delta: float) -> void:
	var i = 0
	while i < _projectiles.size():
		var p = _projectiles[i]
		p.pos += p.vel * delta
		p.life -= delta

		# Torpedo trail
		if p.is_torpedo:
			p.trail.append(p.pos)
			if p.trail.size() > 20:
				p.trail.pop_front()

		# Check hits
		var targets = _herald_ships if p.is_player else _player_ships
		var hit = false
		for target in targets:
			if target.is_destroyed:
				continue
			if p.pos.distance_to(target.pos) < target.size:
				hit = true
				_hit_ship(target, p.damage, p.is_torpedo)
				break

		if hit or p.life <= 0 or _is_off_screen(p.pos):
			_projectiles.remove_at(i)
		else:
			i += 1

func _update_explosions(delta: float) -> void:
	var i = 0
	while i < _explosions.size():
		_explosions[i].life -= delta
		if _explosions[i].life <= 0:
			_explosions.remove_at(i)
		else:
			i += 1

func _update_debris(delta: float) -> void:
	var i = 0
	while i < _debris.size():
		var d = _debris[i]
		d.pos += d.vel * delta
		d.rotation += d.spin * delta
		d.life -= delta * 0.3
		if d.life <= 0:
			_debris.remove_at(i)
		else:
			i += 1

func _update_transmissions(delta: float) -> void:
	if not _current_transmission.is_empty():
		_transmission_timer += delta
		if _transmission_timer > _current_transmission.length() / 50.0 + 2.0:
			_current_transmission = ""
			_transmission_timer = 0.0

	elif not _transmissions.is_empty():
		_current_transmission = _transmissions.pop_front()
		_transmission_timer = 0.0

# ============================================================================
# COMBAT FUNCTIONS
# ============================================================================

func _fire_pdc(ship: BattleShip, is_player: bool) -> void:
	var p = Projectile.new()
	var spread = randf_range(-0.1, 0.1)
	p.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size
	p.vel = Vector2.from_angle(ship.rotation + spread) * 800
	p.is_player = is_player
	p.is_torpedo = false
	p.damage = 0.05
	p.life = 1.5
	_projectiles.append(p)

func _fire_torpedo(ship: BattleShip, is_player: bool) -> void:
	var p = Projectile.new()
	p.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size
	p.vel = Vector2.from_angle(ship.rotation) * 200
	p.is_player = is_player
	p.is_torpedo = true
	p.damage = 0.4
	p.life = 5.0
	p.trail = []
	_projectiles.append(p)

	# Add transmission for torpedo launch
	if is_player and ship.ship_data and randf() < 0.3:
		_transmissions.append("[%s] Torpedo away!" % ship.ship_data.name)

func _hit_ship(ship: BattleShip, damage: float, is_torpedo: bool) -> void:
	ship.health -= damage

	# Screen shake for torpedo hits
	if is_torpedo:
		_shake_intensity = maxf(_shake_intensity, 8.0)

		# Small explosion
		var exp = BattleExplosion.new()
		exp.pos = ship.pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		exp.max_radius = 20
		exp.life = 0.5
		_explosions.append(exp)

	# Ship destroyed
	if ship.health <= 0 and not ship.is_destroyed:
		_destroy_battle_ship(ship)

func _destroy_battle_ship(ship: BattleShip) -> void:
	ship.is_destroyed = true

	# Big explosion
	var exp = BattleExplosion.new()
	exp.pos = ship.pos
	exp.max_radius = ship.size * 3
	exp.life = 1.2
	exp.is_ship_death = true
	if ship.ship_data:
		exp.ship_name = ship.ship_data.name
	_explosions.append(exp)

	# Screen shake
	_shake_intensity = 15.0

	# Debris
	for j in range(10):
		var d = Debris.new()
		d.pos = ship.pos
		d.vel = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		d.rotation = randf() * TAU
		d.spin = randf_range(-3, 3)
		d.size = randf_range(3, 8)
		d.life = 1.0
		_debris.append(d)

	# Transmission for player ship death
	if ship.is_player and ship.ship_data:
		_transmissions.append("[LOST] %s has been destroyed. %d crew." % [
			ship.ship_data.name, ship.ship_data.crew_count
		])
		ship_destroyed.emit(ship.ship_data.name)

# ============================================================================
# HELPERS
# ============================================================================

func _find_nearest_target(ship: BattleShip, targets: Array) -> BattleShip:
	var nearest: BattleShip = null
	var nearest_dist = INF
	for t in targets:
		if t.is_destroyed:
			continue
		var dist = ship.pos.distance_to(t.pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = t
	return nearest

func _is_off_screen(pos: Vector2) -> bool:
	return pos.x < -50 or pos.x > size.x + 50 or pos.y < -50 or pos.y > size.y + 50

# ============================================================================
# PUBLIC API
# ============================================================================

func start_battle(zone_name: String, player_ships: Array, herald_count: int, will_hold: bool) -> void:
	_zone_name = zone_name
	_is_active = true
	_battle_time = 0.0
	_outcome_decided = false
	_player_won = will_hold
	_battle_duration = 8.0

	_player_ships.clear()
	_herald_ships.clear()
	_projectiles.clear()
	_explosions.clear()
	_debris.clear()
	_transmissions.clear()
	_current_transmission = ""

	# Create player ships
	var center = size / 2
	for i in range(player_ships.size()):
		var ship = BattleShip.new()
		ship.ship_data = player_ships[i]
		ship.pos = center + Vector2(randf_range(100, 200), randf_range(-100, 100))
		ship.rotation = PI  # Face left toward heralds
		ship.size = 15 + i % 3 * 5
		ship.is_player = true
		_player_ships.append(ship)

	# Create herald ships
	for i in range(herald_count):
		var ship = BattleShip.new()
		ship.pos = Vector2(randf_range(-100, 50), randf_range(50, size.y - 50))
		ship.rotation = 0
		ship.size = randf_range(12, 25)
		ship.is_player = false
		_herald_ships.append(ship)

	# Opening transmission
	if not player_ships.is_empty() and player_ships[0].ship_data:
		_transmissions.append("[%s] Contact! Herald forces incoming!" % player_ships[0].ship_data.name)

	visible = true

func _end_battle() -> void:
	_outcome_decided = true

	# Final transmission
	if _player_won:
		_transmissions.append("[COMMAND] %s secure. Well done." % _zone_name)
	else:
		_transmissions.append("[COMMAND] %s has fallen. All ships withdraw." % _zone_name)

	# Wait then signal complete
	await get_tree().create_timer(3.0).timeout
	_is_active = false
	visible = false
	battle_complete.emit()

func is_active() -> bool:
	return _is_active
