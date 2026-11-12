extends Node3D
## Um mago na tela: figura de manto, chapéu e cajado montada e animada por código (arte própria,
## proporções naturais). Não conhece a simulação: recebe só o que precisa mostrar.

const MageAnim := preload("res://render/mage_anim.gd")
const Fx := preload("res://render/fx.gd")

const SKIN := Color("c9a184")
const BEARD := Color("b8b2a6")
const WOOD := Color("4a3323")
## Rapidez com que o corpo vai de uma pose à outra.
const POSE_SPEED := 12.0
## A figura é esguia: um pouco maior que o natural para se ler bem na visão de cima.
const BODY_SCALE := 1.25

## Bolha do escudo (Égide); quem liga e desliga é a vista.
var shield: MeshInstance3D

var _anim := MageAnim.new()
var _clip := MageAnim.IDLE
var _time := 0.0
var _flames: CPUParticles3D
var _ring: MeshInstance3D
## Tudo que se inclina, balança e cai junto; os braços giram no ombro.
var _body := Node3D.new()
var _staff_arm := Node3D.new()
var _free_arm := Node3D.new()


func _init(color: Color, shield_color: Color, ring_mesh: Mesh) -> void:
	# Tecido fosco num tom terroso da cor do jogador; chapéu e gola mais escuros.
	var robe := _cloth(color.lerp(Color(0.34, 0.31, 0.28), 0.35).darkened(0.12))
	var trim := _cloth(color.lerp(Color(0.2, 0.18, 0.16), 0.45).darkened(0.35))
	var skin := _cloth(SKIN)
	add_child(_body)
	_body.scale = Vector3.ONE * BODY_SCALE
	_part(_cone(0.2, 0.44, 1.02), robe, _body, Vector3(0, 0.51, 0))
	_part(_cone(0.235, 0.2, 0.5), robe, _body, Vector3(0, 1.25, 0))
	_part(_cone(0.09, 0.3, 0.2), trim, _body, Vector3(0, 1.53, 0))
	_part(_cone(0.215, 0.225, 0.07), trim, _body, Vector3(0, 1.04, 0))
	_part(_ball(0.125), skin, _body, Vector3(0, 1.7, 0))
	_part(_cone(0.085, 0.0, 0.26), _cloth(BEARD), _body, Vector3(0, 1.56, 0.09)).rotation.x = -0.25
	var hat := Node3D.new()
	hat.position = Vector3(0, 1.79, -0.01)
	hat.rotation.x = -0.14
	_body.add_child(hat)
	_part(_cone(0.3, 0.33, 0.035), trim, hat, Vector3.ZERO)
	_part(_cone(0.0, 0.155, 0.55), trim, hat, Vector3(0, 0.28, 0))

	# Com o mago olhando para +z, a direita dele é -x: é a mão do cajado.
	for arm: Node3D in [_staff_arm, _free_arm]:
		arm.position = Vector3(-0.27 if arm == _staff_arm else 0.27, 1.46, 0)
		_body.add_child(arm)
		_part(_cone(0.075, 0.12, 0.6), robe, arm, Vector3(0, -0.3, 0))
		_part(_ball(0.055), skin, arm, Vector3(0, -0.63, 0))
	var staff := _part(_cone(0.022, 0.03, 2.0), _cloth(WOOD), _staff_arm, Vector3(0, -0.28, 0.1))
	var orb := _part(_ball(0.085), Fx.glow_material(color.lightened(0.25), 2.5), staff, Vector3(0, 1.06, 0))
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 3.5
	orb.add_child(light)

	# Anel no chão: identifica o mago na visão de cima.
	_ring = _part(ring_mesh, Fx.flat_material(Color(color, 0.7)), self, Vector3(0, 0.03, 0))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield = _part(_ball(1.5), Fx.flat_material(Color(shield_color, 0.2)), self, Vector3(0, 1.1, 0))
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.visible = false
	_flames = Fx.flames()
	_flames.position.y = 0.9
	add_child(_flames)


## Evento da simulação cujo alvo é este mago ("cast", "hit"...).
func notify(event_type: String) -> void:
	_anim.notify(event_type)


## Animação em cartaz (um dos nomes de `MageAnim`).
func clip() -> String:
	return _clip


func animate(delta: float, alive: bool, moving: bool, burning: bool) -> void:
	_clip = _anim.update(delta, alive, moving)
	_time += delta
	# Pose-alvo: inclinação do corpo (x), altura, e giro de cada braço (x = para a frente, z = para o lado).
	var lean := 0.0
	var height := sin(_time * 2.0) * 0.012
	var staff_arm := Vector3(-0.12, 0, 0)
	var free_arm := Vector3(sin(_time * 2.0) * 0.04, 0, 0.06)
	match _clip:
		MageAnim.RUN:
			var stride := sin(_time * 11.0)
			lean = 0.2
			height = absf(stride) * 0.05
			staff_arm = Vector3(-0.3 + stride * 0.15, 0, 0)
			free_arm = Vector3(-stride * 0.6, 0, 0.1)
		MageAnim.CAST:
			lean = 0.14
			staff_arm = Vector3(-0.5, 0, -0.2)
			free_arm = Vector3(-1.5, 0, -0.15)
		MageAnim.HIT:
			lean = -0.35
			staff_arm = Vector3(0.3, 0, -0.7)
			free_arm = Vector3(0.3, 0, 0.9)
		MageAnim.DEATH:
			lean = -PI * 0.48
			height = 0.22
			staff_arm = Vector3(0.2, 0, -1.2)
			free_arm = Vector3(0.2, 0, 1.2)
	var weight := minf(1.0, delta * POSE_SPEED)
	_body.rotation.x = lerpf(_body.rotation.x, lean, weight)
	_body.position.y = lerpf(_body.position.y, height, weight)
	_staff_arm.rotation = _staff_arm.rotation.lerp(staff_arm, weight)
	_free_arm.rotation = _free_arm.rotation.lerp(free_arm, weight)
	_flames.emitting = burning
	_ring.visible = alive


func _cloth(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _cone(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return mesh


func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _part(mesh: Mesh, material: Material, parent: Node3D, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance
