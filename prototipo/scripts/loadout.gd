class_name Loadout
extends Control
## Tela de loadout em dois modos:
##   - "Escolha Rápida" (padrão no Modo Fácil): grade de cartas grandes de monstros, só os
##     desbloqueados (os outros com cadeado), equipamento/Cântico/deck preenchidos sozinhos,
##     arena em carta grande (ou sorteio) e um botão LUTAR enorme.
##   - "Montar deck (avançado)": a tela "Carregamento de Combate" completa (mockup em
##     docs/gui-conceito.md): 4 cartas com setas e o deck de ataques (orçamento de 20 pontos).
## Na campanha, config_inicial traz "local_travado": true e "inimigo": a arena fica fixa
## (mostrada como informação) e o oponente aparece ao lado.

signal lutar(config: Dictionary)
signal voltar

const TIPOS := ["monstro", "equipamento", "cantico", "local"]
const TITULOS := {"monstro": "Monstro", "equipamento": "Equipamento", "cantico": "Cântico", "local": "Local"}
const SUBTITULOS := {
	"monstro": "O Eco que você controla na arena.",
	"equipamento": "Bônus ao monstro, oculto até a luta.",
	"cantico": "Magia musical: Q e a sequência.",
	"local": "A arena e quem tem a iniciativa.",
}
## Chaves de config_inicial repassadas sem mudança para a Batalha.
const CHAVES_REPASSE := ["inimigo", "campanha", "titulo", "frase", "tutorial", "dificuldade", "local_travado"]
const LARGURA_COLUNA := 298.0
const TOPO_COLUNAS := 135.0
const COLUNAS_GRADE := 5
const TAMANHO_CARTA_GRADE := Vector2(184, 276)

var config_inicial: Dictionary = {}

var _palco: Control
var _rapido: Control
var _avancado: Control
var _modo_rapido := true
var _local_travado := false
var _opcoes: Dictionary = {}
var _indice: Dictionary = {"monstro": 0, "equipamento": 0, "cantico": 0, "local": 0}
var _deck: Array = []
## Escolha do modo rápido: o deck/equipamento/Cântico são sugeridos por monstro.
var _monstro_rapido := ""
var _cartas_grade: Dictionary = {}
var _carta_grande: CartaVisual
var _carta_equip_rapido: CartaVisual
var _carta_cantico_rapido: CartaVisual
var _carta_local_rapido: CartaVisual
var _carta_inimigo_rapido: CartaVisual
var _nome_rapido: Label
var _faccao_rapido: Label
var _deck_rapido: Label
var _aviso_rapido: Label
var _rotulo_arena: Label
var _setas_local_rapido: Array = []
var _botao_lutar_rapido: Button
# Modo avançado
var _cartas: Dictionary = {}
var _legendas: Dictionary = {}
var _setas: Dictionary = {}
var _cartas_ataque: Dictionary = {}
var _custo_grande: Label
var _custo_rodape: Label
var _contagem: Label
var _dica: Label
var _botao_lutar: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Tema.criar_tema()
	_local_travado = bool(config_inicial.get("local_travado", false))
	_opcoes = {
		"monstro": Dados.monstros.keys(),
		"equipamento": Dados.equipamentos.keys(),
		"cantico": Dados.canticos.keys(),
		"local": ["aleatorio"] + Dados.locais.keys(),
	}
	_modo_rapido = Jogo.facil() and not bool(Jogo.config.get("loadout_avancado", false))
	_construir()
	_aplicar_config(config_inicial)
	_atualizar()
	_mostrar_modo()


func _draw() -> void:
	# Fundo: gradiente noturno com octógonos ornamentais (o "salão" da Rede).
	var r := Rect2(Vector2.ZERO, size)
	Tema.gradiente(self, r, Color("#0c121c"), Color("#151d2b"))
	var c := size / 2.0
	for i in 6:
		draw_polyline(Icones.fechar(Icones.octogono(c + Vector2(0, 120), 220.0 + i * 140.0)), Color(Tema.OURO, 0.05), 2.0, true)
	Tema.brilho_radial(self, Vector2(size.x * 0.35, size.y * 0.55), size.y * 0.6, Color(0.25, 0.35, 0.6, 0.25), 8)


# ---------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------

