extends Node

# Melodic sound manager for VNP
# Inspired by Journey/Nier - pentatonic scales, musical flourishes

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

var master_volume: float = 0.35

# Pentatonic scale frequencies (C minor pentatonic, multiple octaves)
const PENTA = [130.81, 155.56, 174.61, 196.0, 233.08,  # C3-Bb3
			   261.63, 311.13, 349.23, 392.0, 466.16,  # C4-Bb4
			   523.25, 622.25, 698.46, 783.99, 932.33] # C5-Bb5

# Sound pools
var weapon_players: Array[AudioStreamPlayer] = []
var explosion_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []

const POOL_SIZE = 8

# Cached sounds
var _cached_laser: AudioStreamWAV = null
var _cached_railgun: AudioStreamWAV = null
var _cached_missile: AudioStreamWAV = null
var _cached_pdc: AudioStreamWAV = null
var _cached_turbolaser: AudioStreamWAV = null
var _cached_gravity: AudioStreamWAV = null
var _cached_explosion_small: AudioStreamWAV = null
var _cached_explosion_big: AudioStreamWAV = null
var _cached_click: AudioStreamWAV = null
var _cached_capture: AudioStreamWAV = null

func _ready():
	_create_sound_pools()
	_precache_sounds()


func _create_sound_pools():
	for i in range(POOL_SIZE):
		weapon_players.append(_create_player())
		explosion_players.append(_create_player())
	for i in range(3):
		ui_players.append(_create_player())


func _precache_sounds():
	_cached_laser = _generate_laser()
	_cached_railgun = _generate_railgun()
	_cached_missile = _generate_missile()
	_cached_pdc = _generate_pdc()
	_cached_turbolaser = _generate_turbolaser()
	_cached_gravity = _generate_gravity()
	_cached_explosion_small = _generate_explosion(false)
	_cached_explosion_big = _generate_explosion(true)
	_cached_click = _generate_click()
	_cached_capture = _generate_capture()


func _create_player() -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.volume_db = linear_to_db(master_volume)
	add_child(player)
	return player


func _get_available_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in pool:
		if not player.playing:
			return player
	return pool[0]


# === PLAY FUNCTIONS ===

func play_laser():
	var player = _get_available_player(weapon_players)
	player.stream = _cached_laser
	player.volume_db = linear_to_db(master_volume * 0.4)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func play_railgun():
	var player = _get_available_player(weapon_players)
	player.stream = _cached_railgun
	player.volume_db = linear_to_db(master_volume * 0.45)
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()


func play_missile_launch():
	var player = _get_available_player(weapon_players)
	player.stream = _cached_missile
	player.volume_db = linear_to_db(master_volume * 0.35)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func play_pdc():
	var player = _get_available_player(weapon_players)
	player.stream = _cached_pdc
	player.volume_db = linear_to_db(master_volume * 0.25)
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()


func play_turbolaser():
	var player = _get_available_player(weapon_players)
	player.stream = _cached_turbolaser
	player.volume_db = linear_to_db(master_volume * 0.5)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func play_gravity():
	var player = _get_available_player(weapon_players)
	player.stream = _cached_gravity
	player.volume_db = linear_to_db(master_volume * 0.35)
	player.play()


func play_explosion(size: int):
	var player = _get_available_player(explosion_players)
	if size >= VnpTypes.ShipSize.LARGE:
		player.stream = _cached_explosion_big
		player.volume_db = linear_to_db(master_volume * 0.5)
	else:
		player.stream = _cached_explosion_small
		player.volume_db = linear_to_db(master_volume * 0.4)
	player.pitch_scale = randf_range(0.85, 1.15)
	player.play()


func play_capture():
	var player = _get_available_player(ui_players)
	player.stream = _cached_capture
	player.volume_db = linear_to_db(master_volume * 0.4)
	player.play()


func play_ui_click():
	var player = _get_available_player(ui_players)
	player.stream = _cached_click
	player.volume_db = linear_to_db(master_volume * 0.3)
	player.play()


# === MELODIC SOUND GENERATION ===

