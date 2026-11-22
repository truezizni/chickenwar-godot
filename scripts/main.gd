extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const BOT_SCRIPT = preload("res://scripts/bot.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const SETTINGS_PATH := "user://chickenwar_settings.cfg"

var player = null
var bots: Array = []
var bots_spawned := false
var ally_count := 3
var enemy_count := 4
var ai_difficulty := 1
var settings_path := SETTINGS_PATH
var hud = null
var capture_progress := 0.0
var blue_in_zone := 0
var red_in_zone := 0
var game_started := false
var paused := false
var game_ended := false
var kills := 0
var deaths := 0
var test_mode := false
var test_menu := false
var test_ads := false
var test_fire := false
var test_reload := false
var input_debug := false
var ai_diag := false
var menu_test := false
var override_allies := -1
var override_enemies := -1
var override_difficulty := -1
var diag_timer := 0.0
var diag_elapsed := 0.0
var debug_timer := 0.0
var screenshot_path := ""
var rng := RandomNumberGenerator.new()

var flag_material: StandardMaterial3D
var ring_material: StandardMaterial3D
var beacon_material: StandardMaterial3D
var flag_node: MeshInstance3D
var house_centers: Array = []


func _ready() -> void:
	rng.seed = 20261122
	_parse_args()
	_load_settings()
	if test_mode:
		ally_count = 3
		enemy_count = 4
		ai_difficulty = 1
		if override_allies >= 0:
			ally_count = clampi(override_allies, 0, 8)
		if override_enemies >= 0:
			enemy_count = clampi(override_enemies, 1, 12)
		if override_difficulty >= 0:
			ai_difficulty = clampi(override_difficulty, 0, 2)
	_setup_environment()
	_build_world()
	_spawn_player()
	_setup_hud()

	if test_mode:
		if test_menu:
			if screenshot_path != "" and DisplayServer.get_name() != "headless":
				_capture_menu_screenshot()
			return
		if menu_test:
			await _run_menu_test()
			return
		_spawn_bots()
		player.global_position = Vector3(0, 0, 19)
		player.rotation.y = 0.0
		player.pitch = -0.04
		for b in bots:
			b.fire_timer = 4.0
		start_game(true)
		await get_tree().process_frame
		await get_tree().process_frame
		player.test_ads = test_ads
		player.test_fire = test_fire
		if test_reload:
			player.ammo = 10
			get_tree().create_timer(1.0).timeout.connect(player._start_reload)
		if ai_diag:
			_print_ai_diag()
			diag_timer = 4.0
		if screenshot_path != "" and DisplayServer.get_name() != "headless":
			_capture_screenshot()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--test":
			test_mode = true
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.substr(arg.find("=") + 1)
		elif arg == "--ads":
			test_ads = true
		elif arg == "--menu":
			test_menu = true
		elif arg == "--inputdebug":
			input_debug = true
		elif arg == "--fire":
			test_fire = true
		elif arg == "--reload":
			test_reload = true
		elif arg == "--aidiag":
			ai_diag = true
		elif arg == "--menutest":
			menu_test = true
		elif arg.begins_with("--allies="):
			override_allies = int(arg.substr(arg.find("=") + 1))
		elif arg.begins_with("--enemies="):
			override_enemies = int(arg.substr(arg.find("=") + 1))
		elif arg.begins_with("--difficulty="):
			override_difficulty = int(arg.substr(arg.find("=") + 1))
		elif arg.begins_with("--settings="):
			settings_path = arg.substr(arg.find("=") + 1)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.40, 0.62)
	sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.84)
	sky_mat.ground_bottom_color = Color(0.16, 0.20, 0.14)
	sky_mat.ground_horizon_color = Color(0.52, 0.60, 0.48)
	sky_mat.sun_angle_max = 28.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.63, 0.73, 0.70)
	env.fog_density = 0.006
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.04
	add_child(sun)


