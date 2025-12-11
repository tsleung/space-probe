extends Node

## VNP Store - State management for Von Neumann Probe mode
## Real-time simulation with continuous resource generation
## The ONLY place with side effects: RNG, signals, tick processing

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: Dictionary)
signal tick_processed(year: float)
signal probe_created(probe: Dictionary)
signal probe_destroyed(probe_id: String, probe_name: String)
signal probe_arrived(probe: Dictionary, system: Dictionary)
signal system_explored(system: Dictionary)
signal resources_changed(resources: Dictionary)
signal event_triggered(event: Dictionary)
signal threat_spawned(threat: Dictionary)
signal game_over(victory: bool, reason: String, score: int)

# ============================================================================
# TIMING CONSTANTS
# ============================================================================

const YEARS_PER_SECOND = 5.0  # Base game speed: 5 years pass per real second
const TICK_RATE = 0.1  # Process every 0.1 seconds (10 ticks/second)
const YEARS_PER_TICK = YEARS_PER_SECOND * TICK_RATE  # 0.5 years per tick

# Resource rates (per year)
const MINING_IRON_PER_YEAR = 20.0
const MINING_RARE_PER_YEAR = 4.0
const ENERGY_REGEN_PER_YEAR = 50.0
const REPLICATION_YEARS = 30.0  # 30 years to build a probe (was 3 turns = 30 years)
const TRAVEL_SPEED = 15.0  # Units per year

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tick_accumulator: float = 0.0
var _game_speed: float = 1.0  # Multiplier for game speed
var _paused: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	reset()

func _process(delta: float):
	if _paused or _state.is_game_over:
		return

	_tick_accumulator += delta * _game_speed
	while _tick_accumulator >= TICK_RATE:
		_tick_accumulator -= TICK_RATE
		_process_tick()

func reset():
	_state = VNPTypes.create_vnp_state()
	_tick_accumulator = 0.0
	_paused = false

func get_state() -> Dictionary:
	return _state.duplicate(true)

func set_game_speed(speed: float) -> void:
	_game_speed = clampf(speed, 0.1, 10.0)

func get_game_speed() -> float:
	return _game_speed

func set_paused(paused: bool) -> void:
	_paused = paused

func is_paused() -> bool:
	return _paused

# ============================================================================
# GETTERS
# ============================================================================

func get_turn() -> int:
	return _state.current_turn

func get_year() -> int:
	return _state.year

func get_resources() -> Dictionary:
	return _state.resources.duplicate()

func get_probes() -> Dictionary:
	return _state.probes.duplicate(true)

func get_probe(probe_id: String) -> Dictionary:
	return _state.probes.get(probe_id, {}).duplicate(true)

func get_systems() -> Dictionary:
	return _state.systems.duplicate(true)

func get_system(system_id: String) -> Dictionary:
	return _state.systems.get(system_id, {}).duplicate(true)

func get_explored_systems() -> Array:
	var explored = []
	for sys_id in _state.systems.keys():
		if _state.systems[sys_id].is_explored:
			explored.append(_state.systems[sys_id])
	return explored

func get_pending_event() -> Dictionary:
	return _state.pending_event.duplicate(true)

func get_event_log() -> Array:
	return _state.event_log.duplicate(true)

func is_game_over() -> bool:
	return _state.is_game_over

func get_active_probe_count() -> int:
	var count = 0
	for probe in _state.probes.values():
		if probe.health > 0:
			count += 1
	return count

# ============================================================================
# DISPATCH
# ============================================================================

func dispatch(action: Dictionary) -> void:
	var old_state = _state
	_state = VNPReducer.reduce(_state, action)
	_emit_change_signals(old_state, _state, action)
	state_changed.emit(_state)

# ============================================================================
# HIGH-LEVEL ACTIONS
# ============================================================================

