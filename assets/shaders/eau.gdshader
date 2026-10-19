shader_type spatial;
// Eau de nuit : petites vagues animées, reflet du ciel sur les bords, éclats des lanternes.
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 couleur_profonde : source_color = vec4(0.02, 0.05, 0.07, 1.0);
uniform vec4 couleur_claire : source_color = vec4(0.07, 0.13, 0.16, 1.0);
uniform vec4 reflet_ciel : source_color = vec4(0.14, 0.18, 0.30, 1.0);
uniform float echelle = 0.8;
uniform float vitesse = 0.25;

varying vec3 pos_monde;

float vagues(vec2 p) {
	float t = TIME * vitesse;
	return bruit(p + vec2(t, t * 0.6)) * 0.5
		+ bruit(p * 2.3 - vec2(t * 1.3, t * 0.4)) * 0.3
		+ bruit(p * 5.1 + vec2(-t, t * 1.7)) * 0.2;
}

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pos_monde.xz * echelle;
	float h = vagues(p);
	float hx = vagues(p + vec2(0.05, 0.0));
	float hz = vagues(p + vec2(0.0, 0.05));
	vec3 n = normalize(vec3((h - hx) * 3.0, 1.0, (h - hz) * 3.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(couleur_profonde.rgb, couleur_claire.rgb, h * 0.7);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = reflet_ciel.rgb * (0.08 + fresnel * 0.8) * (0.5 + h * 0.7);
}
