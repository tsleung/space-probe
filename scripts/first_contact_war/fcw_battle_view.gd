extends Control
class_name FCWBattleView

## CINEMATIC BATTLE VIEW - The Expanse Style
## PDCs spraying tracers, railguns punching through, torpedoes with countermeasures
## Herald aliens with completely distinct organic technology

signal battle_complete
signal ship_destroyed(ship_name: String)
signal expand_toggled(is_expanded: bool)

# ============================================================================
# ENTITY CLASSES
# ============================================================================

class BattleShip:
	var pos: Vector2
	var vel: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var ship_data = null
	var health: float = 1.0
	var shields: float = 1.0  # Herald ships have shields
	var is_player: bool = true
	var size: float = 12.0
	var ship_class: int = 0  # 0=frigate, 1=cruiser, 2=dread
	var target: BattleShip = null
	var is_destroyed: bool = false
	# Weapon cooldowns
	var pdc_cooldown: float = 0.0
	var railgun_cooldown: float = 0.0
	var torpedo_cooldown: float = 0.0
	# Herald weapons
	var plasma_cooldown: float = 0.0
	var tendril_cooldown: float = 0.0
	var drone_cooldown: float = 0.0
	# Animation
	var thrust_intensity: float = 0.5
	var damage_flicker: float = 0.0

# Human weapons
class PDCBurst:
	var pos: Vector2
	var vel: Vector2
	var life: float = 0.4
	var is_tracer: bool = false  # Every 5th round is tracer

class RailgunSlug:
	var start: Vector2
	var end: Vector2
	var pos: Vector2
	var vel: Vector2
	var life: float = 0.8
	var trail: Array = []
	var has_hit: bool = false

class Torpedo:
	var pos: Vector2
	var vel: Vector2
	var target: BattleShip = null
	var life: float = 6.0
	var smoke_trail: Array = []
	var is_intercepted: bool = false
	var engine_flicker: float = 0.0

# Herald weapons
class PlasmaOrb:
	var pos: Vector2
	var vel: Vector2
	var target_pos: Vector2
	var life: float = 3.0
	var pulse_phase: float = 0.0
	var size: float = 8.0

class EnergyTendril:
	var start: Vector2
	var end: Vector2
	var control_points: Array = []  # Bezier curve points
	var life: float = 0.4
	var intensity: float = 1.0

class SwarmDrone:
	var pos: Vector2
	var vel: Vector2
	var target: BattleShip = null
	var life: float = 4.0
	var orbit_angle: float = 0.0

# Effects
class Explosion:
	var pos: Vector2
	var life: float = 1.0
	var max_life: float = 1.0
	var max_radius: float = 25.0
	var is_ship_death: bool = false
	var is_herald: bool = false
	var particles: Array = []

class Debris:
	var pos: Vector2
	var vel: Vector2
	var rotation: float
	var spin: float
	var size: float
	var life: float
	var is_herald: bool = false

class ShieldHit:
	var pos: Vector2
	var normal: Vector2
	var life: float = 0.3
	var size: float = 20.0

class MuzzleFlash:
	var pos: Vector2
	var dir: Vector2
	var life: float = 0.08
	var size: float = 6.0
	var weapon_type: int = 0  # 0=pdc, 1=railgun

# ============================================================================
# STATE
# ============================================================================

var _player_ships: Array = []
var _herald_ships: Array = []

# Human weapons
var _pdc_rounds: Array = []
var _railgun_slugs: Array = []
var _torpedoes: Array = []

# Herald weapons
var _plasma_orbs: Array = []
var _energy_tendrils: Array = []
var _swarm_drones: Array = []

# Effects
var _explosions: Array = []
var _debris: Array = []
var _shield_hits: Array = []
var _muzzle_flashes: Array = []

# Battle state
var _battle_time: float = 0.0
var _battle_duration: float = 12.0
var _is_active: bool = false
var _zone_name: String = ""
var _outcome_decided: bool = false
var _player_won: bool = false

# EU4-style attrition tracking
var _starting_player_ships: int = 0
var _starting_herald_ships: int = 0
var _player_losses: int = 0
var _herald_losses: int = 0
var _combat_phase: int = 0  # Current phase/round of combat
var _phase_timer: float = 0.0
var _phase_duration: float = 3.0  # Seconds per combat phase
var _last_phase_announcement: String = ""
var _is_major_battle: bool = false  # Epic battles last longer

# Camera - Cinematic System
var _camera_offset: Vector2 = Vector2.ZERO
var _camera_target: Vector2 = Vector2.ZERO
var _camera_zoom: float = 1.0
var _target_zoom: float = 1.0
var _shake_intensity: float = 0.0
var _follow_ship: BattleShip = null
var _cinematic_timer: float = 0.0

# Camera Modes
enum CameraMode {
	WIDE_SHOT,      # Overview of entire battle
	FOLLOW_SHIP,    # Track a specific ship
	CLOSE_UP,       # Zoomed in on ship hull
	SWEEP_PAN,      # Slow pan across battlefield
	DRONE_ORBIT,    # Rotate around a ship
	ACTION_TRACK    # Fast follow during combat
}
var _camera_mode: int = CameraMode.WIDE_SHOT
var _camera_mode_timer: float = 0.0
var _camera_mode_duration: float = 8.0  # Longer shots for drama
var _sweep_start: Vector2 = Vector2.ZERO
var _sweep_end: Vector2 = Vector2.ZERO
var _orbit_angle: float = 0.0
var _orbit_center: Vector2 = Vector2.ZERO
var _orbit_radius: float = 60.0

# Transmissions
var _transmissions: Array = []
var _current_transmission: String = ""
var _transmission_timer: float = 0.0

# Expand state
var _is_expanded: bool = false
var _expand_button_rect: Rect2 = Rect2(0, 0, 30, 20)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Enable mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP
	# CRITICAL: Clip all drawing to the control bounds
	clip_contents = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = event.position
		# Check if clicked on expand button (top-right corner)
		if _expand_button_rect.has_point(local_pos):
			_toggle_expand()
			accept_event()

func _toggle_expand() -> void:
	_is_expanded = not _is_expanded
	expand_toggled.emit(_is_expanded)

func is_expanded() -> bool:
	return _is_expanded

func set_expanded(expanded: bool) -> void:
	_is_expanded = expanded

func _process(delta: float) -> void:
	if not _is_active:
		return

	_battle_time += delta
	_cinematic_timer += delta
	_phase_timer += delta

	# EU4-style combat phases
	_update_combat_phase()

	# Update camera
	_update_camera(delta)

	# Update all entities
	_update_ships(delta)
	_update_human_weapons(delta)
	_update_herald_weapons(delta)
	_update_effects(delta)
	_update_transmissions(delta)

	# Cinematic camera changes
	_update_cinematics(delta)

	# Apply pressure in final phase to ensure predetermined outcome
	_apply_final_phase_pressure()

	# End battle if time's up and one side is eliminated (or force end)
	if _battle_time >= _battle_duration and not _outcome_decided:
		_force_battle_conclusion()
		_end_battle()

	queue_redraw()

func _update_combat_phase() -> void:
	## Real combat simulation - no dice rolls, weapons actually kill ships
	## Phases are now just for UI/narrative tracking, not for arbitrary casualties
	if _phase_timer >= _phase_duration:
		_phase_timer = 0.0
		_combat_phase += 1

		# Count active ships (actual state from combat simulation)
		var active_player = _player_ships.filter(func(s): return not s.is_destroyed)
		var active_herald = _herald_ships.filter(func(s): return not s.is_destroyed)
		var current_player = active_player.size()
		var current_herald = active_herald.size()

		# Update loss counts from actual combat
		_player_losses = _starting_player_ships - current_player
		_herald_losses = _starting_herald_ships - current_herald

		# Phase announcements based on REAL combat state
		var announcement = ""
		if _combat_phase == 1:
			announcement = "[COMBAT] Weapons hot - all batteries engaging!"
		else:
			# Narrative based on actual battle state
			var player_pct = float(current_player) / maxf(_starting_player_ships, 1)
			var herald_pct = float(current_herald) / maxf(_starting_herald_ships, 1)

			if current_player == 0:
				announcement = "[COMMAND] All ships lost!"
			elif current_herald == 0:
				announcement = "[TACTICAL] All enemy contacts destroyed!"
			elif player_pct < 0.3 and _player_losses > 0:
				announcement = "[MAYDAY] Fleet critically damaged!"
			elif herald_pct < 0.3 and _herald_losses > 0:
				announcement = "[TACTICAL] Enemy fleet breaking apart!"
			elif _player_losses > 0 or _herald_losses > 0:
				var combat_msgs = [
					"[PHASE %d] Heavy exchange of fire",
					"[PHASE %d] Combat continues",
					"[PHASE %d] Weapons free, all batteries",
				]
				announcement = combat_msgs[_combat_phase % combat_msgs.size()] % _combat_phase

		if not announcement.is_empty() and announcement != _last_phase_announcement:
			_transmissions.append(announcement)
			_last_phase_announcement = announcement

		# Check for battle conclusion conditions
		_check_battle_conclusion(current_player, current_herald)

