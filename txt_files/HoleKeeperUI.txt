# HoleKeeperUI.gd
extends Panel

signal closed()

const VIOLET_ACCENT: Color = Color(0.85, 0.2, 1.0, 1.0)

var is_open: bool = false
var active_poi: Dictionary = {}
var party_system_ref = null
var main_ref = null

enum Step { NEGOTIATE, SELECT_CREW, SELECT_MOD }
var current_step: Step = Step.NEGOTIATE
var selected_char_id: String = ""

var title_lbl: Label
var prompt_lbl: RichTextLabel
var actions_vbox: VBoxContainer
var footer_lbl: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(540, 360)

	var vp_size = get_viewport_rect().size
	position = (vp_size - size) / 2.0

	var font_title = FontManager.get_font("title")
	var font_ui = FontManager.get_font("ui")

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.01, 0.05, 0.98)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = VIOLET_ACCENT
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	add_theme_stylebox_override("panel", panel_style)

	title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(16, 14)
	title_lbl.size = Vector2(508, 24)
	title_lbl.add_theme_font_override("font", font_title)
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", VIOLET_ACCENT)
	add_child(title_lbl)

	var div = HSeparator.new()
	var div_s = StyleBoxLine.new()
	div_s.color = Color(0.85, 0.2, 1.0, 0.4)
	div.add_theme_stylebox_override("separator", div_s)
	div.position = Vector2(16, 42)
	div.size = Vector2(508, 4)
	add_child(div)

	prompt_lbl = RichTextLabel.new()
	prompt_lbl.position = Vector2(20, 50)
	prompt_lbl.size = Vector2(500, 48)
	prompt_lbl.bbcode_enabled = true
	prompt_lbl.scroll_active = false
	prompt_lbl.add_theme_font_override("normal_font", font_ui)
	prompt_lbl.add_theme_font_size_override("normal_font_size", 13)
	add_child(prompt_lbl)

	actions_vbox = VBoxContainer.new()
	actions_vbox.position = Vector2(20, 102)
	actions_vbox.size = Vector2(500, 210)
	actions_vbox.add_theme_constant_override("separation", 8)
	add_child(actions_vbox)

	footer_lbl = Label.new()
	footer_lbl.position = Vector2(16, 326)
	footer_lbl.size = Vector2(508, 22)
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_lbl.add_theme_font_override("font", font_ui)
	footer_lbl.add_theme_font_size_override("font_size", 12)
	footer_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9, 0.7))
	add_child(footer_lbl)

	hide()

func open_ui(poi: Dictionary, party_sys: Node, p_main_ref: Node):
	active_poi = poi
	party_system_ref = party_sys
	main_ref = p_main_ref
	is_open = true

	var letter = poi.get("npc_letter", "A")
	title_lbl.text = Localization.t("hk_title", "★ FENDA QUÂNTICA - HOLE KEEPER %s") % letter

	_show_step_negotiate()
	show()

func _clear_actions():
	for c in actions_vbox.get_children():
		c.queue_free()

# CRIAÇÃO DO SLOT DE ITEM (ESTILO LOJA DE RPG COM MOLDURA PRÓPRIA)
# Criação do Slot com Moldura Opcional (se icon_str for vazio, fica sem moldura)
func _make_shop_slot_btn(key_str: String, title_str: String, stat_str: String, theme_color: Color, icon_str: String = "🔋") -> Button:
	var font_ui = FontManager.get_font("ui")
	var font_title = FontManager.get_font("title")

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(500, 44)

	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.03, 0.02, 0.06, 0.95)
	b_style.border_width_left = 1
	b_style.border_width_top = 1
	b_style.border_width_right = 1
	b_style.border_width_bottom = 1
	b_style.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
	b_style.corner_radius_top_left = 4
	b_style.corner_radius_top_right = 4
	b_style.corner_radius_bottom_right = 4
	b_style.corner_radius_bottom_left = 4

	var f_style = b_style.duplicate()
	f_style.border_color = theme_color
	f_style.bg_color = Color(theme_color.r * 0.15, theme_color.g * 0.15, theme_color.b * 0.15, 0.98)

	btn.add_theme_stylebox_override("normal", b_style)
	btn.add_theme_stylebox_override("hover", f_style)
	btn.add_theme_stylebox_override("focus", f_style)

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(12, 6)
	hbox.size = Vector2(476, 32)
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	# Só cria a moldura se tiver ícone informado
	if icon_str != "":
		var moldura = Panel.new()
		moldura.custom_minimum_size = Vector2(32, 32)
		moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m_style = StyleBoxFlat.new()
		m_style.bg_color = Color(0.01, 0.02, 0.05, 0.95)
		m_style.border_width_left = 1
		m_style.border_width_top = 1
		m_style.border_width_right = 1
		m_style.border_width_bottom = 1
		m_style.border_color = theme_color
		m_style.corner_radius_top_left = 4
		m_style.corner_radius_top_right = 4
		m_style.corner_radius_bottom_right = 4
		m_style.corner_radius_bottom_left = 4
		moldura.add_theme_stylebox_override("panel", m_style)
		hbox.add_child(moldura)

		var bat_icon = Label.new()
		bat_icon.text = icon_str
		bat_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		bat_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bat_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bat_icon.add_theme_font_override("font", font_ui)
		bat_icon.add_theme_font_size_override("font_size", 16)
		bat_icon.modulate = theme_color
		moldura.add_child(bat_icon)

	# Nome da Ação com Atalho
	var name_lbl = Label.new()
	name_lbl.text = "[%s] %s" % [key_str, title_str]
	name_lbl.add_theme_font_override("font", font_ui)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_lbl)

	# Custo / Estatística alinhado à direita
	if stat_str != "":
		var stat_lbl = Label.new()
		stat_lbl.text = stat_str
		stat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_lbl.add_theme_font_override("font", font_title)
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.add_theme_color_override("font_color", theme_color)
		hbox.add_child(stat_lbl)

	return btn

