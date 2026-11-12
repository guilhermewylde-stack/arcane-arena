extends Node3D
## Tudo que é visual fica aqui. Recebe o estado da simulação e só desenha.

## Pedidos do jogador feitos na tela da loja; quem escuta (o jogo) transforma em comandos.
signal buy_requested(spell_id: String)
signal ready_requested

const CameraRig := preload("res://render/camera_rig.gd")
const Spells := preload("res://sim/spells.gd")
const MageView := preload("res://render/mage_view.gd")
const Fx := preload("res://render/fx.gd")
const LAVA_SHADER := preload("res://render/lava.gdshader")
const ROCK_SHADER := preload("res://render/rock.gdshader")

const MAGE_COLORS: Array[Color] = [
	Color("4aa3ff"), Color("ff5a4a"), Color("6bd66b"), Color("e0c040"),
	Color("b070ff"), Color("ff8ad0"), Color("50d8d0"), Color("f0f0f0"),
]

const BAR_SIZE := Vector2(64, 8)
const HUD_BAR_SIZE := Vector2(360, 22)
const BAR_BACK := Color(0.05, 0.03, 0.06, 0.85)
## Altura (acima do chão) onde a barra de vida fica ancorada: logo acima do chapéu.
const BAR_ANCHOR_HEIGHT := 2.75
## Quanto o mago afunda quando está na lava, e até onde desce ao morrer.
const LAVA_SINK := -0.9
const DEATH_SINK := -3.2
const LAVA_LEVEL := -1.2
## Altura em que os projéteis voam (na mão/cajado do mago).
const PROJECTILE_HEIGHT := 1.1
const ICON_SIZE := 52.0
## Rótulos das teclas da barra de magias, na ordem dos espaços.
const SLOT_LABELS: Array[String] = ["Q", "W", "E", "R", "D", "F"]
## Em 3ª pessoa as letras são do movimento: a magia é escolhida pelo número e sai no clique.
const SLOT_LABELS_THIRD: Array[String] = ["1", "2", "3", "4", "5", "6"]
const SELECTED_COLOR := Color("ffe9a8")
## Altura de onde o Cometa começa a cair.
const COMET_HEIGHT := 22.0

var zoom := 1.0
## Mira de 3ª pessoa: direção (mesma convenção do `facing`) e distância do retículo ao mago.
## Fora da 3ª pessoa a direção acompanha o mago, para a câmera entrar por trás dele.
var aim_yaw := 0.0
var aim_distance := 9.0
## Espaço da barra que o clique esquerdo lança em 3ª pessoa.
var selected_slot := 0
## Rótulos das teclas da barra na visão de cima (o jogador pode trocar as teclas).
var slot_labels: Array[String] = SLOT_LABELS

var _camera := Camera3D.new()
var _camera_yaw := 0.0
var _focus := Vector2.ZERO
var _mages := {}
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _marker_life := 0.0
var _lava_material: ShaderMaterial
var _rock_material: ShaderMaterial
var _time := 0.0
var _hud := CanvasLayer.new()
var _bars := {}
var _hud_bar: ColorRect
var _hud_label: Label
var _projectiles := {}
## Clarões de impacto em andamento: { node: MeshInstance3D, life: float (1 → 0), size: float }.
var _bursts: Array[Dictionary] = []
var _spell_icons := {}
var _spell_keys: Array[Label] = []
var _reticle: MeshInstance3D
var _spell_bar: HBoxContainer
var _shop: PanelContainer
var _shop_title: Label
var _shop_buttons := {}
var _shop_ready_button: Button
var _shown_spells: Array = []
## Anel de raio 1 usado nas ondas de choque (Vendaval, Cometa).
var _wave_mesh: ArrayMesh
## Avisos de área prestes a explodir: { id: { ring: MeshInstance3D, rock: MeshInstance3D, total: int } }.
var _hazards := {}
var _arena_root := Node3D.new()
var _arena_radius: float
var _banner: Label
var _scoreboard: HBoxContainer


