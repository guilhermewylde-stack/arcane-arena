extends SceneTree
## Teste de fumaça visual: abre o jogo, anda, dá zoom, morre na lava, reinicia e salva capturas.
## xvfb-run -a godot --path . --rendering-method gl_compatibility -s tests/smoke.gd -- <pasta de saída>

const SimWorld := preload("res://sim/sim_world.gd")

var _main: Node
var _frame := 0
var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 20:
		_save("top.png")
		var target: Variant = _main.view.screen_to_ground(Vector2(root.size) * Vector2(0.7, 0.35))
		_main.queue_command(SimWorld.move_command(0, target))
	elif _frame == 80:
		_main.view.zoom = 0.0
	elif _frame == 200:
		_save("third.png")
		var pos: Vector2 = _main.world.mages[0].pos
		print("posição final do mago: ", pos)
		if pos.length() <= 1.0:
			quit(1)
		# Anda para a lava e fica lá até morrer.
		_main.view.zoom = 0.45
		_main.queue_command(SimWorld.move_command(0, Vector2(-_main.world.arena_radius - 3.0, 0)))
	elif _frame == 400:
		_save("lava.png")
		print("posição na lava: vida ", _main.world.mages[0].hp)
	elif _frame == 560:
		_save("dead.png")
		var dead: bool = not _main.world.mages[0].alive
		print("posição: morto na lava = ", dead)
		if not dead:
			quit(1)
		_main.restart()
	elif _frame == 580:
		var mage: Dictionary = _main.world.mages[0]
		print("posição após reiniciar: ", mage.pos, " vivo = ", mage.alive)
		quit(0 if mage.alive and mage.hp == SimWorld.MAX_HP else 1)
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
