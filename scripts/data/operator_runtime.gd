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
