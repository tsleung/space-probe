extends RefCounted
class_name ColonySimEvents

## Colony Sim Event Logic
## Pure functions for event generation, selection, and resolution
## All functions are static and deterministic

# ============================================================================
# EVENT DEFINITIONS
# ============================================================================

## Get all available events for the colony sim
static func get_all_events() -> Array:
	return [
		# ACT 1 - SURVIVAL EVENTS
		_event_first_winter(),
		_event_equipment_cascade(),
		_event_food_crisis(),

		# ACT 1 - SOCIAL EVENTS
		_event_first_conflict(),
		_event_first_romance(),
		_event_founder_homesickness(),

		# ACT 1 - GENERATIONAL EVENTS
		_event_first_pregnancy(),
		_event_first_birth(),
		_event_first_death(),

		# ACT 2 - POLITICAL EVENTS
		_event_council_formation(),
		_event_first_election(),
		_event_first_strike(),

		# ACT 2 - GENERATIONAL EVENTS
		_event_first_gen_comes_of_age(),
		_event_founder_aging(),

		# ACT 2 - SOCIAL EVENTS
		_event_immigration_clash(),

		# ACT 3 - POLITICAL EVENTS
		_event_independence_question(),

		# ACT 3 - DISCOVERY EVENTS
		_event_life_evidence(),
		_event_terraforming_proposal(),

		# ACT 4 - GENERATIONAL EVENTS
		_event_last_founder_dies(),
		_event_earth_collapse(),

		# QUIET MOMENTS
		_quiet_stargazing_child(),
		_quiet_founders_reunion(),
		_quiet_first_painting()
	]

# ============================================================================
# EVENT SELECTION
# ============================================================================

## Check which events can trigger this year
## Returns array of eligible events
static func get_eligible_events(state: Dictionary) -> Array:
	var all_events = get_all_events()
	var eligible: Array = []

	for event in all_events:
		if _can_event_trigger(event, state):
			eligible.append(event)

	return eligible

## Select which event(s) will occur this year
## Returns: { events: Array, random_consumed: int }
static func select_yearly_events(state: Dictionary, random_values: Array) -> Dictionary:
	var eligible = get_eligible_events(state)
	var selected: Array = []
	var random_idx = 0

	# Base event count by phase
	var max_events = 2
	match state.colony_phase:
		ColonySimTypes.ColonyPhase.ACT_2_SETTLEMENT:
			max_events = 3
		ColonySimTypes.ColonyPhase.ACT_3_COLONY:
			max_events = 3
		ColonySimTypes.ColonyPhase.ACT_4_INDEPENDENCE:
			max_events = 4

	# Priority sort - critical events first
	eligible.sort_custom(func(a, b):
		return _get_event_priority(a) > _get_event_priority(b)
	)

	# Select events
	for event in eligible:
		if selected.size() >= max_events:
			break

		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		# Check probability
		var trigger_chance = event.get("trigger_chance", 0.5)

		# Boost chance if event is overdue
		var cooldown_key = event.type
		var last_trigger = state.event_cooldowns.get(cooldown_key, 0)
		var years_since = state.current_year - last_trigger
		if years_since > 5:
			trigger_chance *= 1.5

		if rand < trigger_chance:
			# Check if not on cooldown
			var cooldown = event.get("cooldown_years", 3)
			if years_since >= cooldown or last_trigger == 0:
				selected.append(event)

	# Always try to add one quiet moment if morale is good
	if selected.size() < max_events:
		var quiet_events = eligible.filter(func(e): return e.get("is_quiet_moment", false))
		if quiet_events.size() > 0:
			var avg_morale = _calc_avg_morale(state.colonists)
			if avg_morale > 50:
				var rand = _get_random(random_values, random_idx)
				random_idx += 1
				if rand < 0.3:  # 30% chance for quiet moment
					selected.append(quiet_events[int(rand * quiet_events.size()) % quiet_events.size()])

	return {
		"events": selected,
		"random_consumed": random_idx
	}

static func _can_event_trigger(event: Dictionary, state: Dictionary) -> bool:
	var year = state.current_year

	# Year range check
	if year < event.get("min_year", 0):
		return false
	if year > event.get("max_year", 999):
		return false

	# Phase check
	var required_phase = event.get("required_phase", -1)
	if required_phase >= 0 and state.colony_phase < required_phase:
		return false

	# Population check
	var min_pop = event.get("min_population", 0)
	if ColonySimPopulation.count_alive(state.colonists) < min_pop:
		return false

	# Cooldown check
	var cooldown_key = event.type
	var last_trigger = state.event_cooldowns.get(cooldown_key, 0)
	var cooldown = event.get("cooldown_years", 3)
	if last_trigger > 0 and (year - last_trigger) < cooldown:
		return false

	# One-time check
	if event.get("one_time", false) and last_trigger > 0:
		return false

	# Custom conditions
	var conditions = event.get("conditions", {})

	if conditions.get("requires_founders_alive", false):
		if ColonySimPopulation.get_alive_founders(state.colonists).size() == 0:
			return false

	if conditions.get("requires_mars_born", false):
		var counts = ColonySimPopulation.count_by_generation(state.colonists)
		if counts[ColonySimTypes.Generation.FIRST_GEN] + counts[ColonySimTypes.Generation.SECOND_GEN] == 0:
			return false

	if conditions.get("requires_couples", false):
		var has_couples = false
		for c in state.colonists:
			if c.is_alive and not c.spouse_id.is_empty():
				has_couples = true
				break
		if not has_couples:
			return false

	return true

