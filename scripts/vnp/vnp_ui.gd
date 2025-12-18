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

	# Add menu button to the status bar (top right)
	var menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "Menu"
	menu_button.custom_minimum_size = Vector2(80, 35)
	menu_button.pressed.connect(_on_menu_button_pressed)

	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.3, 0.2, 0.2, 0.9)
	button_style.border_color = Color(0.8, 0.4, 0.4)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(5)
	button_style.set_content_margin_all(8)
	menu_button.add_theme_stylebox_override("normal", button_style)

	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.5, 0.3, 0.3, 0.9)
	menu_button.add_theme_stylebox_override("hover", hover_style)

	status_container.add_child(menu_button)

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

	# Planets
	var planets_label = Label.new()
	planets_label.name = "PlanetsLabel"
	planets_label.text = "0 🌍"
	planets_label.add_theme_font_size_override("font_size", 14)
	stats.add_child(planets_label)

	# Base weapon cooldown indicator
	var weapon_container = HBoxContainer.new()
	weapon_container.name = "WeaponContainer"
	weapon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(weapon_container)

	var weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.text = _get_base_weapon_name(team)
	weapon_label.add_theme_font_size_override("font_size", 12)
	weapon_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.2))
	weapon_container.add_child(weapon_label)

	var cooldown_bar = ProgressBar.new()
	cooldown_bar.name = "CooldownBar"
	cooldown_bar.custom_minimum_size = Vector2(60, 8)
	cooldown_bar.show_percentage = false
	cooldown_bar.max_value = VnpTypes.BASE_WEAPON_COOLDOWN
	cooldown_bar.value = VnpTypes.BASE_WEAPON_COOLDOWN
	weapon_container.add_child(cooldown_bar)

	return panel

func _get_base_weapon_name(team: int) -> String:
	var weapon_type = VnpTypes.BASE_WEAPONS.get(team, 0)
	match weapon_type:
		VnpTypes.BaseWeapon.ION_CANNON:
			return "⚡ Ion"
		VnpTypes.BaseWeapon.MISSILE_BARRAGE:
			return "🚀 Missiles"
		VnpTypes.BaseWeapon.SINGULARITY:
			return "🌀 Singularity"
	return "Weapon"

func init(vnp_store, bases: Dictionary):
	self.store = vnp_store
	self.base_positions = bases

	store.subscribe(self)

	var current_state = store.get_state()
	on_state_changed(current_state)

func on_state_changed(state):
	for team in VnpTypes.Team.values():
		var ship_count = _count_team_ships(state, team)
		var planet_count = _count_team_planets(state, team)
		var energy = state.teams[team].energy

		var panel = team_panels[team]
		var ships_label = panel.get_node("VBoxContainer/Stats/ShipsLabel")
		var energy_label = panel.get_node("VBoxContainer/Stats/EnergyLabel")
		var planets_label = panel.get_node("VBoxContainer/Stats/PlanetsLabel")

		ships_label.text = "%d ships" % ship_count
		energy_label.text = "%d energy" % energy
		planets_label.text = "%d 🌍" % planet_count

func update_cooldowns(cooldowns: Dictionary):
	for team in cooldowns:
		if team_panels.has(team):
			var panel = team_panels[team]
			var cooldown_bar = panel.get_node_or_null("VBoxContainer/WeaponContainer/CooldownBar")
			if cooldown_bar:
				# Invert: full bar means ready, empty means cooling down
				cooldown_bar.value = VnpTypes.BASE_WEAPON_COOLDOWN - cooldowns[team]

func _count_team_ships(state: Dictionary, team: int) -> int:
	var count = 0
	for ship_id in state.ships:
		if state.ships[ship_id].team == team:
			count += 1
	return count

func _count_team_planets(state: Dictionary, team: int) -> int:
	var count = 0
	for planet_id in state.planets:
		if state.planets[planet_id].get("owner", null) == team:
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

func _on_menu_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
