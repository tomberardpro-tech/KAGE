shader_type spatial;
// Buisson en touffes de feuilles : des cartes de feuilles (assets/textures/feuilles.png, en gris)
// posées tout autour d'une boule, teintées du sombre (dedans, en bas) au clair (dessus).
// `opacite` < 1 : le buisson devient ajouré (le ninja caché dedans reste visible).
render_mode diffuse_lambert_wrap, cull_disabled;

uniform sampler2D feuilles : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 couleur_claire : source_color = vec4(0.42, 0.62, 0.28, 1.0);
uniform vec4 couleur_sombre : source_color = vec4(0.05, 0.14, 0.07, 1.0);
uniform float vent = 0.035;
uniform float opacite = 1.0;

varying float hauteur;
varying float bord;

void vertex() {
	vec3 pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float b = sin(TIME * 1.5 + pm.x * 0.8 + pm.z * 0.6) + 0.4 * sin(TIME * 3.7 + pm.x * 2.1);
	VERTEX.xz += vec2(b, b * 0.6) * vent * clamp(VERTEX.y + 0.2, 0.0, 1.4);
	hauteur = VERTEX.y;
	bord = length(VERTEX);
}

void fragment() {
	vec4 t = texture(feuilles, UV);
	if (t.a < 0.5) {
		discard;
	}
	if (opacite < 1.0) {
		float trame = fract(sin(dot(floor(FRAGCOORD.xy / 2.0), vec2(12.9898, 78.233))) * 43758.5453);
		if (trame > opacite) {
			discard;
		}
	}
	float h = clamp(hauteur * 0.6 + 0.35, 0.0, 1.0);
	float exterieur = clamp(bord * 1.1 - 0.15, 0.0, 1.0);
	float l = t.r * (0.45 + 0.4 * h + 0.25 * exterieur);
	ALBEDO = mix(couleur_sombre.rgb, couleur_claire.rgb, clamp(l, 0.0, 1.0));
	ROUGHNESS = 0.8;
}
