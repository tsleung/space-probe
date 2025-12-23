extends Node
class_name Phase2SoundManager

## Sound manager for MOT Phase 2
## Handles ambient sounds, alerts, and audio feedback
## Uses procedural audio generation for space sounds

# ============================================================================
# AUDIO PLAYERS
# ============================================================================

var ambient_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var alert_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer

# ============================================================================
# STATE
# ============================================================================

var engine_running: bool = true
var engine_volume: float = -20.0
var ambient_volume: float = -25.0
var alert_volume: float = -10.0

# Alert queue
var alert_queue: Array = []
var alert_cooldown: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_players()
	_start_ambient()

func _setup_players() -> void:
	# Ambient (low hum)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_player.volume_db = ambient_volume
	add_child(ambient_player)

	# Engine
	engine_player = AudioStreamPlayer.new()
	engine_player.bus = "Master"
	engine_player.volume_db = engine_volume
	add_child(engine_player)

	# Alert
	alert_player = AudioStreamPlayer.new()
	alert_player.bus = "Master"
	alert_player.volume_db = alert_volume
	add_child(alert_player)

	# UI sounds
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "Master"
	ui_player.volume_db = -15.0
	add_child(ui_player)

	# Footsteps
	footstep_player = AudioStreamPlayer.new()
	footstep_player.bus = "Master"
	footstep_player.volume_db = -20.0
	add_child(footstep_player)

func _start_ambient() -> void:
	# Create procedural ambient sound (low frequency hum)
	var ambient_stream = _create_ambient_stream()
	if ambient_stream:
		ambient_player.stream = ambient_stream
		ambient_player.play()

	# Create engine sound
	var engine_stream = _create_engine_stream()
	if engine_stream:
		engine_player.stream = engine_stream
		engine_player.play()

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if alert_cooldown > 0:
		alert_cooldown -= delta

	_process_alert_queue()

func _process_alert_queue() -> void:
	if alert_queue.is_empty():
		return

	if alert_cooldown <= 0 and not alert_player.playing:
		var alert_type = alert_queue.pop_front()
		_play_alert(alert_type)
		alert_cooldown = 1.0  # Minimum time between alerts

# ============================================================================
# PUBLIC API
# ============================================================================

func play_event_alert(event_type: int) -> void:
	## Queue an alert sound for an event
	alert_queue.append(event_type)

func play_button_click() -> void:
	## UI button click
	ui_player.stream = _create_click_stream()
	ui_player.play()

func play_event_resolved() -> void:
	## Positive resolution sound
	ui_player.stream = _create_resolve_stream()
	ui_player.play()

func play_footstep() -> void:
	## Crew footstep sound
	footstep_player.stream = _create_footstep_stream()
	footstep_player.play()

func play_damage() -> void:
	## Damage/impact sound
	alert_player.stream = _create_damage_stream()
	alert_player.play()

func play_alarm() -> void:
	## Critical alarm
	alert_player.stream = _create_alarm_stream()
	alert_player.play()

func play_arrival() -> void:
	## Mars arrival fanfare
	alert_player.stream = _create_arrival_stream()
	alert_player.volume_db = -5.0  # Louder for arrival
	alert_player.play()

func play_engine_burn() -> void:
	## Correction burn - powerful engine roar
	alert_player.stream = _create_burn_stream()
	alert_player.volume_db = -8.0
	alert_player.play()

func set_engine_intensity(intensity: float) -> void:
	## Adjust engine sound based on speed (0.0 = off, 1.0 = full)
	engine_volume = lerp(-30.0, -15.0, intensity)
	engine_player.volume_db = engine_volume

func set_paused(paused: bool) -> void:
	## Mute/unmute sounds when game is paused
	if paused:
		engine_player.volume_db = -40.0
		ambient_player.volume_db = -35.0
	else:
		engine_player.volume_db = engine_volume
		ambient_player.volume_db = ambient_volume

# ============================================================================
# SOUND GENERATION
# ============================================================================

func _play_alert(event_type: int) -> void:
	const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")

	match event_type:
		Phase2Types.EventType.SOLAR_FLARE:
			alert_player.stream = _create_warning_stream()
		Phase2Types.EventType.COMPONENT_MALFUNCTION:
			alert_player.stream = _create_malfunction_stream()
		Phase2Types.EventType.MESSAGE_FROM_EARTH:
			alert_player.stream = _create_message_stream()
		Phase2Types.EventType.MICROMETEORITE:
			alert_player.stream = _create_impact_stream()
		Phase2Types.EventType.CARGO_LOOSE:
			alert_player.stream = _create_cargo_stream()
		_:
			alert_player.stream = _create_generic_alert_stream()

	alert_player.play()

func _create_ambient_stream() -> AudioStream:
	## Create low-frequency ambient hum
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.5
	return generator

func _create_engine_stream() -> AudioStream:
	## Create engine rumble sound
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.25
	return generator

