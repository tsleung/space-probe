extends Node

## AudioManager - Procedural retro sci-fi sounds
## Generates simple tones and beeps for game events

# ============================================================================
# AUDIO PLAYERS
# ============================================================================

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

# Tone generation
var _sample_hz: float = 44100.0
var _pulse_hz: float = 440.0

# Volume settings (in dB)
var sfx_volume: float = -6.0
var music_volume: float = -12.0
var ambient_volume: float = -18.0
var master_enabled: bool = true

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = ambient_volume
	add_child(_ambient_player)

# ============================================================================
# SOUND EFFECTS - Procedural tones
# ============================================================================

## Play a simple beep
func play_beep(frequency: float = 440.0, duration: float = 0.1, volume_db: float = -6.0):
	if not master_enabled:
		return
	var stream = _generate_tone(frequency, duration)
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db + sfx_volume
	_sfx_player.play()

## Play UI click sound
func play_click():
	play_beep(800.0, 0.05, -8.0)

## Play UI hover sound
func play_hover():
	play_beep(600.0, 0.03, -12.0)

## Play success sound (ascending tones)
func play_success():
	if not master_enabled:
		return
	var stream = _generate_arpeggio([523.25, 659.25, 783.99], 0.1)  # C5, E5, G5
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume
	_sfx_player.play()

## Play error/warning sound (descending tones)
func play_error():
	if not master_enabled:
		return
	var stream = _generate_arpeggio([349.23, 293.66, 246.94], 0.12)  # F4, D4, B3
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume - 3.0
	_sfx_player.play()

## Play alert/event notification
func play_alert():
	if not master_enabled:
		return
	var stream = _generate_two_tone(880.0, 440.0, 0.15)
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume
	_sfx_player.play()

## Play day advance sound
func play_day_advance():
	play_beep(523.25, 0.08, -10.0)  # C5, soft

## Play launch countdown beep
func play_countdown_beep():
	play_beep(1000.0, 0.1, -3.0)

## Play launch sound (dramatic ascending sweep)
func play_launch():
	if not master_enabled:
		return
	var stream = _generate_sweep(200.0, 800.0, 2.0)
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume + 3.0
	_sfx_player.play()

## Play death/crew loss sound
func play_death():
	if not master_enabled:
		return
	var stream = _generate_tone(130.81, 0.8)  # C3, long low tone
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume
	_sfx_player.play()

## Play component damage sound
func play_damage():
	if not master_enabled:
		return
	# Harsh noise-like sound using low frequency with harmonics
	var stream = _generate_noise_burst(0.15)
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume - 6.0
	_sfx_player.play()

## Play reentry rumble
func play_reentry():
	if not master_enabled:
		return
	var stream = _generate_noise_burst(3.0)
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume - 10.0
	_sfx_player.play()

## Play victory fanfare
func play_victory():
	if not master_enabled:
		return
	# Major chord arpeggio
	var stream = _generate_arpeggio([261.63, 329.63, 392.0, 523.25], 0.2)  # C4, E4, G4, C5
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume
	_sfx_player.play()

# ============================================================================
# AMBIENT SOUNDS
# ============================================================================

## Start ship ambient hum
func start_ship_ambient():
	if not master_enabled:
		return
	# Low frequency hum for space atmosphere
	var stream = _generate_ambient_hum(60.0, 10.0)
	_ambient_player.stream = stream
	_ambient_player.volume_db = ambient_volume
	_ambient_player.play()

## Stop ambient
func stop_ambient():
	_ambient_player.stop()

# ============================================================================
# TONE GENERATION (Pure procedural audio)
# ============================================================================

## Generate a simple sine wave tone
func _generate_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var samples = PackedByteArray()
	var num_samples = int(_sample_hz * duration)

	for i in range(num_samples):
		var t = float(i) / _sample_hz
		# Apply fade in/out envelope
		var envelope = 1.0
		var attack = 0.01
		var release = 0.02
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = (duration - t) / release

		var sample = sin(TAU * frequency * t) * envelope
		# Convert to 16-bit PCM
		var sample_int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		samples.append(sample_int & 0xFF)
		samples.append((sample_int >> 8) & 0xFF)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_sample_hz)
	stream.stereo = false
	stream.data = samples
	return stream

