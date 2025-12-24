extends RefCounted
class_name Phase2Reducer

## Phase 2: Travel to Mars - Pure Reducer
## All functions are static and deterministic
## Random values must be passed in via action parameters

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	ADVANCE_HOUR,     # Advance by one hour (primary time action)
	ADVANCE_DAY,      # Advance by 24 hours (convenience for tests/debug)
	SET_SPEED,
	SET_AUTO_ADVANCE,
	TRIGGER_EVENT,
	RESOLVE_EVENT,
	BLOCK_SECTION,
	START_REPAIR,
	EVA_RETRIEVAL,
	ADD_LOG,
	# Ship Systems Integration actions
	APPLY_POWER_DELTA,    # Power drain/generation from control surfaces
	APPLY_RESOURCE_DRAIN, # Crisis resource drain (O2, water, food, etc.)
	APPLY_CREW_DAMAGE,    # Crisis crew damage
	BREAK_SYSTEM,         # Break a ship system (control surface)
	REPAIR_SYSTEM,        # Repair a ship system
	# Life Support actions
	SET_HYDROPONICS_POWER,    # Change hydroponics power level
	DAMAGE_LIFE_SUPPORT,      # Damage a life support system
	REPAIR_LIFE_SUPPORT,      # Repair a life support system
	# Task System actions
	APPLY_TASK_PENALTY        # Apply penalty for failed/cancelled task
}

# ============================================================================
# ACTION CREATORS
# ============================================================================

static func action_advance_hour(random_values: Array) -> Dictionary:
	## Advance time by 1 hour - the primary time advancement action
	return {"type": ActionType.ADVANCE_HOUR, "random_values": random_values}

static func action_advance_day(random_values: Array) -> Dictionary:
	## Advance time by 24 hours (convenience wrapper for tests/debugging)
	return {"type": ActionType.ADVANCE_DAY, "random_values": random_values}

static func action_set_speed(speed: int) -> Dictionary:
	## Set game speed (PAUSED, SLOW, NORMAL, FAST)
	return {"type": ActionType.SET_SPEED, "speed": speed}

static func action_set_auto_advance(auto_advance: bool) -> Dictionary:
	## Enable/disable auto-advance
	return {"type": ActionType.SET_AUTO_ADVANCE, "auto_advance": auto_advance}

static func action_trigger_event(event: Dictionary) -> Dictionary:
	## Trigger an event (pauses auto-advance)
	return {"type": ActionType.TRIGGER_EVENT, "event": event}

static func action_resolve_event(choice_index: int, random_value: float) -> Dictionary:
	## Resolve active event with player choice
	return {"type": ActionType.RESOLVE_EVENT, "choice_index": choice_index, "random_value": random_value}

static func action_block_section(container_id: String, status: int, random_value: float) -> Dictionary:
	## Block a storage container section
	return {"type": ActionType.BLOCK_SECTION, "container_id": container_id, "status": status, "random_value": random_value}

static func action_start_repair(container_id: String, repair_days: int) -> Dictionary:
	## Start repairing a blocked section
	return {"type": ActionType.START_REPAIR, "container_id": container_id, "repair_days": repair_days}

static func action_eva_retrieval(container_id: String, random_value: float) -> Dictionary:
	## Attempt EVA retrieval of supplies from blocked section
	return {"type": ActionType.EVA_RETRIEVAL, "container_id": container_id, "random_value": random_value}

static func action_add_log(message: String) -> Dictionary:
	## Add a log message
	return {"type": ActionType.ADD_LOG, "message": message}

# Ship Systems Integration action creators
static func action_apply_power_delta(delta: float) -> Dictionary:
	## Apply power change from control surfaces (positive = generation, negative = drain)
	return {"type": ActionType.APPLY_POWER_DELTA, "delta": delta}

static func action_apply_resource_drain(resource: String, amount: float) -> Dictionary:
	## Apply resource drain from crises (amount should be negative for drain)
	return {"type": ActionType.APPLY_RESOURCE_DRAIN, "resource": resource, "amount": amount}

static func action_apply_crew_damage(crew_index: int, damage: float) -> Dictionary:
	## Apply damage to specific crew member from crisis
	return {"type": ActionType.APPLY_CREW_DAMAGE, "crew_index": crew_index, "damage": damage}

static func action_break_system(system_id: int, cause: String) -> Dictionary:
	## Break a ship control surface system
	return {"type": ActionType.BREAK_SYSTEM, "system_id": system_id, "cause": cause}

static func action_repair_system(system_id: int) -> Dictionary:
	## Repair a ship control surface system
	return {"type": ActionType.REPAIR_SYSTEM, "system_id": system_id}

# Life Support action creators
static func action_set_hydroponics_power(level: int) -> Dictionary:
	## Set hydroponics power level (0=OFF, 1=LOW, 2=NORMAL, 3=HIGH)
	return {"type": ActionType.SET_HYDROPONICS_POWER, "level": level}

static func action_damage_life_support(system_name: String, amount: float) -> Dictionary:
	## Damage a life support system (hydroponics or water_reclaimer)
	return {"type": ActionType.DAMAGE_LIFE_SUPPORT, "system_name": system_name, "amount": amount}

static func action_repair_life_support(system_name: String, amount: float) -> Dictionary:
	## Repair a life support system
	return {"type": ActionType.REPAIR_LIFE_SUPPORT, "system_name": system_name, "amount": amount}

# Task System action creators
static func action_apply_task_penalty(penalty: Dictionary) -> Dictionary:
	## Apply penalty from failed/cancelled task
	## penalty: {type, amount, task_name, task_type, target (optional)}
	return {"type": ActionType.APPLY_TASK_PENALTY, "penalty": penalty}

# ============================================================================
# MAIN REDUCER
# ============================================================================

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.ADVANCE_HOUR:
			return _reduce_advance_hour(state, action.random_values)
		ActionType.ADVANCE_DAY:
			# Convenience: advance 24 hours (calls ADVANCE_HOUR 24 times)
			var result = state
			for i in range(Phase2Types.HOURS_PER_DAY):
				result = _reduce_advance_hour(result, action.random_values)
			return result
		ActionType.SET_SPEED:
			return _reduce_set_speed(state, action.speed)
		ActionType.SET_AUTO_ADVANCE:
			return _reduce_set_auto_advance(state, action.auto_advance)
		ActionType.TRIGGER_EVENT:
			return _reduce_trigger_event(state, action.event)
		ActionType.RESOLVE_EVENT:
			return _reduce_resolve_event(state, action.choice_index, action.random_value)
		ActionType.BLOCK_SECTION:
			return _reduce_block_section(state, action.container_id, action.status, action.random_value)
		ActionType.START_REPAIR:
			return _reduce_start_repair(state, action.container_id, action.get("repair_hours", action.get("repair_days", 2) * 24))
		ActionType.EVA_RETRIEVAL:
			return _reduce_eva_retrieval(state, action.container_id, action.random_value)
		ActionType.ADD_LOG:
			return _reduce_add_log(state, action.message)
		# Ship Systems Integration
		ActionType.APPLY_POWER_DELTA:
			return _reduce_apply_power_delta(state, action.delta)
		ActionType.APPLY_RESOURCE_DRAIN:
			return _reduce_apply_resource_drain(state, action.resource, action.amount)
		ActionType.APPLY_CREW_DAMAGE:
			return _reduce_apply_crew_damage(state, action.crew_index, action.damage)
		ActionType.BREAK_SYSTEM:
			return _reduce_break_system(state, action.system_id, action.cause)
		ActionType.REPAIR_SYSTEM:
			return _reduce_repair_system(state, action.system_id)
		# Life Support actions
		ActionType.SET_HYDROPONICS_POWER:
			return _reduce_set_hydroponics_power(state, action.level)
		ActionType.DAMAGE_LIFE_SUPPORT:
			return _reduce_damage_life_support(state, action.system_name, action.amount)
		ActionType.REPAIR_LIFE_SUPPORT:
			return _reduce_repair_life_support(state, action.system_name, action.amount)
		# Task System
		ActionType.APPLY_TASK_PENALTY:
			return _reduce_apply_task_penalty(state, action.penalty)
		_:
			return state

