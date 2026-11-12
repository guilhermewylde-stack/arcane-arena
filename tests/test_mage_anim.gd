extends "res://tests/test_case.gd"

const MageAnim := preload("res://render/mage_anim.gd")


func test_parado_e_andando() -> void:
	var anim := MageAnim.new()
	check_eq(anim.update(0.1, true, false), MageAnim.IDLE, "parado")
	check_eq(anim.update(0.1, true, true), MageAnim.RUN, "andando")


func test_lancar_tem_prioridade_sobre_andar_e_depois_acaba() -> void:
	var anim := MageAnim.new()
	anim.notify("cast")
	check_eq(anim.update(0.1, true, true), MageAnim.CAST, "lançando")
	check_eq(anim.update(MageAnim.CAST_TIME, true, true), MageAnim.RUN, "voltou a andar")


func test_atingido_interrompe_o_lancamento() -> void:
	var anim := MageAnim.new()
	anim.notify("cast")
	anim.notify("hit")
	check_eq(anim.update(0.1, true, false), MageAnim.HIT, "atingido")
	check_eq(anim.update(MageAnim.HIT_TIME, true, false), MageAnim.IDLE, "recuperou sem voltar a lançar")


func test_morto_vence_tudo_e_reviver_limpa() -> void:
	var anim := MageAnim.new()
	anim.notify("hit")
	check_eq(anim.update(0.1, false, true), MageAnim.DEATH, "morto")
	check_eq(anim.update(0.1, true, false), MageAnim.IDLE, "nova rodada: parado, sem resto de 'atingido'")


func test_eventos_desconhecidos_sao_ignorados() -> void:
	var anim := MageAnim.new()
	anim.notify("nova")
	check_eq(anim.update(0.1, true, false), MageAnim.IDLE, "nova não é animação")
