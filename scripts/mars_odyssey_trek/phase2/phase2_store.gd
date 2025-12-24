extends Node
class_name Phase2Store

## Phase 2: Travel to Mars - Store
## The ONLY place with side effects for Phase 2 simulation
## Wraps the pure reducer and provides:
## 1. Signal emissions for UI reactivity
## 2. Random number generation
## 3. Event selection and triggering
## 4. Persistence (save/load)
##
## Think of this like a Redux store - it holds state and dispatches actions

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")
const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")

# ============================================================================
# SIGNALS (for UI reactivity)
# ============================================================================

signal state_changed(new_state: Dictionary)
signal hour_advanced(day: int, hour: int)
signal day_advanced(day: int)
signal speed_changed(speed: int)
signal resources_changed(resources: Dictionary)
signal crew_changed(crew: Array)
signal container_blocked(container: Dictionary)
signal container_restored(container: Dictionary)
signal repair_started(container_id: String, days: int)
signal repair_completed(container_id: String)
signal event_triggered(event: Dictionary)
signal event_resolved(choice_index: int)
signal event_resolved_with_choice(event: Dictionary, choice_index: int, chosen_option: Dictionary)  # Phase 4: For task creation from choices
signal mars_visible()
signal arrival()
signal log_added(entry: Dictionary)
signal game_over(reason: String)
signal eva_triggered(crew_role: String, target: String)
signal eva_drift_triggered(crew_role: String)
signal crew_gather(location: String)  # For events like movie night - crew gathers in quarters

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = Phase2Types.create_phase2_state()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Standard event pool (can be extended with data-driven events)
var _event_pool: Array = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	if _state.is_empty():
		_state = Phase2Types.create_phase2_state()
	_setup_event_pool()

func _ready():
	pass  # State already initialized in _init

