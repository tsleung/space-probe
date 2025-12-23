extends RefCounted
class_name MOTOrbital

## Mars Odyssey Trek - Orbital Mechanics
## Calculates Hohmann transfer windows, launch costs, and travel times
##
## Based on real orbital mechanics but tuned for gameplay:
## - Optimal Hohmann transfer: ~180 days (real: ~259 days, compressed for fun)
## - Phase angle requirement: Mars ~44 degrees ahead of Earth at launch
## - Launch windows occur roughly every 26 months (synodic period)

# ============================================================================
# ORBITAL CONSTANTS
# ============================================================================

# All distances in AU (Astronomical Units)
const EARTH_SEMI_MAJOR := 1.0      # Earth orbit radius
const MARS_SEMI_MAJOR := 1.52     # Mars orbit radius

# Orbital periods in Earth years
const EARTH_ORBITAL_PERIOD := 1.0
const MARS_ORBITAL_PERIOD := 1.88

# Synodic period (time between optimal launch windows) in days
# Real: ~780 days (~26 months), we use this for realism
const SYNODIC_PERIOD_DAYS := 780

# Hohmann transfer parameters
const OPTIMAL_PHASE_ANGLE := 0.77  # Radians (~44 degrees) - Mars ahead of Earth
const OPTIMAL_TRANSFER_DAYS := 180  # Gameplay-tuned (real: ~259 days)
const MIN_TRANSFER_DAYS := 150     # Fastest possible (high fuel cost)
const MAX_TRANSFER_DAYS := 300     # Slowest (very inefficient window)

# Fuel multipliers (1.0 = baseline for optimal window)
const FUEL_MULTIPLIER_OPTIMAL := 1.0
const FUEL_MULTIPLIER_GOOD := 1.15
const FUEL_MULTIPLIER_POOR := 1.4
const FUEL_MULTIPLIER_RUSH := 1.6   # LAUNCH NOW penalty

# ============================================================================
# LAUNCH WINDOW DATA STRUCTURE
# ============================================================================

class LaunchWindow:
	var launch_day: int           # Day number from game start
	var travel_days: int          # Days to reach Mars
	var fuel_multiplier: float    # 1.0 = baseline
	var phase_deviation: float    # How far from optimal (radians)
	var quality: String           # "optimal", "good", "poor", "rush"
	var earth_angle: float        # Earth position at launch (radians)
	var mars_angle_arrival: float # Mars position at arrival (radians)

	func _init():
		launch_day = 0
		travel_days = OPTIMAL_TRANSFER_DAYS
		fuel_multiplier = 1.0
		phase_deviation = 0.0
		quality = "optimal"
		earth_angle = 0.0
		mars_angle_arrival = 0.0

	func get_summary() -> Dictionary:
		return {
			"launch_day": launch_day,
			"travel_days": travel_days,
			"fuel_multiplier": fuel_multiplier,
			"quality": quality,
			"phase_deviation_degrees": rad_to_deg(phase_deviation)
		}

# ============================================================================
# POSITION CALCULATIONS
# ============================================================================

static func get_earth_position(day: int, start_year: int = 2040) -> Vector2:
	## Get Earth's position in AU at a given day
	## Day 0 = January 1st of start_year
	var years = day / 365.25
	var angle = _get_earth_angle(day, start_year)
	return Vector2(
		EARTH_SEMI_MAJOR * cos(angle),
		EARTH_SEMI_MAJOR * sin(angle)
	)

static func get_mars_position(day: int, start_year: int = 2040) -> Vector2:
	## Get Mars's position in AU at a given day
	var angle = _get_mars_angle(day, start_year)
	return Vector2(
		MARS_SEMI_MAJOR * cos(angle),
		MARS_SEMI_MAJOR * sin(angle)
	)

static func _get_earth_angle(day: int, start_year: int) -> float:
	## Calculate Earth's orbital angle at a given day
	## Assuming Earth starts at angle 0 on Jan 1, 2040
	var years = day / 365.25
	var angular_velocity = TAU / EARTH_ORBITAL_PERIOD  # radians per year
	# Add some offset based on start year for variety
	var base_angle = (start_year - 2040) * angular_velocity * 0.1
	return base_angle + (angular_velocity * years)

