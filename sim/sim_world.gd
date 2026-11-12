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
## Loja entre rodadas: ninguém age; valem só os comandos `buy` e `ready`.
const PHASE_SHOP := "shop"
const DEFAULT_SHOP_SECONDS := 20.0
const MAX_SPELL_SLOTS := 6
## Ouro: por ponto de dano causado em outro mago, por abate (último a acertar quem morreu),
## por vencer a rodada e, para todos, por rodada jogada.
const GOLD_PER_DAMAGE := 1.0
const GOLD_PER_KILL := 20.0
const GOLD_ROUND_WIN := 30.0
const GOLD_PER_ROUND := 15.0
const COUNTDOWN_SECONDS := 3.0
const ROUND_END_SECONDS := 3.0
const DEFAULT_SHRINK_DELAY := 10.0
const DEFAULT_SHRINK_RATE := 0.5
const DEFAULT_MIN_ARENA_RADIUS := 4.0

var tick := 0
var arena_radius := DEFAULT_ARENA_RADIUS
## Cada mago: { id: int, pos: Vector2, facing: float, move_target: Variant (Vector2 ou null),
## move_dir: Vector2 (direção conduzida por WASD, unitária ou zero),
## hp: float, alive: bool, vel: Vector2 (velocidade de empurrão),
## cooldowns: { id da magia: tick em que volta a ficar pronta },
## spells: { id da magia: nível } na ordem da barra, shield_until: tick em que o escudo acaba,
## last_hit_by: id de quem acertou por último nesta rodada (-1: ninguém) }.
## `facing` é o ângulo em torno de Y; 0 aponta para +z.
## Mago morto fica na lista, mas não age nem se move.
var mages: Array[Dictionary] = []
## Cada projétil: { id, spell, level, owner, pos: Vector2, dir: Vector2, traveled: float }.
var projectiles: Array[Dictionary] = []
## Áreas marcadas que vão explodir: { id, spell, level, owner, pos: Vector2, ticks_left: int }.
var hazards: Array[Dictionary] = []
## O que aconteceu no último `step`, para o render. Todo evento tem `type`, `spell` e `pos`:
## "hit" (+ dir, target), "fizzle", "reflect", "blink" (+ from), "nova" (+ radius),
## "explosion" (+ radius), "shield" (+ target).
var events: Array[Dictionary] = []


var phase := PHASE_ROUND
var round_number := 1
## Rodadas vencidas por cada mago (índice = id).
var scores: Array[int] = []
## Ouro de cada mago (índice = id); acumula pela partida inteira.
var gold: Array[float] = []
## Na loja: quem já avisou que terminou as compras (índice = id).
var shop_ready: Array[bool] = []
## Vencedor da última rodada encerrada (-1: empate ou ainda não houve).
var round_winner := -1
## Vencedor da partida (-1 enquanto ela não acaba).
var match_winner := -1
var initial_arena_radius := DEFAULT_ARENA_RADIUS
## Rodadas necessárias para vencer a partida; 0 = mundo livre, sem regras de partida.
var rounds_to_win := 0

var _next_projectile_id := 0
var _next_hazard_id := 0
var _mage_count := 1
## Magias de cada mago (índice = id); sobrevivem à troca de rodada.
var _loadouts: Array[Dictionary] = []
var _phase_ticks := 0
var _round_ticks := 0
var _shrink_delay := DEFAULT_SHRINK_DELAY
var _shrink_rate := DEFAULT_SHRINK_RATE
var _min_arena_radius := DEFAULT_MIN_ARENA_RADIUS
var _shop_seconds := DEFAULT_SHOP_SECONDS


## Config (tudo opcional): mage_count, arena_radius, rounds_to_win,
## shrink_delay (s), shrink_rate (unidades/s), min_arena_radius,
## loadout (ids das magias com que todo mago começa; padrão: só Brasa),
## shop_seconds (duração da loja entre rodadas; 0 = sem loja).
func _init(config: Dictionary = {}) -> void:
	initial_arena_radius = config.get("arena_radius", DEFAULT_ARENA_RADIUS)
	_mage_count = config.get("mage_count", 1)
	rounds_to_win = config.get("rounds_to_win", 0)
	_shrink_delay = config.get("shrink_delay", DEFAULT_SHRINK_DELAY)
	_shrink_rate = config.get("shrink_rate", DEFAULT_SHRINK_RATE)
	_min_arena_radius = config.get("min_arena_radius", DEFAULT_MIN_ARENA_RADIUS)
	_shop_seconds = config.get("shop_seconds", DEFAULT_SHOP_SECONDS)
	for i in _mage_count:
		scores.append(0)
		gold.append(0.0)
		shop_ready.append(false)
		var spells := {}
		for spell_id: String in config.get("loadout", [Spells.EMBER]):
			spells[spell_id] = 1
		_loadouts.append(spells)
	_reset_round()
	if rounds_to_win > 0:
		_enter(PHASE_COUNTDOWN, COUNTDOWN_SECONDS)


