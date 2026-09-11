# Credits.gd
extends Control

signal return_to_title_requested()

var base_black_bg: ColorRect
var credits_layer: Control
var credits_scroll_box: VBoxContainer
var is_in_credits: bool = false

var victory_report_layer: Control
var victory_title_label: Label
var victory_stats_label: Label
var victory_prompt_label: Label
var is_in_victory_report: bool = false
var is_input_locked: bool = true
var victory_pulse_tween: Tween

var audio_manager_ref: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_setup_base_background()
	_setup_credits_ui()
	_setup_victory_report_ui()

# FUNDO PRETO PERMANENTE QUE NUNCA SOME (BLINDA CONTRA VAZAMENTO DA DUNGEON/BATALHA)
func _setup_base_background() -> void:
	var vp_size = get_viewport_rect().size
	base_black_bg = ColorRect.new()
	base_black_bg.color = Color(0.01, 0.01, 0.03, 1.0)
	base_black_bg.position = Vector2.ZERO
	base_black_bg.size = vp_size
	base_black_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base_black_bg)

func start_flow(stats: Dictionary, audio_ref: Node = null) -> void:
	audio_manager_ref = audio_ref
	modulate.a = 1.0
	show()
	_play_credits(stats)

func _play_credits(stats: Dictionary) -> void:
	is_in_credits = true
	is_in_victory_report = false
	is_input_locked = true
	
	victory_report_layer.hide()
	credits_layer.modulate.a = 1.0
	credits_layer.show()
	
	var vp_size = get_viewport_rect().size
	var total_h = credits_scroll_box.get_minimum_size().y
	credits_scroll_box.position = Vector2(0, vp_size.y + 40.0)

	var scroll_tween = create_tween()
	scroll_tween.tween_property(credits_scroll_box, "position:y", -total_h - 60.0, 15.0).set_trans(Tween.TRANS_LINEAR)

	scroll_tween.finished.connect(func():
		# FADE DOS CRÉDITOS PARA O FUNDO PRETO SÓLIDO (SEM PISCAR NADA ATRÁS)
		_fade_sublayer(credits_layer, 0.0, 0.5, func():
			credits_layer.hide()
			is_in_credits = false
			_show_victory_report(stats)
		)
	)

