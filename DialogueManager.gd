# DialogueManager.gd
extends Node

signal dialogue_triggered(payload: Dictionary)
signal dialogue_ended

@export var min_interval: float = 18.0
@export var max_interval: float = 28.0

var chatter_timer: Timer
var display_timer: Timer

var is_active: bool = true
var is_intro_running: bool = false
var is_showing_dialogue: bool = false
var is_system_message_blocking: bool = false
var dialogue_queue: Array = []
var party_system_ref: Node = null
var sequence_finish_cb: Callable = Callable()

const DIALOGUES_PT = {
	"intro": [
		{"character_id": "humano", "text": "Finalmente... Station Abyss. É aqui que está o Chronodox de Khen-Shalom."},
		{"character_id": "alien", "text": "Khen-Shalom? Os sábios do meu clã o descrevem como \"O Demônio cósmico\"."},
		{"character_id": "robo", "text": "Esse tipo de dado não existe, não tem como ser verdade algo assim."},
		{"character_id": "mutante", "text": "Será que dá pra vender essa coisa por um preço alto no leilão intergalático?"}
	],
	"battle_log_stunned": "%s está atordoado e não pode agir neste turno!",
	"vortice_teleporte": [
		{"character_id": "humano", "text": "Ugh! O vórtice distorceu nossas coordenadas... Onde fomos parar?"},
		{"character_id": "mutante", "text": "Eita, que puxão dimensional doido! Minha cabeça tá rodando!"},
		{"character_id": "alien", "text": "A instabilidade quântica nos arremessou através da dobra do setor."},
		{"character_id": "robo", "text": "Anomalia gravitacional detectada. Telemetria de posição redefinida."}
	],
	"queda_andar_unit7": "Impacto inercial absorvido. Cálculos estruturais indicam: caímos %d andar(es).",
	"mestre_derrotado": [
		{"character_id": "humano", "text": "O líder deles caiu! A cadeia de comando dessa raça na estação inteira foi quebrada."},
		{"character_id": "mutante", "text": "Viu só quem manda aqui?! Agora os capangas menores vão tremer só de sentir nosso cheiro!"},
		{"character_id": "alien", "text": "A mente central foi extirpada. Os remanescentes perderam metade de sua ressonância vital."},
		{"character_id": "robo", "text": "Rede neural do esquadrão inimigo rompida. Eficiência de combate da raça reduzida em 50%."}
	],
	"orb_recuperada": [
		{"character_id": "humano", "text": "Dados absorvidos com sucesso. A integridade tática foi restabelecida."},
		{"character_id": "mutante", "text": "Aee! Sinto o sangue esquentar de novo! Tô no mesmo pique do Capitão!"},
		{"character_id": "alien", "text": "A dispersão quântica de dados foi reabsorvida. Sintonia com o éter restaurada."},
		{"character_id": "robo", "text": "Sobrecarga de memória recuperada. Sincronização neural com o líder em 100%."}
	],
	"detector_encontrado": [
		{"character_id": "humano", "text": "Este sensor capta ressonâncias metálicas nos corredores. Agora saberemos onde há tesouros escondidos!"},
		{"character_id": "mutante", "text": "Um apitador de metal? Gostei, vai achar sucata brilhante pra gente sem eu ter que chutar a parede!"},
		{"character_id": "alien", "text": "A frequência de sonar deste dispositivo revela anomalias densas sob as placas do piso."},
		{"character_id": "robo", "text": "Calibrando módulo de radar geológico. Alcance de varredura acoplado ao visor da equipe."}
	],
	"csouter_encontrado": [
		{"character_id": "humano", "text": "Um radar de telemetria C-Souter! Agora podemos escanear o poder de luta total das hordas em combate!"},
		{"character_id": "mutante", "text": "Olha que visor invocado! Agora dá pra ver o quanto os monstros são fortes antes de quebrar eles!"},
		{"character_id": "alien", "text": "A lente de prisma quântico deste C-Souter quantifica o fluxo bio-energético dos inimigos."},
		{"character_id": "robo", "text": "Interface C-Souter sincronizada. Cálculo de PDL (Poder De Luta) ativo na tela tática."}
	],
	"tropeco_tesouro": [
		{"character_id": "humano", "text": "Opa! Quase caí... mas havia uma cápsula de suprimentos soterrada aqui no piso!"},
		{"character_id": "mutante", "text": "Ai, bati a pata em alguma coisa dura... Opa, é tesouro largado na poeira!"},
		{"character_id": "alien", "text": "Meus passos colidiram com um compartimento lacrado camuflado pelo entulho."},
		{"character_id": "robo", "text": "Impacto inercial registrado nos sensores inferiores. Identificado recipiente de suprimentos intacto."}
	],
	"arcade_spooter_recompensa": [
		{"character_id": "humano", "text": "O terminal desligou completamente... mas sinto uma blindagem de energia vibrando pelo meu corpo!"},
		{"character_id": "mutante", "text": "Caraca, o terminal apagou do nada! Mas ó, minha pele tá parecendo uma carapaça de titânio!"},
		{"character_id": "alien", "text": "O fluxo quântico deste terminal recalibrou nossos campos moleculares. Nossa postura de defesa atingiu a perfeição."},
		{"character_id": "robo", "text": "Terminal em modo standby permanente. Sobrecarga de dados convertida em barreira inercial impenetrável."}
	],
	"arcade_spooter_derrota": [
		{"character_id": "humano", "text": "Droga! Aquele meteoro saiu do nada! Minhas táticas militares falharam contra um fliperama..."},
		{"character_id": "mutante", "text": "Nããão! Aquele asteroide bateu de pontada! Essa máquina tá roubando!"},
		{"character_id": "alien", "text": "Calculou errado a trajetória gravitacional... Os meteoros da simulação desafiam a física estelar."},
		{"character_id": "robo", "text": "Erro 404: Habilidade de pilotagem não encontrada. Solicitando reembolso de fichas fictícias."}
	],
	"cura_disponivel": [
		{"character_id": "humano", "text": "Pod médico ativo. Recomponham-se, esquadrão. Ainda temos muitos setores pela frente."},
		{"character_id": "mutante", "text": "Ahhh, que alívio nessas garras! Pronta pra rasgar mais lataria de robô!"},
		{"character_id": "alien", "text": "As bio-células restauraram o fluxo da minha energia elemental."},
		{"character_id": "robo", "text": "Ciclo de nano-reparo concluído em 100%. Integridade estrutural restabelecida."}
	],
	"magia_cura_campo": [
		{"character_id": "humano", "text": "Essa bio-energia restaurou minhas forças. Me sinto pronto para avançar!"},
		{"character_id": "mutante", "text": "Ahh, essa magia fecha os cortes rapidinho! Minhas garras estão novinhas em folha!"},
		{"character_id": "alien", "text": "O fluxo vital foi realinhado com o éter. Meus tecidos celulares estabilizaram-se."},
		{"character_id": "robo", "text": "Protocolo de auto-reparo concluído. Danos estruturais reduzidos aos parâmetros nominais."}
	],
	"bau_encontrado": [
		{"character_id": "humano", "text": "Suprimentos militares resgatados. Toda vantagem é crucial nessa estação."},
		{"character_id": "mutante", "text": "Mais espólios e sucata valiosa! Isso vai render uma fortuna depois!"},
		{"character_id": "alien", "text": "Componentes tecnológicos curiosos... a engenharia desta estação é ancestral."},
		{"character_id": "robo", "text": "Recursos materiais catalogados e alocados nos compartimentos da equipe."}
	],
	"chave_encontrada": [
		{"character_id": "humano", "text": "Chave de acesso obtida! A Passagem para o próximo andar está liberada!"},
		{"character_id": "mutante", "text": "Aí sim, achamos o passe livre! Agora é só abrir caminho na força até a saída!"},
		{"character_id": "alien", "text": "O cristal de frequência ressonou. A passagem dimensional para o próximo andar se abrirá."},
		{"character_id": "robo", "text": "Código criptográfico mestre descriptografado. Portal do setor desbloqueado."}
	],
	"alarme_seguranca": [
		{"character_id": "humano", "text": "Atenção equipe! A remoção da chave ativou os protocolos de segurança. Inimigos em alerta máximo!"},
		{"character_id": "mutante", "text": "Opa, parece que o alarme acordou a estação inteira! Podem vir, não tenho medo!"},
		{"character_id": "alien", "text": "Sinto as assinaturas de plasma da estação aumentando... as defesas de purga despertaram."},
		{"character_id": "robo", "text": "Alerta vermelho. Sistema de segurança acionado. Força de contenção hostil detectada."}
	],
	"porta_trancada": [
		{"character_id": "humano", "text": "O portal exige a chave de segurança deste andar. Precisamos explorar os outros corredores."},
		{"character_id": "mutante", "text": "Trancado por biometria e campo de força... Vamos vasculhar os baús desse setor!"},
		{"character_id": "alien", "text": "A barreira de energia está ativa. O núcleo da chave ainda não foi inserido."},
		{"character_id": "robo", "text": "Acesso negado. Requer chave criptográfica primária para acessar."}
	],
	"corredor_escuro": [
		{"character_id": "humano", "text": "Mantenham a formação. A iluminação aqui está falhando e sensores indicam movimento."},
		{"character_id": "mutante", "text": "Minhas vibrissas e sentidos estão agitados... Tem coisa rastejando nas sombras."},
		{"character_id": "alien", "text": "As correntes de éter estão instáveis neste setor da estação."},
		{"character_id": "robo", "text": "Níveis de luminosidade em 18%. Recomendo cautela redobrada em cruzamentos."}
	],
	"idle_chatter": [
		{"character_id": "humano", "text": "Mantenham o foco. O Chronodox não pode cair em mãos erradas."},
		{"character_id": "mutante", "text": "Se eu encontrar o desgraçado que projetou esse labirinto, vou usar de arranhador."},
		{"character_id": "alien", "text": "Este complexo orbital flutua no abismo estelar há eras incontáveis..."},
		{"character_id": "robo", "text": "Baterias e sistemas de suporte de vida da equipe operando dentro dos parâmetros normais."}
	]
}

