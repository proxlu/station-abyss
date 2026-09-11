# Main.gd
extends Node3D

var etapa_dois: bool = false

@export var enable_marching_footsteps: bool = true

var dungeon_generator = preload("res://ProceduralDungeon.gd").new()
var party_system = preload("res://PartySystem.gd").new()
var battle_engine = preload("res://BattleEngine.gd").new()
var minimap = preload("res://VectorMinimap.gd").new()
var dialogue_manager = preload("res://DialogueManager.gd").new()
var party_menu = preload("res://PartyMenu.gd").new()
var audio_manager = preload("res://AudioManager.gd").new()
var game_over_script = preload("res://GameOver.gd")
var space_spooter_script = preload("res://SpaceSpooterMinigame.gd")
var terminal_ui = preload("res://DataTerminalUI.gd").new()
var hole_keeper_ui = preload("res://HoleKeeperUI.gd").new()

var title_screen = preload("res://TitleScreen.gd").new()
var credits_screen = preload("res://Credits.gd").new()

var player: CharacterBody3D
var camera: Camera3D
var collision_shape: CollisionShape3D

var ui_canvas: CanvasLayer
var hud_panel: Panel
var hud_top_label: RichTextLabel
var hud_name_label: Label
var hud_hp_bar: ProgressBar
var hud_hp_text: Label
var hud_mp_bar: ProgressBar
var hud_mp_text: Label
var interaction_label: Label

var dialogue_panel: Panel
var dialogue_port_frame: Panel
var portrait_rect: TextureRect
var dialogue_label: RichTextLabel
var current_dialogue_char: String = ""

var is_game_started: bool = false
var is_transitioning_combat: bool = false
var is_fade_movement_locked: bool = false
var fade_rect: ColorRect

var active_tutorial_banner: Control = null

# Cutscenes
var cutscene_canvas: CanvasLayer
var cutscene_layer: Control
var cutscene_bg: TextureRect
var cutscene_panel: Panel
var cutscene_port_frame: Panel
var cutscene_portrait_rect: TextureRect
var cutscene_name_label: Label
var cutscene_text_label: RichTextLabel
var cutscene_prompt: Label
var is_in_cutscene: bool = false
var is_cutscene_input_locked: bool = false
var is_advancing_step: bool = false
var current_cutscene_char: String = ""
var cutscene_dialogue_queue: Array = []
var cutscene_on_complete: Callable
var cutscene_shake_tween: Tween = null
var cutscene_blink_id: int = 0

# Minigame Space Spooter
var active_spooter_minigame: Control = null
var current_active_arcade_poi: Dictionary = {}
var arcade_proximity_player: AudioStreamPlayer = null
var current_proximity_stream_path: String = ""
var is_arcade_input_locked: bool = false

var current_floor_mission: Dictionary = {}
var hud_cycle_mode: int = 0
var hud_cycle_timer: float = 0.0
var active_orbs: Array[Dictionary] = []
var valid_floor_cells: Array = []

var diag_tex_normal: Dictionary = {}
var diag_tex_closed: Dictionary = {}

var esc_confirm_panel: Panel
var is_esc_open = false

var current_floor = 1
var floor_key_found = false
var has_chronodox = false
var has_detector = false
var has_csouter = false
var detector_beep_timer: float = 0.0
var total_treasures_collected = 0
var total_enemies_killed = 0
var last_dungeon_snapshot: ImageTexture = null

var last_turn_direction: int = 0
var zigzag_turn_switches: int = 0
var zigzag_suppressed_count: int = 0

var pois = []
var step_counter = 0.0
var footstep_timer = 0.0

var current_sys_msg_id: int = 0
var pending_level_up_summary: String = ""

const ASSETS_DIR = "res://assets/"

static func get_game_font(category: String = "ui") -> Font:
	return FontManager.get_font(category)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.alt_pressed and event.keycode == KEY_ENTER) or event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var base_w = ProjectSettings.get_setting("display/window/size/viewport_width", 1280)
		var base_h = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
		var target_size = Vector2i(base_w, base_h)
		DisplayServer.window_set_size(target_size)
		var screen_id = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(screen_id)
		var centered_pos = (screen_size - target_size) / 2
		DisplayServer.window_set_position(centered_pos)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	setup_fade_overlay()
	preload_dialogue_textures()

	add_child(audio_manager)
	add_child(dungeon_generator)
	add_child(party_system)
	add_child(battle_engine)
	add_child(dialogue_manager)
	add_child(party_menu)
	dialogue_manager.party_system_ref = party_system

	arcade_proximity_player = AudioStreamPlayer.new()
	arcade_proximity_player.bus = "Master"
	add_child(arcade_proximity_player)

	setup_3d_environment()
	setup_player()
	setup_ui()
	setup_cutscene_ui()

	ui_canvas.add_child(hole_keeper_ui)
	hole_keeper_ui.closed.connect(func():
		hud_panel.show()
		minimap.show()
		if dialogue_manager: dialogue_manager.resume_dialogues()
	)

	ui_canvas.add_child(title_screen)
	title_screen.start_game_requested.connect(start_new_game)

	cutscene_canvas.add_child(credits_screen)
	credits_screen.return_to_title_requested.connect(show_title_screen)

	ui_canvas.add_child(terminal_ui)
	terminal_ui.mission_started.connect(func(m):
		m.is_active = true
		current_floor_mission = m
		update_hud()
	)
	terminal_ui.drive_assigned.connect(assign_drive_to_member_and_close)
	terminal_ui.closed.connect(func():
		hud_panel.show()
		minimap.show()
		if dialogue_manager: dialogue_manager.resume_dialogues()
	)

	dialogue_manager.dialogue_triggered.connect(_on_dialogue_triggered)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	battle_engine.battle_ended.connect(_on_battle_ended)
	party_system.party_leveled_up.connect(_on_party_leveled_up)

	show_title_screen()

func dismiss_tutorial_banner():
	if active_tutorial_banner and is_instance_valid(active_tutorial_banner):
		active_tutorial_banner.queue_free()
		active_tutorial_banner = null

func show_system_message(title_bbcode: String, body_bbcode: String, item_texture: Texture2D = null, on_complete: Callable = Callable(), sfx_name: String = ""):
	current_sys_msg_id += 1
	var this_id = current_sys_msg_id

	if dialogue_manager:
		dialogue_manager.pause_dialogues()

	if audio_manager and sfx_name != "":
		audio_manager.play_sfx(sfx_name)

	current_dialogue_char = ""

	if item_texture:
		if dialogue_port_frame: dialogue_port_frame.show()
		if portrait_rect: portrait_rect.texture = item_texture
		dialogue_label.position = Vector2(145, 15)
		dialogue_label.size = Vector2(dialogue_panel.size.x - 165, 110)
	else:
		if dialogue_port_frame: dialogue_port_frame.hide()
		dialogue_label.position = Vector2(25, 18)
		dialogue_label.size = Vector2(dialogue_panel.size.x - 50, 104)

	dialogue_label.text = "[b]%s[/b]\n%s" % [title_bbcode, body_bbcode]
	dialogue_panel.show()

	var sys_timer = get_tree().create_timer(4.5)
	sys_timer.timeout.connect(func():
		if current_sys_msg_id != this_id:
			return

		if on_complete.is_valid():
			if dialogue_manager:
				dialogue_manager.resume_dialogues()
			on_complete.call()
		else:
			dialogue_panel.hide()
			if dialogue_port_frame: dialogue_port_frame.hide()
			if dialogue_manager:
				dialogue_manager.resume_dialogues()
	)

func setup_fade_overlay():
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 125
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

func fade_to_transparent(duration: float = 0.5, callback: Callable = Callable()):
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if callback.is_valid(): tween.finished.connect(callback)

func fade_to_black(duration: float = 0.5, callback: Callable = Callable()):
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if callback.is_valid(): tween.finished.connect(callback)

static func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]

	# Compatibilidade transparente novo <-> antigo
	if base_name.begins_with("cutscene_"):
		candidates.append(base_name.replace("cutscene_", "cena_"))
	elif base_name.begins_with("cena_"):
		candidates.append(base_name.replace("cena_", "cutscene_"))

	if base_name.begins_with("char_port_"):
		candidates.append(base_name.replace("char_port_", "char_port_"))
	elif base_name.begins_with("char_port_"):
		candidates.append(base_name.replace("char_port_", "char_port_"))

	if base_name.begins_with("char_closed_"):
		candidates.append(base_name.replace("char_closed_", "char_closed_"))
	elif base_name.begins_with("char_closed_"):
		candidates.append(base_name.replace("char_closed_", "char_closed_"))

	if base_name == "ui_tutorial": candidates.append("ui_tutorial")
	elif base_name == "ui_tutorial": candidates.insert(0, "ui_tutorial")
	elif base_name == "ui_item_detector": candidates.append("char_port_detector")
	elif base_name == "char_port_detector": candidates.insert(0, "ui_item_detector")

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null

func show_title_screen():
	BattleEngine.reset_run_state()
	dismiss_tutorial_banner()

	is_game_started = false
	is_transitioning_combat = false
	is_fade_movement_locked = false
	is_esc_open = false
	is_in_cutscene = false
	is_cutscene_input_locked = false
	is_advancing_step = false
	cutscene_blink_id += 1

	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.color.a = 1.0

	if credits_screen:
		credits_screen.hide()

	stop_cutscene_bg_shake()
	silence_map_audio()

	if terminal_ui: terminal_ui.close_terminal()
	if hole_keeper_ui: hole_keeper_ui.close_ui()
	if active_spooter_minigame:
		active_spooter_minigame.queue_free()
		active_spooter_minigame = null

	clear_all_orbs()

	if dungeon_generator.floor_parent and is_instance_valid(dungeon_generator.floor_parent):
		dungeon_generator.floor_parent.queue_free()
		dungeon_generator.floor_parent = null

	if player: player.global_position = Vector3(0, -200, 0)

	if cutscene_layer: cutscene_layer.hide()
	if esc_confirm_panel: esc_confirm_panel.hide()
	if hud_panel: hud_panel.hide()
	if minimap: minimap.hide()
	if interaction_label: interaction_label.hide()
	if dialogue_panel: dialogue_panel.hide()
	if dialogue_manager: dialogue_manager.stop_dialogues()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio_manager.stop_bgm()
	title_screen.open_title(audio_manager)
	fade_to_transparent(0.7)

func start_new_game():
	BattleEngine.reset_run_state()
	fade_to_black(0.4, func():
		title_screen.hide()
		party_system.init_party()
		play_cutscene_prologue()
	)

func start_cutscene_bg_shake(intensity: float = 2.0, speed: float = 0.05):
	stop_cutscene_bg_shake()
	cutscene_shake_tween = create_tween().set_loops()
	cutscene_shake_tween.tween_callback(func():
		if is_instance_valid(cutscene_bg):
			cutscene_bg.position = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	).set_delay(speed)

func stop_cutscene_bg_shake():
	if cutscene_shake_tween and cutscene_shake_tween.is_valid():
		cutscene_shake_tween.kill()
		cutscene_shake_tween = null
	if is_instance_valid(cutscene_bg): cutscene_bg.position = Vector2.ZERO

func play_cutscene_prologue():
	var lang = Localization.current_language
	var prologue_dialogues = []

	var scene_name = "cutscene_prologo" if load_texture_safe("cutscene_prologo") else "cutscene_prologo"

	if lang == "en":
		prologue_dialogues = [
			{"character_id": "humano", "image": scene_name, "bgm": "bgm_spaceship", "delay_before": 1.2, "speaker": "Rigard", "text": "Checklist of approach complete. Has everyone checked gear and supplies before descent?"},
			{"character_id": "mutante", "speaker": "Kira", "text": "Claws sharp, weapons clean and my backpack is full of snacks! When do we get to smash things?"},
			{"character_id": "alien", "speaker": "Vaelthor", "text": "Those 'snacks' of yours carry a peculiar stench that defies all biological laws of my homeworld..."},
			{"character_id": "robo", "speaker": "Unit-7", "text": "Estimated docking time at Station Abyss: 45 seconds. I advise all crew to secure inertial restraints."}
		]
	elif lang == "ja":
		prologue_dialogues = [
			{"character_id": "humano", "image": scene_name, "bgm": "bgm_spaceship", "delay_before": 1.2, "speaker": "Rigard", "text": "アプローチチェックリスト完了。降下前に全員装備と補給品の点検は済んだか？"},
			{"character_id": "mutante", "speaker": "Kira", "text": "爪はピカピカ、武器も清掃済み、リュックはおやつでパンパンよ！で、いつ暴れられるの？"},
			{"character_id": "alien", "speaker": "Vaelthor", "text": "その『おやつ』とやらは、我が故郷の生物学法則をことごとく無視した奇妙な悪臭を放っているな..."},
			{"character_id": "robo", "speaker": "Unit-7", "text": "Station Abyss へのドッキング予想時刻: 45秒後。全員、慣性ハーネスを装着することを推奨します。"}
		]
	else:
		prologue_dialogues = [
			{"character_id": "humano", "image": scene_name, "bgm": "bgm_spaceship", "delay_before": 1.2, "speaker": "Rigard", "text": "Checklist de aproximação concluído. Todo mundo revisou o equipamento e os suprimentos antes da descida?"},
			{"character_id": "mutante", "speaker": "Kira", "text": "Garras afiadas, armas limpas e minha mochila tá lotada de petiscos! Quando a gente chega pra quebrar umas coisas?"},
			{"character_id": "alien", "speaker": "Vaelthor", "text": "Esses seus 'petiscos' têm um odor peculiar que desafia todas as leis biológicas do meu planeta natal..."},
			{"character_id": "robo", "speaker": "Unit-7", "text": "Tempo estimado para acoplagem na Station Abyss: 45 segundos. Recomendo que todos travem os cintos inerciais."}
		]

	start_cutscene_bg_shake(2.2, 0.06)
	start_story_cutscene(prologue_dialogues, func():
		stop_cutscene_bg_shake()
		audio_manager.stop_bgm(0.6)
		fade_to_black(0.6, func(): enter_dungeon_after_prologue())
	)

