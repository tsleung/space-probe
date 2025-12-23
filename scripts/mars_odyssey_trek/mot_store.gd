extends Node
class_name MOTStore

## Mars Odyssey Trek - State Store
## Manages game state for MOT using Redux-like pattern
## Pure state transformations via MOTReducer

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: Dictionary)
signal phase_changed(new_phase: int)
signal budget_changed(remaining: int)
signal launch_window_changed(window: Dictionary)
signal ship_config_changed()
signal crew_changed(crew: Array)
signal cargo_changed(manifest: Dictionary)
signal readiness_changed(is_ready: bool, issues: Array)

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Initialize with default Phase 1 state
	_state = MOTTypes.create_phase1_state("normal")
	state_changed.emit(_state)

func start_new_game(difficulty: String = "normal") -> void:
	_state = MOTTypes.create_phase1_state(difficulty)
	state_changed.emit(_state)
	phase_changed.emit(_state.phase)
	budget_changed.emit(_state.budget_remaining)

# ============================================================================
# STATE ACCESS
# ============================================================================

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_phase() -> int:
	return _state.get("phase", MOTTypes.Phase.SHIP_BUILDING)

func get_budget_remaining() -> int:
	return _state.get("budget_remaining", 0)

func get_launch_window() -> Dictionary:
	var window = _state.get("launch_window")
	return window if window else {}

func get_ship_class() -> int:
	return _state.get("ship_class", -1)

func get_cargo_capacity() -> int:
	return _state.get("cargo_capacity", 0)

func get_cargo_used() -> int:
	return _state.get("cargo_used", 0)

func is_ready_to_launch() -> bool:
	return _state.get("is_ready_to_launch", false)

# ============================================================================
# ACTIONS - LAUNCH WINDOW
# ============================================================================

func set_launch_window(window: RefCounted) -> void:
	var old_state = _state.duplicate(true)

	_state.launch_window = window.get_summary()
	_state.travel_days_estimate = window.travel_days
	_state.fuel_required = _calculate_fuel_required(window.fuel_multiplier)

	_update_readiness()
	_emit_changes(old_state)
	launch_window_changed.emit(_state.launch_window)

func _calculate_fuel_required(fuel_multiplier: float) -> int:
	# Base fuel depends on engine type
	var base_fuel = 10000  # kg
	if _state.engine != null:
		match _state.engine:
			MOTTypes.EngineType.CHEMICAL:
				base_fuel = 15000
			MOTTypes.EngineType.ION_DRIVE:
				base_fuel = 3000
			MOTTypes.EngineType.NUCLEAR_THERMAL:
				base_fuel = 8000
			MOTTypes.EngineType.SOLAR_SAIL:
				base_fuel = 0

	return int(base_fuel * fuel_multiplier)

# ============================================================================
# ACTIONS - CONSTRUCTION
# ============================================================================

func set_construction_approach(approach: int) -> void:
	var old_state = _state.duplicate(true)
	_state.construction_approach = approach
	_recalculate_reliability()
	_update_readiness()
	_emit_changes(old_state)
	ship_config_changed.emit()

func set_engine(engine: int) -> void:
	var old_state = _state.duplicate(true)

	_state.engine = engine
	_recalculate_costs()
	_recalculate_reliability()

	# Recalculate fuel if window already selected
	if _state.launch_window:
		_state.fuel_required = _calculate_fuel_required(_state.launch_window.fuel_multiplier)

	_update_readiness()
	_emit_changes(old_state)
	ship_config_changed.emit()

func set_ship_class(ship_class: int) -> void:
	var old_state = _state.duplicate(true)

	_state.ship_class = ship_class
	_state.cargo_capacity = MOTTypes.SHIP_CLASSES[ship_class].cargo_capacity

	_recalculate_costs()
	_recalculate_reliability()
	_update_readiness()
	_emit_changes(old_state)
	ship_config_changed.emit()

func set_life_support(tier: int) -> void:
	var old_state = _state.duplicate(true)

	_state.life_support = tier
	_recalculate_costs()
	_recalculate_reliability()
	_update_readiness()
	_emit_changes(old_state)
	ship_config_changed.emit()

