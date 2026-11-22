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
var difficulty := 1
var ai_role := "assault"
var slot := 0
var team_size := 4

var target = null
var threat_source = null
var target_visible := false
var last_seen_pos := Vector3.ZERO
var last_seen_time := 99.0
var target_check := 0.0
var reaction_timer := 0.0
var aim_time := 0.0
var alert_pos := Vector3.ZERO
var alert_timer := 0.0
var alert_cooldown := 0.0
var hurt_timer := 0.0
var suppression := 0.0
var fire_timer := 0.0
var burst_left := 0
var strafe_dir := 1.0
var strafe_timer := 0.0
var cover_pos := Vector3.ZERO
var cover_timer := 0.0
var cover_check := 0.0
var cover_cooldown := 0.0
var in_cover := false
var destination := Vector3.ZERO
var dest_timer := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var avoid_timer := 0.0
var avoid_dir := Vector3.ZERO
var walk_time := 0.0
var flash_timer := 0.0
var params: Dictionary = {}
var debug_shots := 0
var debug_cover_uses := 0

var model: Node3D
var rifle: Node3D
var muzzle: Marker3D
var flash: MeshInstance3D
var shot_audio: AudioStreamPlayer3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var rng := RandomNumberGenerator.new()
const EYE_HEIGHT := 1.25


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
	params = _build_ai_params()
	if ai_role == "":
		ai_role = "assault"
	if team_size <= 0:
		team_size = 4
	fire_timer = rng.randf_range(0.8, 2.0)
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

	_tick_timers(delta)

	if target_check <= 0.0:
		target_check = rng.randf_range(0.22, 0.38)
		_scan_for_targets()

	var desired := _decide_movement(delta)
	desired = _avoid_obstacles(desired, delta)
	desired += _separation_force()

	var max_speed: float = params.move_speed * 1.2
	var flat := Vector3(desired.x, 0.0, desired.z)
	if flat.length() > max_speed:
		flat = flat.normalized() * max_speed
	velocity.x = lerp(velocity.x, flat.x, 1.0 - exp(-9.0 * delta))
	velocity.z = lerp(velocity.z, flat.z, 1.0 - exp(-9.0 * delta))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	move_and_slide()
	global_position.x = clampf(global_position.x, -45.0, 45.0)
	global_position.z = clampf(global_position.z, -45.0, 45.0)

	_update_stuck(delta)
	_animate(delta)
	_try_fire()


func _tick_timers(delta: float) -> void:
	fire_timer -= delta
	target_check -= delta
	last_seen_time += delta
	reaction_timer -= delta
	if target_visible:
		aim_time += delta
	else:
		aim_time = maxf(0.0, aim_time - delta * 2.0)
	strafe_timer -= delta
	hurt_timer = maxf(0.0, hurt_timer - delta)
	suppression = maxf(0.0, suppression - delta * 0.55)
	alert_timer = maxf(0.0, alert_timer - delta)
	alert_cooldown = maxf(0.0, alert_cooldown - delta)
	cover_check -= delta
	cover_cooldown = maxf(0.0, cover_cooldown - delta)
	if in_cover:
		cover_timer -= delta
		if cover_timer <= 0.0:
			in_cover = false
			cover_cooldown = rng.randf_range(4.0, 7.0)


