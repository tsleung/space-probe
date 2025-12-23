extends Node
class_name CrisisAI

## AI Controller for Crisis Management
## Automatically assigns crew to crises based on priority and efficiency

const CrisisTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_types.gd")

# ============================================================================
# REFERENCES
# ============================================================================

var crisis_manager: Node  # CrisisManager

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var enabled: bool = true
@export var reaction_delay: float = 0.5  # Seconds before AI reacts to new crisis
@export var reassignment_interval: float = 2.0  # How often to re-evaluate assignments

# ============================================================================
# STATE
# ============================================================================

var reaction_queue: Array = []  # Crises waiting for reaction delay
var reassignment_timer: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func connect_to_manager(manager: Node) -> void:
	crisis_manager = manager
	crisis_manager.crisis_spawned.connect(_on_crisis_spawned)
	crisis_manager.crisis_resolved.connect(_on_crisis_resolved)
	crisis_manager.crisis_escalated.connect(_on_crisis_escalated)

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if not enabled or not crisis_manager:
		return

	# Process reaction queue
	_process_reaction_queue(delta)

	# Periodic reassignment check
	reassignment_timer += delta
	if reassignment_timer >= reassignment_interval:
		reassignment_timer = 0.0
		_evaluate_assignments()

func _process_reaction_queue(delta: float) -> void:
	var to_remove: Array = []

	for i in range(reaction_queue.size()):
		var item = reaction_queue[i]
		item.delay -= delta

		if item.delay <= 0:
			_assign_crew_to_crisis(item.crisis)
			to_remove.append(i)

	# Remove processed items (reverse order to maintain indices)
	for i in range(to_remove.size() - 1, -1, -1):
		reaction_queue.remove_at(to_remove[i])

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_crisis_spawned(crisis: Dictionary) -> void:
	# Queue for assignment after reaction delay
	reaction_queue.append({
		"crisis": crisis,
		"delay": reaction_delay
	})

func _on_crisis_resolved(crisis: Dictionary) -> void:
	# When a crisis resolves, the assigned crew becomes free
	# Re-evaluate if there are unassigned crises
	if crisis_manager.get_unassigned_crises().size() > 0:
		_evaluate_assignments()

func _on_crisis_escalated(crisis: Dictionary, _old_severity: int, new_severity: int) -> void:
	# If crisis escalated to CRITICAL or higher, prioritize it
	if new_severity >= CrisisTypes.Severity.CRITICAL:
		_prioritize_crisis(crisis)

# ============================================================================
# ASSIGNMENT LOGIC
# ============================================================================

func _assign_crew_to_crisis(crisis: Dictionary) -> void:
	## Find the best available crew member for this crisis
	if crisis.assigned_crew != "":
		return  # Already assigned

	var best_crew = _find_best_crew_for_crisis(crisis)
	if best_crew != "":
		crisis_manager.assign_crew(best_crew, crisis.id)

func _find_best_crew_for_crisis(crisis: Dictionary) -> String:
	## Returns the best available crew role, or empty if none available

	var available_crew = _get_available_crew()
	if available_crew.is_empty():
		return ""

	var best_role = ""
	var best_score = -1.0

	for role in available_crew:
		var score = _calculate_crew_score(role, crisis)
		if score > best_score:
			best_score = score
			best_role = role

	return best_role

func _get_available_crew() -> Array:
	## Returns list of crew roles not currently assigned
	var available = []
	for role in ["commander", "engineer", "scientist", "medical"]:
		if not crisis_manager.is_crew_busy(role):
			available.append(role)
	return available

func _calculate_crew_score(crew_role: String, crisis: Dictionary) -> float:
	## Score how well this crew member matches this crisis
	## Higher score = better match

	var score = 0.0

	# Specialist bonus
	var efficiency = CrisisTypes.get_crew_efficiency(crisis, crew_role)
	score += efficiency * 50  # Base efficiency score

	# Severity urgency
	score += crisis.severity * 20

	# Time waiting (prioritize older crises slightly)
	score += min(crisis.total_time * 2, 20)

	return score

func _evaluate_assignments() -> void:
	## Re-evaluate all assignments to optimize
	## May reassign crew if better matches are available

	var unassigned_crises = crisis_manager.get_unassigned_crises()
	if unassigned_crises.is_empty():
		return

	# Sort by urgency (highest severity first, then oldest)
	unassigned_crises.sort_custom(_compare_crisis_urgency)

	# Try to assign each unassigned crisis
	for crisis in unassigned_crises:
		_assign_crew_to_crisis(crisis)

	# Check if we should steal crew from lower-priority crises
	_consider_reassignments()

func _compare_crisis_urgency(a: Dictionary, b: Dictionary) -> bool:
	## Compare function for sorting crises by urgency
	## Returns true if a should come before b
	if a.severity != b.severity:
		return a.severity > b.severity  # Higher severity first
	return a.total_time > b.total_time  # Older first if same severity

func _prioritize_crisis(crisis: Dictionary) -> void:
	## A crisis has become critical - consider stealing crew
	if crisis.assigned_crew != "":
		return  # Already has someone

	# Find any crew working on lower-severity crisis
	var best_steal = ""
	var lowest_severity = crisis.severity

	for role in ["commander", "engineer", "scientist", "medical"]:
		var assignment = crisis_manager.get_crew_assignment(role)
		if assignment == "":
			continue

		var current_crisis = crisis_manager.get_crisis_by_id(assignment)
		if current_crisis.is_empty():
			continue

		if current_crisis.severity < lowest_severity:
			lowest_severity = current_crisis.severity
			best_steal = role

	# Steal the crew member if found
	if best_steal != "":
		print("[AI] Reassigning %s from lower priority crisis to %s!" % [best_steal.capitalize(), crisis.name])
		crisis_manager.assign_crew(best_steal, crisis.id)

func _consider_reassignments() -> void:
	## Check if any crew should be reassigned for better efficiency
	## Called periodically to optimize assignments

	# For now, just ensure critical crises have someone
	var crises = crisis_manager.get_active_crises()

	for crisis in crises:
		if crisis.severity >= CrisisTypes.Severity.CRITICAL and crisis.assigned_crew == "":
			_prioritize_crisis(crisis)

# ============================================================================
# CONTROL
# ============================================================================

func set_enabled(e: bool) -> void:
	enabled = e
	if not enabled:
		reaction_queue.clear()
