extends RefCounted
class_name MCSPolitics

## MCS (Mars Colony Sim) Political Logic - SIMPLIFIED
## Only handles stability and basic faction standings
## All functions are static and deterministic

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")

# ============================================================================
# CONSTANTS
# ============================================================================

const STABILITY_DECAY_RATE = 2.0
const STABILITY_RECOVERY_RATE = 5.0

# ============================================================================
# FACTION MANAGEMENT (simplified)
# ============================================================================

## Update faction standings based on conditions (simplified)
static func update_faction_standings(politics: Dictionary, colonists: Array, resources: Dictionary) -> Dictionary:
	var standings = politics.get("faction_standings", {}).duplicate()

	# Simple drift based on resource state
	var food = resources.get("food", 0.0)
	if food < 100:
		standings[_MCSTypes.Faction.PRAGMATISTS] = minf(100, standings.get(_MCSTypes.Faction.PRAGMATISTS, 50) + 2.0)

	# Mars-born influence grows over time
	var mars_born = 0
	var total = 0
	for c in colonists:
		if c.is_alive:
			total += 1
			if c.generation != _MCSTypes.Generation.EARTH_BORN:
				mars_born += 1

	if total > 0 and float(mars_born) / float(total) > 0.5:
		standings[_MCSTypes.Faction.MARTIANS] = minf(100, standings.get(_MCSTypes.Faction.MARTIANS, 50) + 1.0)

	return _MCSTypes.with_field(politics, "faction_standings", standings)

# ============================================================================
# STABILITY (simplified)
# ============================================================================

## Update political stability (simplified - single function)
static func update_stability(politics: Dictionary, colonists_or_change = null, resources: Dictionary = {}, has_shortage: bool = false) -> Dictionary:
	var change = 0.0

	# If second param is a number, use it directly (for event effects)
	if colonists_or_change is float or colonists_or_change is int:
		change = float(colonists_or_change)
	elif colonists_or_change is Array:
		# Calculate from conditions
		var colonists: Array = colonists_or_change

		# Resource conditions
		if not has_shortage:
			change += 1.0  # Stable when no shortages
		else:
			change -= 5.0  # Shortage is destabilizing

		# Population morale
		var avg_morale = _calc_average_morale(colonists)
		if avg_morale >= 70:
			change += 2.0
		elif avg_morale >= 50:
			change += 0.5
		elif avg_morale < 30:
			change -= 3.0

	var new_stability = clampf(politics.get("stability", 75.0) + change, 0.0, 100.0)
	return _MCSTypes.with_field(politics, "stability", new_stability)

static func _calc_average_morale(colonists: Array) -> float:
	var total = 0.0
	var count = 0

	for c in colonists:
		if c.is_alive and c.life_stage == _MCSTypes.LifeStage.ADULT:
			total += c.morale
			count += 1

	return total / maxf(count, 1.0)

# ============================================================================
# ELECTIONS (simplified stub)
# ============================================================================

## Hold an election - simplified to just boost stability
static func hold_election(politics: Dictionary, colonists: Array, random_values: Array) -> Dictionary:
	var new_politics = update_stability(politics, 5.0)  # Elections boost stability

	return {
		"politics": new_politics,
		"summary": "Colony council elected democratically."
	}

# ============================================================================
# INDEPENDENCE (simplified stub)
# ============================================================================

## Hold independence vote - simplified
static func hold_independence_vote(politics: Dictionary, colonists: Array, random_value: float) -> Dictionary:
	# Simple majority based on Mars-born ratio
	var mars_born = 0
	var total = 0
	for c in colonists:
		if c.is_alive and c.life_stage == _MCSTypes.LifeStage.ADULT:
			total += 1
			if c.generation != _MCSTypes.Generation.EARTH_BORN:
				mars_born += 1

	var mars_ratio = float(mars_born) / maxf(float(total), 1.0)
	var passed = mars_ratio > 0.5 and random_value < (mars_ratio + 0.2)

	var new_politics = politics.duplicate(true)
	if passed:
		new_politics.independence_declared = true

	return {
		"politics": new_politics,
		"passed": passed
	}

## Get system name (for display)
static func get_system_name(system: _MCSTypes.PoliticalSystem) -> String:
	match system:
		_MCSTypes.PoliticalSystem.MISSION_COMMAND:
			return "Mission Command"
		_MCSTypes.PoliticalSystem.ADVISORY_COUNCIL:
			return "Advisory Council"
		_MCSTypes.PoliticalSystem.REPRESENTATIVE:
			return "Representative Government"
		_MCSTypes.PoliticalSystem.CONSTITUTIONAL:
			return "Constitutional Government"
		_MCSTypes.PoliticalSystem.INDEPENDENT_STATE:
			return "Independent State"
	return "Unknown"