static func move_command(mage_id: int, target: Vector2) -> Dictionary:
	return {"type": "move", "mage_id": mage_id, "target": target}


## Conduz o mago numa direção (WASD) até chegar outro comando; direção zero o faz parar.
## Conduzir e andar até um ponto (`move_command`) se cancelam: vale o último.
static func steer_command(mage_id: int, direction: Vector2) -> Dictionary:
	return {"type": "steer", "mage_id": mage_id, "dir": direction}


## Compra a magia ou, se o mago já a tem, sobe um nível. Só vale na loja.
static func buy_command(mage_id: int, spell_id: String) -> Dictionary:
	return {"type": "buy", "mage_id": mage_id, "spell": spell_id}


## Avisa que o mago terminou as compras; a loja fecha quando todos avisam.
static func ready_command(mage_id: int) -> Dictionary:
	return {"type": "ready", "mage_id": mage_id}


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
	if phase == PHASE_SHOP:
		_step_shop(commands)
		return

	for cmd: Dictionary in commands:
		var mage := get_mage(cmd.mage_id)
		if mage.is_empty() or not mage.alive:
			continue
		match cmd.type:
			"move":
				mage.move_target = cmd.target
				mage.move_dir = Vector2.ZERO
			"steer":
				mage.move_dir = cmd.dir.normalized()
				if mage.move_dir != Vector2.ZERO:
					mage.move_target = null
			"cast":
				_cast(mage, cmd.spell, cmd.target)
	for mage in mages:
		if mage.alive:
			_move_mage(mage)
			_apply_knockback(mage)
	_step_projectiles()
	_step_hazards()

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
	if phase == PHASE_COUNTDOWN or phase == PHASE_ROUND_END or phase == PHASE_SHOP:
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
	if mage.is_empty() or not mage.spells.has(spell_id):
		return 0.0
	var remaining: int = mage.cooldowns.get(spell_id, 0) - tick
	return clampf(float(remaining) / _ticks(_stats(mage, spell_id).cooldown), 0.0, 1.0)


## Quanto o mago paga agora por essa magia: compra, melhoria, ou -1 se não há o que comprar
## (magia desconhecida, nível máximo ou barra cheia).
func price(mage_id: int, spell_id: String) -> int:
	var mage := get_mage(mage_id)
	if mage.is_empty() or not Spells.TABLE.has(spell_id):
		return -1
	if mage.spells.has(spell_id):
		return Spells.TABLE[spell_id].upgrade_cost if mage.spells[spell_id] < Spells.MAX_LEVEL else -1
	return Spells.TABLE[spell_id].cost if mage.spells.size() < MAX_SPELL_SLOTS else -1


func can_buy(mage_id: int, spell_id: String) -> bool:
	var cost := price(mage_id, spell_id)
	return phase == PHASE_SHOP and cost >= 0 and gold[mage_id] >= cost


func is_shielded(mage_id: int) -> bool:
	var mage := get_mage(mage_id)
	return not mage.is_empty() and mage.alive and mage.shield_until > tick


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
	hazards.clear()
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
			"move_dir": Vector2.ZERO,
			"hp": MAX_HP,
			"alive": true,
			"vel": Vector2.ZERO,
			"cooldowns": {},
			"spells": _loadouts[i],
			"shield_until": 0,
			"last_hit_by": -1,
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
	for i in _mage_count:
		gold[i] += GOLD_PER_ROUND
	if round_winner >= 0:
		scores[round_winner] += 1
		gold[round_winner] += GOLD_ROUND_WIN
	_enter(PHASE_ROUND_END, ROUND_END_SECONDS)


