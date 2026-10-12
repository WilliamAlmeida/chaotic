class_name CartaVisual
extends Control
## Carta desenhada em código conforme a "Folha de Componentes" (docs/gui-conceito.md):
## faixa de nome + selo, arte, painel de atributos, caixa de texto e rodapé.
## Estados: normal, hover, selecionada, desabilitada e recarregando.
## Se existir res://arte/cartas/<id>.png, ele substitui a arte procedural.

signal clicada(carta: CartaVisual)

const BASE_RETRATO := Vector2(280, 420)
const BASE_ATAQUE := Vector2(240, 300)
const NOMES_TIPO := {"monstro": "Monstro", "equipamento": "Equipamento", "cantico": "Cântico", "local": "Local", "ataque": "Ataque"}

## monstro | equipamento | cantico | local | ataque
var tipo := "monstro"
var id := ""
var selecionada := false
var desabilitada := false
## 0..1; abaixo de 1 mostra o estado "recarregando".
var progresso := 1.0
## Contexto da luta (acende elementos e condições): o monstro que usa a carta e o alvo.
var dono: Lutador
var alvo: Lutador
## Contexto do loadout: elementos do monstro escolhido.
var elementos_dono: Array = []
var interativa := false

var _hover := false
var _pulso := 0.0
var _retrato: RetratoMonstro
var _base := BASE_RETRATO


func definir(novo_tipo: String, novo_id: String) -> void:
	tipo = novo_tipo
	id = novo_id
	_base = BASE_ATAQUE if tipo == "ataque" else BASE_RETRATO
	if tipo == "monstro" and Dados.monstros.has(id):
		if _retrato == null:
			_retrato = RetratoMonstro.new()
			add_child(_retrato)
		_retrato.definir(id)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interativa else Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	var botao := event as InputEventMouseButton
	if interativa and botao and botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT:
		clicada.emit(self)
		accept_event()


func _process(delta: float) -> void:
	if selecionada or _retrato != null:
		_pulso += delta * 3.0
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x / _base.x, size.y / _base.y)
	if _hover and interativa and not desabilitada:
		s *= 1.03
	draw_set_transform((size - _base * s) / 2.0, 0.0, Vector2(s, s))
	match tipo:
		"monstro":
			_carta_monstro()
		"equipamento":
			_carta_equipamento()
		"cantico":
			_carta_cantico()
		"local":
			_carta_local()
		"ataque":
			_carta_ataque()
	if desabilitada:
		draw_style_box(Tema.caixa(Color(0.07, 0.09, 0.13, 0.62), Color(0, 0, 0, 0), 0, 16), Rect2(Vector2.ZERO, _base))
	if progresso < 1.0:
		_sobreposicao_recarga()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =====================================================================
# Tipos de carta
# =====================================================================

