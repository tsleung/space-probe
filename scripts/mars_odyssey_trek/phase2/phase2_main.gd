extends Control
class_name Phase2Main

## Phase 2: Travel to Mars
## The journey through the void - 6 months in a metal tube.
## Core fantasy: Submarine Captain
## Visual mode: Scale distortion - infinite void, fragile ship

# ============================================================================
# CONSTANTS
# ============================================================================

const TOTAL_TRAVEL_DAYS = 183  # Default, can be modified by engine choice
const SECONDS_PER_DAY_NORMAL = 2.0
const SECONDS_PER_DAY_FAST = 0.5
const SECONDS_PER_DAY_SLOW = 4.0

# Colors for visual feedback
const COLOR_HEALTHY = Color(0.3, 0.8, 0.3)
const COLOR_CAUTION = Color(0.9, 0.7, 0.2)
const COLOR_WARNING = Color(0.9, 0.5, 0.2)
const COLOR_CRITICAL = Color(0.9, 0.2, 0.2)
const COLOR_DEPLETED = Color(0.4, 0.4, 0.4)

const COLOR_EARTH = Color(0.3, 0.5, 0.9)
const COLOR_MARS = Color(0.8, 0.4, 0.2)

# ============================================================================
# STATE
# ============================================================================

var current_day: int = 1
var total_days: int = TOTAL_TRAVEL_DAYS
var auto_advance: bool = true
var day_timer: float = 0.0
var seconds_per_day: float = SECONDS_PER_DAY_NORMAL

# Resources (synced from store) - totals computed from storage containers
var resources: Dictionary = {
	"food": {"current": 0, "max": 0},  # Computed from containers
	"water": {"current": 0, "max": 0},  # Computed from containers
	"oxygen": {"current": 100, "max": 100},
	"power": {"current": 45, "max": 50},
	"fuel": {"current": 100, "max": 100}
}

# Storage containers - food and water stored in specific ship sections
# Each section can become blocked (depressurized, damaged, etc.)
var storage_containers: Array = [
	{
		"id": "cargo_a",
		"name": "Cargo Bay A (Forward)",
		"section": "forward",
		"food": 250,
		"food_max": 250,
		"water": 100,
		"water_max": 100,
		"accessible": true,
		"status": "nominal"  # nominal, depressurized, damaged, blocked
	},
	{
		"id": "cargo_b",
		"name": "Cargo Bay B (Midship)",
		"section": "midship",
		"food": 300,
		"food_max": 300,
		"water": 150,
		"water_max": 150,
		"accessible": true,
		"status": "nominal"
	},
	{
		"id": "cargo_c",
		"name": "Cargo Bay C (Aft)",
		"section": "aft",
		"food": 200,
		"food_max": 200,
		"water": 100,
		"water_max": 100,
		"accessible": true,
		"status": "nominal"
	},
	{
		"id": "emergency",
		"name": "Emergency Supplies (Hab)",
		"section": "hab",
		"food": 50,
		"food_max": 50,
		"water": 50,
		"water_max": 50,
		"accessible": true,
		"status": "nominal"
	}
]

# Currently consuming from which container
var active_container_index: int = 0

# Blocked section that needs resolution
var blocked_section_event: Dictionary = {}

# Crew (synced from store)
var crew: Array = []

# Events
var active_event: Dictionary = {}
var event_queue: Array = []

# Visual state
var mars_visible: bool = false
var shake_intensity: float = 0.0
var shake_decay: float = 8.0

# ============================================================================
# NODES
# ============================================================================

@onready var star_field: Node2D = $StarField
@onready var journey_bar: Control = $UI/JourneyBar
@onready var ship_marker: Polygon2D = $UI/JourneyBar/ShipMarker
@onready var day_counter: Label = $UI/DayCounter
@onready var days_remaining: Label = $UI/DaysRemaining
@onready var resource_panel: Control = $UI/ResourcePanel
@onready var food_bar: ProgressBar = $UI/ResourcePanel/FoodBar/Bar
@onready var water_bar: ProgressBar = $UI/ResourcePanel/WaterBar/Bar
@onready var oxygen_bar: ProgressBar = $UI/ResourcePanel/OxygenBar/Bar
@onready var power_bar: ProgressBar = $UI/ResourcePanel/PowerBar/Bar
@onready var fuel_bar: ProgressBar = $UI/ResourcePanel/FuelBar/Bar
@onready var crew_panel: Control = $UI/CrewPanel
@onready var event_popup: PanelContainer = $UI/EventPopup
@onready var event_title: Label = $UI/EventPopup/Content/Title
@onready var event_description: Label = $UI/EventPopup/Content/Description
@onready var event_options: VBoxContainer = $UI/EventPopup/Content/Options
@onready var ship_view: Node2D = $ShipView
@onready var mars_sprite: Node2D = $MarsApproach
@onready var speed_slow: Button = $UI/SpeedControls/SlowBtn
@onready var speed_normal: Button = $UI/SpeedControls/NormalBtn
@onready var speed_fast: Button = $UI/SpeedControls/FastBtn
@onready var speed_pause: Button = $UI/SpeedControls/PauseBtn

