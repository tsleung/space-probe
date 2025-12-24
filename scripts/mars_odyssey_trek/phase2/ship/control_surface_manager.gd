extends Node
class_name ControlSurfaceManager

## Manages all control surfaces on the ship
## Handles state transitions, power balance, heat mechanics, and effect application
##
## 6 Core Systems: Power Core, Shields, Engine, Life Support, Medical Bay, Sensors
## Plus: Emergency Power button
## See: docs/mot/control-surfaces.md

const ControlSurface = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal surface_state_changed(surface_id: int, old_state: int, new_state: int)
signal surface_level_changed(surface_id: int, old_level: int, new_level: int)
signal surface_broken(surface_id: int, cause: String)
signal surface_repaired(surface_id: int)
signal surface_interaction_started(surface_id: int, crew_role: String)
signal surface_interaction_completed(surface_id: int, crew_role: String)
signal power_balance_changed(drain: float, generation: float)
signal reactor_overheat_warning(heat_level: float)
signal reactor_critical(time_to_explosion: float)
signal reactor_exploded()
signal emergency_power_activated()
signal emergency_power_depleted()

# ============================================================================
# STATE
# ============================================================================

var surface_states: Dictionary = {}  # SurfaceId -> state dictionary
var reactor_critical_timer: float = 0.0
var emergency_power_active: bool = false
var emergency_power_timer: float = 0.0
var emergency_power_cooldown: float = 0.0

# References
var store: Node  # Phase2Store

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_initialize_all_surfaces()

func _initialize_all_surfaces() -> void:
	## Create initial state for all control surfaces
	for surface_id in ControlSurface.get_all_surface_ids():
		surface_states[surface_id] = ControlSurface.create_surface_state(surface_id)

func connect_to_store(phase2_store: Node) -> void:
	store = phase2_store

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	_process_interactions(delta)
	_process_reactor_heat(delta)
	_process_emergency_power(delta)

func _process_interactions(delta: float) -> void:
	## Update surfaces that are being used
	for surface_id in surface_states:
		var state = surface_states[surface_id]
		if state.state == ControlSurface.SurfaceState.USING:
			state.use_timer -= delta
			if state.use_timer <= 0:
				_complete_interaction(surface_id)

func _process_reactor_heat(delta: float) -> void:
	## Handle reactor heat buildup and cooling
	var core_state = surface_states.get(ControlSurface.SurfaceId.POWER_CORE, {})
	if core_state.is_empty():
		return

	if core_state.state == ControlSurface.SurfaceState.BROKEN:
		return  # Broken reactor doesn't generate heat

	# Heat generation/dissipation (convert per-hour to per-second)
	var heat_rate = ControlSurface.get_effect(
		ControlSurface.SurfaceId.POWER_CORE,
		"heat_rate",
		core_state.get("level", 0)
	)
	if heat_rate == null:
		heat_rate = 0.0

	# In OVERDRIVE: accumulate heat
	# In NORMAL: dissipate heat
	if heat_rate > 0:
		core_state.heat += (heat_rate / 3600.0) * delta  # Per hour → per second
	else:
		# Dissipate heat when not in overdrive
		core_state.heat -= (ControlSurface.HEAT_DISSIPATION_RATE / 3600.0) * delta
		core_state.heat = max(0.0, core_state.heat)

	# Heat thresholds
	if core_state.heat >= ControlSurface.HEAT_WARNING_THRESHOLD:
		reactor_overheat_warning.emit(core_state.heat)

	if core_state.heat >= ControlSurface.HEAT_CRITICAL_THRESHOLD:
		reactor_critical_timer += delta
		var time_left = ControlSurface.HEAT_EXPLOSION_TIME - reactor_critical_timer
		reactor_critical.emit(time_left)

		if reactor_critical_timer >= ControlSurface.HEAT_EXPLOSION_TIME:
			_trigger_reactor_explosion()
	else:
		reactor_critical_timer = 0.0

