extends Node

# Simple procedural sound manager for VNP
# Generates synthesized sounds for weapons, explosions, and events

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

# Audio bus for game sounds
var master_volume: float = 0.7

# Sound pools for polyphony (multiple simultaneous sounds)
var laser_players: Array[AudioStreamPlayer] = []
var gun_players: Array[AudioStreamPlayer] = []
var missile_players: Array[AudioStreamPlayer] = []
var explosion_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []

const POOL_SIZE = 8  # Max simultaneous sounds per type

# Cached sounds - generated once and reused to prevent memory leaks
var _cached_laser: AudioStreamWAV = null
var _cached_railgun: AudioStreamWAV = null
var _cached_missile: AudioStreamWAV = null
var _cached_pdc: AudioStreamWAV = null
var _cached_turbolaser: AudioStreamWAV = null
var _cached_explosions: Dictionary = {}  # size -> AudioStreamWAV
var _cached_capture: AudioStreamWAV = null
var _cached_click: AudioStreamWAV = null

func _ready():
	_create_sound_pools()
	_precache_sounds()


func _create_sound_pools():
	# Create pools of audio players for each sound type
	for i in range(POOL_SIZE):
		laser_players.append(_create_player())
		gun_players.append(_create_player())
		missile_players.append(_create_player())
		explosion_players.append(_create_player())

	for i in range(4):
		ui_players.append(_create_player())


func _precache_sounds():
	# Generate all sounds once at startup to prevent memory leaks
	_cached_laser = _generate_laser_sound()
	_cached_railgun = _generate_railgun_sound()
	_cached_missile = _generate_missile_sound()
	_cached_pdc = _generate_pdc_sound()
	_cached_turbolaser = _generate_turbolaser_sound()
	_cached_capture = _generate_capture_sound()
	_cached_click = _generate_click_sound()

	# Pre-cache explosion sounds for each size
	for size in [VnpTypes.ShipSize.SMALL, VnpTypes.ShipSize.MEDIUM, VnpTypes.ShipSize.LARGE, VnpTypes.ShipSize.MASSIVE]:
		_cached_explosions[size] = _generate_explosion_sound(size)


func _create_player() -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.volume_db = linear_to_db(master_volume)
	add_child(player)
	return player


func _get_available_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in pool:
		if not player.playing:
			return player
	# All playing - return first (will interrupt)
	return pool[0]


# === WEAPON SOUNDS ===

func play_laser():
	var player = _get_available_player(laser_players)
	player.stream = _cached_laser
	player.volume_db = linear_to_db(master_volume * 0.5)
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()


func play_railgun():
	var player = _get_available_player(gun_players)
	player.stream = _cached_railgun
	player.volume_db = linear_to_db(master_volume * 0.6)
	player.pitch_scale = randf_range(0.85, 1.15)
	player.play()


func play_missile_launch():
	var player = _get_available_player(missile_players)
	player.stream = _cached_missile
	player.volume_db = linear_to_db(master_volume * 0.4)
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()


func play_pdc():
	var player = _get_available_player(gun_players)
	player.stream = _cached_pdc
	player.volume_db = linear_to_db(master_volume * 0.3)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func play_turbolaser():
	var player = _get_available_player(laser_players)
	player.stream = _cached_turbolaser
	player.volume_db = linear_to_db(master_volume * 0.7)
	player.pitch_scale = randf_range(0.9, 1.0)
	player.play()


# === EXPLOSION SOUNDS ===

func play_explosion(size: int):
	var player = _get_available_player(explosion_players)
	player.stream = _cached_explosions.get(size, _cached_explosions.get(VnpTypes.ShipSize.SMALL))
	player.volume_db = linear_to_db(master_volume * 0.8)
	player.pitch_scale = randf_range(0.8, 1.2)
	player.play()


# === UI SOUNDS ===

func play_capture():
	var player = _get_available_player(ui_players)
	player.stream = _cached_capture
	player.volume_db = linear_to_db(master_volume * 0.6)
	player.play()