const DIALOGUES_EN = {
	"intro": [
		{"character_id": "humano", "text": "Finally... Station Abyss. This is where Khen-Shalom's Chronodox lies."},
		{"character_id": "alien", "text": "Khen-Shalom? The elders of my clan describe him as \"The Cosmic Demon\"."},
		{"character_id": "robo", "text": "Such data does not exist in our archives; this cannot be factual."},
		{"character_id": "mutante", "text": "Can we fetch a high price for this trinket at the intergalactic auction?"}
	],
	"battle_log_stunned": "%s is stunned and cannot act this turn!",
	"vortice_teleporte": [
		{"character_id": "humano", "text": "Ugh! The vortex warped our coordinates... Where did we end up?"},
		{"character_id": "mutante", "text": "Whoa, what a wild dimensional pull! My head is spinning!"},
		{"character_id": "alien", "text": "Quantum instability hurled us across the sector's fold."},
		{"character_id": "robo", "text": "Gravitational anomaly detected. Position telemetry reset."}
	],
	"queda_andar_unit7": "Inertial impact absorbed. Structural calculations indicate: we fell %d floor(s).",
	"mestre_derrotado": [
		{"character_id": "humano", "text": "Their master has fallen! The chain of command for this species has been shattered."},
		{"character_id": "mutante", "text": "Did you see who's boss?! The rest of their flunkies will flee at our sight!"},
		{"character_id": "alien", "text": "The central consciousness has been severed. Surviving remnants lost half their vital resonance."},
		{"character_id": "robo", "text": "Enemy neural network destroyed. Combat efficiency of this species reduced by 50%."}
	],
	"orb_recuperada": [
		{"character_id": "humano", "text": "Data absorbed successfully. Tactical integrity has been restored."},
		{"character_id": "mutante", "text": "Hell yeah! I feel my blood pumping again! Back on the Captain's pace!"},
		{"character_id": "alien", "text": "Quantum data dispersion reabsorbed. Attunement with the ether restored."},
		{"character_id": "robo", "text": "Memory overflow recovered. Neural synchronization with the leader at 100%."}
	],
	"detector_encontrado": [
		{"character_id": "humano", "text": "This sensor detects metallic resonance along corridors. Now we'll locate hidden caches!"},
		{"character_id": "mutante", "text": "A metal beeper? Nice! It'll find shiny scrap for us without me having to kick walls!"},
		{"character_id": "alien", "text": "The sonar frequency of this device reveals dense anomalies beneath the floor plates."},
		{"character_id": "robo", "text": "Calibrating geological radar module. Scan range linked to squad HUD."}
	],
	"csouter_encontrado": [
		{"character_id": "humano", "text": "A C-Souter telemetry radar! Now we can scan the total power level of enemy hordes in combat!"},
		{"character_id": "mutante", "text": "Look at this badass visor! Now we can see how tough monsters are before smashing them!"},
		{"character_id": "alien", "text": "The quantum prism lens of this C-Souter quantifies the bio-energetic flow of enemies."},
		{"character_id": "robo", "text": "C-Souter interface synchronized. PL (Power Level) telemetry active on tactical display."}
	],
	"tropeco_tesouro": [
		{"character_id": "humano", "text": "Whoa! Almost tripped... but there was a supply capsule buried right here in the floor!"},
		{"character_id": "mutante", "text": "Ouch, stubbed my paw on something hard... Oh wait, it's loot left in the dust!"},
		{"character_id": "alien", "text": "My steps collided with a sealed cache concealed by the debris."},
		{"character_id": "robo", "text": "Inertial impact registered on lower sensors. Identified intact supply container."}
	],
	"arcade_spooter_recompensa": [
		{"character_id": "humano", "text": "The terminal shut down completely... but I feel an energy shield humming through my body!"},
		{"character_id": "mutante", "text": "Damn, the machine just died! But hey, my skin feels like a titanium carapace!"},
		{"character_id": "alien", "text": "The quantum flux of this terminal recalibrated our molecular fields. Our defensive posture is perfected."},
		{"character_id": "robo", "text": "Terminal in permanent standby mode. Data overload converted into an impenetrable inertial barrier."}
	],
	"arcade_spooter_derrota": [
		{"character_id": "humano", "text": "Damn it! That asteroid came out of nowhere! My military training failed against an arcade game..."},
		{"character_id": "mutante", "text": "Nooo! That asteroid clipped me on the edge! This machine is cheating!"},
		{"character_id": "alien", "text": "Miscalculated gravitational trajectory... The simulation's asteroids defy stellar physics."},
		{"character_id": "robo", "text": "Error 404: Piloting skill not found. Requesting simulated token refund."}
	],
	"cura_disponivel": [
		{"character_id": "humano", "text": "Medical pod active. Regroup, squad. We still have many sectors ahead."},
		{"character_id": "mutante", "text": "Ahhh, relief for these claws! Ready to shred more robot metal!"},
		{"character_id": "alien", "text": "The bio-cells restored the flow of my elemental energy."},
		{"character_id": "robo", "text": "Nano-repair cycle 100% complete. Structural integrity restored."}
	],
	"magia_cura_campo": [
		{"character_id": "humano", "text": "This bio-energy restored my strength. I feel ready to push forward!"},
		{"character_id": "mutante", "text": "Ahh, this spell seals cuts so fast! My claws are as good as new!"},
		{"character_id": "alien", "text": "The life flow has realigned with the ether. My cellular tissue has stabilized."},
		{"character_id": "robo", "text": "Self-repair protocol complete. Structural damage reduced to nominal parameters."}
	],
	"bau_encontrado": [
		{"character_id": "humano", "text": "Military supplies salvaged. Every advantage is vital on this station."},
		{"character_id": "mutante", "text": "More loot and valuable scrap! This will fetch a fortune later!"},
		{"character_id": "alien", "text": "Curious tech components... the engineering of this station is ancient."},
		{"character_id": "robo", "text": "Material resources cataloged and stored in squad compartments."}
	],
	"chave_encontrada": [
		{"character_id": "humano", "text": "Access key acquired! The gateway to the next floor is clear!"},
		{"character_id": "mutante", "text": "Hell yeah, we got the hall pass! Now let's smash our way to the exit!"},
		{"character_id": "alien", "text": "The frequency crystal resonated. The dimensional passage to the next floor will open."},
		{"character_id": "robo", "text": "Master cryptographic key decrypted. Sector portal unlocked."},
		{"character_id": "robo", "text": "Floor Key verified! Updating airlock navigation protocol."}
	],
	"alarme_seguranca": [
		{"character_id": "humano", "text": "Heads up, team! Removing the key tripped the security protocol. Hostiles on high alert!"},
		{"character_id": "mutante", "text": "Looks like the alarm woke the whole station! Bring it on, I ain't scared!"},
		{"character_id": "alien", "text": "I sense the station's plasma signatures surging... purge defenses have awakened."},
		{"character_id": "robo", "text": "Red alert. Security system engaged. Hostile containment force detected."}
	],
	"porta_trancada": [
		{"character_id": "humano", "text": "The portal requires this floor's security key. We need to search the other corridors."},
		{"character_id": "mutante", "text": "Locked down by biometrics and a force field... Let's ransack the chests in this sector!"},
		{"character_id": "alien", "text": "The energy barrier is active. The key core has not yet been inserted."},
		{"character_id": "robo", "text": "Access denied. Primary cryptographic key required for access."}
	],
	"corredor_escuro": [
		{"character_id": "humano", "text": "Maintain formation. Lighting is failing here and sensors detect movement."},
		{"character_id": "mutante", "text": "My whiskers and senses are tingling... Something's creeping in the shadows."},
		{"character_id": "alien", "text": "The ether currents are unstable in this sector of the station."},
		{"character_id": "robo", "text": "Luminosity levels at 18%. Heightened caution advised at intersections."}
	],
	"idle_chatter": [
		{"character_id": "humano", "text": "Stay focused. The Chronodox must not fall into the wrong hands."},
		{"character_id": "mutante", "text": "If I ever find the jerk who designed this labyrinth, I'm using them as a scratching post."},
		{"character_id": "alien", "text": "This orbital facility has drifted in the stellar abyss for uncounted ages..."},
		{"character_id": "robo", "text": "Crew life-support systems and battery reserves operating within nominal parameters."}
	]
}

