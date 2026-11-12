extends "res://tests/test_case.gd"

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")


func _match(extra := {}) -> RefCounted:
	var config := {"mage_count": 2, "rounds_to_win": 2, "shop_seconds": 0.0}
	config.merge(extra, true)
	return SimWorld.new(config)


func _steps(world: RefCounted, seconds: float) -> void:
	for i in roundi(seconds * SimWorld.TICK_RATE):
		world.step()


func _start_round(world: RefCounted) -> void:
	_steps(world, SimWorld.COUNTDOWN_SECONDS)


## Mata o mago na lava no próximo tick.
func _kill(world: RefCounted, id: int) -> void:
	world.mages[id].pos = Vector2(1000, 0)
	world.mages[id].hp = 0.01


## Joga uma rodada inteira em que `winner` vence, parando no fim de rodada.
func _play_round(world: RefCounted, winner: int) -> void:
	_start_round(world)
	_kill(world, 1 - winner)
	world.step()


func test_sem_regras_de_partida_o_mundo_e_livre() -> void:
	var world := SimWorld.new()
	_steps(world, 30.0)
	check_eq(world.phase, SimWorld.PHASE_ROUND, "sempre em rodada")
	check_eq(world.arena_radius, SimWorld.DEFAULT_ARENA_RADIUS, "arena não encolhe")


func test_partida_comeca_em_contagem() -> void:
	var world := _match()
	check_eq(world.phase, SimWorld.PHASE_COUNTDOWN, "fase inicial")
	check_eq(world.round_number, 1, "primeira rodada")
	check_eq(world.scores, [0, 0], "placar zerado")
	check_near(world.phase_seconds_left(), SimWorld.COUNTDOWN_SECONDS, "tempo da contagem")
	_steps(world, 1.0)
	check_near(world.phase_seconds_left(), SimWorld.COUNTDOWN_SECONDS - 1.0, "contagem anda")
	_steps(world, SimWorld.COUNTDOWN_SECONDS - 1.0)
	check_eq(world.phase, SimWorld.PHASE_ROUND, "rodada começa depois da contagem")


func test_na_contagem_ninguem_age() -> void:
	var world := _match()
	var start: Vector2 = world.mages[0].pos
	world.step([SimWorld.move_command(0, Vector2.ZERO), SimWorld.cast_command(1, Spells.EMBER, Vector2.ZERO)])
	_steps(world, 1.0)
	check_eq(world.mages[0].pos, start, "não anda")
	check_eq(world.projectiles.size(), 0, "não lança")
	_start_round(world)
	check_eq(world.mages[0].pos, start, "comando da contagem não fica guardado")


func test_arena_encolhe_depois_de_um_tempo_ate_o_minimo() -> void:
	var world := _match({"shrink_delay": 2.0, "shrink_rate": 1.0, "min_arena_radius": 10.0})
	_start_round(world)
	_steps(world, 2.0)
	check_near(world.arena_radius, SimWorld.DEFAULT_ARENA_RADIUS, "ainda inteira no fim da espera", 0.05)
	_steps(world, 3.0)
	check_near(world.arena_radius, SimWorld.DEFAULT_ARENA_RADIUS - 3.0, "encolheu 1 por segundo", 0.05)
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2.ZERO
	_steps(world, 20.0)
	check_near(world.arena_radius, 10.0, "para no raio mínimo")


func test_arena_que_encolhe_deixa_o_mago_na_lava() -> void:
	var world := _match({"shrink_delay": 0.0, "shrink_rate": 4.0, "min_arena_radius": 2.0})
	_start_round(world)
	world.mages[1].pos = Vector2.ZERO
	_steps(world, 3.0)
	check(world.mages[0].hp < SimWorld.MAX_HP, "a lava alcançou quem ficou parado na borda")
	check_eq(world.mages[1].hp, SimWorld.MAX_HP, "quem está no centro segue ileso")


