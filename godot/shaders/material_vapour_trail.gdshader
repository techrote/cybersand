shader_type canvas_item;
render_mode unshaded;

// Presentation-only vapour persistence. Two half-float SubViewports ping-pong
// once per rendered frame: each frame keeps the brighter of the current Steam/
// Smoke coverage and the reprojected, slightly risen and diffused previous
// frame, decayed exponentially. The palette pass draws the remainder over
// Empty cells, so a vanished or moved gas cell fades out over a fraction of a
// second instead of popping. It reads the same immutable RG8 snapshot and
// never feeds anything back into the simulation.
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform sampler2D history_texture : filter_linear, repeat_disable;
uniform vec2 world_size_px = vec2(1024.0, 1024.0);
uniform vec2 view_size_px = vec2(320.0, 180.0);
uniform vec2 camera_origin_px = vec2(0.0);
uniform vec2 history_origin_px = vec2(0.0);
// Seconds since the history frame was written; 0 clears the history.
uniform float delta_seconds = 0.016;
uniform float condition_projection_enabled = 0.0;
uniform float presentation_time_override = -1.0;
// e-folding times. Steam lingers briefly as a bright afterimage; smoke thins
// a little more slowly so its final disappearance reads as dissipation.
uniform float steam_fade_seconds = 0.42;
uniform float smoke_fade_seconds = 0.65;
uniform float rise_px_per_second = 5.0;

float presentation_time() {
	return presentation_time_override >= 0.0 ? presentation_time_override : TIME;
}

void fragment() {
	vec2 view_pixel = floor(UV * view_size_px);
	vec2 world_pixel = camera_origin_px + view_pixel;
	vec2 clamped = clamp(world_pixel, vec2(0.0), world_size_px - vec2(1.0));
	vec2 cell = texture(world_texture, (clamped + vec2(0.5)) / world_size_px).rg;
	int material_id = int(floor(cell.r * 255.0 + 0.5));
	float condition = condition_projection_enabled > 0.5 ? cell.g : 0.8;
	float steam = material_id == 22 ? 0.55 + 0.45 * condition : 0.0;
	float smoke = material_id == 4 ? 0.30 + 0.70 * condition : 0.0;

	vec2 history = vec2(0.0);
	if (delta_seconds > 0.0) {
		float t = presentation_time();
		// Reading from slightly below moves the remembered vapour upward; the
		// small lateral wobble and bilinear filter diffuse it as it fades.
		vec2 drift = vec2(
			sin(t * 1.3 + world_pixel.y * 0.21) * 0.35,
			rise_px_per_second * delta_seconds
		);
		vec2 history_pixel = world_pixel - history_origin_px + vec2(0.5) + drift;
		vec2 history_uv = history_pixel / view_size_px;
		if (all(greaterThanEqual(history_uv, vec2(0.0))) && all(lessThanEqual(history_uv, vec2(1.0)))) {
			history = texture(history_texture, history_uv).rg;
			history *= vec2(
				exp(-delta_seconds / max(steam_fade_seconds, 0.01)),
				exp(-delta_seconds / max(smoke_fade_seconds, 0.01))
			);
		}
	}
	vec2 result = max(vec2(steam, smoke), history);
	// Clip the invisible tail so the buffer reaches exact zero.
	result *= step(vec2(0.012), result);
	COLOR = vec4(result, 0.0, 1.0);
}
