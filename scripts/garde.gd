class_name Garde
extends CharacterBody3D
## Garde samouraï : fait sa ronde, regarde devant lui, vient voir quand une lanterne s'éteint
## ou quand il entend un bruit. S'il voit le ninja assez longtemps, il le prend en chasse :
## on peut le semer, se cacher ou le trancher. S'il nous rattrape, il frappe.

signal joueur_repere(garde: Garde)  ## le garde a porté le dernier coup (plus de vie) : défaite
signal chasse_commencee(garde: Garde)

enum Etat { RONDE, ENQUETE, ALERTE, MORT, CHASSE }

## Points de la ronde (coordonnées du monde). Vide : le garde reste en faction.
@export var ronde: PackedVector3Array
@export var regard := Vector3.BACK  ## direction du regard en faction (plein sud par défaut)
@export var vitesse := 1.6
@export var portee := 7.3
@export_range(5, 80) var demi_angle := 25.0
@export var portee_penombre := 2.0  ## distance où il repère même sans lumière
@export var pause_bout_de_ronde := 1.5

@export_group("Chasse")
@export var vitesse_chasse := 3.8  ## le ninja court à 5,5 : on peut le semer
@export var portee_frappe := 1.2
@export var duree_frappe := 0.45  ## temps d'élan avant le coup : le temps de s'écarter
@export var temps_pour_semer := 3.5  ## secondes sans nous voir avant d'abandonner
@export var portee_cri := 10.0  ## les gardes à cette distance viennent voir

var etat := Etat.RONDE
var soupcon := 0.0  ## 0 → 1 : à 1 le ninja est repéré

var _depart: Vector3
var _regard_depart: Vector3
var _cible := 0
var _attente := 0.0
var _point_enquete: Vector3
var _balayage := 0.0
var _cone: Node3D  ## tourne avec le regard : faisceau au sol et lanterne
var _cone_materiau: ShaderMaterial
var _faisceau: SpotLight3D
var _lueur_lanterne: StandardMaterial3D
var _teinte := Color(1.0, 0.78, 0.38)
var _t := randf() * 10.0
var _frappe := -1.0  ## > 0 : élan du coup en cours
var _perdu := 0.0
var _souffle := 0.0  ## après un coup, il reprend son souffle avant de recommencer
var _dernier_vu: Vector3

@onready var _visuel: Node3D = $Visuel


func _ready() -> void:
	add_to_group("gardes")
	collision_layer = 4
	collision_mask = 1
	_depart = global_position
	_regard_depart = regard.normalized()
	_tourner_vers(_regard_depart, 1.0)
	_creer_cone()
	for lanterne in get_tree().get_nodes_in_group("lanternes"):
		lanterne.eteinte.connect(_sur_lanterne_eteinte)


func reinitialiser() -> void:
	if etat == Etat.MORT:
		return
	global_position = _depart
	etat = Etat.RONDE
	soupcon = 0.0
	_cible = 0
	_attente = 0.0
	_frappe = -1.0
	_souffle = 0.0
	_visuel.position = Vector3.ZERO
	_tourner_vers(_regard_depart, 1.0)


func tuer() -> void:
	if etat == Etat.MORT:
		return
	etat = Etat.MORT
	remove_from_group("gardes")
	Sons.jouer("tranche")
	Sons.jouer("garde_tombe", -4.0)
	var niveau := get_tree().current_scene
	if niveau.has_method("compter_garde_tue"):
		niveau.compter_garde_tue()
	collision_layer = 0
	_cone.visible = false
	set_process(false)
	var tween := create_tween()
	tween.tween_property(_visuel, "rotation:x", -PI / 2.0, 0.3)
	tween.tween_property(_visuel, "scale", Vector3(1, 0.2, 1), 0.4)


