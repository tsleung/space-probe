extends Control
class_name LaunchAnimation

## Launch Animation for MOT
## EPIC timelapse showing all player choices before departure
## Maximum drama, explosions, and celebration!

signal animation_complete()

# ============================================================================
# ANIMATION STAGES
# ============================================================================

enum Stage {
	INTRO,
	CONSTRUCTION,
	ENGINE_INSTALL,
	SHIP_REVEAL,
	SYSTEMS_CHECK,
	CREW_BOARDING,
	CARGO_LOADING,
	FINAL_PREP,
	COUNTDOWN,
	IGNITION,
	LIFTOFF,
	MAX_Q,
	STAGE_SEP,
	ORBIT,
	TRANSFER_BURN,
	CRUISE,
	COMPLETE
}

const STAGE_DURATIONS = {
	Stage.INTRO: 2.5,
	Stage.CONSTRUCTION: 3.5,
	Stage.ENGINE_INSTALL: 2.5,
	Stage.SHIP_REVEAL: 2.0,
	Stage.SYSTEMS_CHECK: 2.0,
	Stage.CREW_BOARDING: 2.5,
	Stage.CARGO_LOADING: 2.0,
	Stage.FINAL_PREP: 2.0,
	Stage.COUNTDOWN: 4.0,
	Stage.IGNITION: 1.5,
	Stage.LIFTOFF: 2.5,
	Stage.MAX_Q: 2.0,
	Stage.STAGE_SEP: 2.0,
	Stage.ORBIT: 2.5,
	Stage.TRANSFER_BURN: 2.5,
	Stage.CRUISE: 3.0,
	Stage.COMPLETE: 2.0
}

# ============================================================================
# STATE
# ============================================================================

var mission_state: Dictionary = {}
var current_stage: Stage = Stage.INTRO
var stage_timer: float = 0.0
var total_timer: float = 0.0
var is_playing: bool = false
var skip_requested: bool = false

# Animation state
var ship_y: float = 0.0
var ship_x: float = 0.0
var ship_scale: float = 1.0
var ship_rotation: float = 0.0
var camera_shake: Vector2 = Vector2.ZERO
var flame_intensity: float = 0.0
var earth_angle: float = 0.0
var mars_angle: float = PI * 0.8
var transfer_progress: float = 0.0

# Particle systems
var particles: Array = []  # Array of particle dicts
var sparks: Array = []
var confetti: Array = []
var smoke_puffs: Array = []
var stars: Array = []
var nebula_clouds: Array = []
var distant_galaxies: Array = []
var shooting_stars: Array = []

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var canvas: Control = %AnimationCanvas
@onready var stage_label: Label = %StageLabel
@onready var detail_label: Label = %DetailLabel
@onready var skip_button: Button = %SkipButton
@onready var progress_bar: ProgressBar = %ProgressBar

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

	if canvas:
		canvas.draw.connect(_draw_animation)

	_generate_stars()

func _process(delta: float) -> void:
	if not is_playing:
		return

	stage_timer += delta
	total_timer += delta

	var stage_duration = STAGE_DURATIONS[current_stage]
	if stage_timer >= stage_duration or skip_requested:
		_advance_stage()

	_update_animation(delta)
	_update_particles(delta)

	if canvas:
		canvas.queue_redraw()

	_update_progress()

# ============================================================================
# PUBLIC API
# ============================================================================

func play_animation(state: Dictionary) -> void:
	mission_state = state
	current_stage = Stage.INTRO
	stage_timer = 0.0
	total_timer = 0.0
	is_playing = true
	skip_requested = false
	ship_y = 0.0
	ship_x = 0.0
	ship_scale = 1.0
	flame_intensity = 0.0
	transfer_progress = 0.0
	particles.clear()
	sparks.clear()
	confetti.clear()
	smoke_puffs.clear()

	_update_stage_display()

func set_state(state: Dictionary) -> void:
	mission_state = state

# ============================================================================
# PARTICLE GENERATION
# ============================================================================

func _generate_stars() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	stars.clear()
	nebula_clouds.clear()
	distant_galaxies.clear()

	# Generate varied stars with colors
	for i in range(180):
		var star_type = rng.randf()
		var color: Color
		var base_size: float

		if star_type < 0.6:
			# White/blue-white stars (most common)
			color = Color(1, 1, rng.randf_range(0.9, 1.0))
			base_size = rng.randf_range(0.5, 1.5)
		elif star_type < 0.8:
			# Yellow/orange stars
			color = Color(1, rng.randf_range(0.8, 0.95), rng.randf_range(0.5, 0.7))
			base_size = rng.randf_range(1.0, 2.0)
		elif star_type < 0.92:
			# Red giant stars
			color = Color(1, rng.randf_range(0.4, 0.6), rng.randf_range(0.3, 0.5))
			base_size = rng.randf_range(1.5, 2.5)
		else:
			# Blue giant stars (rare, bright)
			color = Color(rng.randf_range(0.7, 0.9), rng.randf_range(0.8, 1.0), 1)
			base_size = rng.randf_range(2.0, 3.5)

		stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"size": base_size,
			"color": color,
			"twinkle_speed": rng.randf_range(2.0, 6.0),
			"twinkle_offset": rng.randf() * TAU
		})

	# Generate nebula clouds (beautiful colorful gas clouds)
	var nebula_colors = [
		Color(0.8, 0.2, 0.5, 0.12),   # Pink/magenta
		Color(0.3, 0.5, 0.9, 0.1),    # Blue
		Color(0.6, 0.3, 0.8, 0.08),   # Purple
		Color(0.2, 0.7, 0.6, 0.06),   # Teal
		Color(0.9, 0.4, 0.2, 0.08),   # Orange/rust
	]

	for i in range(6):
		nebula_clouds.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"size": rng.randf_range(0.2, 0.4),
			"color": nebula_colors[i % nebula_colors.size()],
			"rotation": rng.randf() * TAU,
			"drift_speed": rng.randf_range(0.005, 0.015),
			"pulse_speed": rng.randf_range(0.3, 0.7),
			"layers": rng.randi_range(2, 4)
		})

	# Generate distant galaxies (small spiral/elliptical shapes)
	for i in range(4):
		var galaxy_type = rng.randf()
		distant_galaxies.append({
			"pos": Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.05, 0.95)),
			"size": rng.randf_range(12, 25),
			"rotation": rng.randf() * TAU,
			"tilt": rng.randf_range(0.2, 0.9),
			"color": Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.75, 0.95), rng.randf_range(0.6, 0.85), 0.35),
			"spin_speed": rng.randf_range(0.02, 0.08),
			"is_spiral": galaxy_type < 0.6
		})

func _spawn_spark(pos: Vector2, color: Color, count: int = 5) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(count):
		sparks.append({
			"pos": pos,
			"vel": Vector2(rng.randf_range(-100, 100), rng.randf_range(-150, 50)),
			"color": color,
			"life": 1.0,
			"max_life": 1.0
		})

func _spawn_confetti(pos: Vector2, count: int = 20) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE]
	for i in range(count):
		confetti.append({
			"pos": pos,
			"vel": Vector2(rng.randf_range(-200, 200), rng.randf_range(-300, -100)),
			"color": colors[rng.randi() % colors.size()],
			"rotation": rng.randf() * TAU,
			"rot_speed": rng.randf_range(-10, 10),
			"life": 3.0,
			"size": Vector2(rng.randf_range(4, 10), rng.randf_range(8, 16))
		})

func _spawn_smoke(pos: Vector2, vel: Vector2, count: int = 3) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(count):
		smoke_puffs.append({
			"pos": pos + Vector2(rng.randf_range(-20, 20), rng.randf_range(-10, 10)),
			"vel": vel + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20)),
			"radius": rng.randf_range(10, 25),
			"growth": rng.randf_range(20, 40),
			"life": 2.0,
			"max_life": 2.0
		})

func _spawn_explosion(pos: Vector2, size: float = 1.0) -> void:
	# Spawn lots of particles for explosion
	_spawn_spark(pos, Color(1, 0.8, 0.2), int(15 * size))
	_spawn_spark(pos, Color(1, 0.5, 0.1), int(10 * size))
	_spawn_spark(pos, Color(1, 0.3, 0.1), int(8 * size))
	_spawn_smoke(pos, Vector2(0, -50), int(5 * size))

func _update_particles(delta: float) -> void:
	# Update sparks
	for i in range(sparks.size() - 1, -1, -1):
		var spark = sparks[i]
		spark.life -= delta
		if spark.life <= 0:
			sparks.remove_at(i)
		else:
			spark.pos += spark.vel * delta
			spark.vel.y += 200 * delta  # Gravity

	# Update confetti
	for i in range(confetti.size() - 1, -1, -1):
		var c = confetti[i]
		c.life -= delta
		if c.life <= 0:
			confetti.remove_at(i)
		else:
			c.pos += c.vel * delta
			c.vel.y += 150 * delta  # Gravity
			c.vel.x *= 0.99  # Air resistance
			c.rotation += c.rot_speed * delta

	# Update smoke
	for i in range(smoke_puffs.size() - 1, -1, -1):
		var smoke = smoke_puffs[i]
		smoke.life -= delta
		if smoke.life <= 0:
			smoke_puffs.remove_at(i)
		else:
			smoke.pos += smoke.vel * delta
			smoke.radius += smoke.growth * delta
			smoke.vel.y -= 20 * delta  # Rise

# ============================================================================
# STAGE MANAGEMENT
# ============================================================================

func _advance_stage() -> void:
	skip_requested = false
	stage_timer = 0.0

	if current_stage == Stage.COMPLETE:
		is_playing = false
		animation_complete.emit()
		return

	var next_stage = (current_stage + 1) as Stage

	# Skip stages that don't apply to certain construction approaches
	var approach = mission_state.get("construction_approach", 0)

	# MAX_Q only applies to Earth launches (atmospheric flight)
	if next_stage == Stage.MAX_Q:
		if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY or \
		   approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			next_stage = Stage.STAGE_SEP  # Skip to staging

	current_stage = next_stage
	_on_stage_enter()
	_update_stage_display()

