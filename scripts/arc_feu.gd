class_name ArcFeu
extends MeshInstance3D
## Arc de feu du coup de katana : un croissant de flammes qui balaie l'avant du ninja en suivant
## la lame (de sa droite vers sa gauche, en descendant), avec un cœur jaune clair, des bords
## orange-rouge qui s'effilent et flambent, quelques braises qui s'envolent et une lueur très brève.
## Même principe que la traînée du salto (Trainee) : un ruban additif dessiné à la main,
## mais calculé à partir du temps du coup, pour rester fluide même à faible cadence.

@export var duree_balayage := 0.17  ## temps que met la tête de l'arc à traverser l'avant du ninja
@export var duree_vie := 0.24  ## temps qu'un morceau d'arc met à s'éteindre
@export var debut := 0.07  ## délai entre le début du coup et le départ de l'arc
@export var angle_depart := 75.0  ## en degrés autour du ninja, 0 = droit devant, + = à sa droite
@export var angle_arrivee := -95.0
@export var rayon_interieur := 0.62
@export var rayon_exterieur := 1.45
@export var hauteur_depart := 1.05
@export var hauteur_arrivee := 0.45
@export var intensite := 0.95
## Grossit tout l'arc (rayons, hauteur, braises, lueur) : 1 pour le katana, plus pour la Grande Lame.
var ampleur := 1.0
var lenteur := 1.0  ## > 1 : coup plus lent (la Grande Lame), l'arc suit le même rythme

const ROUGE := Color(0.95, 0.12, 0.03)
const ORANGE := Color(1.0, 0.42, 0.06)
const JAUNE := Color(1.0, 0.86, 0.45)
const SEGMENTS := 36

var porteur: Node3D  ## nœud dont on suit la position et l'orientation (Visuel du ninja)

var _temps := -1.0  ## temps écoulé depuis le début du coup (< 0 : rien à dessiner)
var _braises: Array[Dictionary] = []
var _a_emettre := 0.0
var _lueur: OmniLight3D
var _maillage := ImmediateMesh.new()
var _graine := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _maillage
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	matiere.vertex_color_use_as_albedo = true
	matiere.disable_receive_shadows = true
	matiere.disable_fog = true
	matiere.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = matiere
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(1.0, 0.5, 0.18)
	_lueur.shadow_enabled = false
	_lueur.light_energy = 0.0
	_lueur.omni_range = 3.5
	_lueur.visible = false
	_lueur.top_level = true
	add_child(_lueur)


## Lance un nouvel arc (appelé au début de chaque coup).
func lancer(ampleur_ := 1.0, lenteur_ := 1.0) -> void:
	ampleur = ampleur_
	lenteur = lenteur_
	_temps = 0.0
	_a_emettre = 0.0
	_graine = randf() * 100.0


## Éteint tout d'un coup (réapparition, cinématique).
func effacer() -> void:
	_temps = -1.0
	_braises.clear()
	_maillage.clear_surfaces()
	_lueur.visible = false


func _process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	_maillage.clear_surfaces()
	var fin := (debut + duree_balayage) * lenteur + _vie()
	if _temps >= 0.0:
		_temps += delta
		if _temps > fin:
			_temps = -1.0
	var camera := get_viewport().get_camera_3d()
	if camera == null or porteur == null or not is_instance_valid(porteur):
		_lueur.visible = false
		return
	if _temps >= 0.0:
		_dessiner_arc(camera)
		_emettre_braises(delta)
	else:
		_lueur.visible = false
	_dessiner_braises(delta, camera)


## Les flammes d'un coup lent restent un peu plus longtemps.
func _vie() -> float:
	return duree_vie * sqrt(lenteur)


## Avancée de la tête de l'arc (0..1), rapide puis freinée, au temps t du coup.
func _tete(t: float) -> float:
	var u := clampf((t - debut * lenteur) / (duree_balayage * lenteur), 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 2.2)


## Moment où la tête passe au point s (0..1) de l'arc : l'inverse de _tete.
func _passage(s: float) -> float:
	return (debut + (1.0 - pow(1.0 - s, 1.0 / 2.2)) * duree_balayage) * lenteur


## Point de l'arc à l'abscisse s (0..1) et à la fraction r (0 = intérieur, 1 = extérieur).
func _point(s: float, r: float) -> Vector3:
	var angle := deg_to_rad(lerpf(angle_depart, angle_arrivee, s))
	var rayon := lerpf(rayon_interieur, rayon_exterieur, r) * ampleur
	var local := Vector3(sin(angle) * rayon, lerpf(hauteur_depart, hauteur_arrivee, s) * lerpf(1.0, ampleur, 0.5), cos(angle) * rayon)
	# l'arc penche un peu : le bord extérieur descend plus que l'intérieur
	local.y -= r * 0.18 * s
	return porteur.global_position + porteur.global_transform.basis.orthonormalized() * local


