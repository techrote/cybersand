shader_type canvas_item;
render_mode unshaded;

// Rendering has its own view of the world. Panning changes only these uniforms;
// it does not move or copy the cellular backing store.
uniform vec2 world_size_px = vec2(1024.0, 1024.0);
uniform vec2 view_size_px = vec2(320.0, 180.0);
// Aspect-fitted logical camera rectangle inside the TextureRect, expressed as
// x/y origin plus width/height in local UV space. The same rectangle is used
// by main.gd for pointer-to-world mapping.
uniform vec4 view_rect_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 camera_origin_px = vec2(0.0);
uniform vec2 player_origin_px = vec2(150.0, 145.0);
uniform vec2 player_size_px = vec2(8.0, 14.0);
uniform vec4 player_colour : source_color = vec4(0.12, 1.0, 0.88, 1.0);
// xyz/w layout: centre.xy and full size.zw. Scene-tree rigid bodies stay out of
// the cell texture; rendering composites their current transforms independently.
uniform vec4 rigid_body_data_0 = vec4(-1000.0, -1000.0, 8.0, 14.0);
uniform vec4 rigid_body_data_1 = vec4(-1000.0, -1000.0, 8.0, 14.0);
uniform vec4 rigid_body_data_2 = vec4(-1000.0, -1000.0, 8.0, 14.0);
uniform float rigid_body_rotation_0 = 0.0;
uniform float rigid_body_rotation_1 = 0.0;
uniform float rigid_body_rotation_2 = 0.0;
uniform vec4 rigid_body_colour : source_color = vec4(0.95, 0.12, 0.16, 1.0);
// Alias of the CanvasItem TEXTURE. A named sampler lets bounded helper
// functions inspect four neighbours without a second image or upload.
uniform sampler2D current_world_texture : filter_nearest, repeat_disable;
uniform sampler2D previous_world_texture : filter_nearest, repeat_disable;
uniform sampler2D material_lut : source_color, filter_nearest, repeat_disable;
uniform sampler2D material_program_lut : filter_nearest, repeat_disable;
uniform vec2 material_lut_size = vec2(64.0, 256.0);
uniform float condition_projection_enabled = 0.0;
// 0 preserves the reference stable dither, 1 selects fixed four-level
// coverage, and 2 adds deterministic local interface orientation.
uniform float water_presentation_mode : hint_range(0.0, 2.0, 1.0) = 0.0;
uniform float snapshot_blend : hint_range(0.0, 1.0, 0.01) = 1.0;
// Negative keeps the engine TIME. Capture fixtures set the same non-negative
// sample on this and the emission pass so paired images share one phase.
uniform float presentation_time_override = -1.0;

float presentation_time() {
	return presentation_time_override >= 0.0 ? presentation_time_override : TIME;
}

// Oil's wave phase rate in cycles per second. Decorative presentation phase,
// not measured flow; it equals the value the shared wet finish previously
// derived for Oil from its ID so the approved wave look is unchanged.
const float OIL_WAVE_RATE = 0.045 + 1.0 * 0.012;

float cheap_hash(vec2 value) {
	// Arithmetic-only render hash: cheaper than the previous transcendental
	// hash and stable for a fixed world coordinate/material on one GPU.
	vec3 parts = fract(value.xyx * 0.1031);
	parts += dot(parts, parts.yzx + vec3(33.33));
	return fract((parts.x + parts.y) * parts.z);
}

float stable_pixel_hash(vec2 pixel, int material_id) {
	return cheap_hash(pixel + vec2(float(material_id) * 17.17, float(material_id) * 3.71));
}

float triangle_wave(float value) {
	return abs(fract(value) * 2.0 - 1.0);
}

float manufactured_glint(vec2 pixel, float speed) {
	float seed = cheap_hash(pixel);
	float sweep = 1.0 - triangle_wave(
		presentation_time() * speed + seed + (pixel.x - pixel.y * 0.21) / 43.0
	);
	return step(0.982, seed) * smoothstep(0.86, 1.0, sweep);
}

// Smooth hashed value noise and a three-octave sum. Arithmetic only; every
// lattice is world-anchored, so texture never swims with the camera.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = cheap_hash(i);
	float b = cheap_hash(i + vec2(1.0, 0.0));
	float c = cheap_hash(i + vec2(0.0, 1.0));
	float d = cheap_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3(vec2 p) {
	return value_noise(p) * 0.55
		+ value_noise(p * 2.03 + vec2(17.1, 3.7)) * 0.30
		+ value_noise(p * 4.11 + vec2(5.3, 29.9)) * 0.15;
}

// Black-body style ramp for presentation heat 0..1 (ember red to white).
// Values stay at or below 1 so hot cores keep structure instead of clipping.
vec3 heat_ramp(float heat) {
	vec3 colour = mix(vec3(0.30, 0.025, 0.01), vec3(0.95, 0.26, 0.03), smoothstep(0.0, 0.40, heat));
	colour = mix(colour, vec3(1.0, 0.70, 0.12), smoothstep(0.35, 0.75, heat));
	return mix(colour, vec3(1.0, 0.97, 0.82), smoothstep(0.82, 1.0, heat));
}

// Sparse pixel particles. One candidate per world-lattice cell of size
// `cell` in the moving coordinate p; x = hit (0/1), y = that particle's hash.
// Motion comes from the caller offsetting p by velocity * time.
vec2 lattice_particle(vec2 p, float cell, float density, float salt) {
	vec2 id = floor(p / cell);
	float h = cheap_hash(id + vec2(salt, salt * 1.7));
	vec2 position = floor(vec2(
		cheap_hash(id + vec2(salt + 3.1, 1.3)),
		cheap_hash(id + vec2(5.9, salt + 7.7))
	) * cell);
	vec2 local = floor(p - id * cell);
	float hit = step(1.0 - density, h)
		* step(abs(local.x - position.x) + abs(local.y - position.y), 0.5);
	return vec2(hit, h);
}

int sampled_material_id(vec2 pixel, bool previous_snapshot) {
	vec2 clamped_pixel = clamp(floor(pixel), vec2(0.0), world_size_px - vec2(1.0));
	vec2 world_uv = (clamped_pixel + vec2(0.5)) / world_size_px;
	// Relief reads the same snapshot as the material being shaded, so the old
	// side of a crossfade keeps its own neighbourhood. Same four reads.
	float stored = previous_snapshot
		? texture(previous_world_texture, world_uv).r
		: texture(current_world_texture, world_uv).r;
	return int(floor(stored * 255.0 + 0.5));
}

bool is_relief_solid(int material_id) {
	return material_id == 1
		|| material_id == 7
		|| material_id == 9
		|| material_id == 13
		|| material_id == 28
		|| material_id == 29
		|| material_id == 31
		|| material_id == 35
		|| (material_id >= 38 && material_id <= 80);
}

bool is_liquid_surface(int material_id) {
	return material_id == 3
		|| material_id == 8
		|| material_id == 12
		|| material_id == 16
		|| material_id == 20
		|| material_id == 21
		|| material_id == 24
		|| material_id == 30
		|| material_id == 32
		|| material_id == 33
		|| material_id == 36;
}

float boundary_strength(int material_id, int neighbour_id) {
	if (neighbour_id == material_id) return 0.0;
	if (
		neighbour_id == 0
		|| neighbour_id == 4
		|| neighbour_id == 6
		|| neighbour_id == 22
	) return 1.0;
	return 0.34;
}

vec4 apply_neighbour_relief(vec4 colour, int material_id, ivec4 neighbours) {
	int above_id = neighbours.x;
	int below_id = neighbours.y;
	int left_id = neighbours.z;
	int right_id = neighbours.w;

	if (is_relief_solid(material_id)) {
		float top_edge = boundary_strength(material_id, above_id);
		float left_edge = boundary_strength(material_id, left_id);
		float bottom_edge = boundary_strength(material_id, below_id);
		float right_edge = boundary_strength(material_id, right_id);
		float bevel_light = top_edge * 0.13 + left_edge * 0.075;
		float bevel_shadow = bottom_edge * 0.15 + right_edge * 0.085;
		colour.rgb *= 1.0 + bevel_light - bevel_shadow;
		colour.rgb += vec3(0.045, 0.052, 0.060) * (top_edge + left_edge) * 0.5;
		return colour;
	}

	if (is_liquid_surface(material_id)) {
		float exposed_surface = boundary_strength(material_id, above_id);
		float side_lip = max(
			boundary_strength(material_id, left_id),
			boundary_strength(material_id, right_id)
		);
		colour.rgb += vec3(0.16, 0.22, 0.27) * exposed_surface * 0.28;
		colour.rgb *= 1.0 + side_lip * 0.025;
		return colour;
	}

	// A one-cell ambient-contact shadow grounds overhangs without a depth
	// buffer. It is derived from the same immutable material texture.
	if (material_id == 0 && is_relief_solid(above_id)) {
		colour.rgb *= 0.68;
	}
	// Soft ambient occlusion from the remaining solid neighbours.
	if (material_id == 0) {
		float occluders = float(is_relief_solid(below_id)) + float(is_relief_solid(left_id))
			+ float(is_relief_solid(right_id));
		colour.rgb *= 1.0 - occluders * 0.09;
	}
	return colour;
}

