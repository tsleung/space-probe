extends Node2D
class_name LifeSupportSystems

## Life Support Systems Manager - Ship Resource Regeneration
## Manages the closed-loop life support systems on the ship:
## - Hydroponics (Potato Farm): Power -> Food production
## - Water Reclaimer: Recycled water loop, efficiency-based
## - Solar Panels: Power generation (affected by orientation/damage)
## - CO2 Scrubber: Oxygen regeneration from waste CO2

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal food_produced(amount: float)
signal water_recycled(efficiency: float)
signal power_generated(amount: float)
signal oxygen_generated(amount: float)
signal system_damaged(system_name: String)
signal system_repaired(system_name: String)
signal hydroponics_light_changed(level: int)  # 0-3 power levels

# ============================================================================
# CONSTANTS - Balance values
# ============================================================================

# Hydroponics (Potato Farm)
# BALANCE: 4 crew consume ~0.167 food/hr. At NORMAL we produce ~0.21 food/hr = sustainable
const HYDROPONICS_POWER_LEVELS = {
	0: {"power": 0, "yield_per_hour": 0.0, "name": "OFF", "color": Color(0.2, 0.2, 0.2)},
	1: {"power": 2, "yield_per_hour": 0.05, "name": "LOW", "color": Color(0.4, 0.5, 0.3)},
	2: {"power": 5, "yield_per_hour": 0.10, "name": "NORMAL", "color": Color(0.5, 0.7, 0.3)},
	3: {"power": 10, "yield_per_hour": 0.20, "name": "HIGH", "color": Color(0.6, 0.9, 0.4)}
}
const HYDROPONICS_GROWTH_CYCLE_HOURS = 72  # 3 days to mature
const HYDROPONICS_HARVEST_AMOUNT = 8.0  # Food units per harvest (balanced for 4 crew)

# Water Reclaimer
const WATER_RECLAIMER_BASE_EFFICIENCY = 0.92  # 92% water recycled when healthy
const WATER_RECLAIMER_DAMAGED_EFFICIENCY = 0.60  # 60% when damaged
const WATER_RECLAIMER_POWER_CONSUMPTION = 3  # Power per hour when active

# Solar Panels (Power Generation)
const SOLAR_PANEL_BASE_OUTPUT = 15.0  # Power units per hour at 100% health
const SOLAR_PANEL_DAMAGED_OUTPUT = 5.0  # Power when severely damaged
const SOLAR_PANEL_MIN_HEALTH_FOR_FUNCTION = 10.0  # Below this = no output

# CO2 Scrubber (Oxygen Regeneration)
const CO2_SCRUBBER_BASE_OUTPUT = 0.8  # Oxygen units per hour at 100%
const CO2_SCRUBBER_DAMAGED_OUTPUT = 0.3  # When damaged
const CO2_SCRUBBER_POWER_CONSUMPTION = 4  # Power per hour when active

# ============================================================================
# STATE
# ============================================================================

# Hydroponics state
var hydroponics_enabled: bool = true
var hydroponics_power_level: int = 2  # 0=OFF, 1=LOW, 2=NORMAL, 3=HIGH
var hydroponics_health: float = 100.0  # 0-100
var hydroponics_growth_progress: float = 0.0  # 0.0 to HYDROPONICS_GROWTH_CYCLE_HOURS

# Water reclaimer state
var water_reclaimer_enabled: bool = true
var water_reclaimer_health: float = 100.0  # 0-100
var water_reclaimer_flow_rate: float = 1.0  # Visual flow speed

# Solar panels state
var solar_panels_enabled: bool = true
var solar_panels_health: float = 100.0  # 0-100
var solar_panel_orientation: float = 1.0  # 0-1, affects output (sun angle)

# CO2 scrubber state
var co2_scrubber_enabled: bool = true
var co2_scrubber_health: float = 100.0  # 0-100

# Idle crew efficiency boost
const IDLE_CREW_BOOST = 0.10  # 10% efficiency boost per idle crew member
var idle_crew_in_hydroponics: int = 0
var idle_crew_in_life_support: int = 0

