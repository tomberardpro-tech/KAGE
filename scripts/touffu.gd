class_name Touffu
## Maillage de buisson touffu, de rayon 1 : une boule sombre au centre et des cartes de feuilles
## posées tout autour, tournées vers l'extérieur. Partagé par les buissons du décor et les cachettes.

static var _maillages := {}
static var _materiau: ShaderMaterial


static func maillage(variante := 0) -> ArrayMesh:
	if _maillages.has(variante):
		return _maillages[variante]
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 900 + variante
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# cœur : une boule aplatie, texturée au centre de la touffe (plein de feuilles)
	var anneaux := 6
	var cotes := 10
	for a in anneaux:
		for c in cotes:
			for d in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var phi := PI * float(a + d[0]) / anneaux
				var th := TAU * float(c + d[1]) / cotes
				var n := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				st.set_normal(n)
				st.set_uv(Vector2(0.5, 0.5) + Vector2(n.x, n.z) * 0.12)
				st.add_vertex(Vector3(n.x * 0.82, n.y * 0.62 + 0.05, n.z * 0.82))
	# cartes de feuilles : réparties sur la boule, plus nombreuses sur le dessus
	var cartes := 46
	for k in cartes:
		var y := hasard.randf_range(-0.25, 1.0)
		var th := hasard.randf() * TAU
		var r := sqrt(maxf(1.0 - y * y, 0.0))
		var dir := Vector3(cos(th) * r, y, sin(th) * r).normalized()
		var centre := Vector3(dir.x * 0.85, dir.y * 0.66 + 0.05, dir.z * 0.85)
		var taille := hasard.randf_range(0.65, 0.95)
		var haut := (Vector3.UP - dir * dir.y).normalized() if absf(dir.y) < 0.95 else Vector3.FORWARD
		var cote := dir.cross(haut).normalized()
		var tourne := hasard.randf() * TAU
		var u := cote.rotated(dir, tourne) * taille
		var v := haut.rotated(dir, tourne) * taille
		var coins := [centre - u - v, centre + u - v, centre + u + v, centre - u + v]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			# normale « de boule » : la lumière glisse doucement sur tout le buisson
			st.set_normal((coins[i] as Vector3).normalized().lerp(dir, 0.5).normalized())
			st.set_uv(uvs[i])
			st.add_vertex(coins[i])
	var m := st.commit()
	_maillages[variante] = m
	return m


static func materiau() -> ShaderMaterial:
	if _materiau == null:
		_materiau = ShaderMaterial.new()
		_materiau.shader = load("res://assets/shaders/buisson.gdshader")
		_materiau.set_shader_parameter("feuilles", load("res://assets/textures/feuilles.png"))
	return _materiau