bool is_emitter(int id) {
	return id == 5 || id == 6 || id == 8 || id == 34 || id == 36 || (id >= 77 && id <= 80);
}

vec3 emitter_light(int id) {
	if (id == 6) return vec3(1.0, 0.55, 0.15);
	if (id == 8) return vec3(1.0, 0.35, 0.08);
	if (id == 36) return vec3(1.0, 0.68, 0.30);
	if (id == 34) return vec3(1.0, 0.92, 0.45);
	if (id == 77) return vec3(0.20, 1.0, 0.92);
	if (id == 78) return vec3(1.0, 0.25, 0.75);
	if (id == 79) return vec3(1.0, 0.70, 0.18);
	if (id == 80) return vec3(0.85, 0.92, 1.0);
	if (id == 5) return vec3(0.60, 0.25, 0.85);
	return vec3(0.0);
}

bool is_water_like(int id) {
	return id == 3 || id == 24 || id == 21 || id == 9;
}

bool is_fuel(int id) {
	return id == 7 || id == 11 || id == 16 || id == 27 || id == 46 || id == 47 || id == 26;
}

// Volume, edge and contact shading from the shared neighbour IDs plus, for
// liquids only, three further reads straight up to estimate depth below the
// surface. Presentation only: nothing here feeds back into the simulation.
vec4 apply_volume_and_contact(
	vec4 colour,
	int material_id,
	vec2 pixel,
	ivec4 neighbours,
	bool previous_snapshot,
	float condition
) {
	float t = presentation_time();
	int above_id = neighbours.x;
	float flick = step(0.55, value_noise(pixel * 0.8 + vec2(t * 7.0, -t * 5.0)));

	if (is_liquid_surface(material_id)) {
		float depth = float(above_id == material_id)
			+ float(sampled_material_id(pixel + vec2(0.0, -3.0), previous_snapshot) == material_id)
			+ float(sampled_material_id(pixel + vec2(0.0, -6.0), previous_snapshot) == material_id)
			+ float(sampled_material_id(pixel + vec2(0.0, -10.0), previous_snapshot) == material_id);
		depth *= 0.25;
		bool exposed = above_id != material_id && !is_liquid_surface(above_id);
		if (material_id == 8 || material_id == 36) {
			// Molten: hotter with depth, darker skin and flaring bursts at the top.
			colour.rgb *= mix(0.88, 1.18, depth);
			if (exposed) {
				float skin = value_noise(vec2(pixel.x / 2.0 - t * 0.6, t * 0.4));
				colour.rgb = mix(colour.rgb, vec3(0.22, 0.06, 0.03), smoothstep(0.35, 0.7, skin) * 0.55);
				colour.rgb = mix(colour.rgb, vec3(1.0, 0.92, 0.6), step(0.82, skin) * flick);
			}
		} else {
			vec3 deep = material_id == 3 || material_id == 24
				? vec3(0.02, 0.08, 0.22) : colour.rgb * 0.45;
			colour.rgb = mix(colour.rgb * mix(1.06, 0.72, depth), deep, depth * 0.30);
			if (exposed) {
				float froth = value_noise(vec2(pixel.x / 1.7 - t * 1.8, t * 0.6 + pixel.y));
				vec3 froth_colour = material_id == 12 ? vec3(0.92, 1.0, 0.45)
					: material_id == 32 ? vec3(0.55, 1.0, 0.45)
					: material_id == 16 ? vec3(0.55, 0.45, 0.75)
					: material_id == 33 ? vec3(0.95, 0.97, 1.0)
					: vec3(0.85, 0.95, 1.0);
				colour.rgb = mix(colour.rgb, froth_colour, smoothstep(0.55, 0.85, froth) * 0.65);
			}
		}
	}

	// Gas and foam volumes thin out at their boundaries instead of ending in
	// hard squares.
	if (material_id == 4 || material_id == 22 || material_id == 37 || material_id == 6) {
		float same = float(neighbours.x == material_id) + float(neighbours.y == material_id)
			+ float(neighbours.z == material_id) + float(neighbours.w == material_id);
		float edge = 1.0 - same * 0.25;
		if (material_id == 6) {
			colour.rgb *= 1.0 - edge * 0.22;
		} else {
			colour.a *= 1.0 - edge * 0.55;
			if (material_id == 37) colour.rgb += vec3(0.10) * edge;
		}
	}

	// Contact reactions between neighbouring materials.
	bool touches_water = is_water_like(neighbours.x) || is_water_like(neighbours.y)
		|| is_water_like(neighbours.z) || is_water_like(neighbours.w);
	bool touches_hot = neighbours.x == 8 || neighbours.y == 8 || neighbours.z == 8
		|| neighbours.w == 8 || neighbours.x == 36 || neighbours.y == 36
		|| neighbours.z == 36 || neighbours.w == 36 || neighbours.y == 6;
	if ((material_id == 8 || material_id == 36) && touches_water) {
		colour.rgb = mix(colour.rgb, vec3(1.0, 0.97, 0.88), flick * 0.75);
	}
	if (is_water_like(material_id) && touches_hot) {
		float boil = step(0.5, value_noise(pixel * 1.3 + vec2(0.0, t * 9.0)));
		colour.rgb = mix(colour.rgb, vec3(0.92, 0.97, 1.0), boil * 0.7);
	}
	if (material_id == 12 || material_id == 32) {
		bool etching = is_relief_solid(neighbours.x) || is_relief_solid(neighbours.y)
			|| is_relief_solid(neighbours.z) || is_relief_solid(neighbours.w);
		if (etching) {
			float fizz = step(0.72, value_noise(pixel * 1.6 + vec2(t * 8.0, t * 3.0)));
			colour.rgb = mix(colour.rgb, vec3(0.95, 1.0, 0.55), fizz * 0.7);
		}
	}
	if (material_id == 6 && (is_fuel(neighbours.x) || is_fuel(neighbours.y)
			|| is_fuel(neighbours.z) || is_fuel(neighbours.w))) {
		colour.rgb = mix(colour.rgb, heat_ramp(0.92), 0.35 + flick * 0.25);
	}

	// Emitters rim-light the surfaces next to them.
	if (is_relief_solid(material_id) || material_id == 2 || material_id == 13 || material_id == 23) {
		vec3 light = emitter_light(neighbours.x) + emitter_light(neighbours.y)
			+ emitter_light(neighbours.z) + emitter_light(neighbours.w);
		colour.rgb += light * colour.rgb * 0.75 + light * 0.10;
	}
	return colour;
}

