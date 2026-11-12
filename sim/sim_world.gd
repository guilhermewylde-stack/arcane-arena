extends RefCounted
## Simulação pura e determinística. Não conhece nós, cena, entrada nem relógio real.
## O chão é 2D: Vector2(x, y) corresponde a (x, z) no mundo 3D; altura é só visual.
## Interface: `SimWorld.new(config)` e `step(commands)`.

const Spells := preload("res://sim/spells.gd")

const TICK_RATE := 30
const DT := 1.0 / TICK_RATE
const MAGE_SPEED := 7.0
const DEFAULT_ARENA_RADIUS := 18.0
const MAX_HP := 100.0
## Dano por segundo para quem está fora do raio da arena.
const LAVA_DPS := 25.0
const MAGE_RADIUS := 0.6
## Desaceleração (unidades/s²) da velocidade de empurrão.
const KNOCKBACK_FRICTION := 14.0
## Com a vida no zero o empurrão é multiplicado por 1 + este valor.
const KNOCKBACK_DAMAGE_SCALING := 1.5

## Fases da partida. Sem `rounds_to_win` na config o mundo é livre: fica sempre em
## PHASE_ROUND, a arena não encolhe e ninguém vence (útil para testes e treino).
const PHASE_COUNTDOWN := "countdown"
const PHASE_ROUND := "round"
const PHASE_ROUND_END := "round_end"
const PHASE_MATCH_END := "match_end"
const COUNTDOWN_SECONDS := 3.0
const ROUND_END_SECONDS := 3.0
const DEFAULT_SHRINK_DELAY := 10.0
const DEFAULT_SHRINK_RATE := 0.5
const DEFAULT_MIN_ARENA_RADIUS := 4.0

var tick := 0
var arena_radius := DEFAULT_ARENA_RADIUS
## Cada mago: { id: int, pos: Vector2, facing: float, move_target: Variant (Vector2 ou null),
## hp: float, alive: bool, vel: Vector2 (velocidade de empurrão),
## cooldowns: { id da magia: tick em que volta a ficar pronta } }.
## `facing` é o ângulo em torno de Y; 0 aponta para +z.
## Mago morto fica na lista, mas não age nem se move.
var mages: Array[Dictionary] = []
## Cada projétil: { id: int, spell: String, owner: int, pos: Vector2, dir: Vector2, traveled: float }.
var projectiles: Array[Dictionary] = []
## O que aconteceu no último `step`, para o render: { type: "hit", pos, dir, spell, target }
## ou { type: "fizzle", pos, spell } (projétil acabou sem acertar ninguém).
var events: Array[Dictionary] = []


var phase := PHASE_ROUND
var round_number := 1
## Rodadas vencidas por cada mago (índice = id).
var scores: Array[int] = []
## Vencedor da última rodada encerrada (-1: empate ou ainda não houve).
var round_winner := -1
## Vencedor da partida (-1 enquanto ela não acaba).
var match_winner := -1
var initial_arena_radius := DEFAULT_ARENA_RADIUS
## Rodadas necessárias para vencer a partida; 0 = mundo livre, sem regras de partida.
var rounds_to_win := 0

var _next_projectile_id := 0
var _mage_count := 1
var _phase_ticks := 0
var _round_ticks := 0
var _shrink_delay := DEFAULT_SHRINK_DELAY
var _shrink_rate := DEFAULT_SHRINK_RATE
var _min_arena_radius := DEFAULT_MIN_ARENA_RADIUS


## Config (tudo opcional): mage_count, arena_radius, rounds_to_win,
## shrink_delay (s), shrink_rate (unidades/s), min_arena_radius.
func _init(config: Dictionary = {}) -> void:
	initial_arena_radius = config.get("arena_radius", DEFAULT_ARENA_RADIUS)
	_mage_count = config.get("mage_count", 1)
	rounds_to_win = config.get("rounds_to_win", 0)
	_shrink_delay = config.get("shrink_delay", DEFAULT_SHRINK_DELAY)
	_shrink_rate = config.get("shrink_rate", DEFAULT_SHRINK_RATE)
	_min_arena_radius = config.get("min_arena_radius", DEFAULT_MIN_ARENA_RADIUS)
	for i in _mage_count:
		scores.append(0)
	_reset_round()
	if rounds_to_win > 0:
		_enter(PHASE_COUNTDOWN, COUNTDOWN_SECONDS)


