class_name Batalha
extends Node3D
## Uma partida: monta a arena a partir da carta de Local (obstáculos, perigos e a cenografia
## de scripts/cenario.gd), cria os dois lutadores frente a frente, roda a introdução
## (giro de câmera pela arena -> Iniciativa -> Equipamentos revelados) e o duelo 1x1.
## As "situações" da arena (erupção, maré alta, raio...) ficam em scripts/eventos_arena.gd.

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
## Obstáculos: {"corpo", "centro" (Vector2), "raio", "altura", "vida"}. Bloqueiam projéteis e quebram.
var obstaculos: Array = []
var tempo := 0.0
var em_andamento := false
var simulacao := false
## Situações da arena (sorteadas durante a luta). `eventos.disparar("erupcao")` força uma.
var eventos: EventosArena
var ambiente: WorldEnvironment
var sol: DirectionalLight3D
var cenografia: Node3D

var _encerrada := false
var _camera_intro: Camera3D
var _nevoas_moveis: Array = []


func _ready() -> void:
	add_to_group("batalha")
	simulacao = bool(config.get("simulacao", false))
	# Cópia: a Falha da Rede inverte os modificadores durante a luta sem mexer nos dados globais.
	local = Dados.locais[str(config["local"])].duplicate(true)
	_criar_ambiente()
	_criar_arena()

	var posicoes := _posicoes_iniciais()
	jogador = _criar_lutador(config, posicoes[0], true)
	inimigo = _criar_lutador(config["inimigo"], posicoes[1], false)
	jogador.alvo = inimigo
	inimigo.alvo = jogador
	jogador.rotation.y = _angulo_para(posicoes[0], posicoes[1])
	inimigo.rotation.y = _angulo_para(posicoes[1], posicoes[0])
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
		if Jogo.toque_ativo():
			var toque := ControleToque.new()
			toque.lutador = jogador
			toque.camera = camera
			add_child(toque)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_criar_ia(inimigo)

	hud = Hud.new()
	add_child(hud)
	if bool(config.get("tutorial", false)) and not simulacao:
		var tutorial := Tutorial.new()
		tutorial.batalha = self
		add_child(tutorial)
	hud.configurar(jogador, inimigo, local)
	hud.tempo_restante = DURACAO_MAXIMA
	hud.revanche.connect(func(): pediu_revanche.emit())
	hud.menu.connect(func(): pediu_menu.emit())

	eventos = EventosArena.new()
	add_child(eventos)
	var lista: Array = local.get("eventos", []).duplicate()
	if bool(local.get("vento", false)) and not lista.has("rajada"):
		lista.append("rajada")
	eventos.configurar(self, lista)
	for n in _nevoas_moveis:
		eventos.registrar_nevoa_movel(n["no"], n["perigo"])
	_intro()


# ---------------------------------------------------------------------
# Cenário: cobertura, linha de visão, obstáculos destrutíveis e esconderijos
# ---------------------------------------------------------------------

func obstaculo_em(pos: Vector3) -> Dictionary:
	var plano := Vector2(pos.x, pos.z)
	for o in obstaculos:
		if pos.y <= float(o["altura"]) + 0.2 and plano.distance_to(o["centro"]) <= float(o["raio"]):
			return o
	return {}


## Verdadeiro se nenhum obstáculo alto bloqueia o caminho entre a e b (usado pela IA antes de atirar).
func linha_livre(a: Vector3, b: Vector3) -> bool:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	for o in obstaculos:
		var c: Vector2 = o["centro"]
		var mais_perto := Geometry2D.get_closest_point_to_segment(c, a2, b2)
		if mais_perto.distance_to(c) < float(o["raio"]) + 0.15 and float(o["altura"]) > minf(a.y, b.y) + 0.3:
			return false
	return true


## Ponto atrás do obstáculo mais próximo, do lado oposto ao inimigo. Vector3.INF se não houver.
func ponto_cobertura(de: Vector3, contra: Vector3, alcance := 12.0) -> Vector3:
	var melhor := Vector3.INF
	var melhor_dist := INF
	for o in obstaculos:
		if float(o["altura"]) < 1.8:
			continue
		var c: Vector2 = o["centro"]
		var afastar := (c - Vector2(contra.x, contra.z)).normalized()
		var ponto := c + afastar * (float(o["raio"]) + 1.3)
		var dist := Vector2(de.x, de.z).distance_to(ponto)
		if dist < alcance and dist < melhor_dist and ponto.length() < Lutador.RAIO_ARENA - 1.0:
			melhor = Vector3(ponto.x, 0.0, ponto.y)
			melhor_dist = dist
	return melhor


