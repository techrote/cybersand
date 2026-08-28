shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float glow_strength : hint_range(0.0, 2.0, 0.05) = 0.62;

void fragment() {
	vec2 near_offset = TEXTURE_PIXEL_SIZE * 1.5;
	vec2 far_offset = TEXTURE_PIXEL_SIZE * 4.0;
	vec3 centre = texture(TEXTURE, UV).rgb;
	vec3 glow = centre * 0.30;
	glow += texture(TEXTURE, UV + vec2(near_offset.x, 0.0)).rgb * 0.08;
	glow += texture(TEXTURE, UV - vec2(near_offset.x, 0.0)).rgb * 0.08;
	glow += texture(TEXTURE, UV + vec2(0.0, near_offset.y)).rgb * 0.08;
	glow += texture(TEXTURE, UV - vec2(0.0, near_offset.y)).rgb * 0.08;
	glow += texture(TEXTURE, UV + near_offset).rgb * 0.05;
	glow += texture(TEXTURE, UV - near_offset).rgb * 0.05;
	glow += texture(TEXTURE, UV + vec2(near_offset.x, -near_offset.y)).rgb * 0.05;
	glow += texture(TEXTURE, UV + vec2(-near_offset.x, near_offset.y)).rgb * 0.05;
	glow += texture(TEXTURE, UV + vec2(far_offset.x, 0.0)).rgb * 0.045;
	glow += texture(TEXTURE, UV - vec2(far_offset.x, 0.0)).rgb * 0.045;
	glow += texture(TEXTURE, UV + vec2(0.0, far_offset.y)).rgb * 0.045;
	glow += texture(TEXTURE, UV - vec2(0.0, far_offset.y)).rgb * 0.045;
	// Retain a compact hot core while the dual-radius samples create the halo.
	COLOR = vec4((glow + centre * 0.18) * glow_strength, 1.0);
}
