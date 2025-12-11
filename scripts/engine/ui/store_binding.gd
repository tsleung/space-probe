## Store Binding Utility
## Helps UI components bind to Store signals with automatic cleanup.
##
## Usage:
##   var binding = StoreBinding.new(self, store)
##   binding.bind_property("resources.food", _on_food_changed)
##   binding.bind_computed(func(): return store.get_state().crew.size(), _on_crew_count_changed)
class_name StoreBinding
extends RefCounted


## ============================================================================
## STATE
## ============================================================================

var _owner: Node
var _store: Node  # Can be any Store with state_changed signal
var _bindings: Array[Dictionary] = []
var _last_values: Dictionary = {}
var _connected: bool = false


## ============================================================================
## LIFECYCLE
## ============================================================================

func _init(owner: Node, store: Node) -> void:
	_owner = owner
	_store = store

	if _store.has_signal("state_changed"):
		_store.state_changed.connect(_on_state_changed)
		_connected = true

	# Auto-disconnect when owner is freed
	if _owner.has_signal("tree_exited"):
		_owner.tree_exited.connect(disconnect_all)


## Disconnect all bindings
func disconnect_all() -> void:
	if _connected and is_instance_valid(_store):
		if _store.has_signal("state_changed") and _store.state_changed.is_connected(_on_state_changed):
			_store.state_changed.disconnect(_on_state_changed)
	_bindings.clear()
	_last_values.clear()
	_connected = false


## ============================================================================
## BINDING API
## ============================================================================

## Bind to a specific state path (e.g., "resources.food.current")
func bind_property(path: String, callback: Callable) -> StoreBinding:
	_bindings.append({
		"type": "property",
		"path": path,
		"callback": callback
	})

	# Initialize with current value
	var value = _get_path_value(path)
	_last_values[path] = value
	callback.call(value)

	return self


## Bind to a computed value (function that extracts/transforms state)
func bind_computed(getter: Callable, callback: Callable, key: String = "") -> StoreBinding:
	var binding_key = key if key else str(getter.get_object_id())

	_bindings.append({
		"type": "computed",
		"getter": getter,
		"callback": callback,
		"key": binding_key
	})

	# Initialize with current value
	var value = getter.call()
	_last_values[binding_key] = value
	callback.call(value)

	return self


## Bind to any state change (always called)
func bind_any(callback: Callable) -> StoreBinding:
	_bindings.append({
		"type": "any",
		"callback": callback
	})

	# Initialize with current state
	if _store.has_method("get_state"):
		callback.call(_store.get_state())

	return self


## Bind to a specific action type
func bind_action(action_type: String, callback: Callable) -> StoreBinding:
	_bindings.append({
		"type": "action",
		"action_type": action_type,
		"callback": callback
	})

	return self


## ============================================================================
## HELPERS
## ============================================================================

## Get value at path in state
func _get_path_value(path: String):
	if not _store.has_method("get_state"):
		return null

	var state = _store.get_state()
	var parts = path.split(".")
	var current = state

	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		elif current is Array and part.is_valid_int():
			var idx = int(part)
			if idx >= 0 and idx < current.size():
				current = current[idx]
			else:
				return null
		else:
			return null

	return current


## Handle state change
func _on_state_changed(new_state) -> void:
	for binding in _bindings:
		match binding.type:
			"property":
				var path = binding.path
				var new_value = _get_path_value(path)
				var old_value = _last_values.get(path)

				if not _values_equal(new_value, old_value):
					_last_values[path] = new_value
					binding.callback.call(new_value)

			"computed":
				var new_value = binding.getter.call()
				var key = binding.key
				var old_value = _last_values.get(key)

				if not _values_equal(new_value, old_value):
					_last_values[key] = new_value
					binding.callback.call(new_value)

			"any":
				binding.callback.call(new_state)


## Compare values for equality
func _values_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false

	if a is Dictionary:
		return _dicts_equal(a, b)
	elif a is Array:
		return _arrays_equal(a, b)
	else:
		return a == b


func _dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false

	for key in a:
		if not b.has(key):
			return false
		if not _values_equal(a[key], b[key]):
			return false

	return true


func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false

	for i in range(a.size()):
		if not _values_equal(a[i], b[i]):
			return false

	return true


## ============================================================================
## CONVENIENCE METHODS
## ============================================================================

## Create a derived value that updates when any dependency changes
func derive(paths: Array[String], transform: Callable, callback: Callable) -> StoreBinding:
	var getter = func():
		var values: Array = []
		for path in paths:
			values.append(_get_path_value(path))
		return transform.call(values)

	var key = "derived:" + ",".join(paths)
	return bind_computed(getter, callback, key)


## Bind to array length
func bind_array_length(path: String, callback: Callable) -> StoreBinding:
	var getter = func():
		var arr = _get_path_value(path)
		return arr.size() if arr is Array else 0

	return bind_computed(getter, callback, path + ".length")


## Bind to dictionary keys
func bind_dict_keys(path: String, callback: Callable) -> StoreBinding:
	var getter = func():
		var dict = _get_path_value(path)
		return dict.keys() if dict is Dictionary else []

	return bind_computed(getter, callback, path + ".keys")