# Visual nodes
var hydroponics_visual: Node2D = null
var water_reclaimer_visual: Node2D = null
var solar_panel_visual: Node2D = null
var co2_scrubber_visual: Node2D = null

# Position in Life Support room
var position_offset: Vector2 = Vector2.ZERO

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	z_index = 3

func setup(life_support_position: Vector2) -> void:
	## Legacy: setup both systems in the same room
	position_offset = life_support_position
	_create_hydroponics_visual(Vector2(-40, -20))
	_create_water_reclaimer_visual(Vector2(35, -15))

func setup_separate(hydroponics_position: Vector2, water_reclaimer_position: Vector2) -> void:
	## Setup hydroponics and water reclaimer in separate rooms
	_create_hydroponics_visual_at(hydroponics_position)
	_create_water_reclaimer_visual_at(water_reclaimer_position)

# ============================================================================
# VISUAL CREATION
# ============================================================================

func _create_hydroponics_visual(offset: Vector2) -> void:
	## Create the hydroponics bay (potato farm) visual with offset from position_offset
	_create_hydroponics_visual_at(position_offset + offset)

func _create_hydroponics_visual_at(pos: Vector2) -> void:
	## Create the hydroponics bay (potato farm) visual at absolute position
	hydroponics_visual = Node2D.new()
	hydroponics_visual.name = "Hydroponics"
	hydroponics_visual.position = pos

	# Growing tray container
	var tray = Polygon2D.new()
	tray.polygon = PackedVector2Array([
		Vector2(-25, -15), Vector2(25, -15),
		Vector2(28, 10), Vector2(-28, 10)
	])
	tray.color = Color(0.25, 0.3, 0.2)
	tray.name = "GrowTray"
	hydroponics_visual.add_child(tray)

	# Soil/growing medium
	var soil = Polygon2D.new()
	soil.polygon = PackedVector2Array([
		Vector2(-23, -10), Vector2(23, -10),
		Vector2(23, 5), Vector2(-23, 5)
	])
	soil.color = Color(0.35, 0.25, 0.15)
	soil.name = "Soil"
	hydroponics_visual.add_child(soil)

	# Potato plants (multiple small sprouts)
	for i in range(5):
		var plant = _create_potato_plant(i)
		plant.position = Vector2(-18 + i * 9, -5)
		plant.name = "Plant%d" % i
		hydroponics_visual.add_child(plant)

	# Grow light bar
	var light_bar = Polygon2D.new()
	light_bar.polygon = PackedVector2Array([
		Vector2(-22, -22), Vector2(22, -22),
		Vector2(22, -18), Vector2(-22, -18)
	])
	light_bar.color = Color(0.3, 0.3, 0.35)
	light_bar.name = "LightBar"
	hydroponics_visual.add_child(light_bar)

	# Light glow (changes color based on power level)
	var light_glow = Polygon2D.new()
	light_glow.polygon = PackedVector2Array([
		Vector2(-20, -20), Vector2(20, -20),
		Vector2(20, -8), Vector2(-20, -8)
	])
	light_glow.color = HYDROPONICS_POWER_LEVELS[hydroponics_power_level].color
	light_glow.color.a = 0.4
	light_glow.name = "LightGlow"
	light_glow.z_index = -1
	hydroponics_visual.add_child(light_glow)

	# Label
	var label = Label.new()
	label.text = "HYDROPONICS"
	label.position = Vector2(-32, 12)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	hydroponics_visual.add_child(label)

	# Power indicator
	var power_label = Label.new()
	power_label.text = "PWR: %s" % HYDROPONICS_POWER_LEVELS[hydroponics_power_level].name
	power_label.position = Vector2(-32, 22)
	power_label.add_theme_font_size_override("font_size", 7)
	power_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.4))
	power_label.name = "PowerLabel"
	hydroponics_visual.add_child(power_label)

	# Progress bar background
	var progress_bg = Polygon2D.new()
	progress_bg.polygon = PackedVector2Array([
		Vector2(-25, 32), Vector2(25, 32),
		Vector2(25, 36), Vector2(-25, 36)
	])
	progress_bg.color = Color(0.2, 0.2, 0.2)
	progress_bg.name = "ProgressBg"
	hydroponics_visual.add_child(progress_bg)

	# Progress bar fill
	var progress_fill = Polygon2D.new()
	progress_fill.polygon = PackedVector2Array([
		Vector2(-24, 33), Vector2(-24, 33),
		Vector2(-24, 35), Vector2(-24, 35)
	])
	progress_fill.color = Color(0.4, 0.7, 0.3)
	progress_fill.name = "ProgressFill"
	hydroponics_visual.add_child(progress_fill)

	add_child(hydroponics_visual)

