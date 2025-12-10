class_name TravelLogic
extends RefCounted

## Pure functions for space travel calculations and events
## All functions are static, deterministic with provided random values

# ============================================================================
# TRAVEL CALCULATIONS
# ============================================================================

## Calculate total travel time based on engine and launch timing (pure)
static func calc_travel_days(
	engine: Dictionary,
	ship_mass_kg: float,
	days_past_window: int
) -> int:
	var base_days = 180  # Optimal Hohmann transfer window

	# Penalty for missing launch window (each day adds ~0.5 days travel)
	var window_penalty = maxi(0, days_past_window) * 0.5

	# Engine efficiency affects travel time
	var efficiency_factor = _calc_engine_efficiency_factor(engine)

	# Thrust-to-weight affects acceleration capability
	var thrust_factor = _calc_thrust_factor(engine, ship_mass_kg)

	var total_days = int(base_days * efficiency_factor * thrust_factor + window_penalty)
	return maxi(120, total_days)  # Minimum 4 months even with best engines

static func _calc_engine_efficiency_factor(engine: Dictionary) -> float:
	if engine.is_empty():
		return 2.0  # No engine = very slow

	var isp = engine.get("specific_impulse_s", 300.0)
	if isp == INF:
		return 1.2  # Solar/laser sails are slow but steady

	# Higher ISP = more efficient = faster travel
	# Baseline is 3000s (ion engines)
	var factor = 3000.0 / maxf(isp, 100.0)
	return clampf(factor, 0.6, 2.0)

static func _calc_thrust_factor(engine: Dictionary, ship_mass_kg: float) -> float:
	if engine.is_empty() or ship_mass_kg <= 0:
		return 2.0

	var thrust = engine.get("thrust_n", 0.0)
	if thrust <= 0:
		return 1.5

	# Thrust-to-weight ratio (in space, but using Earth g for reference)
	var twr = thrust / (ship_mass_kg * 9.81)

	# Higher TWR = can do faster trajectory
	if twr > 0.1:
		return 0.7  # High thrust chemical/nuclear
	elif twr > 0.001:
		return 0.9  # Medium thrust
	else:
		return 1.1  # Low thrust ion/plasma

## Calculate daily resource consumption (pure)
static func calc_daily_consumption(crew_count: int, has_recycling: bool) -> Dictionary:
	var base_food_kg = 2.0  # kg per person per day
	var base_water_kg = 3.0
	var base_oxygen_kg = 0.84

	var recycling_factor = 0.3 if has_recycling else 1.0  # Life support recycles 70%

	return {
		"food_kg": crew_count * base_food_kg,
		"water_kg": crew_count * base_water_kg * recycling_factor,
		"oxygen_kg": crew_count * base_oxygen_kg * recycling_factor
	}

## Calculate fuel consumption for a day of travel (pure)
static func calc_daily_fuel_consumption(engine: Dictionary, is_accelerating: bool) -> float:
	if engine.is_empty():
		return 0.0

	var consumption_rate = engine.get("fuel_consumption_kg_s", 0.0)
	if not is_accelerating:
		return consumption_rate * 3600.0 * 0.1  # 10% for station keeping

	# Full burn for 1 hour per day average during acceleration phase
	return consumption_rate * 3600.0

## Calculate distance traveled (for progress display) (pure)
static func calc_distance_progress(day: int, total_days: int) -> Dictionary:
	# Simplified: linear progress (real orbital mechanics is more complex)
	var progress_percent = clampf(float(day) / float(total_days), 0.0, 1.0)

	# Earth-Mars distance varies 55-400 million km, use average transfer
	var total_distance_km = 225_000_000.0  # ~225 million km average

	return {
		"progress_percent": progress_percent * 100.0,
		"distance_traveled_km": total_distance_km * progress_percent,
		"distance_remaining_km": total_distance_km * (1.0 - progress_percent),
		"current_day": day,
		"total_days": total_days
	}

# ============================================================================
# TRAVEL EVENTS (pure, deterministic with random values)
# ============================================================================

