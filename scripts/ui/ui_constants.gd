class_name UIConstants
extends Object

# UI 関連の数値・色・時間の唯一の真実。ここを変えれば全タブに反映される。
# .tscn 側は theme_type_variation 経由でフォントサイズを参照する。
# .gd 側は UIConstants.* を直接参照する。
#
# テーマ：サイバー寄りのダーク基調（濃紺ベース＋シアンアクセント）。
# 「木札」「コルクボード」「紙の書類」は使わず、鋭角・薄ボーダー・サイドアクセントで統一。

# --- 画面レイアウト -----------------------------------------------------
const SIDEBAR_WIDTH := 156
const OPERATOR_LIST_WIDTH := 180
const STATUS_BAR_HEIGHT := 64
const ACCENT_STRIPE_WIDTH := 4       # カード左端のレア度アクセント
const HAIRLINE := 1                  # 罫線・パネル枠の太さ
const PANEL_CORNER_RADIUS := 4       # 角の丸み（ほぼ直角）

# --- フォントサイズ（semantic） ----------------------------------------
const FONT_DISPLAY := 64       # CLICK ボタン等の主役
const FONT_HUGE := 32          # オペ名など特大表示
const FONT_LARGE := 28         # 通貨表示
const FONT_TITLE := 22         # セクション見出し
const FONT_SUBTITLE := 18      # タブボタン・トースト
const FONT_BODY := 16          # デフォルト
const FONT_SMALL := 13         # 補助

# --- 余白 ----------------------------------------------------------------
const SEP_TIGHT := 4
const SEP_SMALL := 6
const SEP_DEFAULT := 8
const SEP_MEDIUM := 12
const SEP_WIDE := 16
const SEP_LOOSE := 24

# --- 色（サイバー・ブルー） ---------------------------------------------
# 背景レイヤー。BG → PANEL → PANEL_DEEP の順に明度が下がる。
const COLOR_BG := Color(0.055, 0.078, 0.106, 1.0)             # #0E141B
const COLOR_BG_PANEL := Color(0.086, 0.122, 0.165, 1.0)       # #161F2A
const COLOR_BG_PANEL_DEEP := Color(0.043, 0.067, 0.094, 1.0)  # #0B1118
const COLOR_BG_HEADER := Color(0.106, 0.165, 0.239, 1.0)      # #1B2A3D
const COLOR_BG_HOVER := Color(0.137, 0.196, 0.275, 1.0)       # #233246
const COLOR_BG_ACTIVE := Color(0.071, 0.318, 0.553, 1.0)      # #12518D（ターコイズ寄り）

# テキスト
const COLOR_TEXT := Color(0.902, 0.933, 0.961, 1.0)           # #E6EEF5
const COLOR_TEXT_DIM := Color(0.482, 0.545, 0.620, 1.0)       # #7B8B9E
const COLOR_TEXT_DISABLED := Color(0.290, 0.337, 0.408, 1.0)  # #4A5668
const COLOR_TEXT_INK := Color(0.055, 0.078, 0.106, 1.0)       # ボタン文字（明背景時）

# 罫線・枠
const COLOR_BORDER := Color(0.176, 0.231, 0.306, 1.0)         # #2D3B4E
const COLOR_BORDER_BRIGHT := Color(0.247, 0.337, 0.439, 1.0)  # #3F5670
const COLOR_BORDER_ACCENT := Color(0.365, 0.812, 0.969, 1.0)  # シアン枠

# アクセント
const COLOR_ACCENT_CYAN := Color(0.365, 0.812, 0.969, 1.0)    # #5DCFF7
const COLOR_ACCENT_BLUE := Color(0.247, 0.663, 0.961, 1.0)    # #3FA9F5
const COLOR_ACCENT_CYAN_DIM := Color(0.365, 0.812, 0.969, 0.35)

# セマンティック
const COLOR_WARN := Color(1.0, 0.627, 0.251, 1.0)             # #FFA040
const COLOR_DANGER := Color(1.0, 0.353, 0.431, 1.0)           # #FF5A6E
const COLOR_SUCCESS := Color(0.416, 0.910, 0.612, 1.0)        # #6AE89C

# トースト
const COLOR_TOAST_BG := Color(0.043, 0.067, 0.094, 0.92)