func _setup_event_pool() -> void:
	## Set up the standard event pool with FTL-style weighted outcomes
	## Events are STORY MOMENTS - real-time emergencies are handled by the Crisis System
	##
	## Design principles (from FTL/Oregon Trail research):
	## 1. Weighted outcomes - each choice has success/failure probabilities
	## 2. Blue options - special choices unlocked by crew/resources
	## 3. No overlap with Crisis System (fires, leaks, power fluctuations)
	## 4. Player agency through meaningful trade-offs

	_event_pool = [
		# =====================================================================
		# SPACE HAZARDS - External threats requiring crew decisions
		# =====================================================================
		Phase2Types.create_event({
			"type": Phase2Types.EventType.SOLAR_FLARE,
			"title": "SOLAR FLARE DETECTED",
			"description": "A solar flare will reach the ship in 6 hours. Radiation levels will spike dangerously.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Shelter in cargo hold",
					"description": "Safest option - crew hides in shielded cargo area.",
					"outcomes": [
						Phase2Types.create_outcome(0.85, [
							Phase2Types.create_effect("morale", -5, "all"),
							Phase2Types.create_effect("log", 0, "Crew sheltered successfully. Minor productivity loss.")
						], "Sheltering works perfectly."),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("health", -10, "all"),
							Phase2Types.create_effect("log", 0, "Some radiation leaked through. Minor exposure.")
						], "Shelter wasn't quite enough.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Rotate ship to use hull as shield",
					"description": "Risky maneuver but preserves morale.",
					"outcomes": [
						Phase2Types.create_outcome(0.6, [
							Phase2Types.create_effect("fuel", -3, "all"),
							Phase2Types.create_effect("log", 0, "Hull shielding maneuver successful!")
						], "The maneuver works perfectly."),
						Phase2Types.create_outcome(0.4, [
							Phase2Types.create_effect("health", -20, "random"),
							Phase2Types.create_effect("fuel", -5, "all"),
							Phase2Types.create_effect("log", 0, "Partial shielding - one crew member took significant exposure.")
						], "Partial success - some exposure.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[ENGINEER] Boost shield harmonics",
					"description": "Engineer can optimize shields for solar particles.",
					"is_blue_option": true,
					"requires_crew": "engineer",
					"outcomes": [
						Phase2Types.create_outcome(0.9, [
							Phase2Types.create_effect("power", -5, "all"),
							Phase2Types.create_effect("fatigue", 15, "engineer"),
							Phase2Types.create_effect("log", 0, "Mitchell's shield optimization blocked the flare completely!")
						], "Engineer saves the day!"),
						Phase2Types.create_outcome(0.1, [
							Phase2Types.create_effect("power", -10, "all"),
							Phase2Types.create_effect("health", -5, "all"),
							Phase2Types.create_effect("log", 0, "Shield optimization helped but wasn't perfect.")
						], "Mostly successful.")
					]
				})
			]
		}),

		Phase2Types.create_event({
			"type": Phase2Types.EventType.MICROMETEORITE,
			"title": "MICROMETEORITE IMPACT",
			"description": "A small impact registered on the hull. Sensors show possible micro-breach. Pressure is stable for now.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Full hull inspection",
					"description": "Thorough but time-consuming.",
					"outcomes": [
						Phase2Types.create_outcome(0.8, [
							Phase2Types.create_effect("fatigue", 10, "all"),
							Phase2Types.create_effect("log", 0, "Inspection complete - no breach found, hull integrity confirmed.")
						], "Nothing serious found."),
						Phase2Types.create_outcome(0.2, [
							Phase2Types.create_effect("fatigue", 15, "all"),
							Phase2Types.create_effect("log", 0, "Found and patched a micro-fracture! Good thing we checked.")
						], "Found a problem and fixed it!")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Quick visual check",
					"description": "Fast but might miss something.",
					"outcomes": [
						Phase2Types.create_outcome(0.7, [
							Phase2Types.create_effect("log", 0, "Quick check shows no visible damage.")
						], "Looks fine."),
						Phase2Types.create_outcome(0.3, [
							Phase2Types.create_effect("oxygen", -5, "all"),
							Phase2Types.create_effect("log", 0, "Missed a slow leak! Lost some atmosphere before we noticed.")
						], "We missed something...")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[ENGINEER] EVA hull repair",
					"description": "Mitchell can do a proper external inspection and repair.",
					"is_blue_option": true,
					"requires_crew": "engineer",
					"outcomes": [
						Phase2Types.create_outcome(0.85, [
							Phase2Types.create_effect("fatigue", 25, "engineer"),
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "EVA repair successful! Hull integrity fully restored.")
						], "Professional repair completed."),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("health", -15, "engineer"),
							Phase2Types.create_effect("fatigue", 30, "engineer"),
							Phase2Types.create_effect("log", 0, "EVA had complications - Mitchell bruised but repair done.")
						], "Repair done but with minor injury.")
					]
				})
			]
		}),

		# =====================================================================
		# CREW EVENTS - Interpersonal and morale situations
		# =====================================================================
		Phase2Types.create_event({
			"type": Phase2Types.EventType.CREW_CONFLICT,
			"title": "CREW DISAGREEMENT",
			"description": "Mitchell and Johnson are having a heated argument about duty schedules. The tension is affecting everyone.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Mediate personally",
					"description": "Commander steps in to resolve the conflict.",
					"outcomes": [
						Phase2Types.create_outcome(0.6, [
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "Wei mediated successfully. Crew respects the fair resolution.")
						], "Mediation works!"),
						Phase2Types.create_outcome(0.4, [
							Phase2Types.create_effect("morale", -8, "all"),
							Phase2Types.create_effect("log", 0, "Mediation helped but underlying tension remains.")
						], "Partially resolved.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Let them work it out",
					"description": "Adults should handle their own problems.",
					"outcomes": [
						Phase2Types.create_outcome(0.4, [
							Phase2Types.create_effect("morale", 3, "all"),
							Phase2Types.create_effect("log", 0, "They worked it out themselves. Builds character.")
						], "They figure it out."),
						Phase2Types.create_outcome(0.6, [
							Phase2Types.create_effect("morale", -15, "all"),
							Phase2Types.create_effect("log", 0, "Conflict escalated. Now everyone's taking sides.")
						], "It gets worse.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[MEDICAL] Psychological intervention",
					"description": "Dr. Johnson can use therapeutic techniques.",
					"is_blue_option": true,
					"requires_crew": "medical",
					"outcomes": [
						Phase2Types.create_outcome(0.8, [
							Phase2Types.create_effect("morale", 10, "all"),
							Phase2Types.create_effect("log", 0, "Johnson's conflict resolution training pays off. Crew feels heard.")
						], "Professional mediation succeeds."),
						Phase2Types.create_outcome(0.2, [
							Phase2Types.create_effect("morale", -5, "all"),
							Phase2Types.create_effect("log", 0, "Johnson tries but the conflict runs deeper than expected.")
						], "Not quite enough.")
					]
				})
			]
		}),

		Phase2Types.create_event({
			"type": Phase2Types.EventType.MEDICAL_EMERGENCY,
			"title": "MEDICAL EMERGENCY",
			"description": "A crew member is experiencing severe abdominal pain. Could be appendicitis or something less serious.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Conservative treatment",
					"description": "Monitor and treat symptoms. Hope it passes.",
					"outcomes": [
						Phase2Types.create_outcome(0.5, [
							Phase2Types.create_effect("health", -10, "random"),
							Phase2Types.create_effect("log", 0, "Symptoms subsided. Was likely stress-related.")
						], "It was nothing serious."),
						Phase2Types.create_outcome(0.5, [
							Phase2Types.create_effect("health", -35, "random"),
							Phase2Types.create_effect("log", 0, "Condition worsened significantly. Should have acted sooner.")
						], "It was serious after all.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Aggressive treatment",
					"description": "Use medical supplies for thorough treatment.",
					"requires_resource": "medical",
					"requires_min": 1,
					"outcomes": [
						Phase2Types.create_outcome(0.8, [
							Phase2Types.create_effect("health", -5, "random"),
							Phase2Types.create_effect("log", 0, "Treatment successful. Patient recovering well.")
						], "Treatment works!"),
						Phase2Types.create_outcome(0.2, [
							Phase2Types.create_effect("health", -20, "random"),
							Phase2Types.create_effect("log", 0, "Treatment helped but condition was more serious than expected.")
						], "Helped but not cured.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[MEDICAL] Emergency surgery",
					"description": "Dr. Johnson can perform surgery if necessary.",
					"is_blue_option": true,
					"requires_crew": "medical",
					"outcomes": [
						Phase2Types.create_outcome(0.9, [
							Phase2Types.create_effect("health", -15, "random"),
							Phase2Types.create_effect("fatigue", 30, "medical"),
							Phase2Types.create_effect("morale", 10, "all"),
							Phase2Types.create_effect("log", 0, "Surgery successful! Johnson saves a life. Crew morale soars.")
						], "Surgery saves them!"),
						Phase2Types.create_outcome(0.1, [
							Phase2Types.create_effect("health", -40, "random"),
							Phase2Types.create_effect("fatigue", 35, "medical"),
							Phase2Types.create_effect("log", 0, "Surgery had complications. Patient stable but recovery will be long.")
						], "Complications arise.")
					]
				})
			]
		}),

		# =====================================================================
		# COMMUNICATION EVENTS - Contact with Earth
		# =====================================================================
		Phase2Types.create_event({
			"type": Phase2Types.EventType.MESSAGE_FROM_EARTH,
			"title": "MESSAGE FROM EARTH",
			"description": "A personal video message has arrived for one of the crew members from their family.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Share immediately with everyone",
					"description": "Good news should be shared.",
					"outcomes": [
						Phase2Types.create_outcome(0.85, [
							Phase2Types.create_effect("morale", 12, "all"),
							Phase2Types.create_effect("log", 0, "Watching the message together boosted everyone's spirits.")
						], "Heartwarming moment for all."),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("morale", 8, "random"),
							Phase2Types.create_effect("morale", -5, "random"),
							Phase2Types.create_effect("log", 0, "Message made some crew homesick.")
						], "Mixed emotions.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Private viewing for recipient",
					"description": "Let them enjoy it privately first.",
					"outcomes": [
						Phase2Types.create_outcome(1.0, [
							Phase2Types.create_effect("morale", 15, "random"),
							Phase2Types.create_effect("log", 0, "A private moment of connection with home.")
						], "Personal moment appreciated.")
					]
				})
			]
		}),

		Phase2Types.create_event({
			"type": Phase2Types.EventType.COMMUNICATION_STATIC,
			"title": "COMMUNICATION INTERFERENCE",
			"description": "Solar activity is causing interference with Earth communications. An important mission update may be waiting.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Boost transmitter power",
					"description": "Uses power but maintains contact.",
					"outcomes": [
						Phase2Types.create_outcome(0.7, [
							Phase2Types.create_effect("power", -8, "all"),
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "Connection restored! Mission control sends encouragement.")
						], "Message received!"),
						Phase2Types.create_outcome(0.3, [
							Phase2Types.create_effect("power", -8, "all"),
							Phase2Types.create_effect("log", 0, "Extra power didn't help. Message garbled.")
						], "Still can't get through.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Wait for interference to pass",
					"description": "Accept temporary silence.",
					"outcomes": [
						Phase2Types.create_outcome(0.6, [
							Phase2Types.create_effect("log", 0, "Interference cleared after a few hours. No urgent messages.")
						], "Patience pays off."),
						Phase2Types.create_outcome(0.4, [
							Phase2Types.create_effect("morale", -8, "all"),
							Phase2Types.create_effect("log", 0, "Isolation weighs on the crew during the blackout.")
						], "The silence is hard.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[SCIENTIST] Frequency hop algorithm",
					"description": "Dr. Tanaka can try an experimental comm technique.",
					"is_blue_option": true,
					"requires_crew": "scientist",
					"outcomes": [
						Phase2Types.create_outcome(0.85, [
							Phase2Types.create_effect("morale", 10, "all"),
							Phase2Types.create_effect("fatigue", 10, "scientist"),
							Phase2Types.create_effect("log", 0, "Tanaka's algorithm works! Crystal clear connection established.")
						], "Science wins!"),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("fatigue", 15, "scientist"),
							Phase2Types.create_effect("log", 0, "Algorithm didn't work, but it was worth trying.")
						], "Good attempt.")
					]
				})
			]
		}),

		# =====================================================================
		# CARGO/SUPPLY EVENTS
		# =====================================================================
		Phase2Types.create_event({
			"type": Phase2Types.EventType.CARGO_LOOSE,
			"title": "EQUIPMENT FLOATING",
			"description": "Some supplies have come loose in zero-G and are drifting through the cargo area.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Carefully secure everything",
					"description": "Takes time but prevents damage.",
					"outcomes": [
						Phase2Types.create_outcome(0.9, [
							Phase2Types.create_effect("fatigue", 10, "all"),
							Phase2Types.create_effect("log", 0, "All cargo secured. No losses.")
						], "Everything saved."),
						Phase2Types.create_outcome(0.1, [
							Phase2Types.create_effect("food", -3, "all"),
							Phase2Types.create_effect("log", 0, "A few ration packs were damaged during recovery.")
						], "Minor losses.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Quick grab and stow",
					"description": "Fast but might miss or damage items.",
					"outcomes": [
						Phase2Types.create_outcome(0.5, [
							Phase2Types.create_effect("log", 0, "Quick work! Got most of it.")
						], "Good enough."),
						Phase2Types.create_outcome(0.5, [
							Phase2Types.create_effect("food", -8, "all"),
							Phase2Types.create_effect("log", 0, "Some supplies drifted into inaccessible areas. Lost.")
						], "Significant losses.")
					]
				})
			]
		}),

		Phase2Types.create_event({
			"type": Phase2Types.EventType.COMPONENT_MALFUNCTION,
			"title": "COMPONENT MALFUNCTION",
			"description": "The environmental monitoring system is showing erratic readings. Could be a sensor fault or something real.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Run diagnostics",
					"description": "Systematic troubleshooting.",
					"outcomes": [
						Phase2Types.create_outcome(0.7, [
							Phase2Types.create_effect("fatigue", 10, "engineer"),
							Phase2Types.create_effect("log", 0, "Diagnostics complete - just a sensor glitch. Recalibrated.")
						], "Easy fix."),
						Phase2Types.create_outcome(0.3, [
							Phase2Types.create_effect("log", 0, "Found a real problem developing. Good we caught it early.")
						], "Good thing we checked!")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Ignore it for now",
					"description": "Probably nothing.",
					"outcomes": [
						Phase2Types.create_outcome(0.6, [
							Phase2Types.create_effect("log", 0, "Readings stabilized on their own.")
						], "It was nothing."),
						Phase2Types.create_outcome(0.4, [
							Phase2Types.create_effect("morale", -10, "all"),
							Phase2Types.create_effect("log", 0, "The problem got worse. Now the crew is nervous about what else we're ignoring.")
						], "Should have checked.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[ENGINEER] Preventive maintenance",
					"description": "Mitchell does a thorough system check.",
					"is_blue_option": true,
					"requires_crew": "engineer",
					"outcomes": [
						Phase2Types.create_outcome(0.95, [
							Phase2Types.create_effect("fatigue", 20, "engineer"),
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "Mitchell found and fixed several minor issues. Ship is in better shape now.")
						], "Above and beyond."),
						Phase2Types.create_outcome(0.05, [
							Phase2Types.create_effect("fatigue", 25, "engineer"),
							Phase2Types.create_effect("log", 0, "Full check complete. Everything was actually fine.")
						], "Thorough but unnecessary.")
					]
				})
			]
		}),

		# =====================================================================
		# MILESTONE/MORALE EVENTS - Positive moments
		# =====================================================================
		Phase2Types.create_event({
			"type": Phase2Types.EventType.MORALE_MILESTONE,
			"title": "JOURNEY MILESTONE",
			"description": "The crew has completed another month of travel. A small celebration could boost spirits.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Special meal from reserves",
					"description": "Use extra rations for a feast.",
					"outcomes": [
						Phase2Types.create_outcome(0.9, [
							Phase2Types.create_effect("food", -8, "all"),
							Phase2Types.create_effect("morale", 15, "all"),
							Phase2Types.create_effect("crew_gather", 0, "quarters"),
							Phase2Types.create_effect("log", 0, "The celebration was worth it! Crew spirits are high.")
						], "Great celebration!"),
						Phase2Types.create_outcome(0.1, [
							Phase2Types.create_effect("food", -8, "all"),
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "Nice meal, but some crew are worried about supplies.")
						], "Good but concerns remain.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Movie night instead",
					"description": "Entertainment without using supplies.",
					"outcomes": [
						Phase2Types.create_outcome(1.0, [
							Phase2Types.create_effect("morale", 8, "all"),
							Phase2Types.create_effect("crew_gather", 0, "quarters"),
							Phase2Types.create_effect("log", 0, "Movie night was a hit. Good for morale without using supplies.")
						], "Simple pleasures.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Keep working",
					"description": "Mission focus. No time for celebrations.",
					"outcomes": [
						Phase2Types.create_outcome(0.3, [
							Phase2Types.create_effect("log", 0, "Crew appreciates the dedication to mission.")
						], "Understood."),
						Phase2Types.create_outcome(0.7, [
							Phase2Types.create_effect("morale", -5, "all"),
							Phase2Types.create_effect("log", 0, "All work and no play... morale dips slightly.")
						], "A bit disappointing.")
					]
				})
			]
		}),

		# =====================================================================
		# EVA EVENTS - Exterior work requiring spacewalk
		# =====================================================================
		Phase2Types.create_event({
			"type": Phase2Types.EventType.COMPONENT_MALFUNCTION,
			"title": "ENGINE NOZZLE DEBRIS",
			"description": "Sensors detect debris buildup on the main engine nozzle. Must be cleared before next course correction burn.",
			"is_eva_event": true,
			"eva_target": "engine",
			"options": [
				Phase2Types.create_event_option({
					"label": "EVA to clear debris",
					"description": "Spacewalk to manually remove the debris.",
					"outcomes": [
						Phase2Types.create_outcome(0.7, [
							Phase2Types.create_effect("fatigue", 25, "engineer"),
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "EVA successful! Engine nozzle cleared.")
						], "Clean spacewalk - debris removed."),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("fatigue", 35, "engineer"),
							Phase2Types.create_effect("morale", 8, "all"),
							Phase2Types.create_effect("eva_drift", 0, "engineer"),
							Phase2Types.create_effect("log", 0, "Debris cleared but spacewalker drifted on tether - rescue required!")
						], "Success but crew member drifted!"),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("health", -15, "engineer"),
							Phase2Types.create_effect("fatigue", 40, "engineer"),
							Phase2Types.create_effect("log", 0, "Sharp debris caused suit tear. Minor injury, mission accomplished.")
						], "Completed with injury.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Remote burn to dislodge",
					"description": "RISKY: Engine pulse might damage the nozzle further.",
					"outcomes": [
						Phase2Types.create_outcome(0.25, [
							Phase2Types.create_effect("fuel", -15, "all"),
							Phase2Types.create_effect("log", 0, "Burn cleared debris but wasted significant fuel.")
						], "Fuel wasted but cleared."),
						Phase2Types.create_outcome(0.45, [
							Phase2Types.create_effect("fuel", -20, "all"),
							Phase2Types.create_effect("morale", -10, "all"),
							Phase2Types.create_effect("log", 0, "Debris compacted into nozzle! Thrust reduced 30% until EVA repair.")
						], "Made it MUCH worse!"),
						Phase2Types.create_outcome(0.30, [
							Phase2Types.create_effect("fuel", -25, "all"),
							Phase2Types.create_effect("health", -10, "all"),
							Phase2Types.create_effect("morale", -15, "all"),
							Phase2Types.create_effect("log", 0, "CRITICAL: Engine backfire! Crew shaken, fuel venting.")
						], "Catastrophic backfire!")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[ENGINEER] Precision EVA",
					"description": "Mitchell's expertise minimizes risk.",
					"is_blue_option": true,
					"requires_crew": "engineer",
					"outcomes": [
						Phase2Types.create_outcome(0.9, [
							Phase2Types.create_effect("fatigue", 20, "engineer"),
							Phase2Types.create_effect("morale", 10, "all"),
							Phase2Types.create_effect("log", 0, "Mitchell's expert EVA work cleared everything perfectly!")
						], "Flawless EVA work."),
						Phase2Types.create_outcome(0.1, [
							Phase2Types.create_effect("fatigue", 25, "engineer"),
							Phase2Types.create_effect("eva_drift", 0, "engineer"),
							Phase2Types.create_effect("log", 0, "Even Mitchell drifted on this one - but quickly recovered!")
						], "Brief drift, fast recovery.")
					]
				})
			]
		}),

		Phase2Types.create_event({
			"type": Phase2Types.EventType.COMMUNICATION_STATIC,
			"title": "ANTENNA MISALIGNMENT",
			"description": "The main antenna has shifted out of alignment. Communications with Earth are degrading.",
			"is_eva_event": true,
			"eva_target": "antenna",
			"options": [
				Phase2Types.create_event_option({
					"label": "EVA to realign antenna",
					"description": "Manual adjustment from outside the hull.",
					"outcomes": [
						Phase2Types.create_outcome(0.65, [
							Phase2Types.create_effect("fatigue", 25, "all"),
							Phase2Types.create_effect("morale", 8, "all"),
							Phase2Types.create_effect("log", 0, "Antenna realigned! Communications restored.")
						], "Perfect alignment achieved."),
						Phase2Types.create_outcome(0.2, [
							Phase2Types.create_effect("fatigue", 35, "random"),
							Phase2Types.create_effect("eva_drift", 0, "random"),
							Phase2Types.create_effect("log", 0, "Antenna fixed but spacewalker got pushed by torque - drifting on tether!")
						], "Fixed but spacewalker adrift!"),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("fatigue", 30, "random"),
							Phase2Types.create_effect("log", 0, "Partial realignment. Comms improved but not perfect.")
						], "Partial success.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Use backup antenna",
					"description": "RISKY: Backup is low-power. May lose Earth contact entirely.",
					"outcomes": [
						Phase2Types.create_outcome(0.20, [
							Phase2Types.create_effect("morale", -10, "all"),
							Phase2Types.create_effect("log", 0, "Backup antenna active. Limited contact with Earth.")
						], "Limited comms."),
						Phase2Types.create_outcome(0.40, [
							Phase2Types.create_effect("morale", -20, "all"),
							Phase2Types.create_effect("log", 0, "Backup antenna failing! Very limited Earth contact. Crew anxious.")
						], "Comms nearly lost!"),
						Phase2Types.create_outcome(0.40, [
							Phase2Types.create_effect("morale", -30, "all"),
							Phase2Types.create_effect("health", -5, "all"),
							Phase2Types.create_effect("log", 0, "TOTAL BLACKOUT: No Earth contact! Crew feels isolated and abandoned.")
						], "Complete communications blackout!")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[SCIENTIST] Calibrated EVA",
					"description": "Tanaka brings precision instruments for exact alignment.",
					"is_blue_option": true,
					"requires_crew": "scientist",
					"outcomes": [
						Phase2Types.create_outcome(0.95, [
							Phase2Types.create_effect("fatigue", 20, "scientist"),
							Phase2Types.create_effect("morale", 12, "all"),
							Phase2Types.create_effect("log", 0, "Tanaka's scientific precision resulted in better-than-original alignment!")
						], "Better than factory settings!"),
						Phase2Types.create_outcome(0.05, [
							Phase2Types.create_effect("fatigue", 25, "scientist"),
							Phase2Types.create_effect("eva_drift", 0, "scientist"),
							Phase2Types.create_effect("log", 0, "Alignment perfect but Tanaka lost grip - tether caught them!")
						], "Great work, minor drift.")
					]
				})
			]
		}),

		Phase2Types.create_event({
			"type": Phase2Types.EventType.POWER_SURGE,
			"title": "SOLAR PANEL DAMAGE",
			"description": "A micrometeorite struck a solar panel. Power generation is reduced by 30%. Repair possible via EVA.",
			"is_eva_event": true,
			"eva_target": "solar",
			"options": [
				Phase2Types.create_event_option({
					"label": "EVA to repair panel",
					"description": "Spacewalk to patch and rewire the damaged cells.",
					"outcomes": [
						Phase2Types.create_outcome(0.6, [
							Phase2Types.create_effect("fatigue", 30, "engineer"),
							Phase2Types.create_effect("power", 5, "all"),
							Phase2Types.create_effect("morale", 5, "all"),
							Phase2Types.create_effect("log", 0, "Solar panel repaired! Power generation restored.")
						], "Full repair successful."),
						Phase2Types.create_outcome(0.2, [
							Phase2Types.create_effect("fatigue", 40, "engineer"),
							Phase2Types.create_effect("eva_drift", 0, "engineer"),
							Phase2Types.create_effect("power", 3, "all"),
							Phase2Types.create_effect("log", 0, "Panel partially fixed - but solar wind pushed spacewalker off!")
						], "Repair done, crew adrift!"),
						Phase2Types.create_outcome(0.2, [
							Phase2Types.create_effect("fatigue", 35, "engineer"),
							Phase2Types.create_effect("power", 2, "all"),
							Phase2Types.create_effect("log", 0, "Partial repair. Some cells unreachable.")
						], "Partial success.")
					]
				}),
				Phase2Types.create_event_option({
					"label": "Reroute around damage",
					"description": "RISKY: Rerouting may overload remaining panels.",
					"outcomes": [
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("power", -8, "all"),
							Phase2Types.create_effect("log", 0, "Power rerouted. Significant capacity loss but stable.")
						], "Lost 30% power."),
						Phase2Types.create_outcome(0.45, [
							Phase2Types.create_effect("power", -15, "all"),
							Phase2Types.create_effect("morale", -10, "all"),
							Phase2Types.create_effect("log", 0, "Rerouting strained other panels! Power generation cut in half.")
						], "Power cascade failure!"),
						Phase2Types.create_outcome(0.40, [
							Phase2Types.create_effect("power", -20, "all"),
							Phase2Types.create_effect("morale", -15, "all"),
							Phase2Types.create_effect("log", 0, "CRITICAL: Reroute caused secondary panel failure! Operating on emergency power only.")
						], "Critical power failure!")
					]
				}),
				Phase2Types.create_event_option({
					"label": "[ENGINEER] Precision EVA repair",
					"description": "Mitchell can do a thorough repair job.",
					"is_blue_option": true,
					"requires_crew": "engineer",
					"outcomes": [
						Phase2Types.create_outcome(0.85, [
							Phase2Types.create_effect("fatigue", 25, "engineer"),
							Phase2Types.create_effect("power", 8, "all"),
							Phase2Types.create_effect("morale", 8, "all"),
							Phase2Types.create_effect("log", 0, "Mitchell's expert repair fully restored the panel, plus improved efficiency!")
						], "Better than before!"),
						Phase2Types.create_outcome(0.15, [
							Phase2Types.create_effect("fatigue", 30, "engineer"),
							Phase2Types.create_effect("power", 5, "all"),
							Phase2Types.create_effect("eva_drift", 0, "engineer"),
							Phase2Types.create_effect("log", 0, "Excellent repair but Mitchell caught a solar gust - safe on tether!")
						], "Good repair, brief scare.")
					]
				})
			]
		})
	]

	# Set up special events (not in random pool)
	_setup_special_events()