func _scan_for_targets() -> void:
	if main == null:
		return
	if target != null and not _is_valid_target(target):
		target = null
		target_visible = false

	var candidates: Array = []
	if player != null and _is_valid_target(player):
		candidates.append(player)
	for b in main.bots:
		if b != self and b.team != team and _is_valid_target(b):
			candidates.append(b)

	var best = null
	var best_score := 9999.0
	var forward := -global_transform.basis.z
	var fov_cos: float = cos(deg_to_rad(params.fov * 0.5))

	for c in candidates:
		var to: Vector3 = c.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > params.view_range:
			continue
		if dist > 0.1 and c != target and last_seen_time > 0.9:
			if forward.dot(to.normalized()) < fov_cos:
				continue
		if not has_los(c):
			continue
		var score := dist
		if c == player:
			score -= 4.0
		if c == target:
			score -= 9.0
		if c == threat_source:
			score -= 12.0
		if dist < 8.0:
			score -= 2.0
		if score < best_score:
			best_score = score
			best = c

	if best != null:
		if best != target:
			target = best
			reaction_timer = rng.randf_range(params.reaction_min, params.reaction_max)
			aim_time = 0.0
			burst_left = 0
			fire_timer = maxf(fire_timer, 0.1)
		target_visible = true
		last_seen_pos = target.global_position
		last_seen_time = 0.0
		if alert_cooldown <= 0.0:
			alert_cooldown = 2.5
			_alert_allies()
	else:
		target_visible = false
		if target != null and last_seen_time > params.memory:
			target = null


