extends RefCounted
class_name MCSEvents

## MCS (Mars Colony Sim) Event Logic - SIMPLIFIED
## Core events for the colony narrative arc
## All functions are static and deterministic

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const _MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")

# ============================================================================
# EVENT DEFINITIONS - 12 Core Events
# ============================================================================

static func get_all_events() -> Array:
	return [
		# SURVIVAL (Years 1-5)
		_event_first_crisis(),
		_event_first_birth(),
		_event_first_death(),

		# GROWTH (Years 5-20)
		_event_council_formation(),
		_event_first_generation(),
		_event_resource_conflict(),

		# SOCIETY (Years 20-50)
		_event_independence_question(),
		_event_discovery(),
		_event_last_founder(),

		# QUIET MOMENTS (any time)
		_quiet_homesickness(),
		_quiet_celebration(),
		_quiet_stargazing()
	]

# ============================================================================
# EVENT SELECTION
# ============================================================================

static func get_eligible_events(state: Dictionary) -> Array:
	var all_events = get_all_events()
	var eligible: Array = []

	for event in all_events:
		if _can_event_trigger(event, state):
			eligible.append(event)

	return eligible

## Select events for a year from eligible events
## Called with: (eligible_events, state, rand1, rand2)
static func select_yearly_events(eligible: Array, state: Dictionary, rand1: float, rand2: float) -> Array:
	var selected: Array = []
	var random_values = [rand1, rand2]
	var random_idx = 0

	# Select up to 2 events per year
	for event in eligible:
		if selected.size() >= 2:
			break

		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var trigger_chance = event.get("trigger_chance", 0.5)

		# Boost chance if event is overdue
		var event_cooldowns = state.get("event_cooldowns", {})
		var last_trigger = event_cooldowns.get(event.get("type", ""), 0)
		var years_since = state.get("current_year", 1) - last_trigger
		if years_since > 5:
			trigger_chance *= 1.5

		if rand < trigger_chance:
			var cooldown = event.get("cooldown_years", 3)
			if years_since >= cooldown or last_trigger == 0:
				selected.append(event)

	return selected

static func _can_event_trigger(event: Dictionary, state: Dictionary) -> bool:
	var year = state.get("current_year", 1)

	if year < event.get("min_year", 0):
		return false
	if year > event.get("max_year", 999):
		return false

	var min_pop = event.get("min_population", 0)
	var colonists = state.get("colonists", [])
	if _MCSPopulation.count_alive(colonists) < min_pop:
		return false

	var event_cooldowns = state.get("event_cooldowns", {})
	var last_trigger = event_cooldowns.get(event.get("type", ""), 0)
	if event.get("one_time", false) and last_trigger > 0:
		return false

	return true

# ============================================================================
# EVENT RESOLUTION
# ============================================================================

static func apply_event_choice(state: Dictionary, event: Dictionary, choice_index: int, random_value: float) -> Dictionary:
	var choices = event.get("choices", [])
	if choices.is_empty() or choice_index < 0 or choice_index >= choices.size():
		return {"state": state, "outcome": "No choice selected"}

	var choice = choices[choice_index]

	var new_state = state.duplicate(true)
	var effects = choice.get("effects", {})

	# Check for skill check
	var success = true
	if choice.get("success_chance", 1.0) < 1.0:
		success = random_value < choice.get("success_chance", 1.0)
		if not success and choice.has("failure_effects"):
			effects = choice.get("failure_effects", {})

	# Apply morale change
	if effects.has("morale_change"):
		var change = effects.get("morale_change", 0.0)
		var colonists = new_state.get("colonists", [])
		var updated_colonists: Array = []
		for c in colonists:
			if c.get("is_alive", false):
				var new_morale = clampf(c.get("morale", 50.0) + change, 0.0, 100.0)
				updated_colonists.append(_MCSTypes.with_field(c, "morale", new_morale))
			else:
				updated_colonists.append(c)
		new_state["colonists"] = updated_colonists

	# Apply stability change
	if effects.has("stability_change"):
		var politics = new_state.get("politics", {})
		var current_stability = politics.get("stability", 75.0)
		var change = effects.get("stability_change", 0.0)
		politics["stability"] = clampf(current_stability + change, 0.0, 100.0)
		new_state["politics"] = politics

	# Apply resource changes
	if effects.has("resource_changes"):
		var res = new_state.get("resources", {}).duplicate()
		var resource_changes = effects.get("resource_changes", {})
		for resource_name in resource_changes:
			res[resource_name] = maxf(0, res.get(resource_name, 0) + resource_changes[resource_name])
		new_state["resources"] = res

	# Update cooldown
	var cooldowns = new_state.get("event_cooldowns", {}).duplicate()
	cooldowns[event.get("type", "")] = new_state.get("current_year", 1)
	new_state["event_cooldowns"] = cooldowns

	var outcome = choice.get("outcome", "Choice made: %s" % choice.get("text", "Unknown"))
	if not success:
		outcome = "Failed: " + outcome

	return {"state": new_state, "outcome": outcome}

