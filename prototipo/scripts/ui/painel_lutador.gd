class_name PainelLutador
extends Control
## Barra superior de um lutador (mockup do HUD): retrato 3D grande, nome, facção,
## Energia em barra inclinada bem alta com número enorme, faixa branca de "dano recente"
## que encolhe, número "-23" saltando ao levar dano e as cargas de Cântico como notas.
## espelhado = true desenha o painel do oponente (retrato à direita).

const TAMANHO := Vector2(860, 190)

var lutador: Lutador
var espelhado := false

var _retrato: RetratoMonstro
var _energia_rastro := 1.0
## Segundos em que a faixa branca fica parada antes de encolher.
var _rastro_espera := 0.0
var _energia_anterior := -1.0
## Último dano recebido (número que salta ao lado da barra) e seu tempo restante.
var _dano_recente := 0.0
var _dano_t := 0.0
var _cura_recente := 0.0
var _cura_t := 0.0
var _tremor_t := 0.0
var _tempo := 0.0
var _cargas_anteriores := -1
var _carga_pulso_t := 0.0


func configurar(l: Lutador, lado_direito: bool) -> void:
	lutador = l
	espelhado = lado_direito
	size = TAMANHO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato = RetratoMonstro.new()
	_retrato.enquadramento = "rosto"
	_retrato.size = Vector2i(256, 256)
	add_child(_retrato)
	_retrato.definir(l.id_monstro)


func _process(delta: float) -> void:
	if lutador == null:
		return
	_tempo += delta
	var fracao := lutador.energia / lutador.energia_max
	if _energia_anterior < 0.0:
		_energia_anterior = lutador.energia
		_energia_rastro = fracao
	if lutador.energia < _energia_anterior - 0.05:
		var dano := _energia_anterior - lutador.energia
		# Vários ticks pequenos (lava) se somam no mesmo número.
		_dano_recente = dano if _dano_t <= 0.0 else _dano_recente + dano
		_dano_t = 0.9
		_rastro_espera = 0.45
		_tremor_t = minf(0.35, 0.12 + dano / 60.0)
	elif lutador.energia > _energia_anterior + 0.05:
		var cura := lutador.energia - _energia_anterior
		_cura_recente = cura if _cura_t <= 0.0 else _cura_recente + cura
		_cura_t = 0.9
	_energia_anterior = lutador.energia
	if lutador.cargas_cantico != _cargas_anteriores:
		if _cargas_anteriores >= 0:
			_carga_pulso_t = 0.5
		_cargas_anteriores = lutador.cargas_cantico
	# A faixa branca espera um instante e depois desce rápido até a Energia real.
	if _rastro_espera > 0.0:
		_rastro_espera -= delta
	else:
		_energia_rastro = move_toward(_energia_rastro, fracao, delta * 0.9)
	_energia_rastro = maxf(fracao, _energia_rastro)
	_dano_t = maxf(0.0, _dano_t - delta)
	_cura_t = maxf(0.0, _cura_t - delta)
	_tremor_t = maxf(0.0, _tremor_t - delta)
	_carga_pulso_t = maxf(0.0, _carga_pulso_t - delta)
	queue_redraw()


func _x(x: float) -> float:
	return TAMANHO.x - x if espelhado else x


