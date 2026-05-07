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

func is_locked() -> bool:
	return Time.get_unix_time_from_system() < locked_until

func gift_count(item_id: StringName) -> int:
	return gift_history.get(item_id, 0)

func inspection_cooldown_remaining(cooldown_sec: float) -> float:
	var elapsed := Time.get_unix_time_from_system() - last_inspection_unix
	return max(0.0, cooldown_sec - elapsed)
