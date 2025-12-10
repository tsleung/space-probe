extends Control

## Game Over / Mission Complete Screen

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var grade_label: Label = $VBoxContainer/GradeLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var stats_label: RichTextLabel = $VBoxContainer/StatsLabel
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton

func _ready():
	_display_results()
	new_game_button.pressed.connect(_on_new_game)
	main_menu_button.pressed.connect(_on_main_menu)

func _display_results():
	var state = GameStore.get_state()
	var score = MarsLogic.calc_mission_score(state)
	var mission_check = MarsLogic.check_mission_complete(state)

	var crew = state.get("crew", [])
	var alive_count = 0
	for member in crew:
		if member.health > 0:
			alive_count += 1

	# Determine title based on outcome
	if alive_count == 0:
		title_label.text = "MISSION FAILED"
		title_label.modulate = Color.RED
	elif not mission_check.mission_success:
		title_label.text = "MISSION PARTIAL SUCCESS"
		title_label.modulate = Color.YELLOW
	else:
		title_label.text = "MISSION SUCCESS!"
		title_label.modulate = Color.GREEN

	# Grade
	grade_label.text = "Grade: %s" % score.grade
	match score.grade:
		"A": grade_label.modulate = Color.GREEN
		"B": grade_label.modulate = Color.CYAN
		"C": grade_label.modulate = Color.YELLOW
		"D": grade_label.modulate = Color.ORANGE
		_: grade_label.modulate = Color.RED

	score_label.text = "Final Score: %d" % score.score

	# Detailed stats
	var stats = "[b]Mission Statistics[/b]\n\n"
	stats += "Total Mission Days: %d\n" % state.current_day
	stats += "Budget Spent: $%s\n\n" % _format_money(state.total_spent)

	stats += "[b]Crew[/b]\n"
	stats += "Survived: %d / %d\n" % [score.crew_alive, crew.size()]
	stats += "Healthy at End: %d\n\n" % score.crew_healthy

	stats += "[b]Science[/b]\n"
	stats += "Experiments Completed: %d\n" % score.experiments
	stats += "Samples Collected: %d\n\n" % score.samples

	var samples = state.get("samples_collected", {})
	stats += "[b]Sample Breakdown[/b]\n"
	stats += "  Soil: %d\n" % samples.get("soil", 0)
	stats += "  Ice: %d\n" % samples.get("ice", 0)
	stats += "  Atmosphere: %d\n" % samples.get("atmosphere", 0)

	stats_label.text = stats

func _format_money(amount: int) -> String:
	if amount >= 1_000_000_000:
		return "%.2fB" % (amount / 1_000_000_000.0)
	elif amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	return str(amount)

func _on_new_game():
	GameStore.start_new_game()
	get_tree().change_scene_to_file("res://scenes/phases/ship_building.tscn")

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
