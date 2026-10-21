class_name Ninja
extends CharacterBody3D
## Le ninja : marcher, s'accroupir, sauter (et faire un salto en double saut), s'accrocher
## aux murs bas et frapper au katana (L) dans la direction où il va.
## Il a 3 points de vie : chaque coup de garde en retire un.

signal a_saute
signal a_grimpe
signal a_frappe
signal blesse(vie: int)

@export_group("Déplacement")
@export var vitesse := 5.5
@export var vitesse_accroupi := 2.2
@export var vitesse_sprint := 8.5  ## en tenant Maj
@export var acceleration := 45.0
@export var vitesse_rotation := 14.0

@export_group("Saut")
@export var force_saut := 6.5          # ~1,2 m : assez pour un muret
@export var gravite := 18.0
@export var tolerance_saut := 0.12     # on peut encore sauter juste après le bord
@export var hauteur_grimpe_max := 2.4  # mur ou toit qu'on peut attraper en sautant
@export var force_double_saut := 6.0  ## second appui en l'air : salto
@export var duree_salto := 0.45  ## durée du tour complet du modèle

@export_group("Katana et vie")
@export var duree_coup := 0.42  ## durée de l'animation du coup
@export var instant_touche := 0.16  ## moment où la lame touche
@export var vie_max := 3
@export var invulnerable_apres_coup := 1.3

var accroupi := false
var en_dash := false  ## plus de dash : gardé à faux pour les autres scripts
var bloque := false  ## pendant une mort ou une victoire
var vie := 3
var attaque := 0.0  ## > 0 : coup de katana en cours (temps restant)
var en_grimpe := false
var pose_forcee := ""  ## animation imposée pendant une cinématique (ex. « brandir »)
var katana_en_main := false  ## P sort le katana ou le range dans son fourreau
var sprinte := false
var salto := 0.0  ## > 0 : salto du double saut en cours (temps restant), lu par anim_chibi.gd

## Portée du katana, devant le ninja (gardes et lanternes).
const PORTEE_SABRE := 1.7
const ANGLE_SABRE := 80.0  ## demi-angle devant lui, en degrés
## Distance à laquelle on peut ouvrir une porte ou un coffre avec E.
const PORTEE_INTERACTION := 1.8
## Au-dessus de cette hauteur, on est sur un toit : la lune peut nous éclairer.
const HAUTEUR_TOIT := 1.4

var _zones: Array[Zone] = []

var _point_depart: Vector3
var _sol_recent := 0.0
var _saut_demande := 0.0
var _grimpe := false
var _a_touche := false
var _invulnerable := 0.0
var _pas := 0.0
var _double_saut := true  ## rechargé en touchant le sol ou après s'être hissé sur un mur
var _direction_coup := Vector3.BACK  ## sens du coup de katana en cours
var _trainee: Trainee

@onready var _visuel: Node3D = $Visuel


func _ready() -> void:
	_point_depart = global_position
	vie = vie_max
	add_to_group("ninja")
	collision_layer = 2
	collision_mask = 1 | 4  # décor et gardes
	# Traînée rouge du salto : elle suit un point au niveau des hanches du modèle,
	# qui décrit une boucle quand le modèle tourne sur lui-même.
	var hanches := Node3D.new()
	hanches.name = "PointTrainee"
	hanches.position = Vector3(0.0, 0.32, -0.05)
	var modele := _visuel.get_node_or_null("Modele")
	(modele if modele else _visuel).add_child(hanches)
	_trainee = Trainee.new()
	_trainee.name = "Trainee"
	_trainee.source = hanches
	add_child(_trainee)


func entrer_zone(zone: Zone) -> void:
	if zone not in _zones:
		_zones.append(zone)


func sortir_zone(zone: Zone) -> void:
	_zones.erase(zone)


func _dans(type: Zone.Type) -> bool:
	for zone in _zones:
		if zone.active and zone.type == type:
			return true
	return false


## Éclairé par une lanterne, le clair de lune, ou la lune quand on est sur un toit.
func est_eclaire() -> bool:
	if _dans(Zone.Type.LUMIERE) or _dans(Zone.Type.LUNE):
		return true
	var niveau := get_tree().current_scene
	return global_position.y > HAUTEUR_TOIT and niveau.get("lune_visible") == true


## Invisible : dans l'ombre (sans lumière), accroupi dans les herbes hautes, ou dans un gros buisson.
func est_cache() -> bool:
	if _dans(Zone.Type.BUISSON):
		return true
	if _dans(Zone.Type.HERBE) and accroupi:
		return true
	return _dans(Zone.Type.OMBRE) and not est_eclaire()


