extends Node3D
## Esprits (yūrei) : petits fantômes lumineux qui apparaissent près du ninja, flottent un moment
## en ondulant puis s'effacent. Purement décoratifs : aucune collision, les gardes les ignorent.
## Ajoutés par niveau.gd.

const MAX := 3
const COULEUR := Color(0.62, 0.86, 1.0)

var cible: Node3D
var _attente := 2.0
var _shader: Shader


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 couleur : source_color;
uniform float opacite = 1.0;
void vertex() {
	// toujours face à la caméra
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float t = TIME * 2.5;
	// tête ronde, corps qui s'affine en traîne ondulante
	float ondule = sin(p.y * 7.0 + t) * 0.12 * clamp(-p.y, 0.0, 1.0);
	float largeur = mix(0.42, 0.04, clamp(-p.y * 0.9, 0.0, 1.0));
	float corps = smoothstep(largeur, largeur - 0.18, abs(p.x - ondule)) * step(p.y, 0.25) * smoothstep(-1.0, -0.6, p.y);
	float tete = smoothstep(0.45, 0.25, length(p - vec2(0.0, 0.3)));
	float forme = max(corps, tete);
	float halo = smoothstep(1.0, 0.0, length(p - vec2(0.0, 0.15))) * 0.35;
	// deux yeux sombres
	float yeux = smoothstep(0.075, 0.05, length(vec2(abs(p.x) - 0.14, p.y - 0.32)));
	float a = (forme * 0.8 + halo) * opacite;
	ALBEDO = couleur * (1.0 - yeux * 0.9) * (0.7 + forme * 0.6);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


func _process(delta: float) -> void:
	_attente -= delta
	if _attente <= 0.0 and cible and get_child_count() < MAX:
		_apparaitre()
		_attente = randf_range(3.0, 8.0)


func _apparaitre() -> void:
	var angle := randf() * TAU
	var depart := cible.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(4.0, 9.0)
	depart.y += randf_range(0.8, 1.8)
	var cap := Vector3(cos(angle + PI / 2.0), 0.0, sin(angle + PI / 2.0)) * (1.0 if randf() < 0.5 else -1.0)
	var esprit := Node3D.new()
	add_child(esprit)
	esprit.global_position = depart

	var corps := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.4)
	corps.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("couleur", COULEUR)
	m.set_shader_parameter("opacite", 0.0)
	corps.material_override = m
	corps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	esprit.add_child(corps)

	var lueur := OmniLight3D.new()
	lueur.light_color = COULEUR
	lueur.omni_range = 3.0
	lueur.light_energy = 0.0
	esprit.add_child(lueur)

	# traînée de petites étincelles
	var trainee := CPUParticles3D.new()
	trainee.amount = 24
	trainee.lifetime = 1.2
	trainee.local_coords = false
	trainee.gravity = Vector3(0, 0.15, 0)
	trainee.initial_velocity_max = 0.25
	trainee.spread = 180.0
	trainee.scale_amount_min = 0.5
	var point := QuadMesh.new()
	point.size = Vector2(0.1, 0.1)
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mp.vertex_color_use_as_albedo = true
	mp.albedo_color = COULEUR
	var rond := GradientTexture2D.new()
	rond.fill = GradientTexture2D.FILL_RADIAL
	rond.fill_from = Vector2(0.5, 0.5)
	rond.fill_to = Vector2(1.0, 0.5)
	rond.gradient = Gradient.new()
	rond.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	mp.albedo_texture = rond
	point.material = mp
	trainee.mesh = point
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	trainee.color_ramp = g
	trainee.position.y = -0.4
	esprit.add_child(trainee)

	# il passe : apparition, dérive en ondulant, puis disparition
	var duree := randf_range(5.0, 8.0)
	var arrivee := depart + cap * randf_range(4.0, 7.0) + Vector3(0, randf_range(-0.3, 0.6), 0)
	esprit.create_tween().tween_property(esprit, "global_position", arrivee, duree).set_trans(Tween.TRANS_SINE)
	var flotte := corps.create_tween().set_loops()
	flotte.tween_property(corps, "position:y", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
	flotte.tween_property(corps, "position:y", -0.12, 0.9).set_trans(Tween.TRANS_SINE)
	var visible_a := func(v: float) -> void:
		m.set_shader_parameter("opacite", v)
		lueur.light_energy = v * 0.8
		trainee.emitting = v > 0.2
	var fondu := esprit.create_tween()
	fondu.tween_method(visible_a, 0.0, 1.0, 1.2)
	fondu.tween_interval(duree - 2.7)
	fondu.tween_method(visible_a, 1.0, 0.0, 1.5)
	fondu.tween_callback(esprit.queue_free)
