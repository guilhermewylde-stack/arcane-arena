extends Node3D
## Cola do jogo: entrada → comandos → simulação em passo fixo → render interpolado.

const SimWorld := preload("res://sim/sim_world.gd")
const ArenaView := preload("res://render/arena_view.gd")
const Spells := preload("res://sim/spells.gd")
const Bot := preload("res://sim/bot.gd")

const LOCAL_MAGE := 0
const ZOOM_STEP := 0.08
## Partida local: o jogador (id 0) e 3 bots; vence quem ganhar 3 rodadas.
const WORLD_CONFIG := {"mage_count": 4, "rounds_to_win": 3}
const BOT_DIFFICULTY := "normal"
const BOT_SEED := 20261

var world: SimWorld
## Depuração/testes: desligado, os outros magos ficam parados como bonecos de treino.
var bots_enabled := true
var _bots: Array[Bot] = []
var view: ArenaView
var _pending: Array[Dictionary] = []
var _previous: Dictionary
var _accumulator := 0.0


func _ready() -> void:
	restart()
	view = ArenaView.new(world.arena_radius)
	add_child(view)
	var hud := Label.new()
	hud.text = "Botão direito: mover · Q: Brasa na direção do cursor · Scroll: zoom (visão de cima ↔ 3ª pessoa) · F11: tela cheia · F5: nova partida"
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 4)
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				var target: Variant = view.screen_to_ground(event.position)
				if target != null:
					queue_command(SimWorld.move_command(LOCAL_MAGE, target))
					view.show_move_marker(target)
			MOUSE_BUTTON_WHEEL_UP:
				view.zoom -= ZOOM_STEP
			MOUSE_BUTTON_WHEEL_DOWN:
				view.zoom += ZOOM_STEP
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		restart()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		var aim: Variant = view.screen_to_ground(get_viewport().get_mouse_position())
		if aim != null:
			queue_command(SimWorld.cast_command(LOCAL_MAGE, Spells.EMBER, aim))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Começa uma partida nova (a vista reaproveita os nós dos magos).
## Os testes passam outra config, por exemplo sem regras de partida.
func restart(config: Dictionary = WORLD_CONFIG) -> void:
	world = SimWorld.new(config)
	_bots.clear()
	for mage: Dictionary in world.mages:
		if mage.id != LOCAL_MAGE:
			_bots.append(Bot.new(mage.id, BOT_SEED + mage.id, BOT_DIFFICULTY))
	_previous = world.snapshot_positions()
	_pending.clear()


## Toda entrada (jogador, bots, rede) entra no mundo por aqui.
func queue_command(command: Dictionary) -> void:
	_pending.append(command)


func _process(delta: float) -> void:
	_accumulator += minf(delta, 0.1)
	while _accumulator >= SimWorld.DT:
		_previous = world.snapshot_positions()
		if bots_enabled:
			for bot in _bots:
				_pending.append_array(bot.think(world))
		world.step(_pending)
		view.show_events(world.events)
		_pending.clear()
		_accumulator -= SimWorld.DT
	view.draw_world(world, _previous, _accumulator / SimWorld.DT, LOCAL_MAGE, delta)
