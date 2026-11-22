extends Node3D

const GRAVITY := 22.0
const RADIUS := 7.5
const MAX_DAMAGE := 95.0
const FUSE_TIME := 2.4
const EXPLOSION_SOUND = preload("res://assets/audio/explosion.wav")

var main = null
var velocity := Vector3.ZERO
var fuse := FUSE_TIME
var exploded := false
var spin := Vector3.ZERO
var mesh: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D


func _ready() -> void:
	spin = Vector3(randf_range(-9.0, 9.0), randf_range(-5.0, 5.0), randf_range(-9.0, 9.0))
	_build()


func _build() -> void:
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 10
	sm.rings = 6
	mesh.mesh = sm

	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.26, 0.16)
	mat.metallic = 0.3
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.05)
	mat.emission_energy_multiplier = 0.0
	mesh.material_override = mat
	add_child(mesh)

	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.096
	bm.bottom_radius = 0.096
	bm.height = 0.035
	bm.radial_segments = 10
	band.mesh = bm
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.10, 0.10, 0.09)
	band_mat.roughness = 0.8
	band.material_override = band_mat
	mesh.add_child(band)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.10)
	light.light_energy = 0.0
	light.omni_range = 3.5
	add_child(light)


func _physics_process(delta: float) -> void:
	if exploded:
		return

	fuse -= delta

	if mesh != null:
		mesh.rotation += spin * delta
	var blink := 0.0
	if fuse < 1.2:
		blink = 3.0 if int(fuse * 12.0) % 2 == 0 else 0.0
	if mat != null:
		mat.emission_energy_multiplier = blink
	if light != null:
		light.light_energy = blink * 0.8

	if fuse <= 0.0:
		_explode()
		return

	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	if main != null and main.player != null:
		query.exclude = [main.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		global_position = hit.position + hit.normal * 0.075
		velocity = velocity.bounce(hit.normal) * 0.42
		if velocity.length() < 1.2:
			velocity = Vector3.ZERO
	else:
		global_position = to
		if global_position.y < 0.075:
			global_position.y = 0.075
			velocity.y = abs(velocity.y) * 0.4
			velocity.x *= 0.75
			velocity.z *= 0.75
			if velocity.length() < 1.2:
				velocity = Vector3.ZERO


func _explode() -> void:
	if exploded:
		return
	exploded = true

	var pos := global_position
	var source = null
	if main != null:
		source = main.player
		for b in main.bots:
			if b != null and is_instance_valid(b) and b.alive:
				var bp: Vector3 = b.global_position + Vector3(0.0, 0.8, 0.0)
				var d := pos.distance_to(bp)
				if d < RADIUS:
					var dmg: float = MAX_DAMAGE * (1.0 - d / RADIUS)
					b.take_damage(max(dmg, 8.0), source)

		if main.player != null and main.player.alive:
			var pp: Vector3 = main.player.global_position + Vector3(0.0, 0.9, 0.0)
			var pd := pos.distance_to(pp)
			if pd < RADIUS:
				var pdmg: float = MAX_DAMAGE * 0.55 * (1.0 - pd / RADIUS)
				main.player.take_damage(pdmg, source)

		_spawn_effect(pos)

	queue_free()


func _spawn_effect(pos: Vector3) -> void:
	var fx := Node3D.new()
	main.add_child(fx)
	fx.global_position = pos

	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 8
	sphere.mesh = sm

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.62, 0.18, 0.9)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.42, 0.08)
	m.emission_energy_multiplier = 8.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere.material_override = m
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(sphere)

	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 10.0
	l.omni_range = 18.0
	fx.add_child(l)

	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sphere, "scale", Vector3.ONE * 7.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sphere, "transparency", 1.0, 0.38)
	tw.tween_property(l, "light_energy", 0.0, 0.38)

	var snd := AudioStreamPlayer3D.new()
	snd.stream = EXPLOSION_SOUND
	snd.volume_db = 1.0
	snd.unit_size = 22.0
	snd.max_distance = 120.0
	snd.pitch_scale = randf_range(0.95, 1.05)
	fx.add_child(snd)
	snd.play()

	get_tree().create_timer(1.6).timeout.connect(fx.queue_free)