# ============================================================================
# HOUR ADVANCEMENT
# ============================================================================

static func _reduce_advance_hour(state: Dictionary, random_values: Array) -> Dictionary:
	## Advance time by 1 hour - runs all hourly updates
	var new_state = state.duplicate(true)
	var random_idx = 0

	# 1. Increment hour and total hours
	new_state.current_hour = new_state.get("current_hour", 0) + 1
	new_state.total_hours = new_state.get("total_hours", 0) + 1

	# 2. Check for day rollover
	var new_day = false
	if new_state.current_hour >= Phase2Types.HOURS_PER_DAY:
		new_state.current_hour = 0
		new_state.current_day += 1
		new_day = true

	# 3. Check repair progress (every hour)
	new_state = _process_repair_progress_hourly(new_state)

	# 4. Consume resources (hourly rates)
	new_state = _consume_hourly_resources(new_state)

	# 5. Update crew stats (hourly rates)
	new_state = _update_crew_hourly(new_state)

	# 6. Check for random events (hourly chance)
	var event_roll = random_values[random_idx] if random_idx < random_values.size() else 0.5
	random_idx += 1
	var event_chance = Phase2Types.get_event_chance_for_hour(new_state.current_day, new_state.total_days)

	if event_roll < event_chance and new_state.active_event.is_empty():
		# Determine if this is a section blockage or regular event
		var blockage_roll = random_values[random_idx] if random_idx < random_values.size() else 0.5
		random_idx += 1

		if blockage_roll < Phase2Types.SECTION_BLOCKAGE_CHANCE:
			# Trigger section blockage
			var container_roll = random_values[random_idx] if random_idx < random_values.size() else 0.5
			random_idx += 1
			new_state = _trigger_section_blockage(new_state, container_roll)
		else:
			# Regular event - add to queue for Store to handle
			new_state.event_queue.append({"type": "random_event", "roll": event_roll})

	# 7. Check Mars visibility milestone (at day boundary)
	if new_day:
		if new_state.current_day >= Phase2Types.MARS_VISIBLE_DAY and not new_state.mars_visible:
			new_state.mars_visible = true
			new_state = _add_log_entry(new_state, "Mars is now visible as a distinct orange dot.")

	# 8. Recompute resource totals
	new_state.resources = Phase2Types.compute_resource_totals(new_state)

	return new_state

static func _process_repair_progress_hourly(state: Dictionary) -> Dictionary:
	## Check and advance repair progress (hourly)
	var repair = state.repair
	if not repair.in_progress:
		return state

	var new_state = state.duplicate(true)
	new_state.repair = repair.duplicate()
	new_state.repair.hours_remaining = new_state.repair.get("hours_remaining", 0) - 1

	# Update legacy days_remaining for display
	new_state.repair.days_remaining = int(ceil(float(new_state.repair.hours_remaining) / Phase2Types.HOURS_PER_DAY))

	if new_state.repair.hours_remaining <= 0:
		# Repair complete!
		new_state.repair.in_progress = false

		# Find and restore the container
		var containers = new_state.storage_containers.duplicate()
		for i in range(containers.size()):
			if containers[i].id == repair.target_container_id:
				var container = containers[i].duplicate()
				container.accessible = true
				container.status = Phase2Types.ContainerStatus.NOMINAL
				containers[i] = container
				new_state = _add_log_entry(new_state, "Repair complete! %s is now accessible." % container.name)
				break
		new_state.storage_containers = containers
		new_state.repair.target_container_id = ""

	return new_state

static func _consume_daily_resources(state: Dictionary) -> Dictionary:
	## Consume food, water, oxygen from accessible containers
	var new_state = state.duplicate(true)
	var crew_count = new_state.crew.size()
	if crew_count == 0:
		crew_count = 4  # Default

	# Food: 1 unit per crew per day
	var food_needed = float(crew_count) * Phase2Types.DAILY_FOOD_PER_CREW
	new_state = _consume_from_containers(new_state, "food", food_needed)

	# Water: 0.5 units per crew per day (with recycling)
	var water_needed = float(crew_count) * Phase2Types.DAILY_WATER_PER_CREW
	new_state = _consume_from_containers(new_state, "water", water_needed)

	# Oxygen: slight daily loss from leakage
	var resources = new_state.resources.duplicate(true)
	resources.oxygen.current = max(0, resources.oxygen.current - Phase2Types.DAILY_OXYGEN_LOSS)
	new_state.resources = resources

	return new_state

static func _consume_from_containers(state: Dictionary, resource_type: String, amount: float) -> Dictionary:
	## Consume resource from accessible containers in order
	var new_state = state.duplicate(true)
	var containers = new_state.storage_containers.duplicate()
	var remaining = amount

	for i in range(containers.size()):
		if remaining <= 0:
			break

		var container = containers[i]
		if not container.accessible:
			continue

		var available = container.get(resource_type, 0)
		if available > 0:
			var consume = min(available, remaining)
			container = container.duplicate()
			container[resource_type] = available - consume
			containers[i] = container
			remaining -= consume
			new_state.active_container_index = i

	new_state.storage_containers = containers
	return new_state

static func _update_crew_daily(state: Dictionary) -> Dictionary:
	## Update crew morale and fatigue daily
	var new_state = state.duplicate(true)
	var crew = new_state.crew.duplicate()

	for i in range(crew.size()):
		var member = crew[i].duplicate()

		# Morale decay from isolation
		member.morale = max(0, member.morale - Phase2Types.DAILY_MORALE_DECAY)

		# Fatigue accumulates
		member.fatigue = min(100, member.fatigue + Phase2Types.DAILY_FATIGUE_GAIN)

		crew[i] = member

	new_state.crew = crew
	return new_state

# ============================================================================
# HOURLY RESOURCE/CREW UPDATES
# ============================================================================