func _carta_monstro() -> void:
	var m: Dictionary = Dados.monstros.get(id, {})
	if m.is_empty():
		return
	var f := Dados.faccao(str(m.get("faccao", "")))
	var cor := Color(str(f["cor"]))
	var escura := Color(str(f["cor_escura"]))
	var clara := Color(str(f["cor_clara"]))
	_moldura(escura, cor, clara)
	_faixa_nome(str(m["nome"]), cor, 196)
	_selo(str(int(m.get("cargas_cantico", 0))), escura)

	var arte := Rect2(14, 62, 252, 192)
	_fundo_arte(arte, clara, cor.darkened(0.35), escura)
	if not _desenhar_arte_arquivo(arte):
		if _retrato:
			var lado := arte.size.y
			draw_texture_rect(_retrato.get_texture(), Rect2(arte.get_center() - Vector2(lado, lado) / 2.0, Vector2(lado, lado)), false)
	if bool(m.get("voa", false)):
		_chip_texto(Vector2(arte.position.x + 6, arte.position.y + 6), "VOA", clara)
	# Chips sobre a arte: Energia (esquerda) e elementos (direita).
	_chip_valor(Vector2(arte.position.x + 6, arte.end.y - 36), "coracao", str(int(m["energia"])), Color("#ff6b6b"))
	var els: Array = m["elementos"]
	for i in els.size():
		Icones.elemento(self, str(els[i]), Vector2(arte.end.x - 20 - i * 34, arte.end.y - 20), 15, true)

	var faixa := Rect2(14, 258, 252, 50)
	draw_style_box(Tema.caixa(escura.darkened(0.25), cor.darkened(0.1), 2, 6), faixa)
	var a: Dictionary = m["atributos"]
	var coluna := 0
	for chave in ["agilidade", "forca", "mente", "animo"]:
		var x := faixa.position.x + 6 + coluna * 62
		Icones.atributo(self, chave, Vector2(x + 15, faixa.get_center().y), 14)
		Tema.texto(self, Tema.fonte("numero"), Vector2(x + 31, faixa.get_center().y + 9), str(int(a[chave])), 24, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
		coluna += 1

	var p: Dictionary = m.get("passiva", {})
	_caixa_texto(Rect2(14, 312, 252, 80), str(p.get("nome", _titulo(str(p.get("tipo", ""))))), str(p.get("descricao", "")))
	_rodape("Monstro", str(f.get("marca", "")), cor, escura)
	if selecionada:
		_fita(Rect2(), "Selecionada", cor)


func _carta_equipamento() -> void:
	var e: Dictionary = Dados.equipamentos.get(id, {})
	if e.is_empty():
		return
	var escura: Color = Tema.MOLDURA_EQUIPAMENTO[0]
	var cor: Color = Tema.MOLDURA_EQUIPAMENTO[1]
	var clara: Color = Tema.MOLDURA_EQUIPAMENTO[2]
	var cor_item := Color(str(e.get("cor", "#cccccc")))
	_moldura(escura, cor, clara)
	_faixa_nome(str(e["nome"]), cor, 196)
	var el := str(e.get("elemento", ""))
	_selo("", escura)
	if el != "":
		Icones.elemento(self, el, Vector2(246, 34), 17, true, false)

	var arte := Rect2(14, 62, 252, 192)
	_fundo_arte(arte, cor_item.lightened(0.45), cor_item.darkened(0.55), escura)
	if not _desenhar_arte_arquivo(arte):
		var c := arte.get_center() + Vector2(0, 4)
		Tema.brilho_radial(self, c, 95, Color(cor_item.lightened(0.6), 0.9))
		Icones.marca(self, str(e.get("modelo", "espada")), c, 72, cor_item.lightened(0.25))
		for p in [Vector2(-80, -55), Vector2(85, -40), Vector2(70, 60), Vector2(-90, 50)]:
			_estrela(c + p, 7, Color(1, 1, 1, 0.85))

	var faixa := Rect2(14, 258, 252, 50)
	draw_style_box(Tema.caixa(escura.darkened(0.2), cor.darkened(0.2), 2, 6), faixa)
	var x := faixa.position.x + 10
	var passivo: Dictionary = e.get("passivo", {})
	for chave in passivo:
		if Dados.ATRIBUTOS.has(chave):
			Icones.atributo(self, str(chave), Vector2(x + 15, faixa.get_center().y), 14)
			Tema.texto(self, Tema.fonte("numero"), Vector2(x + 32, faixa.get_center().y + 9), "+%d" % int(passivo[chave]), 24, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
			x += 84
	if el != "":
		Icones.elemento(self, el, Vector2(x + 15, faixa.get_center().y), 14, true)
		Tema.texto(self, Tema.fonte("texto_negrito"), Vector2(x + 34, faixa.get_center().y + 6), str(Dados.ELEMENTOS[el]["nome"]), 16, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)

	_caixa_texto(Rect2(14, 312, 252, 80), "", str(e.get("descricao", "")) + " Fica oculto até o início da luta.")
	_rodape("Equipamento", "espada", cor, escura)
	if selecionada:
		_fita(Rect2(), "Selecionada", cor)


func _carta_cantico() -> void:
	var c: Dictionary = Dados.canticos.get(id, {})
	if c.is_empty():
		return
	var f := Dados.faccao(str(c.get("faccao", "")))
	var cor := Color(str(f["cor"]))
	var escura := Color(str(f["cor_escura"]))
	var clara := Color(str(f["cor_clara"]))
	_moldura(escura, cor, clara)
	_faixa_nome(str(c["nome"]), cor, 196)
	_selo("1", escura)

	var arte := Rect2(14, 62, 252, 192)
	_fundo_arte(arte, escura.lightened(0.15), Color("#07070f"), escura)
	if not _desenhar_arte_arquivo(arte):
		var centro := arte.get_center()
		Tema.brilho_radial(self, centro, 110, Color(cor, 0.9))
		# Pauta musical ondulando atrás do símbolo.
		for linha in 5:
			var pts := PackedVector2Array()
			for k in 26:
				var x := arte.position.x + 4 + (arte.size.x - 8) * k / 25.0
				pts.append(Vector2(x, centro.y - 30 + linha * 15 + sin(k * 0.45 + _pulso * 0.3) * 8))
			draw_polyline(pts, Color(clara, 0.35), 1.5, true)
		Icones.simbolo_cantico(self, centro, 62, cor, "nota", 0.8)

	var faixa := Rect2(14, 258, 252, 50)
	draw_style_box(Tema.caixa(escura.darkened(0.25), cor.darkened(0.1), 2, 6), faixa)
	var tipo_c := str(c.get("tipo", ""))
	var nomes := {"cura": "Cura", "dano": "Dano", "escudo": "Escudo"}
	var icone := {"cura": "animo", "dano": "forca", "escudo": "mente"}
	Icones.atributo(self, str(icone.get(tipo_c, "mente")), Vector2(faixa.position.x + 22, faixa.get_center().y), 14)
	Tema.texto(self, Tema.fonte("texto_negrito"), Vector2(faixa.position.x + 42, faixa.get_center().y + 7), str(nomes.get(tipo_c, tipo_c)), 18, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
	Tema.texto(self, Tema.fonte("numero"), Vector2(faixa.position.x + 112, faixa.get_center().y + 10), str(int(c.get("valor", 0))), 28, Tema.OURO_CLARO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
	Icones.emblema(self, f, Vector2(faixa.end.x - 22, faixa.get_center().y), 16)

	_caixa_texto(Rect2(14, 312, 252, 80), "", "%s Monstro da mesma facção: +15%%." % str(c.get("descricao", "")))
	_rodape("Cântico", "nota", cor, escura)
	if selecionada:
		_fita(Rect2(), "Selecionada", cor)


func _carta_local() -> void:
	var escura: Color = Tema.MOLDURA_LOCAL[0]
	var cor: Color = Tema.MOLDURA_LOCAL[1]
	var clara: Color = Tema.MOLDURA_LOCAL[2]
	if id == "aleatorio" or not Dados.locais.has(id):
		_verso_carta()
		return
	var loc: Dictionary = Dados.locais[id]
	_moldura(escura, cor, clara)
	_faixa_nome(str(loc["nome"]), cor, 196)
	_selo("", escura)
	var attr := str(loc.get("iniciativa", {}).get("atributo", ""))
	Icones.atributo(self, attr, Vector2(246, 34), 15, false)

	var arte := Rect2(14, 62, 252, 192)
	draw_style_box(Tema.caixa(escura, Color(0, 0, 0, 0.9), 2, 6), arte)
	if not _desenhar_arte_arquivo(arte):
		_paisagem(arte.grow(-2), loc)

	var faixa := Rect2(14, 258, 252, 50)
	draw_style_box(Tema.caixa(escura.darkened(0.2), cor.darkened(0.25), 2, 6), faixa)
	Icones.atributo(self, attr, Vector2(faixa.position.x + 20, faixa.get_center().y), 14)
	Tema.texto(self, Tema.fonte("texto_negrito"), Vector2(faixa.position.x + 38, faixa.get_center().y + 6), "Iniciativa", 15, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var x := faixa.position.x + 128
	for mod in loc.get("modificadores", []):
		Icones.elemento(self, str(mod["elemento"]), Vector2(x, faixa.get_center().y), 13, true)
		Tema.texto(self, Tema.fonte("numero"), Vector2(x + 15, faixa.get_center().y + 8), "+%d" % int(mod["dano_bonus"]), 20, Tema.TEXTO, -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
		x += 52
	var perigos := PackedStringArray()
	for p in loc.get("perigos", []):
		var nome_p: String = {"lava": "lava", "agua": "água", "mato": "capim alto (esconde)", "nevoa": "névoa (esconde)"}.get(str(p["tipo"]), str(p["tipo"]))
		if not perigos.has(nome_p):
			perigos.append(nome_p)
	if bool(loc.get("vento", false)):
		perigos.append("vento")
	var extra := "" if perigos.is_empty() else " Perigos: %s." % ", ".join(perigos)
	_caixa_texto(Rect2(14, 312, 252, 80), "", str(loc.get("descricao", "")) + extra)
	_rodape("Local", "castelo", cor, escura)
	if selecionada:
		_fita(Rect2(), "Selecionada", cor)


func _verso_carta() -> void:
	var escura := Color("#101826")
	var cor := Tema.OURO
	_moldura(escura, cor, Tema.OURO_CLARO)
	var r := Rect2(Vector2.ZERO, _base).grow(-14)
	Tema.gradiente(self, r, Color("#1c2a44"), Color("#0b111c"))
	for i in 4:
		draw_polyline(Icones.fechar(Icones.octogono(r.get_center(), 40.0 + i * 28.0)), Color(cor, 0.18 - i * 0.03), 2.0, true)
	Icones.simbolo_cantico(self, r.get_center() + Vector2(0, -20), 70, cor, "interrogacao", 0.7)
	Tema.texto(self, Tema.fonte("titulo"), Vector2(14, 330), "Local Sorteado", 22, Tema.OURO_CLARO, 252, HORIZONTAL_ALIGNMENT_CENTER, 4)
	draw_multiline_string(Tema.fonte("texto"), Vector2(30, 360), "O cenário é sorteado entre as cartas de Local no início da luta.", HORIZONTAL_ALIGNMENT_CENTER, 220, 14, 3, Tema.TEXTO_SUAVE)


func _carta_ataque() -> void:
	var atk: Dictionary = Dados.ataques.get(id, {})
	if atk.is_empty():
		_carta_vazia()
		return
	var el := Dados.elemento_principal(atk)
	var escura: Color = Dados.ELEMENTOS[el]["escura"] if el != "" else Tema.MOLDURA_NEUTRA[0]
	var cor: Color = Dados.ELEMENTOS[el]["cor"] if el != "" else Tema.MOLDURA_NEUTRA[1]
	var clara: Color = Dados.ELEMENTOS[el]["clara"] if el != "" else Tema.MOLDURA_NEUTRA[2]
	_moldura(escura, cor, clara)
	_faixa_nome(str(atk["nome"]), cor, 166, Rect2(10, 10, 220, 38))
	_selo(str(int(atk["custo"])), escura, Vector2(210, 30), 21)

	var arte := Rect2(12, 52, 216, 118)
	_fundo_arte(arte, clara, cor.darkened(0.45), escura)
	if not _desenhar_arte_arquivo(arte):
		var c := arte.get_center() + Vector2(0, -6)
		Tema.brilho_radial(self, c, 70, Color(1, 1, 1, 0.7))
		_glifo_arquetipo(str(atk["arquetipo"]), c, 36, Color(1, 1, 1, 0.95))
	_chip_valor(Vector2(arte.position.x + 5, arte.end.y - 34), "espada", str(int(atk["dano_base"])), Color("#e6e6e6"))
	var bonus: Dictionary = atk.get("bonus_elemento", {})
	var bx := arte.end.x - 18
	for b in bonus:
		var aceso := _tem_elemento(str(b))
		Tema.texto(self, Tema.fonte("numero"), Vector2(bx - 44, arte.end.y - 9), "+%d" % int(bonus[b]), 20, Tema.TEXTO if aceso else Tema.TEXTO_SUAVE, 28, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		Icones.elemento(self, str(b), Vector2(bx, arte.end.y - 16), 13, aceso)
		bx -= 66

	var caixa := Rect2(12, 174, 216, 90)
	draw_style_box(Tema.caixa(Tema.PERGAMINHO, escura.lightened(0.1), 2, 6), caixa)
	var linha := "%s  ·  Dano %d" % [Dados.ARQUETIPOS.get(str(atk["arquetipo"]), ""), int(atk["dano_base"])]
	Tema.texto(self, Tema.fonte("texto_negrito"), caixa.position + Vector2(8, 19), linha, 13, Tema.TEXTO_ESCURO, caixa.size.x - 16)
	var cond: Dictionary = atk.get("condicao", {})
	var texto_cond := "Sem condição." if cond.is_empty() else Combate.descrever_condicao(cond)
	var cor_cond := Tema.TEXTO_ESCURO
	if not cond.is_empty() and dono != null and alvo != null:
		var ativa := Combate.avaliar_condicao(cond, dono, alvo)
		texto_cond = ("ATIVA: " if ativa else "inativa: ") + texto_cond
		cor_cond = Tema.VERDE_ATIVO if ativa else Color("#8a8070")
	draw_multiline_string(Tema.fonte("texto"), caixa.position + Vector2(8, 38), texto_cond, HORIZONTAL_ALIGNMENT_LEFT, caixa.size.x - 16, 12, 4, cor_cond)
	_rodape("Ataque", "", cor, escura, 300.0)
	if selecionada:
		_fita(Rect2(), "Selecionada", cor)


func _carta_vazia() -> void:
	draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.6), Color(Tema.MEDIO, 0.7), 3, 16), Rect2(Vector2.ZERO, _base))
	if progresso >= 1.0:
		Tema.texto(self, Tema.fonte("titulo"), Vector2(0, _base.y / 2.0), "—", 30, Tema.TEXTO_SUAVE, _base.x, HORIZONTAL_ALIGNMENT_CENTER)


# =====================================================================
# Partes da carta
# =====================================================================

func _moldura(escura: Color, cor: Color, clara: Color) -> void:
	var r := Rect2(Vector2.ZERO, _base)
	var brilho := Color(0, 0, 0, 0)
	var tamanho_brilho := 0
	if selecionada:
		brilho = Color(clara.lerp(cor, 0.3), 0.55 + 0.3 * sin(_pulso))
		tamanho_brilho = 20
	elif _hover and interativa and not desabilitada:
		brilho = Color(clara, 0.35)
		tamanho_brilho = 10
	draw_style_box(Tema.caixa(escura, cor, 5, 16, brilho, tamanho_brilho), r)
	Tema.gradiente(self, r.grow(-9), Color(cor, 0.22), Color(0, 0, 0, 0.3))
	var linha := Tema.caixa(Color(0, 0, 0, 0), Color(Tema.OURO, 0.7), 1, 12)
	linha.draw_center = false
	draw_style_box(linha, r.grow(-7))


func _faixa_nome(nome: String, cor: Color, largura_texto: float, r := Rect2(12, 12, 256, 44)) -> void:
	draw_style_box(Tema.caixa(Tema.PERGAMINHO, cor.darkened(0.25), 2, 6), r)
	Tema.gradiente(self, Rect2(r.position + Vector2(2, r.size.y * 0.55), Vector2(r.size.x - 4, r.size.y * 0.45 - 2)),
		Color(Tema.PERGAMINHO_ESCURO, 0.0), Color(Tema.PERGAMINHO_ESCURO, 0.9))
	var f := Tema.fonte("titulo")
	var tamanho := _ajustar_fonte(nome, f, largura_texto, int(r.size.y * 0.45), 11)
	Tema.texto(self, f, Vector2(r.position.x + 10, r.position.y + r.size.y * 0.5 + tamanho * 0.36), nome, tamanho, Tema.TEXTO_ESCURO, largura_texto)


func _selo(texto: String, fundo: Color, c := Vector2(246, 34), r := 24.0) -> void:
	draw_circle(c, r + 3, Icones.CONTORNO)
	draw_circle(c, r, Tema.OURO)
	draw_circle(c, r - 4, fundo)
	draw_arc(c, r - 6, PI * 1.1, PI * 1.9, 12, Color(1, 1, 1, 0.25), 2.0, true)
	if texto != "":
		Tema.texto(self, Tema.fonte("numero"), c + Vector2(-r, r * 0.42), texto, int(r * 1.25), Tema.TEXTO, r * 2, HORIZONTAL_ALIGNMENT_CENTER, 3)


func _fundo_arte(r: Rect2, topo: Color, base: Color, borda: Color) -> void:
	draw_style_box(Tema.caixa(borda, Color(0, 0, 0, 0.9), 2, 6), r)
	var interno := r.grow(-2)
	Tema.gradiente(self, interno, topo, base)
	# Linhas de velocidade estilo mangá saindo do centro.
	var c := interno.get_center()
	var alcance := minf(interno.size.x, interno.size.y) * 0.5
	for i in 24:
		var a := i * TAU / 24.0 + 0.1
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * alcance * 0.35, c + d * alcance * 0.98, Color(1, 1, 1, 0.12), 2.0, true)


func _desenhar_arte_arquivo(r: Rect2) -> bool:
	var caminho := "res://arte/cartas/%s.png" % id
	if not ResourceLoader.exists(caminho):
		return false
	draw_texture_rect(load(caminho), r.grow(-2), false)
	return true


func _caixa_texto(r: Rect2, titulo: String, corpo: String) -> void:
	draw_style_box(Tema.caixa(Tema.PERGAMINHO, Tema.PERGAMINHO_ESCURO.darkened(0.3), 2, 6), r)
	var y := r.position.y + 18
	if titulo != "":
		Tema.texto(self, Tema.fonte("texto_negrito"), Vector2(r.position.x + 9, y), titulo, 14, Tema.TEXTO_ESCURO, r.size.x - 18)
		y += 16
	var linhas := 4 if titulo == "" else 3
	draw_multiline_string(Tema.fonte("texto"), Vector2(r.position.x + 9, y), corpo, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18, 13, linhas, Tema.TEXTO_ESCURO)


func _rodape(nome_tipo: String, marca: String, cor: Color, escura: Color, altura_carta := 420.0) -> void:
	var y := altura_carta - 30.0
	var r := Rect2(14, y, _base.x - 28, 20)
	draw_style_box(Tema.caixa(Color(escura.darkened(0.4), 0.9), Color(cor, 0.6), 1, 4), r)
	Tema.texto(self, Tema.fonte("titulo"), Vector2(r.position.x, r.position.y + 15), nome_tipo, 13, Tema.OURO_CLARO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, 2)
	if marca != "":
		Icones.marca(self, marca, Vector2(r.position.x + 13, r.get_center().y), 8, cor.lightened(0.3))
		Icones.marca(self, marca, Vector2(r.end.x - 13, r.get_center().y), 8, cor.lightened(0.3))


func _fita(_arte: Rect2, texto: String, cor: Color) -> void:
	var r := Rect2(10, _base.y - 34, _base.x - 20, 26)
	draw_rect(r, Color(cor.darkened(0.55), 0.92))
	draw_line(r.position, Vector2(r.end.x, r.position.y), Tema.OURO, 1.5)
	Tema.texto(self, Tema.fonte("titulo"), Vector2(r.position.x, r.position.y + 16), texto, 14, Tema.OURO_CLARO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, 2)


func _chip_valor(pos: Vector2, icone: String, valor: String, cor_icone: Color) -> void:
	var r := Rect2(pos, Vector2(70, 30))
	draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.88), Tema.OURO, 2, 6), r)
	var c := Vector2(r.position.x + 15, r.get_center().y)
	if icone == "coracao":
		draw_circle(c + Vector2(-4, -3), 5.5, cor_icone)
		draw_circle(c + Vector2(4, -3), 5.5, cor_icone)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-9.5, -1), c + Vector2(9.5, -1), c + Vector2(0, 9)]), cor_icone)
	else:
		Icones.marca(self, icone, c, 10, cor_icone)
	Tema.texto(self, Tema.fonte("numero"), Vector2(r.position.x + 28, r.get_center().y + 9), valor, 24, Tema.TEXTO, 40, HORIZONTAL_ALIGNMENT_LEFT, 3)


