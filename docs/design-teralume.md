# Design do jogo: Teralume e a Rede dos Ecos

Conteúdo gerado no Codex a partir do prompt de game design. Os JSON estão em `prototipo/data/` e foram adaptados assim:

- cada monstro ganhou um campo `pecas`, a lista de partes da silhueta tirada da coluna "Construção da silhueta";
- cada passiva ganhou um `nome` com acentos;
- foi criado `faccoes.json`.

As 12 passivas estão implementadas em `prototipo/scripts/lutador.gd`.


## 1. Lore

Teralume é um mundo-fonte formado por regiões onde matéria, memória e energia elemental coexistem. Seus habitantes descobriram que criaturas excepcionalmente marcadas pelos quatro elementos — brasa, tempestade, pedra e maré — deixam para trás uma assinatura chamada Eco. Um Eco não é a alma da criatura nem uma cópia perfeita: é um registro de suas capacidades, instintos e afinidades.

Séculos depois, estudiosos desenvolveram a Rede dos Ecos, uma infraestrutura distribuída de arenas capazes de materializar temporariamente essas assinaturas. Na Rede, duelistas não transportam exércitos reais. Eles configuram um loadout de cartas que determina qual Eco será manifestado, qual equipamento ele receberá, qual Cântico poderá invocar e em qual ambiente o confronto ocorrerá.

As cartas de Ataque representam padrões de combate registrados na Rede. Um mesmo ataque pode ser executado por monstros diferentes, mas sua eficiência muda conforme atributos, elemento, equipamento e arena. Assim, montar um deck não significa apenas procurar o maior dano: significa escolher quais situações o duelista quer criar.

O Clã das Cinzas nasceu nas regiões vulcânicas do oeste. Seus combatentes acreditam que hesitação é uma forma de derrota. Seus Ecos favorecem pressão ofensiva, dano explosivo, investidas e efeitos que recompensam sequências agressivas. A Brasa é predominante, embora algumas criaturas tenham absorvido Pedra ou Tempestade.

O Reino das Marés ocupa arquipélagos construídos sobre cidades parcialmente submersas. Seus duelistas tratam combate como fluxo: avançar, recuar, reposicionar e devolver a força do adversário. Seus Ecos normalmente possuem Maré e tendem a combinar sobrevivência, controle de espaço e recuperação.

A Colmeia de Rocha não é uma colmeia biológica, mas uma civilização organizada ao redor de enormes formações minerais interligadas. Seus membros enxergam cada combatente como parte de uma estrutura maior. Seus Ecos têm alta resistência, ataques pesados e capacidades relacionadas a terreno, estabilidade e controle.

Os Nômades da Areia atravessam regiões onde tempestades alteram completamente o terreno em poucas horas. Para eles, posição fixa significa vulnerabilidade. Seus Ecos combinam Pedra e Tempestade, especializando-se em velocidade, engano, reposicionamento e ataques que punem adversários incapazes de acompanhar seu movimento.

Todas as quatro facções acreditavam que a Rede apenas reproduzia registros de Teralume. Isso mudou quando arenas começaram a manifestar assinaturas que jamais haviam sido registradas.

Essas manifestações pertencem ao Coro do Horizonte Partido, uma quinta facção que parece existir fora do mundo-fonte. Seus monstros não são invocados pela Rede: eles parecem estar usando a própria Rede para entrar em Teralume. Seus Ecos apresentam padrões incompatíveis com os quatro elementos conhecidos e serão o núcleo de uma futura expansão, introduzindo arenas corrompidas, regras alteradas e uma possível quinta afinidade.

## 2. Concept art e silhueta dos monstros