func _build_world() -> void:
	_add_ground()
	_add_road()
	_add_capture_zone()

	house_centers = [
		Vector2(-16, 11), Vector2(16, 13), Vector2(-18, -12),
		Vector2(18, -14), Vector2(10, 21)
	]
	add_house(-16, 11, 7.5, 6.5, 3.2)
	add_house(16, 13, 8.0, 6.0, 3.6)
	add_house(-18, -12, 7.0, 7.0, 3.4)
	add_house(18, -14, 8.0, 6.5, 3.2)
	add_house(10, 21, 6.0, 5.0, 3.0)

	add_sandbags(-9, 0, 5.0, false)
	add_sandbags(9, 0, 5.0, false)
	add_sandbags(0, 9, 5.0, true)
	add_sandbags(0, -9, 5.0, true)
	add_sandbags(-13, 6, 3.5, true)
	add_sandbags(13, -6, 3.5, true)

	add_crate(Vector3(6, 0, 4), 1.1)
	add_crate(Vector3(-6, 0, -4), 1.1)
	add_crate(Vector3(12, 0, -3), 1.0)
	add_crate(Vector3(-12, 0, 3), 1.0)
	add_crate(Vector3(4, 0, -12), 1.2)
	add_crate(Vector3(-4, 0, 12), 1.2)
	add_crate(Vector3(10, 0, 10), 1.0)
	add_crate(Vector3(-10, 0, -10), 1.0)
	add_crate(Vector3(4.5, 0, 14), 1.3)
	add_crate(Vector3(-4.5, 0, -14), 1.3)

	_scatter_trees()
	_scatter_bushes_and_rocks()
	_add_hills()


func _add_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 0.2, 120)
	cs.shape = bs
	cs.position.y = -0.1
	body.add_child(cs)

	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	mi.mesh = pm

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.025
	noise.fractal_octaves = 3

	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.55, 0.32)
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(8, 8, 1)
	mat.roughness = 1.0
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _add_road() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(7, 115)
	mi.mesh = pm
	mi.position.y = 0.02
	mi.material_override = make_material(Color(0.36, 0.30, 0.21), 1.0)
	add_child(mi)

	var line_mat := make_material(Color(0.75, 0.72, 0.55), 1.0)
	for z in range(-50, 51, 6):
		_add_mesh_box(self, Vector3(0, 0.03, z), Vector3(0.12, 0.01, 2.2), line_mat, false)


func _add_capture_zone() -> void:
	var zone := Node3D.new()
	zone.name = "CaptureZone"
	add_child(zone)

	ring_material = StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.85, 0.85, 0.80)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.85, 0.85, 0.80)
	ring_material.emission_energy_multiplier = 2.0

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 5.7
	torus.outer_radius = 6.0
	torus.rings = 64
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = 0.06
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(ring)

	var disc := MeshInstance3D.new()
	var dcyl := CylinderMesh.new()
	dcyl.top_radius = 5.8
	dcyl.bottom_radius = 5.8
	dcyl.height = 0.02
	dcyl.radial_segments = 48
	disc.mesh = dcyl
	disc.position.y = 0.02
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.85, 0.85, 0.80, 0.07)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(disc)

	var pole := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.05
	pcyl.bottom_radius = 0.08
	pcyl.height = 4.2
	pole.mesh = pcyl
	pole.position.y = 2.1
	pole.material_override = make_material(Color(0.18, 0.18, 0.16), 0.6)
	zone.add_child(pole)

	flag_node = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 1.1)
	flag_node.mesh = quad
	flag_node.position = Vector3(0.85, 3.6, 0)
	flag_material = StandardMaterial3D.new()
	flag_material.albedo_color = Color(0.9, 0.9, 0.85)
	flag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flag_node.material_override = flag_material
	zone.add_child(flag_node)

	var beacon := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.35
	bcyl.bottom_radius = 0.35
	bcyl.height = 10.0
	bcyl.radial_segments = 12
	beacon.mesh = bcyl
	beacon.position.y = 5.0
	beacon_material = StandardMaterial3D.new()
	beacon_material.albedo_color = Color(0.85, 0.85, 0.80, 0.10)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(0.85, 0.85, 0.80)
	beacon_material.emission_energy_multiplier = 1.0
	beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = beacon_material
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(beacon)


func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.main = self
	player.position = Vector3(0, 0, 30)
	add_child(player)


