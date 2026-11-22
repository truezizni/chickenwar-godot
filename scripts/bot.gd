extends CharacterBody3D

const GRAVITY := 22.0
const SPEED := 3.4
const MAX_HEALTH := 60.0
const SHOT_SOUND = preload("res://assets/audio/shot.wav")

var main = null
var player = null
var team := "red"
var bot_name := "КУРА"
var alive := true
var health := MAX_HEALTH
var spawn_pos := Vector3.ZERO
var respawn_timer := 0.0
var fire_timer := 0.0
var burst_left := 0
var target = null
var target_check := 0.0
var strafe_dir := 1.0
var strafe_timer := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var avoid_timer := 0.0
var avoid_dir := Vector3.ZERO
var walk_time := 0.0
var flash_timer := 0.0

var model: Node3D
var rifle: Node3D
var muzzle: Marker3D
var flash: MeshInstance3D
var shot_audio: AudioStreamPlayer3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var rng := RandomNumberGenerator.new()


func _init(p_team: String, p_pos: Vector3) -> void:
	team = p_team
	spawn_pos = p_pos
	position = p_pos


func _ready() -> void:
	rng.randomize()
	collision_layer = 2
	collision_mask = 1 | 2
	add_to_group("bots")
	add_to_group("team_" + team)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.25
	cs.shape = cap
	cs.position.y = 0.625
	add_child(cs)

	_build_model()
	shot_audio = AudioStreamPlayer3D.new()
	shot_audio.stream = SHOT_SOUND
	shot_audio.volume_db = -9.0
	shot_audio.unit_size = 14.0
	shot_audio.max_distance = 75.0
	shot_audio.position = Vector3(0.0, 1.25, 0.0)
	add_child(shot_audio)
	fire_timer = rng.randf_range(1.0, 3.0)
	last_pos = global_position


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)

	var body_mat := _mat(Color(0.93, 0.88, 0.75), 0.9)
	var orange := _mat(Color(0.95, 0.60, 0.15), 0.8)
	var red := _mat(Color(0.80, 0.12, 0.10), 0.8)
	var dark := _mat(Color(0.10, 0.10, 0.09), 0.5)
	var olive := _mat(Color(0.24, 0.28, 0.18), 0.9)
	var team_mat := _mat(Color(0.20, 0.45, 0.95) if team == "blue" else Color(0.90, 0.20, 0.15), 0.7)

	var body := _mesh_capsule(model, Vector3(0, 0.82, 0), 0.26, 0.72, body_mat)
	body.rotation.x = 0.12

	_mesh_sphere(model, Vector3(0, 1.16, -0.16), 0.21, 0.42, body_mat)
	_mesh_sphere(model, Vector3(0, 1.04, -0.35), 0.06, 0.12, red)

	var beak := _mesh_cylinder(model, Vector3(0, 1.13, -0.39), 0.0, 0.07, 0.22, orange)
	beak.rotation.x = -PI * 0.5

	for i in range(3):
		_mesh_box(model, Vector3(0, 1.35 + i * 0.035, -0.18 + i * 0.05), Vector3(0.05, 0.09, 0.09), red)

	_mesh_sphere(model, Vector3(-0.08, 1.22, -0.32), 0.025, 0.05, dark)
	_mesh_sphere(model, Vector3(0.08, 1.22, -0.32), 0.025, 0.05, dark)

	var helmet := _mesh_sphere(model, Vector3(0, 1.31, -0.15), 0.235, 0.235, team_mat, true)
	helmet.scale = Vector3(1.0, 0.85, 1.0)
	var brim := _mesh_cylinder(model, Vector3(0, 1.31, -0.15), 0.26, 0.26, 0.03, team_mat)
	brim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_mesh_box(model, Vector3(0, 0.87, 0.02), Vector3(0.44, 0.32, 0.32), olive)
	_mesh_box(model, Vector3(0, 0.93, -0.18), Vector3(0.16, 0.08, 0.02), team_mat)

	var wing_l := _mesh_box(model, Vector3(-0.28, 0.90, -0.10), Vector3(0.12, 0.10, 0.34), body_mat)
	wing_l.rotation.x = -0.30
	var wing_r := _mesh_box(model, Vector3(0.28, 0.90, -0.10), Vector3(0.12, 0.10, 0.34), body_mat)
	wing_r.rotation.x = -0.30

	for i in range(3):
		var tail := _mesh_box(model, Vector3(0, 0.95 + i * 0.03, 0.30), Vector3(0.07, 0.26, 0.05), body_mat)
		tail.rotation.x = -0.55 - i * 0.08

	leg_l = _mesh_cylinder(model, Vector3(-0.10, 0.22, 0.02), 0.035, 0.040, 0.40, orange)
	leg_r = _mesh_cylinder(model, Vector3(0.10, 0.22, 0.02), 0.035, 0.040, 0.40, orange)

	rifle = Node3D.new()
	rifle.position = Vector3(0.18, 0.95, -0.34)
	model.add_child(rifle)

	_mesh_box(rifle, Vector3(0, 0, 0), Vector3(0.07, 0.09, 0.42), dark)
	_mesh_box(rifle, Vector3(0, -0.09, 0.06), Vector3(0.05, 0.16, 0.10), dark)
	var barrel := _mesh_cylinder(rifle, Vector3(0, 0.01, -0.30), 0.018, 0.022, 0.30, dark)
	barrel.rotation.x = PI * 0.5

	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.01, -0.47)
	rifle.add_child(muzzle)

	flash = MeshInstance3D.new()
	var fquad := QuadMesh.new()
	fquad.size = Vector2(0.26, 0.26)
	flash.mesh = fquad
	flash.position = Vector3(0, 0.01, -0.50)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.80, 0.30)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.45, 0.10)
	fmat.emission_energy_multiplier = 6.0
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = fmat
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rifle.add_child(flash)


