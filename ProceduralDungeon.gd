# ProceduralDungeon.gd
extends Node3D

const ASSETS_DIR: String = "res://assets/"

var tile_size: float = 4.0
var wall_height: float = 3.5
var floor_parent: Node3D
var pulsing_lights: Array[Dictionary] = []
var rotating_shields: Array[Node3D] = []

const GRID_WIDTH: int = 17
const GRID_HEIGHT: int = 17

const CHEST_TARGET_HEIGHT: float = 1.1
const HEAL_POD_TARGET_HEIGHT: float = 1.9
const PORTAL_TARGET_HEIGHT: float = 2.4
const ARCADE_TARGET_HEIGHT: float = 1.85
const TERMINAL_TARGET_HEIGHT: float = 1.85
const CSOUTER_TARGET_HEIGHT: float = 0.28

func _process(delta):
	if not floor_parent or not is_instance_valid(floor_parent):
		return

	var now = Time.get_ticks_msec() * 0.001
	for p in pulsing_lights:
		if is_instance_valid(p.light):
			p.light.light_energy = p.base_energy + sin(now * p.speed + p.phase) * p.amp

	for s in rotating_shields:
		if is_instance_valid(s):
			s.rotation.y += delta * 0.35

func generate_floor(floor_num: int, etapa_dois: bool = false, has_buff: bool = false, eligible_drives_remaining: bool = true, has_csouter: bool = false, has_detector: bool = false) -> Dictionary:
	pulsing_lights.clear()
	rotating_shields.clear()

	if floor_parent:
		floor_parent.queue_free()

	floor_parent = Node3D.new()
	floor_parent.name = "FloorParent_Level_%d" % floor_num
	add_child(floor_parent)

	var maze_data = _carve_maze_grid()
	var grid: Array = maze_data.grid
	var floor_cells: Array = maze_data.floor_cells
	var dead_ends: Array = maze_data.dead_ends
	var spawn_rot_y: float = maze_data.spawn_rot_y

	var materials: Dictionary = _build_materials(floor_num)
	_build_3d_geometry(grid, materials, floor_num)
	_place_sector_signage(grid, floor_num)

	var should_spawn_special = etapa_dois or (randf() < 0.20)
	var spawn_mode = "none"
	if should_spawn_special:
		var can_spooter = not has_buff
		var can_terminal = eligible_drives_remaining
		if can_spooter and can_terminal:
			spawn_mode = "arcade" if randf() < 0.50 else "terminal"
		elif can_spooter:
			spawn_mode = "arcade"
		elif can_terminal:
			spawn_mode = "terminal"

	var generated_mission: Dictionary = {}
	if spawn_mode == "terminal":
		generated_mission = _create_random_mission(floor_num)

	var pois: Array = _distribute_pois(dead_ends, floor_cells, spawn_mode, generated_mission, has_csouter, etapa_dois, has_detector, floor_num, grid)

	var spawn_wx: float = (1 - GRID_WIDTH / 2.0) * tile_size
	var spawn_wz: float = (1 - GRID_HEIGHT / 2.0) * tile_size

	return {
		"spawn_pos": Vector2(spawn_wx, spawn_wz),
		"spawn_rot_y": spawn_rot_y,
		"pois": pois,
		"floor_cells": floor_cells,
		"floor_mission": generated_mission
	}

func _create_random_mission(_floor_num: int) -> Dictionary:
	var enemy_pool = [
		{"id": "enemy_mutant_beast", "name": "Mutantes"},
		{"id": "enemy_drone", "name": "Drones"},
		{"id": "enemy_corrupted_android", "name": "Androides"},
		{"id": "enemy_alien_scout", "name": "Alien Scouts"}
	]
	var chosen_enemy = enemy_pool[randi() % enemy_pool.size()]
	var target_kills = [5, 10, 20][randi() % 3]

	return {
		"enemy_id": chosen_enemy.id,
		"enemy_name": chosen_enemy.name,
		"target_kills": target_kills,
		"current_kills": 0,
		"is_active": false,
		"is_completed": false
	}

func _carve_maze_grid() -> Dictionary:
	var grid: Array = []
	for y in range(GRID_HEIGHT):
		var row: Array = []
		row.resize(GRID_WIDTH)
		row.fill(0)
		grid.append(row)

	var start_cell = Vector2i(1, 1)
	grid[start_cell.y][start_cell.x] = 1
	var stack: Array[Vector2i] = [start_cell]
	var dead_ends: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = [start_cell]

	var dirs = [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]

	while stack.size() > 0:
		var current = stack.back()
		var valid_neighbors: Array[Vector2i] = []

		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			if nx > 0 and nx < GRID_WIDTH - 1 and ny > 0 and ny < GRID_HEIGHT - 1:
				if grid[ny][nx] == 0:
					valid_neighbors.append(d)

		if valid_neighbors.size() > 0:
			var chosen_dir = valid_neighbors[randi() % valid_neighbors.size()]
			var wall_x = current.x + chosen_dir.x / 2
			var wall_y = current.y + chosen_dir.y / 2
			var next_x = current.x + chosen_dir.x
			var next_y = current.y + chosen_dir.y

			grid[wall_y][wall_x] = 1
			grid[next_y][next_x] = 1

			floor_cells.append(Vector2i(wall_x, wall_y))
			floor_cells.append(Vector2i(next_x, next_y))
			stack.append(Vector2i(next_x, next_y))
		else:
			if current != start_cell and not current in dead_ends:
				dead_ends.append(current)
			stack.pop_back()

	for y in range(2, GRID_HEIGHT - 2, 2):
		for x in range(2, GRID_WIDTH - 2, 2):
			if grid[y][x] == 0 and randf() < 0.15:
				if (grid[y-1][x] == 1 and grid[y+1][x] == 1) or (grid[y][x-1] == 1 and grid[y][x+1] == 1):
					grid[y][x] = 1
					floor_cells.append(Vector2i(x, y))

	var spawn_rot_y: float = 0.0
	if grid[1][2] == 1: spawn_rot_y = -PI / 2.0
	elif grid[2][1] == 1: spawn_rot_y = PI

	return {
		"grid": grid,
		"floor_cells": floor_cells,
		"dead_ends": dead_ends,
		"spawn_rot_y": spawn_rot_y
	}