func _construir() -> void:
	_palco = MenuTitulo.palco_central(self)
	_rapido = Control.new()
	_rapido.size = Vector2(1920, 1080)
	_rapido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(_rapido)
	_avancado = Control.new()
	_avancado.size = Vector2(1920, 1080)
	_avancado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(_avancado)

	_construir_rapido()
	_cabecalho()
	for i in TIPOS.size():
		_coluna(TIPOS[i], 32.0 + i * (LARGURA_COLUNA + 14.0))
	_painel_deck()
	_rodape()


func _mostrar_modo() -> void:
	_rapido.visible = _modo_rapido
	_avancado.visible = not _modo_rapido


func _alternar_modo() -> void:
	Audio.tocar("carta")
	if _modo_rapido:
		# Leva a escolha rápida para o modo avançado.
		_indice["monstro"] = maxi(0, (_opcoes["monstro"] as Array).find(_monstro_rapido))
		var sugerido := Jogo.loadout_sugerido(_monstro_rapido)
		_indice["equipamento"] = maxi(0, (_opcoes["equipamento"] as Array).find(sugerido["equipamento"]))
		_indice["cantico"] = maxi(0, (_opcoes["cantico"] as Array).find(sugerido["cantico"]))
		_deck = (sugerido["deck"] as Array).duplicate()
	else:
		_monstro_rapido = _id("monstro")
	_modo_rapido = not _modo_rapido
	Jogo.config["loadout_avancado"] = not _modo_rapido
	Jogo.salvar()
	_atualizar()
	_mostrar_modo()


# ----------------------------- Escolha Rápida -----------------------------

