shader_type texture_blit;
render_mode blend_disabled;

// Each material permanently samples its own independent one-layer array.
// Required ordinary source0 remains a separate owned dummy at unit0.
uniform sampler2DArray staging_array : filter_nearest, repeat_disable;

void blit() {
	// Direct highp vec4 parameters carry exact bounded integer coordinates.
	ivec2 local_pixel = ivec2(floor(UV * MODULATE.zw));
	ivec2 source_pixel = ivec2(MODULATE.xy) + local_pixel;
	vec2 raw = texelFetch(staging_array, ivec3(source_pixel, 0), 0).rg;
	COLOR0 = vec4(raw, 0.0, 1.0);
}
