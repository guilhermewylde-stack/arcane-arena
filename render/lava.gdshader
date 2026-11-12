shader_type spatial;
// Lava estilizada: faixas de cor quente que escorrem devagar. Ruído calculado aqui mesmo (sem texturas).
render_mode unshaded;

uniform float energy = 1.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.1;
	float t = TIME * 0.06;
	vec2 warp = vec2(fbm(p + vec2(t, 0.0)), fbm(p + vec2(5.2, 1.3) - vec2(0.0, t)));
	float n = fbm(p * 1.5 + warp * 1.4 + vec2(0.0, t * 0.5));
	// Lava de desenho: faixas chapadas do vermelho ao amarelo, com ilhas de crosta marrom.
	float heat = smoothstep(0.25, 0.75, n);
	float bands = floor(heat * 5.0 + 0.5) / 5.0;
	heat = mix(heat, bands, 0.75);
	vec3 color = mix(vec3(0.62, 0.08, 0.02), vec3(0.95, 0.3, 0.03), smoothstep(0.0, 0.5, heat));
	color = mix(color, vec3(1.0, 0.7, 0.15), smoothstep(0.55, 1.0, heat));
	float crust = smoothstep(0.6, 0.66, fbm(p * 2.3 - warp + vec2(31.0, 7.0)));
	color = mix(color, vec3(0.2, 0.06, 0.04), crust * 0.85);
	ALBEDO = color * energy;
}