static func _get_event_priority(event: Dictionary) -> int:
	# Higher priority = triggers first
	var severity = event.get("severity", ColonySimTypes.EventSeverity.MINOR)
	match severity:
		ColonySimTypes.EventSeverity.CRITICAL:
			return 100
		ColonySimTypes.EventSeverity.MAJOR:
			return 75
		ColonySimTypes.EventSeverity.MODERATE:
			return 50
		_:
			return 25

# ============================================================================
# EVENT RESOLUTION
# ============================================================================

## Apply player's choice for an event
## Returns: { state: Dictionary, effects: Dictionary, follow_up_event: String }
static func apply_event_choice(state: Dictionary, event: Dictionary, choice_id: String, random_values: Array) -> Dictionary:
	var choice = null
	for c in event.choices:
		if c.id == choice_id:
			choice = c
			break

	if choice == null:
		return {
			"state": state,
			"effects": {},
			"follow_up_event": ""
		}

	var new_state = state.duplicate(true)
	var effects: Dictionary = {}
	var random_idx = 0

	# Check for skill check
	var success = true
	if choice.get("success_chance", 1.0) < 1.0:
		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var base_chance = choice.success_chance

		# Skill modifier
		if choice.has("requires_skill"):
			var required_skill = choice.requires_skill
			var best_worker = ColonySimPopulation.get_best_worker_for_specialty(
				new_state.colonists, required_skill
			)
			if not best_worker.is_empty():
				base_chance += best_worker.skill_level / 200.0

		success = rand < base_chance

	# Apply effects based on success/failure
	var effects_to_apply = choice.effects
	if not success and choice.has("failure_effects"):
		effects_to_apply = choice.failure_effects

	# Morale change
	if effects_to_apply.has("morale_change"):
		var change = effects_to_apply.morale_change
		var updated_colonists: Array = []
		for c in new_state.colonists:
			if c.is_alive:
				var new_morale = clampf(c.morale + change, 0.0, 100.0)
				updated_colonists.append(ColonySimTypes.with_field(c, "morale", new_morale))
			else:
				updated_colonists.append(c)
		new_state.colonists = updated_colonists
		effects["morale_change"] = change

	# Resource changes
	if effects_to_apply.has("resource_changes"):
		var res = new_state.resources.duplicate()
		for resource_name in effects_to_apply.resource_changes:
			res[resource_name] = maxf(0, res.get(resource_name, 0) + effects_to_apply.resource_changes[resource_name])
		new_state.resources = res
		effects["resource_changes"] = effects_to_apply.resource_changes

	# Faction changes
	if effects_to_apply.has("faction_changes"):
		var standings = new_state.politics.faction_standings.duplicate()
		for faction in effects_to_apply.faction_changes:
			standings[faction] = clampf(standings.get(faction, 50) + effects_to_apply.faction_changes[faction], 0, 100)
		new_state.politics = ColonySimTypes.with_field(new_state.politics, "faction_standings", standings)
		effects["faction_changes"] = effects_to_apply.faction_changes

	# Stability change
	if effects_to_apply.has("stability_change"):
		new_state.politics = ColonySimPolitics.update_stability(
			new_state.politics, effects_to_apply.stability_change
		)
		effects["stability_change"] = effects_to_apply.stability_change

	# Add to timeline
	var timeline_entry = ColonySimTypes.create_timeline_entry(
		new_state.current_year,
		event.title,
		"Chose: %s. %s" % [choice.text, "Success!" if success else "Failed." if choice.get("success_chance", 1.0) < 1.0 else ""],
		"event"
	)
	new_state.timeline = new_state.timeline + [timeline_entry]

	# Update cooldown
	var cooldowns = new_state.event_cooldowns.duplicate()
	cooldowns[event.type] = new_state.current_year
	new_state.event_cooldowns = cooldowns

	return {
		"state": new_state,
		"effects": effects,
		"follow_up_event": choice.get("triggers_event", ""),
		"success": success
	}

# ============================================================================
# EVENT DEFINITIONS - ACT 1
# ============================================================================

