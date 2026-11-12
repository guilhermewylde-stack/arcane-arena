import { GameRenderer } from "./render/scene";
import { type Command, createWorld, DT, step, type World } from "./sim";

const LOCAL_MAGE = 0;
const world = createWorld();
let previous: World = structuredClone(world);
const renderer = new GameRenderer(world);
const pending: Command[] = [];

renderer.canvas.addEventListener("contextmenu", (e) => e.preventDefault());
renderer.canvas.addEventListener("pointerdown", (e) => {
  if (e.button !== 2) return;
  const target = renderer.screenToGround(e.clientX, e.clientY);
  if (!target) return;
  pending.push({ type: "move", mageId: LOCAL_MAGE, target });
  renderer.showMoveMarker(target);
});
renderer.canvas.addEventListener(
  "wheel",
  (e) => {
    e.preventDefault();
    renderer.zoom += Math.sign(e.deltaY) * 0.08;
  },
  { passive: false },
);

// Gancho de depuração usado pelos testes de fumaça no navegador.
Object.assign(window, { __game: { world, renderer } });

let last = performance.now();
let accumulator = 0;
function frame(now: number): void {
  const frameDt = Math.min(0.1, (now - last) / 1000);
  last = now;
  accumulator += frameDt;
  while (accumulator >= DT) {
    previous = structuredClone(world);
    step(world, pending.splice(0));
    accumulator -= DT;
  }
  renderer.render(previous, world, accumulator / DT, LOCAL_MAGE, frameDt, now / 1000);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
