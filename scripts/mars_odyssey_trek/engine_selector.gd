extends Control
class_name EngineSelector

## Engine Selector for MOT Phase 1
## Choose: Chemical, Ion Drive, Nuclear Thermal, or Solar Sail

signal engine_selected(engine: int)

# ============================================================================
# STATE
# ============================================================================

var selected_engine: int = -1
var store: MOTStore = null

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var title_label: Label = %TitleLabel
@onready var nickname_label: Label = %NicknameLabel
@onready var layman_label: Label = %LaymanLabel
@onready var power_user_label: Label = %PowerUserLabel
@onready var stats_label: Label = %StatsLabel
@onready var warning_label: Label = %WarningLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_create_engine_cards()
	_update_details_panel()

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	var engine = state.get("engine")
	if engine != null:
		_select_engine(engine, false)

# ============================================================================
# CARD CREATION
# ============================================================================

func _create_engine_cards() -> void:
	if not cards_container:
		return

	for child in cards_container.get_children():
		child.queue_free()

	for engine in MOTTypes.EngineType.values():
		var card = _create_card(engine)
		cards_container.add_child(card)

func _create_card(engine: int) -> PanelContainer:
	var data = MOTTypes.ENGINES[engine]

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 220)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	# Name
	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	# Nickname
	var nick = Label.new()
	nick.text = "\"%s\"" % data.nickname
	nick.add_theme_font_size_override("font_size", 11)
	nick.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	nick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(nick)

	# Description
	var desc = Label.new()
	desc.text = data.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc.add_theme_font_size_override("font_size", 12)
	content.add_child(desc)

	# Cost
	var cost = Label.new()
	cost.text = "$%dM" % (data.cost / 1000000)
	cost.add_theme_font_size_override("font_size", 14)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	content.add_child(cost)

	# Risk indicator
	var risk_color = _get_risk_color(data.risk)
	var risk = Label.new()
	risk.text = "Risk: %d%%" % int(data.risk * 100)
	risk.add_theme_font_size_override("font_size", 11)
	risk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	risk.add_theme_color_override("font_color", risk_color)
	content.add_child(risk)

	margin.add_child(content)
	vbox.add_child(margin)

	# Select button
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 35)
	button.pressed.connect(func(): _select_engine(engine))
	vbox.add_child(button)

	card.set_meta("engine", engine)
	card.set_meta("button", button)

	return card

func _get_risk_color(risk: float) -> Color:
	if risk <= 0.15:
		return Color(0.4, 0.8, 0.4)  # Low - green
	elif risk <= 0.25:
		return Color(0.8, 0.8, 0.3)  # Medium - yellow
	else:
		return Color(0.9, 0.4, 0.3)  # High - red

# ============================================================================
# SELECTION
# ============================================================================

func _select_engine(engine: int, emit: bool = true) -> void:
	selected_engine = engine
	_update_card_highlights()
	_update_details_panel()

	if emit:
		engine_selected.emit(engine)

func _update_card_highlights() -> void:
	if not cards_container:
		return

	for card in cards_container.get_children():
		if not card is PanelContainer:
			continue

		var card_engine = card.get_meta("engine", -1)
		var button = card.get_meta("button") as Button

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(8)

		if card_engine == selected_engine:
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
	if selected_engine < 0:
		_show_prompt()
		return

	var data = MOTTypes.ENGINES[selected_engine]

	if title_label:
		title_label.text = data.name

	if nickname_label:
		nickname_label.text = "\"%s\"" % data.nickname

	if layman_label:
		layman_label.text = data.layman

	if power_user_label:
		power_user_label.text = data.power_user

	if stats_label:
		var text = ""
		text += "Cost: $%dM\n" % (data.cost / 1000000)
		text += "Travel Time: %.0f%% baseline\n" % (data.travel_time_modifier * 100)
		text += "Fuel Efficiency: %.0f%%\n" % (data.fuel_efficiency * 100)
		text += "Risk Factor: %d%%" % int(data.risk * 100)
		stats_label.text = text

	if warning_label:
		var warnings = []
		if data.get("requires_space_assembly", false):
			warnings.append("Requires orbital or lunar assembly")
		if data.get("has_radiation_risk", false):
			warnings.append("Radiation shielding recommended")
		if data.get("no_fuel", false):
			warnings.append("Slowest option but no fuel needed")

		if warnings.size() > 0:
			warning_label.text = "Note: " + ", ".join(warnings)
			warning_label.visible = true
		else:
			warning_label.visible = false

func _show_prompt() -> void:
	if title_label:
		title_label.text = "Choose Your Engine"

	if nickname_label:
		nickname_label.text = ""

	if layman_label:
		layman_label.text = "What powers your journey to Mars?"

	if power_user_label:
		power_user_label.text = "Each engine has different specific impulse (Isp), thrust, and risk profiles."

	if stats_label:
		stats_label.text = "Select an option to see details"

	if warning_label:
		warning_label.visible = false
