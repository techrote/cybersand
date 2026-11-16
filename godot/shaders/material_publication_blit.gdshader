shader_type texture_blit;
render_mode blend_disabled;

// Fixed custom sampler uses unit1; source0 is a separate owned ordinary dummy.
uniform sampler2DArray staging_array : filter_nearest, repeat_disable;

void blit() {
	// Direct highp vec4 parameters carry exact bounded integer coordinates.
	int packed_height = int(MODULATE.w);
	int layer = packed_height >> 14;
	int copy_height = packed_height & 16383;
	ivec2 local_pixel = ivec2(floor(UV * vec2(MODULATE.z, float(copy_height))));
	ivec2 source_pixel = ivec2(MODULATE.xy) + local_pixel;
	vec2 raw = texelFetch(staging_array, ivec3(source_pixel, layer), 0).rg;
	COLOR0 = vec4(raw, 0.0, 1.0);
}