const DIALOGUES_JA = {
	"intro": [
		{"character_id": "humano", "text": "ついに着いたか... Station Abyss。ここにケン・シャロームのクロノドックスが眠っている。"},
		{"character_id": "alien", "text": "ケン・シャローム...？ 我が一族の長老達は彼を「宇宙の悪魔」と呼んでいた。"},
		{"character_id": "robo", "text": "そのようなデータは記録に存在しません。事実とは考えにくいです。"},
		{"character_id": "mutante", "text": "ねえ、その骨董品って闇オークションで高く売れたりするのかしら？"}
	],
	"battle_log_stunned": "%s はスタン状態で行動できない！",
	"vortice_teleporte": [
		{"character_id": "humano", "text": "うっ！ 渦に座標を歪められたか... ここはどこだ？"},
		{"character_id": "mutante", "text": "きゃっ、ものすごい次元の引き寄せね！ 目が回るわ！"},
		{"character_id": "alien", "text": "量子の不安定性が我々をセクターの歪みへと放り投げたようだ。"},
		{"character_id": "robo", "text": "重力異常を検知。位置テレメトリをリセットしました。"}
	],
	"queda_andar_unit7": "慣性衝撃を吸収。構造解析結果: %d 階層落下しました。",
	"mestre_derrotado": [
		{"character_id": "humano", "text": "奴らの長を討ち取った！ この種族全体の統率が完全に崩壊したぞ。"},
		{"character_id": "mutante", "text": "どっちが上か思い知ったかしら？！ これで手下どもも逃げ惑うだけね！"},
		{"character_id": "alien", "text": "主幹知性が消滅した。残党らは生命共鳴の半分を失ったはずだ。"},
		{"character_id": "robo", "text": "敵部隊のニューラルネットワーク切断完了。戦闘効率が50%低下しました。"}
	],
	"orb_recuperada": [
		{"character_id": "humano", "text": "データの吸収に成功。戦術整合性が復元された。"},
		{"character_id": "mutante", "text": "よっしゃー！ 血が滾ってきたわ！ 隊長と同じペースで暴れるわよ！"},
		{"character_id": "alien", "text": "分散していた量子データが再吸収された。エーテルとの調和が戻ったぞ。"},
		{"character_id": "robo", "text": "メモリオーバーフロー解消。リーダーとの神経同期率100%。"}
	],
	"detector_encontrado": [
		{"character_id": "humano", "text": "このセンサーは通路の金属共鳴を感知する。隠された宝箱の位置が特定できるぞ！"},
		{"character_id": "mutante", "text": "金属探知機？ いいじゃない！ 壁を蹴り飛ばさなくてもガラクタが見つかるわ！"},
		{"character_id": "alien", "text": "この装置のソナー周波数は、床板の下にある密度の高い異常を検知している。"},
		{"character_id": "robo", "text": "地質レーダーモジュール校正完了。スキャン範囲を部隊バイザーに接続。"}
	],
	"csouter_encontrado": [
		{"character_id": "humano", "text": "C-スカウターテレメトリレーダーだ！ これで敵群の総戦闘力を戦闘中に解析できる！"},
		{"character_id": "mutante", "text": "イカしたバイザーじゃない！ 叩きのめす前にモンスターの強さが丸見えね！"},
		{"character_id": "alien", "text": "このC-スカウターの量子プリズムレンズは、敵の生体エネルギー流を数値化する。"},
		{"character_id": "robo", "text": "C-スカウターインターフェース同期。戦闘力（PL）計測機能を有効化。"}
	],
	"tropeco_tesouro": [
		{"character_id": "humano", "text": "おっと！ つまずきそうになった... が、床下に物資カプセルが埋もれていたぞ！"},
		{"character_id": "mutante", "text": "痛っ！ 足を固いものにぶつけたわ... って、埃に埋もれたお宝じゃない！"},
		{"character_id": "alien", "text": "我が足が瓦礫に隠された封印コンテナに接触した。"},
		{"character_id": "robo", "text": "下部センサーに慣性衝撃を記録。損傷のない物資コンテナを検知。"}
	],
	"arcade_spooter_recompensa": [
		{"character_id": "humano", "text": "端末は完全に停止したが... 全身に強力なエネルギーシールドが漲っている！"},
		{"character_id": "mutante", "text": "あら、マシンが急に消えたわ！ でも見て、皮膚がチタン装甲みたいにカチカチよ！"},
		{"character_id": "alien", "text": "端末の量子フラックスが我々の分子フィールドを再調整した。防御態勢は完璧だ。"},
		{"character_id": "robo", "text": "端末を永久スタンバイに移行。過剰データを鉄壁の慣性バリアへ変換。"}
	],
	"arcade_spooter_derrota": [
		{"character_id": "humano", "text": "くそっ！ あの隕石はどこから来たんだ！ エリートとしての訓練がゲームに通用しないとは..."},
		{"character_id": "mutante", "text": "いやあああ！ あの小惑星かすったじゃない！ イカサママシンよ！"},
		{"character_id": "alien", "text": "重力軌道の計算ミスか... シミュレーションの隕石は星体物理学を無視している。"},
		{"character_id": "robo", "text": "エラー404: 操縦スキルが見つかりません。コインの返金を要求します。"}
	],
	"cura_disponivel": [
		{"character_id": "humano", "text": "医療ポッド作動。態勢を整えろ、まだ先は長いぞ。"},
		{"character_id": "humano", "text": "稼働中の医療ステーションだ！ 一旦集結して傷の手当をしよう。"},
		{"character_id": "mutante", "text": "ああ〜、爪の先まで生き返るわ！ ロボットのくず鉄を千切りに行くわよ！"},
		{"character_id": "alien", "text": "バイオ細胞が我がエレメンタルエネルギーの流れを修復した。"},
		{"character_id": "robo", "text": "ナノ修復サイクル100%完了。構造的整合性が復旧しました。"}
	],
	"magia_cura_campo": [
		{"character_id": "humano", "text": "生体エネルギーで力が戻った。進む準備はできている！"},
		{"character_id": "mutante", "text": "ふぅ、この魔法は切り傷が一瞬で塞がるわね！ 爪もピカピカよ！"},
		{"character_id": "alien", "text": "生命の流れがエーテルと再調和した。細胞組織が安定している。"},
		{"character_id": "robo", "text": "自己修復プロトコル完了。構造的ダメージは規定値内に収まりました。"}
	],
	"bau_encontrado": [
		{"character_id": "humano", "text": "軍事物資を回収。このステーションではあらゆる物資が貴重だ。"},
		{"character_id": "mutante", "text": "戦利品と貴重なくず鉄ね！ 後で大金に換えてやるわ！"},
		{"character_id": "alien", "text": "興味深い技術パーツだ... このステーションの構造は超古代のものだな。"},
		{"character_id": "robo", "text": "資材リソースを記録し、部隊ストレージへ割り当てました。"}
	],
	"chave_encontrada": [
		{"character_id": "humano", "text": "アクセスキーを獲得！ 次の階層へのルートが開通した！"},
		{"character_id": "mutante", "text": "よっしゃ、通行証ゲットね！ あとは出口まで力ずくで進むだけよ！"},
		{"character_id": "alien", "text": "周波数結晶が共鳴した。次階層への次元通路が開くだろう。"},
		{"character_id": "robo", "text": "マスター暗号コードの解読成功。セクターゲートのロックを解除。"}
	],
	"alarme_seguranca": [
		{"character_id": "humano", "text": "全員警戒せよ！ 鍵の除去で防衛システムが作動した。敵が極限警戒に入ったぞ！"},
		{"character_id": "mutante", "text": "あら、警報でステーション中が目を覚ましたみたいね！ 来なさい、返り討ちよ！"},
		{"character_id": "alien", "text": "ステーションのプラズマ反応が急昇している... 粛清防衛線が覚醒した。"},
		{"character_id": "robo", "text": "緊急警戒。セキュリティシステム作動。敵対的な制御部隊を検知。"}
	],
	"porta_trancada": [
		{"character_id": "humano", "text": "ゲートのロックを解除するにはこの階のキーが必要だ。他の通路を捜索しよう。"},
		{"character_id": "mutante", "text": "生体認証とフォースフィールドでロックされてるわね... このセクターの宝箱を漁りましょう！"},
		{"character_id": "alien", "text": "エネルギー障壁が作動中だ。キーコアがまだ挿入されていない。"},
		{"character_id": "robo", "text": "アクセス拒否。アクセスにはプライマリ暗号キーが必要です。"}
	],
	"corredor_escuro": [
		{"character_id": "humano", "text": "隊形を保て。照明が不調で、センサーに動きが捉えられている。"},
		{"character_id": "mutante", "text": "ヒゲと感覚がビリビリするわ... 影の中で何かが這い回ってるわね。"},
		{"character_id": "alien", "text": "このセクターではエーテルの流れが著しく不安定だ。"},
		{"character_id": "robo", "text": "照度レベル18%。交差点での厳重な警戒を推奨します。"}
	],
	"idle_chatter": [
		{"character_id": "humano", "text": "集中を切らすな。クロノドックスを悪しき者に渡すわけにはいかない。"},
		{"character_id": "mutante", "text": "この迷路を設計した奴を見つけたら、爪の砥石にしてやるわ。"},
		{"character_id": "alien", "text": "この軌道施設は果てしない星々の深淵を幾千年も漂っている..."},
		{"character_id": "robo", "text": "生命維持システムおよびバッテリーは正常範囲内で稼働中。"}
	]
}

