# DataTerminalUI.gd
extends Panel

signal mission_started(mission: Dictionary)
signal drive_assigned(char_id: String, poi: Dictionary)
signal closed()

const RETRO_GREEN: Color = Color(0.0, 1.0, 0.4, 1.0)

var is_open: bool = false
var active_poi: Dictionary = {}
var current_mission_ref: Dictionary = {}

var title_lbl: Label
var status_lbl: Label
var body_lbl: RichTextLabel
var actions_vbox: VBoxContainer
var party_system_ref = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(520, 440)

	var vp_size = get_viewport_rect().size
	position = (vp_size - size) / 2.0

	var font_retro = FontManager.get_font("retro")
	var font_mono = FontManager.get_font("mono")
	var font_ui = FontManager.get_font("ui")

	var term_style = StyleBoxFlat.new()
	term_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	term_style.border_width_left = 3
	term_style.border_width_top = 3
	term_style.border_width_right = 3
	term_style.border_width_bottom = 3
	term_style.border_color = RETRO_GREEN
	term_style.corner_radius_top_left = 4
	term_style.corner_radius_top_right = 4
	term_style.corner_radius_bottom_right = 4
	term_style.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", term_style)

	title_lbl = Label.new()
	title_lbl.text = "TERMINAL DE CALIBRAÇÃO DE DADOS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(16, 16)
	title_lbl.size = Vector2(488, 26)
	title_lbl.add_theme_font_override("font", font_retro)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", RETRO_GREEN)
	add_child(title_lbl)

	status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.position = Vector2(16, 44)
	status_lbl.size = Vector2(488, 20)
	status_lbl.add_theme_font_override("font", font_mono)
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", RETRO_GREEN)
	add_child(status_lbl)

	var div = HSeparator.new()
	var div_s = StyleBoxLine.new()
	div_s.color = RETRO_GREEN
	div.add_theme_stylebox_override("separator", div_s)
	div.position = Vector2(16, 68)
	div.size = Vector2(488, 4)
	add_child(div)

	body_lbl = RichTextLabel.new()
	body_lbl.position = Vector2(24, 80)
	body_lbl.size = Vector2(472, 175)
	body_lbl.bbcode_enabled = true
	body_lbl.scroll_active = false
	body_lbl.add_theme_font_override("normal_font", font_ui)
	body_lbl.add_theme_font_size_override("normal_font_size", 14)
	add_child(body_lbl)

	actions_vbox = VBoxContainer.new()
	actions_vbox.position = Vector2(30, 265)
	actions_vbox.size = Vector2(460, 155)
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

	title_lbl.text = "DATA CALIBRATION TERMINAL" if lang == "en" else ("データ調整端末" if lang == "ja" else "TERMINAL DE CALIBRAÇÃO DE DADOS")

	for child in actions_vbox.get_children():
		child.queue_free()

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = RETRO_GREEN
	btn_style.corner_radius_top_left = 3
	btn_style.corner_radius_top_right = 3
	btn_style.corner_radius_bottom_right = 3
	btn_style.corner_radius_bottom_left = 3

	# 1. BRIEFING
	if not mission.get("is_active", false):
		status_lbl.text = "STATUS: UNCALIBRATED DATA DRIVE" if lang == "en" else ("状態: 未調整データドライブ" if lang == "ja" else "STATUS: DATA DRIVE DESCALIBRADO")
		if lang == "en":
			body_lbl.text = "[color=#00ff66][b]SYSTEM ALERT:[/b][/color]\n[color=#00ff66]The Data Drive in this terminal is uncalibrated. Missing combat telemetry from this floor.\n\n[b]DIRECTIVE:[/b] Eliminate %d %s on this floor to complete the matrix and eject the drive ready for use.[/color]" % [
				mission.target_kills, mission.enemy_name
			]
		elif lang == "ja":
			body_lbl.text = "[color=#00ff66][b]システム警告:[/b][/color]\n[color=#00ff66]この端末に挿入されたデータドライブは未調整です。この階層の戦闘テレメトリデータが不足しています。\n\n[b]指令:[/b] マトリクスを完成させてドライブを取り出すため、この階層で %s を %d 体撃破せよ。[/color]" % [
				mission.enemy_name, mission.target_kills
			]
		else:
			body_lbl.text = "[color=#00ff66][b]AVISO DE SISTEMA:[/b][/color]\n[color=#00ff66]O Data Drive inserido neste terminal está descalibrado. Faltam dados de telemetria de combate da estação.\n\n[b]DIRETIVA:[/b] Elimine %d %s neste andar para concluir a matriz de dados e ejetar o drive pronto para uso.[/color]" % [
				mission.target_kills, mission.enemy_name
			]

		var start_btn = Button.new()
		start_btn.text = "[ E / ENTER ] Start Telemetry Collection" if lang == "en" else (" [ E / ENTER ] テレメトリ収集開始" if lang == "ja" else "[ E / ENTER ] Iniciar Coleta de Telemetria")
		start_btn.custom_minimum_size = Vector2(460, 42)
		start_btn.add_theme_font_override("font", font_ui)
		start_btn.add_theme_color_override("font_color", RETRO_GREEN)
		start_btn.add_theme_stylebox_override("normal", btn_style)
		start_btn.pressed.connect(func():
			emit_signal("mission_started", mission)
			close_terminal()
		)
		actions_vbox.add_child(start_btn)

		var exit_btn = Button.new()
		exit_btn.text = "[ESC] Exit Terminal" if lang == "en" else ("[ESC] 端末終了" if lang == "ja" else "[ESC] Sair do Terminal")
		exit_btn.custom_minimum_size = Vector2(460, 36)
		exit_btn.add_theme_font_override("font", font_ui)
		exit_btn.add_theme_color_override("font_color", RETRO_GREEN)
		exit_btn.add_theme_stylebox_override("normal", btn_style)
		exit_btn.pressed.connect(close_terminal)
		actions_vbox.add_child(exit_btn)
		start_btn.grab_focus()

	# 2. CONCLUSÃO
	elif mission.get("is_completed", false):
		status_lbl.text = "STATUS: RECORDING 100% COMPLETE" if lang == "en" else ("状態: 記録100%完了" if lang == "ja" else "STATUS: GRAVAÇÃO 100% CONCLUÍDA")
		if lang == "en":
			body_lbl.text = "[color=#00ff66][b]TELEMETRY COMPLETE:[/b]\nAll combat data has been successfully synchronized to the drive.\n\nSelect a crew member below to equip the Calibrated Data Drive:[/color]"
		elif lang == "ja":
			body_lbl.text = "[color=#00ff66][b]テレメトリ完了:[/b]\nすべての戦闘データがドライブに同期されました。\n\n調整済みデータドライブを同期するメンバーを選択してください:[/color]"
		else:
			body_lbl.text = "[color=#00ff66][b]TELEMETRIA COMPLETA:[/b]\nTodos os dados de combate foram sincronizados com sucesso no drive.\n\nSelecione abaixo o integrante da equipe para sincronizar o Data Drive Calibrado:[/color]"

		var eligible = party_system_ref.get_eligible_drive_members() if party_system_ref else []
		if eligible.is_empty():
			body_lbl.text += "\n\n[color=#00ff66][NOTICE]: All crew members already possess an active Data Drive.[/color]" if lang == "en" else ("\n\n[color=#00ff66][通知]: 全メンバーが既にアクティブなデータドライブを所持しています。[/color]" if lang == "ja" else "\n\n[color=#00ff66][AVISO]: Todos os integrantes da equipe já possuem um Data Drive ativo.[/color]")
			var close_btn = Button.new()
			close_btn.text = "[ESC] Close Terminal" if lang == "en" else ("[ESC] 端末を閉じる" if lang == "ja" else "[ESC] Fechar Terminal")
			close_btn.custom_minimum_size = Vector2(460, 40)
			close_btn.add_theme_font_override("font", font_ui)
			close_btn.add_theme_color_override("font_color", RETRO_GREEN)
			close_btn.add_theme_stylebox_override("normal", btn_style)
			close_btn.pressed.connect(close_terminal)
			actions_vbox.add_child(close_btn)
			close_btn.grab_focus()
		else:
			for i in range(eligible.size()):
				var char_id = eligible[i]
				var char_name = _get_char_name(char_id)
				var btn = Button.new()
				btn.text = ("[%d] Sync Data Drive with %s" if lang == "en" else ("[%d] %s にデータドライブを同期" if lang == "ja" else "[%d] Sincronizar Data Drive com %s")) % ([i + 1, char_name] if lang != "ja" else [i + 1, char_name])
				btn.custom_minimum_size = Vector2(460, 38)
				btn.add_theme_font_override("font", font_ui)
				btn.add_theme_color_override("font_color", RETRO_GREEN)
				btn.add_theme_stylebox_override("normal", btn_style)
				btn.pressed.connect(func():
					emit_signal("drive_assigned", char_id, active_poi)
					close_terminal()
				)
				actions_vbox.add_child(btn)

			actions_vbox.get_child(0).grab_focus()

	# 3. EM PROGRESSO
	else:
		status_lbl.text = "STATUS: COLLECTING COMBAT DATA..." if lang == "en" else ("状態: 戦闘データ収集中..." if lang == "ja" else "STATUS: COLETANDO DADOS EM COMBATE...")
		if lang == "en":
			body_lbl.text = "[color=#00ff66][b]RECORDING IN PROGRESS:[/b]\n\n• Target: %s\n• Telemetry: %d / %d eliminated\n\nContinue patrolling this orbital floor until the quota is filled.[/color]" % [
				mission.enemy_name, mission.current_kills, mission.target_kills
			]
		elif lang == "ja":
			body_lbl.text = "[color=#00ff66][b]記録進行中:[/b]\n\n• 対象: %s\n• テレメトリ: %d / %d 撃破\n\nノルマが満たされるまで、この軌道階層の巡回を継続せよ。[/color]" % [
				mission.enemy_name, mission.current_kills, mission.target_kills
			]
		else:
			body_lbl.text = "[color=#00ff66][b]GRAVAÇÃO EM PROGRESSO:[/b]\n\n• Alvo: %s\n• Telemetria: %d / %d eliminados\n\nContinue patrulhando este andar orbital até completar a cota exigida.[/color]" % [
				mission.enemy_name, mission.current_kills, mission.target_kills
			]

		var close_btn = Button.new()
		close_btn.text = "[ ESC / E ] Exit Terminal" if lang == "en" else ("[ ESC / E ] 端末終了" if lang == "ja" else "[ ESC / E ] Sair do Terminal")
		close_btn.custom_minimum_size = Vector2(460, 42)
		close_btn.add_theme_font_override("font", font_ui)
		close_btn.add_theme_color_override("font_color", RETRO_GREEN)
		close_btn.add_theme_stylebox_override("normal", btn_style)
		close_btn.pressed.connect(close_terminal)
		actions_vbox.add_child(close_btn)
		close_btn.grab_focus()

	show()

func close_terminal():
	if not is_open: return
	is_open = false
	hide()
	emit_signal("closed")

func _unhandled_input(event: InputEvent):
	if not is_open: return
	
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

func _get_char_name(canonical_id: String) -> String:
	match canonical_id:
		"humano": return "Rigard"
		"mutante": return "Kira"
		"alien": return "Vaelthor"
		"robo": return "Unit-7"
		_: return canonical_id.capitalize()
