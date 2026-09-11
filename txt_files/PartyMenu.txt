# PartyMenu.gd
extends CanvasLayer

const ASSETS_DIR: String = "res://assets/"
var is_open: bool = false
var stats_labels: Dictionary = {}
var carga_labels: Dictionary = {}
var battery_labels: Dictionary = {}
var battery_title_labels: Dictionary = {}
var carga_title_labels: Dictionary = {}
var fullbody_rects: Dictionary = {}
var party_ref: Node

@export var use_centered_party_menu: bool = true
@export var carga_slot_align_right: bool = true

var title_label: Label
var subtitle_label: Label
var footer_lbl: Label
var buff_banner_panel: Panel
var buff_banner_label: Label
var main_container: Control

const CYAN_ACCENT: Color = Color(0.0, 0.85, 1.0, 1.0)
const DEAD_GRAY: Color = Color(0.28, 0.28, 0.32, 0.95)

const KONAMI_SEQUENCE: Array[int] = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
	KEY_B, KEY_A
]
var konami_idx: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	hide()

	var font_title = FontManager.get_font("title")
	var font_mono = FontManager.get_font("mono")
	var font_ui = FontManager.get_font("ui")

	var vp_size = get_viewport().get_visible_rect().size

	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.04, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	main_container = Control.new()
	if use_centered_party_menu:
		main_container.size = Vector2(964, 630)
		main_container.position = (vp_size - main_container.size) / 2.0
	else:
		main_container.position = Vector2(30, 8)
		main_container.size = Vector2(964, 630)
	add_child(main_container)

	var header_box = VBoxContainer.new()
	header_box.position = Vector2(0, 0)
	header_box.size = Vector2(964, 44)
	header_box.add_theme_constant_override("separation", 2)
	main_container.add_child(header_box)

	title_label = Label.new()
	title_label.text = Localization.t("party_title", "STATUS DA EQUIPE")
	title_label.add_theme_font_override("font", font_title)
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", CYAN_ACCENT)
	header_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = Localization.t("party_subtitle", "REGISTRO TÁTICO, CARGA DE EQUIPAMENTO E ATRIBUTOS DO ESQUADRÃO")
	subtitle_label.add_theme_font_override("font", font_ui)
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	header_box.add_child(subtitle_label)

	var columns_container = HBoxContainer.new()
	columns_container.position = Vector2(0, 48)
	columns_container.size = Vector2(964, 500)
	columns_container.add_theme_constant_override("separation", 14)
	main_container.add_child(columns_container)

	var chars = ["humano", "mutante", "alien", "robo"]
	for i in range(chars.size()):
		var char_id = chars[i]

		var card_panel = PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(230, 500)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.02, 0.04, 0.08, 0.85)
		card_style.content_margin_top = 16.0
		card_style.content_margin_bottom = 6.0
		card_style.content_margin_left = 6.0
		card_style.content_margin_right = 6.0
		card_style.corner_radius_top_left = 4
		card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_right = 4
		card_style.corner_radius_bottom_left = 4
		card_panel.add_theme_stylebox_override("panel", card_style)
		columns_container.add_child(card_panel)

		var card_vbox = VBoxContainer.new()
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vbox.add_theme_constant_override("separation", 4)
		card_panel.add_child(card_vbox)

		var tex_box = Control.new()
		tex_box.custom_minimum_size = Vector2(216, 360)
		tex_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vbox.add_child(tex_box)

		var full_tex = load_texture_safe("char_full_" + char_id)
		if not full_tex: full_tex = load_texture_safe("char_full_" + char_id)
		if full_tex:
			var shadow_rect = TextureRect.new()
			shadow_rect.texture = full_tex
			shadow_rect.anchor_right = 1.0
			shadow_rect.anchor_bottom = 1.0
			shadow_rect.offset_left = 8
			shadow_rect.offset_top = 8
			shadow_rect.offset_right = 8
			shadow_rect.offset_bottom = 8
			shadow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shadow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			shadow_rect.modulate = Color(0.0, 0.0, 0.0, 0.95)
			tex_box.add_child(shadow_rect)

			var main_rect = TextureRect.new()
			main_rect.texture = full_tex
			main_rect.anchor_right = 1.0
			main_rect.anchor_bottom = 1.0
			main_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			main_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_box.add_child(main_rect)
			fullbody_rects[char_id] = main_rect

		var slot_x = (216.0 - 58.0 - 8.0) if carga_slot_align_right else 8.0

		var bat_slot_panel = Panel.new()
		bat_slot_panel.size = Vector2(58, 48)
		bat_slot_panel.position = Vector2(slot_x, 250.0)
		bat_slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bat_style = StyleBoxFlat.new()
		bat_style.bg_color = Color(0.01, 0.02, 0.05, 0.95)
		bat_style.border_width_left = 1
		bat_style.border_width_top = 1
		bat_style.border_width_right = 1
		bat_style.border_width_bottom = 1
		bat_style.border_color = Color(0.0, 1.0, 0.5, 0.9)
		bat_style.corner_radius_top_left = 4
		bat_style.corner_radius_top_right = 4
		bat_style.corner_radius_bottom_right = 4
		bat_style.corner_radius_bottom_left = 4
		bat_slot_panel.add_theme_stylebox_override("panel", bat_style)
		tex_box.add_child(bat_slot_panel)

		var bat_lbl_title = Label.new()
		bat_lbl_title.text = Localization.t("party_source", Localization.t("party_battery", "FONTE"))
		bat_lbl_title.position = Vector2(0, 3)
		bat_lbl_title.size = Vector2(58, 12)
		bat_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bat_lbl_title.add_theme_font_override("font", font_ui)
		bat_lbl_title.add_theme_font_size_override("font_size", 9)
		bat_lbl_title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
		bat_slot_panel.add_child(bat_lbl_title)
		battery_title_labels[char_id] = bat_lbl_title

		var bat_bg_icon = Label.new()
		bat_bg_icon.text = "🔋"
		bat_bg_icon.position = Vector2(0, 16)
		bat_bg_icon.size = Vector2(58, 28)
		bat_bg_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bat_bg_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bat_bg_icon.add_theme_font_override("font", font_ui)
		bat_bg_icon.add_theme_font_size_override("font_size", 16)
		bat_bg_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		bat_slot_panel.add_child(bat_bg_icon)

		var bat_tag_lbl = Label.new()
		bat_tag_lbl.position = Vector2(0, 16)
		bat_tag_lbl.size = Vector2(58, 28)
		bat_tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bat_tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bat_tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bat_tag_lbl.add_theme_constant_override("line_spacing", -2)
		bat_tag_lbl.add_theme_font_override("font", font_ui)
		bat_tag_lbl.add_theme_font_size_override("font_size", 8.5)
		bat_tag_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.6))
		bat_tag_lbl.add_theme_constant_override("outline_size", 4)
		bat_tag_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		bat_slot_panel.add_child(bat_tag_lbl)
		battery_labels[char_id] = bat_tag_lbl

		var carga_slot_panel = Panel.new()
		carga_slot_panel.size = Vector2(58, 48)
		carga_slot_panel.position = Vector2(slot_x, 304.0)
		carga_slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var carga_style = StyleBoxFlat.new()
		carga_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		carga_style.border_width_left = 1
		carga_style.border_width_top = 1
		carga_style.border_width_right = 1
		carga_style.border_width_bottom = 1
		carga_style.border_color = CYAN_ACCENT
		carga_style.corner_radius_top_left = 4
		carga_style.corner_radius_top_right = 4
		carga_style.corner_radius_bottom_right = 4
		carga_style.corner_radius_bottom_left = 4
		carga_slot_panel.add_theme_stylebox_override("panel", carga_style)
		tex_box.add_child(carga_slot_panel)

		var carga_lbl_title = Label.new()
		carga_lbl_title.text = Localization.t("party_cargo", "CARGA")
		carga_lbl_title.position = Vector2(0, 3)
		carga_lbl_title.size = Vector2(58, 12)
		carga_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		carga_lbl_title.add_theme_font_override("font", font_ui)
		carga_lbl_title.add_theme_font_size_override("font_size", 9)
		carga_lbl_title.add_theme_color_override("font_color", CYAN_ACCENT)
		carga_slot_panel.add_child(carga_lbl_title)
		carga_title_labels[char_id] = carga_lbl_title

		var carga_icon = Label.new()
		carga_icon.position = Vector2(0, 16)
		carga_icon.size = Vector2(58, 28)
		carga_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		carga_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		carga_icon.add_theme_font_override("font", font_ui)
		carga_icon.add_theme_font_size_override("font_size", 16)
		carga_icon.add_theme_color_override("font_color", CYAN_ACCENT)
		carga_icon.modulate = CYAN_ACCENT
		carga_slot_panel.add_child(carga_icon)
		carga_labels[char_id] = carga_icon

		var div = HSeparator.new()
		var div_style = StyleBoxLine.new()
		div_style.color = Color(0.1, 0.3, 0.5, 0.4)
		div.add_theme_stylebox_override("separator", div_style)
		card_vbox.add_child(div)

		var stats_vbox = VBoxContainer.new()
		stats_vbox.custom_minimum_size = Vector2(210, 60)
		stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_vbox.add_theme_constant_override("separation", 3)
		card_vbox.add_child(stats_vbox)

		var header_lbl = Label.new()
		header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_lbl.add_theme_font_override("font", font_ui)
		header_lbl.add_theme_font_size_override("font_size", 13)
		header_lbl.add_theme_constant_override("outline_size", 2)
		header_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		header_lbl.add_theme_color_override("font_color", CYAN_ACCENT)
		stats_vbox.add_child(header_lbl)

		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 2)
		stats_vbox.add_child(grid)

		var hp_lbl = Label.new()
		hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_lbl.add_theme_font_override("font", font_mono)
		hp_lbl.add_theme_font_size_override("font_size", 11)
		hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		grid.add_child(hp_lbl)

		var spd_lbl = Label.new()
		spd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spd_lbl.add_theme_font_override("font", font_mono)
		spd_lbl.add_theme_font_size_override("font_size", 11)
		spd_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		grid.add_child(spd_lbl)

		var mp_lbl = Label.new()
		mp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mp_lbl.add_theme_font_override("font", font_mono)
		mp_lbl.add_theme_font_size_override("font_size", 11)
		mp_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		grid.add_child(mp_lbl)

		var exp_lbl = Label.new()
		exp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		exp_lbl.add_theme_font_override("font", font_mono)
		exp_lbl.add_theme_font_size_override("font_size", 11)
		exp_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		grid.add_child(exp_lbl)

		stats_labels[char_id] = {
			"header": header_lbl,
			"hp": hp_lbl,
			"mp": mp_lbl,
			"exp": exp_lbl,
			"spd": spd_lbl
		}

	buff_banner_panel = Panel.new()
	buff_banner_panel.position = Vector2(0, 554)
	buff_banner_panel.size = Vector2(964, 30)
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.01, 0.08, 0.04, 0.95)
	b_style.border_width_left = 2
	b_style.border_width_top = 1
	b_style.border_width_right = 2
	b_style.border_width_bottom = 1
	b_style.border_color = Color(0.0, 1.0, 0.4, 0.9)
	b_style.corner_radius_top_left = 3
	b_style.corner_radius_top_right = 3
	b_style.corner_radius_bottom_right = 3
	b_style.corner_radius_bottom_left = 3
	buff_banner_panel.add_theme_stylebox_override("panel", b_style)
	buff_banner_panel.hide()
	main_container.add_child(buff_banner_panel)

	buff_banner_label = Label.new()
	buff_banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	buff_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buff_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buff_banner_label.add_theme_font_override("font", font_ui)
	buff_banner_label.add_theme_font_size_override("font_size", 12)
	buff_banner_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	buff_banner_panel.add_child(buff_banner_label)

	var footer_panel = Panel.new()
	footer_panel.position = Vector2(0, 588)
	footer_panel.size = Vector2(964, 32)
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = Color(0.02, 0.03, 0.06, 0.9)
	f_style.border_width_top = 1
	f_style.border_color = Color(0.1, 0.3, 0.5, 0.5)
	footer_panel.add_theme_stylebox_override("panel", f_style)
	main_container.add_child(footer_panel)

	footer_lbl = Label.new()
	footer_lbl.text = Localization.t("party_footer", "[TAB], [BACKSPACE] ou [ESC] Retornar ao Labirinto")
	footer_lbl.position = Vector2(15, 6)
	footer_lbl.size = Vector2(934, 20)
	footer_lbl.add_theme_font_override("font", font_ui)
	footer_lbl.add_theme_font_size_override("font_size", 13)
	footer_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	footer_panel.add_child(footer_lbl)