func _spawn_bots() -> void:
	if bots_spawned:
		return
	bots_spawned = true

	var blue_spawns := _make_spawn_points(Vector3(0, 0, 28), ally_count, 1.0)
	var red_spawns := _make_spawn_points(Vector3(0, 0, -28), enemy_count, -1.0)

	for i in range(ally_count):
		var b = BOT_SCRIPT.new("blue", blue_spawns[i])
		b.main = self
		b.player = player
		b.bot_name = "СОЮЗНИК-" + str(i + 1)
		b.difficulty = ai_difficulty
		b.ai_role = _role_for("blue", i)
		b.slot = i
		b.team_size = ally_count
		add_child(b)
		bots.append(b)

	for i in range(enemy_count):
		var b = BOT_SCRIPT.new("red", red_spawns[i])
		b.main = self
		b.player = player
		b.bot_name = "ПЕТУХ-" + str(i + 1)
		b.difficulty = ai_difficulty
		b.ai_role = _role_for("red", i)
		b.slot = i
		b.team_size = enemy_count
		add_child(b)
		bots.append(b)

	if test_mode:
		for i in range(ally_count):
			var a_row := floori(float(i) / 4.0)
			var a_col := i % 4
			bots[i].global_position = Vector3(
				(float(a_col) - 1.5) * 2.4, 0.0, 14.0 + float(a_row) * 2.6
			)
			bots[i].spawn_pos = bots[i].global_position
			bots[i].fire_timer = 4.0
		for i in range(enemy_count):
			var e_row := floori(float(i) / 4.0)
			var e_col := i % 4
			var b = bots[ally_count + i]
			b.global_position = Vector3(
				(float(e_col) - 1.5) * 2.4, 0.0, -10.0 - float(e_row) * 2.6
			)
			b.spawn_pos = b.global_position
			b.fire_timer = 4.0


func _make_spawn_points(center: Vector3, count: int, z_sign: float) -> Array:
	var points: Array = []
	var cols := 4
	for i in range(count):
		var row := floori(float(i) / float(cols))
		var col := i % cols
		var x := (float(col) - (float(cols) - 1.0) * 0.5) * 2.6
		var z := center.z + z_sign * float(row) * 2.5
		points.append(Vector3(center.x + x, 0.0, z))
	return points


func _role_for(team_name: String, index: int) -> String:
	if team_name == "blue":
		if index == 0:
			return "escort"
		match index % 4:
			2:
				return "support"
			3:
				return "flank"
			_:
				return "assault"
	match index % 4:
		1:
			return "support"
		2:
			return "flank"
		_:
			return "assault"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	ally_count = clampi(int(cfg.get_value("match", "allies", ally_count)), 0, 8)
	enemy_count = clampi(int(cfg.get_value("match", "enemies", enemy_count)), 1, 12)
	ai_difficulty = clampi(int(cfg.get_value("match", "ai_difficulty", ai_difficulty)), 0, 2)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("match", "allies", ally_count)
	cfg.set_value("match", "enemies", enemy_count)
	cfg.set_value("match", "ai_difficulty", ai_difficulty)
	cfg.save(settings_path)


func change_ally_count(delta: int) -> void:
	ally_count = clampi(ally_count + delta, 0, 8)
	_save_settings()
	if hud != null:
		hud.refresh_settings()


func change_enemy_count(delta: int) -> void:
	enemy_count = clampi(enemy_count + delta, 1, 12)
	_save_settings()
	if hud != null:
		hud.refresh_settings()


func cycle_difficulty() -> void:
	ai_difficulty = (ai_difficulty + 1) % 3
	_save_settings()
	if hud != null:
		hud.refresh_settings()


func set_difficulty(value: int) -> void:
	ai_difficulty = clampi(value, 0, 2)
	_save_settings()
	if hud != null:
		hud.refresh_settings()


func get_difficulty_name() -> String:
	match ai_difficulty:
		0:
			return "ЛЁГКИЙ"
		2:
			return "СЛОЖНЫЙ"
		_:
			return "НОРМАЛЬНЫЙ"


func get_team_alive(team_name: String) -> int:
	var n := 0
	if team_name == "blue" and player != null and player.alive:
		n += 1
	for b in bots:
		if is_instance_valid(b) and b.alive and b.team == team_name:
			n += 1
	return n


func _setup_hud() -> void:
	hud = HUD_SCRIPT.new()
	hud.main = self
	add_child(hud)
	hud.setup(player)