func enter_dungeon_after_prologue():
	is_game_started = true
	is_fade_movement_locked = true
	is_esc_open = false
	current_floor = 1
	total_treasures_collected = 0
	total_enemies_killed = 0
	floor_key_found = false
	has_chronodox = false
	has_detector = false
	has_csouter = false
	detector_beep_timer = 0.0
	last_dungeon_snapshot = null
	current_floor_mission.clear()
	zigzag_turn_switches = 0
	zigzag_suppressed_count = 0

	load_floor(1)

	hud_panel.show()
	minimap.show()
	audio_manager.play_bgm("bgm_dungeon", true, 1.0)

	fade_to_transparent(0.6, func():
		is_fade_movement_locked = false
		var tut_timer = get_tree().create_timer(1.0)
		tut_timer.timeout.connect(_show_dungeon_tutorial_banner)

		var delay_start = get_tree().create_timer(1.6)
		delay_start.timeout.connect(func():
			if is_game_started and not battle_engine.is_in_battle and not is_in_cutscene and not active_spooter_minigame:
				dialogue_manager.start_intro_sequence()
		)
	)

func _show_dungeon_tutorial_banner():
	if not is_game_started or is_in_cutscene or battle_engine.is_in_battle or party_menu.is_open or is_esc_open:
		return

	dismiss_tutorial_banner()

	var tut_tex = load_texture_safe("ui_tutorial")
	if not tut_tex: tut_tex = load_texture_safe("ui_tutorial")
	if not tut_tex: return

	var tut_container = Control.new()
	tut_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tut_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_container.modulate.a = 0.0

	ui_canvas.add_child(tut_container)
	ui_canvas.move_child(tut_container, 0)
	active_tutorial_banner = tut_container

	var tut_rect = TextureRect.new()
	tut_rect.texture = tut_tex
	tut_rect.anchor_left = 0.00
	tut_rect.anchor_right = 1.0
	tut_rect.anchor_top = 0.0
	tut_rect.anchor_bottom = 1.0
	tut_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tut_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tut_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_container.add_child(tut_rect)

	var tw_in = create_tween()
	tw_in.tween_property(tut_container, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

	var hold_timer = get_tree().create_timer(15.0)
	hold_timer.timeout.connect(func():
		if is_instance_valid(active_tutorial_banner):
			var banner = active_tutorial_banner
			var tw_out = create_tween()
			tw_out.tween_property(banner, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
			tw_out.finished.connect(func():
				if is_instance_valid(banner):
					banner.queue_free()
				if active_tutorial_banner == banner:
					active_tutorial_banner = null
			)
	)

func preload_dialogue_textures():
	for c in ["humano", "mutante", "alien", "robo"]:
		var norm_tex = load_texture_safe("char_port_" + c)
		if not norm_tex: norm_tex = load_texture_safe("char_port_" + c)

		var clos_tex = load_texture_safe("char_closed_" + c)
		if not clos_tex: clos_tex = load_texture_safe("char_closed_" + c)

		if norm_tex: diag_tex_normal[c] = norm_tex
		if clos_tex: diag_tex_closed[c] = clos_tex
		elif diag_tex_normal.has(c): diag_tex_closed[c] = diag_tex_normal[c]

func get_canonical_char_id(raw_id: String) -> String:
	var s = raw_id.to_lower().strip_edges()
	if s in ["humano", "rigard", "capitao"]: return "humano"
	if s in ["mutante", "kira"]: return "mutante"
	if s in ["alien", "vaelthor", "vael"]: return "alien"
	if s in ["robo", "unit-7", "unit7", "androide"]: return "robo"
	return s

func get_display_name(canonical_id: String) -> String:
	match canonical_id:
		"humano": return "Rigard"
		"mutante": return "Kira"
		"alien": return "Vaelthor"
		"robo": return "Unit-7"
		_: return canonical_id.capitalize()

func setup_3d_environment():
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.2, 0.3)
	env.fog_enabled = true
	env.fog_density = 0.06
	env.fog_light_color = Color(0.01, 0.02, 0.04)

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func setup_player():
	player = CharacterBody3D.new()
	add_child(player)

	collision_shape = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.6
	collision_shape.shape = shape
	collision_shape.position.y = 0.8
	player.add_child(collision_shape)

	camera = Camera3D.new()
	camera.position.y = 1.5
	camera.rotation.x = deg_to_rad(-15.0)
	player.add_child(camera)

func setup_ui():
	ui_canvas = CanvasLayer.new()
	add_child(ui_canvas)

	var vp_size = get_viewport().get_visible_rect().size

	var font_title = get_game_font("title")
	var font_mono = get_game_font("mono")
	var font_ui = get_game_font("ui")

	var hud_style = StyleBoxFlat.new()
	hud_style.bg_color = Color(0.02, 0.04, 0.09, 0.94)
	hud_style.border_width_left = 2
	hud_style.border_width_top = 2
	hud_style.border_width_right = 2
	hud_style.border_width_bottom = 2
	hud_style.border_color = Color(0.0, 0.85, 1.0, 0.8)
	hud_style.corner_radius_top_left = 4
	hud_style.corner_radius_top_right = 4
	hud_style.corner_radius_bottom_right = 4
	hud_style.corner_radius_bottom_left = 4

	hud_panel = Panel.new()
	hud_panel.position = Vector2(20, 20)
	hud_panel.size = Vector2(300, 119)
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	ui_canvas.add_child(hud_panel)

	var hud_layout = VBoxContainer.new()
	hud_layout.position = Vector2(12, 9)
	hud_layout.size = Vector2(276, 110)
	hud_layout.add_theme_constant_override("separation", 2)
	hud_panel.add_child(hud_layout)

	hud_top_label = RichTextLabel.new()
	hud_top_label.custom_minimum_size = Vector2(276, 42)
	hud_top_label.size = Vector2(276, 42)
	hud_top_label.fit_content = true
	hud_top_label.bbcode_enabled = true
	hud_top_label.scroll_active = false
	hud_top_label.add_theme_font_override("normal_font", font_ui)
	hud_top_label.add_theme_font_override("bold_font", font_title)
	hud_top_label.add_theme_font_size_override("normal_font_size", 11)
	hud_top_label.add_theme_font_size_override("bold_font_size", 11)
	hud_layout.add_child(hud_top_label)

	var separator = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.0, 0.8, 1.0, 0.5)
	separator.add_theme_stylebox_override("separator", sep_style)
	hud_layout.add_child(separator)

	hud_name_label = Label.new()
	hud_name_label.add_theme_font_override("font", font_ui)
	hud_name_label.add_theme_font_size_override("font_size", 12)
	hud_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hud_name_label.add_theme_constant_override("outline_size", 2)
	hud_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_layout.add_child(hud_name_label)

	var bar_bg_hp = StyleBoxFlat.new()
	bar_bg_hp.bg_color = Color(0.02, 0.05, 0.08, 0.9)
	bar_bg_hp.border_width_left = 1
	bar_bg_hp.border_width_top = 1
	bar_bg_hp.border_width_right = 1
	bar_bg_hp.border_width_bottom = 1
	bar_bg_hp.border_color = Color(0.0, 0.7, 0.9, 0.7)
	bar_bg_hp.corner_radius_top_left = 2
	bar_bg_hp.corner_radius_top_right = 2
	bar_bg_hp.corner_radius_bottom_right = 2
	bar_bg_hp.corner_radius_bottom_left = 2

	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.0, 0.85, 1.0)
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_right = 2
	hp_fill.corner_radius_bottom_left = 2

	hud_hp_bar = ProgressBar.new()
	hud_hp_bar.custom_minimum_size = Vector2(276, 15)
	hud_hp_bar.show_percentage = false
	hud_hp_bar.add_theme_stylebox_override("background", bar_bg_hp)
	hud_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hud_layout.add_child(hud_hp_bar)

	hud_hp_text = Label.new()
	hud_hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_hp_text.add_theme_font_override("font", font_mono)
	hud_hp_text.add_theme_font_size_override("font_size", 10)
	hud_hp_text.add_theme_color_override("font_color", Color(1, 1, 1))
	hud_hp_text.add_theme_constant_override("outline_size", 2)
	hud_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	hud_hp_bar.add_child(hud_hp_text)

	var bar_bg_mp = StyleBoxFlat.new()
	bar_bg_mp.bg_color = Color(0.05, 0.02, 0.08, 0.9)
	bar_bg_mp.border_width_left = 1
	bar_bg_mp.border_width_top = 1
	bar_bg_mp.border_width_right = 1
	bar_bg_mp.border_width_bottom = 1
	bar_bg_mp.border_color = Color(0.75, 0.2, 1.0, 0.7)
	bar_bg_mp.corner_radius_top_left = 2
	bar_bg_mp.corner_radius_top_right = 2
	bar_bg_mp.corner_radius_bottom_right = 2
	bar_bg_mp.corner_radius_bottom_left = 2

	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.75, 0.1, 1.0)
	mp_fill.corner_radius_top_left = 2
	mp_fill.corner_radius_top_right = 2
	mp_fill.corner_radius_bottom_right = 2
	mp_fill.corner_radius_bottom_left = 2

	hud_mp_bar = ProgressBar.new()
	hud_mp_bar.custom_minimum_size = Vector2(276, 13)
	hud_mp_bar.show_percentage = false
	hud_mp_bar.add_theme_stylebox_override("background", bar_bg_mp)
	hud_mp_bar.add_theme_stylebox_override("fill", mp_fill)
	hud_layout.add_child(hud_mp_bar)

	hud_mp_text = Label.new()
	hud_mp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_mp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_mp_text.add_theme_font_override("font", font_mono)
	hud_mp_text.add_theme_font_size_override("font_size", 9)
	hud_mp_text.add_theme_color_override("font_color", Color(1, 1, 1))
	hud_mp_text.add_theme_constant_override("outline_size", 2)
	hud_mp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	hud_mp_bar.add_child(hud_mp_text)

	ui_canvas.add_child(minimap)
	minimap.custom_minimum_size = Vector2(180, 180)
	minimap.size = Vector2(180, 180)
	minimap.position = Vector2(vp_size.x - 200, 20)

	interaction_label = Label.new()
	interaction_label.position = Vector2(0, vp_size.y - 240)
	interaction_label.size = Vector2(vp_size.x, 30)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_override("font", font_ui)
	interaction_label.add_theme_font_size_override("font_size", 18)
	interaction_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	interaction_label.add_theme_constant_override("outline_size", 4)
	interaction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	interaction_label.hide()
	ui_canvas.add_child(interaction_label)

	esc_confirm_panel = Panel.new()
	esc_confirm_panel.position = Vector2(vp_size.x / 2.0 - 180, 280)
	esc_confirm_panel.size = Vector2(360, 160)
	var esc_style = StyleBoxFlat.new()
	esc_style.bg_color = Color(0.02, 0.03, 0.06, 0.98)
	esc_style.border_width_top = 2
	esc_style.border_color = Color(1, 0.2, 0.2)
	esc_confirm_panel.add_theme_stylebox_override("panel", esc_style)
	esc_confirm_panel.hide()
	ui_canvas.add_child(esc_confirm_panel)

	var esc_lbl = Label.new()
	esc_lbl.text = Localization.t("esc_confirm_title", "RETORNAR AO TÍTULO?")
	esc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_lbl.position = Vector2(0, 20)
	esc_lbl.size = Vector2(360, 30)
	esc_lbl.add_theme_font_override("font", font_title)
	esc_lbl.add_theme_font_size_override("font_size", 16)
	esc_lbl.add_theme_constant_override("outline_size", 2)
	esc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	esc_confirm_panel.add_child(esc_lbl)

	var yes_btn = Button.new()
	yes_btn.text = Localization.t("esc_confirm_yes", "SIM (Sair)")
	yes_btn.position = Vector2(40, 80)
	yes_btn.size = Vector2(120, 40)
	yes_btn.add_theme_font_override("font", font_ui)
	yes_btn.add_theme_font_size_override("font_size", 14)
	yes_btn.pressed.connect(func():
		audio_manager.play_sfx("sfx_menu_select")
		fade_to_black(0.35, func(): show_title_screen())
	)
	esc_confirm_panel.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = Localization.t("esc_confirm_no", "NÃO")
	no_btn.position = Vector2(200, 80)
	no_btn.size = Vector2(120, 40)
	no_btn.add_theme_font_override("font", font_ui)
	no_btn.add_theme_font_size_override("font_size", 14)
	no_btn.pressed.connect(func(): toggle_esc_menu())
	esc_confirm_panel.add_child(no_btn)

	var diag_style = StyleBoxFlat.new()
	diag_style.bg_color = Color(0.02, 0.03, 0.07, 0.95)
	diag_style.border_width_left = 2
	diag_style.border_color = Color(0.0, 1.0, 1.0, 1.0)

	var diag_h = 140.0
	var diag_w = min(1024.0, vp_size.x - 60.0)
	var diag_x = (vp_size.x - diag_w) / 2.0
	var diag_y = vp_size.y - diag_h - 50.0

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(diag_x, diag_y)
	dialogue_panel.size = Vector2(diag_w, diag_h)
	dialogue_panel.add_theme_stylebox_override("panel", diag_style)
	dialogue_panel.hide()
	ui_canvas.add_child(dialogue_panel)

	dialogue_port_frame = Panel.new()
	dialogue_port_frame.position = Vector2(10, 10)
	dialogue_port_frame.size = Vector2(120, 120)
	var pf_style = StyleBoxFlat.new()
	pf_style.bg_color = Color(0.02, 0.04, 0.08, 0.9)
	pf_style.corner_radius_top_left = 3
	pf_style.corner_radius_top_right = 3
	pf_style.corner_radius_bottom_right = 3
	pf_style.corner_radius_bottom_left = 3
	dialogue_port_frame.add_theme_stylebox_override("panel", pf_style)
	dialogue_panel.add_child(dialogue_port_frame)

	portrait_rect = TextureRect.new()
	portrait_rect.position = Vector2.ZERO
	portrait_rect.custom_minimum_size = Vector2(120, 120)
	portrait_rect.size = Vector2(120, 120)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialogue_port_frame.add_child(portrait_rect)

	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(145, 15)
	dialogue_label.size = Vector2(diag_w - 165, 110)
	dialogue_label.bbcode_enabled = true
	dialogue_label.scroll_active = false
	dialogue_label.add_theme_font_override("normal_font", font_ui)
	dialogue_label.add_theme_font_override("bold_font", font_ui)
	dialogue_label.add_theme_font_size_override("normal_font_size", 14)
	dialogue_label.add_theme_font_size_override("bold_font_size", 15)
	dialogue_panel.add_child(dialogue_label)

