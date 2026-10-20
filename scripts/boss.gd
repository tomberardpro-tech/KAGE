class_name Boss
extends CharacterBody3D
## Le seigneur Oni, gardien du parchemin, au cœur du donjon.
## Il marche vers le ninja, prend son élan (il rougit : c'est le moment de s'écarter), charge,
## puis reste un instant essoufflé : c'est là qu'il faut frapper. Tous les trois assauts,
## il saute et frappe le sol : une onde rouge s'étend, il faut sauter par-dessus.
## Entre deux, il frappe de sa grande épée (elle rougit quand il la lève : on recule)
## ou recule et souffle trois boules de feu (sa gueule s'allume : on se déplace).
## À la moitié de sa vie, il enrage et va plus vite.

signal tombe  ## il vient de s'effondrer (le niveau lui laisse dire sa dernière réplique)
signal vaincu  ## il a disparu : la herse se lève, le coffre apparaît
signal vie_changee(vie: int, vie_max: int)

enum Etat { ATTENTE, POURSUITE, ELAN, CHARGE, SOUFFLE, ONDE_ELAN, ONDE, MORT,
	EPEE_LEVE, EPEE_FRAPPE, FLAMMES_ELAN, FLAMMES }

## ordre des assauts : charge, épée, onde, flammes, puis on recommence
const ORDRE := [Etat.ELAN, Etat.EPEE_LEVE, Etat.ONDE_ELAN, Etat.FLAMMES_ELAN]
const FLAMME := preload("res://scripts/flamme_boss.gd")

@export var vie_max := 8
@export var vitesse := 2.4
@export var vitesse_charge := 13.0
@export var portee_charge := 6.0
@export var duree_elan := 0.75
@export var duree_souffle := 1.3
@export var portee_epee := 2.8
@export var duree_leve := 0.55

var vie := 8
var etat := Etat.ATTENTE

var _temps := 0.0
var _direction := Vector3.BACK
var _assauts := 0
var _a_touche := false
var _invulnerable := 0.0
var _depart: Vector3
var _modele: Node3D
var _animations: AnimationPlayer
var _peau: Array[GeometryInstance3D] = []
var _flash: StandardMaterial3D
var _onde: MeshInstance3D
var _onde_mat: ShaderMaterial
var _fleche: MeshInstance3D
var _barre: CanvasLayer
var _barre_vie: Control
var _vie_affichee := 1.0
var _aura: OmniLight3D
var _epee: Node3D  # pivot de la grande épée, dans sa main droite
var _lame: StandardMaterial3D
var _trainee: MeshInstance3D
var _trainee_mat: ShaderMaterial
var _gueule: StandardMaterial3D
var _flamme_cachee: MeshInstance3D  # boule invisible : le niveau préchauffe sa matière
var _vise := 0.0  # angle de regard au moment de frapper
var _tirs := 0


func _ready() -> void:
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	_depart = global_position
	vie = vie_max
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.75
	capsule.height = 2.6
	forme.shape = capsule
	forme.position.y = 1.3
	add_child(forme)
	_construire_modele()
	_construire_onde()
	_construire_epee()
	_construire_barre()


# --- Pilotage par le niveau ------------------------------------------------

## Le combat commence (après sa réplique).
func reveiller() -> void:
	if etat != Etat.ATTENTE:
		return
	_barre.visible = true
	_changer(Etat.POURSUITE)


## Cinématique d'arrivée : il se redresse et rugit, ses yeux et son aura s'embrasent.
func rugir() -> void:
	Sons.jouer("boss_cri", 0.0, 0.85)
	_secouer_camera(0.6)
	var taille := _modele.scale
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_aura, "light_energy", 5.0, 0.3)
	t.parallel().tween_method(_teinte, 0.0, 0.45, 0.3)
	t.parallel().tween_property(_modele, "scale", taille * 1.1, 0.3)
	t.tween_interval(0.6)
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(_aura, "light_energy", 0.8, 0.9)
	t.parallel().tween_method(_teinte, 0.45, 0.0, 0.9)
	t.parallel().tween_property(_modele, "scale", taille, 0.9)


