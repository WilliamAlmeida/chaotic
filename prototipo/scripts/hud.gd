class_name Hud
extends CanvasLayer
## HUD da luta (mockup em docs/gui-conceito.md): painéis dos lutadores no topo,
## cronômetro octogonal, painel de Cântico, 3 cartas na mão, ritmo do Cântico,
## contador de combo, banners e tela de resultado. Base de 1920x1080.

signal revanche
signal menu

const LETRAS_CANTICO := {"mover_frente": "W", "mover_esq": "A", "mover_tras": "S", "mover_dir": "D"}
const LARGURA_CARTA := 200.0
const ALTURA_CARTA := 250.0

var jogador: Lutador
var inimigo: Lutador
var local: Dictionary = {}
var tempo_restante := 0.0

var _raiz: Control
var _cartas: Array = []
var _banner: Label
var _banner_t := 0.0
var _combo_mostrado := 0
var _combo_t := 0.0
var _ajuda: Label
var _resultado: Control
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
	_resultado_titulo.add_theme_color_override("font_color", Tema.OURO_CLARO if vitoria else Color("#ff6b5a"))
	var motivo := "Tempo esgotado: vence quem tiver mais Energia (%)." if detalhes.get("motivo") == "tempo" else ""
	_resultado_sub.text = "%s\nDuração: %ds\n\n[R] Lutar de novo    [M] Voltar ao loadout" % [motivo, int(detalhes.get("tempo", 0))]
	_resultado.visible = true


# ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if jogador == null or inimigo == null:
		return
	for i in _cartas.size():
		var carta: CartaVisual = _cartas[i]
		var id := jogador.mao.slots[i]
		if carta.id != id:
			carta.definir("ataque", id)
		carta.progresso = jogador.mao.progresso_recarga(i) if id == "" else 1.0
		carta.desabilitada = id != "" and (jogador.atordoado_t > 0.0 or jogador.cantando)
		carta.queue_redraw()
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t / 0.35, 0.0, 1.0)
	if jogador.combo >= 2:
		_combo_mostrado = jogador.combo
		_combo_t = 1.2
	else:
		_combo_t = maxf(0.0, _combo_t - delta)


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


