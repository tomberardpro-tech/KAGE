class_name Garde
extends CharacterBody3D
## Garde samouraï : fait sa ronde, regarde devant lui, vient voir quand une lanterne s'éteint.
## Il repère le ninja s'il le voit en pleine lumière, ou de près dans la pénombre.

signal joueur_repere(garde: Garde)

enum Etat { RONDE, ENQUETE, ALERTE, MORT }

## Points de la ronde (coordonnées du monde). Vide : le garde reste en faction.
@export var ronde: PackedVector3Array
@export var regard := Vector3.BACK  ## direction du regard en faction (plein sud par défaut)
@export var vitesse := 1.6
@export var portee := 7.3
@export_range(5, 80) var demi_angle := 25.0
@export var portee_penombre := 2.0  ## distance où il repère même sans lumière
@export var pause_bout_de_ronde := 1.5

var etat := Etat.RONDE
var soupcon := 0.0  ## 0 → 1 : à 1 le ninja est repéré

var _depart: Vector3
var _regard_depart: Vector3
var _cible := 0
var _attente := 0.0
var _point_enquete: Vector3
var _balayage := 0.0
var _cone: MeshInstance3D
var _cone_materiau: StandardMaterial3D

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
	_tourner_vers(_regard_depart, 1.0)


func tuer() -> void:
	if etat == Etat.MORT:
		return
	etat = Etat.MORT
	remove_from_group("gardes")
	var niveau := get_tree().current_scene
	if niveau.has_method("compter_garde_tue"):
		niveau.compter_garde_tue()
	collision_layer = 0
	_cone.visible = false
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
	if etat == Etat.MORT or etat == Etat.ALERTE:
		return
	if global_position.distance_to(lanterne.global_position) < 14.0:
		etat = Etat.ENQUETE
		_point_enquete = lanterne.global_position + (global_position - lanterne.global_position).normalized() * 1.2
		_attente = 0.0


func _surveiller(delta: float) -> void:
	var ninja: Ninja = get_tree().get_first_node_in_group("ninja")
	var voit := ninja != null and not ninja.bloque and _voit(ninja)
	if voit:
		var vitesse_soupcon := 3.0 if ninja.est_eclaire() else 1.2
		soupcon = minf(soupcon + vitesse_soupcon * delta, 1.0)
		if soupcon > 0.35:
			etat = Etat.ALERTE
			var vers := ninja.global_position - global_position
			vers.y = 0.0
			_tourner_vers(vers.normalized(), delta * 8.0)
		if soupcon >= 1.0:
			joueur_repere.emit(self)
	else:
		soupcon = maxf(soupcon - 0.5 * delta, 0.0)
		if etat == Etat.ALERTE and soupcon <= 0.0:
			etat = Etat.RONDE
	_cone_materiau.albedo_color = Color(Palette.LAQUE, 0.18 + soupcon * 0.4)


func _voit(ninja: Ninja) -> bool:
	if ninja.est_cache():
		return false
	var vers := ninja.global_position - global_position
	var distance := Vector2(vers.x, vers.z).length()
	var limite := portee if ninja.est_eclaire() else portee_penombre
	if distance > limite:
		return false
	var plat := Vector3(vers.x, 0.0, vers.z).normalized()
	if distance > 1.0 and rad_to_deg(plat.angle_to(_direction_regard())) > demi_angle:
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


## Cône de vision dessiné au sol, comme sur le plan Figma.
func _creer_cone() -> void:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 12
	for i in pas:
		var a0 := deg_to_rad(-demi_angle + 2.0 * demi_angle * i / pas)
		var a1 := deg_to_rad(-demi_angle + 2.0 * demi_angle * (i + 1) / pas)
		outil.add_vertex(Vector3.ZERO)
		outil.add_vertex(Vector3(sin(a1), 0, cos(a1)) * portee)
		outil.add_vertex(Vector3(sin(a0), 0, cos(a0)) * portee)
	_cone_materiau = StandardMaterial3D.new()
	_cone_materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_materiau.albedo_color = Color(Palette.LAQUE, 0.18)
	_cone = MeshInstance3D.new()
	_cone.mesh = outil.commit()
	_cone.material_override = _cone_materiau
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position.y = 0.04
	add_child(_cone)
	_cone.rotation.y = _visuel.rotation.y
