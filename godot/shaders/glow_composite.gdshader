shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float glow_strength : hint_range(0.0, 2.0, 0.05) = 0.62;
// The source stays on a world-aligned coarse grid, with guards covering the
// halo footprint and the fractional camera. Reproject only when compositing
// at display resolution, keeping the emission pass small.
// Defaults preserve standalone captures that supply an exact view texture.
uniform vec2 source_uv_offset = vec2(0.0);
uniform vec2 source_uv_scale = vec2(1.0);
uniform bool ambient_sources_absent = false;
uniform sampler2D material_program_lut : filter_nearest, repeat_disable;
varying flat float zero_source;

bool zero_emission_endpoints(int material_id) {
	return all(equal(texelFetch(material_program_lut, ivec2(2, material_id), 0).zw, vec2(0.0)));
}

void vertex() {
	// A certified four-ID source still uses the live appearance program.
	// Test both emission endpoints on the quad, including in-place LUT edits.
	zero_source = float(ambient_sources_absent && zero_emission_endpoints(0)
		&& zero_emission_endpoints(2) && zero_emission_endpoints(3) && zero_emission_endpoints(58));
}

void fragment() {
	if (zero_source > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
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
}
