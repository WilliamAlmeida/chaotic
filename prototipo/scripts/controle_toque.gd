class_name ControleToque
extends CanvasLayer
## Controles de toque para celular/tablet: joystick virtual flutuante na metade esquerda e
## botões grandes e redondos (GOLPE, ESQUIVA, PULO, CÂNTICO) na metade direita. Durante o
## Cântico os botões dão lugar a 4 setas (as notas da sequência). Arrastar na metade direita
## fora dos botões gira a câmera. A Batalha cria esta camada quando Jogo.toque_ativo() é verdadeiro.
##
## Contrato: esta camada só injeta ações no InputMap (Input.action_press / action_release)
## e ajusta a câmera por arrasto; o ControleJogador continua sendo quem fala com o Lutador.
## O botão de pausa envia um InputEventAction "ui_cancel" (a Batalha trata como Esc).
##
## Tudo é desenhado em código (estilo do Tema: dourado sobre carvão, contornos grossos,
## levemente translúcido) numa base 1920x1080 que acompanha a altura real da janela.
## Faixas livres: o topo (painéis dos lutadores e relógio), o fundo (painel de Cântico,
## cartas da mão e Ritmo) e a tela de resultado no centro.

const RAIO_BASE := 120.0        # base do joystick
const RAIO_MANETE := 58.0       # manete do joystick
const ALCANCE := 92.0           # deslocamento máximo do manete (força 1.0)
const FAIXA_TOPO := 210.0       # altura reservada no topo (painéis e relógio)
const FAIXA_FUNDO := 212.0      # altura reservada no fundo (Cântico, cartas, Ritmo)
const SENSIBILIDADE := 0.0055   # radianos por pixel ao arrastar a câmera
const INDICE_MOUSE := 1000      # "dedo" usado para o mouse real (toque forçado no desktop)
const RAIO_GOLPE := 98.0
const RAIO_BOTAO := 78.0
const RAIO_SETA := 82.0
const RAIO_PAUSA := 34.0
const CONTORNO := Color(0.05, 0.03, 0.08, 0.9)

## Ações de movimento alimentadas pelo joystick (e pelas setas do Cântico).
const ACOES_MOVER := ["mover_frente", "mover_esq", "mover_tras", "mover_dir"]

var lutador: Lutador
var camera: CameraOrbita

var _tela: Desenho
var _botoes: Array = []           # botões normais (dicionários, ver _montar)
var _setas: Array = []            # setas do Cântico
var _pausa: Dictionary = {}
var _tamanho := Vector2.ZERO      # tamanho da tela usado na última montagem
var _tempo := 0.0

var _toque_joystick := -1
var _joy_centro := Vector2.ZERO
var _joy_manete := Vector2.ZERO
var _joy_visivel := 0.0           # 0..1, aparece/some suavemente
var _joy_repouso := Vector2.ZERO  # posição "fantasma" quando ninguém toca
var _toque_camera := -1
var _toques_botoes: Dictionary = {}   # índice do dedo -> botão (dicionário)
var _mouse_emulado := false       # o mouse emulado do primeiro toque é nosso?
var _eventos_mouse_removidos: Array = []
var _cantando_antes := false
var _pausa_pressao := 0.0


func _ready() -> void:
	layer = 20
	_tela = Desenho.criar(_desenhar, Vector2.ZERO, Vector2(1920, 1080), true)
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_tela)
	# Com toque, o clique esquerdo deixa de ser "golpe": senão cada toque numa carta
	# (o toque vira clique emulado) também daria um soco.
	if InputMap.has_action("ataque_basico"):
		for ev in InputMap.action_get_events("ataque_basico"):
			if ev is InputEventMouseButton:
				_eventos_mouse_removidos.append(ev)
		for ev in _eventos_mouse_removidos:
			InputMap.action_erase_event("ataque_basico", ev)
	_montar()


func _exit_tree() -> void:
	_soltar_tudo()
	if InputMap.has_action("ataque_basico"):
		for ev in _eventos_mouse_removidos:
			InputMap.action_add_event("ataque_basico", ev)
	_eventos_mouse_removidos.clear()