vec4 apply_material_flair(
	vec4 colour,
	int material_id,
	int flair,
	vec2 pixel,
	float condition
) {
	if (flair == 0) return colour;

	if (flair == 1) { // dressed masonry and brick
		float row = floor(pixel.y / 4.0);
		float local_x = mod(pixel.x + mod(row, 2.0) * 4.0, 8.0);
		float local_y = mod(pixel.y, 4.0);
		float seam = max(1.0 - step(0.66, local_x), 1.0 - step(0.72, local_y));
		float face = 0.94 + cheap_hash(floor(vec2((pixel.x + mod(row, 2.0) * 4.0) / 8.0, row))) * 0.15;
		colour.rgb *= mix(face, 0.47, seam);
		float chip = step(0.975, cheap_hash(pixel + vec2(71.0, 13.0))) * (1.0 - seam);
		float grime = value_noise(pixel / 11.0);
		colour.rgb *= mix(1.0, 0.62, chip) * (0.92 + grime * 0.12);
		return colour;
	}

	if (flair == 2) { // cobble/fieldstone
		float row = floor(pixel.y / 4.0);
		vec2 local = vec2(
			mod(pixel.x + mod(row, 2.0) * 2.5, 5.0) / 5.0,
			mod(pixel.y, 4.0) / 4.0
		) - vec2(0.5);
		float edge = smoothstep(0.36, 0.53, length(local));
		float stone = 0.91 + cheap_hash(floor(vec2(pixel.x / 5.0, row))) * 0.20;
		colour.rgb *= mix(stone, 0.45, edge);
		return colour;
	}

	if (flair == 3) { // plaster/daub
		float broad = cheap_hash(floor(pixel / 7.0));
		float fine = cheap_hash(pixel);
		float chip = step(0.965, fine);
		colour.rgb *= 0.88 + broad * 0.20;
		colour.rgb = mix(colour.rgb, colour.rgb * 0.48, chip);
		return colour;
	}

	if (flair == 4) { // timber grain and rare knots
		float lane = floor(pixel.y / 3.0);
		float grain = triangle_wave((pixel.x + cheap_hash(vec2(lane, 9.0)) * 9.0) / 11.0);
		float knot = step(0.978, cheap_hash(floor(pixel / vec2(9.0, 4.0))));
		colour.rgb *= 0.76 + grain * 0.34;
		colour.rgb *= mix(1.0, 0.54 + triangle_wave(pixel.x / 3.0) * 0.18, knot);
		if (condition > 0.02) { // burn progress: ember cracks and char
			float t = presentation_time();
			float vein = abs(value_noise(pixel / 6.0) - 0.5) + abs(value_noise(pixel / 2.5 + vec2(13.0)) - 0.5) * 0.35;
			float cracks = 1.0 - smoothstep(0.02, 0.07, vein);
			float pulse = 0.55 + 0.45 * value_noise(pixel / 4.0 + vec2(t * 1.1, t * 0.5));
			float burn = smoothstep(0.02, 0.6, condition);
			vec3 char_colour = vec3(0.07, 0.05, 0.045) * (0.8 + cheap_hash(floor(pixel / 2.0)) * 0.4);
			colour.rgb = mix(colour.rgb, char_colour, burn * 0.80);
			colour.rgb = mix(colour.rgb, heat_ramp(0.30 + pulse * 0.55), cracks * burn * pulse);
		}
		return colour;
	}

	if (flair == 5) { // thatch fibres
		float fibre = triangle_wave((pixel.x + pixel.y * 1.65) / 3.0);
		float course = cheap_hash(floor(pixel / vec2(5.0, 3.0)));
		colour.rgb *= 0.72 + fibre * 0.28 + course * 0.15;
		if (condition > 0.02) { // burn progress: ember cracks and char
			float t = presentation_time();
			float vein = abs(value_noise(pixel / 6.0) - 0.5) + abs(value_noise(pixel / 2.5 + vec2(13.0)) - 0.5) * 0.35;
			float cracks = 1.0 - smoothstep(0.02, 0.07, vein);
			float pulse = 0.55 + 0.45 * value_noise(pixel / 4.0 + vec2(t * 1.1, t * 0.5));
			float burn = smoothstep(0.02, 0.6, condition);
			vec3 char_colour = vec3(0.07, 0.05, 0.045) * (0.8 + cheap_hash(floor(pixel / 2.0)) * 0.4);
			colour.rgb = mix(colour.rgb, char_colour, burn * 0.80);
			colour.rgb = mix(colour.rgb, heat_ramp(0.30 + pulse * 0.55), cracks * burn * pulse);
		}
		return colour;
	}

	if (flair == 6) { // overlapping terracotta roof tiles
		float row = floor(pixel.y / 4.0);
		float local_x = mod(pixel.x + mod(row, 2.0) * 3.0, 6.0);
		float local_y = mod(pixel.y, 4.0);
		float seam = max(1.0 - step(0.65, local_y), 1.0 - step(0.62, local_x));
		float lip = smoothstep(2.4, 3.8, local_y);
		colour.rgb *= mix(1.04 - lip * 0.18, 0.46, seam);
		return colour;
	}

	if (flair == 7) { // slate courses
		float row = floor(pixel.y / 3.0);
		float local_x = mod(pixel.x + mod(row, 2.0) * 3.5, 7.0);
		float seam = max(1.0 - step(0.55, local_x), 1.0 - step(0.55, mod(pixel.y, 3.0)));
		colour.rgb *= mix(0.88 + cheap_hash(vec2(floor(pixel.x / 7.0), row)) * 0.24, 0.48, seam);
		return colour;
	}

	if (flair == 8) { // hammered/aged non-ferrous metal
		float hammer = cheap_hash(floor(pixel / 2.0));
		colour.rgb *= 0.84 + hammer * 0.28;
		return colour;
	}

	if (flair == 9) { // stained-glass mosaic with dark leading
		vec2 tile = floor(pixel / 5.0);
		vec2 local = mod(pixel, 5.0);
		float leading = max(1.0 - step(0.72, local.x), 1.0 - step(0.72, local.y));
		float choice = cheap_hash(tile);
		vec3 cyan = vec3(0.10, 0.78, 0.92);
		vec3 magenta = vec3(0.82, 0.14, 0.65);
		vec3 amber = vec3(0.95, 0.55, 0.08);
		vec3 pane = mix(cyan, magenta, step(0.34, choice));
		pane = mix(pane, amber, step(0.70, choice));
		colour.rgb = mix(pane * (0.82 + cheap_hash(tile + vec2(7.0)) * 0.25), vec3(0.035), leading);
		return colour;
	}

	if (flair == 10) { // packed earth
		float clod = cheap_hash(floor(pixel / 3.0));
		float grit = step(0.93, cheap_hash(pixel));
		colour.rgb *= 0.78 + clod * 0.38;
		colour.rgb = mix(colour.rgb, colour.rgb * 0.55, grit);
		return colour;
	}

	if (flair == 11) { // concrete aggregate
		float cloud = cheap_hash(floor(pixel / 6.0));
		float aggregate = cheap_hash(pixel);
		colour.rgb *= 0.86 + cloud * 0.22;
		colour.rgb += vec3((step(0.94, aggregate) - step(aggregate, 0.035)) * 0.12);
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(value_noise(pixel / 9.0) - 0.5));
		colour.rgb *= 1.0 - crack * 0.30;
		return colour;
	}

	if (flair == 12) { // dry asphalt
		float grain = cheap_hash(pixel);
		float pebble = step(0.94, grain);
		colour.rgb *= 0.78 + grain * 0.30;
		colour.rgb += vec3(pebble * 0.10);
		return colour;
	}

	if (flair == 13) { // Oil: viscous wave film and sparse sheen (owner-approved)
		float seed = cheap_hash(pixel);
		float flow_phase = presentation_time() * OIL_WAVE_RATE;
		float sweep = 1.0 - triangle_wave(presentation_time() * 0.22 + seed +
			(pixel.x + pixel.y * 0.35) / 37.0);
		float sparkle = step(0.972, seed) * smoothstep(0.82, 1.0, sweep);
		float streak = smoothstep(0.82, 0.98, triangle_wave(
			(pixel.x + pixel.y * 0.24) / 19.0 + flow_phase
		));
		float cross_flow = smoothstep(0.76, 0.98, triangle_wave(
			(pixel.y - pixel.x * 0.12) / 27.0 - flow_phase * 0.63
		));
		colour.rgb *= 0.75 + streak * 0.17 + cross_flow * 0.10;
		colour.rgb += vec3(0.58, 0.72, 0.82) * sparkle;
		// Thin-film iridescence riding the approved wave crests.
		float film = value_noise(pixel / 9.0 + vec2(presentation_time() * 0.05, 0.0));
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (film * 1.6 + vec3(0.0, 0.33, 0.67)));
		colour.rgb += rainbow * (0.045 + streak * 0.22 + cross_flow * 0.12);
		if (condition > 0.02) { // burning Oil: licking surface flames
			float lick = fbm3(vec2(pixel.x / 3.0, pixel.y / 2.0 + presentation_time() * 2.6));
			float burn = smoothstep(0.45, 0.85, lick) * smoothstep(0.02, 0.5, condition);
			colour.rgb = mix(colour.rgb, heat_ramp(0.45 + lick * 0.5), burn);
		}
		return colour;
	}

	if (flair == 14 || flair == 15) { // plate seams, rivets, scratches, optional paint chips
		vec2 local = mod(pixel, 12.0);
		float seam = max(1.0 - step(0.55, local.x), 1.0 - step(0.55, local.y));
		float rivet = 1.0 - step(0.92, length(local - vec2(1.15)));
		float brushed = triangle_wave((pixel.x + pixel.y * 0.15) / 8.0);
		float glint = manufactured_glint(pixel, flair == 15 ? 0.18 : 0.28);
		colour.rgb *= mix(0.88 + brushed * 0.18, 0.46, seam);
		colour.rgb += vec3(rivet * 0.26);
		colour.rgb += vec3(glint * (1.0 - seam) * (flair == 15 ? 0.24 : 0.46));
		float scratch = step(0.97, triangle_wave((pixel.x * 0.31 - pixel.y) / 7.0 + cheap_hash(floor(pixel / 12.0)) * 5.0))
			* step(0.6, cheap_hash(floor(pixel / vec2(5.0, 3.0)) + vec2(3.0)));
		colour.rgb += vec3(0.07) * scratch * (1.0 - seam);
		if (flair == 15) {
			float chip = step(0.965, cheap_hash(pixel + vec2(19.0, 4.0)));
			colour.rgb = mix(colour.rgb, vec3(0.31, 0.34, 0.35), chip);
		}
		return colour;
	}

	if (flair == 16) { // corrugated steel
		float ridge = triangle_wave(pixel.x / 4.0);
		float joint = 1.0 - step(0.55, mod(pixel.y, 16.0));
		float glint = manufactured_glint(pixel, 0.24) * smoothstep(0.62, 1.0, ridge);
		colour.rgb *= 0.62 + (1.0 - ridge) * 0.58;
		colour.rgb *= mix(1.0, 0.58, joint);
		colour.rgb += vec3(glint * (1.0 - joint) * 0.38);
		return colour;
	}

	if (flair == 17) { // rust scale and pits
		float scale = cheap_hash(floor(pixel / 3.0));
		float pit = step(0.93, cheap_hash(pixel + vec2(31.0, 11.0)));
		colour.rgb *= 0.66 + scale * 0.52;
		colour.rgb *= mix(1.0, 0.43, pit);
		return colour;
	}

	if (flair == 18) { // industrial grating
		vec2 local = mod(pixel, 4.0);
		float rail = max(1.0 - step(0.82, local.x), 1.0 - step(0.82, local.y));
		colour.rgb *= mix(0.20, 1.18, rail);
		return colour;
	}

	if (flair == 19) { // chainlink diamonds
		float first = abs(mod(pixel.x + pixel.y, 6.0) - 3.0);
		float second = abs(mod(pixel.x - pixel.y, 6.0) - 3.0);
		float wire = 1.0 - step(0.82, min(first, second));
		colour.rgb *= mix(0.18, 1.22, wire);
		return colour;
	}

	if (flair == 20) { // horizontal pipe highlight and coupling bands
		float curve = 1.0 - triangle_wave(pixel.y / 8.0);
		float coupling = 1.0 - step(0.85, mod(pixel.x, 16.0));
		float glint = manufactured_glint(pixel, 0.32) * smoothstep(0.72, 1.0, curve);
		colour.rgb *= 0.58 + curve * 0.62;
		colour.rgb = mix(colour.rgb, colour.rgb * 0.58, coupling);
		colour.rgb += vec3(glint * (1.0 - coupling) * 0.48);
		return colour;
	}

	if (flair == 21) { // glazed ceramic tiles
		vec2 local = mod(pixel, 6.0);
		float grout = max(1.0 - step(0.72, local.x), 1.0 - step(0.72, local.y));
		float shine = (1.0 - step(1.5, local.x)) * (1.0 - step(1.5, local.y));
		colour.rgb *= mix(1.02, 0.55, grout);
		colour.rgb += vec3(shine * (1.0 - grout) * 0.18);
		return colour;
	}

	if (flair == 22) { // glass sheen without scene-dependent refraction
		// World-anchored and time-independent: installed glazing is still
		// scenery, and a sub-pixel travelling line steps visibly.
		float band = 1.0 - triangle_wave((pixel.x + pixel.y * 0.72) / 13.0);
		float edge = smoothstep(0.90, 1.0, band);
		colour.rgb += vec3(0.30, 0.48, 0.55) * edge;
		return colour;
	}

	if (flair == 23) { // stippled rubber
		float stipple = cheap_hash(pixel);
		colour.rgb *= 0.76 + stipple * 0.25;
		return colour;
	}

	if (flair == 24) { // colour-coded cable bundle
		float lane = mod(pixel.y, 5.0);
		vec3 stripe = mix(vec3(0.08, 0.72, 0.88), vec3(0.92, 0.18, 0.50), step(1.7, lane));
		stripe = mix(stripe, vec3(0.95, 0.64, 0.09), step(3.4, lane));
		float jacket = 0.72 + (1.0 - triangle_wave(pixel.x / 9.0)) * 0.28;
		colour.rgb = mix(colour.rgb, stripe * jacket, 0.68);
		return colour;
	}

	if (flair == 25) { // fibrous insulation
		float fibre = triangle_wave((pixel.x * 1.7 - pixel.y) / 4.0);
		float voids = step(0.95, cheap_hash(pixel));
		colour.rgb *= 0.72 + fibre * 0.32;
		colour.rgb *= mix(1.0, 0.44, voids);
		return colour;
	}

	if (flair == 26) { // diagonal safety stripes
		float stripe = step(0.5, fract((pixel.x + pixel.y) / 8.0));
		colour.rgb = mix(vec3(0.045, 0.05, 0.055), colour.rgb * 1.08, stripe);
		return colour;
	}

	if (flair == 27) { // neon tube pulse with rare deterministic ballast fault
		float seed = cheap_hash(floor(pixel / 8.0));
		float pulse = 0.94 + (1.0 - triangle_wave(presentation_time() * 0.55 + seed)) * 0.08;
		float fault = step(0.988, cheap_hash(vec2(seed * 91.0, floor(presentation_time() * 2.0))));
		float travelling = smoothstep(0.82, 1.0, 1.0 - triangle_wave(
			pixel.x / 31.0 - presentation_time() * 0.34 + seed
		));
		colour.rgb *= pulse * mix(1.0, 0.64, fault);
		colour.rgb += colour.rgb * travelling * 0.12;
		// Rebuild from hue so HDR-bright tubes keep striations instead of clipping.
		float tube = 1.0 - triangle_wave(pixel.y / 3.0);
		float plasma = value_noise(vec2(pixel.x / 3.0 - presentation_time() * 5.0, pixel.y * 0.7));
		vec3 hue = colour.rgb / max(max(colour.r, max(colour.g, colour.b)), 0.001);
		colour.rgb = hue * (0.55 + tube * 0.33 + plasma * 0.14);
		colour.rgb = mix(colour.rgb, vec3(1.0), smoothstep(0.80, 1.0, tube) * 0.50);
		return colour;
	}

	if (flair == 28) { // LED panel separators and quiet scan
		vec2 local = mod(pixel, 3.0);
		float diode = step(0.62, local.x) * step(0.62, local.y);
		float scan = 0.90 + 0.10 * (1.0 - triangle_wave(presentation_time() * 0.30 + pixel.y / 18.0));
		float refresh = smoothstep(0.90, 1.0, 1.0 - triangle_wave(
			presentation_time() * 0.22 + (pixel.x + pixel.y) / 41.0
		));
		colour.rgb *= mix(0.28, scan + refresh * 0.12, diode);
		colour.rgb = min(colour.rgb, vec3(1.0)) * mix(0.82, 1.0, diode);
		colour.rgb += vec3(0.10) * diode * value_noise(pixel / 2.0 + vec2(presentation_time() * 0.8));
		return colour;
	}

	if (flair == 29) { // water micro-highlights
		float seed = cheap_hash(pixel);
		float sweep = 1.0 - triangle_wave(presentation_time() * 0.18 + seed + pixel.x / 29.0);
		float glint = step(0.982, seed) * smoothstep(0.86, 1.0, sweep);
		float ripple = smoothstep(0.78, 0.98, triangle_wave(
			(pixel.x + pixel.y * 0.22) / 21.0 + presentation_time() * 0.075
		));
		colour.rgb *= 0.91 + ripple * 0.13;
		colour.rgb += vec3(0.32, 0.56, 0.75) * glint;
		if (material_id == 24) { // Brine: Water family with fixed pale salt motes
			float salt = step(0.972, cheap_hash(pixel + vec2(53.0, 11.0)));
			colour.rgb = mix(colour.rgb, vec3(0.84, 0.90, 0.88), salt * 0.40);
		}
		float caustic_a = value_noise(pixel / 6.0 + vec2(presentation_time() * 0.21, presentation_time() * 0.13));
		float caustic_b = value_noise(pixel / 7.5 - vec2(presentation_time() * 0.17, -presentation_time() * 0.09) + vec2(9.1));
		float caustic = 1.0 - smoothstep(0.0, 0.11, abs(caustic_a - caustic_b));
		colour.rgb += vec3(0.16, 0.30, 0.38) * caustic;
		vec2 bubble = lattice_particle(pixel + vec2(sin(presentation_time() * 1.3 + pixel.y * 0.4) * 0.6,
			presentation_time() * 7.0), 8.0, 0.32, 41.0);
		colour.rgb = mix(colour.rgb, vec3(0.70, 0.88, 1.0), bubble.x * 0.55);
		return colour;
	}

	if (flair == 30) { // Fire: rising flame tongues, structured hot core, flicking sparks
		float t = presentation_time();
		float tongue = fbm3(vec2(pixel.x / 4.0, pixel.y / 2.6 + t * 3.4));
		float shear = value_noise(vec2(pixel.x / 2.0 + t * 0.7, pixel.y / 5.0 + t * 2.1));
		float heat = clamp(condition * 0.78 + (tongue - 0.5) * 0.95 + (shear - 0.5) * 0.25, 0.0, 1.0);
		colour.rgb = heat_ramp(heat);
		colour.a = smoothstep(0.04, 0.32, heat) * 0.95 + 0.05;
		vec2 spark = lattice_particle(pixel + vec2(sin(t * 3.0 + pixel.y) * 0.7, t * 22.0), 5.0, 0.22, 13.0);
		float flick = 0.5 + 0.5 * sin(t * 17.0 + spark.y * 50.0);
		colour.rgb = mix(colour.rgb, vec3(1.0, 0.95, 0.70), spark.x * flick);
		colour.a = max(colour.a, spark.x * flick);
		return colour;
	}

	if (flair == 31) { // Lava/molten glass: drifting crust plates, glowing seams, bubbling pops
		float t = presentation_time();
		bool glass = material_id == 36;
		vec2 drift = vec2(t * 0.35, t * 0.12);
		float plates = fbm3(pixel / 6.5 + drift * 0.15);
		float seams = 1.0 - smoothstep(0.0, 0.06, abs(plates - 0.5));
		float churn = fbm3(pixel / 3.5 - drift * 0.4 + vec2(11.0));
		float heat = clamp(0.48 + (churn - 0.5) * 0.7 + seams * 0.45, 0.0, 1.0);
		if (glass) heat = clamp(heat * (0.38 + condition * 0.52) + 0.05, 0.0, 1.0);
		vec3 molten = heat_ramp(heat);
		if (glass) molten = mix(molten, vec3(1.0, 0.86, 0.52), 0.35);
		float crust = smoothstep(0.56, 0.68, plates) * (1.0 - seams);
		if (glass) crust *= 1.0 - condition;
		vec3 crust_colour = vec3(0.16, 0.05, 0.035) * (0.75 + value_noise(pixel / 2.0) * 0.5);
		colour.rgb = mix(molten, crust_colour, crust * 0.88);
		vec2 pop = lattice_particle(pixel, 7.0, 0.30, 23.0);
		float pop_phase = fract(t * 0.6 + pop.y * 7.0);
		colour.rgb = mix(colour.rgb, vec3(1.0, 0.92, 0.60), pop.x * smoothstep(0.85, 1.0, pop_phase));
		return colour;
	}

	if (flair == 32) { // spark twinkle
		float seed = cheap_hash(pixel);
		float twinkle = 0.66 + (1.0 - triangle_wave(presentation_time() * 2.4 + seed)) * 0.68;
		float streak = smoothstep(0.90, 1.0, 1.0 - triangle_wave(
			(pixel.x - pixel.y) / 9.0 + presentation_time() * 0.75 + seed
		));
		colour.rgb *= twinkle;
		colour.rgb += vec3(0.45, 0.38, 0.12) * streak;
		float star = step(0.93, cheap_hash(pixel + vec2(floor(presentation_time() * 12.0))));
		colour.rgb = mix(colour.rgb, vec3(1.0, 1.0, 0.88), star);
		float crackle = value_noise(pixel / 1.5 + vec2(presentation_time() * 9.0, -presentation_time() * 7.0));
		colour.rgb = mix(colour.rgb, vec3(1.0, 0.98, 0.85), smoothstep(0.55, 0.9, crackle) * 0.8);
		colour.rgb *= 0.75 + crackle * 0.35;
		return colour;
	}

	if (flair == 33) { // powders: clustered grains and occasional facets
		float coarse = cheap_hash(floor(pixel / 2.0));
		float facet = triangle_wave((pixel.x * 1.37 + pixel.y * 0.73) / 3.0);
		float speck = step(0.955, cheap_hash(pixel + vec2(5.0, 23.0)));
		float pit = step(0.965, cheap_hash(pixel + vec2(47.0, 3.0)));
		colour.rgb *= 0.72 + coarse * 0.24 + facet * 0.18;
		if (material_id == 26) {
			colour.rgb *= mix(1.0, 0.58, max(speck, pit));
		} else {
			colour.rgb += vec3(0.13, 0.12, 0.09) * speck;
			colour.rgb *= mix(1.0, 0.68, pit);
		}
		if (material_id == 27 && condition > 0.02) { // burning Coal: glowing grains
			float pulse = value_noise(pixel / 2.0 + vec2(presentation_time() * 1.2, 0.0));
			colour.rgb = mix(colour.rgb, heat_ramp(0.3 + pulse * 0.5), coarse * smoothstep(0.02, 0.5, condition));
		}
		float glint_grain = step(0.994, cheap_hash(pixel + vec2(floor(presentation_time() * 0.7) * 3.0, 9.0)));
		colour.rgb += vec3(0.30, 0.28, 0.22) * glint_grain * (material_id == 26 || material_id == 27 ? 0.0 : 1.0);
		return colour;
	}

	if (flair == 34) { // Smoke: advected billows, dark cores, lit rims, drifting soot
		float t = presentation_time();
		float billow = fbm3(pixel / 9.0 + vec2(t * 0.05, t * 0.17));
		float curl = fbm3(pixel / 4.0 + vec2(sin(t * 0.3 + pixel.y * 0.05) * 0.8, t * 0.32));
		float wisp = smoothstep(0.28, 0.82, billow * 0.65 + curl * 0.35);
		float rim = smoothstep(0.55, 0.72, curl) * (1.0 - smoothstep(0.72, 0.9, curl));
		colour.rgb *= 0.55 + wisp * 0.50;
		colour.rgb += vec3(0.07, 0.075, 0.08) * rim;
		colour.a *= (0.40 + wisp * 0.60);
		vec2 soot = lattice_particle(pixel + vec2(sin(t * 0.8 + pixel.y * 0.2) * 1.2, t * 4.0), 6.0, 0.28, 31.0);
		colour.rgb = mix(colour.rgb, vec3(0.06, 0.06, 0.07), soot.x * 0.7);
		colour.a = max(colour.a, soot.x * 0.8 * condition);
		return colour;
	}

	if (flair == 35) { // Steam: rising curls, bright plumes, condensation glints
		float t = presentation_time();
		float plume = fbm3(vec2(pixel.x / 6.0 + sin(t * 0.4 + pixel.y * 0.08), pixel.y / 5.0 + t * 0.9));
		float curl = value_noise(pixel / 2.5 + vec2(t * 0.6, t * 1.4));
		float vapour = smoothstep(0.30, 0.85, plume * 0.75 + curl * 0.25);
		colour.rgb *= 0.86 + vapour * 0.22;
		colour.a *= 0.25 + vapour * 0.75;
		vec2 drop = lattice_particle(pixel + vec2(0.0, t * 10.0), 7.0, 0.20, 37.0);
		float shine = 0.5 + 0.5 * sin(t * 8.0 + drop.y * 30.0);
		colour.rgb = mix(colour.rgb, vec3(0.95, 1.0, 1.0), drop.x * shine * 0.8);
		colour.a = max(colour.a, drop.x * shine * 0.7);
		return colour;
	}

	if (flair == 36) { // Foam: nested bubble rims driven by remaining lifetime
		vec2 bubble_cell = floor(pixel / 5.0);
		float seed = cheap_hash(bubble_cell);
		vec2 local = mod(pixel + vec2(seed * 3.7, seed * 1.9), 5.0) - vec2(2.5);
		float radius = 1.05 + seed * 0.72;
		float rim = 1.0 - smoothstep(0.18, 0.58, abs(length(local) - radius));
		float core = 1.0 - smoothstep(0.0, radius * 0.72, length(local));
		float collapse = smoothstep(0.05, 0.48, condition);
		colour.rgb *= 0.82 + rim * 0.28;
		colour.rgb += vec3(0.23, 0.30, 0.25) * rim * collapse;
		colour.a *= mix(0.42, 1.0, collapse) * (1.0 - core * 0.18);
		vec2 small_cell = floor(pixel / 3.0);
		float small_seed = cheap_hash(small_cell + vec2(7.0));
		vec2 small_local = mod(pixel, 3.0) - vec2(1.0);
		float small_rim = (1.0 - smoothstep(0.2, 0.6, abs(length(small_local) - 0.9))) * step(0.45, small_seed);
		colour.rgb += vec3(0.10, 0.12, 0.11) * small_rim;
		float specular = step(0.9, 1.0 - length(local - vec2(-0.6, -0.6)) / max(radius, 0.5)) * rim;
		colour.rgb += vec3(0.25) * specular;
		float pop = step(0.985, cheap_hash(bubble_cell + vec2(floor(presentation_time() * 3.0))))
			* (1.0 - collapse);
		colour.rgb += vec3(0.45, 0.50, 0.48) * pop * rim;
		return colour;
	}

	if (flair == 37) { // plant/fungus/seed organic fibres and nodes
		float vein_a = triangle_wave((pixel.x * 0.58 + pixel.y) / 5.0);
		float vein_b = triangle_wave((pixel.x - pixel.y * 0.31) / 9.0);
		float node = step(0.965, cheap_hash(pixel + vec2(13.0, 41.0)));
		float pulse = material_id == 18
			? 0.94 + (1.0 - triangle_wave(presentation_time() * 0.12 + cheap_hash(floor(pixel / 5.0)))) * 0.10
			: 1.0;
		colour.rgb *= (0.72 + vein_a * 0.20 + vein_b * 0.14) * pulse;
		colour.rgb += vec3(0.16, 0.20, 0.08) * node;
		if (material_id == 18) {
			vec2 spot = lattice_particle(pixel, 5.0, 0.45, 53.0);
			float glow = 0.5 + 0.5 * sin(presentation_time() * 1.4 + spot.y * 20.0);
			colour.rgb = mix(colour.rgb, vec3(0.95, 0.55, 1.0), spot.x * (0.35 + glow * 0.5));
		}
		return colour;
	}

	if (flair == 38) { // Ice: faceted crystal planes and a fixed cold sheen
		float facet_a = triangle_wave((pixel.x + pixel.y) / 7.0);
		float facet_b = triangle_wave((pixel.x - pixel.y * 1.4) / 11.0);
		float plane = 0.70 + facet_a * 0.18 + facet_b * 0.16;
		float sheen = smoothstep(0.88, 1.0, 1.0 - triangle_wave(
			(pixel.x + pixel.y * 0.52) / 29.0
		));
		colour.rgb *= plane;
		colour.rgb += vec3(0.28, 0.52, 0.66) * sheen;
		float fracture = 1.0 - smoothstep(0.0, 0.05, abs(value_noise(pixel / 7.0) - 0.5));
		colour.rgb += vec3(0.18, 0.24, 0.28) * fracture;
		vec2 frozen = lattice_particle(pixel, 6.0, 0.25, 67.0);
		colour.rgb = mix(colour.rgb, vec3(0.88, 0.96, 1.0), frozen.x * 0.5);
		return colour;
	}

	if (flair == 39) { // Acid/sludge: rolling chemical bands and rising bubbles
		float speed = material_id == 12 ? 0.18 : 0.095;
		vec2 bubble_tile = floor(pixel / 6.0);
		float seed = cheap_hash(bubble_tile);
		vec2 local = mod(
			pixel + vec2(seed * 4.0, presentation_time() * speed * 7.0 + seed * 3.0),
			6.0
		) - vec2(3.0);
		float bubble = (1.0 - smoothstep(0.22, 0.62, abs(length(local) - (0.75 + seed))))
			* step(0.47, seed);
		float swirl = triangle_wave(
			(pixel.x + pixel.y * 0.36) / 15.0 + presentation_time() * speed
		);
		vec3 reactive_tint = material_id == 12
			? vec3(0.34, 0.42, 0.04)
			: vec3(0.08, 0.40, 0.10);
		colour.rgb *= 0.72 + swirl * 0.28;
		colour.rgb += reactive_tint * bubble * 0.75;
		vec2 fizz = lattice_particle(pixel + vec2(sin(presentation_time() * 2.0 + pixel.y) * 0.5,
			presentation_time() * speed * 60.0), 4.0, 0.35, 19.0);
		colour.rgb = mix(colour.rgb, reactive_tint * 2.4 + vec3(0.15), fizz.x * 0.65);
		float froth = smoothstep(0.62, 0.80, fbm3(pixel / 3.0 + vec2(presentation_time() * speed * 2.0, 0.0)));
		colour.rgb += reactive_tint * froth * 0.35;
		return colour;
	}

	if (flair == 40) { // Mercury: travelling mirror bands and pin highlights
		float band_a = 1.0 - triangle_wave(
			(pixel.x + pixel.y * 0.18) / 13.0 + presentation_time() * 0.13
		);
		float band_b = 1.0 - triangle_wave(
			(pixel.y - pixel.x * 0.09) / 23.0 - presentation_time() * 0.075
		);
		float mirror = smoothstep(0.62, 1.0, max(band_a, band_b));
		float pin = step(0.986, cheap_hash(pixel)) * mirror;
		colour.rgb *= 0.52 + mirror * 0.64;
		colour.rgb += vec3(0.48, 0.58, 0.68) * pin;
		float warp = value_noise(pixel / 5.0 + vec2(presentation_time() * 0.30, -presentation_time() * 0.12));
		float reflection = smoothstep(0.35, 0.65, value_noise(vec2(pixel.x / 11.0 + warp * 1.5, pixel.y / 3.0)));
		colour.rgb = mix(colour.rgb * 0.85, colour.rgb * 1.25 + vec3(0.05), reflection * 0.6);
		vec2 glint = lattice_particle(pixel + vec2(presentation_time() * 2.0, 0.0), 8.0, 0.30, 43.0);
		colour.rgb += vec3(0.55, 0.60, 0.65) * glint.x * (0.5 + 0.5 * sin(presentation_time() * 6.0 + glint.y * 20.0));
		return colour;
	}

	if (flair == 41) { // Charged manufactured metal with crawling surface arcs
		vec2 local = mod(pixel, 12.0);
		float seam = max(1.0 - step(0.55, local.x), 1.0 - step(0.55, local.y));
		float brushed = triangle_wave((pixel.x + pixel.y * 0.15) / 8.0);
		float glint = manufactured_glint(pixel, 0.34);
		float route = 1.0 - triangle_wave(
			(pixel.x + floor(pixel.y / 3.0) * 2.0) / 11.0 + presentation_time() * 0.48
		);
		float arc = smoothstep(0.91, 1.0, route)
			* step(0.78, cheap_hash(floor(pixel / 2.0) + vec2(floor(presentation_time() * 4.0))))
			* condition;
		colour.rgb *= mix(0.86 + brushed * 0.20, 0.46, seam);
		colour.rgb += vec3(glint * (1.0 - seam) * 0.48);
		colour.rgb += vec3(0.10, 0.62, 1.18) * arc * (1.0 - seam);
		vec2 arc_spark = lattice_particle(pixel + vec2(presentation_time() * 9.0, 0.0), 6.0, 0.4, 61.0);
		colour.rgb += vec3(0.55, 0.85, 1.25) * arc_spark.x * condition
			* step(0.5, sin(presentation_time() * 23.0 + arc_spark.y * 40.0));
		return colour;
	}

	if (flair == 42) { // Cloner: animated circuitry lattice and scan pulse
		vec2 local = mod(pixel, 6.0);
		float trace = max(1.0 - step(0.62, local.x), 1.0 - step(0.62, local.y));
		float node = 1.0 - step(1.05, length(local - vec2(1.0)));
		float scan = smoothstep(0.82, 1.0, 1.0 - triangle_wave(
			(pixel.x + pixel.y) / 19.0 - presentation_time() * 0.26
		));
		colour.rgb *= mix(0.62, 1.08 + scan * 0.25, max(trace, node));
		colour.rgb += vec3(0.20, 0.05, 0.34) * node * scan;
		return colour;
	}

	if (flair == 43) { // Paste / wet Cement: heavy matte clumps, gentle decorative swell
		float lump = cheap_hash(floor(pixel / vec2(3.0, 2.0)));
		float fine = cheap_hash(pixel + vec2(7.0, 29.0));
		// Decorative phase, not flow. Cement scales it by cure remaining;
		// Paste projects no condition and keeps a constant, very gentle swell.
		float wet = material_id == 30 ? condition : 1.0;
		float settle = triangle_wave(
			(pixel.x * 0.8 + pixel.y * 0.35) / 31.0 + presentation_time() * 0.018
		);
		colour.rgb *= 0.86 + lump * 0.16;
		colour.rgb *= 1.0 - 0.05 * wet + settle * 0.05 * wet;
		if (material_id == 30) {
			colour.rgb += vec3((step(0.95, fine) - step(fine, 0.04)) * 0.07);
		} else {
			colour.rgb *= mix(1.0, 0.78, step(0.96, fine));
		}
		return colour;
	}

	if (flair == 44) { // Slush: icy granules over a gentle decorative meltwater shimmer
		float grain = cheap_hash(floor(pixel / 2.0));
		float facet = triangle_wave((pixel.x * 1.3 + pixel.y * 0.7) / 3.0);
		float crystal = step(0.78, cheap_hash(pixel + vec2(3.0, 17.0)));
		float melt = triangle_wave(
			(pixel.x + pixel.y * 0.3) / 17.0 + presentation_time() * 0.035
		);
		colour.rgb *= 0.80 + grain * 0.18 + facet * 0.06;
		colour.rgb *= 1.0 + (melt - 0.5) * 0.06 * (1.0 - crystal);
		colour.rgb = mix(colour.rgb, vec3(0.80, 0.93, 0.98), crystal * 0.42);
		float twinkle = crystal * step(0.92, cheap_hash(pixel + vec2(floor(presentation_time() * 1.5))));
		colour.rgb += vec3(0.30, 0.38, 0.42) * twinkle;
		return colour;
	}

	if (flair == 45) { // Wet Asphalt/Cobblestone: solid substrate under a still film
		if (material_id == 61) {
			float row = floor(pixel.y / 4.0);
			vec2 local = vec2(mod(pixel.x + mod(row, 2.0) * 2.5, 5.0) / 5.0,
				mod(pixel.y, 4.0) / 4.0) - vec2(0.5);
			float stone = 0.94 + cheap_hash(floor(vec2(pixel.x / 5.0, row))) * 0.16;
			colour.rgb *= mix(stone, 0.53, smoothstep(0.36, 0.53, length(local)));
		} else {
			float grain = cheap_hash(pixel);
			colour.rgb *= 0.84 + grain * 0.30;
			colour.rgb += vec3(0.055, 0.062, 0.070) * step(0.94, grain);
		}
		// Fixed, world-anchored film reflections pooled in broad patches.
		float pool = cheap_hash(floor(pixel / vec2(9.0, 5.0)));
		float sheen = smoothstep(0.62, 1.0, triangle_wave((pixel.x + pixel.y * 0.24) / 19.0));
		colour.rgb += vec3(0.060, 0.080, 0.100) * sheen * (0.35 + pool * 0.65);
		return colour;
	}

	return colour;
}

