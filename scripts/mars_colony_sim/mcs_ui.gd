extends Control

## MCS (Mars Colony Sim) Main UI
## The core gameplay interface for the colony simulation expansion

# Preload in dependency order to ensure proper load
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const _MCSStore = preload("res://scripts/mars_colony_sim/mcs_store.gd")
const _MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")
const _MCSEconomy = preload("res://scripts/mars_colony_sim/mcs_economy.gd")
const _MCSAI = preload("res://scripts/mars_colony_sim/mcs_ai.gd")

# ============================================================================
# NODE REFERENCES
# ============================================================================

# Top bar
@onready var title_label: Label = $TopBar/TitleLabel
@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var year_label: Label = $TopBar/YearLabel
@onready var population_label: Label = $TopBar/PopulationLabel
@onready var stability_label: Label = $TopBar/StabilityLabel

# Left panel - Resources & Buildings
@onready var resource_container: VBoxContainer = $MainContent/LeftPanel/ResourcePanel/ResourceContainer
@onready var building_list: ItemList = $MainContent/LeftPanel/BuildingPanel/BuildingList
@onready var build_button: Button = $MainContent/LeftPanel/BuildingPanel/BuildButton
@onready var repair_button: Button = $MainContent/LeftPanel/BuildingPanel/RepairButton
@onready var auto_repair_button: Button = $MainContent/LeftPanel/BuildingPanel/AutoRepairButton

# Center panel - Population
@onready var tab_container: TabContainer = $MainContent/CenterPanel/PopulationPanel/TabContainer
@onready var colonist_container: VBoxContainer = $MainContent/CenterPanel/PopulationPanel/TabContainer/Colonists/ColonistScroll/ColonistContainer
@onready var stats_label: RichTextLabel = $MainContent/CenterPanel/PopulationPanel/TabContainer/Statistics/StatsLabel
@onready var politics_label: RichTextLabel = $MainContent/CenterPanel/PopulationPanel/TabContainer/Politics/PoliticsLabel
@onready var election_button: Button = $MainContent/CenterPanel/PopulationPanel/TabContainer/Politics/ElectionButton
@onready var independence_button: Button = $MainContent/CenterPanel/PopulationPanel/TabContainer/Politics/IndependenceButton
@onready var projection_label: RichTextLabel = $MainContent/CenterPanel/ProjectionPanel/ProjectionLabel

# Center panel - Colony View
@onready var colony_view = $MainContent/CenterPanel/MCSViewPanel/MCSView

# Right panel - Events
@onready var event_title: Label = $MainContent/RightPanel/EventPanel/EventTitle
@onready var event_description: RichTextLabel = $MainContent/RightPanel/EventPanel/EventDescription
@onready var choice_container: VBoxContainer = $MainContent/RightPanel/EventPanel/ChoiceContainer

# Chronicle log (bottom right)
@onready var colony_log: RichTextLabel = $LogPanel/ColonyLog

# Bottom bar
@onready var workers_button: Button = $BottomBar/WorkersButton
@onready var auto_button: Button = $BottomBar/AutoButton
@onready var ai_button: Button = $BottomBar/AIButton
@onready var ai_personality_button: OptionButton = $BottomBar/AIPersonalityButton
@onready var speed_slider: HSlider = $BottomBar/SpeedSlider
@onready var speed_label: Label = $BottomBar/SpeedLabel
@onready var menu_button: Button = $BottomBar/MenuButton

# Build dialog
@onready var build_dialog: Window = $BuildDialog
@onready var build_type_list: ItemList = $BuildDialog/VBoxContainer/BuildTypeList
@onready var cost_label: Label = $BuildDialog/VBoxContainer/CostLabel
@onready var cancel_build_button: Button = $BuildDialog/VBoxContainer/HBoxContainer/CancelBuildButton
@onready var confirm_build_button: Button = $BuildDialog/VBoxContainer/HBoxContainer/ConfirmBuildButton

# Game over overlay
@onready var game_over_overlay: ColorRect = $GameOverOverlay
@onready var game_over_title: Label = $GameOverOverlay/VBoxContainer/TitleLabel
@onready var game_over_reason: Label = $GameOverOverlay/VBoxContainer/ReasonLabel
@onready var game_over_stats: Label = $GameOverOverlay/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOverOverlay/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $GameOverOverlay/VBoxContainer/MainMenuButton

# ============================================================================
# LOCAL STATE
# ============================================================================

var _colony_store: Node = null
var _auto_advance: bool = false
var _selected_building_idx: int = -1
var _selected_build_type: int = -1
var _peak_population: int = 0

# Continuous time system - weekly ticks for granular feedback
var _game_weeks: float = 0.0          # Continuous week counter
var _time_scale: float = 6.0          # Weeks per real second (6 = ~8.7 sec/year at 52 weeks)
var _last_processed_week: int = 1     # Track when to trigger weekly game logic
const WEEKS_PER_YEAR: int = 52

