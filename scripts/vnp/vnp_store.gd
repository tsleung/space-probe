extends Node

var state = {}
var reducer = preload("res://scripts/vnp/vnp_reducer.gd").new()
var subscribers = []

func _ready():
	# Initialize the state when the store is ready
	state = reducer.get_initial_state()

# Public method to get the current state
func get_state():
	return state

# Dispatch an action to be processed by the reducer
func dispatch(action):
	# The reducer returns the new state
	var new_state = reducer.reduce(state, action)
	
	# Only update and notify if the state has actually changed
	if new_state != state:
		state = new_state
		_notify_subscribers()

# Subscribe a listener function to state changes
func subscribe(subscriber):
	if not subscribers.has(subscriber):
		subscribers.append(subscriber)

# Unsubscribe a listener
func unsubscribe(subscriber):
	var index = subscribers.find(subscriber)
	if index != -1:
		subscribers.remove_at(index)

# Notify all subscribers of a state change
func _notify_subscribers():
	for subscriber in subscribers:
		if is_instance_valid(subscriber) and subscriber.has_method("on_state_changed"):
			subscriber.on_state_changed(state)
		else:
			# Clean up invalid subscribers if they get destroyed
			unsubscribe(subscriber)