# Storage panel nodes
@onready var storage_panel: VBoxContainer = $UI/StoragePanel
@onready var total_supplies_label: Label = $UI/StoragePanel/TotalSupplies

# Star data for parallax
var stars: Array = []
const STAR_COUNT = 200

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_star_field()
	_setup_journey_bar()
	_setup_speed_controls()
	_setup_crew()
	_compute_resource_totals()
	_update_all_displays()

	# Hide event popup initially
	if event_popup:
		event_popup.visible = false

	# Start with Mars invisible
	if mars_sprite:
		mars_sprite.modulate.a = 0.0

	# Connect event option buttons
	_setup_event_buttons()

func _compute_resource_totals() -> void:
	# Calculate food and water totals from all accessible containers
	var total_food = 0.0
	var max_food = 0.0
	var total_water = 0.0
	var max_water = 0.0

	for container in storage_containers:
		max_food += container.food_max
		max_water += container.water_max
		if container.accessible:
			total_food += container.food
			total_water += container.water

	resources.food.current = total_food
	resources.food.max = max_food
	resources.water.current = total_water
	resources.water.max = max_water

func _setup_speed_controls() -> void:
	if speed_slow:
		speed_slow.pressed.connect(func(): _set_speed(SECONDS_PER_DAY_SLOW))
	if speed_normal:
		speed_normal.pressed.connect(func(): _set_speed(SECONDS_PER_DAY_NORMAL))
	if speed_fast:
		speed_fast.pressed.connect(func(): _set_speed(SECONDS_PER_DAY_FAST))
	if speed_pause:
		speed_pause.pressed.connect(func(): auto_advance = not auto_advance)

func _set_speed(new_speed: float) -> void:
	seconds_per_day = new_speed
	auto_advance = true

func _setup_crew() -> void:
	# Initialize default crew
	crew = [
		{"name": "Chen Wei", "role": "Commander", "health": 100, "morale": 85, "fatigue": 0},
		{"name": "Sarah Mitchell", "role": "Engineer", "health": 100, "morale": 80, "fatigue": 0},
		{"name": "Dr. Yuki Tanaka", "role": "Scientist", "health": 100, "morale": 90, "fatigue": 0},
		{"name": "Marcus Johnson", "role": "Medical", "health": 100, "morale": 75, "fatigue": 0}
	]

func _setup_event_buttons() -> void:
	if not event_options:
		return
	for i in range(event_options.get_child_count()):
		var btn = event_options.get_child(i) as Button
		if btn:
			var idx = i
			btn.pressed.connect(func(): resolve_event(idx))

func _process(delta: float) -> void:
	# Update shake
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		_apply_shake()

	# Auto-advance days
	if auto_advance and active_event.is_empty():
		day_timer += delta
		if day_timer >= seconds_per_day:
			day_timer = 0.0
			advance_day()

	# Animate star field parallax
	_update_star_parallax(delta)

	# Update Mars approach visual
	_update_mars_approach()

# ============================================================================
# CORE LOOP
# ============================================================================

func advance_day() -> void:
	current_day += 1

	# Check repair progress first (before other events)
	_check_repair_progress()

	# Consume resources
	_consume_daily_resources()

	# Degrade components slightly
	_apply_daily_wear()

	# Update crew stats
	_update_crew_daily()

	# Check for events
	_check_for_events()

	# Update all displays with animation
	_animate_day_change()

	# Check for Mars visibility milestone
	if current_day >= 140 and not mars_visible:
		_trigger_mars_visible()

	# Check for arrival
	if current_day >= total_days:
		_handle_arrival()

