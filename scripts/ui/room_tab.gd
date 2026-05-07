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
@onready var inspection_button: Button = %InspectionButton
@onready var portrait_view: TextureRect = %PortraitView
@onready var scope_toggle: Button = %ScopeToggle
@onready var battery_bar: ProgressBar = %BatteryBar
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var scope_row: HBoxContainer = %ScopeRow

var _current_op: StringName = &""
var _pose_show_until_unix: float = 0.0


func _ready() -> void:
	EventBus.operator_unlocked.connect(_on_operator_unlocked)
	EventBus.trust_changed.connect(_on_trust_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.reaction_played.connect(_on_reaction_played)
	EventBus.operator_locked.connect(_on_operator_locked)
	EventBus.inspection_performed.connect(_on_inspection_performed)
	EventBus.xray_changed.connect(_on_xray_changed)
	EventBus.scope_battery_changed.connect(_on_scope_battery_changed)
	EventBus.scope_equipped.connect(_on_scope_equipped)
	EventBus.xray_suspicion_changed.connect(_on_xray_suspicion_changed)
	EventBus.xray_caught.connect(_on_xray_caught)
	EventBus.costume_equipped.connect(_on_costume_equipped)
	give_button.pressed.connect(_on_give_pressed)
	inspection_button.pressed.connect(_on_inspection_pressed)
	scope_toggle.toggled.connect(_on_scope_toggled)
	set_process(true)

	_rebuild_operator_list()
	detail_panel.visible = false
	_refresh_scope_ui()
	_refresh_battery_ui()


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
	_refresh_inspection_button()
	_refresh_portrait()
	_refresh_suspicion_ui()


func _process(delta: float) -> void:
	if not visible:
		return
	# 眼鏡ON中は毎フレーム ScopeService に進行を任せる
	if GameState.xray_active and _current_op != &"":
		ScopeService.tick(delta, _current_op)
	if _current_op == &"":
		return
	# 検査クールダウン残量
	if not InspectionService.can_inspect(_current_op):
		_refresh_inspection_button()
	# 見せつけポーズの解除タイマ
	if _pose_show_until_unix > 0.0 and Time.get_unix_time_from_system() >= _pose_show_until_unix:
		_pose_show_until_unix = 0.0
		_refresh_portrait()


func _refresh_inspection_button() -> void:
	if _current_op == &"":
		inspection_button.disabled = true
		inspection_button.text = TranslationServer.translate("ROOM_INSPECTION_BUTTON")
		return
	var remaining := InspectionService.cooldown_remaining_sec(_current_op)
	if remaining <= 0.0:
		inspection_button.disabled = false
		inspection_button.text = TranslationServer.translate("ROOM_INSPECTION_BUTTON")
	else:
		inspection_button.disabled = true
		inspection_button.text = TranslationServer.translate("ROOM_INSPECTION_COOLDOWN_FMT") % int(ceil(remaining))


func _on_inspection_pressed() -> void:
	if _current_op == &"":
		return
	InspectionService.inspect(_current_op)


func _on_inspection_performed(op_id: StringName) -> void:
	if op_id == _current_op:
		_refresh_inspection_button()


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


# --- 立ち絵表示 ----------------------------------------------------------

func _refresh_portrait() -> void:
	if _current_op == &"":
		portrait_view.texture = null
		return
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		portrait_view.texture = null
		return
	var costume := DataRegistry.get_costume(rt.equipped_costume)
	if costume == null:
		portrait_view.texture = null
		return
	if _pose_show_until_unix > Time.get_unix_time_from_system():
		portrait_view.texture = costume.sprite_pose_seductive if costume.sprite_pose_seductive != null else costume.sprite
	elif GameState.xray_active:
		portrait_view.texture = costume.get_xray_sprite(ScopeService.current_view_kind())
	else:
		portrait_view.texture = costume.sprite


func _on_costume_equipped(op_id: StringName, _costume_id: StringName) -> void:
	if op_id == _current_op:
		_refresh_portrait()


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


func _on_xray_changed(_active: bool) -> void:
	scope_toggle.set_pressed_no_signal(GameState.xray_active)
	_refresh_portrait()


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
	# 高信頼ルートで sprite_pose_seductive を表示する反応の場合だけ pose を出す
	# 簡易判定：直近の reaction が DOMINATED の時に pose を一定時間表示
	var rt := GameState.get_runtime(op_id)
	if rt != null and rt.trust > 0:
		_pose_show_until_unix = Time.get_unix_time_from_system() + UIConstants.XRAY_POSE_SHOW_SEC
	_refresh_portrait()
	_refresh_suspicion_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild_operator_list()
		_refresh_detail()
		_rebuild_gift_select()
		_rebuild_touch_list()
		_refresh_inspection_button()
		_refresh_scope_ui()