func _ready() -> void:
	chatter_timer = Timer.new()
	chatter_timer.one_shot = true
	chatter_timer.timeout.connect(_on_chatter_timer_timeout)
	add_child(chatter_timer)

	display_timer = Timer.new()
	display_timer.one_shot = true
	display_timer.timeout.connect(_on_display_timer_timeout)
	add_child(display_timer)

func get_dialogue_pool() -> Dictionary:
	if Localization.current_language == "ja":
		return DIALOGUES_JA
	elif Localization.current_language == "en":
		return DIALOGUES_EN
	return DIALOGUES_PT

func trigger_floor_fall_dialogue(floors_fallen: int) -> void:
	is_active = true
	is_intro_running = false
	is_system_message_blocking = false
	display_timer.stop()
	if chatter_timer: chatter_timer.stop()
	dialogue_queue.clear()

	var pool = get_dialogue_pool()
	var raw_template = pool.get("queda_andar_unit7", "Impacto inercial absorvido. Cálculos estruturais indicam: caímos %d andar(es).")
	var formatted_text = raw_template % floors_fallen

	dialogue_queue.append({
		"character_id": "robo",
		"speaker": "Unit-7",
		"text": formatted_text
	})
	is_showing_dialogue = false
	_process_queue()

func start_intro_sequence() -> void:
	stop_dialogues()
	is_active = true
	is_intro_running = true
	dialogue_queue.clear()

	var pool = get_dialogue_pool()
	for d in pool["intro"]:
		if not _is_character_muted(d.get("character_id", "")):
			dialogue_queue.append(d.duplicate())

	_process_queue()

