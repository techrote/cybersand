shader_type canvas_item;
render_mode unshaded, blend_mix;

// The existing frozen transparent SubViewport is a premultiplied RGBA source.
// Never filter native material IDs or reconstruct a speculative depth image.
uniform sampler2D surface_texture : filter_nearest, repeat_disable;
uniform vec2 surface_size = vec2(1024.0);
uniform float classic_haze = 0.0;
uniform float effect_strength = 1.0;
uniform float comparison_wipe = 1.0;
uniform int quality_tier = 1;
uniform int lens_method = 0; // 0 pixel aperture, 1 highlight diffusion, 2 detail.
uniform float defocus_radius = 0.0; // Native material cells, bounded to six.
uniform float aperture_weights[7];
uniform int aperture_extent = 0;
uniform float detail_suppression = 0.0;
uniform float plane_contrast = 1.0;
uniform float plane_saturation = 1.0;
uniform vec3 plane_tint = vec3(1.0);
uniform float plane_brightness = 1.0;
uniform float black_lift = 0.0;
uniform float highlight_compression = 0.0;
uniform float atmospheric_density = 0.0;
uniform vec3 scattering_colour = vec3(0.055, 0.105, 0.15);
uniform float illumination_strength = 0.0;
uniform float plane_opacity = 1.0;
uniform float clarity_strength = 0.0;

// Read-only aliases of already published Play data, used only by optional
// presentation shadows/clarity. These never request a native capture or ACK.
uniform sampler2D play_cells : filter_nearest, repeat_disable;
uniform bool play_mask_available = false;
uniform vec2 play_offset = vec2(0.0);
uniform float shadow_strength = 0.0;
uniform vec2 shadow_offset = vec2(5.0, 8.0);
uniform float shadow_softness = 0.0;
uniform vec4 player_rectangle = vec4(-4096.0, -4096.0, 0.0, 0.0);
uniform vec4 actor_rectangles[8];
uniform int actor_rectangle_count = 0;
varying vec4 vertex_colour;

void vertex() {
    vertex_colour = COLOR;
}

bool in_surface(vec2 p) {
    return p.x >= 0.0 && p.y >= 0.0 && p.x < surface_size.x && p.y < surface_size.y;
}

vec4 sample_surface(sampler2D source, vec2 point) {
    if (!in_surface(point)) return vec4(0.0);
    return texture(source, (floor(point) + vec2(0.5)) / surface_size);
}

vec3 straight_colour(vec4 source) {
    return source.a > 0.00001 ? source.rgb / source.a : vec3(0.0);
}

vec4 focused_sample(sampler2D source, vec2 point, float radius, vec4 centre) {
    // Dense positive binomial cross: sample every integer distance up to the
    // bounded support. Adjacent integer weight rows interpolate continuously.
    // Unlike sparse expanding rings, fine contrast cannot return at even radii.
    // One shared centre + four taps per distance; maximum25 source reads.
    if (radius <= 0.0 || aperture_extent == 0) return centre;
    vec4 sum = centre * aperture_weights[0];
    for (int index = 1; index <= 6; index++) {
        if (index > aperture_extent) break;
        float offset = float(index);
        vec4 neighbours = sample_surface(source, point + vec2(offset, 0.0))
            + sample_surface(source, point - vec2(offset, 0.0))
            + sample_surface(source, point + vec2(0.0, offset))
            + sample_surface(source, point - vec2(0.0, offset));
        sum += neighbours * aperture_weights[index] * 0.5;
    }
    return sum;
}

float play_material(vec2 point) {
    if (!in_surface(point)) return 0.0;
    return floor(texture(play_cells, (floor(point) + vec2(0.5)) / surface_size).r * 255.0 + 0.5);
}

float occupied(vec2 point) {
    return step(0.5, play_material(point));
}

float architectural_occluder(vec2 point) {
    float id = play_material(point);
    // Complete admitted Solid set in native/include/cybersand/material.hpp.
    // Reserved10 is excluded. Gases/free liquids/powders do not become opaque
    // architectural casters merely because nonempty. This is a stylised mask,
    // not physical transmission: native glass remains an optional solid caster.
    if (id == 1.0 || id == 5.0 || id == 7.0 || id == 9.0 || id == 11.0 || id == 18.0 || id == 28.0 || id == 31.0 || id == 35.0) return 1.0;
    if (id >= 38.0 && id <= 131.0) return 1.0;
    return 0.0;
}

float architectural_shadow(vec2 point) {
    vec2 p = point - shadow_offset;
    float centre = architectural_occluder(p);
    if (quality_tier == 0 || shadow_softness < 0.01) return centre;
    float r = max(1.0, floor(shadow_softness + 0.5));
    return (centre * 4.0 + architectural_occluder(p + vec2(r, 0.0))
        + architectural_occluder(p - vec2(r, 0.0))
        + architectural_occluder(p + vec2(0.0, r))
        + architectural_occluder(p - vec2(0.0, r))) * 0.125;
}

float local_silhouette(vec2 point) {
    float centre = occupied(point);
    float neighbours = max(max(occupied(point + vec2(2.0, 0.0)), occupied(point - vec2(2.0, 0.0))),
        max(occupied(point + vec2(0.0, 2.0)), occupied(point - vec2(0.0, 2.0))));
    return max(neighbours - centre, 0.0);
}

