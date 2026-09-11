# 🌌 STATION ABYSS - DIRETRIZES DO PROJETO E REGRAS DA IA (AGENTS.md)

Este documento contém a arquitetura, regras de design, convenções e lições aprendidas para o desenvolvimento de **Station Abyss** (Godot 4.x / GDScript). Qualquer agente de IA ou desenvolvedor DEVE seguir estritamente estas diretrizes.

---

## 🛑 REGRAS DE OURO (NUNCA VIOLAR)

1. **PRESERVAÇÃO TOTAL DE LORE E TEXTOS:**
   - **NUNCA** remova, reduza ou resuma frases de diálogos, cutscenes, lore ou reações de personagens. O texto rico e cômico/dramático em Português é um dos pilares do jogo.
   - Todo texto novo deve manter a versão original em Português intacta, suportando tradução paralela (EN / JA) via `Localization.t()` ou `TranslationServer`.

2. **NÃO REINVENTAR O QUE JÁ FUNCIONA:**
   - **NUNCA** mude drasticamente estruturas de código, nomes de variáveis ou fluxos que já estão operacionais. Mexa **estritamente** no que for solicitado.

3. **CUIDADO COM FREETYPE E FONTES NO GODOT 4:**
   - **NUNCA** instancie fontes zeradas com `FontFile.new()` ou faça `load()` bruto de arquivos `.ttf` que não estejam pré-importados pelo editor, pois isso faz o FreeType falhar (`hb_font is null`, escala 0.0) e **apaga todos os textos do jogo**.
   - Use a central **`FontManager.gd`** via `SystemFont` com a cadeia de *fallbacks* para Linux, Windows e Mac.

---

## 🔤 SISTEMA DE TIPOGRAFIA E FONTES (`FontManager.gd`)

A tipografia do jogo é dividida em **3 papéis estritos**:

1. **UI Geral, Menus, Diálogos e HUD Base (`"ui"`):**
   - **Fonte:** `DejaVu Sans` (Linux) -> `Segoe UI` / `Arial` (Windows) -> `Helvetica` (Mac) -> `sans-serif`.
   - **Objetivo:** Garantir que o layout da interface nunca pule, mude de tamanho ou estoure bordas.

2. **Interfaces Digitais, Radares, Terminais e Minigame (`"mono"`, `"terminal"`, `"csouter"`, `"arcade"`):**
   - **Fonte:** `Terminus` (Linux/Nativa) -> `OCR A Std` -> `Hack` -> `Consolas` (Windows) -> `monospace`.
   - **Objetivo:** Visual hacker/retro pixel-perfect com largura de caractere fixa.

3. **Placas 3D de Setor na Parede da Dungeon (`"signage"`, `"wall"`):**
   - **Fonte:** `Impact` -> `Arial Black` -> `DejaVu Sans` (Weight 800) -> `sans-serif`.
   - **Objetivo:** Visual de chapa de aço industrial/militar cravada nas paredes 3D (`[ SETOR 01 - ALPHA ]`).

---

## 💬 GERENCIADOR DE DIÁLOGOS E MENSAGENS DE SISTEMA (`DialogueManager.gd` / `Main.gd`)

O sistema de mensagens possui uma **Hierarquia de Prioridade Estrita**:

### A. Mensagens de Sistema (Loot, C-Souter, Level Up, Buff Spooter, Data Drive, Chronodox)
- **Função Central:** Deve sempre ser disparada via `show_system_message()`.
- **Duração Fixa:** Exatamente **5.0 segundos** (ou 7.0s se configurado).
- **Som Automático:** Sempre toca o efeito sonoro oficial de evento único (`sfx_level_up`).
- **Trava de Segurança:**
  - Chama `dialogue_manager.pause_dialogues()` no milissegundo em que entra.
  - Seta `is_system_message_blocking = true` para que nenhuma conversa aleatória (`idle_chatter`) ou diálogo de lore sobrescreva o painel durante a exibição.
  - Oculta o frame do portrait (`dialogue_port_frame.hide()`) se for mensagem pura de texto, ou exibe o ícone do item se houver textura.
  - Ao expirar os 5.0 segundos, aguarda o intervalo de **0.5s** e só então chama `resume_dialogues()` e executa o callback `on_complete` (como a fala de reação da tripulação).

### B. Falas de Personagens e Lore
- **Duração de Exibição:** **4.5 segundos** por balão de fala.
- **Intervalo entre Falas Seguidas:** **0.5 segundos** (impede que textos se atropelem rapidamente).
- **Ressincronização de Booleanos:**
  - Em `pause_dialogues()`, SEMPRE resete `is_showing_dialogue = false` e pare os timers de exibição.
  - Em `resume_dialogues()`, resete `is_showing_dialogue = false` para impedir que o booleano fique preso em `true` e trave permanentemente o gerador de conversas.
  - No evento `_on_dialogue_ended()`, SEMPRE execute `dialogue_panel.hide()` e `dialogue_port_frame.hide()` para que o texto não fique "agarrado" na tela.

