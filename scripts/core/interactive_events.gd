class_name InteractiveEvents
extends RefCounted

## Interactive Event System - Oregon Trail DNA
## Events present meaningful choices with clear trade-offs
## All functions are pure and deterministic

# ============================================================================
# EVENT DATA STRUCTURE
# ============================================================================
# Each event has:
# - id: unique identifier
# - title: short display name
# - description: what's happening
# - choices: array of choice options
# - phase: which phase this event can occur in

# Each choice has:
# - id: choice identifier (a, b, c)
# - text: what the player chooses
# - consequence_text: what happens
# - effects: dictionary of state changes

# ============================================================================
# SHIP BUILDING PHASE EVENTS
# ============================================================================

static func get_ship_building_events() -> Array:
	return [
		{
			"id": "congressional_review",
			"title": "Congressional Budget Review",
			"description": "Senator Williams has called for a review of Mars program spending. The committee wants answers about cost overruns.",
			"choices": [
				{
					"id": "a",
					"text": "Present detailed justification (2 days)",
					"consequence_text": "Your thorough presentation impressed the committee.",
					"effects": {"budget_change": 20_000_000, "days_lost": 2}
				},
				{
					"id": "b",
					"text": "Accept 10% budget cut to avoid scrutiny",
					"consequence_text": "You took the safe path. Budget reduced.",
					"effects": {"budget_percent_change": -0.10}
				},
				{
					"id": "c",
					"text": "Invite media coverage (risky)",
					"consequence_text": "The publicity gamble...",
					"effects": {"risky_outcome": true, "success_budget": 50_000_000, "fail_budget": -50_000_000}
				}
			]
		},
		{
			"id": "contractor_delay",
			"title": "Contractor Supply Delay",
			"description": "Critical component delivery has been delayed. The contractor cites supply chain issues.",
			"choices": [
				{
					"id": "a",
					"text": "Wait for original order (+5 days)",
					"consequence_text": "You waited. The component arrived as specified.",
					"effects": {"days_lost": 5}
				},
				{
					"id": "b",
					"text": "Pay rush fee ($5M, no delay)",
					"consequence_text": "Money talks. Component expedited.",
					"effects": {"budget_change": -5_000_000}
				},
				{
					"id": "c",
					"text": "Source from alternate supplier ($2M, -15% quality)",
					"consequence_text": "Cheaper supplier, but quality concerns remain.",
					"effects": {"budget_change": -2_000_000, "quality_penalty": -15.0}
				}
			]
		},
		{
			"id": "tech_breakthrough",
			"title": "Technology Breakthrough",
			"description": "Engineers at JPL have made a breakthrough in life support efficiency. The new tech is available for integration.",
			"choices": [
				{
					"id": "a",
					"text": "Integrate new tech (+3 days, +10% life support)",
					"consequence_text": "Integration successful! Life support improved.",
					"effects": {"days_lost": 3, "life_support_bonus": 10.0}
				},
				{
					"id": "b",
					"text": "Document for future missions",
					"consequence_text": "You chose to play it safe. Knowledge preserved for the next mission.",
					"effects": {}
				},
				{
					"id": "c",
					"text": "Sell research data (+$10M)",
					"consequence_text": "The private sector paid well for this data.",
					"effects": {"budget_change": 10_000_000}
				}
			]
		},
		{
			"id": "crew_training_incident",
			"title": "Training Simulation Failure",
			"description": "During an EVA simulation, one of your crew made a critical error that would have been fatal in real conditions. They're shaken.",
			"choices": [
				{
					"id": "a",
					"text": "Extra training for entire crew (+5 days, -$3M)",
					"consequence_text": "The whole team learned from this. Everyone is more prepared.",
					"effects": {"days_lost": 5, "budget_change": -3_000_000, "crew_skill_bonus": 10}
				},
				{
					"id": "b",
					"text": "Extra training for affected crew only (+2 days)",
					"consequence_text": "Targeted training helped the individual recover confidence.",
					"effects": {"days_lost": 2, "affected_crew_skill": 15}
				},
				{
					"id": "c",
					"text": "Debrief and move on",
					"consequence_text": "No time for extra training. The crew remembers the close call.",
					"effects": {"crew_morale_penalty": -15}
				}
			]
		},
		{
			"id": "media_documentary",
			"title": "Documentary Crew Request",
			"description": "A major streaming service wants to embed a documentary team with your mission. They'd film everything, including setbacks.",
			"choices": [
				{
					"id": "a",
					"text": "Accept full access (+$15M, high pressure)",
					"consequence_text": "The cameras are rolling. Every decision is now public.",
					"effects": {"budget_change": 15_000_000, "public_mission": true}
				},
				{
					"id": "b",
					"text": "Accept limited access (+$5M)",
					"consequence_text": "Controlled access. Some privacy maintained.",
					"effects": {"budget_change": 5_000_000}
				},
				{
					"id": "c",
					"text": "Decline",
					"consequence_text": "You chose privacy over publicity.",
					"effects": {}
				}
			]
		}
	]