static func move_command(mage_id: int, target: Vector2) -> Dictionary:
	return {"type": "move", "mage_id": mage_id, "target": target}


static func cast_command(mage_id: int, spell_id: String, target: Vector2) -> Dictionary:
	return {"type": "cast", "mage_id": mage_id, "spell": spell_id, "target": target}


## Avança o mundo exatamente um tick, aplicando antes os comandos recebidos.
func step(commands: Array = []) -> void:
	events.clear()
	tick += 1
	if phase == PHASE_MATCH_END:
		return
	if phase == PHASE_COUNTDOWN:
		# Na contagem ninguém age; os comandos recebidos são descartados.
		_phase_ticks -= 1
		if _phase_ticks <= 0:
			phase = PHASE_ROUND
		return

	for cmd: Dictionary in commands:
		var mage := get_mage(cmd.mage_id)
		if mage.is_empty() or not mage.alive:
			continue
		match cmd.type:
			"move":
				mage.move_target = cmd.target
			"cast":
				_cast(mage, cmd.spell, cmd.target)
	for mage in mages:
		if mage.alive:
			_move_mage(mage)
			_apply_knockback(mage)
	_step_projectiles()

	if phase == PHASE_ROUND:
		for mage in mages:
			if mage.alive and is_in_lava(mage.pos):
				_damage(mage, LAVA_DPS * DT)
		if rounds_to_win > 0:
			_shrink_arena()
			_check_round_over()
	else:
		# Fim de rodada: o mundo segue andando, mas ninguém mais leva dano.
		_phase_ticks -= 1
		if _phase_ticks <= 0:
			_finish_round_end()


## Segundos que faltam para a fase atual acabar (0 nas fases sem prazo).
func phase_seconds_left() -> float:
	if phase == PHASE_COUNTDOWN or phase == PHASE_ROUND_END:
		return _phase_ticks * DT
	return 0.0


func get_mage(id: int) -> Dictionary:
	for mage in mages:
		if mage.id == id:
			return mage
	return {}


func is_in_lava(pos: Vector2) -> bool:
	return pos.length() > arena_radius


## Quanto falta da recarga: 1 logo após lançar, 0 quando a magia está pronta.
func cooldown_fraction(mage_id: int, spell_id: String) -> float:
	var mage := get_mage(mage_id)
	if mage.is_empty() or not Spells.TABLE.has(spell_id):
		return 0.0
	var remaining: int = mage.cooldowns.get(spell_id, 0) - tick
	return clampf(float(remaining) / _cooldown_ticks(spell_id), 0.0, 1.0)


## Cópia das posições, usada pelo render para interpolar entre dois ticks:
## { mages: { id: Vector2 }, projectiles: { id: Vector2 } }.
func snapshot_positions() -> Dictionary:
	var out := {"mages": {}, "projectiles": {}}
	for mage in mages:
		out.mages[mage.id] = mage.pos
	for projectile in projectiles:
		out.projectiles[projectile.id] = projectile.pos
	return out


func _enter(new_phase: String, seconds: float) -> void:
	phase = new_phase
	_phase_ticks = roundi(seconds * TICK_RATE)


## Deixa tudo como no começo de uma rodada: magos no anel inicial, arena inteira.
func _reset_round() -> void:
	arena_radius = initial_arena_radius
	_round_ticks = 0
	projectiles.clear()
	mages.clear()
	for i in _mage_count:
		# Magos nascem distribuídos num anel; um mago sozinho nasce no centro.
		var angle := float(i) / _mage_count * TAU
		var r := 0.0 if _mage_count == 1 else arena_radius * 0.6
		mages.append({
			"id": i,
			"pos": Vector2(sin(angle), cos(angle)) * r,
			"facing": angle + PI,
			"move_target": null,
			"hp": MAX_HP,
			"alive": true,
			"vel": Vector2.ZERO,
			"cooldowns": {},
		})


