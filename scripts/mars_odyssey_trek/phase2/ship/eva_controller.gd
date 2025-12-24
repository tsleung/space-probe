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
signal eva_repair_completed(waypoint: int)  # Emitted when exterior surface repaired
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
var maintenance_panels: Dictionary = {}  # waypoint -> panel node

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

	# Add maintenance panel to each surface
	var panel = _create_maintenance_panel(config.shape)
	container.add_child(panel)
	maintenance_panels[waypoint] = panel

	return container

func _create_maintenance_panel(surface_type: String) -> Node2D:
	## Create an openable maintenance panel for exterior work
	var panel_container = Node2D.new()
	panel_container.name = "MaintenancePanel"

	# Panel position varies by surface type
	var panel_offset = Vector2.ZERO
	var panel_size = Vector2(16, 12)

	match surface_type:
		"engine":
			panel_offset = Vector2(-25, -10)
			panel_size = Vector2(14, 10)
		"antenna":
			panel_offset = Vector2(0, 15)
			panel_size = Vector2(12, 8)
		"solar":
			panel_offset = Vector2(25, 0)
			panel_size = Vector2(10, 10)

	panel_container.position = panel_offset

	# Panel cover (closed state)
	var cover = Polygon2D.new()
	cover.polygon = PackedVector2Array([
		Vector2(-panel_size.x/2, -panel_size.y/2),
		Vector2(panel_size.x/2, -panel_size.y/2),
		Vector2(panel_size.x/2, panel_size.y/2),
		Vector2(-panel_size.x/2, panel_size.y/2),
	])
	cover.color = Color(0.5, 0.5, 0.55)
	cover.name = "PanelCover"
	panel_container.add_child(cover)

	# Panel frame
	var frame = Line2D.new()
	frame.add_point(Vector2(-panel_size.x/2, -panel_size.y/2))
	frame.add_point(Vector2(panel_size.x/2, -panel_size.y/2))
	frame.add_point(Vector2(panel_size.x/2, panel_size.y/2))
	frame.add_point(Vector2(-panel_size.x/2, panel_size.y/2))
	frame.add_point(Vector2(-panel_size.x/2, -panel_size.y/2))
	frame.width = 1.5
	frame.default_color = Color(0.3, 0.3, 0.35)
	frame.name = "PanelFrame"
	panel_container.add_child(frame)

	# Panel handle/latch
	var handle = Polygon2D.new()
	handle.polygon = PackedVector2Array([
		Vector2(-2, -1), Vector2(2, -1),
		Vector2(2, 1), Vector2(-2, 1),
	])
	handle.position = Vector2(0, panel_size.y/2 - 2)
	handle.color = Color(0.7, 0.6, 0.2)
	handle.name = "PanelHandle"
	panel_container.add_child(handle)

	# Interior (hidden behind cover, revealed when open)
	var interior = Polygon2D.new()
	interior.polygon = PackedVector2Array([
		Vector2(-panel_size.x/2 + 1, -panel_size.y/2 + 1),
		Vector2(panel_size.x/2 - 1, -panel_size.y/2 + 1),
		Vector2(panel_size.x/2 - 1, panel_size.y/2 - 1),
		Vector2(-panel_size.x/2 + 1, panel_size.y/2 - 1),
	])
	interior.color = Color(0.15, 0.15, 0.2)  # Dark interior
	interior.z_index = -1  # Behind cover
	interior.name = "PanelInterior"
	panel_container.add_child(interior)

	# Circuitry/components inside (visible when open)
	var circuit1 = Line2D.new()
	circuit1.add_point(Vector2(-4, -2))
	circuit1.add_point(Vector2(0, -2))
	circuit1.add_point(Vector2(0, 2))
	circuit1.add_point(Vector2(4, 2))
	circuit1.width = 1.0
	circuit1.default_color = Color(0.3, 0.8, 0.3, 0.8)
	circuit1.z_index = -1
	circuit1.name = "Circuit1"
	panel_container.add_child(circuit1)

	var circuit2 = Line2D.new()
	circuit2.add_point(Vector2(-3, 0))
	circuit2.add_point(Vector2(3, 0))
	circuit2.width = 1.0
	circuit2.default_color = Color(0.8, 0.3, 0.3, 0.8)
	circuit2.z_index = -1
	circuit2.name = "Circuit2"
	panel_container.add_child(circuit2)

	return panel_container

