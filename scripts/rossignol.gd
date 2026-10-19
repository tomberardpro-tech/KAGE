class_name Rossignol
extends Area3D
## Plancher rossignol : il grince quand on y marche debout, et les gardes proches viennent voir.
## Accroupi, on passe sans bruit.

@export var taille := Vector2(4, 4)  ## en mètres
@export var portee_bruit := 9.0
@export var intervalle := 0.7  ## secondes entre deux grincements

var _ninja: Ninja
var _horloge := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b is Ninja: _ninja = b)
	body_exited.connect(func(b): if b == _ninja: _ninja = null)
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(taille.x, 1.0, taille.y)
	forme.shape = boite
	forme.position.y = 0.5
	add_child(forme)
	_lattes()


func _physics_process(delta: float) -> void:
	_horloge = maxf(_horloge - delta, 0.0)
	if _ninja == null or _ninja.bloque or not _ninja.is_on_floor() or _ninja.accroupi:
		return
	if Vector2(_ninja.velocity.x, _ninja.velocity.z).length() < 1.0 or _horloge > 0.0:
		return
	_horloge = intervalle
	var niveau := get_tree().current_scene
	if niveau.has_method("bruit"):
		niveau.bruit(_ninja.global_position, portee_bruit, "Le plancher grince. Accroupis-toi (Ctrl) pour marcher sans bruit.")


## Lattes de bois plus claires, pour qu'on repère le plancher de loin.
func _lattes() -> void:
	var clair := StandardMaterial3D.new()
	clair.albedo_color = Color("#7a5c3e")
	clair.roughness = 0.6
	var fonce := StandardMaterial3D.new()
	fonce.albedo_color = Color("#4a3726")
	var nombre := maxi(int(taille.x / 0.5), 1)
	for i in nombre:
		var latte := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(taille.x / nombre - 0.04, 0.03, taille.y)
		b.material = clair if i % 2 == 0 else fonce
		latte.mesh = b
		latte.position = Vector3(-taille.x / 2.0 + (i + 0.5) * taille.x / nombre, 0.09, 0)
		add_child(latte)
