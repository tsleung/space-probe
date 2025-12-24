extends Node
class_name Phase2Controller

## Phase 2: Travel to Mars - Controller Layer
## Handles input, timing, and game flow
## Dispatches actions to Phase2Store based on user input and auto-advance

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")
const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal auto_play_changed(enabled: bool)
signal crisis_mode_triggered(trigger: String)

# ============================================================================
# STORE REFERENCE
# ============================================================================

var store: Node = null

# ============================================================================
# SHIP SYSTEMS INTEGRATION
# ============================================================================

var ship_systems: Node = null
var crisis_controller: Node = null
var effects: Node = null

# ============================================================================
# TASK SYSTEM INTEGRATION
# ============================================================================

var task_manager: Node = null  # Reference to TaskManager for crew availability checks

# ============================================================================
# TIMING
# ============================================================================

var hour_timer: float = 0.0

# ============================================================================
# AUTO-PLAY (AI mode)
# ============================================================================

@export var auto_play: bool = true  # When true, AI auto-resolves events
@export var auto_play_delay: float = 0.8  # Seconds to wait before auto-resolve (fast for intensity)
var event_timer: float = 0.0
var waiting_for_auto_resolve: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func connect_to_store(p_store: Node) -> void:
	## Connect to a Phase2Store instance
	store = p_store

	# Connect to signals we need to react to
	store.arrival.connect(_on_arrival)
	store.game_over.connect(_on_game_over)
	store.event_triggered.connect(_on_event_triggered)
	store.event_resolved.connect(_on_event_resolved)

func setup_ship_systems(p_ship_systems: Node, p_crisis_controller: Node, p_effects: Node, ship_view: Node) -> void:
	## Wire up ShipSystemsIntegration with other systems
	ship_systems = p_ship_systems
	crisis_controller = p_crisis_controller
	effects = p_effects

	if not ship_systems:
		push_warning("[CONTROLLER] ShipSystemsIntegration not found")
		return

	# Setup the ship systems with store and effects
	ship_systems.setup(store, effects, ship_view)

	# Connect warning signals from ShipSystemsIntegration
	ship_systems.power_critical.connect(_on_power_critical)
	ship_systems.hull_breach_imminent.connect(_on_hull_breach_imminent)
	ship_systems.reactor_meltdown_warning.connect(_on_reactor_meltdown)

	# Connect hull events to crisis triggers
	if ship_systems.hull_events:
		ship_systems.hull_events.asteroid_impact.connect(_on_asteroid_impact)

	# Connect reactor explosion to crisis
	if ship_systems.surface_manager:
		ship_systems.surface_manager.reactor_exploded.connect(_on_reactor_explosion)

	print("[CONTROLLER] Ship systems integration complete")

func setup_task_manager(p_task_manager: Node) -> void:
	## Wire up TaskManager for crew availability checks in AI decisions
	task_manager = p_task_manager
	print("[CONTROLLER] Task manager connected for crew-aware AI")

# ============================================================================
# PROCESS LOOP
# ============================================================================

func _process(delta: float) -> void:
	if not store:
		return

	# Don't process if game is over or arrived
	if store.has_arrived() or store.is_game_over():
		return

	# Handle auto-play event resolution
	if auto_play and waiting_for_auto_resolve and store.has_active_event():
		event_timer += delta
		if event_timer >= auto_play_delay:
			_auto_resolve_event()
		return  # Don't advance time while resolving event

	# Don't auto-advance if event is active (and not auto-playing)
	if store.has_active_event():
		return

	# Don't advance if paused or auto-advance disabled
	if not store.is_auto_advancing():
		return

	var speed = store.get_speed()
	if speed == Phase2Types.Speed.PAUSED:
		return

	# Get seconds per hour based on speed (hourly tick system)
	var seconds_per_hour = Phase2Types.SECONDS_PER_HOUR.get(speed, 0.2)

	# Accumulate time
	hour_timer += delta

	if hour_timer >= seconds_per_hour:
		hour_timer = 0.0
		store.advance_hour()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not store:
		return

	# Speed controls
	if event.is_action_pressed("ui_cancel"):
		store.toggle_pause()

	# Number keys for speed (if defined)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				store.set_speed(Phase2Types.Speed.SLOW)
			KEY_2:
				store.set_speed(Phase2Types.Speed.NORMAL)
			KEY_3:
				store.set_speed(Phase2Types.Speed.FAST)
			KEY_4:
				store.set_speed(Phase2Types.Speed.ULTRA)
			KEY_5:
				store.set_speed(Phase2Types.Speed.LUDICROUS)
				print("[CONTROLLER] LUDICROUS SPEED!")
			KEY_SPACE:
				store.toggle_pause()
			KEY_A:
				toggle_auto_play()
				print("[CONTROLLER] Auto-play: %s" % ("ON" if auto_play else "OFF"))

