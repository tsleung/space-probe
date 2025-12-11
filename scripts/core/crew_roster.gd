class_name CrewRoster
extends RefCounted

## Pre-defined crew members with personalities and backstories
## These make crew feel like real people, not stat bags

# ============================================================================
# CREW DATABASE
# ============================================================================

static func get_available_crew() -> Array:
	return [
		# COMMANDERS
		_create_commander_chen(),
		_create_commander_okonkwo(),

		# PILOTS
		_create_pilot_reyes(),
		_create_pilot_volkov(),

		# ENGINEERS
		_create_engineer_santos(),
		_create_engineer_kim(),

		# SCIENTISTS
		_create_scientist_patel(),
		_create_scientist_johansson(),

		# MEDICS
		_create_medic_thompson(),
		_create_medic_nakamura()
	]

# ============================================================================
# COMMANDERS
# ============================================================================

static func _create_commander_chen() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "chen",
		"display_name": "Dr. Sarah Chen",
		"specialty": GameTypes.CrewSpecialty.COMMANDER,
		"age": 48,
		"health": 95.0,
		"morale": 85.0,
		"skill_piloting": 70.0,
		"skill_engineering": 60.0,
		"skill_science": 80.0,
		"skill_medical": 50.0,
		"skill_leadership": 95.0,
		"personality": GameTypes.PersonalityTrait.LEADER,
		"backstory": "Former Air Force colonel. Led the successful Europa probe mission. Known for keeping crews calm in crisis.",
		"personal_goal": "First human to set foot on Mars. Wants to prove international cooperation works.",
		"quirk": "Plays chess against the ship's computer every night. Has never won."
	})

static func _create_commander_okonkwo() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "okonkwo",
		"display_name": "Cmdr. Adaeze Okonkwo",
		"specialty": GameTypes.CrewSpecialty.COMMANDER,
		"age": 52,
		"health": 88.0,
		"morale": 90.0,
		"skill_piloting": 85.0,
		"skill_engineering": 55.0,
		"skill_science": 65.0,
		"skill_medical": 45.0,
		"skill_leadership": 90.0,
		"personality": GameTypes.PersonalityTrait.STOIC,
		"backstory": "Nigerian Space Agency's most decorated astronaut. Survived the Lunar Station Gamma incident.",
		"personal_goal": "Establish protocols for permanent Mars settlement. Believes this is humanity's backup plan.",
		"quirk": "Keeps a small vial of Nigerian soil. Says it reminds her what she's fighting for."
	})

# ============================================================================
# PILOTS
# ============================================================================

static func _create_pilot_reyes() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "reyes",
		"display_name": "Lt. Carlos Reyes",
		"specialty": GameTypes.CrewSpecialty.PILOT,
		"age": 34,
		"health": 100.0,
		"morale": 95.0,
		"skill_piloting": 95.0,
		"skill_engineering": 70.0,
		"skill_science": 40.0,
		"skill_medical": 35.0,
		"skill_leadership": 60.0,
		"personality": GameTypes.PersonalityTrait.RISK_TAKER,
		"backstory": "Former test pilot. Holds the record for most hours logged on the X-42 spaceplane.",
		"personal_goal": "Prove that human pilots still matter in an age of AI navigation.",
		"quirk": "Names every vehicle he flies. Already calls the ship 'Esperanza'."
	})

static func _create_pilot_volkov() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "volkov",
		"display_name": "Maj. Katya Volkov",
		"specialty": GameTypes.CrewSpecialty.PILOT,
		"age": 41,
		"health": 92.0,
		"morale": 78.0,
		"skill_piloting": 90.0,
		"skill_engineering": 75.0,
		"skill_science": 45.0,
		"skill_medical": 40.0,
		"skill_leadership": 65.0,
		"personality": GameTypes.PersonalityTrait.CAUTIOUS,
		"backstory": "Roscosmos veteran. Piloted the Mir-2 station during the 2029 debris storm.",
		"personal_goal": "Return home safely. Has a daughter waiting on Earth.",
		"quirk": "Triple-checks every system. Other pilots call her paranoid. She calls it 'alive'."
	})

