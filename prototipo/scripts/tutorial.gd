class_name Tutorial
extends CanvasLayer
## Tutorial guiado da primeira luta: um passo por vez, num painel grande e amigável no alto da
## tela (sem cobrir as cartas), com uma seta pulsando no que a criança precisa fazer.
## Enquanto durar, a IA do inimigo fica passiva (ControleIA.passivo): só anda devagar.
## A Batalha cria esta camada quando config["tutorial"] é verdadeiro e preenche `batalha`.
##
## Passos: mover-se, golpe básico, esquiva, carta, pulo (ou subida, se o monstro voa),
## Cântico e "Agora vença!". Ao chegar no último, Jogo.progresso["tutorial_feito"] = true.

const DURACAO_ELOGIO := 1.1
const DURACAO_FINAL := 3.5
const ELOGIOS := ["Muito bem!", "Isso!", "Mandou bem!", "Boa!", "Demais!"]
const LARGURA_PAINEL := 1060.0
const TOPO_PAINEL := 196.0
## Base 1920x1080 da HUD: onde ficam a primeira carta e o painel do ritmo do Cântico.
const PONTO_CARTA := Vector2(732, 1080 - 268)
const PONTO_RITMO := Vector2(1920 - 260, 1080 - 200)

var batalha  # Batalha (sem tipo para evitar dependência cíclica)

var _passos: Array = []
var _passo := -1
var _feito := false
var _concluido := false
var _ia: ControleIA
var _jogador: Lutador
var _raiz: Control
var _painel: PanelContainer
var _progresso: Label
var _titulo: Label
var _corpo: Label
var _seta: Desenho
var _elogio: Label
var _andado := 0.0
var _pos_anterior := Vector3.INF
var _final_t := 0.0


func _ready() -> void:
	layer = 15
	_construir()
	call_deferred("_preparar")


# ---------------------------------------------------------------------
# Fluxo
# ---------------------------------------------------------------------

func _preparar() -> void:
	if batalha == null:
		return
	_jogador = batalha.jogador
	for no in batalha.inimigo.get_parent().get_children():
		if no is ControleIA and no.lutador == batalha.inimigo:
			_ia = no
	if _ia:
		_ia.passivo = true
	_jogador.dicas_ativas = false
	_jogador.acertou.connect(func(atk: Dictionary):
		if str(atk.get("arquetipo", "")) == "basico":
			_completar(1))
	_jogador.esquivou.connect(func(): _completar(2))
	_jogador.usou_carta.connect(func(_id: String): _completar(3))
	_jogador.pulou.connect(func(): _completar(4))
	_jogador.cantico_terminou.connect(func(_ok: bool): _completar(5))
	_passos = _montar_passos()


func _process(delta: float) -> void:
	if batalha == null or _jogador == null:
		return
	if _passo < 0:
		if bool(batalha.get("em_andamento")):
			_mostrar_passo(0)
		return
	if _concluido:
		_final_t -= delta
		if _final_t <= 0.0:
			queue_free()
		elif _final_t < 0.6:
			_painel.modulate.a = _final_t / 0.6
		return
	if not bool(batalha.get("em_andamento")):
		_encerrar()
		return
	if _passo == 0 and not _feito:
		# Soma quanto o jogador andou (só andando, sem contar esquivas, golpes e empurrões).
		var pos := _jogador.global_position
		pos.y = 0.0
		if _pos_anterior != Vector3.INF and _jogador.acao.is_empty() and _jogador.esquiva_t <= 0.0:
			_andado += pos.distance_to(_pos_anterior)
		_pos_anterior = pos
		if _andado >= 3.0:
			_completar(0)
	_posicionar_seta()


