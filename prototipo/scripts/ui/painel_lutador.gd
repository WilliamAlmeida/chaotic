class_name PainelLutador
extends Control
## Barra superior de um lutador (mockup do HUD): retrato 3D, nome, facção,
## Energia em barra inclinada com "rastro" de dano e as cargas de Cântico.
## espelhado = true desenha o painel do oponente (retrato à direita).

const TAMANHO := Vector2(860, 170)

var lutador: Lutador
var espelhado := false

var _retrato: RetratoMonstro
var _energia_rastro := 1.0


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
	var fracao := lutador.energia / lutador.energia_max
	# O rastro claro desce devagar até a Energia real (efeito clássico de jogo de luta).
	_energia_rastro = maxf(fracao, move_toward(_energia_rastro, fracao, delta * 0.35))
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

	# Faixa de fundo inclinada.
	var fundo := PackedVector2Array([Vector2(_x(0), 8), Vector2(_x(800), 8), Vector2(_x(760), 150), Vector2(_x(0), 150)])
	draw_colored_polygon(fundo, Color(Tema.CARVAO, 0.82))
	draw_polyline(Icones.fechar(fundo), Color(cor, 0.85), 2.0, true)
	draw_line(Vector2(_x(150), 14), Vector2(_x(790), 14), Color(Tema.OURO, 0.5), 1.0)

	# Retrato.
	var moldura := Rect2(TAMANHO.x - 140.0 if espelhado else 0.0, 0, 140, 140)
	draw_style_box(Tema.caixa(escura, Tema.OURO, 3, 10), moldura)
	Tema.gradiente(self, moldura.grow(-3), clara, cor.darkened(0.4))
	if _retrato:
		draw_texture_rect(_retrato.get_texture(), moldura.grow(-4), false)
	var emblema_pos := Vector2(moldura.end.x - 14, moldura.end.y - 14) if not espelhado else Vector2(moldura.position.x + 14, moldura.end.y - 14)
	Icones.emblema(self, f, emblema_pos, 16)

	# Nome e facção.
	var x_texto := 158.0
	var largura := 600.0
	var pos_nome := Vector2(_x(x_texto + largura) if espelhado else _x(x_texto), 52)
	Tema.texto(self, Tema.fonte("titulo"), pos_nome, lutador.nome.to_upper(), 36, Tema.TEXTO, largura, alinhamento, 5)
	Tema.texto(self, Tema.fonte("titulo"), pos_nome + Vector2(0, 30), str(f.get("nome", "")), 17, cor.lightened(0.25), largura, alinhamento, 4)
	var numeros := "%d / %d" % [ceili(lutador.energia), int(lutador.energia_max)]
	var pos_num := Vector2(_x(780), 80)
	if espelhado:
		Tema.texto(self, Tema.fonte("numero"), Vector2(pos_num.x, pos_num.y), numeros, 26, Tema.TEXTO, 200, HORIZONTAL_ALIGNMENT_LEFT, 4)
	else:
		Tema.texto(self, Tema.fonte("numero"), Vector2(pos_num.x - 200, pos_num.y), numeros, 26, Tema.TEXTO, 200, HORIZONTAL_ALIGNMENT_RIGHT, 4)

	# Barra de Energia inclinada.
	var y0 := 92.0
	var y1 := 122.0
	var inicio := 150.0
	var fim := 790.0
	_barra(inicio, fim, y0, y1, 1.0, Color(0, 0, 0, 0.7))
	_barra(inicio, fim, y0, y1, _energia_rastro, Color("#fff0c0"))
	var fracao := lutador.energia / lutador.energia_max
	var cor_barra := cor.lightened(0.15)
	if fracao < 0.3:
		cor_barra = cor_barra.lerp(Color("#ff3b3b"), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0))
	_barra(inicio, fim, y0, y1, fracao, cor_barra)
	_barra(inicio, fim, y0, y0 + 9, fracao, Color(1, 1, 1, 0.3))
	if lutador.escudo > 0.0:
		var fracao_escudo := clampf(lutador.escudo / lutador.energia_max, 0.0, 1.0)
		_barra(inicio, fim, y1 - 7, y1, fracao_escudo, Color("#9fe8ff"))
	var contorno := PackedVector2Array([Vector2(_x(inicio + 14), y0), Vector2(_x(fim), y0), Vector2(_x(fim - 14), y1), Vector2(_x(inicio), y1)])
	draw_polyline(Icones.fechar(contorno), Tema.OURO, 2.0, true)

	# Cargas de Cântico (octógonos) e estado.
	var cor_cantico := Color(str(Dados.faccao(str(lutador.cantico.get("faccao", ""))).get("cor", "#b07cff")))
	for i in maxi(lutador.cargas_max, 1):
		var c := Vector2(_x(fim - 18 - i * 34), 146)
		Icones.simbolo_cantico(self, c, 14, cor_cantico, "", 0.0, i < lutador.cargas_cantico)
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
	var linha := "Equip: %s" % equip
	if not estados.is_empty():
		linha += "   " + "  ".join(estados)
	var pos_linha := Vector2(_x(inicio + 420) if espelhado else _x(inicio + 4), 146)
	Tema.texto(self, Tema.fonte("texto_negrito"), pos_linha, linha, 15, Tema.TEXTO_SUAVE if estados.is_empty() else Color("#ffd166"), 420, alinhamento, 3)


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