## Start a new run with generated galaxy
func start_new_run() -> void:
	_rng.seed = int(Time.get_unix_time_from_system())
	_paused = false
	_tick_accumulator = 0.0

	var galaxy_data = VNPGalaxyLogic.generate_galaxy(_rng.seed, 25)
	dispatch(VNPReducer.action_start_run(_rng.seed, galaxy_data))

	_add_log("Year 2200: First Von Neumann probe activated.", "success")

## Process one tick of the simulation (called from _process)
func _process_tick() -> void:
	if _state.is_game_over:
		return

	# If there's a pending event, pause simulation
	if not _state.pending_event.is_empty():
		return

	var years = YEARS_PER_TICK

	# Advance time
	_state.year += years

	# Process all probes continuously
	_process_probes_realtime(years)

	# Energy regeneration (continuous)
	var energy_gain = ENERGY_REGEN_PER_YEAR * years
	dispatch(VNPReducer.action_add_resources({"energy": energy_gain}))

	# Check for random events (probability per tick)
	_check_events_realtime(years)

	# Check for threats
	_check_threats(years)

	# Check win/lose conditions
	_check_game_end()

	tick_processed.emit(_state.year)
	state_changed.emit(_state)

## Process all probes for this tick (real-time)
func _process_probes_realtime(years: float) -> void:
	for probe_id in _state.probes.keys():
		var probe = _state.probes[probe_id]

		match probe.status:
			VNPTypes.ProbeStatus.IDLE:
				# Auto-mine if in a system with resources
				_auto_mine_probe(probe_id, probe, years)

			VNPTypes.ProbeStatus.TRAVELING:
				_process_traveling_probe_realtime(probe_id, probe, years)

			VNPTypes.ProbeStatus.MINING:
				_process_mining_probe_realtime(probe_id, probe, years)

			VNPTypes.ProbeStatus.REPLICATING:
				_process_replicating_probe_realtime(probe_id, probe, years)

func _auto_mine_probe(probe_id: String, probe: Dictionary, years: float) -> void:
	var system = _state.systems.get(probe.current_system, {})
	if system.is_empty():
		return

	# Check if there are resources to mine
	var total_resources = system.resources.get("iron", 0) + system.resources.get("rare", 0)
	if total_resources > 0:
		# Auto-start mining
		dispatch(VNPReducer.action_start_mining(probe_id))
		# Process immediately
		_process_mining_probe_realtime(probe_id, _state.probes[probe_id], years)

func _process_traveling_probe_realtime(probe_id: String, probe: Dictionary, years: float) -> void:
	var from_sys = _state.systems.get(probe.current_system, {})
	var to_sys = _state.systems.get(probe.target_system, {})

	if from_sys.is_empty() or to_sys.is_empty():
		return

	# Calculate distance and progress
	var total_distance = from_sys.position.distance_to(to_sys.position)
	var travel_per_tick = TRAVEL_SPEED * years
	var new_progress = probe.travel_progress + travel_per_tick

	if new_progress >= total_distance:
		# Arrived at destination
		dispatch(VNPReducer.action_update_probe(probe_id, {
			"status": VNPTypes.ProbeStatus.IDLE,
			"current_system": probe.target_system,
			"target_system": "",
			"travel_progress": 0.0
		}))

		# Explore the system if new
		if not to_sys.is_explored:
			dispatch(VNPReducer.action_explore_system(probe.target_system))
			_add_log("%s arrived at %s - System explored!" % [probe.name, to_sys.name], "success")
			system_explored.emit(to_sys)
		else:
			_add_log("%s arrived at %s" % [probe.name, to_sys.name], "info")

		var updated_probe = _state.probes.get(probe_id, {})
		probe_arrived.emit(updated_probe, to_sys)
	else:
		dispatch(VNPReducer.action_update_probe(probe_id, {
			"travel_progress": new_progress
		}))