func setup_cutscene_ui():
	var vp_size = get_viewport().get_visible_rect().size
	var font_title = get_game_font("title")
	var font_ui = get_game_font("ui")

	cutscene_canvas = CanvasLayer.new()
	cutscene_canvas.layer = 25
	add_child(cutscene_canvas)

	cutscene_layer = Control.new()
	cutscene_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene_layer.hide()
	cutscene_canvas.add_child(cutscene_layer)

	var c_bg_color = ColorRect.new()
	c_bg_color.color = Color(0.0, 0.0, 0.0, 1.0)
	c_bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_bg_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutscene_layer.add_child(c_bg_color)

	cutscene_bg = TextureRect.new()
	cutscene_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cutscene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cutscene_layer.add_child(cutscene_bg)

	var diag_h = 140.0
	var diag_w = min(1024.0, vp_size.x - 60.0)
	var diag_x = (vp_size.x - diag_w) / 2.0
	var diag_y = vp_size.y - diag_h - 50.0

	cutscene_panel = Panel.new()
	cutscene_panel.position = Vector2(diag_x, diag_y)
	cutscene_panel.size = Vector2(diag_w, diag_h)
	cutscene_layer.add_child(cutscene_panel)

	cutscene_port_frame = Panel.new()
	cutscene_port_frame.position = Vector2(10, 10)
	cutscene_port_frame.size = Vector2(120, 120)
	var pf_style = StyleBoxFlat.new()
	pf_style.bg_color = Color(0.02, 0.04, 0.08, 0.9)
	pf_style.corner_radius_top_left = 3
	pf_style.corner_radius_top_right = 3
	pf_style.corner_radius_bottom_right = 3
	pf_style.corner_radius_bottom_left = 3
	cutscene_port_frame.add_theme_stylebox_override("panel", pf_style)
	cutscene_panel.add_child(cutscene_port_frame)

	cutscene_portrait_rect = TextureRect.new()
	cutscene_portrait_rect.position = Vector2.ZERO
	cutscene_portrait_rect.custom_minimum_size = Vector2(120, 120)
	cutscene_portrait_rect.size = Vector2(120, 120)
	cutscene_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cutscene_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cutscene_port_frame.add_child(cutscene_portrait_rect)

	cutscene_name_label = Label.new()
	cutscene_name_label.position = Vector2(145, 12)
	cutscene_name_label.size = Vector2(500, 24)
	cutscene_name_label.add_theme_font_override("font", font_ui)
	cutscene_name_label.add_theme_font_size_override("font_size", 15)
	cutscene_panel.add_child(cutscene_name_label)

	cutscene_text_label = RichTextLabel.new()
	cutscene_text_label.position = Vector2(145, 38)
	cutscene_text_label.size = Vector2(diag_w - 165, 85)
	cutscene_text_label.bbcode_enabled = true
	cutscene_text_label.scroll_active = false
	cutscene_text_label.add_theme_font_override("normal_font", font_ui)
	cutscene_text_label.add_theme_font_override("bold_font", font_ui)
	cutscene_text_label.add_theme_font_size_override("normal_font_size", 14)
	cutscene_panel.add_child(cutscene_text_label)

	cutscene_prompt = Label.new()
	var lang = Localization.current_language
	cutscene_prompt.text = "[E / SPACE / A] Continue" if lang == "en" else ("[E / スペース / A] 続ける" if lang == "ja" else "[E / ESPAÇO / A] Avançar")
	cutscene_prompt.position = Vector2(diag_w - 250, diag_h - 26)
	cutscene_prompt.size = Vector2(230, 20)
	cutscene_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cutscene_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cutscene_prompt.add_theme_font_override("font", font_ui)
	cutscene_prompt.add_theme_font_size_override("font_size", 11)
	cutscene_prompt.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 0.7))
	cutscene_panel.add_child(cutscene_prompt)

func execute_field_heal_rest():
	var healed_members: Array[String] = []

	for k in ["humano", "mutante", "alien", "robo"]:
		if k == "mutante" and party_system.is_kira_away:
			continue
		if party_system.members.has(k):
			var m = party_system.members[k]
			if m.hp > 0 and m.mp >= 10:
				m.mp -= 10
				var base_heal = (party_system.members["robo"].heal_power / 2) + 25 if party_system.members.has("robo") else 35
				var heal_val = base_heal + (m.skill_heal_lvl * 4)

				var overflow = (m.hp + heal_val) - m.max_hp
				if overflow > 0:
					m.hp = m.max_hp
					if k == "robo":
						m.shield = max(m.shield, min(heal_val, overflow))
				else:
					m.hp += heal_val

				healed_members.append(k)

	if healed_members.is_empty():
		if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
		return

	update_hud()

	var protagonist_healed = healed_members.has("humano")
	if protagonist_healed:
		var flash = ColorRect.new()
		flash.color = Color(0.0, 0.85, 1.0, 0.5)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_canvas.add_child(flash)
		var t = create_tween()
		t.tween_property(flash, "color:a", 0.0, 0.5)
		t.finished.connect(flash.queue_free)

	if audio_manager:
		if protagonist_healed:
			audio_manager.play_sfx("sfx_heal", 0.0, 0.0)
		else:
			audio_manager.play_sfx("sfx_heal", 0.0, -9.0)

	if dialogue_manager and not healed_members.is_empty():
		var chosen_speaker = healed_members[randi() % healed_members.size()]
		dialogue_manager.trigger_dialogue("magia_cura_campo", chosen_speaker)

func silence_map_audio():
	if arcade_proximity_player and arcade_proximity_player.playing:
		arcade_proximity_player.stop()
		current_proximity_stream_path = ""

func is_exploration_active() -> bool:
	if not is_game_started: return false
	if is_in_cutscene: return false
	if is_transitioning_combat: return false
	if is_fade_movement_locked: return false
	if fade_rect and fade_rect.color.a > 0.05: return false
	if battle_engine and battle_engine.is_in_battle: return false
	if party_menu and party_menu.is_open: return false
	if is_esc_open: return false
	if active_spooter_minigame != null: return false
	if terminal_ui and terminal_ui.is_open: return false
	if hole_keeper_ui and hole_keeper_ui.is_open: return false
	if credits_screen and credits_screen.visible: return false
	return true

func start_story_cutscene(dialogues: Array, on_finish: Callable):
	dismiss_tutorial_banner()

	is_in_cutscene = true
	is_cutscene_input_locked = false
	is_advancing_step = false
	cutscene_dialogue_queue = dialogues.duplicate()
	cutscene_on_complete = on_finish

	silence_map_audio()

	if hud_panel: hud_panel.hide()
	if minimap: minimap.hide()
	if dialogue_panel: dialogue_panel.hide()
	if dialogue_manager: dialogue_manager.pause_dialogues()

	var lang = Localization.current_language
	cutscene_prompt.text = "[E / SPACE / A] Continue" if lang == "en" else ("[E / スペース / A] 続ける" if lang == "ja" else "[E / ESPAÇO / A] Avançar")
	cutscene_prompt.show()
	cutscene_layer.show()
	fade_to_transparent(0.4)
	advance_cutscene()

func advance_cutscene():
	if is_advancing_step or is_cutscene_input_locked: return
	if cutscene_dialogue_queue.is_empty():
		end_story_cutscene()
		return

	is_advancing_step = true
	var step = cutscene_dialogue_queue.pop_front()
	var pause_delay: float = step.get("delay_before", 0.0)

	if step.has("image"):
		var img_name = step.get("image", "")
		if img_name != "":
			cutscene_bg.texture = load_texture_safe(img_name)
		else:
			cutscene_bg.texture = null

	if step.has("sfx") and step.sfx != "": audio_manager.play_sfx(step.sfx)
	if step.has("bgm"):
		if step.bgm == "": audio_manager.stop_bgm()
		else: audio_manager.play_bgm(step.bgm, true, 1.0)

	if step.has("blackout_flicker") and step.blackout_flicker == true:
		var flash = ColorRect.new()
		flash.color = Color(0, 0, 0, 1)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		cutscene_layer.add_child(flash)
		var t_flicker = create_tween()
		t_flicker.tween_property(flash, "color:a", 0.0, 0.08)
		t_flicker.tween_property(flash, "color:a", 1.0, 0.08)
		t_flicker.tween_property(flash, "color:a", 0.0, 0.08)
		t_flicker.tween_property(flash, "color:a", 1.0, 0.12)
		t_flicker.finished.connect(flash.queue_free)

	if step.has("fade_in_reveal") and step.fade_in_reveal == true:
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.color.a = 1.0
		fade_to_transparent(0.8)

	if step.has("flash_heal") and step.flash_heal == true:
		var heal_timer = get_tree().create_timer(0.6)
		heal_timer.timeout.connect(func():
			var flash = ColorRect.new()
			flash.color = Color(0.0, 0.85, 1.0, 0.6)
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			cutscene_layer.add_child(flash)
			var t = create_tween()
			t.tween_property(flash, "color:a", 0.0, 0.6)
			t.finished.connect(flash.queue_free)
			audio_manager.play_sfx("sfx_heal")
			party_system.heal_all_full()
		)

	if pause_delay > 0.0:
		cutscene_panel.hide()
		is_cutscene_input_locked = true
		await get_tree().create_timer(pause_delay).timeout
		if not is_in_cutscene: return
		is_cutscene_input_locked = false
		display_cutscene_dialogue_content(step)
		cutscene_panel.show()
	else:
		display_cutscene_dialogue_content(step)
		cutscene_panel.show()

	is_advancing_step = false

func display_cutscene_dialogue_content(step: Dictionary):
	var char_id = step.get("character_id", "")
	var speaker = step.get("speaker", "")
	var text_content = step.get("text", "")
	var canon_id = get_canonical_char_id(char_id)
	current_cutscene_char = canon_id

	cutscene_blink_id += 1
	var this_blink_id = cutscene_blink_id

	if char_id == "khen_dark":
		cutscene_port_frame.hide()
		cutscene_name_label.text = ""
		cutscene_text_label.position = Vector2(30, 30)
		cutscene_text_label.size = Vector2(cutscene_panel.size.x - 60, 85)
		cutscene_text_label.text = "[b][color=#ff3344][i]« %s »[/i][/color][/b]" % text_content
		var khen_dark_style = StyleBoxFlat.new()
		khen_dark_style.bg_color = Color(0.04, 0.01, 0.02, 0.96)
		khen_dark_style.border_width_left = 2
		khen_dark_style.border_color = Color(1.0, 0.1, 0.2, 0.9)
		cutscene_panel.add_theme_stylebox_override("panel", khen_dark_style)

	elif char_id == "khen":
		cutscene_port_frame.hide()
		cutscene_name_label.position = Vector2(30, 12)
		cutscene_name_label.text = speaker
		cutscene_name_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3))
		cutscene_text_label.position = Vector2(30, 38)
		cutscene_text_label.size = Vector2(cutscene_panel.size.x - 60, 85)
		cutscene_text_label.text = "[color=#ff8899][b]%s[/b][/color]" % text_content
		var khen_style = StyleBoxFlat.new()
		khen_style.bg_color = Color(0.05, 0.01, 0.03, 0.96)
		khen_style.border_width_left = 3
		khen_style.border_color = Color(1.0, 0.2, 0.2, 1.0)
		cutscene_panel.add_theme_stylebox_override("panel", khen_style)

	else:
		cutscene_port_frame.show()
		cutscene_portrait_rect.texture = diag_tex_normal.get(canon_id, null)
		cutscene_name_label.position = Vector2(145, 12)
		cutscene_name_label.text = speaker
		cutscene_name_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		cutscene_text_label.position = Vector2(145, 38)
		cutscene_text_label.size = Vector2(cutscene_panel.size.x - 165, 85)
		cutscene_text_label.text = "[color=#ffffff]%s[/color]" % text_content
		var norm_style = StyleBoxFlat.new()
		norm_style.bg_color = Color(0.02, 0.03, 0.07, 0.95)
		norm_style.border_width_left = 2
		norm_style.border_color = Color(0.0, 1.0, 1.0, 1.0)
		cutscene_panel.add_theme_stylebox_override("panel", norm_style)

		_start_cutscene_blink_loop(canon_id, this_blink_id)

