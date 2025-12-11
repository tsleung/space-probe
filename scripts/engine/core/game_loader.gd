## Loads game definitions from data files.
##
## Responsible for:
## - Loading game manifests
## - Loading components, events, crew, balance data
## - Validating loaded data against schemas
## - Caching loaded games
class_name GameLoader
extends RefCounted

const DATA_PATH = "res://data/"
const GAMES_PATH = DATA_PATH + "games/"
const SHARED_PATH = DATA_PATH + "shared/"

var _loaded_games: Dictionary = {}
var _schema_validator: SchemaValidator


func _init():
	_schema_validator = SchemaValidator.new()


## ============================================================================
## GAME LOADING
## ============================================================================

## Load a complete game definition
func load_game(game_id: String) -> Result:
	# Check cache
	if _loaded_games.has(game_id):
		return Result.ok(_loaded_games[game_id])

	var game_path = GAMES_PATH + game_id + "/"

	# Load manifest first
	var manifest_result = _load_json(game_path + "manifest.json")
	if not manifest_result.is_ok():
		return Result.error(
			"MANIFEST_NOT_FOUND",
			"Could not load game manifest for '%s'" % game_id,
			{"game_id": game_id, "path": game_path + "manifest.json"}
		)

	var manifest = manifest_result.get_value()

	# Build game data
	var game_data = {
		"id": game_id,
		"manifest": manifest,
		"name": manifest.get("name", game_id),
		"description": manifest.get("description", ""),
		"version": manifest.get("version", "1.0.0"),

		# Load all content
		"phases": _load_json(game_path + "phases.json").unwrap_or([]),
		"components": _load_json(game_path + "components.json").unwrap_or([]),
		"engines": _load_json(game_path + "engines.json").unwrap_or([]),
		"crew_roster": _load_json(game_path + "crew_roster.json").unwrap_or([]),
		"balance": _load_json(game_path + "balance.json").unwrap_or({}),

		# Load events by phase
		"events": _load_events(game_path + "events/"),

		# Load shared content
		"shared": _load_shared_content()
	}

	# Validate game data
	var validation = _schema_validator.validate_game(game_data)
	if not validation.is_ok():
		push_warning("Game validation warnings for '%s': %s" % [game_id, validation.get_error()])
		# Continue anyway - just warnings

	# Cache and return
	_loaded_games[game_id] = game_data
	return Result.ok(game_data)


## Get a loaded game (returns empty dict if not loaded)
func get_game(game_id: String) -> Dictionary:
	return _loaded_games.get(game_id, {})


## Check if a game is loaded
func is_game_loaded(game_id: String) -> bool:
	return _loaded_games.has(game_id)


## Clear cache (for hot-reloading)
func clear_cache() -> void:
	_loaded_games.clear()


## Reload a specific game
func reload_game(game_id: String) -> Result:
	_loaded_games.erase(game_id)
	return load_game(game_id)


## ============================================================================
## CONTENT LOADING HELPERS
## ============================================================================

func _load_json(path: String) -> Result:
	if not FileAccess.file_exists(path):
		return Result.error(
			"FILE_NOT_FOUND",
			"File not found: %s" % path,
			{"path": path}
		)

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.error(
			"FILE_OPEN_ERROR",
			"Could not open file: %s" % path,
			{"path": path, "error": FileAccess.get_open_error()}
		)

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return Result.error(
			"JSON_PARSE_ERROR",
			"Failed to parse JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()],
			{"path": path, "line": json.get_error_line()}
		)

	return Result.ok(json.data)


func _load_events(events_path: String) -> Dictionary:
	var events: Dictionary = {}

	if not DirAccess.dir_exists_absolute(events_path):
		return events

	var dir = DirAccess.open(events_path)
	if dir == null:
		return events

	dir.list_dir_begin()
	var filename = dir.get_next()

	while filename != "":
		if filename.ends_with(".json"):
			var phase = filename.trim_suffix(".json")
			var result = _load_json(events_path + filename)
			if result.is_ok():
				var data = result.get_value()
				# Support both array of events and object with "events" key
				if data is Array:
					events[phase] = data
				elif data is Dictionary and data.has("events"):
					events[phase] = data.events
				else:
					events[phase] = []
		filename = dir.get_next()

	dir.list_dir_end()
	return events


func _load_shared_content() -> Dictionary:
	return {
		"traits": _load_json(SHARED_PATH + "traits.json").unwrap_or([]),
		"conditions": _load_json(SHARED_PATH + "conditions.json").unwrap_or([]),
		"achievements": _load_json(SHARED_PATH + "achievements.json").unwrap_or([]),
		"difficulty": _load_json(DATA_PATH + "difficulty.json").unwrap_or({})
	}


## ============================================================================
## CONTENT QUERIES
## ============================================================================

## Get component definition by ID
func get_component(game_id: String, component_id: String) -> Dictionary:
	var game = get_game(game_id)
	for component in game.get("components", []):
		if component.get("id") == component_id:
			return component
	return {}


## Get engine definition by ID
func get_engine(game_id: String, engine_id: String) -> Dictionary:
	var game = get_game(game_id)
	for engine in game.get("engines", []):
		if engine.get("id") == engine_id:
			return engine
	return {}


## Get crew member from roster by ID
func get_crew_from_roster(game_id: String, crew_id: String) -> Dictionary:
	var game = get_game(game_id)
	for crew in game.get("crew_roster", []):
		if crew.get("id") == crew_id:
			return crew
	return {}


## Get event definition by ID
func get_event(game_id: String, event_id: String, phase: String = "") -> Dictionary:
	var game = get_game(game_id)
	var events = game.get("events", {})

	# Search specific phase if provided
	if not phase.is_empty() and events.has(phase):
		for event in events[phase]:
			if event.get("id") == event_id:
				return event

	# Search all phases
	for phase_events in events.values():
		for event in phase_events:
			if event.get("id") == event_id:
				return event

	return {}


## Get balance value by path (e.g., "phase1.base_component_quality")
func get_balance(game_id: String, path: String, default = null):
	var game = get_game(game_id)
	var balance = game.get("balance", {})

	var parts = path.split(".")
	var current = balance

	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return default

	return current


## ============================================================================
## GAME DISCOVERY
## ============================================================================

## List all available games
func list_available_games() -> Array[Dictionary]:
	var games: Array[Dictionary] = []

	if not DirAccess.dir_exists_absolute(GAMES_PATH):
		return games

	var dir = DirAccess.open(GAMES_PATH)
	if dir == null:
		return games

	dir.list_dir_begin()
	var dirname = dir.get_next()

	while dirname != "":
		if dir.current_is_dir() and not dirname.begins_with("."):
			var manifest_path = GAMES_PATH + dirname + "/manifest.json"
			if FileAccess.file_exists(manifest_path):
				var result = _load_json(manifest_path)
				if result.is_ok():
					var manifest = result.get_value()
					games.append({
						"id": dirname,
						"name": manifest.get("name", dirname),
						"description": manifest.get("description", ""),
						"version": manifest.get("version", "1.0.0")
					})
		dirname = dir.get_next()

	dir.list_dir_end()
	return games
