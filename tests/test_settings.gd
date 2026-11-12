extends "res://tests/test_case.gd"

const Settings := preload("res://game/settings.gd")

const PATH := "user://test_settings.cfg"


func test_sem_arquivo_valem_os_padroes() -> void:
	DirAccess.remove_absolute(PATH)
	check_eq(Settings.load_from(PATH), Settings.DEFAULTS, "padrões")


func test_salva_e_le_de_volta() -> void:
	var wanted := {"fullscreen": true, "width": 1920, "height": 1080, "vsync": false}
	Settings.save_to(PATH, wanted)
	check_eq(Settings.load_from(PATH), wanted, "ida e volta")
	DirAccess.remove_absolute(PATH)


func test_valores_invalidos_voltam_ao_padrao_ou_ao_limite() -> void:
	var clean := Settings.sanitize({"fullscreen": "sim", "width": 10, "height": 99999, "extra": 1})
	check_eq(clean.fullscreen, Settings.DEFAULTS.fullscreen, "tipo errado vira padrão")
	check_eq(clean.width, Settings.MIN_SIZE.x, "largura mínima")
	check_eq(clean.height, Settings.MAX_SIZE.y, "altura máxima")
	check_eq(clean.vsync, Settings.DEFAULTS.vsync, "chave que falta vira padrão")
	check(not clean.has("extra"), "chave desconhecida some")


func test_arquivo_quebrado_nao_derruba_o_jogo() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[[[isto não é um cfg")
	file.close()
	check_eq(Settings.load_from(PATH), Settings.DEFAULTS, "padrões com arquivo quebrado")
	DirAccess.remove_absolute(PATH)


func test_resolucoes_oferecidas_cabem_no_monitor() -> void:
	var options := Settings.resolutions(Vector2i(1920, 1080))
	check(options.has(Vector2i(1920, 1080)), "a do próprio monitor entra")
	check(options.has(Vector2i(1280, 720)), "as menores também")
	check(not options.has(Vector2i(2560, 1440)), "as maiores que o monitor não")
	check(not Settings.resolutions(Vector2i(800, 600)).is_empty(), "monitor pequeno ainda tem uma opção")


func test_ajustar_liga_e_desliga() -> void:
	var screen := Vector2i(1920, 1080)
	var changed := Settings.adjust(Settings.DEFAULTS, "vsync", 1, screen)
	check_eq(changed.vsync, not Settings.DEFAULTS.vsync, "vsync trocado")
	check_eq(Settings.adjust(changed, "vsync", -1, screen).vsync, Settings.DEFAULTS.vsync, "e de volta")
	check_eq(Settings.adjust(Settings.DEFAULTS, "fullscreen", 1, screen).fullscreen, true, "tela cheia ligada")


func test_ajustar_resolucao_anda_pela_lista_sem_dar_a_volta() -> void:
	var screen := Vector2i(1920, 1080)
	var options := Settings.resolutions(screen)
	var current := {"width": options[0].x, "height": options[0].y}
	var bigger := Settings.adjust(current, "resolution", 1, screen)
	check_eq(Vector2i(bigger.width, bigger.height), options[1], "próxima da lista")
	var same := Settings.adjust(current, "resolution", -1, screen)
	check_eq(Vector2i(same.width, same.height), options[0], "não passa do começo")
	# Uma resolução editada à mão, fora da lista, vai para a vizinha mais próxima.
	var odd := Settings.adjust({"width": 1300, "height": 760}, "resolution", 1, screen)
	check_eq(Vector2i(odd.width, odd.height), Vector2i(1366, 768), "da fora da lista para a próxima maior")