# ============================================================================
# SURVIVAL EVENTS (Years 1-5)
# ============================================================================

static func _event_first_crisis() -> Dictionary:
	return {
		"type": "first_crisis",
		"title": "Systems Failure",
		"description": "Multiple systems have failed simultaneously. Life support is at 60%. This is the first real test of the colony.",
		"severity": _MCSTypes.EventSeverity.MAJOR,
		"min_year": 1, "max_year": 5,
		"one_time": true,
		"trigger_chance": 0.8,
		"choices": [
			{
				"id": "emergency",
				"text": "All hands emergency repair",
				"outcome": "Everyone worked through the night. Systems restored.",
				"effects": {"morale_change": -10.0, "resource_changes": {"machine_parts": -10}}
			},
			{
				"id": "systematic",
				"text": "Systematic diagnosis first",
				"outcome": "Found the root cause. Efficient repair.",
				"effects": {"resource_changes": {"machine_parts": -5}},
				"success_chance": 0.7,
				"failure_effects": {"morale_change": -20.0, "stability_change": -10.0}
			}
		]
	}

static func _event_first_birth() -> Dictionary:
	return {
		"type": "first_birth",
		"title": "First Martian",
		"description": "A baby has been born - the first human born on Mars. The colony gathers to celebrate.",
		"severity": _MCSTypes.EventSeverity.MAJOR,
		"min_year": 3, "max_year": 15,
		"one_time": true,
		"trigger_chance": 1.0,
		"choices": [
			{
				"id": "celebrate",
				"text": "Colony-wide celebration",
				"outcome": "A day of joy. Mars has its first native.",
				"effects": {"morale_change": 25.0, "stability_change": 10.0}
			},
			{
				"id": "quiet",
				"text": "Private family moment",
				"outcome": "The parents appreciate the privacy.",
				"effects": {"morale_change": 15.0}
			}
		]
	}

static func _event_first_death() -> Dictionary:
	return {
		"type": "first_death",
		"title": "The First Loss",
		"description": "A colonist has died. The colony has lost its first member. In the cramped quarters, death feels very close.",
		"severity": _MCSTypes.EventSeverity.MAJOR,
		"min_year": 1, "max_year": 10,
		"one_time": true,
		"trigger_chance": 1.0,
		"choices": [
			{
				"id": "funeral",
				"text": "Full funeral ceremony",
				"outcome": "A day of mourning. Traditions established.",
				"effects": {"morale_change": -10.0, "stability_change": 10.0}
			},
			{
				"id": "brief",
				"text": "Brief memorial",
				"outcome": "Life must continue.",
				"effects": {"morale_change": -15.0}
			}
		]
	}

# ============================================================================
# GROWTH EVENTS (Years 5-20)
# ============================================================================

