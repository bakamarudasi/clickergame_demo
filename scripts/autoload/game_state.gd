extends Node

# 進行状態の唯一の真実。Service が変更し、変更時 EventBus にシグナルを流す。

const HARASSMENT_LOCK_THRESHOLD := 10
const HARASSMENT_LOCK_DURATION := 300.0  # 5分（実時間）
const HARASSMENT_DECAY_PER_GIFT := 1

var currency: int = 0
var click_power: int = 1
var per_second: int = 0

var owned_upgrades: Dictionary = {}          # upgrade_id -> level
var unlocked_operators: Array[StringName] = []
var operator_runtime: Dictionary = {}        # operator_id -> OperatorRuntime
var inventory: Dictionary = {}               # item_id -> count
var seen_cgs: Array[StringName] = []
var unlocked_memories: Array[StringName] = []

# 永続的に有効なルール（ショップ購入で増える）
var active_rules: Array[StringName] = []

# 紳士眼鏡（Scope）の状態
var owned_scopes: Array[StringName] = []
var equipped_scope_id: StringName = &""
var scope_battery_seconds: float = 0.0
var xray_active: bool = false

# プレステージ・メタ進行
# prestige_count は ReactionRule.min_tier の比較対象（Tier軸）。
# bond は キャラごとの絆。ReactionRule.min_bond の比較対象。
# meta_upgrade_levels は data/meta_upgrades/*.tres の id -> 取得Lv。
# 詳細設計は PROGRESSION.md を参照。
var prestige_count: int = 0
var prestige_currency: int = 0
var bond: Dictionary = {}                    # StringName -> int
var meta_upgrade_levels: Dictionary = {}     # StringName -> int


func _ready() -> void:
	# project.godot の autoload 順序により、ここに来る時点で DataRegistry はロード済み。
	for op in DataRegistry.get_all_operators():
		if op.unlock_cost == 0:
			_unlock_operator_internal(op.id)


# --- 通貨 -----------------------------------------------------------------

func add_currency(amount: int) -> void:
	currency += amount
	EventBus.currency_changed.emit(currency)

