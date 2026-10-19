class_name Clochettes
extends Area3D
## Fil tendu bas, avec des clochettes : on saute par-dessus ou on le coupe (E).
## Si on le traverse, les clochettes sonnent et les gardes alentour viennent voir.

@export var longueur := 4.0  ## en mètres, le long de l'axe X local
@export var portee_bruit := 12.0

const HAUTEUR := 0.45

var intact := true
var _fil: MeshInstance3D
var _clochettes: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("interactifs")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_sur_entree)
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(longueur, 0.5, 0.3)  # au-dessus de 0,5 m, on passe en sautant
	forme.shape = boite
	forme.position.y = 0.25
	add_child(forme)
	_construire()


func texte_action() -> String:
	return "COUPER LE FIL"


func peut_interagir() -> bool:
	return intact


## Coupé à la main, sans bruit.
func interagir() -> void:
	if not intact:
		return
	intact = false
	Sons.jouer("coupe")
	_fil.visible = false
	for c in _clochettes:
		create_tween().tween_property(c, "position:y", 0.05, 0.3)


func _sur_entree(corps: Node3D) -> void:
	if not intact or not corps is Ninja:
		return
	intact = false
	Sons.jouer("clochettes")
	_fil.visible = false
	for c in _clochettes:
		var tween := create_tween()
		for k in 4:
			tween.tween_property(c, "rotation:z", 0.6 if k % 2 == 0 else -0.6, 0.08)
		tween.tween_property(c, "position:y", 0.05, 0.25)
	var niveau := get_tree().current_scene
	if niveau.has_method("bruit"):
		niveau.bruit(global_position, portee_bruit, "Les clochettes ! Saute par-dessus le fil ou coupe-le avec E.")


func _construire() -> void:
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color("#5a3e2b")
	var corde := StandardMaterial3D.new()
	corde.albedo_color = Palette.LAQUE
	corde.emission_enabled = true
	corde.emission = Palette.LAQUE
	corde.emission_energy_multiplier = 0.4  # visible même dans l'ombre
	var or_ := StandardMaterial3D.new()
	or_.albedo_color = Palette.OR
	or_.metallic = 0.6
	or_.emission_enabled = true
	or_.emission = Palette.OR
	or_.emission_energy_multiplier = 0.3
	for cote in [-1, 1]:
		var piquet := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.06
		cyl.height = 0.7
		cyl.material = bois
		piquet.mesh = cyl
		piquet.position = Vector3(cote * longueur / 2.0, 0.35, 0)
		add_child(piquet)
	_fil = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(longueur, 0.03, 0.03)
	b.material = corde
	_fil.mesh = b
	_fil.position.y = HAUTEUR
	add_child(_fil)
	var nombre := maxi(int(longueur / 1.0), 2)
	for i in nombre:
		var c := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.07
		s.height = 0.12
		s.material = or_
		c.mesh = s
		c.position = Vector3(-longueur / 2.0 + (i + 0.5) * longueur / nombre, HAUTEUR - 0.08, 0)
		add_child(c)
		_clochettes.append(c)