# ============================================================================
# TRAVEL PHASE EVENTS
# ============================================================================

static func get_travel_events() -> Array:
	return [
		{
			"id": "solar_flare",
			"title": "Solar Particle Event",
			"description": "Warning: Coronal mass ejection detected. High-energy particles will reach the ship in 6 hours. Radiation levels will spike dangerously.",
			"choices": [
				{
					"id": "a",
					"text": "Full shelter protocol (lose 1 day productivity)",
					"consequence_text": "Everyone sheltered in the shielded cargo bay. No radiation exposure.",
					"effects": {"days_lost": 1, "safe": true}
				},
				{
					"id": "b",
					"text": "Rotate shelter (half productivity, minor exposure)",
					"consequence_text": "Crew rotated through shelter. Minor radiation exposure but work continued.",
					"effects": {"crew_health_change": -5, "crew_morale_change": -3}
				},
				{
					"id": "c",
					"text": "Power shields to maximum (uses 30% battery)",
					"consequence_text": "Shields held. Normal operations continued but power reserves depleted.",
					"effects": {"power_drain": 0.30}
				}
			]
		},
		{
			"id": "hull_micrometeorite",
			"title": "Micrometeorite Impact",
			"description": "A small impact detected on the hull. Sensors show minor damage to an outer panel. No breach... yet.",
			"choices": [
				{
					"id": "a",
					"text": "Immediate EVA repair",
					"consequence_text": "Risky EVA completed successfully. Hull fully repaired.",
					"effects": {"crew_fatigue_change": 20, "hull_repaired": true}
				},
				{
					"id": "b",
					"text": "Internal patch (permanent -5% hull)",
					"consequence_text": "Applied emergency sealant from inside. The patch will hold, but it's not perfect.",
					"effects": {"hull_quality_change": -5}
				},
				{
					"id": "c",
					"text": "Monitor and wait",
					"consequence_text": "You're gambling that it won't get worse...",
					"effects": {"risky_outcome": true, "breach_chance": 0.25}
				}
			]
		},
		{
			"id": "crew_conflict",
			"title": "Crew Disagreement",
			"description": "Tension is boiling over. Two crew members are in a heated argument about duty assignments. The rest of the crew is watching.",
			"choices": [
				{
					"id": "a",
					"text": "Mediate directly",
					"consequence_text": "You stepped in and found a compromise. Tensions defused.",
					"effects": {"crew_morale_change": 5, "commander_respect": 10}
				},
				{
					"id": "b",
					"text": "Let them work it out",
					"consequence_text": "They eventually settled it, but feelings were hurt.",
					"effects": {"crew_morale_change": -10, "relationship_damage": true}
				},
				{
					"id": "c",
					"text": "Separate them (reassign duties)",
					"consequence_text": "You split them up. Efficient, but cold.",
					"effects": {"crew_morale_change": -5, "efficiency_bonus": 5}
				}
			]
		},
		{
			"id": "crew_illness",
			"title": "Medical Emergency",
			"description": "One crew member has developed acute appendicitis symptoms. Without treatment, their condition will worsen rapidly.",
			"choices": [
				{
					"id": "a",
					"text": "Full medical intervention (uses 2 med kits)",
					"consequence_text": "Successful treatment. Full recovery expected in 5 days.",
					"effects": {"medical_kits_used": 2, "crew_health_restored": true, "recovery_days": 5}
				},
				{
					"id": "b",
					"text": "Conservative treatment (uses 1 med kit, risky)",
					"consequence_text": "Minimal intervention. Hoping it resolves on its own.",
					"effects": {"medical_kits_used": 1, "risky_outcome": true, "complication_chance": 0.30}
				},
				{
					"id": "c",
					"text": "Consult Earth and wait (24hr comms delay)",
					"consequence_text": "Mission Control's advice arrives. Condition has worsened during the wait.",
					"effects": {"crew_health_change": -15, "earth_consulted": true}
				}
			]
		},
		{
			"id": "oxygen_leak",
			"title": "Oxygen System Alert",
			"description": "Life support is showing a slow O2 leak. Current reserves will last, but the leak must be addressed.",
			"choices": [
				{
					"id": "a",
					"text": "Full diagnostic and repair (Engineer, 8 hours)",
					"consequence_text": "The engineer found and fixed the leak. System restored.",
					"effects": {"crew_fatigue_change": 25, "o2_leak_fixed": true}
				},
				{
					"id": "b",
					"text": "Patch and monitor",
					"consequence_text": "Quick seal applied. Leak reduced but not eliminated.",
					"effects": {"daily_o2_loss": 0.5}
				},
				{
					"id": "c",
					"text": "Reduce crew activity to conserve O2",
					"consequence_text": "Everyone is resting more. O2 consumption reduced.",
					"effects": {"crew_morale_change": -10, "o2_consumption_reduced": 0.20}
				}
			]
		},
		{
			"id": "asteroid_proximity",
			"title": "Asteroid Proximity Alert",
			"description": "A small asteroid will pass within 500km. No collision risk, but it's close enough to study... or avoid more aggressively.",
			"choices": [
				{
					"id": "a",
					"text": "Adjust course for wider margin (uses fuel)",
					"consequence_text": "Safety first. Course adjusted.",
					"effects": {"fuel_used": 5}
				},
				{
					"id": "b",
					"text": "Maintain course, take measurements",
					"consequence_text": "Valuable data collected on the asteroid's composition!",
					"effects": {"science_bonus": 50, "crew_morale_change": 10}
				},
				{
					"id": "c",
					"text": "Move closer for detailed study",
					"consequence_text": "Incredible images and data! But some debris scratched the hull.",
					"effects": {"science_bonus": 150, "hull_quality_change": -3, "crew_morale_change": 15}
				}
			]
		},
		{
			"id": "birthday_in_space",
			"title": "Birthday in Space",
			"description": "Today is a crew member's birthday. The ship manifest shows the date, but they haven't mentioned it.",
			"choices": [
				{
					"id": "a",
					"text": "Surprise celebration (use luxury rations)",
					"consequence_text": "The surprise party was a hit! Everyone's spirits lifted.",
					"effects": {"food_used": 5, "all_crew_morale_change": 20}
				},
				{
					"id": "b",
					"text": "Quiet acknowledgment",
					"consequence_text": "A sincere 'happy birthday' meant more than they expected.",
					"effects": {"birthday_crew_morale_change": 15, "commander_respect": 5}
				},
				{
					"id": "c",
					"text": "Don't mention it",
					"consequence_text": "The day passed unremarked. They noticed.",
					"effects": {"birthday_crew_morale_change": -10}
				}
			]
		},
		{
			"id": "earth_visible",
			"title": "Earth Visible",
			"description": "Earth has shrunk to a pale blue dot in the distance. The crew gathers at the observation window.",
			"choices": [
				{
					"id": "a",
					"text": "\"We're making history.\"",
					"consequence_text": "Your words resonated. The magnitude of the mission sinks in.",
					"effects": {"all_crew_morale_change": 15}
				},
				{
					"id": "b",
					"text": "Allow a moment of silence",
					"consequence_text": "Sometimes, no words are needed. Each crew member reflects privately.",
					"effects": {"all_crew_morale_change": 10}
				},
				{
					"id": "c",
					"text": "\"Back to work.\"",
					"consequence_text": "The mission comes first. Some crew seemed disappointed.",
					"effects": {"all_crew_morale_change": -5, "efficiency_bonus": 3}
				}
			]
		},
		{
			"id": "halfway_milestone",
			"title": "Halfway to Mars",
			"description": "The navigation console confirms: you've crossed the halfway point. Mars is now closer than Earth.",
			"choices": [
				{
					"id": "a",
					"text": "Full celebration (use luxury rations)",
					"consequence_text": "A proper party! Music, stories, and real food for once.",
					"effects": {"food_used": 8, "all_crew_morale_change": 25}
				},
				{
					"id": "b",
					"text": "Brief acknowledgment",
					"consequence_text": "A toast and a moment to appreciate how far you've come.",
					"effects": {"all_crew_morale_change": 10}
				},
				{
					"id": "c",
					"text": "Focus on the challenges ahead",
					"consequence_text": "You reminded everyone that the hard part is still coming.",
					"effects": {"crew_morale_change": -5}
				}
			]
		}
	]

