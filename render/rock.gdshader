shader_type spatial;
// Plataforma de basalto: lajes escuras separadas por rachaduras. Perto da borda (que encolhe) as
// rachaduras ficam incandescentes; as laterais brilham de baixo para cima, iluminadas pela lava.

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

void fragment() {
	vec3 hot = vec3(1.0, 0.33, 0.04);
	float top = step(0.5, world_normal.y);
	vec2 cell = cells(world_pos.xz * 0.42);
	float crack = 1.0 - smoothstep(0.0, 0.07, cell.x);
	float grain = hash2(floor(world_pos.xz * 9.0)).x;
	vec3 slab = vec3(0.15, 0.145, 0.18) * (0.7 + 0.5 * cell.y + 0.08 * grain);
	float r = length(world_pos.xz);
	float near_edge = smoothstep(edge_radius - 3.5, edge_radius - 0.2, r);
	float rim = smoothstep(edge_radius - 0.3, edge_radius, r);
	vec3 top_color = mix(slab, vec3(0.012, 0.01, 0.014), crack);
	float top_glow = crack * near_edge * near_edge * (1.2 + pulse * 1.0) + rim * 0.4;
	// Laterais: rocha quase preta com o clarão da lava subindo.
	float below = smoothstep(0.0, -1.6, world_pos.y);
	vec3 side_color = vec3(0.03, 0.026, 0.03);
	ALBEDO = mix(side_color, top_color, top);
	EMISSION = hot * mix(below * below * 1.8, top_glow, top);
	ROUGHNESS = 0.88;
}
