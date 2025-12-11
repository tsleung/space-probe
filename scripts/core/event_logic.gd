class_name EventLogic
extends RefCounted

## Pure functions for random event generation and processing
## All functions are deterministic given the same random values

# ============================================================================
# EVENT GENERATION (all pure, deterministic with provided random values)
# ============================================================================

## Check for delay penalty events when past launch window
static func check_delay_events(
	state: Dictionary,
	random_roll: float,
	event_type_roll: float,
	severity_roll: float
) -> Dictionary:
	var days_past = state.current_day - state.launch_window_day
	if days_past <= 0:
		return {"event": null, "should_trigger": false}

	# 5% base chance per day, increases with delay
	var trigger_chance = 0.05 + (days_past * 0.005)
	if random_roll >= trigger_chance:
		return {"event": null, "should_trigger": false}

	# Determine event type
	if event_type_roll < 0.33:
		return {
			"event": generate_weather_damage_event(state, severity_roll),
			"should_trigger": true
		}
	elif event_type_roll < 0.66:
		return {
			"event": generate_crew_sickness_event(state, severity_roll),
			"should_trigger": true
		}
	else:
		return {
			"event": generate_supply_loss_event(state, severity_roll),
			"should_trigger": true
		}

## Generate weather damage event (pure)
static func generate_weather_damage_event(state: Dictionary, severity: float) -> Dictionary:
	var damage_percent = 5.0 + (severity * 10.0)  # 5-15% quality loss

	# Calculate new component qualities
	var damaged_components: Array = []
	for comp in state.ship_components:
		var new_quality = maxf(0.0, comp.quality - damage_percent)
		damaged_components.append(GameTypes.with_field(comp, "quality", new_quality))

	return GameTypes.create_event({
		"type": GameTypes.EventType.WEATHER_DAMAGE,
		"description": "Solar storm damaged ship components! Quality reduced by %.0f%%" % damage_percent,
		"effects": {
			"ship_components": damaged_components
		}
	})

## Generate crew sickness event (pure)
static func generate_crew_sickness_event(state: Dictionary, severity: float) -> Dictionary:
	if state.crew.is_empty():
		return GameTypes.create_event({
			"type": GameTypes.EventType.CREW_SICKNESS,
			"description": "No crew to affect",
			"effects": {}
		})

	# Pick crew member based on severity (as index selector)
	var crew_index = int(severity * state.crew.size()) % state.crew.size()
	var target_crew = state.crew[crew_index]

	if target_crew.is_sick:
		return GameTypes.create_event({
			"type": GameTypes.EventType.CREW_SICKNESS,
			"description": "%s is already sick" % target_crew.display_name,
			"effects": {}
		})

	var sickness_types = [
		"Space Adaptation Syndrome",
		"Radiation Exposure",
		"Viral Infection",
		"Stress-induced Illness"
	]
	var sickness = sickness_types[int(severity * sickness_types.size()) % sickness_types.size()]

	var sick_crew = CrewLogic.apply_sickness(target_crew, sickness)

	var new_crew: Array = []
	for i in range(state.crew.size()):
		if i == crew_index:
			new_crew.append(sick_crew)
		else:
			new_crew.append(state.crew[i])

	return GameTypes.create_event({
		"type": GameTypes.EventType.CREW_SICKNESS,
		"description": "%s has fallen ill with %s" % [target_crew.display_name, sickness],
		"effects": {
			"crew": new_crew
		}
	})

## Generate supply loss event (pure)
static func generate_supply_loss_event(state: Dictionary, severity: float) -> Dictionary:
	var loss_amount = int(1_000_000 + (severity * 9_000_000))  # $1M - $10M

	return GameTypes.create_event({
		"type": GameTypes.EventType.SUPPLY_LOSS,
		"description": "Supply mishap! Lost $%s in resources" % _format_money(loss_amount),
		"effects": {
			"budget": state.budget - loss_amount
		}
	})

# ============================================================================
# TRAVEL EVENTS
# ============================================================================

## Generate random travel event (pure)
static func generate_travel_event(
	state: Dictionary,
	event_roll: float,
	type_roll: float,
	severity_roll: float
) -> Dictionary:
	# Base 10% chance per day for something to happen
	if event_roll >= 0.10:
		return {"event": null, "should_trigger": false}

	# Categorize events
	if type_roll < 0.2:
		return {
			"event": generate_equipment_malfunction(state, severity_roll),
			"should_trigger": true
		}
	elif type_roll < 0.4:
		return {
			"event": generate_crew_sickness_event(state, severity_roll),
			"should_trigger": true
		}
	elif type_roll < 0.6:
		return {
			"event": generate_morale_event(state, severity_roll),
			"should_trigger": true
		}
	elif type_roll < 0.8:
		return {
			"event": generate_discovery_event(state, severity_roll),
			"should_trigger": true
		}
	else:
		return {
			"event": generate_radiation_event(state, severity_roll),
			"should_trigger": true
		}

