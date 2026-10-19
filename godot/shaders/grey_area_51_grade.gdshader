shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/grey_area_51_mask.gdshaderinc"

uniform sampler2D scene_colour : hint_screen_texture, filter_nearest;

// Immutable native material IDs drive appearance only. Absolute world-space
// formwork, tie holes and damp streaks remain continuous across all four cuts.
uniform sampler2D current_world_texture : filter_nearest, repeat_disable;
uniform sampler2D previous_world_texture : filter_nearest, repeat_disable;
uniform vec2 view_size_px = vec2(960.0,192.0);
uniform vec2 camera_origin_px = vec2(32.0);
uniform vec2 player_origin_px = vec2(-1000.0);
uniform vec2 player_size_px = vec2(8.0,14.0);
uniform float snapshot_blend = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453);
}
float material_at(vec2 p) {
	return floor(texture(current_world_texture,(p+vec2(0.5))/vec2(1024.0)).r*255.0+0.5);
}
float air(vec2 p) { return 1.0-step(0.5,material_at(p)); }

void fragment() {
	vec2 p = camera_origin_px + floor(UV*view_size_px);
	float id = material_at(p);
	if (id < 0.5 && snapshot_blend < 0.999) {
		float previous = floor(texture(previous_world_texture,(p+vec2(0.5))/vec2(1024.0)).r*255.0+0.5);
		if (grey_temporally_smoothed(previous)) id = previous;
	}
	bool player = all(greaterThanEqual(p,player_origin_px)) && all(lessThan(p,player_origin_px+player_size_px));
	if (id < 0.5 || player) discard;
	float openness = (air(p+vec2(0.0,-3.0))+air(p+vec2(-3.0,0.0))
		+air(p+vec2(3.0,0.0))+air(p+vec2(0.0,3.0))
		+air(p+vec2(0.0,-9.0))+air(p+vec2(-9.0,0.0))
		+air(p+vec2(9.0,0.0))+air(p+vec2(0.0,9.0)))*0.125;
	vec3 source = texture(scene_colour,SCREEN_UV).rgb;
	float luminance = dot(source,vec3(0.2126,0.7152,0.0722));
	vec3 grade = vec3(0.69,0.74,0.73)*(0.84+0.22*sqrt(openness));
	vec3 colour = mix(source,vec3(luminance),0.48)*grade;
	if (id == 58.0) {
		vec2 q = p-vec2(32.0);
		vec2 panel = mod(q+vec2(7.0,5.0),vec2(48.0,32.0));
		vec2 course = floor((q+vec2(7.0,5.0))/vec2(48.0,32.0));
		float pour = hash(course);
		float joint = max(1.0-step(1.0,panel.x),1.0-step(1.0,panel.y));
		float bevel = max(step(1.0,panel.x)*(1.0-step(2.0,panel.x)),step(1.0,panel.y)*(1.0-step(2.0,panel.y)));
		vec2 tie = mod(q+vec2(7.0,5.0),vec2(24.0,32.0));
		float hole = (1.0-step(1.0,abs(tie.x-12.0)))*(1.0-step(1.0,abs(tie.y-14.0)));
		float drip = (1.0-step(1.0,abs(tie.x-12.0)))*step(15.0,tie.y)*(1.0-step(24.0,tie.y));
		float stain = hash(floor(q/vec2(3.0,19.0)));
		float cast = 0.30+pour*0.035+(hash(p)-0.5)*0.028;
		cast -= joint*0.043+hole*0.11+drip*0.018;
		cast += bevel*0.022;
		cast *= 0.96+stain*0.04;
		cast += 0.075*sqrt(openness);
		// Fine aggregate leaves the broad cast planes legible. The material
		// remains native Concrete; only its scene-specific finish is replaced.
		colour = vec3(0.96,1.0,0.98)*cast;
	}
	if (id == 71.0 || id == 72.0) colour = source*vec3(0.62,0.72,0.72);
	if (id >= 77.0) colour = source*vec3(0.84,0.89,0.85);
	if (id == 65.0 || id == 69.0) colour = mix(colour,vec3(luminance*0.68),0.68);
	COLOR = vec4(colour,1.0);
}
