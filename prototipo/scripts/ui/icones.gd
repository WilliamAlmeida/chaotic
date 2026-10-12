class_name Icones
extends RefCounted
## Ícones vetoriais desenhados em código, seguindo a "Folha de Ícones" do conceito:
## atributos e elementos em molduras octogonais, símbolos de Cântico (anel octogonal
## com cravos) e emblemas das facções. São placeholders fiéis até existir arte em SVG.

const CORES_ATRIBUTO := {
	"agilidade": Color("#3ddc84"),
	"forca": Color("#ff8a3d"),
	"mente": Color("#b07cff"),
	"animo": Color("#ffd23f"),
}
const CONTORNO := Color(0.05, 0.03, 0.08, 0.9)


static func octogono(c: Vector2, r: float, rot := PI / 8.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + i * TAU / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func fechar(pts: PackedVector2Array) -> PackedVector2Array:
	var f := pts.duplicate()
	f.append(pts[0])
	return f


## Polígono em coordenadas unitárias (-1..1), escalado e com contorno escuro.
static func poligono(ci: CanvasItem, unit: Array, c: Vector2, r: float, cor: Color, contorno := true) -> void:
	var pts := PackedVector2Array()
	for p in unit:
		pts.append(c + Vector2(p[0], p[1]) * r)
	ci.draw_colored_polygon(pts, cor)
	if contorno:
		ci.draw_polyline(fechar(pts), CONTORNO, maxf(1.0, r * 0.1), true)


static func hexagono(ci: CanvasItem, c: Vector2, r: float, cor: Color, contorno := true) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, cor)
	if contorno:
		ci.draw_polyline(fechar(pts), CONTORNO, maxf(1.0, r * 0.18), true)


# ---------------------------------------------------------------------
# Molduras
# ---------------------------------------------------------------------

## Chip octogonal com fundo escuro e borda dourada (ícones de atributo/elemento).
static func chip(ci: CanvasItem, c: Vector2, r: float, cor_borda: Color, fundo := Color("#141b26")) -> void:
	var pts := octogono(c, r)
	ci.draw_colored_polygon(pts, fundo)
	ci.draw_polyline(fechar(pts), Color(0, 0, 0, 0.8), maxf(2.0, r * 0.22), true)
	ci.draw_polyline(fechar(pts), cor_borda, maxf(1.0, r * 0.1), true)


# ---------------------------------------------------------------------
# Atributos
# ---------------------------------------------------------------------

static func atributo(ci: CanvasItem, chave: String, c: Vector2, r: float, com_chip := true) -> void:
	var cor: Color = CORES_ATRIBUTO.get(chave, Color.WHITE)
	if com_chip:
		chip(ci, c, r, Tema.OURO)
		r *= 0.68
	match chave:
		"agilidade":
			poligono(ci, [[0.35, -1.0], [-0.6, 0.15], [-0.05, 0.15], [-0.35, 1.0], [0.6, -0.2], [0.05, -0.2]], c, r, cor)
		"forca":
			# Punho: palma, nós dos dedos e polegar.
			ci.draw_rect(Rect2(c + Vector2(-0.62, -0.35) * r, Vector2(1.24, 1.0) * r), cor)
			for i in 4:
				ci.draw_circle(c + Vector2(-0.47 + 0.31 * i, -0.38) * r, 0.2 * r, cor.lightened(0.15))
			ci.draw_rect(Rect2(c + Vector2(-0.85, -0.05) * r, Vector2(0.4, 0.55) * r), cor.darkened(0.15))
			ci.draw_rect(Rect2(c + Vector2(-0.62, -0.58) * r, Vector2(1.24, 1.23) * r), CONTORNO, false, maxf(1.0, r * 0.1))
		"mente":
			# Cabeça de perfil com uma estrela de 4 pontas.
			ci.draw_circle(c + Vector2(0.05, -0.15) * r, 0.7 * r, cor)
			ci.draw_rect(Rect2(c + Vector2(-0.25, 0.35) * r, Vector2(0.55, 0.6) * r), cor)
			ci.draw_arc(c + Vector2(0.05, -0.15) * r, 0.7 * r, 0, TAU, 24, CONTORNO, maxf(1.0, r * 0.1), true)
			poligono(ci, [[0, -0.42], [0.12, -0.12], [0.42, 0], [0.12, 0.12], [0, 0.42], [-0.12, 0.12], [-0.42, 0], [-0.12, -0.12]],
				c + Vector2(0.05, -0.15) * r, r * 0.95, Color.WHITE, false)
		"animo":
			var pts := []
			for i in 16:
				var a := -PI / 2.0 + i * TAU / 16.0
				var raio := 1.0 if i % 4 == 0 else (0.5 if i % 2 == 0 else 0.3)
				pts.append([cos(a) * raio, sin(a) * raio])
			poligono(ci, pts, c, r, cor)


