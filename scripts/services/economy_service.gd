class_name EconomyService
extends Object

# クリック・自動収益・アップグレード購入。
# Workタブ UI が呼ぶ唯一の入り口。

static func click() -> void:
	GameState.add_currency(GameState.effective_click_power())


static func tick(seconds: float = 1.0) -> void:
	var rate := GameState.effective_per_second()
	if rate <= 0:
		return
	GameState.add_currency(int(rate * seconds))


static func current_cost(upgrade_id: StringName) -> int:
	var u := DataRegistry.get_upgrade(upgrade_id)
	if u == null:
		return -1
	var lv := GameState.get_upgrade_level(upgrade_id)
	return int(u.base_cost * pow(u.cost_growth, lv))


static func can_buy_upgrade(upgrade_id: StringName) -> bool:
	var u := DataRegistry.get_upgrade(upgrade_id)
	if u == null:
		return false
	var lv := GameState.get_upgrade_level(upgrade_id)
	if u.max_level >= 0 and lv >= u.max_level:
		return false
	return GameState.currency >= current_cost(upgrade_id)


static func buy_upgrade(upgrade_id: StringName) -> bool:
	if not can_buy_upgrade(upgrade_id):
		return false
	var u := DataRegistry.get_upgrade(upgrade_id)
	var cost := current_cost(upgrade_id)
	if not GameState.try_spend(cost):
		return false
	var new_lv := GameState.get_upgrade_level(upgrade_id) + 1
	GameState.set_upgrade_level(upgrade_id, new_lv)
	_apply_upgrade_effect(u)
	return true


static func _apply_upgrade_effect(u: UpgradeData) -> void:
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			GameState.set_click_power(GameState.click_power + int(u.effect_amount))
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			GameState.set_per_second(GameState.per_second + int(u.effect_amount))
		Enums.UpgradeEffectKind.MULT_CLICK:
			GameState.set_click_power(int(GameState.click_power * u.effect_amount))