vec2 sampled_cell(vec2 pixel) {
	vec2 clamped_pixel = clamp(floor(pixel), vec2(0.0), world_size_px - vec2(1.0));
	return texture(current_world_texture, (clamped_pixel + vec2(0.5)) / world_size_px).rg;
}

int cell_material(vec2 cell) {
	return int(floor(cell.r * 255.0 + 0.5));
}

bool is_hot_source(vec2 cell) {
	int id = cell_material(cell);
	if (id == 6 || id == 8 || id == 34 || id == 36) return true;
	// Burning fuels project burn progress (Wood, Oil, Coal, Oak, Thatch).
	return (id == 7 || id == 16 || id == 27 || id == 46 || id == 47) && cell.g > 0.02;
}

// Presentation-only particles drawn in Empty cells: embers rising above hot
// sources and fumes above reactive liquids. The arithmetic particle test runs
// first; only a candidate particle pixel reads up to three cells below it.
vec4 apply_ambient_particles(vec4 colour, vec2 pixel) {
	float t = presentation_time();
	vec2 ember_p = pixel + vec2(sin(t * 1.7 + pixel.y * 0.35) * 1.2, t * 14.0);
	vec2 ember = lattice_particle(ember_p, 5.0, 0.45, 11.0);
	float tail = 1.0;
	if (ember.x < 0.5) {
		ember = lattice_particle(ember_p - vec2(0.0, 1.0), 5.0, 0.45, 11.0);
		tail = 0.45;
	}
	if (ember.x > 0.5) {
		float strength = 0.0;
		if (is_hot_source(sampled_cell(pixel + vec2(0.0, 2.0)))) strength = 1.0;
		else if (is_hot_source(sampled_cell(pixel + vec2(0.0, 5.0)))) strength = 0.75;
		else if (is_hot_source(sampled_cell(pixel + vec2(0.0, 9.0)))) strength = 0.45;
		float flicker = 0.55 + 0.45 * sin(t * 11.0 + ember.y * 60.0);
		colour.rgb = mix(colour.rgb, heat_ramp(0.45 + flicker * 0.5 * tail), strength * flicker * tail);
		return colour;
	}
	vec2 fume = lattice_particle(
		pixel + vec2(sin(t * 0.9 + pixel.y * 0.25) * 1.6, t * 5.0), 5.0, 0.30, 17.0);
	if (fume.x > 0.5) {
		float strength = 0.0;
		int below = cell_material(sampled_cell(pixel + vec2(0.0, 2.0)));
		if (below != 12 && below != 32) below = cell_material(sampled_cell(pixel + vec2(0.0, 4.0)));
		if (below == 12 || below == 32) strength = 0.55;
		vec3 tint = below == 12 ? vec3(0.78, 0.92, 0.25) : vec3(0.35, 0.85, 0.30);
		colour.rgb = mix(colour.rgb, tint, strength * (0.6 + 0.4 * sin(t * 3.0 + fume.y * 30.0)));
	}
	return colour;
}