# AI Spectate mode - enabled by default for watch mode
var _ai_enabled: bool = true
var _ai_personality = _MCSAI.Personality.VISIONARY  # Visionary by default - dreams big!
var _ai_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Create and initialize the colony store FIRST
	_colony_store = _MCSStore.new()
	add_child(_colony_store)
	_colony_store.start_new_colony(24)  # EPIC: 24 founders for faster progression!

	# Give colony view access to store immediately
	if colony_view:
		colony_view.set_store(_colony_store)

	# Connect ALL signals directly (not deferred)
	_connect_store_signals()
	_connect_ui_signals()

	# Enable auto-play with Visionary AI - idle game style!
	_auto_advance = true
	_ai_enabled = true
	_ai_personality = _MCSAI.Personality.VISIONARY
	_time_scale = 6.0  # Default: 6 weeks/sec (~8.7 sec/year at 52 weeks) - satisfying pace

	# Update button states to match
	if auto_button:
		auto_button.button_pressed = true
	if ai_button:
		ai_button.button_pressed = true
	if ai_personality_button:
		ai_personality_button.selected = 1  # Index 1 = Visionary

	# Set speed slider - 3x feels good for watching
	if speed_slider:
		speed_slider.value = 3.0
	if speed_label:
		speed_label.text = "3x"

	# Hide manual controls by default - can be revealed if player wants
	_setup_idle_mode()

	# Initialize log with inspiring message
	_init_log()
	_add_log_entry({
		"year": 1,
		"message": "=== VISIONARY AI GOVERNOR ONLINE ===",
		"log_type": "milestone"
	})
	_add_log_entry({
		"year": 1,
		"message": "Building humanity's future on Mars...",
		"log_type": "info"
	})

	_sync_ui()

func _setup_idle_mode():
	"""Configure UI for idle/watch mode - Universal Paperclips style"""
	# Hide workers button - auto-assigned
	if workers_button:
		workers_button.visible = false

	# Build/Repair are available but auto-repair is on
	if auto_repair_button:
		auto_repair_button.button_pressed = true

	# The key controls that remain visible:
	# - Speed slider (let player control pace)
	# - AI toggle (let them take over if they want)
	# - AI personality (experiment with different governors)
	# - Save/Menu (essential)
	# - Auto toggle (pause if needed)

func _connect_store_signals():
	if _colony_store:
		_colony_store.state_changed.connect(_on_state_changed)
		_colony_store.year_advanced.connect(_on_year_advanced)
		_colony_store.game_ended.connect(_on_game_ended)
		_colony_store.log_entry_added.connect(_on_log_entry)

func _connect_ui_signals():
	# UI button signals - use safe connection pattern
	if auto_button:
		auto_button.toggled.connect(_on_auto_toggled)
	if ai_button:
		ai_button.toggled.connect(_on_ai_toggled)
	if ai_personality_button:
		ai_personality_button.item_selected.connect(_on_ai_personality_changed)
	if speed_slider:
		speed_slider.value_changed.connect(_on_speed_changed)
	if workers_button:
		workers_button.pressed.connect(_on_auto_assign_workers)
	if menu_button:
		menu_button.pressed.connect(_on_menu)
	if build_button:
		build_button.pressed.connect(_on_build_pressed)
	if repair_button:
		repair_button.pressed.connect(_on_repair_pressed)
	if auto_repair_button:
		auto_repair_button.pressed.connect(_on_auto_repair_pressed)
	if building_list:
		building_list.item_selected.connect(_on_building_selected)
	if election_button:
		election_button.pressed.connect(_on_election)
	if independence_button:
		independence_button.pressed.connect(_on_independence_vote)

	# Build dialog
	if build_type_list:
		build_type_list.item_selected.connect(_on_build_type_selected)
	if cancel_build_button:
		cancel_build_button.pressed.connect(_on_build_cancel)
	if confirm_build_button:
		confirm_build_button.pressed.connect(_on_build_confirm)
	if build_dialog:
		build_dialog.close_requested.connect(_on_build_cancel)

	# Game over
	if restart_button:
		restart_button.pressed.connect(_on_restart)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_menu)

func _process(delta: float):
	# Continuous time simulation with weekly ticks for granular feedback
	if _auto_advance and _colony_store and not _colony_store.is_game_over():
		# Advance time continuously (smooth real-time flow)
		_game_weeks += delta * _time_scale

		# Update colony view with continuous time for smooth animations
		if colony_view and colony_view.has_method("set_game_time"):
			# Convert weeks to days for view animations (7 days per week)
			colony_view.set_game_time(_game_weeks * 7.0, _time_scale * 7.0)

		# Check if we've completed a new week
		var current_week = int(_game_weeks) + 1  # +1 because we start at week 1

		if current_week > _last_processed_week:
			_last_processed_week = current_week

			# Resolve any events with AI before advancing
			if _ai_enabled:
				var events = _colony_store.get_active_events()
				for event in events:
					var choice = _MCSAI.choose_event_option(event, _colony_store.get_state(), _ai_personality, randf())
					_colony_store.resolve_event(event.get("id", ""), choice)
					_trigger_event_visual(event)

			# Track year before advancing for detecting year transitions
			var year_before = _colony_store.get_year()

			# Advance the game logic by one week
			_colony_store.advance_week()

			var year_after = _colony_store.get_year()

			# Year-end actions (when year changes)
			if year_after > year_before:
				# Run full AI turn - handles repairs, UPGRADES, superstructures, and new buildings
				var rng = RandomNumberGenerator.new()
				rng.seed = int(Time.get_unix_time_from_system()) + year_after
				var ai_result = _MCSAI.run_ai_turn(_colony_store, _ai_personality, rng)

				# Log AI actions to chronicle
				for action in ai_result.actions:
					if "UPGRADE" in action or "SUPERSTRUCTURE" in action:
						_add_log_entry({"year": year_after, "message": action, "log_type": "ai_action"})

				# Trigger construction visual if buildings were started
				if colony_view and ai_result.actions.size() > 0:
					colony_view.trigger_event_effect("construction", 2.0)

				# Random ambient events for visual interest (10% chance per year)
				if randf() < 0.1:
					_trigger_random_visual_event()

				# Scale robots with population
				_update_robot_count()

		# Continuous ambient events (storms, small visual effects)
		# About 0.5% chance per week (scaled by delta)
		var storm_check = randf() < 0.005 * _time_scale * delta
		if storm_check and colony_view:
			colony_view.trigger_event_effect("sandstorm", 2.0)

