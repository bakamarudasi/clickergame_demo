class_name ReactionResolver
extends Object

# trigger_kind / trigger_id / 信頼度 / 連投回数 等から最適な ReactionRule を1件選ぶ。
# UI も Service もここを介してリアクションを取得する。
# 設計判断は PROGRESSION.md §5 を参照。

static func resolve(
	trigger_kind: int,
	trigger_id: StringName,
	op_id: StringName,
	trust: int,
	consecutive: int,
	category: int = -1
) -> ReactionRule:
	var rt := GameState.get_runtime(op_id)
	var intimacy: int = rt.intimacy if rt != null else 0
	var harassment: int = rt.harassment_counter if rt != null else 0
	var equipped_costume: StringName = rt.equipped_costume if rt != null else &""

	var best: ReactionRule = null
	var best_score: int = -1
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
		if intimacy < rule.min_intimacy:
			continue
		if harassment > rule.max_harassment:
			continue
		if consecutive < rule.consecutive_count_min or consecutive > rule.consecutive_count_max:
			continue
		if GameState.prestige_count < rule.min_tier:
			continue
		if GameState.get_bond(op_id) < rule.min_bond:
			continue
		if rule.min_arousal > 0.0 and GameState.get_arousal(op_id) < rule.min_arousal:
			continue
		if rule.requires_equipped_costume != &"" and equipped_costume != rule.requires_equipped_costume:
			continue
		if rule.requires_xray_active and not GameState.xray_active:
			continue
		if not _all_active_rules_satisfied(rule.requires_active_rules):
			continue
		if not _all_unlocked(rule.requires_cgs, GameState.seen_cgs):
			continue
		if not _all_unlocked(rule.requires_memories, GameState.unlocked_memories):
			continue
		# 確率発火は他の条件を全部通った後に抽選する。
		# 0未満や1超過はクランプして1.0扱いにする。
		if rule.probability < 1.0 and randf() > rule.probability:
			continue
		var score := rule.priority * 100000 + _specificity(rule)
		if score > best_score:
			best = rule
			best_score = score
	return best


# 全部 GameState.has_rule() を満たしてれば true。空配列ならゲートなしで true。
static func _all_active_rules_satisfied(required: Array[StringName]) -> bool:
	for r in required:
		if r == &"":
			continue
		if not GameState.has_rule(r):
			return false
	return true


# required の全要素が unlocked に含まれていれば true。空配列なら true。
static func _all_unlocked(required: Array[StringName], unlocked: Array) -> bool:
	for id in required:
		if id == &"":
			continue
		if not (id in unlocked):
			return false
	return true


# 同じ priority の rule が複数マッチしたとき、より厳しい条件のものを優先する。
# priority * 100000 と比べて十分小さい範囲に収める。
static func _specificity(rule: ReactionRule) -> int:
	var s := 0
	s += rule.min_tier * 100
	s += rule.min_bond * 10
	s += int(rule.min_arousal)
	s += rule.min_intimacy
	# 累積回数ゲート（gift_count + touch consecutive 等）が高いほどより特化と扱う。
	# 同じ trigger に対して "100回目専用" のマイルストーン反応を組む時に必要。
	s += rule.consecutive_count_min
	if rule.max_harassment < 99999:
		s += 10
	if rule.requires_equipped_costume != &"":
		s += 50
	if rule.requires_xray_active:
		s += 20
	s += rule.requires_cgs.size() * 30
	s += rule.requires_memories.size() * 30
	s += rule.requires_active_rules.size() * 40
	return s


# resolve + apply_side_effects + reaction_played.emit の標準フロー。
# 呼出元の 90% はこの一行で済む。consecutive と category は ITEM 系のみ
# 意味があり、それ以外は省略可。trust は runtime から自動で引く。
# 戻り値: 発火したルール（無ければ null）。
static func fire(
	trigger_kind: int,
	trigger_id: StringName,
	op_id: StringName,
	category: int = -1,
	consecutive: int = 1
) -> ReactionRule:
	var rt := GameState.get_runtime(op_id)
	var trust: int = rt.trust if rt != null else 0
	var rule := resolve(trigger_kind, trigger_id, op_id, trust, consecutive, category)
	if rule != null:
		apply_side_effects(rule, op_id)
		EventBus.reaction_played.emit(op_id, rule)
	return rule


# ルール解決後の副作用適用。trust_delta も含めてここで一括処理する。
# 呼び出し元は別途 GameState.add_trust(rule.trust_delta) を呼んではいけない
# （二重加算になる）。trust 系を rule.side_effects に書く必要は無く、
# trust_delta フィールドだけで完結する。
static func apply_side_effects(rule: ReactionRule, op_id: StringName) -> void:
	if rule.trust_delta != 0:
		GameState.add_trust(op_id, rule.trust_delta)
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
			Enums.EffectKind.INTIMACY_ADD:
				GameState.add_intimacy(op_id, eff.amount)
			Enums.EffectKind.AROUSAL_ADD:
				GameState.add_arousal(op_id, float(eff.amount))
			Enums.EffectKind.MEMORY_UNLOCK:
				GameState.unlock_memory(eff.target_id)
			Enums.EffectKind.CG_PLAY:
				# 解放フラグは触らず、ビューア起動だけ要求する。
				EventBus.cg_play_requested.emit(eff.target_id)
