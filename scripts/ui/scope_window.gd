class_name ScopeWindow
extends Control

# 紳士枠の動かせる窓本体。
# - clip_contents = true でこの Control の矩形でクリップ
# - 子に置いた OverlayInner (TextureRect) が立ち絵全体と同じ位置・サイズで
#   貼られてるので、self.position の負オフセットを OverlayInner.position に
#   逆向きに食わせれば「枠を通して立ち絵の一部だけが見える」状態になる
# - ドラッグで親 (PortraitView) 内を移動する。枠の中身（クリッピング）は
#   親リサイズに追随しないので、リサイズ時は room_tab 側が再配置する。

signal moved

@onready var _overlay_inner: TextureRect = $OverlayInner

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


# 立ち絵全体のテクスチャを枠の内側レイヤーに設定。
# portrait_size は親 PortraitView の実サイズ（OverlayInner はそれと同寸で配置）。
func set_overlay(tex: Texture2D, portrait_size: Vector2) -> void:
	_overlay_inner.texture = tex
	_overlay_inner.size = portrait_size
	_sync_overlay_offset()


# 枠が動いた／親がリサイズした時に呼ぶ。OverlayInner を逆オフセットで貼り直す。
func _sync_overlay_offset() -> void:
	if _overlay_inner == null:
		return
	_overlay_inner.position = -position


func _set_window_position(p: Vector2) -> void:
	var parent_rect := get_parent().get_rect()
	var max_x := maxf(0.0, parent_rect.size.x - size.x)
	var max_y := maxf(0.0, parent_rect.size.y - size.y)
	position = Vector2(clampf(p.x, 0.0, max_x), clampf(p.y, 0.0, max_y))
	_sync_overlay_offset()
	moved.emit()


func center_in_parent() -> void:
	var parent_rect := get_parent().get_rect()
	_set_window_position((parent_rect.size - size) * 0.5)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = mb.position
			else:
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_set_window_position(position + mm.position - _drag_offset)
		accept_event()
