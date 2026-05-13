class_name DialogueLogView
extends RefCounted

# Room タブの会話ログ表示。Label を VBox に積み、末尾自動スクロールと
# 上限本数の打ち切りだけを担当する。会話の中身（誰が何を言ったか）は呼び出し側で組み立てる。

const MAX_ENTRIES := 10

var _scroll: ScrollContainer
var _log: VBoxContainer


func _init(scroll: ScrollContainer, log_box: VBoxContainer) -> void:
	_scroll = scroll
	_log = log_box


func clear() -> void:
	for child in _log.get_children():
		child.queue_free()


func append(text: String) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.text = text
	_log.add_child(l)
	while _log.get_child_count() > MAX_ENTRIES:
		_log.get_child(0).queue_free()
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	# scroll bar の max は次フレームで反映されるので待つ
	await _log.get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		_scroll.scroll_vertical = int(bar.max_value)
