extends Node3D
## Esprits bleus (hitodama, kitsune-bi ou yūrei) : lueurs qui apparaissent près du ninja, flottent un moment
## en ondulant puis s'effacent. Purement décoratifs : aucune collision, les gardes les ignorent.
## Ajoutés par niveau.gd.

const MAX := 3
const COEUR := Color(0.85, 0.97, 1.0)  ## centre presque blanc
const BLEU := Color(0.16, 0.42, 1.0)  ## bord bleu profond
const LUEUR := Color(0.3, 0.55, 1.0)

## 0 : hitodama (flamme d'âme), 1 : kitsune-bi (procession de petites flammes), 2 : yūrei (fantôme bleu)
@export var style := 0

var cible: Node3D
var _attente := 2.0
var _shader: Shader


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 coeur : source_color;
uniform vec3 bleu : source_color;
uniform float opacite = 1.0;
uniform int forme = 0;  // 0 flamme, 1 fantôme
uniform float phase = 0.0;
void vertex() {
	// toujours face à la caméra
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
float flamme(vec2 p, float t) {
	// goutte : rond en bas, pointe qui danse en haut
	p.x += sin(p.y * 5.0 - t * 3.0) * 0.07 * (p.y + 0.5);
	float h = clamp((p.y + 0.3) / 1.15, 0.0, 1.0);
	float l = 0.36 * pow(1.0 - h, 1.4) * (0.88 + 0.12 * sin(t * 6.0 + p.y * 11.0));
	float bas = length(p - vec2(0.0, -0.3));
	float d = p.y < -0.3 ? bas / 0.36 : abs(p.x) / max(l, 0.001);
	return 1.0 - d;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float t = TIME + phase;
	float f;
	float yeux = 0.0;
	if (forme == 0) {
		f = flamme(p * vec2(1.0, 1.0) + vec2(0.0, 0.1), t);
	} else {
		float ondule = sin(p.y * 6.0 + t * 3.0) * 0.14 * clamp(-p.y, 0.0, 1.0);
		float largeur = mix(0.42, 0.02, clamp(-p.y * 0.95, 0.0, 1.0)) * (0.9 + 0.1 * sin(t * 5.0 + p.y * 9.0));
		float corps = (1.0 - abs(p.x - ondule) / max(largeur, 0.001)) * step(p.y, 0.3) * smoothstep(-1.0, -0.5, p.y);
		float tete = 1.0 - length(p - vec2(0.0, 0.3)) / 0.42;
		f = max(corps, tete);
		yeux = smoothstep(0.11, 0.07, length((vec2(abs(p.x) - 0.15, p.y - 0.3)) * vec2(1.0, 0.75)));
	}
	float forme_a = smoothstep(0.0, 0.25, f);
	float centre = smoothstep(0.35, 0.95, f) * (1.0 - yeux);
	float halo = pow(max(0.0, 1.0 - length(p * vec2(1.0, 0.8))), 2.0) * 0.45;
	vec3 c = mix(bleu, coeur, centre) * (1.0 - yeux * 0.85);
	ALBEDO = c * forme_a + bleu * halo;
	ALPHA = clamp((forme_a + halo) * opacite, 0.0, 1.0);
}
"""


func _process(delta: float) -> void:
	# quand le ninja approche, l'esprit file et s'évanouit
	if cible:
		for esprit: Node3D in get_children():
			if not esprit.get_meta("fuit", false):
				var ecart := esprit.global_position - cible.global_position
				ecart.y = 0.0
				if ecart.length() < 3.5:
					_fuir(esprit, ecart.normalized())
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

	var flammes: Array[ShaderMaterial] = []
	var corps := Node3D.new()
	esprit.add_child(corps)
	var nombre := 3 if style == 1 else 1
	for i in nombre:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 1.4) if style == 2 else (Vector2(0.55, 0.75) if style == 1 else Vector2(0.9, 1.2))
		q.mesh = quad
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("coeur", COEUR)
		m.set_shader_parameter("bleu", BLEU)
		m.set_shader_parameter("forme", 1 if style == 2 else 0)
		m.set_shader_parameter("phase", i * 1.7)
		m.set_shader_parameter("opacite", 0.0)
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# la procession suit la même route, chaque flamme un peu derrière et décalée
		q.position = -cap * i * 0.7 + Vector3(0, sin(i * 2.1) * 0.15, 0)
		corps.add_child(q)
		flammes.append(m)
		if nombre > 1:
			var danse := q.create_tween().set_loops()
			danse.tween_property(q, "position:y", q.position.y + 0.18, 0.7 + i * 0.15).set_trans(Tween.TRANS_SINE)
			danse.tween_property(q, "position:y", q.position.y - 0.12, 0.7 + i * 0.15).set_trans(Tween.TRANS_SINE)

	var lueur := OmniLight3D.new()
	lueur.light_color = LUEUR
	lueur.omni_range = 5.5
	lueur.light_energy = 0.0
	esprit.add_child(lueur)

	# braises bleues qui montent et s'éteignent
	var trainee := CPUParticles3D.new()
	trainee.amount = 30
	trainee.lifetime = 1.4
	trainee.local_coords = false
	trainee.gravity = Vector3(0, 0.6, 0)
	trainee.initial_velocity_max = 0.2
	trainee.spread = 180.0
	trainee.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trainee.emission_sphere_radius = 0.2
	trainee.scale_amount_min = 0.4
	var point := QuadMesh.new()
	point.size = Vector2(0.09, 0.09)
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mp.vertex_color_use_as_albedo = true
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
	g.colors = PackedColorArray([Color(COEUR, 0.9), Color(BLEU, 0.0)])
	trainee.color_ramp = g
	trainee.position.y = 0.1 if style == 2 else -0.15
	esprit.add_child(trainee)

	# il passe : apparition, dérive en ondulant, puis disparition
	var duree := randf_range(5.0, 8.0)
	var arrivee := depart + cap * randf_range(4.0, 7.0) + Vector3(0, randf_range(-0.3, 0.6), 0)
	var trajet := esprit.create_tween()
	trajet.tween_property(esprit, "global_position", arrivee, duree).set_trans(Tween.TRANS_SINE)
	esprit.set_meta("trajet", trajet)
	var flotte := corps.create_tween().set_loops()
	flotte.tween_property(corps, "position:y", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
	flotte.tween_property(corps, "position:y", -0.12, 0.9).set_trans(Tween.TRANS_SINE)
	var visible_a := func(v: float) -> void:
		for m in flammes:
			m.set_shader_parameter("opacite", v)
		lueur.light_energy = v * 2.2
		trainee.emitting = v > 0.2
	esprit.set_meta("visible_a", visible_a)
	var fondu := esprit.create_tween()
	fondu.tween_method(visible_a, 0.0, 1.0, 1.2)
	fondu.tween_interval(duree - 2.7)
	fondu.tween_method(visible_a, 1.0, 0.0, 1.5)
	fondu.tween_callback(esprit.queue_free)
	esprit.set_meta("fondu", fondu)


## L'esprit s'enfuit loin du ninja en montant, puis disparaît.
func _fuir(esprit: Node3D, direction: Vector3) -> void:
	esprit.set_meta("fuit", true)
	for nom in ["trajet", "fondu"]:
		var tw: Tween = esprit.get_meta(nom)
		if tw and tw.is_valid():
			tw.kill()
	var visible_a: Callable = esprit.get_meta("visible_a")
	var depart := 1.0
	var mat: ShaderMaterial = esprit.get_child(0).get_child(0).material_override
	if mat:
		depart = mat.get_shader_parameter("opacite")
	var fuite := esprit.create_tween().set_parallel(true)
	fuite.tween_property(esprit, "global_position", esprit.global_position + direction * 5.0 + Vector3(0, 1.5, 0), 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fuite.tween_method(visible_a, depart, 0.0, 0.9)
	fuite.chain().tween_callback(esprit.queue_free)
