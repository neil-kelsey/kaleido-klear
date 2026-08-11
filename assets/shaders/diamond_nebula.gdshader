shader_type canvas_item;

## Nebula fill for diamond polygons (twinkle stars, no rounded mask).

uniform float brightness = 1.0;
uniform float time_sec = 0.0;
uniform vec2 rect_size = vec2(128.0, 128.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float starfield(vec2 uv, float t) {
	float aspect = max(rect_size.x / max(rect_size.y, 1.0), 1.0);
	float stars = 0.0;

	for (int layer = 0; layer < 2; layer++) {
		float density = (layer == 0) ? 10.0 : 5.0;
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
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;
	col += vec3(0.95, 0.97, 1.0) * starfield(UV, time_sec) * 0.9;
	col *= brightness;
	COLOR = vec4(col, tex.a);
}
