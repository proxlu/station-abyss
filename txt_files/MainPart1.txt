# MainPart1.gd
extends Node3D

const ASSETS_DIR = "res://assets/"

# --- EXPORTS & MODO DEBUG ---
@export var enable_marching_footsteps: bool = true
var etapa_dois: bool = false

# --- SISTEMAS PRÉ-CARREGADOS ---
var dungeon_generator = preload("res://ProceduralDungeon.gd").new()
# REGRA DO PROJETO: No Main é SEMPRE 'party_system' (sem _ref)
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

# --- JOGADOR 3D ---
var player: CharacterBody3D
var camera: Camera3D
var collision_shape: CollisionShape3D

# --- INTERFACE HUD ---
var ui_canvas: CanvasLayer
var hud_panel: Panel
var hud_top_label: RichTextLabel
var hud_name_label: Label
var hud_hp_bar: ProgressBar
var hud_hp_text: Label
var hud_mp_bar: ProgressBar
var hud_mp_text: Label
var interaction_label: Label
var active_tutorial_banner: Control = null
var esc_confirm_panel: Panel
var is_esc_open: bool = false

# --- CAIXA DE DIÁLOGOS EM CAMPO ---
var dialogue_panel: Panel
var dialogue_port_frame: Panel
var portrait_rect: TextureRect
var dialogue_label: RichTextLabel
var current_dialogue_char: String = ""
var diag_tex_normal: Dictionary = {}
var diag_tex_closed: Dictionary = {}

# --- TRANSIÇÃO E ESTADOS ---
var is_game_started: bool = false
var is_transitioning_combat: bool = false
var is_fade_movement_locked: bool = false
var fade_rect: ColorRect

# --- SISTEMA DE CUTSCENES ---
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

# --- SPACE SPOOTER & ÁUDIO PROXIMIDADE ---
var active_spooter_minigame: Control = null
var current_active_arcade_poi: Dictionary = {}
var arcade_proximity_player: AudioStreamPlayer = null
var current_proximity_stream_path: String = ""
var is_arcade_input_locked: bool = false

# --- ANDAR, MISSÃO E EXPLORAÇÃO ---
var current_floor: int = 1
var floor_key_found: bool = false
var has_chronodox: bool = false
var has_detector: bool = false
var has_csouter: bool = false
var detector_beep_timer: float = 0.0
var total_treasures_collected: int = 0
var total_enemies_killed: int = 0
var last_dungeon_snapshot: ImageTexture = null

var current_floor_mission: Dictionary = {}
var hud_cycle_mode: int = 0
var hud_cycle_timer: float = 0.0
var active_orbs: Array[Dictionary] = []
var valid_floor_cells: Array = []

var last_turn_direction: int = 0
var zigzag_turn_switches: int = 0
var zigzag_suppressed_count: int = 0

var pois: Array = []
var step_counter: float = 0.0
var footstep_timer: float = 0.0

var current_sys_msg_id: int = 0
var pending_level_up_summary: String = ""

# --- SALA DO COFRE (VAULT) ---
var is_vault_floor: bool = false
var vault_floor_id: float = 0.0
var vault_timer: float = 0.0
var vault_chests_collected: int = 0
var active_vault_chest_node: Node3D = null
var vault_chest_timer: float = 0.0
var vault_chest_state: String = "idle"
var vault_bonus_achieved: bool = false
var is_vault_decision_open: bool = false
var vault_decision_panel: Panel = null
var vault_countdown_label: Label = null

# --- CUTSCENES EXTRAS DOS PODS MÉDICOS ---
var khen_twins: bool = false
var twins_defeated: bool = false
var extra_cutscene_1_played: bool = false
var extra_cutscene_2_played: bool = false
var extra_cutscene_3_played: bool = false
var extra_cutscene_4_played: bool = false
var extra_cutscene_played_this_floor: bool = false

