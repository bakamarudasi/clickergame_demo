extends Node

# 進行状態の唯一の真実。Service が変更し、変更時 EventBus にシグナルを流す。

const HARASSMENT_LOCK_THRESHOLD := 10
const HARASSMENT_LOCK_DURATION := 300.0  # 5分（実時間）
const HARASSMENT_DECAY_PER_GIFT := 1

var currency: int = 0
var click_power: int = 1
var per_second: int = 0

# 一時バフ（アイドル発火・将来のイベント等から付与される）。
# unix 時刻 < click_buff_until_unix の間 click_power に乗算が乗る。
# 切れたら effective_click_power() が自動で素の click_power に戻す。
var click_buff_multiplier: float = 1.0
var click_buff_until_unix: float = 0.0

var owned_upgrades: Dictionary = {}          # upgrade_id -> level
var unlocked_operators: Array[StringName] = []
var operator_runtime: Dictionary = {}        # operator_id -> OperatorRuntime
var inventory: Dictionary = {}               # item_id -> count
var seen_cgs: Array[StringName] = []
var unlocked_memories: Array[StringName] = []

# 永続的に有効なルール（ショップ購入で増える）
var active_rules: Array[StringName] = []
# 時限ルール用：rule_id -> 期限 (unix sec)。記載されてないルールは永続。
# 時限切れは has_rule() 内で lazy に evict する（_process 不要）。
var active_rule_expires: Dictionary = {}

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

# プレステージ通貨の獲得計算用。
# total_earned_this_run は周回ごとにリセット、total_earned_ever は永続。
# 「累計¥100K到達でプレステージ系統解放」の判定に total_earned_ever を使う。
# 獲得式: floor( cube_root( (total_earned_this_run + currency) / 100_000 ) )
# Cookie Clicker 方式（cube_root + 累計＋手元）、ただし規模をこのゲームに合わせて圧縮。
const PRESTIGE_UNLOCK_THRESHOLD := 100_000
const PRESTIGE_CURRENCY_DIVISOR := 100_000
var total_earned_this_run: int = 0
var total_earned_ever: int = 0


func _ready() -> void:
	# project.godot の autoload 順序により、ここに来る時点で DataRegistry はロード済み。
	for op in DataRegistry.get_all_operators():
		if op.unlock_cost == 0:
			_unlock_operator_internal(op.id)
	# セーブ存在時はここで上書きロード。シーンの _ready が走り始める前に
	# state を確定させたいため autoload._ready の末尾で実行。
	# 失敗（ファイル無し / 破損）時はデフォルト state のまま継続。
	SaveService.load_from_disk()


# --- 通貨 -----------------------------------------------------------------

func add_currency(amount: int) -> void:
	currency += amount
	if amount > 0:
		total_earned_this_run += amount
		total_earned_ever += amount
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


# 一時 click 倍率バフ。多重発動時は新しい方で上書き（より強い／長いバフが
# 来た時の挙動を考えるなら max を取るが、現状は素直に上書き）。
func apply_click_buff(multiplier: float, duration_sec: float) -> void:
	click_buff_multiplier = max(1.0, multiplier)
	click_buff_until_unix = Time.get_unix_time_from_system() + max(0.0, duration_sec)
	EventBus.click_power_changed.emit(click_power)


# バフ + メタ強化込みの実効 click_power。EconomyService.click() などはこれを使う。
# メタ強化 click_perm_mult: ×1.05 / Lv（PROGRESSION.md §2.6）
func effective_click_power() -> int:
	var base := click_power
	if Time.get_unix_time_from_system() < click_buff_until_unix:
		base = int(base * click_buff_multiplier)
	var meta_lv := get_meta_level(&"click_perm_mult")
	if meta_lv > 0:
		base = int(base * pow(1.05, meta_lv))
	return base


# メタ強化込みの実効 per_second。
func effective_per_second() -> int:
	var base := per_second
	var meta_lv := get_meta_level(&"per_sec_perm_mult")
	if meta_lv > 0:
		base = int(base * pow(1.05, meta_lv))
	return base


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
		# STAGE_UP 反応は ReactionDispatcher が stage_advanced を購読して
		# call_deferred で発火する（再入回避のため）。ここは emit するだけ。
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


# --- 親密度・発情度 -------------------------------------------------------

func add_intimacy(op_id: StringName, delta: int) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	rt.intimacy = max(0, rt.intimacy + delta)
	EventBus.intimacy_changed.emit(op_id, rt.intimacy)