func _create_potato_plant(index: int) -> Node2D:
	var plant = Node2D.new()

	# Stem
	var stem = Line2D.new()
	stem.add_point(Vector2(0, 8))
	stem.add_point(Vector2(0, 0))
	stem.width = 2.0
	stem.default_color = Color(0.3, 0.5, 0.2)
	plant.add_child(stem)

	# Leaves (simple triangles)
	var leaf1 = Polygon2D.new()
	leaf1.polygon = PackedVector2Array([
		Vector2(0, 2), Vector2(-4, 0), Vector2(0, -2)
	])
	leaf1.color = Color(0.35, 0.55, 0.25)
	plant.add_child(leaf1)

	var leaf2 = Polygon2D.new()
	leaf2.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(4, -2), Vector2(0, -4)
	])
	leaf2.color = Color(0.4, 0.6, 0.3)
	plant.add_child(leaf2)

	return plant

func _create_water_reclaimer_visual(offset: Vector2) -> void:
	## Create the water reclaimer visual with offset from position_offset
	_create_water_reclaimer_visual_at(position_offset + offset)

func _create_water_reclaimer_visual_at(pos: Vector2) -> void:
	## Create the water reclaimer visual at absolute position
	water_reclaimer_visual = Node2D.new()
	water_reclaimer_visual.name = "WaterReclaimer"
	water_reclaimer_visual.position = pos

	# Main tank
	var tank = Polygon2D.new()
	tank.polygon = PackedVector2Array([
		Vector2(-15, -25), Vector2(15, -25),
		Vector2(18, -20), Vector2(18, 20),
		Vector2(15, 25), Vector2(-15, 25),
		Vector2(-18, 20), Vector2(-18, -20)
	])
	tank.color = Color(0.3, 0.35, 0.4)
	tank.name = "Tank"
	water_reclaimer_visual.add_child(tank)

	# Water level (shows current efficiency)
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0),
		Vector2(14, 20), Vector2(-14, 20)
	])
	water.color = Color(0.3, 0.5, 0.7, 0.7)
	water.name = "WaterLevel"
	water_reclaimer_visual.add_child(water)

	# Recycling flow pipes (inlet)
	var pipe_in = Polygon2D.new()
	pipe_in.polygon = PackedVector2Array([
		Vector2(-25, -18), Vector2(-18, -18),
		Vector2(-18, -14), Vector2(-25, -14)
	])
	pipe_in.color = Color(0.4, 0.4, 0.45)
	water_reclaimer_visual.add_child(pipe_in)

	# Recycling flow pipes (outlet)
	var pipe_out = Polygon2D.new()
	pipe_out.polygon = PackedVector2Array([
		Vector2(18, -18), Vector2(25, -18),
		Vector2(25, -14), Vector2(18, -14)
	])
	pipe_out.color = Color(0.4, 0.4, 0.45)
	water_reclaimer_visual.add_child(pipe_out)

	# Flow indicator (animated dots)
	for i in range(3):
		var flow_dot = Polygon2D.new()
		flow_dot.polygon = _create_circle(2, 6)
		flow_dot.color = Color(0.4, 0.6, 0.8, 0.8)
		flow_dot.position = Vector2(-22 + i * 5, -16)
		flow_dot.name = "FlowDot%d" % i
		water_reclaimer_visual.add_child(flow_dot)

	# Efficiency gauge
	var gauge_bg = Polygon2D.new()
	gauge_bg.polygon = PackedVector2Array([
		Vector2(-12, -22), Vector2(12, -22),
		Vector2(12, -19), Vector2(-12, -19)
	])
	gauge_bg.color = Color(0.15, 0.15, 0.18)
	gauge_bg.name = "GaugeBg"
	water_reclaimer_visual.add_child(gauge_bg)

	var gauge_fill = Polygon2D.new()
	gauge_fill.polygon = PackedVector2Array([
		Vector2(-11, -21), Vector2(11, -21),
		Vector2(11, -20), Vector2(-11, -20)
	])
	gauge_fill.color = Color(0.3, 0.7, 0.9)
	gauge_fill.name = "GaugeFill"
	water_reclaimer_visual.add_child(gauge_fill)

	# Status light
	var status_light = Polygon2D.new()
	status_light.polygon = _create_circle(4, 8)
	status_light.position = Vector2(0, -30)
	status_light.color = Color(0.3, 0.9, 0.3)  # Green = healthy
	status_light.name = "StatusLight"
	water_reclaimer_visual.add_child(status_light)

	# Label
	var label = Label.new()
	label.text = "WATER RECLAIMER"
	label.position = Vector2(-42, 28)
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.7))
	water_reclaimer_visual.add_child(label)

	# Efficiency label
	var eff_label = Label.new()
	eff_label.text = "EFF: 92%"
	eff_label.position = Vector2(-18, 38)
	eff_label.add_theme_font_size_override("font_size", 8)
	eff_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	eff_label.name = "EfficiencyLabel"
	water_reclaimer_visual.add_child(eff_label)

	add_child(water_reclaimer_visual)

	# Start flow animation
	_animate_water_flow()