func _physics_process(delta: float) -> void:
	if main == null:
		return
	if not main.game_started or main.paused or main.game_ended:
		return

	if not alive:
		respawn_timer -= delta
		if respawn_timer < 5.5:
			model.visible = false
		if respawn_timer <= 0.0:
			_respawn()
		return

	fire_timer -= delta
	target_check -= delta
	if target_check <= 0.0:
		target_check = 0.35
		target = _find_target()

	var desired := Vector3.ZERO

	if target != null:
		var tpos: Vector3 = target.global_position
		var to_target := tpos - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist > 0.1:
			var dir := to_target / dist
			rotation.y = atan2(-dir.x, -dir.z)
			if dist > 15.0:
				desired = dir * SPEED
			elif dist < 6.0:
				desired = -dir * SPEED * 0.65
			else:
				strafe_timer -= delta
				if strafe_timer <= 0.0:
					strafe_timer = rng.randf_range(0.8, 1.8)
					strafe_dir = -strafe_dir
				desired = Vector3(-dir.z, 0, dir.x) * strafe_dir * SPEED * 0.75

			if dist < 40.0 and has_los(target) and fire_timer <= 0.0:
				_shoot_at(target)
	else:
		var to_obj := -global_position
		to_obj.y = 0.0
		if to_obj.length() > 2.0:
			desired = to_obj.normalized() * SPEED
			rotation.y = atan2(-desired.x, -desired.z)
		else:
			rotation.y += delta * 0.5

	if avoid_timer > 0.0:
		avoid_timer -= delta
		desired += avoid_dir * SPEED * 0.8

	for other in main.bots:
		if other != self and other.alive:
			var d: Vector3 = global_position - other.global_position
			d.y = 0.0
			var l := d.length()
			if l < 1.25 and l > 0.01:
				desired += d.normalized() * (1.25 - l) * 2.0

	velocity.x = lerp(velocity.x, desired.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerp(velocity.z, desired.z, 1.0 - exp(-8.0 * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	move_and_slide()
	global_position.x = clamp(global_position.x, -46.0, 46.0)
	global_position.z = clamp(global_position.z, -46.0, 46.0)

	stuck_timer += delta
	if stuck_timer > 1.0:
		if global_position.distance_to(last_pos) < 0.35:
			avoid_timer = 1.1
			avoid_dir = Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)).normalized()
		last_pos = global_position
		stuck_timer = 0.0

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	walk_time += delta * (4.0 + planar_speed * 2.0)
	var swing: float = sin(walk_time) * 0.5 * clamp(planar_speed / 3.0, 0.0, 1.0)
	if leg_l:
		leg_l.rotation.x = swing
	if leg_r:
		leg_r.rotation.x = -swing

	if flash_timer > 0.0:
		flash_timer -= delta
		flash.visible = flash_timer > 0.0


func _find_target():
	var best = null
	var best_dist := 45.0

	if team == "red" and player != null and player.alive:
		var d := global_position.distance_to(player.global_position)
		if d < best_dist and has_los(player):
			best = player
			best_dist = d

	for b in main.bots:
		if b == self or not b.alive or b.team == team:
			continue
		var d := global_position.distance_to(b.global_position)
		if d < best_dist and has_los(b):
			best = b
			best_dist = d

	return best


func has_los(t) -> bool:
	if t == null:
		return false
	var from := global_position + Vector3(0, 1.25, 0)
	var to: Vector3 = t.global_position + Vector3(0, 1.25, 0)
	if t == player:
		to = t.global_position + Vector3(0, 1.40, 0)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _shoot_at(t) -> void:
	if shot_audio != null:
		shot_audio.pitch_scale = rng.randf_range(0.92, 1.05)
		shot_audio.play()
	var from := global_position + Vector3(0, 1.25, 0)
	var to: Vector3 = t.global_position + Vector3(0, 1.15, 0)
	if t == player:
		to = t.global_position + Vector3(0, 1.35, 0)

	var dir := (to - from).normalized()
	var spread := 0.018 + from.distance_to(to) * 0.0012
	var right := dir.cross(Vector3.UP)
	if right.length() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(dir).normalized()
	dir = (dir + right * rng.randf_range(-spread, spread) + up * rng.randf_range(-spread, spread)).normalized()

	var end := from + dir * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, end)
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		end = hit.position
		var c = hit.collider
		if c == player:
			player.take_damage(rng.randf_range(7.0, 11.0), self)
		elif c != null and c.is_in_group("bots") and c.team != team:
			c.take_damage(rng.randf_range(7.0, 11.0), self, false)

	if main:
		main.spawn_tracer(from, end, Color(1.0, 0.45, 0.28))

	flash_timer = 0.05
	flash.visible = true

	if burst_left <= 0:
		burst_left = 3
	burst_left -= 1
	if burst_left > 0:
		fire_timer = 0.13
	else:
		fire_timer = rng.randf_range(1.0, 1.9)


