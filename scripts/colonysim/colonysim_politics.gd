extends RefCounted
class_name ColonySimPolitics

## Colony Sim Political Logic
## Pure functions for government, factions, elections, and political events
## All functions are static and deterministic

# ============================================================================
# CONSTANTS
# ============================================================================

const STABILITY_DECAY_RATE = 2.0  # Per year natural decay
const STABILITY_RECOVERY_RATE = 5.0  # Per year recovery when things are good
const UNREST_THRESHOLD = 30.0
const CRISIS_THRESHOLD = 15.0

const ELECTION_CYCLE_YEARS = 4
const COUNCIL_SIZE_MIN = 5
const COUNCIL_SIZE_MAX = 15

const FACTION_DRIFT_RATE = 2.0
const INDEPENDENCE_GROWTH_BASE = 1.0

# ============================================================================
# FACTION MANAGEMENT
# ============================================================================

## Update faction standings based on conditions and events
## Returns updated politics dictionary
static func update_faction_standings(politics: Dictionary, conditions: Dictionary) -> Dictionary:
	var standings = politics.faction_standings.duplicate()

	# Drift based on conditions
	if conditions.get("earth_contact_lost", false):
		standings[ColonySimTypes.Faction.EARTHERS] -= 5.0
		standings[ColonySimTypes.Faction.MARTIANS] += 5.0

	if conditions.get("self_sufficient", false):
		standings[ColonySimTypes.Faction.MARTIANS] += 2.0
		standings[ColonySimTypes.Faction.VISIONARIES] += 1.0

	if conditions.get("crisis_active", false):
		standings[ColonySimTypes.Faction.PRAGMATISTS] += 3.0

	if conditions.get("recent_discovery", false):
		standings[ColonySimTypes.Faction.FOUNDERS] += 2.0

	if conditions.get("good_earth_relations", false):
		standings[ColonySimTypes.Faction.EARTHERS] += 2.0

	# Clamp all standings
	for faction in standings:
		standings[faction] = clampf(standings[faction], 0.0, 100.0)

	return ColonySimTypes.with_field(politics, "faction_standings", standings)

## Assign faction to a colonist based on their traits and relationships
static func assign_faction(colonist: Dictionary, politics: Dictionary, all_colonists: Array, rand: float) -> ColonySimTypes.Faction:
	var scores: Dictionary = {}

	for faction in ColonySimTypes.Faction.values():
		if faction == ColonySimTypes.Faction.NONE:
			continue
		scores[faction] = politics.faction_standings.get(faction, 50.0) / 100.0

	# Trait influence
	for trait in colonist.traits:
		match trait:
			ColonySimTypes.ColonistTrait.EARTH_LONGING:
				scores[ColonySimTypes.Faction.EARTHERS] += 0.3
			ColonySimTypes.ColonistTrait.MARS_ADAPTED:
				scores[ColonySimTypes.Faction.MARTIANS] += 0.3
			ColonySimTypes.ColonistTrait.VISIONARY:
				scores[ColonySimTypes.Faction.VISIONARIES] += 0.3
			ColonySimTypes.ColonistTrait.PRAGMATIST:
				scores[ColonySimTypes.Faction.PRAGMATISTS] += 0.3
			ColonySimTypes.ColonistTrait.FOUNDERS_BLOOD:
				scores[ColonySimTypes.Faction.FOUNDERS] += 0.3

	# Generation influence
	match colonist.generation:
		ColonySimTypes.Generation.EARTH_BORN:
			scores[ColonySimTypes.Faction.EARTHERS] += 0.2
			scores[ColonySimTypes.Faction.FOUNDERS] += 0.1
		ColonySimTypes.Generation.FIRST_GEN:
			scores[ColonySimTypes.Faction.MARTIANS] += 0.1
		ColonySimTypes.Generation.SECOND_GEN, ColonySimTypes.Generation.THIRD_GEN_PLUS:
			scores[ColonySimTypes.Faction.MARTIANS] += 0.3
			scores[ColonySimTypes.Faction.EARTHERS] -= 0.2

	# Founder status
	if colonist.is_founder:
		scores[ColonySimTypes.Faction.FOUNDERS] += 0.4

	# Family influence
	for parent_id in colonist.parent_ids:
		var parent = ColonySimPopulation.find_colonist_by_id(all_colonists, parent_id)
		if not parent.is_empty() and parent.faction != ColonySimTypes.Faction.NONE:
			scores[parent.faction] = scores.get(parent.faction, 0.0) + 0.2

	# Add randomness
	for faction in scores:
		scores[faction] += (rand - 0.5) * 0.3

	# Find highest score
	var best_faction = ColonySimTypes.Faction.NONE
	var best_score = 0.0

	for faction in scores:
		if scores[faction] > best_score:
			best_score = scores[faction]
			best_faction = faction

	# Threshold to actually join a faction
	if best_score < 0.4:
		return ColonySimTypes.Faction.NONE

	return best_faction

