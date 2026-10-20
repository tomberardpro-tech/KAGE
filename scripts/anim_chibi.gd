extends Node3D
## Animation simple des modèles chibi : jambes et bras qui balancent en marchant,
## petit rebond, foulard qui flotte, pose de dash pour le ninja.
## Marche avec des pivots (modèles en pièces) ou avec un squelette dont les os
## portent les mêmes noms (modèles d'un seul tenant, voir blender_squelette.py).

@export var amplitude := 38.0  ## balancement des jambes en marche, en degrés
@export var cadence := 11.0

var _corps: CharacterBody3D
var _phase := 0.0
var _repos := {}  # rotation de départ de chaque pivot
var _squelette: Skeleton3D
var _os := {}  # nom -> [indice, rotation de repos, axe X du modèle vu par l'os]
var _angles := {}  # angle actuel de chaque os, en radians
var _entier := false  # modèle d'un seul tenant sans os : on anime le corps entier
var _ecrase := 0.0  # > 0 : écrasé (atterrissage), < 0 : étiré (saut)
var _ecrase_vit := 0.0
var _au_sol := true
var _vy_avant := 0.0
var _poses := {}  # os du modèle articulé -> angles actuels (degrés)
var _t := 0.0

@onready var _jambes := [get_node_or_null("JambeG"), get_node_or_null("JambeD")]
@onready var _bras := [get_node_or_null("BrasG"), get_node_or_null("BrasD")]
@onready var _tronc: Node3D = get_node_or_null("Corps")
@onready var _tete: Node3D = get_node_or_null("Tete")
@onready var _pans: Node3D = get_node_or_null("Foulard/Pans")


func _ready() -> void:
	var n := get_parent()
	while n and not n is CharacterBody3D:
		n = n.get_parent()
	_corps = n
	for pivot in _jambes + _bras + [_tronc, _tete, _pans]:
		if pivot:
			_repos[pivot] = pivot.rotation
	var squelettes := find_children("*", "Skeleton3D", true, false)
	if not squelettes.is_empty():
		_squelette = squelettes[0]
		for nom in ["JambeG", "JambeD", "BrasG", "BrasD", "Corps", "Tete"]:
			var i := _squelette.find_bone(nom)
			if i >= 0:
				var axe := _squelette.get_bone_global_rest(i).basis.inverse() * Vector3.RIGHT
				_os[nom] = [i, _squelette.get_bone_pose_rotation(i), axe.normalized()]
				_angles[nom] = 0.0
	_entier = _squelette == null and _jambes[0] == null and _tronc == null


func _process(delta: float) -> void:
	if _corps == null:
		return
	if _corps.get("etat") == 3:  # garde mort : on ne bouge plus
		return
	var vitesse := Vector2(_corps.velocity.x, _corps.velocity.z).length()
	var marche := clampf(vitesse / 3.0, 0.0, 1.0)
	_phase += delta * cadence * clampf(vitesse / 3.0, 0.4, 1.4) if vitesse > 0.2 else 0.0
	var s := sin(_phase) * marche
	var dash: bool = _corps.get("en_dash") == true
	var lissage := 1.0 - exp(-14.0 * delta)
	if _entier:
		_animer_entier(delta, marche, dash, lissage)
		return
	if _squelette and _squelette.find_bone("GenouG") >= 0:
		_animer_articule(delta, vitesse, marche, dash)
		return

	for i in 2:
		var signe := 1.0 if i == 0 else -1.0
		if _jambes[i]:
			var cible: Vector3 = _repos[_jambes[i]] + Vector3(deg_to_rad(amplitude * s * signe), 0, 0)
			if dash:
				cible = _repos[_jambes[i]] + Vector3(deg_to_rad(-40.0 if i == 0 else 35.0), 0, 0)
			_jambes[i].rotation = _jambes[i].rotation.lerp(cible, lissage)
		if _bras[i]:
			var cible_bras: Vector3 = _repos[_bras[i]] + Vector3(deg_to_rad(-amplitude * 0.8 * s * signe), 0, 0)
			if dash:
				cible_bras = _repos[_bras[i]] + Vector3(deg_to_rad(70.0), 0, 0)
			_bras[i].rotation = _bras[i].rotation.lerp(cible_bras, lissage)

	if _squelette:
		_animer_os(s, dash, marche, lissage)

	# Petit rebond et penché en avant pendant la course et le dash
	position.y = absf(sin(_phase)) * 0.04 * marche
	if _tronc:
		var penche := deg_to_rad(28.0 if dash else 6.0 * marche)
		_tronc.rotation.x = lerpf(_tronc.rotation.x, _repos[_tronc].x + penche, lissage)
	if _tete:
		_tete.rotation.x = lerpf(_tete.rotation.x, _repos[_tete].x + (0.15 if dash else 0.0), lissage)
	if _pans:
		var t := Time.get_ticks_msec() / 1000.0
		var vent := deg_to_rad(sin(t * 7.0) * (6.0 + 14.0 * marche))
		var leve := deg_to_rad(-25.0 * marche - (30.0 if dash else 0.0))
		_pans.rotation = _repos[_pans] + Vector3(leve, vent, 0)