func _start_cutscene_blink_loop(canon_id: String, my_id: int):
	if not diag_tex_closed.has(canon_id) or not diag_tex_normal.has(canon_id):
		return

	var delay = randf_range(1.6, 2.6)
	var t = get_tree().create_timer(delay)
	t.timeout.connect(func():
		if is_in_cutscene and cutscene_blink_id == my_id and current_cutscene_char == canon_id:
			if is_instance_valid(cutscene_portrait_rect):
				cutscene_portrait_rect.texture = diag_tex_closed[canon_id]
				var reopen = get_tree().create_timer(0.16)
				reopen.timeout.connect(func():
					if is_in_cutscene and cutscene_blink_id == my_id and current_cutscene_char == canon_id:
						if is_instance_valid(cutscene_portrait_rect):
							cutscene_portrait_rect.texture = diag_tex_normal[canon_id]
							_start_cutscene_blink_loop(canon_id, my_id)
				)
	)

func end_story_cutscene():
	stop_cutscene_bg_shake()
	cutscene_blink_id += 1
	is_in_cutscene = false
	is_cutscene_input_locked = true
	cutscene_panel.hide()
	cutscene_prompt.hide()
	cutscene_layer.hide()

	if cutscene_on_complete.is_valid():
		var cb = cutscene_on_complete
		cutscene_on_complete = Callable()
		cb.call()

func load_floor(floor_num: int, is_fall: bool = false, floors_fallen: int = 0):
	dismiss_tutorial_banner()

	current_floor = floor_num
	floor_key_found = false
	current_floor_mission.clear()
	clear_all_orbs()

	var has_buff = party_system.has_perfect_defense_buff
	var eligible_rem = party_system.get_eligible_drive_members().size() > 0

	var floor_data = dungeon_generator.generate_floor(floor_num, etapa_dois, has_buff, eligible_rem, has_csouter, has_detector)
	pois = floor_data.pois
	valid_floor_cells = floor_data.get("floor_cells", [])
	current_floor_mission = floor_data.get("floor_mission", {})

	player.global_position = Vector3(floor_data.spawn_pos.x, 0, floor_data.spawn_pos.y)
	player.rotation.y = floor_data.spawn_rot_y

	minimap.reset_minimap()
	update_hud()

	if is_fall:
		if audio_manager: audio_manager.play_sfx("sfx_break")
		var fall_timer = get_tree().create_timer(1.2)
		fall_timer.timeout.connect(func():
			if is_game_started and not battle_engine.is_in_battle and not is_in_cutscene:
				dialogue_manager.trigger_floor_fall_dialogue(floors_fallen)
		)
	else:
		if audio_manager: audio_manager.play_sfx("sfx_portal")

	if floor_num > 1 and not is_fall and dialogue_manager.is_inside_tree():
		var floor_look_timer = get_tree().create_timer(1.5)
		floor_look_timer.timeout.connect(func():
			if is_game_started and not battle_engine.is_in_battle and not is_in_cutscene and not active_spooter_minigame:
				dialogue_manager.trigger_dialogue("corredor_escuro")
		)

func update_hud():
	var leader = party_system.members["humano"]

	if hud_cycle_mode == 1 and not current_floor_mission.is_empty() and current_floor_mission.get("is_active", false):
		if current_floor_mission.is_completed:
			hud_top_label.text = "[color=#00ff66]" + Localization.t("hud_mission_complete", "DADOS COLETADOS\nRequisito Concluído!\nRetorne ao Terminal!") + "[/color]"
		else:
			hud_top_label.text = Localization.t("hud_mission_title", "MISSÃO DATA DRIVE:\nCaçar %s: %02d/%02d\nAndar Orbital %d") % [
				current_floor_mission.enemy_name,
				current_floor_mission.current_kills,
				current_floor_mission.target_kills,
				current_floor
			]
	else:
		var key_str = Localization.t("hud_key_yes", "SIM (ALERTA ATIVO)") if floor_key_found else Localization.t("hud_key_no", "NÃO")
		var floor_fmt = Localization.t("hud_floor", "ANDAR: %d (Estação Orbital)\nCHAVE: %s\nTESOUROS: %d")
		hud_top_label.text = "[color=#e6e6ff]" + (floor_fmt % [
			current_floor, key_str, total_treasures_collected
		]) + "[/color]"

	hud_name_label.text = "Rigard (%s) Lv.%d" % [Localization.t("role_humano", "Capitão"), leader.level]
	hud_hp_bar.max_value = leader.max_hp
	hud_hp_bar.value = max(0, leader.hp)
	if leader.shield > 0:
		hud_hp_text.text = "%d / %d [+%d]" % [max(0, leader.hp), leader.max_hp, leader.shield]
	else:
		hud_hp_text.text = "%d / %d" % [max(0, leader.hp), leader.max_hp]

	hud_mp_bar.max_value = leader.max_mp
	hud_mp_bar.value = max(0, leader.mp)
	hud_mp_text.text = "%d / %d" % [max(0, leader.mp), leader.max_mp]

func toggle_esc_menu():
	if not is_game_started or is_in_cutscene or credits_screen.visible or active_spooter_minigame != null or (terminal_ui and terminal_ui.is_open) or (hole_keeper_ui and hole_keeper_ui.is_open):
		return
	is_esc_open = !is_esc_open
	if is_esc_open:
		dismiss_tutorial_banner()
		if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
		esc_confirm_panel.show()
		var no_btn = esc_confirm_panel.get_child(2)
		if no_btn is Button: no_btn.grab_focus()
	else:
		esc_confirm_panel.hide()

func _unhandled_input(event):
	# ATALHOS DE TESTE RÁPIDO:
	if etapa_dois:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_F1:
				has_csouter = true
				start_combat()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_F2:
				start_space_spooter_arcade({})
				get_viewport().set_input_as_handled()
				return
	if is_in_cutscene:
		if is_cutscene_input_locked or is_advancing_step: return
		var is_adv = false
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			is_adv = true
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
			is_adv = true

		if is_adv:
			advance_cutscene()
			get_viewport().set_input_as_handled()
		return

	if not is_game_started or active_spooter_minigame != null or (terminal_ui and terminal_ui.is_open) or (hole_keeper_ui and hole_keeper_ui.is_open) or credits_screen.visible:
		return

	var is_tab = false
	var is_esc = false
	var is_heal = false
	var is_interact = false

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB: is_tab = true
		elif event.keycode == KEY_ESCAPE: is_esc = true
		elif event.keycode == KEY_R: is_heal = true
		elif event.keycode == KEY_E or event.is_action_pressed("ui_accept"): is_interact = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_BACK or event.button_index == JOY_BUTTON_LEFT_SHOULDER: is_tab = true
		elif event.button_index == JOY_BUTTON_START: is_esc = true
		elif event.button_index == JOY_BUTTON_Y: is_heal = true
		elif event.button_index == JOY_BUTTON_A: is_interact = true

	if is_tab and not battle_engine.is_in_battle and not is_esc_open:
		dismiss_tutorial_banner()
		if audio_manager: audio_manager.play_sfx("sfx_menu_move")
		party_menu.toggle_menu(party_system)
		get_viewport().set_input_as_handled()
	elif is_esc and not battle_engine.is_in_battle and not party_menu.is_open:
		toggle_esc_menu()
		get_viewport().set_input_as_handled()
	elif is_heal and not battle_engine.is_in_battle and not party_menu.is_open and not is_esc_open:
		execute_field_heal_rest()
		get_viewport().set_input_as_handled()
	elif is_interact and not battle_engine.is_in_battle and not party_menu.is_open and not is_esc_open:
		var nearby = get_nearby_poi()
		if nearby:
			handle_interaction(nearby)
			get_viewport().set_input_as_handled()

func _process(delta):
	if not is_exploration_active():
		silence_map_audio()
		return

	if not party_menu.is_open and not is_esc_open:
		minimap.update_player_position(player.global_position)
		check_interactions()
		check_hidden_treasure_stepped()
		check_floor_cracks()
		update_vortices(delta)

	update_arcade_proximity_sound()
	update_detector_radar_beep(delta)
	update_hud_cycling(delta)
	update_orbs_animation(delta)

func check_floor_cracks():
	for p in pois:
		if p.type == "floor_crack":
			var crack_center = Vector3(p.x, 0, p.z)
			var offset = player.global_position - crack_center
			var open_dir = p.open_dir

			var crossed = false
			if open_dir == Vector2i(0, -1) and offset.z >= 0.0: crossed = true
			elif open_dir == Vector2i(0, 1) and offset.z <= 0.0: crossed = true
			elif open_dir == Vector2i(-1, 0) and offset.x >= 0.0: crossed = true
			elif open_dir == Vector2i(1, 0) and offset.x <= 0.0: crossed = true

			if crossed and player.global_position.distance_to(crack_center) <= 2.2:
				is_fade_movement_locked = true
				var jump = randi_range(1, 3)
				var next_f = current_floor + jump
				fade_to_black(0.35, func():
					load_floor(next_f, true, jump)
					fade_to_transparent(0.6, func():
						is_fade_movement_locked = false
					)
				)
				return

func update_vortices(delta: float):
	var vortex_speed = 4.2
	for p in pois:
		if p.type == "vortex" and is_instance_valid(p.node):
			var wp = p.waypoints[p.wp_idx]
			p.node.position = p.node.position.move_toward(wp, vortex_speed * delta)
			p.x = p.node.position.x
			p.z = p.node.position.z

			if p.torus and is_instance_valid(p.torus):
				p.torus.rotation.y += delta * 4.5
				p.torus.rotation.x += delta * 2.5

			if p.node.position.distance_to(wp) < 0.15:
				p.wp_idx = (p.wp_idx + 1) % p.waypoints.size()

			if player.global_position.distance_to(p.node.position) <= 1.2:
				trigger_vortex_teleport()
				return

func trigger_vortex_teleport():
	is_fade_movement_locked = true
	if audio_manager: audio_manager.play_sfx("sfx_portal")

	var flash = ColorRect.new()
	flash.color = Color(0.75, 0.1, 1.0, 0.7)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_canvas.add_child(flash)
	var t = create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.5)
	t.finished.connect(flash.queue_free)

	if valid_floor_cells.size() > 0:
		var target_cell = valid_floor_cells[randi() % valid_floor_cells.size()]
		var target_wx = (target_cell.x - 17 / 2.0) * 4.0
		var target_wz = (target_cell.y - 17 / 2.0) * 4.0
		player.global_position = Vector3(target_wx, 0, target_wz)

	var t_unfreeze = get_tree().create_timer(0.4)
	t_unfreeze.timeout.connect(func():
		is_fade_movement_locked = false
		if dialogue_manager:
			dialogue_manager.trigger_dialogue("vortice_teleporte")
	)

func update_detector_radar_beep(delta: float):
	if not has_detector: return

	var nearest_hidden_dist = 999999.0
	var is_csouter_signal = false

	for p in pois:
		if not p.get("collected", false):
			if p.type == "hidden_treasure":
				var d = player.global_position.distance_to(Vector3(p.x, 0, p.z))
				if d < nearest_hidden_dist:
					nearest_hidden_dist = d
					is_csouter_signal = false
			elif p.type == "prop_csouter_ground" and not has_csouter:
				var d = player.global_position.distance_to(Vector3(p.x, 0, p.z))
				if d < nearest_hidden_dist:
					nearest_hidden_dist = d
					is_csouter_signal = true

	if nearest_hidden_dist <= 12.0:
		detector_beep_timer += delta
		var factor = clamp(nearest_hidden_dist / 12.0, 0.0, 1.0)
		var beep_interval = lerp(0.12, 0.95, factor) if is_csouter_signal else lerp(0.16, 1.15, factor)
		if is_csouter_signal: beep_interval *= randf_range(0.85, 1.15)

		if detector_beep_timer >= beep_interval:
			detector_beep_timer = 0.0
			var vol = lerp(0.5, -3.5, factor)
			var sfx_to_use = "sfx_radar_ping" if (ResourceLoader.exists("res://audio/sfx_radar_ping.wav") or FileAccess.file_exists("res://audio/sfx_radar_ping.wav")) else "sfx_menu_move"

			if is_csouter_signal:
				var distorted_pitch = randf_range(1.65, 2.1) if (randf() > 0.4) else randf_range(0.45, 0.65)
				audio_manager.play_sfx(sfx_to_use, 0.25, vol + 1.5, distorted_pitch)
			else:
				audio_manager.play_sfx(sfx_to_use, 0.02, vol, 1.0)
	else:
		detector_beep_timer = 0.0

func check_hidden_treasure_stepped():
	if has_detector: return
	for p in pois:
		if p.type == "hidden_treasure" and not p.get("collected", false):
			var d = player.global_position.distance_to(Vector3(p.x, 0, p.z))
			if d <= 1.2:
				p.collected = true
				total_treasures_collected += 1
				if audio_manager:
					audio_manager.play_sfx("sfx_hit", 0.1)
					audio_manager.play_sfx("sfx_chest_open")

				var chars = ["humano", "alien", "robo"]
				if not party_system.is_kira_away: chars.append("mutante")
				var speaker = chars[randi() % chars.size()]
				dialogue_manager.trigger_dialogue("tropeco_tesouro", speaker)
				update_hud()
				return