# Midpoint crisis event (triggered specifically at day ~90)
var _midpoint_crisis: Dictionary = {}
var _mars_visible_event: Dictionary = {}
var _final_approach_event: Dictionary = {}
var _midpoint_triggered: bool = false
var _mars_visible_triggered: bool = false
var _final_approach_triggered: bool = false

func _setup_special_events() -> void:
	## Special events that trigger at specific journey points
	_midpoint_crisis = Phase2Types.create_event({
		"type": Phase2Types.EventType.MIDPOINT_CRISIS,
		"title": "⚠️ CRITICAL SYSTEM CASCADE",
		"description": "MIDPOINT CRISIS: Multiple systems failing simultaneously! The water recycler has critically failed, and a power surge has damaged the backup oxygen generator. This is the moment of truth.",
		"options": [
			Phase2Types.create_event_option({
				"label": "All hands emergency repair",
				"effect": "crisis_repair",
				"description": "Everyone drops everything. High fatigue, high success chance."
			}),
			Phase2Types.create_event_option({
				"label": "Prioritize oxygen systems",
				"effect": "crisis_oxygen",
				"description": "Focus on breathing - water can wait."
			}),
			Phase2Types.create_event_option({
				"label": "EVA to external repair",
				"effect": "crisis_eva",
				"description": "Risky but might fix both at once."
			})
		]
	})

	_mars_visible_event = Phase2Types.create_event({
		"type": Phase2Types.EventType.MARS_VISIBLE_EVENT,
		"title": "MARS SIGHTED!",
		"description": "After months of travel, Mars is finally visible to the naked eye! The red planet glows in the viewport. The crew gathers to witness this moment.",
		"options": [
			Phase2Types.create_event_option({
				"label": "Celebrate the milestone",
				"effect": "morale_boost",
				"effect_value": 15,
				"description": "A moment worth remembering."
			}),
			Phase2Types.create_event_option({
				"label": "Stay focused on the mission",
				"effect": "morale_boost",
				"effect_value": 5,
				"description": "Acknowledge it, but keep working."
			})
		]
	})

	_final_approach_event = Phase2Types.create_event({
		"type": Phase2Types.EventType.FINAL_APPROACH,
		"title": "MARS ORBIT APPROACH",
		"description": "The final approach begins. Mars fills the viewport. In just a few days, you'll achieve orbit. The crew feels a mixture of excitement and anxiety.",
		"options": [
			Phase2Types.create_event_option({
				"label": "Run final system checks",
				"effect": "thorough_check",
				"description": "Make sure everything is ready."
			}),
			Phase2Types.create_event_option({
				"label": "Rest before arrival",
				"effect": "rest_treatment",
				"description": "Crew will need energy for landing."
			})
		]
	})

