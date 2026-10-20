shader_type spatial;
// Bannière nobori du clan du seigneur Oni : tissu pourpre qui ondule, un masque d'oni
// (cornes, yeux jaunes qui luisent, crocs) dans un cercle doré, et des flammes en bas.
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec4 rouge : source_color = vec4(0.36, 0.05, 0.05, 1.0);
uniform vec4 noir : source_color = vec4(0.05, 0.03, 0.03, 1.0);
uniform vec4 or_vieux : source_color = vec4(0.79, 0.62, 0.29, 1.0);
uniform vec4 visage : source_color = vec4(0.78, 0.18, 0.11, 1.0);
uniform vec4 os : source_color = vec4(0.92, 0.88, 0.78, 1.0);
uniform vec4 yeux : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform float rapport = 3.0;  // hauteur / largeur du tissu
uniform float phase = 0.0;

void vertex() {
	float vague = sin(TIME * 2.0 + phase - UV.x * 4.0 + UV.y * 2.0);
	VERTEX.z += vague * 0.07 * UV.x;
}

float segment(vec2 p, vec2 a, vec2 b, out float t) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * t);
}

float plein(float d) {
	return 1.0 - smoothstep(-0.006, 0.006, d);
}

void fragment() {
	// fond : pourpre en haut, presque noir en bas
	vec3 c = mix(rouge.rgb, noir.rgb, smoothstep(0.35, 1.0, UV.y));
	vec3 lueur = vec3(0.0);

	// flammes qui montent du bas du tissu
	float flamme_h = 0.16 + 0.07 * sin(UV.x * 21.0 + TIME * 3.0 + phase) + 0.05 * sin(UV.x * 47.0 - TIME * 4.3);
	float flamme = smoothstep(1.0 - flamme_h - 0.01, 1.0 - flamme_h + 0.01, UV.y);
	vec3 feu = mix(vec3(0.95, 0.42, 0.08), vec3(0.6, 0.06, 0.03), smoothstep(1.0 - flamme_h, 1.0, UV.y));
	c = mix(c, feu, flamme);
	lueur += feu * flamme * 0.5;

	vec2 p = (UV - vec2(0.5, 0.25)) * vec2(1.0, rapport);
	p.x = abs(p.x) * 1.0;  // le masque est symétrique
	vec2 q = (UV - vec2(0.5, 0.25)) * vec2(1.0, rapport);
	float r = length(q);
	// cercle doré et fond noir du blason
	float disque = plein(r - 0.4);
	c = mix(c, noir.rgb, disque);
	float anneau = plein(abs(r - 0.38) - 0.022);
	c = mix(c, or_vieux.rgb, anneau);

	// cornes
	float t;
	float d_corne = segment(p, vec2(0.11, -0.12), vec2(0.27, -0.34), t) - mix(0.05, 0.004, t);
	float corne = plein(d_corne);
	c = mix(c, os.rgb, corne);

	// visage rouge
	float d_tete = length((q - vec2(0.0, 0.03)) / vec2(0.2, 0.23)) - 1.0;
	float tete = plein(d_tete * 0.2);
	c = mix(c, visage.rgb, tete);

	// sourcils noirs en V, yeux jaunes en amande qui luisent
	float d_sourcil = segment(p, vec2(0.03, -0.07), vec2(0.15, -0.12), t) - 0.022;
	c = mix(c, noir.rgb, plein(d_sourcil) * tete);
	vec2 e = p - vec2(0.085, -0.02);
	e = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * e;
	float oeil = plein((length(e / vec2(0.06, 0.024)) - 1.0) * 0.024);
	c = mix(c, yeux.rgb, oeil);
	lueur += yeux.rgb * oeil * 1.6;

	// bouche noire et crocs blancs
	vec2 m = q - vec2(0.0, 0.13);
	float bouche = plein((length(m / vec2(0.13, 0.05)) - 1.0) * 0.05);
	c = mix(c, noir.rgb, bouche);
	float d_croc = segment(p, vec2(0.075, 0.09), vec2(0.075, 0.15), t) - mix(0.022, 0.002, t);
	float d_croc_bas = segment(p, vec2(0.04, 0.175), vec2(0.04, 0.12), t) - mix(0.016, 0.002, t);
	c = mix(c, os.rgb, max(plein(d_croc), plein(d_croc_bas)) * bouche);

	// liseré noir en haut
	c = mix(c, noir.rgb, step(UV.y, 0.03));
	ALBEDO = c;
	EMISSION = c * 0.05 + lueur;
	ROUGHNESS = 0.9;
}
