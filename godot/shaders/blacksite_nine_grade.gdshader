shader_type canvas_item;
render_mode unshaded, blend_mul;

// Scene-only exposure and a bounded, eight-sample recess shadow. This consumes
// immutable render textures and multiplies appearance; it changes no material,
// collision, rule, publication or player state. Absolute world samples keep the
// treatment continuous at tile boundaries and when the camera follows a player.
uniform sampler2D current_world_texture : filter_nearest, repeat_disable;
uniform sampler2D previous_world_texture : filter_nearest, repeat_disable;
uniform vec2 view_size_px = vec2(960.0);
uniform vec2 camera_origin_px = vec2(32.0);
uniform vec2 player_origin_px = vec2(-1000.0);
uniform vec2 player_size_px = vec2(8.0,14.0);
uniform float snapshot_blend = 1.0;

float material_at(vec2 point) {
	return floor(texture(current_world_texture, (point + vec2(0.5)) / vec2(1024.0)).r * 255.0 + 0.5);
}

float air(vec2 point) {
	return 1.0 - step(0.5, material_at(point));
}

void fragment() {
	vec2 p = camera_origin_px + floor(UV * view_size_px);
	float id = material_at(p);
	if (id < 0.5 && snapshot_blend < 0.999) {
		id = floor(texture(previous_world_texture, (p + vec2(0.5)) / vec2(1024.0)).r * 255.0 + 0.5);
	}
	bool player = all(greaterThanEqual(p, player_origin_px))
		&& all(lessThan(p, player_origin_px + player_size_px));
	if (id < 0.5 || player) discard;
	float openness = (air(p+vec2(0.0,-4.0)) + air(p+vec2(-4.0,0.0))
		+ air(p+vec2(4.0,0.0)) + air(p+vec2(0.0,4.0))
		+ air(p+vec2(0.0,-11.0)) + air(p+vec2(-11.0,0.0))
		+ air(p+vec2(11.0,0.0)) + air(p+vec2(0.0,11.0))) * 0.125;
	float depth = smoothstep(290.0,960.0,p.y);
	float exposure = 0.49 + 0.40 * sqrt(openness) - depth * 0.055;
	vec3 grade = vec3(0.97,1.0,0.92) * exposure;
	// Readable instrument glass and guide lamps remain the brightest accents.
	if (id >= 77.0) grade = vec3(0.91,0.94,0.88);
	if (id == 71.0 || id == 72.0) grade = max(grade,vec3(0.70,0.78,0.75));
	if (id == 3.0) grade *= vec3(0.73,0.85,0.63);
	COLOR = vec4(grade,1.0);
}
