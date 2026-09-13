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
		TIME * speed + seed + (pixel.x - pixel.y * 0.21) / 43.0
	);
	return step(0.982, seed) * smoothstep(0.86, 1.0, sweep);
}

int sampled_material_id(vec2 pixel) {
	vec2 clamped_pixel = clamp(floor(pixel), vec2(0.0), world_size_px - vec2(1.0));
	vec2 world_uv = (clamped_pixel + vec2(0.5)) / world_size_px;
	return int(floor(texture(current_world_texture, world_uv).r * 255.0 + 0.5));
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

vec4 apply_neighbour_relief(vec4 colour, int material_id, vec2 pixel) {
	int above_id = sampled_material_id(pixel + vec2(0.0, -1.0));
	int below_id = sampled_material_id(pixel + vec2(0.0, 1.0));
	int left_id = sampled_material_id(pixel + vec2(-1.0, 0.0));
	int right_id = sampled_material_id(pixel + vec2(1.0, 0.0));

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
		return colour;
	}

	if (flair == 5) { // thatch fibres
		float fibre = triangle_wave((pixel.x + pixel.y * 1.65) / 3.0);
		float course = cheap_hash(floor(pixel / vec2(5.0, 3.0)));
		colour.rgb *= 0.72 + fibre * 0.28 + course * 0.15;
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
		return colour;
	}

	if (flair == 12) { // dry asphalt
		float grain = cheap_hash(pixel);
		float pebble = step(0.94, grain);
		colour.rgb *= 0.78 + grain * 0.30;
		colour.rgb += vec3(pebble * 0.10);
		return colour;
	}

	if (flair == 13) { // wet media and viscous liquids
		if (material_id == 61) {
			float row = floor(pixel.y / 4.0);
			vec2 local = vec2(mod(pixel.x + mod(row, 2.0) * 2.5, 5.0) / 5.0,
				mod(pixel.y, 4.0) / 4.0) - vec2(0.5);
			colour.rgb *= mix(1.02, 0.53, smoothstep(0.36, 0.53, length(local)));
		}
		float seed = cheap_hash(pixel);
		bool flowing = material_id != 60 && material_id != 61;
		float flow_speed = 0.045 + mod(float(material_id), 5.0) * 0.012;
		float flow_phase = flowing ? TIME * flow_speed : 0.0;
		float sweep = 1.0 - triangle_wave(TIME * 0.22 + seed +
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
		return colour;
	}

	if (flair == 14 || flair == 15) { // plate seams, rivets, optional paint chips
		vec2 local = mod(pixel, 12.0);
		float seam = max(1.0 - step(0.55, local.x), 1.0 - step(0.55, local.y));
		float rivet = 1.0 - step(0.92, length(local - vec2(1.15)));
		float brushed = triangle_wave((pixel.x + pixel.y * 0.15) / 8.0);
		float glint = manufactured_glint(pixel, flair == 15 ? 0.18 : 0.28);
		colour.rgb *= mix(0.88 + brushed * 0.18, 0.46, seam);
		colour.rgb += vec3(rivet * 0.26);
		colour.rgb += vec3(glint * (1.0 - seam) * (flair == 15 ? 0.24 : 0.46));
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
		float band = 1.0 - triangle_wave((pixel.x + pixel.y * 0.72) / 13.0 + TIME * 0.035);
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
		float pulse = 0.94 + (1.0 - triangle_wave(TIME * 0.55 + seed)) * 0.08;
		float fault = step(0.988, cheap_hash(vec2(seed * 91.0, floor(TIME * 2.0))));
		float travelling = smoothstep(0.82, 1.0, 1.0 - triangle_wave(
			pixel.x / 31.0 - TIME * 0.34 + seed
		));
		colour.rgb *= pulse * mix(1.0, 0.64, fault);
		colour.rgb += colour.rgb * travelling * 0.12;
		return colour;
	}

	if (flair == 28) { // LED panel separators and quiet scan
		vec2 local = mod(pixel, 3.0);
		float diode = step(0.62, local.x) * step(0.62, local.y);
		float scan = 0.90 + 0.10 * (1.0 - triangle_wave(TIME * 0.30 + pixel.y / 18.0));
		float refresh = smoothstep(0.90, 1.0, 1.0 - triangle_wave(
			TIME * 0.22 + (pixel.x + pixel.y) / 41.0
		));
		colour.rgb *= mix(0.28, scan + refresh * 0.12, diode);
		return colour;
	}

	if (flair == 29) { // water micro-highlights
		float seed = cheap_hash(pixel);
		float sweep = 1.0 - triangle_wave(TIME * 0.18 + seed + pixel.x / 29.0);
		float glint = step(0.982, seed) * smoothstep(0.86, 1.0, sweep);
		float ripple = smoothstep(0.78, 0.98, triangle_wave(
			(pixel.x + pixel.y * 0.22) / 21.0 + TIME * 0.075
		));
		colour.rgb *= 0.91 + ripple * 0.13;
		colour.rgb += vec3(0.32, 0.56, 0.75) * glint;
		return colour;
	}

	if (flair == 30) { // layered flame shimmer
		float lick_a = triangle_wave((pixel.x * 0.7 - pixel.y) / 6.0 + TIME * 0.9);
		float lick_b = triangle_wave((pixel.x * -0.35 - pixel.y) / 11.0 + TIME * 0.53);
		float hot_core = smoothstep(0.62, 0.98, 1.0 - abs(lick_a - lick_b));
		colour.rgb *= 0.78 + lick_a * 0.19 + lick_b * 0.14;
		colour.rgb += vec3(0.72, 0.24, 0.025) * hot_core * 0.24;
		colour.a *= 0.82 + hot_core * 0.18;
		return colour;
	}

	if (flair == 31) { // lava/molten-glass convection bands and cooling crust
		float flow = triangle_wave((pixel.x + pixel.y * 0.35) / 9.0 + TIME * 0.16);
		float counter_flow = triangle_wave((pixel.y - pixel.x * 0.21) / 15.0 - TIME * 0.09);
		float crust = step(0.88, cheap_hash(floor(pixel / 3.0)));
		float fissure = smoothstep(0.86, 0.98, 1.0 - abs(flow - counter_flow));
		colour.rgb *= 0.78 + (1.0 - flow) * 0.21 + (1.0 - counter_flow) * 0.14;
		colour.rgb *= mix(1.0, 0.48, crust);
		colour.rgb += vec3(0.72, 0.16, 0.015) * fissure * (1.0 - crust) * 0.28;
		return colour;
	}

	if (flair == 32) { // spark twinkle
		float seed = cheap_hash(pixel);
		float twinkle = 0.66 + (1.0 - triangle_wave(TIME * 2.4 + seed)) * 0.68;
		float streak = smoothstep(0.90, 1.0, 1.0 - triangle_wave(
			(pixel.x - pixel.y) / 9.0 + TIME * 0.75 + seed
		));
		colour.rgb *= twinkle;
		colour.rgb += vec3(0.45, 0.38, 0.12) * streak;
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
		return colour;
	}

	if (flair == 34) { // Smoke: slow layered turbulent wisps
		float drift_a = triangle_wave(
			(pixel.x + pixel.y * 0.37) / 17.0 + TIME * 0.052
		);
		float drift_b = triangle_wave(
			(pixel.y - pixel.x * 0.23) / 23.0 - TIME * 0.031
		);
		float wisp = smoothstep(0.18, 0.88, drift_a * 0.58 + drift_b * 0.42);
		float billow = 0.82 + cheap_hash(floor(pixel / 5.0) + vec2(floor(TIME * 0.08))) * 0.18;
		colour.rgb *= 0.70 + wisp * 0.35;
		colour.a *= (0.48 + wisp * 0.52) * billow;
		return colour;
	}

	if (flair == 35) { // Steam: fine rising translucent curls
		float rise = TIME * 0.11;
		float curl_a = triangle_wave((pixel.x + pixel.y * 0.41) / 13.0 + rise);
		float curl_b = triangle_wave((pixel.x * -0.28 + pixel.y) / 19.0 - rise * 0.73);
		float vapour = smoothstep(0.20, 0.92, curl_a * curl_b + curl_b * 0.25);
		colour.rgb *= 0.88 + vapour * 0.18;
		colour.a *= 0.36 + vapour * 0.64;
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
		return colour;
	}

	if (flair == 37) { // plant/fungus/seed organic fibres and nodes
		float vein_a = triangle_wave((pixel.x * 0.58 + pixel.y) / 5.0);
		float vein_b = triangle_wave((pixel.x - pixel.y * 0.31) / 9.0);
		float node = step(0.965, cheap_hash(pixel + vec2(13.0, 41.0)));
		float pulse = material_id == 18
			? 0.94 + (1.0 - triangle_wave(TIME * 0.12 + cheap_hash(floor(pixel / 5.0)))) * 0.10
			: 1.0;
		colour.rgb *= (0.72 + vein_a * 0.20 + vein_b * 0.14) * pulse;
		colour.rgb += vec3(0.16, 0.20, 0.08) * node;
		return colour;
	}

	if (flair == 38) { // Ice: faceted crystal planes and travelling cold sheen
		float facet_a = triangle_wave((pixel.x + pixel.y) / 7.0);
		float facet_b = triangle_wave((pixel.x - pixel.y * 1.4) / 11.0);
		float plane = 0.70 + facet_a * 0.18 + facet_b * 0.16;
		float sheen = smoothstep(0.88, 1.0, 1.0 - triangle_wave(
			(pixel.x + pixel.y * 0.52) / 29.0 + TIME * 0.045
		));
		colour.rgb *= plane;
		colour.rgb += vec3(0.28, 0.52, 0.66) * sheen;
		return colour;
	}

	if (flair == 39) { // Acid/sludge: rolling chemical bands and rising bubbles
		float speed = material_id == 12 ? 0.18 : 0.095;
		vec2 bubble_tile = floor(pixel / 6.0);
		float seed = cheap_hash(bubble_tile);
		vec2 local = mod(
			pixel + vec2(seed * 4.0, TIME * speed * 7.0 + seed * 3.0),
			6.0
		) - vec2(3.0);
		float bubble = (1.0 - smoothstep(0.22, 0.62, abs(length(local) - (0.75 + seed))))
			* step(0.47, seed);
		float swirl = triangle_wave(
			(pixel.x + pixel.y * 0.36) / 15.0 + TIME * speed
		);
		vec3 reactive_tint = material_id == 12
			? vec3(0.34, 0.42, 0.04)
			: vec3(0.08, 0.40, 0.10);
		colour.rgb *= 0.72 + swirl * 0.28;
		colour.rgb += reactive_tint * bubble * 0.75;
		return colour;
	}

	if (flair == 40) { // Mercury: travelling mirror bands and pin highlights
		float band_a = 1.0 - triangle_wave(
			(pixel.x + pixel.y * 0.18) / 13.0 + TIME * 0.13
		);
		float band_b = 1.0 - triangle_wave(
			(pixel.y - pixel.x * 0.09) / 23.0 - TIME * 0.075
		);
		float mirror = smoothstep(0.62, 1.0, max(band_a, band_b));
		float pin = step(0.986, cheap_hash(pixel)) * mirror;
		colour.rgb *= 0.52 + mirror * 0.64;
		colour.rgb += vec3(0.48, 0.58, 0.68) * pin;
		return colour;
	}

	if (flair == 41) { // Charged manufactured metal with crawling surface arcs
		vec2 local = mod(pixel, 12.0);
		float seam = max(1.0 - step(0.55, local.x), 1.0 - step(0.55, local.y));
		float brushed = triangle_wave((pixel.x + pixel.y * 0.15) / 8.0);
		float glint = manufactured_glint(pixel, 0.34);
		float route = 1.0 - triangle_wave(
			(pixel.x + floor(pixel.y / 3.0) * 2.0) / 11.0 + TIME * 0.48
		);
		float arc = smoothstep(0.91, 1.0, route)
			* step(0.78, cheap_hash(floor(pixel / 2.0) + vec2(floor(TIME * 4.0))))
			* condition;
		colour.rgb *= mix(0.86 + brushed * 0.20, 0.46, seam);
		colour.rgb += vec3(glint * (1.0 - seam) * 0.48);
		colour.rgb += vec3(0.10, 0.62, 1.18) * arc * (1.0 - seam);
		return colour;
	}

	if (flair == 42) { // Cloner: animated circuitry lattice and scan pulse
		vec2 local = mod(pixel, 6.0);
		float trace = max(1.0 - step(0.62, local.x), 1.0 - step(0.62, local.y));
		float node = 1.0 - step(1.05, length(local - vec2(1.0)));
		float scan = smoothstep(0.82, 1.0, 1.0 - triangle_wave(
			(pixel.x + pixel.y) / 19.0 - TIME * 0.26
		));
		colour.rgb *= mix(0.62, 1.08 + scan * 0.25, max(trace, node));
		colour.rgb += vec3(0.20, 0.05, 0.34) * node * scan;
		return colour;
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

vec4 material_colour(int material_id, float condition, vec2 world_pixel) {
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
	return apply_neighbour_relief(colour, material_id, world_pixel);
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
	vec4 colour = material_colour(material_id, condition, world_pixel);
	if (
		previous_material_id != material_id
		&& (
			is_temporally_smoothed_material(material_id)
			|| is_temporally_smoothed_material(previous_material_id)
		)
	) {
		colour = mix(
			material_colour(previous_material_id, previous_condition, world_pixel),
			colour,
			snapshot_blend
		);
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
		colour = material_colour(0, 0.0, world_pixel);
	}

	COLOR = colour;
}