# ============================================================================
# PUBLIC METHODS (for UI buttons)
# ============================================================================

func set_speed_slow() -> void:
	if store:
		store.set_speed(Phase2Types.Speed.SLOW)

func set_speed_normal() -> void:
	if store:
		store.set_speed(Phase2Types.Speed.NORMAL)

func set_speed_fast() -> void:
	if store:
		store.set_speed(Phase2Types.Speed.FAST)

func set_speed_ludicrous() -> void:
	if store:
		store.set_speed(Phase2Types.Speed.LUDICROUS)
		print("[CONTROLLER] LUDICROUS SPEED!")

func toggle_pause() -> void:
	if store:
		store.toggle_pause()

func resolve_event_choice(choice_index: int) -> void:
	if store and store.has_active_event():
		store.resolve_event(choice_index)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_arrival() -> void:
	print("[CONTROLLER] Arrived at Mars - transitioning to Phase 3")
	# Could emit a signal or call scene transition here

func _on_game_over(reason: String) -> void:
	print("[CONTROLLER] Game over: %s" % reason)
	# Could emit a signal or show game over screen

func _on_event_triggered(event: Dictionary) -> void:
	## Start auto-resolve timer when event is triggered
	if auto_play:
		waiting_for_auto_resolve = true
		event_timer = 0.0
		print("[AI] Event triggered: %s - will auto-resolve in %.1fs" % [event.get("title", "Unknown"), auto_play_delay])

func _on_event_resolved(_choice_index: int) -> void:
	## Reset auto-resolve state
	waiting_for_auto_resolve = false
	event_timer = 0.0

# ============================================================================
# SHIP SYSTEMS SIGNAL HANDLERS
# ============================================================================

func _on_power_critical() -> void:
	## Handle low power warning
	print("[CONTROLLER] POWER CRITICAL - triggering power crisis")
	crisis_mode_triggered.emit("power_critical")
	# Could trigger CRISIS mode with power-related crises
	# For now, just add a log entry
	if store:
		store.dispatch(Phase2Reducer.action_add_log("WARNING: Power reserves critically low!"))

func _on_hull_breach_imminent() -> void:
	## Handle hull breach warning
	print("[CONTROLLER] HULL BREACH IMMINENT")
	crisis_mode_triggered.emit("hull_breach")
	if store:
		store.dispatch(Phase2Reducer.action_add_log("ALERT: Hull integrity compromised!"))

func _on_reactor_meltdown() -> void:
	## Handle reactor meltdown warning
	print("[CONTROLLER] REACTOR MELTDOWN WARNING")
	crisis_mode_triggered.emit("reactor_meltdown")
	if store:
		store.dispatch(Phase2Reducer.action_add_log("CRITICAL: Reactor temperature critical!"))

func _on_reactor_explosion() -> void:
	## Handle reactor explosion - trigger fire crisis
	print("[CONTROLLER] REACTOR EXPLOSION - triggering fire crisis")
	if store:
		store.dispatch(Phase2Reducer.action_add_log("EXPLOSION: Reactor core breach! Fire in Engineering!"))
		store.dispatch(Phase2Reducer.action_break_system(0, "explosion"))  # Power Core

	# Trigger fire crisis in engineering if crisis controller exists
	if crisis_controller and crisis_controller.has_method("spawn_crisis"):
		crisis_controller.spawn_crisis("fire", 2)  # 2 = Engineering room

