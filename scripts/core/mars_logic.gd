class_name MarsLogic
extends RefCounted

## Pure functions for Mars surface operations
## All functions are static, deterministic with provided random values

# ============================================================================
# EXPERIMENT DEFINITIONS
# ============================================================================

static func get_all_experiments() -> Array:
	return [
		{
			"id": "soil_analysis",
			"name": "Soil Composition Analysis",
			"description": "Analyze Martian soil samples for mineral content and potential biosignatures.",
			"required_skill": "skill_science",
			"difficulty": 0.4,
			"duration_hours": 6,
			"sample_type": "soil",
			"samples_required": 3
		},
		{
			"id": "ice_core",
			"name": "Ice Core Extraction",
			"description": "Drill and analyze subsurface ice deposits for water content and history.",
			"required_skill": "skill_science",
			"difficulty": 0.6,
			"duration_hours": 8,
			"sample_type": "ice",
			"samples_required": 2
		},
		{
			"id": "atmosphere_study",
			"name": "Atmospheric Analysis",
			"description": "Study Martian atmosphere composition and weather patterns.",
			"required_skill": "skill_science",
			"difficulty": 0.3,
			"duration_hours": 4,
			"sample_type": "atmosphere",
			"samples_required": 5
		},
		{
			"id": "geology_survey",
			"name": "Geological Survey",
			"description": "Map and analyze rock formations for Mars history.",
			"required_skill": "skill_science",
			"difficulty": 0.5,
			"duration_hours": 8,
			"sample_type": "soil",
			"samples_required": 4
		},
		{
			"id": "radiation_study",
			"name": "Radiation Measurement",
			"description": "Measure surface radiation levels for future colonization.",
			"required_skill": "skill_engineering",
			"difficulty": 0.3,
			"duration_hours": 3,
			"sample_type": "atmosphere",
			"samples_required": 0
		},
		{
			"id": "hab_test",
			"name": "Habitat Stress Test",
			"description": "Test habitat systems under Martian conditions.",
			"required_skill": "skill_engineering",
			"difficulty": 0.4,
			"duration_hours": 6,
			"sample_type": null,
			"samples_required": 0
		},
		{
			"id": "rover_expedition",
			"name": "Rover Expedition",
			"description": "Extended rover mission to distant geological features.",
			"required_skill": "skill_piloting",
			"difficulty": 0.5,
			"duration_hours": 10,
			"sample_type": "soil",
			"samples_required": 5
		},
		{
			"id": "medical_study",
			"name": "Low Gravity Medical Study",
			"description": "Study effects of Mars gravity on human physiology.",
			"required_skill": "skill_medical",
			"difficulty": 0.4,
			"duration_hours": 4,
			"sample_type": null,
			"samples_required": 0
		}
	]

static func get_experiment_by_id(id: String) -> Dictionary:
	for exp in get_all_experiments():
		if exp.id == id:
			return exp
	return {}

# ============================================================================
# EXPERIMENT CALCULATIONS
# ============================================================================

## Calculate experiment success chance (pure)
static func calc_experiment_success_chance(
	experiment: Dictionary,
	crew: Dictionary
) -> float:
	var base_chance = 1.0 - experiment.difficulty
	var skill_name = experiment.required_skill
	var crew_skill = crew.get(skill_name, 50.0) / 100.0
	var effectiveness = CrewLogic.calc_effectiveness(crew)

	return clampf(base_chance * crew_skill * effectiveness, 0.1, 0.95)

## Check experiment outcome (pure, deterministic)
static func check_experiment_outcome(
	experiment: Dictionary,
	crew: Dictionary,
	random_value: float
) -> Dictionary:
	var success_chance = calc_experiment_success_chance(experiment, crew)
	var success = random_value < success_chance

	if success:
		return {
			"success": true,
			"samples_collected": experiment.samples_required,
			"sample_type": experiment.sample_type,
			"description": "Experiment completed successfully!"
		}
	else:
		# Partial success on close rolls
		if random_value < success_chance + 0.2:
			var partial_samples = experiment.samples_required / 2
			return {
				"success": false,
				"partial": true,
				"samples_collected": partial_samples,
				"sample_type": experiment.sample_type,
				"description": "Partial results obtained. Some samples collected."
			}
		else:
			return {
				"success": false,
				"partial": false,
				"samples_collected": 0,
				"sample_type": null,
				"description": "Experiment failed. Equipment malfunction or conditions unsuitable."
			}

# ============================================================================
# BASE OPERATIONS
# ============================================================================

