shader_type canvas_item;
render_mode unshaded;

// Inputs are rendered material surfaces, never linearly blended material IDs.
// All world coordinates below refer to the authored ROI, not the 1024² backing.
uniform sampler2D layer_0 : filter_nearest, repeat_disable;
uniform sampler2D layer_1 : filter_nearest, repeat_disable;
uniform sampler2D layer_2 : filter_nearest, repeat_disable;
uniform sampler2D layer_3 : filter_nearest, repeat_disable;
uniform sampler2D play_cells : filter_nearest, repeat_disable;
uniform vec2 cell_texture_size = vec2(1024.0);
uniform vec2 world_size = vec2(640.0, 360.0);
uniform vec2 view_size = vec2(480.0, 270.0);
uniform vec2 camera_origin = vec2(80.0, 45.0);
uniform vec4 layer_scale = vec4(1.0, 0.94, 0.88, 0.78);
uniform vec4 layer_parallax = vec4(1.0, 0.70, 0.44, 0.18);
uniform vec4 layer_visibility = vec4(1.0);
uniform int mode = 3;
uniform float parallax_strength = 1.0;
uniform float relief_depth = 12.0;
uniform int relief_slices = 8;
uniform float relief_quantization = 2.0;
uniform vec2 relief_direction = vec2(0.78, 0.42);
uniform float fog_strength = 0.32;
uniform float occluder_strength = 0.8;
uniform bool cutaway = true;
uniform vec2 focus_position = vec2(344.0, 180.0);
uniform float cutaway_radius = 68.0;
uniform float reflection_strength = 0.18;
uniform float reflection_line_y = 278.0;
uniform float presentation_time = 0.0;

bool inside_world(vec2 p) {
    return p.x >= 0.0 && p.y >= 0.0 && p.x < world_size.x && p.y < world_size.y;
}

vec2 layer_point(vec2 logical, float factor, float scale) {
    vec2 anchor = world_size * 0.5;
    vec2 delta = camera_origin + view_size * 0.5 - anchor;
    float effective_factor = 1.0 + (factor - 1.0) * parallax_strength;
    return anchor + delta * effective_factor + (logical - view_size * 0.5) / scale;
}

vec4 read_surface(sampler2D source, vec2 point) {
    if (!inside_world(point)) return vec4(0.0);
    return texture(source, (floor(point) + vec2(0.5)) / world_size);
}

int material_at(vec2 point) {
    if (!inside_world(point)) return 0;
    return int(floor(texture(play_cells, (floor(point) + vec2(0.5)) / cell_texture_size).r * 255.0 + 0.5));
}

vec4 over(vec4 back, vec4 front) {
    return front + back * (1.0 - front.a);
}

vec4 veil(vec4 source, float depth) {
    float haze = clamp(fog_strength * depth, 0.0, 0.9);
    float grey = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 colour = mix(source.rgb, vec3(grey), haze * 0.30);
    colour = mix(colour, vec3(0.055, 0.13, 0.19) * source.a, haze);
    return vec4(colour, source.a);
}

float material_depth(int id) {
    // MAT-002 keeps the authored glass/panel and timber bands instead of
    // dropping the expanded building catalogue out of foreground relief.
    if (id == 96 || (id >= 120 && id <= 124) || id == 129) return 0.38;
    if ((id >= 81 && id <= 94) || id == 125 || id == 128) return 0.70;
    if (id >= 81 && id <= 131) return 1.0;
    if (id == 9 || id == 35 || id == 43 || id == 44 || id == 68 || id == 69) return 0.38;
    if (id == 7 || id == 41 || id == 42) return 0.70;
    if (id == 1 || id == 13 || id == 28 || id == 29 || id == 31 || (id >= 38 && id <= 80)) return 1.0;
    return 0.0;
}

