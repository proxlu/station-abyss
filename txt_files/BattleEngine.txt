# BattleEngine.gd
class_name BattleEngine
extends Node

signal battle_started
signal battle_ended(victory: bool, enemies_killed: int, is_boss: bool, enemy_id: String, dead_allies_without_drive: Array)

const ASSETS_DIR = "res://assets/"

const CUTIN_WIDTH_PX: float = 325.0
const CUTIN_VISIBLE_RATIO: float = 0.70
const CUTIN_BOTTOM_OFFSET: float = 0.0

const ADVANCED_ENEMIES: Array[String] = ["enemy_parasite", "enemy_mech_soldier", "enemy_guardian", "enemy_queen"]
const KHEN_ENEMIES: Array[String] = ["enemy_infante_khen"]

# Variáveis configuráveis de impacto
@export var tremor_a_mais: bool = true
@export var golpe_impactante: bool = true

# =========================================================================
# CONTROLE DE PERSISTÊNCIA DOS 4 MESTRES E ABATES NA RUN
# =========================================================================
static var defeated_masters: Dictionary = {
	"drone": false,
	"mutante": false,
	"androide": false,
	"alien": false
}
static var masters_fought_without_chronodox: int = 0
static var masters_fought_with_chronodox: int = 0

# Contador de abates por espécie para liberar a invasão dos Mestres
static var race_kills: Dictionary = {
	"drone": 0,
	"mutante": 0,
	"androide": 0,
	"alien": 0
}

static func reset_run_state() -> void:
	defeated_masters = {
		"drone": false,
		"mutante": false,
		"androide": false,
		"alien": false
	}
	race_kills = {
		"drone": 0,
		"mutante": 0,
		"androide": 0,
		"alien": 0
	}
	masters_fought_without_chronodox = 0
	masters_fought_with_chronodox = 0

var enemy_shield: int = 0
var enemy_max_shield: int = 0
var enemy_shield_bar: ProgressBar = null
var is_boss_spawning: bool = false

var is_in_battle: bool = false
var battle_ui: Control
var bg_rect: TextureRect
var log_label: Label
var passive_card_panel: Panel
var passive_info_label: Label
var csouter_lens_panel: Panel
var csouter_pdl_label: Label
var viewport_ref: Viewport
var party_system_ref: Node
var audio_manager: Node

var etapa_dois: bool = false
var stunned_allies: Dictionary = {}
var stun_applied_this_round: Dictionary = {}
var portrait_nodes: Dictionary = {}
var portrait_frame_nodes: Dictionary = {}
var portrait_border_overlays: Dictionary = {}
var label_nodes: Dictionary = {}
var hp_bar_nodes: Dictionary = {}
var hp_text_nodes: Dictionary = {}
var shield_bar_nodes: Dictionary = {}
var mp_bar_nodes: Dictionary = {}
var mp_text_nodes: Dictionary = {}

var modo_visual_turno: int = 3
var active_turn_tween: Tween = null

var cutin_container: Control
var cutin_sprite: TextureRect
var combat_panel: Panel
var party_hud_container: HBoxContainer

var enemy_shadow: TextureRect
var enemy_sprite: TextureRect
var enemy_shadow_left: TextureRect
var enemy_sprite_left: TextureRect
var enemy_shadow_right: TextureRect
var enemy_sprite_right: TextureRect
var enemy_count_label: Label
var enemy_hp_bar: ProgressBar = null
var security_badge_label: Label
var khen_particles: CPUParticles2D = null

var tex_cache_normal: Dictionary = {}
var tex_cache_closed: Dictionary = {}
var tex_cache_damaged: Dictionary = {}

var allies_dead_at_start: Dictionary = {}
var is_ally_animating_hit: Dictionary = {}

var menu_container: Control
var main_action_menu: VBoxContainer
var skills_menu: VBoxContainer
var main_buttons = []
var skill_buttons = []

var base_enemies_pool = ["enemy_drone", "enemy_mutant_beast", "enemy_corrupted_android", "enemy_alien_scout"]

var current_enemy_id: String
var is_current_boss: bool = false
var is_master_boss: bool = false
var pending_master_type: String = ""
var active_master_type: String = ""
var accumulated_horde_exp: int = 0
var is_alien_chest: bool = false
var is_weakened_race: bool = false
var has_csouter_radar: bool = false
var has_chronodox: bool = false 
var enemy_unit_max_hp: int = 50
var horde_units: Array[int] = []
var enemy_unit_atk: int = 15
var enemy_exp_reward: int = 40
var current_enemy_speed: int = 10
var current_floor_num: int = 1
var is_security_mode: bool = false
var total_enemies_killed_this_fight: int = 0

var enemy_flee_penalty: float = 0.0

# Mecânica de Provocar da Kira
var is_kira_taunting: bool = false
var taunt_remaining_hits: int = 0

var turn_queue = []
var pending_actions = []
var current_acting_index = 0
var defending_members: Dictionary = {}

enum State { START, SELECT_ACTION, RESOLVE_ACTIONS, END }
var battle_state = State.START
var active_menu_type = "none"

var base_enemy_pos: Vector2 = Vector2.ZERO
var is_animating_hit: bool = false
var enemy_hit_tween: Tween
var blink_timer: float = 0.0

const SIDE_ENEMY_SIZE = Vector2(250, 250)
const SIDE_ENEMY_OFFSET_L = Vector2(-25, 25)
const SIDE_ENEMY_OFFSET_R = Vector2(75, 25)
const SIDE_ENEMY_MODULATE = Color(0.40, 0.40, 0.40, 0.90)
const ENEMY_SHADOW_COLOR  = Color(0.0, 0.0, 0.0, 0.70)
const ENEMY_SHADOW_OFFSET = Vector2(6, 6)
const HP_BAR_DRAIN_DURATION = 0.25

static func get_game_font(category: String = "ui") -> Font:
	return FontManager.get_font(category)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload_portrait_cache()

func preload_portrait_cache():
	var chars = ["humano", "mutante", "alien", "robo"]
	for c in chars:
		var norm_tex = load_texture_safe("char_port_" + c)
		if not norm_tex: norm_tex = load_texture_safe("char_port_" + c)
		if norm_tex: tex_cache_normal[c] = norm_tex

		var clos_tex = load_texture_safe("char_closed_" + c)
		if not clos_tex: clos_tex = load_texture_safe("char_closed_" + c)
		if clos_tex: tex_cache_closed[c] = clos_tex
		elif tex_cache_normal.has(c): tex_cache_closed[c] = tex_cache_normal[c]

		var damg_tex = load_texture_safe("char_damaged_" + c)
		if not damg_tex: damg_tex = load_texture_safe("char_damaged_" + c)
		if damg_tex: tex_cache_damaged[c] = damg_tex
		elif tex_cache_normal.has(c): tex_cache_damaged[c] = tex_cache_normal[c]

func get_portrait_tex(char_id: String, state: String = "normal") -> Texture2D:
	if state == "closed": return tex_cache_closed.get(char_id, tex_cache_normal.get(char_id, null))
	if state == "damaged": return tex_cache_damaged.get(char_id, tex_cache_normal.get(char_id, null))
	return tex_cache_normal.get(char_id, null)

func create_boss_distortion_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5, 0.42);
    vec2 dir = uv - center;
    float dist = length(dir);
    float angle = atan(dir.y, dir.x);
    float wave = sin(dist * 24.0 - TIME * 2.4) * 0.026 * (1.0 - dist * 0.45);
    float swirl = sin(angle * 4.0 + TIME * 1.6) * 0.015;
    vec2 distorted_uv = uv + vec2(cos(angle), sin(angle)) * wave + vec2(-sin(angle), cos(angle)) * swirl;
    float r = texture(TEXTURE, distorted_uv + vec2(0.007, 0.0)).r;
    float g = texture(TEXTURE, distorted_uv).g;
    float b = texture(TEXTURE, distorted_uv - vec2(0.007, 0.0)).b;
    vec4 col = vec4(r, g, b, 1.0);
    vec4 purple_tint = vec4(0.65, 0.12, 0.95, 1.0);
    vec4 final_col = mix(col, col * purple_tint * 1.9, 0.55 + sin(TIME * 2.8) * 0.1);
    float vignette = smoothstep(0.95, 0.28, dist);
    COLOR = mix(vec4(0.04, 0.01, 0.08, 1.0), final_col, vignette);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	return mat

func _process(delta):
	if is_in_battle and battle_state != State.END and enemy_sprite and not is_animating_hit:
		var t = Time.get_ticks_msec() * 0.0028
		var breathe = sin(t) * 0.025
		var target_scale = Vector2(1.0 - (breathe * 0.4), 1.0 + breathe)
		enemy_sprite.scale = target_scale
		if enemy_shadow: enemy_shadow.scale = target_scale
		if enemy_sprite_left: enemy_sprite_left.scale = target_scale
		if enemy_shadow_left: enemy_shadow_left.scale = target_scale
		if enemy_sprite_right: enemy_sprite_right.scale = target_scale
		if enemy_shadow_right: enemy_shadow_right.scale = target_scale

		if not is_boss_spawning and (is_security_mode or is_current_boss or is_master_boss) and not is_alien_chest:
			var alert_pulse = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
			var pulse_col = Color(1.0 + (alert_pulse * 0.35), 0.7 - (alert_pulse * 0.25), 0.7 - (alert_pulse * 0.25))
			enemy_sprite.modulate = pulse_col
			if enemy_sprite_left and enemy_sprite_left.visible: enemy_sprite_left.modulate = pulse_col * SIDE_ENEMY_MODULATE
			if enemy_sprite_right and enemy_sprite_right.visible: enemy_sprite_right.modulate = pulse_col * SIDE_ENEMY_MODULATE

	if is_in_battle and battle_state != State.END:
		blink_timer += delta
		if blink_timer >= 5.0:
			blink_timer = 0.0
			trigger_party_blink()

func trigger_party_blink():
	var chars = ["humano", "mutante", "alien", "robo"]
	for char_id in chars:
		if char_id == "mutante" and party_system_ref.is_kira_away: continue
		if portrait_nodes.has(char_id) and is_instance_valid(portrait_nodes[char_id]) and party_system_ref.members[char_id].hp > 0:
			if is_ally_animating_hit.get(char_id, false): continue
			var port = portrait_nodes[char_id]
			var clos_t = get_portrait_tex(char_id, "closed")
			if clos_t:
				port.texture = clos_t
				var t = get_tree().create_timer(0.18)
				t.timeout.connect(func():
					if is_in_battle and portrait_nodes.has(char_id) and is_instance_valid(portrait_nodes[char_id]) and party_system_ref.members[char_id].hp > 0:
						if not is_ally_animating_hit.get(char_id, false):
							port.texture = get_portrait_tex(char_id, "normal")
				)

