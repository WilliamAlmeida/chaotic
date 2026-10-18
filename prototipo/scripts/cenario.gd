class_name Cenario
extends RefCounted
## Cenografia das arenas: tudo o que fica FORA do raio jogável (Lutador.RAIO_ARENA) e o
## visual dos obstáculos por estilo. Só primitivas com material toon, montadas em código.
## Chamado por Batalha._criar_arena. Cada tema tem cor, silhueta e elemento próprios para
## uma criança reconhecer a arena de longe.

const RAIO_ARENA := 20.0
## Raio do terreno externo (um disco grande embaixo de tudo).
const RAIO_EXTERNO := 90.0
const SHADER_AGUA := """
shader_type spatial;
render_mode cull_disabled, unshaded;
uniform vec4 cor : source_color = vec4(0.15, 0.45, 0.8, 1.0);
uniform vec4 cor_clara : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float alfa = 0.9;
uniform float amplitude = 0.18;
varying vec3 pos_local;
void vertex() {
	pos_local = VERTEX;
	VERTEX.y += sin(VERTEX.x * 0.35 + TIME * 1.3) * amplitude + cos(VERTEX.z * 0.3 + TIME * 0.9) * amplitude;
}
void fragment() {
	float onda = sin(pos_local.x * 0.35 + TIME * 1.3) * 0.5 + cos(pos_local.z * 0.3 + TIME * 0.9) * 0.5;
	float crista = step(0.75, onda);
	ALBEDO = mix(cor.rgb, cor_clara.rgb, crista);
	ALPHA = alfa;
}
"""

static var _shader_agua: Shader


# ---------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------

## Monta a cenografia do local e devolve o nó raiz (filho de `pai`).
static func decorar(pai: Node3D, local: Dictionary) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Cenografia"
	pai.add_child(raiz)
	var tema := str(local.get("tema", local.get("id", "")))
	var gerador := RandomNumberGenerator.new()
	gerador.seed = hash(tema)
	var cor_chao := Color(str(local.get("cor_chao", "#777777")))
	match tema:
		"caldeira":
			_chao_externo(raiz, Color("#2a1714"))
			_caldeira(raiz, gerador)
		"terraco":
			_chao_externo(raiz, Color("#1d3f52"), -1.4)
			_terraco(raiz, gerador)
		"pedreira":
			_chao_externo(raiz, cor_chao.darkened(0.2))
			_pedreira(raiz, gerador)
		"dunas":
			_chao_externo(raiz, Color("#a9793a"))
			_dunas(raiz, gerador, false)
		"jardim":
			_chao_externo(raiz, Color("#26343a"))
			_jardim(raiz, gerador)
		"patio":
			_chao_externo(raiz, Color("#8d8676"))
			_patio(raiz, gerador)
		"bosque":
			_chao_externo(raiz, Color("#2f4a24"))
			_bosque(raiz, gerador)
		"forja":
			_chao_externo(raiz, Color("#2c2530"), -1.4)
			_forja(raiz, gerador)
		"espiral":
			_chao_externo(raiz, Color("#3a4756"))
			_espiral(raiz, gerador)
		"rota":
			_chao_externo(raiz, Color("#8a6632"))
			_dunas(raiz, gerador, true)
		"fenda":
			_chao_externo(raiz, Color("#0d0814"))
			_fenda(raiz, gerador)
		_:
			_chao_externo(raiz, cor_chao.darkened(0.3))
			_pedreira(raiz, gerador)
	return raiz


## Visual de um obstáculo jogável (o corpo e a colisão são criados pela Batalha).
static func construir_obstaculo(corpo: Node3D, raio: float, altura: float, estilo: String, cor_chao: Color) -> void:
	match estilo:
		"arvore":
			_obstaculo_arvore(corpo, raio, altura)
		"pilar":
			_obstaculo_pilar(corpo, raio, altura)
		"cristal":
			_obstaculo_cristal(corpo, raio, altura)
		"metal":
			_obstaculo_metal(corpo, raio, altura)
		"corrompido":
			_obstaculo_corrompido(corpo, raio, altura)
		_:
			_obstaculo_rocha(corpo, raio, altura, cor_chao)


# ---------------------------------------------------------------------
# Obstáculos por estilo
# ---------------------------------------------------------------------

static func _obstaculo_rocha(corpo: Node3D, raio: float, altura: float, cor_chao: Color) -> void:
	var tronco := _cilindro(raio * 0.45, raio, altura, 10)
	_malha(corpo, tronco, Efeitos.material_toon(cor_chao.lightened(0.15)), Vector3(0, altura / 2.0, 0))
	# Uma lasca menor encostada dá silhueta de rocha, não de cone.
	var lasca := _cilindro(raio * 0.2, raio * 0.55, altura * 0.55, 7)
	_malha(corpo, lasca, Efeitos.material_toon(cor_chao.lightened(0.25)), Vector3(raio * 0.7, altura * 0.27, raio * 0.3), Vector3(0, 0, 0.25))


static func _obstaculo_pilar(corpo: Node3D, raio: float, altura: float) -> void:
	_malha(corpo, _cilindro(raio, raio, altura, 14), Efeitos.material_toon(Color(0.85, 0.85, 0.8)), Vector3(0, altura / 2.0, 0))
	_malha(corpo, _caixa(Vector3(raio * 2.6, 0.4, raio * 2.6)), Efeitos.material_toon(Color(0.9, 0.9, 0.85)), Vector3(0, altura, 0))
	_malha(corpo, _caixa(Vector3(raio * 2.4, 0.3, raio * 2.4)), Efeitos.material_toon(Color(0.8, 0.8, 0.75)), Vector3(0, 0.15, 0))


