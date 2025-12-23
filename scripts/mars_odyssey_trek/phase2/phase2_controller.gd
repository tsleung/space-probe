extends Node
class_name Phase2Controller

## Phase 2: Travel to Mars - Controller Layer
## Handles input, timing, and game flow
## Dispatches actions to Phase2Store based on user input and auto-advance

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

# ============================================================================
# STORE REFERENCE
# ============================================================================

var store: Node = null

# ============================================================================
# TIMING
# ============================================================================

var day_timer: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func connect_to_store(p_store: Node) -> void:
	## Connect to a Phase2Store instance
	store = p_store

	# Connect to signals we need to react to
	store.arrival.connect(_on_arrival)
	store.game_over.connect(_on_game_over)

# ============================================================================
# PROCESS LOOP
# ============================================================================

func _process(delta: float) -> void:
	if not store:
		return

	# Don't process if game is over or arrived
	if store.has_arrived() or store.is_game_over():
		return

	# Don't auto-advance if event is active
	if store.has_active_event():
		return

	# Don't advance if paused or auto-advance disabled
	if not store.is_auto_advancing():
		return

	var speed = store.get_speed()
	if speed == Phase2Types.Speed.PAUSED:
		return

	# Get seconds per day based on speed
	var seconds_per_day = Phase2Types.SECONDS_PER_DAY.get(speed, 2.0)

	# Accumulate time
	day_timer += delta

	if day_timer >= seconds_per_day:
		day_timer = 0.0
		store.advance_day()

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
			KEY_SPACE:
				store.toggle_pause()

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
