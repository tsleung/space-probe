## Validates game data against schemas.
##
## Ensures loaded JSON files are structurally correct before use.
## Returns warnings rather than hard errors for flexibility.
class_name SchemaValidator
extends RefCounted


## Validate a complete game definition
func validate_game(game_data: Dictionary) -> Result:
	var warnings: Array[String] = []

	# Validate manifest
	var manifest_warnings = _validate_manifest(game_data.get("manifest", {}))
	warnings.append_array(manifest_warnings)

	# Validate components
	var components = game_data.get("components", [])
	for i in range(components.size()):
		var comp_warnings = _validate_component(components[i], i)
		warnings.append_array(comp_warnings)

	# Validate engines
	var engines = game_data.get("engines", [])
	for i in range(engines.size()):
		var eng_warnings = _validate_engine(engines[i], i)
		warnings.append_array(eng_warnings)

	# Validate crew roster
	var crew_roster = game_data.get("crew_roster", [])
	for i in range(crew_roster.size()):
		var crew_warnings = _validate_crew(crew_roster[i], i)
		warnings.append_array(crew_warnings)

	# Validate events
	var events = game_data.get("events", {})
	for phase in events:
		for i in range(events[phase].size()):
			var event_warnings = _validate_event(events[phase][i], phase, i)
			warnings.append_array(event_warnings)

	# Validate balance
	var balance_warnings = _validate_balance(game_data.get("balance", {}))
	warnings.append_array(balance_warnings)

	# Check cross-references
	var ref_warnings = _validate_references(game_data)
	warnings.append_array(ref_warnings)

	if warnings.is_empty():
		return Result.ok(game_data)
	else:
		return Result.error(
			"VALIDATION_WARNINGS",
			"Game data has %d validation warnings" % warnings.size(),
			{"warnings": warnings}
		)


## ============================================================================
## MANIFEST VALIDATION
## ============================================================================

func _validate_manifest(manifest: Dictionary) -> Array[String]:
	var warnings: Array[String] = []

	if not manifest.has("id"):
		warnings.append("Manifest missing 'id' field")

	if not manifest.has("name"):
		warnings.append("Manifest missing 'name' field")

	if not manifest.has("version"):
		warnings.append("Manifest missing 'version' field")

	return warnings


## ============================================================================
## COMPONENT VALIDATION
## ============================================================================

func _validate_component(component: Dictionary, index: int) -> Array[String]:
	var warnings: Array[String] = []
	var prefix = "Component[%d]" % index

	# Required fields
	if not component.has("id"):
		warnings.append("%s: missing 'id'" % prefix)
	else:
		prefix = "Component '%s'" % component.id

	if not component.has("name"):
		warnings.append("%s: missing 'name'" % prefix)

	if not component.has("category"):
		warnings.append("%s: missing 'category'" % prefix)

	# Stats validation
	var stats = component.get("stats", {})
	if stats.is_empty():
		warnings.append("%s: missing 'stats'" % prefix)
	else:
		if not stats.has("cost"):
			warnings.append("%s: stats missing 'cost'" % prefix)
		elif stats.cost <= 0:
			warnings.append("%s: cost should be positive" % prefix)

		if stats.has("base_quality"):
			var quality = stats.base_quality
			if quality < 0 or quality > 100:
				warnings.append("%s: base_quality should be 0-100, got %d" % [prefix, quality])

	return warnings


## ============================================================================
## ENGINE VALIDATION
## ============================================================================

func _validate_engine(engine: Dictionary, index: int) -> Array[String]:
	var warnings: Array[String] = []
	var prefix = "Engine[%d]" % index

	if not engine.has("id"):
		warnings.append("%s: missing 'id'" % prefix)
	else:
		prefix = "Engine '%s'" % engine.id

	if not engine.has("name"):
		warnings.append("%s: missing 'name'" % prefix)

	# Engine-specific fields
	var stats = engine.get("stats", {})
	if not stats.has("thrust") and not stats.has("travel_time_modifier"):
		warnings.append("%s: missing thrust or travel_time_modifier" % prefix)

	return warnings


## ============================================================================
## CREW VALIDATION
## ============================================================================

func _validate_crew(crew: Dictionary, index: int) -> Array[String]:
	var warnings: Array[String] = []
	var prefix = "Crew[%d]" % index

	if not crew.has("id"):
		warnings.append("%s: missing 'id'" % prefix)
	else:
		prefix = "Crew '%s'" % crew.id

	if not crew.has("name"):
		warnings.append("%s: missing 'name'" % prefix)

	if not crew.has("role"):
		warnings.append("%s: missing 'role'" % prefix)

	# Stats validation
	var stats = crew.get("stats", {})
	for stat_name in stats:
		var value = stats[stat_name]
		if value is int or value is float:
			if value < 0 or value > 100:
				warnings.append("%s: stat '%s' should be 0-100, got %s" % [prefix, stat_name, value])

	return warnings


