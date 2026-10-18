class_name Dialogo
extends Control
## Caixa de diálogo da campanha: ocupa a parte de baixo da tela, com o retrato à esquerda,
## o nome de quem fala e o texto aparecendo letra a letra. Toque/clique/Enter avança
## (ou completa a fala atual) e o botão PULAR encerra tudo.
##
## Uso:  var d := Dialogo.new(); d.falas = [...]; add_child(d); await d.terminou
## Cada fala: {"nome": "Guardiã Lira", "texto": "...", "retrato": {...}, "cor": "#hex" (opcional)}
## Retratos: {"tipo": "monstro", "id": "tigrana"}        carta do monstro (modelo 3D)
##           {"tipo": "mentor"}                           símbolo dourado da Guardiã
##           {"tipo": "coro"}                             octógono partido do Coro
##           {"tipo": "carta", "carta": "equipamento", "id": "..."}  recompensa (qualquer carta)
##           {"tipo": "estrelas", "quantidade": 2}       estrelas conquistadas (pulam)
##           {"tipo": "trofeu"}                           título conquistado
## "confete": true numa fala solta confete colorido (vitória).

signal terminou

const LETRAS_POR_SEGUNDO := 48.0
const ALTURA_CAIXA := 300.0
const MARGEM := 40.0

var falas: Array = []

var _indice := -1
var _caixa: PanelContainer
var _nome: Label
var _texto: Label
var _zona_retrato: Control
var _retrato: Control
var _dica: Label
var _letras := 0.0
var _t := 0.0
var _confete := false
var _confete_t := 0.0
var _encerrado := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_construir()
	_avancar()


func _process(delta: float) -> void:
	_t += delta
	if _texto.visible_characters >= 0 and _texto.visible_characters < _texto.text.length():
		_letras += delta * LETRAS_POR_SEGUNDO
		_texto.visible_characters = int(_letras)
		if _texto.visible_characters >= _texto.text.length():
			_texto.visible_characters = -1
	_dica.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
	if _confete:
		_confete_t += delta
	queue_redraw()


func _draw() -> void:
	# Véu escuro para destacar a caixa (mais forte embaixo).
	Tema.gradiente(self, Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.08), Color(0, 0, 0, 0.55))
	if _confete:
		_desenhar_confete()


