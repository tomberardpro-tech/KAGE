shader_type spatial;
// Tige de bambou : vert qui fonce vers le bas, avec les nœuds.
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 couleur : source_color = vec4(0.30, 0.42, 0.20, 1.0);

varying vec3 pos_monde;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float b = sin(TIME * 0.9 + pos_monde.x * 1.3 + pos_monde.z);
	VERTEX.x += b * 0.025 * max(VERTEX.y + 0.5, 0.0);
}

void fragment() {
	float noeud = smoothstep(0.92, 0.97, fract(pos_monde.y * 1.6 + hash2(floor(pos_monde.xz * 9.0))));
	vec3 c = couleur.rgb * (0.55 + 0.45 * clamp(pos_monde.y / 3.0, 0.0, 1.0));
	ALBEDO = mix(c, c * 0.45, noeud);
	ROUGHNESS = 0.5;
}
