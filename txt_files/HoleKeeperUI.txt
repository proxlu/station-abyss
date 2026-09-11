# HoleKeeperUI.gd
extends Panel

signal closed()
signal battery_modified(char_id: String, mod_tag: String)

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

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(560, 420)

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
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", panel_style)

	title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(16, 16)
	title_lbl.size = Vector2(528, 28)
	title_lbl.add_theme_font_override("font", font_title)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", VIOLET_ACCENT)
	add_child(title_lbl)

	var div = HSeparator.new()
	var div_s = StyleBoxLine.new()
	div_s.color = VIOLET_ACCENT
	div.add_theme_stylebox_override("separator", div_s)
	div.position = Vector2(16, 48)
	div.size = Vector2(528, 4)
	add_child(div)

	prompt_lbl = RichTextLabel.new()
	prompt_lbl.position = Vector2(24, 58)
	prompt_lbl.size = Vector2(512, 60)
	prompt_lbl.bbcode_enabled = true
	prompt_lbl.scroll_active = false
	prompt_lbl.add_theme_font_override("normal_font", font_ui)
	prompt_lbl.add_theme_font_size_override("normal_font_size", 14)
	add_child(prompt_lbl)

	actions_vbox = VBoxContainer.new()
	actions_vbox.position = Vector2(30, 130)
	actions_vbox.size = Vector2(500, 270)
	actions_vbox.add_theme_constant_override("separation", 6)
	add_child(actions_vbox)

	hide()

func open_ui(poi: Dictionary, party_sys: Node, p_main_ref: Node):
	active_poi = poi
	party_system_ref = party_sys
	main_ref = p_main_ref
	is_open = true

	var letter = poi.get("npc_letter", "A")
	title_lbl.text = Localization.t("hk_title", "★ FENDA QUANTICA - HOLE KEEPER %s") % letter

	_show_step_negotiate()
	show()

func _clear_actions():
	for c in actions_vbox.get_children():
		c.queue_free()

func _make_btn(btn_text: String) -> Button:
	var font_ui = FontManager.get_font("ui")
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(500, 38)
	btn.add_theme_font_override("font", font_ui)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", VIOLET_ACCENT)

	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.04, 0.01, 0.08, 0.95)
	b_style.border_width_left = 2
	b_style.border_width_top = 1
	b_style.border_width_right = 2
	b_style.border_width_bottom = 1
	b_style.border_color = VIOLET_ACCENT
	b_style.corner_radius_top_left = 3
	b_style.corner_radius_top_right = 3
	b_style.corner_radius_bottom_right = 3
	b_style.corner_radius_bottom_left = 3
	btn.add_theme_stylebox_override("normal", b_style)
	return btn

func _focus_first_button():
	await get_tree().process_frame
	if actions_vbox and actions_vbox.get_child_count() > 0:
		var first_btn = actions_vbox.get_child(0)
		if first_btn is Button:
			first_btn.grab_focus()

func _show_step_negotiate():
	current_step = Step.NEGOTIATE
	_clear_actions()

	var has_chronodox = main_ref.has_chronodox if main_ref else false

	if has_chronodox:
		prompt_lbl.text = "[color=#e080ff]" + Localization.t("hk_negotiate_prompt", "O Hole Keeper exige o Chronodox para liberar a adulteração de núcleos.") + "[/color]"

		var btn_hand = _make_btn(Localization.t("hk_btn_hand_chronodox", "[ E / ENTER ] Entregar Chronodox (-1 Tesouro)"))
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
		prompt_lbl.text = "[color=#ff4444]" + Localization.t("hk_no_chronodox_msg", "Você não possui o Chronodox para negociar nesta Fenda Quântica.") + "[/color]"

	# A opção de sair só existe ANTES de entregar o Chronodox
	var btn_leave = _make_btn(Localization.t("hk_btn_leave", "[ESC] Sair da Fenda"))
	btn_leave.pressed.connect(close_ui)
	actions_vbox.add_child(btn_leave)

	_focus_first_button()

