extends Control

# Roomタブ。オペ選択 → ギフト/タッチ/メッセージ/メモリー操作を担当。
# 他タブを直接参照しない。GiftService / TouchService 経由でのみ状態を変える。
#
# 立ち絵まわり・アイドルフレーバー・会話ログは別ファイルへ委譲：
#   - PortraitController  立ち絵 / 表情 / xray 窓 / モザイク / シーン方式
#   - IdleFlavorTracker   1/3/5/6 分の段階発火 + バフ
#   - DialogueLogView     会話ログの追記 / 末尾自動スクロール

const INTIMACY_BAR_DISPLAY_MAX := 200   # 親密度バーの目盛上限（実値はラベルで表示）

@onready var operator_list: VBoxContainer = %OperatorList
@onready var detail_panel: Control = %DetailPanel
@onready var op_name_label: Label = %OpNameLabel
@onready var trust_label: Label = %TrustLabel
@onready var stage_label: Label = %StageLabel
@onready var intimacy_label: Label = %IntimacyLabel
@onready var intimacy_bar: ProgressBar = %IntimacyBar
@onready var arousal_label: Label = %ArousalLabel
@onready var arousal_bar: ProgressBar = %ArousalBar
@onready var gift_select: OptionButton = %GiftSelect
@onready var give_button: Button = %GiveButton
@onready var touch_select: OptionButton = %TouchSelect
@onready var touch_button: Button = %TouchButton
@onready var inspection_button: Button = %InspectionButton
@onready var portrait_view: TextureRect = %PortraitView
@onready var face_overlay: TextureRect = %FaceOverlay
@onready var scope_window: ScopeWindow = %ScopeWindow
@onready var scope_toggle: Button = %ScopeToggle
@onready var battery_bar: ProgressBar = %BatteryBar
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var scope_row: HBoxContainer = %ScopeRow
@onready var dialogue_scroll: ScrollContainer = %DialogueScroll
@onready var dialogue_log: VBoxContainer = %DialogueLog
@onready var choice_panel: PanelContainer = %ChoicePanel
@onready var choice_vbox: VBoxContainer = %ChoiceVBox

var _current_op: StringName = &""
var _portrait: PortraitController
var _idle: IdleFlavorTracker
var _dialogue: DialogueLogView
var _choices: ChoicePanelView


func _ready() -> void:
	_portrait = PortraitController.new(portrait_view, face_overlay, scope_window)
	_idle = IdleFlavorTracker.new()
	_idle.fire_buff_applied.connect(_on_idle_fire_buff)
	_dialogue = DialogueLogView.new(dialogue_scroll, dialogue_log)
	_choices = ChoicePanelView.new(choice_panel, choice_vbox)
	_choices.chosen.connect(_on_choice_picked)

	for entry in [
		[EventBus.operator_unlocked, _on_operator_unlocked],
		[EventBus.trust_changed, _on_trust_changed],
		[EventBus.intimacy_changed, _on_intimacy_changed],
		[EventBus.arousal_changed, _on_arousal_changed],
		[EventBus.inventory_changed, _on_inventory_changed],
		[EventBus.reaction_played, _on_reaction_played],
		[EventBus.operator_locked, _on_operator_locked],
		[EventBus.inspection_performed, _on_inspection_performed],
		[EventBus.xray_changed, _on_xray_changed],
		[EventBus.scope_battery_changed, _on_scope_battery_changed],
		[EventBus.scope_equipped, _on_scope_equipped],
		[EventBus.xray_suspicion_changed, _on_xray_suspicion_changed],
		[EventBus.xray_caught, _on_xray_caught],
		[EventBus.costume_equipped, _on_costume_equipped],
	]:
		(entry[0] as Signal).connect(entry[1] as Callable)

	give_button.pressed.connect(_on_give_pressed)
	touch_button.pressed.connect(_on_touch_pressed)
	inspection_button.pressed.connect(_on_inspection_pressed)
	scope_toggle.toggled.connect(_on_scope_toggled)
	visibility_changed.connect(_on_self_visibility_changed)
	set_process(true)

	_rebuild_operator_list()
	detail_panel.visible = false
	_refresh_scope_ui()
	_refresh_battery_ui()
	_idle.reset()


