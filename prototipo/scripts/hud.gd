class_name Hud
extends CanvasLayer
## HUD da luta, estilo desenho animado de sábado de manhã (docs/gui-conceito.md): painéis
## grandes dos lutadores no topo, relógio octogonal, painel de Cântico com as cargas como
## notas, 3 cartas tocáveis na mão, setas gigantes do Cântico no centro, combo saltitante,
## dicas do modo fácil, banners de "episódio", avisos de evento e tela de resultado com
## estrelas e confete. Base de 1920x1080; em telas 20:9 (celular) as âncoras esticam.
##
## API usada pela Batalha: configurar(jogador, inimigo, local), banner(texto, duracao),
## aviso_evento(titulo, cor), mostrar_resultado(vitoria, detalhes), sinais revanche/menu
## e a var tempo_restante.

signal revanche
signal menu

const LETRAS_CANTICO := {"mover_frente": "W", "mover_esq": "A", "mover_tras": "S", "mover_dir": "D"}
const SETAS_CANTICO := {"mover_frente": "cima", "mover_esq": "esq", "mover_tras": "baixo", "mover_dir": "dir"}
const LARGURA_CARTA := 200.0
const ALTURA_CARTA := 250.0
## Modo fácil: no máximo uma dica a cada INTERVALO_DICA segundos, cada uma dura DURACAO_DICA.
const INTERVALO_DICA := 6.0
const DURACAO_DICA := 2.8

var jogador: Lutador
var inimigo: Lutador
var local: Dictionary = {}
var tempo_restante := 0.0

var _config: Dictionary = {}
var _campanha := false
var _toque := false
var _tempo := 0.0
var _raiz: Control
var _cartas: Array = []
var _slots_anteriores: Array = ["", "", ""]
var _ajuda: Label
var _dica_tecla: Label

# Banner (intro, iniciativa, "LUTEM!")
var _banner_no: Desenho
var _banner_texto := ""
var _banner_sub := ""
var _banner_t := 0.0
var _banner_total := 2.0
var _banner_episodio := false
var _banner_escala := 1.0

# Aviso de evento da arena (faixa colorida deslizante)
var _aviso_no: Desenho
var _aviso_titulo := ""
var _aviso_cor := Tema.LARANJA
var _aviso_t := 0.0
var _aviso_total := 2.2

# Combo
var _combo_no: Desenho
var _combo_mostrado := 0
var _combo_t := 0.0
var _combo_escala := 1.0
var _combo_anterior := 0

# Dica do modo fácil (1 linha no topo-centro)
var _dica_no: Desenho
var _dica_texto := ""
var _dica_t := 0.0
var _dica_espera := 3.0
var _dica_ultima := ""
var _dica_escala := 1.0

# Cântico (setas grandes no centro)
var _ritmo_centro: Desenho
var _cantava := false
var _progresso_anterior := 0
var _cantico_fim := ""
var _cantico_fim_t := 0.0
var _nota_t := 0.0

# Dano no jogador (vinheta vermelha nas bordas)
var _energia_j_anterior := -1.0
var _energia_i_anterior := -1.0
var _vinheta_t := 0.0

# Resultado
var _resultado_camada: CanvasLayer
var _resultado: Control
var _resultado_titulo: Label
var _resultado_sub: Label
var _botao_revanche: Button
var _botao_menu: Button
var _estrelas_total := 0
var _estrelas_acesas := 0
var _estrela_t := 0.0
var _estrela_pop := 0.0
var _confete: Array = []
var _resultado_vitoria := false
var _resultado_t := 0.0


func configurar(j: Lutador, i: Lutador, loc: Dictionary) -> void:
	jogador = j
	inimigo = i
	local = loc
	var pai := get_parent()
	if pai != null and pai.get("config") != null and typeof(pai.get("config")) == TYPE_DICTIONARY:
		_config = pai.get("config")
	_campanha = _config.has("campanha")
	_toque = Jogo.toque_ativo()
	layer = 10
	_construir()


