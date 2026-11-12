extends SceneTree
## Teste de fumaça visual: abre o jogo, anda, empurra o boneco com Brasa, dá zoom, morre na lava, reinicia, assiste a uma partida de bots e salva capturas.
## xvfb-run -a godot --path . --rendering-method gl_compatibility -s tests/smoke.gd -- <pasta de saída>

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")

var _main: Node
var _frame := 0
var _failed := false
var _round_end_frame := 0
var _shop_frame := 0

const MATCH_CONFIG := {"mage_count": 4, "rounds_to_win": 2, "shrink_delay": 1.0, "shrink_rate": 5.0, "min_arena_radius": 0.0}
var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		# Primeira parte: mundo livre (sem rodadas) e os outros magos parados, como bonecos
		# de treino. Só aqui, e não em _initialize, porque o _ready do jogo já rodou.
		_main.restart({"mage_count": 4, "loadout": Spells.TABLE.keys()})
		_main.bots_enabled = false
	var world: RefCounted = _main.world
	var dummy: Dictionary = world.mages[2]
	if _frame == 20:
		_save("top.png")
		if _main.view.screen_to_ground(Vector2(root.size) * 0.5) == null:
			_fail("o centro da tela não acerta o chão")
		_main.queue_command(SimWorld.move_command(0, Vector2(0, -2)))
	elif _frame >= 130 and _frame <= 280 and (_frame - 130) % 75 == 0:
		# Chegou perto do boneco: lança Brasa nele sempre que a recarga deixa.
		_main.queue_command(SimWorld.cast_command(0, Spells.EMBER, dummy.pos))
	elif _frame == 140:
		_save("spell.png")
	elif _frame == 156:
		_save("impact.png")
		print("posição: vida do boneco após o 1º acerto = ", dummy.hp)
	elif _frame == 285:
		_main.view.zoom = 0.0
	elif _frame == 320:
		_save("third.png")
		var pos: Vector2 = world.mages[0].pos
		print("posição do mago: ", pos, " · boneco: ", dummy.pos, " vida ", dummy.hp)
		if pos.distance_to(Vector2(0, -2)) > 0.01:
			_fail("o mago não chegou ao alvo")
		if not world.is_in_lava(dummy.pos):
			_fail("o boneco não foi empurrado para a lava")
		# Mostra as outras magias: escudo em si, Cometa no boneco 1, Corrente no boneco 3.
		_main.view.zoom = 1.0
		for cast: Array in [[Spells.AEGIS, pos], [Spells.GALE, pos],
				[Spells.COMET, world.mages[1].pos], [Spells.CHAIN, world.mages[3].pos]]:
			_main.queue_command(SimWorld.cast_command(0, cast[0], cast[1]))
	elif _frame == 340:
		_save("spells.png")
		if not world.is_shielded(0) or world.hazards.is_empty():
			_fail("escudo ou Cometa não estão ativos")
	elif _frame == 425:
		print("posição: boneco 1 vida ", world.mages[1].hp, " · boneco 3 em ", world.mages[3].pos)
		if world.mages[1].hp >= SimWorld.MAX_HP or world.mages[3].pos.x < -9.0:
			_fail("Cometa não acertou ou Corrente não puxou")
		# Fagulha lançada meio torta (sem a curva, erraria) e depois o teleporte.
		var me: Vector2 = world.mages[0].pos
		_main.queue_command(SimWorld.cast_command(0, Spells.HOMING, me + (world.mages[3].pos - me).rotated(0.5)))
		_main.queue_command(SimWorld.cast_command(0, Spells.BLINK, Vector2(-5, -6)))
	elif _frame == 440:
		_save("homing.png")
	elif _frame == 500:
		print("posição: após Passo Etéreo ", world.mages[0].pos, " · boneco 3 vida ", world.mages[3].hp)
		if world.mages[0].pos.y > -5.0 or world.mages[3].hp > SimWorld.MAX_HP - 10.0:
			_fail("Passo Etéreo não teleportou ou a Fagulha não achou o boneco")
		# Anda para a lava e fica lá até morrer.
		_main.view.zoom = 0.45
		_main.queue_command(SimWorld.move_command(0, Vector2(-world.arena_radius - 3.0, 0)))
	elif _frame == 770:
		_save("lava.png")
		print("posição na lava: vida ", world.mages[0].hp)
	elif _frame == 920:
		_save("dead.png")
		var dead: bool = not world.mages[0].alive
		print("posição: morto na lava = ", dead)
		if not dead:
			_fail("o mago não morreu na lava")
		# Segunda parte: partida de verdade contra os bots, com o jogador parado.
		# A arena encolhe depressa para a rodada caber no teste.
		_main.restart(MATCH_CONFIG)
		_main.bots_enabled = true
		_main.view.zoom = 1.0
	elif _frame == 980:
		_save("countdown.png")
		var mage: Dictionary = world.mages[0]
		print("posição após reiniciar: ", mage.pos, " vivo = ", mage.alive, " fase = ", world.phase)
		if not (mage.alive and mage.hp == SimWorld.MAX_HP and world.phase == SimWorld.PHASE_COUNTDOWN):
			_fail("a partida não começou em contagem com o mago inteiro")
	elif _frame == 1220:
		_save("round.png")
		var moved := 0
		var fresh: RefCounted = SimWorld.new(MATCH_CONFIG)
		for bot: Dictionary in world.mages.slice(1):
			moved += int(bot.pos.distance_to(fresh.mages[bot.id].pos) > 1.0)
		print("posição: bots que andaram = ", moved, " · raio da arena = ", world.arena_radius)
		if moved < 3 or world.arena_radius >= world.initial_arena_radius:
			_fail("os bots não andaram ou a arena não encolheu")
	elif _frame > 1220 and _round_end_frame == 0 and world.phase != SimWorld.PHASE_ROUND:
		_round_end_frame = _frame
	elif _round_end_frame > 0 and _frame == _round_end_frame + 30:
		_save("round_end.png")
		print("posição: rodada acabou no quadro ", _round_end_frame, " · vencedor = ", world.round_winner,
			" · placar = ", world.scores)
	elif _shop_frame == 0 and world.phase == SimWorld.PHASE_SHOP:
		_shop_frame = _frame
	elif _shop_frame > 0 and _frame == _shop_frame + 30:
		# Na loja: os bots já compraram; o jogador compra o que o ouro dele alcança e encerra.
		_save("shop.png")
		var bought := 0
		for bot: Dictionary in world.mages.slice(1):
			for level: int in bot.spells.values():
				bought += level
			bought -= 1
		print("posição: loja · ouro = ", world.gold, " · compras dos bots = ", bought)
		if bought == 0:
			_fail("nenhum bot comprou nada")
		_main.buy(Spells.EMBER)
		_main.finish_shopping()
	elif _shop_frame > 0 and _frame == _shop_frame + 40:
		print("posição: jogador após a loja = ", world.mages[0].spells, " · fase = ", world.phase)
		if world.phase != SimWorld.PHASE_COUNTDOWN:
			_fail("a loja não fechou com todos prontos")
	elif world.round_number == 2 and world.phase == SimWorld.PHASE_ROUND_END:
		# A segunda rodada (já com as compras) também chegou ao fim: basta.
		_save("round2_end.png")
		print("posição: 2ª rodada acabou no quadro ", _frame, " · placar = ", world.scores, " · ouro = ", world.gold)
		quit(1 if _failed else 0)
	elif _frame == 3200:
		_fail("a segunda rodada não acabou a tempo")
		quit(1)
	return false


func _fail(message: String) -> void:
	_failed = true
	print("posição: FALHA — ", message)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