func _run_menu_test() -> void:
	settings_path = "user://chickenwar_settings_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	ally_count = 3
	enemy_count = 4
	ai_difficulty = 1
	hud.refresh_settings()
	print("MENUTEST init allies=%d/%s enemies=%d/%s diff=%d/%s" % [
		ally_count, hud.allies_value.text, enemy_count, hud.enemies_value.text,
		ai_difficulty, get_difficulty_name()
	])

	hud.allies_plus_button.pressed.emit()
	hud.enemies_minus_button.pressed.emit()
	hud.difficulty_buttons[2].pressed.emit()
	print("MENUTEST after clicks allies=%d/%s enemies=%d/%s diff=%d/%s" % [
		ally_count, hud.allies_value.text, enemy_count, hud.enemies_value.text,
		ai_difficulty, get_difficulty_name()
	])

	_save_settings()
	var cfg := ConfigFile.new()
	var reload_err := cfg.load(settings_path)
	print("MENUTEST persisted load_err=%d allies=%d enemies=%d diff=%d" % [
		reload_err, int(cfg.get_value("match", "allies", -1)),
		int(cfg.get_value("match", "enemies", -1)),
		int(cfg.get_value("match", "ai_difficulty", -1))
	])

	hud.play_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var expected_bots := ally_count + enemy_count
	print("MENUTEST play started=%s bots=%d/%d menu_visible=%s hud_visible=%s" % [
		str(game_started), bots.size(), expected_bots,
		str(hud.start_overlay.visible), str(hud.hud_root.visible)
	])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	var pass_ok: bool = (
		game_started and bots.size() == expected_bots and not hud.start_overlay.visible
		and hud.hud_root.visible and reload_err == OK
		and int(cfg.get_value("match", "allies", -1)) == 4
		and int(cfg.get_value("match", "enemies", -1)) == 3
		and int(cfg.get_value("match", "ai_difficulty", -1)) == 2
	)
	print("MENUTEST RESULT ", "OK" if pass_ok else "FAIL")
	get_tree().quit()


func _print_ai_diag() -> void:
	var parts: Array = []
	for b in bots:
		if not is_instance_valid(b):
			continue
		var tgt := "none"
		if b.target != null and is_instance_valid(b.target):
			tgt = "PLAYER" if b.target == player else str(b.target.bot_name)
		var player_probe := ""
		if player != null and b.team == "red":
			var to_player: Vector3 = player.global_position - b.global_position
			to_player.y = 0.0
			var fov_dot := 1.0
			if to_player.length() > 0.1:
				fov_dot = b.forward_dir().dot(to_player.normalized())
			player_probe = " player_los=%s fov_dot=%.2f" % [
				str(b.has_los(player)), fov_dot
			]
		parts.append("%s/%s hp=%.0f %s shots=%d cover=%d tgt=%s vis=%s pos=(%.0f,%.0f)%s" % [
			b.bot_name, b.ai_role, b.health, "ALIVE" if b.alive else "DEAD",
			b.debug_shots, b.debug_cover_uses, tgt, str(b.target_visible),
			b.global_position.x, b.global_position.z, player_probe
		])
	print("AIDIAG t=%.1f cap=%.0f blue=%d red=%d spawned=%d" % [
		diag_elapsed, capture_progress, get_team_alive("blue"),
		get_team_alive("red"), bots.size()
	])
	if player != null:
		print("AIDIAG PLAYER hp=%.0f alive=%s pos=(%.1f,%.1f)" % [
			player.health, str(player.alive), player.global_position.x,
			player.global_position.z
		])
	for line in parts:
		print("AIDIAG   ", line)


func start_game(auto := false) -> void:
	if game_started:
		return
	_spawn_bots()
	game_started = true
	paused = false
	if player != null:
		player.fire_timer = 0.35
		player.grenade_cooldown = 0.35
	if not auto and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hud:
		hud.hide_start()
	if input_debug:
		print("START GAME auto=", auto, " mouse_mode=", Input.mouse_mode, " display=", DisplayServer.get_name())


func pause_game() -> void:
	if not game_started or game_ended or paused:
		return
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hud:
		hud.show_pause()


func resume_game() -> void:
	if not game_started or game_ended:
		return
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hud:
		hud.hide_pause()


