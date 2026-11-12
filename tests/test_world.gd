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
