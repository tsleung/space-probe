extends Control
class_name CargoLoader

## Cargo Loader for MOT Phase 1
## Oregon Trail-style supply allocation with weight and budget constraints

signal cargo_changed(category: String, amount: int)

# ============================================================================
# CARGO DEFINITIONS
# ============================================================================

const CARGO_CATEGORIES = {
	"food_days": {
		"name": "Food Rations",
		"unit": "days",
		"kg_per_unit": 2,
		"description": "Crew food supply. Need 400+ days minimum.",
		"min": 0,
		"max": 800,
		"step": 10,
		"default": 450,
		"critical_min": 400
	},
	"water_reserve": {
		"name": "Water Reserve",
		"unit": "tanks",
		"kg_per_unit": 10,
		"description": "Emergency water backup beyond recycling.",
		"min": 0,
		"max": 50,
		"step": 1,
		"default": 20,
		"critical_min": 10
	},
	"spare_parts": {
		"name": "Spare Parts",
		"unit": "kits",
		"kg_per_unit": 50,
		"description": "Repair kits for ship systems.",
		"min": 0,
		"max": 30,
		"step": 1,
		"default": 10,
		"critical_min": 5
	},
	"medical_kits": {
		"name": "Medical Supplies",
		"unit": "kits",
		"kg_per_unit": 20,
		"description": "First aid and emergency medicine.",
		"min": 0,
		"max": 40,
		"step": 1,
		"default": 15,
		"critical_min": 8
	},
	"equipment": {
		"name": "Colony Equipment",
		"unit": "modules",
		"kg_per_unit": 100,
		"description": "Tools and equipment for Mars base.",
		"min": 0,
		"max": 30,
		"step": 1,
		"default": 5,
		"critical_min": 0
	}
}

# ============================================================================
# STATE
# ============================================================================

var cargo_amounts: Dictionary = {}
var cargo_capacity: int = 5000  # Will be updated from store
var store: MOTStore = null

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var sliders_container: VBoxContainer = %SlidersContainer
@onready var capacity_bar: ProgressBar = %CapacityBar
@onready var capacity_label: Label = %CapacityLabel
@onready var weight_breakdown: Label = %WeightBreakdown
@onready var warnings_label: Label = %WarningsLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_initialize_defaults()
	_create_sliders()
	_update_display()

# ============================================================================
# SETUP
# ============================================================================

func set_store(s: MOTStore) -> void:
	store = s

func initialize_from_state(state: Dictionary) -> void:
	cargo_capacity = state.get("cargo_capacity", 5000)

	var manifest = state.get("cargo_manifest", {})
	for category in CARGO_CATEGORIES:
		if manifest.has(category):
			cargo_amounts[category] = manifest[category]

	_update_sliders_from_state()
	_update_display()

func _initialize_defaults() -> void:
	for category in CARGO_CATEGORIES:
		cargo_amounts[category] = CARGO_CATEGORIES[category].default

# ============================================================================
# SLIDER CREATION
# ============================================================================

func _create_sliders() -> void:
	if not sliders_container:
		return

	for child in sliders_container.get_children():
		child.queue_free()

	for category in CARGO_CATEGORIES:
		var row = _create_slider_row(category)
		sliders_container.add_child(row)

func _create_slider_row(category: String) -> HBoxContainer:
	var data = CARGO_CATEGORIES[category]

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	# Label
	var label = Label.new()
	label.text = data.name
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	# Slider
	var slider = HSlider.new()
	slider.min_value = data.min
	slider.max_value = data.max
	slider.step = data.step
	slider.value = cargo_amounts[category]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(func(val): _on_slider_changed(category, int(val)))
	row.add_child(slider)

	# Value label
	var value_label = Label.new()
	value_label.text = "%d %s" % [cargo_amounts[category], data.unit]
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	row.add_child(value_label)

	# Weight label
	var weight = cargo_amounts[category] * data.kg_per_unit
	var weight_label = Label.new()
	weight_label.text = "%d kg" % weight
	weight_label.custom_minimum_size = Vector2(70, 0)
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weight_label.add_theme_font_size_override("font_size", 12)
	weight_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	row.add_child(weight_label)

	# Store references
	row.set_meta("category", category)
	row.set_meta("slider", slider)
	row.set_meta("value_label", value_label)
	row.set_meta("weight_label", weight_label)

	return row

