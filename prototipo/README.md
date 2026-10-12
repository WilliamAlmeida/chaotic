# Ecos de Aetheris: protótipo de arena 3D (Godot 4)

Protótipo jogável do conceito em [`../docs/conceito-jogo-3d.md`](../docs/conceito-jogo-3d.md): um jogo de **ação 3D** em que as **cartas são o loadout**, como no anime *Chaotic*. Elas definem o monstro que você controla, o equipamento que ele carrega, o cenário da luta, o Cântico (magia) e os golpes que aparecem na sua mão durante o combate.

> Nomes, monstros e textos são **próprios** (placeholders). Nada usa marca, nomes ou arte de *Chaotic*.

| Loadout | Luta | Cântico (mini-ritmo) |
|---|---|---|
| ![loadout](capturas/loadout.png) | ![luta](capturas/luta.png) | ![cantico](capturas/cantico.png) |

## Como rodar

1. Instale o **Godot 4.3** ou mais novo (versão padrão, não precisa da versão .NET): <https://godotengine.org/download>
2. Abra o Godot → **Importar** → selecione `prototipo/project.godot`.
3. Aperte **F5** (ou o botão ▶).

Toda a arte é feita com formas primitivas geradas em código. Não há assets para baixar.

## Controles

| Ação | Teclado/mouse | Controle |
|---|---|---|
| Mover | WASD / setas | analógico esquerdo / D-pad |
| Câmera | mouse (Tab trava/destrava no inimigo) | R3 trava |
| Pular | Espaço | A |
| Esquivar (fica invulnerável por um instante) | Shift | B |
| Golpe básico | clique esquerdo / J | X |
| Cartas de ataque da mão | 1, 2, 3 | LB, Y, RB |
| Cântico | Q, depois a sequência com WASD | RT, depois D-pad |
| Soltar o mouse | Esc | |
| Esconder ajuda | F1 | |

## O que está implementado

| Conceito | Como funciona no protótipo |
|---|---|
| **Carta de Monstro** | 3 monstros (Brasário: ágil; Rochedo: forte; Ondina: mística) com Agilidade, Força, Mente, Ânimo, Energia, elementos, cargas de Cântico e passiva |
| **Atributos na ação** | Agilidade → velocidade e recarga da esquiva · Força → dano do golpe básico e resistência a empurrões · Mente → recarga das cartas e força dos Cânticos · Ânimo → chance de crítico e resistência a atordoamento |
| **Deck de ataques** | 6 a 10 cartas com **orçamento de 20 pontos** (regra do card game) e **3 cartas na mão**. A carta usada recarrega e compra a próxima; quando o deck acaba, o descarte é embaralhado |
| **Arquétipos de golpe** | Projétil, Área, Investida e Salto, cada um com animação, aviso no chão e cor do elemento |
| **Desafio / Teste / Falha** | Cada carta tem uma condição que compara atributos. A HUD mostra **ATIVA** (verde) ou **inativa** contra o inimigo atual |
| **Elementos** | Brasa, Tempestade, Pedra e Maré. O bônus elemental só vale se o monstro tem o elemento |
| **Carta de Equipamento** | Espada, escudo ou amuleto: bônus de atributo e/ou elemento. Aparece no modelo, **oculto até o início da luta** |
| **Carta de Cântico** | Cura ou dano com atordoamento. Para conjurar, aperte a sequência de 4 teclas a tempo; levar dano ou errar a tecla interrompe e gasta a carga |
| **Carta de Local** | 3 arenas (Caldeira Vulcânica com lava, Bosque das Marés com água que deixa lento, Planalto dos Ventos com rajadas). Cada uma tem bônus elemental e **iniciativa**: quem vence começa com a mão pronta e o outro espera 2,5s. Pode ser sorteada |
| **IA** | Mantém a distância certa para as cartas da mão, prefere cartas com condição ativa, esquiva projéteis, interrompe Cânticos e evita lava |
| **Partida** | Intro (Local → Iniciativa → Equipamentos revelados → LUTEM!), duelo 1x1, limite de 3 minutos, tela de resultado |

