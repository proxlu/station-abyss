extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.alt_pressed and event.keycode == KEY_ENTER) or event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	# Se estiver em modo janela, vai para tela cheia
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		# 1. Volta para o modo janela
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
		# 2. Pega a resolução padrão do seu projeto (1280x720)
		var base_w = ProjectSettings.get_setting("display/window/size/viewport_width", 1280)
		var base_h = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
		var target_size = Vector2i(base_w, base_h)
		
		# 3. Força a janela a voltar exatamente para 1280x720
		DisplayServer.window_set_size(target_size)
		
		# 4. Centraliza a janela novamente no meio do monitor
		var screen_id = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(screen_id)
		var centered_pos = (screen_size - target_size) / 2
		DisplayServer.window_set_position(centered_pos)