# ---------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var painel_j := PainelLutador.new()
	painel_j.configurar(jogador, false)
	_ancorar(painel_j, Vector2(0, 0), Vector2(18, 12), PainelLutador.TAMANHO)
	_raiz.add_child(painel_j)
	var painel_i := PainelLutador.new()
	painel_i.configurar(inimigo, true)
	_ancorar(painel_i, Vector2(1, 0), Vector2(-18 - PainelLutador.TAMANHO.x, 12), PainelLutador.TAMANHO)
	_raiz.add_child(painel_i)

	var relogio := Desenho.criar(_desenhar_relogio, Vector2.ZERO, Vector2(220, 190), true)
	_ancorar(relogio, Vector2(0.5, 0), Vector2(-110, 6), Vector2(220, 190))
	_raiz.add_child(relogio)

	var cantico := Desenho.criar(_desenhar_painel_cantico, Vector2.ZERO, Vector2(430, 170), true)
	_ancorar(cantico, Vector2(0, 1), Vector2(40, -200), Vector2(430, 170))
	_raiz.add_child(cantico)

	var ritmo := Desenho.criar(_desenhar_ritmo, Vector2.ZERO, Vector2(440, 170), true)
	_ancorar(ritmo, Vector2(1, 1), Vector2(-480, -200), Vector2(440, 170))
	_raiz.add_child(ritmo)

	# Mão de 3 cartas com abas de tecla.
	var largura_total := LARGURA_CARTA * 3 + 28 * 2
	for i in MaoCartas.TAMANHO:
		var x := -largura_total / 2.0 + i * (LARGURA_CARTA + 28)
		var aba := Desenho.criar(_desenhar_aba.bind(str(i + 1)), Vector2.ZERO, Vector2(44, 34))
		_ancorar(aba, Vector2(0.5, 1), Vector2(x + LARGURA_CARTA / 2.0 - 22, -ALTURA_CARTA - 54), Vector2(44, 34))
		_raiz.add_child(aba)
		var carta := CartaVisual.new()
		_ancorar(carta, Vector2(0.5, 1), Vector2(x, -ALTURA_CARTA - 18), Vector2(LARGURA_CARTA, ALTURA_CARTA))
		carta.dono = jogador
		carta.alvo = inimigo
		carta.definir("ataque", "")
		_raiz.add_child(carta)
		_cartas.append(carta)

	var status := Desenho.criar(_desenhar_status, Vector2.ZERO, Vector2(700, 30), true)
	_ancorar(status, Vector2(0.5, 1), Vector2(-350, -ALTURA_CARTA - 92), Vector2(700, 30))
	_raiz.add_child(status)

	var combo := Desenho.criar(_desenhar_combo, Vector2.ZERO, Vector2(420, 170), true)
	_ancorar(combo, Vector2(1, 0.5), Vector2(-460, -170), Vector2(420, 170))
	_raiz.add_child(combo)

	_banner = Label.new()
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.offset_bottom = 90
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_override("font", Tema.fonte("titulo"))
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_color", Tema.OURO_CLARO)
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	_banner.modulate.a = 0.0
	_raiz.add_child(_banner)

	var dica := _rotulo("F1  controles", 14, Tema.TEXTO_SUAVE)
	_ancorar(dica, Vector2(0, 0), Vector2(30, 188), Vector2(200, 24))
	_raiz.add_child(dica)
	_ajuda = _rotulo("WASD  mover\nMouse  câmera (Tab trava)\nEspaço  pular\nShift  esquivar\nClique / J  golpe básico\n1 2 3  cartas da mão\nQ  Cântico (depois WASD)\nEsc  soltar o mouse", 16, Tema.TEXTO)
	_ajuda.add_theme_constant_override("outline_size", 6)
	_ajuda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ancorar(_ajuda, Vector2(0, 0), Vector2(30, 214), Vector2(300, 220))
	_ajuda.visible = false
	_raiz.add_child(_ajuda)

	_construir_resultado()


func _construir_resultado() -> void:
	_resultado = PanelContainer.new()
	_resultado.add_theme_stylebox_override("panel", Tema.caixa(Color(Tema.CARVAO, 0.96), Tema.OURO, 3, 14, Color(Tema.OURO, 0.3), 18))
	_ancorar(_resultado, Vector2(0.5, 0.5), Vector2(-320, -170), Vector2(640, 340))
	_resultado.visible = false
	_raiz.add_child(_resultado)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_resultado.add_child(v)
	_resultado_titulo = _rotulo("", 64, Tema.OURO_CLARO, "titulo")
	_resultado_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_resultado_titulo)
	_resultado_sub = _rotulo("", 18, Tema.TEXTO)
	_resultado_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_resultado_sub)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 18)
	v.add_child(botoes)
	for par in [["LUTAR DE NOVO", func(): revanche.emit()], ["VOLTAR AO LOADOUT", func(): menu.emit()]]:
		var b := Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(240, 54)
		b.pressed.connect(par[1])
		botoes.add_child(b)


# ---------------------------------------------------------------------
# Desenhos
# ---------------------------------------------------------------------

func _desenhar_relogio(ci: Desenho) -> void:
	var c := Vector2(ci.size.x / 2.0, 74)
	var pts := PackedVector2Array()
	for p in Icones.octogono(Vector2.ZERO, 1.0):
		pts.append(c + Vector2(p.x * 100, p.y * 64))
	ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.92))
	ci.draw_polyline(Icones.fechar(pts), Tema.OURO, 3.0, true)
	for lado in [-1.0, 1.0]:
		var ponta := c + Vector2(lado * 118, 0)
		ci.draw_colored_polygon(PackedVector2Array([ponta, ponta + Vector2(-lado * 16, -8), ponta + Vector2(-lado * 16, 8)]), Tema.OURO)
	var restante := maxi(0, ceili(tempo_restante))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, c.y - 30), "DUELO", 17, Tema.TEXTO_SUAVE, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3)
	var cor := Tema.TEXTO if restante > 30 else Color("#ff8a6b")
	Tema.texto(ci, Tema.fonte("numero"), Vector2(0, c.y + 26), "%02d:%02d" % [restante / 60, restante % 60], 58, cor, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 5)
	var attr := str(local.get("iniciativa", {}).get("atributo", ""))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, 162), str(local.get("nome", "")), 17, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(0, 182), "Iniciativa: %s" % Dados.ATRIBUTOS.get(attr, "-"), 14, Tema.TEXTO_SUAVE, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3)