## Texto grande no meio da tela. O primeiro banner (nome da arena) vira um "título de
## episódio" com faixa dourada e, na campanha, mostra título, frase e regra do chefe.
func banner(texto: String, duracao := 2.0, subtitulo := "") -> void:
	if _banner_no == null:
		return
	_banner_texto = texto
	_banner_sub = subtitulo
	_banner_total = maxf(duracao, 0.4)
	_banner_t = _banner_total
	_banner_episodio = local.has("nome") and texto.begins_with(str(local["nome"]))
	if _banner_episodio and subtitulo == "":
		var partes := PackedStringArray()
		if _config.has("titulo"):
			partes.append(str(_config["titulo"]))
		if _config.has("frase"):
			partes.append(str(_config["frase"]))
		var campanha: Dictionary = _config.get("campanha", {}) if typeof(_config.get("campanha")) == TYPE_DICTIONARY else {}
		if campanha.has("regra") and str(campanha["regra"]) != "":
			partes.append(str(campanha["regra"]))
		_banner_sub = "\n".join(partes)
	_banner_escala = 0.3
	var tw := create_tween()
	tw.tween_property(self, "_banner_escala", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Faixa grande colorida com ícone de alerta que entra deslizando e some em ~2 s.
func aviso_evento(titulo: String, cor: Color = Tema.LARANJA, duracao := 2.2) -> void:
	if _aviso_no == null:
		return
	_aviso_titulo = titulo
	_aviso_cor = cor
	_aviso_total = maxf(duracao, 0.8)
	_aviso_t = _aviso_total
	Audio.tocar("aviso")


func mostrar_resultado(vitoria: bool, detalhes: Dictionary) -> void:
	_resultado_vitoria = vitoria
	_resultado_t = 0.0
	_resultado_titulo.text = "VITÓRIA!" if vitoria else "QUASE LÁ!"
	_resultado_titulo.add_theme_color_override("font_color", Tema.OURO_CLARO if vitoria else Tema.LARANJA)
	var linhas := PackedStringArray()
	if detalhes.get("motivo") == "tempo":
		linhas.append("O tempo acabou: venceu quem tinha mais Energia.")
	if vitoria:
		linhas.append("Mandou muito bem, %s!" % jogador.nome)
	else:
		linhas.append("Você quase conseguiu. Tente de novo!")
	linhas.append("Duração: %d s" % int(detalhes.get("tempo", 0)))
	_resultado_sub.text = "\n".join(linhas)
	# Estrelas: pela Energia que sobrou (3 se > 60%, 2 se > 30%, 1 só por vencer).
	_estrelas_total = 0
	if vitoria:
		var fracao := float(detalhes.get("energia_restante", jogador.energia)) / maxf(jogador.energia_max, 1.0)
		_estrelas_total = 3 if fracao > 0.6 else (2 if fracao > 0.3 else 1)
	_estrelas_acesas = 0
	_estrela_t = 0.7
	_estrela_pop = 0.0
	_confete.clear()
	if vitoria:
		for k in 260:
			_soltar_confete(true)
	_resultado_camada.visible = true
	_resultado.scale = Vector2(0.3, 0.3)
	_resultado.pivot_offset = _resultado.size / 2.0
	var tw := create_tween()
	tw.tween_property(_resultado, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.tocar("vitoria" if vitoria else "derrota")
	_botao_revanche.grab_focus()


# ---------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if jogador == null or inimigo == null:
		return
	_tempo += delta
	_atualizar_cartas()
	_atualizar_dano(delta)
	_atualizar_combo(delta)
	_atualizar_cantico(delta)
	_atualizar_dica(delta)
	if _banner_t > 0.0:
		_banner_t -= delta
	if _aviso_t > 0.0:
		_aviso_t -= delta
	if _resultado_camada.visible:
		_atualizar_resultado(delta)


func _em_andamento() -> bool:
	var pai := get_parent()
	return pai != null and bool(pai.get("em_andamento"))


func _atualizar_cartas() -> void:
	var som_tocado := false
	for i in _cartas.size():
		var carta: CartaVisual = _cartas[i]
		var id: String = jogador.mao.slots[i]
		if carta.id != id:
			carta.definir("ataque", id)
		carta.progresso = jogador.mao.progresso_recarga(i) if id == "" else 1.0
		carta.desabilitada = id != "" and (jogador.atordoado_t > 0.0 or jogador.cantando or jogador.energia <= 0.0)
		if id != "" and _slots_anteriores[i] == "":
			# A carta acabou de ficar pronta: pulso e som.
			carta.pulsar()
			if not som_tocado:
				som_tocado = true
				Audio.tocar("carta", -3.0, 1.0 + 0.06 * i)
		_slots_anteriores[i] = id
		carta.queue_redraw()


func _atualizar_dano(delta: float) -> void:
	if _energia_j_anterior < 0.0:
		_energia_j_anterior = jogador.energia
		_energia_i_anterior = inimigo.energia
	if jogador.energia < _energia_j_anterior - 0.05:
		var dano := _energia_j_anterior - jogador.energia
		_vinheta_t = minf(0.6, 0.25 + dano / 80.0)
		Efeitos.tremer_camera(get_tree(), clampf(dano / 30.0, 0.15, 1.0))
	if inimigo.energia < _energia_i_anterior - 0.05:
		var dano := _energia_i_anterior - inimigo.energia
		Efeitos.tremer_camera(get_tree(), clampf(dano / 60.0, 0.1, 0.6))
	_energia_j_anterior = jogador.energia
	_energia_i_anterior = inimigo.energia
	_vinheta_t = maxf(0.0, _vinheta_t - delta)


func _atualizar_combo(delta: float) -> void:
	if jogador.combo >= 2:
		if jogador.combo != _combo_anterior:
			_combo_mostrado = jogador.combo
			_combo_t = 1.5
			_combo_escala = 1.7
			var tw := create_tween()
			tw.tween_property(self, "_combo_escala", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_combo_t = maxf(0.0, _combo_t - delta)
	_combo_anterior = jogador.combo


func _atualizar_cantico(delta: float) -> void:
	if jogador.cantando:
		if not _cantava:
			_progresso_anterior = 0
			_cantico_fim = ""
			_cantico_fim_t = 0.0
		if jogador.cantico_progresso > _progresso_anterior:
			_nota_t = 0.35
			_progresso_anterior = jogador.cantico_progresso
	elif _cantava:
		var completo := jogador.cantico_sequencia.size() > 0 and jogador.cantico_progresso >= jogador.cantico_sequencia.size()
		_cantico_fim = "ok" if completo else "falha"
		_cantico_fim_t = 1.0
	_cantava = jogador.cantando
	_nota_t = maxf(0.0, _nota_t - delta)
	_cantico_fim_t = maxf(0.0, _cantico_fim_t - delta)
	# As setas do centro só capturam toques enquanto o jogador canta.
	_ritmo_centro.mouse_filter = Control.MOUSE_FILTER_STOP if jogador.cantando else Control.MOUSE_FILTER_IGNORE


func _atualizar_dica(delta: float) -> void:
	_dica_t = maxf(0.0, _dica_t - delta)
	if not Jogo.facil() or not _em_andamento() or jogador.energia <= 0.0:
		return
	_dica_espera -= delta
	if _dica_t > 0.0 or _dica_espera > 0.0:
		return
	var candidatas := PackedStringArray()
	if jogador.energia / jogador.energia_max < 0.3:
		candidatas.append("Esquive e espere a carta!")
	if jogador.cargas_cantico > 0 and not jogador.cantando:
		candidatas.append("Cante!" if _toque else "Cante! Aperte Q")
	var pronta := false
	for i in jogador.mao.slots.size():
		if jogador.mao.slots[i] != "" and not _cartas[i].desabilitada:
			pronta = true
	if pronta:
		candidatas.append("Toque na carta!" if _toque else "Aperte 1, 2 ou 3 para usar a carta!")
	if candidatas.is_empty():
		return
	var escolha := candidatas[0]
	for c in candidatas:
		if c != _dica_ultima:
			escolha = c
			break
	_dica_ultima = escolha
	_dica_texto = escolha
	_dica_t = DURACAO_DICA
	_dica_espera = INTERVALO_DICA
	_dica_escala = 0.4
	var tw := create_tween()
	tw.tween_property(self, "_dica_escala", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _atualizar_resultado(delta: float) -> void:
	_resultado_t += delta
	# Estrelas acendem uma a uma, com som.
	if _estrelas_acesas < _estrelas_total:
		_estrela_t -= delta
		if _estrela_t <= 0.0:
			_estrelas_acesas += 1
			_estrela_t = 0.55
			_estrela_pop = 1.0
			Audio.tocar("estrela", 0.0, 1.0 + 0.18 * _estrelas_acesas)
	_estrela_pop = maxf(0.0, _estrela_pop - delta * 2.5)
	# Chuva leve de confete por alguns segundos depois do estouro inicial.
	if _resultado_vitoria and _resultado_t < 6.0:
		for k in 3:
			_soltar_confete(false)
	var altura := _raiz.size.y + 60.0
	var vivos: Array = []
	for c in _confete:
		c["vel"] += Vector2(0, 420.0) * delta
		c["vel"].x = lerpf(c["vel"].x, sin(_tempo * 3.0 + c["fase"]) * 60.0, delta * 2.0)
		c["pos"] += c["vel"] * delta
		c["rot"] += c["vrot"] * delta
		if c["pos"].y < altura:
			vivos.append(c)
	_confete = vivos


func _soltar_confete(estouro: bool) -> void:
	var w := _raiz.size.x
	var cores := [Tema.OURO_CLARO, Tema.VERMELHO_CLARO, Tema.VERDE_CLARO, Tema.AZUL_CLARO, Color("#ff7ad9"), Color("#ffffff")]
	var c := {
		"pos": Vector2(w / 2.0 + randf_range(-120, 120), _raiz.size.y * 0.4) if estouro else Vector2(randf() * w, -30.0),
		"vel": Vector2(randf_range(-900, 900), randf_range(-1100, -300)) if estouro else Vector2(randf_range(-40, 40), randf_range(60, 160)),
		"rot": randf() * TAU,
		"vrot": randf_range(-9.0, 9.0),
		"cor": cores[randi() % cores.size()],
		"tam": Vector2(randf_range(16, 28), randf_range(9, 16)),
		"fase": randf() * TAU,
	}
	_confete.append(c)


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_F1 and not _toque:
		_ajuda.visible = not _ajuda.visible
	elif _resultado_camada.visible and tecla.physical_keycode in [KEY_R, KEY_ENTER, KEY_KP_ENTER]:
		_acionar_revanche()
	elif _resultado_camada.visible and tecla.physical_keycode == KEY_M:
		_acionar_menu()


func _acionar_revanche() -> void:
	Audio.tocar("confirmar")
	revanche.emit()


func _acionar_menu() -> void:
	Audio.tocar("clique")
	menu.emit()


func _usar_carta(i: int) -> void:
	if jogador == null or not jogador.controles_ativos:
		return
	if jogador.usar_carta(i):
		_cartas[i].pulsar(0.1)
	else:
		Audio.tocar("aviso", -8.0, 1.4)


## Toque numa das setas grandes do centro durante o Cântico: envia aquela nota.
func _on_ritmo_input(event: InputEvent) -> void:
	if jogador == null or not jogador.cantando:
		return
	var botao := event as InputEventMouseButton
	var toque := event as InputEventScreenTouch
	var pos := Vector2.ZERO
	if botao != null and botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT:
		pos = botao.position
	elif toque != null and toque.pressed:
		pos = toque.position
	else:
		return
	_ritmo_centro.accept_event()
	var caixas := _caixas_ritmo(jogador.cantico_sequencia.size())
	for i in caixas.size():
		if caixas[i].grow(8).has_point(pos):
			jogador.cantico_tecla(jogador.cantico_sequencia[i])
			return


# ---------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# Vinheta vermelha nas bordas quando o jogador leva dano.
	var vinheta := Desenho.criar(_desenhar_vinheta, Vector2.ZERO, Vector2.ZERO, true)
	vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(vinheta)

	var painel_j := PainelLutador.new()
	painel_j.configurar(jogador, false)
	_ancorar(painel_j, Vector2(0, 0), Vector2(18, 12), PainelLutador.TAMANHO)
	_raiz.add_child(painel_j)
	var painel_i := PainelLutador.new()
	painel_i.configurar(inimigo, true)
	_ancorar(painel_i, Vector2(1, 0), Vector2(-18 - PainelLutador.TAMANHO.x, 12), PainelLutador.TAMANHO)
	_raiz.add_child(painel_i)

	var relogio := Desenho.criar(_desenhar_relogio, Vector2.ZERO, Vector2(240, 214), true)
	_ancorar(relogio, Vector2(0.5, 0), Vector2(-120, 4), Vector2(240, 214))
	_raiz.add_child(relogio)

	var cantico := Desenho.criar(_desenhar_painel_cantico, Vector2.ZERO, Vector2(450, 180), true)
	_ancorar(cantico, Vector2(0, 1), Vector2(36, -206), Vector2(450, 180))
	_raiz.add_child(cantico)

	var status := Desenho.criar(_desenhar_status, Vector2.ZERO, Vector2(450, 180), true)
	_ancorar(status, Vector2(1, 1), Vector2(-486, -206), Vector2(450, 180))
	_raiz.add_child(status)

	# Mão de 3 cartas tocáveis, com abas de tecla no teclado.
	var largura_total := LARGURA_CARTA * 3 + 28 * 2
	for i in MaoCartas.TAMANHO:
		var x := -largura_total / 2.0 + i * (LARGURA_CARTA + 28)
		if not _toque:
			var aba := Desenho.criar(_desenhar_aba.bind(str(i + 1)), Vector2.ZERO, Vector2(48, 36))
			_ancorar(aba, Vector2(0.5, 1), Vector2(x + LARGURA_CARTA / 2.0 - 24, -ALTURA_CARTA - 56), Vector2(48, 36))
			_raiz.add_child(aba)
		var carta := CartaVisual.new()
		carta.interativa = true
		carta.brilho_pronta = true
		_ancorar(carta, Vector2(0.5, 1), Vector2(x, -ALTURA_CARTA - 18), Vector2(LARGURA_CARTA, ALTURA_CARTA))
		carta.dono = jogador
		carta.alvo = inimigo
		carta.definir("ataque", "")
		carta.clicada.connect(func(_c): _usar_carta(i))
		_raiz.add_child(carta)
		_cartas.append(carta)

	# Setas gigantes do Cântico no centro da tela (também tocáveis).
	_ritmo_centro = Desenho.criar(_desenhar_ritmo_centro, Vector2.ZERO, Vector2(1100, 340), true)
	_ancorar(_ritmo_centro, Vector2(0.5, 0.5), Vector2(-550, -200), Vector2(1100, 340))
	_ritmo_centro.gui_input.connect(_on_ritmo_input)
	_raiz.add_child(_ritmo_centro)

	_combo_no = Desenho.criar(_desenhar_combo, Vector2.ZERO, Vector2(560, 200), true)
	_ancorar(_combo_no, Vector2(1, 0.3), Vector2(-600, -100), Vector2(560, 200))
	_raiz.add_child(_combo_no)

	_banner_no = Desenho.criar(_desenhar_banner, Vector2.ZERO, Vector2.ZERO, true)
	_banner_no.anchor_left = 0.0
	_banner_no.anchor_right = 1.0
	_banner_no.anchor_top = 0.3
	_banner_no.anchor_bottom = 0.3
	_banner_no.offset_top = -130
	_banner_no.offset_bottom = 130
	_raiz.add_child(_banner_no)

	_aviso_no = Desenho.criar(_desenhar_aviso, Vector2.ZERO, Vector2.ZERO, true)
	_aviso_no.anchor_left = 0.0
	_aviso_no.anchor_right = 1.0
	_aviso_no.anchor_top = 0.25
	_aviso_no.anchor_bottom = 0.25
	_aviso_no.offset_top = -60
	_aviso_no.offset_bottom = 60
	_raiz.add_child(_aviso_no)

	_dica_no = Desenho.criar(_desenhar_dica, Vector2.ZERO, Vector2(1000, 90), true)
	_ancorar(_dica_no, Vector2(0.5, 0), Vector2(-500, 222), Vector2(1000, 90))
	_raiz.add_child(_dica_no)

	if _toque:
		_dica_tecla = _rotulo("Toque na carta para atacar  •  Joystick move  •  Arraste para girar a câmera", 18, Tema.TEXTO_SUAVE)
	else:
		_dica_tecla = _rotulo("F1  controles", 16, Tema.TEXTO_SUAVE)
	_dica_tecla.add_theme_constant_override("outline_size", 5)
	_dica_tecla.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ancorar(_dica_tecla, Vector2(0, 0), Vector2(30, 206), Vector2(900, 26))
	_raiz.add_child(_dica_tecla)
	_ajuda = _rotulo("WASD  mover\nMouse  câmera (Tab trava)\nEspaço  pular (voadores: subir)\nShift  esquivar\nClique / J  golpe básico\n1 2 3  cartas da mão\nQ  Cântico (depois WASD)\nEsc  soltar o mouse", 18, Tema.TEXTO)
	_ajuda.add_theme_constant_override("outline_size", 6)
	_ajuda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ancorar(_ajuda, Vector2(0, 0), Vector2(30, 236), Vector2(340, 240))
	_ajuda.visible = false
	_raiz.add_child(_ajuda)

	_construir_resultado()


func _construir_resultado() -> void:
	_resultado_camada = CanvasLayer.new()
	_resultado_camada.layer = 30
	_resultado_camada.visible = false
	add_child(_resultado_camada)

	var fundo := Desenho.criar(_desenhar_fundo_resultado, Vector2.ZERO, Vector2.ZERO, true)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_resultado_camada.add_child(fundo)

	_resultado = PanelContainer.new()
	_resultado.add_theme_stylebox_override("panel", Tema.caixa(Color(Tema.CARVAO, 0.96), Tema.OURO, 5, 26, Color(Tema.OURO, 0.4), 28))
	_ancorar(_resultado, Vector2(0.5, 0.5), Vector2(-470, -330), Vector2(940, 660))
	_resultado_camada.add_child(_resultado)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 28)
	_resultado.add_child(margem)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	margem.add_child(v)
	_resultado_titulo = _rotulo("", 104, Tema.OURO_CLARO, "titulo")
	_resultado_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resultado_titulo.add_theme_constant_override("outline_size", 16)
	_resultado_titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02, 1.0))
	v.add_child(_resultado_titulo)
	var estrelas := Desenho.criar(_desenhar_estrelas, Vector2.ZERO, Vector2(480, 150), true)
	estrelas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(estrelas)
	_resultado_sub = _rotulo("", 26, Tema.TEXTO)
	_resultado_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_resultado_sub)
	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 10)
	v.add_child(espaco)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 30)
	v.add_child(botoes)
	_botao_revanche = Button.new()
	_botao_revanche.text = "TENTAR DE NOVO" if _campanha else "LUTAR DE NOVO"
	Tema.botao_grande(_botao_revanche, Color("#2f7fe0"), 30, Vector2(400, 96))
	_botao_revanche.pressed.connect(_acionar_revanche)
	botoes.add_child(_botao_revanche)
	_botao_menu = Button.new()
	_botao_menu.text = "CONTINUAR" if _campanha else "VOLTAR AO LOADOUT"
	Tema.botao_grande(_botao_menu, Color("#2f9e4a") if _campanha else Tema.MEDIO, 30, Vector2(400, 96))
	_botao_menu.pressed.connect(_acionar_menu)
	botoes.add_child(_botao_menu)