func _draw() -> void:
	# Ensure minimum size for drawing
	if size.x < 50 or size.y < 50:
		# Force minimum size if something went wrong with layout
		size = custom_minimum_size if custom_minimum_size.x > 0 else Vector2(400, 280)

	var rect = Rect2(Vector2.ZERO, size)

	# Deep space
	draw_rect(rect, Color(0.008, 0.008, 0.015))

	# Apply camera transform
	var cam_offset = _camera_offset + Vector2(
		randf_range(-1, 1) * _shake_intensity,
		randf_range(-1, 1) * _shake_intensity
	)

	# Background
	_draw_starfield(rect, cam_offset)
	_draw_nebula(rect)

	# Debris (behind)
	for d in _debris:
		_draw_debris(d, cam_offset)

	# Human weapons
	for pdc in _pdc_rounds:
		_draw_pdc_round(pdc, cam_offset)
	for slug in _railgun_slugs:
		_draw_railgun_slug(slug, cam_offset)
	for torp in _torpedoes:
		_draw_torpedo(torp, cam_offset)

	# Herald weapons
	for orb in _plasma_orbs:
		_draw_plasma_orb(orb, cam_offset)
	for tendril in _energy_tendrils:
		_draw_energy_tendril(tendril, cam_offset)
	for drone in _swarm_drones:
		_draw_swarm_drone(drone, cam_offset)

	# Muzzle flashes
	for flash in _muzzle_flashes:
		_draw_muzzle_flash(flash, cam_offset)

	# Ships
	for ship in _herald_ships:
		if not ship.is_destroyed:
			_draw_herald_ship(ship, cam_offset)
	for ship in _player_ships:
		if not ship.is_destroyed:
			_draw_human_ship(ship, cam_offset)

	# Shield hits
	for hit in _shield_hits:
		_draw_shield_hit(hit, cam_offset)

	# Explosions (on top)
	for exp in _explosions:
		_draw_explosion(exp, cam_offset)

	# UI
	draw_rect(rect, Color(0.15, 0.3, 0.5, 0.9), false, 2.0)
	_draw_battle_ui(rect)
	_draw_expand_button(rect)
	if not _current_transmission.is_empty():
		_draw_transmission(rect)

# ============================================================================
# DRAWING - HUMAN SHIPS (Military, Angular, Blue Engines)
# ============================================================================

func _draw_human_ship(ship: BattleShip, offset: Vector2) -> void:
	var pos = ship.pos + offset
	var dir = Vector2.from_angle(ship.rotation)
	var perp = Vector2(-dir.y, dir.x)
	var s = ship.size

	# Engine flare (behind ship)
	var thrust = ship.thrust_intensity * (0.8 + sin(_battle_time * 12) * 0.2)
	var engine_pos = pos - dir * s
	# Main engine
	draw_circle(engine_pos, s * 0.35 * thrust, Color(0.1, 0.3, 0.8, 0.4))
	draw_circle(engine_pos, s * 0.2 * thrust, Color(0.3, 0.6, 1.0, 0.8))
	draw_circle(engine_pos, s * 0.1 * thrust, Color(0.8, 0.9, 1.0, thrust))
	# Side thrusters
	draw_circle(engine_pos + perp * s * 0.3, s * 0.1 * thrust, Color(0.3, 0.6, 1.0, 0.5))
	draw_circle(engine_pos - perp * s * 0.3, s * 0.1 * thrust, Color(0.3, 0.6, 1.0, 0.5))

	# Hull color based on damage
	var hull_base = Color(0.22, 0.25, 0.3)
	if ship.health < 0.5:
		hull_base = hull_base.lerp(Color(0.35, 0.2, 0.15), 0.6)
	if ship.damage_flicker > 0:
		hull_base = hull_base.lerp(Color(1, 0.5, 0.2), ship.damage_flicker)

	# Main hull - wedge shape
	var hull = PackedVector2Array([
		pos + dir * s * 1.4,  # Nose
		pos + dir * s * 0.5 + perp * s * 0.5,
		pos - dir * s * 0.3 + perp * s * 0.6,
		pos - dir * s * 0.9 + perp * s * 0.5,
		pos - dir * s * 0.9 - perp * s * 0.5,
		pos - dir * s * 0.3 - perp * s * 0.6,
		pos + dir * s * 0.5 - perp * s * 0.5,
	])
	draw_colored_polygon(hull, hull_base)

	# Bridge section
	var bridge = PackedVector2Array([
		pos + dir * s * 0.6,
		pos + dir * s * 0.2 + perp * s * 0.25,
		pos - dir * s * 0.3 + perp * s * 0.2,
		pos - dir * s * 0.3 - perp * s * 0.2,
		pos + dir * s * 0.2 - perp * s * 0.25,
	])
	draw_colored_polygon(bridge, hull_base.lightened(0.15))

	# Bridge windows
	draw_circle(pos + dir * s * 0.35, 2, Color(0.5, 0.8, 1.0, 0.9))

	# PDC turrets (4 of them)
	for i in range(4):
		var turret_offset = perp * s * 0.4 * (1 if i % 2 == 0 else -1)
		turret_offset += dir * s * (0.3 if i < 2 else -0.4)
		var turret_pos = pos + turret_offset
		draw_circle(turret_pos, 2.5, Color(0.4, 0.4, 0.45))
		# Turret barrel pointing at target
		if ship.target:
			var to_target = (ship.target.pos - turret_pos).normalized()
			draw_line(turret_pos, turret_pos + to_target * 4, Color(0.5, 0.5, 0.55), 1.5)

	# Railgun (center spine)
	draw_line(pos - dir * s * 0.5, pos + dir * s * 0.8, Color(0.35, 0.35, 0.4), 3)
	draw_circle(pos + dir * s * 0.9, 2, Color(0.5, 0.5, 0.55))

	# Damage effects
	if ship.health < 0.7:
		for i in range(int((1.0 - ship.health) * 5)):
			if randf() < 0.5:
				var spark_pos = pos + Vector2(randf_range(-s, s), randf_range(-s, s)) * 0.6
				draw_circle(spark_pos, randf_range(1, 3), Color(1, 0.5, 0.2, randf()))
		# Smoke
		if randf() < 0.3:
			var smoke_pos = pos + Vector2(randf_range(-s, s), randf_range(-s, s)) * 0.4
			draw_circle(smoke_pos, randf_range(3, 6), Color(0.3, 0.3, 0.3, 0.3))

	# Health bar
	if ship.health < 1.0:
		var bar_w = s * 2
		var bar_pos = pos + Vector2(-bar_w/2, s * 1.2)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 3)), Color(0.15, 0.15, 0.15, 0.8))
		var health_color = Color(0.2, 0.8, 0.3) if ship.health > 0.3 else Color(1, 0.3, 0.2)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ship.health, 3)), health_color)

	# Ship name
	if ship.ship_data and ship.ship_data.get("name"):
		var font = ThemeDB.fallback_font
		var name_text = ship.ship_data.name.substr(0, 10)
		draw_string(font, pos + Vector2(-20, -s * 1.3), name_text, HORIZONTAL_ALIGNMENT_CENTER, 40, 7, Color(0.6, 0.8, 1.0, 0.7))

# ============================================================================
# DRAWING - HERALD SHIPS (Organic, Pulsing, Alien)
# ============================================================================

func _draw_herald_ship(ship: BattleShip, offset: Vector2) -> void:
	var pos = ship.pos + offset
	var s = ship.size
	var pulse = sin(_battle_time * 3 + ship.pos.length() * 0.02) * 0.2 + 0.8

	# Void shield (outer shimmer)
	if ship.shields > 0.1:
		var shield_alpha = ship.shields * 0.3 * pulse
		draw_arc(pos, s * 1.8, 0, TAU, 16, Color(0.8, 0.2, 0.5, shield_alpha), 2)
		# Shield segments
		for i in range(6):
			var angle = _battle_time * 0.5 + i * TAU / 6
			var seg_start = pos + Vector2.from_angle(angle) * s * 1.5
			var seg_end = pos + Vector2.from_angle(angle + 0.3) * s * 1.5
			draw_line(seg_start, seg_end, Color(0.9, 0.3, 0.6, shield_alpha * 0.5), 1)

	# Outer shell - organic irregular shape
	var shell_points = PackedVector2Array()
	for i in range(10):
		var angle = i * TAU / 10
		var wobble = sin(_battle_time * 2 + i * 1.5) * 0.15
		var dist = s * (1.0 + wobble)
		shell_points.append(pos + Vector2.from_angle(angle) * dist)
	draw_colored_polygon(shell_points, Color(0.25, 0.06, 0.08, 0.95))

	# Inner membrane layers
	draw_circle(pos, s * 0.75 * pulse, Color(0.4, 0.08, 0.06))
	draw_circle(pos, s * 0.5 * pulse, Color(0.6, 0.12, 0.08))

	# Glowing core
	var core_pulse = sin(_battle_time * 5) * 0.3 + 0.7
	draw_circle(pos, s * 0.25 * core_pulse, Color(1.0, 0.4, 0.2, core_pulse))
	draw_circle(pos, s * 0.12, Color(1.0, 0.8, 0.5, core_pulse))

	# Energy veins (pulsing lines from core)
	for i in range(6):
		var angle = i * TAU / 6 + sin(_battle_time + i) * 0.2
		var vein_end = pos + Vector2.from_angle(angle) * s * 0.9
		var mid = pos + Vector2.from_angle(angle + sin(_battle_time * 2 + i) * 0.3) * s * 0.5
		var vein_color = Color(0.9, 0.3, 0.1, 0.6 * pulse)
		draw_line(pos, mid, vein_color, 2)
		draw_line(mid, vein_end, Color(vein_color.r, vein_color.g, vein_color.b, 0.3), 1.5)

	# Weapon nodes (where plasma fires from)
	for i in range(3):
		var node_angle = ship.rotation + i * TAU / 3
		var node_pos = pos + Vector2.from_angle(node_angle) * s * 0.8
		var node_glow = 0.5 + (0.5 if ship.plasma_cooldown < 0.2 else 0.0)
		draw_circle(node_pos, 4, Color(1.0, 0.5, 0.2, node_glow))

	# Tendril appendages
	for i in range(4):
		var base_angle = i * TAU / 4 + _battle_time * 0.3
		var tendril_base = pos + Vector2.from_angle(base_angle) * s
		var wave = sin(_battle_time * 3 + i * 2) * 0.4
		var tendril_mid = tendril_base + Vector2.from_angle(base_angle + wave) * s * 0.5
		var tendril_end = tendril_mid + Vector2.from_angle(base_angle + wave * 2) * s * 0.4
		draw_line(tendril_base, tendril_mid, Color(0.5, 0.1, 0.08, 0.7), 3)
		draw_line(tendril_mid, tendril_end, Color(0.6, 0.15, 0.1, 0.5), 2)
		draw_circle(tendril_end, 2, Color(0.8, 0.2, 0.1, 0.6))