static func _get_mars_angle(day: int, start_year: int) -> float:
	## Calculate Mars's orbital angle at a given day
	var years = day / 365.25
	var angular_velocity = TAU / MARS_ORBITAL_PERIOD  # radians per year
	# Mars starts at a different position
	var base_angle = PI * 0.3 + (start_year - 2040) * angular_velocity * 0.1
	return base_angle + (angular_velocity * years)

static func get_phase_angle(day: int, start_year: int = 2040) -> float:
	## Get the current phase angle between Earth and Mars
	## Positive = Mars is ahead of Earth in orbit
	var earth_angle = _get_earth_angle(day, start_year)
	var mars_angle = _get_mars_angle(day, start_year)
	var phase = fmod(mars_angle - earth_angle, TAU)
	if phase < 0:
		phase += TAU
	return phase

# ============================================================================
# LAUNCH WINDOW CALCULATIONS
# ============================================================================

static func calculate_launch_window(launch_day: int, start_year: int = 2040) -> LaunchWindow:
	## Calculate transfer parameters for a specific launch day
	var window = LaunchWindow.new()
	window.launch_day = launch_day

	# Get positions
	window.earth_angle = _get_earth_angle(launch_day, start_year)

	# Calculate phase angle at launch
	var phase_at_launch = get_phase_angle(launch_day, start_year)

	# How far from optimal?
	window.phase_deviation = abs(phase_at_launch - OPTIMAL_PHASE_ANGLE)
	# Handle wraparound (if deviation > PI, we're closer going the other way)
	if window.phase_deviation > PI:
		window.phase_deviation = TAU - window.phase_deviation

	# Calculate travel time based on phase deviation
	# Optimal = ~180 days, poor alignment can add up to 120 days
	var deviation_factor = window.phase_deviation / PI  # 0 to 1
	window.travel_days = int(OPTIMAL_TRANSFER_DAYS + deviation_factor * (MAX_TRANSFER_DAYS - OPTIMAL_TRANSFER_DAYS))

	# Calculate fuel multiplier based on deviation
	# Deviating from optimal requires more delta-v
	if deviation_factor < 0.1:
		window.fuel_multiplier = FUEL_MULTIPLIER_OPTIMAL
		window.quality = "optimal"
	elif deviation_factor < 0.3:
		window.fuel_multiplier = lerpf(FUEL_MULTIPLIER_OPTIMAL, FUEL_MULTIPLIER_GOOD, (deviation_factor - 0.1) / 0.2)
		window.quality = "good"
	elif deviation_factor < 0.6:
		window.fuel_multiplier = lerpf(FUEL_MULTIPLIER_GOOD, FUEL_MULTIPLIER_POOR, (deviation_factor - 0.3) / 0.3)
		window.quality = "poor"
	else:
		window.fuel_multiplier = FUEL_MULTIPLIER_POOR + (deviation_factor - 0.6) * 0.5
		window.quality = "poor"

	# Calculate Mars position at arrival
	var arrival_day = launch_day + window.travel_days
	window.mars_angle_arrival = _get_mars_angle(arrival_day, start_year)

	return window

static func calculate_rush_launch(current_day: int, prep_days: int = 10, start_year: int = 2040) -> LaunchWindow:
	## Calculate a rush launch (LAUNCH NOW with minimal prep)
	var window = calculate_launch_window(current_day + prep_days, start_year)

	# Rush launches have additional penalties
	window.fuel_multiplier *= 1.1  # 10% penalty for rush prep
	window.quality = "rush"

	return window

static func find_optimal_windows(start_day: int, search_days: int = 400, start_year: int = 2040) -> Array:
	## Find all launch windows in the search period
	## Returns array of LaunchWindow sorted by quality
	var windows: Array[LaunchWindow] = []

	# Sample every 5 days to find windows
	var day = start_day
	while day < start_day + search_days:
		var window = calculate_launch_window(day, start_year)
		windows.append(window)
		day += 5

	# Sort by fuel multiplier (best first)
	windows.sort_custom(func(a, b): return a.fuel_multiplier < b.fuel_multiplier)

	return windows