func _init(arena_radius: float) -> void:
	_arena_radius = arena_radius
	add_child(_arena_root)
	_build_environment(arena_radius)
	_build_arena(arena_radius)
	_camera.fov = 50.0
	_camera.far = 400.0
	add_child(_camera)
	add_child(_hud)
	_build_hud_bar()
	_build_spell_bar()
	_build_match_hud()
	_build_shop()


## Converte um ponto da tela no ponto correspondente do chão da arena (ou null).
func screen_to_ground(screen_pos: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return null
	return Vector2(hit.x, hit.z)


func is_third_person() -> bool:
	return CameraRig.is_third_person(zoom)


## Ponto do chão sob o retículo da 3ª pessoa.
func aim_point() -> Vector2:
	return CameraRig.aim_point(_focus, aim_yaw, aim_distance)


## Animação que o mago está mostrando (para testes e depuração).
func mage_clip(id: int) -> String:
	return _mages[id].clip() if _mages.has(id) else ""


func show_move_marker(at: Vector2) -> void:
	_marker.position = Vector3(at.x, 0.03, at.y)
	_marker_life = 1.0


## Mostra o que a simulação relatou num `step` (acertos, explosões, teleportes...).
func show_events(events: Array) -> void:
	for event: Dictionary in events:
		var color: Color = Spells.TABLE[event.spell].color
		var at := Vector3(event.pos.x, PROJECTILE_HEIGHT, event.pos.y)
		var ground := Vector3(event.pos.x, 0.06, event.pos.y)
		if event.has("target") and _mages.has(event.target):
			_mages[event.target].notify(event.type)
		match event.type:
			"hit":
				_spawn_burst(at, color, 1.6)
				_spawn_sparks(at, color, 18, 7.0)
			"fizzle":
				_spawn_burst(at, color, 0.6)
				_spawn_sparks(at, color, 6, 3.0)
			"reflect":
				_spawn_burst(at, color, 2.0)
				_spawn_sparks(at, color, 14, 6.0)
			"blink":
				var from := Vector3(event.from.x, PROJECTILE_HEIGHT, event.from.y)
				_spawn_burst(from, color, 1.2)
				_spawn_sparks(from, color, 16, 4.0)
				_spawn_burst(at, color, 1.8)
				_spawn_sparks(at, color, 16, 4.0)
			"nova":
				_spawn_burst(ground, color, event.radius, _wave_mesh)
				_spawn_sparks(at, color, 24, 9.0)
			"explosion":
				_spawn_burst(ground, color, event.radius, _wave_mesh)
				_spawn_burst(ground, color, event.radius * 0.7)
				_spawn_sparks(ground, color, 40, 11.0)


## Desenha um quadro. `previous` é o `snapshot_positions()` do tick anterior e `alpha` (0..1)
## é o quanto já andamos entre ele e o tick atual.
func draw_world(world: RefCounted, previous: Dictionary, alpha: float, local_mage_id: int, delta: float) -> void:
	_time += delta
	# A plataforma acompanha o raio da simulação (a arena encolhe durante a rodada).
	var shrink: float = world.arena_radius / _arena_radius
	_arena_root.scale = Vector3(shrink, 1.0, shrink)
	for mage: Dictionary in world.mages:
		var node: MageView = _mages.get(mage.id)
		if node == null:
			node = _create_mage(mage.id)
			node.rotation.y = mage.facing
		var before: Vector2 = previous.mages.get(mage.id, mage.pos)
		var pos := before.lerp(mage.pos, alpha)
		# Na lava o mago afunda um pouco e, morto, some dentro dela. Morto na pedra, fica caído
		# até a borda passar por ele.
		var in_lava: bool = world.is_in_lava(mage.pos)
		var sink := 0.0
		if in_lava:
			sink = LAVA_SINK if mage.alive else DEATH_SINK
		if mage.alive and not node.visible:
			# Voltou à vida numa nova rodada: reaparece de pé, sem subir da lava.
			node.position.y = 0.0
		node.visible = mage.alive or node.position.y > DEATH_SINK + 0.05
		var moving: bool = mage.move_target != null or mage.move_dir != Vector2.ZERO
		node.animate(delta, mage.alive, moving, in_lava and node.position.y > DEATH_SINK * 0.6)
		node.position = Vector3(pos.x, move_toward(node.position.y, sink, delta * 4.0), pos.y)
		node.rotation.y = lerp_angle(node.rotation.y, mage.facing, minf(1.0, delta * 14.0))
		node.shield.visible = world.is_shielded(mage.id)

	# Partida nova com menos magos: os nós que sobraram da anterior ficam escondidos.
	for id: int in _mages:
		if id >= world.mages.size():
			_mages[id].visible = false
			_bars[id].visible = false

	_draw_projectiles(world, previous.projectiles, alpha)
	_draw_hazards(world, alpha)
	_draw_bursts(delta)

	var pulse := 0.5 + 0.5 * sin(_time * 1.3)
	_lava_material.set_shader_parameter("energy", 0.8 + pulse * 0.1)
	_rock_material.set_shader_parameter("edge_radius", world.arena_radius)
	_rock_material.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_time * 4.0))

	_marker_life = maxf(0.0, _marker_life - delta * 2.0)
	_marker.visible = _marker_life > 0.0
	_marker_material.albedo_color.a = _marker_life
	_marker.scale = Vector3.ONE * (0.6 + _marker_life * 0.6)

	var local: Node3D = _mages.get(local_mage_id)
	if local != null:
		zoom = CameraRig.clamp_zoom(zoom)
		var third := is_third_person()
		var local_mage: Dictionary = world.get_mage(local_mage_id)
		aim_distance = CameraRig.clamp_aim_distance(aim_distance)
		if not third:
			aim_yaw = local_mage.facing
		var target_yaw := lerp_angle(0.0, aim_yaw, CameraRig.follow_weight(zoom))
		# Em 3ª pessoa a câmera obedece ao mouse quase na hora; de cima, gira com calma.
		_camera_yaw = lerp_angle(_camera_yaw, target_yaw, minf(1.0, delta * (30.0 if third else 5.0)))
		# Morto, o jogador vira espectador: a câmera desliza para o centro da arena.
		var focus_target := Vector2(local.position.x, local.position.z) if local_mage.alive else Vector2.ZERO
		_focus = focus_target if local_mage.alive else _focus.lerp(focus_target, minf(1.0, delta * 2.0))
		var pose := CameraRig.compute_pose(_focus, _camera_yaw, zoom)
		_camera.position = pose.position
		_camera.look_at(pose.look_at)
		_reticle.visible = third and local_mage.alive
		var aim := aim_point()
		_reticle.position = Vector3(aim.x, 0.04, aim.y)

	_draw_health(world, local_mage_id)
	_draw_match(world, local_mage_id)
	_draw_shop(world, local_mage_id)


