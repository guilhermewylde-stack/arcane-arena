/** Plano do chão: x (leste) e z (sul). Toda a simulação é 2D; a altura é só visual. */
export interface Vec2 {
  x: number;
  z: number;
}

export interface Mage {
  id: number;
  pos: Vec2;
  /** Ângulo em radianos em torno do eixo Y; 0 aponta para +z. */
  facing: number;
  moveTarget: Vec2 | null;
}

export interface World {
  tick: number;
  arenaRadius: number;
  mages: Mage[];
}

export type Command = { type: "move"; mageId: number; target: Vec2 };

export interface WorldConfig {
  arenaRadius?: number;
  mageCount?: number;
}