static func _event_first_winter() -> Dictionary:
	return {
		"type": "first_winter",
		"title": "The Long Night",
		"description": "Mars winter is here. Dust storms reduce solar power by 40%, temperatures plummet. Chief Engineer [founder] has prepared a survival plan.",
		"severity": ColonySimTypes.EventSeverity.MODERATE,
		"min_year": 1,
		"max_year": 2,
		"one_time": true,
		"trigger_chance": 1.0,
		"conditions": {"requires_founders_alive": true},
		"choices": [
			{
				"id": "strict",
				"text": "Follow the survival plan strictly",
				"description": "Power rationing, limited EVA. Safe but slow.",
				"effects": {
					"morale_change": -10.0,
					"flag_changes": ["winter_cautious"]
				}
			},
			{
				"id": "push",
				"text": "Push through with normal operations",
				"description": "Risk equipment failures. Maintain productivity.",
				"effects": {
					"resource_changes": {"machine_parts": -5}
				},
				"success_chance": 0.7,
				"failure_effects": {
					"morale_change": -20.0,
					"stability_change": -10.0
				}
			},
			{
				"id": "indoor",
				"text": "Use this time for indoor projects",
				"description": "Accelerate research and training.",
				"effects": {
					"morale_change": 5.0,
					"flag_changes": ["winter_productive"]
				}
			}
		]
	}

static func _event_equipment_cascade() -> Dictionary:
	return {
		"type": "equipment_cascade",
		"title": "Cascade Failure",
		"description": "Life support system has failed, causing problems with connected systems. The original ship components are showing their age.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 1,
		"max_year": 10,
		"cooldown_years": 3,
		"trigger_chance": 0.3,
		"choices": [
			{
				"id": "emergency",
				"text": "Emergency repair (all hands)",
				"description": "2 weeks, all other work stops.",
				"effects": {
					"resource_changes": {"machine_parts": -10}
				}
			},
			{
				"id": "juryrig",
				"text": "Jury-rig a workaround",
				"description": "3 days, minimal disruption, but risky.",
				"effects": {},
				"success_chance": 0.6,
				"failure_effects": {
					"morale_change": -15.0,
					"resource_changes": {"machine_parts": -15, "oxygen": -50}
				}
			},
			{
				"id": "cannibalize",
				"text": "Cannibalize from backup systems",
				"description": "Lose redundancy for future events.",
				"effects": {
					"resource_changes": {"machine_parts": -5},
					"flag_changes": ["no_backup_life_support"]
				}
			}
		]
	}

static func _event_food_crisis() -> Dictionary:
	return {
		"type": "food_crisis",
		"title": "The Hungry Month",
		"description": "Food supplies are critically low. The greenhouse isn't producing enough yet. Rationing is necessary.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 1,
		"max_year": 5,
		"cooldown_years": 2,
		"trigger_chance": 0.4,
		"choices": [
			{
				"id": "light",
				"text": "Light rationing (80% rations)",
				"description": "Extends supplies 25%, minor morale hit.",
				"effects": {
					"morale_change": -5.0
				}
			},
			{
				"id": "severe",
				"text": "Severe rationing (60% rations)",
				"description": "Extends supplies 40%, serious morale impact.",
				"effects": {
					"morale_change": -15.0
				}
			},
			{
				"id": "priority",
				"text": "Prioritize workers",
				"description": "Workers get full rations, others suffer.",
				"effects": {
					"morale_change": -20.0,
					"faction_changes": {ColonySimTypes.Faction.PRAGMATISTS: 10}
				}
			}
		]
	}

static func _event_first_conflict() -> Dictionary:
	return {
		"type": "first_conflict",
		"title": "The Argument",
		"description": "Two founders are arguing loudly in the common area. It started over work schedules but has escalated. Other founders are watching.",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 1,
		"max_year": 3,
		"one_time": true,
		"trigger_chance": 0.6,
		"conditions": {"requires_founders_alive": true},
		"choices": [
			{
				"id": "mediate",
				"text": "Mediate immediately",
				"description": "Skill check: Leadership",
				"effects": {
					"morale_change": 5.0
				},
				"success_chance": 0.6,
				"requires_skill": ColonySimTypes.Specialty.ADMINISTRATOR,
				"failure_effects": {
					"morale_change": -10.0,
					"stability_change": -5.0
				}
			},
			{
				"id": "wait",
				"text": "Let them work it out",
				"description": "50% chance they resolve it naturally.",
				"effects": {},
				"success_chance": 0.5,
				"failure_effects": {
					"morale_change": -15.0
				}
			},
			{
				"id": "separate",
				"text": "Separate them (reassign duties)",
				"description": "Conflict suppressed but productivity reduced.",
				"effects": {
					"stability_change": 5.0,
					"flag_changes": ["efficiency_reduced"]
				}
			}
		]
	}

