extends Control
class_name ApproachSelector

## Construction Approach Selector for MOT Phase 1
## Lets player choose: Earth-Built, Orbital Assembly, or Lunar Shipyard

signal approach_selected(approach: int)

# ============================================================================
# STATE
# ============================================================================

var selected_approach: int = -1
var store: MOTStore = null

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var title_label: Label = %TitleLabel
@onready var layman_label: Label = %LaymanLabel
@onready var power_user_label: Label = %PowerUserLabel
@onready var stats_label: Label = %StatsLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_create_approach_cards()
	_update_details_panel()

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	var approach = state.get("construction_approach")
	if approach != null:
		_select_approach(approach, false)

# ============================================================================
# CARD CREATION
# ============================================================================

func _create_approach_cards() -> void:
	if not cards_container:
		return

	# Clear existing
	for child in cards_container.get_children():
		child.queue_free()

	# Create card for each approach
	for approach in MOTTypes.ConstructionApproach.values():
		var card = _create_card(approach)
		cards_container.add_child(card)

func _create_card(approach: int) -> PanelContainer:
	var data = MOTTypes.CONSTRUCTION_APPROACHES[approach]

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 200)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Title
	var title = Label.new()
	title.text = data.name
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = data.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	content.add_child(desc)

	# Quick stats
	var stats = Label.new()
	var reliability_pct = int(data.reliability * 100)
	var fuel_str = ""
	if data.fuel_multiplier > 1.0:
		fuel_str = "+%d%% fuel" % int((data.fuel_multiplier - 1.0) * 100)
	elif data.fuel_multiplier < 1.0:
		fuel_str = "-%d%% fuel" % int((1.0 - data.fuel_multiplier) * 100)
	else:
		fuel_str = "Normal fuel"

	stats.text = "%d%% reliability | %s" % [reliability_pct, fuel_str]
	stats.add_theme_font_size_override("font_size", 12)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	content.add_child(stats)

	margin.add_child(content)
	vbox.add_child(margin)

	# Select button
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(func(): _select_approach(approach))
	vbox.add_child(button)

	# Store reference for highlighting
	card.set_meta("approach", approach)
	card.set_meta("button", button)

	return card

# ============================================================================
# SELECTION
# ============================================================================

func _select_approach(approach: int, emit: bool = true) -> void:
	selected_approach = approach
	_update_card_highlights()
	_update_details_panel()

	if emit:
		approach_selected.emit(approach)

func _update_card_highlights() -> void:
	if not cards_container:
		return

	for card in cards_container.get_children():
		if not card is PanelContainer:
			continue

		var card_approach = card.get_meta("approach", -1)
		var button = card.get_meta("button") as Button

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(8)

		if card_approach == selected_approach:
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
	if selected_approach < 0:
		_show_prompt()
		return

	var data = MOTTypes.CONSTRUCTION_APPROACHES[selected_approach]

	if title_label:
		title_label.text = data.name

	if layman_label:
		layman_label.text = data.layman

	if power_user_label:
		power_user_label.text = data.power_user

	if stats_label:
		var text = ""
		text += "Reliability: %d%%\n" % int(data.reliability * 100)
		text += "Fuel Multiplier: %.1fx\n" % data.fuel_multiplier
		text += "Cost Multiplier: %.1fx\n" % data.cost_multiplier
		text += "Prep Time: %d days" % data.prep_days
		stats_label.text = text

func _show_prompt() -> void:
	if title_label:
		title_label.text = "Choose Construction Approach"

	if layman_label:
		layman_label.text = "Where will your ship be built?"

	if power_user_label:
		power_user_label.text = "Each approach has different mass penalties and assembly reliability."

	if stats_label:
		stats_label.text = "Select an option to see details"
