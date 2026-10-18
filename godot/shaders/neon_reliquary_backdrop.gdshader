shader_type canvas_item;
render_mode unshaded;

// An art backdrop for empty space, sampled from the already-published RG8
// textures. It never covers current cells, a fading previous cell, or the player.
uniform sampler2D current_world_texture : filter_nearest, repeat_disable;
uniform sampler2D previous_world_texture : filter_nearest, repeat_disable;
uniform vec2 view_size_px = vec2(960.0, 540.0);
uniform vec2 camera_origin_px = vec2(32.0, 16.0);
uniform vec2 player_origin_px = vec2(-1000.0);
uniform vec2 player_size_px = vec2(8.0, 14.0);
uniform float snapshot_blend = 1.0;
uniform int district_index = 0;

float hash11(float p) {
	return fract(sin(p * 127.1 + 31.7) * 43758.5453);
}

float rectangle(vec2 p, vec2 centre, vec2 half_size) {
	vec2 edge = step(abs(p - centre), half_size);
	return edge.x * edge.y;
}

vec3 skyline(vec3 colour, vec2 p, float spacing, float horizon,
		float seed, vec3 silhouette, float windows) {
	float column = floor(p.x / spacing);
	float local_x = mod(p.x, spacing);
	float variety = hash11(column + seed);
	float height = 24.0 + variety * 102.0;
	float width = spacing * (0.48 + hash11(column + seed + 3.0) * 0.28);
	float roof = horizon - height;
	float building = step(local_x, width) * step(roof, p.y);
	float crown = rectangle(vec2(local_x, p.y),
		vec2(width * 0.5, roof - 5.0), vec2(width * 0.23, 5.0));
	float antenna = rectangle(vec2(local_x, p.y),
		vec2(width * 0.5, roof - 15.0), vec2(0.45, 10.0));
	colour = mix(colour, silhouette, max(building, max(crown, antenna)));
	vec2 grid = floor(vec2(local_x, p.y - roof) / vec2(5.0, 8.0));
	vec2 pane = mod(vec2(local_x, p.y - roof), vec2(5.0, 8.0));
	float lit = step(0.73, hash11(column * 29.0 + grid.x * 7.0 + grid.y + seed));
	float window = step(1.0, pane.x) * step(pane.x, 2.0)
		* step(2.0, pane.y) * step(pane.y, 4.0) * step(roof + 7.0, p.y);
	vec3 tint = mix(vec3(0.13, 0.38, 0.43), vec3(0.43, 0.22, 0.20),
		step(0.65, variety));
	return colour + tint * window * lit * building * windows;
}

void fragment() {
	vec2 world_pixel = camera_origin_px + floor(UV * view_size_px);
	vec2 sample_uv = (world_pixel + vec2(0.5)) / vec2(1024.0);
	float current_id = floor(texture(current_world_texture, sample_uv).r * 255.0 + 0.5);
	float previous_id = floor(texture(previous_world_texture, sample_uv).r * 255.0 + 0.5);
	bool player = all(greaterThanEqual(world_pixel, player_origin_px))
		&& all(lessThan(world_pixel, player_origin_px + player_size_px));
	if (current_id > 0.5 || (previous_id > 0.5 && snapshot_blend < 0.999) || player) {
		discard;
	}
	vec2 p = world_pixel;
	float horizon = smoothstep(20.0, 490.0, p.y);
	vec3 colour = mix(vec3(0.019, 0.027, 0.056), vec3(0.054, 0.108, 0.129), horizon);
	float mist_distance = (p.y - 388.0) / 135.0;
	float mist = exp(-mist_distance * mist_distance);
	colour += vec3(0.009, 0.015, 0.022) * mist;
	// Three restrained depth layers: the foreground architecture remains dominant.
	colour = skyline(colour, p - camera_origin_px * 0.12,
		34.0, 372.0, 11.0, vec3(0.030, 0.055, 0.078), 0.12);
	colour = skyline(colour, p - camera_origin_px * 0.07,
		47.0, 434.0, 37.0, vec3(0.023, 0.043, 0.062), 0.19);
	colour = skyline(colour, p - camera_origin_px * 0.025,
		63.0, 491.0, 63.0, vec3(0.016, 0.028, 0.043), 0.22);
	// Broad pools of coloured haze draw the eye through the nave, not along a
	// repeated screen-space effect. They are scenery, not simulated illumination.
	vec2 core = (p - vec2(512.0, 216.0)) / vec2(175.0, 205.0);
	float aura = exp(-dot(core, core) * 1.9);
	colour += vec3(0.014, 0.070, 0.087) * aura;
	vec2 rose = (p - vec2(774.0, 314.0)) / vec2(110.0, 120.0);
	colour += vec3(0.040, 0.005, 0.021) * exp(-dot(rose, rose));
	float shaft_x = p.x - 512.0 - (p.y - 100.0) * 0.13;
	float shaft_right = (shaft_x - 77.0) / 8.0;
	float shaft_left = (shaft_x + 108.0) / 12.0;
	float shafts = exp(-shaft_right * shaft_right) + exp(-shaft_left * shaft_left);
	colour += vec3(0.013, 0.027, 0.028) * shafts
		* smoothstep(155.0, 260.0, p.y) * (1.0 - smoothstep(465.0, 548.0, p.y));
	// Sparse dust glints, stable per world pixel, with slow presentation-only drift.
	float dust = hash11(p.x + p.y * 113.0);
	float twinkle = 0.55 + 0.45 * sin(TIME * 0.7 + dust * 37.0);
	colour += vec3(0.07, 0.12, 0.13) * step(0.9988, dust) * twinkle * aura;
	// Keep the approved reliquary palette exactly as authored. Lower districts
	// descend from warm residential haze into green utility and swamp atmospheres.
	// These colours only reach empty cells after the common occupancy mask above.
	if (district_index == 1) {
		vec2 garden = (p - vec2(516.0, 278.0)) / vec2(236.0, 165.0);
		colour = colour * vec3(1.7, 0.87, 1.02)
			+ vec3(0.035, 0.022, 0.006) * exp(-dot(garden, garden));
	} else if (district_index == 2) {
		vec2 sluice = (p - vec2(555.0, 337.0)) / vec2(148.0, 220.0);
		colour = colour * vec3(0.68, 1.14, 1.0)
			+ vec3(0.006, 0.026, 0.018) * exp(-dot(sluice, sluice));
	} else if (district_index == 3) {
		vec2 basin = (p - vec2(610.0, 409.0)) / vec2(285.0, 146.0);
		vec2 furnace = (p - vec2(263.0, 271.0)) / vec2(110.0, 180.0);
		colour = colour * vec3(0.61, 1.34, 0.78)
			+ vec3(0.014, 0.041, 0.020) * exp(-dot(basin, basin))
			+ vec3(0.040, 0.020, 0.003) * exp(-dot(furnace, furnace));
	}
	float vignette = 1.0 - smoothstep(155.0, 540.0, abs(p.x - 512.0));
	colour *= 0.78 + 0.22 * vignette;
	COLOR = vec4(colour, 1.0);
}
