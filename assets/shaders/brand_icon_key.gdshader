shader_type canvas_item;

// Drop the flat black export backdrop so the K badge can sit over gameplay.
uniform float key_luma : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float chroma = max(max(tex.r, tex.g), tex.b) - min(min(tex.r, tex.g), tex.b);
	float keyed = 1.0 - smoothstep(key_luma, key_luma + 0.10, luma + chroma * 1.8);
	tex.a *= 1.0 - keyed;
	if (tex.a < 0.02) {
		discard;
	}
	COLOR = tex;
}
