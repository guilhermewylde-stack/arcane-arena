extends RefCounted
## Fábrica de efeitos: materiais que brilham e partículas (rastros, faíscas, brasas no ar).
## Só cria nós; quem os posiciona e apaga é `arena_view.gd`.

static var _soft_dot: GradientTexture2D
static var _particle_material: StandardMaterial3D
static var _particle_mesh: QuadMesh


## Material que emite luz na cor dada (o bloom faz o halo).
static func glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## Material sem sombra que soma luz ao que está atrás (clarões, halos, anéis de onda).
static func additive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Rastro contínuo que fica para trás de quem o carrega (projéteis).
static func trail(color: Color, size: float) -> CPUParticles3D:
	var particles := _particles(color, 24, 0.4, size)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 1.0
	return particles


## Estouro de faíscas que se apaga sozinho (acertos, explosões, teleportes).
static func sparks(color: Color, amount: int, speed: float) -> CPUParticles3D:
	var particles := _particles(color, amount, 0.55, 0.16)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.35
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.0, 0)
	particles.finished.connect(particles.queue_free)
	return particles


## Chamas subindo de um ponto (mago queimando na lava). Começa desligado.
static func flames() -> CPUParticles3D:
	var particles := _particles(Color(1.0, 0.45, 0.1), 24, 0.6, 0.3)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.5
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.5
	particles.emitting = false
	return particles


## Brasas subindo devagar de toda a lava: dão vida e profundidade ao fundo escuro.
static func embers(extent: float) -> CPUParticles3D:
	var particles := _particles(Color(1.0, 0.4, 0.08), 160, 7.0, 0.14)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(extent, 0.1, extent)
	particles.direction = Vector3.UP
	particles.spread = 30.0
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 2.2
	particles.preprocess = 7.0
	return particles


static func _particles(color: Color, amount: int, lifetime: float, size: float) -> CPUParticles3D:
	if _particle_mesh == null:
		_build_shared()
	var particles := CPUParticles3D.new()
	particles.mesh = _particle_mesh
	particles.amount = amount
	particles.lifetime = lifetime
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size
	particles.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Todas as partículas dividem a mesma malha e o mesmo material (um ponto macio); a cor vem de cada emissor.
static func _build_shared() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	_soft_dot = GradientTexture2D.new()
	_soft_dot.gradient = gradient
	_soft_dot.width = 32
	_soft_dot.height = 32
	_soft_dot.fill = GradientTexture2D.FILL_RADIAL
	_soft_dot.fill_from = Vector2(0.5, 0.5)
	_soft_dot.fill_to = Vector2(1.0, 0.5)
	_particle_material = additive_material(Color.WHITE)
	_particle_material.albedo_texture = _soft_dot
	_particle_material.vertex_color_use_as_albedo = true
	_particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_particle_mesh = QuadMesh.new()
	_particle_mesh.material = _particle_material