## ============================================================================
## EVENT VALIDATION
## ============================================================================

func _validate_event(event: Dictionary, phase: String, index: int) -> Array[String]:
	var warnings: Array[String] = []
	var prefix = "Event[%s][%d]" % [phase, index]

	if not event.has("id"):
		warnings.append("%s: missing 'id'" % prefix)
	else:
		prefix = "Event '%s'" % event.id

	if not event.has("title"):
		warnings.append("%s: missing 'title'" % prefix)

	if not event.has("description"):
		warnings.append("%s: missing 'description'" % prefix)

	# Choices validation
	var choices = event.get("choices", [])
	if choices.is_empty():
		warnings.append("%s: no choices defined" % prefix)
	else:
		for i in range(choices.size()):
			var choice_warnings = _validate_choice(choices[i], prefix, i)
			warnings.append_array(choice_warnings)

	return warnings


func _validate_choice(choice: Dictionary, event_prefix: String, index: int) -> Array[String]:
	var warnings: Array[String] = []
	var prefix = "%s choice[%d]" % [event_prefix, index]

	if not choice.has("id"):
		warnings.append("%s: missing 'id'" % prefix)

	if not choice.has("text"):
		warnings.append("%s: missing 'text'" % prefix)

	# Outcomes validation
	var outcomes = choice.get("outcomes", [])
	if outcomes.is_empty():
		warnings.append("%s: no outcomes defined" % prefix)
	else:
		var total_weight: float = 0.0
		for outcome in outcomes:
			total_weight += outcome.get("weight", outcome.get("probability", 1.0))

		# Check weights sum to approximately 1.0 (or any positive value)
		if total_weight <= 0:
			warnings.append("%s: outcome weights sum to 0" % prefix)

	return warnings


## ============================================================================
## BALANCE VALIDATION
## ============================================================================

func _validate_balance(balance: Dictionary) -> Array[String]:
	var warnings: Array[String] = []

	# Check for expected sections
	var expected_sections = ["difficulty", "phase1", "phase2", "phase3", "phase4", "formulas", "scoring"]
	for section in expected_sections:
		if not balance.has(section):
			warnings.append("Balance: missing '%s' section" % section)

	# Validate difficulty multipliers
	var difficulty = balance.get("difficulty", {})
	for diff_name in difficulty:
		var diff = difficulty[diff_name]
		if diff is Dictionary:
			for key in diff:
				var value = diff[key]
				if value is float or value is int:
					if key.ends_with("_multiplier") and value <= 0:
						warnings.append("Balance: %s.%s should be positive" % [diff_name, key])

	return warnings


## ============================================================================
## CROSS-REFERENCE VALIDATION
## ============================================================================

func _validate_references(game_data: Dictionary) -> Array[String]:
	var warnings: Array[String] = []

	# Build ID sets
	var component_ids = _collect_ids(game_data.get("components", []))
	var engine_ids = _collect_ids(game_data.get("engines", []))
	var crew_ids = _collect_ids(game_data.get("crew_roster", []))
	var event_ids = _collect_all_event_ids(game_data.get("events", {}))

	# Check event references
	var events = game_data.get("events", {})
	for phase in events:
		for event in events[phase]:
			# Check trigger_event references
			for choice in event.get("choices", []):
				for outcome in choice.get("outcomes", []):
					for effect in outcome.get("effects", []):
						if effect is Dictionary and effect.get("type") == "trigger_event":
							var ref_id = effect.get("event_id", "")
							if not ref_id.is_empty() and not ref_id in event_ids:
								warnings.append("Event '%s': references unknown event '%s'" % [event.id, ref_id])

			# Check component requirements
			for choice in event.get("choices", []):
				for req in choice.get("requirements", []):
					if req is Dictionary and req.get("type") == "has_component":
						var comp_id = req.get("component_id", "")
						if not comp_id.is_empty() and not comp_id in component_ids:
							warnings.append("Event '%s': references unknown component '%s'" % [event.id, comp_id])

	# Check crew relationships
	for crew in game_data.get("crew_roster", []):
		var relationships = crew.get("relationships", {})
		for other_id in relationships:
			if not other_id in crew_ids:
				warnings.append("Crew '%s': relationship references unknown crew '%s'" % [crew.id, other_id])

	return warnings


func _collect_ids(items: Array) -> Array[String]:
	var ids: Array[String] = []
	for item in items:
		if item.has("id"):
			ids.append(item.id)
	return ids


func _collect_all_event_ids(events: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for phase in events:
		for event in events[phase]:
			if event.has("id"):
				ids.append(event.id)
	return ids