func _update_sliders_from_state() -> void:
	if not sliders_container:
		return

	for row in sliders_container.get_children():
		var category = row.get_meta("category", "")
		var slider = row.get_meta("slider") as HSlider
		if slider and cargo_amounts.has(category):
			slider.set_value_no_signal(cargo_amounts[category])

# ============================================================================
# SLIDER HANDLING
# ============================================================================

func _on_slider_changed(category: String, value: int) -> void:
	cargo_amounts[category] = value
	_update_row_display(category)
	_update_display()
	cargo_changed.emit(category, value)

func _update_row_display(category: String) -> void:
	if not sliders_container:
		return

	var data = CARGO_CATEGORIES[category]

	for row in sliders_container.get_children():
		if row.get_meta("category", "") == category:
			var value_label = row.get_meta("value_label") as Label
			var weight_label = row.get_meta("weight_label") as Label

			if value_label:
				value_label.text = "%d %s" % [cargo_amounts[category], data.unit]

			if weight_label:
				var weight = cargo_amounts[category] * data.kg_per_unit
				weight_label.text = "%d kg" % weight

			# Color coding for critical values
			var is_critical = cargo_amounts[category] < data.critical_min
			if value_label:
				if is_critical:
					value_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
				else:
					value_label.remove_theme_color_override("font_color")
			break

# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func _update_display() -> void:
	var total_weight = _calculate_total_weight()

	# Capacity bar
	if capacity_bar:
		capacity_bar.max_value = cargo_capacity
		capacity_bar.value = total_weight

		# Color based on usage
		var usage_pct = float(total_weight) / cargo_capacity if cargo_capacity > 0 else 0
		var bar_style = StyleBoxFlat.new()
		bar_style.set_corner_radius_all(4)

		if total_weight > cargo_capacity:
			bar_style.bg_color = Color(0.9, 0.2, 0.2)
		elif usage_pct > 0.9:
			bar_style.bg_color = Color(0.9, 0.7, 0.2)
		else:
			bar_style.bg_color = Color(0.3, 0.7, 0.4)

		capacity_bar.add_theme_stylebox_override("fill", bar_style)

	# Capacity label
	if capacity_label:
		capacity_label.text = "%d / %d kg" % [total_weight, cargo_capacity]
		if total_weight > cargo_capacity:
			capacity_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			capacity_label.remove_theme_color_override("font_color")

	# Weight breakdown
	if weight_breakdown:
		var lines = []
		for category in CARGO_CATEGORIES:
			var data = CARGO_CATEGORIES[category]
			var weight = cargo_amounts[category] * data.kg_per_unit
			lines.append("%s: %d kg" % [data.name, weight])
		weight_breakdown.text = " | ".join(lines)

	# Warnings
	if warnings_label:
		var warnings = _get_warnings()
		if warnings.size() > 0:
			warnings_label.text = "Warnings: " + ", ".join(warnings)
			warnings_label.visible = true
		else:
			warnings_label.visible = false

func _calculate_total_weight() -> int:
	var total = 0
	for category in CARGO_CATEGORIES:
		var data = CARGO_CATEGORIES[category]
		total += cargo_amounts[category] * data.kg_per_unit
	return total

func _get_warnings() -> Array:
	var warnings = []

	# Check capacity
	if _calculate_total_weight() > cargo_capacity:
		warnings.append("Over capacity!")

	# Check critical minimums
	for category in CARGO_CATEGORIES:
		var data = CARGO_CATEGORIES[category]
		if cargo_amounts[category] < data.critical_min:
			warnings.append("%s below minimum" % data.name)

	return warnings