func _on_asteroid_impact(room: int, damage: float) -> void:
	## Handle asteroid impact - possibly trigger hull stress crisis
	print("[CONTROLLER] Asteroid impact in room %d, damage %.0f%%" % [room, damage * 100])

	if damage > 0.3 and crisis_controller and crisis_controller.has_method("spawn_crisis"):
		crisis_controller.spawn_crisis("hull_stress", room)

# ============================================================================
# AUTO-PLAY AI
# ============================================================================

func _auto_resolve_event() -> void:
	## AI picks an option for the current event
	if not store or not store.has_active_event():
		waiting_for_auto_resolve = false
		return

	var event = store.get_active_event()
	var options = event.get("options", [])
	if options.is_empty():
		waiting_for_auto_resolve = false
		return

	# AI decision logic - pick based on risk/reward
	var choice = _ai_pick_choice(event, options)

	print("[AI] Choosing option %d: %s" % [choice, options[choice].get("label", "???")])
	store.resolve_event(choice)

	waiting_for_auto_resolve = false
	event_timer = 0.0

func _ai_pick_choice(event: Dictionary, options: Array) -> int:
	## AI decision-making for event choices
	## IMPROVED: Now calculates expected values and considers resource situation

	var best_choice = 0
	var best_score = -1000.0

	# Get current resource situation for context-aware decisions
	var resource_context = _get_resource_context()

	for i in range(options.size()):
		var option = options[i]
		var score = _calculate_option_expected_value(option, event, resource_context)

		if score > best_score:
			best_score = score
			best_choice = i

	return best_choice

func _get_resource_context() -> Dictionary:
	## Get current resource levels AND time context to inform decisions
	if not store:
		return {"power_critical": false, "food_critical": false, "water_critical": false, "health_critical": false, "hours_remaining": 4392, "journey_progress": 0.0, "urgency": 1.0}

	var resources = store.get_resources()
	var crew = store.get_crew()

	# Calculate average crew health/morale
	var avg_health = 100.0
	var avg_morale = 100.0
	if crew.size() > 0:
		var total_health = 0.0
		var total_morale = 0.0
		for member in crew:
			total_health += member.get("health", 100.0)
			total_morale += member.get("morale", 100.0)
		avg_health = total_health / crew.size()
		avg_morale = total_morale / crew.size()

	# Get resource levels (handle different possible formats)
	var power = resources.get("power", {})
	var power_current = power.get("current", 50.0) if power is Dictionary else power
	var power_max = power.get("max", 100.0) if power is Dictionary else 100.0

	var food = resources.get("food", {})
	var food_current = food.get("current", 50.0) if food is Dictionary else food
	var food_max = food.get("max", 100.0) if food is Dictionary else 100.0

	var water = resources.get("water", {})
	var water_current = water.get("current", 50.0) if water is Dictionary else water
	var water_max = water.get("max", 100.0) if water is Dictionary else 100.0

	var oxygen = resources.get("oxygen", {})
	var oxygen_current = oxygen.get("current", 100.0) if oxygen is Dictionary else oxygen

	# TIME AWARENESS - key for Phase 2 AI improvements
	var hours_remaining = store.get_hours_remaining() if store.has_method("get_hours_remaining") else 4392
	var days_remaining = store.get_days_remaining() if store.has_method("get_days_remaining") else 183
	var journey_progress = store.get_journey_progress() if store.has_method("get_journey_progress") else 0.0

	# Calculate urgency multiplier based on journey progress
	# Early journey (< 20%): Conservative play (urgency 0.8)
	# Mid journey (20-80%): Normal play (urgency 1.0)
	# Late journey (> 80%): Desperate play (urgency 1.5-2.0)
	var urgency = 1.0
	if journey_progress < 0.2:
		urgency = 0.8  # Early game - play safe
	elif journey_progress > 0.8:
		urgency = 1.5 + (journey_progress - 0.8) * 2.5  # Late game - take more risks
	elif journey_progress > 0.9:
		urgency = 2.0  # Final stretch - maximum desperation

	# CREW AVAILABILITY - check who's busy with tasks
	var crew_busy = {}
	var crew_fatigue = {}
	var active_task_count = 0
	if task_manager and task_manager.has_method("get_active_tasks"):
		active_task_count = task_manager.get_task_count()
		# Track which crew roles are busy
		if task_manager.has_method("is_crew_busy"):
			crew_busy["engineer"] = task_manager.is_crew_busy("engineer")
			crew_busy["medical"] = task_manager.is_crew_busy("medical")
			crew_busy["scientist"] = task_manager.is_crew_busy("scientist")
			crew_busy["commander"] = task_manager.is_crew_busy("commander")

	# Build crew fatigue map from crew array
	for member in crew:
		var role_name = _get_role_name(member.get("role", -1))
		if role_name:
			crew_fatigue[role_name] = member.get("fatigue", 0)

	return {
		"power_critical": power_current < power_max * 0.2,
		"power_low": power_current < power_max * 0.4,
		"food_critical": food_current < food_max * 0.2,
		"food_low": food_current < food_max * 0.4,
		"water_critical": water_current < water_max * 0.3,
		"water_low": water_current < water_max * 0.5,
		"oxygen_critical": oxygen_current < 30,
		"health_critical": avg_health < 50,
		"health_low": avg_health < 70,
		"morale_critical": avg_morale < 40,
		"morale_low": avg_morale < 60,
		"power_percent": power_current / max(power_max, 1.0),
		"food_percent": food_current / max(food_max, 1.0),
		"water_percent": water_current / max(water_max, 1.0),
		# TIME CONTEXT
		"hours_remaining": hours_remaining,
		"days_remaining": days_remaining,
		"journey_progress": journey_progress,
		"urgency": urgency,
		"is_early_game": journey_progress < 0.2,
		"is_late_game": journey_progress > 0.8,
		"is_final_stretch": journey_progress > 0.9,
		# CREW AVAILABILITY
		"crew_busy": crew_busy,
		"crew_fatigue": crew_fatigue,
		"active_task_count": active_task_count,
		"task_overload": active_task_count >= 3,  # Too many tasks already
	}