## Barras de vida em tamanho fixo de tela, para ficarem legíveis em qualquer zoom.
func _draw_health(world: RefCounted, local_mage_id: int) -> void:
	for mage: Dictionary in world.mages:
		var node: Node3D = _mages[mage.id]
		var bar: ColorRect = _bars[mage.id]
		var anchor := node.position + Vector3.UP * BAR_ANCHOR_HEIGHT
		bar.visible = mage.alive and not _camera.is_position_behind(anchor)
		if not bar.visible:
			continue
		bar.position = (_camera.unproject_position(anchor) - Vector2(BAR_SIZE.x * 0.5, BAR_SIZE.y)).round()
		_set_fill(bar, mage.hp / world.MAX_HP)

	var local: Dictionary = world.get_mage(local_mage_id)
	if not local.is_empty():
		_set_fill(_hud_bar, local.hp / world.MAX_HP)
		_hud_label.text = ("%d / %d" % [ceili(local.hp), int(world.MAX_HP)] if local.alive else "Morto") \
			+ "   ·   Ouro %d" % floori(world.gold[local_mage_id])
	if not local.is_empty():
		if local.spells.keys() != _shown_spells:
			_fill_spell_bar(local.spells.keys())
		for spell_id: String in _spell_icons:
			var shade: ColorRect = _spell_icons[spell_id]
			shade.size.y = ICON_SIZE * world.cooldown_fraction(local_mage_id, spell_id)
		var third := is_third_person()
		for slot: int in _spell_keys.size():
			_spell_keys[slot].text = (SLOT_LABELS_THIRD if third else slot_labels)[slot]
			var icon: ColorRect = _spell_keys[slot].get_parent()
			icon.color = SELECTED_COLOR if third and slot == selected_slot else BAR_BACK


