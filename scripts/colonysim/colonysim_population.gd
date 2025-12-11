extends RefCounted
class_name ColonySimPopulation

## Colony Sim Population Logic
## Pure functions for colonist simulation: aging, birth, death, relationships
## All functions are static and deterministic (random values passed in)

# ============================================================================
# CONSTANTS
# ============================================================================

const BASE_FERTILITY_RATE = 0.025  # 2.5% of fertile women per year
const FERTILE_AGE_MIN = 18
const FERTILE_AGE_MAX = 45
const CHILD_MORTALITY_RATE = 0.01  # 1% per year in harsh conditions
const ELDER_MORTALITY_BASE = 0.02  # 2% per year at 61, increases
const MAX_AGE = 95
const PREGNANCY_MONTHS = 9

# Trait inheritance chances
const TRAIT_INHERITANCE_CHANCE = 0.3
const TRAIT_MUTATION_CHANCE = 0.1

# Relationship thresholds
const ROMANCE_THRESHOLD = 70
const FRIEND_THRESHOLD = 50
const RIVAL_THRESHOLD = -30

# ============================================================================
# AGING & LIFE CYCLE
# ============================================================================

## Advance all colonists by one year
## Returns: { colonists: Array, births: Array, deaths: Array, events: Array, new_adults: Array }
static func advance_year(colonists: Array, year: int, resources: Dictionary, buildings: Array, random_values: Array) -> Dictionary:
	var new_colonists: Array = []
	var births: Array = []
	var deaths: Array = []
	var events: Array = []
	var new_adults: Array = []
	var random_idx = 0

	# Process each colonist
	for colonist in colonists:
		if not colonist.is_alive:
			new_colonists.append(colonist)
			continue

		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var old_stage = colonist.life_stage
		var updated = _age_colonist(colonist, year, rand)

		# Check for coming of age (adolescent -> adult)
		if old_stage == ColonySimTypes.LifeStage.ADOLESCENT and updated.life_stage == ColonySimTypes.LifeStage.ADULT:
			new_adults.append(updated)
			events.append({
				"type": "coming_of_age",
				"colonist_id": updated.id,
				"colonist_name": updated.get("display_name", "%s %s" % [updated.first_name, updated.last_name]),
				"age": updated.age
			})

		# Check for death
		var death_rand = _get_random(random_values, random_idx)
		random_idx += 1
		var death_result = _check_death(updated, year, death_rand)

		if death_result.died:
			updated = ColonySimTypes.with_fields(updated, {
				"is_alive": false,
				"death_year": year,
				"death_cause": death_result.cause
			})
			deaths.append({
				"colonist": updated,
				"name": updated.get("display_name", "%s %s" % [updated.first_name, updated.last_name]),
				"cause": death_result.cause,
				"year": year
			})
			events.append({
				"type": "death",
				"colonist_id": updated.id,
				"colonist_name": updated.get("display_name", "%s %s" % [updated.first_name, updated.last_name]),
				"cause": death_result.cause,
				"age": updated.age
			})

		# Check for pregnancy progression
		if updated.is_pregnant:
			updated = ColonySimTypes.with_field(updated, "pregnancy_months", updated.pregnancy_months + 12)
			if updated.pregnancy_months >= PREGNANCY_MONTHS:
				# Birth!
				var birth_rand = _get_random(random_values, random_idx)
				random_idx += 1
				var child = _create_child(updated, colonists, year, birth_rand)
				births.append(child)
				updated = ColonySimTypes.with_fields(updated, {
					"is_pregnant": false,
					"pregnancy_months": 0,
					"child_ids": updated.child_ids + [child.id]
				})
				events.append({
					"type": "birth",
					"child_id": child.id,
					"child_name": child.get("display_name", "%s %s" % [child.first_name, child.last_name]),
					"mother_id": updated.id,
					"mother_name": updated.get("display_name", "%s %s" % [updated.first_name, updated.last_name]),
					"year": year
				})

		new_colonists.append(updated)

	# Add newborns to population
	new_colonists.append_array(births)

	# Check for new pregnancies
	var pregnancy_result = _check_pregnancies(new_colonists, year, random_values.slice(random_idx))
	new_colonists = pregnancy_result.colonists
	events.append_array(pregnancy_result.events)

	return {
		"colonists": new_colonists,
		"births": births,
		"deaths": deaths,
		"events": events,
		"new_adults": new_adults
	}