func _process_mining_probe_realtime(probe_id: String, probe: Dictionary, years: float) -> void:
	var system = _state.systems.get(probe.current_system, {})
	if system.is_empty():
		return

	# Calculate mining yield (continuous)
	var efficiency = probe.efficiency
	var iron_rate = MINING_IRON_PER_YEAR * efficiency * years
	var rare_rate = MINING_RARE_PER_YEAR * efficiency * years

	var iron_available = system.resources.get("iron", 0)
	var rare_available = system.resources.get("rare", 0)

	var iron_mined = minf(iron_rate, iron_available)
	var rare_mined = minf(rare_rate, rare_available)

	if iron_mined > 0 or rare_mined > 0:
		dispatch(VNPReducer.action_mine_resources(probe.current_system, {
			"iron": iron_mined,
			"rare": rare_mined
		}))

	# If system depleted, set probe idle (it will look for new resources)
	var updated_sys = _state.systems.get(probe.current_system, {})
	var total_remaining = updated_sys.resources.get("iron", 0) + updated_sys.resources.get("rare", 0)
	if total_remaining <= 0:
		dispatch(VNPReducer.action_set_idle(probe_id))
		_add_log("%s: %s depleted." % [probe.name, system.name], "info")

func _process_replicating_probe_realtime(probe_id: String, probe: Dictionary, years: float) -> void:
	var new_progress = probe.task_progress + years

	if new_progress >= REPLICATION_YEARS:
		# Replication complete!
		var new_id = "probe_%d" % _state.next_probe_id
		var new_name = "Bob-%d" % _state.total_probes_built
		var parent_gen = probe.generation

		var new_probe = VNPTypes.create_probe({
			"id": new_id,
			"name": new_name,
			"current_system": probe.current_system,
			"generation": parent_gen + 1,
			"created_turn": _state.current_turn
		})

		dispatch(VNPReducer.action_create_probe(new_probe))
		dispatch(VNPReducer.action_set_idle(probe_id))

		_add_log("%s completed! Generation %d probe ready." % [new_name, parent_gen + 1], "success")
		probe_created.emit(new_probe)
	else:
		dispatch(VNPReducer.action_update_probe(probe_id, {
			"task_progress": new_progress
		}))

# ============================================================================
# PROBE COMMANDS
# ============================================================================

## Command a probe to travel to another system
func move_probe(probe_id: String, target_system_id: String) -> bool:
	var probe = _state.probes.get(probe_id, {})
	if probe.is_empty():
		return false

	# Can travel if idle or mining (interrupts mining)
	if probe.status != VNPTypes.ProbeStatus.IDLE and probe.status != VNPTypes.ProbeStatus.MINING:
		return false

	var from_sys = _state.systems.get(probe.current_system, {})
	var to_sys = _state.systems.get(target_system_id, {})

	if from_sys.is_empty() or to_sys.is_empty():
		return false

	# Check if systems are connected
	if not VNPGalaxyLogic.are_connected(from_sys, target_system_id):
		return false

	var distance = from_sys.position.distance_to(to_sys.position)
	var travel_years = distance / TRAVEL_SPEED

	dispatch(VNPReducer.action_move_probe(probe_id, target_system_id, 0.0))  # Start at 0 progress
	_add_log("%s departing for %s (%.0f years)" % [probe.name, to_sys.name, travel_years], "info")

	return true

## Command a probe to start mining
func start_mining(probe_id: String) -> bool:
	var probe = _state.probes.get(probe_id, {})
	if probe.is_empty():
		return false

	if probe.status != VNPTypes.ProbeStatus.IDLE:
		return false

	var system = _state.systems.get(probe.current_system, {})
	if system.is_empty():
		return false

	# Check if there are resources to mine
	var total_resources = system.resources.get("iron", 0) + system.resources.get("rare", 0)
	if total_resources <= 0:
		return false

	dispatch(VNPReducer.action_start_mining(probe_id))
	_add_log("%s began mining in %s" % [probe.name, system.name], "info")

	return true

