extends CanvasLayer

var main = null
var player = null

var root: Control
var hud_root: Control
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
var settings_panel: PanelContainer
var allies_value: Label
var enemies_value: Label
var allies_minus_button: Button
var allies_plus_button: Button
var enemies_minus_button: Button
var enemies_plus_button: Button
var difficulty_buttons: Array = []
var play_button: Button
var leave_button: Button
var ui_font: SystemFont
var ui_font_bold: SystemFont
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


class MenuBackdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.020, 0.015, 0.72))
		draw_circle(Vector2(size.x * 0.16, size.y * 0.30), size.y * 0.42, Color(0.72, 0.84, 0.48, 0.07))
		draw_circle(Vector2(size.x * 0.82, size.y * 0.72), size.y * 0.48, Color(0.95, 0.66, 0.28, 0.055))
		draw_circle(Vector2(size.x * 0.65, size.y * 0.16), 90.0, Color(0.85, 0.93, 0.70, 0.045))


func _ready() -> void:
	layer = 10
	ui_font = _make_system_font(400)
	ui_font_bold = _make_system_font(700)
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


func _make_system_font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Variable Display", "Segoe UI", "Roboto", "Noto Sans", "Arial"])
	f.font_weight = weight
	return f


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

	stats_label = _label("УБИЙСТВА  0      СМЕРТИ  0", 17, Color(0.92, 0.95, 0.85), 3)
	_anchor(stats_label, 0.0, 0.0, 24.0, 16.0, 380.0, 54.0)
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

	hud_root = Control.new()
	hud_root.anchor_right = 1.0
	hud_root.anchor_bottom = 1.0
	hud_root.offset_right = 0.0
	hud_root.offset_bottom = 0.0
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_root)
	for child in root.get_children():
		if child != hud_root:
			root.remove_child(child)
			hud_root.add_child(child)