# 発情度の取得は必ずこの関数経由で。前回 set/get からの経過時間ぶんを
# その場で減衰させてから返す（lazy decay）。
func get_arousal(op_id: StringName) -> float:
	var rt := get_runtime(op_id)
	if rt == null:
		return 0.0
	_decay_arousal_to_now(rt)
	return rt.arousal


# 発情度を加算する。親密度に応じた加算ブーストがかかる（B案連動）。
# 親密度 100 ごとに +AROUSAL_INTIMACY_BOOST_PER_100 倍（既定で +100% / ×2.0）。
func add_arousal(op_id: StringName, delta: float) -> void:
	var rt := get_runtime(op_id)
	if rt == null:
		return
	_decay_arousal_to_now(rt)
	var boost := 1.0 + (float(rt.intimacy) / 100.0) * UIConstants.AROUSAL_INTIMACY_BOOST_PER_100
	rt.arousal = clampf(rt.arousal + delta * boost, 0.0, UIConstants.AROUSAL_MAX)
	if rt.arousal > rt.arousal_peak:
		rt.arousal_peak = rt.arousal
	EventBus.arousal_changed.emit(op_id, rt.arousal)
	# AROUSAL_MAX 到達時に 1 度だけ反応を出す。80% 以下に落ちたらフラグリセット。
	# 発火本体は ReactionDispatcher（call_deferred で再入回避）。
	if rt.arousal >= UIConstants.AROUSAL_MAX and not rt.arousal_max_announced:
		rt.arousal_max_announced = true
		ReactionDispatcher.dispatch_arousal_max(op_id)
	elif rt.arousal < UIConstants.AROUSAL_MAX * 0.8:
		rt.arousal_max_announced = false


func _decay_arousal_to_now(rt: OperatorRuntime) -> void:
	var now := Time.get_unix_time_from_system()
	if rt.arousal_last_unix > 0.0 and rt.arousal > 0.0:
		var elapsed: float = max(0.0, now - rt.arousal_last_unix)
		rt.arousal = max(0.0, rt.arousal - elapsed * UIConstants.AROUSAL_DECAY_PER_SEC)
	rt.arousal_last_unix = now


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
	if not (rule_id in active_rules):
		return false
	# 時限ルール: 期限超過なら lazy に削除して false 返却。
	# 反応 resolver も UI も毎回 has_rule() を通る前提で eviction を集約。
	if active_rule_expires.has(rule_id):
		if Time.get_unix_time_from_system() >= float(active_rule_expires[rule_id]):
			remove_rule(rule_id)
			return false
	return true

# duration_sec > 0 で時限ルール、それ以外（既定）は永続。
# 既存ルール上書きは「期限延長」と扱う：同じ rule_id を更新時間で再活性化したい
# ケース（例: rope 連続贈呈で combo 時計をリセット）に対応。
func add_rule(rule_id: StringName, duration_sec: float = -1.0) -> void:
	if rule_id == &"":
		return
	var newly_activated := not (rule_id in active_rules)
	if newly_activated:
		active_rules.append(rule_id)
	if duration_sec > 0.0:
		active_rule_expires[rule_id] = Time.get_unix_time_from_system() + duration_sec
	elif newly_activated:
		# 永続活性化時は既存の期限を念のため消す
		active_rule_expires.erase(rule_id)
	if newly_activated:
		EventBus.rule_activated.emit(rule_id)

func remove_rule(rule_id: StringName) -> void:
	if not (rule_id in active_rules):
		return
	active_rules.erase(rule_id)
	active_rule_expires.erase(rule_id)
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
	# 全アンロック済みオペに「次回再会で挨拶台詞」フラグを立てる。
	# Room でそのオペを選んだ瞬間に PRESTIGE 反応が 1 度だけ流れる。
	for op_id in unlocked_operators:
		var rt := get_runtime(op_id)
		if rt != null:
			rt.pending_prestige_greet = true


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


# プレステージ系統の解放判定。累計¥1Mを一度でも超えていれば永続的に解放。
# UI（メタタブ表示・リセットボタン）は全てこれを参照する。
func is_prestige_unlocked() -> bool:
	return total_earned_ever >= PRESTIGE_UNLOCK_THRESHOLD