func _finish_round_end() -> void:
	if round_winner >= 0 and scores[round_winner] >= rounds_to_win:
		match_winner = round_winner
		phase = PHASE_MATCH_END
		return
	round_number += 1
	_reset_round()
	if _shop_seconds > 0.0:
		shop_ready.fill(false)
		_enter(PHASE_SHOP, _shop_seconds)
	else:
		_enter(PHASE_COUNTDOWN, COUNTDOWN_SECONDS)


func _step_shop(commands: Array) -> void:
	for cmd: Dictionary in commands:
		if get_mage(cmd.mage_id).is_empty():
			continue
		match cmd.type:
			"buy":
				if can_buy(cmd.mage_id, cmd.spell):
					gold[cmd.mage_id] -= price(cmd.mage_id, cmd.spell)
					var spells: Dictionary = _loadouts[cmd.mage_id]
					spells[cmd.spell] = spells.get(cmd.spell, 0) + 1
			"ready":
				shop_ready[cmd.mage_id] = true
	_phase_ticks -= 1
	if _phase_ticks <= 0 or not shop_ready.has(false):
		_enter(PHASE_COUNTDOWN, COUNTDOWN_SECONDS)


func _ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * TICK_RATE))


func _stats(mage: Dictionary, spell_id: String) -> Dictionary:
	return Spells.stats(spell_id, mage.spells[spell_id])


func _cast(mage: Dictionary, spell_id: String, target: Vector2) -> void:
	if not mage.spells.has(spell_id) or mage.cooldowns.get(spell_id, 0) > tick:
		return
	var spell := _stats(mage, spell_id)
	mage.cooldowns[spell_id] = tick + _ticks(spell.cooldown)
	var to_target: Vector2 = target - mage.pos
	if to_target.length() > 0.001 and spell.behavior != "nova" and spell.behavior != "shield":
		mage.facing = atan2(to_target.x, to_target.y)
	var event := {"spell": spell_id, "pos": mage.pos, "target": mage.id}
	match spell.behavior:
		"projectile":
			projectiles.append({
				"id": _next_projectile_id,
				"spell": spell_id,
				"level": mage.spells[spell_id],
				"owner": mage.id,
				"pos": mage.pos,
				"dir": Vector2(sin(mage.facing), cos(mage.facing)),
				"traveled": 0.0,
			})
			_next_projectile_id += 1
		"teleport":
			event.merge({"type": "blink", "from": mage.pos})
			mage.pos += to_target.limit_length(spell.range)
			mage.move_target = null
			event.pos = mage.pos
			events.append(event)
		"nova":
			_blast(mage.pos, spell, mage.id, mage.id)
			events.append(event.merged({"type": "nova", "radius": spell.radius}))
		"shield":
			mage.shield_until = tick + _ticks(spell.duration)
			events.append(event.merged({"type": "shield"}))
		"delayed_area":
			hazards.append({
				"id": _next_hazard_id,
				"spell": spell_id,
				"level": mage.spells[spell_id],
				"owner": mage.id,
				"pos": mage.pos + to_target.limit_length(spell.range),
				"ticks_left": _ticks(spell.delay),
			})
			_next_hazard_id += 1


func _step_projectiles() -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		var spell: Dictionary = Spells.stats(projectile.spell, projectile.level)
		if spell.has("turn_rate"):
			_steer(projectile, spell.turn_rate * DT)
		var from: Vector2 = projectile.pos
		var advance: float = minf(spell.speed * DT, spell.range - projectile.traveled)
		var to: Vector2 = from + projectile.dir * advance
		var victim := _first_mage_hit(projectile, from, to, spell.radius + MAGE_RADIUS)
		if not victim.is_empty():
			if victim.shield_until > tick:
				_reflect(projectile, victim)
				survivors.append(projectile)
			else:
				_hit(victim, projectile, spell)
			continue
		projectile.pos = to
		projectile.traveled += advance
		if projectile.traveled >= spell.range - 0.0001:
			events.append({"type": "fizzle", "pos": to, "spell": projectile.spell})
		else:
			survivors.append(projectile)
	projectiles = survivors


