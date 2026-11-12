extends RefCounted
## Teclas de jogo configuráveis, salvas em `user://settings.cfg` (seção `keys`). Dados puros.
## Um mapa é { ação: keycode }. Ações `slot_N` lançam a magia do espaço N na visão de cima;
## ações `move_*` andam em 3ª pessoa. São grupos separados: a mesma tecla pode estar nos dois.
## Os números 1–6 (escolher magia em 3ª pessoa e comprar na loja) são fixos.

const Settings := preload("res://game/settings.gd")

const SECTION := "keys"
const DEFAULTS := {
	"slot_1": KEY_Q, "slot_2": KEY_W, "slot_3": KEY_E, "slot_4": KEY_R, "slot_5": KEY_D, "slot_6": KEY_F,
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
}
## Nome de cada ação no menu, na ordem em que aparecem.
const LABELS := {
	"slot_1": "Magia 1", "slot_2": "Magia 2", "slot_3": "Magia 3",
	"slot_4": "Magia 4", "slot_5": "Magia 5", "slot_6": "Magia 6",
	"move_forward": "Andar para a frente", "move_back": "Andar para trás",
	"move_left": "Andar para a esquerda", "move_right": "Andar para a direita",
}
const SLOT_COUNT := 6
## Teclas com função fixa no jogo.
const RESERVED: Array[Key] = [
	KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_F5, KEY_F11,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7,
]
const KEY_NAMES := {KEY_SPACE: "Espaço", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}


static func is_bindable(keycode: int) -> bool:
	return keycode != KEY_NONE and not RESERVED.has(keycode)


## Grupo da ação: teclas só brigam dentro do mesmo grupo.
static func group_of(action: String) -> String:
	return action.get_slice("_", 0)


## Mapa válido: só ações conhecidas; tecla de tipo errado, reservada ou repetida no grupo
## volta ao padrão.
static func sanitize(raw: Dictionary) -> Dictionary:
	var clean := {}
	for action: String in DEFAULTS:
		var key: Variant = raw.get(action)
		var valid: bool = typeof(key) == TYPE_INT and is_bindable(key)
		if valid:
			for other: String in clean:
				valid = valid and not (group_of(other) == group_of(action) and clean[other] == key)
		clean[action] = key if valid else DEFAULTS[action]
	return clean


## Cópia do mapa com `action` na tecla `keycode`. Se outra ação do mesmo grupo já usava a
## tecla, as duas trocam. Tecla reservada não muda nada.
static func rebind(map: Dictionary, action: String, keycode: int) -> Dictionary:
	var out := map.duplicate()
	if not DEFAULTS.has(action) or not is_bindable(keycode):
		return out
	for other: String in out:
		if other != action and group_of(other) == group_of(action) and out[other] == keycode:
			out[other] = out[action]
	out[action] = keycode
	return out


static func slot_key(map: Dictionary, slot: int) -> int:
	return map["slot_%d" % (slot + 1)]


## Espaço da barra que a tecla lança, ou -1.
static func slot_of(map: Dictionary, keycode: int) -> int:
	for slot in SLOT_COUNT:
		if slot_key(map, slot) == keycode:
			return slot
	return -1


## Teclas de movimento apertadas agora (x = direita da tela, y = para a frente).
## `is_pressed` recebe um keycode e diz se a tecla está apertada.
static func move_input(map: Dictionary, is_pressed: Callable) -> Vector2:
	return Vector2(
		float(is_pressed.call(map.move_right)) - float(is_pressed.call(map.move_left)),
		float(is_pressed.call(map.move_forward)) - float(is_pressed.call(map.move_back)))


## Nome curto da tecla, para a barra de magias, o menu e a ajuda.
static func key_label(keycode: int) -> String:
	return KEY_NAMES.get(keycode, OS.get_keycode_string(keycode))


static func load_from(path: String = Settings.PATH) -> Dictionary:
	return sanitize(Settings.read_section(path, SECTION, DEFAULTS.keys()))


static func save_to(path: String, map: Dictionary) -> void:
	Settings.write_section(path, SECTION, sanitize(map))
