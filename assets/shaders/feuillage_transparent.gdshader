shader_type spatial;
// Feuillage des gros buissons quand le ninja est dedans : le même, mais à moitié transparent.
render_mode diffuse_lambert_wrap, cull_back;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 couleur_claire : source_color = vec4(0.24, 0.42, 0.18, 1.0);
uniform vec4 couleur_sombre : source_color = vec4(0.05, 0.13, 0.06, 1.0);
uniform float touffes = 7.0;
uniform float vent = 0.03;

varying vec3 pos_monde;
varying vec3 normale_monde;

float relief(vec3 p) {
	return bruit(p.xz * touffes + p.y * 3.1) * 0.6 + bruit(p.xy * touffes * 2.1 + p.z * 1.7) * 0.4;
}

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float b = sin(TIME * 1.3 + pos_monde.x * 0.7 + pos_monde.z * 0.5);
	VERTEX.xz += vec2(b, b * 0.6) * vent * clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
	float r = relief(pos_monde);
	float rx = relief(pos_monde + vec3(0.03, 0.0, 0.0));
	float ry = relief(pos_monde + vec3(0.0, 0.03, 0.0));
	float rz = relief(pos_monde + vec3(0.0, 0.0, 0.03));
	vec3 n = normalize(normale_monde + vec3(r - rx, r - ry, r - rz) * 9.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float haut = clamp(normale_monde.y * 0.5 + 0.5, 0.0, 1.0);
	float creux = smoothstep(0.25, 0.75, r);
	ALBEDO = mix(couleur_sombre.rgb, couleur_claire.rgb, clamp(haut * 0.65 + creux * 0.55 - 0.15, 0.0, 1.0));
	ROUGHNESS = 0.85;
	ALPHA = 0.42;
}