static func _age_colonist(colonist: Dictionary, year: int, rand: float) -> Dictionary:
	var new_age = colonist.age + 1
	var new_stage = ColonySimTypes._calc_life_stage(new_age)

	var updates = {
		"age": new_age,
		"life_stage": new_stage
	}

	# Stat changes based on age
	if new_stage == ColonySimTypes.LifeStage.ELDER:
		# Elders have declining health
		updates["health"] = maxf(0, colonist.health - 2.0 - rand * 3.0)
	elif new_stage == ColonySimTypes.LifeStage.CHILD:
		# Children grow healthier (usually)
		updates["health"] = minf(100, colonist.health + 1.0)
		# Children learn faster
		updates["skill_level"] = minf(100, colonist.skill_level + 2.0 + rand * 3.0)

	# Skill growth for working adults
	if new_stage == ColonySimTypes.LifeStage.ADULT and colonist.is_working:
		updates["skill_level"] = minf(100, colonist.skill_level + 1.0 + rand * 2.0)

	# Radiation accumulates
	updates["radiation_exposure"] = colonist.radiation_exposure + 0.5 + rand * 0.5

	return ColonySimTypes.with_fields(colonist, updates)

static func _check_death(colonist: Dictionary, year: int, rand: float) -> Dictionary:
	var death_chance = 0.0
	var cause = ""

	# Age-based mortality
	if colonist.age >= MAX_AGE:
		death_chance = 1.0
		cause = "old age"
	elif colonist.life_stage == ColonySimTypes.LifeStage.ELDER:
		death_chance = ELDER_MORTALITY_BASE * (1.0 + (colonist.age - 60) * 0.05)
		cause = "natural causes"
	elif colonist.life_stage == ColonySimTypes.LifeStage.INFANT or colonist.life_stage == ColonySimTypes.LifeStage.CHILD:
		death_chance = CHILD_MORTALITY_RATE
		cause = "childhood illness"

	# Health-based mortality
	if colonist.health < 20:
		death_chance += 0.3
		cause = "declining health"
	elif colonist.health < 40:
		death_chance += 0.1

	# Radiation-based mortality
	if colonist.radiation_exposure > 80:
		death_chance += 0.2
		cause = "radiation exposure"
	elif colonist.radiation_exposure > 60:
		death_chance += 0.05

	return {
		"died": rand < death_chance,
		"cause": cause
	}

static func _check_pregnancies(colonists: Array, year: int, random_values: Array) -> Dictionary:
	var updated_colonists: Array = []
	var events: Array = []
	var random_idx = 0

	for colonist in colonists:
		var updated = colonist

		# Skip if already pregnant, dead, or not fertile
		if colonist.is_pregnant or not colonist.is_alive:
			updated_colonists.append(updated)
			continue

		if colonist.age < FERTILE_AGE_MIN or colonist.age > FERTILE_AGE_MAX:
			updated_colonists.append(updated)
			continue

		# Need to identify by checking if they could be a mother (simplified)
		# In a real implementation, you'd track sex/gender
		# For now, use a proxy: 50% of adults can become pregnant
		var rand1 = _get_random(random_values, random_idx)
		random_idx += 1

		if rand1 > 0.5:  # Not a potential mother this year
			updated_colonists.append(updated)
			continue

		# Check if has spouse
		if colonist.spouse_id.is_empty():
			updated_colonists.append(updated)
			continue

		# Find spouse
		var spouse = null
		for c in colonists:
			if c.id == colonist.spouse_id and c.is_alive:
				spouse = c
				break

		if spouse == null:
			updated_colonists.append(updated)
			continue

		# Calculate fertility
		var fertility_chance = BASE_FERTILITY_RATE
		fertility_chance *= _calc_health_fertility_modifier(colonist.health)
		fertility_chance *= _calc_morale_fertility_modifier(colonist.morale)
		fertility_chance *= _calc_age_fertility_modifier(colonist.age)

		var rand2 = _get_random(random_values, random_idx)
		random_idx += 1

		if rand2 < fertility_chance:
			updated = ColonySimTypes.with_fields(updated, {
				"is_pregnant": true,
				"pregnancy_months": 0
			})
			events.append({
				"type": "pregnancy",
				"colonist_id": updated.id,
				"colonist_name": "%s %s" % [updated.first_name, updated.last_name],
				"year": year
			})

		updated_colonists.append(updated)

	return {
		"colonists": updated_colonists,
		"events": events
	}

