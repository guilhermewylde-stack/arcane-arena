extends "res://tests/test_case.gd"

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")
const Bot := preload("res://sim/bot.gd")

const EMBER: Dictionary = Spells.TABLE[Spells.EMBER]


func _match(extra := {}) -> RefCounted:
	var config := {"mage_count": 2, "rounds_to_win": 3}
	config.merge(extra, true)
	return SimWorld.new(config)


func _steps(world: RefCounted, seconds: float) -> void:
	for i in roundi(seconds * SimWorld.TICK_RATE):
		world.step()


## Joga a contagem, mata o mago 1 e espera o fim de rodada: o mundo fica na loja.
func _to_shop(world: RefCounted) -> void:
	_steps(world, SimWorld.COUNTDOWN_SECONDS)
	world.mages[1].pos = Vector2(1000, 0)
	world.mages[1].hp = 0.01
	world.step()
	_steps(world, SimWorld.ROUND_END_SECONDS)


## Mundo livre com o lançador (id 0) no centro e o alvo (id 1) em +x.
func _duel(distance := 5.0, loadout: Array = [Spells.EMBER]) -> RefCounted:
	var world := SimWorld.new({"mage_count": 2, "arena_radius": 2000.0, "loadout": loadout})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(distance, 0)
	return world


func test_nivel_1_usa_os_numeros_da_tabela_e_niveis_melhoram() -> void:
	check_eq(Spells.stats(Spells.EMBER, 1).damage, EMBER.damage, "nível 1 = tabela")
	check(Spells.stats(Spells.EMBER, 2).damage > EMBER.damage, "nível 2 causa mais dano")
	check(Spells.stats(Spells.EMBER, 3).damage > Spells.stats(Spells.EMBER, 2).damage, "nível 3 mais ainda")
	for spell_id: String in Spells.TABLE:
		var spell: Dictionary = Spells.TABLE[spell_id]
		check(spell.has("cost") and spell.has("upgrade_cost") and spell.has("per_level"), "%s tem preços e níveis" % spell_id)
		check(Spells.stats(spell_id, Spells.MAX_LEVEL) != Spells.stats(spell_id, 1), "%s muda com o nível" % spell_id)
		check(Spells.stats(spell_id, Spells.MAX_LEVEL).cooldown > 0.5, "%s mantém recarga razoável" % spell_id)


func test_ouro_por_dano_causado() -> void:
	var world := _duel()
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(5, 0))])
	_steps(world, 1.0)
	check_near(world.gold[0], EMBER.damage * SimWorld.GOLD_PER_DAMAGE, "quem acertou ganha")
	check_eq(world.gold[1], 0.0, "quem apanhou não ganha")


func test_dano_em_si_mesmo_e_da_lava_nao_da_ouro() -> void:
	var world := _duel(1000.0, [Spells.COMET])
	world.step([SimWorld.cast_command(0, Spells.COMET, Vector2.ZERO)])
	_steps(world, 2.0)
	check(world.mages[0].hp < SimWorld.MAX_HP, "o próprio Cometa fere")
	check_eq(world.gold[0], 0.0, "mas não rende ouro")


func test_ouro_por_abate_vai_para_quem_acertou_por_ultimo() -> void:
	var world := SimWorld.new({"mage_count": 2, "loadout": [Spells.EMBER]})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(5, 0)
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(5, 0))])
	_steps(world, 1.0)
	var before: float = world.gold[0]
	world.mages[1].pos = Vector2(1000, 0)
	world.mages[1].hp = 0.01
	world.step()
	check(not world.mages[1].alive, "alvo morreu na lava")
	check_near(world.gold[0], before + SimWorld.GOLD_PER_KILL, "abate creditado")


func test_morte_sem_ninguem_ter_acertado_nao_da_abate() -> void:
	var world := _match({"shop_seconds": 0.0})
	_steps(world, SimWorld.COUNTDOWN_SECONDS)
	world.mages[1].pos = Vector2(1000, 0)
	world.mages[1].hp = 0.01
	world.step()
	check_near(world.gold[0], SimWorld.GOLD_PER_ROUND + SimWorld.GOLD_ROUND_WIN, "vencedor: rodada + vitória, sem abate")
	check_near(world.gold[1], SimWorld.GOLD_PER_ROUND, "perdedor: só o ouro da rodada")


func test_depois_da_rodada_vem_a_loja_com_tempo_limite() -> void:
	var world := _match()
	_to_shop(world)
	check_eq(world.phase, SimWorld.PHASE_SHOP, "fase de loja")
	check_near(world.phase_seconds_left(), SimWorld.DEFAULT_SHOP_SECONDS, "tempo da loja")
	check(world.mages[1].alive and world.mages[1].hp == SimWorld.MAX_HP, "magos já restaurados")
	var pos: Vector2 = world.mages[0].pos
	world.step([SimWorld.move_command(0, Vector2.ZERO), SimWorld.cast_command(0, Spells.EMBER, Vector2.ZERO)])
	check(world.mages[0].pos == pos and world.projectiles.is_empty(), "na loja ninguém anda nem lança")
	_steps(world, SimWorld.DEFAULT_SHOP_SECONDS)
	check_eq(world.phase, SimWorld.PHASE_COUNTDOWN, "contagem depois da loja")
	check_eq(world.round_number, 2, "segunda rodada")


