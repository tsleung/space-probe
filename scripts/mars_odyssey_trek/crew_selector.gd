extends Control
class_name CrewSelector

## Crew Selector for MOT Phase 1
## Pick 4 crew members from the roster

signal crew_changed(crew_ids: Array)

# ============================================================================
# STATE
# ============================================================================

var crew_roster: Array = []
var selected_crew: Array = []  # Array of crew IDs
var store: MOTStore = null
const MAX_CREW = 4

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var roster_grid: GridContainer = %RosterGrid
@onready var selected_panel: HBoxContainer = %SelectedPanel
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var crew_count_label: Label = %CrewCountLabel
@onready var detail_name: Label = %DetailName
@onready var detail_role: Label = %DetailRole
@onready var detail_background: Label = %DetailBackground
@onready var detail_trait: Label = %DetailTrait
@onready var detail_stats: Label = %DetailStats

var hovered_crew: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_crew_roster()
	_create_roster_ui()
	_update_selected_display()
	_update_details_panel()

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	var crew = state.get("crew", [])
	selected_crew = crew.duplicate()
	_update_roster_highlights()
	_update_selected_display()

# ============================================================================
# DATA LOADING
# ============================================================================

func _load_crew_roster() -> void:
	var file = FileAccess.open("res://data/games/mars_odyssey_trek/crew_roster.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			crew_roster = json.data
		file.close()

# ============================================================================
# ROSTER UI
# ============================================================================

func _create_roster_ui() -> void:
	if not roster_grid:
		return

	for child in roster_grid.get_children():
		child.queue_free()

	roster_grid.columns = 5

	for crew in crew_roster:
		var card = _create_crew_card(crew)
		roster_grid.add_child(card)

func _create_crew_card(crew: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 140)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)

	# Name
	var name_label = Label.new()
	name_label.text = crew.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)

	# Role
	var role_label = Label.new()
	role_label.text = crew.role.capitalize()
	role_label.add_theme_font_size_override("font_size", 11)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_color_override("font_color", _get_role_color(crew.role))
	content.add_child(role_label)

	# Nationality
	var nat_label = Label.new()
	nat_label.text = crew.nationality
	nat_label.add_theme_font_size_override("font_size", 10)
	nat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nat_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content.add_child(nat_label)

	# Key trait
	if crew.traits.size() > 0:
		var trait_label = Label.new()
		trait_label.text = crew.traits[0].name
		trait_label.add_theme_font_size_override("font_size", 10)
		trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trait_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		content.add_child(trait_label)

	margin.add_child(content)
	vbox.add_child(margin)

	# Button
	var button = Button.new()
	button.text = "ADD"
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(func(): _toggle_crew(crew.id))
	vbox.add_child(button)

	# Hover handling
	card.mouse_entered.connect(func(): _on_card_hover(crew))
	card.mouse_exited.connect(func(): _on_card_unhover())

	card.set_meta("crew_id", crew.id)
	card.set_meta("button", button)

	return card

func _get_role_color(role: String) -> Color:
	match role:
		"commander":
			return Color(0.9, 0.7, 0.3)
		"pilot":
			return Color(0.4, 0.7, 0.9)
		"engineer":
			return Color(0.9, 0.5, 0.3)
		"scientist":
			return Color(0.5, 0.9, 0.5)
		"medic":
			return Color(0.9, 0.4, 0.5)
		_:
			return Color(0.7, 0.7, 0.7)

# ============================================================================
# SELECTION
# ============================================================================

func _toggle_crew(crew_id: String) -> void:
	if crew_id in selected_crew:
		# Remove
		selected_crew.erase(crew_id)
	else:
		# Add if room
		if selected_crew.size() < MAX_CREW:
			selected_crew.append(crew_id)
		else:
			return  # Can't add more

	_update_roster_highlights()
	_update_selected_display()
	crew_changed.emit(selected_crew.duplicate())

