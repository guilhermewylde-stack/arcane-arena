extends "res://tests/test_case.gd"

const CameraRig := preload("res://render/camera_rig.gd")


func test_visao_de_cima_alta_olhando_para_o_alvo() -> void:
	var pose := CameraRig.compute_pose(Vector2(2, 3), 0.0, 1.0)
	check(pose.position.y > 20.0, "câmera alta")
	check_eq(pose.look_at, Vector3(2, 0, 3), "olha para o chão no alvo")


func test_terceira_pessoa_baixa_e_atras_do_mago() -> void:
	var pose := CameraRig.compute_pose(Vector2.ZERO, PI / 2, 0.0)
	check(pose.position.y < 5.0, "câmera baixa")
	check(pose.position.x < -5.0, "olhando para +x, câmera fica em -x")
	check_near(pose.position.z, CameraRig.NEAR.shoulder, "fora do eixo só pelo ombro")


func test_zoom_fora_do_intervalo_e_limitado() -> void:
	check_eq(CameraRig.compute_pose(Vector2.ZERO, 0.0, 5.0), CameraRig.compute_pose(Vector2.ZERO, 0.0, 1.0), "zoom limitado")


func test_so_acompanha_o_mago_perto_da_terceira_pessoa() -> void:
	check_eq(CameraRig.follow_weight(0.0), 1.0, "3ª pessoa acompanha")
	check_eq(CameraRig.follow_weight(1.0), 0.0, "visão de cima não acompanha")
	check_eq(CameraRig.follow_weight(CameraRig.THIRD_PERSON_ZOOM), 1.0, "acompanha por inteiro enquanto valem os controles de 3ª pessoa")


func test_terceira_pessoa_so_com_zoom_proximo() -> void:
	check(CameraRig.is_third_person(0.0), "zoom 0 é 3ª pessoa")
	check(not CameraRig.is_third_person(1.0), "zoom 1 é visão de cima")
	check(not CameraRig.is_third_person(0.5), "zoom do meio ainda é visão de cima")


func test_wasd_e_relativo_a_camera() -> void:
	# `input`: x = direita da tela, y = para a frente.
	var forward := CameraRig.move_direction(Vector2(0, 1), PI / 2)
	check_near(forward.x, 1.0, "frente segue o yaw (+x)")
	check_near(forward.y, 0.0, "sem desvio lateral")
	# Com yaw 0 (olhando para +z) a direita da tela é -x do mundo.
	var right := CameraRig.move_direction(Vector2(1, 0), 0.0)
	check_near(right.x, -1.0, "direita da tela")
	check_near(right.y, 0.0, "sem avanço")
	check_near(CameraRig.move_direction(Vector2(1, 1), 0.3).length(), 1.0, "diagonal normalizada")
	check_eq(CameraRig.move_direction(Vector2.ZERO, 0.3), Vector2.ZERO, "sem tecla, sem direção")


func test_mira_fica_no_chao_a_frente_do_mago() -> void:
	var aim := CameraRig.aim_point(Vector2(1, 2), PI / 2, 8.0)
	check_near(aim.x, 9.0, "à frente em +x")
	check_near(aim.y, 2.0, "alinhada")
	var near := CameraRig.aim_point(Vector2.ZERO, 0.0, 0.0)
	check_near(near.y, CameraRig.AIM_MIN, "distância mínima")
	var far := CameraRig.aim_point(Vector2.ZERO, 0.0, 999.0)
	check_near(far.y, CameraRig.AIM_MAX, "distância máxima")


func test_camera_de_ombro_so_em_terceira_pessoa() -> void:
	# Olhando para +z, a direita da tela é -x: a câmera desloca para a direita do mago.
	var near := CameraRig.compute_pose(Vector2.ZERO, 0.0, 0.0)
	check(near.position.x < -0.5, "câmera à direita do mago")
	check_near(near.look_at.x, near.position.x, "continua olhando paralelo à mira")
	check_near(CameraRig.compute_pose(Vector2.ZERO, 0.0, 1.0).position.x, 0.0, "visão de cima centrada")
