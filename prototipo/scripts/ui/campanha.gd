class_name Campanha
extends Control
## Mapa da campanha: uma trilha de nós (círculos grandes com o ícone da facção, estrelas
## conquistadas e cadeado nos bloqueados). O nó atual pulsa; tocar num nó liberado o
## seleciona; JOGAR inicia a etapa. Setas ‹ › mudam de circuito.

signal jogar(circuito: int, etapa: int)
signal voltar

const COR_CORO := Color("#9b4dff")
const POSICOES_NOS := [Vector2(330, 470), Vector2(760, 400), Vector2(1180, 470), Vector2(1620, 390)]

var circuito := 0
var etapa := 0

var _palco: Control
var _nos: Array = []
var _titulo: Label
var _descricao: Label
var _estrelas_circuito: Label
var _etapa_titulo: Label
var _etapa_frase: Label
var _regra: Label
var _carta_inimigo: CartaVisual
var _carta_local: CartaVisual
var _botao_jogar: Button
var _seta_esq: Button
var _seta_dir: Button
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Tema.criar_tema()
	var proxima := Jogo.proxima_etapa()
	circuito = clampi(int(proxima["circuito"]), 0, maxi(0, Jogo.circuitos().size() - 1))
	etapa = int(proxima["etapa"])
	_construir()
	_atualizar()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var cor := _cor_circuito()
	Tema.gradiente(self, Rect2(Vector2.ZERO, size), cor.darkened(0.85), Color("#0c121c"))
	Tema.brilho_radial(self, size * Vector2(0.5, 0.42), size.y * 0.7, Color(cor, 0.18), 8)
	# Anéis octogonais girando devagar atrás da trilha, na cor da facção.
	var centro := size * Vector2(0.5, 0.42)
	for i in 4:
		var raio := size.y * (0.22 + 0.13 * i)
		draw_polyline(Icones.fechar(Icones.octogono(centro, raio, _t * 0.04 * (1 if i % 2 == 0 else -1) + i * 0.3)), Color(cor, 0.16 - 0.03 * i), 10.0, true)


func _cor_circuito() -> Color:
	var c: Dictionary = Jogo.circuito(circuito)
	var fac := str(c.get("faccao", ""))
	if fac == "coro":
		return COR_CORO
	return Color(str(Dados.faccao(fac).get("cor", "#8a97ab")))


# ---------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------