static func _consume_hourly_resources(state: Dictionary) -> Dictionary:
	## Consume food, water, oxygen from accessible containers (hourly rates)
	## Also processes life support systems (hydroponics, water reclaimer, solar panels, CO2 scrubber)
	var new_state = state.duplicate(true)
	var crew_count = new_state.crew.size()
	if crew_count == 0:
		crew_count = 4  # Default

	# Get life support state
	var life_support = new_state.get("life_support", Phase2Types.create_life_support_state())
	life_support = life_support.duplicate(true)

	# Get resources for updates
	var resources = new_state.resources.duplicate(true)

	# =====================
	# SOLAR PANELS (Power Generation) - MUST RUN FIRST
	# =====================
	var solar_health = life_support.get("solar_panels_health", 100.0)
	var solar_enabled = life_support.get("solar_panels_enabled", true)
	var solar_orientation = life_support.get("solar_panel_orientation", 1.0)

	const SOLAR_BASE_OUTPUT = 15.0  # Power per hour at 100% health
	const SOLAR_DAMAGED_OUTPUT = 5.0
	const SOLAR_MIN_HEALTH = 10.0

	var power_generated = 0.0
	if solar_enabled and solar_health > SOLAR_MIN_HEALTH:
		var health_factor = solar_health / 100.0
		var base_output = SOLAR_DAMAGED_OUTPUT + (SOLAR_BASE_OUTPUT - SOLAR_DAMAGED_OUTPUT) * health_factor
		power_generated = base_output * solar_orientation
		resources.power.current = min(resources.power.max, resources.power.current + power_generated)

	# =====================
	# HYDROPONICS (Food Production)
	# =====================
	var food_produced = 0.0
	var hydroponics_enabled = life_support.get("hydroponics_enabled", true)
	var hydroponics_health = life_support.get("hydroponics_health", 100.0)

	if hydroponics_enabled and hydroponics_health > 20:
		var power_level = life_support.get("hydroponics_power_level", 2)
		var level_config = Phase2Types.HYDROPONICS_POWER_LEVELS.get(power_level, {})
		var power_needed = level_config.get("power", 5)

		# Check if we have enough power
		if resources.power.current >= power_needed:
			# Consume power for hydroponics
			resources.power.current = max(0, resources.power.current - power_needed)

			# Grow potatoes (health affects growth rate)
			var health_factor = hydroponics_health / 100.0
			var yield_rate = level_config.get("yield_per_hour", 0.06) * health_factor
			life_support.hydroponics_growth_progress = life_support.get("hydroponics_growth_progress", 0.0) + 1.0

			# Check for harvest
			if life_support.hydroponics_growth_progress >= Phase2Types.HYDROPONICS_GROWTH_CYCLE_HOURS:
				life_support.hydroponics_growth_progress = 0.0
				food_produced = Phase2Types.HYDROPONICS_HARVEST_AMOUNT * health_factor
			else:
				# Small continuous yield
				food_produced = yield_rate

	# =====================
	# WATER RECLAIMER (Efficiency)
	# =====================
	var water_efficiency = 0.0
	var reclaimer_enabled = life_support.get("water_reclaimer_enabled", true)
	var reclaimer_health = life_support.get("water_reclaimer_health", 100.0)
	const RECLAIMER_POWER = 3.0  # Power per hour

	if reclaimer_enabled and reclaimer_health > 0:
		water_efficiency = Phase2Types.get_water_recycling_efficiency(reclaimer_health)
		# Consume power for water reclaimer
		if resources.power.current >= RECLAIMER_POWER:
			resources.power.current = max(0, resources.power.current - RECLAIMER_POWER)
		else:
			# Not enough power - reduced efficiency
			water_efficiency = water_efficiency * 0.5

	# =====================
	# CO2 SCRUBBER (Oxygen Generation)
	# =====================
	var oxygen_produced = 0.0
	var scrubber_enabled = life_support.get("co2_scrubber_enabled", true)
	var scrubber_health = life_support.get("co2_scrubber_health", 100.0)
	const SCRUBBER_POWER = 4.0  # Power per hour
	const SCRUBBER_BASE_OUTPUT = 0.8  # Oxygen per hour at 100%
	const SCRUBBER_DAMAGED_OUTPUT = 0.3

	if scrubber_enabled and scrubber_health > 20:
		if resources.power.current >= SCRUBBER_POWER:
			resources.power.current = max(0, resources.power.current - SCRUBBER_POWER)
			var health_factor = scrubber_health / 100.0
			oxygen_produced = SCRUBBER_DAMAGED_OUTPUT + (SCRUBBER_BASE_OUTPUT - SCRUBBER_DAMAGED_OUTPUT) * health_factor

	# =====================
	# FOOD CONSUMPTION (with hydroponics offset)
	# =====================
	var food_needed = float(crew_count) * Phase2Types.HOURLY_FOOD_PER_CREW
	var net_food_needed = max(0, food_needed - food_produced)

	# Apply resource changes before container updates
	new_state.resources = resources
	new_state = _consume_from_containers(new_state, "food", net_food_needed)

	# If we produced more than we consumed, add to first available container
	if food_produced > food_needed:
		var excess = food_produced - food_needed
		new_state = _add_to_containers(new_state, "food", excess)

	# =====================
	# WATER CONSUMPTION (with recycling)
	# =====================
	# With 92% efficiency, only 8% of water is actually lost
	var base_water_needed = float(crew_count) * Phase2Types.HOURLY_WATER_PER_CREW
	var net_water_needed = Phase2Types.get_net_water_consumption(base_water_needed, water_efficiency)
	new_state = _consume_from_containers(new_state, "water", net_water_needed)

	# =====================
	# OXYGEN (consumption - regeneration from CO2 scrubber)
	# =====================
	resources = new_state.resources.duplicate(true)
	var oxygen_consumed = Phase2Types.HOURLY_OXYGEN_LOSS
	var net_oxygen_change = oxygen_produced - oxygen_consumed
	resources.oxygen.current = clamp(resources.oxygen.current + net_oxygen_change, 0, resources.oxygen.max)
	new_state.resources = resources

	# Update life support state
	new_state.life_support = life_support

	return new_state

static func _add_to_containers(state: Dictionary, resource_type: String, amount: float) -> Dictionary:
	## Add resource to accessible containers (for hydroponics harvest)
	var new_state = state.duplicate(true)
	var containers = new_state.storage_containers.duplicate()
	var remaining = amount

	for i in range(containers.size()):
		if remaining <= 0:
			break

		var container = containers[i]
		if not container.accessible:
			continue

		var current = container.get(resource_type, 0)
		var max_val = container.get(resource_type + "_max", 0)
		var can_add = max_val - current

		if can_add > 0:
			var to_add = min(remaining, can_add)
			var new_container = container.duplicate()
			new_container[resource_type] = current + to_add
			containers[i] = new_container
			remaining -= to_add

	new_state.storage_containers = containers
	return new_state

static func _update_crew_hourly(state: Dictionary) -> Dictionary:
	## Update crew morale and fatigue hourly
	var new_state = state.duplicate(true)
	var crew = new_state.crew.duplicate()

	for i in range(crew.size()):
		var member = crew[i].duplicate()

		# Morale decay from isolation (hourly rate)
		member.morale = max(0, member.morale - Phase2Types.HOURLY_MORALE_DECAY)

		# Fatigue accumulates (hourly rate)
		member.fatigue = min(100, member.fatigue + Phase2Types.HOURLY_FATIGUE_GAIN)

		crew[i] = member

	new_state.crew = crew
	return new_state

# ============================================================================
# SPEED CONTROLS
# ============================================================================

static func _reduce_set_speed(state: Dictionary, speed: int) -> Dictionary:
	var new_state = state.duplicate(true)
	new_state.speed = speed
	if speed != Phase2Types.Speed.PAUSED:
		new_state.auto_advance = true
	return new_state

static func _reduce_set_auto_advance(state: Dictionary, auto_advance: bool) -> Dictionary:
	var new_state = state.duplicate(true)
	new_state.auto_advance = auto_advance
	return new_state

# ============================================================================
# EVENTS
# ============================================================================

static func _reduce_trigger_event(state: Dictionary, event: Dictionary) -> Dictionary:
	## Set the active event and pause auto-advance
	var new_state = state.duplicate(true)
	new_state.active_event = event.duplicate(true)
	new_state.auto_advance = false
	return new_state

static func _reduce_resolve_event(state: Dictionary, choice_index: int, random_value: float) -> Dictionary:
	## Resolve the active event based on player choice
	## Supports FTL-style weighted outcomes
	if state.active_event.is_empty():
		return state

	var new_state = state.duplicate(true)
	var event = new_state.active_event
	var options = event.get("options", [])

	if choice_index < 0 or choice_index >= options.size():
		return state

	var choice = options[choice_index]

	# Check for FTL-style weighted outcomes
	var outcomes = choice.get("outcomes", [])
	if not outcomes.is_empty():
		# Roll against weighted outcomes
		var selected_outcome = _select_weighted_outcome(outcomes, random_value)
		if not selected_outcome.is_empty():
			# Apply all effects from the outcome
			for effect_dict in selected_outcome.get("effects", []):
				new_state = _apply_weighted_effect(new_state, effect_dict, random_value)

			# Log the outcome description if present
			var outcome_desc = selected_outcome.get("description", "")
			if outcome_desc != "":
				new_state = _add_log_entry(new_state, outcome_desc)
	else:
		# Legacy single effect system (backwards compatibility)
		var effect = choice.get("effect", Phase2Types.EventEffectType.MORALE_BOOST)
		new_state = _apply_event_effect(new_state, effect, choice.get("effect_value", 0), random_value)

	# Clear event and resume
	new_state.active_event = {}
	new_state.auto_advance = true

	return new_state