# ============================================================================
# STATE GETTERS
# ============================================================================

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_day() -> int:
	return _state.get("current_day", 1)

func get_current_hour() -> int:
	return _state.get("current_hour", 0)

func get_total_hours() -> int:
	return _state.get("total_hours", 0)

func get_total_days() -> int:
	return _state.get("total_days", Phase2Types.TOTAL_TRAVEL_DAYS)

func get_days_remaining() -> int:
	return Phase2Reducer.get_days_remaining(_state)

func get_hours_remaining() -> int:
	return Phase2Reducer.get_hours_remaining(_state)

func get_journey_progress() -> float:
	return Phase2Reducer.get_journey_progress(_state)

func get_speed() -> int:
	return _state.get("speed", Phase2Types.Speed.NORMAL)

func is_auto_advancing() -> bool:
	return _state.get("auto_advance", true)

func get_resources() -> Dictionary:
	return _state.get("resources", {}).duplicate(true)

func get_crew() -> Array:
	return _state.get("crew", []).duplicate(true)

func get_crew_count() -> int:
	return _state.get("crew", []).size()

func get_storage_containers() -> Array:
	return _state.get("storage_containers", []).duplicate(true)

func get_accessible_containers() -> Array:
	return Phase2Types.get_accessible_containers(_state)

