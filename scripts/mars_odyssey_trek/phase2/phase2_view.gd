extends Control
class_name Phase2View

## Phase 2: Travel to Mars - View Layer
## Handles all visual updates and UI rendering
## Receives state changes via signals from Phase2Store

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

# ============================================================================
# COLORS
# ============================================================================

const COLOR_HEALTHY = Color(0.3, 0.8, 0.3)
const COLOR_CAUTION = Color(0.9, 0.7, 0.2)
const COLOR_WARNING = Color(0.9, 0.5, 0.2)
const COLOR_CRITICAL = Color(0.9, 0.2, 0.2)
const COLOR_DEPLETED = Color(0.4, 0.4, 0.4)
const COLOR_EARTH = Color(0.3, 0.5, 0.9)
const COLOR_MARS = Color(0.8, 0.4, 0.2)

# ============================================================================
# STORE REFERENCE
# ============================================================================

var store: Node = null

# ============================================================================
# NODES (populated via _ready or scene references)
# ============================================================================

@onready var day_counter: Label = $UI/DayCounter if has_node("UI/DayCounter") else null
@onready var days_remaining: Label = $UI/DaysRemaining if has_node("UI/DaysRemaining") else null
@onready var journey_bar: Control = $UI/JourneyBar if has_node("UI/JourneyBar") else null
@onready var ship_marker: Node2D = $UI/JourneyBar/ShipMarker if has_node("UI/JourneyBar/ShipMarker") else null
@onready var earth_dot: Node2D = $UI/JourneyBar/EarthDot if has_node("UI/JourneyBar/EarthDot") else null
@onready var mars_dot: Node2D = $UI/JourneyBar/MarsDot if has_node("UI/JourneyBar/MarsDot") else null
@onready var resource_panel: Control = $UI/ResourcePanel if has_node("UI/ResourcePanel") else null
@onready var crew_panel: Control = $UI/CrewPanel if has_node("UI/CrewPanel") else null
@onready var storage_panel: Control = $UI/StoragePanel if has_node("UI/StoragePanel") else null
@onready var event_popup: PanelContainer = $UI/EventPopup if has_node("UI/EventPopup") else null
@onready var star_field: Node2D = $StarField if has_node("StarField") else null
@onready var mars_sprite: Node2D = $MarsApproach if has_node("MarsApproach") else null

# Star parallax data
var stars: Array = []
const STAR_COUNT = 200

# Visual state
var shake_intensity: float = 0.0
var shake_decay: float = 8.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_star_field()

	# Hide event popup initially
	if event_popup:
		event_popup.visible = false

	# Start with Mars invisible
	if mars_sprite:
		mars_sprite.modulate.a = 0.0

func connect_to_store(p_store: Node) -> void:
	## Connect to a Phase2Store instance
	store = p_store

	# Connect to store signals
	store.state_changed.connect(_on_state_changed)
	store.day_advanced.connect(_on_day_advanced)
	store.event_triggered.connect(_on_event_triggered)
	store.event_resolved.connect(_on_event_resolved)
	store.container_blocked.connect(_on_container_blocked)
	store.container_restored.connect(_on_container_restored)
	store.repair_started.connect(_on_repair_started)
	store.repair_completed.connect(_on_repair_completed)
	store.mars_visible.connect(_on_mars_visible)
	store.arrival.connect(_on_arrival)
	store.log_added.connect(_on_log_added)

	# Initial sync
	_sync_all(store.get_state())

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_state_changed(new_state: Dictionary) -> void:
	_sync_all(new_state)

func _on_day_advanced(day: int) -> void:
	_animate_day_change()

func _on_event_triggered(event: Dictionary) -> void:
	_show_event_popup(event)
	shake_screen(8.0)

func _on_event_resolved(_choice_index: int) -> void:
	_hide_event_popup()
	shake_screen(5.0)

func _on_container_blocked(container: Dictionary) -> void:
	shake_screen(15.0)
	print("[VIEW] Container blocked: %s" % container.name)

func _on_container_restored(container: Dictionary) -> void:
	shake_screen(5.0)
	print("[VIEW] Container restored: %s" % container.name)

func _on_repair_started(container_id: String, days: int) -> void:
	print("[VIEW] Repair started on %s, %d days" % [container_id, days])

func _on_repair_completed(container_id: String) -> void:
	print("[VIEW] Repair completed: %s" % container_id)

func _on_mars_visible() -> void:
	print("[VIEW] Mars is now visible!")

func _on_arrival() -> void:
	print("[VIEW] Arrived at Mars!")

