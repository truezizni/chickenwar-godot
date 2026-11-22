extends CharacterBody3D

const GRAVITY := 22.0
const SPEED_WALK := 5.2
const SPEED_SPRINT := 8.0
const SPEED_CROUCH := 2.6
const JUMP_VELOCITY := 6.2
const MOUSE_SENS := 0.0022
const MAG_SIZE := 30
const MAX_RESERVE := 120
const FIRE_INTERVAL := 0.105
const RELOAD_TIME := 1.9
const GRENADE_SCRIPT = preload("res://scripts/grenade.gd")
const WEAPON_SCENE = preload("res://assets/weapons/akm_fps.glb")
const SHOT_SOUND = preload("res://assets/audio/shot.wav")
const RELOAD_SOUND = preload("res://assets/audio/reload.wav")
const HIT_SOUND = preload("res://assets/audio/hit.wav")
const WEAPON_SCALE := 0.05
const WEAPON_YAW := 90.0
const MUZZLE_MODEL := Vector3(7.45, 0.87, 0.0)

var main = null
var alive := true
var health := 100.0
var max_health := 100.0
var ammo := MAG_SIZE
var reserve := MAX_RESERVE
var grenades := 3
var reloading := false
var reload_timer := 0.0
var fire_timer := 0.0
var grenade_cooldown := 0.0
var pitch := 0.0
var recoil := 0.0
var debug_motion_count := 0
var spread_heat := 0.0
var bob_time := 0.0
var crouch_amount := 0.0
var respawn_timer := 0.0
var is_sprinting := false
var ads := false
var test_ads := false
var test_fire := false

var camera: Camera3D
var weapon: Node3D
var weapon_model: Node3D
var weapon_anim: AnimationPlayer
var muzzle: Marker3D
var flash: MeshInstance3D
var flash_light: OmniLight3D
var flash_timer := 0.0
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var hit_audio: AudioStreamPlayer
var base_weapon_pos := Vector3(0.19, -0.24, -0.55)
var ads_weapon_pos := Vector3(-0.08, -0.156, -0.60)
var ads_weapon_rot := Vector3(-0.01, -0.02, 0.0)
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	collision_layer = 1
	collision_mask = 1 | 2

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)

	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 250.0
	camera.current = true
	add_child(camera)

	_build_weapon()
	_build_audio()


func _build_audio() -> void:
	shot_audio = AudioStreamPlayer.new()
	shot_audio.stream = SHOT_SOUND
	shot_audio.volume_db = -2.0
	add_child(shot_audio)

	reload_audio = AudioStreamPlayer.new()
	reload_audio.stream = RELOAD_SOUND
	reload_audio.volume_db = -5.0
	add_child(reload_audio)

	hit_audio = AudioStreamPlayer.new()
	hit_audio.stream = HIT_SOUND
	hit_audio.volume_db = -6.0
	add_child(hit_audio)


func _input(event: InputEvent) -> void:
	if main == null or not alive:
		return
	if event is InputEventMouseMotion and main.input_debug and debug_motion_count < 20:
		debug_motion_count += 1
		print("MOTION mode=", Input.mouse_mode, " rel=", event.relative, " started=", main.game_started, " paused=", main.paused)
	if not main.game_started or main.paused or main.game_ended:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		pitch = clamp(pitch - event.relative.y * MOUSE_SENS, -1.35, 1.35)
		if main.input_debug:
			print("MOUSE rel=", event.relative, " yaw=", rotation.y, " pitch=", pitch)


