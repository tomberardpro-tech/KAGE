class_name Ninja
extends CharacterBody3D
## Le ninja : marcher, s'accroupir, sauter, s'accrocher aux murs bas et dasher vers la souris.

signal a_saute
signal a_grimpe
signal dash_lance(direction: Vector3)

@export_group("Déplacement")
@export var vitesse := 5.5
@export var vitesse_accroupi := 2.2
@export var acceleration := 45.0
@export var vitesse_rotation := 14.0

@export_group("Saut")
@export var force_saut := 6.5          # ~1,2 m : assez pour un muret
@export var gravite := 18.0
@export var tolerance_saut := 0.12     # on peut encore sauter juste après le bord
@export var hauteur_grimpe_max := 2.4  # mur ou toit qu'on peut attraper en sautant

@export_group("Dash au sabre")
@export var distance_dash := 5.0
@export var duree_dash := 0.18
@export var recharge_dash := 0.6

var accroupi := false
var en_dash := false
var bloque := false  ## pendant une mort ou une victoire

## Rayon du coup de sabre pendant le dash (gardes et lanternes).
const PORTEE_SABRE := 1.3
## Au-dessus de cette hauteur, on est sur un toit : la lune peut nous éclairer.
const HAUTEUR_TOIT := 1.4

var _zones: Array[Zone] = []

var _point_depart: Vector3
var _sol_recent := 0.0
var _saut_demande := 0.0
var _grimpe := false
var _dash_restant := 0.0
var _dash_recharge := 0.0
var _dash_direction := Vector3.ZERO

@onready var _visuel: Node3D = $Visuel


func _ready() -> void:
	_point_depart = global_position
	add_to_group("ninja")
	collision_layer = 2
	collision_mask = 1 | 4  # décor et gardes


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


## Invisible : dans l'ombre (sans lumière), ou accroupi dans les herbes hautes.
func est_cache() -> bool:
	if _dans(Zone.Type.HERBE) and accroupi:
		return true
	return _dans(Zone.Type.OMBRE) and not est_eclaire()


func _physics_process(delta: float) -> void:
	if _grimpe:
		return
	if bloque:
		velocity = Vector3(0.0, velocity.y - gravite * delta, 0.0)
		move_and_slide()
		return
	_dash_recharge -= delta

	if en_dash:
		_continuer_dash(delta)
		return

	var entree := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# La caméra regarde plein nord : haut de l'écran = -Z.
	var direction := Vector3(entree.x, 0.0, entree.y)

	accroupi = Input.is_action_pressed("accroupir") and is_on_floor()
	_visuel.scale.y = lerpf(_visuel.scale.y, 0.72 if accroupi else 1.0, 1.0 - exp(-18.0 * delta))

	# Saut, avec un peu de tolérance pour que ça reste agréable
	_sol_recent = tolerance_saut if is_on_floor() else _sol_recent - delta
	_saut_demande = tolerance_saut if Input.is_action_just_pressed("jump") else _saut_demande - delta
	if _saut_demande > 0.0 and _sol_recent > 0.0:
		velocity.y = force_saut
		_saut_demande = 0.0
		_sol_recent = 0.0
		a_saute.emit()
	if not is_on_floor():
		velocity.y -= gravite * delta
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5

	var cible := direction * (vitesse_accroupi if accroupi else vitesse)
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
		Vector2(cible.x, cible.z), acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if direction.length() > 0.1:
		_tourner_vers(direction, delta)

	move_and_slide()

	if not is_on_floor() and direction.length() > 0.1 and velocity.y < 2.5:
		_essayer_grimper(direction.normalized())

	if Input.is_action_just_pressed("dash") and _dash_recharge <= 0.0:
		_lancer_dash()

	if global_position.y < -10.0:
		reapparaitre()


func reapparaitre(position_depart := _point_depart) -> void:
	global_position = position_depart
	velocity = Vector3.ZERO
	en_dash = false


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
	velocity = Vector3.ZERO
	a_grimpe.emit()
	var arrivee: Vector3 = impact.position + direction * 0.25 + Vector3.UP * 0.05
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", Vector3(global_position.x, arrivee.y, global_position.z), 0.18)
	tween.tween_property(self, "global_position", arrivee, 0.12)
	tween.finished.connect(func(): _grimpe = false)


func _lancer_dash() -> void:
	var direction := _direction_souris()
	if direction == Vector3.ZERO:
		direction = Vector3(sin(_visuel.rotation.y), 0.0, cos(_visuel.rotation.y))
	_dash_direction = direction
	_dash_restant = duree_dash
	_dash_recharge = recharge_dash
	en_dash = true
	_visuel.rotation.y = atan2(direction.x, direction.z)
	dash_lance.emit(direction)


func _continuer_dash(delta: float) -> void:
	_dash_restant -= delta
	_trancher()
	velocity = _dash_direction * (distance_dash / duree_dash)
	move_and_slide()
	if _dash_restant <= 0.0 or is_on_wall():
		en_dash = false
		velocity = _dash_direction * vitesse


## Le sabre touche les gardes et les lanternes proches pendant le dash.
func _trancher() -> void:
	for cible in get_tree().get_nodes_in_group("gardes") + get_tree().get_nodes_in_group("lanternes"):
		var ecart: Vector3 = cible.global_position - global_position
		ecart.y = 0.0
		if ecart.length() < PORTEE_SABRE:
			if cible is Garde:
				cible.tuer()
			elif cible is Lanterne:
				cible.eteindre()


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
