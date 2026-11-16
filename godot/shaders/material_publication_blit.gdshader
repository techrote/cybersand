shader_type texture_blit;
render_mode blend_disabled;
uniform sampler2D source_texture : hint_blit_source0, filter_nearest, repeat_disable;
void blit() {
    ivec2 local_pixel = ivec2(floor(UV * MODULATE.zw));
    vec2 raw = texelFetch(source_texture, ivec2(MODULATE.xy) + local_pixel, 0).rg;
    COLOR0 = vec4(raw, 0.0, 1.0);
}
