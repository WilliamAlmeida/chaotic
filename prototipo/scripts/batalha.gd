class_name Batalha
extends Node3D
## Uma partida: monta a arena a partir da carta de Local, cria os dois lutadores,
## roda a introdução (Local -> Iniciativa -> Equipamentos revelados) e o duelo 1x1.

signal terminou(vitoria_jogador: bool, detalhes: Dictionary)
signal pediu_revanche
signal pediu_menu

const DURACAO_MAXIMA := 180.0
const DANO_LAVA_POR_SEGUNDO := 9.0

var config: Dictionary = {}
var local: Dictionary = {}
var jogador: Lutador
var inimigo: Lutador
var camera: CameraOrbita
var hud: Hud
var perigos: Array = []
var tempo := 0.0
var em_andamento := false
var simulacao := false

var _vento_t := 7.0
var _encerrada := false


func _ready() -> void:
	simulacao = bool(config.get("simulacao", false))
	local = Dados.locais[str(config["local"])]
	_criar_ambiente()
	_criar_arena()

	jogador = _criar_lutador(config, Vector3(0, 0.2, 9), true)
	inimigo = _criar_lutador(config["inimigo"], Vector3(0, 0.2, -9), false)
	jogador.alvo = inimigo
	inimigo.alvo = jogador
	inimigo.rotation.y = PI
	jogador.derrotado.connect(_on_derrotado)
	inimigo.derrotado.connect(_on_derrotado)

	camera = CameraOrbita.new()
	camera.alvo = jogador
	camera.foco = inimigo
	add_child(camera)

	if simulacao:
		_criar_ia(jogador)
	else:
		var controle := ControleJogador.new()
		controle.lutador = jogador
		controle.camera = camera
		add_child(controle)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_criar_ia(inimigo)

	hud = Hud.new()
	add_child(hud)
	hud.configurar(jogador, inimigo, local)
	hud.tempo_restante = DURACAO_MAXIMA
	hud.revanche.connect(func(): pediu_revanche.emit())
	hud.menu.connect(func(): pediu_menu.emit())
	_intro()


func perigo_em(pos: Vector3) -> String:
	var plano := Vector2(pos.x, pos.z)
	for p in perigos:
		if plano.distance_to(p["centro"]) <= float(p["raio"]):
			return str(p["tipo"])
	return ""


func _physics_process(delta: float) -> void:
	if not em_andamento:
		return
	tempo += delta
	hud.tempo_restante = DURACAO_MAXIMA - tempo
	for lutador in [jogador, inimigo]:
		var l: Lutador = lutador
		if l.energia <= 0.0:
			continue
		var perigo := perigo_em(l.global_position)
		l.mult_velocidade_ambiente = 0.55 if perigo == "agua" else 1.0
		if perigo == "lava" and l.is_on_floor():
			l.receber_dano_ambiente(DANO_LAVA_POR_SEGUNDO * delta)
	if bool(local.get("vento", false)):
		_vento_t -= delta
		if _vento_t <= 0.0:
			_vento_t = randf_range(6.0, 9.0)
			var ang := randf() * TAU
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			jogador.empurrar(dir * 16.0)
			inimigo.empurrar(dir * 16.0)
			hud.banner("Rajada de vento!", 1.0)
	if tempo >= DURACAO_MAXIMA:
		var fracao_j := jogador.energia / jogador.energia_max
		var fracao_i := inimigo.energia / inimigo.energia_max
		_finalizar(fracao_j >= fracao_i, "tempo")


func _unhandled_input(event: InputEvent) -> void:
	if simulacao:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and em_andamento \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------------
# Fluxo da partida
# ---------------------------------------------------------------------

func _intro() -> void:
	var sorteado := " (sorteado)" if bool(config.get("local_sorteado", false)) else ""
	hud.banner("%s%s" % [local["nome"], sorteado], 2.2)
	await _esperar(2.2)

	# Iniciativa: definida pelo Local, como no card game. Empate favorece o jogador ativo.
	var attr := str(local["iniciativa"]["atributo"])
	var jogador_primeiro := jogador.atributo(attr) >= inimigo.atributo(attr)
	var quem := jogador.nome if jogador_primeiro else inimigo.nome
	hud.banner("Iniciativa (%s): %s" % [Dados.ATRIBUTOS[attr], quem], 2.0)
	jogador.mao.iniciar(jogador.deck, 0.0 if jogador_primeiro else 2.5)
	inimigo.mao.iniciar(inimigo.deck, 2.5 if jogador_primeiro else 0.0)
	await _esperar(2.0)

	jogador.revelar_equipamento()
	inimigo.revelar_equipamento()
	hud.banner("Equipamentos revelados!", 1.6)
	await _esperar(1.6)

	hud.banner("LUTEM!", 1.0)
	jogador.controles_ativos = true
	inimigo.controles_ativos = true
	em_andamento = true


func _on_derrotado(derrotado: Lutador) -> void:
	_finalizar(derrotado != jogador, "derrota")


