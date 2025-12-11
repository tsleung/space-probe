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
static func calc_daily_consumption(crew_count: int, life_support_quality: float) -> Dictionary:
	var base_food_kg = 2.0  # kg per person per day
	var base_water_kg = 3.0
	var base_oxygen_kg = 0.84

	# Life support quality affects recycling efficiency (0% quality = no recycling, 100% = 85% recycling)
	var recycling_efficiency = (life_support_quality / 100.0) * 0.85
	var water_factor = 1.0 - recycling_efficiency  # 15-100% consumption
	var oxygen_factor = 1.0 - recycling_efficiency

	return {
		"food_kg": crew_count * base_food_kg,  # Food can't be recycled
		"water_kg": crew_count * base_water_kg * water_factor,
		"oxygen_kg": crew_count * base_oxygen_kg * oxygen_factor
	}

## Calculate recommended supplies for a journey (pure)
static func calc_recommended_supplies(crew_count: int, travel_days: int, safety_margin: float = 1.3) -> Dictionary:
	# Assume decent (70%) life support for baseline calculations
	var daily = calc_daily_consumption(crew_count, 70.0)
	return {
		"food_kg": daily.food_kg * travel_days * safety_margin,
		"water_kg": daily.water_kg * travel_days * safety_margin,
		"oxygen_kg": daily.oxygen_kg * travel_days * safety_margin
	}

