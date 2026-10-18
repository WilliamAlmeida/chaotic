class_name MenuTitulo
extends Control
## Tela de título: logo com brilho, símbolos das facções girando ao fundo e botões enormes:
## JOGAR HISTÓRIA (campanha), DUELO RÁPIDO (loadout livre) e OPÇÕES. O rodapé mostra as
## estrelas e as vitórias do jogador (Jogo.progresso).
##
## Também guarda os ajudantes de interface usados pelas outras telas do jogo completo
## (botão grande colorido, estrela e cadeado), para não repetir código.

signal campanha
signal duelo_rapido
signal opcoes

const COR_HISTORIA := Color("#8a1a14")
const COR_DUELO := Color("#1b4f8a")
const COR_OPCOES := Color("#3a4657")

var _palco: Control
var _logo: Label
var _continuar: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Tema.criar_tema()
	_construir()


func _process(delta: float) -> void:
	_t += delta
	# Respiração suave do logo.
	var s := 1.0 + 0.02 * sin(_t * 1.6)
	_logo.scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	Tema.gradiente(self, r, Color("#0c121c"), Color("#1a2438"))
	Tema.brilho_radial(self, size * Vector2(0.5, 0.36), size.y * 0.55, Color(0.95, 0.75, 0.35, 0.16 + 0.05 * sin(_t * 1.6)), 10)
	# Símbolos das facções girando devagar nos cantos (fundo decorativo).
	var faccoes: Array = Dados.faccoes.keys()
	var posicoes := [Vector2(0.12, 0.2), Vector2(0.88, 0.2), Vector2(0.1, 0.82), Vector2(0.9, 0.82)]
	for i in faccoes.size():
		if i >= posicoes.size():
			break
		var f: Dictionary = Dados.faccoes[faccoes[i]]
		var c: Vector2 = size * posicoes[i]
		var raio := size.y * 0.14
		var ang := _t * 0.12 * (1.0 if i % 2 == 0 else -1.0) + i * 0.7
		draw_set_transform(c, ang, Vector2.ONE)
		Icones.simbolo_cantico(self, Vector2.ZERO, raio, Color(Color(str(f["cor"])), 0.34), str(f["marca"]), 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Estrelinhas cintilando.
	for i in 26:
		var p := Vector2(fposmod(i * 311.7, size.x), fposmod(i * 197.3, size.y))
		var a := 0.25 + 0.25 * sin(_t * 2.0 + i)
		draw_circle(p, 2.5, Color(1, 0.95, 0.8, a))


func _construir() -> void:
	_palco = palco_central(self)

	# Logo com brilho.
	_logo = Label.new()
	_logo.text = "ECOS DE AETHERIS"
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.add_theme_font_override("font", Tema.fonte("titulo"))
	_logo.add_theme_font_size_override("font_size", 112)
	_logo.add_theme_color_override("font_color", Tema.OURO_CLARO)
	_logo.add_theme_color_override("font_shadow_color", Color(0.45, 0.2, 0.0, 0.9))
	_logo.add_theme_constant_override("shadow_offset_x", 5)
	_logo.add_theme_constant_override("shadow_offset_y", 6)
	_logo.add_theme_constant_override("outline_size", 10)
	_logo.add_theme_color_override("font_outline_color", Color("#3a1a08"))
	_logo.position = Vector2(160, 120)
	_logo.size = Vector2(1600, 150)
	_logo.pivot_offset = _logo.size / 2.0
	_palco.add_child(_logo)

	var sub := Label.new()
	sub.text = "A Rede dos Ecos precisa de você!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", Tema.fonte("texto_negrito"))
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Tema.TEXTO)
	sub.position = Vector2(160, 280)
	sub.size = Vector2(1600, 50)
	_palco.add_child(sub)

	# Botões gigantes.
	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 26)
	coluna.position = Vector2(600, 380)
	coluna.size = Vector2(720, 520)
	_palco.add_child(coluna)

	var historia := botao_grande("JOGAR HISTÓRIA", COR_HISTORIA, Vector2(720, 130), 52)
	historia.pressed.connect(func():
		Audio.tocar("confirmar")
		campanha.emit())
	coluna.add_child(historia)
	_continuar = Label.new()
	_continuar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continuar.add_theme_font_override("font", Tema.fonte("texto_negrito"))
	_continuar.add_theme_font_size_override("font_size", 26)
	_continuar.add_theme_color_override("font_color", Tema.OURO)
	_continuar.text = _texto_continuar()
	coluna.add_child(_continuar)

	var duelo := botao_grande("DUELO RÁPIDO", COR_DUELO, Vector2(720, 110), 44)
	duelo.pressed.connect(func():
		Audio.tocar("confirmar")
		duelo_rapido.emit())
	coluna.add_child(duelo)
	var opc := botao_grande("OPÇÕES", COR_OPCOES, Vector2(720, 96), 38)
	opc.pressed.connect(func():
		Audio.tocar("clique")
		opcoes.emit())
	coluna.add_child(opc)

	# Rodapé: estrelas e vitórias.
	var rodape := Desenho.criar(func(ci: Control): _desenhar_rodape(ci), Vector2(460, 960), Vector2(1000, 90), true)
	_palco.add_child(rodape)