func _on_stage_enter() -> void:
	var center = canvas.size / 2 if canvas else Vector2(500, 300)

	match current_stage:
		Stage.SHIP_REVEAL:
			# Dramatic reveal sparks
			_spawn_spark(center + Vector2(-50, 0), Color(1, 0.9, 0.5), 10)
			_spawn_spark(center + Vector2(50, 0), Color(1, 0.9, 0.5), 10)

		Stage.IGNITION:
			flame_intensity = 0.3
			camera_shake = Vector2(2, 2)
			_spawn_smoke(center + Vector2(0, 120), Vector2(0, 30), 8)

		Stage.LIFTOFF:
			flame_intensity = 1.0
			camera_shake = Vector2(5, 5)

		Stage.MAX_Q:
			camera_shake = Vector2(8, 8)
			# Shock diamonds effect handled in draw

		Stage.STAGE_SEP:
			_spawn_explosion(center + Vector2(0, 50), 1.5)
			camera_shake = Vector2(3, 3)

		Stage.ORBIT:
			camera_shake = Vector2.ZERO
			# Celebration!
			_spawn_confetti(center + Vector2(-100, -50), 15)
			_spawn_confetti(center + Vector2(100, -50), 15)
			_spawn_confetti(center, 20)

		Stage.COMPLETE:
			# Final celebration
			for i in range(5):
				_spawn_confetti(center + Vector2(randf_range(-200, 200), randf_range(-100, 100)), 10)

func _update_stage_display() -> void:
	var title = ""
	var detail = ""

	match current_stage:
		Stage.INTRO:
			title = "MARS ODYSSEY TREK"
			detail = "Humanity's Greatest Journey Begins..."

		Stage.CONSTRUCTION:
			var approach = mission_state.get("construction_approach")
			if approach != null:
				var data = MOTTypes.CONSTRUCTION_APPROACHES[approach]
				match approach:
					MOTTypes.ConstructionApproach.EARTH_BUILT:
						title = "CAPE CANAVERAL ASSEMBLY"
						detail = "Building humanity's ark on the launchpad\n%s" % data.layman
					MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
						title = "ORBITAL CONSTRUCTION"
						detail = "Assembling in the void, 400km above Earth\n%s" % data.layman
					MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
						title = "LUNAR GATEWAY SHIPYARD"
						detail = "Forged in lunar orbit, ready to leap\n%s" % data.layman
			else:
				title = "SHIP CONSTRUCTION"
				detail = "Building the spacecraft..."

		Stage.ENGINE_INSTALL:
			var engine = mission_state.get("engine")
			if engine != null:
				var data = MOTTypes.ENGINES[engine]
				title = "ENGINE INTEGRATION"
				detail = "%s - \"%s\"\n%s" % [data.name.to_upper(), data.nickname, data.layman]
			else:
				title = "ENGINE INSTALLATION"
				detail = "Installing propulsion systems..."

		Stage.SHIP_REVEAL:
			var ship_class = mission_state.get("ship_class")
			if ship_class != null:
				var data = MOTTypes.SHIP_CLASSES[ship_class]
				title = "THE %s" % data.name.to_upper()
				detail = data.layman
			else:
				title = "VESSEL COMPLETE"
				detail = "Ready for the journey..."

		Stage.SYSTEMS_CHECK:
			var tier = mission_state.get("life_support")
			if tier != null:
				var data = MOTTypes.LIFE_SUPPORT_TIERS[tier]
				title = "SYSTEMS ACTIVATION"
				detail = "%s Life Support Online\n%d%% recycling efficiency" % [data.name, int(data.recycling_efficiency * 100)]
			else:
				title = "SYSTEMS CHECK"
				detail = "All systems nominal..."

		Stage.CREW_BOARDING:
			var crew = mission_state.get("crew", [])
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "CREW TRANSFER"
				detail = "%d astronauts floating through to the ship" % crew.size()
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "CREW BOARDING"
				detail = "%d explorers bounding across lunar regolith" % crew.size()
			else:
				title = "CREW BOARDING"
				detail = "%d brave souls ready to make history" % crew.size()

		Stage.CARGO_LOADING:
			var cargo_used = mission_state.get("cargo_used", 0)
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "CARGO TRANSFER"
				detail = "Docking %d kg in supply pods" % cargo_used
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "CARGO LOADING"
				detail = "Lunar rovers delivering %d kg of supplies" % cargo_used
			else:
				title = "CARGO MANIFEST"
				detail = "Loading %d kg of supplies and dreams" % cargo_used

		Stage.FINAL_PREP:
			var reliability = mission_state.get("reliability_estimate", 0.9)
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "UNDOCKING PREP"
				detail = "Station Control: Docking clamps ready to release\nReliability: %d%%" % int(reliability * 100)
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "FINAL PREPARATIONS"
				detail = "Lunar Gateway Control: All systems GO\nReliability: %d%%" % int(reliability * 100)
			else:
				title = "FINAL PREPARATIONS"
				detail = "Mission Control: All systems GO\nReliability: %d%%" % int(reliability * 100)

		Stage.COUNTDOWN:
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "UNDOCKING SEQUENCE"
				detail = "Releasing docking clamps..."
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "T-MINUS 10"
				detail = "Lunar launch - Earth watches from afar..."
			else:
				title = "T-MINUS 10"
				detail = "The world holds its breath..."

		Stage.IGNITION:
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "DEPARTURE BURN"
				detail = "Thrusters firing - clearing the station!"
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "MAIN ENGINE START"
				detail = "Ignition in lunar vacuum!"
			else:
				title = "MAIN ENGINE START"
				detail = "Ignition sequence initiated!"

		Stage.LIFTOFF:
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "DEPARTURE CONFIRMED"
				detail = "Clear of the station - accelerating to escape!"
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "LUNAR LIFTOFF!"
				detail = "Rising in 1/6th gravity - farewell Moon!"
			else:
				title = "LIFTOFF!"
				detail = "WE HAVE LIFTOFF!"

		Stage.MAX_Q:
			# Only shown for Earth launches
			title = "MAX Q"
			detail = "Maximum dynamic pressure - throttling up!"

		Stage.STAGE_SEP:
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "ESCAPE BURN COMPLETE"
				detail = "On trajectory for Trans-Mars Injection!"
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "LUNAR ESCAPE"
				detail = "Breaking free of lunar gravity!"
			else:
				title = "STAGE SEPARATION"
				detail = "First stage away! Second stage ignition!"

		Stage.ORBIT:
			var approach = mission_state.get("construction_approach", 0)
			if approach == MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
				title = "HELIOCENTRIC TRAJECTORY"
				detail = "Earth orbit escaped - now orbiting the Sun!"
			elif approach == MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
				title = "EARTH-MOON L1 TRANSIT"
				detail = "Passing through the Lagrange point!"
			else:
				title = "ORBIT ACHIEVED!"
				detail = "Circularizing at 400km - Preparing for TMI"

		Stage.TRANSFER_BURN:
			title = "TRANS-MARS INJECTION"
			detail = "Firing for Mars! No turning back now!"

		Stage.CRUISE:
			var window = mission_state.get("launch_window", {})
			var travel_days = window.get("travel_days", 180)
			title = "CRUISE PHASE"
			detail = "%d days to Mars\nThe adventure has begun!" % travel_days

		Stage.COMPLETE:
			title = "GODSPEED, EXPLORERS"
			detail = "Next stop: The Red Planet"

	if stage_label:
		stage_label.text = title
	if detail_label:
		detail_label.text = detail

func _update_progress() -> void:
	if not progress_bar:
		return

	var total_stages = Stage.COMPLETE + 1
	var base_progress = float(current_stage) / total_stages
	var stage_progress = stage_timer / STAGE_DURATIONS[current_stage]
	var total_progress = base_progress + (stage_progress / total_stages)

	progress_bar.value = total_progress * 100

# ============================================================================
# ANIMATION UPDATE
# ============================================================================

func _update_animation(delta: float) -> void:
	# Decay camera shake
	camera_shake = camera_shake.lerp(Vector2.ZERO, delta * 3)

	match current_stage:
		Stage.COUNTDOWN:
			# Building tension
			if stage_timer > 3.0:
				camera_shake = Vector2(1, 1)

		Stage.IGNITION:
			flame_intensity = lerp(flame_intensity, 0.5, delta * 3)
			_spawn_smoke(Vector2(canvas.size.x / 2, canvas.size.y * 0.7), Vector2(randf_range(-50, 50), 20), 1)

		Stage.LIFTOFF:
			ship_y -= delta * 80
			flame_intensity = 1.0
			# Continuous smoke
			if randf() < 0.3:
				_spawn_smoke(Vector2(canvas.size.x / 2, canvas.size.y * 0.8), Vector2(randf_range(-80, 80), 30), 2)

		Stage.MAX_Q:
			ship_y -= delta * 150
			ship_scale = max(0.6, ship_scale - delta * 0.15)
			flame_intensity = 1.2
			camera_shake = Vector2(sin(total_timer * 30) * 3, cos(total_timer * 25) * 3)

		Stage.STAGE_SEP:
			ship_y -= delta * 100
			ship_scale = max(0.4, ship_scale - delta * 0.1)
			flame_intensity = 0.8

		Stage.ORBIT:
			ship_scale = 0.3
			flame_intensity = lerp(flame_intensity, 0.0, delta * 2)
			earth_angle += delta * 0.3

		Stage.TRANSFER_BURN:
			flame_intensity = 0.6
			transfer_progress = min(1.0, stage_timer / STAGE_DURATIONS[Stage.TRANSFER_BURN])
			earth_angle += delta * 0.2
			mars_angle += delta * 0.15

		Stage.CRUISE:
			flame_intensity = lerp(flame_intensity, 0.0, delta * 2)
			transfer_progress = min(1.0, transfer_progress + delta * 0.2)
			earth_angle += delta * 0.15
			mars_angle += delta * 0.1

		Stage.COMPLETE:
			# Gentle drift
			earth_angle += delta * 0.1
			mars_angle += delta * 0.08

# ============================================================================
# DRAWING
# ============================================================================

func _draw_animation() -> void:
	if not canvas:
		return

	var center = canvas.size / 2
	var shake_offset = Vector2(
		randf_range(-camera_shake.x, camera_shake.x),
		randf_range(-camera_shake.y, camera_shake.y)
	)

	# Draw stars background (always)
	_draw_starfield()

	match current_stage:
		Stage.INTRO:
			_draw_intro_scene(center + shake_offset)

		Stage.CONSTRUCTION, Stage.ENGINE_INSTALL:
			_draw_construction_scene(center + shake_offset)

		Stage.SHIP_REVEAL, Stage.SYSTEMS_CHECK:
			_draw_reveal_scene(center + shake_offset)

		Stage.CREW_BOARDING:
			_draw_boarding_scene(center + shake_offset)

		Stage.CARGO_LOADING:
			_draw_cargo_scene(center + shake_offset)

		Stage.FINAL_PREP, Stage.COUNTDOWN:
			_draw_launchpad_scene(center + shake_offset)

		Stage.IGNITION, Stage.LIFTOFF, Stage.MAX_Q:
			_draw_launch_scene(center + shake_offset)

		Stage.STAGE_SEP:
			_draw_staging_scene(center + shake_offset)

		Stage.ORBIT, Stage.TRANSFER_BURN, Stage.CRUISE, Stage.COMPLETE:
			_draw_space_scene(center + shake_offset)

	# Draw particles on top
	_draw_particles()

func _draw_starfield() -> void:
	# Draw the Milky Way band first (subtle glow across the sky)
	_draw_milky_way()

	# Draw nebula clouds (behind everything else)
	_draw_nebulae()

	# Draw distant galaxies
	_draw_galaxies()

	# Draw stars with their individual colors
	for star in stars:
		var pos = Vector2(star.pos.x * canvas.size.x, star.pos.y * canvas.size.y)
		var twinkle = 0.5 + 0.5 * sin(total_timer * star.twinkle_speed + star.twinkle_offset)
		var alpha = 0.4 + 0.6 * twinkle
		var color = star.get("color", Color.WHITE)
		color.a = alpha

		# Draw glow for brighter stars
		if star.size > 1.5:
			var glow_color = Color(color.r, color.g, color.b, alpha * 0.2)
			canvas.draw_circle(pos, star.size * 3, glow_color)

		canvas.draw_circle(pos, star.size, color)

	# Draw occasional shooting stars
	_draw_shooting_stars()

func _draw_milky_way() -> void:
	## Draw a subtle band of light representing our galaxy
	var band_center_y = canvas.size.y * 0.35
	var band_angle = 0.15  # Slight tilt

	# Multiple layers for depth
	for layer in range(3):
		var layer_alpha = 0.03 - layer * 0.008
		var layer_width = 120 + layer * 60

		for i in range(20):
			var t = float(i) / 20
			var x = t * canvas.size.x
			var base_y = band_center_y + sin(t * 3 + band_angle) * 40
			var wobble = sin(t * 7 + total_timer * 0.1) * 15

			# Varying density along the band
			var density = 0.7 + 0.3 * sin(t * 5 + 1.5)
			var width = layer_width * density

			canvas.draw_circle(
				Vector2(x, base_y + wobble),
				width * 0.5,
				Color(0.9, 0.85, 0.7, layer_alpha * density)
			)

func _draw_nebulae() -> void:
	## Draw beautiful colorful gas clouds
	for nebula in nebula_clouds:
		var center = Vector2(nebula.pos.x * canvas.size.x, nebula.pos.y * canvas.size.y)
		var base_size = nebula.size * min(canvas.size.x, canvas.size.y)
		var pulse = 1.0 + 0.1 * sin(total_timer * nebula.pulse_speed)

		# Drift slowly
		center.x += sin(total_timer * nebula.drift_speed) * 10
		center.y += cos(total_timer * nebula.drift_speed * 0.7) * 8

		# Draw multiple overlapping circles for cloud effect
		var layers = nebula.get("layers", 3)
		for layer in range(layers):
			var layer_offset = Vector2(
				cos(nebula.rotation + layer * 1.2) * base_size * 0.3,
				sin(nebula.rotation + layer * 1.2) * base_size * 0.3
			)
			var layer_size = base_size * (1.0 - layer * 0.15) * pulse

			var color = nebula.color
			color.a = nebula.color.a * (1.0 - layer * 0.2)

			canvas.draw_circle(center + layer_offset, layer_size, color)

			# Add some wispy tendrils
			if layer == 0:
				for tendril in range(3):
					var tendril_angle = nebula.rotation + tendril * TAU / 3 + total_timer * 0.02
					var tendril_pos = center + Vector2(cos(tendril_angle), sin(tendril_angle)) * base_size * 0.8
					var tendril_color = Color(color.r, color.g, color.b, color.a * 0.5)
					canvas.draw_circle(tendril_pos, base_size * 0.4, tendril_color)

func _draw_galaxies() -> void:
	## Draw distant spiral and elliptical galaxies
	for galaxy in distant_galaxies:
		var center = Vector2(galaxy.pos.x * canvas.size.x, galaxy.pos.y * canvas.size.y)
		var size = galaxy.size
		var rotation = galaxy.rotation + total_timer * galaxy.spin_speed
		var tilt = galaxy.tilt
		var color = galaxy.color

		if galaxy.get("is_spiral", true):
			# Spiral galaxy - draw spiral arms
			_draw_spiral_galaxy(center, size, rotation, tilt, color)
		else:
			# Elliptical galaxy - just a glowing ellipse
			_draw_elliptical_galaxy(center, size, rotation, tilt, color)

func _draw_spiral_galaxy(center: Vector2, size: float, rotation: float, tilt: float, color: Color) -> void:
	# Central bulge
	canvas.draw_circle(center, size * 0.3, Color(color.r, color.g, color.b, color.a * 0.8))
	canvas.draw_circle(center, size * 0.15, Color(1, 0.95, 0.8, color.a))

	# Spiral arms
	for arm in range(2):
		var arm_offset = arm * PI
		for i in range(15):
			var t = float(i) / 15
			var spiral_angle = rotation + arm_offset + t * 2.5
			var radius = size * (0.3 + t * 0.7)

			# Apply tilt (makes it look 3D)
			var pos = center + Vector2(
				cos(spiral_angle) * radius,
				sin(spiral_angle) * radius * tilt
			)

			var point_size = size * 0.08 * (1.0 - t * 0.5)
			var point_alpha = color.a * (1.0 - t * 0.6)

			canvas.draw_circle(pos, point_size, Color(color.r, color.g, color.b, point_alpha))

func _draw_elliptical_galaxy(center: Vector2, size: float, rotation: float, tilt: float, color: Color) -> void:
	# Simple glowing ellipse
	for layer in range(3):
		var layer_size = size * (1.0 - layer * 0.25)
		var layer_alpha = color.a * (1.0 - layer * 0.3)

		# Draw as stretched circle (approximate ellipse)
		var points = 16
		var vertices = PackedVector2Array()
		for i in range(points):
			var angle = float(i) / points * TAU
			var x = cos(angle) * layer_size
			var y = sin(angle) * layer_size * tilt
			# Rotate
			var rotated_x = x * cos(rotation) - y * sin(rotation)
			var rotated_y = x * sin(rotation) + y * cos(rotation)
			vertices.append(center + Vector2(rotated_x, rotated_y))

		var colors = PackedColorArray()
		for i in range(points):
			colors.append(Color(color.r, color.g, color.b, layer_alpha))

		if vertices.size() >= 3:
			canvas.draw_polygon(vertices, colors)

func _draw_shooting_stars() -> void:
	## Occasionally spawn and draw shooting stars
	# Random chance to spawn a new one
	if randf() < 0.003 and shooting_stars.size() < 3:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		shooting_stars.append({
			"start": Vector2(rng.randf() * canvas.size.x, rng.randf_range(0, canvas.size.y * 0.4)),
			"angle": rng.randf_range(0.3, 0.8),
			"speed": rng.randf_range(400, 800),
			"length": rng.randf_range(30, 80),
			"life": 1.0,
			"color": Color(1, 1, rng.randf_range(0.8, 1.0))
		})

	# Update and draw
	for i in range(shooting_stars.size() - 1, -1, -1):
		var star = shooting_stars[i]
		star.life -= 0.02

		if star.life <= 0:
			shooting_stars.remove_at(i)
			continue

		var progress = 1.0 - star.life
		var pos = star.start + Vector2(
			cos(star.angle) * star.speed * progress,
			sin(star.angle) * star.speed * progress
		)

		# Draw the streak
		var tail_pos = pos - Vector2(cos(star.angle), sin(star.angle)) * star.length
		var alpha = star.life * 0.8

		# Glowing head
		canvas.draw_circle(pos, 2, Color(star.color.r, star.color.g, star.color.b, alpha))

		# Fading tail
		for j in range(5):
			var t = float(j) / 5
			var segment_pos = pos.lerp(tail_pos, t)
			var segment_alpha = alpha * (1.0 - t)
			canvas.draw_circle(segment_pos, 1.5 - t * 0.8, Color(star.color.r, star.color.g, star.color.b, segment_alpha))

func _draw_intro_scene(center: Vector2) -> void:
	# Dramatic Earth in corner
	canvas.draw_circle(Vector2(100, canvas.size.y - 80), 120, Color(0.1, 0.3, 0.6, 0.3))
	canvas.draw_circle(Vector2(100, canvas.size.y - 80), 100, Color(0.2, 0.4, 0.8, 0.5))

	# Mars in distance
	var mars_pulse = 0.8 + 0.2 * sin(total_timer * 2)
	canvas.draw_circle(Vector2(canvas.size.x - 80, 80), 25 * mars_pulse, Color(0.9, 0.4, 0.2, 0.8))

	# Connecting line (trajectory hint)
	var progress = min(1.0, stage_timer / STAGE_DURATIONS[Stage.INTRO])
	if progress > 0.3:
		var line_alpha = (progress - 0.3) / 0.7
		var line_end = Vector2(100, canvas.size.y - 80).lerp(Vector2(canvas.size.x - 80, 80), progress)
		canvas.draw_line(Vector2(100, canvas.size.y - 80), line_end, Color(1, 1, 1, line_alpha * 0.3), 2)

func _draw_construction_scene(center: Vector2) -> void:
	var approach = mission_state.get("construction_approach", 0)

	match approach:
		MOTTypes.ConstructionApproach.EARTH_BUILT:
			_draw_earth_construction(center)
		MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
			_draw_orbital_construction(center)
		MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			_draw_lunar_construction(center)
		_:
			_draw_earth_construction(center)

func _draw_earth_construction(center: Vector2) -> void:
	# Ground
	canvas.draw_rect(Rect2(0, center.y + 120, canvas.size.x, 100), Color(0.2, 0.25, 0.2))

	# Launch tower
	canvas.draw_rect(Rect2(center.x + 60, center.y - 80, 20, 200), Color(0.6, 0.3, 0.2))
	canvas.draw_rect(Rect2(center.x + 50, center.y - 80, 40, 10), Color(0.5, 0.25, 0.15))

	# Crane
	var crane_angle = sin(total_timer * 0.5) * 0.2
	var crane_base = center + Vector2(-80, -60)
	var crane_end = crane_base + Vector2(cos(crane_angle - PI/4) * 100, sin(crane_angle - PI/4) * 100)
	canvas.draw_line(crane_base, crane_end, Color(0.8, 0.6, 0.2), 4)

	# Ship being built
	var build_progress = stage_timer / (STAGE_DURATIONS[Stage.CONSTRUCTION] + STAGE_DURATIONS[Stage.ENGINE_INSTALL])
	_draw_ship_building(center + Vector2(0, 50), build_progress)

	# Welding sparks
	if current_stage == Stage.CONSTRUCTION:
		if int(total_timer * 8) % 3 == 0:
			_spawn_spark(center + Vector2(randf_range(-30, 30), randf_range(-40, 40)), Color(1, 0.9, 0.4), 3)

func _draw_orbital_construction(center: Vector2) -> void:
	# Earth below
	canvas.draw_circle(Vector2(center.x, canvas.size.y + 200), 280, Color(0.2, 0.4, 0.8))
	canvas.draw_arc(Vector2(center.x, canvas.size.y + 200), 280, PI, TAU, 32, Color(0.3, 0.5, 0.9), 3)

	# Space station structure
	var station_center = center + Vector2(-100, 0)
	canvas.draw_rect(Rect2(station_center.x - 60, station_center.y - 5, 120, 10), Color(0.7, 0.7, 0.75))
	canvas.draw_circle(station_center, 20, Color(0.6, 0.6, 0.65))

	# Solar panels
	for i in [-1, 1]:
		var panel_pos = station_center + Vector2(i * 80, 0)
		canvas.draw_rect(Rect2(panel_pos.x - 25, panel_pos.y - 8, 50, 16), Color(0.2, 0.2, 0.5))

	# Ship modules floating in
	var build_progress = stage_timer / STAGE_DURATIONS[Stage.CONSTRUCTION]
	var module_positions = [
		Vector2(80, -20),
		Vector2(60, 20),
		Vector2(100, 0)
	]

	for i in range(min(int(build_progress * 3) + 1, 3)):
		var target = center + Vector2(30, 0)
		var start = center + module_positions[i] + Vector2(100, 0)
		var pos = start.lerp(target, min(1.0, build_progress * 3 - i))
		canvas.draw_rect(Rect2(pos.x - 15, pos.y - 20, 30, 40), _get_ship_color())

	# Astronaut
	var astro_pos = center + Vector2(50 + sin(total_timer) * 10, -30 + cos(total_timer * 0.7) * 5)
	canvas.draw_circle(astro_pos, 5, Color(1, 1, 1))
	canvas.draw_circle(astro_pos + Vector2(0, 8), 8, Color(0.9, 0.9, 0.95))

func _draw_lunar_construction(center: Vector2) -> void:
	# Lunar surface
	canvas.draw_rect(Rect2(0, center.y + 100, canvas.size.x, 120), Color(0.4, 0.4, 0.42))

	# Craters
	for i in range(5):
		var crater_x = (i * 200 + 50) % int(canvas.size.x)
		canvas.draw_circle(Vector2(crater_x, center.y + 130), 30, Color(0.35, 0.35, 0.37))

	# Earth in sky
	canvas.draw_circle(Vector2(canvas.size.x - 100, 80), 40, Color(0.2, 0.4, 0.8))

	# Lunar base domes
	for i in range(3):
		var dome_x = center.x - 150 + i * 100
		canvas.draw_circle(Vector2(dome_x, center.y + 100), 35, Color(0.6, 0.6, 0.65, 0.8))
		canvas.draw_arc(Vector2(dome_x, center.y + 100), 35, PI, TAU, 16, Color(0.7, 0.7, 0.75), 2)

	# Ship on lunar launchpad
	var build_progress = stage_timer / (STAGE_DURATIONS[Stage.CONSTRUCTION] + STAGE_DURATIONS[Stage.ENGINE_INSTALL])
	_draw_ship_building(center + Vector2(0, 30), build_progress)

	# Lunar dust particles
	if randf() < 0.1:
		_spawn_spark(center + Vector2(randf_range(-100, 100), 100), Color(0.5, 0.5, 0.52, 0.5), 2)

func _draw_ship_building(pos: Vector2, progress: float) -> void:
	var hull_color = _get_ship_color()
	var engine_color = _get_engine_color()

	# Platform
	canvas.draw_rect(Rect2(pos.x - 50, pos.y + 60, 100, 8), Color(0.5, 0.5, 0.5))

	# Ship hull (builds up)
	var hull_height = 100 * min(1.0, progress * 1.5)
	if hull_height > 0:
		canvas.draw_rect(Rect2(pos.x - 25, pos.y + 60 - hull_height, 50, hull_height), hull_color)

	# Nose cone
	if progress > 0.5:
		var nose_alpha = (progress - 0.5) * 2
		var nose_color = Color(hull_color.r, hull_color.g, hull_color.b, nose_alpha)
		var points = PackedVector2Array([
			Vector2(pos.x - 25, pos.y - 40),
			Vector2(pos.x, pos.y - 75),
			Vector2(pos.x + 25, pos.y - 40)
		])
		canvas.draw_polygon(points, [nose_color])

	# Engine (in engine install stage)
	if current_stage >= Stage.ENGINE_INSTALL:
		var engine_progress = stage_timer / STAGE_DURATIONS[Stage.ENGINE_INSTALL] if current_stage == Stage.ENGINE_INSTALL else 1.0
		var engine_y = pos.y + 60 + 50 * (1.0 - engine_progress)
		canvas.draw_rect(Rect2(pos.x - 18, engine_y, 36, 20), engine_color)

		# Nozzle
		var nozzle_points = PackedVector2Array([
			Vector2(pos.x - 14, engine_y + 20),
			Vector2(pos.x - 22, engine_y + 40),
			Vector2(pos.x + 22, engine_y + 40),
			Vector2(pos.x + 14, engine_y + 20)
		])
		canvas.draw_polygon(nozzle_points, [engine_color.darkened(0.3)])

func _draw_reveal_scene(center: Vector2) -> void:
	# Dramatic lighting
	var reveal_progress = stage_timer / STAGE_DURATIONS[current_stage]

	# Spotlight effect
	var spotlight_radius = 50 + reveal_progress * 150
	canvas.draw_circle(center + Vector2(0, 20), spotlight_radius, Color(1, 1, 0.9, 0.1))

	# Full ship
	_draw_full_ship(center + Vector2(0, 20), 1.2)

	# Lens flare
	if reveal_progress > 0.3:
		var flare_alpha = (reveal_progress - 0.3) * 0.5
		canvas.draw_circle(center + Vector2(-60, -80), 20, Color(1, 0.9, 0.7, flare_alpha))
		canvas.draw_circle(center + Vector2(-40, -60), 8, Color(1, 0.95, 0.8, flare_alpha * 0.7))

func _draw_boarding_scene(center: Vector2) -> void:
	var approach = mission_state.get("construction_approach", 0)

	match approach:
		MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
			_draw_orbital_boarding(center)
		MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			_draw_lunar_boarding(center)
		_:
			_draw_earth_boarding(center)

func _draw_earth_boarding(center: Vector2) -> void:
	_draw_ship_on_pad(center)

	# Draw crew walking with more detail
	var crew_count = mission_state.get("crew", []).size()
	var progress = stage_timer / STAGE_DURATIONS[Stage.CREW_BOARDING]

	# Walkway
	canvas.draw_rect(Rect2(center.x - 150, center.y + 85, 120, 8), Color(0.5, 0.5, 0.55))

	for i in range(crew_count):
		var delay = i * 0.15
		var crew_progress = clamp((progress - delay) * 1.5, 0, 1)
		var start_x = center.x - 160
		var end_x = center.x - 35
		var x = lerp(start_x, end_x, crew_progress)
		var y = center.y + 80

		# Walking bob
		var bob = sin(crew_progress * 20) * 3 if crew_progress < 1 else 0

		# Spacesuit colors
		var suit_colors = [Color(0.9, 0.5, 0.2), Color(0.2, 0.5, 0.9), Color(0.2, 0.8, 0.3), Color(0.8, 0.2, 0.5)]
		var suit_color = suit_colors[i % 4]

		# Body
		canvas.draw_circle(Vector2(x, y - 20 + bob), 8, suit_color)  # Helmet
		canvas.draw_rect(Rect2(x - 6, y - 12 + bob, 12, 18), suit_color.darkened(0.1))  # Body

		# Visor
		canvas.draw_circle(Vector2(x, y - 20 + bob), 5, Color(0.2, 0.3, 0.4, 0.8))

		# Legs
		if crew_progress < 1:
			var leg_offset = sin(crew_progress * 20) * 4
			canvas.draw_line(Vector2(x - 3, y + 6 + bob), Vector2(x - 3 + leg_offset, y + 18), suit_color.darkened(0.2), 3)
			canvas.draw_line(Vector2(x + 3, y + 6 + bob), Vector2(x + 3 - leg_offset, y + 18), suit_color.darkened(0.2), 3)

func _draw_orbital_boarding(center: Vector2) -> void:
	## Crew boarding in orbit - EVA to ship docked at station

	# Earth below
	canvas.draw_circle(Vector2(center.x, canvas.size.y + 250), 300, Color(0.2, 0.4, 0.8))
	canvas.draw_arc(Vector2(center.x, canvas.size.y + 250), 300, PI, TAU, 32, Color(0.3, 0.5, 0.9), 3)

	# Station on left
	var station_center = center + Vector2(-120, 20)
	canvas.draw_rect(Rect2(station_center.x - 50, station_center.y - 5, 100, 10), Color(0.7, 0.7, 0.75))
	canvas.draw_circle(station_center, 18, Color(0.6, 0.6, 0.65))

	# Solar panels
	for i in [-1, 1]:
		var panel_pos = station_center + Vector2(i * 70, 0)
		canvas.draw_rect(Rect2(panel_pos.x - 20, panel_pos.y - 8, 40, 16), Color(0.2, 0.2, 0.5))

	# Ship docked on right
	_draw_full_ship(center + Vector2(60, 0), 0.9)

	# Docking port connection
	canvas.draw_rect(Rect2(station_center.x + 50, station_center.y - 4, 30, 8), Color(0.5, 0.5, 0.55))

	# Crew floating through (EVA style)
	var crew_count = mission_state.get("crew", []).size()
	var progress = stage_timer / STAGE_DURATIONS[Stage.CREW_BOARDING]

	for i in range(crew_count):
		var delay = i * 0.2
		var crew_progress = clamp((progress - delay) * 1.3, 0, 1)

		# Float from station to ship
		var start_pos = station_center + Vector2(20, -15 + i * 8)
		var end_pos = center + Vector2(35, -30 + i * 12)
		var pos = start_pos.lerp(end_pos, crew_progress)

		# Zero-G floating motion
		var float_offset = Vector2(sin(total_timer * 2 + i) * 5, cos(total_timer * 1.5 + i * 2) * 3)
		pos += float_offset * (1.0 - crew_progress)

		# EVA suit (bulkier than ground suits)
		var suit_colors = [Color(0.95, 0.95, 0.98), Color(0.9, 0.5, 0.2), Color(0.2, 0.5, 0.9), Color(0.2, 0.8, 0.3)]
		var suit_color = suit_colors[i % 4]

		# Bulky EVA suit
		canvas.draw_circle(pos + Vector2(0, -8), 9, suit_color)  # Helmet
		canvas.draw_rect(Rect2(pos.x - 8, pos.y, 16, 20), suit_color.darkened(0.1))  # Body

		# Gold visor
		canvas.draw_circle(pos + Vector2(0, -8), 6, Color(0.8, 0.6, 0.2, 0.9))

		# Life support backpack
		canvas.draw_rect(Rect2(pos.x - 10, pos.y + 2, 6, 15), Color(0.4, 0.4, 0.45))

		# Tether line
		var tether_color = Color(0.9, 0.9, 0.5, 0.7)
		canvas.draw_line(start_pos, pos, tether_color, 1.5)

func _draw_lunar_boarding(center: Vector2) -> void:
	## Crew boarding on lunar surface - low gravity hopping

	# Lunar surface
	canvas.draw_rect(Rect2(0, center.y + 100, canvas.size.x, 120), Color(0.4, 0.4, 0.42))

	# Craters
	for i in range(5):
		var crater_x = (i * 180 + 70) % int(canvas.size.x)
		canvas.draw_circle(Vector2(crater_x, center.y + 130), 25, Color(0.35, 0.35, 0.37))

	# Earth in sky
	canvas.draw_circle(Vector2(canvas.size.x - 100, 80), 40, Color(0.2, 0.4, 0.8))

	# Lunar habitat domes
	for i in range(2):
		var dome_x = center.x - 180 + i * 80
		canvas.draw_circle(Vector2(dome_x, center.y + 100), 30, Color(0.6, 0.6, 0.65, 0.8))
		canvas.draw_arc(Vector2(dome_x, center.y + 100), 30, PI, TAU, 16, Color(0.7, 0.7, 0.75), 2)

	# Ship on lunar pad
	_draw_full_ship(center + Vector2(50, 30), 0.9)

	# Lunar rover bringing crew
	var rover_x = center.x - 100 + stage_timer * 40
	if rover_x < center.x + 20:
		# Rover body
		canvas.draw_rect(Rect2(rover_x - 25, center.y + 75, 50, 20), Color(0.7, 0.7, 0.75))
		# Wheels
		for wx in [-20, 0, 20]:
			canvas.draw_circle(Vector2(rover_x + wx, center.y + 98), 8, Color(0.3, 0.3, 0.32))

	# Crew with lunar bounce walk
	var crew_count = mission_state.get("crew", []).size()
	var progress = stage_timer / STAGE_DURATIONS[Stage.CREW_BOARDING]

	for i in range(crew_count):
		var delay = i * 0.15
		var crew_progress = clamp((progress - delay) * 1.5, 0, 1)
		var start_x = center.x - 80
		var end_x = center.x + 25
		var x = lerp(start_x, end_x, crew_progress)
		var y = center.y + 78

		# Lunar bounce (longer, slower hops due to 1/6 gravity)
		var bounce_phase = crew_progress * 8  # Fewer, higher bounces
		var bounce = abs(sin(bounce_phase * PI)) * 15 if crew_progress < 1 else 0

		var suit_colors = [Color(0.95, 0.95, 0.98), Color(0.9, 0.5, 0.2), Color(0.2, 0.5, 0.9), Color(0.2, 0.8, 0.3)]
		var suit_color = suit_colors[i % 4]

		# Bulky lunar suit
		canvas.draw_circle(Vector2(x, y - 22 - bounce), 10, suit_color)  # Helmet
		canvas.draw_rect(Rect2(x - 8, y - 12 - bounce, 16, 22), suit_color.darkened(0.1))  # Body

		# Gold visor
		canvas.draw_circle(Vector2(x, y - 22 - bounce), 6, Color(0.8, 0.6, 0.2, 0.9))

		# Life support backpack
		canvas.draw_rect(Rect2(x + 6, y - 10 - bounce, 6, 18), Color(0.4, 0.4, 0.45))

func _draw_cargo_scene(center: Vector2) -> void:
	var approach = mission_state.get("construction_approach", 0)

	match approach:
		MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
			_draw_orbital_cargo(center)
		MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			_draw_lunar_cargo(center)
		_:
			_draw_earth_cargo(center)

func _draw_earth_cargo(center: Vector2) -> void:
	_draw_ship_on_pad(center)

	var progress = stage_timer / STAGE_DURATIONS[Stage.CARGO_LOADING]

	# Conveyor belt
	canvas.draw_rect(Rect2(center.x + 40, center.y + 70, 150, 12), Color(0.4, 0.4, 0.45))

	# Moving boxes
	for i in range(8):
		var box_delay = i * 0.1
		var box_progress = clamp((progress - box_delay) * 2, 0, 1)

		if box_progress > 0:
			var start_pos = Vector2(center.x + 180, center.y + 65)
			var mid_pos = Vector2(center.x + 40, center.y + 65)
			var end_pos = Vector2(center.x, center.y + 20 - i * 8)

			var pos: Vector2
			if box_progress < 0.5:
				pos = start_pos.lerp(mid_pos, box_progress * 2)
			else:
				pos = mid_pos.lerp(end_pos, (box_progress - 0.5) * 2)

			var box_colors = [Color(0.6, 0.4, 0.2), Color(0.5, 0.5, 0.6), Color(0.3, 0.5, 0.3)]
			canvas.draw_rect(Rect2(pos.x - 10, pos.y - 10, 20, 20), box_colors[i % 3])

func _draw_orbital_cargo(center: Vector2) -> void:
	## Cargo loading in orbit - cargo pods docking

	# Earth below
	canvas.draw_circle(Vector2(center.x, canvas.size.y + 250), 300, Color(0.2, 0.4, 0.8))
	canvas.draw_arc(Vector2(center.x, canvas.size.y + 250), 300, PI, TAU, 32, Color(0.3, 0.5, 0.9), 3)

	# Ship in center
	_draw_full_ship(center + Vector2(0, 10), 0.85)

	# Cargo pods approaching from different angles
	var progress = stage_timer / STAGE_DURATIONS[Stage.CARGO_LOADING]

	var pod_data = [
		{"start": Vector2(-180, -50), "end": Vector2(-35, -20)},
		{"start": Vector2(180, -30), "end": Vector2(35, 0)},
		{"start": Vector2(-150, 80), "end": Vector2(-30, 30)},
		{"start": Vector2(160, 100), "end": Vector2(30, 40)},
	]

	for i in range(pod_data.size()):
		var delay = i * 0.15
		var pod_progress = clamp((progress - delay) * 1.5, 0, 1)

		if pod_progress > 0:
			var start = center + pod_data[i].start
			var target = center + pod_data[i].end
			var pos = start.lerp(target, pod_progress)

			# Gentle floating
			var float_off = Vector2(sin(total_timer * 1.5 + i * 2) * 3, cos(total_timer + i) * 2)
			pos += float_off * (1.0 - pod_progress)

			# Cargo container
			var pod_color = Color(0.6, 0.5, 0.3) if i % 2 == 0 else Color(0.5, 0.5, 0.55)
			canvas.draw_rect(Rect2(pos.x - 18, pos.y - 12, 36, 24), pod_color)

			# Hazard stripes
			canvas.draw_rect(Rect2(pos.x - 18, pos.y - 12, 6, 24), Color(0.9, 0.7, 0.2))

			# Thrusters puffing
			if pod_progress < 0.9:
				var thrust_alpha = 0.5 * (1.0 - pod_progress)
				var thrust_dir = (target - start).normalized()
				var thrust_pos = pos - thrust_dir * 22
				canvas.draw_circle(thrust_pos, 4, Color(0.8, 0.8, 1.0, thrust_alpha))

	# Robotic arm
	var arm_angle = sin(total_timer * 0.8) * 0.3
	var arm_base = center + Vector2(-40, 60)
	var arm_mid = arm_base + Vector2(cos(arm_angle) * 50, sin(arm_angle) * 50 - 40)
	var arm_end = arm_mid + Vector2(cos(arm_angle - 0.5) * 40, sin(arm_angle - 0.5) * 40)
	canvas.draw_line(arm_base, arm_mid, Color(0.6, 0.6, 0.65), 4)
	canvas.draw_line(arm_mid, arm_end, Color(0.6, 0.6, 0.65), 3)
	canvas.draw_circle(arm_mid, 5, Color(0.5, 0.5, 0.55))

func _draw_lunar_cargo(center: Vector2) -> void:
	## Cargo loading on lunar surface

	# Lunar surface
	canvas.draw_rect(Rect2(0, center.y + 100, canvas.size.x, 120), Color(0.4, 0.4, 0.42))

	# Craters
	for i in range(4):
		var crater_x = (i * 200 + 100) % int(canvas.size.x)
		canvas.draw_circle(Vector2(crater_x, center.y + 135), 22, Color(0.35, 0.35, 0.37))

	# Earth in sky
	canvas.draw_circle(Vector2(canvas.size.x - 100, 80), 40, Color(0.2, 0.4, 0.8))

	# Ship on pad
	_draw_full_ship(center + Vector2(60, 30), 0.9)

	# Loading crane
	var crane_base = center + Vector2(-50, 100)
	var crane_top = center + Vector2(-50, -20)
	canvas.draw_line(crane_base, crane_top, Color(0.5, 0.5, 0.55), 6)

	# Crane arm swinging
	var crane_angle = sin(total_timer * 0.7) * 0.4 + 0.8
	var crane_arm_end = crane_top + Vector2(cos(crane_angle) * 100, sin(crane_angle) * 60)
	canvas.draw_line(crane_top, crane_arm_end, Color(0.5, 0.5, 0.55), 4)

	# Cargo on cable
	var progress = stage_timer / STAGE_DURATIONS[Stage.CARGO_LOADING]
	var cable_length = 40 + sin(total_timer * 2) * 5
	var cargo_pos = crane_arm_end + Vector2(0, cable_length)

	# Cable
	canvas.draw_line(crane_arm_end, cargo_pos, Color(0.3, 0.3, 0.35), 2)

	# Cargo crate swinging
	canvas.draw_rect(Rect2(cargo_pos.x - 15, cargo_pos.y - 15, 30, 30), Color(0.6, 0.5, 0.3))
	canvas.draw_rect(Rect2(cargo_pos.x - 15, cargo_pos.y - 15, 5, 30), Color(0.9, 0.7, 0.2))

	# Lunar rovers with cargo
	for i in range(2):
		var rover_delay = i * 0.3
		var rover_progress = clamp((progress - rover_delay) * 1.2, 0, 1)
		var rover_start = center.x - 180 + i * 40
		var rover_end = center.x + 20
		var rover_x = lerp(rover_start, rover_end, rover_progress)
		var rover_y = center.y + 78

		if rover_progress < 1:
			# Rover with cargo
			canvas.draw_rect(Rect2(rover_x - 20, rover_y - 5, 40, 15), Color(0.7, 0.7, 0.75))
			canvas.draw_rect(Rect2(rover_x - 12, rover_y - 20, 24, 15), Color(0.6, 0.5, 0.3))  # Cargo
			# Wheels with lunar dust
			for wx in [-15, 15]:
				canvas.draw_circle(Vector2(rover_x + wx, rover_y + 12), 6, Color(0.3, 0.3, 0.32))
				# Dust trail
				if rover_progress > 0.1 and rover_progress < 0.95:
					_spawn_spark(Vector2(rover_x + wx + 10, rover_y + 15), Color(0.5, 0.5, 0.52, 0.4), 1)