func _trigger_event_visual(event: Dictionary):
	"""Trigger visual effects based on event content"""
	if not colony_view:
		return

	var title = event.get("title", "").to_lower()
	var description = event.get("description", "").to_lower()
	var combined = title + " " + description

	if "storm" in combined or "dust" in combined or "sandstorm" in combined:
		colony_view.start_sandstorm()
	elif "rescue" in combined or "emergency" in combined or "accident" in combined:
		colony_view.trigger_event_effect("rescue", 5.0)
	elif "breakdown" in combined or "malfunction" in combined or "failure" in combined:
		colony_view.trigger_event_effect("crisis", 4.0)
	elif "construction" in combined or "build" in combined or "expand" in combined:
		colony_view.trigger_event_effect("construction", 3.0)

func _trigger_random_visual_event():
	"""Occasional random visual events for atmosphere"""
	if not colony_view:
		return

	var roll = randf()
	if roll < 0.3:
		# Brief dust devil
		colony_view.trigger_event_effect("sandstorm", 3.0)
	elif roll < 0.5:
		# Maintenance activity
		colony_view.trigger_event_effect("construction", 2.0)

func _update_robot_count():
	"""Scale robot count based on colony size"""
	if not colony_view or not colony_view.has_method("set_robot_count"):
		return

	var pop = _colony_store.get_colonist_count()
	var buildings = _colony_store.get_buildings().size()

	# 1 robot per 5 colonists or 3 buildings, minimum 3
	var target_robots = maxi(3, maxi(pop / 5, buildings / 3))
	colony_view.set_robot_count(target_robots)

func _init_log():
	if not colony_log:
		return
	colony_log.clear()
	var log_entries = _colony_store.get_colony_log()
	var start = maxi(0, log_entries.size() - 30)
	for i in range(start, log_entries.size()):
		_add_log_entry(log_entries[i])

# ============================================================================
# UI SYNC
# ============================================================================

func _sync_ui():
	if not _colony_store:
		return
	var state = _colony_store.get_state()
	if state.is_empty():
		return

	# Get data directly from state
	var colonists = state.colonists if state.has("colonists") else []
	var buildings = state.buildings if state.has("buildings") else []
	var resources = state.resources if state.has("resources") else {}

	# Track peak population
	_peak_population = maxi(_peak_population, colonists.size())

	# Update colony view with explicit data
	if colony_view and colony_view.has_method("update_state"):
		colony_view.update_state(buildings, colonists)

	# Calculate and display priorities
	_update_priority_alerts(state, resources, buildings, colonists)

	# Top bar - with null checks
	if phase_label:
		phase_label.text = "Era: %s" % _colony_store.get_phase_name()
	if year_label:
		# Show year and week for granular time display
		var week = _colony_store.get_week() if _colony_store else 1
		year_label.text = "Year %d, Week %d" % [state.current_year, week]
	if population_label:
		population_label.text = "Pop: %d" % colonists.size()
	if stability_label:
		var politics = state.get("politics", {})
		var stability = politics.get("stability", 75.0) if politics else 75.0
		stability_label.text = "Stability: %.0f%%" % stability
		# Color stability based on value
		if stability < 30:
			stability_label.modulate = Color.RED
		elif stability < 60:
			stability_label.modulate = Color.YELLOW
		else:
			stability_label.modulate = Color.GREEN

	# Resources
	_update_resources(resources)

	# Buildings
	_update_buildings(buildings)

	# Population tabs
	_update_colonists(colonists)
	_update_statistics(state)
	_update_politics(state)

	# Projections
	_update_projections()

	# Events
	var active_events = state.active_events if state.has("active_events") else []
	_update_events(active_events)

	# Button states
	_update_button_states(state)

func _update_resources(resources: Dictionary):
	if not resource_container:
		return
	for child in resource_container.get_children():
		child.queue_free()

	# Get projection for net flows
	var projection = _colony_store.project_next_year() if _colony_store else {}
	var net_resources = projection.get("net", {})
	var production = projection.get("production", {})
	var consumption = projection.get("consumption", {})

	# Match the actual resource keys from create_resource_stockpile
	var resource_order = ["food", "water", "oxygen", "fuel", "building_materials", "machine_parts", "medicine"]

	for resource_name in resource_order:
		if resources.has(resource_name) and resources[resource_name] > 0:
			var amount = resources[resource_name]
			var net = net_resources.get(resource_name, 0.0)
			var prod = production.get(resource_name, 0.0)
			var cons = consumption.get(resource_name, 0.0)

			var vbox = VBoxContainer.new()
			resource_container.add_child(vbox)

			# Main row: name, bar, amount
			var hbox = HBoxContainer.new()
			vbox.add_child(hbox)

			var name_label = Label.new()
			name_label.text = resource_name.capitalize()
			name_label.custom_minimum_size = Vector2(100, 0)
			name_label.add_theme_font_size_override("font_size", 16)
			hbox.add_child(name_label)

			var bar = ProgressBar.new()
			bar.custom_minimum_size = Vector2(60, 20)
			bar.max_value = 500.0  # Cap for display
			bar.value = minf(amount, 500.0)
			bar.show_percentage = false
			hbox.add_child(bar)

			var value_label = Label.new()
			value_label.text = "%.0f" % amount
			value_label.custom_minimum_size = Vector2(55, 0)
			value_label.add_theme_font_size_override("font_size", 16)
			hbox.add_child(value_label)

			# Flow indicator: +prod / -cons = net
			var flow_label = Label.new()
			var net_sign = "+" if net >= 0 else ""
			flow_label.text = "%s%.0f/yr" % [net_sign, net]
			flow_label.custom_minimum_size = Vector2(70, 0)
			flow_label.add_theme_font_size_override("font_size", 14)
			if net < 0:
				flow_label.modulate = Color.RED
			elif net > 0:
				flow_label.modulate = Color.GREEN
			else:
				flow_label.modulate = Color.GRAY
			hbox.add_child(flow_label)

			# Color bar based on amount (low = red, high = green)
			if amount < 50:
				bar.modulate = Color.RED
			elif amount < 150:
				bar.modulate = Color.YELLOW
			else:
				bar.modulate = Color.GREEN

