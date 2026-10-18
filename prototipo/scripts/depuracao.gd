class_name Depuracao
extends RefCounted
## Utilidades para roteiros de teste/captura (ver main.gd, argumento --roteiro=caminho.gd).
##
## Um roteiro é um script que estende Node; o Main o adiciona como filho e ele dirige o
## jogo (abre telas, simula toques, tira capturas) e chama get_tree().quit() ao terminar.
##
##   static func capturar(arvore, caminho)   salva o viewport principal em PNG
##   static func esperar(arvore, segundos)   await de tempo real
##   static func pasta()                     pasta passada em --pasta=... (ou user://)

static func capturar(arvore: SceneTree, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := arvore.root.get_viewport().get_texture().get_image()
	var caminho := nome if nome.contains("/") else pasta().path_join(nome)
	if not caminho.ends_with(".png"):
		caminho += ".png"
	img.save_png(caminho)
	print("captura ", caminho)


static func esperar(arvore: SceneTree, segundos: float) -> void:
	await arvore.create_timer(segundos).timeout


static func pasta() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pasta="):
			return a.get_slice("=", 1)
	return OS.get_user_data_dir()


## Simula um toque/clique de tela numa posição (coordenadas do viewport base 1920x1080).
static func tocar(arvore: SceneTree, pos: Vector2, soltar := true) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = true
	ev.index = 0
	Input.parse_input_event(ev)
	if soltar:
		await arvore.process_frame
		var ev2 := InputEventScreenTouch.new()
		ev2.position = pos
		ev2.pressed = false
		ev2.index = 0
		Input.parse_input_event(ev2)


## Aperta uma ação do InputMap por alguns quadros.
static func acao(arvore: SceneTree, nome: String, quadros := 2) -> void:
	Input.action_press(nome)
	for i in quadros:
		await arvore.process_frame
	Input.action_release(nome)
