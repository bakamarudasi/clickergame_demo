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
