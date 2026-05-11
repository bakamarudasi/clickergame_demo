extends Node

# 反応の「いつ流すか」を集約する場所。
# GameState は状態を変えてシグナルを emit するだけ、UI/Service は意図を投げるだけ、
# 反応の resolve / apply / emit はここから ReactionResolver.fire() に集約する。
#
# 状態変化由来の自然発火（STAGE_UP / AROUSAL_MAX）は call_deferred で
# 1 フレーム遅延して発火する。これで side_effect の trust_delta が次の
# ステージ境界を越えても再入再帰しない（直前の add_trust が return してから動く）。


func _ready() -> void:
	EventBus.stage_advanced.connect(_on_stage_advanced)


func _on_stage_advanced(op_id: StringName, new_stage: int) -> void:
	# 直接呼ぶと apply_side_effects → add_trust → stage_advanced ... の
	# 再入経路が開く。call_deferred で次フレームに送って閉じる。
	call_deferred("_fire_stage_up", op_id, new_stage)


func _fire_stage_up(op_id: StringName, new_stage: int) -> void:
	ReactionResolver.fire(Enums.TriggerKind.STAGE_UP, StringName(str(new_stage)), op_id)


# AROUSAL_MAX 到達は GameState 側の「初回到達フラグ」管理に依存するため、
# シグナルではなく明示的な dispatch_*() で呼んでもらう（call_deferred で再入回避）。
func dispatch_arousal_max(op_id: StringName) -> void:
	call_deferred("_fire_arousal_max", op_id)


func _fire_arousal_max(op_id: StringName) -> void:
	ReactionResolver.fire(Enums.TriggerKind.AROUSAL_MAX, &"", op_id)


# PRESTIGE / IDLE は UI 側のタイミング（Room タブを開いた瞬間 / 一定秒経過）で
# 流すもので、状態変化と関係ないので同期で OK。再入経路も無い。
func dispatch_prestige_greet(op_id: StringName) -> ReactionRule:
	return ReactionResolver.fire(Enums.TriggerKind.PRESTIGE, &"", op_id)


func dispatch_idle(op_id: StringName, stage_id: StringName) -> ReactionRule:
	return ReactionResolver.fire(Enums.TriggerKind.IDLE, stage_id, op_id)


# ロック中オペにアクション試行された時のガード。
# ロック中なら LOCKED_REVISIT 反応を 1 本流し（or toast）、true を返す。
# 呼出側はそこで通常処理を中断する。
func try_locked_revisit(op_id: StringName) -> bool:
	if not GameState.is_operator_locked(op_id):
		return false
	var rule := ReactionResolver.fire(Enums.TriggerKind.LOCKED_REVISIT, &"", op_id)
	if rule == null:
		EventBus.toast_requested.emit(TranslationServer.translate("TOAST_OPERATOR_LOCKED"))
	return true