func _process_emergency_power(delta: float) -> void:
	## Handle emergency power duration
	var emergency_state = surface_states.get(ControlSurface.SurfaceId.EMERGENCY_POWER, {})
	if emergency_state.is_empty():
		return

	if emergency_state.level == 1:  # ACTIVE
		emergency_state.active_duration -= delta
		if emergency_state.active_duration <= 0:
			_deactivate_emergency_power()

	# Recharge from DEPLETED back to STANDBY
	if emergency_state.level == 2:  # DEPLETED
		emergency_state.cooldown -= delta
		if emergency_state.cooldown <= 0:
			emergency_state.level = 0  # Back to STANDBY
			emergency_state.cooldown = 0.0

# ============================================================================
# INTERACTION API
# ============================================================================

func start_interaction(surface_id: int, crew_role: String) -> bool:
	## Start crew interaction with a surface
	## Returns false if surface is broken or already being used

	var state = surface_states.get(surface_id, {})
	if state.is_empty():
		return false

	if state.state == ControlSurface.SurfaceState.BROKEN:
		return false

	if state.state == ControlSurface.SurfaceState.USING:
		return false  # Already in use

	var old_state = state.state
	state.state = ControlSurface.SurfaceState.USING
	state.use_timer = ControlSurface.get_interaction_time(surface_id)

	surface_state_changed.emit(surface_id, old_state, state.state)
	surface_interaction_started.emit(surface_id, crew_role)

	return true

func _complete_interaction(surface_id: int) -> void:
	## Complete an interaction and apply the level change
	var state = surface_states.get(surface_id, {})
	if state.is_empty():
		return

	# Handle based on surface type
	var surface_type = ControlSurface.get_type(surface_id)
	if surface_type == ControlSurface.SurfaceType.LEVER:
		var levels = ControlSurface.get_levels(surface_id)
		var old_level = state.level
		state.level = (state.level + 1) % levels.size()
		surface_level_changed.emit(surface_id, old_level, state.level)

	elif surface_type == ControlSurface.SurfaceType.BUTTON:
		_handle_button_press(surface_id)

	# Return to working state
	var old_state = state.state
	state.state = ControlSurface.SurfaceState.WORKING
	surface_state_changed.emit(surface_id, old_state, state.state)
	surface_interaction_completed.emit(surface_id, "")

	# Recalculate power balance
	_emit_power_balance()

func set_level(surface_id: int, level: int) -> bool:
	## Directly set level (used by AI or UI)
	var state = surface_states.get(surface_id, {})
	if state.is_empty():
		return false

	if state.state != ControlSurface.SurfaceState.WORKING:
		return false

	var levels = ControlSurface.get_levels(surface_id)
	if level < 0 or level >= levels.size():
		return false

	var old_level = state.level
	state.level = level
	surface_level_changed.emit(surface_id, old_level, level)
	_emit_power_balance()

	return true

func _handle_button_press(surface_id: int) -> void:
	## Handle button-type surface activation
	if surface_id == ControlSurface.SurfaceId.EMERGENCY_POWER:
		_activate_emergency_power()

# ============================================================================
# DAMAGE & REPAIR
# ============================================================================

func break_surface(surface_id: int, cause: String = "damage") -> void:
	## Set a surface to broken state
	var state = surface_states.get(surface_id, {})
	if state.is_empty():
		return

	if state.state == ControlSurface.SurfaceState.BROKEN:
		return  # Already broken

	var old_state = state.state
	state.state = ControlSurface.SurfaceState.BROKEN
	state.broken_time = 0.0

	surface_state_changed.emit(surface_id, old_state, state.state)
	surface_broken.emit(surface_id, cause)
	_emit_power_balance()

	print("[SURFACE] %s BROKEN: %s" % [ControlSurface.get_name(surface_id), cause])

func repair_surface(surface_id: int) -> void:
	## Repair a broken surface
	var state = surface_states.get(surface_id, {})
	if state.is_empty():
		return

	if state.state != ControlSurface.SurfaceState.BROKEN:
		return

	var old_state = state.state
	state.state = ControlSurface.SurfaceState.WORKING
	state.broken_time = 0.0

	surface_state_changed.emit(surface_id, old_state, state.state)
	surface_repaired.emit(surface_id)
	_emit_power_balance()

	print("[SURFACE] %s REPAIRED" % ControlSurface.get_name(surface_id))

