#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "    LIMPANDO COMPATIBILIDADE DE NOMES ANTIGOS             "
echo "=========================================================="

python3 - << 'EOF'
import os

def find_file(name):
    for root, dirs, files in os.walk("."):
        if name in files:
            return os.path.join(root, name)
    return None

def patch_file(filepath, replacements):
    if not filepath or not os.path.exists(filepath):
        return False
    
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Backup
    with open(filepath + ".bak", "w", encoding="utf-8") as f:
        f.write(content)

    for old, new in replacements:
        content = content.replace(old, new)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"[OK] Limpo com sucesso: {filepath}")
    return True

# ----------------------------------------------------------------------
# 1. MAIN.GD
# ----------------------------------------------------------------------
main_file = find_file("Main.gd")
main_replacements = [
    # Simplifica load_texture_safe
    ('''static func load_texture_safe(base_name: String) -> Texture2D:
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
	return null''',
     '''static func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var full_path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
			return load(full_path)
	return null'''),

    # Linhas com ternários redundantes
    ('var scene_name = "cutscene_prologo" if load_texture_safe("cutscene_prologo") else "cutscene_prologo"',
     'var scene_name = "cutscene_prologo"'),
    ('var scene_name = "cutscene_chronodox" if load_texture_safe("cutscene_chronodox") else "cutscene_chronodox"',
     'var scene_name = "cutscene_chronodox"'),
    ('var empty_bg_name = "cutscene_sem_bg" if load_texture_safe("cutscene_sem_bg") else "cutscene_sem_bg"',
     'var empty_bg_name = "cutscene_sem_bg"'),
    ('var sc1 = "cutscene_final_1" if load_texture_safe("cutscene_final_1") else "cutscene_final_1"',
     'var sc1 = "cutscene_final_1"'),
    ('var sc2 = "cutscene_final_2" if load_texture_safe("cutscene_final_2") else "cutscene_final_2"',
     'var sc2 = "cutscene_final_2"'),
    ('var sc3 = "cutscene_final_3" if load_texture_safe("cutscene_final_3") else "cutscene_final_3"',
     'var sc3 = "cutscene_final_3"'),
    ('var sc4 = "cutscene_final_4" if load_texture_safe("cutscene_final_4") else "cutscene_final_4"',
     'var sc4 = "cutscene_final_4"'),

    # Checagens duplas
    ('''		var tut_tex = load_texture_safe("ui_tutorial")
	if not tut_tex: tut_tex = load_texture_safe("ui_tutorial")''',
     '''		var tut_tex = load_texture_safe("ui_tutorial")'''),
    ('''		var norm_tex = load_texture_safe("char_port_" + c)
		if not norm_tex: norm_tex = load_texture_safe("char_port_" + c)''',
     '''		var norm_tex = load_texture_safe("char_port_" + c)'''),
    ('''		var clos_tex = load_texture_safe("char_closed_" + c)
		if not clos_tex: clos_tex = load_texture_safe("char_closed_" + c)''',
     '''		var clos_tex = load_texture_safe("char_closed_" + c)'''),
    ('''		var open_tex = load_texture_safe("prop_chest_open")
			if not open_tex: open_tex = load_texture_safe("prop_chest_open")''',
     '''		var open_tex = load_texture_safe("prop_chest_open")'''),
    ('''		var d_tex = load_texture_safe("ui_item_detector")
				if not d_tex: d_tex = load_texture_safe("char_port_detector")''',
     '''		var d_tex = load_texture_safe("ui_item_detector")'''),
    ('''	var tex_closed = load_texture_safe("cutscene_final_5")
	if not tex_closed: tex_closed = load_texture_safe("cutscene_final_5")''',
     '''	var tex_closed = load_texture_safe("cutscene_final_5")'''),
    ('''	var tex_open = load_texture_safe("cutscene_final_6")
	if not tex_open: tex_open = load_texture_safe("cutscene_final_6")''',
     '''	var tex_open = load_texture_safe("cutscene_final_6")'''),
]
patch_file(main_file, main_replacements)

# ----------------------------------------------------------------------
# 2. BATTLEENGINE.GD
# ----------------------------------------------------------------------
bat_file = find_file("BattleEngine.gd")
bat_replacements = [
    # load_enemy_texture direto
    ('''func load_enemy_texture(base_id: String) -> Texture2D:
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
	return null''',
     '''func load_enemy_texture(base_id: String) -> Texture2D:
	if base_id == "enemy_alien_chest":
		return load_texture_safe("prop_chest_closed")
	return load_texture_safe(base_id)'''),

    # load_texture_safe enxuta
    ('''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	for ext in extensions:
		var path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return load(path)
	return null''',
     '''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return load(path)
	return null'''),

    # Limpeza de preload_portrait_cache
    ('''		var norm_tex = load_texture_safe("char_port_" + c)
		if not norm_tex: norm_tex = load_texture_safe("char_port_" + c)
		if norm_tex: tex_cache_normal[c] = norm_tex

		var clos_tex = load_texture_safe("char_closed_" + c)
		if not clos_tex: clos_tex = load_texture_safe("char_closed_" + c)
		if clos_tex: tex_cache_closed[c] = clos_tex
		elif tex_cache_normal.has(c): tex_cache_closed[c] = tex_cache_normal[c]

		var damg_tex = load_texture_safe("char_damaged_" + c)
		if not damg_tex: damg_tex = load_texture_safe("char_damaged_" + c)
		if damg_tex: tex_cache_damaged[c] = damg_tex
		elif tex_cache_normal.has(c): tex_cache_damaged[c] = tex_cache_normal[c]''',
     '''		var norm_tex = load_texture_safe("char_port_" + c)
		if norm_tex: tex_cache_normal[c] = norm_tex

		var clos_tex = load_texture_safe("char_closed_" + c)
		if clos_tex: tex_cache_closed[c] = clos_tex
		elif tex_cache_normal.has(c): tex_cache_closed[c] = tex_cache_normal[c]

		var damg_tex = load_texture_safe("char_damaged_" + c)
		if damg_tex: tex_cache_damaged[c] = damg_tex
		elif tex_cache_normal.has(c): tex_cache_damaged[c] = tex_cache_normal[c]'''),
]
patch_file(bat_file, bat_replacements)

