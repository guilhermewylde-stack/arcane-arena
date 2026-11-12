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
const TARGET_TIE_MARGIN := 1.0
## O bot só puxa com Corrente se estiver ao menos isto mais longe do centro que o inimigo.
const PULL_ADVANTAGE := 2.0
## Lança a magia em volta de si quando o inimigo está dentro desta fração do raio dela.
const NOVA_RANGE_FRACTION := 0.8

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

	var threat := _incoming(world, me)
	for spell_id: String in me.spells:
		if world.cooldown_fraction(mage_id, spell_id) > 0.0:
			continue
		var target: Variant = _spell_target(world, me, enemy, threat, Spells.stats(spell_id, me.spells[spell_id]))
		if target != null:
			commands.append(SimWorld.cast_command(mage_id, spell_id, target))

	var safe_radius: float = world.arena_radius * SAFE_FRACTION
	var roam_radius: float = world.arena_radius * ROAM_FRACTION
	var dodge: Variant = null
	if difficulty.dodges and not threat.is_empty():
		dodge = me.pos + threat.side * DODGE_STEP
		if dodge.length() > safe_radius:
			dodge = me.pos - threat.side * DODGE_STEP
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


## O inimigo vivo mais próximo. Entre os quase empatados (diferença menor que
## TARGET_TIE_MARGIN) sorteia, para os bots não perseguirem sempre o de menor id.
func _nearest_enemy(world: RefCounted, me: Dictionary) -> Dictionary:
	var enemies: Array = world.mages.filter(
		func(mage: Dictionary) -> bool: return mage.id != mage_id and mage.alive)
	if enemies.is_empty():
		return {}
	var nearest := INF
	for mage: Dictionary in enemies:
		nearest = minf(nearest, me.pos.distance_to(mage.pos))
	var tied := enemies.filter(
		func(mage: Dictionary) -> bool: return me.pos.distance_to(mage.pos) <= nearest + TARGET_TIE_MARGIN)
	return tied[0] if tied.size() == 1 else tied[_rng.randi() % tied.size()]


## Onde lançar a magia agora, ou null se não vale a pena. Uma regra por comportamento.
func _spell_target(world: RefCounted, me: Dictionary, enemy: Dictionary, threat: Dictionary, spell: Dictionary) -> Variant:
	var to_enemy: Vector2 = Vector2.ZERO if enemy.is_empty() else enemy.pos - me.pos
	match spell.behavior:
		"projectile":
			if enemy.is_empty() or to_enemy.length() > spell.range * CAST_RANGE_FRACTION:
				return null
			# Puxão só compensa se arrasta o inimigo para fora, na direção da lava.
			if spell.has("pull") and me.pos.length() < enemy.pos.length() + PULL_ADVANTAGE:
				return null
			return me.pos + to_enemy.rotated(_aim_error())
		"delayed_area":
			if enemy.is_empty() or to_enemy.length() > spell.range:
				return null
			return me.pos + to_enemy.rotated(_aim_error())
		"teleport":
			return Vector2.ZERO if world.is_in_lava(me.pos) else null
		"nova":
			if enemy.is_empty() or to_enemy.length() > spell.radius * NOVA_RANGE_FRACTION:
				return null
			return me.pos
		"shield":
			return null if threat.is_empty() else me.pos
	return null


func _aim_error() -> float:
	return _rng.randf_range(-difficulty.aim_error, difficulty.aim_error)


## O projétil mais urgente que vai acertar o bot: { time: float, side: Vector2 (para onde
## sair da frente) }, ou {} se não há perigo.
func _incoming(world: RefCounted, me: Dictionary) -> Dictionary:
	var threat := {}
	for projectile: Dictionary in world.projectiles:
		if projectile.owner == mage_id:
			continue
		var spell: Dictionary = Spells.stats(projectile.spell, projectile.level)
		var reach: float = spell.radius + SimWorld.MAGE_RADIUS + DODGE_MARGIN
		var rel: Vector2 = me.pos - projectile.pos
		var along: float = rel.dot(projectile.dir)
		if along <= 0.0 or along > spell.range - projectile.traveled + reach:
			continue
		var lateral: Vector2 = rel - projectile.dir * along
		var time: float = along / spell.speed
		if lateral.length() > reach or time > DODGE_REACTION or time >= threat.get("time", INF):
			continue
		# Sai pelo lado em que já está; bem na linha do tiro, escolhe um lado fixo.
		var side: Vector2 = lateral.normalized() if lateral.length() > 0.01 else projectile.dir.orthogonal()
		threat = {"time": time, "side": side}
	return threat
