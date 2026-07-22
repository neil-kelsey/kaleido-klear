shader_type canvas_item;

// Simple, reliable title colouring (no blur builtins).

uniform float phase : hint_range(0.0, 1.0) = 0.0;
// 0 = rainbow, 2 = white, 3 = dark (for shadow layers)
uniform int mode = 0;

vec3 kaleido_rainbow(float t) {
	t = fract(t);
	// Slightly deeper cyan/yellow for readability on white; keep the rest vivid.
	vec3 c0 = vec3(0.00, 0.72, 0.92); // cyan
	vec3 c1 = vec3(0.22, 0.42, 0.95); // blue
	vec3 c2 = vec3(0.68, 0.24, 0.95); // purple
	vec3 c3 = vec3(0.95, 0.18, 0.62); // magenta
	vec3 c4 = vec3(0.95, 0.45, 0.12); // orange
	vec3 c5 = vec3(0.92, 0.72, 0.08); // yellow (darkened)
	vec3 c6 = vec3(0.12, 0.78, 0.38); // green
	vec3 c7 = vec3(0.00, 0.72, 0.92); // cyan
	float x = t * 7.0;
	float i = floor(x);
	float f = fract(x);
	vec3 a = c0;
	vec3 b = c1;
	if (i < 0.5) { a = c0; b = c1; }
	else if (i < 1.5) { a = c1; b = c2; }
	else if (i < 2.5) { a = c2; b = c3; }
	else if (i < 3.5) { a = c3; b = c4; }
	else if (i < 4.5) { a = c4; b = c5; }
	else if (i < 5.5) { a = c5; b = c6; }
	else { a = c6; b = c7; }
	return mix(a, b, f);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a * COLOR.a;
	if (a < 0.004) {
		discard;
	}
	float t = UV.x * 0.92 - phase;
	if (mode == 2) {
		COLOR = vec4(vec3(1.0), a);
	} else if (mode == 3) {
		COLOR = vec4(vec3(0.42, 0.45, 0.52), a * 0.38);
	} else {
		COLOR = vec4(kaleido_rainbow(t), a);
	}
}