## Check for daily travel event (pure)
static func check_daily_event(
	state: Dictionary,
	day_in_journey: int,
	random_roll: float,
	event_type_roll: float,
	severity_roll: float
) -> Dictionary:
	# Base 8% chance per day for an event
	var event_chance = 0.08

	# Higher chance in first week (adaptation) and near Mars (radiation)
	if day_in_journey < 7:
		event_chance = 0.15
	elif day_in_journey > state.get("travel_total_days", 180) - 14:
		event_chance = 0.12

	if random_roll >= event_chance:
		return {"event": null, "triggered": false}

	# Determine event type
	var event: Dictionary
	if event_type_roll < 0.15:
		event = _generate_equipment_event(state, severity_roll)
	elif event_type_roll < 0.30:
		event = _generate_health_event(state, severity_roll)
	elif event_type_roll < 0.45:
		event = _generate_morale_event(state, severity_roll)
	elif event_type_roll < 0.55:
		event = _generate_discovery_event(state, severity_roll)
	elif event_type_roll < 0.70:
		event = _generate_supply_event(state, severity_roll)
	elif event_type_roll < 0.85:
		event = _generate_radiation_event(state, severity_roll)
	else:
		event = _generate_communication_event(state, severity_roll)

	return {"event": event, "triggered": true}

static func _generate_equipment_event(state: Dictionary, severity: float) -> Dictionary:
	var components = state.get("ship_components", [])
	if components.is_empty():
		return {"type": "equipment", "description": "Systems nominal", "effects": {}}

	# Find component with lowest quality (most likely to fail)
	var target = null
	var lowest_quality = 101.0
	for comp in components:
		var fail_roll = severity * 100.0
		if comp.quality < lowest_quality and fail_roll > comp.quality:
			lowest_quality = comp.quality
			target = comp

	if target == null:
		return {
			"type": "equipment",
			"subtype": "nominal",
			"description": "Routine diagnostics complete. All systems operational.",
			"effects": {}
		}

	var damage = 5.0 + severity * 15.0
	var new_components = []
	for comp in components:
		if comp.hex_position == target.hex_position:
			new_components.append(GameTypes.with_field(comp, "quality", maxf(0.0, comp.quality - damage)))
		else:
			new_components.append(comp)

	var descriptions = [
		"%s showing abnormal readings. Quality reduced." % target.display_name,
		"Minor malfunction in %s. Repairs attempted." % target.display_name,
		"%s requires recalibration after power surge." % target.display_name,
	]

	return {
		"type": "equipment",
		"subtype": "malfunction",
		"description": descriptions[int(severity * descriptions.size()) % descriptions.size()],
		"effects": {"ship_components": new_components}
	}

static func _generate_health_event(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])
	if crew.is_empty():
		return {"type": "health", "description": "No crew aboard", "effects": {}}

	var target_idx = int(severity * crew.size()) % crew.size()
	var target = crew[target_idx]

	# Severity determines event type
	if severity < 0.3:
		# Minor issue - fatigue
		var new_crew = []
		for i in range(crew.size()):
			if i == target_idx:
				new_crew.append(GameTypes.with_field(crew[i], "fatigue", minf(100.0, crew[i].fatigue + 20.0)))
			else:
				new_crew.append(crew[i])
		return {
			"type": "health",
			"subtype": "fatigue",
			"description": "%s experiencing sleep disruption. Fatigue increased." % target.display_name,
			"effects": {"crew": new_crew}
		}
	elif severity < 0.6:
		# Moderate - minor illness
		if target.is_sick:
			return {"type": "health", "description": "%s still recovering." % target.display_name, "effects": {}}

		var illnesses = ["space adaptation syndrome", "minor infection", "headaches from pressure changes"]
		var illness = illnesses[int(severity * illnesses.size()) % illnesses.size()]

		var new_crew = []
		for i in range(crew.size()):
			if i == target_idx:
				new_crew.append(GameTypes.with_fields(crew[i], {
					"is_sick": true,
					"sickness_type": illness,
					"days_sick": 0
				}))
			else:
				new_crew.append(crew[i])
		return {
			"type": "health",
			"subtype": "illness",
			"description": "%s has developed %s." % [target.display_name, illness],
			"effects": {"crew": new_crew}
		}
	else:
		# Serious - injury
		var new_crew = []
		for i in range(crew.size()):
			if i == target_idx:
				new_crew.append(GameTypes.with_fields(crew[i], {
					"is_injured": true,
					"health": maxf(0.0, crew[i].health - 20.0)
				}))
			else:
				new_crew.append(crew[i])
		return {
			"type": "health",
			"subtype": "injury",
			"description": "%s injured during routine maintenance. Requires medical attention." % target.display_name,
			"effects": {"crew": new_crew}
		}