func _focus_first_button():
	await get_tree().process_frame
	if actions_vbox and actions_vbox.get_child_count() > 0:
		var first_btn = actions_vbox.get_child(0)
		if first_btn is Button and not first_btn.disabled:
			first_btn.grab_focus()

func _show_step_negotiate():
	current_step = Step.NEGOTIATE
	_clear_actions()

	var has_chronodox = main_ref.has_chronodox if main_ref else false
	footer_lbl.text = "[ ESC / BACKSPACE ] Sair da Fenda"

	if has_chronodox:
		prompt_lbl.text = "[color=#e080ff]O Hole Keeper exige o Chronodox para calibrar os núcleos da equipe.[/color]"
		# Passa "" no final para NÃO ter ícone de bateria
		var btn_hand = _make_shop_slot_btn("E", "Entregar Chronodox", "(-1 Tesouro)", Color(1.0, 0.85, 0.3), "")
		btn_hand.pressed.connect(func():
			if main_ref.audio_manager:
				main_ref.audio_manager.play_sfx("sfx_flee", 0.0, 3.0)

			main_ref.has_chronodox = false
			if main_ref.party_system: main_ref.party_system.has_chronodox = false
			if main_ref.battle_engine: main_ref.battle_engine.has_chronodox = false
			main_ref.total_treasures_collected = max(0, main_ref.total_treasures_collected - 1)
			main_ref.update_hud()

			active_poi["used"] = true
			_show_step_select_crew()
		)
		actions_vbox.add_child(btn_hand)
	else:
		prompt_lbl.text = "[color=#ff4444]Você não possui o Chronodox para negociar com o Hole Keeper![/color]"

	_focus_first_button()

func _show_step_select_crew():
	current_step = Step.SELECT_CREW
	_clear_actions()

	prompt_lbl.text = "[color=#e080ff][b]SELECIONE O TRIPULANTE PARA CALIBRAÇÃO DA BATERIA:[/b][/color]"
	footer_lbl.text = "[ 1 - 4 ] Selecionar Tripulante   |   [ ESC / BACKSPACE ] Voltar"

	var order = ["humano", "mutante", "alien", "robo"]
	var idx = 1
	for k in order:
		if party_system_ref and party_system_ref.members.has(k):
			var m = party_system_ref.members[k]
			var char_key = k

			var is_away = (k == "mutante" and party_system_ref.is_kira_away)
			var status_tag = "[ AUSENTE ]" if is_away else ("[ %s ]" % m.battery_tag.replace("\n", " "))
			
			var crew_col = Color(0.0, 0.85, 1.0)
			match m.battery_mod_id:
				"mod_hp": crew_col = Color(0.0, 1.0, 0.5)
				"mod_mp": crew_col = Color(0.85, 0.25, 1.0)
				"mod_vel": crew_col = Color(0.0, 0.9, 1.0)
				"mod_dmg": crew_col = Color(1.0, 0.55, 0.1)

			var btn = _make_shop_slot_btn(str(idx), "%s (Lv.%d)" % [m.name, m.level], status_tag, crew_col)
			if is_away:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5, 0.5)
			else:
				btn.pressed.connect(func():
					selected_char_id = char_key
					_show_step_select_mod()
				)

			actions_vbox.add_child(btn)
			idx += 1

	_focus_first_button()

