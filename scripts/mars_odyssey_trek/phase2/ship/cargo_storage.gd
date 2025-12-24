extends Node
class_name CargoStorage

## Manages item inventory in the Cargo Bay for CRISIS mode
## Items are spawned at CRISIS start and consumed when used

const ItemTypes = preload("res://scripts/mars_odyssey_trek/phase2/crisis/item_types.gd")
const TileGrid = preload("res://scripts/mars_odyssey_trek/phase2/crisis/tile_grid.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal item_taken(item_type: ItemTypes.ItemType, remaining: int)
signal item_returned(item_type: ItemTypes.ItemType, total: int)
signal storage_depleted(item_type: ItemTypes.ItemType)
signal storage_initialized(quantities: Dictionary)

# ============================================================================
# STATE
# ============================================================================

var inventory: Dictionary = {}  # ItemType -> count
var item_positions: Dictionary = {}  # ItemType -> tile position for pickup

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_item_positions()

func _setup_item_positions() -> void:
	## Assign storage tiles to item types
	## Based on TileGrid.STORAGE_TILES layout
	item_positions = {
		ItemTypes.ItemType.PATCH_KIT: Vector2i(1, 8),
		ItemTypes.ItemType.EXTINGUISHER: Vector2i(1, 9),
		ItemTypes.ItemType.MED_KIT: Vector2i(1, 10),
		ItemTypes.ItemType.SANITIZER: Vector2i(2, 10),
		ItemTypes.ItemType.POWER_CELL: Vector2i(2, 8),
		ItemTypes.ItemType.SPARE_PART: Vector2i(2, 9)
	}

func initialize_for_crisis(crisis_type: String = "standard") -> void:
	## Set up inventory for a CRISIS encounter
	var quantities = ItemTypes.get_spawn_quantities(crisis_type)
	inventory.clear()

	for item_type in quantities:
		inventory[item_type] = quantities[item_type]

	storage_initialized.emit(inventory.duplicate())
	print("[CARGO] Initialized storage for %s crisis: %s" % [crisis_type, inventory])

func clear_storage() -> void:
	## Clear all items (end of CRISIS)
	inventory.clear()

# ============================================================================
# ITEM OPERATIONS
# ============================================================================

func take_item(item_type: ItemTypes.ItemType) -> bool:
	## Remove one item from storage
	## Returns true if successful, false if none available

	var count = inventory.get(item_type, 0)
	if count <= 0:
		return false

	inventory[item_type] = count - 1
	item_taken.emit(item_type, inventory[item_type])

	if inventory[item_type] == 0:
		storage_depleted.emit(item_type)
		print("[CARGO] DEPLETED: %s" % ItemTypes.get_item_name(item_type))

	return true

func return_item(item_type: ItemTypes.ItemType) -> void:
	## Return an item to storage (if task was cancelled)
	var count = inventory.get(item_type, 0)
	inventory[item_type] = count + 1
	item_returned.emit(item_type, inventory[item_type])

func has_item(item_type: ItemTypes.ItemType) -> bool:
	return inventory.get(item_type, 0) > 0

func get_count(item_type: ItemTypes.ItemType) -> int:
	return inventory.get(item_type, 0)

func get_all_counts() -> Dictionary:
	return inventory.duplicate()

# ============================================================================
# POSITION HELPERS
# ============================================================================

func get_item_tile(item_type: ItemTypes.ItemType) -> Vector2i:
	## Get the tile position where this item type is stored
	return item_positions.get(item_type, Vector2i(1, 9))

func get_item_world_position(item_type: ItemTypes.ItemType) -> Vector2:
	## Get world position for item pickup
	var tile = get_item_tile(item_type)
	return TileGrid.tile_to_world(tile)

func get_any_available_item_for_crisis(crisis_type: int) -> int:
	## Get an available item type that can fix the given crisis
	## Returns -1 if no suitable item available

	var required = ItemTypes.get_required_item(crisis_type)
	if required == -1:
		return -1  # Crisis doesn't need an item

	if has_item(required):
		return required

	return -1  # Required item not available

# ============================================================================
# QUERIES
# ============================================================================

func get_total_items() -> int:
	var total = 0
	for item_type in inventory:
		total += inventory[item_type]
	return total

func get_depleted_items() -> Array:
	## Get list of item types that have run out
	var depleted = []
	for item_type in inventory:
		if inventory[item_type] == 0:
			depleted.append(item_type)
	return depleted

func get_low_items(threshold: int = 1) -> Array:
	## Get list of item types below threshold
	var low = []
	for item_type in inventory:
		if inventory[item_type] <= threshold:
			low.append(item_type)
	return low

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_inventory() -> void:
	print("=== CARGO INVENTORY ===")
	for item_type in inventory:
		var name = ItemTypes.get_item_name(item_type)
		var count = inventory[item_type]
		print("  %s: %d" % [name, count])
	print("=======================")

func debug_add_items(item_type: ItemTypes.ItemType, count: int) -> void:
	## Debug: Add items to storage
	var current = inventory.get(item_type, 0)
	inventory[item_type] = current + count