func test_loja_fecha_quando_todos_estao_prontos() -> void:
	var world := _match()
	_to_shop(world)
	world.step([SimWorld.ready_command(0)])
	check_eq(world.phase, SimWorld.PHASE_SHOP, "falta um")
	world.step([SimWorld.ready_command(1)])
	check_eq(world.phase, SimWorld.PHASE_COUNTDOWN, "todos prontos: começa a contagem")


func test_comprar_magia_nova() -> void:
	var world := _match()
	_to_shop(world)
	world.gold[0] = 100.0
	check_eq(world.price(0, Spells.BLINK), Spells.TABLE[Spells.BLINK].cost, "preço de compra")
	world.step([SimWorld.buy_command(0, Spells.BLINK)])
	check_eq(world.mages[0].spells, {Spells.EMBER: 1, Spells.BLINK: 1}, "magia nova no nível 1")
	check_near(world.gold[0], 100.0 - Spells.TABLE[Spells.BLINK].cost, "ouro descontado")


func test_subir_nivel_ate_o_maximo() -> void:
	var world := _match()
	_to_shop(world)
	world.gold[0] = 1000.0
	check_eq(world.price(0, Spells.EMBER), EMBER.upgrade_cost, "preço de melhoria")
	for i in Spells.MAX_LEVEL + 2:
		world.step([SimWorld.buy_command(0, Spells.EMBER)])
	check_eq(world.mages[0].spells[Spells.EMBER], Spells.MAX_LEVEL, "para no nível máximo")
	check_near(world.gold[0], 1000.0 - EMBER.upgrade_cost * (Spells.MAX_LEVEL - 1), "só paga pelas melhorias feitas")
	check_eq(world.price(0, Spells.EMBER), -1, "no máximo não há mais o que comprar")


func test_sem_ouro_ou_fora_da_loja_nao_compra() -> void:
	var world := _match()
	world.gold[0] = 1000.0
	world.step([SimWorld.buy_command(0, Spells.BLINK)])
	check(not world.mages[0].spells.has(Spells.BLINK), "na contagem não compra")
	_to_shop(world)
	world.gold[0] = 1.0
	world.step([SimWorld.buy_command(0, Spells.BLINK), SimWorld.buy_command(0, "nao_existe")])
	check(not world.mages[0].spells.has(Spells.BLINK), "sem ouro não compra")
	check_near(world.gold[0], 1.0, "ouro intacto")


func test_barra_tem_no_maximo_seis_magias() -> void:
	var world := _match()
	_to_shop(world)
	world.gold[0] = 10000.0
	for spell_id: String in Spells.TABLE:
		world.step([SimWorld.buy_command(0, spell_id)])
	check_eq(world.mages[0].spells.size(), SimWorld.MAX_SPELL_SLOTS, "seis espaços")


func test_compra_vale_na_rodada_seguinte_e_nivel_aumenta_o_dano() -> void:
	var world := _match()
	_to_shop(world)
	world.gold[0] = 1000.0
	world.step([SimWorld.buy_command(0, Spells.EMBER), SimWorld.buy_command(0, Spells.GALE)])
	world.step([SimWorld.ready_command(0), SimWorld.ready_command(1)])
	_steps(world, SimWorld.COUNTDOWN_SECONDS)
	check_eq(world.mages[0].spells, {Spells.EMBER: 2, Spells.GALE: 1}, "compras mantidas")
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(5, 0)
	world.step([SimWorld.cast_command(0, Spells.EMBER, Vector2(5, 0))])
	_steps(world, 0.5)
	check_near(world.mages[1].hp, SimWorld.MAX_HP - Spells.stats(Spells.EMBER, 2).damage, "dano do nível 2")


func test_bot_com_ouro_compra_e_depois_fica_pronto() -> void:
	var world := _match()
	_to_shop(world)
	world.gold[1] = 120.0
	var bot := Bot.new(1, 9)
	world.step([SimWorld.ready_command(0)])
	for i in 40:
		if world.phase != SimWorld.PHASE_SHOP:
			break
		world.step(bot.think(world))
	check_eq(world.phase, SimWorld.PHASE_COUNTDOWN, "bot ficou pronto e a loja fechou")
	var levels := 0
	for level: int in world.mages[1].spells.values():
		levels += level
	check(levels > 1, "bot gastou em magia nova ou melhoria")
	var cheapest := INF
	for spell_id: String in Spells.TABLE:
		var price: int = world.price(1, spell_id)
		if price >= 0:
			cheapest = minf(cheapest, price)
	check(world.gold[1] < cheapest, "gastou até não poder comprar mais nada (sobrou %s)" % world.gold[1])


func test_bot_sem_ouro_so_fica_pronto() -> void:
	var world := _match()
	_to_shop(world)
	world.gold[1] = 0.0
	var commands := Bot.new(1, 9).think(world)
	check_eq(commands.size(), 1, "um comando")
	check_eq(commands[0].type, "ready", "pronto")