## Área marcada no chão (anel que pulsa) e a pedra caindo até o momento do impacto.
func _draw_hazards(world: RefCounted, alpha: float) -> void:
	var seen := {}
	for hazard: Dictionary in world.hazards:
		seen[hazard.id] = true
		var spell: Dictionary = Spells.stats(hazard.spell, hazard.level)
		if not _hazards.has(hazard.id):
			_hazards[hazard.id] = _create_hazard(hazard, spell)
		var entry: Dictionary = _hazards[hazard.id]
		var left: float = clampf((hazard.ticks_left - alpha) / entry.total, 0.0, 1.0)
		entry.rock.position.y = PROJECTILE_HEIGHT + left * COMET_HEIGHT
		entry.ring.material_override.albedo_color.a = 0.45 + 0.4 * sin(_time * 18.0)
	for id: int in _hazards.keys():
		if not seen.has(id):
			_hazards[id].ring.queue_free()
			_hazards[id].rock.queue_free()
			_hazards.erase(id)


func _create_hazard(hazard: Dictionary, spell: Dictionary) -> Dictionary:
	var warn := Fx.flat_material(spell.color)
	var ring := _add_mesh(_ring_mesh(spell.radius - 0.25, spell.radius), warn, self)
	ring.position = Vector3(hazard.pos.x, 0.04, hazard.pos.y)
	var glow := Fx.glow_material(spell.color.darkened(0.2), 1.2)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.8
	rock_mesh.height = 1.6
	var rock := _add_mesh(rock_mesh, glow, self)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock.position = Vector3(hazard.pos.x, COMET_HEIGHT, hazard.pos.y)
	rock.add_child(Fx.trail(spell.color, 0.5))
	return {"ring": ring, "rock": rock, "total": maxi(1, hazard.ticks_left)}


func _draw_projectiles(world: RefCounted, previous: Dictionary, alpha: float) -> void:
	var seen := {}
	for projectile: Dictionary in world.projectiles:
		seen[projectile.id] = true
		var node: Node3D = _projectiles.get(projectile.id)
		if node == null:
			node = _create_projectile(projectile.id, Spells.TABLE[projectile.spell])
		var before: Vector2 = previous.get(projectile.id, projectile.pos)
		var pos := before.lerp(projectile.pos, alpha)
		node.position = Vector3(pos.x, PROJECTILE_HEIGHT, pos.y)
	for id: int in _projectiles.keys():
		if not seen.has(id):
			_projectiles[id].queue_free()
			_projectiles.erase(id)


func _create_projectile(id: int, spell: Dictionary) -> Node3D:
	# Núcleo quase branco, halo na cor da magia e um rastro de faíscas.
	var mesh := SphereMesh.new()
	mesh.radius = spell.radius * 0.7
	mesh.height = spell.radius * 1.4
	var node := _add_mesh(mesh, Fx.glow_material(spell.color.lightened(0.3), 1.8), self)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = spell.radius * 1.6
	halo_mesh.height = spell.radius * 3.2
	var halo := _add_mesh(halo_mesh, Fx.flat_material(Color(spell.color, 0.3)), node)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(Fx.trail(spell.color, spell.radius * 0.7))
	var light := OmniLight3D.new()
	light.light_color = spell.color
	light.light_energy = 1.2
	light.omni_range = 4.0
	node.add_child(light)
	_projectiles[id] = node
	return node


## Clarão que cresce e some: marca onde um projétil acertou ou se apagou.
## Com `shape` (um anel de raio 1) vira onda de choque no chão.
func _spawn_burst(at: Vector3, color: Color, size: float, shape: Mesh = null) -> void:
	var material := Fx.flat_material(color.lightened(0.4))
	var mesh := shape
	if mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		mesh = sphere
	var node := _add_mesh(mesh, material, self)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.scale = Vector3.ONE * 0.2
	_bursts.append({"node": node, "life": 1.0, "size": size})


