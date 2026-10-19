shader_type spatial;
// Bannière nobori : tissu rouge qui ondule, avec le mon blanc du clan (fleur dans un cercle).
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec4 rouge : source_color = vec4(0.55, 0.11, 0.08, 1.0);
uniform vec4 blanc : source_color = vec4(0.90, 0.86, 0.78, 1.0);
uniform float rapport = 3.0;  // hauteur / largeur du tissu
uniform float phase = 0.0;

void vertex() {
	float vague = sin(TIME * 2.0 + phase - UV.x * 4.0 + UV.y * 2.0);
	VERTEX.z += vague * 0.07 * UV.x;
}

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.25)) * vec2(1.0, rapport);
	float r = length(p);
	float a = atan(p.y, p.x);
	float anneau = smoothstep(0.30, 0.31, r) * smoothstep(0.36, 0.35, r);
	float petale = 0.23 * (0.62 + 0.38 * abs(cos(2.5 * a + 0.785)));
	float fleur = smoothstep(petale + 0.01, petale, r) * smoothstep(0.035, 0.045, r);
	float bande = step(0.94, UV.y) + step(UV.y, 0.03);
	float mon = clamp(anneau + fleur, 0.0, 1.0);
	vec3 c = mix(rouge.rgb, blanc.rgb, mon);
	c = mix(c, vec3(0.08), bande);
	ALBEDO = c;
	EMISSION = c * 0.06;
	ROUGHNESS = 0.9;
}