func _consume_daily_resources() -> void:
	var crew_count = crew.size()
	if crew_count == 0:
		crew_count = 4  # Default assumption

	# Food: 1 unit per crew per day - consume from accessible containers
	var food_needed = float(crew_count)
	food_needed = _consume_from_containers("food", food_needed)

	# Water: 0.5 units per crew per day (with recycling)
	var water_needed = float(crew_count) * 0.5
	water_needed = _consume_from_containers("water", water_needed)

	# Recalculate totals after consumption
	_compute_resource_totals()

	# Oxygen: regenerated by life support (slight net loss from leakage)
	var oxygen_loss = 0.1  # Base daily leakage
	resources.oxygen.current = max(0, min(resources.oxygen.max, resources.oxygen.current - oxygen_loss))

	# Power: net zero if solar panels working
	# Fuel: only consumed during maneuvers

func _consume_from_containers(resource_type: String, amount: float) -> float:
	# Consume from accessible containers in order, return remaining unfulfilled amount
	var remaining = amount

	for container in storage_containers:
		if remaining <= 0:
			break
		if not container.accessible:
			continue

		var available = container.get(resource_type, 0)
		if available > 0:
			var consume = min(available, remaining)
			container[resource_type] = available - consume
			remaining -= consume
			active_container_index = storage_containers.find(container)

	return remaining  # Returns unfulfilled amount (0 if fully satisfied)

func _get_accessible_resource(resource_type: String) -> float:
	var total = 0.0
	for container in storage_containers:
		if container.accessible:
			total += container.get(resource_type, 0)
	return total

func _get_inaccessible_resource(resource_type: String) -> float:
	var total = 0.0
	for container in storage_containers:
		if not container.accessible:
			total += container.get(resource_type, 0)
	return total

func _get_blocked_containers() -> Array:
	var blocked = []
	for container in storage_containers:
		if not container.accessible and container.status != "nominal":
			blocked.append(container)
	return blocked

func _apply_daily_wear() -> void:
	# Placeholder - components degrade slowly
	pass

func _update_crew_daily() -> void:
	for member in crew:
		# Slight morale decay from isolation
		member.morale = max(0, member.get("morale", 100) - 0.5)

		# Fatigue accumulates
		member.fatigue = min(100, member.get("fatigue", 0) + 0.3)

func _check_for_events() -> void:
	# Random event chance based on day
	var event_chance = 0.1  # 10% base chance per day

	# Higher chance during "interesting" periods
	if current_day < 10:  # Early days
		event_chance = 0.15
	elif current_day > total_days - 20:  # Final approach
		event_chance = 0.2
	elif current_day > total_days / 2 - 5 and current_day < total_days / 2 + 5:  # Midpoint
		event_chance = 0.25

	if randf() < event_chance:
		_trigger_random_event()

# ============================================================================
# EVENTS
# ============================================================================

func _trigger_random_event() -> void:
	# Check if we should trigger a section blockage event
	if randf() < 0.15:  # 15% of events are section blockages
		_trigger_section_blockage()
		return

	# Standard event pool
	var events = [
		{
			"title": "SOLAR FLARE DETECTED",
			"description": "A solar flare will reach the ship in 6 hours. Radiation levels will spike.",
			"options": [
				{"label": "Shelter in cargo hold", "effect": "productivity_loss"},
				{"label": "Continue with shielding", "effect": "minor_radiation"},
				{"label": "Emergency power to shields", "effect": "power_drain"}
			]
		},
		{
			"title": "COMPONENT MALFUNCTION",
			"description": "The %s is showing erratic readings. It may need attention." % ["oxygenator", "water recycler", "navigation system"].pick_random(),
			"options": [
				{"label": "Assign engineer to repair", "effect": "repair_attempt"},
				{"label": "Monitor for now", "effect": "degradation_risk"},
				{"label": "Reroute through backup", "effect": "backup_strain"}
			]
		},
		{
			"title": "MESSAGE FROM EARTH",
			"description": "A personal message has arrived for one of the crew members.",
			"options": [
				{"label": "Share immediately", "effect": "morale_boost"},
				{"label": "Save for a difficult day", "effect": "store_message"}
			]
		},
		{
			"title": "MICROMETEORITE IMPACT",
			"description": "A small impact registered on the hull. No breach detected, but sensors are recalibrating.",
			"options": [
				{"label": "Full hull inspection", "effect": "thorough_check"},
				{"label": "Quick visual check", "effect": "quick_check"}
			]
		},
		{
			"title": "EQUIPMENT FLOATING",
			"description": "Some supplies have come loose and are drifting in the cargo area. Nothing critical.",
			"options": [
				{"label": "Secure everything properly", "effect": "secure_cargo"},
				{"label": "Catch what you can, continue", "effect": "minor_loss"}
			]
		}
	]

	active_event = events.pick_random()
	_show_event_popup()
	auto_advance = false  # Pause for event