func _update_buildings(buildings: Array):
	if not building_list:
		return
	building_list.clear()
	for building in buildings:
		var is_operational = building.get("is_operational", true)
		var construction_progress = building.get("construction_progress", 1.0)
		var status = ""
		if not is_operational:
			if construction_progress < 1.0:
				status = " [BUILDING %.0f%%]" % (construction_progress * 100)
			else:
				status = " [BROKEN]"

		var assigned_workers = building.get("assigned_workers", [])
		var workers = assigned_workers.size()
		var capacity = building.get("worker_capacity", 0)
		var worker_text = " (%d/%d)" % [workers, capacity] if capacity > 0 else ""

		var building_type = building.get("type", 0)
		var name = _MCSTypes.get_building_name(building_type)

		# Add production/consumption info (using full building for tier-aware stats)
		var output_text = _get_building_output_text(building)

		building_list.add_item("%s%s%s %s" % [name, worker_text, status, output_text])

		# Color based on status
		var idx = building_list.item_count - 1
		if not is_operational:
			building_list.set_item_custom_fg_color(idx, Color.ORANGE if construction_progress < 1.0 else Color.RED)

func _get_building_output_text(building: Dictionary) -> String:
	"""Get a short description based on ACTUAL tier stats"""
	var building_type = building.get("type", 0)
	var is_operational = building.get("is_operational", true)
	var tier = building.get("tier", 1)

	if not is_operational:
		return "[OFFLINE]"

	# Get tier stats for accurate production values
	var stats = _MCSTypes.get_tier_stats(building_type, tier)
	var tier_label = " T%d" % tier if tier > 1 else ""

	# Show upgrading status
	if building.get("upgrading", false):
		var progress = building.get("upgrade_progress", 0.0) * 100
		return "→ upgrading %.0f%%" % progress

	match building_type:
		# Housing - show actual capacity from tier stats
		_MCSTypes.BuildingType.HAB_POD, _MCSTypes.BuildingType.APARTMENT_BLOCK, \
		_MCSTypes.BuildingType.LUXURY_QUARTERS, _MCSTypes.BuildingType.BARRACKS:
			var capacity = stats.get("housing_capacity", 4)
			return "→ %d beds%s" % [capacity, tier_label]

		# Food production - show actual production from tier stats
		_MCSTypes.BuildingType.GREENHOUSE, _MCSTypes.BuildingType.HYDROPONICS, \
		_MCSTypes.BuildingType.PROTEIN_VATS:
			var prod = stats.get("production", {})
			var food = prod.get("food", 0)
			return "→ +%d food/yr%s" % [food, tier_label]

		# Power - show actual generation from tier stats
		_MCSTypes.BuildingType.SOLAR_ARRAY, _MCSTypes.BuildingType.WIND_TURBINE, \
		_MCSTypes.BuildingType.RTG, _MCSTypes.BuildingType.FISSION_REACTOR, \
		_MCSTypes.BuildingType.FUSION_REACTOR:
			var power = stats.get("power_gen", 0)
			return "→ +%d power%s" % [power, tier_label]

		# Water - show actual production from tier stats
		_MCSTypes.BuildingType.WATER_EXTRACTOR:
			var prod = stats.get("production", {})
			var water = prod.get("water", 0)
			return "→ +%d water/yr%s" % [water, tier_label]

		# Oxygen
		_MCSTypes.BuildingType.OXYGENATOR:
			var prod = stats.get("production", {})
			var oxygen = prod.get("oxygen", 0)
			return "→ +%d oxygen/yr%s" % [oxygen, tier_label]

		# Industry - show parts production
		_MCSTypes.BuildingType.WORKSHOP:
			var prod = stats.get("production", {})
			var parts = prod.get("machine_parts", 0)
			if parts > 0:
				return "→ +%d parts%s" % [parts, tier_label]
			return "→ repairs%s" % tier_label
		_MCSTypes.BuildingType.FACTORY:
			var prod = stats.get("production", {})
			var parts = prod.get("machine_parts", 0)
			var mats = prod.get("building_materials", 0)
			return "→ +%d parts +%d mats%s" % [parts, mats, tier_label]

		# Medical
		_MCSTypes.BuildingType.MEDICAL_BAY, _MCSTypes.BuildingType.HOSPITAL:
			var health = stats.get("health_boost", 0)
			return "→ +%d health%s" % [health, tier_label]

		# Science/Education
		_MCSTypes.BuildingType.LAB, _MCSTypes.BuildingType.RESEARCH_CENTER:
			var research = stats.get("research_boost", 0)
			return "→ +%d research%s" % [research, tier_label]
		_MCSTypes.BuildingType.SCHOOL:
			var edu = stats.get("education_capacity", 0)
			return "→ %d students%s" % [edu, tier_label]
		_MCSTypes.BuildingType.UNIVERSITY:
			return "→ +skills%s" % tier_label

		# Social
		_MCSTypes.BuildingType.RECREATION_CENTER:
			return "→ +morale%s" % tier_label
		_MCSTypes.BuildingType.TEMPLE:
			return "→ +stability"
		_MCSTypes.BuildingType.GOVERNMENT_HALL:
			return "→ governance"
		# Infrastructure
		_MCSTypes.BuildingType.LANDING_PAD:
			return "→ trade"
		_:
			return ""

