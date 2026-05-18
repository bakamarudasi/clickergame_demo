@tool
class_name SegmentedBar
extends Control

# 観測機器風のセグメント化ゲージ。N 個の矩形を並べ、value/max_value の比率に
# 応じて埋まる数を変える。critical_threshold を超える（または invert_critical=true で
# 下回る）と全セグメントが警告色に切り替わり、点滅も発火する。
#
# ProgressBar と互換の value / min_value / max_value API を持つので
# .gd 側のコードは `bar.value = X` のままで動く。.tscn 側は type="Control" +
# script=SegmentedBar に差し替える。
#
# Battery のように「減ると危険」なバーは invert_critical = true で運用する。

signal value_changed(value: float)

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		_redraw_safe()
@export var max_value: float = 100.0:
	set(v):
		max_value = max(v, min_value + 0.001)
		_redraw_safe()
@export var value: float = 0.0:
	set(v):
		var clamped: float = clamp(v, min_value, max_value)
		if not is_equal_approx(value, clamped):
			value = clamped
			emit_signal("value_changed", value)
			_redraw_safe()
			_refresh_blink()
		else:
			value = clamped

@export_group("Segments")
@export var segment_count: int = 24:
	set(v):
		segment_count = max(1, v)
		_redraw_safe()
@export var segment_gap: float = 2.0:
	set(v):
		segment_gap = max(0.0, v)
		_redraw_safe()
@export var segment_skew: float = 0.0:
	set(v):
		segment_skew = v
		_redraw_safe()
# 末尾「ハーフセグメント」を有効にする。半端な ratio を最後の半透明セルで示せる。
@export var allow_partial_tail: bool = true:
	set(v):
		allow_partial_tail = v
		_redraw_safe()

@export_group("Colors")
@export var color_filled: Color = Color(0.365, 0.812, 0.969, 1.0):
	set(v):
		color_filled = v
		_redraw_safe()
@export var color_empty: Color = Color(0.176, 0.231, 0.306, 0.55):
	set(v):
		color_empty = v
		_redraw_safe()
@export var color_critical: Color = Color(1.0, 0.353, 0.431, 1.0):
	set(v):
		color_critical = v
		_redraw_safe()
@export var color_border: Color = Color(0.043, 0.067, 0.094, 1.0):
	set(v):
		color_border = v
		_redraw_safe()

@export_group("Critical")
# critical_threshold は 0..1 の比率。invert_critical=false ならこれ以上で警告、
# true ならこれ以下で警告（バッテリ系）。
@export_range(0.0, 1.0) var critical_threshold: float = 0.85:
	set(v):
		critical_threshold = clamp(v, 0.0, 1.0)
		_refresh_blink()
		_redraw_safe()
@export var invert_critical: bool = false:
	set(v):
		invert_critical = v
		_refresh_blink()
		_redraw_safe()
@export var blink_when_critical: bool = true:
	set(v):
		blink_when_critical = v
		_refresh_blink()
@export_range(0.1, 4.0) var blink_period: float = 0.8:
	set(v):
		blink_period = max(0.1, v)
		_refresh_blink()


var _blink_tween: Tween


func _ready() -> void:
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 14.0
	resized.connect(queue_redraw)
	_refresh_blink()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var ratio: float = _ratio()
	var critical := _is_critical(ratio)
	var fill_color: Color = color_critical if critical else color_filled

	var n := segment_count
	var gap := segment_gap
	var total_w := size.x
	var seg_w: float = max(1.0, (total_w - gap * (n - 1)) / float(n))
	var seg_h: float = size.y

	var exact: float = ratio * float(n)
	var full_segs: int = int(floor(exact))
	var partial: float = exact - float(full_segs)

	for i in range(n):
		var x: float = float(i) * (seg_w + gap)
		var rect := Rect2(x, 0.0, seg_w, seg_h)
		var col: Color
		if i < full_segs:
			col = fill_color
		elif i == full_segs and allow_partial_tail and partial > 0.0:
			# ハーフセグメント：fill と empty を partial 比でブレンド
			col = color_empty.lerp(fill_color, partial)
		else:
			col = color_empty

		if abs(segment_skew) < 0.01:
			draw_rect(rect, col, true)
		else:
			# 斜めセグメント（平行四辺形）。観測機器ぽさを出すための装飾。
			var sk: float = segment_skew
			var pts := PackedVector2Array([
				Vector2(rect.position.x + sk, rect.position.y),
				Vector2(rect.position.x + rect.size.x + sk, rect.position.y),
				Vector2(rect.position.x + rect.size.x - sk, rect.position.y + rect.size.y),
				Vector2(rect.position.x - sk, rect.position.y + rect.size.y),
			])
			draw_colored_polygon(pts, col)

		# 各セグメントに薄い縁取り
		if color_border.a > 0.0:
			draw_rect(rect, color_border, false, 1.0)


func _ratio() -> float:
	var span: float = max_value - min_value
	if span <= 0.0:
		return 0.0
	return clamp((value - min_value) / span, 0.0, 1.0)


func _is_critical(ratio: float) -> bool:
	if invert_critical:
		return ratio <= critical_threshold
	return ratio >= critical_threshold


func _refresh_blink() -> void:
	# Tween は状態が変わった瞬間だけ作り直す。常時 loop は重い。
	var should_blink := blink_when_critical and _is_critical(_ratio())
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	if not should_blink or not is_inside_tree():
		modulate = Color(1, 1, 1, 1)
		return
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(self, "modulate", Color(1.25, 0.7, 0.75, 1.0), blink_period * 0.5)
	_blink_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), blink_period * 0.5)


func _redraw_safe() -> void:
	if is_inside_tree():
		queue_redraw()