bool inside_rigid_body(vec2 world_pixel, vec4 body_data, float body_rotation) {
	vec2 delta = world_pixel + vec2(0.5) - body_data.xy;
	float cosine = cos(body_rotation);
	float sine = sin(body_rotation);
	vec2 local_position = vec2(
		cosine * delta.x + sine * delta.y,
		-sine * delta.x + cosine * delta.y
	);
	vec2 half_size = body_data.zw * 0.5;
	return abs(local_position.x) <= half_size.x && abs(local_position.y) <= half_size.y;
}

bool is_temporally_smoothed_material(int material_id) {
	return material_id == 2
		|| material_id == 3
		|| material_id == 4
		|| material_id == 6
		|| material_id == 20
		|| material_id == 21
		|| material_id == 22
		|| material_id == 23
		|| material_id == 24
		|| material_id == 25
		|| material_id == 26
		|| material_id == 27
		|| material_id == 29
		|| material_id == 30
		|| material_id == 32
		|| material_id == 33
		|| material_id == 34
		|| material_id == 36
		|| material_id == 37;
}

float stable_coverage_hash(vec2 pixel) {
	return cheap_hash(pixel + vec2(41.31, 17.17));
}

int water_coverage_samples(int condition_byte) {
	if (condition_byte <= 0) return 0;
	return min(4, (condition_byte * 4 + 254) / 255);
}

