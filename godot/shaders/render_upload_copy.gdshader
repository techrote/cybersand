shader_type texture_blit;
render_mode blend_disabled;

// Material bytes are normalized data. No source_color hint, blending,
// modulation, mipmaps or colour conversion belongs in this copy.
uniform sampler2D patch_source : hint_blit_source0, filter_nearest, repeat_disable;

void blit() {
	COLOR0 = texture(patch_source, UV);
}