func _create_click_stream() -> AudioStream:
	## Simple click sound
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.05

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = 1.0 - (t / duration)
		var sample = sin(t * 800 * TAU) * envelope * 0.3
		sample += sin(t * 1200 * TAU) * envelope * 0.2
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_resolve_stream() -> AudioStream:
	## Positive resolution chime
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.3

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = (1.0 - (t / duration)) * min(t * 20.0, 1.0)
		var sample = sin(t * 440 * TAU) * envelope * 0.2
		sample += sin(t * 554 * TAU) * envelope * 0.15  # C-E-G
		sample += sin(t * 660 * TAU) * envelope * 0.15
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_footstep_stream() -> AudioStream:
	## Metallic footstep
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.1

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 30.0)
		var noise = randf_range(-1, 1)
		var sample = noise * envelope * 0.2
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_damage_stream() -> AudioStream:
	## Impact/damage sound
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.4

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 8.0)
		var noise = randf_range(-1, 1)
		var low = sin(t * 80 * TAU)
		var sample = (noise * 0.3 + low * 0.7) * envelope * 0.4
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_alarm_stream() -> AudioStream:
	## Klaxon alarm
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.8

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = 0.7 + sin(t * 10.0 * TAU) * 0.3
		var freq = 440.0 + sin(t * 5.0 * TAU) * 100.0
		var sample = sin(t * freq * TAU) * envelope * 0.3
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_warning_stream() -> AudioStream:
	## Warning beep for solar flare etc
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.5

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var beep_on = fmod(t, 0.25) < 0.15
		var envelope = 1.0 if beep_on else 0.0
		var sample = sin(t * 880 * TAU) * envelope * 0.25
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_malfunction_stream() -> AudioStream:
	## Electrical malfunction sound
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.4

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 5.0)
		var noise = randf_range(-1, 1)
		var buzz = sin(t * 60 * TAU)
		var sample = (noise * 0.4 + buzz * 0.6) * envelope * 0.25
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_message_stream() -> AudioStream:
	## Radio message chime
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.4

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 4.0)
		var sample = sin(t * 600 * TAU) * envelope * 0.15
		sample += sin(t * 800 * TAU) * envelope * 0.15
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_impact_stream() -> AudioStream:
	## Micrometeorite impact
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.2

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 20.0)
		var noise = randf_range(-1, 1)
		var ping = sin(t * 2000 * TAU) * exp(-t * 50.0)
		var sample = (noise * 0.5 + ping * 0.5) * envelope * 0.3
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_cargo_stream() -> AudioStream:
	## Cargo loose alert
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.3

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 6.0)
		var clunk = sin(t * 200 * TAU)
		var sample = clunk * envelope * 0.25
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_generic_alert_stream() -> AudioStream:
	## Generic alert beep
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 0.3

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 5.0)
		var sample = sin(t * 660 * TAU) * envelope * 0.2
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _create_arrival_stream() -> AudioStream:
	## Mars arrival fanfare - triumphant!
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 2.0

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var envelope = min(t * 2.0, 1.0) * (1.0 - max(0, (t - 1.5) / 0.5))

		# Build a chord progression
		var sample = 0.0
		if t < 0.5:
			# C major
			sample = sin(t * 261 * TAU) * 0.2
			sample += sin(t * 329 * TAU) * 0.15
			sample += sin(t * 392 * TAU) * 0.15
		elif t < 1.0:
			# G major
			sample = sin(t * 392 * TAU) * 0.2
			sample += sin(t * 493 * TAU) * 0.15
			sample += sin(t * 587 * TAU) * 0.15
		else:
			# C major (higher)
			sample = sin(t * 523 * TAU) * 0.25
			sample += sin(t * 659 * TAU) * 0.15
			sample += sin(t * 784 * TAU) * 0.15

		samples.append(Vector2(sample * envelope, sample * envelope))

	return _samples_to_stream(samples, int(sample_rate))

func _create_burn_stream() -> AudioStream:
	## Powerful engine burn - deep rumble that builds and fades
	var samples = PackedVector2Array()
	var sample_rate = 22050.0
	var duration = 2.5

	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate

		# Envelope: quick ramp up, sustain, gradual fade
		var envelope = 0.0
		if t < 0.2:
			envelope = t / 0.2  # Ramp up
		elif t < 2.0:
			envelope = 1.0  # Sustain
		else:
			envelope = (duration - t) / 0.5  # Fade out

		# Deep rumble with harmonics
		var base_freq = 60.0 + sin(t * 3.0) * 10.0  # Slight frequency wobble
		var rumble = sin(t * base_freq * TAU) * 0.4
		rumble += sin(t * base_freq * 2.0 * TAU) * 0.2  # First harmonic
		rumble += sin(t * base_freq * 3.0 * TAU) * 0.1  # Second harmonic

		# Add some noise for texture
		var noise = randf_range(-1, 1) * 0.15

		# Higher frequency roar that builds
		var intensity = min(t * 2.0, 1.0)
		var roar = sin(t * 120 * TAU) * intensity * 0.2
		roar += sin(t * 180 * TAU) * intensity * 0.1

		var sample = (rumble + noise + roar) * envelope * 0.5
		samples.append(Vector2(sample, sample))

	return _samples_to_stream(samples, int(sample_rate))

func _samples_to_stream(samples: PackedVector2Array, sample_rate: int) -> AudioStreamWAV:
	## Convert sample array to playable stream
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = sample_rate

	var data = PackedByteArray()
	for sample in samples:
		var left = int(clamp(sample.x, -1.0, 1.0) * 32767)
		var right = int(clamp(sample.y, -1.0, 1.0) * 32767)
		data.append(left & 0xFF)
		data.append((left >> 8) & 0xFF)
		data.append(right & 0xFF)
		data.append((right >> 8) & 0xFF)

	wav.data = data
	return wav
