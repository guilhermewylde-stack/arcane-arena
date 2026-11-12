extends RefCounted
## Simulação pura e determinística. Não conhece nós, cena, entrada nem relógio real.
## O chão é 2D: Vector2(x, y) corresponde a (x, z) no mundo 3D; altura é só visual.
## Interface: `SimWorld.new(config)` e `step(commands)`.

const TICK_RATE := 30
const DT := 1.0 / TICK_RATE
const MAGE_SPEED := 7.0
const DEFAULT_ARENA_RADIUS := 18.0
const MAX_HP := 100.0
## Dano por segundo para quem está fora do raio da arena.
const LAVA_DPS := 25.0

var tick := 0
var arena_radius := DEFAULT_ARENA_RADIUS
## Cada mago: { id: int, pos: Vector2, facing: float, move_target: Variant (Vector2 ou null),
## hp: float, alive: bool }. Mago morto fica na lista, mas não age nem se move.
## `facing` é o ângulo em torno de Y; 0 aponta para +z.
var mages: Array[Dictionary] = []


func _init(config: Dictionary = {}) -> void:
	arena_radius = config.get("arena_radius", DEFAULT_ARENA_RADIUS)
	var count: int = config.get("mage_count", 1)
	for i in count:
		# Magos nascem distribuídos num anel; um mago sozinho nasce no centro.
		var angle := float(i) / count * TAU
		var r := 0.0 if count == 1 else arena_radius * 0.6
		mages.append({
			"id": i,
			"pos": Vector2(sin(angle), cos(angle)) * r,
			"facing": angle + PI,
			"move_target": null,
			"hp": MAX_HP,
			"alive": true,
		})


static func move_command(mage_id: int, target: Vector2) -> Dictionary:
	return {"type": "move", "mage_id": mage_id, "target": target}


## Avança o mundo exatamente um tick, aplicando antes os comandos recebidos.
func step(commands: Array = []) -> void:
	for cmd: Dictionary in commands:
		var mage := get_mage(cmd.mage_id)
		if mage.is_empty() or not mage.alive:
			continue
		if cmd.type == "move":
			mage.move_target = cmd.target
	for mage in mages:
		if not mage.alive:
			continue
		_move_mage(mage)
		if is_in_lava(mage.pos):
			_damage(mage, LAVA_DPS * DT)
	tick += 1


func get_mage(id: int) -> Dictionary:
	for mage in mages:
		if mage.id == id:
			return mage
	return {}


func is_in_lava(pos: Vector2) -> bool:
	return pos.length() > arena_radius


## Cópia das posições, usada pelo render para interpolar entre dois ticks.
func snapshot_positions() -> Dictionary:
	var out := {}
	for mage in mages:
		out[mage.id] = mage.pos
	return out


func _move_mage(mage: Dictionary) -> void:
	if mage.move_target == null:
		return
	var target: Vector2 = mage.move_target
	var to_target: Vector2 = target - mage.pos
	var dist := to_target.length()
	var max_step := MAGE_SPEED * DT
	if dist <= max_step:
		mage.pos = target
		mage.move_target = null
		return
	mage.facing = atan2(to_target.x, to_target.y)
	mage.pos += to_target / dist * max_step


func _damage(mage: Dictionary, amount: float) -> void:
	mage.hp = maxf(0.0, mage.hp - amount)
	if mage.hp <= 0.0:
		mage.alive = false
		mage.move_target = null
