class_name GiftService
extends Object

# Roomタブ UI が「ギフトを渡す」ときに呼ぶ唯一の入り口。

static func give(op_id: StringName, item_id: StringName) -> ReactionRule:
	if GameState.is_operator_locked(op_id):
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_OPERATOR_LOCKED"))
		return null
	var it := DataRegistry.get_item(item_id)
	if it == null:
		return null
	if not GameState.consume_item(item_id, 1):
		var name := TranslationServer.translate(it.display_name)
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_ITEM_EMPTY_FMT") % name)
		return null

	var rt := GameState.get_runtime(op_id)
	var consecutive: int = 1
	if rt != null:
		consecutive = rt.gift_count(item_id) + 1

	var rule := ReactionResolver.resolve(
		Enums.TriggerKind.ITEM,
		item_id,
		op_id,
		rt.trust if rt != null else 0,
		consecutive,
		it.category
	)

	GameState.record_gift(op_id, item_id)
	GameState.decay_harassment_on_gift(op_id)

	if rule != null:
		GameState.add_trust(op_id, rule.trust_delta)
		ReactionResolver.apply_side_effects(rule, op_id)
		EventBus.reaction_played.emit(op_id, rule)
	else:
		# ルール未定義なら ItemEffect から信頼度のみ反映するフォールバック
		_fallback_apply(op_id, it)
	return rule


static func _fallback_apply(op_id: StringName, it: ItemData) -> void:
	for eff: ItemEffect in it.effects:
		if eff.kind == Enums.EffectKind.TRUST_ADD:
			GameState.add_trust(op_id, eff.amount)
