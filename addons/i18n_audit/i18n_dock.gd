@tool
extends VBoxContainer

const Scanner = preload("res://addons/i18n_audit/scanner.gd")

var editor_plugin: EditorPlugin = null

var _summary_label: Label
var _tabs: TabContainer
var _tree_missing: Tree
var _tree_unused: Tree
var _tree_undefined: Tree


func _init() -> void:
	name = "i18n Audit"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build_ui()
	_refresh()


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var header := HBoxContainer.new()
	add_child(header)
	var refresh_btn := Button.new()
	refresh_btn.text = "Rescan"
	refresh_btn.pressed.connect(_refresh)
	header.add_child(refresh_btn)
	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_summary_label)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	_tree_undefined = _make_tree(["Key", "Used at"])
	_tree_undefined.name = "Undefined"
	_tabs.add_child(_tree_undefined)

	_tree_missing = _make_tree(["Key", "Locale", "CSV", "Used at"])
	_tree_missing.name = "Empty cells"
	_tabs.add_child(_tree_missing)

	_tree_unused = _make_tree(["Key", "CSV"])
	_tree_unused.name = "Unused"
	_tabs.add_child(_tree_unused)


func _make_tree(columns: Array) -> Tree:
	var t := Tree.new()
	t.columns = columns.size()
	t.column_titles_visible = true
	for i in columns.size():
		t.set_column_title(i, columns[i])
		t.set_column_expand(i, true)
		t.set_column_clip_content(i, true)
	t.hide_root = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.item_activated.connect(_on_tree_item_activated.bind(t))
	return t


# --- Scan & populate --------------------------------------------------------

func _refresh() -> void:
	var rep := Scanner.scan()
	_summary_label.text = "  usages: %d   undef: %d   empty: %d   unused: %d   csv files: %d" % [
		rep.usages.size(),
		rep.undefined.size(),
		rep.missing.size(),
		rep.unused.size(),
		rep.tables.size(),
	]
	_populate_undefined(rep)
	_populate_missing(rep)
	_populate_unused(rep)


func _populate_undefined(rep) -> void:
	_tree_undefined.clear()
	var root := _tree_undefined.create_item()
	var sorted := rep.undefined.duplicate()
	sorted.sort_custom(func(a, b): return a["key"] < b["key"])
	for entry in sorted:
		var it := _tree_undefined.create_item(root)
		it.set_text(0, entry["key"])
		var first: Dictionary = entry["usages"][0] if not entry["usages"].is_empty() else {}
		var loc_text := ""
		if not first.is_empty():
			loc_text = "%s:%d" % [first["path"], first["line"]]
			if entry["usages"].size() > 1:
				loc_text += "  (+%d)" % (entry["usages"].size() - 1)
		it.set_text(1, loc_text)
		it.set_metadata(0, first)


func _populate_missing(rep) -> void:
	_tree_missing.clear()
	var root := _tree_missing.create_item()
	var sorted := rep.missing.duplicate()
	sorted.sort_custom(func(a, b):
		if a["key"] != b["key"]:
			return a["key"] < b["key"]
		return a["locale"] < b["locale"])
	for entry in sorted:
		var it := _tree_missing.create_item(root)
		it.set_text(0, entry["key"])
		it.set_text(1, entry["locale"])
		it.set_text(2, entry["table_path"].get_file())
		var usages: Array = entry["usages"]
		if usages.is_empty():
			it.set_text(3, "(resource field)")
			it.set_metadata(0, {"path": entry["table_path"], "line": 1})
		else:
			var first: Dictionary = usages[0]
			var loc := "%s:%d" % [first["path"], first["line"]]
			if usages.size() > 1:
				loc += "  (+%d)" % (usages.size() - 1)
			it.set_text(3, loc)
			it.set_metadata(0, first)


func _populate_unused(rep) -> void:
	_tree_unused.clear()
	var root := _tree_unused.create_item()
	var sorted := rep.unused.duplicate()
	sorted.sort_custom(func(a, b): return a["key"] < b["key"])
	for entry in sorted:
		var it := _tree_unused.create_item(root)
		it.set_text(0, entry["key"])
		it.set_text(1, entry["table_path"].get_file())
		it.set_metadata(0, {"path": entry["table_path"], "line": 1})


# --- 行クリックでファイルを開く ---------------------------------------------

func _on_tree_item_activated(tree: Tree) -> void:
	var sel := tree.get_selected()
	if sel == null:
		return
	var meta: Variant = sel.get_metadata(0)
	if meta == null or not (meta is Dictionary):
		return
	var path: String = meta.get("path", "")
	if path == "":
		return
	var line: int = meta.get("line", 1)
	if path.ends_with(".gd"):
		EditorInterface.edit_script(load(path), line)
	else:
		EditorInterface.select_file(path)