func _construir_rapido() -> void:
	var em_campanha := config_inicial.has("campanha")
	var botao_voltar := MenuTitulo.botao_grande("◀  VOLTAR", Color("#3a4657"), Vector2(250, 76), 28)
	botao_voltar.position = Vector2(32, 28)
	botao_voltar.pressed.connect(func():
		Audio.tocar("voltar")
		voltar.emit())
	_rapido.add_child(botao_voltar)

	var titulo := _rotulo("ESCOLHA SEU MONSTRO", Vector2(300, 22), "titulo", 56, Tema.OURO_CLARO)
	titulo.size = Vector2(1100, 80)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rapido.add_child(titulo)

	var avancado := MenuTitulo.botao_grande("Montar deck (avançado)", Color("#1b4f8a"), Vector2(440, 76), 24)
	avancado.position = Vector2(1448, 28)
	avancado.pressed.connect(_alternar_modo)
	_rapido.add_child(avancado)

	# Grade de monstros (desbloqueados primeiro).
	var ids: Array = Dados.monstros.keys()
	ids.sort_custom(func(a, b):
		var da := Jogo.monstro_desbloqueado(a)
		var db := Jogo.monstro_desbloqueado(b)
		return da and not db if da != db else a < b)
	for i in ids.size():
		var id: String = ids[i]
		var carta := CartaVisual.new()
		carta.interativa = true
		carta.definir("monstro", id)
		carta.position = Vector2(32, 130) + Vector2((i % COLUNAS_GRADE) * (TAMANHO_CARTA_GRADE.x + 12), (i / COLUNAS_GRADE) * (TAMANHO_CARTA_GRADE.y + 12))
		carta.size = TAMANHO_CARTA_GRADE
		carta.clicada.connect(func(c: CartaVisual): _escolher_rapido(c.id))
		if not Jogo.monstro_desbloqueado(id):
			carta.desabilitada = true
			carta.add_child(Desenho.criar(func(ci: Control): _desenhar_bloqueio(ci), Vector2.ZERO, TAMANHO_CARTA_GRADE))
		_rapido.add_child(carta)
		_cartas_grade[id] = carta

	# Painel do lutador escolhido.
	_rapido.add_child(Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.72), Color(Tema.OURO, 0.55), 3, 22), Rect2(Vector2.ZERO, ci.size)), Vector2(1010, 120), Vector2(880, 480)))
	_carta_grande = CartaVisual.new()
	_carta_grande.position = Vector2(1030, 140)
	_carta_grande.size = Vector2(293, 440)
	_rapido.add_child(_carta_grande)
	_nome_rapido = _rotulo("", Vector2(1350, 140), "titulo", 46, Tema.OURO_CLARO)
	_nome_rapido.size = Vector2(520, 60)
	_rapido.add_child(_nome_rapido)
	_faccao_rapido = _rotulo("", Vector2(1352, 200), "texto_negrito", 26, Tema.TEXTO)
	_faccao_rapido.size = Vector2(520, 36)
	_rapido.add_child(_faccao_rapido)
	_rapido.add_child(_rotulo("Já vem pronto para a luta:", Vector2(1352, 244), "texto", 22, Tema.TEXTO_SUAVE))
	_carta_equip_rapido = CartaVisual.new()
	_carta_equip_rapido.position = Vector2(1350, 280)
	_carta_equip_rapido.size = Vector2(160, 240)
	_rapido.add_child(_carta_equip_rapido)
	_carta_cantico_rapido = CartaVisual.new()
	_carta_cantico_rapido.position = Vector2(1530, 280)
	_carta_cantico_rapido.size = Vector2(160, 240)
	_rapido.add_child(_carta_cantico_rapido)
	_rapido.add_child(Desenho.criar(func(ci: Control):
		Icones.chip(ci, Vector2(40, 40), 34, Tema.OURO)
		Icones.espada(ci, Vector2(40, 40), 22, Tema.TEXTO), Vector2(1710, 300), Vector2(80, 80)))
	_deck_rapido = _rotulo("", Vector2(1710, 390), "texto_negrito", 22, Tema.TEXTO)
	_deck_rapido.size = Vector2(170, 120)
	_deck_rapido.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rapido.add_child(_deck_rapido)
	_aviso_rapido = _rotulo("", Vector2(1350, 534), "texto_negrito", 24, Color("#ffb38a"))
	_aviso_rapido.size = Vector2(520, 50)
	_rapido.add_child(_aviso_rapido)

	# Arena (e oponente, na campanha).
	_rapido.add_child(Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.72), Color(Tema.OURO, 0.55), 3, 22), Rect2(Vector2.ZERO, ci.size)), Vector2(1010, 620), Vector2(880, 430)))
	_rotulo_arena = _rotulo("ARENA DA ETAPA" if em_campanha else "ARENA", Vector2(1030, 632), "titulo", 28, Tema.OURO)
	_rotulo_arena.size = Vector2(440, 40)
	_rapido.add_child(_rotulo_arena)
	_carta_local_rapido = CartaVisual.new()
	_carta_local_rapido.position = Vector2(1070, 680)
	_carta_local_rapido.size = Vector2(220, 330)
	_carta_local_rapido.interativa = not _local_travado
	_carta_local_rapido.clicada.connect(func(_c: CartaVisual): _mudar_local_rapido(1))
	_rapido.add_child(_carta_local_rapido)
	if not _local_travado:
		for lado in [-1, 1]:
			var seta := Button.new()
			seta.text = "‹" if lado < 0 else "›"
			seta.flat = true
			seta.focus_mode = Control.FOCUS_NONE
			seta.add_theme_font_override("font", Tema.fonte("titulo"))
			seta.add_theme_font_size_override("font_size", 96)
			seta.add_theme_color_override("font_color", Tema.OURO)
			seta.add_theme_color_override("font_hover_color", Tema.OURO_CLARO)
			seta.position = Vector2(1016 if lado < 0 else 1296, 780)
			seta.size = Vector2(56, 120)
			seta.pressed.connect(func(): _mudar_local_rapido(lado))
			_rapido.add_child(seta)
			_setas_local_rapido.append(seta)
	if em_campanha:
		var contra := _rotulo("CONTRA", Vector2(1380, 632), "titulo", 28, Color("#ff8a66"))
		contra.size = Vector2(240, 40)
		_rapido.add_child(contra)
		_carta_inimigo_rapido = CartaVisual.new()
		_carta_inimigo_rapido.position = Vector2(1380, 680)
		_carta_inimigo_rapido.size = Vector2(220, 330)
		_carta_inimigo_rapido.definir("monstro", str(config_inicial.get("inimigo", {}).get("monstro", "")))
		_rapido.add_child(_carta_inimigo_rapido)

	_botao_lutar_rapido = MenuTitulo.botao_grande("LUTAR!", Color("#8a1a14"), Vector2(260 if em_campanha else 500, 200), 60)
	_botao_lutar_rapido.position = Vector2(1620, 760) if em_campanha else Vector2(1370, 760)
	_botao_lutar_rapido.pressed.connect(_on_lutar)
	_rapido.add_child(_botao_lutar_rapido)