# ----------------------------------------------------------------------
# 3. PROCEDURALDUNGEON.GD
# ----------------------------------------------------------------------
pd_file = find_file("ProceduralDungeon.gd")
pd_replacements = [
    ('''static func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]

	# Compatibilidade bidirecional de nomes
	if base_name == "prop_chest_closed": candidates.append("prop_chest_closed")
	elif base_name == "prop_chest_closed": candidates.insert(0, "prop_chest_closed")
	elif base_name == "prop_chest_open": candidates.append("prop_chest_open")
	elif base_name == "prop_chest_open": candidates.insert(0, "prop_chest_open")
	elif base_name == "prop_heal_pod": candidates.append_array(["prop_heal_pod", "prop_heal_pod"])
	elif base_name in ["prop_heal_pod", "prop_heal_pod"]: candidates.insert(0, "prop_heal_pod")
	elif base_name == "prop_portal": candidates.append("portal")
	elif base_name == "portal": candidates.insert(0, "prop_portal")
	elif base_name == "prop_spooter_on": candidates.append("prop_spooter_on")
	elif base_name == "prop_spooter_on": candidates.insert(0, "prop_spooter_on")
	elif base_name == "prop_spooter_off": candidates.append("prop_spooter_off")
	elif base_name == "prop_spooter_off": candidates.insert(0, "prop_spooter_off")
	elif base_name == "prop_terminal_on": candidates.append("prop_terminal_on")
	elif base_name == "prop_terminal_on": candidates.insert(0, "prop_terminal_on")
	elif base_name == "prop_terminal_off": candidates.append("prop_terminal_off")
	elif base_name == "prop_terminal_off": candidates.insert(0, "prop_terminal_off")
	elif base_name == "prop_csouter_ground": candidates.append("prop_csouter_ground")
	elif base_name == "prop_csouter_ground": candidates.insert(0, "prop_csouter_ground")

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null''',
     '''static func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var full_path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
			return load(full_path)
	return null'''),
]
patch_file(pd_file, pd_replacements)

# ----------------------------------------------------------------------
# 4. PARTYMENU.GD, TITLESCREEN.GD, GAMEOVER.GD
# ----------------------------------------------------------------------
for fname in ["PartyMenu.gd", "TitleScreen.gd", "GameOver.gd"]:
    fpath = find_file(fname)
    if fpath:
        repls = [
            ('''func load_texture_safe(base_name: String) -> Texture2D:
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
	return null''',
             '''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var full_path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
			return load(full_path)
	return null'''),
            ('''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]
	if base_name == "ui_gameover_illustration": candidates.append("ui_gameover_illustration")
	elif base_name == "ui_gameover_illustration": candidates.insert(0, "ui_gameover_illustration")

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null''',
             '''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var full_path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
			return load(full_path)
	return null'''),
            ('''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG", ""]
	var candidates = [base_name]
	if base_name == "ui_title_illustration": candidates.append("ui_title_illustration")
	elif base_name == "ui_title_illustration": candidates.insert(0, "ui_title_illustration")
	elif base_name == "ui_title_logo": candidates.append("ui_title_logo")
	elif base_name == "ui_title_logo": candidates.insert(0, "ui_title_logo")

	for c in candidates:
		for ext in extensions:
			var full_path = ASSETS_DIR + c + ext
			if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
				return load(full_path)
	return null''',
             '''func load_texture_safe(base_name: String) -> Texture2D:
	var extensions = [".png", ".webp", ".jpg"]
	for ext in extensions:
		var full_path = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
			return load(full_path)
	return null'''),
            ('if not full_tex: full_tex = load_texture_safe("char_full_" + char_id)', ''),
            ('if not ill_tex: ill_tex = load_texture_safe("ui_title_illustration")', ''),
            ('if not logo_tex: logo_tex = load_texture_safe("ui_title_logo")', ''),
        ]
        patch_file(fpath, repls)

print("==========================================================")
print("  COMPATIBILIDADE ANTIGA REMOVIDA COM SUCESSO!            ")
print("==========================================================")
EOF
