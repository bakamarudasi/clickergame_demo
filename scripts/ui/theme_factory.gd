class_name ThemeFactory
extends Object

# UIConstants を読んで Theme を1つ組み立てる。
# main.gd から build_default() を呼んで root Control に setattr する。

static func build_default() -> Theme:
	var t := Theme.new()
	t.default_font_size = UIConstants.FONT_BODY

	_add_label_variation(t, UIConstants.VAR_DISPLAY_LABEL, UIConstants.FONT_HUGE)
	_add_label_variation(t, UIConstants.VAR_LARGE_LABEL, UIConstants.FONT_LARGE)
	_add_label_variation(t, UIConstants.VAR_TITLE_LABEL, UIConstants.FONT_TITLE)
	_add_label_variation(t, UIConstants.VAR_SUBTITLE_LABEL, UIConstants.FONT_SUBTITLE)

	_add_button_variation(t, UIConstants.VAR_DISPLAY_BUTTON, UIConstants.FONT_DISPLAY)
	_add_button_variation(t, UIConstants.VAR_TAB_BUTTON, UIConstants.FONT_SUBTITLE)
	return t


static func _add_label_variation(t: Theme, variation: StringName, size: int) -> void:
	t.set_type_variation(variation, &"Label")
	t.set_font_size(&"font_size", variation, size)


static func _add_button_variation(t: Theme, variation: StringName, size: int) -> void:
	t.set_type_variation(variation, &"Button")
	t.set_font_size(&"font_size", variation, size)


# Room タブのルートに被せる小さなテーマ。font_size など未設定のプロパティは
# 親（Main の build_default）テーマに自動でフォールバックするので、ここでは
# クリーム背景に合うように Label / Button の文字色だけ上書きする。
static func build_room_overlay() -> Theme:
	var t := Theme.new()
	var dark := UIConstants.COLOR_ROOM_TEXT
	var dim := UIConstants.COLOR_ROOM_TEXT_DIM
	t.set_color(&"font_color", &"Label", dark)
	t.set_color(&"font_color", &"Button", dark)
	t.set_color(&"font_pressed_color", &"Button", dark)
	t.set_color(&"font_hover_color", &"Button", dark)
	t.set_color(&"font_focus_color", &"Button", dark)
	t.set_color(&"font_hover_pressed_color", &"Button", dark)
	t.set_color(&"font_disabled_color", &"Button", dim)
	t.set_color(&"font_color", &"OptionButton", dark)
	t.set_color(&"font_pressed_color", &"OptionButton", dark)
	t.set_color(&"font_hover_color", &"OptionButton", dark)
	t.set_color(&"font_focus_color", &"OptionButton", dark)
	t.set_color(&"font_disabled_color", &"OptionButton", dim)
	return t