func _spawn_sparks(at: Vector3, color: Color, amount: int, speed: float) -> void:
	var sparks := Fx.sparks(color, amount, speed)
	sparks.position = at
	add_child(sparks)
	sparks.emitting = true


func _draw_bursts(delta: float) -> void:
	for burst in _bursts:
		burst.life -= delta * 3.0
		var node: MeshInstance3D = burst.node
		if burst.life <= 0.0:
			node.queue_free()
			continue
		node.scale = Vector3.ONE * lerpf(burst.size, 0.2, burst.life * burst.life)
		node.material_override.albedo_color.a = burst.life
	_bursts = _bursts.filter(func(burst: Dictionary) -> bool: return burst.life > 0.0)


func _set_fill(bar: ColorRect, fraction: float) -> void:
	var fill: ColorRect = bar.get_child(0)
	fill.size.x = (bar.size.x - 2.0) * clampf(fraction, 0.0, 1.0)
	fill.color = Color("e03a2e").lerp(Color("58d858"), smoothstep(0.2, 0.7, fraction))


## Barra = fundo escuro com um preenchimento filho (índice 0).
func _create_bar(bar_size: Vector2) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = BAR_BACK
	bar.size = bar_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.position = Vector2.ONE
	fill.size = bar_size - Vector2(2, 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	return bar


func _build_hud_bar() -> void:
	_hud_bar = _create_bar(HUD_BAR_SIZE)
	_hud_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE, 40)
	_hud_label = Label.new()
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 14)
	_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override("outline_size", 4)
	_hud_bar.add_child(_hud_label)
	_hud.add_child(_hud_bar)


## Loja entre rodadas: uma linha por magia com nível e preço; fica apagado o que não dá para comprar.
func _draw_shop(world: RefCounted, local_mage_id: int) -> void:
	_shop.visible = world.phase == world.PHASE_SHOP
	if not _shop.visible:
		return
	_shop_title.text = "Loja  ·  Ouro %d  ·  %d s" % [floori(world.gold[local_mage_id]), ceili(world.phase_seconds_left())]
	var spells: Dictionary = world.get_mage(local_mage_id).spells
	var number := 1
	for spell_id: String in _shop_buttons:
		var button: Button = _shop_buttons[spell_id]
		var cost: int = world.price(local_mage_id, spell_id)
		var level: int = spells.get(spell_id, 0)
		var offer := "nível máximo" if level >= Spells.MAX_LEVEL else "barra cheia"
		if cost >= 0:
			offer = ("comprar" if level == 0 else "nível %d → %d" % [level, level + 1]) + "  ·  %d ouro" % cost
		button.text = "%d   %s  —  %s" % [number, Spells.TABLE[spell_id].name, offer]
		button.disabled = not world.can_buy(local_mage_id, spell_id)
		number += 1
	var done: bool = world.shop_ready[local_mage_id]
	_shop_ready_button.disabled = done
	_shop_ready_button.text = "Aguardando os outros..." if done else "Pronto (Espaço)"


