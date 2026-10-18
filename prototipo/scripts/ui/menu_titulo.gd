class_name MenuTitulo
extends Control
## Tela de título: Campanha (história), Duelo Rápido (loadout livre) e Opções.

signal campanha
signal duelo_rapido
signal opcoes

var _coluna: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Tema.criar_tema()
	_construir()


func _draw() -> void:
	Tema.gradiente(self, Rect2(Vector2.ZERO, size), Color("#0c121c"), Color("#1a2438"))
	Tema.brilho_radial(self, size * Vector2(0.5, 0.42), size.y * 0.55, Color(0.3, 0.4, 0.7, 0.3), 10)


func _construir() -> void:
	_coluna = VBoxContainer.new()
	_coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	_coluna.add_theme_constant_override("separation", 22)
	_coluna.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_coluna.custom_minimum_size = Vector2(520, 0)
	_coluna.position -= Vector2(260, 220)
	add_child(_coluna)

	var titulo := Label.new()
	titulo.text = "ECOS DE AETHERIS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", Tema.fonte("titulo"))
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", Tema.OURO_CLARO)
	_coluna.add_child(titulo)

	for par in [["CAMPANHA", campanha], ["DUELO RÁPIDO", duelo_rapido], ["OPÇÕES", opcoes]]:
		var b := Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(520, 84)
		b.add_theme_font_size_override("font_size", 30)
		var sinal: Signal = par[1]
		b.pressed.connect(func():
			Audio.tocar("confirmar")
			sinal.emit())
		_coluna.add_child(b)