## Update colonist faction affiliations
static func update_colonist_factions(colonists: Array, politics: Dictionary, random_values: Array) -> Array:
	var updated: Array = []
	var random_idx = 0

	for colonist in colonists:
		if not colonist.is_alive:
			updated.append(colonist)
			continue

		# Children don't have factions
		if colonist.life_stage == ColonySimTypes.LifeStage.CHILD or colonist.life_stage == ColonySimTypes.LifeStage.INFANT:
			updated.append(colonist)
			continue

		# Only update faction occasionally (10% chance per year) or if no faction
		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		if colonist.faction == ColonySimTypes.Faction.NONE or rand < 0.1:
			var new_faction = assign_faction(colonist, politics, colonists, rand)
			updated.append(ColonySimTypes.with_field(colonist, "faction", new_faction))
		else:
			updated.append(colonist)

	return updated

# ============================================================================
# STABILITY
# ============================================================================

## Calculate stability change for the year
static func calc_stability_change(politics: Dictionary, conditions: Dictionary, colonists: Array) -> float:
	var change = 0.0

	# Governance legitimacy
	if politics.system >= ColonySimTypes.PoliticalSystem.REPRESENTATIVE:
		change += 2.0  # Democracy bonus
	elif politics.system == ColonySimTypes.PoliticalSystem.MISSION_COMMAND:
		if politics.authority_level > 8:
			change -= 1.0  # Autocracy penalty grows over time

	# Resource conditions
	if conditions.get("food_sufficient", true):
		change += 1.0
	else:
		change -= 5.0

	if conditions.get("housing_sufficient", true):
		change += 0.5
	else:
		change -= 3.0

	# Population morale
	var avg_morale = _calc_average_morale(colonists)
	if avg_morale >= 70:
		change += 2.0
	elif avg_morale >= 50:
		change += 0.5
	elif avg_morale >= 30:
		change -= 2.0
	else:
		change -= 5.0

	# Faction conflict
	var faction_spread = _calc_faction_spread(politics.faction_standings)
	if faction_spread > 40:
		change -= 2.0  # High disagreement

	# Recent events
	if conditions.get("recent_election", false):
		change += 3.0  # Elections stabilize
	if conditions.get("recent_crisis", false):
		change -= 3.0
	if conditions.get("recent_death_leader", false):
		change -= 5.0

	return change

## Update political stability
static func update_stability(politics: Dictionary, change: float) -> Dictionary:
	var new_stability = clampf(politics.stability + change, 0.0, 100.0)
	return ColonySimTypes.with_field(politics, "stability", new_stability)

static func _calc_average_morale(colonists: Array) -> float:
	var total = 0.0
	var count = 0

	for c in colonists:
		if c.is_alive and c.life_stage == ColonySimTypes.LifeStage.ADULT:
			total += c.morale
			count += 1

	return total / maxf(count, 1.0)

static func _calc_faction_spread(standings: Dictionary) -> float:
	var values: Array = []
	for faction in standings:
		values.append(standings[faction])

	if values.size() < 2:
		return 0.0

	var max_val = values.max()
	var min_val = values.min()

	return max_val - min_val

# ============================================================================
# ELECTIONS
# ============================================================================