static func find_next_optimal_window(start_day: int, start_year: int = 2040) -> LaunchWindow:
	## Find the next optimal/good launch window from a given day
	var windows = find_optimal_windows(start_day, 400, start_year)

	for window in windows:
		if window.quality == "optimal" or window.quality == "good":
			return window

	# If no good window found, return the best available
	return windows[0] if windows.size() > 0 else calculate_launch_window(start_day, start_year)

static func get_window_timeline(start_day: int, end_day: int, start_year: int = 2040) -> Array:
	## Get a timeline of windows for UI display
	## Returns array of {day, quality, fuel_multiplier, travel_days}
	var timeline = []

	# First, add the rush option
	var rush = calculate_rush_launch(start_day, 10, start_year)
	timeline.append({
		"day": rush.launch_day,
		"label": "LAUNCH NOW",
		"quality": rush.quality,
		"fuel_multiplier": rush.fuel_multiplier,
		"travel_days": rush.travel_days,
		"is_rush": true
	})

	# Then sample windows
	var day = start_day + 15  # Start after rush window
	while day <= end_day:
		var window = calculate_launch_window(day, start_year)

		# Only add significant windows (optimal or good)
		# Or add at regular intervals for context
		var should_add = window.quality == "optimal" or window.quality == "good"
		should_add = should_add or (day - start_day) % 30 == 0  # Every 30 days for context

		if should_add:
			timeline.append({
				"day": day,
				"label": "Day %d" % day,
				"quality": window.quality,
				"fuel_multiplier": window.fuel_multiplier,
				"travel_days": window.travel_days,
				"is_rush": false
			})

		day += 5

	return timeline

# ============================================================================
# UI HELPERS
# ============================================================================

static func get_quality_color(quality: String) -> Color:
	## Get display color for window quality
	match quality:
		"optimal":
			return Color(0.2, 0.8, 0.2)  # Green
		"good":
			return Color(0.8, 0.8, 0.2)  # Yellow
		"poor":
			return Color(0.8, 0.4, 0.2)  # Orange
		"rush":
			return Color(0.8, 0.2, 0.2)  # Red
		_:
			return Color(0.5, 0.5, 0.5)  # Gray

static func format_fuel_cost(fuel_multiplier: float, base_fuel: float = 10000) -> String:
	## Format fuel requirement for display
	var fuel = base_fuel * fuel_multiplier
	if fuel >= 1000:
		return "%.1fk kg" % (fuel / 1000)
	return "%d kg" % int(fuel)

static func format_travel_time(days: int) -> String:
	## Format travel time for display
	if days < 30:
		return "%d days" % days
	var months = days / 30.0
	return "%.1f months" % months

static func get_window_description(window: LaunchWindow) -> String:
	## Get a human-readable description of a launch window
	match window.quality:
		"optimal":
			return "Optimal Hohmann transfer - lowest fuel cost"
		"good":
			return "Good window - slightly higher fuel cost"
		"poor":
			return "Suboptimal alignment - significantly higher fuel cost"
		"rush":
			return "Rush launch - expensive but immediate"
		_:
			return "Launch window"

static func get_educational_text(window: LaunchWindow) -> String:
	## Get educational tooltip text about orbital mechanics
	var text = ""

	text += "Phase Angle: %.1f degrees\n" % rad_to_deg(get_phase_angle(window.launch_day))
	text += "(Optimal: ~44 degrees)\n\n"

	if window.quality == "optimal":
		text += "This is a Hohmann transfer orbit - the most fuel-efficient "
		text += "path between two circular orbits. The spacecraft follows an "
		text += "elliptical path that touches both Earth's and Mars's orbits."
	elif window.quality == "rush":
		text += "A rush launch means departing before the optimal alignment. "
		text += "The spacecraft must use more fuel to compensate for the "
		text += "non-ideal trajectory."
	else:
		text += "The phase angle isn't optimal, so the transfer requires "
		text += "extra fuel to adjust the trajectory. Waiting for better "
		text += "alignment would reduce costs."

	return text