func _dessiner_arc(camera: Camera3D) -> void:
	var tete := _tete(_temps)
	if tete <= 0.001:
		_lueur.visible = false
		return
	var vue := camera.global_position
	# cinq rangées du dedans vers le dehors : bord rouge, orange, cœur jaune, orange, bord rouge
	var rangs := [0.0, 0.4, 0.66, 0.8, 1.0]
	var couleurs := [ROUGE * 0.1, ROUGE.lerp(ORANGE, 0.4) * 0.7, JAUNE * 0.7, ORANGE * 0.65, ROUGE * 0.3]
	var n := maxi(int(SEGMENTS * tete), 2)
	var colonnes: Array = []
	for i in n + 1:
		var s := tete * float(i) / n
		var age := _temps - _passage(s)
		var vie := 1.0 - clampf(age / _vie(), 0.0, 1.0)
		# la queue s'effile (vers 0) et la tête est pointue
		var effile := smoothstep(0.0, 0.18, s) * smoothstep(0.0, 0.06, tete - s + 0.01)
		var epais := vie * (0.35 + 0.65 * effile)
		# les flammes : le bord extérieur ondule et lèche vers l'extérieur
		var flamme := 0.5 + 0.5 * sin(s * 31.0 + _temps * 40.0 + _graine) * sin(s * 13.0 - _temps * 25.0)
		var milieu := 0.68
		var colonne: Array = []
		for k in rangs.size():
			var r: float = rangs[k]
			var rr := milieu + (r - milieu) * epais
			if k == rangs.size() - 1:
				rr += flamme * 0.12 * epais
			var c: Color = couleurs[k] * (intensite * vie * (0.55 + 0.45 * effile))
			c.a = 1.0
			colonne.append([_point(s, rr), c])
		colonnes.append(colonne)
	_maillage.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in colonnes.size() - 1:
		var a: Array = colonnes[i]
		var b: Array = colonnes[i + 1]
		for k in rangs.size() - 1:
			for v in [a[k], b[k], b[k + 1], a[k], b[k + 1], a[k + 1]]:
				_maillage.surface_set_color(v[1])
				_maillage.surface_add_vertex(v[0])
	# éclat blanc-jaune sur la tête de l'arc, là où passe la lame
	var tete_p := _point(tete, 0.8)
	_quad(tete_p, vue, 0.08 * sqrt(ampleur), JAUNE * (0.8 * (1.0 - clampf((_temps - _passage(tete)) / _vie(), 0.0, 1.0))))
	_maillage.surface_end()
	# lueur courte : forte au passage de la lame, éteinte juste après
	var balayage := _temps - debut * lenteur
	var demi := duree_balayage * lenteur * 0.5
	var force := clampf(1.0 - absf(balayage - demi) / (demi + 0.08), 0.0, 1.0)
	_lueur.visible = force > 0.01
	_lueur.global_position = tete_p + Vector3.UP * 0.2
	_lueur.light_energy = 1.3 * force * sqrt(ampleur)
	_lueur.omni_range = 2.8 * ampleur


## Braises lâchées par la tête de l'arc pendant son passage.
func _emettre_braises(delta: float) -> void:
	var tete := _tete(_temps)
	if tete <= 0.0 or tete >= 0.999:
		return
	_a_emettre += delta * 70.0 * ampleur
	while _a_emettre >= 1.0:
		_a_emettre -= 1.0
		var s := clampf(tete - randf() * 0.12, 0.0, 1.0)
		var p := _point(s, randf_range(0.5, 1.05))
		var dehors := (p - porteur.global_position)
		dehors.y = 0.0
		dehors = dehors.normalized()
		_braises.append({
			"p": p,
			"v": dehors * randf_range(0.6, 2.2) + Vector3.UP * randf_range(1.2, 3.0),
			"age": 0.0,
			"vie": randf_range(0.35, 0.75),
			"taille": randf_range(0.022, 0.05) * sqrt(ampleur),
		})


func _dessiner_braises(delta: float, camera: Camera3D) -> void:
	var i := 0
	while i < _braises.size():
		var b: Dictionary = _braises[i]
		b.age += delta
		if b.age > b.vie:
			_braises.remove_at(i)
			continue
		b.v *= exp(-2.5 * delta)
		b.v.y += 1.2 * delta  # l'air chaud les fait monter
		b.p += b.v * delta
		i += 1
	if _braises.is_empty():
		return
	var vue := camera.global_position
	_maillage.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in _braises:
		var x: float = b.age / b.vie
		var c := JAUNE.lerp(ORANGE, smoothstep(0.0, 0.3, x)).lerp(ROUGE, smoothstep(0.3, 0.9, x))
		_quad(b.p, vue, b.taille * (1.0 - x * 0.5), c * (1.2 * (1.0 - x)))
	_maillage.surface_end()


## Petit losange tourné vers la caméra (braise ou éclat).
func _quad(centre: Vector3, vue: Vector3, taille: float, couleur: Color) -> void:
	var axe := (vue - centre).normalized()
	var droite := axe.cross(Vector3.UP if absf(axe.y) < 0.95 else Vector3.FORWARD).normalized()
	var haut := droite.cross(axe).normalized()
	couleur.a = 1.0
	var coins := [centre + haut * taille, centre + droite * taille, centre - haut * taille, centre - droite * taille]
	for k in [0, 1, 2, 0, 2, 3]:
		_maillage.surface_set_color(couleur)
		_maillage.surface_add_vertex(coins[k])
