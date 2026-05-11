class_name InspectionService
extends Object

# 身だしなみ検査。Roomタブ UI が呼ぶ唯一の入り口。
# クールダウン中なら toast を出して null を返す。

static func can_inspect(op_id: StringName) -> bool:
	if GameState.is_operator_locked(op_id):
		return false
	var rt := GameState.get_runtime(op_id)
	if rt == null:
		return false
	return rt.inspection_cooldown_remaining(UIConstants.INSPECTION_COOLDOWN_SEC) <= 0.0


static func cooldown_remaining_sec(op_id: StringName) -> float:
	var rt := GameState.get_runtime(op_id)
	if rt == null:
		return 0.0
	return rt.inspection_cooldown_remaining(UIConstants.INSPECTION_COOLDOWN_SEC)


static func inspect(op_id: StringName) -> ReactionRule:
	if ReactionDispatcher.try_locked_revisit(op_id):
		return null
	if not can_inspect(op_id):
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_INSPECTION_COOLDOWN"))
		return null

	GameState.mark_inspected(op_id)
	return ReactionResolver.fire(Enums.TriggerKind.INSPECTION, &"", op_id)
