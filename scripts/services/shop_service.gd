class_name ShopService
extends Object

# Shopタブ UI が呼ぶ唯一の入り口。
# 購入 → 通貨減算 → インベントリ加算 or 永続効果適用。

static func can_buy(item_id: StringName, qty: int = 1) -> bool:
	var it := DataRegistry.get_item(item_id)
	if it == null or qty <= 0:
		return false
	return GameState.currency >= it.price * qty


# 所持金で買える最大数を返す。非消耗品は常に 1（複数所持は意味がない）。
static func max_affordable(item_id: StringName) -> int:
	var it := DataRegistry.get_item(item_id)
	if it == null or it.price <= 0:
		return 0
	if not it.is_consumable:
		return 1 if GameState.currency >= it.price else 0
	return GameState.currency / it.price


static func buy(item_id: StringName, qty: int = 1) -> bool:
	var it := DataRegistry.get_item(item_id)
	if it == null or qty <= 0:
		return false
	# 非消耗品は常に 1 個扱い（永続効果なので qty は無視）
	var actual_qty := qty if it.is_consumable else 1
	var total_cost := it.price * actual_qty
	if not GameState.try_spend(total_cost):
		return false
	if it.is_consumable:
		GameState.add_item(item_id, actual_qty)
	else:
		_apply_permanent_effects(it)
	EventBus.item_purchased.emit(item_id)
	return true


static func _apply_permanent_effects(it: ItemData) -> void:
	# 永続/即時効果はここで一括処理。インベントリには入らない
	for eff: ItemEffect in it.effects:
		match eff.kind:
			Enums.EffectKind.OPERATOR_UNLOCK:
				GameState.unlock_operator(eff.target_id)
			Enums.EffectKind.COSTUME_UNLOCK:
				# 衣装は CostumeData.operator_id から所有者を引く
				var c := DataRegistry.get_costume(eff.target_id)
				if c != null:
					GameState.unlock_costume(c.operator_id, c.id)
			Enums.EffectKind.RULE_ACTIVATE:
				GameState.add_rule(eff.target_id)
			Enums.EffectKind.SCOPE_GRANT:
				GameState.grant_scope(eff.target_id)
			Enums.EffectKind.SCOPE_BATTERY_REFILL:
				GameState.add_scope_battery(float(eff.amount))
			_:
				pass
