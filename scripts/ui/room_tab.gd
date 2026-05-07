extends Control

# Roomタブ。オペ選択 → ギフト/タッチ/メッセージ/メモリー操作を担当。
# 他タブを直接参照しない。GiftService / TouchService 経由でのみ状態を変える。

@onready var operator_list: VBoxContainer = %OperatorList
@onready var detail_panel: Control = %DetailPanel
@onready var op_name_label: Label = %OpNameLabel
@onready var trust_label: Label = %TrustLabel
@onready var stage_label: Label = %StageLabel
@onready var gift_select: OptionButton = %GiftSelect
@onready var give_button: Button = %GiveButton
@onready var touch_list: VBoxContainer = %TouchList
@onready var reaction_label: Label = %ReactionLabel

var _current_op: StringName = &""


func _ready() -> void:
	EventBus.operator_unlocked.connect(_on_operator_unlocked)
	EventBus.trust_changed.connect(_on_trust_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.reaction_played.connect(_on_reaction_played)
	EventBus.operator_locked.connect(_on_operator_locked)
	give_button.pressed.connect(_on_give_pressed)

	_rebuild_operator_list()
	detail_panel.visible = false


func _rebuild_operator_list() -> void:
	for child in operator_list.get_children():
		child.queue_free()
	for op_id: StringName in GameState.unlocked_operators:
		var op := DataRegistry.get_operator(op_id)
		if op == null:
			continue
		var b := Button.new()
		b.text = op.display_name
		b.pressed.connect(_select_operator.bind(op_id))
		operator_list.add_child(b)


func _select_operator(op_id: StringName) -> void:
	_current_op = op_id
	detail_panel.visible = true
	_refresh_detail()
	_rebuild_gift_select()
	_rebuild_touch_list()


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
	for child in touch_list.get_children():
		child.queue_free()
	if _current_op == &"":
		return
	var rt := GameState.get_runtime(_current_op)
	for spot: TouchSpotData in DataRegistry.get_touch_spots_for(_current_op):
		var b := Button.new()
		var prefix := "⚠ " if spot.is_harassment else ""
		b.text = "%s%s" % [prefix, tr(spot.display_name)]
		b.disabled = rt == null or rt.current_stage < spot.unlock_at_stage
		b.pressed.connect(TouchService.touch.bind(_current_op, spot.id))
		touch_list.add_child(b)


func _on_give_pressed() -> void:
	if _current_op == &"":
		return
	var sel := gift_select.get_selected_id()
	if sel < 0:
		return
	var item_id: StringName = gift_select.get_item_metadata(sel)
	GiftService.give(_current_op, item_id)


func _on_operator_unlocked(_op_id: StringName) -> void:
	_rebuild_operator_list()


func _on_trust_changed(op_id: StringName, _trust: int, _stage: int) -> void:
	if op_id == _current_op:
		_refresh_detail()
		_rebuild_touch_list()


func _on_inventory_changed(_id: StringName, _n: int) -> void:
	_rebuild_gift_select()


func _on_reaction_played(op_id: StringName, rule: ReactionRule) -> void:
	if op_id != _current_op:
		return
	reaction_label.text = tr("ROOM_REACTION_FMT") % [tr(rule.dialogue), rule.trust_delta]


func _on_operator_locked(op_id: StringName, until_unix: float) -> void:
	if op_id == _current_op:
		var sec := int(until_unix - Time.get_unix_time_from_system())
		reaction_label.text = tr("ROOM_LOCK_FMT") % max(0, sec)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild_operator_list()
		_refresh_detail()
		_rebuild_gift_select()
		_rebuild_touch_list()
