extends RefCounted
class_name ShipTypes

## Ship Layout Types and Constants for MOT Phase 2 Visual Ship

# ============================================================================
# ROOM TYPES
# ============================================================================

enum RoomType {
	BRIDGE,
	ENGINEERING,
	LIFE_SUPPORT,
	MEDICAL,
	QUARTERS,
	CARGO_BAY,
	CORRIDOR
}

# Which crew role calls which room "home"
const CREW_HOME_ROOMS = {
	"commander": RoomType.BRIDGE,
	"engineer": RoomType.ENGINEERING,
	"scientist": RoomType.LIFE_SUPPORT,
	"medical": RoomType.MEDICAL
}

# ============================================================================
# CREW STATES
# ============================================================================

enum CrewState {
	IDLE,       # At home station, monitoring
	MOVING,     # Walking/running to destination
	WORKING,    # Performing task at location
	RESTING,    # In quarters recovering
	EMERGENCY   # Responding to crisis (running)
}

# ============================================================================
# TASK TYPES
# ============================================================================

enum TaskType {
	MONITOR,        # Passive monitoring at station
	REPAIR,         # Fix damaged system
	SEAL_BREACH,    # Emergency hull breach
	REROUTE_POWER,  # Power system work
	TREAT_PATIENT,  # Medical care
	REST,           # Recover fatigue
	RETRIEVE_SUPPLIES  # Get supplies from cargo
}

# Task durations in seconds (game time)
const TASK_DURATIONS = {
	TaskType.MONITOR: -1,  # Continuous
	TaskType.REPAIR: 30.0,
	TaskType.SEAL_BREACH: 45.0,
	TaskType.REROUTE_POWER: 20.0,
	TaskType.TREAT_PATIENT: 25.0,
	TaskType.REST: 60.0,
	TaskType.RETRIEVE_SUPPLIES: 15.0
}

# ============================================================================
# MOVEMENT
# ============================================================================

const CREW_WALK_SPEED = 50.0   # pixels/second normal
const CREW_RUN_SPEED = 120.0   # pixels/second emergency

# ============================================================================
# ROOM DEFINITIONS
# ============================================================================

static func get_room_name(room_type: RoomType) -> String:
	match room_type:
		RoomType.BRIDGE: return "Bridge"
		RoomType.ENGINEERING: return "Engineering"
		RoomType.LIFE_SUPPORT: return "Life Support"
		RoomType.MEDICAL: return "Medical Bay"
		RoomType.QUARTERS: return "Crew Quarters"
		RoomType.CARGO_BAY: return "Cargo Bay"
		RoomType.CORRIDOR: return "Corridor"
		_: return "Unknown"

static func get_room_color(room_type: RoomType) -> Color:
	match room_type:
		RoomType.BRIDGE: return Color(0.3, 0.4, 0.6)        # Blue-ish
		RoomType.ENGINEERING: return Color(0.5, 0.4, 0.3)   # Brown-ish
		RoomType.LIFE_SUPPORT: return Color(0.3, 0.5, 0.4)  # Teal-ish
		RoomType.MEDICAL: return Color(0.5, 0.5, 0.5)       # White-ish
		RoomType.QUARTERS: return Color(0.4, 0.35, 0.45)    # Purple-ish
		RoomType.CARGO_BAY: return Color(0.4, 0.4, 0.35)    # Tan
		RoomType.CORRIDOR: return Color(0.25, 0.25, 0.3)    # Dark gray
		_: return Color(0.3, 0.3, 0.3)

# ============================================================================
# CREW COLORS
# ============================================================================

const CREW_COLORS = {
	"commander": Color(0.2, 0.4, 0.8),  # Blue
	"engineer": Color(0.8, 0.5, 0.2),   # Orange
	"scientist": Color(0.3, 0.7, 0.4),  # Green
	"medical": Color(0.8, 0.3, 0.3)     # Red
}

static func get_crew_color(role: String) -> Color:
	return CREW_COLORS.get(role, Color.WHITE)

# ============================================================================
# PHASE 2 INTEGRATION MAPPINGS
# ============================================================================

# Map P2 storage container IDs to visual rooms
const CONTAINER_TO_ROOM = {
	"cargo_a": RoomType.CARGO_BAY,      # Forward cargo → main cargo bay
	"cargo_b": RoomType.QUARTERS,       # Midship → quarters (secondary storage)
	"cargo_c": RoomType.ENGINEERING,    # Aft → engineering (secondary storage)
	"emergency": RoomType.MEDICAL       # Emergency hab → medical bay
}

# Map P2 crew role names to visual role IDs
const P2_ROLE_TO_VISUAL = {
	"Commander": "commander",
	"Engineer": "engineer",
	"Scientist": "scientist",
	"Medical": "medical"
}

# Reverse mapping: visual role ID to P2 role name
const VISUAL_TO_P2_ROLE = {
	"commander": "Commander",
	"engineer": "Engineer",
	"scientist": "Scientist",
	"medical": "Medical"
}

# Which crew role should respond to which room's emergencies
const ROOM_EMERGENCY_RESPONDER = {
	RoomType.BRIDGE: "commander",
	RoomType.ENGINEERING: "engineer",
	RoomType.LIFE_SUPPORT: "engineer",
	RoomType.MEDICAL: "medical",
	RoomType.QUARTERS: "commander",
	RoomType.CARGO_BAY: "scientist",
	RoomType.CORRIDOR: "engineer"
}

static func get_room_for_container(container_id: String) -> RoomType:
	return CONTAINER_TO_ROOM.get(container_id, RoomType.CARGO_BAY)

static func get_visual_role(p2_role: String) -> String:
	return P2_ROLE_TO_VISUAL.get(p2_role, "engineer")

static func get_emergency_responder(room_type: RoomType) -> String:
	return ROOM_EMERGENCY_RESPONDER.get(room_type, "engineer")