func _texto_continuar() -> String:
	if Jogo.campanha_concluida():
		return "Campanha completa! Jogue de novo para mais estrelas."
	var p := Jogo.proxima_etapa()
	if int(p["circuito"]) == 0 and int(p["etapa"]) == 0 and Jogo.total_estrelas() == 0:
		return "Começar a aventura!"
	return "Continuar: Circuito %d - Etapa %d" % [int(p["circuito"]) + 1, int(p["etapa"]) + 1]


func _desenhar_rodape(ci: Control) -> void:
	var meio := ci.size.x / 2.0
	var y := ci.size.y / 2.0
	ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.7), Color(Tema.OURO, 0.45), 2, 24), Rect2(Vector2(meio - 420, 0), Vector2(840, ci.size.y)))
	estrela(ci, Vector2(meio - 300, y), 26, Tema.OURO_CLARO)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(meio - 262, y + 13), "%d estrelas" % Jogo.total_estrelas(), 34, Tema.OURO_CLARO)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(meio + 40, y + 13), "%d vitórias" % int(Jogo.progresso.get("vitorias", 0)), 34, Tema.TEXTO)
	Icones.espada(ci, Vector2(meio + 2, y), 20, Tema.TEXTO)


# =====================================================================
# Ajudantes compartilhados pelas telas do jogo completo
# =====================================================================

## Control de 1920x1080 ancorado no centro: a interface não quebra em 16:9 nem em 20:9.
static func palco_central(pai: Control) -> Control:
	var palco := Control.new()
	palco.anchor_left = 0.5
	palco.anchor_right = 0.5
	palco.anchor_top = 0.5
	palco.anchor_bottom = 0.5
	palco.offset_left = -960
	palco.offset_right = 960
	palco.offset_top = -540
	palco.offset_bottom = 540
	palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(palco)
	return palco


## Botão enorme e colorido com borda dourada e brilho no hover.
static func botao_grande(texto: String, cor: Color, tamanho: Vector2, fonte_tamanho := 40) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tamanho
	b.size = tamanho
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Tema.fonte("titulo"))
	b.add_theme_font_size_override("font_size", fonte_tamanho)
	b.add_theme_stylebox_override("normal", Tema.caixa(cor, Tema.OURO, 4, 22, Color(cor.lightened(0.3), 0.35), 10))
	b.add_theme_stylebox_override("hover", Tema.caixa(cor.lightened(0.18), Tema.OURO_CLARO, 4, 22, Color(cor.lightened(0.5), 0.6), 18))
	b.add_theme_stylebox_override("pressed", Tema.caixa(cor.darkened(0.3), Tema.OURO, 4, 22))
	b.add_theme_stylebox_override("focus", Tema.caixa(cor, Tema.OURO_CLARO, 4, 22))
	b.add_theme_stylebox_override("disabled", Tema.caixa(Color("#3a3a40"), Color("#6a6a70"), 4, 22))
	b.add_theme_color_override("font_color", Tema.OURO_CLARO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Tema.OURO)
	b.add_theme_color_override("font_disabled_color", Color(Tema.TEXTO, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 4)
	return b


## Estrela de cinco pontas com contorno escuro.
static func estrela(ci: CanvasItem, c: Vector2, r: float, cor: Color, contorno := true) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * TAU / 10.0
		var raio := r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * raio)
	ci.draw_colored_polygon(pts, cor)
	if contorno:
		ci.draw_polyline(Icones.fechar(pts), Color(0.25, 0.15, 0.02, 0.9), maxf(1.5, r * 0.12), true)
	if cor.v > 0.5:
		ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.16, Color(1, 1, 1, 0.55))


## Cadeado (etapa bloqueada).
static func cadeado(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	ci.draw_arc(c + Vector2(0, -r * 0.25), r * 0.55, PI, TAU, 16, cor, r * 0.22, true)
	var corpo := Rect2(c + Vector2(-r * 0.8, -r * 0.2), Vector2(r * 1.6, r * 1.2))
	ci.draw_style_box(Tema.caixa(cor, cor.darkened(0.4), 2, int(r * 0.2)), corpo)
	ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.18, cor.darkened(0.6))