# ============================================================================
# MARS BASE EVENTS
# ============================================================================

static func get_mars_events() -> Array:
	return [
		{
			"id": "dust_storm_warning",
			"title": "Dust Storm Approaching",
			"description": "Satellite imagery shows a regional dust storm forming. Estimated arrival: 2 sols. Duration: unknown.",
			"choices": [
				{
					"id": "a",
					"text": "Full lockdown preparation (1 sol)",
					"consequence_text": "All EVA cancelled. Secured equipment. You're as ready as you can be.",
					"effects": {"sols_lost": 1, "storm_prepared": true}
				},
				{
					"id": "b",
					"text": "Selective prep (protect critical systems)",
					"consequence_text": "Quick preparations made. Some equipment left exposed.",
					"effects": {"partial_prep": true}
				},
				{
					"id": "c",
					"text": "Continue operations until storm hits",
					"consequence_text": "You maximized work time, but got caught in the storm.",
					"effects": {"risky_outcome": true, "caught_outside_chance": 0.20}
				}
			]
		},
		{
			"id": "anomalous_reading",
			"title": "Anomalous Sensor Reading",
			"description": "The atmospheric sensors are showing something unusual. Methane readings that shouldn't be there. It could be equipment error, geological activity, or... something else.",
			"choices": [
				{
					"id": "a",
					"text": "Investigate thoroughly (3 sols, uses supplies)",
					"consequence_text": "Deep investigation begins. This could be historic.",
					"effects": {"sols_used": 3, "investigation_started": true, "potential_discovery": true}
				},
				{
					"id": "b",
					"text": "Log and continue mission",
					"consequence_text": "Noted in the record. Future missions can follow up.",
					"effects": {"science_bonus": 25}
				},
				{
					"id": "c",
					"text": "Dismiss as equipment error",
					"consequence_text": "Probably just sensor drift. You recalibrated and moved on.",
					"effects": {}
				}
			]
		},
		{
			"id": "eva_emergency",
			"title": "EVA Emergency",
			"description": "A crew member signals emergency during EVA. Their suit is showing a pressure leak. They're 200 meters from the habitat.",
			"choices": [
				{
					"id": "a",
					"text": "Immediate rescue EVA",
					"consequence_text": "You rushed out and got them back. Close call, but everyone's safe.",
					"effects": {"rescuer_fatigue": 40, "rescued_health_loss": -10}
				},
				{
					"id": "b",
					"text": "Talk them through self-repair",
					"consequence_text": "Calm instructions helped them patch the leak and return.",
					"effects": {"rescued_stress": 30, "skill_check": true}
				},
				{
					"id": "c",
					"text": "Send the rover",
					"consequence_text": "The rover reached them in time. Slower but safer for the rescue team.",
					"effects": {"rescued_health_loss": -15, "rover_used": true}
				}
			]
		},
		{
			"id": "water_discovery",
			"title": "Water Ice Discovery",
			"description": "A survey mission found a significant ice deposit closer than expected. Extracting it could solve your water concerns, but it's in rough terrain.",
			"choices": [
				{
					"id": "a",
					"text": "Full extraction mission (5 sols, high reward)",
					"consequence_text": "Major operation successful! Water reserves significantly boosted.",
					"effects": {"sols_used": 5, "water_bonus": 500, "crew_fatigue": 25}
				},
				{
					"id": "b",
					"text": "Careful survey first (2 sols, moderate reward)",
					"consequence_text": "Survey complete. Smaller extraction but safer.",
					"effects": {"sols_used": 2, "water_bonus": 200}
				},
				{
					"id": "c",
					"text": "Mark for future mission",
					"consequence_text": "Location logged. No time for extraction this mission.",
					"effects": {"science_bonus": 50}
				}
			]
		}
	]