static func _select_weighted_outcome(outcomes: Array, random_value: float) -> Dictionary:
	## Select an outcome based on weighted probability
	## random_value should be 0.0-1.0
	var cumulative = 0.0
	for outcome in outcomes:
		cumulative += outcome.get("weight", 0.0)
		if random_value < cumulative:
			return outcome
	# Fallback to last outcome if weights don't sum to 1.0
	return outcomes[-1] if not outcomes.is_empty() else {}

static func _apply_weighted_effect(state: Dictionary, effect_dict: Dictionary, random_value: float) -> Dictionary:
	## Apply a single effect from a weighted outcome
	## effect_dict: {type, value, target}
	var new_state = state.duplicate(true)
	var effect_type = effect_dict.get("type", "")
	var value = effect_dict.get("value", 0)
	var target = effect_dict.get("target", "all")

	match effect_type:
		"morale":
			new_state = _apply_crew_stat_change(new_state, "morale", value, target, random_value)
		"health":
			new_state = _apply_crew_stat_change(new_state, "health", value, target, random_value)
		"fatigue":
			new_state = _apply_crew_stat_change(new_state, "fatigue", value, target, random_value)
		"food":
			new_state = _apply_resource_change(new_state, "food", value)
		"water":
			new_state = _apply_resource_change(new_state, "water", value)
		"oxygen":
			new_state = _apply_resource_change(new_state, "oxygen", value)
		"power":
			new_state = _apply_resource_change(new_state, "power", value)
		"fuel":
			new_state = _apply_resource_change(new_state, "fuel", value)
		"log":
			# Log message is stored in target field for this effect type
			if target != "all" and target != "":
				new_state = _add_log_entry(new_state, target)

	return new_state

static func _apply_crew_stat_change(state: Dictionary, stat: String, value: int, target: String, random_value: float) -> Dictionary:
	## Apply a stat change to crew members
	## target: "all", "random", or crew role name (e.g., "engineer")
	var new_state = state.duplicate(true)
	var crew = new_state.crew.duplicate()

	if target == "all":
		for i in range(crew.size()):
			var member = crew[i].duplicate()
			member[stat] = clamp(member[stat] + value, 0, 100)
			crew[i] = member
	elif target == "random":
		if crew.size() > 0:
			var idx = int(random_value * crew.size()) % crew.size()
			var member = crew[idx].duplicate()
			member[stat] = clamp(member[stat] + value, 0, 100)
			crew[idx] = member
	else:
		# Target specific crew by role
		var role_map = {
			"commander": Phase2Types.CrewRole.COMMANDER,
			"engineer": Phase2Types.CrewRole.ENGINEER,
			"scientist": Phase2Types.CrewRole.SCIENTIST,
			"medical": Phase2Types.CrewRole.MEDICAL
		}
		var target_role = role_map.get(target.to_lower(), -1)
		for i in range(crew.size()):
			if crew[i].role == target_role:
				var member = crew[i].duplicate()
				member[stat] = clamp(member[stat] + value, 0, 100)
				crew[i] = member
				break

	new_state.crew = crew
	return new_state

static func _apply_resource_change(state: Dictionary, resource: String, value: int) -> Dictionary:
	## Apply a resource change (positive or negative)
	var new_state = state.duplicate(true)

	if resource == "food" or resource == "water":
		# These are stored in containers
		var containers = new_state.storage_containers.duplicate()
		var remaining = abs(value)
		var is_loss = value < 0

		for i in range(containers.size()):
			if containers[i].accessible and remaining > 0:
				var container = containers[i].duplicate()
				if is_loss:
					var take = min(container[resource], remaining)
					container[resource] = container[resource] - take
					remaining -= take
				else:
					var space = container[resource + "_max"] - container[resource]
					var add = min(space, remaining)
					container[resource] = container[resource] + add
					remaining -= add
				containers[i] = container

		new_state.storage_containers = containers
		new_state.resources = Phase2Types.compute_resource_totals(new_state)
	else:
		# Direct resource (oxygen, power, fuel)
		var resources = new_state.resources.duplicate(true)
		if resources.has(resource):
			var res = resources[resource].duplicate()
			res.current = clamp(res.current + value, 0, res.max)
			resources[resource] = res
		new_state.resources = resources

	return new_state

