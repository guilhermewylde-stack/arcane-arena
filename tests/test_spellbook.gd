extends "res://tests/test_case.gd"

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")
const Bot := preload("res://sim/bot.gd")

const ALL := [Spells.EMBER, Spells.BLINK, Spells.GALE, Spells.CHAIN, Spells.AEGIS, Spells.COMET, Spells.HOMING]


## Lançador (id 0) no centro e alvo (id 1) em +x; os dois com todas as magias.
func _duel(distance := 5.0, loadout: Array = ALL) -> RefCounted:
	var world := SimWorld.new({"mage_count": 2, "arena_radius": 2000.0, "loadout": loadout})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(distance, 0)
	return world


func _cast(world: RefCounted, spell_id: String, target := Vector2(100, 0), mage_id := 0) -> void:
	world.step([SimWorld.cast_command(mage_id, spell_id, target)])


func _steps(world: RefCounted, seconds: float) -> void:
	for i in roundi(seconds * SimWorld.TICK_RATE):
		world.step()


func _stat(spell_id: String, key: String) -> float:
	return Spells.TABLE[spell_id][key]


func _casts(commands: Array, spell_id: String) -> Array:
	return commands.filter(func(cmd: Dictionary) -> bool: return cmd.type == "cast" and cmd.spell == spell_id)


func test_tabela_tem_as_sete_magias() -> void:
	check_eq(Spells.TABLE.size(), 7, "sete magias")
	for spell_id: String in ALL:
		for key: String in ["name", "behavior", "cooldown", "color"]:
			check(Spells.TABLE[spell_id].has(key), "%s tem '%s'" % [spell_id, key])


func test_mago_comeca_so_com_brasa_e_nao_lanca_o_que_nao_tem() -> void:
	var world := SimWorld.new()
	check_eq(world.mages[0].spells.keys(), [Spells.EMBER], "magias iniciais")
	_cast(world, Spells.BLINK, Vector2(5, 0))
	check_eq(world.mages[0].pos, Vector2.ZERO, "não teleporta sem ter a magia")


func test_passo_etereo_teleporta_ate_o_alcance() -> void:
	var world := _duel(1000.0)
	world.step([SimWorld.move_command(0, Vector2(0, 50))])
	_cast(world, Spells.BLINK, Vector2(3, 0))
	check_near(world.mages[0].pos.x, 3.0, "chega no alvo quando está perto", 0.001)
	check(world.mages[0].move_target == null, "perde o alvo de movimento")
	var blinked: bool = world.events.any(func(event: Dictionary) -> bool: return event.type == "blink")
	check(blinked, "evento de teleporte")
	_steps(world, _stat(Spells.BLINK, "cooldown"))
	var before: Vector2 = world.mages[0].pos
	_cast(world, Spells.BLINK, before + Vector2(0, 500))
	check_near(world.mages[0].pos.distance_to(before), _stat(Spells.BLINK, "range"), "longe demais: anda só o alcance", 0.001)


func test_vendaval_empurra_e_fere_quem_esta_perto() -> void:
	var world := SimWorld.new({"mage_count": 3, "arena_radius": 2000.0, "loadout": ALL})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(_stat(Spells.GALE, "radius") - 1.0, 0)
	world.mages[2].pos = Vector2(0, _stat(Spells.GALE, "radius") + 2.0)
	var far: Vector2 = world.mages[2].pos
	_cast(world, Spells.GALE)
	_steps(world, 3.0)
	check_near(world.mages[1].hp, SimWorld.MAX_HP - _stat(Spells.GALE, "damage"), "dano em quem está no raio")
	check(world.mages[1].pos.x > _stat(Spells.GALE, "radius") + 1.0, "empurrado para longe do lançador")
	check_eq(world.mages[2].pos, far, "quem está fora do raio não é afetado")
	check_eq(world.mages[2].hp, SimWorld.MAX_HP, "nem leva dano")
	check_eq(world.mages[0].hp, SimWorld.MAX_HP, "lançador ileso")
	check_eq(world.mages[0].pos, Vector2.ZERO, "lançador não se move")


func test_corrente_puxa_o_alvo_para_o_lancador() -> void:
	var world := _duel(10.0)
	_cast(world, Spells.CHAIN)
	_steps(world, 3.0)
	check_near(world.mages[1].hp, SimWorld.MAX_HP - _stat(Spells.CHAIN, "damage"), "dano pequeno")
	check(world.mages[1].pos.x < 7.0, "alvo veio para perto (x = %s)" % world.mages[1].pos.x)
	check(world.mages[1].pos.x > 0.0, "sem atravessar o lançador")


func test_egide_reflete_projetil_de_volta() -> void:
	var world := _duel(8.0)
	world.step([
		SimWorld.cast_command(1, Spells.AEGIS, Vector2.ZERO),
		SimWorld.cast_command(0, Spells.EMBER, Vector2(8, 0)),
	])
	check(world.is_shielded(1), "escudo ativo")
	_steps(world, 1.4)
	check_eq(world.mages[1].hp, SimWorld.MAX_HP, "quem tem escudo não leva dano")
	check_eq(world.mages[1].pos, Vector2(8, 0), "nem é empurrado")
	check_near(world.mages[0].hp, SimWorld.MAX_HP - _stat(Spells.EMBER, "damage"), "o projétil volta e acerta quem lançou")


func test_egide_acaba_depois_da_duracao() -> void:
	var world := _duel(8.0)
	_cast(world, Spells.AEGIS, Vector2.ZERO, 1)
	_steps(world, _stat(Spells.AEGIS, "duration") + 0.1)
	check(not world.is_shielded(1), "escudo acabou")
	_cast(world, Spells.EMBER, Vector2(8, 0))
	_steps(world, 1.0)
	check(world.mages[1].hp < SimWorld.MAX_HP, "sem escudo leva dano")


