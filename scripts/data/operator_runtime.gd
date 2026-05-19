class_name OperatorRuntime
extends Resource

@export var operator_id: StringName = &""
@export var trust: int = 0
@export var current_stage: int = 0
@export var equipped_costume: StringName = &""
@export var unlocked_costumes: Array[StringName] = []
@export var gift_history: Dictionary = {}
@export var harassment_counter: int = 0
@export var locked_until: float = 0.0
@export var seen_messages: Array[StringName] = []
@export var last_inspection_unix: float = 0.0
@export var xray_suspicion: float = 0.0
# trust >= 80 状態で xray バレを食らった累計回数。ReactionResolver に
# consecutive として渡すことで「N 回目のバレで特別反応」を引ける。
@export var xray_caught_high_count: int = 0

# 親密度（永続・上昇のみ）。trust とは別軸の長期指標で、
# arousal の増加補正に使う（B案連動）。
@export var intimacy: int = 0

# 発情度。0..UIConstants.AROUSAL_MAX の float。
# 時間で UIConstants.AROUSAL_DECAY_PER_SEC ずつ減衰。
# arousal_last_unix は lazy decay 計算の基準時刻。
@export var arousal: float = 0.0
@export var arousal_last_unix: float = 0.0
@export var arousal_peak: float = 0.0
# 発情度が AROUSAL_MAX に到達した時 1 度だけ MAX 用反応を出す。
# arousal が一定値（80%）以下に落ちたらリセットされる。
@export var arousal_max_announced: bool = false

# プレステージ完了時に立つフラグ。次回 Room でこのオペを選択した瞬間に
# PRESTIGE 反応を 1 度だけ出して降ろす（再会演出）。
@export var pending_prestige_greet: bool = false

func is_locked() -> bool:
	return Time.get_unix_time_from_system() < locked_until

func gift_count(item_id: StringName) -> int:
	return gift_history.get(item_id, 0)

func inspection_cooldown_remaining(cooldown_sec: float) -> float:
	var elapsed := Time.get_unix_time_from_system() - last_inspection_unix
	return max(0.0, cooldown_sec - elapsed)


# --- Serialization (SaveService 用) --------------------------------------
# StringName を String に落として JSON 化できる Dictionary を返す。
# Dictionary.gift_history のキー（item_id）も String 化。
func to_dict() -> Dictionary:
	var gift_out := {}
	for k in gift_history.keys():
		gift_out[String(k)] = int(gift_history[k])
	var costumes_out: Array = []
	for c in unlocked_costumes:
		costumes_out.append(String(c))
	var messages_out: Array = []
	for m in seen_messages:
		messages_out.append(String(m))
	return {
		"operator_id": String(operator_id),
		"trust": trust,
		"current_stage": current_stage,
		"equipped_costume": String(equipped_costume),
		"unlocked_costumes": costumes_out,
		"gift_history": gift_out,
		"harassment_counter": harassment_counter,
		"locked_until": locked_until,
		"seen_messages": messages_out,
		"last_inspection_unix": last_inspection_unix,
		"xray_suspicion": xray_suspicion,
		"xray_caught_high_count": xray_caught_high_count,
		"intimacy": intimacy,
		"arousal": arousal,
		"arousal_last_unix": arousal_last_unix,
		"arousal_peak": arousal_peak,
		"arousal_max_announced": arousal_max_announced,
		"pending_prestige_greet": pending_prestige_greet,
	}


func apply_dict(d: Dictionary) -> void:
	operator_id = StringName(d.get("operator_id", ""))
	trust = int(d.get("trust", 0))
	current_stage = int(d.get("current_stage", 0))
	equipped_costume = StringName(d.get("equipped_costume", ""))
	unlocked_costumes.clear()
	for c in d.get("unlocked_costumes", []):
		unlocked_costumes.append(StringName(c))
	gift_history.clear()
	var gift_in: Dictionary = d.get("gift_history", {})
	for k in gift_in.keys():
		gift_history[StringName(k)] = int(gift_in[k])
	harassment_counter = int(d.get("harassment_counter", 0))
	locked_until = float(d.get("locked_until", 0.0))
	seen_messages.clear()
	for m in d.get("seen_messages", []):
		seen_messages.append(StringName(m))
	last_inspection_unix = float(d.get("last_inspection_unix", 0.0))
	xray_suspicion = float(d.get("xray_suspicion", 0.0))
	xray_caught_high_count = int(d.get("xray_caught_high_count", 0))
	intimacy = int(d.get("intimacy", 0))
	arousal = float(d.get("arousal", 0.0))
	arousal_last_unix = float(d.get("arousal_last_unix", 0.0))
	arousal_peak = float(d.get("arousal_peak", 0.0))
	arousal_max_announced = bool(d.get("arousal_max_announced", false))
	pending_prestige_greet = bool(d.get("pending_prestige_greet", false))