## Get available daily activities on Mars (pure)
static func get_mars_activities() -> Array:
	return [
		{"id": "rest", "name": "Rest in Hab", "fatigue_change": -25.0, "morale_change": 5.0, "hours": 8},
		{"id": "maintenance", "name": "Base Maintenance", "fatigue_change": 15.0, "morale_change": -3.0, "hours": 4},
		{"id": "eva", "name": "EVA (Spacewalk)", "fatigue_change": 20.0, "morale_change": 10.0, "hours": 4},
		{"id": "sample_collection", "name": "Sample Collection", "fatigue_change": 15.0, "morale_change": 5.0, "hours": 6},
		{"id": "communication", "name": "Earth Communication", "fatigue_change": 5.0, "morale_change": 15.0, "hours": 2},
		{"id": "exercise", "name": "Exercise", "fatigue_change": 10.0, "morale_change": 5.0, "health_change": 3.0, "hours": 2}
	]

## Apply Mars activity to crew (pure)
static func apply_mars_activity(crew: Dictionary, activity: Dictionary) -> Dictionary:
	var updates = {}

	if activity.has("fatigue_change"):
		updates["fatigue"] = clampf(crew.fatigue + activity.fatigue_change, 0.0, 100.0)

	if activity.has("morale_change"):
		updates["morale"] = clampf(crew.morale + activity.morale_change, 0.0, 100.0)

	if activity.has("health_change"):
		updates["health"] = clampf(crew.health + activity.health_change, 0.0, 100.0)

	return GameTypes.with_fields(crew, updates)

# ============================================================================
# MARS EVENTS
# ============================================================================

## Check for daily Mars event (pure)
static func check_daily_event(
	state: Dictionary,
	sol: int,
	random_roll: float,
	event_type_roll: float,
	severity_roll: float
) -> Dictionary:
	# 10% base chance per sol
	var event_chance = 0.10

	if random_roll >= event_chance:
		return {"event": null, "triggered": false}

	var event: Dictionary
	if event_type_roll < 0.25:
		event = _generate_dust_storm_event(state, severity_roll)
	elif event_type_roll < 0.45:
		event = _generate_equipment_event(state, severity_roll)
	elif event_type_roll < 0.65:
		event = _generate_discovery_event(state, severity_roll)
	elif event_type_roll < 0.80:
		event = _generate_health_event(state, severity_roll)
	else:
		event = _generate_supply_event(state, severity_roll)

	return {"event": event, "triggered": true}

static func _generate_dust_storm_event(state: Dictionary, severity: float) -> Dictionary:
	if severity < 0.3:
		return {
			"type": "weather",
			"subtype": "dust_minor",
			"description": "Minor dust devil spotted near base. No impact on operations.",
			"effects": {}
		}
	elif severity < 0.7:
		# Moderate storm - can't do EVA
		return {
			"type": "weather",
			"subtype": "dust_moderate",
			"description": "Dust storm approaching. EVA operations suspended for today.",
			"effects": {"eva_blocked": true}
		}
	else:
		# Major storm - damages equipment
		var crew = state.get("crew", [])
		var new_crew = []
		for member in crew:
			new_crew.append(GameTypes.with_field(member, "morale", maxf(0.0, member.morale - 10.0)))

		return {
			"type": "weather",
			"subtype": "dust_major",
			"description": "Major dust storm! All personnel confined to habitat. Morale decreased.",
			"effects": {"crew": new_crew, "eva_blocked": true}
		}

static func _generate_equipment_event(state: Dictionary, severity: float) -> Dictionary:
	var equipment_issues = [
		{"name": "water recycler", "severity_threshold": 0.3},
		{"name": "oxygen generator", "severity_threshold": 0.5},
		{"name": "solar panel array", "severity_threshold": 0.4},
		{"name": "rover battery", "severity_threshold": 0.2}
	]

	for issue in equipment_issues:
		if severity < issue.severity_threshold:
			return {
				"type": "equipment",
				"subtype": "minor",
				"description": "%s showing minor issues. Crew performed repairs." % issue.name.capitalize(),
				"effects": {}
			}

	# Major failure
	return {
		"type": "equipment",
		"subtype": "major",
		"description": "Critical equipment failure! Emergency repairs needed.",
		"effects": {}
	}

