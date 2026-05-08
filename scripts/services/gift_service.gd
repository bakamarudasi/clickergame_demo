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
	# ReactionRule が見つからなかった場合のフォールバック。
	# キャラ反応に強く依存しない効果（信頼度・親密度・発情度・ハラス）はここで適用する。
	# CG/COSTUME など他のキャラ依存系はリアクション側でしか発火しない設計。
	for eff: ItemEffect in it.effects:
		match eff.kind:
			Enums.EffectKind.TRUST_ADD:
				GameState.add_trust(op_id, eff.amount)
			Enums.EffectKind.INTIMACY_ADD:
				GameState.add_intimacy(op_id, eff.amount)
			Enums.EffectKind.AROUSAL_ADD:
				GameState.add_arousal(op_id, float(eff.amount))
			Enums.EffectKind.HARASSMENT_LOCK:
				GameState.add_harassment(op_id, eff.amount)
			_:
				pass
