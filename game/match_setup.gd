extends RefCounted
## Configuração da partida escolhida no menu (bots, dificuldade, rodadas), salva junto das
## opções em `user://settings.cfg`. Dados puros: o menu mostra, `main.gd` usa.

const Settings := preload("res://game/settings.gd")
const Bot := preload("res://sim/bot.gd")

const SECTION := "match"
const DEFAULTS := {"bots": 3, "difficulty": "normal", "rounds": 3}
## O limite de bots vem das cores de mago disponíveis (8, contando o jogador).
const MAX_BOTS := 7
const MAX_ROUNDS := 9
const DIFFICULTY_NAMES := {"easy": "Fácil", "normal": "Normal", "hard": "Difícil"}


static func sanitize(raw: Dictionary) -> Dictionary:
	var clean := DEFAULTS.duplicate()
	for key: String in DEFAULTS:
		if typeof(raw.get(key)) == typeof(DEFAULTS[key]):
			clean[key] = raw[key]
	clean.bots = clampi(clean.bots, 1, MAX_BOTS)
	clean.rounds = clampi(clean.rounds, 1, MAX_ROUNDS)
	if not Bot.DIFFICULTIES.has(clean.difficulty):
		clean.difficulty = DEFAULTS.difficulty
	return clean


## Cópia da configuração com um campo andado `step` casas: números somam (até o limite)
## e a dificuldade dá a volta na lista.
static func adjust(setup: Dictionary, key: String, step: int) -> Dictionary:
	var out := sanitize(setup)
	if key == "difficulty":
		var names: Array = Bot.DIFFICULTIES.keys()
		out.difficulty = names[posmod(names.find(out.difficulty) + step, names.size())]
	else:
		out[key] += step
	return sanitize(out)


## Config do `SimWorld` para esta partida (o jogador é sempre o mago 0).
static func world_config(setup: Dictionary) -> Dictionary:
	var clean := sanitize(setup)
	return {"mage_count": clean.bots + 1, "rounds_to_win": clean.rounds}


static func load_from(path: String = Settings.PATH) -> Dictionary:
	return sanitize(Settings.read_section(path, SECTION, DEFAULTS.keys()))


static func save_to(path: String, setup: Dictionary) -> void:
	Settings.write_section(path, SECTION, sanitize(setup))