func play_ui_click():
	var player = _get_available_player(ui_players)
	player.stream = _cached_click
	player.volume_db = linear_to_db(master_volume * 0.4)
	player.play()


# === SOUND GENERATION ===
# Using AudioStreamWAV with procedurally generated samples

func _generate_laser_sound() -> AudioStreamWAV:
	# Smooth bubbly laser - soft sine sweep
	var sample_rate = 22050
	var duration = 0.12
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = 800 + sin(t * 40) * 300  # Wobbling frequency for bubbly feel
		# Smooth envelope with soft attack
		var attack = min(t * 20, 1.0)
		var decay = pow(1.0 - (t / duration), 0.7)
		var envelope = attack * decay * 0.6
		var sample = sin(t * freq * TAU) * envelope
		# Soft harmonic
		sample += sin(t * freq * 1.5 * TAU) * envelope * 0.2
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_railgun_sound() -> AudioStreamWAV:
	# Soft pop/thud instead of harsh crack
	var sample_rate = 22050
	var duration = 0.08
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		# Soft attack, smooth decay
		var attack = min(t * 30, 1.0)
		var decay = pow(1.0 - (t / duration), 0.5)
		var envelope = attack * decay * 0.5
		# Low tone instead of noise
		var tone = sin(t * 180 * TAU) + sin(t * 90 * TAU) * 0.5
		var sample = tone * envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_missile_sound() -> AudioStreamWAV:
	# Soft whoosh - smooth rising tone
	var sample_rate = 22050
	var duration = 0.15
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = 100 + t * 400  # Rising frequency
		# Very smooth envelope
		var envelope = sin(t / duration * PI) * 0.4
		var sample = sin(t * freq * TAU) * envelope
		sample += sin(t * freq * 0.5 * TAU) * envelope * 0.3
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_pdc_sound() -> AudioStreamWAV:
	# Soft tick instead of harsh pop
	var sample_rate = 22050
	var duration = 0.04
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var attack = min(t * 50, 1.0)
		var decay = pow(1.0 - (t / duration), 0.8)
		var envelope = attack * decay * 0.3
		var sample = sin(t * 600 * TAU) * envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_turbolaser_sound() -> AudioStreamWAV:
	# Deep smooth pulse
	var sample_rate = 22050
	var duration = 0.25
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = 200 + sin(t * 25) * 50  # Slight wobble
		# Smooth envelope
		var attack = min(t * 15, 1.0)
		var decay = pow(1.0 - (t / duration), 0.6)
		var envelope = attack * decay * 0.5
		var sample = sin(t * freq * TAU) * envelope
		sample += sin(t * freq * 0.5 * TAU) * envelope * 0.4  # Sub
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_explosion_sound(size: int) -> AudioStreamWAV:
	# Softer boom - more tone, less noise
	var sample_rate = 22050
	var duration = 0.15 + size * 0.1
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	var base_freq = 120 - size * 20

	for i in range(num_samples):
		var t = float(i) / sample_rate
		# Soft attack
		var attack = min(t * 20, 1.0)
		var decay = pow(1.0 - (t / duration), 0.7)
		var envelope = attack * decay * 0.6

		# More tone, less noise for smoother sound
		var tone = sin(t * base_freq * TAU) + sin(t * base_freq * 0.5 * TAU) * 0.5
		var sample = tone * envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_capture_sound() -> AudioStreamWAV:
	# Ascending triumphant tone
	var sample_rate = 22050
	var duration = 0.3
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = 400 + t * 600  # Ascending
		var envelope = sin(t / duration * PI)  # Smooth in/out
		var sample = sin(t * freq * TAU) * envelope
		sample += sin(t * freq * 1.5 * TAU) * envelope * 0.3  # Fifth harmonic
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _generate_click_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.05
	var samples = PackedByteArray()
	var num_samples = int(sample_rate * duration)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 100)
		var sample = sin(t * 800 * TAU) * envelope
		samples.append(int(clamp(sample * 127, -128, 127)) + 128)

	return _create_wav(samples, sample_rate)


func _create_wav(samples: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.data = samples
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav
