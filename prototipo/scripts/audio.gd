extends Node
## Autoload "Audio": efeitos sonoros e música gerados em código (sem arquivos de som).
##
## Uso:  Audio.tocar("golpe")            efeito curto
##       Audio.tocar("golpe", -6.0, 1.2) com volume (dB) e afinação
##       Audio.musica("luta")            troca a música de fundo (loop)
##       Audio.parar_musica()
## Nomes desconhecidos são ignorados em silêncio, então qualquer tela pode pedir um som
## antes de ele existir. Os sons são sintetizados uma vez e guardados em cache.

const TAXA := 22050
const VOZES := 12

var _cache: Dictionary = {}
var _vozes: Array[AudioStreamPlayer] = []
var _proxima_voz := 0
var _musica: AudioStreamPlayer
var _musica_nome := ""


func _ready() -> void:
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_vozes.append(p)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)


func tocar(nome: String, volume_db := 0.0, afinacao := 1.0) -> void:
	var stream := _obter(nome)
	if stream == null:
		return
	var p := _vozes[_proxima_voz]
	_proxima_voz = (_proxima_voz + 1) % VOZES
	p.stream = stream
	p.volume_db = volume_db + linear_to_db(clampf(float(Jogo.config.get("volume_efeitos", 0.8)), 0.0001, 1.0))
	p.pitch_scale = afinacao
	p.play()


func musica(nome: String) -> void:
	if nome == _musica_nome and _musica.playing:
		return
	var stream := _obter("musica_" + nome)
	if stream == null:
		parar_musica()
		return
	_musica_nome = nome
	_musica.stream = stream
	_musica.volume_db = linear_to_db(clampf(float(Jogo.config.get("volume_musica", 0.6)), 0.0001, 1.0))
	_musica.play()


func parar_musica() -> void:
	_musica_nome = ""
	_musica.stop()


func atualizar_volumes() -> void:
	if _musica.playing:
		_musica.volume_db = linear_to_db(clampf(float(Jogo.config.get("volume_musica", 0.6)), 0.0001, 1.0))


# ---------------------------------------------------------------------
# Síntese
# ---------------------------------------------------------------------

