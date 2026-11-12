extends RefCounted
## Matemática pura da câmera: do zoom 0 (3ª pessoa, atrás do mago) ao zoom 1 (visão de cima).

const ZOOM_MIN := 0.0
const ZOOM_MAX := 1.0
## `shoulder`: deslocamento lateral (câmera de ombro), para o mago não tapar a mira.
const NEAR := {"distance": 6.5, "height": 3.2, "look_height": 1.6, "shoulder": 1.3}
const FAR := {"distance": 15.0, "height": 27.0, "look_height": 0.0}
## Abaixo deste zoom valem os controles de 3ª pessoa (WASD, mouse capturado).
const THIRD_PERSON_ZOOM := 0.3
## Limites da distância da mira (retículo no chão) até o mago.
const AIM_MIN := 3.0
const AIM_MAX := 24.0


static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, ZOOM_MIN, ZOOM_MAX)


## Quanto a câmera acompanha a direção da mira: 1 em 3ª pessoa, 0 na visão de cima.
## A passagem acontece logo acima de `THIRD_PERSON_ZOOM`, para a troca de esquema ser suave.
static func follow_weight(zoom: float) -> float:
	return 1.0 - smoothstep(THIRD_PERSON_ZOOM, THIRD_PERSON_ZOOM + 0.3, clamp_zoom(zoom))


static func is_third_person(zoom: float) -> bool:
	return clamp_zoom(zoom) < THIRD_PERSON_ZOOM


## Direita da tela, no chão, para uma câmera olhando na direção `yaw`.
static func screen_right(yaw: float) -> Vector2:
	return Vector2(-cos(yaw), sin(yaw))


## Direção no chão para as teclas de movimento (`input`: x = direita da tela, y = para a
## frente), relativa à câmera. Unitária, ou zero sem tecla.
static func move_direction(input: Vector2, yaw: float) -> Vector2:
	var forward := Vector2(sin(yaw), cos(yaw))
	return (forward * input.y + screen_right(yaw) * input.x).normalized()


static func clamp_aim_distance(distance: float) -> float:
	return clampf(distance, AIM_MIN, AIM_MAX)


## Ponto do chão onde a mira de 3ª pessoa está: à frente do mago, na direção `yaw`.
static func aim_point(mage_pos: Vector2, yaw: float, distance: float) -> Vector2:
	return mage_pos + Vector2(sin(yaw), cos(yaw)) * clamp_aim_distance(distance)


## Pose da câmera para um alvo no chão. `yaw` é a direção para onde a câmera olha
## (mesma convenção do `facing` do mago). Devolve { position: Vector3, look_at: Vector3 }.
static func compute_pose(target: Vector2, yaw: float, zoom: float) -> Dictionary:
	var z := clamp_zoom(zoom)
	var distance := lerpf(NEAR.distance, FAR.distance, z)
	# O ombro some cedo no zoom, junto com os controles de 3ª pessoa.
	var side := screen_right(yaw) * NEAR.shoulder * follow_weight(z)
	return {
		"position": Vector3(
			target.x - sin(yaw) * distance + side.x,
			lerpf(NEAR.height, FAR.height, z),
			target.y - cos(yaw) * distance + side.y),
		"look_at": Vector3(target.x + side.x, lerpf(NEAR.look_height, FAR.look_height, z), target.y + side.y),
	}
