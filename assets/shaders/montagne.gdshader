shader_type spatial;
// Montagnes au loin : dégradé doux du pied (pris dans la brume bleue) au sommet, avec un peu de
// neige éclairée par la lune. Le maillage fait 1 de haut : VERTEX.y va de 0 au sommet.
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 pied : source_color = vec4(0.25, 0.29, 0.44, 1.0);
uniform vec4 sommet : source_color = vec4(0.15, 0.18, 0.30, 1.0);
uniform vec4 neige : source_color = vec4(0.62, 0.68, 0.86, 1.0);

varying float hauteur;
varying vec3 pos_monde;

void vertex() {
	hauteur = VERTEX.y;
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = mix(pied.rgb, sommet.rgb, smoothstep(0.0, 0.75, hauteur));
	float limite = 0.8 + (bruit(pos_monde.xz * 0.08) - 0.5) * 0.14;
	c = mix(c, neige.rgb, smoothstep(limite, limite + 0.04, hauteur) * 0.85);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