func _shrink_arena() -> void:
	_round_ticks += 1
	if _round_ticks > roundi(_shrink_delay * TICK_RATE):
		arena_radius = maxf(_min_arena_radius, arena_radius - _shrink_rate * DT)


func _check_round_over() -> void:
	var alive := mages.filter(func(mage: Dictionary) -> bool: return mage.alive)
	if alive.size() > 1:
		return
	round_winner = alive[0].id if alive.size() == 1 else -1
	if round_winner >= 0:
		scores[round_winner] += 1
	_enter(PHASE_ROUND_END, ROUND_END_SECONDS)


func _finish_round_end() -> void:
	if round_winner >= 0 and scores[round_winner] >= rounds_to_win:
		match_winner = round_winner
		phase = PHASE_MATCH_END
		return
	round_number += 1
	_reset_round()
	_enter(PHASE_COUNTDOWN, COUNTDOWN_SECONDS)


func _cooldown_ticks(spell_id: String) -> int:
	return maxi(1, roundi(Spells.TABLE[spell_id].cooldown * TICK_RATE))


func _cast(mage: Dictionary, spell_id: String, target: Vector2) -> void:
	if not Spells.TABLE.has(spell_id) or mage.cooldowns.get(spell_id, 0) > tick:
		return
	mage.cooldowns[spell_id] = tick + _cooldown_ticks(spell_id)
	var to_target: Vector2 = target - mage.pos
	if to_target.length() > 0.001:
		mage.facing = atan2(to_target.x, to_target.y)
	projectiles.append({
		"id": _next_projectile_id,
		"spell": spell_id,
		"owner": mage.id,
		"pos": mage.pos,
		"dir": Vector2(sin(mage.facing), cos(mage.facing)),
		"traveled": 0.0,
	})
	_next_projectile_id += 1


func _step_projectiles() -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		var spell: Dictionary = Spells.TABLE[projectile.spell]
		var from: Vector2 = projectile.pos
		var advance: float = minf(spell.speed * DT, spell.range - projectile.traveled)
		var to: Vector2 = from + projectile.dir * advance
		var victim := _first_mage_hit(projectile, from, to, spell.radius + MAGE_RADIUS)
		if not victim.is_empty():
			_hit(victim, projectile, spell)
			continue
		projectile.pos = to
		projectile.traveled += advance
		if projectile.traveled >= spell.range - 0.0001:
			events.append({"type": "fizzle", "pos": to, "spell": projectile.spell})
		else:
			survivors.append(projectile)
	projectiles = survivors


## O mago vivo (que não o dono) mais perto do início do trecho percorrido neste tick.
func _first_mage_hit(projectile: Dictionary, from: Vector2, to: Vector2, reach: float) -> Dictionary:
	var best := {}
	var best_dist := INF
	for mage in mages:
		if not mage.alive or mage.id == projectile.owner:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(mage.pos, from, to)
		if closest.distance_to(mage.pos) > reach:
			continue
		var dist := from.distance_squared_to(mage.pos)
		if dist < best_dist:
			best = mage
			best_dist = dist
	return best


func _hit(victim: Dictionary, projectile: Dictionary, spell: Dictionary) -> void:
	_damage(victim, spell.damage)
	# O empurrão cresce com o dano acumulado: quanto menos vida, mais longe voa.
	var missing: float = 1.0 - victim.hp / MAX_HP
	victim.vel += projectile.dir * spell.knockback * (1.0 + missing * KNOCKBACK_DAMAGE_SCALING)
	victim.move_target = null
	events.append({
		"type": "hit", "pos": victim.pos, "dir": projectile.dir,
		"spell": projectile.spell, "target": victim.id,
	})


func _apply_knockback(mage: Dictionary) -> void:
	if mage.vel == Vector2.ZERO:
		return
	mage.pos += mage.vel * DT
	mage.vel = mage.vel.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * DT)


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
		mage.vel = Vector2.ZERO
