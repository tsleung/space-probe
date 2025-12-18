extends Area2D

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")
const ImpactFxScene = preload("res://scenes/vnp/impact_fx.tscn")

var speed = 800
var damage = 0
var team = -1
var weapon_type = null
var target_id = -1 # For homing missiles
var direction = Vector2.RIGHT

var lifetime = 2.0 # seconds

func _ready():
	var timer = Timer.new()
	timer.name = "ProjectileLifetime"
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "queue_free"))
	timer.start()
	
	self.connect("area_entered", Callable(self, "_on_area_entered"))

func init(init_data):
	self.damage = init_data.get("damage", 0)
	self.team = init_data.get("team", -1)
	self.weapon_type = init_data.get("weapon_type", null)
	self.target_id = init_data.get("target_id", -1)
	self.position = init_data.get("start_position", Vector2.ZERO)
	self.rotation = init_data.get("start_rotation", 0)
	self.direction = Vector2.RIGHT.rotated(self.rotation)
	
	if weapon_type == VnpTypes.WeaponType.MISSILE:
		$Polygon2D.color = Color.ORANGE
		$Trail2D.default_color = Color.ORANGE
		speed = 400 # Missiles are slower
	else: # Guns
		$Polygon2D.color = Color.YELLOW
		$Trail2D.default_color = Color.YELLOW


func _physics_process(delta):
	if weapon_type == VnpTypes.WeaponType.MISSILE:
		var store = get_tree().root.get_node("VnpMain").store
		if store:
			var state = store.get_state()
			if state.ships.has(target_id):
				var target_ship = state.ships[target_id]
				var direction_to_target = (target_ship.position - position).normalized()
				# Rotate towards the target
				direction = direction.slerp(direction_to_target, 0.05)
				rotation = direction.angle()
	
	position += direction * speed * delta

func _on_area_entered(area):
	var ship = area.get_parent()
	if not ship.is_in_group("ships"):
		return
	
	# Don't hit ships on the same team
	if ship.ship_data.team == self.team:
		return

	get_tree().root.get_node("VnpMain").store.dispatch({
			"type": "DAMAGE_SHIP",
			"ship_id": ship.ship_data.id,
			"damage": damage
		})
	
	# Create a particle-based impact effect
	var impact = ImpactFxScene.instantiate()
	get_parent().add_child(impact)
	impact.global_position = global_position
	impact.emitting = true

	queue_free()