func _show_victory_report(stats: Dictionary) -> void:
	is_in_victory_report = true
	is_input_locked = true

	var floor_reached: int = stats.get("floor", 1)
	var kills: int = stats.get("enemies_killed", 0)
	var treasures: int = stats.get("treasures", 0)
	var lang = Localization.current_language
	var chronodox_text = (("RESGATADO COM SUCESSO" if lang == "pt" else ("RETRIEVED" if lang == "en" else "回収成功")) if stats.get("has_chronodox", true) else ("NÃO RESGATADO" if lang == "pt" else ("NOT FOUND" if lang == "en" else "未発見")))

	var report_fmt = Localization.t("victory_stats", "• Andar Final Alcançado:  %d\n• Inimigos Abatidos:      %d\n• Tesouros Coletados:     %d\n• Chronodox:              %s\n• Status da Equipe:       SOBREVIVENTES")
	var report_header = Localization.t("mission_report_title", "RELATÓRIO DA MISSÃO:")
	
	victory_stats_label.text = "%s\n\n%s" % [
		report_header,
		report_fmt % [floor_reached, kills, treasures, chronodox_text]
	]

	if victory_pulse_tween and victory_pulse_tween.is_valid():
		victory_pulse_tween.kill()
	victory_pulse_tween = create_tween().set_loops()
	victory_pulse_tween.tween_property(victory_title_label, "modulate", Color(1.4, 1.4, 1.4), 1.2).set_trans(Tween.TRANS_SINE)
	victory_pulse_tween.tween_property(victory_title_label, "modulate", Color(1.0, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)

	victory_prompt_label.modulate.a = 0.0
	victory_report_layer.modulate.a = 0.0
	victory_report_layer.show()
	
	_fade_sublayer(victory_report_layer, 1.0, 0.5)

	var prompt_timer = get_tree().create_timer(1.0)
	prompt_timer.timeout.connect(func():
		var t = create_tween()
		t.tween_property(victory_prompt_label, "modulate:a", 1.0, 0.4)
		t.finished.connect(func():
			is_input_locked = false
		)
	)

func _finish_and_return() -> void:
	if is_input_locked: return
	is_input_locked = true

	if victory_pulse_tween and victory_pulse_tween.is_valid():
		victory_pulse_tween.kill()

	if audio_manager_ref:
		audio_manager_ref.play_sfx("sfx_menu_select")
		audio_manager_ref.stop_bgm(0.6)

	# FADE SUAVE DO RELATÓRIO PARA O PRETO TOTAL
	_fade_sublayer(victory_report_layer, 0.0, 0.4, func():
		victory_report_layer.hide()
		is_in_victory_report = false
		emit_signal("return_to_title_requested")
	)

func _unhandled_input(event: InputEvent) -> void:
	if not is_in_victory_report or is_input_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_finish_and_return()
			get_viewport().set_input_as_handled()

func _setup_credits_ui() -> void:
	var vp_size = get_viewport_rect().size
	size = vp_size

	credits_layer = Control.new()
	credits_layer.position = Vector2.ZERO
	credits_layer.size = vp_size
	credits_layer.hide()
	add_child(credits_layer)

	var p_stars = _create_ambient_particles(Vector2(vp_size.x / 2.0, vp_size.y * 0.5), Vector2(0, -1))
	p_stars.amount = 35
	p_stars.color = Color(0.0, 0.85, 1.0, 0.3)
	credits_layer.add_child(p_stars)

	credits_scroll_box = VBoxContainer.new()
	credits_scroll_box.custom_minimum_size = Vector2(vp_size.x, 0)
	credits_scroll_box.size = Vector2(vp_size.x, 0)
	credits_scroll_box.add_theme_constant_override("separation", 24)
	credits_layer.add_child(credits_scroll_box)

	_build_credits_content()

func _build_credits_content() -> void:
	# "STATION ABYSS" no topo dos créditos usa a fonte sci-fi estilosa
	var font_title = FontManager.get_font("title")
	var font_ui = FontManager.get_font("ui")
	var lang = Localization.current_language

	var thanks_str = "To you, for playing Station Abyss!" if lang == "en" else ("Station Abyss をプレイしてくれたあなたに！" if lang == "ja" else "A você, por jogar Station Abyss!")

	var roles = [
		{"role": "CREATION & GENERAL DIRECTION" if lang == "en" else ("原案・総監督" if lang == "ja" else "CRIAÇÃO & DIREÇÃO GERAL"), "name": "proxlu"},
		{"role": "STORY & SCRIPT" if lang == "en" else ("ストーリー・脚本" if lang == "ja" else "HISTÓRIA & ROTEIRO"), "name": "proxlu"},
		{"role": "PROGRAMMING & SYSTEMS" if lang == "en" else ("プログラミング・システム" if lang == "ja" else "PROGRAMAÇÃO & SISTEMAS"), "name": "proxlu"},
		{"role": "SOUNDTRACK & COMPOSITION" if lang == "en" else ("サウンドトラック・作曲" if lang == "ja" else "TRILHA SONORA & COMPOSIÇÃO"), "name": "proxlu"},
		{"role": "AUDIO DESIGN & SFX" if lang == "en" else ("効果音・オーディオデザイン" if lang == "ja" else "DESIGN DE ÁUDIO & EFEITOS SONOROS"), "name": "proxlu"},
		{"role": "CONCEPT ART & CHARACTERS" if lang == "en" else ("コンセプトアート・キャラクター" if lang == "ja" else "ARTE CONCEITUAL & PERSONAGENS"), "name": "proxlu"},
		{"role": "PROCEDURAL LEVEL DESIGN" if lang == "en" else ("プロシージャルレベルデザイン" if lang == "ja" else "LEVEL DESIGN PROCEDURAL"), "name": "proxlu"},
		{"role": "EXECUTIVE PRODUCTION" if lang == "en" else ("エグゼクティブプロデューサー" if lang == "ja" else "PRODUÇÃO EXECUTIVA"), "name": "proxlu"},
		{"role": "TESTING & BALANCING" if lang == "en" else ("テスト・調整" if lang == "ja" else "TESTES & BALANCEAMENTO"), "name": "proxlu"},
		{"role": "SPECIAL THANKS" if lang == "en" else ("スペシャルサンクス" if lang == "ja" else "AGRADECIMENTOS ESPECIAIS"), "name": thanks_str}
	]

	var title_lbl = Label.new()
	title_lbl.text = "STATION ABYSS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", font_title)
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	credits_scroll_box.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "CREDITS" if lang == "en" else ("スタッフロール" if lang == "ja" else "CRÉDITOS")
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", font_ui)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.8))
	credits_scroll_box.add_child(sub_lbl)

	var sep = HSeparator.new()
	var s_style = StyleBoxLine.new()
	s_style.color = Color(0.0, 0.8, 1.0, 0.4)
	sep.add_theme_stylebox_override("separator", s_style)
	credits_scroll_box.add_child(sep)

	for entry in roles:
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)

		var r_lbl = Label.new()
		r_lbl.text = entry.role
		r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_lbl.add_theme_font_override("font", font_ui)
		r_lbl.add_theme_font_size_override("font_size", 13)
		r_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		v.add_child(r_lbl)

		var n_lbl = Label.new()
		n_lbl.text = entry.name
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.add_theme_font_override("font", font_ui)
		n_lbl.add_theme_font_size_override("font_size", 18)
		n_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3) if entry.name == "proxlu" else Color(0.9, 1.0, 0.9))
		v.add_child(n_lbl)

		credits_scroll_box.add_child(v)