static func _calc_health_fertility_modifier(health: float) -> float:
	if health >= 80:
		return 1.2
	elif health >= 60:
		return 1.0
	elif health >= 40:
		return 0.7
	else:
		return 0.3

static func _calc_morale_fertility_modifier(morale: float) -> float:
	if morale >= 70:
		return 1.1
	elif morale >= 50:
		return 1.0
	elif morale >= 30:
		return 0.8
	else:
		return 0.5

static func _calc_age_fertility_modifier(age: int) -> float:
	if age >= 20 and age <= 30:
		return 1.2
	elif age >= 31 and age <= 35:
		return 1.0
	elif age >= 36 and age <= 40:
		return 0.7
	else:
		return 0.4

# ============================================================================
# BIRTH & CHILD CREATION
# ============================================================================

static func _create_child(mother: Dictionary, all_colonists: Array, year: int, rand: float) -> Dictionary:
	# Find father (spouse)
	var father = null
	for c in all_colonists:
		if c.id == mother.spouse_id:
			father = c
			break

	# Generate child
	var child = ColonySimTypes.create_colonist({
		"first_name": _generate_first_name(rand),
		"last_name": mother.last_name,  # Simplified: mother's last name
		"age": 0,
		"birth_year": year,
		"generation": _calc_child_generation(mother, father),
		"life_stage": ColonySimTypes.LifeStage.INFANT,
		"health": 70.0 + rand * 20.0,
		"morale": 80.0,
		"fatigue": 10.0,
		"parent_ids": [mother.id],
		"is_founder": false,
		"traits": _inherit_traits(mother, father, rand)
	})

	if father:
		child = ColonySimTypes.with_field(child, "parent_ids", [mother.id, father.id])

	return child

static func _calc_child_generation(mother: Dictionary, father: Dictionary) -> ColonySimTypes.Generation:
	var parent_gen = mother.generation
	if father:
		parent_gen = maxi(mother.generation, father.generation)

	match parent_gen:
		ColonySimTypes.Generation.EARTH_BORN:
			return ColonySimTypes.Generation.FIRST_GEN
		ColonySimTypes.Generation.FIRST_GEN:
			return ColonySimTypes.Generation.SECOND_GEN
		_:
			return ColonySimTypes.Generation.THIRD_GEN_PLUS

static func _inherit_traits(mother: Dictionary, father: Dictionary, rand: float) -> Array:
	var traits: Array = []
	var all_parent_traits: Array = mother.traits.duplicate()
	if father:
		all_parent_traits.append_array(father.traits)

	# Inherit some parent traits
	for trait in all_parent_traits:
		if randf() < TRAIT_INHERITANCE_CHANCE:
			if trait not in traits:
				traits.append(trait)

	# Chance of new trait (mutation)
	if rand < TRAIT_MUTATION_CHANCE:
		var new_trait = _random_trait(rand)
		if new_trait not in traits:
			traits.append(new_trait)

	# Mars-born children get Mars-adapted trait chance
	if rand < 0.3:
		if ColonySimTypes.ColonistTrait.MARS_ADAPTED not in traits:
			traits.append(ColonySimTypes.ColonistTrait.MARS_ADAPTED)

	# Limit traits
	while traits.size() > 5:
		traits.pop_back()

	return traits