## Le ninja est reparti de l'autel : le seigneur reprend sa place, en pleine forme.
func reinitialiser() -> void:
	if etat == Etat.MORT:
		return
	global_position = _depart
	velocity = Vector3.ZERO
	vie = vie_max
	_assauts = 0
	_barre.visible = false
	_onde.visible = false
	_fleche.visible = false
	_teinte(0.0)
	_calmer()
	_changer(Etat.ATTENTE)
	_regarder(Vector3.BACK, 1.0)
	vie_changee.emit(vie, vie_max)


## Coup de katana du ninja. Renvoie true si le coup porte.
func recevoir_coup(depuis: Vector3) -> bool:
	if etat == Etat.MORT or etat == Etat.ATTENTE or _invulnerable > 0.0:
		return false
	vie -= 1
	_invulnerable = 0.35
	vie_changee.emit(vie, vie_max)
	Sons.jouer("tranche")
	Sons.jouer("boss_touche", -2.0, randf_range(0.9, 1.1))
	# éclair blanc et petit recul
	_flash.emission = Color.WHITE
	_flash.emission_energy_multiplier = 2.5
	create_tween().tween_property(_flash, "emission_energy_multiplier", 0.0, 0.25)
	var recul := global_position - depuis
	recul.y = 0.0
	velocity = recul.normalized() * 3.0
	_secouer_camera(0.12)
	if vie <= 0:
		_mourir()
	return true


