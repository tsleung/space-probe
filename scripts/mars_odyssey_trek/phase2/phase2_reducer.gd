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
	ADVANCE_DAY,
	SET_SPEED,
	SET_AUTO_ADVANCE,
	TRIGGER_EVENT,
	RESOLVE_EVENT,
	BLOCK_SECTION,
	START_REPAIR,
	EVA_RETRIEVAL,
	ADD_LOG
}

# ============================================================================
# ACTION CREATORS
# ============================================================================

static func action_advance_day(random_values: Array) -> Dictionary:
	## Advance time by 1 day - the primary time advancement action
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

# ============================================================================
# MAIN REDUCER
# ============================================================================

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.ADVANCE_DAY:
			return _reduce_advance_day(state, action.random_values)
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
			return _reduce_start_repair(state, action.container_id, action.repair_days)
		ActionType.EVA_RETRIEVAL:
			return _reduce_eva_retrieval(state, action.container_id, action.random_value)
		ActionType.ADD_LOG:
			return _reduce_add_log(state, action.message)
		_:
			return state

# ============================================================================
# DAY ADVANCEMENT
# ============================================================================

static func _reduce_advance_day(state: Dictionary, random_values: Array) -> Dictionary:
	## Advance time by 1 day - runs all daily updates
	var new_state = state.duplicate(true)
	var random_idx = 0

	# 1. Increment day
	new_state.current_day += 1

	# 2. Check repair progress
	new_state = _process_repair_progress(new_state)

	# 3. Consume resources
	new_state = _consume_daily_resources(new_state)

	# 4. Update crew stats
	new_state = _update_crew_daily(new_state)

	# 5. Check for random events
	var event_roll = random_values[random_idx] if random_idx < random_values.size() else 0.5
	random_idx += 1
	var event_chance = Phase2Types.get_event_chance_for_day(new_state.current_day, new_state.total_days)

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

	# 6. Check Mars visibility milestone
	if new_state.current_day >= Phase2Types.MARS_VISIBLE_DAY and not new_state.mars_visible:
		new_state.mars_visible = true
		new_state = _add_log_entry(new_state, "Mars is now visible as a distinct orange dot.")

	# 7. Recompute resource totals
	new_state.resources = Phase2Types.compute_resource_totals(new_state)

	return new_state

static func _process_repair_progress(state: Dictionary) -> Dictionary:
	## Check and advance repair progress
	var repair = state.repair
	if not repair.in_progress:
		return state

	var new_state = state.duplicate(true)
	new_state.repair = repair.duplicate()
	new_state.repair.days_remaining -= 1

	if new_state.repair.days_remaining <= 0:
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
	else:
		new_state = _add_log_entry(new_state, "Repair in progress... %d days remaining." % new_state.repair.days_remaining)

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
	if state.active_event.is_empty():
		return state

	var new_state = state.duplicate(true)
	var event = new_state.active_event
	var options = event.get("options", [])

	if choice_index < 0 or choice_index >= options.size():
		return state

	var choice = options[choice_index]
	var effect = choice.get("effect", Phase2Types.EventEffectType.MORALE_BOOST)

	# Apply effect based on type
	new_state = _apply_event_effect(new_state, effect, choice.get("effect_value", 0), random_value)

	# Clear event and resume
	new_state.active_event = {}
	new_state.auto_advance = true

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

		_:
			pass  # Unknown effect

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

static func _reduce_start_repair(state: Dictionary, container_id: String, repair_days: int) -> Dictionary:
	## Start repairing a blocked section
	var new_state = state.duplicate(true)

	# Find the container
	var container_name = ""
	for container in new_state.storage_containers:
		if container.id == container_id:
			container_name = container.name
			break

	if container_name.is_empty():
		return state

	# Set up repair state
	new_state.repair = {
		"in_progress": true,
		"days_remaining": repair_days,
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

	new_state = _add_log_entry(new_state, "Engineer dispatched to repair %s. Estimated %d days." % [container_name, repair_days])

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
	return state.current_day >= state.total_days

static func is_game_over(state: Dictionary) -> bool:
	return Phase2Types.is_game_over(state)

static func get_days_remaining(state: Dictionary) -> int:
	return max(0, state.total_days - state.current_day)

static func get_journey_progress(state: Dictionary) -> float:
	return float(state.current_day) / float(state.total_days)
