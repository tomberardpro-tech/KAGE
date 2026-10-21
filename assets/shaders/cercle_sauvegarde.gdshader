shader_type spatial;
// Cercle de sauvegarde au sol autour d'un autel : anneaux lumineux et petits traits qui tournent.
// Bleu pâle tant que l'autel n'est pas activé, doré une fois qu'il est le point de reprise.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float actif = 0.0;
uniform vec4 couleur_repos : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform vec4 couleur_actif : source_color = vec4(1.0, 0.72, 0.3, 1.0);

float anneau(float r, float centre, float epaisseur) {
	return smoothstep(epaisseur, 0.0, abs(r - centre));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float tour = TIME * (0.25 + actif * 0.35);
	float traits = step(0.6, fract((a + tour) / 6.2832 * 12.0)) * anneau(r, 0.8, 0.07);
	float interieur = step(0.7, fract((a - tour * 1.5) / 6.2832 * 8.0)) * anneau(r, 0.55, 0.03);
	float lignes = anneau(r, 0.93, 0.025) + anneau(r, 0.68, 0.02) + traits * 0.8 + interieur * 0.7;
	float lueur = smoothstep(1.0, 0.0, r) * 0.12;
	float pulse = 0.75 + 0.25 * sin(TIME * 2.2);
	vec3 c = mix(couleur_repos.rgb, couleur_actif.rgb, actif);
	ALBEDO = c * (lignes + lueur) * pulse * (0.7 + actif * 0.6);
	ALPHA = clamp(lignes + lueur, 0.0, 1.0) * step(r, 1.0);
}
