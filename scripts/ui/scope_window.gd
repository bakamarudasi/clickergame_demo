class_name ScopeWindow
extends Control

# 紳士枠の動かせる窓本体。
# - clip_contents = true でこの Control の矩形でクリップ
# - 子に置いた OverlayInner (TextureRect) が立ち絵全体と同じ位置・サイズで
#   貼られてるので、self.position の負オフセットを OverlayInner.position に
#   逆向きに食わせれば「枠を通して立ち絵の一部だけが見える」状態になる
# - 本体ドラッグ＝移動、右下 ResizeHandle ドラッグ＝サイズ変更
# - サイズ上限は装備中スコープの max_window_size（set_max_size で渡す）
#   下限は MIN_SIZE 定数。ハンドルでこの範囲にクランプされる。

signal moved
signal resized_by_user

const MIN_SIZE := Vector2(80, 80)

@onready var _overlay_inner: TextureRect = $OverlayInner
@onready var _resize_handle: Control = $ResizeHandle

var _max_size: Vector2 = Vector2(220, 220)
var _portrait_size: Vector2 = Vector2.ZERO

var _move_dragging: bool = false
var _move_drag_local: Vector2 = Vector2.ZERO

var _resize_dragging: bool = false
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_start_global: Vector2 = Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_handle.gui_input.connect(_on_handle_input)
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE


# 立ち絵テクスチャを枠の内側レイヤーに設定。
# portrait_size は親 PortraitView の実サイズ（OverlayInner はそれと同寸で配置）。
func set_overlay(tex: Texture2D, portrait_size: Vector2) -> void:
	_portrait_size = portrait_size
	_overlay_inner.texture = tex
	_overlay_inner.size = portrait_size
	_sync_overlay_offset()


# 装備中スコープの最大サイズを通知。現在サイズが超えてたら縮める。
func set_max_size(max_s: Vector2) -> void:
	_max_size = max_s
	size = Vector2(
			clampf(size.x, MIN_SIZE.x, _max_size.x),
			clampf(size.y, MIN_SIZE.y, _max_size.y)
	)
	_clamp_position_in_parent()
	_sync_overlay_offset()


func _sync_overlay_offset() -> void:
	if _overlay_inner == null:
		return
	_overlay_inner.position = -position


func _clamp_position_in_parent() -> void:
	var parent_rect: Rect2 = (get_parent() as Control).get_rect()
	var max_x := maxf(0.0, parent_rect.size.x - size.x)
	var max_y := maxf(0.0, parent_rect.size.y - size.y)
	position = Vector2(clampf(position.x, 0.0, max_x), clampf(position.y, 0.0, max_y))


func center_in_parent() -> void:
	var parent_rect: Rect2 = (get_parent() as Control).get_rect()
	position = (parent_rect.size - size) * 0.5
	_clamp_position_in_parent()
	_sync_overlay_offset()


# 枠内側の TextureRect にシェーダーマテリアルを噛ませる。null で素通し。
# モザイク（resolution_level）演出は room_tab がここを叩く。
func set_overlay_material(mat: Material) -> void:
	if _overlay_inner == null:
		return
	_overlay_inner.material = mat


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_move_dragging = true
				_move_drag_local = mb.position
			else:
				_move_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _move_dragging:
		var mm := event as InputEventMouseMotion
		position += mm.position - _move_drag_local
		_clamp_position_in_parent()
		_sync_overlay_offset()
		moved.emit()
		accept_event()


func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resize_dragging = true
				_resize_start_size = size
				_resize_start_global = mb.global_position
			else:
				_resize_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _resize_dragging:
		var delta: Vector2 = (event as InputEventMouseMotion).global_position - _resize_start_global
		var new_size := _resize_start_size + delta
		new_size.x = clampf(new_size.x, MIN_SIZE.x, _max_size.x)
		new_size.y = clampf(new_size.y, MIN_SIZE.y, _max_size.y)
		# 親の右端／下端を超えないようにもクランプ（位置固定でリサイズなので）
		var parent_rect: Rect2 = (get_parent() as Control).get_rect()
		new_size.x = minf(new_size.x, parent_rect.size.x - position.x)
		new_size.y = minf(new_size.y, parent_rect.size.y - position.y)
		size = new_size
		_sync_overlay_offset()
		resized_by_user.emit()
		accept_event()