func _on_log_added(entry: Dictionary) -> void:
	print("[Day %d] %s" % [entry.get("day", 0), entry.get("message", "")])

# ============================================================================
# SYNC FUNCTIONS
# ============================================================================

func _sync_all(state: Dictionary) -> void:
	_sync_day_counter(state)
	_sync_journey_bar(state)
	_sync_resources(state)
	_sync_storage(state)
	_sync_crew(state)
	_sync_mars_approach(state)

func _sync_day_counter(state: Dictionary) -> void:
	if day_counter:
		day_counter.text = "Day %d / %d" % [state.current_day, state.total_days]
	if days_remaining:
		var remaining = state.total_days - state.current_day
		days_remaining.text = "%d days remaining" % remaining

func _sync_journey_bar(state: Dictionary) -> void:
	if not journey_bar:
		return

	var bar_width = journey_bar.size.x
	var padding = 20.0
	var y_center = 25.0

	# Position Earth at left edge, Mars at right edge
	if earth_dot:
		earth_dot.position = Vector2(padding, y_center)
	if mars_dot:
		mars_dot.position = Vector2(bar_width - padding, y_center)

	# Position ship based on journey progress
	if ship_marker:
		var progress = float(state.current_day) / float(state.total_days)
		var travel_width = bar_width - (padding * 2)
		var ship_x = padding + (travel_width * progress)
		ship_marker.position = Vector2(ship_x, y_center)

func _sync_resources(state: Dictionary) -> void:
	if not resource_panel:
		return

	var resources = state.resources
	_update_resource_bar("FoodBar", resources.food.current, resources.food.max)
	_update_resource_bar("WaterBar", resources.water.current, resources.water.max)
	_update_resource_bar("OxygenBar", resources.oxygen.current, resources.oxygen.max)
	_update_resource_bar("PowerBar", resources.power.current, resources.power.max)
	_update_resource_bar("FuelBar", resources.fuel.current, resources.fuel.max)

func _update_resource_bar(bar_name: String, current: float, max_val: float) -> void:
	var bar_container = resource_panel.get_node_or_null(bar_name)
	if not bar_container:
		return

	var bar = bar_container.get_node_or_null("Bar") as ProgressBar
	if bar:
		var percent = current / max(max_val, 1.0)
		bar.value = percent * 100
		_color_progress_bar(bar, percent)

func _color_progress_bar(bar: ProgressBar, percent: float) -> void:
	var stylebox = bar.get_theme_stylebox("fill")
	if stylebox is StyleBoxFlat:
		if percent > 0.5:
			stylebox.bg_color = COLOR_HEALTHY
		elif percent > 0.25:
			stylebox.bg_color = COLOR_CAUTION
		elif percent > 0.1:
			stylebox.bg_color = COLOR_WARNING
		else:
			stylebox.bg_color = COLOR_CRITICAL

func _sync_storage(state: Dictionary) -> void:
	if not storage_panel:
		return

	for i in range(state.storage_containers.size()):
		var container = state.storage_containers[i]
		var container_node = storage_panel.get_node_or_null("Container%d" % i)
		if not container_node:
			continue

		var name_label = container_node.get_node_or_null("Name") as Label
		var status_label = container_node.get_node_or_null("Status") as Label

		if name_label:
			if container.accessible:
				name_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			else:
				name_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				var status_name = Phase2Types.get_container_status_name(container.status)
				name_label.text = "%s [%s]" % [container.name, status_name.to_upper()]

		if status_label:
			if container.accessible:
				status_label.text = "%d food | %d water" % [container.food, container.water]
				status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			else:
				status_label.text = "INACCESSIBLE - %d food | %d water trapped" % [container.food, container.water]
				status_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))

func _sync_crew(state: Dictionary) -> void:
	if not crew_panel:
		return

	for i in range(min(state.crew.size(), crew_panel.get_child_count())):
		var crew_container = crew_panel.get_child(i)
		var portrait = crew_container.get_node_or_null("Portrait") as ColorRect
		var name_label = crew_container.get_node_or_null("Name") as Label
		var member = state.crew[i]

		if name_label:
			name_label.text = Phase2Types.get_crew_role_name(member.role)

		if portrait:
			var health = member.health
			var morale = member.morale
			var condition = (health + morale) / 200.0

			if condition > 0.7:
				portrait.modulate = Color(1.0, 1.0, 1.0)
			elif condition > 0.4:
				portrait.modulate = Color(0.9, 0.9, 0.7)
			else:
				portrait.modulate = Color(0.7, 0.6, 0.6)

