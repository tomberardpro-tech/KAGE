shader_type spatial;
// Gazon : touffes courtes posées partout sur l'herbe, qui ondulent avec le vent.
render_mode cull_disabled, diffuse_lambert_wrap, shadows_disabled;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 pied : source_color = vec4(0.19, 0.34, 0.16, 1.0);
uniform vec4 pointe : source_color = vec4(0.38, 0.56, 0.27, 1.0);
uniform float hauteur_brin = 0.3;

varying float hauteur;
varying float teinte;

void vertex() {
	hauteur = clamp(VERTEX.y / hauteur_brin, 0.0, 1.0);
	vec3 monde = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	teinte = bruit(monde.xz * 0.3);
	float vent = sin(TIME * 1.8 + monde.x * 0.6 + monde.z * 0.4) + 0.4 * sin(TIME * 3.1 + monde.z * 1.3);
	VERTEX.x += vent * 0.05 * hauteur * hauteur;
	VERTEX.z += vent * 0.03 * hauteur * hauteur;
}

void fragment() {
	ALBEDO = mix(pied.rgb, pointe.rgb, hauteur) * (0.85 + teinte * 0.3);
	ROUGHNESS = 0.85;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
