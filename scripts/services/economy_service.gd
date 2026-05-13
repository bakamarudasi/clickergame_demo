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
	return buy_upgrade_bulk(upgrade_id, 1) > 0


# 指定IDの次に買う qty Lv 分の合計コスト（等比級数）。
# max_level で制限される場合は買える分だけで打ち切る。qty<=0 は 0 を返す。
static func cumulative_cost(upgrade_id: StringName, qty: int) -> int:
	if qty <= 0:
		return 0
	var u := DataRegistry.get_upgrade(upgrade_id)
	if u == null:
		return 0
	var lv := GameState.get_upgrade_level(upgrade_id)
	var remaining := qty
	if u.max_level > 0:
		remaining = min(remaining, u.max_level - lv)
	if remaining <= 0:
		return 0
	var total := 0.0
	var c := float(u.base_cost) * pow(u.cost_growth, lv)
	for i in remaining:
		total += c
		c *= u.cost_growth
	return int(total)


# 現在の所持金で買える最大 Lv 数。max_level も尊重する。
static func max_affordable_qty(upgrade_id: StringName) -> int:
	var u := DataRegistry.get_upgrade(upgrade_id)
	if u == null:
		return 0
	var lv := GameState.get_upgrade_level(upgrade_id)
	var room := -1
	if u.max_level > 0:
		room = u.max_level - lv
		if room <= 0:
			return 0
	var budget := float(GameState.currency)
	var c := float(u.base_cost) * pow(u.cost_growth, lv)
	if c <= 0.0:
		return 0
	var n := 0
	# 安全弁：成長率 1.0 のアップグレードがあると無限ループになるので上限を設ける。
	const HARD_CAP := 100000
	while budget >= c and n < HARD_CAP:
		budget -= c
		c *= u.cost_growth
		n += 1
		if room >= 0 and n >= room:
			break
	return n


# qty Lv 分まとめて購入。実際に買えた数を返す（足りなければ 0）。
static func buy_upgrade_bulk(upgrade_id: StringName, qty: int) -> int:
	if qty <= 0:
		return 0
	var u := DataRegistry.get_upgrade(upgrade_id)
	if u == null:
		return 0
	var lv := GameState.get_upgrade_level(upgrade_id)
	var room := qty
	if u.max_level > 0:
		room = min(room, u.max_level - lv)
	if room <= 0:
		return 0
	var total_cost := cumulative_cost(upgrade_id, room)
	if total_cost <= 0:
		return 0
	if not GameState.try_spend(total_cost):
		return 0
	GameState.set_upgrade_level(upgrade_id, lv + room)
	_apply_upgrade_effect_bulk(u, room)
	return room


static func _apply_upgrade_effect_bulk(u: UpgradeData, qty: int) -> void:
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			GameState.set_click_power(GameState.click_power + int(u.effect_amount) * qty)
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			GameState.set_per_second(GameState.per_second + int(u.effect_amount) * qty)
		Enums.UpgradeEffectKind.MULT_CLICK:
			# 倍率は重ねがけ：effect_amount^qty
			GameState.set_click_power(int(float(GameState.click_power) * pow(u.effect_amount, qty)))