func start_repair(surface_id: int, _crew_role: String) -> float:
	## Start repairing a broken surface
	## Returns repair time, or -1 if can't repair
	var state = surface_states.get(surface_id, {})
	if state.is_empty() or state.state != ControlSurface.SurfaceState.BROKEN:
		return -1.0

	return ControlSurface.get_repair_time(surface_id)

# ============================================================================
# EMERGENCY POWER
# ============================================================================

func _activate_emergency_power() -> void:
	var state = surface_states.get(ControlSurface.SurfaceId.EMERGENCY_POWER, {})
	if state.is_empty():
		return

	# Check if depleted or on cooldown
	if state.level == 2:  # DEPLETED
		return

	var effect = ControlSurface.get_definition(ControlSurface.SurfaceId.EMERGENCY_POWER).get("effect", {})
	state.level = 1  # ACTIVE
	state.active_duration = effect.get("duration", 30.0)

	emergency_power_activated.emit()
	_emit_power_balance()
	print("[POWER] EMERGENCY POWER ACTIVATED!")

func _deactivate_emergency_power() -> void:
	var state = surface_states.get(ControlSurface.SurfaceId.EMERGENCY_POWER, {})
	if state.is_empty():
		return

	var effect = ControlSurface.get_definition(ControlSurface.SurfaceId.EMERGENCY_POWER).get("effect", {})
	state.level = 2  # DEPLETED
	state.cooldown = effect.get("recharge_time", 300.0)
	state.active_duration = 0.0

	emergency_power_depleted.emit()
	_emit_power_balance()
	print("[POWER] Emergency power depleted")

func _trigger_reactor_explosion() -> void:
	## CATASTROPHIC: Reactor exploded
	print("[POWER] !!! REACTOR EXPLOSION !!!")

	break_surface(ControlSurface.SurfaceId.POWER_CORE, "explosion")

	# 50% chance to damage engine
	if randf() < 0.5:
		break_surface(ControlSurface.SurfaceId.ENGINE, "explosion_damage")

	# Reset heat
	var core_state = surface_states.get(ControlSurface.SurfaceId.POWER_CORE, {})
	if not core_state.is_empty():
		core_state.heat = 0.0
	reactor_critical_timer = 0.0

	reactor_exploded.emit()

# ============================================================================
# QUERIES
# ============================================================================

func get_surface_state(surface_id: int) -> Dictionary:
	return surface_states.get(surface_id, {})

func get_level(surface_id: int) -> int:
	var state = surface_states.get(surface_id, {})
	return state.get("level", 0)

func is_broken(surface_id: int) -> bool:
	var state = surface_states.get(surface_id, {})
	return state.get("state") == ControlSurface.SurfaceState.BROKEN

func is_being_used(surface_id: int) -> bool:
	var state = surface_states.get(surface_id, {})
	return state.get("state") == ControlSurface.SurfaceState.USING

func get_total_power_drain() -> float:
	return ControlSurface.calculate_total_drain(surface_states)

func get_total_power_generation() -> float:
	return ControlSurface.calculate_total_generation(surface_states)

func get_net_power() -> float:
	return ControlSurface.calculate_net_power(surface_states)

func get_damage_reduction() -> float:
	return ControlSurface.get_damage_reduction(surface_states)

func get_speed_multiplier() -> float:
	return ControlSurface.get_speed_multiplier(surface_states)

func get_fuel_multiplier() -> float:
	return ControlSurface.get_fuel_multiplier(surface_states)

func get_healing_multiplier() -> float:
	return ControlSurface.get_healing_rate(surface_states)

func get_o2_multiplier() -> float:
	return ControlSurface.get_o2_multiplier(surface_states)

func get_water_multiplier() -> float:
	return ControlSurface.get_water_multiplier(surface_states)

func get_event_warning_days() -> int:
	return ControlSurface.get_event_warning_days(surface_states)