func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]
	if base_name.begins_with("char_full_"):
		candidates.append(base_name.replace("char_full_", "char_full_"))
	elif base_name.begins_with("char_full_"):
		candidates.append(base_name.replace("char_full_", "char_full_"))

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null

func _unhandled_input(event):
	if not is_open: return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KONAMI_SEQUENCE[konami_idx]:
			konami_idx += 1
			if konami_idx >= KONAMI_SEQUENCE.size():
				konami_idx = 0
				if party_ref:
					party_ref.is_alien_endless_skin = !party_ref.is_alien_endless_skin
					update_stats(party_ref)
				get_viewport().set_input_as_handled()
				return
		else:
			konami_idx = 1 if event.keycode == KONAMI_SEQUENCE[0] else 0

		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			toggle_menu(party_ref)
			get_viewport().set_input_as_handled()

func toggle_menu(party_system):
	party_ref = party_system
	is_open = !is_open
	konami_idx = 0
	if is_open:
		update_stats(party_system)
		show()
	else:
		hide()

func update_stats(party_system):
	if not party_system: return

	var is_en = (Localization.current_language == "en")
	var is_ja = (Localization.current_language == "ja")
	title_label.text = Localization.t("party_title", "STATUS DA EQUIPE")
	subtitle_label.text = Localization.t("party_subtitle", "REGISTRO TÁTICO, CARGA DE EQUIPAMENTO E ATRIBUTOS DO ESQUADRÃO")
	footer_lbl.text = Localization.t("party_footer", "[TAB], [BACKSPACE] ou [ESC] Retornar ao Labirinto")

	var order = ["humano", "mutante", "alien", "robo"]
	for char_id in order:
		if party_system.members.has(char_id) and stats_labels.has(char_id):
			var member = party_system.members[char_id]
			var nodes = stats_labels[char_id]

			if char_id == "alien" and fullbody_rects.has("alien"):
				var full_tex = null
				if party_system.is_alien_endless_skin:
					full_tex = load_texture_safe("char_full_alien_endless")
					if not full_tex: full_tex = load_texture_safe("char_full_alien_endless")
				if not full_tex:
					full_tex = load_texture_safe("char_full_alien")
					if not full_tex: full_tex = load_texture_safe("char_full_alien")
				if full_tex: fullbody_rects["alien"].texture = full_tex

			if char_id == "mutante" and party_system.is_kira_away:
				var away_str = Localization.t("party_status_away", "AUSENTE")
				nodes.header.text = "%s  Lv.%d  [%s]" % [member.name.to_upper(), member.level, away_str]
				nodes.header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
				if fullbody_rects.has(char_id) and is_instance_valid(fullbody_rects[char_id]):
					fullbody_rects[char_id].modulate = Color(0.4, 0.4, 0.45, 0.6)
			else:
				var status = Localization.t("party_status_alive", "VIVO") if member.hp > 0 else Localization.t("party_status_dead", "INCAPACITADA")
				nodes.header.text = "%s  Lv.%d  [%s]" % [member.name.to_upper(), member.level, status]
				if member.hp <= 0:
					nodes.header.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				else:
					nodes.header.add_theme_color_override("font_color", CYAN_ACCENT)

				if fullbody_rects.has(char_id) and is_instance_valid(fullbody_rects[char_id]):
					if member.hp <= 0:
						fullbody_rects[char_id].modulate = DEAD_GRAY
					else:
						fullbody_rects[char_id].modulate = Color(1.0, 1.0, 1.0, 1.0)

			if member.shield > 0:
				nodes.hp.text = "HP: %3d/%3d" % [max(0, member.hp + member.shield), member.max_hp]
			else:
				nodes.hp.text = "HP: %3d/%3d" % [max(0, member.hp), member.max_hp]
			nodes.spd.text = ("SPD: %d" if is_en or is_ja else "VEL: %d") % member.speed
			nodes.mp.text = "MP: %3d/%3d" % [max(0, member.mp), member.max_mp]
			nodes.exp.text = "EXP: %d/%d" % [member.exp, member.exp_next]

			if battery_title_labels.has(char_id):
				battery_title_labels[char_id].text = Localization.t("party_source", Localization.t("party_battery", "FONTE"))

			if carga_title_labels.has(char_id):
				carga_title_labels[char_id].text = Localization.t("party_cargo", "CARGA")

			if carga_labels.has(char_id):
				carga_labels[char_id].text = member.carga_slot_icon if member.carga_slot_icon != "" else ""

			if battery_labels.has(char_id):
				battery_labels[char_id].text = member.battery_tag

	if party_system.has_perfect_defense_buff and not party_system.is_kira_away:
		buff_banner_label.text = Localization.t("party_spooter_banner", "★ SPACE SPOOTER BUFF: DEFESA IMPENETRÁVEL: Com os 4 tripulantes vivos, Defender anula 100% do dano")
		buff_banner_panel.show()
	else:
		buff_banner_panel.hide()
