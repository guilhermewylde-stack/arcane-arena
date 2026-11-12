extends Node3D
## Tudo que é visual fica aqui. Recebe o estado da simulação e só desenha.

const CameraRig := preload("res://render/camera_rig.gd")
const Spells := preload("res://sim/spells.gd")

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
## Altura em que os projéteis voam (na mão/cajado do mago).
const PROJECTILE_HEIGHT := 1.1
const ICON_SIZE := 52.0
## Rótulos das teclas da barra de magias, na ordem dos espaços.
const SLOT_LABELS: Array[String] = ["Q", "W", "E", "R", "D", "F"]
## Altura de onde o Cometa começa a cair.
const COMET_HEIGHT := 22.0

var zoom := 1.0

var _camera := Camera3D.new()
var _camera_yaw := 0.0
var _focus := Vector2.ZERO
var _mages := {}
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _marker_life := 0.0
var _lava_material: StandardMaterial3D
var _time := 0.0
var _hud := CanvasLayer.new()
var _bars := {}
var _hud_bar: ColorRect
var _hud_label: Label
var _projectiles := {}
## Clarões de impacto em andamento: { node: MeshInstance3D, life: float (1 → 0), size: float }.
var _bursts: Array[Dictionary] = []
var _spell_icons := {}
var _spell_bar: HBoxContainer
var _shown_spells: Array = []
var _shields := {}
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