func _construir() -> void:
	_palco = MenuTitulo.palco_central(self)

	# Cabeçalho: setas de circuito, título e estrelas.
	_seta_esq = _seta("‹", Vector2(300, 30))
	_seta_esq.pressed.connect(func(): _mudar_circuito(-1))
	_palco.add_child(_seta_esq)
	_seta_dir = _seta("›", Vector2(1520, 30))
	_seta_dir.pressed.connect(func(): _mudar_circuito(1))
	_palco.add_child(_seta_dir)
	_titulo = _rotulo("", Vector2(400, 36), "titulo", 62, Tema.OURO_CLARO)
	_titulo.size = Vector2(1120, 80)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_constant_override("outline_size", 8)
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_palco.add_child(_titulo)
	_descricao = _rotulo("", Vector2(400, 118), "texto_negrito", 26, Tema.TEXTO)
	_descricao.size = Vector2(1120, 40)
	_descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_palco.add_child(_descricao)
	_estrelas_circuito = _rotulo("", Vector2(1560, 120), "titulo", 30, Tema.OURO_CLARO)
	_estrelas_circuito.size = Vector2(330, 40)
	_estrelas_circuito.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_palco.add_child(_estrelas_circuito)
	_palco.add_child(Desenho.criar(func(ci: Control):
		MenuTitulo.estrela(ci, Vector2(22, 22), 20, Tema.OURO_CLARO)
		Tema.texto(ci, Tema.fonte("titulo"), Vector2(52, 33), "%d" % Jogo.total_estrelas(), 32, Tema.OURO_CLARO), Vector2(40, 110), Vector2(200, 44)))

	# Trilha: ligações desenhadas atrás e os nós por cima.
	_palco.add_child(Desenho.criar(func(ci: Desenho): _desenhar_trilha(ci), Vector2.ZERO, Vector2(1920, 1080), true))
	for i in POSICOES_NOS.size():
		var no := No.new()
		no.mapa = self
		no.indice = i
		no.position = POSICOES_NOS[i] - Vector2(150, 150)
		no.size = Vector2(300, 300)
		no.tocado.connect(_selecionar)
		_palco.add_child(no)
		_nos.append(no)

	# Painel da etapa selecionada.
	var painel := Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.82), Color(Tema.OURO, 0.6), 3, 24), Rect2(Vector2.ZERO, ci.size)), Vector2(60, 700), Vector2(1180, 330))
	_palco.add_child(painel)
	_carta_inimigo = CartaVisual.new()
	_carta_inimigo.position = Vector2(84, 716)
	_carta_inimigo.size = Vector2(200, 300)
	_palco.add_child(_carta_inimigo)
	_carta_local = CartaVisual.new()
	_carta_local.position = Vector2(300, 716)
	_carta_local.size = Vector2(200, 300)
	_palco.add_child(_carta_local)
	_etapa_titulo = _rotulo("", Vector2(530, 724), "titulo", 46, Tema.OURO_CLARO)
	_etapa_titulo.size = Vector2(690, 60)
	_etapa_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palco.add_child(_etapa_titulo)
	_etapa_frase = _rotulo("", Vector2(530, 800), "texto_negrito", 30, Tema.TEXTO)
	_etapa_frase.size = Vector2(690, 80)
	_etapa_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palco.add_child(_etapa_frase)
	_regra = _rotulo("", Vector2(530, 900), "texto_negrito", 24, Color("#ffb38a"))
	_regra.size = Vector2(690, 110)
	_regra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palco.add_child(_regra)

	_botao_jogar = MenuTitulo.botao_grande("JOGAR!", Color("#8a1a14"), Vector2(600, 150), 64)
	_botao_jogar.position = Vector2(1280, 760)
	_botao_jogar.pressed.connect(func():
		if not Jogo.etapa_liberada(circuito, etapa):
			Audio.tocar("aviso")
			return
		Audio.tocar("confirmar")
		jogar.emit(circuito, etapa))
	_palco.add_child(_botao_jogar)

	var botao_voltar := MenuTitulo.botao_grande("◀  VOLTAR", Color("#3a4657"), Vector2(300, 90), 32)
	botao_voltar.position = Vector2(1280, 930)
	botao_voltar.pressed.connect(func():
		Audio.tocar("voltar")
		voltar.emit())
	_palco.add_child(botao_voltar)