static func _apply_event_effect(state: Dictionary, effect, effect_value: int, random_value: float) -> Dictionary:
	## Apply an event effect to the state
	var new_state = state.duplicate(true)

	match effect:
		Phase2Types.EventEffectType.MORALE_BOOST, "morale_boost":
			var crew = new_state.crew.duplicate()
			var boost = effect_value if effect_value > 0 else 10
			for i in range(crew.size()):
				var member = crew[i].duplicate()
				member.morale = min(100, member.morale + boost)
				crew[i] = member
			new_state.crew = crew
			new_state = _add_log_entry(new_state, "Crew morale improved from the good news.")

		Phase2Types.EventEffectType.MORALE_LOSS, "morale_loss", "morale_risk":
			var crew = new_state.crew.duplicate()
			var loss = effect_value if effect_value > 0 else 5
			for i in range(crew.size()):
				var member = crew[i].duplicate()
				member.morale = max(0, member.morale - loss)
				crew[i] = member
			new_state.crew = crew

		Phase2Types.EventEffectType.HEALTH_LOSS, "health_loss", "minor_radiation":
			var crew = new_state.crew.duplicate()
			var loss = effect_value if effect_value > 0 else 5
			for i in range(crew.size()):
				var member = crew[i].duplicate()
				member.health = max(0, member.health - loss)
				crew[i] = member
			new_state.crew = crew
			new_state = _add_log_entry(new_state, "Crew received minor radiation exposure.")

		Phase2Types.EventEffectType.POWER_DRAIN, "power_drain":
			var resources = new_state.resources.duplicate(true)
			var drain = effect_value if effect_value > 0 else 10
			resources.power.current = max(0, resources.power.current - drain)
			new_state.resources = resources
			new_state = _add_log_entry(new_state, "Emergency power diverted to shields. Power reserves depleted.")

		Phase2Types.EventEffectType.FOOD_LOSS, "food_loss", "minor_loss":
			var containers = new_state.storage_containers.duplicate()
			var loss = effect_value if effect_value > 0 else 5
			for i in range(containers.size()):
				if containers[i].accessible and containers[i].food > loss:
					var container = containers[i].duplicate()
					container.food = max(0, container.food - loss)
					containers[i] = container
					break
			new_state.storage_containers = containers
			new_state.resources = Phase2Types.compute_resource_totals(new_state)
			new_state = _add_log_entry(new_state, "Some supplies were lost.")

		Phase2Types.EventEffectType.WATER_LOSS, "water_loss":
			var containers = new_state.storage_containers.duplicate()
			var loss = effect_value if effect_value > 0 else 5
			for i in range(containers.size()):
				if containers[i].accessible and containers[i].water > loss:
					var container = containers[i].duplicate()
					container.water = max(0, container.water - loss)
					containers[i] = container
					break
			new_state.storage_containers = containers
			new_state.resources = Phase2Types.compute_resource_totals(new_state)

		"secure_cargo", "thorough_check":
			new_state = _add_log_entry(new_state, "Cargo properly secured.")

		"quick_check":
			if random_value < 0.1:
				new_state = _add_log_entry(new_state, "Visual check complete, but something may have been missed...")
			else:
				new_state = _add_log_entry(new_state, "Quick visual check - no damage found.")

		# New event effects
		"fatigue_gain":
			# Engineer manually stabilizes - gains fatigue
			var crew = new_state.crew.duplicate()
			var fatigue_amount = effect_value if effect_value > 0 else 15
			for i in range(crew.size()):
				if crew[i].role == Phase2Types.CrewRole.ENGINEER:
					var member = crew[i].duplicate()
					member.fatigue = min(100, member.fatigue + fatigue_amount)
					crew[i] = member
					break
			new_state.crew = crew
			new_state = _add_log_entry(new_state, "Engineer manually stabilized the power systems. Exhausting work.")

		"fuel_loss":
			var resources = new_state.resources.duplicate(true)
			var loss = effect_value if effect_value > 0 else 3
			resources.fuel.current = max(0, resources.fuel.current - loss)
			new_state.resources = resources
			new_state = _add_log_entry(new_state, "Correction burn executed. Fuel consumed.")

		"delay_correction":
			new_state = _add_log_entry(new_state, "Waiting for optimal correction window...")

		"water_fix":
			new_state = _add_log_entry(new_state, "Water recycler filter replaced. Efficiency restored.")

		"partial_fix":
			new_state = _add_log_entry(new_state, "Water recycler cleaned and recalibrated. 90% efficiency.")

		"water_ration":
			new_state = _add_log_entry(new_state, "Crew implementing water rationing until Mars arrival.")

		"use_spare":
			new_state = _add_log_entry(new_state, "Backup sensors installed.")

		"watch_and_wait":
			new_state = _add_log_entry(new_state, "Monitoring oxygen levels closely...")

		"communication_delay":
			new_state = _add_log_entry(new_state, "Accepting temporary communication blackout.")

		"health_check":
			new_state = _add_log_entry(new_state, "Full medical workup complete. Crew health verified.")

		"quick_treatment":
			new_state = _add_log_entry(new_state, "Standard treatment protocol applied.")

		"rest_treatment":
			new_state = _add_log_entry(new_state, "Crew member resting and under observation.")

		# Midpoint crisis effects
		"crisis_repair":
			var crew = new_state.crew.duplicate()
			for i in range(crew.size()):
				var member = crew[i].duplicate()
				member.fatigue = min(100, member.fatigue + 25)
				crew[i] = member
			new_state.crew = crew
			new_state = _add_log_entry(new_state, "All hands emergency repair! Systems stabilized, crew exhausted.")

		"crisis_oxygen":
			var resources = new_state.resources.duplicate(true)
			resources.oxygen.current = max(50, resources.oxygen.current)
			new_state.resources = resources
			new_state = _add_log_entry(new_state, "Oxygen systems prioritized and stabilized.")

		"crisis_eva":
			# Risky EVA to fix both systems
			if random_value > 0.5:
				new_state = _add_log_entry(new_state, "EVA repair successful! Both systems operational.")
			else:
				var crew = new_state.crew.duplicate()
				var victim_idx = int(random_value * crew.size()) % crew.size()
				var victim = crew[victim_idx].duplicate()
				victim.health = max(0, victim.health - 15)
				crew[victim_idx] = victim
				new_state.crew = crew
				new_state = _add_log_entry(new_state, "EVA repair completed with minor injuries. %s treating minor decompression." % victim.name)

		_:
			# Unknown effect - just log it
			new_state = _add_log_entry(new_state, "Event resolved.")

	return new_state

# ============================================================================
# SECTION BLOCKAGE
# ============================================================================

static func _trigger_section_blockage(state: Dictionary, container_roll: float) -> Dictionary:
	## Block a random accessible container
	var new_state = state.duplicate(true)

	# Find blockable containers (accessible, not emergency)
	var blockable_indices: Array = []
	for i in range(new_state.storage_containers.size()):
		var container = new_state.storage_containers[i]
		if container.accessible and container.id != "emergency":
			blockable_indices.append(i)

	if blockable_indices.is_empty():
		return state  # No containers to block

	# Select container based on roll
	var target_idx = blockable_indices[int(container_roll * blockable_indices.size()) % blockable_indices.size()]
	var containers = new_state.storage_containers.duplicate()
	var target = containers[target_idx].duplicate()

	# Determine blockage type
	var blockage_types = [
		Phase2Types.ContainerStatus.DEPRESSURIZED,
		Phase2Types.ContainerStatus.DAMAGED,
		Phase2Types.ContainerStatus.BLOCKED
	]
	var status = blockage_types[int(container_roll * 3) % 3]

	# Block the container
	target.accessible = false
	target.status = status
	containers[target_idx] = target
	new_state.storage_containers = containers

	# Create section blockage event
	var status_name = Phase2Types.get_container_status_name(status)
	var cause = _get_blockage_cause(status)
	var danger = _get_blockage_danger(status)

	var event = Phase2Types.create_event({
		"type": Phase2Types.EventType.SECTION_BLOCKAGE,
		"title": "SECTION %s" % status_name.to_upper(),
		"description": "%s has suffered a %s!\n\nTrapped supplies: %d food, %d water\n\nThe section is currently inaccessible due to %s." % [
			target.name,
			cause,
			target.food,
			target.water,
			danger
		],
		"options": [
			Phase2Types.create_event_option({
				"label": "Repair the section (Engineer, 2-4 days)",
				"effect": Phase2Types.EventEffectType.REPAIR_SECTION,
				"risk": "low",
				"description": "Send the engineer to fix the %s. Safer but takes time." % cause
			}),
			Phase2Types.create_event_option({
				"label": "EVA retrieval (Any crew, immediate)",
				"effect": Phase2Types.EventEffectType.EVA_RETRIEVAL,
				"risk": "high",
				"description": "Spacewalk to access the section from outside. Dangerous but fast."
			})
		],
		"blocked_container_id": target.id
	})

	new_state.active_event = event
	new_state.auto_advance = false

	new_state = _add_log_entry(new_state, "ALERT: %s is now %s!" % [target.name, status_name])

	return new_state

static func _get_blockage_cause(status: int) -> String:
	match status:
		Phase2Types.ContainerStatus.DEPRESSURIZED:
			return "pressure seal failure"
		Phase2Types.ContainerStatus.DAMAGED:
			return "electrical fire"
		Phase2Types.ContainerStatus.BLOCKED:
			return "debris obstruction"
	return "unknown issue"

static func _get_blockage_danger(status: int) -> String:
	match status:
		Phase2Types.ContainerStatus.DEPRESSURIZED:
			return "vacuum exposure"
		Phase2Types.ContainerStatus.DAMAGED:
			return "toxic fumes"
		Phase2Types.ContainerStatus.BLOCKED:
			return "structural instability"
	return "safety concerns"

static func _reduce_block_section(state: Dictionary, container_id: String, status: int, _random_value: float) -> Dictionary:
	## Manually block a specific container section
	var new_state = state.duplicate(true)
	var containers = new_state.storage_containers.duplicate()

	for i in range(containers.size()):
		if containers[i].id == container_id:
			var container = containers[i].duplicate()
			container.accessible = false
			container.status = status
			containers[i] = container
			break

	new_state.storage_containers = containers
	new_state.resources = Phase2Types.compute_resource_totals(new_state)
	return new_state

# ============================================================================
# REPAIR & EVA
# ============================================================================

