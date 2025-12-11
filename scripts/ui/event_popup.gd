extends Control

## Event Popup - Presents interactive events with choices to the player
## Used across all phases for Oregon Trail-style decision making

signal choice_made(event: Dictionary, choice_id: String)
signal popup_closed

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var description_label: RichTextLabel = $Panel/VBox/DescriptionLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer
@onready var consequence_label: RichTextLabel = $Panel/VBox/ConsequenceLabel
@onready var continue_button: Button = $Panel/VBox/ContinueButton

var _current_event: Dictionary = {}
var _selected_choice: Dictionary = {}
var _showing_consequence: bool = false

func _ready():
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	consequence_label.visible = false
	continue_button.visible = false

## Show an event with choices
func show_event(event: Dictionary):
	_current_event = event
	_selected_choice = {}
	_showing_consequence = false

	# Play alert sound
	AudioManager.play_alert()

	title_label.text = event.title
	description_label.text = event.description

	# Clear old choice buttons
	for child in choices_container.get_children():
		child.queue_free()

	# Create choice buttons
	for choice in event.choices:
		var button = Button.new()
		button.text = "[%s] %s" % [choice.id.to_upper(), choice.text]
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_on_choice_pressed.bind(choice))
		choices_container.add_child(button)

	consequence_label.visible = false
	continue_button.visible = false

	visible = true
	# Animate in
	panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

## Called when player clicks a choice
func _on_choice_pressed(choice: Dictionary):
	_selected_choice = choice
	_showing_consequence = true

	# Play click sound
	AudioManager.play_click()

	# Hide choice buttons
	for child in choices_container.get_children():
		child.visible = false

	# Show consequence
	consequence_label.text = "[b]%s[/b]\n\n%s" % [choice.text, choice.consequence_text]
	consequence_label.visible = true
	continue_button.visible = true
	continue_button.grab_focus()

func _on_continue_pressed():
	if _showing_consequence and not _selected_choice.is_empty():
		choice_made.emit(_current_event, _selected_choice.id)

	# Animate out
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	await tween.finished

	visible = false
	popup_closed.emit()

## Allow keyboard shortcuts for choices
func _input(event: InputEvent):
	if not visible or _showing_consequence:
		return

	if event is InputEventKey and event.pressed:
		var key = event.keycode
		if key == KEY_A or key == KEY_1:
			_select_choice_by_id("a")
		elif key == KEY_B or key == KEY_2:
			_select_choice_by_id("b")
		elif key == KEY_C or key == KEY_3:
			_select_choice_by_id("c")

func _select_choice_by_id(id: String):
	for choice in _current_event.choices:
		if choice.id == id:
			_on_choice_pressed(choice)
			return
