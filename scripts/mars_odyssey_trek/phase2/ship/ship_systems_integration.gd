extends Node
class_name ShipSystemsIntegration

## Wires up all ship systems for MOT Phase 2
## Connects Control Surfaces, Hull Events, and Effects to Phase2Store

const ControlSurface = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface.gd")
const ControlSurfaceManager = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface_manager.gd")
const ControlSurfacesContainer = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surfaces_container.gd")
const HullEvents = preload("res://scripts/mars_odyssey_trek/phase2/ship/hull_events.gd")
const ExteriorSurfaceManager = preload("res://scripts/mars_odyssey_trek/phase2/ship/exterior_surface_manager.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal power_critical()
signal hull_breach_imminent()
signal reactor_meltdown_warning()
signal exterior_surface_critical(surface_type: String)

# ============================================================================
# CHILD NODES (Created at runtime)
# ============================================================================

var surface_manager: ControlSurfaceManager
var surfaces_container: ControlSurfacesContainer
var hull_events: HullEvents
var exterior_surfaces: ExteriorSurfaceManager

# References
var store: Node  # Phase2Store
var effects: Node  # Phase2Effects
var ship_view: Node2D  # ShipView

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var power_update_interval: float = 1.0  # Check power balance every second
@export var hull_event_interval: float = 30.0  # Check for random hull events
@export var auto_hull_events: bool = true  # Enable random hull events

# State
var power_timer: float = 0.0
var hull_event_timer: float = 0.0
var last_net_power: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_child_systems()

func _create_child_systems() -> void:
	## Create all child system nodes
	surface_manager = ControlSurfaceManager.new()
	surface_manager.name = "ControlSurfaceManager"
	add_child(surface_manager)

	surfaces_container = ControlSurfacesContainer.new()
	surfaces_container.name = "ControlSurfacesContainer"
	add_child(surfaces_container)

	hull_events = HullEvents.new()
	hull_events.name = "HullEvents"
	add_child(hull_events)

	exterior_surfaces = ExteriorSurfaceManager.new()
	exterior_surfaces.name = "ExteriorSurfaceManager"
	add_child(exterior_surfaces)

func setup(phase2_store: Node, phase2_effects: Node, view: Node2D) -> void:
	## Connect all systems together
	store = phase2_store
	effects = phase2_effects
	ship_view = view

	# Setup surface manager
	surface_manager.connect_to_store(store)

	# Setup surfaces container - position surfaces within rooms
	surfaces_container.setup_with_ship_view(surface_manager, ship_view)

	# Setup hull events
	hull_events.setup(effects, surface_manager, ship_view)

	# Connect signals
	_connect_signals()

	print("[SHIP SYSTEMS] Integration complete")

func _connect_signals() -> void:
	## Wire up all system signals

	# Surface manager signals
	surface_manager.power_balance_changed.connect(_on_power_balance_changed)
	surface_manager.surface_broken.connect(_on_surface_broken)
	surface_manager.surface_repaired.connect(_on_surface_repaired)
	surface_manager.reactor_overheat_warning.connect(_on_reactor_overheat)
	surface_manager.reactor_critical.connect(_on_reactor_critical)
	surface_manager.emergency_power_activated.connect(_on_emergency_power)
	surface_manager.emergency_power_depleted.connect(_on_emergency_depleted)

	# Hull event signals
	hull_events.asteroid_impact.connect(_on_asteroid_impact)
	hull_events.solar_flare_hit.connect(_on_solar_flare)
	hull_events.micrometeorite_hit.connect(_on_micrometeorite)
	hull_events.debris_collision.connect(_on_debris_collision)

	# Surfaces container click handling
	surfaces_container.surface_clicked.connect(_on_surface_clicked)

	# Exterior surface signals
	exterior_surfaces.surface_damaged.connect(_on_exterior_damaged)
	exterior_surfaces.surface_repaired.connect(_on_exterior_repaired)
	exterior_surfaces.surface_critical.connect(_on_exterior_critical)

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	_process_power_effects(delta)
	_process_hull_events(delta)

func _process_power_effects(delta: float) -> void:
	## Apply power drain/generation to Phase2Store
	power_timer += delta
	if power_timer < power_update_interval:
		return

	power_timer = 0.0

	if not store:
		return

	var net_power = surface_manager.get_net_power()

	# Apply power change to store via dispatch
	# net_power is in units/hour, we need to scale by interval
	# power_update_interval is 1 second, so divide hourly rate by 3600
	if store.has_method("dispatch") and net_power != 0:
		var power_delta = net_power * (power_update_interval / 3600.0)
		store.dispatch(Phase2Reducer.action_apply_power_delta(power_delta))

	# Check for power critical (net drain worse than -5/hr)
	if net_power < -5.0 and last_net_power >= -5.0:
		power_critical.emit()
		if surfaces_container:
			surfaces_container.show_power_balance_warning(true)
	elif net_power >= -5.0 and last_net_power < -5.0:
		# Power recovered - could clear warning
		pass

	last_net_power = net_power

func _process_hull_events(delta: float) -> void:
	## Randomly trigger hull events
	if not auto_hull_events:
		return

	hull_event_timer += delta
	if hull_event_timer < hull_event_interval:
		return

	hull_event_timer = 0.0

	# Random chance of hull event
	var roll = randf()
	if roll < 0.05:  # 5% chance every 30 seconds
		_trigger_random_hull_event()

func _trigger_random_hull_event() -> void:
	var event_type = randi() % 4
	match event_type:
		0:
			hull_events.trigger_micrometeorite_shower(randi_range(3, 7))
		1:
			hull_events.trigger_debris_collision(1)
		2:
			hull_events.trigger_solar_flare(randf_range(0.5, 1.5))
		3:
			hull_events.trigger_asteroid_impact(["small", "medium"][randi() % 2])

# ============================================================================
# SIGNAL HANDLERS - Surface Manager
# ============================================================================

func _on_power_balance_changed(drain: float, generation: float) -> void:
	var net = generation - drain
	print("[POWER] Drain: %.1f, Gen: %.1f, Net: %.1f" % [drain, generation, net])

func _on_surface_broken(surface_id: int, cause: String) -> void:
	## Handle surface breaking
	var name = ControlSurface.get_name(surface_id)
	print("[SURFACE] %s BROKEN: %s" % [name, cause])

	# Visual effects
	if effects and surfaces_container:
		var pos = surfaces_container.get_surface_position(surface_id)
		if pos != Vector2.ZERO:
			effects.spawn_sparks(pos, 15)
			effects.spawn_smoke(pos, 4)

	# Flash room
	if ship_view:
		var room = ControlSurface.get_room(surface_id)
		ship_view.flash_room(room, Color(1.0, 0.3, 0.2))

func _on_surface_repaired(surface_id: int) -> void:
	var name = ControlSurface.get_name(surface_id)
	print("[SURFACE] %s REPAIRED" % name)

	# Visual effects
	if effects and surfaces_container:
		var pos = surfaces_container.get_surface_position(surface_id)
		if pos != Vector2.ZERO:
			effects.spawn_welding_sparks(pos)

	# Flash room green
	if ship_view:
		var room = ControlSurface.get_room(surface_id)
		ship_view.flash_room(room, Color(0.2, 1.0, 0.3))

func _on_reactor_overheat(heat_level: float) -> void:
	print("[REACTOR] OVERHEAT WARNING: %.1f" % heat_level)
	if effects:
		var reactor_pos = surfaces_container.get_surface_position(ControlSurface.SurfaceId.POWER_CORE)
		effects.spawn_steam(reactor_pos, 8)

func _on_reactor_critical(time_to_explosion: float) -> void:
	print("[REACTOR] CRITICAL! %.1fs to explosion!" % time_to_explosion)
	reactor_meltdown_warning.emit()

	if effects:
		var reactor_pos = surfaces_container.get_surface_position(ControlSurface.SurfaceId.POWER_CORE)
		effects.spawn_fire(reactor_pos, 1.0)
		effects.shake_screen(5.0, 0.5)

func _on_emergency_power() -> void:
	print("[POWER] EMERGENCY POWER ACTIVATED!")
	if surfaces_container:
		surfaces_container.flash_all_surfaces(Color(1.0, 1.0, 0.3))

func _on_emergency_depleted() -> void:
	print("[POWER] Emergency power depleted")

# ============================================================================
# SIGNAL HANDLERS - Hull Events
# ============================================================================

func _on_asteroid_impact(room: int, damage: float) -> void:
	print("[HULL] Asteroid impact! Room: %s, Damage: %.0f%%" % [ShipTypes.get_room_name(room), damage * 100])

	if ship_view:
		ship_view.damage_room(room, damage)

	# Chance to trigger hull breach warning
	if damage > 0.3:
		hull_breach_imminent.emit()

	# Chance to damage exterior surfaces (30% for asteroids)
	if randf() < 0.3:
		var surfaces = [
			ExteriorSurfaceManager.SurfaceType.ENGINE_NOZZLE,
			ExteriorSurfaceManager.SurfaceType.ANTENNA_ARRAY,
			ExteriorSurfaceManager.SurfaceType.SOLAR_PANEL
		]
		var target = surfaces[randi() % surfaces.size()]
		var ext_damage = damage * randf_range(15, 35)
		exterior_surfaces.damage_surface(target, ext_damage)

func _on_solar_flare(intensity: float) -> void:
	print("[HULL] Solar flare hit! Intensity: %.1f" % intensity)

	# Visual flash handled by hull_events
	if effects:
		effects.trigger_solar_flare_effect()

	# Solar panels especially vulnerable to solar flares (40% chance)
	if randf() < 0.4:
		var damage = intensity * randf_range(10, 25)
		exterior_surfaces.damage_surface(ExteriorSurfaceManager.SurfaceType.SOLAR_PANEL, damage)

func _on_micrometeorite(damage: float) -> void:
	print("[HULL] Micrometeorite hit. Minor damage.")
	# Small impacts - mostly handled visually

func _on_debris_collision(damage: float) -> void:
	print("[HULL] Debris collision! Damage: %.0f%%" % (damage * 100))

	# Debris can damage antenna more easily (20% chance)
	if randf() < 0.2:
		var ext_damage = damage * randf_range(10, 20)
		exterior_surfaces.damage_surface(ExteriorSurfaceManager.SurfaceType.ANTENNA_ARRAY, ext_damage)

# ============================================================================
# SIGNAL HANDLERS - Exterior Surfaces
# ============================================================================

func _on_exterior_damaged(surface_type: String, new_integrity: float) -> void:
	print("[EXTERIOR] %s damaged, integrity: %.0f%%" % [surface_type.capitalize(), new_integrity * 100])

func _on_exterior_repaired(surface_type: String) -> void:
	print("[EXTERIOR] %s fully repaired!" % surface_type.capitalize())

func _on_exterior_critical(surface_type: String) -> void:
	print("[EXTERIOR] %s is CRITICAL!" % surface_type.capitalize())
	exterior_surface_critical.emit(surface_type)

# ============================================================================
# SIGNAL HANDLERS - Surface Clicks
# ============================================================================

func _on_surface_clicked(surface_id: int) -> void:
	## Handle player clicking on a control surface
	## For now, just log - will integrate with crew commands later

	var surface_name = ControlSurface.get_name(surface_id)

	if surface_manager.is_broken(surface_id):
		print("[CLICK] %s is broken - needs repair" % surface_name)
		return

	if surface_manager.is_being_used(surface_id):
		print("[CLICK] %s is currently being used" % surface_name)
		return

	print("[CLICK] %s clicked - would need crew to operate" % surface_name)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_surface_manager() -> ControlSurfaceManager:
	return surface_manager

func get_hull_events() -> HullEvents:
	return hull_events

func get_exterior_surfaces() -> ExteriorSurfaceManager:
	return exterior_surfaces

func repair_exterior_by_waypoint(waypoint: int) -> void:
	## Called when EVA repairs an exterior surface
	exterior_surfaces.repair_by_waypoint(waypoint)

func get_power_status() -> Dictionary:
	return {
		"drain": surface_manager.get_total_power_drain(),
		"generation": surface_manager.get_total_power_generation(),
		"net": surface_manager.get_net_power(),
		"reactor_heat": surface_manager.get_reactor_heat()
	}

func get_ship_modifiers() -> Dictionary:
	## Get all modifiers from control surfaces and exterior surfaces for Phase2 calculations
	# Interior control surface modifiers
	var interior_speed = surface_manager.get_speed_multiplier()
	var interior_fuel = surface_manager.get_fuel_multiplier()

	# Exterior surface modifiers
	var exterior_speed = exterior_surfaces.get_speed_modifier()
	var exterior_fuel = exterior_surfaces.get_fuel_waste_modifier()
	var exterior_solar = exterior_surfaces.get_solar_power_modifier()
	var exterior_warning = exterior_surfaces.get_event_warning_reduction()

	return {
		"damage_reduction": surface_manager.get_damage_reduction(),
		"speed_multiplier": interior_speed * exterior_speed,  # Combined speed
		"fuel_multiplier": interior_fuel * exterior_fuel,     # Combined fuel efficiency
		"healing_multiplier": surface_manager.get_healing_multiplier(),
		"o2_multiplier": surface_manager.get_o2_multiplier(),
		"solar_power_modifier": exterior_solar,               # NEW: solar panel efficiency
		"event_warning_reduction": exterior_warning,          # NEW: antenna misalignment
	}

func trigger_test_event(event_type: String) -> void:
	## Trigger a test hull event (for debugging)
	match event_type:
		"asteroid_small":
			hull_events.trigger_asteroid_impact("small")
		"asteroid_medium":
			hull_events.trigger_asteroid_impact("medium")
		"asteroid_large":
			hull_events.trigger_asteroid_impact("large")
		"solar_flare":
			hull_events.trigger_solar_flare(1.0)
		"micrometeorite":
			hull_events.trigger_micrometeorite_shower(5)
		"debris":
			hull_events.trigger_debris_collision(2)
		"explosion":
			if effects:
				effects.spawn_explosion(Vector2(400, 270), 1.5)
		"fire":
			if effects:
				effects.spawn_fire(Vector2(400, 270), 5.0)
		_:
			print("[TEST] Unknown event type: %s" % event_type)

func break_random_surface() -> void:
	## Debug: Break a random control surface
	var surface_ids = ControlSurface.get_all_surface_ids()
	var working_surfaces = surface_ids.filter(func(id): return not surface_manager.is_broken(id))

	if working_surfaces.size() > 0:
		var target = working_surfaces[randi() % working_surfaces.size()]
		surface_manager.break_surface(target, "debug")

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save_state() -> Dictionary:
	return {
		"surfaces": surface_manager.save_state(),
		"exterior": exterior_surfaces.save_state()
	}

func load_state(data: Dictionary) -> void:
	if data.has("surfaces"):
		surface_manager.load_state(data.surfaces)
	if data.has("exterior"):
		exterior_surfaces.load_state(data.exterior)