| Monstro | Prompt de concept art | Construção da silhueta |
|---|---|---|
| Cindravil | Original volcanic predator creature, frontal full-body concept art, lean humanoid-beast anatomy, dark charcoal armor plates, glowing orange fissures, elongated forearms, swept-back flame-shaped fins, agile stance, anime cel-shaded rendering, clean line art, neutral gray background, game character turnaround quality, no text, no logo | Tronco = cápsula fina; cabeça = esfera achatada; braços/pernas = cápsulas longas; ombros = cones para trás; cauda = sequência de cones. |
| Braseonte | Original massive volcanic guardian creature, frontal full-body concept art, extremely broad stone torso, black volcanic plates, magma glow between armor segments, heavy fists, short thick legs, anime cel-shaded style, neutral background, clean game character design, no text | Torso = caixa grande; cabeça = esfera pequena; braços = cápsulas grossas; punhos = caixas; pernas = cilindros; costas = cones irregulares. |
| Pirocanto | Original mystical fire entity, frontal full-body concept art, floating ceremonial body, narrow torso, segmented ember mantle, circular glowing core in chest, symmetrical floating flame ornaments, elegant mage silhouette, anime cel-shaded, neutral background, no text | Tronco = cápsula vertical; cabeça = esfera; manto = cone invertido; núcleo = esfera; ornamentos = pequenas esferas e cones flutuantes. |
| Velamar | Original amphibious speed fighter creature, frontal full-body concept art, sleek aquatic armor, streamlined limbs, fin-like forearms, blue and turquoise body markings, athletic stance, anime cel-shaded concept art, neutral gray background, no text | Tronco = cápsula; cabeça = esfera alongada; braços/pernas = cápsulas; barbatanas = cones achatados; pés = caixas estreitas. |
| Abissarca | Original deep ocean armored guardian creature, frontal full-body concept art, huge shell-covered torso, heavy aquatic armor, broad shoulders, short powerful legs, dark blue shell plates with turquoise edges, anime cel-shaded, neutral background, no text | Corpo = esfera grande + caixa; casco = meia esfera; braços = cilindros grossos; cabeça = esfera pequena; ombros = cones largos. |
| Nacarim | Original pearl ocean oracle creature, frontal full-body concept art, slender floating body, nacre armor, circular pearl nodes, flowing fin-shaped appendages, pale cyan glow, mystical anime cel-shaded aesthetic, neutral background, no text | Torso = cápsula fina; cabeça = esfera; nós = várias esferas pequenas; braços = cápsulas; nadadeiras = cones achatados; base = cone invertido. |
| Talhuno | Original monolithic stone giant creature, frontal full-body concept art, enormous rectangular torso, layered sandstone armor, compact head embedded between shoulders, oversized forearms, ancient geometric mineral design, anime cel-shaded, neutral background, no text | Corpo = caixa enorme; cabeça = esfera parcialmente embutida; braços = caixas/cápsulas grossas; pernas = caixas; ombros = blocos. |
| Prismolito | Original crystalline tactical mage creature, frontal full-body concept art, faceted stone body, floating prism fragments around shoulders, luminous cyan crystal core, geometric symmetrical silhouette, anime cel-shaded concept art, neutral background, no text | Tronco = prisma/caixa; cabeça = esfera ou octaedro; núcleo = esfera; membros = cápsulas; cristais flutuantes = cones. |
| Craguil | Original agile rock predator creature, frontal full-body concept art, compact muscular quadruped-inspired humanoid stance, forward stone horns, layered mineral plates, amber cracks, powerful legs, anime cel-shaded, neutral background, no text | Peito = cápsula horizontal; cabeça = esfera; chifres = cones; braços/pernas = cápsulas; placas = caixas achatadas. |
| Sirocal | Original desert wind runner creature, frontal full-body concept art, extremely lean body, swept-back sandstone armor strips, long legs, aerodynamic head crest, golden and pale yellow colors, anime cel-shaded, neutral background, no text | Corpo = cápsula fina; pernas = cápsulas longas; cabeça = esfera pequena; crista = cone; braços = cápsulas; ombreiras = caixas inclinadas. |
| Dunamonte | Original desert sand tank creature, frontal full-body concept art, bulky layered dune armor, broad chest, thick rounded limbs, sandstone plates shifting over one another, muted gold and brown palette, anime cel-shaded, neutral background, no text | Torso = esfera grande; placas = caixas curvas; braços/pernas = cápsulas grossas; cabeça = esfera pequena; ombros = esferas. |
| Miralume | Original desert mirage mage creature, frontal full-body concept art, slender hovering body, layered translucent heat-wave fins, turquoise glowing eyes and nodes, golden desert armor, asymmetrical floating ornaments, anime cel-shaded, neutral background, no text | Corpo = cápsula; cabeça = esfera; base = cone invertido; ornamentos = esferas; braços = cápsulas finas; lâminas laterais = cones achatados. |