func _update_colonists(colonists: Array):
	if not colonist_container:
		return

	for child in colonist_container.get_children():
		child.queue_free()

	if colonists.is_empty():
		return

	# Sort by generation then age
	var sorted = colonists.duplicate()
	sorted.sort_custom(func(a, b): return a.get("generation", 0) * 1000 + a.get("age", 0) < b.get("generation", 0) * 1000 + b.get("age", 0))

	for colonist in sorted:
		var panel = _create_colonist_entry(colonist)
		colonist_container.add_child(panel)

func _create_colonist_entry(colonist: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 30)

	var name_label = Label.new()
	name_label.text = "%s (%d)" % [colonist.get("display_name", "Unknown"), colonist.get("age", 0)]
	name_label.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(name_label)

	var generation = colonist.get("generation", 0)
	var gen_label = Label.new()
	gen_label.text = _MCSTypes.get_generation_name(generation)
	gen_label.custom_minimum_size = Vector2(80, 0)
	gen_label.modulate = _get_generation_color(generation)
	hbox.add_child(gen_label)

	var specialty_label = Label.new()
	specialty_label.text = _MCSTypes.get_specialty_name(colonist.get("specialty", 0))
	specialty_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(specialty_label)

	var effectiveness = _MCSPopulation.calc_effectiveness(colonist)
	var eff_label = Label.new()
	eff_label.text = "%.0f%%" % (effectiveness * 100)
	eff_label.modulate = Color.GREEN.lerp(Color.RED, 1.0 - effectiveness)
	hbox.add_child(eff_label)

	return hbox

func _get_generation_color(generation: int) -> Color:
	match generation:
		_MCSTypes.Generation.EARTH_BORN: return Color.GOLD
		_MCSTypes.Generation.FIRST_GEN: return Color.CYAN
		_MCSTypes.Generation.SECOND_GEN: return Color.GREEN
		_MCSTypes.Generation.THIRD_GEN_PLUS: return Color.YELLOW
		_: return Color.WHITE

func _update_statistics(state: Dictionary):
	if not _colony_store or not stats_label:
		return

	var gen_breakdown = _colony_store.get_generation_breakdown()
	var faction_breakdown = _colony_store.get_faction_breakdown()

	var text = "[b]Population Breakdown[/b]\n\n"

	text += "[u]By Generation:[/u]\n"
	for gen in _MCSTypes.Generation.values():
		var count = gen_breakdown.get(gen, 0)
		if count > 0:
			text += "  %s: %d\n" % [_MCSTypes.get_generation_name(gen), count]

	text += "\n[u]By Faction:[/u]\n"
	for faction in _MCSTypes.Faction.values():
		var count = faction_breakdown.get(faction, 0)
		if count > 0:
			text += "  %s: %d\n" % [_MCSTypes.get_faction_name(faction), count]

	text += "\n[u]Workforce:[/u]\n"
	var workforce = _colony_store.get_workforce()
	text += "  Workers: %d\n" % workforce.size()

	var children = 0
	var elderly = 0
	var colonists = state.get("colonists", [])
	for c in colonists:
		if c.get("life_stage", -1) == _MCSTypes.LifeStage.CHILD:
			children += 1
		elif c.get("life_stage", -1) == _MCSTypes.LifeStage.ELDER:
			elderly += 1
	text += "  Children: %d\n" % children
	text += "  Elderly: %d\n" % elderly

	stats_label.text = text

func _update_politics(state: Dictionary):
	if not politics_label:
		return

	var pol = state.get("politics", {})
	if pol.is_empty():
		return

	var text = "[b]Political Overview[/b]\n\n"

	text += "[u]Government:[/u] %s\n" % _MCSTypes.get_political_system_name(pol.get("system", 0))
	text += "[u]Stability:[/u] %.0f%%\n" % pol.get("stability", 75.0)
	text += "[u]Independence:[/u] %.0f%%\n\n" % pol.get("independence_sentiment", 0.0)

	if pol.get("current_leader", ""):
		text += "[u]Leader:[/u] %s\n" % pol.current_leader
	if pol.get("ruling_faction", -1) >= 0:
		text += "[u]Ruling Faction:[/u] %s\n\n" % _MCSTypes.get_faction_name(pol.ruling_faction)

	text += "[u]Faction Support:[/u]\n"
	var faction_standings = pol.get("faction_standings", {})
	for faction in _MCSTypes.Faction.values():
		var support = faction_standings.get(faction, 0.0)
		if support > 0:
			text += "  %s: %.0f%%\n" % [_MCSTypes.get_faction_name(faction), support * 100]

	politics_label.text = text

	# Button visibility
	if election_button:
		election_button.visible = state.get("current_year", 0) >= 5
	if independence_button:
		independence_button.visible = state.get("current_year", 0) >= 20 and pol.get("independence_sentiment", 0) >= 50