func _physics_process(delta: float) -> void:
	if main == null:
		return
	if not main.game_started or main.paused or main.game_ended:
		return

	if not alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	ads = test_ads or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	fire_timer -= delta
	grenade_cooldown -= delta
	spread_heat = lerp(spread_heat, 0.0, 1.0 - exp(-6.0 * delta))

	if main.test_mode and test_fire and fire_timer <= 0.0 and not reloading:
		if ammo <= 0:
			ammo = MAG_SIZE
		_shoot()

	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	var ix := 0.0
	var iz := 0.0
	if Input.is_physical_key_pressed(KEY_D):
		ix += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		ix -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		iz += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		iz -= 1.0

	var crouching := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and iz < 0.0 and not crouching and not ads

	var dir := transform.basis * Vector3(ix, 0, iz)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var speed := SPEED_WALK
	if crouching:
		speed = SPEED_CROUCH
	elif is_sprinting:
		speed = SPEED_SPRINT

	var target_vel := dir * speed
	velocity.x = lerp(velocity.x, target_vel.x, 1.0 - exp(-12.0 * delta))
	velocity.z = lerp(velocity.z, target_vel.z, 1.0 - exp(-12.0 * delta))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y = -0.5

	move_and_slide()
	global_position.x = clamp(global_position.x, -46.0, 46.0)
	global_position.z = clamp(global_position.z, -46.0, 46.0)

	var target_crouch := 1.0 if crouching else 0.0
	crouch_amount = lerp(crouch_amount, target_crouch, 8.0 * delta)
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	bob_time += delta * (planar_speed * 1.5 + 1.0)

	camera.position.y = lerp(1.62, 1.12, crouch_amount)
	if is_on_floor() and planar_speed > 0.5:
		camera.position.y += sin(bob_time * 8.0) * 0.025
		camera.position.x = sin(bob_time * 4.0) * 0.015
	else:
		camera.position.x = lerp(camera.position.x, 0.0, 8.0 * delta)

	recoil = lerp(recoil, 0.0, 1.0 - exp(-9.0 * delta))
	camera.rotation.x = pitch + recoil
	camera.fov = lerp(camera.fov, 55.0 if ads else 75.0, 1.0 - exp(-10.0 * delta))

	_update_weapon(delta)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_timer <= 0.0 and not reloading and not main.test_mode:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()

	if Input.is_physical_key_pressed(KEY_R) and not main.test_mode:
		_start_reload()

	if Input.is_physical_key_pressed(KEY_G) and grenade_cooldown <= 0.0 and not main.test_mode:
		_throw_grenade()


func _build_weapon() -> void:
	weapon = Node3D.new()
	weapon.position = base_weapon_pos
	camera.add_child(weapon)

	weapon_model = WEAPON_SCENE.instantiate()
	weapon_model.scale = Vector3.ONE * WEAPON_SCALE
	weapon_model.rotation_degrees.y = WEAPON_YAW
	weapon.add_child(weapon_model)
	_disable_viewmodel_shadows(weapon_model)

	weapon_anim = weapon_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if weapon_anim != null:
		var idle: Animation = weapon_anim.get_animation("Armature|Idle")
		if idle != null:
			idle.loop_mode = Animation.LOOP_LINEAR
		weapon_anim.animation_finished.connect(_on_weapon_anim_finished)
		weapon_anim.play("Armature|Idle")

	muzzle = Marker3D.new()
	muzzle.position = Vector3(MUZZLE_MODEL.z, MUZZLE_MODEL.y, -MUZZLE_MODEL.x) * WEAPON_SCALE
	weapon.add_child(muzzle)

	flash = MeshInstance3D.new()
	var fquad := QuadMesh.new()
	fquad.size = Vector2(0.13, 0.13)
	flash.mesh = fquad
	flash.position = muzzle.position + Vector3(0.0, 0.0, -0.02)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.92, 0.65)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.62, 0.18)
	fmat.emission_energy_multiplier = 6.0
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fmat.albedo_texture = _make_flash_texture()
	flash.material_override = fmat
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(flash)

	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.72, 0.32)
	flash_light.light_energy = 0.0
	flash_light.omni_range = 4.0
	flash_light.position = muzzle.position
	weapon.add_child(flash_light)


