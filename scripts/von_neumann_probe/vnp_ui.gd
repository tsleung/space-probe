extends Control

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

var store = null
var base_positions = {}
var ai_controller = null
var strategic_points = {}  # point_id -> Node2D

# UI elements (created dynamically)
var team_panels = {}
var victory_label: Label = null
var status_container: HBoxContainer = null
var stance_buttons = {}  # {stance: Button}
var formation_buttons = {}  # {formation: Button}
var adherence_buttons = {}  # {adherence: Button}
var fleet_composition_labels = {}  # {ship_type: Label}
var ship_priority_buttons = {}  # {ship_type: Button}
var vnp_main = null  # Reference to main scene for charge controls
var doctrine_expanded = false  # Whether doctrine panel is expanded
var doctrine_container = null  # The expandable doctrine section

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
	status_container.add_theme_constant_override("separation", 20)  # Reduced spacing
	margin.add_child(status_container)

	# Create panel for each team
	for team in VnpTypes.Team.values():
		var panel = _create_team_panel(team)
		status_container.add_child(panel)
		team_panels[team] = panel
		# Hide Progenitor panel initially - it will be revealed during The Cycle
		if team == VnpTypes.Team.PROGENITOR:
			panel.visible = false

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
	stats.add_theme_constant_override("separation", 10)  # Tighter spacing
	vbox.add_child(stats)

	# Ship count
	var ships_label = Label.new()
	ships_label.name = "ShipsLabel"
	ships_label.text = "0"
	ships_label.add_theme_font_size_override("font_size", 12)
	stats.add_child(ships_label)

	# Energy
	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "0"
	energy_label.add_theme_font_size_override("font_size", 12)
	energy_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))  # Yellow for energy
	stats.add_child(energy_label)

	# Mass
	var mass_label = Label.new()
	mass_label.name = "MassLabel"
	mass_label.text = "0"
	mass_label.add_theme_font_size_override("font_size", 12)
	mass_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))  # Brown for mass
	stats.add_child(mass_label)

	# Strategic points
	var points_label = Label.new()
	points_label.name = "PointsLabel"
	points_label.text = "0 pts"
	points_label.add_theme_font_size_override("font_size", 12)
	stats.add_child(points_label)

	# Base weapon cooldown indicator
	var weapon_container = HBoxContainer.new()
	weapon_container.name = "WeaponContainer"
	weapon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_container.add_theme_constant_override("separation", 4)
	vbox.add_child(weapon_container)

	var weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.text = _get_base_weapon_name(team)
	weapon_label.add_theme_font_size_override("font_size", 10)
	weapon_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.2))
	weapon_container.add_child(weapon_label)

	# Charge indicators (circles) - BIGGER for visibility during screen shake
	var charge_container = HBoxContainer.new()
	charge_container.name = "ChargeContainer"
	charge_container.add_theme_constant_override("separation", 4)
	for i in range(5):  # MAX_BASE_CHARGES = 5
		var charge_dot = ColorRect.new()
		charge_dot.name = "Charge%d" % i
		charge_dot.custom_minimum_size = Vector2(12, 12)  # Bigger dots
		charge_dot.color = Color(0.3, 0.3, 0.3, 0.5)  # Dim when empty
		charge_container.add_child(charge_dot)
	weapon_container.add_child(charge_container)

	# Player-only: Mode toggle, fire button, and expandable doctrine
	# LARGER BUTTONS for easier clicking during screen shake
	if team == VnpTypes.Team.PLAYER:
		var mode_btn = Button.new()
		mode_btn.name = "ModeBtn"
		mode_btn.text = "M"  # Manual
		mode_btn.custom_minimum_size = Vector2(32, 28)  # BIGGER
		mode_btn.tooltip_text = "Toggle Auto/Manual fire mode"
		mode_btn.pressed.connect(_on_mode_toggle_pressed)
		mode_btn.add_theme_font_size_override("font_size", 13)
		weapon_container.add_child(mode_btn)

		var fire_btn = Button.new()
		fire_btn.name = "FireBtn"
		fire_btn.text = "FIRE"
		fire_btn.custom_minimum_size = Vector2(50, 28)  # BIGGER
		fire_btn.tooltip_text = "Fire 1 charge (close range)"
		fire_btn.pressed.connect(_on_fire_button_pressed)
		fire_btn.add_theme_font_size_override("font_size", 12)
		var fire_style = StyleBoxFlat.new()
		fire_style.bg_color = Color(0.5, 0.25, 0.2, 0.9)
		fire_style.set_corner_radius_all(4)
		fire_style.set_content_margin_all(4)
		fire_btn.add_theme_stylebox_override("normal", fire_style)
		weapon_container.add_child(fire_btn)

		var burst_btn = Button.new()
		burst_btn.name = "BurstBtn"
		burst_btn.text = "BURST"
		burst_btn.custom_minimum_size = Vector2(70, 28)  # BIGGER
		burst_btn.tooltip_text = "Fire ALL charges at once! More charges = longer range + bigger effect"
		burst_btn.pressed.connect(_on_burst_button_pressed)
		burst_btn.add_theme_font_size_override("font_size", 12)
		var burst_style = StyleBoxFlat.new()
		burst_style.bg_color = Color(0.7, 0.2, 0.1, 0.9)
		burst_style.set_corner_radius_all(4)
		burst_style.set_content_margin_all(4)
		burst_btn.add_theme_stylebox_override("normal", burst_style)
		weapon_container.add_child(burst_btn)

		# Expandable doctrine toggle button
		var doctrine_btn = Button.new()
		doctrine_btn.name = "DoctrineBtn"
		doctrine_btn.text = "+"
		doctrine_btn.custom_minimum_size = Vector2(32, 28)  # BIGGER
		doctrine_btn.tooltip_text = "Expand fleet doctrine options"
		doctrine_btn.pressed.connect(_on_doctrine_toggle_pressed)
		doctrine_btn.add_theme_font_size_override("font_size", 14)
		var doctrine_style = StyleBoxFlat.new()
		doctrine_style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
		doctrine_style.set_corner_radius_all(4)
		doctrine_style.set_content_margin_all(4)
		doctrine_btn.add_theme_stylebox_override("normal", doctrine_style)
		weapon_container.add_child(doctrine_btn)

		# Expandable doctrine container (hidden by default)
		doctrine_container = VBoxContainer.new()
		doctrine_container.name = "DoctrineContainer"
		doctrine_container.visible = false
		doctrine_container.add_theme_constant_override("separation", 4)
		vbox.add_child(doctrine_container)

		_create_doctrine_controls(doctrine_container)

	return panel

