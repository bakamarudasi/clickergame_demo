@tool
class_name AssetAuditDropDialog
extends ConfirmationDialog

# 画像ドロップ時に「この画像をどう使うか」を選ぶダイアログ。
# audit_dock から呼ばれて confirmed_apply を返す。

signal confirmed_apply(target_meta: Dictionary, src_path: String, src_is_os: bool,
		mode_choice: int, switch_to_full_cg: bool, expression_key: String)

var _meta: Dictionary = {}
var _src_path: String = ""
var _src_is_os: bool = false

var _radio_group: ButtonGroup
var _radio_full_cg_keep: CheckBox
var _radio_full_cg_switch: CheckBox
var _radio_face_overlay: CheckBox
var _expression_edit: LineEdit


func setup(target_meta: Dictionary, src_path: String, src_is_os: bool) -> void:
	_meta = target_meta
	_src_path = src_path
	_src_is_os = src_is_os
	title = "画像の用途を選択"
	ok_button_text = "適用"
	cancel_button_text = "キャンセル"
	min_size = Vector2(520, 280)

	var vb := VBoxContainer.new()
	add_child(vb)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mode_label := "PORTRAIT" if target_meta.get("mode", 0) == 0 else "FULL_CG"
	info.text = "ドロップ画像: %s\n対象: %s step %02d (現在モード: %s)\n保存先規約: res://assets/cg/<op>/<cg>/step_NN_<basename>.png" % [
		src_path,
		target_meta.get("cg_id", &""),
		int(target_meta.get("step_index", 0)) + 1,
		mode_label,
	]
	info.modulate = Color(1, 1, 1, 0.85)
	vb.add_child(info)

	vb.add_child(HSeparator.new())

	_radio_group = ButtonGroup.new()

	_radio_full_cg_keep = CheckBox.new()
	_radio_full_cg_keep.text = "このステップの FULL_CG 画像にする（推奨）"
	_radio_full_cg_keep.button_group = _radio_group
	vb.add_child(_radio_full_cg_keep)

	_radio_full_cg_switch = CheckBox.new()
	_radio_full_cg_switch.text = "ステップを FULL_CG に変更して画像を埋める"
	_radio_full_cg_switch.button_group = _radio_group
	vb.add_child(_radio_full_cg_switch)

	_radio_face_overlay = CheckBox.new()
	_radio_face_overlay.text = "立ち絵の顔差分（portrait_face_overlays）として登録"
	_radio_face_overlay.button_group = _radio_group
	vb.add_child(_radio_face_overlay)

	var expr_hb := HBoxContainer.new()
	vb.add_child(expr_hb)
	var expr_label := Label.new()
	expr_label.text = "    expression キー:"
	expr_hb.add_child(expr_label)
	_expression_edit = LineEdit.new()
	_expression_edit.placeholder_text = "例: smile / shy_smile / blush"
	_expression_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	expr_hb.add_child(_expression_edit)

	# 現在モードに応じて推奨デフォルトを選択
	if target_meta.get("mode", 0) == 1:  # FULL_CG
		_radio_full_cg_keep.button_pressed = true
	else:
		# PORTRAIT step: hint が入ってればおそらく FULL_CG への切替が意図、
		# 入ってなければ顔差分の可能性が高いが、安全側で FULL_CG keep を初期選択。
		_radio_full_cg_keep.button_pressed = true

	# 表情欄のデフォルトは hint から推測しない（ユーザー入力に任せる）
	# 顔差分選択時のみ enable 表示にするとわかりやすいが、常時 enable で簡素化。

	confirmed.connect(_on_confirmed)
	canceled.connect(queue_free)
	close_requested.connect(queue_free)


func _on_confirmed() -> void:
	var choice := 0
	if _radio_full_cg_keep.button_pressed:
		choice = 0
	elif _radio_full_cg_switch.button_pressed:
		choice = 1
	elif _radio_face_overlay.button_pressed:
		choice = 2
	confirmed_apply.emit(
		_meta, _src_path, _src_is_os,
		choice,
		_radio_full_cg_switch.button_pressed,
		_expression_edit.text.strip_edges()
	)
	queue_free()
