extends RefCounted
## Escolhe a animação de um mago a partir do que a simulação conta. Lógica pura: não toca em nós.
## Prioridade: morto > atingido > lançando > correndo > parado.

const IDLE := "Idle"
const RUN := "Running_A"
const CAST := "Spellcast_Shoot"
const HIT := "Hit_A"
const DEATH := "Death_A"
## Quanto tempo (s) cada animação de reação segura o mago antes de voltar a andar/parar.
const CAST_TIME := 0.45
const HIT_TIME := 0.4

var _cast_left := 0.0
var _hit_left := 0.0


## Avisa de um evento da simulação cujo alvo é este mago ("cast", "hit"; os outros são ignorados).
func notify(event_type: String) -> void:
	match event_type:
		"cast":
			_cast_left = CAST_TIME
		"hit":
			_hit_left = HIT_TIME
			_cast_left = 0.0


## Avança o tempo e devolve o nome da animação que deve estar tocando.
func update(delta: float, alive: bool, moving: bool) -> String:
	if not alive:
		_cast_left = 0.0
		_hit_left = 0.0
		return DEATH
	_hit_left = maxf(0.0, _hit_left - delta)
	_cast_left = maxf(0.0, _cast_left - delta)
	if _hit_left > 0.0:
		return HIT
	if _cast_left > 0.0:
		return CAST
	return RUN if moving else IDLE
