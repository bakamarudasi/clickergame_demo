class_name ShopService
extends Object

# Shopタブ UI が呼ぶ唯一の入り口。
# 購入 → 通貨減算 → インベントリ加算 or 永続効果適用。

static func can_buy(item_id: StringName) -> bool:
	var it := DataRegistry.get_item(item_id)
	if it == null:
		return false
	return GameState.currency >= it.price


static func buy(item_id: StringName) -> bool:
	var it := DataRegistry.get_item(item_id)
	if it == null:
		return false
	if not GameState.try_spend(it.price):
		return false
	if it.is_consumable:
		GameState.add_item(item_id, 1)
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