## Criar ou alterar cartas

Edite os JSON em `data/`. Não precisa mexer em código.

- `monstros.json`: atributos, energia, elementos, cor e forma (`agil`, `robusto`, `mistico`)
- `ataques.json`: `custo`, `arquetipo` (`projetil`/`area`/`investida`/`salto`), `dano_base`, `bonus_elemento` e uma `condicao`:
  ```json
  "condicao": {"tipo": "desafio", "atributo": "agilidade", "margem": 1,
               "efeito": {"tipo": "atordoar", "valor": 0.6}}
  ```
  - `tipo` da condição: `desafio`, `teste` (usa `valor`) ou `falha` (usa `valor`)
  - `efeito`: `dano_extra`, `atordoar`, `empurrar`, `cura` ou `roubar_carga`
- `equipamentos.json`: `modelo` (`espada`/`escudo`/`amuleto`), `socket`, `passivo`, `elemento`
- `canticos.json`: `tipo` (`cura`/`dano`), `valor`, `atordoar`, `alcance`
- `locais.json`: cores do céu e do chão, `iniciativa`, `modificadores`, `obstaculos` `[x, z, raio, altura]`, `perigos` (`lava`/`agua`) e `vento`

## Simular partidas (balanceamento)

O jogo pode rodar partidas **IA contra IA** sem abrir janela e imprimir uma tabela de vitórias:

```bash
godot --headless --path prototipo --fixed-fps 60 -- --simular=40
```

`--autoteste` roda só uma partida. No modo `--headless` o Godot imprime muitos `Parameter "m" is null` (mesh_storage.h). É ruído do renderizador vazio usado sem janela e pode ser ignorado.

Resultado atual com 40 partidas IA x IA: Rochedo 68%, Ondina 48%, Brasário 36%, duração média de 38s. Os números variam a cada rodada. Contra um jogador humano, a mobilidade do Brasário pesa mais do que pesa para a IA.

## Estrutura

```
prototipo/
├── project.godot        # Godot 4.3, renderizador Compatibility (roda em PCs mais fracos e na web)
├── main.tscn            # cena raiz; todo o resto é montado por código
├── data/*.json          # as cartas
└── scripts/
    ├── dados.gd         # autoload: carrega os JSON, deck sugerido, IA de loadout, controles
    ├── main.gd          # troca loadout ↔ batalha; modo de simulação
    ├── loadout.gd       # tela de montagem (monstro, equipamento, cântico, local, deck)
    ├── batalha.gd       # arena, perigos, intro, iniciativa, fim da partida
    ├── lutador.gd       # o monstro: atributos, ações, cântico, modelo procedural
    ├── mao_cartas.gd    # deck/mão de 3/descarte/recarga
    ├── combate.gd       # regras de dano, Desafio/Teste/Falha, efeitos
    ├── projetil.gd      # projéteis com leve perseguição
    ├── efeitos.gd       # explosões e avisos no chão
    ├── camera_orbita.gd # câmera em 3ª pessoa com trava no inimigo
    ├── controle_jogador.gd
    ├── controle_ia.gd
    └── hud.gd           # barras, cartas, mini-ritmo, banners, resultado
```

## Exportar

Em **Projeto → Exportar**, adicione `*.json` em *Filtros para exportar arquivos que não são recursos*. Sem isso, as cartas não entram no executável.

## Próximos passos sugeridos

1. Testar a sensação de jogo e ajustar números (recarga das cartas, velocidade, dano).
2. Trocar os modelos primitivos por `.glb` com animações (os pontos de encaixe `mao_dir`, `mao_esq` e `peito` já existem).
3. Tabuleiro tático 3x3 entre as lutas, com o dano que sobra passando para a luta seguinte.
4. Coleção e exploração: escanear monstros, locais e itens no mundo para ganhar as cartas.
5. Multiplayer online.
