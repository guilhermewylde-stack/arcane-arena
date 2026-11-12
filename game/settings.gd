extends RefCounted
## Opções de janela do jogador (tela cheia, resolução, vsync), guardadas em `user://settings.cfg`.
## Enquanto não há menu (issue 012), o arquivo pode ser editado à mão; F11 alterna a tela cheia.

const PATH := "user://settings.cfg"
const SECTION := "window"
const DEFAULTS := {"fullscreen": false, "width": 1600, "height": 900, "vsync": true}
const MIN_SIZE := Vector2i(960, 540)
const MAX_SIZE := Vector2i(7680, 4320)


## Devolve só as chaves conhecidas, com tipo certo e resolução dentro dos limites.
static func sanitize(raw: Dictionary) -> Dictionary:
	var clean := DEFAULTS.duplicate()
	for key: String in DEFAULTS:
		if typeof(raw.get(key)) == typeof(DEFAULTS[key]):
			clean[key] = raw[key]
	clean.width = clampi(clean.width, MIN_SIZE.x, MAX_SIZE.x)
	clean.height = clampi(clean.height, MIN_SIZE.y, MAX_SIZE.y)
	return clean


## Lê as opções; arquivo ausente ou quebrado dá os padrões.
static func load_from(path: String = PATH) -> Dictionary:
	var file := ConfigFile.new()
	var raw := {}
	if file.load(path) == OK:
		for key: String in DEFAULTS:
			raw[key] = file.get_value(SECTION, key, null)
	return sanitize(raw)


static func save_to(path: String, settings: Dictionary) -> void:
	var file := ConfigFile.new()
	var clean := sanitize(settings)
	for key: String in clean:
		file.set_value(SECTION, key, clean[key])
	file.save(path)


## Aplica as opções à janela do jogo.
static func apply(settings: Dictionary) -> void:
	var clean := sanitize(settings)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if clean.vsync else DisplayServer.VSYNC_DISABLED)
	if clean.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size := Vector2i(clean.width, clean.height)
	var screen := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(
		DisplayServer.screen_get_position(screen) + (DisplayServer.screen_get_size(screen) - size) / 2)
