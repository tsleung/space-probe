extends Control
class_name ShipClassSelector

## Ship Class + Upgrades Selector for MOT Phase 1
## Choose: Capsule, Standard, or Cruiser + Optional Upgrades

signal ship_class_selected(ship_class: int)
signal upgrade_toggled(upgrade_id: String, enabled: bool)

# ============================================================================
# STATE
# ============================================================================

var selected_class: int = -1
var selected_upgrades: Array = []
var store: MOTStore = null

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var class_cards: HBoxContainer = %ClassCards
@onready var upgrades_container: GridContainer = %UpgradesContainer
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var title_label: Label = %TitleLabel
@onready var layman_label: Label = %LaymanLabel
@onready var stats_label: Label = %StatsLabel
@onready var cargo_label: Label = %CargoLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_create_class_cards()
	_create_upgrade_checkboxes()
	_update_details_panel()

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	var ship_class = state.get("ship_class")
	if ship_class != null:
		_select_class(ship_class, false)

	var upgrades = state.get("upgrades", [])
	for upgrade_id in upgrades:
		if not upgrade_id in selected_upgrades:
			selected_upgrades.append(upgrade_id)
	_update_upgrade_checkboxes()

# ============================================================================
# CLASS CARDS
# ============================================================================

func _create_class_cards() -> void:
	if not class_cards:
		return

	for child in class_cards.get_children():
		child.queue_free()

	for ship_class in MOTTypes.ShipClass.values():
		var card = _create_class_card(ship_class)
		class_cards.add_child(card)

func _create_class_card(ship_class: int) -> PanelContainer:
	var data = MOTTypes.SHIP_CLASSES[ship_class]

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	# Name
	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	# Description
	var desc = Label.new()
	desc.text = data.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc.add_theme_font_size_override("font_size", 12)
	content.add_child(desc)

	# Cargo capacity
	var cargo = Label.new()
	cargo.text = "%d kg cargo" % data.cargo_capacity
	cargo.add_theme_font_size_override("font_size", 14)
	cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	content.add_child(cargo)

	# Cost
	var cost = Label.new()
	cost.text = "$%dM" % (data.cost / 1000000)
	cost.add_theme_font_size_override("font_size", 14)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	content.add_child(cost)

	margin.add_child(content)
	vbox.add_child(margin)

	# Select button
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 35)
	button.pressed.connect(func(): _select_class(ship_class))
	vbox.add_child(button)

	card.set_meta("ship_class", ship_class)
	card.set_meta("button", button)

	return card

# ============================================================================
# UPGRADES
# ============================================================================

func _create_upgrade_checkboxes() -> void:
	if not upgrades_container:
		return

	for child in upgrades_container.get_children():
		child.queue_free()

	upgrades_container.columns = 2

	for upgrade_id in MOTTypes.SHIP_UPGRADES:
		var upgrade = MOTTypes.SHIP_UPGRADES[upgrade_id]
		var checkbox = _create_upgrade_checkbox(upgrade_id, upgrade)
		upgrades_container.add_child(checkbox)

func _create_upgrade_checkbox(upgrade_id: String, data: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	var check = CheckBox.new()
	check.text = ""
	check.toggled.connect(func(pressed): _on_upgrade_toggled(upgrade_id, pressed))
	check.set_meta("upgrade_id", upgrade_id)
	container.add_child(check)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = "%s ($%dM)" % [data.name, data.cost / 1000000]
	name_label.add_theme_font_size_override("font_size", 13)
	info.add_child(name_label)

	var desc = Label.new()
	desc.text = data.description
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(desc)

	container.add_child(info)
	container.set_meta("checkbox", check)

	return container

func _update_upgrade_checkboxes() -> void:
	if not upgrades_container:
		return

	for container in upgrades_container.get_children():
		var check = container.get_meta("checkbox") as CheckBox
		if check:
			var upgrade_id = check.get_meta("upgrade_id", "")
			check.set_pressed_no_signal(upgrade_id in selected_upgrades)

func _on_upgrade_toggled(upgrade_id: String, pressed: bool) -> void:
	if pressed:
		if not upgrade_id in selected_upgrades:
			selected_upgrades.append(upgrade_id)
	else:
		selected_upgrades.erase(upgrade_id)

	_update_details_panel()
	upgrade_toggled.emit(upgrade_id, pressed)

# ============================================================================
# SELECTION
# ============================================================================

func _select_class(ship_class: int, emit: bool = true) -> void:
	selected_class = ship_class
	_update_class_highlights()
	_update_details_panel()

	if emit:
		ship_class_selected.emit(ship_class)

func _update_class_highlights() -> void:
	if not class_cards:
		return

	for card in class_cards.get_children():
		if not card is PanelContainer:
			continue

		var card_class = card.get_meta("ship_class", -1)
		var button = card.get_meta("button") as Button

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(8)

		if card_class == selected_class:
			style.bg_color = Color(0.15, 0.25, 0.35)
			style.border_color = Color(0.3, 0.6, 1.0)
			style.set_border_width_all(3)
			if button:
				button.text = "SELECTED"
				button.disabled = true
		else:
			style.bg_color = Color(0.12, 0.12, 0.15)
			style.border_color = Color(0.3, 0.3, 0.35)
			style.set_border_width_all(1)
			if button:
				button.text = "SELECT"
				button.disabled = false

		card.add_theme_stylebox_override("panel", style)

# ============================================================================
# DETAILS PANEL
# ============================================================================

func _update_details_panel() -> void:
	if selected_class < 0:
		_show_prompt()
		return

	var data = MOTTypes.SHIP_CLASSES[selected_class]

	if title_label:
		title_label.text = data.name + " Class"

	if layman_label:
		layman_label.text = data.layman

	# Calculate total cargo with upgrades
	var base_cargo = data.cargo_capacity
	var bonus_cargo = 0
	for upgrade_id in selected_upgrades:
		if MOTTypes.SHIP_UPGRADES.has(upgrade_id):
			var upgrade = MOTTypes.SHIP_UPGRADES[upgrade_id]
			if upgrade.effects.has("cargo_bonus"):
				bonus_cargo += upgrade.effects.cargo_bonus

	if cargo_label:
		if bonus_cargo > 0:
			cargo_label.text = "Cargo: %d kg (+%d from upgrades)" % [base_cargo + bonus_cargo, bonus_cargo]
		else:
			cargo_label.text = "Cargo Capacity: %d kg" % base_cargo

	if stats_label:
		var text = ""
		text += "Base Cost: $%dM\n" % (data.cost / 1000000)
		text += "Crew Comfort: %.0f%%\n" % (data.crew_comfort * 100)
		text += "Durability: %.0f%%\n" % (data.durability * 100)

		if selected_upgrades.size() > 0:
			var upgrade_cost = 0
			for upgrade_id in selected_upgrades:
				if MOTTypes.SHIP_UPGRADES.has(upgrade_id):
					upgrade_cost += MOTTypes.SHIP_UPGRADES[upgrade_id].cost
			text += "\nUpgrades: +$%dM" % (upgrade_cost / 1000000)

		stats_label.text = text

func _show_prompt() -> void:
	if title_label:
		title_label.text = "Choose Ship Class"

	if layman_label:
		layman_label.text = "How much room do you need for the journey?"

	if cargo_label:
		cargo_label.text = "Cargo capacity affects how many supplies you can bring"

	if stats_label:
		stats_label.text = "Select a class to see details"
