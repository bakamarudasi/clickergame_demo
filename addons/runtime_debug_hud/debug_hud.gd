extends CanvasLayer

# F12 でトグルする実行時デバッグオーバーレイ。
#
# - GameState（通貨・click_power・per_sec・prestige・xray）をリアルタイム表示
# - 選択中オペの runtime（trust / intimacy / arousal / harassment / suspicion）を表示
# - EventBus 全シグナルを動的に subscribe して emit ログをスクロール表示
# - チート操作: 通貨 +1000 / 信頼 +10 / scope battery +60s / 親密度 +10 / 発情度 +50
#
# 編集中(@tool)ではなく実行中のみアクティブ。エディタプロセスでも autoload は
# 走るので _ready で Engine.is_editor_hint() を見て無効化する。

const TOGGLE_KEY := KEY_F12
const MAX_LOG_LINES := 60

var _root: PanelContainer
var _state_label: RichTextLabel
var _log_label: RichTextLabel
var _op_picker: OptionButton
var _selected_op: StringName = &""
var _log_lines: Array[String] = []
var _signal_subs: Array = []


func _ready() -> void:
	if Engine.is_editor_hint():
		# エディタ内 inspector 等では何もしない。
		set_process_input(false)
		return
	layer = 100
	_build_ui()
	_subscribe_all_event_bus_signals()
	# 起動時は閉じている。F12 で開く。
	_root.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			_root.visible = not _root.visible
			if _root.visible:
				_refresh_op_picker()
				_refresh_state()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _root != null and _root.visible:
		_refresh_state()


# --- UI 構築 ----------------------------------------------------------------

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.anchor_top = 0.0
	_root.anchor_bottom = 1.0
	_root.offset_left = -460.0
	_root.offset_right = -8.0
	_root.offset_top = 8.0
	_root.offset_bottom = -8.0
	_root.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	bg.border_color = Color(0.85, 0.45, 0.55, 0.8)
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	_root.add_theme_stylebox_override("panel", bg)

	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_root.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG HUD (F12)"
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	vbox.add_child(title)

	# State 表示
	_state_label = RichTextLabel.new()
	_state_label.bbcode_enabled = true
	_state_label.fit_content = true
	_state_label.custom_minimum_size = Vector2(0, 220)
	_state_label.scroll_active = false
	vbox.add_child(_state_label)

	# Operator picker
	var op_row := HBoxContainer.new()
	vbox.add_child(op_row)
	var op_lbl := Label.new()
	op_lbl.text = "Op:"
	op_row.add_child(op_lbl)
	_op_picker = OptionButton.new()
	_op_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_op_picker.item_selected.connect(_on_op_selected)
	op_row.add_child(_op_picker)

	# Cheat buttons
	vbox.add_child(_separator())
	var cheats := GridContainer.new()
	cheats.columns = 2
	cheats.add_theme_constant_override("h_separation", 6)
	cheats.add_theme_constant_override("v_separation", 4)
	vbox.add_child(cheats)
	cheats.add_child(_make_button("+ ¥1,000", _cheat_currency.bind(1000)))
	cheats.add_child(_make_button("+ ¥100,000", _cheat_currency.bind(100000)))
	cheats.add_child(_make_button("Trust +10", _cheat_trust.bind(10)))
	cheats.add_child(_make_button("Trust -10", _cheat_trust.bind(-10)))
	cheats.add_child(_make_button("Intimacy +10", _cheat_intimacy.bind(10)))
	cheats.add_child(_make_button("Arousal +50", _cheat_arousal.bind(50.0)))
	cheats.add_child(_make_button("Scope batt +60s", _cheat_scope_battery.bind(60.0)))
	cheats.add_child(_make_button("Unlock all costumes", _cheat_unlock_all_costumes))
	cheats.add_child(_make_button("Toggle xray", _cheat_toggle_xray))
	cheats.add_child(_make_button("+ 💎10 prestige", _cheat_prestige_currency.bind(10)))

	# Log 表示
	vbox.add_child(_separator())
	var log_title := Label.new()
	log_title.text = "EventBus log"
	log_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(log_title)
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.custom_minimum_size = Vector2(0, 240)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log_label)

	var clear_btn := _make_button("Clear log", _clear_log)
	vbox.add_child(clear_btn)


func _separator() -> HSeparator:
	return HSeparator.new()


func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


# --- EventBus 全シグナル監視 -------------------------------------------------

func _subscribe_all_event_bus_signals() -> void:
	# EventBus 自身のスクリプトに宣言されたシグナルだけを動的に subscribe する。
	# get_signal_list() だと Node/Object の汎用シグナル (tree_entered 等) まで
	# 拾ってしまうので、get_script().get_script_signal_list() でフィルタする。
	var bus := _get_event_bus()
	if bus == null:
		return
	var script := bus.get_script() as Script
	if script == null:
		return
	for sig_info in script.get_script_signal_list():
		var sig_name: String = sig_info["name"]
		_subscribe_one(bus, sig_name)


func _subscribe_one(bus: Node, sig_name: String) -> void:
	# ローカル変数として sig_name を固定してラムダで捕獲する。
	# for ループ内に直接ラムダを書くと変数共有でハマる。
	var handler := func(a0 = null, a1 = null, a2 = null, a3 = null):
		_log_emit(sig_name, [a0, a1, a2, a3])
	bus.connect(sig_name, handler)
	_signal_subs.append([bus, sig_name, handler])


