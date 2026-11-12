extends Node3D
## Um mago na tela: modelo animado (KayKit Adventurers, CC0) de manto na cor do jogador, com anel
## no chão e ponta do cajado acesa. Não conhece a simulação: recebe só o que precisa mostrar.

const MageAnim := preload("res://render/mage_anim.gd")
const Fx := preload("res://render/fx.gd")
const MODEL := preload("res://assets/models/mage/Mage.glb")

## Peças do modelo que este jogo não usa (o mago segura só o cajado).
const HIDDEN_PARTS: Array[String] = ["Spellbook", "Spellbook_open", "1H_Wand"]
## Manto inteiro na cor do jogador; chapéu e capa num tom mais escuro da mesma cor.
const ROBE_PARTS: Array[String] = ["Mage_Body", "Mage_ArmLeft", "Mage_ArmRight", "Mage_LegLeft", "Mage_LegRight"]
const TRIM_PARTS: Array[String] = ["Mage_Hat", "Mage_Cape"]
## Velocidade de cada animação (as de reação são aceleradas para caber no tempo de `MageAnim`).
const SPEEDS := {MageAnim.CAST: 2.0, MageAnim.HIT: 1.6, MageAnim.RUN: 1.25}
const BLEND := 0.12
## O modelo é cabeçudo e de chapéu largo: um pouco menor para não tapar a mira em 3ª pessoa.
const MODEL_SCALE := 0.85

## Bolha do escudo (Égide); quem liga e desliga é a vista.
var shield: MeshInstance3D

var _anim := MageAnim.new()
var _player: AnimationPlayer
var _flames: CPUParticles3D
var _ring: MeshInstance3D


func _init(color: Color, shield_color: Color, ring_mesh: Mesh) -> void:
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	_player = model.find_child("AnimationPlayer")
	for clip: String in [MageAnim.IDLE, MageAnim.RUN]:
		_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for part: String in HIDDEN_PARTS:
		model.find_child(part).visible = false
	for group: Array in [[ROBE_PARTS, color], [TRIM_PARTS, color.darkened(0.35)]]:
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = group[1]
		cloth.roughness = 0.9
		for part: String in group[0]:
			(model.find_child(part) as MeshInstance3D).material_override = cloth

	# Ponta do cajado acesa na cor do jogador.
	var staff: Node3D = model.find_child("2H_Staff")
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.13
	orb_mesh.height = 0.26
	var orb := MeshInstance3D.new()
	orb.mesh = orb_mesh
	orb.material_override = Fx.glow_material(color.lightened(0.3), 4.0)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.position.y = 1.2
	staff.add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.6
	light.omni_range = 4.0
	orb.add_child(light)

	# Anel no chão: é o que identifica o mago na visão de cima, mesmo no escuro.
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.material_override = Fx.flat_material(Color(color, 0.85))
	_ring.position.y = 0.03
	add_child(_ring)

	var bubble_material := Fx.flat_material(Color(shield_color, 0.2))
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 1.5
	bubble_mesh.height = 3.0
	shield = MeshInstance3D.new()
	shield.mesh = bubble_mesh
	shield.material_override = bubble_material
	shield.position.y = 1.1
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.visible = false
	add_child(shield)

	_flames = Fx.flames()
	_flames.position.y = 0.9
	add_child(_flames)


## Evento da simulação cujo alvo é este mago ("cast", "hit"...).
func notify(event_type: String) -> void:
	_anim.notify(event_type)


func clip() -> String:
	return _player.assigned_animation


func animate(delta: float, alive: bool, moving: bool, burning: bool) -> void:
	var clip := _anim.update(delta, alive, moving)
	if _player.current_animation != clip and not (clip == MageAnim.DEATH and _player.assigned_animation == clip):
		_player.play(clip, BLEND, SPEEDS.get(clip, 1.0))
	_flames.emitting = burning
	_ring.visible = alive