func try_spend(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	EventBus.currency_changed.emit(currency)
	return true


# --- 強化 -----------------------------------------------------------------

func set_click_power(v: int) -> void:
	click_power = v
	EventBus.click_power_changed.emit(click_power)

func set_per_second(v: int) -> void:
	per_second = v
	EventBus.per_second_changed.emit(per_second)

func get_upgrade_level(id: StringName) -> int:
	return owned_upgrades.get(id, 0)

func set_upgrade_level(id: StringName, level: int) -> void:
	owned_upgrades[id] = level
	EventBus.upgrade_purchased.emit(id, level)


# --- インベントリ ---------------------------------------------------------

func add_item(item_id: StringName, n: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + n
	EventBus.inventory_changed.emit(item_id, inventory[item_id])

func consume_item(item_id: StringName, n: int = 1) -> bool:
	var cur: int = inventory.get(item_id, 0)
	if cur < n:
		return false
	inventory[item_id] = cur - n
	EventBus.inventory_changed.emit(item_id, inventory[item_id])
	return true

func item_count(item_id: StringName) -> int:
	return inventory.get(item_id, 0)


# --- オペレータ -----------------------------------------------------------

func _unlock_operator_internal(op_id: StringName) -> void:
	if op_id in unlocked_operators:
		return
	unlocked_operators.append(op_id)
	if not operator_runtime.has(op_id):
		var rt := OperatorRuntime.new()
		rt.operator_id = op_id
		var op := DataRegistry.get_operator(op_id)
		if op != null:
			rt.equipped_costume = op.default_costume_id
		operator_runtime[op_id] = rt
	EventBus.operator_unlocked.emit(op_id)

func unlock_operator(op_id: StringName) -> void:
	_unlock_operator_internal(op_id)

func get_runtime(op_id: StringName) -> OperatorRuntime:
	return operator_runtime.get(op_id)

func is_operator_unlocked(op_id: StringName) -> bool:
	return op_id in unlocked_operators

func is_operator_locked(op_id: StringName) -> bool:
	var rt := get_runtime(op_id)
	return rt != null and rt.is_locked()


# --- 信頼度 ---------------------------------------------------------------

func add_trust(op_id: StringName, delta: int) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.trust = max(0, rt.trust + delta)
	var new_stage := _compute_stage(op_id, rt.trust)
	var advanced := new_stage > rt.current_stage
	rt.current_stage = new_stage
	EventBus.trust_changed.emit(op_id, rt.trust, rt.current_stage)
	if advanced:
		EventBus.stage_advanced.emit(op_id, rt.current_stage)

func _compute_stage(op_id: StringName, trust: int) -> int:
	var op := DataRegistry.get_operator(op_id)
	if op == null:
		return 0
	var stage := 0
	for s in op.stages:
		if trust >= s.threshold:
			stage = s.stage_index
	return stage


# --- ハラスメント ---------------------------------------------------------

func add_harassment(op_id: StringName, weight: int) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.harassment_counter += weight
	if rt.harassment_counter >= HARASSMENT_LOCK_THRESHOLD:
		rt.locked_until = Time.get_unix_time_from_system() + HARASSMENT_LOCK_DURATION
		rt.harassment_counter = 0
		EventBus.operator_locked.emit(op_id, rt.locked_until)

func decay_harassment_on_gift(op_id: StringName) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.harassment_counter = max(0, rt.harassment_counter - HARASSMENT_DECAY_PER_GIFT)


# --- 衣装・CG・記憶 -------------------------------------------------------

func unlock_costume(op_id: StringName, costume_id: StringName) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	if costume_id in rt.unlocked_costumes:
		return
	rt.unlocked_costumes.append(costume_id)
	EventBus.costume_unlocked.emit(op_id, costume_id)

func equip_costume(op_id: StringName, costume_id: StringName) -> void:
	var rt := get_runtime(op_id)
	if rt == null or not (costume_id in rt.unlocked_costumes):
		return
	rt.equipped_costume = costume_id
	EventBus.costume_equipped.emit(op_id, costume_id)

func unlock_cg(cg_id: StringName) -> void:
	if cg_id in seen_cgs:
		return
	seen_cgs.append(cg_id)
	EventBus.cg_unlocked.emit(cg_id)

func unlock_memory(memory_id: StringName) -> void:
	if memory_id in unlocked_memories:
		return
	unlocked_memories.append(memory_id)
	EventBus.memory_unlocked.emit(memory_id)


# --- 履歴 -----------------------------------------------------------------

func record_gift(op_id: StringName, item_id: StringName) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.gift_history[item_id] = rt.gift_history.get(item_id, 0) + 1


# --- ルール ---------------------------------------------------------------

func has_rule(rule_id: StringName) -> bool:
	return rule_id in active_rules

func add_rule(rule_id: StringName) -> void:
	if rule_id == &"" or rule_id in active_rules:
		return
	active_rules.append(rule_id)
	EventBus.rule_activated.emit(rule_id)

func remove_rule(rule_id: StringName) -> void:
	if not (rule_id in active_rules):
		return
	active_rules.erase(rule_id)
	EventBus.rule_deactivated.emit(rule_id)


# --- 検査 -----------------------------------------------------------------

func mark_inspected(op_id: StringName) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.last_inspection_unix = Time.get_unix_time_from_system()
	EventBus.inspection_performed.emit(op_id)


# --- 紳士眼鏡 -------------------------------------------------------------

func grant_scope(scope_id: StringName) -> void:
	if scope_id == &"" or scope_id in owned_scopes:
		return
	owned_scopes.append(scope_id)
	if equipped_scope_id == &"":
		equip_scope(scope_id)
	EventBus.scope_equipped.emit(equipped_scope_id)

func equip_scope(scope_id: StringName) -> void:
	if not (scope_id in owned_scopes):
		return
	equipped_scope_id = scope_id
	EventBus.scope_equipped.emit(scope_id)

func add_scope_battery(seconds: float) -> void:
	scope_battery_seconds = max(0.0, scope_battery_seconds + seconds)
	EventBus.scope_battery_changed.emit(scope_battery_seconds)

func consume_scope_battery(seconds: float) -> void:
	scope_battery_seconds = max(0.0, scope_battery_seconds - seconds)
	EventBus.scope_battery_changed.emit(scope_battery_seconds)

func set_xray_active(active: bool) -> void:
	if xray_active == active:
		return
	xray_active = active
	EventBus.xray_changed.emit(active)

func add_xray_suspicion(op_id: StringName, delta: float) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.xray_suspicion = max(0.0, rt.xray_suspicion + delta)
	EventBus.xray_suspicion_changed.emit(op_id, rt.xray_suspicion)

func reset_xray_suspicion(op_id: StringName) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.xray_suspicion = 0.0
	EventBus.xray_suspicion_changed.emit(op_id, 0.0)


# --- プレステージ・メタ進行 ----------------------------------------------

func add_prestige_count(delta: int = 1) -> void:
	prestige_count = max(0, prestige_count + delta)
	EventBus.prestige_count_changed.emit(prestige_count)

func add_prestige_currency(amount: int) -> void:
	prestige_currency = max(0, prestige_currency + amount)
	EventBus.prestige_currency_changed.emit(prestige_currency)

func try_spend_prestige(amount: int) -> bool:
	if prestige_currency < amount:
		return false
	prestige_currency -= amount
	EventBus.prestige_currency_changed.emit(prestige_currency)
	return true

func get_bond(op_id: StringName) -> int:
	return bond.get(op_id, 0)

func add_bond(op_id: StringName, delta: int = 1) -> void:
	var new_value: int = max(0, get_bond(op_id) + delta)
	bond[op_id] = new_value
	EventBus.bond_changed.emit(op_id, new_value)

func get_meta_level(meta_id: StringName) -> int:
	return meta_upgrade_levels.get(meta_id, 0)

func set_meta_level(meta_id: StringName, level: int) -> void:
	meta_upgrade_levels[meta_id] = level
	EventBus.meta_upgrade_purchased.emit(meta_id, level)

func has_meta_unlock(meta_id: StringName) -> bool:
	# requires_meta フィールドの判定用ユーティリティ。
	# 空文字は「要件なし」、それ以外は当該 meta が Lv1 以上で解放扱い。
	if meta_id == &"":
		return true
	return get_meta_level(meta_id) >= 1