## Check if an election should occur this year
static func should_hold_election(politics: Dictionary, year: int) -> bool:
	if politics.system < ColonySimTypes.PoliticalSystem.ADVISORY_COUNCIL:
		return false

	if politics.next_election_year <= 0:
		return false

	return year >= politics.next_election_year

## Hold an election
## Returns: { politics: Dictionary, events: Array, winner: Dictionary }
static func hold_election(politics: Dictionary, colonists: Array, year: int, random_values: Array) -> Dictionary:
	var events: Array = []
	var random_idx = 0

	# Get candidates
	var candidates = _get_candidates(colonists)
	if candidates.size() < 2:
		return {
			"politics": politics,
			"events": [{
				"type": "election_cancelled",
				"reason": "Not enough candidates"
			}],
			"winner": {}
		}

	# Calculate votes for each candidate
	var votes: Dictionary = {}
	for candidate in candidates:
		votes[candidate.id] = 0

	var voters = colonists.filter(func(c):
		return c.is_alive and c.life_stage == ColonySimTypes.LifeStage.ADULT
	)

	for voter in voters:
		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var best_candidate = _vote_for_candidate(voter, candidates, rand)
		if best_candidate:
			votes[best_candidate.id] = votes.get(best_candidate.id, 0) + 1

	# Find winner
	var winner = {}
	var max_votes = 0
	for candidate in candidates:
		if votes[candidate.id] > max_votes:
			max_votes = votes[candidate.id]
			winner = candidate

	# Build new council
	candidates.sort_custom(func(a, b): return votes[a.id] > votes[b.id])
	var council_size = mini(politics.council_size, candidates.size())
	var new_council: Array = []
	for i in range(council_size):
		new_council.append(candidates[i].id)

	# Update politics
	var new_politics = ColonySimTypes.with_fields(politics, {
		"current_council": new_council,
		"next_election_year": year + politics.election_cycle_years
	})

	# Stability boost from election
	new_politics = update_stability(new_politics, 5.0)

	events.append({
		"type": "election_result",
		"winner_id": winner.id,
		"winner_name": "%s %s" % [winner.first_name, winner.last_name],
		"vote_count": max_votes,
		"total_voters": voters.size(),
		"council": new_council,
		"year": year
	})

	return {
		"politics": new_politics,
		"events": events,
		"winner": winner
	}

static func _get_candidates(colonists: Array) -> Array:
	var candidates: Array = []

	for c in colonists:
		if not c.is_alive:
			continue
		if c.life_stage != ColonySimTypes.LifeStage.ADULT:
			continue
		if c.health < 50:
			continue

		# Leadership qualities
		var score = ColonySimPopulation.calc_effectiveness(c)
		score += c.skill_level / 100.0

		# Traits that make good leaders
		for trait in c.traits:
			if trait in [ColonySimTypes.ColonistTrait.OPTIMIST, ColonySimTypes.ColonistTrait.EMPATHETIC, ColonySimTypes.ColonistTrait.STEADY_HANDS]:
				score += 0.2

		if score > 0.6:  # Threshold for candidacy
			candidates.append(c)

	# Limit to top candidates
	candidates.sort_custom(func(a, b):
		return ColonySimPopulation.calc_effectiveness(a) > ColonySimPopulation.calc_effectiveness(b)
	)

	return candidates.slice(0, 10)

static func _vote_for_candidate(voter: Dictionary, candidates: Array, rand: float) -> Dictionary:
	var scores: Dictionary = {}

	for candidate in candidates:
		var score = 0.0

		# Same faction bonus
		if voter.faction == candidate.faction and voter.faction != ColonySimTypes.Faction.NONE:
			score += 0.4

		# Relationship
		var relationship = voter.relationships.get(candidate.id, 0.0)
		score += relationship / 200.0  # -0.5 to 0.5

		# Competence
		score += ColonySimPopulation.calc_effectiveness(candidate) * 0.3

		# Founder bonus (early years)
		if candidate.is_founder:
			score += 0.1

		# Random factor
		score += (rand - 0.5) * 0.2

		scores[candidate.id] = score

	# Find best
	var best = null
	var best_score = -999.0
	for candidate in candidates:
		if scores[candidate.id] > best_score:
			best_score = scores[candidate.id]
			best = candidate

	return best