func _desenhar_bloqueio(ci: Control) -> void:
	var c := ci.size / 2.0
	ci.draw_circle(c + Vector2(0, -30), 52, Color(0.05, 0.07, 0.11, 0.85))
	MenuTitulo.cadeado(ci, c + Vector2(0, -30), 26, Color("#c9d2e0"))
	var r := Rect2(Vector2(10, ci.size.y - 100), Vector2(ci.size.x - 20, 78))
	ci.draw_style_box(Tema.caixa(Color(0.05, 0.07, 0.11, 0.9), Tema.OURO, 2, 10), r)
	Tema.texto(ci, Tema.fonte("texto_negrito"), r.position + Vector2(0, 30), "Trancado!", 20, Tema.OURO_CLARO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	Tema.texto(ci, Tema.fonte("texto"), r.position + Vector2(0, 54), "Vença na história", 16, Tema.TEXTO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	Tema.texto(ci, Tema.fonte("texto"), r.position + Vector2(0, 72), "para liberar", 16, Tema.TEXTO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _escolher_rapido(id: String) -> void:
	if not Jogo.monstro_desbloqueado(id):
		Audio.tocar("aviso")
		_aviso_rapido.text = "Esse Eco ainda está trancado. Vença a campanha!"
		return
	Audio.tocar("carta")
	_monstro_rapido = id
	_aviso_rapido.text = ["Boa escolha!", "Esse é forte!", "Ótimo Eco!", "Vai dar certo!"].pick_random()
	_atualizar()


func _mudar_local_rapido(passo: int) -> void:
	if _local_travado:
		return
	Audio.tocar("carta")
	_mudar("local", passo)


# ----------------------------- Modo avançado -----------------------------

func _cabecalho() -> void:
	_avancado.add_child(Desenho.criar(func(ci: Control): _rosa_dos_ventos(ci, ci.size / 2.0, 34.0), Vector2(30, 18), Vector2(76, 76)))
	_avancado.add_child(_rotulo("CARREGAMENTO DE COMBATE", Vector2(118, 16), "titulo", 52, Tema.TEXTO))
	_avancado.add_child(_rotulo("ESCOLHA SUAS CARTAS E PREPARE-SE PARA O DUELO.", Vector2(122, 84), "texto", 17, Tema.TEXTO_SUAVE))
	var botao_voltar := MenuTitulo.botao_grande("◀  VOLTAR", Color("#3a4657"), Vector2(200, 60), 22)
	botao_voltar.position = Vector2(1130, 30)
	botao_voltar.pressed.connect(func():
		Audio.tocar("voltar")
		voltar.emit())
	_avancado.add_child(botao_voltar)
	var rapido := MenuTitulo.botao_grande("ESCOLHA RÁPIDA", Color("#1b4f8a"), Vector2(300, 60), 22)
	rapido.position = Vector2(1350, 30)
	rapido.pressed.connect(_alternar_modo)
	_avancado.add_child(rapido)
	_avancado.add_child(_rotulo("MAGIA EM SINTONIA\nCOM UM MUNDO MAIOR.", Vector2(1700, 22), "texto", 13, Tema.TEXTO_SUAVE))
	_avancado.add_child(Desenho.criar(func(ci: Control):
		ci.draw_line(Vector2(0, 0), Vector2(ci.size.x, 0), Color(Tema.OURO, 0.35), 1.5)
		_losango(ci, Vector2(ci.size.x / 2.0, 0), 5.0, Tema.OURO), Vector2(118, 120), Vector2(1772, 2)))


func _coluna(tipo: String, x: float) -> void:
	var y := TOPO_COLUNAS
	_avancado.add_child(Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.55), Color(Tema.MEDIO, 0.7), 1, 10), Rect2(Vector2.ZERO, ci.size)), Vector2(x, y), Vector2(LARGURA_COLUNA, 800)))
	_avancado.add_child(Desenho.criar(func(ci: Control): _icone_tipo(ci, tipo), Vector2(x + 12, y + 14), Vector2(56, 56)))
	var titulo := _rotulo(TITULOS[tipo], Vector2(x + 76, y + 10), "titulo", 30, Tema.TEXTO)
	_legendas[tipo + "_titulo"] = titulo
	_avancado.add_child(titulo)
	var sub := _rotulo(SUBTITULOS[tipo], Vector2(x + 76, y + 48), "texto", 13, Tema.TEXTO_SUAVE)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(LARGURA_COLUNA - 86, 0)
	sub.size = Vector2(LARGURA_COLUNA - 86, 40)
	_avancado.add_child(sub)

	var travada := tipo == "local" and _local_travado
	var carta := CartaVisual.new()
	carta.position = Vector2(x + 9, y + 100)
	carta.size = Vector2(280, 420)
	carta.interativa = not travada
	carta.clicada.connect(func(_c: CartaVisual): _mudar(tipo, 1))
	_avancado.add_child(carta)
	_cartas[tipo] = carta

	if not travada:
		for lado in [-1, 1]:
			var seta := Button.new()
			seta.text = "‹" if lado < 0 else "›"
			seta.flat = true
			seta.focus_mode = Control.FOCUS_NONE
			seta.add_theme_font_override("font", Tema.fonte("titulo"))
			seta.add_theme_font_size_override("font_size", 64)
			seta.add_theme_color_override("font_color", Tema.TEXTO)
			seta.add_theme_color_override("font_hover_color", Tema.OURO)
			seta.position = Vector2(x - 14 if lado < 0 else x + LARGURA_COLUNA - 26, y + 260)
			seta.size = Vector2(40, 90)
			seta.pressed.connect(func(): _mudar(tipo, lado))
			_avancado.add_child(seta)

	_avancado.add_child(Desenho.criar(func(ci: Control): _simbolo_coluna(ci, tipo), Vector2(x + 29, y + 535), Vector2(240, 220), true))
	var legenda := _rotulo("", Vector2(x, y + 758), "titulo", 17, Tema.TEXTO_SUAVE)
	legenda.size = Vector2(LARGURA_COLUNA, 30)
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legendas[tipo] = legenda
	_avancado.add_child(legenda)