func _desenhar_confete() -> void:
	var cores := [Tema.OURO, Color("#ff5a2a"), Color("#3fc8f0"), Color("#3ddc84"), Color("#ff6bd6"), Color.WHITE]
	for i in 90:
		var semente := float(i) * 7.31
		var x := fposmod(semente * 53.7, size.x) + sin(_confete_t * 2.0 + semente) * 30.0
		var y := fposmod(_confete_t * (160.0 + fposmod(semente * 11.0, 120.0)) + semente * 97.0, size.y + 60.0) - 40.0
		var ang := _confete_t * 3.0 + semente
		draw_set_transform(Vector2(x, y), ang, Vector2.ONE)
		draw_rect(Rect2(-9, -5, 18, 10), cores[i % cores.size()])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _construir() -> void:
	_caixa = PanelContainer.new()
	_caixa.anchor_left = 0.0
	_caixa.anchor_right = 1.0
	_caixa.anchor_top = 1.0
	_caixa.anchor_bottom = 1.0
	_caixa.offset_left = MARGEM
	_caixa.offset_right = -MARGEM
	_caixa.offset_top = -ALTURA_CAIXA - MARGEM
	_caixa.offset_bottom = -MARGEM
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_theme_stylebox_override("panel", Tema.caixa(Color("#141c2a", 0.96), Tema.OURO, 4, 26, Color(Tema.OURO, 0.25), 16))
	add_child(_caixa)

	# Retrato: à esquerda, saindo um pouco por cima da caixa.
	_zona_retrato = Control.new()
	_zona_retrato.anchor_left = 0.0
	_zona_retrato.anchor_right = 0.0
	_zona_retrato.anchor_top = 1.0
	_zona_retrato.anchor_bottom = 1.0
	_zona_retrato.offset_left = MARGEM + 28
	_zona_retrato.offset_right = MARGEM + 28 + 250
	_zona_retrato.offset_top = -ALTURA_CAIXA - MARGEM - 70
	_zona_retrato.offset_bottom = -MARGEM - 22
	_zona_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zona_retrato)

	_nome = Label.new()
	_nome.anchor_left = 0.0
	_nome.anchor_right = 0.0
	_nome.anchor_top = 1.0
	_nome.anchor_bottom = 1.0
	_nome.offset_left = MARGEM + 310
	_nome.offset_right = MARGEM + 310 + 900
	_nome.offset_top = -ALTURA_CAIXA - MARGEM + 22
	_nome.offset_bottom = -ALTURA_CAIXA - MARGEM + 78
	_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nome.add_theme_font_override("font", Tema.fonte("titulo"))
	_nome.add_theme_font_size_override("font_size", 38)
	_nome.add_theme_color_override("font_color", Tema.OURO_CLARO)
	add_child(_nome)

	_texto = Label.new()
	_texto.anchor_left = 0.0
	_texto.anchor_right = 1.0
	_texto.anchor_top = 1.0
	_texto.anchor_bottom = 1.0
	_texto.offset_left = MARGEM + 310
	_texto.offset_right = -MARGEM - 60
	_texto.offset_top = -ALTURA_CAIXA - MARGEM + 90
	_texto.offset_bottom = -MARGEM - 60
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_override("font", Tema.fonte("texto_negrito"))
	_texto.add_theme_font_size_override("font_size", 40)
	_texto.add_theme_color_override("font_color", Tema.TEXTO)
	add_child(_texto)

	_dica = Label.new()
	_dica.text = "Toque para continuar  ▶"
	_dica.anchor_left = 1.0
	_dica.anchor_right = 1.0
	_dica.anchor_top = 1.0
	_dica.anchor_bottom = 1.0
	_dica.offset_left = -MARGEM - 520
	_dica.offset_right = -MARGEM - 40
	_dica.offset_top = -MARGEM - 58
	_dica.offset_bottom = -MARGEM - 18
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.add_theme_font_override("font", Tema.fonte("texto_negrito"))
	_dica.add_theme_font_size_override("font_size", 24)
	_dica.add_theme_color_override("font_color", Tema.OURO)
	add_child(_dica)

	var pular := MenuTitulo.botao_grande("PULAR  ▶▶", Color("#3a4657"), Vector2(220, 70), 28)
	pular.anchor_left = 1.0
	pular.anchor_right = 1.0
	pular.anchor_top = 1.0
	pular.anchor_bottom = 1.0
	pular.offset_left = -MARGEM - 240
	pular.offset_right = -MARGEM - 20
	pular.offset_top = -ALTURA_CAIXA - MARGEM - 36
	pular.offset_bottom = -ALTURA_CAIXA - MARGEM + 34
	pular.pressed.connect(func():
		Audio.tocar("voltar")
		_encerrar())
	add_child(pular)


# ---------------------------------------------------------------------
# Fluxo
# ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var botao := event as InputEventMouseButton
	var toque := event as InputEventScreenTouch
	if (botao and botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT) or (toque and toque.pressed):
		_toque()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_toque()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_encerrar()
		get_viewport().set_input_as_handled()


func _toque() -> void:
	if _encerrado:
		return
	if _texto.visible_characters >= 0 and _texto.visible_characters < _texto.text.length():
		_texto.visible_characters = -1
		return
	_avancar()