func _draw_launchpad_scene(center: Vector2) -> void:
	var approach = mission_state.get("construction_approach", 0)

	match approach:
		MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
			_draw_orbital_departure_prep(center)
		MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			_draw_lunar_launchpad(center)
		_:
			_draw_earth_launchpad(center)

func _draw_earth_launchpad(center: Vector2) -> void:
	# Ground with more detail
	canvas.draw_rect(Rect2(0, center.y + 130, canvas.size.x, 90), Color(0.25, 0.28, 0.25))

	# Flame trench
	canvas.draw_rect(Rect2(center.x - 60, center.y + 130, 120, 30), Color(0.15, 0.15, 0.18))

	_draw_ship_on_pad(center)

	# Launch tower with details
	canvas.draw_rect(Rect2(center.x + 55, center.y - 100, 25, 230), Color(0.6, 0.3, 0.2))

	# Umbilical connections
	if current_stage == Stage.FINAL_PREP:
		canvas.draw_line(Vector2(center.x + 55, center.y), Vector2(center.x + 25, center.y), Color(0.3, 0.3, 0.35), 3)
		canvas.draw_line(Vector2(center.x + 55, center.y + 40), Vector2(center.x + 25, center.y + 40), Color(0.3, 0.3, 0.35), 3)

	# Countdown display
	if current_stage == Stage.COUNTDOWN:
		var countdown = max(0, 10 - int(stage_timer * 2.5))
		var font = ThemeDB.fallback_font

		# Pulsing effect
		var pulse = 1.0 + sin(total_timer * 10) * 0.1
		var font_size = int(72 * pulse)

		var countdown_color = Color(1, 0.3, 0.2) if countdown <= 3 else Color(1, 0.8, 0.2)
		canvas.draw_string(font, Vector2(center.x - 25, center.y - 130), str(countdown), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, countdown_color)

		# Steam venting
		if countdown <= 5:
			_spawn_smoke(center + Vector2(randf_range(-40, 40), 120), Vector2(randf_range(-30, 30), -20), 1)

func _draw_orbital_departure_prep(center: Vector2) -> void:
	## Orbital: Ship undocking from station, not a ground launch

	# Earth below
	canvas.draw_circle(Vector2(center.x, canvas.size.y + 250), 300, Color(0.2, 0.4, 0.8))
	canvas.draw_arc(Vector2(center.x, canvas.size.y + 250), 300, PI, TAU, 32, Color(0.3, 0.5, 0.9), 3)

	# Station
	var station_center = center + Vector2(-100, 30)
	canvas.draw_rect(Rect2(station_center.x - 50, station_center.y - 5, 100, 10), Color(0.7, 0.7, 0.75))
	canvas.draw_circle(station_center, 18, Color(0.6, 0.6, 0.65))

	# Solar panels
	for i in [-1, 1]:
		var panel_pos = station_center + Vector2(i * 70, 0)
		canvas.draw_rect(Rect2(panel_pos.x - 20, panel_pos.y - 8, 40, 16), Color(0.2, 0.2, 0.5))

	# Ship (undocking)
	var undock_progress = 0.0
	if current_stage == Stage.COUNTDOWN:
		undock_progress = stage_timer / STAGE_DURATIONS[Stage.COUNTDOWN]

	var ship_offset = Vector2(60 + undock_progress * 40, 0)
	_draw_full_ship(center + ship_offset, 0.9)

	# Docking clamps releasing
	if current_stage == Stage.FINAL_PREP:
		# Clamps still attached
		canvas.draw_rect(Rect2(center.x + 20, center.y + 26, 40, 8), Color(0.5, 0.5, 0.55))
		# Blinking ready lights
		var blink = int(total_timer * 3) % 2 == 0
		canvas.draw_circle(center + Vector2(30, 22), 4, Color(0.2, 0.9, 0.2) if blink else Color(0.1, 0.4, 0.1))

	if current_stage == Stage.COUNTDOWN:
		# Clamps retracting
		var clamp_retract = undock_progress * 30
		if undock_progress < 0.5:
			canvas.draw_rect(Rect2(center.x + 20 - clamp_retract, center.y + 26, 40, 8), Color(0.5, 0.5, 0.55))

		# "UNDOCKING" text instead of countdown numbers
		var font = ThemeDB.fallback_font
		var alpha = 0.5 + sin(total_timer * 5) * 0.3
		canvas.draw_string(font, Vector2(center.x - 60, center.y - 80), "UNDOCKING", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color(0.3, 0.9, 0.3, alpha))

		# Cold gas thrusters puffing
		if undock_progress > 0.3:
			var puff_alpha = sin(total_timer * 10) * 0.3 + 0.5
			canvas.draw_circle(center + ship_offset + Vector2(-30, 0), 5, Color(0.8, 0.8, 1.0, puff_alpha))

func _draw_lunar_launchpad(center: Vector2) -> void:
	## Lunar launch - on the Moon's surface

	# Lunar surface
	canvas.draw_rect(Rect2(0, center.y + 100, canvas.size.x, 120), Color(0.4, 0.4, 0.42))

	# Craters
	for i in range(4):
		var crater_x = (i * 200 + 80) % int(canvas.size.x)
		canvas.draw_circle(Vector2(crater_x, center.y + 130), 22, Color(0.35, 0.35, 0.37))

	# Earth in sky (beautiful blue marble)
	canvas.draw_circle(Vector2(canvas.size.x - 100, 80), 40, Color(0.2, 0.4, 0.8))

	# Lunar base in background
	for i in range(3):
		var dome_x = center.x - 200 + i * 120
		canvas.draw_circle(Vector2(dome_x, center.y + 100), 25, Color(0.55, 0.55, 0.6, 0.7))

	# Ship on lunar pad
	_draw_full_ship(center + Vector2(0, 30), 1.0)

	# Lightweight lunar tower (lower gravity = lighter structure)
	canvas.draw_rect(Rect2(center.x + 50, center.y - 40, 15, 140), Color(0.6, 0.6, 0.65))

	if current_stage == Stage.FINAL_PREP:
		# Umbilicals
		canvas.draw_line(Vector2(center.x + 50, center.y + 10), Vector2(center.x + 25, center.y + 10), Color(0.4, 0.4, 0.45), 2)

	if current_stage == Stage.COUNTDOWN:
		var countdown = max(0, 10 - int(stage_timer * 2.5))
		var font = ThemeDB.fallback_font

		var pulse = 1.0 + sin(total_timer * 10) * 0.1
		var font_size = int(72 * pulse)

		var countdown_color = Color(1, 0.3, 0.2) if countdown <= 3 else Color(1, 0.8, 0.2)
		canvas.draw_string(font, Vector2(center.x - 25, center.y - 100), str(countdown), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, countdown_color)

		# No steam on Moon (vacuum!) - but maybe some venting
		if countdown <= 3:
			# Propellant venting (quickly disperses in vacuum)
			var vent_alpha = 0.4 * (1.0 - stage_timer * 0.1)
			canvas.draw_circle(center + Vector2(randf_range(-30, 30), 90), 8, Color(0.8, 0.8, 0.85, vent_alpha))

func _draw_launch_scene(center: Vector2) -> void:
	var approach = mission_state.get("construction_approach", 0)

	match approach:
		MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
			_draw_orbital_departure(center)
		MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			_draw_lunar_launch(center)
		_:
			_draw_earth_launch(center)

func _draw_earth_launch(center: Vector2) -> void:
	## Traditional ground launch from Earth

	# Ground (scrolling down effect)
	var ground_y = center.y + 130 - ship_y * 0.3
	if ground_y < canvas.size.y:
		canvas.draw_rect(Rect2(0, ground_y, canvas.size.x, canvas.size.y - ground_y + 100), Color(0.25, 0.28, 0.25))

		# Launch tower receding
		var tower_y = center.y - 100 - ship_y * 0.3
		canvas.draw_rect(Rect2(center.x + 55, tower_y, 25, 230), Color(0.6, 0.3, 0.2))

	# Ship
	var ship_pos = center + Vector2(0, ship_y)
	_draw_ship_flying(ship_pos, ship_scale)

	# MASSIVE exhaust
	_draw_rocket_exhaust(ship_pos, ship_scale, flame_intensity)

	# Smoke trail (only in atmosphere)
	if current_stage >= Stage.LIFTOFF:
		var trail_start = ship_pos + Vector2(0, 60 * ship_scale)
		var trail_end = Vector2(center.x, center.y + 150)
		_draw_smoke_trail(trail_start, trail_end)

func _draw_orbital_departure(center: Vector2) -> void:
	## Orbital departure - ship moving away from station, then burn

	# Earth below (always visible)
	canvas.draw_circle(Vector2(center.x, canvas.size.y + 200), 280, Color(0.2, 0.4, 0.8))
	canvas.draw_arc(Vector2(center.x, canvas.size.y + 200), 280, PI, TAU, 32, Color(0.3, 0.5, 0.9), 3)

	# Station receding
	var station_scale = max(0.3, 1.0 - abs(ship_y) * 0.005)
	var station_center = center + Vector2(-150 - abs(ship_y) * 0.3, 50 + abs(ship_y) * 0.1)
	canvas.draw_rect(Rect2(station_center.x - 30 * station_scale, station_center.y - 3, 60 * station_scale, 6), Color(0.6, 0.6, 0.65))
	canvas.draw_circle(station_center, 12 * station_scale, Color(0.5, 0.5, 0.55))

	# Ship moving right and up
	var ship_pos = center + Vector2(50 + abs(ship_y) * 0.5, ship_y * 0.3)
	_draw_full_ship(ship_pos, ship_scale)

	# Engine burn (no smoke in vacuum!)
	if flame_intensity > 0:
		_draw_vacuum_exhaust(ship_pos, ship_scale, flame_intensity)

	# Thruster puffs for attitude control
	if current_stage == Stage.IGNITION:
		var puff_alpha = sin(total_timer * 8) * 0.3 + 0.4
		canvas.draw_circle(ship_pos + Vector2(-25, -20), 4, Color(0.8, 0.8, 1.0, puff_alpha))
		canvas.draw_circle(ship_pos + Vector2(25, -20), 4, Color(0.8, 0.8, 1.0, puff_alpha))