func start_battle(vp: Viewport, canvas: CanvasLayer, p_system: Node, audio: Node, floor_num: int = 1, is_alert_active: bool = false, p_has_chronodox: bool = false, snapshot_tex: Texture2D = null, has_csouter: bool = false):
	if is_in_battle: return
	is_in_battle = true
	is_current_boss = false
	is_master_boss = false
	is_boss_spawning = false
	enemy_shield = 0
	enemy_max_shield = 0
	pending_master_type = ""
	active_master_type = ""
	accumulated_horde_exp = 0
	is_alien_chest = false
	is_weakened_race = false
	has_csouter_radar = has_csouter
	has_chronodox = p_has_chronodox 
	viewport_ref = vp
	party_system_ref = p_system
	audio_manager = audio
	current_floor_num = floor_num
	is_security_mode = is_alert_active
	battle_state = State.START
	total_enemies_killed_this_fight = 0
	blink_timer = 0.0
	defending_members.clear()
	is_ally_animating_hit.clear()
	is_kira_taunting = false
	taunt_remaining_hits = 0
	enemy_flee_penalty = 0.0

	allies_dead_at_start.clear()
	stunned_allies.clear()
	stun_applied_this_round.clear()
	for k in party_system_ref.members.keys():
		if party_system_ref.members[k].hp <= 0:
			allies_dead_at_start[k] = true

	var spawn_alien_chest_roll = (not is_security_mode) and (etapa_dois or (randf() <= 0.01))

	var candidate_enemies: Array[Dictionary] = []
	for e_id in base_enemies_pool:
		candidate_enemies.append({"id": e_id, "weight": 1.0})

	# Escalamento progressivo de spawn para inimigos por andar com pesos decrescentes
	if floor_num >= 5: candidate_enemies.append({"id": "enemy_parasite", "weight": 0.85})
	if floor_num >= 10: candidate_enemies.append({"id": "enemy_mech_soldier", "weight": 0.70})
	if floor_num >= 15: candidate_enemies.append({"id": "enemy_guardian", "weight": 0.55})
	if floor_num >= 20: candidate_enemies.append({"id": "enemy_queen", "weight": 0.40})
	if has_chronodox: candidate_enemies.append({"id": "enemy_infante_khen", "weight": 0.90})

	var total_weight: float = 0.0
	for entry in candidate_enemies: total_weight += entry.weight
	var roll: float = randf() * total_weight
	var accumulated: float = 0.0
	current_enemy_id = candidate_enemies[0].id

	for entry in candidate_enemies:
		accumulated += entry.weight
		if roll <= accumulated:
			current_enemy_id = entry.id
			break

	if spawn_alien_chest_roll:
		current_enemy_id = "enemy_alien_chest"
		is_alien_chest = true

	# Checagem de Mestre da Raça:
	# NUNCA NO ANDAR 1 E APENAS COM 8+ ABATES DA RAÇA ACUMULADOS
	var race_type = ""
	match current_enemy_id:
		"enemy_drone": race_type = "drone"
		"enemy_mutant_beast": race_type = "mutante"
		"enemy_corrupted_android": race_type = "androide"
		"enemy_alien_scout": race_type = "alien"

	if race_type != "":
		if defeated_masters.get(race_type, false):
			is_weakened_race = true
			is_security_mode = false
		else:
			var can_spawn_master = false
			if not has_chronodox and masters_fought_without_chronodox == 0:
				can_spawn_master = true
			elif has_chronodox and masters_fought_with_chronodox == 0:
				can_spawn_master = true

			var kills_satisfied = etapa_dois or (race_kills.get(race_type, 0) >= 8)
			var floor_allowed = (floor_num > 1) or etapa_dois

			if can_spawn_master and floor_allowed and kills_satisfied:
				var m_chance = 0.50 if etapa_dois else 0.01
				if randf() <= m_chance:
					pending_master_type = race_type

	var leader_lvl = party_system_ref.members["humano"].level

	var horde_size: int = 1
	if is_alien_chest:
		horde_size = 1
	elif floor_num == 1:
		horde_size = randi_range(1, 2)
	else:
		var min_horde = clampi(1 + int(floor_num / 6.0), 1, 3)
		var max_horde = clampi(2 + int(floor_num / 3.0), 2, 5)
		if floor_num >= 15:
			max_horde = clampi(2 + int(floor_num / 3.0), 2, 6)
		horde_size = randi_range(min_horde, max_horde)

	# Mutantes e inimigos avançados surgem em menor quantitativo
	if current_enemy_id == "enemy_mutant_beast":
		horde_size = max(1, horde_size - 1)
	elif current_enemy_id in ADVANCED_ENEMIES:
		var red = 2 if (current_enemy_id == "enemy_guardian" or current_enemy_id == "enemy_queen") else 1
		horde_size = max(1, horde_size - red)

	if is_security_mode and not is_alien_chest and not is_weakened_race:
		horde_size += randi_range(0, 1)

	var base_hp = 40 + (floor_num * 14) + (leader_lvl * 8)
	var base_atk = 12 + (floor_num * 4) + (leader_lvl * 3)
	var base_exp = (35 + (floor_num * 16)) * horde_size
	var base_speed = 10 + int(floor_num * 0.6) + (randi() % 3)

	var stat_multiplier: float = 1.0
	match current_enemy_id:
		"enemy_parasite": stat_multiplier = 1.15
		"enemy_mech_soldier":
			stat_multiplier = 1.20
			enemy_flee_penalty = 0.25 # Rifle
		"enemy_guardian": stat_multiplier = 1.25
		"enemy_queen": stat_multiplier = 1.30
		"enemy_infante_khen": stat_multiplier = 1.10
		"enemy_alien_scout":
			enemy_flee_penalty = 0.25 # Rifle

	if is_alien_chest:
		enemy_unit_max_hp = max(20, int(base_hp * 0.50))
		enemy_unit_atk = max(5, int(base_atk * 0.50))
		enemy_exp_reward = 0
		current_enemy_speed = 9999
	else:
		# Diferenciação tática dos 4 inimigos comuns
		match current_enemy_id:
			"enemy_drone":
				enemy_unit_max_hp = max(20, int(base_hp * 0.75)) # Pouca vida
				enemy_unit_atk = int(base_atk * 1.05)            # Dano regular
				current_enemy_speed = base_speed + 3             # Rápido
			"enemy_mutant_beast":
				enemy_unit_max_hp = int(base_hp * 1.25)          # Vida alta
				enemy_unit_atk = int(base_atk * 1.25)            # Dano alto
				current_enemy_speed = max(3, base_speed - 3)     # Lento
			_:
				enemy_unit_max_hp = int(base_hp * stat_multiplier)
				enemy_unit_atk = int(base_atk * stat_multiplier)
				current_enemy_speed = int(base_speed * stat_multiplier)

		enemy_exp_reward = int(base_exp * stat_multiplier)

	if is_weakened_race:
		enemy_unit_max_hp = max(15, int(enemy_unit_max_hp * 0.50))
		enemy_unit_atk = max(4, int(enemy_unit_atk * 0.50))
		current_enemy_speed = max(3, int(current_enemy_speed * 0.50))

	if is_security_mode and not is_alien_chest and not is_weakened_race:
		enemy_unit_max_hp = int(enemy_unit_max_hp * 1.15)
		enemy_unit_atk = int(enemy_unit_atk * 1.10)
		enemy_exp_reward = int(enemy_exp_reward * 1.40)
		current_enemy_speed += 1

	horde_units.clear()
	for i in range(horde_size):
		horde_units.append(enemy_unit_max_hp)

	if audio_manager:
		var battle_pitch = 1.15 if is_security_mode else 1.0
		if current_enemy_id == "enemy_infante_khen":
			audio_manager.play_bgm("bgm_infantry", true, battle_pitch)
		else:
			audio_manager.play_bgm("bgm_battle", true, battle_pitch)

	setup_battle_ui(canvas, snapshot_tex)
	emit_signal("battle_started")

	var lang = Localization.current_language
	var enemy_display_name = get_formatted_enemy_name()

	if is_alien_chest:
		if lang == "en": log_message("AMBUSH! An Alien Chest appeared!")
		elif lang == "ja": log_message("奇襲！ エイリアンチェストが現れた！")
		else: log_message("EMBOSCADA! Um Alien Baú apareceu!")
	elif is_security_mode:
		if lang == "en": log_message("[CONTAINMENT] Containment Force %s (x%d) intercepted the squad!" % [enemy_display_name, horde_units.size()])
		elif lang == "ja": log_message("[粛清] 粛清部隊 %s (x%d) が部隊を急襲！" % [enemy_display_name, horde_units.size()])
		else: log_message("[CONTENÇÃO] Força de Contenção %s (x%d) interceptou a equipe!" % [enemy_display_name, horde_units.size()])
	elif is_weakened_race:
		if lang == "en": log_message("[DISORGANIZED] A weakened %s horde (x%d) engaged the squad!" % [enemy_display_name, horde_units.size()])
		elif lang == "ja": log_message("[弱体化] 統率を失った %s (x%d) が現れた！" % [enemy_display_name, horde_units.size()])
		else: log_message("[DESORGANIZADOS] Horda enfraquecida de %s (x%d) abordou a equipe!" % [enemy_display_name, horde_units.size()])
	else:
		if lang == "en": log_message("ENCOUNTER! %s horde (x%d) engaged the squad!" % [enemy_display_name, horde_units.size()])
		elif lang == "ja": log_message("遭遇！ %s の群れ (x%d) が戦闘を開始！" % [enemy_display_name, horde_units.size()])
		else: log_message("ENCONTRO! Horda de %s (x%d) interceptou a equipe!" % [enemy_display_name, horde_units.size()])

	get_tree().create_timer(1.2).timeout.connect(start_turn_selection)

func start_boss_battle(vp: Viewport, canvas: CanvasLayer, p_system: Node, audio: Node, floor_num: int = 1, is_debug: bool = true, snapshot_tex: Texture2D = null, p_has_csouter: bool = false):
	if is_in_battle: return
	is_in_battle = true
	is_current_boss = true
	is_master_boss = false
	is_boss_spawning = false
	enemy_shield = 0
	enemy_max_shield = 0
	is_alien_chest = false
	is_weakened_race = false
	has_csouter_radar = p_has_csouter
	viewport_ref = vp
	party_system_ref = p_system
	audio_manager = audio
	current_floor_num = floor_num
	is_security_mode = true
	battle_state = State.START
	total_enemies_killed_this_fight = 0
	blink_timer = 0.0
	defending_members.clear()
	is_ally_animating_hit.clear()
	stunned_allies.clear()
	stun_applied_this_round.clear()
	is_kira_taunting = false
	taunt_remaining_hits = 0
	enemy_flee_penalty = 0.0

	if party_system_ref.members.has("robo"):
		party_system_ref.members["robo"].hp = 0
		party_system_ref.members["robo"].mp = 0

	allies_dead_at_start.clear()
	for k in party_system_ref.members.keys():
		if party_system_ref.members[k].hp <= 0:
			allies_dead_at_start[k] = true

	current_enemy_id = "enemy_boss_khen_shalom"
	# Buff de +30% HP e +15% ATK/VEL no Boss Final
	if is_debug:
		enemy_unit_max_hp = int(180 * 1.30) # 234
		enemy_unit_atk = int(28 * 1.15)     # 32
		enemy_exp_reward = 2500
		current_enemy_speed = int(18 * 1.15)# 21
	else:
		enemy_unit_max_hp = int((1200 + (floor_num * 150)) * 1.30)
		enemy_unit_atk = int((35 + (floor_num * 6)) * 1.15)
		enemy_exp_reward = 5000
		current_enemy_speed = int(22 * 1.15)

	horde_units = [enemy_unit_max_hp]

	if audio_manager:
		audio_manager.play_bgm("bgm_final_boss", true, 1.0)

	setup_battle_ui(canvas, snapshot_tex)
	emit_signal("battle_started")

	var boss_name = get_formatted_enemy_name()
	var lang = Localization.current_language
	if lang == "en": log_message("FINAL BATTLE! %s, the Cosmic Demon has awakened!" % boss_name)
	elif lang == "ja": log_message("最終決戦！ 宇宙の悪魔 %s が目覚めた！" % boss_name)
	else: log_message("BATALHA FINAL! %s, o Demônio Cósmico despertou!" % boss_name)

	get_tree().create_timer(1.2).timeout.connect(start_turn_selection)

