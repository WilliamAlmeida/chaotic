class_name Hud
extends CanvasLayer
## Interface da batalha: energia, mão de 3 cartas, Cântico (mini-ritmo), banners e resultado.

signal revanche
signal menu

const LETRAS_CANTICO := {"mover_frente": "W", "mover_esq": "A", "mover_tras": "S", "mover_dir": "D"}
const COR_ATIVA := Color(0.45, 1.0, 0.5)
const COR_INATIVA := Color(0.55, 0.55, 0.62)

var jogador: Lutador
var inimigo: Lutador
var local: Dictionary = {}
var tempo_restante := 0.0

var _raiz: Control
var _lado_j: Dictionary = {}
var _lado_i: Dictionary = {}
var _cartas: Array = []
var _status: Label
var _banner: Label
var _banner_t := 0.0
var _tempo: Label
var _ritmo: PanelContainer
var _ritmo_titulo: Label
var _ritmo_texto: RichTextLabel
var _ritmo_barra: ProgressBar
var _ajuda: Label
var _resultado: PanelContainer
var _resultado_titulo: Label
var _resultado_sub: Label


func configurar(j: Lutador, i: Lutador, loc: Dictionary) -> void:
	jogador = j
	inimigo = i
	local = loc
	_construir()


func banner(texto: String, duracao := 2.0) -> void:
	if _banner == null:
		return
	_banner.text = texto
	_banner_t = duracao
	_banner.modulate.a = 1.0


func mostrar_resultado(vitoria: bool, detalhes: Dictionary) -> void:
	_resultado_titulo.text = "VITÓRIA!" if vitoria else "DERROTA"
	_resultado_titulo.add_theme_color_override("font_color", COR_ATIVA if vitoria else Color(1, 0.4, 0.4))
	var motivo := "Tempo esgotado: vence quem tiver mais Energia (%)." if detalhes.get("motivo") == "tempo" else ""
	_resultado_sub.text = "%s\nDuração: %ds\n\n[R] Lutar de novo    [M] Voltar ao loadout" % [motivo, int(detalhes.get("tempo", 0))]
	_resultado.visible = true


# ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if jogador == null or inimigo == null:
		return
	_atualizar_lado(_lado_j, jogador)
	_atualizar_lado(_lado_i, inimigo)
	_atualizar_cartas()
	_atualizar_status()
	_atualizar_ritmo()
	var restante := maxi(0, ceili(tempo_restante))
	_tempo.text = "%d:%02d" % [restante / 60, restante % 60]
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t / 0.35, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_F1:
		_ajuda.visible = not _ajuda.visible
	elif _resultado.visible and tecla.physical_keycode == KEY_R:
		revanche.emit()
	elif _resultado.visible and tecla.physical_keycode == KEY_M:
		menu.emit()


func _atualizar_lado(lado: Dictionary, l: Lutador) -> void:
	lado["nome"].text = "%s   %d / %d" % [l.nome, ceili(l.energia), int(l.energia_max)]
	lado["barra"].value = l.energia / l.energia_max
	var nomes_el := PackedStringArray()
	for el in l.elementos:
		nomes_el.append(Dados.ELEMENTOS[el]["nome"])
	var equip := str(l.equipamento.get("nome", "nenhum")) if l.equipamento_revelado else "???"
	var estado := ""
	if l.energia <= 0.0:
		estado = "  [DERROTADO]"
	elif l.atordoado_t > 0.0:
		estado = "  [ATORDOADO]"
	elif l.cantando:
		estado = "  [CANTANDO]"
	lado["info"].text = "AGI %d   FOR %d   MEN %d   ÂNI %d%s\n%s\nEquip: %s   |   Cargas de Cântico: %d" % [
		int(l.atributo("agilidade")), int(l.atributo("forca")), int(l.atributo("mente")), int(l.atributo("animo")),
		estado, ", ".join(nomes_el), equip, l.cargas_cantico]


func _atualizar_cartas() -> void:
	for i in MaoCartas.TAMANHO:
		var c: Dictionary = _cartas[i]
		var id := jogador.mao.slots[i]
		var estilo: StyleBoxFlat = c["estilo"]
		if id == "":
			c["titulo"].text = "[%d]  recarregando..." % (i + 1)
			c["dano"].text = ""
			c["cond"].text = ""
			c["barra"].value = jogador.mao.progresso_recarga(i)
			c["painel"].modulate = Color(1, 1, 1, 0.55)
			estilo.border_color = Color(0.3, 0.3, 0.35)
			continue
		var atk: Dictionary = Dados.ataques[id]
		c["titulo"].text = "[%d]  %s   (custo %d)" % [i + 1, atk["nome"], int(atk["custo"])]
		c["dano"].text = "%s  |  %s" % [Dados.ARQUETIPOS.get(str(atk["arquetipo"]), ""), _texto_dano(atk)]
		var cond: Dictionary = atk.get("condicao", {})
		if cond.is_empty():
			c["cond"].text = "(sem condição)"
			c["cond"].add_theme_color_override("font_color", COR_INATIVA)
		else:
			var ativa := Combate.avaliar_condicao(cond, jogador, inimigo)
			c["cond"].text = ("ATIVA: " if ativa else "inativa: ") + Combate.descrever_condicao(cond)
			c["cond"].add_theme_color_override("font_color", COR_ATIVA if ativa else COR_INATIVA)
		c["barra"].value = 1.0
		c["painel"].modulate = Color(1, 1, 1, 1) if jogador.pode_agir() else Color(1, 1, 1, 0.8)
		estilo.border_color = jogador.cor_ataque(atk)