static func _random_trait(rand: float) -> ColonySimTypes.ColonistTrait:
	var trait_values = ColonySimTypes.ColonistTrait.values()
	var idx = int(rand * trait_values.size()) % trait_values.size()
	return trait_values[idx]

# ============================================================================
# RELATIONSHIPS
# ============================================================================

## Update relationships between colonists
## Returns updated colonists array
static func update_relationships(colonists: Array, year: int, random_values: Array) -> Array:
	var updated: Array = []
	var random_idx = 0

	for colonist in colonists:
		if not colonist.is_alive:
			updated.append(colonist)
			continue

		var new_relationships = colonist.relationships.duplicate()

		for other in colonists:
			if other.id == colonist.id or not other.is_alive:
				continue

			var current = new_relationships.get(other.id, 0.0)
			var rand = _get_random(random_values, random_idx)
			random_idx += 1

			# Relationship drift based on traits
			var drift = _calc_relationship_drift(colonist, other, rand)
			new_relationships[other.id] = clampf(current + drift, -100.0, 100.0)

		updated.append(ColonySimTypes.with_field(colonist, "relationships", new_relationships))

	return updated

static func _calc_relationship_drift(a: Dictionary, b: Dictionary, rand: float) -> float:
	var drift = 0.0

	# Compatible traits increase relationships
	var compatibility = _calc_trait_compatibility(a.traits, b.traits)
	drift += compatibility * (rand - 0.5) * 5.0

	# Same faction = bonus
	if a.faction == b.faction and a.faction != ColonySimTypes.Faction.NONE:
		drift += 2.0

	# Different faction = friction
	if a.faction != b.faction and a.faction != ColonySimTypes.Faction.NONE and b.faction != ColonySimTypes.Faction.NONE:
		drift -= 1.0

	# Family bonds
	if b.id in a.parent_ids or a.id in b.parent_ids:
		drift += 3.0
	if a.spouse_id == b.id:
		drift += 2.0

	return drift

static func _calc_trait_compatibility(traits_a: Array, traits_b: Array) -> float:
	var score = 0.0

	# Complementary traits
	var complementary = [
		[ColonySimTypes.ColonistTrait.OPTIMIST, ColonySimTypes.ColonistTrait.PESSIMIST],  # Balance
		[ColonySimTypes.ColonistTrait.EXTROVERT, ColonySimTypes.ColonistTrait.INTROVERT],  # Some friction
		[ColonySimTypes.ColonistTrait.CREATIVE, ColonySimTypes.ColonistTrait.METHODICAL],  # Some friction
	]

	# Same traits = good
	for trait in traits_a:
		if trait in traits_b:
			score += 1.0

	# Complementary = neutral to slight friction
	for pair in complementary:
		if pair[0] in traits_a and pair[1] in traits_b:
			score -= 0.5
		if pair[1] in traits_a and pair[0] in traits_b:
			score -= 0.5

	return score