func open_maintenance_panel(waypoint: int) -> void:
	## Animate opening a maintenance panel
	var panel = maintenance_panels.get(waypoint)
	if not panel:
		return

	var cover = panel.get_node_or_null("PanelCover")
	if not cover:
		return

	# Animate cover opening (rotate/scale)
	var tween = create_tween()
	tween.tween_property(cover, "scale", Vector2(0.1, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cover, "position:x", cover.position.x - 8, 0.3)

func close_maintenance_panel(waypoint: int) -> void:
	## Animate closing a maintenance panel
	var panel = maintenance_panels.get(waypoint)
	if not panel:
		return

	var cover = panel.get_node_or_null("PanelCover")
	if not cover:
		return

	# Animate cover closing
	var tween = create_tween()
	tween.tween_property(cover, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(cover, "position:x", 0.0, 0.3)

# ============================================================================
# WORK ANIMATIONS & ACTIVITY INDICATORS
# ============================================================================

var active_work_animations: Dictionary = {}  # waypoint -> animation nodes
var activity_indicators: Dictionary = {}  # waypoint -> glow node

func _start_work_animation(waypoint: int) -> void:
	## Start work-specific animation at exterior surface
	var surface = exterior_surfaces.get(waypoint)
	if not surface:
		return

	# Start the ship-level activity indicator (visible from distance)
	_start_activity_indicator(waypoint)

	# Get the panel position for animation placement
	var panel = maintenance_panels.get(waypoint)
	var panel_pos = panel.position if panel else Vector2.ZERO

	match waypoint:
		ShipNavigation.Waypoint.EXTERIOR_ENGINE:
			_start_engine_work_animation(surface, panel_pos)
		ShipNavigation.Waypoint.EXTERIOR_ANTENNA:
			_start_antenna_work_animation(surface, panel_pos)
		ShipNavigation.Waypoint.EXTERIOR_SOLAR:
			_start_solar_work_animation(surface, panel_pos)

func _stop_work_animation(waypoint: int) -> void:
	## Stop and clean up work animation
	if active_work_animations.has(waypoint):
		var anim_nodes = active_work_animations[waypoint]
		for node in anim_nodes:
			if is_instance_valid(node):
				node.queue_free()
		active_work_animations.erase(waypoint)

	# Stop activity indicator
	_stop_activity_indicator(waypoint)

func _start_activity_indicator(waypoint: int) -> void:
	## Create a pulsing glow at work location visible from zoomed-out view
	var surface = exterior_surfaces.get(waypoint)
	if not surface:
		return

	# Determine glow color based on work type
	var glow_color: Color
	match waypoint:
		ShipNavigation.Waypoint.EXTERIOR_ENGINE:
			glow_color = Color(1.0, 0.6, 0.2, 0.4)  # Orange for welding
		ShipNavigation.Waypoint.EXTERIOR_ANTENNA:
			glow_color = Color(0.3, 0.7, 1.0, 0.4)  # Blue for calibration
		ShipNavigation.Waypoint.EXTERIOR_SOLAR:
			glow_color = Color(1.0, 0.9, 0.3, 0.4)  # Yellow for percussive
		_:
			glow_color = Color(0.8, 0.8, 0.8, 0.4)

	# Create large outer glow (visible from distance)
	var glow_container = Node2D.new()
	glow_container.name = "ActivityIndicator"
	glow_container.z_index = -2  # Behind everything else
	surface.add_child(glow_container)

	# Large soft glow
	var outer_glow = Polygon2D.new()
	outer_glow.polygon = _create_circle(40, 16)
	outer_glow.color = glow_color * Color(1, 1, 1, 0.3)
	outer_glow.name = "OuterGlow"
	glow_container.add_child(outer_glow)

	# Medium glow
	var mid_glow = Polygon2D.new()
	mid_glow.polygon = _create_circle(25, 12)
	mid_glow.color = glow_color * Color(1, 1, 1, 0.5)
	mid_glow.name = "MidGlow"
	glow_container.add_child(mid_glow)

	# Inner bright glow
	var inner_glow = Polygon2D.new()
	inner_glow.polygon = _create_circle(12, 8)
	inner_glow.color = glow_color
	inner_glow.name = "InnerGlow"
	glow_container.add_child(inner_glow)

	# Pulse animation
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(glow_container, "scale", Vector2(1.2, 1.2), 0.6).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(glow_container, "scale", Vector2(0.9, 0.9), 0.6).set_ease(Tween.EASE_IN_OUT)

	# Also pulse the alpha
	var alpha_tween = create_tween()
	alpha_tween.set_loops()
	alpha_tween.tween_property(glow_container, "modulate:a", 0.7, 0.5)
	alpha_tween.tween_property(glow_container, "modulate:a", 1.0, 0.5)

	activity_indicators[waypoint] = glow_container

func _stop_activity_indicator(waypoint: int) -> void:
	## Stop and remove activity indicator
	if activity_indicators.has(waypoint):
		var indicator = activity_indicators[waypoint]
		if is_instance_valid(indicator):
			# Fade out before removing
			var tween = create_tween()
			tween.tween_property(indicator, "modulate:a", 0.0, 0.3)
			tween.tween_callback(indicator.queue_free)
		activity_indicators.erase(waypoint)

func _start_engine_work_animation(surface: Node2D, panel_pos: Vector2) -> void:
	## Engine work - welding sparks
	var anim_nodes: Array = []

	# Create spark emitter container
	var spark_container = Node2D.new()
	spark_container.position = panel_pos + Vector2(0, 5)
	spark_container.name = "EngineWorkAnim"
	surface.add_child(spark_container)
	anim_nodes.append(spark_container)

	# Welding light glow
	var glow = Polygon2D.new()
	glow.polygon = _create_circle(8, 8)
	glow.color = Color(1.0, 0.8, 0.3, 0.6)
	glow.name = "WeldGlow"
	spark_container.add_child(glow)

	# Animate the glow pulsing
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.15)
	glow_tween.tween_property(glow, "scale", Vector2(0.8, 0.8), 0.15)

	# Start spark emission timer
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(_emit_weld_spark.bind(spark_container))
	spark_container.add_child(timer)

	active_work_animations[ShipNavigation.Waypoint.EXTERIOR_ENGINE] = anim_nodes

func _emit_weld_spark(container: Node2D) -> void:
	## Emit a single welding spark
	if not is_instance_valid(container):
		return

	var spark = Polygon2D.new()
	spark.polygon = PackedVector2Array([
		Vector2(-1, -1), Vector2(1, -1),
		Vector2(1, 1), Vector2(-1, 1)
	])
	spark.color = Color(1.0, 0.9, 0.4)
	container.add_child(spark)

	# Random spark direction
	var angle = randf_range(0, TAU)
	var distance = randf_range(15, 30)
	var end_pos = Vector2(cos(angle), sin(angle)) * distance

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "position", end_pos, 0.3)
	tween.tween_property(spark, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(spark.queue_free)

func _start_antenna_work_animation(surface: Node2D, panel_pos: Vector2) -> void:
	## Antenna work - calibration gestures with dish movement
	var anim_nodes: Array = []

	# Create calibration indicator
	var indicator = Node2D.new()
	indicator.position = Vector2(0, -25)  # Above antenna dish
	indicator.name = "AntennaWorkAnim"
	surface.add_child(indicator)
	anim_nodes.append(indicator)

	# Signal indicator circles (like radio waves)
	for i in range(3):
		var ring = Line2D.new()
		var radius = 8 + i * 6
		for j in range(17):
			var angle = (float(j) / 16) * TAU
			ring.add_point(Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
		ring.width = 1.5
		ring.default_color = Color(0.3, 0.8, 0.3, 0.5 - i * 0.15)
		ring.name = "Ring%d" % i
		indicator.add_child(ring)

		# Animate rings pulsing
		var ring_tween = create_tween()
		ring_tween.set_loops()
		ring_tween.tween_interval(i * 0.2)  # Stagger
		ring_tween.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.5)
		ring_tween.tween_property(ring, "scale", Vector2(0.8, 0.8), 0.5)

	# Dish subtle rotation animation
	var dish_tween = create_tween()
	dish_tween.set_loops()
	dish_tween.tween_property(surface, "rotation", 0.1, 1.0).set_ease(Tween.EASE_IN_OUT)
	dish_tween.tween_property(surface, "rotation", -0.1, 1.0).set_ease(Tween.EASE_IN_OUT)
	dish_tween.tween_property(surface, "rotation", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT)

	active_work_animations[ShipNavigation.Waypoint.EXTERIOR_ANTENNA] = anim_nodes

func _start_solar_work_animation(surface: Node2D, panel_pos: Vector2) -> void:
	## Solar panel work - percussive maintenance (hitting the panel)
	var anim_nodes: Array = []

	# Impact indicator
	var impact = Node2D.new()
	impact.position = panel_pos
	impact.name = "SolarWorkAnim"
	surface.add_child(impact)
	anim_nodes.append(impact)

	# Start impact timer
	var timer = Timer.new()
	timer.wait_time = 0.8
	timer.autostart = true
	timer.timeout.connect(_do_solar_hit.bind(impact, surface))
	impact.add_child(timer)

	active_work_animations[ShipNavigation.Waypoint.EXTERIOR_SOLAR] = anim_nodes

func _do_solar_hit(impact_node: Node2D, surface: Node2D) -> void:
	## Create a hit impact effect on solar panel
	if not is_instance_valid(impact_node) or not is_instance_valid(surface):
		return

	# Impact flash
	var flash = Polygon2D.new()
	flash.polygon = _create_circle(6, 8)
	flash.color = Color(1.0, 1.0, 0.8, 0.8)
	impact_node.add_child(flash)

	# Flash animation
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.1)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.chain().tween_callback(flash.queue_free)

	# Panel shake
	var original_pos = surface.position
	var shake_tween = create_tween()
	shake_tween.tween_property(surface, "position", original_pos + Vector2(2, -1), 0.03)
	shake_tween.tween_property(surface, "position", original_pos + Vector2(-2, 1), 0.03)
	shake_tween.tween_property(surface, "position", original_pos, 0.04)

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
	## Create airlock door visual with dramatic effects (scaled down to not overlap cargo bay)
	var airlock_pos = ship_nav.get_waypoint_position(ShipNavigation.Waypoint.AIRLOCK)

	var airlock = Node2D.new()
	airlock.position = airlock_pos
	airlock.name = "Airlock"
	airlock.z_index = -2  # Behind ship rooms

	# OUTER RING - Heavy industrial frame (scaled down from 45 to 28)
	var outer_frame = Polygon2D.new()
	outer_frame.polygon = _create_circle(28, 16)
	outer_frame.color = Color(0.25, 0.25, 0.3)
	outer_frame.name = "OuterFrame"
	airlock.add_child(outer_frame)

	# Warning stripes ring
	var warning_ring = Line2D.new()
	for i in range(17):
		var angle = (float(i) / 16) * TAU
		warning_ring.add_point(Vector2(cos(angle) * 25, sin(angle) * 25))
	warning_ring.width = 4.0
	warning_ring.default_color = Color(0.9, 0.7, 0.1)
	warning_ring.name = "WarningRing"
	airlock.add_child(warning_ring)

	# Main hatch (circular) - scaled down from 35 to 22
	var hatch = Polygon2D.new()
	hatch.polygon = _create_circle(22, 14)
	hatch.color = Color(0.45, 0.45, 0.5)
	hatch.name = "Hatch"
	airlock.add_child(hatch)

	# Hatch inner ring with details
	var inner = Polygon2D.new()
	inner.polygon = _create_circle(17, 12)
	inner.color = Color(0.35, 0.35, 0.4)
	inner.name = "InnerRing"
	airlock.add_child(inner)

	# Center viewport window
	var viewport = Polygon2D.new()
	viewport.polygon = _create_circle(8, 10)
	viewport.color = Color(0.15, 0.2, 0.25)
	viewport.name = "Viewport"
	airlock.add_child(viewport)

	# Viewport glass reflection
	var glass = Polygon2D.new()
	glass.polygon = _create_circle(6, 10)
	glass.color = Color(0.3, 0.4, 0.5, 0.4)
	glass.name = "Glass"
	airlock.add_child(glass)

	# Locking bolts around the hatch (6 bolts, scaled down)
	for i in range(6):
		var angle = (float(i) / 6) * TAU
		var bolt = Polygon2D.new()
		bolt.polygon = _create_circle(3, 6)
		bolt.position = Vector2(cos(angle) * 20, sin(angle) * 20)
		bolt.color = Color(0.5, 0.5, 0.55)
		bolt.name = "Bolt%d" % i
		airlock.add_child(bolt)

	# Main handle wheel
	var handle_bg = Polygon2D.new()
	handle_bg.polygon = _create_circle(5, 8)
	handle_bg.color = Color(0.3, 0.3, 0.35)
	handle_bg.name = "HandleBg"
	airlock.add_child(handle_bg)

	var handle = Line2D.new()
	handle.add_point(Vector2(-4, 0))
	handle.add_point(Vector2(4, 0))
	handle.add_point(Vector2(0, 0))
	handle.add_point(Vector2(0, -4))
	handle.add_point(Vector2(0, 4))
	handle.width = 2.0
	handle.default_color = Color(0.8, 0.6, 0.2)
	handle.name = "Handle"
	airlock.add_child(handle)

	# AIRLOCK label - compact, above the hatch
	var label = Label.new()
	label.text = "◄ AIRLOCK ►"
	label.position = Vector2(-38, -45)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.name = "AirlockLabel"
	airlock.add_child(label)

	# Main status light (compact - combined into one)
	var status_light = Polygon2D.new()
	status_light.polygon = _create_circle(5, 8)
	status_light.position = Vector2(-35, 0)
	status_light.color = Color(0.2, 0.9, 0.2)  # Bright green = pressurized/safe
	status_light.name = "StatusLight"
	airlock.add_child(status_light)

	# Status light glow
	var status_glow = Polygon2D.new()
	status_glow.polygon = _create_circle(9, 8)
	status_glow.position = Vector2(-35, 0)
	status_glow.color = Color(0.2, 0.9, 0.2, 0.3)
	status_glow.name = "StatusGlow"
	status_glow.z_index = -1
	airlock.add_child(status_glow)

	# Pressure gauge - compact, below airlock
	var gauge_container = Node2D.new()
	gauge_container.position = Vector2(0, 38)
	gauge_container.name = "GaugeContainer"
	airlock.add_child(gauge_container)

	var gauge_bg = Polygon2D.new()
	gauge_bg.polygon = PackedVector2Array([
		Vector2(-22, -5), Vector2(22, -5),
		Vector2(22, 5), Vector2(-22, 5)
	])
	gauge_bg.color = Color(0.15, 0.15, 0.18)
	gauge_bg.name = "GaugeBg"
	gauge_container.add_child(gauge_bg)

	var gauge_fill = Polygon2D.new()
	gauge_fill.polygon = PackedVector2Array([
		Vector2(-20, -3), Vector2(20, -3),
		Vector2(20, 3), Vector2(-20, 3)
	])
	gauge_fill.color = Color(0.2, 0.7, 0.9)  # Blue = full pressure
	gauge_fill.name = "GaugeFill"
	gauge_container.add_child(gauge_fill)

	# Gauge label
	var gauge_label = Label.new()
	gauge_label.text = "PRESSURE"
	gauge_label.position = Vector2(-22, -16)
	gauge_label.add_theme_font_size_override("font_size", 8)
	gauge_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	gauge_container.add_child(gauge_label)

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
	## Start a full EVA sequence to an exterior location
	## This is an async function that handles all 4 phases:
	## 1. Interior transit (walk to cargo bay)
	## 2. Airlock sequence (suit up, exit)
	## 3. Exterior work (move to target, work)
	## 4. Return (back through airlock)

	print("[EVA-DEBUG] EVAController.start_eva: role=%s, target=%d (%s)" % [
		crew_role, target_waypoint, ShipNavigation.get_exterior_name(target_waypoint)])
	print("[EVA-DEBUG] ship_view is null: %s" % (ship_view == null))
	print("[EVA-DEBUG] ship_nav is null: %s" % (ship_nav == null))

	if active_eva.has(crew_role):
		print("[EVA-DEBUG] BLOCKED: %s already has active EVA" % crew_role)
		return

	if not ship_view:
		push_error("[EVA-DEBUG] CRITICAL: ship_view is NULL!")
		return

	var crew_member = ship_view.crew.get(crew_role)
	print("[EVA-DEBUG] crew_member for '%s' is null: %s" % [crew_role, crew_member == null])

	if not crew_member:
		push_error("[EVA-DEBUG] CRITICAL: No crew member found for role '%s'" % crew_role)
		print("[EVA-DEBUG] Available crew keys: %s" % str(ship_view.crew.keys()))
		return

	print("[EVA-DEBUG] Crew member found: %s at room %d" % [crew_member.name, crew_member.current_room])

	active_eva[crew_role] = {
		"target": target_waypoint,
		"phase": "interior_transit",
		"start_time": Time.get_ticks_msec(),
	}

	eva_started.emit(crew_role, target_waypoint)
	print("[EVA-DEBUG] eva_started signal emitted, starting async sequence...")

	# Run the full EVA sequence
	_run_eva_sequence(crew_role, target_waypoint)

