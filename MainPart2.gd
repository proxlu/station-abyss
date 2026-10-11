# MainPart2.gd
extends "res://MainPart1.gd"

# ==============================================================================
# STUBS VIRTUAIS (Implementados no Main.gd final)
# ==============================================================================
func update_hud() -> void: pass
func load_floor(_floor_num: int, _is_fall: bool = false, _floors_fallen: int = 0) -> void: pass
func check_interactions() -> void: pass
func deactivate_portal_shield() -> void: pass
func start_combat() -> void: pass
func _check_pending_special_encounter() -> String: return ""
func _start_special_encounter_sequence(_boss_id: String) -> void: pass

# ==============================================================================
# ESTADOS DE EXPLORAÇÃO E ÁUDIO DE PROXIMIDADE
# ==============================================================================
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
			if audio_manager.BGM_CUSTOM_VOLUMES.has(track_key): base_target_vol = audio_manager.BGM_CUSTOM_VOLUMES[track_key]
			elif audio_manager.SFX_ATTENUATION.has(track_key): base_target_vol = audio_manager.SFX_ATTENUATION[track_key]

		var t = clamp((min_dist - min_dist_threshold) / (max_dist - min_dist_threshold), 0.0, 1.0)
		arcade_proximity_player.volume_db = lerp(base_target_vol, base_target_vol - 38.0, t)

# ==============================================================================
# MOVIMENTAÇÃO 3D E FÍSICA DO JOGADOR
# ==============================================================================
func is_front_space_clear(min_clear_distance: float = 4.2) -> bool:
	if not player or not is_inside_tree(): return false

	var forward_dir = -player.global_transform.basis.z.normalized()
	var test_motion = forward_dir * min_clear_distance
	var test_col = KinematicCollision3D.new()
	if player.test_move(player.global_transform, test_motion, test_col): return false

	var p_pos_2d = Vector2(player.global_position.x, player.global_position.z)
	var f_dir_2d = Vector2(forward_dir.x, forward_dir.z).normalized()

	for p in pois:
		var poi_pos_2d = Vector2(p.x, p.z)
		var dist = p_pos_2d.distance_to(poi_pos_2d)
		if dist < 1.8: return false
		elif dist < 3.8:
			var to_poi_dir = (poi_pos_2d - p_pos_2d).normalized()
			if f_dir_2d.dot(to_poi_dir) > 0.45: return false

	return true

func trigger_kira_departure():
	if party_system.is_kira_away or has_chronodox: return
	party_system.is_kira_away = true
	zigzag_suppressed_count = 0
	zigzag_turn_switches = 0

	if audio_manager: audio_manager.play_sfx("sfx_menu_cancel")

	if dialogue_port_frame:
		dialogue_port_frame.show()
		if diag_tex_normal.has("mutante"): portrait_rect.texture = diag_tex_normal["mutante"]

	var kira_speech = Localization.t("kira_away_dialogue", "Humano, você tá andando parecendo uma barata tonta na parede! Cansaço só de olhar... Cansei de esperar, vou na frente quebrar umas portas!")
	dialogue_label.position = Vector2(145, 15)
	dialogue_label.size = Vector2(dialogue_panel.size.x - 165, 110)
	dialogue_label.text = "[b][color=#ff9933]Kira[/color][/b]\n%s" % kira_speech
	dialogue_panel.show()

	var t = get_tree().create_timer(4.0)
	t.timeout.connect(func():
		var warn_title = Localization.t("popup_kira_away_title", "⚠ ATENÇÃO:")
		var warn_desc = Localization.t("popup_kira_away_warn", "Kira ficou impaciente com a lentidão e avançou sozinha pelos corredores!")
		show_system_message("[color=#ff4444]" + warn_title + "[/color]", warn_desc, null, Callable(), "sfx_menu_cancel")
	)