func _avancar() -> void:
	_indice += 1
	if _indice >= falas.size():
		_encerrar()
		return
	var fala: Dictionary = falas[_indice]
	_nome.text = str(fala.get("nome", ""))
	_nome.add_theme_color_override("font_color", Color(str(fala.get("cor", "#ffe3a0"))))
	_texto.text = str(fala.get("texto", ""))
	_texto.visible_characters = 0
	_letras = 0.0
	_confete = bool(fala.get("confete", false))
	_confete_t = 0.0
	_mostrar_retrato(fala.get("retrato", {}))
	Audio.tocar("carta" if str(fala.get("retrato", {}).get("tipo", "")) in ["carta", "estrelas", "trofeu"] else "clique")
	if str(fala.get("retrato", {}).get("tipo", "")) == "estrelas":
		Audio.tocar("estrela")


func _encerrar() -> void:
	if _encerrado:
		return
	_encerrado = true
	terminou.emit()
	queue_free()


# ---------------------------------------------------------------------
# Retratos
# ---------------------------------------------------------------------

func _mostrar_retrato(retrato: Dictionary) -> void:
	if is_instance_valid(_retrato):
		_retrato.queue_free()
	_retrato = null
	var tipo := str(retrato.get("tipo", ""))
	var tamanho := _zona_retrato.size
	match tipo:
		"monstro", "carta":
			var carta := CartaVisual.new()
			var tipo_carta := "monstro" if tipo == "monstro" else str(retrato.get("carta", "monstro"))
			carta.definir(tipo_carta, str(retrato.get("id", "")))
			carta.size = tamanho
			_retrato = carta
			if tipo == "carta":
				_retrato.add_child(Desenho.criar(func(ci: Desenho): _raios(ci), Vector2(-60, -60), tamanho + Vector2(120, 120), true))
				_retrato.move_child(_retrato.get_child(-1), 0)
		"mentor":
			_retrato = Desenho.criar(func(ci: Desenho): _retrato_mentor(ci), Vector2.ZERO, tamanho, true)
		"coro":
			_retrato = Desenho.criar(func(ci: Desenho): _retrato_coro(ci), Vector2.ZERO, tamanho, true)
		"estrelas":
			var quantidade := int(retrato.get("quantidade", 1))
			_retrato = Desenho.criar(func(ci: Desenho): _retrato_estrelas(ci, quantidade), Vector2.ZERO, tamanho, true)
		"trofeu":
			_retrato = Desenho.criar(func(ci: Desenho): _retrato_trofeu(ci), Vector2.ZERO, tamanho, true)
		_:
			return
	# Entrada animada (pulinho).
	_retrato.pivot_offset = tamanho / 2.0
	_retrato.scale = Vector2(0.6, 0.6)
	_zona_retrato.add_child(_retrato)
	var tw := _retrato.create_tween()
	tw.tween_property(_retrato, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _raios(ci: Desenho) -> void:
	var c := ci.size / 2.0
	for i in 12:
		var a := ci.tempo * 0.6 + i * TAU / 12.0
		var p1 := c + Vector2(cos(a), sin(a)) * ci.size.y * 0.75
		var p2 := c + Vector2(cos(a + 0.12), sin(a + 0.12)) * ci.size.y * 0.75
		ci.draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(Tema.OURO_CLARO, 0.22))