func _painel_deck() -> void:
	var x := 1290.0
	var y := TOPO_COLUNAS
	_avancado.add_child(Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.7), Color(Tema.OURO, 0.45), 2, 12), Rect2(Vector2.ZERO, ci.size)), Vector2(x, y), Vector2(598, 800)))
	_avancado.add_child(Desenho.criar(func(ci: Control):
		Icones.chip(ci, ci.size / 2.0, 28, Tema.OURO)
		Icones.espada(ci, ci.size / 2.0, 18, Tema.TEXTO), Vector2(x + 14, y + 14), Vector2(60, 60)))
	_avancado.add_child(_rotulo("Deck de Ataques", Vector2(x + 84, y + 12), "titulo", 32, Tema.TEXTO))
	_avancado.add_child(Desenho.criar(func(ci: Control): _barra_segmentada(ci, _custo_deck()), Vector2(x + 86, y + 60), Vector2(300, 14), true))
	_custo_grande = _rotulo("0/20", Vector2(x + 400, y + 2), "titulo", 50, Tema.OURO)
	_custo_grande.size = Vector2(180, 60)
	_custo_grande.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_avancado.add_child(_custo_grande)
	var legenda := _rotulo("CUSTO TOTAL", Vector2(x + 400, y + 62), "texto", 13, Tema.TEXTO_SUAVE)
	legenda.size = Vector2(180, 20)
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_avancado.add_child(legenda)

	var rolagem := ScrollContainer.new()
	rolagem.position = Vector2(x + 10, y + 92)
	rolagem.size = Vector2(580, 698)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_avancado.add_child(rolagem)
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 10)
	rolagem.add_child(grade)
	var ids: Array = Dados.ataques.keys()
	ids.sort_custom(func(a, b):
		var ca := int(Dados.ataques[a]["custo"])
		var cb := int(Dados.ataques[b]["custo"])
		return ca < cb if ca != cb else str(Dados.ataques[a]["nome"]) < str(Dados.ataques[b]["nome"]))
	for id in ids:
		var carta := CartaVisual.new()
		carta.custom_minimum_size = Vector2(180, 225)
		carta.interativa = true
		carta.definir("ataque", id)
		carta.clicada.connect(func(c: CartaVisual): _alternar_ataque(c.id))
		grade.add_child(carta)
		_cartas_ataque[id] = carta