float rectangle_reveal(vec2 point, vec4 rectangle) {
    if (rectangle.z <= 0.0 || rectangle.w <= 0.0) return 0.0;
    vec2 centre = rectangle.xy + rectangle.zw * 0.5;
    vec2 distance_to_box = max(abs(point - centre) - rectangle.zw * 0.5, vec2(0.0));
    return 1.0 - smoothstep(2.0, 9.0, length(distance_to_box));
}

float actor_reveal(vec2 point) {
    float reveal = rectangle_reveal(point, player_rectangle);
    for (int index = 0; index < 8; index++) {
        if (index >= actor_rectangle_count) break;
        reveal = max(reveal, rectangle_reveal(point, actor_rectangles[index]));
    }
    return reveal;
}

vec4 classic_output(vec4 source) {
    // Preserve the literal Strata002 HAZE expression and the same fixed-function
    // straight-alpha blend. Algebraically equivalent premultiplied output can
    // round differently in an RGBA8 target at nontrivial haze/parent opacity.
    source.rgb = mix(source.rgb, vec3(0.055, 0.105, 0.15), classic_haze);
    return source;
}

void fragment() {
    vec2 point = floor(UV * surface_size) + vec2(0.5);
    vec4 centre = sample_surface(surface_texture, point);
    vec4 classic = classic_output(centre);
    // The Classic wipe side must not enter a premultiply/unpremultiply roundtrip.
    COLOR = classic * vertex_colour;
    if (SCREEN_UV.x <= comparison_wipe && effect_strength > 0.0) {
        float sample_radius = defocus_radius;
        if (detail_suppression > 0.0 || illumination_strength > 0.0) sample_radius = max(sample_radius, 1.0);
        vec4 low = centre;
        if (sample_radius > 0.001) low = focused_sample(surface_texture, point, sample_radius, centre);
        // No downstream operation can create coverage without centre/low
        // coverage: tone/masks only change RGB and diffusion multiplies low.a.
        // Exact zero, never an epsilon: retain every faint aperture/halo pixel.
        if (centre.a == 0.0 && low.a == 0.0) {
            COLOR = vec4(0.0);
        } else {
            vec4 optical = centre;
            if (lens_method == 0 && defocus_radius > 0.0) {
                // sample_radius can exceed defocus only when detail/illumination
                // needs the one-cell kernel. Reuse it instead of reading twice.
                optical = sample_radius == defocus_radius ? low : mix(centre, low, defocus_radius);
            }
            vec3 colour = straight_colour(optical);
            vec3 low_colour = straight_colour(low);
            float detail_mix = detail_suppression;
            if (lens_method == 2) detail_mix = max(detail_mix, min(defocus_radius / 3.0, 0.8));
            // Suppress fine interior contrast without changing the silhouette.
            colour = mix(colour, low_colour, detail_mix);
            float luminance = dot(colour, vec3(0.2126, 0.7152, 0.0722));
            colour = mix(vec3(luminance), colour, plane_saturation);
            colour = (colour - vec3(0.5)) * plane_contrast + vec3(0.5);
            colour = max(colour, vec3(0.0));
            colour = (colour * (1.0 - black_lift) + vec3(black_lift)) * plane_brightness * plane_tint;
            colour = colour / (vec3(1.0) + max(colour - vec3(0.45), vec3(0.0)) * highlight_compression);
            colour = mix(colour, scattering_colour, 1.0 - exp(-atmospheric_density));
            if (shadow_strength > 0.0 && play_mask_available) {
                colour *= 1.0 - architectural_shadow(point + play_offset) * shadow_strength;
            }
            float separation = 0.0;
            if (clarity_strength > 0.0 && play_mask_available) {
                separation = max(local_silhouette(point + play_offset), actor_reveal(point + play_offset));
            }
            colour *= 1.0 - clarity_strength * (0.16 + 0.36 * separation);
            optical = vec4(clamp(colour, vec3(0.0), vec3(1.0)) * optical.a, optical.a);
            // Highlight spread is bounded to the small plane kernel, with coverage
            // union rather than an opaque fullscreen bloom or colour in empty alpha.
            float diffusion = illumination_strength;
            if (lens_method == 1) diffusion += min(defocus_radius * 0.15, 0.65);
            if (diffusion > 0.0) {
                float highlight = smoothstep(0.48, 0.92, dot(low_colour, vec3(0.2126, 0.7152, 0.0722)));
                float halo_alpha = low.a * highlight * min(diffusion * 0.28, 0.5);
                optical.rgb += low_colour * halo_alpha * (1.0 - optical.a * 0.6);
                optical.a = optical.a + halo_alpha * (1.0 - optical.a);
                optical.rgb = min(optical.rgb, vec3(optical.a));
            }
            optical *= plane_opacity * (1.0 - clarity_strength * 0.5);
            // Filtering and effect interpolation remain premultiplied. Convert only
            // at the final boundary, where the existing straight-alpha framebuffer
            // blend applies source coverage and parent opacity exactly once.
            vec4 output_colour = mix(vec4(classic.rgb * classic.a, classic.a), optical, effect_strength);
            COLOR = vec4(straight_colour(output_colour) * vertex_colour.rgb,
                output_colour.a * vertex_colour.a);
        }
    }
}
