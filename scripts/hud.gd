extends CanvasLayer

var main = null
var player = null

var root: Control
var hit_lines: Array = []
var crosshair_hit_color := Color(1.0, 1.0, 1.0)
var capture_bar
var capture_label: Label
var stats_label: Label
var health_bg: ColorRect
var health_fill: ColorRect
var health_label: Label
var grenade_label: Label
var ammo_label: Label
var weapon_label: Label
var mouse_hint: Label
var feed_box: VBoxContainer
var feed_entries: Array = []
var damage_flash: ColorRect
var death_overlay: Control
var death_timer: Label
var start_overlay: Control
var pause_overlay: Control
var end_overlay: Control
var end_title: Label
var end_stats: Label

var damage_alpha := 0.0
var hit_timer := 0.0


class CaptureBar extends Control:
	var value := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var mid := w * 0.5
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.04, 0.05, 0.07, 0.62))
		if value >= 0.0:
			var fw: float = mid * clamp(value / 100.0, 0.0, 1.0)
			draw_rect(Rect2(mid, 2.0, fw, h - 4.0), Color(0.22, 0.52, 1.0, 0.92))
		else:
			var fw: float = mid * clamp(-value / 100.0, 0.0, 1.0)
			draw_rect(Rect2(mid - fw, 2.0, fw, h - 4.0), Color(1.0, 0.26, 0.20, 0.92))
		draw_line(Vector2(mid, 0.0), Vector2(mid, h), Color(1.0, 1.0, 1.0, 0.8), 2.0)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.name = "HUDRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_hud()
	_build_start()
	_build_pause()
	_build_end()
	_build_death()


func setup(p) -> void:
	player = p
	if player != null:
		health_label.text = "HP  %d" % int(player.health)
		ammo_label.text = "%d  /  %d" % [player.ammo, player.reserve]
		grenade_label.text = "ГРАНАТЫ  x%d" % player.grenades


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.8, 0.04, 0.04, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.anchor_right = 1.0
	damage_flash.anchor_bottom = 1.0
	damage_flash.offset_right = 0.0
	damage_flash.offset_bottom = 0.0
	root.add_child(damage_flash)

	for i in range(4):
		var tick := ColorRect.new()
		tick.color = crosshair_hit_color
		tick.size = Vector2(2.0, 8.0)
		tick.pivot_offset = Vector2(1.0, 4.0)
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tick)
		hit_lines.append(tick)

	capture_label = _label("ТОЧКА ЗАХВАТА", 18, Color(0.92, 0.95, 0.85), 3)
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(capture_label, 0.5, 0.0, -220.0, 14.0, 440.0, 24.0)
	root.add_child(capture_label)

	capture_bar = CaptureBar.new()
	capture_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(capture_bar, 0.5, 0.0, -180.0, 40.0, 360.0, 16.0)
	root.add_child(capture_bar)

	stats_label = _label("УБИЙСТВА  0      СМЕРТИ  0", 18, Color(0.92, 0.95, 0.85), 3)
	_anchor(stats_label, 0.0, 0.0, 24.0, 18.0, 340.0, 26.0)
	root.add_child(stats_label)

	feed_box = VBoxContainer.new()
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.alignment = BoxContainer.ALIGNMENT_END
	feed_box.add_theme_constant_override("separation", 2)
	_anchor(feed_box, 1.0, 0.0, -364.0, 16.0, 340.0, 200.0)
	root.add_child(feed_box)

	health_label = _label("HP  100", 22, Color(0.85, 1.0, 0.8), 3)
	_anchor(health_label, 0.0, 1.0, 24.0, -108.0, 260.0, 28.0)
	root.add_child(health_label)

	health_bg = ColorRect.new()
	health_bg.color = Color(0.05, 0.06, 0.05, 0.72)
	health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(health_bg, 0.0, 1.0, 24.0, -76.0, 260.0, 22.0)
	root.add_child(health_bg)

	health_fill = ColorRect.new()
	health_fill.color = Color(0.35, 0.85, 0.35)
	health_fill.position = Vector2(2.0, 2.0)
	health_fill.size = Vector2(256.0, 18.0)
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bg.add_child(health_fill)

	grenade_label = _label("ГРАНАТЫ  x3", 18, Color(0.95, 0.9, 0.7), 3)
	_anchor(grenade_label, 0.0, 1.0, 24.0, -48.0, 260.0, 24.0)
	root.add_child(grenade_label)

	weapon_label = _label("АК-КУРИЦА", 18, Color(0.9, 0.9, 0.85), 3)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor(weapon_label, 1.0, 1.0, -324.0, -108.0, 300.0, 24.0)
	root.add_child(weapon_label)

	mouse_hint = _label("КЛИКНИТЕ ПО ОКНУ, ЧТОБЫ ЗАХВАТИТЬ МЫШЬ", 20, Color(1.0, 0.9, 0.45), 4)
	mouse_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_hint.visible = false
	_anchor(mouse_hint, 0.5, 0.5, -360.0, 60.0, 720.0, 30.0)
	root.add_child(mouse_hint)

	ammo_label = _label("30  /  120", 44, Color(1.0, 1.0, 0.95), 4)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor(ammo_label, 1.0, 1.0, -324.0, -82.0, 300.0, 56.0)
	root.add_child(ammo_label)