func _run_eva_sequence(crew_role: String, target_waypoint: int) -> void:
	## Async function that runs the full EVA sequence
	print("[EVA-DEBUG] _run_eva_sequence STARTING for %s -> %d" % [crew_role, target_waypoint])

	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		push_error("[EVA-DEBUG] _run_eva_sequence: crew_member is NULL!")
		return

	# ========================================
	# PHASE 1: Interior Transit to Cargo Bay
	# ========================================
	active_eva[crew_role].phase = "interior_transit"
	print("[EVA-DEBUG] ===== PHASE 1: Interior Transit =====")
	print("[EVA-DEBUG] Crew current room: %d, target: CARGO_BAY (%d)" % [
		crew_member.current_room, ShipTypes.RoomType.CARGO_BAY])

	# Get path from current room to cargo bay
	var interior_path = ship_nav.find_path(crew_member.current_room, ShipTypes.RoomType.CARGO_BAY)
	print("[EVA-DEBUG] Path has %d waypoints" % interior_path.size())
	if interior_path.size() > 0:
		print("[EVA-DEBUG] Path: %s" % str(interior_path))

	if interior_path.size() > 0:
		print("[EVA-DEBUG] Calling move_along_path...")
		crew_member.move_along_path(ShipTypes.RoomType.CARGO_BAY, interior_path, null, false)
		print("[EVA-DEBUG] Waiting for arrived_at_destination signal...")

		# Wait for crew to arrive at cargo bay
		await crew_member.arrived_at_destination
		print("[EVA-DEBUG] arrived_at_destination signal received!")
	else:
		print("[EVA-DEBUG] Empty path - crew may already be at cargo bay")

	# Check if EVA was cancelled
	if not active_eva.has(crew_role):
		print("[EVA-DEBUG] EVA was cancelled during Phase 1")
		return

	# ========================================
	# PHASE 2: Airlock Sequence
	# ========================================
	print("[EVA-DEBUG] ===== PHASE 2: Airlock Sequence =====")
	active_eva[crew_role].phase = "airlock"
	await _begin_airlock_sequence(crew_role, target_waypoint)
	print("[EVA-DEBUG] Airlock sequence complete")

	# Check if EVA was cancelled or crew drifted
	if not active_eva.has(crew_role) or drifting_crew.has(crew_role):
		print("[EVA-DEBUG] EVA cancelled or crew drifted during Phase 2")
		return

	# ========================================
	# PHASE 3: Exterior Work
	# ========================================
	print("[EVA-DEBUG] ===== PHASE 3: Exterior Work =====")
	active_eva[crew_role].phase = "exterior_work"
	var drifted = await _begin_exterior_work(crew_role, target_waypoint)
	print("[EVA-DEBUG] Exterior work complete, drifted=%s" % drifted)

	# If crew drifted, the rescue system handles the rest
	if drifted or not active_eva.has(crew_role):
		print("[EVA-DEBUG] EVA ended due to drift or cancellation")
		return

	# ========================================
	# PHASE 4: Return through Airlock
	# ========================================
	print("[EVA-DEBUG] ===== PHASE 4: Return =====")
	active_eva[crew_role].phase = "returning"
	await _begin_return_sequence(crew_role)
	print("[EVA-DEBUG] ===== EVA SEQUENCE COMPLETE =====")