func _get_base_weapon_name(team: int) -> String:
	var weapon_type = VnpTypes.BASE_WEAPONS.get(team, 0)
	match weapon_type:
		VnpTypes.BaseWeapon.ARC_STORM:
			return "Arc Storm"
		VnpTypes.BaseWeapon.HELLSTORM:
			return "Hellstorm"
		VnpTypes.BaseWeapon.VOID_TEAR:
			return "Void Tear"
	return "Weapon"

func init(vnp_store, bases: Dictionary, controller = null, point_nodes: Dictionary = {}, main_scene = null):
	self.store = vnp_store
	self.base_positions = bases
	self.ai_controller = controller
	self.strategic_points = point_nodes
	self.vnp_main = main_scene if main_scene else get_parent().get_parent()  # VnpMain is parent of UILayer

	store.subscribe(self)

	# Listen for stance/formation/adherence changes from AI controller
	if ai_controller:
		ai_controller.stance_changed.connect(_on_stance_changed)
		ai_controller.formation_changed.connect(_on_formation_changed)
		ai_controller.adherence_changed.connect(_on_adherence_changed)
		# Defer style updates to ensure buttons exist
		call_deferred("_update_stance_display", ai_controller.team_stances.get(VnpTypes.Team.PLAYER, VnpTypes.FleetStance.BALANCED))
		call_deferred("_update_formation_display", ai_controller.team_formations.get(VnpTypes.Team.PLAYER, VnpTypes.FleetFormation.OFFENSIVE))
		call_deferred("_update_adherence_display", ai_controller.team_adherence.get(VnpTypes.Team.PLAYER, VnpTypes.FleetAdherence.LOOSE))

	var current_state = store.get_state()
	on_state_changed(current_state)