static func _generate_morale_event(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])
	if crew.is_empty():
		return {"type": "morale", "description": "No crew aboard", "effects": {}}

	var is_positive = severity > 0.5
	var change = 10.0 + (absf(severity - 0.5) * 30.0)
	if not is_positive:
		change = -change

	var new_crew = []
	for member in crew:
		new_crew.append(GameTypes.with_field(member, "morale", clampf(member.morale + change, 0.0, 100.0)))

	var positive_events = [
		"Movie night was a hit! Crew spirits lifted.",
		"Received video messages from family on Earth.",
		"Crew celebrated mission milestone together.",
		"Zero-g sports competition boosted team bonding.",
	]
	var negative_events = [
		"Tension between crew members over duties.",
		"Homesickness affecting the team.",
		"Communication delay with Earth causing frustration.",
		"Monotony of space travel wearing on crew.",
	]

	var events = positive_events if is_positive else negative_events
	var description = events[int(severity * events.size()) % events.size()]

	return {
		"type": "morale",
		"subtype": "positive" if is_positive else "negative",
		"description": description,
		"effects": {"crew": new_crew}
	}

static func _generate_discovery_event(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])

	var discoveries = [
		{"text": "Captured stunning photos of Earth from deep space.", "morale": 15.0},
		{"text": "Observed interesting asteroid passing nearby.", "morale": 10.0},
		{"text": "Conducted successful zero-g experiment.", "morale": 12.0},
		{"text": "Spotted comet tail in the distance.", "morale": 8.0},
	]

	var discovery = discoveries[int(severity * discoveries.size()) % discoveries.size()]

	var new_crew = []
	for member in crew:
		new_crew.append(GameTypes.with_field(member, "morale", minf(100.0, member.morale + discovery.morale)))

	return {
		"type": "discovery",
		"subtype": "observation",
		"description": discovery.text,
		"effects": {"crew": new_crew} if not crew.is_empty() else {}
	}

static func _generate_supply_event(state: Dictionary, severity: float) -> Dictionary:
	if severity < 0.5:
		# Found efficiency - good event
		return {
			"type": "supply",
			"subtype": "efficiency",
			"description": "Crew found ways to reduce water consumption. Supplies will last longer.",
			"effects": {}
		}
	else:
		# Supply issue
		var issues = [
			"Food storage contamination detected. Some rations lost.",
			"Water recycler efficiency dropped temporarily.",
			"Oxygen scrubber needed filter replacement.",
		]
		return {
			"type": "supply",
			"subtype": "loss",
			"description": issues[int(severity * issues.size()) % issues.size()],
			"effects": {}
		}

static func _generate_radiation_event(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])

	if severity < 0.4:
		return {
			"type": "radiation",
			"subtype": "nominal",
			"description": "Solar activity nominal. Radiation levels within safe parameters.",
			"effects": {}
		}

	var radiation_level = 30.0 + severity * 70.0
	var health_loss = (radiation_level - 30.0) * 0.3

	if crew.is_empty():
		return {
			"type": "radiation",
			"subtype": "warning",
			"description": "Solar flare detected. Radiation spike recorded.",
			"effects": {}
		}

	var new_crew = []
	for member in crew:
		new_crew.append(GameTypes.with_field(member, "health", maxf(0.0, member.health - health_loss)))

	return {
		"type": "radiation",
		"subtype": "exposure",
		"description": "Solar particle event! Crew received %.0f mSv exposure. (Health -%.0f)" % [radiation_level, health_loss],
		"effects": {"crew": new_crew}
	}