static func _generate_discovery_event(state: Dictionary, severity: float) -> Dictionary:
	var discoveries = [
		{"text": "Unusual mineral formation discovered nearby!", "morale": 15.0, "samples": 2, "type": "soil"},
		{"text": "Possible ancient water channel identified!", "morale": 20.0, "samples": 0, "type": null},
		{"text": "Interesting atmospheric phenomenon observed!", "morale": 10.0, "samples": 1, "type": "atmosphere"},
		{"text": "Subsurface ice deposit located!", "morale": 18.0, "samples": 3, "type": "ice"}
	]

	var discovery = discoveries[int(severity * discoveries.size()) % discoveries.size()]

	var crew = state.get("crew", [])
	var new_crew = []
	for member in crew:
		new_crew.append(GameTypes.with_field(member, "morale", minf(100.0, member.morale + discovery.morale)))

	var effects = {"crew": new_crew}

	if discovery.samples > 0 and discovery.type:
		var samples = state.get("samples_collected", {}).duplicate()
		samples[discovery.type] = samples.get(discovery.type, 0) + discovery.samples
		effects["samples_collected"] = samples

	return {
		"type": "discovery",
		"subtype": "science",
		"description": discovery.text,
		"effects": effects
	}

static func _generate_health_event(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])
	if crew.is_empty():
		return {"type": "health", "description": "No crew", "effects": {}}

	var target_idx = int(severity * crew.size()) % crew.size()
	var target = crew[target_idx]

	if severity < 0.5:
		# Minor health issue
		var new_crew = []
		for i in range(crew.size()):
			if i == target_idx:
				new_crew.append(GameTypes.with_field(crew[i], "fatigue", minf(100.0, crew[i].fatigue + 15.0)))
			else:
				new_crew.append(crew[i])
		return {
			"type": "health",
			"subtype": "minor",
			"description": "%s experiencing fatigue from low gravity adaptation." % target.display_name,
			"effects": {"crew": new_crew}
		}
	else:
		# More serious
		var new_crew = []
		for i in range(crew.size()):
			if i == target_idx:
				new_crew.append(GameTypes.with_fields(crew[i], {
					"health": maxf(0.0, crew[i].health - 10.0),
					"is_sick": true,
					"sickness_type": "Mars adaptation syndrome"
				}))
			else:
				new_crew.append(crew[i])
		return {
			"type": "health",
			"subtype": "serious",
			"description": "%s has developed Mars adaptation syndrome." % target.display_name,
			"effects": {"crew": new_crew}
		}

static func _generate_supply_event(state: Dictionary, severity: float) -> Dictionary:
	if severity < 0.5:
		return {
			"type": "supply",
			"subtype": "good",
			"description": "Inventory check complete. Supplies well organized.",
			"effects": {}
		}
	else:
		return {
			"type": "supply",
			"subtype": "issue",
			"description": "Some food supplies found damaged. Rationing may be needed.",
			"effects": {}
		}

# ============================================================================
# MISSION COMPLETION CHECKS
# ============================================================================

## Check if mission objectives are complete (pure)
static func check_mission_complete(state: Dictionary) -> Dictionary:
	var experiments_completed = state.get("experiments_completed", [])
	var samples = state.get("samples_collected", {})

	var required_experiments = ["soil_analysis", "ice_core", "atmosphere_study"]
	var experiments_done = 0
	for req in required_experiments:
		if req in experiments_completed:
			experiments_done += 1

	var total_samples = samples.get("soil", 0) + samples.get("ice", 0) + samples.get("atmosphere", 0)
	var samples_target = 15

	var can_return = experiments_done >= 2 and total_samples >= 10

	return {
		"experiments_required": required_experiments.size(),
		"experiments_done": experiments_done,
		"samples_collected": total_samples,
		"samples_target": samples_target,
		"can_return": can_return,
		"mission_success": experiments_done >= required_experiments.size() and total_samples >= samples_target
	}

## Calculate mission score (pure)
static func calc_mission_score(state: Dictionary) -> Dictionary:
	var crew = state.get("crew", [])
	var experiments = state.get("experiments_completed", [])
	var samples = state.get("samples_collected", {})

	var crew_alive = 0
	var crew_healthy = 0
	for member in crew:
		if member.health > 0:
			crew_alive += 1
			if not member.is_sick and not member.is_injured:
				crew_healthy += 1

	var total_samples = samples.get("soil", 0) + samples.get("ice", 0) + samples.get("atmosphere", 0)

	var score = 0
	score += crew_alive * 1000  # Each surviving crew
	score += crew_healthy * 500  # Bonus for healthy crew
	score += experiments.size() * 500  # Each experiment
	score += total_samples * 100  # Each sample

	var grade = "F"
	if score >= 8000:
		grade = "A"
	elif score >= 6000:
		grade = "B"
	elif score >= 4000:
		grade = "C"
	elif score >= 2000:
		grade = "D"

	return {
		"score": score,
		"grade": grade,
		"crew_alive": crew_alive,
		"crew_healthy": crew_healthy,
		"experiments": experiments.size(),
		"samples": total_samples
	}
