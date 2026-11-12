extends "res://tests/test_case.gd"

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")

const EMBER: Dictionary = Spells.TABLE[Spells.EMBER]


## Lançador (id 0) no centro e alvo (id 1) em +x, à distância dada.
func _duel(distance := 5.0) -> RefCounted:
	var world := SimWorld.new({"mage_count": 2, "arena_radius": 2000.0})
	world.mages[0].pos = Vector2.ZERO
	world.mages[1].pos = Vector2(distance, 0)
	return world


func _cast(world: RefCounted, target := Vector2(100, 0)) -> void:
	world.step([SimWorld.cast_command(0, Spells.EMBER, target)])


func _steps(world: RefCounted, seconds: float) -> void:
	for i in roundi(seconds * SimWorld.TICK_RATE):
		world.step()


func test_brasa_e_definida_como_dados() -> void:
	for key: String in ["name", "cooldown", "speed", "range", "radius", "damage", "knockback"]:
		check(EMBER.has(key), "tabela tem '%s'" % key)


func test_lancar_cria_projetil_na_direcao_do_alvo() -> void:
	var world := _duel(1000.0)
	_cast(world, Vector2(0, 50))
	check_eq(world.projectiles.size(), 1, "um projétil")
	var before: Vector2 = world.projectiles[0].pos
	world.step()
	var moved: Vector2 = world.projectiles[0].pos - before
	check_near(moved.x, 0.0, "anda reto em x")
	check_near(moved.y, EMBER.speed * SimWorld.DT, "anda na velocidade da magia", 0.001)
	check_near(world.mages[0].facing, 0.0, "lançador vira para o alvo")


func test_recarga_impede_lancar_de_novo() -> void:
	var world := _duel(1000.0)
	_cast(world)
	_cast(world)
	check_eq(world.projectiles.size(), 1, "segundo lançamento ignorado na recarga")
	check(world.cooldown_fraction(0, Spells.EMBER) > 0.8, "recarga quase cheia logo após lançar")
	_steps(world, EMBER.cooldown)
	check_eq(world.cooldown_fraction(0, Spells.EMBER), 0.0, "recarga terminou")
	var count: int = world.projectiles.size()
	_cast(world)
	check_eq(world.projectiles.size(), count + 1, "lança de novo depois da recarga")


func test_projetil_some_no_fim_do_alcance() -> void:
	var world := _duel(EMBER.range + 3.0)
	_cast(world)
	_steps(world, EMBER.range / EMBER.speed + 0.2)
	check_eq(world.projectiles.size(), 0, "projétil sumiu")
	check_eq(world.mages[1].hp, SimWorld.MAX_HP, "alvo fora do alcance não leva dano")


func test_acerto_causa_dano_e_consome_o_projetil() -> void:
	var world := _duel()
	_cast(world)
	var hit := false
	for i in SimWorld.TICK_RATE:
		world.step()
		for event: Dictionary in world.events:
			if event.type == "hit" and event.target == 1:
				hit = true
	check(hit, "evento de acerto emitido")
	check_near(world.mages[1].hp, SimWorld.MAX_HP - EMBER.damage, "dano da magia")
	check_eq(world.projectiles.size(), 0, "projétil consumido")


func test_projetil_que_passa_longe_nao_acerta() -> void:
	var world := _duel()
	world.mages[1].pos = Vector2(5, 3)
	_cast(world)
	_steps(world, 1.0)
	check_eq(world.mages[1].hp, SimWorld.MAX_HP, "sem dano")


func test_acerto_empurra_na_direcao_do_projetil_e_o_atrito_para() -> void:
	var world := _duel()
	world.step([SimWorld.move_command(1, Vector2(900, 0))])
	_cast(world)
	_steps(world, 1.0)
	var target: Dictionary = world.mages[1]
	check(target.move_target == null, "empurrado perde o alvo de movimento")
	_steps(world, 3.0)
	check(target.pos.x > 6.0 and target.pos.x < 30.0, "foi empurrado para +x e parou de andar (x = %s)" % target.pos.x)
	check_near(target.pos.y, 0.0, "sem desvio lateral", 0.3)
	var rest: Vector2 = target.pos
	_steps(world, 1.0)
	check_eq(target.pos, rest, "o atrito para o mago")


func test_empurrao_cresce_com_o_dano_acumulado() -> void:
	var fresh := _duel()
	_cast(fresh)
	_steps(fresh, 4.0)
	var hurt := _duel()
	hurt.mages[1].hp = 40.0
	_cast(hurt)
	_steps(hurt, 4.0)
	var fresh_push: float = fresh.mages[1].pos.x - 5.0
	var hurt_push: float = hurt.mages[1].pos.x - 5.0
	check(hurt_push > fresh_push * 1.3, "ferido voa mais longe (%s contra %s)" % [hurt_push, fresh_push])


func test_quem_lancou_nao_e_atingido() -> void:
	var world := _duel(1000.0)
	_cast(world)
	check_eq(world.projectiles.size(), 1, "projétil não bate em quem lançou")
	_steps(world, 0.3)
	check_eq(world.mages[0].hp, SimWorld.MAX_HP, "lançador sem dano")
	check_eq(world.mages[0].pos, Vector2.ZERO, "lançador não é empurrado")


func test_morto_nao_lanca_nem_e_atingido() -> void:
	var world := _duel()
	world.mages[1].alive = false
	world.step([SimWorld.cast_command(1, Spells.EMBER, Vector2.ZERO)])
	check_eq(world.projectiles.size(), 0, "morto não lança")
	_cast(world)
	_steps(world, EMBER.range / EMBER.speed + 0.2)
	check_eq(world.mages[1].pos, Vector2(5, 0), "projétil atravessa o morto")


func test_magia_desconhecida_e_ignorada() -> void:
	var world := _duel()
	world.step([SimWorld.cast_command(0, "nao_existe", Vector2(5, 0))])
	check_eq(world.projectiles.size(), 0, "nada lançado")


func test_deterministico_com_magias() -> void:
	check_eq(_run(), _run(), "mesmos comandos, mesmo estado")


func _run() -> String:
	var world := _duel(6.0)
	for i in 4:
		_cast(world, Vector2(6, 0.3 * i))
		_steps(world, EMBER.cooldown)
	return var_to_str(world.mages) + var_to_str(world.projectiles)