func take_damage(amount: float, source = null, headshot := false) -> void:
	if not alive:
		return
	health -= amount
	if model:
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3(1.08, 1.08, 1.08), 0.05)
		tw.tween_property(model, "scale", Vector3.ONE, 0.10)
	if health <= 0.0:
		_die(source)


func _die(source) -> void:
	alive = false
	health = 0.0
	velocity = Vector3.ZERO
	respawn_timer = 8.0
	collision_layer = 0
	collision_mask = 0
	model.rotation.z = PI * 0.5
	model.position.y = 0.15
	flash.visible = false
	if main:
		main.on_bot_died(self, source)


func _respawn() -> void:
	global_position = spawn_pos + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0))
	health = MAX_HEALTH
	alive = true
	collision_layer = 2
	collision_mask = 1 | 2
	model.visible = true
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	model.scale = Vector3.ONE
	target = null
	fire_timer = 1.5
	burst_left = 0
	last_pos = global_position
	stuck_timer = 0.0
	avoid_timer = 0.0


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _mesh_box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _mesh_sphere(parent: Node, pos: Vector3, radius: float, height: float, mat: Material, hemi := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = height
	sm.radial_segments = 8
	sm.rings = 6
	sm.is_hemisphere = hemi
	mi.mesh = sm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _mesh_capsule(parent: Node, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 4
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _mesh_cylinder(parent: Node, pos: Vector3, top_r: float, bottom_r: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
