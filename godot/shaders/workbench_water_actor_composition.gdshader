shader_type canvas_item;
render_mode unshaded;

// Only explicitly proven current actor parts use this layer. Preserve the
// material framebuffer underneath rather than erasing retained native Water.
uniform sampler2D current_material : filter_nearest, repeat_disable;
uniform sampler2D previous_material : filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(1.0);
uniform vec2 world_origin = vec2(0.0);
uniform vec2 view_size = vec2(1.0);
uniform vec2 overlay_size = vec2(1.0);
uniform bool previous_active = false;
uniform float snapshot_blend : hint_range(0.0, 1.0) = 1.0;
varying vec2 world_position;

void vertex() {
	world_position = world_origin + VERTEX * view_size / overlay_size;
}

void fragment() {
	ivec2 cell = ivec2(floor(world_position));
	if (cell.x < 0 || cell.y < 0 || cell.x >= int(world_size.x) || cell.y >= int(world_size.y)) {
		discard;
	}
	int current_id = int(round(texelFetch(current_material, cell, 0).r * 255.0));
	int previous_id = previous_active ? int(round(texelFetch(previous_material, cell, 0).r * 255.0)) : 0;
	// Cell-centre native geometry and continuous pixel polygons have different
	// fractional borders. Never draw across a hard/other-material border merely
	// because that cell centre lies outside the sampled native footprint.
	if ((current_id != 0 && current_id != 3) || (previous_active && previous_id != 0 && previous_id != 3)) {
		discard;
	}
	float water = current_id == 3 ? 1.0 : 0.0;
	if (previous_active) {
		water = mix(previous_id == 3 ? 1.0 : 0.0, water, snapshot_blend);
	}
	COLOR.a *= mix(1.0, 0.65, water);
}