# 今リセットしたら何源石片もらえるかのプレビュー。
# 計算式: floor( cube_root( (total_earned_this_run + currency) / 100_000 ) )
# - 立方根：序盤厚め・後半は穏やかに伸びる Cookie Clicker と同形のカーブ
# - 累計獲得 + 現在手持ち：手元¥に二重カウント効果を持たせて、抱え込みにも報酬
# - 100K で divisor を割るので「閾値ピッタリ到達 = 1個」のクリーンな下限
func compute_prestige_currency_gained() -> int:
	var pool := total_earned_this_run + currency
	if pool < PRESTIGE_CURRENCY_DIVISOR:
		return 0
	return int(floor(pow(float(pool) / float(PRESTIGE_CURRENCY_DIVISOR), 1.0 / 3.0)))


# プレステージ実行：周回通貨を確定して獲得、走行中の進行をリセット。
# 保持: prestige_count / prestige_currency / meta_upgrade_levels / オペ trust / CG / Memory
# 初期化: currency / owned_upgrades / click_power / per_second / total_earned_this_run / 一時バフ
func do_prestige_reset() -> void:
	var gained := compute_prestige_currency_gained()
	add_prestige_currency(gained)
	add_prestige_count(1)

	# 走行中の進行をリセット
	currency = 0
	owned_upgrades.clear()
	click_power = 1
	per_second = 0
	total_earned_this_run = 0
	click_buff_multiplier = 1.0
	click_buff_until_unix = 0.0

	# starter_funds メタ強化分の初期資金を付与（Lv * 1000）
	var sf_lv := get_meta_level(&"starter_funds")
	if sf_lv > 0:
		currency = sf_lv * 1000
		total_earned_this_run += currency

	# UI同期
	EventBus.currency_changed.emit(currency)
	EventBus.click_power_changed.emit(click_power)
	EventBus.per_second_changed.emit(per_second)


# --- セーブ／ロード（SaveService からのみ呼ばれる） -----------------------

# JSON 化可能な Dictionary を返す。StringName は全部 String に潰す。
# 復元側は apply_snapshot()。
func serialize() -> Dictionary:
	return {
		"currency": currency,
		"click_power": click_power,
		"per_second": per_second,
		"click_buff_multiplier": click_buff_multiplier,
		"click_buff_until_unix": click_buff_until_unix,
		"owned_upgrades": _stringname_keyed_to_string(owned_upgrades),
		"unlocked_operators": _stringname_array_to_string(unlocked_operators),
		"inventory": _stringname_keyed_to_string(inventory),
		"seen_cgs": _stringname_array_to_string(seen_cgs),
		"unlocked_memories": _stringname_array_to_string(unlocked_memories),
		"active_rules": _stringname_array_to_string(active_rules),
		"active_rule_expires": _stringname_keyed_to_string(active_rule_expires),
		"owned_scopes": _stringname_array_to_string(owned_scopes),
		"equipped_scope_id": String(equipped_scope_id),
		"scope_battery_seconds": scope_battery_seconds,
		"xray_active": xray_active,
		"prestige_count": prestige_count,
		"prestige_currency": prestige_currency,
		"bond": _stringname_keyed_to_string(bond),
		"meta_upgrade_levels": _stringname_keyed_to_string(meta_upgrade_levels),
		"total_earned_this_run": total_earned_this_run,
		"total_earned_ever": total_earned_ever,
		"operator_runtime": _serialize_runtimes(),
	}