func _create_circle(radius: float, segments: int = 12) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_water_flow() -> void:
	## Animate the water flow dots
	if not water_reclaimer_visual:
		return

	var flow_tween = create_tween()
	flow_tween.set_loops()

	for i in range(3):
		var dot = water_reclaimer_visual.get_node_or_null("FlowDot%d" % i)
		if dot:
			var dot_tween = create_tween()
			dot_tween.set_loops()
			dot_tween.tween_interval(i * 0.3)
			dot_tween.tween_property(dot, "position:x", 22.0, 1.0)
			dot_tween.tween_property(dot, "position:x", -22.0, 0.0)

func _animate_plant_growth() -> void:
	## Subtle plant growth animation
	if not hydroponics_visual:
		return

	for i in range(5):
		var plant = hydroponics_visual.get_node_or_null("Plant%d" % i)
		if plant:
			var scale_factor = 0.5 + (hydroponics_growth_progress / HYDROPONICS_GROWTH_CYCLE_HOURS) * 0.5
			plant.scale = Vector2(scale_factor, scale_factor)

# ============================================================================
# HOURLY UPDATE (called by store/reducer)
# ============================================================================

func process_hour(current_power: float) -> Dictionary:
	## Process one hour of life support operation
	## Returns: {food_produced, water_efficiency, power_consumed, power_generated, oxygen_produced}
	var result = {
		"food_produced": 0.0,
		"water_efficiency": get_current_water_efficiency(),
		"power_consumed": 0.0,
		"power_generated": 0.0,
		"oxygen_produced": 0.0
	}

	# SOLAR PANELS - Generate power first (before consumption)
	if solar_panels_enabled and solar_panels_health > SOLAR_PANEL_MIN_HEALTH_FOR_FUNCTION:
		var health_factor = solar_panels_health / 100.0
		var base_output = SOLAR_PANEL_DAMAGED_OUTPUT + \
			(SOLAR_PANEL_BASE_OUTPUT - SOLAR_PANEL_DAMAGED_OUTPUT) * health_factor
		result.power_generated = base_output * solar_panel_orientation
		power_generated.emit(result.power_generated)

	# Available power = current_power + newly generated
	var available_power = current_power + result.power_generated

	# Hydroponics processing
	if hydroponics_enabled and hydroponics_health > 20:
		var level_config = HYDROPONICS_POWER_LEVELS[hydroponics_power_level]
		var power_needed = level_config.power

		if available_power >= power_needed:
			result.power_consumed += power_needed

			# Grow potatoes (health affects growth rate, idle crew boosts)
			var health_factor = hydroponics_health / 100.0
			var crew_boost = get_hydroponics_boost()
			var growth_rate = level_config.yield_per_hour * health_factor * crew_boost
			hydroponics_growth_progress += 1.0  # 1 hour of growth

			# Check for harvest
			if hydroponics_growth_progress >= HYDROPONICS_GROWTH_CYCLE_HOURS:
				hydroponics_growth_progress = 0.0
				result.food_produced = HYDROPONICS_HARVEST_AMOUNT * health_factor * crew_boost
				food_produced.emit(result.food_produced)
				_show_harvest_effect()
			else:
				# Small continuous yield (boosted by idle crew)
				result.food_produced = growth_rate
				if result.food_produced > 0:
					food_produced.emit(result.food_produced)

			_update_growth_visual()

	# Water reclaimer processing
	if water_reclaimer_enabled:
		result.power_consumed += WATER_RECLAIMER_POWER_CONSUMPTION
		water_recycled.emit(result.water_efficiency)

	# CO2 SCRUBBER - Oxygen regeneration
	if co2_scrubber_enabled and co2_scrubber_health > 20:
		if available_power >= result.power_consumed + CO2_SCRUBBER_POWER_CONSUMPTION:
			result.power_consumed += CO2_SCRUBBER_POWER_CONSUMPTION
			var health_factor = co2_scrubber_health / 100.0
			var oxygen_output = CO2_SCRUBBER_DAMAGED_OUTPUT + \
				(CO2_SCRUBBER_BASE_OUTPUT - CO2_SCRUBBER_DAMAGED_OUTPUT) * health_factor
			result.oxygen_produced = oxygen_output
			oxygen_generated.emit(result.oxygen_produced)

	_update_visuals()
	return result

