class_name UIConstants
extends Object

# UI 関連の数値・色・時間の唯一の真実。ここを変えれば全タブに反映される。
# .tscn 側は theme_type_variation 経由でフォントサイズを参照する。
# .gd 側は UIConstants.* を直接参照する。

# --- 画面レイアウト -----------------------------------------------------
const SIDEBAR_WIDTH := 140
const OPERATOR_LIST_WIDTH := 180
const STATUS_BAR_HEIGHT := 64

# --- フォントサイズ（semantic） ----------------------------------------
const FONT_DISPLAY := 64       # CLICK ボタン等の主役
const FONT_HUGE := 32          # オペ名など特大表示
const FONT_LARGE := 28         # 通貨表示
const FONT_TITLE := 24         # セクション見出し
const FONT_SUBTITLE := 22      # タブボタン・トースト
const FONT_BODY := 18          # デフォルト
const FONT_SMALL := 14         # 補助

# --- 余白 ----------------------------------------------------------------
const SEP_TIGHT := 4
const SEP_SMALL := 6
const SEP_DEFAULT := 8
const SEP_MEDIUM := 12
const SEP_WIDE := 16
const SEP_LOOSE := 24

# --- 色 ------------------------------------------------------------------
const COLOR_BG := Color(0.12, 0.14, 0.2, 1.0)
const COLOR_BG_PANEL := Color(0.16, 0.18, 0.24, 1.0)
const COLOR_TEXT := Color(0.92, 0.92, 0.95, 1.0)
const COLOR_ACCENT := Color(0.85, 0.45, 0.55, 1.0)
const COLOR_WARN := Color(0.95, 0.6, 0.3, 1.0)

# レア度カラー（強化カードの枠・名前色）
const RARITY_COLORS := {
	Enums.UpgradeRarity.COMMON: Color(0.62, 0.66, 0.72, 1.0),
	Enums.UpgradeRarity.RARE: Color(0.35, 0.65, 0.98, 1.0),
	Enums.UpgradeRarity.EPIC: Color(0.78, 0.45, 0.95, 1.0),
	Enums.UpgradeRarity.LEGENDARY: Color(1.0, 0.78, 0.25, 1.0),
}
const RARITY_PANEL_BG := Color(0.14, 0.16, 0.22, 1.0)
const RARITY_PANEL_BG_DISABLED := Color(0.10, 0.11, 0.15, 1.0)
const CARD_GLOW_PERIOD := 1.6      # 買えるカードの脈動周期（秒）
const CARD_GLOW_MIN := 0.85        # 脈動最小 modulate.v
const CARD_GLOW_MAX := 1.15        # 脈動最大 modulate.v

# メタ強化の3柱カラー（カード枠・名前色用）
const PILLAR_COLORS := {
	Enums.MetaPillar.AFFINITY: Color(0.95, 0.45, 0.65, 1.0),
	Enums.MetaPillar.ECONOMY: Color(0.95, 0.78, 0.30, 1.0),
	Enums.MetaPillar.CATALOG: Color(0.55, 0.70, 0.98, 1.0),
}

# --- アニメーション・時間 -----------------------------------------------
const TOAST_HOLD_SEC := 1.4
const TOAST_FADE_SEC := 0.6
const PORTRAIT_CLICK_SQUASH := 0.05
const PORTRAIT_CLICK_DURATION := 0.08
const CLICK_WIGGLE_DEG := 2.5                # クリック時のランダム回転幅（±度）
const CLICK_POPUP_RISE_PX := 90.0            # +N ポップアップの上昇量
const CLICK_POPUP_DURATION := 0.7            # +N ポップアップの寿命（秒）

# --- ゲームバランス --------------------------------------------------------
const INSPECTION_COOLDOWN_SEC := 300.0       # 検査クールダウン（実時間秒、テスト時は短く）
const XRAY_SUSPICION_PER_SEC := 1.0          # 眼鏡ON中の suspicion 加算/秒
const XRAY_SUSPICION_THRESHOLD := 30.0       # この値で発覚
const XRAY_POSE_SHOW_SEC := 4.0              # 高信頼バレ時に見せつけポーズを表示する時間

# 発情度（arousal）まわり。詳細設計は OperatorRuntime と GameState.add_arousal を参照。
const AROUSAL_MAX := 100.0                   # 0..この値の範囲でクランプ
const AROUSAL_DECAY_PER_SEC := 1.0           # 何もしないと毎秒これだけ減る
const AROUSAL_INTIMACY_BOOST_PER_100 := 1.0  # 親密度100ごとに増加量+100% (×2倍)

# ゴールデン書類（Workタブのランダムボーナス）
const GOLDEN_INTERVAL_MIN_SEC := 180.0       # 出現間隔の下限（3分）
const GOLDEN_INTERVAL_MAX_SEC := 420.0       # 出現間隔の上限（7分）
const GOLDEN_LIFETIME_SEC := 12.0            # 画面横断にかける時間（=見逃し許容秒数）
const GOLDEN_BONUS_PER_CLICK := 25           # click_power 比例ボーナスの倍率
const GOLDEN_BONUS_PCT_OF_PILE := 0.07       # 現在通貨の何%をボーナスにするか
const GOLDEN_BONUS_FLOOR := 50               # 最低保証ボーナス
const GOLDEN_SIZE_PX := 96.0
const GOLDEN_TINT_COLOR := Color(1.4, 1.15, 0.4)

# Room タブのアイドルフレーバー段階タイマー（最後の操作から経過秒）
const IDLE_STAGE_1_SEC := 60.0      # 1分：軽い独り言
const IDLE_STAGE_2_SEC := 180.0     # 3分：牽制
const IDLE_STAGE_3_SEC := 300.0     # 5分：ロックオン
const IDLE_FIRE_SEC := 360.0        # 6分：発火（バフ付与）
const IDLE_BUFF_MULT := 2.0         # 発火時の click 倍率
const IDLE_BUFF_DURATION_SEC := 60.0  # バフ持続秒

# --- Theme variation 名（.tscn の theme_type_variation で使う） --------
const VAR_DISPLAY_BUTTON := &"DisplayButton"   # FONT_DISPLAY
const VAR_TAB_BUTTON := &"TabButton"           # FONT_SUBTITLE
const VAR_DISPLAY_LABEL := &"DisplayLabel"     # FONT_HUGE
const VAR_LARGE_LABEL := &"LargeLabel"         # FONT_LARGE
const VAR_TITLE_LABEL := &"TitleLabel"         # FONT_TITLE
const VAR_SUBTITLE_LABEL := &"SubtitleLabel"   # FONT_SUBTITLE