## Command a probe to start replicating
func start_replication(probe_id: String) -> bool:
	var probe = _state.probes.get(probe_id, {})
	if probe.is_empty():
		return false

	# Can replicate if idle or mining (interrupts mining)
	if probe.status != VNPTypes.ProbeStatus.IDLE and probe.status != VNPTypes.ProbeStatus.MINING:
		return false

	# Check resources
	var cost = VNPTypes.REPLICATION_COST
	if _state.resources.iron < cost.iron or _state.resources.energy < cost.energy:
		return false

	# Spend resources
	dispatch(VNPReducer.action_spend_resources(cost))
	dispatch(VNPReducer.action_start_replication(probe_id))

	_add_log("%s began replication (%.0f years, Cost: %d iron, %d energy)" % [probe.name, REPLICATION_YEARS, cost.iron, cost.energy], "info")

	return true

## Set a probe to idle
func set_probe_idle(probe_id: String) -> void:
	var probe = _state.probes.get(probe_id, {})
	if probe.is_empty():
		return

	# Can't cancel travel
	if probe.status == VNPTypes.ProbeStatus.TRAVELING:
		return

	dispatch(VNPReducer.action_set_idle(probe_id))

## Check if replication is affordable
func can_replicate() -> bool:
	var cost = VNPTypes.REPLICATION_COST
	return _state.resources.iron >= cost.iron and _state.resources.energy >= cost.energy

# ============================================================================
# REAL-TIME EVENTS & THREATS
# ============================================================================

## Check for events in real-time (probability per year)
func _check_events_realtime(years: float) -> void:
	# Base chance: 5% per year
	var event_chance = 0.05 * years

	if _rng.randf() > event_chance:
		return

	# Pick a random probe for the event
	var probe_ids = _state.probes.keys()
	if probe_ids.is_empty():
		return

	var target_probe_id = probe_ids[_rng.randi() % probe_ids.size()]
	var target_probe = _state.probes[target_probe_id]
	var system = _state.systems.get(target_probe.current_system, {})

	# Generate event based on system danger level
	var event = _generate_event(target_probe, system)
	if not event.is_empty():
		dispatch(VNPReducer.action_set_event(event))
		event_triggered.emit(event)

## Check for threats - things that require player attention
func _check_threats(years: float) -> void:
	# More probes = higher threat chance (galactic attention)
	var probe_count = get_active_probe_count()
	var threat_chance = 0.01 * years * sqrt(float(probe_count))

	if _rng.randf() > threat_chance or probe_count < 3:
		return

	# Generate a threat that requires resource spending to handle
	var threat_type = _rng.randi() % 3
	var threat: Dictionary

	match threat_type:
		0:  # System hazard - spend energy to shield probes
			var dangerous_systems = []
			for sys_id in _state.systems.keys():
				var sys = _state.systems[sys_id]
				if sys.danger_level > 0.3:
					dangerous_systems.append(sys)
			if dangerous_systems.is_empty():
				return
			var target_sys = dangerous_systems[_rng.randi() % dangerous_systems.size()]
			threat = {
				"title": "Solar Flare Warning",
				"description": "A massive solar flare is approaching %s! Probes there need emergency shielding." % target_sys.name,
				"choices": [
					VNPTypes.create_choice("shield_all", "Shield all probes (-%d energy)" % (probe_count * 20), {"energy": -(probe_count * 20)}),
					VNPTypes.create_choice("sacrifice", "Let them weather it (each probe: 30%% damage chance)", {"damage_all_chance": 0.3, "system": target_sys.id})
				],
				"category": VNPTypes.EventCategory.HAZARD,
				"affected_system": target_sys.id
			}

		1:  # Resource drain - spend resources or lose efficiency
			threat = {
				"title": "Cosmic Ray Burst",
				"description": "Intense cosmic radiation is degrading probe systems across the galaxy!",
				"choices": [
					VNPTypes.create_choice("repair", "Emergency repairs (-%d iron)" % (probe_count * 10), {"iron": -(probe_count * 10)}),
					VNPTypes.create_choice("endure", "Continue operations (all probes: -10%% efficiency for 100 years)", {"efficiency_penalty": 0.1, "duration": 100})
				],
				"category": VNPTypes.EventCategory.HAZARD
			}

		2:  # Expansion pressure - spend rare elements or slow down
			threat = {
				"title": "Quantum Interference",
				"description": "Unknown interference is disrupting replication across the network!",
				"choices": [
					VNPTypes.create_choice("calibrate", "Recalibrate systems (-%d rare)" % (probe_count * 5), {"rare": -(probe_count * 5)}),
					VNPTypes.create_choice("wait", "Wait it out (replication paused for 50 years)", {"pause_replication": 50})
				],
				"category": VNPTypes.EventCategory.HAZARD
			}

	if not threat.is_empty():
		var event = VNPTypes.create_event({
			"id": "threat_%d" % int(_state.year),
			"category": threat.get("category", VNPTypes.EventCategory.HAZARD),
			"title": threat.title,
			"description": threat.description,
			"choices": threat.choices,
			"affected_system": threat.get("affected_system", "")
		})
		dispatch(VNPReducer.action_set_event(event))
		event_triggered.emit(event)
		threat_spawned.emit(threat)