func _process(delta: float) -> void:
	if not visible:
		return
	if GameState.xray_active and _current_op != &"":
		ScopeService.tick(delta, _current_op)
	if _current_op == &"":
		return
	if not InspectionService.can_inspect(_current_op):
		_refresh_inspection_button()
	_idle.tick(_current_op)
	_portrait.tick()


# --- オペレーター選択 ----------------------------------------------------

func _rebuild_operator_list() -> void:
	for child in operator_list.get_children():
		child.queue_free()
	for op_id: StringName in GameState.unlocked_operators:
		var op := DataRegistry.get_operator(op_id)
		if op == null:
			continue
		var b := Button.new()
		# OperatorData.display_name は翻訳キー（"OP_LEMUEN_NAME" 等）。表示時は必ず tr() を通す。
		b.text = tr(op.display_name)
		b.pressed.connect(_select_operator.bind(op_id))
		operator_list.add_child(b)


func _select_operator(op_id: StringName) -> void:
	_current_op = op_id
	_dialogue.clear()
	_choices.clear()
	detail_panel.visible = true
	_refresh_detail()
	_rebuild_gift_select()
	_rebuild_touch_list()
	_refresh_inspection_button()
	_portrait.set_operator(op_id)
	_refresh_suspicion_ui()
	_consume_prestige_greet(op_id)


# プレステージ完了後の最初の選択時に PRESTIGE 反応を 1 度だけ流す。
func _consume_prestige_greet(op_id: StringName) -> void:
	var rt := GameState.get_runtime(op_id)
	if rt == null or not rt.pending_prestige_greet:
		return
	rt.pending_prestige_greet = false
	ReactionDispatcher.dispatch_prestige_greet(op_id)


# --- 詳細パネル / ゲージ -------------------------------------------------

func _refresh_detail() -> void:
	if _current_op == &"":
		return
	var op := DataRegistry.get_operator(_current_op)
	var rt := GameState.get_runtime(_current_op)
	if op == null or rt == null:
		return
	op_name_label.text = tr(op.display_name)
	trust_label.text = tr("ROOM_TRUST_FMT") % rt.trust
	var stage_title := ""
	for s in op.stages:
		if s.stage_index == rt.current_stage:
			stage_title = tr(s.title)
			break
	stage_label.text = tr("ROOM_STAGE_FMT") % [rt.current_stage, stage_title]
	_refresh_gauges()


func _refresh_gauges() -> void:
	if _current_op == &"":
		intimacy_label.text = ""
		arousal_label.text = ""
		intimacy_bar.value = 0.0
		arousal_bar.value = 0.0
		return
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		return
	intimacy_label.text = tr("STATUS_INTIMACY_FMT") % rt.intimacy
	intimacy_bar.value = clampf(float(rt.intimacy), 0.0, float(INTIMACY_BAR_DISPLAY_MAX))
	var a := GameState.get_arousal(_current_op)
	arousal_label.text = tr("STATUS_AROUSAL_FMT") % int(a)
	arousal_bar.value = clampf(a, 0.0, UIConstants.AROUSAL_MAX)


# --- ギフト / タッチ / 検査 ----------------------------------------------

func _rebuild_gift_select() -> void:
	gift_select.clear()
	var idx := 0
	for it: ItemData in DataRegistry.items.values():
		if not it.is_consumable:
			continue
		var n := GameState.item_count(it.id)
		if n <= 0:
			continue
		gift_select.add_item(tr("ROOM_GIFT_INV_FMT") % [tr(it.display_name), n], idx)
		gift_select.set_item_metadata(idx, it.id)
		idx += 1