func _get_event_bus() -> Node:
	# Autoload は scene tree の root にぶら下がる。
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


func _log_emit(sig_name: String, args: Array) -> void:
	# args は _subscribe_one のラムダから渡される [a0, a1, a2, a3]。
	# 実 emit 引数が無かった位置は null（このシグナル群は全部非 null を渡す前提）。
	var parts: Array = []
	for v in args:
		if v == null:
			continue
		parts.append(str(v))
	var time_str := "%5.1f" % (Time.get_ticks_msec() / 1000.0)
	var line := "[color=#888]%s[/color] [color=#7cf]%s[/color]" % [time_str, sig_name]
	if not parts.is_empty():
		line += " [color=#ddd](%s)[/color]" % ", ".join(parts)
	_log_lines.append(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


func _clear_log() -> void:
	_log_lines.clear()
	if _log_label != null:
		_log_label.text = ""


# --- 状態表示 --------------------------------------------------------------

func _refresh_op_picker() -> void:
	var prev_op := _selected_op
	_op_picker.clear()
	var idx := 0
	var prev_idx := -1
	for op_id in GameState.unlocked_operators:
		_op_picker.add_item(str(op_id), idx)
		if op_id == prev_op:
			prev_idx = idx
		idx += 1
	if idx == 0:
		_op_picker.add_item("(none unlocked)", 0)
		_selected_op = &""
		return
	if prev_idx >= 0:
		_op_picker.select(prev_idx)
	else:
		_op_picker.select(0)
		_selected_op = GameState.unlocked_operators[0]


func _on_op_selected(idx: int) -> void:
	if idx < 0 or idx >= GameState.unlocked_operators.size():
		_selected_op = &""
		return
	_selected_op = GameState.unlocked_operators[idx]
	_refresh_state()


func _refresh_state() -> void:
	if _state_label == null:
		return
	var lines: Array[String] = []
	lines.append("[color=#fc5]Currency:[/color] ¥%s   [color=#fc5]click:[/color] %d (eff %d)   [color=#fc5]/sec:[/color] %d (eff %d)" % [
		_fmt_num(GameState.currency),
		GameState.click_power, GameState.effective_click_power(),
		GameState.per_second, GameState.effective_per_second(),
	])
	lines.append("[color=#aaa]earned this run:[/color] %s   [color=#aaa]ever:[/color] %s" % [
		_fmt_num(GameState.total_earned_this_run),
		_fmt_num(GameState.total_earned_ever),
	])
	lines.append("[color=#9cf]prestige:[/color] count=%d  💎=%d   [color=#9cf]xray:[/color] %s  battery=%.1fs  scope=%s" % [
		GameState.prestige_count, GameState.prestige_currency,
		"ON" if GameState.xray_active else "off",
		GameState.scope_battery_seconds,
		str(GameState.equipped_scope_id),
	])
	lines.append("[color=#9cf]active rules:[/color] %s" % ", ".join(GameState.active_rules.map(func(x): return str(x))))
	lines.append("[color=#9cf]unlocked ops:[/color] %s" % ", ".join(GameState.unlocked_operators.map(func(x): return str(x))))

	if _selected_op != &"":
		var rt := GameState.get_runtime(_selected_op)
		if rt != null:
			lines.append("")
			lines.append("[color=#f9a]== %s ==[/color]" % str(_selected_op))
			lines.append("  trust=%d stage=%d  intimacy=%d  arousal=%.1f (peak %.1f)" % [
				rt.trust, rt.current_stage, rt.intimacy, rt.arousal, rt.arousal_peak,
			])
			lines.append("  harassment=%d  locked_until=%.0f  inspected=%.0f" % [
				rt.harassment_counter, rt.locked_until, rt.last_inspection_unix,
			])
			lines.append("  xray_suspicion=%.2f  costume=%s" % [
				rt.xray_suspicion, str(rt.equipped_costume),
			])
			lines.append("  bond=%d  prestige_greet_pending=%s" % [
				GameState.get_bond(_selected_op),
				"yes" if rt.pending_prestige_greet else "no",
			])
	_state_label.text = "\n".join(lines)


static func _fmt_num(n: int) -> String:
	# 桁区切りカンマ整形
	var s := str(abs(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	if n < 0:
		out = "-" + out
	return out


# --- チート ----------------------------------------------------------------

func _cheat_currency(amount: int) -> void:
	GameState.add_currency(amount)


func _cheat_prestige_currency(amount: int) -> void:
	GameState.add_prestige_currency(amount)


func _cheat_trust(delta: int) -> void:
	if _selected_op == &"":
		return
	GameState.add_trust(_selected_op, delta)


func _cheat_intimacy(delta: int) -> void:
	if _selected_op == &"":
		return
	GameState.add_intimacy(_selected_op, delta)


func _cheat_arousal(delta: float) -> void:
	if _selected_op == &"":
		return
	GameState.add_arousal(_selected_op, delta)


func _cheat_scope_battery(seconds: float) -> void:
	GameState.add_scope_battery(seconds)


func _cheat_toggle_xray() -> void:
	GameState.set_xray_active(not GameState.xray_active)


func _cheat_unlock_all_costumes() -> void:
	if _selected_op == &"":
		return
	for costume_id in DataRegistry.costumes.keys():
		var cos: CostumeData = DataRegistry.costumes[costume_id]
		if cos != null and cos.operator_id == _selected_op:
			GameState.unlock_costume(_selected_op, costume_id)