func _physics_process(delta):
	if not is_exploration_active(): return

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
		if will_collide: player.velocity = Vector3.ZERO
		else: player.velocity = forward * (-move_dir) * move_speed
	else:
		player.velocity = Vector3.ZERO

	var pos_before = player.global_position
	player.move_and_slide()
	var actual_dist = pos_before.distance_to(player.global_position)

	var effective_dist = actual_dist
	if is_marching_in_place: effective_dist = (move_speed * delta) * 2.0

	if effective_dist > 0.001:
		footstep_timer += delta
		if footstep_timer >= 0.5:
			footstep_timer = 0.0
			var should_play_step = true
			if is_marching_in_place and not enable_marching_footsteps: should_play_step = false
			if should_play_step and audio_manager: audio_manager.play_sfx("sfx_step", 0.1)

		step_counter += effective_dist
		if not is_vault_floor and step_counter > 15.0:
			if randf() < 0.3:
				if is_front_space_clear(4.2):
					step_counter = 0.0
					zigzag_turn_switches = 0
					zigzag_suppressed_count = 0
					is_transitioning_combat = true
					player.velocity = Vector3.ZERO

					var special_spawn_id = _check_pending_special_encounter()
					if special_spawn_id != "":
						_start_special_encounter_sequence(special_spawn_id)
					else:
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

# ==============================================================================
# CICLO DE PROCESSAMENTO (VÓRTICES, RACHADURAS, RADAR)
# ==============================================================================
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
		_process_vault_minigame(delta)

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
					if next_f % 5 == 0: load_vault_floor(next_f, true, jump)
					else: load_floor(next_f, true, jump)
					fade_to_transparent(0.6, func(): is_fade_movement_locked = false)
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
		if dialogue_manager: dialogue_manager.trigger_dialogue("vortice_teleporte")
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

# ==============================================================================
# MECÂNICA DA SALA DO COFRE (VAULT)
# ==============================================================================
func load_vault_floor(vault_num: int, is_fall: bool = false, floors_fallen: int = 0):
	dismiss_tutorial_banner()
	extra_cutscene_played_this_floor = false
	is_vault_floor = true
	current_floor = vault_num
	vault_floor_id = float(vault_num)
	vault_chests_collected = 0
	vault_timer = 60.0
	vault_chest_state = "idle"
	vault_bonus_achieved = false
	is_vault_decision_open = false

	var floor_data = dungeon_generator.generate_vault_floor(vault_num)
	pois = []
	player.global_position = Vector3(0, 0, 0)
	player.rotation.y = 0.0
	minimap.reset_minimap()
	update_hud()

	var pairs = ["cofre_rigard", "cofre_vaelthor", "cofre_unit7"]
	var chosen_pair = pairs[randi() % pairs.size()]
	var pool = dialogue_manager.get_dialogue_pool()
	var dialogues = pool.get(chosen_pair, [])

	if is_fall:
		if audio_manager: audio_manager.play_sfx("sfx_break")
		var t_fall = get_tree().create_timer(1.2)
		t_fall.timeout.connect(func():
			dialogue_manager.trigger_floor_fall_dialogue(floors_fallen)
			var t_vault_dialogues = get_tree().create_timer(4.2)
			t_vault_dialogues.timeout.connect(func():
				_start_vault_dialogue_sequence(dialogues)
			)
		)
	else:
		audio_manager.play_sfx("sfx_portal")
		var t_intro = get_tree().create_timer(1.5)
		t_intro.timeout.connect(func():
			_start_vault_dialogue_sequence(dialogues)
		)

func _start_vault_dialogue_sequence(dialogues: Array):
	if dialogues.is_empty():
		_open_vault_decision_modal()
		return

	_show_single_vault_dialogue(dialogues[0])

	var t_line2 = get_tree().create_timer(4.0)
	t_line2.timeout.connect(func():
		if dialogues.size() > 1:
			_show_single_vault_dialogue(dialogues[1])

		var t_modal = get_tree().create_timer(4.2)
		t_modal.timeout.connect(func():
			if dialogue_panel: dialogue_panel.hide()
			if dialogue_port_frame: dialogue_port_frame.hide()
			_open_vault_decision_modal()
		)
	)

func _show_single_vault_dialogue(line_data: Dictionary):
	var char_key = get_canonical_char_id(line_data.character_id)
	var display_name = line_data.get("speaker", get_display_name(char_key))
	current_dialogue_char = char_key

	if dialogue_port_frame: dialogue_port_frame.show()
	dialogue_label.position = Vector2(145, 15)
	dialogue_label.size = Vector2(dialogue_panel.size.x - 165, 110)
	portrait_rect.texture = diag_tex_normal.get(char_key, null)
	dialogue_label.text = "[b][color=#ffd700]%s[/color][/b]\n%s" % [display_name, line_data.text]
	dialogue_panel.show()

