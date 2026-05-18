class_name DialogueLogView
extends RefCounted

# Room タブの会話ログ表示。RichTextLabel を VBox に積み、末尾自動スクロールと
# 上限本数の打ち切りを担当する。
#
# エントリは2種類：
#   - reaction: 話者名（accent色）＋セリフ＋信頼度デルタ（色つき）
#   - system  : 説明文だけ（ロック通知など。dim色・italic）
#
# 翻訳キーを保持しておくことでロケール切替時に再描画できる。

const MAX_ENTRIES := 10

# BBCode 用の色（Color → "#rrggbb" 文字列に焼く）
const HEX_SPEAKER := "#5DCFF7"   # COLOR_ACCENT_CYAN
const HEX_DELTA_PLUS := "#FFC857"  # 信頼度+
const HEX_DELTA_MINUS := "#FF5A6E"  # 信頼度-
const HEX_DELTA_ZERO := "#7B8B9E"   # 0 の時は dim
const HEX_SYSTEM := "#7B8B9E"
const HEX_TC := "#3F5670"   # COLOR_BORDER_BRIGHT 相当、観測ログのタイムコード用

var _scroll: ScrollContainer
var _log: VBoxContainer

# 既存エントリの「キー」を保持して翻訳変更時に再構築できるようにする。
# 各要素は Dictionary { kind, speaker_key, dialogue_key, trust_delta, system_text }
var _entries: Array = []


func _init(scroll: ScrollContainer, log_box: VBoxContainer) -> void:
	_scroll = scroll
	_log = log_box


func clear() -> void:
	_entries.clear()
	for child in _log.get_children():
		child.queue_free()


# キャラの反応をログに積む。speaker_key / dialogue_key は翻訳キー。
# 追加時のシステム時刻を TC として刻み、ロケール切替で再描画しても
# 時刻が動かないように entry に焼いておく。
func append_reaction(speaker_key: String, dialogue_key: String, trust_delta: int) -> void:
	_entries.append({
		"kind": "reaction",
		"speaker_key": speaker_key,
		"dialogue_key": dialogue_key,
		"trust_delta": trust_delta,
		"tc": _now_tc(),
	})
	_append_entry_view(_entries[_entries.size() - 1])
	_trim_and_scroll()


# システム通知（ロック残り時間など。話者なし）。
# text は既に翻訳・フォーマット済みの完成文字列を渡す。
# locale 切替で再翻訳したい場合は ROOM_LOCK_FMT のようなキー＋引数を保持する形に
# 変更する余地あり（現状は ROOM_LOCK_FMT の % が外で適用される設計のまま）。
func append_system(text: String) -> void:
	_entries.append({
		"kind": "system",
		"text": text,
		"tc": _now_tc(),
	})
	_append_entry_view(_entries[_entries.size() - 1])
	_trim_and_scroll()


# 翻訳変更時に呼ぶ。エントリは保持したまま見た目だけ作り直す。
func rebuild_views() -> void:
	for child in _log.get_children():
		child.queue_free()
	for entry in _entries:
		_append_entry_view(entry)
	_scroll_to_bottom()


# --- 内部 ---------------------------------------------------------------

func _append_entry_view(entry: Dictionary) -> void:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.text = _format_entry(entry)
	_log.add_child(rt)


func _format_entry(entry: Dictionary) -> String:
	# サイバー観測ログ風の TC プレフィックス。
	# entry.get("tc", "") で旧データ（フィールド無し）にも耐える。
	var tc_str := ""
	var tc: String = entry.get("tc", "")
	if tc != "":
		tc_str = "[color=%s]%s[/color] " % [HEX_TC, tc]
	match entry.kind:
		"reaction":
			var speaker := TranslationServer.translate(entry.speaker_key)
			var line := TranslationServer.translate(entry.dialogue_key)
			var delta: int = entry.trust_delta
			var delta_str := _format_delta(delta)
			# 「[TC ...] > 話者：『セリフ』  +5」のレイアウト。
			return "%s[color=%s]>[/color] [color=%s][b]%s[/b][/color]  %s%s" % [
				tc_str,
				HEX_TC,
				HEX_SPEAKER,
				speaker,
				line,
				delta_str,
			]
		"system":
			# システム行は >> プレフィックス。例: [TC 00:24:13] >> 選択: ...
			return "%s[color=%s][i]>> %s[/i][/color]" % [tc_str, HEX_SYSTEM, entry.text]
		_:
			return ""


# 「TC HH:MM:SS」風プレフィックス。実時間ベースで簡易に出す。
# ゲーム内時刻が将来実装されたらそっちに差し替える。
func _now_tc() -> String:
	var t := Time.get_time_dict_from_system()
	return "[TC %02d:%02d:%02d]" % [int(t.hour), int(t.minute), int(t.second)]


func _format_delta(delta: int) -> String:
	if delta == 0:
		return ""
	var hex := HEX_DELTA_PLUS if delta > 0 else HEX_DELTA_MINUS
	# 例: "  [color=#FFC857]+5[/color]"
	return "  [color=%s]%+d[/color]" % [hex, delta]


func _trim_and_scroll() -> void:
	while _log.get_child_count() > MAX_ENTRIES:
		_log.get_child(0).queue_free()
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	# scroll bar の max は次フレームで反映されるので待つ
	await _log.get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		_scroll.scroll_vertical = int(bar.max_value)