# ---------------------------------------------------------------------
# Desenhos
# ---------------------------------------------------------------------

func _desenhar_vinheta(ci: Desenho) -> void:
	if _vinheta_t <= 0.0:
		return
	var alfa := clampf(_vinheta_t / 0.4, 0.0, 1.0) * 0.6
	var w := ci.size.x
	var h := ci.size.y
	var cor := Color(0.9, 0.1, 0.05, alfa)
	var nada := Color(0.9, 0.1, 0.05, 0.0)
	var esp := 140.0
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, esp), Vector2(0, esp)]), PackedColorArray([cor, cor, nada, nada]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, h - esp), Vector2(w, h - esp), Vector2(w, h), Vector2(0, h)]), PackedColorArray([nada, nada, cor, cor]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(esp, 0), Vector2(esp, h), Vector2(0, h)]), PackedColorArray([cor, nada, nada, cor]))
	ci.draw_polygon(PackedVector2Array([Vector2(w - esp, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - esp, h)]), PackedColorArray([nada, cor, cor, nada]))


func _desenhar_relogio(ci: Desenho) -> void:
	var restante := maxi(0, ceili(tempo_restante))
	var urgente := restante <= 10 and _em_andamento()
	var c := Vector2(ci.size.x / 2.0, 80)
	var escala := 1.0 + (0.08 * absf(sin(_tempo * 6.0)) if urgente else 0.0)
	ci.draw_set_transform(c, 0.0, Vector2(escala, escala))
	var pts := PackedVector2Array()
	for p in Icones.octogono(Vector2.ZERO, 1.0):
		pts.append(Vector2(p.x * 112, p.y * 70))
	ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.92))
	ci.draw_polyline(Icones.fechar(pts), Icones.CONTORNO, 6.0, true)
	ci.draw_polyline(Icones.fechar(pts), Tema.VERMELHO_CLARO if urgente else Tema.OURO, 3.5, true)
	for lado in [-1.0, 1.0]:
		var ponta := Vector2(lado * 132, 0)
		ci.draw_colored_polygon(PackedVector2Array([ponta, ponta + Vector2(-lado * 18, -9), ponta + Vector2(-lado * 18, 9)]), Tema.OURO)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(-100, -34), "DUELO", 18, Tema.TEXTO_SUAVE, 200, HORIZONTAL_ALIGNMENT_CENTER, 3)
	var cor := Tema.TEXTO if restante > 30 else (Tema.VERMELHO_CLARO if urgente else Color("#ff8a6b"))
	Tema.texto(ci, Tema.fonte("numero"), Vector2(-110, 30), "%02d:%02d" % [restante / 60, restante % 60], 66, cor, 220, HORIZONTAL_ALIGNMENT_CENTER, 6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var attr := str(local.get("iniciativa", {}).get("atributo", ""))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(-60, 180), str(local.get("nome", "")), 19, Tema.OURO_CLARO, ci.size.x + 120, HORIZONTAL_ALIGNMENT_CENTER, 5)
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(-60, 204), "Iniciativa: %s" % Dados.ATRIBUTOS.get(attr, "-"), 15, Tema.TEXTO_SUAVE, ci.size.x + 120, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _painel(ci: Control, cor_borda: Color) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var pts := PackedVector2Array([Vector2(18, 0), Vector2(w, 0), Vector2(w, h - 18), Vector2(w - 18, h), Vector2(0, h), Vector2(0, 18)])
	ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.86))
	ci.draw_polyline(Icones.fechar(pts), Icones.CONTORNO, 5.0, true)
	ci.draw_polyline(Icones.fechar(pts), cor_borda, 3.0, true)
	var interno := PackedVector2Array()
	for p in pts:
		interno.append(p + (Vector2(w, h) / 2.0 - p).normalized() * 7.0)
	ci.draw_polyline(Icones.fechar(interno), Color(cor_borda, 0.3), 1.0, true)