## 3. Balanceamento

| Monstro | Papel | Pontos fortes | Pontos fracos | Combinações fortes |
|---|---|---|---|---|
| Cindravil | Rápido | Maior mobilidade, ótimo crítico, projéteis eficientes | Pouca Energia, Mente baixa | Cinza Agulha + Centelha Lance + Agulha de Siroco + Sabre do Siroco |
| Braseonte | Tanque ofensivo | Energia máxima, Força alta, excelente anti-empurrão | Muito lento, recargas inferiores | Investida da Fornalha + Muralha em Marcha + Lâmina de Basalto + Voto da Brasa |
| Pirocanto | Mago ofensivo | Mente 94, 3 Cânticos, grande explosão elemental | Força e Energia baixas | Pulso de Carvão + Queda Meteora + Concha da Memória + Coro da Fornalha |
| Velamar | Híbrido móvel | Mobilidade alta com Mente aceitável | Não domina nenhum atributo ofensivo | Jato Laminar + Onda Reversa + Passo de Duna + Lâmina de Fluxo |
| Abissarca | Tanque | Energia alta, resistência a controle, Força 86 | Agilidade muito baixa | Aríete de Espuma + Mergulho Abissal + Círculo de Nácar + Acorde do Monólito |
| Nacarim | Mago de sustain | Maior Mente do elenco, cura e recarga | Vulnerável a pressão corpo a corpo | Gota Ressonante + Círculo de Nácar + Concha da Memória + Canção da Renovação |
| Talhuno | Tanque pesado | Força 94, Energia máxima, excelente troca direta | Mobilidade e Mente ruins | Muralha em Marcha + Colapso Raso + Martelo Orbital + Lâmina de Basalto |
| Prismolito | Mago híbrido | Mente alta, dois elementos, condições consistentes | Agilidade mediana e pressão direta menor | Anel Prismático + Lança de Vidro + Seixo de Retorno + Selo Prismático |
| Craguil | Híbrido agressivo | Força + Agilidade equilibradas | Mente e Ânimo apenas medianos | Passo de Duna + Investida da Fornalha + Colapso Raso + Lâmina de Basalto |
| Sirocal | Rápido | Maior Agilidade, excelente para kite | Menor Energia do elenco e Força baixa | Agulha de Siroco + Passo de Duna + Salto Miragem + Sabre do Siroco |
| Dunamonte | Tanque híbrido | Boa Força, Mente razoável e alta Energia | Pouca capacidade de perseguição | Muralha em Marcha + Frente Arenosa + Poço Seco + Talismã da Duna |
| Miralume | Mago móvel | Mente 90 + Agilidade 72 + 3 Cânticos | Pouca Força e baixa Energia | Salto Miragem + Agulha de Siroco + Pulso de Carvão + Coro da Fornalha |

### Curvas de poder pretendidas

O roster cria quatro perfis principais:

Agilidade 90+ vence por posicionamento, mas deve perder rapidamente se for preso por area + atordoar.

Força 85+ domina trocas frontais e desafio, mas sofre contra kite e ataques de alta velocidade.

Mente 90+ aproveita recarga, Cânticos e efeitos condicionais, mas possui Energia ou Força deliberadamente inferiores.

Os híbridos ficam aproximadamente na faixa 55–80 em vários atributos e devem possuir mais possibilidades de montagem, mas nunca superar os especialistas em sua função principal.

Também existe uma relação intencional de arquétipos:

projetil → pressão a distância

area → controle de mobilidade

investida → perseguição e quebra de espaço

salto → alto risco e alto dano

Não estabeleceria uma vantagem rígida do tipo pedra-papel-tesoura entre eles; o sistema de atributos já produz contrajogo suficiente.

## 4. Próximas camadas

Tabuleiro tático 3×3