func _build_materials(floor_num: int) -> Dictionary:
	var wall_mat = StandardMaterial3D.new()
	var wall_tex_name = "env_wall_metal_cyan"
	if not _texture_exists(wall_tex_name): wall_tex_name = "env_wall_metal_cyan.png"

	if floor_num % 3 == 0:
		var purple_pool = ["env_wall_metal_purple.png", "env_wall_metal_purple.png", "env_wall_metal_purple_alt.png", "env_wall_metal_purple_alt.png", "env_wall_metal_grey.png", "env_wall_metal_grey.png"]
		for tex in purple_pool:
			if ResourceLoader.exists(ASSETS_DIR + tex) or FileAccess.file_exists(ASSETS_DIR + tex):
				wall_tex_name = tex
				break
	elif floor_num % 2 == 0:
		var orange_pool = ["env_wall_metal_orange.png", "env_wall_metal_orange.png", "env_wall_metal_orange_alt.png", "env_wall_metal_orange_alt.png", "env_wall_metal_grey.png", "env_wall_metal_grey.png"]
		for tex in orange_pool:
			if ResourceLoader.exists(ASSETS_DIR + tex) or FileAccess.file_exists(ASSETS_DIR + tex):
				wall_tex_name = tex
				break

	var wall_tex = load_texture_safe(wall_tex_name)
	if wall_tex: wall_mat.albedo_texture = wall_tex

	wall_mat.roughness = 0.4
	wall_mat.metallic = 0.8
	wall_mat.uv1_scale = Vector3(1.0, wall_height / tile_size, 1.0)

	var floor_mat = StandardMaterial3D.new()
	var floor_tex_name = "env_floor_grid"

	# Ciclo dos 3 pisos conforme a progressão dos andares
	if floor_num % 3 == 0 and _texture_exists("env_floor_grid_dots"):
		floor_tex_name = "env_floor_grid_dots"  # Piso 3: Pontilhado (Andares 3, 6, 9, 12...)
	elif floor_num % 2 == 0 and _texture_exists("env_floor_grid_alt"):
		floor_tex_name = "env_floor_grid_alt"   # Piso 2: Cruz (Andares 2, 4, 8, 10...)
	else:
		floor_tex_name = "env_floor_grid"       # Piso 1: Quadrado (Andares 1, 5, 7, 11...)

	var floor_tex = load_texture_safe(floor_tex_name)
	if floor_tex: floor_mat.albedo_texture = floor_tex
	floor_mat.roughness = 0.6
	floor_mat.metallic = 0.5
	floor_mat.uv1_scale = Vector3(tile_size / 2.0, tile_size / 2.0, 1.0)

	var ceil_mat = StandardMaterial3D.new()
	var ceil_tex = load_texture_safe("env_ceiling_dark")
	if not ceil_tex: ceil_tex = load_texture_safe("env_ceiling_dark")
	if ceil_tex: ceil_mat.albedo_texture = ceil_tex
	ceil_mat.roughness = 0.9
	ceil_mat.uv1_scale = Vector3(tile_size / 2.0, tile_size / 2.0, 1.0)

	return {
		"wall": wall_mat,
		"floor": floor_mat,
		"ceiling": ceil_mat
	}

func _texture_exists(base_name: String) -> bool:
	var extensions = [".png", ".PNG", ".webp", ".jpg", ""]
	for ext in extensions:
		var p = ASSETS_DIR + base_name + ext
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return true
	return false

func _build_3d_geometry(grid: Array, materials: Dictionary, floor_num: int) -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var wx: float = (x - GRID_WIDTH / 2.0) * tile_size
			var wz: float = (y - GRID_HEIGHT / 2.0) * tile_size

			if grid[y][x] == 0:
				var wall_box = CSGBox3D.new()
				wall_box.size = Vector3(tile_size, wall_height, tile_size)
				wall_box.position = Vector3(wx, wall_height / 2.0, wz)
				wall_box.material_override = materials.wall
				wall_box.use_collision = true
				floor_parent.add_child(wall_box)
			else:
				var floor_plane = CSGBox3D.new()
				floor_plane.size = Vector3(tile_size, 0.1, tile_size)
				floor_plane.position = Vector3(wx, -0.05, wz)
				floor_plane.material_override = materials.floor
				floor_parent.add_child(floor_plane)

				var ceil_plane = CSGBox3D.new()
				ceil_plane.size = Vector3(tile_size, 0.1, tile_size)
				ceil_plane.position = Vector3(wx, wall_height, wz)
				ceil_plane.material_override = materials.ceiling
				floor_parent.add_child(ceil_plane)

				if (x % 2 != 0) and (y % 2 != 0):
					_setup_corridor_light(Vector3(wx, wall_height - 0.4, wz), floor_num)

func _setup_corridor_light(pos: Vector3, floor_num: int) -> void:
	var light_color = Color(0.1, 0.9, 1.0)
	if floor_num % 3 == 0: light_color = Color(0.85, 0.25, 1.0)
	elif floor_num % 2 == 0: light_color = Color(1.0, 0.65, 0.15)

	var disc_frame = CSGCylinder3D.new()
	disc_frame.radius = 0.26
	disc_frame.height = 0.04
	disc_frame.sides = 24
	disc_frame.position = Vector3(pos.x, wall_height - 0.065, pos.z)
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.08, 0.1, 0.14, 1.0)
	frame_mat.metallic = 0.85
	frame_mat.roughness = 0.3
	disc_frame.material_override = frame_mat
	floor_parent.add_child(disc_frame)

	var neon_lens = CSGCylinder3D.new()
	neon_lens.radius = 0.20
	neon_lens.height = 0.02
	neon_lens.sides = 24
	neon_lens.position = Vector3(pos.x, wall_height - 0.08, pos.z)
	var lens_mat = StandardMaterial3D.new()
	lens_mat.albedo_color = light_color
	lens_mat.emission_enabled = true
	lens_mat.emission = light_color
	lens_mat.emission_energy_multiplier = 4.0
	lens_mat.roughness = 0.1
	neon_lens.material_override = lens_mat
	floor_parent.add_child(neon_lens)

	var light = OmniLight3D.new()
	light.position = Vector3(pos.x, wall_height - 0.25, pos.z)
	light.omni_range = 7.5
	light.light_energy = 0.85
	light.light_color = light_color
	floor_parent.add_child(light)

func _place_sector_signage(grid: Array, floor_num: int) -> void:
	var sectors = [
		{"name": "SEC 01 - ALPHA", "cx": int(GRID_WIDTH * 0.25), "cy": int(GRID_HEIGHT * 0.25)},
		{"name": "SEC 02 - BETA",  "cx": int(GRID_WIDTH * 0.75), "cy": int(GRID_HEIGHT * 0.25)},
		{"name": "SEC 03 - GAMMA", "cx": int(GRID_WIDTH * 0.25), "cy": int(GRID_HEIGHT * 0.75)},
		{"name": "SEC 04 - DELTA", "cx": int(GRID_WIDTH * 0.75), "cy": int(GRID_HEIGHT * 0.75)}
	]

	var sign_color = Color(0.0, 0.9, 1.0)
	if floor_num % 3 == 0: sign_color = Color(0.85, 0.3, 1.0)
	elif floor_num % 2 == 0: sign_color = Color(1.0, 0.65, 0.15)

	for sec in sectors:
		var placed = false
		for dy in range(-2, 3):
			if placed: break
			for dx in range(-2, 3):
				var tx = clampi(sec.cx + dx, 1, GRID_WIDTH - 2)
				var ty = clampi(sec.cy + dy, 1, GRID_HEIGHT - 2)

				if grid[ty][tx] == 0:
					var offset = Vector3.ZERO
					var rot = Vector3.ZERO

					if ty + 1 < GRID_HEIGHT and grid[ty + 1][tx] == 1:
						offset = Vector3(0, 1.8, (tile_size / 2.0) + 0.02)
						rot = Vector3(0, 0, 0)
					elif ty - 1 >= 0 and grid[ty - 1][tx] == 1:
						offset = Vector3(0, 1.8, -(tile_size / 2.0) - 0.02)
						rot = Vector3(0, PI, 0)
					elif tx + 1 < GRID_WIDTH and grid[ty][tx + 1] == 1:
						offset = Vector3((tile_size / 2.0) + 0.02, 1.8, 0)
						rot = Vector3(0, -PI / 2.0, 0)
					elif tx - 1 >= 0 and grid[ty][tx - 1] == 1:
						offset = Vector3(-(tile_size / 2.0) - 0.02, 1.8, 0)
						rot = Vector3(0, PI / 2.0, 0)

					if offset != Vector3.ZERO:
						var wx: float = (tx - GRID_WIDTH / 2.0) * tile_size
						var wz: float = (ty - GRID_HEIGHT / 2.0) * tile_size

						var sign_lbl = Label3D.new()
						sign_lbl.text = "[ %s ]" % sec.name
						sign_lbl.font = FontManager.get_font("signage")
						sign_lbl.font_size = 36
						sign_lbl.pixel_size = 0.005
						sign_lbl.modulate = sign_color
						sign_lbl.outline_modulate = Color(0, 0, 0, 0.95)
						sign_lbl.outline_size = 6
						sign_lbl.shaded = false
						sign_lbl.double_sided = false
						sign_lbl.position = Vector3(wx, 0, wz) + offset
						sign_lbl.rotation = rot
						floor_parent.add_child(sign_lbl)
						placed = true
						break

func _is_solid_floor_rect(grid: Array, min_x: int, min_y: int, w: int, h: int) -> bool:
	for y in range(min_y, min_y + h):
		for x in range(min_x, min_x + w):
			if x < 1 or x >= GRID_WIDTH - 1 or y < 1 or y >= GRID_HEIGHT - 1:
				return false
			if grid[y][x] != 1:
				return false
	return true

func _distribute_pois(dead_ends: Array, floor_cells: Array, spawn_mode: String, mission_data: Dictionary, has_csouter: bool, etapa_dois: bool, has_detector: bool = false, floor_num: int = 1, grid: Array = []) -> Array:
	var pois: Array = []
	dead_ends.shuffle()

	var vortex_occupied_cells: Dictionary = {}
	var spawn_vortex_floor = etapa_dois or (randf() <= 0.50)

	if spawn_vortex_floor:
		var candidate_sizes = [
			Vector2i(4, 3), Vector2i(3, 4),
			Vector2i(4, 2), Vector2i(2, 4),
			Vector2i(3, 3)
		]
		var found_natural_blocks: Array[Dictionary] = []

		for r_sz in candidate_sizes:
			for y in range(1, GRID_HEIGHT - r_sz.y):
				for x in range(1, GRID_WIDTH - r_sz.x):
					if x <= 2 and y <= 2: continue
					if _is_solid_floor_rect(grid, x, y, r_sz.x, r_sz.y):
						var is_overlapping = false
						for dy in range(r_sz.y):
							for dx in range(r_sz.x):
								if vortex_occupied_cells.has(Vector2i(x + dx, y + dy)):
									is_overlapping = true
									break
							if is_overlapping: break

						if not is_overlapping:
							for dy in range(r_sz.y):
								for dx in range(r_sz.x):
									vortex_occupied_cells[Vector2i(x + dx, y + dy)] = true

							found_natural_blocks.append({
								"min_x": x, "min_y": y,
								"w": r_sz.x, "h": r_sz.y
							})
							break
				if found_natural_blocks.size() >= (2 if etapa_dois else 1): break
			if found_natural_blocks.size() >= (2 if etapa_dois else 1): break

		for rm in found_natural_blocks:
			if etapa_dois or (randf() <= 0.50):
				var w = rm.w
				var h = rm.h
				var is_dual_vortex = (w == 3 and h == 4) or (w == 4 and h == 3)
				var v_count = 2 if is_dual_vortex else 1

				var c1 = Vector3((rm.min_x - GRID_WIDTH / 2.0) * tile_size, 0, (rm.min_y - GRID_HEIGHT / 2.0) * tile_size)
				var c2 = Vector3(((rm.min_x + w - 1) - GRID_WIDTH / 2.0) * tile_size, 0, (rm.min_y - GRID_HEIGHT / 2.0) * tile_size)
				var c3 = Vector3(((rm.min_x + w - 1) - GRID_WIDTH / 2.0) * tile_size, 0, ((rm.min_y + h - 1) - GRID_HEIGHT / 2.0) * tile_size)
				var c4 = Vector3((rm.min_x - GRID_WIDTH / 2.0) * tile_size, 0, ((rm.min_y + h - 1) - GRID_HEIGHT / 2.0) * tile_size)

				var waypoints: Array[Vector3] = [c1, c2, c3, c4]

				for v_i in range(v_count):
					var start_corner = 0 if v_i == 0 else 2
					pois.append(_spawn_vortex_with_safe_waypoints(waypoints, start_corner))

	var available_floor_cells: Array[Vector2i] = []
	for fc in floor_cells:
		if not vortex_occupied_cells.has(fc):
			available_floor_cells.append(fc)
	if available_floor_cells.is_empty(): available_floor_cells = floor_cells.duplicate()

	var available_dead_ends: Array[Vector2i] = []
	for de in dead_ends:
		if not vortex_occupied_cells.has(de):
			available_dead_ends.append(de)
	if available_dead_ends.is_empty(): available_dead_ends = dead_ends.duplicate()

	# PORTAL
	var exit_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells.back()
	var exit_wx: float = (exit_cell.x - GRID_WIDTH / 2.0) * tile_size
	var exit_wz: float = (exit_cell.y - GRID_HEIGHT / 2.0) * tile_size
	pois.append(_spawn_portal(Vector3(exit_wx, 0.0, exit_wz)))

	# BAÚS
	var total_chests = randi_range(2, 4)
	for i in range(total_chests):
		var c_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells[randi() % available_floor_cells.size()]
		var wx: float = (c_cell.x - GRID_WIDTH / 2.0) * tile_size
		var wz: float = (c_cell.y - GRID_HEIGHT / 2.0) * tile_size
		pois.append(_spawn_chest(Vector3(wx, 0.0, wz), (i == 0)))

	# POD MÉDICO
	var heal_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells[randi() % available_floor_cells.size()]
	var h_wx: float = (heal_cell.x - GRID_WIDTH / 2.0) * tile_size
	var h_wz: float = (heal_cell.y - GRID_HEIGHT / 2.0) * tile_size
	pois.append(_spawn_heal_pod(Vector3(h_wx, 0.0, h_wz)))

	# ARCADE / TERMINAL
	if spawn_mode == "arcade":
		var arc_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells[randi() % available_floor_cells.size()]
		var a_wx: float = (arc_cell.x - GRID_WIDTH / 2.0) * tile_size
		var a_wz: float = (arc_cell.y - GRID_HEIGHT / 2.0) * tile_size
		pois.append(_spawn_space_spooter_arcade(Vector3(a_wx, 0.0, a_wz)))
	elif spawn_mode == "terminal":
		var term_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells[randi() % available_floor_cells.size()]
		var t_wx: float = (term_cell.x - GRID_WIDTH / 2.0) * tile_size
		var t_wz: float = (term_cell.y - GRID_HEIGHT / 2.0) * tile_size
		pois.append(_spawn_data_terminal(Vector3(t_wx, 0.0, t_wz), mission_data))

	# HOLE KEEPER
	if (floor_num >= 2 or etapa_dois) and randf() <= 0.50:
		var hk_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells[randi() % available_floor_cells.size()]
		var hk_x: float = (hk_cell.x - GRID_WIDTH / 2.0) * tile_size
		var hk_z: float = (hk_cell.y - GRID_HEIGHT / 2.0) * tile_size
		var letter = String.chr(65 + (randi() % 26))
		pois.append(_spawn_hole_keeper(Vector3(hk_x, 0.0, hk_z), letter, grid, hk_cell.x, hk_cell.y))

	# RACHADURAS
	var spawn_crack = etapa_dois or (randf() <= 0.20)
	if spawn_crack:
		var eligible_dead_ends: Array[Dictionary] = []
		for y in range(1, GRID_HEIGHT - 1):
			for x in range(1, GRID_WIDTH - 1):
				if x <= 2 and y <= 2: continue
				if grid[y][x] == 1 and not vortex_occupied_cells.has(Vector2i(x, y)):
					var walls_count = 0
					var open_dir = Vector2i.ZERO
					if grid[y-1][x] == 0: walls_count += 1
					else: open_dir = Vector2i(0, -1)
					if grid[y+1][x] == 0: walls_count += 1
					else: open_dir = Vector2i(0, 1)
					if grid[y][x-1] == 0: walls_count += 1
					else: open_dir = Vector2i(-1, 0)
					if grid[y][x+1] == 0: walls_count += 1
					else: open_dir = Vector2i(1, 0)

					if walls_count == 3 and open_dir != Vector2i.ZERO:
						eligible_dead_ends.append({"x": x, "y": y, "open_dir": open_dir})

		if eligible_dead_ends.size() > 0:
			var chosen_beco = eligible_dead_ends[randi() % eligible_dead_ends.size()]
			var b_wx: float = (chosen_beco.x - GRID_WIDTH / 2.0) * tile_size
			var b_wz: float = (chosen_beco.y - GRID_HEIGHT / 2.0) * tile_size
			pois.append(_spawn_floor_crack(Vector3(b_wx, 0, b_wz), chosen_beco.open_dir))

	# TESOUROS ESCONDIDOS
	var hidden_count = randi_range(0, 2)
	for _h in range(hidden_count):
		var rand_cell = available_floor_cells[randi() % available_floor_cells.size()]
		var hx: float = (rand_cell.x - GRID_WIDTH / 2.0) * tile_size
		var hz: float = (rand_cell.y - GRID_HEIGHT / 2.0) * tile_size
		pois.append({
			"type": "hidden_treasure",
			"x": hx,
			"z": hz,
			"collected": false
		})

	# C-SOUTER
	var can_spawn_csouter = not has_csouter and has_detector and (etapa_dois or randf() <= 0.20)
	if can_spawn_csouter:
		var c_cell = available_dead_ends.pop_back() if available_dead_ends.size() > 0 else available_floor_cells[randi() % available_floor_cells.size()]
		var cx: float = (c_cell.x - GRID_WIDTH / 2.0) * tile_size
		var cz: float = (c_cell.y - GRID_HEIGHT / 2.0) * tile_size
		pois.append(_spawn_csouter_ground(Vector3(cx, 0.0, cz)))

	return pois

func _create_diamond_fissure(length: float, width: float, pos: Vector3, rot_y: float) -> CSGPolygon3D:
	var poly = CSGPolygon3D.new()
	var pts = PackedVector2Array([
		Vector2(0, -length / 2.0),
		Vector2(width / 2.0, 0.0),
		Vector2(0, length / 2.0),
		Vector2(-width / 2.0, 0.0)
	])
	poly.polygon = pts
	poly.depth = 0.015
	poly.rotation.x = deg_to_rad(90.0)
	poly.rotation.y = rot_y
	poly.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.85, 1.0, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.85, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.roughness = 0.1
	poly.material_override = mat
	return poly

func _spawn_floor_crack(pos: Vector3, open_dir: Vector2i) -> Dictionary:
	var crack_node = Node3D.new()
	crack_node.name = "FloorCrack_Node"
	crack_node.position = pos

	crack_node.add_child(_create_diamond_fissure(2.6, 0.22, Vector3(0, 0.01, 0), deg_to_rad(25.0)))
	crack_node.add_child(_create_diamond_fissure(1.9, 0.18, Vector3(0.35, 0.01, -0.2), deg_to_rad(-40.0)))
	crack_node.add_child(_create_diamond_fissure(1.5, 0.14, Vector3(-0.4, 0.01, 0.3), deg_to_rad(65.0)))

	var crack_light = OmniLight3D.new()
	crack_light.position = Vector3(0, 0.35, 0)
	crack_light.light_color = Color(0.0, 0.85, 1.0, 1.0)
	crack_light.light_energy = 1.4
	crack_light.omni_range = 4.0
	crack_node.add_child(crack_light)

	floor_parent.add_child(crack_node)

	return {
		"type": "floor_crack",
		"x": pos.x,
		"z": pos.z,
		"open_dir": open_dir,
		"node": crack_node
	}

func _spawn_vortex_with_safe_waypoints(waypoints: Array, start_idx: int = 0) -> Dictionary:
	var vortex_node = Node3D.new()
	vortex_node.name = "Vortex_Node"

	var ring_mat = StandardMaterial3D.new()
	var purple_glow = Color(0.75, 0.1, 1.0, 0.9)
	ring_mat.albedo_color = purple_glow
	ring_mat.emission_enabled = true
	ring_mat.emission = purple_glow
	ring_mat.emission_energy_multiplier = 4.0

	var core_torus = CSGTorus3D.new()
	core_torus.inner_radius = 0.40
	core_torus.outer_radius = 0.85
	core_torus.sides = 16
	core_torus.ring_sides = 8
	core_torus.position.y = 1.2
	core_torus.material_override = ring_mat
	vortex_node.add_child(core_torus)

	var core_sphere = CSGSphere3D.new()
	core_sphere.radius = 0.32
	core_sphere.position.y = 1.2
	var black_mat = StandardMaterial3D.new()
	black_mat.albedo_color = Color(0.01, 0.01, 0.02, 1.0)
	black_mat.metallic = 0.9
	black_mat.roughness = 0.2
	core_sphere.material_override = black_mat
	vortex_node.add_child(core_sphere)

	var v_light = OmniLight3D.new()
	v_light.position.y = 1.2
	v_light.light_color = purple_glow
	v_light.light_energy = 1.6
	v_light.omni_range = 5.0
	vortex_node.add_child(v_light)

	var initial_wp = start_idx % waypoints.size()
	vortex_node.position = waypoints[initial_wp]
	floor_parent.add_child(vortex_node)

	return {
		"type": "vortex",
		"x": vortex_node.position.x,
		"z": vortex_node.position.z,
		"waypoints": waypoints,
		"wp_idx": (initial_wp + 1) % waypoints.size(),
		"node": vortex_node,
		"torus": core_torus,
		"light": v_light
	}

func _spawn_hole_keeper(base_pos: Vector3, letter: String, grid: Array, cx: int, cy: int) -> Dictionary:
	var hk_node = Node3D.new()
	hk_node.name = "HoleKeeper_Node"

	var wall_offset = Vector3.ZERO
	var wall_rot = Vector3.ZERO

	if cy - 1 >= 0 and grid[cy - 1][cx] == 0:
		wall_offset = Vector3(0, 1.4, -(tile_size / 2.0) + 0.04)
		wall_rot = Vector3(0, 0, 0)
	elif cy + 1 < GRID_HEIGHT and grid[cy + 1][cx] == 0:
		wall_offset = Vector3(0, 1.4, (tile_size / 2.0) - 0.04)
		wall_rot = Vector3(0, PI, 0)
	elif cx - 1 >= 0 and grid[cy][cx - 1] == 0:
		wall_offset = Vector3(-(tile_size / 2.0) + 0.04, 1.4, 0)
		wall_rot = Vector3(0, PI / 2.0, 0)
	elif cx + 1 < GRID_WIDTH and grid[cy][cx + 1] == 0:
		wall_offset = Vector3((tile_size / 2.0) - 0.04, 1.4, 0)
		wall_rot = Vector3(0, -PI / 2.0, 0)
	else:
		wall_offset = Vector3(0, 1.4, -(tile_size / 2.0) + 0.04)

	hk_node.position = base_pos + wall_offset
	hk_node.rotation = wall_rot

	var hole_bg = CSGCylinder3D.new()
	hole_bg.radius = 0.65
	hole_bg.height = 0.08
	hole_bg.sides = 24
	hole_bg.rotation.x = deg_to_rad(90.0)
	var hole_mat = StandardMaterial3D.new()
	hole_mat.albedo_color = Color(0.01, 0.0, 0.03, 1.0)
	hole_mat.metallic = 0.9
	hole_mat.roughness = 0.2
	hole_bg.material_override = hole_mat
	hk_node.add_child(hole_bg)

	var void_ring = CSGCylinder3D.new()
	void_ring.radius = 0.70
	void_ring.height = 0.02
	void_ring.sides = 24
	void_ring.rotation.x = deg_to_rad(90.0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.85, 0.2, 1.0, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.85, 0.2, 1.0)
	ring_mat.emission_energy_multiplier = 3.5
	void_ring.material_override = ring_mat
	hk_node.add_child(void_ring)

	var light = OmniLight3D.new()
	light.position = Vector3.ZERO
	light.light_color = Color(0.85, 0.2, 1.0, 1.0)
	light.light_energy = 1.6
	light.omni_range = 4.5

	pulsing_lights.append({
		"light": light,
		"base_energy": 1.6,
		"speed": 3.5,
		"amp": 0.5,
		"phase": randf() * TAU
	})

	hk_node.add_child(light)
	floor_parent.add_child(hk_node)

	return {
		"type": "hole_keeper",
		"x": base_pos.x,
		"z": base_pos.z,
		"npc_letter": letter,
		"used": false,
		"node": hk_node,
		"light": light
	}

func _spawn_csouter_ground(base_pos: Vector3) -> Dictionary:
	var csouter_sprite = Sprite3D.new()
	csouter_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var tex = load_texture_safe("prop_csouter_ground")
	if not tex: tex = load_texture_safe("prop_csouter_ground")
	if not tex: tex = load_texture_safe("item_csouter")

	if tex:
		csouter_sprite.texture = tex
		csouter_sprite.pixel_size = CSOUTER_TARGET_HEIGHT / float(tex.get_height())
	else:
		csouter_sprite.pixel_size = 0.003

	csouter_sprite.position = Vector3(base_pos.x, 0.14, base_pos.z)

	var light = OmniLight3D.new()
	light.position = Vector3(base_pos.x, 0.25, base_pos.z)
	light.light_color = Color(0.1, 0.6, 1.0, 1.0)
	light.light_energy = 0.8
	light.omni_range = 2.0
	floor_parent.add_child(light)
	floor_parent.add_child(csouter_sprite)

	return {
		"type": "prop_csouter_ground",
		"x": base_pos.x,
		"z": base_pos.z,
		"collected": false,
		"node": csouter_sprite,
		"light": light
	}

func _spawn_chest(base_pos: Vector3, is_floor_key: bool) -> Dictionary:
	var shadow_mesh = CSGCylinder3D.new()
	shadow_mesh.radius = 0.85
	shadow_mesh.height = 0.01
	shadow_mesh.position = Vector3(base_pos.x, 0.01, base_pos.z)
	var shadow_mat = StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.01, 0.01, 0.02, 0.65)
	shadow_mat.roughness = 1.0
	shadow_mesh.material_override = shadow_mat
	floor_parent.add_child(shadow_mesh)

	var sprite_chest = Sprite3D.new()
	sprite_chest.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var chest_tex = load_texture_safe("prop_chest_closed")
	if not chest_tex: chest_tex = load_texture_safe("prop_chest_closed")
	if chest_tex:
		sprite_chest.texture = chest_tex
		sprite_chest.pixel_size = CHEST_TARGET_HEIGHT / float(chest_tex.get_height())
	else:
		sprite_chest.pixel_size = 0.005

	sprite_chest.position = Vector3(base_pos.x, CHEST_TARGET_HEIGHT / 2.0, base_pos.z)
	floor_parent.add_child(sprite_chest)

	return {
		"type": "chest",
		"x": base_pos.x,
		"z": base_pos.z,
		"opened": false,
		"has_floor_key": is_floor_key,
		"node": sprite_chest
	}

func _spawn_heal_pod(base_pos: Vector3) -> Dictionary:
	var heal_tex = load_texture_safe("prop_heal_pod")
	if not heal_tex: heal_tex = load_texture_safe("prop_heal_pod")
	if not heal_tex: heal_tex = load_texture_safe("prop_heal_pod")

	var heal_node: Node3D

	if heal_tex:
		var s = Sprite3D.new()
		s.texture = heal_tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = HEAL_POD_TARGET_HEIGHT / float(heal_tex.get_height())
		s.position = Vector3(base_pos.x, HEAL_POD_TARGET_HEIGHT / 2.0, base_pos.z)
		heal_node = s
	else:
		var csg_cyl = CSGCylinder3D.new()
		csg_cyl.radius = 0.5
		csg_cyl.height = HEAL_POD_TARGET_HEIGHT
		csg_cyl.position = Vector3(base_pos.x, HEAL_POD_TARGET_HEIGHT / 2.0, base_pos.z)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.85, 1.0, 0.8)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.85, 1.0)
		csg_cyl.material_override = mat
		heal_node = csg_cyl

	var pod_light = OmniLight3D.new()
	pod_light.position = Vector3(base_pos.x, 1.2, base_pos.z)
	pod_light.light_color = Color(0.102, 0.851, 1.0, 1.0)
	pod_light.light_energy = 1.4
	pod_light.omni_range = 5.5

	pulsing_lights.append({
		"light": pod_light,
		"base_energy": 1.4,
		"speed": 2.4,
		"amp": 0.4,
		"phase": randf() * TAU
	})

	floor_parent.add_child(pod_light)
	floor_parent.add_child(heal_node)

	return {
		"type": "heal",
		"x": base_pos.x,
		"z": base_pos.z,
		"node": heal_node
	}

