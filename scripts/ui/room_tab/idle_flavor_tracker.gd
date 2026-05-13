class_name IdleFlavorTracker
extends RefCounted

# Room タブ操作なしで一定時間経つと、IDLE 反応を段階的に発火する。
# 各段階の trigger_id は &"stage_1" / &"stage_2" / &"stage_3" / &"fire"。
# fire 段階では click_power に一時バフを乗せる（狙撃カウントダウンの「演出」役）。
#
# RoomTab 側で tick(current_op) を _process から、reset() をユーザー操作の度に呼ぶ。

signal fire_buff_applied  # 発火段階に達した瞬間。トーストを出すなど演出側で拾う。

var _last_interaction_unix: float = 0.0
var _stage_fired: int = 0


func reset() -> void:
	_last_interaction_unix = Time.get_unix_time_from_system()
	_stage_fired = 0


func tick(current_op: StringName) -> void:
	if current_op == &"":
		return
	if GameState.is_operator_locked(current_op):
		return
	var elapsed := Time.get_unix_time_from_system() - _last_interaction_unix
	if elapsed >= UIConstants.IDLE_FIRE_SEC and _stage_fired < 4:
		_stage_fired = 4
		ReactionDispatcher.dispatch_idle(current_op, &"fire")
		GameState.apply_click_buff(UIConstants.IDLE_BUFF_MULT, UIConstants.IDLE_BUFF_DURATION_SEC)
		fire_buff_applied.emit()
		reset()
	elif elapsed >= UIConstants.IDLE_STAGE_3_SEC and _stage_fired < 3:
		_stage_fired = 3
		ReactionDispatcher.dispatch_idle(current_op, &"stage_3")
	elif elapsed >= UIConstants.IDLE_STAGE_2_SEC and _stage_fired < 2:
		_stage_fired = 2
		ReactionDispatcher.dispatch_idle(current_op, &"stage_2")
	elif elapsed >= UIConstants.IDLE_STAGE_1_SEC and _stage_fired < 1:
		_stage_fired = 1
		ReactionDispatcher.dispatch_idle(current_op, &"stage_1")
