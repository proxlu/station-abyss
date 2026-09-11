# TitleScreen.gd
extends Control

signal start_game_requested()

const ASSETS_DIR = "res://assets/"

var audio_manager_ref: Node = null
var title_ui_container: Control
var title_start_btn: Button
var exit_btn: Button
var is_starting: bool = false

static var has_selected_language: bool = false
var is_choosing_language: bool = false
var lang_select_container: Control
var btn_pt: Button
var btn_en: Button
var btn_ja: Button

static func get_game_font(category: String = "ui") -> Font:
	return FontManager.get_font(category)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_title_ui()

func _build_title_ui():
	var vp_size = get_viewport_rect().size
	size = vp_size
	position = Vector2.ZERO

	var font_btn = get_game_font("ui")
	var font_title = get_game_font("title")

	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.05, 1.0)
	bg.position = Vector2.ZERO
	bg.size = vp_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var ill_tex = load_texture_safe("ui_title_illustration")
	if not ill_tex: ill_tex = load_texture_safe("ui_title_illustration")
	if ill_tex:
		var ill_rect = TextureRect.new()
		ill_rect.position = Vector2.ZERO
		ill_rect.size = vp_size
		ill_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ill_rect.stretch_mode = TextureRect.STRETCH_SCALE
		ill_rect.texture = ill_tex
		ill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ill_rect)

	var p_left = create_ambient_particles(Vector2(60, vp_size.y * 0.5), Vector2(1, -0.2))
	var p_right = create_ambient_particles(Vector2(vp_size.x - 60, vp_size.y * 0.5), Vector2(-1, -0.2))
	add_child(p_left)
	add_child(p_right)

	title_ui_container = Control.new()
	title_ui_container.position = Vector2.ZERO
	title_ui_container.size = vp_size
	title_ui_container.modulate.a = 0.0
	title_ui_container.hide()
	add_child(title_ui_container)

	var logo_w = min(642.0, vp_size.x * 0.95)
	var logo_h = 100.0
	var logo_pos = Vector2((vp_size.x - logo_w) / 2.0, vp_size.y * 0.12)

	var logo_wrapper = Control.new()
	logo_wrapper.position = logo_pos
	logo_wrapper.size = Vector2(logo_w, logo_h)
	logo_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui_container.add_child(logo_wrapper)

	var logo_tex = load_texture_safe("ui_title_logo")
	if not logo_tex: logo_tex = load_texture_safe("ui_title_logo")
	if logo_tex:
		var logo_rect = TextureRect.new()
		logo_rect.texture = logo_tex
		logo_rect.position = Vector2.ZERO
		logo_rect.size = Vector2(logo_w, logo_h)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_wrapper.add_child(logo_rect)

		var logo_center = Vector2(logo_w / 2.0, logo_h / 2.0)
		var energy_fx = create_logo_energy_particles(logo_center, Vector2(logo_w, logo_h))
		logo_wrapper.add_child(energy_fx)
	else:
		var title = Label.new()
		title.text = "STATION ABYSS"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.position = Vector2.ZERO
		title.size = Vector2(logo_w, logo_h)
		title.add_theme_font_override("font", font_title)
		title.add_theme_font_size_override("font_size", 44)
		title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		title.add_theme_constant_override("outline_size", 6)
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		logo_wrapper.add_child(title)

	title_start_btn = Button.new()
	title_start_btn.text = tr("INICIAR MISSÃO")
	title_start_btn.position = Vector2(vp_size.x / 2.0 - 140, vp_size.y - 170)
	title_start_btn.size = Vector2(280, 48)
	title_start_btn.add_theme_font_override("font", font_btn)
	title_start_btn.add_theme_font_size_override("font_size", 17)
	title_start_btn.pressed.connect(_on_start_pressed)
	title_ui_container.add_child(title_start_btn)

	exit_btn = Button.new()
	exit_btn.text = tr("SAIR DO JOGO")
	exit_btn.position = Vector2(vp_size.x / 2.0 - 140, vp_size.y - 110)
	exit_btn.size = Vector2(280, 48)
	exit_btn.add_theme_font_override("font", font_btn)
	exit_btn.add_theme_font_size_override("font_size", 17)
	exit_btn.pressed.connect(func():
		if is_starting: return
		get_tree().quit()
	)
	title_ui_container.add_child(exit_btn)

	_build_language_selection_ui(vp_size, font_btn, font_title)