func get_blocked_containers() -> Array:
	return Phase2Types.get_blocked_containers(_state)

func get_active_container_index() -> int:
	return _state.get("active_container_index", 0)

func get_repair_state() -> Dictionary:
	return _state.get("repair", {}).duplicate(true)

func is_repair_in_progress() -> bool:
	return Phase2Reducer.is_repair_in_progress(_state)

func get_active_event() -> Dictionary:
	return _state.get("active_event", {}).duplicate(true)

func has_active_event() -> bool:
	return Phase2Reducer.has_active_event(_state)

func is_mars_visible() -> bool:
	return _state.get("mars_visible", false)

func has_arrived() -> bool:
	return Phase2Reducer.has_arrived(_state)

func is_game_over() -> bool:
	return Phase2Reducer.is_game_over(_state)

func get_log() -> Array:
	return _state.get("log", []).duplicate(true)

func get_average_morale() -> float:
	return Phase2Reducer.get_average_morale(_state)

func get_average_health() -> float:
	return Phase2Reducer.get_average_health(_state)

func get_accessible_food() -> float:
	return Phase2Reducer.get_accessible_food(_state)

func get_accessible_water() -> float:
	return Phase2Reducer.get_accessible_water(_state)

func get_trapped_food() -> float:
	return Phase2Reducer.get_trapped_food(_state)