## Converte um ponto da tela no ponto correspondente do chão da arena (ou null).
func screen_to_ground(screen_pos: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return null
	return Vector2(hit.x, hit.z)


func show_move_marker(at: Vector2) -> void:
	_marker.position = Vector3(at.x, 0.03, at.y)
	_marker_life = 1.0


## Mostra o que a simulação relatou num `step` (acertos, explosões, teleportes...).
func show_events(events: Array) -> void:
	for event: Dictionary in events:
		var color: Color = Spells.TABLE[event.spell].color
		var at := Vector3(event.pos.x, PROJECTILE_HEIGHT, event.pos.y)
		match event.type:
			"hit":
				_spawn_burst(at, color, 1.6)
			"fizzle":
				_spawn_burst(at, color, 0.6)
			"reflect":
				_spawn_burst(at, color, 2.0)
			"blink":
				_spawn_burst(Vector3(event.from.x, PROJECTILE_HEIGHT, event.from.y), color, 1.2)
				_spawn_burst(at, color, 1.8)
			"nova", "explosion":
				_spawn_burst(Vector3(event.pos.x, 0.2, event.pos.y), color, event.radius)


## Desenha um quadro. `previous` é o `snapshot_positions()` do tick anterior e `alpha` (0..1)
## é o quanto já andamos entre ele e o tick atual.
func draw_world(world: RefCounted, previous: Dictionary, alpha: float, local_mage_id: int, delta: float) -> void:
	_time += delta
	# A plataforma acompanha o raio da simulação (a arena encolhe durante a rodada).
	var shrink: float = world.arena_radius / _arena_radius
	_arena_root.scale = Vector3(shrink, 1.0, shrink)
	for mage: Dictionary in world.mages:
		var node: Node3D = _mages.get(mage.id)
		if node == null:
			node = _create_mage(mage.id)
			node.rotation.y = mage.facing
		var before: Vector2 = previous.mages.get(mage.id, mage.pos)
		var pos := before.lerp(mage.pos, alpha)
		# Na lava o mago afunda um pouco; morto, some dentro dela.
		var sink := 0.0
		if not mage.alive:
			sink = DEATH_SINK
		elif world.is_in_lava(mage.pos):
			sink = LAVA_SINK
		if mage.alive and not node.visible:
			# Voltou à vida numa nova rodada: reaparece de pé, sem subir da lava.
			node.position.y = 0.0
		node.visible = mage.alive or node.position.y > DEATH_SINK + 0.05
		node.position = Vector3(pos.x, move_toward(node.position.y, sink, delta * 4.0), pos.y)
		node.rotation.y = lerp_angle(node.rotation.y, mage.facing, minf(1.0, delta * 14.0))
		_shields[mage.id].visible = world.is_shielded(mage.id)

	_draw_projectiles(world, previous.projectiles, alpha)
	_draw_hazards(world, alpha)
	_draw_bursts(delta)

	var pulse := 0.5 + 0.5 * sin(_time * 1.3)
	_lava_material.emission_energy_multiplier = 0.85 + pulse * 0.2

	_marker_life = maxf(0.0, _marker_life - delta * 2.0)
	_marker.visible = _marker_life > 0.0
	_marker_material.albedo_color.a = _marker_life
	_marker.scale = Vector3.ONE * (0.6 + _marker_life * 0.6)

	var local: Node3D = _mages.get(local_mage_id)
	if local != null:
		zoom = CameraRig.clamp_zoom(zoom)
		var target_yaw := lerp_angle(0.0, local.rotation.y, CameraRig.follow_weight(zoom))
		_camera_yaw = lerp_angle(_camera_yaw, target_yaw, minf(1.0, delta * 5.0))
		# Morto, o jogador vira espectador: a câmera desliza para o centro da arena.
		var local_mage: Dictionary = world.get_mage(local_mage_id)
		var focus_target := Vector2(local.position.x, local.position.z) if local_mage.alive else Vector2.ZERO
		_focus = focus_target if local_mage.alive else _focus.lerp(focus_target, minf(1.0, delta * 2.0))
		var pose := CameraRig.compute_pose(_focus, _camera_yaw, zoom)
		_camera.position = pose.position
		_camera.look_at(pose.look_at)

	_draw_health(world, local_mage_id)
	_draw_match(world, local_mage_id)


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
		_hud_label.text = "%d / %d" % [ceili(local.hp), int(world.MAX_HP)] if local.alive else "Morto"
	if not local.is_empty():
		if local.spells.keys() != _shown_spells:
			_fill_spell_bar(local.spells.keys())
		for spell_id: String in _spell_icons:
			var shade: ColorRect = _spell_icons[spell_id]
			shade.size.y = ICON_SIZE * world.cooldown_fraction(local_mage_id, spell_id)


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
	var warn := StandardMaterial3D.new()
	warn.albedo_color = spell.color
	warn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := _add_mesh(_ring_mesh(spell.radius - 0.25, spell.radius), warn, self)
	ring.position = Vector3(hazard.pos.x, 0.04, hazard.pos.y)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = spell.color
	glow.emission_enabled = true
	glow.emission = spell.color
	glow.emission_energy_multiplier = 4.0
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.8
	rock_mesh.height = 1.6
	var rock := _add_mesh(rock_mesh, glow, self)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock.position = Vector3(hazard.pos.x, COMET_HEIGHT, hazard.pos.y)
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
	var material := StandardMaterial3D.new()
	material.albedo_color = spell.color
	material.emission_enabled = true
	material.emission = spell.color
	material.emission_energy_multiplier = 4.0
	var mesh := SphereMesh.new()
	mesh.radius = spell.radius
	mesh.height = spell.radius * 2.0
	var node := _add_mesh(mesh, material, self)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = spell.color
	light.light_energy = 2.5
	light.omni_range = 5.0
	node.add_child(light)
	_projectiles[id] = node
	return node


## Clarão que cresce e some: marca onde um projétil acertou ou se apagou.
func _spawn_burst(at: Vector3, color: Color, size: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.4)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var node := _add_mesh(mesh, material, self)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.scale = Vector3.ONE * 0.2
	_bursts.append({"node": node, "life": 1.0, "size": size})


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
			_banner.text = "%s a partida!\nPrimeiro a %d rodadas · F5: nova partida" % [who, world.rounds_to_win]


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
	for child in _spell_bar.get_children():
		_spell_bar.remove_child(child)
		child.queue_free()
	for slot: int in mini(spell_ids.size(), SLOT_LABELS.size()):
		_spell_icons[spell_ids[slot]] = _create_spell_icon(spell_ids[slot], SLOT_LABELS[slot])


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
	icon.tooltip_text = spell.name
	_spell_bar.add_child(icon)
	return shade


func _build_environment(arena_radius: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0710")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f9ccc")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("3a1208")
	env.fog_density = 0.006
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = arena_radius * 4.0
	sun.rotation_degrees = Vector3(-58, -40, 0)
	add_child(sun)


func _build_arena(arena_radius: float) -> void:
	_lava_material = StandardMaterial3D.new()
	_lava_material.albedo_color = Color("2a0a04")
	_lava_material.emission_enabled = true
	_lava_material.emission = Color("ff4a12")
	var lava_mesh := PlaneMesh.new()
	lava_mesh.size = Vector2(500, 500)
	var lava := _add_mesh(lava_mesh, _lava_material, self)
	lava.position.y = -1.2

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6b6470")
	stone.roughness = 0.9
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = arena_radius
	platform_mesh.bottom_radius = arena_radius * 0.92
	platform_mesh.height = 1.6
	platform_mesh.radial_segments = 96
	var platform := _add_mesh(platform_mesh, stone, _arena_root)
	platform.position.y = -0.8

	# Anéis decorativos para dar leitura de distância no chão.
	var groove := StandardMaterial3D.new()
	groove.albedo_color = Color("3a3340")
	for fraction: float in [0.33, 0.66, 0.98]:
		var ring := _add_mesh(_ring_mesh(arena_radius * fraction - 0.12, arena_radius * fraction), groove, _arena_root)
		ring.position.y = 0.01

	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = Color("7dffb0")
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker = _add_mesh(_ring_mesh(0.35, 0.5), _marker_material, self)
	_marker.visible = false


func _create_mage(id: int) -> Node3D:
	var root := Node3D.new()
	var robe_material := StandardMaterial3D.new()
	robe_material.albedo_color = MAGE_COLORS[id % MAGE_COLORS.size()]
	robe_material.roughness = 0.7
	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.0
	robe_mesh.bottom_radius = 0.62
	robe_mesh.height = 1.5
	_add_mesh(robe_mesh, robe_material, root).position.y = 0.75

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("e8c9a8")
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.54
	_add_mesh(head_mesh, skin, root).position.y = 1.62

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a2233")
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.0
	hat_mesh.bottom_radius = 0.36
	hat_mesh.height = 0.75
	_add_mesh(hat_mesh, dark, root).position.y = 2.1

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3b22")
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.04
	staff_mesh.bottom_radius = 0.04
	staff_mesh.height = 1.9
	_add_mesh(staff_mesh, wood, root).position = Vector3(0.55, 0.95, 0.25)

	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("bfe6ff")
	glow.emission_enabled = true
	glow.emission = Color("bfe6ff")
	glow.emission_energy_multiplier = 3.0
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.13
	orb_mesh.height = 0.26
	_add_mesh(orb_mesh, glow, root).position = Vector3(0.55, 1.98, 0.25)

	var bubble_material := StandardMaterial3D.new()
	bubble_material.albedo_color = Color(Spells.TABLE[Spells.AEGIS].color, 0.35)
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.emission_enabled = true
	bubble_material.emission = Spells.TABLE[Spells.AEGIS].color
	bubble_material.emission_energy_multiplier = 0.8
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 1.5
	bubble_mesh.height = 3.0
	var bubble := _add_mesh(bubble_mesh, bubble_material, root)
	bubble.position.y = 1.1
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.visible = false
	_shields[id] = bubble

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