func update_hud_cycling(delta: float):
	if current_floor_mission.is_empty() or not current_floor_mission.get("is_active", false):
		hud_cycle_mode = 0
		return

	hud_cycle_timer += delta
	if hud_cycle_timer >= 4.0:
		hud_cycle_timer = 0.0
		hud_cycle_mode = 1 if hud_cycle_mode == 0 else 0
		var tween = create_tween()
		tween.tween_property(hud_top_label, "modulate:a", 0.0, 0.15)
		tween.tween_callback(update_hud)
		tween.tween_property(hud_top_label, "modulate:a", 1.0, 0.15)

func update_orbs_animation(_delta: float):
	var now = Time.get_ticks_msec() * 0.001
	for orb_data in active_orbs:
		if is_instance_valid(orb_data.node):
			orb_data.node.position.y = orb_data.base_y + sin(now * 2.8 + orb_data.phase) * 0.20

func spawn_data_orb(char_id: String, world_pos: Vector3):
	for i in range(active_orbs.size() - 1, -1, -1):
		var existing_orb = active_orbs[i]
		if existing_orb.get("char_id") == char_id:
			if is_instance_valid(existing_orb.get("node")): existing_orb.node.queue_free()
			pois.erase(existing_orb)
			active_orbs.remove_at(i)

	var orb_node = Node3D.new()
	orb_node.position = world_pos

	var sphere = CSGSphere3D.new()
	sphere.radius = 0.35
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.use_collision = false

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.9, 1.0)
	mat.emission_energy_multiplier = 2.0
	sphere.material_override = mat
	orb_node.add_child(sphere)

	var light = OmniLight3D.new()
	light.light_color = Color(0.8, 0.9, 1.0, 1.0)
	light.light_energy = 1.4
	light.omni_range = 3.5
	orb_node.add_child(light)

	if dungeon_generator.floor_parent: dungeon_generator.floor_parent.add_child(orb_node)

	var poi_entry = {
		"type": "data_orb",
		"char_id": char_id,
		"x": world_pos.x,
		"z": world_pos.z,
		"base_y": 0.8,
		"phase": randf() * TAU,
		"node": orb_node
	}
	pois.append(poi_entry)
	active_orbs.append(poi_entry)

func clear_all_orbs():
	for orb in active_orbs:
		if is_instance_valid(orb.node): orb.node.queue_free()
	active_orbs.clear()

func update_arcade_proximity_sound():
	if not arcade_proximity_player: return

	var candidate_pois: Array[Dictionary] = []
	for p in pois:
		if p.type == "arcade_spooter" and not p.completed:
			var p_copy = p.duplicate()
			p_copy["stream_path"] = "res://audio/bgm_space_spooter.mp3"
			candidate_pois.append(p_copy)
		elif p.type == "data_terminal" and not p.completed:
			var p_copy = p.duplicate()
			p_copy["stream_path"] = "res://audio/bgm_terminal.mp3"
			candidate_pois.append(p_copy)
		elif p.type == "heal":
			var p_copy = p.duplicate()
			p_copy["stream_path"] = "res://audio/sfx_pod_idle.wav"
			candidate_pois.append(p_copy)
		elif p.type == "portal":
			var p_copy = p.duplicate()
			p_copy["stream_path"] = "res://audio/sfx_portal_idle.mp3"
			candidate_pois.append(p_copy)
		elif p.type == "vortex":
			var p_copy = p.duplicate()
			p_copy["stream_path"] = "res://audio/bgm_vortex.mp3"
			candidate_pois.append(p_copy)

	if candidate_pois.is_empty():
		silence_map_audio()
		return

	var closest_poi = null
	var min_dist = 999999.0
	for p in candidate_pois:
		var d = player.global_position.distance_to(Vector3(p.x, 0, p.z))
		if d < min_dist:
			min_dist = d
			closest_poi = p

	var max_dist = 11.0
	var min_dist_threshold = 2.2

	if closest_poi == null or min_dist > max_dist:
		silence_map_audio()
	else:
		var stream_path: String = closest_poi.stream_path
		if not arcade_proximity_player.playing or current_proximity_stream_path != stream_path:
			var found_stream = null
			var extensions = [".mp3", ".ogg", ".wav"]
			var base_no_ext = stream_path.get_basename()
			for ext in extensions:
				var test_p = base_no_ext + ext
				if ResourceLoader.exists(test_p) or FileAccess.file_exists(test_p):
					found_stream = test_p
					break

			if found_stream:
				current_proximity_stream_path = found_stream
				arcade_proximity_player.stream = load(found_stream)
				arcade_proximity_player.play()
			elif stream_path.contains("vortex") and (ResourceLoader.exists("res://audio/sfx_portal.wav") or ResourceLoader.exists("res://audio/sfx_portal_idle.mp3")):
				current_proximity_stream_path = "res://audio/sfx_portal.wav"
				arcade_proximity_player.stream = load("res://audio/sfx_portal.wav")
				arcade_proximity_player.play()
			elif stream_path == "res://audio/bgm_terminal.mp3" and ResourceLoader.exists("res://audio/bgm_space_spooter.mp3"):
				current_proximity_stream_path = "res://audio/bgm_space_spooter.mp3"
				arcade_proximity_player.stream = load("res://audio/bgm_space_spooter.mp3")
				arcade_proximity_player.play()
			elif stream_path == "res://audio/sfx_pod_idle.wav" and ResourceLoader.exists("res://audio/sfx_heal.wav"):
				current_proximity_stream_path = "res://audio/sfx_heal.wav"
				arcade_proximity_player.stream = load("res://audio/sfx_heal.wav")
				arcade_proximity_player.play()
			elif (stream_path == "res://audio/sfx_portal_idle.mp3" or stream_path == "res://audio/sfx_portal_idle.wav") and ResourceLoader.exists("res://audio/sfx_portal.wav"):
				current_proximity_stream_path = "res://audio/sfx_portal.wav"
				arcade_proximity_player.stream = load("res://audio/sfx_portal.wav")
				arcade_proximity_player.play()

		var track_key = current_proximity_stream_path.get_file().get_basename()
		var base_target_vol = -6.0
		if audio_manager:
			if audio_manager.BGM_CUSTOM_VOLUMES.has(track_key):
				base_target_vol = audio_manager.BGM_CUSTOM_VOLUMES[track_key]
			elif audio_manager.SFX_ATTENUATION.has(track_key):
				base_target_vol = audio_manager.SFX_ATTENUATION[track_key]

		var t = clamp((min_dist - min_dist_threshold) / (max_dist - min_dist_threshold), 0.0, 1.0)
		arcade_proximity_player.volume_db = lerp(base_target_vol, base_target_vol - 38.0, t)

func is_front_space_clear(min_clear_distance: float = 4.2) -> bool:
	if not player or not is_inside_tree(): return false

	var forward_dir = -player.global_transform.basis.z.normalized()
	var test_motion = forward_dir * min_clear_distance
	var test_col = KinematicCollision3D.new()
	var body_collided = player.test_move(player.global_transform, test_motion, test_col)
	if body_collided: return false

	var space_state = get_world_3d().direct_space_state
	var ray_origin = player.global_position + Vector3(0, 1.2, 0)
	var ray_target = ray_origin + (forward_dir * min_clear_distance)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.exclude = [player.get_rid()]

	var ray_col = space_state.intersect_ray(query)
	return ray_col.is_empty()

func trigger_kira_departure():
	if party_system.is_kira_away or has_chronodox: return
	party_system.is_kira_away = true
	zigzag_suppressed_count = 0
	zigzag_turn_switches = 0

	if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")

	if dialogue_port_frame:
		dialogue_port_frame.show()
		if diag_tex_normal.has("mutante"):
			portrait_rect.texture = diag_tex_normal["mutante"]

	dialogue_label.position = Vector2(145, 15)
	dialogue_label.size = Vector2(dialogue_panel.size.x - 165, 110)
	dialogue_label.text = "[b][color=#ff9933]Kira[/color][/b]\nHumano, você tá andando parecendo uma barata tonta na parede! Cansaço só de olhar... Cansei de esperar, vou na frente quebrar umas portas!"
	dialogue_panel.show()

	var t = get_tree().create_timer(4.0)
	t.timeout.connect(func():
		var warn_title = Localization.t("popup_kira_away_title", "⚠ ATENÇÃO:")
		var warn_desc = Localization.t("popup_kira_away_warn", "Kira ficou impaciente com a lentidão e DEIXOU O GRUPO!\n(Ela avançou sozinha e não participará das batalhas até ser encontrada).")
		show_system_message("[color=#ff4444]" + warn_title + "[/color]", warn_desc, null, Callable(), "sfx_menu_cancel")
	)

func _physics_process(delta):
	if not is_exploration_active():
		return

	var press_forward = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) < -0.3 or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
	var press_backward = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) > 0.3 or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)
	var is_marching_in_place = press_forward and press_backward

	var move_dir = 0
	var rot_dir = 0
	var move_speed = 4.2
	var rot_speed = 2.4

	if press_forward: move_dir -= 1
	if press_backward: move_dir += 1

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.get_joy_axis(0, JOY_AXIS_LEFT_X) < -0.3 or Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) < -0.3 or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): 
		rot_dir += 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.get_joy_axis(0, JOY_AXIS_LEFT_X) > 0.3 or Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) > 0.3 or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): 
		rot_dir -= 1

	player.rotation.y += rot_dir * rot_speed * delta

	if rot_dir != 0 and not is_marching_in_place and not has_chronodox and not party_system.is_kira_away:
		if last_turn_direction != 0 and rot_dir != last_turn_direction:
			zigzag_turn_switches += 1
		last_turn_direction = rot_dir

	var forward = -player.global_transform.basis.z
	var target_motion = forward * (-move_dir) * move_speed * delta

	if move_dir != 0:
		var test_col = KinematicCollision3D.new()
		var will_collide = player.test_move(player.global_transform, target_motion, test_col)
		if will_collide:
			player.velocity = Vector3.ZERO
		else:
			player.velocity = forward * (-move_dir) * move_speed
	else:
		player.velocity = Vector3.ZERO

	var pos_before = player.global_position
	player.move_and_slide()
	var actual_dist = pos_before.distance_to(player.global_position)

	var effective_dist = actual_dist
	if is_marching_in_place:
		effective_dist = (move_speed * delta) * 2.0

	if effective_dist > 0.001:
		footstep_timer += delta
		if footstep_timer >= 0.5:
			footstep_timer = 0.0
			var should_play_step = true
			if is_marching_in_place and not enable_marching_footsteps:
				should_play_step = false
			if should_play_step and audio_manager:
				audio_manager.play_sfx("sfx_step", 0.1)

		step_counter += effective_dist
		if step_counter > 15.0:
			if randf() < 0.3:
				if is_front_space_clear(4.2):
					step_counter = 0.0
					zigzag_turn_switches = 0
					zigzag_suppressed_count = 0
					is_transitioning_combat = true
					player.velocity = Vector3.ZERO
					start_combat()
					return
				else:
					step_counter = 12.0
					if not is_marching_in_place and not has_chronodox and not party_system.is_kira_away:
						if zigzag_turn_switches >= 3:
							zigzag_suppressed_count += 1
							zigzag_turn_switches = 0
							if zigzag_suppressed_count >= 2:
								trigger_kira_departure()
			else:
				step_counter = 0.0
				if not is_marching_in_place: zigzag_turn_switches = 0
	else:
		footstep_timer = 0.0

func get_nearby_poi():
	for p in pois:
		if p.type == "hidden_treasure" and not has_detector:
			continue
		if player.global_position.distance_to(Vector3(p.x, 0, p.z)) < 2.5:
			return p
	return null

func check_interactions():
	var nearby = get_nearby_poi()
	if nearby:
		var text_to_show = ""
		if nearby.type == "chest":
			text_to_show = Localization.t("interaction_chest_opened", "Baú Vazio") if nearby.opened else Localization.t("interaction_chest_closed", "[E / A] Abrir Baú")
		elif nearby.type == "heal":
			text_to_show = Localization.t("interaction_heal", "[E / A] Usar Pod Médico (Restaurar Party)")
		elif nearby.type == "portal":
			text_to_show = Localization.t("interaction_portal", "[E / A] Entrar no Portal (Requer Chave)")
		elif nearby.type == "arcade_spooter":
			text_to_show = Localization.t("interaction_spooter_off", "Terminal Desativado (Parou de funcionar)") if nearby.completed else Localization.t("interaction_spooter", "[E / A] Jogar Space Spooter")
		elif nearby.type == "data_terminal":
			text_to_show = Localization.t("interaction_terminal_off", "Terminal Desativado (Gravação Concluída)") if nearby.completed else Localization.t("interaction_terminal", "[E / A] Acessar Terminal de Dados")
		elif nearby.type == "data_orb":
			var char_name = get_display_name(nearby.char_id)
			text_to_show = Localization.t("interaction_orb", "[E / A] Coletar Excesso de Dados (%s)") % char_name
		elif nearby.type == "hidden_treasure" and has_detector:
			text_to_show = Localization.t("interaction_hidden_done", "Cápsula Já Coletada") if nearby.get("collected", false) else Localization.t("interaction_hidden", "[E / A] Tesouro Detectado")
		elif nearby.type == "prop_csouter_ground":
			text_to_show = Localization.t("interaction_csouter_done", "Item Coletado") if nearby.get("collected", false) else Localization.t("interaction_csouter", "[E / A] Coletar C-Souter (Radar de Telemetria)")
		elif nearby.type == "hole_keeper":
			text_to_show = Localization.t("interaction_hole_keeper_done", "Fenda Quântica Vazia") if nearby.get("used", false) else Localization.t("interaction_hole_keeper", "[E / A] Falar com Hole Keeper")

		if text_to_show != "":
			interaction_label.text = text_to_show
			interaction_label.show()
		else:
			interaction_label.hide()
	else:
		interaction_label.hide()

