# PartySystem.gd
extends Node

signal party_updated
signal party_leveled_up(leveled_names: Array, new_levels: Dictionary)

class Member:
	var id: String
	var name: String
	var race: String
	var role: String
	var level: int = 1
	var exp: int = 0
	var exp_next: int = 100

	# Atributos Atuais / Máximos
	var hp: int
	var max_hp: int
	var shield: int = 0
	var mp: int
	var max_mp: int
	var speed: int
	var atk: int
	var magic_power: int
	var heal_power: int
	var def: int

	# Atributos Base
	var base_hp: int
	var base_mp: int
	var base_spd: int
	var base_atk: int
	var base_mag: int
	var base_heal: int
	var base_def: int

	var skill_attack_lvl: int = 1
	var skill_magic_lvl: int = 1
	var skill_heal_lvl: int = 1

	var carga_slot_icon: String = ""
	var has_data_drive: bool = false

	# BATERIA (Hole Keeper Modifiers)
	var battery_tag: String = "Normal"
	var battery_mod_id: String = "none"
	var battery_hp_offset: int = 0
	var battery_mp_offset: int = 0
	var battery_atk_offset: int = 0
	var battery_spd_offset: int = 0

	func _init(p_id, p_name, p_race, p_role, p_hp, p_mp, p_spd, p_atk, p_mag, p_heal, p_def):
		id = p_id
		name = p_name
		race = p_race
		role = p_role

		base_hp = p_hp
		base_mp = p_mp
		base_spd = p_spd
		base_atk = p_atk
		base_mag = p_mag
		base_heal = p_heal
		base_def = p_def

		max_hp = p_hp
		hp = p_hp
		shield = 0
		max_mp = p_mp
		mp = p_mp
		speed = p_spd
		atk = p_atk
		magic_power = p_mag
		heal_power = p_heal
		def = p_def

		if p_id == "humano":
			carga_slot_icon = "🗡️"
			has_data_drive = false
		else:
			carga_slot_icon = ""
			has_data_drive = false

	func apply_battery_mod(mod_id: String, tag: String):
		restore_battery_to_normal()
		battery_mod_id = mod_id
		battery_tag = tag

		match mod_id:
			"mod_1": # -MP / +HP (Bateria de Célula Residual)
				battery_hp_offset = 40
				battery_mp_offset = -20
			"mod_2": # -VEL / +DMG (Bateria de Sobrecarga)
				battery_spd_offset = -4
				battery_atk_offset = 12
			"mod_3": # Cura % (Bateria Regenerativa Quântica)
				battery_hp_offset = 15
				hp = max_hp
				mp = max_mp
			"mod_4": # -HP / +MP (Bateria de Transmutação)
				battery_hp_offset = -25
				battery_mp_offset = 45

		max_hp = max(10, max_hp + battery_hp_offset)
		max_mp = max(5, max_mp + battery_mp_offset)
		atk = max(1, atk + battery_atk_offset)
		speed = max(1, speed + battery_spd_offset)
		hp = clamp(hp, 1, max_hp)
		mp = clamp(mp, 0, max_mp)

	func restore_battery_to_normal():
		if battery_mod_id == "none": return
		max_hp = max(10, max_hp - battery_hp_offset)
		max_mp = max(5, max_mp - battery_mp_offset)
		atk = max(1, atk - battery_atk_offset)
		speed = max(1, speed - battery_spd_offset)

		battery_hp_offset = 0
		battery_mp_offset = 0
		battery_atk_offset = 0
		battery_spd_offset = 0
		battery_mod_id = "none"
		battery_tag = "Normal"

		hp = clamp(hp, 1, max_hp)
		mp = clamp(mp, 0, max_mp)

var members: Dictionary = {}
var has_perfect_defense_buff: bool = false
var is_kira_away: bool = false
var is_alien_endless_skin: bool = false
var has_chronodox: bool = false

func _ready():
	init_party()