func _show_step_select_crew():
	current_step = Step.SELECT_CREW
	_clear_actions()

	prompt_lbl.text = "[color=#e080ff][b]" + Localization.t("hk_select_crew_title", "SELECIONE O TRIPULANTE PARA ADULTERAÇÃO DE NÚCLEO:") + "[/b][/color]"

	# NÃO HÁ BOTÃO DE SAIR AQUI. O jogador deve obrigatoriamente escolher um tripulante.
	var order = ["humano", "mutante", "alien", "robo"]
	var idx = 1
	for k in order:
		if party_system_ref and party_system_ref.members.has(k):
			if k == "mutante" and party_system_ref.is_kira_away:
				continue
			var m = party_system_ref.members[k]
			var char_key = k
			var btn_text = "[%d] %s  (Lv.%d)  [ 🔋 %s ]" % [idx, m.name, m.level, m.battery_tag.replace("\n", " ")]
			var btn = _make_btn(btn_text)
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
	prompt_lbl.text = "[color=#e080ff]Tripulante: [b]%s[/b] | Núcleo Atual: [ [b]%s[/b] ][/color]" % [m.name, m.battery_tag.replace("\n", " ")]

	var mods = [
		{"id": "mod_1", "name": Localization.t("hk_mod_1_name", "⚙️ -MP / +HP (Núcleo de Célula Residual)"), "tag": Localization.t("hk_mod_1_tag", "-MP\n+HP")},
		{"id": "mod_2", "name": Localization.t("hk_mod_2_name", "⚡ -VEL / +DMG (Núcleo de Sobrecarga)"), "tag": Localization.t("hk_mod_2_tag", "-VEL\n+DMG")},
		{"id": "mod_3", "name": Localization.t("hk_mod_3_name", "🩸 Cura % (Núcleo Regenerativa Quântica)"), "tag": Localization.t("hk_mod_3_tag", "REGEN\n%")},
		{"id": "mod_4", "name": Localization.t("hk_mod_4_name", "🧪 -HP / +MP (Núcleo de Transmutação)"), "tag": Localization.t("hk_mod_4_tag", "-HP\n+MP")}
	]

	for i in range(mods.size()):
		var mod_data = mods[i]
		var btn = _make_btn("[%d] %s" % [i + 1, mod_data.name])
		btn.pressed.connect(func():
			_apply_mod_to_member(mod_data.id, mod_data.tag)
		)
		actions_vbox.add_child(btn)

	if m.battery_mod_id != "none":
		var btn_restore = _make_btn("[5] " + Localization.t("hk_mod_restore_name", "🔧 [ Restaurar Núcleo ao Normal ] (Custo: 1 Tesouro)"))
		btn_restore.pressed.connect(func():
			_restore_member_battery()
		)
		actions_vbox.add_child(btn_restore)

	var btn_back = _make_btn(Localization.t("hk_btn_back_crew", "[ESC] Voltar / Escolher Outro Tripulante"))
	btn_back.pressed.connect(_show_step_select_crew)
	actions_vbox.add_child(btn_back)

	_focus_first_button()

func _apply_mod_to_member(mod_id: String, tag: String):
	var m = party_system_ref.members[selected_char_id]
	m.apply_battery_mod(mod_id, tag)

	if main_ref and main_ref.audio_manager:
		main_ref.audio_manager.play_sfx("sfx_level_up")
		main_ref.audio_manager.play_sfx("sfx_heal")

	var title = Localization.t("popup_battery_applied_title", "★ NÚCLEO ADULTERADO COM SUCESSO!")
	var desc = Localization.t("popup_battery_applied_desc", "Núcleo de %s recalibrado!") % m.name

	close_ui()
	if main_ref:
		main_ref.update_hud()
		main_ref.show_system_message("[color=#e080ff]" + title + "[/color]", desc)

func _restore_member_battery():
	if main_ref and main_ref.total_treasures_collected < 1:
		if main_ref.audio_manager:
			main_ref.audio_manager.play_sfx("sfx_flee", 0.0, 3.0)
		prompt_lbl.text += "\n[color=#ff4444]" + Localization.t("hk_no_treasure_restore", "Recursos insuficientes! É necessário 1 Tesouro para restaurar o Núcleo.") + "[/color]"
		return

	if main_ref:
		main_ref.total_treasures_collected -= 1

	var m = party_system_ref.members[selected_char_id]
	m.restore_battery_to_normal()

	if main_ref and main_ref.audio_manager:
		main_ref.audio_manager.play_sfx("sfx_level_up")

	var title = Localization.t("popup_battery_restored_title", "★ NÚCLEO RESTAURADO!")
	var desc = Localization.t("popup_battery_restored_desc", "O núcleo de %s foi restaurado para o estado Normal!") % m.name

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

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			if current_step == Step.SELECT_MOD:
				_show_step_select_crew()
				get_viewport().set_input_as_handled()
			elif current_step == Step.NEGOTIATE:
				close_ui()
				get_viewport().set_input_as_handled()
			# No SELECT_CREW, não fecha a loja!
		elif current_step == Step.NEGOTIATE:
			if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				var has_chronodox = main_ref.has_chronodox if main_ref else false
				if has_chronodox and actions_vbox.get_child_count() > 0:
					var first_btn = actions_vbox.get_child(0)
					if first_btn is Button:
						first_btn.emit_signal("pressed")
						get_viewport().set_input_as_handled()
		elif current_step == Step.SELECT_CREW:
			var valid_members = []
			for k in ["humano", "mutante", "alien", "robo"]:
				if party_system_ref and party_system_ref.members.has(k):
					if k == "mutante" and party_system_ref.is_kira_away: continue
					valid_members.append(k)

			if event.keycode == KEY_1 and valid_members.size() >= 1:
				selected_char_id = valid_members[0]
				_show_step_select_mod()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_2 and valid_members.size() >= 2:
				selected_char_id = valid_members[1]
				_show_step_select_mod()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_3 and valid_members.size() >= 3:
				selected_char_id = valid_members[2]
				_show_step_select_mod()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_4 and valid_members.size() >= 4:
				selected_char_id = valid_members[3]
				_show_step_select_mod()
				get_viewport().set_input_as_handled()

		elif current_step == Step.SELECT_MOD:
			if event.keycode == KEY_1:
				_apply_mod_to_member("mod_1", Localization.t("hk_mod_1_tag", "-MP\n+HP"))
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_2:
				_apply_mod_to_member("mod_2", Localization.t("hk_mod_2_tag", "-VEL\n+DMG"))
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_3:
				_apply_mod_to_member("mod_3", Localization.t("hk_mod_3_tag", "REGEN\n%"))
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_4:
				_apply_mod_to_member("mod_4", Localization.t("hk_mod_4_tag", "-HP\n+MP"))
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_5:
				var m = party_system_ref.members[selected_char_id]
				if m.battery_mod_id != "none":
					_restore_member_battery()
					get_viewport().set_input_as_handled()
