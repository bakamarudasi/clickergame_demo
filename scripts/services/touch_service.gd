class_name TouchService
extends Object

# 通常タッチもセクハラタッチも全部ここを通す。
# is_harassment フラグで分岐し、ロック判定もここで処理。

static func touch(op_id: StringName, spot_id: StringName) -> ReactionRule:
	if ReactionDispatcher.try_locked_revisit(op_id):
		return null
	var spot := DataRegistry.get_touch_spot(spot_id)
	if spot == null:
		return null

	var rt := GameState.get_runtime(op_id)
	if rt == null:
		return null

	# 段階解放ゲート
	if rt.current_stage < spot.unlock_at_stage:
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_TOUCH_GATED"))
		return null

	var trigger_kind := (
		Enums.TriggerKind.HARASSMENT
		if spot.is_harassment
		else Enums.TriggerKind.TOUCH
	)
	# resolve はルックアップだけ先に走らせる（rule.trust_delta の正負で
	# spot 側の基礎ペナルティ適用要否が変わるため）。発火は最後にまとめて。
	var rule := ReactionResolver.resolve(trigger_kind, spot_id, op_id, rt.trust, 1, -1)

	# TouchSpot の基礎値（spot 側）と、Rule の trust_delta（rule 側）は別物。
	# 前者は「触れた結果として最低限動く trust」、後者は「ルールが見つかった時の上乗せ」。
	# rule.trust_delta は apply_side_effects 側で適用するのでここでは触らない。
	if spot.is_harassment:
		if rule == null or rule.trust_delta < 0:
			GameState.add_trust(op_id, spot.trust_penalty_low)
		GameState.add_harassment(op_id, spot.harassment_weight)
	else:
		GameState.add_trust(op_id, spot.trust_delta_base)

	if rule != null:
		ReactionResolver.apply_side_effects(rule, op_id)
		EventBus.reaction_played.emit(op_id, rule)
	return rule