func setup_battle_ui(canvas: CanvasLayer, snapshot_tex: Texture2D):
	var vp_size = canvas.get_viewport().get_visible_rect().size
	var lang = Localization.current_language
	portrait_nodes.clear()
	portrait_frame_nodes.clear()
	portrait_border_overlays.clear()
	label_nodes.clear()
	hp_bar_nodes.clear()
	hp_text_nodes.clear()
	shield_bar_nodes.clear()
	mp_bar_nodes.clear()
	mp_text_nodes.clear()

	var font_title = get_game_font("title")
	var font_mono = get_game_font("mono")
	var font_ui = get_game_font("ui")

	battle_ui = Control.new()
	battle_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(battle_ui)

	bg_rect = TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if snapshot_tex: bg_rect.texture = snapshot_tex
	else:
		var img = viewport_ref.get_texture().get_image()
		if img: bg_rect.texture = ImageTexture.create_from_image(img)

	if is_current_boss and not is_master_boss:
		bg_rect.material = create_boss_distortion_material()
	else:
		bg_rect.material = null
	battle_ui.add_child(bg_rect)

	var panel_height = 210.0
	var panel_margin = 10.0
	var panel_y = vp_size.y - panel_height - panel_margin
	var panel_w = vp_size.x - (panel_margin * 2.0)

	combat_panel = Panel.new()
	combat_panel.position = Vector2(panel_margin, panel_y)
	combat_panel.size = Vector2(panel_w, panel_height)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	p_style.border_width_top = 2
	p_style.border_color = Color(1.0, 0.2, 0.1) if (is_security_mode or is_current_boss or is_master_boss) else Color(0, 0.8, 1)
	p_style.corner_radius_top_left = 4
	p_style.corner_radius_top_right = 4
	p_style.corner_radius_bottom_right = 4
	p_style.corner_radius_bottom_left = 4
	combat_panel.add_theme_stylebox_override("panel", p_style)
	battle_ui.add_child(combat_panel)

	if has_csouter_radar:
		_create_csouter_lens_ui(font_title, font_mono)

	passive_card_panel = Panel.new()
	passive_card_panel.position = Vector2(panel_margin + 10.0, panel_y - 34.0)
	passive_card_panel.size = Vector2(430, 28)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.01, 0.03, 0.07, 0.95)
	card_style.border_width_left = 2
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.0, 1.0, 0.7, 0.85)
	card_style.corner_radius_top_left = 3
	card_style.corner_radius_top_right = 3
	card_style.corner_radius_bottom_right = 3
	card_style.corner_radius_bottom_left = 3
	passive_card_panel.add_theme_stylebox_override("panel", card_style)
	passive_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive_card_panel.hide()
	battle_ui.add_child(passive_card_panel)

	passive_info_label = Label.new()
	passive_info_label.position = Vector2(10, 0)
	passive_info_label.size = Vector2(410, 28)
	passive_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	passive_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	passive_info_label.add_theme_font_override("font", font_ui)
	passive_info_label.add_theme_font_size_override("font_size", 11)
	passive_info_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.7))
	passive_card_panel.add_child(passive_info_label)

	var center_x = vp_size.x / 2.0
	var original_ref_y = max(18.0, panel_y - 300.0 - 68.0)
	var label_y = original_ref_y + 300.0 + 4.0
	var hp_bar_y = label_y + 24.0

	var enemy_size = Vector2(150, 150) if is_alien_chest else Vector2(300, 300)
	base_enemy_pos = Vector2(center_x - (enemy_size.x / 2.0), label_y - enemy_size.y + 6.0)

	var enemy_tex = load_enemy_texture(current_enemy_id)

	enemy_shadow_left = TextureRect.new()
	enemy_shadow_left.position = base_enemy_pos + SIDE_ENEMY_OFFSET_L + ENEMY_SHADOW_OFFSET
	enemy_shadow_left.size = SIDE_ENEMY_SIZE
	enemy_shadow_left.pivot_offset = Vector2(125, 250)
	enemy_shadow_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_shadow_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_shadow_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_shadow_left.modulate = ENEMY_SHADOW_COLOR
	if enemy_tex: enemy_shadow_left.texture = enemy_tex
	battle_ui.add_child(enemy_shadow_left)

	enemy_sprite_left = TextureRect.new()
	enemy_sprite_left.position = base_enemy_pos + SIDE_ENEMY_OFFSET_L
	enemy_sprite_left.size = SIDE_ENEMY_SIZE
	enemy_sprite_left.pivot_offset = Vector2(125, 250)
	enemy_sprite_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_sprite_left.modulate = SIDE_ENEMY_MODULATE
	if enemy_tex: enemy_sprite_left.texture = enemy_tex
	battle_ui.add_child(enemy_sprite_left)

	enemy_shadow_right = TextureRect.new()
	enemy_shadow_right.position = base_enemy_pos + SIDE_ENEMY_OFFSET_R + ENEMY_SHADOW_OFFSET
	enemy_shadow_right.size = SIDE_ENEMY_SIZE
	enemy_shadow_right.pivot_offset = Vector2(125, 250)
	enemy_shadow_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_shadow_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_shadow_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_shadow_right.modulate = ENEMY_SHADOW_COLOR
	if enemy_tex: enemy_shadow_right.texture = enemy_tex
	battle_ui.add_child(enemy_shadow_right)

	enemy_sprite_right = TextureRect.new()
	enemy_sprite_right.position = base_enemy_pos + SIDE_ENEMY_OFFSET_R
	enemy_sprite_right.size = SIDE_ENEMY_SIZE
	enemy_sprite_right.pivot_offset = Vector2(125, 250)
	enemy_sprite_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_sprite_right.modulate = SIDE_ENEMY_MODULATE
	if enemy_tex: enemy_sprite_right.texture = enemy_tex
	battle_ui.add_child(enemy_sprite_right)

	var shadow_offset_to_use = (ENEMY_SHADOW_OFFSET * 2.0) if is_alien_chest else ENEMY_SHADOW_OFFSET
	enemy_shadow = TextureRect.new()
	enemy_shadow.position = base_enemy_pos + shadow_offset_to_use
	enemy_shadow.size = enemy_size
	enemy_shadow.pivot_offset = Vector2(enemy_size.x / 2.0, enemy_size.y)
	enemy_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_shadow.modulate = ENEMY_SHADOW_COLOR
	if enemy_tex: enemy_shadow.texture = enemy_tex
	battle_ui.add_child(enemy_shadow)

	enemy_sprite = TextureRect.new()
	enemy_sprite.position = base_enemy_pos
	enemy_sprite.size = enemy_size
	enemy_sprite.pivot_offset = Vector2(enemy_size.x / 2.0, enemy_size.y)
	enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if enemy_tex: enemy_sprite.texture = enemy_tex
	battle_ui.add_child(enemy_sprite)

	if is_current_boss and not is_master_boss and current_enemy_id == "enemy_boss_khen_shalom":
		khen_particles = CPUParticles2D.new()
		khen_particles.position = base_enemy_pos + Vector2(enemy_size.x / 2.0, enemy_size.y * 0.5)
		khen_particles.amount = 35
		khen_particles.lifetime = 1.8
		khen_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		khen_particles.emission_sphere_radius = 120.0
		khen_particles.gravity = Vector2(0, -18)
		khen_particles.spread = 180.0
		khen_particles.initial_velocity_min = 15.0
		khen_particles.initial_velocity_max = 35.0
		khen_particles.scale_amount_min = 2.0
		khen_particles.scale_amount_max = 4.5
		khen_particles.color = Color(0.8, 0.1, 1.0, 0.45)
		battle_ui.add_child(khen_particles)
		battle_ui.move_child(khen_particles, enemy_shadow.get_index())

	var badge_y = max(4.0, base_enemy_pos.y - 20.0)
	security_badge_label = Label.new()
	security_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	security_badge_label.position = Vector2(center_x - 240, badge_y)
	security_badge_label.size = Vector2(480, 20)
	security_badge_label.add_theme_font_override("font", font_ui)
	security_badge_label.add_theme_font_size_override("font_size", 13)
	security_badge_label.add_theme_constant_override("outline_size", 4)
	security_badge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	battle_ui.add_child(security_badge_label)

	if is_current_boss and not is_master_boss:
		security_badge_label.text = Localization.t("battle_boss_badge", "★ IMPERADOR DO TEMPO - CHEFE FINAL ★")
		security_badge_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		security_badge_label.show()
	elif is_master_boss:
		var master_badge = "★ LÍDER DE RAÇA - MESTRE ★" if lang == "pt" else ("★ SPECIES LEADER - MASTER ★" if lang == "en" else "★ 種族の統率者 - マスター ★")
		security_badge_label.text = master_badge
		security_badge_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
		security_badge_label.show()
	elif is_security_mode and not is_alien_chest:
		security_badge_label.text = Localization.t("battle_purge_badge", "⚠ PROTOCOLO DE PURGA ATIVO ⚠")
		security_badge_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
		security_badge_label.show()
	elif is_weakened_race:
		security_badge_label.text = Localization.t("battle_weakened_badge", "▼ DESESTABILIZADOS (-50% ATRIBUTOS) ▼")
		security_badge_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.8))
		security_badge_label.show()
	else:
		security_badge_label.hide()

	enemy_count_label = Label.new()
	enemy_count_label.position = Vector2(center_x - 250, label_y)
	enemy_count_label.size = Vector2(500, 22)
	enemy_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_count_label.add_theme_font_override("font", font_ui)
	enemy_count_label.add_theme_font_size_override("font_size", 17)
	enemy_count_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if (is_current_boss or is_master_boss) else Color(1.0, 0.85, 0.2))
	enemy_count_label.add_theme_constant_override("outline_size", 4)
	enemy_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	battle_ui.add_child(enemy_count_label)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(center_x - 140, hp_bar_y)
	enemy_hp_bar.size = Vector2(280, 16)
	enemy_hp_bar.max_value = horde_units.size() * enemy_unit_max_hp
	enemy_hp_bar.value = enemy_hp_bar.max_value
	battle_ui.add_child(enemy_hp_bar)

	enemy_shield_bar = ProgressBar.new()
	enemy_shield_bar.position = enemy_hp_bar.position
	enemy_shield_bar.size = enemy_hp_bar.size
	enemy_shield_bar.show_percentage = false
	enemy_shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var enemy_sh_fill = StyleBoxFlat.new()
	enemy_sh_fill.bg_color = Color(1.0, 0.9, 0.2, 0.85)
	enemy_sh_fill.corner_radius_top_left = 2
	enemy_sh_fill.corner_radius_top_right = 2
	enemy_sh_fill.corner_radius_bottom_right = 2
	enemy_sh_fill.corner_radius_bottom_left = 2
	enemy_shield_bar.add_theme_stylebox_override("fill", enemy_sh_fill)
	enemy_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_shield_bar.hide()
	battle_ui.add_child(enemy_shield_bar)

	log_label = Label.new()
	log_label.position = Vector2(20, 5)
	log_label.size = Vector2(panel_w - 40, 24)
	log_label.add_theme_font_override("font", font_ui)
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	log_label.add_theme_constant_override("outline_size", 2)
	log_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	combat_panel.add_child(log_label)

	menu_container = Control.new()
	menu_container.position = Vector2(20, 32)
	menu_container.size = Vector2(230, panel_height - 40)
	combat_panel.add_child(menu_container)

	main_action_menu = VBoxContainer.new()
	main_action_menu.size = Vector2(230, panel_height - 40)
	main_action_menu.add_theme_constant_override("separation", 4)
	menu_container.add_child(main_action_menu)
	main_action_menu.hide()

	main_buttons.clear()
	var main_actions = [
		Localization.t("battle_act_attack", "[1] Atacar Singular"),
		Localization.t("battle_act_skills", "[2] Habilidades"),
		Localization.t("battle_act_defend", "[3] Defender")
	]
	var action_keys = ["Atacar", "Habilidades", "Defender"]
	if not is_current_boss and not is_master_boss:
		main_actions.append(Localization.t("battle_act_flee", "[4] Fugir (Grupo)"))
		action_keys.append("Fugir")

	for i in range(main_actions.size()):
		var btn = Button.new()
		btn.text = main_actions[i]
		btn.custom_minimum_size = Vector2(230, 38)
		btn.add_theme_font_override("font", font_ui)
		btn.add_theme_font_size_override("font_size", 13)
		var act_id = action_keys[i]
		btn.pressed.connect(func(): _on_main_menu_selected(act_id))
		main_action_menu.add_child(btn)
		main_buttons.append(btn)

	skills_menu = VBoxContainer.new()
	skills_menu.size = Vector2(230, panel_height - 40)
	skills_menu.add_theme_constant_override("separation", 4)
	menu_container.add_child(skills_menu)
	skills_menu.hide()

	skill_buttons.clear()
	var skills = [
		Localization.t("battle_skill_aoe", "[1] Magia de Área (15 MP)"),
		Localization.t("battle_skill_heal_single", "[2] Curar Alvo Crítico (10 MP)"),
		Localization.t("battle_skill_heal_party", "[3] Habilidade Nv.5"),
		Localization.t("battle_skill_back", "[4] Voltar")
	]
	for i in range(skills.size()):
		var btn = Button.new()
		btn.text = skills[i]
		btn.custom_minimum_size = Vector2(230, 38)
		btn.add_theme_font_override("font", font_ui)
		btn.add_theme_font_size_override("font_size", 12)
		var skill_text = ["Magia Área", "Cura Alvo", "Habilidade Nv5", "Voltar"][i]
		btn.pressed.connect(func(): _on_skill_selected(skill_text))
		skills_menu.add_child(btn)
		skill_buttons.append(btn)

	party_hud_container = HBoxContainer.new()
	party_hud_container.position = Vector2(265, 25)
	party_hud_container.size = Vector2(panel_w - 285, panel_height - 30)
	party_hud_container.add_theme_constant_override("separation", 12)
	combat_panel.add_child(party_hud_container)

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

	var shield_fill = StyleBoxFlat.new()
	shield_fill.bg_color = Color(1.0, 0.9, 0.2, 0.85)
	shield_fill.corner_radius_top_left = 2
	shield_fill.corner_radius_top_right = 2
	shield_fill.corner_radius_bottom_right = 2
	shield_fill.corner_radius_bottom_left = 2

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

	var order = ["humano", "mutante", "alien", "robo"]
	for char_id in order:
		var member = party_system_ref.members[char_id]

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)

		var port_frame = Panel.new()
		port_frame.custom_minimum_size = Vector2(120, 120)
		port_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var pf_style = StyleBoxFlat.new()
		pf_style.bg_color = Color(0.02, 0.04, 0.08, 0.9)
		port_frame.add_theme_stylebox_override("panel", pf_style)
		vbox.add_child(port_frame)

		var port = TextureRect.new()
		port.position = Vector2.ZERO
		port.custom_minimum_size = Vector2(120, 120)
		port.size = Vector2(120, 120)
		port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port_frame.add_child(port)

		var border_overlay = Panel.new()
		border_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color(0, 0, 0, 0)
		border_style.draw_center = false
		border_overlay.add_theme_stylebox_override("panel", border_style)
		port_frame.add_child(border_overlay)

		portrait_nodes[char_id] = port
		portrait_frame_nodes[char_id] = port_frame
		portrait_border_overlays[char_id] = border_overlay

		var lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", font_ui)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		vbox.add_child(lbl)
		label_nodes[char_id] = lbl

		var hp_box = Control.new()
		hp_box.custom_minimum_size = Vector2(120, 14)
		vbox.add_child(hp_box)

		var hp_bar = ProgressBar.new()
		hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		hp_bar.show_percentage = false
		hp_bar.max_value = member.max_hp
		hp_bar.value = member.hp
		hp_bar.add_theme_stylebox_override("background", bar_bg_hp)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		hp_box.add_child(hp_bar)
		hp_bar_nodes[char_id] = hp_bar

		var shield_bar = ProgressBar.new()
		shield_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		shield_bar.show_percentage = false
		shield_bar.max_value = member.max_hp
		shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		shield_bar.add_theme_stylebox_override("fill", shield_fill)
		shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shield_bar.hide()
		hp_box.add_child(shield_bar)
		shield_bar_nodes[char_id] = shield_bar

		var hp_txt = Label.new()
		hp_txt.set_anchors_preset(Control.PRESET_FULL_RECT)
		hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_txt.add_theme_font_override("font", font_mono)
		hp_txt.add_theme_font_size_override("font_size", 10)
		hp_txt.add_theme_constant_override("outline_size", 2)
		hp_txt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		hp_box.add_child(hp_txt)
		hp_text_nodes[char_id] = hp_txt

		var mp_bar = ProgressBar.new()
		mp_bar.custom_minimum_size = Vector2(120, 12)
		mp_bar.show_percentage = false
		mp_bar.max_value = member.max_mp
		mp_bar.value = member.mp
		mp_bar.add_theme_stylebox_override("background", bar_bg_mp)
		mp_bar.add_theme_stylebox_override("fill", mp_fill)
		vbox.add_child(mp_bar)
		mp_bar_nodes[char_id] = mp_bar

		var mp_txt = Label.new()
		mp_txt.set_anchors_preset(Control.PRESET_FULL_RECT)
		mp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mp_txt.add_theme_font_override("font", font_mono)
		mp_txt.add_theme_font_size_override("font_size", 9)
		mp_txt.add_theme_constant_override("outline_size", 2)
		mp_txt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		mp_bar.add_child(mp_txt)
		mp_text_nodes[char_id] = mp_txt

		party_hud_container.add_child(vbox)

	cutin_container = Control.new()
	cutin_container.position = Vector2(0, 0)
	cutin_container.size = vp_size
	cutin_container.clip_contents = true
	cutin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_ui.add_child(cutin_container)

	cutin_sprite = TextureRect.new()
	cutin_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cutin_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	cutin_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutin_sprite.hide()
	cutin_container.add_child(cutin_sprite)

	update_battle_ui(true)

func _create_csouter_lens_ui(title_font: Font, mono_font: Font):
	csouter_lens_panel = Panel.new()
	csouter_lens_panel.position = Vector2(20, 20)
	csouter_lens_panel.size = Vector2(240, 90)

	var lens_style = StyleBoxFlat.new()
	lens_style.bg_color = Color(0.01, 0.10, 0.24, 0.65)
	lens_style.border_width_left = 2
	lens_style.border_width_top = 2
	lens_style.border_width_right = 2
	lens_style.border_width_bottom = 2
	lens_style.border_color = Color(0.0, 0.85, 1.0, 0.9)
	lens_style.corner_radius_top_left = 4
	lens_style.corner_radius_top_right = 4
	lens_style.corner_radius_bottom_right = 4
	lens_style.corner_radius_bottom_left = 4
	csouter_lens_panel.add_theme_stylebox_override("panel", lens_style)
	csouter_lens_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_ui.add_child(csouter_lens_panel)

	var term_font = FontManager.get_font("csouter")
	var title_lbl = Label.new()
	title_lbl.text = Localization.t("battle_csouter_title", "◈ C-SOUTER RADAR ◈")
	title_lbl.position = Vector2(10, 6)
	title_lbl.size = Vector2(220, 16)
	title_lbl.add_theme_font_override("font", term_font)
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9))
	csouter_lens_panel.add_child(title_lbl)

	var div = HSeparator.new()
	var div_s = StyleBoxLine.new()
	div_s.color = Color(0.0, 0.85, 1.0, 0.4)
	div.add_theme_stylebox_override("separator", div_s)
	div.position = Vector2(8, 24)
	div.size = Vector2(224, 2)
	csouter_lens_panel.add_child(div)

	csouter_pdl_label = Label.new()
	csouter_pdl_label.position = Vector2(10, 28)
	csouter_pdl_label.size = Vector2(220, 60)
	csouter_pdl_label.add_theme_font_override("font", term_font)
	csouter_pdl_label.add_theme_font_size_override("font_size", 12)
	csouter_pdl_label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0))
	csouter_lens_panel.add_child(csouter_pdl_label)

	_update_csouter_pdl_display()

func _update_csouter_pdl_display():
	if not csouter_pdl_label: return

	var total_hp = get_total_horde_hp()
	var horde_count = horde_units.size()
	var total_atk = horde_count * enemy_unit_atk
	var total_spd = horde_count * current_enemy_speed
	var pdl_total = total_hp + (total_atk * 2) + (total_spd * 3) + (enemy_shield * 2)

	if is_current_boss and not is_master_boss:
		pdl_total += 8000
	elif is_master_boss:
		pdl_total += 3500

	var enemy_display = get_formatted_enemy_name()
	var readout_fmt = Localization.t("battle_csouter_readout", "ALVO: %s\nUNIDADES: %d\nPDL TOTAL: [ %d ]")
	csouter_pdl_label.text = readout_fmt % [enemy_display, horde_count, pdl_total]

func load_enemy_texture(base_id: String) -> Texture2D:
	if base_id == "enemy_alien_chest":
		var chest_t = load_texture_safe("prop_chest_closed")
		if not chest_t: chest_t = load_texture_safe("prop_chest_closed")
		if chest_t: return chest_t

	var candidates = [base_id]
	if base_id == "enemy_guardian": candidates.append("enemy_guardian")
	elif base_id == "enemy_guardian": candidates.insert(0, "enemy_guardian")
	elif base_id == "enemy_queen": candidates.append("enemy_queen")
	elif base_id == "enemy_queen": candidates.insert(0, "enemy_queen")
	elif base_id == "enemy_master_drone": candidates.append("enemy_master_drone")
	elif base_id == "enemy_master_mutant": candidates.append("enemy_master_mutant")
	elif base_id == "enemy_master_android": candidates.append("enemy_master_android")
	elif base_id == "enemy_master_alien": candidates.append("enemy_master_alien")
	elif base_id == "enemy_master_drone": candidates.append("enemy_master_drone")
	elif base_id == "enemy_master_mutant": candidates.append("enemy_master_mutant")
	elif base_id == "enemy_master_android": candidates.append("enemy_master_android")
	elif base_id == "enemy_master_alien": candidates.append("enemy_master_alien")

	for cid in candidates:
		var t = load_texture_safe(cid)
		if t: return t
	return null

func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	for ext in extensions:
		var path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return load(path)
	return null

