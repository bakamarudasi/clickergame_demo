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