func _begin_airlock_sequence(crew_role: String, target_waypoint: int) -> void:
	## Phase 2: Suiting up and exiting through airlock
	print("[EVA-DEBUG] _begin_airlock_sequence starting...")
	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		push_error("[EVA-DEBUG] _begin_airlock_sequence: crew_member is NULL!")
		return

	# Move to airlock position within cargo bay
	var airlock_pos = ship_nav.get_waypoint_position(ShipNavigation.Waypoint.AIRLOCK)
	print("[EVA-DEBUG] Moving crew to airlock at %s" % str(airlock_pos))
	print("[EVA-DEBUG] Crew current position: %s" % str(crew_member.global_position))

	var tween = create_tween()
	tween.tween_property(crew_member, "global_position", airlock_pos, 0.8)
	await tween.finished
	print("[EVA-DEBUG] Crew arrived at airlock position")

	# Suiting up pause
	print("[EVA-DEBUG] Suiting up (1.5s pause)...")
	await get_tree().create_timer(1.5).timeout
	print("[EVA-DEBUG] Suited up!")

	# Animate airlock door open
	print("[EVA-DEBUG] Opening airlock door...")
	_animate_airlock_open()
	await get_tree().create_timer(0.3).timeout

	# Create tether from airlock to crew
	print("[EVA-DEBUG] Creating tether...")
	_create_tether(crew_role)

	# Apply EVA suit visuals
	print("[EVA-DEBUG] Applying EVA suit visuals...")
	_apply_eva_suit(crew_member)

	# Change crew to EVA state
	print("[EVA-DEBUG] Setting crew state to EVA...")
	crew_member.set_state(ShipTypes.CrewState.EVA)
	print("[EVA-DEBUG] Crew now in EVA state, tether attached, exiting airlock!")

