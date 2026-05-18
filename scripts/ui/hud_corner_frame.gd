@tool
class_name HudCornerFrame
extends Control

# 観測者視点 HUD の角ブラケット（┌ ┐ └ ┘）を _draw() で描く軽量オーバーレイ。
# 任意の PanelContainer / Control に full-rect で子として置き、mouse_filter=IGNORE
# にしておけば下のクリックを邪魔しない。サイバー基調の差別化に効く。

@export var color: Color = Color(0.365, 0.812, 0.969, 1.0):  # UIConstants.COLOR_ACCENT_CYAN
	set(v):
		color = v
		queue_redraw()
@export var bracket_length: float = 18.0:
	set(v):
		bracket_length = v
		queue_redraw()
@export var thickness: float = 2.0:
	set(v):
		thickness = v
		queue_redraw()
@export var inset: float = 2.0:
	set(v):
		inset = v
		queue_redraw()
# 各辺中央に短い目盛りを置くか（観測機器感を強める）
@export var draw_tick_marks: bool = false:
	set(v):
		draw_tick_marks = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 親の full rect を埋める前提だが、保険として offset_* も 0 に揃える
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var topleft := Vector2(inset, inset)
	var topright := Vector2(size.x - inset, inset)
	var botleft := Vector2(inset, size.y - inset)
	var botright := size - Vector2(inset, inset)
	var bl := bracket_length

	# 4 隅の L 字
	draw_line(topleft, topleft + Vector2(bl, 0), color, thickness)
	draw_line(topleft, topleft + Vector2(0, bl), color, thickness)

	draw_line(topright, topright - Vector2(bl, 0), color, thickness)
	draw_line(topright, topright + Vector2(0, bl), color, thickness)

	draw_line(botleft, botleft + Vector2(bl, 0), color, thickness)
	draw_line(botleft, botleft - Vector2(0, bl), color, thickness)

	draw_line(botright, botright - Vector2(bl, 0), color, thickness)
	draw_line(botright, botright - Vector2(0, bl), color, thickness)

	if draw_tick_marks:
		var tick := bl * 0.4
		var mid_top := Vector2(size.x * 0.5, inset)
		var mid_bot := Vector2(size.x * 0.5, size.y - inset)
		var mid_left := Vector2(inset, size.y * 0.5)
		var mid_right := Vector2(size.x - inset, size.y * 0.5)
		draw_line(mid_top, mid_top + Vector2(0, tick), color, thickness)
		draw_line(mid_bot, mid_bot - Vector2(0, tick), color, thickness)
		draw_line(mid_left, mid_left + Vector2(tick, 0), color, thickness)
		draw_line(mid_right, mid_right - Vector2(tick, 0), color, thickness)
