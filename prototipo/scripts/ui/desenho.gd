class_name Desenho
extends Control
## Control que desenha via Callable: funcao(ci: Control) -> void.
## Útil para ícones e ornamentos sem criar uma classe para cada um.

var funcao: Callable
## Redesenha todo frame (para brilhos pulsantes e barras que mudam).
var animado := false
var tempo := 0.0


static func criar(f: Callable, pos: Vector2, tamanho: Vector2, anima := false) -> Desenho:
	var d := Desenho.new()
	d.funcao = f
	d.position = pos
	d.size = tamanho
	d.custom_minimum_size = tamanho
	d.animado = anima
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _process(delta: float) -> void:
	if animado:
		tempo += delta
		queue_redraw()


func _draw() -> void:
	if funcao.is_valid():
		funcao.call(self)
