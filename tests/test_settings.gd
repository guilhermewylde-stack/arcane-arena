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
