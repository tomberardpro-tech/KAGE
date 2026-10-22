shader_type spatial;
// Esprit (scripts/esprits.gd) : petite âme épurée, façon icône, dessinée en SDF sur un quad
// toujours face à la caméra. Une goutte arrondie dont la pointe se recourbe en une seule
// petite volute, deux grands yeux blancs ovales, une bille qui flotte, un halo doux.
// Trois teintes : violet profond au bord, cœur plus clair, yeux blancs.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 coeur : source_color = vec3(0.78, 0.62, 1.0);
uniform vec3 violet : source_color = vec3(0.36, 0.1, 0.78);
uniform vec3 yeux_c : source_color = vec3(1.0, 1.0, 1.0);
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

// segment effilé de a (épaisseur wa) à b (épaisseur wb)
float trait(vec2 p, vec2 a, vec2 b, float wa, float wb) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - mix(wa, wb, h);
}

// trait qui s'amincit le long d'un arc de cercle (centre c, rayon r), de l'angle a0
// en tournant dans le sens horaire sur une ouverture « ouv »
float arc_effile(vec2 p, vec2 c, float r, float a0, float ouv, float w0, float w1) {
	vec2 q = p - c;
	float s = a0 - atan(q.y, q.x);
	s = s - 6.2831853 * floor(s / 6.2831853);
	float u = s / ouv;
	if (u > 1.0) {
		vec2 fin = c + r * vec2(cos(a0 - ouv), sin(a0 - ouv));
		vec2 dep = c + r * vec2(cos(a0), sin(a0));
		return min(length(p - fin) - w1, length(p - dep) - w0);
	}
	return abs(length(q) - r) - mix(w0, w1, u);
}

void fragment() {
	vec2 p = (vec2(UV.x, 1.0 - UV.y) - 0.5) * taille * 0.88;  // mètres (un peu agrandi), y vers le haut
	float t = TIME + phase;
	float px = fwidth(p.x) * 1.0;

	// --- goutte : un ventre rond qui s'effile vers le haut
	float souffle = sin(t * 2.2) * 0.012;
	float ventre = ellipse(p - vec2(0.0, -0.2), vec2(0.36 + souffle, 0.38 - souffle));
	// la pointe et la volute se balancent doucement
	float vent = sin(t * 1.6) * 0.035;
	vec2 c = vec2(0.08 + vent, 0.5);
	float r = 0.11;
	float pointe = trait(p, vec2(0.0, -0.08), vec2(c.x - r, c.y), 0.27, 0.08);
	float volute = arc_effile(p, c, r, 3.1416, 3.8, 0.08, 0.022);
	float corps = smin(ventre, pointe, 0.12);
	corps = smin(corps, volute, 0.03);

	// --- une seule bille qui flotte près de la volute
	vec2 b = vec2(-0.2 + sin(t * 1.3) * 0.025, 0.6 + sin(t * 2.0) * 0.04);
	float bille = length(p - b) - 0.045;

	// --- yeux : deux grands ovales blancs
	vec2 pe = vec2(abs(p.x) - 0.125, p.y + 0.15);
	float oeil = ellipse(pe, vec2(0.068, 0.095));

	// --- couverture
	float a_corps = 1.0 - smoothstep(-px, px, corps);
	float a_bille = 1.0 - smoothstep(-px, px, bille);
	float a_oeil = (1.0 - smoothstep(-px, px, oeil)) * a_corps;

	// corps : violet profond au bord, cœur plus clair qui palpite à peine
	float dedans = clamp(-corps / 0.26, 0.0, 1.0);
	float pouls = 0.92 + 0.08 * sin(t * 2.6);
	vec3 couleur = mix(violet, coeur, smoothstep(0.0, 0.85, dedans) * pouls);
	couleur = mix(couleur * 1.15, yeux_c * 1.6, a_oeil);
	couleur = mix(couleur, mix(coeur, yeux_c, 0.5) * 1.2, a_bille * (1.0 - a_corps));
	float alpha = max(a_corps, a_bille);

	// halo doux autour de la silhouette
	float dmin = min(corps, bille);
	float halo = exp(-max(dmin, 0.0) / 0.07) * 0.35 * (1.0 - alpha);
	couleur = mix(couleur, mix(violet, coeur, 0.4), halo / max(alpha + halo, 0.001));
	alpha += halo;

	ALBEDO = couleur;
	vec2 bord = min(UV, 1.0 - UV);
	ALPHA = clamp(alpha * opacite, 0.0, 1.0) * smoothstep(0.0, 0.06, min(bord.x, bord.y));
}
