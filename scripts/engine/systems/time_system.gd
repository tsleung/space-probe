## Time progression system.
## Handles day/sol advancement, phase transitions, and time-based triggers.
##
## All functions are static and pure.
class_name TimeSystem
extends RefCounted


## ============================================================================
## TIME UNITS
## ============================================================================

## Time unit types
enum TimeUnit {
	DAY,   # Earth day (used in ship building, travel)
	SOL    # Mars day (~24h 37m, used on Mars surface)
}


## Get time unit for current phase
static func get_time_unit(phase: String) -> TimeUnit:
	match phase:
		"mars_base", "mars_arrival":
			return TimeUnit.SOL
		_:
			return TimeUnit.DAY


## Get time unit name
static func get_time_unit_name(unit: TimeUnit) -> String:
	match unit:
		TimeUnit.DAY:
			return "Day"
		TimeUnit.SOL:
			return "Sol"
		_:
			return "Day"


## ============================================================================
## TIME ADVANCEMENT
## ============================================================================

## Advance time by one unit (day or sol depending on phase)
static func advance_time(
	state: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var phase = state.get("phase", "")

	# Increment appropriate counter
	if get_time_unit(phase) == TimeUnit.SOL:
		new_state["current_sol"] = state.get("current_sol", 0) + 1
	else:
		new_state["current_day"] = state.get("current_day", 0) + 1

	# Apply time-based effects
	new_state = _apply_daily_effects(new_state, balance, rng)

	# Check for phase transitions
	new_state = _check_phase_transitions(new_state, balance)

	# Update time tracking
	new_state["last_update_time"] = Time.get_unix_time_from_system()

	return new_state


## Apply all daily effects
static func _apply_daily_effects(
	state: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state
	var phase = state.get("phase", "")

	# Resource consumption (travel and mars phases)
	if phase in ["travel_to_mars", "travel_to_earth", "mars_base"]:
		new_state = ResourceSystem.consume_daily(new_state, balance, rng)
		new_state = ResourceSystem.apply_deprivation(new_state, balance, rng)

	# Crew daily update
	new_state = CrewSystem.apply_daily_update(new_state, balance, rng)

	# Component wear (travel phases)
	if phase in ["travel_to_mars", "travel_to_earth"]:
		new_state = ComponentSystem.apply_daily_wear(new_state, balance, rng)

	return new_state


## Check for automatic phase transitions
static func _check_phase_transitions(
	state: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var new_state = state.duplicate(true)
	var phase = state.get("phase", "")

	match phase:
		"travel_to_mars":
			var travel_day = state.get("travel_day", 0)
			var total_days = state.get("travel_total_days", 180)
			if travel_day >= total_days:
				new_state["pending_phase_transition"] = "mars_arrival"

		"travel_to_earth":
			var travel_day = state.get("return_travel_day", 0)
			var total_days = state.get("return_travel_total_days", 180)
			if travel_day >= total_days:
				new_state["pending_phase_transition"] = "earth_arrival"

		"mars_base":
			var current_sol = state.get("current_sol", 0)
			var min_sols = balance.get("mars_minimum_sols", 30)
			var departure_ready = state.get("departure_ready", false)
			if current_sol >= min_sols and departure_ready:
				new_state["can_depart_mars"] = true

	return new_state


## ============================================================================
## REAL-TIME SUPPORT
## ============================================================================

## Calculate how many time units should pass based on elapsed real time
static func calculate_time_units_to_advance(
	state: Dictionary,
	current_time: float,
	time_scale: float
) -> int:
	var last_update = state.get("last_update_time", current_time)
	var elapsed_seconds = current_time - last_update

	# Time scale: 1.0 = 1 real second per game day, 60.0 = 1 real minute per game day
	var seconds_per_unit = 1.0 / time_scale

	return int(elapsed_seconds / seconds_per_unit)


## Apply multiple time units at once (for catch-up)
static func advance_time_units(
	state: Dictionary,
	units: int,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state

	for i in range(units):
		new_state = advance_time(new_state, balance, rng)

		# Check for stopping conditions
		if new_state.get("pending_phase_transition", "") != "":
			break
		if new_state.get("game_over", false):
			break
		if new_state.get("pending_event", null) != null:
			break

	return new_state


## ============================================================================
## LAUNCH WINDOW
## ============================================================================

## Calculate days until launch window
static func days_until_launch_window(state: Dictionary, balance: Dictionary) -> int:
	var current_day = state.get("current_day", 0)
	var window_day = state.get("launch_window_day", balance.get("optimal_launch_day", 365))
	return max(0, window_day - current_day)


## Calculate days past launch window
static func days_past_launch_window(state: Dictionary, balance: Dictionary) -> int:
	var current_day = state.get("current_day", 0)
	var window_day = state.get("launch_window_day", balance.get("optimal_launch_day", 365))
	return max(0, current_day - window_day)


## Calculate launch window penalty
static func calculate_launch_penalty(state: Dictionary, balance: Dictionary) -> Dictionary:
	var days_past = days_past_launch_window(state, balance)

	if days_past <= 0:
		return {
			"travel_days_added": 0,
			"fuel_multiplier": 1.0,
			"penalty_level": "none"
		}

	var penalty_per_day = balance.get("launch_window_penalty_per_day", 0.5)
	var fuel_penalty_per_day = balance.get("launch_fuel_penalty_per_day", 0.01)

	var travel_penalty = int(days_past * penalty_per_day)
	var fuel_mult = 1.0 + (days_past * fuel_penalty_per_day)

	var penalty_level = "minor"
	if days_past > 30:
		penalty_level = "moderate"
	if days_past > 60:
		penalty_level = "severe"
	if days_past > 90:
		penalty_level = "critical"

	return {
		"travel_days_added": travel_penalty,
		"fuel_multiplier": fuel_mult,
		"penalty_level": penalty_level,
		"days_past": days_past
	}


## ============================================================================
## TRAVEL PROGRESS
## ============================================================================

## Calculate travel progress percentage
static func calculate_travel_progress(state: Dictionary) -> float:
	var travel_day = state.get("travel_day", 0)
	var total_days = state.get("travel_total_days", 180)

	if total_days <= 0:
		return 0.0

	return clamp(float(travel_day) / float(total_days) * 100.0, 0.0, 100.0)


## Calculate estimated arrival day
static func calculate_arrival_day(state: Dictionary) -> int:
	var current_day = state.get("current_day", 0)
	var travel_day = state.get("travel_day", 0)
	var total_travel_days = state.get("travel_total_days", 180)

	return current_day + (total_travel_days - travel_day)


## Calculate distance traveled (approximate)
static func calculate_distance(state: Dictionary, balance: Dictionary) -> Dictionary:
	var progress = calculate_travel_progress(state) / 100.0
	var total_distance = balance.get("earth_mars_distance_km", 225000000)

	return {
		"traveled_km": total_distance * progress,
		"remaining_km": total_distance * (1.0 - progress),
		"total_km": total_distance,
		"progress_percent": progress * 100.0
	}


## ============================================================================
## MARS SOL CALCULATIONS
## ============================================================================

## Calculate Mars departure window
static func calculate_mars_departure_window(state: Dictionary, balance: Dictionary) -> Dictionary:
	var arrival_sol = state.get("mars_arrival_sol", 0)
	var min_stay = balance.get("mars_minimum_sols", 30)
	var optimal_stay = balance.get("mars_optimal_sols", 60)
	var max_stay = balance.get("mars_maximum_sols", 120)

	var earliest_departure = arrival_sol + min_stay
	var optimal_departure = arrival_sol + optimal_stay
	var latest_departure = arrival_sol + max_stay

	return {
		"earliest_sol": earliest_departure,
		"optimal_sol": optimal_departure,
		"latest_sol": latest_departure,
		"penalty_after_optimal": true
	}


## Calculate Mars departure penalty
static func calculate_mars_departure_penalty(
	state: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var current_sol = state.get("current_sol", 0)
	var window = calculate_mars_departure_window(state, balance)

	if current_sol < window.earliest_sol:
		var days_early = window.earliest_sol - current_sol
		return {
			"can_depart": false,
			"penalty_level": "too_early",
			"sols_until_window": days_early,
			"message": "Cannot depart for %d more sols" % days_early
		}

	if current_sol <= window.optimal_sol:
		return {
			"can_depart": true,
			"penalty_level": "none",
			"fuel_multiplier": 1.0,
			"travel_days_added": 0
		}

	var sols_late = current_sol - window.optimal_sol
	var penalty_per_sol = balance.get("mars_departure_penalty_per_sol", 0.3)

	if current_sol > window.latest_sol:
		return {
			"can_depart": true,
			"penalty_level": "critical",
			"fuel_multiplier": 2.0,
			"travel_days_added": int(sols_late * penalty_per_sol),
			"message": "Orbital mechanics severely degraded"
		}

	return {
		"can_depart": true,
		"penalty_level": "moderate" if sols_late > 30 else "minor",
		"fuel_multiplier": 1.0 + (sols_late * 0.01),
		"travel_days_added": int(sols_late * penalty_per_sol)
	}


## ============================================================================
## DEADLINE TRACKING
## ============================================================================

## Get all active deadlines
static func get_deadlines(state: Dictionary, balance: Dictionary) -> Array[Dictionary]:
	var deadlines: Array[Dictionary] = []
	var phase = state.get("phase", "")
	var current_day = state.get("current_day", 0)
	var current_sol = state.get("current_sol", 0)

	match phase:
		"ship_building":
			var launch_window = state.get("launch_window_day", balance.get("optimal_launch_day", 365))
			var days_until = launch_window - current_day
			deadlines.append({
				"name": "Launch Window",
				"day": launch_window,
				"days_remaining": days_until,
				"urgency": _calculate_urgency(days_until, 60)
			})

		"mars_base":
			var window = calculate_mars_departure_window(state, balance)
			var sols_until_optimal = window.optimal_sol - current_sol
			var sols_until_latest = window.latest_sol - current_sol

			deadlines.append({
				"name": "Optimal Departure",
				"sol": window.optimal_sol,
				"sols_remaining": sols_until_optimal,
				"urgency": _calculate_urgency(sols_until_optimal, 20)
			})

			deadlines.append({
				"name": "Latest Departure",
				"sol": window.latest_sol,
				"sols_remaining": sols_until_latest,
				"urgency": _calculate_urgency(sols_until_latest, 30)
			})

	return deadlines


## Calculate urgency level
static func _calculate_urgency(time_remaining: int, threshold: int) -> String:
	if time_remaining <= 0:
		return "passed"
	elif time_remaining <= threshold / 4:
		return "critical"
	elif time_remaining <= threshold / 2:
		return "urgent"
	elif time_remaining <= threshold:
		return "approaching"
	else:
		return "normal"


## ============================================================================
## DATE FORMATTING
## ============================================================================

## Format day as date string (relative to mission start)
static func format_day_as_date(day: int, start_year: int = 2035) -> String:
	var total_days = day
	var year = start_year
	var month = 1
	var day_of_month = 1

	var days_in_months = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

	while total_days > 0:
		# Check leap year
		var is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
		var days_this_year = 366 if is_leap else 365

		if total_days >= days_this_year:
			total_days -= days_this_year
			year += 1
		else:
			# Find month
			for m in range(12):
				var days_this_month = days_in_months[m]
				if m == 1 and is_leap:
					days_this_month = 29

				if total_days >= days_this_month:
					total_days -= days_this_month
					month += 1
				else:
					day_of_month = total_days + 1
					total_days = 0
					break
			break

	var month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	return "%s %d, %d" % [month_names[month - 1], day_of_month, year]


## Format time remaining
static func format_time_remaining(units: int, time_unit: TimeUnit) -> String:
	var unit_name = "day" if time_unit == TimeUnit.DAY else "sol"
	if units != 1:
		unit_name += "s"

	return "%d %s" % [units, unit_name]