func on_state_changed(state):
	if state == null or not state.has("teams"):
		return
	for team in VnpTypes.Team.values():
		# Skip teams that don't exist in state (like PROGENITOR)
		if not state.teams.has(team):
			continue
		# Skip teams without UI panels
		if not team_panels.has(team):
			continue
		var ship_count = _count_team_ships(state, team)
		var point_count = _count_team_strategic_points(state, team)
		var energy = state.teams[team].energy
		var mass = state.teams[team].get("mass", 0)

		var panel = team_panels[team]
		var ships_label = panel.get_node("VBoxContainer/Stats/ShipsLabel")
		var energy_label = panel.get_node("VBoxContainer/Stats/EnergyLabel")
		var mass_label = panel.get_node("VBoxContainer/Stats/MassLabel")
		var points_label = panel.get_node("VBoxContainer/Stats/PointsLabel")

		ships_label.text = "%d ships" % ship_count
		energy_label.text = "%d en" % energy
		mass_label.text = "%d ms" % mass
		points_label.text = "%d pts" % point_count

	# Update player fleet composition display
	_update_fleet_composition(state)

func update_cooldowns(cooldowns: Dictionary, charges: Dictionary = {}, modes: Dictionary = {}):
	for team in cooldowns:
		if not team_panels.has(team):
			continue
		var panel = team_panels[team]
		var weapon_container = panel.get_node_or_null("VBoxContainer/WeaponContainer")
		if not weapon_container:
			continue

		# Update charge indicators
		var charge_container = weapon_container.get_node_or_null("ChargeContainer")
		if charge_container:
			var charge_count = charges.get(team, 0)
			var team_color = VnpTypes.get_team_color(team)
			for i in range(charge_container.get_child_count()):
				var dot = charge_container.get_child(i)
				if i < charge_count:
					dot.color = team_color  # Lit when charged
				else:
					dot.color = Color(0.3, 0.3, 0.3, 0.5)  # Dim when empty

		# Update mode button for player
		if team == VnpTypes.Team.PLAYER:
			var mode_btn = weapon_container.get_node_or_null("ModeBtn")
			if mode_btn:
				var mode = modes.get(team, "auto")
				mode_btn.text = "M" if mode == "manual" else "A"
				mode_btn.tooltip_text = "Mode: %s (click to toggle)" % mode.capitalize()

			var charge_count = charges.get(team, 0)

			var fire_btn = weapon_container.get_node_or_null("FireBtn")
			if fire_btn:
				fire_btn.disabled = charge_count <= 0

			var burst_btn = weapon_container.get_node_or_null("BurstBtn")
			if burst_btn:
				burst_btn.disabled = charge_count <= 0
				burst_btn.text = "BURST x%d" % charge_count if charge_count > 1 else "BURST"


func _on_mode_toggle_pressed():
	if vnp_main:
		vnp_main.toggle_charge_mode(VnpTypes.Team.PLAYER)


func _on_fire_button_pressed():
	if vnp_main:
		vnp_main.manual_fire_base_weapon(VnpTypes.Team.PLAYER)


func _on_burst_button_pressed():
	if vnp_main:
		if convergence_active:
			# During convergence, this is RETREAT - flee to center
			vnp_main.trigger_full_retreat(VnpTypes.Team.PLAYER)
		else:
			# Normal operation - burst fire base weapon
			vnp_main.burst_fire_base_weapon(VnpTypes.Team.PLAYER)

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


func _count_team_strategic_points(state: Dictionary, team: int) -> int:
	var count = 0
	if state.has("strategic_points"):
		for point_id in state.strategic_points:
			if state.strategic_points[point_id].get("owner", null) == team:
				count += 1
	return count


func show_victory(winner_name: String):
	# Special message if Progenitor wins
	if winner_name == "The Progenitor":
		victory_label.text = "THE CYCLE CONTINUES\nYou have been absorbed."
		victory_label.add_theme_color_override("font_color", VnpTypes.PROGENITOR_PULSE)
		victory_label.add_theme_font_size_override("font_size", 36)
	else:
		victory_label.text = "%s Wins!" % winner_name
		victory_label.add_theme_color_override("font_color", Color.WHITE)
		victory_label.add_theme_font_size_override("font_size", 48)

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


func _on_doctrine_toggle_pressed():
	doctrine_expanded = not doctrine_expanded
	if doctrine_container:
		doctrine_container.visible = doctrine_expanded

	# Update button text
	var player_panel = team_panels.get(VnpTypes.Team.PLAYER)
	if player_panel:
		var doctrine_btn = player_panel.get_node_or_null("VBoxContainer/WeaponContainer/DoctrineBtn")
		if doctrine_btn:
			doctrine_btn.text = "-" if doctrine_expanded else "+"


