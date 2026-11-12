extends RefCounted
## Tabela de magias: só dados. As regras que usam estes números moram em `sim_world.gd`,
## uma por comportamento (`behavior`):
## - "projectile": voa reto; ao acertar causa `damage` e empurra (`knockback`).
##   Opcionais: `pull` (em vez de empurrar, puxa o alvo para quem lançou, com essa velocidade)
##   e `turn_rate` (rad/s; o projétil faz curva na direção do inimigo mais próximo).
## - "teleport": leva o mago até o alvo, no máximo a `range` de distância.
## - "nova": fere e empurra quem estiver a até `radius` do lançador.
## - "shield": por `duration` segundos, reflete projéteis de volta.
## - "delayed_area": marca um ponto (até `range`); após `delay` fere e empurra quem estiver em `radius`.
## Tempos em segundos, distâncias em unidades do mundo, velocidades em unidades por segundo.

const EMBER := "ember"
const BLINK := "blink"
const GALE := "gale"
const CHAIN := "chain"
const AEGIS := "aegis"
const COMET := "comet"
const HOMING := "homing"

const TABLE := {
	EMBER: {
		"name": "Brasa", "behavior": "projectile", "cooldown": 1.2, "color": Color("ff8a2a"),
		"speed": 22.0, "range": 16.0, "radius": 0.4, "damage": 8.0, "knockback": 9.0,
	},
	BLINK: {
		"name": "Passo Etéreo", "behavior": "teleport", "cooldown": 6.0, "color": Color("b48cff"),
		"range": 7.0,
	},
	GALE: {
		"name": "Vendaval", "behavior": "nova", "cooldown": 7.0, "color": Color("9fe8ff"),
		"radius": 5.0, "damage": 5.0, "knockback": 13.0,
	},
	CHAIN: {
		"name": "Corrente", "behavior": "projectile", "cooldown": 8.0, "color": Color("c8ccd8"),
		"speed": 26.0, "range": 13.0, "radius": 0.35, "damage": 4.0, "knockback": 0.0, "pull": 15.0,
	},
	AEGIS: {
		"name": "Égide", "behavior": "shield", "cooldown": 9.0, "color": Color("ffe27a"),
		"duration": 1.5,
	},
	COMET: {
		"name": "Cometa", "behavior": "delayed_area", "cooldown": 9.0, "color": Color("ff5a3a"),
		"range": 12.0, "delay": 1.0, "radius": 3.0, "damage": 18.0, "knockback": 13.0,
	},
	HOMING: {
		"name": "Fagulha Teleguiada", "behavior": "projectile", "cooldown": 5.0, "color": Color("7dffb0"),
		"speed": 12.0, "range": 24.0, "radius": 0.35, "damage": 7.0, "knockback": 8.0, "turn_rate": 3.0,
	},
}


## Números da magia no nível dado (por enquanto todo nível vale o da tabela).
static func stats(spell_id: String, _level: int = 1) -> Dictionary:
	return TABLE[spell_id]
