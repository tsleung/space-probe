## Handles save/load operations for game state.
##
## Saves are JSON files containing:
## - Game state
## - RNG state (for deterministic replay)
## - Metadata (version, timestamps)
class_name Persistence
extends RefCounted

const SAVE_DIR = "user://saves/"
const SAVE_EXTENSION = ".json"


func _init():
	_ensure_save_directory()


## ============================================================================
## SAVE OPERATIONS
## ============================================================================

## Save data to file
func save(path: String, data: Dictionary) -> Result:
	var full_path = _get_full_path(path)

	# Convert to JSON
	var json_string = JSON.stringify(data, "  ")

	# Write to file
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		return Result.error(
			"SAVE_FAILED",
			"Could not open file for writing: %s" % full_path,
			{"path": full_path, "error": FileAccess.get_open_error()}
		)

	file.store_string(json_string)
	file.close()

	return Result.ok(full_path)


## Auto-save with timestamp
func auto_save(data: Dictionary, prefix: String = "autosave") -> Result:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "%s_%s%s" % [prefix, timestamp, SAVE_EXTENSION]
	return save(filename, data)


## ============================================================================
## LOAD OPERATIONS
## ============================================================================

## Load data from file
func load_file(path: String) -> Result:
	var full_path = _get_full_path(path)

	if not FileAccess.file_exists(full_path):
		return Result.error(
			"FILE_NOT_FOUND",
			"Save file not found: %s" % full_path,
			{"path": full_path}
		)

	var file = FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return Result.error(
			"LOAD_FAILED",
			"Could not open file for reading: %s" % full_path,
			{"path": full_path, "error": FileAccess.get_open_error()}
		)

	var json_string = file.get_as_text()
	file.close()

	# Parse JSON
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return Result.error(
			"JSON_PARSE_ERROR",
			"Failed to parse save file: %s" % json.get_error_message(),
			{"path": full_path, "line": json.get_error_line()}
		)

	var data = json.data
	if not data is Dictionary:
		return Result.error(
			"INVALID_SAVE_FORMAT",
			"Save file must contain a dictionary",
			{"path": full_path}
		)

	# Validate version
	var version_result = _validate_version(data)
	if not version_result.is_ok():
		return version_result

	return Result.ok(data)


## ============================================================================
## SAVE MANAGEMENT
## ============================================================================

## List all save files
func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []

	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var filename = dir.get_next()

	while filename != "":
		if filename.ends_with(SAVE_EXTENSION):
			var info = get_save_info(filename)
			if info.is_ok():
				saves.append(info.get_value())
		filename = dir.get_next()

	dir.list_dir_end()

	# Sort by date, newest first
	saves.sort_custom(func(a, b): return a.saved_at > b.saved_at)

	return saves


## Get info about a save file without fully loading it
func get_save_info(path: String) -> Result:
	var load_result = load_file(path)
	if not load_result.is_ok():
		return load_result

	var data = load_result.get_value()

	return Result.ok({
		"filename": path,
		"game_id": data.get("game_id", "unknown"),
		"saved_at": data.get("saved_at", "unknown"),
		"version": data.get("version", "unknown"),
		"phase": data.get("state", {}).get("current_phase", "unknown"),
		"day": data.get("state", {}).get("current_day", 0),
		"crew_count": data.get("state", {}).get("crew", []).size()
	})


## Delete a save file
func delete_save(path: String) -> Result:
	var full_path = _get_full_path(path)

	if not FileAccess.file_exists(full_path):
		return Result.error(
			"FILE_NOT_FOUND",
			"Save file not found: %s" % full_path,
			{"path": full_path}
		)

	var error = DirAccess.remove_absolute(full_path)
	if error != OK:
		return Result.error(
			"DELETE_FAILED",
			"Could not delete save file",
			{"path": full_path, "error": error}
		)

	return Result.ok(path)


## ============================================================================
## HELPERS
## ============================================================================

func _get_full_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return path
	return SAVE_DIR + path


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _validate_version(data: Dictionary) -> Result:
	var version = data.get("version", "0.0.0")

	# Parse version
	var parts = version.split(".")
	if parts.size() < 2:
		return Result.error(
			"INVALID_VERSION",
			"Save file has invalid version: %s" % version,
			{"version": version}
		)

	# Check compatibility (major version must match)
	var save_major = int(parts[0])
	var current_major = 1  # Current game version

	if save_major != current_major:
		return Result.error(
			"VERSION_MISMATCH",
			"Save file version %s is incompatible with game version 1.x" % version,
			{"save_version": version, "game_version": "1.0.0"}
		)

	return Result.ok(version)


## ============================================================================
## EXPORT/IMPORT (for sharing saves)
## ============================================================================

## Export save to a portable format
func export_save(path: String, export_path: String) -> Result:
	var load_result = load_file(path)
	if not load_result.is_ok():
		return load_result

	var data = load_result.get_value()

	# Add export metadata
	data["exported_at"] = Time.get_datetime_string_from_system()
	data["original_path"] = path

	# Encode as base64 for easy sharing (optional)
	var json_string = JSON.stringify(data, "  ")

	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		return Result.error(
			"EXPORT_FAILED",
			"Could not create export file",
			{"path": export_path}
		)

	file.store_string(json_string)
	file.close()

	return Result.ok(export_path)


## Import save from external source
func import_save(import_path: String, save_name: String = "") -> Result:
	# Read import file
	if not FileAccess.file_exists(import_path):
		return Result.error(
			"IMPORT_FILE_NOT_FOUND",
			"Import file not found",
			{"path": import_path}
		)

	var file = FileAccess.open(import_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return Result.error(
			"IMPORT_PARSE_ERROR",
			"Failed to parse import file",
			{"path": import_path}
		)

	var data = json.data

	# Remove export metadata
	data.erase("exported_at")
	data.erase("original_path")

	# Generate save name if not provided
	if save_name.is_empty():
		save_name = "imported_%s%s" % [
			Time.get_datetime_string_from_system().replace(":", "-"),
			SAVE_EXTENSION
		]

	return save(save_name, data)
