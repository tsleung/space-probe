extends Node

## ShipViewBridge - Connects Phase2Store signals to ShipView visualization
## Translates game state changes into visual crew movements and room effects

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")
const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

# ============================================================================
# MAPPINGS
# ============================================================================

# Map P2 storage containers to ship rooms
const CONTAINER_TO_ROOM = {
	"cargo_a": ShipTypes.RoomType.CARGO_BAY,
	"cargo_b": ShipTypes.RoomType.QUARTERS,
	"cargo_c": ShipTypes.RoomType.ENGINEERING,
	"emergency": ShipTypes.RoomType.MEDICAL
}

# Map P2 crew roles (enum int) to visual crew
const ROLE_TO_VISUAL = {
	Phase2Types.CrewRole.COMMANDER: "commander",
	Phase2Types.CrewRole.ENGINEER: "engineer",
	Phase2Types.CrewRole.SCIENTIST: "scientist",
	Phase2Types.CrewRole.MEDICAL: "medical"
}

# Map event types to room responses
const EVENT_ROOM_TARGETS = {
	Phase2Types.EventType.COMPONENT_MALFUNCTION: ShipTypes.RoomType.ENGINEERING,
	Phase2Types.EventType.MICROMETEORITE: ShipTypes.RoomType.ENGINEERING,
	Phase2Types.EventType.CARGO_LOOSE: ShipTypes.RoomType.CARGO_BAY,
}

# ============================================================================
# REFERENCES
# ============================================================================

@export var store_path: NodePath
@export var ship_view_path: NodePath
@export var journey_indicator_path: NodePath

var store: Node  # Phase2Store
var ship_view: Node2D  # ShipView
var journey_indicator: Node2D
var sound_manager: Node  # Phase2SoundManager
var effects_manager: Node2D  # Phase2Effects
var ship_hull: Node2D  # ShipHull - for engine burn effects

# Track repair state for visual updates
var active_repairs: Dictionary = {}  # container_id -> {room_type, days_total, days_remaining}

# Track current event for resolution visuals
var current_event: Dictionary = {}
var current_event_type: int = -1

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	await get_tree().process_frame
	_connect_references()

func _connect_references() -> void:
	# Find store
	if store_path:
		store = get_node(store_path)
	if not store:
		store = get_parent().get_node_or_null("Phase2Store")

	# Find ship view
	if ship_view_path:
		ship_view = get_node(ship_view_path)
	if not ship_view:
		ship_view = get_parent().get_node_or_null("ShipView")

	# Find journey indicator
	if journey_indicator_path:
		journey_indicator = get_node(journey_indicator_path)
	if not journey_indicator:
		journey_indicator = get_parent().get_node_or_null("JourneyIndicator")

	# Find sound manager
	sound_manager = get_parent().get_node_or_null("SoundManager")

	# Find effects manager
	effects_manager = get_parent().get_node_or_null("Effects")

	# Find ship hull for engine burn effects
	ship_hull = get_parent().get_node_or_null("ShipHull")

	if not store:
		push_warning("ShipViewBridge: Could not find Phase2Store")
		return

	if not ship_view:
		push_warning("ShipViewBridge: Could not find ShipView")
		return

	# Connect to store signals
	store.day_advanced.connect(_on_day_advanced)
	store.crew_changed.connect(_on_crew_changed)
	store.container_blocked.connect(_on_container_blocked)
	store.container_restored.connect(_on_container_restored)
	store.repair_started.connect(_on_repair_started)
	store.repair_completed.connect(_on_repair_completed)
	store.event_triggered.connect(_on_event_triggered)
	store.event_resolved.connect(_on_event_resolved)
	store.mars_visible.connect(_on_mars_visible)
	store.game_over.connect(_on_game_over)

	# Initialize visual state from current store state
	_sync_initial_state()

func _sync_initial_state() -> void:
	if not store or not ship_view:
		return

	var state = store.get_state()

	# Sync crew positions to their home rooms
	_sync_crew_to_home_positions()

	# Sync any already-blocked containers
	for container in state.storage_containers:
		if container.status != Phase2Types.ContainerStatus.NOMINAL:
			var room_type = CONTAINER_TO_ROOM.get(container.id)
			if room_type != null:
				ship_view.damage_room(room_type, 0.7)

	# Sync journey indicator
	if journey_indicator:
		journey_indicator.set_current_day(state.current_day)