func _rodape() -> void:
	var y := 952.0
	_avancado.add_child(Desenho.criar(func(ci: Control):
		ci.draw_circle(ci.size / 2.0, 20, Color(Tema.CARVAO, 0.9))
		ci.draw_arc(ci.size / 2.0, 20, 0, TAU, 32, Tema.OURO, 2.0, true)
		Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, 31), "?", 26, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER), Vector2(32, y + 14), Vector2(44, 44)))
	_dica = _rotulo("", Vector2(90, y + 12), "texto", 15, Tema.TEXTO_SUAVE)
	_dica.size = Vector2(640, 60)
	_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avancado.add_child(_dica)

	_custo_rodape = _rotulo("", Vector2(760, y + 4), "titulo", 20, Tema.TEXTO)
	_avancado.add_child(_custo_rodape)
	_avancado.add_child(Desenho.criar(func(ci: Control): _barra_segmentada(ci, _custo_deck()), Vector2(760, y + 38), Vector2(300, 16), true))
	_contagem = _rotulo("", Vector2(760, y + 60), "texto", 14, Tema.TEXTO_SUAVE)
	_avancado.add_child(_contagem)

	var sugerir := Button.new()
	sugerir.text = "SUGERIR DECK"
	sugerir.position = Vector2(1090, y + 14)
	sugerir.size = Vector2(200, 56)
	sugerir.pressed.connect(_sugerir_deck)
	_avancado.add_child(sugerir)
	var limpar := Button.new()
	limpar.text = "✕  LIMPAR DECK"
	limpar.position = Vector2(1300, y + 14)
	limpar.size = Vector2(200, 56)
	limpar.pressed.connect(func():
		_deck.clear()
		_atualizar())
	_avancado.add_child(limpar)

	_botao_lutar = Button.new()
	_botao_lutar.text = "LUTAR"
	_botao_lutar.position = Vector2(1530, y - 6)
	_botao_lutar.size = Vector2(360, 96)
	_botao_lutar.add_theme_font_override("font", Tema.fonte("titulo"))
	_botao_lutar.add_theme_font_size_override("font_size", 50)
	var vermelho := Color("#8a1a14")
	_botao_lutar.add_theme_stylebox_override("normal", Tema.caixa(vermelho, Tema.OURO, 3, 16, Color(1.0, 0.3, 0.15, 0.45), 14))
	_botao_lutar.add_theme_stylebox_override("hover", Tema.caixa(vermelho.lightened(0.15), Tema.OURO_CLARO, 3, 16, Color(1.0, 0.45, 0.2, 0.7), 22))
	_botao_lutar.add_theme_stylebox_override("pressed", Tema.caixa(vermelho.darkened(0.3), Tema.OURO, 3, 16))
	_botao_lutar.add_theme_stylebox_override("focus", Tema.caixa(vermelho, Tema.OURO_CLARO, 3, 16))
	_botao_lutar.add_theme_stylebox_override("disabled", Tema.caixa(Color("#3a3a40"), Color("#6a6a70"), 3, 16))
	_botao_lutar.add_theme_color_override("font_color", Tema.OURO_CLARO)
	_botao_lutar.add_theme_color_override("font_hover_color", Color.WHITE)
	_botao_lutar.pressed.connect(_on_lutar)
	_avancado.add_child(_botao_lutar)
	_botao_lutar.add_child(Desenho.criar(func(ci: Control):
		Icones.simbolo_cantico(ci, Vector2(40, 48), 26, Tema.OURO, "", 0.0)
		_rosa_dos_ventos(ci, Vector2(40, 48), 12.0), Vector2.ZERO, Vector2(80, 96)))


# ---------------------------------------------------------------------
# Comportamento
# ---------------------------------------------------------------------

func _mudar(tipo: String, passo: int) -> void:
	if tipo == "local" and _local_travado:
		return
	var lista: Array = _opcoes[tipo]
	_indice[tipo] = wrapi(int(_indice[tipo]) + passo, 0, lista.size())
	_atualizar()


func _id(tipo: String) -> String:
	return str(_opcoes[tipo][int(_indice[tipo])])


func _alternar_ataque(id: String) -> void:
	if _deck.has(id):
		_deck.erase(id)
	else:
		_deck.append(id)
	_atualizar()


func _custo_deck() -> int:
	var custo := 0
	for id in _deck:
		custo += int(Dados.ataques[id]["custo"])
	return custo


func _sugerir_deck() -> void:
	_deck = Dados.deck_sugerido(_id("monstro"))
	_atualizar()


func _aplicar_config(cfg: Dictionary) -> void:
	var desbloqueados := Jogo.monstros_desbloqueados()
	var monstro := str(cfg.get("monstro", ""))
	if not Jogo.monstro_desbloqueado(monstro):
		monstro = str(desbloqueados[0]) if not desbloqueados.is_empty() else str(Dados.monstros.keys()[0])
	_monstro_rapido = monstro
	for tipo in TIPOS:
		_indice[tipo] = maxi(0, (_opcoes[tipo] as Array).find(cfg.get(tipo, "")))
	_indice["monstro"] = maxi(0, (_opcoes["monstro"] as Array).find(monstro))
	_deck = (cfg.get("deck", []) as Array).duplicate()
	if _deck.is_empty():
		_deck = Dados.deck_sugerido(monstro)


func _atualizar() -> void:
	_atualizar_rapido()
	_atualizar_avancado()