## Check for new romance possibilities
## Returns: { colonists: Array, events: Array }
static func check_romance(colonists: Array, year: int, random_values: Array) -> Dictionary:
	var events: Array = []
	var updated = colonists.duplicate(true)
	var random_idx = 0

	for i in range(updated.size()):
		var a = updated[i]
		if not a.is_alive or not a.spouse_id.is_empty():
			continue
		if a.life_stage != ColonySimTypes.LifeStage.ADULT:
			continue

		for j in range(i + 1, updated.size()):
			var b = updated[j]
			if not b.is_alive or not b.spouse_id.is_empty():
				continue
			if b.life_stage != ColonySimTypes.LifeStage.ADULT:
				continue

			var relationship_a_to_b = a.relationships.get(b.id, 0.0)
			var relationship_b_to_a = b.relationships.get(a.id, 0.0)

			if relationship_a_to_b >= ROMANCE_THRESHOLD and relationship_b_to_a >= ROMANCE_THRESHOLD:
				var rand = _get_random(random_values, random_idx)
				random_idx += 1

				if rand < 0.2:  # 20% chance per year if compatible
					# Marriage!
					updated[i] = ColonySimTypes.with_field(a, "spouse_id", b.id)
					updated[j] = ColonySimTypes.with_field(b, "spouse_id", a.id)
					events.append({
						"type": "marriage",
						"colonist_a_id": a.id,
						"colonist_a_name": "%s %s" % [a.first_name, a.last_name],
						"colonist_b_id": b.id,
						"colonist_b_name": "%s %s" % [b.first_name, b.last_name],
						"year": year
					})
					break  # Only one marriage per person per year

	return {
		"colonists": updated,
		"events": events
	}

# ============================================================================
# MORALE & EFFECTIVENESS
# ============================================================================

## Calculate colonist effectiveness (0.0 - 1.0)
static func calc_effectiveness(colonist: Dictionary) -> float:
	if not colonist.is_alive:
		return 0.0

	if colonist.life_stage == ColonySimTypes.LifeStage.INFANT:
		return 0.0
	if colonist.life_stage == ColonySimTypes.LifeStage.CHILD:
		return 0.0

	var health_factor = colonist.health / 100.0
	var morale_factor = colonist.morale / 100.0
	var fatigue_factor = (100.0 - colonist.fatigue) / 100.0
	var skill_factor = colonist.skill_level / 100.0

	# Life stage modifier
	var stage_mod = 1.0
	if colonist.life_stage == ColonySimTypes.LifeStage.ADOLESCENT:
		stage_mod = 0.6
	elif colonist.life_stage == ColonySimTypes.LifeStage.ELDER:
		stage_mod = 0.7

	# Trait modifiers
	var trait_mod = 1.0
	for trait in colonist.traits:
		match trait:
			ColonySimTypes.ColonistTrait.OPTIMIST:
				trait_mod *= 1.1
			ColonySimTypes.ColonistTrait.PESSIMIST:
				trait_mod *= 0.95
			ColonySimTypes.ColonistTrait.PERFECTIONIST:
				trait_mod *= 1.15
			ColonySimTypes.ColonistTrait.STEADY_HANDS:
				trait_mod *= 1.1

	var base = health_factor * 0.3 + morale_factor * 0.3 + fatigue_factor * 0.2 + skill_factor * 0.2
	return clampf(base * stage_mod * trait_mod, 0.0, 1.5)

## Update morale for all colonists based on conditions
## Returns updated colonists array
static func update_morale(colonists: Array, conditions: Dictionary, random_values: Array) -> Array:
	var updated: Array = []
	var random_idx = 0

	for colonist in colonists:
		if not colonist.is_alive:
			updated.append(colonist)
			continue

		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var morale_change = 0.0

		# Base drift toward neutral
		if colonist.morale > 50:
			morale_change -= 0.5
		elif colonist.morale < 50:
			morale_change += 0.5

		# Conditions
		if conditions.get("food_sufficient", true):
			morale_change += 1.0
		else:
			morale_change -= 5.0

		if conditions.get("housing_sufficient", true):
			morale_change += 0.5
		else:
			morale_change -= 3.0

		if conditions.get("recent_death", false):
			morale_change -= 10.0

		if conditions.get("recent_birth", false):
			morale_change += 5.0

		if conditions.get("crisis_active", false):
			morale_change -= 3.0

		# Trait-based morale
		for trait in colonist.traits:
			match trait:
				ColonySimTypes.ColonistTrait.OPTIMIST:
					morale_change += 2.0
				ColonySimTypes.ColonistTrait.PESSIMIST:
					morale_change -= 1.0
				ColonySimTypes.ColonistTrait.EARTH_LONGING:
					morale_change -= 1.5
				ColonySimTypes.ColonistTrait.MARS_ADAPTED:
					morale_change += 1.0

		# Random variance
		morale_change += (rand - 0.5) * 4.0

		var new_morale = clampf(colonist.morale + morale_change, 0.0, 100.0)
		updated.append(ColonySimTypes.with_field(colonist, "morale", new_morale))

	return updated

