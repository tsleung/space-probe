extends Node
class_name CrisisManager

## Real-Time Crisis Manager
## Handles spawning, escalation, resource drain, and resolution of crises
## This is the core of the "Overcooked" experience

const CrisisTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_types.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal crisis_spawned(crisis: Dictionary)
signal crisis_escalated(crisis: Dictionary, old_severity: int, new_severity: int)
signal crisis_resolved(crisis: Dictionary)
signal crew_assigned(crisis_id: String, crew_role: String)
signal crew_unassigned(crisis_id: String, crew_role: String)
signal resource_drained(resource: String, amount: float)
signal catastrophe(crisis: Dictionary, effect: String)

# ============================================================================
# STATE
# ============================================================================

var active_crises: Dictionary = {}  # crisis_id -> crisis dict
var crew_assignments: Dictionary = {}  # crew_role -> crisis_id (or empty)

# Timing
var spawn_timer: float = 0.0
var spawn_interval: float = CrisisTypes.CRISIS_CHECK_INTERVAL

# Difficulty scaling
var journey_progress: float = 0.0  # 0.0 to 1.0
var crisis_intensity: float = 1.0  # Multiplier for spawn chance

# Pause state
var paused: bool = false

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var enabled: bool = true
@export var max_crises: int = CrisisTypes.MAX_ACTIVE_CRISES
@export var base_spawn_chance: float = CrisisTypes.BASE_SPAWN_CHANCE

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Initialize crew assignments
	crew_assignments = {
		"commander": "",
		"engineer": "",
		"scientist": "",
		"medical": ""
	}

# ============================================================================
# PROCESS LOOP
# ============================================================================

func _process(delta: float) -> void:
	if not enabled or paused:
		return

	# Update all active crises
	_update_crises(delta)

	# Check for spawning new crises
	_update_spawn_timer(delta)

func _update_crises(delta: float) -> void:
	var to_remove: Array = []

	for crisis_id in active_crises:
		var crisis = active_crises[crisis_id]

		# Update timing
		crisis.time_in_severity += delta
		crisis.total_time += delta

		# Check for escalation
		_check_escalation(crisis)

		# Apply resource drain
		_apply_drain(crisis, delta)

		# Update fix progress if crew assigned
		if crisis.assigned_crew != "":
			_update_fix_progress(crisis, delta)

			# Check if fixed
			if crisis.fix_progress >= 1.0:
				to_remove.append(crisis_id)
				crisis_resolved.emit(crisis)

		# Check for catastrophic effects
		if crisis.severity == CrisisTypes.Severity.CATASTROPHIC:
			_check_catastrophic_effects(crisis, delta)

	# Remove resolved crises
	for crisis_id in to_remove:
		_remove_crisis(crisis_id)

func _update_spawn_timer(delta: float) -> void:
	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_try_spawn_crisis()

# ============================================================================
# CRISIS SPAWNING
# ============================================================================

func _try_spawn_crisis() -> void:
	# Don't spawn if at max
	if active_crises.size() >= max_crises:
		return

	# Calculate spawn chance with journey escalation curve
	# Based on crisis management game design principles:
	# - Quiet early phase (0-15%): Fewer crises, let player learn
	# - Building tension (15-50%): Normal crisis rate
	# - Midpoint peak (50-55%): Crisis intensity spikes
	# - Late game pressure (55-90%): Sustained high pressure
	# - Final approach (90-100%): Slight reduction for landing focus

	var phase_multiplier = _get_phase_multiplier(journey_progress)
	var spawn_chance = base_spawn_chance * crisis_intensity * phase_multiplier

	# Active crisis count affects spawn rate (pressure mechanic)
	# More crises = slightly lower chance of new ones (cascading but not overwhelming)
	var load_factor = 1.0 - (active_crises.size() * 0.15)
	spawn_chance *= max(0.3, load_factor)

	if randf() < spawn_chance:
		spawn_random_crisis()

