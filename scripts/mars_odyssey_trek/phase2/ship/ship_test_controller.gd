extends Node

## Test controller for ship view

const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

@onready var ship_view = $"../ShipView"
@onready var status_text = $"../UI/CrewStatus/StatusText"

# Buttons
@onready var damage_bridge = $"../UI/Controls/DamageBridge"
@onready var damage_cargo = $"../UI/Controls/DamageCargo"
@onready var damage_engineering = $"../UI/Controls/DamageEngineering"
@onready var send_engineer_cargo = $"../UI/Controls/SendEngineerCargo"
@onready var send_medical_bridge = $"../UI/Controls/SendMedicalBridge"
@onready var send_nearest = $"../UI/Controls/SendNearest"
@onready var repair_all = $"../UI/Controls/RepairAll"

func _ready():
	# Wait a frame for ship_view to initialize
	await get_tree().process_frame

	# Connect buttons
	if damage_bridge:
		damage_bridge.pressed.connect(_on_damage_bridge)
	if damage_cargo:
		damage_cargo.pressed.connect(_on_damage_cargo)
	if damage_engineering:
		damage_engineering.pressed.connect(_on_damage_engineering)
	if send_engineer_cargo:
		send_engineer_cargo.pressed.connect(_on_send_engineer_cargo)
	if send_medical_bridge:
		send_medical_bridge.pressed.connect(_on_send_medical_bridge)
	if send_nearest:
		send_nearest.pressed.connect(_on_send_nearest)
	if repair_all:
		repair_all.pressed.connect(_on_repair_all)

func _process(_delta):
	_update_status()

func _update_status():
	if not ship_view or not status_text:
		return
	var status = ship_view.get_crew_status()
	var text = ""
	for role in ["commander", "engineer", "scientist", "medical"]:
		if status.has(role):
			var s = status[role]
			text += "%s: %s\n  in %s\n" % [role.capitalize(), s.state, s.room]
	status_text.text = text

func _on_damage_bridge():
	if ship_view:
		ship_view.damage_room(ShipTypes.RoomType.BRIDGE, 0.7)

func _on_damage_cargo():
	if ship_view:
		ship_view.damage_room(ShipTypes.RoomType.CARGO_BAY, 0.8)

func _on_damage_engineering():
	if ship_view:
		ship_view.damage_room(ShipTypes.RoomType.ENGINEERING, 0.6)

func _on_send_engineer_cargo():
	if ship_view:
		ship_view.send_crew_to_room("engineer", ShipTypes.RoomType.CARGO_BAY, false)

func _on_send_medical_bridge():
	if ship_view:
		ship_view.send_crew_to_room("medical", ShipTypes.RoomType.BRIDGE, false)

func _on_send_nearest():
	if ship_view:
		ship_view.send_nearest_crew_to_room(ShipTypes.RoomType.CARGO_BAY, true)

func _on_repair_all():
	if ship_view:
		for room_type in ShipTypes.RoomType.values():
			ship_view.repair_room(room_type)