func _sync_mars_approach(state: Dictionary) -> void:
	if not mars_sprite:
		return

	if state.current_day >= Phase2Types.MARS_VISIBLE_DAY:
		var progress = float(state.current_day - Phase2Types.MARS_VISIBLE_DAY) / float(state.total_days - Phase2Types.MARS_VISIBLE_DAY)
		var target_alpha = clamp(progress * 2, 0.0, 1.0)
		mars_sprite.modulate.a = lerp(mars_sprite.modulate.a, target_alpha, 0.1)

		var base_scale = 0.1
		var final_scale = 2.0
		var scale_progress = pow(progress, 2)
		mars_sprite.scale = Vector2.ONE * lerp(base_scale, final_scale, scale_progress)

# ============================================================================
# EVENT POPUP
# ============================================================================

func _show_event_popup(event: Dictionary) -> void:
	if not event_popup:
		return

	var event_title = event_popup.get_node_or_null("Content/Title") as Label
	var event_description = event_popup.get_node_or_null("Content/Description") as Label
	var event_options = event_popup.get_node_or_null("Content/Options") as VBoxContainer

	if event_title:
		event_title.text = event.get("title", "EVENT")
	if event_description:
		event_description.text = event.get("description", "")

	if event_options:
		var options = event.get("options", [])
		for i in range(event_options.get_child_count()):
			var btn = event_options.get_child(i) as Button
			if btn:
				if i < options.size():
					btn.text = options[i].get("label", "Option %d" % (i + 1))
					btn.visible = true
				else:
					btn.visible = false

	event_popup.visible = true

	# Animate entrance
	event_popup.modulate.a = 0.0
	var target_pos = event_popup.position
	event_popup.position.x += 300

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(event_popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(event_popup, "position:x", target_pos.x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_event_popup() -> void:
	if not event_popup:
		return

	var tween = create_tween()
	tween.tween_property(event_popup, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): event_popup.visible = false)

# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_day_change() -> void:
	if day_counter:
		var tween = create_tween()
		tween.tween_property(day_counter, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(day_counter, "scale", Vector2.ONE, 0.1)

func shake_screen(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)

func _process(delta: float) -> void:
	# Update shake
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		_apply_shake()

	# Update star parallax
	_update_star_parallax(delta)

func _apply_shake() -> void:
	if shake_intensity < 0.1:
		position = Vector2.ZERO
		return

	var offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)
	position = offset

# ============================================================================
# STAR FIELD
# ============================================================================

func _setup_star_field() -> void:
	if not star_field:
		return

	var viewport_size = get_viewport_rect().size
	stars.clear()

	for i in range(STAR_COUNT):
		var star_data = {
			"pos": Vector2(randf() * viewport_size.x * 2, randf() * viewport_size.y),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.3, 1.0),
			"twinkle_offset": randf() * TAU,
			"twinkle_speed": randf_range(1.0, 3.0),
			"parallax": randf_range(0.2, 1.0)
		}
		stars.append(star_data)

		var star = Polygon2D.new()
		var s = star_data.size
		star.polygon = PackedVector2Array([
			Vector2(-s, 0), Vector2(0, -s), Vector2(s, 0), Vector2(0, s)
		])
		var brightness = star_data.brightness
		var color_roll = randf()
		if color_roll < 0.6:
			star.color = Color(brightness, brightness, brightness * 1.1, 0.8)
		elif color_roll < 0.8:
			star.color = Color(brightness, brightness * 0.95, brightness * 0.8, 0.8)
		else:
			star.color = Color(brightness, brightness * 0.7, brightness * 0.6, 0.8)
		star.position = star_data.pos
		star.name = "Star_%d" % i
		star_field.add_child(star)

func _update_star_parallax(delta: float) -> void:
	if not star_field or stars.is_empty():
		return

	var viewport_size = get_viewport_rect().size
	var time = Time.get_ticks_msec() / 1000.0

	for i in range(min(stars.size(), star_field.get_child_count())):
		var star_data = stars[i]
		var star_node = star_field.get_child(i) as Polygon2D
		if not star_node:
			continue

		star_data.pos.x -= delta * 20 * star_data.parallax

		if star_data.pos.x < -50:
			star_data.pos.x = viewport_size.x + 50
			star_data.pos.y = randf() * viewport_size.y

		star_node.position = star_data.pos

		var twinkle = sin(time * star_data.twinkle_speed + star_data.twinkle_offset)
		star_node.modulate.a = 0.6 + twinkle * 0.4
