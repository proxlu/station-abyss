# DataTerminalUI.gd
extends Panel

signal mission_started(mission: Dictionary)
signal drive_assigned(char_id: String, poi: Dictionary)
signal closed()

const ASSETS_DIR: String = "res://assets/"
const RETRO_GREEN: Color = Color(0.0, 1.0, 0.4, 1.0)
const RETRO_GREEN_DIM: Color = Color(0.0, 0.7, 0.3, 0.75)
const RETRO_GREEN_DARK: Color = Color(0.01, 0.08, 0.03, 0.95)

var is_open: bool = false
var active_poi: Dictionary = {}
var current_mission_ref: Dictionary = {}
var party_system_ref = null

var title_lbl: Label
var status_lbl: Label
var scan_box_panel: Panel
var scan_title_lbl: Label
var enemy_silhouette_rect: TextureRect
var drive_card_panel: Panel
var drive_icon_lbl: Label
var drive_progress_lbl: Label
var mission_desc_lbl: RichTextLabel
var actions_vbox: VBoxContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(460, 460)

	var vp_size = get_viewport_rect().size
	position = (vp_size - size) / 2.0

	var font_retro = FontManager.get_font("retro")
	var font_mono = FontManager.get_font("mono")
	var font_ui = FontManager.get_font("ui")

	# Moldura de Monitor Terminal Verde Monocromático
	var term_style = StyleBoxFlat.new()
	term_style.bg_color = Color(0.0, 0.01, 0.02, 0.98)
	term_style.border_width_left = 3
	term_style.border_width_top = 3
	term_style.border_width_right = 3
	term_style.border_width_bottom = 3
	term_style.border_color = RETRO_GREEN
	term_style.corner_radius_top_left = 6
	term_style.corner_radius_top_right = 6
	term_style.corner_radius_bottom_right = 6
	term_style.corner_radius_bottom_left = 6
	add_theme_stylebox_override("panel", term_style)

	# 1. CABEÇALHO DO MONITOR
	title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(12, 12)
	title_lbl.size = Vector2(436, 22)
	title_lbl.add_theme_font_override("font", font_retro)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", RETRO_GREEN)
	add_child(title_lbl)

	status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.position = Vector2(12, 34)
	status_lbl.size = Vector2(436, 16)
	status_lbl.add_theme_font_override("font", font_mono)
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", RETRO_GREEN_DIM)
	add_child(status_lbl)

	var div = HSeparator.new()
	var div_s = StyleBoxLine.new()
	div_s.color = RETRO_GREEN_DIM
	div.add_theme_stylebox_override("separator", div_s)
	div.position = Vector2(14, 52)
	div.size = Vector2(432, 4)
	add_child(div)

	# 2. BLOCO ESQUERDO: SCANNER HOLOGRÁFICO AMPLIADO (150x150)
	scan_box_panel = Panel.new()
	scan_box_panel.position = Vector2(16, 62)
	scan_box_panel.size = Vector2(150, 150)
	var scan_style = StyleBoxFlat.new()
	scan_style.bg_color = RETRO_GREEN_DARK
	scan_style.border_width_left = 1
	scan_style.border_width_top = 1
	scan_style.border_width_right = 1
	scan_style.border_width_bottom = 1
	scan_style.border_color = RETRO_GREEN
	scan_style.corner_radius_top_left = 4
	scan_style.corner_radius_top_right = 4
	scan_style.corner_radius_bottom_right = 4
	scan_style.corner_radius_bottom_left = 4
	scan_box_panel.add_theme_stylebox_override("panel", scan_style)
	add_child(scan_box_panel)

	scan_title_lbl = Label.new()
	scan_title_lbl.text = "ALVO // SCAN"
	scan_title_lbl.position = Vector2(0, 3)
	scan_title_lbl.size = Vector2(150, 12)
	scan_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scan_title_lbl.add_theme_font_override("font", font_ui)
	scan_title_lbl.add_theme_font_size_override("font_size", 8)
	scan_title_lbl.add_theme_color_override("font_color", RETRO_GREEN_DIM)
	scan_box_panel.add_child(scan_title_lbl)

	enemy_silhouette_rect = TextureRect.new()
	enemy_silhouette_rect.position = Vector2(6, 18)
	enemy_silhouette_rect.size = Vector2(138, 126)
	enemy_silhouette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_silhouette_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_silhouette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_silhouette_rect.modulate = RETRO_GREEN
	scan_box_panel.add_child(enemy_silhouette_rect)

	# 3. BLOCO DIREITO: DIRETIVA & CARTÃO DO DATA DRIVE
	mission_desc_lbl = RichTextLabel.new()
	mission_desc_lbl.position = Vector2(174, 62)
	mission_desc_lbl.size = Vector2(270, 78)
	mission_desc_lbl.bbcode_enabled = true
	mission_desc_lbl.scroll_active = false
	mission_desc_lbl.add_theme_font_override("normal_font", font_ui)
	mission_desc_lbl.add_theme_font_size_override("normal_font_size", 12)
	add_child(mission_desc_lbl)

	drive_card_panel = Panel.new()
	drive_card_panel.position = Vector2(174, 148)
	drive_card_panel.size = Vector2(270, 64)
	var dc_style = StyleBoxFlat.new()
	dc_style.bg_color = RETRO_GREEN_DARK
	dc_style.border_width_left = 1
	dc_style.border_width_top = 1
	dc_style.border_width_right = 1
	dc_style.border_width_bottom = 1
	dc_style.border_color = RETRO_GREEN_DIM
	dc_style.corner_radius_top_left = 4
	dc_style.corner_radius_top_right = 4
	dc_style.corner_radius_bottom_right = 4
	dc_style.corner_radius_bottom_left = 4
	drive_card_panel.add_theme_stylebox_override("panel", dc_style)
	add_child(drive_card_panel)

	drive_icon_lbl = Label.new()
	drive_icon_lbl.text = "💾"
	drive_icon_lbl.position = Vector2(6, 12)
	drive_icon_lbl.size = Vector2(40, 40)
	drive_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drive_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drive_icon_lbl.add_theme_font_override("font", font_ui)
	drive_icon_lbl.add_theme_font_size_override("font_size", 22)
	drive_icon_lbl.modulate = RETRO_GREEN
	drive_card_panel.add_child(drive_icon_lbl)

	drive_progress_lbl = Label.new()
	drive_progress_lbl.position = Vector2(48, 8)
	drive_progress_lbl.size = Vector2(216, 48)
	drive_progress_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drive_progress_lbl.add_theme_font_override("font", font_mono)
	drive_progress_lbl.add_theme_font_size_override("font_size", 10)
	drive_progress_lbl.add_theme_color_override("font_color", RETRO_GREEN)
	drive_card_panel.add_child(drive_progress_lbl)

	# Linha divisória de console
	var div2 = HSeparator.new()
	var div2_s = StyleBoxLine.new()
	div2_s.color = Color(RETRO_GREEN_DIM.r, RETRO_GREEN_DIM.g, RETRO_GREEN_DIM.b, 0.35)
	div2.add_theme_stylebox_override("separator", div2_s)
	div2.position = Vector2(16, 222)
	div2.size = Vector2(428, 4)
	add_child(div2)

	# 4. ÁREA INFERIOR DE BOTÕES
	actions_vbox = VBoxContainer.new()
	actions_vbox.position = Vector2(16, 230)
	actions_vbox.size = Vector2(428, 214)
	actions_vbox.custom_minimum_size = Vector2(428, 214)
	actions_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_vbox.add_theme_constant_override("separation", 8)
	add_child(actions_vbox)

	hide()

