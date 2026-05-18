class_name ChoicePanelView
extends RefCounted

# Room タブの選択肢ボタン群を管理するヘルパー。
# ReactionRule.choices が非空のとき、本体台詞のあとに画面下に並べる。
# プレイヤーがどれか押すと chosen シグナルで RoomTab 本体に通知する。
#
# 同時に複数のルールが選択肢を持つことは想定しない。新しい choices が来たら
# show() が既存のボタンを置き換える。

signal chosen(choice: ReactionChoice)

var _panel: PanelContainer
var _vbox: VBoxContainer


func _init(panel: PanelContainer, vbox: VBoxContainer) -> void:
	_panel = panel
	_vbox = vbox
	_panel.visible = false


func is_active() -> bool:
	return _panel.visible


func show_choices(choices: Array) -> void:
	clear()
	if choices.is_empty():
		return
	for choice: ReactionChoice in choices:
		var b := Button.new()
		# Button.text に翻訳キーをそのまま入れて Godot の自動翻訳に乗せる
		b.text = choice.label_key
		b.theme_type_variation = UIConstants.VAR_PILL_BUTTON
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_pressed.bind(choice))
		_vbox.add_child(b)
	_panel.visible = true


func clear() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_panel.visible = false


func _on_pressed(choice: ReactionChoice) -> void:
	# 連打で同じ choice が二度発火しないよう、押したら即座にパネルを閉じる。
	clear()
	chosen.emit(choice)