static func _reduce_start_repair(state: Dictionary, container_id: String, repair_hours: int) -> Dictionary:
	## Start repairing a blocked section (now uses hours)
	var new_state = state.duplicate(true)

	# Find the container
	var container_name = ""
	for container in new_state.storage_containers:
		if container.id == container_id:
			container_name = container.name
			break

	if container_name.is_empty():
		return state

	# Calculate days for display
	var repair_days = int(ceil(float(repair_hours) / Phase2Types.HOURS_PER_DAY))

	# Set up repair state (now in hours)
	new_state.repair = {
		"in_progress": true,
		"hours_remaining": repair_hours,
		"days_remaining": repair_days,  # For display
		"target_container_id": container_id
	}

	# Find and fatigue the engineer
	var crew = new_state.crew.duplicate()
	for i in range(crew.size()):
		if crew[i].role == Phase2Types.CrewRole.ENGINEER:
			var member = crew[i].duplicate()
			member.fatigue = min(100, member.fatigue + Phase2Types.REPAIR_FATIGUE_COST)
			crew[i] = member
			break
	new_state.crew = crew

	# Clear the active event if this was triggered by event resolution
	new_state.active_event = {}
	new_state.auto_advance = true

	new_state = _add_log_entry(new_state, "Engineer dispatched to repair %s. Estimated %d hours (~%d days)." % [container_name, repair_hours, repair_days])

	return new_state

static func _reduce_eva_retrieval(state: Dictionary, container_id: String, random_value: float) -> Dictionary:
	## Attempt EVA retrieval of supplies from blocked section
	var new_state = state.duplicate(true)

	# Find the blocked container
	var containers = new_state.storage_containers.duplicate()
	var container_idx = -1
	var container = {}

	for i in range(containers.size()):
		if containers[i].id == container_id:
			container_idx = i
			container = containers[i].duplicate()
			break

	if container_idx < 0:
		return state

	var food_amount = container.food
	var water_amount = container.water

	if random_value < Phase2Types.EVA_SUCCESS_CHANCE:
		# Success! Retrieve supplies to emergency container
		for i in range(containers.size()):
			if containers[i].id == "emergency":
				var emergency = containers[i].duplicate()
				emergency.food += food_amount
				emergency.water += water_amount
				containers[i] = emergency
				break

		# Original container loses its supplies (retrieved)
		container.food = 0
		container.water = 0
		containers[container_idx] = container

		new_state.storage_containers = containers
		new_state.resources = Phase2Types.compute_resource_totals(new_state)
		new_state = _add_log_entry(new_state, "EVA successful! Retrieved %d food and %d water from %s." % [
			food_amount, water_amount, container.name
		])
	else:
		# Failure - crew member injured, partial retrieval
		var crew = new_state.crew.duplicate()
		var victim_idx = int(random_value * crew.size()) % crew.size()
		var victim = crew[victim_idx].duplicate()
		victim.health = max(0, victim.health - Phase2Types.EVA_INJURY_DAMAGE)
		crew[victim_idx] = victim
		new_state.crew = crew

		# Partial retrieval (30-60%)
		var partial = Phase2Types.EVA_PARTIAL_RETRIEVAL_MIN + random_value * (Phase2Types.EVA_PARTIAL_RETRIEVAL_MAX - Phase2Types.EVA_PARTIAL_RETRIEVAL_MIN)

		for i in range(containers.size()):
			if containers[i].id == "emergency":
				var emergency = containers[i].duplicate()
				emergency.food += int(food_amount * partial)
				emergency.water += int(water_amount * partial)
				containers[i] = emergency
				break

		# Rest is lost
		container.food = 0
		container.water = 0
		containers[container_idx] = container

		new_state.storage_containers = containers
		new_state.resources = Phase2Types.compute_resource_totals(new_state)
		new_state = _add_log_entry(new_state, "EVA COMPLICATION! %s injured during retrieval. Only partial supplies recovered." % victim.name)

	# Clear event and resume
	new_state.active_event = {}
	new_state.auto_advance = true

	return new_state

# ============================================================================
# LOGGING
# ============================================================================

static func _reduce_add_log(state: Dictionary, message: String) -> Dictionary:
	return _add_log_entry(state, message)

static func _add_log_entry(state: Dictionary, message: String) -> Dictionary:
	var new_state = state.duplicate(true)
	var log = new_state.log.duplicate()
	log.append({
		"day": new_state.current_day,
		"hour": new_state.get("current_hour", 0),
		"total_hours": new_state.get("total_hours", 0),
		"message": message
	})
	new_state.log = log
	return new_state

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

static func get_accessible_food(state: Dictionary) -> float:
	var total = 0.0
	for container in state.storage_containers:
		if container.accessible:
			total += container.food
	return total

static func get_accessible_water(state: Dictionary) -> float:
	var total = 0.0
	for container in state.storage_containers:
		if container.accessible:
			total += container.water
	return total

static func get_trapped_food(state: Dictionary) -> float:
	var total = 0.0
	for container in state.storage_containers:
		if not container.accessible:
			total += container.food
	return total

static func get_trapped_water(state: Dictionary) -> float:
	var total = 0.0
	for container in state.storage_containers:
		if not container.accessible:
			total += container.water
	return total

static func get_crew_by_role(state: Dictionary, role: int) -> Dictionary:
	for member in state.crew:
		if member.role == role:
			return member
	return {}

static func get_average_morale(state: Dictionary) -> float:
	if state.crew.is_empty():
		return 0.0
	var total = 0.0
	for member in state.crew:
		total += member.morale
	return total / state.crew.size()

static func get_average_health(state: Dictionary) -> float:
	if state.crew.is_empty():
		return 0.0
	var total = 0.0
	for member in state.crew:
		total += member.health
	return total / state.crew.size()

static func is_repair_in_progress(state: Dictionary) -> bool:
	return state.repair.in_progress

static func has_active_event(state: Dictionary) -> bool:
	return not state.active_event.is_empty()

static func has_arrived(state: Dictionary) -> bool:
	var total_hours = state.get("total_hours", state.current_day * Phase2Types.HOURS_PER_DAY)
	return total_hours >= Phase2Types.TOTAL_TRAVEL_HOURS or state.current_day >= state.total_days

static func is_game_over(state: Dictionary) -> bool:
	return Phase2Types.is_game_over(state)

static func get_days_remaining(state: Dictionary) -> int:
	return max(0, state.total_days - state.current_day)

static func get_hours_remaining(state: Dictionary) -> int:
	var total_hours = state.get("total_hours", 0)
	return max(0, Phase2Types.TOTAL_TRAVEL_HOURS - total_hours)

static func get_journey_progress(state: Dictionary) -> float:
	## Use total_hours for smoother progress (updates every hour not every day)
	var total_hours = state.get("total_hours", state.current_day * Phase2Types.HOURS_PER_DAY)
	return float(total_hours) / float(Phase2Types.TOTAL_TRAVEL_HOURS)

# ============================================================================
# SHIP SYSTEMS INTEGRATION REDUCERS
# ============================================================================

static func _reduce_apply_power_delta(state: Dictionary, delta: float) -> Dictionary:
	## Apply power change from control surfaces
	## delta is the per-second power change already scaled by the caller
	var new_state = state.duplicate(true)
	var resources = new_state.resources.duplicate(true)

	if resources.has("power"):
		var power = resources.power.duplicate()
		power.current = clamp(power.current + delta, 0, power.max)
		resources.power = power
		new_state.resources = resources

	return new_state