func handle_interaction(poi):
	if poi.type == "hole_keeper":
		if poi.get("used", false) or is_in_cutscene or (hole_keeper_ui and hole_keeper_ui.is_open): return

		var letter = poi.get("npc_letter", "A")
		var lang = Localization.current_language
		var hk_text = ""
		if lang == "en":
			hk_text = "« The previous branch lost the sphere again?! Incompetents! Hand over the Chronodox so I can recalibrate your suit's core. »"
		elif lang == "ja":
			hk_text = "« 前の支店がまた球体を紛失しただと？！ 無能め！ クロノドックスを渡せば、スーツのコアを再調整してやる。 »"
		else:
			hk_text = "« A filial anterior perdeu a esfera de novo?! Incompetentes! Entregue-me o Chronodox para que eu possa recalibrar o núcleo do seu traje. »"

		var empty_bg_name = "cutscene_sem_bg" if load_texture_safe("cutscene_sem_bg") else "cutscene_sem_bg"
		var hk_dialogue = [
			{
				"character_id": "khen_dark",
				"speaker": "Hole Keeper " + letter,
				"text": hk_text,
				"image": empty_bg_name
			}
		]

		start_story_cutscene(hk_dialogue, func():
			open_hole_keeper_screen(poi)
		)

	elif poi.type == "chest" and not poi.opened:
		poi.opened = true
		if poi.node and poi.node is Sprite3D:
			var open_tex = load_texture_safe("prop_chest_open")
			if not open_tex: open_tex = load_texture_safe("prop_chest_open")
			if open_tex:
				poi.node.texture = open_tex
				var target_height = 1.1
				poi.node.pixel_size = target_height / float(open_tex.get_height())
				poi.node.position.y = target_height / 2.0

		if poi.has_floor_key:
			if audio_manager: audio_manager.play_sfx("sfx_chest_open")
			floor_key_found = true
			dialogue_manager.trigger_dialogue("chave_encontrada")
			deactivate_portal_shield()

			var alarm_timer = get_tree().create_timer(4.5)
			alarm_timer.timeout.connect(func():
				if is_game_started and not battle_engine.is_in_battle and not is_in_cutscene and not credits_screen.visible and not active_spooter_minigame:
					if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
					dialogue_manager.trigger_dialogue("alarme_seguranca")
			)
		else:
			total_treasures_collected += 1
			var drop_chance: float = 1.0 if etapa_dois else (0.05 if current_floor >= 2 else 0.0)
			if not has_chronodox and randf() <= drop_chance:
				trigger_chronodox_discovery()
			else:
				if audio_manager: audio_manager.play_sfx("sfx_chest_open")
				dialogue_manager.trigger_dialogue("bau_encontrado")
		update_hud()

	elif poi.type == "hidden_treasure" and has_detector and not poi.get("collected", false):
		poi.collected = true
		total_treasures_collected += 1
		if audio_manager: audio_manager.play_sfx("sfx_chest_open")
		var chars = ["humano", "alien", "robo"]
		if not party_system.is_kira_away: chars.append("mutante")
		var speaker = chars[randi() % chars.size()]
		dialogue_manager.trigger_dialogue("bau_encontrado", speaker)
		update_hud()

	elif poi.type == "prop_csouter_ground" and not poi.get("collected", false):
		poi.collected = true
		has_csouter = true
		total_treasures_collected += 1
		if is_instance_valid(poi.node): poi.node.queue_free()
		if poi.has("light") and is_instance_valid(poi.light): poi.light.queue_free()

		if audio_manager:
			audio_manager.play_sfx("sfx_level_up")
			audio_manager.play_sfx("sfx_heal")

		var title = Localization.t("popup_csouter_title", "★ C-SOUTER ADQUIRIDO COM SUCESSO!")
		var desc = Localization.t("popup_csouter_desc", "Radar óptico equipado! (Em combate, exibe o visor com a leitura de PDL - Poder De Luta da horda inimiga).")

		show_system_message("[color=#00e5ff]" + title + "[/color]", desc, null, func():
			dialogue_manager.trigger_dialogue("csouter_encontrado")
		)
		update_hud()

	elif poi.type == "heal":
		party_system.heal_all_full()
		var flash = ColorRect.new()
		flash.color = Color(0.0, 0.85, 1.0, 0.5)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_canvas.add_child(flash)
		var t = create_tween()
		t.tween_property(flash, "color:a", 0.0, 0.5)
		t.finished.connect(flash.queue_free)

		if audio_manager: audio_manager.play_sfx("sfx_heal")
		dialogue_manager.trigger_dialogue("cura_disponivel")
		update_hud()

	elif poi.type == "arcade_spooter":
		if poi.completed or is_arcade_input_locked: return
		start_space_spooter_arcade(poi)

	elif poi.type == "data_terminal":
		if poi.completed or (terminal_ui and terminal_ui.is_open): return
		open_terminal_screen(poi)

	elif poi.type == "data_orb":
		handle_data_orb_interaction(poi)

	elif poi.type == "portal":
		if not floor_key_found:
			if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
			dialogue_manager.trigger_dialogue("porta_trancada")
			return
		load_floor(current_floor + 1)

