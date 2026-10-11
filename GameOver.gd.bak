# GameOver.gd
extends Control

static var stat_floor_reached: int = 1
static var stat_enemies_killed: int = 0
static var stat_treasures_collected: int = 0
static var stat_has_chronodox: bool = false
static var stat_living_allies: int = 0

const ASSETS_DIR = "res://assets/"
var audio_manager: Node
var fade_rect: ColorRect
var retry_btn: Button
var is_input_locked: bool = true

var font_title = FontManager.get_font("gameover_title")
var font_mono = FontManager.get_font("gameover_report")
var font_ui = FontManager.get_font("ui")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_input_locked = true

	var vp_size = get_viewport_rect().size
	size = vp_size
	position = Vector2.ZERO

	var base_bg = ColorRect.new()
	base_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	base_bg.position = Vector2.ZERO
	base_bg.size = vp_size
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base_bg)

	audio_manager = preload("res://AudioManager.gd").new()
	add_child(audio_manager)
	audio_manager.play_bgm("bgm_gameover", false, 1.0, false)

	var ill_tex = load_texture_safe("ui_gameover_illustration")
	if not ill_tex: ill_tex = load_texture_safe("ui_gameover_illustration")
	if ill_tex:
		var ill_rect = TextureRect.new()
		ill_rect.position = Vector2.ZERO
		ill_rect.size = vp_size
		ill_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ill_rect.stretch_mode = TextureRect.STRETCH_SCALE
		ill_rect.texture = ill_tex
		ill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ill_rect)

	var stars_left = create_distant_stars(Vector2(70, vp_size.y * 0.45), Vector2(55, vp_size.y * 0.38), 15)
	var stars_right = create_distant_stars(Vector2(vp_size.x - 70, vp_size.y * 0.45), Vector2(55, vp_size.y * 0.38), 15)
	var stars_top = create_distant_stars(Vector2(vp_size.x * 0.5, 45), Vector2(vp_size.x * 0.45, 30), 12)
	add_child(stars_left)
	add_child(stars_right)
	add_child(stars_top)

	var title = Label.new()
	title.text = Localization.t("gameover_title", "O CAPITÃO CAIU\nMISSÃO FRACASSADA")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 45)
	title.size = Vector2(vp_size.x, 70)
	title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("line_spacing", 4)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))

	var red_color = Color(1.0, 0.2, 0.2)
	var white_color = Color(1.0, 0.5, 0.3, 1.0)
	title.add_theme_color_override("font_color", red_color)
	add_child(title)

	var title_tween = create_tween().set_loops()
	title_tween.tween_property(title, "theme_override_colors/font_color", white_color, 0.8).set_trans(Tween.TRANS_SINE)
	title_tween.tween_property(title, "theme_override_colors/font_color", red_color, 0.8).set_trans(Tween.TRANS_SINE)

	var stats_panel = Panel.new()
	stats_panel.position = Vector2(vp_size.x / 2.0 - 260, 135)
	stats_panel.size = Vector2(520, 210)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.18, 0.02, 0.03, 0.94)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.8, 0.2, 0.2)
	p_style.corner_radius_top_left = 4
	p_style.corner_radius_top_right = 4
	p_style.corner_radius_bottom_right = 4
	p_style.corner_radius_bottom_left = 4
	stats_panel.add_theme_stylebox_override("panel", p_style)
	add_child(stats_panel)

	var chronodox_status = Localization.t("chronodox_found", "RESGATADO COM SUCESSO") if stat_has_chronodox else Localization.t("chronodox_not_found", "NÃO ENCONTRADO")
	var stats_label = Label.new()
	stats_label.position = Vector2(25, 16)
	stats_label.size = Vector2(470, 198)
	stats_label.add_theme_font_override("font", font_mono)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	stats_label.add_theme_constant_override("outline_size", 2)
	stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	var header_text = Localization.t("mission_report_title", "RELATÓRIO DA MISSÃO:")
	var body_fmt = Localization.t("gameover_stats", "• Andar Alcançado:    %d\n• Inimigos Abatidos:  %d\n• Tesouros Coletados: %d\n• Chronodox:          %s\n• Aliados Vivos:      %d / 4")
	stats_label.text = "%s\n\n%s" % [
		header_text,
		body_fmt % [stat_floor_reached, stat_enemies_killed, stat_treasures_collected, chronodox_status, stat_living_allies]
	]
	stats_panel.add_child(stats_label)

	retry_btn = Button.new()
	retry_btn.text = Localization.t("gameover_retry_btn", "RETORNAR AO TITULO")
	retry_btn.position = Vector2(vp_size.x / 2.0 - 140, 365)
	retry_btn.size = Vector2(280, 50)
	retry_btn.add_theme_font_override("font", font_ui)
	retry_btn.add_theme_font_size_override("font_size", 16)
	retry_btn.modulate.a = 0.0
	retry_btn.disabled = true
	retry_btn.pressed.connect(_on_retry_pressed)
	add_child(retry_btn)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.position = Vector2.ZERO
	fade_rect.size = vp_size
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)

	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

	var delay_timer = get_tree().create_timer(1.0)
	delay_timer.timeout.connect(func():
		is_input_locked = false
		if retry_btn:
			retry_btn.disabled = false
			var btn_tween = create_tween()
			btn_tween.tween_property(retry_btn, "modulate:a", 1.0, 0.45)
			btn_tween.finished.connect(func(): retry_btn.grab_focus())
	)

func create_distant_stars(pos: Vector2, extents: Vector2, amount: int = 15) -> CPUParticles2D:
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 4.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 1.0
	p.spread = 180.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.9, 0.96, 1.0, 0.35)
	return p

func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]
	if base_name == "ui_gameover_illustration": candidates.append("ui_gameover_illustration")
	elif base_name == "ui_gameover_illustration": candidates.insert(0, "ui_gameover_illustration")

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null

func _unhandled_input(event):
	if is_input_locked: return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_on_retry_pressed()
		get_viewport().set_input_as_handled()

func _on_retry_pressed():
	if is_input_locked: return
	is_input_locked = true

	audio_manager.play_sfx("sfx_menu_select")
	audio_manager.stop_bgm()

	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
	tween.finished.connect(func():
		if ResourceLoader.exists("res://main.tscn"):
			get_tree().change_scene_to_file("res://main.tscn")
		elif ResourceLoader.exists("res://Main.tscn"):
			get_tree().change_scene_to_file("res://Main.tscn")
		else:
			var main_script = load("res://Main.gd")
			var main_node = Node3D.new()
			main_node.set_script(main_script)
			var cur_scene = get_tree().current_scene
			get_tree().root.add_child(main_node)
			get_tree().current_scene = main_node
			if cur_scene: cur_scene.queue_free()
	)
