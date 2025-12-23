extends Node
class_name CrisisController

## Crisis Controller - Main integration point for the real-time crisis system
## Connects CrisisManager, CrisisAI, CrisisVisual with Phase2Store and ShipView

const CrisisTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_types.gd")
const CrisisManagerScript = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_manager.gd")
const CrisisAIScript = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_ai.gd")
const CrisisVisualScript = preload("res://scripts/mars_odyssey_trek/phase2/crisis/crisis_visual.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# COMPONENTS
# ============================================================================

var crisis_manager: Node  # CrisisManager
var crisis_ai: Node  # CrisisAI
var crisis_visual: Node2D  # CrisisVisual

# ============================================================================
# REFERENCES
# ============================================================================

var phase2_store: Node
var ship_view: Node2D
var ship_view_bridge: Node

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var crisis_mode_enabled: bool = true
@export var ai_mode_enabled: bool = true

# ============================================================================
# SIGNALS
# ============================================================================

signal crisis_count_changed(count: int)
signal total_drain_changed(drain_per_sec: Dictionary)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Create crisis system components
	_create_components()

	# Wait a frame for parent to set up references
	await get_tree().process_frame
	_connect_references()

func _create_components() -> void:
	# Crisis Manager
	crisis_manager = CrisisManagerScript.new()
	crisis_manager.name = "CrisisManager"
	add_child(crisis_manager)

	# Crisis AI
	crisis_ai = CrisisAIScript.new()
	crisis_ai.name = "CrisisAI"
	add_child(crisis_ai)

	# Crisis Visual (Node2D for rendering)
	crisis_visual = CrisisVisualScript.new()
	crisis_visual.name = "CrisisVisual"
	add_child(crisis_visual)

	# Connect AI to manager
	crisis_ai.connect_to_manager(crisis_manager)

func _connect_references() -> void:
	# Find Phase2Store
	phase2_store = get_parent().get_node_or_null("Phase2Store")

	# Find ShipView
	ship_view = get_parent().get_node_or_null("ShipView")

	# Find ShipViewBridge
	ship_view_bridge = get_parent().get_node_or_null("ShipViewBridge")

	if not phase2_store:
		push_warning("CrisisController: Phase2Store not found")

	if not ship_view:
		push_warning("CrisisController: ShipView not found")
	else:
		crisis_visual.setup(crisis_manager, ship_view)

	# Connect crisis manager signals
	crisis_manager.crisis_spawned.connect(_on_crisis_spawned)
	crisis_manager.crisis_resolved.connect(_on_crisis_resolved)
	crisis_manager.crew_assigned.connect(_on_crew_assigned)
	crisis_manager.crew_unassigned.connect(_on_crew_unassigned)
	crisis_manager.resource_drained.connect(_on_resource_drained)
	crisis_manager.catastrophe.connect(_on_catastrophe)

	# Connect to Phase2Store signals if available
	if phase2_store:
		if phase2_store.has_signal("hour_advanced"):
			phase2_store.hour_advanced.connect(_on_hour_advanced)
		if phase2_store.has_signal("speed_changed"):
			phase2_store.speed_changed.connect(_on_speed_changed)

	# Initial state sync
	_sync_journey_progress()

# ============================================================================
# PROCESS
# ============================================================================

func _process(_delta: float) -> void:
	if not crisis_mode_enabled:
		return

	# Emit crisis count for HUD
	var count = crisis_manager.get_crisis_count()
	crisis_count_changed.emit(count)

# ============================================================================
# SIGNAL HANDLERS - CRISIS MANAGER
# ============================================================================

func _on_crisis_spawned(crisis: Dictionary) -> void:
	# Visual feedback - flash the room
	if ship_view and ship_view.has_method("flash_room"):
		var color = CrisisTypes.get_severity_color(crisis.severity)
		ship_view.flash_room(crisis.room, color)

	# Sound alert
	var sound_manager = get_parent().get_node_or_null("SoundManager")
	if sound_manager and sound_manager.has_method("play_alarm"):
		sound_manager.play_alarm()

func _on_crisis_resolved(crisis: Dictionary) -> void:
	# Visual feedback - flash green
	if ship_view and ship_view.has_method("flash_room"):
		ship_view.flash_room(crisis.room, Color(0.3, 0.9, 0.3))

	# Sound
	var sound_manager = get_parent().get_node_or_null("SoundManager")
	if sound_manager and sound_manager.has_method("play_event_resolved"):
		sound_manager.play_event_resolved()

func _on_crew_assigned(crisis_id: String, crew_role: String) -> void:
	## Crew was assigned to a crisis - make them move there
	var crisis = crisis_manager.get_crisis_by_id(crisis_id)
	if crisis.is_empty():
		return

	if ship_view and ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room(crew_role, crisis.room, true)

func _on_crew_unassigned(_crisis_id: String, crew_role: String) -> void:
	## Crew finished or was reassigned - return to home station
	var home_rooms = {
		"commander": ShipTypes.RoomType.BRIDGE,
		"engineer": ShipTypes.RoomType.ENGINEERING,
		"scientist": ShipTypes.RoomType.LIFE_SUPPORT,
		"medical": ShipTypes.RoomType.MEDICAL
	}

	if ship_view and ship_view.has_method("send_crew_to_room"):
		var home = home_rooms.get(crew_role, ShipTypes.RoomType.BRIDGE)
		ship_view.send_crew_to_room(crew_role, home, false)

func _on_resource_drained(resource: String, amount: float) -> void:
	## Apply resource drain to Phase2Store
	if not phase2_store:
		return

	# Get current state and apply drain
	var state = phase2_store.get_state()
	var resources = state.get("resources", {})

	match resource:
		"oxygen":
			if resources.has("oxygen"):
				var new_val = max(0, resources.oxygen.current - amount)
				_update_resource(resources, "oxygen", new_val)
		"power":
			if resources.has("power"):
				var new_val = max(0, resources.power.current - amount)
				_update_resource(resources, "power", new_val)
		"water":
			if resources.has("water"):
				var new_val = max(0, resources.water.current - amount)
				_update_resource(resources, "water", new_val)
		"fuel":
			if resources.has("fuel"):
				var new_val = max(0, resources.fuel.current - amount)
				_update_resource(resources, "fuel", new_val)
		"food":
			if resources.has("food"):
				var new_val = max(0, resources.food.current - amount)
				_update_resource(resources, "food", new_val)
		"morale":
			# Apply to all crew
			var crew = state.get("crew", [])
			for member in crew:
				member.morale = max(0, member.morale - amount * 0.1)
		"crew_health":
			# Apply to random crew member
			var crew = state.get("crew", [])
			if crew.size() > 0:
				var victim = crew[randi() % crew.size()]
				victim.health = max(0, victim.health - amount * 0.5)

func _update_resource(resources: Dictionary, key: String, new_value: float) -> void:
	## Helper to update a resource value
	if resources.has(key):
		resources[key].current = new_value
		# Emit resources_changed if store supports it
		if phase2_store and phase2_store.has_signal("resources_changed"):
			phase2_store.resources_changed.emit(resources)

func _on_catastrophe(crisis: Dictionary, effect: String) -> void:
	## Handle catastrophic events
	print("[CRISIS] CATASTROPHE! %s caused %s" % [crisis.name, effect])

	match effect:
		"hull_breach":
			# Massive O2 loss
			_on_resource_drained("oxygen", 20.0)
			# Screen shake
			var effects = get_parent().get_node_or_null("Effects")
			if effects and effects.has_method("shake_screen"):
				effects.shake_screen(15.0, 0.5)

# ============================================================================
# SIGNAL HANDLERS - PHASE2STORE
# ============================================================================

func _on_hour_advanced(_day: int, _hour: int) -> void:
	# Update journey progress for crisis spawning
	_sync_journey_progress()

func _on_speed_changed(speed: int) -> void:
	# Pause crisis system when game is paused
	crisis_manager.set_paused(speed == 0)

func _sync_journey_progress() -> void:
	if not phase2_store:
		return

	var progress = phase2_store.get_journey_progress() if phase2_store.has_method("get_journey_progress") else 0.0
	crisis_manager.set_journey_progress(progress)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not crisis_mode_enabled:
		return

	# Click to assign crew manually (when AI is off)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not ai_mode_enabled:
			_handle_click(event.position)

	# Toggle crisis mode with C key
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_C:
				crisis_mode_enabled = not crisis_mode_enabled
				crisis_manager.enabled = crisis_mode_enabled
				print("[CRISIS] Crisis mode: %s" % ("ON" if crisis_mode_enabled else "OFF"))
			KEY_V:
				# Debug: spawn random crisis
				crisis_manager.debug_spawn_random()

func _handle_click(position: Vector2) -> void:
	## Handle manual crew assignment via click
	var crisis = crisis_visual.get_crisis_at_screen_position(position)
	if crisis.is_empty():
		return

	# Find first available crew
	for role in ["engineer", "scientist", "medical", "commander"]:
		if not crisis_manager.is_crew_busy(role):
			crisis_manager.assign_crew(role, crisis.id)
			break

# ============================================================================
# PUBLIC API
# ============================================================================

func set_crisis_mode(enabled: bool) -> void:
	crisis_mode_enabled = enabled
	crisis_manager.enabled = enabled
	print("[CRISIS] Crisis mode: %s" % ("ON" if enabled else "OFF"))

func set_ai_mode(enabled: bool) -> void:
	ai_mode_enabled = enabled
	crisis_ai.set_enabled(enabled)
	print("[CRISIS] AI mode: %s" % ("ON" if enabled else "OFF"))

func get_crisis_count() -> int:
	return crisis_manager.get_crisis_count()

func get_active_crises() -> Array:
	return crisis_manager.get_active_crises()

func spawn_test_crisis() -> void:
	crisis_manager.debug_spawn_random()