func get_current_water_efficiency() -> float:
	## Get current water recycling efficiency based on health and idle crew
	if not water_reclaimer_enabled or water_reclaimer_health <= 0:
		return 0.0

	var health_factor = water_reclaimer_health / 100.0
	var crew_boost = get_water_reclaimer_boost()
	var base_eff = WATER_RECLAIMER_DAMAGED_EFFICIENCY + \
		(WATER_RECLAIMER_BASE_EFFICIENCY - WATER_RECLAIMER_DAMAGED_EFFICIENCY) * health_factor

	# Cap at 98% efficiency (can't be 100%)
	return min(base_eff * crew_boost, 0.98)

func get_current_power_consumption() -> float:
	## Get current power consumption per hour
	var power = 0.0
	if hydroponics_enabled and hydroponics_health > 20:
		power += HYDROPONICS_POWER_LEVELS[hydroponics_power_level].power
	if water_reclaimer_enabled:
		power += WATER_RECLAIMER_POWER_CONSUMPTION
	return power

# ============================================================================
# IDLE CREW PRODUCTIVITY
# ============================================================================

func set_idle_crew_counts(hydroponics_count: int, life_support_count: int) -> void:
	## Update the count of idle crew helping with each system
	## Called by ship_view or controller when crew positions change
	idle_crew_in_hydroponics = hydroponics_count
	idle_crew_in_life_support = life_support_count

func get_hydroponics_boost() -> float:
	## Get efficiency multiplier from idle crew helping in hydroponics
	return 1.0 + (idle_crew_in_hydroponics * IDLE_CREW_BOOST)

