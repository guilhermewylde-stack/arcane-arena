extends CanvasLayer
## Menu principal e de pausa. Só mostra e emite sinais; quem age é `main.gd`.
## `setup` é a configuração da partida (ver `match_setup.gd`), editada pelos botões − e +.

signal start_requested(setup: Dictionary)
signal resume_requested
signal main_menu_requested
signal quit_requested

const MatchSetup := preload("res://game/match_setup.gd")

const MODE_MAIN := "main"
const MODE_PAUSE := "pause"

var mode := MODE_MAIN
var setup := MatchSetup.DEFAULTS.duplicate()

var _title: Label
var _values := {}
var _main_only: Array[Control] = []
var _pause_only: Array[Control] = []


func _init() -> void:
	layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.07, 0.05, 0.1, 0.94)
	backdrop.set_corner_radius_all(8)
	backdrop.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", backdrop)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(420, 0)
	panel.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color("ffb347"))
	column.add_child(_title)

	_pause_only.append(_add_button(column, "Continuar (Esc)", func() -> void: resume_requested.emit()))
	_main_only.append(_add_button(column, "Jogar (Enter)", func() -> void: start_requested.emit(setup)))
	_pause_only.append(_add_button(column, "Nova partida", func() -> void: start_requested.emit(setup)))
	for row: Array in [["bots", "Bots"], ["difficulty", "Dificuldade"], ["rounds", "Rodadas para vencer"]]:
		_add_setup_row(column, row[0], row[1])
	_pause_only.append(_add_button(column, "Menu principal", func() -> void: main_menu_requested.emit()))
	_add_button(column, "Sair do jogo", func() -> void: quit_requested.emit())
	show_mode(MODE_MAIN)


## Abre o menu no modo dado (principal ou pausa).
func show_mode(new_mode: String) -> void:
	mode = new_mode
	visible = true
	_title.text = "Arcane Arena" if mode == MODE_MAIN else "Pausa"
	for control in _main_only:
		control.visible = mode == MODE_MAIN
	for control in _pause_only:
		control.visible = mode == MODE_PAUSE
	_refresh()


## Muda um campo da configuração (é o que os botões − e + fazem).
func adjust(key: String, step: int) -> void:
	setup = MatchSetup.adjust(setup, key, step)
	_refresh()


func _refresh() -> void:
	setup = MatchSetup.sanitize(setup)
	_values.bots.text = str(setup.bots)
	_values.difficulty.text = MatchSetup.DIFFICULTY_NAMES.get(setup.difficulty, setup.difficulty)
	_values.rounds.text = str(setup.rounds)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_setup_row(parent: Control, key: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_add_button(row, " − ", func() -> void: adjust(key, -1))
	var value := Label.new()
	value.custom_minimum_size = Vector2(90, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	_values[key] = value
	_add_button(row, " + ", func() -> void: adjust(key, 1))
	parent.add_child(row)
