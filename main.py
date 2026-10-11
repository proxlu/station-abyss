import os
import shutil

TARGET_FILE = "Main.gd"

REPLACEMENTS = [
    (
"""func fade_to_transparent(duration: float = 0.5, callback: Callable = Callable()):
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if callback.is_valid(): tween.finished.connect(callback)

func fade_to_black(duration: float = 0.5, callback: Callable = Callable()):
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if callback.is_valid(): tween.finished.connect(callback)""",
"""var current_fade_tween: Tween = null

func fade_to_transparent(duration: float = 0.5, callback: Callable = Callable()):
	if current_fade_tween and current_fade_tween.is_valid():
		current_fade_tween.kill()
	current_fade_tween = create_tween()
	current_fade_tween.tween_property(fade_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if callback.is_valid(): current_fade_tween.finished.connect(callback)

func fade_to_black(duration: float = 0.5, callback: Callable = Callable()):
	if current_fade_tween and current_fade_tween.is_valid():
		current_fade_tween.kill()
	current_fade_tween = create_tween()
	current_fade_tween.tween_property(fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if callback.is_valid(): current_fade_tween.finished.connect(callback)"""
    ),
    (
"""func start_new_game():
	BattleEngine.reset_run_state()
	fade_to_black(0.4, func():
		title_screen.hide()
		party_system.init_party()
		play_cutscene_prologue()
	)""",
"""func start_new_game():
	BattleEngine.reset_run_state()
	if current_fade_tween and current_fade_tween.is_valid():
		current_fade_tween.kill()
	fade_to_black(0.35, func():
		title_screen.hide()
		party_system.init_party()
		play_cutscene_prologue()
	)"""
    ),
    (
"""	load_floor(1)

	hud_panel.show()
	minimap.show()
	audio_manager.play_bgm("bgm_dungeon", true, 1.0)""",
"""	if cutscene_layer: cutscene_layer.hide()
	if cutscene_bg: cutscene_bg.texture = null
	if cutscene_panel: cutscene_panel.hide()

	load_floor(1)

	hud_panel.show()
	minimap.show()
	audio_manager.play_bgm("bgm_dungeon", true, 1.0)"""
    ),
    (
"""func end_story_cutscene():
	stop_cutscene_bg_shake()
	cutscene_blink_id += 1
	is_in_cutscene = false
	is_cutscene_input_locked = true
	cutscene_panel.hide()
	cutscene_prompt.hide()
	
	hold_cutscene_black = false
	cutscene_layer.hide()
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.color.a = 1.0
		fade_to_transparent(0.6)

	if cutscene_on_complete.is_valid():
		var cb = cutscene_on_complete
		cutscene_on_complete = Callable()
		cb.call()""",
"""func end_story_cutscene():
	stop_cutscene_bg_shake()
	cutscene_blink_id += 1
	is_in_cutscene = false
	is_cutscene_input_locked = true
	cutscene_panel.hide()
	cutscene_prompt.hide()
	hold_cutscene_black = false
	cutscene_layer.hide()
	if cutscene_bg: cutscene_bg.texture = null

	var cb = cutscene_on_complete
	cutscene_on_complete = Callable()
	if cb.is_valid():
		cb.call()
	else:
		fade_to_transparent(0.5)"""
    ),
    (
"""	start_story_cutscene(cutscene_dialogues, func():
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.color.a = 1.0
		cutscene_layer.hide()
		cutscene_bg.texture = null
		cutscene_panel.hide()
		if hud_panel: hud_panel.hide()
		if minimap: minimap.hide()
		if interaction_label: interaction_label.hide()
		has_chronodox = false
		if party_system: party_system.has_chronodox = false
		if battle_engine: battle_engine.has_chronodox = false
		battle_engine.start_boss_battle(get_viewport(), ui_canvas, party_system, audio_manager, current_floor, etapa_dois, last_dungeon_snapshot, has_csouter)
	)""",
"""	start_story_cutscene(cutscene_dialogues, func():
		cutscene_layer.hide()
		cutscene_bg.texture = null
		cutscene_panel.hide()
		if hud_panel: hud_panel.hide()
		if minimap: minimap.hide()
		if interaction_label: interaction_label.hide()
		has_chronodox = false
		if party_system: party_system.has_chronodox = false
		if battle_engine: battle_engine.has_chronodox = false
		battle_engine.start_boss_battle(get_viewport(), ui_canvas, party_system, audio_manager, current_floor, etapa_dois, last_dungeon_snapshot, has_csouter)
		fade_to_transparent(0.6)
	)"""
    ),
    (
"""func play_cutscene_post_credits():
	hold_cutscene_black = true
	silence_map_audio()
	audio_manager.stop_bgm()""",
"""func play_cutscene_post_credits():
	if credits_screen:
		credits_screen.hide()
	hold_cutscene_black = true
	silence_map_audio()
	audio_manager.stop_bgm()"""
    ),
    (
"""		"saria_e_yuna":
			dialogues = [
				{
					"character_id": "saria_e_yuna",
					"speaker": Localization.t("name_saria_yuna", "Saria & Yuna"),
					"image": "cutscene_saria_e_yuna",
					"delay_before": 0.8,
					"text": Localization.t("cs_saria_yuna_speak")
				},
				{
					"character_id": "alien",
					"speaker": "Vaelthor",
					"text": Localization.t("cs_saria_yuna_reply")
				}
			]""",
"""		"saria_e_yuna":
			dialogues = [
				{
					"character_id": "saria_e_yuna",
					"speaker": "Saria",
					"image": "cutscene_saria_e_yuna",
					"delay_before": 0.8,
					"text": Localization.t("cs_saria_yuna_speak")
				},
				{
					"character_id": "saria_e_yuna",
					"speaker": "Yuna",
					"text": Localization.t("cs_saria_yuna_speak_2")
				},
				{
					"character_id": "alien",
					"speaker": "Vaelthor",
					"text": Localization.t("cs_saria_yuna_reply")
				}
			]"""
    ),
    (
"""			start_story_cutscene(dying_dialogue, func():
				# NÃO FORÇAMOS MAIS O FADE AQUI! O end_story_cutscene já faz o fade_to_transparent(0.4) suavemente.
				if dead_without_drive.size() > 0:
					for dead_char in dead_without_drive: spawn_data_orb(dead_char, player.global_position)
				if hud_panel: hud_panel.show()
				if minimap: minimap.show()
				update_hud()
			)""",
"""			start_story_cutscene(dying_dialogue, func():
				if dead_without_drive.size() > 0:
					for dead_char in dead_without_drive: spawn_data_orb(dead_char, player.global_position)
				if hud_panel: hud_panel.show()
				if minimap: minimap.show()
				update_hud()
				fade_to_transparent(0.4)
			)"""
    )
]

def main():
    if not os.path.exists(TARGET_FILE):
        print(f"[ERRO] {TARGET_FILE} nao encontrado no diretorio atual.")
        return

    backup_path = TARGET_FILE + ".bak"
    if not os.path.exists(backup_path):
        shutil.copy2(TARGET_FILE, backup_path)
        print(f"[BACKUP] Criado: {backup_path}")

    with open(TARGET_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    modified = content
    for idx, (old_text, new_text) in enumerate(REPLACEMENTS, 1):
        if old_text not in modified:
            print(f"[AVISO] Trecho {idx} nao encontrado. Pode ja ter sido alterado.")
            continue
        modified = modified.replace(old_text, new_text, 1)
        print(f"[OK] Trecho {idx} aplicado.")

    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        f.write(modified)

    print("[CONCLUIDO] Main.gd atualizado com sucesso.")

if __name__ == "__main__":
    main()
