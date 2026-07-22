shader_type canvas_item;

// Soft diagonal highlight that drifts left to right across a primary CTA.

uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform float band_width : hint_range(0.05, 0.6) = 0.22;
uniform float strength : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	float d = UV.x * 0.85 + UV.y * 0.35;
	float center = phase * 1.6 - 0.3;
	float dist = abs(d - center);
	float band = 1.0 - smoothstep(0.0, band_width, dist);
	float vertical = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	float alpha = band * vertical * strength;
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
