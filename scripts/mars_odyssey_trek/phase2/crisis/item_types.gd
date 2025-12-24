extends RefCounted
class_name ItemTypes

## Item definitions for CRISIS mode fetch tasks
## Items are stored in Cargo Bay and consumed when used to fix crises

# ============================================================================
# ITEM TYPES
# ============================================================================

enum ItemType {
	PATCH_KIT,      # Seal hull breaches
	EXTINGUISHER,   # Suppress fires
	MED_KIT,        # Medical emergencies
	SANITIZER,      # Food contamination
	POWER_CELL,     # Power fluctuations (backup)
	SPARE_PART      # General equipment repairs
}

# ============================================================================
# ITEM DEFINITIONS
# ============================================================================

const ITEM_DEFINITIONS = {
	ItemType.PATCH_KIT: {
		"name": "Patch Kit",
		"short_name": "PKT",
		"color": Color(0.6, 0.6, 0.6),  # Gray
		"description": "Emergency hull patch materials"
	},
	ItemType.EXTINGUISHER: {
		"name": "Fire Extinguisher",
		"short_name": "EXT",
		"color": Color(0.9, 0.2, 0.2),  # Red
		"description": "CO2 fire suppression unit"
	},
	ItemType.MED_KIT: {
		"name": "Medical Kit",
		"short_name": "MED",
		"color": Color(0.9, 0.9, 0.9),  # White
		"description": "Emergency medical supplies"
	},
	ItemType.SANITIZER: {
		"name": "Sanitizer",
		"short_name": "SAN",
		"color": Color(0.3, 0.8, 0.3),  # Green
		"description": "Industrial-grade sanitizing agent"
	},
	ItemType.POWER_CELL: {
		"name": "Power Cell",
		"short_name": "PWR",
		"color": Color(0.9, 0.8, 0.2),  # Yellow
		"description": "Emergency backup power cell"
	},
	ItemType.SPARE_PART: {
		"name": "Spare Part",
		"short_name": "SPR",
		"color": Color(0.5, 0.4, 0.3),  # Brown
		"description": "Universal replacement component"
	}
}

# ============================================================================
# SPAWN QUANTITIES PER CRISIS TYPE
# ============================================================================

# Standard CRISIS encounter (45-60s, 8-12 crises)
const STANDARD_SPAWN = {
	ItemType.PATCH_KIT: 4,
	ItemType.EXTINGUISHER: 3,
	ItemType.MED_KIT: 3,
	ItemType.SANITIZER: 2,
	ItemType.POWER_CELL: 2,
	ItemType.SPARE_PART: 3
}

# Cascade CRISIS (60-90s, 12-18 crises)
const CASCADE_SPAWN = {
	ItemType.PATCH_KIT: 5,
	ItemType.EXTINGUISHER: 4,
	ItemType.MED_KIT: 4,
	ItemType.SANITIZER: 3,
	ItemType.POWER_CELL: 3,
	ItemType.SPARE_PART: 4
}

# Perfect Storm CRISIS (90-120s, 15-25 crises) - deliberately scarce
const STORM_SPAWN = {
	ItemType.PATCH_KIT: 4,
	ItemType.EXTINGUISHER: 3,
	ItemType.MED_KIT: 3,
	ItemType.SANITIZER: 2,
	ItemType.POWER_CELL: 2,
	ItemType.SPARE_PART: 3
}

# ============================================================================
# CRISIS → ITEM MAPPING
# ============================================================================

# Which item type fixes which crisis (from CrisisTypes.CrisisType)
const CRISIS_ITEM_REQUIREMENTS = {
	0: ItemType.SPARE_PART,      # O2_LEAK - needs spare parts
	1: ItemType.POWER_CELL,      # POWER_FLUCTUATION - needs power cell
	2: ItemType.SPARE_PART,      # WATER_RECYCLER - needs spare parts
	3: ItemType.PATCH_KIT,       # HULL_STRESS - needs patch kit
	4: ItemType.MED_KIT,         # MEDICAL_EMERGENCY - needs med kit
	5: -1,                       # NAVIGATION_DRIFT - station task, no item
	6: -1,                       # COMMS_FAILURE - station task, no item
	7: ItemType.EXTINGUISHER,    # FIRE - needs extinguisher
	8: ItemType.SPARE_PART,      # EQUIPMENT_FAULT - needs spare parts
	9: ItemType.SANITIZER        # FOOD_CONTAMINATION - needs sanitizer
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func get_item_name(item_type: ItemType) -> String:
	var def = ITEM_DEFINITIONS.get(item_type, {})
	return def.get("name", "Unknown Item")

static func get_item_short_name(item_type: ItemType) -> String:
	var def = ITEM_DEFINITIONS.get(item_type, {})
	return def.get("short_name", "???")

static func get_item_color(item_type: ItemType) -> Color:
	var def = ITEM_DEFINITIONS.get(item_type, {})
	return def.get("color", Color.WHITE)

static func requires_item(crisis_type: int) -> bool:
	## Check if a crisis type requires an item to fix
	var required = CRISIS_ITEM_REQUIREMENTS.get(crisis_type, -1)
	return required != -1

static func get_required_item(crisis_type: int) -> int:
	## Get the item type required to fix a crisis (-1 if none)
	return CRISIS_ITEM_REQUIREMENTS.get(crisis_type, -1)

static func get_spawn_quantities(crisis_type: String) -> Dictionary:
	## Get item spawn quantities for a crisis type
	match crisis_type:
		"standard": return STANDARD_SPAWN.duplicate()
		"cascade": return CASCADE_SPAWN.duplicate()
		"storm": return STORM_SPAWN.duplicate()
		_: return STANDARD_SPAWN.duplicate()

static func item_type_to_string(item_type: ItemType) -> String:
	## Convert item type enum to string for carrying
	match item_type:
		ItemType.PATCH_KIT: return "patch_kit"
		ItemType.EXTINGUISHER: return "extinguisher"
		ItemType.MED_KIT: return "med_kit"
		ItemType.SANITIZER: return "sanitizer"
		ItemType.POWER_CELL: return "power_cell"
		ItemType.SPARE_PART: return "spare_part"
		_: return "unknown"

static func string_to_item_type(item_string: String) -> ItemType:
	## Convert string back to item type enum
	match item_string:
		"patch_kit": return ItemType.PATCH_KIT
		"extinguisher": return ItemType.EXTINGUISHER
		"med_kit": return ItemType.MED_KIT
		"sanitizer": return ItemType.SANITIZER
		"power_cell": return ItemType.POWER_CELL
		"spare_part": return ItemType.SPARE_PART
		_: return ItemType.SPARE_PART