# ============================================================================
# DRAWING - HUMAN WEAPONS
# ============================================================================

func _draw_pdc_round(pdc: PDCBurst, offset: Vector2) -> void:
	var pos = pdc.pos + offset
	if pdc.is_tracer:
		# Bright tracer round
		var trail_end = pos - pdc.vel.normalized() * 8
		draw_line(trail_end, pos, Color(1, 1, 0.6, 0.8), 1.5)
		draw_circle(pos, 2, Color(1, 1, 0.8))
	else:
		# Regular round (dimmer)
		draw_circle(pos, 1, Color(1, 1, 0.7, 0.6))

func _draw_railgun_slug(slug: RailgunSlug, offset: Vector2) -> void:
	var pos = slug.pos + offset
	var dir = slug.vel.normalized()

	# Long bright trail
	for i in range(slug.trail.size()):
		var t_pos = slug.trail[i] + offset
		var alpha = float(i) / slug.trail.size()
		draw_circle(t_pos, 2 + alpha * 2, Color(0.5, 0.8, 1.0, alpha * 0.6))

	# Main slug - elongated bright line
	var slug_length = 15
	draw_line(pos - dir * slug_length, pos, Color(0.7, 0.9, 1.0), 3)
	draw_line(pos - dir * slug_length * 0.5, pos, Color(1, 1, 1), 2)
	# Bright tip
	draw_circle(pos, 3, Color(1, 1, 1))
	draw_circle(pos, 5, Color(0.5, 0.8, 1.0, 0.5))

func _draw_torpedo(torp: Torpedo, offset: Vector2) -> void:
	var pos = torp.pos + offset
	var dir = torp.vel.normalized()

	# Smoke trail
	for i in range(torp.smoke_trail.size()):
		var t_pos = torp.smoke_trail[i] + offset
		var t = float(i) / max(torp.smoke_trail.size(), 1)
		var smoke_size = 2 + t * 6
		var smoke_alpha = t * 0.4
		draw_circle(t_pos, smoke_size, Color(0.5, 0.5, 0.5, smoke_alpha))
		# Hot exhaust at recent positions
		if t > 0.7:
			draw_circle(t_pos, smoke_size * 0.5, Color(1, 0.6, 0.2, (t - 0.7) * 2))

	# Torpedo body
	var body_length = 8
	var body_width = 3
	# Main body
	var body = PackedVector2Array([
		pos + dir * body_length,
		pos + dir * -body_length * 0.3 + Vector2(-dir.y, dir.x) * body_width,
		pos + dir * -body_length,
		pos + dir * -body_length * 0.3 - Vector2(-dir.y, dir.x) * body_width,
	])
	draw_colored_polygon(body, Color(0.4, 0.4, 0.45))

	# Warhead (red tip)
	draw_circle(pos + dir * body_length * 0.8, 2.5, Color(0.8, 0.2, 0.2))

	# Engine glow
	var flicker = torp.engine_flicker
	draw_circle(pos - dir * body_length, 3 + flicker, Color(1, 0.6, 0.2, 0.8))
	draw_circle(pos - dir * body_length, 2, Color(1, 0.9, 0.6))

func _draw_muzzle_flash(flash: MuzzleFlash, offset: Vector2) -> void:
	var pos = flash.pos + offset
	var alpha = flash.life / 0.08

	if flash.weapon_type == 0:  # PDC
		draw_circle(pos, flash.size * alpha, Color(1, 1, 0.7, alpha))
	else:  # Railgun
		# Big bright flash
		draw_circle(pos, flash.size * 2 * alpha, Color(0.5, 0.8, 1.0, alpha * 0.5))
		draw_circle(pos, flash.size * alpha, Color(1, 1, 1, alpha))
		# Muzzle line
		draw_line(pos, pos + flash.dir * 20, Color(0.7, 0.9, 1.0, alpha), 3)

# ============================================================================
# DRAWING - HERALD WEAPONS
# ============================================================================

func _draw_plasma_orb(orb: PlasmaOrb, offset: Vector2) -> void:
	var pos = orb.pos + offset
	var pulse = sin(orb.pulse_phase) * 0.3 + 0.7
	var s = orb.size * pulse

	# Outer unstable field
	for i in range(8):
		var angle = orb.pulse_phase * 2 + i * TAU / 8
		var wobble = sin(orb.pulse_phase * 3 + i) * s * 0.3
		var point = pos + Vector2.from_angle(angle) * (s + wobble)
		draw_circle(point, 2, Color(1, 0.4, 0.1, 0.4))

	# Core layers
	draw_circle(pos, s * 1.2, Color(0.8, 0.2, 0.05, 0.4))
	draw_circle(pos, s * 0.8, Color(1.0, 0.4, 0.1, 0.7))
	draw_circle(pos, s * 0.4, Color(1.0, 0.7, 0.3, 0.9))
	draw_circle(pos, s * 0.2, Color(1, 1, 0.8))

func _draw_energy_tendril(tendril: EnergyTendril, offset: Vector2) -> void:
	var alpha = tendril.intensity * (tendril.life / 0.4)

	# Draw curved beam using control points
	if tendril.control_points.size() >= 4:
		var prev_point = tendril.start + offset
		for i in range(1, 10):
			var t = float(i) / 9
			var point = _bezier_point(
				tendril.start + offset,
				tendril.control_points[0] + offset,
				tendril.control_points[1] + offset,
				tendril.end + offset,
				t
			)
			# Outer glow
			draw_line(prev_point, point, Color(0.8, 0.2, 0.5, alpha * 0.3), 8)
			# Core beam
			draw_line(prev_point, point, Color(1.0, 0.4, 0.6, alpha), 3)
			# Bright center
			draw_line(prev_point, point, Color(1, 0.8, 0.9, alpha), 1.5)
			prev_point = point

func _draw_swarm_drone(drone: SwarmDrone, offset: Vector2) -> void:
	var pos = drone.pos + offset
	var pulse = sin(_battle_time * 8 + drone.orbit_angle) * 0.3 + 0.7

	# Tiny organic drone
	var points = PackedVector2Array()
	for i in range(5):
		var angle = drone.orbit_angle + i * TAU / 5
		var dist = 3 * (1 + sin(_battle_time * 4 + i) * 0.2)
		points.append(pos + Vector2.from_angle(angle) * dist)
	draw_colored_polygon(points, Color(0.6, 0.15, 0.1, 0.9))

	# Glowing core
	draw_circle(pos, 2 * pulse, Color(1, 0.4, 0.2, pulse))

func _draw_shield_hit(hit: ShieldHit, offset: Vector2) -> void:
	var pos = hit.pos + offset
	var alpha = hit.life / 0.3
	var s = hit.size * (1 + (1 - alpha) * 0.5)

	# Hexagonal shield impact
	var hex_points = PackedVector2Array()
	for i in range(6):
		var angle = i * TAU / 6
		hex_points.append(pos + Vector2.from_angle(angle) * s)
	draw_polyline(hex_points + PackedVector2Array([hex_points[0]]), Color(0.9, 0.3, 0.6, alpha), 2)
	draw_circle(pos, s * 0.3, Color(1, 0.5, 0.8, alpha * 0.5))

# ============================================================================
# DRAWING - EFFECTS
# ============================================================================

func _draw_explosion(exp: Explosion, offset: Vector2) -> void:
	var pos = exp.pos + offset
	var progress = 1.0 - (exp.life / exp.max_life)
	var r = exp.max_radius * ease(progress, 0.5)

	if exp.is_herald:
		# Alien explosion - purple/red, imploding then exploding
		if progress < 0.3:
			# Implosion
			var imp_r = exp.max_radius * (1 - progress * 3)
			draw_circle(pos, imp_r, Color(0.5, 0.1, 0.3, 0.5))
		# Explosion
		draw_circle(pos, r * 0.8, Color(0.8, 0.2, 0.4, exp.life))
		draw_circle(pos, r * 0.5, Color(1, 0.4, 0.5, exp.life))
		draw_circle(pos, r * 0.2, Color(1, 0.8, 0.9, exp.life))
		# Void tendrils
		for i in range(6):
			var angle = i * TAU / 6 + _battle_time
			var tendril_end = pos + Vector2.from_angle(angle) * r * 1.2
			draw_line(pos, tendril_end, Color(0.6, 0.1, 0.3, exp.life * 0.5), 2)
	else:
		# Human explosion - orange/yellow, classic
		draw_circle(pos, r * 0.3 * exp.life, Color(1, 1, 1, exp.life))
		draw_circle(pos, r * 0.7, Color(1, 0.7, 0.2, exp.life * 0.8))
		draw_circle(pos, r * 0.5, Color(1, 0.5, 0.1, exp.life * 0.9))
		# Shockwave ring
		if progress > 0.2:
			draw_arc(pos, r, 0, TAU, 20, Color(1, 0.4, 0.1, (1 - progress) * 0.8), 2)

	# Particles
	for p in exp.particles:
		var p_alpha = p.life if p.has("life") else exp.life
		var p_color = p.color if p.has("color") else Color(1, 0.6, 0.2)
		draw_circle(p.pos + offset, p.size if p.has("size") else 2, Color(p_color.r, p_color.g, p_color.b, p_alpha))

