## Game Registry
## Central registry for all available games.
## Loads game manifests and provides game definitions.
##
## All functions are static and pure except for caching.
class_name GameRegistry
extends RefCounted


## ============================================================================
## CONSTANTS
## ============================================================================

const GAMES_PATH = "res://data/games/"
const MANIFEST_FILE = "manifest.json"


## ============================================================================
## REGISTRY STATE
## ============================================================================

## Cached game manifests (loaded on first access)
static var _manifests: Dictionary = {}
static var _loaded: bool = false


## ============================================================================
## PUBLIC API
## ============================================================================

## Get list of all available games
static func get_available_games() -> Array[Dictionary]:
	_ensure_loaded()

	var games: Array[Dictionary] = []
	for game_id in _manifests:
		games.append(_manifests[game_id])

	return games


## Get a specific game manifest
static func get_game_manifest(game_id: String) -> Dictionary:
	_ensure_loaded()

	if not _manifests.has(game_id):
		return {}

	return _manifests[game_id].duplicate(true)


## Check if a game exists
static func has_game(game_id: String) -> bool:
	_ensure_loaded()
	return _manifests.has(game_id)


## Get all game IDs
static func get_game_ids() -> Array[String]:
	_ensure_loaded()

	var ids: Array[String] = []
	for game_id in _manifests:
		ids.append(game_id)

	return ids


## Get game path
static func get_game_path(game_id: String) -> String:
	return GAMES_PATH + game_id + "/"


## ============================================================================
## GAME DATA LOADING
## ============================================================================

## Load all data for a game
static func load_game_data(game_id: String) -> Result:
	_ensure_loaded()

	if not _manifests.has(game_id):
		return Result.error("GAME_NOT_FOUND", "Game '%s' not found in registry" % game_id)

	var manifest = _manifests[game_id]
	var game_path = get_game_path(game_id)
	var data: Dictionary = {
		"manifest": manifest,
		"game_id": game_id
	}

	# Load referenced files
	var files = manifest.get("files", {})

	for file_key in files:
		var file_path = game_path + files[file_key]
		var result = _load_json_file(file_path)

		if not result.is_ok():
			return Result.error("FILE_LOAD_ERROR", "Failed to load %s: %s" % [file_key, result.get_error().message])

		data[file_key] = result.get_value()

	return Result.ok(data)


## Load balance data for a game
static func load_balance(game_id: String) -> Result:
	var game_path = get_game_path(game_id)
	var balance_path = game_path + "balance.json"

	return _load_json_file(balance_path)


## Load events for a game and phase
static func load_events(game_id: String, phase: String = "main") -> Result:
	var game_path = get_game_path(game_id)
	var events_path = game_path + "events/%s.json" % phase

	var result = _load_json_file(events_path)

	if not result.is_ok():
		# Try without phase subdirectory
		events_path = game_path + "events.json"
		result = _load_json_file(events_path)

	return result


## ============================================================================
## MANIFEST LOADING
## ============================================================================

## Ensure manifests are loaded
static func _ensure_loaded() -> void:
	if _loaded:
		return

	_load_all_manifests()
	_loaded = true


## Load all game manifests
static func _load_all_manifests() -> void:
	_manifests.clear()

	# Scan games directory
	var dir = DirAccess.open(GAMES_PATH)
	if dir == null:
		push_error("Failed to open games directory: %s" % GAMES_PATH)
		return

	dir.list_dir_begin()
	var folder_name = dir.get_next()

	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var manifest_path = GAMES_PATH + folder_name + "/" + MANIFEST_FILE
			var result = _load_json_file(manifest_path)

			if result.is_ok():
				var manifest = result.get_value()
				manifest["_path"] = GAMES_PATH + folder_name + "/"
				_manifests[manifest.get("id", folder_name)] = manifest
			else:
				push_warning("Failed to load manifest for %s: %s" % [folder_name, result.get_error().message])

		folder_name = dir.get_next()

	dir.list_dir_end()


## ============================================================================
## FILE UTILITIES
## ============================================================================

## Load a JSON file
static func _load_json_file(path: String) -> Result:
	if not FileAccess.file_exists(path):
		return Result.error("FILE_NOT_FOUND", "File not found: %s" % path)

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.error("FILE_READ_ERROR", "Failed to open file: %s" % path)

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)

	if error != OK:
		return Result.error("JSON_PARSE_ERROR", "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])

	return Result.ok(json.data)


## ============================================================================
## CACHE MANAGEMENT
## ============================================================================

## Force reload of all manifests
static func reload() -> void:
	_loaded = false
	_manifests.clear()
	_ensure_loaded()


## Clear cache (for testing)
static func clear_cache() -> void:
	_loaded = false
	_manifests.clear()