# ============================================================================
# RETURN JOURNEY EVENTS
# ============================================================================

static func get_return_events() -> Array:
	return [
		{
			"id": "system_cascade",
			"title": "System Cascade Warning",
			"description": "Multiple systems showing stress. The ship is tired after the long journey. One failure could trigger others.",
			"choices": [
				{
					"id": "a",
					"text": "Full maintenance day (lose 1 day, use spare parts)",
					"consequence_text": "Comprehensive maintenance completed. Systems stabilized.",
					"effects": {"spare_parts_used": 1, "all_systems_bonus": 5}
				},
				{
					"id": "b",
					"text": "Prioritize life support only",
					"consequence_text": "Life support secured. Other systems will have to hold.",
					"effects": {"life_support_bonus": 10}
				},
				{
					"id": "c",
					"text": "Push through",
					"consequence_text": "No time for maintenance. Hope for the best.",
					"effects": {"cascade_risk": true}
				}
			]
		},
		{
			"id": "food_critical",
			"title": "Food Supplies Critical",
			"description": "At current consumption, food will run out before Earth arrival. The crew knows. They're looking to you for a decision.",
			"choices": [
				{
					"id": "a",
					"text": "Severe rationing (half portions)",
					"consequence_text": "Hunger becomes a constant companion, but supplies will last.",
					"effects": {"food_consumption_multiplier": 0.5, "crew_health_daily": -2, "crew_morale_change": -20}
				},
				{
					"id": "b",
					"text": "Moderate rationing (75% portions)",
					"consequence_text": "Reduced portions. Uncomfortable but manageable.",
					"effects": {"food_consumption_multiplier": 0.75, "crew_health_daily": -1, "crew_morale_change": -10}
				},
				{
					"id": "c",
					"text": "Maintain rations, hope for rescue",
					"consequence_text": "Normal food for now. You're betting on an early rescue or faster arrival.",
					"effects": {"hope_strategy": true}
				}
			]
		},
		{
			"id": "earth_contact",
			"title": "Earth Contact Restored",
			"description": "\"Artemis, this is Houston. We read you. Welcome back to the neighborhood.\"",
			"choices": [
				{
					"id": "a",
					"text": "Request status briefing",
					"consequence_text": "Houston fills you in on what you've missed. Earth is waiting.",
					"effects": {"crew_morale_change": 20, "earth_briefed": true}
				},
				{
					"id": "b",
					"text": "Personal messages for crew",
					"consequence_text": "Each crew member speaks to loved ones. Tears and smiles.",
					"effects": {"all_crew_morale_change": 30}
				},
				{
					"id": "c",
					"text": "Focus on mission status only",
					"consequence_text": "Efficient communication. Houston confirms your trajectory.",
					"effects": {"crew_morale_change": 10}
				}
			]
		},
		{
			"id": "reentry_check",
			"title": "Reentry Systems Check",
			"description": "Final preparations for atmospheric reentry. Heat shield, parachutes, and navigation must all work perfectly.",
			"choices": [
				{
					"id": "a",
					"text": "Triple-check everything",
					"consequence_text": "You found a minor issue and fixed it. Everything is ready.",
					"effects": {"reentry_bonus": 10}
				},
				{
					"id": "b",
					"text": "Standard checks",
					"consequence_text": "Checks complete. Systems nominal.",
					"effects": {}
				},
				{
					"id": "c",
					"text": "Trust the systems",
					"consequence_text": "No time for paranoia. You've come this far.",
					"effects": {"confidence_bonus": true, "undetected_issue_chance": 0.10}
				}
			]
		}
	]