func test_ultimo_vivo_vence_a_rodada() -> void:
	var world := _match()
	_play_round(world, 0)
	check_eq(world.phase, SimWorld.PHASE_ROUND_END, "fim de rodada")
	check_eq(world.round_winner, 0, "vencedor")
	check_eq(world.scores, [1, 0], "placar")


func test_no_fim_de_rodada_o_vencedor_nao_morre() -> void:
	var world := _match()
	_play_round(world, 0)
	world.mages[0].pos = Vector2(1000, 0)
	_steps(world, 1.0)
	check_eq(world.mages[0].hp, SimWorld.MAX_HP, "sem dano de lava")
	check_eq(world.scores, [1, 0], "placar não muda")


func test_nova_rodada_restaura_tudo() -> void:
	var world := _match({"shrink_delay": 0.0, "shrink_rate": 1.0})
	var spawn: Vector2 = world.mages[0].pos
	_start_round(world)
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(50, 50)), SimWorld.move_command(0, Vector2(1, 1))])
	_steps(world, 0.5)
	_kill(world, 1)
	world.step()
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(-50, 50))])
	_steps(world, SimWorld.ROUND_END_SECONDS)
	check_eq(world.phase, SimWorld.PHASE_COUNTDOWN, "contagem da nova rodada")
	check_eq(world.round_number, 2, "número da rodada")
	check_eq(world.scores, [1, 0], "placar mantido")
	check_eq(world.arena_radius, SimWorld.DEFAULT_ARENA_RADIUS, "arena inteira")
	check_eq(world.projectiles.size(), 0, "sem projéteis")
	check_eq(world.mages[0].pos, spawn, "de volta ao ponto inicial")
	for mage: Dictionary in world.mages:
		check(mage.alive and mage.hp == SimWorld.MAX_HP, "mago %d vivo com vida cheia" % mage.id)
		check(mage.move_target == null and mage.vel == Vector2.ZERO, "mago %d parado" % mage.id)
	_start_round(world)
	check_eq(world.cooldown_fraction(0, Spells.EMBER), 0.0, "recargas zeradas")


func test_todos_mortos_no_mesmo_tick_e_empate() -> void:
	var world := _match()
	_start_round(world)
	_kill(world, 0)
	_kill(world, 1)
	world.step()
	check_eq(world.phase, SimWorld.PHASE_ROUND_END, "fim de rodada")
	check_eq(world.round_winner, -1, "sem vencedor")
	check_eq(world.scores, [0, 0], "ninguém pontua")
	_steps(world, SimWorld.ROUND_END_SECONDS)
	check_eq(world.round_number, 2, "joga outra rodada")


func test_quem_chega_ao_numero_de_rodadas_vence_a_partida() -> void:
	var world := _match()
	_play_round(world, 0)
	_steps(world, SimWorld.ROUND_END_SECONDS)
	_play_round(world, 1)
	_steps(world, SimWorld.ROUND_END_SECONDS)
	check_eq(world.match_winner, -1, "1 a 1: partida continua")
	_play_round(world, 1)
	check_eq(world.phase, SimWorld.PHASE_ROUND_END, "mostra o fim da rodada antes")
	_steps(world, SimWorld.ROUND_END_SECONDS)
	check_eq(world.phase, SimWorld.PHASE_MATCH_END, "fim de partida")
	check_eq(world.match_winner, 1, "vencedor da partida")
	check_eq(world.scores, [1, 2], "placar final")


func test_fim_de_partida_congela_o_mundo() -> void:
	var world := _match({"rounds_to_win": 1})
	_play_round(world, 0)
	_steps(world, SimWorld.ROUND_END_SECONDS)
	var pos: Vector2 = world.mages[0].pos
	world.step([SimWorld.move_command(0, pos + Vector2(5, 0))])
	_steps(world, 10.0)
	check_eq(world.phase, SimWorld.PHASE_MATCH_END, "continua no fim de partida")
	check_eq(world.mages[0].pos, pos, "ninguém se move")