func _create_doctrine_controls(container: VBoxContainer):
	# Compact inline doctrine controls

	# Row 1: Stance (AGG BAL DEF)
	var stance_label = Label.new()
	stance_label.text = "Build:"
	stance_label.add_theme_font_size_override("font_size", 10)
	stance_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.3))
	container.add_child(stance_label)

	var stance_row = HBoxContainer.new()
	stance_row.add_theme_constant_override("separation", 3)
	container.add_child(stance_row)

	for stance in VnpTypes.FleetStance.values():
		var btn = _create_stance_button(stance)
		stance_row.add_child(btn)
		stance_buttons[stance] = btn

	# Row 2: Formation + Adherence
	var tactic_label = Label.new()
	tactic_label.text = "Tactics:"
	tactic_label.add_theme_font_size_override("font_size", 10)
	tactic_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.3))
	container.add_child(tactic_label)

	var tactic_row = HBoxContainer.new()
	tactic_row.add_theme_constant_override("separation", 3)
	container.add_child(tactic_row)

	for formation in VnpTypes.FleetFormation.values():
		var btn = _create_formation_button(formation)
		tactic_row.add_child(btn)
		formation_buttons[formation] = btn

	for adherence in VnpTypes.FleetAdherence.values():
		var btn = _create_adherence_button(adherence)
		tactic_row.add_child(btn)
		adherence_buttons[adherence] = btn

	# Row 3: Ship Priorities (clickable to cycle 1x -> 2x -> 3x -> ∞)
	var priority_label = Label.new()
	priority_label.text = "Priority (click to boost):"
	priority_label.add_theme_font_size_override("font_size", 10)
	priority_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.3))
	container.add_child(priority_label)

	var priority_row = HBoxContainer.new()
	priority_row.add_theme_constant_override("separation", 3)
	container.add_child(priority_row)

	for ship_type in [VnpTypes.ShipType.FRIGATE, VnpTypes.ShipType.DESTROYER, VnpTypes.ShipType.CRUISER,
					  VnpTypes.ShipType.DEFENDER, VnpTypes.ShipType.SHIELDER, VnpTypes.ShipType.GRAVITON]:
		var btn = _create_priority_button(ship_type)
		priority_row.add_child(btn)
		ship_priority_buttons[ship_type] = btn

	# Row 4: Fleet composition counts
	var comp_row = HBoxContainer.new()
	comp_row.add_theme_constant_override("separation", 4)
	container.add_child(comp_row)

	for ship_type in [VnpTypes.ShipType.FRIGATE, VnpTypes.ShipType.DESTROYER, VnpTypes.ShipType.CRUISER,
					  VnpTypes.ShipType.DEFENDER, VnpTypes.ShipType.SHIELDER, VnpTypes.ShipType.GRAVITON]:
		var ship_label = Label.new()
		ship_label.name = "Ship_%d" % ship_type
		var short_name = _get_ship_short_name(ship_type)
		ship_label.text = "%s:0" % short_name
		ship_label.add_theme_font_size_override("font_size", 9)
		ship_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.3))
		comp_row.add_child(ship_label)
		fleet_composition_labels[ship_type] = ship_label


func _create_priority_button(ship_type: int) -> Button:
	var btn = Button.new()
	btn.name = "Priority_%d" % ship_type
	var short_name = _get_ship_short_name(ship_type)
	btn.text = short_name  # Will be updated to show priority
	btn.custom_minimum_size = Vector2(36, 22)
	btn.tooltip_text = "Click to increase %s priority" % VnpTypes.SHIP_STATS.get(ship_type, {}).get("name", "Ship")
	btn.pressed.connect(_on_priority_button_pressed.bind(ship_type))
	btn.add_theme_font_size_override("font_size", 9)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.25, 0.3, 0.8)
	normal_style.border_color = Color(0.4, 0.5, 0.6)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	normal_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal_style)

	return btn


func _on_priority_button_pressed(ship_type: int):
	if ai_controller:
		ai_controller.cycle_ship_priority(VnpTypes.Team.PLAYER, ship_type)
		_update_priority_button(ship_type)