func _update_roster_highlights() -> void:
	if not roster_grid:
		return

	for card in roster_grid.get_children():
		if not card is PanelContainer:
			continue

		var crew_id = card.get_meta("crew_id", "")
		var button = card.get_meta("button") as Button
		var is_selected = crew_id in selected_crew

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)

		if is_selected:
			style.bg_color = Color(0.15, 0.3, 0.2)
			style.border_color = Color(0.3, 0.8, 0.4)
			style.set_border_width_all(2)
			if button:
				button.text = "REMOVE"
		else:
			style.bg_color = Color(0.1, 0.1, 0.13)
			style.border_color = Color(0.25, 0.25, 0.3)
			style.set_border_width_all(1)
			if button:
				if selected_crew.size() >= MAX_CREW:
					button.text = "FULL"
					button.disabled = true
				else:
					button.text = "ADD"
					button.disabled = false

		card.add_theme_stylebox_override("panel", style)

# ============================================================================
# SELECTED DISPLAY
# ============================================================================

func _update_selected_display() -> void:
	if crew_count_label:
		crew_count_label.text = "Crew: %d / %d" % [selected_crew.size(), MAX_CREW]
		if selected_crew.size() >= MAX_CREW:
			crew_count_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		elif selected_crew.size() == 0:
			crew_count_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		else:
			crew_count_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))

	if not selected_panel:
		return

	for child in selected_panel.get_children():
		child.queue_free()

	for crew_id in selected_crew:
		var crew = _get_crew_by_id(crew_id)
		if crew:
			var slot = _create_selected_slot(crew)
			selected_panel.add_child(slot)

	# Add empty slots
	for i in range(selected_crew.size(), MAX_CREW):
		var empty = _create_empty_slot()
		selected_panel.add_child(empty)

func _create_selected_slot(crew: Dictionary) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(120, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.2, 0.15)
	style.border_color = _get_role_color(crew.role)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_lbl = Label.new()
	name_lbl.text = crew.name.split(" ")[-1]  # Just last name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = crew.role.capitalize()
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", _get_role_color(crew.role))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(role_lbl)

	slot.add_child(vbox)

	# Click to remove
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_crew(crew.id)
	)
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return slot

func _create_empty_slot() -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(120, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.2, 0.2, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "Empty"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)

	return slot

# ============================================================================
# DETAILS PANEL
# ============================================================================

func _on_card_hover(crew: Dictionary) -> void:
	hovered_crew = crew
	_update_details_panel()

func _on_card_unhover() -> void:
	hovered_crew = {}
	_update_details_panel()

func _update_details_panel() -> void:
	if hovered_crew.is_empty():
		_show_prompt()
		return

	if detail_name:
		detail_name.text = hovered_crew.name

	if detail_role:
		detail_role.text = "%s | %s | Age %d" % [
			hovered_crew.role.capitalize(),
			hovered_crew.nationality,
			hovered_crew.age
		]

	if detail_background:
		detail_background.text = hovered_crew.background.short

	if detail_trait:
		if hovered_crew.traits.size() > 0:
			var trait_data = hovered_crew.traits[0]
			detail_trait.text = "%s: %s" % [trait_data.name, trait_data.description]
		else:
			detail_trait.text = ""

	if detail_stats:
		var stats = hovered_crew.stats
		var text = ""
		text += "Piloting: %d | " % stats.piloting
		text += "Engineering: %d | " % stats.engineering
		text += "Science: %d | " % stats.science
		text += "Medical: %d | " % stats.medical
		text += "Leadership: %d" % stats.leadership
		detail_stats.text = text

func _show_prompt() -> void:
	if detail_name:
		detail_name.text = "Select Your Crew"

	if detail_role:
		detail_role.text = "Pick 4 crew members for the mission"

	if detail_background:
		detail_background.text = "Hover over a crew member to see their details. Each brings unique skills and traits that will affect your journey."

	if detail_trait:
		detail_trait.text = ""

	if detail_stats:
		detail_stats.text = ""

# ============================================================================
# HELPERS
# ============================================================================

func _get_crew_by_id(crew_id: String) -> Dictionary:
	for crew in crew_roster:
		if crew.id == crew_id:
			return crew
	return {}
