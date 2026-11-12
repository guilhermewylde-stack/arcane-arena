extends SceneTree
## Teste de fumaça visual: abre o jogo, anda, dá zoom e salva duas capturas.
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
		quit(0 if pos.length() > 1.0 else 1)
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
