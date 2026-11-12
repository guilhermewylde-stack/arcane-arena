extends SceneTree
## Teste de fumaça visual: abre o jogo, anda, empurra o boneco com Brasa, dá zoom, morre na lava, reinicia, assiste aos bots e salva capturas.
## xvfb-run -a godot --path . --rendering-method gl_compatibility -s tests/smoke.gd -- <pasta de saída>

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")

var _main: Node
var _frame := 0
var _failed := false
var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)
	# Primeira parte: os outros magos ficam parados, como bonecos de treino.
	_main.bots_enabled = false


func _process(_delta: float) -> bool:
	_frame += 1
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
		# Anda para a lava e fica lá até morrer.
		_main.view.zoom = 0.45
		_main.queue_command(SimWorld.move_command(0, Vector2(-world.arena_radius - 3.0, 0)))
	elif _frame == 590:
		_save("lava.png")
		print("posição na lava: vida ", world.mages[0].hp)
	elif _frame == 740:
		_save("dead.png")
		var dead: bool = not world.mages[0].alive
		print("posição: morto na lava = ", dead)
		if not dead:
			_fail("o mago não morreu na lava")
		# Segunda parte: partida de verdade contra os bots, com o jogador parado.
		_main.restart()
		_main.bots_enabled = true
		_main.view.zoom = 1.0
	elif _frame == 745:
		var mage: Dictionary = world.mages[0]
		print("posição após reiniciar: ", mage.pos, " vivo = ", mage.alive)
		if not (mage.alive and mage.hp == SimWorld.MAX_HP):
			_fail("reiniciar não restaurou o mago")
	elif _frame == 860:
		_save("bots.png")
	elif _frame == 1040:
		var moved := 0
		var damaged := 0
		var fresh: RefCounted = SimWorld.new(_main.WORLD_CONFIG)
		for bot: Dictionary in world.mages.slice(1):
			moved += int(bot.pos.distance_to(fresh.mages[bot.id].pos) > 1.0)
		for any: Dictionary in world.mages:
			damaged += int(any.hp < SimWorld.MAX_HP)
		print("posição: bots que andaram = ", moved, " · magos feridos = ", damaged)
		if moved < 3 or damaged == 0:
			_fail("os bots não andaram ou não lutaram")
		quit(1 if _failed else 0)
	return false


func _fail(message: String) -> void:
	_failed = true
	print("posição: FALHA — ", message)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