func _update_priority_alerts(state: Dictionary, resources: Dictionary, buildings: Array, colonists: Array):
	"""Calculate and display priority alerts based on colony state"""
	if not colony_view or not colony_view.has_method("set_priority_alerts"):
		return

	var alerts: Array = []
	var projection = _colony_store.project_next_year() if _colony_store else {}
	var net_resources = projection.get("net", {})

	# Check critical resources
	var critical_resources = ["food", "water", "oxygen"]
	for res_name in critical_resources:
		var amount = resources.get(res_name, 0)
		var net = net_resources.get(res_name, 0)
		var years_left = amount / absf(net) if net < 0 else 999

		if amount < 20:
			alerts.append({"priority": 2, "message": "%s CRITICAL" % res_name.capitalize(), "icon": "🔴"})
		elif amount < 50 or years_left < 2:
			alerts.append({"priority": 1, "message": "Low %s" % res_name, "icon": "⚠"})

	# Check housing
	var housing_dict = projection.get("housing_balance", {})
	var housing_available = housing_dict.get("available", 0)
	if housing_available < 0:
		alerts.append({"priority": 2, "message": "Housing shortage!", "icon": "🏠"})
	elif housing_available < 3:
		alerts.append({"priority": 1, "message": "Housing tight", "icon": "🏠"})

	# Check power
	var power_dict = projection.get("power_balance", {})
	var power_balance = power_dict.get("balance", 0)
	if power_balance < -10:
		alerts.append({"priority": 2, "message": "Power deficit!", "icon": "⚡"})
	elif power_balance < 0:
		alerts.append({"priority": 1, "message": "Low power", "icon": "⚡"})

	# Check broken buildings
	var broken_count = 0
	for b in buildings:
		if not b.get("is_operational", true) and not b.get("is_under_construction", false):
			broken_count += 1
	if broken_count > 0:
		var priority = 2 if broken_count > 2 else 1
		alerts.append({"priority": priority, "message": "%d broken" % broken_count, "icon": "🔧"})

	# Check population health/stability
	var politics = state.get("politics", {})
	var stability = politics.get("stability", 75.0)
	if stability < 30:
		alerts.append({"priority": 2, "message": "Unstable!", "icon": "📉"})
	elif stability < 50:
		alerts.append({"priority": 1, "message": "Unrest", "icon": "📉"})

	# Positive alerts (info level)
	if colonists.size() > 0 and alerts.is_empty():
		var food_years = projection.get("food_surplus_years", 0)
		if food_years > 5:
			alerts.append({"priority": 0, "message": "Stable", "icon": "✓"})

	# Construction in progress (info)
	var under_construction = 0
	for b in buildings:
		if b.get("is_under_construction", false):
			under_construction += 1
	if under_construction > 0:
		alerts.append({"priority": 0, "message": "Building %d" % under_construction, "icon": "🔨"})

	# Sort by priority (critical first)
	alerts.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))

	# Limit to top 4 alerts
	if alerts.size() > 4:
		alerts.resize(4)

	colony_view.set_priority_alerts(alerts)

func _update_projections():
	if not _colony_store or not projection_label:
		return

	var projection = _colony_store.project_next_year()
	if projection.is_empty():
		return

	var text = "[b]Next Year Forecast[/b]\n\n"

	text += "[u]Net Resources:[/u]\n"
	var net_resources = projection.get("net", {})
	for key in net_resources.keys():
		var net = net_resources[key]
		var color = "green" if net >= 0 else "red"
		var sign = "+" if net >= 0 else ""
		text += "  %s: [color=%s]%s%.0f[/color]\n" % [key.capitalize(), color, sign, net]

	text += "\n[u]Capacity:[/u]\n"
	# power_balance and housing_balance are dictionaries with .balance and .available keys
	var power_dict = projection.get("power_balance", {})
	var housing_dict = projection.get("housing_balance", {})
	var power = power_dict.get("balance", 0.0)
	var housing = housing_dict.get("available", 0)
	text += "  Power: [color=%s]%s%.0f[/color]\n" % ["green" if power >= 0 else "red", "+" if power >= 0 else "", power]
	text += "  Housing: [color=%s]%s%d[/color]\n" % ["green" if housing >= 0 else "red", "+" if housing >= 0 else "", housing]

	text += "\n[u]Food Security:[/u] %.1f years" % projection.get("food_surplus_years", 0.0)

	projection_label.text = text

func _update_events(active_events: Array):
	if not choice_container:
		return

	# Clear existing choice buttons
	for child in choice_container.get_children():
		child.queue_free()

	if active_events.is_empty():
		if event_title:
			event_title.text = "No Active Event"
		if event_description:
			event_description.text = "Events will appear here as the colony develops."
		return

	var event = active_events[0]  # Show first active event
	if event_title:
		event_title.text = event.get("title", "Event")
	if event_description:
		event_description.text = event.get("description", "")

	# Create choice buttons
	var choices = event.get("choices", [])
	var event_id = event.get("id", "")
	for i in range(choices.size()):
		var choice = choices[i]
		var button = Button.new()
		button.text = choice.get("text", "Option %d" % i)
		button.pressed.connect(func(): _on_choice_selected(event_id, i))
		choice_container.add_child(button)

func _update_button_states(state: Dictionary):
	# Disable controls during events that need resolution
	var events = state.get("active_events", [])
	var has_active_event = events.size() > 0

	if auto_button:
		auto_button.disabled = has_active_event

	# Don't disable auto-advance in AI mode - AI handles events
	if has_active_event and _auto_advance and not _ai_enabled:
		_auto_advance = false
		if auto_button:
			auto_button.button_pressed = false

	# Repair button
	if repair_button:
		repair_button.disabled = _selected_building_idx < 0

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_state_changed(_new_state: Dictionary):
	_sync_ui()

func _on_year_advanced(year: int):
	if year_label:
		year_label.text = "Year: %d" % year

func _on_event_triggered(event: Dictionary):
	_update_events([event])
	# In AI mode, don't pause - AI will handle it
	if _ai_enabled:
		# AI will resolve in next frame
		return
	# In manual mode, pause auto-advance during events
	if _auto_advance:
		_auto_advance = false
		if auto_button:
			auto_button.button_pressed = false

