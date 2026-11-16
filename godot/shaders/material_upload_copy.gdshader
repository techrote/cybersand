shader_type texture_blit;
render_mode blend_disabled;

// Material IDs and condition bytes are normalized data, never source colours.
uniform sampler2D patch_source : hint_blit_source0, filter_nearest, repeat_disable;

void blit() {
	COLOR0 = texture(patch_source, UV);
}