func _draw() -> void:
	if lutador == null:
		return
	var f := lutador.faccao
	var cor := Color(str(f.get("cor", "#8a97ab")))
	var escura := Color(str(f.get("cor_escura", "#1e2936")))
	var clara := Color(str(f.get("cor_clara", "#dfe6f0")))
	var alinhamento := HORIZONTAL_ALIGNMENT_RIGHT if espelhado else HORIZONTAL_ALIGNMENT_LEFT
	var fracao := lutador.energia / lutador.energia_max
	var baixa := fracao < 0.3 and lutador.energia > 0.0

	# Tremor do painel inteiro ao levar dano.
	if _tremor_t > 0.0:
		var amp := _tremor_t * 18.0
		draw_set_transform(Vector2(sin(_tempo * 70.0) * amp, cos(_tempo * 53.0) * amp * 0.5), 0.0, Vector2.ONE)

	# Faixa de fundo inclinada.
	var fundo := PackedVector2Array([Vector2(_x(0), 8), Vector2(_x(810), 8), Vector2(_x(766), 172), Vector2(_x(0), 172)])
	draw_colored_polygon(fundo, Color(Tema.CARVAO, 0.84))
	var cor_borda := cor if not baixa else Color(cor).lerp(Tema.VERMELHO_CLARO, 0.5 + 0.5 * sin(_tempo * 8.0))
	draw_polyline(Icones.fechar(fundo), Color(cor_borda, 0.95), 3.0, true)
	draw_line(Vector2(_x(165), 14), Vector2(_x(800), 14), Color(Tema.OURO, 0.55), 1.5)

	# Retrato grande com moldura dourada.
	var moldura := Rect2(TAMANHO.x - 156.0 if espelhado else 0.0, 0, 156, 156)
	draw_style_box(Tema.caixa(escura, Tema.OURO, 4, 12), moldura)
	Tema.gradiente(self, moldura.grow(-4), clara, cor.darkened(0.4))
	if _retrato:
		draw_texture_rect(_retrato.get_texture(), moldura.grow(-5), false)
	if lutador.energia <= 0.0:
		draw_style_box(Tema.caixa(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 12), moldura.grow(-4))
	var emblema_pos := Vector2(moldura.end.x - 16, moldura.end.y - 16) if not espelhado else Vector2(moldura.position.x + 16, moldura.end.y - 16)
	Icones.emblema(self, f, emblema_pos, 19)

	# Nome e facção.
	var x_texto := 172.0
	var largura := 470.0
	var pos_nome := Vector2(_x(x_texto + largura) if espelhado else _x(x_texto), 54)
	Tema.texto(self, Tema.fonte("titulo"), pos_nome, lutador.nome.to_upper(), 40, Tema.TEXTO, largura, alinhamento, 6)
	Tema.texto(self, Tema.fonte("titulo"), pos_nome + Vector2(0, 30), str(f.get("nome", "")), 18, cor.lightened(0.3), largura, alinhamento, 4)

	# Número grande da Energia: coração + valor atual + "/máximo", encostado na ponta da barra.
	var numero := "%d" % ceili(lutador.energia)
	var escala_num := 1.0 + (0.25 * _dano_t if _dano_t > 0.6 else 0.0)
	var cor_num := Tema.TEXTO if not baixa else Tema.VERMELHO_CLARO.lerp(Tema.TEXTO, 0.5 + 0.5 * sin(_tempo * 8.0))
	var f_num := Tema.fonte("numero")
	var tam_num := int(52 * escala_num)
	var texto_max := "/%d" % int(lutador.energia_max)
	var w_num := f_num.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_num).x
	var w_max := f_num.get_string_size(texto_max, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var total := 34.0 + w_num + 4.0 + w_max
	var x_ini := 60.0 if espelhado else 800.0 - total
	var y_num := 86.0
	Icones.coracao(self, Vector2(x_ini + 14, y_num - 16), 13, Tema.VERMELHO_CLARO)
	Tema.texto(self, f_num, Vector2(x_ini + 34, y_num), numero, tam_num, cor_num, -1, HORIZONTAL_ALIGNMENT_LEFT, 6)
	Tema.texto(self, f_num, Vector2(x_ini + 38 + w_num, y_num - 2), texto_max, 24, Tema.TEXTO_SUAVE, -1, HORIZONTAL_ALIGNMENT_LEFT, 4)

	# Barra de Energia inclinada, alta, com marcas a cada 25%.
	var y0 := 98.0
	var y1 := 142.0
	var inicio := 166.0
	var fim := 800.0
	_barra(inicio, fim, y0, y1, 1.0, Color(0, 0, 0, 0.72))
	_barra(inicio, fim, y0, y1, _energia_rastro, Color(1, 1, 1, 0.95))
	var cor_barra := cor.lightened(0.15)
	if baixa:
		cor_barra = cor_barra.lerp(Color("#ff3b3b"), 0.5 + 0.5 * sin(_tempo * 8.0))
	_barra(inicio, fim, y0, y1, fracao, cor_barra)
	_barra(inicio, fim, y0, y0 + 12, fracao, Color(1, 1, 1, 0.32))
	for i in [0.25, 0.5, 0.75]:
		var x_topo := inicio + 14.0 + (fim - inicio - 14.0) * float(i)
		draw_line(Vector2(_x(x_topo), y0), Vector2(_x(x_topo - 14.0), y1), Color(0, 0, 0, 0.35), 2.0)
	if lutador.escudo > 0.0:
		var fracao_escudo := clampf(lutador.escudo / lutador.energia_max, 0.0, 1.0)
		_barra(inicio, fim, y1 - 9, y1, fracao_escudo, Tema.AZUL_CLARO)
	var contorno := PackedVector2Array([Vector2(_x(inicio + 14), y0), Vector2(_x(fim), y0), Vector2(_x(fim - 14), y1), Vector2(_x(inicio), y1)])
	draw_polyline(Icones.fechar(contorno), Icones.CONTORNO, 5.0, true)
	draw_polyline(Icones.fechar(contorno), Tema.OURO, 2.5, true)

	# "-23" saltando em cima da barra, bem onde a faixa branca encolhe (ou "+15" verde ao curar).
	var x_fim := inicio + (fim - inicio) * clampf(fracao, 0.12, 0.88)
	if _dano_t > 0.0:
		var k := 1.0 - _dano_t / 0.9
		var salto := absf(sin(k * PI * 1.5)) * 16.0 * (1.0 - k)
		var pos := Vector2(_x(x_fim), y1 - 6 - salto)
		var alfa := clampf(_dano_t / 0.3, 0.0, 1.0)
		Tema.texto(self, f_num, pos + Vector2(-80, 0), "-%d" % roundi(_dano_recente), 46, Color(Tema.VERMELHO_CLARO, alfa), 160, HORIZONTAL_ALIGNMENT_CENTER, 8, Color(0.2, 0.02, 0.02, alfa))
	if _cura_t > 0.0:
		var k := 1.0 - _cura_t / 0.9
		var pos := Vector2(_x(x_fim), y1 - 6 - k * 20.0)
		var alfa := clampf(_cura_t / 0.3, 0.0, 1.0)
		Tema.texto(self, f_num, pos + Vector2(-80, 0), "+%d" % roundi(_cura_recente), 42, Color(Tema.VERDE_CLARO, alfa), 160, HORIZONTAL_ALIGNMENT_CENTER, 8, Color(0.02, 0.15, 0.05, alfa))

	# Cargas de Cântico como notas musicais dentro do símbolo octogonal.
	var cor_cantico := Color(str(Dados.faccao(str(lutador.cantico.get("faccao", ""))).get("cor", "#b07cff")))
	for i in maxi(lutador.cargas_max, 1):
		var c := Vector2(_x(fim - 22 - i * 44), 164)
		var cheia := i < lutador.cargas_cantico
		var r := 18.0
		if cheia and _carga_pulso_t > 0.0:
			r += 6.0 * sin(_carga_pulso_t / 0.5 * PI)
		Icones.simbolo_cantico(self, c, r, cor_cantico, "nota" if cheia else "", 0.3 if cheia else 0.0, cheia)

	# Linha de estado (equipamento + situação).
	var estados := PackedStringArray()
	if lutador.energia <= 0.0:
		estados.append("DERROTADO")
	elif lutador.atordoado_t > 0.0:
		estados.append("ATORDOADO")
	elif lutador.cantando:
		estados.append("CANTANDO")
	if lutador.escudo > 0.0:
		estados.append("ESCUDO %d" % roundi(lutador.escudo))
	if lutador.no_alto():
		estados.append("NO ALTO")
	if lutador.escondido:
		estados.append("ESCONDIDO")
	var equip := str(lutador.equipamento.get("nome", "—")) if lutador.equipamento_revelado else "???"
	var linha := equip
	if not estados.is_empty():
		linha = "  ".join(estados) + "   •   " + equip
	var pos_linha := Vector2(_x(inicio + 400) if espelhado else _x(inicio + 4), 170)
	Tema.texto(self, Tema.fonte("texto_negrito"), pos_linha, linha, 17, Tema.TEXTO_SUAVE if estados.is_empty() else Color("#ffd166"), 400, alinhamento, 4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _barra(inicio: float, fim: float, y0: float, y1: float, fracao: float, cor: Color) -> void:
	if fracao <= 0.0:
		return
	var inclinacao := 14.0
	var comprimento := (fim - inicio) * clampf(fracao, 0.0, 1.0)
	var a := inicio
	var b := inicio + comprimento
	var pts := PackedVector2Array([Vector2(_x(a + inclinacao), y0), Vector2(_x(b), y0), Vector2(_x(b - inclinacao), y1), Vector2(_x(a), y1)])
	if b - a < inclinacao:
		pts = PackedVector2Array([Vector2(_x(a), y0), Vector2(_x(b), y0), Vector2(_x(b), y1), Vector2(_x(a), y1)])
	draw_colored_polygon(pts, cor)
