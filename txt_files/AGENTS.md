# 🌌 STATION ABYSS - DIRETRIZES DO PROJETO E REGRAS DA IA (AGENTS.md)

Este documento contém a arquitetura, regras de design, convenções e lições aprendidas para o desenvolvimento de **Station Abyss** (Godot 4.x / GDScript). Qualquer agente de IA ou desenvolvedor DEVE seguir estritamente estas diretrizes.

---

## 🛑 REGRAS DE OURO (NUNCA VIOLAR)

1. **PRESERVAÇÃO TOTAL DE LORE E TEXTOS:**
   - **NUNCA** remova, reduza ou resuma frases de diálogos, cutscenes, lore ou reações de personagens. O texto rico e cômico/dramático em Português é um dos pilares centrais do jogo.
   - Todo texto novo deve manter a versão original em Português intacta, suportando tradução paralela (EN / JA) via `Localization.t()`.

2. **NÃO REINVENTAR O QUE JÁ FUNCIONA:**
   - **NUNCA** mude drasticamente estruturas de código, nomes de variáveis ou fluxos que já estão operacionais. Mexa **estritamente** no que for solicitado.

3. **CUIDADO COM FONTES E O BUG DE ACENTOS NO GODOT 4:**
   - O motor de texto do Godot (HarfBuzz) renderiza glifos caractere por caractere. Fontes puramente ASCII ou sci-fi/pixel sem suporte a acentos (`Orbitron`, fontes BRK) provocam o bug visual de *fallback de glifo individual*: a palavra inteira fica estilizada e apenas a letra acentuada (`Ã`, `É`, `Ó`, `Ç`) é desenhada fina em Arial do sistema.
   - **REGRA ESTRITA:** Textos dinâmicos em português (nomes de personagens, nomes de inimigos, diálogos, HUD de jogador e mensagens de sistema) **DEVEM USAR `font_ui`** (famílias com conjunto latino completo como `Exo 2`, `Ubuntu`, `Segoe UI`, `Roboto`).
   - Fontes de estilo sci-fi/display (`font_title`) são reservadas **exclusivamente** para títulos fixos em caixa alta sem acentuação (ex: `"STATION ABYSS"`, `"STATUS DA EQUIPE"`, `"FENDA QUANTICA"`).

4. **NATUREZA INFINITA DA DUNGEON:**
   - O jogo **NÃO possui trava no andar 20**. A estação espacial é infinita e os atributos dos inimigos escalam continuamente via fórmulas multiplicativas baseadas em `floor_num`.
   - A batalha final contra o Imperador do Tempo (**Khen-Shalom**) NÃO acontece ao chegar em um andar fixo, mas sim ao **morrer carregando o artefato Chronodox**, ativando o Paradoxo Temporal.

---

## 🔤 SISTEMA DE TIPOGRAFIA E FONTES (`FontManager.gd`)

A tipografia é centralizada em `FontManager.gd` e carrega arquivos locais exclusivamente de `res://assets/fonts/`:

1. **Interface, Nomes, Diálogos e Textos Acentuados (`"ui"`):**
   - **Fontes:** `Exo 2`, `Ubuntu`, `Segoe UI`, `Roboto`, `DejaVu Sans`.
   - **Objetivo:** Renderização 100% nativa de caracteres latinos (`ã`, `é`, `ó`, `ç`) com kerning proporcional perfeito no Linux, Windows e Mac.

2. **Terminais, Radares e C-Souter (`"mono"`, `"terminal"`, `"csouter"`, `"hud_numbers"`):**
   - **Fontes:** Carrega `Terminus.ttf` / `Terminus.otf` de `res://assets/fonts/` -> fallback para `Consolas`, `Liberation Mono`, `Monospace`.
   - **Objetivo:** Largura fixa pixel-perfect para alinhamento de telemetria e números de atributos.

3. **Arcade Retro (`"retro"`, `"arcade"`):**
   - **Fontes:** `Terminus.ttf` -> `Visitor TT1 BRK` -> `Consolas`. Usado no minigame *Space Spooter*.

4. **Títulos Sci-Fi Sem Acento (`"title"`, `"boss"`):**
   - **Fontes:** `Orbitron.ttf` (de `assets/fonts/`) -> `Quantum Flat BRK` -> `Impact` -> `Arial Black`.
   - **Uso Restrito:** Apenas em títulos em inglês ou palavras sem acento.

---

## 📁 PADRONIZAÇÃO DE ASSETS E CARREGAMENTO

