shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/grey_area_51_mask.gdshaderinc"

// Recessed bunker walls are drawn only behind currently Empty native cells.
// No camera-relative tint, noise, parallax or vignette can reveal a tile edge.
uniform sampler2D current_world_texture : filter_nearest, repeat_disable;
uniform sampler2D previous_world_texture : filter_nearest, repeat_disable;
uniform vec2 view_size_px = vec2(960.0,192.0);
uniform vec2 camera_origin_px = vec2(32.0);
uniform vec2 player_origin_px = vec2(-1000.0);
uniform vec2 player_size_px = vec2(8.0,14.0);
uniform float snapshot_blend = 1.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float pool(vec2 p,vec2 centre,vec2 radius) {
	vec2 d = (p-centre)/radius;
	return exp(-dot(d,d)*2.0);
}

void fragment() {
	vec2 wp = camera_origin_px+floor(UV*view_size_px);
	vec2 sample_uv = (wp+vec2(0.5))/vec2(1024.0);
	float current = floor(texture(current_world_texture,sample_uv).r*255.0+0.5);
	float previous = floor(texture(previous_world_texture,sample_uv).r*255.0+0.5);
	bool player = all(greaterThanEqual(wp,player_origin_px)) && all(lessThan(wp,player_origin_px+player_size_px));
	if (current > 0.5 || (grey_temporally_smoothed(previous) && snapshot_blend < 0.999) || player) discard;
	vec2 p = wp-vec2(32.0);
	vec3 colour = vec3(0.023,0.030,0.031);
	vec2 panel = mod(p+vec2(13.0,7.0),vec2(29.0,21.0));
	float joint = max(1.0-step(1.0,panel.x),1.0-step(1.0,panel.y));
	colour *= 1.0-joint*0.27;
	float rib = 1.0-step(3.0,mod(p.x+17.0,67.0));
	colour *= 1.0-rib*0.3;
	float wire = 1.0-step(1.0,mod(p.y+10.0,27.0));
	colour += vec3(0.008,0.009,0.008)*wire;
	colour += vec3(0.020,0.018,0.011)*pool(p,vec2(55.0,117.0),vec2(65.0,44.0));
	colour += vec3(0.003,0.014,0.015)*pool(p,vec2(493.0,82.0),vec2(85.0,61.0));
	colour += vec3(0.018,0.011,0.006)*pool(p,vec2(677.0,119.0),vec2(79.0,50.0));
	colour += vec3(0.005,0.010,0.013)*pool(p,vec2(892.0,128.0),vec2(65.0,54.0));
	colour *= 0.88+hash(wp)*0.20;
	COLOR = vec4(colour,1.0);
}
