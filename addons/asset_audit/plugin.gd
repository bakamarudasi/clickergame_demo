@tool
extends EditorPlugin

const AuditDock = preload("res://addons/asset_audit/audit_dock.gd")
const Index = preload("res://addons/asset_audit/index.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = AuditDock.new()
	_dock.editor_plugin = self
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)
	# ファイル変更でインデックスキャッシュを無効化。ユーザーが Inspector や
	# FileSystem で .tres / 翻訳 .csv を編集した直後に逆引きが古くならないように。
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null and not fs.filesystem_changed.is_connected(_on_fs_changed):
		fs.filesystem_changed.connect(_on_fs_changed)


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null and fs.filesystem_changed.is_connected(_on_fs_changed):
		fs.filesystem_changed.disconnect(_on_fs_changed)
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _on_fs_changed() -> void:
	Index.invalidate()
	Index._translation_built = false
