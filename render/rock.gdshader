shader_type spatial;
// Plataforma de pedra clara: lajes com musgo. Perto da borda (que encolhe) a pedra chamusca e as
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
	vec3 hot = vec3(1.0, 0.4, 0.05);
	float top = step(0.5, world_normal.y);
	vec2 cell = cells(world_pos.xz * 0.42);
	float joint = 1.0 - smoothstep(0.0, 0.06, cell.x);
	// Lajes de pedra clara, cada uma com um tom; musgo nas juntas e em manchas.
	vec3 slab = mix(vec3(0.5, 0.44, 0.35), vec3(0.38, 0.37, 0.35), cell.y);
	float moss_patch = smoothstep(0.56, 0.64, soft_noise(world_pos.xz * 0.22) * 0.7 + soft_noise(world_pos.xz * 0.9) * 0.3);
	float moss = clamp(moss_patch * 0.8 + (1.0 - smoothstep(0.0, 0.16, cell.x)) * 0.55, 0.0, 1.0);
	vec3 top_color = mix(slab, vec3(0.2, 0.36, 0.11), moss);
	top_color = mix(top_color, vec3(0.17, 0.15, 0.12), joint * (1.0 - moss_patch));
	// Perto da borda (que encolhe) a pedra fica chamuscada e as juntas acendem.
	float r = length(world_pos.xz);
	float near_edge = smoothstep(edge_radius - 3.5, edge_radius - 0.2, r);
	top_color = mix(top_color, top_color * vec3(0.5, 0.4, 0.38), near_edge);
	float top_glow = joint * near_edge * near_edge * (1.4 + pulse * 1.0);
	// Laterais: rocha marrom com o clarão da lava subindo.
	float below = smoothstep(0.0, -1.6, world_pos.y);
	vec3 side_color = vec3(0.22, 0.16, 0.13);
	ALBEDO = mix(side_color, top_color, top);
	EMISSION = hot * mix(below * below * 0.9, top_glow, top);
	ROUGHNESS = 0.9;
}