static func _event_first_romance() -> Dictionary:
	return {
		"type": "first_romance",
		"title": "Found in Translation",
		"description": "You've noticed two colonists spending more time together. The way they look at each other... something is developing.",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 1,
		"max_year": 5,
		"one_time": true,
		"trigger_chance": 0.5,
		"conditions": {"requires_couples": false},  # Triggers before couples exist
		"choices": [
			{
				"id": "encourage",
				"text": "Encourage the relationship",
				"description": "Both gain morale, but risk if it ends badly.",
				"effects": {
					"morale_change": 10.0
				}
			},
			{
				"id": "discourage",
				"text": "Discourage relationships (professional)",
				"description": "Colony policy established.",
				"effects": {
					"morale_change": -5.0,
					"flag_changes": ["relationships_discouraged"]
				}
			},
			{
				"id": "neutral",
				"text": "Stay out of it",
				"description": "Let relationship develop naturally.",
				"effects": {}
			}
		]
	}

static func _event_founder_homesickness() -> Dictionary:
	return {
		"type": "founder_homesickness",
		"title": "Looking at Earth",
		"description": "You find a founder at the observation window during night cycle, staring at Earth. 'I knew I'd never go back. But knowing it and feeling it...'",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 1,
		"max_year": 5,
		"cooldown_years": 2,
		"trigger_chance": 0.4,
		"is_quiet_moment": true,
		"conditions": {"requires_founders_alive": true},
		"choices": [
			{
				"id": "listen",
				"text": "Tell me about what you miss",
				"description": "Long conversation about Earth.",
				"effects": {
					"morale_change": 8.0
				}
			},
			{
				"id": "inspire",
				"text": "We're building something new here",
				"description": "Inspirational speech.",
				"effects": {
					"morale_change": 3.0
				}
			},
			{
				"id": "share",
				"text": "I miss it too",
				"description": "Shared vulnerability.",
				"effects": {
					"morale_change": 5.0
				}
			},
			{
				"id": "silent",
				"text": "[Stand with them in silence]",
				"description": "No words needed.",
				"effects": {
					"morale_change": 10.0
				}
			}
		]
	}

static func _event_first_pregnancy() -> Dictionary:
	return {
		"type": "first_pregnancy",
		"title": "Two Heartbeats",
		"description": "A colonist approaches you privately. She's pregnant. The first pregnancy in human history on another planet. Everything about this is unprecedented.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 2,
		"max_year": 10,
		"one_time": true,
		"trigger_chance": 0.8,
		"conditions": {"requires_couples": true},
		"choices": [
			{
				"id": "announce",
				"text": "Announce it to the colony",
				"description": "Colony morale +25, but pressure on parents.",
				"effects": {
					"morale_change": 25.0
				}
			},
			{
				"id": "quiet",
				"text": "Keep it quiet until second trimester",
				"description": "Private matter respected.",
				"effects": {
					"morale_change": 5.0
				}
			},
			{
				"id": "concern",
				"text": "Express concern about the risks",
				"description": "Honest about medical limitations.",
				"effects": {
					"morale_change": -5.0,
					"flag_changes": ["medical_alert_pregnancy"]
				}
			}
		]
	}

static func _event_first_birth() -> Dictionary:
	return {
		"type": "first_birth",
		"title": "A New World's First Citizen",
		"description": "After 14 hours of labor, a healthy baby has been born. The first human born on Mars. The entire colony has gathered. This moment will be in history books.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 3,
		"max_year": 15,
		"one_time": true,
		"trigger_chance": 1.0,
		"conditions": {"requires_mars_born": false},
		"choices": [
			{
				"id": "name",
				"text": "Name the child yourself",
				"description": "High investment in this character.",
				"effects": {
					"morale_change": 30.0
				}
			},
			{
				"id": "parents",
				"text": "Let the parents choose",
				"description": "Respect for privacy.",
				"effects": {
					"morale_change": 25.0
				}
			},
			{
				"id": "vote",
				"text": "Hold a colony-wide naming vote",
				"description": "Democratic tradition established.",
				"effects": {
					"morale_change": 20.0,
					"stability_change": 5.0
				}
			}
		]
	}

static func _event_first_death() -> Dictionary:
	return {
		"type": "first_death",
		"title": "The First to Fall",
		"description": "A colonist has died. The colony has lost its first member. In the cramped quarters, surrounded by the Martian void, death feels very close.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 1,
		"max_year": 10,
		"one_time": true,
		"trigger_chance": 1.0,  # Triggered automatically on first death
		"choices": [
			{
				"id": "funeral",
				"text": "Full funeral ceremony",
				"description": "1 day of mourning. Establish traditions.",
				"effects": {
					"morale_change": -10.0,
					"stability_change": 10.0,
					"flag_changes": ["funeral_tradition"]
				}
			},
			{
				"id": "brief",
				"text": "Brief memorial (mission continues)",
				"description": "2 hours ceremony.",
				"effects": {
					"morale_change": -15.0
				}
			},
			{
				"id": "crew_decide",
				"text": "Let the crew decide",
				"description": "Democratic, but you appear weak.",
				"effects": {
					"stability_change": -5.0
				}
			}
		]
	}