---

## ⚔️ SISTEMA DE COMBATE (`BattleEngine.gd`)

### 1. Ações Livres / Instantâneas (Defender e Fugir)
- **Prioridade Máxima:** Ações de `Defender` e `Fugir` possuem velocidade instantânea (`act.speed = 99999`) e executam **no topo da fila de resolução**, antes de qualquer ataque de inimigo ou aliado.
- **Execução Visual:** O personagem assume a postura de defesa no log e no áudio (`sfx_defend`) primeiro. Quando a horda inimiga ataca naquele turno, a flag `defending_members` **já está 100% ativa**, aplicando a redução de dano ou a Defesa Impenetrável.
- **Evitar Escopo Duplicado:** Nunca re-declare `var actor_entity = act.actor.entity` dentro do bloco `elif act.action == "Defender":`, pois ela já existe no topo do bloco `else:`.

### 2. Passiva de Sobrecura da Unit-7 (`act.actor.id == "robo"`)
- **EXCLUSIVA DA UNIT-7:** Apenas quando a Unit-7 é a curandeira da ação (`is_unit7_healer = (act.actor.id == "robo")`), o excesso de cura além do 100% de HP é convertido em Escudo (`m.shield`). Curas vindas de Rigard ou Vaelthor **nunca** geram escudo.
- **NÃO ACUMULA INFINITO:** A fórmula é uma RENOVAÇÃO DE ESTADO: `m.shield = max(m.shield, wasted_heal)`. Se o aliado tem 20 de escudo e a sobrecura é 35, o escudo muda para 35 (não vira 55).
- **Prioridade de Alvo na Cura Alvo:**
  1. Primeiro foca em quem está com HP ferido (`hp < max_hp`).
  2. Se todos estiverem com 100% de HP e quem cura for a Unit-7, foca no aliado com menor escudo (ignorando quem já tem escudo cheio igual ao valor da cura).
  3. Se todos já estiverem com HP cheio e Escudo cheio, gasta a MP, toca `sfx_heal` e avisa no log que todos já estavam no máximo.
- **Cura em Área:** Na cura em grupo, todos os membros vivos piscam em azul (`animate_ally_heal(k)`), mas a sobrecura em escudo só se aplica à Unit-7.

### 3. Escalonamento Infinito de Andares
- **Andar 1:** Horda estritamente de **1 a 2 inimigos** (`randi_range(1, 2)`).
- **Andar 2+:** Mínimo e máximo de inimigos e atributos (HP, ATK, SPD, EXP) crescem infinitamente sem teto fixo.
- **Modo Purga (Alerta Vermelho):** Aumenta HP (+45%), Dano (+35%), Velocidade (+4), EXP (+60%) e envia reforços extras de inimigos (+1 a +3).

---

## 🎨 INTERFACE, BANNERS E MENUS

### 1. Banner de Tutorial Panorâmico (`_show_dungeon_tutorial_banner()`)
- Exibido **exclusivamente na exploração da dungeon** (1.6s após a entrada).
- Centralizado proporcionalmente com âncoras (`anchor_left = 0.0`, `anchor_right = 1.0`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`).
- Usa `mouse_filter = MOUSE_FILTER_IGNORE` para não travar inputs de movimento do jogador.
- **Destruição Imediata (`dismiss_tutorial_banner()`):** Deve ser deletado instantaneamente ao abrir ESC, Party Menu (TAB), iniciar combate, abrir terminais, minigame, cutscenes ou trocar de andar.
- **EVITAR ERRO DE LAMBDA:** Ao usar timers para o fade-out do tutorial, valide através de `is_instance_valid(active_tutorial_banner)` em vez de capturar nós locais soltos em lambdas.

### 2. HUD do Jogador
- Mantido no tamanho cravado de **300x120** (ou 304x132 fixo) sem `fit_content = true` em RichTextLabels dinâmicos, para impedir que métricas de fontes alterem o espaçamento das bordas do painel.

### 3. Tela de Seleção de Idiomas (`TitleScreen.gd`)
- Inicia em tela preta com as bandeiras (🇧🇷 PORTUGUÊS, 🇺🇸 ENGLISH, 🇯🇵 日本語) antes de tocar a BGM tema.
- Possui trava de segurança contra duplo clique (`if is_choosing_language: return`) e desativa os botões no momento do clique.
