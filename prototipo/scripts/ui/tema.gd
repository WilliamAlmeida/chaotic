class_name Tema
extends RefCounted
## Identidade visual do jogo (ver docs/gui-conceito.md): paleta, fontes e estilos.
## Fontes: Cinzel (títulos), Rajdhani (números), Exo 2 (texto). Licença OFL em res://fontes.

const CARVAO := Color("#0f1620")
const PAINEL := Color("#1e2936")
const MEDIO := Color("#3a4657")
const PERGAMINHO := Color("#f2e7d6")
const PERGAMINHO_ESCURO := Color("#d8c6a6")
const OURO := Color("#e8b75a")
const OURO_CLARO := Color("#ffe3a0")
const OURO_ESCURO := Color("#7a5a22")
const TEXTO := Color("#f4efe6")
const TEXTO_SUAVE := Color("#a9b4c4")
const TEXTO_ESCURO := Color("#2a2018")
const VERDE_ATIVO := Color("#2f9e4a")
const VERMELHO := Color("#d9452b")

## Molduras por tipo de carta (cor escura, cor da borda, cor clara).
const MOLDURA_EQUIPAMENTO := [Color("#16263a"), Color("#6fa8dc"), Color("#cfe6ff")]
const MOLDURA_LOCAL := [Color("#3a2a10"), Color("#e8b75a"), Color("#fff0c0")]
const MOLDURA_NEUTRA := [Color("#1e2936"), Color("#8a97ab"), Color("#dfe6f0")]

const ARQUIVOS_FONTE := {
	"titulo": "res://fontes/Cinzel-Bold.woff2",
	"numero": "res://fontes/Rajdhani-Bold.woff2",
	"texto": "res://fontes/Exo2-Medium.woff2",
	"texto_negrito": "res://fontes/Exo2-Bold.woff2",
}

static var _fontes: Dictionary = {}


static func fonte(nome: String) -> Font:
	if _fontes.has(nome):
		return _fontes[nome]
	var caminho: String = ARQUIVOS_FONTE.get(nome, "")
	var f: Font = ThemeDB.fallback_font
	if caminho != "" and ResourceLoader.exists(caminho):
		f = load(caminho)
	_fontes[nome] = f
	return f


static func caixa(fundo: Color, borda: Color, largura := 2, raio := 10, brilho := Color(0, 0, 0, 0), tamanho_brilho := 0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(largura)
	estilo.set_corner_radius_all(raio)
	estilo.anti_aliasing = true
	if tamanho_brilho > 0:
		estilo.shadow_color = brilho
		estilo.shadow_size = tamanho_brilho
	return estilo


## Tema global aplicado na janela raiz (botões, rótulos, barras de rolagem).
static func criar_tema() -> Theme:
	var t := Theme.new()
	t.default_font = fonte("texto")
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXTO)

	var normal := caixa(Color(PAINEL, 0.92), MEDIO, 2, 8)
	normal.set_content_margin_all(10)
	var foco := caixa(Color(PAINEL.lightened(0.08), 0.95), OURO, 2, 8, Color(OURO, 0.35), 6)
	foco.set_content_margin_all(10)
	var pressionado := caixa(CARVAO, OURO, 2, 8)
	pressionado.set_content_margin_all(10)
	var desabilitado := caixa(Color(PAINEL, 0.5), Color(MEDIO, 0.5), 2, 8)
	desabilitado.set_content_margin_all(10)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", foco)
	t.set_stylebox("focus", "Button", foco)
	t.set_stylebox("pressed", "Button", pressionado)
	t.set_stylebox("disabled", "Button", desabilitado)
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", OURO_CLARO)
	t.set_color("font_pressed_color", "Button", OURO)
	t.set_color("font_disabled_color", "Button", Color(TEXTO, 0.4))
	t.set_font("font", "Button", fonte("texto_negrito"))

	var trilho := caixa(Color(CARVAO, 0.6), Color(0, 0, 0, 0), 0, 4)
	var pegador := caixa(MEDIO, Color(0, 0, 0, 0), 0, 4)
	var pegador_foco := caixa(OURO_ESCURO, Color(0, 0, 0, 0), 0, 4)
	for barra in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", barra, trilho)
		t.set_stylebox("grabber", barra, pegador)
		t.set_stylebox("grabber_highlight", barra, pegador_foco)
		t.set_stylebox("grabber_pressed", barra, pegador_foco)
	return t


## Desenha texto com contorno (para ficar legível sobre arte).
static func texto(ci: CanvasItem, f: Font, pos: Vector2, s: String, tamanho: int, cor: Color,
		largura := -1.0, alinhamento := HORIZONTAL_ALIGNMENT_LEFT, contorno := 0, cor_contorno := Color(0, 0, 0, 0.85)) -> void:
	if contorno > 0:
		ci.draw_string_outline(f, pos, s, alinhamento, largura, tamanho, contorno, cor_contorno)
	ci.draw_string(f, pos, s, alinhamento, largura, tamanho, cor)


## Gradiente vertical num retângulo.
static func gradiente(ci: CanvasItem, r: Rect2, topo: Color, base: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts, PackedColorArray([topo, topo, base, base]))


## Gradiente radial aproximado (anéis concêntricos), usado nas artes procedurais.
static func brilho_radial(ci: CanvasItem, c: Vector2, raio: float, cor: Color, passos := 10) -> void:
	for i in passos:
		var k := 1.0 - float(i) / passos
		ci.draw_circle(c, raio * k, Color(cor, cor.a * (1.0 / passos) * 1.6))


## Cores vivas para feedback de acerto/erro/aviso (HUD infantil).
const VERDE_CLARO := Color("#5dff8a")
const VERMELHO_CLARO := Color("#ff6b5a")
const AZUL_CLARO := Color("#7fd3ff")
const LARANJA := Color("#ff9f3d")


## Deixa um Button enorme e colorido, bom para dedos pequenos em celular.
static func botao_grande(b: Button, cor: Color, tamanho_fonte := 30, minimo := Vector2(380, 92)) -> void:
	b.custom_minimum_size = minimo
	b.add_theme_font_override("font", fonte("titulo"))
	b.add_theme_font_size_override("font_size", tamanho_fonte)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", OURO_CLARO)
	b.add_theme_color_override("font_pressed_color", OURO_CLARO)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var normal := caixa(cor, OURO, 4, 18, Color(cor, 0.35), 10)
	normal.set_content_margin_all(14)
	var foco := caixa(cor.lightened(0.15), OURO_CLARO, 4, 18, Color(OURO, 0.5), 16)
	foco.set_content_margin_all(14)
	var pressionado := caixa(cor.darkened(0.25), OURO, 4, 18)
	pressionado.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", foco)
	b.add_theme_stylebox_override("focus", foco)
	b.add_theme_stylebox_override("pressed", pressionado)
