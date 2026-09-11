# SpaceSpooterMinigame.gd
extends Control

signal minigame_completed(victory: bool)

const TARGET_DODGES: int = 100

enum State { INTRO, PLAYING, WON, LOST }
var current_state: State = State.INTRO

var dodged_count: int = 0
var move_direction: float = 1.0
var ship_x: float = 230.0
var ship_speed: float = 340.0

var asteroids: Array[Dictionary] = []
var spawn_timer: float = 0.0
var current_spawn_interval: float = 0.80

var screen_size: Vector2 = Vector2(460, 460)
var audio_manager_ref: Node

var bg_snapshot_rect: TextureRect
var frame_container: Panel
var game_viewport_clip: Control
var game_font: Font = null

const RETRO_GREEN: Color = Color(0.0, 1.0, 0.4, 1.0)
const RETRO_GREEN_DARK: Color = Color(0.0, 1.0, 0.4, 1.0)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_font = FontManager.get_font("retro")

func start_game(snapshot_tex: Texture2D, audio_ref: Node):
	audio_manager_ref = audio_ref
	var vp_size = get_viewport_rect().size

	if bg_snapshot_rect == null:
		bg_snapshot_rect = TextureRect.new()
		bg_snapshot_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_snapshot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_snapshot_rect.stretch_mode = TextureRect.STRETCH_SCALE
		bg_snapshot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_snapshot_rect)

		var dark_tint = ColorRect.new()
		dark_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark_tint.color = Color(0.0, 0.01, 0.03, 0.85)
		dark_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dark_tint)

		frame_container = Panel.new()
		frame_container.size = screen_size + Vector2(16, 16)
		frame_container.position = (vp_size - frame_container.size) / 2.0
		var f_style = StyleBoxFlat.new()
		f_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		f_style.border_width_left = 3
		f_style.border_width_top = 3
		f_style.border_width_right = 3
		f_style.border_width_bottom = 3
		f_style.border_color = RETRO_GREEN
		f_style.corner_radius_top_left = 4
		f_style.corner_radius_top_right = 4
		f_style.corner_radius_bottom_right = 4
		f_style.corner_radius_bottom_left = 4
		frame_container.add_theme_stylebox_override("panel", f_style)
		add_child(frame_container)

		game_viewport_clip = Control.new()
		game_viewport_clip.clip_contents = true
		game_viewport_clip.size = screen_size
		game_viewport_clip.position = Vector2(8, 8)
		frame_container.add_child(game_viewport_clip)
		game_viewport_clip.draw.connect(_on_game_draw)

	if snapshot_tex:
		bg_snapshot_rect.texture = snapshot_tex

	current_state = State.INTRO
	dodged_count = 0
	asteroids.clear()
	move_direction = 1.0
	ship_x = screen_size.x / 2.0
	spawn_timer = 0.0

	if audio_manager_ref:
		audio_manager_ref.play_bgm("bgm_space_spooter_playing", true, 1.0, true)

	if game_viewport_clip:
		game_viewport_clip.queue_redraw()

func _process(delta: float):
	if current_state != State.PLAYING:
		if game_viewport_clip: game_viewport_clip.queue_redraw()
		return

	ship_x += move_direction * ship_speed * delta

	if ship_x < 0:
		ship_x += screen_size.x
	elif ship_x > screen_size.x:
		ship_x -= screen_size.x

	spawn_timer += delta
	current_spawn_interval = clamp(0.80 - (float(dodged_count) / float(TARGET_DODGES)) * 0.46, 0.28, 0.80)

	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		spawn_asteroid()

	var fall_speed = 220.0 + (float(dodged_count) * 3.4)
	var remaining_asteroids: Array[Dictionary] = []
	var ship_center = Vector2(ship_x, screen_size.y - 50.0)

	for ast in asteroids:
		ast.pos.y += fall_speed * delta
		ast.rot += ast.rot_speed * delta

		var dist = ast.pos.distance_to(ship_center)

		if dist < (ast.radius + 20.0):
			trigger_defeat()
			return

		if ast.pos.y > (screen_size.y + ast.radius + 15.0):
			dodged_count += 1
			if dodged_count >= TARGET_DODGES:
				trigger_victory()
				return
		else:
			remaining_asteroids.append(ast)

	asteroids = remaining_asteroids
	if game_viewport_clip:
		game_viewport_clip.queue_redraw()

func trigger_defeat():
	current_state = State.LOST
	set_process(false)
	if audio_manager_ref:
		audio_manager_ref.play_sfx("sfx_hit")
		audio_manager_ref.stop_bgm(0.3)
	if game_viewport_clip: game_viewport_clip.queue_redraw()

	var t = get_tree().create_timer(1.2)
	t.timeout.connect(func():
		emit_signal("minigame_completed", false)
	)

func trigger_victory():
	current_state = State.WON
	set_process(false)
	if audio_manager_ref:
		audio_manager_ref.stop_bgm(0.3)
		audio_manager_ref.play_sfx("sfx_level_up")
	if game_viewport_clip: game_viewport_clip.queue_redraw()

	var t = get_tree().create_timer(1.5)
	t.timeout.connect(func():
		emit_signal("minigame_completed", true)
	)