func _atualizar_rapido() -> void:
	for id in _cartas_grade:
		var carta: CartaVisual = _cartas_grade[id]
		carta.selecionada = id == _monstro_rapido
		carta.queue_redraw()
	var m: Dictionary = Dados.monstros.get(_monstro_rapido, {})
	if m.is_empty():
		return
	var f := Dados.faccao(str(m.get("faccao", "")))
	var sugerido := Jogo.loadout_sugerido(_monstro_rapido)
	_carta_grande.definir("monstro", _monstro_rapido)
	_nome_rapido.text = str(m["nome"])
	_faccao_rapido.text = str(f["nome"])
	_faccao_rapido.add_theme_color_override("font_color", Color(str(f["cor"])).lightened(0.25))
	_carta_equip_rapido.definir("equipamento", str(sugerido["equipamento"]))
	_carta_cantico_rapido.definir("cantico", str(sugerido["cantico"]))
	_deck_rapido.text = "Deck pronto:\n%d golpes" % (sugerido["deck"] as Array).size()
	_carta_local_rapido.definir("local", _id("local"))


func _atualizar_avancado() -> void:
	for tipo in TIPOS:
		var carta: CartaVisual = _cartas[tipo]
		carta.definir(tipo, _id(tipo))
	var m: Dictionary = Dados.monstros[_id("monstro")]
	var f := Dados.faccao(str(m.get("faccao", "")))
	_legendas["monstro"].text = str(f["nome"])
	_legendas["monstro_titulo"].add_theme_color_override("font_color", Color(str(f["cor"])).lightened(0.15))
	_legendas["equipamento"].text = "Revelado no início da luta"
	_legendas["equipamento_titulo"].add_theme_color_override("font_color", Tema.MOLDURA_EQUIPAMENTO[1])
	var fc := Dados.faccao(str(Dados.canticos[_id("cantico")].get("faccao", "")))
	_legendas["cantico"].text = str(fc["nome"]) + ("  •  +15%" if fc.get("id", "") == f.get("id", "-") else "")
	_legendas["cantico_titulo"].add_theme_color_override("font_color", Color(str(fc["cor"])).lightened(0.2))
	var id_local := _id("local")
	if _local_travado:
		_legendas["local"].text = "Arena da etapa"
	else:
		_legendas["local"].text = "Sorteado na luta" if id_local == "aleatorio" else "Iniciativa: " + str(Dados.ATRIBUTOS[str(Dados.locais[id_local]["iniciativa"]["atributo"])])
	_legendas["local_titulo"].add_theme_color_override("font_color", Tema.OURO)

	# Elementos do monstro + equipamento acendem os bônus nas cartas de ataque.
	var elementos: Array = (m["elementos"] as Array).duplicate()
	var el_equip := str(Dados.equipamentos[_id("equipamento")].get("elemento", ""))
	if el_equip != "" and not elementos.has(el_equip):
		elementos.append(el_equip)
	for id in _cartas_ataque:
		var carta: CartaVisual = _cartas_ataque[id]
		carta.selecionada = _deck.has(id)
		carta.elementos_dono = elementos
		carta.queue_redraw()

	var custo := _custo_deck()
	_custo_grande.text = "%d/%d" % [custo, Dados.ORCAMENTO_DECK]
	_custo_grande.add_theme_color_override("font_color", Tema.VERMELHO if custo > Dados.ORCAMENTO_DECK else Tema.OURO)
	_custo_rodape.text = "CUSTO DO DECK:  %d/%d" % [custo, Dados.ORCAMENTO_DECK]
	_contagem.text = "Cartas: %d (de %d a %d)" % [_deck.size(), Dados.DECK_MIN, Dados.DECK_MAX]
	var problemas := PackedStringArray()
	if custo > Dados.ORCAMENTO_DECK:
		problemas.append("orçamento estourado")
	if _deck.size() < Dados.DECK_MIN:
		problemas.append("faltam cartas (mínimo %d)" % Dados.DECK_MIN)
	if _deck.size() > Dados.DECK_MAX:
		problemas.append("cartas demais (máximo %d)" % Dados.DECK_MAX)
	_botao_lutar.disabled = not problemas.is_empty()
	if problemas.is_empty():
		_dica.text = "DICA: monstros lutam, equipamentos os fortalecem, Cânticos mudam o curso da batalha e Locais transformam o campo. Bônus elementais acesos valem para o seu monstro."
		_dica.add_theme_color_override("font_color", Tema.TEXTO_SUAVE)
	else:
		_dica.text = "Deck inválido: " + ", ".join(problemas) + "."
		_dica.add_theme_color_override("font_color", Color("#ff7a66"))