## Même balancement que les pivots, appliqué aux os du squelette.
func _animer_os(s: float, dash: bool, marche: float, lissage: float) -> void:
	var cibles := {
		"JambeG": -40.0 if dash else amplitude * s,
		"JambeD": 35.0 if dash else -amplitude * s,
		"BrasG": 70.0 if dash else -amplitude * 0.8 * s,
		"BrasD": 70.0 if dash else amplitude * 0.8 * s,
		"Corps": 28.0 if dash else 6.0 * marche,
		"Tete": 8.0 if dash else 0.0,
	}
	for nom in _os:
		var o: Array = _os[nom]
		_angles[nom] = lerpf(_angles[nom], deg_to_rad(cibles[nom]), lissage)
		_squelette.set_bone_pose_rotation(o[0], o[1] * Quaternion(o[2], _angles[nom]))


## Modèle sans os ni pivots : tout le corps se dandine en courant, s'étire en sautant
## et s'écrase à l'atterrissage, avec un ressort pour que ce soit fluide.
func _animer_entier(delta: float, marche: float, dash: bool, lissage: float) -> void:
	var au_sol := _corps.is_on_floor()
	var vy := _corps.velocity.y
	if au_sol and not _au_sol:
		_ecrase_vit += clampf(-_vy_avant * 0.6, 1.0, 4.0)  # atterrissage
	elif not au_sol and _au_sol and vy > 1.0:
		_ecrase_vit -= 2.2  # décollage
	_au_sol = au_sol
	_vy_avant = vy
	var cible := 0.0 if au_sol else -clampf(absf(vy) * 0.018, 0.0, 0.1)
	_ecrase_vit += (cible - _ecrase) * 260.0 * delta
	_ecrase_vit *= exp(-13.0 * delta)
	_ecrase = clampf(_ecrase + _ecrase_vit * delta, -0.25, 0.3)
	scale = Vector3(1.0 + _ecrase * 0.5, 1.0 - _ecrase, 1.0 + _ecrase * 0.5)

	var pas := absf(sin(_phase)) * marche if au_sol else 0.0
	position.y = lerpf(position.y, pas * 0.07, lissage)
	var penche := 30.0 if dash else 9.0 * marche + (0.0 if au_sol else 6.0)
	rotation.x = lerpf(rotation.x, deg_to_rad(penche), lissage)
	var dandine := sin(_phase) * 6.0 * marche if au_sol and not dash else 0.0
	rotation.z = lerpf(rotation.z, deg_to_rad(dandine), lissage)


