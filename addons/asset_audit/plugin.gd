@tool
extends EditorPlugin

const AuditDock = preload("res://addons/asset_audit/audit_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = AuditDock.new()
	_dock.editor_plugin = self
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
