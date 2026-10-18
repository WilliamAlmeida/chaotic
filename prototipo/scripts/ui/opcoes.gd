class_name Opcoes
extends Control
## Tela de opções, com botões enormes de alternar e sliders grandes (pensada para crianças):
## Modo Fácil, Controles de toque, volumes de efeitos e música, Apagar progresso e Voltar.
## Tudo é salvo com Jogo.salvar().

signal voltar

const COR_LIGADO := Color("#2f9e4a")
const COR_DESLIGADO := Color("#55606f")
const COR_AUTO := Color("#1b4f8a")

var _palco: Control
var _botao_facil: Button
var _botao_toque: Button
var _botao_apagar: Button
var _confirmacao: HBoxContainer
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Tema.criar_tema()
	_construir()
	_atualizar()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	Tema.gradiente(self, Rect2(Vector2.ZERO, size), Color("#0c121c"), Color("#1a2438"))
	var c := size / 2.0
	for i in 5:
		draw_polyline(Icones.fechar(Icones.octogono(c, 260.0 + i * 150.0, _t * 0.03 * (i + 1))), Color(Tema.OURO, 0.06), 2.0, true)


func _construir() -> void:
	_palco = MenuTitulo.palco_central(self)

	var titulo := Label.new()
	titulo.text = "OPÇÕES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", Tema.fonte("titulo"))
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", Tema.OURO_CLARO)
	titulo.position = Vector2(0, 50)
	titulo.size = Vector2(1920, 90)
	_palco.add_child(titulo)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Tema.caixa(Color(Tema.CARVAO, 0.75), Color(Tema.OURO, 0.5), 3, 24))
	painel.position = Vector2(360, 170)
	painel.size = Vector2(1200, 640)
	_palco.add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 40)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 34)
	margem.add_child(coluna)

	# Modo Fácil
	_botao_facil = _linha_botao(coluna, "Modo Fácil", "Mira automática, inimigos mais calmos e dicas grandes.")
	_botao_facil.pressed.connect(func():
		Jogo.config["modo_facil"] = not Jogo.facil()
		_salvar_e_atualizar())

	# Controles de toque
	_botao_toque = _linha_botao(coluna, "Controles de toque", "Botões na tela para jogar com os dedos.")
	_botao_toque.pressed.connect(func():
		var ordem := ["auto", "sim", "nao"]
		var atual := ordem.find(str(Jogo.config.get("toque", "auto")))
		Jogo.config["toque"] = ordem[(atual + 1) % ordem.size()]
		_salvar_e_atualizar())

	# Volumes
	_linha_slider(coluna, "Efeitos", "volume_efeitos", func(): Audio.tocar("golpe"))
	_linha_slider(coluna, "Música", "volume_musica", func(): Audio.atualizar_volumes())

	# Apagar progresso (com confirmação).
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	coluna.add_child(linha)
	var rotulo := _rotulo("Apagar progresso", 36)
	rotulo.custom_minimum_size = Vector2(640, 90)
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo)
	_botao_apagar = MenuTitulo.botao_grande("APAGAR", Color("#8a1a14"), Vector2(440, 90), 32)
	_botao_apagar.pressed.connect(func():
		Audio.tocar("aviso")
		_botao_apagar.visible = false
		_confirmacao.visible = true)
	linha.add_child(_botao_apagar)
	_confirmacao = HBoxContainer.new()
	_confirmacao.add_theme_constant_override("separation", 14)
	_confirmacao.visible = false
	linha.add_child(_confirmacao)
	var pergunta := _rotulo("Tem certeza?", 28)
	pergunta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirmacao.add_child(pergunta)
	var sim := MenuTitulo.botao_grande("SIM", Color("#8a1a14"), Vector2(130, 90), 30)
	sim.pressed.connect(func():
		Jogo.apagar_progresso()
		Audio.tocar("quebra")
		_confirmacao.visible = false
		_botao_apagar.visible = true
		_atualizar())
	_confirmacao.add_child(sim)
	var nao := MenuTitulo.botao_grande("NÃO", COR_AUTO, Vector2(130, 90), 30)
	nao.pressed.connect(func():
		Audio.tocar("voltar")
		_confirmacao.visible = false
		_botao_apagar.visible = true)
	_confirmacao.add_child(nao)

	var botao_voltar := MenuTitulo.botao_grande("◀  VOLTAR", Color("#3a4657"), Vector2(420, 100), 40)
	botao_voltar.position = Vector2(750, 880)
	botao_voltar.pressed.connect(func():
		Jogo.salvar()
		Audio.tocar("voltar")
		voltar.emit())
	_palco.add_child(botao_voltar)


