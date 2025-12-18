extends Control

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")

var store = null
var base_positions = {}

# UI elements (created dynamically)
var team_panels = {}
var victory_label: Label = null
var status_container: HBoxContainer = null

func _ready():
	_create_ui()

func _create_ui():
	# Top bar for team status
	var margin = MarginContainer.new()
	margin.name = "TopMargin"
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	add_child(margin)

	status_container = HBoxContainer.new()
	status_container.name = "StatusContainer"
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	status_container.add_theme_constant_override("separation", 40)
	margin.add_child(status_container)

	# Create panel for each team
	for team in VnpTypes.Team.values():
		var panel = _create_team_panel(team)
		status_container.add_child(panel)
		team_panels[team] = panel

	# Victory label (centered, hidden by default)
	victory_label = Label.new()
	victory_label.name = "VictoryLabel"
	victory_label.set_anchors_preset(Control.PRESET_CENTER)
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.add_theme_font_size_override("font_size", 48)
	victory_label.add_theme_color_override("font_color", Color.WHITE)
	victory_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	victory_label.add_theme_constant_override("shadow_offset_x", 2)
	victory_label.add_theme_constant_override("shadow_offset_y", 2)
	victory_label.visible = false
	add_child(victory_label)

func _create_team_panel(team: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = VnpTypes.get_team_name(team) + "Panel"

	# Style the panel with team color
	var style = StyleBoxFlat.new()
	style.bg_color = VnpTypes.get_team_color(team).darkened(0.7)
	style.border_color = VnpTypes.get_team_color(team)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Team name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = VnpTypes.get_team_name(team)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", VnpTypes.get_team_color(team))
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Stats container
	var stats = HBoxContainer.new()
	stats.name = "Stats"
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 20)
	vbox.add_child(stats)

	# Ship count
	var ships_label = Label.new()
	ships_label.name = "ShipsLabel"
	ships_label.text = "0 ships"
	ships_label.add_theme_font_size_override("font_size", 14)
	stats.add_child(ships_label)

	# Energy
	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "0 energy"
	energy_label.add_theme_font_size_override("font_size", 14)
	stats.add_child(energy_label)

	return panel

func init(vnp_store, bases: Dictionary):
	self.store = vnp_store
	self.base_positions = bases

	store.subscribe(self)

	var current_state = store.get_state()
	on_state_changed(current_state)

func on_state_changed(state):
	for team in VnpTypes.Team.values():
		var ship_count = _count_team_ships(state, team)
		var energy = state.teams[team].energy

		var panel = team_panels[team]
		var ships_label = panel.get_node("VBoxContainer/Stats/ShipsLabel")
		var energy_label = panel.get_node("VBoxContainer/Stats/EnergyLabel")

		ships_label.text = "%d ships" % ship_count
		energy_label.text = "%d energy" % energy

func _count_team_ships(state: Dictionary, team: int) -> int:
	var count = 0
	for ship_id in state.ships:
		if state.ships[ship_id].team == team:
			count += 1
	return count

func show_victory(winner_name: String):
	victory_label.text = "%s Wins!" % winner_name
	victory_label.visible = true

	# Animate victory label
	victory_label.modulate.a = 0
	victory_label.scale = Vector2(0.5, 0.5)
	victory_label.pivot_offset = victory_label.size / 2

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(victory_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(victory_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_victory():
	victory_label.visible = false
