extends Node2D

## Space background with parallax stars

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var star_count_far: int = 80
@export var star_count_mid: int = 40
@export var star_count_near: int = 20
@export var scroll_speed: float = 10.0  # Base pixels per second

# ============================================================================
# STATE
# ============================================================================

var far_stars: Array[Dictionary] = []
var mid_stars: Array[Dictionary] = []
var near_stars: Array[Dictionary] = []

var viewport_size: Vector2 = Vector2(1920, 1080)
var scroll_offset: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get actual viewport size
	viewport_size = get_viewport_rect().size
	if viewport_size.x < 100:  # Fallback if viewport not ready
		viewport_size = Vector2(1920, 1080)
	_generate_stars()

func _generate_stars() -> void:
	# Far stars - tiny, dim, slow parallax
	for i in range(star_count_far):
		far_stars.append({
			"pos": Vector2(randf() * viewport_size.x * 2, randf() * viewport_size.y),
			"size": randf_range(0.5, 1.0),
			"brightness": randf_range(0.2, 0.4),
			"parallax": 0.1
		})

	# Mid stars - small, medium brightness
	for i in range(star_count_mid):
		mid_stars.append({
			"pos": Vector2(randf() * viewport_size.x * 2, randf() * viewport_size.y),
			"size": randf_range(1.0, 1.5),
			"brightness": randf_range(0.4, 0.7),
			"parallax": 0.3,
			"twinkle_offset": randf() * TAU
		})

	# Near stars - larger, brighter, faster parallax
	for i in range(star_count_near):
		near_stars.append({
			"pos": Vector2(randf() * viewport_size.x * 2, randf() * viewport_size.y),
			"size": randf_range(1.5, 2.5),
			"brightness": randf_range(0.7, 1.0),
			"parallax": 0.6,
			"twinkle_offset": randf() * TAU
		})

# ============================================================================
# UPDATE
# ============================================================================

func _process(delta: float) -> void:
	scroll_offset += scroll_speed * delta
	queue_redraw()

func _draw() -> void:
	# Draw background
	draw_rect(Rect2(0, 0, viewport_size.x, viewport_size.y), Color(0.02, 0.02, 0.05))

	# Draw far stars
	for star in far_stars:
		var x = fmod(star.pos.x - scroll_offset * star.parallax, viewport_size.x * 2)
		if x < 0:
			x += viewport_size.x * 2
		if x < viewport_size.x:
			var color = Color(star.brightness, star.brightness, star.brightness * 1.1)
			draw_circle(Vector2(x, star.pos.y), star.size, color)

	# Draw mid stars with twinkle
	var time = Time.get_ticks_msec() / 1000.0
	for star in mid_stars:
		var x = fmod(star.pos.x - scroll_offset * star.parallax, viewport_size.x * 2)
		if x < 0:
			x += viewport_size.x * 2
		if x < viewport_size.x:
			var twinkle = 0.8 + 0.2 * sin(time * 2.0 + star.twinkle_offset)
			var brightness = star.brightness * twinkle
			var color = Color(brightness, brightness, brightness * 1.1)
			draw_circle(Vector2(x, star.pos.y), star.size, color)

	# Draw near stars with twinkle
	for star in near_stars:
		var x = fmod(star.pos.x - scroll_offset * star.parallax, viewport_size.x * 2)
		if x < 0:
			x += viewport_size.x * 2
		if x < viewport_size.x:
			var twinkle = 0.7 + 0.3 * sin(time * 3.0 + star.twinkle_offset)
			var brightness = star.brightness * twinkle
			# Slight color variation for near stars
			var color = Color(brightness, brightness * 0.95, brightness * 1.1)
			draw_circle(Vector2(x, star.pos.y), star.size, color)

# ============================================================================
# API
# ============================================================================

func set_scroll_speed(speed: float) -> void:
	scroll_speed = speed
