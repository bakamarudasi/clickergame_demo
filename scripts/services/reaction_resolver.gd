class_name ReactionResolver
extends RefCounted

# trigger_kind / trigger_id / 信頼度 / 連投回数 から最適な ReactionRule を1件選ぶ。
# UI も Service もここを介してリアクションを取得する。

static func resolve(
	trigger_kind: int,
	trigger_id: StringName,
	op_id: StringName,
	trust: int,
	consecutive: int,
	category: int = -1
) -> ReactionRule:
	var best: ReactionRule = null
	var best_priority: int = -1
	for rule: ReactionRule in DataRegistry.reactions:
		if rule.trigger_kind != trigger_kind:
			continue
		if rule.operator_id != &"" and rule.operator_id != op_id:
			continue
		if rule.match_category:
			if category < 0 or rule.category != category:
				continue
		else:
			if rule.trigger_id != &"" and rule.trigger_id != trigger_id:
				continue
		if trust < rule.min_trust or trust > rule.max_trust:
			continue
		if consecutive < rule.consecutive_count_min or consecutive > rule.consecutive_count_max:
			continue
		if rule.priority > best_priority:
			best = rule
			best_priority = rule.priority
	return best


static func apply_side_effects(rule: ReactionRule, op_id: StringName) -> void:
	for eff: ItemEffect in rule.side_effects:
		match eff.kind:
			Enums.EffectKind.TRUST_ADD:
				GameState.add_trust(op_id, eff.amount)
			Enums.EffectKind.CG_UNLOCK:
				GameState.unlock_cg(eff.target_id)
			Enums.EffectKind.OPERATOR_UNLOCK:
				GameState.unlock_operator(eff.target_id)
			Enums.EffectKind.COSTUME_UNLOCK:
				GameState.unlock_costume(op_id, eff.target_id)
			Enums.EffectKind.HARASSMENT_LOCK:
				GameState.add_harassment(op_id, eff.amount)
