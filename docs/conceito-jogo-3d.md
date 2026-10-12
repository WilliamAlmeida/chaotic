# Conceito: jogo de ação 3D "no estilo Chaotic"

> Premissa: **não é um card game.** É um jogo de **ação 3D** em que as **cartas são o loadout**. Elas definem qual monstro você controla, que arma ou equipamento ele usa, em que cenário a luta acontece e quais golpes ele tem, como no anime.
> Base de pesquisa: [`pesquisa-chaotic.md`](pesquisa-chaotic.md).

---

## 1. O que o anime mostra (e vamos reproduzir)

| No anime | No nosso jogo |
|---|---|
| O jogador entra numa **Drome** e "vira" a criatura: é uma realidade virtual extrema, com sentidos amplificados | Você **controla o monstro em 3D**, em terceira pessoa |
| O **local** sorteado vira o cenário da luta | A **carta de Local** escolhe a **arena 3D** e os modificadores dela |
| O **Battlegear** é revelado no começo da luta e aparece na criatura | A **carta de Equipamento** é uma arma ou acessório visível no modelo, revelada só quando a luta começa |
| Os **ataques** são golpes com nome, gritados e executados | As **cartas de Ataque** são as habilidades ativas da luta |
| O **Mugic** é uma música mágica que gasta "contadores" | A **carta de Cântico** é uma habilidade especial com cargas limitadas por partida |
| O **tabuleiro** escolhe quem enfrenta quem entre as lutas | Camada **tática opcional** entre as lutas (time de 3) |
| **Perim**: ir ao mundo real e **escanear** criaturas, locais e itens | **Exploração 3D** para **conseguir cartas** escaneando |
| Ganhar **7 lutas numa Drome** desbloqueia o desafio ao **Codemaster** | Progressão por **arenas e chefes** |

---

## 2. Loop principal do jogo

```
 ┌──────────── EXPLORAÇÃO (mundo-fonte) ─────────────┐
 │ andar pelo mundo 3D, encontrar monstros, locais e │
 │ itens → ESCANEAR → ganha a carta                  │
 └───────────────┬───────────────────────────────────┘
                 ▼
 ┌──────────── HUB (a "Rede") ───────────────────────┐
 │ montar o deck (loadout) · ranking · loja · social │
 └───────────────┬───────────────────────────────────┘
                 ▼
 ┌──────────── ARENA (partida) ──────────────────────┐
 │ [opcional] tabuleiro tático 3v3 → escolhe o duelo │
 │ carta de Local → carrega a arena 3D               │
 │ DUELO 3D EM TEMPO REAL 1v1                        │
 │ vitória → XP, ranking, recompensas                │
 └───────────────┬───────────────────────────────────┘
                 └──► volta para explorar e buscar cartas melhores
```

A exploração gera **cartas novas**, as cartas mudam **como você luta**, e lutar abre **novas regiões e arenas**.

---

## 3. Papel de cada tipo de carta

### 3.1 Carta de Monstro (o "personagem jogável")
Define o modelo 3D, as animações, os atributos e a identidade.

| Atributo (inspirado nas 4 disciplinas) | Efeito na ação 3D |
|---|---|
| **Agilidade** (≈ Speed) | velocidade de movimento, recarga do *dash*, quem age primeiro no início |
| **Força** (≈ Power) | dano físico, *knockback*, resistência a ser interrompido (*poise*) |
| **Mente** (≈ Wisdom) | recarga das habilidades, força dos Cânticos, dano mágico |
| **Ânimo** (≈ Courage) | resistência a atordoamento e medo, chance de crítico, bônus quando está com pouca vida |
| **Energia** | vida (HP) |
| **Elementos** (0–4) | liberam o **bônus elemental** dos golpes |
| **Cargas de Cântico** (0–3) | quantos Cânticos podem ser usados na partida |
| **Habilidade passiva** | ex.: invisibilidade ao ficar parado, regeneração perto de água |

Cada monstro tem um **ataque básico** sem custo, para o jogador nunca ficar sem opção, além de **esquiva**, **defesa** e **pulo**.

