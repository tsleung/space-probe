extends Control
class_name MOTMain

## Mars Odyssey Trek - Phase 1 Main Controller
## Orchestrates the 7 decision steps of ship preparation
## Manages scene transitions, budget display, and readiness state

# Explicit preloads to ensure dependencies are loaded
const MOTStoreScript = preload("res://scripts/mars_odyssey_trek/mot_store.gd")
const LaunchAnimationScript = preload("res://scripts/mars_odyssey_trek/launch_animation.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal phase1_completed(final_state: Dictionary)
signal decision_changed(step: int)
signal back_to_menu_requested()

# ============================================================================
# ENUMS
# ============================================================================

enum Step {
	LAUNCH_WINDOW,
	CONSTRUCTION,
	ENGINE,
	SHIP_CLASS,
	LIFE_SUPPORT,
	CREW,
	CARGO,
	REVIEW
}

const STEP_NAMES = {
	Step.LAUNCH_WINDOW: "Launch Window",
	Step.CONSTRUCTION: "Construction",
	Step.ENGINE: "Engine",
	Step.SHIP_CLASS: "Ship Class",
	Step.LIFE_SUPPORT: "Life Support",
	Step.CREW: "Crew",
	Step.CARGO: "Cargo",
	Step.REVIEW: "Review"
}

const STEP_SCENES = {
	Step.LAUNCH_WINDOW: "res://scenes/mars_odyssey_trek/orbital_selector.tscn",
	Step.CONSTRUCTION: "res://scenes/mars_odyssey_trek/approach_selector.tscn",
	Step.ENGINE: "res://scenes/mars_odyssey_trek/engine_selector.tscn",
	Step.SHIP_CLASS: "res://scenes/mars_odyssey_trek/ship_class_selector.tscn",
	Step.LIFE_SUPPORT: "res://scenes/mars_odyssey_trek/life_support_selector.tscn",
	Step.CREW: "res://scenes/mars_odyssey_trek/crew_selector.tscn",
	Step.CARGO: "res://scenes/mars_odyssey_trek/cargo_loader.tscn",
	Step.REVIEW: "res://scenes/mars_odyssey_trek/launch_review.tscn"
}

# ============================================================================
# STATE
# ============================================================================

var store: Node  # MOTStore instance
var current_step: Step = Step.LAUNCH_WINDOW
var current_scene: Control = null

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var scene_container: Control = %SceneContainer
@onready var budget_label: Label = %BudgetLabel
@onready var step_indicator: HBoxContainer = %StepIndicator
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var menu_button: Button = %MenuButton

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_initialize_store()
	_setup_ui()
	_load_step(Step.LAUNCH_WINDOW)

func _initialize_store() -> void:
	store = MOTStore.new()
	add_child(store)

	# Connect to store signals
	store.state_changed.connect(_on_state_changed)
	store.budget_changed.connect(_on_budget_changed)
	store.readiness_changed.connect(_on_readiness_changed)

func _setup_ui() -> void:
	# Connect navigation buttons
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	_update_navigation_buttons()
	_update_budget_display()
	_update_step_indicator()

# ============================================================================
# STEP NAVIGATION
# ============================================================================

func _load_step(step: Step) -> void:
	current_step = step

	# Unload current scene
	if current_scene:
		current_scene.queue_free()
		current_scene = null

	# Load new scene
	var scene_path = STEP_SCENES[step]
	if ResourceLoader.exists(scene_path):
		var packed_scene = load(scene_path)
		current_scene = packed_scene.instantiate()
		scene_container.add_child(current_scene)
		_connect_step_scene(step, current_scene)
	else:
		push_warning("MOTMain: Scene not found: %s" % scene_path)
		_show_placeholder(step)

	_update_navigation_buttons()
	_update_step_indicator()
	decision_changed.emit(step)

func _connect_step_scene(step: Step, scene: Control) -> void:
	## Connect signals from decision scenes to store actions
	match step:
		Step.LAUNCH_WINDOW:
			if scene.has_signal("window_selected"):
				scene.window_selected.connect(_on_launch_window_selected)
			if scene.has_signal("launch_now_pressed"):
				scene.launch_now_pressed.connect(_on_launch_window_selected)
		Step.CONSTRUCTION:
			if scene.has_signal("approach_selected"):
				scene.approach_selected.connect(_on_construction_selected)
		Step.ENGINE:
			if scene.has_signal("engine_selected"):
				scene.engine_selected.connect(_on_engine_selected)
		Step.SHIP_CLASS:
			if scene.has_signal("ship_class_selected"):
				scene.ship_class_selected.connect(_on_ship_class_selected)
			if scene.has_signal("upgrade_toggled"):
				scene.upgrade_toggled.connect(_on_upgrade_toggled)
		Step.LIFE_SUPPORT:
			if scene.has_signal("tier_selected"):
				scene.tier_selected.connect(_on_life_support_selected)
		Step.CREW:
			if scene.has_signal("crew_changed"):
				scene.crew_changed.connect(_on_crew_changed)
		Step.CARGO:
			if scene.has_signal("cargo_changed"):
				scene.cargo_changed.connect(_on_cargo_changed)
		Step.REVIEW:
			if scene.has_signal("launch_pressed"):
				scene.launch_pressed.connect(_on_launch_pressed)

	# Pass store reference to scene if it needs it
	if scene.has_method("set_store"):
		scene.set_store(store)

	# Initialize scene with current state
	if scene.has_method("initialize_from_state"):
		scene.initialize_from_state(store.get_state())

func _show_placeholder(step: Step) -> void:
	## Show placeholder for unbuilt scenes
	var placeholder = VBoxContainer.new()
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.alignment = BoxContainer.ALIGNMENT_CENTER

	var title = Label.new()
	title.text = STEP_NAMES[step]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	placeholder.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "(Coming Soon)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	placeholder.add_child(subtitle)

	scene_container.add_child(placeholder)
	current_scene = placeholder

func go_to_step(step: Step) -> void:
	if step >= Step.LAUNCH_WINDOW and step <= Step.REVIEW:
		_load_step(step)

func next_step() -> void:
	if current_step < Step.REVIEW:
		_load_step(current_step + 1 as Step)

func prev_step() -> void:
	if current_step > Step.LAUNCH_WINDOW:
		_load_step(current_step - 1 as Step)

# ============================================================================
# UI UPDATES
# ============================================================================

func _update_navigation_buttons() -> void:
	if prev_button:
		prev_button.disabled = current_step == Step.LAUNCH_WINDOW
		prev_button.text = "< Back"

	if next_button:
		if current_step == Step.REVIEW:
			next_button.visible = false  # Review has launch button instead
		else:
			next_button.visible = true
			next_button.text = "Next >"

func _update_budget_display() -> void:
	if not budget_label:
		return

	var state = store.get_state()
	var remaining = state.get("budget_remaining", 0)
	var total = state.get("budget_total", 0)

	budget_label.text = "$%s / $%s" % [
		_format_money(remaining),
		_format_money(total)
	]

	# Color based on budget health
	if remaining < 0:
		budget_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	elif remaining < total * 0.2:
		budget_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		budget_label.remove_theme_color_override("font_color")

func _update_step_indicator() -> void:
	if not step_indicator:
		return

	# Clear existing indicators
	for child in step_indicator.get_children():
		child.queue_free()

	# Create step indicators
	for step in Step.values():
		var indicator = _create_step_dot(step)
		step_indicator.add_child(indicator)

func _create_step_dot(step: int) -> Control:
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)

	# Color based on completion/current state
	var state = store.get_state()
	var is_complete = _is_step_complete(step, state)
	var is_current = step == current_step

	if is_current:
		dot.color = Color(0.3, 0.6, 1.0)  # Blue for current
	elif is_complete:
		dot.color = Color(0.3, 0.8, 0.3)  # Green for complete
	else:
		dot.color = Color(0.4, 0.4, 0.4)  # Gray for incomplete

	container.add_child(dot)

	# Step label below dot
	var label = Label.new()
	label.text = STEP_NAMES[step].substr(0, 4)  # First 4 chars
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_current:
		label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	container.add_child(label)

	# Make clickable
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(50, 40)
	button.pressed.connect(func(): go_to_step(step as Step))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(button)
	button.set_anchors_preset(Control.PRESET_FULL_RECT)

	return container