func _on_event_resolved(_event_id: String, _choice: int, outcome: String):
	if _colony_store:
		_add_log_entry({"year": _colony_store.get_year(), "message": outcome, "log_type": "event"})
	_sync_ui()

func _on_game_ended(is_victory: bool, reason: String):
	_auto_advance = false
	if auto_button:
		auto_button.button_pressed = false

	if game_over_overlay:
		game_over_overlay.visible = true
	if game_over_title:
		game_over_title.text = "VICTORY!" if is_victory else "COLONY LOST"
		game_over_title.modulate = Color.GOLD if is_victory else Color.RED
	if game_over_reason:
		game_over_reason.text = reason
	if game_over_stats and _colony_store:
		game_over_stats.text = "Years survived: %d\nPeak population: %d\nFinal population: %d" % [
			_colony_store.get_year(),
			_peak_population,
			_colony_store.get_colonist_count()
		]

func _on_log_entry(entry: Dictionary):
	_add_log_entry(entry)
	_trigger_visual_for_log(entry)

func _add_log_entry(entry: Dictionary):
	if not colony_log:
		return
	var color = "white"
	match entry.get("log_type", "info"):
		"crisis": color = "red"
		"death": color = "orange"
		"birth": color = "cyan"
		"milestone": color = "gold"
		"political": color = "purple"
		"event": color = "yellow"
		"success": color = "green"
		"info": color = "gray"

	colony_log.append_text("[color=%s][Year %d] %s[/color]\n" % [color, entry.get("year", 0), entry.get("message", "")])

func _trigger_visual_for_log(entry: Dictionary):
	"""Trigger visual effects based on log entries"""
	if not colony_view:
		return

	var log_type = entry.get("log_type", "info")
	var message = entry.get("message", "").to_lower()

	# Check for specific visual triggers
	match log_type:
		"crisis":
			# Crisis events - show flashing alerts
			if "storm" in message or "sandstorm" in message or "dust" in message:
				colony_view.start_sandstorm()
			elif "rescue" in message or "lost" in message or "stranded" in message:
				colony_view.trigger_event_effect("rescue", 6.0)
			elif "breakdown" in message or "malfunction" in message or "damaged" in message:
				# Find a broken building and highlight it
				var buildings = _colony_store.get_buildings()
				for b in buildings:
					if not b.get("is_operational", true):
						colony_view.trigger_building_crisis(b.get("id", ""))
						break
			else:
				colony_view.trigger_event_effect("crisis", 4.0)
		"death":
			# Death - brief crisis effect
			colony_view.trigger_event_effect("crisis", 2.0)
		"birth":
			# Birth - celebration particles
			colony_view.trigger_event_effect("construction", 3.0)
		"milestone":
			# Achievement - lots of activity
			colony_view.trigger_event_effect("construction", 5.0)

func _on_auto_toggled(toggled: bool):
	_auto_advance = toggled
	# Time continues from where it left off (no reset needed)

func _on_ai_toggled(toggled: bool):
	set_ai_enabled(toggled)
	# When AI is enabled, also enable auto-advance for real-time play
	if toggled and not _auto_advance:
		_auto_advance = true
		auto_button.button_pressed = true

	# Log the change
	if toggled:
		_add_log_entry({
			"year": _colony_store.get_year(),
			"message": "AI Governor resumed control.",
			"log_type": "political"
		})
	else:
		_add_log_entry({
			"year": _colony_store.get_year(),
			"message": "Manual control restored.",
			"log_type": "political"
		})

func _on_ai_personality_changed(index: int):
	var personality = _MCSAI.Personality.PRAGMATIST
	match index:
		0: personality = _MCSAI.Personality.PRAGMATIST
		1: personality = _MCSAI.Personality.VISIONARY
		2: personality = _MCSAI.Personality.HUMANIST
		3: personality = _MCSAI.Personality.CAUTIOUS

	var old_name = _MCSAI.get_personality_name(_ai_personality)
	set_ai_personality(personality)
	var new_name = _MCSAI.get_personality_name(personality)

	if old_name != new_name:
		_add_log_entry({
			"year": _colony_store.get_year(),
			"message": "AI Governor changed: %s -> %s" % [old_name, new_name],
			"log_type": "political"
		})

func _on_speed_changed(value: float):
	# Time scale: 1x = 2 weeks/sec (~26 sec/year), 10x = 20 weeks/sec (~2.6 sec/year)
	_time_scale = 2.0 * value
	if speed_label:
		speed_label.text = "%dx" % int(value)

func _on_auto_assign_workers():
	_colony_store.auto_assign_workers()
	_sync_ui()

func _on_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_restart():
	game_over_overlay.visible = false
	_peak_population = 0
	_game_weeks = 0.0
	_last_processed_week = 1
	_colony_store.start_new_colony(24)  # EPIC: 24 founders for faster progression!
	colony_log.clear()
	_init_log()
	_sync_ui()

func _on_building_selected(index: int):
	_selected_building_idx = index
	repair_button.disabled = false

func _on_build_pressed():
	build_dialog.visible = true
	_populate_build_types()

func _on_repair_pressed():
	if _selected_building_idx < 0:
		return

	var buildings = _colony_store.get_buildings()
	if _selected_building_idx < buildings.size():
		var building = buildings[_selected_building_idx]
		_colony_store.repair_building(building.id)

func _on_auto_repair_pressed():
	"""Repair all broken buildings automatically"""
	_auto_repair_all()
	_sync_ui()

func _auto_repair_all():
	"""Silent auto-repair for idle mode"""
	if not _colony_store:
		return
	var buildings = _colony_store.get_buildings()
	for building in buildings:
		if not building.get("is_operational", true) and building.get("construction_progress", 1.0) >= 1.0:
			_colony_store.repair_building(building.id)

