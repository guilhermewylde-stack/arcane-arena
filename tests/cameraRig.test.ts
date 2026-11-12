import { describe, expect, it } from "vitest";
import { computeCameraPose, followWeight, lerpAngle } from "../src/render/cameraRig";

describe("câmera", () => {
  it("visão de cima: alta, olhando para o chão no alvo", () => {
    const pose = computeCameraPose({ x: 2, z: 3 }, 0, 1);
    expect(pose.position.y).toBeGreaterThan(20);
    expect(pose.lookAt).toEqual({ x: 2, y: 0, z: 3 });
  });

  it("3ª pessoa: baixa e atrás do mago em relação ao yaw", () => {
    const pose = computeCameraPose({ x: 0, z: 0 }, Math.PI / 2, 0);
    expect(pose.position.y).toBeLessThan(5);
    expect(pose.position.x).toBeLessThan(-5); // olhando para +x, câmera fica em -x
    expect(pose.position.z).toBeCloseTo(0, 5);
  });

  it("zoom fora do intervalo é limitado", () => {
    expect(computeCameraPose({ x: 0, z: 0 }, 0, 5)).toEqual(computeCameraPose({ x: 0, z: 0 }, 0, 1));
  });

  it("só acompanha a direção do mago perto da 3ª pessoa", () => {
    expect(followWeight(0)).toBe(1);
    expect(followWeight(1)).toBe(0);
  });

  it("interpola ângulos pelo caminho mais curto", () => {
    expect(lerpAngle(3, -3, 0.5)).toBeCloseTo(Math.PI, 1);
  });
});
