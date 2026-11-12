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
	check_near(pose.position.z, 0.0, "alinhada no eixo")


func test_zoom_fora_do_intervalo_e_limitado() -> void:
	check_eq(CameraRig.compute_pose(Vector2.ZERO, 0.0, 5.0), CameraRig.compute_pose(Vector2.ZERO, 0.0, 1.0), "zoom limitado")


func test_so_acompanha_o_mago_perto_da_terceira_pessoa() -> void:
	check_eq(CameraRig.follow_weight(0.0), 1.0, "3ª pessoa acompanha")
	check_eq(CameraRig.follow_weight(1.0), 0.0, "visão de cima não acompanha")
