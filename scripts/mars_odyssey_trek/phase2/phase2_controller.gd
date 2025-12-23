extends Node
class_name Phase2Controller

## Phase 2: Travel to Mars - Controller Layer
## Handles input, timing, and game flow
## Dispatches actions to Phase2Store based on user input and auto-advance

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal auto_play_changed(enabled: bool)

# ============================================================================
# STORE REFERENCE
# ============================================================================

var store: Node = null

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
	## Prefers: low risk, crew safety, resource preservation

	var best_choice = 0
	var best_score = -1000.0

	for i in range(options.size()):
		var option = options[i]
		var score = 0.0

		# Risk scoring
		var risk = option.get("risk", "medium")
		match risk:
			"low": score += 20.0
			"medium": score += 0.0
			"high": score -= 30.0

		# Effect-based scoring
		var effect = option.get("effect", "")
		if effect is String:
			if effect.contains("morale_boost"): score += 15.0
			if effect.contains("repair") or effect.contains("fix"): score += 10.0
			if effect.contains("health_loss") or effect.contains("radiation"): score -= 20.0
			if effect.contains("power_drain"): score -= 5.0
			if effect.contains("food_loss") or effect.contains("water_loss"): score -= 10.0
			if effect.contains("eva"): score -= 15.0  # Risky but sometimes necessary
			if effect.contains("thorough") or effect.contains("full"): score += 5.0

		# Event type specific preferences
		var event_type = event.get("type", -1)
		match event_type:
			Phase2Types.EventType.SECTION_BLOCKAGE:
				# Prefer repair over EVA unless no other choice
				if i == 0: score += 10.0  # Repair is usually first option
			Phase2Types.EventType.NAVIGATION_DRIFT:
				# Prefer immediate correction if fuel isn't critical
				if i == 0: score += 5.0
			Phase2Types.EventType.MIDPOINT_CRISIS:
				# All-hands repair is safest
				if i == 0: score += 15.0

		# Add small random factor for variety
		score += randf() * 5.0

		if score > best_score:
			best_score = score
			best_choice = i

	return best_choice

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
