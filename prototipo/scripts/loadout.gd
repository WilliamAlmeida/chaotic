class_name Loadout
extends Control
## Tela "Carregamento de Combate" (mockup em docs/gui-conceito.md): 4 cartas de loadout
## com setas e o símbolo octogonal embaixo, e o deck de ataques à direita
## (orçamento de 20 pontos, de 6 a 10 cartas).

signal lutar(config: Dictionary)

const TIPOS := ["monstro", "equipamento", "cantico", "local"]
const TITULOS := {"monstro": "Monstro", "equipamento": "Equipamento", "cantico": "Cântico", "local": "Local"}
const SUBTITULOS := {
	"monstro": "O Eco que você controla na arena.",
	"equipamento": "Bônus ao monstro, oculto até a luta.",
	"cantico": "Magia musical: Q e a sequência.",
	"local": "A arena e quem tem a iniciativa.",
}
const LARGURA_COLUNA := 298.0
const TOPO_COLUNAS := 135.0

var config_inicial: Dictionary = {}

var _palco: Control
var _opcoes: Dictionary = {}
var _indice: Dictionary = {"monstro": 0, "equipamento": 0, "cantico": 0, "local": 0}
var _cartas: Dictionary = {}
var _legendas: Dictionary = {}
var _cartas_ataque: Dictionary = {}
var _deck: Array = []
var _custo_grande: Label
var _custo_rodape: Label
var _contagem: Label
var _dica: Label
var _botao_lutar: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_opcoes = {
		"monstro": Dados.monstros.keys(),
		"equipamento": Dados.equipamentos.keys(),
		"cantico": Dados.canticos.keys(),
		"local": ["aleatorio"] + Dados.locais.keys(),
	}
	_construir()
	_aplicar_config(config_inicial)
	_atualizar()


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
	_palco = Control.new()
	_palco.anchor_left = 0.5
	_palco.anchor_right = 0.5
	_palco.anchor_top = 0.5
	_palco.anchor_bottom = 0.5
	_palco.offset_left = -960
	_palco.offset_right = 960
	_palco.offset_top = -540
	_palco.offset_bottom = 540
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)

	_cabecalho()
	for i in TIPOS.size():
		_coluna(TIPOS[i], 32.0 + i * (LARGURA_COLUNA + 14.0))
	_painel_deck()
	_rodape()


func _cabecalho() -> void:
	_palco.add_child(Desenho.criar(func(ci: Control): _rosa_dos_ventos(ci, ci.size / 2.0, 34.0), Vector2(30, 18), Vector2(76, 76)))
	_palco.add_child(_rotulo("CARREGAMENTO DE COMBATE", Vector2(118, 16), "titulo", 52, Tema.TEXTO))
	_palco.add_child(_rotulo("ESCOLHA SUAS CARTAS E PREPARE-SE PARA O DUELO.", Vector2(122, 84), "texto", 17, Tema.TEXTO_SUAVE))
	var nav := RichTextLabel.new()
	nav.bbcode_enabled = true
	nav.fit_content = true
	nav.scroll_active = false
	nav.position = Vector2(1130, 34)
	nav.size = Vector2(520, 30)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_theme_font_override("normal_font", Tema.fonte("texto_negrito"))
	nav.add_theme_font_size_override("normal_font_size", 15)
	nav.text = "[color=#a9b4c4]INÍCIO   •   [/color][color=#e8b75a]LOADOUT[/color][color=#a9b4c4]   •   ARENA   •   PERFIL   •   AJUSTES[/color]"
	_palco.add_child(nav)
	_palco.add_child(_rotulo("MAGIA EM SINTONIA\nCOM UM MUNDO MAIOR.", Vector2(1700, 22), "texto", 13, Tema.TEXTO_SUAVE))
	_palco.add_child(Desenho.criar(func(ci: Control):
		ci.draw_line(Vector2(0, 0), Vector2(ci.size.x, 0), Color(Tema.OURO, 0.35), 1.5)
		_losango(ci, Vector2(ci.size.x / 2.0, 0), 5.0, Tema.OURO), Vector2(118, 120), Vector2(1772, 2)))


func _coluna(tipo: String, x: float) -> void:
	var y := TOPO_COLUNAS
	_palco.add_child(Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.55), Color(Tema.MEDIO, 0.7), 1, 10), Rect2(Vector2.ZERO, ci.size)), Vector2(x, y), Vector2(LARGURA_COLUNA, 800)))
	_palco.add_child(Desenho.criar(func(ci: Control): _icone_tipo(ci, tipo), Vector2(x + 12, y + 14), Vector2(56, 56)))
	var titulo := _rotulo(TITULOS[tipo], Vector2(x + 76, y + 10), "titulo", 30, Tema.TEXTO)
	_legendas[tipo + "_titulo"] = titulo
	_palco.add_child(titulo)
	var sub := _rotulo(SUBTITULOS[tipo], Vector2(x + 76, y + 48), "texto", 13, Tema.TEXTO_SUAVE)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(LARGURA_COLUNA - 86, 0)
	sub.size = Vector2(LARGURA_COLUNA - 86, 40)
	_palco.add_child(sub)

	var carta := CartaVisual.new()
	carta.position = Vector2(x + 9, y + 100)
	carta.size = Vector2(280, 420)
	carta.interativa = true
	carta.clicada.connect(func(_c: CartaVisual): _mudar(tipo, 1))
	_palco.add_child(carta)
	_cartas[tipo] = carta

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
		_palco.add_child(seta)

	_palco.add_child(Desenho.criar(func(ci: Control): _simbolo_coluna(ci, tipo), Vector2(x + 29, y + 535), Vector2(240, 220), true))
	var legenda := _rotulo("", Vector2(x, y + 758), "titulo", 17, Tema.TEXTO_SUAVE)
	legenda.size = Vector2(LARGURA_COLUNA, 30)
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legendas[tipo] = legenda
	_palco.add_child(legenda)


