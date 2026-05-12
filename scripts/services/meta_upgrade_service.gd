class_name MetaUpgradeService
extends Object

# プレステージ通貨（源石片）でメタ強化を購入する。
# 効果適用は GameState 側のヘルパ（effective_click_power 等）と
# do_prestige_reset() の starter_funds 反映で行うため、
# このサービス自身は「購入処理」と「コスト計算」だけを持つ。
# 詳細設計は PROGRESSION.md §2.5 / §2.6。

static func current_cost(meta_id: StringName) -> int:
	var m := DataRegistry.get_meta_upgrade(meta_id)
	if m == null:
		return -1
	var lv := GameState.get_meta_level(meta_id)
	# Type A (max_level=1) は cost_growth=1.0 で base そのまま、
	# Type B は base * growth^lv の指数式（既存 EconomyService と同じ計算式）。
	return int(m.base_cost * pow(m.cost_growth, lv))


static func can_buy(meta_id: StringName) -> bool:
	var m := DataRegistry.get_meta_upgrade(meta_id)
	if m == null:
		return false
	var lv := GameState.get_meta_level(meta_id)
	if m.max_level > 0 and lv >= m.max_level:
		return false
	return GameState.prestige_currency >= current_cost(meta_id)


static func buy(meta_id: StringName) -> bool:
	if not can_buy(meta_id):
		return false
	var cost := current_cost(meta_id)
	if not GameState.try_spend_prestige(cost):
		return false
	var new_lv := GameState.get_meta_level(meta_id) + 1
	GameState.set_meta_level(meta_id, new_lv)
	# perm_mult 系の購入直後に click_power / per_second 表示を更新するため、
	# 関連シグナルを即時に流す（実値は effective_* 経由で読まれる）。
	EventBus.click_power_changed.emit(GameState.click_power)
	EventBus.per_second_changed.emit(GameState.per_second)
	return true


static func is_max_level(meta_id: StringName) -> bool:
	var m := DataRegistry.get_meta_upgrade(meta_id)
	if m == null or m.max_level <= 0:
		return false
	return GameState.get_meta_level(meta_id) >= m.max_level