func _painel(ci: Control, cor_borda: Color) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var pts := PackedVector2Array([Vector2(18, 0), Vector2(w, 0), Vector2(w, h - 18), Vector2(w - 18, h), Vector2(0, h), Vector2(0, 18)])
	ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.86))
	ci.draw_polyline(Icones.fechar(pts), cor_borda, 2.5, true)
	var interno := PackedVector2Array()
	for p in pts:
		interno.append(p + (Vector2(w, h) / 2.0 - p).normalized() * 6.0)
	ci.draw_polyline(Icones.fechar(interno), Color(cor_borda, 0.3), 1.0, true)


func _desenhar_painel_cantico(ci: Desenho) -> void:
	var fac := Dados.faccao(str(jogador.cantico.get("faccao", "")))
	var cor := Color(str(fac.get("cor", "#7f6bff")))
	_painel(ci, cor)
	Icones.simbolo_cantico(ci, Vector2(44, 44), 26, cor, "nota", 0.3)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(84, 40), "CÂNTICO", 28, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 4)
	Tema.texto(ci, Tema.fonte("texto"), Vector2(86, 64), "%s   [Q]" % str(jogador.cantico.get("nome", "—")), 15, Tema.TEXTO_SUAVE, 330, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var total := maxi(jogador.cargas_max, 1)
	for i in maxi(total, 4):
		var c := Vector2(62 + i * 86, 120)
		var cheia := i < jogador.cargas_cantico
		if i >= total:
			Icones.simbolo_cantico(ci, c, 34, Color(0.3, 0.32, 0.38), "", 0.0, false)
		else:
			var brilho := 0.35 + 0.2 * sin(ci.tempo * 3.0 + i) if cheia else 0.0
			Icones.simbolo_cantico(ci, c, 34, cor, "nota" if cheia else "", brilho, cheia)


func _desenhar_ritmo(ci: Desenho) -> void:
	var fac := Dados.faccao(str(jogador.cantico.get("faccao", "")))
	var cor := Color(str(fac.get("cor", "#7f6bff")))
	_painel(ci, cor if jogador.cantando else Color(Tema.MEDIO, 0.9))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(24, 38), "RITMO DO CÂNTICO", 24, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 4)
	var sequencia: Array = jogador.cantico_sequencia if jogador.cantando else ["mover_frente", "mover_esq", "mover_tras", "mover_dir"]
	var subtitulo := "Execute a sequência:" if jogador.cantando else "Aperte [Q] para cantar (%d cargas)" % jogador.cargas_cantico
	Tema.texto(ci, Tema.fonte("texto"), Vector2(26, 62), subtitulo, 15, Tema.TEXTO_SUAVE, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
	for i in sequencia.size():
		var r := Rect2(26 + i * 76, 78, 64, 60)
		var fundo := Color(Tema.PAINEL, 0.9)
		var borda := Color(Tema.MEDIO, 0.9)
		var cor_letra := Tema.TEXTO_SUAVE
		var brilho := Color(0, 0, 0, 0)
		var tamanho_brilho := 0
		if jogador.cantando:
			cor_letra = Tema.TEXTO
			borda = Color(cor, 0.9)
			if i < jogador.cantico_progresso:
				fundo = Color("#1f6b38")
				borda = Color("#5dff8a")
			elif i == jogador.cantico_progresso:
				borda = Tema.OURO_CLARO
				brilho = Color(Tema.OURO, 0.6)
				tamanho_brilho = 10
				cor_letra = Tema.OURO_CLARO
		ci.draw_style_box(Tema.caixa(fundo, borda, 3, 8, brilho, tamanho_brilho), r)
		Tema.texto(ci, Tema.fonte("titulo"), Vector2(r.position.x, r.position.y + 44), str(LETRAS_CANTICO.get(sequencia[i], "?")), 36, cor_letra, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)
	Icones.simbolo_cantico(ci, Vector2(ci.size.x - 52, 98), 38, cor, "nota", 0.5 if jogador.cantando else 0.0, jogador.cargas_cantico > 0)
	if jogador.cantando:
		var fracao := clampf(1.0 - jogador.cantico_t / jogador.cantico_limite, 0.0, 1.0)
		ci.draw_rect(Rect2(26, 148, 300, 8), Color(0, 0, 0, 0.6))
		ci.draw_rect(Rect2(26, 148, 300 * fracao, 8), cor.lightened(0.3))


func _desenhar_aba(ci: Control, tecla: String) -> void:
	var pts := PackedVector2Array([Vector2(6, 0), Vector2(ci.size.x - 6, 0), Vector2(ci.size.x, ci.size.y), Vector2(0, ci.size.y)])
	ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.95))
	ci.draw_polyline(Icones.fechar(pts), Tema.OURO, 2.0, true)
	Tema.texto(ci, Tema.fonte("numero"), Vector2(0, 27), tecla, 26, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3)


