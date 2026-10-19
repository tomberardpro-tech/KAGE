shader_type spatial;
// Chute d'eau : filets qui descendent, plus clairs en bas où l'eau écume.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 couleur : source_color = vec4(0.62, 0.74, 0.92, 1.0);
uniform float vitesse = 1.0;

void fragment() {
	float t = TIME * vitesse;
	float filets = bruit(vec2(UV.x * 16.0, UV.y * 2.5 - t * 3.0)) * 0.6
		+ bruit(vec2(UV.x * 34.0, UV.y * 5.0 - t * 5.0)) * 0.4;
	float bords = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float ecume = smoothstep(0.7, 1.0, UV.y);
	ALBEDO = couleur.rgb * (0.55 + filets * 0.6) + vec3(ecume * 0.35);
	ALPHA = clamp((0.25 + filets * 0.7 + ecume * 0.3) * bords, 0.0, 0.95);
}
