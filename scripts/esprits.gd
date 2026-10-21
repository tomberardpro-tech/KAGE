extends Node3D
## Esprits bleus (hitodama, kitsune-bi ou yūrei) : petits fantômes qui apparaissent près du ninja, flottent un
## moment en ondulant puis s'effacent. Leur silhouette (tête en goutte qui finit en volute, billes flottantes,
## yeux clairs en amande, petite cape qui ondule) est dessinée par assets/shaders/esprit.gdshader. Purement décoratifs : aucune collision, les gardes les ignorent.
## Quand le ninja s'approche, l'esprit fuit devant lui : on peut lui courir après, presque l'attraper,
## puis il s'évanouit en petites étincelles. Ajoutés par niveau.gd.

const MAX := 1  ## un seul à la fois : un passage rare, pas un essaim qui distrait
const COEUR := Color(0.4, 0.85, 1.0)  ## centre cyan
const VIOLET := Color(0.48, 0.12, 0.95)  ## entre-deux violet vif
const BLEU := Color(0.2, 0.05, 0.55)  ## bord indigo profond
const LUEUR := Color(0.45, 0.3, 1.0)
const CAPE := Color(0.56, 0.6, 0.86)  ## petite cape bleu-gris, contraste avec le corps
const DESSIN := Vector2(1.4, 2.0)  ## cadre du dessin dans le shader (en mètres à l'échelle 1)
const DISTANCE_FUITE := 4.0  ## le ninja approche : l'esprit s'enfuit
const VITESSE_FUITE := 7.6  ## un peu moins que le sprint (8,5) : on peut presque l'attraper
const DISTANCE_TOUCHE := 0.8

## 0 : hitodama (un petit fantôme), 1 : kitsune-bi (procession de trois tout petits), 2 : yūrei (un plus grand)
@export var style := 0

var cible: Node3D
var _attente := 2.0
var _shader: Shader


func _ready() -> void:
	_shader = preload("res://assets/shaders/esprit.gdshader")


func _process(delta: float) -> void:
	# quand le ninja approche, l'esprit fuit devant lui
	if cible:
		for esprit: Node3D in get_children():
			if esprit.get_meta("fini", false):
				continue
			var ecart := esprit.global_position - cible.global_position
			ecart.y = 0.0
			if esprit.get_meta("fuit", false):
				_poursuite(esprit, ecart, delta)
			elif ecart.length() < DISTANCE_FUITE:
				_fuir(esprit)
	_attente -= delta
	if _attente <= 0.0 and cible and get_child_count() < MAX:
		_apparaitre()
		_attente = randf_range(10.0, 18.0)


func _apparaitre() -> void:
	var angle := randf() * TAU
	var depart := cible.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(6.0, 10.0)
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
		# ~1,5× la taille des anciennes flammes : le petit fantôme fait ~1,45 m de la pointe aux billes
		quad.size = DESSIN * (0.95 if style == 2 else (0.5 if style == 1 else 0.85))
		q.mesh = quad
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("coeur", COEUR)
		m.set_shader_parameter("bleu", BLEU)
		m.set_shader_parameter("violet", VIOLET)
		m.set_shader_parameter("cape", CAPE)
		m.set_shader_parameter("taille", DESSIN)
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
	trainee.emission_sphere_radius = 0.3
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
	esprit.set_meta("point", point)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(COEUR, 0.8), Color(VIOLET, 0.0)])
	trainee.color_ramp = g
	trainee.position.y = 0.25  # les braises montent de la tête et de la volute
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
		lueur.light_energy = v * 1.4
		trainee.emitting = v > 0.2
	esprit.set_meta("visible_a", visible_a)
	esprit.set_meta("opacite", flammes[0])
	var fondu := esprit.create_tween()
	fondu.tween_method(visible_a, 0.0, 1.0, 1.2)
	fondu.tween_interval(duree - 2.7)
	fondu.tween_method(visible_a, 1.0, 0.0, 1.5)
	fondu.tween_callback(esprit.queue_free)
	esprit.set_meta("fondu", fondu)


## Le ninja l'a vu : l'esprit cesse de dériver et se met à fuir.
func _fuir(esprit: Node3D) -> void:
	esprit.set_meta("fuit", true)
	esprit.set_meta("reste", randf_range(6.0, 10.0))
	esprit.set_meta("vitesse", Vector3.ZERO)
	for nom in ["trajet", "fondu"]:
		var tw: Tween = esprit.get_meta(nom)
		if tw and tw.is_valid():
			tw.kill()
	# il se ravive s'il était en train de s'effacer
	var mat: ShaderMaterial = esprit.get_meta("opacite")
	var t := esprit.create_tween()
	t.tween_method(esprit.get_meta("visible_a"), mat.get_shader_parameter("opacite"), 1.0, 0.3)
	esprit.set_meta("ravive", t)


## Il file devant le ninja en flottant, d'autant plus vite qu'il est proche ; au bout d'un moment,
## ou si le ninja le touche, il s'évanouit.
func _poursuite(esprit: Node3D, ecart: Vector3, delta: float) -> void:
	var reste: float = esprit.get_meta("reste") - delta
	esprit.set_meta("reste", reste)
	var d := ecart.length()
	if reste <= 0.0 or d < DISTANCE_TOUCHE:
		_evanouir(esprit)
		return
	var fuite := ecart.normalized() if d > 0.01 else Vector3.FORWARD
	# il louvoie un peu, comme une flamme portée par le vent
	fuite = fuite.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.0017 + esprit.get_instance_id()) * 0.6)
	var vite := lerpf(VITESSE_FUITE, 1.5, clampf((d - 1.5) / 7.0, 0.0, 1.0))
	var v: Vector3 = esprit.get_meta("vitesse")
	v = v.lerp(fuite * vite, 1.0 - exp(-3.0 * delta))
	esprit.set_meta("vitesse", v)
	esprit.global_position += v * delta
	var hauteur := cible.global_position.y + 1.3 + sin(Time.get_ticks_msec() * 0.003) * 0.3
	esprit.global_position.y = lerpf(esprit.global_position.y, hauteur, 1.0 - exp(-2.0 * delta))


## Fondu rapide et petite gerbe d'étincelles, puis il disparaît.
func _evanouir(esprit: Node3D) -> void:
	esprit.set_meta("fini", true)
	var ravive: Tween = esprit.get_meta("ravive")
	if ravive and ravive.is_valid():
		ravive.kill()
	var gerbe := CPUParticles3D.new()
	gerbe.one_shot = true
	gerbe.explosiveness = 0.9
	gerbe.amount = 26
	gerbe.lifetime = 0.9
	gerbe.gravity = Vector3(0, 0.8, 0)
	gerbe.direction = Vector3.UP
	gerbe.spread = 180.0
	gerbe.initial_velocity_min = 0.8
	gerbe.initial_velocity_max = 2.2
	gerbe.damping_min = 2.0
	gerbe.damping_max = 3.0
	gerbe.scale_amount_min = 0.5
	gerbe.mesh = esprit.get_meta("point")
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(COEUR, 1.0), Color(VIOLET, 0.0)])
	gerbe.color_ramp = g
	esprit.add_child(gerbe)
	gerbe.emitting = true
	var t := esprit.create_tween().set_parallel(true)
	t.tween_method(esprit.get_meta("visible_a"), 1.0, 0.0, 0.5)
	t.tween_property(esprit, "global_position:y", esprit.global_position.y + 0.6, 0.5)
	t.chain().tween_interval(0.9)
	t.chain().tween_callback(esprit.queue_free)
