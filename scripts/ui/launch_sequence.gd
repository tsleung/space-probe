extends Control

## Launch Sequence - A dramatic cinematic moment when departing for Mars
## This is the emotional peak of the ship building phase

signal sequence_complete

@onready var background: ColorRect = $Background
@onready var text_container: VBoxContainer = $CenterContainer/TextContainer
@onready var main_text: RichTextLabel = $CenterContainer/TextContainer/MainText
@onready var sub_text: Label = $CenterContainer/TextContainer/SubText
@onready var countdown_label: Label = $CenterContainer/TextContainer/CountdownLabel
@onready var continue_button: Button = $CenterContainer/TextContainer/ContinueButton

var _current_stage: int = 0
var _crew_names: Array = []
var _travel_days: int = 180

func _ready():
	visible = false
	continue_button.pressed.connect(_advance_stage)
	continue_button.visible = false

func start_sequence(crew: Array, travel_days: int):
	_crew_names = []
	for member in crew:
		_crew_names.append(member.display_name)
	_travel_days = travel_days
	_current_stage = 0
	visible = true
	_show_stage()

func _show_stage():
	match _current_stage:
		0:
			_show_preflight()
		1:
			_show_crew_boarding()
		2:
			_show_final_checks()
		3:
			_show_countdown()
		4:
			_show_launch()
		5:
			_show_departure()
		_:
			_complete_sequence()

func _show_preflight():
	main_text.text = "[center][b]LUNA BASE - LAUNCH COMPLEX 7[/b][/center]\n\n[center]Final preparations are underway.\nThe ship has been loaded with supplies.\nAll systems report nominal.[/center]"
	sub_text.text = "T-minus 2 hours to launch window"
	countdown_label.visible = false
	continue_button.visible = true
	continue_button.text = "Continue"
	_animate_fade_in()

func _show_crew_boarding():
	var crew_text = ""
	for i in range(_crew_names.size()):
		crew_text += "  %s reports aboard.\n" % _crew_names[i]

	main_text.text = "[center][b]CREW BOARDING[/b][/center]\n\n%s\n[center]All crew members secured in launch positions.[/center]" % crew_text
	sub_text.text = "T-minus 30 minutes"
	continue_button.visible = true
	_animate_fade_in()

func _show_final_checks():
	main_text.text = "[center][b]FINAL SYSTEMS CHECK[/b][/center]\n\n[center]\"Flight, all stations report status.\"\n\n  Propulsion: GO\n  Life Support: GO\n  Navigation: GO\n  Communication: GO\n  Medical: GO\n\n\"Flight Director, we are GO for launch.\"[/center]"
	sub_text.text = "T-minus 5 minutes"
	continue_button.visible = true
	_animate_fade_in()

func _show_countdown():
	main_text.text = "[center][b]COUNTDOWN INITIATED[/b][/center]"
	sub_text.text = ""
	countdown_label.visible = true
	continue_button.visible = false
	_animate_countdown()

func _animate_countdown():
	var counts = ["10", "9", "8", "7", "6", "5", "4", "3", "2", "1"]
	for i in range(counts.size()):
		countdown_label.text = counts[i]
		# Flash effect
		countdown_label.modulate = Color.WHITE
		var tween = create_tween()
		if i < 5:
			tween.tween_property(countdown_label, "modulate", Color(0.7, 0.7, 0.7), 0.8)
		else:
			# More dramatic for final seconds
			tween.tween_property(countdown_label, "modulate", Color(1, 0.8, 0.3), 0.3)
			tween.tween_property(countdown_label, "modulate", Color.WHITE, 0.3)
		await get_tree().create_timer(0.8).timeout

	countdown_label.text = "IGNITION"
	countdown_label.modulate = Color(1, 0.5, 0.2)
	await get_tree().create_timer(1.0).timeout

	_current_stage += 1
	_show_stage()

func _show_launch():
	countdown_label.visible = false
	main_text.text = "[center][b]LIFTOFF[/b][/center]\n\n[center]\"We have liftoff! The Artemis mission\nis on its way to Mars!\"\n\nEngine performance nominal.\nVelocity increasing.\nLunar gravity well clearing...[/center]"
	sub_text.text = ""

	# Screen shake/flash effect
	background.modulate = Color(1, 0.9, 0.8)
	var tween = create_tween()
	tween.tween_property(background, "modulate", Color(0, 0, 0.05), 2.0)

	continue_button.visible = true
	continue_button.text = "Continue"

func _show_departure():
	main_text.text = "[center][b]TRANS-MARS INJECTION COMPLETE[/b][/center]\n\n[center]The ship has achieved escape velocity.\n\nEarth grows smaller behind you.\nMars awaits.\n\n[b]Estimated journey time: %d days[/b]\n\nThe crew settles in for the long voyage.[/center]" % _travel_days
	sub_text.text = "\"Godspeed, Artemis.\""
	continue_button.visible = true
	continue_button.text = "Begin Journey"

func _advance_stage():
	_current_stage += 1
	_show_stage()

func _complete_sequence():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	visible = false
	modulate.a = 1.0
	sequence_complete.emit()

func _animate_fade_in():
	text_container.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(text_container, "modulate:a", 1.0, 0.5)
