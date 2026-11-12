import type { Vec2 } from "../sim";

export interface CameraPose {
  position: { x: number; y: number; z: number };
  lookAt: { x: number; y: number; z: number };
}

export const ZOOM_MIN = 0; // 3ª pessoa, atrás do mago
export const ZOOM_MAX = 1; // visão de cima, estilo MOBA

const NEAR = { distance: 6.5, height: 3.2, lookHeight: 1.6 };
const FAR = { distance: 15, height: 27, lookHeight: 0 };

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const smoothstep = (e0: number, e1: number, x: number) => {
  const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
};

export function clampZoom(zoom: number): number {
  return Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, zoom));
}

/** Quanto a câmera acompanha a direção do mago: 1 em 3ª pessoa, 0 na visão de cima. */
export function followWeight(zoom: number): number {
  return 1 - smoothstep(0.15, 0.45, clampZoom(zoom));
}

/**
 * Pose da câmera para um alvo no chão. `yaw` é a direção para onde a câmera olha
 * (mesma convenção de Mage.facing); quem chama decide como suavizá-la.
 */
export function computeCameraPose(target: Vec2, yaw: number, zoom: number): CameraPose {
  const z = clampZoom(zoom);
  const distance = lerp(NEAR.distance, FAR.distance, z);
  return {
    position: {
      x: target.x - Math.sin(yaw) * distance,
      y: lerp(NEAR.height, FAR.height, z),
      z: target.z - Math.cos(yaw) * distance,
    },
    lookAt: { x: target.x, y: lerp(NEAR.lookHeight, FAR.lookHeight, z), z: target.z },
  };
}

/** Interpola ângulos pelo caminho mais curto. */
export function lerpAngle(from: number, to: number, t: number): number {
  let diff = (to - from) % (Math.PI * 2);
  if (diff > Math.PI) diff -= Math.PI * 2;
  if (diff < -Math.PI) diff += Math.PI * 2;
  return from + diff * t;
}