static func _generate_communication_event(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])

	if severity < 0.3:
		# Good - clear comms
		var morale_boost = 5.0
		var new_crew = []
		for member in crew:
			new_crew.append(GameTypes.with_field(member, "morale", minf(100.0, member.morale + morale_boost)))
		return {
			"type": "communication",
			"subtype": "contact",
			"description": "Crystal clear video call with Mission Control. Updates received.",
			"effects": {"crew": new_crew} if not crew.is_empty() else {}
		}
	elif severity < 0.7:
		# Neutral - signal delay
		return {
			"type": "communication",
			"subtype": "delay",
			"description": "Signal delay now exceeds 10 minutes each way. Communication becoming challenging.",
			"effects": {}
		}
	else:
		# Bad - blackout
		var morale_loss = 8.0
		var new_crew = []
		for member in crew:
			new_crew.append(GameTypes.with_field(member, "morale", maxf(0.0, member.morale - morale_loss)))
		return {
			"type": "communication",
			"subtype": "blackout",
			"description": "Communication blackout due to solar conjunction. No contact with Earth for 24 hours.",
			"effects": {"crew": new_crew} if not crew.is_empty() else {}
		}

# ============================================================================
# CREW ACTIVITIES (pure)
# ============================================================================

## Get available activities for a crew member (pure)
static func get_available_activities() -> Array:
	return [
		{"id": "rest", "name": "Rest", "fatigue_change": -20.0, "morale_change": 5.0, "hours": 8},
		{"id": "exercise", "name": "Exercise", "fatigue_change": 10.0, "morale_change": 5.0, "health_change": 2.0, "hours": 2},
		{"id": "work", "name": "Ship Maintenance", "fatigue_change": 15.0, "morale_change": -2.0, "hours": 6},
		{"id": "science", "name": "Scientific Research", "fatigue_change": 10.0, "morale_change": 3.0, "hours": 4},
		{"id": "social", "name": "Social Time", "fatigue_change": -5.0, "morale_change": 10.0, "hours": 2},
		{"id": "medical", "name": "Medical Checkup", "fatigue_change": 5.0, "health_change": 5.0, "hours": 1},
	]

## Apply activity to crew member (pure)
static func apply_activity(crew: Dictionary, activity: Dictionary) -> Dictionary:
	var updates = {}

	if activity.has("fatigue_change"):
		updates["fatigue"] = clampf(crew.fatigue + activity.fatigue_change, 0.0, 100.0)

	if activity.has("morale_change"):
		updates["morale"] = clampf(crew.morale + activity.morale_change, 0.0, 100.0)

	if activity.has("health_change"):
		updates["health"] = clampf(crew.health + activity.health_change, 0.0, 100.0)

	return GameTypes.with_fields(crew, updates)

# ============================================================================
# ARRIVAL CHECKS (pure)
# ============================================================================

## Check mission status on Mars arrival (pure)
static func check_arrival_status(state: Dictionary) -> Dictionary:
	var crew = state.get("crew", [])
	var components = state.get("ship_components", [])

	var alive_count = 0
	var healthy_count = 0
	for member in crew:
		if member.health > 0:
			alive_count += 1
			if not member.is_sick and not member.is_injured:
				healthy_count += 1

	var avg_quality = 0.0
	if not components.is_empty():
		var total = 0.0
		for comp in components:
			total += comp.quality
		avg_quality = total / components.size()

	var can_land = alive_count > 0 and avg_quality > 20.0

	var issues = []
	if alive_count == 0:
		issues.append("No surviving crew members")
	if avg_quality <= 20.0:
		issues.append("Ship too damaged for Mars orbit insertion")
	if healthy_count == 0 and alive_count > 0:
		issues.append("All crew members incapacitated")

	return {
		"can_land": can_land,
		"alive_crew": alive_count,
		"healthy_crew": healthy_count,
		"ship_quality": avg_quality,
		"issues": issues
	}