func spawn_asteroid():
	var ast: Dictionary = {
		"pos": Vector2(randf_range(30.0, screen_size.x - 30.0), -40.0),
		"radius": randf_range(30.0, 48.0),
		"rot": randf() * TAU,
		"rot_speed": randf_range(-2.4, 2.4)
	}
	asteroids.append(ast)

func _unhandled_input(event: InputEvent):
	if current_state == State.WON or current_state == State.LOST:
		return

	var is_act = false
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.is_action_pressed("ui_accept")):
		is_act = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		is_act = true

	if is_act:
		if current_state == State.INTRO:
			current_state = State.PLAYING
			if audio_manager_ref: audio_manager_ref.play_sfx("sfx_menu_select")
		elif current_state == State.PLAYING:
			move_direction = -move_direction
			if audio_manager_ref: audio_manager_ref.play_sfx("sfx_menu_move", 0.05, -6.0)
		get_viewport().set_input_as_handled()

func _on_game_draw():
	if not game_viewport_clip: return
	var font_to_use = game_font if game_font else FontManager.get_font("retro")
	var lang = Localization.current_language

	game_viewport_clip.draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.0, 0.0, 1.0), true)

	if current_state == State.INTRO:
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 140), "SPACE SPOOTER", HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 34, RETRO_GREEN)

		var dodge_str = ("DODGE %d ASTEROIDS" if lang == "en" else ("%d個の隕石を回避せよ" if lang == "ja" else "DESVIE DE %d METEOROS")) % TARGET_DODGES
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 220), dodge_str, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 20, RETRO_GREEN)

		var rev_str = "[ E / A ] REVERSE DIRECTION" if lang == "en" else ("[ E / A ] 旋回反転" if lang == "ja" else "[ E / A ] INVERTE DIREÇÃO")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 290), rev_str, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 18, RETRO_GREEN)

		var play_str = "PRESS [ E / A ] TO PLAY" if lang == "en" else ("[ E / A ] ボタンで開始" if lang == "ja" else "PRESSIONE [ E / A ] PARA JOGAR")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 390), play_str, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 20, RETRO_GREEN)
		return

	if current_state == State.WON:
		var won_title = "★ VICTORY! ★" if lang == "en" else ("★ 勝利！ ★" if lang == "ja" else "★ VITÓRIA! ★")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 180), won_title, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 34, RETRO_GREEN)

		var won_sub = "100 ASTEROIDS DODGED" if lang == "en" else ("100個の隕石回避達成" if lang == "ja" else "100 METEOROS DESVIADOS")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 250), won_sub, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 20, RETRO_GREEN)

		var disc_str = "SYSTEM DISCONNECTING..." if lang == "en" else ("システム切断中..." if lang == "ja" else "SISTEMA DESCONECTANDO...")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 320), disc_str, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 17, RETRO_GREEN)
		return

	if current_state == State.LOST:
		var lost_title = "COLLISION DETECTED!" if lang == "en" else ("衝突検知！" if lang == "ja" else "COLISÃO DETECTADA!")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 190), lost_title, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 24, RETRO_GREEN)

		var lost_sub = "RESTARTING SIMULATION..." if lang == "en" else ("シミュレーション再起動中..." if lang == "ja" else "REINICIANDO SIMULAÇÃO...")
		game_viewport_clip.draw_string(font_to_use, Vector2(0, 260), lost_sub, HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 17, RETRO_GREEN)
		return

	var score_str = ("ASTEROIDS: %d / %d" if lang == "en" else ("隕石: %d / %d" if lang == "ja" else "METEOROS: %d / %d")) % [dodged_count, TARGET_DODGES]
	var dir_str = "[E / A] REVERSE" if lang == "en" else ("[E / A] 反転" if lang == "ja" else "[E / A] INVERTER")
	game_viewport_clip.draw_string(font_to_use, Vector2(16, 32), score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RETRO_GREEN)
	game_viewport_clip.draw_string(font_to_use, Vector2(0, 32), dir_str, HORIZONTAL_ALIGNMENT_RIGHT, screen_size.x - 16.0, 16, RETRO_GREEN)

	var ship_screen_pos = Vector2(ship_x, screen_size.y - 50.0)
	var tip = ship_screen_pos + Vector2(0, -28)
	var left_wing = ship_screen_pos + Vector2(-22, 22)
	var right_wing = ship_screen_pos + Vector2(22, 22)
	var engine = ship_screen_pos + Vector2(0, 12)

	var ship_poly = PackedVector2Array([tip, left_wing, engine, right_wing])
	game_viewport_clip.draw_colored_polygon(ship_poly, RETRO_GREEN)
	game_viewport_clip.draw_polyline(PackedVector2Array([tip, left_wing, engine, right_wing, tip]), RETRO_GREEN, 2.5)

	for ast in asteroids:
		var poly = PackedVector2Array()
		for i in range(8):
			var angle = ast.rot + (i * TAU / 8.0)
			var pt = ast.pos + Vector2(cos(angle), sin(angle)) * ast.radius
			poly.append(pt)

		game_viewport_clip.draw_colored_polygon(poly, RETRO_GREEN_DARK)
		poly.append(poly[0])
		game_viewport_clip.draw_polyline(poly, RETRO_GREEN, 2.5)