func _physics_process(delta: float) -> void:
	if _grimpe:
		return
	_clignoter(delta)  # même bloqué, sinon il pourrait rester invisible pendant une cinématique
	if salto > 0.0:
		salto = maxf(0.0, salto - delta)
	_trainee.actif = salto > 0.04
	if bloque:
		velocity = Vector3(0.0, velocity.y - gravite * delta, 0.0)
		move_and_slide()
		return
	if attaque > 0.0:
		attaque -= delta
		if not _a_touche and attaque <= duree_coup - instant_touche:
			_a_touche = true
			_trancher()

	var entree := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# La caméra regarde plein nord : haut de l'écran = -Z.
	var direction := Vector3(entree.x, 0.0, entree.y)

	accroupi = Input.is_action_pressed("accroupir") and is_on_floor()
	_visuel.scale.y = lerpf(_visuel.scale.y, 0.9 if accroupi else 1.0, 1.0 - exp(-18.0 * delta))

	# Saut, avec un peu de tolérance pour que ça reste agréable
	_sol_recent = tolerance_saut if is_on_floor() else _sol_recent - delta
	_saut_demande = tolerance_saut if Input.is_action_just_pressed("jump") else _saut_demande - delta
	if _saut_demande > 0.0 and _sol_recent > 0.0:
		velocity.y = force_saut
		_saut_demande = 0.0
		_sol_recent = 0.0
		a_saute.emit()
		Sons.jouer("saut", -16.0, randf_range(0.95, 1.08))
	elif Input.is_action_just_pressed("jump") and not is_on_floor() and _double_saut:
		_double_sauter()
	if is_on_floor() and salto <= 0.0:
		_double_saut = true
	if not is_on_floor():
		velocity.y -= gravite * delta
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5

	sprinte = Input.is_action_pressed("sprint") and not accroupi and direction.length() > 0.1
	var cible := direction * (vitesse_accroupi if accroupi else (vitesse_sprint if sprinte else vitesse))
	if attaque > 0.0:
		cible *= 0.25  # on se plante pour frapper
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
		Vector2(cible.x, cible.z), acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if direction.length() > 0.1 and attaque <= 0.0:  # pendant un coup, on garde le sens de la lame
		_tourner_vers(direction, delta)

	move_and_slide()
	_bruit_de_pas(delta)

	if not is_on_floor() and direction.length() > 0.1 and velocity.y < 2.5:
		_essayer_grimper(direction.normalized())

	if Input.is_action_just_pressed("katana"):
		ranger_katana(katana_en_main)
	if Input.is_action_just_pressed("frapper") and attaque <= 0.0:
		if not katana_en_main:
			ranger_katana(false)  # L sort le katana s'il était rangé
		_frapper(direction)

	if Input.is_action_just_pressed("interact"):
		var objet := objet_proche()
		if objet:
			objet.interagir()

	if global_position.y < -10.0:
		reapparaitre()


## Pas feutrés en courant ; accroupi, on ne s'entend pas.
func _bruit_de_pas(delta: float) -> void:
	var vitesse_sol := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or accroupi or vitesse_sol < 1.0:
		_pas = 0.0
		return
	_pas -= delta
	if _pas <= 0.0:
		_pas = 0.22 if sprinte else 0.3
		Sons.jouer("pas", -16.0 if not sprinte else -12.0, randf_range(0.85, 1.15))


func reapparaitre(position_depart := _point_depart) -> void:
	global_position = position_depart
	velocity = Vector3.ZERO
	vie = vie_max
	attaque = 0.0
	salto = 0.0
	_double_saut = true
	_trainee.effacer()
	_invulnerable = 0.0
	_visuel.visible = true
	blesse.emit(vie)


## Coup d'un garde : on perd un point de vie et on est repoussé. Renvoie true si le coup porte.
func blesser(depuis: Vector3) -> bool:
	if bloque or _invulnerable > 0.0 or vie <= 0:
		return false
	vie -= 1
	_invulnerable = invulnerable_apres_coup
	var recul := global_position - depuis
	recul.y = 0.0
	recul = recul.normalized() if recul.length() > 0.01 else Vector3.BACK
	velocity = recul * 7.0 + Vector3.UP * 3.0
	blesse.emit(vie)
	return true


## Après un coup, le ninja clignote le temps d'être de nouveau touchable.
func _clignoter(delta: float) -> void:
	if _invulnerable <= 0.0:
		return
	_invulnerable -= delta
	_visuel.visible = _invulnerable <= 0.0 or fmod(_invulnerable, 0.16) > 0.07


func _tourner_vers(direction: Vector3, delta: float) -> void:
	var angle := atan2(direction.x, direction.z)
	_visuel.rotation.y = lerp_angle(_visuel.rotation.y, angle, 1.0 - exp(-vitesse_rotation * delta))