# ============================================================================
# ENGINEERS
# ============================================================================

static func _create_engineer_santos() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "santos",
		"display_name": "Eng. Miguel Santos",
		"specialty": GameTypes.CrewSpecialty.ENGINEER,
		"age": 38,
		"health": 100.0,
		"morale": 88.0,
		"skill_piloting": 45.0,
		"skill_engineering": 95.0,
		"skill_science": 60.0,
		"skill_medical": 35.0,
		"skill_leadership": 55.0,
		"personality": GameTypes.PersonalityTrait.OPTIMIST,
		"backstory": "Brazilian aerospace prodigy. Designed the ISRU system that made this mission possible.",
		"personal_goal": "See his life support systems work on an alien world. Prove his math is right.",
		"quirk": "Talks to the ship's systems like they're pets. 'Come on, baby, don't overheat now.'"
	})

static func _create_engineer_kim() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "kim",
		"display_name": "Dr. Ji-yeon Kim",
		"specialty": GameTypes.CrewSpecialty.ENGINEER,
		"age": 44,
		"health": 85.0,
		"morale": 82.0,
		"skill_piloting": 40.0,
		"skill_engineering": 90.0,
		"skill_science": 75.0,
		"skill_medical": 45.0,
		"skill_leadership": 60.0,
		"personality": GameTypes.PersonalityTrait.LONER,
		"backstory": "KASA's top nuclear engineer. Literally wrote the textbook on space reactor containment.",
		"personal_goal": "Prove nuclear propulsion is safe and essential for human expansion.",
		"quirk": "Prefers night shifts when everyone else is sleeping. Says the hum of the reactor is 'peaceful'."
	})

# ============================================================================
# SCIENTISTS
# ============================================================================

static func _create_scientist_patel() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "patel",
		"display_name": "Dr. Vikram Patel",
		"specialty": GameTypes.CrewSpecialty.SCIENTIST_GEOLOGY,
		"age": 36,
		"health": 90.0,
		"morale": 100.0,
		"skill_piloting": 30.0,
		"skill_engineering": 50.0,
		"skill_science": 95.0,
		"skill_medical": 40.0,
		"skill_leadership": 45.0,
		"personality": GameTypes.PersonalityTrait.CURIOUS,
		"backstory": "Found evidence of ancient water flows on Mars from orbital data. This mission will prove his theory.",
		"personal_goal": "Find definitive proof of past microbial life. The greatest discovery in human history.",
		"quirk": "Gets visibly excited about rocks. Has named several Martian craters after his grandmother."
	})

static func _create_scientist_johansson() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "johansson",
		"display_name": "Dr. Astrid Johansson",
		"specialty": GameTypes.CrewSpecialty.SCIENTIST_BIOLOGY,
		"age": 42,
		"health": 88.0,
		"morale": 75.0,
		"skill_piloting": 35.0,
		"skill_engineering": 45.0,
		"skill_science": 92.0,
		"skill_medical": 70.0,
		"skill_leadership": 50.0,
		"personality": GameTypes.PersonalityTrait.HOMESICK,
		"backstory": "Nobel Prize nominee for her work on extremophile bacteria. Left her family for this mission.",
		"personal_goal": "Determine if Mars can support terraforming. Believes it's humanity's next home.",
		"quirk": "Writes letters to her children every day, even though they won't receive them for months."
	})

# ============================================================================
# MEDICS
# ============================================================================

static func _create_medic_thompson() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "thompson",
		"display_name": "Dr. James Thompson",
		"specialty": GameTypes.CrewSpecialty.MEDIC,
		"age": 50,
		"health": 82.0,
		"morale": 85.0,
		"skill_piloting": 30.0,
		"skill_engineering": 40.0,
		"skill_science": 65.0,
		"skill_medical": 95.0,
		"skill_leadership": 70.0,
		"personality": GameTypes.PersonalityTrait.CARETAKER,
		"backstory": "Pioneered telemedicine protocols for deep space. Has saved lives from 400,000 km away.",
		"personal_goal": "Develop treatments for space adaptation syndrome. Make long-term space travel safer.",
		"quirk": "Tells terrible dad jokes during procedures. Says laughter is the best anesthetic."
	})