static func _event_council_formation() -> Dictionary:
	return {
		"type": "council_formation",
		"title": "Voice of the People",
		"description": "The colony has grown. New arrivals want representation. It's time to decide how decisions get made.",
		"severity": _MCSTypes.EventSeverity.MAJOR,
		"min_year": 6, "max_year": 20,
		"min_population": 25,
		"one_time": true,
		"trigger_chance": 0.8,
		"choices": [
			{
				"id": "advisory",
				"text": "Advisory council (you retain authority)",
				"outcome": "Council advises, you decide.",
				"effects": {"stability_change": 10.0}
			},
			{
				"id": "governing",
				"text": "Governing council (shared power)",
				"outcome": "Democracy takes root on Mars.",
				"effects": {"stability_change": 15.0, "morale_change": 10.0}
			},
			{
				"id": "resist",
				"text": "Maintain founder rule",
				"outcome": "Tensions rise among newcomers.",
				"effects": {"stability_change": -10.0, "morale_change": -15.0}
			}
		]
	}

static func _event_first_generation() -> Dictionary:
	return {
		"type": "first_generation",
		"title": "Children of Mars",
		"description": "The first Mars-born child has reached adulthood. They've never seen Earth. Mars is the only home they know.",
		"severity": _MCSTypes.EventSeverity.MODERATE,
		"min_year": 18, "max_year": 35,
		"one_time": true,
		"trigger_chance": 1.0,
		"choices": [
			{
				"id": "ceremony",
				"text": "Coming of age ceremony",
				"outcome": "A new tradition for a new world.",
				"effects": {"morale_change": 20.0}
			},
			{
				"id": "political",
				"text": "Speech about Mars identity",
				"outcome": "The Martian faction grows stronger.",
				"effects": {"morale_change": 10.0, "stability_change": -5.0}
			}
		]
	}

static func _event_resource_conflict() -> Dictionary:
	return {
		"type": "resource_conflict",
		"title": "Resource Dispute",
		"description": "Workers demand better conditions and more say in resource allocation. Production has slowed.",
		"severity": _MCSTypes.EventSeverity.MAJOR,
		"min_year": 10, "max_year": 40,
		"min_population": 40,
		"cooldown_years": 10,
		"trigger_chance": 0.4,
		"choices": [
			{
				"id": "negotiate",
				"text": "Negotiate in good faith",
				"outcome": "Compromise reached. Relations improve.",
				"effects": {"stability_change": 10.0}
			},
			{
				"id": "meet",
				"text": "Meet demands immediately",
				"outcome": "Workers happy. Others see weakness.",
				"effects": {"morale_change": 15.0, "stability_change": -5.0}
			},
			{
				"id": "refuse",
				"text": "Refuse to negotiate",
				"outcome": "Standoff. Risk of escalation.",
				"effects": {},
				"success_chance": 0.5,
				"failure_effects": {"stability_change": -20.0, "morale_change": -20.0}
			}
		]
	}

# ============================================================================
# SOCIETY EVENTS (Years 20+)
# ============================================================================

static func _event_independence_question() -> Dictionary:
	return {
		"type": "independence_question",
		"title": "The Independence Question",
		"description": "The colony no longer needs Earth to survive. Should Mars seek political independence?",
		"severity": _MCSTypes.EventSeverity.CRITICAL,
		"min_year": 25, "max_year": 80,
		"min_population": 100,
		"one_time": true,
		"trigger_chance": 0.6,
		"choices": [
			{
				"id": "support",
				"text": "Support independence",
				"outcome": "You become a symbol of the movement.",
				"effects": {"morale_change": 10.0}
			},
			{
				"id": "oppose",
				"text": "Support remaining with Earth",
				"outcome": "Traditionalists are relieved.",
				"effects": {"stability_change": 5.0}
			},
			{
				"id": "unity",
				"text": "Call for unity regardless",
				"outcome": "Respected by both sides.",
				"effects": {"stability_change": 10.0}
			}
		]
	}

