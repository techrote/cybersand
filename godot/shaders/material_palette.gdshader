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
// Quality-tier hook: 0 skips the shape-aware fills (and their extra reads) and
// falls back to each material's ordinary finish.
uniform float structured_detail = 1.0;
// Quality-tier hook for the Empty-cell growth decor (vines, flowers, shrooms).
uniform float growth_decor = 1.0;
// Steam/Smoke afterimage written by material_vapour_trail.gdshader. Zero
// strength (the default, used by capture fixtures) leaves output unchanged.
uniform sampler2D vapour_trail_texture : hint_default_black, filter_linear, repeat_disable;
uniform vec2 vapour_trail_origin_px = vec2(0.0);
uniform float vapour_trail_strength = 0.0;
// Last valid material ID; mirrors CyberMaterialAppearanceLut.MATERIAL_COUNT - 1.
const int LAST_MATERIAL_ID = 131;

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

// Domain-warped flow field for liquid bulk. Two slow warp noises bend a
// three-octave field, so motion reads as pseudorandom swirling eddies rather
// than straight bands scrolling at one rate. World-anchored; presentation only.
float swirl_field(vec2 p, float t, float speed) {
	vec2 warp = vec2(
		value_noise(p * 0.55 + vec2(t * speed, -t * speed * 0.6)),
		value_noise(p * 0.55 + vec2(5.2 - t * speed * 0.7, 1.3 + t * speed * 0.45))
	) - vec2(0.5);
	return fbm3(p + warp * 3.2 + vec2(t * speed * 0.30, -t * speed * 0.18));
}

// Thin contour lines of a smooth field: curved marbling, never hatching.
float field_contours(float field, float count, float width) {
	float f = fract(field * count);
	return 1.0 - smoothstep(0.0, width, min(f, 1.0 - f));
}

// Organic corrosion: layered blotches, gravity-stretched spill runs and
// clustered pits. Returns x = coverage 0..1, y = darkness of the deepest scale.
vec2 corrosion_field(vec2 pixel, float up_bias) {
	float blotch = fbm3(pixel / 7.5 + vec2(3.1, 9.7));
	float run_warp = value_noise(pixel / 6.0) * 2.4;
	float run = fbm3(vec2(pixel.x / 2.6 + run_warp, pixel.y / 13.0));
	float spill = smoothstep(0.50, 0.72, run) * smoothstep(0.30, 0.55, blotch + up_bias);
	float coverage = clamp(smoothstep(0.42, 0.66, blotch) + spill * 0.8, 0.0, 1.0);
	float deep = smoothstep(0.62, 0.82, blotch) * smoothstep(0.45, 0.75, value_noise(pixel / 2.2));
	return vec2(coverage, deep);
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
		|| (material_id >= 38 && material_id <= LAST_MATERIAL_ID);
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
	return id == 5 || id == 6 || id == 8 || id == 34 || id == 36 || (id >= 77 && id <= 80)
		|| id == 123 || id == 127;
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
	if (id == 123) return vec3(0.30, 0.85, 0.18);
	if (id == 127) return vec3(0.25, 0.80, 0.55);
	return vec3(0.0);
}

bool is_water_like(int id) {
	return id == 3 || id == 24 || id == 21 || id == 9;
}

bool is_fuel(int id) {
	return id == 7 || id == 11 || id == 16 || id == 27 || id == 46 || id == 47 || id == 26
		|| (id >= 81 && id <= 97);
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
					: material_id == 32 ? vec3(0.30, 0.66, 0.20)
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
		// Luminous building materials do not rim-light their own interior.
		if (material_id >= 81 && is_emitter(material_id)) {
			light -= emitter_light(material_id) * (float(neighbours.x == material_id)
				+ float(neighbours.y == material_id) + float(neighbours.z == material_id)
				+ float(neighbours.w == material_id));
		}
		colour.rgb += light * colour.rgb * 0.75 + light * 0.10;
	}
	return colour;
}

// ---------------------------------------------------------------------------
// MAT-002 building catalogue (IDs 81+). One flair class; the branch is chosen by
// material ID. Geometry comes from the shape-aware run probe when enabled and
// from a fixed large-panel default otherwise. Static finishes are
// time-independent apart from deliberate manufactured or luminous effects
// (aluminium/brass/gold glints, snow glitter, phosphor breathing).

struct BuildGeometry {
	float along;        // world coordinate along the run
	float across_world; // world coordinate across the run
	float across_u;     // 0..1 position across the run
	float across_span;  // cells across the run
	float edge;         // cells to the nearest run edge (0 = exposed)
	float up;           // cells of the same material above (probe-limited)
	float down;         // cells of the same material below
	bool horizontal;
	bool top_open;
	bool bottom_open;
};

BuildGeometry default_build_geometry(vec2 pixel) {
	BuildGeometry g;
	g.along = pixel.x;
	g.across_world = pixel.y;
	g.across_u = 0.5;
	g.across_span = 9.0;
	g.edge = 4.0;
	g.up = 4.0;
	g.down = 4.0;
	g.horizontal = true;
	g.top_open = false;
	g.bottom_open = false;
	return g;
}

vec4 apply_burn(vec4 colour, vec2 pixel, float condition) {
	if (condition <= 0.02) return colour;
	float t = presentation_time();
	float vein = abs(value_noise(pixel / 6.0) - 0.5) + abs(value_noise(pixel / 2.5 + vec2(13.0)) - 0.5) * 0.35;
	float cracks = 1.0 - smoothstep(0.02, 0.07, vein);
	float pulse = 0.55 + 0.45 * value_noise(pixel / 4.0 + vec2(t * 1.1, t * 0.5));
	float burn = smoothstep(0.02, 0.6, condition);
	vec3 char_colour = vec3(0.07, 0.05, 0.045) * (0.8 + cheap_hash(floor(pixel / 2.0)) * 0.4);
	colour.rgb = mix(colour.rgb, char_colour, burn * 0.80);
	colour.rgb = mix(colour.rgb, heat_ramp(0.30 + pulse * 0.55), cracks * burn * pulse);
	return colour;
}

// Late-wood band intensity for a board seen edge-on: rings run along the
// board, bent by two noise scales so the figure flows instead of striping.
float wood_grain(float along, float across, float seed, float ring, float wobble) {
	float warp = (value_noise(vec2(along / 14.0, across / 3.0 + seed * 7.0)) - 0.5) * wobble
		+ (value_noise(vec2(along / 4.5, across * 0.8 + seed * 3.0)) - 0.5) * wobble * 0.35;
	float g = fract(across / ring + warp + seed);
	return smoothstep(0.60, 0.90, g) * (1.0 - smoothstep(0.90, 1.0, g));
}

// x = knot core, y = ring swirl around it (added to the grain coordinate).
vec2 wood_knot(float along, float across, float spacing, float density, float seed) {
	vec2 cell = floor(vec2(along / spacing, across / 5.0));
	float h = cheap_hash(cell + vec2(seed, 7.0));
	if (h > density) return vec2(0.0);
	vec2 centre = (cell + vec2(0.2 + cheap_hash(cell + vec2(seed + 1.0)) * 0.6,
		0.3 + cheap_hash(cell + vec2(seed + 2.0)) * 0.4)) * vec2(spacing, 5.0);
	float d = length((vec2(along, across) - centre) * vec2(0.55, 1.0));
	return vec2(1.0 - smoothstep(0.5, 1.4, d), exp(-d * 0.45) * 1.6);
}

// Planked surface helper: x = lane index, y = joint mask, z = gap mask.
vec3 board_layout(BuildGeometry g, float lane_width, float board_length, float seed) {
	float lane = floor(g.across_world / lane_width);
	float offset = cheap_hash(vec2(lane, seed)) * board_length;
	float joint = 1.0 - step(0.8, mod(g.along + offset, board_length));
	float gap = 1.0 - step(0.6, mod(g.across_world, lane_width));
	return vec3(lane, joint, gap);
}

// Running-bond block courses: x = seam mask, y = per-block hash.
vec2 block_courses(vec2 pixel, vec2 size, float seed) {
	float row = floor(pixel.y / size.y);
	float shifted = pixel.x + mod(row, 2.0) * size.x * 0.5;
	vec2 local = vec2(mod(shifted, size.x), mod(pixel.y, size.y));
	float seam = max(1.0 - step(0.7, local.x), 1.0 - step(0.7, local.y));
	return vec2(seam, cheap_hash(vec2(floor(shifted / size.x), row) + vec2(seed)));
}

// Cheap jittered cellular field: x = distance to nearest site, y = gap to the
// second site (small near borders), z = owning site hash.
vec3 cell_field(vec2 pixel, float size, float seed) {
	vec2 cell = floor(pixel / size);
	float nearest = 9.0;
	float second = 9.0;
	float owner = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 candidate = cell + vec2(float(x), float(y));
			vec2 site = (candidate + vec2(0.15) + vec2(cheap_hash(candidate + vec2(seed)),
				cheap_hash(candidate + vec2(seed + 7.0))) * 0.7) * size;
			float d = length(pixel + vec2(0.5) - site);
			if (d < nearest) { second = nearest; nearest = d; owner = cheap_hash(candidate + vec2(seed + 3.0)); }
			else if (d < second) { second = d; }
		}
	}
	return vec3(nearest, second - nearest, owner);
}

float static_glint(vec2 pixel, float threshold) {
	return step(threshold, cheap_hash(pixel + vec2(13.0, 71.0)));
}

