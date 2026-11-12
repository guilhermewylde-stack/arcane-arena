import type { Command, Mage, World, WorldConfig } from "./types";

/** Passos de simulação por segundo. A simulação é determinística e não conhece o relógio real. */
export const TICK_RATE = 30;
export const DT = 1 / TICK_RATE;
export const MAGE_SPEED = 7;
export const DEFAULT_ARENA_RADIUS = 18;

export function createWorld(config: WorldConfig = {}): World {
  const arenaRadius = config.arenaRadius ?? DEFAULT_ARENA_RADIUS;
  const count = config.mageCount ?? 1;
  const mages: Mage[] = [];
  for (let i = 0; i < count; i++) {
    // Magos nascem distribuídos num anel; um mago sozinho nasce no centro.
    const angle = (i / count) * Math.PI * 2;
    const r = count === 1 ? 0 : arenaRadius * 0.6;
    mages.push({
      id: i,
      pos: { x: Math.sin(angle) * r, z: Math.cos(angle) * r },
      facing: angle + Math.PI,
      moveTarget: null,
    });
  }
  return { tick: 0, arenaRadius, mages };
}

/** Avança o mundo exatamente um tick, aplicando antes os comandos recebidos. */
export function step(world: World, commands: readonly Command[] = []): void {
  for (const cmd of commands) {
    const mage = world.mages.find((m) => m.id === cmd.mageId);
    if (!mage) continue;
    if (cmd.type === "move") mage.moveTarget = { x: cmd.target.x, z: cmd.target.z };
  }
  for (const mage of world.mages) moveMage(mage);
  world.tick++;
}

function moveMage(mage: Mage): void {
  const target = mage.moveTarget;
  if (!target) return;
  const dx = target.x - mage.pos.x;
  const dz = target.z - mage.pos.z;
  const dist = Math.hypot(dx, dz);
  const maxStep = MAGE_SPEED * DT;
  if (dist <= maxStep) {
    mage.pos.x = target.x;
    mage.pos.z = target.z;
    mage.moveTarget = null;
    return;
  }
  mage.facing = Math.atan2(dx, dz);
  mage.pos.x += (dx / dist) * maxStep;
  mage.pos.z += (dz / dist) * maxStep;
}