func _rebuild_touch_list() -> void:
	# 名前は歴史的経緯で _list のまま。中身は OptionButton 再生成。
	# - 解禁段階未満は set_item_disabled で灰色化（リスト自体には残す＝
	#   「次の段階で開く操作」がプレイヤーに見える）
	# - 全項目 disabled の場合は触れるボタン自体を無効化
	touch_select.clear()
	touch_button.disabled = true
	if _current_op == &"":
		return
	var rt := GameState.get_runtime(_current_op)
	var idx := 0
	var first_enabled := -1
	for spot: TouchSpotData in DataRegistry.get_touch_spots_for(_current_op):
		var prefix := "⚠ " if spot.is_harassment else ""
		touch_select.add_item("%s%s" % [prefix, tr(spot.display_name)], idx)
		touch_select.set_item_metadata(idx, spot.id)
		var locked := rt == null or rt.current_stage < spot.unlock_at_stage
		touch_select.set_item_disabled(idx, locked)
		if not locked and first_enabled < 0:
			first_enabled = idx
		idx += 1
	if first_enabled >= 0:
		touch_select.select(first_enabled)
		touch_button.disabled = false


func _on_give_pressed() -> void:
	if _current_op == &"":
		return
	var sel := gift_select.get_selected_id()
	if sel < 0:
		return
	var item_id: StringName = gift_select.get_item_metadata(sel)
	GiftService.give(_current_op, item_id)


func _on_touch_pressed() -> void:
	if _current_op == &"":
		return
	var sel := touch_select.get_selected_id()
	if sel < 0:
		return
	# disabled 項目を select() しても OptionButton は素直に通すので、念のため弾く
	if touch_select.is_item_disabled(touch_select.get_item_index(sel)):
		return
	var spot_id: StringName = touch_select.get_item_metadata(sel)
	TouchService.touch(_current_op, spot_id)


func _refresh_inspection_button() -> void:
	if _current_op == &"":
		inspection_button.disabled = true
		# Button.text に翻訳キーをそのまま入れれば Godot が自動翻訳・自動再翻訳する
		inspection_button.text = "ROOM_INSPECTION_BUTTON"
		return
	var remaining := InspectionService.cooldown_remaining_sec(_current_op)
	if remaining <= 0.0:
		inspection_button.disabled = false
		inspection_button.text = "ROOM_INSPECTION_BUTTON"
	else:
		inspection_button.disabled = true
		# 動的フォーマット文字列なので tr() で展開する必要がある
		inspection_button.text = tr("ROOM_INSPECTION_COOLDOWN_FMT") % int(ceil(remaining))


func _on_inspection_pressed() -> void:
	if _current_op == &"":
		return
	InspectionService.inspect(_current_op)


# --- 紳士眼鏡 UI ---------------------------------------------------------

func _refresh_scope_ui() -> void:
	var has_scope := ScopeService.equipped() != null
	scope_row.visible = has_scope
	suspicion_bar.visible = has_scope
	scope_toggle.set_pressed_no_signal(GameState.xray_active)


func _refresh_battery_ui() -> void:
	var s := ScopeService.equipped()
	if s == null:
		battery_bar.value = 0.0
		return
	battery_bar.value = clamp(GameState.scope_battery_seconds / s.battery_max_sec, 0.0, 1.0)


func _refresh_suspicion_ui() -> void:
	if _current_op == &"":
		suspicion_bar.value = 0.0
		return
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		suspicion_bar.value = 0.0
		return
	suspicion_bar.value = clamp(rt.xray_suspicion / UIConstants.XRAY_SUSPICION_THRESHOLD, 0.0, 1.0)


func _on_scope_toggled(_pressed: bool) -> void:
	ScopeService.toggle(_current_op)
	_idle.reset()


# --- イベントハンドラ ---------------------------------------------------

func _on_self_visibility_changed() -> void:
	if visible:
		_idle.reset()


func _on_idle_fire_buff() -> void:
	EventBus.toast_requested.emit(
		tr("TOAST_IDLE_BUFF_FMT") % [int(UIConstants.IDLE_BUFF_MULT), int(UIConstants.IDLE_BUFF_DURATION_SEC)]
	)


func _on_operator_unlocked(_op_id: StringName) -> void:
	_rebuild_operator_list()


func _on_trust_changed(op_id: StringName, _trust: int, _stage: int) -> void:
	if op_id == _current_op:
		_refresh_detail()
		_rebuild_touch_list()


