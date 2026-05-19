class_name CombineService
extends Object

# Roomタブ UI が「複数アイテム同時使用（コンボ）」で渡す時の入り口。
# 単発ギフトは GiftService.give() を引き続き使う想定（こちらは 2 個以上専用）。
# 入力アイテムは「最大 3 個・同一アイテム重複OK」。
# 同一アイテムを N 回入れる（rope×3 等）が成立するよう、内部では
# multi-set として扱い、ソートして resolve_combo に渡す。

const MAX_COMBO_SIZE := 3


static func combine(op_id: StringName, item_ids: Array) -> ReactionRule:
	if op_id == &"" or item_ids.is_empty():
		return null
	# ハラスロック中は GiftService と同じく差し戻し。
	if ReactionDispatcher.try_locked_revisit(op_id):
		return null

	# ソートだけ（dedup しない）。同一アイテムの重複は仕様。
	var sorted_ids := _sort_stringnames(item_ids)
	if sorted_ids.size() > MAX_COMBO_SIZE:
		return null
	if sorted_ids.size() == 1:
		# 単発はギフト経路。UI 側で防いでるはずだがフェイルセーフ。
		return GiftService.give(op_id, sorted_ids[0])

	# 在庫一括チェック（同一 id を N 回必要なケースを正しくカウント）。
	# 1 個でも足りなければ何も消費せず終了。
	var counts: Dictionary = {}
	for id in sorted_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts.keys():
		if GameState.item_count(id) < int(counts[id]):
			EventBus.toast_requested.emit(TranslationServer.translate("TOAST_COMBO_ITEM_MISSING"))
			return null

	# 反応解決（消費の前）。combo_item_ids も sorted（重複込み）で比較される。
	var rule := ReactionResolver.resolve_combo(op_id, sorted_ids)

	# アイテムは見つかっても見つからなくても消費する（コンボ「試行」をした扱い）。
	# 同一 id を N 個入れたなら N 回 record_gift される（gift_count 累計が伸びる）。
	for id in sorted_ids:
		GameState.consume_item(id, 1)
		GameState.record_gift(op_id, id)
		GameState.decay_harassment_on_gift(op_id)

	if rule != null:
		ReactionResolver.apply_side_effects(rule, op_id)
		EventBus.reaction_played.emit(op_id, rule)
	else:
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_COMBO_NO_REACTION"))
	return rule


# 入力 Array を StringName 化＆ソート（dedup しない）。空文字は除外。
static func _sort_stringnames(src: Array) -> Array:
	var out: Array = []
	for v in src:
		var sn := StringName(v)
		if sn == &"":
			continue
		out.append(sn)
	out.sort()
	return out
