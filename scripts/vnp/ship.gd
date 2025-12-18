extends CharacterBody2D

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")
const ProjectileScene = preload("res://scenes/vnp/projectile.tscn")
const ImpactFxScene = preload("res://scenes/vnp/impact_fx.tscn")

var store = null
var ship_data = {}
var ship_stats = {}

@onready var navigation_agent = $NavigationAgent2D
@onready var polygon = $Polygon2D
@onready var fire_rate_timer = $FireRateTimer
@onready var laser_beam = $LaserBeam
@onready var selection_indicator = $SelectionIndicator

# Engine trail particle system
var engine_trail: GPUParticles2D = null
var muzzle_flash: Polygon2D = null

func init(vnp_store, initial_data):
	self.store = vnp_store
	self.ship_data = initial_data
	self.ship_stats = VnpTypes.SHIP_STATS[ship_data.type]

	self.position = ship_data.position
	_apply_styles()
	_setup_engine_trail()
	_setup_muzzle_flash()

	fire_rate_timer.wait_time = 1.0 / ship_stats.get("fire_rate", 1.0)
	fire_rate_timer.connect("timeout", Callable(self, "_on_fire_rate_timer_timeout"))

func _setup_engine_trail():
	engine_trail = GPUParticles2D.new()
	engine_trail.name = "EngineTrail"

	# Position at rear of ship
	var ship_size = VnpTypes.get_ship_size(ship_data.type)
	var trail_offset = {
		VnpTypes.ShipSize.SMALL: -12,
		VnpTypes.ShipSize.MEDIUM: -16,
		VnpTypes.ShipSize.LARGE: -20,
	}
	engine_trail.position = Vector2(trail_offset.get(ship_size, -12), 0)

	# Particle settings
	engine_trail.amount = 20
	engine_trail.lifetime = 0.4
	engine_trail.explosiveness = 0.0
	engine_trail.emitting = true

	# Create process material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)  # Emit backwards
	material.spread = 15.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 80.0
	material.damping_min = 20.0
	material.damping_max = 30.0
	material.scale_min = 0.5
	material.scale_max = 1.5
	material.color = VnpTypes.get_team_color(ship_data.team).lightened(0.3)

	# Fade out
	var gradient = Gradient.new()
	gradient.set_color(0, VnpTypes.get_team_color(ship_data.team).lightened(0.5))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	engine_trail.process_material = material

	# Draw as circles
	engine_trail.draw_pass_1 = _create_circle_mesh(3.0)

	add_child(engine_trail)

func _setup_muzzle_flash():
	muzzle_flash = Polygon2D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(12, 0), Vector2(0, 4)
	])
	# Faction-specific muzzle flash color
	var flash_color = VnpTypes.get_weapon_color(ship_data.team, ship_stats.get("weapon", VnpTypes.WeaponType.GUN))
	muzzle_flash.color = flash_color.lightened(0.5)  # Brighter flash
	muzzle_flash.visible = false

	# Position at front of ship
	var ship_size = VnpTypes.get_ship_size(ship_data.type)
	var flash_offset = {
		VnpTypes.ShipSize.SMALL: 15,
		VnpTypes.ShipSize.MEDIUM: 20,
		VnpTypes.ShipSize.LARGE: 18,
	}
	muzzle_flash.position = Vector2(flash_offset.get(ship_size, 15), 0)

	add_child(muzzle_flash)

func _create_circle_mesh(radius: float) -> QuadMesh:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(radius * 2, radius * 2)
	return mesh

func _show_muzzle_flash():
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): muzzle_flash.visible = false)

func select():
	selection_indicator.visible = true

func deselect():
	selection_indicator.visible = false

func _physics_process(delta):
	var current_state = store.get_state()
	if not current_state.ships.has(ship_data.id):
		queue_free()
		return

	var my_current_data = current_state.ships[ship_data.id]
	
	var target_ship_data = null
	if my_current_data.target and current_state.ships.has(my_current_data.target):
		target_ship_data = current_state.ships.get(my_current_data.target)

	# Rotate to look at target
	if my_current_data.state == "attacking" and target_ship_data:
		look_at(target_ship_data.position)
	elif my_current_data.state == "moving":
		if my_current_data.target is Vector2 and position.distance_to(my_current_data.target) > 1:
			look_at(my_current_data.target)
	
	match my_current_data.state:
		"idle":
			if ship_data.type != VnpTypes.ShipType.HARVESTER:
				var target_id = _find_nearest_enemy(current_state)
				if target_id != -1:
					store.dispatch({
						"type": "SET_SHIP_STATE",
						"ship_id": ship_data.id,
						"state": "attacking",
						"target": target_id
					})
		"moving":
			var target_pos = my_current_data.target
			if target_pos is Vector2:
				_move_to(target_pos)
				if position.distance_to(target_pos) < 10.0:
					store.dispatch({ "type": "SET_SHIP_STATE", "ship_id": ship_data.id, "state": "idle", "target": null })
			else: # Invalid target for moving
				store.dispatch({ "type": "SET_SHIP_STATE", "ship_id": ship_data.id, "state": "idle", "target": null })


		"attacking":
			if not target_ship_data:
				store.dispatch({"type": "SET_SHIP_STATE", "ship_id": ship_data.id, "state": "idle"})
				return
			
			var distance_to_target = position.distance_to(target_ship_data.position)
			
			if distance_to_target > ship_stats.range:
				_move_to(target_ship_data.position)
			else:
				velocity = Vector2.ZERO
				move_and_slide()
				if fire_rate_timer.is_stopped():
					fire_rate_timer.start()

	if self.position != my_current_data.position:
		store.dispatch({
			"type": "UPDATE_SHIP_POSITION",
			"ship_id": ship_data.id,
			"position": self.position
		})

