extends Node2D
class_name EVAController

## Controls EVA (Extra-Vehicular Activity) mechanics
## - Exterior control surfaces (engine, antenna, solar panel)
## - Tether visualization and physics
## - Rescue mechanics when crew drifts

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const ShipNavigation = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_navigation.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal eva_started(crew_role: String, target: int)
signal eva_completed(crew_role: String, success: bool)
signal crew_drifted(crew_role: String)
signal rescue_started(rescuer_role: String, victim_role: String)
signal rescue_completed(victim_role: String)

# ============================================================================
# EXTERIOR SURFACE DEFINITIONS
# ============================================================================

const SURFACE_CONFIGS = {
	ShipNavigation.Waypoint.EXTERIOR_ENGINE: {
		"name": "Engine Nozzle",
		"color": Color(0.6, 0.4, 0.2),  # Bronze
		"size": Vector2(40, 30),
		"shape": "engine",
	},
	ShipNavigation.Waypoint.EXTERIOR_ANTENNA: {
		"name": "Antenna Array",
		"color": Color(0.5, 0.5, 0.6),  # Silver
		"size": Vector2(50, 40),
		"shape": "antenna",
	},
	ShipNavigation.Waypoint.EXTERIOR_SOLAR: {
		"name": "Solar Panel",
		"color": Color(0.2, 0.3, 0.5),  # Dark blue
		"size": Vector2(60, 25),
		"shape": "solar",
	},
}

# ============================================================================
# STATE
# ============================================================================

var ship_view: Node = null
var ship_nav: ShipNavigation = null

# Active EVA state
var active_eva: Dictionary = {}  # crew_role -> EVA state dict
var exterior_surfaces: Dictionary = {}  # waypoint -> Node2D

# Tethers
var tethers: Dictionary = {}  # crew_role -> Line2D

# Drift state
var drifting_crew: Dictionary = {}  # crew_role -> drift state

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	z_index = 5  # Above ship hull but below crew

func setup(view: Node, nav: ShipNavigation) -> void:
	ship_view = view
	ship_nav = nav
	_create_exterior_surfaces()
	_create_airlock_visual()

func _create_exterior_surfaces() -> void:
	## Create visual representations of exterior control surfaces
	for waypoint in SURFACE_CONFIGS:
		var config = SURFACE_CONFIGS[waypoint]
		var pos = ship_nav.get_waypoint_position(waypoint)

		var surface = _create_surface_visual(waypoint, config, pos)
		add_child(surface)
		exterior_surfaces[waypoint] = surface

func _create_surface_visual(waypoint: int, config: Dictionary, pos: Vector2) -> Node2D:
	var container = Node2D.new()
	container.position = pos
	container.name = config.name.replace(" ", "_")

	match config.shape:
		"engine":
			_add_engine_visual(container, config)
		"antenna":
			_add_antenna_visual(container, config)
		"solar":
			_add_solar_visual(container, config)

	return container

func _add_engine_visual(container: Node2D, config: Dictionary) -> void:
	## Engine nozzle - cone shape
	var nozzle = Polygon2D.new()
	nozzle.polygon = PackedVector2Array([
		Vector2(-15, -20), Vector2(15, -20),  # Top (narrow)
		Vector2(25, 20), Vector2(-25, 20),    # Bottom (wide)
	])
	nozzle.color = config.color
	container.add_child(nozzle)

	# Glow effect (exhaust)
	var glow = Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-20, 20), Vector2(20, 20),
		Vector2(10, 45), Vector2(-10, 45),
	])
	glow.color = Color(0.3, 0.5, 0.8, 0.4)  # Blue exhaust glow
	container.add_child(glow)

	# Mounting bracket
	var bracket = Polygon2D.new()
	bracket.polygon = PackedVector2Array([
		Vector2(-8, -25), Vector2(8, -25),
		Vector2(8, -20), Vector2(-8, -20),
	])
	bracket.color = Color(0.4, 0.4, 0.4)
	container.add_child(bracket)