Todos os arquivos visuais em `res://assets/` seguem convenções semânticas estritas com carregamento multi-formato seguro:

### 1. Nomenclatura Padrão de Texturas
- `cutscene_*`: Imagens de história e cinemáticas (`cutscene_prologo`, `cutscene_chronodox`, `cutscene_final_1` a `6`, `cutscene_sem_bg`).
- `enemy_*`: Todos os inimigos, elites e mestres (`enemy_drone`, `enemy_mutant_beast`, `enemy_guardian`, `enemy_queen`, `enemy_master_drone`, `enemy_boss_khen_shalom`).
- `char_port_*`: Retratos normais de diálogo e combate (`char_port_humano`, etc.).
- `char_closed_*`: Retratos de olhos fechados (sistema de piscar).
- `char_damaged_*`: Retratos feridos/derrotados.
- `char_full_*`: Imagens de corpo inteiro para os cut-ins de combate e tela de party.
- `prop_*`: Objetos do labirinto (`prop_chest_closed`, `prop_chest_open`, `prop_heal_pod`, `prop_portal`, `prop_spooter_on`, `prop_terminal_on`, `prop_csouter_ground`).
- `env_*`: Texturas 3D de blocos de parede, piso e teto (`env_wall_metal_cyan`, `env_floor_grid`, `env_ceiling_dark`).
- `ui_*`: Telas de fundo e ícones de menu (`ui_title_illustration`, `ui_title_logo`, `ui_gameover_illustration`, `ui_tutorial`, `ui_item_detector`).

### 2. Carregador Seguro Multi-Formato (`load_texture_safe`)
- Todo método de carregar imagem itera sobre extensões (`.png`, `.webp`, `.jpg`, `""`). Isso garante que conversões futuras para WebP funcionem sem quebrar chamadas de código.

---

## 🏰 LABIRINTO PROCEDURAL E AMBIENTAÇÃO (`ProceduralDungeon.gd`)

1. **Rotação Matemática dos Pisos e Paredes:**
   - Segue a regra modular unificada da estação (sem divisão rígida de biomas):
     - `floor_num % 3 == 0`: Paredes Roxas + Piso 3 (`env_floor_grid_dots` - Pontilhado) + Luz Neon Roxa.
     - `floor_num % 2 == 0`: Paredes Laranjas + Piso 2 (`env_floor_grid_alt` - Cruz) + Luz Neon Âmbar.
     - `else`: Paredes Ciano + Piso 1 (`env_floor_grid` - Quadrado) + Luz Neon Azul.
   - O Andar 1 é garantido no piso e parede ciano padrão.

2. **Segurança de Navegação na Grade:**
   - **NUNCA** coloque pilastras ou obstáculos com colisão no centro dos corredores de 1 bloco (largura 4m). Elementos estruturais ficam restritos a salas largas (3x3 ou 4x3) ou decorativos no teto ($Y > 3.0m$).

---

## ⚔️ SISTEMA DE COMBATE E HORDAS (`BattleEngine.gd`)

### 1. Diferenciação Tática das Hordas Comuns
- **Drones (`enemy_drone`):** Pouco HP (-25%), dano regular, alta velocidade (+3 a +4 SPD). Atacam primeiro.
- **Mutantes (`enemy_mutant_beast`):** Muita vida (+25%), dano brutal (+25% ATK), lentos (-3 SPD). Horda sempre reduzida em 1 integrante (`horde_size = max(1, horde_size - 1)`).
- **Androides (`enemy_corrupted_android`):** Atributos médios balanceados.
- **Alien Scouts (`enemy_alien_scout`):** Atributos equilibrados, mas armados com rifles — **penalidade severa de fuga** (`-25%` de chance de recuo).
- **Soldado Mecha (`enemy_mech_soldier`):** Também possui rifle (`-25%` de chance de fuga).

### 2. Inimigos de Andar (Progressão Escalável)
- **Andar 5+:** `enemy_parasite` (+15% stats, peso 0.85, horda -1).
- **Andar 10+:** `enemy_mech_soldier` (+20% stats, peso 0.70, horda -1, rifle).
- **Andar 15+:** `enemy_guardian` (+25% stats, peso 0.55, horda -2).
- **Andar 20+:** `enemy_queen` (+30% stats, peso 0.40, horda -2).
- **Pós-Chronodox:** `enemy_infante_khen` (+10% stats, peso 0.90, exército pessoal do chefe).