func _is_valid_target(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t == player:
		return player.alive and team == "red"
	if t is Node and t.is_in_group("bots"):
		return t.alive and t.team != team
	return false


func _target_eye(t) -> Vector3:
	var height := 1.40 if t == player else 1.15
	return t.global_position + Vector3(0.0, height, 0.0)


func _alert_allies() -> void:
	if main == null or target == null:
		return
	for b in main.bots:
		if b == self or not is_instance_valid(b) or not b.alive or b.team != team:
			continue
		if b.global_position.distance_to(global_position) <= 24.0:
			b.receive_alert(target.global_position)


func receive_alert(pos: Vector3) -> void:
	if target_visible:
		return
	alert_pos = pos
	alert_timer = maxf(alert_timer, 4.0)


func has_los(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var from := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var to := _target_eye(t)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var exclude: Array[RID] = [get_rid()]
	if t is CollisionObject3D:
		exclude.append(t.get_rid())
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _decide_movement(delta: float) -> Vector3:
	var desired := Vector3.ZERO

	if in_cover and cover_timer > 0.0:
		var to_cover := cover_pos - global_position
		to_cover.y = 0.0
		if to_cover.length() > 0.55:
			desired = to_cover.normalized() * params.move_speed * 1.15
			_turn_toward(to_cover, delta)
		else:
			var threat := last_seen_pos if target != null else cover_pos
			var face := threat - global_position
			face.y = 0.0
			if face.length() > 0.1:
				_turn_toward(face, delta)
		return desired

	if target != null and target_visible:
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist > 0.1:
			var dir := to_target / dist
			_turn_toward(dir, delta)

			var pref := _preferred_range()
			if dist > pref.y:
				desired = dir * params.move_speed
				if ai_role == "flank":
					desired += Vector3(-dir.z, 0.0, dir.x) * strafe_dir * params.move_speed * 0.35
			elif dist < pref.x:
				desired = -dir * params.move_speed * 0.85
			else:
				strafe_timer -= delta
				if strafe_timer <= 0.0:
					strafe_timer = rng.randf_range(0.7, 1.7)
					strafe_dir = -strafe_dir
				desired = Vector3(-dir.z, 0.0, dir.x) * strafe_dir * params.move_speed * 0.78

			if dist < 4.5:
				desired -= dir * params.move_speed * 0.4

		if not in_cover and cover_check <= 0.0 and _should_seek_cover():
			cover_check = rng.randf_range(1.4, 2.2)
			_find_cover(target.global_position)

		if health < MAX_HEALTH * 0.30 and not in_cover:
			var away: Vector3 = global_position - target.global_position
			away.y = 0.0
			if away.length() > 0.1:
				desired = away.normalized() * params.move_speed * 1.2
		return desired

	if target != null and last_seen_time < params.memory:
		var to_last := last_seen_pos - global_position
		to_last.y = 0.0
		if to_last.length() > 1.2:
			_turn_toward(to_last, delta)
			desired = to_last.normalized() * params.move_speed * 0.85
		else:
			desired = Vector3.ZERO
			rotation.y += delta * 0.8
		return desired

	if alert_timer > 0.0:
		var to_alert := alert_pos - global_position
		to_alert.y = 0.0
		if to_alert.length() < 2.0:
			alert_timer = 0.0
		else:
			_turn_toward(to_alert, delta)
			desired = to_alert.normalized() * params.move_speed
		return desired

	dest_timer -= delta
	if dest_timer <= 0.0 or destination == Vector3.ZERO:
		dest_timer = rng.randf_range(2.6, 4.4)
		destination = _objective_destination()
	var to_dest := destination - global_position
	to_dest.y = 0.0
	if to_dest.length() > 1.5:
		_turn_toward(to_dest, delta)
		desired = to_dest.normalized() * params.move_speed
	else:
		rotation.y += delta * 0.35
	return desired


func _turn_toward(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.05:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-params.turn * delta))


func _preferred_range() -> Vector2:
	match ai_role:
		"support":
			return Vector2(13.0, 21.0)
		"flank":
			return Vector2(8.0, 16.0)
		"escort":
			return Vector2(7.0, 14.0)
		_:
			return Vector2(5.0, 12.0)


func _should_seek_cover() -> bool:
	if cover_cooldown > 0.0:
		return false
	if health < MAX_HEALTH * 0.45:
		return true
	if suppression > 0.55:
		return rng.randf() < params.cover_chance
	if hurt_timer > 0.0:
		return rng.randf() < params.cover_chance
	if target != null and target_visible:
		var d := global_position.distance_to(target.global_position)
		if d < 13.0:
			return rng.randf() < params.cover_chance * 0.30
	return false


func _find_cover(threat_pos: Vector3) -> void:
	var best := Vector3.ZERO
	var best_score := -9999.0
	var found := false
	var threat_eye := threat_pos + Vector3(0.0, 1.35, 0.0)

	for i in range(8):
		var angle := float(i) * TAU / 8.0 + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		for radius in [3.2, 5.0]:
			var cand: Vector3 = global_position + dir * radius
			if absf(cand.x) > 44.0 or absf(cand.z) > 44.0:
				continue
			if cand.distance_to(threat_pos) < 4.5:
				continue
			if not _path_clear(global_position, cand):
				continue
			var cand_eye := cand + Vector3(0.0, EYE_HEIGHT, 0.0)
			if not _ray_blocked(cand_eye, threat_eye):
				continue
			var to_threat := threat_pos - global_position
			to_threat.y = 0.0
			var away := -dir.dot(to_threat.normalized())
			var score := away * 3.0 + rng.randf() * 0.7 - absf(radius - 4.2) * 0.2
			if score > best_score:
				best_score = score
				best = cand
				found = true

	if found:
		cover_pos = best
		in_cover = true
		cover_timer = rng.randf_range(1.8, 3.0)
		if health < MAX_HEALTH * 0.45:
			cover_timer = rng.randf_range(3.0, 4.5)
		debug_cover_uses += 1
	else:
		cover_cooldown = rng.randf_range(2.0, 3.5)


func _path_clear(from: Vector3, to: Vector3) -> bool:
	var a := from + Vector3(0.0, 0.55, 0.0)
	var b := to + Vector3(0.0, 0.55, 0.0)
	return not _ray_blocked(a, b)


func _ray_blocked(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _objective_destination() -> Vector3:
	if team == "blue" and ai_role == "escort" and player != null and player.alive:
		var pz := Vector2(player.global_position.x, player.global_position.z).length()
		if pz > 9.0:
			var a := float(slot) * 2.3 + 0.7
			return player.global_position + Vector3(cos(a), 0.0, sin(a)) * 5.0

	var count: int = maxi(1, team_size)
	var angle := float(slot) / float(count) * TAU
	var radius := 2.2
	match ai_role:
		"support":
			radius = 8.5
		"flank":
			radius = 12.0
			angle += 0.4
		"escort":
			radius = 4.5
	return Vector3(cos(angle), 0.0, sin(angle)) * radius


func _separation_force() -> Vector3:
	var push := Vector3.ZERO
	if main == null:
		return push
	for other in main.bots:
		if other == self or not is_instance_valid(other) or not other.alive:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.2 and l > 0.01:
			push += d.normalized() * (1.2 - l) * 1.7
	return push


func _avoid_obstacles(desired: Vector3, delta: float) -> Vector3:
	var result := desired
	if avoid_timer > 0.0:
		avoid_timer -= delta
		result = result.lerp(avoid_dir * params.move_speed, 0.65)

	var flat := Vector3(result.x, 0.0, result.z)
	if flat.length() < 0.25:
		return result
	var dir := flat.normalized()
	var origin := global_position + Vector3(0.0, 0.55, 0.0)
	if not _ray_blocked(origin, origin + dir * 1.9):
		return result

	var left := dir.rotated(Vector3.UP, deg_to_rad(55.0))
	var right := dir.rotated(Vector3.UP, deg_to_rad(-55.0))
	var left_free := not _ray_blocked(origin, origin + left * 2.4)
	var right_free := not _ray_blocked(origin, origin + right * 2.4)
	var steer := Vector3.ZERO
	if left_free and not right_free:
		steer = left
	elif right_free and not left_free:
		steer = right
	elif left_free and right_free:
		steer = left if strafe_dir > 0.0 else right
	else:
		steer = -dir
		result = -result * 0.35
	return result.lerp(steer * params.move_speed, 0.72)


func _update_stuck(delta: float) -> void:
	stuck_timer += delta
	if stuck_timer > 1.2:
		if global_position.distance_to(last_pos) < 0.4:
			avoid_timer = 1.0
			var side := 1.0 if rng.randf() > 0.5 else -1.0
			avoid_dir = Vector3(-forward_dir().z, 0.0, forward_dir().x) * side
			cover_cooldown = 0.0
			destination = Vector3.ZERO
		last_pos = global_position
		stuck_timer = 0.0


func forward_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _animate(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	walk_time += delta * (4.0 + planar_speed * 2.0)
	var swing: float = sin(walk_time) * 0.5 * clampf(planar_speed / 3.0, 0.0, 1.0)
	if leg_l:
		leg_l.rotation.x = swing
	if leg_r:
		leg_r.rotation.x = -swing

	if flash_timer > 0.0:
		flash_timer -= delta
		flash.visible = flash_timer > 0.0


func _try_fire() -> void:
	if target == null or not target_visible:
		return
	if reaction_timer > 0.0 or fire_timer > 0.0:
		return
	if not has_los(target):
		return
	if not _line_of_fire_clear(target):
		return
	_shoot_at(target)


func _line_of_fire_clear(t) -> bool:
	var from := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var to := _target_eye(t)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var c = hit.collider
	if c == t:
		return true
	if c is Node and c.is_in_group("bots") and c.team == team:
		return false
	return false

func _shoot_at(t) -> void:
	if shot_audio != null:
		shot_audio.pitch_scale = rng.randf_range(0.92, 1.05)
		shot_audio.play()
	var from := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var to := _target_eye(t)

	var dir := (to - from).normalized()
	var dist := from.distance_to(to)
	var spread: float = params.spread + dist * params.spread_per_meter
	var move_ratio: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(1.0, params.move_speed), 0.0, 1.0)
	spread += move_ratio * 0.009
	if t == player and player != null:
		var tv: float = Vector2(player.velocity.x, player.velocity.z).length()
		spread += clampf(tv / 8.0, 0.0, 1.0) * 0.006
	spread *= lerp(1.55, 0.90, clampf(aim_time / 1.1, 0.0, 1.0))

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
		var dmg := rng.randf_range(params.damage_min, params.damage_max)
		if c == player:
			player.take_damage(dmg, self)
		elif c != null and c.is_in_group("bots") and c.team != team:
			c.take_damage(dmg, self, false)

	if main:
		var tracer_from := muzzle.global_position if muzzle != null else from
		main.spawn_tracer(tracer_from, end, Color(1.0, 0.45, 0.28))

	flash_timer = 0.05
	flash.visible = true
	debug_shots += 1

	if burst_left <= 0:
		burst_left = params.burst
	burst_left -= 1
	if burst_left > 0:
		fire_timer = rng.randf_range(0.10, 0.16)
	else:
		fire_timer = rng.randf_range(params.burst_pause_min, params.burst_pause_max)



func take_damage(amount: float, source = null, headshot := false) -> void:
	if not alive:
		return
	health -= amount
	hurt_timer = 3.0
	suppression = minf(1.0, suppression + 0.55)
	if model:
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3(1.08, 1.08, 1.08), 0.05)
		tw.tween_property(model, "scale", Vector3.ONE, 0.10)

	if source != null and is_instance_valid(source) and _is_enemy_source(source):
		threat_source = source
		if target == null or not target_visible:
			last_seen_pos = source.global_position
			last_seen_time = 0.0
			if has_los(source):
				target = source
				target_visible = true
				reaction_timer = maxf(reaction_timer, params.reaction_min * 0.8)
				aim_time = 0.0
		if alert_cooldown <= 0.0:
			alert_cooldown = 2.5
			receive_alert(source.global_position)
		if in_cover and health < MAX_HEALTH * 0.5:
			cover_timer = maxf(cover_timer, 2.0)
		if health < MAX_HEALTH * 0.55 and cover_cooldown <= 0.0:
			cover_check = 0.0

	if health <= 0.0:
		_die(source)


func _is_enemy_source(source) -> bool:
	if source == player:
		return team == "red"
	if source is Node and source.is_in_group("bots"):
		return source.team != team
	return false


func _die(source) -> void:
	alive = false
	health = 0.0
	velocity = Vector3.ZERO
	respawn_timer = 8.0
	collision_layer = 0
	collision_mask = 0
	target = null
	target_visible = false
	in_cover = false
	cover_timer = 0.0
	threat_source = null
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
	target_visible = false
	threat_source = null
	last_seen_time = 99.0
	alert_timer = 0.0
	alert_cooldown = 0.0
	aim_time = 0.0
	reaction_timer = 0.0
	cover_timer = 0.0
	cover_cooldown = 0.0
	in_cover = false
	destination = Vector3.ZERO
	dest_timer = 0.0
	fire_timer = 1.2
	burst_left = 0
	last_pos = global_position
	stuck_timer = 0.0
	avoid_timer = 0.0
	var face := -global_position
	face.y = 0.0
	if face.length() > 0.1:
		rotation.y = atan2(-face.x, -face.z)


func _build_ai_params() -> Dictionary:
	var p := {
		"reaction_min": 0.32,
		"reaction_max": 0.55,
		"view_range": 42.0,
		"fov": 120.0,
		"memory": 4.5,
		"spread": 0.018,
		"spread_per_meter": 0.0011,
		"damage_min": 6.0,
		"damage_max": 9.0,
		"burst": 3,
		"burst_pause_min": 1.0,
		"burst_pause_max": 1.7,
		"turn": 7.5,
		"move_speed": 3.5,
		"cover_chance": 0.45,
	}
	if difficulty <= 0:
		p.reaction_min = 0.55
		p.reaction_max = 0.95
		p.view_range = 36.0
		p.fov = 100.0
		p.memory = 3.0
		p.spread = 0.027
		p.spread_per_meter = 0.0016
		p.damage_min = 5.0
		p.damage_max = 8.0
		p.burst = 2
		p.burst_pause_min = 1.4
		p.burst_pause_max = 2.4
		p.turn = 5.5
		p.move_speed = 3.2
		p.cover_chance = 0.25
	elif difficulty >= 2:
		p.reaction_min = 0.18
		p.reaction_max = 0.32
		p.view_range = 48.0
		p.fov = 140.0
		p.memory = 6.0
		p.spread = 0.011
		p.spread_per_meter = 0.0007
		p.damage_min = 7.0
		p.damage_max = 10.0
		p.burst = 4
		p.burst_pause_min = 0.75
		p.burst_pause_max = 1.25
		p.turn = 9.5
		p.move_speed = 3.8
		p.cover_chance = 0.65
	return p


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