static func _event_discovery() -> Dictionary:
	return {
		"type": "discovery",
		"title": "Breakthrough Discovery",
		"description": "Deep drill samples contain something remarkable - evidence of ancient microbial life. Life existed on Mars.",
		"severity": _MCSTypes.EventSeverity.CRITICAL,
		"min_year": 20, "max_year": 100,
		"one_time": true,
		"trigger_chance": 0.2,
		"choices": [
			{
				"id": "announce",
				"text": "Announce immediately",
				"outcome": "Earth goes wild. History made.",
				"effects": {"morale_change": 30.0}
			},
			{
				"id": "verify",
				"text": "Verify thoroughly first",
				"outcome": "Scientific credibility preserved.",
				"effects": {"morale_change": 10.0, "stability_change": 5.0}
			}
		]
	}

static func _event_last_founder() -> Dictionary:
	return {
		"type": "last_founder",
		"title": "End of an Era",
		"description": "The last of the original founders has died. They were the last person who remembered Earth's sky.",
		"severity": _MCSTypes.EventSeverity.MAJOR,
		"min_year": 50, "max_year": 100,
		"one_time": true,
		"trigger_chance": 1.0,
		"choices": [
			{
				"id": "holiday",
				"text": "Establish Founder's Day",
				"outcome": "Annual commemoration established.",
				"effects": {"morale_change": 10.0, "stability_change": 10.0}
			},
			{
				"id": "memorial",
				"text": "Name a facility after them",
				"outcome": "Their name lives on.",
				"effects": {"morale_change": 5.0}
			},
			{
				"id": "forward",
				"text": "Focus on the future",
				"outcome": "The colony moves on.",
				"effects": {"morale_change": -5.0}
			}
		]
	}

# ============================================================================
# QUIET MOMENTS
# ============================================================================

static func _quiet_homesickness() -> Dictionary:
	return {
		"type": "quiet_homesickness",
		"title": "Looking at Earth",
		"description": "You find a colonist at the observation window, staring at the blue dot. 'I knew I'd never go back...'",
		"severity": _MCSTypes.EventSeverity.MINOR,
		"min_year": 1, "max_year": 30,
		"cooldown_years": 3,
		"trigger_chance": 0.3,
		"choices": [
			{
				"id": "listen",
				"text": "Listen to their story",
				"outcome": "A long conversation about Earth.",
				"effects": {"morale_change": 8.0}
			},
			{
				"id": "silent",
				"text": "Stand with them in silence",
				"outcome": "No words needed.",
				"effects": {"morale_change": 10.0}
			}
		]
	}

static func _quiet_celebration() -> Dictionary:
	return {
		"type": "quiet_celebration",
		"title": "Anniversary Gathering",
		"description": "Colonists have gathered for the landing anniversary. They're looking at old photos, laughing and crying.",
		"severity": _MCSTypes.EventSeverity.MINOR,
		"min_year": 5, "max_year": 100,
		"cooldown_years": 5,
		"trigger_chance": 0.4,
		"choices": [
			{
				"id": "join",
				"text": "Join them",
				"outcome": "You're part of this moment.",
				"effects": {"morale_change": 10.0}
			},
			{
				"id": "colony",
				"text": "Make it a colony celebration",
				"outcome": "Everyone joins in.",
				"effects": {"morale_change": 15.0, "stability_change": 5.0}
			}
		]
	}

static func _quiet_stargazing() -> Dictionary:
	return {
		"type": "quiet_stargazing",
		"title": "Questions About Earth",
		"description": "Mars-born children at the window. One points at Earth. 'Why do the old people cry when they look at it?'",
		"severity": _MCSTypes.EventSeverity.MINOR,
		"min_year": 15, "max_year": 100,
		"cooldown_years": 5,
		"trigger_chance": 0.3,
		"choices": [
			{
				"id": "miss",
				"text": "Because they miss home",
				"outcome": "Simple truth.",
				"effects": {"morale_change": 3.0}
			},
			{
				"id": "remember",
				"text": "Because they're remembering people they loved",
				"outcome": "Deeper understanding.",
				"effects": {"morale_change": 5.0}
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
