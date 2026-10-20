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
var _fouille: Array[Vector3] = []  ## pas qui lui restent à faire autour de la cachette
var _axe_fouille := Vector3.ZERO  ## pendant une fouille : il regarde à gauche et à droite de cet axe
var _marche_fouille := 0.0
var _retour_poste := false  ## garde en faction qui revient à son poste après une fouille
var _lanterne: Node3D

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
	_finir_fouille()
	_visuel.position = Vector3.ZERO
	_tourner_vers(_regard_depart, 1.0)


func tuer() -> void:
	if etat == Etat.MORT:
		return
	etat = Etat.MORT
	remove_from_group("gardes")
	Sons.jouer("tranche")
	var niveau := get_tree().current_scene
	if niveau.has_method("compter_garde_tue"):
		niveau.compter_garde_tue()
	collision_layer = 0
	set_process(false)
	_animer_mort()


## Il titube sous le coup, tombe à genoux puis sur le côté. Sa lanterne roule au sol et
## s'éteint doucement. Quelques secondes plus tard, le corps s'enfonce dans la terre et disparaît.
func _animer_mort() -> void:
	var anim: AnimationPlayer = _visuel.get_node_or_null("Modele/Animations")
	if anim:
		anim.play("repos")
		anim.seek(0.0, true)
		anim.pause()
	var arriere := -_direction_regard()
	var cote := 1.0 if randf() < 0.5 else -1.0
	var corps := create_tween().set_parallel()
	# il titube en arrière
	corps.tween_property(_visuel, "position", arriere * 0.3, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	corps.tween_property(_visuel, "rotation:x", -0.3, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	corps.tween_property(_visuel, "rotation:z", 0.18 * cote, 0.2)
	corps.chain().tween_property(_visuel, "rotation:z", -0.14 * cote, 0.25).set_trans(Tween.TRANS_SINE)
	# à genoux, penché en avant
	corps.chain().tween_property(_visuel, "position:y", -0.22, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	corps.tween_property(_visuel, "rotation:x", 0.4, 0.35).set_trans(Tween.TRANS_SINE)
	corps.tween_property(_visuel, "rotation:z", 0.0, 0.3)
	corps.chain().tween_interval(0.3)
	# puis il bascule sur le côté
	corps.chain().tween_property(_visuel, "rotation:z", PI / 2.0 * cote, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	corps.tween_property(_visuel, "rotation:x", 0.1, 0.5)
	corps.tween_property(_visuel, "position:y", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
	corps.chain().tween_callback(func():
		Sons.jouer("garde_tombe", -4.0)
		_poussiere(_visuel.global_position + _visuel.global_basis.y * 0.5, 16))
	# petit rebond au choc
	corps.tween_property(_visuel, "rotation:z", (PI / 2.0 - 0.1) * cote, 0.1).set_ease(Tween.EASE_OUT)
	corps.chain().tween_property(_visuel, "rotation:z", PI / 2.0 * cote, 0.15).set_ease(Tween.EASE_IN)
	# il s'efface : s'enfonce dans la terre en devenant transparent
	corps.chain().tween_interval(3.0)
	corps.chain().tween_callback(func(): _poussiere(_visuel.global_position + _visuel.global_basis.y * 0.5, 22))
	corps.tween_property(_visuel, "position:y", -0.9, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	corps.tween_property(_lanterne, "position:y", -0.4, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for morceau: GeometryInstance3D in _visuel.find_children("*", "GeometryInstance3D", true, false) + _lanterne.find_children("*", "GeometryInstance3D", true, false):
		corps.tween_property(morceau, "transparency", 1.0, 1.6)
	corps.chain().tween_callback(func():
		_visuel.visible = false
		_cone.visible = false)

	# la lanterne tombe, rebondit, roule un peu et s'éteint
	var lampe := create_tween().set_parallel()
	lampe.tween_property(_lanterne, "position:y", 0.09, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	lampe.tween_property(_lanterne, "position:z", _lanterne.position.z + 0.35, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lampe.tween_property(_lanterne, "rotation:z", PI / 2.0 * -cote, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	lampe.tween_method(func(k: float): _cone_materiau.set_shader_parameter("force", 0.22 * (1.0 - k)), 0.0, 1.0, 0.4)
	lampe.tween_method(_eteindre_lanterne.bind(_faisceau.light_energy), 0.0, 1.0, 2.8).set_delay(0.3)


## k de 0 (allumée) à 1 (éteinte) : la flamme baisse en vacillant.
func _eteindre_lanterne(k: float, energie: float) -> void:
	var vacille := 0.75 + 0.25 * sin(k * 47.0) * sin(k * 13.0)
	var reste := (1.0 - k) * (1.0 - k)
	_faisceau.light_energy = energie * reste * vacille
	_lueur_lanterne.emission_energy_multiplier = 4.0 * reste * vacille
	if k >= 1.0:
		_faisceau.visible = false


## Petit nuage de poussière quand il touche le sol ou s'efface.
func _poussiere(point: Vector3, nombre: int) -> void:
	var nuage := CPUParticles3D.new()
	nuage.one_shot = true
	nuage.explosiveness = 0.85
	nuage.amount = nombre
	nuage.lifetime = 1.1
	var boule := SphereMesh.new()
	boule.radius = 0.07
	boule.height = 0.14
	boule.radial_segments = 6
	boule.rings = 3
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.vertex_color_use_as_albedo = true
	boule.material = matiere
	nuage.mesh = boule
	nuage.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	nuage.emission_sphere_radius = 0.4
	nuage.direction = Vector3.UP
	nuage.spread = 70.0
	nuage.initial_velocity_min = 0.4
	nuage.initial_velocity_max = 1.2
	nuage.gravity = Vector3(0, -0.6, 0)
	nuage.damping_min = 1.5
	nuage.damping_max = 2.5
	nuage.scale_amount_min = 0.7
	nuage.scale_amount_max = 1.8
	var fondu := Gradient.new()
	fondu.set_color(0, Color(0.62, 0.56, 0.46, 0.55))
	fondu.set_color(1, Color(0.62, 0.56, 0.46, 0.0))
	nuage.color_ramp = fondu
	add_child(nuage)
	nuage.global_position = Vector3(point.x, global_position.y + 0.15, point.z)
	nuage.emitting = true
	nuage.finished.connect(nuage.queue_free)


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
		if _retour_poste:
			if _aller_vers(_depart, delta):
				_retour_poste = false
			return
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


const DUREE_REGARD := 1.2  ## pendant une fouille : temps pour regarder à gauche puis à droite


func _enqueter(delta: float) -> void:
	var fouille := _axe_fouille != Vector3.ZERO
	if _attente > 0.0:
		_attente -= delta
		velocity = Vector3.ZERO
		if fouille:
			# il tourne la tête à gauche, puis à droite
			var balaye := sin((1.0 - _attente / DUREE_REGARD) * TAU) * deg_to_rad(65.0)
			_tourner_vers(_axe_fouille.rotated(Vector3.UP, balaye), delta * 8.0)
		else:
			_tourner_vers(_direction_regard().rotated(Vector3.UP, delta * 1.5), 1.0)
		if _attente <= 0.0:
			if not _fouille.is_empty():
				_point_enquete = _fouille.pop_front()
				_marche_fouille = 0.0
			else:
				if fouille:
					_retour_poste = true
				_finir_fouille()
				etat = Etat.RONDE
		return
	_marche_fouille += delta
	# pendant une fouille, s'il bute contre un mur il n'insiste pas
	if _aller_vers(_point_enquete, delta) or (fouille and _marche_fouille > 2.5):
		velocity = Vector3.ZERO
		if fouille:
			_attente = DUREE_REGARD
			_axe_fouille = _direction_regard()
		else:
			_attente = 2.5


## Le ninja a plongé dans une cachette : le garde s'arrête là où il l'a vu disparaître,
## regarde autour de lui, fait quelques pas d'un côté puis de l'autre, et retourne à sa ronde.
func _fouiller() -> void:
	etat = Etat.ENQUETE
	soupcon = 0.5  # encore méfiant : s'il nous revoit, il réagit vite
	_attente = 0.0
	_point_enquete = global_position
	_marche_fouille = 0.0
	var face := _dernier_vu - global_position
	face.y = 0.0
	face = face.normalized() if face.length() > 0.1 else _direction_regard()
	_axe_fouille = face
	var cote := 1.0 if randf() < 0.5 else -1.0
	_fouille.clear()
	for i in 2:
		var dir := face.rotated(Vector3.UP, deg_to_rad(randf_range(65.0, 110.0)) * cote)
		_fouille.append(_point_libre(global_position, dir * randf_range(1.3, 1.8)))
		cote = -cote


## Le point à « ecart » de depart, raccourci s'il y a un mur sur le chemin.
func _point_libre(depart: Vector3, ecart: Vector3) -> Vector3:
	var haut := Vector3.UP * 0.6
	var requete := PhysicsRayQueryParameters3D.create(depart + haut, depart + ecart + haut, 1, [get_rid()])
	var touche := get_world_3d().direct_space_state.intersect_ray(requete)
	if touche.is_empty():
		return depart + ecart
	var libre := maxf(depart.distance_to(touche.position - haut) - 0.5, 0.0)
	return depart + ecart.normalized() * libre


func _finir_fouille() -> void:
	_fouille.clear()
	_axe_fouille = Vector3.ZERO


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
	_finir_fouille()
	var ecart := global_position - point
	ecart.y = 0.0
	_point_enquete = point + ecart.normalized() * 1.2 if ecart.length() > 1.2 else global_position
	_attente = 0.0


func _commencer_chasse(ninja: Ninja) -> void:
	etat = Etat.CHASSE
	_perdu = 0.0
	_frappe = -1.0
	_finir_fouille()
	_retour_poste = false
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
	if ninja.est_cache() and _perdu > 0.0:
		# caché sous ses yeux : il court jusqu'à l'endroit où il nous a vus disparaître, puis fouille
		var reste := _dernier_vu - global_position
		reste.y = 0.0
		if reste.length() < 1.6 or _perdu > temps_pour_semer:
			_fouiller()
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
	_lanterne = lanterne
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