# ============================================================================
# EVENT DEFINITIONS - ACT 2
# ============================================================================

static func _event_council_formation() -> Dictionary:
	return {
		"type": "council_formation",
		"title": "The Voice of the People",
		"description": "The colony has grown beyond the founding crew. New colonists want representation. Factions are emerging. It's time to decide how decisions get made.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 6,
		"max_year": 15,
		"one_time": true,
		"trigger_chance": 0.8,
		"min_population": 25,
		"choices": [
			{
				"id": "advisory",
				"text": "Establish advisory council (you retain authority)",
				"description": "Council advises, you decide.",
				"effects": {
					"stability_change": 10.0,
					"flag_changes": ["political_advisory"]
				}
			},
			{
				"id": "governing",
				"text": "Establish governing council (shared power)",
				"description": "Council votes on major decisions.",
				"effects": {
					"stability_change": 15.0,
					"morale_change": 10.0,
					"flag_changes": ["political_representative"]
				}
			},
			{
				"id": "resist",
				"text": "Resist formalization (maintain founder rule)",
				"description": "The original crew knows best.",
				"effects": {
					"stability_change": -10.0,
					"morale_change": -15.0,
					"faction_changes": {ColonySimTypes.Faction.FOUNDERS: 15}
				}
			},
			{
				"id": "democracy",
				"text": "Full democracy immediately",
				"description": "Elected council with full power.",
				"effects": {
					"stability_change": 5.0,
					"morale_change": 20.0
				}
			}
		]
	}

static func _event_first_election() -> Dictionary:
	return {
		"type": "first_election",
		"title": "Democracy on Mars",
		"description": "The first election on Mars. Three candidates have emerged from different factions. Campaigning has been intense.",
		"severity": ColonySimTypes.EventSeverity.MODERATE,
		"min_year": 8,
		"max_year": 20,
		"one_time": true,
		"trigger_chance": 0.9,
		"min_population": 30,
		"choices": [
			{
				"id": "endorse_earther",
				"text": "Endorse the Earther candidate",
				"description": "Gain influence with Earthers, lose with others.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.EARTHERS: 20,
						ColonySimTypes.Faction.MARTIANS: -15
					}
				}
			},
			{
				"id": "endorse_founder",
				"text": "Endorse the Founder candidate",
				"description": "Gain influence with Founders.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.FOUNDERS: 20,
						ColonySimTypes.Faction.MARTIANS: -10
					}
				}
			},
			{
				"id": "endorse_martian",
				"text": "Endorse the Martian candidate",
				"description": "Gain influence with Martians.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.MARTIANS: 20,
						ColonySimTypes.Faction.EARTHERS: -15
					}
				}
			},
			{
				"id": "neutral",
				"text": "Remain neutral",
				"description": "Leader above politics.",
				"effects": {
					"stability_change": 5.0
				}
			}
		]
	}

static func _event_first_strike() -> Dictionary:
	return {
		"type": "first_strike",
		"title": "Tools Down",
		"description": "15 workers have stopped working. They demand better conditions, more say in resource allocation, and a Workers' Council. Food production has halted.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 10,
		"max_year": 30,
		"cooldown_years": 10,
		"trigger_chance": 0.3,
		"min_population": 50,
		"choices": [
			{
				"id": "negotiate",
				"text": "Negotiate in good faith",
				"description": "Meet with leaders, discuss demands.",
				"effects": {
					"stability_change": 5.0,
					"faction_changes": {ColonySimTypes.Faction.PRAGMATISTS: 10}
				}
			},
			{
				"id": "meet",
				"text": "Meet demands immediately",
				"description": "Strike ends. Others see you as weak.",
				"effects": {
					"morale_change": 15.0,
					"stability_change": -10.0
				}
			},
			{
				"id": "refuse",
				"text": "Refuse to negotiate",
				"description": "Wait them out. Risk escalation.",
				"effects": {},
				"success_chance": 0.5,
				"failure_effects": {
					"stability_change": -20.0,
					"morale_change": -20.0
				}
			},
			{
				"id": "arrest",
				"text": "Arrest the leaders",
				"description": "Strike ends. Radicalization risk.",
				"effects": {
					"morale_change": -30.0,
					"stability_change": -15.0,
					"flag_changes": ["authoritarian_action"]
				}
			}
		]
	}

