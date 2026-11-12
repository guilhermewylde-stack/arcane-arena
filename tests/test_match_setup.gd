extends "res://tests/test_case.gd"

const MatchSetup := preload("res://game/match_setup.gd")
const Settings := preload("res://game/settings.gd")
const Bot := preload("res://sim/bot.gd")

const PATH := "user://test_match_setup.cfg"


func test_padrao_e_a_partida_de_sempre() -> void:
	check_eq(MatchSetup.world_config(MatchSetup.DEFAULTS), {"mage_count": 4, "rounds_to_win": 3}, "1 jogador + 3 bots, 3 rodadas")
	check(Bot.DIFFICULTIES.has(MatchSetup.DEFAULTS.difficulty), "dificuldade padrão existe")


func test_valores_fora_do_limite_sao_corrigidos() -> void:
	var clean := MatchSetup.sanitize({"bots": 99, "rounds": 0, "difficulty": "impossível"})
	check_eq(clean.bots, MatchSetup.MAX_BOTS, "bots no máximo")
	check_eq(clean.rounds, 1, "pelo menos uma rodada")
	check_eq(clean.difficulty, MatchSetup.DEFAULTS.difficulty, "dificuldade desconhecida vira padrão")


func test_ajustar_soma_e_respeita_os_limites() -> void:
	var setup := MatchSetup.adjust(MatchSetup.DEFAULTS, "bots", 1)
	check_eq(setup.bots, 4, "mais um bot")
	check_eq(MatchSetup.DEFAULTS.bots, 3, "não altera o original")
	check_eq(MatchSetup.adjust({"bots": 1}, "bots", -1).bots, 1, "sempre há um adversário")
	check_eq(MatchSetup.adjust({"rounds": MatchSetup.MAX_ROUNDS}, "rounds", 1).rounds, MatchSetup.MAX_ROUNDS, "teto de rodadas")


func test_ajustar_dificuldade_da_a_volta() -> void:
	var names: Array = Bot.DIFFICULTIES.keys()
	var setup := {"difficulty": names[-1]}
	check_eq(MatchSetup.adjust(setup, "difficulty", 1).difficulty, names[0], "do último volta ao primeiro")
	check_eq(MatchSetup.adjust({"difficulty": names[0]}, "difficulty", -1).difficulty, names[-1], "e ao contrário")


func test_salva_sem_apagar_as_opcoes_de_janela() -> void:
	DirAccess.remove_absolute(PATH)
	var window := {"fullscreen": true, "width": 1280, "height": 720, "vsync": false}
	Settings.save_to(PATH, window)
	MatchSetup.save_to(PATH, {"bots": 5, "difficulty": "hard", "rounds": 2})
	check_eq(MatchSetup.load_from(PATH), {"bots": 5, "difficulty": "hard", "rounds": 2}, "partida salva")
	check_eq(Settings.load_from(PATH), window, "janela preservada")
	Settings.save_to(PATH, Settings.DEFAULTS)
	check_eq(MatchSetup.load_from(PATH).bots, 5, "e a partida sobrevive a salvar a janela")
	DirAccess.remove_absolute(PATH)