func _move_to(target_position):
	navigation_agent.target_position = target_position
	var next_path_position = navigation_agent.get_next_path_position()
	var new_velocity = position.direction_to(next_path_position) * ship_stats.speed
	velocity = new_velocity
	move_and_slide()

func _find_nearest_enemy(state):
	var nearest_enemy_id = -1
	var min_dist_sq = INF
	
	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team != ship_data.team:
			var dist_sq = self.position.distance_squared_to(other_ship.position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				nearest_enemy_id = other_ship_id
				
	return nearest_enemy_id

func _on_fire_rate_timer_timeout():
	var current_state = store.get_state()
	var my_current_data = current_state.ships.get(ship_data.id)
	
	if not my_current_data or my_current_data.state != "attacking":
		return

	var target_id = my_current_data.target
	if current_state.ships.has(target_id):
		var target_data = current_state.ships[target_id]
		var target_stats = VnpTypes.SHIP_STATS[target_data.type]
		var damage_multiplier = VnpTypes.DAMAGE_MULTIPLIERS[ship_stats.weapon].get(target_stats.weapon, 1.0)
		var total_damage = ship_stats.damage * damage_multiplier

		# Show muzzle flash for all weapons
		_show_muzzle_flash()

		match ship_stats.weapon:
			VnpTypes.WeaponType.LASER:
				# LASER: Instant hit with sustained burn effect
				var laser_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.LASER)

				# Main beam - bright core
				laser_beam.default_color = laser_color
				laser_beam.clear_points()
				laser_beam.add_point(Vector2.ZERO)
				laser_beam.add_point(to_local(target_data.position))

				# Create glow beam (wider, more transparent) - add to root so it doesn't move with ship
				var glow_beam = Line2D.new()
				glow_beam.default_color = Color(laser_color.r, laser_color.g, laser_color.b, 0.4)
				glow_beam.width = 24.0
				glow_beam.add_point(global_position)
				glow_beam.add_point(target_data.position)
				get_tree().root.add_child(glow_beam)

				# Animate beam fade - use sequential tween with proper cleanup
				var tween = create_tween()
				tween.tween_property(laser_beam, "width", 0.0, 0.2).from(14.0)

				var glow_tween = get_tree().create_tween()
				glow_tween.tween_property(glow_beam, "modulate:a", 0.0, 0.2)
				glow_tween.tween_callback(func(): glow_beam.queue_free())

				# Burning impact at target
				var impact = ImpactFxScene.instantiate()
				get_tree().root.add_child(impact)
				impact.global_position = target_data.position
				impact.scale = Vector2(1.5, 1.5)  # Larger burn mark
				impact.emitting = true

				# Instant damage - lasers are precise
				store.dispatch({ "type": "DAMAGE_SHIP", "ship_id": target_id, "damage": total_damage })

			VnpTypes.WeaponType.GUN, VnpTypes.WeaponType.MISSILE:
				var projectile = ProjectileScene.instantiate()
				get_tree().root.add_child(projectile)
				projectile.init({
					"team": ship_data.team,
					"weapon_type": ship_stats.weapon,
					"damage": total_damage,
					"start_position": self.global_position,
					"start_rotation": self.rotation,
					"target_id": target_id,
				})

func _apply_styles():
	match ship_data.type:
		VnpTypes.ShipType.FRIGATE:
			polygon.polygon = PackedVector2Array([Vector2(15, 0), Vector2(-10, -10), Vector2(-10, 10)])
		VnpTypes.ShipType.DESTROYER:
			polygon.polygon = PackedVector2Array([Vector2(20, 0), Vector2(-15, -8), Vector2(-15, 8)])
		VnpTypes.ShipType.CRUISER:
			polygon.polygon = PackedVector2Array([Vector2(18, 0), Vector2(9, -15), Vector2(-9, -15), Vector2(-18, 0), Vector2(-9, 15), Vector2(9, 15)])
		VnpTypes.ShipType.HARVESTER:
			polygon.polygon = PackedVector2Array([Vector2(-15, -8), Vector2(15, -8), Vector2(15, 8), Vector2(-15, 8)])

	polygon.color = VnpTypes.get_team_color(ship_data.team)