shader_type spatial;
// Flaque de pluie : forme irrégulière, surface lisse qui reflète le ciel et les lanternes,
// petits ronds qui s'ouvrent sous la pluie.
render_mode blend_mix, depth_draw_opaque, cull_back;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec3 couleur : source_color = vec3(0.05, 0.07, 0.11);

varying vec3 pos_monde;
varying vec3 graine;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	graine = MODEL_MATRIX[3].xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float bord = length(p) + (bruit(p * 2.3 + graine.xz) - 0.5) * 0.6;
	float forme = smoothstep(0.85, 0.65, bord);
	if (forme < 0.01) {
		discard;
	}
	// ronds de pluie : une goutte par cellule, à un moment différent
	vec2 q = pos_monde.xz * 3.0;
	vec2 cellule = floor(q);
	vec2 n = vec2(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = cellule + vec2(float(i), float(j));
			vec2 centre = c + vec2(hash(c), hash(c + 7.0));
			float t = fract(TIME * 0.8 + hash(c + 3.0));
			vec2 v = q - centre;
			float d = length(v);
			float onde = sin((d - t * 0.6) * 40.0) * smoothstep(0.08, 0.0, abs(d - t * 0.6)) * (1.0 - t);
			n += normalize(v + 0.0001) * onde;
		}
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(vec3(n.x, 1.0, n.y) * vec3(0.25, 1.0, 0.25), 0.0)).xyz);
	ALBEDO = couleur;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = forme * 0.82;
}