func _build_language_selection_ui(vp_size: Vector2, font_btn: Font, font_title: Font):
	lang_select_container = Control.new()
	lang_select_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lang_select_container)

	var dark_cover = ColorRect.new()
	dark_cover.color = Color(0.0, 0.0, 0.0, 0.98)
	dark_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	lang_select_container.add_child(dark_cover)

	var prompt_lbl = Label.new()
	prompt_lbl.text = "SELECIONE O IDIOMA  /  SELECT LANGUAGE  /  言語選択"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.position = Vector2(0, vp_size.y * 0.35)
	prompt_lbl.size = Vector2(vp_size.x, 35)
	prompt_lbl.add_theme_font_override("font", font_title)
	prompt_lbl.add_theme_font_size_override("font_size", 18)
	prompt_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	prompt_lbl.add_theme_constant_override("outline_size", 4)
	prompt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lang_select_container.add_child(prompt_lbl)

	var btn_box = HBoxContainer.new()
	btn_box.position = Vector2(vp_size.x / 2.0 - 380, vp_size.y * 0.46)
	btn_box.size = Vector2(760, 70)
	btn_box.add_theme_constant_override("separation", 18)
	lang_select_container.add_child(btn_box)

	var btn_normal_style = StyleBoxFlat.new()
	btn_normal_style.bg_color = Color(0.03, 0.06, 0.12, 0.95)
	btn_normal_style.border_width_left = 2
	btn_normal_style.border_width_top = 2
	btn_normal_style.border_width_right = 2
	btn_normal_style.border_width_bottom = 2
	btn_normal_style.border_color = Color(0.0, 0.8, 1.0, 0.6)
	btn_normal_style.corner_radius_top_left = 6
	btn_normal_style.corner_radius_top_right = 6
	btn_normal_style.corner_radius_bottom_right = 6
	btn_normal_style.corner_radius_bottom_left = 6

	var btn_focus_style = btn_normal_style.duplicate()
	btn_focus_style.border_color = Color(0.0, 1.0, 0.5, 1.0)
	btn_focus_style.bg_color = Color(0.05, 0.12, 0.20, 0.98)

	btn_pt = Button.new()
	btn_pt.text = "🇧🇷  PORTUGUÊS"
	btn_pt.custom_minimum_size = Vector2(230, 64)
	btn_pt.add_theme_font_override("font", font_btn)
	btn_pt.add_theme_font_size_override("font_size", 16)
	btn_pt.add_theme_stylebox_override("normal", btn_normal_style)
	btn_pt.add_theme_stylebox_override("hover", btn_focus_style)
	btn_pt.add_theme_stylebox_override("focus", btn_focus_style)
	btn_pt.pressed.connect(func(): _choose_language("pt"))
	btn_box.add_child(btn_pt)

	btn_en = Button.new()
	btn_en.text = "🇺🇸  ENGLISH"
	btn_en.custom_minimum_size = Vector2(230, 64)
	btn_en.add_theme_font_override("font", font_btn)
	btn_en.add_theme_font_size_override("font_size", 16)
	btn_en.add_theme_stylebox_override("normal", btn_normal_style)
	btn_en.add_theme_stylebox_override("hover", btn_focus_style)
	btn_en.add_theme_stylebox_override("focus", btn_focus_style)
	btn_en.pressed.connect(func(): _choose_language("en"))
	btn_box.add_child(btn_en)

	btn_ja = Button.new()
	btn_ja.text = "🇯🇵  日本語"
	btn_ja.custom_minimum_size = Vector2(230, 64)
	btn_ja.add_theme_font_override("font", font_btn)
	btn_ja.add_theme_font_size_override("font_size", 16)
	btn_ja.add_theme_stylebox_override("normal", btn_normal_style)
	btn_ja.add_theme_stylebox_override("hover", btn_focus_style)
	btn_ja.add_theme_stylebox_override("focus", btn_focus_style)
	btn_ja.pressed.connect(func(): _choose_language("ja"))
	btn_box.add_child(btn_ja)

func _choose_language(lang: String):
	if is_choosing_language: return
	is_choosing_language = true

	if btn_pt: btn_pt.disabled = true
	if btn_en: btn_en.disabled = true
	if btn_ja: btn_ja.disabled = true

	TranslationServer.set_locale(lang)
	Localization.set_language(lang)

	has_selected_language = true

	title_start_btn.text = Localization.t("btn_start_game", "INICIAR MISSÃO")
	exit_btn.text = Localization.t("btn_quit_game", "SAIR DO JOGO")

	if audio_manager_ref:
		audio_manager_ref.play_sfx("sfx_menu_select")

	var t_fade = create_tween()
	t_fade.tween_property(lang_select_container, "modulate:a", 0.0, 0.35)
	t_fade.finished.connect(func():
		lang_select_container.hide()
		_open_main_title_flow()
	)