func _make_flash_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.98, 0.85, 1.0))
	grad.set_color(1, Color(1.0, 0.45, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _disable_viewmodel_shadows(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_disable_viewmodel_shadows(c)


func _on_weapon_anim_finished(anim_name: StringName) -> void:
	if weapon_anim == null:
		return
	if anim_name == "Armature|Shoot" or anim_name == "Armature|Reload":
		weapon_anim.play("Armature|Idle", 0.12)


func _update_weapon(delta: float) -> void:
	if weapon == null:
		return
	var target_pos := base_weapon_pos
	var target_rot := Vector3.ZERO

	if ads:
		target_pos = ads_weapon_pos
		target_rot = ads_weapon_rot
	if reloading:
		target_pos = Vector3(0.24, -0.34, -0.44)
		target_rot = Vector3(-0.32, 0.0, 0.22)
	elif is_sprinting:
		target_pos = Vector3(0.28, -0.30, -0.42)
		target_rot = Vector3(0.16, 0.0, -0.30)

	weapon.position = weapon.position.lerp(target_pos, 1.0 - exp(-12.0 * delta))
	weapon.rotation = weapon.rotation.lerp(target_rot, 1.0 - exp(-12.0 * delta))
	weapon.position.z += recoil * 0.9

	var planar := Vector2(velocity.x, velocity.z).length()
	var move_amt: float = clampf(planar / SPEED_WALK, 0.0, 1.6)
	var bob_scale := 0.35 if ads else 1.0
	var bob := sin(bob_time * 8.0) * 0.008 * move_amt * bob_scale
	var sway := sin(bob_time * 4.0) * 0.006 * move_amt * bob_scale
	weapon.position += Vector3(sway, bob, 0.0)
	weapon.rotation.z += sway * 0.5

	if flash_timer > 0.0:
		flash_timer -= delta
		flash.visible = flash_timer > 0.0
		if flash_light != null:
			flash_light.light_energy = 2.4 * clampf(flash_timer / 0.05, 0.0, 1.0)
	elif flash_light != null and flash_light.light_energy != 0.0:
		flash_light.light_energy = 0.0


func _shoot() -> void:
	ammo -= 1
	fire_timer = FIRE_INTERVAL
	recoil += 0.018
	spread_heat = min(1.0, spread_heat + 0.14)
	flash_timer = 0.05
	flash.visible = true
	if flash_light != null:
		flash_light.light_energy = 2.4
	if weapon_anim != null:
		weapon_anim.play("Armature|Shoot", 0.02, 1.5)
	if shot_audio != null:
		shot_audio.pitch_scale = rng.randf_range(0.94, 1.06)
		shot_audio.play()

	var origin := camera.global_position
	var basis := camera.global_transform.basis
	var forward := -basis.z
	var right := basis.x
	var up := basis.y
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var spread := 0.004 + spread_heat * 0.012 + (0.018 if not ads else 0.0015)
	spread += clamp(planar_speed * 0.0012, 0.0, 0.012)

	var dir := (forward + right * rng.randf_range(-spread, spread) + up * rng.randf_range(-spread, spread)).normalized()
	var end := origin + dir * 120.0

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var hit_pos := end
	if not hit.is_empty():
		hit_pos = hit.position
		var collider = hit.collider
		if collider != null and collider.is_in_group("bots"):
			if collider.team != "blue":
				var headshot: bool = hit_pos.y > collider.global_position.y + 1.02
				collider.take_damage(70.0 if headshot else 28.0, self, headshot)
				if hit_audio != null:
					hit_audio.pitch_scale = rng.randf_range(0.97, 1.05)
					hit_audio.play()
				if main:
					main.on_player_hit(headshot)
		elif collider != self:
			if main:
				main.spawn_impact(hit_pos)

	if main:
		main.spawn_tracer(muzzle.global_position, hit_pos, Color(1.0, 0.82, 0.35))


func _start_reload() -> void:
	if reloading or ammo >= MAG_SIZE or reserve <= 0:
		return
	reloading = true
	reload_timer = RELOAD_TIME
	if weapon_anim != null:
		weapon_anim.play("Armature|Reload", 0.12, 1.36)
	if reload_audio != null:
		reload_audio.pitch_scale = rng.randf_range(0.98, 1.03)
		reload_audio.play()


func _finish_reload() -> void:
	var need := MAG_SIZE - ammo
	var take := mini(need, reserve)
	ammo += take
	reserve -= take
	reloading = false


func _throw_grenade() -> void:
	if grenades <= 0:
		return
	grenades -= 1
	grenade_cooldown = 0.7
	var g = GRENADE_SCRIPT.new()
	g.main = main
	if main:
		main.add_child(g)
		g.global_position = camera.global_position - camera.global_transform.basis.z * 0.6
		g.velocity = -camera.global_transform.basis.z * 13.0 + Vector3.UP * 4.0


func take_damage(amount: float, source = null) -> void:
	if not alive or main == null or main.game_ended:
		return
	health -= amount
	if main.hud:
		main.hud.flash_damage()
	if health <= 0.0:
		_die()


func _die() -> void:
	alive = false
	health = 0.0
	weapon.visible = false
	if weapon_anim != null:
		weapon_anim.stop()
	if flash_light != null:
		flash_light.light_energy = 0.0
	velocity = Vector3.ZERO
	respawn_timer = 4.0
	camera.rotation.z = 0.35
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if main:
		main.on_player_died()


func _respawn() -> void:
	global_position = Vector3(0, 0, 30)
	rotation.y = 0.0
	pitch = 0.0
	recoil = 0.0
	camera.rotation.x = 0.0
	camera.rotation.z = 0.0
	health = max_health
	ammo = MAG_SIZE
	reserve = MAX_RESERVE
	grenades = 3
	reloading = false
	alive = true
	weapon.visible = true
	if weapon_anim != null:
		weapon_anim.play("Armature|Idle")
	velocity = Vector3.ZERO
	if main:
		if main.hud:
			main.hud.hide_death()
		if main.game_started and not main.paused and not main.game_ended:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