static func _reduce_apply_resource_drain(state: Dictionary, resource: String, amount: float) -> Dictionary:
	## Apply resource drain from crises
	## Supports: oxygen, power, fuel (direct), food, water (container-based)
	var new_state = state.duplicate(true)

	if resource == "food" or resource == "water":
		# Container-based resources
		new_state = _consume_from_containers(new_state, resource, abs(amount) if amount < 0 else 0)
		if amount > 0:
			# Adding resources - find accessible container with space
			var containers = new_state.storage_containers.duplicate()
			var remaining = amount
			for i in range(containers.size()):
				if containers[i].accessible and remaining > 0:
					var container = containers[i].duplicate()
					var space = container[resource + "_max"] - container[resource]
					var add_amt = min(space, remaining)
					container[resource] = container[resource] + add_amt
					remaining -= add_amt
					containers[i] = container
			new_state.storage_containers = containers
		new_state.resources = Phase2Types.compute_resource_totals(new_state)
	else:
		# Direct resources (oxygen, power, fuel)
		var resources = new_state.resources.duplicate(true)
		if resources.has(resource):
			var res = resources[resource].duplicate()
			res.current = clamp(res.current + amount, 0, res.max)
			resources[resource] = res
			new_state.resources = resources

	return new_state

static func _reduce_apply_crew_damage(state: Dictionary, crew_index: int, damage: float) -> Dictionary:
	## Apply damage to a specific crew member
	var new_state = state.duplicate(true)
	var crew = new_state.crew.duplicate()

	if crew_index >= 0 and crew_index < crew.size():
		var member = crew[crew_index].duplicate()
		member.health = clamp(member.health - damage, 0, 100)
		crew[crew_index] = member
		new_state.crew = crew

		if member.health <= 0:
			new_state = _add_log_entry(new_state, "%s has died from injuries." % member.name)

	return new_state

static func _reduce_break_system(state: Dictionary, system_id: int, cause: String) -> Dictionary:
	## Mark a ship system as broken in state
	## The actual breaking is handled by ControlSurfaceManager, this just tracks it in store
	var new_state = state.duplicate(true)

	# Initialize broken_systems array if not present
	if not new_state.has("broken_systems"):
		new_state.broken_systems = []

	var broken = new_state.broken_systems.duplicate()
	if system_id not in broken:
		broken.append(system_id)
		new_state.broken_systems = broken
		new_state = _add_log_entry(new_state, "SYSTEM FAILURE: %s (%s)" % [_get_system_name(system_id), cause])

	return new_state

static func _reduce_repair_system(state: Dictionary, system_id: int) -> Dictionary:
	## Mark a ship system as repaired in state
	var new_state = state.duplicate(true)

	if new_state.has("broken_systems"):
		var broken = new_state.broken_systems.duplicate()
		broken.erase(system_id)
		new_state.broken_systems = broken
		new_state = _add_log_entry(new_state, "System repaired: %s" % _get_system_name(system_id))

	return new_state

# ============================================================================
# LIFE SUPPORT REDUCERS
# ============================================================================

static func _reduce_set_hydroponics_power(state: Dictionary, level: int) -> Dictionary:
	## Set hydroponics power level (0=OFF, 1=LOW, 2=NORMAL, 3=HIGH)
	var new_state = state.duplicate(true)
	var life_support = new_state.get("life_support", Phase2Types.create_life_support_state())
	life_support = life_support.duplicate(true)

	life_support.hydroponics_power_level = clamp(level, 0, 3)

	var level_name = Phase2Types.HYDROPONICS_POWER_LEVELS.get(level, {}).get("name", "UNKNOWN")
	new_state = _add_log_entry(new_state, "Hydroponics power set to %s" % level_name)
	new_state.life_support = life_support
	return new_state

static func _reduce_damage_life_support(state: Dictionary, system_name: String, amount: float) -> Dictionary:
	## Damage a life support system (hydroponics, water_reclaimer, solar_panels, co2_scrubber)
	var new_state = state.duplicate(true)
	var life_support = new_state.get("life_support", Phase2Types.create_life_support_state())
	life_support = life_support.duplicate(true)

	match system_name:
		"hydroponics":
			life_support.hydroponics_health = max(0, life_support.get("hydroponics_health", 100.0) - amount)
			if life_support.hydroponics_health <= 20:
				new_state = _add_log_entry(new_state, "WARNING: Hydroponics bay critically damaged!")
			else:
				new_state = _add_log_entry(new_state, "Hydroponics bay damaged (%.0f%% health)" % life_support.hydroponics_health)
		"water_reclaimer":
			life_support.water_reclaimer_health = max(0, life_support.get("water_reclaimer_health", 100.0) - amount)
			if life_support.water_reclaimer_health <= 50:
				new_state = _add_log_entry(new_state, "WARNING: Water reclaimer efficiency critical!")
			else:
				new_state = _add_log_entry(new_state, "Water reclaimer damaged (%.0f%% health)" % life_support.water_reclaimer_health)
		"solar_panels":
			life_support.solar_panels_health = max(0, life_support.get("solar_panels_health", 100.0) - amount)
			if life_support.solar_panels_health <= 30:
				new_state = _add_log_entry(new_state, "CRITICAL: Solar panels severely damaged! Power generation compromised!")
			else:
				new_state = _add_log_entry(new_state, "Solar panels damaged (%.0f%% health)" % life_support.solar_panels_health)
		"co2_scrubber":
			life_support.co2_scrubber_health = max(0, life_support.get("co2_scrubber_health", 100.0) - amount)
			if life_support.co2_scrubber_health <= 40:
				new_state = _add_log_entry(new_state, "WARNING: CO2 scrubber critically damaged! Oxygen regeneration failing!")
			else:
				new_state = _add_log_entry(new_state, "CO2 scrubber damaged (%.0f%% health)" % life_support.co2_scrubber_health)

	new_state.life_support = life_support
	return new_state

static func _reduce_repair_life_support(state: Dictionary, system_name: String, amount: float) -> Dictionary:
	## Repair a life support system (hydroponics, water_reclaimer, solar_panels, co2_scrubber)
	var new_state = state.duplicate(true)
	var life_support = new_state.get("life_support", Phase2Types.create_life_support_state())
	life_support = life_support.duplicate(true)

	match system_name:
		"hydroponics":
			var was_critical = life_support.get("hydroponics_health", 100.0) <= 20
			life_support.hydroponics_health = min(100, life_support.get("hydroponics_health", 100.0) + amount)
			if was_critical and life_support.hydroponics_health > 20:
				new_state = _add_log_entry(new_state, "Hydroponics bay restored to operational status")
			else:
				new_state = _add_log_entry(new_state, "Hydroponics bay repaired (%.0f%% health)" % life_support.hydroponics_health)
		"water_reclaimer":
			var was_critical = life_support.get("water_reclaimer_health", 100.0) <= 50
			life_support.water_reclaimer_health = min(100, life_support.get("water_reclaimer_health", 100.0) + amount)
			if was_critical and life_support.water_reclaimer_health > 50:
				new_state = _add_log_entry(new_state, "Water reclaimer restored to full efficiency")
			else:
				new_state = _add_log_entry(new_state, "Water reclaimer repaired (%.0f%% health)" % life_support.water_reclaimer_health)
		"solar_panels":
			var was_critical = life_support.get("solar_panels_health", 100.0) <= 30
			life_support.solar_panels_health = min(100, life_support.get("solar_panels_health", 100.0) + amount)
			if was_critical and life_support.solar_panels_health > 30:
				new_state = _add_log_entry(new_state, "Solar panels restored! Power generation back to normal!")
			else:
				new_state = _add_log_entry(new_state, "Solar panels repaired (%.0f%% health)" % life_support.solar_panels_health)
		"co2_scrubber":
			var was_critical = life_support.get("co2_scrubber_health", 100.0) <= 40
			life_support.co2_scrubber_health = min(100, life_support.get("co2_scrubber_health", 100.0) + amount)
			if was_critical and life_support.co2_scrubber_health > 40:
				new_state = _add_log_entry(new_state, "CO2 scrubber restored! Oxygen regeneration back online!")
			else:
				new_state = _add_log_entry(new_state, "CO2 scrubber repaired (%.0f%% health)" % life_support.co2_scrubber_health)

	new_state.life_support = life_support
	return new_state