# セーブからの復元。各タブはこの後の EventBus フル再発火で同期される。
# xray_active は battery が空なら強制 OFF（不整合ガード）。
func apply_snapshot(d: Dictionary) -> void:
	currency = int(d.get("currency", 0))
	click_power = int(d.get("click_power", 1))
	per_second = int(d.get("per_second", 0))
	click_buff_multiplier = float(d.get("click_buff_multiplier", 1.0))
	click_buff_until_unix = float(d.get("click_buff_until_unix", 0.0))

	owned_upgrades = _to_stringname_keyed_int_dict(d.get("owned_upgrades", {}))
	unlocked_operators = _to_stringname_array(d.get("unlocked_operators", []))
	inventory = _to_stringname_keyed_int_dict(d.get("inventory", {}))
	seen_cgs = _to_stringname_array(d.get("seen_cgs", []))
	unlocked_memories = _to_stringname_array(d.get("unlocked_memories", []))
	active_rules = _to_stringname_array(d.get("active_rules", []))
	# 時限ルールの期限を復元。値は float の unix sec。
	active_rule_expires.clear()
	var exp_in: Variant = d.get("active_rule_expires", {})
	if typeof(exp_in) == TYPE_DICTIONARY:
		for k in (exp_in as Dictionary).keys():
			active_rule_expires[StringName(k)] = float((exp_in as Dictionary)[k])

	owned_scopes = _to_stringname_array(d.get("owned_scopes", []))
	equipped_scope_id = StringName(d.get("equipped_scope_id", ""))
	scope_battery_seconds = float(d.get("scope_battery_seconds", 0.0))
	xray_active = bool(d.get("xray_active", false))
	if xray_active and scope_battery_seconds <= 0.0:
		xray_active = false

	prestige_count = int(d.get("prestige_count", 0))
	prestige_currency = int(d.get("prestige_currency", 0))
	bond = _to_stringname_keyed_int_dict(d.get("bond", {}))
	meta_upgrade_levels = _to_stringname_keyed_int_dict(d.get("meta_upgrade_levels", {}))
	total_earned_this_run = int(d.get("total_earned_this_run", 0))
	total_earned_ever = int(d.get("total_earned_ever", 0))

	operator_runtime.clear()
	var rt_dict: Dictionary = d.get("operator_runtime", {})
	for k in rt_dict.keys():
		var rt := OperatorRuntime.new()
		rt.apply_dict(rt_dict[k])
		operator_runtime[StringName(k)] = rt

	# 旧セーブ + 新規追加された 0-cost オペの取りこぼしを救う。
	# 既存ロード結果には触らず、ロードに無いオペだけ補填する。
	for op in DataRegistry.get_all_operators():
		if op.unlock_cost == 0 and not is_operator_unlocked(op.id):
			_unlock_operator_internal(op.id)

	_emit_full_refresh()


# ロード直後、既に _ready 済みのタブを同期するため主要シグナルを撃ち直す。
# UI 側は EventBus 経由で表示更新するので、ここで呼べば全タブの再描画が走る。
func _emit_full_refresh() -> void:
	EventBus.currency_changed.emit(currency)
	EventBus.click_power_changed.emit(click_power)
	EventBus.per_second_changed.emit(per_second)
	EventBus.prestige_count_changed.emit(prestige_count)
	EventBus.prestige_currency_changed.emit(prestige_currency)
	EventBus.scope_battery_changed.emit(scope_battery_seconds)
	EventBus.xray_changed.emit(xray_active)
	if equipped_scope_id != &"":
		EventBus.scope_equipped.emit(equipped_scope_id)
	for op_id in unlocked_operators:
		EventBus.operator_unlocked.emit(op_id)
		var rt: OperatorRuntime = operator_runtime.get(op_id)
		if rt != null:
			EventBus.trust_changed.emit(op_id, rt.trust, rt.current_stage)
			EventBus.intimacy_changed.emit(op_id, rt.intimacy)
			EventBus.arousal_changed.emit(op_id, rt.arousal)
			EventBus.xray_suspicion_changed.emit(op_id, rt.xray_suspicion)
			if rt.equipped_costume != &"":
				EventBus.costume_equipped.emit(op_id, rt.equipped_costume)
	for upg_id in owned_upgrades.keys():
		EventBus.upgrade_purchased.emit(upg_id, int(owned_upgrades[upg_id]))
	for item_id in inventory.keys():
		EventBus.inventory_changed.emit(item_id, int(inventory[item_id]))
	for meta_id in meta_upgrade_levels.keys():
		EventBus.meta_upgrade_purchased.emit(meta_id, int(meta_upgrade_levels[meta_id]))
	for rule_id in active_rules:
		EventBus.rule_activated.emit(rule_id)


func _serialize_runtimes() -> Dictionary:
	var out := {}
	for k in operator_runtime.keys():
		var rt: OperatorRuntime = operator_runtime[k]
		out[String(k)] = rt.to_dict()
	return out


func _stringname_keyed_to_string(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src.keys():
		out[String(k)] = src[k]
	return out


func _stringname_array_to_string(src: Array) -> Array:
	var out: Array = []
	for v in src:
		out.append(String(v))
	return out


func _to_stringname_array(src: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(src) != TYPE_ARRAY:
		return out
	for v in src:
		out.append(StringName(v))
	return out


func _to_stringname_keyed_int_dict(src: Variant) -> Dictionary:
	var out := {}
	if typeof(src) != TYPE_DICTIONARY:
		return out
	for k in (src as Dictionary).keys():
		out[StringName(k)] = int((src as Dictionary)[k])
	return out
