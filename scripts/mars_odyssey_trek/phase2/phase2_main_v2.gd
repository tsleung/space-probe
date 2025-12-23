extends Node
class_name Phase2MainV2

## Phase 2: Travel to Mars - Main Coordinator
## Connects Store, View, and Controller together

@onready var store: Node = $Store
@onready var view: Control = $View
@onready var controller: Node = $Controller

func _ready() -> void:
	# Connect View and Controller to Store
	if view and store:
		view.connect_to_store(store)
	if controller and store:
		controller.connect_to_store(store)

	# Wire up event option buttons
	_connect_event_buttons()

	# Wire up speed control buttons
	_connect_speed_buttons()

	print("[Phase2] Initialized with Store/Reducer architecture")

func _connect_event_buttons() -> void:
	var event_options = view.get_node_or_null("UI/EventPopup/Content/Options")
	if not event_options:
		return

	for i in range(event_options.get_child_count()):
		var btn = event_options.get_child(i) as Button
		if btn:
			var choice_index = i
			btn.pressed.connect(func(): controller.resolve_event_choice(choice_index))

func _connect_speed_buttons() -> void:
	var speed_controls = view.get_node_or_null("UI/SpeedControls")
	if not speed_controls:
		return

	var slow_btn = speed_controls.get_node_or_null("SlowBtn") as Button
	var normal_btn = speed_controls.get_node_or_null("NormalBtn") as Button
	var fast_btn = speed_controls.get_node_or_null("FastBtn") as Button
	var pause_btn = speed_controls.get_node_or_null("PauseBtn") as Button

	if slow_btn:
		slow_btn.pressed.connect(controller.set_speed_slow)
	if normal_btn:
		normal_btn.pressed.connect(controller.set_speed_normal)
	if fast_btn:
		fast_btn.pressed.connect(controller.set_speed_fast)
	if pause_btn:
		pause_btn.pressed.connect(controller.toggle_pause)