func _is_step_complete(step: int, state: Dictionary) -> bool:
	match step:
		Step.LAUNCH_WINDOW:
			return state.get("launch_window") != null
		Step.CONSTRUCTION:
			return state.get("construction_approach") != null
		Step.ENGINE:
			return state.get("engine") != null
		Step.SHIP_CLASS:
			return state.get("ship_class") != null
		Step.LIFE_SUPPORT:
			return state.get("life_support") != null
		Step.CREW:
			return state.get("crew", []).size() >= 4
		Step.CARGO:
			return state.get("cargo_manifest", {}).get("food_days", 0) >= 400
		Step.REVIEW:
			return false  # Never "complete" - it's the launch point
	return false

func _format_money(amount: int) -> String:
	if amount >= 1000000000:
		return "%.1fB" % (amount / 1000000000.0)
	elif amount >= 1000000:
		return "%.0fM" % (amount / 1000000.0)
	elif amount >= 1000:
		return "%.0fK" % (amount / 1000.0)
	return str(amount)

# ============================================================================
# STORE ACTION HANDLERS
# ============================================================================

func _on_launch_window_selected(window: RefCounted) -> void:
	store.set_launch_window(window)

func _on_construction_selected(approach: int) -> void:
	store.set_construction_approach(approach)

func _on_engine_selected(engine: int) -> void:
	store.set_engine(engine)