## Centro do capim alto / névoa mais próximo. Vector3.INF se não houver.
func esconderijo_proximo(de: Vector3, alcance := 12.0) -> Vector3:
	var melhor := Vector3.INF
	var melhor_dist := alcance
	for p in perigos:
		if not str(p["tipo"]) in ["mato", "nevoa"]:
			continue
		var c: Vector2 = p["centro"]
		var dist := Vector2(de.x, de.z).distance_to(c)
		if dist < melhor_dist:
			melhor = Vector3(c.x, 0.0, c.y)
			melhor_dist = dist
	return melhor


func danificar_area(pos: Vector3, raio: float, dano: float) -> void:
	var plano := Vector2(pos.x, pos.z)
	for o in obstaculos.duplicate():
		if plano.distance_to(o["centro"]) <= raio + float(o["raio"]):
			danificar_obstaculo(o, dano)


func danificar_obstaculo(o: Dictionary, dano: float) -> void:
	if not obstaculos.has(o):
		return
	o["vida"] = float(o["vida"]) - dano
	var corpo: StaticBody3D = o["corpo"]
	if float(o["vida"]) <= 0.0:
		obstaculos.erase(o)
		corpo.collision_layer = 0
		Efeitos.explosao(self, corpo.global_position + Vector3(0, float(o["altura"]) * 0.5, 0), Color(0.78, 0.68, 0.52), float(o["raio"]) * 2.5, 0.5)
		var tw := corpo.create_tween()
		tw.tween_property(corpo, "scale", Vector3(1.3, 0.05, 1.3), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(corpo.queue_free)
	else:
		var tw := corpo.create_tween()
		tw.tween_property(corpo, "scale", Vector3(0.9, 1.0, 0.9), 0.05)
		tw.tween_property(corpo, "scale", Vector3.ONE, 0.12)


## Tipo do perigo no ponto ("" se nenhum). Perigos com "raio_interno" são anéis (maré alta).
func perigo_em(pos: Vector3) -> String:
	var plano := Vector2(pos.x, pos.z)
	for p in perigos:
		var d := plano.distance_to(p["centro"])
		if d <= float(p["raio"]) and d >= float(p.get("raio_interno", 0.0)):
			return str(p["tipo"])
	return ""


## Cria um obstáculo durante a luta (desmoronamento) e devolve sua entrada em `obstaculos`.
func adicionar_obstaculo(pos: Vector3, raio: float, altura: float, estilo := "") -> Dictionary:
	if estilo == "":
		estilo = str(local.get("estilo_obstaculo", "rocha"))
	_criar_obstaculo(Vector3(pos.x, 0.0, pos.z), raio, altura, estilo, Color(str(local["cor_chao"])))
	return obstaculos.back()


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
		# Quem voa passa por cima de lava e água.
		l.mult_velocidade_ambiente = 0.55 if perigo == "agua" and not l.voa else 1.0
		if perigo == "lava" and l.is_on_floor() and not l.voa:
			l.receber_dano_ambiente(DANO_LAVA_POR_SEGUNDO * delta)
		# Capim alto e névoa escondem quem não está atacando; na tempestade de areia, todo mundo.
		var cego := eventos != null and eventos.cegueira_ativa()
		l.escondido = (cego or (perigo in ["mato", "nevoa"] and not l.no_alto())) and l.acao.is_empty() and not l.cantando
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
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Jogo.toque_ativo():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------------
# Fluxo da partida
# ---------------------------------------------------------------------

## Introdução curta (<= 6 s; 1 s a menos no modo fácil): giro de câmera apresentando a
## arena -> Iniciativa -> Equipamentos revelados -> LUTEM!
func _intro() -> void:
	var facil := Jogo.facil() and not simulacao
	var t_giro := 2.0 if facil else 2.5
	var t_iniciativa := 1.3 if facil else 1.5
	var t_equip := 1.0 if facil else 1.2
	var sorteado := " (sorteado)" if bool(config.get("local_sorteado", false)) else ""
	hud.banner("%s%s" % [local["nome"], sorteado], t_giro)
	if not simulacao:
		_apresentar_arena(t_giro)
	await _esperar(t_giro)

	# Iniciativa: definida pelo Local, como no card game. Empate favorece o jogador ativo.
	var attr := str(local["iniciativa"]["atributo"])
	var jogador_primeiro := jogador.atributo(attr) >= inimigo.atributo(attr)
	var quem := jogador.nome if jogador_primeiro else inimigo.nome
	hud.banner("Iniciativa (%s): %s" % [Dados.ATRIBUTOS[attr], quem], t_iniciativa)
	jogador.mao.iniciar(jogador.deck, 0.0 if jogador_primeiro else 2.5)
	inimigo.mao.iniciar(inimigo.deck, 2.5 if jogador_primeiro else 0.0)
	await _esperar(t_iniciativa)

	jogador.revelar_equipamento()
	inimigo.revelar_equipamento()
	hud.banner("Equipamentos revelados!", t_equip)
	await _esperar(t_equip)

	_encerrar_camera_intro()
	hud.banner("LUTEM!", 1.0)
	jogador.controles_ativos = true
	inimigo.controles_ativos = true
	em_andamento = true


## Câmera própria que dá uma volta alta pela arena e desce até perto do jogador.
func _apresentar_arena(duracao: float) -> void:
	_camera_intro = Camera3D.new()
	_camera_intro.fov = 62.0
	add_child(_camera_intro)
	_camera_intro.make_current()
	var pj := jogador.global_position
	var dir_j := Vector2(pj.x, pj.z).normalized() if Vector2(pj.x, pj.z).length() > 0.1 else Vector2(0, 1)
	var ang0 := atan2(dir_j.y, dir_j.x) + 1.9
	var ang1 := atan2(dir_j.y, dir_j.x) + 0.15
	var passo := func(t: float):
		if not is_instance_valid(_camera_intro):
			return
		var f := smoothstep(0.0, 1.0, t)
		var ang := lerpf(ang0, ang1, f)
		var raio := lerpf(34.0, 16.0, f)
		var altura := lerpf(17.0, 5.5, f)
		_camera_intro.global_position = Vector3(cos(ang) * raio, altura, sin(ang) * raio)
		var alvo := Vector3.ZERO.lerp(inimigo.global_position + Vector3(0, 1.0, 0), f * 0.6)
		_camera_intro.look_at(alvo, Vector3.UP)
	var tw := _camera_intro.create_tween()
	tw.tween_method(passo, 0.0, 1.0, duracao)


func _encerrar_camera_intro() -> void:
	if is_instance_valid(_camera_intro):
		_camera_intro.queue_free()
		_camera_intro = null
	if is_instance_valid(camera) and is_instance_valid(camera.camera):
		camera.camera.make_current()


func _on_derrotado(derrotado: Lutador) -> void:
	_finalizar(derrotado != jogador, "derrota")


func _finalizar(vitoria: bool, motivo: String) -> void:
	if _encerrada:
		return
	_encerrada = true
	em_andamento = false
	_encerrar_camera_intro()
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
	# Chefes da campanha trazem Energia extra (fração, ex.: 0.3 = +30%).
	l.energia_bonus = float(cfg.get("energia_bonus", 0.0))
	l.configurar(str(cfg["monstro"]), str(cfg.get("equipamento", "")), str(cfg.get("cantico", "")), cfg["deck"])
	l.e_jogador = do_jogador and not simulacao
	l.local = local
	add_child(l)
	l.global_position = pos
	return l


## Jogador e inimigo frente a frente a ~9 m, girando em volta do centro até os dois
## nascerem fora de obstáculos e de lava/água.
func _posicoes_iniciais() -> Array[Vector3]:
	var melhor: Array[Vector3] = [Vector3(0, 0.2, 9), Vector3(0, 0.2, -9)]
	for passo in 12:
		for lado in [1.0, -1.0]:
			var ang: float = deg_to_rad(15.0 * passo) * float(lado)
			var a := Vector3(sin(ang) * 9.0, 0.2, cos(ang) * 9.0)
			var b := -a
			b.y = 0.2
			if _ponto_de_nascimento_livre(a) and _ponto_de_nascimento_livre(b):
				return [a, b]
			if passo == 0:
				break
	return melhor


func _ponto_de_nascimento_livre(p: Vector3) -> bool:
	var plano := Vector2(p.x, p.z)
	for o in obstaculos:
		if plano.distance_to(o["centro"]) < float(o["raio"]) + 1.3:
			return false
	for pr in perigos:
		if str(pr["tipo"]) in ["lava", "agua"] and plano.distance_to(pr["centro"]) < float(pr["raio"]) + 0.9:
			return false
	return true


func _angulo_para(de: Vector3, para: Vector3) -> float:
	var d := para - de
	return atan2(-d.x, -d.z)


func _criar_ia(l: Lutador) -> void:
	var ia := ControleIA.new()
	ia.lutador = l
	ia.batalha = self
	# Simulações IA x IA usam sempre a IA normal; partidas de verdade seguem a config/modo fácil.
	ia.dificuldade = "normal" if simulacao else str(config.get("dificuldade", "facil" if Jogo.facil() else "normal"))
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
	ambiente = WorldEnvironment.new()
	ambiente.environment = env
	add_child(ambiente)

	sol = DirectionalLight3D.new()
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

	# Cenografia fora da arena (só com janela: a simulação headless não precisa dela).
	if not simulacao:
		cenografia = Cenario.decorar(self, local)

	var estilo := str(local.get("estilo_obstaculo", "rocha"))
	for o in local.get("obstaculos", []):
		_criar_obstaculo(Vector3(float(o[0]), 0.0, float(o[1])), float(o[2]), float(o[3]), estilo, cor_chao)

	for p in local.get("perigos", []):
		var centro := Vector2(float(p["x"]), float(p["z"]))
		var raio := float(p["raio"])
		var tipo := str(p["tipo"])
		var perigo := {"tipo": tipo, "centro": centro, "raio": raio}
		perigos.append(perigo)
		if tipo == "mato":
			_criar_mato(centro, raio)
			continue
		if tipo == "nevoa":
			var no := _criar_nevoa(centro, raio)
			if bool(local.get("nevoa_movel", false)):
				_nevoas_moveis.append({"no": no, "perigo": perigo})
			continue
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


func _criar_mato(centro: Vector2, raio: float) -> void:
	var base := CylinderMesh.new()
	base.top_radius = raio
	base.bottom_radius = raio
	base.height = 0.04
	var mb := MeshInstance3D.new()
	mb.mesh = base
	mb.material_override = Efeitos.material_toon(Color("#2f5a24"), 0.0, false)
	mb.position = Vector3(centro.x, 0.03, centro.y)
	add_child(mb)
	var tons := [Color("#4f8f35"), Color("#5fa63f"), Color("#3f7a2c"), Color("#77b84a")]
	var gerador := RandomNumberGenerator.new()
	gerador.seed = int(centro.x * 1000 + centro.y * 7)
	for i in int(raio * raio * 4.0):
		var ang := gerador.randf() * TAU
		var r := sqrt(gerador.randf()) * raio * 0.95
		var folha := CylinderMesh.new()
		folha.top_radius = 0.0
		folha.bottom_radius = gerador.randf_range(0.08, 0.14)
		folha.height = gerador.randf_range(1.4, 2.1)
		folha.radial_segments = 4
		var mf := MeshInstance3D.new()
		mf.mesh = folha
		mf.material_override = Efeitos.material_toon(tons[i % tons.size()], 0.0, false)
		mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mf.position = Vector3(centro.x + cos(ang) * r, folha.height / 2.0, centro.y + sin(ang) * r)
		mf.rotation = Vector3(gerador.randf_range(-0.2, 0.2), 0.0, gerador.randf_range(-0.2, 0.2))
		add_child(mf)


## Banco de névoa. Devolve o nó raiz (a névoa móvel da Rota das Tempestades é movida por ele).
func _criar_nevoa(centro: Vector2, raio: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = Vector3(centro.x, 0.0, centro.y)
	add_child(raiz)
	var cor := Color(str(local.get("cor_ceu_horizonte", "#e8eef2"))).lightened(0.45)
	var gerador := RandomNumberGenerator.new()
	gerador.seed = int(centro.x * 31 + centro.y * 17)
	for i in 7:
		var ang := gerador.randf() * TAU
		var r := gerador.randf() * raio * 0.6
		var esfera := SphereMesh.new()
		esfera.radius = 1.0
		esfera.height = 2.0
		var mn := MeshInstance3D.new()
		mn.mesh = esfera
		mn.material_override = Efeitos.material(cor, 0.2, 0.38, true)
		mn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mn.position = Vector3(cos(ang) * r, gerador.randf_range(0.8, 1.6), sin(ang) * r)
		mn.scale = Vector3(raio * 0.55, raio * 0.35, raio * 0.55) * gerador.randf_range(0.8, 1.2)
		raiz.add_child(mn)
		var tw := mn.create_tween().set_loops()
		tw.tween_property(mn, "position:y", mn.position.y + 0.35, gerador.randf_range(1.5, 2.5)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mn, "position:y", mn.position.y, gerador.randf_range(1.5, 2.5)).set_trans(Tween.TRANS_SINE)
	return raiz


func _criar_obstaculo(pos: Vector3, raio: float, altura: float, estilo: String, cor_chao: Color) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = pos
	add_child(corpo)
	obstaculos.append({"corpo": corpo, "centro": Vector2(pos.x, pos.z), "raio": raio, "altura": altura,
		"vida": 40.0 + altura * 12.0 + raio * 25.0})
	var forma := CylinderShape3D.new()
	forma.radius = raio
	forma.height = altura
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position.y = altura / 2.0
	corpo.add_child(col)

	Cenario.construir_obstaculo(corpo, raio, altura, estilo, cor_chao)