func _trigger_section_blockage() -> void:
	# Find an accessible container to block (not emergency supplies)
	var blockable = []
	for container in storage_containers:
		if container.accessible and container.id != "emergency":
			blockable.append(container)

	if blockable.is_empty():
		return  # No containers to block

	var target = blockable.pick_random()

	# Determine blockage type
	var blockage_types = [
		{"status": "depressurized", "cause": "pressure seal failure", "danger": "vacuum exposure"},
		{"status": "damaged", "cause": "electrical fire", "danger": "toxic fumes"},
		{"status": "blocked", "cause": "debris obstruction", "danger": "structural instability"}
	]
	var blockage = blockage_types.pick_random()

	# Block the container
	target.accessible = false
	target.status = blockage.status
	blocked_section_event = target

	# Calculate what we're losing access to
	var food_trapped = target.food
	var water_trapped = target.water

	# Create the blockage event with two retrieval options
	active_event = {
		"title": "SECTION %s" % blockage.status.to_upper(),
		"description": "%s has suffered a %s!\n\nTrapped supplies: %d food, %d water\n\nThe section is currently inaccessible due to %s." % [
			target.name,
			blockage.cause,
			food_trapped,
			water_trapped,
			blockage.danger
		],
		"options": [
			{
				"label": "Repair the section (Engineer, 2-4 days)",
				"effect": "repair_section",
				"risk": "low",
				"description": "Send the engineer to fix the %s. Safer but takes time." % blockage.cause
			},
			{
				"label": "EVA retrieval (Any crew, immediate)",
				"effect": "eva_retrieval",
				"risk": "high",
				"description": "Spacewalk to access the section from outside. Dangerous but fast."
			}
		],
		"blocked_container": target.id
	}

	_show_event_popup()
	auto_advance = false
	shake_screen(15.0)  # Big shake for section damage

