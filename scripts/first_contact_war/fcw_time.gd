extends RefCounted
class_name FCWTime

## First Contact War - Unified Time System
##
## Single source of truth for all time in FCW.
##
## Architecture:
##   - game_time: float (hours since game start) - the authoritative clock
##   - Simulation advances in discrete 1-hour ticks
##   - Visual layer interpolates between ticks for smooth animation
##   - Player decisions can be made at any time (real-time agency)
##
## Time Hierarchy:
##   - Hour = base simulation tick (finest granularity)
##   - Day = 24 hours (production updates, daily events)
##   - Week = 168 hours / 7 days (major phases, Herald milestones)
##
## Design Philosophy:
##   "The weeks march as inevitability - futility, hopelessness, dread.
##    But you are NOT a victim to operational structure.
##    You can make decisions at any moment."

# ============================================================================
# CONSTANTS
# ============================================================================

const HOURS_PER_DAY: int = 24
const DAYS_PER_WEEK: int = 7
const HOURS_PER_WEEK: int = HOURS_PER_DAY * DAYS_PER_WEEK  # 168

## Speed settings: ticks (hours) per real second
## At NORMAL speed, 1 hour = 1 real second, so a full week takes 168 seconds (~3 min)
const SPEED_SETTINGS: Dictionary = {
	"PAUSED": 0.0,
	"SLOW": 0.5,      # 1 hour = 2 real seconds
	"NORMAL": 1.0,    # 1 hour = 1 real second
	"FAST": 4.0,      # 1 hour = 0.25 real seconds
	"VERY_FAST": 12.0 # 1 hour = ~0.08 real seconds
}

const SPEED_NAMES: Array = ["PAUSED", "SLOW", "NORMAL", "FAST", "VERY FAST"]
const SPEED_VALUES: Array = [0.0, 0.5, 1.0, 4.0, 12.0]

# ============================================================================
# TIME QUERIES (Pure functions - no side effects)
# ============================================================================

static func get_hour_of_day(game_time: float) -> int:
	## Returns 0-23
	return int(game_time) % HOURS_PER_DAY

static func get_day_of_week(game_time: float) -> int:
	## Returns 1-7 (Monday = 1)
	return (int(game_time / HOURS_PER_DAY) % DAYS_PER_WEEK) + 1

static func get_week(game_time: float) -> int:
	## Returns week number (1-indexed)
	return int(game_time / HOURS_PER_WEEK) + 1

static func get_total_days(game_time: float) -> int:
	## Total days elapsed
	return int(game_time / HOURS_PER_DAY)

static func get_total_weeks(game_time: float) -> int:
	## Total complete weeks elapsed
	return int(game_time / HOURS_PER_WEEK)

static func format_time(game_time: float) -> String:
	## Format as "WEEK X, DAY Y - HH:00"
	var week = get_week(game_time)
	var day = get_day_of_week(game_time)
	var hour = get_hour_of_day(game_time)
	return "WEEK %d, DAY %d - %02d:00" % [week, day, hour]

static func format_time_compact(game_time: float) -> String:
	## Format as "W1D3 14:00"
	var week = get_week(game_time)
	var day = get_day_of_week(game_time)
	var hour = get_hour_of_day(game_time)
	return "W%dD%d %02d:00" % [week, day, hour]

# ============================================================================
# BOUNDARY DETECTION
# ============================================================================

static func is_hour_boundary(old_time: float, new_time: float) -> bool:
	## Did we cross an hour boundary?
	return int(new_time) > int(old_time)

static func is_day_boundary(old_time: float, new_time: float) -> bool:
	## Did we cross a day boundary?
	return get_total_days(new_time) > get_total_days(old_time)

static func is_week_boundary(old_time: float, new_time: float) -> bool:
	## Did we cross a week boundary?
	return get_total_weeks(new_time) > get_total_weeks(old_time)

static func hours_until_next_day(game_time: float) -> float:
	## Hours remaining until next day starts
	var current_hour = get_hour_of_day(game_time)
	return float(HOURS_PER_DAY - current_hour)

