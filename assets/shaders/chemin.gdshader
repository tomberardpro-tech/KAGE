shader_type spatial;
// Chemin de terre battue : UV.x va d'un bord à l'autre, UV.y suit la longueur (en m).
// Terre battue nuancée, des cailloux et un bord irrégulier où l'herbe reprend sa place.
render_mode diffuse_lambert_wrap;
#include "res://assets/shaders/motifs.gdshaderinc"

uniform vec4 terre_claire : source_color = vec4(0.62, 0.49, 0.35, 1.0);
uniform vec4 terre_sombre : source_color = vec4(0.40, 0.30, 0.21, 1.0);
uniform vec4 herbe : source_color = vec4(0.25, 0.40, 0.20, 1.0);

varying vec3 pos_monde;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pos_monde.xz;
	float x = UV.x * 2.0 - 1.0;  // -1 .. 1 en travers (le ruban déborde un peu : 1.25 × la largeur)
	float bruit_bord = bruit(p * 1.3) * 0.25 + bruit(p * 5.0) * 0.1;
	float bord = abs(x) * 1.25 + bruit_bord - 0.12;
	if (bord > 1.0) {
		discard;
	}
	float grand = bruit(p * 0.6) * 0.6 + bruit(p * 2.0) * 0.4;
	vec3 c = mix(terre_sombre.rgb, terre_claire.rgb, smoothstep(0.2, 0.8, grand));
	c *= 0.9 + bruit(p * 14.0) * 0.18;
	// cailloux
	vec2 cel = cellules(p * 6.0);
	// un caillou arrondi au cœur de quelques cellules (pas leur contour)
	float caillou = smoothstep(0.2, 0.26, cel.x) * step(0.93, cel.y);
	c = mix(c, mix(vec3(0.55, 0.53, 0.5), vec3(0.38, 0.36, 0.34), cel.y), caillou);
	// l'herbe déborde sur les bords
	float herbu = smoothstep(0.72, 0.98, bord);
	c = mix(c, herbe.rgb * (0.8 + bruit(p * 9.0) * 0.4), herbu);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