## Generate arpeggio (sequence of tones)
func _generate_arpeggio(frequencies: Array, note_duration: float) -> AudioStreamWAV:
	var samples = PackedByteArray()

	for freq in frequencies:
		var num_samples = int(_sample_hz * note_duration)
		for i in range(num_samples):
			var t = float(i) / _sample_hz
			var envelope = 1.0
			var attack = 0.01
			var release = note_duration * 0.3
			if t < attack:
				envelope = t / attack
			elif t > note_duration - release:
				envelope = (note_duration - t) / release

			var sample = sin(TAU * freq * t) * envelope * 0.7
			var sample_int = int(clampf(sample, -1.0, 1.0) * 32767.0)
			samples.append(sample_int & 0xFF)
			samples.append((sample_int >> 8) & 0xFF)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_sample_hz)
	stream.stereo = false
	stream.data = samples
	return stream

## Generate two-tone alert
func _generate_two_tone(freq1: float, freq2: float, note_duration: float) -> AudioStreamWAV:
	return _generate_arpeggio([freq1, freq2, freq1], note_duration)

## Generate frequency sweep
func _generate_sweep(start_freq: float, end_freq: float, duration: float) -> AudioStreamWAV:
	var samples = PackedByteArray()
	var num_samples = int(_sample_hz * duration)

	for i in range(num_samples):
		var t = float(i) / _sample_hz
		var progress = t / duration
		var freq = start_freq + (end_freq - start_freq) * progress

		# Envelope
		var envelope = 1.0
		if progress < 0.1:
			envelope = progress / 0.1
		elif progress > 0.9:
			envelope = (1.0 - progress) / 0.1

		var sample = sin(TAU * freq * t) * envelope * 0.6
		var sample_int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		samples.append(sample_int & 0xFF)
		samples.append((sample_int >> 8) & 0xFF)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_sample_hz)
	stream.stereo = false
	stream.data = samples
	return stream

## Generate noise burst (for damage/rumble)
func _generate_noise_burst(duration: float) -> AudioStreamWAV:
	var samples = PackedByteArray()
	var num_samples = int(_sample_hz * duration)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system())

	for i in range(num_samples):
		var t = float(i) / _sample_hz
		var progress = t / duration

		# Envelope
		var envelope = 1.0
		if progress < 0.05:
			envelope = progress / 0.05
		elif progress > 0.7:
			envelope = (1.0 - progress) / 0.3

		# Mix noise with low frequency rumble
		var noise = (rng.randf() * 2.0 - 1.0) * 0.3
		var rumble = sin(TAU * 60.0 * t) * 0.4
		var sample = (noise + rumble) * envelope

		var sample_int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		samples.append(sample_int & 0xFF)
		samples.append((sample_int >> 8) & 0xFF)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_sample_hz)
	stream.stereo = false
	stream.data = samples
	return stream

## Generate ambient hum (looping)
func _generate_ambient_hum(frequency: float, duration: float) -> AudioStreamWAV:
	var samples = PackedByteArray()
	var num_samples = int(_sample_hz * duration)

	for i in range(num_samples):
		var t = float(i) / _sample_hz
		# Mix fundamental with harmonics for richer hum
		var sample = sin(TAU * frequency * t) * 0.5
		sample += sin(TAU * frequency * 2.0 * t) * 0.2
		sample += sin(TAU * frequency * 3.0 * t) * 0.1
		sample *= 0.3  # Quiet

		var sample_int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		samples.append(sample_int & 0xFF)
		samples.append((sample_int >> 8) & 0xFF)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_sample_hz)
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = samples
	return stream

# ============================================================================
# VOLUME CONTROLS
# ============================================================================

func set_master_enabled(enabled: bool):
	master_enabled = enabled
	if not enabled:
		_sfx_player.stop()
		_music_player.stop()
		_ambient_player.stop()

func set_sfx_volume(volume_db: float):
	sfx_volume = volume_db

func set_music_volume(volume_db: float):
	music_volume = volume_db
	_music_player.volume_db = volume_db

func set_ambient_volume(volume_db: float):
	ambient_volume = volume_db
	_ambient_player.volume_db = volume_db
