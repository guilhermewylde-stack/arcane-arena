shader_type spatial;
// Lava: crosta escura com veios incandescentes que escorrem devagar. Ruído calculado aqui mesmo (sem texturas).
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
	vec2 p = world_pos.xz * 0.11;
	float t = TIME * 0.05;
	vec2 warp = vec2(fbm(p + vec2(t, 0.0)), fbm(p + vec2(5.2, 1.3) - vec2(0.0, t)));
	float n = fbm(p * 1.7 + warp * 1.6 + vec2(0.0, t * 0.5));
	// Crosta escura na maior parte; veios finos e quentes onde o ruído cruza o meio e um
	// vermelho abafado nas poças onde ele é baixo.
	float veins = 1.0 - smoothstep(0.0, 0.05, abs(n - 0.5));
	float pools = smoothstep(0.42, 0.18, n);
	float heat = clamp(veins * 0.9 + pools * 0.3, 0.0, 1.0);
	vec3 color = mix(vec3(0.03, 0.006, 0.004), vec3(0.42, 0.03, 0.006), smoothstep(0.0, 0.4, heat));
	color = mix(color, vec3(1.0, 0.32, 0.03), smoothstep(0.4, 0.8, heat));
	color = mix(color, vec3(1.0, 0.75, 0.35), smoothstep(0.85, 1.0, heat));
	ALBEDO = color * (1.0 + heat * 0.8) * energy;
}