func _draw_lunar_launch(center: Vector2) -> void:
	## Lunar launch - lower gravity, no atmosphere

	# Lunar surface receding (slower due to lower gravity)
	var ground_y = center.y + 100 - ship_y * 0.2
	if ground_y < canvas.size.y:
		canvas.draw_rect(Rect2(0, ground_y, canvas.size.x, canvas.size.y - ground_y + 100), Color(0.4, 0.4, 0.42))

		# Craters
		for i in range(4):
			var crater_x = (i * 200 + 80) % int(canvas.size.x)
			var crater_y = ground_y + 30
			if crater_y < canvas.size.y:
				canvas.draw_circle(Vector2(crater_x, crater_y), 22, Color(0.35, 0.35, 0.37))

		# Tower receding
		var tower_y = center.y - 40 - ship_y * 0.2
		if tower_y < canvas.size.y:
			canvas.draw_rect(Rect2(center.x + 50, tower_y, 15, 140), Color(0.6, 0.6, 0.65))

	# Earth in sky (always there!)
	canvas.draw_circle(Vector2(canvas.size.x - 100, 80), 40, Color(0.2, 0.4, 0.8))

	# Ship (ascending slower due to lower gravity needed)
	var ship_pos = center + Vector2(0, ship_y)
	_draw_ship_flying(ship_pos, ship_scale)

	# Vacuum exhaust (no billowing smoke)
	if flame_intensity > 0:
		_draw_vacuum_exhaust(ship_pos, ship_scale, flame_intensity)

	# Lunar dust kicked up (only near surface)
	if abs(ship_y) < 100 and current_stage == Stage.LIFTOFF:
		for i in range(3):
			var dust_x = center.x + randf_range(-80, 80)
			var dust_y = ground_y - 10
			if dust_y < canvas.size.y:
				var dust_alpha = 0.4 * (1.0 - abs(ship_y) / 100.0)
				canvas.draw_circle(Vector2(dust_x, dust_y), 15 + randf() * 10, Color(0.5, 0.5, 0.52, dust_alpha))

func _draw_vacuum_exhaust(pos: Vector2, scale: float, intensity: float) -> void:
	## Engine exhaust in vacuum - no billowing, just the flame cone
	if intensity <= 0:
		return

	var nozzle_y = pos.y + 100 * scale

	# Clean, focused exhaust plume (no air to spread it)
	var flame_length = (100 + sin(total_timer * 25) * 15) * intensity * scale

	# Outer glow
	var outer_points = PackedVector2Array([
		Vector2(pos.x - 20 * scale, nozzle_y),
		Vector2(pos.x, nozzle_y + flame_length),
		Vector2(pos.x + 20 * scale, nozzle_y)
	])
	canvas.draw_polygon(outer_points, [Color(0.4, 0.5, 1.0, 0.4 * intensity)])

	# Middle layer
	var mid_length = flame_length * 0.85
	var mid_points = PackedVector2Array([
		Vector2(pos.x - 14 * scale, nozzle_y),
		Vector2(pos.x, nozzle_y + mid_length),
		Vector2(pos.x + 14 * scale, nozzle_y)
	])
	canvas.draw_polygon(mid_points, [Color(0.6, 0.7, 1.0, 0.7 * intensity)])

	# Core (bright white-blue)
	var inner_length = flame_length * 0.6
	var inner_points = PackedVector2Array([
		Vector2(pos.x - 8 * scale, nozzle_y),
		Vector2(pos.x, nozzle_y + inner_length),
		Vector2(pos.x + 8 * scale, nozzle_y)
	])
	canvas.draw_polygon(inner_points, [Color(0.9, 0.95, 1.0, intensity)])

func _draw_staging_scene(center: Vector2) -> void:
	var approach = mission_state.get("construction_approach", 0)

	match approach:
		MOTTypes.ConstructionApproach.ORBITAL_ASSEMBLY:
			_draw_orbital_staging(center)
		MOTTypes.ConstructionApproach.LUNAR_SHIPYARD:
			_draw_lunar_staging(center)
		_:
			_draw_earth_staging(center)

func _draw_earth_staging(center: Vector2) -> void:
	## Traditional atmospheric staging

	# First stage falling away
	var sep_progress = stage_timer / STAGE_DURATIONS[Stage.STAGE_SEP]
	var stage1_pos = center + Vector2(0, ship_y + sep_progress * 150)
	var stage1_rot = sep_progress * 0.5

	# Draw separated first stage
	canvas.draw_set_transform(stage1_pos, stage1_rot, Vector2.ONE * 0.3)
	canvas.draw_rect(Rect2(-20, -30, 40, 60), _get_ship_color().darkened(0.2))
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Main ship continuing
	var ship_pos = center + Vector2(0, ship_y - sep_progress * 50)
	_draw_ship_flying(ship_pos, ship_scale * 0.8)
	_draw_rocket_exhaust(ship_pos, ship_scale * 0.8, flame_intensity)

func _draw_orbital_staging(center: Vector2) -> void:
	## Orbital - no staging needed, just continued departure burn

	# Earth below
	canvas.draw_circle(Vector2(center.x, canvas.size.y + 150), 250, Color(0.2, 0.4, 0.8))
	canvas.draw_arc(Vector2(center.x, canvas.size.y + 150), 250, PI, TAU, 32, Color(0.3, 0.5, 0.9), 3)

	# Ship continuing burn
	var ship_pos = center + Vector2(80, -50)
	_draw_full_ship(ship_pos, ship_scale * 0.7)
	_draw_vacuum_exhaust(ship_pos, ship_scale * 0.7, flame_intensity)

	# Station now very small in distance
	var station_center = center + Vector2(-200, 100)
	canvas.draw_circle(station_center, 8, Color(0.5, 0.5, 0.55))

func _draw_lunar_staging(center: Vector2) -> void:
	## Lunar staging - similar to orbital but with Moon below

	# Moon surface far below
	canvas.draw_rect(Rect2(0, center.y + 180, canvas.size.x, 60), Color(0.35, 0.35, 0.37))

	# Earth in sky
	canvas.draw_circle(Vector2(canvas.size.x - 100, 100), 45, Color(0.2, 0.4, 0.8))

	# Ship
	var ship_pos = center + Vector2(0, -60)
	_draw_full_ship(ship_pos, ship_scale * 0.7)
	_draw_vacuum_exhaust(ship_pos, ship_scale * 0.7, flame_intensity)

func _draw_space_scene(center: Vector2) -> void:
	# Dramatic Sun with corona and lens flares
	var sun_pos = Vector2(70, center.y - 20)
	_draw_dramatic_sun(sun_pos, center)

	# Earth orbit with subtle glow
	var orbit_radius_earth = 110.0
	_draw_glowing_orbit(center, orbit_radius_earth, Color(0.3, 0.5, 0.9, 0.3))

	# Mars orbit
	var orbit_radius_mars = 190.0
	_draw_glowing_orbit(center, orbit_radius_mars, Color(0.9, 0.5, 0.3, 0.25))

	# Earth with atmosphere glow and city lights on dark side
	var earth_pos = center + Vector2(cos(earth_angle), sin(earth_angle)) * orbit_radius_earth
	_draw_detailed_earth(earth_pos, sun_pos)

	# Mars with polar caps
	var mars_pos = center + Vector2(cos(mars_angle), sin(mars_angle)) * orbit_radius_mars
	_draw_detailed_mars(mars_pos)

	# Transfer trajectory with glowing trail
	if current_stage >= Stage.TRANSFER_BURN:
		_draw_transfer_arc(center, earth_pos, mars_pos, transfer_progress)

	# Ship on transfer
	if current_stage >= Stage.TRANSFER_BURN:
		var ship_travel = earth_pos.lerp(mars_pos, transfer_progress * 0.7)
		_draw_ship_tiny(ship_travel, transfer_progress)

		# Engine burn with glow
		if flame_intensity > 0.1:
			var flame_dir = (mars_pos - earth_pos).normalized()
			var flame_pos = ship_travel - flame_dir * 8
			# Outer glow
			canvas.draw_circle(flame_pos, 8 * flame_intensity, Color(0.3, 0.5, 1.0, flame_intensity * 0.3))
			# Core
			canvas.draw_circle(flame_pos, 4 * flame_intensity, Color(0.6, 0.8, 1.0, flame_intensity))

func _draw_dramatic_sun(pos: Vector2, scene_center: Vector2) -> void:
	## Draw a beautiful sun with corona and rays

	# Outer corona (very large, subtle)
	for i in range(5):
		var corona_size = 100 - i * 15
		var corona_alpha = 0.03 + i * 0.01
		canvas.draw_circle(pos, corona_size, Color(1, 0.9, 0.6, corona_alpha))

	# Sun rays (radiating lines)
	var ray_count = 12
	for i in range(ray_count):
		var angle = (float(i) / ray_count) * TAU + total_timer * 0.02
		var ray_length = 70 + sin(angle * 3 + total_timer) * 15
		var ray_end = pos + Vector2(cos(angle), sin(angle)) * ray_length
		var ray_alpha = 0.15 + sin(angle * 2 + total_timer * 0.5) * 0.05
		canvas.draw_line(pos, ray_end, Color(1, 0.95, 0.7, ray_alpha), 2)

	# Main sun body
	canvas.draw_circle(pos, 32, Color(1, 0.98, 0.9))
	canvas.draw_circle(pos, 28, Color(1, 0.95, 0.8))

	# Sun surface detail (subtle darker spots)
	canvas.draw_circle(pos + Vector2(-8, 5), 6, Color(0.95, 0.85, 0.6, 0.3))
	canvas.draw_circle(pos + Vector2(10, -8), 4, Color(0.95, 0.85, 0.6, 0.2))

	# Lens flare (classic cinematic effect)
	var flare_dir = (scene_center - pos).normalized()
	var flare_positions = [0.3, 0.5, 0.7, 0.85]
	var flare_sizes = [8, 12, 6, 15]
	var flare_colors = [
		Color(1, 0.8, 0.4, 0.25),
		Color(0.4, 0.8, 1, 0.15),
		Color(1, 0.6, 0.8, 0.2),
		Color(0.6, 1, 0.8, 0.1)
	]

	for i in range(flare_positions.size()):
		var flare_pos = pos + flare_dir * (pos.distance_to(scene_center) * flare_positions[i] * 2)
		canvas.draw_circle(flare_pos, flare_sizes[i], flare_colors[i])

func _draw_glowing_orbit(orbit_center: Vector2, radius: float, color: Color) -> void:
	## Draw orbit with subtle glow effect
	# Outer glow
	canvas.draw_arc(orbit_center, radius, 0, TAU, 64, Color(color.r, color.g, color.b, color.a * 0.3), 4)
	# Main line
	canvas.draw_arc(orbit_center, radius, 0, TAU, 64, color, 1.5)

