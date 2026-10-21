shader_type spatial;
// Esprit (scripts/esprits.gd) : petit fantôme à la Hollow Knight, dessiné en SDF sur un quad
// toujours face à la caméra. Tête en goutte dont le haut s'étire en volute recourbée, deux
// billes qui flottent au-dessus, grands yeux clairs en amande, petite cape qui ondule, bas en
// deux petites pointes. Palette mystique : indigo au bord, violet, cœur cyan lumineux.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 coeur : source_color = vec3(0.4, 0.85, 1.0);
uniform vec3 violet : source_color = vec3(0.48, 0.12, 0.95);
uniform vec3 bleu : source_color = vec3(0.2, 0.05, 0.55);
uniform vec3 cape : source_color = vec3(0.56, 0.6, 0.86);
uniform vec3 yeux_c : source_color = vec3(0.92, 0.98, 1.0);
uniform float opacite = 1.0;
uniform float phase = 0.0;
uniform vec2 taille = vec2(1.4, 2.0);  // taille du quad, en mètres

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float ellipse(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

// trait épais qui s'amincit le long d'un arc de cercle (centre c, rayon r),
// de l'angle a0 en tournant dans le sens horaire sur une ouverture « ouv »
float arc_effile(vec2 p, vec2 c, float r, float a0, float ouv, float w0, float w1) {
	vec2 q = p - c;
	float a = atan(q.y, q.x);
	float s = a0 - a;
	s = s - 6.2831853 * floor(s / 6.2831853);  // 0..2π, sens horaire
	float u = s / ouv;
	if (u > 1.0) {
		// au-delà de la pointe : distance au bout ou au départ, le plus proche
		vec2 fin = c + r * vec2(cos(a0 - ouv), sin(a0 - ouv));
		vec2 dep = c + r * vec2(cos(a0), sin(a0));
		return min(length(p - fin) - w1, length(p - dep) - w0);
	}
	return abs(length(q) - r) - mix(w0, w1, u);
}

// segment effilé de a (épaisseur wa) à b (épaisseur wb)
float trait(vec2 p, vec2 a, vec2 b, float wa, float wb) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - mix(wa, wb, h);
}