func _show_event_popup() -> void:
	if not event_popup or active_event.is_empty():
		return

	# Set content
	if event_title:
		event_title.text = active_event.get("title", "EVENT")
	if event_description:
		event_description.text = active_event.get("description", "")

	# Update option buttons
	if event_options:
		var options = active_event.get("options", [])
		for i in range(event_options.get_child_count()):
			var btn = event_options.get_child(i) as Button
			if btn:
				if i < options.size():
					btn.text = options[i].get("label", "Option %d" % (i + 1))
					btn.visible = true
				else:
					btn.visible = false

	event_popup.visible = true

	# Animate popup entrance - slide in from right
	event_popup.modulate.a = 0.0
	var target_pos = event_popup.position
	event_popup.position.x += 300

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(event_popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(event_popup, "position:x", target_pos.x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Screen shake for drama
	shake_screen(8.0)

func resolve_event(choice_index: int) -> void:
	if active_event.is_empty():
		return

	var choice = active_event.options[choice_index]
	_apply_event_effect(choice.effect)

	# Hide popup with animation
	var tween = create_tween()
	tween.tween_property(event_popup, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): event_popup.visible = false)

	active_event = {}
	auto_advance = true

	# Screen shake for drama
	shake_screen(5.0)

func _apply_event_effect(effect: String) -> void:
	match effect:
		"morale_boost":
			for member in crew:
				member.morale = min(100, member.get("morale", 50) + 10)
			_add_log_message("Crew morale improved from the good news.")

		"morale_risk":
			for member in crew:
				member.morale = max(0, member.get("morale", 50) - 5)

		"power_drain":
			resources.power.current = max(0, resources.power.current - 10)
			_add_log_message("Emergency power diverted to shields. Power reserves depleted.")

		"minor_radiation":
			for member in crew:
				member.health = max(0, member.get("health", 100) - 5)
			_add_log_message("Crew received minor radiation exposure.")

		"repair_section":
			_start_section_repair()

		"eva_retrieval":
			_attempt_eva_retrieval()

		"secure_cargo":
			# No negative effect, just time spent
			_add_log_message("Cargo properly secured.")

		"minor_loss":
			# Lose a small amount of food from the minor cargo loss
			for container in storage_containers:
				if container.accessible and container.food > 5:
					container.food = max(0, container.food - 5)
					break
			_compute_resource_totals()
			_add_log_message("Some supplies were lost in the shuffle.")

		"thorough_check":
			# Takes time but ensures safety
			_add_log_message("Full hull inspection completed. All clear.")

		"quick_check":
			# Small chance of missing something
			if randf() < 0.1:
				_add_log_message("Visual check complete, but something may have been missed...")
			else:
				_add_log_message("Quick visual check - no damage found.")

		_:
			pass  # Unknown effect

# Repair state tracking
var repair_in_progress: bool = false
var repair_days_remaining: int = 0
var repair_target_container: String = ""

func _start_section_repair() -> void:
	if blocked_section_event.is_empty():
		return

	repair_in_progress = true
	repair_days_remaining = randi_range(2, 4)  # 2-4 days to repair
	repair_target_container = blocked_section_event.id

	# Find the engineer
	var engineer_idx = -1
	for i in range(crew.size()):
		if crew[i].role == "Engineer":
			engineer_idx = i
			break

	if engineer_idx >= 0:
		crew[engineer_idx].fatigue = min(100, crew[engineer_idx].get("fatigue", 0) + 20)

	_add_log_message("Engineer dispatched to repair %s. Estimated %d days." % [
		blocked_section_event.name,
		repair_days_remaining
	])

	blocked_section_event = {}

func _attempt_eva_retrieval() -> void:
	if blocked_section_event.is_empty():
		return

	# EVA is risky - roll for success/injury
	var success_chance = 0.7  # 70% success
	var roll = randf()

	var container = blocked_section_event
	var food_amount = container.food
	var water_amount = container.water

	if roll < success_chance:
		# Success! Retrieve supplies, but section remains blocked
		# Create a temporary "rescued supplies" effect - add to emergency container
		for c in storage_containers:
			if c.id == "emergency":
				c.food += food_amount
				c.water += water_amount
				break

		# Original container loses its supplies (we retrieved them)
		container.food = 0
		container.water = 0

		_compute_resource_totals()
		_add_log_message("EVA successful! Retrieved %d food and %d water from %s." % [
			food_amount, water_amount, container.name
		])
		shake_screen(8.0)

	else:
		# Failure - crew member injured, supplies partially lost
		var crew_member = crew.pick_random()
		crew_member.health = max(0, crew_member.get("health", 100) - 25)

		# Partial retrieval - got some supplies
		var partial = 0.3 + randf() * 0.3  # 30-60% retrieved
		for c in storage_containers:
			if c.id == "emergency":
				c.food += int(food_amount * partial)
				c.water += int(water_amount * partial)
				break

		container.food = 0  # Rest is lost to space
		container.water = 0

		_compute_resource_totals()
		_add_log_message("EVA COMPLICATION! %s injured during retrieval. Only partial supplies recovered." % crew_member.name)
		shake_screen(20.0)

	blocked_section_event = {}

func _check_repair_progress() -> void:
	if not repair_in_progress:
		return

	repair_days_remaining -= 1

	if repair_days_remaining <= 0:
		# Repair complete!
		repair_in_progress = false

		# Find and restore the container
		for container in storage_containers:
			if container.id == repair_target_container:
				container.accessible = true
				container.status = "nominal"
				_add_log_message("Repair complete! %s is now accessible." % container.name)
				_compute_resource_totals()
				shake_screen(5.0)
				break

		repair_target_container = ""
	else:
		_add_log_message("Repair in progress... %d days remaining." % repair_days_remaining)

# ============================================================================
# VISUALS
# ============================================================================

func _setup_star_field() -> void:
	if not star_field:
		return

	var viewport_size = get_viewport_rect().size

	# Generate star data
	stars.clear()
	for i in range(STAR_COUNT):
		var star_data = {
			"pos": Vector2(randf() * viewport_size.x * 2, randf() * viewport_size.y),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.3, 1.0),
			"twinkle_offset": randf() * TAU,
			"twinkle_speed": randf_range(1.0, 3.0),
			"parallax": randf_range(0.2, 1.0)  # Slower = further away
		}
		stars.append(star_data)

		# Create visual star node
		var star = Polygon2D.new()
		var s = star_data.size
		star.polygon = PackedVector2Array([
			Vector2(-s, 0), Vector2(0, -s), Vector2(s, 0), Vector2(0, s)
		])
		var brightness = star_data.brightness
		# Vary star colors slightly
		var color_roll = randf()
		if color_roll < 0.6:
			star.color = Color(brightness, brightness, brightness * 1.1, 0.8)  # Blue-white
		elif color_roll < 0.8:
			star.color = Color(brightness, brightness * 0.95, brightness * 0.8, 0.8)  # Yellow
		else:
			star.color = Color(brightness, brightness * 0.7, brightness * 0.6, 0.8)  # Orange
		star.position = star_data.pos
		star.name = "Star_%d" % i
		star_field.add_child(star)