# ============================================================================
# POLITICAL EVOLUTION
# ============================================================================

## Check if political system should evolve
## Returns: { politics: Dictionary, events: Array }
static func check_political_evolution(politics: Dictionary, colonists: Array, year: int) -> Dictionary:
	var events: Array = []
	var new_politics = politics

	var population = ColonySimPopulation.count_alive(colonists)

	# Evolution triggers
	match politics.system:
		ColonySimTypes.PoliticalSystem.MISSION_COMMAND:
			# Evolve to council after Year 5 or population > 25
			if year >= 6 and population > 20:
				if politics.stability > 40:
					new_politics = ColonySimTypes.with_fields(new_politics, {
						"system": ColonySimTypes.PoliticalSystem.ADVISORY_COUNCIL,
						"council_size": COUNCIL_SIZE_MIN,
						"next_election_year": year + 2
					})
					events.append({
						"type": "political_evolution",
						"new_system": "Advisory Council",
						"year": year
					})

		ColonySimTypes.PoliticalSystem.ADVISORY_COUNCIL:
			# Evolve to representative after Year 15 or population > 75
			if year >= 16 and population > 60:
				if politics.stability > 50:
					new_politics = ColonySimTypes.with_fields(new_politics, {
						"system": ColonySimTypes.PoliticalSystem.REPRESENTATIVE,
						"authority_level": 5
					})
					events.append({
						"type": "political_evolution",
						"new_system": "Representative Government",
						"year": year
					})

		ColonySimTypes.PoliticalSystem.REPRESENTATIVE:
			# Evolve to constitutional after Year 30
			if year >= 31 and population > 200:
				if politics.stability > 60:
					new_politics = ColonySimTypes.with_fields(new_politics, {
						"system": ColonySimTypes.PoliticalSystem.CONSTITUTIONAL
					})
					events.append({
						"type": "political_evolution",
						"new_system": "Constitutional Government",
						"year": year
					})

	return {
		"politics": new_politics,
		"events": events
	}

# ============================================================================
# INDEPENDENCE
# ============================================================================

## Update independence sentiment
static func update_independence_sentiment(politics: Dictionary, conditions: Dictionary, colonists: Array) -> Dictionary:
	var sentiment = politics.independence_sentiment
	var change = 0.0

	# Generation influence
	var gen_counts = ColonySimPopulation.count_by_generation(colonists)
	var total = ColonySimPopulation.count_alive(colonists)
	if total > 0:
		var mars_born_ratio = float(gen_counts[ColonySimTypes.Generation.FIRST_GEN] +
									gen_counts[ColonySimTypes.Generation.SECOND_GEN] +
									gen_counts[ColonySimTypes.Generation.THIRD_GEN_PLUS]) / float(total)
		change += mars_born_ratio * 2.0  # Mars-born push for independence

	# Self-sufficiency
	if conditions.get("self_sufficient", false):
		change += 2.0

	# Earth relations
	if conditions.get("earth_contact_lost", false):
		change += 10.0
	elif conditions.get("poor_earth_relations", false):
		change += 3.0
	elif conditions.get("good_earth_relations", false):
		change -= 1.0

	# Faction influence
	var martian_standing = politics.faction_standings.get(ColonySimTypes.Faction.MARTIANS, 50.0)
	var earther_standing = politics.faction_standings.get(ColonySimTypes.Faction.EARTHERS, 50.0)
	change += (martian_standing - earther_standing) / 50.0

	sentiment = clampf(sentiment + change, 0.0, 100.0)

	return ColonySimTypes.with_field(politics, "independence_sentiment", sentiment)

## Check if independence vote should occur
static func should_independence_vote(politics: Dictionary, conditions: Dictionary) -> bool:
	if politics.independence_declared:
		return false

	if politics.independence_sentiment < 60:
		return false

	if not conditions.get("self_sufficient", false):
		return false

	return true

