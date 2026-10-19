shader_type spatial;
// Nappe de brume au ras du sol, qui dérive lentement.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 couleur : source_color = vec4(0.55, 0.60, 0.72, 1.0);
uniform float densite = 0.5;

varying vec3 pos_monde;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pos_monde.xz * 0.18 + vec2(TIME * 0.02, TIME * 0.012);
	float n = bruit(p) * 0.6 + bruit(p * 2.7 - vec2(TIME * 0.03, 0.0)) * 0.4;
	vec2 c = UV * 2.0 - 1.0;
	float bord = 1.0 - smoothstep(0.4, 1.0, length(c));
	ALBEDO = couleur.rgb;
	ALPHA = clamp(smoothstep(0.3, 0.8, n) * bord * densite, 0.0, 1.0);
}