func _build_shop() -> void:
	_shop = PanelContainer.new()
	_shop.set_anchors_preset(Control.PRESET_CENTER)
	_shop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shop.grow_vertical = Control.GROW_DIRECTION_BOTH
	_shop.visible = false
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.07, 0.05, 0.1, 0.94)
	backdrop.set_corner_radius_all(8)
	_shop.add_theme_stylebox_override("panel", backdrop)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_shop.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_shop_title = Label.new()
	_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_shop_title)
	for spell_id: String in Spells.TABLE:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(430, 0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", Spells.TABLE[spell_id].color.lightened(0.3))
		button.pressed.connect(func() -> void: buy_requested.emit(spell_id))
		column.add_child(button)
		_shop_buttons[spell_id] = button
	_shop_ready_button = Button.new()
	_shop_ready_button.focus_mode = Control.FOCUS_NONE
	_shop_ready_button.pressed.connect(func() -> void: ready_requested.emit())
	column.add_child(_shop_ready_button)
	_hud.add_child(_shop)


static func mage_name(id: int, local_mage_id: int) -> String:
	return "Você" if id == local_mage_id else "Bot %d" % id


## Placar no topo e faixa central com contagem, vencedor da rodada e da partida.
func _draw_match(world: RefCounted, local_mage_id: int) -> void:
	_scoreboard.visible = world.rounds_to_win > 0
	_banner.text = ""
	if not _scoreboard.visible:
		return
	while _scoreboard.get_child_count() < world.scores.size():
		var entry := Label.new()
		entry.add_theme_font_size_override("font_size", 20)
		entry.add_theme_color_override("font_color", MAGE_COLORS[_scoreboard.get_child_count() % MAGE_COLORS.size()])
		entry.add_theme_color_override("font_outline_color", Color.BLACK)
		entry.add_theme_constant_override("outline_size", 6)
		_scoreboard.add_child(entry)
	for id: int in _scoreboard.get_child_count():
		_scoreboard.get_child(id).visible = id < world.scores.size()
	for id: int in world.scores.size():
		var entry: Label = _scoreboard.get_child(id)
		entry.text = "%s  %d" % [mage_name(id, local_mage_id), world.scores[id]]
		entry.modulate.a = 1.0 if world.get_mage(id).alive else 0.45
	match world.phase:
		world.PHASE_COUNTDOWN:
			_banner.text = "Rodada %d\n%d" % [world.round_number, ceili(world.phase_seconds_left())]
		world.PHASE_ROUND_END:
			if world.round_winner < 0:
				_banner.text = "Empate"
			elif world.round_winner == local_mage_id:
				_banner.text = "Você venceu a rodada!"
			else:
				_banner.text = "%s venceu a rodada" % mage_name(world.round_winner, local_mage_id)
		world.PHASE_MATCH_END:
			var who := "Você venceu" if world.match_winner == local_mage_id \
				else "%s venceu" % mage_name(world.match_winner, local_mage_id)
			_banner.text = "%s a partida!\nPrimeiro a %d rodadas · F5: nova partida · Esc: menu" % [who, world.rounds_to_win]


func _build_match_hud() -> void:
	_scoreboard = HBoxContainer.new()
	_scoreboard.add_theme_constant_override("separation", 36)
	_scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
	_scoreboard.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_scoreboard)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.offset_bottom = -260.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	_hud.add_child(_banner)


func _build_spell_bar() -> void:
	_spell_bar = HBoxContainer.new()
	_spell_bar.add_theme_constant_override("separation", 8)
	_spell_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spell_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_spell_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_spell_bar.offset_bottom = -72.0
	_spell_bar.offset_top = -72.0
	_hud.add_child(_spell_bar)


## Refaz a barra: um ícone por magia do jogador, na ordem das teclas.
func _fill_spell_bar(spell_ids: Array) -> void:
	_shown_spells = spell_ids.duplicate()
	_spell_icons.clear()
	_spell_keys.clear()
	for child in _spell_bar.get_children():
		_spell_bar.remove_child(child)
		child.queue_free()
	for slot: int in mini(spell_ids.size(), SLOT_LABELS.size()):
		_spell_icons[spell_ids[slot]] = _create_spell_icon(spell_ids[slot], slot_labels[slot])