func _desenhar_painel_cantico(ci: Desenho) -> void:
	var fac := Dados.faccao(str(jogador.cantico.get("faccao", "")))
	var cor := Color(str(fac.get("cor", "#7f6bff")))
	var carregado := jogador.cargas_cantico > 0 and not jogador.cantando
	_painel(ci, cor if carregado else Color(Tema.MEDIO, 0.9))
	Icones.simbolo_cantico(ci, Vector2(46, 46), 28, cor, "nota", 0.4 if carregado else 0.0, carregado)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(88, 42), "CÂNTICO", 30, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 5)
	var nome := str(jogador.cantico.get("nome", "—"))
	var dica := "" if _toque else "   [Q]"
	Tema.texto(ci, Tema.fonte("texto"), Vector2(90, 68), nome + dica, 17, Tema.TEXTO_SUAVE, 340, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var total := maxi(jogador.cargas_max, 1)
	var espaco := 92.0 if total <= 4 else (ci.size.x - 100.0) / total
	for i in maxi(total, 4):
		var c := Vector2(60 + i * espaco, 126)
		var cheia := i < jogador.cargas_cantico
		if i >= total:
			Icones.simbolo_cantico(ci, c, 36, Color(0.3, 0.32, 0.38), "", 0.0, false)
		else:
			var r := 36.0 + (3.0 * sin(_tempo * 4.0 + i) if cheia else 0.0)
			var brilho := 0.4 + 0.25 * sin(_tempo * 3.0 + i) if cheia else 0.0
			Icones.simbolo_cantico(ci, c, r, cor, "nota" if cheia else "", brilho, cheia)
	if carregado and not _em_andamento():
		return
	if jogador.cantando:
		Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(0, 170), "Cantando...", 16, cor.lightened(0.4), ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3)


