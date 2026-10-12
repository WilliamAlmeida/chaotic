class_name Loadout
extends Control
## Tela de montagem: as cartas escolhem o monstro, o equipamento, o Cântico,
## o cenário e o deck de ataques (orçamento de 20 pontos, de 6 a 10 cartas).

signal lutar(config: Dictionary)

var config_inicial: Dictionary = {}

var _ids_monstros: Array = []
var _ids_equip: Array = []
var _ids_canticos: Array = []
var _ids_locais: Array = []
var _op_monstro: OptionButton
var _op_equip: OptionButton
var _op_cantico: OptionButton
var _op_local: OptionButton
var _desc_monstro: Label
var _desc_equip: Label
var _desc_cantico: Label
var _desc_local: Label
var _checks: Dictionary = {}
var _rotulos_ataque: Dictionary = {}
var _orcamento: Label
var _aviso: Label
var _botao_lutar: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_construir()
	_aplicar_config(config_inicial)
	_atualizar()


func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("#15121f")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 22)
	add_child(margem)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 10)
	margem.add_child(raiz)

	var titulo := _label("ECOS DE AETHERIS  -  Protótipo de Arena", 30)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	raiz.add_child(titulo)
	var sub := _label("Suas cartas definem quem você é na arena: o monstro que você controla, o equipamento que ele carrega, " +
		"o cenário da luta e os golpes que aparecem na sua mão durante o combate.", 14)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(sub)

	var colunas := HBoxContainer.new()
	colunas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colunas.add_theme_constant_override("separation", 24)
	raiz.add_child(colunas)

	# Coluna esquerda: monstro, equipamento, cântico e local.
	var rolagem_esq := ScrollContainer.new()
	rolagem_esq.custom_minimum_size.x = 430
	rolagem_esq.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colunas.add_child(rolagem_esq)
	var esquerda := VBoxContainer.new()
	esquerda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esquerda.add_theme_constant_override("separation", 6)
	rolagem_esq.add_child(esquerda)

	_ids_monstros = Dados.monstros.keys()
	_op_monstro = _seletor(esquerda, "Carta de Monstro", _ids_monstros, Dados.monstros)
	_desc_monstro = _descricao(esquerda)
	_ids_equip = Dados.equipamentos.keys()
	_op_equip = _seletor(esquerda, "Carta de Equipamento", _ids_equip, Dados.equipamentos)
	_desc_equip = _descricao(esquerda)
	_ids_canticos = Dados.canticos.keys()
	_op_cantico = _seletor(esquerda, "Carta de Cântico", _ids_canticos, Dados.canticos)
	_desc_cantico = _descricao(esquerda)
	_ids_locais = ["aleatorio"] + Dados.locais.keys()
	_op_local = _seletor(esquerda, "Carta de Local (cenário)", _ids_locais, Dados.locais)
	_desc_local = _descricao(esquerda)

	# Coluna direita: deck de ataques.
	var direita := VBoxContainer.new()
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.add_theme_constant_override("separation", 8)
	colunas.add_child(direita)
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation", 16)
	direita.add_child(cabecalho)
	cabecalho.add_child(_label("Deck de Ataques", 20))
	_orcamento = _label("", 16)
	_orcamento.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(_orcamento)
	var sugerir := Button.new()
	sugerir.text = "Sugerir deck"
	sugerir.pressed.connect(_sugerir_deck)
	cabecalho.add_child(sugerir)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	direita.add_child(rolagem)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	rolagem.add_child(grade)

	var ids_ataques: Array = Dados.ataques.keys()
	ids_ataques.sort_custom(func(a, b): return int(Dados.ataques[a]["custo"]) < int(Dados.ataques[b]["custo"]))
	for id in ids_ataques:
		var atk: Dictionary = Dados.ataques[id]
		var painel := PanelContainer.new()
		painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.1, 0.09, 0.15)
		estilo.set_corner_radius_all(6)
		estilo.set_content_margin_all(8)
		painel.add_theme_stylebox_override("panel", estilo)
		grade.add_child(painel)
		var v := VBoxContainer.new()
		painel.add_child(v)
		var check := CheckBox.new()
		check.text = "%s   [custo %d]" % [atk["nome"], int(atk["custo"])]
		check.toggled.connect(func(_ligado: bool): _atualizar())
		v.add_child(check)
		var detalhes := _label(_texto_ataque(atk), 12)
		detalhes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(detalhes)
		_checks[id] = check
		_rotulos_ataque[id] = detalhes

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 16)
	raiz.add_child(rodape)
	_aviso = _label("", 15)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(_aviso)
	_botao_lutar = Button.new()
	_botao_lutar.text = "   LUTAR!   "
	_botao_lutar.add_theme_font_size_override("font_size", 24)
	_botao_lutar.pressed.connect(_on_lutar)
	rodape.add_child(_botao_lutar)


func _seletor(pai: Control, titulo: String, ids: Array, fonte: Dictionary) -> OptionButton:
	pai.add_child(_label(titulo, 18))
	var op := OptionButton.new()
	for id in ids:
		op.add_item("Sortear do deck de locais" if id == "aleatorio" else str(fonte[id]["nome"]))
	op.item_selected.connect(func(_i: int): _atualizar())
	pai.add_child(op)
	return op