func _add_antenna_visual(container: Node2D, config: Dictionary) -> void:
	## Antenna array - dish with spokes
	# Main dish (arc shape)
	var dish = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(13):
		var angle = PI + (float(i) / 12) * PI  # 180 degrees arc
		points.append(Vector2(cos(angle) * 25, sin(angle) * 20))
	# Close the dish bottom
	points.append(Vector2(25, 3))
	points.append(Vector2(-25, 3))
	dish.polygon = points
	dish.color = config.color
	container.add_child(dish)

	# Central receiver
	var receiver = Polygon2D.new()
	receiver.polygon = _create_circle(5, 8)
	receiver.position = Vector2(0, -8)
	receiver.color = Color(0.8, 0.2, 0.2)  # Red receiver
	container.add_child(receiver)

	# Support arm
	var arm = Polygon2D.new()
	arm.polygon = PackedVector2Array([
		Vector2(-2, 0), Vector2(2, 0),
		Vector2(2, 15), Vector2(-2, 15),
	])
	arm.color = Color(0.4, 0.4, 0.4)
	container.add_child(arm)

	# Mounting base
	var base = Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-10, 15), Vector2(10, 15),
		Vector2(10, 20), Vector2(-10, 20),
	])
	base.color = Color(0.3, 0.3, 0.35)
	container.add_child(base)

func _add_solar_visual(container: Node2D, config: Dictionary) -> void:
	## Solar panel - rectangular with grid lines
	# Main panel
	var panel = Polygon2D.new()
	panel.polygon = PackedVector2Array([
		Vector2(-30, -12), Vector2(30, -12),
		Vector2(30, 12), Vector2(-30, 12),
	])
	panel.color = config.color
	container.add_child(panel)

	# Grid lines (horizontal)
	for i in range(3):
		var y = -8 + i * 8
		var line = Line2D.new()
		line.add_point(Vector2(-28, y))
		line.add_point(Vector2(28, y))
		line.width = 1.0
		line.default_color = Color(0.4, 0.5, 0.7, 0.6)
		container.add_child(line)

	# Grid lines (vertical)
	for i in range(7):
		var x = -24 + i * 8
		var line = Line2D.new()
		line.add_point(Vector2(x, -10))
		line.add_point(Vector2(x, 10))
		line.width = 1.0
		line.default_color = Color(0.4, 0.5, 0.7, 0.6)
		container.add_child(line)

	# Frame
	var frame = Line2D.new()
	frame.add_point(Vector2(-30, -12))
	frame.add_point(Vector2(30, -12))
	frame.add_point(Vector2(30, 12))
	frame.add_point(Vector2(-30, 12))
	frame.add_point(Vector2(-30, -12))
	frame.width = 2.0
	frame.default_color = Color(0.5, 0.5, 0.5)
	container.add_child(frame)

	# Mounting arm
	var arm = Polygon2D.new()
	arm.polygon = PackedVector2Array([
		Vector2(-3, 12), Vector2(3, 12),
		Vector2(3, 25), Vector2(-3, 25),
	])
	arm.color = Color(0.4, 0.4, 0.4)
	container.add_child(arm)

func _create_airlock_visual() -> void:
	## Create airlock door visual
	var airlock_pos = ship_nav.get_waypoint_position(ShipNavigation.Waypoint.AIRLOCK)

	var airlock = Node2D.new()
	airlock.position = airlock_pos
	airlock.name = "Airlock"

	# Airlock hatch (circular)
	var hatch = Polygon2D.new()
	hatch.polygon = _create_circle(15, 12)
	hatch.color = Color(0.4, 0.4, 0.45)
	airlock.add_child(hatch)

	# Hatch inner ring
	var inner = Polygon2D.new()
	inner.polygon = _create_circle(10, 12)
	inner.color = Color(0.3, 0.3, 0.35)
	airlock.add_child(inner)

	# Handle
	var handle = Line2D.new()
	handle.add_point(Vector2(-6, 0))
	handle.add_point(Vector2(6, 0))
	handle.width = 3.0
	handle.default_color = Color(0.6, 0.6, 0.2)
	airlock.add_child(handle)

	add_child(airlock)