## Caixas das setas do Cântico no centro (em coordenadas do _ritmo_centro).
func _caixas_ritmo(n: int) -> Array:
	var caixas: Array = []
	var lado := 150.0 if n <= 4 else 120.0
	var espaco := 30.0
	var largura := n * lado + (n - 1) * espaco
	var x0 := (_ritmo_centro.size.x - largura) / 2.0
	for i in n:
		caixas.append(Rect2(x0 + i * (lado + espaco), 110, lado, lado))
	return caixas


func _desenhar_ritmo_centro(ci: Desenho) -> void:
	var cantando := jogador.cantando
	if not cantando and _cantico_fim_t <= 0.0:
		return
	var fac := Dados.faccao(str(jogador.cantico.get("faccao", "")))
	var cor := Color(str(fac.get("cor", "#7f6bff")))
	var sequencia: Array = jogador.cantico_sequencia
	var n := sequencia.size()
	if n == 0:
		return
	var alfa := 1.0 if cantando else clampf(_cantico_fim_t / 0.4, 0.0, 1.0)
	var caixas := _caixas_ritmo(n)
	var tremor := Vector2.ZERO
	if _cantico_fim == "falha" and _cantico_fim_t > 0.5:
		tremor = Vector2(sin(_tempo * 60.0) * 10.0, 0)
	ci.draw_set_transform(tremor, 0.0, Vector2.ONE)

	# Cabeçalho.
	var titulo := "CANTE!"
	var sub := "Toque nas setas" if _toque else "Aperte as setas (W A S D)"
	if _cantico_fim == "ok":
		titulo = "PERFEITO!"
		sub = ""
	elif _cantico_fim == "falha":
		titulo = "OPS!"
		sub = "Tente de novo quando tiver carga"
	var cor_titulo := Tema.OURO_CLARO
	if _cantico_fim == "ok":
		cor_titulo = Tema.VERDE_CLARO
	elif _cantico_fim == "falha":
		cor_titulo = Tema.VERMELHO_CLARO
	var pulo := 1.0 + (0.1 * absf(sin(_tempo * 8.0)) if cantando else 0.0)
	ci.draw_set_transform(Vector2(ci.size.x / 2.0, 50) + tremor, 0.0, Vector2(pulo, pulo))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(-400, 20), titulo, 58, Color(cor_titulo, alfa), 800, HORIZONTAL_ALIGNMENT_CENTER, 10, Color(0.1, 0.05, 0.02, alfa))
	ci.draw_set_transform(tremor, 0.0, Vector2.ONE)
	if sub != "":
		Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(0, 96), sub, 22, Color(Tema.TEXTO, alfa), ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 5)

	var progresso := jogador.cantico_progresso
	for i in n:
		var r: Rect2 = caixas[i]
		var fundo := Color(Tema.PAINEL, 0.92 * alfa)
		var borda := Color(Tema.MEDIO, alfa)
		var cor_seta := Color(Tema.TEXTO_SUAVE, alfa)
		var brilho := Color(0, 0, 0, 0)
		var tamanho_brilho := 0
		var escala := 1.0
		var feita := i < progresso
		var atual := cantando and i == progresso
		if _cantico_fim == "falha":
			fundo = Color("#5a1410", alfa)
			borda = Color(Tema.VERMELHO_CLARO, alfa)
			cor_seta = Color(Tema.VERMELHO_CLARO, alfa)
		elif feita or _cantico_fim == "ok":
			fundo = Color("#1f6b38", alfa)
			borda = Color(Tema.VERDE_CLARO, alfa)
			cor_seta = Color(Tema.VERDE_CLARO, alfa)
			if i == progresso - 1 and _nota_t > 0.0:
				escala = 1.0 + 0.3 * (_nota_t / 0.35)
		elif atual:
			fundo = Color(cor.darkened(0.5), alfa)
			borda = Color(Tema.OURO_CLARO, alfa)
			cor_seta = Color(Tema.OURO_CLARO, alfa)
			brilho = Color(Tema.OURO, 0.7 * alfa)
			tamanho_brilho = 16
			escala = 1.0 + 0.08 * sin(_tempo * 9.0)
		ci.draw_set_transform(r.get_center() + tremor, 0.0, Vector2(escala, escala))
		var local_r := Rect2(-r.size / 2.0, r.size)
		ci.draw_style_box(Tema.caixa(fundo, borda, 5, 18, brilho, tamanho_brilho), local_r)
		var direcao := str(SETAS_CANTICO.get(sequencia[i], "cima"))
		if _cantico_fim == "falha":
			Icones.errado(ci, Vector2.ZERO, r.size.x * 0.26, cor_seta)
		elif feita or _cantico_fim == "ok":
			Icones.seta(ci, Vector2(0, -8), r.size.x * 0.26, direcao, Color(cor_seta, 0.55 * alfa))
			Icones.certo(ci, Vector2(r.size.x * 0.22, r.size.y * 0.22), r.size.x * 0.16, cor_seta)
		else:
			Icones.seta(ci, Vector2(0, -6), r.size.x * 0.3, direcao, cor_seta)
		if not _toque:
			Tema.texto(ci, Tema.fonte("numero"), Vector2(-r.size.x / 2.0, r.size.y / 2.0 - 8), str(LETRAS_CANTICO.get(sequencia[i], "?")), 26, Color(Tema.TEXTO, 0.8 * alfa), r.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3)
	ci.draw_set_transform(tremor, 0.0, Vector2.ONE)

	# Barra de tempo do Cântico.
	if cantando:
		var fracao := clampf(1.0 - jogador.cantico_t / maxf(jogador.cantico_limite, 0.01), 0.0, 1.0)
		var primeira: Rect2 = caixas[0]
		var ultima: Rect2 = caixas[n - 1]
		var barra := Rect2(primeira.position.x, ultima.end.y + 22, ultima.end.x - primeira.position.x, 18)
		ci.draw_style_box(Tema.caixa(Color(0, 0, 0, 0.6), Tema.OURO, 2, 9), barra)
		var cor_barra := cor.lightened(0.3) if fracao > 0.3 else Tema.VERMELHO_CLARO
		ci.draw_style_box(Tema.caixa(cor_barra, Color(0, 0, 0, 0), 0, 7), Rect2(barra.position + Vector2(3, 3), Vector2(maxf(0.0, (barra.size.x - 6) * fracao), barra.size.y - 6)))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_aba(ci: Control, tecla: String) -> void:
	var pts := PackedVector2Array([Vector2(6, 0), Vector2(ci.size.x - 6, 0), Vector2(ci.size.x, ci.size.y), Vector2(0, ci.size.y)])
	ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.95))
	ci.draw_polyline(Icones.fechar(pts), Tema.OURO, 2.5, true)
	Tema.texto(ci, Tema.fonte("numero"), Vector2(0, 29), tecla, 28, Tema.OURO_CLARO, ci.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3)