func open_terminal(poi: Dictionary, mission: Dictionary, party_sys):
	active_poi = poi
	current_mission_ref = mission
	party_system_ref = party_sys

	if mission.is_empty():
		return

	is_open = true
	var lang = Localization.current_language
	var font_ui = FontManager.get_font("ui")

	title_lbl.text = "TERMINAL DE CALIBRAÇÃO DE DADOS" if lang == "pt" else ("DATA CALIBRATION TERMINAL" if lang == "en" else ("DATENKALIBRIERUNGSTERMINAL" if lang == "de" else "データ調整端末"))
	scan_title_lbl.text = "ALVO // SCAN" if lang == "pt" else ("TARGET // SCAN" if lang == "en" else ("ZIEL // SCAN" if lang == "de" else "標的 // スキャン"))

	var e_tex = _load_enemy_texture(mission.get("enemy_id", "enemy_drone"))
	enemy_silhouette_rect.texture = e_tex

	for child in actions_vbox.get_children():
		child.queue_free()

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.02, 0.01, 0.95)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = RETRO_GREEN
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left = 4

	var f_style = btn_style.duplicate()
	f_style.border_color = Color(0.4, 1.0, 0.6)
	f_style.bg_color = Color(0.0, 0.12, 0.05, 0.98)

	var target_name = _get_enemy_display_name(mission)
	var target_kills = mission.get("target_kills", 10)
	var current_kills = mission.get("current_kills", 0)

	# 1. BRIEFING (DESCALIBRADO)
	if not mission.get("is_active", false):
		status_lbl.text = "STATUS: DATA DRIVE DESCALIBRADO" if lang == "pt" else ("STATUS: UNCALIBRATED DATA DRIVE" if lang == "en" else ("STATUS: UNKALIBRIERTES DATENLAUFWERK" if lang == "de" else "状態: 未調整データドライブ"))
		
		if lang == "pt":
			mission_desc_lbl.text = "[color=#00ff66][b]DIRETIVA:[/b]\nElimine [b]%d %s[/b] neste andar para calibrar a matriz de telemetria.[/color]" % [target_kills, target_name]
		elif lang == "en":
			mission_desc_lbl.text = "[color=#00ff66][b]DIRECTIVE:[/b]\nEliminate [b]%d %s[/b] on this floor to calibrate the telemetry matrix.[/color]" % [target_kills, target_name]
		elif lang == "de":
			mission_desc_lbl.text = "[color=#00ff66][b]DIREKTIVE:[/b]\nEliminiere [b]%d %s[/b] auf dieser Ebene, um die Telemetriematrix zu kalibrieren.[/color]" % [target_kills, target_name]
		else:
			mission_desc_lbl.text = "[color=#00ff66][b]指令:[/b]\nこの階層で [b]%s[/b] を [b]%d 体[/b] 撃破し、マトリクスを調整せよ。[/color]" % [target_name, target_kills]

		drive_icon_lbl.modulate = RETRO_GREEN_DIM
		if lang == "pt":
			drive_progress_lbl.text = "MATRIZ: [ ░░░░░░░░ ] 0%\nSTATUS: AGUARDANDO DADOS"
		elif lang == "en":
			drive_progress_lbl.text = "MATRIX: [ ░░░░░░░░ ] 0%\nSTATUS: AWAITING DATA"
		elif lang == "de":
			drive_progress_lbl.text = "MATRIX: [ ░░░░░░░░ ] 0%\nSTATUS: WARTE AUF DATEN"
		else:
			drive_progress_lbl.text = "マトリクス: [ ░░░░░░░░ ] 0%\n状態: データ待機中"

		var start_btn = Button.new()
		start_btn.text = "[ E / ENTER ] Iniciar Coleta de Telemetria" if lang == "pt" else ("[ E / ENTER ] Start Telemetry Collection" if lang == "en" else ("[ E / ENTER ] Telemetrie-Sammlung starten" if lang == "de" else "[ E / ENTER ] テレメトリ収集開始"))
		start_btn.custom_minimum_size = Vector2(428, 46)
		start_btn.add_theme_font_override("font", font_ui)
		start_btn.add_theme_font_size_override("font_size", 13)
		start_btn.add_theme_color_override("font_color", RETRO_GREEN)
		start_btn.add_theme_stylebox_override("normal", btn_style)
		start_btn.add_theme_stylebox_override("hover", f_style)
		start_btn.add_theme_stylebox_override("focus", f_style)
		start_btn.pressed.connect(func():
			emit_signal("mission_started", mission)
			close_terminal()
		)
		actions_vbox.add_child(start_btn)

		var exit_btn = Button.new()
		exit_btn.text = "[ ESC ] Sair do Terminal" if lang == "pt" else ("[ ESC ] Exit Terminal" if lang == "en" else ("[ ESC ] Terminal verlassen" if lang == "de" else "[ ESC ] 端末終了"))
		exit_btn.custom_minimum_size = Vector2(428, 40)
		exit_btn.add_theme_font_override("font", font_ui)
		exit_btn.add_theme_font_size_override("font_size", 13)
		exit_btn.add_theme_color_override("font_color", RETRO_GREEN_DIM)
		exit_btn.add_theme_stylebox_override("normal", btn_style)
		exit_btn.add_theme_stylebox_override("hover", f_style)
		exit_btn.add_theme_stylebox_override("focus", f_style)
		exit_btn.pressed.connect(close_terminal)
		actions_vbox.add_child(exit_btn)
		start_btn.grab_focus()

	# 2. CONCLUSÃO (100% GRAVADO)
	elif mission.get("is_completed", false):
		status_lbl.text = "STATUS: GRAVAÇÃO 100% CONCLUÍDA" if lang == "pt" else ("STATUS: RECORDING 100% COMPLETE" if lang == "en" else ("STATUS: AUFZEICHNUNG 100% ABGESCHLOSSEN" if lang == "de" else "状態: 記録100%完了"))
		
		if lang == "pt":
			mission_desc_lbl.text = "[color=#00ff66][b]TELEMETRIA COMPLETA:[/b]\nMatriz estabilizada. Selecione o integrante para sincronizar:[/color]"
		elif lang == "en":
			mission_desc_lbl.text = "[color=#00ff66][b]TELEMETRY COMPLETE:[/b]\nMatrix stabilized. Select member to sync drive:[/color]"
		elif lang == "de":
			mission_desc_lbl.text = "[color=#00ff66][b]TELEMETRIE VOLLSTÄNDIG:[/b]\nMatrix stabilisiert. Wähle Mitglied zur Synchronisierung:[/color]"
		else:
			mission_desc_lbl.text = "[color=#00ff66][b]テレメトリ完了:[/b]\nマトリクス安定。同期するメンバーを選択:[/color]"

		drive_icon_lbl.modulate = Color(0.0, 1.0, 0.5)
		if lang == "pt":
			drive_progress_lbl.text = "MATRIZ: [ ▰▰▰▰▰▰▰▰ ] 100%\nSTATUS: SINCRONIZAÇÃO PRONTA"
		elif lang == "en":
			drive_progress_lbl.text = "MATRIX: [ ▰▰▰▰▰▰▰▰ ] 100%\nSTATUS: READY TO SYNC"
		elif lang == "de":
			drive_progress_lbl.text = "MATRIX: [ ▰▰▰▰▰▰▰▰ ] 100%\nSTATUS: BEREIT ZUR SYNCHRONISATION"
		else:
			drive_progress_lbl.text = "マトリクス: [ ▰▰▰▰▰▰▰▰ ] 100%\n状態: 同期準備完了"

		var eligible = party_system_ref.get_eligible_drive_members() if party_system_ref else []
		if eligible.is_empty():
			if lang == "pt":
				mission_desc_lbl.text += "\n[color=#00ff66][AVISO]: Toda a equipe já possui Data Drive ativo.[/color]"
			elif lang == "en":
				mission_desc_lbl.text += "\n[color=#00ff66][NOTICE]: All crew members already possess a Data Drive.[/color]"
			elif lang == "de":
				mission_desc_lbl.text += "\n[color=#00ff66][HINWEIS]: Die gesamte Besatzung besitzt bereits ein aktives Datenlaufwerk.[/color]"
			else:
				mission_desc_lbl.text += "\n[color=#00ff66][通知]: 全員がデータドライブを所持しています。[/color]"

			var close_btn = Button.new()
			close_btn.text = "[ ESC ] Fechar Terminal" if lang == "pt" else ("[ ESC ] Close Terminal" if lang == "en" else ("[ ESC ] Terminal schließen" if lang == "de" else "[ ESC ] 端末を閉じる"))
			close_btn.custom_minimum_size = Vector2(428, 44)
			close_btn.add_theme_font_override("font", font_ui)
			close_btn.add_theme_font_size_override("font_size", 13)
			close_btn.add_theme_color_override("font_color", RETRO_GREEN)
			close_btn.add_theme_stylebox_override("normal", btn_style)
			close_btn.add_theme_stylebox_override("hover", f_style)
			close_btn.add_theme_stylebox_override("focus", f_style)
			close_btn.pressed.connect(close_terminal)
			actions_vbox.add_child(close_btn)
			close_btn.grab_focus()
		else:
			for i in range(eligible.size()):
				var char_id = eligible[i]
				var char_name = _get_char_name(char_id)
				var btn = Button.new()
				btn.text = ("[%d] Sincronizar Data Drive com %s" if lang == "pt" else ("[%d] Sync Data Drive with %s" if lang == "en" else ("[%d] Datenlaufwerk mit %s synchronisieren" if lang == "de" else "[%d] %s にデータドライブを同期"))) % [i + 1, char_name]
				btn.custom_minimum_size = Vector2(428, 40)
				btn.add_theme_font_override("font", font_ui)
				btn.add_theme_font_size_override("font_size", 13)
				btn.add_theme_color_override("font_color", RETRO_GREEN)
				btn.add_theme_stylebox_override("normal", btn_style)
				btn.add_theme_stylebox_override("hover", f_style)
				btn.add_theme_stylebox_override("focus", f_style)
				btn.pressed.connect(func():
					emit_signal("drive_assigned", char_id, active_poi)
					close_terminal()
				)
				actions_vbox.add_child(btn)

			if actions_vbox.get_child_count() > 0:
				actions_vbox.get_child(0).grab_focus()

	# 3. EM PROGRESSO (GRAVANDO)
	else:
		status_lbl.text = "STATUS: GRAVANDO TELEMETRIA EM COMBATE..." if lang == "pt" else ("STATUS: RECORDING COMBAT TELEMETRY..." if lang == "en" else ("STATUS: ZEICHNE KAMPFTELEMETRIE AUF..." if lang == "de" else "状態: 戦闘テレメトリ記録中..."))
		
		if lang == "pt":
			mission_desc_lbl.text = "[color=#00ff66][b]GRAVAÇÃO ATIVA:[/b]\n• Alvo: %s\n• Progresso: %d / %d eliminados[/color]" % [target_name, current_kills, target_kills]
		elif lang == "en":
			mission_desc_lbl.text = "[color=#00ff66][b]RECORDING IN PROGRESS:[/b]\n• Target: %s\n• Progress: %d / %d eliminated[/color]" % [target_name, current_kills, target_kills]
		elif lang == "de":
			mission_desc_lbl.text = "[color=#00ff66][b]AKTIVE AUFZEICHNUNG:[/b]\n• Ziel: %s\n• Fortschritt: %d / %d eliminiert[/color]" % [target_name, current_kills, target_kills]
		else:
			mission_desc_lbl.text = "[color=#00ff66][b]記録中:[/b]\n• 標的: %s\n• 進行状況: %d / %d 撃破[/color]" % [target_name, current_kills, target_kills]

		var ratio = clamp(float(current_kills) / float(max(1, target_kills)), 0.0, 1.0)
		var total_blocks = 8
		var filled = int(round(ratio * total_blocks))
		var bar_str = ""
		for b in range(total_blocks):
			bar_str += "▰" if b < filled else "▱"

		var percent = int(ratio * 100.0)
		drive_icon_lbl.modulate = RETRO_GREEN
		if lang == "pt":
			drive_progress_lbl.text = "MATRIZ: [ %s ] %d%%\nGRAVANDO: %d / %d DADOS" % [bar_str, percent, current_kills, target_kills]
		elif lang == "en":
			drive_progress_lbl.text = "MATRIX: [ %s ] %d%%\nRECORDING: %d / %d DATA" % [bar_str, percent, current_kills, target_kills]
		elif lang == "de":
			drive_progress_lbl.text = "MATRIX: [ %s ] %d%%\nAUFZEICHNUNG: %d / %d DATEN" % [bar_str, percent, current_kills, target_kills]
		else:
			drive_progress_lbl.text = "マトリクス: [ %s ] %d%%\n記録中: %d / %d データ" % [bar_str, percent, current_kills, target_kills]

		var close_btn = Button.new()
		close_btn.text = "[ ESC / E ] Retornar à Patrulha" if lang == "pt" else ("[ ESC / E ] Return to Patrol" if lang == "en" else ("[ ESC / E ] Zur Patrouille zurückkehren" if lang == "de" else "[ ESC / E ] 巡回に戻る"))
		close_btn.custom_minimum_size = Vector2(428, 48)
		close_btn.add_theme_font_override("font", font_ui)
		close_btn.add_theme_font_size_override("font_size", 13)
		close_btn.add_theme_color_override("font_color", RETRO_GREEN)
		close_btn.add_theme_stylebox_override("normal", btn_style)
		close_btn.add_theme_stylebox_override("hover", f_style)
		close_btn.add_theme_stylebox_override("focus", f_style)
		close_btn.pressed.connect(close_terminal)
		actions_vbox.add_child(close_btn)
		close_btn.grab_focus()

	show()

