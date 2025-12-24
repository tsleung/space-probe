extends RefCounted
class_name Phase2Types

## Phase 2: Travel to Mars - Type Definitions
## Defines all data structures for the travel phase
## Uses Dictionary factories following MCSTypes pattern

# ============================================================================
# ENUMS
# ============================================================================

enum Speed {
	PAUSED,
	SLOW,
	NORMAL,
	FAST,
	ULTRA,
	LUDICROUS  # 10x faster than ULTRA - for debugging
}

enum ContainerStatus {
	NOMINAL,
	DEPRESSURIZED,
	DAMAGED,
	BLOCKED
}

enum CrewRole {
	COMMANDER,
	ENGINEER,
	SCIENTIST,
	MEDICAL
}

enum EventType {
	SOLAR_FLARE,
	COMPONENT_MALFUNCTION,
	MESSAGE_FROM_EARTH,
	MICROMETEORITE,
	CARGO_LOOSE,
	SECTION_BLOCKAGE,
	# New event types
	CREW_CONFLICT,
	MEDICAL_EMERGENCY,
	POWER_SURGE,
	NAVIGATION_DRIFT,
	WATER_RECYCLER_ISSUE,
	OXYGEN_FLUCTUATION,
	COMMUNICATION_STATIC,
	MORALE_MILESTONE,
	# Special events
	MIDPOINT_CRISIS,
	MARS_VISIBLE_EVENT,
	FINAL_APPROACH
}

enum EventEffectType {
	MORALE_BOOST,
	MORALE_LOSS,
	HEALTH_LOSS,
	POWER_DRAIN,
	FOOD_LOSS,
	WATER_LOSS,
	REPAIR_SECTION,
	EVA_RETRIEVAL
}

# ============================================================================
# CONSTANTS
# ============================================================================

# Time structure
const HOURS_PER_DAY = 24
const TOTAL_TRAVEL_DAYS = 183
const TOTAL_TRAVEL_HOURS = TOTAL_TRAVEL_DAYS * HOURS_PER_DAY  # 4392 hours

# Real-time seconds per game hour at each speed
const SECONDS_PER_HOUR = {
	Speed.PAUSED: 0.0,
	Speed.SLOW: 0.5,       # 12 seconds per day
	Speed.NORMAL: 0.2,     # ~5 seconds per day
	Speed.FAST: 0.05,      # ~1.2 seconds per day
	Speed.ULTRA: 0.005,    # ~0.12 seconds per day (whole journey in ~22 seconds)
	Speed.LUDICROUS: 0.0005  # 10x ULTRA (~2 seconds for whole journey)
}

# Hourly consumption rates (daily rates / 24)
const HOURLY_FOOD_PER_CREW = 1.0 / HOURS_PER_DAY      # ~0.042
const HOURLY_WATER_PER_CREW = 0.5 / HOURS_PER_DAY     # ~0.021
const HOURLY_OXYGEN_LOSS = 0.1 / HOURS_PER_DAY        # ~0.004
const HOURLY_MORALE_DECAY = 0.5 / HOURS_PER_DAY       # ~0.021
const HOURLY_FATIGUE_GAIN = 0.3 / HOURS_PER_DAY       # ~0.012

# Legacy daily rates (for reference)
const DAILY_FOOD_PER_CREW = 1.0
const DAILY_WATER_PER_CREW = 0.5
const DAILY_OXYGEN_LOSS = 0.1
const DAILY_MORALE_DECAY = 0.5
const DAILY_FATIGUE_GAIN = 0.3

const MARS_VISIBLE_DAY = 140
const MARS_VISIBLE_HOUR = MARS_VISIBLE_DAY * HOURS_PER_DAY

# Event chances (per hour - increased for more action)
const BASE_EVENT_CHANCE_PER_HOUR = 0.25 / HOURS_PER_DAY      # ~1% per hour
const EARLY_EVENT_CHANCE_PER_HOUR = 0.35 / HOURS_PER_DAY     # ~1.5% per hour
const MIDPOINT_EVENT_CHANCE_PER_HOUR = 0.50 / HOURS_PER_DAY  # ~2% per hour
const FINAL_EVENT_CHANCE_PER_HOUR = 0.40 / HOURS_PER_DAY     # ~1.7% per hour
const SECTION_BLOCKAGE_CHANCE = 0.15  # Of events that trigger

