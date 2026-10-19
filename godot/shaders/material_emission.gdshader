shader_type canvas_item;
render_mode unshaded;

// Downsampled presentation-only light source. It reads the same immutable RG8
// snapshot as the palette pass and never creates Light2D nodes or simulation
// feedback. One low-resolution fragment performs a bounded sixteen-cell,
// dual-radius sample before the composite pass widens the halo on the GPU.
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform sampler2D material_program_lut : filter_nearest, repeat_disable;
uniform vec2 world_size_px = vec2(1024.0, 1024.0);
uniform vec2 view_size_px = vec2(320.0, 180.0);
uniform vec2 camera_origin_px = vec2(0.0);
uniform float condition_projection_enabled = 0.0;
uniform float sample_radius_px : hint_range(1.0, 12.0, 0.5) = 4.0;
// Shared with the palette pass; negative keeps the engine TIME.
uniform float presentation_time_override = -1.0;

float presentation_time() {
	return presentation_time_override >= 0.0 ? presentation_time_override : TIME;
}

float cheap_hash(vec2 value) {
	vec3 parts = fract(value.xyx * 0.1031);
	parts += dot(parts, parts.yzx + vec3(33.33));
	return fract((parts.x + parts.y) * parts.z);
}

float triangle_wave(float value) {
	return abs(fract(value) * 2.0 - 1.0);
}

float flair_emission_multiplier(int flair, vec2 pixel) {
	if (flair == 27) { // neon
		float seed = cheap_hash(floor(pixel / 8.0));
		float pulse = 0.94 + (1.0 - triangle_wave(presentation_time() * 0.55 + seed)) * 0.08;
		float fault = step(0.988, cheap_hash(vec2(seed * 91.0, floor(presentation_time() * 2.0))));
		return pulse * mix(1.0, 0.64, fault);
	}
	if (flair == 28) { // LED scan
		return 0.90 + 0.10 * (1.0 - triangle_wave(presentation_time() * 0.30 + pixel.y / 18.0));
	}
	if (flair == 30) { // flame
		return 0.88 + triangle_wave((pixel.x * 0.7 - pixel.y) / 6.0 + presentation_time() * 0.9) * 0.22;
	}
	if (flair == 31) { // molten material
		return 0.90 + (1.0 - triangle_wave((pixel.x + pixel.y * 0.35) / 9.0 + presentation_time() * 0.16)) * 0.24;
	}
	if (flair == 32) { // spark
		return 0.72 + (1.0 - triangle_wave(presentation_time() * 2.4 + cheap_hash(pixel))) * 0.60;
	}
	if (flair == 41) { // charged metal
		return 0.92 + smoothstep(0.88, 1.0, 1.0 - triangle_wave(
			(pixel.x + pixel.y * 0.37) / 13.0 + presentation_time() * 0.48
		)) * 0.34;
	}
	if (flair == 50) { // activated firework: hot flicker feeding the bloom
		return 0.85 + 0.45 * (0.5 + 0.5 * sin(presentation_time() * 37.0 + cheap_hash(pixel) * 60.0));
	}
	if (flair == 42) { // cloner circuitry
		return 0.88 + smoothstep(0.80, 1.0, 1.0 - triangle_wave(
			(pixel.x + pixel.y) / 19.0 - presentation_time() * 0.26
		)) * 0.30;
	}
	return 1.0;
}

vec3 emission_at(vec2 world_pixel) {
	vec2 clamped_pixel = clamp(world_pixel, vec2(0.0), world_size_px - vec2(1.0));
	vec2 world_uv = (floor(clamped_pixel) + vec2(0.5)) / world_size_px;
	vec2 cell = texture(world_texture, world_uv).rg;
	int material_id = int(floor(cell.r * 255.0 + 0.5));
	float condition = cell.g * condition_projection_enabled;
	float program_v = (float(material_id) + 0.5) / 256.0;
	vec4 curve_value = texture(material_program_lut, vec2(0.375, program_v));
	vec4 alpha_emission = texture(material_program_lut, vec2(0.625, program_v));
	vec4 emission_program = texture(material_program_lut, vec2(0.875, program_v));
	float response = smoothstep(curve_value.x, curve_value.y, condition);
	float intensity = mix(alpha_emission.z, alpha_emission.w, response);
	int flair = int(floor(emission_program.a + 0.5));
	float multiplier = flair_emission_multiplier(flair, world_pixel);
	if (material_id == 127) { // phosphor afterglow breathes slowly
		multiplier *= 0.80 + 0.20 * sin(presentation_time() * 0.8 + world_pixel.x * 0.05);
	}
	return emission_program.rgb * intensity * multiplier;
}

void fragment() {
	vec2 world_pixel = camera_origin_px + floor(UV * view_size_px);
	float radius = sample_radius_px;
	// The half-resolution texel covers a 2x2 block of cells; taking the brightest
	// keeps single-cell emitters (activated fireworks, sparks) in the bloom.
	// UV is at the output texel's centre: floor(UV * view_size_px) is the
	// bottom-right cell at 2:1, not the block's origin. Derivatives also keep
	// full-resolution fixtures at a one-cell footprint.
	vec2 footprint = vec2(1.0) + step(vec2(1.5), fwidth(UV * view_size_px));
	vec2 block_pixel = camera_origin_px + floor(UV * view_size_px / footprint) * footprint;
	vec2 span = footprint - vec2(1.0);
	vec3 emission = max(max(emission_at(block_pixel), emission_at(block_pixel + vec2(span.x, 0.0))),
		max(emission_at(block_pixel + vec2(0.0, span.y)), emission_at(block_pixel + span))) * 0.22;
	emission += emission_at(world_pixel + vec2(radius, 0.0)) * 0.09;
	emission += emission_at(world_pixel + vec2(-radius, 0.0)) * 0.09;
	emission += emission_at(world_pixel + vec2(0.0, radius)) * 0.09;
	emission += emission_at(world_pixel + vec2(0.0, -radius)) * 0.09;
	emission += emission_at(world_pixel + vec2(radius, radius)) * 0.045;
	emission += emission_at(world_pixel + vec2(-radius, radius)) * 0.045;
	emission += emission_at(world_pixel + vec2(radius, -radius)) * 0.045;
	emission += emission_at(world_pixel + vec2(-radius, -radius)) * 0.045;
	emission += emission_at(world_pixel + vec2(radius * 2.0, 0.0)) * 0.06;
	emission += emission_at(world_pixel + vec2(-radius * 2.0, 0.0)) * 0.06;
	emission += emission_at(world_pixel + vec2(0.0, radius * 2.0)) * 0.06;
	emission += emission_at(world_pixel + vec2(0.0, -radius * 2.0)) * 0.06;
	COLOR = vec4(emission, clamp(max(emission.r, max(emission.g, emission.b)), 0.0, 1.0));
}
