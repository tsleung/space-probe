## Crew management system.
## Handles stats, relationships, tasks, and status effects.
##
## All functions are static and pure.
class_name CrewSystem
extends RefCounted


## ============================================================================
## DAILY UPDATES
## ============================================================================

## Apply daily stat changes to all crew
static func apply_daily_update(
	state: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	for i in range(crew.size()):
		var member = crew[i]

		# Skip dead crew
		if member.get("status") == GameTypes.CrewStatus.DEAD:
			continue

		# Apply base decay
		member = _apply_stat_decay(member, balance)

		# Apply condition effects
		member = _apply_condition_effects(member, balance)

		# Check for sickness recovery
		member = _check_sickness_recovery(member, balance, rng)

		# Update status based on health
		member = _update_status(member, balance)

		crew[i] = member

	new_state["crew"] = crew
	return new_state


## Apply base stat decay
static func _apply_stat_decay(member: Dictionary, balance: Dictionary) -> Dictionary:
	var new_member = member.duplicate(true)

	# Morale decay
	var morale_decay = balance.get("morale_decay_per_day", 0.5)
	new_member["morale"] = max(0, new_member.get("morale", 75) - morale_decay)

	# Health decay (mitigated by medical bay)
	var health_decay = balance.get("health_decay_per_day", 0.5)
	new_member["health"] = max(0, new_member.get("health", 100) - health_decay)

	# Fatigue accumulates if working
	if new_member.get("current_task") and new_member.get("current_task") != "rest":
		new_member["fatigue"] = min(100, new_member.get("fatigue", 0) + 5)

	return new_member


## Apply condition effects (illness, injury, etc.)
static func _apply_condition_effects(member: Dictionary, balance: Dictionary) -> Dictionary:
	var new_member = member.duplicate(true)
	var conditions = new_member.get("conditions", [])

	for condition in conditions:
		var condition_id = condition.get("id", "")

		# Sickness damage
		if condition_id in ["moderate_illness", "severe_illness"]:
			var health_loss = balance.get("sickness_health_loss_per_day", 2)
			new_member["health"] = max(0, new_member.get("health", 100) - health_loss)

	return new_member


## Check for sickness recovery
static func _check_sickness_recovery(member: Dictionary, balance: Dictionary, rng: RNGManager) -> Dictionary:
	var new_member = member.duplicate(true)
	var conditions = new_member.get("conditions", [])
	var new_conditions = []

	for condition in conditions:
		var days_with = condition.get("days_with", 0) + 1
		condition["days_with"] = days_with

		# Check recovery for sickness
		if condition.get("id", "").ends_with("_illness"):
			var recovery_days = balance.get("sickness_recovery_days", 7)
			var recovery_chance = balance.get("sickness_recovery_chance", 0.3)

			if days_with >= recovery_days and rng.check(recovery_chance):
				# Recovered!
				continue

		new_conditions.append(condition)

	new_member["conditions"] = new_conditions
	return new_member


## Update crew status based on health
static func _update_status(member: Dictionary, balance: Dictionary) -> Dictionary:
	var new_member = member.duplicate(true)
	var health = new_member.get("health", 100)

	var death_threshold = balance.get("death_health_threshold", 0)
	var critical_threshold = balance.get("critical_health_threshold", 20)
	var impaired_threshold = balance.get("impaired_health_threshold", 50)

	if health <= death_threshold:
		new_member["status"] = GameTypes.CrewStatus.DEAD
	elif health < critical_threshold:
		new_member["status"] = GameTypes.CrewStatus.CRITICAL
	elif health < impaired_threshold:
		new_member["status"] = GameTypes.CrewStatus.INJURED
	else:
		# Check for sickness
		var has_sickness = false
		for condition in new_member.get("conditions", []):
			if condition.get("id", "").ends_with("_illness"):
				has_sickness = true
				break

		if has_sickness:
			new_member["status"] = GameTypes.CrewStatus.SICK
		else:
			new_member["status"] = GameTypes.CrewStatus.HEALTHY

	return new_member


## ============================================================================
## EFFECTIVENESS CALCULATION
## ============================================================================

## Calculate crew member effectiveness (0.0 to 1.0+)
static func calculate_effectiveness(member: Dictionary, balance: Dictionary) -> float:
	var health = member.get("health", 100)
	var morale = member.get("morale", 75)
	var fatigue = member.get("fatigue", 0)

	# Base effectiveness
	var effectiveness = (health / 100.0) * (morale / 100.0) * ((100.0 - fatigue) / 100.0)

	# Apply condition modifiers
	for condition in member.get("conditions", []):
		var modifier = condition.get("effectiveness_multiplier", 1.0)
		effectiveness *= modifier

	# Apply trait modifiers
	for trait_data in member.get("traits", []):
		var effects = trait_data.get("effect", trait_data.get("effects", {}))
		if effects.has("effectiveness_multiplier"):
			effectiveness *= effects.effectiveness_multiplier

	return effectiveness


## Calculate skill check success chance
static func calculate_skill_check(
	member: Dictionary,
	skill: String,
	difficulty: float,
	balance: Dictionary
) -> float:
	var base_skill = member.get("skills", {}).get(skill, 50)
	var effectiveness = calculate_effectiveness(member, balance)
	var skill_bonus = balance.get("skill_check_bonus", 0)

	# Base success chance
	var success_chance = (1.0 - difficulty) + (base_skill / 100.0) * 0.5 + (skill_bonus / 100.0)

	# Apply effectiveness
	success_chance *= effectiveness

	# Clamp to reasonable range
	return clamp(success_chance, 0.1, 0.95)


## Get effective skill level (skill modified by effectiveness)
static func get_effective_skill(member: Dictionary, skill: String, balance: Dictionary) -> float:
	var base_skill = member.get("skills", {}).get(skill, 50)
	var effectiveness = calculate_effectiveness(member, balance)
	return base_skill * effectiveness


## ============================================================================
## TASK MANAGEMENT
## ============================================================================

## Assign task to crew member
static func assign_task(state: Dictionary, crew_id: String, task: String) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			crew[i]["current_task"] = task
			break

	new_state["crew"] = crew
	return new_state


## Apply task effects
static func apply_task_effects(
	state: Dictionary,
	crew_id: String,
	task: String,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])
	var activity = balance.get("activities", {}).get(task, {})

	for i in range(crew.size()):
		if crew[i].get("id") != crew_id:
			continue

		var member = crew[i]

		# Apply stat changes
		if activity.has("fatigue"):
			member["fatigue"] = clamp(member.get("fatigue", 0) + activity.fatigue, 0, 100)

		if activity.has("morale"):
			var morale_change = activity.morale
			morale_change = _apply_personality_modifier(member, morale_change, "morale")
			member["morale"] = clamp(member.get("morale", 75) + morale_change, 0, 100)

		if activity.has("health"):
			member["health"] = clamp(member.get("health", 100) + activity.health, 0, 100)

		# Apply skill bonus if applicable
		var skill_threshold = activity.get("skill_bonus_threshold", 0)
		var skill_bonus_morale = activity.get("skill_bonus_morale", 0)
		if skill_threshold > 0:
			var relevant_skill = _get_task_skill(task)
			if member.get("skills", {}).get(relevant_skill, 0) > skill_threshold:
				member["morale"] = clamp(member.get("morale", 75) + skill_bonus_morale, 0, 100)

		crew[i] = member
		break

	new_state["crew"] = crew
	return new_state


