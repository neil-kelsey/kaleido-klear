shader_type canvas_item;

// Level-select backdrop only. Same bake as CTA nebula, but:
// - cover-sampled (no portrait stretch)
// - crushed almost to black with a hint of colour
// - quiet twinkle stars

uniform vec2 rect_size = vec2(400.0, 800.0);
uniform vec2 tex_size = vec2(1024.0, 384.0);
uniform float brightness = 1.0;
uniform float time_sec = 0.0;
uniform float ink = 0.045; // how much nebula colour leaks through

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 cover_uv(vec2 uv) {
	vec2 screen = max(rect_size, vec2(1.0));
	vec2 tex = max(tex_size, vec2(1.0));
	float s = max(screen.x / tex.x, screen.y / tex.y);
	vec2 sized = tex * s;
	return (uv * screen - screen * 0.5) / sized + 0.5;
}

float starfield(vec2 uv, float t) {
	// Cell size in screen pixels so sparks stay circular on a tall portrait rect.
	vec2 pixel = uv * max(rect_size, vec2(1.0));
	float stars = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float cell = (layer == 0) ? 52.0 : 88.0;
		vec2 p = pixel / cell;
		if (layer == 1) {
			p += vec2(19.3, 7.1);
		}
		vec2 grid = floor(p);
		vec2 f = fract(p);
		float h = hash21(grid + float(layer) * 31.0);
		if (h > 0.82) {
			vec2 center = vec2(hash21(grid + 0.37), hash21(grid + 2.11));
			float radius = mix(0.04, 0.11, hash21(grid + 5.5)) * ((layer == 0) ? 0.8 : 1.2);
			float d = length(f - center);
			float spark = exp(-(d * d) / max(radius * radius * 0.55, 0.0001));
			float twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * mix(0.8, 2.0, h) + h * 48.0));
			stars += spark * twinkle * mix(0.25, 0.8, h);
		}
	}
	return clamp(stars, 0.0, 1.2);
}

void fragment() {
	vec2 uv = cover_uv(UV);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec3 neb = texture(TEXTURE, uv).rgb;
	vec3 night = vec3(0.012, 0.012, 0.018);
	vec3 col = mix(night, neb, ink);
	col += vec3(0.92, 0.94, 1.0) * starfield(UV, time_sec) * 0.55;
	col *= brightness;
	COLOR = vec4(col, 1.0);
}
