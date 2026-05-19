class_name ScopeService
extends Object

# 紳士眼鏡（Scope）。Roomタブ UI が呼ぶ唯一の入り口。
#
# - toggle(op_id): ON/OFF 切替
# - tick(delta, op_id): 毎フレーム呼ばれる。バッテリー消費＆ suspicion 加算、閾値超で発覚
# - 装備中スコープが無い／バッテリ切れなら自動 OFF


static func equipped() -> ScopeData:
	if GameState.equipped_scope_id == &"":
		return null
	return DataRegistry.get_scope(GameState.equipped_scope_id)


static func current_view_kind() -> StringName:
	var s := equipped()
	return s.view_kind if s != null else &""


static func can_toggle_on() -> bool:
	return equipped() != null and GameState.scope_battery_seconds > 0.0


static func toggle(op_id: StringName) -> void:
	if GameState.xray_active:
		_set_off()
		return
	if not can_toggle_on():
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_SCOPE_NO_BATTERY"))
		return
	GameState.set_xray_active(true)
	# 切替時に suspicion をリセットして気付かれ難くする運用にしてもよい
	if op_id != &"":
		GameState.reset_xray_suspicion(op_id)


static func _set_off() -> void:
	GameState.set_xray_active(false)


# RoomTab._process から毎フレーム呼ぶ
static func tick(delta: float, op_id: StringName) -> void:
	if not GameState.xray_active:
		return
	# バッテリ消費
	GameState.consume_scope_battery(delta)
	if GameState.scope_battery_seconds <= 0.0:
		_set_off()
		return
	if op_id == &"":
		return

	# Suspicion 加算
	var rate := UIConstants.XRAY_SUSPICION_PER_SEC
	var scope := equipped()
	if scope != null:
		rate *= scope.suspicion_rate
	var op := DataRegistry.get_operator(op_id)
	if op != null:
		rate *= op.xray_detection_rate
	GameState.add_xray_suspicion(op_id, rate * delta)

	var rt := GameState.get_runtime(op_id)
	if rt != null and rt.xray_suspicion >= UIConstants.XRAY_SUSPICION_THRESHOLD:
		_trigger_caught(op_id)


static func _trigger_caught(op_id: StringName) -> void:
	# ON状態を解除した上で、信頼度＆性格に応じた反応を引く
	_set_off()
	GameState.reset_xray_suspicion(op_id)

	# 高信頼でのバレ累計を OperatorRuntime に貯め、ReactionResolver には
	# consecutive 引数として渡す。これで「N 回目のバレで特別反応／CG 解放」を
	# 既存の consecutive_count_min/max ゲートで組める。
	var rt := GameState.get_runtime(op_id)
	var consecutive := 1
	if rt != null and rt.trust >= 80:
		rt.xray_caught_high_count += 1
		consecutive = rt.xray_caught_high_count

	ReactionResolver.fire(Enums.TriggerKind.XRAY_CAUGHT, &"", op_id, -1, consecutive)
	EventBus.xray_caught.emit(op_id)