func _chip_texto(pos: Vector2, texto: String, cor: Color) -> void:
	var r := Rect2(pos, Vector2(58, 26))
	draw_style_box(Tema.caixa(Color(Tema.CARVAO, 0.88), Tema.OURO, 2, 6), r)
	Tema.texto(self, Tema.fonte("titulo"), Vector2(r.position.x, r.position.y + 19), texto, 15, cor, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, 2)


func _estrela(c: Vector2, r: float, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0),
		c + Vector2(r * 0.25, r * 0.25), c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), cor)


func _glifo_arquetipo(arquetipo: String, c: Vector2, r: float, cor: Color) -> void:
	var traco := maxf(2.0, r * 0.16)
	match arquetipo:
		"projetil":
			for i in 3:
				var y := c.y + (i - 1) * r * 0.35
				draw_line(Vector2(c.x - r * 1.2, y), Vector2(c.x - r * 0.1, y), Color(cor, 0.5 + 0.2 * i), traco * 0.6, true)
			draw_circle(c + Vector2(r * 0.35, 0), r * 0.55, Icones.CONTORNO)
			draw_circle(c + Vector2(r * 0.35, 0), r * 0.45, cor)
		"area":
			for i in 3:
				draw_arc(c, r * (0.35 + 0.33 * i), 0, TAU, 32, Color(cor, 1.0 - 0.25 * i), traco * 0.7, true)
			draw_circle(c, r * 0.15, cor)
		"investida":
			for i in 2:
				var x := c.x - r * 0.5 + i * r * 0.6
				var pts := PackedVector2Array([Vector2(x, c.y - r * 0.7), Vector2(x + r * 0.55, c.y), Vector2(x, c.y + r * 0.7)])
				draw_polyline(pts, Icones.CONTORNO, traco * 1.6, true)
				draw_polyline(pts, cor, traco, true)
		"salto":
			var arco := PackedVector2Array()
			for i in 20:
				var t := float(i) / 19.0
				arco.append(c + Vector2(-r + 2.0 * r * t, r * 0.5 - sin(t * PI) * r * 1.1))
			draw_polyline(arco, cor, traco, true)
			_estrela(c + Vector2(r, r * 0.55), r * 0.45, cor)
		"basico":
			Icones.espada(self, c, r, cor)


