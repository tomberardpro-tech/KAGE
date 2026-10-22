shader_type spatial;
// Bannière nobori de l'époque des samouraïs : tissu écru qui ondule, bandes noires en haut et
// en bas, et le mon du clan, un mitsudomoe (trois virgules qui tournent) dans un anneau noir.
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec4 tissu : source_color = vec4(0.88, 0.84, 0.74, 1.0);
uniform vec4 encre : source_color = vec4(0.07, 0.06, 0.06, 1.0);
uniform vec4 rouge : source_color = vec4(0.62, 0.12, 0.09, 1.0);
uniform float rapport = 3.0;  // hauteur / largeur du tissu
uniform float phase = 0.0;

void vertex() {
	float vague = sin(TIME * 2.0 + phase - UV.x * 4.0 + UV.y * 2.0);
	VERTEX.z += vague * 0.07 * UV.x;
}

float plein(float d, float flou) {
	return 1.0 - smoothstep(-flou, flou, d);
}

// Une virgule (tomoe) : une tête ronde et une queue qui s'enroule vers l'extérieur.
float tomoe(vec2 p, float depart) {
	float r = length(p);
	float a = atan(p.y, p.x);
	vec2 tete = vec2(cos(depart), sin(depart)) * 0.15;
	float d = length(p - tete) - 0.08;
	float da = mod(a - depart + 6.2832, 6.2832);
	float t = da / 1.9;
	if (t < 1.0) {
		float rc = 0.15 + 0.1 * t;
		float demi = 0.08 * pow(1.0 - t, 1.3);
		d = min(d, abs(r - rc) - demi);
	}
	return d;
}

void fragment() {
	vec3 c = tissu.rgb * (0.94 + 0.06 * sin(UV.y * 90.0));  // léger grain du tissu
	// bandes noires en haut et en bas, fin liseré rouge dessous
	c = mix(c, encre.rgb, step(UV.y, 0.05) + step(0.95, UV.y));
	c = mix(c, rouge.rgb, step(0.05, UV.y) * step(UV.y, 0.065));
	c = mix(c, rouge.rgb, step(0.935, UV.y) * step(UV.y, 0.95));

	vec2 p = (UV - vec2(0.5, 0.3)) * vec2(1.0, rapport);
	float flou = 0.006;
	float r = length(p);
	float anneau = plein(abs(r - 0.36) - 0.03, flou);
	float d = 1.0;
	for (int k = 0; k < 3; k++) {
		d = min(d, tomoe(p, float(k) * 2.0944 + 1.5708));
	}
	float mon = max(anneau, plein(d, flou) * step(r, 0.33));
	c = mix(c, encre.rgb, mon);
	ALBEDO = c;
	EMISSION = c * 0.05;
	ROUGHNESS = 0.9;
}