func _sync_crew_to_home_positions() -> void:
	# Position visual crew at their home stations
	pass  # ShipView already does this in _position_crew_at_stations

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_day_advanced(day: int) -> void:
	# Update journey indicator
	if journey_indicator:
		journey_indicator.set_current_day(day)

	# Update repair progress visuals
	_update_repair_visuals()

	# Sync crew visual state (fatigue, etc.)
	if store:
		var state = store.get_state()
		_update_crew_visuals(state.crew)

func _on_crew_changed(crew: Array) -> void:
	_update_crew_visuals(crew)

func _on_container_blocked(container: Dictionary) -> void:
	var room_type = CONTAINER_TO_ROOM.get(container.id)
	if room_type == null:
		return

	# Show damage on the room
	ship_view.damage_room(room_type, 0.8)

	# Visual alert - engineer looks at the problem
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", room_type, true)

func _on_container_restored(container: Dictionary) -> void:
	var room_type = CONTAINER_TO_ROOM.get(container.id)
	if room_type == null:
		return

	# Clear damage visual
	ship_view.repair_room(room_type)

	# Clear repair tracking
	active_repairs.erase(container.id)

	# Return engineer to engineering
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)

func _on_repair_started(container_id: String, days: int) -> void:
	var room_type = CONTAINER_TO_ROOM.get(container_id)
	if room_type == null:
		return

	# Track repair progress
	active_repairs[container_id] = {
		"room_type": room_type,
		"days_total": days,
		"days_remaining": days
	}

	# Send engineer to the room
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", room_type, true)

	# Start working task
	await get_tree().create_timer(1.0).timeout  # Wait for engineer to arrive
	if ship_view.has_method("assign_task_to_crew"):
		ship_view.assign_task_to_crew("engineer", ShipTypes.TaskType.REPAIR)

	# Show repair progress on room
	if ship_view.has_method("show_repair_progress"):
		ship_view.show_repair_progress(room_type, 0.0)

func _on_repair_completed(container_id: String) -> void:
	var room_type = CONTAINER_TO_ROOM.get(container_id)
	if room_type == null:
		return

	# Clear repair tracking
	active_repairs.erase(container_id)

	# Clear repair progress visual
	if ship_view.has_method("hide_repair_progress"):
		ship_view.hide_repair_progress(room_type)

	# Finish engineer's task
	var engineer = ship_view.get_crew_member("engineer")
	if engineer and engineer.has_method("finish_task"):
		engineer.finish_task()

func _on_event_triggered(event: Dictionary) -> void:
	# Store event for resolution visuals
	current_event = event.duplicate(true)
	current_event_type = event.get("type", -1)

	# Play event sound
	if sound_manager and sound_manager.has_method("play_event_alert"):
		sound_manager.play_event_alert(current_event_type)

	# Dispatch visual response based on event type
	match current_event_type:
		Phase2Types.EventType.SOLAR_FLARE:
			_handle_solar_flare_visual()
		Phase2Types.EventType.COMPONENT_MALFUNCTION:
			_handle_malfunction_visual()
		Phase2Types.EventType.MESSAGE_FROM_EARTH:
			_handle_message_visual()
		Phase2Types.EventType.MICROMETEORITE:
			_handle_micrometeorite_visual()
		Phase2Types.EventType.CARGO_LOOSE:
			_handle_cargo_loose_visual()
		Phase2Types.EventType.SECTION_BLOCKAGE:
			# Handled by container_blocked signal
			pass
		# New event types
		Phase2Types.EventType.CREW_CONFLICT:
			_handle_crew_conflict_visual()
		Phase2Types.EventType.MEDICAL_EMERGENCY:
			_handle_medical_emergency_visual()
		Phase2Types.EventType.POWER_SURGE:
			_handle_power_surge_visual()
		Phase2Types.EventType.NAVIGATION_DRIFT:
			_handle_navigation_visual()
		Phase2Types.EventType.WATER_RECYCLER_ISSUE:
			_handle_water_issue_visual()
		Phase2Types.EventType.OXYGEN_FLUCTUATION:
			_handle_oxygen_visual()
		Phase2Types.EventType.COMMUNICATION_STATIC:
			_handle_communication_visual()
		Phase2Types.EventType.MORALE_MILESTONE:
			_handle_milestone_visual()
		# Special events
		Phase2Types.EventType.MIDPOINT_CRISIS:
			_handle_midpoint_crisis_visual()
		Phase2Types.EventType.MARS_VISIBLE_EVENT:
			_handle_mars_visible_visual()
		Phase2Types.EventType.FINAL_APPROACH:
			_handle_final_approach_visual()
		_:
			# Generic event - show activity
			pass