## Hold independence vote
## Returns: { politics: Dictionary, events: Array, passed: bool }
static func hold_independence_vote(politics: Dictionary, colonists: Array, year: int, random_values: Array) -> Dictionary:
	var events: Array = []
	var random_idx = 0

	var yes_votes = 0
	var no_votes = 0

	var voters = colonists.filter(func(c):
		return c.is_alive and c.life_stage == ColonySimTypes.LifeStage.ADULT
	)

	for voter in voters:
		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var vote_yes_chance = 0.5

		# Faction influence
		if voter.faction == ColonySimTypes.Faction.MARTIANS:
			vote_yes_chance += 0.3
		elif voter.faction == ColonySimTypes.Faction.EARTHERS:
			vote_yes_chance -= 0.3
		elif voter.faction == ColonySimTypes.Faction.VISIONARIES:
			vote_yes_chance += 0.2

		# Generation influence
		if voter.generation in [ColonySimTypes.Generation.SECOND_GEN, ColonySimTypes.Generation.THIRD_GEN_PLUS]:
			vote_yes_chance += 0.2
		elif voter.generation == ColonySimTypes.Generation.EARTH_BORN:
			vote_yes_chance -= 0.1

		# Sentiment influence
		vote_yes_chance += (politics.independence_sentiment - 50) / 100.0

		vote_yes_chance = clampf(vote_yes_chance, 0.1, 0.9)

		if rand < vote_yes_chance:
			yes_votes += 1
		else:
			no_votes += 1

	var total_votes = yes_votes + no_votes
	var yes_percentage = float(yes_votes) / maxf(float(total_votes), 1.0) * 100.0
	var passed = yes_percentage > 50.0

	var new_politics = politics
	if passed:
		new_politics = ColonySimTypes.with_fields(new_politics, {
			"independence_declared": true,
			"independence_year": year,
			"system": ColonySimTypes.PoliticalSystem.INDEPENDENT_STATE
		})

	events.append({
		"type": "independence_vote",
		"yes_votes": yes_votes,
		"no_votes": no_votes,
		"yes_percentage": yes_percentage,
		"passed": passed,
		"year": year
	})

	return {
		"politics": new_politics,
		"events": events,
		"passed": passed
	}

# ============================================================================
# POLICIES
# ============================================================================

## Apply policy effects to colonists
## Returns updated colonists
static func apply_policy_effects(colonists: Array, policies: Dictionary) -> Array:
	var updated: Array = []

	for colonist in colonists:
		if not colonist.is_alive:
			updated.append(colonist)
			continue

		var morale_mod = 0.0

		# Food rationing
		var rationing = policies.get("food_rationing", 1.0)
		if rationing < 0.8:
			morale_mod -= 10.0
		elif rationing < 1.0:
			morale_mod -= 3.0
		elif rationing > 1.1:
			morale_mod += 3.0

		# Work hours
		var work_hours = policies.get("work_hours", 45)
		if work_hours > 55:
			morale_mod -= 8.0
		elif work_hours > 50:
			morale_mod -= 3.0
		elif work_hours < 35:
			morale_mod += 3.0

		var new_morale = clampf(colonist.morale + morale_mod, 0.0, 100.0)
		updated.append(ColonySimTypes.with_field(colonist, "morale", new_morale))

	return updated

## Set a policy value
static func set_policy(politics: Dictionary, policy_name: String, value) -> Dictionary:
	var new_policies = politics.policies.duplicate()
	new_policies[policy_name] = value
	return ColonySimTypes.with_field(politics, "policies", new_policies)

# ============================================================================
# HELPERS
# ============================================================================

static func _get_random(arr: Array, idx: int) -> float:
	if idx < arr.size():
		return arr[idx]
	return 0.5

static func get_system_name(system: ColonySimTypes.PoliticalSystem) -> String:
	match system:
		ColonySimTypes.PoliticalSystem.MISSION_COMMAND:
			return "Mission Command"
		ColonySimTypes.PoliticalSystem.ADVISORY_COUNCIL:
			return "Advisory Council"
		ColonySimTypes.PoliticalSystem.REPRESENTATIVE:
			return "Representative Government"
		ColonySimTypes.PoliticalSystem.CONSTITUTIONAL:
			return "Constitutional Government"
		ColonySimTypes.PoliticalSystem.INDEPENDENT_STATE:
			return "Independent State"
	return "Unknown"