func deactivate_portal_shield():
	for p in pois:
		if p.type == "portal" and p.has("shield") and is_instance_valid(p.shield):
			var s_mesh = p.shield
			var s_mat = p.get("shield_mat", null)
			var tw = create_tween().set_parallel(true)
			tw.tween_property(s_mesh, "scale", Vector3(1.35, 1.35, 1.35), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			if s_mat:
				tw.tween_property(s_mat, "albedo_color:a", 0.0, 0.45)
			tw.finished.connect(func():
				if is_instance_valid(s_mesh):
					s_mesh.queue_free()
			)

func open_hole_keeper_screen(poi: Dictionary):
	dismiss_tutorial_banner()
	hud_panel.hide()
	minimap.hide()
	interaction_label.hide()
	if dialogue_manager: dialogue_manager.pause_dialogues()

	hole_keeper_ui.open_ui(poi, party_system, self)

func handle_data_orb_interaction(poi: Dictionary):
	var char_id = poi.char_id
	if not party_system.members.has(char_id): return
	var member = party_system.members[char_id]
	var lang = Localization.current_language

	if member.hp <= 0:
		if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
		var sys_title = "[color=#ff3344][SYSTEM]: Unconscious member.[/color]" if lang == "en" else ("[color=#ff3344][システム]: 仲間が意識不明です。[/color]" if lang == "ja" else "[color=#ff3344][SISTEMA]: Integrante inconsciente.[/color]")
		var sys_desc = "Assimilation requires active vital signs. Revive member in the Med Pod first." if lang == "en" else ("同期には生命反応が必要です。先に医療ポッドで蘇生させてください。" if lang == "ja" else "A assimilação requer sinais vitais ativos. Reanime o integrante no Pod de Cura primeiro.")
		show_system_message(sys_title, sys_desc, null, Callable(), "")
		return

	party_system.sync_member_to_rigard(char_id)
	if is_instance_valid(poi.node): poi.node.queue_free()
	pois.erase(poi)
	active_orbs.erase(poi)

	if audio_manager:
		audio_manager.play_sfx("sfx_level_up")
		audio_manager.play_sfx("sfx_heal")

	var flash = ColorRect.new()
	flash.color = Color(0.8, 0.1, 1.0, 0.5)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_canvas.add_child(flash)
	var t_f = create_tween()
	t_f.tween_property(flash, "color:a", 0.0, 0.6)
	t_f.finished.connect(flash.queue_free)

	dialogue_manager.trigger_dialogue("orb_recuperada", char_id)
	update_hud()

func open_terminal_screen(poi: Dictionary):
	dismiss_tutorial_banner()

	var mission = poi.get("mission", current_floor_mission)
	if mission.is_empty(): return

	hud_panel.hide()
	minimap.hide()
	interaction_label.hide()
	if dialogue_manager: dialogue_manager.pause_dialogues()

	terminal_ui.open_terminal(poi, mission, party_system)

func assign_drive_to_member_and_close(char_id: String, poi: Dictionary):
	party_system.equip_data_drive(char_id)
	poi.completed = true

	for i in range(active_orbs.size() - 1, -1, -1):
		var orb = active_orbs[i]
		if orb.get("char_id") == char_id:
			if is_instance_valid(orb.get("node")):
				orb.node.queue_free()
			pois.erase(orb)
			active_orbs.remove_at(i)

	current_floor_mission.clear()
	hud_cycle_mode = 0
	hud_cycle_timer = 0.0
	hud_top_label.modulate.a = 1.0

	if poi.has("node") and is_instance_valid(poi.node):
		var off_tex = load_texture_safe("prop_terminal_off")
		if not off_tex: off_tex = load_texture_safe("prop_terminal_off")
		if not off_tex: off_tex = load_texture_safe("prop_spooter_off")
		if not off_tex: off_tex = load_texture_safe("prop_spooter_off")
		if off_tex: poi.node.texture = off_tex
	if poi.has("light") and is_instance_valid(poi.light): poi.light.visible = false
	if poi.has("shadow") and is_instance_valid(poi.shadow): poi.shadow.visible = true

	if audio_manager:
		audio_manager.play_sfx("sfx_level_up")
		audio_manager.play_sfx("sfx_heal")

	var char_name = get_display_name(char_id)
	var title = Localization.t("popup_datadrive_title", "★ DATA DRIVE CALIBRADO COM SUCESSO!")
	var desc = Localization.t("popup_datadrive_desc", "Data Drive alocado para %s!\n(Nível e EXP igualados ao Capitão; imunidade a perdas futuras de EXP).") % char_name

	show_system_message("[color=#00ff66]" + title + "[/color]", desc, null, func():
		dialogue_manager.trigger_dialogue("orb_recuperada", char_id)
	)
	update_hud()

func start_space_spooter_arcade(poi: Dictionary):
	dismiss_tutorial_banner()

	current_active_arcade_poi = poi
	silence_map_audio()
	audio_manager.stop_bgm()
	if audio_manager: audio_manager.play_sfx("sfx_menu_select")

	ui_canvas.hide()
	if dialogue_manager: dialogue_manager.pause_dialogues()

	await RenderingServer.frame_post_draw

	var snapshot = capture_clean_snapshot()
	ui_canvas.show()
	hud_panel.hide()
	minimap.hide()
	interaction_label.hide()

	active_spooter_minigame = space_spooter_script.new()
	ui_canvas.add_child(active_spooter_minigame)
	active_spooter_minigame.minigame_completed.connect(_on_space_spooter_ended)
	active_spooter_minigame.start_game(snapshot, audio_manager)

func _on_space_spooter_ended(victory: bool):
	if active_spooter_minigame:
		active_spooter_minigame.queue_free()
		active_spooter_minigame = null

	hud_panel.show()
	minimap.show()

	if dialogue_manager:
		dialogue_manager.resume_dialogues()

	if victory:
		current_active_arcade_poi.completed = true
		if current_active_arcade_poi.has("node") and is_instance_valid(current_active_arcade_poi.node):
			var off_tex = load_texture_safe("prop_spooter_off")
			if not off_tex: off_tex = load_texture_safe("prop_spooter_off")
			if off_tex: current_active_arcade_poi.node.texture = off_tex
		if current_active_arcade_poi.has("light") and is_instance_valid(current_active_arcade_poi.light):
			current_active_arcade_poi.light.visible = false
		if current_active_arcade_poi.has("shadow") and is_instance_valid(current_active_arcade_poi.shadow):
			current_active_arcade_poi.shadow.visible = true

		party_system.unlock_perfect_defense()

		var flash = ColorRect.new()
		flash.color = Color(0.0, 1.0, 0.35, 0.6)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_canvas.add_child(flash)
		var t = create_tween()
		t.tween_property(flash, "color:a", 0.0, 0.65)
		t.finished.connect(flash.queue_free)

		if audio_manager:
			audio_manager.play_sfx("sfx_level_up")
			audio_manager.play_sfx("sfx_heal")

		var title = Localization.t("popup_spooter_buff_title", "★ SPACE SPOOTER BUFF ATIVADO!")
		var desc = Localization.t("popup_spooter_buff_desc", "Defesa Impenetrável adquirida! (Com a equipe completa de 4 membros, Defender anula 100% do dano recebido).")

		show_system_message("[color=#00ff66]" + title + "[/color]", desc, null, func():
			var chars = ["humano", "alien", "robo"]
			if not party_system.is_kira_away: chars.append("mutante")
			var speaker = chars[randi() % chars.size()]
			dialogue_manager.trigger_dialogue("arcade_spooter_recompensa", speaker)
		)
	else:
		var chars = ["humano", "alien", "robo"]
		if not party_system.is_kira_away: chars.append("mutante")
		var speaker = chars[randi() % chars.size()]
		dialogue_manager.trigger_dialogue("arcade_spooter_derrota", speaker)

	is_arcade_input_locked = false
	audio_manager.play_bgm("bgm_dungeon", true, 1.0)

func trigger_chronodox_discovery():
	dismiss_tutorial_banner()

	has_chronodox = true
	if party_system: party_system.has_chronodox = true
	if battle_engine: battle_engine.has_chronodox = true

	is_in_cutscene = true
	if player: player.velocity = Vector3.ZERO
	audio_manager.stop_bgm()
	silence_map_audio()

	if hud_panel: hud_panel.hide()
	if minimap: minimap.hide()
	if interaction_label: interaction_label.hide()
	if dialogue_panel: dialogue_panel.hide()
	if dialogue_manager: dialogue_manager.pause_dialogues()

	fade_to_black(0.4, func():
		audio_manager.play_bgm("bgm_chronodox", false, 1.0, true)
		var black_screen_timer = get_tree().create_timer(1.0)
		black_screen_timer.timeout.connect(func(): play_cutscene_0_chronodox())
	)
	is_arcade_input_locked = true
	var unlock_timer = get_tree().create_timer(0.8)
	unlock_timer.timeout.connect(func(): is_arcade_input_locked = false)

func play_cutscene_0_chronodox():
	var was_away = party_system.is_kira_away
	party_system.is_kira_away = false
	var lang = Localization.current_language

	var scene_name = "cutscene_chronodox" if load_texture_safe("cutscene_chronodox") else "cutscene_chronodox"

	var cutscene_dialogues = []
	if was_away:
		var away_text = "Took you long enough! I even took a nap ahead... but look what I found!" if lang == "en" else ("遅かったじゃない！先に行って一眠りしちゃったわ... でも見て、すごいの見つけたのよ！" if lang == "ja" else "Demoraram, hein? Até tirei um cochilo aqui na frente... Mas olhem só o que eu achei!")
		cutscene_dialogues.append({
			"character_id": "mutante",
			"image": scene_name,
			"delay_before": 1.2,
			"speaker": "Kira",
			"text": away_text
		})

	if lang == "en":
		cutscene_dialogues.append_array([
			{"character_id": "humano", "image": scene_name, "delay_before": 1.4, "sfx": "sfx_treasure_open", "speaker": "Rigard", "text": "It matches the archives, no doubt: it's the Chronodox!"},
			{"character_id": "mutante", "speaker": "Kira", "text": "That's the Chronodox? I didn't expect a clock. Can't even tell the time... Look, it's spherical."},
			{"character_id": "alien", "speaker": "Vaelthor", "text": "It doesn't seem of mystical origin. What power source moves that axis and hands?"},
			{"character_id": "robo", "speaker": "Unit-7", "text": "I do not feel well near this artifact..."}
		])
	elif lang == "ja":
		cutscene_dialogues.append_array([
			{"character_id": "humano", "image": scene_name, "delay_before": 1.4, "sfx": "sfx_treasure_open", "speaker": "Rigard", "text": "記録の記述と一致する、間違いない... クロノドックスだ！"},
			{"character_id": "mutante", "speaker": "Kira", "text": "これがクロノドックス？時計なんて思わなかったわ。時間も読めないじゃない... 見て、球形よ。"},
			{"character_id": "alien", "speaker": "Vaelthor", "text": "神秘的な起源の代物ではなさそうだ。一体どのようなエネルギー源がこの軸と針を動かしているのだ？"},
			{"character_id": "robo", "speaker": "Unit-7", "text": "このアーティファクトの近くにいると、システムの調子がおかしくなります..."}
		])
	else:
		cutscene_dialogues.append_array([
			{"character_id": "humano", "image": scene_name, "delay_before": 1.4, "sfx": "sfx_treasure_open", "speaker": "Rigard", "text": "Ele bate com as descrições, não há dúvidas: é o Chronodox!"},
			{"character_id": "mutante", "speaker": "Kira", "text": "Esse é o Chronodox? Eu não esperava que fosse um relógio. Nem dá pra ver as horas nele... Veja, ele é esférico."},
			{"character_id": "alien", "speaker": "Vaelthor", "text": "Ele não parece ter origem mística. Que tipo de fonte de energia move esse eixo e os ponteiros?"},
			{"character_id": "robo", "speaker": "Unit-7", "text": "Não me sinto bem perto dessa coisa..."}
		])

	start_story_cutscene(cutscene_dialogues, func():
		audio_manager.stop_bgm(0.6)
		audio_manager.play_bgm("bgm_dungeon", true, 1.0)
		hud_panel.show()
		minimap.show()

		var flash = ColorRect.new()
		flash.color = Color(1.0, 0.85, 0.2, 0.65)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_canvas.add_child(flash)
		var t = create_tween()
		t.tween_property(flash, "color:a", 0.0, 0.65)
		t.finished.connect(flash.queue_free)

		if audio_manager: audio_manager.play_sfx("sfx_level_up")

		var title = Localization.t("popup_chronodox_title", "★ TESOURO ARTEFATO REVELADO!")
		var desc_text = Localization.t("popup_chronodox_kira_desc", "A equipe adquiriu o Chronodox e KIRA REUNIU-SE AO GRUPO!") if was_away else Localization.t("popup_chronodox_desc", "A equipe adquiriu um tesouro de valor inestimável: Chronodox!")

		show_system_message("[color=#ffd700]" + title + "[/color]", desc_text, null, func():
			if dialogue_manager:
				dialogue_manager.start_chronodox_sequence()
		)
	)

func play_cutscene_final_sequence():
	var lang = Localization.current_language
	var cutscene_dialogues = []

	var sc1 = "cutscene_final_1" if load_texture_safe("cutscene_final_1") else "cutscene_final_1"
	var sc2 = "cutscene_final_2" if load_texture_safe("cutscene_final_2") else "cutscene_final_2"
	var sc3 = "cutscene_final_3" if load_texture_safe("cutscene_final_3") else "cutscene_final_3"

	if lang == "en":
		cutscene_dialogues = [
			{"character_id": "alien", "image": sc1, "delay_before": 1.4, "speaker": "Vaelthor", "text": "Captain Rigard?! The Chronodox... it dissolved."},
			{"character_id": "humano", "speaker": "Rigard", "text": "Not just that. The last thing I remember was the blade piercing my chest."},
			{"character_id": "mutante", "speaker": "Kira", "text": "Whatever that thing did, our retirement plans just went out the airlock."},
			{"character_id": "robo", "image": sc2, "delay_before": 1.2, "sfx": "sfx_menu_cancel", "speaker": "Unit-7", "text": "Critical error. Temporal reading exceeds logic capacity... Logic Overflow!"},
			{"character_id": "humano", "speaker": "Rigard", "text": "Unit-7, what is happening?!"},
			{"character_id": "robo", "flash_heal": true, "speaker": "Unit-7", "text": "Data sync corrupted. Preventing core breach... Initiating Self-Sacrifice Protocol. Regenerate allies and shut down."},
			{"character_id": "mutante", "image": "", "bgm": "bgm_final_boss", "blackout_flicker": true, "delay_before": 0.8, "speaker": "Kira", "text": "The station power just died all at once!"},
			{"character_id": "khen_dark", "speaker": "", "text": "The Chronodox did not save you. It only aligned my timeline with yours."},
			{"character_id": "alien", "image": sc3, "fade_in_reveal": true, "delay_before": 1.5, "speaker": "Vaelthor", "text": "This presence... It is him. The demon of legend."},
			{"character_id": "khen", "speaker": "Khen-Shalom", "text": "You broke the seal. Now witness the wrath of the Khen Empire!"}
		]
	elif lang == "ja":
		cutscene_dialogues = [
			{"character_id": "alien", "image": sc1, "delay_before": 1.4, "speaker": "Vaelthor", "text": "リガード隊長？！ クロノドックスが... 蒸発しました。"},
			{"character_id": "humano", "speaker": "Rigard", "text": "それだけじゃない。最後に覚えているのは、刃が胸を貫いた感触だ。"},
			{"character_id": "mutante", "speaker": "Kira", "text": "あいつが何をしたにせよ、私たちの引退計画は宇宙の塵になったわね。"},
			{"character_id": "robo", "image": sc2, "delay_before": 1.2, "sfx": "sfx_menu_cancel", "speaker": "Unit-7", "text": "致命的なエラー。時間軸の計測値が処理能力を超過... ロジックオーバーフロー！"},
			{"character_id": "humano", "speaker": "Rigard", "text": "Unit-7、一体何が起きているんだ？！"},
			{"character_id": "robo", "flash_heal": true, "speaker": "Unit-7", "text": "データ同期破損。コア崩壊を回避... 自己犠牲プロトコル起動。仲間を再生し、シャットダウンします。"},
			{"character_id": "mutante", "image": "", "bgm": "bgm_final_boss", "blackout_flicker": true, "delay_before": 0.8, "speaker": "Kira", "text": "ステーションの電力が一気に落ちたわ！"},
			{"character_id": "khen_dark", "speaker": "", "text": "クロノドックスは貴様らを救ったのではない。我が時間を貴様らの時間軸へと収束させたに過ぎぬ。"},
			{"character_id": "alien", "image": sc3, "fade_in_reveal": true, "delay_before": 1.5, "speaker": "Vaelthor", "text": "この気配... 奴だ。伝説の悪魔..."},
			{"character_id": "khen", "speaker": "Khen-Shalom", "text": "封印を破りし者どもよ。今こそケン帝国の怒りを拝むがよい！"}
		]
	else:
		cutscene_dialogues = [
			{"character_id": "alien", "image": sc1, "delay_before": 1.4, "speaker": "Vaelthor", "text": "Capitão Rigard?! O Chronodox... ele evaporou."},
			{"character_id": "humano", "speaker": "Rigard", "text": "Não só ele. A última coisa que me lembro foi a lâmina atravessando meu peito."},
			{"character_id": "mutante", "speaker": "Kira", "text": "Seja lá o que aquela coisa fez, nossa aposentadoria foi pro espaço."},
			{"character_id": "robo", "image": sc2, "delay_before": 1.2, "sfx": "sfx_menu_cancel", "speaker": "Unit-7", "text": "Erro crítico. Leitura temporal excede capacidade de processamento... Sobrecarga Lógica!"},
			{"character_id": "humano", "speaker": "Rigard", "text": "Unit-7, o que tá acontecendo?!"},
			{"character_id": "robo", "flash_heal": true, "speaker": "Unit-7", "text": "Sincronia de dados corrompida. Para evitar contaminação do sistema... Ativar Protocolo de Auto-Sacrifício. Regenerar aliados e desligar."},
			{"character_id": "mutante", "image": "", "bgm": "bgm_final_boss", "blackout_flicker": true, "delay_before": 0.8, "speaker": "Kira", "text": "A energia da estação caiu toda de uma vez!"},
			{"character_id": "khen_dark", "speaker": "", "text": "O Chronodox não salvou vocês. Ele apenas alinhou o meu tempo ao seu."},
			{"character_id": "alien", "image": sc3, "fade_in_reveal": true, "delay_before": 1.5, "speaker": "Vaelthor", "text": "Essa presença... É ele. O demônio da lenda."},
			{"character_id": "khen", "speaker": "Khen-Shalom", "text": "Vocês quebraram o lacre. Agora, contemplem a fúria do Império Khen!"}
		]

	start_story_cutscene(cutscene_dialogues, func():
		cutscene_layer.hide()
		cutscene_bg.texture = null
		cutscene_panel.hide()
		if hud_panel: hud_panel.hide()
		if minimap: minimap.hide()
		if interaction_label: interaction_label.hide()
		battle_engine.start_boss_battle(get_viewport(), ui_canvas, party_system, audio_manager, current_floor, etapa_dois, last_dungeon_snapshot, has_csouter)
	)

func play_cutscene_epilogue():
	silence_map_audio()
	audio_manager.stop_bgm()
	var lang = Localization.current_language

	var dying_text = "Impossible... how..." if lang == "en" else ("馬鹿な... なぜだ..." if lang == "ja" else "Não... pode... ser...")
	var dying_dialogue = [
		{"character_id": "khen", "image": "", "bgm": "", "sfx": "sfx_ambient_hum", "delay_before": 0.4, "speaker": "Khen-Shalom", "text": dying_text}
	]

	start_story_cutscene(dying_dialogue, func():
		cutscene_panel.hide()
		cutscene_bg.texture = null
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.color.a = 1.0
		is_cutscene_input_locked = true

		is_in_cutscene = true
		await get_tree().create_timer(3.0).timeout
		is_cutscene_input_locked = false

		var sc4 = "cutscene_final_4" if load_texture_safe("cutscene_final_4") else "cutscene_final_4"
		var trio_dialogues = []
		if lang == "en":
			trio_dialogues = [
				{"character_id": "mutante", "image": sc4, "delay_before": 1.2, "speaker": "Kira", "text": "(Panting) We did it... The monster is down."},
				{"character_id": "alien", "speaker": "Vaelthor", "text": "Her core is completely cold... Her synthetic mind collapsed trying to compute the Chronodox paradox. She shut down to avoid becoming a threat."},
				{"character_id": "humano", "speaker": "Rigard", "text": "Unit-7..."}
			]
		elif lang == "ja":
			trio_dialogues = [
				{"character_id": "mutante", "image": sc4, "delay_before": 1.2, "speaker": "Kira", "text": "(息を荒げて) やったわ... あの怪物を倒した..."},
				{"character_id": "alien", "speaker": "Vaelthor", "text": "彼女のコアは完全に冷え切っている... クロノドックスのパラドックスを処理しようとして合成頭脳が崩壊したのだ。我々に危害を加えないよう、強制シャットダウンを選んだのだろう。"},
				{"character_id": "humano", "speaker": "Rigard", "text": "Unit-7..."}
			]
		else:
			trio_dialogues = [
				{"character_id": "mutante", "image": sc4, "delay_before": 1.2, "speaker": "Kira", "text": "[i](Ofegante)[/i] Conseguimos... O desgraçado caiu."},
				{"character_id": "alien", "speaker": "Vaelthor", "text": "O núcleo dela tá totalmente frio... A mente sintética entrou em colapso tentando processar o paradoxo do Chronodox. Ela se desligou forçadamente pra não surtar e virar uma ameaça contra nós."},
				{"character_id": "humano", "speaker": "Rigard", "text": "Unit-7..."}
			]

		start_story_cutscene(trio_dialogues, func(): execute_unit7_awakening_climax())
	)

func execute_unit7_awakening_climax():
	is_in_cutscene = true
	is_cutscene_input_locked = true
	cutscene_dialogue_queue.clear()
	cutscene_on_complete = Callable()
	cutscene_panel.hide()
	cutscene_prompt.hide()

	silence_map_audio()

	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.color.a = 1.0

	var tex_closed = load_texture_safe("cutscene_final_5")
	if not tex_closed: tex_closed = load_texture_safe("cutscene_final_5")
	cutscene_bg.texture = tex_closed
	cutscene_layer.show()
	fade_to_transparent(0.5)

	await get_tree().create_timer(3.0).timeout
	audio_manager.play_sfx("sfx_robot_poweron")
	audio_manager.play_bgm("credits", false, 1.0, false)

	var tex_open = load_texture_safe("cutscene_final_6")
	if not tex_open: tex_open = load_texture_safe("cutscene_final_6")
	if tex_open:
		var overlay = TextureRect.new()
		overlay.texture = tex_open
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		overlay.modulate.a = 0.0
		cutscene_layer.add_child(overlay)
		cutscene_layer.move_child(overlay, cutscene_bg.get_index() + 1)
		var dissolve_tween = create_tween()
		dissolve_tween.tween_property(overlay, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		await dissolve_tween.finished
		cutscene_bg.texture = tex_open
		overlay.queue_free()

	await get_tree().create_timer(1.0).timeout
	cutscene_port_frame.show()
	cutscene_portrait_rect.texture = diag_tex_normal.get("robo", null)
	cutscene_name_label.position = Vector2(145, 12)
	cutscene_name_label.text = "Unit-7"
	cutscene_name_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	cutscene_text_label.position = Vector2(145, 38)
	cutscene_text_label.size = Vector2(cutscene_panel.size.x - 165, 85)
	cutscene_text_label.text = "[color=#ffffff]...[/color]"
	cutscene_panel.show()

	await get_tree().create_timer(2.5).timeout

	fade_to_black(0.6, func():
		cutscene_layer.hide()
		cutscene_bg.texture = null
		cutscene_panel.hide()
		is_in_cutscene = false

		var stats_payload = {
			"floor": current_floor,
			"enemies_killed": total_enemies_killed,
			"treasures": total_treasures_collected,
			"has_chronodox": has_chronodox
		}

		credits_screen.start_flow(stats_payload, audio_manager)
		fade_to_transparent(0.5)
	)

func capture_clean_snapshot() -> ImageTexture:
	var img = get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img) if img else null

func start_combat():
	dismiss_tutorial_banner()

	is_transitioning_combat = true
	player.velocity = Vector3.ZERO
	silence_map_audio()

	ui_canvas.hide()
	if dialogue_manager: dialogue_manager.pause_dialogues()

	await RenderingServer.frame_post_draw

	var snapshot = capture_clean_snapshot()
	last_dungeon_snapshot = snapshot
	ui_canvas.show()

	battle_engine.etapa_dois = etapa_dois
	battle_engine.start_battle(get_viewport(), ui_canvas, party_system, audio_manager, current_floor, floor_key_found, has_chronodox, snapshot, has_csouter)

func _on_battle_ended(victory: bool, enemies_killed: int, is_boss: bool = false, enemy_id: String = "", dead_without_drive: Array = []):
	is_transitioning_combat = false
	total_enemies_killed += enemies_killed
	var leader = party_system.members["humano"]

	# 1. Mestre de Raça Derrotado
	if victory and (enemy_id.begins_with("mestre_dos_") or enemy_id.begins_with("enemy_master_")):
		total_treasures_collected += 1
		update_hud()
		if audio_manager:
			audio_manager.play_sfx("sfx_chest_open")

		var sys_title = ""
		var sys_desc = ""
		match enemy_id:
			"enemy_master_drone", "enemy_master_drone":
				sys_title = Localization.t("popup_master_drone_title")
				sys_desc = Localization.t("popup_master_drone_desc")
			"enemy_master_mutant", "enemy_master_mutant":
				sys_title = Localization.t("popup_master_mutante_title")
				sys_desc = Localization.t("popup_master_mutante_desc")
			"enemy_master_android", "enemy_master_android":
				sys_title = Localization.t("popup_master_androide_title")
				sys_desc = Localization.t("popup_master_androide_desc")
			"enemy_master_alien", "enemy_master_alien":
				sys_title = Localization.t("popup_master_alien_title")
				sys_desc = Localization.t("popup_master_alien_desc")

		if pending_level_up_summary != "":
			sys_desc += "\n\n[color=#00e5ff]★ " + pending_level_up_summary + "[/color]"
			pending_level_up_summary = ""

		show_system_message("[color=#ff6600]" + sys_title + "[/color]", sys_desc, null, func():
			var chars = ["humano", "alien", "robo"]
			if not party_system.is_kira_away: chars.append("mutante")
			var speaker = chars[randi() % chars.size()]
			dialogue_manager.trigger_dialogue("mestre_derrotado", speaker)
		, "")
		return

	if victory and pending_level_up_summary != "":
		var title = Localization.t("popup_level_up_title", "PROGRESSÃO TÁTICA!")
		var desc = Localization.t("popup_level_up_body", "%s Atributos aumentados!") % pending_level_up_summary
		pending_level_up_summary = ""
		hud_panel.show()
		minimap.show()
		update_hud()
		show_system_message("[color=#00e5ff]" + title + "[/color]", desc, null, Callable(), "sfx_level_up")
		return

	# 2. Alien Baú derrotado
	if enemy_id == "enemy_alien_chest" and victory:
		floor_key_found = true
		deactivate_portal_shield()
		for p in pois:
			if p.type == "chest": p.has_floor_key = false

		update_hud()
		dialogue_manager.trigger_dialogue("chave_encontrada")

		var alarm_timer = get_tree().create_timer(4.5)
		alarm_timer.timeout.connect(func():
			if is_game_started and not battle_engine.is_in_battle and not is_in_cutscene and not credits_screen.visible:
				if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
				dialogue_manager.trigger_dialogue("alarme_seguranca")
		)
		return

	# 3. Boss Final
	if is_boss and victory and enemy_id == "enemy_boss_khen_shalom":
		silence_map_audio()
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.color.a = 1.0
		if hud_panel: hud_panel.hide()
		if minimap: minimap.hide()
		if interaction_label: interaction_label.hide()
		if dialogue_panel: dialogue_panel.hide()
		play_cutscene_epilogue()
		return

	# 4. Chronodox Paradox
	if not victory and leader.hp <= 0 and has_chronodox and not is_boss:
		silence_map_audio()
		fade_to_black(0.4, func():
			audio_manager.stop_bgm()
			var t1 = get_tree().create_timer(1.0)
			t1.timeout.connect(func():
				audio_manager.play_sfx("sfx_paradox_egnite")
				var t2 = get_tree().create_timer(1.0)
				t2.timeout.connect(func(): play_cutscene_final_sequence())
			)
		)
		return

	# 5. Game Over normal
	if leader.hp <= 0:
		silence_map_audio()
		game_over_script.stat_floor_reached = current_floor
		game_over_script.stat_enemies_killed = total_enemies_killed
		game_over_script.stat_treasures_collected = total_treasures_collected
		game_over_script.stat_has_chronodox = has_chronodox
		var living_count = 0
		for k in party_system.members.keys():
			if party_system.members[k].hp > 0: living_count += 1
		game_over_script.stat_living_allies = living_count

		fade_to_black(0.5, func():
			if ResourceLoader.exists("res://GameOver.tscn"):
				get_tree().change_scene_to_file("res://GameOver.tscn")
			else:
				var go_script = load("res://GameOver.gd")
				var go_node = Control.new()
				go_node.set_script(go_script)
				var cur_scene = get_tree().current_scene
				get_tree().root.add_child(go_node)
				get_tree().current_scene = go_node
				if cur_scene: cur_scene.queue_free()
		)
		return

	# 6. Drop de Detector ou Baú Comum em Batalhas Normais
	if victory and not is_boss and enemy_id != "enemy_alien_chest":
		var elite_enemies = ["enemy_parasite", "enemy_mech_soldier", "enemy_guardian", "enemy_queen", "enemy_guardian", "enemy_queen"]
		var is_elite_fight: bool = enemy_id in elite_enemies

		var rate_per_enemy: float = 0.02 if is_elite_fight else 0.01
		var drop_chance: float = 1.0 if etapa_dois else (enemies_killed * rate_per_enemy)

		if randf() <= drop_chance:
			var can_get_detector = not has_detector and (etapa_dois or randf() <= 0.20)
			if can_get_detector:
				has_detector = true
				total_treasures_collected += 1

				var title = Localization.t("popup_detector_title", "★ ESPÓLIO DE COMBATE RARO!")
				var desc = Localization.t("popup_detector_desc", "A horda dropou um Detector de Metais!\n(Bips rápidos de sonar indicarão a presença de cápsulas sob o piso).")
				var d_tex = load_texture_safe("ui_item_detector")
				if not d_tex: d_tex = load_texture_safe("char_port_detector")

				show_system_message("[color=#00ff66]" + title + "[/color]", desc, d_tex, func():
					dialogue_manager.trigger_dialogue("detector_encontrado")
				, "sfx_level_up")
			else:
				total_treasures_collected += 1
				if audio_manager: audio_manager.play_sfx("sfx_chest_open")

				var chars = ["humano", "alien", "robo"]
				if not party_system.is_kira_away: chars.append("mutante")
				var speaker = chars[randi() % chars.size()]
				dialogue_manager.trigger_dialogue("bau_encontrado", speaker)
		else:
			if dialogue_manager:
				dialogue_manager.resume_dialogues()
	else:
		if dialogue_manager:
			dialogue_manager.resume_dialogues()

	# 7. Atualização de Missão de Telemetria
	if victory and not current_floor_mission.is_empty() and current_floor_mission.get("is_active", false) and not current_floor_mission.is_completed:
		if current_floor_mission.enemy_id == enemy_id:
			current_floor_mission.current_kills = min(current_floor_mission.target_kills, current_floor_mission.current_kills + enemies_killed)
			if current_floor_mission.current_kills >= current_floor_mission.target_kills:
				current_floor_mission.is_completed = true
				if audio_manager: audio_manager.play_sfx("sfx_level_up")
			update_hud()

	if victory and dead_without_drive.size() > 0:
		for dead_char in dead_without_drive: spawn_data_orb(dead_char, player.global_position)

	if is_game_started and not is_in_cutscene and not credits_screen.visible and not (terminal_ui and terminal_ui.is_open):
		hud_panel.show()
		minimap.show()
		update_hud()

func _on_party_leveled_up(leveled_names: Array, new_levels: Dictionary):
	var lang = Localization.current_language
	var summary_text = ""
	if leveled_names.size() == 1:
		var char_n = leveled_names[0]
		summary_text = ("%s reached Level %d!" if lang == "en" else ("%s がレベル %d に上がった！" if lang == "ja" else "%s subiu para o Nível %d!")) % [char_n, new_levels[char_n]]
	elif leveled_names.size() == party_system.members.size():
		summary_text = "ALL CREW leveled up!" if lang == "en" else ("部隊全員がレベルアップ！" if lang == "ja" else "TODA A EQUIPE subiu de nível!")
	else:
		summary_text = ("%s leveled up!" if lang == "en" else ("%s がレベルアップ！" if lang == "ja" else "%s subiram de nível!")) % ", ".join(leveled_names)

	if battle_engine and battle_engine.is_in_battle:
		pending_level_up_summary = summary_text
		return

	var title = Localization.t("popup_level_up_title", "PROGRESSÃO TÁTICA!")
	var desc = Localization.t("popup_level_up_body", "%s Atributos aumentados!") % summary_text
	show_system_message("[color=#00e5ff]" + title + "[/color]", desc, null, Callable(), "sfx_level_up")

func _on_dialogue_triggered(payload):
	var char_key = get_canonical_char_id(payload.character_id)
	var display_name = payload.get("speaker", get_display_name(char_key))
	current_dialogue_char = char_key

	if dialogue_port_frame: dialogue_port_frame.show()
	dialogue_label.position = Vector2(145, 15)
	dialogue_label.size = Vector2(dialogue_panel.size.x - 165, 110)
	portrait_rect.texture = diag_tex_normal.get(char_key, null)
	dialogue_label.text = "[b][color=#00e5ff]%s[/color][/b]\n%s" % [display_name, payload.text]
	dialogue_panel.show()

	var blink_delay = get_tree().create_timer(1.8)
	blink_delay.timeout.connect(func():
		if dialogue_panel.visible and current_dialogue_char == char_key and diag_tex_closed.has(char_key):
			portrait_rect.texture = diag_tex_closed[char_key]
			var reopen_delay = get_tree().create_timer(0.18)
			reopen_delay.timeout.connect(func():
				if dialogue_panel.visible and current_dialogue_char == char_key and diag_tex_normal.has(char_key):
					portrait_rect.texture = diag_tex_normal[char_key]
			)
	)

func _on_dialogue_ended():
	if dialogue_panel: dialogue_panel.hide()
	if dialogue_port_frame: dialogue_port_frame.hide()
