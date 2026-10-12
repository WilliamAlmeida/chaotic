# Prompts usados no Codex

Os dois prompts abaixo geraram [`gui-conceito.md`](gui-conceito.md) (imagens em `gui-conceito/`) e [`design-teralume.md`](design-teralume.md), com os JSON em `prototipo/data/`. Reutilize-os para gerar mais conteúdo no mesmo formato.

## 1. Conceito de GUI

```
Você é diretor de arte de UI de games. Crie o CONCEITO VISUAL da interface de um jogo de ação 3D feito em Godot 4, inspirado na estética de anime de card game dos anos 2000 (cartas com moldura colorida por facção, ícones de atributos, símbolo octogonal de "magia musical"). NÃO use nomes, logos ou personagens de franquias existentes.

Contexto do jogo: as cartas formam o loadout. Antes da luta o jogador escolhe 4 cartas (Monstro, Equipamento, Cântico = magia musical, Local = arena) e monta um deck de 6–10 cartas de Ataque (orçamento de 20 pontos). Na luta 1x1 em 3D, ele tem 3 cartas de Ataque na mão (teclas 1, 2, 3), que recarregam após o uso.

Facções (cor principal / escura / clara / marca):
- Clã das Cinzas: #d9452b / #5a1410 / #ffb38a / chamas
- Reino das Marés: #2f7fe0 / #0e2a5c / #9fd4ff / onda
- Colmeia de Rocha: #a8743c / #3d2410 / #f0c890 / favo hexagonal
- Nômades da Areia: #e7b928 / #5a4208 / #fff0a0 / sol
Atributos: Agilidade, Força, Mente, Ânimo. Elementos: Brasa, Tempestade, Pedra, Maré.

Entregue:
1. Mockup 1920x1080 da TELA DE LOADOUT: 4 cartas retrato lado a lado com setas < > para trocar e o anel octogonal colorido da facção embaixo de cada uma; à direita, a grade do deck de ataques (cartas paisagem), com o orçamento "14/20" e o botão LUTAR.
2. Mockup 1920x1080 do HUD DA LUTA: barras de Energia dos dois lados, cronômetro, 3 cartas de ataque embaixo (uma recarregando), cargas de Cântico como anéis octogonais pequenos, e o painel do mini-ritmo do Cântico (sequência W A S D).
3. Folha de componentes: moldura da carta retrato (Monstro, Equipamento, Cântico, Local) e paisagem (Ataque), nos estados normal, selecionada, desabilitada e recarregando.
4. Folha de ícones: 4 atributos, 4 elementos (aceso e apagado), 4 símbolos de Cântico (anel octogonal com a marca de cada facção) e o emblema de cada facção.
5. Especificação em Markdown (docs/gui-conceito.md): paleta em hex, fontes sugeridas (gratuitas, Google Fonts), medidas em px de cada componente, margens, cantos, espessuras de borda, layout das áreas da carta (faixa de nome, arte, painel de atributos, caixa de texto, rodapé), estados e animações (hover, seleção, recarga, revelação do equipamento).

Pense em implementação no Godot: painéis que funcionem em 9-slice (StyleBoxTexture), ícones vetoriais simples (SVG) e cores sólidas com contorno escuro, num visual de anime/cel-shading.
```

## 2. Design do jogo (conteúdo em JSON)

```
Você é game designer. Expanda o conteúdo de um jogo de ação 3D em que cartas são o loadout (estilo anime de card game, com nomes 100% originais, sem referências a franquias existentes). O protótipo já existe em Godot 4 e lê os dados de arquivos JSON. Respeite EXATAMENTE os formatos abaixo.

Regras atuais:
- Atributos 0–100: agilidade (velocidade/esquiva), forca (dano básico/resiste a empurrão), mente (recarga das cartas/força do Cântico), animo (crítico/resiste a atordoamento).
- Energia (vida) entre 240 e 320. Elementos: brasa, tempestade, pedra, mare.
- Ataque: custo 0–4 (deck de 6–10 cartas, orçamento de 20), arquetipo projetil|area|investida|salto, dano_base 4–13, bonus_elemento (só vale se o monstro tem o elemento), condicao opcional:
  {"tipo":"desafio","atributo":X,"margem":N} | {"tipo":"teste","atributo":X,"valor":N} | {"tipo":"falha","atributo":X,"valor":N}
  com efeito {"tipo": dano_extra|atordoar|empurrar|cura|roubar_carga, "valor": N}.

Formatos: veja prototipo/data/*.json (monstros, ataques, equipamentos, canticos, locais).

Entregue:
1. Lore curta (1 página): o mundo-fonte, a "Rede" onde os jogadores duelam, as 4 facções e uma 5ª facção invasora para uma futura expansão.
2. 12 monstros (3 por facção) com papéis diferentes, 24 ataques, 8 equipamentos, 6 cânticos e 6 locais, em blocos JSON separados por arquivo.
3. Para cada monstro, um prompt de concept art e uma descrição de silhueta montável com formas simples.
4. Tabela de balanceamento e combinações fortes.
5. Ideias para as próximas camadas (tabuleiro tático, exploração com escaneamento, progressão por arenas).
```

## 3. Próximo pedido sugerido: arte das cartas

As cartas aceitam arte final sem mudar código: salve `prototipo/arte/cartas/<id>.png` (ex.: `cindravil.png`, `bola_fogo.png`, `caldeira_rubra.png`). Use os prompts de concept art de `design-teralume.md`, com fundo e proporção adequados à área de arte: retrato 252x192, ataque 216x118.