## Get relevant skill for a task
static func _get_task_skill(task: String) -> String:
	match task:
		"repair":
			return "engineering"
		"medical":
			return "medical"
		"research":
			return "science"
		"monitor", "piloting":
			return "piloting"
		_:
			return "leadership"


## ============================================================================
## PERSONALITY AND TRAITS
## ============================================================================

## Apply personality modifier to a value
static func _apply_personality_modifier(member: Dictionary, value: float, stat: String) -> float:
	var traits = member.get("traits", [])
	var result = value

	for trait_data in traits:
		var effects = trait_data.get("effect", trait_data.get("effects", {}))

		# Morale modifiers
		if stat == "morale":
			if value > 0 and effects.has("positive_morale_multiplier"):
				result *= effects.positive_morale_multiplier
			elif value < 0 and effects.has("negative_morale_multiplier"):
				result *= effects.negative_morale_multiplier

			if effects.has("morale_swing_multiplier"):
				result *= effects.morale_swing_multiplier

	return result


## Get trait effect value
static func get_trait_effect(member: Dictionary, effect_name: String, default: float = 1.0) -> float:
	for trait_data in member.get("traits", []):
		var effects = trait_data.get("effect", trait_data.get("effects", {}))
		if effects.has(effect_name):
			return effects[effect_name]

	return default