func _build_start() -> void:
	start_overlay = _make_screen()
	start_overlay.add_child(_make_overlay(Color(0.02, 0.035, 0.025, 0.82)))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_anchor(box, 0.5, 0.5, -390.0, -230.0, 780.0, 460.0)
	start_overlay.add_child(box)

	var title := _label("CHICKEN WAR", 82, Color(1.0, 0.82, 0.30), 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("КУРИНЫЙ ФРОНТ  •  ПРОТОТИП НА GODOT", 22, Color(0.85, 0.92, 0.78), 3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_spacer(12))

	var lines := [
		"WASD — движение     SHIFT — бег     CTRL — присесть",
		"ЛКМ — стрельба     ПКМ — прицел     R — перезарядка",
		"G — граната     ESC — пауза",
		"Захватите точку в центре карты и удерживайте её до конца шкалы."
	]
	for line in lines:
		var l := _label(line, 18, Color(0.88, 0.9, 0.86), 2)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)

	var credit := _label("Модель AKM: J-Toastie  •  CC-BY 3.0  •  poly.pizza", 14, Color(0.72, 0.78, 0.70), 1)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credit)

	box.add_child(_spacer(18))
	var play := _label("НАЖМИТЕ ЛКМ ИЛИ ENTER", 26, Color(1.0, 0.95, 0.6), 4)
	play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(play)

	var tw := play.create_tween().set_loops()
	tw.tween_property(play, "modulate:a", 0.45, 0.8)
	tw.tween_property(play, "modulate:a", 1.0, 0.8)
	start_overlay.visible = true


func _build_pause() -> void:
	pause_overlay = _make_screen()
	pause_overlay.add_child(_make_overlay(Color(0.01, 0.02, 0.015, 0.68)))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_anchor(box, 0.5, 0.5, -300.0, -120.0, 600.0, 240.0)
	pause_overlay.add_child(box)

	var title := _label("ПАУЗА", 64, Color(0.95, 0.92, 0.80), 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := _label("ESC — продолжить бой", 22, Color(0.85, 0.88, 0.82), 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _build_end() -> void:
	end_overlay = _make_screen()
	end_overlay.add_child(_make_overlay(Color(0.02, 0.02, 0.02, 0.78)))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_anchor(box, 0.5, 0.5, -350.0, -170.0, 700.0, 340.0)
	end_overlay.add_child(box)

	end_title = _label("ПОБЕДА", 76, Color(0.45, 0.95, 0.45), 9)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_title)

	end_stats = _label("", 26, Color(0.92, 0.94, 0.90), 3)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_stats)

	var hint := _label("R — сыграть ещё раз", 22, Color(1.0, 0.9, 0.55), 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _build_death() -> void:
	death_overlay = _make_screen()
	death_overlay.add_child(_make_overlay(Color(0.30, 0.0, 0.0, 0.38)))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_anchor(box, 0.5, 0.5, -350.0, -80.0, 700.0, 160.0)
	death_overlay.add_child(box)

	var title := _label("ВАС УСТРАНИЛИ", 54, Color(1.0, 0.35, 0.28), 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	death_timer = _label("Возрождение через 4.0 с", 22, Color(0.95, 0.88, 0.82), 3)
	death_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(death_timer)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func hide_start() -> void:
	start_overlay.visible = false


func show_pause() -> void:
	pause_overlay.visible = true
	_hide_hitmarker()


func hide_pause() -> void:
	pause_overlay.visible = false


func show_end(victory: bool, kills: int, deaths: int) -> void:
	end_overlay.visible = true
	pause_overlay.visible = false
	death_overlay.visible = false
	_hide_hitmarker()
	damage_flash.color = Color(0.8, 0.04, 0.04, 0.0)
	if victory:
		end_title.text = "ПОБЕДА"
		end_title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45))
	else:
		end_title.text = "ПОРАЖЕНИЕ"
		end_title.add_theme_color_override("font_color", Color(1.0, 0.32, 0.26))
	end_stats.text = "УБИЙСТВА: %d      СМЕРТИ: %d" % [kills, deaths]


func show_death() -> void:
	death_overlay.visible = true
	_hide_hitmarker()
	death_timer.text = "Возрождение через 4.0 с"


