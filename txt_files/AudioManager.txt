# AudioManager.gd
extends Node

const AUDIO_DIR = "res://audio/"

# ==============================================================================
# TRATAMENTO PONTUAL DOS ÁUDIOS ESTOURADOS / ALTOS
# ==============================================================================
const SFX_ATTENUATION: Dictionary = {
	"sfx_paradox_egnite": -8.0,
	"sfx_portal": -6.0,
	"sfx_level_up": -10.0,
	"sfx_flee": +15.0
}

const DEFAULT_BGM_VOLUME: float = -6.0

const BGM_CUSTOM_VOLUMES: Dictionary = {
	"bgm_terminal": -15.0,       # Reduzido, muito alto
	"bgm_spaceship": 0.0,        # Som de ambiente da nave já gravado suave (-30 dB)
	"bgm_space_spooter": -10.0,
	"bgm_chronodox": -10.0
}

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_CHANNELS = 8

var current_bgm_name: String = ""
var is_loop_enabled: bool = false
var is_auto_fade_enabled: bool = true

const AUTO_FADE_OUT_TIME: float = 2.5

func _init():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	
	for i in range(MAX_SFX_CHANNELS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		sfx_players.append(p)

func _ready():
	if bgm_player.get_parent() == null:
		add_child(bgm_player)
		bgm_player.finished.connect(_on_bgm_finished)
	
	for p in sfx_players:
		if p.get_parent() == null:
			add_child(p)

func _process(_delta):
	if is_auto_fade_enabled and bgm_player and bgm_player.playing and bgm_player.stream:
		var total_len = bgm_player.stream.get_length()
		if total_len > 4.0:
			var cur_pos = bgm_player.get_playback_position()
			var remaining = total_len - cur_pos
			
			if remaining <= AUTO_FADE_OUT_TIME and remaining > 0.0:
				var base_vol = BGM_CUSTOM_VOLUMES.get(current_bgm_name, DEFAULT_BGM_VOLUME)
				var progress = 1.0 - (remaining / AUTO_FADE_OUT_TIME)
				bgm_player.volume_db = lerp(base_vol, -60.0, progress)

func _on_bgm_finished():
	if is_loop_enabled and current_bgm_name != "" and bgm_player:
		var target_vol = BGM_CUSTOM_VOLUMES.get(current_bgm_name, DEFAULT_BGM_VOLUME)
		bgm_player.volume_db = -40.0
		bgm_player.play()
		var tween_in = create_tween()
		tween_in.tween_property(bgm_player, "volume_db", target_vol, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		current_bgm_name = ""

func play_bgm(track_name: String, loop: bool = true, pitch: float = 1.0, auto_fade_end: bool = true):
	is_loop_enabled = loop
	is_auto_fade_enabled = auto_fade_end
	
	var extensions = [".ogg", ".mp3", ".wav"]
	var found_path = ""
	for ext in extensions:
		var path = AUDIO_DIR + track_name + ext
		if ResourceLoader.exists(path):
			found_path = path
			break
			
	if found_path == "":
		current_bgm_name = ""
		stop_bgm()
		return
		
	if bgm_player and current_bgm_name == track_name and bgm_player.playing:
		var tween = create_tween()
		tween.tween_property(bgm_player, "pitch_scale", pitch, 0.4).set_trans(Tween.TRANS_SINE)
		return
		
	var stream = load(found_path)
	current_bgm_name = track_name
	var target_vol = BGM_CUSTOM_VOLUMES.get(track_name, DEFAULT_BGM_VOLUME)

	if bgm_player:
		bgm_player.stream = stream
		bgm_player.pitch_scale = pitch
		bgm_player.volume_db = target_vol
		bgm_player.play()

func stop_bgm(fade_duration: float = 0.0):
	current_bgm_name = ""
	is_loop_enabled = false
	
	if not bgm_player:
		return
	
	if fade_duration > 0.0 and bgm_player.playing:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -60.0, fade_duration).set_trans(Tween.TRANS_SINE)
		tween.finished.connect(func():
			if current_bgm_name == "" and bgm_player:
				bgm_player.stop()
				bgm_player.volume_db = DEFAULT_BGM_VOLUME
				bgm_player.pitch_scale = 1.0
		)
	else:
		if bgm_player.playing:
			bgm_player.stop()
		bgm_player.volume_db = DEFAULT_BGM_VOLUME
		bgm_player.pitch_scale = 1.0

func play_sfx(sfx_name: String, pitch_randomness: float = 0.0, volume_offset: float = 0.0, base_pitch: float = 1.0):
	var extensions = [".wav", ".ogg", ".mp3"]
	var found_path = ""
	for ext in extensions:
		var path = AUDIO_DIR + sfx_name + ext
		if ResourceLoader.exists(path):
			found_path = path
			break
			
	if found_path == "":
		return
		
	var stream = load(found_path)
	
	var base_adjustment = SFX_ATTENUATION.get(sfx_name, 0.0)
	var final_volume = base_adjustment + volume_offset

	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = final_volume
			p.pitch_scale = base_pitch + randf_range(-pitch_randomness, pitch_randomness)
			p.play()
			return
			
	if sfx_players.size() > 0:
		sfx_players[0].stream = stream
		sfx_players[0].volume_db = final_volume
		sfx_players[0].pitch_scale = base_pitch + randf_range(-pitch_randomness, pitch_randomness)
		sfx_players[0].play()
		