int water_coverage_mask(int samples) {
	if (samples <= 0) return 0;
	if (samples == 1) return 1;
	if (samples == 2) return 3;
	if (samples == 3) return 7;
	return 15;
}

int water_subcell_index(int x, int y) {
	if (y == 0) return x == 1 ? 3 : 2;
	return x == 1 ? 1 : 0;
}

int water_add_ordered_sample(int mask, int sample_count, int rank, int subcell) {
	if (rank >= sample_count) return mask;
	if (subcell == 0) return mask + 1;
	if (subcell == 1) return mask + 2;
	if (subcell == 2) return mask + 4;
	return mask + 8;
}

int sampled_water_condition_byte(vec2 pixel, bool previous_snapshot) {
	vec2 clamped_pixel = clamp(floor(pixel), vec2(0.0), world_size_px - vec2(1.0));
	vec2 world_uv = (clamped_pixel + vec2(0.5)) / world_size_px;
	vec2 cell_sample;
	if (previous_snapshot) {
		cell_sample = texture(previous_world_texture, world_uv).rg;
	} else {
		cell_sample = texture(current_world_texture, world_uv).rg;
	}
	int material_id = int(floor(cell_sample.r * 255.0 + 0.5));
	if (material_id != 3) return 0;
	return int(floor(cell_sample.g * 255.0 + 0.5));
}

