shader_type spatial;
// Brins d'herbe haute : pied sombre, pointe plus claire, qui ondulent dans le vent.
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec4 pied : source_color = vec4(0.07, 0.13, 0.09, 1.0);
uniform vec4 pointe : source_color = vec4(0.30, 0.44, 0.26, 1.0);

varying float hauteur;

void vertex() {
	hauteur = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	vec3 monde = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float vent = sin(TIME * 1.6 + monde.x * 0.8 + monde.z * 0.6) + 0.5 * sin(TIME * 2.9 + monde.z * 1.7);
	VERTEX.x += vent * 0.08 * hauteur * hauteur;
}

void fragment() {
	ALBEDO = mix(pied.rgb, pointe.rgb, hauteur);
	ROUGHNESS = 0.8;
}