func _update_priority_button(ship_type: int):
	if not ship_priority_buttons.has(ship_type) or not ai_controller:
		return

	var btn = ship_priority_buttons[ship_type]
	var priority = ai_controller.get_ship_priority(VnpTypes.Team.PLAYER, ship_type)
	var short_name = _get_ship_short_name(ship_type)

	# Update text to show priority
	if priority == 1:
		btn.text = short_name
	elif priority == 100:
		btn.text = "%s∞" % short_name
	else:
		btn.text = "%sx%d" % [short_name, priority]

	# Update style based on priority
	var style = StyleBoxFlat.new()
	match priority:
		1:
			style.bg_color = Color(0.2, 0.25, 0.3, 0.8)
			style.border_color = Color(0.4, 0.5, 0.6)
			style.set_border_width_all(1)
		2:
			style.bg_color = Color(0.3, 0.35, 0.2, 0.9)
			style.border_color = Color(0.6, 0.7, 0.3)
			style.set_border_width_all(2)
		3:
			style.bg_color = Color(0.4, 0.3, 0.15, 0.9)
			style.border_color = Color(0.8, 0.6, 0.2)
			style.set_border_width_all(2)
		100:
			style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
			style.border_color = Color(1.0, 0.4, 0.3)
			style.set_border_width_all(2)

	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", style)


# Old standalone fleet controls panel - no longer used
func _create_fleet_controls_old():
	# Bottom left panel for fleet stance - compact version
	var bottom_margin = MarginContainer.new()
	bottom_margin.name = "BottomMargin"
	bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_margin.add_theme_constant_override("margin_left", 10)
	bottom_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(bottom_margin)

	var fleet_panel = PanelContainer.new()
	fleet_panel.name = "FleetPanel"

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.2, 0.85)
	panel_style.border_color = VnpTypes.get_team_color(VnpTypes.Team.PLAYER)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(8)
	fleet_panel.add_theme_stylebox_override("panel", panel_style)
	bottom_margin.add_child(fleet_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	fleet_panel.add_child(vbox)

	# Header - more compact
	var header = Label.new()
	header.text = "DOCTRINE"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", VnpTypes.get_team_color(VnpTypes.Team.PLAYER))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Stance buttons (what ships to build)
	var stance_row = HBoxContainer.new()
	stance_row.add_theme_constant_override("separation", 3)
	stance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stance_row)

	for stance in VnpTypes.FleetStance.values():
		var btn = _create_stance_button(stance)
		stance_row.add_child(btn)
		stance_buttons[stance] = btn

	# Formation + Adherence in single row
	var tactic_row = HBoxContainer.new()
	tactic_row.add_theme_constant_override("separation", 3)
	tactic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tactic_row)

	for formation in VnpTypes.FleetFormation.values():
		var btn = _create_formation_button(formation)
		tactic_row.add_child(btn)
		formation_buttons[formation] = btn

	for adherence in VnpTypes.FleetAdherence.values():
		var btn = _create_adherence_button(adherence)
		tactic_row.add_child(btn)
		adherence_buttons[adherence] = btn

	# Fleet composition - single compact row
	var comp_row = HBoxContainer.new()
	comp_row.name = "CompositionRow"
	comp_row.add_theme_constant_override("separation", 6)
	comp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(comp_row)

	# Add labels for each combat ship type
	for ship_type in [VnpTypes.ShipType.FRIGATE, VnpTypes.ShipType.DESTROYER, VnpTypes.ShipType.CRUISER,
					  VnpTypes.ShipType.DEFENDER, VnpTypes.ShipType.SHIELDER, VnpTypes.ShipType.GRAVITON]:
		var ship_label = Label.new()
		ship_label.name = "Ship_%d" % ship_type
		var short_name = _get_ship_short_name(ship_type)
		ship_label.text = "%s:0" % short_name
		ship_label.add_theme_font_size_override("font_size", 9)
		ship_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.3))
		comp_row.add_child(ship_label)
		fleet_composition_labels[ship_type] = ship_label


func _create_stance_button(stance: int) -> Button:
	var btn = Button.new()
	btn.name = "Stance_%d" % stance
	# Use abbreviated names
	var abbrev = {"Aggressive": "AGG", "Balanced": "BAL", "Defensive": "DEF"}
	btn.text = abbrev.get(VnpTypes.get_stance_name(stance), VnpTypes.get_stance_name(stance))
	btn.custom_minimum_size = Vector2(40, 22)
	btn.pressed.connect(_on_stance_button_pressed.bind(stance))

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.25, 0.3, 0.8)
	normal_style.border_color = Color(0.4, 0.5, 0.6)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	normal_style.set_content_margin_all(3)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.35, 0.4, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", 9)

	return btn