# ---------------------------------------------------------------------
# Montagem (posições relativas ao tamanho real da tela)
# ---------------------------------------------------------------------

func _montar() -> void:
	var t := _tela.size
	if t.x < 10.0 or t.y < 10.0:
		t = Vector2(1920, 1080)
	_tamanho = t
	var w := t.x
	var h := t.y
	_botoes = [
		_botao("GOLPE", "ataque_basico", Vector2(w - 250, h * 0.70), RAIO_GOLPE, "punho", true),
		_botao("ESQUIVA", "esquivar", Vector2(w - 500, h * 0.73), RAIO_BOTAO, "rastro"),
		_botao("PULO", "pular", Vector2(w - 500, h * 0.49), RAIO_BOTAO, "seta"),
		_botao("CÂNTICO", "cantico", Vector2(w - 250, h * 0.44), RAIO_BOTAO, "nota"),
	]
	var c := Vector2(w - 380, h * 0.56)
	var passo := 175.0
	_setas = [
		_botao("W", "mover_frente", c + Vector2(0, -passo), RAIO_SETA, "seta", false, 0.0),
		_botao("A", "mover_esq", c + Vector2(-passo, 0), RAIO_SETA, "seta", false, -PI / 2.0),
		_botao("S", "mover_tras", c + Vector2(0, passo), RAIO_SETA, "seta", false, PI),
		_botao("D", "mover_dir", c + Vector2(passo, 0), RAIO_SETA, "seta", false, PI / 2.0),
	]
	_pausa = {"centro": Vector2(w - 64, FAIXA_TOPO + 22), "raio": RAIO_PAUSA}
	_joy_repouso = Vector2(w * 0.19, h * 0.56)
	if _toque_joystick == -1:
		_joy_centro = _joy_repouso
		_joy_manete = _joy_centro


func _botao(rotulo: String, acao: String, centro: Vector2, raio: float, icone: String, destaque := false, giro := 0.0) -> Dictionary:
	return {"rotulo": rotulo, "acao": acao, "centro": centro, "raio": raio, "icone": icone,
		"destaque": destaque, "giro": giro, "pressao": 0.0, "apertado": false}


func _process(delta: float) -> void:
	_tempo += delta
	if _tela.size != _tamanho:
		_montar()
	if lutador == null or not is_instance_valid(lutador):
		return
	# Entrar ou sair do Cântico: solta tudo, porque o conjunto de botões muda.
	if lutador.cantando != _cantando_antes:
		_cantando_antes = lutador.cantando
		_soltar_tudo()
	for b in _botoes + _setas:
		b["pressao"] = move_toward(b["pressao"], 1.0 if b["apertado"] else 0.0, delta * 9.0)
	_pausa_pressao = move_toward(_pausa_pressao, 0.0, delta * 4.0)
	_joy_visivel = move_toward(_joy_visivel, 1.0 if _toque_joystick != -1 else 0.0, delta * 6.0)
	# Antes da luta começar (ou depois de acabar) os controles ficam apagados.
	var ativo := lutador.controles_ativos and lutador.energia > 0.0
	_tela.modulate.a = move_toward(_tela.modulate.a, 1.0 if ativo else 0.55, delta * 3.0)
	if _toque_joystick == -1:
		_joy_centro = _joy_centro.lerp(_joy_repouso, 1.0 - exp(-6.0 * delta))
		_joy_manete = _joy_manete.lerp(_joy_centro, 1.0 - exp(-10.0 * delta))