func _unhandled_input(event):
	if not is_in_battle or battle_state != State.SELECT_ACTION: return

	if event is InputEventJoypadButton and event.pressed:
		if audio_manager: audio_manager.play_sfx("sfx_menu_move")
		if event.button_index == JOY_BUTTON_B:
			if active_menu_type == "skill":
				_on_skill_selected("Voltar")
				get_viewport().set_input_as_handled()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		if audio_manager: audio_manager.play_sfx("sfx_menu_move")
		if active_menu_type == "main":
			if event.keycode == KEY_1: _on_main_menu_selected("Atacar")
			elif event.keycode == KEY_2: _on_main_menu_selected("Habilidades")
			elif event.keycode == KEY_3: _on_main_menu_selected("Defender")
			elif event.keycode == KEY_4 and not is_current_boss and not is_master_boss: _on_main_menu_selected("Fugir")
		elif active_menu_type == "skill":
			if event.keycode == KEY_1: _on_skill_selected("Magia Área")
			elif event.keycode == KEY_2: _on_skill_selected("Cura Alvo")
			elif event.keycode == KEY_3:
				var actor = turn_queue[current_acting_index].entity
				if actor.level >= 5: _on_skill_selected("Habilidade Nv5")
				else:
					if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
					var lang = Localization.current_language
					log_message("Skill locked! Requires Level 5." if lang == "en" else ("スキルロック中！ レベル5が必要です。" if lang == "ja" else "Habilidade bloqueada! Requer Nível 5."))
			elif event.keycode == KEY_4 or event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE: _on_skill_selected("Voltar")

func log_message(msg: String):
	if log_label: log_label.text = msg

func get_total_horde_hp() -> int:
	var total = 0
	for hp in horde_units: total += hp
	return total

func count_living_allies() -> int:
	var count = 0
	for k in party_system_ref.members.keys():
		if k == "mutante" and party_system_ref.is_kira_away: continue
		if party_system_ref.members[k].hp > 0: count += 1
	return count

func apply_damage_to_horde_front(dmg: int) -> int:
	var effective_dmg = dmg
	if enemy_shield > 0:
		if enemy_shield >= effective_dmg:
			enemy_shield -= effective_dmg
			effective_dmg = 0
		else:
			effective_dmg -= enemy_shield
			enemy_shield = 0

	if effective_dmg > 0 and not horde_units.is_empty():
		if effective_dmg >= horde_units[0]:
			horde_units.pop_front()
			total_enemies_killed_this_fight += 1
			_record_race_kill(current_enemy_id)
		else:
			horde_units[0] -= effective_dmg

	update_enemy_hp_bar_direct()
	return effective_dmg

func _record_race_kill(e_id: String) -> void:
	match e_id:
		"enemy_drone": race_kills["drone"] = race_kills.get("drone", 0) + 1
		"enemy_mutant_beast": race_kills["mutante"] = race_kills.get("mutante", 0) + 1
		"enemy_corrupted_android": race_kills["androide"] = race_kills.get("androide", 0) + 1
		"enemy_alien_scout": race_kills["alien"] = race_kills.get("alien", 0) + 1

func update_enemy_hp_bar_direct():
	if enemy_hp_bar:
		var t_ehp = create_tween()
		t_ehp.tween_property(enemy_hp_bar, "value", float(get_total_horde_hp()), HP_BAR_DRAIN_DURATION)

	if enemy_shield_bar:
		if enemy_shield > 0:
			enemy_shield_bar.show()
			enemy_shield_bar.max_value = enemy_max_shield
			var t_esh = create_tween()
			t_esh.tween_property(enemy_shield_bar, "value", float(enemy_shield), HP_BAR_DRAIN_DURATION)
		else:
			enemy_shield_bar.hide()

	_update_csouter_pdl_display()

func update_single_ally_hp(char_id: String):
	if not party_system_ref.members.has(char_id): return
	var member = party_system_ref.members[char_id]
	var target_hp = max(0, member.hp)

	if hp_bar_nodes.has(char_id) and is_instance_valid(hp_bar_nodes[char_id]):
		var hp_b = hp_bar_nodes[char_id]
		hp_b.max_value = member.max_hp
		var t_hp = create_tween()
		t_hp.tween_property(hp_b, "value", float(target_hp), HP_BAR_DRAIN_DURATION)

	if shield_bar_nodes.has(char_id) and is_instance_valid(shield_bar_nodes[char_id]):
		var s_bar = shield_bar_nodes[char_id]
		s_bar.max_value = member.max_hp
		if member.shield > 0 and member.hp > 0:
			s_bar.show()
			s_bar.value = clamp(member.shield, 0, member.max_hp)
		else:
			s_bar.hide()

	if hp_text_nodes.has(char_id) and is_instance_valid(hp_text_nodes[char_id]):
		var hp_txt = hp_text_nodes[char_id]
		if member.shield > 0:
			hp_txt.text = "%d / %d [+%d]" % [target_hp, member.max_hp, member.shield]
		else:
			hp_txt.text = "%d / %d" % [target_hp, member.max_hp]

func update_single_ally_mp(char_id: String):
	if not party_system_ref.members.has(char_id): return
	var member = party_system_ref.members[char_id]

	if mp_bar_nodes.has(char_id) and is_instance_valid(mp_bar_nodes[char_id]):
		var mp_b = mp_bar_nodes[char_id]
		mp_b.max_value = member.max_mp
		var t_mp = create_tween()
		t_mp.tween_property(mp_b, "value", float(max(0, member.mp)), 0.20)

	if mp_text_nodes.has(char_id) and is_instance_valid(mp_text_nodes[char_id]):
		mp_text_nodes[char_id].text = "%d / %d" % [max(0, member.mp), member.max_mp]

func update_battle_ui(update_horde_sprites: bool = true):
	var order = ["humano", "mutante", "alien", "robo"]
	for char_id in order:
		var member = party_system_ref.members[char_id]

		if label_nodes.has(char_id) and is_instance_valid(label_nodes[char_id]):
			var lbl = label_nodes[char_id]
			if char_id == "mutante" and party_system_ref.is_kira_away:
				lbl.text = "%s [%s]" % [member.name, Localization.t("party_status_away", "AUSENTE")]
				lbl.modulate = Color(1.0, 0.6, 0.2)
			elif member.hp <= 0:
				lbl.text = "%s [%s]" % [member.name, Localization.t("party_status_dead", "INCAPACITADA")]
				lbl.modulate = Color(1, 0.2, 0.2)
			else:
				var stun_icon = " 🌀" if stunned_allies.get(char_id, 0) > 0 else ""
				var taunt_icon = " 🛡️" if (char_id == "mutante" and is_kira_taunting) else ""
				lbl.text = "%s%s%s (Lv.%d)" % [member.name, stun_icon, taunt_icon, member.level]
				lbl.modulate = Color(0.7, 0.9, 1.0) if stunned_allies.get(char_id, 0) > 0 else Color(1, 1, 1)

		update_single_ally_hp(char_id)
		update_single_ally_mp(char_id)

		if portrait_nodes.has(char_id) and is_instance_valid(portrait_nodes[char_id]):
			var port = portrait_nodes[char_id]
			if is_ally_animating_hit.get(char_id, false): continue

			var is_defending_perfect = defending_members.has(char_id) and party_system_ref.has_perfect_defense_buff and (count_living_allies() == 4) and not is_current_boss and not party_system_ref.is_kira_away

			if char_id == "mutante" and party_system_ref.is_kira_away:
				port.modulate = Color(0.35, 0.35, 0.40)
				port.texture = get_portrait_tex(char_id, "normal")
			elif is_current_boss and not is_master_boss and char_id == "robo":
				port.texture = get_portrait_tex("robo", "closed")
				port.modulate = Color(0.28, 0.28, 0.32)
			elif member.hp <= 0:
				if not allies_dead_at_start.get(char_id, false):
					port.texture = get_portrait_tex(char_id, "damaged")
					port.modulate = Color(0.7, 0.35, 0.35)
				else:
					port.texture = get_portrait_tex(char_id, "normal")
					port.modulate = Color(0.28, 0.28, 0.32)
			elif is_defending_perfect:
				port.modulate = Color(0.2, 1.8, 0.6)
			else:
				port.modulate = Color(1, 1, 1)
				port.texture = get_portrait_tex(char_id, "normal")

	var enemy_tex = load_enemy_texture(current_enemy_id)
	if enemy_tex and not (is_alien_chest and horde_units.is_empty()):
		if enemy_sprite: enemy_sprite.texture = enemy_tex
		if enemy_sprite_left: enemy_sprite_left.texture = enemy_tex
		if enemy_sprite_right: enemy_sprite_right.texture = enemy_tex
		if enemy_shadow_left: enemy_shadow_left.texture = enemy_tex
		if enemy_shadow_right: enemy_shadow_right.texture = enemy_tex

	if update_horde_sprites and battle_state != State.END:
		var horde_count = horde_units.size()
		if is_current_boss or is_master_boss or is_alien_chest or horde_count <= 1:
			if enemy_sprite_left: enemy_sprite_left.hide(); enemy_shadow_left.hide()
			if enemy_sprite_right: enemy_sprite_right.hide(); enemy_shadow_right.hide()
		elif horde_count == 2:
			if enemy_sprite_left: enemy_sprite_left.hide(); enemy_shadow_left.hide()
			if enemy_sprite_right: enemy_sprite_right.show(); enemy_shadow_right.show()
		else:
			if enemy_sprite_left: enemy_sprite_left.show(); enemy_shadow_left.show()
			if enemy_sprite_right: enemy_sprite_right.show(); enemy_shadow_right.show()

	if enemy_count_label:
		var lang = Localization.current_language
		var enemy_name = get_formatted_enemy_name()
		var taunt_mark = " 💢" if is_kira_taunting else ""
		var status_neutralized = " [NEUTRALIZADO]" if lang == "pt" else (" [NEUTRALIZED]" if lang == "en" else " [撃破]")
		var status_opened = " [ABERTO]" if lang == "pt" else (" [OPENED]" if lang == "en" else " [開封済み]")

		var shield_tag = ""
		if enemy_shield > 0:
			shield_tag = " 🛡️ [ESCUDO: %d]" % enemy_shield if lang == "pt" else (" 🛡️ [SHIELD: %d]" % enemy_shield if lang == "en" else " 🛡️ [シールド: %d]" % enemy_shield)

		if is_current_boss and not is_master_boss:
			var boss_title = "%s, O Demônio Cósmico" % enemy_name if lang == "pt" else ("%s, the Cosmic Demon" % enemy_name if lang == "en" else "ケン・シャローム (宇宙の悪魔)")
			enemy_count_label.text = (boss_title + status_neutralized) if horde_units.is_empty() else boss_title + taunt_mark + shield_tag
		elif is_master_boss:
			enemy_count_label.text = (enemy_name + status_neutralized) if horde_units.is_empty() else enemy_name + taunt_mark + shield_tag
		elif is_alien_chest:
			enemy_count_label.text = (enemy_name + status_opened) if horde_units.is_empty() else enemy_name
		elif horde_units.is_empty():
			enemy_count_label.text = enemy_name + status_neutralized
		else:
			var prefix = ""
			if is_security_mode:
				prefix = "[CONTAINMENT] " if lang == "en" else ("[粛清] " if lang == "ja" else "[CONTENÇÃO] ")
			enemy_count_label.text = "%s%s (x%d)%s" % [prefix, enemy_name, horde_units.size(), taunt_mark]

	update_enemy_hp_bar_direct()

func get_formatted_enemy_name() -> String:
	var lang = Localization.current_language
	if is_current_boss and not is_master_boss:
		if lang == "ja": return "ケン・シャローム"
		return "Khen-Shalom"
	elif is_master_boss:
		match active_master_type:
			"drone":
				return "Victor-Prime, Mestre dos Drones" if lang == "pt" else ("Victor-Prime, Drone Master" if lang == "en" else "ヴィクター・プライム (ドローンの主)")
			"mutante":
				return "Dr. Ghorgorath, Mestre dos Mutantes" if lang == "pt" else ("Dr. Ghorgorath, Mutant Master" if lang == "en" else "Dr.ゴルゴラス (ミュータントの主)")
			"androide":
				return "Valeria X-9, Mestra dos Androides" if lang == "pt" else ("Valeria X-9, Android Master" if lang == "en" else "ヴァレリア X-9 (アンドロイドの主)")
			"alien":
				return "Xylox, Mestre dos Aliens" if lang == "pt" else ("Xylox, Alien Master" if lang == "en" else "サイロックス (エイリアンの主)")
			_:
				return "Mestre Supremo"
	elif is_alien_chest or current_enemy_id == "enemy_alien_chest":
		if lang == "ja": return "エイリアンチェスト"
		elif lang == "en": return "Alien Chest"
		return "Alien Baú"
	return current_enemy_id.replace("enemy_", "").replace("boss_", "").replace("_", " ").capitalize()

func start_turn_selection():
	if battle_state == State.END: return

	turn_queue.clear()
	pending_actions.clear()
	defending_members.clear()
	stun_applied_this_round.clear()
	is_kira_taunting = false    # <-- Garante que não vaza de um turno para o outro
	taunt_remaining_hits = 0 

	for key in ["humano", "mutante", "alien", "robo"]:
		if key == "mutante" and party_system_ref.is_kira_away: continue
		var m = party_system_ref.members[key]
		if m.hp > 0:
			turn_queue.append({"id": key, "entity": m, "is_enemy": false})

	turn_queue.append({"id": current_enemy_id, "speed": current_enemy_speed, "is_enemy": true})

	current_acting_index = 0
	battle_state = State.SELECT_ACTION
	prompt_next_ally_action()

func update_turn_visual_indicators(active_char_id: String):
	if active_turn_tween and active_turn_tween.is_valid():
		active_turn_tween.kill()
		active_turn_tween = null

	var chars = ["humano", "mutante", "alien", "robo"]
	for c in chars:
		if c == "mutante" and party_system_ref.is_kira_away:
			if portrait_nodes.has(c) and is_instance_valid(portrait_nodes[c]):
				portrait_nodes[c].modulate = Color(0.35, 0.35, 0.4)
			continue

		if portrait_nodes.has(c) and is_instance_valid(portrait_nodes[c]):
			if not is_ally_animating_hit.get(c, false) and party_system_ref.members[c].hp > 0:
				portrait_nodes[c].modulate = Color(1, 1, 1)

		if portrait_border_overlays.has(c) and is_instance_valid(portrait_border_overlays[c]):
			var border_style = StyleBoxFlat.new()
			border_style.bg_color = Color(0, 0, 0, 0)
			border_style.draw_center = false
			portrait_border_overlays[c].add_theme_stylebox_override("panel", border_style)

	if modo_visual_turno == 0 or active_char_id == "" or not portrait_nodes.has(active_char_id):
		return

	if modo_visual_turno == 1:
		var port = portrait_nodes[active_char_id]
		port.modulate = Color(1.20, 1.20, 1.25)
		active_turn_tween = create_tween().set_loops()
		active_turn_tween.tween_property(port, "modulate", Color(1.65, 1.65, 1.75), 0.32).set_trans(Tween.TRANS_SINE)
		active_turn_tween.tween_property(port, "modulate", Color(1.20, 1.20, 1.25), 0.32).set_trans(Tween.TRANS_SINE)
	elif modo_visual_turno == 3:
		var port = portrait_nodes[active_char_id]
		port.modulate = Color(1.40, 1.40, 1.50)
	elif modo_visual_turno == 2:
		if portrait_border_overlays.has(active_char_id):
			var pf_style = StyleBoxFlat.new()
			pf_style.bg_color = Color(0, 0, 0, 0)
			pf_style.draw_center = false
			pf_style.border_width_left = 2
			pf_style.border_width_top = 2
			pf_style.border_width_right = 2
			pf_style.border_width_bottom = 2
			pf_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
			portrait_border_overlays[active_char_id].add_theme_stylebox_override("panel", pf_style)