func _desenhar_status(ci: Desenho) -> void:
	var pronta := jogador.esquiva_recarga <= 0.0
	_painel(ci, Tema.OURO if pronta else Color(Tema.MEDIO, 0.9))
	Icones.atributo(ci, "agilidade", Vector2(46, 46), 26)
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(88, 42), "ESQUIVA", 30, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 5)
	var dica := "" if _toque else "   [Shift]"
	var texto := ("Pronta!" if pronta else "Recarregando...") + dica
	Tema.texto(ci, Tema.fonte("texto"), Vector2(90, 68), texto, 17, Tema.VERDE_CLARO if pronta else Tema.TEXTO_SUAVE, 340, HORIZONTAL_ALIGNMENT_LEFT, 3)
	# Barra de recarga da esquiva.
	var total := maxf(jogador.recarga_esquiva(), 0.01)
	var fracao := 1.0 if pronta else clampf(1.0 - jogador.esquiva_recarga / total, 0.0, 1.0)
	var barra := Rect2(28, 92, ci.size.x - 56, 22)
	ci.draw_style_box(Tema.caixa(Color(0, 0, 0, 0.6), Tema.OURO, 2, 9), barra)
	ci.draw_style_box(Tema.caixa(Tema.VERDE_CLARO if pronta else Tema.AZUL_CLARO, Color(0, 0, 0, 0), 0, 7), Rect2(barra.position + Vector2(3, 3), Vector2(maxf(0.0, (barra.size.x - 6) * fracao), barra.size.y - 6)))
	# Deck e descarte.
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(28, 148), "Deck  %d" % jogador.mao.compra.size(), 22, Tema.TEXTO, 200, HORIZONTAL_ALIGNMENT_LEFT, 4)
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(ci.size.x - 228, 148), "Descarte  %d" % jogador.mao.descarte.size(), 22, Tema.TEXTO_SUAVE, 200, HORIZONTAL_ALIGNMENT_RIGHT, 4)