func _setup_journey_bar() -> void:
	if not journey_bar:
		return

	journey_bar.queue_redraw()

func _update_star_parallax(delta: float) -> void:
	if not star_field or stars.is_empty():
		return

	var viewport_size = get_viewport_rect().size
	var time = Time.get_ticks_msec() / 1000.0

	# Update each star position and twinkle
	for i in range(min(stars.size(), star_field.get_child_count())):
		var star_data = stars[i]
		var star_node = star_field.get_child(i) as Polygon2D
		if not star_node:
			continue

		# Move star based on parallax depth
		star_data.pos.x -= delta * 20 * star_data.parallax

		# Wrap around
		if star_data.pos.x < -50:
			star_data.pos.x = viewport_size.x + 50
			star_data.pos.y = randf() * viewport_size.y

		star_node.position = star_data.pos

		# Twinkle effect
		var twinkle = sin(time * star_data.twinkle_speed + star_data.twinkle_offset)
		star_node.modulate.a = 0.6 + twinkle * 0.4

func _update_mars_approach() -> void:
	if not mars_sprite:
		return

	if current_day >= 140:
		var progress = float(current_day - 140) / float(total_days - 140)
		var target_alpha = clamp(progress * 2, 0.0, 1.0)
		mars_sprite.modulate.a = lerp(mars_sprite.modulate.a, target_alpha, 0.1)

		# Mars grows as we approach
		var base_scale = 0.1
		var final_scale = 2.0
		var scale_progress = pow(progress, 2)  # Accelerating growth
		mars_sprite.scale = Vector2.ONE * lerp(base_scale, final_scale, scale_progress)

func _trigger_mars_visible() -> void:
	mars_visible = true
	# Could trigger a narrative beat here
	_add_log_message("Mars is now visible as a distinct orange dot.")