### 3.2 Cartas de Ataque: o "moveset rotativo" (mecânica central)
É aqui que o estilo Chaotic aparece no jogo de ação:
- O jogador monta um **deck de 20 Ataques** com **orçamento de 20 pontos** (regra do TCG). Golpes fortes custam mais.
- Na luta, ele tem **3 golpes na mão** (3 botões de habilidade, como no TCG, onde a mão é de 3).
- Ao usar um golpe, ele sai da mão e **o próximo do deck entra** depois de um pequeno tempo de recarga.
- Cada golpe tem uma **animação "arquétipo"** (investida, projétil, área, pulo, agarrão…), um **dano base**, um **bônus por elemento** e um **efeito condicional** inspirado no TCG:
  - **Desafio**: compara um atributo entre os dois monstros. Ex.: "se sua Agilidade for maior que a do alvo, atordoa 1s".
  - **Teste**: exige um mínimo do próprio monstro. Ex.: "se Força ≥ 60, +15 de dano".
  - **Falha**: depende de um atributo baixo do alvo. Ex.: "se a Mente do alvo for < 40, ele perde 1 carga de Cântico".
  - A HUD mostra um **ícone aceso ou apagado** em cada golpe da mão, indicando se a condição vale contra aquele inimigo.

Isso cria decisões táticas em tempo real: *"guardo o golpe caro para quando ele estiver encurralado ou uso agora para liberar outro?"*

### 3.3 Carta de Equipamento (Battlegear)
- É uma arma ou acessório **visível no modelo** (espada, escudo, amuleto, armadura).
- Fica **oculta até a luta começar**, como no TCG. O oponente só descobre ao entrar na arena.
- Pode ser passiva (+10 de Força, ganha o elemento Brasa) ou ativa (um botão extra com recarga longa).

### 3.4 Carta de Cântico (Mugic)
- É uma "magia musical" com **cargas limitadas** (usa as cargas do monstro).
- Ideia de identidade: para conjurar, o jogador executa uma **sequência rápida de notas/botões** (um mini‑ritmo de 1–2 s, vulnerável a interrupção). Funciona como a "música" do anime e dá risco e recompensa.
- Exemplos: cura, purificar efeitos, roubar uma carta da mão do inimigo, trocar o cenário.

### 3.5 Carta de Local (cenário)
- Define **qual arena 3D** carrega e os **modificadores** dela:
  - **Iniciativa**: quem começa com vantagem. Ex.: "o monstro com maior Mente começa com o primeiro golpe já carregado".
  - **Bônus elemental**: num vulcão, golpes de Brasa causam +X.
  - **Perigos de cenário**: lava, correntes de vento, plataformas que caem.
- Cada jogador leva um **deck de Locais**, e o local da luta é **sorteado** dele (do atacante ou alternado). O **cenário fica imprevisível** sem perder a estratégia de montar o deck.

---

## 4. Fluxo de uma partida

1. **Montagem** (fora da partida): time de monstros + 1 equipamento por monstro + Cânticos + deck de 20 ataques + deck de Locais.
2. **Tabuleiro tático** (opcional, modo "Drome"): os monstros ficam numa pirâmide e se movem por turnos. Entrar na casa de um inimigo **inicia um duelo**. O **dano que sobra fica para a próxima luta**.
3. **Revelação do Local** → transição cinematográfica → carrega a arena.
4. **Revelação dos Equipamentos** (animação curta mostrando a arma aparecendo no monstro).
5. **Duelo 3D 1v1** em tempo real até a Energia de um chegar a 0.
6. Volta ao tabuleiro. Vence quem **eliminar todos os monstros** adversários.

**Modo rápido:** só o duelo 1v1 (escolhe monstro, equipamento, ataques e local).

---

## 5. Exploração e "escaneamento" (Perim)

- **Mundo dividido em regiões**, cada uma ligada a uma facção ou elemento (floresta, deserto, subterrâneo, oceano…).
- **Escanear um monstro**: chegar perto sem ser notado (furtividade) ou enfraquecê‑lo e então manter o *scanner* apontado por alguns segundos. Isso gera a carta do monstro. Se ele perceber, ataca de verdade.
- **Escanear um local**: chegar a pontos marcados no mapa (mirantes, ruínas). Isso libera a **arena** como carta.
- **Escanear itens e cânticos**: puzzles, baús, NPCs e missões das facções.
- Cartas repetidas podem virar **variações** (atributos levemente diferentes), um aceno ao fato de cada scan ser único no anime.

---

## 6. Referências de jogos para estudar

| Jogo | O que aproveitar |
|---|---|
| *Kingdom Hearts: Chain of Memories / Re:CoM* | Ação 3D em tempo real com **golpes vindos de um deck de cartas** (é o mais próximo do nosso núcleo) |
| *Phantom Dust* | Arena 3D em que as habilidades **são "compradas" durante a luta** a partir de um deck |
| *Mega Man Battle Network / Star Force* | Pasta de chips (deck) + escolha de golpes em tempo real |
| *Lost Kingdoms* (GameCube) | Cartas que invocam criaturas e golpes em 3D |
| *Pokémon Legends: Arceus* | Exploração 3D e captura com furtividade (base do "escaneamento") |
| *Digimon / Monster Rancher* | Coleção e evolução de monstros com atributos |