# ============================================================================
# EVENT SELECTION (pure, deterministic)
# ============================================================================

## Select a random event for the given phase (pure)
static func select_event(phase: GameTypes.GamePhase, random_roll: float) -> Dictionary:
	var events: Array
	match phase:
		GameTypes.GamePhase.SHIP_BUILDING:
			events = get_ship_building_events()
		GameTypes.GamePhase.TRAVEL_TO_MARS:
			events = get_travel_events()
		GameTypes.GamePhase.MARS_BASE:
			events = get_mars_events()
		GameTypes.GamePhase.TRAVEL_TO_EARTH:
			events = get_return_events()
		_:
			return {}

	if events.is_empty():
		return {}

	var index = int(random_roll * events.size()) % events.size()
	return events[index]

## Check if an event should trigger (pure)
static func should_event_trigger(phase: GameTypes.GamePhase, day: int, random_roll: float) -> bool:
	var base_chance: float
	match phase:
		GameTypes.GamePhase.SHIP_BUILDING:
			base_chance = 0.08  # 8% per day
		GameTypes.GamePhase.TRAVEL_TO_MARS:
			base_chance = 0.12  # 12% per day - travel is eventful
		GameTypes.GamePhase.MARS_BASE:
			base_chance = 0.10  # 10% per sol
		GameTypes.GamePhase.TRAVEL_TO_EARTH:
			base_chance = 0.15  # 15% per day - worn systems, more events
		_:
			return false

	return random_roll < base_chance