func _build_start() -> void:
	start_overlay = _make_screen()

	var backdrop := MenuBackdrop.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_overlay.add_child(backdrop)

	var layout := HBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 76)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(layout, 0.5, 0.5, -570.0, -270.0, 1140.0, 540.0)
	start_overlay.add_child(layout)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(left)

	var accent_row := HBoxContainer.new()
	accent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(accent_row)
	var accent := Panel.new()
	accent.custom_minimum_size = Vector2(52.0, 5.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent_style := StyleBoxFlat.new()
	accent_style.bg_color = Color(0.96, 0.76, 0.36)
	accent_style.set_corner_radius_all(3)
	accent.add_theme_stylebox_override("panel", accent_style)
	accent_row.add_child(accent)
	left.add_child(_spacer(18))

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(title_row)

	var t1 := _label("CHICKEN", 78, Color(0.97, 0.96, 0.90), 9)
	t1.add_theme_font_override("font", ui_font_bold)
	title_row.add_child(t1)

	var t2 := _label("WAR", 78, Color(0.97, 0.77, 0.36), 9)
	t2.add_theme_font_override("font", ui_font_bold)
	title_row.add_child(t2)

	left.add_child(_spacer(8))
	var tag := _label("КУРИНЫЙ ФРОНТ   •   3D FPS", 17, Color(0.80, 0.88, 0.72), 2)
	tag.add_theme_font_override("font", ui_font_bold)
	left.add_child(tag)

	left.add_child(_spacer(14))
	var desc := _label("Захвати точку в центре карты и удержи её до победы.", 16, Color(0.80, 0.85, 0.77), 2)
	left.add_child(desc)

	left.add_child(_spacer(36))
	play_button = _primary_button("ИГРАТЬ   →", 316.0, 62.0)
	play_button.pressed.connect(_on_play_pressed)
	left.add_child(play_button)

	left.add_child(_spacer(10))
	leave_button = _text_button("ВЫЙТИ", 316.0, 46.0)
	leave_button.pressed.connect(_on_leave_pressed)
	left.add_child(leave_button)

	left.add_child(_spacer(30))
	var controls := _label("WASD — движение    ЛКМ — огонь    R — перезарядка    G — граната    ESC — пауза", 13, Color(0.72, 0.78, 0.68), 1)
	left.add_child(controls)
	left.add_child(_spacer(4))
	var credit := _label("AKM: J-Toastie  •  CC-BY 3.0  •  poly.pizza", 12, Color(0.58, 0.64, 0.56), 1)
	left.add_child(credit)

	_build_settings_panel(layout)

	if hud_root != null:
		hud_root.visible = false
	start_overlay.visible = true
	refresh_settings()


func _build_settings_panel(parent: Control) -> void:
	settings_panel = PanelContainer.new()
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.custom_minimum_size = Vector2(432.0, 0.0)
	settings_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.120, 0.095, 0.96)
	style.border_color = Color(0.74, 0.86, 0.62, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(28)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 22.0
	settings_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(settings_panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_theme_constant_override("separation", 15)
	settings_panel.add_child(col)

	var overline := _label("ПАРАМЕТРЫ МАТЧА", 12, Color(0.76, 0.88, 0.62), 1)
	overline.add_theme_font_override("font", ui_font_bold)
	col.add_child(overline)

	var heading := _label("НАСТРОЙКИ БОЯ", 26, Color(0.97, 0.96, 0.90), 3)
	heading.add_theme_font_override("font", ui_font_bold)
	col.add_child(heading)

	col.add_child(_divider())
	col.add_child(_setting_row("СОЮЗНИКИ", _build_stepper(true)))
	col.add_child(_setting_row("ВРАГИ", _build_stepper(false)))

	var diff_label := _label("СЛОЖНОСТЬ ИИ", 15, Color(0.80, 0.85, 0.76), 2)
	diff_label.add_theme_font_override("font", ui_font_bold)
	col.add_child(diff_label)
	col.add_child(_build_difficulty_segment())

	col.add_child(_divider())
	var hint := _label("ИИ использует укрытия, фланги и память о цели.", 13, Color(0.66, 0.74, 0.62), 1)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var save_hint := _label("Настройки сохраняются автоматически", 12, Color(0.54, 0.62, 0.51), 1)
	col.add_child(save_hint)


func _setting_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 12)
	var l := _label(text, 17, Color(0.90, 0.93, 0.86), 2)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(control)
	return row


func _build_stepper(is_allies: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.custom_minimum_size = Vector2(152.0, 44.0)
	pill.add_theme_stylebox_override("panel", _pill_style(Color(0.145, 0.195, 0.150, 1.0), 22.0))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 0)
	pill.add_child(row)

	var minus := _icon_button("-")
	var value := _label("0", 20, Color(0.97, 0.96, 0.90), 2)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(52.0, 36.0)
	value.add_theme_font_override("font", ui_font_bold)
	var plus := _icon_button("+")

	if is_allies:
		allies_value = value
		allies_minus_button = minus
		allies_plus_button = plus
		minus.pressed.connect(_on_allies_minus)
		plus.pressed.connect(_on_allies_plus)
	else:
		enemies_value = value
		enemies_minus_button = minus
		enemies_plus_button = plus
		minus.pressed.connect(_on_enemies_minus)
		plus.pressed.connect(_on_enemies_plus)

	row.add_child(minus)
	row.add_child(value)
	row.add_child(plus)
	return pill


func _build_difficulty_segment() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 6)
	var labels := ["ЛЁГКИЙ", "СРЕДНИЙ", "СЛОЖНЫЙ"]
	for i in range(labels.size()):
		var b := Button.new()
		b.text = labels[i]
		b.custom_minimum_size = Vector2(0.0, 40.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", ui_font_bold)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_difficulty_selected.bind(i))
		difficulty_buttons.append(b)
		row.add_child(b)
	return row


func _primary_button(text: String, width: float, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, height)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", ui_font_bold)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color(0.075, 0.115, 0.055))
	b.add_theme_color_override("font_hover_color", Color(0.060, 0.095, 0.040))
	b.add_theme_color_override("font_pressed_color", Color(0.040, 0.070, 0.025))
	b.add_theme_stylebox_override("normal", _action_style(Color(0.80, 0.90, 0.64), height * 0.5, 28.0))
	b.add_theme_stylebox_override("hover", _action_style(Color(0.87, 0.95, 0.72), height * 0.5, 28.0))
	b.add_theme_stylebox_override("pressed", _action_style(Color(0.68, 0.80, 0.52), height * 0.5, 28.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _text_button(text: String, width: float, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, height)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", ui_font_bold)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.86, 0.90, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.94))
	b.add_theme_color_override("font_pressed_color", Color(0.96, 0.76, 0.36))
	b.add_theme_stylebox_override("normal", _action_style(Color(0, 0, 0, 0), height * 0.5, 24.0))
	b.add_theme_stylebox_override("hover", _action_style(Color(1, 1, 1, 0.07), height * 0.5, 24.0))
	b.add_theme_stylebox_override("pressed", _action_style(Color(1, 1, 1, 0.11), height * 0.5, 24.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _icon_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(36.0, 36.0)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", ui_font_bold)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.94))
	b.add_theme_color_override("font_pressed_color", Color(0.96, 0.76, 0.36))
	b.add_theme_stylebox_override("normal", _round_style(Color(0, 0, 0, 0), 18.0))
	b.add_theme_stylebox_override("hover", _round_style(Color(1, 1, 1, 0.09), 18.0))
	b.add_theme_stylebox_override("pressed", _round_style(Color(1, 1, 1, 0.13), 18.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1.0, 1.0, 1.0, 0.075)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _pill_style(bg: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = 4.0
	s.content_margin_right = 4.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


func _action_style(bg: Color, radius: float, pad: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


func _round_style(bg: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = 0.0
	s.content_margin_right = 0.0
	s.content_margin_top = 0.0
	s.content_margin_bottom = 0.0
	return s



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

func refresh_settings() -> void:
	if main == null:
		return
	if allies_value != null:
		allies_value.text = str(main.ally_count)
	if enemies_value != null:
		enemies_value.text = str(main.enemy_count)
	for i in range(difficulty_buttons.size()):
		var b: Button = difficulty_buttons[i]
		var selected: bool = i == main.ai_difficulty
		var normal_bg := Color(0.80, 0.90, 0.64) if selected else Color(0.145, 0.195, 0.150, 1.0)
		var hover_bg := Color(0.87, 0.95, 0.72) if selected else Color(0.21, 0.27, 0.20, 1.0)
		var pressed_bg := Color(0.68, 0.80, 0.52) if selected else Color(0.24, 0.31, 0.23, 1.0)
		b.add_theme_stylebox_override("normal", _action_style(normal_bg, 20.0, 4.0))
		b.add_theme_stylebox_override("hover", _action_style(hover_bg, 20.0, 4.0))
		b.add_theme_stylebox_override("pressed", _action_style(pressed_bg, 20.0, 4.0))
		if selected:
			b.add_theme_color_override("font_color", Color(0.075, 0.115, 0.055))
			b.add_theme_color_override("font_hover_color", Color(0.060, 0.095, 0.040))
			b.add_theme_color_override("font_pressed_color", Color(0.040, 0.070, 0.025))
		else:
			b.add_theme_color_override("font_color", Color(0.84, 0.89, 0.80))
			b.add_theme_color_override("font_hover_color", Color(0.96, 0.98, 0.92))
			b.add_theme_color_override("font_pressed_color", Color(0.96, 0.76, 0.36))


func _on_allies_minus() -> void:
	if main != null:
		main.change_ally_count(-1)


func _on_allies_plus() -> void:
	if main != null:
		main.change_ally_count(1)


func _on_enemies_minus() -> void:
	if main != null:
		main.change_enemy_count(-1)


func _on_enemies_plus() -> void:
	if main != null:
		main.change_enemy_count(1)


func _on_difficulty_selected(index: int) -> void:
	if main != null:
		main.set_difficulty(index)


func _on_play_pressed() -> void:
	if main != null:
		main.start_game()


func _on_leave_pressed() -> void:
	get_tree().quit()


func hide_start() -> void:
	start_overlay.visible = false
	if hud_root != null:
		hud_root.visible = true


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

	stats_label.text = "УБИЙСТВА  %d      СМЕРТИ  %d\nВ СТРОЮ   СИНИЕ %d   •   КРАСНЫЕ %d" % [
		main.kills, main.deaths, main.get_team_alive("blue"), main.get_team_alive("red")
	]

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

func _unhandled_input(event: InputEvent) -> void:
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
	if ui_font != null:
		l.add_theme_font_override("font", ui_font)
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