func _linha_botao(coluna: VBoxContainer, nome: String, explicacao: String) -> Button:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	coluna.add_child(linha)
	var textos := VBoxContainer.new()
	textos.custom_minimum_size = Vector2(640, 0)
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_child(textos)
	textos.add_child(_rotulo(nome, 36))
	var expl := _rotulo(explicacao, 22)
	expl.add_theme_color_override("font_color", Tema.TEXTO_SUAVE)
	expl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(expl)
	var botao := MenuTitulo.botao_grande("", COR_LIGADO, Vector2(440, 90), 32)
	linha.add_child(botao)
	return botao


func _linha_slider(coluna: VBoxContainer, nome: String, chave: String, ao_mudar: Callable) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	coluna.add_child(linha)
	var rotulo := _rotulo(nome, 36)
	rotulo.custom_minimum_size = Vector2(640, 90)
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo)
	var deslizador := Deslizador.new()
	deslizador.custom_minimum_size = Vector2(440, 90)
	deslizador.valor = clampf(float(Jogo.config.get(chave, 0.8)), 0.0, 1.0)
	deslizador.mudou.connect(func(v: float):
		Jogo.config[chave] = snappedf(v, 0.05)
		ao_mudar.call())
	deslizador.soltou.connect(func(): Jogo.salvar())
	linha.add_child(deslizador)


func _rotulo(texto: String, tamanho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", Tema.fonte("texto_negrito"))
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", Tema.TEXTO)
	return l


func _salvar_e_atualizar() -> void:
	Audio.tocar("clique")
	Jogo.salvar()
	_atualizar()


func _estilizar(botao: Button, texto: String, cor: Color) -> void:
	botao.text = texto
	botao.add_theme_stylebox_override("normal", Tema.caixa(cor, Tema.OURO, 4, 22, Color(cor.lightened(0.3), 0.35), 10))
	botao.add_theme_stylebox_override("hover", Tema.caixa(cor.lightened(0.18), Tema.OURO_CLARO, 4, 22, Color(cor.lightened(0.5), 0.6), 18))
	botao.add_theme_stylebox_override("pressed", Tema.caixa(cor.darkened(0.3), Tema.OURO, 4, 22))


func _atualizar() -> void:
	_estilizar(_botao_facil, "LIGADO  ✓" if Jogo.facil() else "DESLIGADO", COR_LIGADO if Jogo.facil() else COR_DESLIGADO)
	match str(Jogo.config.get("toque", "auto")):
		"sim":
			_estilizar(_botao_toque, "LIGADO  ✓", COR_LIGADO)
		"nao":
			_estilizar(_botao_toque, "DESLIGADO", COR_DESLIGADO)
		_:
			_estilizar(_botao_toque, "AUTOMÁTICO", COR_AUTO)


## Slider grande desenhado em código: trilho, preenchimento dourado e um botão redondo fácil de pegar.
class Deslizador extends Control:
	signal mudou(valor: float)
	signal soltou

	var valor := 0.8
	var _arrastando := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var botao := event as InputEventMouseButton
		var toque := event as InputEventScreenTouch
		if botao and botao.button_index == MOUSE_BUTTON_LEFT:
			_arrastando = botao.pressed
			if botao.pressed:
				_definir(botao.position.x)
			else:
				soltou.emit()
			accept_event()
		elif toque:
			_arrastando = toque.pressed
			if toque.pressed:
				_definir(toque.position.x)
			else:
				soltou.emit()
			accept_event()
		elif _arrastando and (event is InputEventMouseMotion or event is InputEventScreenDrag):
			_definir(event.position.x)
			accept_event()

	func _definir(x: float) -> void:
		var margem := size.y * 0.5
		valor = clampf((x - margem) / maxf(1.0, size.x - margem * 2.0), 0.0, 1.0)
		mudou.emit(valor)
		queue_redraw()

	func _draw() -> void:
		var margem := size.y * 0.5
		var y := size.y / 2.0
		var trilho := Rect2(Vector2(margem, y - 12), Vector2(size.x - margem * 2.0, 24))
		draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.9), Tema.MEDIO, 2, 12), trilho)
		var cheio := Rect2(trilho.position, Vector2(trilho.size.x * valor, trilho.size.y))
		if cheio.size.x > 4:
			draw_style_box(Tema.caixa(Tema.OURO, Tema.OURO_ESCURO, 2, 12), cheio)
		var knob := Vector2(trilho.position.x + trilho.size.x * valor, y)
		draw_circle(knob, margem * 0.8, Color(0, 0, 0, 0.5))
		draw_circle(knob, margem * 0.72, Tema.OURO_CLARO)
		draw_arc(knob, margem * 0.72, 0, TAU, 32, Tema.OURO_ESCURO, 3.0, true)
		Tema.texto(self, Tema.fonte("numero"), Vector2(knob.x - 40, y + 10), str(int(round(valor * 100))), 26, Tema.TEXTO_ESCURO, 80, HORIZONTAL_ALIGNMENT_CENTER)