func _show_step_select_mod():
	current_step = Step.SELECT_MOD
	_clear_actions()

	var m = party_system_ref.members[selected_char_id]
	prompt_lbl.text = "[color=#e080ff]Tripulante: [b]%s[/b]   |   Núcleo Atual: [ [b]%s[/b] ][/color]" % [m.name, m.battery_tag.replace("\n", " ")]
	footer_lbl.text = "[ 1 - 4 ] Escolher Núcleo   |   [ ESC / BACKSPACE ] Voltar"

	# OS 4 SLOTS DE NÚCLEO (HP, MP, VEL, DMG)
	var mods_def = [
		{"id": "mod_hp", "key": "1", "name": "Núcleo de HP", "stat": "+25% HP / -25% MP", "col": Color(0.0, 1.0, 0.5), "tag": "+HP\n-MP"},
		{"id": "mod_mp", "key": "2", "name": "Núcleo de MP", "stat": "+25% MP / -25% HP", "col": Color(0.85, 0.25, 1.0), "tag": "+MP\n-HP"},
		{"id": "mod_vel", "key": "3", "name": "Núcleo de VEL", "stat": "+25% VEL / -25% DANO", "col": Color(0.0, 0.9, 1.0), "tag": "+VEL\n-DMG"},
		{"id": "mod_dmg", "key": "4", "name": "Núcleo de DMG", "stat": "+25% DANO / -25% VEL", "col": Color(1.0, 0.55, 0.1), "tag": "+DMG\n-VEL"}
	]

	for entry in mods_def:
		if m.battery_mod_id == entry.id:
			var btn_rest = _make_shop_slot_btn(entry.key, "Restaurar Bateria", "(1 Tesouro)", Color(1.0, 0.85, 0.3))
			btn_rest.pressed.connect(_restore_member_battery)
			actions_vbox.add_child(btn_rest)
		else:
			var btn = _make_shop_slot_btn(entry.key, entry.name, entry.stat, entry.col)
			btn.pressed.connect(func(): _apply_mod_to_member(entry.id, entry.tag))
			actions_vbox.add_child(btn)

	_focus_first_button()

func _apply_mod_to_member(mod_id: String, tag: String):
	var m = party_system_ref.members[selected_char_id]
	m.apply_battery_mod(mod_id, tag)

	if main_ref and main_ref.audio_manager:
		main_ref.audio_manager.play_sfx("sfx_level_up")
		main_ref.audio_manager.play_sfx("sfx_heal")

	var title = "★ NÚCLEO CALIBRADO COM SUCESSO!"
	var desc = "Núcleo de %s redistribuída com sucesso!" % m.name

	close_ui()
	if main_ref:
		main_ref.update_hud()
		main_ref.show_system_message("[color=#e080ff]" + title + "[/color]", desc)

func _restore_member_battery():
	if main_ref and main_ref.total_treasures_collected < 1:
		if main_ref.audio_manager:
			main_ref.audio_manager.play_sfx("sfx_menu_cancel")
		prompt_lbl.text = "[color=#ff4444]Recursos insuficientes! É necessário 1 Tesouro para restaurar a Bateria.[/color]"
		return

	if main_ref:
		main_ref.total_treasures_collected -= 1

	var m = party_system_ref.members[selected_char_id]
	m.restore_battery_to_normal()

	if main_ref and main_ref.audio_manager:
		main_ref.audio_manager.play_sfx("sfx_level_up")

	var title = "★ NÚCLEO RESTAURADO!"
	var desc = "O núcleo de %s voltou ao estado Normal!" % m.name

	close_ui()
	if main_ref:
		main_ref.update_hud()
		main_ref.show_system_message("[color=#00ff66]" + title + "[/color]", desc)

func close_ui():
	if not is_open: return
	is_open = false
	hide()
	emit_signal("closed")

func _unhandled_input(event: InputEvent):
	if not is_open: return

	# Fechar no controle com Botão B
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		if current_step == Step.SELECT_MOD:
			_show_step_select_crew()
		else:
			close_ui()
		get_viewport().set_input_as_handled()
		return

	# Confirmar entrega no controle com Botão A
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		if current_step == Step.NEGOTIATE and actions_vbox.get_child_count() > 0:
			var first_btn = actions_vbox.get_child(0)
			if first_btn is Button and not first_btn.disabled:
				first_btn.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			if current_step == Step.SELECT_MOD:
				_show_step_select_crew()
			else:
				close_ui()
			get_viewport().set_input_as_handled()
			return

		var pressed_idx = -1
		if event.keycode == KEY_1: pressed_idx = 0
		elif event.keycode == KEY_2: pressed_idx = 1
		elif event.keycode == KEY_3: pressed_idx = 2
		elif event.keycode == KEY_4: pressed_idx = 3

		if pressed_idx >= 0 and pressed_idx < actions_vbox.get_child_count():
			var target_btn = actions_vbox.get_child(pressed_idx)
			if target_btn is Button and not target_btn.disabled:
				target_btn.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return

		if current_step == Step.NEGOTIATE:
			if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				if actions_vbox.get_child_count() > 0:
					var first_btn = actions_vbox.get_child(0)
					if first_btn is Button and not first_btn.disabled:
						first_btn.emit_signal("pressed")
						get_viewport().set_input_as_handled()
