shader_type canvas_item;

// The letter artwork is white, with a few green accent pixels in the mark.
uniform vec4 ink : source_color = vec4(0.953, 0.937, 0.902, 1.0);
uniform vec4 accent : source_color = vec4(0.498, 0.890, 0.788, 1.0);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float green = src.g - max(src.r, src.b);
	float accent_w = smoothstep(0.02, 0.07, green);
	vec3 col = mix(ink.rgb, accent.rgb, accent_w);
	COLOR = vec4(col, src.a);
}
