class_name ThemeFactory
extends Object

# UIConstants と PanelStyler を読んで、ゲーム全体の Theme を組み立てる。
# main.gd から build_default() を呼んで root Control に setattr する。
#
# Theme は以下を定義する：
#  - 既定フォントサイズ / 既定色
#  - 各 Control タイプ（Button, PanelContainer, Label, ProgressBar 等）の
#    通常状態の StyleBox / 色
#  - 変種（DisplayLabel, TabButton, PillButton, AccentButton, SectionHeader 等）
#    のフォントサイズと StyleBox 上書き
#
# 変種は .tscn の `theme_type_variation = &"XYZ"` で参照される。
# 静的な見た目は theme_type_variation で済ませ、.gd 側のスタイル上書きは
# 「rarity 色を動的に変える」みたいな本当に動的な場面に限定する。

static func build_default() -> Theme:
	var t := Theme.new()
	t.default_font_size = UIConstants.FONT_BODY

	_apply_label_defaults(t)
	_apply_button_defaults(t)
	_apply_panel_defaults(t)
	_apply_progress_bar(t)
	_apply_option_button(t)
	_apply_scroll_container(t)
	_apply_tab_container(t)
	_apply_separator(t)

	_register_label_variations(t)
	_register_button_variations(t)
	_register_panel_variations(t)
	return t


# --- Label ---------------------------------------------------------------

static func _apply_label_defaults(t: Theme) -> void:
	t.set_color(&"font_color", &"Label", UIConstants.COLOR_TEXT)
	t.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.55))


static func _register_label_variations(t: Theme) -> void:
	_add_label_variation(t, UIConstants.VAR_DISPLAY_LABEL, UIConstants.FONT_HUGE, UIConstants.COLOR_TEXT)
	_add_label_variation(t, UIConstants.VAR_LARGE_LABEL, UIConstants.FONT_LARGE, UIConstants.COLOR_ACCENT_CYAN)
	_add_label_variation(t, UIConstants.VAR_TITLE_LABEL, UIConstants.FONT_TITLE, UIConstants.COLOR_TEXT)
	_add_label_variation(t, UIConstants.VAR_SUBTITLE_LABEL, UIConstants.FONT_SUBTITLE, UIConstants.COLOR_TEXT)
	_add_label_variation(t, UIConstants.VAR_NUMERIC_LABEL, UIConstants.FONT_TITLE, UIConstants.COLOR_ACCENT_CYAN)
	_add_label_variation(t, UIConstants.VAR_DIM_LABEL, UIConstants.FONT_BODY, UIConstants.COLOR_TEXT_DIM)

	# SectionHeader は Label の見た目（左にバー付き）を演出する変種。
	# 親側の PanelContainer に PanelStyler.section_header() を貼って使う想定。
	_add_label_variation(t, UIConstants.VAR_SECTION_HEADER, UIConstants.FONT_TITLE, UIConstants.COLOR_ACCENT_CYAN)


static func _add_label_variation(t: Theme, variation: StringName, size: int, color: Color) -> void:
	t.set_type_variation(variation, &"Label")
	t.set_font_size(&"font_size", variation, size)
	t.set_color(&"font_color", variation, color)


# --- Button --------------------------------------------------------------

static func _apply_button_defaults(t: Theme) -> void:
	var states := PanelStyler.button_states(UIConstants.COLOR_ACCENT_CYAN)
	for state in states:
		t.set_stylebox(state, &"Button", states[state])
	t.set_color(&"font_color", &"Button", UIConstants.COLOR_TEXT)
	t.set_color(&"font_hover_color", &"Button", UIConstants.COLOR_ACCENT_CYAN)
	t.set_color(&"font_pressed_color", &"Button", UIConstants.COLOR_TEXT_INK)
	t.set_color(&"font_hover_pressed_color", &"Button", UIConstants.COLOR_TEXT_INK)
	t.set_color(&"font_disabled_color", &"Button", UIConstants.COLOR_TEXT_DISABLED)
	t.set_color(&"font_focus_color", &"Button", UIConstants.COLOR_ACCENT_CYAN)