func _finalizar(vitoria: bool, motivo: String) -> void:
	if _encerrada:
		return
	_encerrada = true
	em_andamento = false
	jogador.controles_ativos = false
	inimigo.controles_ativos = false
	var vencedor := jogador if vitoria else inimigo
	var perdedor := inimigo if vitoria else jogador
	var detalhes := {
		"vencedor": vencedor.id_monstro,
		"perdedor": perdedor.id_monstro,
		"local": str(config["local"]),
		"tempo": tempo,
		"motivo": motivo,
		"energia_restante": vencedor.energia,
	}
	if simulacao:
		terminou.emit(vitoria, detalhes)
		return
	hud.banner("VITÓRIA!" if vitoria else "DERROTA", 2.0)
	await _esperar(1.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.mostrar_resultado(vitoria, detalhes)
	terminou.emit(vitoria, detalhes)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


# ---------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------

func _criar_lutador(cfg: Dictionary, pos: Vector3, do_jogador: bool) -> Lutador:
	var l := Lutador.new()
	l.configurar(str(cfg["monstro"]), str(cfg.get("equipamento", "")), str(cfg.get("cantico", "")), cfg["deck"])
	l.e_jogador = do_jogador and not simulacao
	l.local = local
	add_child(l)
	l.global_position = pos
	return l


func _criar_ia(l: Lutador) -> void:
	var ia := ControleIA.new()
	ia.lutador = l
	ia.batalha = self
	add_child(ia)


func _criar_ambiente() -> void:
	var horizonte := Color(str(local["cor_ceu_horizonte"]))
	var ceu_mat := ProceduralSkyMaterial.new()
	ceu_mat.sky_top_color = Color(str(local["cor_ceu_topo"]))
	ceu_mat.sky_horizon_color = horizonte
	ceu_mat.ground_horizon_color = horizonte
	ceu_mat.ground_bottom_color = Color(str(local["cor_chao"])).darkened(0.6)
	var ceu := Sky.new()
	ceu.sky_material = ceu_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = horizonte
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var mundo := WorldEnvironment.new()
	mundo.environment = env
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.light_color = Color(str(local["cor_luz"]))
	sol.light_energy = 1.25
	sol.shadow_enabled = true
	sol.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sol)


func _criar_arena() -> void:
	var cor_chao := Color(str(local["cor_chao"]))
	# Chão circular com colisão.
	var chao := StaticBody3D.new()
	add_child(chao)
	var forma := CylinderShape3D.new()
	forma.radius = 21.5
	forma.height = 1.0
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position.y = -0.5
	chao.add_child(col)
	var malha := CylinderMesh.new()
	malha.top_radius = 21.5
	malha.bottom_radius = 22.5
	malha.height = 1.0
	malha.radial_segments = 64
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = Efeitos.material_toon(cor_chao, 0.0, false)
	mi.position.y = -0.5
	chao.add_child(mi)

	# Anel de pedras na borda (decoração).
	for i in 28:
		var ang := TAU * i / 28.0
		var bloco := BoxMesh.new()
		bloco.size = Vector3(1.0, 0.8 + 0.6 * absf(sin(i * 1.7)), 1.0)
		var b := MeshInstance3D.new()
		b.mesh = bloco
		b.material_override = Efeitos.material_toon(cor_chao.lightened(0.25))
		b.position = Vector3(cos(ang) * 22.0, bloco.size.y / 2.0, sin(ang) * 22.0)
		b.rotation.y = -ang
		add_child(b)

	var estilo := str(local.get("estilo_obstaculo", "rocha"))
	for o in local.get("obstaculos", []):
		_criar_obstaculo(Vector3(float(o[0]), 0.0, float(o[1])), float(o[2]), float(o[3]), estilo, cor_chao)

	for p in local.get("perigos", []):
		var centro := Vector2(float(p["x"]), float(p["z"]))
		var raio := float(p["raio"])
		var tipo := str(p["tipo"])
		perigos.append({"tipo": tipo, "centro": centro, "raio": raio})
		var poca := CylinderMesh.new()
		poca.top_radius = raio
		poca.bottom_radius = raio
		poca.height = 0.06
		poca.radial_segments = 40
		var mp := MeshInstance3D.new()
		mp.mesh = poca
		if tipo == "lava":
			mp.material_override = Efeitos.material(Color(1.0, 0.35, 0.08), 1.1)
		else:
			mp.material_override = Efeitos.material(Color(0.2, 0.5, 1.0), 0.3, 0.75)
		mp.position = Vector3(centro.x, 0.03, centro.y)
		add_child(mp)


func _criar_obstaculo(pos: Vector3, raio: float, altura: float, estilo: String, cor_chao: Color) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = pos
	add_child(corpo)
	var forma := CylinderShape3D.new()
	forma.radius = raio
	forma.height = altura
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position.y = altura / 2.0
	corpo.add_child(col)

	var tronco := CylinderMesh.new()
	tronco.height = altura
	var mi := MeshInstance3D.new()
	mi.mesh = tronco
	mi.position.y = altura / 2.0
	corpo.add_child(mi)
	match estilo:
		"arvore":
			tronco.top_radius = raio * 0.6
			tronco.bottom_radius = raio * 0.8
			mi.material_override = Efeitos.material_toon(Color(0.4, 0.27, 0.16))
			var copa := SphereMesh.new()
			copa.radius = raio * 3.0
			copa.height = raio * 4.5
			var mc := MeshInstance3D.new()
			mc.mesh = copa
			mc.material_override = Efeitos.material_toon(Color(0.22, 0.5, 0.25))
			mc.position.y = altura + raio
			corpo.add_child(mc)
		"pilar":
			tronco.top_radius = raio
			tronco.bottom_radius = raio
			mi.material_override = Efeitos.material_toon(Color(0.85, 0.85, 0.8))
			var topo := BoxMesh.new()
			topo.size = Vector3(raio * 2.6, 0.4, raio * 2.6)
			var mt := MeshInstance3D.new()
			mt.mesh = topo
			mt.material_override = Efeitos.material_toon(Color(0.9, 0.9, 0.85))
			mt.position.y = altura
			corpo.add_child(mt)
		_:
			tronco.top_radius = raio * 0.45
			tronco.bottom_radius = raio
			mi.material_override = Efeitos.material_toon(cor_chao.lightened(0.15))
