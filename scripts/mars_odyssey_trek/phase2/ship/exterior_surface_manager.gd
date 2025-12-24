extends Node
class_name ExteriorSurfaceManager

## Manages exterior ship surfaces that require EVA to repair
## - Engine Nozzle: Affects thrust efficiency (speed)
## - Antenna Array: Affects communication (event warnings)
## - Solar Panel: Affects power generation

const ShipNavigation = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_navigation.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal surface_damaged(surface_type: String, new_integrity: float)
signal surface_repaired(surface_type: String)
signal surface_critical(surface_type: String)

# ============================================================================
# SURFACE TYPES
# ============================================================================

enum SurfaceType {
	ENGINE_NOZZLE,
	ANTENNA_ARRAY,
	SOLAR_PANEL
}

# Map waypoints to surface types
const WAYPOINT_TO_SURFACE = {
	ShipNavigation.Waypoint.EXTERIOR_ENGINE: SurfaceType.ENGINE_NOZZLE,
	ShipNavigation.Waypoint.EXTERIOR_ANTENNA: SurfaceType.ANTENNA_ARRAY,
	ShipNavigation.Waypoint.EXTERIOR_SOLAR: SurfaceType.SOLAR_PANEL,
}

const SURFACE_NAMES = {
	SurfaceType.ENGINE_NOZZLE: "Engine Nozzle",
	SurfaceType.ANTENNA_ARRAY: "Antenna Array",
	SurfaceType.SOLAR_PANEL: "Solar Panel",
}

# ============================================================================
# STATE
# ============================================================================

# Engine nozzle: 0-100% integrity (lower = worse thrust)
var engine_integrity: float = 100.0

# Antenna: 0-90 degrees misalignment (higher = worse comms)
var antenna_misalignment: float = 0.0

# Solar panel: 0-100% degradation (higher = less power)
var solar_degradation: float = 0.0

# ============================================================================
# THRESHOLDS
# ============================================================================

const ENGINE_CRITICAL = 30.0     # Below 30% integrity is critical
const ANTENNA_WARNING = 45.0     # Over 45 degrees is warning
const ANTENNA_CRITICAL = 75.0    # Over 75 degrees is critical
const SOLAR_WARNING = 50.0       # Over 50% degradation is warning
const SOLAR_CRITICAL = 80.0      # Over 80% degradation is critical

# ============================================================================
# DAMAGE / REPAIR
# ============================================================================

func damage_surface(surface_type: int, amount: float) -> void:
	## Apply damage to an exterior surface
	match surface_type:
		SurfaceType.ENGINE_NOZZLE:
			var old = engine_integrity
			engine_integrity = max(0.0, engine_integrity - amount)
			print("[EXTERIOR] Engine Nozzle: %.0f%% -> %.0f%% integrity" % [old, engine_integrity])
			if engine_integrity <= ENGINE_CRITICAL and old > ENGINE_CRITICAL:
				surface_critical.emit("engine")

		SurfaceType.ANTENNA_ARRAY:
			var old = antenna_misalignment
			antenna_misalignment = min(90.0, antenna_misalignment + amount)
			print("[EXTERIOR] Antenna Array: %.0f° -> %.0f° misalignment" % [old, antenna_misalignment])
			if antenna_misalignment >= ANTENNA_CRITICAL and old < ANTENNA_CRITICAL:
				surface_critical.emit("antenna")

		SurfaceType.SOLAR_PANEL:
			var old = solar_degradation
			solar_degradation = min(100.0, solar_degradation + amount)
			print("[EXTERIOR] Solar Panel: %.0f%% -> %.0f%% degraded" % [old, solar_degradation])
			if solar_degradation >= SOLAR_CRITICAL and old < SOLAR_CRITICAL:
				surface_critical.emit("solar")

	var type_str = get_surface_name(surface_type).to_lower().replace(" ", "_")
	surface_damaged.emit(type_str, get_integrity(surface_type))

func damage_by_waypoint(waypoint: int, amount: float) -> void:
	## Damage surface based on EVA waypoint
	var surface_type = WAYPOINT_TO_SURFACE.get(waypoint, -1)
	if surface_type >= 0:
		damage_surface(surface_type, amount)

func repair_surface(surface_type: int) -> void:
	## Fully repair an exterior surface (via EVA)
	match surface_type:
		SurfaceType.ENGINE_NOZZLE:
			engine_integrity = 100.0
			print("[EXTERIOR] Engine Nozzle repaired to 100%!")

		SurfaceType.ANTENNA_ARRAY:
			antenna_misalignment = 0.0
			print("[EXTERIOR] Antenna Array realigned!")

		SurfaceType.SOLAR_PANEL:
			solar_degradation = 0.0
			print("[EXTERIOR] Solar Panel restored!")

	var type_str = get_surface_name(surface_type).to_lower().replace(" ", "_")
	surface_repaired.emit(type_str)

func repair_by_waypoint(waypoint: int) -> void:
	## Repair surface based on EVA waypoint
	var surface_type = WAYPOINT_TO_SURFACE.get(waypoint, -1)
	if surface_type >= 0:
		repair_surface(surface_type)