static func hours_until_next_week(game_time: float) -> float:
	## Hours remaining until next week starts
	var hours_into_week = int(game_time) % HOURS_PER_WEEK
	return float(HOURS_PER_WEEK - hours_into_week)

# ============================================================================
# CONVERSION UTILITIES
# ============================================================================

static func hours_to_weeks(hours: float) -> float:
	return hours / float(HOURS_PER_WEEK)

static func weeks_to_hours(weeks: float) -> float:
	return weeks * float(HOURS_PER_WEEK)

static func days_to_hours(days: float) -> float:
	return days * float(HOURS_PER_DAY)

static func hours_to_days(hours: float) -> float:
	return hours / float(HOURS_PER_DAY)

# ============================================================================
# INTERPOLATION HELPERS
# ============================================================================

static func get_tick_progress(accumulated_time: float) -> float:
	## Get progress through current hour tick (0.0 to 1.0)
	## Used for visual interpolation between discrete states
	return fmod(accumulated_time, 1.0)

static func lerp_position(prev_pos: Vector2, curr_pos: Vector2, tick_progress: float) -> Vector2:
	## Interpolate between two positions based on tick progress
	return prev_pos.lerp(curr_pos, tick_progress)

# ============================================================================
# TRAVEL TIME (in hours, not weeks)
# ============================================================================

## Travel times between zones in hours
## Based on original week-based times * HOURS_PER_WEEK
## Zone IDs from FCWTypes.ZoneId:
##   KUIPER=0, JUPITER=1, ASTEROID_BELT=2, SATURN=3, MARS=4, EARTH=5
const ZONE_TRAVEL_HOURS: Dictionary = {
	# Earth (5) <-> Mars (4): 2 weeks
	"4_5": 2 * HOURS_PER_WEEK,

	# Mars (4) <-> Outer planets: 3 weeks each
	"1_4": 3 * HOURS_PER_WEEK,  # Mars-Jupiter
	"2_4": 3 * HOURS_PER_WEEK,  # Mars-Asteroid Belt
	"3_4": 3 * HOURS_PER_WEEK,  # Mars-Saturn

	# Outer planets <-> Kuiper (0): 2 weeks each
	"0_1": 2 * HOURS_PER_WEEK,  # Kuiper-Jupiter
	"0_2": 2 * HOURS_PER_WEEK,  # Kuiper-Asteroid Belt
	"0_3": 2 * HOURS_PER_WEEK,  # Kuiper-Saturn
}

## Mars zone ID constant for multi-hop routing
const MARS_ZONE_ID: int = 4  # FCWTypes.ZoneId.MARS

static func get_travel_hours(from_zone: int, to_zone: int) -> int:
	## Get travel time in hours between two zones
	if from_zone == to_zone:
		return 0

	var key = "%d_%d" % [mini(from_zone, to_zone), maxi(from_zone, to_zone)]

	# Direct connection
	if ZONE_TRAVEL_HOURS.has(key):
		return ZONE_TRAVEL_HOURS[key]

	# Multi-hop - estimate via Mars (zone ID 4)
	var to_mars_a = get_travel_hours(from_zone, MARS_ZONE_ID)
	var to_mars_b = get_travel_hours(MARS_ZONE_ID, to_zone)
	return to_mars_a + to_mars_b

static func get_travel_weeks(from_zone: int, to_zone: int) -> float:
	## Get travel time in weeks (for display purposes)
	return float(get_travel_hours(from_zone, to_zone)) / float(HOURS_PER_WEEK)

# ============================================================================
# VELOCITY CONVERSION
# ============================================================================

static func velocity_per_hour(velocity_per_week: Vector2) -> Vector2:
	## Convert velocity from AU/week to AU/hour
	return velocity_per_week / float(HOURS_PER_WEEK)

static func velocity_per_week(velocity_per_hour: Vector2) -> Vector2:
	## Convert velocity from AU/hour to AU/week
	return velocity_per_hour * float(HOURS_PER_WEEK)
