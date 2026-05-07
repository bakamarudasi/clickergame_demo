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

# --- アニメーション・時間 -----------------------------------------------
const TOAST_HOLD_SEC := 1.4
const TOAST_FADE_SEC := 0.6
const PORTRAIT_CLICK_SQUASH := 0.05
const PORTRAIT_CLICK_DURATION := 0.08

# --- Theme variation 名（.tscn の theme_type_variation で使う） --------
const VAR_DISPLAY_BUTTON := &"DisplayButton"   # FONT_DISPLAY
const VAR_TAB_BUTTON := &"TabButton"           # FONT_SUBTITLE
const VAR_DISPLAY_LABEL := &"DisplayLabel"     # FONT_HUGE
const VAR_LARGE_LABEL := &"LargeLabel"         # FONT_LARGE
const VAR_TITLE_LABEL := &"TitleLabel"         # FONT_TITLE
const VAR_SUBTITLE_LABEL := &"SubtitleLabel"   # FONT_SUBTITLE
