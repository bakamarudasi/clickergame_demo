extends Control

# Statusタブ（仮置き）。各オペレーターの主要ステータスを縦に並べるだけのプレースホルダ。
# 将来は CG/Memory 解放数、累計ギフト、ハラス値、xray 視認数 なども載せて
# ギャラリー系の導線にする予定。
# 「特定アイテム購入で初めてタブを解放」みたいなゲートも後付けする想定（今は常時表示）。

@onready var operator_vbox: VBoxContainer = %OperatorVBox

# op_id -> Dictionary { row: VBoxContainer, lines: Dictionary{ "trust" / "intimacy" / "arousal": Label } }
var _rows: Dictionary = {}


func _ready() -> void:
	EventBus.operator_unlocked.connect(_on_operator_unlocked)
	EventBus.trust_changed.connect(_on_trust_changed)
	EventBus.intimacy_changed.connect(_on_intimacy_changed)
	EventBus.arousal_changed.connect(_on_arousal_changed)
	_rebuild()


func _rebuild() -> void:
	for child in operator_vbox.get_children():
		child.queue_free()
	_rows.clear()
	for op: OperatorData in DataRegistry.get_all_operators():
		if not GameState.is_operator_unlocked(op.id):
			continue
		_make_row(op)


func _make_row(op: OperatorData) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var name_label := Label.new()
	name_label.theme_type_variation = UIConstants.VAR_DISPLAY_LABEL
	name_label.text = tr(op.display_name)
	row.add_child(name_label)
	var trust_lbl := Label.new()
	var intimacy_lbl := Label.new()
	var arousal_lbl := Label.new()
	row.add_child(trust_lbl)
	row.add_child(intimacy_lbl)
	row.add_child(arousal_lbl)
	operator_vbox.add_child(row)
	_rows[op.id] = {
		"row": row,
		"trust": trust_lbl,
		"intimacy": intimacy_lbl,
		"arousal": arousal_lbl,
	}
	_refresh_row(op.id)


func _refresh_row(op_id: StringName) -> void:
	if not _rows.has(op_id):
		return
	var rt := GameState.get_runtime(op_id)
	if rt == null:
		return
	var entry: Dictionary = _rows[op_id]
	(entry.trust as Label).text = tr("STATUS_TRUST_FMT") % rt.trust
	(entry.intimacy as Label).text = tr("STATUS_INTIMACY_FMT") % rt.intimacy
	(entry.arousal as Label).text = tr("STATUS_AROUSAL_FMT") % int(GameState.get_arousal(op_id))


func _on_operator_unlocked(_op_id: StringName) -> void:
	_rebuild()


func _on_trust_changed(op_id: StringName, _trust: int, _stage: int) -> void:
	_refresh_row(op_id)


func _on_intimacy_changed(op_id: StringName, _v: int) -> void:
	_refresh_row(op_id)


func _on_arousal_changed(op_id: StringName, _v: float) -> void:
	_refresh_row(op_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild()