# ---------------------------------------------------------------------
# Elementos
# ---------------------------------------------------------------------

static func elemento(ci: CanvasItem, el: String, c: Vector2, r: float, aceso := true, com_chip := true) -> void:
	var cor := Dados.cor_elemento(el)
	if not aceso:
		cor = Color(cor.lerp(Color(0.45, 0.47, 0.52), 0.75), 0.75)
	if com_chip:
		chip(ci, c, r, cor if aceso else Color(0.35, 0.37, 0.42))
		if aceso:
			Tema.brilho_radial(ci, c, r * 0.95, Color(cor, 0.35), 6)
		r *= 0.68
	match el:
		"brasa":
			chama(ci, c, r, cor)
		"tempestade":
			espiral(ci, c, r, cor)
		"pedra":
			colmeia(ci, c, r, cor)
		"mare":
			onda(ci, c, r, cor)


static func chama(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	poligono(ci, [[0, -1.0], [0.3, -0.5], [0.62, -0.05], [0.6, 0.45], [0.3, 0.85], [0, 0.95], [-0.3, 0.85], [-0.6, 0.45], [-0.55, 0.0], [-0.3, -0.3], [-0.12, 0.05]], c, r, cor)
	poligono(ci, [[0, -0.15], [0.25, 0.25], [0.25, 0.6], [0, 0.78], [-0.25, 0.6], [-0.2, 0.3]], c, r, cor.lightened(0.5), false)


static func espiral(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := float(i) / 39.0
		var a := t * TAU * 1.6
		pts.append(c + Vector2(cos(a), sin(a)) * r * (0.15 + 0.85 * t))
	ci.draw_polyline(pts, CONTORNO, r * 0.34, true)
	ci.draw_polyline(pts, cor, r * 0.22, true)


static func colmeia(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	for p in [Vector2(0, -0.5), Vector2(-0.43, 0.25), Vector2(0.43, 0.25), Vector2(0, 0.75)]:
		hexagono(ci, c + p * r * 0.9, r * 0.33, cor)


static func onda(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	# Crista de onda: arco que se enrola + linha de base ondulada.
	var curva := PackedVector2Array()
	for i in 30:
		var t := float(i) / 29.0
		var a := PI * 0.95 + t * PI * 1.45
		var raio := r * (0.75 - 0.42 * t)
		curva.append(c + Vector2(0.05 * r, -0.05 * r) + Vector2(cos(a), sin(a)) * raio)
	ci.draw_polyline(curva, CONTORNO, r * 0.36, true)
	ci.draw_polyline(curva, cor, r * 0.24, true)
	var base := PackedVector2Array()
	for i in 20:
		var x := -0.95 + 1.9 * float(i) / 19.0
		base.append(c + Vector2(x, 0.72 + 0.1 * sin(x * 6.0)) * r)
	ci.draw_polyline(base, CONTORNO, r * 0.26, true)
	ci.draw_polyline(base, cor.lightened(0.25), r * 0.15, true)


static func sol(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	for i in 8:
		var a := i * TAU / 8.0
		var ponta := c + Vector2(cos(a), sin(a)) * r
		var l1 := c + Vector2(cos(a + 0.22), sin(a + 0.22)) * r * 0.5
		var l2 := c + Vector2(cos(a - 0.22), sin(a - 0.22)) * r * 0.5
		ci.draw_colored_polygon(PackedVector2Array([ponta, l1, l2]), cor)
	ci.draw_circle(c, r * 0.45, CONTORNO)
	ci.draw_circle(c, r * 0.38, cor.lightened(0.2))


static func nota(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	# Duas colcheias unidas (♫).
	var a := c + Vector2(-0.45, 0.55) * r
	var b := c + Vector2(0.45, 0.4) * r
	for p in [a, b]:
		ci.draw_circle(p, r * 0.27, CONTORNO)
		ci.draw_circle(p, r * 0.21, cor)
	ci.draw_line(a + Vector2(0.2, 0) * r, a + Vector2(0.2, -1.05) * r, cor, r * 0.13)
	ci.draw_line(b + Vector2(0.2, 0) * r, b + Vector2(0.2, -1.05) * r, cor, r * 0.13)
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(0.14, -1.1) * r, b + Vector2(0.27, -1.2) * r,
		b + Vector2(0.27, -0.92) * r, a + Vector2(0.14, -0.82) * r]), cor)


static func espada(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	var dir := Vector2(0.7, -0.7)
	var perp := Vector2(0.7, 0.7)
	var ponta := c + dir * r
	var base := c - dir * r * 0.35
	ci.draw_colored_polygon(PackedVector2Array([ponta, base + perp * r * 0.13, base - perp * r * 0.13]), cor)
	ci.draw_polyline(fechar(PackedVector2Array([ponta, base + perp * r * 0.13, base - perp * r * 0.13])), CONTORNO, r * 0.06, true)
	ci.draw_line(base + perp * r * 0.35, base - perp * r * 0.35, Tema.OURO, r * 0.14)
	ci.draw_line(base, c - dir * r * 0.85, Color("#5a3a20"), r * 0.13)
	ci.draw_circle(c - dir * r * 0.9, r * 0.1, Tema.OURO)


static func escudo_icone(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	poligono(ci, [[-0.75, -0.8], [0.75, -0.8], [0.7, 0.1], [0, 0.95], [-0.7, 0.1]], c, r, cor)
	poligono(ci, [[0, -0.55], [0.45, -0.55], [0.42, 0.05], [0, 0.6]], c, r, cor.lightened(0.3), false)


static func amuleto(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	ci.draw_arc(c + Vector2(0, -0.35) * r, r * 0.55, PI, TAU, 16, Tema.OURO, r * 0.1, true)
	poligono(ci, [[0, -0.3], [0.5, 0.25], [0, 0.95], [-0.5, 0.25]], c, r, cor)
	poligono(ci, [[0, -0.1], [0.22, 0.25], [0, 0.55], [-0.22, 0.25]], c, r, cor.lightened(0.5), false)


static func castelo(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	var partes := [Rect2(-0.8, -0.2, 0.42, 1.1), Rect2(0.38, -0.2, 0.42, 1.1), Rect2(-0.38, -0.55, 0.76, 1.45)]
	for p in partes:
		var rr: Rect2 = p
		ci.draw_rect(Rect2(c + rr.position * r, rr.size * r), cor)
	for x in [-0.8, -0.59, 0.38, 0.59, -0.38, -0.13, 0.12]:
		var topo := -0.55 if x >= -0.38 and x < 0.38 else -0.2
		ci.draw_rect(Rect2(c + Vector2(x, topo - 0.2) * r, Vector2(0.18, 0.2) * r), cor)
	ci.draw_rect(Rect2(c + Vector2(-0.15, 0.45) * r, Vector2(0.3, 0.45) * r), CONTORNO)


## Ícones genéricos por nome (marcas das facções, tipos de carta).
static func marca(ci: CanvasItem, nome: String, c: Vector2, r: float, cor: Color) -> void:
	match nome:
		"chamas":
			chama(ci, c, r, cor)
		"onda":
			onda(ci, c, r, cor)
		"colmeia":
			colmeia(ci, c, r, cor)
		"sol":
			sol(ci, c, r, cor)
		"nota":
			nota(ci, c, r, cor)
		"espada":
			espada(ci, c, r, cor)
		"escudo":
			escudo_icone(ci, c, r, cor)
		"amuleto":
			amuleto(ci, c, r, cor)
		"castelo":
			castelo(ci, c, r, cor)
		"interrogacao":
			Tema.texto(ci, Tema.fonte("titulo"), c + Vector2(-r * 0.5, r * 0.55), "?", int(r * 1.6), cor, r, HORIZONTAL_ALIGNMENT_CENTER, 4)


# ---------------------------------------------------------------------
# Símbolo de Cântico: anel octogonal chanfrado com 4 cravos em losango
# ---------------------------------------------------------------------

static func simbolo_cantico(ci: CanvasItem, c: Vector2, r: float, cor: Color, marca_interna := "", brilho := 0.0, aceso := true) -> void:
	if not aceso:
		cor = cor.lerp(Color(0.25, 0.28, 0.33), 0.8)
	if brilho > 0.0 and aceso:
		for i in 8:
			ci.draw_colored_polygon(octogono(c, r * (1.0 + 0.045 * (i + 1))), Color(cor, brilho * 0.06))
	var esp := r * 0.24
	var ext := octogono(c, r)
	var inte := octogono(c, r - esp)
	# Fundo do miolo.
	ci.draw_colored_polygon(inte, Color(cor.darkened(0.82), 0.92 if aceso else 0.6))
	# Faces do anel com luz vinda de cima (chanfro).
	for i in 8:
		var j := (i + 1) % 8
		var meio := (ext[i] + ext[j]) / 2.0 - c
		var luz := clampf(0.5 - meio.normalized().y * 0.5, 0.0, 1.0)
		var face := cor.darkened(0.35).lerp(cor.lightened(0.35), luz)
		ci.draw_colored_polygon(PackedVector2Array([ext[i], ext[j], inte[j], inte[i]]), face)
		ci.draw_line(ext[i], inte[i], Color(cor.darkened(0.6), 0.9), maxf(1.0, r * 0.025), true)
	ci.draw_polyline(fechar(ext), CONTORNO, maxf(1.5, r * 0.05), true)
	ci.draw_polyline(fechar(inte), CONTORNO, maxf(1.0, r * 0.035), true)
	ci.draw_polyline(fechar(octogono(c, r - esp * 0.25)), Color(cor.lightened(0.6), 0.5), maxf(1.0, r * 0.02), true)
	# Cravos em losango nos pontos cardeais.
	var dourado := Tema.OURO if aceso else Color(0.4, 0.4, 0.45)
	for i in 4:
		var a := i * PI / 2.0 - PI / 2.0
		var p := c + Vector2(cos(a), sin(a)) * (r - esp * 0.5)
		var d := Vector2(cos(a), sin(a)) * esp * 0.75
		var q := Vector2(-d.y, d.x) * 0.55
		var losango := PackedVector2Array([p + d, p + q, p - d, p - q])
		ci.draw_colored_polygon(losango, dourado)
		ci.draw_polyline(fechar(losango), CONTORNO, maxf(1.0, r * 0.02), true)
	if marca_interna != "":
		marca(ci, marca_interna, c, (r - esp) * 0.7, cor.lightened(0.15) if aceso else cor)
	elif aceso:
		# Sem marca: miolo preenchido para "carga cheia" ficar evidente mesmo pequeno.
		ci.draw_colored_polygon(octogono(c, (r - esp) * 0.92), cor.lightened(0.1))
		ci.draw_colored_polygon(octogono(c, (r - esp) * 0.45), cor.lightened(0.55))


## Emblema da facção: chip octogonal com a marca dentro.
static func emblema(ci: CanvasItem, f: Dictionary, c: Vector2, r: float) -> void:
	var cor := Color(str(f.get("cor", "#8a97ab")))
	chip(ci, c, r, Tema.OURO, Color(str(f.get("cor_escura", "#1e2936"))))
	var m := str(f.get("marca", ""))
	if m != "":
		marca(ci, m, c, r * 0.62, cor.lightened(0.2))