func _get_role_name(role: int) -> String:
	## Convert role enum to string name
	match role:
		0: return "commander"
		1: return "engineer"
		2: return "scientist"
		3: return "medical"
		_: return ""

func _calculate_option_expected_value(option: Dictionary, event: Dictionary, context: Dictionary) -> float:
	## Calculate the expected value of an option considering weighted outcomes
	## NOW WITH TIME AWARENESS - adjusts risk tolerance based on journey progress

	var score = 0.0
	var outcomes = option.get("outcomes", [])

	# If option has weighted outcomes, calculate expected value
	if not outcomes.is_empty():
		for outcome in outcomes:
			var weight = outcome.get("weight", 0.5)
			var outcome_value = _score_outcome_effects(outcome.get("effects", []), context)
			score += weight * outcome_value
	else:
		# Fallback to simple effect analysis for options without outcomes
		score = _score_simple_option(option, event, context)

	# =========================================================================
	# TIME-AWARE RISK ADJUSTMENTS
	# =========================================================================

	var label = option.get("label", "").to_lower()
	var risk = option.get("risk", "medium")

	# Early game (< 20% journey): Prefer safe options
	if context.get("is_early_game", false):
		if risk == "low":
			score += 10.0  # Bonus for safe options early
		elif risk == "high":
			score -= 15.0  # Penalty for risky options early

	# Late game (> 80% journey): Accept more risks
	if context.get("is_late_game", false):
		if risk == "high":
			score += 20.0  # Desperation bonus for risky options
		if label.contains("repair") or label.contains("fix"):
			# Check if there's time for repairs
			var repair_hours = _estimate_repair_hours(option, event)
			var hours_remaining = context.get("hours_remaining", 4392)
			if repair_hours > hours_remaining * 0.3:
				score -= 40.0  # Too late for long repairs
				print("[AI TIME] Repair option penalized - %d hours vs %.0f remaining" % [repair_hours, hours_remaining])

	# Final stretch (> 90% journey): Maximum desperation
	if context.get("is_final_stretch", false):
		# Any option that keeps us alive is valuable
		if label.contains("emergency") or label.contains("desperate"):
			score += 30.0
		# Penalize slow options heavily
		if label.contains("wait") or label.contains("delay"):
			score -= 25.0

	# Apply urgency multiplier to resource-critical decisions
	var urgency = context.get("urgency", 1.0)

	# =========================================================================
	# CREW AVAILABILITY ADJUSTMENTS
	# =========================================================================

	var crew_busy = context.get("crew_busy", {})
	var crew_fatigue = context.get("crew_fatigue", {})

	# Check if this option requires a specific crew member
	var requires_crew = option.get("requires_crew", "")
	if requires_crew != "":
		# Check if required crew is busy
		if crew_busy.get(requires_crew, false):
			score -= 30.0  # Heavy penalty - crew already assigned to task
			print("[AI CREW] %s is busy, option penalized by 30" % requires_crew)

		# Check if required crew is fatigued
		var fatigue = crew_fatigue.get(requires_crew, 0)
		if fatigue > 70:
			score -= 15.0  # Penalty for using exhausted crew
			print("[AI CREW] %s is fatigued (%.0f), option penalized by 15" % [requires_crew, fatigue])
		elif fatigue > 90:
			score -= 30.0  # Severe penalty for exhausted crew
			print("[AI CREW] %s is exhausted (%.0f), option penalized by 30" % [requires_crew, fatigue])

	# Penalize options that would create too many active tasks
	if context.get("task_overload", false):
		# If we already have 3+ tasks, avoid creating more
		if label.contains("repair") or label.contains("eva") or label.contains("treat"):
			score -= 20.0
			print("[AI CREW] Task overload, task-creating option penalized")

	# =========================================================================
	# STANDARD OPTION SCORING (with urgency adjustments)
	# =========================================================================

	# Blue options (specialist required) are usually better
	if option.get("is_blue_option", false):
		score += 25.0
		# But only if we have the required crew and they're healthy AND available
		if requires_crew:
			if context.health_critical:
				score -= 15.0  # Don't push exhausted specialists
			if crew_busy.get(requires_crew, false):
				score -= 20.0  # Blue option loses value if crew is busy

	# EVA events - repair is critical but consider risks
	if event.get("is_eva_event", false):
		if label.contains("eva"):
			# EVA repairs are valuable, especially when power is low (solar panels!)
			score += 30.0 * urgency  # Scale with urgency
			if context.power_critical:
				score += 40.0  # MUST fix solar panels!
		elif not label.contains("eva"):
			# Non-EVA options for EVA events are usually worse
			score -= 30.0

	# Repair options are valuable when systems are damaged
	if label.contains("repair") or label.contains("fix"):
		score += 15.0
		if context.power_critical:
			score += 30.0 * urgency  # Repair urgency scales with journey progress

	# Shelter/safety options when health is low
	if label.contains("shelter") or label.contains("hide"):
		if context.health_critical:
			score += 40.0
		elif context.health_low:
			score += 20.0

	# Conservative options - good early, bad late
	if label.contains("conserv") or label.contains("wait"):
		if context.get("is_early_game", false):
			score += 15.0  # Good to conserve early
		elif context.get("is_late_game", false):
			score -= 20.0  # No time to wait late game
		elif context.power_critical or context.food_critical:
			score += 15.0

	# =========================================================================
	# PHASE 5: RESOURCE PROJECTION - will we survive this decision?
	# =========================================================================
	var projection_penalty = _get_resource_projection_penalty(option, context)
	score += projection_penalty

	# Add tiny random factor for tie-breaking
	score += randf() * 2.0

	return score

