extends Control

## Game Over / Mission Complete Screen
## Shows ending tier, crew fate, and full mission statistics

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var grade_label: Label = $VBoxContainer/GradeLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var stats_label: RichTextLabel = $VBoxContainer/StatsLabel
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton

# Ending tier descriptions
const ENDING_TIERS = {
	"GOLD": {
		"title": "GOLD MISSION",
		"subtitle": "A Historic Achievement",
		"description": "All crew returned safely with full scientific payload. This mission will be remembered for generations.",
		"color": Color(1.0, 0.84, 0.0)
	},
	"SILVER": {
		"title": "SILVER MISSION",
		"subtitle": "Mission Accomplished",
		"description": "The crew made it home with valuable data. Minor setbacks couldn't stop humanity's reach.",
		"color": Color(0.75, 0.75, 0.75)
	},
	"BRONZE": {
		"title": "BRONZE MISSION",
		"subtitle": "Against All Odds",
		"description": "Some made it back. Their sacrifice will advance human knowledge.",
		"color": Color(0.8, 0.5, 0.2)
	},
	"PYRRHIC": {
		"title": "PYRRHIC VICTORY",
		"subtitle": "The Cost Was Too High",
		"description": "The mission succeeded, but at terrible cost. We must do better next time.",
		"color": Color(0.6, 0.4, 0.6)
	},
	"FAILURE": {
		"title": "MISSION LOST",
		"subtitle": "They Will Be Remembered",
		"description": "The mission did not succeed. Their courage will inspire future explorers.",
		"color": Color(0.5, 0.2, 0.2)
	}
}

func _ready():
	_display_results()
	new_game_button.pressed.connect(_on_new_game)
	main_menu_button.pressed.connect(_on_main_menu)

func _display_results():
	var state = GameStore.get_state()
	var score = MarsLogic.calc_mission_score(state)
	var mission_check = MarsLogic.check_mission_complete(state)
	var reentry_results = state.get("reentry_results", {})

	var crew = state.get("crew", [])
	var original_crew_count = crew.size()

	# Count survivors - check reentry results first, then fall back to health
	var survivors = []
	var crew_alive = 0
	if reentry_results.has("crew_survived") and not reentry_results.crew_survived.is_empty():
		survivors = reentry_results.crew_survived
		crew_alive = survivors.size()
	else:
		for member in crew:
			if member.health > 0:
				crew_alive += 1
				survivors.append(member.id)

	# Determine ending tier
	var ending_tier = _calculate_ending_tier(crew_alive, original_crew_count, score, mission_check, reentry_results)
	var tier_info = ENDING_TIERS[ending_tier]

	# Set title based on tier
	title_label.text = tier_info.title
	title_label.modulate = tier_info.color

	# Grade with subtitle
	grade_label.text = tier_info.subtitle
	grade_label.modulate = tier_info.color.lightened(0.3)

	score_label.text = "Final Score: %d" % score.score

	# Build detailed stats
	var stats = ""

	# Tier description
	stats += "[center][i]%s[/i][/center]\n\n" % tier_info.description

	# Crew fate section
	stats += "[b]CREW FATE[/b]\n"
	for member in crew:
		var status_icon = ""
		var status_color = "gray"
		if member.id in survivors:
			status_icon = "RETURNED"
			status_color = "green"
		elif member.health <= 0:
			status_icon = "LOST IN SPACE"
			status_color = "red"
		else:
			# Died during reentry
			status_icon = "LOST AT REENTRY"
			status_color = "orange"
		stats += "[color=%s]  %s - %s[/color]\n" % [status_color, member.display_name, status_icon]

	stats += "\n"

	# Reentry results if available
	if not reentry_results.is_empty():
		stats += "[b]REENTRY SEQUENCE[/b]\n"
		stats += "  Heat Shield: %s\n" % ("[color=green]OK[/color]" if reentry_results.get("heat_shield_success", false) else "[color=red]FAILED[/color]")
		stats += "  Parachutes: %s\n" % ("[color=green]OK[/color]" if reentry_results.get("parachute_success", false) else "[color=red]FAILED[/color]")
		stats += "  Landing: %s\n\n" % ("[color=green]OK[/color]" if reentry_results.get("landing_success", false) else "[color=red]HARD[/color]")

	# Mission stats
	stats += "[b]MISSION STATISTICS[/b]\n"
	stats += "  Total Mission Days: %d\n" % state.current_day
	stats += "  Budget Used: $%s\n" % GameTypes.format_money(state.get("total_spent", 0))
	stats += "  Crew Deaths: %d\n\n" % state.get("crew_deaths", 0)

	# Science results
	stats += "[b]SCIENCE RESULTS[/b]\n"
	stats += "  Experiments: %d completed\n" % score.experiments
	stats += "  Samples: %d collected\n" % score.samples

	var samples = state.get("samples_collected", {})
	if not samples.is_empty():
		stats += "    - Soil: %d\n" % samples.get("soil", 0)
		stats += "    - Ice: %d\n" % samples.get("ice", 0)
		stats += "    - Atmosphere: %d\n" % samples.get("atmosphere", 0)

	stats_label.text = stats

func _calculate_ending_tier(survivors: int, total_crew: int, score: Dictionary, mission_check: Dictionary, reentry_results: Dictionary) -> String:
	# No survivors = FAILURE
	if survivors == 0:
		return "FAILURE"

	# All crew + full mission success = GOLD
	if survivors == total_crew and mission_check.mission_success:
		if reentry_results.get("heat_shield_success", true) and reentry_results.get("parachute_success", true) and reentry_results.get("landing_success", true):
			return "GOLD"
		else:
			return "SILVER"  # Some reentry issues but all survived

	# Most crew + good science = SILVER
	if survivors >= (total_crew - 1) and score.experiments >= 3:
		return "SILVER"

	# Some crew survived + some science = BRONZE
	if survivors >= 1 and (score.experiments >= 1 or score.samples >= 5):
		return "BRONZE"

	# Crew survived but mission was problematic = PYRRHIC
	if survivors >= 1:
		return "PYRRHIC"

	return "FAILURE"

func _on_new_game():
	GameStore.start_new_game()
	get_tree().change_scene_to_file("res://scenes/phases/ship_building.tscn")

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