func _draw_debris(d: Debris, offset: Vector2) -> void:
	var pos = d.pos + offset
	var alpha = minf(d.life, 1.0)

	if d.is_herald:
		# Organic debris - blobby
		draw_circle(pos, d.size, Color(0.4, 0.1, 0.1, alpha))
	else:
		# Metal debris - angular
		var points = PackedVector2Array()
		for i in range(4):
			var angle = d.rotation + i * TAU / 4
			points.append(pos + Vector2.from_angle(angle) * d.size)
		draw_colored_polygon(points, Color(0.35, 0.35, 0.38, alpha))

func _draw_starfield(rect: Rect2, offset: Vector2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77777
	for i in range(50):
		var star_pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		star_pos += offset * 0.05
		star_pos.x = fmod(star_pos.x + rect.size.x, rect.size.x)
		star_pos.y = fmod(star_pos.y + rect.size.y, rect.size.y)
		var brightness = rng.randf_range(0.3, 0.9)
		var twinkle = sin(_battle_time * rng.randf_range(1, 4) + i) * 0.2 + 0.8
		draw_circle(star_pos, rng.randf_range(0.5, 1.5), Color(brightness * twinkle, brightness * twinkle, brightness * twinkle * 1.1))

func _draw_nebula(rect: Rect2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 33333
	for i in range(2):
		var center = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var nebula_color = Color(0.1, 0.05, 0.15, 0.08) if i == 0 else Color(0.05, 0.08, 0.12, 0.06)
		draw_circle(center, 100, nebula_color)

# ============================================================================
# DRAWING - UI
# ============================================================================

func _draw_battle_ui(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font

	# === EU4-STYLE COMBAT DISPLAY ===
	# Shows forces on each side with visual attrition bars

	var player_alive = _player_ships.filter(func(s): return not s.is_destroyed).size()
	var herald_alive = _herald_ships.filter(func(s): return not s.is_destroyed).size()

	# Calculate loss percentages for visual effect
	var player_start = maxi(_starting_player_ships, 1)
	var herald_start = maxi(_starting_herald_ships, 1)
	var player_pct = float(player_alive) / float(player_start)
	var herald_pct = float(herald_alive) / float(herald_start)

	# --- TOP BANNER: Zone name and phase ---
	var banner_h = 28
	draw_rect(Rect2(0, 0, rect.size.x, banner_h), Color(0.0, 0.02, 0.06, 0.95))
	draw_line(Vector2(0, banner_h), Vector2(rect.size.x, banner_h), Color(0.2, 0.35, 0.5, 0.8), 1)

	# Zone name (center)
	draw_string(font, Vector2(rect.size.x / 2 - 60, 12), "⚔ BATTLE FOR %s" % _zone_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, 120, 9, Color(1, 0.9, 0.7))

	# Phase indicator (right side)
	var phase_text = "PHASE %d" % _combat_phase if _combat_phase > 0 else "ENGAGING"
	draw_string(font, Vector2(rect.size.x - 65, 12), phase_text, HORIZONTAL_ALIGNMENT_LEFT, 60, 8, Color(0.6, 0.7, 0.8))

	# Phase timer bar (thin line under phase)
	var phase_progress = minf(_phase_timer / _phase_duration, 1.0)
	draw_rect(Rect2(rect.size.x - 65, 18, 55 * phase_progress, 2), Color(0.5, 0.6, 0.7, 0.6))

	# --- FORCE COMPARISON PANEL (EU4-style) ---
	# Ships are positioned: Herald on LEFT, UNN on RIGHT
	# So panels should match: Herald label on LEFT, UNN label on RIGHT
	var panel_y = banner_h + 4
	var panel_h = 50
	var panel_margin = 8
	var half_w = (rect.size.x - panel_margin * 3) / 2

	# Herald Forces (left panel - purple/red to match ship positions)
	_draw_force_panel(
		Rect2(panel_margin, panel_y, half_w, panel_h),
		"HERALD",
		_starting_herald_ships,
		herald_alive,
		_herald_losses,
		Color(0.5, 0.1, 0.3),  # Purple theme (matches Herald color)
		Color(0.9, 0.3, 0.5),
		true
	)

	# UNN Forces (right panel - blue to match ship positions)
	_draw_force_panel(
		Rect2(panel_margin * 2 + half_w, panel_y, half_w, panel_h),
		"UNN FLEET",
		_starting_player_ships,
		player_alive,
		_player_losses,
		Color(0.2, 0.4, 0.7),  # Blue theme
		Color(0.4, 0.7, 1.0),
		false
	)

	# --- BATTLE PROGRESS BAR (bottom of force panel) ---
	var bar_y = panel_y + panel_h + 4
	var bar_w = rect.size.x - panel_margin * 2
	var progress = minf(_battle_time / _battle_duration, 1.0)

	draw_rect(Rect2(panel_margin, bar_y, bar_w, 4), Color(0.1, 0.1, 0.15))

	# Progress bar color changes based on who's winning
	var progress_color = Color(0.5, 0.5, 0.4)  # Neutral
	if player_pct > herald_pct + 0.2:
		progress_color = Color(0.3, 0.6, 0.8)  # Blue - winning
	elif herald_pct > player_pct + 0.2:
		progress_color = Color(0.8, 0.3, 0.2)  # Red - losing

	draw_rect(Rect2(panel_margin, bar_y, bar_w * progress, 4), progress_color)

	# Major battle indicator
	if _is_major_battle:
		var pulse = sin(_battle_time * 3) * 0.3 + 0.7
		draw_string(font, Vector2(panel_margin, bar_y + 14), "★ MAJOR ENGAGEMENT",
			HORIZONTAL_ALIGNMENT_LEFT, 120, 7, Color(1, 0.8, 0.3, pulse))


func _draw_force_panel(rect: Rect2, title: String, starting: int, current: int, losses: int,
		bg_color: Color, text_color: Color, is_player: bool) -> void:
	var font = ThemeDB.fallback_font

	# Panel background
	draw_rect(rect, bg_color.darkened(0.7))
	draw_rect(rect, bg_color.lightened(0.2), false, 1)

	# Title
	draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 10), title,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 7, text_color.darkened(0.2))

	# Ship count - BIG numbers (EU4 style)
	var count_text = "%d" % current
	var count_x = rect.position.x + 4 if is_player else rect.position.x + rect.size.x - 30
	draw_string(font, Vector2(count_x, rect.position.y + 28), count_text,
		HORIZONTAL_ALIGNMENT_LEFT, 30, 16, text_color)

	# Starting count (smaller, grayed out)
	var start_text = "/ %d" % starting
	var start_x = count_x + 24 if is_player else count_x + 24
	draw_string(font, Vector2(start_x, rect.position.y + 28), start_text,
		HORIZONTAL_ALIGNMENT_LEFT, 30, 9, text_color.darkened(0.4))

	# Losses indicator (if any)
	if losses > 0:
		var loss_text = "-%d" % losses
		var loss_x = rect.position.x + rect.size.x - 25 if is_player else rect.position.x + 4
		var loss_color = Color(1, 0.3, 0.3) if is_player else Color(0.3, 1, 0.3)
		draw_string(font, Vector2(loss_x, rect.position.y + 28), loss_text,
			HORIZONTAL_ALIGNMENT_LEFT, 25, 10, loss_color)

	# Visual ship bar (shows attrition as bar shrinks)
	var bar_y = rect.position.y + 36
	var bar_w = rect.size.x - 8
	var bar_h = 8
	var fill_pct = float(current) / float(maxi(starting, 1))

	# Background (full bar = starting ships)
	draw_rect(Rect2(rect.position.x + 4, bar_y, bar_w, bar_h), bg_color.darkened(0.5))

	# Filled portion (current ships) - shrinks as ships die
	var fill_w = bar_w * fill_pct
	if is_player:
		draw_rect(Rect2(rect.position.x + 4, bar_y, fill_w, bar_h), text_color)
	else:
		# Herald bar fills from right
		draw_rect(Rect2(rect.position.x + 4 + bar_w - fill_w, bar_y, fill_w, bar_h), text_color)

	# Ship icons in bar (visual representation)
	var icon_spacing = bar_w / float(maxi(starting, 1))
	for i in range(starting):
		var icon_x = rect.position.x + 4 + i * icon_spacing + icon_spacing * 0.5
		var is_alive = i < current
		var icon_color = text_color if is_alive else Color(0.2, 0.2, 0.2, 0.5)
		# Small diamond for each ship
		if is_alive:
			draw_circle(Vector2(icon_x, bar_y + bar_h / 2), 2, icon_color)
		else:
			# X mark for destroyed
			draw_line(Vector2(icon_x - 2, bar_y + 1), Vector2(icon_x + 2, bar_y + bar_h - 1), Color(0.5, 0.2, 0.2, 0.6), 1)
			draw_line(Vector2(icon_x + 2, bar_y + 1), Vector2(icon_x - 2, bar_y + bar_h - 1), Color(0.5, 0.2, 0.2, 0.6), 1)

func _draw_transmission(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var box_h = 28
	var box_y = rect.size.y - box_h - 4
	draw_rect(Rect2(4, box_y, rect.size.x - 8, box_h), Color(0.0, 0.05, 0.12, 0.92))
	draw_rect(Rect2(4, box_y, rect.size.x - 8, box_h), Color(0.2, 0.4, 0.6, 0.7), false, 1)

	var chars = int(_transmission_timer * 60)
	var text = _current_transmission.substr(0, mini(chars, 55))
	draw_string(font, Vector2(10, box_y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 9, Color(0.6, 0.85, 1.0))

func _draw_expand_button(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var btn_w = 24
	var btn_h = 16
	var btn_x = rect.size.x - btn_w - 4
	# Position below force panels (banner=28, panel=50, gap=8)
	var btn_y = 28 + 50 + 8 + 4

	# Update button rect for hit detection
	_expand_button_rect = Rect2(btn_x, btn_y, btn_w, btn_h)

	# Button background - subtle
	var bg_color = Color(0.15, 0.25, 0.35, 0.85)
	draw_rect(_expand_button_rect, bg_color)
	draw_rect(_expand_button_rect, Color(0.3, 0.4, 0.5, 0.7), false, 1)

	# Icon: expand (arrows pointing out) or collapse (arrows pointing in)
	var icon = "⤢" if not _is_expanded else "⤡"
	draw_string(font, Vector2(btn_x + 5, btn_y + 12), icon, HORIZONTAL_ALIGNMENT_CENTER, btn_w, 10, Color(0.7, 0.8, 0.9))

# ============================================================================
# UPDATE - SHIPS
# ============================================================================

func _update_ships(delta: float) -> void:
	for ship in _player_ships:
		if ship.is_destroyed:
			continue
		_update_human_ship(ship, delta)

	for ship in _herald_ships:
		if ship.is_destroyed:
			continue
		_update_herald_ship(ship, delta)

func _update_human_ship(ship: BattleShip, delta: float) -> void:
	# Find target
	if ship.target == null or ship.target.is_destroyed:
		ship.target = _find_nearest(ship, _herald_ships)

	if ship.target:
		var to_target = ship.target.pos - ship.pos
		var dist = to_target.length()
		var target_angle = to_target.angle()
		ship.rotation = lerp_angle(ship.rotation, target_angle, delta * 2.5)

		# PDC - rapid fire at close range
		ship.pdc_cooldown -= delta
		if ship.pdc_cooldown <= 0 and dist < 150:
			_fire_pdc_burst(ship)
			ship.pdc_cooldown = 0.05  # 20 rounds/sec

		# Railgun - slower, longer range
		ship.railgun_cooldown -= delta
		if ship.railgun_cooldown <= 0 and dist < 250:
			_fire_railgun(ship)
			ship.railgun_cooldown = 1.5

		# Torpedo - occasional, homing
		ship.torpedo_cooldown -= delta
		if ship.torpedo_cooldown <= 0 and dist < 200:
			_fire_torpedo(ship)
			ship.torpedo_cooldown = 4.0 + randf() * 2.0

	# Movement - slow, deliberate
	ship.pos += Vector2.from_angle(ship.rotation) * 15 * delta
	ship.thrust_intensity = 0.5 + randf() * 0.3

	# Keep ship within battle view bounds (with padding for UI elements)
	var padding = 50.0  # Account for UI header/footer
	ship.pos.x = clampf(ship.pos.x, padding, size.x - padding)
	ship.pos.y = clampf(ship.pos.y, padding, size.y - padding)

	# Damage flicker decay
	ship.damage_flicker = maxf(ship.damage_flicker - delta * 5, 0)

func _update_herald_ship(ship: BattleShip, delta: float) -> void:
	if ship.target == null or ship.target.is_destroyed:
		ship.target = _find_nearest(ship, _player_ships)

	if ship.target:
		var to_target = ship.target.pos - ship.pos
		var dist = to_target.length()
		var target_angle = to_target.angle()
		ship.rotation = lerp_angle(ship.rotation, target_angle, delta * 3.5)

		# Plasma orbs - medium rate
		ship.plasma_cooldown -= delta
		if ship.plasma_cooldown <= 0 and dist < 180:
			_fire_plasma_orb(ship)
			ship.plasma_cooldown = 0.6

		# Energy tendril - close range beam
		ship.tendril_cooldown -= delta
		if ship.tendril_cooldown <= 0 and dist < 100:
			_fire_energy_tendril(ship)
			ship.tendril_cooldown = 1.2

		# Swarm drones - spawns suicide drones
		ship.drone_cooldown -= delta
		if ship.drone_cooldown <= 0 and dist < 200:
			_spawn_swarm_drones(ship, 3)
			ship.drone_cooldown = 5.0

		# Aggressive movement
		if dist > 80:
			ship.pos += to_target.normalized() * 35 * delta
		else:
			var orbit = Vector2(-to_target.y, to_target.x).normalized()
			ship.pos += orbit * 20 * delta

	# Keep ship within battle view bounds (with padding for UI elements)
	var padding = 50.0  # Account for UI header/footer
	ship.pos.x = clampf(ship.pos.x, padding, size.x - padding)
	ship.pos.y = clampf(ship.pos.y, padding, size.y - padding)

	ship.damage_flicker = maxf(ship.damage_flicker - delta * 5, 0)

# ============================================================================
# UPDATE - WEAPONS
# ============================================================================

func _update_human_weapons(delta: float) -> void:
	# PDC rounds
	var i = 0
	while i < _pdc_rounds.size():
		var pdc = _pdc_rounds[i]
		pdc.pos += pdc.vel * delta
		pdc.life -= delta

		# Check hit on herald ships
		for target in _herald_ships:
			if target.is_destroyed:
				continue
			if pdc.pos.distance_to(target.pos) < target.size + 3:
				_hit_herald(target, 0.02, pdc.pos)
				pdc.life = 0
				break

		if pdc.life <= 0 or _off_screen(pdc.pos):
			_pdc_rounds.remove_at(i)
		else:
			i += 1

	# Railgun slugs
	i = 0
	while i < _railgun_slugs.size():
		var slug = _railgun_slugs[i]
		slug.pos += slug.vel * delta
		slug.life -= delta
		slug.trail.append(slug.pos)
		if slug.trail.size() > 20:
			slug.trail.pop_front()

		if not slug.has_hit:
			for target in _herald_ships:
				if target.is_destroyed:
					continue
				if slug.pos.distance_to(target.pos) < target.size + 5:
					_hit_herald(target, 0.25, slug.pos)
					slug.has_hit = true
					_shake_intensity = maxf(_shake_intensity, 8)
					# Railgun punches through!
					_transmissions.append("[RAILGUN] Solid hit!")
					break

		if slug.life <= 0 or _off_screen(slug.pos):
			_railgun_slugs.remove_at(i)
		else:
			i += 1

	# Torpedoes
	i = 0
	while i < _torpedoes.size():
		var torp = _torpedoes[i]

		# Homing
		if torp.target and not torp.target.is_destroyed:
			var to_target = torp.target.pos - torp.pos
			var desired = to_target.normalized() * torp.vel.length()
			torp.vel = torp.vel.lerp(desired, delta * 1.5)

		torp.pos += torp.vel * delta
		torp.life -= delta
		torp.engine_flicker = sin(_battle_time * 15) * 0.5

		# Smoke trail
		torp.smoke_trail.append(torp.pos)
		if torp.smoke_trail.size() > 25:
			torp.smoke_trail.pop_front()

		# PDC interception by herald plasma
		for orb in _plasma_orbs:
			if torp.pos.distance_to(orb.pos) < 15:
				torp.is_intercepted = true
				_create_explosion(torp.pos, 15, false)
				torp.life = 0
				break

		# Hit check
		if not torp.is_intercepted:
			for target in _herald_ships:
				if target.is_destroyed:
					continue
				if torp.pos.distance_to(target.pos) < target.size + 8:
					_hit_herald(target, 0.4, torp.pos)
					_create_explosion(torp.pos, 35, false)
					_shake_intensity = maxf(_shake_intensity, 15)
					_transmissions.append("[TORPEDO] Impact confirmed!")
					torp.life = 0
					break

		if torp.life <= 0 or _off_screen(torp.pos):
			_torpedoes.remove_at(i)
		else:
			i += 1

func _update_herald_weapons(delta: float) -> void:
	# Plasma orbs
	var i = 0
	while i < _plasma_orbs.size():
		var orb = _plasma_orbs[i]

		# Drift toward target
		var to_target = orb.target_pos - orb.pos
		orb.vel = orb.vel.lerp(to_target.normalized() * 100, delta * 0.8)
		orb.pos += orb.vel * delta
		orb.life -= delta
		orb.pulse_phase += delta * 8

		# Hit check
		for target in _player_ships:
			if target.is_destroyed:
				continue
			if orb.pos.distance_to(target.pos) < target.size + orb.size:
				_hit_human(target, 0.08, orb.pos)
				orb.life = 0
				break

		if orb.life <= 0 or _off_screen(orb.pos):
			_plasma_orbs.remove_at(i)
		else:
			i += 1

	# Energy tendrils
	i = 0
	while i < _energy_tendrils.size():
		var tendril = _energy_tendrils[i]
		tendril.life -= delta
		tendril.intensity = tendril.life / 0.4

		# Continuous damage while active
		if tendril.life > 0.2:
			for target in _player_ships:
				if target.is_destroyed:
					continue
				# Check if beam passes near target
				var dist_to_beam = _point_to_line_dist(target.pos, tendril.start, tendril.end)
				if dist_to_beam < target.size + 10:
					_hit_human(target, 0.03 * delta * 10, target.pos)

		if tendril.life <= 0:
			_energy_tendrils.remove_at(i)
		else:
			i += 1

	# Swarm drones
	i = 0
	while i < _swarm_drones.size():
		var drone = _swarm_drones[i]
		drone.life -= delta
		drone.orbit_angle += delta * 5

		if drone.target == null or drone.target.is_destroyed:
			drone.target = _find_nearest_pos(drone.pos, _player_ships)

		if drone.target:
			var to_target = drone.target.pos - drone.pos
			drone.vel = drone.vel.lerp(to_target.normalized() * 120, delta * 3)
			drone.pos += drone.vel * delta

			# Suicide attack
			if to_target.length() < drone.target.size + 5:
				_hit_human(drone.target, 0.06, drone.pos)
				_create_explosion(drone.pos, 12, true)
				drone.life = 0

		if drone.life <= 0 or _off_screen(drone.pos):
			_swarm_drones.remove_at(i)
		else:
			i += 1

# ============================================================================
# UPDATE - EFFECTS
# ============================================================================

func _update_effects(delta: float) -> void:
	# Explosions
	var i = 0
	while i < _explosions.size():
		var exp = _explosions[i]
		exp.life -= delta
		for p in exp.particles:
			if p.has("pos") and p.has("vel"):
				p.pos += p.vel * delta
				if p.has("life"):
					p.life -= delta
		if exp.life <= 0:
			_explosions.remove_at(i)
		else:
			i += 1

	# Debris
	i = 0
	while i < _debris.size():
		var d = _debris[i]
		d.pos += d.vel * delta
		d.vel *= 0.98
		d.rotation += d.spin * delta
		d.life -= delta * 0.4
		if d.life <= 0:
			_debris.remove_at(i)
		else:
			i += 1

	# Shield hits
	i = 0
	while i < _shield_hits.size():
		_shield_hits[i].life -= delta
		if _shield_hits[i].life <= 0:
			_shield_hits.remove_at(i)
		else:
			i += 1

	# Muzzle flashes
	i = 0
	while i < _muzzle_flashes.size():
		_muzzle_flashes[i].life -= delta
		if _muzzle_flashes[i].life <= 0:
			_muzzle_flashes.remove_at(i)
		else:
			i += 1

	# Screen shake decay
	_shake_intensity = maxf(_shake_intensity - delta * 20, 0)

func _update_camera(delta: float) -> void:
	# Update camera based on current mode
	match _camera_mode:
		CameraMode.WIDE_SHOT:
			_update_camera_wide(delta)
		CameraMode.FOLLOW_SHIP:
			_update_camera_follow(delta)
		CameraMode.CLOSE_UP:
			_update_camera_closeup(delta)
		CameraMode.SWEEP_PAN:
			_update_camera_sweep(delta)
		CameraMode.DRONE_ORBIT:
			_update_camera_orbit(delta)
		CameraMode.ACTION_TRACK:
			_update_camera_action(delta)

	# Smooth camera movement
	_camera_offset = _camera_offset.lerp(_camera_target, delta * 1.5)
	_camera_zoom = lerpf(_camera_zoom, _target_zoom, delta * 1.5)

func _update_camera_wide(delta: float) -> void:
	# Wide shot - center of battlefield, slight drift
	var drift = Vector2(sin(_cinematic_timer * 0.3) * 20, cos(_cinematic_timer * 0.2) * 15)
	_camera_target = drift
	_target_zoom = 1.0

func _update_camera_follow(delta: float) -> void:
	# Track a specific ship
	if _follow_ship and not _follow_ship.is_destroyed:
		_camera_target = -_follow_ship.pos + size / 2
		_target_zoom = 1.2  # Slight zoom
	else:
		_camera_mode = CameraMode.WIDE_SHOT

func _update_camera_closeup(delta: float) -> void:
	# Close-up on ship hull
	if _follow_ship and not _follow_ship.is_destroyed:
		_camera_target = -_follow_ship.pos + size / 2
		_target_zoom = 2.0  # Zoomed in
	else:
		_camera_mode = CameraMode.WIDE_SHOT

func _update_camera_sweep(delta: float) -> void:
	# Slow pan across battlefield
	var t = _camera_mode_timer / _camera_mode_duration
	t = ease(t, 0.3)  # Smooth easing
	var sweep_pos = _sweep_start.lerp(_sweep_end, t)
	_camera_target = -sweep_pos + size / 2
	_target_zoom = 1.1

func _update_camera_orbit(delta: float) -> void:
	# Drone orbit around a ship
	_orbit_angle += delta * 0.8  # Slow rotation
	if _follow_ship and not _follow_ship.is_destroyed:
		var orbit_offset = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * _orbit_radius
		_camera_target = -(_follow_ship.pos + orbit_offset) + size / 2
		_target_zoom = 1.5
	else:
		_camera_mode = CameraMode.WIDE_SHOT

func _update_camera_action(delta: float) -> void:
	# Fast tracking during combat - follow action
	if _follow_ship and not _follow_ship.is_destroyed and _follow_ship.target:
		# Track midpoint between ship and its target
		var midpoint = (_follow_ship.pos + _follow_ship.target.pos) / 2
		_camera_target = -midpoint + size / 2
		_target_zoom = 1.3
	elif _follow_ship and not _follow_ship.is_destroyed:
		_camera_target = -_follow_ship.pos + size / 2
		_target_zoom = 1.3
	else:
		_camera_mode = CameraMode.WIDE_SHOT

func _update_cinematics(delta: float) -> void:
	_camera_mode_timer += delta

	# Change camera mode when duration expires
	if _camera_mode_timer >= _camera_mode_duration:
		_switch_camera_mode()

func _switch_camera_mode() -> void:
	_camera_mode_timer = 0.0

	# Get active ships
	var all_ships = _player_ships + _herald_ships
	var active = all_ships.filter(func(s): return not s.is_destroyed)

	if active.is_empty():
		_camera_mode = CameraMode.WIDE_SHOT
		_camera_mode_duration = 5.0
		return

	# Weight camera modes for variety
	var mode_weights = [
		[CameraMode.WIDE_SHOT, 1],
		[CameraMode.FOLLOW_SHIP, 3],
		[CameraMode.CLOSE_UP, 2],
		[CameraMode.SWEEP_PAN, 2],
		[CameraMode.DRONE_ORBIT, 2],
		[CameraMode.ACTION_TRACK, 3]
	]

	# Pick weighted random mode
	var total_weight = 0
	for mw in mode_weights:
		total_weight += mw[1]
	var roll = randi() % total_weight
	var cumulative = 0
	var new_mode = CameraMode.WIDE_SHOT
	for mw in mode_weights:
		cumulative += mw[1]
		if roll < cumulative:
			new_mode = mw[0]
			break

	_camera_mode = new_mode

	# Setup for specific modes
	match _camera_mode:
		CameraMode.WIDE_SHOT:
			_camera_mode_duration = randf_range(6.0, 10.0)
			_follow_ship = null

		CameraMode.FOLLOW_SHIP:
			_camera_mode_duration = randf_range(8.0, 12.0)
			# Pick a random player ship (more dramatic)
			var player_active = _player_ships.filter(func(s): return not s.is_destroyed)
			if not player_active.is_empty():
				_follow_ship = player_active[randi() % player_active.size()]
			else:
				_follow_ship = active[randi() % active.size()]

		CameraMode.CLOSE_UP:
			_camera_mode_duration = randf_range(5.0, 8.0)
			# Pick ship in combat (has target)
			var in_combat = active.filter(func(s): return s.target != null)
			if not in_combat.is_empty():
				_follow_ship = in_combat[randi() % in_combat.size()]
			else:
				_follow_ship = active[randi() % active.size()]

		CameraMode.SWEEP_PAN:
			_camera_mode_duration = randf_range(8.0, 12.0)
			# Sweep from one side to another
			if randf() > 0.5:
				# Sweep from player to herald
				var player_pos = _get_fleet_center(_player_ships)
				var herald_pos = _get_fleet_center(_herald_ships)
				_sweep_start = player_pos
				_sweep_end = herald_pos
			else:
				# Sweep across horizontally
				_sweep_start = Vector2(size.x * 0.2, size.y * 0.5)
				_sweep_end = Vector2(size.x * 0.8, size.y * 0.5)

		CameraMode.DRONE_ORBIT:
			_camera_mode_duration = randf_range(10.0, 15.0)
			_orbit_angle = randf() * TAU
			_orbit_radius = randf_range(40, 80)
			# Pick a capital ship if possible
			var capitals = active.filter(func(s): return s.size > 14)
			if not capitals.is_empty():
				_follow_ship = capitals[randi() % capitals.size()]
			else:
				_follow_ship = active[randi() % active.size()]

		CameraMode.ACTION_TRACK:
			_camera_mode_duration = randf_range(6.0, 10.0)
			# Pick ship currently in combat
			var fighting = active.filter(func(s): return s.target != null and not s.target.is_destroyed)
			if not fighting.is_empty():
				_follow_ship = fighting[randi() % fighting.size()]
			else:
				_follow_ship = active[randi() % active.size()]

	# Transmission about camera change (occasionally)
	if randf() < 0.3:
		_generate_camera_transmission()

func _get_fleet_center(ships: Array) -> Vector2:
	var active = ships.filter(func(s): return not s.is_destroyed)
	if active.is_empty():
		return size / 2
	var center = Vector2.ZERO
	for ship in active:
		center += ship.pos
	return center / active.size()

func _generate_camera_transmission() -> void:
	match _camera_mode:
		CameraMode.CLOSE_UP:
			if _follow_ship and _follow_ship.ship_data:
				_transmissions.append("[DRONE] Visual on %s" % _follow_ship.ship_data.name.substr(0, 12))
		CameraMode.DRONE_ORBIT:
			if _follow_ship and _follow_ship.is_player:
				_transmissions.append("[CAM] Tracking friendly vessel")
			elif _follow_ship:
				_transmissions.append("[CAM] Herald contact bearing 270")
		CameraMode.ACTION_TRACK:
			_transmissions.append("[TACTICAL] Engagement in progress")
		CameraMode.SWEEP_PAN:
			_transmissions.append("[OVERVIEW] Scanning battle space")

func _update_transmissions(delta: float) -> void:
	if not _current_transmission.is_empty():
		_transmission_timer += delta
		if _transmission_timer > 2.5:
			_current_transmission = ""
			_transmission_timer = 0.0
	elif not _transmissions.is_empty():
		_current_transmission = _transmissions.pop_front()
		_transmission_timer = 0.0

# ============================================================================
# COMBAT - FIRING WEAPONS
# ============================================================================

func _fire_pdc_burst(ship: BattleShip) -> void:
	if not ship.target:
		return

	var to_target = ship.target.pos - ship.pos
	var base_angle = to_target.angle()

	# Fire from multiple turrets
	var turret_count = 2
	for t in range(turret_count):
		var spread = randf_range(-0.12, 0.12)
		var pdc = PDCBurst.new()
		pdc.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size * 0.5
		pdc.vel = Vector2.from_angle(base_angle + spread) * 600
		pdc.is_tracer = (randi() % 5 == 0)  # Every 5th is tracer
		_pdc_rounds.append(pdc)

	# Muzzle flash
	var flash = MuzzleFlash.new()
	flash.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size
	flash.dir = Vector2.from_angle(base_angle)
	flash.weapon_type = 0
	flash.size = 4
	_muzzle_flashes.append(flash)

func _fire_railgun(ship: BattleShip) -> void:
	if not ship.target:
		return

	var to_target = ship.target.pos - ship.pos
	var slug = RailgunSlug.new()
	slug.start = ship.pos
	slug.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size
	slug.vel = to_target.normalized() * 800
	slug.trail = []
	_railgun_slugs.append(slug)

	# Big muzzle flash
	var flash = MuzzleFlash.new()
	flash.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size * 1.2
	flash.dir = to_target.normalized()
	flash.weapon_type = 1
	flash.size = 10
	_muzzle_flashes.append(flash)

	_shake_intensity = maxf(_shake_intensity, 5)
	_transmissions.append("[%s] Railgun firing!" % (ship.ship_data.name.substr(0, 8) if ship.ship_data else "UNN"))

func _fire_torpedo(ship: BattleShip) -> void:
	if not ship.target:
		return

	var torp = Torpedo.new()
	torp.pos = ship.pos + Vector2.from_angle(ship.rotation) * ship.size
	torp.vel = Vector2.from_angle(ship.rotation) * 60
	torp.target = ship.target
	torp.smoke_trail = []
	_torpedoes.append(torp)

	_transmissions.append("[%s] Torpedo away!" % (ship.ship_data.name.substr(0, 8) if ship.ship_data else "UNN"))

func _fire_plasma_orb(ship: BattleShip) -> void:
	if not ship.target:
		return

	var orb = PlasmaOrb.new()
	var fire_angle = ship.rotation + randf_range(-0.3, 0.3)
	orb.pos = ship.pos + Vector2.from_angle(fire_angle) * ship.size
	orb.vel = Vector2.from_angle(fire_angle) * 80
	orb.target_pos = ship.target.pos
	orb.size = randf_range(6, 10)
	_plasma_orbs.append(orb)

func _fire_energy_tendril(ship: BattleShip) -> void:
	if not ship.target:
		return

	var tendril = EnergyTendril.new()
	tendril.start = ship.pos
	tendril.end = ship.target.pos

	# Create bezier control points for curved beam
	var mid = (tendril.start + tendril.end) / 2
	var perp = (tendril.end - tendril.start).normalized()
	perp = Vector2(-perp.y, perp.x)
	tendril.control_points = [
		mid + perp * randf_range(-40, 40),
		mid + perp * randf_range(-40, 40)
	]
	_energy_tendrils.append(tendril)

func _spawn_swarm_drones(ship: BattleShip, count: int) -> void:
	for i in range(count):
		var drone = SwarmDrone.new()
		drone.pos = ship.pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		drone.vel = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		drone.orbit_angle = randf() * TAU
		if ship.target:
			drone.target = ship.target
		_swarm_drones.append(drone)

# ============================================================================
# COMBAT - DAMAGE
# ============================================================================

func _hit_herald(ship: BattleShip, damage: float, hit_pos: Vector2) -> void:
	# Apply damage multiplier based on predetermined outcome (player attacking)
	var biased_damage = damage * _get_damage_multiplier(true)

	# Shield absorbs first
	if ship.shields > 0:
		ship.shields -= biased_damage * 2
		var shield_hit = ShieldHit.new()
		shield_hit.pos = hit_pos
		shield_hit.normal = (hit_pos - ship.pos).normalized()
		_shield_hits.append(shield_hit)
		if ship.shields <= 0:
			ship.shields = 0
			_transmissions.append("[TACTICAL] Herald shields down!")
		return

	ship.health -= biased_damage
	ship.damage_flicker = 1.0
	_shake_intensity = maxf(_shake_intensity, 2)

	# Check for death - but protect last ship until final phase
	if ship.health <= 0:
		if _should_protect_ship(ship):
			ship.health = 0.05  # Keep barely alive
			ship.damage_flicker = 1.0
		elif not ship.is_destroyed:
			_destroy_herald(ship)

func _hit_human(ship: BattleShip, damage: float, hit_pos: Vector2) -> void:
	# Apply damage multiplier based on predetermined outcome (herald attacking)
	var biased_damage = damage * _get_damage_multiplier(false)

	ship.health -= biased_damage
	ship.damage_flicker = 1.0
	_shake_intensity = maxf(_shake_intensity, 3)

	# Check for death - but protect last ship until final phase
	if ship.health <= 0:
		if _should_protect_ship(ship):
			ship.health = 0.05  # Keep barely alive
			ship.damage_flicker = 1.0
		elif not ship.is_destroyed:
			_destroy_human(ship)

func _destroy_herald(ship: BattleShip) -> void:
	ship.is_destroyed = true
	_create_explosion(ship.pos, ship.size * 4, true)
	_shake_intensity = maxf(_shake_intensity, 12)
	_spawn_debris(ship.pos, 10, true)

func _destroy_human(ship: BattleShip) -> void:
	ship.is_destroyed = true
	_create_explosion(ship.pos, ship.size * 4, false)
	_shake_intensity = maxf(_shake_intensity, 15)
	_spawn_debris(ship.pos, 12, false)

	if ship.ship_data:
		_transmissions.append("[MAYDAY] %s destroyed!" % ship.ship_data.name.substr(0, 12))
		ship_destroyed.emit(ship.ship_data.name)

func _create_explosion(pos: Vector2, radius: float, is_herald: bool) -> void:
	var exp = Explosion.new()
	exp.pos = pos
	exp.max_radius = radius
	exp.max_life = 0.8 + radius * 0.02
	exp.life = exp.max_life
	exp.is_herald = is_herald

	# Particles
	for j in range(15):
		exp.particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-100, 100), randf_range(-100, 100)),
			"color": Color(1, 0.3, 0.5) if is_herald else Color(1, 0.6, 0.2),
			"size": randf_range(2, 5),
			"life": randf_range(0.3, 0.6)
		})
	_explosions.append(exp)

