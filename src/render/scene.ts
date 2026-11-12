import * as THREE from "three";
import type { Vec2, World } from "../sim";
import { clampZoom, computeCameraPose, followWeight, lerpAngle } from "./cameraRig";

const MAGE_COLORS = [0x4aa3ff, 0xff5a4a, 0x6bd66b, 0xe0c040, 0xb070ff, 0xff8ad0, 0x50d8d0, 0xf0f0f0];

/** Tudo que é Three.js fica aqui. Recebe o estado da simulação e só desenha. */
export class GameRenderer {
  readonly canvas: HTMLCanvasElement;
  zoom = 1;

  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.PerspectiveCamera(50, 1, 0.1, 400);
  private readonly lava: THREE.Mesh<THREE.CircleGeometry, THREE.MeshBasicMaterial>;
  private readonly marker: THREE.Mesh;
  private readonly mageMeshes = new Map<number, THREE.Group>();
  private readonly raycaster = new THREE.Raycaster();
  private readonly ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private cameraYaw = 0;
  private markerLife = 0;

  constructor(world: World) {
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.canvas = this.renderer.domElement;
    document.body.appendChild(this.canvas);

    this.scene.background = new THREE.Color(0x0b0710);
    this.scene.fog = new THREE.Fog(0x1a0a08, 45, 140);

    this.scene.add(new THREE.HemisphereLight(0x8fa8ff, 0xff5a1e, 0.55));
    const sun = new THREE.DirectionalLight(0xfff0d8, 2.2);
    sun.position.set(-14, 30, 12);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    const s = world.arenaRadius + 4;
    Object.assign(sun.shadow.camera, { left: -s, right: s, top: s, bottom: -s, near: 1, far: 80 });
    this.scene.add(sun);

    this.lava = new THREE.Mesh(
      new THREE.CircleGeometry(200, 64),
      new THREE.MeshBasicMaterial({ color: 0xff4a12 }),
    );
    this.lava.rotation.x = -Math.PI / 2;
    this.lava.position.y = -1.2;
    this.scene.add(this.lava);

    const platform = new THREE.Mesh(
      new THREE.CylinderGeometry(world.arenaRadius, world.arenaRadius * 0.92, 1.6, 72),
      new THREE.MeshStandardMaterial({ color: 0x6b6470, roughness: 0.9, metalness: 0.05 }),
    );
    platform.position.y = -0.8;
    platform.receiveShadow = true;
    this.scene.add(platform);

    // Anéis decorativos para dar leitura de distância no chão.
    for (const f of [0.33, 0.66, 0.98]) {
      const ring = new THREE.Mesh(
        new THREE.RingGeometry(world.arenaRadius * f - 0.12, world.arenaRadius * f, 72),
        new THREE.MeshBasicMaterial({ color: 0x3a3340 }),
      );
      ring.rotation.x = -Math.PI / 2;
      ring.position.y = 0.01;
      this.scene.add(ring);
    }

    this.marker = new THREE.Mesh(
      new THREE.RingGeometry(0.35, 0.5, 32),
      new THREE.MeshBasicMaterial({ color: 0x7dffb0, transparent: true }),
    );
    this.marker.rotation.x = -Math.PI / 2;
    this.marker.position.y = 0.03;
    this.marker.visible = false;
    this.scene.add(this.marker);

    this.resize();
    window.addEventListener("resize", () => this.resize());
  }

