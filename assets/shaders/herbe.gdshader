shader_type spatial;
// Brins d'herbe haute : pied sombre, pointe plus claire et un peu dorée, couleur qui varie d'un
// brin à l'autre, ondulation dans le vent, et les brins s'écartent quand le ninja passe dedans.
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec4 pied : source_color = vec4(0.08, 0.17, 0.09, 1.0);
uniform vec4 pointe : source_color = vec4(0.42, 0.6, 0.28, 1.0);
uniform vec4 pointe_seche : source_color = vec4(0.62, 0.62, 0.32, 1.0);
uniform vec3 joueur = vec3(0.0, -100.0, 0.0);

varying float hauteur;
varying float teinte;

float hachage(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	hauteur = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	vec3 monde = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	teinte = hachage(floor(monde.xz * 7.0));
	float vent = sin(TIME * 1.6 + monde.x * 0.8 + monde.z * 0.6) + 0.5 * sin(TIME * 2.9 + monde.z * 1.7);
	vec3 pousse = vec3(vent * 0.08, 0.0, vent * 0.03);
	// le ninja écarte les brins autour de lui
	vec2 ecart = monde.xz - joueur.xz;
	float d = length(ecart);
	float force = smoothstep(1.1, 0.2, d) * step(abs(monde.y - joueur.y), 1.5);
	pousse.xz += normalize(ecart + vec2(0.001)) * force * 0.55;
	pousse.y -= force * 0.25;
	vec3 local = inverse(mat3(MODEL_MATRIX)) * pousse;
	VERTEX += local * hauteur * hauteur;
}

void fragment() {
	vec3 bout = mix(pointe.rgb, pointe_seche.rgb, teinte * teinte * 0.7);
	ALBEDO = mix(pied.rgb, bout, pow(hauteur, 0.8)) * (0.85 + 0.3 * teinte);
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.12, 0.18, 0.06) * hauteur;
}