# レア度カラー（アークナイツ寄り：金→紫→シアン→グレー）
const RARITY_COLORS := {
	Enums.UpgradeRarity.COMMON: Color(0.604, 0.647, 0.690, 1.0),    # #9AA5B0
	Enums.UpgradeRarity.RARE: Color(0.302, 0.816, 0.882, 1.0),      # #4DD0E1
	Enums.UpgradeRarity.EPIC: Color(0.780, 0.478, 0.910, 1.0),      # #C77AE8
	Enums.UpgradeRarity.LEGENDARY: Color(1.0, 0.784, 0.341, 1.0),   # #FFC857
}
# カードの背景（暗）と無効時の沈み色
const RARITY_PANEL_BG := Color(0.086, 0.122, 0.165, 1.0)        # = COLOR_BG_PANEL
const RARITY_PANEL_BG_DISABLED := Color(0.055, 0.078, 0.106, 1.0)  # = COLOR_BG
const RARITY_PANEL_BG_MAXED := Color(0.063, 0.180, 0.169, 1.0)
const CARD_GLOW_PERIOD := 1.6      # 買えるカードの脈動周期（秒）
const CARD_GLOW_MIN := 0.92
const CARD_GLOW_MAX := 1.10

# メタ強化の3柱カラー
const PILLAR_COLORS := {
	Enums.MetaPillar.AFFINITY: Color(0.949, 0.451, 0.651, 1.0),   # ピンク
	Enums.MetaPillar.ECONOMY: Color(1.0, 0.784, 0.341, 1.0),      # 金
	Enums.MetaPillar.CATALOG: Color(0.365, 0.812, 0.969, 1.0),    # シアン
}

# --- アニメーション・時間 -----------------------------------------------
const TOAST_HOLD_SEC := 1.4
const TOAST_FADE_SEC := 0.6
const PORTRAIT_CLICK_SQUASH := 0.05
const PORTRAIT_CLICK_DURATION := 0.08
const CLICK_WIGGLE_DEG := 2.5
const CLICK_POPUP_RISE_PX := 90.0
const CLICK_POPUP_DURATION := 0.7

# --- ゲームバランス --------------------------------------------------------
const INSPECTION_COOLDOWN_SEC := 300.0
const XRAY_SUSPICION_PER_SEC := 1.0
const XRAY_SUSPICION_THRESHOLD := 30.0
const XRAY_POSE_SHOW_SEC := 4.0

const AROUSAL_MAX := 100.0
const AROUSAL_DECAY_PER_SEC := 1.0
const AROUSAL_INTIMACY_BOOST_PER_100 := 1.0

const GOLDEN_INTERVAL_MIN_SEC := 180.0
const GOLDEN_INTERVAL_MAX_SEC := 420.0
const GOLDEN_LIFETIME_SEC := 12.0
const GOLDEN_BONUS_PER_CLICK := 25
const GOLDEN_BONUS_PCT_OF_PILE := 0.07
const GOLDEN_BONUS_FLOOR := 50
const GOLDEN_SIZE_PX := 96.0
const GOLDEN_TINT_COLOR := Color(1.0, 0.85, 0.35)

const IDLE_STAGE_1_SEC := 60.0
const IDLE_STAGE_2_SEC := 180.0
const IDLE_STAGE_3_SEC := 300.0
const IDLE_FIRE_SEC := 360.0
const IDLE_BUFF_MULT := 2.0
const IDLE_BUFF_DURATION_SEC := 60.0

# --- Theme variation 名（.tscn の theme_type_variation で使う） --------
const VAR_DISPLAY_BUTTON := &"DisplayButton"   # FONT_DISPLAY
const VAR_TAB_BUTTON := &"TabButton"           # サイドバーのタブ（左端アクセント付き）
const VAR_PILL_BUTTON := &"PillButton"         # カテゴリ／柱トグル
const VAR_ACCENT_BUTTON := &"AccentButton"     # 主アクション（購入等）にシアン強調
const VAR_DISPLAY_LABEL := &"DisplayLabel"     # FONT_HUGE
const VAR_LARGE_LABEL := &"LargeLabel"         # FONT_LARGE
const VAR_TITLE_LABEL := &"TitleLabel"         # FONT_TITLE
const VAR_SUBTITLE_LABEL := &"SubtitleLabel"   # FONT_SUBTITLE
const VAR_SECTION_HEADER := &"SectionHeader"   # 各タブの見出し（左にシアンバー）
const VAR_NUMERIC_LABEL := &"NumericLabel"     # コスト・数値（少し太め強調）
const VAR_DIM_LABEL := &"DimLabel"             # 補助テキスト