func get_water_reclaimer_boost() -> float:
	## Get efficiency multiplier from idle crew helping in life support
	return 1.0 + (idle_crew_in_life_support * IDLE_CREW_BOOST)

# ============================================================================
# CONTROLS
# ============================================================================

func set_hydroponics_power(level: int) -> void:
	## Set hydroponics power level (0=OFF, 1=LOW, 2=NORMAL, 3=HIGH)
	hydroponics_power_level = clamp(level, 0, 3)
	hydroponics_light_changed.emit(hydroponics_power_level)
	_update_hydroponics_light()

func toggle_hydroponics() -> void:
	hydroponics_enabled = not hydroponics_enabled
	if not hydroponics_enabled:
		hydroponics_power_level = 0
	_update_visuals()

func toggle_water_reclaimer() -> void:
	water_reclaimer_enabled = not water_reclaimer_enabled
	_update_visuals()

func damage_hydroponics(amount: float) -> void:
	hydroponics_health = max(0, hydroponics_health - amount)
	if hydroponics_health <= 20:
		system_damaged.emit("hydroponics")
	_update_visuals()

func damage_water_reclaimer(amount: float) -> void:
	water_reclaimer_health = max(0, water_reclaimer_health - amount)
	if water_reclaimer_health <= 50:
		system_damaged.emit("water_reclaimer")
	_update_visuals()

func repair_hydroponics(amount: float) -> void:
	var was_damaged = hydroponics_health <= 20
	hydroponics_health = min(100, hydroponics_health + amount)
	if was_damaged and hydroponics_health > 20:
		system_repaired.emit("hydroponics")
	_update_visuals()

func repair_water_reclaimer(amount: float) -> void:
	var was_damaged = water_reclaimer_health <= 50
	water_reclaimer_health = min(100, water_reclaimer_health + amount)
	if was_damaged and water_reclaimer_health > 50:
		system_repaired.emit("water_reclaimer")
	_update_visuals()

func damage_solar_panels(amount: float) -> void:
	solar_panels_health = max(0, solar_panels_health - amount)
	if solar_panels_health <= 30:
		system_damaged.emit("solar_panels")
	_update_visuals()

func repair_solar_panels(amount: float) -> void:
	var was_damaged = solar_panels_health <= 30
	solar_panels_health = min(100, solar_panels_health + amount)
	if was_damaged and solar_panels_health > 30:
		system_repaired.emit("solar_panels")
	_update_visuals()

func damage_co2_scrubber(amount: float) -> void:
	co2_scrubber_health = max(0, co2_scrubber_health - amount)
	if co2_scrubber_health <= 40:
		system_damaged.emit("co2_scrubber")
	_update_visuals()

func repair_co2_scrubber(amount: float) -> void:
	var was_damaged = co2_scrubber_health <= 40
	co2_scrubber_health = min(100, co2_scrubber_health + amount)
	if was_damaged and co2_scrubber_health > 40:
		system_repaired.emit("co2_scrubber")
	_update_visuals()

func toggle_solar_panels() -> void:
	solar_panels_enabled = not solar_panels_enabled
	_update_visuals()

func toggle_co2_scrubber() -> void:
	co2_scrubber_enabled = not co2_scrubber_enabled
	_update_visuals()

# ============================================================================
# VISUAL UPDATES
# ============================================================================

func _update_visuals() -> void:
	_update_hydroponics_light()
	_update_hydroponics_health()
	_update_water_reclaimer_status()

func _update_hydroponics_light() -> void:
	if not hydroponics_visual:
		return

	var light_glow = hydroponics_visual.get_node_or_null("LightGlow")
	var power_label = hydroponics_visual.get_node_or_null("PowerLabel")

	if light_glow:
		var level_config = HYDROPONICS_POWER_LEVELS[hydroponics_power_level]
		var target_color = level_config.color
		target_color.a = 0.4 if hydroponics_enabled else 0.1

		var tween = create_tween()
		tween.tween_property(light_glow, "color", target_color, 0.3)

	if power_label:
		power_label.text = "PWR: %s" % HYDROPONICS_POWER_LEVELS[hydroponics_power_level].name

