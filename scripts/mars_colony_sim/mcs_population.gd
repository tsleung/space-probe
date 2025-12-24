extends RefCounted
class_name MCSPopulation

## MCS (Mars Colony Sim) Population Logic
## Pure functions for colonist simulation: aging, birth, death, relationships
## All functions are static and deterministic (random values passed in)

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")

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

# Artificial birth constants (colony-style reproduction)
const GESTATION_CAPACITY_PER_MEDICAL_BAY = 2  # births/year per tier
const GESTATION_CAPACITY_PER_HOSPITAL = 6     # births/year per tier
const GESTATION_SUCCESS_RATE = 0.80           # 80% success rate
const MEDICINE_PER_BIRTH = 5.0                # medicine consumed per birth

# Immigration constants
const IMMIGRATION_PER_STARPORT = 2            # immigrants/year per tier
const IMMIGRATION_PER_SPACE_STATION = 5       # immigrants/year per tier

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
		if old_stage == _MCSTypes.LifeStage.ADOLESCENT and updated.life_stage == _MCSTypes.LifeStage.ADULT:
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
			updated = _MCSTypes.with_fields(updated, {
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
			updated = _MCSTypes.with_field(updated, "pregnancy_months", updated.pregnancy_months + 12)
			if updated.pregnancy_months >= PREGNANCY_MONTHS:
				# Birth!
				var birth_rand = _get_random(random_values, random_idx)
				random_idx += 1
				var child = _create_child(updated, colonists, year, birth_rand)
				births.append(child)
				updated = _MCSTypes.with_fields(updated, {
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
	var new_stage = _MCSTypes._calc_life_stage(new_age)

	var updates = {
		"age": new_age,
		"life_stage": new_stage
	}

	# Stat changes based on age
	if new_stage == _MCSTypes.LifeStage.ELDER:
		# Elders have declining health
		updates["health"] = maxf(0, colonist.health - 2.0 - rand * 3.0)
	elif new_stage == _MCSTypes.LifeStage.CHILD:
		# Children grow healthier (usually)
		updates["health"] = minf(100, colonist.health + 1.0)
		# Children learn faster
		updates["skill_level"] = minf(100, colonist.skill_level + 2.0 + rand * 3.0)

	# Skill growth for working adults
	if new_stage == _MCSTypes.LifeStage.ADULT and colonist.is_working:
		updates["skill_level"] = minf(100, colonist.skill_level + 1.0 + rand * 2.0)

	# Radiation accumulates
	updates["radiation_exposure"] = colonist.radiation_exposure + 0.5 + rand * 0.5

	return _MCSTypes.with_fields(colonist, updates)

static func _check_death(colonist: Dictionary, year: int, rand: float) -> Dictionary:
	var death_chance = 0.0
	var cause = ""

	# Age-based mortality
	if colonist.age >= MAX_AGE:
		death_chance = 1.0
		cause = "old age"
	elif colonist.life_stage == _MCSTypes.LifeStage.ELDER:
		death_chance = ELDER_MORTALITY_BASE * (1.0 + (colonist.age - 60) * 0.05)
		cause = "natural causes"
	elif colonist.life_stage == _MCSTypes.LifeStage.INFANT or colonist.life_stage == _MCSTypes.LifeStage.CHILD:
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
		var spouse_id = colonist.get("spouse_id", "")
		if spouse_id.is_empty():
			updated_colonists.append(updated)
			continue

		# Find spouse
		var spouse = null
		for c in colonists:
			if c.id == spouse_id and c.get("is_alive", false):
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
			updated = _MCSTypes.with_fields(updated, {
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

	var first_name = _generate_first_name(rand)
	var last_name = mother.get("last_name", "Unknown")

	# Generate child
	var child = _MCSTypes.create_colonist({
		"first_name": first_name,
		"last_name": last_name,
		"display_name": "%s %s" % [first_name, last_name],
		"age": 0,
		"birth_year": year,
		"generation": _calc_child_generation(mother, father),
		"life_stage": _MCSTypes.LifeStage.INFANT,
		"health": 70.0 + rand * 20.0,
		"morale": 80.0,
		"fatigue": 10.0,
		"parent_ids": [mother.id],
		"is_founder": false,
		"traits": _inherit_traits(mother, father, rand)
	})

	if father:
		child = _MCSTypes.with_field(child, "parent_ids", [mother.id, father.id])

	return child

static func _calc_child_generation(mother: Dictionary, father: Dictionary) -> _MCSTypes.Generation:
	var parent_gen = mother.generation
	if father:
		parent_gen = maxi(mother.generation, father.generation)

	match parent_gen:
		_MCSTypes.Generation.EARTH_BORN:
			return _MCSTypes.Generation.FIRST_GEN
		_MCSTypes.Generation.FIRST_GEN:
			return _MCSTypes.Generation.SECOND_GEN
		_:
			return _MCSTypes.Generation.THIRD_GEN_PLUS

static func _inherit_traits(mother: Dictionary, father: Dictionary, rand: float) -> Array:
	var traits: Array = []
	var all_parent_traits: Array = mother.get("traits", []).duplicate()
	if father:
		all_parent_traits.append_array(father.get("traits", []))

	# Inherit some parent traits - use deterministic selection based on rand
	var trait_rand = rand
	for t in all_parent_traits:
		trait_rand = fmod(trait_rand * 7.0 + 0.3, 1.0)  # Simple deterministic PRNG
		if trait_rand < TRAIT_INHERITANCE_CHANCE:
			if t not in traits:
				traits.append(t)

	# Chance of new trait (mutation)
	if rand < TRAIT_MUTATION_CHANCE:
		var new_trait = _random_trait(rand)
		if new_trait not in traits:
			traits.append(new_trait)

	# Mars-born children get Mars-adapted trait chance
	if rand < 0.3:
		if _MCSTypes.ColonistTrait.MARS_ADAPTED not in traits:
			traits.append(_MCSTypes.ColonistTrait.MARS_ADAPTED)

	# Limit traits
	while traits.size() > 5:
		traits.pop_back()

	return traits

static func _random_trait(rand: float) -> _MCSTypes.ColonistTrait:
	var trait_values = _MCSTypes.ColonistTrait.values()
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

		updated.append(_MCSTypes.with_field(colonist, "relationships", new_relationships))

	return updated

static func _calc_relationship_drift(a: Dictionary, b: Dictionary, rand: float) -> float:
	var drift = 0.0

	# Compatible traits increase relationships
	var compatibility = _calc_trait_compatibility(a.traits, b.traits)
	drift += compatibility * (rand - 0.5) * 5.0

	# Same faction = bonus
	if a.faction == b.faction and a.faction != _MCSTypes.Faction.NONE:
		drift += 2.0

	# Different faction = friction
	if a.faction != b.faction and a.faction != _MCSTypes.Faction.NONE and b.faction != _MCSTypes.Faction.NONE:
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
		[_MCSTypes.ColonistTrait.OPTIMIST, _MCSTypes.ColonistTrait.PESSIMIST],  # Balance
		[_MCSTypes.ColonistTrait.EXTROVERT, _MCSTypes.ColonistTrait.INTROVERT],  # Some friction
		[_MCSTypes.ColonistTrait.CREATIVE, _MCSTypes.ColonistTrait.METHODICAL],  # Some friction
	]

	# Same traits = good
	for t in traits_a:
		if t in traits_b:
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
		if a.life_stage != _MCSTypes.LifeStage.ADULT:
			continue

		for j in range(i + 1, updated.size()):
			var b = updated[j]
			if not b.is_alive or not b.spouse_id.is_empty():
				continue
			if b.life_stage != _MCSTypes.LifeStage.ADULT:
				continue

			var relationship_a_to_b = a.relationships.get(b.id, 0.0)
			var relationship_b_to_a = b.relationships.get(a.id, 0.0)

			if relationship_a_to_b >= ROMANCE_THRESHOLD and relationship_b_to_a >= ROMANCE_THRESHOLD:
				var rand = _get_random(random_values, random_idx)
				random_idx += 1

				if rand < 0.2:  # 20% chance per year if compatible
					# Marriage!
					updated[i] = _MCSTypes.with_field(a, "spouse_id", b.id)
					updated[j] = _MCSTypes.with_field(b, "spouse_id", a.id)
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
# ARTIFICIAL BIRTHS (Colony-Style Reproduction)
# ============================================================================

## Calculate births based on Medical Bay capacity (not marriage)
## This is the primary birth mechanism - no spouse required
## Returns: { births: Array, events: Array, medicine_consumed: float }
static func calculate_artificial_births(
	colonists: Array,
	buildings: Array,
	resources: Dictionary,
	year: int,
	random_values: Array
) -> Dictionary:
	var births: Array = []
	var events: Array = []
	var random_idx = 0

	# Calculate gestation capacity from medical buildings
	var total_capacity = 0
	for building in buildings:
		if not building.get("is_operational", true):
			continue
		var tier = building.get("tier", 1)
		var b_type = building.get("type", -1)
		# MEDICAL building handles all medical needs (was MEDICAL_BAY + HOSPITAL)
		if b_type == _MCSTypes.BuildingType.MEDICAL:
			# Lower tiers = MEDICAL_BAY equivalent, higher tiers = HOSPITAL equivalent
			if tier <= 2:
				total_capacity += GESTATION_CAPACITY_PER_MEDICAL_BAY * tier
			else:
				total_capacity += GESTATION_CAPACITY_PER_HOSPITAL * tier

	# Check medicine availability
	var available_medicine = resources.get("medicine", 0.0)
	var medicine_limited = int(available_medicine / MEDICINE_PER_BIRTH)
	var max_births = mini(total_capacity, medicine_limited)

	# Need at least 2 adults to provide genetic material
	var adults: Array = []
	for c in colonists:
		if c.is_alive and c.life_stage == _MCSTypes.LifeStage.ADULT:
			adults.append(c)
	if adults.size() < 2:
		return {"births": [], "events": [], "medicine_consumed": 0.0}

	# Generate births based on capacity
	for i in range(max_births):
		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		# Success rate check
		if rand >= GESTATION_SUCCESS_RATE:
			continue

		# Select genetic parents randomly from adults
		var parent1_idx = int(rand * adults.size()) % adults.size()
		var rand2 = _get_random(random_values, random_idx)
		random_idx += 1
		var parent2_idx = (parent1_idx + 1 + int(rand2 * (adults.size() - 1))) % adults.size()

		var parent1 = adults[parent1_idx]
		var parent2 = adults[parent2_idx]

		# Create child
		var child = _create_artificial_child(parent1, parent2, year, rand)
		births.append(child)

		events.append({
			"type": "birth",
			"child_id": child.id,
			"child_name": child.get("display_name", "%s %s" % [child.first_name, child.last_name]),
			"year": year,
			"artificial": true
		})

	return {
		"births": births,
		"events": events,
		"medicine_consumed": births.size() * MEDICINE_PER_BIRTH
	}

## Create a child from artificial reproduction
static func _create_artificial_child(parent1: Dictionary, parent2: Dictionary, year: int, rand: float) -> Dictionary:
	var first_name = _generate_first_name(rand)
	# Use parent1's last name, or generate one
	var last_name = parent1.get("last_name", "Colony")

	var child = _MCSTypes.create_colonist({
		"first_name": first_name,
		"last_name": last_name,
		"display_name": "%s %s" % [first_name, last_name],
		"age": 0,
		"birth_year": year,
		"generation": _calc_child_generation(parent1, parent2),
		"life_stage": _MCSTypes.LifeStage.INFANT,
		"health": 75.0 + rand * 15.0,
		"morale": 80.0,
		"fatigue": 10.0,
		"parent_ids": [parent1.get("id", ""), parent2.get("id", "")],
		"is_founder": false,
		"traits": _inherit_traits(parent1, parent2, rand)
	})

	return child

# ============================================================================
# IMMIGRATION (Starport/Space Station)
# ============================================================================

## Calculate yearly immigration based on infrastructure
## Returns: { immigrants: Array, events: Array }
static func calculate_immigration(
	buildings: Array,
	resources: Dictionary,
	year: int,
	random_values: Array
) -> Dictionary:
	var immigrants: Array = []
	var events: Array = []
	var random_idx = 0

	# Calculate immigration capacity from infrastructure
	var capacity = 0
	for building in buildings:
		if not building.get("is_operational", true):
			continue
		var tier = building.get("tier", 1)
		var b_type = building.get("type", -1)
		if b_type == _MCSTypes.BuildingType.STARPORT:
			capacity += IMMIGRATION_PER_STARPORT * tier
		elif b_type == _MCSTypes.BuildingType.ORBITAL:
			capacity += IMMIGRATION_PER_SPACE_STATION * tier

	if capacity == 0:
		return {"immigrants": [], "events": []}

	# Check if colony can support immigrants (food surplus)
	var food = resources.get("food", 0.0)
	if food < 100 * capacity:
		capacity = capacity / 2  # Reduce immigration if food is low

	# Generate immigrants
	for i in range(capacity):
		var rand = _get_random(random_values, random_idx)
		random_idx += 1

		var immigrant = _create_immigrant(year, rand)
		immigrants.append(immigrant)

		events.append({
			"type": "immigration",
			"colonist_id": immigrant.get("id", ""),
			"colonist_name": immigrant.get("display_name", immigrant.get("first_name", "Unknown")),
			"year": year
		})

	return {
		"immigrants": immigrants,
		"events": events
	}

## Create an immigrant from Earth
static func _create_immigrant(year: int, rand: float) -> Dictionary:
	var age = 20 + int(rand * 25)  # Age 20-45 (working adults)
	var first_name = _generate_first_name(rand)

	# Generate a unique last name for variety
	var last_names = ["Armstrong", "Chen", "Patel", "Kim", "Garcia", "Mueller", "Okonkwo", "Volkov", "Tanaka", "Silva"]
	var last_name = last_names[int(rand * last_names.size()) % last_names.size()]

	return _MCSTypes.create_colonist({
		"first_name": first_name,
		"last_name": last_name,
		"display_name": "%s %s" % [first_name, last_name],
		"age": age,
		"birth_year": year - age,
		"generation": _MCSTypes.Generation.EARTH_BORN,
		"life_stage": _MCSTypes.LifeStage.ADULT,
		"health": 70 + rand * 20,
		"morale": 60 + rand * 20,
		"is_founder": false,
		"traits": _generate_immigrant_traits(rand)
	})

## Generate traits for immigrants (skilled workers from Earth)
static func _generate_immigrant_traits(rand: float) -> Array:
	var traits: Array = []

	# Immigrants are trained - often have useful traits
	var possible_traits = [
		_MCSTypes.ColonistTrait.METHODICAL,
		_MCSTypes.ColonistTrait.PERFECTIONIST,
		_MCSTypes.ColonistTrait.STEADY_HANDS,
		_MCSTypes.ColonistTrait.OPTIMIST,
	]

	# 60% chance of one good trait
	if rand < 0.6:
		var idx = int(rand * possible_traits.size()) % possible_traits.size()
		traits.append(possible_traits[idx])

	# Some immigrants have Earth Longing (homesick)
	if rand > 0.7:
		traits.append(_MCSTypes.ColonistTrait.EARTH_LONGING)

	return traits

# ============================================================================
# MORALE & EFFECTIVENESS
# ============================================================================

## Calculate colonist effectiveness (0.0 - 1.0)
static func calc_effectiveness(colonist: Dictionary) -> float:
	if not colonist.is_alive:
		return 0.0

	if colonist.life_stage == _MCSTypes.LifeStage.INFANT:
		return 0.0
	if colonist.life_stage == _MCSTypes.LifeStage.CHILD:
		return 0.0

	var health_factor = colonist.health / 100.0
	var morale_factor = colonist.morale / 100.0
	var fatigue_factor = (100.0 - colonist.fatigue) / 100.0
	var skill_factor = colonist.skill_level / 100.0

	# Life stage modifier
	var stage_mod = 1.0
	if colonist.life_stage == _MCSTypes.LifeStage.ADOLESCENT:
		stage_mod = 0.6
	elif colonist.life_stage == _MCSTypes.LifeStage.ELDER:
		stage_mod = 0.7

	# Trait modifiers
	var trait_mod = 1.0
	for t in colonist.traits:
		match t:
			_MCSTypes.ColonistTrait.OPTIMIST:
				trait_mod *= 1.1
			_MCSTypes.ColonistTrait.PESSIMIST:
				trait_mod *= 0.95
			_MCSTypes.ColonistTrait.PERFECTIONIST:
				trait_mod *= 1.15
			_MCSTypes.ColonistTrait.STEADY_HANDS:
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
		for t in colonist.traits:
			match t:
				_MCSTypes.ColonistTrait.OPTIMIST:
					morale_change += 2.0
				_MCSTypes.ColonistTrait.PESSIMIST:
					morale_change -= 1.0
				_MCSTypes.ColonistTrait.EARTH_LONGING:
					morale_change -= 1.5
				_MCSTypes.ColonistTrait.MARS_ADAPTED:
					morale_change += 1.0

		# Random variance
		morale_change += (rand - 0.5) * 4.0

		var new_morale = clampf(colonist.morale + morale_change, 0.0, 100.0)
		updated.append(_MCSTypes.with_field(colonist, "morale", new_morale))

	return updated

# ============================================================================
# WORKFORCE
# ============================================================================

## Get all working-age colonists who can work
static func get_workforce(colonists: Array) -> Array:
	var workers: Array = []
	for colonist in colonists:
		if not colonist.is_alive:
			continue
		if colonist.life_stage != _MCSTypes.LifeStage.ADULT:
			continue
		if colonist.health >= 40:
			workers.append(colonist)
	return workers

## Get counts of available workers by specialty
static func get_workforce_summary(colonists: Array) -> Dictionary:
	var summary = {
		"total_working_age": 0,
		"total_available": 0,
		"by_specialty": {}
	}

	for spec in _MCSTypes.Specialty.values():
		summary.by_specialty[spec] = 0

	for colonist in colonists:
		if not colonist.is_alive:
			continue
		if colonist.life_stage != _MCSTypes.LifeStage.ADULT:
			continue

		summary.total_working_age += 1

		if colonist.is_working and colonist.health >= 40:
			summary.total_available += 1
			summary.by_specialty[colonist.specialty] = summary.by_specialty.get(colonist.specialty, 0) + 1

	return summary

## Get the best colonist for a job
static func get_best_worker_for_specialty(colonists: Array, specialty: _MCSTypes.Specialty) -> Dictionary:
	var best = {}
	var best_score = -1.0

	for colonist in colonists:
		if not colonist.is_alive or not colonist.is_working:
			continue
		if colonist.life_stage != _MCSTypes.LifeStage.ADULT:
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
		_MCSTypes.Generation.EARTH_BORN: 0,
		_MCSTypes.Generation.FIRST_GEN: 0,
		_MCSTypes.Generation.SECOND_GEN: 0,
		_MCSTypes.Generation.THIRD_GEN_PLUS: 0
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
