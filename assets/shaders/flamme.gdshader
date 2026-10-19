shader_type spatial;
// Flamme de brasero, toujours tournée vers la caméra.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
#include "res://assets/shaders/bruit.gdshaderinc"

uniform vec4 couleur : source_color = vec4(1.0, 0.55, 0.18, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	float n = bruit(vec2(uv.x * 5.0, uv.y * 4.0 + TIME * 4.0));
	float x = (uv.x - 0.5) * 2.0;
	float forme = 1.0 - smoothstep(0.0, 1.0, abs(x) / mix(0.15, 0.9, uv.y) + (n - 0.5) * 0.5);
	forme *= smoothstep(0.0, 0.5, uv.y) * smoothstep(1.0, 0.85, uv.y);
	vec3 c = mix(couleur.rgb, vec3(1.0, 0.92, 0.6), forme * uv.y);
	ALBEDO = c * forme * 1.6;
	ALPHA = forme;
}