func _on_event_resolved(choice_index: int) -> void:
	# Show visual feedback based on event type and choice
	_show_choice_visual(current_event_type, choice_index, current_event)

	# Play resolution sound
	if sound_manager and sound_manager.has_method("play_event_resolved"):
		sound_manager.play_event_resolved()

	# Clear current event
	current_event = {}
	current_event_type = -1

	# Return crew to stations after a delay (unless EVA which handles its own return)
	if current_event_type != Phase2Types.EventType.SECTION_BLOCKAGE or choice_index != 1:
		await get_tree().create_timer(1.5).timeout
		_return_crew_to_stations()

func _show_choice_visual(event_type: int, choice: int, event_data: Dictionary = {}) -> void:
	## Show visual feedback based on the player's choice
	if not ship_view:
		return

	match event_type:
		Phase2Types.EventType.SOLAR_FLARE:
			match choice:
				0:  # Shelter in cargo hold
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.CARGO_BAY, true)
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.CARGO_BAY, true)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.CARGO_BAY, true)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.CARGO_BAY, true)
					_flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.3, 0.5, 1.0))
				1:  # Continue with shielding
					_flash_ship(Color(1.0, 0.8, 0.3, 0.3))
				2:  # Emergency power to shields
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
					_flash_room(ShipTypes.RoomType.ENGINEERING, Color(0.9, 0.7, 0.2))

		Phase2Types.EventType.COMPONENT_MALFUNCTION:
			match choice:
				0:  # Assign engineer to repair
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, true)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.3, 0.8, 0.4))
				1:  # Monitor for now - commander moves around bridge checking consoles
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.5, 0.5, 0.7))

		Phase2Types.EventType.MESSAGE_FROM_EARTH:
			match choice:
				0:  # Share immediately
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, false)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.4, 0.8, 1.0))
				1:  # Save for later
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.3, 0.5, 0.6))

		Phase2Types.EventType.MICROMETEORITE:
			match choice:
				0:  # Full hull inspection
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.CARGO_BAY, true)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.ENGINEERING, true)
					_flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.8, 0.5, 0.2))
				1:  # Quick visual check
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.CORRIDOR, false)
					_flash_room(ShipTypes.RoomType.CORRIDOR, Color(0.6, 0.6, 0.5))

		Phase2Types.EventType.CARGO_LOOSE:
			match choice:
				0:  # Secure everything properly
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.CARGO_BAY, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.CARGO_BAY, false)
					_flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.4, 0.7, 0.4))
				1:  # Catch what you can
					var roles = ["commander", "scientist", "medical"]
					var picker = roles[randi() % roles.size()]
					ship_view.send_crew_to_room(picker, ShipTypes.RoomType.CARGO_BAY, true)
					_flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.7, 0.5, 0.3))

		Phase2Types.EventType.SECTION_BLOCKAGE:
			var container_id = event_data.get("blocked_container_id", "")
			var room_type = CONTAINER_TO_ROOM.get(container_id, ShipTypes.RoomType.CARGO_BAY)
			match choice:
				0:  # Repair section - engineer goes to damaged room
					ship_view.send_crew_to_room("engineer", room_type, true)
					_flash_room(room_type, Color(0.3, 0.7, 0.4))
				1:  # EVA retrieval - TRIGGER THE FULL EVA VISUAL!
					trigger_eva_visual("engineer")
					_flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.5, 0.7, 1.0))

		Phase2Types.EventType.NAVIGATION_DRIFT:
			match choice:
				0:  # Immediate correction burn
					if ship_hull and ship_hull.has_method("trigger_correction_burn"):
						ship_hull.trigger_correction_burn(2.5)
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(1.0, 0.6, 0.3))
					if sound_manager and sound_manager.has_method("play_engine_burn"):
						sound_manager.play_engine_burn()
				1:  # Wait for optimal window - scientist calculates
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.BRIDGE, false)
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.4, 0.6, 0.8))

		Phase2Types.EventType.CREW_CONFLICT:
			match choice:
				0:  # Commander intervenes
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, true)
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, false)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.4, 0.7, 0.5))
				1:  # Let them work it out - crew separates
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, false)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.6, 0.4, 0.4))
				2:  # Enforce strict protocol
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, true)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.5, 0.5, 0.7))

		Phase2Types.EventType.MEDICAL_EMERGENCY:
			# Pick a random patient (not the medic themselves)
			var patient_roles = ["commander", "engineer", "scientist"]
			var patient_role = patient_roles[randi() % patient_roles.size()]

			match choice:
				0:  # Emergency surgery - patient and medic to medical bay
					# Patient goes first (they're the one in emergency)
					ship_view.send_crew_to_room(patient_role, ShipTypes.RoomType.MEDICAL, true)
					# Medic runs to treat them
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, true)
					# Scientist assists
					if patient_role != "scientist":
						ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.MEDICAL, false)
					_flash_room(ShipTypes.RoomType.MEDICAL, Color(0.9, 0.3, 0.3))  # Red for emergency
				1:  # Conservative treatment - patient and medic to medical
					ship_view.send_crew_to_room(patient_role, ShipTypes.RoomType.MEDICAL, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, true)
					_flash_room(ShipTypes.RoomType.MEDICAL, Color(0.5, 0.7, 0.5))
				2:  # Aggressive treatment - patient stays in bed, medic treats
					ship_view.send_crew_to_room(patient_role, ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, true)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.4, 0.5, 0.6))

		Phase2Types.EventType.POWER_SURGE:
			match choice:
				0:  # Reroute to backup
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
					_flash_room(ShipTypes.RoomType.ENGINEERING, Color(0.9, 0.7, 0.2))
					_flash_ship(Color(0.8, 0.6, 0.2, 0.2))
				1:  # Engineer stabilizes manually
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
					_flash_room(ShipTypes.RoomType.ENGINEERING, Color(0.6, 0.8, 0.4))

		Phase2Types.EventType.WATER_RECYCLER_ISSUE:
			match choice:
				0:  # Replace the filter
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, true)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.CARGO_BAY, false)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.3, 0.6, 0.9))
				1:  # Clean and recalibrate
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, true)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.4, 0.7, 0.8))
				2:  # Ration water
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.5, 0.6, 0.7))

		Phase2Types.EventType.OXYGEN_FLUCTUATION:
			match choice:
				0:  # Run full diagnostics
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, true)
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.4, 0.8, 0.9))
				1:  # Replace sensors
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, true)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.CARGO_BAY, false)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.3, 0.7, 0.8))
				2:  # Monitor closely
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, false)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.5, 0.6, 0.7))

		Phase2Types.EventType.COMMUNICATION_STATIC:
			match choice:
				0:  # Boost transmitter power
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.5, 0.8, 0.5))
				1:  # Wait for interference to pass
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.4, 0.5, 0.5))

		Phase2Types.EventType.MORALE_MILESTONE:
			match choice:
				0:  # Special meal
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, false)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.8, 0.6, 0.3))
				1:  # Movie night
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, false)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.5, 0.7, 1.0))
				2:  # Keep working
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.5, 0.5, 0.5))

		Phase2Types.EventType.MIDPOINT_CRISIS:
			match choice:
				0:  # All hands emergency repair
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, true)
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.CORRIDOR, true)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, true)
					_flash_ship(Color(1.0, 0.5, 0.2, 0.4))
					if effects_manager and effects_manager.has_method("shake_screen"):
						effects_manager.shake_screen(5.0, 0.3)
				1:  # Prioritize oxygen
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, true)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, true)
					_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.4, 0.8, 0.9))
				2:  # EVA to external repair
					trigger_eva_visual("engineer")
					_flash_room(ShipTypes.RoomType.CARGO_BAY, Color(0.5, 0.7, 1.0))
					if effects_manager and effects_manager.has_method("shake_screen"):
						effects_manager.shake_screen(3.0, 0.2)

		Phase2Types.EventType.MARS_VISIBLE_EVENT:
			match choice:
				0, 1:  # Celebrate or acknowledge
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.BRIDGE, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.BRIDGE, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.BRIDGE, false)
					_flash_room(ShipTypes.RoomType.BRIDGE, Color(1.0, 0.5, 0.3))

		Phase2Types.EventType.FINAL_APPROACH:
			match choice:
				0:  # Run final system checks
					ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, false)
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
					_flash_ship(Color(0.5, 0.7, 0.5, 0.3))
				1:  # Rest before arrival
					ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.QUARTERS, false)
					ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, false)
					_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.4, 0.5, 0.6))