func _open_vault_decision_modal():
	if vault_decision_panel and is_instance_valid(vault_decision_panel):
		vault_decision_panel.queue_free()

	is_vault_decision_open = true
	is_fade_movement_locked = true
	player.velocity = Vector3.ZERO

	dismiss_tutorial_banner()
	if audio_manager: audio_manager.play_sfx("sfx_menu_select")

	var vp_size = get_viewport().get_visible_rect().size
	var font_title = get_game_font("title")
	var font_ui = get_game_font("ui")

	vault_decision_panel = Panel.new()
	vault_decision_panel.size = Vector2(600, 260)
	vault_decision_panel.position = (vp_size - vault_decision_panel.size) / 2.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.07, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	vault_decision_panel.add_theme_stylebox_override("panel", style)
	ui_canvas.add_child(vault_decision_panel)

	var title_lbl = Label.new()
	title_lbl.text = Localization.t("vault_prompt_title", "★ CÂMARA DE DADOS - PROTOCOLO DE EXTRAÇÃO ★")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(10, 16)
	title_lbl.size = Vector2(580, 26)
	title_lbl.add_theme_font_override("font", font_title)
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vault_decision_panel.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = Localization.t("vault_prompt_desc", "Sensores detectaram compartimentos de telemetria despressurizados.\nComo o Capitão deseja proceder?")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.position = Vector2(20, 48)
	desc_lbl.size = Vector2(560, 46)
	desc_lbl.add_theme_font_override("font", font_ui)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vault_decision_panel.add_child(desc_lbl)

	var btn_normal_style = StyleBoxFlat.new()
	btn_normal_style.bg_color = Color(0.04, 0.05, 0.10, 0.95)
	btn_normal_style.border_width_left = 1
	btn_normal_style.border_width_top = 1
	btn_normal_style.border_width_right = 1
	btn_normal_style.border_width_bottom = 1
	btn_normal_style.border_color = Color(1.0, 0.85, 0.2, 0.6)
	btn_normal_style.corner_radius_top_left = 4
	btn_normal_style.corner_radius_top_right = 4
	btn_normal_style.corner_radius_bottom_right = 4
	btn_normal_style.corner_radius_bottom_left = 4

	var btn_focus_style = btn_normal_style.duplicate()
	btn_focus_style.border_color = Color(0.0, 1.0, 0.6, 1.0)
	btn_focus_style.bg_color = Color(0.06, 0.12, 0.18, 0.98)

	var btn_start = Button.new()
	btn_start.text = Localization.t("vault_btn_start", "[ 1 / E ] Iniciar Desafio (10 Baús em 60s)")
	btn_start.position = Vector2(40, 115)
	btn_start.size = Vector2(520, 46)
	btn_start.add_theme_font_override("font", font_ui)
	btn_start.add_theme_font_size_override("font_size", 13)
	btn_start.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	btn_start.add_theme_stylebox_override("normal", btn_normal_style)
	btn_start.add_theme_stylebox_override("hover", btn_focus_style)
	btn_start.add_theme_stylebox_override("focus", btn_focus_style)
	btn_start.pressed.connect(_on_vault_challenge_chosen)
	vault_decision_panel.add_child(btn_start)

	var btn_skip = Button.new()
	btn_skip.text = Localization.t("vault_btn_skip", "[ 2 / ESC ] Cota Segura (Resgatar 5 Baús de EXP e Sair)")
	btn_skip.position = Vector2(40, 175)
	btn_skip.size = Vector2(520, 46)
	btn_skip.add_theme_font_override("font", font_ui)
	btn_skip.add_theme_font_size_override("font_size", 13)
	btn_skip.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	btn_skip.add_theme_stylebox_override("normal", btn_normal_style)
	btn_skip.add_theme_stylebox_override("hover", btn_focus_style)
	btn_skip.add_theme_stylebox_override("focus", btn_focus_style)
	btn_skip.pressed.connect(_on_vault_safe_chosen)
	vault_decision_panel.add_child(btn_skip)

	btn_start.grab_focus()