func prompt_next_ally_action():
	if battle_state == State.END: return

	main_action_menu.hide()
	skills_menu.hide()

	while current_acting_index < turn_queue.size() and turn_queue[current_acting_index].is_enemy:
		current_acting_index += 1

	if current_acting_index >= turn_queue.size():
		resolve_turn_actions()
		return

	var actor = turn_queue[current_acting_index]

	if stunned_allies.get(actor.id, 0) > 0:
		pending_actions.append({"actor": actor, "action": "Atordoado", "speed": actor.entity.speed})
		current_acting_index += 1
		prompt_next_ally_action()
		return
	update_turn_visual_indicators(actor.id)

	var localized_role = Localization.t("role_" + actor.id, actor.entity.role)
	var lang = Localization.current_language
	if lang == "en":
		log_message("Action for %s (%s). Select:" % [actor.entity.name.to_upper(), localized_role])
	elif lang == "ja":
		log_message("%s (%s) の行動順。選択してください:" % [actor.entity.name.to_upper(), localized_role])
	else:
		log_message("Ação de %s (%s). Selecione:" % [actor.entity.name.to_upper(), localized_role])

	if actor.id == "mutante":
		passive_info_label.text = "✦ PASSIVE [Kira]: Dual Claws (Attacks split damage into 2 strikes)" if lang == "en" else ("✦ パッシブ [キラ]: 双爪 (攻撃ダメージを2回攻撃に分割)" if lang == "ja" else "✦ PASSIVA [Kira]: Garras Duplas (Ataque divide o dano em 2 golpes)")
		passive_card_panel.show()
	elif actor.id == "robo":
		passive_info_label.text = "✦ PASSIVE [Unit-7]: Overheal (Full HP heals generate Shields)" if lang == "en" else ("✦ パッシブ [Unit-7]: オーバーヒール (HP満タン時の回復がシールド化)" if lang == "ja" else "✦ PASSIVA [Unit-7]: Sobrecura (Curas em vida cheia geram Escudo)")
		passive_card_panel.show()
	else:
		passive_card_panel.hide()

	var can_perfect_defend = party_system_ref.has_perfect_defense_buff and (count_living_allies() == 4) and not is_current_boss and not party_system_ref.is_kira_away
	if main_buttons.size() >= 3:
		if can_perfect_defend:
			main_buttons[2].text = Localization.t("battle_act_defend_buff", "[3] ★ Defender (Impenetrável)")
			main_buttons[2].add_theme_color_override("font_color", Color(0.0, 1.0, 0.4))
		else:
			main_buttons[2].text = Localization.t("battle_act_defend", "[3] Defender")
			main_buttons[2].remove_theme_color_override("font_color")

	active_menu_type = "main"
	main_action_menu.show()
	if main_buttons.size() > 0: main_buttons[0].grab_focus()

func _on_main_menu_selected(action: String):
	if battle_state != State.SELECT_ACTION: return
	if audio_manager: audio_manager.play_sfx("sfx_menu_select")

	if action == "Habilidades":
		active_menu_type = "skill"
		main_action_menu.hide()

		var actor_entry = turn_queue[current_acting_index]
		var actor = actor_entry.entity
		var actor_id = actor_entry.id

		if skill_buttons.size() >= 3:
			skill_buttons[0].text = Localization.t("battle_skill_aoe", "[1] Magia de Área (15 MP)")
			skill_buttons[1].text = Localization.t("battle_skill_heal_single", "[2] Curar Alvo Crítico (10 MP)")
			if skill_buttons.size() >= 4:
				skill_buttons[3].text = Localization.t("battle_skill_back", "[4] Voltar")

			var skill3_name = ""
			var skill3_key = ""
			match actor_id:
				"humano":
					skill3_name = Localization.t("battle_skill_drive", "[3] Drive (25 MP)")
					skill3_key = "Drive"
				"mutante":
					skill3_name = Localization.t("battle_skill_taunt", "[3] Provocar (20 MP)")
					skill3_key = "Provocar"
				"alien":
					skill3_name = Localization.t("battle_skill_obscure", "[3] Obscure (25 MP)")
					skill3_key = "Obscure"
				"robo":
					skill3_name = Localization.t("battle_skill_heal_party", "[3] Cura em Grupo (20 MP)")
					skill3_key = "Cura Área"

			if actor.level < 5:
				skill_buttons[2].disabled = true
				var locked_fmt = Localization.t("battle_skill_locked_fmt", "[3] %s [Bloqueado Lv.5]")
				skill_buttons[2].text = locked_fmt % skill3_key
				skill_buttons[2].modulate = Color(0.6, 0.6, 0.6, 0.5)
			else:
				skill_buttons[2].disabled = false
				skill_buttons[2].text = skill3_name
				skill_buttons[2].modulate = Color(1, 1, 1, 1)

		skills_menu.show()
		if skill_buttons.size() > 0: skill_buttons[0].grab_focus()
	elif action == "Fugir":
		attempt_group_flee()
	else:
		register_action(action)

func attempt_group_flee():
	active_menu_type = "none"
	main_action_menu.hide()
	skills_menu.hide()
	passive_card_panel.hide()
	update_turn_visual_indicators("")

	if is_current_boss or is_master_boss: return

	var leader = party_system_ref.members["humano"]
	var flee_chance = 0.35 + (leader.level * 0.05) - (current_floor_num * 0.04)
	if is_security_mode: flee_chance -= 0.15

	# Aplica penalidade se houver inimigos com rifles (Alien Scout / Mecha)
	flee_chance -= enemy_flee_penalty
	flee_chance = clamp(flee_chance, 0.05, 0.85)

	var lang = Localization.current_language
	if randf() < flee_chance:
		if audio_manager: audio_manager.play_sfx("sfx_flee")
		log_message("The squad successfully retreated into the corridors!" if lang == "en" else ("部隊は通路へと無事に撤退した！" if lang == "ja" else "A equipe recuou com sucesso para os corredores!"))
		get_tree().create_timer(1.2).timeout.connect(func(): end_battle(false))
	else:
		if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
		if enemy_flee_penalty > 0.0:
			log_message("Enemy rifle fire pinned down your squad!" if lang == "en" else ("敵狙撃手の射撃で退路を塞がれた！" if lang == "ja" else "O fogo de precisão dos rifles inimigos impediu a fuga!"))
		else:
			log_message("The horde blocked the escape! Enemy ambush imminent!" if lang == "en" else ("敵群に退路を阻まれた！ 待ち伏せ攻撃を受ける！" if lang == "ja" else "A horda bloqueou a retirada! Emboscada inimiga iminente!"))
		pending_actions.clear()
		battle_state = State.RESOLVE_ACTIONS
		pending_actions.append({"actor": {"id": current_enemy_id, "is_enemy": true}, "action": "Ataque Horda", "speed": 999})
		get_tree().create_timer(1.2).timeout.connect(execute_next_action)

func _on_skill_selected(skill: String):
	if battle_state != State.SELECT_ACTION: return

	if skill == "Voltar":
		if audio_manager: audio_manager.play_sfx("sfx_flee")
		active_menu_type = "main"
		skills_menu.hide()
		main_action_menu.show()
		if main_buttons.size() > 0: main_buttons[0].grab_focus()
		return

	var actor_entry = turn_queue[current_acting_index]
	var actor = actor_entry.entity
	var actor_id = actor_entry.id

	var chosen_action = skill
	var cost = 15
	if skill == "Cura Alvo":
		cost = 10
	elif skill == "Habilidade Nv5":
		match actor_id:
			"humano":
				chosen_action = "Drive"
				cost = 25
			"mutante":
				chosen_action = "Provocar"
				cost = 20
			"alien":
				chosen_action = "Obscure"
				cost = 25
			"robo":
				chosen_action = "Cura Área"
				cost = 20

	if actor.mp < cost:
		if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")
		var lang = Localization.current_language
		log_message("Insufficient MP for %s! (Requires %d MP)" % [chosen_action, cost] if lang == "en" else ("%s に必要なMPが不足しています！ (%d MPが必要)" % [chosen_action, cost] if lang == "ja" else "MP Insuficiente para %s! (Requer %d MP)" % [chosen_action, cost]))
		return

	if audio_manager: audio_manager.play_sfx("sfx_menu_select")
	register_action(chosen_action)

func register_action(action_name: String):
	active_menu_type = "none"
	main_action_menu.hide()
	skills_menu.hide()
	passive_card_panel.hide()
	update_turn_visual_indicators("")

	var actor = turn_queue[current_acting_index]
	pending_actions.append({"actor": actor, "action": action_name, "speed": actor.entity.speed})

	current_acting_index += 1
	prompt_next_ally_action()

func resolve_turn_actions():
	battle_state = State.RESOLVE_ACTIONS

	for act in pending_actions:
		if not act.actor.is_enemy:
			var cost = 0
			match act.action:
				"Magia Área": cost = 15
				"Cura Alvo": cost = 10
				"Cura Área": cost = 20
				"Drive": cost = 25
				"Provocar": cost = 20
				"Obscure": cost = 25

			if cost > 0:
				act.actor.entity.mp = max(0, act.actor.entity.mp - cost)
				update_single_ally_mp(act.actor.id)

	defending_members.clear()
	for act in pending_actions:
		if act.action == "Defender":
			defending_members[act.actor.id] = true
			act.speed = 99999
		elif act.action == "Provocar": # <-- ADICIONE AQUI
			act.speed = 99998

	pending_actions.append({"actor": {"id": current_enemy_id, "is_enemy": true}, "action": "Ataque Horda", "speed": current_enemy_speed})
	pending_actions.sort_custom(func(a, b): return a.speed > b.speed)

	execute_next_action()

func animate_enemy_hit(is_fatal: bool = false, is_aoe: bool = false, on_finished: Callable = Callable(), custom_color: Color = Color(2.5, 0.2, 0.2), custom_sparks_color: Color = Color(1.0, 0.3, 0.1)):
	if audio_manager: audio_manager.play_sfx("sfx_hit")
	is_animating_hit = true

	var spark_pos = base_enemy_pos + Vector2(75, 75) if is_alien_chest else base_enemy_pos + Vector2(150, 150)
	spawn_hit_sparks(spark_pos, custom_sparks_color)

	if enemy_hit_tween and enemy_hit_tween.is_valid():
		enemy_hit_tween.kill()

	var shake_amplitude = 26.0 if tremor_a_mais else 14.0
	enemy_hit_tween = create_tween()
	enemy_hit_tween.tween_property(enemy_sprite, "modulate", custom_color, 0.05)
	enemy_hit_tween.tween_property(enemy_sprite, "position", base_enemy_pos + Vector2(shake_amplitude, 0), 0.04)
	enemy_hit_tween.tween_property(enemy_sprite, "position", base_enemy_pos + Vector2(-shake_amplitude, 0), 0.04)
	enemy_hit_tween.tween_property(enemy_sprite, "position", base_enemy_pos + Vector2(shake_amplitude * 0.5, 0), 0.04)
	enemy_hit_tween.tween_property(enemy_sprite, "position", base_enemy_pos, 0.04)

	var final_color = Color(1, 1, 1)
	if is_fatal and not is_alien_chest:
		final_color = Color(0.25, 0.25, 0.25)
	elif is_security_mode or is_current_boss or is_master_boss:
		final_color = Color(1.2, 0.8, 0.8)

	enemy_hit_tween.tween_property(enemy_sprite, "modulate", final_color, 0.15)

	if is_aoe:
		var targets = []
		var base_positions = []
		var final_side_color = Color(0.25, 0.25, 0.25) if is_fatal else SIDE_ENEMY_MODULATE
		if enemy_sprite_left and enemy_sprite_left.visible:
			targets.append(enemy_sprite_left)
			base_positions.append(base_enemy_pos + SIDE_ENEMY_OFFSET_L)
			spawn_hit_sparks(base_enemy_pos + SIDE_ENEMY_OFFSET_L + (SIDE_ENEMY_SIZE / 2.0), custom_sparks_color)
		if enemy_sprite_right and enemy_sprite_right.visible:
			targets.append(enemy_sprite_right)
			base_positions.append(base_enemy_pos + SIDE_ENEMY_OFFSET_R)
			spawn_hit_sparks(base_enemy_pos + SIDE_ENEMY_OFFSET_R + (SIDE_ENEMY_SIZE / 2.0), custom_sparks_color)

		for i in range(targets.size()):
			var tg = targets[i]
			var b_pos = base_positions[i]
			var sub_tw = create_tween()
			sub_tw.tween_property(tg, "modulate", custom_color, 0.05)
			sub_tw.tween_property(tg, "position", b_pos + Vector2(shake_amplitude * 0.7, 0), 0.04)
			sub_tw.tween_property(tg, "position", b_pos + Vector2(-shake_amplitude * 0.7, 0), 0.04)
			sub_tw.tween_property(tg, "position", b_pos + Vector2(shake_amplitude * 0.35, 0), 0.04)
			sub_tw.tween_property(tg, "position", b_pos, 0.04)
			sub_tw.tween_property(tg, "modulate", final_side_color, 0.15)

	enemy_hit_tween.finished.connect(func():
		is_animating_hit = false
		if on_finished.is_valid(): on_finished.call()
	)

func spawn_hit_sparks(pos: Vector2, color: Color):
	var sparks = CPUParticles2D.new()
	sparks.position = pos
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 16
	sparks.lifetime = 0.35
	sparks.explosiveness = 0.9
	sparks.spread = 180.0
	sparks.initial_velocity_min = 70.0
	sparks.initial_velocity_max = 160.0
	sparks.scale_amount_min = 2.5
	sparks.scale_amount_max = 5.0
	sparks.color = color
	battle_ui.add_child(sparks)
	get_tree().create_timer(0.5).timeout.connect(sparks.queue_free)

func animate_ally_hit(char_id: String, custom_modulate: Color = Color(2.5, 0.2, 0.2)):
	if not portrait_nodes.has(char_id) or not is_instance_valid(portrait_nodes[char_id]): return
	var port = portrait_nodes[char_id]
	is_ally_animating_hit[char_id] = true
	port.texture = get_portrait_tex(char_id, "damaged")

	var shake_val = 10.0 if (tremor_a_mais and is_current_boss and not is_master_boss) else 6.0
	var tween = create_tween()
	tween.tween_property(port, "modulate", custom_modulate, 0.05)
	tween.tween_property(port, "position:y", port.position.y + shake_val, 0.05)
	tween.tween_property(port, "position:y", port.position.y - shake_val, 0.05)
	tween.tween_property(port, "position:y", port.position.y, 0.05)

	var final_color = Color(1, 1, 1) if party_system_ref.members[char_id].hp > 0 else Color(0.7, 0.35, 0.35)
	tween.tween_property(port, "modulate", final_color, 0.35)

	tween.finished.connect(func():
		is_ally_animating_hit[char_id] = false
		if portrait_nodes.has(char_id) and is_instance_valid(portrait_nodes[char_id]):
			if party_system_ref.members[char_id].hp > 0:
				port.texture = get_portrait_tex(char_id, "normal")
			else:
				if is_current_boss and not is_master_boss and char_id == "robo":
					port.texture = get_portrait_tex("robo", "closed")
				elif not allies_dead_at_start.get(char_id, false):
					port.texture = get_portrait_tex(char_id, "damaged")
				else:
					port.texture = get_portrait_tex(char_id, "normal")
	)