func _draw_detailed_earth(pos: Vector2, sun_pos: Vector2) -> void:
	## Draw Earth with atmosphere glow and detail
	var radius = 16.0

	# Atmosphere glow
	canvas.draw_circle(pos, radius + 6, Color(0.4, 0.6, 1.0, 0.15))
	canvas.draw_circle(pos, radius + 3, Color(0.5, 0.7, 1.0, 0.25))

	# Main planet
	canvas.draw_circle(pos, radius, Color(0.15, 0.4, 0.75))

	# Continents (simplified)
	var continent_angle = total_timer * 0.1
	canvas.draw_circle(pos + Vector2(cos(continent_angle) * 5, sin(continent_angle * 0.5) * 8), 6, Color(0.3, 0.6, 0.35, 0.7))
	canvas.draw_circle(pos + Vector2(cos(continent_angle + 2) * 7, sin(continent_angle + 1) * 4), 4, Color(0.35, 0.55, 0.3, 0.6))

	# Polar ice caps
	canvas.draw_circle(pos + Vector2(0, -radius + 3), 5, Color(0.95, 0.98, 1.0, 0.8))
	canvas.draw_circle(pos + Vector2(0, radius - 4), 4, Color(0.9, 0.95, 1.0, 0.6))

	# Cloud wisps
	var cloud_offset = Vector2(sin(total_timer * 0.3) * 3, cos(total_timer * 0.2) * 2)
	canvas.draw_circle(pos + cloud_offset + Vector2(4, -3), 4, Color(1, 1, 1, 0.4))

func _draw_detailed_mars(pos: Vector2) -> void:
	## Draw Mars with polar cap and surface detail
	var radius = 13.0

	# Subtle atmosphere
	canvas.draw_circle(pos, radius + 2, Color(0.9, 0.6, 0.4, 0.1))

	# Main planet body
	canvas.draw_circle(pos, radius, Color(0.85, 0.45, 0.25))

	# Darker regions (maria)
	canvas.draw_circle(pos + Vector2(-3, 2), 5, Color(0.6, 0.3, 0.2, 0.5))
	canvas.draw_circle(pos + Vector2(5, -1), 4, Color(0.65, 0.35, 0.2, 0.4))

	# Olympus Mons (bright spot)
	canvas.draw_circle(pos + Vector2(-5, -4), 2, Color(0.95, 0.6, 0.4, 0.6))

	# North polar ice cap (white)
	canvas.draw_circle(pos + Vector2(0, -radius + 3), 4, Color(0.95, 0.95, 1.0, 0.9))

	# Valles Marineris (dark line)
	var vm_start = pos + Vector2(-8, 1)
	var vm_end = pos + Vector2(6, 3)
	canvas.draw_line(vm_start, vm_end, Color(0.5, 0.25, 0.15, 0.4), 1.5)

func _draw_ship_on_pad(center: Vector2) -> void:
	_draw_full_ship(center + Vector2(0, 20), 1.0)

func _draw_full_ship(pos: Vector2, scale: float) -> void:
	var hull_color = _get_ship_color()
	var engine_color = _get_engine_color()

	# Main hull
	canvas.draw_rect(Rect2(pos.x - 25 * scale, pos.y - 50 * scale, 50 * scale, 100 * scale), hull_color)

	# Nose cone
	var points = PackedVector2Array([
		Vector2(pos.x - 25 * scale, pos.y - 50 * scale),
		Vector2(pos.x, pos.y - 85 * scale),
		Vector2(pos.x + 25 * scale, pos.y - 50 * scale)
	])
	canvas.draw_polygon(points, [hull_color])

	# Window
	canvas.draw_circle(pos + Vector2(0, -30) * scale, 8 * scale, Color(0.2, 0.3, 0.4))
	canvas.draw_circle(pos + Vector2(0, -30) * scale, 6 * scale, Color(0.3, 0.4, 0.5))

	# Engine section
	canvas.draw_rect(Rect2(pos.x - 22 * scale, pos.y + 50 * scale, 44 * scale, 25 * scale), engine_color)

	# Nozzle
	var nozzle_points = PackedVector2Array([
		Vector2(pos.x - 18 * scale, pos.y + 75 * scale),
		Vector2(pos.x - 28 * scale, pos.y + 100 * scale),
		Vector2(pos.x + 28 * scale, pos.y + 100 * scale),
		Vector2(pos.x + 18 * scale, pos.y + 75 * scale)
	])
	canvas.draw_polygon(nozzle_points, [engine_color.darkened(0.3)])

	# Fins
	for i in [-1, 1]:
		var fin_points = PackedVector2Array([
			Vector2(pos.x + 25 * i * scale, pos.y + 30 * scale),
			Vector2(pos.x + 45 * i * scale, pos.y + 90 * scale),
			Vector2(pos.x + 25 * i * scale, pos.y + 90 * scale)
		])
		canvas.draw_polygon(fin_points, [hull_color.darkened(0.1)])

func _draw_ship_flying(pos: Vector2, scale: float) -> void:
	_draw_full_ship(pos, scale)

func _draw_rocket_exhaust(pos: Vector2, scale: float, intensity: float) -> void:
	if intensity <= 0:
		return

	var nozzle_y = pos.y + 100 * scale

	# Outer flame
	var flame_length = (80 + sin(total_timer * 30) * 20) * intensity * scale
	var outer_points = PackedVector2Array([
		Vector2(pos.x - 25 * scale, nozzle_y),
		Vector2(pos.x, nozzle_y + flame_length),
		Vector2(pos.x + 25 * scale, nozzle_y)
	])
	canvas.draw_polygon(outer_points, [Color(1, 0.4, 0.1, 0.9 * intensity)])

	# Middle flame
	var mid_length = flame_length * 0.75
	var mid_points = PackedVector2Array([
		Vector2(pos.x - 18 * scale, nozzle_y),
		Vector2(pos.x, nozzle_y + mid_length),
		Vector2(pos.x + 18 * scale, nozzle_y)
	])
	canvas.draw_polygon(mid_points, [Color(1, 0.7, 0.2, intensity)])

	# Inner flame (hottest)
	var inner_length = flame_length * 0.5
	var inner_points = PackedVector2Array([
		Vector2(pos.x - 10 * scale, nozzle_y),
		Vector2(pos.x, nozzle_y + inner_length),
		Vector2(pos.x + 10 * scale, nozzle_y)
	])
	canvas.draw_polygon(inner_points, [Color(1, 0.95, 0.8, intensity)])

	# Shock diamonds (during max-q)
	if current_stage == Stage.MAX_Q:
		for i in range(3):
			var diamond_y = nozzle_y + 20 + i * 25
			var diamond_size = (8 - i * 2) * scale
			canvas.draw_circle(Vector2(pos.x, diamond_y), diamond_size, Color(1, 0.9, 0.7, 0.8 - i * 0.2))

func _draw_smoke_trail(start: Vector2, end: Vector2) -> void:
	var segments = 10
	for i in range(segments):
		var t = float(i) / segments
		var pos = start.lerp(end, t)
		var alpha = 0.3 * (1.0 - t)
		var radius = 15 + t * 30
		pos.x += sin(t * 10 + total_timer) * 20
		canvas.draw_circle(pos, radius, Color(0.7, 0.7, 0.7, alpha))

func _draw_ship_tiny(pos: Vector2, progress: float) -> void:
	var hull_color = _get_ship_color()

	# Ship dot
	canvas.draw_circle(pos, 5, hull_color)

	# Direction indicator
	var dir = Vector2(1, 0).rotated(-progress * PI * 0.3)
	canvas.draw_line(pos, pos + dir * 12, hull_color, 2)

	# Trail
	for i in range(5):
		var trail_pos = pos - dir * (i + 1) * 8
		var alpha = 0.5 - i * 0.1
		canvas.draw_circle(trail_pos, 2, Color(hull_color.r, hull_color.g, hull_color.b, alpha))

func _draw_orbit_circle(center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_arc(center, radius, 0, TAU, 64, color, 1.5)

func _draw_transfer_arc(center: Vector2, from: Vector2, to: Vector2, progress: float) -> void:
	var color = Color(0.9, 0.8, 0.2, 0.6)
	var steps = 30
	var prev = from

	var control = center + (from - center).rotated(PI * 0.4) * 0.6

	for i in range(1, int(steps * progress) + 1):
		var t = float(i) / steps
		var p1 = from.lerp(control, t)
		var p2 = control.lerp(to, t)
		var point = p1.lerp(p2, t)

		if i % 2 == 0:  # Dashed
			canvas.draw_line(prev, point, color, 2)
		prev = point

func _draw_particles() -> void:
	# Draw sparks
	for spark in sparks:
		var alpha = spark.life / spark.max_life
		var color = Color(spark.color.r, spark.color.g, spark.color.b, alpha)
		canvas.draw_circle(spark.pos, 3 * alpha, color)

	# Draw confetti
	for c in confetti:
		canvas.draw_set_transform(c.pos, c.rotation, Vector2.ONE)
		var alpha = min(1.0, c.life)
		var color = Color(c.color.r, c.color.g, c.color.b, alpha)
		canvas.draw_rect(Rect2(-c.size.x/2, -c.size.y/2, c.size.x, c.size.y), color)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Draw smoke
	for smoke in smoke_puffs:
		var alpha = (smoke.life / smoke.max_life) * 0.4
		canvas.draw_circle(smoke.pos, smoke.radius, Color(0.7, 0.7, 0.7, alpha))

# ============================================================================
# HELPERS
# ============================================================================

func _get_ship_color() -> Color:
	var ship_class = mission_state.get("ship_class")
	match ship_class:
		MOTTypes.ShipClass.CAPSULE:
			return Color(0.55, 0.55, 0.6)
		MOTTypes.ShipClass.STANDARD:
			return Color(0.75, 0.75, 0.8)
		MOTTypes.ShipClass.CRUISER:
			return Color(0.9, 0.9, 0.95)
		_:
			return Color(0.7, 0.7, 0.75)

func _get_engine_color() -> Color:
	var engine = mission_state.get("engine")
	match engine:
		MOTTypes.EngineType.CHEMICAL:
			return Color(0.5, 0.45, 0.4)
		MOTTypes.EngineType.ION_DRIVE:
			return Color(0.3, 0.5, 0.85)
		MOTTypes.EngineType.NUCLEAR_THERMAL:
			return Color(0.2, 0.7, 0.3)
		MOTTypes.EngineType.SOLAR_SAIL:
			return Color(0.85, 0.75, 0.3)
		_:
			return Color(0.5, 0.5, 0.5)

func _on_skip_pressed() -> void:
	skip_requested = true