func _generate_laser() -> AudioStreamWAV:
	# Quiet hum - smooth sustained tone
	var sample_rate = 22050
	var duration = 0.2
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var freq = PENTA[5]  # Mid tone

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		# Gentle envelope - fade in and out
		var envelope = sin(progress * PI) * 0.2  # Quiet

		# Smooth hum with subtle vibrato
		var vibrato = sin(t * 6) * 3
		var sample = sin(t * (freq + vibrato) * TAU) * envelope

		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_railgun() -> AudioStreamWAV:
	# Deep percussive with melodic tail - like a muted bell
	var sample_rate = 22050
	var duration = 0.12
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var fundamental = PENTA[0]  # Low C

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		# Sharp attack, melodic decay
		var envelope = exp(-progress * 10) * 0.5

		# Bell-like harmonics
		var sample = sin(t * fundamental * TAU) * 1.0
		sample += sin(t * fundamental * 2 * TAU) * 0.5 * exp(-progress * 15)
		sample += sin(t * fundamental * 3 * TAU) * 0.25 * exp(-progress * 20)

		sample *= envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_missile() -> AudioStreamWAV:
	# Rising tone - hopeful ascending note
	var sample_rate = 22050
	var duration = 0.18
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var start_note = PENTA[3]
	var end_note = PENTA[6]

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = sin(progress * PI) * 0.3

		# Glide from low to high
		var freq = lerp(start_note, end_note, progress)
		var sample = sin(t * freq * TAU) * envelope

		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_pdc() -> AudioStreamWAV:
	# Quick staccato note - like a pizzicato
	var sample_rate = 22050
	var duration = 0.05
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var note = PENTA[7]  # Mid-high

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = exp(-progress * 25) * 0.3
		var sample = sin(t * note * TAU) * envelope

		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_turbolaser() -> AudioStreamWAV:
	# Deep chord - power chord feeling
	var sample_rate = 22050
	var duration = 0.3
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	# Power chord: root + fifth
	var root = PENTA[0]
	var fifth = PENTA[2]

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = exp(-progress * 3) * 0.4

		var sample = sin(t * root * TAU) * 0.6
		sample += sin(t * fifth * TAU) * 0.4
		sample += sin(t * root * 0.5 * TAU) * 0.3  # Sub-octave

		sample *= envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_gravity() -> AudioStreamWAV:
	# Ethereal descending - like wind chimes fading
	var sample_rate = 22050
	var duration = 0.35
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	# Multiple notes fading at different rates
	var notes = [PENTA[10], PENTA[8], PENTA[5]]

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = sin(progress * PI) * 0.3

		var sample = 0.0
		for j in range(notes.size()):
			var note_env = exp(-progress * (3 + j * 2))
			sample += sin(t * notes[j] * TAU) * note_env * 0.4

		sample *= envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_explosion(big: bool) -> AudioStreamWAV:
	# Rumble with melodic undertone
	var sample_rate = 22050
	var duration = 0.25 if not big else 0.4
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var bass_note = PENTA[0] * 0.5  # Sub-bass

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = exp(-progress * (5 if not big else 3)) * 0.45

		# Noise component (impact)
		var noise = (randf() - 0.5) * (1.0 - progress) * 0.5
		# Melodic bass component
		var tone = sin(t * bass_note * TAU) * 0.8

		var sample = (noise + tone) * envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_click() -> AudioStreamWAV:
	# Gentle chime
	var sample_rate = 22050
	var duration = 0.06
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var note = PENTA[9]

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = exp(-progress * 20) * 0.3
		var sample = sin(t * note * TAU) * envelope
		sample += sin(t * note * 2 * TAU) * envelope * 0.3

		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_capture() -> AudioStreamWAV:
	# Ascending flourish - triumphant arpeggio
	var sample_rate = 22050
	var duration = 0.3
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var notes = [PENTA[5], PENTA[7], PENTA[9], PENTA[10]]

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var envelope = sin(progress * PI) * 0.35

		# Quick arpeggio up
		var note_idx = int(progress * 3.99)
		var freq = notes[min(note_idx, 3)]

		var sample = sin(t * freq * TAU) * envelope
		sample += sin(t * freq * 2 * TAU) * envelope * 0.2

		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _create_wav(samples: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.data = samples
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav
