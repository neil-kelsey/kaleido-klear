shader_type canvas_item;

// The website veil is one band, 2.6 viewport-widths wide, slid by a cubic
// ease: left = (-2.6 + 3.6 * ease) * width. At ease 0.5 the band covers
// the background. The moth is drawn above this band, so the sweep never
// erases the silhouette. vert_color keeps the final fade on this layer too.
varying vec4 vert_color;

uniform float progress = 0.0;
uniform vec4 mist_color : source_color = vec4(0.925490, 0.894118, 0.823529, 1.0);
uniform vec4 edge_color : source_color = vec4(0.925490, 0.894118, 0.823529, 1.0);

void vertex() {
	vert_color = COLOR;
}

float ease(float p) {
	if (p < 0.5) {
		return 4.0 * p * p * p;
	}
	return 1.0 - pow(-2.0 * p + 2.0, 3.0) / 2.0;
}

void fragment() {
	float e = ease(clamp(progress, 0.0, 1.0));
	float left = -2.6 + 3.6 * e;
	float mx = (UV.x - left) / 2.6;
	float cover = smoothstep(0.0, 0.18, mx) * (1.0 - smoothstep(0.78, 1.0, mx));
	float rim = smoothstep(0.62, 0.86, mx) * (1.0 - smoothstep(0.86, 1.05, mx));
	vec3 col = mix(mist_color.rgb, edge_color.rgb, rim * 0.85);
	COLOR = vec4(col, cover) * vert_color;
}