## ============================================================================
## RELATIONSHIPS
## ============================================================================

## Update relationship between two crew members
static func update_relationship(
	state: Dictionary,
	crew1_id: String,
	crew2_id: String,
	amount: float,
	balance: Dictionary
) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])
	var max_rel = balance.get("relationship_max", 100)
	var min_rel = balance.get("relationship_min", 0)

	for i in range(crew.size()):
		if crew[i].get("id") == crew1_id:
			var relationships = crew[i].get("relationships", {})
			var current = relationships.get(crew2_id, balance.get("relationship_start", 50))
			relationships[crew2_id] = clamp(current + amount, min_rel, max_rel)
			crew[i]["relationships"] = relationships

		if crew[i].get("id") == crew2_id:
			var relationships = crew[i].get("relationships", {})
			var current = relationships.get(crew1_id, balance.get("relationship_start", 50))
			relationships[crew1_id] = clamp(current + amount, min_rel, max_rel)
			crew[i]["relationships"] = relationships

	new_state["crew"] = crew
	return new_state


## Get relationship level between two crew members
static func get_relationship(state: Dictionary, crew1_id: String, crew2_id: String) -> float:
	var crew = state.get("crew", [])

	for member in crew:
		if member.get("id") == crew1_id:
			return member.get("relationships", {}).get(crew2_id, 50)

	return 50


## ============================================================================
## CREW QUERIES
## ============================================================================

## Get crew member by ID
static func get_crew_by_id(state: Dictionary, crew_id: String) -> Dictionary:
	for member in state.get("crew", []):
		if member.get("id") == crew_id:
			return member
	return {}


## Get all living crew
static func get_living_crew(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in state.get("crew", []):
		if member.get("status") != GameTypes.CrewStatus.DEAD:
			result.append(member)
	return result


## Get crew by specialty
static func get_crew_by_specialty(state: Dictionary, specialty: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in state.get("crew", []):
		if member.get("specialty") == specialty or member.get("role") == specialty:
			result.append(member)
	return result


## Get best crew member for a skill
static func get_best_for_skill(state: Dictionary, skill: String, balance: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_skill: float = -1

	for member in get_living_crew(state):
		var effective_skill = get_effective_skill(member, skill, balance)
		if effective_skill > best_skill:
			best_skill = effective_skill
			best = member

	return best


## Get average morale
static func get_average_morale(state: Dictionary) -> float:
	var living = get_living_crew(state)
	if living.is_empty():
		return 0

	var total: float = 0
	for member in living:
		total += member.get("morale", 75)

	return total / living.size()


## ============================================================================
## STAT MODIFICATIONS
## ============================================================================

## Modify crew member stat
static func modify_stat(
	state: Dictionary,
	crew_id: String,
	stat: String,
	amount: float
) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			var current = crew[i].get(stat, 100 if stat == "health" else 75)
			var max_val = 100
			crew[i][stat] = clamp(current + amount, 0, max_val)
			break

	new_state["crew"] = crew
	return new_state


## Apply condition to crew member
static func add_condition(
	state: Dictionary,
	crew_id: String,
	condition_id: String,
	condition_data: Dictionary = {}
) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			var conditions = crew[i].get("conditions", [])
			conditions.append({
				"id": condition_id,
				"days_with": 0
			}.merged(condition_data))
			crew[i]["conditions"] = conditions
			break

	new_state["crew"] = crew
	return new_state


## Remove condition from crew member
static func remove_condition(
	state: Dictionary,
	crew_id: String,
	condition_id: String
) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			var conditions = crew[i].get("conditions", [])
			var new_conditions = []
			for condition in conditions:
				if condition.get("id") != condition_id:
					new_conditions.append(condition)
			crew[i]["conditions"] = new_conditions
			break

	new_state["crew"] = crew
	return new_state