## Generate equipment malfunction event (pure)
static func generate_equipment_malfunction(state: Dictionary, severity: float) -> Dictionary:
	if state.ship_components.is_empty():
		return GameTypes.create_event({
			"type": GameTypes.EventType.EQUIPMENT_MALFUNCTION,
			"description": "No equipment to malfunction",
			"effects": {}
		})

	# Pick component based on severity and quality (lower quality = higher chance)
	var vulnerable_components: Array = []
	for comp in state.ship_components:
		var fail_chance = ComponentLogic.calc_failure_chance(comp.quality)
		if severity < fail_chance:
			vulnerable_components.append(comp)

	if vulnerable_components.is_empty():
		return GameTypes.create_event({
			"type": GameTypes.EventType.EQUIPMENT_MALFUNCTION,
			"description": "Equipment check passed - all systems nominal",
			"effects": {}
		})

	var target_index = int(severity * vulnerable_components.size()) % vulnerable_components.size()
	var target = vulnerable_components[target_index]
	var quality_loss = 10.0 + (severity * 20.0)

	var new_components: Array = []
	for comp in state.ship_components:
		if comp.hex_position == target.hex_position:
			new_components.append(GameTypes.with_field(
				comp,
				"quality",
				maxf(0.0, comp.quality - quality_loss)
			))
		else:
			new_components.append(comp)

	return GameTypes.create_event({
		"type": GameTypes.EventType.EQUIPMENT_MALFUNCTION,
		"description": "%s malfunctioned! Quality reduced by %.0f%%" % [target.display_name, quality_loss],
		"effects": {
			"ship_components": new_components
		}
	})

## Generate morale event (can be positive or negative) (pure)
static func generate_morale_event(state: Dictionary, severity: float) -> Dictionary:
	var is_positive = severity > 0.5
	var change = 10.0 + (absf(severity - 0.5) * 20.0)

	if is_positive:
		change = change
	else:
		change = -change

	var new_crew: Array = []
	for crew in state.crew:
		var new_morale = clampf(crew.morale + change, 0.0, 100.0)
		new_crew.append(GameTypes.with_field(crew, "morale", new_morale))

	var description = ""
	if is_positive:
		var positive_events = [
			"Crew enjoyed a movie night together!",
			"Received encouraging messages from Earth!",
			"Milestone celebration - halfway to Mars!",
			"Successful experiment boosted team spirit!"
		]
		description = positive_events[int(severity * positive_events.size()) % positive_events.size()]
	else:
		var negative_events = [
			"Communication blackout caused anxiety.",
			"Equipment noise disrupted sleep cycles.",
			"Cabin fever setting in...",
			"Homesickness affecting the crew."
		]
		description = negative_events[int(severity * negative_events.size()) % negative_events.size()]

	return GameTypes.create_event({
		"type": GameTypes.EventType.MORALE_BOOST,
		"description": description + " (Morale %+.0f%%)" % change,
		"effects": {
			"crew": new_crew
		}
	})

## Generate discovery event (always positive) (pure)
static func generate_discovery_event(state: Dictionary, severity: float) -> Dictionary:
	var discoveries = [
		{"text": "Crew observed a spectacular solar flare!", "science_bonus": 5.0},
		{"text": "Detected an unusual asteroid composition.", "science_bonus": 10.0},
		{"text": "Captured amazing photos of Earth from distance.", "morale_bonus": 15.0},
		{"text": "Found optimization for life support system.", "quality_bonus": 5.0}
	]

	var discovery = discoveries[int(severity * discoveries.size()) % discoveries.size()]
	var effects = {}

	if discovery.has("morale_bonus"):
		var new_crew: Array = []
		for crew in state.crew:
			new_crew.append(GameTypes.with_field(
				crew,
				"morale",
				minf(100.0, crew.morale + discovery.morale_bonus)
			))
		effects["crew"] = new_crew

	if discovery.has("quality_bonus"):
		var new_components: Array = []
		for comp in state.ship_components:
			if comp.id == "life_support":
				new_components.append(GameTypes.with_field(
					comp,
					"quality",
					minf(100.0, comp.quality + discovery.quality_bonus)
				))
			else:
				new_components.append(comp)
		effects["ship_components"] = new_components

	return GameTypes.create_event({
		"type": GameTypes.EventType.DISCOVERY,
		"description": discovery.text,
		"effects": effects
	})

## Generate radiation event (pure)
static func generate_radiation_event(state: Dictionary, severity: float) -> Dictionary:
	var radiation_level = severity * 100.0

	if radiation_level < 30:
		return GameTypes.create_event({
			"type": GameTypes.EventType.WEATHER_DAMAGE,
			"description": "Minor solar radiation detected - within safe limits.",
			"effects": {}
		})

	# Affects crew health
	var health_loss = (radiation_level - 30) * 0.5  # 0-35 health loss

	var new_crew: Array = []
	for crew in state.crew:
		new_crew.append(GameTypes.with_field(
			crew,
			"health",
			maxf(0.0, crew.health - health_loss)
		))

	return GameTypes.create_event({
		"type": GameTypes.EventType.WEATHER_DAMAGE,
		"description": "Solar radiation spike! Crew exposed to %.0f rads. (Health -%.0f%%)" % [radiation_level, health_loss],
		"effects": {
			"crew": new_crew
		}
	})

# ============================================================================
# HELPERS
# ============================================================================

static func _format_money(amount: int) -> String:
	if amount >= 1_000_000_000:
		return "%.2fB" % (amount / 1_000_000_000.0)
	elif amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK" % (amount / 1_000.0)
	return str(amount)