func init_party():
	members.clear()
	has_perfect_defense_buff = false
	is_kira_away = false
	is_alien_endless_skin = false

	members["humano"] = Member.new("humano", "Rigard", "Humano", "Capitão", 120, 40, 12, 18, 10, 8, 12)
	members["mutante"] = Member.new("mutante", "Kira", "Mutante", "Tanque / Brawler", 160, 20, 15, 24, 5, 0, 18)
	members["alien"] = Member.new("alien", "Vaelthor", "Alienígena", "Dano Elemental", 90, 80, 8, 8, 30, 10, 8)
	members["robo"] = Member.new("robo", "Unit-7", "Androide", "Suporte", 110, 60, 10, 10, 12, 22, 14)

func unlock_perfect_defense():
	has_perfect_defense_buff = true
	emit_signal("party_updated")

func equip_data_drive(char_id: String) -> bool:
	if not members.has(char_id) or char_id == "humano":
		return false
	var m = members[char_id]
	m.has_data_drive = true
	m.carga_slot_icon = "💾"
	sync_member_to_rigard(char_id)
	emit_signal("party_updated")
	return true

func apply_proportional_growth(m: Member):
	var hp_gain = int(m.base_hp * 0.12) + (randi() % 5)
	var mp_gain = int(m.base_mp * 0.14) + (randi() % 4)
	var atk_gain = max(1, int(round(m.base_atk * 0.12)))
	var def_gain = max(1, int(round(m.base_def * 0.12)))
	var spd_gain = max(1, int(round(m.base_spd * 0.10)))
	var mag_gain = int(round(m.base_mag * 0.15))
	var heal_gain = int(round(m.base_heal * 0.16))

	m.max_hp += hp_gain
	m.max_mp += mp_gain
	if m.hp > 0: m.hp = m.max_hp
	m.mp = m.max_mp
	m.atk += atk_gain
	m.def += def_gain
	m.speed += spd_gain
	m.magic_power += mag_gain
	m.heal_power += heal_gain

func sync_member_to_rigard(char_id: String):
	if not members.has(char_id) or char_id == "humano": return
	var rigard = members["humano"]
	var m = members[char_id]

	if m.level < rigard.level or (m.level == rigard.level and m.exp < rigard.exp):
		var level_diff = rigard.level - m.level
		for _i in range(level_diff):
			apply_proportional_growth(m)

		m.level = rigard.level
		m.exp = rigard.exp
		m.exp_next = rigard.exp_next
		m.hp = min(m.hp, m.max_hp)
		m.mp = min(m.mp, m.max_mp)

func get_eligible_drive_members() -> Array[String]:
	var eligible: Array[String] = []
	for k in ["mutante", "alien", "robo"]:
		if members.has(k) and not members[k].has_data_drive:
			eligible.append(k)
	return eligible

func gain_exp_all(amount: int):
	var leveled_names: Array = []
	var new_levels: Dictionary = {}

	for k in members.keys():
		var m = members[k]
		if m.hp > 0 or m.has_data_drive or (k == "mutante" and is_kira_away):
			m.exp += amount
			var did_level = false
			while m.exp >= m.exp_next:
				m.exp -= m.exp_next
				m.level += 1
				m.exp_next = int(m.exp_next * 1.5)

				apply_proportional_growth(m)
				did_level = true

			if did_level:
				leveled_names.append(m.name)
				new_levels[m.name] = m.level

	for k in ["mutante", "alien", "robo"]:
		if members.has(k) and members[k].has_data_drive:
			sync_member_to_rigard(k)

	emit_signal("party_updated")
	if leveled_names.size() > 0:
		emit_signal("party_leveled_up", leveled_names, new_levels)

func upgrade_skill(char_id: String, skill_type: String):
	if not members.has(char_id): return
	var m = members[char_id]

	if skill_type == "attack":
		m.skill_attack_lvl += 1
		m.max_hp += 10
		m.speed += 2
		m.atk += 4
	elif skill_type == "magic":
		m.skill_magic_lvl += 1
		m.max_mp += 15
		m.magic_power += 5
	elif skill_type == "heal":
		m.skill_heal_lvl += 1
		m.max_hp += 8
		m.max_mp += 8
		m.speed += 1
		m.heal_power += 4

	m.hp = min(m.hp, m.max_hp)
	m.mp = min(m.mp, m.max_mp)
	emit_signal("party_updated")

func heal_all_full():
	for k in members.keys():
		var m = members[k]
		m.hp = m.max_hp
		m.mp = m.max_mp
	emit_signal("party_updated")