func _physics_process(delta: float) -> void:
	if etat == Etat.MORT:
		return
	_surveiller(delta)
	match etat:
		Etat.RONDE:
			_faire_la_ronde(delta)
		Etat.ENQUETE:
			_enqueter(delta)
		Etat.ALERTE:
			velocity = Vector3.ZERO
		Etat.CHASSE:
			_chasser(delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()


func _faire_la_ronde(delta: float) -> void:
	if ronde.size() < 2:
		# En faction : il balaie doucement du regard.
		_balayage += delta * 0.6
		var angle := sin(_balayage) * deg_to_rad(35.0)
		_tourner_vers(_regard_depart.rotated(Vector3.UP, angle), delta * 4.0)
		velocity = Vector3.ZERO
		return
	if _attente > 0.0:
		_attente -= delta
		velocity = Vector3.ZERO
		return
	if _aller_vers(ronde[_cible], delta):
		_cible = (_cible + 1) % ronde.size()
		_attente = pause_bout_de_ronde


func _enqueter(delta: float) -> void:
	if _attente > 0.0:
		_attente -= delta
		velocity = Vector3.ZERO
		_tourner_vers(_direction_regard().rotated(Vector3.UP, delta * 1.5), 1.0)
		if _attente <= 0.0:
			etat = Etat.RONDE
		return
	if _aller_vers(_point_enquete, delta):
		_attente = 2.5


## Renvoie true une fois arrivé.
func _aller_vers(point: Vector3, delta: float) -> bool:
	var ecart := point - global_position
	ecart.y = 0.0
	if ecart.length() < 0.3:
		velocity = Vector3.ZERO
		return true
	var direction := ecart.normalized()
	velocity.x = direction.x * vitesse
	velocity.z = direction.z * vitesse
	_tourner_vers(direction, delta * 6.0)
	return false


func _sur_lanterne_eteinte(lanterne: Lanterne) -> void:
	if global_position.distance_to(lanterne.global_position) < 14.0:
		entendre(lanterne.global_position)


## Un bruit (lanterne, plancher qui grince, clochettes) : il va voir, sauf s'il est déjà occupé.
func entendre(point: Vector3) -> void:
	if etat != Etat.RONDE and etat != Etat.ENQUETE:
		return
	etat = Etat.ENQUETE
	var ecart := global_position - point
	ecart.y = 0.0
	_point_enquete = point + ecart.normalized() * 1.2 if ecart.length() > 1.2 else global_position
	_attente = 0.0


func _commencer_chasse(ninja: Ninja) -> void:
	etat = Etat.CHASSE
	_perdu = 0.0
	_frappe = -1.0
	_dernier_vu = ninja.global_position
	chasse_commencee.emit(self)
	for autre: Garde in get_tree().get_nodes_in_group("gardes"):
		if autre != self and autre.global_position.distance_to(global_position) < portee_cri:
			autre.entendre(ninja.global_position)


## Il court vers le dernier endroit où il nous a vus et frappe quand il est assez près.
func _chasser(delta: float) -> void:
	var ninja: Ninja = get_tree().get_first_node_in_group("ninja")
	if ninja == null or ninja.bloque:
		velocity = Vector3.ZERO
		return
	var ecart := ninja.global_position - global_position
	ecart.y = 0.0
	if _frappe >= 0.0:
		velocity = Vector3.ZERO
		_frappe -= delta
		_tourner_vers(ecart.normalized(), delta * 10.0)
		# Il recule un peu pour prendre son élan, puis porte le coup.
		_visuel.position = -_direction_regard() * 0.25 * sin(clampf(1.0 - _frappe / duree_frappe, 0.0, 1.0) * PI)
		if _frappe < 0.0:
			_visuel.position = Vector3.ZERO
			Sons.jouer("frappe")
			_souffle = 0.7
			if ecart.length() < portee_frappe + 0.4 and ninja.blesser(global_position) and ninja.vie <= 0:
				joueur_repere.emit(self)
		return
	if _souffle > 0.0:
		_souffle -= delta
		velocity = Vector3.ZERO
		_tourner_vers(ecart.normalized(), delta * 6.0)
		return
	if _perdu > temps_pour_semer:
		# Semé : il fouille l'endroit où il nous a vus pour la dernière fois.
		etat = Etat.ENQUETE
		soupcon = 0.0
		_point_enquete = _dernier_vu
		_attente = 0.0
		return
	if ecart.length() < portee_frappe and _perdu == 0.0:
		_frappe = duree_frappe
		velocity = Vector3.ZERO
		return
	var vitesse_normale := vitesse
	vitesse = vitesse_chasse
	if _aller_vers(_dernier_vu, delta):
		_perdu = maxf(_perdu, 0.01)
	vitesse = vitesse_normale


func _surveiller(delta: float) -> void:
	var ninja: Ninja = get_tree().get_first_node_in_group("ninja")
	var voit := ninja != null and not ninja.bloque and _voit(ninja)
	if etat == Etat.CHASSE:
		if voit:
			_dernier_vu = ninja.global_position
			_perdu = 0.0
		else:
			_perdu += delta
		_teindre(COULEUR_CHASSE, 1.0)
		return
	if voit:
		var vitesse_soupcon := 3.0 if ninja.est_eclaire() else 1.2
		soupcon = minf(soupcon + vitesse_soupcon * delta, 1.0)
		if soupcon > 0.35:
			etat = Etat.ALERTE
			var vers := ninja.global_position - global_position
			vers.y = 0.0
			_tourner_vers(vers.normalized(), delta * 8.0)
		if soupcon >= 1.0:
			_commencer_chasse(ninja)
	else:
		soupcon = maxf(soupcon - 0.5 * delta, 0.0)
		if etat == Etat.ALERTE and soupcon <= 0.0:
			etat = Etat.RONDE
	_teindre(COULEUR_CALME.lerp(COULEUR_SOUPCON, soupcon), soupcon)


func _voit(ninja: Ninja) -> bool:
	if ninja.est_cache():
		return false
	var vers := ninja.global_position - global_position
	var distance := Vector2(vers.x, vers.z).length()
	# En chasse, il a les yeux rivés sur nous : pas besoin de lumière, ni d'être dans son cône.
	var chasse := etat == Etat.CHASSE
	var limite := portee if chasse or ninja.est_eclaire() else portee_penombre
	if distance > limite:
		return false
	var plat := Vector3(vers.x, 0.0, vers.z).normalized()
	if not chasse and distance > 1.0 and rad_to_deg(plat.angle_to(_direction_regard())) > demi_angle:
		return false
	# Rien entre lui et le ninja ?
	var yeux := global_position + Vector3.UP * 1.2
	var cible := ninja.global_position + Vector3.UP * 0.6
	var requete := PhysicsRayQueryParameters3D.create(yeux, cible, 1)
	return get_world_3d().direct_space_state.intersect_ray(requete).is_empty()


func _direction_regard() -> Vector3:
	return Vector3(sin(_visuel.rotation.y), 0.0, cos(_visuel.rotation.y))


func _tourner_vers(direction: Vector3, poids: float) -> void:
	if direction.length() < 0.01:
		return
	var angle := atan2(direction.x, direction.z)
	_visuel.rotation.y = lerp_angle(_visuel.rotation.y, angle, clampf(poids, 0.0, 1.0))
	if _cone:
		_cone.rotation.y = _visuel.rotation.y


const COULEUR_CALME := Color(1.0, 0.8, 0.42)  ## flamme de bougie
const COULEUR_SOUPCON := Color(1.0, 0.5, 0.15)
const COULEUR_CHASSE := Color(1.0, 0.16, 0.1)


func _process(delta: float) -> void:
	# la flamme de la lanterne tremble un peu
	_t += delta
	var vacille := 0.92 + 0.05 * sin(_t * 7.7) + 0.03 * sin(_t * 13.1)
	_faisceau.light_energy = (1.5 + 1.2 * _alerte_visuelle) * vacille
	_cone_materiau.set_shader_parameter("vacille", vacille)


var _alerte_visuelle := 0.0


func _teindre(couleur: Color, alerte: float) -> void:
	_teinte = _teinte.lerp(couleur, 0.15)
	_alerte_visuelle = lerpf(_alerte_visuelle, alerte, 0.15)
	_faisceau.light_color = _teinte
	_cone_materiau.set_shader_parameter("couleur", _teinte)
	_cone_materiau.set_shader_parameter("force", 0.22 + 0.34 * _alerte_visuelle)
	_lueur_lanterne.emission = _teinte


## Le garde tient une gandō (lanterne de ronde qui éclaire devant elle) : un faisceau chaud
## éclaire vraiment le sol devant lui, et une lueur douce au sol montre jusqu'où il voit.
## Jaune quand il est calme, orange quand il a un doute, rouge quand il nous poursuit.
func _creer_cone() -> void:
	_cone = Node3D.new()
	add_child(_cone)
	# lueur au sol : éventail aux bords flous, plus fort près du garde, fin liseré au bout
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 16
	var bord := demi_angle + 6.0
	for i in pas:
		var a0 := deg_to_rad(-bord + 2.0 * bord * i / pas)
		var a1 := deg_to_rad(-bord + 2.0 * bord * (i + 1) / pas)
		for v in [[Vector3.ZERO, Vector2(0.5, 0)], [Vector3(sin(a1), 0, cos(a1)) * portee, Vector2(float(i + 1) / pas, 1)],
				[Vector3(sin(a0), 0, cos(a0)) * portee, Vector2(float(i) / pas, 1)]]:
			outil.set_uv(v[1])
			outil.add_vertex(v[0])
	_cone_materiau = ShaderMaterial.new()
	_cone_materiau.shader = _shader_lueur()
	var sol := MeshInstance3D.new()
	sol.mesh = outil.commit()
	sol.material_override = _cone_materiau
	sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sol.position.y = 0.05
	_cone.add_child(sol)
	# la lanterne, tenue à bout de bras devant lui
	var lanterne := Node3D.new()
	lanterne.position = Vector3(0.3, 1.0, 0.42)
	_cone.add_child(lanterne)
	var corps := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.1
	cyl.height = 0.24
	cyl.radial_segments = 10
	corps.mesh = cyl
	var cuivre := StandardMaterial3D.new()
	cuivre.albedo_color = Color("#3a2a1e")
	cuivre.metallic = 0.5
	corps.material_override = cuivre
	corps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lanterne.add_child(corps)
	var vitre := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 0.075
	disque.bottom_radius = 0.075
	disque.height = 0.02
	vitre.mesh = disque
	vitre.rotation.x = PI / 2.0
	vitre.position.z = 0.1
	_lueur_lanterne = StandardMaterial3D.new()
	_lueur_lanterne.albedo_color = Color.WHITE
	_lueur_lanterne.emission_enabled = true
	_lueur_lanterne.emission = COULEUR_CALME
	_lueur_lanterne.emission_energy_multiplier = 4.0
	vitre.material_override = _lueur_lanterne
	lanterne.add_child(vitre)
	var anse := MeshInstance3D.new()
	var tige := BoxMesh.new()
	tige.size = Vector3(0.02, 0.22, 0.02)
	anse.mesh = tige
	anse.position = Vector3(0, 0.2, -0.04)
	anse.material_override = cuivre
	lanterne.add_child(anse)
	_faisceau = SpotLight3D.new()
	_faisceau.position = Vector3(0, 0, 0.1)
	_faisceau.rotation.x = deg_to_rad(-14.0)
	_faisceau.rotation.y = PI  # un SpotLight éclaire vers −Z ; le garde regarde vers +Z
	_faisceau.spot_range = portee + 1.5
	_faisceau.spot_angle = demi_angle + 4.0
	_faisceau.spot_attenuation = 0.8
	_faisceau.set("spot_angle_attenuation", 2.0)  # bord du faisceau adouci
	_faisceau.light_color = COULEUR_CALME
	_faisceau.shadow_enabled = false
	lanterne.add_child(_faisceau)
	_teindre(COULEUR_CALME, 0.0)
	_cone.rotation.y = _visuel.rotation.y


static var _shader_partage: Shader


static func _shader_lueur() -> Shader:
	if _shader_partage:
		return _shader_partage
	_shader_partage = Shader.new()
	_shader_partage.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 couleur : source_color = vec3(1.0, 0.8, 0.42);
uniform float force = 0.35;
uniform float vacille = 1.0;
void fragment() {
	float d = UV.y;  // 0 au garde, 1 au bout de sa vue
	float cote = abs(UV.x - 0.5) * 2.0;
	float bords = smoothstep(1.0, 0.45, cote);
	float lueur = (1.0 - d * 0.75) * smoothstep(1.0, 0.86, d) * bords;
	float rim = smoothstep(0.86, 0.95, d) * smoothstep(1.0, 0.95, d) * bords * 0.9;
	float grain = 0.9 + 0.1 * sin(d * 40.0 - TIME * 3.0);
	ALBEDO = couleur * (lueur * grain + rim) * force * vacille;
}
"""
	return _shader_partage