func _update_hydroponics_health() -> void:
	if not hydroponics_visual:
		return

	# Update plants based on health
	for i in range(5):
		var plant = hydroponics_visual.get_node_or_null("Plant%d" % i)
		if plant:
			var health_color = Color.WHITE
			if hydroponics_health < 30:
				health_color = Color(0.6, 0.5, 0.3)  # Wilting
			elif hydroponics_health < 60:
				health_color = Color(0.8, 0.8, 0.6)  # Stressed
			plant.modulate = health_color

func _update_growth_visual() -> void:
	if not hydroponics_visual:
		return

	var progress_fill = hydroponics_visual.get_node_or_null("ProgressFill")
	if progress_fill:
		var progress = hydroponics_growth_progress / HYDROPONICS_GROWTH_CYCLE_HOURS
		var width = 48 * progress
		progress_fill.polygon = PackedVector2Array([
			Vector2(-24, 33), Vector2(-24 + width, 33),
			Vector2(-24 + width, 35), Vector2(-24, 35)
		])

	_animate_plant_growth()

func _update_water_reclaimer_status() -> void:
	if not water_reclaimer_visual:
		return

	var status_light = water_reclaimer_visual.get_node_or_null("StatusLight")
	var gauge_fill = water_reclaimer_visual.get_node_or_null("GaugeFill")
	var eff_label = water_reclaimer_visual.get_node_or_null("EfficiencyLabel")
	var water_level = water_reclaimer_visual.get_node_or_null("WaterLevel")

	var efficiency = get_current_water_efficiency()

	# Status light color
	if status_light:
		var status_color: Color
		if water_reclaimer_health > 70:
			status_color = Color(0.3, 0.9, 0.3)  # Green
		elif water_reclaimer_health > 40:
			status_color = Color(0.9, 0.7, 0.2)  # Yellow
		else:
			status_color = Color(0.9, 0.3, 0.2)  # Red
		status_light.color = status_color

	# Efficiency gauge
	if gauge_fill:
		var gauge_width = 22 * efficiency
		gauge_fill.polygon = PackedVector2Array([
			Vector2(-11, -21), Vector2(-11 + gauge_width, -21),
			Vector2(-11 + gauge_width, -20), Vector2(-11, -20)
		])

		# Color based on efficiency
		if efficiency > 0.85:
			gauge_fill.color = Color(0.3, 0.7, 0.9)
		elif efficiency > 0.70:
			gauge_fill.color = Color(0.9, 0.7, 0.3)
		else:
			gauge_fill.color = Color(0.9, 0.4, 0.3)

	# Efficiency label
	if eff_label:
		eff_label.text = "EFF: %d%%" % int(efficiency * 100)

	# Water level visual
	if water_level:
		var level_height = 20 * efficiency
		water_level.polygon = PackedVector2Array([
			Vector2(-14, 20 - level_height), Vector2(14, 20 - level_height),
			Vector2(14, 20), Vector2(-14, 20)
		])

func _show_harvest_effect() -> void:
	## Show a visual effect when harvest is ready
	if not hydroponics_visual:
		return

	# Flash the plants
	var flash_tween = create_tween()
	flash_tween.tween_property(hydroponics_visual, "modulate", Color(1.5, 1.5, 0.8), 0.2)
	flash_tween.tween_property(hydroponics_visual, "modulate", Color.WHITE, 0.3)

	# Reset plants to small size
	for i in range(5):
		var plant = hydroponics_visual.get_node_or_null("Plant%d" % i)
		if plant:
			plant.scale = Vector2(0.5, 0.5)

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save_state() -> Dictionary:
	return {
		"hydroponics_enabled": hydroponics_enabled,
		"hydroponics_power_level": hydroponics_power_level,
		"hydroponics_health": hydroponics_health,
		"hydroponics_growth_progress": hydroponics_growth_progress,
		"water_reclaimer_enabled": water_reclaimer_enabled,
		"water_reclaimer_health": water_reclaimer_health,
		"solar_panels_enabled": solar_panels_enabled,
		"solar_panels_health": solar_panels_health,
		"solar_panel_orientation": solar_panel_orientation,
		"co2_scrubber_enabled": co2_scrubber_enabled,
		"co2_scrubber_health": co2_scrubber_health,
	}

