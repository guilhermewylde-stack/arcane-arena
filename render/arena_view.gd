extends Node3D
## Tudo que é visual fica aqui. Recebe o estado da simulação e só desenha.

const CameraRig := preload("res://render/camera_rig.gd")

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

var zoom := 1.0

var _camera := Camera3D.new()
var _camera_yaw := 0.0
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


func _init(arena_radius: float) -> void:
	_build_environment(arena_radius)
	_build_arena(arena_radius)
	_camera.fov = 50.0
	_camera.far = 400.0
	add_child(_camera)
	add_child(_hud)
	_build_hud_bar()


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


## Desenha um quadro. `previous` são as posições do tick anterior e `alpha` (0..1)
## é o quanto já andamos entre ele e o tick atual.
func draw_world(world: RefCounted, previous: Dictionary, alpha: float, local_mage_id: int, delta: float) -> void:
	_time += delta
	for mage: Dictionary in world.mages:
		var node: Node3D = _mages.get(mage.id)
		if node == null:
			node = _create_mage(mage.id)
			node.rotation.y = mage.facing
		var before: Vector2 = previous.get(mage.id, mage.pos)
		var pos := before.lerp(mage.pos, alpha)
		# Na lava o mago afunda um pouco; morto, some dentro dela.
		var sink := 0.0
		if not mage.alive:
			sink = DEATH_SINK
		elif world.is_in_lava(mage.pos):
			sink = LAVA_SINK
		node.visible = mage.alive or node.position.y > DEATH_SINK + 0.05
		node.position = Vector3(pos.x, move_toward(node.position.y, sink, delta * 4.0), pos.y)
		node.rotation.y = lerp_angle(node.rotation.y, mage.facing, minf(1.0, delta * 14.0))

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
		var pose := CameraRig.compute_pose(Vector2(local.position.x, local.position.z), _camera_yaw, zoom)
		_camera.position = pose.position
		_camera.look_at(pose.look_at)

	_draw_health(world, local_mage_id)


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
	var platform := _add_mesh(platform_mesh, stone, self)
	platform.position.y = -0.8

	# Anéis decorativos para dar leitura de distância no chão.
	var groove := StandardMaterial3D.new()
	groove.albedo_color = Color("3a3340")
	for fraction: float in [0.33, 0.66, 0.98]:
		var ring := _add_mesh(_ring_mesh(arena_radius * fraction - 0.12, arena_radius * fraction), groove, self)
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
