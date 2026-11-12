extends CanvasLayer
## Menu principal, de pausa e tela de opções. Só mostra e emite sinais; quem age é `main.gd`.
## `setup` é a configuração da partida (ver `match_setup.gd`) e `settings` as opções de
## janela (ver `settings.gd`); os dois são editados pelos botões − e +.

signal start_requested(setup: Dictionary)
signal resume_requested
signal main_menu_requested
signal quit_requested
## Uma opção de janela mudou: `main.gd` aplica e salva.
signal settings_changed(settings: Dictionary)

const MatchSetup := preload("res://game/match_setup.gd")
const Settings := preload("res://game/settings.gd")

const MODE_MAIN := "main"
const MODE_PAUSE := "pause"
const MODE_OPTIONS := "options"

var mode := MODE_MAIN
var setup := MatchSetup.DEFAULTS.duplicate()
var settings := Settings.DEFAULTS.duplicate()
## Tamanho do monitor, para oferecer só resoluções que cabem (preenchido por `main.gd`).
var screen_size := Vector2i(1920, 1080)

var _title: Label
var _values := {}
## Pares [controle, modos em que ele aparece].
var _shown_in: Array[Array] = []
## Menu de onde a tela de opções foi aberta, para o "Voltar".
var _options_from := MODE_MAIN


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

	var menus := [MODE_MAIN, MODE_PAUSE]
	_only(_add_button(column, "Continuar (Esc)", func() -> void: resume_requested.emit()), [MODE_PAUSE])
	_only(_add_button(column, "Jogar (Enter)", func() -> void: start_requested.emit(setup)), [MODE_MAIN])
	_only(_add_button(column, "Nova partida", func() -> void: start_requested.emit(setup)), [MODE_PAUSE])
	for row: Array in [["bots", "Bots"], ["difficulty", "Dificuldade"], ["rounds", "Rodadas para vencer"]]:
		_only(_add_row(column, row[0], row[1], adjust), menus)
	_only(_add_button(column, "Opções", func() -> void: show_mode(MODE_OPTIONS)), menus)
	_only(_add_button(column, "Menu principal", func() -> void: main_menu_requested.emit()), [MODE_PAUSE])
	_only(_add_button(column, "Sair do jogo", func() -> void: quit_requested.emit()), menus)
	for row: Array in [["fullscreen", "Tela cheia (F11)"], ["resolution", "Resolução da janela"], ["vsync", "Vsync"]]:
		_only(_add_row(column, row[0], row[1], adjust_setting), [MODE_OPTIONS])
	_only(_add_button(column, "Voltar (Esc)", back), [MODE_OPTIONS])
	show_mode(MODE_MAIN)


## Abre o menu no modo dado (principal, pausa ou opções).
func show_mode(new_mode: String) -> void:
	if new_mode == MODE_OPTIONS and mode != MODE_OPTIONS:
		_options_from = mode
	mode = new_mode
	visible = true
	_title.text = {MODE_MAIN: "Arcane Arena", MODE_PAUSE: "Pausa", MODE_OPTIONS: "Opções"}[mode]
	for pair: Array in _shown_in:
		pair[0].visible = mode in pair[1]
	_refresh()


## Sai da tela de opções para o menu de onde ela foi aberta.
func back() -> void:
	show_mode(_options_from)


## Muda um campo da configuração da partida (é o que os botões − e + fazem).
func adjust(key: String, step: int) -> void:
	setup = MatchSetup.adjust(setup, key, step)
	_refresh()


## Muda uma opção de janela e avisa para ela valer na hora.
func adjust_setting(key: String, step: int) -> void:
	settings = Settings.adjust(settings, key, step, screen_size)
	_refresh()
	settings_changed.emit(settings)


func _refresh() -> void:
	setup = MatchSetup.sanitize(setup)
	settings = Settings.sanitize(settings)
	_values.bots.text = str(setup.bots)
	_values.difficulty.text = MatchSetup.DIFFICULTY_NAMES.get(setup.difficulty, setup.difficulty)
	_values.rounds.text = str(setup.rounds)
	_values.fullscreen.text = "Sim" if settings.fullscreen else "Não"
	_values.resolution.text = "%d × %d" % [settings.width, settings.height]
	_values.vsync.text = "Sim" if settings.vsync else "Não"


func _only(control: Control, modes: Array) -> void:
	_shown_in.append([control, modes])


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Linha "rótulo  −  valor  +"; os botões chamam `on_adjust(key, -1 ou 1)`.
func _add_row(parent: Control, key: String, text: String, on_adjust: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_add_button(row, " − ", func() -> void: on_adjust.call(key, -1))
	var value := Label.new()
	value.custom_minimum_size = Vector2(120, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	_values[key] = value
	_add_button(row, " + ", func() -> void: on_adjust.call(key, 1))
	parent.add_child(row)
	return row