func _on_ship_class_selected(ship_class: int) -> void:
	store.set_ship_class(ship_class)

func _on_upgrade_toggled(upgrade_id: String, enabled: bool) -> void:
	if enabled:
		store.add_upgrade(upgrade_id)
	else:
		store.remove_upgrade(upgrade_id)

func _on_life_support_selected(tier: int) -> void:
	store.set_life_support(tier)

func _on_crew_changed(crew_ids: Array) -> void:
	# Clear existing and add new
	var state = store.get_state()
	for existing_id in state.get("crew", []):
		store.remove_crew_member(existing_id)
	for new_id in crew_ids:
		store.add_crew_member(new_id)

func _on_cargo_changed(category: String, amount: int) -> void:
	store.set_cargo(category, amount)

func _on_launch_pressed() -> void:
	if store.can_launch():
		_play_launch_animation()

func _play_launch_animation() -> void:
	# Hide normal UI
	if scene_container:
		for child in scene_container.get_children():
			child.queue_free()

	# Load and play animation
	var anim_scene = load("res://scenes/mars_odyssey_trek/launch_animation.tscn")
	var animation = anim_scene.instantiate() as LaunchAnimation
	scene_container.add_child(animation)

	# Pass mission state to animation
	animation.set_state(store.get_state())
	animation.animation_complete.connect(_on_animation_complete)
	animation.play_animation(store.get_state())

	# Hide navigation during animation
	if prev_button:
		prev_button.visible = false
	if next_button:
		next_button.visible = false
	if step_indicator:
		step_indicator.visible = false

func _on_animation_complete() -> void:
	var final_state = store.get_state()
	store.launch()
	phase1_completed.emit(final_state)
	# TODO: Transition to Phase 2 scene
	# For now, return to menu with a message
	print("Phase 1 complete! Transitioning to Phase 2...")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ============================================================================
# STORE SIGNAL HANDLERS
# ============================================================================

func _on_state_changed(_new_state: Dictionary) -> void:
	_update_step_indicator()

func _on_budget_changed(_remaining: int) -> void:
	_update_budget_display()

func _on_readiness_changed(is_ready: bool, issues: Array) -> void:
	# Update next button state on review step
	if current_step == Step.REVIEW and current_scene and current_scene.has_method("set_readiness"):
		current_scene.set_readiness(is_ready, issues)

# ============================================================================
# NAVIGATION HANDLERS
# ============================================================================

func _on_prev_pressed() -> void:
	prev_step()

func _on_next_pressed() -> void:
	next_step()

func _on_menu_pressed() -> void:
	back_to_menu_requested.emit()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ============================================================================
# PUBLIC API
# ============================================================================

func start_new_game(difficulty: String = "normal") -> void:
	store.start_new_game(difficulty)
	_load_step(Step.LAUNCH_WINDOW)
	_update_budget_display()
	_update_step_indicator()

func get_store() -> MOTStore:
	return store