## Modèle articulé (scripts/tools/articuler.gd) : vraie course jambes et bras opposés,
## genoux qui plient, saut groupé, chute bras écartés, dash penché bras en arrière,
## marche accroupie, respiration au repos. Tout est lissé pour passer d'une pose à l'autre.
## Angles en degrés autour de X : positif = le membre part vers l'arrière, le buste se penche en avant.
func _animer_articule(delta: float, vitesse: float, marche: float, dash: bool) -> void:
	_t += delta
	var au_sol := _corps.is_on_floor()
	var vy := _corps.velocity.y
	var accroupi: bool = _corps.get("accroupi") == true
	var c := {}  # pose visée : nom -> Vector3 (degrés)
	var s := sin(_phase)
	var genou_arriere := maxf(0.0, -cos(_phase))  # la jambe qui revient plie le genou
	var genou_avant := maxf(0.0, cos(_phase))
	if dash:
		c = {"Corps": Vector3(38, 0, 0), "Tete": Vector3(-22, 0, 0),
			"BrasG": Vector3(75, 0, 18), "BrasD": Vector3(75, 0, -18),
			"JambeG": Vector3(-45, 0, 0), "GenouG": Vector3(40, 0, 0),
			"JambeD": Vector3(55, 0, 0), "GenouD": Vector3(25, 0, 0), "Bassin": Vector3.ZERO}
	elif not au_sol and vy > 0.5:
		# Saut : jambes groupées, bras levés
		c = {"Corps": Vector3(-6, 0, 0), "Tete": Vector3(-8, 0, 0),
			"BrasG": Vector3(-130, 0, 25), "BrasD": Vector3(-130, 0, -25),
			"JambeG": Vector3(-55, 0, 0), "GenouG": Vector3(80, 0, 0),
			"JambeD": Vector3(15, 0, 0), "GenouD": Vector3(60, 0, 0), "Bassin": Vector3.ZERO}
	elif not au_sol:
		# Chute : bras écartés pour l'équilibre, jambes tendues vers le sol
		c = {"Corps": Vector3(4, 0, 0), "Tete": Vector3(6, 0, 0),
			"BrasG": Vector3(-20, 0, 70), "BrasD": Vector3(-20, 0, -70),
			"JambeG": Vector3(-20, 0, 6), "GenouG": Vector3(25, 0, 0),
			"JambeD": Vector3(10, 0, -6), "GenouD": Vector3(10, 0, 0), "Bassin": Vector3.ZERO}
	elif accroupi:
		# Marche de ninja accroupi : jambes pliées, petits pas, bras prêts
		var a := 25.0 * marche
		c = {"Corps": Vector3(22, 0, 0), "Tete": Vector3(-14, 0, 0),
			"BrasG": Vector3(-35 + a * s * 0.4, 0, 12), "BrasD": Vector3(-35 - a * s * 0.4, 0, -12),
			"JambeG": Vector3(-55 + a * s, 0, 4), "GenouG": Vector3(80 - 20.0 * genou_avant * marche, 0, 0),
			"JambeD": Vector3(-55 - a * s, 0, -4), "GenouD": Vector3(80 - 20.0 * genou_arriere * marche, 0, 0),
			"Bassin": Vector3.ZERO}
	elif marche > 0.05:
		# Course : jambes et bras opposés, buste qui tourne un peu, tête qui compense
		var a := 50.0 * marche
		c = {"Corps": Vector3(12 * marche, -9 * s * marche, 0), "Tete": Vector3(-8 * marche, 9 * s * marche, 0),
			"BrasG": Vector3(-a * 1.1 * s, 0, 10), "BrasD": Vector3(a * 1.1 * s, 0, -10),
			"JambeG": Vector3(a * s, 0, 0), "GenouG": Vector3(75.0 * genou_arriere * marche + 10.0, 0, 0),
			"JambeD": Vector3(-a * s, 0, 0), "GenouD": Vector3(75.0 * genou_avant * marche + 10.0, 0, 0),
			"Bassin": Vector3(0, 6 * s * marche, 0)}
	else:
		# Repos : il respire et balance doucement les bras
		var r := sin(_t * 2.2)
		c = {"Corps": Vector3(2 + r * 2.0, 0, 0), "Tete": Vector3(-r * 2.5, sin(_t * 0.7) * 6.0, 0),
			"BrasG": Vector3(r * 4.0, 0, 6 + r * 2.0), "BrasD": Vector3(-r * 4.0, 0, -6 - r * 2.0),
			"JambeG": Vector3.ZERO, "GenouG": Vector3.ZERO, "JambeD": Vector3.ZERO, "GenouD": Vector3.ZERO,
			"Bassin": Vector3.ZERO}
	var douceur := 1.0 - exp(-(22.0 if dash else 13.0) * delta)
	for nom in c:
		var i := _squelette.find_bone(nom)
		if i < 0:
			continue
		var actuel: Vector3 = _poses.get(nom, Vector3.ZERO)
		actuel = actuel.lerp(c[nom], douceur)
		_poses[nom] = actuel
		_squelette.set_bone_pose_rotation(i, Quaternion.from_euler(actuel * PI / 180.0))

	# Rebond des pas, écrasement à l'atterrissage et étirement au décollage (ressort)
	if au_sol and not _au_sol:
		_ecrase_vit += clampf(-_vy_avant * 0.6, 1.0, 4.0)
	elif not au_sol and _au_sol and vy > 1.0:
		_ecrase_vit -= 2.2
	_au_sol = au_sol
	_vy_avant = vy
	var cible := 0.0 if au_sol else -clampf(absf(vy) * 0.015, 0.0, 0.08)
	_ecrase_vit += (cible - _ecrase) * 260.0 * delta
	_ecrase_vit *= exp(-13.0 * delta)
	_ecrase = clampf(_ecrase + _ecrase_vit * delta, -0.2, 0.25)
	scale = Vector3(1.0 + _ecrase * 0.4, 1.0 - _ecrase * 0.8, 1.0 + _ecrase * 0.4)
	var pas := absf(cos(_phase)) * marche if au_sol and not accroupi else 0.0
	position.y = lerpf(position.y, pas * 0.06 - (0.12 if accroupi else 0.0), 1.0 - exp(-14.0 * delta))