func close_terminal():
	if not is_open: return
	is_open = false
	hide()
	emit_signal("closed")

func _load_enemy_texture(base_id: String) -> Texture2D:
	var clean_name = base_id.get_basename()
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var p = ASSETS_DIR + clean_name + ext
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return load(p)
	return null

func _get_enemy_display_name(mission: Dictionary) -> String:
	var lang = Localization.current_language
	if lang == "en" and mission.has("enemy_name_en"):
		return mission["enemy_name_en"]
	elif lang == "ja" and mission.has("enemy_name_ja"):
		return mission["enemy_name_ja"]
	elif lang == "de" and mission.has("enemy_name_de"):
		return mission["enemy_name_de"]
	elif lang == "pt" and mission.has("enemy_name_pt"):
		return mission["enemy_name_pt"]

	var e_id = mission.get("enemy_id", "")
	match e_id:
		"enemy_mutant_beast":
			return "Mutantes" if lang == "pt" else ("Mutants" if lang == "en" else ("Mutanten" if lang == "de" else "変異獣"))
		"enemy_drone":
			return "Drones" if lang == "pt" else ("Drones" if lang == "en" else ("Drohnen" if lang == "de" else "ドローン"))
		"enemy_corrupted_android":
			return "Androides" if lang == "pt" else ("Androids" if lang == "en" else ("Androiden" if lang == "de" else "アンドロイド"))
		"enemy_alien_scout":
			return "Alien Scouts" if lang == "pt" else ("Alien Scouts" if lang == "en" else ("Alien-Späher" if lang == "de" else "斥候エイリアン"))
		_:
			return mission.get("enemy_name", "Inimigo" if lang == "pt" else ("Enemy" if lang == "en" else ("Feind" if lang == "de" else "敵")))