func _animate_day_change() -> void:
	_update_all_displays()

	# Subtle pulse on day counter
	if day_counter:
		var tween = create_tween()
		tween.tween_property(day_counter, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(day_counter, "scale", Vector2.ONE, 0.1)

func _update_all_displays() -> void:
	_update_day_counter()
	_update_journey_bar()
	_update_resource_displays()
	_update_storage_displays()
	_update_crew_displays()

func _update_day_counter() -> void:
	if day_counter:
		day_counter.text = "Day %d / %d" % [current_day, total_days]
	if days_remaining:
		var remaining = total_days - current_day
		days_remaining.text = "%d days remaining" % remaining

func _update_journey_bar() -> void:
	if not ship_marker or not journey_bar:
		return

	# Calculate ship position along journey bar
	var progress = float(current_day) / float(total_days)
	var bar_width = journey_bar.size.x - 40  # Account for Earth/Mars dots
	var ship_x = 20 + (bar_width * progress)
	ship_marker.position.x = ship_x

func _update_resource_displays() -> void:
	# Update progress bars with smooth animation
	if food_bar:
		var target = (resources.food.current / float(resources.food.max)) * 100
		food_bar.value = lerp(food_bar.value, target, 0.2)
		_color_progress_bar(food_bar, target / 100.0)

	if water_bar:
		var target = (resources.water.current / float(resources.water.max)) * 100
		water_bar.value = lerp(water_bar.value, target, 0.2)
		_color_progress_bar(water_bar, target / 100.0)

	if oxygen_bar:
		var target = (resources.oxygen.current / float(resources.oxygen.max)) * 100
		oxygen_bar.value = lerp(oxygen_bar.value, target, 0.2)
		_color_progress_bar(oxygen_bar, target / 100.0)

	if power_bar:
		var target = (resources.power.current / float(resources.power.max)) * 100
		power_bar.value = lerp(power_bar.value, target, 0.2)
		_color_progress_bar(power_bar, target / 100.0)

	if fuel_bar:
		var target = (resources.fuel.current / float(resources.fuel.max)) * 100
		fuel_bar.value = lerp(fuel_bar.value, target, 0.2)
		_color_progress_bar(fuel_bar, target / 100.0)

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

func _update_storage_displays() -> void:
	if not storage_panel:
		return

	var total_food = 0
	var total_water = 0
	var accessible_food = 0
	var accessible_water = 0

	# Update each container display
	for i in range(storage_containers.size()):
		var container = storage_containers[i]
		var container_node = storage_panel.get_node_or_null("Container%d" % i)
		if not container_node:
			continue

		var name_label = container_node.get_node_or_null("Name") as Label
		var status_label = container_node.get_node_or_null("Status") as Label

		# Track totals
		total_food += container.food
		total_water += container.water
		if container.accessible:
			accessible_food += container.food
			accessible_water += container.water

		if name_label:
			# Color based on accessibility
			if container.accessible:
				if i == active_container_index:
					# Currently consuming from this container
					name_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1))
				else:
					name_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, 1))
			else:
				# Blocked - show in red with status
				name_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
				name_label.text = "%s [%s]" % [container.name, container.status.to_upper()]

		if status_label:
			if container.accessible:
				status_label.text = "%d food | %d water" % [container.food, container.water]
				status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			else:
				status_label.text = "INACCESSIBLE - %d food | %d water trapped" % [container.food, container.water]
				status_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3, 1))

	# Update total supplies label
	if total_supplies_label:
		if accessible_food == total_food and accessible_water == total_water:
			total_supplies_label.text = "TOTAL: %d food | %d water" % [total_food, total_water]
			total_supplies_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1))
		else:
			# Show both accessible and trapped
			total_supplies_label.text = "ACCESSIBLE: %d food | %d water\nTRAPPED: %d food | %d water" % [
				accessible_food, accessible_water,
				total_food - accessible_food, total_water - accessible_water
			]
			total_supplies_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))

func _update_crew_displays() -> void:
	if not crew_panel:
		return

	# Update crew portraits based on morale/health
	for i in range(min(crew.size(), crew_panel.get_child_count())):
		var crew_container = crew_panel.get_child(i)
		var portrait = crew_container.get_node_or_null("Portrait") as ColorRect
		var name_label = crew_container.get_node_or_null("Name") as Label

		if i < crew.size():
			var member = crew[i]

			# Update name
			if name_label:
				name_label.text = member.get("role", "Crew")

			# Tint portrait based on health/morale
			if portrait:
				var health = member.get("health", 100)
				var morale = member.get("morale", 100)
				var condition = (health + morale) / 200.0

				if condition > 0.7:
					portrait.modulate = Color(1.0, 1.0, 1.0)  # Normal
				elif condition > 0.4:
					portrait.modulate = Color(0.9, 0.9, 0.7)  # Stressed
				else:
					portrait.modulate = Color(0.7, 0.6, 0.6)  # Critical

func shake_screen(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)

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
# ARRIVAL
# ============================================================================

func _handle_arrival() -> void:
	auto_advance = false
	_add_log_message("Mars orbit achieved. Preparing for landing sequence...")

	# Transition to Phase 3
	# For now, just stop the simulation
	await get_tree().create_timer(3.0).timeout
	# emit_signal("phase_complete")

# ============================================================================
# UTILITIES
# ============================================================================

func _add_log_message(message: String) -> void:
	print("[Day %d] %s" % [current_day, message])

func get_resource_percent(resource_name: String) -> float:
	if not resources.has(resource_name):
		return 0.0
	var res = resources[resource_name]
	if res.max <= 0:
		return 0.0
	return float(res.current) / float(res.max)

func get_resource_color(resource_name: String) -> Color:
	var percent = get_resource_percent(resource_name)
	if percent > 0.5:
		return COLOR_HEALTHY
	elif percent > 0.25:
		return COLOR_CAUTION
	elif percent > 0.1:
		return COLOR_WARNING
	elif percent > 0:
		return COLOR_CRITICAL
	else:
		return COLOR_DEPLETED