## Si un mur bas est devant nous et que son sommet est à portée, on s'y hisse.
func _essayer_grimper(direction: Vector3) -> void:
	var espace := get_world_3d().direct_space_state
	var torse := global_position + Vector3.UP * 0.6
	var devant := PhysicsRayQueryParameters3D.create(torse, torse + direction * 0.7, collision_mask, [get_rid()])
	if espace.intersect_ray(devant).is_empty():
		return
	var haut := global_position + direction * 0.75 + Vector3.UP * (hauteur_grimpe_max + 0.2)
	var dessus := PhysicsRayQueryParameters3D.create(haut, haut + Vector3.DOWN * (hauteur_grimpe_max + 0.2), collision_mask, [get_rid()])
	var impact := espace.intersect_ray(dessus)
	if impact.is_empty() or impact.normal.y < 0.7:
		return
	var hauteur: float = impact.position.y - global_position.y
	if hauteur < 0.3 or hauteur > hauteur_grimpe_max:
		return
	_grimpe = true
	en_grimpe = true
	velocity = Vector3.ZERO
	a_grimpe.emit()
	Sons.jouer("grimpe", -4.0)
	var arrivee: Vector3 = impact.position + direction * 0.25 + Vector3.UP * 0.05
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", Vector3(global_position.x, arrivee.y, global_position.z), 0.24)
	tween.tween_property(self, "global_position", arrivee, 0.16)
	tween.finished.connect(func():
		_grimpe = false
		en_grimpe = false
		_double_saut = true)


## Second saut en l'air : petite impulsion, salto vers l'avant et traînée rouge.
func _double_sauter() -> void:
	_double_saut = false
	velocity.y = force_double_saut
	salto = duree_salto
	_saut_demande = 0.0
	a_saute.emit()
	Sons.jouer("saut", -14.0, randf_range(1.12, 1.25))


## Coup de katana dans la direction où l'on va (flèches / ZQSD) ; sans touche de direction,
## vers la souris si l'on clique, sinon droit devant soi. La lame touche un peu après le début.
func _frapper(direction := Vector3.ZERO) -> void:
	var vise := direction
	if vise.length() < 0.1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		vise = _direction_souris()
	if vise.length() > 0.1:
		_visuel.rotation.y = atan2(vise.x, vise.z)
	_direction_coup = Vector3(sin(_visuel.rotation.y), 0.0, cos(_visuel.rotation.y))
	attaque = duree_coup
	_a_touche = false
	a_frappe.emit()
	Sons.jouer("tranche", -5.0, randf_range(0.95, 1.08))


## Sort le katana (ranger = faux) ou le remet dans son fourreau.
func ranger_katana(ranger: bool) -> void:
	if katana_en_main == not ranger:
		return
	katana_en_main = not ranger
	Sons.jouer("rengainer" if ranger else "degainer", -6.0, randf_range(0.95, 1.05))


## Porte, coffre ou fil à clochettes assez proche pour qu'on s'en serve avec E.
func objet_proche() -> Node3D:
	var meilleur: Node3D = null
	var distance := PORTEE_INTERACTION
	for objet: Node3D in get_tree().get_nodes_in_group("interactifs"):
		var d := _distance_a(objet)
		if objet.peut_interagir() and d < distance:
			distance = d
			meilleur = objet
	return meilleur


## Distance au sol ; pour un fil, distance au point le plus proche du fil.
func _distance_a(objet: Node3D) -> float:
	var local := objet.to_local(global_position)
	if objet is Clochettes:
		local.x = maxf(absf(local.x) - objet.longueur / 2.0, 0.0)
	local.y = 0.0
	return local.length()


## Le katana touche les gardes, les lanternes et le seigneur Oni dans le sens du coup.
func _trancher() -> void:
	var devant := _direction_coup
	for cible in get_tree().get_nodes_in_group("gardes") + get_tree().get_nodes_in_group("lanternes") + get_tree().get_nodes_in_group("boss"):
		var ecart: Vector3 = cible.global_position - global_position
		ecart.y = 0.0
		var face := ecart.length() < 0.5 or rad_to_deg(devant.angle_to(ecart)) < ANGLE_SABRE
		# le seigneur Oni est un géant : on le touche d'un peu plus loin
		var portee := PORTEE_SABRE + (0.9 if cible is Boss else 0.0)
		if ecart.length() < portee and face:
			if cible is Garde:
				cible.tuer()
			elif cible is Lanterne:
				cible.eteindre()
			elif cible is Boss:
				cible.recevoir_coup(global_position)


## Direction au sol entre le ninja et le curseur de la souris.
func _direction_souris() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var souris := get_viewport().get_mouse_position()
	var origine := camera.project_ray_origin(souris)
	var rayon := camera.project_ray_normal(souris)
	var plan := Plane(Vector3.UP, global_position.y)
	var point = plan.intersects_ray(origine, rayon)
	if point == null:
		return Vector3.ZERO
	var vers: Vector3 = point - global_position
	vers.y = 0.0
	return vers.normalized() if vers.length() > 0.2 else Vector3.ZERO
