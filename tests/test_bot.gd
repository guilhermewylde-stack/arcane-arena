extends "res://tests/test_case.gd"

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")
const Bot := preload("res://sim/bot.gd")

const EMBER: Dictionary = Spells.TABLE[Spells.EMBER]


## Bot (id 0) no centro e inimigo (id 1) em +x, à distância dada.
func _duel(distance := 8.0) -> RefCounted:
	var world := SimWorld.new({"mage_count": 2})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(distance, 0)
	return world


func _of_type(commands: Array, type: String) -> Array:
	return commands.filter(func(cmd: Dictionary) -> bool: return cmd.type == type)


func test_bot_morto_nao_gera_comandos() -> void:
	var world := _duel()
	world.mages[0].alive = false
	check_eq(Bot.new(0, 1).think(world).size(), 0, "sem comandos")


func test_bot_parado_escolhe_um_destino_dentro_da_arena() -> void:
	var world := SimWorld.new()
	var moves := _of_type(Bot.new(0, 7).think(world), "move")
	check_eq(moves.size(), 1, "um comando de mover")
	if moves.size() == 1:
		check_eq(moves[0].mage_id, 0, "comando é do próprio bot")
		check(moves[0].target.length() < world.arena_radius * Bot.SAFE_FRACTION, "destino longe da borda")


func test_bot_andando_nao_troca_de_destino() -> void:
	var world := SimWorld.new()
	var bot := Bot.new(0, 7)
	world.step(bot.think(world))
	check(world.mages[0].move_target != null, "está andando")
	check_eq(_of_type(bot.think(world), "move").size(), 0, "não manda mover de novo")


func test_bot_perto_da_borda_volta_para_a_arena() -> void:
	var world := SimWorld.new()
	world.mages[0].pos = Vector2(world.arena_radius + 2.0, 0)
	world.mages[0].move_target = Vector2(world.arena_radius + 9.0, 0)
	var moves := _of_type(Bot.new(0, 3).think(world), "move")
	check_eq(moves.size(), 1, "manda voltar")
	if moves.size() == 1:
		check(moves[0].target.length() < world.arena_radius * Bot.SAFE_FRACTION, "destino dentro da arena")
		check(moves[0].target.x > 0.0, "volta pelo caminho mais curto")


func test_bot_desvia_de_projetil_que_vem_nele() -> void:
	var world := _duel(6.0)
	var bot := Bot.new(1, 5)
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(6, 0))])
	var dodged := false
	for i in SimWorld.TICK_RATE * 2:
		var commands := bot.think(world)
		for cmd: Dictionary in _of_type(commands, "move"):
			if not world.projectiles.is_empty() and absf(cmd.target.y) > 1.0:
				dodged = true
		world.step(commands)
	check(dodged, "andou para o lado enquanto o projétil vinha")
	check_eq(world.mages[1].hp, SimWorld.MAX_HP, "não foi atingido")


func test_bot_facil_nao_desvia() -> void:
	var world := _duel(6.0)
	var bot := Bot.new(1, 5, "easy")
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(6, 0))])
	world.mages[1].move_target = Vector2(6.0, 9.0)
	check_eq(_of_type(bot.think(world), "move").size(), 0, "fica onde está")


func test_bot_ignora_projetil_que_vai_passar_longe() -> void:
	var world := _duel(6.0)
	var bot := Bot.new(1, 5)
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(0, 6))])
	world.mages[1].move_target = Vector2(6.0, 9.0)
	check_eq(_of_type(bot.think(world), "move").size(), 0, "não desvia à toa")


func test_bot_nao_desvia_do_proprio_projetil() -> void:
	var world := _duel(1000.0)
	var bot := Bot.new(0, 5)
	world.mages[0].move_target = Vector2(1.0, 0.0)
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(6, 0))])
	check_eq(_of_type(bot.think(world), "move").size(), 0, "o projétil é dele")


func test_bot_lanca_brasa_no_inimigo_ao_alcance() -> void:
	var world := _duel()
	var casts := _of_type(Bot.new(0, 11).think(world), "cast")
	check_eq(casts.size(), 1, "um lançamento")
	if casts.size() == 1:
		check_eq(casts[0].spell, Spells.EMBER, "Brasa")
		check(casts[0].target.x > 0.0, "na direção do inimigo")


func test_bot_nao_lanca_fora_do_alcance_nem_em_recarga_nem_em_morto() -> void:
	var far := _duel(EMBER.range + 4.0)
	check_eq(_of_type(Bot.new(0, 11).think(far), "cast").size(), 0, "fora do alcance")

	var cooling := _duel()
	var bot := Bot.new(0, 11)
	cooling.step(bot.think(cooling))
	check_eq(_of_type(bot.think(cooling), "cast").size(), 0, "em recarga")

	var dead := _duel()
	dead.mages[1].alive = false
	check_eq(_of_type(Bot.new(0, 11).think(dead), "cast").size(), 0, "inimigo morto")


func test_erro_de_mira_respeita_a_dificuldade() -> void:
	var worst := {}
	for difficulty: String in ["easy", "normal", "hard"]:
		worst[difficulty] = 0.0
		for seed_value in 200:
			var casts := _of_type(Bot.new(0, seed_value, difficulty).think(_duel()), "cast")
			var error: float = absf((casts[0].target as Vector2).angle())
			worst[difficulty] = maxf(worst[difficulty], error)
		check(worst[difficulty] <= Bot.DIFFICULTIES[difficulty].aim_error + 0.0001,
			"%s: erro dentro do limite (%s)" % [difficulty, worst[difficulty]])
	check(worst.easy > worst.normal and worst.normal > worst.hard, "quanto mais difícil, melhor a mira")


func test_bot_persegue_inimigo_distante() -> void:
	var world := SimWorld.new({"mage_count": 2, "arena_radius": 60.0})
	world.mages[0].pos = Vector2(-30, 0)
	world.mages[1].pos = Vector2(30, 0)
	var bot := Bot.new(0, 2, "hard")
	for i in SimWorld.TICK_RATE * 14:
		world.step(bot.think(world))
	check(world.mages[1].hp < SimWorld.MAX_HP, "chegou perto e acertou o inimigo parado")


func test_mesma_semente_mesma_partida() -> void:
	var first := _match(42)
	check_eq(first, _match(42), "determinístico")
	check(first != _match(43), "outra semente, outra partida")


func test_bots_se_enfrentam() -> void:
	var world := SimWorld.new({"mage_count": 4})
	var bots := [Bot.new(0, 1), Bot.new(1, 2), Bot.new(2, 3), Bot.new(3, 4)]
	var damaged := false
	for i in SimWorld.TICK_RATE * 10:
		var commands := []
		for bot: RefCounted in bots:
			commands.append_array(bot.think(world))
		world.step(commands)
	for mage in world.mages:
		if mage.hp < SimWorld.MAX_HP:
			damaged = true
	check(damaged, "em 10 s alguém levou dano")


func _match(seed_value: int) -> String:
	var world := SimWorld.new({"mage_count": 4})
	var bots := []
	for i in 4:
		bots.append(Bot.new(i, seed_value + i))
	for i in SimWorld.TICK_RATE * 15:
		var commands := []
		for bot: RefCounted in bots:
			commands.append_array(bot.think(world))
		world.step(commands)
	return var_to_str(world.mages)


func test_entre_inimigos_a_mesma_distancia_o_alvo_varia() -> void:
	var right := 0
	var left := 0
	for seed_value in 60:
		var world := SimWorld.new({"mage_count": 3})
		world.mages[0].pos = Vector2.ZERO
		world.mages[1].pos = Vector2(8, 0)
		world.mages[2].pos = Vector2(-8, 0)
		var casts := _of_type(Bot.new(0, seed_value).think(world), "cast")
		if casts[0].target.x > 0.0:
			right += 1
		else:
			left += 1
	check(right > 10 and left > 10, "não persegue sempre o mesmo (%d à direita, %d à esquerda)" % [right, left])


func test_inimigo_claramente_mais_perto_e_o_alvo() -> void:
	for seed_value in 30:
		var world := SimWorld.new({"mage_count": 3})
		world.mages[0].pos = Vector2.ZERO
		world.mages[1].pos = Vector2(10, 0)
		world.mages[2].pos = Vector2(-5, 0)
		var casts := _of_type(Bot.new(0, seed_value).think(world), "cast")
		check(casts[0].target.x < 0.0, "mira no mais próximo (semente %d)" % seed_value)