func _desenhar_status(ci: Desenho) -> void:
	var esquiva := "pronta" if jogador.esquiva_recarga <= 0.0 else "%.1fs" % jogador.esquiva_recarga
	var texto := "Deck %d   •   Descarte %d   •   Esquiva [Shift]: %s" % [jogador.mao.compra.size(), jogador.mao.descarte.size(), esquiva]
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(0, 22), texto, 16, Tema.TEXTO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _desenhar_combo(ci: Desenho) -> void:
	if _combo_t <= 0.0 or _combo_mostrado < 2:
		return
	var alfa := clampf(_combo_t / 0.4, 0.0, 1.0)
	var elogio := "Boa Sequência!"
	if _combo_mostrado >= 6:
		elogio = "Imparável!"
	elif _combo_mostrado >= 4:
		elogio = "Excelente!"
	var pulso := 1.0 + 0.06 * sin(ci.tempo * 10.0)
	ci.draw_set_transform(Vector2(40, 40), -0.12, Vector2(pulso, pulso))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(0, 60), str(_combo_mostrado), 96, Color(Tema.OURO_CLARO, alfa), -1, HORIZONTAL_ALIGNMENT_LEFT, 10, Color(0.3, 0.12, 0.02, alfa))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(70 if _combo_mostrado < 10 else 120, 50), "GOLPES", 48, Color(Tema.OURO, alfa), -1, HORIZONTAL_ALIGNMENT_LEFT, 8, Color(0.3, 0.12, 0.02, alfa))
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(80, 92), elogio, 28, Color(Tema.TEXTO, alfa), -1, HORIZONTAL_ALIGNMENT_LEFT, 6, Color(0, 0, 0, alfa))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------
# Utilitários
# ---------------------------------------------------------------------

## Posiciona um Control por âncora (0..1) + deslocamento em pixels da base 1920x1080.
func _ancorar(c: Control, ancora: Vector2, deslocamento: Vector2, tamanho: Vector2) -> void:
	c.anchor_left = ancora.x
	c.anchor_right = ancora.x
	c.anchor_top = ancora.y
	c.anchor_bottom = ancora.y
	c.offset_left = deslocamento.x
	c.offset_top = deslocamento.y
	c.offset_right = deslocamento.x + tamanho.x
	c.offset_bottom = deslocamento.y + tamanho.y


func _rotulo(texto: String, tamanho: int, cor: Color, fonte := "texto_negrito") -> Label:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Tema.fonte(fonte))
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l
