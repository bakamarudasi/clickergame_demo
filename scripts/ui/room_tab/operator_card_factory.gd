class_name OperatorCardFactory
extends RefCounted

# Room タブ左ペインの「ブリーフィング・カード」を組み立てる。
# 元は素のボタンだったところを、観測ファイル風レイアウト
# （[SUBJECT-LEMUEN] / 名前 / CLEARANCE.NN）に置き換える。
#
# 選択中カードは左端 4px のシアンアクセント＋背景色違いで強調する。
# クリックは panel.gui_input → selected シグナルで host に通す。

signal selected(op_id: StringName)


# OperatorData / current_stage / 現在選択中かを渡して 1 枚分の Control を返す。
# 返した Control は呼び出し側が VBoxContainer に add_child する。
func build(op: OperatorData, op_id: StringName, current_stage: int, is_current: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _build_stylebox(is_current))
	panel.gui_input.connect(_on_card_input.bind(op_id))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Subject ID: 小さくシアンで「[SUBJECT-LEMUEN]」
	var subj := Label.new()
	subj.text = "[SUBJECT-%s]" % str(op_id).to_upper()
	subj.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_CYAN)
	subj.add_theme_font_size_override("font_size", UIConstants.FONT_SMALL)
	subj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subj)

	# 名前（OperatorData.display_name は翻訳キー）
	var name_label := Label.new()
	name_label.text = TranslationServer.translate(op.display_name)
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SUBTITLE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# CLEARANCE.NN（現ステージを 2 桁ゼロ詰めで権限風表示）
	var clearance := Label.new()
	clearance.text = "CLEARANCE.%02d" % current_stage
	clearance.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	clearance.add_theme_font_size_override("font_size", UIConstants.FONT_SMALL)
	clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(clearance)

	return panel


# 選択中のカードは強アクセント、未選択は薄罫線のダークカード。
func _build_stylebox(is_current: bool) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	if is_current:
		sbox.bg_color = UIConstants.COLOR_BG_HEADER
		sbox.border_color = UIConstants.COLOR_ACCENT_CYAN
		sbox.border_width_left = UIConstants.ACCENT_STRIPE_WIDTH
		sbox.border_width_top = UIConstants.HAIRLINE
		sbox.border_width_right = UIConstants.HAIRLINE
		sbox.border_width_bottom = UIConstants.HAIRLINE
	else:
		sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
		sbox.border_color = UIConstants.COLOR_BORDER
		sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = 10
	sbox.content_margin_right = 8
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	return sbox


func _on_card_input(event: InputEvent, op_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("selected", op_id)