func _texto_dano(atk: Dictionary) -> String:
	var partes := PackedStringArray()
	partes.append("Dano %d" % int(atk["dano_base"]))
	var bonus: Dictionary = atk.get("bonus_elemento", {})
	for el in bonus:
		var nome_el: String = Dados.ELEMENTOS[el]["nome"]
		if jogador.elementos.has(el):
			partes.append("+%d %s" % [int(bonus[el]), nome_el])
		else:
			partes.append("(sem %s)" % nome_el)
	return "  ".join(partes)


func _atualizar_status() -> void:
	var esquiva := "pronta" if jogador.esquiva_recarga <= 0.0 else "%.1fs" % jogador.esquiva_recarga
	var nome_cantico := str(jogador.cantico.get("nome", "nenhum"))
	_status.text = "Deck: %d   Descarte: %d   |   Esquiva [Shift]: %s   |   Cântico [Q]: %s (%d cargas)" % [
		jogador.mao.compra.size(), jogador.mao.descarte.size(), esquiva, nome_cantico, jogador.cargas_cantico]


func _atualizar_ritmo() -> void:
	_ritmo.visible = jogador.cantando
	if not jogador.cantando:
		return
	_ritmo_titulo.text = "%s - aperte a sequência:" % str(jogador.cantico.get("nome", ""))
	var partes := PackedStringArray()
	for i in jogador.cantico_sequencia.size():
		var letra: String = LETRAS_CANTICO.get(jogador.cantico_sequencia[i], "?")
		if i < jogador.cantico_progresso:
			partes.append("[color=#66ff77]%s[/color]" % letra)
		elif i == jogador.cantico_progresso:
			partes.append("[color=#ffe066][b]%s[/b][/color]" % letra)
		else:
			partes.append(letra)
	_ritmo_texto.text = "[center]%s[/center]" % "   ".join(partes)
	_ritmo_barra.value = clampf(1.0 - jogador.cantico_t / jogador.cantico_limite, 0.0, 1.0)


