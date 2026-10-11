# FontManager.gd
class_name FontManager
extends RefCounted

const FONTS_DIR = "res://assets/fonts/"
static var _font_cache: Dictionary = {}

static func get_font(category: String = "ui") -> Font:
	var cat = category.to_lower()

	# Retorna do cache se já foi instanciada (elimina recálculos de memória)
	if _font_cache.has(cat):
		return _font_cache[cat]

	# 1. Tenta carregar do diretório local res://assets/fonts/
	var local_font = _load_local_font_file(cat)
	if local_font:
		# Conecta o fallback CJK (Japonês) no arquivo local para nunca travar no Linux/Windows
		var cjk_fallback = SystemFont.new()
		cjk_fallback.font_names = PackedStringArray([
			"Noto Sans CJK JP", "Yu Gothic", "Meiryo", "MS Gothic", "DejaVu Sans", "Sans-Serif"
		])
		local_font.fallbacks = [cjk_fallback]
		_font_cache[cat] = local_font
		return local_font

	# 2. Fallback via SystemFont com suporte completo nativo
	var sf = SystemFont.new()
	match cat:
		"gameover_title", "victory_title":
			sf.font_names = PackedStringArray([
				"Orbitron", "Exo 2", "Ubuntu Titling", "Ubuntu", "Segoe UI", 
				"Noto Sans CJK JP", "Yu Gothic", "Meiryo", "DejaVu Sans", "Sans-Serif"
			])
			sf.font_weight = 700

		"gameover_report", "victory_stats":
			sf.font_names = PackedStringArray([
				"Consolas", "Cascadia Mono", "Cascadia Code", "Share Tech Mono", 
				"Liberation Mono", "Noto Sans Mono CJK JP", "MS Gothic", "Monospace"
			])
			sf.font_weight = 700

		"boss", "alert", "title":
			sf.font_names = PackedStringArray([
				"Quantum Flat BRK", "Perfect Dark BRK", "Impact", 
				"Arial Black", "Noto Sans CJK JP", "Yu Gothic", "Meiryo", "DejaVu Sans", "Sans-Serif"
			])
			sf.font_weight = 800

		"signage", "wall":
			sf.font_names = PackedStringArray([
				"Impact", "Conduit 2 BRK", "Arial Black", 
				"Noto Sans CJK JP", "Yu Gothic", "Meiryo", "DejaVu Sans", "Segoe UI", "Sans-Serif"
			])
			sf.font_weight = 800

		"arcade", "retro_game", "retro":
			sf.font_names = PackedStringArray([
				"Visitor TT1 BRK", "8-bit Limit BRK", "Terminus", 
				"Noto Sans CJK JP", "Yu Gothic", "Classic Console", "Consolas", "Monospace"
			])
			sf.font_weight = 700

		"mono", "terminal", "csouter", "hud_numbers":
			sf.font_names = PackedStringArray([
				"Terminus", "OCR A Std", "Noto Sans Mono CJK JP", "MS Gothic", "Hack", "Consolas", 
				"Courier New", "Liberation Mono", "Monospace"
			])
			sf.font_weight = 700

		_:
			sf.font_names = PackedStringArray([
				"Roboto", "Lato", "Noto Sans CJK JP", "Yu Gothic", "Meiryo", "DejaVu Sans", "Segoe UI", 
				"Liberation Sans", "Arial", "Sans-Serif"
			])
			sf.font_weight = 600

	_font_cache[cat] = sf
	return sf

static func _load_local_font_file(cat: String) -> FontFile:
	var target_names: Array[String] = []
	match cat:
		"arcade", "retro_game", "retro", "mono", "terminal", "csouter":
			target_names = ["Terminus.ttf", "terminus.ttf", "retro.ttf", "arcade.ttf", "Terminus.otf", "terminus.otf"]
		"title", "boss", "alert":
			target_names = ["Orbitron.ttf", "orbitron.ttf"]

	for f_name in target_names:
		var p = FONTS_DIR + f_name
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			var res = load(p)
			if res is FontFile:
				return res
	return null