# --- Comportement -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	_invulnerable -= delta
	_vie_affichee = move_toward(_vie_affichee, float(vie) / vie_max, delta * 1.5)
	_barre_vie.queue_redraw()
	if etat == Etat.MORT or etat == Etat.ATTENTE:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		_gravite(delta)
		move_and_slide()
		return
	var ninja: Ninja = get_tree().get_first_node_in_group("ninja")
	if ninja == null:
		return
	var ecart := ninja.global_position - global_position
	ecart.y = 0.0
	var rage := 1.3 if vie <= vie_max / 2 else 1.0
	_temps -= delta
	match etat:
		Etat.POURSUITE:
			_regarder(ecart.normalized(), delta * 5.0)
			_modele.rotation.x = 0.0
			var prochain: Etat = ORDRE[_assauts % ORDRE.size()]
			# pour l'épée il doit venir tout près : il presse le pas
			var allure := 1.5 if prochain == Etat.EPEE_LEVE else 1.0
			var portee := portee_charge
			if prochain == Etat.EPEE_LEVE:
				portee = portee_epee - 0.4
			elif prochain == Etat.FLAMMES_ELAN:
				portee = 9.0
			var cible := ecart.normalized() * vitesse * rage * allure
			velocity.x = move_toward(velocity.x, cible.x, delta * 12.0)
			velocity.z = move_toward(velocity.z, cible.z, delta * 12.0)
			_jouer("marche", 1.2 * rage)
			if ninja.bloque:
				velocity = Vector3.ZERO
			elif _temps <= 0.0 and ecart.length() < portee:
				_assauts += 1
				_changer(prochain)
		Etat.ELAN:
			# il recule un peu, rougit et vise : une flèche rouge montre où il va charger
			velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
			_regarder(ecart.normalized(), delta * 8.0)
			_direction = _direction_regard()
			_fleche.visible = true
			_fleche.rotation.y = _modele.rotation.y
			_teinte(1.0 - _temps / (duree_elan / rage))
			if _temps <= 0.0:
				_fleche.visible = false
				_a_touche = false
				Sons.jouer("boss_charge")
				_changer(Etat.CHARGE)
		Etat.CHARGE:
			velocity.x = _direction.x * vitesse_charge * rage
			velocity.z = _direction.z * vitesse_charge * rage
			_jouer("frappe", 1.6)
			if not _a_touche and ecart.length() < 1.7 and ninja.blesser(global_position):
				_a_touche = true
				_toucher_ninja(ninja)
			if _temps <= 0.0 or is_on_wall():
				if is_on_wall():
					_secouer_camera(0.25)
					Sons.jouer("frappe", 0.0, 0.7)
				_teinte(0.0)
				_changer(Etat.SOUFFLE)
		Etat.SOUFFLE:
			velocity = velocity.move_toward(Vector3.ZERO, delta * 25.0)
			_epee.rotation.x = lerpf(_epee.rotation.x, 0.5, delta * 4.0)
			_jouer("repos", 0.6)
			if _temps <= 0.0:
				_changer(Etat.POURSUITE)
		Etat.ONDE_ELAN:
			velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
			_teinte(1.0 - _temps / 0.7)
			# il s'accroupit, puis bondit
			_modele.position.y = -0.25 * (1.0 - _temps / 0.7)
			if _temps <= 0.0:
				_modele.position.y = 0.0
				_lancer_onde()
				_changer(Etat.ONDE)
		Etat.ONDE:
			velocity = Vector3.ZERO
			var rayon := _onde.scale.x * 0.5
			var dist := ecart.length()
			if not _a_touche and ninja.is_on_floor() and absf(dist - rayon) < 0.55 and ninja.blesser(global_position):
				_a_touche = true
				_toucher_ninja(ninja)
			if _temps <= 0.0:
				_teinte(0.0)
				_changer(Etat.SOUFFLE)
		Etat.EPEE_LEVE:
			# il lève l'épée, qui rougit, le buste tourné pour prendre de l'élan
			velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
			_regarder(ecart.normalized(), delta * 6.0)
			_vise = _modele.rotation.y
			var p := 1.0 - _temps / duree_leve
			_epee.rotation.x = lerpf(0.5, -1.9, minf(p * 2.0, 1.0))
			_rougir_lame(p)
			_teinte(p * 0.6)
			if _temps <= 0.0:
				_a_touche = false
				Sons.jouer("tranche", -6.0, 0.6)
				_trainee.visible = true
				_trainee.rotation.y = _vise
				_changer(Etat.EPEE_FRAPPE)
		Etat.EPEE_FRAPPE:
			# grand revers horizontal, de sa droite vers sa gauche, en avançant d'un pas
			var p := clampf(1.0 - _temps / 0.24, 0.0, 1.0)
			var angle := lerpf(-1.25, 1.25, p)
			_modele.rotation.y = _vise + angle
			_epee.rotation.x = lerpf(-1.9, -0.05, minf(p * 3.0, 1.0))
			velocity.x = sin(_vise) * 3.0
			velocity.z = cos(_vise) * 3.0
			_trainee_mat.set_shader_parameter("avance", p)
			# le ninja est touché s'il est dans l'arc déjà balayé, à portée de lame
			var local := ecart.rotated(Vector3.UP, -_vise)
			var a := atan2(local.x, local.z)
			var dy := absf(ninja.global_position.y - global_position.y)
			if not _a_touche and ecart.length() < portee_epee and dy < 1.6 and a > -1.4 and a < angle + 0.2 \
					and ninja.blesser(global_position):
				_a_touche = true
				Sons.jouer("frappe", -6.0, 0.8)
				_toucher_ninja(ninja)
			if _temps <= 0.0:
				_rougir_lame(0.0)
				_teinte(0.0)
				_effacer_trainee()
				_changer(Etat.SOUFFLE)
		Etat.FLAMMES_ELAN:
			# il recule en inspirant : sa gueule et son aura s'embrasent
			_regarder(ecart.normalized(), delta * 8.0)
			velocity.x = -sin(_modele.rotation.y) * 2.5
			velocity.z = -cos(_modele.rotation.y) * 2.5
			var p := 1.0 - _temps / 0.85
			_gueule.emission_energy_multiplier = p * 6.0
			_aura.light_energy = 0.8 + p * 2.5
			_modele.rotation.x = -0.25 * p  # il se cambre
			# une boule de feu grossit déjà dans sa gueule
			_flamme_cachee.visible = true
			_flamme_cachee.scale = Vector3.ONE * 0.3 * p
			if _temps <= 0.0:
				_tirs = 0
				_changer(Etat.FLAMMES)
		Etat.FLAMMES:
			velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
			_regarder(ecart.normalized(), delta * 6.0)
			_modele.rotation.x = 0.1
			if _temps <= 0.0:
				if _tirs < 3:
					_cracher(ninja)
					_tirs += 1
					_temps = 0.38
				else:
					_calmer(false)
					_changer(Etat.SOUFFLE)
	_gravite(delta)
	move_and_slide()