func _flash_room(room_type, color: Color) -> void:
	## Flash a room with a color to indicate activity
	if ship_view and ship_view.has_method("flash_room"):
		ship_view.flash_room(room_type, color)

func _flash_ship(color: Color) -> void:
	## Flash the whole ship (for radiation, alerts, etc.)
	if ship_view and ship_view.has_method("flash_all_rooms"):
		ship_view.flash_all_rooms(color)

func _on_mars_visible() -> void:
	# Mars visibility handled by journey indicator automatically
	pass

func _on_game_over(reason: String) -> void:
	# Stop all crew movement, show distress state
	if ship_view:
		for role in ["commander", "engineer", "scientist", "medical"]:
			var crew = ship_view.get_crew_member(role)
			if crew and crew.has_method("finish_task"):
				crew.finish_task()

# ============================================================================
# VISUAL EVENT HANDLERS
# ============================================================================

func _handle_solar_flare_visual() -> void:
	# All crew move toward center/shelter
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.CORRIDOR, true)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.CORRIDOR, true)

	# Solar flare effect
	if effects_manager and effects_manager.has_method("trigger_solar_flare_effect"):
		effects_manager.trigger_solar_flare_effect()

func _handle_malfunction_visual() -> void:
	# Engineer runs to engineering
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)

