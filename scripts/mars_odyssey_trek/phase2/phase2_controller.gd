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
	## Get current resource levels to inform decisions
	if not store:
		return {"power_critical": false, "food_critical": false, "water_critical": false, "health_critical": false}

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
	}

func _calculate_option_expected_value(option: Dictionary, event: Dictionary, context: Dictionary) -> float:
	## Calculate the expected value of an option considering weighted outcomes

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

	# Blue options (specialist required) are usually better
	if option.get("is_blue_option", false):
		score += 25.0
		# But only if we have the required crew and they're healthy
		var requires_crew = option.get("requires_crew", "")
		if requires_crew and context.health_critical:
			score -= 15.0  # Don't push exhausted specialists

	# EVA events - repair is critical but consider risks
	if event.get("is_eva_event", false):
		var label = option.get("label", "").to_lower()
		if label.contains("eva"):
			# EVA repairs are valuable, especially when power is low (solar panels!)
			score += 30.0
			if context.power_critical:
				score += 40.0  # MUST fix solar panels!
		elif not label.contains("eva"):
			# Non-EVA options for EVA events are usually worse
			score -= 30.0

	# Repair options are valuable when systems are damaged
	var label = option.get("label", "").to_lower()
	if label.contains("repair") or label.contains("fix"):
		score += 15.0
		if context.power_critical:
			score += 30.0  # Repair is critical when power is low

	# Shelter/safety options when health is low
	if label.contains("shelter") or label.contains("hide"):
		if context.health_critical:
			score += 40.0
		elif context.health_low:
			score += 20.0

	# Conservative options when resources are critically low
	if label.contains("conserv") or label.contains("wait"):
		if context.power_critical or context.food_critical:
			score += 15.0

	# Add tiny random factor for tie-breaking
	score += randf() * 2.0

	return score

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