static func _event_first_gen_comes_of_age() -> Dictionary:
	return {
		"type": "first_gen_comes_of_age",
		"title": "Children of Mars",
		"description": "The first Mars-born child has reached adulthood. They've never seen Earth except in pictures. Mars is the only home they've ever known.",
		"severity": ColonySimTypes.EventSeverity.MODERATE,
		"min_year": 18,
		"max_year": 30,
		"one_time": true,
		"trigger_chance": 1.0,
		"conditions": {"requires_mars_born": true},
		"choices": [
			{
				"id": "ceremony",
				"text": "Grand ceremony (Coming of Age tradition)",
				"description": "Colony-wide celebration.",
				"effects": {
					"morale_change": 20.0,
					"flag_changes": ["coming_of_age_tradition"]
				}
			},
			{
				"id": "quiet",
				"text": "Quiet recognition",
				"description": "Personal ceremony with family.",
				"effects": {
					"morale_change": 10.0
				}
			},
			{
				"id": "political",
				"text": "Use the moment politically",
				"description": "Speech about Mars independence.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.MARTIANS: 20,
						ColonySimTypes.Faction.EARTHERS: -10
					}
				}
			}
		]
	}

static func _event_founder_aging() -> Dictionary:
	return {
		"type": "founder_aging",
		"title": "The Weight of Years",
		"description": "The oldest founder has been reflecting on their age. They want to discuss succession—who will carry on their knowledge?",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 15,
		"max_year": 40,
		"cooldown_years": 10,
		"trigger_chance": 0.5,
		"is_quiet_moment": true,
		"conditions": {"requires_founders_alive": true},
		"choices": [
			{
				"id": "apprentice",
				"text": "Formal apprenticeship program",
				"description": "Founder trains designated successor.",
				"effects": {
					"morale_change": 5.0,
					"flag_changes": ["knowledge_transfer_active"]
				}
			},
			{
				"id": "document",
				"text": "Documentation project",
				"description": "Founder writes everything down.",
				"effects": {
					"flag_changes": ["founders_manual_created"]
				}
			},
			{
				"id": "reassure",
				"text": "You've still got years left",
				"description": "Reassure them.",
				"effects": {
					"morale_change": 3.0
				}
			}
		]
	}

static func _event_immigration_clash() -> Dictionary:
	return {
		"type": "immigration_clash",
		"title": "New Blood, Old Tensions",
		"description": "Tensions are rising between the 'old guard' and the 'newcomers.' The newcomers expected a functioning colony. The founders feel their sacrifice is dismissed.",
		"severity": ColonySimTypes.EventSeverity.MODERATE,
		"min_year": 8,
		"max_year": 20,
		"cooldown_years": 5,
		"trigger_chance": 0.4,
		"min_population": 40,
		"choices": [
			{
				"id": "founders",
				"text": "Side with the founders",
				"description": "They earned their place.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.FOUNDERS: 20,
						ColonySimTypes.Faction.EARTHERS: -15
					}
				}
			},
			{
				"id": "newcomers",
				"text": "Side with the newcomers",
				"description": "Fresh perspectives help us grow.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.EARTHERS: 20,
						ColonySimTypes.Faction.FOUNDERS: -15
					}
				}
			},
			{
				"id": "bridge",
				"text": "Bridge-building program",
				"description": "Pair founders with newcomers.",
				"effects": {
					"stability_change": 10.0
				}
			},
			{
				"id": "segregate",
				"text": "Segregate to avoid conflict",
				"description": "Peace through distance.",
				"effects": {
					"stability_change": -5.0,
					"flag_changes": ["cultural_segregation"]
				}
			}
		]
	}

# ============================================================================
# EVENT DEFINITIONS - ACT 3 & 4
# ============================================================================

static func _event_independence_question() -> Dictionary:
	return {
		"type": "independence_question",
		"title": "A Fork in the Road",
		"description": "The colony no longer needs Earth to survive. The Independence Faction has called for a referendum. Should Mars seek political independence?",
		"severity": ColonySimTypes.EventSeverity.CRITICAL,
		"min_year": 25,
		"max_year": 60,
		"one_time": true,
		"trigger_chance": 0.7,
		"min_population": 200,
		"required_phase": ColonySimTypes.ColonyPhase.ACT_3_COLONY,
		"choices": [
			{
				"id": "support",
				"text": "Support independence",
				"description": "You become symbol of the movement.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.MARTIANS: 30,
						ColonySimTypes.Faction.EARTHERS: -30
					},
					"flag_changes": ["independence_supported"]
				}
			},
			{
				"id": "oppose",
				"text": "Support remaining with Earth",
				"description": "You become symbol of Earth loyalty.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.EARTHERS: 30,
						ColonySimTypes.Faction.MARTIANS: -30
					},
					"flag_changes": ["independence_opposed"]
				}
			},
			{
				"id": "unity",
				"text": "Call for unity regardless of outcome",
				"description": "Respected by both sides.",
				"effects": {
					"stability_change": 10.0
				}
			},
			{
				"id": "abstain",
				"text": "Abstain (let the people decide)",
				"description": "Some see leadership, some see cowardice.",
				"effects": {}
			}
		]
	}

