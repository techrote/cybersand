shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float glow_strength : hint_range(0.0, 2.0, 0.05) = 0.62;
// The source stays on a world-aligned coarse grid, with guards covering the
// halo footprint and the fractional camera. Reproject only when compositing
// at display resolution, keeping the emission pass small.
// Defaults preserve standalone captures that supply an exact view texture.
uniform vec2 source_uv_offset = vec2(0.0);
uniform vec2 source_uv_scale = vec2(1.0);

void fragment() {
	vec2 source_uv = source_uv_offset + UV * source_uv_scale;
	vec2 near_offset = TEXTURE_PIXEL_SIZE * 1.5;
	vec2 far_offset = TEXTURE_PIXEL_SIZE * 4.0;
	vec3 centre = texture(TEXTURE, source_uv).rgb;
	vec3 glow = centre * 0.30;
	glow += texture(TEXTURE, source_uv + vec2(near_offset.x, 0.0)).rgb * 0.08;
	glow += texture(TEXTURE, source_uv - vec2(near_offset.x, 0.0)).rgb * 0.08;
	glow += texture(TEXTURE, source_uv + vec2(0.0, near_offset.y)).rgb * 0.08;
	glow += texture(TEXTURE, source_uv - vec2(0.0, near_offset.y)).rgb * 0.08;
	glow += texture(TEXTURE, source_uv + near_offset).rgb * 0.05;
	glow += texture(TEXTURE, source_uv - near_offset).rgb * 0.05;
	glow += texture(TEXTURE, source_uv + vec2(near_offset.x, -near_offset.y)).rgb * 0.05;
	glow += texture(TEXTURE, source_uv + vec2(-near_offset.x, near_offset.y)).rgb * 0.05;
	glow += texture(TEXTURE, source_uv + vec2(far_offset.x, 0.0)).rgb * 0.045;
	glow += texture(TEXTURE, source_uv - vec2(far_offset.x, 0.0)).rgb * 0.045;
	glow += texture(TEXTURE, source_uv + vec2(0.0, far_offset.y)).rgb * 0.045;
	glow += texture(TEXTURE, source_uv - vec2(0.0, far_offset.y)).rgb * 0.045;
	// Retain a compact hot core while the dual-radius samples create the halo.
	COLOR = vec4((glow + centre * 0.18) * glow_strength, 1.0);
}