func _begin_exterior_work(crew_role: String, target_waypoint: int) -> bool:
	## Phase 3: Move along hull to exterior target and work
	## Crew follows hull traversal path: AIRLOCK -> HULL_TOP -> (branch) -> destination
	## Returns true if crew drifted, false otherwise
	print("[EVA-DEBUG] _begin_exterior_work starting...")
	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		push_error("[EVA-DEBUG] _begin_exterior_work: crew_member is NULL!")
		return false

	# Get the hull traversal path from airlock to target
	var hull_path = ship_nav.find_eva_path(ShipTypes.RoomType.CARGO_BAY, target_waypoint)
	print("[EVA-DEBUG] Hull traversal path has %d waypoints" % hull_path.size())

	# EVA movement is slower and floaty
	var eva_speed = 30.0

	# Walk along hull path (skip first point which is airlock where we already are)
	for i in range(1, hull_path.size()):
		var next_pos = hull_path[i]
		var distance = crew_member.global_position.distance_to(next_pos)
		var duration = distance / eva_speed

		print("[EVA-DEBUG] EVA move to waypoint %d: distance=%.1f, duration=%.1fs" % [i, distance, duration])

		var tween = create_tween()
		tween.tween_property(crew_member, "global_position", next_pos, duration)
		await tween.finished

		# Check if EVA was cancelled
		if not active_eva.has(crew_role):
			return false

	print("[EVA-DEBUG] Arrived at exterior target: %s" % ShipNavigation.get_exterior_name(target_waypoint))

	# Work at target - use increased work time (6 seconds with 1s securing)
	print("[EVA-DEBUG] Securing position (1s)...")
	await get_tree().create_timer(1.0).timeout

	# Open maintenance panel
	print("[EVA-DEBUG] Opening maintenance panel...")
	open_maintenance_panel(target_waypoint)
	await get_tree().create_timer(0.3).timeout

	var work_time = ShipTypes.TASK_DURATIONS.get(ShipTypes.TaskType.EVA_REPAIR, 6.0)
	print("[EVA-DEBUG] Working on %s for %.1fs..." % [
		ShipNavigation.get_exterior_name(target_waypoint), work_time])

	# Start work animation
	_start_work_animation(target_waypoint)
	await get_tree().create_timer(work_time).timeout
	_stop_work_animation(target_waypoint)

	# Close maintenance panel
	print("[EVA-DEBUG] Closing maintenance panel...")
	close_maintenance_panel(target_waypoint)
	await get_tree().create_timer(0.3).timeout

	print("[EVA-DEBUG] Work complete!")

	# Check for drift
	print("[EVA-DEBUG] Checking for drift (15% chance)...")
	if check_for_drift(crew_role):
		print("[EVA-DEBUG] DRIFTED! Rescue sequence will handle return.")
		return true

	# Repair completed successfully - emit signal so exterior surface can be repaired
	print("[EVA-DEBUG] No drift - repair successful!")
	print("[EVA-DEBUG] Emitting eva_repair_completed signal...")
	eva_repair_completed.emit(target_waypoint)

	return false

func _begin_return_sequence(crew_role: String) -> void:
	## Phase 4: Return through airlock via hull path
	print("[EVA-DEBUG] _begin_return_sequence starting...")
	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		push_error("[EVA-DEBUG] _begin_return_sequence: crew_member is NULL!")
		return

	# Get the current target from active_eva to find return path
	var target_wp = active_eva[crew_role].get("target", ShipNavigation.Waypoint.EXTERIOR_ENGINE)

	# Get hull path and reverse it for return
	var hull_path = ship_nav.find_eva_path(ShipTypes.RoomType.CARGO_BAY, target_wp)
	hull_path.reverse()

	var return_speed = 35.0  # Slightly faster on return

	# Walk back along hull path (skip first point which is current position)
	for i in range(1, hull_path.size()):
		var next_pos = hull_path[i]
		var distance = crew_member.global_position.distance_to(next_pos)
		var duration = distance / return_speed

		print("[EVA-DEBUG] Return move to waypoint %d: distance=%.1f, duration=%.1fs" % [i, distance, duration])

		var tween = create_tween()
		tween.tween_property(crew_member, "global_position", next_pos, duration)
		await tween.finished

		# Check if EVA was cancelled
		if not active_eva.has(crew_role):
			return

	print("[EVA-DEBUG] Arrived at airlock!")

	# Animate airlock close
	print("[EVA-DEBUG] Closing airlock door...")
	_animate_airlock_close()
	await get_tree().create_timer(0.3).timeout

	# Removing suit pause
	print("[EVA-DEBUG] Removing suit (1.0s pause)...")
	await get_tree().create_timer(1.0).timeout
	print("[EVA-DEBUG] Suit removed!")

	# Complete EVA
	print("[EVA-DEBUG] Calling complete_eva...")
	complete_eva(crew_role, true)