static func _register_button_variations(t: Theme) -> void:
	_add_button_variation(t, UIConstants.VAR_DISPLAY_BUTTON, UIConstants.FONT_DISPLAY)
	_add_button_variation(t, UIConstants.VAR_TAB_BUTTON, UIConstants.FONT_SUBTITLE)
	_add_button_variation(t, UIConstants.VAR_PILL_BUTTON, UIConstants.FONT_SUBTITLE)
	_add_button_variation(t, UIConstants.VAR_ACCENT_BUTTON, UIConstants.FONT_SUBTITLE)

	# TabButton（サイドバー）：未選択時は枠なし、選択時のみ左バー＋背景反転。
	var tab_states := PanelStyler.sidebar_tab_states()
	for state in tab_states:
		t.set_stylebox(state, UIConstants.VAR_TAB_BUTTON, tab_states[state])
	t.set_color(&"font_color", UIConstants.VAR_TAB_BUTTON, UIConstants.COLOR_TEXT_DIM)
	t.set_color(&"font_hover_color", UIConstants.VAR_TAB_BUTTON, UIConstants.COLOR_TEXT)
	t.set_color(&"font_pressed_color", UIConstants.VAR_TAB_BUTTON, UIConstants.COLOR_ACCENT_CYAN)
	t.set_color(&"font_hover_pressed_color", UIConstants.VAR_TAB_BUTTON, UIConstants.COLOR_ACCENT_CYAN)

	# PillButton（カテゴリ／柱）：押下時にシアン塗り。
	var pill_states := PanelStyler.pill_button_states(UIConstants.COLOR_ACCENT_CYAN)
	for state in pill_states:
		t.set_stylebox(state, UIConstants.VAR_PILL_BUTTON, pill_states[state])
	t.set_color(&"font_color", UIConstants.VAR_PILL_BUTTON, UIConstants.COLOR_TEXT)
	t.set_color(&"font_hover_color", UIConstants.VAR_PILL_BUTTON, UIConstants.COLOR_ACCENT_CYAN)
	t.set_color(&"font_pressed_color", UIConstants.VAR_PILL_BUTTON, UIConstants.COLOR_TEXT_INK)
	t.set_color(&"font_hover_pressed_color", UIConstants.VAR_PILL_BUTTON, UIConstants.COLOR_TEXT_INK)

	# AccentButton（購入・主アクション）：シアン塗り常時。
	var accent_states := PanelStyler.button_states(UIConstants.COLOR_ACCENT_CYAN, true)
	for state in accent_states:
		t.set_stylebox(state, UIConstants.VAR_ACCENT_BUTTON, accent_states[state])
	t.set_color(&"font_color", UIConstants.VAR_ACCENT_BUTTON, UIConstants.COLOR_TEXT_INK)
	t.set_color(&"font_hover_color", UIConstants.VAR_ACCENT_BUTTON, UIConstants.COLOR_TEXT_INK)
	t.set_color(&"font_pressed_color", UIConstants.VAR_ACCENT_BUTTON, UIConstants.COLOR_TEXT_INK)


static func _add_button_variation(t: Theme, variation: StringName, size: int) -> void:
	t.set_type_variation(variation, &"Button")
	t.set_font_size(&"font_size", variation, size)


# --- PanelContainer ------------------------------------------------------

static func _apply_panel_defaults(t: Theme) -> void:
	t.set_stylebox(&"panel", &"PanelContainer", PanelStyler.panel_dark())
	# Popup や dialog のパネルも統一
	t.set_stylebox(&"panel", &"Panel", PanelStyler.panel_dark())
	t.set_stylebox(&"panel", &"PopupPanel", PanelStyler.panel_dark(UIConstants.COLOR_BORDER_BRIGHT))


static func _register_panel_variations(t: Theme) -> void:
	t.set_type_variation(UIConstants.VAR_SECTION_HEADER, &"PanelContainer")
	t.set_stylebox(&"panel", UIConstants.VAR_SECTION_HEADER, PanelStyler.section_header())


# --- ProgressBar ---------------------------------------------------------

static func _apply_progress_bar(t: Theme) -> void:
	var styles := PanelStyler.progress_bar_styles(UIConstants.COLOR_ACCENT_CYAN)
	t.set_stylebox(&"background", &"ProgressBar", styles[&"background"])
	t.set_stylebox(&"fill", &"ProgressBar", styles[&"fill"])
	t.set_color(&"font_color", &"ProgressBar", UIConstants.COLOR_TEXT)


