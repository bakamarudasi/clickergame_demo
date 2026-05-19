class_name CombineService
extends Object

# Roomタブ UI が「複数アイテム同時使用（コンボ）」で渡す時の入り口。
# 単発ギフトは GiftService.give() を引き続き使う想定（こちらは 2 個以上専用）。
# 入力アイテムは UI 側で「異種・最大3個」を保証してくる前提だが、念のため
# ここでも sorted/unique 化と inventory チェックを通してから消費する。

const MAX_COMBO_SIZE := 3


static func combine(op_id: StringName, item_ids: Array) -> ReactionRule:
	if op_id == &"" or item_ids.is_empty():
		return null
	# ハラスロック中は GiftService と同じく差し戻し。
	if ReactionDispatcher.try_locked_revisit(op_id):
		return null

	# 異種 / 最大数チェック。同一 id は dedup されるので、その時点で 2 個未満なら
	# 単発として GiftService に丸投げする（外側 UI が単発スロットを使うべきだが
	# 念のためのフェイルセーフ）。
	var unique := _sort_unique_stringnames(item_ids)
	if unique.size() == 0:
		return null
	if unique.size() > MAX_COMBO_SIZE:
		return null
	if unique.size() == 1:
		return GiftService.give(op_id, unique[0])

	# 全アイテムを持ってるか先に確認。1個でも不足してたら何も消費せず終了。
	for id in unique:
		if GameState.item_count(id) <= 0:
			var n := TranslationServer.translate("TOAST_COMBO_ITEM_MISSING")
			EventBus.toast_requested.emit(n)
			return null

	# 反応解決（消費の前にやって、見つからなければ何も消費しない方針）。
	var rule := ReactionResolver.resolve_combo(op_id, unique)

	# アイテムは見つかっても見つからなくても消費する（コンボ「試行」をした扱い）。
	# 見つからない時は通常コンボ反応へのフォールバックを別途用意してもよいが、
	# 現段階では「未知のコンボは null を返してトーストだけ出す」運用にする。
	for id in unique:
		GameState.consume_item(id, 1)
		GameState.record_gift(op_id, id)
		GameState.decay_harassment_on_gift(op_id)

	if rule != null:
		ReactionResolver.apply_side_effects(rule, op_id)
		EventBus.reaction_played.emit(op_id, rule)
	else:
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_COMBO_NO_REACTION"))
	return rule


# 入力 Array を String/StringName 混在から StringName 化、空文字を除外、ソート＆重複排除。
static func _sort_unique_stringnames(src: Array) -> Array:
	var out: Array = []
	for v in src:
		var sn := StringName(v)
		if sn == &"":
			continue
		if not (sn in out):
			out.append(sn)
	out.sort()
	return out
