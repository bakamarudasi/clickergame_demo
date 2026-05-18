class_name NextUnlockBadge
extends RefCounted

# Room タブ「次の解禁プレビュー」バッジ。現在ステージと次ステージの間で
# 信頼度進捗を可視化し、解禁予定の衣装/CG 数を伏字で見せる（ロック感の演出）。
# 解禁内容の名前は未解禁時には出さない――プレイヤーが「あと何かある」と
# 感じる余白を残すのが狙い。
#
# 表示モード：
#  - hidden : オペレータ未選択
#  - locked : 次ステージあり。進捗バー + 「??? 衣装 × N」みたいなカウント
#  - ready  : 信頼が閾値到達済（次フレームで stage_advanced 発火直前など）。ハイライト
#  - max    : 最終ステージ。フレーバ表示のみ

const PULSE_PERIOD: float = 1.4

var _panel: PanelContainer
var _stage_label: Label
var _progress_label: Label
var _progress_bar: ProgressBar
var _unlocks_label: Label
var _host: Control
var _pulse_tween: Tween


func _init(
	panel: PanelContainer,
	stage_label: Label,
	progress_label: Label,
	progress_bar: ProgressBar,
	unlocks_label: Label,
	host: Control,
) -> void:
	_panel = panel
	_stage_label = stage_label
	_progress_label = progress_label
	_progress_bar = progress_bar
	_unlocks_label = unlocks_label
	_host = host
	_panel.visible = false
	# 子 Label 側で mouse_filter=STOP のままだとパネルのツールチップが
	# 発火しない。子に hover を素通りさせてパネル自身にイベントを届ける。
	_stage_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_progress_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_unlocks_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_PASS


func refresh(op_id: StringName) -> void:
	if op_id == &"":
		_panel.visible = false
		_stop_pulse()
		return
	var op := DataRegistry.get_operator(op_id)
	var rt := GameState.get_runtime(op_id)
	if op == null or rt == null:
		_panel.visible = false
		_stop_pulse()
		return

	# 現ステージとその次のステージを stage_index ベースで取り出す。
	# stages は順序保証が無いので毎回ソート相当の探索をする。
	var current_idx: int = rt.current_stage
	var current_threshold := 0
	var next_stage: TrustStageData = null
	for s: TrustStageData in op.stages:
		if s.stage_index == current_idx:
			current_threshold = s.threshold
		if s.stage_index > current_idx:
			if next_stage == null or s.stage_index < next_stage.stage_index:
				next_stage = s

	_panel.visible = true
	if next_stage == null:
		_show_max()
		return

	# 進捗 = (今の信頼 - 現ステージ閾値) / (次の閾値 - 現ステージ閾値)。
	# 1.0 を超えてる場合は ready 表示（実際にはこの瞬間 stage_advanced が来るが、
	# call_deferred の隙間で見える可能性があるので考慮）。
	var span := max(1, next_stage.threshold - current_threshold)
	var earned := max(0, rt.trust - current_threshold)
	var ratio: float = clampf(float(earned) / float(span), 0.0, 1.0)
	_progress_bar.value = ratio * 100.0
	_progress_label.text = TranslationServer.translate("UI_ROOM_NEXT_TRUST_FMT") % [rt.trust, next_stage.threshold]

	# 次ステージのタイトルは伏字。閾値到達時のみ「✦ 解禁可能」サインに切替。
	if rt.trust >= next_stage.threshold:
		_stage_label.text = TranslationServer.translate("UI_ROOM_NEXT_READY")
		_start_pulse()
	else:
		_stage_label.text = TranslationServer.translate("UI_ROOM_NEXT_STAGE_FMT") % next_stage.stage_index
		_stop_pulse()

	# 解禁内容はカウントだけ伏字で。中身は当然出さない。
	var parts: Array[String] = []
	var costumes_n := next_stage.costume_unlocks.size()
	var cgs_n := next_stage.cg_unlocks.size()
	if costumes_n > 0:
		parts.append(TranslationServer.translate("UI_ROOM_NEXT_COSTUMES_FMT") % costumes_n)
	if cgs_n > 0:
		parts.append(TranslationServer.translate("UI_ROOM_NEXT_CGS_FMT") % cgs_n)
	if parts.is_empty():
		_unlocks_label.text = TranslationServer.translate("UI_ROOM_NEXT_NO_REWARDS")
	else:
		_unlocks_label.text = "   ".join(parts)

	# ホバー時のツールチップ：解禁する各項目を 1 行ずつ「??? 衣装」「??? CG」で羅列。
	# 名前は出さないが、何個・どのカテゴリかは見える。
	var tip_lines: Array[String] = [TranslationServer.translate("UI_ROOM_NEXT_TOOLTIP_HEADER")]
	for _id in next_stage.costume_unlocks:
		tip_lines.append("  " + TranslationServer.translate("UI_ROOM_NEXT_LOCKED_COSTUME"))
	for _id in next_stage.cg_unlocks:
		tip_lines.append("  " + TranslationServer.translate("UI_ROOM_NEXT_LOCKED_CG"))
	_panel.tooltip_text = "\n".join(tip_lines)


func _show_max() -> void:
	_stage_label.text = TranslationServer.translate("UI_ROOM_NEXT_MAX")
	_progress_bar.value = 100.0
	_progress_label.text = ""
	_unlocks_label.text = ""
	_panel.tooltip_text = TranslationServer.translate("UI_ROOM_NEXT_MAX")
	_stop_pulse()


func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		return
	_pulse_tween = _host.create_tween().set_loops()
	_pulse_tween.tween_property(_panel, "modulate", Color(1.25, 1.2, 0.9, 1.0), PULSE_PERIOD * 0.5)
	_pulse_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), PULSE_PERIOD * 0.5)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	_panel.modulate = Color(1, 1, 1, 1)
