import { describe, expect, it } from "vitest";
import { createWorld, MAGE_SPEED, step, TICK_RATE } from "../src/sim";

describe("movimento do mago", () => {
  it("fica parado sem comandos", () => {
    const world = createWorld();
    step(world);
    expect(world.mages[0]!.pos).toEqual({ x: 0, z: 0 });
    expect(world.tick).toBe(1);
  });

  it("anda na velocidade do mago em direção ao alvo", () => {
    const world = createWorld();
    step(world, [{ type: "move", mageId: 0, target: { x: 100, z: 0 } }]);
    for (let i = 1; i < TICK_RATE; i++) step(world);
    expect(world.mages[0]!.pos.x).toBeCloseTo(MAGE_SPEED, 5);
    expect(world.mages[0]!.pos.z).toBeCloseTo(0, 5);
  });

  it("chega exatamente no alvo e para", () => {
    const world = createWorld();
    step(world, [{ type: "move", mageId: 0, target: { x: 3, z: -4 } }]);
    for (let i = 0; i < TICK_RATE * 2; i++) step(world);
    const mage = world.mages[0]!;
    expect(mage.pos).toEqual({ x: 3, z: -4 });
    expect(mage.moveTarget).toBeNull();
  });

  it("vira para a direção do movimento", () => {
    const world = createWorld();
    step(world, [{ type: "move", mageId: 0, target: { x: 10, z: 0 } }]);
    expect(world.mages[0]!.facing).toBeCloseTo(Math.PI / 2, 5);
  });

  it("um novo comando substitui o alvo anterior", () => {
    const world = createWorld();
    step(world, [{ type: "move", mageId: 0, target: { x: 10, z: 0 } }]);
    step(world, [{ type: "move", mageId: 0, target: { x: 0, z: 0 } }]);
    for (let i = 0; i < TICK_RATE; i++) step(world);
    expect(world.mages[0]!.pos.x).toBeCloseTo(0, 5);
  });

  it("é determinístico: mesmos comandos, mesmo estado", () => {
    const run = () => {
      const w = createWorld({ mageCount: 4 });
      step(w, [{ type: "move", mageId: 2, target: { x: 1.5, z: 7 } }]);
      for (let i = 0; i < 50; i++) step(w);
      return JSON.stringify(w);
    };
    expect(run()).toBe(run());
  });
});