func start_chronodox_sequence() -> void:
	stop_dialogues()
	is_active = true
	is_intro_running = false
	dialogue_queue.clear()

	var lang = Localization.current_language
	var dialogues = []
	if lang == "ja":
		dialogues = [
			{"character_id": "robo", "text": "指示を願います、隊長？"},
			{"character_id": "humano", "text": "主要目標は確保した。あとはこのステーションからの脱出ルートを探すだけだ。"},
			{"character_id": "mutante", "text": "私を見ないでよ、このガラクタ迷路じゃ私も同じくらい迷子なんだから..."},
			{"character_id": "alien", "text": "キラの嗅覚でさえ捉えられないなら、通常の出口は存在しないのかもしれんな。"}
		]
	elif lang == "en":
		dialogues = [
			{"character_id": "robo", "text": "What are your orders, Captain?"},
			{"character_id": "humano", "text": "Main objective secured. Now we need to find an exit from this station."},
			{"character_id": "mutante", "text": "Don't look at me, I'm just as lost as you in this scrapheap maze..."},
			{"character_id": "alien", "text": "If not even Kira's scent caught a trail, perhaps there is no conventional exit here."}
		]
	else:
		dialogues = [
			{"character_id": "robo", "text": "Quais as ordens, Capitão?"},
			{"character_id": "humano", "text": "O objetivo principal tá na mão. Agora precisamos achar uma saída desta estação."},
			{"character_id": "mutante", "text": "Não olhem pra mim, eu tô tão perdida quanto vocês nesse labirinto de sucata..."},
			{"character_id": "alien", "text": "Se nem o faro da Kira encontrou algo, talvez não haja uma saída convencional por aqui."}
		]

	for d in dialogues:
		if not _is_character_muted(d.get("character_id", "")):
			dialogue_queue.append(d.duplicate())

	_process_queue()