func _retrato_mentor(ci: Desenho) -> void:
	var c := ci.size / 2.0
	var r := minf(ci.size.x, ci.size.y) * 0.42
	ci.draw_style_box(Tema.caixa(Color("#2a2210"), Tema.OURO, 4, 20, Color(Tema.OURO, 0.35), 14), Rect2(Vector2.ZERO, ci.size))
	Tema.brilho_radial(ci, c, r * 1.1, Color(Tema.OURO, 0.35), 8)
	Icones.simbolo_cantico(ci, c + Vector2(0, -10), r * 0.85, Tema.OURO, "nota", 0.6 + 0.3 * sin(ci.tempo * 2.5))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, ci.size.y - 22), "Guardiã da Rede", 20, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _retrato_coro(ci: Desenho) -> void:
	var c := ci.size / 2.0
	var r := minf(ci.size.x, ci.size.y) * 0.4
	var roxo := Color("#9b4dff")
	ci.draw_style_box(Tema.caixa(Color("#120a1e"), roxo, 4, 20, Color(roxo, 0.4), 16), Rect2(Vector2.ZERO, ci.size))
	Tema.brilho_radial(ci, c, r * 1.15, Color(roxo, 0.35), 8)
	# Octógono partido ao meio, com as metades tremendo.
	var tremor := Vector2(sin(ci.tempo * 23.0) * 4.0, cos(ci.tempo * 17.0) * 3.0)
	var pts := Icones.octogono(c + Vector2(0, -10), r)
	var esquerda := PackedVector2Array([pts[3] + tremor, pts[4] + tremor, pts[5] + tremor, pts[6] + tremor, c + Vector2(6, 10) + tremor, c + Vector2(-8, -30) + tremor])
	var direita := PackedVector2Array([pts[7] - tremor, pts[0] - tremor, pts[1] - tremor, pts[2] - tremor, c + Vector2(4, -30) - tremor, c + Vector2(18, 10) - tremor])
	for metade in [esquerda, direita]:
		ci.draw_colored_polygon(metade, Color("#2a1448"))
		ci.draw_polyline(Icones.fechar(metade), roxo.lightened(0.3), 5.0, true)
	for i in 3:
		var p := c + Vector2(-40 + i * 40, -10) + Vector2(sin(ci.tempo * 9.0 + i) * 6.0, 0)
		ci.draw_circle(p, 7.0, Color("#e6c6ff"))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, ci.size.y - 22), "Coro do Horizonte", 19, Color("#e6c6ff"), ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _retrato_estrelas(ci: Desenho, quantidade: int) -> void:
	var c := ci.size / 2.0
	ci.draw_style_box(Tema.caixa(Color("#1c2a44"), Tema.OURO, 4, 20, Color(Tema.OURO, 0.4), 16), Rect2(Vector2.ZERO, ci.size))
	for i in 3:
		var ganhou := i < quantidade
		var atraso := i * 0.25
		var k := clampf((ci.tempo - atraso) * 3.0, 0.0, 1.0)
		var pulo := sin(k * PI) * 40.0
		var pos := c + Vector2((i - 1) * 74, (0 if i == 1 else 26) - pulo)
		var r := 34.0 * (0.4 + 0.6 * k) if ganhou else 30.0
		MenuTitulo.estrela(ci, pos, r, Tema.OURO_CLARO if ganhou else Color("#3a4657"))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, ci.size.y - 22), "%d de 3 estrelas" % quantidade, 22, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _retrato_trofeu(ci: Desenho) -> void:
	var c := ci.size / 2.0
	ci.draw_style_box(Tema.caixa(Color("#2a2210"), Tema.OURO, 4, 20, Color(Tema.OURO, 0.5), 20), Rect2(Vector2.ZERO, ci.size))
	_raios(ci)
	var r := 70.0
	var taca := PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r * 0.55, r * 0.2), c + Vector2(-r * 0.55, r * 0.2)])
	ci.draw_colored_polygon(taca, Tema.OURO)
	ci.draw_polyline(Icones.fechar(taca), Tema.OURO_ESCURO, 4.0, true)
	ci.draw_rect(Rect2(c + Vector2(-12, r * 0.2), Vector2(24, 34)), Tema.OURO_ESCURO)
	ci.draw_rect(Rect2(c + Vector2(-46, r * 0.2 + 34), Vector2(92, 18)), Tema.OURO)
	for lado in [-1, 1]:
		ci.draw_arc(c + Vector2(lado * r * 1.05, -r * 0.45), r * 0.4, 0, TAU, 20, Tema.OURO, 8.0, true)
	MenuTitulo.estrela(ci, c + Vector2(0, -r * 0.4), 28, Color.WHITE)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, ci.size.y - 22), "Título conquistado!", 20, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)