# --- OS 4 CHEFES ESPECIAIS ---
var abyss_killer_defeated: bool = false
var r07_echo_defeated: bool = false
var saria_yuna_defeated: bool = false
var aurelia_voss_defeated: bool = false
var abyss_killer_fled: bool = false

# ==============================================================================
# FUNÇÕES DE UTILITÁRIOS E TEXTURAS
# ==============================================================================
static func get_game_font(category: String = "ui") -> Font:
	return FontManager.get_font(category)

static func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]

	if base_name == "char_port_csouter": candidates.append_array(["ui_item_csouter", "prop_csouter_ground", "item_csouter"])
	elif base_name == "ui_item_csouter": candidates.append_array(["char_port_csouter", "prop_csouter_ground", "item_csouter"])

	if base_name.begins_with("cutscene_"):
		candidates.append(base_name.replace("cutscene_", "cena_"))
	elif base_name.begins_with("cena_"):
		candidates.append(base_name.replace("cena_", "cutscene_"))

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null

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

func preload_dialogue_textures():
	for c in ["humano", "mutante", "alien", "robo"]:
		var norm_tex = load_texture_safe("char_port_" + c)
		var clos_tex = load_texture_safe("char_closed_" + c)
		if norm_tex: diag_tex_normal[c] = norm_tex
		if clos_tex: diag_tex_closed[c] = clos_tex
		elif diag_tex_normal.has(c): diag_tex_closed[c] = diag_tex_normal[c]

# ==============================================================================
# CONFIGURAÇÃO DE TRANSIÇÕES, AMBIENTE E MONTAGEM DE UI
# ==============================================================================
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
	cutscene_prompt.text = "[E / SPACE / A] Continue" if lang == "en" else ("[E / LEERTASTE / A] Weiter" if lang == "de" else ("[E / スペース / A] 続ける" if lang == "ja" else "[E / ESPAÇO / A] Avançar"))
	cutscene_prompt.position = Vector2(diag_w - 250, diag_h - 26)
	cutscene_prompt.size = Vector2(230, 20)
	cutscene_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cutscene_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cutscene_prompt.add_theme_font_override("font", font_ui)
	cutscene_prompt.add_theme_font_size_override("font_size", 11)
	cutscene_prompt.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 0.7))
	cutscene_panel.add_child(cutscene_prompt)

# ==============================================================================
# MENSAGENS DO SISTEMA E TUTORIAL
# ==============================================================================
func dismiss_tutorial_banner():
	if active_tutorial_banner and is_instance_valid(active_tutorial_banner):
		active_tutorial_banner.queue_free()
		active_tutorial_banner = null

func _show_dungeon_tutorial_banner():
	if not is_game_started or is_in_cutscene or battle_engine.is_in_battle or party_menu.is_open or is_esc_open:
		return

	dismiss_tutorial_banner()
	var tut_tex = load_texture_safe("ui_tutorial")
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
				if is_instance_valid(banner): banner.queue_free()
				if active_tutorial_banner == banner: active_tutorial_banner = null
			)
	)

func show_system_message(title_bbcode: String, body_bbcode: String, item_texture: Texture2D = null, on_complete: Callable = Callable(), sfx_name: String = ""):
	current_sys_msg_id += 1
	var this_id = current_sys_msg_id

	if dialogue_manager: dialogue_manager.pause_dialogues()
	if audio_manager and sfx_name != "": audio_manager.play_sfx(sfx_name)

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
		if current_sys_msg_id != this_id: return

		if on_complete.is_valid():
			if dialogue_manager: dialogue_manager.resume_dialogues()
			on_complete.call()
		else:
			dialogue_panel.hide()
			if dialogue_port_frame: dialogue_port_frame.hide()
			if dialogue_manager: dialogue_manager.resume_dialogues()
	)

# ==============================================================================
# CONTROLE DE JANELA E TELA CHEIA
# ==============================================================================
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