func _spawn_debris(pos: Vector2, count: int, is_herald: bool) -> void:
	for j in range(count):
		var d = Debris.new()
		d.pos = pos
		d.vel = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		d.rotation = randf() * TAU
		d.spin = randf_range(-4, 4)
		d.size = randf_range(2, 6)
		d.life = randf_range(2, 4)
		d.is_herald = is_herald
		_debris.append(d)

# ============================================================================
# HELPERS
# ============================================================================

func _find_nearest(ship: BattleShip, targets: Array) -> BattleShip:
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

func _find_nearest_pos(pos: Vector2, targets: Array) -> BattleShip:
	var nearest: BattleShip = null
	var nearest_dist = INF
	for t in targets:
		if t.is_destroyed:
			continue
		var dist = pos.distance_to(t.pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = t
	return nearest

func _off_screen(pos: Vector2) -> bool:
	return pos.x < -30 or pos.x > size.x + 30 or pos.y < -30 or pos.y > size.y + 30

func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1 - t
	return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3

func _point_to_line_dist(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line = line_end - line_start
	var len_sq = line.length_squared()
	if len_sq == 0:
		return point.distance_to(line_start)
	var t = clampf(((point - line_start).dot(line)) / len_sq, 0, 1)
	var projection = line_start + t * line
	return point.distance_to(projection)

# ============================================================================
# BATTLE CONCLUSION - Ensures predetermined outcome through biased combat
# ============================================================================

var _in_final_phase: bool = false  # When true, last ships can die

func _check_battle_conclusion(current_player: int, current_herald: int) -> void:
	## Check if battle should conclude and manage the final phase
	var battle_progress = _battle_time / _battle_duration

	# Early battle - keep at least 1 ship on each side for drama
	if battle_progress < 0.7:
		return

	# Near end of battle - enter final phase where last ships can die
	if battle_progress > 0.85 and not _in_final_phase:
		_in_final_phase = true
		if _player_won:
			_transmissions.append("[TACTICAL] Enemy retreat detected - press the attack!")
		else:
			_transmissions.append("[COMMAND] All ships, fighting withdrawal!")

	# Check for natural conclusion (one side eliminated)
	if current_player == 0 or current_herald == 0:
		if not _outcome_decided:
			_end_battle()

func _get_damage_multiplier(attacker_is_player: bool) -> float:
	## Returns damage multiplier based on predetermined outcome
	## CRITICAL: Winners ALWAYS do more damage from the start
	## The battle must never show the wrong side winning
	var battle_progress = _battle_time / _battle_duration

	# Strong initial bias that increases over time
	# Start at 1.3x advantage, grow to 2.0x by end
	var base_advantage = 1.3
	var scaling_advantage = battle_progress * 0.7  # Additional 0.7x by end
	var winner_mult = base_advantage + scaling_advantage

	# Losers do reduced damage from the start
	var loser_mult = 0.6 - battle_progress * 0.2  # 0.6x down to 0.4x

	if attacker_is_player:
		# Player attacking herald
		return winner_mult if _player_won else loser_mult
	else:
		# Herald attacking player
		return winner_mult if not _player_won else loser_mult

func _should_protect_ship(ship: BattleShip) -> bool:
	## Returns true if this ship should be protected from death
	## CRITICAL: Winning side's ships are ALWAYS protected until final phase
	## Losing side only protected if they're the last ship (for drama)
	if _in_final_phase:
		return false  # No protection in final phase - let battle conclude

	var is_on_winning_side = (ship.is_player and _player_won) or (not ship.is_player and not _player_won)

	if is_on_winning_side:
		# ALWAYS protect winning side ships until final phase
		# They must never all die before the battle ends correctly
		var active_same_side = 0
		if ship.is_player:
			for s in _player_ships:
				if not s.is_destroyed:
					active_same_side += 1
		else:
			for s in _herald_ships:
				if not s.is_destroyed:
					active_same_side += 1
		# Protect if this would be less than 2 ships (keep drama)
		return active_same_side <= 2
	else:
		# Losing side - only protect the very last ship for dramatic final stand
		var active_same_side = 0
		if ship.is_player:
			for s in _player_ships:
				if not s.is_destroyed:
					active_same_side += 1
		else:
			for s in _herald_ships:
				if not s.is_destroyed:
					active_same_side += 1
		return active_same_side <= 1

func _apply_final_phase_pressure() -> void:
	## In final phase, aggressively ensure the correct side wins
	## This is called every frame, so use small increments
	if not _in_final_phase:
		# Even before final phase, apply light attrition to losing side
		_apply_losing_side_attrition()
		return

	var active_player = _player_ships.filter(func(s): return not s.is_destroyed)
	var active_herald = _herald_ships.filter(func(s): return not s.is_destroyed)

	# Aggressive drain in final phase - battle must end correctly
	var drain_rate = 0.02  # 2% per frame = fast

	if _player_won:
		# Pressure herald ships to die
		for ship in active_herald:
			ship.health -= drain_rate
			ship.damage_flicker = maxf(ship.damage_flicker, 0.3)
			if ship.health <= 0 and not ship.is_destroyed:
				_destroy_herald(ship)
	else:
		# Pressure player ships to die
		for ship in active_player:
			ship.health -= drain_rate
			ship.damage_flicker = maxf(ship.damage_flicker, 0.3)
			if ship.health <= 0 and not ship.is_destroyed:
				_destroy_human(ship)

func _apply_losing_side_attrition() -> void:
	## Constant light attrition on losing side to ensure they're always behind
	## Called every frame before final phase
	var battle_progress = _battle_time / _battle_duration

	# Attrition increases as battle progresses
	var attrition_rate = 0.001 + battle_progress * 0.003  # 0.1% to 0.4% per frame

	if _player_won:
		# Herald is losing - apply attrition
		for ship in _herald_ships:
			if not ship.is_destroyed and not _should_protect_ship(ship):
				ship.health -= attrition_rate
				if ship.health <= 0:
					_destroy_herald(ship)
	else:
		# Player is losing - apply attrition
		for ship in _player_ships:
			if not ship.is_destroyed and not _should_protect_ship(ship):
				ship.health -= attrition_rate
				if ship.health <= 0:
					_destroy_human(ship)

func _force_battle_conclusion() -> void:
	## Called when battle time is up - ensure the correct side wins
	## This is the "director's cut" - make sure the story ends right
	var active_player = _player_ships.filter(func(s): return not s.is_destroyed)
	var active_herald = _herald_ships.filter(func(s): return not s.is_destroyed)

	if _player_won:
		# Player should win - destroy remaining herald ships
		for ship in active_herald:
			_destroy_herald(ship)
			_transmissions.append("[TACTICAL] Final enemy contact destroyed!")
	else:
		# Herald should win - destroy remaining player ships
		for ship in active_player:
			_destroy_human(ship)

# ============================================================================
# PUBLIC API
# ============================================================================

func start_battle(zone_name: String, player_ships: Array, herald_count: int, will_hold: bool) -> void:
	_zone_name = zone_name
	_is_active = true
	_battle_time = 0.0
	_cinematic_timer = 0.0
	_outcome_decided = false
	_player_won = will_hold

	# EU4-style battle scaling - bigger battles = longer duration
	var total_ships = player_ships.size() + herald_count
	_starting_player_ships = player_ships.size()
	_starting_herald_ships = herald_count
	_player_losses = 0
	_herald_losses = 0
	_combat_phase = 0
	_phase_timer = 0.0
	_last_phase_announcement = ""
	_in_final_phase = false  # Reset final phase flag

	# Determine if this is a major battle (epic length)
	_is_major_battle = total_ships >= 8 or herald_count >= 6 or zone_name in ["Jupiter", "Saturn", "Earth", "Mars"]

	# Scale battle duration: small skirmish = 8s, major battle = 25-40s
	if total_ships <= 3:
		_battle_duration = 8.0  # Quick skirmish
		_phase_duration = 4.0
	elif total_ships <= 6:
		_battle_duration = 15.0  # Standard engagement
		_phase_duration = 3.5
	elif _is_major_battle:
		_battle_duration = 25.0 + total_ships * 1.5  # EPIC battle
		_phase_duration = 4.0
	else:
		_battle_duration = 18.0
		_phase_duration = 3.5

	# Cap at reasonable max
	_battle_duration = minf(_battle_duration, 45.0)

	# Clear all
	_player_ships.clear()
	_herald_ships.clear()
	_pdc_rounds.clear()
	_railgun_slugs.clear()
	_torpedoes.clear()
	_plasma_orbs.clear()
	_energy_tendrils.clear()
	_swarm_drones.clear()
	_explosions.clear()
	_debris.clear()
	_shield_hits.clear()
	_muzzle_flashes.clear()
	_transmissions.clear()
	_current_transmission = ""
	_camera_offset = Vector2.ZERO
	_follow_ship = null

	# Initialize camera system
	_camera_mode = CameraMode.WIDE_SHOT
	_camera_mode_timer = 0.0
	_camera_mode_duration = 4.0  # Start with shorter wide shot, then switch
	_target_zoom = 1.0
	_camera_zoom = 1.0
	_orbit_angle = 0.0

	# Scale factor based on view size (expanded vs compact)
	var scale_factor = minf(size.x / 400.0, size.y / 280.0)
	scale_factor = clampf(scale_factor, 1.0, 2.5)

	var center = size / 2
	var ship_spacing = 40 * scale_factor
	var ship_base_size = 12 * scale_factor

	# Create human ships (right side)
	var max_player = 4 if scale_factor < 1.5 else 6
	for i in range(mini(player_ships.size(), max_player)):
		var ship = BattleShip.new()
		ship.ship_data = player_ships[i]
		ship.pos = Vector2(size.x * 0.75, center.y + (i - (max_player - 1) * 0.5) * ship_spacing)
		ship.rotation = PI
		ship.size = ship_base_size + (i % 2) * 4 * scale_factor
		ship.is_player = true
		ship.health = 1.0
		ship.shields = 0  # Humans don't have shields
		_player_ships.append(ship)

	# Create herald ships (left side)
	var max_herald = 6 if scale_factor < 1.5 else 10
	for i in range(mini(herald_count, max_herald)):
		var ship = BattleShip.new()
		ship.pos = Vector2(size.x * 0.2 + randf() * 40 * scale_factor, 40 * scale_factor + i * ((size.y - 80 * scale_factor) / max(herald_count - 1, 1)))
		ship.rotation = 0
		ship.size = randf_range(10, 16) * scale_factor
		ship.is_player = false
		ship.health = 0.7
		ship.shields = 0.5  # Heralds have shields
		_herald_ships.append(ship)

	# Follow first player ship
	if not _player_ships.is_empty():
		_follow_ship = _player_ships[0]

	if not player_ships.is_empty() and player_ships[0]:
		var name = player_ships[0].name if player_ships[0].get("name") else "Fleet"
		_transmissions.append("[%s] All hands, battle stations!" % name.substr(0, 10))

	visible = true

func _end_battle() -> void:
	_outcome_decided = true
	if _player_won:
		_transmissions.append("[COMMAND] Zone secure. Well done.")
	else:
		_transmissions.append("[COMMAND] Zone lost. All ships withdraw!")

	await get_tree().create_timer(2.5).timeout
	_is_active = false
	visible = false
	battle_complete.emit()

func is_active() -> bool:
	return _is_active
