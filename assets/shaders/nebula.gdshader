shader_type canvas_item;

// Shared nebula fill: one baked texture + in-place twinkle stars.
// mask_mode: 0 = none, 1 = rounded rect, 2 = diamond.

uniform vec2 rect_size = vec2(400.0, 140.0);
uniform float corner_radius_px = 40.0;
uniform float brightness = 1.0;
uniform float wash_out = 0.0;
uniform float time_sec = 0.0;
uniform int mask_mode = 1;
uniform float opacity = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float rounded_mask(vec2 uv, vec2 size, float radius) {
	vec2 p = uv * size;
	vec2 half_size = size * 0.5;
	float r = min(radius, min(half_size.x, half_size.y) - 0.5);
	vec2 q = abs(p - half_size) - (half_size - vec2(r));
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	return 1.0 - smoothstep(-2.0, 2.5, dist);
}

float diamond_mask(vec2 uv) {
	float d = abs(uv.x - 0.5) + abs(uv.y - 0.5);
	return 1.0 - smoothstep(0.492, 0.508, d);
}

float starfield(vec2 uv, float t) {
	float aspect = max(rect_size.x / max(rect_size.y, 1.0), 1.0);
	float stars = 0.0;

	for (int layer = 0; layer < 2; layer++) {
		float density = (layer == 0) ? 12.0 : 6.0;
		vec2 p = uv * vec2(aspect, 1.0) * density;
		if (layer == 1) {
			p += vec2(19.3, 7.1);
		}
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float h = hash21(cell + float(layer) * 31.0);
		if (h > 0.78) {
			vec2 center = vec2(hash21(cell + 0.37), hash21(cell + 2.11));
			float radius = mix(0.05, 0.14, hash21(cell + 5.5)) * ((layer == 0) ? 0.85 : 1.25);
			float d = length(f - center);
			float spark = exp(-(d * d) / max(radius * radius * 0.55, 0.0001));
			float twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * mix(1.1, 2.6, h) + h * 48.0));
			stars += spark * twinkle * mix(0.35, 1.0, h);
		}
	}

	float edge = smoothstep(0.0, 0.12, uv.x) * smoothstep(0.0, 0.12, 1.0 - uv.x);
	edge *= smoothstep(0.0, 0.14, uv.y) * smoothstep(0.0, 0.14, 1.0 - uv.y);
	return clamp(stars * edge, 0.0, 1.35);
}

void fragment() {
	float mask = 1.0;
	if (mask_mode == 1) {
		mask = rounded_mask(UV, rect_size, corner_radius_px);
	} else if (mask_mode == 2) {
		mask = diamond_mask(UV);
	}
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;
	col += vec3(0.95, 0.97, 1.0) * starfield(UV, time_sec) * 0.9;
	col *= brightness;
	if (wash_out > 0.001) {
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(luma), wash_out * 0.55);
		col = mix(col, vec3(0.94, 0.95, 0.98), wash_out * 0.62);
	}
	COLOR = vec4(col, tex.a * mask * opacity);
}