# ---------------------------------------------------------------------
# Construção da interface (feita em código para o protótipo não depender de cenas)
# ---------------------------------------------------------------------

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_lado_j = _criar_lado(false)
	_lado_i = _criar_lado(true)

	var topo := VBoxContainer.new()
	topo.anchor_left = 0.5
	topo.anchor_right = 0.5
	topo.offset_left = -170
	topo.offset_right = 170
	topo.offset_top = 10
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(topo)
	_tempo = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	topo.add_child(_tempo)
	var info_local := _label(14, HORIZONTAL_ALIGNMENT_CENTER)
	info_local.text = "%s\nIniciativa: %s" % [local.get("nome", ""), Dados.ATRIBUTOS.get(str(local.get("iniciativa", {}).get("atributo", "")), "-")]
	topo.add_child(info_local)

	_banner = _label(46, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.26
	_banner.anchor_bottom = 0.26
	_banner.offset_bottom = 70
	_banner.modulate.a = 0.0
	_raiz.add_child(_banner)

	_status = _label(15, HORIZONTAL_ALIGNMENT_CENTER)
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.anchor_right = 1.0
	_status.offset_top = -200
	_status.offset_bottom = -175
	_raiz.add_child(_status)

	var linha := HBoxContainer.new()
	linha.anchor_left = 0.5
	linha.anchor_right = 0.5
	linha.anchor_top = 1.0
	linha.anchor_bottom = 1.0
	linha.offset_left = -400
	linha.offset_right = 400
	linha.offset_top = -168
	linha.offset_bottom = -14
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 12)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(linha)
	for i in MaoCartas.TAMANHO:
		_cartas.append(_criar_carta(linha))

	_ritmo = PanelContainer.new()
	_ritmo.anchor_left = 0.5
	_ritmo.anchor_right = 0.5
	_ritmo.anchor_top = 0.5
	_ritmo.anchor_bottom = 0.5
	_ritmo.offset_left = -230
	_ritmo.offset_right = 230
	_ritmo.offset_top = 30
	_ritmo.offset_bottom = 150
	_ritmo.add_theme_stylebox_override("panel", _caixa(Color(0.12, 0.06, 0.2, 0.9), Color(0.75, 0.5, 1.0)))
	_ritmo.visible = false
	_raiz.add_child(_ritmo)
	var vr := VBoxContainer.new()
	_ritmo.add_child(vr)
	_ritmo_titulo = _label(16, HORIZONTAL_ALIGNMENT_CENTER)
	vr.add_child(_ritmo_titulo)
	_ritmo_texto = RichTextLabel.new()
	_ritmo_texto.bbcode_enabled = true
	_ritmo_texto.fit_content = true
	_ritmo_texto.scroll_active = false
	_ritmo_texto.custom_minimum_size = Vector2(420, 48)
	_ritmo_texto.add_theme_font_size_override("normal_font_size", 36)
	_ritmo_texto.add_theme_font_size_override("bold_font_size", 40)
	vr.add_child(_ritmo_texto)
	_ritmo_barra = _barra(Color(0.75, 0.5, 1.0), 8)
	vr.add_child(_ritmo_barra)

	_ajuda = _label(13)
	_ajuda.anchor_top = 1.0
	_ajuda.anchor_bottom = 1.0
	_ajuda.offset_left = 14
	_ajuda.offset_right = 240
	_ajuda.offset_top = -170
	_ajuda.offset_bottom = -10
	_ajuda.text = "WASD  mover\nMouse  câmera (Tab trava)\nEspaço  pular\nShift  esquivar\nClique / J  golpe básico\n1 2 3  cartas de ataque\nQ  Cântico (depois WASD)\nEsc  soltar o mouse\nF1  esconder ajuda"
	_raiz.add_child(_ajuda)

	_resultado = PanelContainer.new()
	_resultado.anchor_left = 0.5
	_resultado.anchor_right = 0.5
	_resultado.anchor_top = 0.5
	_resultado.anchor_bottom = 0.5
	_resultado.offset_left = -250
	_resultado.offset_right = 250
	_resultado.offset_top = -120
	_resultado.offset_bottom = 120
	_resultado.add_theme_stylebox_override("panel", _caixa(Color(0.07, 0.06, 0.1, 0.95), Color(1.0, 0.7, 0.3)))
	_resultado.visible = false
	_raiz.add_child(_resultado)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_resultado.add_child(v)
	_resultado_titulo = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_resultado_titulo)
	_resultado_sub = _label(16, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_resultado_sub)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 16)
	v.add_child(botoes)
	var b1 := Button.new()
	b1.text = "Lutar de novo"
	b1.pressed.connect(func(): revanche.emit())
	botoes.add_child(b1)
	var b2 := Button.new()
	b2.text = "Voltar ao loadout"
	b2.pressed.connect(func(): menu.emit())
	botoes.add_child(b2)


func _criar_lado(direita: bool) -> Dictionary:
	var alinhamento := HORIZONTAL_ALIGNMENT_RIGHT if direita else HORIZONTAL_ALIGNMENT_LEFT
	var caixa := VBoxContainer.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if direita:
		caixa.anchor_left = 1.0
		caixa.anchor_right = 1.0
		caixa.offset_left = -440
		caixa.offset_right = -20
		caixa.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		caixa.offset_left = 20
		caixa.offset_right = 440
	caixa.offset_top = 14
	_raiz.add_child(caixa)
	var nome := _label(22, alinhamento)
	caixa.add_child(nome)
	var barra := _barra(Color(0.95, 0.35, 0.3) if direita else Color(0.3, 0.85, 0.45), 22)
	if direita:
		barra.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	caixa.add_child(barra)
	var info := _label(14, alinhamento)
	caixa.add_child(info)
	return {"nome": nome, "barra": barra, "info": info}


func _criar_carta(pai: Control) -> Dictionary:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(255, 150)
	var estilo := _caixa(Color(0.08, 0.07, 0.12, 0.88), Color(0.5, 0.5, 0.5))
	painel.add_theme_stylebox_override("panel", estilo)
	pai.add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	painel.add_child(v)
	var titulo := _label(16)
	v.add_child(titulo)
	var dano := _label(13)
	v.add_child(dano)
	var cond := _label(13)
	cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cond.custom_minimum_size.x = 230
	cond.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cond)
	var barra := _barra(Color(0.95, 0.8, 0.35), 8)
	v.add_child(barra)
	return {"painel": painel, "estilo": estilo, "titulo": titulo, "dano": dano, "cond": cond, "barra": barra}


func _label(tamanho: int, alinhamento := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.horizontal_alignment = alinhamento
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


func _barra(cor: Color, altura: float) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, altura)
	barra.max_value = 1.0
	barra.step = 0.0
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0, 0, 0, 0.55)
	fundo.set_corner_radius_all(4)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	cheio.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", cheio)
	return barra


func _caixa(fundo: Color, borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(10)
	return estilo