func animate_ally_heal(char_id: String):
	if not portrait_nodes.has(char_id) or not is_instance_valid(portrait_nodes[char_id]): return
	var port = portrait_nodes[char_id]
	port.texture = get_portrait_tex(char_id, "normal")

	var tween = create_tween()
	tween.tween_property(port, "modulate", Color(0.2, 2.2, 2.5), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(port, "modulate", Color(1, 1, 1), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func animate_enemy_lunge(callback: Callable):
	var lunge_dist = 45.0 if (is_current_boss and not is_master_boss and golpe_impactante) else 35.0
	var lunge_time = 0.07 if (is_current_boss and not is_master_boss and golpe_impactante) else 0.12
	var return_time = 0.14 if (is_current_boss and not is_master_boss and golpe_impactante) else 0.18

	var tween = create_tween()
	tween.tween_property(enemy_sprite, "position:y", base_enemy_pos.y + lunge_dist, lunge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if enemy_shadow:
		var st = create_tween()
		var shadow_offset_to_use = (ENEMY_SHADOW_OFFSET * 2.0) if is_alien_chest else ENEMY_SHADOW_OFFSET
		st.tween_property(enemy_shadow, "position:y", base_enemy_pos.y + shadow_offset_to_use.y + lunge_dist, lunge_time)
		st.tween_property(enemy_shadow, "position:y", base_enemy_pos.y + shadow_offset_to_use.y, return_time)

	if enemy_sprite_left and enemy_sprite_left.visible:
		var t_l = create_tween()
		t_l.tween_property(enemy_sprite_left, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_L.y + lunge_dist, lunge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_l.tween_property(enemy_sprite_left, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_L.y, return_time)
		if enemy_shadow_left:
			var st_l = create_tween()
			st_l.tween_property(enemy_shadow_left, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_L.y + ENEMY_SHADOW_OFFSET.y + lunge_dist, lunge_time)
			st_l.tween_property(enemy_shadow_left, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_L.y, return_time)

	if enemy_sprite_right and enemy_sprite_right.visible:
		var t_r = create_tween()
		t_r.tween_property(enemy_sprite_right, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_R.y + lunge_dist, lunge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_r.tween_property(enemy_sprite_right, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_R.y, return_time)
		if enemy_shadow_right:
			var st_r = create_tween()
			st_r.tween_property(enemy_shadow_right, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_R.y + ENEMY_SHADOW_OFFSET.y + lunge_dist, lunge_time)
			st_r.tween_property(enemy_shadow_right, "position:y", base_enemy_pos.y + SIDE_ENEMY_OFFSET_R.y, return_time)

	tween.tween_property(enemy_sprite, "position:y", base_enemy_pos.y, return_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(callback)

func execute_next_action():
	if battle_state == State.END: return

	if pending_actions.is_empty():
		start_turn_selection()
		return

	var act = pending_actions.pop_front()
	var is_enemy = act.actor.is_enemy
	var lang = Localization.current_language

	if is_enemy:
		if horde_units.is_empty():
			execute_next_action()
			return

		if is_current_boss and not is_master_boss:
			log_message("Khen-Shalom desfere um golpe de plasma temporal fulminante!" if lang == "pt" else ("Khen-Shalom unleashes a devastating temporal plasma strike!" if lang == "en" else "ケン・シャロームが猛烈な時間プラズマの一撃を放つ！"))
		elif is_master_boss:
			match active_master_type:
				"drone": log_message("Victor-Prime comanda seus enxames em bombardeio total!" if lang == "pt" else ("Victor-Prime commands all drone swarms in a full barrage!" if lang == "en" else "ヴィクター・プライムが全機に一斉爆撃を命令！"))
				"mutante": log_message("Dr. Ghorgorath desfere um golpe esmagador seguido de presas venenosas!" if lang == "pt" else ("Dr. Ghorgorath unleashes a crushing blow followed by venomous fangs!" if lang == "en" else "Dr.ゴルゴラスが粉砕撃と毒牙の連撃を放つ！"))
				"androide": log_message("Valeria X-9 corta em sequência veloz com suas lâminas de energia!" if lang == "pt" else ("Valeria X-9 slashes in swift sequence with dual energy blades!" if lang == "en" else "ヴァレリア X-9 が双刃エネルギーブレードで連撃！"))
				"alien": log_message("Xylox chicoteia os 8 tentáculos atingindo todo o esquadrão!" if lang == "pt" else ("Xylox lashes all 8 tentacles across the squad!" if lang == "en" else "サイロックスが8本の触手で部隊全員を薙ぎ払う！"))
		elif is_alien_chest:
			log_message("Alien Chest bites swiftly with its sharp teeth!" if lang == "en" else ("エイリアンチェストが鋭い牙で素早く噛みついた！" if lang == "ja" else "O Alien Baú morde velozmente com suas presas afiadas!"))
		else:
			log_message("The enemy Horde advances with synchronized volleys!" if lang == "en" else ("敵群が一斉射撃を開始！" if lang == "ja" else "A Horda inimiga avança com disparos sincronizados!"))

		animate_enemy_lunge(func():
			if audio_manager: audio_manager.play_sfx("sfx_hit")

			var living_allies = []
			for k in party_system_ref.members.keys():
				if k == "mutante" and party_system_ref.is_kira_away: continue
				if party_system_ref.members[k].hp > 0: living_allies.append(k)

			if living_allies.size() > 0:
				var total_dmg_dealt = 0
				var living_count = count_living_allies()
				var can_perfect_defend = party_system_ref.has_perfect_defense_buff and (living_count == 4) and not is_current_boss and not party_system_ref.is_kira_away

				if is_master_boss and (active_master_type == "drone" or active_master_type == "alien"):
					for target_key in living_allies:
						var target_member = party_system_ref.members[target_key]
						var raw_dmg = max(3, int(enemy_unit_atk * 0.75) - (target_member.def / 3))
						if defending_members.has(target_key): raw_dmg = int(raw_dmg * 0.5)

						if is_kira_taunting and target_key == "mutante":
							raw_dmg = int(raw_dmg * 0.5)

						if target_member.shield > 0:
							if target_member.shield >= raw_dmg:
								target_member.shield -= raw_dmg
								raw_dmg = 0
							else:
								raw_dmg -= target_member.shield
								target_member.shield = 0

						target_member.hp -= raw_dmg
						total_dmg_dealt += raw_dmg
						animate_ally_hit(target_key)
						update_single_ally_hp(target_key)

					if is_kira_taunting:
						is_kira_taunting = false
						taunt_remaining_hits = 0

				elif is_master_boss and active_master_type == "androide":
					var chosen_target = "mutante" if (is_kira_taunting and party_system_ref.members["mutante"].hp > 0) else living_allies[randi() % living_allies.size()]

					var target_member = party_system_ref.members[chosen_target]
					var raw_dmg1 = max(4, enemy_unit_atk - (target_member.def / 2))
					if defending_members.has(chosen_target): raw_dmg1 = int(raw_dmg1 * 0.5)
					if is_kira_taunting and chosen_target == "mutante": raw_dmg1 = int(raw_dmg1 * 0.5)

					if target_member.shield > 0:
						if target_member.shield >= raw_dmg1:
							target_member.shield -= raw_dmg1
							raw_dmg1 = 0
						else:
							raw_dmg1 -= target_member.shield
							target_member.shield = 0

					target_member.hp -= raw_dmg1
					total_dmg_dealt += raw_dmg1
					animate_ally_hit(chosen_target)
					spawn_hit_sparks(portrait_frame_nodes[chosen_target].global_position + Vector2(60, 60), Color(0.0, 0.85, 1.0))
					update_single_ally_hp(chosen_target)

					var hit1_msg = ("Valeria X-9 golpeia com a 1ª Lâmina: %d de dano!" if lang == "pt" else ("Valeria X-9 strikes with 1st Blade: %d damage!" if lang == "en" else "ヴァレリア X-9 の第1刃！ %d ダメージ！")) % raw_dmg1
					log_message(hit1_msg)

					var t_blade2 = get_tree().create_timer(0.35)
					t_blade2.timeout.connect(func():
						if party_system_ref.members[chosen_target].hp <= 0:
							var remaining_living = []
							for k in living_allies:
								if party_system_ref.members[k].hp > 0: remaining_living.append(k)
							if remaining_living.size() > 0:
								chosen_target = remaining_living[randi() % remaining_living.size()]

						if party_system_ref.members[chosen_target].hp > 0:
							var target_m2 = party_system_ref.members[chosen_target]
							var raw_dmg2 = max(4, enemy_unit_atk - (target_m2.def / 2))
							if defending_members.has(chosen_target): raw_dmg2 = int(raw_dmg2 * 0.5)
							if is_kira_taunting and chosen_target == "mutante": raw_dmg2 = int(raw_dmg2 * 0.5)

							if target_m2.shield > 0:
								if target_m2.shield >= raw_dmg2:
									target_m2.shield -= raw_dmg2
									raw_dmg2 = 0
								else:
									raw_dmg2 -= target_m2.shield
									target_m2.shield = 0

							target_m2.hp -= raw_dmg2
							total_dmg_dealt += raw_dmg2
							animate_ally_hit(chosen_target)
							spawn_hit_sparks(portrait_frame_nodes[chosen_target].global_position + Vector2(60, 60), Color(0.0, 0.85, 1.0))
							update_single_ally_hp(chosen_target)
							if audio_manager: audio_manager.play_sfx("sfx_hit")

							var hit2_msg = ("Valeria X-9 rasga com a 2ª Lâmina: %d de dano!" if lang == "pt" else ("Valeria X-9 slashes with 2nd Blade: %d damage!" if lang == "en" else "ヴァレリア X-9 の第2刃！ %d ダメージ！")) % raw_dmg2
							log_message(hit2_msg)

						if is_kira_taunting:
							is_kira_taunting = false
							taunt_remaining_hits = 0

						update_battle_ui(true)
						if not check_deaths():
							get_tree().create_timer(1.2).timeout.connect(execute_next_action)
					)
					return

				elif is_master_boss and active_master_type == "mutante":
					var chosen_target = "mutante" if (is_kira_taunting and party_system_ref.members["mutante"].hp > 0) else living_allies[randi() % living_allies.size()]
					var target_member = party_system_ref.members[chosen_target]

					var raw_dmg1 = max(4, enemy_unit_atk - (target_member.def / 2))
					if defending_members.has(chosen_target): raw_dmg1 = int(raw_dmg1 * 0.5)
					if is_kira_taunting and chosen_target == "mutante": raw_dmg1 = int(raw_dmg1 * 0.5)

					if target_member.shield > 0:
						if target_member.shield >= raw_dmg1:
							target_member.shield -= raw_dmg1
							raw_dmg1 = 0
						else:
							raw_dmg1 -= target_member.shield
							target_member.shield = 0
					target_member.hp -= raw_dmg1
					total_dmg_dealt += raw_dmg1
					animate_ally_hit(chosen_target)
					update_single_ally_hp(chosen_target)

					var t_venom = get_tree().create_timer(0.30)
					t_venom.timeout.connect(func():
						if target_member.hp > 0:
							var raw_dmg2 = max(3, int(enemy_unit_atk * 0.85))
							if is_kira_taunting and chosen_target == "mutante": raw_dmg2 = int(raw_dmg2 * 0.5)
							if target_member.shield > 0:
								if target_member.shield >= raw_dmg2:
									target_member.shield -= raw_dmg2
									raw_dmg2 = 0
								else:
									raw_dmg2 -= target_member.shield
									target_member.shield = 0
							target_member.hp -= raw_dmg2
							total_dmg_dealt += raw_dmg2
							animate_ally_hit(chosen_target, Color(0.2, 2.5, 0.4))
							spawn_hit_sparks(portrait_frame_nodes[chosen_target].global_position + Vector2(60, 60), Color(0.2, 1.0, 0.3))
							update_single_ally_hp(chosen_target)
							if audio_manager: audio_manager.play_sfx("sfx_hit")

						if is_kira_taunting:
							is_kira_taunting = false
							taunt_remaining_hits = 0

						update_battle_ui(true)
						if not check_deaths():
							get_tree().create_timer(1.2).timeout.connect(execute_next_action)
					)
					return

				else:
					for i in range(horde_units.size()):
						var target_key = ""
						if is_kira_taunting and party_system_ref.members["mutante"].hp > 0:
							target_key = "mutante"
						else:
							target_key = living_allies[randi() % living_allies.size()]

						var target_member = party_system_ref.members[target_key]

						if defending_members.has(target_key) and can_perfect_defend:
							if portrait_frame_nodes.has(target_key) and is_instance_valid(portrait_frame_nodes[target_key]):
								var frame_pos = portrait_frame_nodes[target_key].global_position + Vector2(60, 60)
								spawn_hit_sparks(frame_pos, Color(0.0, 1.0, 0.5))
							continue

						var raw_dmg = max(2, (enemy_unit_atk - target_member.def / 2) / 2) if defending_members.has(target_key) else max(4, enemy_unit_atk - target_member.def / 2)

						if is_kira_taunting and target_key == "mutante":
							raw_dmg = int(raw_dmg * 0.5)

						if target_member.shield > 0:
							if target_member.shield >= raw_dmg:
								target_member.shield -= raw_dmg
								raw_dmg = 0
							else:
								raw_dmg -= target_member.shield
								target_member.shield = 0

						target_member.hp -= raw_dmg
						total_dmg_dealt += raw_dmg
						animate_ally_hit(target_key)
						update_single_ally_hp(target_key)

						if is_current_boss and not is_master_boss and target_member.hp > 0:
							stunned_allies[target_key] = 1
							stun_applied_this_round[target_key] = true

					if is_kira_taunting:
						is_kira_taunting = false
						taunt_remaining_hits = 0

				if total_dmg_dealt > 0:
					if lang == "en": log_message("The enemy attack dealt %d damage to the squad!" % total_dmg_dealt)
					elif lang == "ja": log_message("敵の攻撃により部隊に %d ダメージ！" % total_dmg_dealt)
					else: log_message("O ataque inimigo causou %d de dano na equipe!" % total_dmg_dealt)
				else:
					if lang == "en": log_message("The squad completely absorbed the enemy onslaught!")
					elif lang == "ja": log_message("部隊は敵の攻撃を完全無効化した！")
					else: log_message("A equipe absorveu integralmente a ofensiva inimiga!")

				update_battle_ui(true)
				if check_deaths(): return

			get_tree().create_timer(1.2).timeout.connect(execute_next_action)
		)
	else:
		var actor_entity = act.actor.entity
		if actor_entity.hp <= 0 or horde_units.is_empty():
			execute_next_action()
			return

		var actor_id = act.actor.id

		if act.action == "Atordoado" or stunned_allies.get(actor_id, 0) > 0:
			if not stun_applied_this_round.get(actor_id, false):
				stunned_allies.erase(actor_id)

			update_battle_ui(true)
			if audio_manager: audio_manager.play_sfx("sfx_flee", 0.0, 3.0)
			var stun_fmt = Localization.t("battle_log_stunned", "%s está atordoado e não pode agir neste turno!")
			log_message(stun_fmt % actor_entity.name)
			get_tree().create_timer(1.0).timeout.connect(execute_next_action)
			return

		if act.action == "Atacar":
			play_special_cutin(act.actor.id, func():
				if act.actor.id == "mutante":
					var total_dmg = actor_entity.atk + (actor_entity.skill_attack_lvl * 5) + (randi() % 8)
					var dmg1 = int(total_dmg / 2.0)
					var dmg2 = total_dmg - dmg1

					var prev_count = horde_units.size()
					apply_damage_to_horde_front(dmg1)
					var is_fatal_1 = horde_units.is_empty()

					if horde_units.size() < prev_count:
						log_message("Kira strikes with 1st Claw: %d damage (Enemy DESTROYED!)" % dmg1 if lang == "en" else ("キラの第1爪: %d ダメージ (敵撃破！)" % dmg1 if lang == "ja" else "Kira desfere 1ª Garra: %d de dano (Inimigo DESTRUÍDO!)" % dmg1))
					else:
						log_message("Kira strikes with 1st Claw: %d damage!" % dmg1 if lang == "en" else ("キラの第1爪: %d ダメージ！" % dmg1 if lang == "ja" else "Kira desfere 1ª Garra: %d de dano!" % dmg1))

					update_battle_ui(true)

					animate_enemy_hit(is_fatal_1, false, func():
						if check_deaths(): return

						var t_strike2 = get_tree().create_timer(0.20)
						t_strike2.timeout.connect(func():
							if horde_units.is_empty() or battle_state == State.END:
								check_deaths()
								return

							var prev_count_2 = horde_units.size()
							apply_damage_to_horde_front(dmg2)
							var is_fatal_2 = horde_units.is_empty()

							if horde_units.size() < prev_count_2:
								log_message("Kira rips with 2nd Claw: %d damage (Enemy DESTROYED!)" % dmg2 if lang == "en" else ("キラの第2爪: %d ダメージ (敵撃破！)" % dmg2 if lang == "ja" else "Kira rasga com 2ª Garra: %d de dano (Inimigo DESTRUÍDO!)" % dmg2))
							else:
								log_message("Kira rips with 2nd Claw: %d damage!" % dmg2 if lang == "en" else ("キラの第2爪: %d ダメージ！" % dmg2 if lang == "ja" else "Kira rasga com 2ª Garra: %d de dano!" % dmg2))

							update_battle_ui(true)

							animate_enemy_hit(is_fatal_2, false, func():
								if not check_deaths():
									get_tree().create_timer(0.6).timeout.connect(execute_next_action)
							)
						)
					)
				else:
					var dmg = actor_entity.atk + (actor_entity.skill_attack_lvl * 5) + (randi() % 8)
					var prev_count = horde_units.size()
					apply_damage_to_horde_front(dmg)

					if horde_units.size() < prev_count:
						log_message("%s dealt %d damage and DESTROYED the enemy!" % [actor_entity.name, dmg] if lang == "en" else ("%s の攻撃！ %d ダメージを与え、敵を粉砕した！" % [actor_entity.name, dmg] if lang == "ja" else "%s causou %d de dano e DESTRUIU o inimigo!" % [actor_entity.name, dmg]))
					else:
						log_message("%s attacked dealing %d damage!" % [actor_entity.name, dmg] if lang == "en" else ("%s の攻撃！ %d ダメージを与えた！" % [actor_entity.name, dmg] if lang == "ja" else "%s atacou causando %d de dano!" % [actor_entity.name, dmg]))

					var is_fatal = horde_units.is_empty()
					animate_enemy_hit(is_fatal, false, func():
						update_battle_ui(true)
						if not check_deaths():
							get_tree().create_timer(0.6).timeout.connect(execute_next_action)
					)
			)
		elif act.action == "Drive":
			play_special_cutin("humano", func():
				var dmg = (actor_entity.atk + (actor_entity.skill_attack_lvl * 5) + (randi() % 8)) * 2
				apply_damage_to_horde_front(dmg)

				if lang == "en":
					log_message("Rigard unleashed DRIVE! Impact dealt %d critical damage!" % dmg)
				elif lang == "ja":
					log_message("リガードの「ドライブ」発動！ 渾身の %d ダメージ！" % dmg)
				else:
					log_message("Rigard ativou o DRIVE! Golpe gerou %d de dano crítico!" % dmg)

				var is_fatal = horde_units.is_empty()
				animate_enemy_hit(is_fatal, false, func():
					update_battle_ui(true)
					if not check_deaths():
						get_tree().create_timer(0.6).timeout.connect(execute_next_action)
				, Color(2.5, 1.2, 0.1), Color(1.0, 0.55, 0.0))
			)
		elif act.action == "Provocar":
			act.speed = 99998
			play_special_cutin("mutante", func():
				if audio_manager: audio_manager.play_sfx("sfx_meow")
				is_kira_taunting = true
				taunt_remaining_hits = horde_units.size()

				update_battle_ui(true)

				var rosa_aura = Color(2.2, 0.6, 1.8)
				var normal_col = Color(1.0, 1.0, 1.0)

				if portrait_nodes.has("mutante") and is_instance_valid(portrait_nodes["mutante"]):
					is_ally_animating_hit["mutante"] = true
					var p_tw = create_tween()
					p_tw.tween_property(portrait_nodes["mutante"], "modulate", rosa_aura, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					p_tw.tween_property(portrait_nodes["mutante"], "modulate", normal_col, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					p_tw.finished.connect(func():
						is_ally_animating_hit["mutante"] = false
					)

				if enemy_sprite and is_instance_valid(enemy_sprite):
					var e_tw = create_tween()
					e_tw.tween_property(enemy_sprite, "modulate", rosa_aura, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					e_tw.tween_property(enemy_sprite, "modulate", normal_col, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				if enemy_sprite_left and enemy_sprite_left.visible:
					var el_tw = create_tween()
					el_tw.tween_property(enemy_sprite_left, "modulate", rosa_aura, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					el_tw.tween_property(enemy_sprite_left, "modulate", SIDE_ENEMY_MODULATE, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				if enemy_sprite_right and enemy_sprite_right.visible:
					var er_tw = create_tween()
					er_tw.tween_property(enemy_sprite_right, "modulate", rosa_aura, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					er_tw.tween_property(enemy_sprite_right, "modulate", SIDE_ENEMY_MODULATE, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				if lang == "en":
					log_message("Kira taunted the enemy horde! (All incoming hits drawn to Kira at -50% damage!)")
				elif lang == "ja":
					log_message("キラが敵群を挑発！ (全ての攻撃を引きつけ、被ダメージを50%カット！)")
				else:
					log_message("Kira provocou a horda inimiga! (Ataques atraídos para Kira com -50% de dano!)")

				get_tree().create_timer(0.5).timeout.connect(execute_next_action)
			)
		elif act.action == "Obscure":
			play_special_cutin("alien", func():
				var dmg = (actor_entity.magic_power + (actor_entity.skill_magic_lvl * 7) + (randi() % 10)) * 2

				var aoe_dmg = dmg
				if enemy_shield > 0:
					if enemy_shield >= aoe_dmg:
						enemy_shield -= aoe_dmg
						aoe_dmg = 0
					else:
						aoe_dmg -= enemy_shield
						enemy_shield = 0

				var remaining_horde: Array[int] = []
				for u_hp in horde_units:
					var new_hp = u_hp - aoe_dmg
					if new_hp <= 0:
						total_enemies_killed_this_fight += 1
						_record_race_kill(current_enemy_id)
					else:
						remaining_horde.append(new_hp)

				horde_units = remaining_horde
				update_enemy_hp_bar_direct()

				if lang == "en":
					log_message("Vaelthor cast OBSCURE! Void energy crushed the horde for %d damage!" % dmg)
				elif lang == "ja":
					log_message("ヴァエルサの「オブスキュア」！ 虚無の波動が全体に %d ダメージ！" % dmg)
				else:
					log_message("Vaelthor invocou OBSCURE! Vórtice sombrio causou %d de dano em área!" % dmg)

				var is_fatal = horde_units.is_empty()
				animate_enemy_hit(is_fatal, true, func():
					update_battle_ui(not is_fatal)
					if not check_deaths():
						get_tree().create_timer(0.6).timeout.connect(execute_next_action)
				, Color(2.0, 0.4, 2.5), Color(0.85, 0.25, 1.0))
			)
		elif act.action == "Magia Área":
			play_special_cutin(act.actor.id, func():
				var dmg = actor_entity.magic_power + (actor_entity.skill_magic_lvl * 7) + (randi() % 10)
				var aoe_dmg = dmg
				if enemy_shield > 0:
					if enemy_shield >= aoe_dmg:
						enemy_shield -= aoe_dmg
						aoe_dmg = 0
					else:
						aoe_dmg -= enemy_shield
						enemy_shield = 0

				var remaining_horde: Array[int] = []
				for u_hp in horde_units:
					var new_hp = u_hp - aoe_dmg
					if new_hp <= 0:
						total_enemies_killed_this_fight += 1
						_record_race_kill(current_enemy_id)
					else:
						remaining_horde.append(new_hp)

				horde_units = remaining_horde
				update_enemy_hp_bar_direct()

				if lang == "en":
					log_message("%s unleashed Area Magic! Dealt %d damage!" % [actor_entity.name, dmg])
				elif lang == "ja":
					log_message("%s の範囲魔法！ 全体に %d ダメージ！" % [actor_entity.name, dmg])
				else:
					log_message("%s liberou Magia de Área! Causou %d de dano!" % [actor_entity.name, dmg])

				var is_fatal = horde_units.is_empty()
				animate_enemy_hit(is_fatal, true, func():
					update_battle_ui(not is_fatal)
					if not check_deaths():
						get_tree().create_timer(0.6).timeout.connect(execute_next_action)
				)
			)
		elif act.action == "Cura Alvo":
			play_special_cutin(act.actor.id, func():
				if audio_manager: audio_manager.play_sfx("sfx_heal")
				var heal_val = actor_entity.heal_power + 45
				var is_unit7_healer = (act.actor.id == "robo")
				var target_key = ""

				var lowest_hp = 999999
				for k in party_system_ref.members.keys():
					if k == "mutante" and party_system_ref.is_kira_away: continue
					var m = party_system_ref.members[k]
					if m.hp > 0 and m.hp < m.max_hp and m.hp < lowest_hp:
						lowest_hp = m.hp
						target_key = k

				if target_key == "" and is_unit7_healer:
					var lowest_shield = 999999
					for k in party_system_ref.members.keys():
						if k == "mutante" and party_system_ref.is_kira_away: continue
						var m = party_system_ref.members[k]
						if m.hp > 0 and m.shield < heal_val and m.shield < lowest_shield:
							lowest_shield = m.shield
							target_key = k

				if target_key != "":
					var target_member = party_system_ref.members[target_key]
					var overflow = (target_member.hp + heal_val) - target_member.max_hp

					if overflow > 0:
						target_member.hp = target_member.max_hp
						if is_unit7_healer:
							var wasted_heal = min(heal_val, overflow)
							target_member.shield = max(target_member.shield, wasted_heal)
							if lang == "en": log_message("%s overhealed %s: Shield set to %d!" % [actor_entity.name, target_member.name, target_member.shield])
							elif lang == "ja": log_message("%s が %s をオーバーヒール: シールド値を %d に設定！" % [actor_entity.name, target_member.name, target_member.shield])
							else: log_message("%s sobrecurou %s: Escudo ajustado para %d!" % [actor_entity.name, target_member.name, target_member.shield])
						else:
							if lang == "en": log_message("%s fully restored %s's HP!" % [actor_entity.name, target_member.name])
							elif lang == "ja": log_message("%s が %s のHPを全回復させた！" % [actor_entity.name, target_member.name])
							else: log_message("%s curou %s completamente!" % [actor_entity.name, target_member.name])
					else:
						target_member.hp += heal_val
						if lang == "en": log_message("%s healed %s, restoring %d HP!" % [actor_entity.name, target_member.name, heal_val])
						elif lang == "ja": log_message("%s が %s を回復、HPが %d 回復した！" % [actor_entity.name, target_member.name, heal_val])
						else: log_message("%s curou %s recuperando %d de HP!" % [actor_entity.name, target_member.name, heal_val])

					animate_ally_heal(target_key)
					update_single_ally_hp(target_key)
				else:
					if lang == "en": log_message("All allies are already at max HP and Shields! Heal had no effect.")
					elif lang == "ja": log_message("仲間全員のHPとシールドが満タンです！ 回復の効果はありませんでした。")
					else: log_message("Todos os aliados já estão com Vida e Escudos no máximo! A cura não surtiu efeito.")

				update_battle_ui(true)
				get_tree().create_timer(0.6).timeout.connect(execute_next_action)
			)
		elif act.action == "Cura Área":
			play_special_cutin(act.actor.id, func():
				if audio_manager: audio_manager.play_sfx("sfx_heal")
				var heal_val = (actor_entity.heal_power / 2) + 25
				var is_unit7_healer = (act.actor.id == "robo")
				var total_shields_granted = 0

				for k in party_system_ref.members.keys():
					if k == "mutante" and party_system_ref.is_kira_away: continue
					var m = party_system_ref.members[k]
					if m.hp > 0:
						var overflow = (m.hp + heal_val) - m.max_hp
						if overflow > 0:
							m.hp = m.max_hp
							if is_unit7_healer:
								var wasted_heal = min(heal_val, overflow)
								m.shield = max(m.shield, wasted_heal)
								total_shields_granted += 1
						else:
							m.hp += heal_val

						animate_ally_heal(k)
						update_single_ally_hp(k)

				if is_unit7_healer and total_shields_granted > 0:
					if lang == "en": log_message("Unit-7 healed the squad and renewed Protective Barriers!")
					elif lang == "ja": log_message("Unit-7 が部隊を全回復し、バリアを更新した！")
					else: log_message("Unit-7 regenerou a equipe e renovou as Barreiras Protetoras!")
				else:
					if lang == "en": log_message("Squad recovered %d HP!" % heal_val)
					elif lang == "ja": log_message("部隊全員のHPが %d 回復した！" % heal_val)
					else: log_message("Equipe regenerada em %d HP!" % heal_val)

				update_battle_ui(true)
				get_tree().create_timer(0.6).timeout.connect(execute_next_action)
			)
		elif act.action == "Defender":
			if audio_manager: audio_manager.play_sfx("sfx_defend")
			var living_count = count_living_allies()

			if party_system_ref.has_perfect_defense_buff and (living_count == 4) and not is_current_boss and not party_system_ref.is_kira_away:
				if lang == "en": log_message("%s took an Impenetrable Defense stance! (Damage Negated!)" % actor_entity.name)
				elif lang == "ja": log_message("%s は「絶対防御」の姿勢をとった！ (ダメージ無効化！)" % actor_entity.name)
				else: log_message("%s assumiu uma Postura de Defesa Impenetrável! (Dano Anulado!)" % actor_entity.name)
			else:
				if lang == "en": log_message("%s assumed an armored defense stance." % actor_entity.name)
				elif lang == "ja": log_message("%s は防御姿勢をとった。" % actor_entity.name)
				else: log_message("%s assumiu postura blindada de defesa." % actor_entity.name)

			get_tree().create_timer(0.4).timeout.connect(execute_next_action)

func trigger_master_boss_appearance(m_type: String):
	is_master_boss = true
	is_boss_spawning = true
	active_master_type = m_type
	pending_master_type = ""
	is_security_mode = false

	if not has_chronodox:
		masters_fought_without_chronodox += 1
	else:
		masters_fought_with_chronodox += 1

	accumulated_horde_exp += enemy_exp_reward

	match m_type:
		"drone": current_enemy_id = "enemy_master_drone"
		"mutante": current_enemy_id = "enemy_master_mutant"
		"androide": current_enemy_id = "enemy_master_android"
		"alien": current_enemy_id = "enemy_master_alien"

	var leader_lvl = party_system_ref.members["humano"].level

	# Buff de +30% HP e +15% ATK/VEL nos 4 Mestres
	enemy_unit_max_hp = int((260 + (current_floor_num * 24) + (leader_lvl * 12)) * 1.30)
	enemy_unit_atk = int((22 + (current_floor_num * 4) + (leader_lvl * 3)) * 1.15)
	enemy_exp_reward = 800 + (current_floor_num * 120)
	current_enemy_speed = int((15 + int(current_floor_num * 0.5)) * 1.15)

	horde_units = [enemy_unit_max_hp]

	# Valeria X-9 ganha 50% de escudo amarelo alinhado
	if m_type == "androide":
		enemy_shield = int(enemy_unit_max_hp * 0.50)
		enemy_max_shield = enemy_unit_max_hp
	else:
		enemy_shield = 0
		enemy_max_shield = 0

	if audio_manager:
		audio_manager.play_sfx("sfx_paradox_egnite", 0.0, 2.0)
		audio_manager.play_bgm("bgm_bosses", true, 1.0)

	if main_buttons.size() >= 4:
		var flee_btn = main_buttons[3]
		if is_instance_valid(flee_btn):
			flee_btn.disabled = true
			flee_btn.hide()

	var new_tex = load_enemy_texture(current_enemy_id)
	if new_tex:
		if enemy_sprite:
			enemy_sprite.texture = new_tex
			enemy_sprite.scale = Vector2(1.28, 1.28)
			enemy_sprite.modulate = Color(2.5, 1.2, 3.5, 0.0)
		if enemy_shadow:
			enemy_shadow.texture = new_tex
			enemy_shadow.modulate = Color(0, 0, 0, 0.0)

	if enemy_sprite_left: enemy_sprite_left.hide(); enemy_shadow_left.hide()
	if enemy_sprite_right: enemy_sprite_right.hide(); enemy_shadow_right.hide()

	var t_fade = create_tween().set_parallel(true)
	t_fade.tween_property(enemy_sprite, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	t_fade.tween_property(enemy_sprite, "scale", Vector2(1.0, 1.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t_fade.tween_property(enemy_shadow, "modulate:a", ENEMY_SHADOW_COLOR.a, 1.4).set_trans(Tween.TRANS_SINE)
	t_fade.chain().tween_property(enemy_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

	var lang = Localization.current_language
	if security_badge_label:
		var master_badge = "★ LÍDER DE RAÇA - MESTRE ★" if lang == "pt" else ("★ SPECIES LEADER - MASTER ★" if lang == "en" else "★ 種族の統率者 - マスター ★")
		security_badge_label.text = master_badge
		security_badge_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
		security_badge_label.show()

	if enemy_hp_bar:
		enemy_hp_bar.max_value = float(get_total_horde_hp())
		enemy_hp_bar.value = enemy_hp_bar.max_value

	update_battle_ui(false)

	var speech = ""
	if has_chronodox:
		match m_type:
			"drone":
				speech = "« Energia cronológica detectada! Entreguem o Chronodox ou serão desintegrados! »" if lang == "pt" else ("« Chronological energy detected! Surrender the Chronodox or face disintegration! »" if lang == "en" else "« 時間エネルギー反応を検知！ クロノドックスを渡せ、さもなくば消滅あるのみ！ »")
			"mutante":
				speech = "« Esse cheiro... Vocês estão com o Chronodox! Passem essa esfera para mim agora! »" if lang == "pt" else ("« That scent... You hold the Chronodox! Hand over the sphere at once! »" if lang == "en" else "« この匂い... 貴様らクロノドックスを持っているな！ 今すぐその球体を寄越せ！ »")
			"androide":
				speech = "« Assinatura temporal confirmada. O Chronodox pertencerá aos meus sistemas! »" if lang == "pt" else ("« Temporal signature confirmed. The Chronodox shall belong to my network! »" if lang == "en" else "« 時間軸シグネチャ確認。クロノドックスは我がシステムが統掌する！ »")
			"alien":
				speech = "« O Chronodox... a relíquia das eras! Meus tentáculos vão arrancá-lo de seus corpos! »" if lang == "pt" else ("« The Chronodox... relic of eons! My tentacles shall rip it from your husks! »" if lang == "en" else "« クロノドックス... 悠久の秘宝！ 我が触手でその肉体から引きずり出してくれよう！ »")
	else:
		match m_type:
			"drone":
				speech = "« Alerta crítico! Vocês destruíram minha esquadra de drones! Eu mesmo vou expurgar vocês! »" if lang == "pt" else ("« Critical breach! You destroyed my drone squadron! I shall purge you myself! »" if lang == "en" else "« 致命的警告！ 我がドローン小隊を破壊したな！ 私自ら貴様らを粛清する！ »")
			"mutante":
				speech = "« Quem ousa chacinar minhas feras mutantes?! Vou estraçalhar cada osso de vocês! »" if lang == "pt" else ("« Who dares butcher my mutant beasts?! I'll crush every bone in your bodies! »" if lang == "en" else "« 我が変異獣どもを屠ったのは貴様らか？！ 骨の髄まで噛み砕いてくれる！ »")
			"androide":
				speech = "« Unidades androides neutralizadas. Eu mesma executarei o protocolo de extermínio! »" if lang == "pt" else ("« Android units neutralized. I shall execute the extermination protocol myself! »" if lang == "en" else "« アンドロイド部隊全滅を確認。私が直接貴様らの抹殺プロトコルを執行する！ »")
			"alien":
				speech = "« Vocês ousaram aniquilar meus batedores?! Sentirão a fúria dos meus tentáculos! »" if lang == "pt" else ("« You dared slaughter my scouts?! Feel the crushing wrath of my tentacles! »" if lang == "en" else "« よくも我が斥候を殲滅したな？！ 触手の猛威、その身で味わうがよい！ »")

	log_label.add_theme_font_size_override("font_size", 16)
	log_label.add_theme_constant_override("outline_size", 4)
	log_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	log_message(speech)

	var orig_log_pos = log_label.position

	var rgb_pulse = create_tween().set_loops(28)
	rgb_pulse.tween_property(log_label, "theme_override_colors/font_color", Color(2.4, 0.2, 0.2), 0.08)
	rgb_pulse.tween_property(log_label, "theme_override_colors/font_color", Color(1.0, 0.05, 0.05), 0.08)
	rgb_pulse.tween_property(log_label, "theme_override_colors/font_color", Color(1.8, 0.35, 0.15), 0.08)
	rgb_pulse.tween_property(log_label, "theme_override_colors/font_color", Color(0.75, 0.0, 0.0), 0.08)

	var shake_tw = create_tween().set_loops(210)
	shake_tw.tween_callback(func():
		if is_instance_valid(log_label):
			log_label.position = orig_log_pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	).set_delay(0.02)

	var t = get_tree().create_timer(4.2)
	t.timeout.connect(func():
		is_boss_spawning = false
		if rgb_pulse and rgb_pulse.is_valid(): rgb_pulse.kill()
		if shake_tw and shake_tw.is_valid(): shake_tw.kill()

		log_label.position = orig_log_pos
		log_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		log_label.add_theme_font_size_override("font_size", 14)
		start_turn_selection()
	)

func check_deaths() -> bool:
	var rigard = party_system_ref.members["humano"]
	var lang = Localization.current_language

	if rigard.hp <= 0 and battle_state != State.END:
		battle_state = State.END
		pending_actions.clear()

		if audio_manager:
			audio_manager.stop_bgm()
			if is_current_boss or not has_chronodox:
				audio_manager.play_sfx("sfx_game_over")

		if lang == "en": log_message("Commander Rigard has been neutralized!")
		elif lang == "ja": log_message("リガード隊長が倒れた！")
		else: log_message("O Comandante Rigard foi abatido!")

		var dead_without_drive: Array[String] = []
		var t = get_tree().create_timer(1.8)
		t.timeout.connect(func():
			is_in_battle = false
			if battle_ui: battle_ui.queue_free()
			emit_signal("battle_ended", false, total_enemies_killed_this_fight, is_current_boss, current_enemy_id, dead_without_drive)
		)
		return true

	if horde_units.is_empty() and battle_state != State.END:
		if pending_master_type != "" and not is_master_boss:
			trigger_master_boss_appearance(pending_master_type)
			return true

		battle_state = State.END

		if is_alien_chest:
			var open_tex = load_texture_safe("prop_chest_open")
			if not open_tex: open_tex = load_texture_safe("prop_chest_open")
			if open_tex and enemy_sprite: enemy_sprite.texture = open_tex
			if audio_manager: audio_manager.play_sfx("sfx_chest_open")
		else:
			var dead_gray = Color(0.25, 0.25, 0.25)
			if enemy_sprite: enemy_sprite.modulate = dead_gray
			if enemy_sprite_left and enemy_sprite_left.visible: enemy_sprite_left.modulate = dead_gray
			if enemy_sprite_right and enemy_sprite_right.visible: enemy_sprite_right.modulate = dead_gray

		if enemy_count_label:
			var enemy_name = get_formatted_enemy_name()
			var status_neutralized = " [NEUTRALIZADO]" if lang == "pt" else (" [NEUTRALIZED]" if lang == "en" else " [撃破]")
			var status_opened = " [ABERTO]" if lang == "pt" else (" [OPENED]" if lang == "en" else " [開封済み]")

			if is_current_boss or is_master_boss:
				enemy_count_label.text = enemy_name + status_neutralized
			elif is_alien_chest:
				enemy_count_label.text = enemy_name + status_opened
			else:
				enemy_count_label.text = enemy_name + status_neutralized

		if is_current_boss and not is_master_boss:
			if audio_manager: audio_manager.stop_bgm()
		elif audio_manager:
			audio_manager.play_bgm("bgm_victory", false, 1.0)
			audio_manager.play_sfx("sfx_level_up")

		if is_master_boss:
			defeated_masters[active_master_type] = true

		var total_exp_to_give = enemy_exp_reward + accumulated_horde_exp
		if total_exp_to_give > 0:
			party_system_ref.gain_exp_all(total_exp_to_give)
			if lang == "en": log_message("Enemy group neutralized! +%d EXP granted!" % total_exp_to_give)
			elif lang == "ja": log_message("敵グループを撃破！ %d EXP 獲得！" % total_exp_to_give)
			else: log_message("Inimigo neutralizado! +%d EXP concedidos!" % total_exp_to_give)

		var win_delay = 1.0 if (is_current_boss and not is_master_boss) else 2.0
		get_tree().create_timer(win_delay).timeout.connect(func(): end_battle(true))
		return true

	return false

func spawn_cutin_speedlines() -> CPUParticles2D:
	var container_w = cutin_container.size.x
	var container_h = cutin_container.size.y

	var img = Image.create(110, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.95))
	var line_tex = ImageTexture.create_from_image(img)

	var p = CPUParticles2D.new()
	p.texture = line_tex

	p.position = Vector2(0, container_h * 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(5, container_h * 0.20)

	var vel_030 = container_w / 0.05
	p.direction = Vector2(1, 0)
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vel_030
	p.initial_velocity_max = vel_030 * 1.10
	p.lifetime = 0.05
	p.amount = 500
	p.color = Color(1.0, 1.0, 1.0, 0.30)

	cutin_container.add_child(p)
	cutin_container.move_child(p, 1)
	return p

func play_special_cutin(character_id: String, callback: Callable):
	var tex_name = "char_full_" + character_id
	var raw_tex = load_texture_safe(tex_name)
	if not raw_tex:
		tex_name = "char_full_" + character_id
		if character_id == "alien" and party_system_ref and party_system_ref.is_alien_endless_skin:
			var endless_tex = load_texture_safe("char_full_alien_endless")
			if not endless_tex: endless_tex = load_texture_safe("char_full_alien_endless")
			if endless_tex: raw_tex = endless_tex
		if not raw_tex: raw_tex = load_texture_safe(tex_name)

	if not raw_tex:
		callback.call()
		return

	var raw_w = float(raw_tex.get_width())
	var raw_h = float(raw_tex.get_height())
	var crop_h = raw_h * clamp(CUTIN_VISIBLE_RATIO, 0.1, 1.0)

	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = raw_tex
	atlas_tex.region = Rect2(0, 0, raw_w, crop_h)
	cutin_sprite.texture = atlas_tex

	var aspect_ratio = raw_w / crop_h
	var render_w = CUTIN_WIDTH_PX
	var render_h = render_w / aspect_ratio
	cutin_sprite.size = Vector2(render_w, render_h)

	var container_w = cutin_container.size.x
	var container_h = cutin_container.size.y
	var base_y = container_h - render_h - CUTIN_BOTTOM_OFFSET
	var center_x = (container_w - render_w) / 2.0
	var start_x = -render_w - 60.0

	var bg_fade = ColorRect.new()
	bg_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_fade.color = Color(0, 0, 0, 0)
	bg_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutin_container.add_child(bg_fade)
	cutin_container.move_child(bg_fade, 0)

	cutin_sprite.position = Vector2(start_x, base_y)
	cutin_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	cutin_sprite.show()

	var speedlines = spawn_cutin_speedlines()
	var tween = create_tween()
	tween.tween_property(cutin_sprite, "position:x", center_x - 20.0, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bg_fade, "color:a", 0.35, 0.15)
	tween.chain().tween_property(cutin_sprite, "position:x", center_x + 20.0, 0.35)
	tween.parallel().tween_property(bg_fade, "color:a", 0.70, 0.15)

	tween.finished.connect(func():
		cutin_sprite.hide()
		speedlines.queue_free()
		bg_fade.queue_free()
		callback.call()
	)

func end_battle(victory: bool):
	if not is_in_battle: return
	battle_state = State.END
	is_in_battle = false

	var dead_without_drive: Array[String] = []
	for k in ["mutante", "alien", "robo"]:
		if party_system_ref.members.has(k):
			var m = party_system_ref.members[k]
			if m.hp <= 0 and not m.has_data_drive and not allies_dead_at_start.get(k, false) and not (k == "mutante" and party_system_ref.is_kira_away):
				dead_without_drive.append(k)

	var finished_enemy_id = current_enemy_id
	var was_boss = is_current_boss or is_master_boss

	if battle_ui: battle_ui.queue_free()
	if audio_manager and not is_current_boss:
		audio_manager.play_bgm("bgm_dungeon", true, 1.0)
	emit_signal("battle_ended", victory, total_enemies_killed_this_fight, was_boss, finished_enemy_id, dead_without_drive)