func _estimate_repair_hours(option: Dictionary, event: Dictionary) -> int:
	## Estimate how long a repair option will take
	## Used to determine if there's time for repairs late in the journey

	var label = option.get("label", "").to_lower()

	# Extract hours from label if present (e.g., "Repair (4 hours)")
	var regex = RegEx.new()
	regex.compile("(\\d+)\\s*(?:hour|hr)")
	var result = regex.search(label)
	if result:
		return int(result.get_string(1))

	# Default estimates based on task type
	if label.contains("eva"):
		return 6  # EVA tasks take longer
	elif label.contains("quick") or label.contains("fast"):
		return 2
	elif label.contains("careful") or label.contains("thorough"):
		return 4
	else:
		return 3  # Default repair time

# ============================================================================
# PHASE 5: RESOURCE BURN RATE PROJECTION
# ============================================================================

func _project_resource_state(hours_ahead: int) -> Dictionary:
	## Project resource levels after hours_ahead hours
	## Used to answer: "Will we survive if we pick this option?"
	## Returns projected levels for food, water, power, oxygen

	if not store:
		return {"food": 100, "water": 100, "power": 100, "oxygen": 100, "survival": true}

	var resources = store.get_resources()
	var crew = store.get_crew()
	var life_support = store.get_life_support() if store.has_method("get_life_support") else {}
	var crew_count = crew.size()

	# Current levels
	var food_current = resources.get("food", {}).get("current", 100.0)
	var water_current = resources.get("water", {}).get("current", 100.0)
	var power_current = resources.get("power", {}).get("current", 100.0)
	var oxygen_current = resources.get("oxygen", {}).get("current", 100.0)

	# Get life support health for efficiency calculations
	var hydro_health = life_support.get("hydroponics_health", 100.0) / 100.0
	var water_health = life_support.get("water_reclaimer_health", 100.0) / 100.0
	var solar_health = life_support.get("solar_panels_health", 100.0) / 100.0
	var scrubber_health = life_support.get("co2_scrubber_health", 100.0) / 100.0

	# Hourly consumption/production rates (from balance)
	# Food: 0.167 per crew per hour consumed, 0.21 produced (hydroponics)
	var food_per_hour = (0.21 * hydro_health) - (0.167 * crew_count)

	# Water: 0.5 per crew per hour consumed, 92% recycled
	var water_consumed = 0.5 * crew_count
	var water_recycled = water_consumed * 0.92 * water_health
	var water_per_hour = water_recycled - water_consumed

	# Power: 15 generated (solar), 12 consumed (life support)
	var power_per_hour = (15.0 * solar_health) - 12.0

	# Oxygen: 0.8 generated (scrubber), tiny leak
	var oxygen_per_hour = (0.8 * scrubber_health) - 0.004

	# Project forward
	var projected = {
		"food": food_current + (food_per_hour * hours_ahead),
		"water": water_current + (water_per_hour * hours_ahead),
		"power": power_current + (power_per_hour * hours_ahead),
		"oxygen": oxygen_current + (oxygen_per_hour * hours_ahead),
	}

	# Clamp to valid ranges
	projected.food = max(0, projected.food)
	projected.water = max(0, projected.water)
	projected.power = max(0, projected.power)
	projected.oxygen = max(0, projected.oxygen)

	# Determine if we'll survive
	projected["survival"] = projected.food > 0 and projected.water > 0 and projected.power > 0 and projected.oxygen > 10

	# Add danger flags
	projected["food_danger"] = projected.food < 10
	projected["water_danger"] = projected.water < 10
	projected["power_danger"] = projected.power < 5
	projected["oxygen_danger"] = projected.oxygen < 20

	return projected

