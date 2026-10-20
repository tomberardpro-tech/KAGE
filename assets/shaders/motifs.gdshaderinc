// Outils des matières dessinées : bruit, cellules (dalles, pierres) et projection selon la face.
#include "res://assets/shaders/bruit.gdshaderinc"

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Cellules de Voronoï : x = distance au bord de la cellule, y = numéro de la cellule (0..1).
vec2 cellules(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 proche = vec2(0.0);
	vec2 id = vec2(0.0);
	float d1 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) { d1 = d; proche = r; id = i + g; }
		}
	}
	float bord = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			if (dot(proche - r, proche - r) > 0.0001) {
				bord = min(bord, dot(0.5 * (proche + r), normalize(r - proche)));
			}
		}
	}
	return vec2(bord, hash2(id));
}

// Coordonnées 2D sur la face : le dessus utilise xz, les murs utilisent leur plan vertical.
vec2 plan(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return vec2(p.z, -p.y);
	return vec2(p.x, -p.y);
}

// Briques ou blocs en rangées décalées : x = distance au joint, y = numéro du bloc.
vec2 blocs(vec2 p, vec2 taille) {
	vec2 q = p / taille;
	float rang = floor(q.y);
	q.x += mod(rang, 2.0) * 0.5;
	vec2 id = vec2(floor(q.x), rang);
	vec2 f = fract(q) - 0.5;
	vec2 d = (0.5 - abs(f)) * taille;
	return vec2(min(d.x, d.y), hash2(id));
}