# --- OptionButton --------------------------------------------------------

static func _apply_option_button(t: Theme) -> void:
	var states := PanelStyler.button_states(UIConstants.COLOR_BORDER_BRIGHT)
	for state in states:
		t.set_stylebox(state, &"OptionButton", states[state])
	t.set_color(&"font_color", &"OptionButton", UIConstants.COLOR_TEXT)
	t.set_color(&"font_disabled_color", &"OptionButton", UIConstants.COLOR_TEXT_DISABLED)


# --- ScrollContainer / ScrollBar -----------------------------------------

static func _apply_scroll_container(t: Theme) -> void:
	# 透明背景。中身のパネル背景を透かす。
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	t.set_stylebox(&"panel", &"ScrollContainer", transparent)

	for klass in [&"VScrollBar", &"HScrollBar"]:
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
		bar_bg.set_corner_radius_all(2)
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = UIConstants.COLOR_BORDER_BRIGHT
		grabber.set_corner_radius_all(2)
		var grabber_hi := StyleBoxFlat.new()
		grabber_hi.bg_color = UIConstants.COLOR_ACCENT_CYAN
		grabber_hi.set_corner_radius_all(2)
		t.set_stylebox(&"scroll", klass, bar_bg)
		t.set_stylebox(&"scroll_focus", klass, bar_bg)
		t.set_stylebox(&"grabber", klass, grabber)
		t.set_stylebox(&"grabber_highlight", klass, grabber_hi)
		t.set_stylebox(&"grabber_pressed", klass, grabber_hi)


# --- TabContainer --------------------------------------------------------

static func _apply_tab_container(t: Theme) -> void:
	var panel := PanelStyler.panel_dark()
	panel.content_margin_left = UIConstants.SEP_SMALL
	panel.content_margin_right = UIConstants.SEP_SMALL
	panel.content_margin_top = UIConstants.SEP_SMALL
	panel.content_margin_bottom = UIConstants.SEP_SMALL
	t.set_stylebox(&"panel", &"TabContainer", panel)

	var selected := StyleBoxFlat.new()
	selected.bg_color = UIConstants.COLOR_BG_PANEL
	selected.border_color = UIConstants.COLOR_ACCENT_CYAN
	selected.border_width_bottom = 2
	selected.content_margin_left = UIConstants.SEP_MEDIUM
	selected.content_margin_right = UIConstants.SEP_MEDIUM
	selected.content_margin_top = UIConstants.SEP_SMALL
	selected.content_margin_bottom = UIConstants.SEP_SMALL

	var unselected := StyleBoxFlat.new()
	unselected.bg_color = UIConstants.COLOR_BG
	unselected.content_margin_left = UIConstants.SEP_MEDIUM
	unselected.content_margin_right = UIConstants.SEP_MEDIUM
	unselected.content_margin_top = UIConstants.SEP_SMALL
	unselected.content_margin_bottom = UIConstants.SEP_SMALL

	t.set_stylebox(&"tab_selected", &"TabContainer", selected)
	t.set_stylebox(&"tab_unselected", &"TabContainer", unselected)
	t.set_stylebox(&"tab_hovered", &"TabContainer", unselected)
	t.set_color(&"font_selected_color", &"TabContainer", UIConstants.COLOR_ACCENT_CYAN)
	t.set_color(&"font_unselected_color", &"TabContainer", UIConstants.COLOR_TEXT_DIM)
	t.set_color(&"font_hovered_color", &"TabContainer", UIConstants.COLOR_TEXT)


# --- Separator -----------------------------------------------------------

static func _apply_separator(t: Theme) -> void:
	var line := StyleBoxFlat.new()
	line.bg_color = UIConstants.COLOR_BORDER
	line.content_margin_top = 1
	t.set_stylebox(&"separator", &"HSeparator", line)
	t.set_stylebox(&"separator", &"VSeparator", line)
	t.set_constant(&"separation", &"HSeparator", 1)
	t.set_constant(&"separation", &"VSeparator", 1)