func _paisagem(r: Rect2, loc: Dictionary) -> void:
	var topo := Color(str(loc.get("cor_ceu_topo", "#334")))
	var horizonte := Color(str(loc.get("cor_ceu_horizonte", "#889")))
	var chao := Color(str(loc.get("cor_chao", "#443")))
	var linha_horizonte := r.position.y + r.size.y * 0.52
	Tema.gradiente(self, Rect2(r.position, Vector2(r.size.x, linha_horizonte - r.position.y)), topo, horizonte)
	Tema.brilho_radial(self, Vector2(r.position.x + r.size.x * 0.72, linha_horizonte - 22), 46, Color(horizonte.lightened(0.6), 0.9))
	# Montanhas ao fundo.
	var montanhas := PackedVector2Array([Vector2(r.position.x, linha_horizonte)])
	for i in 9:
		var x := r.position.x + r.size.x * i / 8.0
		montanhas.append(Vector2(x, linha_horizonte - 12 - 22 * absf(sin(i * 1.9 + 0.5))))
	montanhas.append(Vector2(r.end.x, linha_horizonte))
	draw_colored_polygon(montanhas, horizonte.darkened(0.4))
	Tema.gradiente(self, Rect2(r.position.x, linha_horizonte, r.size.x, r.end.y - linha_horizonte), chao.lightened(0.2), chao.darkened(0.35))
	# A arena vista de cima, achatada em perspectiva.
	var centro := Vector2(r.get_center().x, linha_horizonte + (r.end.y - linha_horizonte) * 0.5)
	var rx := r.size.x * 0.44
	var ry := (r.end.y - linha_horizonte) * 0.42
	_elipse(centro, rx, ry, chao.lightened(0.3))
	_elipse_contorno(centro, rx, ry, Color(Tema.OURO, 0.6))
	for p in loc.get("perigos", []):
		var pos := centro + Vector2(float(p["x"]) / 20.0 * rx, float(p["z"]) / 20.0 * ry)
		var cor_p: Color = {"lava": Color("#ff6a1f"), "agua": Color("#3f9bff"), "mato": Color("#4f9a3a"), "nevoa": Color(1, 1, 1, 0.55)}.get(str(p["tipo"]), Color("#3f9bff"))
		_elipse(pos, float(p["raio"]) / 20.0 * rx, float(p["raio"]) / 20.0 * ry, cor_p)
	var estilo := str(loc.get("estilo_obstaculo", "rocha"))
	for o in loc.get("obstaculos", []):
		var base := centro + Vector2(float(o[0]) / 20.0 * rx, float(o[1]) / 20.0 * ry)
		var largura := float(o[2]) / 20.0 * rx * 1.6
		var altura := float(o[3]) * 5.0
		match estilo:
			"arvore":
				draw_rect(Rect2(base - Vector2(largura * 0.2, altura * 0.6), Vector2(largura * 0.4, altura * 0.6)), Color("#5a3a20"))
				draw_circle(base - Vector2(0, altura * 0.75), largura * 1.2, Color("#2f7a3a"))
			"pilar":
				draw_rect(Rect2(base - Vector2(largura * 0.5, altura), Vector2(largura, altura)), Color("#e6e2d6"))
				draw_rect(Rect2(base - Vector2(largura * 0.75, altura + 3), Vector2(largura * 1.5, 4)), Color("#f4f0e6"))
			_:
				draw_colored_polygon(PackedVector2Array([base + Vector2(-largura, 0), base + Vector2(-largura * 0.35, -altura),
					base + Vector2(largura * 0.4, -altura * 0.8), base + Vector2(largura, 0)]), chao.lightened(0.4))
	if bool(loc.get("vento", false)):
		for i in 3:
			var pts := PackedVector2Array()
			for k in 16:
				var x := r.position.x + 20 + k * 12
				pts.append(Vector2(x, r.position.y + 28 + i * 18 + sin(k * 0.8 + i) * 4))
			draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0, true)