func _handle_message_visual() -> void:
	# Commander goes to bridge to receive message
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)

func _handle_micrometeorite_visual() -> void:
	# Engineer responds to hull damage
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)

	# Screen shake for impact
	if effects_manager and effects_manager.has_method("trigger_impact"):
		effects_manager.trigger_impact(0.5)

	# Play damage sound
	if sound_manager and sound_manager.has_method("play_damage"):
		sound_manager.play_damage()

func _handle_cargo_loose_visual() -> void:
	# Random crew chases loose cargo
	var roles = ["commander", "scientist", "engineer", "medical"]
	var random_role = roles[randi() % roles.size()]
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room(random_role, ShipTypes.RoomType.CARGO_BAY, false)

# NEW EVENT VISUAL HANDLERS

func _handle_crew_conflict_visual() -> void:
	# Two crew members move apart - visible tension
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, false)
		# Commander goes to mediate
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, true)

func _handle_medical_emergency_visual() -> void:
	# Medical crew rushes to medical bay
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, true)
		# Random patient
		var patient = ["commander", "engineer", "scientist"][randi() % 3]
		ship_view.send_crew_to_room(patient, ShipTypes.RoomType.MEDICAL, true)
	_flash_room(ShipTypes.RoomType.MEDICAL, Color(1.0, 0.3, 0.3))

func _handle_power_surge_visual() -> void:
	# Engineer runs to engineering, flash warning
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
	_flash_room(ShipTypes.RoomType.ENGINEERING, Color(1.0, 0.9, 0.2))
	# Flash entire ship yellow briefly
	_flash_ship(Color(1.0, 0.8, 0.3, 0.2))

func _handle_navigation_visual() -> void:
	# Commander and scientist to bridge
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.BRIDGE, false)
	_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.5, 0.5, 1.0))

func _handle_water_issue_visual() -> void:
	# Engineer to life support
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, true)
	_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.3, 0.6, 1.0))

func _handle_oxygen_visual() -> void:
	# Scientist checks life support
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, true)
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.LIFE_SUPPORT, false)
	_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(0.4, 0.8, 0.9))