static func _event_life_evidence() -> Dictionary:
	return {
		"type": "life_evidence",
		"title": "We Are Not Alone",
		"description": "Deep drill samples contain microbial fossils. Three billion years old. Life on Mars. This changes everything.",
		"severity": ColonySimTypes.EventSeverity.CRITICAL,
		"min_year": 25,
		"max_year": 80,
		"one_time": true,
		"trigger_chance": 0.1,
		"min_population": 100,
		"required_phase": ColonySimTypes.ColonyPhase.ACT_3_COLONY,
		"choices": [
			{
				"id": "announce",
				"text": "Announce immediately",
				"description": "Full transparency. Earth goes wild.",
				"effects": {
					"morale_change": 20.0,
					"faction_changes": {ColonySimTypes.Faction.FOUNDERS: 30}
				}
			},
			{
				"id": "verify",
				"text": "Verify thoroughly (6 months)",
				"description": "Scientific credibility.",
				"effects": {
					"flag_changes": ["life_verification_pending"]
				}
			},
			{
				"id": "control",
				"text": "Control the narrative",
				"description": "You decide the framing.",
				"effects": {
					"stability_change": -5.0
				},
				"success_chance": 0.7,
				"failure_effects": {
					"stability_change": -20.0,
					"morale_change": -15.0
				}
			},
			{
				"id": "suppress",
				"text": "Suppress the finding",
				"description": "Too big. Too dangerous.",
				"effects": {
					"flag_changes": ["life_evidence_suppressed"]
				}
			}
		]
	}

static func _event_terraforming_proposal() -> Dictionary:
	return {
		"type": "terraforming_proposal",
		"title": "The Long Dream",
		"description": "A visionary scientist proposes terraforming. Not in our lifetimes. Maybe 500 years. But Mars could have an atmosphere. Blue skies. Rain.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 30,
		"max_year": 80,
		"one_time": true,
		"trigger_chance": 0.3,
		"min_population": 300,
		"required_phase": ColonySimTypes.ColonyPhase.ACT_3_COLONY,
		"choices": [
			{
				"id": "begin",
				"text": "Begin the Long Project",
				"description": "10% of production to terraforming.",
				"effects": {
					"faction_changes": {ColonySimTypes.Faction.VISIONARIES: 30},
					"flag_changes": ["terraforming_begun"]
				}
			},
			{
				"id": "research",
				"text": "Research only",
				"description": "Small science investment.",
				"effects": {}
			},
			{
				"id": "reject",
				"text": "Reject terraforming",
				"description": "Mars should stay Mars.",
				"effects": {
					"faction_changes": {
						ColonySimTypes.Faction.PRAGMATISTS: 20,
						ColonySimTypes.Faction.VISIONARIES: -20
					}
				}
			},
			{
				"id": "referendum",
				"text": "Let the people decide",
				"description": "Democratic legitimacy.",
				"effects": {
					"stability_change": 5.0
				}
			}
		]
	}

static func _event_last_founder_dies() -> Dictionary:
	return {
		"type": "last_founder_dies",
		"title": "The End of an Era",
		"description": "The last of the original eight has died. They were the last person alive who remembered Earth's sky. The Founding Generation has ended.",
		"severity": ColonySimTypes.EventSeverity.MAJOR,
		"min_year": 50,
		"max_year": 100,
		"one_time": true,
		"trigger_chance": 1.0,
		"choices": [
			{
				"id": "holiday",
				"text": "Establish Founder's Day (holiday)",
				"description": "Annual commemoration.",
				"effects": {
					"morale_change": 10.0,
					"stability_change": 10.0,
					"flag_changes": ["founders_day_established"]
				}
			},
			{
				"id": "memorial",
				"text": "Living memorial (rename facility)",
				"description": "Their name lives on.",
				"effects": {
					"morale_change": 5.0
				}
			},
			{
				"id": "forward",
				"text": "Move forward (no formal commemoration)",
				"description": "Focus on the future.",
				"effects": {
					"morale_change": -5.0
				}
			}
		]
	}