func _get_phase_multiplier(progress: float) -> float:
	## Return spawn rate multiplier based on journey phase
	## Creates escalating difficulty curve with peaks and valleys
	if progress < 0.15:
		# Early phase: 50% spawn rate (learning period)
		return 0.5
	elif progress < 0.50:
		# Building tension: Normal rate, slowly increasing
		return 0.7 + (progress - 0.15) * 0.86  # 0.7 to 1.0
	elif progress < 0.55:
		# Midpoint crisis peak: 150% spawn rate
		return 1.5
	elif progress < 0.90:
		# Late game: High sustained pressure
		return 1.2
	else:
		# Final approach: Slightly reduced (focus on arrival)
		return 0.8

func spawn_random_crisis() -> void:
	var crisis_type = CrisisTypes.get_random_crisis_type()

	# For FIRE, pick a random room
	var room_override = null
	if crisis_type == CrisisTypes.CrisisType.FIRE:
		room_override = CrisisTypes.get_random_room()

	spawn_crisis(crisis_type, room_override)

func spawn_crisis(crisis_type: CrisisTypes.CrisisType, room_override = null) -> Dictionary:
	var crisis = CrisisTypes.create_crisis(crisis_type, room_override)
	active_crises[crisis.id] = crisis
	crisis_spawned.emit(crisis)
	print("[CRISIS] Spawned: %s in %s" % [crisis.name, _get_room_name(crisis.room)])
	return crisis

func _get_room_name(room) -> String:
	if room == null:
		return "Unknown"
	return ShipTypes.get_room_name(room)

# ============================================================================
# ESCALATION
# ============================================================================

func _check_escalation(crisis: Dictionary) -> void:
	var current_severity = crisis.severity
	var base_escalation_time = CrisisTypes.get_escalation_time(current_severity)

	# -1 means no further escalation
	if base_escalation_time < 0:
		return

	# Crises escalate faster later in the journey (pressure mechanic)
	# Early game: 120% time (more forgiving)
	# Mid game: 100% time (normal)
	# Late game: 80% time (more urgent)
	var escalation_multiplier = _get_escalation_speed_multiplier()
	var escalation_time = base_escalation_time * escalation_multiplier

	if crisis.time_in_severity >= escalation_time:
		var old_severity = current_severity
		crisis.severity = _get_next_severity(current_severity)
		crisis.time_in_severity = 0.0
		crisis_escalated.emit(crisis, old_severity, crisis.severity)
		print("[CRISIS] %s escalated to %s!" % [crisis.name, CrisisTypes.get_severity_name(crisis.severity)])

func _get_escalation_speed_multiplier() -> float:
	## Crises escalate faster as journey progresses
	if journey_progress < 0.25:
		return 1.2  # 20% slower escalation early on
	elif journey_progress < 0.75:
		return 1.0  # Normal speed
	else:
		return 0.8  # 20% faster escalation late game

func _get_next_severity(current: CrisisTypes.Severity) -> CrisisTypes.Severity:
	match current:
		CrisisTypes.Severity.EMERGING: return CrisisTypes.Severity.ACTIVE
		CrisisTypes.Severity.ACTIVE: return CrisisTypes.Severity.CRITICAL
		CrisisTypes.Severity.CRITICAL: return CrisisTypes.Severity.CATASTROPHIC
		_: return CrisisTypes.Severity.CATASTROPHIC

# ============================================================================
# RESOURCE DRAIN
# ============================================================================

func _apply_drain(crisis: Dictionary, delta: float) -> void:
	var resource = crisis.resource_drain
	if resource == "none" or resource == "":
		return

	var base_rate = crisis.drain_rate
	var multiplier = CrisisTypes.get_drain_multiplier(crisis.severity)
	var drain_amount = base_rate * multiplier * delta

	resource_drained.emit(resource, drain_amount)

# ============================================================================
# CREW ASSIGNMENT
# ============================================================================

func assign_crew(crew_role: String, crisis_id: String) -> bool:
	## Assign a crew member to fix a crisis
	## Returns true if assignment successful

	# Check if crisis exists
	if not active_crises.has(crisis_id):
		return false

	# Unassign from current crisis if any
	var current_assignment = crew_assignments.get(crew_role, "")
	if current_assignment != "":
		unassign_crew(crew_role)

	# Assign to new crisis
	crew_assignments[crew_role] = crisis_id
	active_crises[crisis_id].assigned_crew = crew_role
	crew_assigned.emit(crisis_id, crew_role)
	print("[CRISIS] %s assigned to %s" % [crew_role.capitalize(), active_crises[crisis_id].name])
	return true