func _seta(texto: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = texto
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(100, 120)
	b.add_theme_font_override("font", Tema.fonte("titulo"))
	b.add_theme_font_size_override("font_size", 110)
	b.add_theme_color_override("font_color", Tema.OURO)
	b.add_theme_color_override("font_hover_color", Tema.OURO_CLARO)
	b.add_theme_color_override("font_disabled_color", Color(Tema.TEXTO, 0.15))
	return b


func _rotulo(texto: String, pos: Vector2, fonte: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Tema.fonte(fonte))
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


# ---------------------------------------------------------------------
# Comportamento
# ---------------------------------------------------------------------

func _mudar_circuito(passo: int) -> void:
	var novo := clampi(circuito + passo, 0, Jogo.circuitos().size() - 1)
	if novo == circuito:
		return
	Audio.tocar("carta")
	circuito = novo
	# Seleciona a etapa atual se for este circuito; senão a última liberada.
	var proxima := Jogo.proxima_etapa()
	if int(proxima["circuito"]) == circuito:
		etapa = int(proxima["etapa"])
	else:
		etapa = 0
		for e in Jogo.etapas(circuito).size():
			if Jogo.etapa_liberada(circuito, e):
				etapa = e
	_atualizar()


func _selecionar(indice: int) -> void:
	if not Jogo.etapa_liberada(circuito, indice):
		Audio.tocar("aviso")
		return
	Audio.tocar("clique")
	etapa = indice
	_atualizar()


func _atualizar() -> void:
	var c: Dictionary = Jogo.circuito(circuito)
	var lista := Jogo.etapas(circuito)
	_titulo.text = str(c.get("nome", "Campanha"))
	_titulo.add_theme_color_override("font_color", _cor_circuito().lightened(0.45))
	_descricao.text = str(c.get("descricao", ""))
	_estrelas_circuito.text = "★ %d / %d" % [Jogo.estrelas_do_circuito(circuito), lista.size() * 3]
	_seta_esq.disabled = circuito <= 0
	_seta_dir.disabled = circuito >= Jogo.circuitos().size() - 1
	for no in _nos:
		no.visible = int(no.indice) < lista.size()
		no.queue_redraw()
	var et := Jogo.etapa(circuito, etapa)
	var liberada := Jogo.etapa_liberada(circuito, etapa)
	_etapa_titulo.text = ("CHEFE: " if bool(et.get("chefe", false)) else "") + str(et.get("titulo", ""))
	_etapa_frase.text = str(et.get("frase", "")) if liberada else "Vença a etapa anterior para liberar!"
	_regra.text = ("Regra do chefe: " + str(et.get("regra", ""))) if liberada and et.has("regra") else ""
	var inimigo: Dictionary = et.get("inimigo", {})
	_carta_inimigo.definir("monstro", str(inimigo.get("monstro", "")))
	_carta_inimigo.desabilitada = not liberada
	_carta_local.definir("local", Jogo.local_da_etapa(circuito, etapa))
	_carta_local.desabilitada = not liberada
	_botao_jogar.disabled = not liberada
	_botao_jogar.text = "JOGAR!" if not Jogo.etapa_vencida(circuito, etapa) else "DE NOVO!"


# ---------------------------------------------------------------------
# Desenho da trilha
# ---------------------------------------------------------------------

func _desenhar_trilha(ci: Desenho) -> void:
	var lista := Jogo.etapas(circuito)
	for i in range(1, mini(lista.size(), POSICOES_NOS.size())):
		var a: Vector2 = POSICOES_NOS[i - 1]
		var b: Vector2 = POSICOES_NOS[i]
		var liberada := Jogo.etapa_liberada(circuito, i)
		var cor := Tema.OURO if liberada else Color(Tema.MEDIO, 0.8)
		ci.draw_line(a, b, Color(0, 0, 0, 0.45), 26.0, true)
		if liberada:
			ci.draw_line(a, b, cor, 14.0, true)
		else:
			var n := 9
			for k in n:
				var p1 := a.lerp(b, (k + 0.15) / n)
				var p2 := a.lerp(b, (k + 0.65) / n)
				ci.draw_line(p1, p2, cor, 12.0, true)
		# Pontinhos andando na trilha liberada.
		if liberada:
			for k in 3:
				var t := fposmod(ci.tempo * 0.25 + k / 3.0, 1.0)
				ci.draw_circle(a.lerp(b, t), 7.0, Tema.OURO_CLARO)


## Um nó da trilha (círculo grande): desenha e recebe toques.
class No extends Control:
	signal tocado(indice: int)

	var mapa: Campanha
	var indice := 0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var botao := event as InputEventMouseButton
		var toque := event as InputEventScreenTouch
		if (botao and botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT) or (toque and toque.pressed):
			tocado.emit(indice)
			accept_event()

	func _draw() -> void:
		var c := size / 2.0 - Vector2(0, 20)
		var et := Jogo.etapa(mapa.circuito, indice)
		var chefe := bool(et.get("chefe", false))
		var liberada := Jogo.etapa_liberada(mapa.circuito, indice)
		var vencida := Jogo.etapa_vencida(mapa.circuito, indice)
		var proxima := Jogo.proxima_etapa()
		var atual := int(proxima["circuito"]) == mapa.circuito and int(proxima["etapa"]) == indice and not Jogo.campanha_concluida()
		var selecionado := mapa.etapa == indice
		var r := 96.0 if chefe else 80.0
		var cor := mapa._cor_circuito()
		if not liberada:
			cor = Color("#55606f")
		# Pulso do nó atual e anel de seleção.
		if atual:
			var pulso := 1.0 + 0.08 * sin(_t * 4.0)
			draw_circle(c, r * 1.25 * pulso, Color(Tema.OURO_CLARO, 0.18))
			draw_arc(c, r * 1.18 * pulso, 0, TAU, 48, Tema.OURO_CLARO, 5.0, true)
		if selecionado:
			draw_arc(c, r * 1.1, 0, TAU, 48, Color.WHITE, 6.0, true)
		# Coroa do chefe.
		if chefe:
			var pts := PackedVector2Array()
			for i in 7:
				var a := -PI / 2.0 + (i - 3) * 0.3
				pts.append(c + Vector2(cos(a), sin(a)) * (r + (34.0 if i % 2 == 0 else 14.0)))
			pts.append(c + Vector2(cos(-PI / 2.0 + 0.95), sin(-PI / 2.0 + 0.95)) * r)
			pts.append(c + Vector2(cos(-PI / 2.0 - 0.95), sin(-PI / 2.0 - 0.95)) * r)
			draw_colored_polygon(pts, Tema.OURO if liberada else Color("#55606f"))
			draw_polyline(Icones.fechar(pts), Color(0.25, 0.15, 0.02, 0.9), 3.0, true)
		# Círculo principal.
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.45))
		draw_circle(c, r, cor.darkened(0.55))
		draw_arc(c, r - 4, 0, TAU, 64, cor.lightened(0.1), 9.0, true)
		draw_arc(c, r, 0, TAU, 64, Color(0.05, 0.03, 0.08, 0.9), 3.0, true)
		# Ícone: emblema da facção ou cadeado.
		if liberada:
			var fac := str(Jogo.circuito(mapa.circuito).get("faccao", ""))
			if fac == "coro":
				draw_polyline(Icones.fechar(Icones.octogono(c, r * 0.5, _t * 0.5)), Color("#e6c6ff"), 7.0, true)
				draw_circle(c, r * 0.14, Color("#e6c6ff"))
			else:
				Icones.emblema(self, Dados.faccao(fac), c, r * 0.52)
			if vencida:
				draw_circle(c + Vector2(r * 0.7, -r * 0.7), 22, Tema.VERDE_ATIVO)
				draw_arc(c + Vector2(r * 0.7, -r * 0.7), 22, 0, TAU, 24, Color(0.05, 0.03, 0.08, 0.9), 3.0, true)
				draw_polyline(PackedVector2Array([c + Vector2(r * 0.7 - 10, -r * 0.7), c + Vector2(r * 0.7 - 3, -r * 0.7 + 8), c + Vector2(r * 0.7 + 11, -r * 0.7 - 9)]), Color.WHITE, 5.0, true)
		else:
			MenuTitulo.cadeado(self, c, r * 0.38, Color("#aab4c4"))
		# Número da etapa e estrelas.
		Tema.texto(self, Tema.fonte("titulo"), Vector2(0, c.y + r + 36), "%d" % (indice + 1), 30, Tema.TEXTO, size.x, HORIZONTAL_ALIGNMENT_CENTER, 5)
		var estrelas := Jogo.estrelas(mapa.circuito, indice)
		for i in 3:
			var p := Vector2(c.x + (i - 1) * 46, c.y + r + 72)
			MenuTitulo.estrela(self, p, 20, Tema.OURO_CLARO if i < estrelas else Color(Tema.CARVAO, 0.8))