func _on_build_type_selected(index: int):
	_selected_build_type = index
	_update_build_cost()

func _on_build_cancel():
	build_dialog.visible = false
	_selected_build_type = -1

func _on_build_confirm():
	if _selected_build_type >= 0:
		var building_types = _MCSTypes.BuildingType.values()
		if _selected_build_type < building_types.size():
			_colony_store.start_construction(building_types[_selected_build_type])
	build_dialog.visible = false
	_selected_build_type = -1

func _populate_build_types():
	build_type_list.clear()
	for building_type in _MCSTypes.BuildingType.values():
		build_type_list.add_item(_MCSTypes.get_building_name(building_type))

func _update_build_cost():
	if _selected_build_type < 0:
		cost_label.text = "Select a building type"
		return

	# Building costs (simplified)
	var costs = {
		_MCSTypes.BuildingType.HAB_POD: {"materials": 50, "power": 10},
		_MCSTypes.BuildingType.APARTMENT_BLOCK: {"materials": 100, "power": 25},
		_MCSTypes.BuildingType.GREENHOUSE: {"materials": 40, "power": 15},
		_MCSTypes.BuildingType.HYDROPONICS: {"materials": 60, "power": 20},
		_MCSTypes.BuildingType.SOLAR_ARRAY: {"materials": 30, "power": 0},
		_MCSTypes.BuildingType.FISSION_REACTOR: {"materials": 150, "power": 0},
		_MCSTypes.BuildingType.WATER_EXTRACTOR: {"materials": 60, "power": 20},
		_MCSTypes.BuildingType.WORKSHOP: {"materials": 70, "power": 15},
		_MCSTypes.BuildingType.FACTORY: {"materials": 120, "power": 30},
		_MCSTypes.BuildingType.MEDICAL_BAY: {"materials": 100, "power": 20},
		_MCSTypes.BuildingType.SCHOOL: {"materials": 60, "power": 10},
		_MCSTypes.BuildingType.LAB: {"materials": 90, "power": 25},
		_MCSTypes.BuildingType.GOVERNMENT_HALL: {"materials": 120, "power": 30},
		_MCSTypes.BuildingType.LANDING_PAD: {"materials": 200, "power": 50},
	}

	var building_types = _MCSTypes.BuildingType.values()
	if _selected_build_type < building_types.size():
		var type = building_types[_selected_build_type]
		var cost = costs.get(type, {"materials": 50, "power": 10})
		cost_label.text = "Cost: %d materials, %d power/yr" % [cost.materials, cost.power]

func _on_choice_selected(event_id: String, choice_index: int):
	_colony_store.resolve_event(event_id, choice_index)

func _on_election():
	_colony_store.hold_election()

func _on_independence_vote():
	_colony_store.hold_independence_vote()

# ============================================================================
# AI SPECTATE MODE
# ============================================================================

func _ai_resolve_pending_events():
	"""Have AI automatically resolve any pending events"""
	var active_events = _colony_store.get_active_events()
	var state = _colony_store.get_state()

	for event in active_events:
		var choice_idx = _MCSAI.choose_event_option(
			event,
			state,
			_ai_personality,
			_ai_rng.randf()
		)

		# Log AI decision
		if choice_idx < event.choices.size():
			var choice = event.choices[choice_idx]
			_add_log_entry({
				"year": _colony_store.get_year(),
				"message": "AI chose: %s" % choice.text,
				"log_type": "info"
			})

		_colony_store.resolve_event(event.id, choice_idx)
		state = _colony_store.get_state()  # Refresh state

func _ai_maybe_build():
	"""Have AI potentially construct a building"""
	var state = _colony_store.get_state()

	# 30% chance to consider building
	if _ai_rng.randf() > 0.3:
		return

	var building_type = _MCSAI.choose_building(
		state,
		_ai_personality,
		_ai_rng.randf()
	)

	if building_type >= 0:
		if _colony_store.start_construction(building_type):
			_add_log_entry({
				"year": _colony_store.get_year(),
				"message": "AI built: %s" % _MCSTypes.get_building_name(building_type),
				"log_type": "info"
			})

func set_ai_enabled(enabled: bool):
	"""Enable or disable AI spectate mode"""
	_ai_enabled = enabled
	if enabled:
		_ai_rng.seed = int(Time.get_unix_time_from_system())
		_add_log_entry({
			"year": _colony_store.get_year(),
			"message": "AI Governor (%s) taking control" % _MCSAI.get_personality_name(_ai_personality),
			"log_type": "milestone"
		})

func set_ai_personality(personality: _MCSAI.Personality):
	"""Set the AI personality"""
	_ai_personality = personality
	if _ai_enabled:
		_add_log_entry({
			"year": _colony_store.get_year(),
			"message": "AI Governor personality: %s" % _MCSAI.get_personality_name(_ai_personality),
			"log_type": "info"
		})

func is_ai_enabled() -> bool:
	return _ai_enabled

func get_ai_personality() -> _MCSAI.Personality:
	return _ai_personality

func start_spectate_mode(personality: _MCSAI.Personality = _MCSAI.Personality.PRAGMATIST):
	"""Start full spectate mode - AI controls everything, auto-advance enabled"""
	_ai_personality = personality
	_ai_enabled = true
	_auto_advance = true
	_ai_rng.seed = int(Time.get_unix_time_from_system())

	# Update UI
	auto_button.button_pressed = true

	_add_log_entry({
		"year": _colony_store.get_year(),
		"message": "=== SPECTATE MODE: %s Governor ===" % _MCSAI.get_personality_name(_ai_personality),
		"log_type": "milestone"
	})

	_sync_ui()