func _get_resource_projection_penalty(option: Dictionary, context: Dictionary) -> float:
	## Calculate penalty based on resource projections
	## Returns negative score if taking this option would deplete resources

	var penalty = 0.0

	# Estimate how long this option's task would take
	var task_hours = 3  # Default
	var task_config = option.get("task_config")
	if task_config != null and task_config is Dictionary and not task_config.is_empty():
		task_hours = task_config.get("hours", 3)
	else:
		# Estimate from label
		task_hours = _estimate_repair_hours(option, {})

	# Project resources after task completes
	var projected = _project_resource_state(task_hours)

	if not projected.survival:
		penalty -= 200.0  # Catastrophic - this option kills us
		print("[AI PROJECTION] Option would lead to resource death in %d hours" % task_hours)
	else:
		# Individual resource dangers
		if projected.food_danger:
			penalty -= 50.0
			print("[AI PROJECTION] Food would be critical after %d hours" % task_hours)
		if projected.water_danger:
			penalty -= 50.0
		if projected.power_danger:
			penalty -= 100.0  # Power loss is catastrophic
			print("[AI PROJECTION] Power would fail after %d hours" % task_hours)
		if projected.oxygen_danger:
			penalty -= 80.0

	return penalty

func _score_outcome_effects(effects: Array, context: Dictionary) -> float:
	## Score the effects of an outcome based on current resource needs

	var value = 0.0

	for effect in effects:
		var effect_type = effect.get("type", "")
		var amount = effect.get("amount", 0.0)
		var target = effect.get("target", "all")

		match effect_type:
			"health":
				# Health gains/losses - more valuable when health is low
				var multiplier = 2.0 if context.health_critical else (1.5 if context.health_low else 1.0)
				value += amount * multiplier

			"morale":
				# Morale - important but less than health
				var multiplier = 1.5 if context.morale_critical else 1.0
				value += amount * 0.8 * multiplier

			"fatigue":
				# Fatigue is bad (higher = worse)
				value -= amount * 0.5

			"power":
				# Power - VERY important when critical
				var multiplier = 5.0 if context.power_critical else (2.0 if context.power_low else 1.0)
				value += amount * multiplier

			"food":
				# Food - important when low
				var multiplier = 3.0 if context.food_critical else (1.5 if context.food_low else 1.0)
				value += amount * multiplier

			"water":
				# Water - important when low
				var multiplier = 3.0 if context.water_critical else (1.5 if context.water_low else 1.0)
				value += amount * multiplier

			"oxygen":
				# Oxygen - critical resource
				var multiplier = 4.0 if context.oxygen_critical else 1.0
				value += amount * multiplier

			"fuel":
				# Fuel - preserve what we have
				value += amount * 0.5

			"log":
				# Log entries have no direct value
				pass

			"eva_drift":
				# EVA drift is risky
				value -= 30.0

			"crew_gather":
				# Crew gathering is neutral to positive
				value += 5.0

	return value