func _on_vault_safe_chosen():
	is_vault_decision_open = false
	if vault_decision_panel and is_instance_valid(vault_decision_panel):
		vault_decision_panel.queue_free()
		vault_decision_panel = null

	is_fade_movement_locked = false
	vault_chest_state = "finished"
	vault_chests_collected = 5
	total_treasures_collected += 5

	var exp_per_chest = int(35 + ceil(vault_floor_id) * 16)
	var total_safe_exp = exp_per_chest * 5
	party_system.gain_exp_all(total_safe_exp)
	update_hud()

	audio_manager.play_sfx("sfx_portal")
	var p_pod = dungeon_generator._spawn_heal_pod(Vector3(-3.5, 0, 0))
	var p_exit = dungeon_generator._spawn_portal(Vector3(3.5, 0, 0))
	pois.append(p_pod)
	pois.append(p_exit)

	deactivate_portal_shield()
	floor_key_found = true

	var t_title = Localization.t("vault_safe_title", "★ COTA SEGURA ASSEGURADA ★")
	var t_desc = Localization.t("vault_safe_desc", "5 Baús de telemetria foram resgatados em segurança (+%d EXP, +5 Tesouros).\nO Pod médico e o Portal de saída foram ativados.") % total_safe_exp
	show_system_message("[color=#ffd700]" + t_title + "[/color]", t_desc, null, Callable(), "sfx_level_up")

func _on_vault_challenge_chosen():
	is_vault_decision_open = false
	if vault_decision_panel and is_instance_valid(vault_decision_panel):
		vault_decision_panel.queue_free()
		vault_decision_panel = null

	_start_vault_countdown()

func _start_vault_countdown():
	is_fade_movement_locked = true
	vault_chest_state = "countdown"

	var vp_size = get_viewport().get_visible_rect().size
	var font_title = get_game_font("title")

	vault_countdown_label = Label.new()
	vault_countdown_label.position = Vector2(0, vp_size.y * 0.35)
	vault_countdown_label.size = Vector2(vp_size.x, 100)
	vault_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vault_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vault_countdown_label.add_theme_font_override("font", font_title)
	vault_countdown_label.add_theme_font_size_override("font_size", 72)
	vault_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vault_countdown_label.add_theme_constant_override("outline_size", 8)
	vault_countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	ui_canvas.add_child(vault_countdown_label)

	if ResourceLoader.exists("res://audio/sfx_robotic_countdown.wav") or FileAccess.file_exists("res://audio/sfx_robotic_countdown.wav"):
		audio_manager.play_sfx("sfx_robotic_countdown")
	else:
		audio_manager.play_sfx("sfx_menu_move", 0.0, 2.0, 1.0)

	vault_countdown_label.text = "3"
	_pulse_countdown_number()

	var t2 = get_tree().create_timer(1.0)
	t2.timeout.connect(func():
		if is_instance_valid(vault_countdown_label):
			vault_countdown_label.text = "2"
			_pulse_countdown_number()
			if not ResourceLoader.exists("res://audio/sfx_robotic_countdown.wav"):
				audio_manager.play_sfx("sfx_menu_move", 0.0, 2.0, 1.2)
	)

	var t3 = get_tree().create_timer(2.0)
	t3.timeout.connect(func():
		if is_instance_valid(vault_countdown_label):
			vault_countdown_label.text = "1"
			_pulse_countdown_number()
			if not ResourceLoader.exists("res://audio/sfx_robotic_countdown.wav"):
				audio_manager.play_sfx("sfx_menu_move", 0.0, 2.0, 1.4)
	)

	var t_go = get_tree().create_timer(3.0)
	t_go.timeout.connect(func():
		if is_instance_valid(vault_countdown_label):
			vault_countdown_label.text = Localization.t("vault_countdown_go", "VAI!")
			vault_countdown_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
			_pulse_countdown_number()
			if not ResourceLoader.exists("res://audio/sfx_robotic_countdown.wav"):
				audio_manager.play_sfx("sfx_level_up")
	)

	var t_start = get_tree().create_timer(4.0)
	t_start.timeout.connect(func():
		if is_instance_valid(vault_countdown_label):
			vault_countdown_label.queue_free()
			vault_countdown_label = null

		is_fade_movement_locked = false
		vault_chest_state = "cooldown"
		vault_chest_timer = 0.5
	)