func open_title(audio_ref: Node = null) -> void:
	audio_manager_ref = audio_ref
	is_starting = false
	is_choosing_language = false
	show()

	if not has_selected_language:
		if btn_pt: btn_pt.disabled = false
		if btn_en: btn_en.disabled = false
		if btn_ja: btn_ja.disabled = false
		title_ui_container.hide()
		lang_select_container.show()
		lang_select_container.modulate.a = 1.0
		btn_pt.grab_focus()
	else:
		lang_select_container.hide()
		_open_main_title_flow()

func _open_main_title_flow():
	title_ui_container.show()
	if title_start_btn: title_start_btn.disabled = false
	if exit_btn: exit_btn.disabled = false
	if title_ui_container: title_ui_container.modulate.a = 0.0

	if audio_manager_ref:
		audio_manager_ref.play_bgm("bgm_title", false, 1.0, false)

	var delay_timer = get_tree().create_timer(0.35)
	delay_timer.timeout.connect(func():
		if title_ui_container:
			var tween_ui = create_tween()
			tween_ui.tween_property(title_ui_container, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
			tween_ui.finished.connect(func():
				if title_start_btn and not is_starting: title_start_btn.grab_focus()
			)
	)

func _unhandled_input(event: InputEvent):
	if not has_selected_language and lang_select_container.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				if btn_en.has_focus(): btn_pt.grab_focus()
				elif btn_ja.has_focus(): btn_en.grab_focus()
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				if btn_pt.has_focus(): btn_en.grab_focus()
				elif btn_en.has_focus(): btn_ja.grab_focus()

func _on_start_pressed():
	if is_starting: return
	is_starting = true
	if title_start_btn: title_start_btn.disabled = true
	if exit_btn: exit_btn.disabled = true

	if audio_manager_ref:
		audio_manager_ref.play_sfx("sfx_menu_select")
		audio_manager_ref.stop_bgm()

	emit_signal("start_game_requested")

func create_ambient_particles(pos: Vector2, dir: Vector2) -> CPUParticles2D:
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = 20
	p.lifetime = 4.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(50, 260)
	p.gravity = Vector2(0, -8)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 28.0
	p.direction = dir
	p.spread = 35.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(1.0, 0.8, 1.0, 0.22)
	return p

func create_logo_energy_particles(center_pos: Vector2, rect_size: Vector2) -> Control:
	var container = Control.new()
	container.position = center_pos
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var p_cyan = CPUParticles2D.new()
	p_cyan.amount = 36
	p_cyan.lifetime = 0.32
	p_cyan.speed_scale = 1.3
	p_cyan.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p_cyan.emission_rect_extents = Vector2(rect_size.x * 0.46, rect_size.y * 0.36)
	p_cyan.gravity = Vector2.ZERO
	p_cyan.spread = 180.0
	p_cyan.initial_velocity_min = 15.0
	p_cyan.initial_velocity_max = 50.0
	p_cyan.scale_amount_min = 1.5
	p_cyan.scale_amount_max = 3.5
	p_cyan.color = Color(0.0, 0.88, 1.0, 0.85)
	container.add_child(p_cyan)

	var p_core = CPUParticles2D.new()
	p_core.amount = 18
	p_core.lifetime = 0.2
	p_core.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p_core.emission_rect_extents = Vector2(rect_size.x * 0.42, rect_size.y * 0.28)
	p_core.gravity = Vector2.ZERO
	p_core.spread = 180.0
	p_core.initial_velocity_min = 8.0
	p_core.initial_velocity_max = 30.0
	p_core.scale_amount_min = 2.0
	p_core.scale_amount_max = 4.0
	p_core.color = Color(0.75, 0.96, 1.0, 0.95)
	container.add_child(p_core)

	return container

func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]
	if base_name == "ui_title_illustration": candidates.append("ui_title_illustration")
	elif base_name == "ui_title_illustration": candidates.insert(0, "ui_title_illustration")
	elif base_name == "ui_title_logo": candidates.append("ui_title_logo")
	elif base_name == "ui_title_logo": candidates.insert(0, "ui_title_logo")

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null
