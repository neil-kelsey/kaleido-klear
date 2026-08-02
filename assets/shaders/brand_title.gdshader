shader_type canvas_item;

#include "res://assets/shaders/kaleido_rainbow.gdshaderinc"

// Simple, reliable title colouring (no blur builtins).

uniform float phase : hint_range(0.0, 1.0) = 0.0;
// 0 = rainbow, 2 = white, 3 = dark (for shadow layers)
uniform int mode = 0;

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
