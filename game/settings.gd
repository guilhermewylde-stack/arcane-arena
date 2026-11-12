extends RefCounted
## Opções de janela do jogador (tela cheia, resolução, vsync), guardadas em `user://settings.cfg`.
## Enquanto não há menu (issue 012), o arquivo pode ser editado à mão; F11 alterna a tela cheia.

const PATH := "user://settings.cfg"
const SECTION := "window"
const DEFAULTS := {"fullscreen": false, "width": 1600, "height": 900, "vsync": true}
const MIN_SIZE := Vector2i(960, 540)
const MAX_SIZE := Vector2i(7680, 4320)
const COMMON_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]


## Devolve só as chaves conhecidas, com tipo certo e resolução dentro dos limites.
static func sanitize(raw: Dictionary) -> Dictionary:
	var clean := DEFAULTS.duplicate()
	for key: String in DEFAULTS:
		if typeof(raw.get(key)) == typeof(DEFAULTS[key]):
			clean[key] = raw[key]
	clean.width = clampi(clean.width, MIN_SIZE.x, MAX_SIZE.x)
	clean.height = clampi(clean.height, MIN_SIZE.y, MAX_SIZE.y)
	return clean


## Resoluções de janela oferecidas no menu: as comuns que cabem no monitor (da menor à maior).
static func resolutions(screen_size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for size: Vector2i in COMMON_SIZES:
		if size.x <= screen_size.x and size.y <= screen_size.y:
			out.append(size)
	if out.is_empty():
		out.append(MIN_SIZE)
	return out


## Cópia das opções com um campo andado `step` casas: liga/desliga para `fullscreen` e `vsync`;
## `resolution` anda pela lista de `resolutions(screen_size)`, sem dar a volta.
static func adjust(settings: Dictionary, key: String, step: int, screen_size: Vector2i) -> Dictionary:
	var out := sanitize(settings)
	if key != "resolution":
		out[key] = not out[key]
		return out
	var options := resolutions(screen_size)
	var area: int = out.width * out.height
	# Posição na lista: a primeira opção que não é menor que a atual.
	var index := options.size() - 1
	for i in options.size():
		if options[i].x * options[i].y >= area:
			index = i
			break
	if options[index] == Vector2i(out.width, out.height) or step < 0:
		index = clampi(index + step, 0, options.size() - 1)
	out.width = options[index].x
	out.height = options[index].y
	return out


## Lê as opções; arquivo ausente ou quebrado dá os padrões.
static func load_from(path: String = PATH) -> Dictionary:
	return sanitize(read_section(path, SECTION, DEFAULTS.keys()))


static func save_to(path: String, settings: Dictionary) -> void:
	write_section(path, SECTION, sanitize(settings))


## Valores crus de uma seção do arquivo (só as chaves que existem nele).
static func read_section(path: String, section: String, keys: Array) -> Dictionary:
	var file := ConfigFile.new()
	var raw := {}
	if FileAccess.file_exists(path) and file.load(path) == OK:
		for key: String in keys:
			raw[key] = file.get_value(section, key, null)
	return raw


## Grava uma seção sem mexer nas outras do mesmo arquivo.
static func write_section(path: String, section: String, values: Dictionary) -> void:
	var file := ConfigFile.new()
	if FileAccess.file_exists(path):
		file.load(path)
	for key: String in values:
		file.set_value(section, key, values[key])
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
