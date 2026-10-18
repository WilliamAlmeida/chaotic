# Campanha: "A Fenda do Horizonte"

Roteiro da história do modo **JOGAR HISTÓRIA** do protótipo. Os dados ficam em `prototipo/data/campanha.json` (títulos, falas, oponentes, arenas, recompensas e regras de chefe); este documento é o guia de tom e de enredo.

Público: crianças a partir de 6 anos. Falas de **uma linha**, palavras simples, muita celebração ("Muito bem!", "Boa luta!") e nenhuma punição ao perder: o mentor sempre incentiva a tentar de novo.

## Personagens

| Personagem | Papel | Retrato |
|---|---|---|
| **Duelista** (o jogador) | Novato na Rede dos Ecos. Nunca fala: as escolhas são as lutas. | – |
| **Guardiã Lira** | Mentora, uma Guardiã da Rede. Explica cada arena com uma dica curta e comemora as vitórias. | Símbolo dourado de Cântico com uma nota musical |
| **Os oponentes** | O monstro de cada etapa fala por si (uma frase de desafio antes e uma de respeito depois). | Carta do monstro (modelo 3D) |
| **Voz do Horizonte** | O Coro do Horizonte Partido falando *através* de Ecos invadidos. Fala pausado, com reticências. | Octógono partido, roxo e tremido |

## Enredo em cinco circuitos

A Rede dos Ecos, que materializa as lembranças dos monstros de Teralume, começa a falhar: arenas tremem, Ecos aparecem no circuito errado e uma voz desconhecida fala por eles. A Guardiã Lira treina um Duelista novato e o leva pelos circuitos das quatro facções. Cada chefe derrotado revela uma pista, até a luta final na Fenda do Horizonte contra o Arauto do Coro.

### 1. Circuito das Cinzas (Clã das Cinzas)

| Etapa | Título | Arena | Oponente | Recompensa |
|---|---|---|---|---|
| 1 | Primeira Faísca (tutorial) | Pátio do Primeiro Eco | Cindravil | Cindravil |
| 2 | Asas de Brasa | Caldeira Rubra | Cinzalar (voa) | Cinzalar |
| 3 | Canto da Fornalha | Caldeira Rubra | Pirocanto | Pirocanto |
| 4 | **Chefe:** O Colosso Braseonte | Caldeira Rubra | Braseonte (+30% Energia) | Braseonte |

Pista do chefe: "Antes de você, algo passou por aqui. Algo que não era um Eco."

### 2. Circuito das Marés (Reino das Marés)

| Etapa | Título | Arena | Oponente | Recompensa |
|---|---|---|---|---|
| 1 | Ondas Gêmeas | Terraço das Marés | Velamar | Lâmina de Fluxo |
| 2 | Segredo do Oráculo | Jardim dos Condutores | Nacarim | Nacarim |
| 3 | Eco Estranho | Terraço das Marés | Sirocal *invadido pelo Coro* | Concha da Memória |
| 4 | **Chefe:** Guardião do Abismo | Terraço das Marés | Abissarca (+30% Energia) | Abissarca |

Pista do chefe: "A voz vem do Horizonte Partido."

### 3. Circuito Mineral (Colmeia de Rocha)

| Etapa | Título | Arena | Oponente | Recompensa |
|---|---|---|---|---|
| 1 | Chifres de Pedra | Pedreira Viva | Craguil | Craguil |
| 2 | Luz no Bosque | Bosque Sussurrante | Prismolito | Prismolito |
| 3 | Eco Rachado | Pedreira Viva | Braseonte *invadido* | Selo Prismático |
| 4 | **Chefe:** O Monólito | Pedreira Viva | Talhuno (+30% Energia) | Acorde do Monólito |

Pista do chefe: "Alguém está partindo a Rede ao meio. Os Nômades viram o rasgo no céu."

### 4. Circuito Errante (Nômades da Areia)

| Etapa | Título | Arena | Oponente | Recompensa |
|---|---|---|---|---|
| 1 | Sombra no Céu | Dunas de Vidro | Aerisca (voa) | Aerisca |
| 2 | Miragem | Dunas de Vidro | Miralume | Miralume |
| 3 | Tempestade Partida | Dunas de Vidro | Pirocanto *invadido* | Sabre do Siroco |
| 4 | **Chefe:** Senhor das Dunas | Dunas de Vidro | Dunamonte (+30% Energia) | Dunamonte |

Pista do chefe: "A Fenda está aberta. Vá, antes que o Coro entre inteiro!"

### 5. Convergência (Coro do Horizonte Partido)

Todas as lutas acontecem na **Fenda do Horizonte** (`fenda_horizonte`). Enquanto essa arena não existir em `locais.json`, cada etapa usa a arena de reserva indicada no JSON.

| Etapa | Título | Oponente | Recompensa |
|---|---|---|---|
| 1 | Portal Partido | Cinzalar *invadido* | Coro da Fornalha |
| 2 | Coro das Profundezas | Nacarim *invadida* | Canção da Renovação |
| 3 | Cristal Quebrado | Prismolito *invadido* | Hino do Horizonte Móvel |
| 4 | **Chefe final:** Arauto do Horizonte | Miralume *Arauto* (+30% Energia, "arena inverte os bônus") | Título **Guardião da Rede** |

Final: "A Fenda se fechou! Você salvou a Rede dos Ecos!" O Coro promete voltar (gancho para a expansão com a quinta facção, ver `design-teralume.md`, seção 4).

## Regras dos chefes

Cada chefe traz uma **regra** (texto em `regra`, mostrado no mapa e passado em `config["campanha"]["regra"]`). As implementadas pela configuração:

- **+30% de Energia:** `config["inimigo"]["energia_bonus"] = 0.3` (a Batalha/Lutador deve aplicar).

As outras ("névoa que esconde", "investidas causam menos dano", "vento mais forte", "a arena inverte os bônus") são por enquanto texto de sabor; a arena já traz névoa, vento etc. pelos próprios perigos.

## Estrelas e progressão

- Vencer dá **1 estrela**; vencer com mais de 30% de Energia, **2**; com mais de 60%, **3**.
- Etapas vencidas podem ser repetidas para melhorar as estrelas.
- Perder não tira nada: o mentor dá uma dica e o mapa continua no mesmo lugar.
- Recompensas: o monstro vencido vira um Eco registrado (desbloqueado na Escolha Rápida); equipamentos e Cânticos são mostrados como prêmio simbólico (já estão disponíveis).
- Ao terminar os cinco circuitos, todos os 15 monstros estão desbloqueados.