func _mostrar_passo(indice: int) -> void:
	if indice >= _passos.size():
		return
	_passo = indice
	_feito = false
	_elogio.visible = false
	var passo: Dictionary = _passos[indice]
	# Pula o Cântico se o monstro não tem carga ou carta de Cântico.
	if str(passo.get("chave", "")) == "cantico" and (_jogador.cargas_cantico <= 0 or _jogador.cantico.is_empty()):
		_mostrar_passo(indice + 1)
		return
	_progresso.text = "PASSO %d DE %d" % [indice + 1, _passos.size()]
	_titulo.text = str(passo["titulo"])
	_corpo.text = str(passo["texto"])
	_painel.visible = true
	_painel.modulate.a = 1.0
	_painel.pivot_offset = _painel.size / 2.0
	_painel.scale = Vector2(0.8, 0.8)
	var tw := _painel.create_tween()
	tw.tween_property(_painel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_seta.visible = str(passo.get("alvo", "")) != ""
	Audio.tocar("clique")
	if indice == _passos.size() - 1:
		_terminar()


func _completar(indice: int) -> void:
	if _passo != indice or _feito or _concluido:
		return
	_feito = true
	_seta.visible = false
	_elogio.text = ELOGIOS[randi() % ELOGIOS.size()]
	_elogio.visible = true
	_elogio.pivot_offset = _elogio.size / 2.0
	_elogio.scale = Vector2(0.5, 0.5)
	var tw := _elogio.create_tween()
	tw.tween_property(_elogio, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.tocar("confirmar")
	await get_tree().create_timer(DURACAO_ELOGIO).timeout
	if is_inside_tree() and not _concluido:
		_mostrar_passo(indice + 1)


## Último passo: o inimigo volta a lutar e o tutorial fica registrado como feito.
func _terminar() -> void:
	_concluido = true
	_final_t = DURACAO_FINAL
	_seta.visible = false
	if _ia:
		_ia.passivo = false
	_jogador.dicas_ativas = true
	Jogo.progresso["tutorial_feito"] = true
	Jogo.salvar()
	Audio.tocar("estrela")


## A luta acabou antes do fim do tutorial: libera tudo sem marcar como feito.
func _encerrar() -> void:
	_concluido = true
	_final_t = 0.0
	if _ia:
		_ia.passivo = false
	_jogador.dicas_ativas = true


# ---------------------------------------------------------------------
# Textos (dependem de toque, controle ou teclado)
# ---------------------------------------------------------------------

func _modo_entrada() -> String:
	if Jogo.toque_ativo():
		return "toque"
	if not Input.get_connected_joypads().is_empty():
		return "controle"
	return "teclado"


func _montar_passos() -> Array:
	var modo := _modo_entrada()
	var voa := _jogador.voa
	var textos := {
		"mover": {"toque": "Arraste o joystick da esquerda.", "controle": "Empurre o analógico esquerdo.",
			"teclado": "Use W A S D ou as setas."},
		"golpe": {"toque": "Chegue perto e toque no botão GOLPE.", "controle": "Chegue perto e aperte X.",
			"teclado": "Chegue perto e clique ou aperte J."},
		"esquivar": {"toque": "Toque no botão ESQUIVA.", "controle": "Aperte B.", "teclado": "Aperte Shift."},
		"carta": {"toque": "Toque numa carta lá embaixo.", "controle": "Aperte LB, Y ou RB.",
			"teclado": "Aperte 1, 2 ou 3 (ou clique na carta)."},
		"pular": {"toque": "Toque no botão PULO.", "controle": "Aperte A.", "teclado": "Aperte Espaço."},
		"cantico": {"toque": "Toque em CÂNTICO e depois nas setas que aparecem.",
			"controle": "Aperte RT e depois as setas no direcional.",
			"teclado": "Aperte Q e depois as letras que aparecem."},
	}
	return [
		{"chave": "mover", "titulo": "Mova-se!", "texto": textos["mover"][modo], "alvo": "jogador"},
		{"chave": "golpe", "titulo": "Dê um golpe!", "texto": textos["golpe"][modo], "alvo": "inimigo"},
		{"chave": "esquivar", "titulo": "Esquive!", "texto": textos["esquivar"][modo], "alvo": "jogador"},
		{"chave": "carta", "titulo": "Use uma carta!", "texto": textos["carta"][modo], "alvo": "carta"},
		{"chave": "pular", "titulo": "Suba!" if voa else "Pule!", "texto": textos["pular"][modo], "alvo": "jogador"},
		{"chave": "cantico", "titulo": "Cante o Cântico!", "texto": textos["cantico"][modo], "alvo": "ritmo"},
		{"chave": "fim", "titulo": "Agora vença!", "texto": "Zere a Energia do inimigo. Você consegue!", "alvo": ""},
	]


# ---------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_theme_stylebox_override("panel", Tema.caixa(Color(Tema.CARVAO, 0.93), Tema.OURO, 4, 24, Color(Tema.OURO, 0.35), 22))
	_painel.anchor_left = 0.5
	_painel.anchor_right = 0.5
	_painel.offset_left = -LARGURA_PAINEL / 2.0
	_painel.offset_right = LARGURA_PAINEL / 2.0
	_painel.offset_top = TOPO_PAINEL
	_painel.offset_bottom = TOPO_PAINEL + 190
	_painel.visible = false
	_raiz.add_child(_painel)
	var margem := MarginContainer.new()
	for lado in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(lado, 36)
	margem.add_theme_constant_override("margin_top", 12)
	margem.add_theme_constant_override("margin_bottom", 16)
	_painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 2)
	margem.add_child(coluna)
	_progresso = _rotulo("", 22, Tema.OURO, "texto_negrito")
	coluna.add_child(_progresso)
	_titulo = _rotulo("", 52, Tema.OURO_CLARO, "titulo")
	coluna.add_child(_titulo)
	_corpo = _rotulo("", 36, Tema.TEXTO, "texto")
	_corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_corpo)

	_seta = Desenho.criar(_desenhar_seta, Vector2.ZERO, Vector2(140, 150), true)
	_seta.visible = false
	_raiz.add_child(_seta)

	_elogio = _rotulo("", 84, Tema.OURO_CLARO, "titulo")
	_elogio.anchor_left = 0.5
	_elogio.anchor_right = 0.5
	_elogio.offset_left = -500
	_elogio.offset_right = 500
	_elogio.offset_top = TOPO_PAINEL + 30
	_elogio.offset_bottom = TOPO_PAINEL + 150
	_elogio.add_theme_constant_override("outline_size", 18)
	_elogio.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.02, 0.95))
	_elogio.visible = false
	_raiz.add_child(_elogio)