# ============================================================================
# WORKFORCE
# ============================================================================

## Get counts of available workers by specialty
static func get_workforce_summary(colonists: Array) -> Dictionary:
	var summary = {
		"total_working_age": 0,
		"total_available": 0,
		"by_specialty": {}
	}

	for spec in ColonySimTypes.Specialty.values():
		summary.by_specialty[spec] = 0

	for colonist in colonists:
		if not colonist.is_alive:
			continue
		if colonist.life_stage != ColonySimTypes.LifeStage.ADULT:
			continue

		summary.total_working_age += 1

		if colonist.is_working and colonist.health >= 40:
			summary.total_available += 1
			summary.by_specialty[colonist.specialty] = summary.by_specialty.get(colonist.specialty, 0) + 1

	return summary

## Get the best colonist for a job
static func get_best_worker_for_specialty(colonists: Array, specialty: ColonySimTypes.Specialty) -> Dictionary:
	var best = {}
	var best_score = -1.0

	for colonist in colonists:
		if not colonist.is_alive or not colonist.is_working:
			continue
		if colonist.life_stage != ColonySimTypes.LifeStage.ADULT:
			continue

		var score = calc_effectiveness(colonist)
		if colonist.specialty == specialty:
			score *= 1.5
		elif colonist.secondary_skills.has(specialty):
			score *= (1.0 + colonist.secondary_skills[specialty] / 200.0)

		if score > best_score:
			best_score = score
			best = colonist

	return best

# ============================================================================
# NAME GENERATION (Simple placeholder)
# ============================================================================

const FIRST_NAMES = [
	"Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Quinn", "Avery",
	"Elena", "Marcus", "Sarah", "David", "Maria", "James", "Anna", "Michael",
	"Sofia", "Chen", "Wei", "Yuki", "Amir", "Fatima", "Olga", "Ivan",
	"Priya", "Raj", "Kenji", "Mei", "Lars", "Ingrid", "Hassan", "Zara"
]

static func _generate_first_name(rand: float) -> String:
	var idx = int(rand * FIRST_NAMES.size()) % FIRST_NAMES.size()
	return FIRST_NAMES[idx]

# ============================================================================
# HELPERS
# ============================================================================

static func _get_random(arr: Array, idx: int) -> float:
	if idx < arr.size():
		return arr[idx]
	return 0.5

static func count_alive(colonists: Array) -> int:
	var count = 0
	for c in colonists:
		if c.is_alive:
			count += 1
	return count

static func count_by_generation(colonists: Array) -> Dictionary:
	var counts = {
		ColonySimTypes.Generation.EARTH_BORN: 0,
		ColonySimTypes.Generation.FIRST_GEN: 0,
		ColonySimTypes.Generation.SECOND_GEN: 0,
		ColonySimTypes.Generation.THIRD_GEN_PLUS: 0
	}

	for c in colonists:
		if c.is_alive:
			counts[c.generation] = counts.get(c.generation, 0) + 1

	return counts

static func get_founders(colonists: Array) -> Array:
	var founders: Array = []
	for c in colonists:
		if c.is_founder:
			founders.append(c)
	return founders

static func get_alive_founders(colonists: Array) -> Array:
	var founders: Array = []
	for c in colonists:
		if c.is_founder and c.is_alive:
			founders.append(c)
	return founders

static func find_colonist_by_id(colonists: Array, id: String) -> Dictionary:
	for c in colonists:
		if c.id == id:
			return c
	return {}