## Vira o projétil, no máximo `max_turn` radianos, na direção do inimigo vivo mais próximo.
func _steer(projectile: Dictionary, max_turn: float) -> void:
	var nearest := {}
	var best := INF
	for mage in mages:
		if not mage.alive or mage.id == projectile.owner:
			continue
		var dist: float = projectile.pos.distance_squared_to(mage.pos)
		if dist < best:
			nearest = mage
			best = dist
	if nearest.is_empty() or best < 0.0001:
		return
	var wanted: float = projectile.dir.angle_to(nearest.pos - projectile.pos)
	projectile.dir = projectile.dir.rotated(clampf(wanted, -max_turn, max_turn))


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
	_damage(victim, spell.damage, projectile.owner)
	var owner := get_mage(projectile.owner)
	if spell.has("pull") and not owner.is_empty():
		# Puxão: velocidade fixa na direção de quem lançou, substituindo o empurrão atual.
		victim.vel = victim.pos.direction_to(owner.pos) * spell.pull
		victim.move_target = null
	else:
		_push(victim, projectile.dir, spell.knockback)
	events.append({
		"type": "hit", "pos": victim.pos, "dir": projectile.dir,
		"spell": projectile.spell, "target": victim.id,
	})


## O escudo devolve o projétil: ele passa a ser de quem refletiu e volta para quem lançou.
func _reflect(projectile: Dictionary, shielded: Dictionary) -> void:
	var owner := get_mage(projectile.owner)
	projectile.dir = -projectile.dir if owner.is_empty() or owner.pos == shielded.pos \
		else shielded.pos.direction_to(owner.pos)
	projectile.owner = shielded.id
	projectile.pos = shielded.pos
	projectile.traveled = 0.0
	events.append({"type": "reflect", "pos": shielded.pos, "spell": projectile.spell})


## Empurrão que cresce com o dano acumulado: quanto menos vida, mais longe voa.
func _push(victim: Dictionary, dir: Vector2, knockback: float) -> void:
	if not victim.alive:
		return
	var missing: float = 1.0 - victim.hp / MAX_HP
	victim.vel += dir * knockback * (1.0 + missing * KNOCKBACK_DAMAGE_SCALING)
	victim.move_target = null


## Explosão em área: fere e empurra para longe do centro todo mago vivo no raio,
## menos `immune_id` (quem lançou um Vendaval; -1 = ninguém escapa).
func _blast(center: Vector2, spell: Dictionary, source_id: int, immune_id: int) -> void:
	for mage in mages:
		if not mage.alive or mage.id == immune_id:
			continue
		if mage.pos.distance_to(center) > spell.radius + MAGE_RADIUS:
			continue
		_damage(mage, spell.damage, source_id)
		var away: Vector2 = center.direction_to(mage.pos)
		_push(mage, away if away != Vector2.ZERO else Vector2.RIGHT, spell.knockback)


func _step_hazards() -> void:
	var pending: Array[Dictionary] = []
	for hazard in hazards:
		hazard.ticks_left -= 1
		if hazard.ticks_left > 0:
			pending.append(hazard)
			continue
		var spell: Dictionary = Spells.stats(hazard.spell, hazard.level)
		_blast(hazard.pos, spell, hazard.owner, -1)
		events.append({"type": "explosion", "pos": hazard.pos, "spell": hazard.spell, "radius": spell.radius})
	hazards = pending


func _apply_knockback(mage: Dictionary) -> void:
	if mage.vel == Vector2.ZERO:
		return
	mage.pos += mage.vel * DT
	mage.vel = mage.vel.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * DT)


func _move_mage(mage: Dictionary) -> void:
	if mage.move_dir != Vector2.ZERO:
		mage.facing = atan2(mage.move_dir.x, mage.move_dir.y)
		mage.pos += mage.move_dir * MAGE_SPEED * DT
		return
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


## Tira vida. `source_id` é o mago que causou o dano (-1: a lava); ele ganha ouro pelo
## dano em outros magos e fica marcado como o último a acertar, para levar o abate.
func _damage(mage: Dictionary, amount: float, source_id := -1) -> void:
	var dealt: float = minf(amount, mage.hp)
	mage.hp -= dealt
	if source_id >= 0 and source_id != mage.id:
		gold[source_id] += dealt * GOLD_PER_DAMAGE
		mage.last_hit_by = source_id
	if mage.hp <= 0.0:
		mage.hp = 0.0
		mage.alive = false
		mage.move_target = null
		mage.vel = Vector2.ZERO
		if mage.last_hit_by >= 0:
			gold[mage.last_hit_by] += GOLD_PER_KILL