func test_cometa_cai_com_atraso_e_atinge_a_area() -> void:
	var world := SimWorld.new({"mage_count": 3, "arena_radius": 2000.0, "loadout": ALL})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(8, 1)
	world.mages[2].pos = Vector2(8, _stat(Spells.COMET, "radius") + 3.0)
	_cast(world, Spells.COMET, Vector2(8, 0))
	check_eq(world.hazards.size(), 1, "área marcada no chão")
	_steps(world, _stat(Spells.COMET, "delay") - 0.2)
	check_eq(world.mages[1].hp, SimWorld.MAX_HP, "sem dano antes de cair")
	_steps(world, 3.0)
	check_eq(world.hazards.size(), 0, "área some depois do impacto")
	check_near(world.mages[1].hp, SimWorld.MAX_HP - _stat(Spells.COMET, "damage"), "dano na área")
	check(world.mages[1].pos.y > 2.0, "empurrado para longe do centro do impacto")
	check_eq(world.mages[2].hp, SimWorld.MAX_HP, "fora da área, ileso")


func test_cometa_longe_demais_cai_no_limite_do_alcance() -> void:
	var world := _duel(1000.0)
	_cast(world, Spells.COMET, Vector2(500, 0))
	check_near(world.hazards[0].pos.x, _stat(Spells.COMET, "range"), "ponto de queda limitado", 0.001)


func test_fagulha_teleguiada_faz_curva_ate_o_alvo() -> void:
	var straight := _duel()
	straight.mages[1].pos = Vector2(9, 4)
	_cast(straight, Spells.EMBER)
	_steps(straight, 3.0)
	check_eq(straight.mages[1].hp, SimWorld.MAX_HP, "a Brasa reta erra esse alvo")

	var homing := _duel()
	homing.mages[1].pos = Vector2(9, 4)
	_cast(homing, Spells.HOMING)
	_steps(homing, 3.0)
	check_near(homing.mages[1].hp, SimWorld.MAX_HP - _stat(Spells.HOMING, "damage"), "a Fagulha persegue e acerta")


func test_magias_continuam_com_o_mago_na_rodada_seguinte() -> void:
	var world := SimWorld.new({"mage_count": 2, "rounds_to_win": 2, "loadout": [Spells.EMBER, Spells.GALE]})
	for i in roundi(SimWorld.COUNTDOWN_SECONDS * SimWorld.TICK_RATE):
		world.step()
	world.mages[1].pos = Vector2(1000, 0)
	world.mages[1].hp = 0.01
	for i in roundi(SimWorld.ROUND_END_SECONDS * SimWorld.TICK_RATE) + 2:
		world.step()
	check_eq(world.round_number, 2, "segunda rodada")
	check_eq(world.mages[0].spells.keys(), [Spells.EMBER, Spells.GALE], "magias mantidas")


func test_bot_na_lava_usa_passo_etereo_para_voltar() -> void:
	var world := SimWorld.new({"mage_count": 2, "loadout": ALL})
	world.mages[0].pos = Vector2(world.arena_radius + 3.0, 0)
	world.mages[1].pos = Vector2(-10, 0)
	var commands := Bot.new(0, 1).think(world)
	check_eq(_casts(commands, Spells.BLINK).size(), 1, "lança Passo Etéreo")
	world.step(commands)
	check(not world.is_in_lava(world.mages[0].pos), "voltou para a arena")


func test_bot_usa_vendaval_so_com_inimigo_colado() -> void:
	check_eq(_casts(Bot.new(0, 1).think(_duel(2.0)), Spells.GALE).size(), 1, "inimigo colado: lança")
	check_eq(_casts(Bot.new(0, 1).think(_duel(9.0)), Spells.GALE).size(), 0, "inimigo longe: guarda")


func test_bot_levanta_egide_quando_vem_projetil() -> void:
	var world := _duel(6.0)
	check_eq(_casts(Bot.new(1, 1).think(world), Spells.AEGIS).size(), 0, "sem perigo, não gasta")
	_cast(world, Spells.EMBER, Vector2(6, 0))
	check_eq(_casts(Bot.new(1, 1).think(world), Spells.AEGIS).size(), 1, "projétil vindo: escudo")


func test_bot_joga_cometa_no_inimigo_ao_alcance() -> void:
	var casts := _casts(Bot.new(0, 1, "hard").think(_duel(8.0)), Spells.COMET)
	check_eq(casts.size(), 1, "lança Cometa")
	if casts.size() == 1:
		check(casts[0].target.distance_to(Vector2(8, 0)) < 1.0, "em cima do inimigo")
	check_eq(_casts(Bot.new(0, 1).think(_duel(30.0)), Spells.COMET).size(), 0, "fora do alcance, não lança")


func test_bot_so_puxa_com_corrente_quem_esta_mais_para_dentro() -> void:
	var inward := _duel(8.0)
	check_eq(_casts(Bot.new(0, 1).think(inward), Spells.CHAIN).size(), 0, "bot no centro não puxa o inimigo para dentro")
	check_eq(_casts(Bot.new(1, 1).think(inward), Spells.CHAIN).size(), 1, "bot mais na borda puxa o inimigo para fora")


func test_bot_so_com_brasa_nao_inventa_magias() -> void:
	var world := _duel(2.0, [Spells.EMBER])
	world.mages[0].pos = Vector2(world.arena_radius + 3.0, 0)
	for cmd: Dictionary in Bot.new(0, 1).think(world):
		check(cmd.type != "cast" or cmd.spell == Spells.EMBER, "só lança o que tem")