static func _create_medic_nakamura() -> Dictionary:
	return GameTypes.create_crew_member({
		"id": "nakamura",
		"display_name": "Dr. Yuki Nakamura",
		"specialty": GameTypes.CrewSpecialty.MEDIC,
		"age": 39,
		"health": 95.0,
		"morale": 80.0,
		"skill_piloting": 40.0,
		"skill_engineering": 35.0,
		"skill_science": 70.0,
		"skill_medical": 92.0,
		"skill_leadership": 55.0,
		"personality": GameTypes.PersonalityTrait.PESSIMIST,
		"backstory": "Trauma surgeon turned space medicine specialist. Has seen too many accidents to be optimistic.",
		"personal_goal": "Bring everyone home alive. That's the only metric that matters.",
		"quirk": "Always prepares for worst-case scenarios. Other crew find it morbid but reassuring."
	})

# ============================================================================
# PERSONALITY EFFECTS
# ============================================================================

## Get morale modifier based on personality
static func get_morale_modifier(personality: GameTypes.PersonalityTrait, event_type: String) -> float:
	match personality:
		GameTypes.PersonalityTrait.OPTIMIST:
			return 1.2 if event_type == "positive" else 0.8
		GameTypes.PersonalityTrait.PESSIMIST:
			return 0.8 if event_type == "positive" else 1.3
		GameTypes.PersonalityTrait.STOIC:
			return 0.5  # Half the morale swing
		GameTypes.PersonalityTrait.HOMESICK:
			return 1.5 if event_type == "earth_contact" else 1.0
		GameTypes.PersonalityTrait.CURIOUS:
			return 1.5 if event_type == "discovery" else 1.0
		GameTypes.PersonalityTrait.LONER:
			return 0.5 if event_type == "social" else 1.0
		_:
			return 1.0

## Get work effectiveness modifier based on personality and context
static func get_effectiveness_modifier(personality: GameTypes.PersonalityTrait, context: String) -> float:
	match personality:
		GameTypes.PersonalityTrait.RISK_TAKER:
			return 1.2 if context == "experiment" else 1.0
		GameTypes.PersonalityTrait.CAUTIOUS:
			return 0.9 if context == "experiment" else 1.1  # Lower success, fewer failures
		GameTypes.PersonalityTrait.LONER:
			return 1.2 if context == "solo_work" else 0.9
		GameTypes.PersonalityTrait.CARETAKER:
			return 1.3 if context == "medical" else 1.0
		GameTypes.PersonalityTrait.LEADER:
			return 1.2 if context == "team_work" else 1.0
		_:
			return 1.0

## Get description of personality trait
static func get_personality_description(personality: GameTypes.PersonalityTrait) -> String:
	match personality:
		GameTypes.PersonalityTrait.OPTIMIST:
			return "Optimist - Sees the bright side; morale recovers quickly"
		GameTypes.PersonalityTrait.PESSIMIST:
			return "Pessimist - Prepares for the worst; takes bad news harder"
		GameTypes.PersonalityTrait.LEADER:
			return "Leader - Inspires others in crisis; boosts team morale"
		GameTypes.PersonalityTrait.LONER:
			return "Loner - Works better alone; less affected by social events"
		GameTypes.PersonalityTrait.CARETAKER:
			return "Caretaker - Naturally nurturing; excellent at medical care"
		GameTypes.PersonalityTrait.RISK_TAKER:
			return "Risk-Taker - Bold choices; higher highs, lower lows"
		GameTypes.PersonalityTrait.CAUTIOUS:
			return "Cautious - Triple-checks everything; fewer catastrophic failures"
		GameTypes.PersonalityTrait.STOIC:
			return "Stoic - Steady under pressure; emotions don't swing"
		GameTypes.PersonalityTrait.HOMESICK:
			return "Homesick - Struggles with distance; treasure Earth contact"
		GameTypes.PersonalityTrait.CURIOUS:
			return "Curious - Loves discovery; science boosts morale"
		_:
			return "Unknown"