---

## 7. Produção: como tornar viável

- **O maior custo é arte e animação.** Para escalar:
  - Agrupar monstros em **esqueletos compartilhados** (bípede, quadrúpede, voador, serpente). Animações são reaproveitadas entre monstros do mesmo esqueleto.
  - As cartas de Ataque usam **arquétipos de animação + VFX por elemento**. Um único "projétil" vira bola de fogo, rajada de vento, pedra ou jato d'água. Assim, 4 arquétipos × 4 elementos já rendem 16 golpes visualmente distintos.
  - Equipamentos como **sockets** no esqueleto (mão, costas, cabeça).
- **Motor:** **Godot 4** (gratuito, leve, bom para indie e prototipagem) ou **Unity** (mais assets prontos e bom para mobile). Unreal só se o foco for visual de ponta.
- **Multiplayer online** (PvP) é caro: exige servidor autoritativo ou *rollback*. Recomendo **começar com PvE contra IA** e deixar o PvP para depois do protótipo.
- **Dados das cartas em JSON/Resources**, separados do código, para balancear sem recompilar.

---

## 8. MVP: primeiro protótipo jogável

**Meta:** provar que "lutar com um moveset que vem de cartas" é divertido.

1. **1 arena** (carta de Local) com 1 modificador elemental.
2. **2 monstros** (esqueleto bípede) com atributos diferentes (um rápido, um forte).
3. Movimento 3D, câmera, ataque básico, esquiva.
4. **Deck de 8–10 Ataques com mão de 3** e reposição automática; 1 condição de **Desafio** e 1 de **Teste** funcionando com ícone na HUD.
5. **1 Equipamento** revelado no início.
6. **1 Cântico** com o mini‑ritmo.
7. **IA simples** como oponente.
8. Tela de loadout escolhendo monstro, equipamento, local e ataques.

> ✅ **Protótipo implementado em Godot 4:** veja [`../prototipo/README.md`](../prototipo/README.md).

**Depois do MVP:** mais locais e elementos → tabuleiro 3v3 → deckbuilder com orçamento → exploração e escaneamento → hub e progressão por arenas e chefes → PvP.

---

## 9. Esboço de dados (ação 3D)

```jsonc
// Monstro
{
  "id": "mon_001", "nome": "...", "faccao": "...", "esqueleto": "bipede",
  "atributos": { "agilidade": 75, "forca": 45, "mente": 30, "animo": 60 },
  "energia": 120, "elementos": ["brasa"], "cargas_cantico": 1,
  "passiva": { "tipo": "regenera_perto_de", "elemento": "mare", "valor": 2 },
  "modelo": "res://monstros/mon_001.glb"
}
// Ataque (habilidade)
{
  "id": "atk_010", "nome": "...", "custo": 3, "arquetipo": "projetil",
  "dano_base": 10, "bonus_elemento": { "brasa": 10 }, "recarga_s": 1.5,
  "condicao": { "tipo": "desafio", "atributo": "agilidade", "efeito": { "atordoar_s": 1.0 } },
  "vfx": "fogo_projetil"
}
// Equipamento
{ "id": "eq_004", "nome": "...", "socket": "mao_direita",
  "passivo": { "forca": 10 }, "ativo": null, "modelo": "res://equip/eq_004.glb" }
// Local (arena)
{ "id": "loc_002", "nome": "...", "cena": "res://arenas/vulcao.tscn",
  "iniciativa": { "atributo": "mente", "vantagem": "primeiro_golpe_carregado" },
  "modificadores": [{ "elemento": "brasa", "dano_bonus": 5 }], "perigos": ["lava"] }
```

---

## 10. Lembrete de propriedade intelectual
Chaotic voltou ao mercado em 2026 (Panini). Use **nomes, facções, arte e textos próprios**. O que pode ser aproveitado com segurança é a **estrutura de ideias e mecânicas**: cartas como loadout, ataques de um deck com orçamento, atributos testados em golpes, local sorteado, equipamento oculto e escaneamento.

### Fontes adicionais deste documento
- [BattleDromes — Chaotic Wiki](https://chaotic.fandom.com/wiki/BattleDromes)
- [Beta Drome — Chaotic Wiki](https://chaotic.fandom.com/wiki/Beta_Drome)
- [Chaotic (Western Animation) — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/WesternAnimation/Chaotic)
- [Gonzo Library — Chaotic: The Trading Card Game Cartoon Without the Cards](https://gonzolibrary.wordpress.com/2019/11/15/chaotic-the-trading-card-game-cartoon-without-the-cards/)
- [Chaotic TCG Downloadable Rules (PDF)](http://ccggamez.com/files/chaotic/Chaotic.pdf)
