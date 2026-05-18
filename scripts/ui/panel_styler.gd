class_name PanelStyler
extends Object

# UI 全体で使う StyleBoxFlat ビルダー。
# 「ダークパネル」「サイドアクセント付きカード」「セクション見出し」など、
# 各タブ・各 factory が同じ意匠で組めるよう、ここに集約する。

# 基本のダークパネル（罫線あり）。タブやパネル枠の汎用。
static func panel_dark(border_color: Color = UIConstants.COLOR_BORDER) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_PANEL
	sbox.border_color = border_color
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_DEFAULT
	sbox.content_margin_bottom = UIConstants.SEP_DEFAULT
	return sbox


# カード（rarity アクセント付き）。左端 4px のカラーバーが特徴。
static func card(accent_color: Color, bg_color: Color = UIConstants.COLOR_BG_PANEL) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = bg_color
	sbox.border_color = UIConstants.COLOR_BORDER
	sbox.border_width_top = UIConstants.HAIRLINE
	sbox.border_width_right = UIConstants.HAIRLINE
	sbox.border_width_bottom = UIConstants.HAIRLINE
	sbox.border_width_left = UIConstants.ACCENT_STRIPE_WIDTH
	# 左端だけアクセントカラー、ほかは薄ボーダー
	# StyleBoxFlat は border_color が単色なので「左だけ別色」は出せない。
	# 代わりに：左の太い枠＋同色を accent として塗り、他の枠は ColorRect 等で
	# 賄うか、今回は border_color を accent にして他を border_width=hairline で
	# 細くする近似で対応。
	sbox.border_color = accent_color
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM + 2
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_MEDIUM
	sbox.content_margin_bottom = UIConstants.SEP_MEDIUM
	sbox.shadow_color = Color(0, 0, 0, 0.45)
	sbox.shadow_size = 4
	sbox.shadow_offset = Vector2(0, 2)
	return sbox


# セクション見出しのバッジ（左にシアンバー）。
static func section_header() -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_HEADER
	sbox.border_color = UIConstants.COLOR_ACCENT_CYAN
	sbox.border_width_left = UIConstants.ACCENT_STRIPE_WIDTH
	sbox.set_corner_radius_all(2)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM
	sbox.content_margin_right = UIConstants.SEP_WIDE
	sbox.content_margin_top = UIConstants.SEP_SMALL
	sbox.content_margin_bottom = UIConstants.SEP_SMALL
	return sbox


# Button 用 StyleBox 群（normal/hover/pressed/disabled/focus）。
# 4状態ぶんを Dictionary で返す。Theme.set_stylebox や手動 override で使う。
static func button_states(
		accent: Color = UIConstants.COLOR_ACCENT_CYAN,
		filled: bool = false) -> Dictionary:
	return {
		&"normal": _btn(accent, filled, false, false),
		&"hover": _btn(accent, filled, true, false),
		&"pressed": _btn(accent, true, false, true),
		&"hover_pressed": _btn(accent, true, true, true),
		&"focus": _btn(accent, filled, true, false),
		&"disabled": _btn_disabled(),
	}


static func _btn(accent: Color, filled: bool, hovered: bool, active: bool) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	if active or filled:
		sbox.bg_color = accent if active else UIConstants.COLOR_BG_HOVER
	else:
		sbox.bg_color = UIConstants.COLOR_BG_PANEL if not hovered else UIConstants.COLOR_BG_HOVER
	sbox.border_color = accent
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_SMALL
	sbox.content_margin_bottom = UIConstants.SEP_SMALL
	return sbox


static func _btn_disabled() -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	sbox.border_color = UIConstants.COLOR_BORDER
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_SMALL
	sbox.content_margin_bottom = UIConstants.SEP_SMALL
	return sbox


# サイドバー用タブボタン：未選択時は枠なし、選択時のみ左にシアンの太バー＋背景反転。
static func sidebar_tab_states() -> Dictionary:
	return {
		&"normal": _sidebar_tab(false, false),
		&"hover": _sidebar_tab(true, false),
		&"pressed": _sidebar_tab(false, true),
		&"hover_pressed": _sidebar_tab(true, true),
		&"focus": _sidebar_tab(true, false),
		&"disabled": _btn_disabled(),
	}


static func _sidebar_tab(hovered: bool, active: bool) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	if active:
		sbox.bg_color = UIConstants.COLOR_BG_PANEL
		sbox.border_color = UIConstants.COLOR_ACCENT_CYAN
		sbox.border_width_left = UIConstants.ACCENT_STRIPE_WIDTH
	elif hovered:
		sbox.bg_color = UIConstants.COLOR_BG_HOVER
	else:
		sbox.bg_color = UIConstants.COLOR_BG
	sbox.set_corner_radius_all(0)
	sbox.content_margin_left = UIConstants.SEP_WIDE
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_MEDIUM
	sbox.content_margin_bottom = UIConstants.SEP_MEDIUM
	return sbox


# カテゴリ/柱用のピル型トグル：押下時のみ accent 塗り。
static func pill_button_states(accent: Color = UIConstants.COLOR_ACCENT_CYAN) -> Dictionary:
	return {
		&"normal": _pill(accent, false, false),
		&"hover": _pill(accent, true, false),
		&"pressed": _pill(accent, false, true),
		&"hover_pressed": _pill(accent, true, true),
		&"focus": _pill(accent, true, false),
		&"disabled": _btn_disabled(),
	}


static func _pill(accent: Color, hovered: bool, active: bool) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	if active:
		sbox.bg_color = accent
	elif hovered:
		sbox.bg_color = UIConstants.COLOR_BG_HOVER
	else:
		sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	sbox.border_color = accent if active else UIConstants.COLOR_BORDER
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_WIDE
	sbox.content_margin_right = UIConstants.SEP_WIDE
	sbox.content_margin_top = UIConstants.SEP_SMALL
	sbox.content_margin_bottom = UIConstants.SEP_SMALL
	return sbox


# ProgressBar の背景／進捗を1セットで返す。
static func progress_bar_styles(fill_color: Color = UIConstants.COLOR_ACCENT_CYAN) -> Dictionary:
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	bg.border_color = UIConstants.COLOR_BORDER
	bg.set_border_width_all(UIConstants.HAIRLINE)
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	return { &"background": bg, &"fill": fill }