func get_trapped_water() -> float:
	return Phase2Reducer.get_trapped_water(_state)

# ============================================================================
# DISPATCH (the only way to modify state)
# ============================================================================

func dispatch(action: Dictionary) -> void:
	var old_state = _state
	_state = Phase2Reducer.reduce(_state, action)

	# Emit appropriate signals based on what changed
	_emit_change_signals(old_state, _state, action)
	state_changed.emit(_state)

func dispatch_with_random(action: Dictionary, random_count: int = 10) -> void:
	var random_values: Array = []
	for i in range(random_count):
		random_values.append(_rng.randf())

	action["random_values"] = random_values
	dispatch(action)

# ============================================================================
# HIGH-LEVEL ACTIONS (convenience methods that dispatch)
# ============================================================================

func start_new_journey(seed_value: int = 0) -> void:
	if seed_value > 0:
		_rng.seed = seed_value
	else:
		_rng.seed = int(Time.get_unix_time_from_system())

	_state = Phase2Types.create_phase2_state({
		"random_seed": _rng.seed
	})
	state_changed.emit(_state)

func advance_hour() -> void:
	## Primary time advancement - advances by 1 hour
	if is_game_over() or has_arrived():
		return

	if has_active_event():
		return  # Can't advance while event is active

	# Generate random values for the hour
	dispatch_with_random(Phase2Reducer.action_advance_hour([]), 10)

	var current_day = get_current_day()

	# Check for special events at specific journey milestones
	_check_special_events(current_day)

	# Check if we need to trigger a random event from the queue
	if not has_active_event():  # Don't stack events
		_process_event_queue()

	# Check for arrival
	if has_arrived():
		arrival.emit()

	# Check for game over
	if is_game_over():
		game_over.emit("All crew lost")