func _animate_airlock_open() -> void:
	## Animate the airlock door opening with EPIC decompression effects
	var airlock_node = get_node_or_null("Airlock")
	if not airlock_node:
		return

	# ALL LIGHTS GO RED - EMERGENCY!
	var status_light = airlock_node.get_node_or_null("StatusLight")
	var status_glow = airlock_node.get_node_or_null("StatusGlow")
	if status_light:
		status_light.color = Color(1.0, 0.2, 0.1)  # BRIGHT RED
	if status_glow:
		status_glow.color = Color(1.0, 0.2, 0.1, 0.5)

	# Status light handled above - flash with warning ring

	# WARNING RING FLASHES
	var warning_ring = airlock_node.get_node_or_null("WarningRing")
	if warning_ring:
		var ring_tween = create_tween()
		ring_tween.set_loops(6)
		ring_tween.tween_property(warning_ring, "default_color", Color(1.0, 0.3, 0.0), 0.1)
		ring_tween.tween_property(warning_ring, "default_color", Color(0.9, 0.7, 0.1), 0.1)

	# Animate pressure gauge emptying DRAMATICALLY
	var gauge_container = airlock_node.get_node_or_null("GaugeContainer")
	var gauge_fill = gauge_container.get_node_or_null("GaugeFill") if gauge_container else null
	if gauge_fill:
		var gauge_tween = create_tween()
		gauge_tween.tween_property(gauge_fill, "scale", Vector2(0.0, 1.0), 1.2)
		gauge_tween.parallel().tween_property(gauge_fill, "color", Color(0.8, 0.2, 0.2), 1.2)

	# MASSIVE decompression particle effect
	_create_decompression_particles(airlock_node.global_position)

	# Flash the ENTIRE airlock with emergency lighting
	var flash_tween = create_tween()
	flash_tween.set_loops(4)
	flash_tween.tween_property(airlock_node, "modulate", Color(1.3, 0.8, 0.8), 0.15)
	flash_tween.tween_property(airlock_node, "modulate", Color(1.0, 1.0, 1.0), 0.15)

	# Rotate handle wheel as it unlocks
	var handle = airlock_node.get_node_or_null("Handle")
	if handle:
		var handle_tween = create_tween()
		handle_tween.tween_property(handle, "rotation", TAU, 0.8).set_ease(Tween.EASE_OUT)

	# Bolts retract (scale down)
	for i in range(6):
		var bolt = airlock_node.get_node_or_null("Bolt%d" % i)
		if bolt:
			var bolt_tween = create_tween()
			bolt_tween.tween_interval(i * 0.06)
			bolt_tween.tween_property(bolt, "scale", Vector2(0.3, 0.3), 0.2)

	# Open the hatch with dramatic swing
	var hatch = airlock_node.get_node_or_null("Hatch")
	var inner = airlock_node.get_node_or_null("InnerRing")
	var viewport = airlock_node.get_node_or_null("Viewport")
	if hatch:
		var tween = create_tween()
		tween.tween_interval(0.5)  # Wait for bolts
		tween.tween_property(hatch, "scale", Vector2(0.1, 1.0), 0.6).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(hatch, "position:x", -30, 0.6)
	if inner:
		var inner_tween = create_tween()
		inner_tween.tween_interval(0.5)
		inner_tween.tween_property(inner, "scale", Vector2(0.1, 1.0), 0.6)
		inner_tween.parallel().tween_property(inner, "position:x", -25, 0.6)
	if viewport:
		var vp_tween = create_tween()
		vp_tween.tween_interval(0.5)
		vp_tween.tween_property(viewport, "modulate:a", 0.0, 0.4)

