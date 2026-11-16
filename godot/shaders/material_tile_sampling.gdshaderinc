// Exact material lookup shared by terrain, glow, vapour and scene masks.
// Full 2D textures remain the default for existing/standalone shader users.
uniform bool material_tiles_enabled = false;
uniform int material_tile_side = 64;
uniform float material_inverse_tile_side = 0.015625;
uniform int material_tile_columns = 1;
uniform vec2 material_texture_size = vec2(1.0);
uniform sampler2DArray current_material_tiles : filter_nearest, repeat_disable;
uniform sampler2DArray previous_material_tiles : filter_nearest, repeat_disable;

vec4 cyber_material_array_sample(sampler2DArray tiles, vec2 uv) {
	// Match nearest, clamp-to-edge sampling of the original finite plane.
	// Mapping takes place in world coordinates, including neighbour reads, so
	// neither padded edge texels nor a neighbouring layer can cross a seam.
	// Validated power-of-two sides make every operation below binary-exact:
	// the local sample stays at its texel centre and the layer is an integer.
	// Use the normalized nearest sampler path without repeated integer
	// division and integer texelFetch addressing for every neighbour.
	vec2 pixel = clamp(floor(uv * material_texture_size), vec2(0.0), material_texture_size - vec2(1.0));
	vec2 tile = floor(pixel * material_inverse_tile_side);
	vec2 local_uv = (pixel - tile * float(material_tile_side) + vec2(0.5)) * material_inverse_tile_side;
	float layer = tile.y * float(material_tile_columns) + tile.x;
	return texture(tiles, vec3(local_uv, layer));
}

vec4 cyber_material_current(sampler2D full_texture, vec2 uv) {
#ifdef CYBER_MATERIAL_TILES
	return cyber_material_array_sample(current_material_tiles, uv);
#else
	if (material_tiles_enabled) return cyber_material_array_sample(current_material_tiles, uv);
	return texture(full_texture, uv);
#endif
}

vec4 cyber_material_previous(sampler2D full_texture, vec2 uv) {
#ifdef CYBER_MATERIAL_TILES
	return cyber_material_array_sample(previous_material_tiles, uv);
#else
	if (material_tiles_enabled) return cyber_material_array_sample(previous_material_tiles, uv);
	return texture(full_texture, uv);
#endif
}
