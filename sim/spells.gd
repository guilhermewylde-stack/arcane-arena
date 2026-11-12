extends RefCounted
## Tabela de magias: só dados. As regras que usam estes números moram em `sim_world.gd`.
## Tempos em segundos, distâncias em unidades do mundo, velocidades em unidades por segundo.

const EMBER := "ember"

const TABLE := {
	EMBER: {
		"name": "Brasa",
		"key": "Q",
		"cooldown": 1.2,
		"speed": 22.0,
		"range": 16.0,
		"radius": 0.4,
		"damage": 8.0,
		"knockback": 9.0,
		"color": Color("ff8a2a"),
	},
}