vec4 rear_scene(vec2 logical) {
    vec4 far_plane = read_surface(layer_3, layer_point(logical, layer_parallax.w, layer_scale.w)) * layer_visibility.w;
    vec4 weather = read_surface(layer_2, layer_point(logical, layer_parallax.z, layer_scale.z)) * layer_visibility.z;
    vec4 set_plane = read_surface(layer_1, layer_point(logical, layer_parallax.y, layer_scale.y)) * layer_visibility.y;
    return over(over(veil(far_plane, 1.0), veil(weather, 0.62)), veil(set_plane, 0.35));
}

void fragment() {
    vec2 logical = floor(UV * view_size) + vec2(0.5);
    vec2 play_point = layer_point(logical, 1.0, 1.0);
    float sky_gradient = clamp(logical.y / view_size.y, 0.0, 1.0);
    vec4 result = vec4(mix(vec3(0.025, 0.035, 0.062), vec3(0.010, 0.018, 0.030), sky_gradient), 1.0);
    if (mode >= 2) result = over(result, rear_scene(logical));
    if ((mode == 1 || mode >= 3) && relief_depth > 0.0 && layer_visibility.x > 0.0) {
        vec2 camera_delta = camera_origin + view_size * 0.5 - world_size * 0.5;
        vec2 direction = relief_direction + camera_delta / view_size * 0.8 * parallax_strength;
        float quantization = max(relief_quantization, 1.0);
        for (int i = 8; i >= 1; i--) {
            if (i > relief_slices) continue;
            float depth = float(i) / float(max(relief_slices, 1));
            float slice_scale = 1.0 - depth * 0.018;
            vec2 point = (play_point - world_size * 0.5) / slice_scale + world_size * 0.5;
            point -= direction * relief_depth * depth;
            point += camera_delta * depth * 0.04 * parallax_strength;
            point = floor(point / quantization) * quantization + vec2(quantization * 0.5);
            int id = material_at(point);
            if (material_depth(id) + 0.001 < depth) continue;
            vec4 face = read_surface(layer_0, point);
            face.rgb *= mix(0.50, 0.22, depth);
            face.rgb = mix(face.rgb, vec3(0.035, 0.075, 0.10) * face.a, depth * 0.24);
            result = over(result, face * layer_visibility.x);
        }
    }
    vec4 play = read_surface(layer_0, play_point) * layer_visibility.x;
    int play_id = material_at(play_point);
    if (mode >= 3 && reflection_strength > 0.0 && (play_id == 3 || play_id == 16 || play_id == 33)) {
        float ripple = floor(sin(play_point.y * 0.71 + presentation_time * 1.8) * 2.0);
        vec2 reflected_logical = vec2(logical.x + ripple, 2.0 * (reflection_line_y - camera_origin.y) - logical.y);
        vec4 reflection = rear_scene(reflected_logical);
        float band = 0.5 + 0.5 * step(0.5, fract(play_point.y * 0.5));
        play.rgb = mix(play.rgb, reflection.rgb * play.a, reflection_strength * band * reflection.a);
    }
    result = over(result, play);
    if (mode == 4 && occluder_strength > 0.0) {
        float frame_scale = min(view_size.x / world_size.x, view_size.y / world_size.y) * 1.06;
        vec2 near_point = layer_point(logical, 1.55, frame_scale);
        near_point = floor(near_point / 2.0) * 2.0 + vec2(1.0);
        vec4 near = read_surface(layer_0, near_point);
        float rim = smoothstep(0.28, 0.46, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
        float focus_mask = 1.0;
        if (cutaway) {
            vec2 focus_logical = focus_position - camera_origin;
            focus_mask = smoothstep(cutaway_radius * 0.66, cutaway_radius, distance(logical, focus_logical));
        }
        near.rgb = mix(near.rgb * 0.17, vec3(0.018, 0.030, 0.045) * near.a, 0.55);
        result = over(result, near * rim * focus_mask * occluder_strength);
    }
    COLOR = vec4(result.rgb, 1.0);
}
