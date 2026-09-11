# Localization.gd
class_name Localization
extends RefCounted

static var current_language: String = "pt"

const STRINGS: Dictionary = {
	"pt": {
		# Cargos e Nomes
		"role_humano": "Capitão",
		"role_mutante": "Tanque / Brawler",
		"role_alien": "Dano Elemental",
		"role_robo": "Suporte",

		# Title & Language
		"lang_prompt": "SELECIONE O IDIOMA  /  SELECT LANGUAGE  /  言語選択",
		"btn_start_game": "INICIAR MISSÃO",
		"btn_quit_game": "SAIR DO JOGO",

		# HUD & Exploration
		"hud_floor": "ANDAR: %d (Estação Orbital)\nCHAVE: %s\nTESOUROS: %d",
		"hud_key_yes": "SIM (ALERTA ATIVO)",
		"hud_key_no": "NÃO",
		"hud_mission_title": "MISSÃO DATA DRIVE:\nCaçar %s: %02d/%02d\nAndar Orbital %d",
		"hud_mission_complete": "DADOS COLETADOS\nRequisito Concluído!\nRetorne ao Terminal!",
		"interaction_chest_closed": "[E] Abrir Baú",
		"interaction_chest_opened": "Baú Vazio",
		"interaction_heal": "[E] Usar Pod Médico (Restaurar Party)",
		"interaction_portal": "[E] Entrar no Portal (Requer Chave)",
		"interaction_spooter": "[E] Jogar Space Spooter",
		"interaction_spooter_off": "Terminal Desativado (Parou de funcionar)",
		"interaction_terminal": "[E] Acessar Terminal de Dados",
		"interaction_terminal_off": "Terminal Desativado (Gravação Concluída)",
		"interaction_orb": "[E] Coletar Excesso de Dados (%s)",
		"interaction_hidden": "[E] Tesouro Detectado",
		"interaction_hidden_done": "Cápsula Já Coletada",
		"interaction_csouter": "[E] Coletar C-Souter (Radar de Telemetria)",
		"interaction_csouter_done": "Item Coletado",

		# Hole Keeper & Núcleo
		"interaction_hole_keeper": "[E] Falar com Hole Keeper",
		"interaction_hole_keeper_done": "Fenda Quântica Vazia",
		"party_source": "FONTE",
		"party_battery": "FONTE",
		"hk_title": "★ FENDA QUÂNTICA - HOLE KEEPER %s",
		"hk_intro_dialogue": "« A filial anterior perdeu a esfera de novo?! Incompetentes! Entregue-me o Chronodox para que eu possa recalibrar o núcleo do seu traje. »",
		"hk_no_chronodox_msg": "Você não possui o Chronodox para negociar com o Hole Keeper!",
		"hk_btn_hand_chronodox": "[ E / ENTER ] Entregar Chronodox (-1 Tesouro)",
		"hk_btn_leave": "[ESC] Sair da Fenda",
		"hk_select_crew_title": "SELECIONE O TRIPULANTE PARA ADULTERAÇÃO DO NÚCLEO:",
		"hk_mod_1_name": "⚙️ -MP / +HP (Núcleo de Célula Residual)",
		"hk_mod_1_tag": "-MP\n+HP",
		"hk_mod_2_name": "⚡ -VEL / +DMG (Núcleo de Sobrecarga)",
		"hk_mod_2_tag": "-VEL\n+DMG",
		"hk_mod_3_name": "🩸 Cura % (Núcleo Regenerativo Quântico)",
		"hk_mod_3_tag": "REGEN\n%",
		"hk_mod_4_name": "🧪 -HP / +MP (Núcleo de Transmutação)",
		"hk_mod_4_tag": "-HP\n+MP",
		"hk_mod_restore_name": "🔧 [ Restaurar Núcleo ao Normal ] (Custo: 1 Tesouro)",
		"hk_btn_back_crew": "[ESC] Voltar / Escolher Outro Tripulante",
		"popup_battery_applied_title": "★ NÚCLEO ADULTERADO COM SUCESSO!",
		"popup_battery_applied_desc": "Núcleo de %s recalibrado!",
		"popup_battery_restored_title": "★ NÚCLEO RESTAURADO!",
		"popup_battery_restored_desc": "O núcleo de %s foi restaurado para o estado Normal!",
		"hk_no_treasure_restore": "Recursos insuficientes! É necessário 1 Tesouro para restaurar o núcleo.",

		# Popups e Eventos
		"popup_detector_title": "★ ESPÓLIO DE COMBATE RARO!",
		"popup_detector_desc": "A horda dropou um Detector de Metais!\n(Bips rápidos de sonar indicarão a presença de cápsulas sob o piso).",
		"popup_csouter_title": "★ C-SOUTER ADQUIRIDO COM SUCESSO!",
		"popup_csouter_desc": "Radar óptico equipado! (Em combate, exibe o visor com a leitura de PDL - Poder De Luta da horda inimiga).",
		"popup_spooter_buff_title": "★ SPACE SPOOTER BUFF ATIVADO!",
		"popup_spooter_buff_desc": "Defesa Impenetrável adquirida! (Com a equipe completa de 4 membros, Defender anula 100% do dano recebido).",
		"popup_datadrive_title": "★ DATA DRIVE CALIBRADO COM SUCESSO!",
		"popup_datadrive_desc": "Data Drive alocado para %s!\n(Nível e EXP igualados ao Capitão; imunidade a perdas futuras de EXP).",
		"popup_chronodox_title": "★ TESOURO ARTEFATO REVELADO!",
		"popup_chronodox_desc": "A equipe adquiriu um tesouro de valor inestimável: Chronodox!",
		"popup_chronodox_kira_desc": "A equipe adquiriu o Chronodox e KIRA REUNIU-SE AO GRUPO!",
		"popup_kira_away_warn": "Kira ficou impaciente com a lentidão e DEIXOU O GRUPO!\n(Ela avançou sozinha e não participará das batalhas até ser encontrada).",
		"popup_kira_away_title": "⚠ ATENÇÃO:",
		"popup_level_up_title": "PROGRESSÃO TÁTICA!",
		"popup_level_up_body": "%s Atributos aumentados!",
		"esc_confirm_title": "RETORNAR AO TÍTULO?",
		"esc_confirm_yes": "SIM (Sair)",
		"esc_confirm_no": "NÃO",

		# Popups dos Mestres Derrotados
		"popup_master_drone_title": "★ VICTOR-PRIME FOI DESTRUÍDO!",
		"popup_master_drone_desc": "O Mestre dos Drones foi aniquilado!\nTodos os Drones da estação perderam 50% de seus atributos e não entram mais em Purga.",
		"popup_master_mutante_title": "★ DR. GHORGORATH FOI ABATIDO!",
		"popup_master_mutante_desc": "O Mestre dos Mutantes sucumbiu!\nTodas as Feras Mutantes da estação perderam 50% de seus atributos e não entram mais em Purga.",
		"popup_master_androide_title": "★ VALERIA X-9 FOI DESATIVADA!",
		"popup_master_androide_desc": "A Mestra dos Androides foi desmantelada!\nTodos os Androides Corrompidos perderam 50% de seus atributos e não entram mais em Purga.",
		"popup_master_alien_title": "★ XYLOX FOI EXTERMINADO!",
		"popup_master_alien_desc": "O Mestre dos Aliens foi expurgado!\nTodos os Alien Scouts perderam 50% de seus atributos e não entram mais em Purga.",

		# Party Menu
		"party_title": "STATUS DA EQUIPE",
		"party_subtitle": "REGISTRO TÁTICO, CARGA DE EQUIPAMENTO E ATRIBUTOS DO ESQUADRÃO",
		"party_cargo": "CARGA",
		"party_status_alive": "VIVO",
		"party_status_dead": "INCAPACITADA",
		"party_status_away": "AUSENTE",
		"party_footer": "[TAB] ou [ESC] Retornar ao Labirinto",
		"party_spooter_banner": "★ SPACE SPOOTER BUFF: DEFESA IMPENETRÁVEL: Com os 4 tripulantes vivos, Defender anula 100% do dano",

		# Combate
		"battle_boss_badge": "★ IMPERADOR DO TEMPO - CHEFE FINAL ★",
		"battle_purge_badge": "⚠ PROTOCOLO DE PURGA ATIVO ⚠",
		"battle_weakened_badge": "▼ DESESTABILIZADOS (-50% ATRIBUTOS) ▼",
		"battle_act_attack": "[1] Atacar Singular",
		"battle_act_skills": "[2] Habilidades",
		"battle_act_defend": "[3] Defender",
		"battle_act_defend_buff": "[3] ★ Defender (Impenetrável)",
		"battle_act_flee": "[4] Fugir (Grupo)",
		"battle_skill_aoe": "[1] Magia de Área (15 MP)",
		"battle_skill_heal_single": "[2] Curar Alvo Crítico (10 MP)",
		"battle_skill_drive": "[3] Drive (25 MP)",
		"battle_skill_taunt": "[3] Provocar (20 MP)",
		"battle_skill_obscure": "[3] Obscure (25 MP)",
		"battle_skill_heal_party": "[3] Cura em Grupo (20 MP)",
		"battle_skill_locked_fmt": "[3] %s [Bloqueado Lv.5]",
		"battle_skill_back": "[4] Voltar",
		"battle_csouter_title": "◈ C-SOUTER RADAR ◈",
		"battle_csouter_readout": "ALVO: %s\nUNIDADES: %d\nPDL TOTAL: [ %d ]",

		# Game Over & Relatórios
		"gameover_title": "O CAPITÃO CAIU\nMISSÃO FRACASSADA",
		"mission_report_title": "RELATÓRIO DA MISSÃO:",
		"gameover_stats": "• Andar Alcançado:    %d\n• Inimigos Abatidos:  %d\n• Tesouros Coletados: %d\n• Chronodox:          %s\n• Aliados Vivos:      %d / 4",
		"gameover_retry_btn": "RETORNAR AO TÍTULO",
		"chronodox_found": "RESGATADO COM SUCESSO",
		"chronodox_not_found": "NÃO ENCONTRADO",

		# Créditos
		"victory_title": "MISSÃO CUMPRIDA\nSTATION ABYSS VENCIDA",
		"victory_stats": "• Andar Final Alcançado:  %d\n• Inimigos Abatidos:      %d\n• Tesouros Coletados:     %d\n• Chronodox:              %s\n• Status da Equipe:       SOBREVIVENTES",
		"victory_prompt": "[ Pressione ESPAÇO / ENTER para Retornar ao Menu ]"
	},
	"en": {
		# Roles and Titles
		"role_humano": "Captain",
		"role_mutante": "Tank / Brawler",
		"role_alien": "Elemental DPS",
		"role_robo": "Support",

		# Title & Language
		"lang_prompt": "SELECT LANGUAGE  /  SELECIONE O IDIOMA  /  言語選択",
		"btn_start_game": "START MISSION",
		"btn_quit_game": "QUIT GAME",

		# HUD & Exploration
		"hud_floor": "FLOOR: %d (Orbital Station)\nKEY: %s\nTREASURES: %d",
		"hud_key_yes": "YES (ALERT ACTIVE)",
		"hud_key_no": "NO",
		"hud_mission_title": "DATA DRIVE MISSION:\nHunt %s: %02d/%02d\nOrbital Floor %d",
		"hud_mission_complete": "DATA COLLECTED\nQuota Completed!\nReturn to Terminal!",
		"interaction_chest_closed": "[E] Open Chest",
		"interaction_chest_opened": "Empty Chest",
		"interaction_heal": "[E] Use Med Pod (Restore Squad)",
		"interaction_portal": "[E] Enter Portal (Key Required)",
		"interaction_spooter": "[E] Play Space Spooter",
		"interaction_spooter_off": "Terminal Offline (Out of power)",
		"interaction_terminal": "[E] Access Data Terminal",
		"interaction_terminal_off": "Terminal Offline (Calibration Done)",
		"interaction_orb": "[E] Collect Data Overflow (%s)",
		"interaction_hidden": "[E] Hidden Cache Detected",
		"interaction_hidden_done": "Cache Already Collected",
		"interaction_csouter": "[E] Pick up C-Souter (Telemetry Radar)",
		"interaction_csouter_done": "Item Collected",

		# Hole Keeper & Core
		"interaction_hole_keeper": "[E] Talk to Hole Keeper",
		"interaction_hole_keeper_done": "Quantum Rift Empty",
		"party_source": "SOURCE",
		"party_battery": "SOURCE",
		"hk_title": "★ QUANTUM RIFT - HOLE KEEPER %s",
		"hk_intro_dialogue": "« The previous branch lost the sphere again?! Incompetents! Hand over the Chronodox so I can recalibrate your suit's core. »",
		"hk_no_chronodox_msg": "You do not have the Chronodox to negotiate with the Hole Keeper!",
		"hk_btn_hand_chronodox": "[ E / ENTER ] Hand over Chronodox (-1 Treasure)",
		"hk_btn_leave": "[ESC] Exit Rift",
		"hk_select_crew_title": "SELECT CREW MEMBER FOR CORE MODIFICATION:",
		"hk_mod_1_name": "⚙️ -MP / +HP (Residual Cell Core)",
		"hk_mod_1_tag": "-MP\n+HP",
		"hk_mod_2_name": "⚡ -SPD / +DMG (Overcharge Core)",
		"hk_mod_2_tag": "-SPD\n+DMG",
		"hk_mod_3_name": "🩸 Heal % (Quantum Regenerative Core)",
		"hk_mod_3_tag": "REGEN\n%",
		"hk_mod_4_name": "🧪 -HP / +MP (Transmutation Core)",
		"hk_mod_4_tag": "-HP\n+MP",
		"hk_mod_restore_name": "🔧 [ Restore Core to Normal ] (Cost: 1 Treasure)",
		"hk_btn_back_crew": "[ESC] Back / Choose Another Member",
		"popup_battery_applied_title": "★ CORE MODIFIED SUCCESSFULLY!",
		"popup_battery_applied_desc": "%s's core recalibrated!",
		"popup_battery_restored_title": "★ CORE RESTORED!",
		"popup_battery_restored_desc": "%s's core has been restored to Normal status!",
		"hk_no_treasure_restore": "Insufficient resources! 1 Treasure is required to restore core.",

		# Popups and Events
		"popup_detector_title": "★ RARE COMBAT SPOIL!",
		"popup_detector_desc": "The horde dropped a Metal Detector!\n(Fast sonar pings will now indicate hidden capsules beneath floor plates).",
		"popup_csouter_title": "★ C-SOUTER ACQUIRED SUCCESSFULLY!",
		"popup_csouter_desc": "Optical radar equipped! (In battle, displays a HUD with the enemy horde's total Power Level - PL).",
		"popup_spooter_buff_title": "★ SPACE SPOOTER BUFF ACTIVATED!",
		"popup_spooter_buff_desc": "Impenetrable Defense acquired! (With all 4 crew members alive, Defend negates 100% of damage taken).",
		"popup_datadrive_title": "★ DATA DRIVE CALIBRATED SUCCESSFULLY!",
		"popup_datadrive_desc": "Data Drive assigned to %s!\n(Level and EXP matched to Captain; permanent EXP loss protection).",
		"popup_chronodox_title": "★ ARTIFACT TREASURE REVEALED!",
		"popup_chronodox_desc": "The squad has acquired an invaluable artifact: Chronodox!",
		"popup_chronodox_kira_desc": "The squad acquired the Chronodox and KIRA REJOINED THE TEAM!",
		"popup_kira_away_warn": "Kira grew impatient with the slow pace and LEFT THE GROUP!\n(She moved ahead alone and won't join battles until found).",
		"popup_kira_away_title": "⚠ WARNING:",
		"popup_level_up_title": "TACTICAL PROGRESSION!",
		"popup_level_up_body": "%s Attributes increased!",
		"esc_confirm_title": "RETURN TO TITLE?",
		"esc_confirm_yes": "YES (Quit)",
		"esc_confirm_no": "NO",

		# Popups of Defeated Masters
		"popup_master_drone_title": "★ VICTOR-PRIME DESTROYED!",
		"popup_master_drone_desc": "The Drone Master was obliterated!\nAll Drones on this station lost 50% of their attributes and will no longer Purge.",
		"popup_master_mutante_title": "★ GHORGORATH SLAIN!",
		"popup_master_mutante_desc": "The Mutant Master fell!\nAll Mutant Beasts on this station lost 50% of their attributes and will no longer Purge.",
		"popup_master_androide_title": "★ VALERIA X-9 DEACTIVATED!",
		"popup_master_androide_desc": "The Android Master was dismantled!\nAll Corrupted Androids lost 50% of their attributes and will no longer Purge.",
		"popup_master_alien_title": "★ XYLOX PURGED!",
		"popup_master_alien_desc": "The Alien Master was purged!\nAll Alien Scouts lost 50% of their attributes and will no longer Purge.",

		# Party Menu
		"party_title": "SQUAD STATUS",
		"party_subtitle": "TACTICAL LOG, EQUIPMENT LOADOUT AND CREW ATTRIBUTES",
		"party_cargo": "CARGO",
		"party_status_alive": "ALIVE",
		"party_status_dead": "INCAPACITATED",
		"party_status_away": "ABSENT",
		"party_footer": "[TAB] or [ESC] Return to Maze",
		"party_spooter_banner": "★ SPACE SPOOTER BUFF: IMPENETRABLE DEFENSE: With all 4 crew members alive, Defend blocks 100% of damage",

		# Combate
		"battle_boss_badge": "★ TIME EMPEROR - FINAL BOSS ★",
		"battle_purge_badge": "⚠ PURGE PROTOCOL ACTIVE ⚠",
		"battle_weakened_badge": "▼ DESTABILIZED (-50% STATS) ▼",
		"battle_act_attack": "[1] Single Attack",
		"battle_act_skills": "[2] Skills",
		"battle_act_defend": "[3] Defend",
		"battle_act_defend_buff": "[3] ★ Defend (Impenetrable)",
		"battle_act_flee": "[4] Flee (Squad)",
		"battle_skill_aoe": "[1] Area Magic (15 MP)",
		"battle_skill_heal_single": "[2] Critical Heal (10 MP)",
		"battle_skill_drive": "[3] Drive (25 MP)",
		"battle_skill_taunt": "[3] Taunt (20 MP)",
		"battle_skill_obscure": "[3] Obscure (25 MP)",
		"battle_skill_heal_party": "[3] Party Heal (20 MP)",
		"battle_skill_locked_fmt": "[3] %s [Locked Lv.5]",
		"battle_skill_back": "[4] Back",
		"battle_csouter_title": "◈ C-SOUTER RADAR ◈",
		"battle_csouter_readout": "TARGET: %s\nUNITS: %d\nTOTAL PL: [ %d ]",

		# Game Over & Relatórios
		"gameover_title": "THE CAPTAIN HAS FALLEN\nMISSION FAILED",
		"mission_report_title": "MISSION REPORT:",
		"gameover_stats": "• Floor Reached:     %d\n• Enemies Neutralized: %d\n• Treasures Found:   %d\n• Chronodox:         %s\n• Surviving Allies:  %d / 4",
		"gameover_retry_btn": "RETURN TO TITLE",
		"chronodox_found": "RETRIEVED SUCCESSFULLY",
		"chronodox_not_found": "NOT FOUND",

		# Créditos
		"victory_title": "MISSION ACCOMPLISHED\nSTATION ABYSS CONQUERED",
		"victory_stats": "• Final Floor Reached:    %d\n• Enemies Neutralized:    %d\n• Treasures Found:        %d\n• Chronodox:              %s\n• Squad Status:           SURVIVORS",
		"victory_prompt": "[ Press SPACE / ENTER to Return to Menu ]"
	},
	"ja": {
		# Roles and Titles
		"role_humano": "隊長",
		"role_mutante": "タンク / ブローラー",
		"role_alien": "元素アタッカー",
		"role_robo": "サポート",

		# Title & Language
		"lang_prompt": "言語選択  /  SELECT LANGUAGE  /  SELECIONE O IDIOMA",
		"btn_start_game": "ミッション開始",
		"btn_quit_game": "ゲーム終了",

		# HUD & Exploration
		"hud_floor": "階層: %d (軌道ステーション)\nキー: %s\n宝箱: %d",
		"hud_key_yes": "あり (警報発令中)",
		"hud_key_no": "なし",
		"hud_mission_title": "データドライブミッション:\n討伐 %s: %02d/%02d\n軌道階層 %d",
		"hud_mission_complete": "データ収集完了\nノルマ達成！\n端末へ戻れ！",
		"interaction_chest_closed": "[E] 宝箱を開ける",
		"interaction_chest_opened": "空の宝箱",
		"interaction_heal": "[E] 医療ポッドを使用 (部隊全回復)",
		"interaction_portal": "[E] ゲートに入る (鍵が必要)",
		"interaction_spooter": "[E] スペース・スプーターをプレイ",
		"interaction_spooter_off": "端末停止中 (機能停止)",
		"interaction_terminal": "[E] データ端末にアクセス",
		"interaction_terminal_off": "端末停止中 (調整完了)",
		"interaction_orb": "[E] 溢れ出たデータを回収 (%s)",
		"interaction_hidden": "[E] 隠し反応を検知",
		"interaction_hidden_done": "回収済みカプセル",
		"interaction_csouter": "[E] C-スカウターを入手 (テレメトリーレーダー)",
		"interaction_csouter_done": "入手済みアイテム",

		# Hole Keeper & Core
		"interaction_hole_keeper": "[E] ホールの番人と話す",
		"interaction_hole_keeper_done": "量子裂け目は空っぽだ",
		"party_source": "動力源",
		"party_battery": "動力源",
		"hk_title": "★ 量子亀裂 - ホールの番人 %s",
		"hk_intro_dialogue": "« 前の支店がまた球体を紛失しただと？！ 無能め！ クロノドックスを渡せば、スーツのコアを再調整してやる。 »",
		"hk_no_chronodox_msg": "ホールの番人と取引するためのクロノドックスを持っていません！",
		"hk_btn_hand_chronodox": "[ E / ENTER ] クロノドックスを渡す (宝箱 -1)",
		"hk_btn_leave": "[ESC] 亀裂を去る",
		"hk_select_crew_title": "コア改造を行うメンバーを選択:",
		"hk_mod_1_name": "⚙️ -MP / +HP (残留セルコア)",
		"hk_mod_1_tag": "-MP\n+HP",
		"hk_mod_2_name": "⚡ -速度 / +火力 (過充電コア)",
		"hk_mod_2_tag": "-速度\n+火力",
		"hk_mod_3_name": "🩸 HP回復 % (量子再生コア)",
		"hk_mod_3_tag": "回復\n%",
		"hk_mod_4_name": "🧪 -HP / +MP (錬金変換コア)",
		"hk_mod_4_tag": "-HP\n+MP",
		"hk_mod_restore_name": "🔧 [ コアを通常に復元 ] (費用: 宝箱 1)",
		"hk_btn_back_crew": "[ESC] 戻る / 別のメンバーを選択",
		"popup_battery_applied_title": "★ コア改造成功！",
		"popup_battery_applied_desc": "%s のコアが再調整されました！",
		"popup_battery_restored_title": "★ コア復元完了！",
		"popup_battery_restored_desc": "%s のコアが通常状態に復元されました！",
		"hk_no_treasure_restore": "リソース不足！ コア復元には宝箱が1つ必要です。",

		# Popups of Defeated Masters
		"popup_master_drone_title": "★ ヴィクター・プライム撃破！",
		"popup_master_drone_desc": "ドローンの主が粉砕された！\nステーション内の全ドローンの能力値が50%低下し、粛清モードが発生しなくなります。",
		"popup_master_mutante_title": "★ Dr.ゴルゴラス討伐！",
		"popup_master_mutante_desc": "ミュータントの主が討ち取られた！\nステーション内の全変異獣の能力値が50%低下し、粛清モードが発生しなくなります。",
		"popup_master_androide_title": "★ ヴァレリア X-9 停止！",
		"popup_master_androide_desc": "アンドロイドの主が解体された！\nステーション内の全汚染アンドロイドの能力値が50%低下し、粛清モードが発生しなくなります。",
		"popup_master_alien_title": "★ サイロックス殲滅！",
		"popup_master_alien_desc": "エイリアンの主が排除された！\nステーション内の全斥候エイリアンの能力値が50%低下し、粛清モードが発生しなくなります。",

		# Popups e Eventos
		"popup_detector_title": "★ 貴重な戦利品を獲得！",
		"popup_detector_desc": "敵群が金属探知機をドロップした！\n(高速ソナー音で床下の隠しカプセル位置を知らせます)。",
		"popup_csouter_title": "★ C-スカウター獲得成功！",
		"popup_csouter_desc": "光学レーダーを装備！ (戦闘時、敵群の総戦闘力「PL」を視界バイザーに表示します)。",
		"popup_spooter_buff_title": "★ スペース・スプーターバフ発動！",
		"popup_spooter_buff_desc": "「絶対防御」を獲得！ (生存メンバー4人が揃っている時、「防御」で受けるダメージを100%無効化します)。",
		"popup_datadrive_title": "★ データドライブの調整完了！",
		"popup_datadrive_desc": "%sにデータドライブを同期！\n(レベルと経験値が隊長と同期され、今後の経験値損失を防止します)。",
		"popup_chronodox_title": "★ 秘宝アーティファクト発見！",
		"popup_chronodox_desc": "部隊は計り知れない価値を持つ秘宝「クロノドックス」を獲得した！",
		"popup_chronodox_kira_desc": "クロノドックスを獲得し、キラが部隊に復帰した！",
		"popup_kira_away_warn": "キラは進みの遅さに痺れを切らし、部隊から離脱した！\n(単独で先行したため、発見されるまで戦闘に参加しません)。",
		"popup_kira_away_title": "⚠ 警告:",
		"popup_level_up_title": "戦術レベルアップ！",
		"popup_level_up_body": "%s ステータスが上昇した！",
		"esc_confirm_title": "タイトルに戻りますか？",
		"esc_confirm_yes": "はい (終了)",
		"esc_confirm_no": "いいえ",

		# Party Menu
		"party_title": "部隊ステータス",
		"party_subtitle": "戦術記録・装備スロット・部隊能力値",
		"party_cargo": "装備",
		"party_status_alive": "生存",
		"party_status_dead": "戦闘不能",
		"party_status_away": "離脱中",
		"party_footer": "[TAB] / [ESC] 迷宮に戻る",
		"party_spooter_banner": "★ スペース・スプーターバフ: 絶対防御: メンバー4人全員生存時、「防御」で受けるダメージを100%無効化",

		# Combate
		"battle_boss_badge": "★ 時間の皇帝 - 最終ボス ★",
		"battle_purge_badge": "⚠ 粛清プロトコル作動中 ⚠",
		"battle_weakened_badge": "▼ 統率崩壊 (-50% 能力値) ▼",
		"battle_act_attack": "[1] 単体攻撃",
		"battle_act_skills": "[2] スキル",
		"battle_act_defend": "[3] 防御",
		"battle_act_defend_buff": "[3] ★ 絶対防御",
		"battle_act_flee": "[4] 逃走 (部隊)",
		"battle_skill_aoe": "[1] 範囲魔法 (15 MP)",
		"battle_skill_heal_single": "[2] 単体回復 (10 MP)",
		"battle_skill_drive": "[3] ドライブ (25 MP)",
		"battle_skill_taunt": "[3] 挑発 (20 MP)",
		"battle_skill_obscure": "[3] オブスキュア (25 MP)",
		"battle_skill_heal_party": "[3] 全体回復 (20 MP)",
		"battle_skill_locked_fmt": "[3] %s [Lv.5で解放]",
		"battle_skill_back": "[4] 戻る",
		"battle_csouter_title": "◈ C-SOUTER レーダー ◈",
		"battle_csouter_readout": "対象: %s\n個体数: %d\n総PL: [ %d ]",

		# Game Over & Relatórios
		"gameover_title": "隊長戦死\n作戦失敗",
		"mission_report_title": "作戦報告:",
		"gameover_stats": "• 到達階層:      %d\n• 撃破敵数:      %d\n• 獲得宝箱:      %d\n• クロノドックス:  %s\n• 生存仲間:      %d / 4",
		"gameover_retry_btn": "タイトルに戻る",
		"chronodox_found": "回収成功",
		"chronodox_not_found": "未発見",

		# Créditos
		"victory_title": "作戦完了\nSTATION ABYSS 攻略",
		"victory_stats": "• 最終到達階層:            %d\n• 撃破敵数:                %d\n• 獲得宝箱:                %d\n• クロノドックス:          %s\n• 部隊状況:                生存",
		"victory_prompt": "[ SPACE / ENTER キーでメニューへ戻る ]"
	}
}

static func set_language(lang: String) -> void:
	if lang in ["pt", "en", "ja"]:
		current_language = lang

static func t(key: String, default_text: String = "") -> String:
	var lang_dict = STRINGS.get(current_language, STRINGS["pt"])
	if lang_dict.has(key):
		return lang_dict[key]
	if STRINGS["pt"].has(key):
		return STRINGS["pt"][key]
	return default_text if default_text != "" else key

static func get_text(key: String, default_text: String = "") -> String:
	return t(key, default_text)