func _obter(nome: String) -> AudioStreamWAV:
	if _cache.has(nome):
		return _cache[nome]
	var amostras := _sintetizar(nome)
	if amostras.is_empty():
		_cache[nome] = null
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TAXA
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(amostras.size() * 2)
	for i in amostras.size():
		var v := int(clampf(amostras[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	if nome.begins_with("musica_"):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = amostras.size()
	_cache[nome] = stream
	return stream


## Devolve as amostras (-1..1) de um som pelo nome; vazio se o nome não existe.
func _sintetizar(nome: String) -> PackedFloat32Array:
	match nome:
		"golpe":
			return _ruido(0.12, 0.9, 0.012, 900.0)
		"golpe_forte":
			return _mistura(_ruido(0.2, 1.0, 0.02, 500.0), _tom(0.2, 90.0, 0.8, 0.0, 0.18, 0.5))
		"esquiva":
			return _varredura(0.18, 300.0, 1200.0, 0.4)
		"salto":
			return _varredura(0.22, 220.0, 660.0, 0.5)
		"projetil":
			return _varredura(0.25, 900.0, 300.0, 0.35)
		"explosao":
			return _ruido(0.45, 1.0, 0.03, 250.0)
		"carta":
			return _mistura(_tom(0.12, 880.0, 0.5, 0.005, 0.1), _tom(0.12, 1320.0, 0.3, 0.03, 0.08))
		"cantico_nota":
			return _tom(0.25, 660.0, 0.6, 0.01, 0.2)
		"cantico_ok":
			return _acorde(0.6, [523.0, 659.0, 784.0, 1046.0], 0.5)
		"cantico_falha":
			return _varredura(0.4, 400.0, 150.0, 0.5)
		"cura":
			return _acorde(0.5, [659.0, 880.0, 1318.0], 0.4)
		"escudo":
			return _acorde(0.4, [440.0, 554.0, 659.0], 0.4)
		"dano":
			return _mistura(_ruido(0.1, 0.7, 0.01, 1200.0), _tom(0.1, 160.0, 0.5, 0.0, 0.09, 0.4))
		"vitoria":
			return _melodia([[523.0, 0.15], [659.0, 0.15], [784.0, 0.15], [1046.0, 0.45]], 0.55)
		"derrota":
			return _melodia([[392.0, 0.25], [349.0, 0.25], [311.0, 0.25], [262.0, 0.6]], 0.5)
		"clique":
			return _tom(0.06, 1200.0, 0.4, 0.002, 0.05)
		"confirmar":
			return _melodia([[784.0, 0.08], [1046.0, 0.16]], 0.45)
		"voltar":
			return _melodia([[659.0, 0.08], [523.0, 0.14]], 0.4)
		"aviso":
			return _melodia([[880.0, 0.1], [880.0, 0.1]], 0.5)
		"vento":
			return _ruido(0.9, 0.35, 0.3, 180.0)
		"quebra":
			return _mistura(_ruido(0.3, 0.9, 0.02, 700.0), _tom(0.3, 120.0, 0.5, 0.0, 0.25, 0.6))
		"estrela":
			return _melodia([[1046.0, 0.08], [1318.0, 0.08], [1568.0, 0.2]], 0.45)
		"musica_menu":
			return _musica_simples([262, 330, 392, 330, 294, 349, 440, 349, 330, 392, 494, 392, 262, 330, 392, 523], 0.42, 0.2)
		"musica_luta":
			return _musica_simples([220, 220, 330, 220, 262, 262, 392, 262, 196, 196, 294, 196, 220, 262, 330, 440], 0.22, 0.28)
		"musica_vitoria":
			return _musica_simples([392, 523, 659, 784, 659, 523, 392, 523], 0.3, 0.25)
	return PackedFloat32Array()


func _tom(duracao: float, freq: float, volume: float, ataque: float, decaimento: float, ruido := 0.0) -> PackedFloat32Array:
	var n := int(duracao * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		var env := minf(1.0, t / maxf(ataque, 0.0005)) * exp(-t / maxf(decaimento, 0.001))
		fase += TAU * freq / TAXA
		var v := sin(fase) * 0.7 + sin(fase * 2.0) * 0.2 + sin(fase * 3.0) * 0.1
		if ruido > 0.0:
			v = lerpf(v, randf_range(-1.0, 1.0), ruido)
		saida[i] = v * env * volume
	return saida


func _ruido(duracao: float, volume: float, ataque: float, corte: float) -> PackedFloat32Array:
	var n := int(duracao * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var filtro := 0.0
	var alfa := clampf(corte / TAXA * TAU, 0.01, 1.0)
	for i in n:
		var t := float(i) / TAXA
		var env := minf(1.0, t / maxf(ataque, 0.0005)) * exp(-t / (duracao * 0.3))
		filtro += (randf_range(-1.0, 1.0) - filtro) * alfa
		saida[i] = filtro * env * volume * 2.0
	return saida


func _varredura(duracao: float, f0: float, f1: float, volume: float) -> PackedFloat32Array:
	var n := int(duracao * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var fase := 0.0
	for i in n:
		var k := float(i) / n
		var freq := lerpf(f0, f1, k)
		fase += TAU * freq / TAXA
		var env := sin(k * PI)
		saida[i] = (sin(fase) * 0.8 + sin(fase * 2.0) * 0.2) * env * volume
	return saida


func _acorde(duracao: float, freqs: Array, volume: float) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	for f in freqs:
		saida = _mistura(saida, _tom(duracao, float(f), volume / freqs.size(), 0.01, duracao * 0.5))
	return saida


func _melodia(notas: Array, volume: float) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	for nota in notas:
		saida.append_array(_tom(float(nota[1]), float(nota[0]), volume, 0.005, float(nota[1]) * 0.9))
	return saida


## Loop musical simples: baixo + melodia em ondas suaves, com batida leve.
func _musica_simples(notas: Array, passo: float, volume: float) -> PackedFloat32Array:
	var n := int(notas.size() * passo * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var fase_m := 0.0
	var fase_b := 0.0
	var por_nota := int(passo * TAXA)
	for i in n:
		var idx := mini(i / por_nota, notas.size() - 1)
		var dentro := float(i % por_nota) / por_nota
		var freq := float(notas[idx])
		fase_m += TAU * freq / TAXA
		fase_b += TAU * (freq / 2.0) / TAXA
		var env := (1.0 - dentro) * 0.6 + 0.4
		var batida := exp(-dentro * 12.0) * 0.25 if idx % 2 == 0 else 0.0
		var v := sin(fase_m) * 0.45 * env + sin(fase_b) * 0.3 + (randf_range(-1.0, 1.0) * batida)
		saida[i] = v * volume
	return saida


func _mistura(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var saida := PackedFloat32Array()
	saida.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		saida[i] = v
	return saida