func _descricao(pai: Control) -> Label:
	var l := _label("", 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	pai.add_child(l)
	return l


func _label(texto: String, tamanho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	return l


func _texto_ataque(atk: Dictionary) -> String:
	var partes := PackedStringArray()
	partes.append(str(Dados.ARQUETIPOS.get(str(atk["arquetipo"]), "")))
	partes.append("Dano %d" % int(atk["dano_base"]))
	var bonus: Dictionary = atk.get("bonus_elemento", {})
	for el in bonus:
		partes.append("+%d %s" % [int(bonus[el]), Dados.ELEMENTOS[el]["nome"]])
	var texto := "  |  ".join(partes)
	var cond: Dictionary = atk.get("condicao", {})
	if not cond.is_empty():
		texto += "\n" + Combate.descrever_condicao(cond)
	return texto


func _monstro_atual() -> String:
	return str(_ids_monstros[_op_monstro.selected])


func _deck_atual() -> Array:
	var deck: Array = []
	for id in _checks:
		if _checks[id].button_pressed:
			deck.append(id)
	return deck


func _atualizar() -> void:
	var m: Dictionary = Dados.monstros[_monstro_atual()]
	var a: Dictionary = m["atributos"]
	var nomes_el := PackedStringArray()
	for el in m["elementos"]:
		nomes_el.append(Dados.ELEMENTOS[el]["nome"])
	_desc_monstro.text = "%s\nAgilidade %d   Força %d   Mente %d   Ânimo %d\nEnergia %d  |  Elementos: %s  |  Cargas de Cântico: %d\n%s" % [
		m["descricao"], int(a["agilidade"]), int(a["forca"]), int(a["mente"]), int(a["animo"]),
		int(m["energia"]), ", ".join(nomes_el), int(m["cargas_cantico"]), m["passiva"]["descricao"]]
	_desc_equip.text = str(Dados.equipamentos[_ids_equip[_op_equip.selected]]["descricao"]) + \
		"\n(Fica oculto para o oponente até o início da luta.)"
	_desc_cantico.text = str(Dados.canticos[_ids_canticos[_op_cantico.selected]]["descricao"]) + \
		"\nNa luta: aperte Q e repita a sequência de teclas antes do tempo acabar. Levar dano interrompe."
	var id_local := str(_ids_locais[_op_local.selected])
	if id_local == "aleatorio":
		_desc_local.text = "O cenário é sorteado entre todas as cartas de Local, como no anime."
	else:
		var loc: Dictionary = Dados.locais[id_local]
		_desc_local.text = "%s\nIniciativa: %s" % [loc["descricao"], Dados.ATRIBUTOS[str(loc["iniciativa"]["atributo"])]]

	# Destaca ataques que combinam com os elementos do monstro.
	for id in _rotulos_ataque:
		var bonus: Dictionary = Dados.ataques[id].get("bonus_elemento", {})
		var combina := bonus.is_empty()
		for el in bonus:
			if m["elementos"].has(el):
				combina = true
		_rotulos_ataque[id].add_theme_color_override("font_color", Color(0.6, 1.0, 0.65) if combina else Color(0.6, 0.6, 0.66))

	var deck := _deck_atual()
	var custo := 0
	for id in deck:
		custo += int(Dados.ataques[id]["custo"])
	_orcamento.text = "Orçamento: %d / %d    Cartas: %d (de %d a %d)" % [
		custo, Dados.ORCAMENTO_DECK, deck.size(), Dados.DECK_MIN, Dados.DECK_MAX]
	var problemas := PackedStringArray()
	if custo > Dados.ORCAMENTO_DECK:
		problemas.append("orçamento estourado")
	if deck.size() < Dados.DECK_MIN:
		problemas.append("faltam cartas")
	if deck.size() > Dados.DECK_MAX:
		problemas.append("cartas demais")
	_botao_lutar.disabled = not problemas.is_empty()
	if problemas.is_empty():
		_aviso.text = "Deck válido. Verde = ataques que combinam com os elementos do seu monstro. O oponente é sorteado."
		_aviso.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	else:
		_aviso.text = "Deck inválido: " + ", ".join(problemas)
		_aviso.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))


func _sugerir_deck() -> void:
	var sugerido := Dados.deck_sugerido(_monstro_atual())
	for id in _checks:
		_checks[id].set_pressed_no_signal(sugerido.has(id))
	_atualizar()


func _aplicar_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		_sugerir_deck()
		return
	_op_monstro.select(maxi(0, _ids_monstros.find(cfg.get("monstro", ""))))
	_op_equip.select(maxi(0, _ids_equip.find(cfg.get("equipamento", ""))))
	_op_cantico.select(maxi(0, _ids_canticos.find(cfg.get("cantico", ""))))
	_op_local.select(maxi(0, _ids_locais.find(cfg.get("local", "aleatorio"))))
	var deck: Array = cfg.get("deck", [])
	for id in _checks:
		_checks[id].set_pressed_no_signal(deck.has(id))


func _on_lutar() -> void:
	lutar.emit({
		"monstro": _monstro_atual(),
		"equipamento": _ids_equip[_op_equip.selected],
		"cantico": _ids_canticos[_op_cantico.selected],
		"local": _ids_locais[_op_local.selected],
		"deck": _deck_atual(),
	})
