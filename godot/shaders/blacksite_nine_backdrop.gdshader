shader_type canvas_item;
render_mode unshaded;

// The same absolute-world backdrop is sampled in overview, tile and follow
// views. No per-camera parallax, vignette, tile tint or time-dependent grain can
// introduce an edge discontinuity. Only published Empty cells receive scenery.
uniform sampler2D current_world_texture : filter_nearest, repeat_disable;
uniform sampler2D previous_world_texture : filter_nearest, repeat_disable;
uniform vec2 view_size_px = vec2(960.0);
uniform vec2 camera_origin_px = vec2(32.0);
uniform vec2 player_origin_px = vec2(-1000.0);
uniform vec2 player_size_px = vec2(8.0, 14.0);
uniform float snapshot_blend = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float box(vec2 p, vec2 centre, vec2 half_size) {
	vec2 edge = step(abs(p - centre), half_size);
	return edge.x * edge.y;
}

float pool(vec2 p, vec2 centre, vec2 radius) {
	vec2 d = (p - centre) / radius;
	return exp(-dot(d, d) * 1.8);
}

vec3 surface(vec2 p) {
	float height = smoothstep(0.0, 276.0, p.y);
	vec3 colour = mix(vec3(0.020, 0.026, 0.029), vec3(0.071, 0.079, 0.070), height);
	// An unbroken line of dead manufacturing sheds and chimney stacks.
	for (int layer = 0; layer < 2; layer++) {
		float pitch = layer == 0 ? 67.0 : 113.0;
		float column = floor((p.x + float(layer) * 31.0) / pitch);
		float local_x = mod(p.x + float(layer) * 31.0, pitch);
		float variety = hash(vec2(column, float(layer) + 5.0));
		float roof = 166.0 + float(layer) * 41.0 - variety * 63.0;
		float width = pitch * (0.48 + variety * 0.24);
		float mass = step(local_x, width) * step(roof, p.y);
		float chimney = box(vec2(local_x, p.y), vec2(width * 0.72, roof - 29.0), vec2(4.0, 31.0));
		vec3 shade = layer == 0 ? vec3(0.047,0.056,0.052) : vec3(0.029,0.037,0.034);
		colour = mix(colour, shade, max(mass, chimney));
		float roof_rim = step(abs(p.y - roof), 1.0) * step(local_x, width);
		colour += vec3(0.006, 0.007, 0.004) * roof_rim;
	}
	float cable_y = 84.0 + 0.00015 * pow(mod(p.x + 125.0, 370.0) - 185.0, 2.0);
	colour *= 1.0 - 0.26 * step(abs(p.y - cable_y), 0.65);
	colour += vec3(0.018, 0.012, 0.006) * pool(p, vec2(166.0, 238.0), vec2(248.0, 48.0));
	return colour;
}

vec3 subterranean(vec2 p) {
	float depth = smoothstep(300.0, 960.0, p.y);
	vec3 colour = mix(vec3(0.028,0.035,0.032), vec3(0.014,0.023,0.025), depth);
	// Dim secondary wall courses and conduit runs, behind the native cutaway.
	vec2 plate = mod(p + vec2(21.0, 9.0), vec2(73.0, 47.0));
	float joint = max(step(plate.x, 1.0), step(plate.y, 1.0));
	colour *= 1.0 - joint * 0.24;
	float rib = step(mod(p.x + 18.0, 116.0), 5.0);
	colour *= 1.0 - rib * 0.30;
	float pipe_y = mod(p.y + 34.0, 137.0);
	colour += vec3(0.008,0.009,0.006) * step(pipe_y, 2.0);
	colour *= 1.0 - step(3.0, pipe_y) * step(pipe_y, 7.0) * 0.22;
	colour += vec3(0.017,0.009,0.002) * pool(p,vec2(190.0,462.0),vec2(153.0,94.0));
	colour += vec3(0.002,0.014,0.018) * pool(p,vec2(551.0,445.0),vec2(95.0,92.0));
	colour += vec3(0.024,0.009,0.002) * pool(p,vec2(166.0,809.0),vec2(135.0,119.0));
	colour += vec3(0.003,0.013,0.011) * pool(p,vec2(835.0,904.0),vec2(172.0,92.0));
	return colour;
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
	vec2 p = world_pixel - vec2(32.0);
	vec3 colour = mix(surface(p), subterranean(p), smoothstep(272.0, 293.0, p.y));
	float grit = hash(world_pixel);
	colour *= 0.88 + grit * 0.18;
	float stain = hash(floor(world_pixel / vec2(3.0,19.0)));
	colour *= 0.92 + stain * 0.08;
	COLOR = vec4(colour, 1.0);
}