func _generate_event(probe: Dictionary, system: Dictionary) -> Dictionary:
	var roll = _rng.randf()
	var danger = system.get("danger_level", 0.1)

	# Higher danger = more hazards
	if roll < danger * 0.5:
		return _generate_hazard_event(probe, system)
	elif roll < 0.4:
		return _generate_discovery_event(probe, system)
	else:
		return _generate_anomaly_event(probe, system)

func _generate_hazard_event(probe: Dictionary, system: Dictionary) -> Dictionary:
	var hazards = [
		{
			"title": "Radiation Surge",
			"description": "%s detected dangerous radiation levels in %s. The probe's systems are at risk." % [probe.name, system.name],
			"choices": [
				VNPTypes.create_choice("shield", "Activate emergency shielding (lose 50 energy)", {"energy": -50}),
				VNPTypes.create_choice("risk", "Continue operations (20%% chance of damage)", {"damage_chance": 0.2})
			]
		},
		{
			"title": "Micrometeorite Storm",
			"description": "A dense debris field threatens %s in the %s system." % [probe.name, system.name],
			"choices": [
				VNPTypes.create_choice("evade", "Evasive maneuvers (skip this turn's task)", {"skip_turn": true}),
				VNPTypes.create_choice("tank", "Brace for impact (15%% damage)", {"damage_chance": 0.15})
			]
		}
	]

	var hazard = hazards[_rng.randi() % hazards.size()]

	return VNPTypes.create_event({
		"id": "event_%d" % _state.current_turn,
		"category": VNPTypes.EventCategory.HAZARD,
		"title": hazard.title,
		"description": hazard.description,
		"choices": hazard.choices,
		"affected_probe": probe.id,
		"affected_system": system.id
	})

func _generate_discovery_event(probe: Dictionary, system: Dictionary) -> Dictionary:
	var discoveries = [
		{
			"title": "Resource Cache",
			"description": "%s discovered a hidden asteroid with concentrated minerals!" % probe.name,
			"choices": [
				VNPTypes.create_choice("mine", "Mine immediately (+30 iron, +10 rare)", {"iron": 30, "rare": 10}),
				VNPTypes.create_choice("mark", "Mark for later (+50 iron to system)", {"system_iron": 50})
			]
		},
		{
			"title": "Ancient Wreckage",
			"description": "%s found debris from an unknown civilization in %s." % [probe.name, system.name],
			"choices": [
				VNPTypes.create_choice("salvage", "Salvage technology (+20 rare)", {"rare": 20}),
				VNPTypes.create_choice("study", "Study wreckage (+100 energy from data)", {"energy": 100})
			]
		}
	]

	var discovery = discoveries[_rng.randi() % discoveries.size()]

	return VNPTypes.create_event({
		"id": "event_%d" % _state.current_turn,
		"category": VNPTypes.EventCategory.DISCOVERY,
		"title": discovery.title,
		"description": discovery.description,
		"choices": discovery.choices,
		"affected_probe": probe.id,
		"affected_system": system.id
	})