func _create_formation_button(formation: int) -> Button:
	var btn = Button.new()
	btn.name = "Formation_%d" % formation
	# Use abbreviated names
	var abbrev = {"Defensive": "DEF", "Offensive": "OFF"}
	btn.text = abbrev.get(VnpTypes.get_formation_name(formation), VnpTypes.get_formation_name(formation))
	btn.custom_minimum_size = Vector2(36, 20)
	btn.pressed.connect(_on_formation_button_pressed.bind(formation))

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.22, 0.28, 0.8)
	normal_style.border_color = Color(0.35, 0.45, 0.55)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	normal_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.28, 0.32, 0.38, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", 9)

	return btn


func _create_adherence_button(adherence: int) -> Button:
	var btn = Button.new()
	btn.name = "Adherence_%d" % adherence
	# Use abbreviated names
	var abbrev = {"Loose": "LSE", "Tight": "TGT"}
	btn.text = abbrev.get(VnpTypes.get_adherence_name(adherence), VnpTypes.get_adherence_name(adherence))
	btn.custom_minimum_size = Vector2(36, 20)
	btn.pressed.connect(_on_adherence_button_pressed.bind(adherence))

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.18, 0.2, 0.25, 0.8)
	normal_style.border_color = Color(0.3, 0.4, 0.5)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	normal_style.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.28, 0.35, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", 9)

	return btn


func _on_stance_button_pressed(stance: int):
	if ai_controller:
		ai_controller.team_stances[VnpTypes.Team.PLAYER] = stance
		ai_controller.stance_changed.emit(VnpTypes.Team.PLAYER, stance)
		_update_stance_display(stance)


func _on_stance_changed(team: int, stance: int):
	if team == VnpTypes.Team.PLAYER:
		_update_stance_display(stance)


func _on_formation_button_pressed(formation: int):
	if ai_controller:
		ai_controller.team_formations[VnpTypes.Team.PLAYER] = formation
		ai_controller.formation_changed.emit(VnpTypes.Team.PLAYER, formation)
		_update_formation_display(formation)


func _on_formation_changed(team: int, formation: int):
	if team == VnpTypes.Team.PLAYER:
		_update_formation_display(formation)


func _on_adherence_button_pressed(adherence: int):
	if ai_controller:
		ai_controller.team_adherence[VnpTypes.Team.PLAYER] = adherence
		ai_controller.adherence_changed.emit(VnpTypes.Team.PLAYER, adherence)
		_update_adherence_display(adherence)


func _on_adherence_changed(team: int, adherence: int):
	if team == VnpTypes.Team.PLAYER:
		_update_adherence_display(adherence)


func _update_stance_display(active_stance: int):
	for stance in stance_buttons:
		var btn = stance_buttons[stance]
		var is_active = stance == active_stance

		var style = StyleBoxFlat.new()
		if is_active:
			# Active stance - bright border and background
			style.bg_color = Color(0.15, 0.3, 0.5, 0.9)
			style.border_color = VnpTypes.get_team_color(VnpTypes.Team.PLAYER)
			style.set_border_width_all(2)
		else:
			# Inactive stance
			style.bg_color = Color(0.2, 0.25, 0.3, 0.8)
			style.border_color = Color(0.4, 0.5, 0.6)
			style.set_border_width_all(1)

		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		btn.add_theme_stylebox_override("normal", style)


func _update_formation_display(active_formation: int):
	for formation in formation_buttons:
		var btn = formation_buttons[formation]
		var is_active = formation == active_formation

		var style = StyleBoxFlat.new()
		if is_active:
			# Active formation - different color scheme (more tactical feel)
			if formation == VnpTypes.FleetFormation.DEFENSIVE:
				style.bg_color = Color(0.15, 0.35, 0.25, 0.9)  # Green tint for defensive
				style.border_color = Color(0.3, 0.7, 0.4)
			else:  # Offensive
				style.bg_color = Color(0.4, 0.2, 0.15, 0.9)  # Red tint for offensive
				style.border_color = Color(0.8, 0.4, 0.3)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.2, 0.22, 0.28, 0.8)
			style.border_color = Color(0.35, 0.45, 0.55)
			style.set_border_width_all(1)

		style.set_corner_radius_all(4)
		style.set_content_margin_all(5)
		btn.add_theme_stylebox_override("normal", style)