static func _obstaculo_arvore(corpo: Node3D, raio: float, altura: float) -> void:
	_malha(corpo, _cilindro(raio * 0.6, raio * 0.8, altura, 10), Efeitos.material_toon(Color(0.4, 0.27, 0.16)), Vector3(0, altura / 2.0, 0))
	var copa := SphereMesh.new()
	copa.radius = raio * 2.1
	copa.height = raio * 3.0
	_malha(corpo, copa, Efeitos.material_toon(Color(0.22, 0.5, 0.25)), Vector3(0, altura + raio * 0.6, 0))
	var copa2 := SphereMesh.new()
	copa2.radius = raio * 1.4
	copa2.height = raio * 2.2
	_malha(corpo, copa2, Efeitos.material_toon(Color(0.3, 0.6, 0.3)), Vector3(raio * 0.9, altura + raio * 1.4, raio * 0.4))


static func _obstaculo_cristal(corpo: Node3D, raio: float, altura: float) -> void:
	# A cor alterna entre magenta e ciano conforme a posição, para cada cristal ser diferente.
	var par := int(absf(corpo.position.x * 3.0 + corpo.position.z * 7.0)) % 2 == 0
	var cor := Color("#d070ff") if par else Color("#6fe6ff")
	var mat := Efeitos.material_toon(cor, 0.35)
	_malha(corpo, _cilindro(raio * 0.3, raio, altura, 6), mat, Vector3(0, altura / 2.0, 0))
	var ponta := _cilindro(0.0, raio * 0.3, altura * 0.35, 6)
	_malha(corpo, ponta, mat, Vector3(0, altura + altura * 0.17, 0))
	var lateral := _cilindro(0.0, raio * 0.45, altura * 0.6, 6)
	_malha(corpo, lateral, Efeitos.material_toon(cor.lightened(0.2), 0.35), Vector3(raio * 0.8, altura * 0.25, -raio * 0.3), Vector3(0.1, 0, -0.5))
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 0.6
	luz.omni_range = raio * 5.0
	luz.position.y = altura * 0.7
	corpo.add_child(luz)


static func _obstaculo_metal(corpo: Node3D, raio: float, altura: float) -> void:
	var ferro := Efeitos.material_toon(Color("#5a5c66"))
	_malha(corpo, _cilindro(raio, raio, altura, 12), ferro, Vector3(0, altura / 2.0, 0))
	_malha(corpo, _cilindro(raio * 1.15, raio * 1.15, 0.3, 12), Efeitos.material_toon(Color("#3d3f47")), Vector3(0, altura - 0.15, 0))
	_malha(corpo, _cilindro(raio * 1.15, raio * 1.15, 0.3, 12), Efeitos.material_toon(Color("#3d3f47")), Vector3(0, 0.15, 0))
	# Faixa quente no meio: a forja ainda está acesa.
	var anel := TorusMesh.new()
	anel.inner_radius = raio * 0.98
	anel.outer_radius = raio * 1.08
	_malha(corpo, anel, Efeitos.material(Color("#ff7a2a"), 1.6, 1.0, true), Vector3(0, altura * 0.5, 0))
	for i in 4:
		var ang := TAU * i / 4.0
		var rebite := SphereMesh.new()
		rebite.radius = raio * 0.12
		rebite.height = raio * 0.24
		_malha(corpo, rebite, Efeitos.material_toon(Color("#8d8f99"), 0.0, false), Vector3(cos(ang) * raio, altura * 0.8, sin(ang) * raio))


static func _obstaculo_corrompido(corpo: Node3D, raio: float, altura: float) -> void:
	var lado := raio * 1.5
	var cubo := _malha(corpo, _caixa(Vector3(lado, altura, lado)), Efeitos.material_toon(Color("#120a1e")), Vector3(0, altura / 2.0, 0), Vector3(0, PI / 4.0, 0))
	var nucleo := _malha(corpo, _caixa(Vector3(lado * 0.55, altura * 0.55, lado * 0.55)), Efeitos.material(Color("#b45bff"), 2.0, 1.0, true), Vector3(0, altura / 2.0, 0), Vector3(0.6, 0.4, 0.3))
	var anel := TorusMesh.new()
	anel.inner_radius = lado * 0.9
	anel.outer_radius = lado * 0.98
	var mi_anel := _malha(corpo, anel, Efeitos.material(Color("#d9b3ff"), 2.2, 1.0, true), Vector3(0, altura * 0.5, 0))
	_girar(nucleo, 3.0)
	_girar(mi_anel, 6.0)
	var tw := cubo.create_tween().set_loops()
	tw.tween_property(mi_anel, "position:y", altura * 0.85, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mi_anel, "position:y", altura * 0.15, 1.6).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------
# Temas
# ---------------------------------------------------------------------