func hide_death() -> void:
	death_overlay.visible = false


func flash_damage() -> void:
	damage_alpha = min(0.65, damage_alpha + 0.35)


func show_hitmarker(headshot: bool) -> void:
	hit_timer = 0.18
	crosshair_hit_color = Color(1.0, 0.30, 0.22) if headshot else Color(1.0, 1.0, 1.0)


func _hide_hitmarker() -> void:
	hit_timer = 0.0
	for t in hit_lines:
		if is_instance_valid(t):
			t.visible = false


func add_feed(text: String) -> void:
	if feed_box == null:
		return
	var l := _label(text, 16, Color(0.95, 0.95, 0.9), 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed_box.add_child(l)
	feed_entries.append(l)
	while feed_entries.size() > 6:
		var old = feed_entries.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func update_hud(delta: float) -> void:
	if player == null or main == null:
		return

	var hp_ratio: float = clamp(player.health / player.max_health, 0.0, 1.0)
	health_fill.size = Vector2(max(0.0, (health_bg.size.x - 4.0) * hp_ratio), health_bg.size.y - 4.0)
	if hp_ratio > 0.55:
		health_fill.color = Color(0.35, 0.85, 0.35)
	elif hp_ratio > 0.25:
		health_fill.color = Color(0.95, 0.75, 0.20)
	else:
		health_fill.color = Color(0.95, 0.22, 0.18)
	health_label.text = "HP  %d" % int(ceil(player.health))

	ammo_label.text = "%d  /  %d" % [player.ammo, player.reserve]
	ammo_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28) if player.ammo == 0 else Color(1.0, 1.0, 0.95))
	grenade_label.text = "ГРАНАТЫ  x%d" % player.grenades
	grenade_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50) if player.grenades <= 0 else Color(0.95, 0.9, 0.7))

	stats_label.text = "УБИЙСТВА  %d      СМЕРТИ  %d" % [main.kills, main.deaths]

	if mouse_hint != null:
		mouse_hint.visible = not main.test_mode and main.game_started and not main.paused and not main.game_ended and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED

	capture_bar.value = main.capture_progress
	capture_bar.queue_redraw()
	var prog: float = main.capture_progress
	if prog > 1.0:
		capture_label.text = "ЗАХВАТ ТОЧКИ  —  СИНИЕ  %d%%" % int(prog)
		capture_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	elif prog < -1.0:
		capture_label.text = "ЗАХВАТ ТОЧКИ  —  КРАСНЫЕ  %d%%" % int(-prog)
		capture_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
	else:
		capture_label.text = "ТОЧКА НЕЙТРАЛЬНА"
		capture_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.85))

	var hit_a: float = clamp(hit_timer / 0.18, 0.0, 1.0)
	var center := Vector2(root.size.x * 0.5, root.size.y * 0.5)
	var tick_off := 12.0
	var tick_len := 8.0
	var tick_positions := [Vector2(-tick_off, -tick_off), Vector2(tick_off, -tick_off), Vector2(-tick_off, tick_off), Vector2(tick_off, tick_off)]
	var tick_rots := [-PI * 0.25, PI * 0.25, PI * 0.25, -PI * 0.25]
	for i in range(4):
		var tick: ColorRect = hit_lines[i]
		tick.position = center + tick_positions[i] - Vector2(1.0, tick_len * 0.5)
		tick.rotation = tick_rots[i]
		tick.color = Color(crosshair_hit_color.r, crosshair_hit_color.g, crosshair_hit_color.b, hit_a)
		tick.visible = hit_a > 0.0
	hit_timer = max(0.0, hit_timer - delta)

	damage_alpha = max(0.0, damage_alpha - delta * 1.6)
	var low := 0.0
	if player.health < 30.0 and player.alive:
		low = 0.10 + sin(Time.get_ticks_msec() * 0.006) * 0.05
	var a: float = max(damage_alpha, low)
	damage_flash.color = Color(0.8, 0.04, 0.04, a)

	if death_overlay.visible:
		death_timer.text = "Возрождение через %.1f с" % max(0.0, player.respawn_timer)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if start_overlay != null and start_overlay.visible:
		var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)
		if clicked or pressed_key:
			if main != null:
				main.start_game()
			get_viewport().set_input_as_handled()
	elif end_overlay != null and end_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _label(text: String, font_size: int, color := Color(1, 1, 1), outline := 3) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _anchor(c: Control, ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_top = oy
	c.offset_right = ox + w
	c.offset_bottom = oy + h


func _make_screen() -> Control:
	var screen := Control.new()
	screen.anchor_right = 1.0
	screen.anchor_bottom = 1.0
	screen.offset_right = 0.0
	screen.offset_bottom = 0.0
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false
	root.add_child(screen)
	return screen


func _make_overlay(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	return rect


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