# Legacy daily event chances
const BASE_EVENT_CHANCE = 0.10
const EARLY_EVENT_CHANCE = 0.15
const MIDPOINT_EVENT_CHANCE = 0.25
const FINAL_EVENT_CHANCE = 0.20

# EVA success rate
const EVA_SUCCESS_CHANCE = 0.70
const EVA_PARTIAL_RETRIEVAL_MIN = 0.30
const EVA_PARTIAL_RETRIEVAL_MAX = 0.60
const EVA_INJURY_DAMAGE = 25
const EVA_DURATION_HOURS = 6  # EVA takes 6 hours

# Repair (in hours instead of days)
const REPAIR_MIN_HOURS = 48   # 2 days
const REPAIR_MAX_HOURS = 96   # 4 days
const REPAIR_FATIGUE_COST = 20

# Legacy repair in days
const REPAIR_MIN_DAYS = 2
const REPAIR_MAX_DAYS = 4

# ============================================================================
# FACTORY FUNCTIONS - Storage Container
# ============================================================================

static func create_storage_container(overrides: Dictionary = {}) -> Dictionary:
	var container = {
		"id": "",
		"name": "",
		"section": "",
		"food": 0,
		"food_max": 0,
		"water": 0,
		"water_max": 0,
		"accessible": true,
		"status": ContainerStatus.NOMINAL
	}

	for key in overrides:
		container[key] = overrides[key]

	return container

static func create_default_containers() -> Array:
	return [
		create_storage_container({
			"id": "cargo_a",
			"name": "Cargo Bay A (Forward)",
			"section": "forward",
			"food": 250,
			"food_max": 250,
			"water": 100,
			"water_max": 100
		}),
		create_storage_container({
			"id": "cargo_b",
			"name": "Cargo Bay B (Midship)",
			"section": "midship",
			"food": 300,
			"food_max": 300,
			"water": 150,
			"water_max": 150
		}),
		create_storage_container({
			"id": "cargo_c",
			"name": "Cargo Bay C (Aft)",
			"section": "aft",
			"food": 200,
			"food_max": 200,
			"water": 100,
			"water_max": 100
		}),
		create_storage_container({
			"id": "emergency",
			"name": "Emergency Supplies (Hab)",
			"section": "hab",
			"food": 50,
			"food_max": 50,
			"water": 50,
			"water_max": 50
		})
	]

# ============================================================================
# FACTORY FUNCTIONS - Crew Member
# ============================================================================

static func create_crew_member(overrides: Dictionary = {}) -> Dictionary:
	var member = {
		"id": _generate_id(),
		"name": "",
		"role": CrewRole.COMMANDER,
		"health": 100.0,
		"morale": 80.0,
		"fatigue": 0.0
	}

	for key in overrides:
		member[key] = overrides[key]

	return member

static func create_default_crew() -> Array:
	return [
		create_crew_member({
			"name": "Chen Wei",
			"role": CrewRole.COMMANDER,
			"morale": 85.0
		}),
		create_crew_member({
			"name": "Sarah Mitchell",
			"role": CrewRole.ENGINEER,
			"morale": 80.0
		}),
		create_crew_member({
			"name": "Dr. Yuki Tanaka",
			"role": CrewRole.SCIENTIST,
			"morale": 90.0
		}),
		create_crew_member({
			"name": "Marcus Johnson",
			"role": CrewRole.MEDICAL,
			"morale": 75.0
		})
	]

# ============================================================================
# FACTORY FUNCTIONS - Resources
# ============================================================================

static func create_resources(overrides: Dictionary = {}) -> Dictionary:
	var resources = {
		"food": {"current": 0, "max": 0},  # Computed from containers
		"water": {"current": 0, "max": 0},  # Computed from containers
		"oxygen": {"current": 100.0, "max": 100.0},
		"power": {"current": 45.0, "max": 50.0},
		"fuel": {"current": 100.0, "max": 100.0}
	}

	for key in overrides:
		resources[key] = overrides[key]

	return resources

# ============================================================================
# FACTORY FUNCTIONS - Repair State
# ============================================================================

static func create_repair_state(overrides: Dictionary = {}) -> Dictionary:
	var repair = {
		"in_progress": false,
		"hours_remaining": 0,
		"days_remaining": 0,  # Legacy, computed from hours
		"target_container_id": ""
	}

	for key in overrides:
		repair[key] = overrides[key]

	return repair

