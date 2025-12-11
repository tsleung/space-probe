## Result type for explicit error handling.
## Use instead of returning null, -1, or false to indicate failure.
##
## Usage:
##   var result = some_operation()
##   if result.is_ok():
##       var value = result.get_value()
##   else:
##       var error = result.get_error()
##       push_error(error.message)
class_name Result
extends RefCounted

var _value
var _error: Dictionary
var _is_ok: bool


## Create a successful result with a value
static func ok(value = null) -> Result:
	var r = Result.new()
	r._value = value
	r._is_ok = true
	r._error = {}
	return r


## Create a failed result with an error
## Error should have: code (String), message (String), and optional context fields
static func err(error: Dictionary) -> Result:
	assert(error.has("code"), "Error must have 'code' field")
	assert(error.has("message"), "Error must have 'message' field")
	var r = Result.new()
	r._error = error
	r._is_ok = false
	return r


## Create an error with standard fields
static func error(code: String, message: String, context: Dictionary = {}) -> Result:
	var error = {
		"code": code,
		"message": message
	}
	error.merge(context)
	return err(error)


## Check if result is successful
func is_ok() -> bool:
	return _is_ok


## Check if result is an error
func is_err() -> bool:
	return not _is_ok


## Get the success value. Only call if is_ok() is true.
func get_value():
	assert(_is_ok, "Cannot get value from error result")
	return _value


## Get the error dictionary. Only call if is_err() is true.
func get_error() -> Dictionary:
	assert(not _is_ok, "Cannot get error from ok result")
	return _error


## Get value or return default if error
func unwrap_or(default):
	return _value if _is_ok else default


## Get value or call function to get default if error
func unwrap_or_else(callable: Callable):
	return _value if _is_ok else callable.call()


## Transform the value if ok, pass through error if not
func map(callable: Callable) -> Result:
	if _is_ok:
		return Result.ok(callable.call(_value))
	return self


## Transform the error if err, pass through value if not
func map_err(callable: Callable) -> Result:
	if not _is_ok:
		return Result.err(callable.call(_error))
	return self


## Chain another operation that returns Result
func and_then(callable: Callable) -> Result:
	if _is_ok:
		return callable.call(_value)
	return self


## Provide alternative if error
func or_else(callable: Callable) -> Result:
	if not _is_ok:
		return callable.call(_error)
	return self


## Get value, pushing error if failed (for cases where you must proceed)
func unwrap_or_push_error(default):
	if not _is_ok:
		push_error("Result error [%s]: %s" % [_error.code, _error.message])
		return default
	return _value


## String representation for debugging
func _to_string() -> String:
	if _is_ok:
		return "Result.ok(%s)" % str(_value)
	else:
		return "Result.err(%s: %s)" % [_error.code, _error.message]