  /** Converte um ponto da tela no ponto correspondente do chão da arena. */
  screenToGround(clientX: number, clientY: number): Vec2 | null {
    const rect = this.canvas.getBoundingClientRect();
    const ndc = new THREE.Vector2(
      ((clientX - rect.left) / rect.width) * 2 - 1,
      -((clientY - rect.top) / rect.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(ndc, this.camera);
    const hit = this.raycaster.ray.intersectPlane(this.ground, new THREE.Vector3());
    return hit ? { x: hit.x, z: hit.z } : null;
  }

  showMoveMarker(at: Vec2): void {
    this.marker.position.set(at.x, 0.03, at.z);
    this.marker.visible = true;
    this.markerLife = 1;
  }

  /**
   * Desenha um quadro. `prev`/`curr` são as posições dos dois últimos ticks e
   * `alpha` (0..1) é o quanto já andamos entre eles.
   */
  render(prev: World, curr: World, alpha: number, localMageId: number, frameDt: number, time: number): void {
    for (const mage of curr.mages) {
      const before = prev.mages.find((m) => m.id === mage.id) ?? mage;
      const mesh = this.mageMeshes.get(mage.id) ?? this.createMage(mage.id);
      mesh.position.set(
        before.pos.x + (mage.pos.x - before.pos.x) * alpha,
        0,
        before.pos.z + (mage.pos.z - before.pos.z) * alpha,
      );
      mesh.rotation.y = lerpAngle(mesh.rotation.y, mage.facing, Math.min(1, frameDt * 14));
    }

    const pulse = 0.5 + 0.5 * Math.sin(time * 1.3);
    this.lava.material.color.setRGB(1, 0.24 + pulse * 0.12, 0.05);

    if (this.markerLife > 0) {
      this.markerLife = Math.max(0, this.markerLife - frameDt * 2);
      (this.marker.material as THREE.MeshBasicMaterial).opacity = this.markerLife;
      this.marker.scale.setScalar(0.6 + this.markerLife * 0.6);
      this.marker.visible = this.markerLife > 0;
    }

    const local = this.mageMeshes.get(localMageId);
    if (local) {
      this.zoom = clampZoom(this.zoom);
      const targetYaw = lerpAngle(0, local.rotation.y, followWeight(this.zoom));
      this.cameraYaw = lerpAngle(this.cameraYaw, targetYaw, Math.min(1, frameDt * 5));
      const pose = computeCameraPose({ x: local.position.x, z: local.position.z }, this.cameraYaw, this.zoom);
      this.camera.position.set(pose.position.x, pose.position.y, pose.position.z);
      this.camera.lookAt(pose.lookAt.x, pose.lookAt.y, pose.lookAt.z);
    }
    this.renderer.render(this.scene, this.camera);
  }

  private createMage(id: number): THREE.Group {
    const color = MAGE_COLORS[id % MAGE_COLORS.length]!;
    const group = new THREE.Group();
    const robe = new THREE.Mesh(
      new THREE.ConeGeometry(0.62, 1.5, 20),
      new THREE.MeshStandardMaterial({ color, roughness: 0.7 }),
    );
    robe.position.y = 0.75;
    const head = new THREE.Mesh(
      new THREE.SphereGeometry(0.27, 20, 14),
      new THREE.MeshStandardMaterial({ color: 0xe8c9a8, roughness: 0.8 }),
    );
    head.position.y = 1.62;
    const hat = new THREE.Mesh(
      new THREE.ConeGeometry(0.36, 0.75, 20),
      new THREE.MeshStandardMaterial({ color: 0x2a2233, roughness: 0.6 }),
    );
    hat.position.y = 2.1;
    const staff = new THREE.Mesh(
      new THREE.CylinderGeometry(0.04, 0.04, 1.9, 8),
      new THREE.MeshStandardMaterial({ color: 0x5a3b22 }),
    );
    staff.position.set(0.55, 0.95, 0.25);
    const orb = new THREE.Mesh(
      new THREE.SphereGeometry(0.13, 14, 10),
      new THREE.MeshBasicMaterial({ color: 0xbfe6ff }),
    );
    orb.position.set(0.55, 1.98, 0.25);
    for (const part of [robe, head, hat, staff]) part.castShadow = true;
    group.add(robe, head, hat, staff, orb);
    this.scene.add(group);
    this.mageMeshes.set(id, group);
    return group;
  }

  private resize(): void {
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.camera.aspect = window.innerWidth / window.innerHeight;
    this.camera.updateProjectionMatrix();
  }
}