# ============================================================================
# FACTORY FUNCTIONS - Event
# ============================================================================

static func create_event(overrides: Dictionary = {}) -> Dictionary:
	var event = {
		"id": _generate_id(),
		"type": EventType.SOLAR_FLARE,
		"title": "",
		"description": "",
		"options": [],  # Array of event options
		"blocked_container_id": ""  # For section blockage events
	}

	for key in overrides:
		event[key] = overrides[key]

	return event

static func create_event_option(overrides: Dictionary = {}) -> Dictionary:
	## Create an event option with FTL-style weighted outcomes
	## Blue options require prerequisites (crew role, resource, or equipment)
	var option = {
		"label": "",
		"description": "",
		# Weighted outcomes (FTL-style) - if empty, use legacy single effect
		"outcomes": [],  # Array of {weight, effects[], description}
		# Legacy single effect (for backwards compatibility)
		"effect": EventEffectType.MORALE_BOOST,
		"effect_value": 0,
		# Blue option prerequisites (unlocks special choices)
		"requires_crew": "",        # CrewRole name: "engineer", "medical", etc.
		"requires_resource": "",    # Resource: "spare_parts", "medical_supplies"
		"requires_min": 0,          # Minimum amount of resource
		"is_blue_option": false     # Visual indicator for special options
	}

	for key in overrides:
		option[key] = overrides[key]

	return option

static func create_outcome(weight: float, effects: Array, description: String = "") -> Dictionary:
	## Create a weighted outcome for an event option
	## weight: probability (0.0-1.0), effects: array of effect dicts
	return {
		"weight": weight,
		"effects": effects,
		"description": description
	}

static func create_effect(effect_type: String, value = 0, target: String = "all") -> Dictionary:
	## Create a single effect for an outcome
	## effect_type: "morale", "health", "food", "water", "oxygen", "power", "fuel", "fatigue"
	## target: "all", "random", "engineer", "medical", etc.
	return {
		"type": effect_type,
		"value": value,
		"target": target
	}

# ============================================================================
# FACTORY FUNCTIONS - Main State
# ============================================================================

static func create_phase2_state(overrides: Dictionary = {}) -> Dictionary:
	var containers = create_default_containers()
	var resources = create_resources()

	# Compute initial resource totals from containers
	var total_food = 0.0
	var max_food = 0.0
	var total_water = 0.0
	var max_water = 0.0

	for container in containers:
		max_food += container.food_max
		max_water += container.water_max
		if container.accessible:
			total_food += container.food
			total_water += container.water

	resources.food.current = total_food
	resources.food.max = max_food
	resources.water.current = total_water
	resources.water.max = max_water

	var state = {
		# Time (hourly system)
		"current_hour": 0,         # 0-23 within current day
		"current_day": 1,          # Day 1 to 183
		"total_hours": 0,          # Total hours elapsed
		"total_days": TOTAL_TRAVEL_DAYS,
		"speed": Speed.NORMAL,
		"auto_advance": true,

		# Resources (totals computed from containers)
		"resources": resources,

		# Storage
		"storage_containers": containers,
		"active_container_index": 0,

		# Crew
		"crew": create_default_crew(),

		# Repair (now in hours)
		"repair": create_repair_state(),

		# Events
		"active_event": {},
		"event_queue": [],

		# Visual state (tracked for determinism, rendered by view)
		"mars_visible": false,

		# Random seed for determinism
		"random_seed": 0,

		# Log messages (for replay/debugging)
		"log": []
	}

	for key in overrides:
		state[key] = overrides[key]

	return state

# ============================================================================
# IMMUTABLE UPDATE HELPERS
# ============================================================================

static func with_field(record: Dictionary, field: String, value) -> Dictionary:
	var new_record = record.duplicate(true)
	new_record[field] = value
	return new_record

static func with_fields(record: Dictionary, updates: Dictionary) -> Dictionary:
	var new_record = record.duplicate(true)
	for key in updates:
		new_record[key] = updates[key]
	return new_record

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static var _id_counter: int = 0

static func _generate_id() -> String:
	_id_counter += 1
	return "p2_%d_%d" % [Time.get_ticks_msec(), _id_counter]