vec4 apply_building_finish(vec4 colour, int id, vec2 pixel, BuildGeometry g, float condition) {
	float t = presentation_time();
	float along = g.along;
	float across = g.across_world;
	float cylinder = 1.0 - pow(abs(g.across_u * 2.0 - 1.0), 2.0);
	bool exposed = g.edge < 0.5;

	// ---- woods, fibres and combustible polymers (81-97) ----
	if (id == 81) { // pine planks: pale boards, tight flowing grain, resin knots
		vec3 b = board_layout(g, 4.0, 15.0, 3.0);
		vec2 knot = wood_knot(along, across, 13.0, 0.35, 5.0);
		float grain = wood_grain(along, across + knot.y, cheap_hash(vec2(b.x, 2.0)), 1.6, 1.4);
		colour.rgb *= 0.90 + cheap_hash(vec2(b.x, 8.0)) * 0.16 - grain * 0.22;
		colour.rgb = mix(colour.rgb, vec3(0.42, 0.24, 0.10), knot.x * 0.85);
		colour.rgb *= 1.0 - b.y * 0.40 - b.z * 0.32;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 82) { // birch: papery white bark, black lenticel dashes, peeling curls
		float lenticel = step(0.78, value_noise(vec2(along * 0.9, across / 3.5)))
			* step(0.45, value_noise(vec2(along / 5.0, across / 6.0)));
		float scar = 1.0 - smoothstep(0.0, 0.09, abs(value_noise(vec2(along / 9.0, across / 2.0)) - 0.5));
		float curl = step(0.84, value_noise(pixel / 2.2 + vec2(7.0)));
		colour.rgb *= 0.70 + cylinder * 0.36;
		colour.rgb = mix(colour.rgb, vec3(0.08, 0.07, 0.07), max(lenticel * 0.85, scar * step(0.62, value_noise(pixel / 7.0)) * 0.8));
		colour.rgb = mix(colour.rgb, vec3(0.84, 0.66, 0.50), curl * 0.45);
		return apply_burn(colour, pixel, condition);
	}
	if (id == 83) { // rough oak bark: deep furrows along the trunk, broken plates, lichen
		float furrow_coord = across / 2.2 + (value_noise(vec2(along / 10.0, across / 3.0)) - 0.5) * 1.8;
		float furrow = 1.0 - smoothstep(0.0, 0.22, abs(fract(furrow_coord) - 0.5) - 0.25);
		float plate_break = step(0.80, value_noise(vec2(along / 2.0, floor(furrow_coord) * 3.1)));
		colour.rgb *= (0.62 + cylinder * 0.50) * (1.0 - furrow * 0.68) * (1.0 - plate_break * 0.30);
		colour.rgb += vec3(0.10, 0.08, 0.05) * (1.0 - furrow) * cylinder;
		colour.rgb += vec3(0.07, 0.06, 0.05) * (1.0 - furrow) * value_noise(pixel / 1.5);
		float lichen = step(0.84, value_noise(pixel / 3.0 + vec2(41.0))) * (1.0 - furrow);
		colour.rgb = mix(colour.rgb, vec3(0.50, 0.58, 0.40), lichen * 0.55);
		return apply_burn(colour, pixel, condition);
	}
	if (id == 84 || id == 85) { // walnut / mahogany panels: figured grain, satin lustre
		vec3 b = board_layout(g, id == 84 ? 6.0 : 5.0, 23.0, float(id));
		float seed = cheap_hash(vec2(b.x, float(id)));
		float grain = wood_grain(along, across, seed, id == 84 ? 2.6 : 1.9, id == 84 ? 2.6 : 1.0);
		float figure = id == 85
			? smoothstep(0.35, 0.65, value_noise(vec2(along / 3.0, b.x * 5.0))) // ribbon stripe
			: value_noise(vec2(along / 6.0, across / 2.0 + seed * 9.0));
		colour.rgb *= 0.82 + figure * 0.26 - grain * 0.26;
		float lustre = smoothstep(0.86, 1.0, 1.0 - triangle_wave((along + across * 0.6) / 37.0 + seed));
		colour.rgb += vec3(0.10, 0.07, 0.05) * lustre;
		colour.rgb *= 1.0 - b.y * 0.42 - b.z * 0.40;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 86) { // bamboo: rounded culms with nodes, fibres and tint per culm
		float culm = floor(across / 3.0);
		float u = mod(across, 3.0) / 3.0;
		float round_shade = 0.60 + (1.0 - pow(abs(u * 2.0 - 1.0), 2.0)) * 0.48;
		float spacing = 9.0 + floor(cheap_hash(vec2(culm, 4.0)) * 5.0);
		float in_segment = mod(along + cheap_hash(vec2(culm, 9.0)) * spacing, spacing);
		float node = 1.0 - step(0.9, in_segment);
		float bulge = 1.0 - smoothstep(0.9, 2.2, in_segment) * smoothstep(spacing - 0.2, spacing - 1.6, in_segment);
		vec3 tint = mix(vec3(0.62, 0.66, 0.28), vec3(0.78, 0.66, 0.34), cheap_hash(vec2(culm, 1.0)));
		colour.rgb = tint * round_shade * (0.94 + triangle_wave(across * 1.7 + along / 21.0) * 0.08);
		colour.rgb *= 1.0 - node * 0.45 + bulge * 0.06;
		colour.rgb *= 1.0 - (1.0 - step(0.5, mod(across, 3.0))) * 0.35;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 87) { // plywood: cathedral face veneer, ply laminations on exposed edges
		float centre = (floor(along / 17.0) + 0.5) * 17.0;
		float arch = length(vec2((along - centre) * 0.35, across - floor(across / 13.0) * 13.0 + 3.0));
		float cathedral = smoothstep(0.65, 0.95, fract(arch / 2.1 + value_noise(pixel / 7.0) * 0.6));
		colour.rgb *= 0.92 - cathedral * 0.20 + value_noise(pixel / 3.0) * 0.08;
		float sheet = 1.0 - step(0.7, mod(along, 24.0));
		colour.rgb *= 1.0 - sheet * 0.40;
		if (g.edge < 1.5) { // laminations: alternating plies
			float ply = mod(floor((g.horizontal ? pixel.y : pixel.x) * 1.0), 2.0);
			colour.rgb = mix(colour.rgb, colour.rgb * (0.70 + ply * 0.35), 0.8);
		}
		return apply_burn(colour, pixel, condition);
	}
	if (id == 88) { // driftwood: silvered, deeply weathered grain, worm holes
		float grain = wood_grain(along, across, 0.3, 2.2, 3.2);
		float streak = smoothstep(0.55, 0.85, value_noise(vec2(along / 9.0, across * 0.9)));
		colour.rgb *= 0.84 + streak * 0.22 - grain * 0.30;
		colour.rgb = mix(colour.rgb, vec3(0.80, 0.80, 0.78), smoothstep(0.7, 0.95, value_noise(pixel / 5.0)) * 0.3);
		float hole = step(0.975, cheap_hash(floor(pixel / 2.0) + vec2(31.0)));
		colour.rgb *= 1.0 - hole * 0.6;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 89) { // cedar shingles: staggered courses, weathered silver to red
		float course = floor(pixel.y / 4.0);
		float width = 3.0 + floor(cheap_hash(vec2(floor(pixel.x / 5.0), course)) * 3.0);
		float shifted = pixel.x + course * 2.3;
		float shingle = floor(shifted / width);
		float in_x = mod(shifted, width);
		float local_y = mod(pixel.y, 4.0);
		float h = cheap_hash(vec2(shingle, course));
		vec3 tone = mix(colour.rgb, vec3(0.56, 0.54, 0.52), smoothstep(0.55, 0.95, h) * 0.75);
		colour.rgb = tone * (0.80 + local_y * 0.07);
		colour.rgb *= 1.0 - (1.0 - step(0.7, in_x)) * 0.55;
		colour.rgb *= 1.0 - (1.0 - step(0.9, local_y)) * 0.45;
		colour.rgb *= 0.92 + triangle_wave(pixel.x * 0.9 + h * 4.0) * 0.10;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 90) { // charred timber (shou sugi ban): alligator crackle with silver sheen
		vec3 crack = cell_field(pixel * vec2(1.0, 1.6), 3.4, 17.0);
		float fissure = 1.0 - smoothstep(0.15, 0.55, crack.y);
		float sheen = smoothstep(0.55, 0.95, 1.0 - crack.x / 2.4) * (0.5 + crack.z * 0.5);
		colour.rgb *= 0.80 + sheen * 0.55;
		colour.rgb += vec3(0.14, 0.14, 0.16) * sheen * step(0.55, crack.z);
		colour.rgb *= 1.0 - fissure * 0.75;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 91) { // cork: compressed granules and dark pores
		float granule = value_noise(pixel / 1.6);
		float pore = step(0.86, value_noise(pixel / 1.1 + vec2(23.0)));
		colour.rgb *= 0.78 + granule * 0.34;
		colour.rgb = mix(colour.rgb, vec3(0.86, 0.66, 0.44), step(0.80, granule) * 0.35);
		colour.rgb *= 1.0 - pore * 0.55;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 92) { // wicker: over/under basket weave of rounded strands
		vec2 tile = floor(pixel / 4.0);
		vec2 local = mod(pixel, 4.0);
		bool runs_x = mod(tile.x + tile.y, 2.0) < 0.5;
		float u = (runs_x ? local.y : local.x) / 4.0;
		float strand = 1.0 - pow(abs(fract(u * 2.0) * 2.0 - 1.0), 2.0);
		float under = (runs_x ? local.x : local.y) / 4.0;
		colour.rgb *= 0.50 + strand * 0.52 + (1.0 - abs(under * 2.0 - 1.0)) * 0.10;
		colour.rgb *= 1.0 - (1.0 - step(0.6, runs_x ? local.x : local.y)) * 0.25;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 93) { // cardboard: fibre mottle, fold creases, fluting on exposed edges
		colour.rgb *= 0.92 + value_noise(pixel / 3.0) * 0.10 + (cheap_hash(pixel) - 0.5) * 0.06;
		float crease = 1.0 - step(0.6, mod(along, 19.0));
		colour.rgb *= 1.0 - crease * 0.20;
		float tape = step(abs(g.across_u - 0.5), 0.12) * step(4.5, g.across_span);
		colour.rgb = mix(colour.rgb, vec3(0.80, 0.68, 0.46), tape * 0.45);
		if (g.edge < 1.5) colour.rgb *= 0.70 + (1.0 - triangle_wave(along / 2.0)) * 0.45;
		return apply_burn(colour, pixel, condition);
	}
	if (id == 94) { // shoji paper screen: backlit paper in a kumiko lattice
		float bar = max(1.0 - step(0.8, mod(pixel.x, 6.0)), 1.0 - step(0.8, mod(pixel.y, 8.0)));
		float glow = 0.94 + value_noise(pixel / 5.0) * 0.10 + fbm3(pixel / 2.0) * 0.04;
		colour.rgb *= glow;
		colour.rgb = mix(colour.rgb, vec3(0.30, 0.20, 0.12), max(bar, step(g.edge, 0.5)));
		colour.a = mix(colour.a, 1.0, max(bar, step(g.edge, 0.5)));
		return apply_burn(colour, pixel, condition);
	}
	if (id == 95) { // tar block: wrinkled glossy pitch with a fixed specular band
		float wrinkle = value_noise(pixel / 2.6) * 0.6 + value_noise(pixel / 1.2) * 0.4;
		float spec = smoothstep(0.82, 1.0, 1.0 - triangle_wave((pixel.x + pixel.y * 0.4 + wrinkle * 4.0) / 21.0));
		colour.rgb *= 0.85 + wrinkle * 0.25;
		colour.rgb += vec3(0.20, 0.21, 0.24) * spec * smoothstep(0.4, 0.7, wrinkle);
		if (g.top_open) colour.rgb += vec3(0.06);
		return apply_burn(colour, pixel, condition);
	}
	if (id == 96) { // acrylic sheet: clear with polished bright edges and inner reflection
		float inner = smoothstep(0.85, 1.0, 1.0 - triangle_wave((pixel.x - pixel.y * 0.8) / 23.0));
		colour.rgb += vec3(0.22, 0.26, 0.28) * inner;
		if (g.edge < 0.5) { colour.rgb = colour.rgb * 1.20 + vec3(0.10); colour.a = 0.90; }
		return apply_burn(colour, pixel, condition);
	}
	if (id == 97) { // moss wall: stone courses smothered in fuzzy moss, bright fruiting tips
		vec2 block = block_courses(pixel, vec2(7.0, 5.0), 9.0);
		float moss = smoothstep(0.38, 0.62, fbm3(pixel / 3.5) + (g.top_open ? 0.25 : 0.0));
		vec3 stone = vec3(0.40, 0.40, 0.37) * (0.85 + block.y * 0.25) * (1.0 - block.x * 0.45);
		vec3 moss_colour = mix(vec3(0.16, 0.30, 0.10), vec3(0.36, 0.56, 0.18), value_noise(pixel / 1.3));
		colour.rgb = mix(stone, moss_colour, moss);
		colour.rgb = mix(colour.rgb, vec3(0.78, 0.70, 0.30), step(0.97, cheap_hash(pixel)) * moss);
		return apply_burn(colour, pixel, condition);
	}

	// ---- stone, earth and masonry (98-112) ----
	if (id == 98) { // marble: warped grey veins, faint gold veins, polished slabs
		float field = fbm3(pixel / 9.0 + vec2(value_noise(pixel / 17.0) * 3.0, 0.0));
		float vein = field_contours(field, 2.0, 0.06);
		float gold = field_contours(fbm3(pixel / 13.0 + vec2(5.0)), 1.5, 0.02);
		colour.rgb *= 0.95 + value_noise(pixel / 6.0) * 0.07;
		colour.rgb = mix(colour.rgb, vec3(0.34, 0.36, 0.40), vein * 0.85);
		colour.rgb = mix(colour.rgb, vec3(0.78, 0.62, 0.32), gold * 0.55);
		float slab = max(1.0 - step(0.6, mod(pixel.x, 16.0)), 1.0 - step(0.6, mod(pixel.y, 12.0)));
		colour.rgb *= 1.0 - slab * 0.18;
		colour.rgb += vec3(0.07) * smoothstep(0.9, 1.0, 1.0 - triangle_wave((pixel.x + pixel.y) / 29.0));
		return colour;
	}
	if (id == 99) { // chalk: soft powdery blocks, smudges and loose dust on top
		vec2 block = block_courses(pixel, vec2(9.0, 6.0), 4.0);
		colour.rgb *= 0.95 + block.y * 0.05 + (value_noise(pixel / 4.0) - 0.5) * 0.08;
		colour.rgb *= 1.0 - block.x * 0.12;
		colour.rgb *= 1.0 - step(0.86, value_noise(pixel / 3.0 + vec2(11.0))) * 0.10;
		if (g.top_open) colour.rgb = colour.rgb * 1.04 + vec3(0.03);
		return colour;
	}
	if (id == 100) { // basalt columns: vertical prisms, faceted shading, cross-fractures
		float column = floor(pixel.x / 4.0);
		float facet = mod(pixel.x, 4.0);
		float shade = facet < 1.0 ? 1.18 : facet < 2.0 ? 1.0 : facet < 3.0 ? 0.86 : 0.72;
		float joint = 1.0 - step(0.75, facet);
		float fracture_y = mod(pixel.y + cheap_hash(vec2(column, 3.0)) * 17.0, 9.0 + floor(cheap_hash(vec2(column, 5.0)) * 8.0));
		float fracture = 1.0 - step(0.7, fracture_y);
		colour.rgb *= shade * (0.92 + cheap_hash(vec2(column, 1.0)) * 0.14);
		colour.rgb *= 1.0 - max(joint * 0.6, fracture * 0.45);
		colour.rgb += vec3(0.03) * step(0.9, cheap_hash(pixel));
		return colour;
	}
	if (id == 101) { // obsidian: glassy black with conchoidal ripples and sharp glints
		vec3 shell = cell_field(pixel, 6.0, 29.0);
		float ripple = field_contours(shell.x / 2.0, 1.0, 0.18);
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (shell.z + vec3(0.0, 0.33, 0.67)));
		colour.rgb *= 0.80 + (1.0 - shell.x / 5.0) * 0.40;
		colour.rgb += vec3(0.18, 0.16, 0.24) * ripple;
		colour.rgb += rainbow * 0.05 * ripple;
		colour.rgb += vec3(0.85, 0.85, 1.0) * static_glint(pixel, 0.988) * (1.0 - shell.x / 5.0);
		return colour;
	}
	if (id == 102) { // adobe: large mud bricks with straw flecks and eroded corners
		vec2 block = block_courses(pixel, vec2(9.0, 5.0), 21.0);
		float erosion = step(0.65, value_noise(pixel / 2.0)) * block.x;
		colour.rgb *= 0.88 + block.y * 0.16 + (value_noise(pixel / 3.0) - 0.5) * 0.10;
		colour.rgb *= 1.0 - block.x * 0.30 - erosion * 0.15;
		float straw = step(0.80, value_noise(vec2(pixel.x * 0.8 + pixel.y * 0.4, pixel.y * 1.6)))
			* step(0.6, cheap_hash(pixel + vec2(9.0)));
		colour.rgb = mix(colour.rgb, vec3(0.84, 0.70, 0.36), straw * 0.6);
		return colour;
	}
	if (id == 103) { // raw clay: smooth damp body with finger-smoothed swirls
		float smear = field_contours(fbm3(pixel / 6.0), 2.5, 0.08);
		colour.rgb *= 0.90 + value_noise(pixel / 5.0) * 0.12;
		colour.rgb *= 1.0 - smear * 0.14;
		colour.rgb += vec3(0.08, 0.06, 0.05) * smoothstep(0.88, 1.0, 1.0 - triangle_wave((pixel.x + pixel.y * 0.5) / 17.0));
		return colour;
	}
	if (id == 104) { // firebrick: pale buff refractory bricks, iron spots, glazed face
		vec2 block = block_courses(pixel, vec2(8.0, 4.0), 13.0);
		colour.rgb *= 0.92 + block.y * 0.14;
		colour.rgb = mix(colour.rgb, vec3(0.88, 0.84, 0.76), block.x * 0.75);
		colour.rgb = mix(colour.rgb, vec3(0.30, 0.18, 0.10), step(0.94, cheap_hash(pixel + vec2(7.0))) * (1.0 - block.x));
		return colour;
	}
	if (id == 105) { // packed snow: compression layers, blue shadow, glitter
		float layer = triangle_wave(pixel.y / 3.0 + value_noise(vec2(pixel.x / 9.0, 0.0)) * 1.5);
		colour.rgb *= 0.92 + layer * 0.08;
		colour.rgb = mix(colour.rgb, vec3(0.70, 0.80, 0.95), smoothstep(0.5, 1.0, 1.0 - min(g.down, 3.0) / 3.0) * 0.18);
		if (g.top_open) colour.rgb = vec3(0.98, 0.99, 1.0);
		float glitter = static_glint(pixel, 0.965) * step(0.75, cheap_hash(pixel + vec2(floor(t * 1.5))));
		colour.rgb += vec3(0.45, 0.55, 0.65) * glitter;
		return colour;
	}
	if (id == 106) { // rock salt: translucent pink/white halite crystals with inclusions
		vec3 crystal = cell_field(pixel, 4.0, 37.0);
		float face = 0.82 + crystal.z * 0.26;
		colour.rgb *= face;
		colour.rgb = mix(colour.rgb, vec3(0.97, 0.94, 0.92), step(0.7, crystal.z) * 0.35);
		colour.rgb *= 1.0 - (1.0 - smoothstep(0.2, 0.7, crystal.y)) * 0.25;
		colour.rgb = mix(colour.rgb, vec3(0.38, 0.34, 0.36), step(0.97, cheap_hash(pixel)) * 0.8);
		return colour;
	}
	if (id == 107) { // gypsum board: taped joints, screw rows, light paper texture
		float joint = 1.0 - step(1.6, mod(pixel.x, 24.0));
		float screw = step(mod(pixel.x, 24.0), 4.5) * (1.0 - step(0.6, abs(mod(pixel.x, 24.0) - 3.5)))
			* (1.0 - step(0.6, mod(pixel.y, 8.0)));
		colour.rgb *= 0.97 + value_noise(pixel / 2.0) * 0.04;
		colour.rgb *= 1.0 + joint * 0.04;
		colour.rgb *= 1.0 - screw * 0.30;
		if (g.edge < 0.5) colour.rgb *= 0.88;
		return colour;
	}
	if (id == 108) { // quicklime: chalky grain with crazed surface cracks
		vec3 craze = cell_field(pixel, 5.0, 43.0);
		colour.rgb *= 0.94 + cheap_hash(floor(pixel / 1.0)) * 0.06;
		colour.rgb *= 1.0 - (1.0 - smoothstep(0.0, 0.35, craze.y)) * 0.22;
		colour.rgb = mix(colour.rgb, vec3(0.94, 0.92, 0.80), smoothstep(0.6, 0.9, value_noise(pixel / 6.0)) * 0.2);
		return colour;
	}
	if (id == 109) { // rammed earth: wavering strata of ochre, red and umber with pebbles
		float wave = value_noise(vec2(pixel.x / 13.0, floor(pixel.y / 3.0))) * 1.6;
		float stratum = floor(pixel.y / 3.0 + wave);
		float pick = cheap_hash(vec2(stratum, 9.0));
		vec3 band = pick < 0.33 ? vec3(0.70, 0.48, 0.30) : pick < 0.66 ? vec3(0.60, 0.34, 0.22) : vec3(0.48, 0.34, 0.24);
		colour.rgb = mix(colour.rgb, band, 0.85) * (0.90 + value_noise(pixel / 2.0) * 0.14);
		colour.rgb *= 1.0 - (1.0 - step(0.6, fract(pixel.y / 3.0 + wave))) * 0.18;
		colour.rgb = mix(colour.rgb, vec3(0.62, 0.60, 0.56), step(0.95, cheap_hash(pixel)) * 0.8);
		float lift = 1.0 - step(0.7, mod(pixel.y, 12.0));
		colour.rgb *= 1.0 - lift * 0.18;
		return colour;
	}
	if (id == 110) { // sandbags: stacked burlap pillows with seams and weave
		float row = floor(pixel.y / 4.0);
		float shifted = pixel.x + mod(row, 2.0) * 4.0;
		vec2 local = vec2(mod(shifted, 8.0) - 3.5, mod(pixel.y, 4.0) - 1.5) / vec2(4.0, 2.0);
		float pillow = 1.0 - clamp(dot(local, local), 0.0, 1.0);
		float weave = step(0.5, mod(pixel.x + pixel.y, 2.0)) * 0.06;
		colour.rgb *= 0.55 + pillow * 0.55 + weave + (cheap_hash(vec2(floor(shifted / 8.0), row)) - 0.5) * 0.12;
		return colour;
	}
	if (id == 111) { // terrazzo: polished matrix with multicoloured chips
		vec3 chip = cell_field(pixel, 2.6, 61.0);
		float is_chip = 1.0 - smoothstep(0.55, 0.95, chip.x);
		vec3 chip_colour = chip.z < 0.2 ? vec3(0.62, 0.20, 0.16) : chip.z < 0.4 ? vec3(0.20, 0.42, 0.30)
			: chip.z < 0.6 ? vec3(0.12, 0.12, 0.13) : chip.z < 0.8 ? vec3(0.95, 0.94, 0.92) : vec3(0.80, 0.66, 0.42);
		colour.rgb = mix(colour.rgb * (0.96 + value_noise(pixel / 7.0) * 0.06), chip_colour, is_chip * step(0.35, chip.z + 0.2));
		colour.rgb += vec3(0.05) * smoothstep(0.9, 1.0, 1.0 - triangle_wave((pixel.x + pixel.y) / 31.0));
		return colour;
	}
	if (id == 112) { // gabion: packed fieldstones behind a bright wire grid
		vec3 stone = cell_field(pixel, 3.2, 71.0);
		float body = 0.70 + stone.z * 0.45;
		colour.rgb *= body * (1.0 - (1.0 - smoothstep(0.1, 0.6, stone.y)) * 0.55);
		colour.rgb = mix(colour.rgb, colour.rgb * vec3(1.05, 0.95, 0.85), step(0.7, stone.z) * 0.4);
		float wire = max(1.0 - step(0.6, mod(pixel.x, 6.0)), 1.0 - step(0.6, mod(pixel.y, 6.0)));
		colour.rgb = mix(colour.rgb, vec3(0.70, 0.74, 0.76), wire * 0.85);
		if (g.edge < 0.5) colour.rgb = vec3(0.62, 0.66, 0.68);
		return colour;
	}

	// ---- metals (113-119) ----
	if (id == 113) { // galvanised zinc: crystalline spangle flowers
		vec3 spangle = cell_field(pixel, 5.5, 83.0);
		float feather = triangle_wave(atan(pixel.y - floor(pixel.y / 5.5) * 5.5 - 2.75, pixel.x - floor(pixel.x / 5.5) * 5.5 - 2.75) * 1.6);
		colour.rgb *= 0.82 + spangle.z * 0.30 + feather * 0.04;
		colour.rgb *= 1.0 - (1.0 - smoothstep(0.0, 0.45, spangle.y)) * 0.12;
		float seam = 1.0 - step(0.7, mod(along, 20.0));
		colour.rgb *= 1.0 - seam * 0.35;
		return colour;
	}
	if (id == 114 || id == 119) { // aluminium / brass: brushed panels, rivets, glints
		float brushed = value_noise(vec2(along / 9.0, across * 2.3)) * 0.6 + cheap_hash(vec2(floor(along / 3.0), across)) * 0.4;
		vec2 panel = mod(pixel, vec2(14.0, 10.0));
		float seam = max(1.0 - step(0.6, panel.x), 1.0 - step(0.6, panel.y));
		float rivet = (1.0 - step(0.9, length(panel - vec2(1.5, 1.5))));
		colour.rgb *= mix(0.88 + brushed * 0.18, 0.55, seam);
		colour.rgb += vec3(0.20) * rivet;
		if (id == 119) colour.rgb = mix(colour.rgb, vec3(0.36, 0.40, 0.24), smoothstep(0.65, 0.9, fbm3(pixel / 6.0)) * 0.35);
		colour.rgb += vec3(manufactured_glint(pixel, 0.26) * (1.0 - seam) * 0.50);
		return colour;
	}
	if (id == 115) { // magnesium: bright silver sheet with white oxide bloom
		colour.rgb *= 0.92 + value_noise(vec2(along / 7.0, across * 1.5)) * 0.12;
		colour.rgb = mix(colour.rgb, vec3(0.90, 0.90, 0.88), smoothstep(0.55, 0.85, fbm3(pixel / 5.0)) * 0.30);
		float seam = max(1.0 - step(0.6, mod(pixel.x, 18.0)), 1.0 - step(0.6, mod(pixel.y, 12.0)));
		colour.rgb *= 1.0 - seam * 0.30;
		return colour;
	}
	if (id == 116) { // thermite brick: red oxide grain with silver aluminium flecks
		vec2 block = block_courses(pixel, vec2(8.0, 4.0), 31.0);
		colour.rgb *= 0.84 + value_noise(pixel / 1.5) * 0.24;
		colour.rgb = mix(colour.rgb, vec3(0.80, 0.82, 0.86), step(0.93, cheap_hash(pixel + vec2(17.0))) * 0.8);
		colour.rgb *= 1.0 - block.x * 0.45;
		return colour;
	}
	if (id == 117) { // bare iron: mill-scale mottle, heat tint and early flash rust
		float mottle = fbm3(pixel / 6.0);
		colour.rgb *= 0.84 + mottle * 0.26;
		colour.rgb = mix(colour.rgb, vec3(0.30, 0.30, 0.42), smoothstep(0.65, 0.85, value_noise(pixel / 9.0 + vec2(4.0))) * 0.25);
		vec2 rust = corrosion_field(pixel, g.top_open ? 0.2 : -0.1);
		colour.rgb = mix(colour.rgb, vec3(0.55, 0.26, 0.10), rust.x * 0.28 * step(0.55, mottle));
		return colour;
	}
	if (id == 118) { // gold leaf: overlapping gilded squares, crinkles and bright sparkle
		vec2 leaf = mod(pixel + vec2(floor(pixel.y / 5.0) * 1.3, 0.0), 5.0);
		float overlap = max(1.0 - step(0.6, leaf.x), 1.0 - step(0.6, leaf.y));
		float crinkle = field_contours(value_noise(pixel / 2.0), 2.0, 0.12);
		colour.rgb *= 0.86 + value_noise(pixel / 3.0) * 0.22 - overlap * 0.14 + crinkle * 0.10;
		colour.rgb += vec3(1.0, 0.86, 0.46) * manufactured_glint(pixel, 0.30) * 0.85;
		colour.rgb += vec3(0.40, 0.34, 0.16) * static_glint(pixel, 0.985);
		return colour;
	}

	// ---- glass and crystal (120-124) ----
	if (id == 120) { // glass blocks: rippled lenses in light mortar joints
		vec2 local = mod(pixel, 6.0) - vec2(2.5);
		float mortar = max(1.0 - step(0.8, mod(pixel.x, 6.0)), 1.0 - step(0.8, mod(pixel.y, 6.0)));
		float ripple = field_contours(length(local) / 2.2, 1.0, 0.25);
		colour.rgb += vec3(0.18, 0.26, 0.28) * ripple;
		colour.rgb = mix(colour.rgb, vec3(0.78, 0.78, 0.74), mortar);
		colour.a = mix(colour.a, 1.0, mortar);
		return colour;
	}
	if (id == 121) { // frosted glass: diffuse sparkle with clear polished borders
		colour.rgb *= 0.96 + fbm3(pixel / 1.5) * 0.08;
		colour.rgb += vec3(0.05) * static_glint(pixel, 0.94);
		if (g.edge < 1.5) { colour.rgb = colour.rgb * 0.8 + vec3(0.06, 0.10, 0.12); colour.a *= 0.75; }
		return colour;
	}
	if (id == 122) { // quartz: prismatic facets with rainbow dispersion edges
		vec3 facet = cell_field(pixel * vec2(0.6, 1.2), 3.5, 97.0);
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (facet.z * 2.0 + pixel.y * 0.04 + vec3(0.0, 0.33, 0.67)));
		float ridge = 1.0 - smoothstep(0.0, 0.45, facet.y);
		colour.rgb *= 0.88 + facet.z * 0.20;
		colour.rgb += rainbow * ridge * 0.22 + vec3(0.25) * ridge * step(0.6, facet.z);
		return colour;
	}
	if (id == 123) { // uranium glass: fluorescent green body with bright edges and seed bubbles
		colour.rgb *= 0.92 + value_noise(pixel / 4.0) * 0.12;
		if (g.edge < 0.5) colour.rgb = colour.rgb * 1.25 + vec3(0.10, 0.25, 0.05);
		vec2 bubble = lattice_particle(pixel, 5.0, 0.25, 101.0);
		colour.rgb = mix(colour.rgb, vec3(0.80, 1.0, 0.70), bubble.x * 0.5);
		return colour;
	}
	if (id == 124) { // sugar glass: amber with bubbles and fine stress cracks
		float crack = 1.0 - smoothstep(0.0, 0.04, abs(value_noise(pixel / 5.0) - 0.5));
		vec2 bubble = lattice_particle(pixel, 4.0, 0.30, 103.0);
		colour.rgb *= 0.92 + value_noise(pixel / 3.0) * 0.12;
		colour.rgb += vec3(0.30, 0.24, 0.12) * crack;
		colour.rgb = mix(colour.rgb, vec3(1.0, 0.92, 0.70), bubble.x * 0.45);
		return colour;
	}

	// ---- chemical and industrial (125-131) ----
	if (id == 125) { // wax: soft translucent body, drip runs under open edges
		colour.rgb *= 0.94 + value_noise(pixel / 6.0) * 0.08;
		colour.rgb = mix(colour.rgb, vec3(1.0, 0.96, 0.84), smoothstep(0.6, 1.0, cylinder) * 0.12);
		if (g.bottom_open || g.down < 1.5) {
			float drip = step(0.55, cheap_hash(vec2(pixel.x, 7.0)));
			colour.rgb = mix(colour.rgb, colour.rgb * 1.08 + vec3(0.03), drip * 0.6);
		}
		return colour;
	}
	if (id == 126) { // sulfur: clustered needle crystals with orange-ochre tint
		float needle = triangle_wave((pixel.x * 0.8 + pixel.y * 1.7 + value_noise(pixel / 4.0) * 6.0) / 2.5);
		vec3 cluster = cell_field(pixel, 4.0, 113.0);
		colour.rgb *= 0.80 + needle * 0.22 + cluster.z * 0.10;
		colour.rgb = mix(colour.rgb, vec3(0.86, 0.56, 0.12), step(0.78, cluster.z) * 0.35);
		colour.rgb *= 1.0 - (1.0 - smoothstep(0.0, 0.4, cluster.y)) * 0.25;
		return colour;
	}
	if (id == 127) { // phosphor: hex-dot luminous tile with a slow breathing afterglow
		vec2 local = mod(pixel + vec2(mod(floor(pixel.y / 3.0), 2.0) * 1.5, 0.0), vec2(3.0, 3.0)) - vec2(1.0);
		float lit_dot = 1.0 - step(0.9, length(local));
		float breathe = 0.80 + 0.20 * sin(t * 0.8 + value_noise(pixel / 13.0) * 6.0);
		colour.rgb *= mix(0.70, 1.15 * breathe, lit_dot);
		return colour;
	}
	if (id == 128) { // polymer panel: moulded ribs, sprue marks and a glossy band
		float rib = 1.0 - step(1.0, mod(along, 7.0));
		float gloss = smoothstep(0.88, 1.0, 1.0 - triangle_wave((pixel.x - pixel.y * 0.5) / 27.0));
		colour.rgb *= 0.92 + value_noise(pixel / 8.0) * 0.08 + rib * 0.12;
		colour.rgb += vec3(0.26, 0.30, 0.34) * gloss;
		colour.rgb *= 1.0 - (1.0 - step(0.9, length(mod(pixel, 16.0) - vec2(8.0)))) * 0.25;
		return colour;
	}
	if (id == 129) { // solar panel: blue cells, silver busbars, sky reflection, frame
		vec2 cell = mod(pixel, 6.0);
		float gap = max(1.0 - step(0.6, cell.x), 1.0 - step(0.6, cell.y));
		float busbar = 1.0 - step(0.5, abs(cell.x - 3.0));
		float reflection = smoothstep(0.0, 1.0, 1.0 - fract((pixel.x + pixel.y * 1.3) / 47.0)) * 0.12;
		colour.rgb = mix(colour.rgb * (0.90 + cheap_hash(floor(pixel / 6.0)) * 0.10), vec3(0.62, 0.66, 0.70), max(gap * 0.9, busbar * 0.35));
		colour.rgb += vec3(0.25, 0.32, 0.45) * reflection;
		if (g.edge < 0.5) colour.rgb = vec3(0.62, 0.65, 0.68);
		return colour;
	}
	if (id == 130) { // carbon fibre: 2x2 twill weave with alternating sheen
		vec2 tow = floor(pixel / 2.0);
		bool warp = mod(tow.x + tow.y, 4.0) < 2.0;
		float sheen = warp ? 1.10 + 0.35 * (1.0 - triangle_wave(pixel.x / 7.0)) : 0.55 + 0.20 * (1.0 - triangle_wave(pixel.y / 7.0));
		colour.rgb *= sheen;
		colour.rgb += vec3(0.05, 0.05, 0.06) * smoothstep(0.85, 1.0, 1.0 - triangle_wave((pixel.x + pixel.y) / 19.0));
		return colour;
	}
	if (id == 131) { // heat-shield tiles: black squares, pale gap filler, scorched edges
		vec2 tile = mod(pixel, 6.0);
		float gap = max(1.0 - step(0.6, tile.x), 1.0 - step(0.6, tile.y));
		colour.rgb *= 0.88 + cheap_hash(floor(pixel / 6.0)) * 0.22;
		colour.rgb = mix(colour.rgb, vec3(0.78, 0.76, 0.70), gap * 0.75);
		colour.rgb = mix(colour.rgb, vec3(0.42, 0.38, 0.34), smoothstep(0.6, 0.9, value_noise(pixel / 3.0)) * 0.15 * (1.0 - gap));
		return colour;
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

	if (flair == 13) { // Oil: swirling marbled slick (owner direction 2026-10-18 pass 2)
		float t = presentation_time();
		float swirl = swirl_field(pixel / 9.0, t, OIL_WAVE_RATE * 2.2);
		float eddy = swirl_field(pixel / 4.0 + vec2(7.7, 2.9), t, OIL_WAVE_RATE * 3.6);
		float lines = field_contours(swirl, 3.0, 0.16);
		// Suppress the per-cell palette dither: a slick is smooth.
		colour.rgb = mix(colour.rgb, vec3(0.20, 0.18, 0.21), 0.55);
		colour.rgb *= 0.72 + swirl * 0.42 + eddy * 0.10;
		// Thin-film rainbow follows the same warped field, so colour pools and
		// curls with the eddies instead of riding straight crests.
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (swirl * 1.9 + eddy * 0.6 + vec3(0.0, 0.33, 0.67)));
		colour.rgb += rainbow * (0.03 + lines * 0.26 + smoothstep(0.58, 0.80, eddy) * 0.10);
		float seed = cheap_hash(pixel);
		float sparkle = step(0.975, seed) * smoothstep(0.70, 0.86, eddy)
			* (0.5 + 0.5 * sin(t * 3.0 + seed * 40.0));
		colour.rgb += vec3(0.58, 0.72, 0.82) * sparkle;
		if (condition > 0.02) { // burning Oil: licking surface flames
			float lick = fbm3(vec2(pixel.x / 3.0, pixel.y / 2.0 + t * 2.6));
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

	if (flair == 17) { // organic rust: blotches, flaking scale, spill runs, clustered pits
		vec2 rust = corrosion_field(pixel, 0.0);
		float flake = fbm3(pixel / 2.3 + vec2(11.0, 4.0));
		vec3 orange = vec3(0.74, 0.33, 0.11);
		vec3 ochre = vec3(0.78, 0.53, 0.20);
		vec3 deep = vec3(0.24, 0.08, 0.04);
		float tone = smoothstep(0.30, 0.75, flake);
		vec3 scale = mix(deep * 1.6, mix(orange, ochre, smoothstep(0.62, 0.86, flake)), tone);
		colour.rgb = mix(colour.rgb * (0.78 + flake * 0.30), scale, 0.35 + rust.x * 0.45);
		colour.rgb = mix(colour.rgb, deep, rust.y * 0.70);
		float pit = step(0.80, value_noise(pixel / 1.4 + vec2(5.0))) * rust.x;
		colour.rgb *= mix(1.0, 0.45, pit);
		colour.rgb += vec3(0.08, 0.05, 0.02) * step(0.985, cheap_hash(pixel + vec2(31.0, 11.0))) * tone;
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
		float ripple = swirl_field(pixel / 9.0, presentation_time(), 0.11);
		colour.rgb *= 0.90 + ripple * 0.15 + field_contours(ripple, 3.0, 0.06) * 0.05;
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
		// Last part of the lifetime dissolves from the thin wisps inward, so
		// the cell is nearly transparent before it becomes Empty.
		float fade = smoothstep(0.0, 0.32, condition);
		colour.a *= mix(smoothstep(0.35, 0.85, wisp), 1.0, fade);
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
		colour.rgb = mix(colour.rgb, vec3(0.97, 0.985, 1.0), 0.70 + vapour * 0.30);
		colour.a *= 0.74 + vapour * 0.26;
		colour.a *= mix(smoothstep(0.30, 0.80, vapour), 1.0, smoothstep(0.0, 0.25, condition));
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
		float swirl = swirl_field(pixel / 6.5, presentation_time(), speed * 1.6);
		vec3 reactive_tint = material_id == 12
			? vec3(0.34, 0.42, 0.04)
			: vec3(0.05, 0.26, 0.05);
		colour.rgb *= (material_id == 12 ? 0.72 : 0.62) + swirl * 0.34;
		if (material_id == 32) { // toxic sludge: smooth dark depths with oily green filaments
			colour.rgb = mix(colour.rgb, vec3(0.10, 0.27, 0.08), 0.45);
			colour.rgb = mix(colour.rgb, vec3(0.03, 0.09, 0.03), smoothstep(0.30, 0.10, swirl) * 0.6);
			colour.rgb += vec3(0.10, 0.34, 0.06) * field_contours(swirl, 4.0, 0.07);
		}
		colour.rgb += reactive_tint * bubble * 0.75;
		vec2 fizz = lattice_particle(pixel + vec2(sin(presentation_time() * 2.0 + pixel.y) * 0.5,
			presentation_time() * speed * 60.0), 4.0, 0.35, 19.0);
		colour.rgb = mix(colour.rgb, reactive_tint * 2.4 + vec3(0.15), fizz.x * (material_id == 12 ? 0.65 : 0.22));
		float froth = smoothstep(0.62, 0.80, fbm3(pixel / 3.0 + vec2(presentation_time() * speed * 2.0, 0.0)));
		colour.rgb += reactive_tint * froth * 0.35;
		return colour;
	}

	if (flair == 40) { // Mercury: swirling liquid-metal reflections and pin highlights
		float t = presentation_time();
		float swirl = swirl_field(pixel / 8.0, t, 0.16);
		float detail = swirl_field(pixel / 3.5 + vec2(3.3, 8.1), t, 0.27);
		// Fake environment map: the warped field indexes a dark/bright horizon.
		float env = smoothstep(0.30, 0.70, swirl + (detail - 0.5) * 0.35);
		colour.rgb *= 0.46 + env * 0.78;
		colour.rgb += vec3(0.30, 0.36, 0.42) * field_contours(swirl, 3.0, 0.07);
		float pin = step(0.982, cheap_hash(pixel)) * smoothstep(0.62, 0.80, detail)
			* (0.5 + 0.5 * sin(t * 5.0 + cheap_hash(pixel + vec2(2.0)) * 30.0));
		colour.rgb += vec3(0.55, 0.62, 0.70) * pin;
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
		float settle = swirl_field(pixel / 11.0, presentation_time(), 0.045);
		colour.rgb *= 0.86 + lump * 0.16;
		colour.rgb *= 1.0 - 0.05 * wet + settle * 0.08 * wet;
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
		float melt = swirl_field(pixel / 8.0, presentation_time(), 0.05);
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

	if (flair == 47) { // Plant: jittered leaf clusters, midribs, stems and a gentle sway
		float t = presentation_time();
		vec2 sway = vec2(sin(t * 0.9 + pixel.y * 0.35) * 0.35, 0.0);
		vec3 leaf_cell = cell_field(pixel + sway, 2.7, 5.0);
		float leaf = 1.0 - smoothstep(0.7, 1.7, leaf_cell.x);
		float gap = 1.0 - smoothstep(0.0, 0.35, leaf_cell.y);
		float angle = leaf_cell.z * 6.2832;
		vec2 local = fract((pixel + sway) / 2.7) - vec2(0.5);
		float midrib = 1.0 - smoothstep(0.0, 0.18, abs(dot(local, vec2(-sin(angle), cos(angle)))));
		float stem = 1.0 - smoothstep(0.0, 0.08, abs(value_noise(pixel / vec2(2.5, 6.0)) - 0.5));
		float vigour = 0.85 + smoothstep(0.0, 0.5, condition) * 0.25;
		vec3 light_leaf = mix(vec3(0.28, 0.62, 0.24), vec3(0.52, 0.78, 0.26), leaf_cell.z);
		vec3 dark_leaf = vec3(0.08, 0.24, 0.10);
		colour.rgb = mix(dark_leaf, light_leaf, leaf * (1.0 - gap * 0.7)) * vigour;
		colour.rgb += vec3(0.06, 0.08, 0.02) * midrib * leaf;
		colour.rgb = mix(colour.rgb, vec3(0.20, 0.34, 0.13), stem * 0.45);
		return colour;
	}

	if (flair == 48) { // Fungus: mycelium web, fruiting knots and bioluminescent pulses
		float t = presentation_time();
		float hypha_a = 1.0 - smoothstep(0.0, 0.07, abs(value_noise(pixel / 3.1) - 0.5));
		float hypha_b = 1.0 - smoothstep(0.0, 0.05, abs(value_noise(pixel / 1.7 + vec2(19.0, 3.0)) - 0.5));
		float web = max(hypha_a, hypha_b * 0.7);
		vec3 substrate = mix(vec3(0.26, 0.14, 0.24), vec3(0.42, 0.24, 0.38), value_noise(pixel / 4.0));
		colour.rgb = mix(colour.rgb * 0.55, substrate, 0.55);
		colour.rgb = mix(colour.rgb, vec3(0.92, 0.86, 0.90), web * 0.75);
		vec2 knot = lattice_particle(pixel, 5.0, 0.40, 53.0);
		float pulse = smoothstep(0.80, 1.0, 1.0 - triangle_wave(
			value_noise(pixel / 9.0) * 3.0 - t * 0.18));
		colour.rgb = mix(colour.rgb, vec3(0.95, 0.55, 1.0), knot.x * (0.35 + 0.5 * (0.5 + 0.5 * sin(t * 1.4 + knot.y * 20.0))));
		colour.rgb += vec3(0.45, 0.20, 0.60) * web * pulse;
		return colour;
	}

	if (flair == 49) { // Mite: iridescent chitin with glistening highlights
		float t = presentation_time();
		float seed = cheap_hash(pixel + vec2(91.0));
		float film = fract(seed * 0.35 + t * 0.22 + (pixel.x - pixel.y) * 0.045);
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (film + vec3(0.0, 0.33, 0.67)));
		colour.rgb = mix(colour.rgb * 0.85, rainbow * 1.10 + vec3(0.12), 0.70);
		float glisten = smoothstep(0.92, 1.0, sin(t * 6.0 + seed * 50.0) * 0.5 + 0.5);
		colour.rgb += vec3(0.85, 0.90, 1.0) * glisten * 0.85;
		return colour;
	}

	if (flair == 50) { // Rocket: striped casing; an activated firework burns white-gold
		float t = presentation_time();
		if (condition > 0.0005) {
			float flicker = 0.75 + 0.25 * sin(t * 37.0 + cheap_hash(pixel) * 60.0);
			colour.rgb = mix(heat_ramp(0.92), vec3(1.0, 0.96, 0.86), 0.5) * (1.15 + flicker * 0.45);
			return colour;
		}
		float stripe = step(0.5, fract((pixel.x + pixel.y) / 4.0));
		colour.rgb = mix(colour.rgb, vec3(0.86, 0.18, 0.22), stripe * 0.65);
		colour.rgb += vec3(0.10) * step(0.6, sin(t * 2.0 + pixel.x) * 0.5 + 0.5) * 0.3;
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
	return (id == 7 || id == 16 || id == 27 || id == 46 || id == 47 || (id >= 81 && id <= 97))
		&& cell.g > 0.02;
}

bool is_plant_host(int id) {
	return id == 11 || id == 97;
}

vec3 petal_colour(float h) {
	if (h < 0.2) return vec3(0.95, 0.45, 0.72);
	if (h < 0.4) return vec3(1.0, 0.84, 0.25);
	if (h < 0.6) return vec3(0.96, 0.95, 0.92);
	if (h < 0.8) return vec3(0.66, 0.46, 0.96);
	return vec3(0.93, 0.24, 0.22);
}

// Presentation-only growth drawn into Empty cells next to Plant, Moss Wall and
// Fungus: flowers, leaves and grass tufts on top of Plant, mushrooms on top of
// Fungus, and vines/hyphae hanging beneath them. Each three-column group hosts
// at most one sprout found by scanning its centre column (<= 6 reads, 45% of
// groups); hanging growth scans the pixel's own column (<= 5 reads, 32% of
// columns). Nothing is simulated.
vec4 apply_growth_decor(vec4 colour, vec2 pixel) {
	if (growth_decor < 0.5) return colour;
	float t = presentation_time();
	float group = floor(pixel.x / 3.0);
	float centre = group * 3.0 + 1.0;
	float dx = pixel.x - centre;
	float pick = cheap_hash(vec2(group, 211.0));
	if (pick > 0.55) {
		int host = 0;
		float level = 0.0;
		for (int k = 0; k <= 5; k++) {
			if (k == 0 && dx == 0.0) continue;
			int id = sampled_material_id(vec2(centre, pixel.y + float(k)), false);
			if (id != 0) {
				host = k == 0 ? -1 : id;
				level = float(k);
				break;
			}
		}
		float shape = cheap_hash(vec2(group, 223.0));
		float tone = cheap_hash(vec2(group, 229.0));
		if (is_plant_host(host)) {
			if (pick < 0.70) { // grass tuft
				float blade = 1.0 + floor(shape * 2.0);
				bool tuft = (dx == 0.0 && level <= blade) || (abs(dx) == 1.0 && level <= 1.0 && cheap_hash(pixel) > 0.4);
				if (tuft) colour.rgb = mix(vec3(0.20, 0.46, 0.16), vec3(0.42, 0.70, 0.22), cheap_hash(pixel + vec2(3.0)));
				return colour;
			}
			float stem = 1.0 + floor(shape * 3.0);
			float sway = sin(t * 1.1 + group * 1.7) * 0.5;
			if (dx == 0.0 && level <= stem) {
				colour.rgb = vec3(0.22, 0.48, 0.18) * (0.85 + 0.15 * sway);
			} else if (level == stem + 1.0 && abs(dx) <= 1.0) {
				colour.rgb = dx == 0.0 ? vec3(0.98, 0.78, 0.20) : petal_colour(tone);
			} else if (level == stem + 2.0 && dx == 0.0) {
				colour.rgb = petal_colour(tone) * 1.05;
			} else if (stem >= 2.0 && level == floor(stem * 0.5 + 0.5) && dx == (tone > 0.5 ? 1.0 : -1.0)) {
				colour.rgb = vec3(0.30, 0.62, 0.22);
			}
			return colour;
		}
		if (host == 18) {
			float stalk = pick < 0.70 ? 0.0 : 1.0 + floor(shape * 2.0);
			vec3 cap = tone < 0.35 ? vec3(0.82, 0.16, 0.14)
				: tone < 0.65 ? vec3(0.56, 0.38, 0.24)
				: mix(vec3(0.55, 0.30, 0.95), vec3(0.30, 0.95, 0.95), step(0.85, tone));
			bool glowing = tone >= 0.65;
			float pulse = glowing ? 1.15 + 0.35 * sin(t * 1.6 + group) : 1.0;
			if (dx == 0.0 && level <= stalk) {
				colour.rgb = vec3(0.86, 0.80, 0.70) * (0.85 + level * 0.04);
			} else if (level == stalk + 1.0 && (abs(dx) <= 1.0 || stalk == 0.0 && dx == 0.0)) {
				if (stalk == 0.0 && dx != 0.0) return colour;
				colour.rgb = cap * pulse * (dx == 0.0 ? 1.0 : 0.82);
				if (tone < 0.35 && cheap_hash(pixel + vec2(5.0)) > 0.6) colour.rgb = vec3(0.96, 0.94, 0.90);
			} else if (stalk > 0.0 && level == stalk + 2.0 && dx == 0.0) {
				colour.rgb = cap * pulse * 1.10;
			}
			return colour;
		}
	}
	// Hanging growth from the underside of Plant / Moss Wall / Fungus.
	if (cheap_hash(vec2(pixel.x, 307.0)) > 0.68) {
		float reach = 2.0 + floor(cheap_hash(vec2(pixel.x, 311.0)) * 4.0);
		for (int k = 1; k <= 5; k++) {
			if (float(k) > reach) break;
			int id = sampled_material_id(pixel - vec2(0.0, float(k)), false);
			if (id == 0) continue;
			if (is_plant_host(id)) {
				float leaf = step(0.5, mod(pixel.y + pixel.x, 3.0));
				colour.rgb = mix(vec3(0.14, 0.36, 0.14), vec3(0.32, 0.62, 0.22), leaf);
				if (float(k) == reach && cheap_hash(vec2(pixel.x, 313.0)) > 0.6) {
					colour.rgb = petal_colour(cheap_hash(vec2(pixel.x, 317.0)));
				}
			} else if (id == 18 && float(k) <= reach * 0.6) {
				float pulse = 0.5 + 0.5 * sin(t * 1.3 - pixel.y * 0.8 + pixel.x);
				colour.rgb = mix(colour.rgb, vec3(0.88, 0.80, 0.92), 0.45 + pulse * 0.25);
			}
			break;
		}
	}
	return colour;
}

vec4 apply_vapour_trail(vec4 colour, vec2 pixel) {
	if (vapour_trail_strength <= 0.0) return colour;
	vec2 uv = (pixel - vapour_trail_origin_px + vec2(0.5)) / view_size_px;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return colour;
	vec2 ghost = texture(vapour_trail_texture, uv).rg * vapour_trail_strength;
	if (ghost.x + ghost.y < 0.01) return colour;
	float t = presentation_time();
	float wisp = 0.55 + 0.45 * fbm3(pixel / 4.0 + vec2(t * 0.25, t * 0.8));
	colour.rgb = mix(colour.rgb, vec3(0.42, 0.44, 0.48), clamp(ghost.y * wisp * 0.50, 0.0, 0.50));
	colour.rgb = mix(colour.rgb, vec3(0.95, 0.97, 1.0), clamp(ghost.x * wisp * 0.62, 0.0, 0.62));
	return colour;
}

// Presentation-only particles drawn in Empty cells: embers rising above hot
// sources and fumes above reactive liquids. The arithmetic particle test runs
// first; only a candidate particle pixel reads up to three cells below it.
vec4 apply_ambient_particles(vec4 colour, vec2 pixel) {
	float t = presentation_time();
	colour = apply_growth_decor(colour, pixel);
	colour = apply_vapour_trail(colour, pixel);
	// Firework sparks around an activated Rocket (flight state > 0).
	vec2 spark = lattice_particle(pixel + vec2(sin(t * 5.0 + pixel.y) * 0.6, t * 11.0), 3.0, 0.55, 131.0);
	if (spark.x > 0.5) {
		for (int k = 0; k < 4; k++) {
			vec2 offset = k == 0 ? vec2(1.0, 0.0) : k == 1 ? vec2(-1.0, 0.0) : k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0);
			vec2 near = sampled_cell(pixel + offset * (1.0 + step(0.5, spark.y)));
			if (cell_material(near) == 17 && near.g > 0.0005) {
				vec3 hue = 0.5 + 0.5 * cos(6.2832 * (floor(t * 5.0) * 0.17 + spark.y + vec3(0.0, 0.33, 0.67)));
				float flash = 0.6 + 0.4 * sin(t * 29.0 + spark.y * 70.0);
				colour.rgb = mix(colour.rgb, (hue * 0.6 + vec3(0.6)) * 1.4, flash);
				return colour;
			}
		}
	}
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
	vec2 leak = lattice_particle(
		pixel + vec2(sin(t * 1.3 + pixel.y * 0.5) * 1.0, t * 6.0), 4.0, 0.35, 29.0);
	if (leak.x > 0.5 && cheap_hash(floor(pixel / 14.0) + vec2(5.0)) > 0.72) {
		int side = cell_material(sampled_cell(pixel + vec2(0.0, 2.0)));
		if (side != 68 && side != 69) side = cell_material(sampled_cell(pixel + vec2(0.0, 4.0)));
		if (side == 68 || side == 69) {
			float puff = 0.45 + 0.35 * sin(t * 4.0 + leak.y * 20.0);
			colour.rgb = mix(colour.rgb, vec3(0.86, 0.90, 0.92), puff);
			return colour;
		}
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

// ---------------------------------------------------------------------------
// Shape-aware ("space-filling") construction fills. A pixel measures how far
// its own material continues in each cardinal direction (bounded run-length:
// reads at 2, 3, 5 and 8 cells after the shared neighbour), then generates
// orientation, cross-section and region-anchored patterns from that. Only the
// materials listed in uses_structured_fill() pay for the extra reads. All of
// it is time-independent except deliberate manufactured effects (cable data
// pulses, neon plasma).

bool uses_structured_fill(int material_id) {
	if (structured_detail < 0.5) return false;
	// Every static construction surface plus Wall, Cloner, Wood, Ice, Metal,
	// Concrete and Glass.
	return material_id == 1 || material_id == 5 || material_id == 7 || material_id == 9
		|| material_id == 28 || material_id == 31 || material_id == 35
		|| (material_id >= 38 && material_id <= LAST_MATERIAL_ID);
}

bool is_open_cell(int id) {
	return id == 0 || id == 4 || id == 6 || id == 22 || id == 34 || id == 37;
}

// Vertical weathering run hanging from a top edge: some world columns carry a
// stain whose length is hashed per column (up to 8 cells, the probe limit).
float drip_streak(vec2 pixel, float up, float salt) {
	float column = cheap_hash(vec2(pixel.x, salt));
	float length_cells = 1.5 + cheap_hash(vec2(pixel.x, salt + 5.0)) * 6.5;
	return step(0.70, column) * (1.0 - smoothstep(0.0, length_cells, up));
}

float run_length(vec2 pixel, vec2 direction, int material_id, int first, bool previous_snapshot) {
	if (first != material_id) return 0.0;
	if (sampled_material_id(pixel + direction * 2.0, previous_snapshot) != material_id) return 1.0;
	if (sampled_material_id(pixel + direction * 3.0, previous_snapshot) != material_id) return 2.0;
	if (sampled_material_id(pixel + direction * 5.0, previous_snapshot) != material_id) return 3.0;
	if (sampled_material_id(pixel + direction * 8.0, previous_snapshot) != material_id) return 5.0;
	return 8.0;
}

// x = cells of the same material above, y = below, z = left, w = right.
vec4 region_extent(vec2 pixel, int material_id, ivec4 neighbours, bool previous_snapshot) {
	return vec4(
		run_length(pixel, vec2(0.0, -1.0), material_id, neighbours.x, previous_snapshot),
		run_length(pixel, vec2(0.0, 1.0), material_id, neighbours.y, previous_snapshot),
		run_length(pixel, vec2(-1.0, 0.0), material_id, neighbours.z, previous_snapshot),
		run_length(pixel, vec2(1.0, 0.0), material_id, neighbours.w, previous_snapshot)
	);
}

BuildGeometry probed_build_geometry(vec2 pixel, ivec4 neighbours, vec4 extent) {
	float span_x = extent.z + extent.w + 1.0;
	float span_y = extent.x + extent.y + 1.0;
	float long_x = (extent.z >= 8.0 || extent.w >= 8.0) ? 99.0 : span_x;
	float long_y = (extent.x >= 8.0 || extent.y >= 8.0) ? 99.0 : span_y;
	BuildGeometry g;
	g.horizontal = long_x >= long_y;
	g.along = g.horizontal ? pixel.x : pixel.y;
	g.across_world = g.horizontal ? pixel.y : pixel.x;
	g.across_span = g.horizontal ? span_y : span_x;
	g.across_u = ((g.horizontal ? extent.x : extent.z) + 0.5) / g.across_span;
	g.edge = min(min(extent.x, extent.y), min(extent.z, extent.w));
	g.up = extent.x;
	g.down = extent.y;
	g.top_open = extent.x < 0.5 && is_open_cell(neighbours.x);
	g.bottom_open = extent.y < 0.5 && is_open_cell(neighbours.y);
	return g;
}

vec4 apply_detail_edges(
	vec4 colour,
	int material_id,
	int flair,
	vec2 pixel,
	vec4 extent,
	float edge,
	bool exposed,
	float condition
) {
	colour = apply_material_flair(colour, material_id, flair, pixel, condition);
	if (material_id == 43 || material_id == 57) { // soldier course and corner quoins
		if (extent.x < 3.5 && extent.x > 0.5) {
			float header = 1.0 - step(0.6, mod(pixel.x, 2.0));
			colour.rgb *= 1.0 - header * 0.40;
		}
		bool corner_side = extent.z < 2.5 || extent.w < 2.5;
		if (corner_side && mod(floor(pixel.y / 4.0), 2.0) < 0.5) {
			colour.rgb = mix(colour.rgb, vec3(0.70, 0.66, 0.58) * (0.85 + cheap_hash(floor(pixel / 4.0)) * 0.2), 0.75);
		}
	} else if (material_id == 70) { // bullnose trim on exposed tile edges
		if (exposed) colour.rgb = colour.rgb * 1.12 + vec3(0.05);
		else if (edge < 1.5) colour.rgb *= 0.86;
	} else if (material_id == 58) { // tie holes and exposed rebar
		vec2 tie = mod(pixel, vec2(10.0, 8.0)) - vec2(5.0, 4.0);
		colour.rgb *= 1.0 - (1.0 - step(0.8, length(tie))) * 0.55;
		if (exposed && cheap_hash(floor(pixel / 2.0) + vec2(9.0)) > 0.55) {
			colour.rgb = vec3(0.42, 0.20, 0.10) * (0.8 + cheap_hash(pixel) * 0.4);
		}
	}
	return colour;
}

vec4 apply_structured_fill(
	vec4 colour,
	int material_id,
	int flair,
	vec2 pixel,
	ivec4 neighbours,
	vec4 extent,
	float condition
) {
	float t = presentation_time();
	// Run geometry. Horizontal when the run is at least as wide as it is tall.
	float span_x = extent.z + extent.w + 1.0;
	float span_y = extent.x + extent.y + 1.0;
	// A direction that reached the 8-cell probe is treated as long, so large
	// panels do not flip orientation near their edges; those use a default.
	float long_x = (extent.z >= 8.0 || extent.w >= 8.0) ? 99.0 : span_x;
	float long_y = (extent.x >= 8.0 || extent.y >= 8.0) ? 99.0 : span_y;
	bool large = long_x > 50.0 && long_y > 50.0;
	bool horizontal = large ? material_id != 64 : long_x >= long_y;
	float across_pos = horizontal ? extent.x : extent.z;          // cells from the near edge
	float across_span = horizontal ? span_y : span_x;
	float across_u = (across_pos + 0.5) / across_span;           // 0..1 across the run
	float along = horizontal ? pixel.x : pixel.y;                // world-anchored along axis
	float across_world = horizontal ? pixel.y : pixel.x;
	float edge = min(min(extent.x, extent.y), min(extent.z, extent.w));
	bool exposed = edge < 0.5;

	if (material_id == 68 || material_id == 69) { // pipes
		float cylinder = sqrt(max(0.0, 1.0 - pow(across_u * 2.0 - 1.0, 2.0)));
		float specular = smoothstep(0.80, 1.0, 1.0 - abs(across_u - 0.30) * 3.2);
		float segment = floor(along / 14.0);
		float in_segment = mod(along, 14.0);
		float flange = 1.0 - step(1.0, in_segment);
		float bolt = flange * step(0.5, abs(across_u - 0.5) * 2.0 - 0.45);
		bool junction = abs(span_x - span_y) < 1.5 && span_x > 2.0;
		colour.rgb *= 0.30 + cylinder * 0.95;
		colour.rgb += vec3(0.38) * specular * (1.0 - flange);
		colour.rgb *= 1.0 - (1.0 - cylinder) * 0.25;
		colour.rgb = mix(colour.rgb, colour.rgb * 0.62 + vec3(0.04), flange);
		colour.rgb += vec3(0.22) * bolt;
		if (junction) {
			float box = step(0.5, mod(pixel.x + pixel.y, 2.0));
			colour.rgb = mix(colour.rgb, colour.rgb * 0.7, 0.5) + vec3(0.06) * box;
		}
		if (material_id == 69) { // copper patina pooled underneath
			float patina = smoothstep(0.55, 0.85, value_noise(pixel / 3.0)) * smoothstep(0.5, 1.0, across_u);
			colour.rgb = mix(colour.rgb, vec3(0.25, 0.55, 0.45), patina * 0.6);
		}
		return colour;
	}

	if (material_id == 76) { // hazard stripes anchored to the panel
		float thickness = min(long_x, long_y);
		float width = clamp(floor(across_span / 3.0), 2.0, 5.0);
		float stripe;
		if (thickness <= 5.0) { // thin strip: chevrons pointing along the run
			float c = abs(across_pos - (across_span - 1.0) * 0.5);
			stripe = step(0.5, fract((along + c) / (width * 2.0)));
		} else {
			stripe = step(0.5, fract((pixel.x + pixel.y) / 8.0));
		}
		vec3 yellow = colour.rgb * 1.08;
		vec3 black = vec3(0.045, 0.05, 0.055);
		colour.rgb = mix(black, yellow, stripe);
		float worn = step(0.72, value_noise(pixel / 1.6)) * step(0.6, cheap_hash(pixel));
		colour.rgb = mix(colour.rgb, vec3(0.38, 0.40, 0.42), worn * 0.45);
		if (exposed && thickness > 5.0) colour.rgb = black * 1.6;
		return colour;
	}

	if (material_id == 75) { // quilted insulation batts with foil facing
		vec2 quilt = mod(pixel, vec2(7.0, 5.0));
		vec2 centred = (quilt - vec2(3.0, 2.0)) / vec2(3.5, 2.5);
		float puff = 1.0 - clamp(dot(centred, centred), 0.0, 1.0);
		float seam = step(quilt.x, 0.5) + step(quilt.y, 0.5);
		float stitch = seam * step(0.5, mod(pixel.x + pixel.y, 2.0));
		float fibre = triangle_wave((pixel.x * 1.7 - pixel.y) / 4.0);
		colour.rgb *= 0.62 + puff * 0.42 + fibre * 0.10;
		colour.rgb *= 1.0 - stitch * 0.35;
		if (exposed) { // crinkled reflective foil on the open face
			float crinkle = value_noise(pixel * 0.9);
			colour.rgb = vec3(0.62, 0.64, 0.66) * (0.65 + crinkle * 0.55);
		}
		return colour;
	}

	if (material_id == 74) { // round cables running along the bundle
		float lane = floor(across_world);
		float pick = cheap_hash(vec2(lane, 17.0));
		vec3 jacket = pick < 0.25 ? vec3(0.08, 0.66, 0.85)
			: pick < 0.50 ? vec3(0.88, 0.17, 0.48)
			: pick < 0.75 ? vec3(0.92, 0.62, 0.10) : vec3(0.16, 0.16, 0.18);
		float round_shade = 0.65 + 0.35 * (1.0 - triangle_wave(across_world * 0.5 + 0.25));
		float tie = 1.0 - step(1.0, mod(along, 11.0));
		colour.rgb = jacket * round_shade;
		colour.rgb = mix(colour.rgb, vec3(0.12, 0.12, 0.13), tie);
		if (pick > 0.86) { // fibre-optic strand with travelling data pulses
			float pulse = step(0.93, fract(along / 23.0 - t * 0.9 + pick * 5.0));
			colour.rgb = mix(vec3(0.10, 0.20, 0.24), vec3(0.55, 1.0, 1.0), pulse);
		}
		return colour;
	}

	if (material_id == 46) { // planks along the long axis
		float plank = floor(across_world / 3.0);
		float offset = cheap_hash(vec2(plank, 5.0)) * 13.0;
		float in_plank = mod(along + offset, 13.0);
		float joint = 1.0 - step(0.8, in_plank);
		float gap = 1.0 - step(0.6, mod(across_world, 3.0));
		float grain = triangle_wave((along + cheap_hash(vec2(plank, 9.0)) * 9.0) / 11.0
			+ sin(across_world * 1.7) * 0.15);
		colour.rgb *= 0.76 + grain * 0.30;
		colour.rgb *= 1.0 - gap * 0.38 - joint * 0.45;
		float nail = step(abs(in_plank - 1.5), 0.6) * step(0.5, mod(across_world, 3.0) - 0.9)
			* step(mod(across_world, 3.0), 1.6);
		colour.rgb = mix(colour.rgb, vec3(0.30, 0.31, 0.33), nail * 0.9);
		return apply_burn(colour, pixel, condition);
	}

	if (material_id == 64) { // corrugation ridges follow the sheet's long axis
		float ridge = triangle_wave(across_world / 4.0);
		float lap = 1.0 - step(0.6, mod(along, 18.0));
		float glint = manufactured_glint(pixel, 0.24) * smoothstep(0.62, 1.0, ridge);
		colour.rgb *= 0.62 + (1.0 - ridge) * 0.58;
		colour.rgb *= mix(1.0, 0.58, lap);
		colour.rgb += vec3(glint * (1.0 - lap) * 0.38);
		float streak = smoothstep(0.6, 0.9, value_noise(vec2(across_world / 2.0, along / 9.0)));
		colour.rgb = mix(colour.rgb, vec3(0.42, 0.24, 0.14), streak * 0.30);
		return colour;
	}

	if (material_id == 55) { // generative leaded glass (jittered Voronoi panes)
		vec2 cell = floor(pixel / 7.0);
		float nearest = 9.0;
		float second = 9.0;
		vec2 owner = cell;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 candidate = cell + vec2(float(x), float(y));
				vec2 site = (candidate + vec2(0.15) + vec2(cheap_hash(candidate), cheap_hash(candidate + vec2(7.0))) * 0.7) * 7.0;
				float d = length(pixel + vec2(0.5) - site);
				if (d < nearest) { second = nearest; nearest = d; owner = candidate; }
				else if (d < second) { second = d; }
			}
		}
		float choice = cheap_hash(owner + vec2(31.0));
		vec3 pane = choice < 0.2 ? vec3(0.10, 0.70, 0.90) : choice < 0.4 ? vec3(0.80, 0.14, 0.62)
			: choice < 0.6 ? vec3(0.95, 0.58, 0.10) : choice < 0.8 ? vec3(0.18, 0.62, 0.28) : vec3(0.20, 0.28, 0.85);
		float light = 0.75 + value_noise(pixel / 5.0) * 0.35;
		float lead = 1.0 - step(0.75, second - nearest);
		colour.rgb = mix(pane * light, vec3(0.04, 0.04, 0.05), lead);
		if (exposed) colour.rgb = vec3(0.08, 0.08, 0.09);
		return colour;
	}

	if (material_id >= 77 && material_id <= 79) { // neon tube core along the run
		colour = apply_material_flair(colour, material_id, flair, pixel, condition);
		vec3 hue = colour.rgb / max(max(colour.r, max(colour.g, colour.b)), 0.001);
		float core = 1.0 - abs(across_u * 2.0 - 1.0);
		float plasma = value_noise(vec2(along / 3.0 - t * 5.0, across_world * 0.7));
		colour.rgb = hue * (0.50 + core * 0.40 + plasma * 0.14);
		colour.rgb = mix(colour.rgb, vec3(1.0), smoothstep(0.70, 1.0, core) * 0.55);
		return colour;
	}

	// Remaining materials keep their finish and gain edge-aware detail.
	if (material_id == 43 || material_id == 57 || material_id == 70 || material_id == 58) {
		return apply_detail_edges(colour, material_id, flair, pixel, extent, edge, exposed, condition);
	}
	bool top_open = extent.x < 0.5 && is_open_cell(neighbours.x);
	bool bottom_open = extent.y < 0.5 && is_open_cell(neighbours.y);
	bool side_open = (extent.z < 0.5 && is_open_cell(neighbours.z))
		|| (extent.w < 0.5 && is_open_cell(neighbours.w));
	float up = extent.x;
	bool thin = across_span <= 3.5;

	if (material_id == 73) { // rubber: moving conveyor belt when thin, tread plate when wide
		if (across_span <= 6.5) {
			float rib = step(0.5, fract((along - t * 6.0) / 4.0));
			float roller = 1.0 - step(0.5, min(horizontal ? extent.z : extent.x, horizontal ? extent.w : extent.y));
			colour.rgb *= 0.70 + rib * 0.35;
			colour.rgb *= 0.85 + (1.0 - abs(across_u * 2.0 - 1.0)) * 0.25;
			if (roller > 0.5) colour.rgb = vec3(0.45, 0.47, 0.50) * (0.7 + step(0.5, fract(t * 2.0 + across_u)) * 0.3);
		} else {
			float a = step(0.6, triangle_wave((pixel.x + pixel.y) / 4.0)) * step(0.5, mod(floor(pixel.y / 2.0) + floor(pixel.x / 4.0), 2.0));
			float b = step(0.6, triangle_wave((pixel.x - pixel.y) / 4.0)) * (1.0 - step(0.5, mod(floor(pixel.y / 2.0) + floor(pixel.x / 4.0), 2.0)));
			colour.rgb *= 0.78 + max(a, b) * 0.45;
			colour.rgb += vec3(0.07, 0.07, 0.075) * max(a, b);
		}
		return colour;
	}

	if (material_id == 80) { // LED panel: bezel and a generative scrolling display
		if (edge < 0.5) {
			colour.rgb = vec3(0.10, 0.11, 0.13);
			return colour;
		}
		vec2 local = mod(pixel, 2.0);
		float diode = step(0.5, local.x) * step(0.5, local.y);
		float wave = value_noise(vec2(pixel.x / 7.0 - t * 1.5, pixel.y / 5.0)) + value_noise(vec2(pixel.x / 3.0, pixel.y / 3.0 + t * 0.8)) * 0.5;
		float marquee = step(0.5, fract(pixel.x / 9.0 - t * 0.9)) * step(0.6, value_noise(vec2(floor(pixel.x / 3.0), floor(pixel.y / 4.0)) + vec2(floor(t * 0.9 * 9.0) * 0.0)));
		vec3 tint = 0.5 + 0.5 * cos(6.2832 * (wave * 0.45 + t * 0.05 + vec3(0.0, 0.33, 0.67)));
		vec3 display = mix(tint * (0.35 + wave * 0.45), vec3(1.0), marquee * 0.35);
		colour.rgb = mix(display * 0.25, display * 1.15, diode);
		return colour;
	}

	if (material_id == 5) { // Cloner: truchet circuit traces with travelling pulses
		vec2 tile = floor(pixel / 6.0);
		vec2 local = mod(pixel, 6.0) - vec2(2.5);
		if (cheap_hash(tile + vec2(11.0)) > 0.5) local.x = -local.x;
		float arc_a = abs(length(local - vec2(-3.0, -3.0)) - 3.0);
		float arc_b = abs(length(local - vec2(3.0, 3.0)) - 3.0);
		float trace = 1.0 - step(0.75, min(arc_a, arc_b));
		float pulse = step(0.85, fract((pixel.x + pixel.y) / 17.0 - t * 0.7));
		colour.rgb *= 0.55 + trace * 0.45;
		colour.rgb = mix(colour.rgb, vec3(0.95, 0.65, 1.0), trace * pulse * 0.85);
		if (edge < 0.5) colour.rgb *= 0.6;
		return colour;
	}

	if (material_id == 7) { // generic wood: planks along the run
		float plank = floor(across_world / 3.0);
		float offset = cheap_hash(vec2(plank, 15.0)) * 11.0;
		float in_plank = mod(along + offset, 11.0);
		float joint = 1.0 - step(0.8, in_plank);
		float gap = 1.0 - step(0.6, mod(across_world, 3.0));
		float grain = triangle_wave((along + cheap_hash(vec2(plank, 19.0)) * 9.0) / 9.0);
		colour.rgb *= 0.78 + grain * 0.28;
		colour.rgb *= 1.0 - gap * 0.35 - joint * 0.40;
		return apply_burn(colour, pixel, condition);
	}

	if (material_id == 9) { // Ice: frosted top, icicles hanging from open undersides
		colour = apply_material_flair(colour, material_id, flair, pixel, condition);
		if (top_open) colour.rgb = mix(colour.rgb, vec3(0.92, 0.97, 1.0), 0.55);
		if (extent.y < 2.5 && bottom_open || extent.y < 2.5 && is_open_cell(sampled_material_id(pixel + vec2(0.0, extent.y + 1.0), false))) {
			float icicle = cheap_hash(vec2(pixel.x, 71.0));
			float reach = 1.0 + icicle * 2.5;
			if (extent.y + 0.5 < 3.0 - reach) colour.a = 0.0;
			colour.rgb = mix(colour.rgb, vec3(0.85, 0.95, 1.0), 0.35);
		}
		return colour;
	}

	if (material_id == 35 || material_id == 72) { // windows: frames, mullions, reflections
		colour = apply_material_flair(colour, material_id, flair, pixel, condition);
		float mullion = (1.0 - step(0.6, mod(pixel.x, 10.0))) + (1.0 - step(0.6, mod(pixel.y, 12.0)));
		vec3 frame = vec3(0.16, 0.17, 0.19);
		if (material_id == 72) { // dark glass: faint lit windows of a reflected city
			vec2 block = floor(pixel / vec2(3.0, 2.0));
			float lit = step(0.86, cheap_hash(block + vec2(41.0)));
			vec3 lamp = cheap_hash(block + vec2(3.0)) > 0.5 ? vec3(1.0, 0.75, 0.35) : vec3(0.45, 0.85, 1.0);
			colour.rgb = mix(colour.rgb, lamp * 0.55, lit * 0.6 * step(0.5, mod(pixel.x, 3.0)));
		}
		if (edge < 0.5) colour.rgb = frame;
		else if (mullion > 0.5) colour.rgb = mix(colour.rgb, frame, 0.85);
		return colour;
	}

	if (material_id == 71) { // chemical tank: fill line, rising bubbles, frame
		colour = apply_material_flair(colour, material_id, flair, pixel, condition);
		float fill_top = 2.0 + floor(cheap_hash(floor(pixel / 24.0)) * 3.0);
		if (up >= fill_top) {
			colour.rgb = mix(colour.rgb, vec3(0.20, 0.85, 0.55), 0.45);
			vec2 bubble = lattice_particle(pixel + vec2(sin(t * 2.0 + pixel.y) * 0.5, t * 5.0), 4.0, 0.35, 77.0);
			colour.rgb = mix(colour.rgb, vec3(0.75, 1.0, 0.85), bubble.x * 0.8);
		} else if (up >= fill_top - 1.0) {
			colour.rgb = mix(colour.rgb, vec3(0.70, 1.0, 0.80), 0.7);
		}
		if (edge < 0.5) colour.rgb = vec3(0.30, 0.34, 0.36);
		return colour;
	}

	if (material_id == 50) { // wrought iron: balusters when thin, riveted plate when wide
		if (thin) {
			float collar = 1.0 - step(0.8, mod(along, 8.0));
			colour.rgb *= 0.55 + (1.0 - abs(across_u * 2.0 - 1.0)) * 0.70;
			colour.rgb = mix(colour.rgb, colour.rgb * 1.6 + vec3(0.04), collar);
			if (top_open && !horizontal) colour.rgb = vec3(0.55, 0.50, 0.32);
		} else {
			colour = apply_material_flair(colour, material_id, flair, pixel, condition);
			float rivet = step(0.5, 1.0 - step(0.5, edge - 0.5)) * step(0.5, mod(along, 3.0));
			colour.rgb += vec3(0.16) * rivet * float(edge > 0.5 && edge < 1.5);
		}
		return colour;
	}

	// The remaining static materials keep their finish and gain region detail.
	colour = apply_material_flair(colour, material_id, flair, pixel, condition);
	if (material_id == 1 || material_id == 31 || material_id == 28) { // blocks, formwork, machined edges
		vec2 block = mod(pixel, material_id == 31 ? vec2(12.0, 8.0) : vec2(8.0, 4.0));
		float seam = (1.0 - step(0.6, block.x)) + (1.0 - step(0.6, block.y));
		colour.rgb *= 1.0 - min(seam, 1.0) * (material_id == 28 ? 0.10 : 0.16);
		if (top_open) colour.rgb *= 1.12;
		colour.rgb *= 1.0 - drip_streak(pixel, up, 3.0) * 0.22;
		if (material_id == 28 && edge < 0.5) colour.rgb = colour.rgb * 1.2 + vec3(0.05);
	} else if (material_id >= 38 && material_id <= 40) { // ashlar: cap course, quoins, drips
		if (top_open || up < 0.5) colour.rgb = colour.rgb * 1.10 + vec3(0.03);
		bool quoin = extent.z < 3.5 || extent.w < 3.5;
		if (quoin && mod(floor(pixel.y / 4.0), 2.0) < 0.5) colour.rgb *= 1.08;
		colour.rgb *= 1.0 - drip_streak(pixel, up, 7.0) * 0.25;
		if (material_id == 40) {
			float fleck = cheap_hash(pixel + vec2(19.0, 3.0));
			colour.rgb = mix(colour.rgb, vec3(0.08), step(0.93, fleck) * 0.7);
			colour.rgb = mix(colour.rgb, vec3(0.88, 0.86, 0.82), step(fleck, 0.04) * 0.6);
		}
		if (material_id == 39) colour.rgb *= 0.92 + triangle_wave(pixel.y / 2.3 + value_noise(pixel / 9.0)) * 0.10;
	} else if (material_id == 41 || material_id == 42) { // cobbles: polished tops, moss
		if (up < 0.5) colour.rgb *= 1.10;
		float moss_depth = material_id == 42 ? 2.5 : 0.8;
		float moss = (top_open || up < moss_depth) ? step(0.40, value_noise(pixel / 2.0) + (moss_depth - up) * 0.12) : 0.0;
		moss = max(moss, material_id == 42 ? step(0.82, value_noise(pixel / 1.5)) : 0.0);
		colour.rgb = mix(colour.rgb, vec3(0.22, 0.42, 0.14) * (0.7 + cheap_hash(pixel) * 0.5), moss * 0.85);
	} else if (material_id == 44) { // lime plaster spalling to reveal brick
		float spall = step(0.70, value_noise(pixel / 6.0) + (edge < 1.5 ? 0.18 : 0.0));
		if (spall > 0.5) {
			float row = floor(pixel.y / 3.0);
			float mortar = (1.0 - step(0.6, mod(pixel.x + mod(row, 2.0) * 3.0, 6.0))) + (1.0 - step(0.6, mod(pixel.y, 3.0)));
			colour.rgb = mix(vec3(0.62, 0.30, 0.22), vec3(0.55, 0.52, 0.46), min(mortar, 1.0));
		}
		colour.rgb *= 1.0 - drip_streak(pixel, up, 13.0) * 0.18;
	} else if (material_id == 45) { // half-timbered wattle and daub
		float post = edge < 1.5 ? 1.0 : 0.0;
		float rail = 1.0 - step(1.5, mod(pixel.y, 11.0));
		float brace = 1.0 - step(1.2, abs(mod(pixel.x, 12.0) - mod(pixel.y, 11.0) * 1.09));
		float beam = max(post, max(rail, brace));
		vec3 oak = vec3(0.24, 0.15, 0.09) * (0.8 + triangle_wave(pixel.x / 5.0 + pixel.y / 7.0) * 0.3);
		colour.rgb = mix(colour.rgb, oak, beam);
	} else if (material_id == 47) { // thatch: ridge binding and ragged eave fringe
		float course = floor(pixel.y / 4.0);
		colour.rgb *= 0.85 + triangle_wave((pixel.x + course * 2.0) / 2.0) * 0.20;
		if (up < 1.5 && top_open || up < 1.5 && extent.x < 1.5) colour.rgb *= 0.70;
		if (extent.y < 1.5 && (bottom_open || extent.y < 0.5)) {
			if (cheap_hash(vec2(pixel.x, 37.0)) > 0.55 && extent.y < 0.5) colour.a = 0.0;
			colour.rgb *= 1.12;
		}
	} else if (material_id == 48 || material_id == 49) { // roofs: ridge cap, eave, lichen
		if (up < 1.5) colour.rgb = mix(colour.rgb, colour.rgb * 0.75 + vec3(0.06), 0.8)
			* (0.85 + (1.0 - triangle_wave(pixel.x / 3.0)) * 0.30);
		if (extent.y < 0.5) colour.rgb *= 0.65;
		float lichen = step(0.88, value_noise(pixel / 2.0)) * step(0.4, cheap_hash(pixel));
		colour.rgb = mix(colour.rgb, vec3(0.55, 0.60, 0.30), lichen * 0.6);
	} else if (material_id == 51) { // lead: standing seams and white bloom
		float seam = 1.0 - step(0.8, mod(horizontal ? pixel.x : pixel.y, 8.0));
		colour.rgb = mix(colour.rgb, colour.rgb * 1.35 + vec3(0.03), seam);
		colour.rgb = mix(colour.rgb, vec3(0.75, 0.78, 0.80), drip_streak(pixel, up, 23.0) * 0.30);
		if (edge < 0.5) colour.rgb *= 1.15;
	} else if (material_id == 52 || material_id == 53 || material_id == 54) { // patina runs
		vec3 green = vec3(0.30, 0.62, 0.50);
		float run = drip_streak(pixel, up, 31.0);
		colour.rgb = mix(colour.rgb, green * (0.8 + cheap_hash(pixel) * 0.3), run * (material_id == 54 ? 0.5 : 0.65));
		if (material_id == 54 && edge < 0.5) colour.rgb = mix(colour.rgb, vec3(0.70, 0.40, 0.22), 0.5);
		if (material_id != 54 && edge < 0.5) colour.rgb = colour.rgb * 1.18 + vec3(0.04);
	} else if (material_id == 56) { // packed earth: strata, pebbles, grassy top
		colour.rgb *= 0.88 + triangle_wave(pixel.y / 3.0 + value_noise(vec2(pixel.x / 11.0, 0.0)) * 1.5) * 0.18;
		if (top_open || up < 0.5) {
			colour.rgb = vec3(0.24, 0.48, 0.16) * (0.75 + cheap_hash(pixel) * 0.5);
		} else if (up < 1.5) {
			colour.rgb = mix(colour.rgb, vec3(0.20, 0.36, 0.12), step(0.5, cheap_hash(pixel + vec2(2.0))) * 0.6);
		}
	} else if (material_id == 59) { // asphalt: tar-sealed cracks, worn top
		float crack = 1.0 - smoothstep(0.0, 0.03, abs(value_noise(pixel / 10.0) - 0.5));
		colour.rgb = mix(colour.rgb, vec3(0.02, 0.02, 0.025), crack * 0.85);
		if (up < 0.5) colour.rgb *= 1.15;
	} else if (material_id == 60 || material_id == 61) { // wet: puddle sheen on the top surface
		if (up < 1.5) {
			float ripple = value_noise(vec2(pixel.x / 3.0, 0.0));
			colour.rgb = mix(colour.rgb, vec3(0.30, 0.42, 0.55) * (0.8 + ripple * 0.5), up < 0.5 ? 0.55 : 0.25);
		}
	} else if (material_id == 62 || material_id == 63) { // plates: rivet rows, weld beads, grime
		bool rivet_row = edge > 0.5 && edge < 1.5;
		float rivet = rivet_row ? step(0.5, 1.0 - step(0.7, mod(along, 3.0))) : 0.0;
		colour.rgb += vec3(0.18) * rivet;
		colour.rgb *= 1.0 - (1.0 - min(1.0, (extent.y + 0.5) / 8.0)) * 0.15;
		if (material_id == 63) {
			float chip = step(0.6, value_noise(pixel / 1.6)) * (edge < 1.5 ? 1.0 : 0.15);
			colour.rgb = mix(colour.rgb, vec3(0.42, 0.24, 0.14), chip * 0.7);
			colour.rgb = mix(colour.rgb, vec3(0.45, 0.22, 0.10), drip_streak(pixel, up, 41.0) * 0.35);
		}
	} else if (material_id == 65) { // rusted steel: corrosion spilling from edges and seams
		vec2 rust = corrosion_field(pixel, top_open || up < 1.5 ? 0.25 : 0.0);
		float bleed = drip_streak(pixel, up, 43.0) * smoothstep(0.35, 0.65, value_noise(vec2(pixel.x / 1.3, pixel.y / 6.0)));
		colour.rgb = mix(colour.rgb, vec3(0.50, 0.20, 0.07), max(bleed * 0.65, rust.x * 0.25));
		colour.rgb = mix(colour.rgb, vec3(0.16, 0.06, 0.03), rust.y * 0.5);
		if (edge < 1.5 && step(0.80, value_noise(pixel / 1.5)) * step(0.5, rust.x) > 0.5) colour.a = 0.0;
	} else if (material_id == 66 || material_id == 67) { // grating / chainlink frames and posts
		if (edge < 0.5) colour.rgb = vec3(0.36, 0.40, 0.44) * (0.8 + (material_id == 67 ? 0.2 : 0.0));
		if (material_id == 67 && mod(along, 16.0) < 1.0) colour.rgb = vec3(0.40, 0.44, 0.48);
	}
	return colour;
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
	// One gather of the four neighbours (from the snapshot being shaded)
	// feeds the structured fills, the volume/contact stage and the relief.
	ivec4 neighbours = ivec4(
		sampled_material_id(world_pixel + vec2(0.0, -1.0), previous_snapshot),
		sampled_material_id(world_pixel + vec2(0.0, 1.0), previous_snapshot),
		sampled_material_id(world_pixel + vec2(-1.0, 0.0), previous_snapshot),
		sampled_material_id(world_pixel + vec2(1.0, 0.0), previous_snapshot)
	);
	if (material_id >= 81 && material_id <= LAST_MATERIAL_ID) {
		// Keep the catalogue at a single dispatch site. Putting it inside the
		// shared flair helper duplicates this large branch at every ordinary
		// structured finish call when GPU drivers inline shader functions.
		BuildGeometry geometry = default_build_geometry(world_pixel);
		if (uses_structured_fill(material_id)) {
			geometry = probed_build_geometry(world_pixel, neighbours,
				region_extent(world_pixel, material_id, neighbours, previous_snapshot));
		}
		colour = apply_building_finish(colour, material_id, world_pixel, geometry, condition);
	} else if (uses_structured_fill(material_id)) {
		vec4 extent = region_extent(world_pixel, material_id, neighbours, previous_snapshot);
		colour = apply_structured_fill(
			colour, material_id, flair, world_pixel, neighbours, extent, condition);
	} else {
		colour = apply_material_flair(colour, material_id, flair, world_pixel, condition);
	}
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
