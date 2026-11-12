extends "res://tests/test_case.gd"

const SimWorld := preload("res://sim/sim_world.gd")


func test_fica_parado_sem_comandos() -> void:
	var world := SimWorld.new()
	world.step()
	check_eq(world.mages[0].pos, Vector2.ZERO, "posição")
	check_eq(world.tick, 1, "tick")


func test_anda_na_velocidade_do_mago() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(0, Vector2(100, 0))])
	for i in SimWorld.TICK_RATE - 1:
		world.step()
	check_near(world.mages[0].pos.x, SimWorld.MAGE_SPEED, "x após 1 s", 0.001)
	check_near(world.mages[0].pos.y, 0.0, "z após 1 s")


func test_chega_exatamente_no_alvo_e_para() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(0, Vector2(3, -4))])
	for i in SimWorld.TICK_RATE * 2:
		world.step()
	check_eq(world.mages[0].pos, Vector2(3, -4), "posição final")
	check(world.mages[0].move_target == null, "alvo limpo ao chegar")


func test_vira_para_a_direcao_do_movimento() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(0, Vector2(10, 0))])
	check_near(world.mages[0].facing, PI / 2, "facing para +x")


func test_novo_comando_substitui_o_alvo() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(0, Vector2(10, 0))])
	world.step([SimWorld.move_command(0, Vector2.ZERO)])
	for i in SimWorld.TICK_RATE:
		world.step()
	check_near(world.mages[0].pos.x, 0.0, "voltou ao centro")


func test_comando_para_mago_inexistente_e_ignorado() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(99, Vector2(5, 5))])
	check_eq(world.mages[0].pos, Vector2.ZERO, "ninguém se moveu")


func test_deterministico() -> void:
	check_eq(_run(), _run(), "mesmos comandos, mesmo estado")


func _run() -> String:
	var world := SimWorld.new({"mage_count": 4})
	world.step([SimWorld.move_command(2, Vector2(1.5, 7))])
	for i in 50:
		world.step()
	return var_to_str(world.mages)


func test_mago_nasce_vivo_com_vida_cheia() -> void:
	var world := SimWorld.new()
	check_eq(world.mages[0].hp, SimWorld.MAX_HP, "vida inicial")
	check(world.mages[0].alive, "vivo")


func test_dentro_da_arena_nao_leva_dano() -> void:
	var world := SimWorld.new({"arena_radius": 5.0})
	world.step([SimWorld.move_command(0, Vector2(4.9, 0))])
	for i in SimWorld.TICK_RATE * 3:
		world.step()
	check_eq(world.mages[0].hp, SimWorld.MAX_HP, "vida intacta na borda de dentro")


func test_lava_causa_dano_por_segundo() -> void:
	var world := SimWorld.new({"arena_radius": 5.0})
	world.mages[0].pos = Vector2(6, 0)
	for i in SimWorld.TICK_RATE:
		world.step()
	check_near(world.mages[0].hp, SimWorld.MAX_HP - SimWorld.LAVA_DPS, "vida após 1 s na lava", 0.001)
	check(world.mages[0].alive, "ainda vivo")


func test_morre_quando_a_vida_zera() -> void:
	var world := _world_with_dead_mage()
	check_eq(world.mages[0].hp, 0.0, "vida não fica negativa")
	check(not world.mages[0].alive, "morto")


func test_morto_ignora_comandos_e_nao_se_move() -> void:
	var world := _world_with_dead_mage()
	var pos: Vector2 = world.mages[0].pos
	world.step([SimWorld.move_command(0, Vector2.ZERO)])
	for i in 10:
		world.step()
	check_eq(world.mages[0].pos, pos, "não saiu do lugar")
	check(world.mages[0].move_target == null, "sem alvo de movimento")


func test_morre_andando_e_para_onde_morreu() -> void:
	var world := SimWorld.new({"arena_radius": 5.0})
	world.step([SimWorld.move_command(0, Vector2(1000, 0))])
	for i in SimWorld.TICK_RATE * 10:
		world.step()
	check(not world.mages[0].alive, "morreu na lava")
	var pos: Vector2 = world.mages[0].pos
	world.step()
	check_eq(world.mages[0].pos, pos, "parou ao morrer")


func _world_with_dead_mage() -> RefCounted:
	var world := SimWorld.new({"arena_radius": 5.0})
	world.mages[0].pos = Vector2(6, 0)
	var ticks := ceili(SimWorld.MAX_HP / SimWorld.LAVA_DPS * SimWorld.TICK_RATE) + 2
	for i in ticks:
		world.step()
	return world


func test_conduzir_anda_na_direcao_ate_mandar_parar() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.steer_command(0, Vector2(1, 0))])
	for i in SimWorld.TICK_RATE - 1:
		world.step()
	check_near(world.mages[0].pos.x, SimWorld.MAGE_SPEED, "x após 1 s", 0.001)
	world.step([SimWorld.steer_command(0, Vector2.ZERO)])
	var stopped: Vector2 = world.mages[0].pos
	world.step()
	check_eq(world.mages[0].pos, stopped, "parou com direção zero")


func test_conduzir_na_diagonal_nao_e_mais_rapido() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.steer_command(0, Vector2(5, 5))])
	check_near(world.mages[0].pos.length(), SimWorld.MAGE_SPEED * SimWorld.DT, "passo de um tick")


func test_conduzir_vira_o_mago_para_a_direcao() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.steer_command(0, Vector2(-1, 0))])
	check_near(world.mages[0].facing, -PI / 2, "facing para -x")


func test_conduzir_cancela_o_alvo_do_clique_e_vice_versa() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(0, Vector2(10, 0))])
	world.step([SimWorld.steer_command(0, Vector2(0, 1))])
	check(world.mages[0].move_target == null, "conduzir limpa o alvo")
	var x: float = world.mages[0].pos.x
	world.step([SimWorld.move_command(0, Vector2(x, -10))])
	world.step()
	check_near(world.mages[0].pos.x, x, "segue só o clique")
	check(world.mages[0].pos.y < 0.2, "clique cancela a direção conduzida")


func test_conduzir_com_direcao_zero_nao_cancela_o_clique() -> void:
	var world := SimWorld.new()
	world.step([SimWorld.move_command(0, Vector2(10, 0))])
	world.step([SimWorld.steer_command(0, Vector2.ZERO)])
	check(world.mages[0].move_target != null, "alvo do clique continua")


func test_mago_morto_nao_e_conduzido() -> void:
	var world := SimWorld.new({"arena_radius": 5.0, "mage_count": 2})
	world.mages[0].hp = 0.01
	world.mages[0].pos = Vector2(50, 0)
	world.step([SimWorld.steer_command(0, Vector2(1, 0))])
	world.step()
	var pos: Vector2 = world.mages[0].pos
	world.step()
	check(not world.mages[0].alive, "morreu na lava")
	check_eq(world.mages[0].pos, pos, "morto não anda")