func _elipse(c: Vector2, rx: float, ry: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, cor)


func _elipse_contorno(c: Vector2, rx: float, ry: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := i * TAU / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, cor, 2.0, true)


func _sobreposicao_recarga() -> void:
	draw_style_box(Tema.caixa(Color(0.03, 0.04, 0.07, 0.68), Color(0, 0, 0, 0), 0, 16), Rect2(Vector2.ZERO, _base))
	var c := Vector2(_base.x / 2.0, _base.y * 0.38)
	var r := minf(_base.x, _base.y) * 0.2
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.15), r * 0.22, true)
	draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * progresso, 48, Color("#7fd3ff"), r * 0.22, true)
	for i in 12:
		var a := i * TAU / 12.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.78, c + Vector2(cos(a), sin(a)) * r * 1.22, Color(0, 0, 0, 0.5), 2.0)
	Tema.texto(self, Tema.fonte("texto_negrito"), Vector2(0, c.y + r * 1.9), "Recarregando...", 18, Tema.TEXTO, _base.x, HORIZONTAL_ALIGNMENT_CENTER, 4)


# =====================================================================
# Utilitários
# =====================================================================

func _tem_elemento(el: String) -> bool:
	if dono != null:
		return dono.elementos.has(el)
	if not elementos_dono.is_empty():
		return elementos_dono.has(el)
	return true


func _ajustar_fonte(texto: String, f: Font, largura: float, maximo: int, minimo: int) -> int:
	var tamanho := maximo
	while tamanho > minimo and f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura:
		tamanho -= 1
	return tamanho


func _titulo(identificador: String) -> String:
	var partes := identificador.split("_")
	var saida := PackedStringArray()
	for p in partes:
		if p.length() > 2 or saida.is_empty():
			saida.append(p.capitalize())
		else:
			saida.append(p)
	return " ".join(saida)
