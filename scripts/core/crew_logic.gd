class_name CrewLogic
extends RefCounted

## Pure functions for crew operations
## All functions are static, take inputs, return outputs, no side effects

# ============================================================================
# CREW CALCULATIONS
# ============================================================================

## Calculate overall effectiveness based on stats (pure)
static func calc_effectiveness(crew: Dictionary) -> float:
	var health_factor = crew.health / 100.0
	var morale_factor = crew.morale / 100.0
	var fatigue_factor = (100.0 - crew.fatigue) / 100.0

	var effectiveness = health_factor * morale_factor * fatigue_factor

	if crew.is_sick:
		effectiveness *= 0.5
	if crew.is_injured:
		effectiveness *= 0.3

	return clampf(effectiveness, 0.0, 1.0)

## Apply daily updates to crew member (pure)
static func apply_daily_update(crew: Dictionary, random_value: float) -> Dictionary:
	var updates = {}

	# Natural fatigue recovery
	updates["fatigue"] = maxf(0.0, crew.fatigue - 10.0)

	# Morale slowly decays in space
	updates["morale"] = maxf(0.0, crew.morale - 0.5)

	# Sickness progression
	if crew.is_sick:
		var new_days_sick = crew.days_sick + 1
		updates["days_sick"] = new_days_sick
		updates["health"] = maxf(0.0, crew.health - 2.0)

		# Chance to recover after 7 days
		if new_days_sick > 7 and random_value < 0.3:
			updates["is_sick"] = false
			updates["days_sick"] = 0
			updates["sickness_type"] = ""

	return GameTypes.with_fields(crew, updates)

## Apply work fatigue to crew member (pure)
static func apply_work(crew: Dictionary, hours: float) -> Dictionary:
	var new_fatigue = minf(100.0, crew.fatigue + hours * 2.0)
	return GameTypes.with_field(crew, "fatigue", new_fatigue)

## Apply sickness to crew member (pure)
static func apply_sickness(crew: Dictionary, sickness_type: String) -> Dictionary:
	return GameTypes.with_fields(crew, {
		"is_sick": true,
		"sickness_type": sickness_type,
		"days_sick": 0
	})

## Apply injury to crew member (pure)
static func apply_injury(crew: Dictionary) -> Dictionary:
	return GameTypes.with_field(crew, "is_injured", true)

## Heal crew member (pure)
static func apply_healing(crew: Dictionary, health_restored: float) -> Dictionary:
	return GameTypes.with_fields(crew, {
		"health": minf(100.0, crew.health + health_restored),
		"is_injured": false if crew.health + health_restored >= 50.0 else crew.is_injured
	})

## Boost morale (pure)
static func apply_morale_boost(crew: Dictionary, amount: float) -> Dictionary:
	return GameTypes.with_field(crew, "morale", minf(100.0, crew.morale + amount))

## Rest crew member (pure)
static func apply_rest(crew: Dictionary, hours: float) -> Dictionary:
	var fatigue_reduction = hours * 5.0
	var morale_boost = hours * 1.0
	return GameTypes.with_fields(crew, {
		"fatigue": maxf(0.0, crew.fatigue - fatigue_reduction),
		"morale": minf(100.0, crew.morale + morale_boost)
	})

# ============================================================================
# CREW QUERIES
# ============================================================================

static func get_specialty_name(specialty: GameTypes.CrewSpecialty) -> String:
	match specialty:
		GameTypes.CrewSpecialty.COMMANDER: return "Commander"
		GameTypes.CrewSpecialty.PILOT: return "Pilot"
		GameTypes.CrewSpecialty.ENGINEER: return "Engineer"
		GameTypes.CrewSpecialty.SCIENTIST_GEOLOGY: return "Geologist"
		GameTypes.CrewSpecialty.SCIENTIST_BIOLOGY: return "Biologist"
		GameTypes.CrewSpecialty.SCIENTIST_CHEMISTRY: return "Chemist"
		GameTypes.CrewSpecialty.MEDIC: return "Flight Medic"
	return "Crew"

