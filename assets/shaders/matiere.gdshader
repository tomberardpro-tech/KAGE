shader_type spatial;
// Matières dessinées du décor, style doux et coloré (herbe, dalles, pavés, murs, tuiles, bois...).
// Le motif est calculé à partir de la position dans le monde : pas de texture à charger.
render_mode diffuse_lambert_wrap;
#include "res://assets/shaders/motifs.gdshaderinc"

// 0 herbe, 1 dalles, 2 pavés, 3 enduit blanc, 4 tuiles, 5 bois, 6 pierre de taille,
// 7 sable ratissé, 8 terre battue, 9 rocher moussu, 10 chaume, 11 tatami
uniform int motif = 0;
uniform vec4 couleur_a : source_color = vec4(0.30, 0.45, 0.25, 1.0);
uniform vec4 couleur_b : source_color = vec4(0.20, 0.34, 0.18, 1.0);
uniform vec4 couleur_joint : source_color = vec4(0.10, 0.10, 0.12, 1.0);
uniform float echelle = 1.0;
uniform float mousse = 1.0;

varying vec3 pos_monde;
varying vec3 normale_monde;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = plan(pos_monde, normale_monde) * echelle;
	vec3 c = couleur_a.rgb;
	float rugosite = 0.9;
	vec3 relief = vec3(0.0);  // petite inclinaison de la normale, pour le volume
	float grand = bruit(p * 0.15) * 0.6 + bruit(p * 0.45) * 0.4;

	if (motif == 0) {
		// Herbe : grandes taches claires et foncées, petits brins et trèfles
		float fin = bruit(p * 6.0);
		c = mix(couleur_b.rgb, couleur_a.rgb, smoothstep(0.25, 0.75, grand));
		c *= 0.88 + fin * 0.24;
		float trefle = smoothstep(0.84, 0.88, bruit(p * 2.2 + 17.0)) * step(0.6, bruit(p * 9.0));
		c = mix(c, c * 1.12 + vec3(0.01, 0.03, 0.0), trefle);
	} else if (motif == 1) {
		// Dalles de pierre irrégulières, joints d'herbe sombre
		vec2 v = cellules(p * 1.4);
		float joint = smoothstep(0.03, 0.09, v.x);
		vec3 pierre = mix(couleur_a.rgb, couleur_b.rgb, v.y) * (0.92 + bruit(p * 8.0) * 0.16);
		pierre *= 0.85 + 0.15 * smoothstep(0.05, 0.3, v.x);
		c = mix(couleur_joint.rgb, pierre, joint);
		relief.y = -0.3 * (1.0 - smoothstep(0.03, 0.2, v.x));
	} else if (motif == 2) {
		// Pavés arrondis en rangées
		vec2 b = blocs(p, vec2(0.34, 0.26));
		float joint = smoothstep(0.015, 0.05, b.x);
		vec3 pave = mix(couleur_a.rgb, couleur_b.rgb, b.y) * (0.9 + bruit(p * 10.0) * 0.2);
		pave *= 0.82 + 0.18 * smoothstep(0.02, 0.12, b.x);
		c = mix(couleur_joint.rgb, pave, joint);
	} else if (motif == 3) {
		// Enduit blanc : très légères nuances, un peu sali en bas des murs
		c = couleur_a.rgb * (0.95 + bruit(p * 3.0) * 0.05 + grand * 0.04);
		float bas = 1.0 - smoothstep(0.3, 1.4, pos_monde.y);
		c = mix(c, c * vec3(0.82, 0.8, 0.76), bas * 0.5);
		rugosite = 0.95;
	} else if (motif == 4) {
		// Tuiles rondes (kawara) : rangées en relief avec reflet sur le dessus
		float x = fract(p.x * 3.2);
		float bosse = sin(x * 3.14159);
		float rang = fract(p.y * 2.4);
		float recouvre = smoothstep(0.0, 0.12, rang);
		c = mix(couleur_b.rgb, couleur_a.rgb, bosse * recouvre) * (0.92 + bruit(p * 4.0) * 0.12);
		c *= 0.75 + 0.25 * recouvre;
		relief.x = cos(x * 3.14159) * 0.6;
		rugosite = 0.45;
	} else if (motif == 5) {
		// Planches de bois : veinage et joints
		float planche = floor(p.y * 5.0);
		float veine = bruit(vec2(p.x * 1.5, p.y * 40.0 + planche * 7.0));
		c = mix(couleur_b.rgb, couleur_a.rgb, veine) * (0.88 + hash2(vec2(planche, 3.0)) * 0.24);
		c *= 0.7 + 0.3 * smoothstep(0.0, 0.08, fract(p.y * 5.0));
	} else if (motif == 6) {
		// Pierre de taille en blocs (soubassements)
		vec2 b = blocs(p, vec2(0.6, 0.3));
		float joint = smoothstep(0.012, 0.035, b.x);
		vec3 bloc = mix(couleur_a.rgb, couleur_b.rgb, b.y) * (0.9 + bruit(p * 9.0) * 0.2);
		c = mix(couleur_joint.rgb, bloc, joint);
	} else if (motif == 7) {
		// Sable ratissé du jardin zen : sillons réguliers
		float sillon = sin(p.y * 18.0) * 0.5 + 0.5;
		c = mix(couleur_b.rgb, couleur_a.rgb, sillon) * (0.96 + bruit(p * 30.0) * 0.08);
		relief.z = cos(p.y * 18.0) * 0.35;
	} else if (motif == 8) {
		// Terre battue avec petits cailloux
		c = mix(couleur_b.rgb, couleur_a.rgb, grand) * (0.9 + bruit(p * 7.0) * 0.2);
		float caillou = smoothstep(0.78, 0.8, bruit(p * 5.0 + 3.0));
		c = mix(c, couleur_joint.rgb, caillou * 0.6);
	} else if (motif == 9) {
		// Rocher : gris nuancé, mousse sur le dessus
		c = mix(couleur_b.rgb, couleur_a.rgb, bruit(pos_monde.xz * 3.0 + pos_monde.y * 2.0));
		float mousse_haut = smoothstep(0.55, 0.85, normale_monde.y + (bruit(pos_monde.xz * 4.0) - 0.5) * 0.6);
		c = mix(c, vec3(0.22, 0.36, 0.17), mousse * mousse_haut);
	} else if (motif == 10) {
		// Chaume : brins de paille en couches
		float brin = bruit(vec2(p.x * 30.0, p.y * 2.0));
		float couche = fract(p.y * 3.0);
		c = mix(couleur_b.rgb, couleur_a.rgb, brin) * (0.75 + 0.25 * smoothstep(0.0, 0.3, couche));
	} else {
		// Tatami : tressage fin et bordure
		float trame = sin(p.x * 120.0) * 0.5 + 0.5;
		c = mix(couleur_b.rgb, couleur_a.rgb, trame * 0.5 + 0.5);
	}
	ALBEDO = c;
	ROUGHNESS = rugosite;
	if (relief != vec3(0.0)) {
		vec3 n = normalize(normale_monde + relief);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
}
