shader_type canvas_item;

// The dark rig is painted on solid black. Key that black out so the layers
// stack with normal alpha and no rectangle shows on the dark splash.
// vert_color carries the canvas modulate. Writing COLOR alone drops it,
// which left the wordmark accent on screen after the splash had faded.
varying vec4 vert_color;

void vertex() {
	vert_color = COLOR;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float lum = max(src.r, max(src.g, src.b));
	float keep = smoothstep(0.02, 0.09, lum);
	COLOR = vec4(src.rgb, src.a * keep) * vert_color;
}