func add_upgrade(upgrade_id: String) -> bool:
	if upgrade_id in _state.upgrades:
		return false  # Already have it

	if not MOTTypes.SHIP_UPGRADES.has(upgrade_id):
		return false  # Invalid upgrade

	var old_state = _state.duplicate(true)

	_state.upgrades.append(upgrade_id)

	# Apply cargo bonus if applicable
	var upgrade = MOTTypes.SHIP_UPGRADES[upgrade_id]
	if upgrade.effects.has("cargo_bonus"):
		_state.cargo_capacity += upgrade.effects.cargo_bonus

	_recalculate_costs()
	_update_readiness()
	_emit_changes(old_state)
	ship_config_changed.emit()
	return true

func remove_upgrade(upgrade_id: String) -> bool:
	if not upgrade_id in _state.upgrades:
		return false

	var old_state = _state.duplicate(true)

	_state.upgrades.erase(upgrade_id)

	# Remove cargo bonus if applicable
	var upgrade = MOTTypes.SHIP_UPGRADES[upgrade_id]
	if upgrade.effects.has("cargo_bonus"):
		_state.cargo_capacity -= upgrade.effects.cargo_bonus

	_recalculate_costs()
	_update_readiness()
	_emit_changes(old_state)
	ship_config_changed.emit()
	return true

# ============================================================================
# ACTIONS - CREW
# ============================================================================

func add_crew_member(crew_id: String) -> bool:
	if _state.crew.size() >= 4:
		return false  # Max crew

	if crew_id in _state.crew:
		return false  # Already added

	var old_state = _state.duplicate(true)
	_state.crew.append(crew_id)
	_update_readiness()
	_emit_changes(old_state)
	crew_changed.emit(_state.crew)
	return true

func remove_crew_member(crew_id: String) -> bool:
	if not crew_id in _state.crew:
		return false

	var old_state = _state.duplicate(true)
	_state.crew.erase(crew_id)
	_update_readiness()
	_emit_changes(old_state)
	crew_changed.emit(_state.crew)
	return true

# ============================================================================
# ACTIONS - CARGO
# ============================================================================

func set_cargo(category: String, amount: int) -> void:
	var old_state = _state.duplicate(true)

	if _state.cargo_manifest.has(category):
		_state.cargo_manifest[category] = amount
		_recalculate_cargo_used()
		_update_readiness()
		_emit_changes(old_state)
		cargo_changed.emit(_state.cargo_manifest)

func _recalculate_cargo_used() -> void:
	var used = 0
	# Each category has different kg per unit
	used += _state.cargo_manifest.food_days * 2  # 2 kg per day of food
	used += _state.cargo_manifest.water_reserve * 10  # 10 kg per reserve unit
	used += _state.cargo_manifest.spare_parts * 50  # 50 kg per spare parts kit
	used += _state.cargo_manifest.medical_kits * 20  # 20 kg per medical kit
	used += _state.cargo_manifest.equipment * 100  # 100 kg per equipment unit
	_state.cargo_used = used

# ============================================================================
# INTERNAL CALCULATIONS
# ============================================================================

func _recalculate_costs() -> void:
	var breakdown = MOTTypes.calculate_budget_breakdown(_state)
	_state.budget_spent = breakdown.total
	_state.budget_remaining = breakdown.remaining

func _recalculate_reliability() -> void:
	var reliability = 0.9  # Base

	if _state.construction_approach != null:
		reliability *= MOTTypes.CONSTRUCTION_APPROACHES[_state.construction_approach].reliability

	if _state.engine != null:
		var engine = MOTTypes.ENGINES[_state.engine]
		reliability *= (1.0 - engine.risk)

	if _state.ship_class != null:
		reliability *= MOTTypes.SHIP_CLASSES[_state.ship_class].durability

	_state.reliability_estimate = reliability

func _update_readiness() -> void:
	var readiness = MOTTypes.check_launch_readiness(_state)
	_state.is_ready_to_launch = readiness.is_ready
	_state.readiness_issues = readiness.issues
	readiness_changed.emit(readiness.is_ready, readiness.issues)

func _emit_changes(old_state: Dictionary) -> void:
	state_changed.emit(_state)

	if old_state.budget_remaining != _state.budget_remaining:
		budget_changed.emit(_state.budget_remaining)

	if old_state.phase != _state.phase:
		phase_changed.emit(_state.phase)

# ============================================================================
# LAUNCH
# ============================================================================

func can_launch() -> bool:
	return _state.is_ready_to_launch

func launch() -> bool:
	## Transition to Phase 2
	if not can_launch():
		return false

	var old_state = _state.duplicate(true)

	_state.phase = MOTTypes.Phase.TRAVEL_TO_MARS
	# Additional transition logic would go here

	_emit_changes(old_state)
	return true
