shader_type sky;
// Ciel de nuit : dégradé bleu nuit, étoiles qui scintillent, lune avec son halo, nuages qui passent.
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec3 haut : source_color = vec3(0.02, 0.03, 0.08);
uniform vec3 horizon : source_color = vec3(0.13, 0.17, 0.3);
uniform vec3 lune : source_color = vec3(0.95, 0.93, 0.85);
uniform vec3 nuage : source_color = vec3(0.16, 0.19, 0.3);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, -1.0, 1.0);
	vec3 c = mix(horizon, haut, smoothstep(0.0, 0.6, h));
	if (h < 0.0) {
		c = mix(horizon, haut * 0.6, smoothstep(0.0, -0.4, h));
	}
	// étoiles : une cellule sur cinquante s'allume, scintillement lent
	vec3 cellule = floor(d * 180.0);
	float e = step(0.985, hash3(cellule));
	float centre = 1.0 - smoothstep(0.0, 0.45, length(fract(d * 180.0) - 0.5));
	float scintille = 0.6 + 0.4 * sin(TIME * (1.0 + hash3(cellule + 3.0) * 3.0) + hash3(cellule) * 40.0);
	c += vec3(0.85, 0.9, 1.0) * e * centre * scintille * smoothstep(0.05, 0.3, h);
	// lune, dans la direction de la lumière principale
	vec3 vers_lune = normalize(LIGHT0_DIRECTION);
	float a = dot(d, vers_lune);
	float disque = smoothstep(0.9993, 0.9996, a);
	float taches = bruit(d.xz * 260.0) * 0.18;
	c = mix(c, lune * (1.0 - taches), disque);
	c += lune * 0.25 * pow(max(a, 0.0), 180.0) + horizon * 0.5 * pow(max(a, 0.0), 12.0);
	// nuages qui passent lentement
	vec2 uv = d.xz / max(d.y + 0.15, 0.05);
	float n = bruit(uv * 1.2 + vec2(TIME * 0.01, 0.0)) * 0.65 + bruit(uv * 3.1 - vec2(TIME * 0.015, 0.0)) * 0.35;
	float couvre = smoothstep(0.5, 0.78, n) * smoothstep(0.0, 0.25, h);
	vec3 bord = nuage + lune * 0.15 * pow(max(a, 0.0), 6.0);
	c = mix(c, bord, couvre * 0.85);
	COLOR = c;
}