func advance_day() -> void:
	## Legacy: advance by 1 full day (24 hours)
	for i in range(Phase2Types.HOURS_PER_DAY):
		if has_active_event() or is_game_over() or has_arrived():
			break
		advance_hour()

func _check_special_events(day: int) -> void:
	## Check if any special events should trigger based on the current day

	# Midpoint crisis (around day 90-95)
	if not _midpoint_triggered and day >= 90 and day <= 95:
		_midpoint_triggered = true
		trigger_event(_midpoint_crisis.duplicate(true))
		return

	# Mars becomes visible (around day 140)
	if not _mars_visible_triggered and day >= Phase2Types.MARS_VISIBLE_DAY and day <= Phase2Types.MARS_VISIBLE_DAY + 3:
		_mars_visible_triggered = true
		trigger_event(_mars_visible_event.duplicate(true))
		return

	# Final approach (last 10 days)
	if not _final_approach_triggered and day >= Phase2Types.TOTAL_TRAVEL_DAYS - 10 and day <= Phase2Types.TOTAL_TRAVEL_DAYS - 7:
		_final_approach_triggered = true
		trigger_event(_final_approach_event.duplicate(true))
		return

func set_speed(speed: int) -> void:
	dispatch(Phase2Reducer.action_set_speed(speed))

func pause() -> void:
	dispatch(Phase2Reducer.action_set_speed(Phase2Types.Speed.PAUSED))

func resume() -> void:
	if get_speed() == Phase2Types.Speed.PAUSED:
		dispatch(Phase2Reducer.action_set_speed(Phase2Types.Speed.NORMAL))

func toggle_pause() -> void:
	if get_speed() == Phase2Types.Speed.PAUSED:
		resume()
	else:
		pause()

func resolve_event(choice_index: int) -> void:
	if not has_active_event():
		return

	var event = get_active_event()
	var choice = event.options[choice_index] if choice_index < event.options.size() else {}

	# Handle special effects - can be string or int enum
	var effect = choice.get("effect", "")
	var is_repair = false
	var is_eva_retrieval = false

	# Check both string and enum forms
	if effect is String:
		is_repair = effect == "repair_section"
		is_eva_retrieval = effect == "eva_retrieval"
	elif effect is int:
		is_repair = effect == Phase2Types.EventEffectType.REPAIR_SECTION
		is_eva_retrieval = effect == Phase2Types.EventEffectType.EVA_RETRIEVAL

	if is_repair:
		# Start repair (using hours now)
		var container_id = event.get("blocked_container_id", "")
		var repair_hours = _rng.randi_range(Phase2Types.REPAIR_MIN_HOURS, Phase2Types.REPAIR_MAX_HOURS)
		dispatch(Phase2Reducer.action_start_repair(container_id, repair_hours))
	elif is_eva_retrieval:
		# Attempt EVA retrieval
		var container_id = event.get("blocked_container_id", "")
		dispatch(Phase2Reducer.action_eva_retrieval(container_id, _rng.randf()))
	else:
		# Standard event resolution
		dispatch(Phase2Reducer.action_resolve_event(choice_index, _rng.randf()))

	# Check if this is an EVA event AND the chosen option involves EVA
	# Only trigger visual EVA if the choice involves spacewalking
	if event.get("is_eva_event", false):
		var choice_label = choice.get("label", "").to_lower()
		var is_eva_choice = choice_label.contains("eva") or choice.get("is_eva_option", false)

		if is_eva_choice:
			var eva_target = event.get("eva_target", "engine")
			var crew_role = _get_eva_crew_role(choice)
			eva_triggered.emit(crew_role, eva_target)
			print("[STORE] EVA triggered: %s -> %s" % [crew_role, eva_target])

			# Check if the outcome includes eva_drift effect
			var outcomes = choice.get("outcomes", [])
			if not outcomes.is_empty():
				var roll = _rng.randf()
				var cumulative = 0.0
				for outcome in outcomes:
					cumulative += outcome.get("weight", 0.0)
					if roll <= cumulative:
						for eff in outcome.get("effects", []):
							if eff.get("type", "") == "eva_drift":
								var drift_target = eff.get("target", crew_role)
								if drift_target == "random":
									var roles = ["commander", "engineer", "scientist", "medical"]
									drift_target = roles[_rng.randi() % roles.size()]
								eva_drift_triggered.emit(drift_target)
						break

	# Check for crew_gather effects (for morale events like movie night)
	var outcomes = choice.get("outcomes", [])
	for outcome in outcomes:
		for eff in outcome.get("effects", []):
			if eff.get("type", "") == "crew_gather":
				var location = eff.get("target", "quarters")
				crew_gather.emit(location)
				break