# ---------------------------------------------------------------------
# Entrada (multitoque)
# ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if lutador == null or not is_instance_valid(lutador):
		return
	var consumido := false
	if event is InputEventScreenTouch:
		consumido = _toque(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		consumido = _arrastar(event.index, event.position, event.relative)
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			# Clique emulado a partir do primeiro dedo: engolimos quando o dedo é nosso,
			# para o clique não vazar para as cartas, a câmera ou a Batalha.
			if event.pressed:
				_mouse_emulado = _zona(event.position) != ""
			consumido = _mouse_emulado
			if not event.pressed:
				_mouse_emulado = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Mouse real com toque forçado no desktop: vale como um dedo.
			consumido = _toque(INDICE_MOUSE, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			consumido = _mouse_emulado
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			consumido = _arrastar(INDICE_MOUSE, event.position, event.relative)
	if consumido:
		get_viewport().set_input_as_handled()


## A quem pertence um toque nesta posição: "botao", "seta", "pausa", "joystick", "camera" ou "".
func _zona(p: Vector2) -> String:
	if lutador.cantando:
		if not _botao_em(_setas, p).is_empty():
			return "seta"
	elif not _botao_em(_botoes, p).is_empty():
		return "botao"
	if p.distance_to(_pausa["centro"]) <= _pausa["raio"] * 1.4:
		return "pausa"
	var w := _tamanho.x
	var h := _tamanho.y
	if p.y < FAIXA_TOPO or p.y > h - FAIXA_FUNDO:
		return ""
	if p.x < w * 0.5:
		return "joystick"
	# Cartas da mão (centro do fundo): não cobrimos.
	if absf(p.x - w * 0.5) < 350.0 and p.y > h - 300.0:
		return ""
	return "camera"


func _botao_em(lista: Array, p: Vector2) -> Dictionary:
	var melhor := {}
	var melhor_d := INF
	for b in lista:
		var d := p.distance_to(b["centro"])
		if d <= b["raio"] * 1.18 and d < melhor_d:
			melhor = b
			melhor_d = d
	return melhor if not melhor.is_empty() else {}


func _toque(indice: int, p: Vector2, pressionado: bool) -> bool:
	if not pressionado:
		return _soltar(indice)
	match _zona(p):
		"botao", "seta":
			var b := _botao_em(_setas if lutador.cantando else _botoes, p)
			if b.is_empty():
				return false
			_apertar_botao(indice, b)
			return true
		"pausa":
			_pausa_pressao = 1.0
			Audio.tocar("clique", -4.0)
			var ev := InputEventAction.new()
			ev.action = "ui_cancel"
			ev.pressed = true
			Input.parse_input_event(ev)
			return true
		"joystick":
			if _toque_joystick != -1 or lutador.cantando:
				return false
			_toque_joystick = indice
			_joy_centro = _limitar_base(p)
			_joy_manete = _joy_centro
			_joy_visivel = maxf(_joy_visivel, 0.3)
			return true
		"camera":
			if _toque_camera != -1:
				return false
			_toque_camera = indice
			return true
	return false


func _arrastar(indice: int, p: Vector2, relativo: Vector2) -> bool:
	if indice == _toque_joystick:
		_mover_joystick(p)
		return true
	if indice == _toque_camera:
		if is_instance_valid(camera):
			camera.pitch = clampf(camera.pitch - relativo.y * SENSIBILIDADE, -1.1, 0.25)
			if not camera.travada:
				camera.yaw -= relativo.x * SENSIBILIDADE
		return true
	return _toques_botoes.has(indice)


func _soltar(indice: int) -> bool:
	var era_nosso := false
	if indice == _toque_joystick:
		_toque_joystick = -1
		_soltar_movimento()
		era_nosso = true
	if indice == _toque_camera:
		_toque_camera = -1
		era_nosso = true
	if _toques_botoes.has(indice):
		var b: Dictionary = _toques_botoes[indice]
		_toques_botoes.erase(indice)
		_soltar_botao(b)
		era_nosso = true
	return era_nosso


func _apertar_botao(indice: int, b: Dictionary) -> void:
	_toques_botoes[indice] = b
	b["apertado"] = true
	b["pressao"] = 1.0
	Input.action_press(str(b["acao"]))
	Audio.tocar("clique", -10.0, 1.15 if b["destaque"] else 1.0)
	if bool(Jogo.config.get("vibracao", true)):
		Input.vibrate_handheld(25)


func _soltar_botao(b: Dictionary) -> void:
	b["apertado"] = false
	# Outro dedo ainda segura o mesmo botão? Então a ação continua.
	for outro in _toques_botoes.values():
		if is_same(outro, b):
			b["apertado"] = true
			return
	Input.action_release(str(b["acao"]))


func _soltar_movimento() -> void:
	for acao in ACOES_MOVER:
		Input.action_release(acao)


func _soltar_tudo() -> void:
	for b in _toques_botoes.values():
		b["apertado"] = false
		Input.action_release(str(b["acao"]))
	_toques_botoes.clear()
	for b in _botoes + _setas:
		b["apertado"] = false
	if _toque_joystick != -1:
		_toque_joystick = -1
		_soltar_movimento()
	_toque_camera = -1


func _limitar_base(p: Vector2) -> Vector2:
	var w := _tamanho.x
	var h := _tamanho.y
	return Vector2(clampf(p.x, RAIO_BASE + 10.0, w * 0.5 - RAIO_BASE),
		clampf(p.y, FAIXA_TOPO + RAIO_BASE * 0.6, h - FAIXA_FUNDO - RAIO_BASE * 0.6))


func _mover_joystick(p: Vector2) -> void:
	var d := p - _joy_centro
	if d.length() > ALCANCE:
		# Joystick flutuante: a base acompanha o dedo quando ele vai longe demais,
		# assim arrastões grandes de criança continuam funcionando.
		_joy_centro = _limitar_base(_joy_centro + d.normalized() * (d.length() - ALCANCE))
		d = (p - _joy_centro).limit_length(ALCANCE)
	_joy_manete = _joy_centro + d
	var forca := d / ALCANCE
	_acao_analogica("mover_dir", forca.x)
	_acao_analogica("mover_esq", -forca.x)
	_acao_analogica("mover_tras", forca.y)
	_acao_analogica("mover_frente", -forca.y)


func _acao_analogica(acao: String, valor: float) -> void:
	if valor > 0.02:
		Input.action_press(acao, clampf(valor, 0.0, 1.0))
	else:
		Input.action_release(acao)


# ---------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------

func _desenhar(ci: Control) -> void:
	if lutador == null or not is_instance_valid(lutador):
		return
	if lutador.cantando:
		_desenhar_setas(ci)
	else:
		_desenhar_joystick(ci)
		for b in _botoes:
			_desenhar_botao(ci, b)
	_desenhar_pausa(ci)


func _desenhar_joystick(ci: Control) -> void:
	var c := _joy_centro
	var vis := 0.38 + 0.62 * _joy_visivel
	var esc := 0.9 + 0.1 * _joy_visivel
	var r := RAIO_BASE * esc
	# Base: disco de carvão translúcido com anel dourado grosso.
	ci.draw_circle(c, r + 5.0, Color(CONTORNO, 0.7 * vis))
	ci.draw_circle(c, r, Color(Tema.CARVAO, 0.45 * vis))
	ci.draw_arc(c, r, 0.0, TAU, 64, Color(Tema.OURO, 0.9 * vis), 6.0, true)
	ci.draw_arc(c, r * 0.62, 0.0, TAU, 48, Color(Tema.OURO, 0.25 * vis), 2.0, true)
	# Quatro setinhas nas bordas (indicam que aqui se anda).
	for i in 4:
		var ang := i * PI / 2.0
		var dir := Vector2(0, -1).rotated(ang)
		var ponta := c + dir * (r - 16.0)
		var base := c + dir * (r - 36.0)
		var lado := dir.orthogonal() * 12.0
		ci.draw_colored_polygon(PackedVector2Array([ponta, base + lado, base - lado]), Color(Tema.OURO_CLARO, 0.8 * vis))
	# Manete: botão dourado com brilho.
	var m := _joy_manete
	var rm := RAIO_MANETE * (0.9 + 0.1 * _joy_visivel)
	if _joy_visivel > 0.0:
		Tema.brilho_radial(ci, m, rm * 1.6, Color(Tema.OURO, 0.35 * _joy_visivel), 5)
	ci.draw_circle(m, rm + 5.0, Color(CONTORNO, 0.9 * vis))
	ci.draw_circle(m, rm, Color(Tema.OURO, vis))
	ci.draw_circle(m, rm * 0.78, Color(Tema.OURO_CLARO, 0.85 * vis))
	ci.draw_arc(m + Vector2(0, -rm * 0.2), rm * 0.45, deg_to_rad(200), deg_to_rad(340), 20, Color(1, 1, 1, 0.55 * vis), rm * 0.14, true)
	if _joy_visivel < 0.5:
		Tema.texto(ci, Tema.fonte("titulo"), Vector2(c.x - 120, c.y + r + 34), "MOVER", 20,
			Color(Tema.OURO_CLARO, 0.9 * vis), 240, HORIZONTAL_ALIGNMENT_CENTER, 5)


func _desenhar_botao(ci: Control, b: Dictionary) -> void:
	var p: float = b["pressao"]
	var c: Vector2 = b["centro"]
	var r: float = b["raio"] * (1.0 + 0.14 * p)
	var destaque: bool = b["destaque"]
	var fracao := _fracao_recarga(str(b["acao"]))
	var disponivel := fracao >= 1.0
	var fundo := Color(Tema.OURO, 0.88) if destaque else Color(Tema.PAINEL, 0.82)
	var borda := Color(Tema.OURO_CLARO, 0.95) if destaque else Color(Tema.OURO, 0.95)
	var cor_icone := Tema.CARVAO if destaque else Tema.OURO_CLARO
	if not disponivel:
		fundo = Color(fundo.darkened(0.35), fundo.a)
		cor_icone = Color(cor_icone, 0.55)
	if p > 0.0:
		Tema.brilho_radial(ci, c, r * 1.45, Color(Tema.OURO_CLARO, 0.45 * p), 6)
	ci.draw_circle(c, r + 7.0, Color(CONTORNO, 0.9))
	ci.draw_circle(c, r, fundo)
	ci.draw_circle(c, r, Color(Tema.OURO_CLARO, 0.25 * p))
	# Brilho no topo (vidro).
	ci.draw_arc(c + Vector2(0, -r * 0.12), r * 0.72, deg_to_rad(205), deg_to_rad(335), 28, Color(1, 1, 1, 0.16), r * 0.12, true)
	ci.draw_arc(c, r, 0.0, TAU, 64, borda, 6.0, true)
	# Recarga: anel que vai se completando.
	if not disponivel:
		ci.draw_arc(c, r - 12.0, -PI / 2.0, -PI / 2.0 + TAU * fracao, 48, Color(Tema.OURO_CLARO, 0.95), 7.0, true)
	_desenhar_icone(ci, str(b["icone"]), c + Vector2(0, -r * 0.16), r * 0.46, cor_icone, float(b["giro"]))
	var fonte_tam := 26 if destaque else 21
	var cor_rotulo := Tema.TEXTO_ESCURO if destaque else Tema.TEXTO
	Tema.texto(ci, Tema.fonte("titulo"), Vector2(c.x - r, c.y + r * 0.78), str(b["rotulo"]), fonte_tam,
		cor_rotulo, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER, 4 if destaque else 5,
		Color(Tema.OURO_CLARO, 0.6) if destaque else Color(0, 0, 0, 0.85))
	if str(b["acao"]) == "cantico":
		# Carguinhas do Cântico restantes.
		var n: int = lutador.cargas_cantico
		for i in maxi(n, 0):
			ci.draw_circle(c + Vector2(-10.0 * (n - 1) + i * 20.0, -r - 20.0), 7.0, Tema.OURO_CLARO)
			ci.draw_arc(c + Vector2(-10.0 * (n - 1) + i * 20.0, -r - 20.0), 7.0, 0.0, TAU, 16, CONTORNO, 2.0, true)


func _desenhar_setas(ci: Control) -> void:
	var proxima := ""
	if Jogo.facil() and lutador.cantico_progresso < lutador.cantico_sequencia.size():
		proxima = str(lutador.cantico_sequencia[lutador.cantico_progresso])
	# Fundo em cruz, discreto, ligando as quatro setas.
	var c0: Vector2 = (_setas[0]["centro"] + _setas[2]["centro"]) / 2.0
	ci.draw_circle(c0, 60.0, Color(Tema.CARVAO, 0.5))
	ci.draw_arc(c0, 60.0, 0.0, TAU, 40, Color(Tema.OURO, 0.5), 4.0, true)
	Icones.nota(ci, c0 + Vector2(0, 14), 30.0, Tema.OURO_CLARO)
	for b in _setas:
		var p: float = b["pressao"]
		var c: Vector2 = b["centro"]
		var r: float = b["raio"] * (1.0 + 0.14 * p)
		var destaque: bool = str(b["acao"]) == proxima
		var pulso := 0.5 + 0.5 * sin(_tempo * 8.0)
		var fundo := Color(Tema.OURO, 0.9) if destaque else Color(Tema.PAINEL, 0.82)
		var borda := Color(Tema.OURO_CLARO, 0.8 + 0.2 * pulso) if destaque else Color(Tema.OURO, 0.95)
		if destaque:
			Tema.brilho_radial(ci, c, r * (1.4 + 0.15 * pulso), Color(Tema.OURO_CLARO, 0.4), 6)
		if p > 0.0:
			Tema.brilho_radial(ci, c, r * 1.45, Color(Tema.OURO_CLARO, 0.45 * p), 6)
		ci.draw_circle(c, r + 7.0, Color(CONTORNO, 0.9))
		ci.draw_circle(c, r, fundo)
		ci.draw_circle(c, r, Color(Tema.OURO_CLARO, 0.25 * p))
		ci.draw_arc(c, r, 0.0, TAU, 64, borda, 6.0 + 2.0 * pulso * float(destaque), true)
		_desenhar_icone(ci, "seta", c + Vector2(0, -r * 0.14), r * 0.5, Tema.CARVAO if destaque else Tema.OURO_CLARO, float(b["giro"]))
		# Letra do teclado, pequena, para casar com o painel de Cântico da HUD.
		Tema.texto(ci, Tema.fonte("titulo"), Vector2(c.x - r, c.y + r * 0.74), str(b["rotulo"]), 18,
			Tema.TEXTO_ESCURO if destaque else Tema.TEXTO_SUAVE, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER, 3)


func _desenhar_pausa(ci: Control) -> void:
	var c: Vector2 = _pausa["centro"]
	var r: float = _pausa["raio"] * (1.0 + 0.15 * _pausa_pressao)
	ci.draw_circle(c, r + 4.0, Color(CONTORNO, 0.8))
	ci.draw_circle(c, r, Color(Tema.PAINEL, 0.75))
	ci.draw_arc(c, r, 0.0, TAU, 40, Color(Tema.OURO, 0.9), 4.0, true)
	for lado in [-1.0, 1.0]:
		ci.draw_rect(Rect2(c + Vector2(lado * 9.0 - 4.0, -12.0), Vector2(8.0, 24.0)), Tema.OURO_CLARO)


## Ícones simples desenhados em código (tamanho r = "raio" do ícone).
func _desenhar_icone(ci: Control, nome: String, c: Vector2, r: float, cor: Color, giro := 0.0) -> void:
	match nome:
		"punho":
			_icone_punho(ci, c, r, cor)
		"rastro":
			_icone_rastro(ci, c, r, cor)
		"seta":
			_icone_seta(ci, c, r, cor, giro)
		"nota":
			Icones.nota(ci, c + Vector2(0, r * 0.3), r * 0.9, cor)


func _icone_punho(ci: Control, c: Vector2, r: float, cor: Color) -> void:
	# Punho fechado visto de frente: 4 dedos com os nós em cima e o polegar cruzando embaixo.
	var escuro := CONTORNO
	var corpo := Rect2(c + Vector2(-0.85, -0.45) * r, Vector2(1.7, 0.95) * r)
	var nos: Array = []
	for i in 4:
		nos.append(c + Vector2(-0.62 + i * 0.415, -0.47) * r)
	var polegar_a := c + Vector2(-0.72, 0.42) * r
	var polegar_b := c + Vector2(0.35, 0.42) * r
	# Passo 1: contorno escuro (formas um pouco maiores).
	ci.draw_rect(corpo.grow(r * 0.09), escuro)
	for n in nos:
		ci.draw_circle(n, r * 0.31, escuro)
	ci.draw_line(polegar_a, polegar_b, escuro, r * 0.7)
	ci.draw_circle(polegar_a, r * 0.35, escuro)
	ci.draw_circle(polegar_b, r * 0.35, escuro)
	# Passo 2: formas coloridas.
	ci.draw_rect(corpo, cor)
	for n in nos:
		ci.draw_circle(n, r * 0.23, cor)
	# Vincos entre os dedos.
	for i in range(1, 4):
		var x := -0.62 + i * 0.415 - 0.2075
		ci.draw_line(c + Vector2(x, -0.25) * r, c + Vector2(x, 0.3) * r, escuro, r * 0.07)
	# Polegar por cima dos dedos.
	ci.draw_line(polegar_a, polegar_b, escuro, r * 0.62)
	ci.draw_circle(polegar_a, r * 0.31, escuro)
	ci.draw_circle(polegar_b, r * 0.31, escuro)
	ci.draw_line(polegar_a, polegar_b, cor, r * 0.5)
	ci.draw_circle(polegar_a, r * 0.25, cor)
	ci.draw_circle(polegar_b, r * 0.25, cor)
	# Faíscas de impacto à direita.
	for i in 3:
		var ang := deg_to_rad(-40.0 + i * 40.0)
		var dir := Vector2(1, 0).rotated(ang)
		ci.draw_line(c + Vector2(0.95, 0) * r + dir * r * 0.2, c + Vector2(0.95, 0) * r + dir * r * 0.55, cor, r * 0.1)


func _icone_rastro(ci: Control, c: Vector2, r: float, cor: Color) -> void:
	# Três chevrons correndo para a direita, cada um mais apagado que o anterior.
	for i in 3:
		var x := 0.45 - i * 0.55
		var a := 1.0 - i * 0.3
		var pts := PackedVector2Array([c + Vector2(x - 0.35, -0.7) * r, c + Vector2(x + 0.1, 0.0) * r, c + Vector2(x - 0.35, 0.7) * r])
		ci.draw_polyline(pts, Color(CONTORNO, a), r * 0.36, true)
		ci.draw_polyline(pts, Color(cor, a), r * 0.2, true)


func _icone_seta(ci: Control, c: Vector2, r: float, cor: Color, giro := 0.0) -> void:
	var forma := [Vector2(0, -0.95), Vector2(0.9, 0.0), Vector2(0.4, 0.0), Vector2(0.4, 0.9),
		Vector2(-0.4, 0.9), Vector2(-0.4, 0.0), Vector2(-0.9, 0.0)]
	var pts := PackedVector2Array()
	for v in forma:
		pts.append(c + (v as Vector2).rotated(giro) * r)
	ci.draw_colored_polygon(pts, cor)
	var fechado := pts.duplicate()
	fechado.append(pts[0])
	ci.draw_polyline(fechado, CONTORNO, r * 0.12, true)


## Fração da recarga (1.0 = pronto) para mostrar o anel nos botões.
func _fracao_recarga(acao: String) -> float:
	match acao:
		"ataque_basico":
			var total := lutador.recarga_basico()
			return 1.0 if total <= 0.0 else clampf(1.0 - lutador.basico_recarga / total, 0.0, 1.0)
		"esquivar":
			var total := lutador.recarga_esquiva()
			return 1.0 if total <= 0.0 else clampf(1.0 - lutador.esquiva_recarga / total, 0.0, 1.0)
		"cantico":
			return 1.0 if lutador.cargas_cantico > 0 else 0.0
	return 1.0