## Caldeira Rubra: vulcão ao fundo, rochas escuras, poças de lava brilhantes e fumaça.
static func _caldeira(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var escuro := Efeitos.material_toon(Color("#3a2320"))
	var lava := Efeitos.material(Color("#ff5a14"), 1.4)
	# Vulcão grande no horizonte.
	_malha(raiz, _cilindro(6.0, 30.0, 26.0, 16), Efeitos.material_toon(Color("#331c18")), Vector3(0, 12.5, -72))
	_malha(raiz, _cilindro(6.5, 6.5, 0.6, 16), lava, Vector3(0, 25.6, -72))
	for i in 3:
		_fumaca(raiz, Vector3(g.randf_range(-3, 3), 26.0, -72 + g.randf_range(-3, 3)), 5.0, Color(0.35, 0.3, 0.3), g)
	# Paredão da cratera: rochas altas em volta.
	for i in 30:
		var ang := TAU * i / 30.0 + g.randf_range(-0.08, 0.08)
		var r := g.randf_range(27.0, 36.0)
		var h := g.randf_range(3.0, 9.0)
		var rocha := _cilindro(g.randf_range(0.6, 2.0), g.randf_range(2.5, 4.5), h, 7)
		_malha(raiz, rocha, escuro, Vector3(cos(ang) * r, h / 2.0 - 0.5, sin(ang) * r), Vector3(g.randf_range(-0.15, 0.15), g.randf() * TAU, g.randf_range(-0.15, 0.15)))
	# Poças de lava entre as rochas, com fumaça subindo.
	for i in 10:
		var ang := TAU * i / 10.0 + 0.3
		var r := g.randf_range(24.0, 30.0)
		var pos := Vector3(cos(ang) * r, -0.4, sin(ang) * r)
		_malha(raiz, _cilindro(2.6, 2.6, 0.2, 18), lava, pos)
		var luz := OmniLight3D.new()
		luz.light_color = Color("#ff7a30")
		luz.light_energy = 1.2
		luz.omni_range = 9.0
		luz.position = pos + Vector3(0, 1.5, 0)
		raiz.add_child(luz)
		if i % 2 == 0:
			_fumaca(raiz, pos, 2.2, Color(0.4, 0.33, 0.33), g)


## Terraço das Marés: água viva em volta, ruínas submersas e colunas quebradas.
static func _terraco(raiz: Node3D, g: RandomNumberGenerator) -> void:
	_agua(raiz, Color("#0d4f96"), Color("#cfefff"), -0.7, 180.0)
	var pedra := Efeitos.material_toon(Color("#b8c4c0"))
	var pedra_escura := Efeitos.material_toon(Color("#5f7d84"))
	for i in 18:
		var ang := TAU * i / 18.0 + g.randf_range(-0.1, 0.1)
		var r := g.randf_range(24.0, 34.0)
		var h := g.randf_range(1.5, 6.0)
		var pos := Vector3(cos(ang) * r, h / 2.0 - 1.0, sin(ang) * r)
		_malha(raiz, _cilindro(0.8, 0.9, h, 12), pedra if i % 3 else pedra_escura, pos, Vector3(g.randf_range(-0.25, 0.25), 0, g.randf_range(-0.25, 0.25)))
		if i % 4 == 0:
			# Pedaço de coluna caído ao lado.
			_malha(raiz, _cilindro(0.8, 0.8, 3.0, 12), pedra_escura, pos + Vector3(2.0, -h / 2.0 + 0.2, 1.0), Vector3(0, g.randf() * TAU, PI / 2.0))
	# Arcos de uma muralha submersa.
	for i in 5:
		var ang := -0.6 + i * 0.3
		var r := 40.0
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		_arco(raiz, pos, -ang + PI / 2.0, 7.0, 4.0, pedra)
	# Pedras de maré rasas (cabeças de rocha à flor d'água).
	for i in 24:
		var ang := g.randf() * TAU
		var r := g.randf_range(23.0, 60.0)
		var esfera := SphereMesh.new()
		esfera.radius = g.randf_range(0.8, 2.0)
		esfera.height = esfera.radius
		_malha(raiz, esfera, Efeitos.material_toon(Color("#1c3038")), Vector3(cos(ang) * r, -0.5, sin(ang) * r))


## Pedreira Viva: cristais, blocos empilhados e paredões de pedra.
static func _pedreira(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var pedra := Efeitos.material_toon(Color("#7d7462"))
	var pedra_clara := Efeitos.material_toon(Color("#9a8f78"))
	var cristal := Efeitos.material_toon(Color("#f0c890"), 0.5)
	for i in 14:
		var ang := TAU * i / 14.0
		var r := g.randf_range(25.0, 32.0)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		# Pilha de blocos.
		var n := g.randi_range(2, 4)
		for j in n:
			var tam := Vector3(g.randf_range(2.0, 3.4), g.randf_range(1.2, 2.0), g.randf_range(2.0, 3.4))
			_malha(raiz, _caixa(tam), pedra_clara if j % 2 else pedra, pos + Vector3(g.randf_range(-0.4, 0.4), 0.0, g.randf_range(-0.4, 0.4)), Vector3(0, g.randf_range(-0.3, 0.3), 0))
			pos.y += tam.y
		if i % 2 == 0:
			var h := g.randf_range(2.5, 5.0)
			_malha(raiz, _cilindro(0.0, g.randf_range(0.6, 1.1), h, 6), cristal, Vector3(pos.x + 2.5, h / 2.0 - 0.3, pos.z), Vector3(g.randf_range(-0.3, 0.3), 0, g.randf_range(-0.3, 0.3)))
	# Paredão de fundo.
	for i in 12:
		var ang := TAU * i / 12.0 + 0.2
		var h := g.randf_range(10.0, 18.0)
		_malha(raiz, _caixa(Vector3(14.0, h, 8.0)), pedra, Vector3(cos(ang) * 48.0, h / 2.0 - 1.0, sin(ang) * 48.0), Vector3(0, -ang + PI / 2.0, 0))


## Dunas de Vidro (e Rota das Tempestades, com `tempestade`): dunas, pilares de vidro, cactos e poeira.
static func _dunas(raiz: Node3D, g: RandomNumberGenerator, tempestade: bool) -> void:
	var areia := Efeitos.material_toon(Color("#9c7236") if tempestade else Color("#bf8a42"), 0.0, false)
	var vidro := Efeitos.material(Color("#4fc8ff"), 0.7, 0.85)
	var cacto := Efeitos.material_toon(Color("#4f8f35"))
	for i in 16:
		var ang := TAU * i / 16.0 + g.randf_range(-0.1, 0.1)
		var r := g.randf_range(37.0, 56.0)
		var duna := SphereMesh.new()
		duna.radius = g.randf_range(6.0, 11.0)
		duna.height = duna.radius * g.randf_range(0.25, 0.4)
		_malha(raiz, duna, areia, Vector3(cos(ang) * r, -0.6, sin(ang) * r), Vector3(0, g.randf() * TAU, 0), Vector3(1.0, 1.0, g.randf_range(0.6, 1.0)))
	for i in 9:
		var ang := TAU * i / 9.0 + 0.4
		var r := g.randf_range(23.5, 29.0)
		var h := g.randf_range(3.0, 7.0)
		_malha(raiz, _cilindro(g.randf_range(0.3, 0.6), g.randf_range(0.7, 1.1), h, 6), vidro, Vector3(cos(ang) * r, h / 2.0 - 0.4, sin(ang) * r), Vector3(g.randf_range(-0.2, 0.2), 0, g.randf_range(-0.2, 0.2)))
	for i in 7:
		var ang := TAU * i / 7.0 + 1.1
		var r := g.randf_range(24.0, 31.0)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var h := g.randf_range(2.0, 3.2)
		_malha(raiz, _cilindro(0.45, 0.5, h, 8), cacto, pos + Vector3(0, h / 2.0 - 0.4, 0))
		_malha(raiz, _cilindro(0.3, 0.3, 1.3, 8), cacto, pos + Vector3(0.8, h * 0.6, 0), Vector3(0, 0, PI / 2.0))
		_malha(raiz, _cilindro(0.3, 0.3, 1.2, 8), cacto, pos + Vector3(1.3, h * 0.6 + 0.6, 0))
	# Poeira que anda com o vento.
	var cor_poeira := Color("#c9a35a") if tempestade else Color("#e6c98a")
	for i in (14 if tempestade else 6):
		var p := SphereMesh.new()
		p.radius = 1.0
		p.height = 2.0
		var mi := _malha(raiz, p, Efeitos.material(cor_poeira, 0.1, 0.28, true), Vector3(g.randf_range(-30, 30), g.randf_range(1.0, 4.0), g.randf_range(-30, 30)), Vector3.ZERO, Vector3(g.randf_range(3.0, 7.0), g.randf_range(1.5, 3.0), g.randf_range(3.0, 7.0)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_deslizar(mi, Vector3(1.0, 0.0, 0.35).normalized() * (22.0 if tempestade else 10.0), 70.0, g)
	if tempestade:
		# Nuvens de tempestade baixas e postes tortos de uma rota abandonada.
		var nuvem := Efeitos.material(Color("#3f3d52"), 0.0, 0.92)
		for i in 10:
			var ang := TAU * i / 10.0
			var n := SphereMesh.new()
			n.radius = 1.0
			n.height = 2.0
			var mi := _malha(raiz, n, nuvem, Vector3(cos(ang) * 62.0, 30.0, sin(ang) * 62.0), Vector3.ZERO, Vector3(16.0, 5.0, 12.0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_deslizar(mi, Vector3(6.0, 0.0, 2.0), 50.0, g)
		var madeira := Efeitos.material_toon(Color("#5a4028"))
		for i in 6:
			var ang := TAU * i / 6.0 + 0.2
			var pos := Vector3(cos(ang) * 26.0, 0.0, sin(ang) * 26.0)
			_malha(raiz, _cilindro(0.18, 0.22, 4.5, 6), madeira, pos + Vector3(0, 1.8, 0), Vector3(0.25, 0, 0.1))
			_malha(raiz, _caixa(Vector3(1.6, 0.5, 0.1)), Efeitos.material_toon(Color("#e7b928")), pos + Vector3(0.4, 3.6, 0.3), Vector3(0.25, 0.4, 0.1))
		# Relâmpago distante que acende e apaga.
		var luz := DirectionalLight3D.new()
		luz.light_color = Color("#cfe6ff")
		luz.light_energy = 0.0
		luz.rotation_degrees = Vector3(-30, 120, 0)
		raiz.add_child(luz)
		var tw := luz.create_tween().set_loops()
		tw.tween_interval(g.randf_range(4.0, 7.0))
		tw.tween_property(luz, "light_energy", 1.4, 0.05)
		tw.tween_property(luz, "light_energy", 0.0, 0.25)
		tw.tween_property(luz, "light_energy", 0.9, 0.05)
		tw.tween_property(luz, "light_energy", 0.0, 0.4)


## Jardim dos Condutores: pilares metálicos com anéis que brilham, cabos e faíscas.
static func _jardim(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var metal := Efeitos.material_toon(Color("#6e7f8a"))
	var metal_escuro := Efeitos.material_toon(Color("#3f4b54"))
	var topos: Array[Vector3] = []
	for i in 12:
		var ang := TAU * i / 12.0
		var r := 26.0 if i % 2 == 0 else 34.0
		var h := g.randf_range(7.0, 13.0)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		_malha(raiz, _cilindro(0.5, 0.7, h, 10), metal, pos + Vector3(0, h / 2.0 - 0.4, 0))
		_malha(raiz, _caixa(Vector3(2.4, 0.6, 2.4)), metal_escuro, pos + Vector3(0, -0.2, 0))
		var topo := pos + Vector3(0, h, 0)
		topos.append(topo)
		_malha(raiz, SphereMesh.new(), Efeitos.material(Color("#9fe3ff"), 2.0, 1.0, true), topo, Vector3.ZERO, Vector3.ONE * 0.9)
		var luz := OmniLight3D.new()
		luz.light_color = Color("#9fe3ff")
		luz.light_energy = 1.0
		luz.omni_range = 10.0
		luz.position = topo
		raiz.add_child(luz)
		for j in 3:
			var anel := TorusMesh.new()
			anel.inner_radius = 0.9
			anel.outer_radius = 1.1
			var mi := _malha(raiz, anel, Efeitos.material(Color("#7fd4ff"), 1.6, 1.0, true), pos + Vector3(0, h * (0.3 + 0.2 * j), 0))
			_pulsar(mi, 1.0 + 0.3 * j, g)
	# Cabos ligando os topos dos pilares vizinhos.
	for i in topos.size():
		_cabo(raiz, topos[i], topos[(i + 1) % topos.size()], metal_escuro)
	# Faíscas flutuantes.
	for i in 10:
		var ang := g.randf() * TAU
		var r := g.randf_range(22.0, 36.0)
		var f := SphereMesh.new()
		f.radius = 0.18
		f.height = 0.36
		var mi := _malha(raiz, f, Efeitos.material(Color("#dff6ff"), 2.5, 1.0, true), Vector3(cos(ang) * r, g.randf_range(1.0, 5.0), sin(ang) * r))
		_flutuar(mi, g.randf_range(0.5, 1.5), g.randf_range(1.0, 2.5))


## Pátio do Primeiro Eco: arquibancadas, arcos e as bandeiras das quatro facções.
static func _patio(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var pedra := Efeitos.material_toon(Color("#c9bfa8"))
	var pedra_escura := Efeitos.material_toon(Color("#a89e88"))
	# Arquibancadas em degraus, em quatro blocos com passagens entre eles.
	for bloco in 4:
		var ang0 := TAU * bloco / 4.0 + 0.25
		for degrau in 4:
			var r := 24.5 + degrau * 2.2
			var h := 1.0 + degrau * 1.1
			var segmentos := 7
			for s in segmentos:
				var ang := ang0 + (s + 0.5) / float(segmentos) * (TAU / 4.0 - 0.5)
				_malha(raiz, _caixa(Vector3(r * (TAU / 4.0 - 0.5) / segmentos + 0.1, h, 2.2)), pedra if degrau % 2 else pedra_escura, Vector3(cos(ang) * r, h / 2.0 - 0.5, sin(ang) * r), Vector3(0, -ang + PI / 2.0, 0))
		# Arco de entrada entre os blocos.
		var ang_arco := TAU * bloco / 4.0
		_arco(raiz, Vector3(cos(ang_arco) * 25.5, 0.0, sin(ang_arco) * 25.5), -ang_arco + PI / 2.0, 5.0, 5.0, pedra)
	# Bandeiras das facções em mastros altos.
	var ids := ["cinzas", "mares", "rocha", "areia"]
	for i in ids.size():
		var fac: Dictionary = Dados.faccao(ids[i])
		var ang := TAU * i / 4.0 + PI / 4.0
		var pos := Vector3(cos(ang) * 31.5, 0.0, sin(ang) * 31.5)
		_bandeira(raiz, pos, Color(str(fac.get("cor", "#ffffff"))), Color(str(fac.get("cor_clara", "#ffffff"))), 9.0, g)
	# Espectadores: esferas coloridas nos degraus (silhuetas simples).
	for i in 60:
		var ang := g.randf() * TAU
		var degrau := g.randi_range(0, 3)
		var r := 24.5 + degrau * 2.2
		var h := 1.0 + degrau * 1.1
		var esfera := SphereMesh.new()
		esfera.radius = 0.4
		esfera.height = 0.8
		var tom := Color.from_hsv(g.randf(), 0.55, 0.9)
		var mi := _malha(raiz, esfera, Efeitos.material_toon(tom, 0.0, false), Vector3(cos(ang) * r, h, sin(ang) * r))
		_flutuar(mi, 0.15, g.randf_range(0.6, 1.2))


## Bosque Sussurrante: árvores em volta, cogumelos e arbustos.
static func _bosque(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var tronco := Efeitos.material_toon(Color("#5a3b22"))
	var copas := [Efeitos.material_toon(Color("#2f7a3a")), Efeitos.material_toon(Color("#4a9a40")), Efeitos.material_toon(Color("#237a5a"))]
	for i in 26:
		var ang := TAU * i / 26.0 + g.randf_range(-0.08, 0.08)
		var r := g.randf_range(24.0, 40.0)
		var h := g.randf_range(5.0, 10.0)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		_malha(raiz, _cilindro(0.5, 0.8, h, 8), tronco, pos + Vector3(0, h / 2.0 - 0.4, 0))
		var copa := SphereMesh.new()
		copa.radius = g.randf_range(2.6, 4.0)
		copa.height = copa.radius * 1.6
		_malha(raiz, copa, copas[i % 3], pos + Vector3(0, h + copa.radius * 0.4, 0))
		var copa2 := SphereMesh.new()
		copa2.radius = copa.radius * 0.7
		copa2.height = copa2.radius * 1.5
		_malha(raiz, copa2, copas[(i + 1) % 3], pos + Vector3(copa.radius * 0.6, h + copa.radius * 0.9, copa.radius * 0.2))
	# Cogumelos coloridos, com pintinhas.
	for i in 12:
		var ang := g.randf() * TAU
		var r := g.randf_range(22.5, 30.0)
		var pos := Vector3(cos(ang) * r, -0.5, sin(ang) * r)
		var h := g.randf_range(0.8, 2.0)
		_malha(raiz, _cilindro(0.3, 0.4, h, 8), Efeitos.material_toon(Color("#f0e6c8")), pos + Vector3(0, h / 2.0, 0))
		var chapeu := SphereMesh.new()
		chapeu.radius = h * 0.8
		chapeu.height = h * 0.8
		var cor := Color("#e0452b") if i % 2 == 0 else Color("#6f5bd6")
		_malha(raiz, chapeu, Efeitos.material_toon(cor), pos + Vector3(0, h, 0))
		for j in 3:
			var pinta := SphereMesh.new()
			pinta.radius = h * 0.12
			pinta.height = h * 0.24
			var a := g.randf() * TAU
			_malha(raiz, pinta, Efeitos.material_toon(Color.WHITE, 0.0, false), pos + Vector3(cos(a) * h * 0.5, h + h * 0.25, sin(a) * h * 0.5))
	# Arbustos.
	for i in 16:
		var ang := g.randf() * TAU
		var r := g.randf_range(22.5, 34.0)
		var a := SphereMesh.new()
		a.radius = g.randf_range(0.9, 1.6)
		a.height = a.radius * 1.4
		_malha(raiz, a, copas[i % 3], Vector3(cos(ang) * r, -0.3, sin(ang) * r))


## Forja Submersa: lava e água lado a lado, bigornas, chaminés com fumaça e vapor.
static func _forja(raiz: Node3D, g: RandomNumberGenerator) -> void:
	_agua(raiz, Color("#0a4aa0"), Color("#c8ecff"), -0.8, 180.0)
	var ferro := Efeitos.material_toon(Color("#4a4c55"))
	var ferro_escuro := Efeitos.material_toon(Color("#2e3038"))
	var lava := Efeitos.material(Color("#ff5a14"), 1.4)
	# Passarelas de ferro saindo da arena sobre a água.
	for i in 4:
		var ang := TAU * i / 4.0 + PI / 4.0
		_malha(raiz, _caixa(Vector3(4.0, 0.5, 16.0)), ferro_escuro, Vector3(cos(ang) * 30.0, -0.3, sin(ang) * 30.0), Vector3(0, -ang + PI / 2.0, 0))
	# Metade "Cinzas": rio de lava e chaminés. Metade "Marés": colunas submersas e vapor.
	for i in 6:
		var ang := -PI / 2.0 + TAU * i / 12.0 - PI / 4.0
		var r := g.randf_range(25.0, 32.0)
		var pos := Vector3(cos(ang) * r, -0.5, sin(ang) * r)
		_malha(raiz, _cilindro(3.0, 3.0, 0.5, 18), lava, pos)
		var luz := OmniLight3D.new()
		luz.light_color = Color("#ff7a30")
		luz.light_energy = 1.1
		luz.omni_range = 9.0
		luz.position = pos + Vector3(0, 1.5, 0)
		raiz.add_child(luz)
		var h := g.randf_range(6.0, 11.0)
		var cham := pos + Vector3(3.5, 0.0, 1.5)
		_malha(raiz, _cilindro(1.0, 1.4, h, 10), ferro, cham + Vector3(0, h / 2.0, 0))
		_malha(raiz, _cilindro(1.3, 1.3, 0.6, 10), ferro_escuro, cham + Vector3(0, h, 0))
		_fumaca(raiz, cham + Vector3(0, h + 0.5, 0), 3.0, Color(0.3, 0.28, 0.3), g)
	for i in 8:
		var ang := PI / 2.0 + TAU * i / 16.0 - PI / 4.0
		var r := g.randf_range(24.0, 34.0)
		var h := g.randf_range(2.0, 6.0)
		var pos := Vector3(cos(ang) * r, h / 2.0 - 1.2, sin(ang) * r)
		_malha(raiz, _cilindro(0.9, 1.0, h, 12), Efeitos.material_toon(Color("#8fa5a3")), pos, Vector3(g.randf_range(-0.2, 0.2), 0, g.randf_range(-0.2, 0.2)))
		if i % 2 == 0:
			_fumaca(raiz, Vector3(pos.x + 1.5, 0.2, pos.z), 2.5, Color(0.9, 0.95, 1.0), g, 0.4)
	# Bigornas e engrenagens: a forja em si.
	for i in 5:
		var ang := TAU * i / 5.0 + 0.5
		var pos := Vector3(cos(ang) * 26.0, -0.5, sin(ang) * 26.0)
		_malha(raiz, _caixa(Vector3(2.2, 1.2, 1.0)), ferro_escuro, pos + Vector3(0, 0.6, 0), Vector3(0, -ang, 0))
		_malha(raiz, _caixa(Vector3(3.0, 0.6, 1.0)), ferro, pos + Vector3(0, 1.5, 0), Vector3(0, -ang, 0))
		var eng := TorusMesh.new()
		eng.inner_radius = 1.2
		eng.outer_radius = 1.9
		var mi := _malha(raiz, eng, ferro, pos + Vector3(0, 3.5, 2.5), Vector3(PI / 2.0, 0, 0))
		_girar(mi, 0.6)


## Espiral Mineral: plataformas de cristal que sobem em espiral e cristais gigantes.
static func _espiral(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var pedra := Efeitos.material_toon(Color("#55657a"))
	var cores := [Color("#d070ff"), Color("#6fe6ff"), Color("#ffd27f")]
	for i in 22:
		var t := i / 22.0
		var ang := t * TAU * 1.5
		var r := 24.0 + t * 20.0
		var h := 0.5 + t * 16.0
		var pos := Vector3(cos(ang) * r, h, sin(ang) * r)
		_malha(raiz, _caixa(Vector3(5.0, 1.0, 4.0)), pedra, pos, Vector3(0, -ang, 0))
		_malha(raiz, _cilindro(1.2, 1.6, h + 0.5, 8), pedra, Vector3(pos.x, h / 2.0 - 0.5, pos.z))
		var cor: Color = cores[i % 3]
		var ch := g.randf_range(2.0, 4.5)
		var mi := _malha(raiz, _cilindro(0.0, g.randf_range(0.5, 0.9), ch, 6), Efeitos.material_toon(cor, 0.4), pos + Vector3(1.2, ch / 2.0 + 0.5, 0.8), Vector3(g.randf_range(-0.2, 0.2), 0, g.randf_range(-0.2, 0.2)))
		if i % 3 == 0:
			var luz := OmniLight3D.new()
			luz.light_color = cor
			luz.light_energy = 0.8
			luz.omni_range = 8.0
			luz.position = pos + Vector3(0, 2.0, 0)
			raiz.add_child(luz)
	# Cristais gigantes no paredão e lascas flutuando.
	for i in 10:
		var ang := TAU * i / 10.0 + 0.3
		var h := g.randf_range(10.0, 20.0)
		var cor: Color = cores[i % 3]
		_malha(raiz, _cilindro(0.0, g.randf_range(2.0, 3.5), h, 6), Efeitos.material_toon(cor, 0.3), Vector3(cos(ang) * 50.0, h / 2.0 - 1.0, sin(ang) * 50.0), Vector3(g.randf_range(-0.25, 0.25), 0, g.randf_range(-0.25, 0.25)))
	for i in 14:
		var ang := g.randf() * TAU
		var r := g.randf_range(22.0, 40.0)
		var mi := _malha(raiz, _cilindro(0.0, 0.3, 1.0, 6), Efeitos.material(cores[i % 3], 1.5, 1.0, true), Vector3(cos(ang) * r, g.randf_range(2.0, 7.0), sin(ang) * r), Vector3(g.randf() * TAU, 0, g.randf() * TAU))
		_flutuar(mi, g.randf_range(0.3, 0.8), g.randf_range(1.5, 3.0))
		_girar(mi, g.randf_range(0.5, 1.5))


## Fenda do Horizonte: chão preto rachado de roxo, fragmentos flutuando e a fenda no céu.
static func _fenda(raiz: Node3D, g: RandomNumberGenerator) -> void:
	var roxo := Color("#b45bff")
	var brilho := Efeitos.material(roxo, 2.0, 1.0, true)
	var escuro := Efeitos.material_toon(Color("#120a1e"))
	# Rachaduras luminosas saindo da arena.
	for i in 16:
		var ang := TAU * i / 16.0 + g.randf_range(-0.1, 0.1)
		var comp := g.randf_range(8.0, 22.0)
		var r := 22.5 + comp / 2.0
		_malha(raiz, _caixa(Vector3(0.25, 0.1, comp)), brilho, Vector3(cos(ang) * r, -0.45, sin(ang) * r), Vector3(0, -ang + PI / 2.0, 0))
	# Fragmentos de arena que flutuam e giram devagar.
	for i in 24:
		var ang := g.randf() * TAU
		var r := g.randf_range(24.0, 48.0)
		var tam := Vector3(g.randf_range(1.5, 5.0), g.randf_range(0.6, 2.0), g.randf_range(1.5, 5.0))
		var corpo := Node3D.new()
		corpo.position = Vector3(cos(ang) * r, g.randf_range(1.0, 14.0), sin(ang) * r)
		raiz.add_child(corpo)
		_malha(corpo, _caixa(tam), escuro, Vector3.ZERO, Vector3(g.randf_range(-0.4, 0.4), g.randf() * TAU, g.randf_range(-0.4, 0.4)))
		_malha(corpo, _caixa(Vector3(tam.x * 0.6, 0.12, 0.12)), brilho, Vector3(0, tam.y * 0.5, 0), Vector3(0, g.randf() * TAU, 0))
		_flutuar(corpo, g.randf_range(0.4, 1.2), g.randf_range(2.0, 4.0))
		_girar(corpo, g.randf_range(0.1, 0.4))
	# A fenda: um rasgo vertical de luz no horizonte.
	var fenda := _malha(raiz, _caixa(Vector3(1.2, 60.0, 0.3)), Efeitos.material(Color("#e9d2ff"), 3.0, 1.0, true), Vector3(0, 28.0, -75.0), Vector3(0, 0, 0.12))
	_pulsar(fenda, 2.0, g)
	_malha(raiz, _caixa(Vector3(6.0, 60.0, 0.1)), Efeitos.material(roxo, 1.2, 0.35, true), Vector3(0, 28.0, -75.5), Vector3(0, 0, 0.12))
	var luz := OmniLight3D.new()
	luz.light_color = roxo
	luz.light_energy = 1.5
	luz.omni_range = 60.0
	luz.position = Vector3(0, 20, -60)
	raiz.add_child(luz)
	# Olhos do Coro: esferas escuras com um ponto roxo, espiando da borda.
	for i in 6:
		var ang := TAU * i / 6.0 + 0.5
		var pos := Vector3(cos(ang) * 30.0, g.randf_range(3.0, 7.0), sin(ang) * 30.0)
		var e := SphereMesh.new()
		e.radius = 1.4
		e.height = 2.8
		var olho := _malha(raiz, e, escuro, pos)
		var p := SphereMesh.new()
		p.radius = 0.4
		p.height = 0.8
		_malha(olho, p, brilho, Vector3(-cos(ang) * 1.1, 0.2, -sin(ang) * 1.1))
		_flutuar(olho, 0.6, g.randf_range(2.0, 3.5))


# ---------------------------------------------------------------------
# Peças compostas
# ---------------------------------------------------------------------

static func _chao_externo(raiz: Node3D, cor: Color, y := -0.55) -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = RAIO_EXTERNO
	disco.bottom_radius = RAIO_EXTERNO
	disco.height = 0.4
	disco.radial_segments = 48
	var mi := _malha(raiz, disco, Efeitos.material_toon(cor, 0.0, false), Vector3(0, y - 0.2, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Plano de água com ondulação por shader.
static func _agua(raiz: Node3D, cor: Color, cor_clara: Color, y: float, tamanho: float) -> void:
	if _shader_agua == null:
		_shader_agua = Shader.new()
		_shader_agua.code = SHADER_AGUA
	var mat := ShaderMaterial.new()
	mat.shader = _shader_agua
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("cor_clara", cor_clara)
	var plano := PlaneMesh.new()
	plano.size = Vector2(tamanho, tamanho)
	plano.subdivide_width = 48
	plano.subdivide_depth = 48
	var mi := _malha(raiz, plano, mat, Vector3(0, y, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _arco(raiz: Node3D, pos: Vector3, rot_y: float, largura: float, altura: float, mat: Material) -> void:
	var arco := Node3D.new()
	arco.position = pos
	arco.rotation.y = rot_y
	raiz.add_child(arco)
	_malha(arco, _caixa(Vector3(1.0, altura, 1.0)), mat, Vector3(-largura / 2.0, altura / 2.0 - 0.5, 0))
	_malha(arco, _caixa(Vector3(1.0, altura, 1.0)), mat, Vector3(largura / 2.0, altura / 2.0 - 0.5, 0))
	_malha(arco, _caixa(Vector3(largura + 1.0, 1.0, 1.2)), mat, Vector3(0, altura - 0.2, 0))
	_malha(arco, _caixa(Vector3(largura * 0.5, 0.7, 1.0)), mat, Vector3(0, altura - 0.9, 0))


static func _bandeira(raiz: Node3D, pos: Vector3, cor: Color, cor_clara: Color, altura: float, g: RandomNumberGenerator) -> void:
	_malha(raiz, _cilindro(0.12, 0.16, altura, 8), Efeitos.material_toon(Color("#d8d2c0")), pos + Vector3(0, altura / 2.0 - 0.5, 0))
	var esfera := SphereMesh.new()
	esfera.radius = 0.3
	esfera.height = 0.6
	_malha(raiz, esfera, Efeitos.material_toon(Color("#ffd27f"), 0.4), pos + Vector3(0, altura - 0.4, 0))
	var pano := Node3D.new()
	pano.position = pos + Vector3(0, altura - 1.9, 0)
	raiz.add_child(pano)
	_malha(pano, _caixa(Vector3(2.8, 1.8, 0.08)), Efeitos.material_toon(cor), Vector3(1.5, 0, 0))
	_malha(pano, _caixa(Vector3(2.6, 0.5, 0.1)), Efeitos.material_toon(cor_clara, 0.0, false), Vector3(1.5, 0.2, 0))
	var tw := pano.create_tween().set_loops()
	tw.tween_property(pano, "rotation:y", 0.35, g.randf_range(0.8, 1.3)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pano, "rotation:y", -0.2, g.randf_range(0.8, 1.3)).set_trans(Tween.TRANS_SINE)


static func _cabo(raiz: Node3D, a: Vector3, b: Vector3, mat: Material) -> void:
	var meio := (a + b) / 2.0 - Vector3(0, 1.2, 0)
	var comp := a.distance_to(b)
	var mi := _malha(raiz, _cilindro(0.08, 0.08, comp, 5), mat, meio)
	mi.look_at(b, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)


## Esferas translúcidas que sobem, crescem e somem, em laço.
static func _fumaca(raiz: Node3D, origem: Vector3, altura: float, cor: Color, g: RandomNumberGenerator, tamanho := 1.0) -> void:
	for i in 3:
		var esfera := SphereMesh.new()
		esfera.radius = 1.0
		esfera.height = 2.0
		esfera.radial_segments = 10
		esfera.rings = 5
		var mat := Efeitos.material(cor, 0.0, 0.5, true)
		var mi := _malha(raiz, esfera, mat, origem)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dur := g.randf_range(2.5, 4.0)
		var tw := mi.create_tween().set_loops()
		tw.tween_interval(i * dur / 3.0)
		tw.tween_callback(func():
			mi.position = origem + Vector3(g.randf_range(-0.5, 0.5), 0, g.randf_range(-0.5, 0.5))
			mi.scale = Vector3.ONE * 0.5 * tamanho
			mat.albedo_color.a = 0.45)
		tw.tween_property(mi, "position:y", origem.y + altura, dur)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 1.8 * tamanho, dur)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------------
# Animações simples
# ---------------------------------------------------------------------

static func _flutuar(no: Node3D, amplitude: float, periodo: float) -> void:
	var y0 := no.position.y
	var tw := no.create_tween().set_loops()
	tw.tween_property(no, "position:y", y0 + amplitude, periodo).set_trans(Tween.TRANS_SINE)
	tw.tween_property(no, "position:y", y0 - amplitude, periodo).set_trans(Tween.TRANS_SINE)


static func _girar(no: Node3D, velocidade: float) -> void:
	var tw := no.create_tween().set_loops()
	tw.tween_property(no, "rotation:y", TAU, TAU / maxf(0.05, velocidade)).as_relative()


static func _pulsar(no: Node3D, forca: float, g: RandomNumberGenerator) -> void:
	var escala := no.scale
	var tw := no.create_tween().set_loops()
	var dur := g.randf_range(0.6, 1.4)
	tw.tween_property(no, "scale", escala * (1.0 + 0.12 * forca), dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(no, "scale", escala, dur).set_trans(Tween.TRANS_SINE)


## Move o nó no sentido `direcao` (m/s) e, ao sair do raio, volta pelo lado oposto.
static func _deslizar(no: Node3D, direcao: Vector3, raio: float, g: RandomNumberGenerator) -> void:
	var dir := direcao.normalized()
	var inicio := no.position - dir * raio
	var fase := g.randf()
	var dur := raio * 2.0 / maxf(0.1, direcao.length())
	var passo := func(t: float):
		no.position = inicio + dir * raio * 2.0 * fposmod(t + fase, 1.0)
	var tw := no.create_tween().set_loops()
	tw.tween_method(passo, 0.0, 1.0, dur)


# ---------------------------------------------------------------------
# Primitivas
# ---------------------------------------------------------------------

static func _malha(pai: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = escala
	pai.add_child(mi)
	return mi


static func _caixa(tamanho: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = tamanho
	return m


static func _cilindro(topo: float, base: float, altura: float, segmentos := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = topo
	m.bottom_radius = base
	m.height = altura
	m.radial_segments = segmentos
	return m