func trigger_hole_keeper_dialogue(letter: String, on_finish: Callable = Callable()) -> void:
	stop_dialogues()
	is_active = true
	is_intro_running = false
	dialogue_queue.clear()
	sequence_finish_cb = on_finish

	var lang = Localization.current_language
	var text_line = ""
	if lang == "en":
		text_line = "« The previous branch lost the sphere again?! Incompetents! Hand over the Chronodox so I can recalibrate your suit's core. »"
	elif lang == "ja":
		text_line = "« 前の支店がまた球体を紛失しただと？！ 無能め！ クロノドックスを渡せば、スーツのコアを再調整してやる。 »"
	else:
		text_line = "« A filial anterior perdeu a esfera de novo?! Incompetentes! Entregue-me o Chronodox para que eu possa recalibrar o núcleo do seu traje. »"

	dialogue_queue.append({
		"character_id": "khen_dark",
		"speaker": "Hole Keeper " + letter,
		"text": text_line
	})
	_process_queue()

func _is_character_muted(char_id: String) -> bool:
	if char_id == "mutante" and party_system_ref and party_system_ref.is_kira_away:
		return true
	return false

func pause_dialogues() -> void:
	is_system_message_blocking = true
	is_showing_dialogue = false
	dialogue_queue.clear() # Limpa diálogos antigos interrompidos para não tocarem fora de hora!
	if chatter_timer and chatter_timer.time_left > 0: chatter_timer.stop()
	if display_timer and display_timer.time_left > 0: display_timer.stop()
	emit_signal("dialogue_ended")