static func _get_system_name(system_id: int) -> String:
	## Get human-readable system name from ID
	## These match ControlSurface.SurfaceId enum
	match system_id:
		0: return "Power Core"
		1: return "Shields"
		2: return "Engine"
		3: return "Life Support"
		4: return "Medical Bay"
		5: return "Sensors"
		6: return "Emergency Power"
		_: return "Unknown System"

# ============================================================================
# TASK PENALTY REDUCERS
# ============================================================================

static func _reduce_apply_task_penalty(state: Dictionary, penalty: Dictionary) -> Dictionary:
	## Apply a penalty from a failed/cancelled task
	## penalty: {type, amount, task_name, task_type, target (optional)}
	var new_state = state.duplicate(true)
	var penalty_type = penalty.get("type", "none")
	var amount = penalty.get("amount", 0.0)
	var target = penalty.get("target", "random")
	var task_name = penalty.get("task_name", "Unknown task")

	match penalty_type:
		"system_damage":
			# Damage a life support system (random or specified)
			new_state = _apply_system_damage_penalty(new_state, amount, target, task_name)

		"health_damage":
			# Damage crew health
			new_state = _apply_health_damage_penalty(new_state, amount, target, task_name)

		"morale_damage":
			# Reduce crew morale
			new_state = _apply_morale_damage_penalty(new_state, amount, target, task_name)

		"resource_drain":
			# Consume resources (power by default, or specified resource)
			var resource = penalty.get("resource", "power")
			new_state = _apply_resource_drain_penalty(new_state, resource, amount, task_name)

		"efficiency_loss":
			# Reduce system efficiency (damage multiple systems slightly)
			new_state = _apply_efficiency_loss_penalty(new_state, amount, task_name)

		"none":
			pass  # No penalty

	return new_state

static func _apply_system_damage_penalty(state: Dictionary, amount: float, target: String, task_name: String) -> Dictionary:
	## Damage a life support system as penalty
	var new_state = state.duplicate(true)
	var life_support = new_state.get("life_support", Phase2Types.create_life_support_state())
	life_support = life_support.duplicate(true)

	# Determine which system to damage
	var systems = ["hydroponics", "water_reclaimer", "solar_panels", "co2_scrubber"]
	var target_system = target

	if target == "random" or target not in systems:
		# Pick a random system
		var idx = randi() % systems.size()
		target_system = systems[idx]

	# Apply damage
	match target_system:
		"hydroponics":
			life_support.hydroponics_health = max(0, life_support.get("hydroponics_health", 100.0) - amount)
		"water_reclaimer":
			life_support.water_reclaimer_health = max(0, life_support.get("water_reclaimer_health", 100.0) - amount)
		"solar_panels":
			life_support.solar_panels_health = max(0, life_support.get("solar_panels_health", 100.0) - amount)
		"co2_scrubber":
			life_support.co2_scrubber_health = max(0, life_support.get("co2_scrubber_health", 100.0) - amount)

	new_state.life_support = life_support
	new_state = _add_log_entry(new_state, "TASK FAILED: %s - %s damaged (%.0f damage)" % [task_name, target_system.capitalize().replace("_", " "), amount])
	return new_state

static func _apply_health_damage_penalty(state: Dictionary, amount: float, target: String, task_name: String) -> Dictionary:
	## Damage crew health as penalty
	var new_state = state.duplicate(true)
	var crew = new_state.crew.duplicate()

	if crew.is_empty():
		return new_state

	var affected_names: Array = []

	if target == "all":
		for i in range(crew.size()):
			var member = crew[i].duplicate()
			member.health = max(0, member.health - amount)
			crew[i] = member
			affected_names.append(member.name)
	elif target == "random":
		var idx = randi() % crew.size()
		var member = crew[idx].duplicate()
		member.health = max(0, member.health - amount)
		crew[idx] = member
		affected_names.append(member.name)
	else:
		# Target by role name
		var role_map = {
			"commander": Phase2Types.CrewRole.COMMANDER,
			"engineer": Phase2Types.CrewRole.ENGINEER,
			"scientist": Phase2Types.CrewRole.SCIENTIST,
			"medical": Phase2Types.CrewRole.MEDICAL
		}
		var target_role = role_map.get(target.to_lower(), -1)
		for i in range(crew.size()):
			if crew[i].role == target_role:
				var member = crew[i].duplicate()
				member.health = max(0, member.health - amount)
				crew[i] = member
				affected_names.append(member.name)
				break

	new_state.crew = crew
	var names_str = ", ".join(affected_names) if affected_names.size() > 0 else "crew"
	new_state = _add_log_entry(new_state, "TASK FAILED: %s - %s injured (%.0f damage)" % [task_name, names_str, amount])
	return new_state

static func _apply_morale_damage_penalty(state: Dictionary, amount: float, target: String, task_name: String) -> Dictionary:
	## Reduce crew morale as penalty
	var new_state = state.duplicate(true)
	var crew = new_state.crew.duplicate()

	if crew.is_empty():
		return new_state

	if target == "all" or target == "random":
		# Morale loss typically affects everyone
		for i in range(crew.size()):
			var member = crew[i].duplicate()
			member.morale = max(0, member.morale - amount)
			crew[i] = member
	else:
		# Target by role
		var role_map = {
			"commander": Phase2Types.CrewRole.COMMANDER,
			"engineer": Phase2Types.CrewRole.ENGINEER,
			"scientist": Phase2Types.CrewRole.SCIENTIST,
			"medical": Phase2Types.CrewRole.MEDICAL
		}
		var target_role = role_map.get(target.to_lower(), -1)
		for i in range(crew.size()):
			if crew[i].role == target_role:
				var member = crew[i].duplicate()
				member.morale = max(0, member.morale - amount)
				crew[i] = member
				break

	new_state.crew = crew
	new_state = _add_log_entry(new_state, "TASK FAILED: %s - Crew morale decreased" % task_name)
	return new_state

static func _apply_resource_drain_penalty(state: Dictionary, resource: String, amount: float, task_name: String) -> Dictionary:
	## Drain resources as penalty
	var new_state = state.duplicate(true)

	if resource == "food" or resource == "water":
		# Container-based resources
		new_state = _consume_from_containers(new_state, resource, amount)
		new_state.resources = Phase2Types.compute_resource_totals(new_state)
	else:
		# Direct resources (power, oxygen, fuel)
		var resources = new_state.resources.duplicate(true)
		if resources.has(resource):
			var res = resources[resource].duplicate()
			res.current = max(0, res.current - amount)
			resources[resource] = res
			new_state.resources = resources

	new_state = _add_log_entry(new_state, "TASK FAILED: %s - Lost %.1f %s" % [task_name, amount, resource])
	return new_state

static func _apply_efficiency_loss_penalty(state: Dictionary, amount: float, task_name: String) -> Dictionary:
	## Reduce overall system efficiency (slight damage to multiple systems)
	var new_state = state.duplicate(true)
	var life_support = new_state.get("life_support", Phase2Types.create_life_support_state())
	life_support = life_support.duplicate(true)

	# Small damage spread across systems
	var per_system = amount / 4.0  # Divide among 4 systems
	life_support.hydroponics_health = max(0, life_support.get("hydroponics_health", 100.0) - per_system)
	life_support.water_reclaimer_health = max(0, life_support.get("water_reclaimer_health", 100.0) - per_system)
	life_support.solar_panels_health = max(0, life_support.get("solar_panels_health", 100.0) - per_system)
	life_support.co2_scrubber_health = max(0, life_support.get("co2_scrubber_health", 100.0) - per_system)

	new_state.life_support = life_support
	new_state = _add_log_entry(new_state, "TASK FAILED: %s - Ship systems degraded" % task_name)
	return new_state