# ============================================================================
# GAME SYSTEM MODIFIERS
# ============================================================================

func get_speed_modifier() -> float:
	## Engine nozzle integrity directly affects thrust
	## 100% = 1.0x, 50% = 0.5x, 0% = 0.0x
	return engine_integrity / 100.0

func get_fuel_waste_modifier() -> float:
	## Damaged engine wastes more fuel (worse efficiency)
	## 100% integrity = 1.0x fuel use
	## 50% integrity = 1.25x fuel use
	## 0% integrity = 1.5x fuel use
	return 1.0 + (1.0 - engine_integrity / 100.0) * 0.5

func get_event_warning_reduction() -> float:
	## Misaligned antenna reduces event warning time
	## 0° = 0 days reduced, 60°+ = 1 full day reduced
	if antenna_misalignment >= 60.0:
		return 1.0  # Lose full day of warning
	elif antenna_misalignment >= 30.0:
		return 0.5  # Lose half day
	return 0.0

func get_solar_power_modifier() -> float:
	## Degraded solar panels generate less power
	## 0% degradation = 1.0x, 50% = 0.5x, 100% = 0.0x
	return 1.0 - (solar_degradation / 100.0)

# ============================================================================
# QUERIES
# ============================================================================

func get_integrity(surface_type: int) -> float:
	## Get normalized integrity (0.0-1.0) for any surface
	match surface_type:
		SurfaceType.ENGINE_NOZZLE:
			return engine_integrity / 100.0
		SurfaceType.ANTENNA_ARRAY:
			return 1.0 - (antenna_misalignment / 90.0)
		SurfaceType.SOLAR_PANEL:
			return 1.0 - (solar_degradation / 100.0)
	return 1.0

func get_integrity_by_waypoint(waypoint: int) -> float:
	var surface_type = WAYPOINT_TO_SURFACE.get(waypoint, -1)
	if surface_type >= 0:
		return get_integrity(surface_type)
	return 1.0

func is_damaged(surface_type: int) -> bool:
	return get_integrity(surface_type) < 1.0

func is_critical(surface_type: int) -> bool:
	match surface_type:
		SurfaceType.ENGINE_NOZZLE:
			return engine_integrity <= ENGINE_CRITICAL
		SurfaceType.ANTENNA_ARRAY:
			return antenna_misalignment >= ANTENNA_CRITICAL
		SurfaceType.SOLAR_PANEL:
			return solar_degradation >= SOLAR_CRITICAL
	return false

func get_surface_name(surface_type: int) -> String:
	return SURFACE_NAMES.get(surface_type, "Unknown")

func get_all_surfaces_status() -> Dictionary:
	return {
		"engine": {
			"integrity": engine_integrity,
			"modifier": get_speed_modifier(),
			"critical": engine_integrity <= ENGINE_CRITICAL,
		},
		"antenna": {
			"misalignment": antenna_misalignment,
			"modifier": 1.0 - get_event_warning_reduction(),
			"critical": antenna_misalignment >= ANTENNA_CRITICAL,
		},
		"solar": {
			"degradation": solar_degradation,
			"modifier": get_solar_power_modifier(),
			"critical": solar_degradation >= SOLAR_CRITICAL,
		},
	}

func get_worst_surface() -> int:
	## Returns the surface type that needs repair most urgently
	var worst_integrity = 1.0
	var worst_type = -1

	for surface_type in [SurfaceType.ENGINE_NOZZLE, SurfaceType.ANTENNA_ARRAY, SurfaceType.SOLAR_PANEL]:
		var integrity = get_integrity(surface_type)
		if integrity < worst_integrity:
			worst_integrity = integrity
			worst_type = surface_type

	return worst_type

# ============================================================================
# SERIALIZATION
# ============================================================================

func save_state() -> Dictionary:
	return {
		"engine_integrity": engine_integrity,
		"antenna_misalignment": antenna_misalignment,
		"solar_degradation": solar_degradation,
	}

func load_state(data: Dictionary) -> void:
	engine_integrity = data.get("engine_integrity", 100.0)
	antenna_misalignment = data.get("antenna_misalignment", 0.0)
	solar_degradation = data.get("solar_degradation", 0.0)

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_status() -> void:
	print("=== EXTERIOR SURFACE STATUS ===")
	print("Engine Nozzle: %.0f%% integrity (speed: %.0f%%)" % [
		engine_integrity, get_speed_modifier() * 100])
	print("Antenna Array: %.0f° misaligned (warning reduction: %.1f days)" % [
		antenna_misalignment, get_event_warning_reduction()])
	print("Solar Panel: %.0f%% degraded (power: %.0f%%)" % [
		solar_degradation, get_solar_power_modifier() * 100])
	print("================================")

func debug_damage_all(amount: float) -> void:
	## Damage all surfaces by amount (for testing)
	damage_surface(SurfaceType.ENGINE_NOZZLE, amount)
	damage_surface(SurfaceType.ANTENNA_ARRAY, amount)
	damage_surface(SurfaceType.SOLAR_PANEL, amount)
