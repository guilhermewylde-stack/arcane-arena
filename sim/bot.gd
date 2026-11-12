extends RefCounted
## Cérebro de um bot: olha o mundo e devolve comandos, como um jogador faria.
## Não altera o mundo. O único estado próprio é o RNG com semente, então a mesma
## semente com o mesmo mundo gera sempre os mesmos comandos.
## Interface: `Bot.new(mage_id, seed, difficulty)` e `think(world) -> Array` (uma vez por tick).

const SimWorld := preload("res://sim/sim_world.gd")
const Spells := preload("res://sim/spells.gd")

## `aim_error`: desvio máximo da mira, em radianos. `dodges`: desvia de projéteis.
const DIFFICULTIES := {
	"easy": {"aim_error": 0.35, "dodges": false},
	"normal": {"aim_error": 0.15, "dodges": true},
	"hard": {"aim_error": 0.04, "dodges": true},
}
## Além desta fração do raio da arena o bot larga tudo e volta para dentro.
const SAFE_FRACTION := 0.85
## Fração do raio dentro da qual o bot escolhe seus destinos.
const ROAM_FRACTION := 0.7
## Só lança quando o inimigo está dentro desta fração do alcance da magia.
const CAST_RANGE_FRACTION := 0.9
## Distância (mín., máx.) que o bot tenta manter do inimigo ao circular.
const ORBIT_DISTANCE := Vector2(5.0, 10.0)
## Só reage a projéteis que chegam em menos tempo que isto (segundos).
const DODGE_REACTION := 0.7
const DODGE_MARGIN := 0.5
const DODGE_STEP := 3.0

var mage_id: int
var difficulty: Dictionary

var _rng := RandomNumberGenerator.new()


func _init(id: int, seed_value: int, difficulty_name := "normal") -> void:
	mage_id = id
	difficulty = DIFFICULTIES[difficulty_name]
	_rng.seed = seed_value


func think(world: RefCounted) -> Array:
	var me: Dictionary = world.get_mage(mage_id)
	if me.is_empty() or not me.alive:
		return []
	var commands := []
	var enemy := _nearest_enemy(world, me)

	if not enemy.is_empty() and world.cooldown_fraction(mage_id, Spells.EMBER) == 0.0:
		var to_enemy: Vector2 = enemy.pos - me.pos
		if to_enemy.length() <= Spells.TABLE[Spells.EMBER].range * CAST_RANGE_FRACTION:
			var error := _rng.randf_range(-difficulty.aim_error, difficulty.aim_error)
			commands.append(SimWorld.cast_command(mage_id, Spells.EMBER, me.pos + to_enemy.rotated(error)))

	var safe_radius: float = world.arena_radius * SAFE_FRACTION
	var roam_radius: float = world.arena_radius * ROAM_FRACTION
	var dodge: Variant = _dodge_target(world, me, safe_radius) if difficulty.dodges else null
	if dodge != null:
		commands.append(SimWorld.move_command(mage_id, dodge))
	elif me.pos.length() > safe_radius:
		commands.append(SimWorld.move_command(mage_id, me.pos.limit_length(roam_radius)))
	elif me.move_target == null:
		var center: Vector2 = Vector2.ZERO if enemy.is_empty() else enemy.pos
		var distance := _rng.randf_range(ORBIT_DISTANCE.x, ORBIT_DISTANCE.y)
		var around := center + Vector2.RIGHT.rotated(_rng.randf() * TAU) * distance
		commands.append(SimWorld.move_command(mage_id, around.limit_length(roam_radius)))
	return commands


func _nearest_enemy(world: RefCounted, me: Dictionary) -> Dictionary:
	var best := {}
	var best_dist := INF
	for mage: Dictionary in world.mages:
		if mage.id == mage_id or not mage.alive:
			continue
		var dist: float = me.pos.distance_squared_to(mage.pos)
		if dist < best_dist:
			best = mage
			best_dist = dist
	return best


## Para onde fugir do projétil mais urgente que vai acertar o bot, ou null se não há perigo.
func _dodge_target(world: RefCounted, me: Dictionary, safe_radius: float) -> Variant:
	var soonest := INF
	var target: Variant = null
	for projectile: Dictionary in world.projectiles:
		if projectile.owner == mage_id:
			continue
		var spell: Dictionary = Spells.TABLE[projectile.spell]
		var reach: float = spell.radius + SimWorld.MAGE_RADIUS + DODGE_MARGIN
		var rel: Vector2 = me.pos - projectile.pos
		var along: float = rel.dot(projectile.dir)
		if along <= 0.0 or along > spell.range - projectile.traveled + reach:
			continue
		var lateral: Vector2 = rel - projectile.dir * along
		var time: float = along / spell.speed
		if lateral.length() > reach or time > DODGE_REACTION or time >= soonest:
			continue
		soonest = time
		# Sai pelo lado em que já está; bem na linha do tiro, escolhe um lado fixo.
		var side: Vector2 = lateral.normalized() if lateral.length() > 0.01 else projectile.dir.orthogonal()
		target = me.pos + side * DODGE_STEP
		if target.length() > safe_radius:
			target = me.pos - side * DODGE_STEP
	return target