func _changer(nouvel: Etat) -> void:
	etat = nouvel
	match nouvel:
		Etat.POURSUITE:
			_temps = 0.6
		Etat.ELAN:
			_temps = duree_elan / (1.3 if vie <= vie_max / 2 else 1.0)
			Sons.jouer("boss_cri", -3.0, randf_range(0.9, 1.05))
			_jouer("repos", 0.3)
		Etat.CHARGE:
			_temps = 0.42
		Etat.SOUFFLE:
			_temps = duree_souffle
		Etat.ONDE_ELAN:
			_temps = 0.7
			Sons.jouer("boss_cri", -3.0, 0.8)
		Etat.ONDE:
			_temps = 0.9
			_a_touche = false
		Etat.EPEE_LEVE:
			_temps = duree_leve
			Sons.jouer("boss_cri", -6.0, randf_range(1.0, 1.1))
			Sons.jouer("degainer", -8.0, 0.7)
			_jouer("repos", 0.3)
		Etat.EPEE_FRAPPE:
			_temps = 0.24
		Etat.FLAMMES_ELAN:
			_temps = 0.85
			Sons.jouer("boss_charge", -9.0, 0.6)
			_jouer("repos", 0.3)
		Etat.FLAMMES:
			_temps = 0.0


func _gravite(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0


func _toucher_ninja(ninja: Ninja) -> void:
	_secouer_camera(0.3)
	if ninja.vie <= 0:
		var niveau := get_tree().current_scene
		if niveau.has_method("ninja_vaincu"):
			niveau.ninja_vaincu()


## Une boule de feu part de sa gueule, droit vers le ninja (là où il est maintenant).
func _cracher(ninja: Ninja) -> void:
	var boule := FLAMME.new()
	boule.lanceur = self
	get_parent().add_child(boule)
	boule.global_position = _flamme_cachee.global_position
	var vers := ninja.global_position + Vector3.UP * 0.6 - boule.global_position
	boule.direction = vers.normalized()
	Sons.jouer("boss_onde", -10.0, 1.6)
	_gueule.emission_energy_multiplier = 6.0
	create_tween().tween_property(_gueule, "emission_energy_multiplier", 3.0, 0.3)


## 0 : acier ; 1 : lame rouge vif (il va frapper).
func _rougir_lame(v: float) -> void:
	_lame.albedo_color = Color("#dfe3ea").lerp(Color(1.0, 0.2, 0.1), v)
	_lame.emission_energy_multiplier = v * 3.0


func _effacer_trainee() -> void:
	var t := create_tween()
	t.tween_method(func(v: float): _trainee_mat.set_shader_parameter("fondu", v), 1.0, 0.0, 0.2)
	t.tween_callback(func():
		_trainee.visible = false
		_trainee_mat.set_shader_parameter("fondu", 1.0))


## Il frappe le sol : une onde rouge s'étend jusqu'à 8 m.
func _lancer_onde() -> void:
	Sons.jouer("boss_onde")
	_secouer_camera(0.4)
	_onde.visible = true
	_onde.scale = Vector3.ONE * 0.5
	var t := create_tween()
	t.tween_property(_onde, "scale", Vector3.ONE * 16.0, 0.9)
	t.parallel().tween_method(func(v: float): _onde_mat.set_shader_parameter("fondu", v), 1.0, 0.0, 0.9)
	t.tween_callback(func(): _onde.visible = false)


## Épée baissée, gueule éteinte et (sauf demande) plus aucune boule de feu en vol.
func _calmer(eteindre_flammes := true) -> void:
	_epee.rotation.x = 0.5
	_rougir_lame(0.0)
	_trainee.visible = false
	_gueule.emission_energy_multiplier = 0.0
	_flamme_cachee.visible = false
	_aura.light_energy = 0.8
	_modele.rotation.x = 0.0
	if eteindre_flammes:
		for f in get_tree().get_nodes_in_group("flamme_boss"):
			f.queue_free()


func _mourir() -> void:
	etat = Etat.MORT
	remove_from_group("boss")
	collision_layer = 0
	_fleche.visible = false
	_onde.visible = false
	_teinte(0.0)
	_calmer()
	_jouer("repos", 0.2)
	_animations.pause()
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(_modele, "rotation:x", -PI / 2.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		Sons.jouer("garde_tombe", 2.0, 0.7)
		_secouer_camera(0.35))
	t.tween_interval(0.5)
	t.tween_callback(func():
		_barre.visible = false
		tombe.emit())


## Après sa dernière réplique, il se dissout dans l'ombre.
func disparaitre() -> void:
	var t := create_tween().set_parallel()
	for g in _peau:
		t.tween_property(g, "transparency", 1.0, 1.2)
	t.chain().tween_callback(func():
		visible = false
		vaincu.emit())


func _jouer(nom: String, vitesse_anim := 1.0) -> void:
	if _animations.current_animation != nom:
		_animations.play(nom, 0.15)
	_animations.speed_scale = vitesse_anim


func _regarder(direction: Vector3, poids: float) -> void:
	if direction.length() < 0.01:
		return
	_modele.rotation.y = lerp_angle(_modele.rotation.y, atan2(direction.x, direction.z), clampf(poids, 0.0, 1.0))


func _direction_regard() -> Vector3:
	return Vector3(sin(_modele.rotation.y), 0.0, cos(_modele.rotation.y))


## 0 : normal ; 1 : rouge vif (il va frapper).
func _teinte(v: float) -> void:
	if v <= 0.0 and _flash.emission == Color.WHITE and _flash.emission_energy_multiplier > 0.05:
		return  # éclair blanc d'un coup reçu en cours
	_flash.emission = Color(1.0, 0.15, 0.05)
	_flash.emission_energy_multiplier = clampf(v, 0.0, 1.0) * 1.2


func _secouer_camera(force: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("secouer"):
		camera.secouer(force)


# --- Construction -------------------------------------------------------------

## Le modèle du garde, en géant : armure rouge sang, cornes dorées, yeux qui brillent.
func _construire_modele() -> void:
	_modele = load("res://scenes/characters/garde_modele.tscn").instantiate()
	_modele.scale = Vector3.ONE * 1.65
	add_child(_modele)
	_modele.set_process(false)  # animé par ce script, pas par anim_chibi
	_animations = _modele.get_node("Animations")
	var corps: MeshInstance3D = _modele.find_child("Garde", true, false)
	var base := corps.mesh.surface_get_material(0) as BaseMaterial3D
	_flash = base.duplicate() as StandardMaterial3D
	_flash.albedo_color = Color(1.35, 0.5, 0.45)
	_flash.emission_enabled = true
	_flash.emission = Color(1.0, 0.15, 0.05)
	_flash.emission_energy_multiplier = 0.0
	corps.material_override = _flash
	_peau.append(corps)
	var squelette: Skeleton3D = _modele.find_child("Squelette", true, false)
	var tete := BoneAttachment3D.new()
	tete.bone_name = "Tete"
	squelette.add_child(tete)
	var or_ := StandardMaterial3D.new()
	or_.albedo_color = Color("#d9a94e")
	or_.metallic = 0.8
	or_.roughness = 0.3
	var yeux := StandardMaterial3D.new()
	yeux.albedo_color = Color(1, 0.3, 0.1)
	yeux.emission_enabled = true
	yeux.emission = Color(1, 0.25, 0.05)
	yeux.emission_energy_multiplier = 4.0
	# la tête du modèle est à environ 0,2 au-dessus de l'os Tete (unités du maillage)
	for s in [-1.0, 1.0]:
		var corne := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.035
		cone.height = 0.2
		cone.radial_segments = 8
		corne.mesh = cone
		corne.material_override = or_
		corne.position = Vector3(s * 0.08, 0.27, 0.02)
		corne.rotation.z = -s * 0.5
		tete.add_child(corne)
		_peau.append(corne)
		var oeil := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.018
		sphere.height = 0.036
		oeil.mesh = sphere
		oeil.material_override = yeux
		oeil.position = Vector3(s * 0.045, 0.14, 0.1)
		tete.add_child(oeil)
		_peau.append(oeil)
	# gueule : éteinte, elle s'allume avant les flammes
	_gueule = StandardMaterial3D.new()
	_gueule.albedo_color = Color(0.25, 0.05, 0.02)
	_gueule.emission_enabled = true
	_gueule.emission = Color(1.0, 0.45, 0.1)
	_gueule.emission_energy_multiplier = 0.0
	var gueule := MeshInstance3D.new()
	var bouche := SphereMesh.new()
	bouche.radius = 0.045
	bouche.height = 0.05
	gueule.mesh = bouche
	gueule.material_override = _gueule
	gueule.position = Vector3(0, 0.08, 0.1)
	tete.add_child(gueule)
	_peau.append(gueule)
	# les boules de feu partent d'ici ; celle-ci reste cachée (préchauffage de sa matière)
	_flamme_cachee = MeshInstance3D.new()
	_flamme_cachee.mesh = FLAMME.maillage()
	_flamme_cachee.material_override = FLAMME.matiere()
	_flamme_cachee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flamme_cachee.scale = Vector3.ONE * 0.3
	_flamme_cachee.position = Vector3(0, 0.08, 0.2)
	_flamme_cachee.visible = false
	tete.add_child(_flamme_cachee)
	_aura = OmniLight3D.new()
	_aura.light_color = Color(1.0, 0.3, 0.15)
	_aura.omni_range = 4.0
	_aura.light_energy = 0.8
	_aura.position.y = 1.6
	add_child(_aura)
	_jouer("repos")


func _construire_onde() -> void:
	_onde = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE
	_onde.mesh = plan
	_onde_mat = ShaderMaterial.new()
	_onde_mat.shader = Shader.new()
	_onde_mat.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float fondu = 1.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float anneau = smoothstep(0.86, 0.96, r) * smoothstep(1.0, 0.97, r);
	ALBEDO = vec3(1.0, 0.25, 0.08) * (anneau * 2.2 + smoothstep(1.0, 0.0, r) * 0.08) * fondu;
}
"""
	_onde.material_override = _onde_mat
	_onde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_onde.position.y = 0.08
	_onde.visible = false
	add_child(_onde)
	# flèche au sol pendant l'élan
	_fleche = MeshInstance3D.new()
	var bande := PlaneMesh.new()
	bande.size = Vector2(1.2, portee_charge)
	bande.center_offset = Vector3(0, 0, portee_charge / 2.0)
	_fleche.mesh = bande
	var mf := ShaderMaterial.new()
	mf.shader = Shader.new()
	mf.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void fragment() {
	float bords = smoothstep(0.5, 0.3, abs(UV.x - 0.5));
	float vague = 0.6 + 0.4 * sin(UV.y * 18.0 + TIME * 14.0);
	ALBEDO = vec3(1.0, 0.18, 0.06) * bords * vague * 0.5;
}
"""
	_fleche.material_override = mf
	_fleche.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fleche.position.y = 0.07
	_fleche.visible = false
	add_child(_fleche)


## Sa grande épée (nodachi) dans la main droite, et la traînée rouge de son revers.
func _construire_epee() -> void:
	var squelette: Skeleton3D = _modele.find_child("Squelette", true, false)
	var main := BoneAttachment3D.new()
	main.bone_name = "AvantBrasD"
	squelette.add_child(main)
	_epee = Node3D.new()
	_epee.position = Vector3(0, -0.08, 0)  # le poing, au bout de l'avant-bras
	_epee.rotation.x = 0.5
	main.add_child(_epee)
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color("#1c1210")
	noir.roughness = 0.8
	var or_ := StandardMaterial3D.new()
	or_.albedo_color = Color("#d9a94e")
	or_.metallic = 0.8
	or_.roughness = 0.3
	_lame = StandardMaterial3D.new()
	_lame.albedo_color = Color("#dfe3ea")
	_lame.metallic = 0.4
	_lame.roughness = 0.25
	_lame.emission_enabled = true
	_lame.emission = Color(1.0, 0.12, 0.04)
	_lame.emission_energy_multiplier = 0.0
	# poignée (en unités du maillage : le géant est environ 2,3 fois plus grand)
	var poignee := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.2
	cyl.radial_segments = 8
	poignee.mesh = cyl
	poignee.material_override = noir
	poignee.rotation.x = PI / 2.0
	poignee.position.z = -0.03
	# garde (tsuba)
	var tsuba := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 0.035
	disque.bottom_radius = 0.035
	disque.height = 0.008
	disque.radial_segments = 12
	tsuba.mesh = disque
	tsuba.material_override = or_
	tsuba.rotation.x = PI / 2.0
	tsuba.position.z = 0.075
	# lame, longue et fine, qui rougit quand il la lève
	var lame := MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3(0.008, 0.032, 0.86)
	lame.mesh = boite
	lame.material_override = _lame
	lame.position.z = 0.51
	for m in [poignee, tsuba, lame]:
		_epee.add_child(m)
		_peau.append(m)
	# traînée de l'arc : un éventail rouge additif, bref
	_trainee = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE * portee_epee * 2.0
	_trainee.mesh = plan
	_trainee_mat = ShaderMaterial.new()
	_trainee_mat.shader = Shader.new()
	_trainee_mat.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float avance = 1.0;
uniform float fondu = 1.0;
uniform float portee = 3.0;
varying vec3 p;
void vertex() { p = VERTEX; }
void fragment() {
	float r = length(p.xz) / portee;
	float a = atan(p.x, p.z);
	float bout = mix(-1.25, 1.25, avance);
	float arc = smoothstep(bout - 1.8, bout, a) * step(a, bout + 0.05) * step(-1.3, a);
	float bande = smoothstep(0.3, 0.55, r) * smoothstep(1.0, 0.85, r);
	ALBEDO = vec3(1.0, 0.2, 0.06) * arc * arc * bande * 1.6 * fondu;
}
"""
	_trainee_mat.set_shader_parameter("portee", portee_epee)
	_trainee.material_override = _trainee_mat
	_trainee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trainee.position.y = 0.65  # hauteur du poing
	_trainee.visible = false
	add_child(_trainee)


## Barre de vie du seigneur, en haut de l'écran pendant le combat.
func _construire_barre() -> void:
	_barre = CanvasLayer.new()
	_barre.layer = 9
	_barre.visible = false
	add_child(_barre)
	_barre_vie = Control.new()
	_barre_vie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barre_vie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barre_vie.draw.connect(_dessiner_barre)
	_barre.add_child(_barre_vie)
	var nom := Label.new()
	nom.text = "鬼  SEIGNEUR ONI"
	nom.theme_type_variation = &"TitreParchemin"
	nom.add_theme_font_size_override("font_size", 30)
	nom.add_theme_color_override("font_color", Palette.WASHI)
	nom.add_theme_color_override("font_outline_color", Palette.NOIR)
	nom.add_theme_constant_override("outline_size", 8)
	nom.set_anchors_preset(Control.PRESET_CENTER_TOP)
	nom.position = Vector2(-300, 34)
	nom.custom_minimum_size = Vector2(600, 0)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barre.add_child(nom)


func _dessiner_barre() -> void:
	var largeur := 620.0
	var x := (_barre_vie.size.x - largeur) / 2.0
	var y := 84.0
	_barre_vie.draw_rect(Rect2(x - 4, y - 4, largeur + 8, 22), Palette.NOIR)
	_barre_vie.draw_rect(Rect2(x, y, largeur, 14), Color("#3a1210"))
	_barre_vie.draw_rect(Rect2(x, y, largeur * _vie_affichee, 14), Color("#f2c46a"))
	_barre_vie.draw_rect(Rect2(x, y, largeur * float(vie) / vie_max, 14), Palette.LAQUE)
	for k in range(1, vie_max):
		var gx := x + largeur * k / vie_max
		_barre_vie.draw_line(Vector2(gx, y), Vector2(gx, y + 14), Palette.NOIR, 2.0)
	_barre_vie.draw_rect(Rect2(x - 4, y - 4, largeur + 8, 22), Palette.OR, false, 2.0)