func _get_eva_crew_role(choice: Dictionary) -> String:
	## Determine which crew role does the EVA based on choice
	var requires_crew = choice.get("requires_crew", "")
	if requires_crew:
		return requires_crew
	# Default to engineer for EVA work
	return "engineer"

func trigger_event(event: Dictionary) -> void:
	dispatch(Phase2Reducer.action_trigger_event(event))

# ============================================================================
# EVENT PROCESSING
# ============================================================================

func _process_event_queue() -> void:
	## Process any pending events in the queue
	var event_queue = _state.get("event_queue", [])
	if event_queue.is_empty():
		return

	# Get the first queued event request
	var request = event_queue[0]

	if request.get("type") == "random_event":
		# Pick a random event from the pool
		if not _event_pool.is_empty():
			var event = _event_pool[_rng.randi() % _event_pool.size()].duplicate(true)
			trigger_event(event)

	# Clear the queue (the event is now active)
	var new_state = _state.duplicate(true)
	new_state.event_queue = []
	_state = new_state

# ============================================================================
# SIGNAL EMISSION HELPERS
# ============================================================================

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, action: Dictionary) -> void:
	# Hour advancement
	var old_total_hours = old_state.get("total_hours", 0)
	var new_total_hours = new_state.get("total_hours", 0)
	if old_total_hours != new_total_hours:
		var new_day = new_state.get("current_day", 1)
		var new_hour = new_state.get("current_hour", 0)
		hour_advanced.emit(new_day, new_hour)

	# Day advancement
	var old_day = old_state.get("current_day", 1)
	var new_day = new_state.get("current_day", 1)
	if old_day != new_day:
		day_advanced.emit(new_day)

	# Speed change
	var old_speed = old_state.get("speed", Phase2Types.Speed.NORMAL)
	var new_speed = new_state.get("speed", Phase2Types.Speed.NORMAL)
	if old_speed != new_speed:
		speed_changed.emit(new_speed)

	# Resources change
	var old_resources = old_state.get("resources", {})
	var new_resources = new_state.get("resources", {})
	if old_resources != new_resources:
		resources_changed.emit(new_resources)

	# Crew change
	var old_crew = old_state.get("crew", [])
	var new_crew = new_state.get("crew", [])
	if old_crew != new_crew:
		crew_changed.emit(new_crew)

	# Container accessibility changes
	var old_containers = old_state.get("storage_containers", [])
	var new_containers = new_state.get("storage_containers", [])
	for i in range(min(old_containers.size(), new_containers.size())):
		var old_c = old_containers[i]
		var new_c = new_containers[i]
		if old_c.get("accessible", true) and not new_c.get("accessible", true):
			container_blocked.emit(new_c)
		elif not old_c.get("accessible", true) and new_c.get("accessible", true):
			container_restored.emit(new_c)

	# Repair state changes
	var old_repair = old_state.get("repair", {})
	var new_repair = new_state.get("repair", {})
	if not old_repair.get("in_progress", false) and new_repair.get("in_progress", false):
		repair_started.emit(new_repair.get("target_container_id", ""), new_repair.get("days_remaining", 0))
	elif old_repair.get("in_progress", false) and not new_repair.get("in_progress", false):
		repair_completed.emit(old_repair.get("target_container_id", ""))

	# Mars visibility
	var old_mars = old_state.get("mars_visible", false)
	var new_mars = new_state.get("mars_visible", false)
	if not old_mars and new_mars:
		mars_visible.emit()

	# Log additions
	var old_log = old_state.get("log", [])
	var new_log = new_state.get("log", [])
	if new_log.size() > old_log.size():
		var new_entry = new_log[-1]
		log_added.emit(new_entry)

	# Event state changes - detect when active_event transitions
	var old_event = old_state.get("active_event", {})
	var new_event = new_state.get("active_event", {})

	# Event triggered (covers both explicit TRIGGER_EVENT and section blockages during ADVANCE_DAY)
	if old_event.is_empty() and not new_event.is_empty():
		event_triggered.emit(new_event)

	# Event resolved
	if not old_event.is_empty() and new_event.is_empty():
		var choice_index = action.get("choice_index", 0)
		event_resolved.emit(choice_index)
		# Phase 4: Emit with full event and chosen option for task creation
		var options = old_event.get("options", [])
		var chosen_option = options[choice_index] if choice_index < options.size() else {}
		event_resolved_with_choice.emit(old_event, choice_index, chosen_option)

# ============================================================================
# PERSISTENCE
# ============================================================================

func save_journey(slot: int = 0) -> bool:
	var save_path = "user://phase2_save_%d.json" % slot
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return false

	var save_data = _state.duplicate(true)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_journey(slot: int = 0) -> bool:
	var save_path = "user://phase2_save_%d.json" % slot
	if not FileAccess.file_exists(save_path):
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		return false

	_state = json.data
	state_changed.emit(_state)
	return true

func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists("user://phase2_save_%d.json" % slot)

func delete_save(slot: int = 0) -> bool:
	var save_path = "user://phase2_save_%d.json" % slot
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false

# ============================================================================
# DEBUG HELPERS
# ============================================================================

func debug_advance_days(count: int) -> void:
	for i in range(count):
		advance_day()
		if has_active_event():
			resolve_event(0)  # Auto-resolve with first choice

func debug_block_container(container_id: String) -> void:
	dispatch(Phase2Reducer.action_block_section(
		container_id,
		Phase2Types.ContainerStatus.BLOCKED,
		_rng.randf()
	))

func debug_trigger_random_event() -> void:
	if not _event_pool.is_empty():
		var event = _event_pool[_rng.randi() % _event_pool.size()].duplicate(true)
		trigger_event(event)

func debug_set_day(day: int) -> void:
	var new_state = _state.duplicate(true)
	new_state.current_day = day
	_state = new_state
	state_changed.emit(_state)