func end_game(victory: bool) -> void:
	if game_ended:
		return
	game_ended = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ai_diag:
		print("AIDIAG GAME END victory=%s kills=%d deaths=%d cap=%.0f" % [
			str(victory), kills, deaths, capture_progress
		])
		_print_ai_diag()
	if hud:
		hud.show_end(victory, kills, deaths)


func _input(event: InputEvent) -> void:
	if game_started and not paused and not game_ended:
		if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if input_debug:
				print("MOUSE recaptured by click: ", Input.mouse_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and game_started and not game_ended:
		if paused:
			resume_game()
		else:
			pause_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and game_started and not paused and not game_ended and not test_mode:
		pause_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and game_started and not paused and not game_ended:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if input_debug:
			print("MOUSE recaptured on focus: ", Input.mouse_mode)


func _process(delta: float) -> void:
	if input_debug:
		debug_timer -= delta
		if debug_timer <= 0.0:
			debug_timer = 1.0
			print("DBG started=", game_started, " paused=", paused, " mouse=", Input.mouse_mode, " focus=", DisplayServer.window_is_focused())
	if ai_diag and game_started:
		diag_elapsed += delta
		diag_timer -= delta
		if diag_timer <= 0.0:
			diag_timer = 4.0
			_print_ai_diag()
	if not game_started or paused or game_ended:
		return
	_update_capture(delta)
	_update_capture_visuals()
	if hud:
		hud.update_hud(delta)


func _update_capture(delta: float) -> void:
	blue_in_zone = 0
	red_in_zone = 0

	if player != null and player.alive and _in_zone(player.global_position):
		blue_in_zone += 1

	for b in bots:
		if b.alive and _in_zone(b.global_position):
			if b.team == "blue":
				blue_in_zone += 1
			else:
				red_in_zone += 1

	if blue_in_zone > 0 and red_in_zone == 0:
		capture_progress = clamp(capture_progress + 7.0 * delta * (1.0 + 0.25 * (blue_in_zone - 1)), -100.0, 100.0)
	elif red_in_zone > 0 and blue_in_zone == 0:
		capture_progress = clamp(capture_progress - 7.0 * delta * (1.0 + 0.25 * (red_in_zone - 1)), -100.0, 100.0)

	if abs(capture_progress) >= 100.0 and not ai_diag:
		end_game(capture_progress > 0.0)


func _in_zone(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).length() <= 6.0


func _update_capture_visuals() -> void:
	if flag_material == null:
		return
	var t: float = clamp(capture_progress / 100.0, -1.0, 1.0)
	var col := Color(0.90, 0.90, 0.85)
	if t >= 0.0:
		col = col.lerp(Color(0.25, 0.55, 1.0), t)
	else:
		col = col.lerp(Color(1.0, 0.28, 0.22), -t)

	flag_material.albedo_color = col
	ring_material.albedo_color = col
	ring_material.emission = col
	beacon_material.albedo_color = Color(col.r, col.g, col.b, 0.10)
	beacon_material.emission = col

	var time := Time.get_ticks_msec() * 0.001
	ring_material.emission_energy_multiplier = 1.5 + sin(time * 3.0) * 0.6
	flag_node.rotation.y = sin(time * 2.0) * 0.18


func on_player_hit(headshot: bool) -> void:
	if hud:
		hud.show_hitmarker(headshot)


func on_bot_died(bot, killer) -> void:
	if killer == player:
		kills += 1
		if hud:
			hud.add_feed("ВЫ  →  " + bot.bot_name)
	elif killer != null and killer is Node and killer.is_in_group("bots"):
		if hud:
			var prefix := "СОЮЗНИК " if killer.team == "blue" else "ВРАГ "
			hud.add_feed(prefix + killer.bot_name + "  →  " + bot.bot_name)
	else:
		if hud:
			hud.add_feed(bot.bot_name + "  →  ...")


func on_player_died() -> void:
	deaths += 1
	if hud:
		hud.add_feed("ВАС УСТРАНИЛИ")
		hud.show_death()


func spawn_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var dist := from.distance_to(to)
	if dist < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, dist)
	mi.mesh = bm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