func _painel_deck() -> void:
	var x := 1290.0
	var y := TOPO_COLUNAS
	_palco.add_child(Desenho.criar(func(ci: Control):
		ci.draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.7), Color(Tema.OURO, 0.45), 2, 12), Rect2(Vector2.ZERO, ci.size)), Vector2(x, y), Vector2(598, 800)))
	_palco.add_child(Desenho.criar(func(ci: Control):
		Icones.chip(ci, ci.size / 2.0, 28, Tema.OURO)
		Icones.espada(ci, ci.size / 2.0, 18, Tema.TEXTO), Vector2(x + 14, y + 14), Vector2(60, 60)))
	_palco.add_child(_rotulo("Deck de Ataques", Vector2(x + 84, y + 12), "titulo", 32, Tema.TEXTO))
	_palco.add_child(Desenho.criar(func(ci: Control): _barra_segmentada(ci, _custo_deck()), Vector2(x + 86, y + 60), Vector2(300, 14), true))
	_custo_grande = _rotulo("0/20", Vector2(x + 400, y + 2), "titulo", 50, Tema.OURO)
	_custo_grande.size = Vector2(180, 60)
	_custo_grande.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_palco.add_child(_custo_grande)
	var legenda := _rotulo("CUSTO TOTAL", Vector2(x + 400, y + 62), "texto", 13, Tema.TEXTO_SUAVE)
	legenda.size = Vector2(180, 20)
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_palco.add_child(legenda)

	var rolagem := ScrollContainer.new()
	rolagem.position = Vector2(x + 10, y + 92)
	rolagem.size = Vector2(580, 698)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palco.add_child(rolagem)
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
	_palco.add_child(Desenho.criar(func(ci: Control):
		ci.draw_circle(ci.size / 2.0, 20, Color(Tema.CARVAO, 0.9))
		ci.draw_arc(ci.size / 2.0, 20, 0, TAU, 32, Tema.OURO, 2.0, true)
		Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, 31), "?", 26, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER), Vector2(32, y + 14), Vector2(44, 44)))
	_dica = _rotulo("", Vector2(90, y + 12), "texto", 15, Tema.TEXTO_SUAVE)
	_dica.size = Vector2(640, 60)
	_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palco.add_child(_dica)

	_custo_rodape = _rotulo("", Vector2(760, y + 4), "titulo", 20, Tema.TEXTO)
	_palco.add_child(_custo_rodape)
	_palco.add_child(Desenho.criar(func(ci: Control): _barra_segmentada(ci, _custo_deck()), Vector2(760, y + 38), Vector2(300, 16), true))
	_contagem = _rotulo("", Vector2(760, y + 60), "texto", 14, Tema.TEXTO_SUAVE)
	_palco.add_child(_contagem)

	var sugerir := Button.new()
	sugerir.text = "SUGERIR DECK"
	sugerir.position = Vector2(1090, y + 14)
	sugerir.size = Vector2(200, 56)
	sugerir.pressed.connect(_sugerir_deck)
	_palco.add_child(sugerir)
	var limpar := Button.new()
	limpar.text = "✕  LIMPAR DECK"
	limpar.position = Vector2(1300, y + 14)
	limpar.size = Vector2(200, 56)
	limpar.pressed.connect(func():
		_deck.clear()
		_atualizar())
	_palco.add_child(limpar)

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
	_palco.add_child(_botao_lutar)
	_botao_lutar.add_child(Desenho.criar(func(ci: Control):
		Icones.simbolo_cantico(ci, Vector2(40, 48), 26, Tema.OURO, "", 0.0)
		_rosa_dos_ventos(ci, Vector2(40, 48), 12.0), Vector2.ZERO, Vector2(80, 96)))


# ---------------------------------------------------------------------
# Comportamento
# ---------------------------------------------------------------------

func _mudar(tipo: String, passo: int) -> void:
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
	if cfg.is_empty():
		_sugerir_deck()
		return
	for tipo in TIPOS:
		_indice[tipo] = maxi(0, (_opcoes[tipo] as Array).find(cfg.get(tipo, "")))
	_deck = (cfg.get("deck", []) as Array).duplicate()


func _atualizar() -> void:
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
	lutar.emit({
		"monstro": _id("monstro"),
		"equipamento": _id("equipamento"),
		"cantico": _id("cantico"),
		"local": _id("local"),
		"deck": _deck.duplicate(),
	})


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