func resume_dialogues() -> void:
	is_system_message_blocking = false
	is_active = true
	if not is_showing_dialogue:
		if not dialogue_queue.is_empty():
			_process_queue()
		else:
			schedule_next_chatter()

func stop_dialogues() -> void:
	is_active = true
	is_intro_running = false
	is_showing_dialogue = false
	is_system_message_blocking = false
	dialogue_queue.clear()
	if chatter_timer: chatter_timer.stop()
	if display_timer: display_timer.stop()
	emit_signal("dialogue_ended")

func trigger_dialogue(trigger_key: String, character_id: String = "") -> void:
	is_active = true

	if trigger_key == "idle_chatter":
		if is_intro_running or is_showing_dialogue or is_system_message_blocking or dialogue_queue.size() > 0:
			return

	if is_intro_running and trigger_key != "intro":
		is_intro_running = false

	if character_id != "" and _is_character_muted(character_id):
		return

	var pool = get_dialogue_pool()
	var matching: Array = []
	if pool.has(trigger_key):
		for d in pool[trigger_key]:
			var cid = d.get("character_id", "")
			if not _is_character_muted(cid):
				if character_id == "" or cid == character_id:
					matching.append(d)

	if matching.is_empty():
		return

	var chosen: Dictionary = matching[randi() % matching.size()].duplicate()

	if trigger_key != "idle_chatter":
		display_timer.stop()
		is_showing_dialogue = false
		is_system_message_blocking = false
		dialogue_queue.clear()

	dialogue_queue.append(chosen)
	_process_queue()

