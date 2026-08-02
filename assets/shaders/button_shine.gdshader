shader_type canvas_item;

// Soft diagonal gleam that drifts left to right across a primary CTA.
// Uses a Gaussian falloff + life fade so the band dissolves in/out —
// never a hard leading/trailing edge sliding across the face.

uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform float band_width : hint_range(0.05, 0.8) = 0.42;
uniform float strength : hint_range(0.0, 1.0) = 0.18;
uniform vec2 rect_size = vec2(400.0, 140.0);
uniform float corner_radius_px = 40.0;

float rounded_mask(vec2 uv, vec2 size, float radius) {
	vec2 p = uv * size;
	vec2 half_size = size * 0.5;
	float r = min(radius, min(half_size.x, half_size.y));
	vec2 q = abs(p - half_size) - (half_size - vec2(r));
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	return 1.0 - smoothstep(-0.75, 1.25, dist);
}

void fragment() {
	float mask = rounded_mask(UV, rect_size, corner_radius_px);
	if (mask <= 0.001) {
		discard;
	}

	float d = UV.x * 0.85 + UV.y * 0.35;
	float center = phase * 1.55 - 0.28;
	float dist = abs(d - center);

	// Wide Gaussian — peak is soft; skirts fade to ~0 with no visible wall.
	float sigma = max(band_width * 0.6, 0.12);
	float band = exp(-(dist * dist) / (2.0 * sigma * sigma));

	// Dissolve the whole gleam as it enters from the left / exits to the right
	// so you never see a sharp edge appear or leave the button.
	float life = smoothstep(-0.2, 0.22, center) * (1.0 - smoothstep(0.78, 1.2, center));

	// Also fade near the button's own left/right so any residual edge is invisible.
	float side_fade = smoothstep(0.0, 0.14, UV.x) * smoothstep(0.0, 0.14, 1.0 - UV.x);
	float vertical = smoothstep(0.0, 0.16, UV.y) * (1.0 - smoothstep(0.84, 1.0, UV.y));

	float alpha = band * life * side_fade * vertical * strength * mask;
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