static func get_speed_name(speed: Speed) -> String:
	match speed:
		Speed.PAUSED: return "Paused"
		Speed.SLOW: return "Slow"
		Speed.NORMAL: return "Normal"
		Speed.FAST: return "Fast"
		Speed.ULTRA: return "ULTRA"
		Speed.LUDICROUS: return "LUDICROUS"
	return "Unknown"

static func get_container_status_name(status: ContainerStatus) -> String:
	match status:
		ContainerStatus.NOMINAL: return "Nominal"
		ContainerStatus.DEPRESSURIZED: return "Depressurized"
		ContainerStatus.DAMAGED: return "Damaged"
		ContainerStatus.BLOCKED: return "Blocked"
	return "Unknown"

static func get_crew_role_name(role: CrewRole) -> String:
	match role:
		CrewRole.COMMANDER: return "Commander"
		CrewRole.ENGINEER: return "Engineer"
		CrewRole.SCIENTIST: return "Scientist"
		CrewRole.MEDICAL: return "Medical"
	return "Unknown"

static func get_event_type_name(event_type: EventType) -> String:
	match event_type:
		EventType.SOLAR_FLARE: return "Solar Flare"
		EventType.COMPONENT_MALFUNCTION: return "Component Malfunction"
		EventType.MESSAGE_FROM_EARTH: return "Message from Earth"
		EventType.MICROMETEORITE: return "Micrometeorite Impact"
		EventType.CARGO_LOOSE: return "Cargo Loose"
		EventType.SECTION_BLOCKAGE: return "Section Blockage"
	return "Unknown"

# ============================================================================
# COMPUTED GETTERS
# ============================================================================

static func compute_resource_totals(state: Dictionary) -> Dictionary:
	var total_food = 0.0
	var max_food = 0.0
	var total_water = 0.0
	var max_water = 0.0

	for container in state.storage_containers:
		max_food += container.food_max
		max_water += container.water_max
		if container.accessible:
			total_food += container.food
			total_water += container.water

	var new_resources = state.resources.duplicate(true)
	new_resources.food.current = total_food
	new_resources.food.max = max_food
	new_resources.water.current = total_water
	new_resources.water.max = max_water

	return new_resources

static func get_accessible_containers(state: Dictionary) -> Array:
	var accessible = []
	for container in state.storage_containers:
		if container.accessible:
			accessible.append(container)
	return accessible

static func get_blocked_containers(state: Dictionary) -> Array:
	var blocked = []
	for container in state.storage_containers:
		if not container.accessible:
			blocked.append(container)
	return blocked

static func get_crew_by_role(state: Dictionary, role: CrewRole) -> Dictionary:
	for member in state.crew:
		if member.role == role:
			return member
	return {}

static func get_event_chance_for_day(day: int, total_days: int) -> float:
	if day < 10:
		return EARLY_EVENT_CHANCE
	elif day > total_days - 20:
		return FINAL_EVENT_CHANCE
	elif day > total_days / 2 - 5 and day < total_days / 2 + 5:
		return MIDPOINT_EVENT_CHANCE
	return BASE_EVENT_CHANCE

static func get_event_chance_for_hour(day: int, total_days: int) -> float:
	## Get hourly event chance based on current journey phase
	if day < 10:
		return EARLY_EVENT_CHANCE_PER_HOUR
	elif day > total_days - 20:
		return FINAL_EVENT_CHANCE_PER_HOUR
	elif day > total_days / 2 - 5 and day < total_days / 2 + 5:
		return MIDPOINT_EVENT_CHANCE_PER_HOUR
	return BASE_EVENT_CHANCE_PER_HOUR

static func hours_to_day_hour(total_hours: int) -> Dictionary:
	## Convert total hours to day and hour within day
	var day = (total_hours / HOURS_PER_DAY) + 1
	var hour = total_hours % HOURS_PER_DAY
	return {"day": day, "hour": hour}

static func day_hour_to_total_hours(day: int, hour: int) -> int:
	## Convert day + hour to total hours elapsed
	return (day - 1) * HOURS_PER_DAY + hour

static func is_game_over(state: Dictionary) -> bool:
	# All crew dead
	var alive_count = 0
	for member in state.crew:
		if member.health > 0:
			alive_count += 1
	if alive_count == 0:
		return true

	# Out of critical resources for too long could be added
	return false

static func has_arrived(state: Dictionary) -> bool:
	var total_hours = state.get("total_hours", 0)
	return total_hours >= TOTAL_TRAVEL_HOURS or state.current_day >= state.total_days
