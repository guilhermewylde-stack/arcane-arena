extends RefCounted
## Matemática pura da câmera: do zoom 0 (3ª pessoa, atrás do mago) ao zoom 1 (visão de cima).

const ZOOM_MIN := 0.0
const ZOOM_MAX := 1.0
const NEAR := {"distance": 6.5, "height": 3.2, "look_height": 1.6}
const FAR := {"distance": 15.0, "height": 27.0, "look_height": 0.0}


static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, ZOOM_MIN, ZOOM_MAX)


## Quanto a câmera acompanha a direção do mago: 1 em 3ª pessoa, 0 na visão de cima.
static func follow_weight(zoom: float) -> float:
	return 1.0 - smoothstep(0.15, 0.45, clamp_zoom(zoom))


## Pose da câmera para um alvo no chão. `yaw` é a direção para onde a câmera olha
## (mesma convenção do `facing` do mago). Devolve { position: Vector3, look_at: Vector3 }.
static func compute_pose(target: Vector2, yaw: float, zoom: float) -> Dictionary:
	var z := clamp_zoom(zoom)
	var distance := lerpf(NEAR.distance, FAR.distance, z)
	return {
		"position": Vector3(
			target.x - sin(yaw) * distance,
			lerpf(NEAR.height, FAR.height, z),
			target.y - cos(yaw) * distance),
		"look_at": Vector3(target.x, lerpf(NEAR.look_height, FAR.look_height, z), target.y),
	}