func _generate_anomaly_event(probe: Dictionary, system: Dictionary) -> Dictionary:
	if not system.has_anomaly or system.anomaly_investigated:
		return {}

	return VNPTypes.create_event({
		"id": "event_%d" % _state.current_turn,
		"category": VNPTypes.EventCategory.ANOMALY,
		"title": "Strange Signal",
		"description": "%s detected an artificial signal in %s. Investigation could yield valuable data." % [probe.name, system.name],
		"choices": [
			VNPTypes.create_choice("investigate", "Investigate thoroughly (+50 rare, mark anomaly)", {"rare": 50, "investigate_anomaly": true}),
			VNPTypes.create_choice("ignore", "Log and continue", {})
		],
		"affected_probe": probe.id,
		"affected_system": system.id
	})

## Resolve an event choice
func resolve_event(choice_id: String) -> void:
	var event = _state.pending_event
	if event.is_empty():
		return

	var choice = null
	for c in event.choices:
		if c.id == choice_id:
			choice = c
			break

	if choice == null:
		return

	var effects = choice.effects

	# Apply effects
	if effects.has("iron"):
		dispatch(VNPReducer.action_add_resources({"iron": effects.iron}))
	if effects.has("rare"):
		dispatch(VNPReducer.action_add_resources({"rare": effects.rare}))
	if effects.has("energy"):
		if effects.energy > 0:
			dispatch(VNPReducer.action_add_resources({"energy": effects.energy}))
		else:
			dispatch(VNPReducer.action_spend_resources({"energy": -effects.energy}))

	if effects.has("system_iron"):
		var sys = _state.systems.get(event.affected_system, {})
		if not sys.is_empty():
			var new_resources = sys.resources.duplicate()
			new_resources.iron += effects.system_iron
			dispatch(VNPReducer.action_update_system(event.affected_system, {"resources": new_resources}))

	if effects.has("investigate_anomaly"):
		dispatch(VNPReducer.action_update_system(event.affected_system, {"anomaly_investigated": true}))

	if effects.has("damage_chance"):
		if _rng.randf() < effects.damage_chance:
			var probe = _state.probes.get(event.affected_probe, {})
			if not probe.is_empty():
				var new_health = maxf(0, probe.health - 25)
				dispatch(VNPReducer.action_update_probe(event.affected_probe, {"health": new_health}))
				_add_log("%s took damage! Health: %.0f%%" % [probe.name, new_health], "warning")

				if new_health <= 0:
					dispatch(VNPReducer.action_destroy_probe(event.affected_probe))
					_add_log("%s was destroyed!" % probe.name, "error")
					probe_destroyed.emit(event.affected_probe, probe.name)

	# Clear the event
	dispatch(VNPReducer.action_clear_event())
	_add_log("Resolved: %s" % event.title, "info")

# ============================================================================
# WIN/LOSE CONDITIONS
# ============================================================================

func _check_game_end() -> void:
	# Lose: All probes destroyed
	if _state.probes.is_empty():
		dispatch(VNPReducer.action_end_game(false, "All probes lost. The mission has failed."))
		game_over.emit(false, "All probes lost", _state.final_score)
		return

	# Win: Explored 50% of galaxy
	var explore_ratio = float(_state.systems_explored) / float(_state.total_systems)
	if explore_ratio >= 0.5:
		dispatch(VNPReducer.action_end_game(true, "Half the galaxy explored! Mission successful."))
		game_over.emit(true, "Galaxy explored", _state.final_score)
		return

	# Win: 20+ probes active
	if get_active_probe_count() >= 20:
		dispatch(VNPReducer.action_end_game(true, "Probe swarm achieved! The galaxy will be ours."))
		game_over.emit(true, "Probe swarm", _state.final_score)
		return

# ============================================================================
# HELPERS
# ============================================================================

func _add_log(message: String, category: String = "info") -> void:
	dispatch(VNPReducer.action_add_log(message, category))

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, action: Dictionary) -> void:
	if old_state.resources != new_state.resources:
		resources_changed.emit(new_state.resources)