func spawn_impact(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 6
	sm.rings = 4
	mi.mesh = sm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.65, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 6.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(0.12).timeout.connect(mi.queue_free)


func _capture_menu_screenshot() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(screenshot_path)
	print("SCREENSHOT: ", screenshot_path, " err=", err)
	get_tree().quit()


func _capture_screenshot() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	if player != null and player.weapon != null:
		print("SHOT ads=", player.ads, " test_ads=", player.test_ads, " wpos=", player.weapon.position, " wrot=", player.weapon.rotation_degrees)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(screenshot_path)
	print("SCREENSHOT: ", screenshot_path, " err=", err)
	get_tree().quit()


# ---------------------------------------------------------------------------
# World helpers
# ---------------------------------------------------------------------------

func make_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add_mesh_box(parent: Node, pos: Vector3, size: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add_static_box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)

	parent.add_child(body)
	return body


func add_house(x: float, z: float, w: float, d: float, h: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 0, z)
	add_child(g)

	var wall_mat := make_material(Color(0.55, 0.45, 0.33), 1.0)
	var trim_mat := make_material(Color(0.28, 0.22, 0.15), 1.0)
	var t := 0.3

	_add_static_box(g, Vector3(0, h * 0.5, -d * 0.5), Vector3(w, h, t), wall_mat)
	_add_static_box(g, Vector3(-w * 0.5, h * 0.5, 0), Vector3(t, h, d), wall_mat)
	_add_static_box(g, Vector3(w * 0.5, h * 0.5, 0), Vector3(t, h, d), wall_mat)

	var door_w := 1.6
	var side_w := (w - door_w) * 0.5
	_add_static_box(g, Vector3(-(door_w * 0.5 + side_w * 0.5), h * 0.5, d * 0.5), Vector3(side_w, h, t), wall_mat)
	_add_static_box(g, Vector3(door_w * 0.5 + side_w * 0.5, h * 0.5, d * 0.5), Vector3(side_w, h, t), wall_mat)
	_add_static_box(g, Vector3(0, h - 0.25, d * 0.5), Vector3(door_w, 0.5, t), trim_mat)

	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.0
	rm.bottom_radius = max(w, d) * 0.72
	rm.height = 2.0
	rm.radial_segments = 4
	rm.rings = 1
	roof.mesh = rm
	roof.position.y = h + 1.0
	roof.rotation.y = PI * 0.25
	roof.material_override = make_material(Color(0.22, 0.16, 0.12), 1.0)
	g.add_child(roof)

	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.90, 0.75, 0.40)
	win_mat.emission_enabled = true
	win_mat.emission = Color(0.90, 0.60, 0.20)
	win_mat.emission_energy_multiplier = 1.4

	for wx in [-w * 0.30, w * 0.30]:
		_add_mesh_box(g, Vector3(wx, h * 0.62, d * 0.5 + 0.16), Vector3(0.7, 0.7, 0.05), win_mat, false)
		_add_mesh_box(g, Vector3(wx, h * 0.62, -d * 0.5 - 0.16), Vector3(0.7, 0.7, 0.05), win_mat, false)
	_add_mesh_box(g, Vector3(-w * 0.5 - 0.16, h * 0.62, 0), Vector3(0.05, 0.7, 0.7), win_mat, false)
	_add_mesh_box(g, Vector3(w * 0.5 + 0.16, h * 0.62, 0), Vector3(0.05, 0.7, 0.7), win_mat, false)

	add_crate(Vector3(x + w * 0.22, 0, z - d * 0.22), 0.9)


func add_sandbags(x: float, z: float, length: float, along_x: bool) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 0, z)
	add_child(g)

	var mat := make_material(Color(0.56, 0.51, 0.36), 1.0)
	var n := int(length / 0.7)
	if n < 2:
		n = 2

	for i in range(n):
		var off := (i - (n - 1) * 0.5) * 0.7
		var p := Vector3(off, 0.22, 0) if along_x else Vector3(0, 0.22, off)
		var s := Vector3(0.68, 0.44, 0.5) if along_x else Vector3(0.5, 0.44, 0.68)
		_add_mesh_box(g, p, s, mat)
		if i % 2 == 1:
			var p2 := p + Vector3(0, 0.44, 0)
			var s2 := Vector3(0.60, 0.40, 0.45) if along_x else Vector3(0.45, 0.40, 0.60)
			_add_mesh_box(g, p2, s2, mat)

	var body := StaticBody3D.new()
	body.position = Vector3(0, 0.5, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, 1.0, 0.7) if along_x else Vector3(0.7, 1.0, length)
	cs.shape = bs
	body.add_child(cs)
	g.add_child(body)


func add_crate(pos: Vector3, s: float = 1.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, s * 0.5, 0)
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(s, s, s)
	mi.mesh = bm
	mi.material_override = make_material(Color(0.45, 0.32, 0.18), 1.0)
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(s, s, s)
	cs.shape = bs
	body.add_child(cs)

	add_child(body)


func add_tree(pos: Vector3, s: float) -> void:
	var root := StaticBody3D.new()
	root.position = pos
	root.collision_layer = 1
	root.collision_mask = 0

	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38 * s
	cyl.height = 4.0 * s
	cs.shape = cyl
	cs.position.y = 2.0 * s
	root.add_child(cs)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.22 * s
	tm.bottom_radius = 0.32 * s
	tm.height = 2.2 * s
	tm.radial_segments = 7
	trunk.mesh = tm
	trunk.position.y = 1.1 * s
	trunk.material_override = make_material(Color(0.32, 0.22, 0.13), 1.0)
	root.add_child(trunk)

	var green := Color(0.16, 0.30, 0.16).lerp(Color(0.24, 0.40, 0.20), rng.randf())
	var fmat := make_material(green, 1.0)
	for i in range(3):
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = (1.6 - i * 0.35) * s
		cm.height = 1.7 * s
		cm.radial_segments = 8
		cone.mesh = cm
		cone.position.y = (2.1 + i * 0.85) * s
		cone.material_override = fmat
		root.add_child(cone)

	add_child(root)


func add_bush(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 6
	sm.rings = 4
	mi.mesh = sm
	mi.position = pos + Vector3(0, 0.25, 0)
	mi.scale = Vector3(1.3, 0.55, 1.3)
	mi.material_override = make_material(Color(0.20, 0.35, 0.18), 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func add_rock(pos: Vector3, s: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 5
	sm.rings = 3
	mi.mesh = sm
	mi.position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3(s, s * 0.55, s * 0.8)
	mi.rotation.y = rng.randf_range(0, TAU)
	mi.material_override = make_material(Color(0.40, 0.40, 0.38), 1.0)
	add_child(mi)


func _scatter_trees() -> void:
	var placed: Array = []
	var attempts := 0
	while placed.size() < 55 and attempts < 900:
		attempts += 1
		var x := rng.randf_range(-42, 42)
		var z := rng.randf_range(-42, 42)
		if abs(x) < 5.5:
			continue
		if Vector2(x, z).length() < 11.0:
			continue
		if Vector2(x, z - 30).length() < 8.0 or Vector2(x, z + 30).length() < 8.0:
			continue
		var ok := true
		for h in house_centers:
			if Vector2(x - h.x, z - h.y).length() < 8.0:
				ok = false
				break
		if not ok:
			continue
		for p in placed:
			if Vector2(x - p.x, z - p.y).length() < 3.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(x, z))
		add_tree(Vector3(x, 0, z), rng.randf_range(0.8, 1.35))


func _scatter_bushes_and_rocks() -> void:
	for i in range(35):
		var x := rng.randf_range(-40, 40)
		var z := rng.randf_range(-40, 40)
		if abs(x) < 4.0 or Vector2(x, z).length() < 8.0:
			continue
		add_bush(Vector3(x, 0, z))
	for i in range(16):
		var x := rng.randf_range(-40, 40)
		var z := rng.randf_range(-40, 40)
		if abs(x) < 4.0 or Vector2(x, z).length() < 7.0:
			continue
		add_rock(Vector3(x, 0, z), rng.randf_range(0.7, 1.5))


func _add_hills() -> void:
	for i in range(14):
		var ang := TAU * i / 14.0 + rng.randf_range(-0.12, 0.12)
		var radius := rng.randf_range(58.0, 74.0)
		var x := cos(ang) * radius
		var z := sin(ang) * radius
		var r := rng.randf_range(12.0, 22.0)
		var h := rng.randf_range(10.0, 18.0)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 8
		mi.mesh = cm
		mi.position = Vector3(x, h * 0.5 - 1.5, z)
		mi.material_override = make_material(Color(0.18, 0.27, 0.18), 1.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