func _score_simple_option(option: Dictionary, event: Dictionary, context: Dictionary) -> float:
	## Fallback scoring for options without detailed outcomes

	var score = 0.0

	# Risk scoring
	var risk = option.get("risk", "medium")
	match risk:
		"low": score += 20.0
		"medium": score += 0.0
		"high": score -= 20.0 if not context.power_critical else -10.0  # Take more risks when desperate

	# Effect-based scoring
	var effect = option.get("effect", "")
	if effect is String:
		if effect.contains("morale_boost"): score += 15.0
		if effect.contains("repair") or effect.contains("fix"):
			score += 20.0
			if context.power_critical: score += 30.0
		if effect.contains("health_loss") or effect.contains("radiation"): score -= 25.0
		if effect.contains("power_drain"):
			score -= 10.0 if context.power_critical else -5.0
		if effect.contains("food_loss") or effect.contains("water_loss"): score -= 15.0
		if effect.contains("eva"):
			# EVA is risky but necessary for repairs
			score += 10.0 if context.power_critical else -5.0
		if effect.contains("thorough") or effect.contains("full"): score += 10.0

	# Event type specific preferences
	var event_type = event.get("type", -1)
	match event_type:
		Phase2Types.EventType.SECTION_BLOCKAGE:
			if option.get("label", "").to_lower().contains("repair"): score += 15.0
		Phase2Types.EventType.MIDPOINT_CRISIS:
			# All-hands repair is safest
			if option == event.options[0]: score += 20.0
		Phase2Types.EventType.POWER_SURGE:
			# Must fix power issues!
			if option.get("label", "").to_lower().contains("repair"): score += 40.0

	return score

func set_auto_play(enabled: bool) -> void:
	auto_play = enabled
	if not enabled:
		waiting_for_auto_resolve = false
		event_timer = 0.0
	auto_play_changed.emit(auto_play)

func toggle_auto_play() -> void:
	set_auto_play(not auto_play)

# ============================================================================
# DEBUG
# ============================================================================

func debug_skip_days(count: int) -> void:
	if store:
		store.debug_advance_days(count)

func debug_trigger_event() -> void:
	if store:
		store.debug_trigger_random_event()

func debug_block_container() -> void:
	if store:
		store.debug_block_container("cargo_a")