func _pulse_countdown_number():
	if not vault_countdown_label or not is_instance_valid(vault_countdown_label): return
	vault_countdown_label.scale = Vector2(1.3, 1.3)
	vault_countdown_label.pivot_offset = vault_countdown_label.size / 2.0
	var tw = create_tween()
	tw.tween_property(vault_countdown_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process_vault_minigame(delta: float):
	if not is_vault_floor or vault_chest_state in ["finished", "idle", "countdown"]:
		return

	var prev_sec = int(ceil(vault_timer))
	vault_timer = max(0.0, vault_timer - delta)
	if int(ceil(vault_timer)) != prev_sec or vault_chest_state == "active":
		update_hud()

	if (vault_timer <= 0.0 or vault_chests_collected >= 10) and vault_chest_state != "finished":
		_finish_vault_minigame()
		return

	vault_chest_timer -= delta

	if vault_chest_state == "active" and is_instance_valid(active_vault_chest_node):
		if player.global_position.distance_to(active_vault_chest_node.position) <= 2.2:
			_collect_vault_chest()

	if vault_chest_timer <= 0.0:
		if vault_chest_state == "active":
			if is_instance_valid(active_vault_chest_node):
				active_vault_chest_node.queue_free()
			vault_chest_state = "cooldown"
			vault_chest_timer = 2.8
		elif vault_chest_state == "cooldown":
			_spawn_next_vault_chest()

func _spawn_next_vault_chest():
	var tile_size = 4.0
	var rx = randi_range(-1, 1) * tile_size
	var rz = randi_range(-1, 1) * tile_size

	active_vault_chest_node = dungeon_generator.spawn_vault_chest(Vector3(rx, 0, rz))
	audio_manager.play_sfx("sfx_portal", 0.1, -4.0)

	vault_chest_state = "active"
	vault_chest_timer = 3.2

func _collect_vault_chest():
	vault_chests_collected += 1
	total_treasures_collected += 1

	audio_manager.play_sfx("sfx_chest_open")

	var exp_per_chest = int(35 + ceil(vault_floor_id) * 16)
	party_system.gain_exp_all(exp_per_chest)

	if is_instance_valid(active_vault_chest_node):
		active_vault_chest_node.queue_free()

	vault_chest_state = "cooldown"
	vault_chest_timer = 2.8

func _finish_vault_minigame():
	vault_chest_state = "finished"
	if is_instance_valid(active_vault_chest_node):
		active_vault_chest_node.queue_free()

	audio_manager.play_sfx("sfx_portal")
	var p_pod = dungeon_generator._spawn_heal_pod(Vector3(-3.5, 0, 0))
	var p_exit = dungeon_generator._spawn_portal(Vector3(3.5, 0, 0))
	pois.append(p_pod)
	pois.append(p_exit)

	deactivate_portal_shield()
	floor_key_found = true

	if vault_chests_collected >= 10:
		var exp_per_chest = int(35 + ceil(vault_floor_id) * 16)
		var bonus_exp = exp_per_chest * 10
		party_system.gain_exp_all(bonus_exp)
		total_treasures_collected += 10
		update_hud()

		var t_win1 = Localization.t("vault_win_step1_title", "★ EXTRAÇÃO CONCLUÍDA (10/10) ★")
		var d_win1 = Localization.t("vault_win_step1_desc", "Incrível! Todos os 10 contêineres de dados foram coletados antes do tempo limite!")

		show_system_message("[color=#ffd700]" + t_win1 + "[/color]", d_win1, null, func():
			var flash_gold = ColorRect.new()
			flash_gold.color = Color(1.0, 0.85, 0.2, 0.75)
			flash_gold.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui_canvas.add_child(flash_gold)
			var tw = create_tween()
			tw.tween_property(flash_gold, "color:a", 0.0, 0.75)
			tw.finished.connect(flash_gold.queue_free)

			var t_win2 = Localization.t("vault_win_step2_title", "★ BÔNUS DUPLO ATIVADO! ★")
			var d_win2 = Localization.t("vault_win_step2_desc", "Desempenho perfeito! O prêmio foi DOBRADO (+%d EXP extra e +10 Tesouros adicionais)!") % bonus_exp
			show_system_message("[color=#ffd700]" + t_win2 + "[/color]", d_win2, null, Callable(), "sfx_level_up")
		, "sfx_level_up")
	else:
		var t_fin = Localization.t("vault_time_up_title", "TEMPO ESGOTADO (%d/10)") % vault_chests_collected
		var d_fin = Localization.t("vault_time_up_desc", "Câmara trancada. O portal de saída e o pod de cura foram ativados.")
		show_system_message("[color=#ffd700]" + t_fin + "[/color]", d_fin, null, Callable(), "sfx_menu_select")