func _on_intimacy_changed(op_id: StringName, _v: int) -> void:
	if op_id == _current_op:
		_refresh_gauges()


func _on_arousal_changed(op_id: StringName, _v: float) -> void:
	if op_id == _current_op:
		_refresh_gauges()
		_portrait.on_arousal_changed()


func _on_inventory_changed(_id: StringName, _n: int) -> void:
	_rebuild_gift_select()


func _on_reaction_played(op_id: StringName, rule: ReactionRule) -> void:
	if op_id != _current_op:
		return
	# 話者は現在オペ。display_name は翻訳キーなのでログ側で翻訳する。
	var op := DataRegistry.get_operator(op_id)
	var speaker_key := op.display_name if op != null else ""
	_dialogue.append_reaction(speaker_key, rule.pick_dialogue(), rule.trust_delta)
	_portrait.flash_expression(rule.expression)
	# 選択肢がある場合は本体台詞のあとに提示。同時に複数 active にはしない
	# （新規 rule が来たら古い選択肢は捨てる）。
	if not rule.choices.is_empty():
		_choices.show_choices(rule.choices)
	# IDLE 反応は「アイドル経過の結果」なのでタイマーをリセットしない
	# （リセットすると stage_1 → 待機 → stage_1 のループになる）。
	# それ以外の反応＝ユーザーの能動的なアクションなのでタイマーを巻き戻す。
	if rule.trigger_kind != Enums.TriggerKind.IDLE:
		_idle.reset()


func _on_choice_picked(choice: ReactionChoice) -> void:
	if _current_op == &"":
		return
	# 1) プレイヤーが選んだことをログに残す（システム行）
	_dialogue.append_system("→ %s" % tr(choice.label_key))
	# 2) 効果を適用してオペのレスポンスを取得
	var response_key := ReactionResolver.apply_choice(choice, _current_op)
	# 3) レスポンスを話者ログに積む（trust_delta もカラー表示）
	var op := DataRegistry.get_operator(_current_op)
	var speaker_key := op.display_name if op != null else ""
	_dialogue.append_reaction(speaker_key, response_key, choice.trust_delta)
	# 4) 表情フラッシュ
	if choice.expression != &"":
		_portrait.flash_expression(choice.expression)
	# 選択肢ボタンに反応した＝能動アクション扱い
	_idle.reset()


func _on_operator_locked(op_id: StringName, until_unix: float) -> void:
	if op_id == _current_op:
		var sec := int(until_unix - Time.get_unix_time_from_system())
		_dialogue.append_system(tr("ROOM_LOCK_FMT") % max(0, sec))


func _on_inspection_performed(op_id: StringName) -> void:
	if op_id == _current_op:
		_refresh_inspection_button()


func _on_xray_changed(_active: bool) -> void:
	scope_toggle.set_pressed_no_signal(GameState.xray_active)
	_portrait.refresh()


func _on_scope_battery_changed(_v: float) -> void:
	_refresh_battery_ui()


func _on_scope_equipped(_id: StringName) -> void:
	_refresh_scope_ui()
	_refresh_battery_ui()


func _on_xray_suspicion_changed(op_id: StringName, _v: float) -> void:
	if op_id == _current_op:
		_refresh_suspicion_ui()


func _on_xray_caught(op_id: StringName) -> void:
	if op_id != _current_op:
		return
	var rt := GameState.get_runtime(op_id)
	if rt != null and rt.trust > 0:
		_portrait.show_seductive_pose(UIConstants.XRAY_POSE_SHOW_SEC)
	else:
		_portrait.refresh()
	_refresh_suspicion_ui()


func _on_costume_equipped(op_id: StringName, _costume_id: StringName) -> void:
	if op_id == _current_op:
		_portrait.refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rebuild_operator_list()
		_refresh_detail()
		_rebuild_gift_select()
		_rebuild_touch_list()
		_refresh_inspection_button()
		_refresh_scope_ui()
		if _dialogue != null:
			_dialogue.rebuild_views()
