extends Control
class_name LifeSupportSelector

## Life Support Tier Selector for MOT Phase 1
## Choose: Basic, Standard, or Redundant life support systems

signal tier_selected(tier: int)

# ============================================================================
# STATE
# ============================================================================

var selected_tier: int = -1
var store: MOTStore = null

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var stats_label: Label = %StatsLabel
@onready var warning_label: Label = %WarningLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_create_tier_cards()
	_update_details_panel()

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	var tier = state.get("life_support")
	if tier != null:
		_select_tier(tier, false)

# ============================================================================
# CARD CREATION
# ============================================================================

func _create_tier_cards() -> void:
	if not cards_container:
		return

	for child in cards_container.get_children():
		child.queue_free()

	for tier in MOTTypes.LifeSupportTier.values():
		var card = _create_card(tier)
		cards_container.add_child(card)

func _create_card(tier: int) -> PanelContainer:
	var data = MOTTypes.LIFE_SUPPORT_TIERS[tier]

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 200)
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
	content.add_theme_constant_override("separation", 10)

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
	desc.add_theme_font_size_override("font_size", 13)
	content.add_child(desc)

	# Recycling efficiency
	var recycle = Label.new()
	recycle.text = "%d%% recycling" % int(data.recycling_efficiency * 100)
	recycle.add_theme_font_size_override("font_size", 14)
	recycle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
	content.add_child(recycle)

	# Failure risk
	var risk_color = _get_risk_color(data.failure_risk)
	var risk = Label.new()
	risk.text = "%d%% failure risk" % int(data.failure_risk * 100)
	risk.add_theme_font_size_override("font_size", 13)
	risk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	risk.add_theme_color_override("font_color", risk_color)
	content.add_child(risk)

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
	button.pressed.connect(func(): _select_tier(tier))
	vbox.add_child(button)

	card.set_meta("tier", tier)
	card.set_meta("button", button)

	return card

func _get_risk_color(risk: float) -> Color:
	if risk <= 0.05:
		return Color(0.4, 0.8, 0.4)  # Low - green
	elif risk <= 0.1:
		return Color(0.8, 0.8, 0.3)  # Medium - yellow
	else:
		return Color(0.9, 0.5, 0.3)  # High - orange

# ============================================================================
# SELECTION
# ============================================================================

func _select_tier(tier: int, emit: bool = true) -> void:
	selected_tier = tier
	_update_card_highlights()
	_update_details_panel()

	if emit:
		tier_selected.emit(tier)

func _update_card_highlights() -> void:
	if not cards_container:
		return

	for card in cards_container.get_children():
		if not card is PanelContainer:
			continue

		var card_tier = card.get_meta("tier", -1)
		var button = card.get_meta("button") as Button

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(8)

		if card_tier == selected_tier:
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
	if selected_tier < 0:
		_show_prompt()
		return

	var data = MOTTypes.LIFE_SUPPORT_TIERS[selected_tier]

	if title_label:
		title_label.text = data.name + " Life Support"

	if description_label:
		var desc_text = data.description
		desc_text += "\n\nRecycling efficiency determines how much water and air can be recovered. "
		desc_text += "Higher efficiency means less supplies needed."
		description_label.text = desc_text

	if stats_label:
		var text = ""
		text += "Cost: $%dM\n" % (data.cost / 1000000)
		text += "Recycling: %d%%\n" % int(data.recycling_efficiency * 100)
		text += "Failure Risk: %d%%\n" % int(data.failure_risk * 100)
		text += "System Mass: %d kg" % data.mass
		stats_label.text = text

	if warning_label:
		match selected_tier:
			MOTTypes.LifeSupportTier.BASIC:
				warning_label.text = "Warning: Single point of failure. Any malfunction could be fatal."
				warning_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
				warning_label.visible = true
			MOTTypes.LifeSupportTier.STANDARD:
				warning_label.text = "Manual backup available. Crew can survive system failure with effort."
				warning_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
				warning_label.visible = true
			MOTTypes.LifeSupportTier.REDUNDANT:
				warning_label.text = "Triple redundancy. Can lose two systems and still survive."
				warning_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
				warning_label.visible = true
			_:
				warning_label.visible = false

func _show_prompt() -> void:
	if title_label:
		title_label.text = "Choose Life Support Tier"

	if description_label:
		description_label.text = "Life support keeps your crew alive during the journey.\n\nHigher tiers cost more but provide better recycling efficiency and system redundancy."

	if stats_label:
		stats_label.text = "Select an option to see details"

	if warning_label:
		warning_label.visible = false