func _handle_communication_visual() -> void:
	# Commander to bridge for communications
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
	_flash_room(ShipTypes.RoomType.BRIDGE, Color(0.6, 0.8, 0.4))

func _handle_milestone_visual() -> void:
	# Crew gathers in quarters to celebrate
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.QUARTERS, false)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.QUARTERS, false)
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.QUARTERS, false)
		# Engineer stays on duty
	_flash_room(ShipTypes.RoomType.QUARTERS, Color(0.5, 1.0, 0.5))

# SPECIAL EVENT VISUAL HANDLERS

func _handle_midpoint_crisis_visual() -> void:
	# EMERGENCY! All crew scramble, ship flashes red
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, true)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, true)
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, true)
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, true)
	# Multiple room flashes for cascade failure
	_flash_room(ShipTypes.RoomType.ENGINEERING, Color(1.0, 0.2, 0.2))
	_flash_room(ShipTypes.RoomType.LIFE_SUPPORT, Color(1.0, 0.3, 0.1))
	_flash_ship(Color(1.0, 0.2, 0.2, 0.4))

	# Major screen shake for crisis
	if effects_manager and effects_manager.has_method("shake_screen"):
		effects_manager.shake_screen(10.0, 0.5)

	# Play alarm
	if sound_manager and sound_manager.has_method("play_alarm"):
		sound_manager.play_alarm()

func _handle_mars_visible_visual() -> void:
	# Crew gathers at bridge windows to look at Mars!
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.BRIDGE, false)
	_flash_room(ShipTypes.RoomType.BRIDGE, Color(1.0, 0.5, 0.3))

func _handle_final_approach_visual() -> void:
	# Crew at stations for final approach
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
	_flash_ship(Color(0.8, 0.4, 0.3, 0.2))

func _return_crew_to_stations() -> void:
	if not ship_view:
		return

	# Return crew to their home stations
	if ship_view.has_method("send_crew_to_room"):
		ship_view.send_crew_to_room("commander", ShipTypes.RoomType.BRIDGE, false)
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.ENGINEERING, false)
		ship_view.send_crew_to_room("scientist", ShipTypes.RoomType.LIFE_SUPPORT, false)
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.MEDICAL, false)

# ============================================================================
# UPDATE FUNCTIONS
# ============================================================================

func _update_repair_visuals() -> void:
	for container_id in active_repairs:
		var repair = active_repairs[container_id]
		repair.days_remaining -= 1

		var progress = 1.0 - (float(repair.days_remaining) / float(repair.days_total))
		if ship_view.has_method("show_repair_progress"):
			ship_view.show_repair_progress(repair.room_type, progress)

func _update_crew_visuals(crew: Array) -> void:
	if not ship_view:
		return

	for crew_data in crew:
		var role_enum = crew_data.get("role", Phase2Types.CrewRole.COMMANDER)
		var visual_role = ROLE_TO_VISUAL.get(role_enum, "")
		if visual_role.is_empty():
			continue

		var crew_visual = ship_view.get_crew_member(visual_role)
		if not crew_visual:
			continue

		# Update visual based on crew stats
		var health = crew_data.get("health", 100)
		var morale = crew_data.get("morale", 100)
		var fatigue = crew_data.get("fatigue", 0)

		# Apply visual effects based on stats
		if crew_visual.has_method("set_health_visual"):
			crew_visual.set_health_visual(health)
		if crew_visual.has_method("set_morale_visual"):
			crew_visual.set_morale_visual(morale)

		# High fatigue = crew should rest
		if fatigue > 80 and crew_visual.has_method("start_resting"):
			crew_visual.start_resting()

# ============================================================================
# EVA VISUAL (special case)
# ============================================================================

func trigger_eva_visual(crew_role) -> void:
	## Called when EVA retrieval is chosen
	## Shows crew going outside the ship
	## crew_role can be a CrewRole enum or string
	var visual_role: String
	if crew_role is int:
		visual_role = ROLE_TO_VISUAL.get(crew_role, "engineer")
	else:
		# Fallback for string input
		visual_role = crew_role.to_lower() if crew_role else "engineer"

	if ship_view and ship_view.has_method("trigger_eva_visual"):
		ship_view.trigger_eva_visual(visual_role)
