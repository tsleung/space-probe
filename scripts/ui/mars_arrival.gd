extends Control

## Mars Arrival Sequence - The moment of touchdown
## This is an emotional peak in the journey

signal sequence_complete

@onready var background: ColorRect = $Background
@onready var text_container: VBoxContainer = $CenterContainer/TextContainer
@onready var main_text: RichTextLabel = $CenterContainer/TextContainer/MainText
@onready var sub_text: Label = $CenterContainer/TextContainer/SubText
@onready var continue_button: Button = $CenterContainer/TextContainer/ContinueButton

var _current_stage: int = 0
var _crew_names: Array = []
var _mission_day: int = 1

func _ready():
	visible = false
	continue_button.pressed.connect(_advance_stage)
	continue_button.visible = false

func start_sequence(crew: Array, mission_day: int):
	_crew_names = []
	for member in crew:
		if member.health > 0:
			_crew_names.append(member.display_name)
	_mission_day = mission_day
	_current_stage = 0
	visible = true
	_show_stage()

func _show_stage():
	match _current_stage:
		0:
			_show_orbit_insertion()
		1:
			_show_landing_sequence()
		2:
			_show_touchdown()
		3:
			_show_first_steps()
		_:
			_complete_sequence()

func _show_orbit_insertion():
	main_text.text = "[center][b]MARS ORBIT INSERTION[/b][/center]\n\n[center]After %d days of travel,\nthe ship begins orbital maneuvers.\n\nMars fills the viewport.\nRust-red deserts. Ancient volcanoes.\nThis is no longer a photograph.[/center]" % _mission_day
	sub_text.text = "Altitude: 400 km"
	continue_button.visible = true
	continue_button.text = "Continue"
	_animate_fade_in()

	# Shift background to Mars colors
	var tween = create_tween()
	tween.tween_property(background, "color", Color(0.15, 0.05, 0.02), 2.0)

func _show_landing_sequence():
	main_text.text = "[center][b]DESCENT INITIATED[/b][/center]\n\n[center]\"Artemis, you are GO for powered descent.\"\n\nThe lander separates.\nRetro-rockets fire.\nDust swirls in the thin atmosphere.\n\nAltitude dropping...[/center]"
	sub_text.text = "100m... 50m... 20m..."
	_animate_fade_in()

func _show_touchdown():
	main_text.text = "[center][b]TOUCHDOWN CONFIRMED[/b][/center]\n\n[center]\"Contact light. Engine stop.\"\n\nSilence.\n\nThen the radio crackles:\n\"Houston, Utopia Planitia. The Artemis has landed.\"[/center]"
	sub_text.text = "Mission Day %d" % _mission_day

	# Flash effect
	background.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(background, "modulate", Color(1, 0.9, 0.85), 0.5)
	tween.tween_property(background, "modulate", Color.WHITE, 1.0)

	continue_button.text = "Continue"
	_animate_fade_in()

func _show_first_steps():
	var first_crew = _crew_names[0] if not _crew_names.is_empty() else "The commander"

	main_text.text = "[center][b]FIRST STEPS[/b][/center]\n\n[center]%s descends the ladder.\n\nBoots touch Martian soil.\n\n\"That's one small step for a crew,\none giant leap for humanity.\"\n\nYou are on Mars.[/center]" % first_crew
	sub_text.text = "The real work begins now."
	continue_button.text = "Begin Surface Operations"
	_animate_fade_in()

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