func get_broken_surfaces() -> Array:
	## Get list of all broken surface IDs
	var broken = []
	for surface_id in surface_states:
		if surface_states[surface_id].state == ControlSurface.SurfaceState.BROKEN:
			broken.append(surface_id)
	return broken

func get_reactor_heat() -> float:
	var core_state = surface_states.get(ControlSurface.SurfaceId.POWER_CORE, {})
	return core_state.get("heat", 0.0)

func is_emergency_power_available() -> bool:
	var state = surface_states.get(ControlSurface.SurfaceId.EMERGENCY_POWER, {})
	return state.get("level", 0) == 0  # STANDBY

func is_emergency_power_active() -> bool:
	var state = surface_states.get(ControlSurface.SurfaceId.EMERGENCY_POWER, {})
	return state.get("level", 0) == 1  # ACTIVE

# ============================================================================
# POWER BALANCE
# ============================================================================

func _emit_power_balance() -> void:
	var drain = get_total_power_drain()
	var gen = get_total_power_generation()
	power_balance_changed.emit(drain, gen)

# ============================================================================
# SERIALIZATION
# ============================================================================

func save_state() -> Dictionary:
	return {
		"surface_states": surface_states.duplicate(true),
		"reactor_critical_timer": reactor_critical_timer,
		"emergency_power_active": emergency_power_active,
		"emergency_power_timer": emergency_power_timer,
		"emergency_power_cooldown": emergency_power_cooldown
	}

func load_state(data: Dictionary) -> void:
	surface_states = data.get("surface_states", {})
	reactor_critical_timer = data.get("reactor_critical_timer", 0.0)
	emergency_power_active = data.get("emergency_power_active", false)
	emergency_power_timer = data.get("emergency_power_timer", 0.0)
	emergency_power_cooldown = data.get("emergency_power_cooldown", 0.0)

	# Reinitialize any missing surfaces
	for surface_id in ControlSurface.get_all_surface_ids():
		if not surface_id in surface_states:
			surface_states[surface_id] = ControlSurface.create_surface_state(surface_id)

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_status() -> void:
	print("=== CONTROL SURFACE STATUS ===")
	print("Power: %.1f gen / %.1f drain = %.1f net (per hour)" % [
		get_total_power_generation(),
		get_total_power_drain(),
		get_net_power()
	])

	var core_state = surface_states.get(ControlSurface.SurfaceId.POWER_CORE, {})
	print("Power Core: %s (heat: %.1f)" % [
		ControlSurface.get_level_name(ControlSurface.SurfaceId.POWER_CORE, core_state.get("level", 0)),
		core_state.get("heat", 0.0)
	])

	print("Shields: %s (%.0f%% reduction)" % [
		"ON" if get_level(ControlSurface.SurfaceId.SHIELDS) == 1 else "OFF",
		get_damage_reduction() * 100
	])

	print("Engine: %s (%.1fx speed, %.1fx fuel)" % [
		ControlSurface.get_level_name(ControlSurface.SurfaceId.ENGINE, get_level(ControlSurface.SurfaceId.ENGINE)),
		get_speed_multiplier(),
		get_fuel_multiplier()
	])

	print("Life Support: %s (%.1fx O2, %.1fx water)" % [
		ControlSurface.get_level_name(ControlSurface.SurfaceId.LIFE_SUPPORT, get_level(ControlSurface.SurfaceId.LIFE_SUPPORT)),
		get_o2_multiplier(),
		get_water_multiplier()
	])

	print("Medical Bay: %s" % ("ON" if get_level(ControlSurface.SurfaceId.MEDICAL_BAY) == 1 else "OFF"))
	print("Sensors: %s (+%d day warning)" % [
		"ON" if get_level(ControlSurface.SurfaceId.SENSORS) == 1 else "OFF",
		get_event_warning_days()
	])

	var broken = get_broken_surfaces()
	if broken.size() > 0:
		print("BROKEN: %s" % str(broken.map(func(id): return ControlSurface.get_name(id))))

	print("==============================")