func _rotulo(texto: String, tamanho: int, cor: Color, fonte: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Tema.fonte(fonte))
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	return l


# ---------------------------------------------------------------------
# Seta que aponta o que fazer
# ---------------------------------------------------------------------

## Coloca a seta acima do alvo do passo (monstro projetado da cena 3D, carta ou painel do ritmo).
func _posicionar_seta() -> void:
	if not _seta.visible or _passo < 0:
		return
	var ponto := Vector2.ZERO
	match str(_passos[_passo].get("alvo", "")):
		"jogador":
			ponto = _projetar(_jogador)
		"inimigo":
			ponto = _projetar(batalha.inimigo)
		"carta":
			ponto = PONTO_CARTA
		"ritmo":
			ponto = PONTO_RITMO
	if ponto == Vector2.INF:
		_seta.modulate.a = 0.0
		return
	_seta.modulate.a = 1.0
	ponto.x = clampf(ponto.x, 90.0, 1830.0)
	ponto.y = clampf(ponto.y, TOPO_PAINEL + 200 + 150, 1000.0)
	_seta.position = ponto - Vector2(_seta.size.x / 2.0, _seta.size.y)


## Ponto da tela (base 1920x1080) acima da cabeça de um lutador; INF se estiver atrás da câmera.
func _projetar(l: Lutador) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or l == null:
		return Vector2.INF
	var pos := l.global_position + Vector3(0, 2.6 * l.escala, 0)
	if cam.is_position_behind(pos):
		return Vector2.INF
	return cam.unproject_position(pos)


func _desenhar_seta(ci: Desenho) -> void:
	var w := ci.size.x
	var salto := absf(sin(ci.tempo * 5.0)) * 22.0
	var cx := w / 2.0
	var topo := 10.0 + salto
	var base := ci.size.y - 10.0 + salto - 22.0
	var pts := PackedVector2Array([
		Vector2(cx - 18, topo), Vector2(cx + 18, topo), Vector2(cx + 18, base - 58),
		Vector2(cx + 56, base - 58), Vector2(cx, base), Vector2(cx - 56, base - 58), Vector2(cx - 18, base - 58),
	])
	ci.draw_colored_polygon(pts, Tema.OURO_CLARO)
	ci.draw_polyline(Icones.fechar(pts), Color(0.3, 0.12, 0.02, 0.95), 6.0, true)
	# Brilho pulsante atrás da ponta.
	var brilho := 0.25 + 0.2 * sin(ci.tempo * 5.0)
	ci.draw_circle(Vector2(cx, base - 20), 46.0, Color(Tema.OURO, brilho * 0.5))