func _process_queue() -> void:
	if not is_active or is_system_message_blocking:
		return

	if dialogue_queue.is_empty():
		is_showing_dialogue = false
		emit_signal("dialogue_ended")
		if is_intro_running: is_intro_running = false

		if sequence_finish_cb.is_valid():
			var cb = sequence_finish_cb
			sequence_finish_cb = Callable()
			cb.call()

		schedule_next_chatter()
		return

	is_showing_dialogue = true
	var payload: Dictionary = dialogue_queue.pop_front()
	emit_signal("dialogue_triggered", payload)
	display_timer.start(4.0)

func _on_display_timer_timeout() -> void:
	emit_signal("dialogue_ended")
	is_showing_dialogue = false

	if dialogue_queue.is_empty():
		if is_intro_running: is_intro_running = false

		if sequence_finish_cb.is_valid():
			var cb = sequence_finish_cb
			sequence_finish_cb = Callable()
			cb.call()

		schedule_next_chatter()
	else:
		var gap_timer = get_tree().create_timer(1.2)
		gap_timer.timeout.connect(func():
			if is_active and not is_system_message_blocking and not is_showing_dialogue:
				_process_queue()
		)

func schedule_next_chatter() -> void:
	if not is_active or is_intro_running or is_showing_dialogue or is_system_message_blocking: return
	var delay: float = randf_range(min_interval, max_interval)
	chatter_timer.start(delay)

func _on_chatter_timer_timeout() -> void:
	if is_active and not is_intro_running and not is_showing_dialogue and not is_system_message_blocking:
		trigger_dialogue("idle_chatter")
	else:
		schedule_next_chatter()