void fragment() {
	vec2 p = (vec2(UV.x, 1.0 - UV.y) - 0.5) * taille + vec2(0.0, 0.02);  // mètres, y vers le haut
	float t = TIME + phase;
	float px = fwidth(p.x) * 1.2;

	// --- corps : tête en goutte + bas en deux petites pointes
	vec2 ph = p - vec2(0.0, 0.08);
	float tete = ellipse(ph, vec2(0.33, 0.34));
	float torse = ellipse(p - vec2(0.0, -0.3), vec2(0.2, 0.26));
	float corps = smin(tete, torse, 0.1);
	float pas = sin(t * 4.0) * 0.03;
	float jambe_g = trait(p, vec2(-0.09, -0.4), vec2(-0.12 + pas, -0.76), 0.075, 0.012);
	float jambe_d = trait(p, vec2(0.09, -0.4), vec2(0.12 - pas, -0.76), 0.075, 0.012);
	corps = smin(corps, min(jambe_g, jambe_d), 0.05);

	// --- volute : la tête s'étire en une flamme qui se recourbe
	float vent = sin(t * 1.8) * 0.03;
	vec2 c = vec2(0.07 + vent, 0.56);
	float r = 0.15 + sin(t * 2.3) * 0.01;
	float volute = arc_effile(p, c, r, 3.1416, 4.0, 0.1, 0.008);
	float tige = trait(p, vec2(-0.02, 0.3), vec2(c.x - r, c.y), 0.16, 0.1);
	corps = smin(corps, smin(tige, volute, 0.06), 0.08);

	// --- billes qui flottent au-dessus
	vec2 b1 = vec2(-0.2 + sin(t * 1.3) * 0.03, 0.78 + sin(t * 2.1) * 0.04);
	vec2 b2 = vec2(0.02 + sin(t * 1.7 + 1.0) * 0.03, 0.86 + sin(t * 2.6 + 2.0) * 0.035);
	float billes = min(length(p - b1) - 0.045, length(p - b2) - 0.032);

	// --- cape : col autour du cou, pan qui tombe sur les épaules, écharpe qui flotte
	float ondule = sin(p.x * 9.0 - t * 3.5) * 0.025;
	vec2 pc = p - vec2(0.0, -0.2);
	float col = ellipse(pc, vec2(0.3, 0.075));
	float largeur = mix(0.27, 0.37, clamp(-(pc.y) / 0.26, 0.0, 1.0));
	float ourlet = -0.27 + ondule - abs(sin(p.x * 11.0 + t * 2.0)) * 0.045;
	float pan = max(abs(pc.x) - largeur, max(pc.y - 0.02, ourlet - pc.y));
	// pan fendu devant pour laisser voir le torse
	float fente = abs(pc.x + sin(t * 2.0) * 0.02) - mix(0.0, 0.09, clamp(-pc.y / 0.26, 0.0, 1.0));
	pan = max(pan, -fente + 0.0);
	float manteau = smin(col, pan, 0.04);
	// écharpe : un pan qui flotte derrière, à droite, porté par le vent
	float echarpe = 1e3;
	for (int i = 0; i < 6; i++) {
		float u0 = float(i) / 6.0, u1 = float(i + 1) / 6.0;
		vec2 a = vec2(0.2 + u0 * 0.42, -0.19 - u0 * 0.1 + sin(u0 * 5.0 - t * 4.0) * 0.07 * u0);
		vec2 b = vec2(0.2 + u1 * 0.42, -0.19 - u1 * 0.1 + sin(u1 * 5.0 - t * 4.0) * 0.07 * u1);
		echarpe = min(echarpe, trait(p, a, b, mix(0.065, 0.012, u0), mix(0.065, 0.012, u1)));
	}
	manteau = min(manteau, echarpe);

	// --- yeux : grandes amandes claires, un peu inclinées (l'air un peu méchant)
	vec2 pe = vec2(abs(p.x) - 0.135, p.y - 0.07);
	float incl = 0.45;
	pe = mat2(vec2(cos(incl), sin(incl)), vec2(-sin(incl), cos(incl))) * pe;
	// clignement de temps en temps
	float cycle = fract(t / 4.3);
	float clin = 1.0 - 0.85 * smoothstep(0.0, 0.015, cycle) * (1.0 - smoothstep(0.03, 0.045, cycle));
	float oeil = ellipse(pe, vec2(0.08, 0.12 * clin));
	// paupière plate en haut, côté nez : l'amande
	oeil = max(oeil, (p.y - 0.07) - 0.065 + (0.2 - abs(p.x)) * 0.5);

	// --- couverture
	float a_corps = 1.0 - smoothstep(-px, px, corps);
	float a_billes = 1.0 - smoothstep(-px, px, billes);
	float a_cape = 1.0 - smoothstep(-px, px, manteau);
	float a_oeil = (1.0 - smoothstep(-px, px, oeil)) * a_corps;

	// corps : bord indigo, violet, cœur cyan qui palpite
	float dedans = clamp(-corps / 0.22, 0.0, 1.0);
	float pouls = 0.85 + 0.15 * sin(t * 3.0);
	vec3 cc = mix(bleu, violet, smoothstep(0.0, 0.45, dedans));
	cc = mix(cc, coeur, smoothstep(0.35, 1.0, dedans) * 0.75 * pouls);
	// visage plus sombre autour des yeux, pour qu'ils ressortent même de loin
	float masque = 1.0 - smoothstep(-0.07, 0.08, ellipse(p - vec2(0.0, 0.05), vec2(0.25, 0.13)));
	cc = mix(cc, bleu * 0.75, masque * 0.65);
	// lisière lumineuse sur le contour, comme une âme
	cc += coeur * 0.35 * (1.0 - smoothstep(0.0, 0.03, -corps)) * a_corps;
	// volute plus claire vers sa pointe
	cc = mix(cc, coeur, (1.0 - smoothstep(-0.02, 0.06, volute)) * smoothstep(0.45, 0.75, p.y) * 0.5);

	vec3 col_b = mix(coeur, vec3(1.0), 0.4);
	// cape : tissu bleu-gris pâle, plis ombrés
	float plis = 0.9 + 0.1 * sin(p.x * 26.0 + sin(p.y * 6.0 + t) * 2.0);
	vec3 col_cape = cape * plis * mix(0.75, 1.0, smoothstep(-0.48, -0.15, p.y));
	col_cape = mix(col_cape * 0.6, col_cape, smoothstep(0.0, 0.025, -manteau));  // liseré sombre

	vec3 couleur = cc;
	float alpha = a_corps;
	couleur = mix(couleur, col_cape, a_cape);
	alpha = max(alpha, a_cape);
	couleur = mix(couleur, yeux_c, a_oeil * (1.0 - a_cape));
	// léger éclat clair autour des yeux
	couleur += coeur * 0.25 * exp(-max(oeil, 0.0) / 0.025) * (1.0 - a_oeil) * a_corps * (1.0 - a_cape);
	couleur = mix(couleur, col_b, a_billes);
	alpha = max(alpha, a_billes);

	// halo violet doux autour de la silhouette
	float dmin = min(min(corps, manteau), billes);
	float halo = exp(-max(dmin, 0.0) / 0.06) * 0.4 * (1.0 - alpha);
	couleur = mix(couleur, mix(violet, coeur, 0.3), halo / max(alpha + halo, 0.001));
	alpha = alpha + halo;

	ALBEDO = couleur * 1.15;
	vec2 bord = min(UV, 1.0 - UV);
	ALPHA = clamp(alpha * opacite, 0.0, 1.0) * smoothstep(0.0, 0.06, min(bord.x, bord.y));
}