func load_state(state: Dictionary) -> void:
	hydroponics_enabled = state.get("hydroponics_enabled", true)
	hydroponics_power_level = state.get("hydroponics_power_level", 2)
	hydroponics_health = state.get("hydroponics_health", 100.0)
	hydroponics_growth_progress = state.get("hydroponics_growth_progress", 0.0)
	water_reclaimer_enabled = state.get("water_reclaimer_enabled", true)
	water_reclaimer_health = state.get("water_reclaimer_health", 100.0)
	solar_panels_enabled = state.get("solar_panels_enabled", true)
	solar_panels_health = state.get("solar_panels_health", 100.0)
	solar_panel_orientation = state.get("solar_panel_orientation", 1.0)
	co2_scrubber_enabled = state.get("co2_scrubber_enabled", true)
	co2_scrubber_health = state.get("co2_scrubber_health", 100.0)
	_update_visuals()

# ============================================================================
# GETTERS
# ============================================================================

func get_hydroponics_status() -> Dictionary:
	return {
		"enabled": hydroponics_enabled,
		"health": hydroponics_health,
		"power_level": hydroponics_power_level,
		"growth_progress": hydroponics_growth_progress,
		"growth_max": HYDROPONICS_GROWTH_CYCLE_HOURS,
		"power_consumption": HYDROPONICS_POWER_LEVELS[hydroponics_power_level].power,
		"yield_rate": HYDROPONICS_POWER_LEVELS[hydroponics_power_level].yield_per_hour
	}

func get_water_reclaimer_status() -> Dictionary:
	return {
		"enabled": water_reclaimer_enabled,
		"health": water_reclaimer_health,
		"efficiency": get_current_water_efficiency(),
		"power_consumption": WATER_RECLAIMER_POWER_CONSUMPTION
	}

func get_solar_panels_status() -> Dictionary:
	var health_factor = solar_panels_health / 100.0
	var current_output = 0.0
	if solar_panels_enabled and solar_panels_health > SOLAR_PANEL_MIN_HEALTH_FOR_FUNCTION:
		var base_output = SOLAR_PANEL_DAMAGED_OUTPUT + \
			(SOLAR_PANEL_BASE_OUTPUT - SOLAR_PANEL_DAMAGED_OUTPUT) * health_factor
		current_output = base_output * solar_panel_orientation
	return {
		"enabled": solar_panels_enabled,
		"health": solar_panels_health,
		"orientation": solar_panel_orientation,
		"current_output": current_output,
		"max_output": SOLAR_PANEL_BASE_OUTPUT
	}

func get_co2_scrubber_status() -> Dictionary:
	var health_factor = co2_scrubber_health / 100.0
	var current_output = 0.0
	if co2_scrubber_enabled and co2_scrubber_health > 20:
		current_output = CO2_SCRUBBER_DAMAGED_OUTPUT + \
			(CO2_SCRUBBER_BASE_OUTPUT - CO2_SCRUBBER_DAMAGED_OUTPUT) * health_factor
	return {
		"enabled": co2_scrubber_enabled,
		"health": co2_scrubber_health,
		"current_output": current_output,
		"max_output": CO2_SCRUBBER_BASE_OUTPUT,
		"power_consumption": CO2_SCRUBBER_POWER_CONSUMPTION
	}

func get_all_systems_status() -> Dictionary:
	## Get status of all life support systems at once
	return {
		"hydroponics": get_hydroponics_status(),
		"water_reclaimer": get_water_reclaimer_status(),
		"solar_panels": get_solar_panels_status(),
		"co2_scrubber": get_co2_scrubber_status()
	}