## Apply daily supply consumption to state, returns updated supplies and any critical events (pure)
static func consume_daily_supplies(supplies: Dictionary, crew: Array, components: Array) -> Dictionary:
	var alive_crew = 0
	for member in crew:
		if member.health > 0:
			alive_crew += 1

	if alive_crew == 0:
		return {"supplies": supplies, "events": [], "crew_updates": {}}

	# Find life support quality
	var life_support_quality = 70.0  # Default
	for comp in components:
		if comp.id == "life_support":
			life_support_quality = comp.quality
			break

	var consumption = calc_daily_consumption(alive_crew, life_support_quality)
	var new_supplies = supplies.duplicate()
	var events: Array = []
	var crew_updates: Dictionary = {}  # crew_id -> updates

	# Consume food
	new_supplies.food_kg = maxf(0.0, supplies.food_kg - consumption.food_kg)
	if new_supplies.food_kg <= 0 and supplies.food_kg > 0:
		events.append({"type": "critical", "resource": "food", "message": "FOOD DEPLETED! Crew is starving!"})
	elif new_supplies.food_kg < consumption.food_kg * 7:
		events.append({"type": "warning", "resource": "food", "message": "Food supplies critically low! Less than 7 days remaining."})

	# Consume water
	new_supplies.water_kg = maxf(0.0, supplies.water_kg - consumption.water_kg)
	if new_supplies.water_kg <= 0 and supplies.water_kg > 0:
		events.append({"type": "critical", "resource": "water", "message": "WATER DEPLETED! Crew is dehydrating!"})
	elif new_supplies.water_kg < consumption.water_kg * 7:
		events.append({"type": "warning", "resource": "water", "message": "Water supplies critically low! Less than 7 days remaining."})

	# Consume oxygen
	new_supplies.oxygen_kg = maxf(0.0, supplies.oxygen_kg - consumption.oxygen_kg)
	if new_supplies.oxygen_kg <= 0 and supplies.oxygen_kg > 0:
		events.append({"type": "critical", "resource": "oxygen", "message": "OXYGEN DEPLETED! Crew is suffocating!"})
	elif new_supplies.oxygen_kg < consumption.oxygen_kg * 3:
		events.append({"type": "warning", "resource": "oxygen", "message": "OXYGEN CRITICAL! Less than 3 days remaining!"})

	# Apply starvation/dehydration/suffocation effects to crew
	for i in range(crew.size()):
		var member = crew[i]
		if member.health <= 0:
			continue

		var updates = {}

		# Starvation: -5 health per day without food
		if new_supplies.food_kg <= 0:
			updates["health"] = maxf(0.0, member.health - 5.0)
			updates["morale"] = maxf(0.0, member.morale - 10.0)

		# Dehydration: -10 health per day without water
		if new_supplies.water_kg <= 0:
			var current_health = updates.get("health", member.health)
			updates["health"] = maxf(0.0, current_health - 10.0)
			updates["morale"] = maxf(0.0, updates.get("morale", member.morale) - 15.0)

		# Suffocation: -25 health per day without oxygen (rapid death)
		if new_supplies.oxygen_kg <= 0:
			var current_health = updates.get("health", member.health)
			updates["health"] = maxf(0.0, current_health - 25.0)

		if not updates.is_empty():
			crew_updates[member.id] = updates

	return {
		"supplies": new_supplies,
		"events": events,
		"crew_updates": crew_updates,
		"consumption": consumption
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

	# Severity determines damage amount
	var damage = 5.0 + severity * 20.0

	# Critical failure - component destroyed if quality drops to 0
	var new_quality = maxf(0.0, target.quality - damage)
	var is_critical = new_quality <= 0 and target.quality > 0

	var new_components = []
	for comp in components:
		if comp.hex_position == target.hex_position:
			new_components.append(GameTypes.with_field(comp, "quality", new_quality))
		else:
			new_components.append(comp)

	var description: String
	if is_critical:
		description = "CRITICAL FAILURE: %s has been destroyed! System offline." % target.display_name
	elif severity > 0.7:
		description = "SERIOUS DAMAGE: %s critically damaged! Quality now %.0f%%" % [target.display_name, new_quality]
	else:
		var minor_descriptions = [
			"%s showing abnormal readings. Quality now %.0f%%." % [target.display_name, new_quality],
			"Minor malfunction in %s. Quality now %.0f%%." % [target.display_name, new_quality],
			"%s requires recalibration. Quality now %.0f%%." % [target.display_name, new_quality],
		]
		description = minor_descriptions[int(severity * minor_descriptions.size()) % minor_descriptions.size()]

	return {
		"type": "equipment",
		"subtype": "critical" if is_critical else "malfunction",
		"description": description,
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
	var supplies = state.get("supplies", {})

	if severity < 0.4:
		# Found efficiency - good event, gain supplies
		var bonus = 10.0 + severity * 20.0
		var new_supplies = supplies.duplicate()
		new_supplies["water_kg"] = supplies.get("water_kg", 0.0) + bonus
		return {
			"type": "supply",
			"subtype": "efficiency",
			"description": "Crew optimized water recycling! Gained %.0f kg water." % bonus,
			"effects": {"supplies": new_supplies}
		}
	elif severity < 0.7:
		# Minor supply loss
		var loss_pct = 0.05 + (severity - 0.4) * 0.1  # 5-8% loss
		var new_supplies = supplies.duplicate()

		# Pick which supply is affected
		var supply_types = ["food_kg", "water_kg", "oxygen_kg"]
		var affected = supply_types[int(severity * 10) % 3]
		var loss = supplies.get(affected, 0.0) * loss_pct
		new_supplies[affected] = maxf(0.0, supplies.get(affected, 0.0) - loss)

		var descriptions = {
			"food_kg": "Food storage contamination detected. Lost %.0f kg of rations." % loss,
			"water_kg": "Water recycler malfunction. Lost %.0f kg of water." % loss,
			"oxygen_kg": "Oxygen tank micro-leak detected. Lost %.0f kg of O2." % loss
		}

		return {
			"type": "supply",
			"subtype": "loss",
			"description": descriptions[affected],
			"effects": {"supplies": new_supplies}
		}
	else:
		# Major supply crisis
		var loss_pct = 0.1 + (severity - 0.7) * 0.2  # 10-16% loss
		var new_supplies = supplies.duplicate()
		var affected = "food_kg" if severity < 0.85 else "oxygen_kg"
		var loss = supplies.get(affected, 0.0) * loss_pct
		new_supplies[affected] = maxf(0.0, supplies.get(affected, 0.0) - loss)

		var descriptions = {
			"food_kg": "CRITICAL: Cargo bay depressurization! Lost %.0f kg of food supplies!" % loss,
			"oxygen_kg": "EMERGENCY: Main O2 tank breach! Lost %.0f kg of oxygen!" % loss
		}

		return {
			"type": "supply",
			"subtype": "critical",
			"description": descriptions[affected],
			"effects": {"supplies": new_supplies}
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
		{
			"id": "rest",
			"name": "Rest",
			"description": "Sleep and recover. Reduces fatigue significantly.",
			"fatigue_change": -25.0,
			"morale_change": 3.0,
			"hours": 8,
			"requires_resource": null
		},
		{
			"id": "exercise",
			"name": "Exercise",
			"description": "Use the gym to maintain health. Causes some fatigue.",
			"fatigue_change": 15.0,
			"morale_change": 5.0,
			"health_change": 3.0,
			"hours": 2,
			"requires_resource": null
		},
		{
			"id": "repair",
			"name": "Repair Systems",
			"description": "Fix damaged components. Uses 1 spare part. Engineer bonus.",
			"fatigue_change": 20.0,
			"morale_change": -3.0,
			"hours": 6,
			"requires_resource": "spare_parts",
			"resource_cost": 1,
			"repair_amount": 15.0,  # Base quality restored
			"skill_used": "skill_engineering"
		},
		{
			"id": "medical",
			"name": "Medical Treatment",
			"description": "Treat injuries/illness. Uses 1 medical kit. Medic bonus.",
			"fatigue_change": 5.0,
			"hours": 4,
			"requires_resource": "medical_kits",
			"resource_cost": 1,
			"heal_amount": 25.0,  # Base health restored
			"cure_chance": 0.6,   # Base chance to cure sickness
			"skill_used": "skill_medical"
		},
		{
			"id": "science",
			"name": "Scientific Research",
			"description": "Conduct experiments. Boosts morale for scientists.",
			"fatigue_change": 10.0,
			"morale_change": 5.0,
			"hours": 4,
			"requires_resource": null,
			"skill_used": "skill_science"
		},
		{
			"id": "social",
			"name": "Social Time",
			"description": "Bond with crew. Great for morale recovery.",
			"fatigue_change": -5.0,
			"morale_change": 12.0,
			"hours": 2,
			"requires_resource": null
		},
		{
			"id": "monitor",
			"name": "Monitor Systems",
			"description": "Watch for problems. May prevent equipment failures.",
			"fatigue_change": 10.0,
			"morale_change": -2.0,
			"hours": 4,
			"requires_resource": null,
			"prevents_failures": true,
			"skill_used": "skill_engineering"
		},
		{
			"id": "ration_food",
			"name": "Ration Food",
			"description": "Reduce food consumption by 30% today. Health/morale penalty.",
			"fatigue_change": 0.0,
			"morale_change": -8.0,
			"health_change": -2.0,
			"hours": 0,
			"requires_resource": null,
			"reduces_consumption": {"food_kg": 0.3}
		}
	]

## Apply activity to crew member (pure) - returns crew updates and any side effects
static func apply_activity(crew: Dictionary, activity: Dictionary) -> Dictionary:
	var updates = {}

	# Track hours used
	var hours = activity.get("hours", 0)
	updates["hours_used_today"] = crew.get("hours_used_today", 0) + hours

	if activity.has("fatigue_change"):
		updates["fatigue"] = clampf(crew.fatigue + activity.fatigue_change, 0.0, 100.0)

	if activity.has("morale_change"):
		# Skill bonus for matching activities
		var morale_bonus = activity.morale_change
		if activity.has("skill_used"):
			var skill_value = crew.get(activity.skill_used, 50.0)
			if skill_value > 70:
				morale_bonus += 3.0  # Experts enjoy their work more
		updates["morale"] = clampf(crew.morale + morale_bonus, 0.0, 100.0)

	if activity.has("health_change"):
		updates["health"] = clampf(crew.health + activity.health_change, 0.0, 100.0)

	return GameTypes.with_fields(crew, updates)

## Apply repair activity - returns result with component updates and resource cost (pure)
static func apply_repair_activity(
	crew: Dictionary,
	components: Array,
	spare_parts: int,
	random_value: float
) -> Dictionary:
	if spare_parts <= 0:
		return {"success": false, "reason": "No spare parts available"}

	# Find most damaged component
	var worst_component = null
	var worst_quality = 100.0
	var worst_index = -1
	for i in range(components.size()):
		if components[i].quality < worst_quality and components[i].quality < 90:
			worst_quality = components[i].quality
			worst_component = components[i]
			worst_index = i

	if worst_component == null:
		return {"success": false, "reason": "No components need repair"}

	# Calculate repair amount based on engineer skill (SIGNIFICANT impact!)
	var skill = crew.get("skill_engineering", 50.0)
	var base_repair = 10.0  # Lower base, more skill dependent
	var skill_bonus = (skill - 50.0) / 50.0 * 25.0  # -25 to +25 based on skill (unskilled: 5-15, expert: 25-45)
	var random_factor = 0.8 + random_value * 0.4  # 0.8 to 1.2

	# Specialty bonus - engineers get 20% more effectiveness
	var specialty = crew.get("specialty", -1)
	var specialty_mult = 1.2 if specialty == GameTypes.CrewSpecialty.ENGINEER else 1.0

	var repair_amount = (base_repair + skill_bonus) * random_factor * specialty_mult

	# Apply repair
	var new_components = components.duplicate()
	var new_quality = minf(100.0, worst_component.quality + repair_amount)
	new_components[worst_index] = GameTypes.with_field(worst_component, "quality", new_quality)

	return {
		"success": true,
		"components": new_components,
		"spare_parts_used": 1,
		"component_repaired": worst_component.display_name,
		"quality_restored": repair_amount,
		"new_quality": new_quality
	}

## Apply medical treatment activity (pure)
static func apply_medical_activity(
	patient: Dictionary,
	medic: Dictionary,
	medical_kits: int,
	random_value: float
) -> Dictionary:
	if medical_kits <= 0:
		return {"success": false, "reason": "No medical kits available"}

	if patient.health >= 100 and not patient.is_sick and not patient.is_injured:
		return {"success": false, "reason": "Patient doesn't need treatment"}

	var medic_skill = medic.get("skill_medical", 50.0)
	var updates = {}
	var results = []

	# Specialty bonus - medics get 25% more effectiveness
	var specialty = medic.get("specialty", -1)
	var specialty_mult = 1.25 if specialty == GameTypes.CrewSpecialty.MEDIC else 1.0

	# Heal health (SIGNIFICANT skill impact!)
	var base_heal = 15.0  # Lower base, more skill dependent
	var skill_bonus = (medic_skill - 50.0) / 50.0 * 25.0  # -25 to +25 (unskilled: 5-20, expert: 30-50)
	var heal_amount = (base_heal + skill_bonus) * (0.8 + random_value * 0.4) * specialty_mult
	updates["health"] = minf(100.0, patient.health + heal_amount)
	results.append("Restored %.0f health" % heal_amount)

	# Try to cure sickness (skill matters A LOT!)
	if patient.is_sick:
		# Cure chance: 30% base, up to 90% with high skill (non-medics struggle)
		var cure_chance = 0.3 + (medic_skill / 100.0) * 0.6  # 30-90% based on skill
		if specialty == GameTypes.CrewSpecialty.MEDIC:
			cure_chance = minf(0.95, cure_chance + 0.15)  # Medics get +15% cure chance
		if random_value < cure_chance:
			updates["is_sick"] = false
			updates["sickness_type"] = ""
			updates["days_sick"] = 0
			results.append("Cured %s" % patient.sickness_type)
		else:
			results.append("Sickness persists (%.0f%% cure chance)" % (cure_chance * 100))

	# Heal injuries
	if patient.is_injured and updates.get("health", patient.health) >= 50:
		updates["is_injured"] = false
		results.append("Injury treated")

	return {
		"success": true,
		"patient_updates": updates,
		"medical_kits_used": 1,
		"results": results
	}

# ============================================================================
# CRISIS EVENTS - Hard choices that define the game
# ============================================================================

## Generate crisis events - these pause the game and require player decision (pure)
static func generate_crisis_event(state: Dictionary, event_type_roll: float, severity_roll: float) -> Dictionary:
	# Pick crisis type based on roll
	if event_type_roll < 0.25:
		return _generate_life_support_crisis(state, severity_roll)
	elif event_type_roll < 0.5:
		return _generate_medical_crisis(state, severity_roll)
	elif event_type_roll < 0.75:
		return _generate_supply_crisis(state, severity_roll)
	else:
		return _generate_crew_conflict(state, severity_roll)

static func _generate_life_support_crisis(state: Dictionary, severity: float) -> Dictionary:
	var supplies = state.get("supplies", {})
	var spare_parts = int(supplies.get("spare_parts", 0))

	return {
		"type": "crisis",
		"id": "life_support_failure",
		"title": "LIFE SUPPORT MALFUNCTION",
		"description": "Warning alarms blare throughout the ship. The life support system is failing!\n\nOxygen recycling has dropped to 40% efficiency. Without action, you'll burn through oxygen reserves twice as fast.",
		"choices": [
			{
				"id": "a",
				"text": "Emergency repair (uses 2 spare parts)" if spare_parts >= 2 else "Emergency repair [NOT ENOUGH PARTS]",
				"consequence_text": "The engineer works through the night. Life support is restored to full function." if spare_parts >= 2 else "You don't have enough spare parts!",
				"enabled": spare_parts >= 2,
				"effects": {
					"supplies": {"spare_parts": spare_parts - 2},
					"component_quality_boost": {"life_support": 20.0}
				} if spare_parts >= 2 else {}
			},
			{
				"id": "b",
				"text": "Partial repair (uses 1 spare part, 70% efficiency)" if spare_parts >= 1 else "Partial repair [NOT ENOUGH PARTS]",
				"consequence_text": "A temporary fix. Life support runs at 70% - oxygen consumption increased." if spare_parts >= 1 else "You don't have enough spare parts!",
				"enabled": spare_parts >= 1,
				"effects": {
					"supplies": {"spare_parts": spare_parts - 1},
					"component_quality_boost": {"life_support": 10.0},
					"temporary_oxygen_penalty": 1.3  # 30% more oxygen use
				} if spare_parts >= 1 else {}
			},
			{
				"id": "c",
				"text": "Ration oxygen (no parts, crew health suffers)",
				"consequence_text": "The crew huddles together, breathing slowly. Everyone feels lightheaded for days.",
				"enabled": true,
				"effects": {
					"crew_health_penalty": -10.0,
					"crew_morale_penalty": -15.0
				}
			}
		]
	}

static func _generate_medical_crisis(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])
	var supplies = state.get("supplies", {})
	var medical_kits = int(supplies.get("medical_kits", 0))

	# Pick a victim
	var victim_index = int(severity * crew.size()) % crew.size()
	var victim = crew[victim_index] if not crew.is_empty() else {"display_name": "Unknown"}

	var injury_type = "acute appendicitis" if severity < 0.5 else "internal bleeding from a fall"

	return {
		"type": "crisis",
		"id": "medical_emergency",
		"title": "MEDICAL EMERGENCY",
		"description": "%s has collapsed!\n\nDiagnosis: %s. Without treatment, they could die within days." % [victim.display_name, injury_type],
		"victim_index": victim_index,
		"choices": [
			{
				"id": "a",
				"text": "Full surgery (2 medical kits, high success)" if medical_kits >= 2 else "Full surgery [NOT ENOUGH KITS]",
				"consequence_text": "The operation is successful. %s will need rest but will recover fully." % victim.display_name if medical_kits >= 2 else "You don't have enough medical supplies!",
				"enabled": medical_kits >= 2,
				"effects": {
					"supplies": {"medical_kits": medical_kits - 2},
					"victim_heal": 30.0,
					"victim_cure": true
				} if medical_kits >= 2 else {}
			},
			{
				"id": "b",
				"text": "Conservative treatment (1 kit, moderate success)" if medical_kits >= 1 else "Conservative treatment [NOT ENOUGH KITS]",
				"consequence_text": "Pain management and monitoring. %s stabilizes but remains weakened." % victim.display_name if medical_kits >= 1 else "You don't have enough medical supplies!",
				"enabled": medical_kits >= 1,
				"effects": {
					"supplies": {"medical_kits": medical_kits - 1},
					"victim_heal": 15.0
				} if medical_kits >= 1 else {}
			},
			{
				"id": "c",
				"text": "Let them rest (no supplies, hope for the best)",
				"consequence_text": "%s's condition worsens. They're in constant pain and can barely function." % victim.display_name,
				"enabled": true,
				"effects": {
					"victim_damage": -20.0,
					"victim_sick": true
				}
			}
		]
	}

static func _generate_supply_crisis(state: Dictionary, severity: float) -> Dictionary:
	var supplies = state.get("supplies", {})
	var food = supplies.get("food_kg", 0.0)
	var water = supplies.get("water_kg", 0.0)

	var lost_resource = "food" if severity < 0.5 else "water"
	var lost_amount = 50.0 + severity * 100.0  # 50-150 kg lost

	return {
		"type": "crisis",
		"id": "cargo_breach",
		"title": "CARGO BAY BREACH",
		"description": "A micrometeorite has punctured the cargo bay!\n\n%.0f kg of %s is venting into space. You have seconds to decide." % [lost_amount, lost_resource],
		"choices": [
			{
				"id": "a",
				"text": "Seal the breach immediately (lose the supplies)",
				"consequence_text": "The breach is sealed. The %s is lost, but the ship is safe." % lost_resource,
				"enabled": true,
				"effects": {
					"supply_loss": {lost_resource + "_kg": lost_amount}
				}
			},
			{
				"id": "b",
				"text": "Try to save supplies first (risky)",
				"consequence_text": "The crew scrambles to recover supplies. Some are saved, but the breach widens.",
				"enabled": true,
				"effects": {
					"supply_loss": {lost_resource + "_kg": lost_amount * 0.5},
					"component_damage": {"cargo": 15.0}
				}
			},
			{
				"id": "c",
				"text": "Send someone to manually seal from outside (dangerous)",
				"consequence_text": "A brave EVA saves most of the supplies, but the crew member is injured.",
				"enabled": true,
				"effects": {
					"supply_loss": {lost_resource + "_kg": lost_amount * 0.2},
					"random_crew_injury": true
				}
			}
		]
	}

static func _generate_crew_conflict(state: Dictionary, severity: float) -> Dictionary:
	var crew = state.get("crew", [])
	if crew.size() < 2:
		return {}

	var crew1_idx = int(severity * crew.size()) % crew.size()
	var crew2_idx = (crew1_idx + 1) % crew.size()
	var crew1 = crew[crew1_idx]
	var crew2 = crew[crew2_idx]

	return {
		"type": "crisis",
		"id": "crew_conflict",
		"title": "CREW CONFLICT",
		"description": "Tensions have boiled over between %s and %s!\n\n%s accuses %s of incompetence. The argument has turned physical." % [crew1.display_name, crew2.display_name, crew1.display_name, crew2.display_name],
		"crew1_index": crew1_idx,
		"crew2_index": crew2_idx,
		"choices": [
			{
				"id": "a",
				"text": "Side with %s" % crew1.display_name,
				"consequence_text": "%s feels vindicated. %s is humiliated and resentful." % [crew1.display_name, crew2.display_name],
				"enabled": true,
				"effects": {
					"crew1_morale": 10.0,
					"crew2_morale": -25.0,
					"crew2_effectiveness_penalty": 0.8
				}
			},
			{
				"id": "b",
				"text": "Side with %s" % crew2.display_name,
				"consequence_text": "%s feels vindicated. %s is humiliated and resentful." % [crew2.display_name, crew1.display_name],
				"enabled": true,
				"effects": {
					"crew2_morale": 10.0,
					"crew1_morale": -25.0,
					"crew1_effectiveness_penalty": 0.8
				}
			},
			{
				"id": "c",
				"text": "Force them to work it out together",
				"consequence_text": "After hours of mediation, they reach an uneasy truce. Both are exhausted.",
				"enabled": true,
				"effects": {
					"crew1_morale": -10.0,
					"crew2_morale": -10.0,
					"crew1_fatigue": 30.0,
					"crew2_fatigue": 30.0
				}
			}
		]
	}

## Check if a crisis should trigger (pure)
static func check_for_crisis(state: Dictionary, random_roll: float, type_roll: float, severity_roll: float) -> Dictionary:
	# Base 3% chance per day for a crisis
	var crisis_chance = 0.03

	# Increase chance if things are going badly
	var supplies = state.get("supplies", {})
	var crew = state.get("crew", [])

	# Low supplies increase crisis chance
	var travel_day = state.get("travel_day", 0)
	var travel_total = state.get("travel_total_days", 180)
	var days_remaining = travel_total - travel_day

	for key in ["food_kg", "water_kg", "oxygen_kg"]:
		var amount = supplies.get(key, 0.0)
		if amount < days_remaining * 2:  # Less than 2 days per person roughly
			crisis_chance += 0.02

	# Low morale increases crisis chance
	var avg_morale = 0.0
	for member in crew:
		avg_morale += member.morale
	if not crew.is_empty():
		avg_morale /= crew.size()
	if avg_morale < 40:
		crisis_chance += 0.03

	if random_roll >= crisis_chance:
		return {"triggered": false}

	var crisis = generate_crisis_event(state, type_roll, severity_roll)
	if crisis.is_empty():
		return {"triggered": false}

	return {
		"triggered": true,
		"crisis": crisis
	}

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