int water_oriented_mask(
	int condition_byte,
	vec2 world_pixel,
	bool previous_snapshot
) {
	int samples = water_coverage_samples(condition_byte);
	if (samples == 0) return 0;

	int gradient_x = sampled_water_condition_byte(
		world_pixel + vec2(1.0, 0.0), previous_snapshot
	) - sampled_water_condition_byte(
		world_pixel + vec2(-1.0, 0.0), previous_snapshot
	);
	int gradient_y = sampled_water_condition_byte(
		world_pixel + vec2(0.0, 1.0), previous_snapshot
	) - sampled_water_condition_byte(
		world_pixel + vec2(0.0, -1.0), previous_snapshot
	);
	int magnitude_x = abs(gradient_x);
	int magnitude_y = abs(gradient_y);
	int magnitude = max(magnitude_x, magnitude_y);

	// Weak, symmetric, isolated and equal-diagonal gradients use the fixed
	// coverage masks. Thresholds are exact normalized-byte comparisons.
	if (magnitude <= 2 || abs(magnitude_x - magnitude_y) < 1) {
		return water_coverage_mask(samples);
	}

	int fuller_x = gradient_x > 0 ? 1 : 0;
	int fuller_y = gradient_y > 0 ? 1 : 0;
	int first;
	int second;
	int third;
	int fourth;

	if (min(magnitude_x, magnitude_y) > 2) {
		first = water_subcell_index(fuller_x, fuller_y);
		if (magnitude_x > magnitude_y) {
			second = water_subcell_index(fuller_x, 1 - fuller_y);
			third = water_subcell_index(1 - fuller_x, fuller_y);
		} else {
			second = water_subcell_index(1 - fuller_x, fuller_y);
			third = water_subcell_index(fuller_x, 1 - fuller_y);
		}
		fourth = water_subcell_index(1 - fuller_x, 1 - fuller_y);
	} else {
		// Axial gradients contain tied scores. Alternate each tied pair by
		// world-cell parity so the choice is stable across frames and scales.
		bool odd_cell = int(mod(abs(world_pixel.x + world_pixel.y), 2.0)) == 1;
		if (magnitude_x > magnitude_y) {
			int full_bottom = water_subcell_index(fuller_x, 1);
			int full_top = water_subcell_index(fuller_x, 0);
			int empty_bottom = water_subcell_index(1 - fuller_x, 1);
			int empty_top = water_subcell_index(1 - fuller_x, 0);
			first = odd_cell ? full_top : full_bottom;
			second = odd_cell ? full_bottom : full_top;
			third = odd_cell ? empty_top : empty_bottom;
			fourth = odd_cell ? empty_bottom : empty_top;
		} else {
			int full_left = water_subcell_index(0, fuller_y);
			int full_right = water_subcell_index(1, fuller_y);
			int empty_left = water_subcell_index(0, 1 - fuller_y);
			int empty_right = water_subcell_index(1, 1 - fuller_y);
			first = odd_cell ? full_right : full_left;
			second = odd_cell ? full_left : full_right;
			third = odd_cell ? empty_right : empty_left;
			fourth = odd_cell ? empty_left : empty_right;
		}
	}

	int mask = 0;
	mask = water_add_ordered_sample(mask, samples, 0, first);
	mask = water_add_ordered_sample(mask, samples, 1, second);
	mask = water_add_ordered_sample(mask, samples, 2, third);
	return water_add_ordered_sample(mask, samples, 3, fourth);
}