func _spawn_portal(base_pos: Vector3) -> Dictionary:
	var portal_sprite = Sprite3D.new()
	portal_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var portal_tex = load_texture_safe("prop_portal")
	if not portal_tex: portal_tex = load_texture_safe("prop_portal")
	if portal_tex:
		portal_sprite.texture = portal_tex
		portal_sprite.pixel_size = PORTAL_TARGET_HEIGHT / float(portal_tex.get_height())
	else:
		portal_sprite.pixel_size = 0.006

	portal_sprite.position = Vector3(base_pos.x, PORTAL_TARGET_HEIGHT / 2.0, base_pos.z)

	var portal_light = OmniLight3D.new()
	portal_light.position = Vector3(base_pos.x, 1.5, base_pos.z)
	portal_light.light_color = Color(0.75, 0.1, 1.0)
	portal_light.light_energy = 1.3
	portal_light.omni_range = 6.0

	pulsing_lights.append({
		"light": portal_light,
		"base_energy": 1.3,
		"speed": 3.0,
		"amp": 0.45,
		"phase": randf() * TAU
	})

	floor_parent.add_child(portal_light)
	floor_parent.add_child(portal_sprite)

	var shield_mesh = CSGCylinder3D.new()
	shield_mesh.name = "PortalShield_Mesh"
	shield_mesh.radius = 1.45
	shield_mesh.height = 2.6
	shield_mesh.sides = 12
	shield_mesh.position = Vector3(base_pos.x, 1.25, base_pos.z)
	shield_mesh.use_collision = false

	var shield_mat = StandardMaterial3D.new()
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.16)
	shield_mat.emission_enabled = false
	shield_mat.roughness = 0.1
	shield_mesh.material_override = shield_mat

	floor_parent.add_child(shield_mesh)
	rotating_shields.append(shield_mesh)

	return {
		"type": "portal",
		"x": base_pos.x,
		"z": base_pos.z,
		"node": portal_sprite,
		"shield": shield_mesh,
		"shield_mat": shield_mat
	}

func _spawn_space_spooter_arcade(base_pos: Vector3) -> Dictionary:
	var shadow_mesh = CSGCylinder3D.new()
	shadow_mesh.radius = 0.95
	shadow_mesh.height = 0.01
	shadow_mesh.position = Vector3(base_pos.x, 0.01, base_pos.z)
	var shadow_mat = StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.01, 0.01, 0.02, 0.70)
	shadow_mat.roughness = 1.0
	shadow_mesh.material_override = shadow_mat
	shadow_mesh.visible = false
	floor_parent.add_child(shadow_mesh)

	var arcade_sprite = Sprite3D.new()
	arcade_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var tex_on = load_texture_safe("prop_spooter_on")
	if not tex_on: tex_on = load_texture_safe("prop_spooter_on")
	if arcade_sprite and tex_on:
		arcade_sprite.texture = tex_on
		arcade_sprite.pixel_size = ARCADE_TARGET_HEIGHT / float(tex_on.get_height())
	else:
		arcade_sprite.pixel_size = 0.0055

	arcade_sprite.position = Vector3(base_pos.x, ARCADE_TARGET_HEIGHT / 2.0, base_pos.z)

	var arcade_light = OmniLight3D.new()
	arcade_light.position = Vector3(base_pos.x, 1.2, base_pos.z)
	arcade_light.light_color = Color(0.0, 1.0, 0.35, 1.0)
	arcade_light.light_energy = 1.1
	arcade_light.omni_range = 3.5

	pulsing_lights.append({
		"light": arcade_light,
		"base_energy": 1.1,
		"speed": 3.5,
		"amp": 0.35,
		"phase": randf() * TAU
	})

	floor_parent.add_child(arcade_light)
	floor_parent.add_child(arcade_sprite)

	return {
		"type": "arcade_spooter",
		"x": base_pos.x,
		"z": base_pos.z,
		"completed": false,
		"node": arcade_sprite,
		"light": arcade_light,
		"shadow": shadow_mesh
	}

func _spawn_data_terminal(base_pos: Vector3, mission_data: Dictionary) -> Dictionary:
	var shadow_mesh = CSGCylinder3D.new()
	shadow_mesh.radius = 0.95
	shadow_mesh.height = 0.01
	shadow_mesh.position = Vector3(base_pos.x, 0.01, base_pos.z)
	var shadow_mat = StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.01, 0.01, 0.02, 0.70)
	shadow_mat.roughness = 1.0
	shadow_mesh.material_override = shadow_mat
	shadow_mesh.visible = false
	floor_parent.add_child(shadow_mesh)

	var terminal_sprite = Sprite3D.new()
	terminal_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var tex_on = load_texture_safe("prop_terminal_on")
	if not tex_on: tex_on = load_texture_safe("prop_terminal_on")
	if not tex_on: tex_on = load_texture_safe("prop_spooter_on")
	if not tex_on: tex_on = load_texture_safe("prop_spooter_on")
	if terminal_sprite and tex_on:
		terminal_sprite.texture = tex_on
		terminal_sprite.pixel_size = TERMINAL_TARGET_HEIGHT / float(tex_on.get_height())
	else:
		terminal_sprite.pixel_size = 0.0055

	terminal_sprite.position = Vector3(base_pos.x, TERMINAL_TARGET_HEIGHT / 2.0, base_pos.z)

	var term_light = OmniLight3D.new()
	term_light.position = Vector3(base_pos.x, 1.2, base_pos.z)
	term_light.light_color = Color(0.0, 1.0, 0.35, 1.0)
	term_light.light_energy = 1.1
	term_light.omni_range = 3.5

	pulsing_lights.append({
		"light": term_light,
		"base_energy": 1.1,
		"speed": 3.5,
		"amp": 0.35,
		"phase": randf() * TAU
	})

	floor_parent.add_child(term_light)
	floor_parent.add_child(terminal_sprite)

	return {
		"type": "data_terminal",
		"x": base_pos.x,
		"z": base_pos.z,
		"completed": false,
		"mission": mission_data,
		"node": terminal_sprite,
		"light": term_light,
		"shadow": shadow_mesh
	}

static func load_texture_safe(base_name: String) -> Texture2D:
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
	return null