func _update_adherence_display(active_adherence: int):
	for adherence in adherence_buttons:
		var btn = adherence_buttons[adherence]
		var is_active = adherence == active_adherence

		var style = StyleBoxFlat.new()
		if is_active:
			if adherence == VnpTypes.FleetAdherence.LOOSE:
				style.bg_color = Color(0.3, 0.25, 0.15, 0.9)  # Orange tint for loose
				style.border_color = Color(0.7, 0.5, 0.3)
			else:  # Tight
				style.bg_color = Color(0.2, 0.25, 0.35, 0.9)  # Blue tint for tight
				style.border_color = Color(0.4, 0.5, 0.8)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.18, 0.2, 0.25, 0.8)
			style.border_color = Color(0.3, 0.4, 0.5)
			style.set_border_width_all(1)

		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", style)


func _get_ship_short_name(ship_type: int) -> String:
	match ship_type:
		VnpTypes.ShipType.FRIGATE:
			return "FRG"
		VnpTypes.ShipType.DESTROYER:
			return "DST"
		VnpTypes.ShipType.CRUISER:
			return "CRS"
		VnpTypes.ShipType.DEFENDER:
			return "DEF"
		VnpTypes.ShipType.SHIELDER:
			return "SHD"
		VnpTypes.ShipType.GRAVITON:
			return "GRV"
		VnpTypes.ShipType.STARBASE:
			return "SB"
	return "???"


func _update_fleet_composition(state: Dictionary):
	if fleet_composition_labels.is_empty():
		return

	# Count player ships by type
	var counts = {}
	for ship_type in fleet_composition_labels.keys():
		counts[ship_type] = 0

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team == VnpTypes.Team.PLAYER:
			if counts.has(ship.type):
				counts[ship.type] += 1

	# Update labels
	for ship_type in fleet_composition_labels:
		var label = fleet_composition_labels[ship_type]
		var short_name = _get_ship_short_name(ship_type)
		label.text = "%s: %d" % [short_name, counts[ship_type]]


# === THE CYCLE - CONVERGENCE UI ===

var mystery_card: PanelContainer = null
var progenitor_label: Label = null
var cycle_ending_panel: PanelContainer = null
var convergence_active: bool = false  # Track if convergence is happening

func show_mystery_card():
	"""Display ??? DETECTED card - first sign of The Progenitor"""
	if mystery_card:
		mystery_card.queue_free()

	# Show the Progenitor team panel with "???" as the name
	var progenitor_panel = team_panels.get(VnpTypes.Team.PROGENITOR)
	if progenitor_panel:
		progenitor_panel.visible = true
		var name_label = progenitor_panel.get_node_or_null("VBoxContainer/NameLabel")
		if name_label:
			name_label.text = "???"

	mystery_card = PanelContainer.new()
	mystery_card.name = "MysteryCard"
	mystery_card.set_anchors_preset(Control.PRESET_CENTER)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.0, 0.15, 0.95)
	style.border_color = VnpTypes.PROGENITOR_ACCENT
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(30)
	mystery_card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mystery_card.add_child(vbox)

	var title = Label.new()
	title.text = "??? DETECTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", VnpTypes.PROGENITOR_ACCENT)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Something approaches from the edge..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.5, 0.8))
	vbox.add_child(subtitle)

	add_child(mystery_card)

	# Auto-hide after a few seconds
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(func():
		if mystery_card and is_instance_valid(mystery_card):
			var tween = create_tween()
			tween.tween_property(mystery_card, "modulate:a", 0.0, 1.0)
			tween.tween_callback(mystery_card.queue_free)
	)