func _create_circle(radius: float, segments: int = 12) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

# ============================================================================
# EVA OPERATIONS
# ============================================================================

func start_eva(crew_role: String, target_waypoint: int) -> void:
	## Start an EVA to an exterior location
	if active_eva.has(crew_role):
		return  # Already on EVA

	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		return

	print("[EVA] %s starting EVA to %s" % [crew_role.capitalize(), ShipNavigation.get_exterior_name(target_waypoint)])

	active_eva[crew_role] = {
		"target": target_waypoint,
		"phase": "departing",  # departing, outside, working, returning, complete
		"start_time": Time.get_ticks_msec(),
	}

	# Create tether
	_create_tether(crew_role)

	# Send crew to exterior location
	var path = ship_nav.find_eva_path(crew_member.current_room, target_waypoint)
	crew_member.move_along_path(ShipTypes.RoomType.CARGO_BAY, path, null, false)
	crew_member.set_state(ShipTypes.CrewState.EVA)

	eva_started.emit(crew_role, target_waypoint)

func _create_tether(crew_role: String) -> void:
	var tether = Line2D.new()
	tether.name = "Tether_" + crew_role
	tether.width = 2.0
	tether.default_color = Color(0.9, 0.85, 0.2, 0.9)  # Yellow safety tether
	tether.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tether.end_cap_mode = Line2D.LINE_CAP_ROUND
	tether.z_index = 9
	tether.visible = true

	var airlock_pos = ship_nav.get_waypoint_position(ShipNavigation.Waypoint.AIRLOCK)
	tether.add_point(airlock_pos)
	tether.add_point(airlock_pos)  # Will update in _process

	add_child(tether)
	tethers[crew_role] = tether

func _process(delta: float) -> void:
	# Update tethers to follow crew
	for role in active_eva:
		_update_tether(role)

	# Process drift physics
	for role in drifting_crew:
		_process_drift(role, delta)

func _update_tether(crew_role: String) -> void:
	var tether = tethers.get(crew_role)
	var crew_member = ship_view.crew.get(crew_role)

	if not tether or not crew_member:
		return

	# Add wave motion to tether
	var time = Time.get_ticks_msec() / 1000.0
	var wave = Vector2(sin(time * 2.0) * 2.0, cos(time * 3.0) * 2.0)
	tether.set_point_position(1, crew_member.global_position + wave)

func complete_eva(crew_role: String, success: bool = true) -> void:
	## Complete an EVA and return crew inside
	if not active_eva.has(crew_role):
		return

	print("[EVA] %s EVA complete (success: %s)" % [crew_role.capitalize(), success])

	# Clean up tether
	if tethers.has(crew_role):
		tethers[crew_role].queue_free()
		tethers.erase(crew_role)

	# Send crew back to their home room
	var crew_member = ship_view.crew.get(crew_role)
	if crew_member:
		var home_room = ShipTypes.CREW_HOME_ROOMS.get(crew_role, ShipTypes.RoomType.BRIDGE)
		ship_view.send_crew_to_room(crew_role, home_room, false)

	active_eva.erase(crew_role)
	eva_completed.emit(crew_role, success)

# ============================================================================
# DRIFT/RESCUE MECHANICS
# ============================================================================

const DRIFT_CHANCE = 0.15  # 15% chance to drift while working outside
const DRIFT_SPEED = 25.0   # Pixels per second
const SELF_RESCUE_SPEED = 8.0  # Slow self-rescue speed

func check_for_drift(crew_role: String) -> bool:
	## Check if crew drifts while working - returns true if drifted
	if randf() > DRIFT_CHANCE:
		return false

	_start_drift(crew_role)
	return true