## Apply a choice's effects to state (pure)
static func apply_choice_effects(state: Dictionary, event: Dictionary, choice_id: String) -> Dictionary:
	var choice: Dictionary = {}
	for c in event.choices:
		if c.id == choice_id:
			choice = c
			break

	if choice.is_empty():
		return state

	var effects = choice.effects
	var new_state = state.duplicate(true)

	# Apply various effect types
	if effects.has("budget_change"):
		new_state.budget = maxi(0, new_state.budget + effects.budget_change)

	if effects.has("budget_percent_change"):
		var change = int(new_state.budget * effects.budget_percent_change)
		new_state.budget = maxi(0, new_state.budget + change)

	if effects.has("days_lost"):
		new_state.current_day += effects.days_lost

	if effects.has("crew_morale_change"):
		var new_crew = []
		for member in new_state.crew:
			new_crew.append(GameTypes.with_field(
				member, "morale",
				clampf(member.morale + effects.crew_morale_change, 0, 100)
			))
		new_state.crew = new_crew

	if effects.has("all_crew_morale_change"):
		var new_crew = []
		for member in new_state.crew:
			new_crew.append(GameTypes.with_field(
				member, "morale",
				clampf(member.morale + effects.all_crew_morale_change, 0, 100)
			))
		new_state.crew = new_crew

	if effects.has("crew_health_change"):
		var new_crew = []
		for member in new_state.crew:
			new_crew.append(GameTypes.with_field(
				member, "health",
				clampf(member.health + effects.crew_health_change, 0, 100)
			))
		new_state.crew = new_crew

	if effects.has("crew_fatigue_change"):
		var new_crew = []
		for member in new_state.crew:
			new_crew.append(GameTypes.with_field(
				member, "fatigue",
				clampf(member.fatigue + effects.crew_fatigue_change, 0, 100)
			))
		new_state.crew = new_crew

	if effects.has("hull_quality_change"):
		# Apply to hull/cockpit component
		var new_components = []
		for comp in new_state.ship_components:
			if comp.id in ["cockpit", "hull"]:
				new_components.append(GameTypes.with_field(
					comp, "quality",
					clampf(comp.quality + effects.hull_quality_change, 0, 100)
				))
			else:
				new_components.append(comp)
		new_state.ship_components = new_components

	if effects.has("science_bonus"):
		new_state["science_points"] = new_state.get("science_points", 0) + effects.science_bonus

	if effects.has("food_used"):
		var supplies = new_state.get("supplies", {}).duplicate()
		supplies["food_kg"] = maxf(0, supplies.get("food_kg", 0) - effects.food_used)
		new_state.supplies = supplies

	if effects.has("medical_kits_used"):
		var supplies = new_state.get("supplies", {}).duplicate()
		supplies["medical_kits"] = maxi(0, supplies.get("medical_kits", 0) - effects.medical_kits_used)
		new_state.supplies = supplies

	if effects.has("spare_parts_used"):
		var supplies = new_state.get("supplies", {}).duplicate()
		supplies["spare_parts"] = maxi(0, supplies.get("spare_parts", 0) - effects.spare_parts_used)
		new_state.supplies = supplies

	if effects.has("life_support_bonus"):
		var new_components = []
		for comp in new_state.ship_components:
			if comp.id == "life_support":
				new_components.append(GameTypes.with_field(
					comp, "quality",
					minf(100, comp.quality + effects.life_support_bonus)
				))
			else:
				new_components.append(comp)
		new_state.ship_components = new_components

	if effects.has("all_systems_bonus"):
		var new_components = []
		for comp in new_state.ship_components:
			new_components.append(GameTypes.with_field(
				comp, "quality",
				minf(100, comp.quality + effects.all_systems_bonus)
			))
		new_state.ship_components = new_components

	if effects.has("water_bonus"):
		var supplies = new_state.get("supplies", {}).duplicate()
		supplies["water_kg"] = supplies.get("water_kg", 0) + effects.water_bonus
		new_state.supplies = supplies

	return new_state