func _get_char_name(canonical_id: String) -> String:
	var lang = Localization.current_language
	if lang == "ja":
		match canonical_id:
			"humano": return "リガード"
			"mutante": return "キラ"
			"alien": return "ヴァエルサ"
			"robo": return "Unit-7"
	match canonical_id:
		"humano": return "Rigard"
		"mutante": return "Kira"
		"alien": return "Vaelthor"
		"robo": return "Unit-7"
		_: return canonical_id.capitalize()

func _unhandled_input(event: InputEvent):
	if not is_open: return

	# Suporte a controle: Fechar (B) ou Iniciar/Confirmar (A)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
			close_terminal()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_A:
			if not current_mission_ref.is_empty() and not current_mission_ref.get("is_active", false):
				emit_signal("mission_started", current_mission_ref)
				close_terminal()
				get_viewport().set_input_as_handled()
				return
			elif not current_mission_ref.is_empty() and not current_mission_ref.get("is_completed", false):
				close_terminal()
				get_viewport().set_input_as_handled()
				return

	# Lógica original de teclado 100% intacta
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			close_terminal()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E or event.keycode == KEY_ENTER or event.is_action_pressed("ui_accept"):
			if not current_mission_ref.is_empty() and not current_mission_ref.get("is_active", false):
				emit_signal("mission_started", current_mission_ref)
				close_terminal()
				get_viewport().set_input_as_handled()
			elif not current_mission_ref.is_empty() and not current_mission_ref.get("is_completed", false):
				close_terminal()
				get_viewport().set_input_as_handled()
		elif current_mission_ref.get("is_completed", false) and party_system_ref:
			var eligible = party_system_ref.get_eligible_drive_members()
			if event.keycode == KEY_1 and eligible.size() >= 1:
				emit_signal("drive_assigned", eligible[0], active_poi)
				close_terminal()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_2 and eligible.size() >= 2:
				emit_signal("drive_assigned", eligible[1], active_poi)
				close_terminal()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_3 and eligible.size() >= 3:
				emit_signal("drive_assigned", eligible[2], active_poi)
				close_terminal()
				get_viewport().set_input_as_handled()