func _on_lutar() -> void:
	var cfg: Dictionary
	if _modo_rapido:
		cfg = Jogo.loadout_sugerido(_monstro_rapido)
		cfg["local"] = _id("local")
	else:
		cfg = {
			"monstro": _id("monstro"),
			"equipamento": _id("equipamento"),
			"cantico": _id("cantico"),
			"local": _id("local"),
			"deck": _deck.duplicate(),
		}
	for chave in CHAVES_REPASSE:
		if config_inicial.has(chave):
			cfg[chave] = config_inicial[chave]
	Audio.tocar("confirmar")
	lutar.emit(cfg)


# ---------------------------------------------------------------------
# Desenhos auxiliares
# ---------------------------------------------------------------------

func _icone_tipo(ci: Control, tipo: String) -> void:
	var c := ci.size / 2.0
	match tipo:
		"monstro":
			Icones.emblema(ci, Dados.faccao(str(Dados.monstros[_id("monstro")].get("faccao", ""))), c, 26)
		"equipamento":
			Icones.chip(ci, c, 26, Tema.MOLDURA_EQUIPAMENTO[1])
			Icones.espada(ci, c, 16, Tema.MOLDURA_EQUIPAMENTO[2])
		"cantico":
			var fc := Dados.faccao(str(Dados.canticos[_id("cantico")].get("faccao", "")))
			Icones.chip(ci, c, 26, Color(str(fc["cor"])))
			Icones.nota(ci, c, 14, Color(str(fc["cor_clara"])))
		"local":
			Icones.chip(ci, c, 26, Tema.OURO)
			Icones.castelo(ci, c, 15, Tema.OURO_CLARO)


func _simbolo_coluna(ci: Desenho, tipo: String) -> void:
	var c := ci.size / 2.0
	var brilho := 0.6 + 0.25 * sin(ci.tempo * 2.2)
	match tipo:
		"monstro":
			var f := Dados.faccao(str(Dados.monstros[_id("monstro")].get("faccao", "")))
			Icones.simbolo_cantico(ci, c, 84, Color(str(f["cor"])), str(f["marca"]), brilho)
		"equipamento":
			Icones.simbolo_cantico(ci, c, 84, Color("#4f8fd6"), "espada", brilho)
		"cantico":
			var fc := Dados.faccao(str(Dados.canticos[_id("cantico")].get("faccao", "")))
			Icones.simbolo_cantico(ci, c, 84, Color(str(fc["cor"])), "nota", brilho)
		"local":
			Icones.simbolo_cantico(ci, c, 84, Tema.OURO, "castelo", brilho)


func _barra_segmentada(ci: Control, valor: int) -> void:
	var segmentos := Dados.ORCAMENTO_DECK
	var largura := ci.size.x / segmentos
	for i in segmentos:
		var r := Rect2(i * largura + 1, 0, largura - 2, ci.size.y)
		var cheio := i < valor
		var cor := Color("#3fa9ff") if cheio else Color(Tema.MEDIO, 0.6)
		if cheio and valor > segmentos:
			cor = Tema.VERMELHO
		ci.draw_rect(r, cor)
		if cheio:
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(1, 1, 1, 0.25))
	ci.draw_rect(Rect2(Vector2.ZERO, ci.size), Color(Tema.OURO, 0.5), false, 1.0)


func _rosa_dos_ventos(ci: CanvasItem, c: Vector2, r: float) -> void:
	for i in 8:
		var a := i * TAU / 8.0 - PI / 2.0
		var comprimento := r if i % 2 == 0 else r * 0.55
		var ponta := c + Vector2(cos(a), sin(a)) * comprimento
		var l1 := c + Vector2(cos(a + 0.4), sin(a + 0.4)) * r * 0.16
		var l2 := c + Vector2(cos(a - 0.4), sin(a - 0.4)) * r * 0.16
		ci.draw_colored_polygon(PackedVector2Array([ponta, l1, c]), Tema.TEXTO if i % 2 == 0 else Tema.TEXTO_SUAVE)
		ci.draw_colored_polygon(PackedVector2Array([ponta, c, l2]), Tema.MEDIO)
	ci.draw_arc(c, r * 0.72, 0, TAU, 32, Color(Tema.TEXTO_SUAVE, 0.6), 1.5, true)


func _losango(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), cor)


func _rotulo(texto: String, pos: Vector2, fonte: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Tema.fonte(fonte))
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l