func unassign_crew(crew_role: String) -> void:
	## Remove crew from their current crisis assignment
	var crisis_id = crew_assignments.get(crew_role, "")
	if crisis_id == "":
		return

	crew_assignments[crew_role] = ""
	if active_crises.has(crisis_id):
		active_crises[crisis_id].assigned_crew = ""
		crew_unassigned.emit(crisis_id, crew_role)

func get_crew_assignment(crew_role: String) -> String:
	## Returns crisis_id or empty string
	return crew_assignments.get(crew_role, "")

func is_crew_busy(crew_role: String) -> bool:
	return crew_assignments.get(crew_role, "") != ""

# ============================================================================
# FIX PROGRESS
# ============================================================================

func _update_fix_progress(crisis: Dictionary, delta: float) -> void:
	var crew_role = crisis.assigned_crew
	if crew_role == "":
		return

	# Calculate fix speed
	var efficiency = CrisisTypes.get_crew_efficiency(crisis, crew_role)
	var fix_rate = efficiency / crisis.fix_time  # Progress per second

	crisis.fix_progress += fix_rate * delta

# ============================================================================
# CATASTROPHIC EFFECTS
# ============================================================================

func _check_catastrophic_effects(crisis: Dictionary, _delta: float) -> void:
	## Handle special effects when crisis reaches CATASTROPHIC
	var special = crisis.get("special", "")

	if special == "breach_risk" and randf() < 0.01:  # 1% per frame chance
		catastrophe.emit(crisis, "hull_breach")

	if special == "spreads" and randf() < 0.005:  # 0.5% per frame chance
		_spread_fire(crisis)

func _spread_fire(fire_crisis: Dictionary) -> void:
	## Fire spreads to an adjacent room
	if active_crises.size() >= max_crises:
		return

	var new_room = CrisisTypes.get_random_room()
	if new_room != fire_crisis.room:
		var new_fire = spawn_crisis(CrisisTypes.CrisisType.FIRE, new_room)
		print("[CRISIS] Fire spread to %s!" % _get_room_name(new_room))

# ============================================================================
# CRISIS REMOVAL
# ============================================================================

func _remove_crisis(crisis_id: String) -> void:
	if not active_crises.has(crisis_id):
		return

	var crisis = active_crises[crisis_id]

	# Unassign crew
	if crisis.assigned_crew != "":
		crew_assignments[crisis.assigned_crew] = ""

	active_crises.erase(crisis_id)
	print("[CRISIS] Resolved: %s" % crisis.name)

func clear_all_crises() -> void:
	## Debug: clear all active crises
	for crisis_id in active_crises.keys():
		_remove_crisis(crisis_id)

# ============================================================================
# GETTERS
# ============================================================================

func get_active_crises() -> Array:
	return active_crises.values()

func get_crisis_count() -> int:
	return active_crises.size()

func get_crisis_by_id(crisis_id: String) -> Dictionary:
	return active_crises.get(crisis_id, {})

func get_crisis_at_room(room: ShipTypes.RoomType) -> Dictionary:
	for crisis in active_crises.values():
		if crisis.room == room:
			return crisis
	return {}

func get_most_urgent_crisis() -> Dictionary:
	## Returns the crisis with highest severity, or longest duration if tied
	var most_urgent = {}
	var highest_score = -1

	for crisis in active_crises.values():
		var score = crisis.severity * 1000 + crisis.total_time
		if score > highest_score:
			highest_score = score
			most_urgent = crisis

	return most_urgent

func get_unassigned_crises() -> Array:
	var result = []
	for crisis in active_crises.values():
		if crisis.assigned_crew == "":
			result.append(crisis)
	return result

# ============================================================================
# CONTROL
# ============================================================================

func set_paused(p: bool) -> void:
	paused = p

func set_journey_progress(progress: float) -> void:
	journey_progress = clamp(progress, 0.0, 1.0)

func set_intensity(intensity: float) -> void:
	crisis_intensity = max(0.0, intensity)

# ============================================================================
# DEBUG
# ============================================================================

func debug_spawn_crisis(crisis_type: CrisisTypes.CrisisType) -> void:
	spawn_crisis(crisis_type)

func debug_spawn_random() -> void:
	spawn_random_crisis()
