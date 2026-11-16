// Exact material lookup shared by terrain, glow, vapour and scene masks.
// Full 2D textures remain the default for existing/standalone shader users.
uniform bool material_tiles_enabled = false;
uniform int material_tile_side = 64;
uniform int material_tile_columns = 1;
uniform vec2 material_texture_size = vec2(1.0);
uniform sampler2DArray current_material_tiles : filter_nearest, repeat_disable;
uniform sampler2DArray previous_material_tiles : filter_nearest, repeat_disable;

vec4 cyber_material_array_sample(sampler2DArray tiles, vec2 uv) {
	// Match nearest, clamp-to-edge sampling of the original finite plane.
	// Mapping takes place in world coordinates, including neighbour reads, so
	// neither padded edge texels nor a neighbouring layer can cross a seam.
	ivec2 pixel = clamp(ivec2(floor(uv * material_texture_size)), ivec2(0), ivec2(material_texture_size) - ivec2(1));
	ivec2 tile = pixel / material_tile_side;
	ivec2 local_pixel = pixel - tile * material_tile_side;
	int layer = tile.y * material_tile_columns + tile.x;
	return texelFetch(tiles, ivec3(local_pixel, layer), 0);
}

vec4 cyber_material_current(sampler2D full_texture, vec2 uv) {
	if (material_tiles_enabled) return cyber_material_array_sample(current_material_tiles, uv);
	return texture(full_texture, uv);
}

vec4 cyber_material_previous(sampler2D full_texture, vec2 uv) {
	if (material_tiles_enabled) return cyber_material_array_sample(previous_material_tiles, uv);
	return texture(full_texture, uv);
}