### 3. Invasão dos 4 Mestres de Raça
- **TRAVA DO ANDAR 1:** Mestres **nunca** aparecem no Andar 1 (`floor_num > 1`).
- **CONDIÇÃO DE ABATE:** Só têm chance de invadir se o esquadrão tiver acumulado pelo menos **8 abates** daquela raça na jornada (`race_kills[race] >= 8`).
- **BALANCEAMENTO DOS MESTRES:** Possuem **+30% de HP** e **+15% de ATK e Velocidade**.
- **Valeria X-9 (Androide):** Possui barra de escudo amarelo equivalente a 50% de sua vida total.
- **Limite:** Máximo de 1 Mestre antes de obter o Chronodox e 1 Mestre após o Chronodox.

### 4. Chefe Final (Khen-Shalom)
- Status reforçados (+30% HP, +15% ATK/SPD).
- Provoca atordoamento em área e possui animação de manifestação de plasma temporal.

### 5. Sinergias e Passivas dos Aliados
- **Rigard (Capitão):** Técnica *Drive* (dano crítico x2). Define o teto de nível do grupo via *Data Drives*.
- **Kira (Tanque / Brawler):** Passiva *Garras Duplas* (ataque divide o dano em 2 golpes rápidos). Técnica *Provocar* (atrai ataques de toda a horda para si com -50% de redução de dano por golpe). Se o jogador ziguezaguear sem rumo na dungeon, ela se irrita e sai temporariamente do grupo.
- **Vaelthor (Dano Elemental):** Especialista em dano em área (*Magia de Área* e *Obscure*).
- **Unit-7 (Suporte / Androide):** Passiva *Sobrecura* (exclusiva dela: curas em aliados com HP cheio geram barreiras de Escudo). Na cutscene final antes de Khen-Shalom, entra em sobrecarga lógica pelo paradoxo e executa o protocolo de auto-sacrifício para curar o grupo.

---

## 💬 GERENCIADOR DE DIÁLOGOS E LOCALIZAÇÃO

1. **Localização em Código Puro (`Localization.gd`):**
   - A pasta externa `locale/` e o arquivo `translations.csv` são legados e **não** são utilizados em tempo de execução.
   - Toda a tradução (PT / EN / JA) é processada internamente pela classe estática `Localization.gd` (dicionário `STRINGS`) e pelas constantes de idioma em `DialogueManager.gd`.
   - Menus e interfaces checam `Localization.current_language`.

2. **Mensagens de Sistema vs. Diálogos:**
   - Mensagens de loot, level-up e artefatos usam `show_system_message()` com trava estrita de sobreposição (`dialogue_manager.pause_dialogues()`), evitando que falas comuns de corredor cortem avisos vitais.

---

## 🎮 MINIGAMES E INTERFACES ESPECIAIS

1. **Radar C-Souter:**
   - Ativado em combate ao possuir o item. Exibe HUD ciano calculando o **PDL (Poder De Luta)** acumulado da horda inimiga em tempo real.
   - Utiliza fonte com suporte a acentos no nome dos monstros para evitar estouro de caracteres.

2. **Fliperama Space Spooter (`SpaceSpooterMinigame.gd`):**
   - Minigame estilo arcade vetorial (desviar de 100 asteroides para liberar a bênção da *Defesa Impenetrável*).
   - O texto de inverter direção no topo direito DEVE usar largura delimitada com padding:
     `game_viewport_clip.draw_string(font_to_use, Vector2(0, 32), dir_str, HORIZONTAL_ALIGNMENT_RIGHT, screen_size.x - 16.0, 16, RETRO_GREEN)`
     Isso impede que palavras longas em português (`[E / A] INVERTER`) vazem da tela.

---

## 📦 VERSIONAMENTO E REPOSITÓRIO (GIT / GITHUB)

1. **Estrutura Raiz:**
   - O arquivo `project.godot`, pastas `assets/` e todos os scripts `.gd` residem na raiz do repositório para manter a compatibilidade com caminhos absolutos `res://` do Godot.
2. **Regras do `.gitignore`:**
   - A pasta `.godot/` (cache e arquivos importados pesados da engine) deve ser **estritamente ignorada**.
   - Os arquivos de metadados **`*.import` soltos ao lado dos assets NUNCA devem ser ignorados** (eles mantêm as configurações de loop de som, filtros e compressão de textura).
3. **Licença Oficial:**
   - **GNU General Public License v3.0 (GPLv3)**: O projeto é software livre com reciprocidade (Copyleft). Qualquer pessoa pode estudar, modificar e bifurcar, desde que projetos derivados mantenham o código-fonte 100% aberto.