## Ícone da magia com a tecla; uma sombra desce de cima enquanto a recarga corre.
## Devolve a sombra, que é o que muda a cada quadro.
func _create_spell_icon(spell_id: String, key_label: String) -> ColorRect:
	var spell: Dictionary = Spells.TABLE[spell_id]
	var icon := ColorRect.new()
	icon.color = BAR_BACK
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	var gem := ColorRect.new()
	gem.color = spell.color.darkened(0.15)
	gem.position = Vector2(3, 3)
	gem.size = Vector2.ONE * (ICON_SIZE - 6.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(gem)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.size = Vector2(ICON_SIZE, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(shade)
	var key := Label.new()
	key.text = key_label
	key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 22)
	key.add_theme_color_override("font_outline_color", Color.BLACK)
	key.add_theme_constant_override("outline_size", 6)
	icon.add_child(key)
	_spell_keys.append(key)
	icon.tooltip_text = spell.name
	_spell_bar.add_child(icon)
	return shade


func _build_environment(arena_radius: float) -> void:
	# Fantasia clara: dia de céu azul, sol quente, cores vivas. A lava é só o perigo, não a luz da cena.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3d7fd6")
	sky_material.sky_horizon_color = Color("cfe4f7")
	sky_material.ground_bottom_color = Color("c9783a")
	sky_material.ground_horizon_color = Color("f0c9a0")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe6ff")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Sol quente de cima (forma e sombra) e um leve clarão da lava de baixo.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff2d6")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = arena_radius * 4.0
	sun.rotation_degrees = Vector3(-55, -40, 0)
	add_child(sun)
	var underglow := DirectionalLight3D.new()
	underglow.light_color = Color("ff7a2a")
	underglow.light_energy = 0.25
	underglow.rotation_degrees = Vector3(65, 30, 0)
	add_child(underglow)


func _build_arena(arena_radius: float) -> void:
	_lava_material = ShaderMaterial.new()
	_lava_material.shader = LAVA_SHADER
	var lava_mesh := PlaneMesh.new()
	lava_mesh.size = Vector2(500, 500)
	var lava := _add_mesh(lava_mesh, _lava_material, self)
	lava.position.y = LAVA_LEVEL
	var embers := Fx.embers(arena_radius * 2.5)
	embers.position.y = LAVA_LEVEL
	add_child(embers)
	_wave_mesh = _ring_mesh(0.82, 1.0)

	_rock_material = ShaderMaterial.new()
	_rock_material.shader = ROCK_SHADER
	var stone := _rock_material
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = arena_radius
	platform_mesh.bottom_radius = arena_radius * 0.92
	platform_mesh.height = 1.6
	platform_mesh.radial_segments = 96
	var platform := _add_mesh(platform_mesh, stone, _arena_root)
	platform.position.y = -0.8

	# Anéis decorativos para dar leitura de distância no chão.
	var groove := StandardMaterial3D.new()
	groove.albedo_color = Color("5f584c")
	for fraction: float in [0.33, 0.66, 0.98]:
		var ring := _add_mesh(_ring_mesh(arena_radius * fraction - 0.12, arena_radius * fraction), groove, _arena_root)
		ring.position.y = 0.01

	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = Color("7dffb0")
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker = _add_mesh(_ring_mesh(0.35, 0.5), _marker_material, self)
	_marker.visible = false

	# Retículo da 3ª pessoa: desenhado por cima de tudo, para o mago não o esconder.
	var reticle_material := StandardMaterial3D.new()
	reticle_material.albedo_color = Color("fff3c4")
	reticle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reticle_material.no_depth_test = true
	reticle_material.render_priority = 10
	_reticle = _add_mesh(_ring_mesh(0.42, 0.56), reticle_material, self)
	_add_mesh(_ring_mesh(0.0, 0.1, 16), reticle_material, _reticle)
	_reticle.visible = false


func _create_mage(id: int) -> MageView:
	var root := MageView.new(MAGE_COLORS[id % MAGE_COLORS.size()], Spells.TABLE[Spells.AEGIS].color, _ring_mesh(0.72, 0.9, 48))
	add_child(root)
	_mages[id] = root
	var bar := _create_bar(BAR_SIZE)
	_hud.add_child(bar)
	_hud.move_child(bar, 0)
	_bars[id] = bar
	return root


func _add_mesh(mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Anel plano no chão (plano XZ), virado para cima.
func _ring_mesh(inner: float, outer: float, segments := 96) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in segments:
		var a0 := float(i) / segments * TAU
		var a1 := float(i + 1) / segments * TAU
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		for v: Vector3 in [d0 * inner, d1 * outer, d0 * outer, d0 * inner, d1 * inner, d1 * outer]:
			vertices.append(v)
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