Entre duas batalhas, o jogador entra em uma visão estratégica composta por 9 espaços. Cada espaço representa uma posição da expedição, não a posição do personagem durante o combate.

O jogador pode avançar apenas para casas adjacentes. Algumas revelam batalha, outras oferecem Cânticos temporários, recuperação, equipamentos, modificadores de deck ou eventos.

O ponto interessante é permitir que o jogador veja parcialmente as próximas casas. Assim, a decisão deixa de ser apenas “qual bônus é maior?” e passa a ser “qual caminho prepara melhor meu deck para o chefe?”.

Uma arena poderia, por exemplo:

Batalha → Oficina → Elite

enquanto outro caminho oferece:

Escaneamento → Cântico → Evento

Isso cria estratégia sem adicionar complexidade ao combate 3D.

Exploração e escaneamento

Fora da Rede competitiva, o jogador explora pequenas regiões de Teralume.

Monstros não precisam ser capturados diretamente. Ao encontrar uma criatura, o jogador inicia um escaneamento de Eco.

Cada encontro aumenta o percentual de registro:

25% revela elemento.

50% revela atributos aproximados.

75% revela passiva.

100% permite sintetizar sua carta de Monstro.

Isso cria uma razão mecânica para encontrar novamente criaturas conhecidas.

Versões raras poderiam possuir assinatura diferente, aparência alternativa ou pequena redistribuição de atributos sem criar um novo monstro completamente independente.

Progressão por arenas

A campanha pode ser organizada em Circuitos da Rede, cada um com 4–6 arenas.

Exemplo:

Circuito das Cinzas → Circuito das Marés → Circuito Mineral → Circuito Errante → Convergência.

Cada circuito ensina um aspecto específico do sistema.

Os chefes devem alterar regras, não apenas possuir mais Energia. Um chefe poderia possuir duas fases, bloquear temporariamente um slot da mão, alterar o modificador elemental da arena ou possuir uma reação específica contra determinadas cartas.

Isso também prepara narrativamente a invasão do Coro do Horizonte Partido.

Na expansão, algumas arenas poderiam começar a apresentar falhas da Rede: obstáculos mudam durante a luta, modificadores elementais oscilam e criaturas invasoras ignoram algumas regras normais.

O resultado é uma progressão natural:

montar deck → dominar combate → navegar o tabuleiro → escanear novos Ecos → derrotar chefes → descobrir anomalias da Rede → enfrentar a quinta facção.

Esse loop permite expandir o jogo principalmente adicionando novos JSONs, arenas e comportamentos, sem precisar modificar a estrutura central do combate.

## 5. Cenário e voo (adicionado no protótipo)

Nos episódios de *Chaotic* o cenário era parte da luta. No protótipo isso virou regra:

- **Cobertura:** pilares, rochas e árvores bloqueiam projéteis. Ficar atrás de um obstáculo enquanto as cartas recarregam é uma tática válida.
- **Cenário destrutível:** obstáculos têm resistência (40 + altura × 12 + raio × 25). Projéteis, golpes de Área e Saltos os quebram, e a cobertura some.
- **Esconderijos:** capim alto (`mato`) e névoa (`nevoa`) escondem quem não está atacando. Projéteis não perseguem quem está escondido, e a IA vai até a última posição em que viu o alvo. Arenas com esconderijo: Bosque Sussurrante (nova), Terraço das Marés e Dunas de Vidro.
- **Voo:** monstros alados pairam a 1,6 m, ignoram lava e água, e com Espaço sobem a 4,6 m por cerca de 2 s. No alto, apenas projéteis os atingem. A troca é Energia mais baixa e o risco de ser alvo fácil de projéteis.
  - **Aerisca** (Nômades da Areia): *Vantagem de Altura*, com +20% de dano em projéteis quando está no alto.
  - **Cinzalar** (Clã das Cinzas): *Mergulho Ígneo*. Ao descer, a próxima investida ou salto causa +6 de dano.
- **IA "rápida":** quando tem 12 ou mais de Agilidade sobre o alvo, a IA faz kiting: ataca de longe, recua e esquiva investidas.