func _animate_airlock_close() -> void:
	## Animate the airlock door closing with EPIC recompression effects
	var airlock_node = get_node_or_null("Airlock")
	if not airlock_node:
		return

	# SECURE THE HATCH - dramatic swing closed
	var hatch = airlock_node.get_node_or_null("Hatch")
	var inner = airlock_node.get_node_or_null("InnerRing")
	var viewport = airlock_node.get_node_or_null("Viewport")

	if hatch:
		var hatch_tween = create_tween()
		hatch_tween.tween_property(hatch, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN)
		hatch_tween.parallel().tween_property(hatch, "position:x", 0.0, 0.5)
	if inner:
		var inner_tween = create_tween()
		inner_tween.tween_property(inner, "scale", Vector2(1.0, 1.0), 0.5)
		inner_tween.parallel().tween_property(inner, "position:x", 0.0, 0.5)
	if viewport:
		var vp_tween = create_tween()
		vp_tween.tween_property(viewport, "modulate:a", 1.0, 0.3)

	# Rotate handle wheel to LOCK
	var handle = airlock_node.get_node_or_null("Handle")
	if handle:
		var handle_tween = create_tween()
		handle_tween.tween_interval(0.4)
		handle_tween.tween_property(handle, "rotation", TAU * 2, 0.8).set_ease(Tween.EASE_OUT)

	# BOLTS SLAM BACK INTO PLACE - staggered for drama
	for i in range(6):
		var bolt = airlock_node.get_node_or_null("Bolt%d" % i)
		if bolt:
			var bolt_tween = create_tween()
			bolt_tween.tween_interval(0.5 + i * 0.1)
			bolt_tween.tween_property(bolt, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
			# Bolt flash on engage
			bolt_tween.parallel().tween_property(bolt, "color", Color(0.8, 0.8, 0.3), 0.1)
			bolt_tween.tween_property(bolt, "color", Color(0.5, 0.5, 0.55), 0.2)

	# SEAL CONFIRMED - status light turns green after bolts engage

	# REPRESSURIZATION - the gauge fills with satisfying drama
	var gauge_container = airlock_node.get_node_or_null("GaugeContainer")
	var gauge_fill = gauge_container.get_node_or_null("GaugeFill") if gauge_container else null
	if gauge_fill:
		var gauge_tween = create_tween()
		gauge_tween.tween_interval(0.5)
		# Color shift: red -> yellow -> cyan as pressure builds
		gauge_tween.tween_property(gauge_fill, "color", Color(0.8, 0.4, 0.2), 0.4)
		gauge_tween.parallel().tween_property(gauge_fill, "scale", Vector2(0.4, 1.0), 0.4)
		gauge_tween.tween_property(gauge_fill, "color", Color(0.9, 0.7, 0.2), 0.4)
		gauge_tween.parallel().tween_property(gauge_fill, "scale", Vector2(0.7, 1.0), 0.4)
		gauge_tween.tween_property(gauge_fill, "color", Color(0.2, 0.7, 0.9), 0.4)
		gauge_tween.parallel().tween_property(gauge_fill, "scale", Vector2(1.0, 1.0), 0.4)

	# REPRESSURIZATION PARTICLES - air rushing back in
	_create_repressurization_particles(airlock_node.global_position)

	# Main status light: RED -> YELLOW (cycling) -> GREEN
	var status_light = airlock_node.get_node_or_null("StatusLight")
	var status_glow = airlock_node.get_node_or_null("StatusGlow")
	if status_light:
		# Start with cycling yellow
		var cycle_tween = create_tween()
		cycle_tween.set_loops(4)
		cycle_tween.tween_property(status_light, "color", Color(0.9, 0.7, 0.2), 0.2)
		cycle_tween.tween_property(status_light, "color", Color(0.6, 0.4, 0.1), 0.2)

		# After cycling, go solid green
		var final_tween = create_tween()
		final_tween.tween_interval(1.8)
		final_tween.tween_property(status_light, "color", Color(0.2, 0.95, 0.2), 0.3)

	if status_glow:
		var glow_tween = create_tween()
		glow_tween.tween_interval(1.8)
		glow_tween.tween_property(status_glow, "color", Color(0.2, 0.95, 0.2, 0.4), 0.3)

	# Warning ring stops flashing, returns to normal
	var warning_ring = airlock_node.get_node_or_null("WarningRing")
	if warning_ring:
		var ring_tween = create_tween()
		ring_tween.tween_interval(2.0)
		ring_tween.tween_property(warning_ring, "default_color", Color(0.9, 0.7, 0.1), 0.3)

	# Flash the whole airlock with "SAFE" green lighting
	var safe_tween = create_tween()
	safe_tween.tween_interval(2.0)
	safe_tween.tween_property(airlock_node, "modulate", Color(0.9, 1.1, 0.9), 0.3)
	safe_tween.tween_property(airlock_node, "modulate", Color(1.0, 1.0, 1.0), 0.3)

func _create_repressurization_particles(pos: Vector2) -> void:
	## Create visual effect of air rushing BACK into airlock
	for i in range(10):
		var particle = Polygon2D.new()
		particle.polygon = _create_circle(2, 6)
		particle.color = Color(0.6, 0.8, 0.95, 0.5)

		# Start from outside, rush inward
		var angle = randf_range(-PI * 0.5, PI * 0.5) - PI / 2
		var start_offset = Vector2(cos(angle), sin(angle)) * randf_range(50, 90)
		particle.global_position = pos + start_offset
		add_child(particle)

		# Rush toward center
		var duration = randf_range(0.4, 0.7)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration * 0.8)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), duration)
		tween.chain().tween_callback(particle.queue_free)

func _create_decompression_particles(pos: Vector2) -> void:
	## Create visual effect of air venting from airlock
	# Create multiple small particles that drift outward
	for i in range(8):
		var particle = Polygon2D.new()
		particle.polygon = _create_circle(2, 6)
		particle.color = Color(0.7, 0.8, 0.9, 0.6)
		particle.global_position = pos
		add_child(particle)

		# Random outward direction (biased left since airlock opens to space)
		var angle = randf_range(-PI * 0.7, PI * 0.7) - PI / 2
		var direction = Vector2(cos(angle), sin(angle))
		var distance = randf_range(40, 80)
		var duration = randf_range(0.5, 1.0)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + direction * distance, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), duration)
		tween.chain().tween_callback(particle.queue_free)

# ============================================================================
# EVA SUIT VISUALS
# ============================================================================

func _apply_eva_suit(crew_member: Node2D) -> void:
	## Apply EVA suit visuals - white tint and helmet overlay
	if not crew_member:
		return

	# Store original modulate for restoration
	if not crew_member.has_meta("original_modulate"):
		crew_member.set_meta("original_modulate", crew_member.modulate)

	# Apply white suit tint
	crew_member.modulate = Color(0.95, 0.95, 1.0)

	# Add helmet overlay if not already present
	if not crew_member.has_node("EVAHelmet"):
		var helmet = _create_helmet_visual()
		crew_member.add_child(helmet)

	# Add backpack/life support unit
	if not crew_member.has_node("EVABackpack"):
		var backpack = _create_backpack_visual()
		crew_member.add_child(backpack)

func _remove_eva_suit(crew_member: Node2D) -> void:
	## Remove EVA suit visuals and restore original appearance
	if not crew_member:
		return

	# Restore original modulate
	if crew_member.has_meta("original_modulate"):
		crew_member.modulate = crew_member.get_meta("original_modulate")
		crew_member.remove_meta("original_modulate")
	else:
		crew_member.modulate = Color.WHITE

	# Remove helmet
	var helmet = crew_member.get_node_or_null("EVAHelmet")
	if helmet:
		helmet.queue_free()

	# Remove backpack
	var backpack = crew_member.get_node_or_null("EVABackpack")
	if backpack:
		backpack.queue_free()

func _create_helmet_visual() -> Node2D:
	## Create a programmatic helmet overlay
	var helmet_container = Node2D.new()
	helmet_container.name = "EVAHelmet"
	helmet_container.z_index = 1  # Above crew sprite

	# Helmet dome (rounded rectangle-ish)
	var dome = Polygon2D.new()
	dome.polygon = PackedVector2Array([
		Vector2(-7, -14), Vector2(7, -14),   # Top
		Vector2(9, -10), Vector2(9, -2),      # Right side upper
		Vector2(7, 2), Vector2(-7, 2),        # Bottom
		Vector2(-9, -2), Vector2(-9, -10),    # Left side upper
	])
	dome.color = Color(0.85, 0.85, 0.9, 0.95)  # Light grey/white helmet
	helmet_container.add_child(dome)

	# Visor (golden reflective)
	var visor = Polygon2D.new()
	visor.polygon = PackedVector2Array([
		Vector2(-5, -11), Vector2(5, -11),
		Vector2(6, -6), Vector2(6, -2),
		Vector2(-6, -2), Vector2(-6, -6),
	])
	visor.color = Color(0.9, 0.75, 0.3, 0.85)  # Golden visor
	helmet_container.add_child(visor)

	# Visor reflection highlight
	var highlight = Line2D.new()
	highlight.add_point(Vector2(-4, -9))
	highlight.add_point(Vector2(2, -9))
	highlight.width = 1.5
	highlight.default_color = Color(1.0, 1.0, 1.0, 0.6)
	helmet_container.add_child(highlight)

	return helmet_container

