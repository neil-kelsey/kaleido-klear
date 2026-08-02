shader_type canvas_item;

#include "res://assets/shaders/kaleido_rainbow.gdshaderinc"

// Scrolling rainbow ring for rounded secondary CTAs / chrome.
// Same kaleido_rainbow() stops as the brand title.

uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(400.0, 140.0);
uniform float corner_radius_px = 40.0;
uniform float border_width_px = 3.0;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 p = (UV - 0.5) * size;
	float radius = min(corner_radius_px, min(size.x, size.y) * 0.5 - 0.5);
	float outer = rounded_box_sdf(p, size * 0.5, radius);
	float inner = rounded_box_sdf(p, size * 0.5 - vec2(border_width_px), max(radius - border_width_px, 0.0));

	// Soft AA ring — opaque on the stroke, transparent inside/outside.
	float ring = smoothstep(1.25, -0.25, outer) * smoothstep(-1.25, 0.25, inner);
	if (ring < 0.004) {
		discard;
	}

	// March along the perimeter so the rainbow scrolls like the title.
	float t = UV.x * 0.92 + UV.y * 0.18 - phase;
	COLOR = vec4(kaleido_rainbow(t), ring);
}