func _setup_victory_report_ui() -> void:
	var vp_size = get_viewport_rect().size
	var font_ui = FontManager.get_font("ui")

	victory_report_layer = Control.new()
	victory_report_layer.position = Vector2.ZERO
	victory_report_layer.size = vp_size
	victory_report_layer.hide()
	add_child(victory_report_layer)

	var p_stars = _create_ambient_particles(Vector2(vp_size.x / 2.0, vp_size.y * 0.5), Vector2(0, -1))
	p_stars.amount = 30
	p_stars.color = Color(0.0, 0.9, 1.0, 0.25)
	victory_report_layer.add_child(p_stars)

	victory_title_label = Label.new()
	victory_title_label.text = Localization.t("victory_title", "MISSÃO CUMPRIDA\nSTATION ABYSS VENCIDA")
	victory_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_title_label.position = Vector2(0, 45)
	victory_title_label.size = Vector2(vp_size.x, 70)
	victory_title_label.add_theme_font_override("font", font_ui)
	victory_title_label.add_theme_font_size_override("font_size", 22)
	victory_title_label.add_theme_constant_override("line_spacing", 4)
	victory_title_label.add_theme_constant_override("outline_size", 4)

	var cyan_color = Color(0.0, 0.95, 1.0)
	var white_color = Color(0.9, 0.9, 1.0)
	victory_title_label.add_theme_color_override("font_color", cyan_color)
	victory_report_layer.add_child(victory_title_label)

	var v_title_tween = create_tween().set_loops()
	v_title_tween.tween_property(victory_title_label, "theme_override_colors/font_color", white_color, 0.8).set_trans(Tween.TRANS_SINE)
	v_title_tween.tween_property(victory_title_label, "theme_override_colors/font_color", cyan_color, 0.8).set_trans(Tween.TRANS_SINE)

	var panel = Panel.new()
	panel.position = Vector2(vp_size.x / 2.0 - 240, 140)
	panel.size = Vector2(480, 220)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.04, 0.08, 0.94)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.0, 0.85, 1.0)
	p_style.corner_radius_top_left = 4
	p_style.corner_radius_top_right = 4
	p_style.corner_radius_bottom_right = 4
	p_style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", p_style)
	victory_report_layer.add_child(panel)

	# Relatório de estatísticas com font_ui e espaçamento limpo entre linhas (evita letras grudadas)
	victory_stats_label = Label.new()
	victory_stats_label.position = Vector2(25, 20)
	victory_stats_label.size = Vector2(430, 180)
	victory_stats_label.add_theme_font_override("font", font_ui)
	victory_stats_label.add_theme_font_size_override("font_size", 13)
	victory_stats_label.add_theme_constant_override("line_spacing", 6)
	victory_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	panel.add_child(victory_stats_label)

	victory_prompt_label = Label.new()
	victory_prompt_label.text = Localization.t("victory_prompt", "[ Pressione ESPAÇO / ENTER para Retornar ao Menu ]")
	victory_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_prompt_label.position = Vector2(0, vp_size.y - 70)
	victory_prompt_label.size = Vector2(vp_size.x, 30)
	victory_prompt_label.add_theme_font_override("font", font_ui)
	victory_prompt_label.add_theme_font_size_override("font_size", 14)
	victory_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	victory_prompt_label.modulate.a = 0.0
	victory_report_layer.add_child(victory_prompt_label)

func _create_ambient_particles(pos: Vector2, dir: Vector2) -> CPUParticles2D:
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = 25
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

func _fade_sublayer(node: Control, target_alpha: float, duration: float, on_finish: Callable = Callable()) -> void:
	var t = create_tween()
	t.tween_property(node, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE)
	if on_finish.is_valid():
		t.finished.connect(on_finish)