func _create_backpack_visual() -> Node2D:
	## Create a life support backpack visual
	var backpack_container = Node2D.new()
	backpack_container.name = "EVABackpack"
	backpack_container.z_index = -1  # Behind crew sprite

	# Main backpack body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-6, -8), Vector2(0, -8),
		Vector2(0, 6), Vector2(-6, 6),
	])
	body.position = Vector2(-4, 0)  # Offset to back
	body.color = Color(0.7, 0.7, 0.75)
	backpack_container.add_child(body)

	# Oxygen tank (small cylinder)
	var tank = Polygon2D.new()
	tank.polygon = PackedVector2Array([
		Vector2(-2, -6), Vector2(2, -6),
		Vector2(2, 4), Vector2(-2, 4),
	])
	tank.position = Vector2(-8, 0)
	tank.color = Color(0.3, 0.5, 0.7)  # Blue oxygen tank
	backpack_container.add_child(tank)

	return backpack_container

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

func _process(_delta: float) -> void:
	# Update visual elements only (tethers)
	for role in active_eva:
		_update_tether(role)

func _physics_process(delta: float) -> void:
	# Process drift physics in physics_process for framerate-independent behavior
	for role in drifting_crew.keys():  # Use .keys() to avoid modification during iteration
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

	# Remove EVA suit visuals and send crew back to their home room
	var crew_member = ship_view.crew.get(crew_role)
	if crew_member:
		# Remove EVA suit
		_remove_eva_suit(crew_member)

		# Send to home room
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

	# Bias away from ship center (with null check)
	var layout_center = ship_view.layout_center if ship_view and "layout_center" in ship_view else crew_member.global_position
	if layout_center != Vector2.ZERO:
		var to_center = (layout_center - crew_member.global_position).normalized()
		if to_center.length() > 0.001:  # Avoid NaN from zero vector
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

			# Use epsilon for floating point comparison to avoid precision issues
			if drift.distance <= 0.5:  # Small tolerance
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
# SAVE/LOAD STATE
# ============================================================================

func save_eva_state() -> Dictionary:
	## Save current EVA state for persistence
	var state = {
		"active_eva": {},
		"drifting_crew": {},
	}

	# Save active EVA state (excluding visual references)
	for role in active_eva:
		var eva = active_eva[role]
		state.active_eva[role] = {
			"target": eva.get("target", 0),
			"phase": eva.get("phase", ""),
			"start_time": eva.get("start_time", 0),
		}

	# Save drifting crew state
	for role in drifting_crew:
		var drift = drifting_crew[role]
		state.drifting_crew[role] = {
			"direction": {"x": drift.direction.x, "y": drift.direction.y},
			"distance": drift.distance,
			"max_distance": drift.max_distance,
			"phase": drift.phase,
			"rescuer": drift.rescuer,
		}

	return state

func load_eva_state(state: Dictionary) -> void:
	## Restore EVA state from saved data
	# Note: This should be called after ship_view and ship_nav are set up

	# Restore active EVA (visual elements will need recreation)
	active_eva = {}
	for role in state.get("active_eva", {}):
		var eva_data = state.active_eva[role]
		active_eva[role] = {
			"target": eva_data.get("target", 0),
			"phase": eva_data.get("phase", ""),
			"start_time": eva_data.get("start_time", 0),
		}

		# Recreate tether if crew is on EVA
		var crew_member = ship_view.crew.get(role) if ship_view else null
		if crew_member:
			_create_tether(role)
			_apply_eva_suit(crew_member)

	# Restore drifting crew
	drifting_crew = {}
	for role in state.get("drifting_crew", {}):
		var drift_data = state.drifting_crew[role]
		drifting_crew[role] = {
			"direction": Vector2(drift_data.direction.x, drift_data.direction.y),
			"distance": drift_data.distance,
			"max_distance": drift_data.max_distance,
			"phase": drift_data.phase,
			"rescuer": drift_data.rescuer,
		}

func has_active_eva() -> bool:
	## Check if any EVA is currently in progress
	return active_eva.size() > 0 or drifting_crew.size() > 0

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

func get_active_eva_crew() -> Array:
	## Get list of crew roles currently on EVA
	return active_eva.keys()

func _force_emergency_return(crew_role: String) -> void:
	## Force an immediate emergency return for crew on EVA
	## Used for solar flare radiation exposure, etc.
	if not active_eva.has(crew_role):
		return

	print("[EVA] EMERGENCY: %s forced return initiated!" % crew_role.capitalize())

	var crew_member = ship_view.crew.get(crew_role)
	if not crew_member:
		return

	# Stop any work animations
	var target = active_eva[crew_role].get("target", ShipNavigation.Waypoint.EXTERIOR_ENGINE)
	_stop_work_animation(target)
	close_maintenance_panel(target)

	# Set phase to emergency return
	active_eva[crew_role].phase = "emergency_return"

	# Immediately move to airlock (faster than normal return)
	var airlock_pos = ship_nav.get_waypoint_position(ShipNavigation.Waypoint.AIRLOCK)
	var emergency_speed = 60.0  # Fast emergency return

	var tween = create_tween()
	var distance = crew_member.global_position.distance_to(airlock_pos)
	var duration = distance / emergency_speed
	tween.tween_property(crew_member, "global_position", airlock_pos, duration)
	tween.tween_callback(_complete_emergency_return.bind(crew_role))

func _complete_emergency_return(crew_role: String) -> void:
	## Complete emergency return after reaching airlock
	print("[EVA] %s emergency return complete - entering airlock!" % crew_role.capitalize())

	# Animate airlock close
	_animate_airlock_close()

	# Complete EVA (marked as unsuccessful due to emergency)
	complete_eva(crew_role, false)
