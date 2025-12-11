## Centralized random number generator.
## All randomness in the game flows through this manager.
## Enables deterministic replay by controlling the seed.
##
## Random values are generated here and passed INTO pure functions,
## keeping all game logic deterministic.
class_name RNGManager
extends RefCounted

var _rng: RandomNumberGenerator
var _seed: int
var _call_count: int = 0


func _init(seed: int = -1):
	_rng = RandomNumberGenerator.new()
	if seed == -1:
		_rng.randomize()
		_seed = _rng.seed
	else:
		_seed = seed
		_rng.seed = seed


## Get the seed used by this RNG
func get_seed() -> int:
	return _seed


## Get number of random calls made (for debugging/replay)
func get_call_count() -> int:
	return _call_count


## Reset to initial state with same seed
func reset() -> void:
	_rng.seed = _seed
	_call_count = 0


## Reset with a new seed
func reset_with_seed(seed: int) -> void:
	_seed = seed
	_rng.seed = seed
	_call_count = 0


## Get random float in range [0.0, 1.0)
func randf() -> float:
	_call_count += 1
	return _rng.randf()


## Get random float in range [min, max]
func randf_range(min_val: float, max_val: float) -> float:
	_call_count += 1
	return _rng.randf_range(min_val, max_val)


## Get random integer in range [min, max] (inclusive)
func randi_range(min_val: int, max_val: int) -> int:
	_call_count += 1
	return _rng.randi_range(min_val, max_val)


## Get N random floats [0.0, 1.0) - for actions needing multiple rolls
func randf_array(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in range(count):
		result.append(randf())
	return result


## Get N random floats in range [min, max]
func randf_range_array(count: int, min_val: float, max_val: float) -> Array[float]:
	var result: Array[float] = []
	for i in range(count):
		result.append(randf_range(min_val, max_val))
	return result


## Check if random roll succeeds (roll < probability)
func check(probability: float) -> bool:
	return randf() < probability


## Pick random item from array
func pick(array: Array):
	if array.is_empty():
		return null
	return array[randi_range(0, array.size() - 1)]


## Pick N random items from array (without replacement)
func pick_n(array: Array, n: int) -> Array:
	if array.is_empty() or n <= 0:
		return []

	var available = array.duplicate()
	var result = []
	var count = mini(n, available.size())

	for i in range(count):
		var index = randi_range(0, available.size() - 1)
		result.append(available[index])
		available.remove_at(index)

	return result


## Pick random item using weights
## Items and weights must be same length
func pick_weighted(items: Array, weights: Array) -> Variant:
	if items.is_empty() or weights.is_empty():
		return null

	assert(items.size() == weights.size(), "Items and weights must have same length")

	var total: float = 0.0
	for w in weights:
		total += float(w)

	if total <= 0:
		return pick(items)

	var roll = randf() * total
	var cumulative: float = 0.0

	for i in range(items.size()):
		cumulative += float(weights[i])
		if roll < cumulative:
			return items[i]

	return items[-1]


## Pick random item using weight field in dictionaries
## Example: pick_weighted_by_field([{id: "a", weight: 0.3}, {id: "b", weight: 0.7}], "weight")
func pick_weighted_by_field(items: Array, weight_field: String) -> Variant:
	if items.is_empty():
		return null

	var weights: Array = []
	for item in items:
		weights.append(float(item.get(weight_field, 1.0)))

	return pick_weighted(items, weights)


## Shuffle array in place and return it
func shuffle(array: Array) -> Array:
	var n = array.size()
	for i in range(n - 1, 0, -1):
		var j = randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
	return array


## Get a shuffled copy of array
func shuffled(array: Array) -> Array:
	return shuffle(array.duplicate())


## Roll dice: NdS (N dice with S sides)
## Example: roll_dice(2, 6) for 2d6
func roll_dice(num_dice: int, num_sides: int) -> int:
	var total = 0
	for i in range(num_dice):
		total += randi_range(1, num_sides)
	return total


## Get detailed dice roll result
func roll_dice_detailed(num_dice: int, num_sides: int) -> Dictionary:
	var rolls: Array[int] = []
	var total = 0
	for i in range(num_dice):
		var roll = randi_range(1, num_sides)
		rolls.append(roll)
		total += roll
	return {
		"rolls": rolls,
		"total": total,
		"num_dice": num_dice,
		"num_sides": num_sides
	}


## Normal distribution (Box-Muller transform)
func randfn(mean: float = 0.0, std_dev: float = 1.0) -> float:
	var u1 = randf()
	var u2 = randf()
	# Avoid log(0)
	while u1 == 0:
		u1 = randf()
	var z = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return mean + z * std_dev


## Get state for serialization (for save games)
func get_state() -> Dictionary:
	return {
		"seed": _seed,
		"call_count": _call_count,
		"rng_state": _rng.state
	}


## Restore state from serialization
func set_state(state: Dictionary) -> void:
	_seed = state.get("seed", _seed)
	_call_count = state.get("call_count", 0)
	if state.has("rng_state"):
		_rng.state = state.rng_state
	else:
		_rng.seed = _seed
		# Fast-forward to correct position
		for i in range(_call_count):
			_rng.randf()
