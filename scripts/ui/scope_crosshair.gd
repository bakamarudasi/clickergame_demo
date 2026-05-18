@tool
class_name ScopeCrosshair
extends Control

# 紳士眼鏡ウィンドウ中央の照準十字。中心に隙間、4本の腕に距離スケールチック、
# 中央に観測点ドット。ScopeWindow の子に置き mouse_filter=IGNORE にしておけば
# ドラッグ操作を邪魔しない。
#
# 描画はサイズ依存なので、ScopeWindow の resize に追従して queue_redraw。

@export var color: Color = Color(0.365, 0.812, 0.969, 0.85):
	set(v):
		color = v
		queue_redraw()
@export var thickness: float = 1.0:
	set(v):
		thickness = v
		queue_redraw()
# 中心の十字に空ける隙間（被写体を見えるように）
@export var center_gap: float = 10.0:
	set(v):
		center_gap = max(0.0, v)
		queue_redraw()
@export var tick_count: int = 3:
	set(v):
		tick_count = max(0, v)
		queue_redraw()
@export var tick_length: float = 6.0:
	set(v):
		tick_length = max(0.0, v)
		queue_redraw()
@export var draw_center_dot: bool = true:
	set(v):
		draw_center_dot = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var gap: float = center_gap

	# 主軸十字（中心に隙間）
	draw_line(Vector2(0.0, cy), Vector2(cx - gap, cy), color, thickness)
	draw_line(Vector2(cx + gap, cy), Vector2(size.x, cy), color, thickness)
	draw_line(Vector2(cx, 0.0), Vector2(cx, cy - gap), color, thickness)
	draw_line(Vector2(cx, cy + gap), Vector2(cx, size.y), color, thickness)

	# 距離チック。各腕を tick_count+1 等分した位置に短い垂直線を引く。
	# 腕の長さは中心〜端 = (cx - gap) / (cy - gap)。中心側から数えるので
	# t = i / (tick_count+1) の比率で配置。
	var half_tick: float = tick_length * 0.5
	for i in range(1, tick_count + 1):
		var t: float = float(i) / float(tick_count + 1)
		var dx: float = (cx - gap) * t
		draw_line(Vector2(cx - dx, cy - half_tick), Vector2(cx - dx, cy + half_tick), color, thickness)
		draw_line(Vector2(cx + dx, cy - half_tick), Vector2(cx + dx, cy + half_tick), color, thickness)
		var dy: float = (cy - gap) * t
		draw_line(Vector2(cx - half_tick, cy - dy), Vector2(cx + half_tick, cy - dy), color, thickness)
		draw_line(Vector2(cx - half_tick, cy + dy), Vector2(cx + half_tick, cy + dy), color, thickness)

	if draw_center_dot:
		draw_circle(Vector2(cx, cy), 1.6, color)