static func get_primary_skill(crew: Dictionary) -> String:
	match crew.specialty:
		GameTypes.CrewSpecialty.COMMANDER: return "skill_leadership"
		GameTypes.CrewSpecialty.PILOT: return "skill_piloting"
		GameTypes.CrewSpecialty.ENGINEER: return "skill_engineering"
		GameTypes.CrewSpecialty.SCIENTIST_GEOLOGY, \
		GameTypes.CrewSpecialty.SCIENTIST_BIOLOGY, \
		GameTypes.CrewSpecialty.SCIENTIST_CHEMISTRY: return "skill_science"
		GameTypes.CrewSpecialty.MEDIC: return "skill_medical"
	return "skill_science"

## Check if crew member can perform task (pure)
static func can_perform_task(crew: Dictionary, min_effectiveness: float = 0.3) -> bool:
	return calc_effectiveness(crew) >= min_effectiveness and not crew.is_injured

## Get crew status summary (pure)
static func get_status_summary(crew: Dictionary) -> String:
	if crew.health <= 0:
		return "Deceased"
	if crew.is_injured:
		return "Injured"
	if crew.is_sick:
		return "Sick: " + crew.sickness_type
	if crew.fatigue > 80:
		return "Exhausted"
	if crew.morale < 20:
		return "Demoralized"
	if crew.fatigue > 50:
		return "Tired"
	return "Healthy"

# ============================================================================
# CREW FACTORY
# ============================================================================

static func create_crew_member(
	name: String,
	specialty: GameTypes.CrewSpecialty,
	random_values: Array  # Array of floats 0-1 for deterministic generation
) -> Dictionary:
	var age = 28 + int(random_values[0] * 27)  # 28-55

	var skills = {
		"skill_piloting": 30.0 + random_values[1] * 40.0,
		"skill_engineering": 30.0 + random_values[2] * 40.0,
		"skill_science": 30.0 + random_values[3] * 40.0,
		"skill_medical": 30.0 + random_values[4] * 40.0,
		"skill_leadership": 30.0 + random_values[5] * 40.0
	}

	# Boost primary skill based on specialty
	match specialty:
		GameTypes.CrewSpecialty.COMMANDER:
			skills["skill_leadership"] = 70.0 + random_values[5] * 25.0
			skills["skill_piloting"] = 60.0 + random_values[1] * 20.0
		GameTypes.CrewSpecialty.PILOT:
			skills["skill_piloting"] = 75.0 + random_values[1] * 20.0
		GameTypes.CrewSpecialty.ENGINEER:
			skills["skill_engineering"] = 75.0 + random_values[2] * 20.0
		GameTypes.CrewSpecialty.SCIENTIST_GEOLOGY, \
		GameTypes.CrewSpecialty.SCIENTIST_BIOLOGY, \
		GameTypes.CrewSpecialty.SCIENTIST_CHEMISTRY:
			skills["skill_science"] = 75.0 + random_values[3] * 20.0
		GameTypes.CrewSpecialty.MEDIC:
			skills["skill_medical"] = 75.0 + random_values[4] * 20.0

	return GameTypes.create_crew_member({
		"id": name.to_lower().replace(" ", "_"),
		"display_name": name,
		"specialty": specialty,
		"age": age,
		"skill_piloting": skills["skill_piloting"],
		"skill_engineering": skills["skill_engineering"],
		"skill_science": skills["skill_science"],
		"skill_medical": skills["skill_medical"],
		"skill_leadership": skills["skill_leadership"]
	})

# ============================================================================
# TEAM CALCULATIONS
# ============================================================================

## Calculate average team effectiveness (pure)
static func calc_team_effectiveness(crew_list: Array) -> float:
	if crew_list.is_empty():
		return 0.0

	var total = 0.0
	for crew in crew_list:
		total += calc_effectiveness(crew)
	return total / crew_list.size()

## Calculate team skill average for a specific skill (pure)
static func calc_team_skill(crew_list: Array, skill_name: String) -> float:
	if crew_list.is_empty():
		return 0.0

	var total = 0.0
	for crew in crew_list:
		total += crew.get(skill_name, 0.0) * calc_effectiveness(crew)
	return total / crew_list.size()

## Count healthy crew members (pure)
static func count_healthy(crew_list: Array) -> int:
	var count = 0
	for crew in crew_list:
		if crew.health > 0 and not crew.is_injured and not crew.is_sick:
			count += 1
	return count

## Count alive crew members (pure)
static func count_alive(crew_list: Array) -> int:
	var count = 0
	for crew in crew_list:
		if crew.health > 0:
			count += 1
	return count