func _desenhar_combo(ci: Desenho) -> void:
	if _combo_t <= 0.0 or _combo_mostrado < 2:
		return
	var alfa := clampf(_combo_t / 0.4, 0.0, 1.0)
	var elogio := "Boa sequência!"
	var cor := Tema.OURO_CLARO
	if _combo_mostrado >= 6:
		elogio = "IMPARÁVEL!"
		cor = Tema.VERMELHO_CLARO
	elif _combo_mostrado >= 4:
		elogio = "Excelente!"
		cor = Tema.LARANJA
	var salto := absf(sin(_tempo * 7.0)) * 10.0
	ci.draw_set_transform(Vector2(ci.size.x - 40, 90 - salto), -0.1, Vector2(_combo_escala, _combo_escala))
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(-520, 20), "x%d COMBO!" % _combo_mostrado, 72, Color(cor, alfa), 520, HORIZONTAL_ALIGNMENT_RIGHT, 12, Color(0.3, 0.12, 0.02, alfa))
	Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(-520, 62), elogio, 30, Color(Tema.TEXTO, alfa), 520, HORIZONTAL_ALIGNMENT_RIGHT, 7, Color(0, 0, 0, alfa))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_banner(ci: Desenho) -> void:
	if _banner_t <= 0.0 or _banner_texto == "":
		return
	var alfa := clampf(_banner_t / 0.35, 0.0, 1.0)
	var w := ci.size.x
	var centro := Vector2(w / 2.0, ci.size.y / 2.0)
	var f := Tema.fonte("titulo")
	ci.draw_set_transform(centro, 0.0, Vector2(_banner_escala, _banner_escala))
	if _banner_episodio:
		# Título de episódio: faixa escura de ponta a ponta com filetes dourados.
		var linhas_sub := _banner_sub.split("\n", false) if _banner_sub != "" else PackedStringArray()
		var altura := 150.0 + linhas_sub.size() * 34.0
		var faixa := Rect2(-w / 2.0 - 10, -altura / 2.0, w + 20, altura)
		ci.draw_rect(faixa, Color(Tema.CARVAO, 0.86 * alfa))
		for y in [faixa.position.y + 6, faixa.end.y - 6]:
			ci.draw_line(Vector2(faixa.position.x, y), Vector2(faixa.end.x, y), Color(Tema.OURO, alfa), 4.0)
		for y in [faixa.position.y + 14, faixa.end.y - 14]:
			ci.draw_line(Vector2(faixa.position.x, y), Vector2(faixa.end.x, y), Color(Tema.OURO, 0.4 * alfa), 1.5)
		var y_titulo := faixa.position.y + 54
		Tema.texto(ci, f, Vector2(-w / 2.0, y_titulo), "ARENA", 20, Color(Tema.OURO, alfa), w, HORIZONTAL_ALIGNMENT_CENTER, 4)
		var tamanho := 76
		while tamanho > 40 and f.get_string_size(_banner_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > w - 80:
			tamanho -= 4
		Tema.texto(ci, f, Vector2(-w / 2.0, y_titulo + tamanho * 0.95), _banner_texto, tamanho, Color(Tema.OURO_CLARO, alfa), w, HORIZONTAL_ALIGNMENT_CENTER, 14, Color(0.15, 0.07, 0.02, alfa))
		# Losangos dourados dos lados do título.
		var meio := f.get_string_size(_banner_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x / 2.0 + 40
		for lado in [-1.0, 1.0]:
			var c := Vector2(lado * meio, y_titulo + tamanho * 0.6)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0), c + Vector2(0, 12), c + Vector2(-12, 0)]), Color(Tema.OURO, alfa))
		var y_sub := y_titulo + tamanho * 0.95 + 40
		for k in linhas_sub.size():
			var cor_sub := Tema.TEXTO if k == 0 else Tema.LARANJA
			Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(-w / 2.0, y_sub + k * 34), linhas_sub[k], 26, Color(cor_sub, alfa), w, HORIZONTAL_ALIGNMENT_CENTER, 6)
	else:
		var curto := _banner_texto.length() <= 8 and _banner_texto == _banner_texto.to_upper()
		var tamanho := 110 if curto else 64
		while tamanho > 36 and f.get_string_size(_banner_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > w - 120:
			tamanho -= 4
		var largura := f.get_string_size(_banner_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + 140
		var altura := tamanho * 1.5
		var pts := PackedVector2Array([Vector2(-largura / 2.0 + 24, -altura / 2.0), Vector2(largura / 2.0, -altura / 2.0),
			Vector2(largura / 2.0 - 24, altura / 2.0), Vector2(-largura / 2.0, altura / 2.0)])
		ci.draw_colored_polygon(pts, Color(Tema.CARVAO, 0.8 * alfa))
		ci.draw_polyline(Icones.fechar(pts), Color(Tema.OURO, alfa), 4.0, true)
		var cor := Tema.VERMELHO_CLARO if curto else Tema.OURO_CLARO
		Tema.texto(ci, f, Vector2(-largura / 2.0, tamanho * 0.36), _banner_texto, tamanho, Color(cor, alfa), largura, HORIZONTAL_ALIGNMENT_CENTER, 14, Color(0.1, 0.05, 0.02, alfa))
		if _banner_sub != "":
			Tema.texto(ci, Tema.fonte("texto_negrito"), Vector2(-w / 2.0, altura / 2.0 + 34), _banner_sub, 26, Color(Tema.TEXTO, alfa), w, HORIZONTAL_ALIGNMENT_CENTER, 6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_aviso(ci: Desenho) -> void:
	if _aviso_t <= 0.0:
		return
	var w := ci.size.x
	var decorrido := _aviso_total - _aviso_t
	var largura := minf(w - 60.0, 1100.0)
	# Entra deslizando da esquerda (com pulo), fica, e sai pela direita.
	var x := 0.0
	if decorrido < 0.4:
		x = Tween.interpolate_value(-w, w, decorrido, 0.4, Tween.TRANS_BACK, Tween.EASE_OUT)
	elif _aviso_t < 0.3:
		x = Tween.interpolate_value(0.0, w, 0.3 - _aviso_t, 0.3, Tween.TRANS_QUAD, Tween.EASE_IN)
	var faixa := Rect2((w - largura) / 2.0 + x, 2, largura, ci.size.y - 4)
	var escura := _aviso_cor.darkened(0.55)
	var pts := PackedVector2Array([faixa.position + Vector2(30, 0), Vector2(faixa.end.x, faixa.position.y),
		faixa.end - Vector2(30, 0), Vector2(faixa.position.x, faixa.end.y)])
	ci.draw_colored_polygon(pts, Color(escura, 0.94))
	ci.draw_polyline(Icones.fechar(pts), Icones.CONTORNO, 7.0, true)
	ci.draw_polyline(Icones.fechar(pts), _aviso_cor.lightened(0.2), 4.0, true)
	# Listras diagonais de "atenção" nas pontas.
	for lado in [0.0, 1.0]:
		for k in 4:
			var x0 := faixa.position.x + 44 + k * 18 if lado == 0.0 else faixa.end.x - 60 - k * 18
			ci.draw_line(Vector2(x0, faixa.position.y + 10), Vector2(x0 - 14, faixa.end.y - 10), Color(_aviso_cor, 0.35), 5.0)
	var pulso := 1.0 + 0.12 * absf(sin(_tempo * 10.0))
	ci.draw_set_transform(Vector2(faixa.position.x + 90, faixa.get_center().y), 0.0, Vector2(pulso, pulso))
	Icones.alerta(ci, Vector2(0, 2), 34, Tema.OURO_CLARO)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var f := Tema.fonte("titulo")
	var tamanho := 46
	while tamanho > 24 and f.get_string_size(_aviso_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura - 220:
		tamanho -= 2
	Tema.texto(ci, f, Vector2(faixa.position.x + 150, faixa.get_center().y + tamanho * 0.36), _aviso_titulo, tamanho, Tema.OURO_CLARO, largura - 220, HORIZONTAL_ALIGNMENT_CENTER, 10, Color(0.1, 0.04, 0.02, 1.0))


func _desenhar_dica(ci: Desenho) -> void:
	# Some enquanto um aviso de evento ocupa a mesma região da tela.
	if _dica_t <= 0.0 or _dica_texto == "" or _aviso_t > 0.0:
		return
	var alfa := clampf(_dica_t / 0.3, 0.0, 1.0)
	var f := Tema.fonte("titulo")
	var tamanho := 40
	var largura := f.get_string_size(_dica_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + 120
	var salto := absf(sin(_tempo * 6.0)) * 6.0
	ci.draw_set_transform(Vector2(ci.size.x / 2.0, ci.size.y / 2.0 - salto), 0.0, Vector2(_dica_escala, _dica_escala))
	var r := Rect2(-largura / 2.0, -34, largura, 68)
	ci.draw_style_box(Tema.caixa(Color("#1f6b38", 0.94 * alfa), Color(Tema.VERDE_CLARO, alfa), 4, 34, Color(Tema.VERDE_CLARO, 0.35 * alfa), 14), r)
	# Bolha de dica com uma "pontinha" embaixo (balão de desenho animado).
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-14, 32), Vector2(14, 32), Vector2(0, 48)]), Color("#1f6b38", 0.94 * alfa))
	Icones.estrela(ci, Vector2(-largura / 2.0 + 38, 0), 18, Color(Tema.OURO_CLARO, alfa), true, _tempo * 2.0)
	Tema.texto(ci, f, Vector2(-largura / 2.0 + 60, tamanho * 0.36), _dica_texto, tamanho, Color(Tema.TEXTO, alfa), largura - 90, HORIZONTAL_ALIGNMENT_CENTER, 8, Color(0.02, 0.15, 0.05, alfa))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_fundo_resultado(ci: Desenho) -> void:
	var w := ci.size.x
	var h := ci.size.y
	ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.62))
	if _resultado_vitoria:
		# Raios girando atrás do painel (clássico de vitória de desenho animado).
		var c := Vector2(w / 2.0, h / 2.0)
		var raio := maxf(w, h)
		for i in 16:
			var a := _tempo * 0.35 + i * TAU / 16.0
			var b := a + TAU / 32.0
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * raio, c + Vector2(cos(b), sin(b)) * raio]), Color(Tema.OURO, 0.07))
	for p in _confete:
		var pos: Vector2 = p["pos"]
		var tam: Vector2 = p["tam"]
		var escala_x := absf(cos(p["rot"] * 1.3))
		ci.draw_set_transform(pos, p["rot"], Vector2(maxf(escala_x, 0.15), 1.0))
		ci.draw_rect(Rect2(-tam / 2.0, tam), p["cor"])
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_estrelas(ci: Desenho) -> void:
	var c := Vector2(ci.size.x / 2.0, ci.size.y / 2.0)
	for i in 3:
		var pos := c + Vector2((i - 1) * 150.0, 10.0 if i != 1 else -10.0)
		var acesa := i < _estrelas_acesas
		var escala := 1.0
		if acesa and i == _estrelas_acesas - 1:
			escala = 1.0 + 0.6 * _estrela_pop
		ci.draw_set_transform(pos, 0.0, Vector2(escala, escala))
		if acesa:
			Tema.brilho_radial(ci, Vector2.ZERO, 70, Color(Tema.OURO, 0.5), 8)
		Icones.estrela(ci, Vector2.ZERO, 56, Tema.OURO_CLARO, acesa)
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
