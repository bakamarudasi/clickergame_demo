class_name QuantitySelector
extends RefCounted

# 数量モード（×1 / ×10 / ×100 / ×Max）の共通UIヘルパー。
# Shop タブ（.tscn 配置済みの 4 ボタン）と Work タブ（カードごとに動的生成）の
# 両方で使えるよう、bind_buttons() / build_into() の 2 系統 API を持つ。
# 0=×1, 1=×10, 2=×100, 3=×Max

signal mode_changed(mode: int)

const MODE_X1 := 0
const MODE_X10 := 1
const MODE_X100 := 2
const MODE_MAX := 3
const _LABELS := ["×1", "×10", "×100"]

var mode: int = 0
var buttons: Array[Button] = []


# 既存の 4 ボタン（.tscn 側で配置済み）を束ねる。
# Max ボタンの text には「翻訳キー」をそのまま入れる（Godot の Button.text は
# キー文字列ならロケール切替で自動 tr されるため、別途再翻訳呼び出しが不要）。
func bind_buttons(btns: Array, max_label_key: String = "WORK_UPGRADE_QTY_MAX") -> void:
	assert(btns.size() == 4, "QuantitySelector requires exactly 4 buttons")
	buttons.clear()
	var group := ButtonGroup.new()
	for i in 4:
		var b: Button = btns[i]
		b.toggle_mode = true
		b.button_group = group
		b.text = _LABELS[i] if i < 3 else max_label_key
		b.toggled.connect(_on_btn_toggled.bind(i))
		buttons.append(b)
	buttons[mode].set_pressed_no_signal(true)


# 親コンテナに 4 ボタンを生成して配置する（カード等の動的生成ケース）。
func build_into(
		parent: Container,
		max_label_key: String = "WORK_UPGRADE_QTY_MAX",
		button_min_size: Vector2 = Vector2(56, 28),
		font_color: Variant = null) -> void:
	var btns: Array[Button] = []
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = button_min_size
		if font_color is Color:
			b.add_theme_color_override("font_color", font_color)
		parent.add_child(b)
		btns.append(b)
	bind_buttons(btns, max_label_key)


# 外部からモードだけ書き換える（他カードとの同期用）。
# トグル状態のみ更新し、mode_changed は再帰回避のため発火しない。
func set_mode_silent(new_mode: int) -> void:
	new_mode = clamp(new_mode, 0, 3)
	mode = new_mode
	if buttons.size() >= 4:
		buttons[new_mode].set_pressed_no_signal(true)


func set_enabled(enabled: bool) -> void:
	for b in buttons:
		b.disabled = not enabled


# 現モードに対応する qty を返す。Max のときだけ max_resolver を評価する。
func resolve_qty(max_resolver: Callable) -> int:
	match mode:
		MODE_X1: return 1
		MODE_X10: return 10
		MODE_X100: return 100
		MODE_MAX: return int(max_resolver.call())
		_: return 1


func _on_btn_toggled(pressed: bool, idx: int) -> void:
	if not pressed or mode == idx:
		return
	mode = idx
	mode_changed.emit(mode)