bool water_mask_contains(int mask, int subcell) {
	if (subcell == 0) return mask % 2 == 1;
	if (subcell == 1) return (mask / 2) % 2 == 1;
	if (subcell == 2) return (mask / 4) % 2 == 1;
	return (mask / 8) % 2 == 1;
}

int displayed_material_id(
	int material_id,
	float condition,
	vec2 world_pixel,
	vec2 cell_fraction,
	bool previous_snapshot
) {
	if (material_id != 3 || condition_projection_enabled <= 0.5) {
		return material_id;
	}
	if (water_presentation_mode < 0.5) {
		return stable_coverage_hash(world_pixel) >= condition ? 0 : material_id;
	}

	int condition_byte = int(floor(condition * 255.0 + 0.5));
	int samples = water_coverage_samples(condition_byte);
	int mask = water_coverage_mask(samples);
	if (water_presentation_mode >= 1.5) {
		mask = water_oriented_mask(condition_byte, world_pixel, previous_snapshot);
	}
	int subcell_x = cell_fraction.x >= 0.5 ? 1 : 0;
	int subcell_y = cell_fraction.y >= 0.5 ? 1 : 0;
	int subcell = water_subcell_index(subcell_x, subcell_y);
	return water_mask_contains(mask, subcell) ? material_id : 0;
}

vec4 material_colour(
	int material_id,
	float condition,
	vec2 world_pixel,
	bool previous_snapshot
) {
	float variation = stable_pixel_hash(world_pixel, material_id);
	float variation_index = floor(variation * material_lut_size.x);
	vec2 lut_uv = vec2(
		(variation_index + 0.5) / material_lut_size.x,
		(float(material_id) + 0.5) / material_lut_size.y
	);
	vec4 colour = texture(material_lut, lut_uv);
	float program_v = (float(material_id) + 0.5) / 256.0;
	vec4 tint = texture(material_program_lut, vec2(0.125, program_v));
	vec4 curve_value = texture(material_program_lut, vec2(0.375, program_v));
	vec4 alpha_emission = texture(material_program_lut, vec2(0.625, program_v));
	vec4 emission_colour = texture(material_program_lut, vec2(0.875, program_v));
	float response = smoothstep(curve_value.x, curve_value.y, condition);
	colour.rgb *= mix(curve_value.z, curve_value.w, response);
	colour.rgb = mix(colour.rgb, tint.rgb, tint.a * response);
	colour.a *= mix(alpha_emission.x, alpha_emission.y, response);
	colour.rgb += emission_colour.rgb * mix(
		alpha_emission.z,
		alpha_emission.w,
		response
	);
	int flair = int(floor(emission_colour.a + 0.5));
	colour = apply_material_flair(colour, material_id, flair, world_pixel, condition);
	// One gather of the four neighbours (from the snapshot being shaded)
	// feeds both the volume/contact stage and the structural relief.
	ivec4 neighbours = ivec4(
		sampled_material_id(world_pixel + vec2(0.0, -1.0), previous_snapshot),
		sampled_material_id(world_pixel + vec2(0.0, 1.0), previous_snapshot),
		sampled_material_id(world_pixel + vec2(-1.0, 0.0), previous_snapshot),
		sampled_material_id(world_pixel + vec2(1.0, 0.0), previous_snapshot)
	);
	colour = apply_volume_and_contact(
		colour, material_id, world_pixel, neighbours, previous_snapshot, condition);
	return apply_neighbour_relief(colour, material_id, neighbours);
}

void fragment() {
	vec2 view_min = view_rect_uv.xy;
	vec2 view_max = view_rect_uv.xy + view_rect_uv.zw;
	bool inside_view = UV.x >= view_min.x && UV.y >= view_min.y
		&& UV.x < view_max.x && UV.y < view_max.y;
	vec2 fitted_uv = clamp(
		(UV - view_min) / max(view_rect_uv.zw, vec2(0.000001)),
		vec2(0.0),
		vec2(0.999999)
	);
	vec2 continuous_view_pixel = fitted_uv * view_size_px;
	vec2 view_pixel = floor(continuous_view_pixel);
	vec2 world_pixel = camera_origin_px + view_pixel;
	vec2 cell_fraction = fract(camera_origin_px + continuous_view_pixel);
	vec2 world_uv = (world_pixel + vec2(0.5)) / world_size_px;
	vec2 cell_sample = texture(TEXTURE, world_uv).rg;
	vec2 previous_cell_sample = texture(previous_world_texture, world_uv).rg;
	int stored_material_id = int(floor(cell_sample.r * 255.0 + 0.5));
	int previous_stored_material_id = int(floor(previous_cell_sample.r * 255.0 + 0.5));
	float condition = cell_sample.g;
	float previous_condition = previous_cell_sample.g;
	int material_id = displayed_material_id(
		stored_material_id,
		condition,
		world_pixel,
		cell_fraction,
		false
	);
	int previous_material_id = displayed_material_id(
		previous_stored_material_id,
		previous_condition,
		world_pixel,
		cell_fraction,
		true
	);
	vec4 colour = material_colour(material_id, condition, world_pixel, false);
	if (
		previous_material_id != material_id
		&& (
			is_temporally_smoothed_material(material_id)
			|| is_temporally_smoothed_material(previous_material_id)
		)
	) {
		colour = mix(
			material_colour(previous_material_id, previous_condition, world_pixel, true),
			colour,
			snapshot_blend
		);
	}
	if (material_id == 0 && inside_view) {
		colour = apply_ambient_particles(colour, world_pixel);
	}

	vec2 player_max = player_origin_px + player_size_px;
	bool inside_player = world_pixel.x >= player_origin_px.x
		&& world_pixel.y >= player_origin_px.y
		&& world_pixel.x < player_max.x
		&& world_pixel.y < player_max.y;
	if (inside_player) {
		colour = player_colour;
	}

	bool inside_test_body = inside_rigid_body(
		world_pixel,
		rigid_body_data_0,
		rigid_body_rotation_0
	) || inside_rigid_body(
		world_pixel,
		rigid_body_data_1,
		rigid_body_rotation_1
	) || inside_rigid_body(
		world_pixel,
		rigid_body_data_2,
		rigid_body_rotation_2
	);
	if (inside_test_body) {
		colour = rigid_body_colour;
	}
	if (!inside_view) {
		colour = material_colour(0, 0.0, world_pixel, false);
	}

	COLOR = colour;
}