func reveal_progenitor():
	"""Transition from ??? to THE PROGENITOR - name revealed in team panel"""
	convergence_active = true

	# Update the team panel name from "???" to "THE PROGENITOR"
	var progenitor_panel = team_panels.get(VnpTypes.Team.PROGENITOR)
	if progenitor_panel:
		var name_label = progenitor_panel.get_node_or_null("VBoxContainer/NameLabel")
		if name_label:
			# Dramatic reveal animation
			var tween = create_tween()
			tween.tween_property(name_label, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func(): name_label.text = "THE PROGENITOR")
			tween.tween_property(name_label, "modulate:a", 1.0, 0.5)

	# Also show a dramatic centered reveal card
	if progenitor_label:
		progenitor_label.queue_free()

	progenitor_label = Label.new()
	progenitor_label.name = "ProgenitorLabel"
	progenitor_label.text = "THE PROGENITOR"
	progenitor_label.set_anchors_preset(Control.PRESET_CENTER)
	progenitor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progenitor_label.add_theme_font_size_override("font_size", 56)
	progenitor_label.add_theme_color_override("font_color", VnpTypes.PROGENITOR_PULSE)
	progenitor_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	progenitor_label.add_theme_constant_override("shadow_offset_x", 3)
	progenitor_label.add_theme_constant_override("shadow_offset_y", 3)
	progenitor_label.modulate.a = 0.0
	add_child(progenitor_label)

	# Dramatic fade in and out for the name reveal
	var reveal_tween = create_tween()
	reveal_tween.tween_property(progenitor_label, "modulate:a", 1.0, 0.5)
	reveal_tween.tween_interval(2.5)
	reveal_tween.tween_property(progenitor_label, "modulate:a", 0.0, 1.0)
	reveal_tween.tween_callback(func():
		if progenitor_label and is_instance_valid(progenitor_label):
			progenitor_label.queue_free()
			progenitor_label = null
	)

	# Flip the BURST button to show RETREAT functionality
	_update_burst_button_for_convergence()


func _update_burst_button_for_convergence():
	"""Change BURST button behavior during convergence - retreat instead of attack"""
	var player_panel = team_panels.get(VnpTypes.Team.PLAYER, null)
	if not player_panel:
		return

	var weapon_container = player_panel.get_node_or_null("VBoxContainer/WeaponContainer")
	if not weapon_container:
		return

	var burst_btn = weapon_container.get_node_or_null("BurstBtn")
	if burst_btn:
		burst_btn.text = "RETREAT"
		burst_btn.tooltip_text = "All ships flee to safety! The Progenitor approaches!"

		# Change button style to purple
		var retreat_style = StyleBoxFlat.new()
		retreat_style.bg_color = Color(0.4, 0.1, 0.5, 0.9)
		retreat_style.border_color = VnpTypes.PROGENITOR_ACCENT
		retreat_style.set_border_width_all(2)
		retreat_style.set_corner_radius_all(4)
		retreat_style.set_content_margin_all(4)
		burst_btn.add_theme_stylebox_override("normal", retreat_style)


func show_cycle_ending():
	"""Display the cycle ending - player becomes the next Progenitor"""
	if cycle_ending_panel:
		cycle_ending_panel.queue_free()

	cycle_ending_panel = PanelContainer.new()
	cycle_ending_panel.name = "CycleEndingPanel"
	cycle_ending_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.0, 0.1, 0.95)
	cycle_ending_panel.add_theme_stylebox_override("panel", style)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cycle_ending_panel.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "THE PROGENITOR SHATTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", VnpTypes.PROGENITOR_ACCENT)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "You are now the largest network."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(subtitle)

	var cycle_text = Label.new()
	cycle_text.text = "The cycle continues..."
	cycle_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cycle_text.add_theme_font_size_override("font_size", 20)
	cycle_text.add_theme_color_override("font_color", Color(0.6, 0.4, 0.7))
	vbox.add_child(cycle_text)

	# Add a spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	var warning = Label.new()
	warning.text = "Somewhere, in a distant sector,\na small faction detects something massive approaching.\nThey call it..."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 16)
	warning.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(warning)

	var mystery = Label.new()
	mystery.text = '"???"'
	mystery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery.add_theme_font_size_override("font_size", 36)
	mystery.add_theme_color_override("font_color", VnpTypes.PROGENITOR_ACCENT)
	vbox.add_child(mystery)

	# Menu button
	var menu_btn = Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.pressed.connect(_on_menu_button_pressed)
	vbox.add_child(menu_btn)

	add_child(cycle_ending_panel)

	# Fade in
	cycle_ending_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(cycle_ending_panel, "modulate:a", 1.0, 2.0)


func is_convergence_active() -> bool:
	"""Check if convergence is happening (for button behavior changes)"""
	return convergence_active