static func _event_earth_collapse() -> Dictionary:
	return {
		"type": "earth_collapse",
		"title": "Silence from Home",
		"description": "Transmissions from Earth have stopped. For three weeks, nothing. Then a fragment: '...war... infrastructure collapse... you're on your own...' Then silence. You are truly alone.",
		"severity": ColonySimTypes.EventSeverity.CRITICAL,
		"min_year": 60,
		"max_year": 100,
		"one_time": true,
		"trigger_chance": 0.1,
		"required_phase": ColonySimTypes.ColonyPhase.ACT_4_INDEPENDENCE,
		"choices": [
			{
				"id": "truth",
				"text": "Announce the truth",
				"description": "Panic, then acceptance.",
				"effects": {
					"morale_change": -30.0,
					"stability_change": -20.0,
					"flag_changes": ["earth_collapsed", "alone_in_universe"]
				}
			},
			{
				"id": "controlled",
				"text": "Controlled release",
				"description": "Gradual revelation over months.",
				"effects": {
					"morale_change": -15.0,
					"stability_change": -10.0,
					"flag_changes": ["earth_collapsed"]
				}
			},
			{
				"id": "investigate",
				"text": "Investigate before announcing",
				"description": "Send probe/signal attempts.",
				"effects": {
					"flag_changes": ["earth_investigation_pending"]
				}
			}
		]
	}

# ============================================================================
# QUIET MOMENTS
# ============================================================================

static func _quiet_stargazing_child() -> Dictionary:
	return {
		"type": "quiet_stargazing_child",
		"title": "Questions About Earth",
		"description": "You find Mars-born children at the observation window. One points at a blue dot. 'Is that Earth?' 'Yes.' 'Why do the old people cry when they look at it?'",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 10,
		"max_year": 100,
		"cooldown_years": 5,
		"trigger_chance": 0.2,
		"is_quiet_moment": true,
		"conditions": {"requires_mars_born": true},
		"choices": [
			{
				"id": "miss",
				"text": "Because they miss home",
				"description": "Simple, truthful.",
				"effects": {
					"morale_change": 3.0
				}
			},
			{
				"id": "remember",
				"text": "Because they're remembering people they loved",
				"description": "Deeper truth.",
				"effects": {
					"morale_change": 5.0
				}
			},
			{
				"id": "beautiful",
				"text": "Because it's beautiful",
				"description": "Deflection.",
				"effects": {}
			},
			{
				"id": "silent",
				"text": "[Sit with them in silence]",
				"description": "Peaceful moment.",
				"effects": {
					"morale_change": 5.0
				}
			}
		]
	}

static func _quiet_founders_reunion() -> Dictionary:
	return {
		"type": "quiet_founders_reunion",
		"title": "The Last Four",
		"description": "The surviving founders have gathered for the anniversary. They're looking at old photos, laughing and crying.",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 30,
		"max_year": 60,
		"cooldown_years": 5,
		"trigger_chance": 0.3,
		"is_quiet_moment": true,
		"conditions": {"requires_founders_alive": true},
		"choices": [
			{
				"id": "join",
				"text": "Join them",
				"description": "You're part of this moment.",
				"effects": {
					"morale_change": 10.0
				}
			},
			{
				"id": "privacy",
				"text": "Let them have their moment",
				"description": "Respectful distance.",
				"effects": {
					"morale_change": 3.0
				}
			},
			{
				"id": "colony",
				"text": "Bring the colony in",
				"description": "Make it a celebration.",
				"effects": {
					"morale_change": 15.0,
					"stability_change": 5.0
				}
			}
		]
	}

static func _quiet_first_painting() -> Dictionary:
	return {
		"type": "quiet_first_painting",
		"title": "Martian Art",
		"description": "A Mars-born artist has completed the first original artwork by a Martian. A painting of sunrise, but brighter than reality. 'This is how I see it. Mars through Martian eyes.'",
		"severity": ColonySimTypes.EventSeverity.MINOR,
		"min_year": 15,
		"max_year": 50,
		"one_time": true,
		"trigger_chance": 0.3,
		"is_quiet_moment": true,
		"conditions": {"requires_mars_born": true},
		"choices": [
			{
				"id": "display",
				"text": "Display it prominently",
				"description": "Central plaza installation.",
				"effects": {
					"morale_change": 10.0,
					"flag_changes": ["martian_art_celebrated"]
				}
			},
			{
				"id": "preserve",
				"text": "Preserve it carefully",
				"description": "Historical artifact.",
				"effects": {
					"morale_change": 5.0
				}
			},
			{
				"id": "commission",
				"text": "Commission more art",
				"description": "Art program begins.",
				"effects": {
					"morale_change": 8.0,
					"flag_changes": ["art_program_active"]
				}
			}
		]
	}

# ============================================================================
# HELPERS
# ============================================================================

static func _get_random(arr: Array, idx: int) -> float:
	if idx < arr.size():
		return arr[idx]
	return 0.5

static func _calc_avg_morale(colonists: Array) -> float:
	var total = 0.0
	var count = 0
	for c in colonists:
		if c.is_alive:
			total += c.morale
			count += 1
	return total / maxf(count, 1.0)
