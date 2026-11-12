shader_type spatial;
// Plataforma de pedra gasta: lajes irregulares com grão e musgo nas juntas. Perto da borda (que encolhe) a pedra chamusca e as
// juntas ficam incandescentes; as laterais brilham de baixo para cima, iluminadas pela lava.

uniform float edge_radius = 18.0;
uniform float pulse = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// x: distância até a borda da célula mais próxima; y: número aleatório da célula.
vec2 cells(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 nearest_g = vec2(0.0);
	vec2 nearest_r = vec2(0.0);
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest_r = r;
				nearest_g = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = nearest_g + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			if (dot(nearest_r - r, nearest_r - r) > 0.00001) {
				edge = min(edge, dot(0.5 * (nearest_r + r), normalize(r - nearest_r)));
			}
		}
	}
	return vec2(edge, hash2(n + nearest_g).x);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float soft_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x), mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, f.x), f.y);
}

void fragment() {
	vec3 hot = vec3(1.0, 0.36, 0.05);
	float top = step(0.5, world_normal.y);
	vec2 cell = cells(world_pos.xz * 0.5);
	float joint = 1.0 - smoothstep(0.0, 0.045, cell.x);
	float broad = soft_noise(world_pos.xz * 0.35);
	float mid = soft_noise(world_pos.xz * 2.1);
	float fine = soft_noise(world_pos.xz * 9.0) * 0.6 + soft_noise(world_pos.xz * 31.0) * 0.4;
	// Lajes gastas de pedra cinza-parda: manchas largas, grão fino e bordas escurecidas (dá relevo).
	vec3 stone = mix(vec3(0.3, 0.285, 0.265), vec3(0.4, 0.365, 0.32), cell.y);
	stone *= 0.62 + 0.35 * broad + 0.22 * mid + 0.2 * fine;
	stone *= mix(0.6, 1.0, smoothstep(0.0, 0.2, cell.x));
	// Musgo escuro só nas juntas, onde a pedra é mais úmida.
	float moss = (1.0 - smoothstep(0.0, 0.14, cell.x)) * smoothstep(0.4, 0.65, broad);
	vec3 top_color = mix(stone, vec3(0.1, 0.13, 0.06) * (0.7 + 0.6 * fine), moss * 0.85);
	top_color = mix(top_color, vec3(0.045, 0.04, 0.036), joint);
	// Perto da borda (que encolhe) a pedra fica chamuscada e as juntas acendem.
	float r = length(world_pos.xz);
	float near_edge = smoothstep(edge_radius - 3.5, edge_radius - 0.2, r);
	top_color = mix(top_color, top_color * vec3(0.45, 0.36, 0.34), near_edge);
	float top_glow = joint * near_edge * near_edge * (1.0 + pulse * 0.8);
	// Laterais: rocha bruta com o clarão da lava subindo.
	float below = smoothstep(0.0, -1.6, world_pos.y);
	float rough = soft_noise(world_pos.xy * 3.0 + world_pos.zy * 2.0);
	vec3 side_color = vec3(0.17, 0.14, 0.12) * (0.6 + 0.7 * rough);
	ALBEDO = mix(side_color, top_color, top);
	EMISSION = hot * mix(below * below * 1.1, top_glow, top);
	ROUGHNESS = 0.95;
}
