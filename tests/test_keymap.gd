extends "res://tests/test_case.gd"

const Keymap := preload("res://game/keymap.gd")
const Settings := preload("res://game/settings.gd")

const PATH := "user://test_keymap.cfg"


func test_padroes_sao_as_teclas_de_sempre() -> void:
	var slots: Array = []
	for slot in 6:
		slots.append(Keymap.slot_key(Keymap.DEFAULTS, slot))
	check_eq(slots, [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_D, KEY_F], "barra de magias")
	check_eq(Keymap.DEFAULTS.move_forward, KEY_W, "andar para a frente")
	check_eq(Keymap.slot_of(Keymap.DEFAULTS, KEY_E), 2, "E é o 3º espaço")
	check_eq(Keymap.slot_of(Keymap.DEFAULTS, KEY_Z), -1, "tecla sem magia")


func test_trocar_uma_tecla() -> void:
	var map := Keymap.rebind(Keymap.DEFAULTS, "slot_1", KEY_Z)
	check_eq(Keymap.slot_of(map, KEY_Z), 0, "Z lança o 1º espaço")
	check_eq(Keymap.slot_of(map, KEY_Q), -1, "Q ficou livre")
	check_eq(Keymap.DEFAULTS.slot_1, KEY_Q, "não altera o original")


func test_conflito_no_mesmo_grupo_troca_as_duas() -> void:
	var map := Keymap.rebind(Keymap.DEFAULTS, "slot_1", KEY_W)
	check_eq(map.slot_1, KEY_W, "1º espaço ganhou o W")
	check_eq(map.slot_2, KEY_Q, "e o 2º ficou com o Q que sobrou")


func test_grupos_diferentes_podem_repetir_tecla() -> void:
	# A barra vale na visão de cima e o movimento na 3ª pessoa: W nos dois não é conflito.
	var map := Keymap.rebind(Keymap.DEFAULTS, "move_left", KEY_Q)
	check_eq(map.move_left, KEY_Q, "Q anda para a esquerda")
	check_eq(map.slot_1, KEY_Q, "e continua lançando o 1º espaço")


func test_teclas_reservadas_nao_sao_aceitas() -> void:
	for key: Key in [KEY_ESCAPE, KEY_F5, KEY_F11, KEY_ENTER, KEY_1]:
		check(not Keymap.is_bindable(key), "%s é reservada" % OS.get_keycode_string(key))
		check_eq(Keymap.rebind(Keymap.DEFAULTS, "slot_1", key), Keymap.DEFAULTS, "nada muda")
	check(Keymap.is_bindable(KEY_SPACE), "espaço pode")


func test_direcao_do_movimento_pelas_teclas_apertadas() -> void:
	var pressed := func(key: Key) -> bool: return key == KEY_W or key == KEY_D
	check_eq(Keymap.move_input(Keymap.DEFAULTS, pressed), Vector2(1, 1), "frente + direita")
	var opposite := func(key: Key) -> bool: return key == KEY_A or key == KEY_D
	check_eq(Keymap.move_input(Keymap.DEFAULTS, opposite), Vector2.ZERO, "opostas se anulam")


func test_arquivo_com_lixo_volta_ao_padrao_sem_duplicar() -> void:
	var clean := Keymap.sanitize({"slot_1": "Q", "slot_2": KEY_Q, "move_back": KEY_ESCAPE})
	check_eq(clean.slot_1, KEY_Q, "tipo errado vira padrão")
	check_eq(clean.slot_2, KEY_W, "duplicada no grupo vira padrão")
	check_eq(clean.move_back, KEY_S, "reservada vira padrão")


func test_salva_e_le_de_volta() -> void:
	DirAccess.remove_absolute(PATH)
	check_eq(Keymap.load_from(PATH), Keymap.DEFAULTS, "sem arquivo, padrões")
	var map := Keymap.rebind(Keymap.DEFAULTS, "move_forward", KEY_UP)
	Keymap.save_to(PATH, map)
	check_eq(Keymap.load_from(PATH), map, "ida e volta")
	check_eq(Settings.load_from(PATH), Settings.DEFAULTS, "sem mexer na seção da janela")
	DirAccess.remove_absolute(PATH)


func test_nome_curto_da_tecla() -> void:
	check_eq(Keymap.key_label(KEY_Q), "Q", "letra")
	check_eq(Keymap.key_label(KEY_SPACE), "Espaço", "espaço em português")