func _start_drift(crew_role: String) -> void:
	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		return

	print("[EVA] %s has drifted off! Tether holding..." % crew_role.capitalize())

	# Random drift direction (away from ship)
	var drift_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	# Bias away from ship center
	var to_center = (ship_view.layout_center - crew_member.global_position).normalized()
	drift_dir = (drift_dir - to_center * 0.5).normalized()

	drifting_crew[crew_role] = {
		"direction": drift_dir,
		"distance": 0.0,
		"max_distance": randf_range(80, 150),  # How far they drift
		"phase": "drifting",  # drifting, stopped, pulling_back
		"rescuer": "",
	}

	crew_member.set_state(ShipTypes.CrewState.TETHERED)
	crew_drifted.emit(crew_role)

func _process_drift(crew_role: String, delta: float) -> void:
	var drift = drifting_crew[crew_role]
	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		return

	match drift.phase:
		"drifting":
			# Drift outward
			drift.distance += DRIFT_SPEED * delta
			crew_member.global_position += drift.direction * DRIFT_SPEED * delta

			if drift.distance >= drift.max_distance:
				drift.phase = "stopped"
				print("[EVA] %s has stopped drifting, %s away" % [
					crew_role.capitalize(),
					"%.0f units" % drift.distance
				])
				_check_for_rescue(crew_role)

		"stopped":
			# Waiting for rescue or self-rescue
			pass

		"pulling_back":
			# Being pulled back (by self or rescuer)
			var speed = SELF_RESCUE_SPEED if drift.rescuer == "" else DRIFT_SPEED * 1.5
			var airlock_pos = ship_nav.get_waypoint_position(ShipNavigation.Waypoint.AIRLOCK)
			var to_airlock = (airlock_pos - crew_member.global_position).normalized()

			crew_member.global_position += to_airlock * speed * delta
			drift.distance -= speed * delta

			if drift.distance <= 0:
				_complete_rescue(crew_role)

func _check_for_rescue(drifted_role: String) -> void:
	## Find someone to rescue the drifted crew member
	# Check for available crew who can rescue
	for role in ship_view.crew:
		if role == drifted_role:
			continue

		var member = ship_view.crew[role]
		if member.current_state == ShipTypes.CrewState.IDLE:
			# This crew member can rescue!
			_start_rescue(role, drifted_role)
			return

	# No one available - start slow self-rescue
	print("[EVA] No one available to rescue %s - pulling self back on tether..." % drifted_role.capitalize())
	drifting_crew[drifted_role].phase = "pulling_back"

func _start_rescue(rescuer_role: String, victim_role: String) -> void:
	print("[EVA] %s going out to rescue %s!" % [rescuer_role.capitalize(), victim_role.capitalize()])

	drifting_crew[victim_role].rescuer = rescuer_role
	drifting_crew[victim_role].phase = "pulling_back"

	# Send rescuer to airlock and start their EVA
	start_eva(rescuer_role, ShipNavigation.Waypoint.AIRLOCK)

	rescue_started.emit(rescuer_role, victim_role)

func _complete_rescue(crew_role: String) -> void:
	var drift = drifting_crew.get(crew_role)
	if not drift:
		return

	var rescuer = drift.rescuer
	print("[EVA] %s safely back at airlock%s" % [
		crew_role.capitalize(),
		" (rescued by %s)" % rescuer.capitalize() if rescuer else " (self-rescued)"
	])

	drifting_crew.erase(crew_role)

	# Complete EVA for rescued crew
	complete_eva(crew_role, true)

	# Complete rescuer's EVA too
	if rescuer:
		complete_eva(rescuer, true)

	rescue_completed.emit(crew_role)

# ============================================================================
# QUERIES
# ============================================================================

func is_on_eva(crew_role: String) -> bool:
	return active_eva.has(crew_role)

func is_drifting(crew_role: String) -> bool:
	return drifting_crew.has(crew_role)

func get_active_eva_count() -> int:
	return active_eva.size()

func get_exterior_surface_position(waypoint: int) -> Vector2:
	return ship_nav.get_waypoint_position(waypoint)
