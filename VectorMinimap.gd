# VectorMinimap.gd
extends Control

@export var min_distance_threshold: float = 1.5
@export var line_color: Color = Color(0.0, 1.0, 0.4, 0.9)
@export var line_width: float = 2.0

var normal_scale: float = 3.2
var expanded_scale: float = 5.2

var vector_trail: Array[Vector2] = []
var current_player_pos: Vector2 = Vector2.ZERO

var is_expanded: bool = false
var normal_size: Vector2 = Vector2(90, 90)
var normal_pos: Vector2 = Vector2.ZERO
var expanded_size: Vector2 = Vector2(460, 460)

var current_tween: Tween = null

func _ready() -> void:
	clip_contents = true
	await get_tree().process_frame
	normal_size = size
	normal_pos = position

func reset_minimap() -> void:
	vector_trail.clear()
	is_expanded = false
	queue_redraw()

func update_player_position(world_pos_3d: Vector3) -> void:
	var pos_2d: Vector2 = Vector2(world_pos_3d.x, world_pos_3d.z)
	current_player_pos = pos_2d
	
	if vector_trail.is_empty():
		vector_trail.append(pos_2d)
		queue_redraw()
		return
		
	var last_logged_point: Vector2 = vector_trail.back()
	var distance_stepped: float = pos_2d.distance_to(last_logged_point)
	
	if distance_stepped >= min_distance_threshold:
		vector_trail.append(pos_2d)
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SHIFT:
			_handle_expand(event.pressed)
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_STICK:
			_handle_expand(event.pressed)

func _handle_expand(expand: bool) -> void:
	if expand and not is_expanded:
		_set_expanded_state(true)
	elif not expand and is_expanded:
		_set_expanded_state(false)

func _set_expanded_state(expand: bool) -> void:
	is_expanded = expand
	var vp_size = get_viewport_rect().size
	
	var target_size = expanded_size if is_expanded else normal_size
	var target_pos = (vp_size - expanded_size) / 2.0 if is_expanded else Vector2(vp_size.x - normal_size.x - 20.0, 20.0)

	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, "size", target_size, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.finished.connect(queue_redraw)
	
	queue_redraw()

func _draw() -> void:
	var center_offset: Vector2 = size / 2.0
	var cur_scale = expanded_scale if is_expanded else normal_scale

	if is_expanded:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.08, 0.92), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.85, 1.0, 0.8), false, 2.0)
		draw_line(Vector2(center_offset.x, 0), Vector2(center_offset.x, size.y), Color(0.0, 0.85, 1.0, 0.15), 1.0)
		draw_line(Vector2(0, center_offset.y), Vector2(size.x, center_offset.y), Color(0.0, 0.85, 1.0, 0.15), 1.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.06, 0.65), true)

	if vector_trail.size() < 2:
		draw_circle(center_offset, 4.0 if not is_expanded else 5.0, Color.WHITE)
		return

	for i in range(1, vector_trail.size()):
		var p1: Vector2 = center_offset + (vector_trail[i - 1] - current_player_pos) * cur_scale
		var p2: Vector2 = center_offset + (vector_trail[i] - current_player_pos) * cur_scale
		draw_line(p1, p2, line_color, line_width if not is_expanded else 2.5)

	var player_dot_size = 5.0 if is_expanded else 3.5
	draw_circle(center_offset, player_dot_size, Color.WHITE)
	if is_expanded:
		draw_arc(center_offset, 8.0, 0, TAU, 16, Color(0.0, 1.0, 0.5, 0.8), 1.5)