# ============================================================================
# PASSIVE EVENT GENERATION (merged from event_logic.gd)
# These events happen automatically without player choice
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
			"event": _generate_weather_damage_event(state, severity_roll),
			"should_trigger": true
		}
	elif event_type_roll < 0.66:
		return {
			"event": _generate_crew_sickness_event(state, severity_roll),
			"should_trigger": true
		}
	else:
		return {
			"event": _generate_supply_loss_event(state, severity_roll),
			"should_trigger": true
		}

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
			"event": _generate_equipment_malfunction(state, severity_roll),
			"should_trigger": true
		}
	elif type_roll < 0.4:
		return {
			"event": _generate_crew_sickness_event(state, severity_roll),
			"should_trigger": true
		}
	elif type_roll < 0.6:
		return {
			"event": _generate_morale_event(state, severity_roll),
			"should_trigger": true
		}
	elif type_roll < 0.8:
		return {
			"event": _generate_discovery_event(state, severity_roll),
			"should_trigger": true
		}
	else:
		return {
			"event": _generate_radiation_event(state, severity_roll),
			"should_trigger": true
		}

## Generate weather damage event (pure)
static func _generate_weather_damage_event(state: Dictionary, severity: float) -> Dictionary:
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
static func _generate_crew_sickness_event(state: Dictionary, severity: float) -> Dictionary:
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
static func _generate_supply_loss_event(state: Dictionary, severity: float) -> Dictionary:
	var loss_amount = int(1_000_000 + (severity * 9_000_000))  # $1M - $10M

	return GameTypes.create_event({
		"type": GameTypes.EventType.SUPPLY_LOSS,
		"description": "Supply mishap! Lost $%s in resources" % GameTypes.format_money(loss_amount),
		"effects": {
			"budget": state.budget - loss_amount
		}
	})

## Generate equipment malfunction event (pure)
static func _generate_equipment_malfunction(state: Dictionary, severity: float) -> Dictionary:
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
static func _generate_morale_event(state: Dictionary, severity: float) -> Dictionary:
	var is_positive = severity > 0.5
	var change = 10.0 + (absf(severity - 0.5) * 20.0)

	if not is_positive:
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
static func _generate_discovery_event(state: Dictionary, severity: float) -> Dictionary:
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
static func _generate_radiation_event(state: Dictionary, severity: float) -> Dictionary:
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
