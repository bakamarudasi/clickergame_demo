@tool
extends Control

# Asset Audit のメイン UI。
# - Browse: 全カテゴリのコンテンツを Tree で一覧、クリックで Inspector に開く
# - Audit:  画像未配置の CG step / 壊れた ext_resource 参照を一覧
# - 新規追加: 雛形 .tres を data/<folder>/ に作成して Inspector に開く
# - 画像 D&D: Browse Tree 上の CG step に画像をドロップして差し込む

const Categories = preload("res://addons/asset_audit/categories.gd")
const Scanner = preload("res://addons/asset_audit/scanner.gd")
const DropDialog = preload("res://addons/asset_audit/drop_dialog.gd")

# tree item metadata
const META_KIND := "kind"            # "category" | "resource" | "step"
const META_CATEGORY_KEY := "cat"
const META_PATH := "res_path"
const META_STEP := "step_index"
const META_OP := "op_id"
const META_CG_ID := "cg_id"
const META_HINT := "hint"
const META_MODE := "mode"
# slot 系（"portrait_slot" / "costume_slot"）で使う
const META_SLOT_PROP := "slot_prop"   # "portrait_idle" / "portrait_expressions" / "portrait_face_overlays" /
                                       # "sprite" / "sprite_pose_seductive" / "sprite_xray_variants"
const META_SLOT_KEY := "slot_key"     # Dictionary 系のキー（例: "smile" / "underwear"）

# 外部から plugin.gd がセットする。Inspector 操作や FS 更新に使う。
var editor_plugin: EditorPlugin = null

# UI
var _browse_tree: Tree
var _filter_edit: LineEdit
var _category_picker: OptionButton
var _audit_missing_tree: Tree
var _audit_refs_tree: Tree
var _audit_expr_tree: Tree
var _audit_dangling_tree: Tree
var _audit_translation_tree: Tree
var _dashboard_op_picker: OptionButton
var _dashboard_tree: Tree
var _status_label: Label
var _context_menu: PopupMenu

# プレビューに使うロケール（空 = 任意の locale から拾う）
const _PREVIEW_LOCALE := "ja"

# 待機中のドロップ情報（OS ドラッグ時、files_dropped が来た時にここを参照）
var _pending_drop_target: Dictionary = {}


func _init() -> void:
	name = "Asset Audit"
	custom_minimum_size = Vector2(360, 600)


func _ready() -> void:
	_build_ui()
	_refresh_all()
	var w := get_window()
	if w != null and not w.files_dropped.is_connected(_on_window_files_dropped):
		w.files_dropped.connect(_on_window_files_dropped)


func _exit_tree() -> void:
	var w := get_window()
	if w != null and w.files_dropped.is_connected(_on_window_files_dropped):
		w.files_dropped.disconnect(_on_window_files_dropped)


# -------------------------------------------------------------------------
# UI 構築
# -------------------------------------------------------------------------

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(root)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(tabs)

	tabs.add_child(_build_browse_tab())
	tabs.add_child(_build_audit_tab())
	tabs.add_child(_build_dashboard_tab())

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(1, 1, 1, 0.7)
	_status_label.add_theme_font_size_override("font_size", 11)
	root.add_child(_status_label)


func _build_browse_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Browse"
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.size_flags_vertical = SIZE_EXPAND_FILL

	var top := HBoxContainer.new()
	box.add_child(top)

	var refresh := Button.new()
	refresh.text = "再スキャン"
	refresh.tooltip_text = "data/ 配下を再読込してリストを更新"
	refresh.pressed.connect(_refresh_all)
	top.add_child(refresh)

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "id / name で絞り込み"
	_filter_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter_edit.text_changed.connect(func(_t): _populate_browse_tree())
	top.add_child(_filter_edit)

	_browse_tree = Tree.new()
	_browse_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_browse_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_browse_tree.hide_root = true
	_browse_tree.columns = 2
	_browse_tree.set_column_titles_visible(true)
	_browse_tree.set_column_title(0, "ID / 表示名")
	_browse_tree.set_column_title(1, "状態")
	_browse_tree.set_column_expand(0, true)
	_browse_tree.set_column_expand(1, false)
	_browse_tree.set_column_custom_minimum_width(1, 120)
	_browse_tree.allow_rmb_select = true
	_browse_tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM
	_browse_tree.item_activated.connect(_on_browse_activated)
	_browse_tree.item_mouse_selected.connect(_on_browse_mouse_selected)
	# 共通の右クリックメニュー
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Inspector で開く", 0)
	_context_menu.add_item("使用箇所を検索…", 1)
	_context_menu.add_separator()
	_context_menu.add_item("複製", 2)
	_context_menu.add_item("削除", 3)
	_context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(_context_menu)
	# Tree の D&D は set_drag_forwarding で受け取る
	_browse_tree.set_drag_forwarding(Callable(), _can_drop_browse, _drop_browse)
	box.add_child(_browse_tree)

	var bottom := HBoxContainer.new()
	box.add_child(bottom)

	_category_picker = OptionButton.new()
	for i in Categories.ENTRIES.size():
		var e = Categories.ENTRIES[i]
		_category_picker.add_item(e.label, i)
	bottom.add_child(_category_picker)

	var add_btn := Button.new()
	add_btn.text = "+ 新規追加"
	add_btn.pressed.connect(_on_add_pressed)
	bottom.add_child(add_btn)

	var open_btn := Button.new()
	open_btn.text = "Inspector"
	open_btn.tooltip_text = "選択中の項目を Inspector で開く"
	open_btn.pressed.connect(_on_open_in_inspector_pressed)
	bottom.add_child(open_btn)

	var dup_btn := Button.new()
	dup_btn.text = "複製"
	dup_btn.pressed.connect(_on_duplicate_pressed)
	bottom.add_child(dup_btn)

	var del_btn := Button.new()
	del_btn.text = "削除"
	del_btn.pressed.connect(_on_delete_pressed)
	bottom.add_child(del_btn)

	return box


func _build_audit_tab() -> Control:
	var outer := TabContainer.new()
	outer.name = "Audit"
	outer.size_flags_horizontal = SIZE_EXPAND_FILL
	outer.size_flags_vertical = SIZE_EXPAND_FILL

	# Missing CG
	var missing_box := VBoxContainer.new()
	missing_box.name = "Missing CG"
	var missing_top := HBoxContainer.new()
	missing_box.add_child(missing_top)
	var refresh_missing := Button.new()
	refresh_missing.text = "再スキャン"
	refresh_missing.pressed.connect(_populate_missing_cg_tree)
	missing_top.add_child(refresh_missing)
	var missing_hint := Label.new()
	missing_hint.text = "step に画像をドロップして埋める"
	missing_hint.modulate = Color(1, 1, 1, 0.6)
	missing_top.add_child(missing_hint)

	_audit_missing_tree = Tree.new()
	_audit_missing_tree.hide_root = true
	_audit_missing_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_audit_missing_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_audit_missing_tree.columns = 3
	_audit_missing_tree.set_column_titles_visible(true)
	_audit_missing_tree.set_column_title(0, "CG / Step")
	_audit_missing_tree.set_column_title(1, "Mode")
	_audit_missing_tree.set_column_title(2, "Hint")
	_audit_missing_tree.set_column_expand(0, true)
	_audit_missing_tree.set_column_expand(1, false)
	_audit_missing_tree.set_column_expand(2, true)
	_audit_missing_tree.set_column_custom_minimum_width(1, 70)
	_audit_missing_tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM
	_audit_missing_tree.item_activated.connect(_on_missing_activated)
	_audit_missing_tree.set_drag_forwarding(Callable(), _can_drop_browse, _drop_browse)
	missing_box.add_child(_audit_missing_tree)
	outer.add_child(missing_box)

	# Broken Refs
	var refs_box := VBoxContainer.new()
	refs_box.name = "Broken Refs"
	var refs_top := HBoxContainer.new()
	refs_box.add_child(refs_top)
	var refresh_refs := Button.new()
	refresh_refs.text = "再スキャン"
	refresh_refs.pressed.connect(_populate_refs_tree)
	refs_top.add_child(refresh_refs)
	var refs_hint := Label.new()
	refs_hint.text = "ファイル名ダブルクリックで Inspector に開く"
	refs_hint.modulate = Color(1, 1, 1, 0.6)
	refs_top.add_child(refs_hint)

	_audit_refs_tree = Tree.new()
	_audit_refs_tree.hide_root = true
	_audit_refs_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_audit_refs_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_audit_refs_tree.columns = 2
	_audit_refs_tree.set_column_titles_visible(true)
	_audit_refs_tree.set_column_title(0, "参照元 .tres / .tscn")
	_audit_refs_tree.set_column_title(1, "存在しない参照先")
	_audit_refs_tree.set_column_expand(0, true)
	_audit_refs_tree.set_column_expand(1, true)
	_audit_refs_tree.item_activated.connect(_on_refs_activated)
	refs_box.add_child(_audit_refs_tree)
	outer.add_child(refs_box)

	# Missing Expression Keys
	var expr_box := VBoxContainer.new()
	expr_box.name = "Missing Expressions"
	var expr_top := HBoxContainer.new()
	expr_box.add_child(expr_top)
	var refresh_expr := Button.new()
	refresh_expr.text = "再スキャン"
	refresh_expr.pressed.connect(_populate_expr_tree)
	expr_top.add_child(refresh_expr)
	var expr_hint := Label.new()
	expr_hint.text = "Reaction/CG が参照してる expression キーが Operator に未登録"
	expr_hint.modulate = Color(1, 1, 1, 0.6)
	expr_top.add_child(expr_hint)

	_audit_expr_tree = Tree.new()
	_audit_expr_tree.hide_root = true
	_audit_expr_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_audit_expr_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_audit_expr_tree.columns = 3
	_audit_expr_tree.set_column_titles_visible(true)
	_audit_expr_tree.set_column_title(0, "Operator")
	_audit_expr_tree.set_column_title(1, "expression キー")
	_audit_expr_tree.set_column_title(2, "参照元")
	_audit_expr_tree.set_column_expand(0, false)
	_audit_expr_tree.set_column_expand(1, false)
	_audit_expr_tree.set_column_expand(2, true)
	_audit_expr_tree.set_column_custom_minimum_width(0, 110)
	_audit_expr_tree.set_column_custom_minimum_width(1, 130)
	_audit_expr_tree.item_activated.connect(_on_expr_activated)
	expr_box.add_child(_audit_expr_tree)
	outer.add_child(expr_box)

	# Dangling IDs
	var dang_box := VBoxContainer.new()
	dang_box.name = "Dangling IDs"
	var dang_top := HBoxContainer.new()
	dang_box.add_child(dang_top)
	var refresh_dang := Button.new()
	refresh_dang.text = "再スキャン"
	refresh_dang.pressed.connect(_populate_dangling_tree)
	dang_top.add_child(refresh_dang)
	var dang_hint := Label.new()
	dang_hint.text = "存在しない id を参照してるプロパティ（タイポ検出）"
	dang_hint.modulate = Color(1, 1, 1, 0.6)
	dang_top.add_child(dang_hint)

	_audit_dangling_tree = Tree.new()
	_audit_dangling_tree.hide_root = true
	_audit_dangling_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_audit_dangling_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_audit_dangling_tree.columns = 4
	_audit_dangling_tree.set_column_titles_visible(true)
	_audit_dangling_tree.set_column_title(0, "Source")
	_audit_dangling_tree.set_column_title(1, "field")
	_audit_dangling_tree.set_column_title(2, "value (未定義)")
	_audit_dangling_tree.set_column_title(3, "expected category")
	_audit_dangling_tree.set_column_expand(0, true)
	_audit_dangling_tree.set_column_expand(1, false)
	_audit_dangling_tree.set_column_expand(2, false)
	_audit_dangling_tree.set_column_expand(3, false)
	_audit_dangling_tree.set_column_custom_minimum_width(1, 200)
	_audit_dangling_tree.set_column_custom_minimum_width(2, 160)
	_audit_dangling_tree.set_column_custom_minimum_width(3, 120)
	_audit_dangling_tree.item_activated.connect(_on_dangling_activated)
	dang_box.add_child(_audit_dangling_tree)
	outer.add_child(dang_box)

	# Missing Translation Keys
	var tr_box := VBoxContainer.new()
	tr_box.name = "Missing Translations"
	var tr_top := HBoxContainer.new()
	tr_box.add_child(tr_top)
	var refresh_tr := Button.new()
	refresh_tr.text = "再スキャン"
	refresh_tr.pressed.connect(_populate_translation_tree)
	tr_top.add_child(refresh_tr)
	var tr_hint := Label.new()
	tr_hint.text = "翻訳ソース (.csv/.po) に未登録のキーを参照してるフィールド"
	tr_hint.modulate = Color(1, 1, 1, 0.6)
	tr_top.add_child(tr_hint)

	_audit_translation_tree = Tree.new()
	_audit_translation_tree.hide_root = true
	_audit_translation_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_audit_translation_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_audit_translation_tree.columns = 3
	_audit_translation_tree.set_column_titles_visible(true)
	_audit_translation_tree.set_column_title(0, "Source")
	_audit_translation_tree.set_column_title(1, "field")
	_audit_translation_tree.set_column_title(2, "未定義キー")
	_audit_translation_tree.set_column_expand(0, true)
	_audit_translation_tree.set_column_expand(1, false)
	_audit_translation_tree.set_column_expand(2, true)
	_audit_translation_tree.set_column_custom_minimum_width(1, 200)
	_audit_translation_tree.item_activated.connect(_on_translation_activated)
	tr_box.add_child(_audit_translation_tree)
	outer.add_child(tr_box)

	return outer


# -------------------------------------------------------------------------
# データ再読込
# -------------------------------------------------------------------------

func _refresh_all() -> void:
	# 各種スキャナが同じ index を参照するので、まず一度だけ無効化して
	# 強制リビルドさせる。
	AssetAuditIndex.invalidate()
	AssetAuditIndex._translation_built = false
	_populate_browse_tree()
	_populate_missing_cg_tree()
	_populate_refs_tree()
	_populate_expr_tree()
	_populate_dangling_tree()
	_populate_translation_tree()
	_populate_dashboard()


# -------------------------------------------------------------------------
# Dashboard tab
# -------------------------------------------------------------------------

func _build_dashboard_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Dashboard"
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.size_flags_vertical = SIZE_EXPAND_FILL

	var top := HBoxContainer.new()
	box.add_child(top)
	var pick_label := Label.new()
	pick_label.text = "Operator:"
	top.add_child(pick_label)
	_dashboard_op_picker = OptionButton.new()
	_dashboard_op_picker.item_selected.connect(func (_idx): _populate_dashboard())
	top.add_child(_dashboard_op_picker)
	var refresh := Button.new()
	refresh.text = "↻"
	refresh.pressed.connect(_populate_dashboard)
	top.add_child(refresh)

	_dashboard_tree = Tree.new()
	_dashboard_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_dashboard_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_dashboard_tree.hide_root = true
	_dashboard_tree.columns = 2
	_dashboard_tree.set_column_titles_visible(true)
	_dashboard_tree.set_column_title(0, "セクション / 項目")
	_dashboard_tree.set_column_title(1, "値")
	_dashboard_tree.set_column_expand(0, true)
	_dashboard_tree.set_column_expand(1, true)
	_dashboard_tree.item_activated.connect(_on_dashboard_activated)
	box.add_child(_dashboard_tree)
	return box


func _refresh_op_picker() -> void:
	if _dashboard_op_picker == null:
		return
	var prev_id := ""
	if _dashboard_op_picker.item_count > 0:
		prev_id = _dashboard_op_picker.get_item_text(_dashboard_op_picker.selected)
	_dashboard_op_picker.clear()
	var op_entry := AssetAuditCategories.find_by_key("operators")
	if op_entry.is_empty():
		return
	var ops := AssetAuditScanner.scan_category(op_entry)
	for i in ops.size():
		_dashboard_op_picker.add_item(String(ops[i].id), i)
		_dashboard_op_picker.set_item_metadata(i, ops[i].path)
		if String(ops[i].id) == prev_id:
			_dashboard_op_picker.selected = i


func _populate_dashboard() -> void:
	if _dashboard_tree == null:
		return
	_refresh_op_picker()
	_dashboard_tree.clear()
	if _dashboard_op_picker.item_count == 0:
		var root := _dashboard_tree.create_item()
		var ri := _dashboard_tree.create_item(root)
		ri.set_text(0, "（Operator が未登録）")
		return
	var op_path: String = _dashboard_op_picker.get_item_metadata(_dashboard_op_picker.selected)
	var op: OperatorData = load(op_path) as OperatorData
	if op == null:
		return
	var root := _dashboard_tree.create_item()

	# Header
	var head := _dashboard_tree.create_item(root)
	head.set_text(0, op.id)
	head.set_text(1, AssetAuditIndex.translation_lookup(op.display_name, _PREVIEW_LOCALE))
	head.set_metadata(0, {META_KIND: "resource", META_PATH: op_path})

	# Counts
	var counts := _dashboard_tree.create_item(root)
	counts.set_text(0, "■ コンテンツ数")
	counts.set_selectable(0, false)
	counts.set_selectable(1, false)

	var costumes := _filter_resources("costumes", "operator_id", op.id)
	var cgs := _filter_resources("cgs", "operator_id", op.id)
	var touch := _filter_resources("touch_spots", "operator_id", op.id)
	var reactions := _filter_resources("reactions", "operator_id", op.id)

	_dash_row(counts, "Costumes", str(costumes.size()))
	# CG: 欠損 step 件数も併記
	var missing_cg_steps := 0
	for c in cgs:
		var cg: CGData = c.resource as CGData
		if cg == null: continue
		for s in cg.steps:
			if s != null and s.cg_image == null and (s.mode == Enums.CGStepMode.FULL_CG or s.image_path_hint != ""):
				missing_cg_steps += 1
	_dash_row(counts, "CGs", "%d  (画像未配置 step: %d)" % [cgs.size(), missing_cg_steps])
	_dash_row(counts, "Touch Spots", str(touch.size()))
	_dash_row(counts, "Reactions", str(reactions.size()))
	_dash_row(counts, "Liked Items", str(op.liked_items.size()))
	_dash_row(counts, "Disliked Items", str(op.disliked_items.size()))
	_dash_row(counts, "Default Costume", String(op.default_costume_id))
	_dash_row(counts, "portrait_expressions", str(op.portrait_expressions.size()))
	_dash_row(counts, "portrait_face_overlays", str(op.portrait_face_overlays.size()))

	# Stages
	var stages_root := _dashboard_tree.create_item(root)
	stages_root.set_text(0, "■ Stages")
	stages_root.set_selectable(0, false)
	stages_root.set_selectable(1, false)
	for i in op.stages.size():
		var st: TrustStageData = op.stages[i]
		if st == null: continue
		var sr := _dashboard_tree.create_item(stages_root)
		var title_txt := AssetAuditIndex.translation_lookup(st.title, _PREVIEW_LOCALE) if st.title != "" else ""
		sr.set_text(0, "stage %d  (threshold %d)" % [i, st.threshold])
		sr.set_text(1, title_txt)
		for cu in st.costume_unlocks:
			var c := _dashboard_tree.create_item(sr)
			c.set_text(0, "  unlock costume")
			c.set_text(1, String(cu))
		for cgu in st.cg_unlocks:
			var c2 := _dashboard_tree.create_item(sr)
			c2.set_text(0, "  unlock cg")
			c2.set_text(1, String(cgu))

	# Issues for this operator
	var issues_root := _dashboard_tree.create_item(root)
	issues_root.set_text(0, "■ Issues")
	issues_root.set_selectable(0, false)
	issues_root.set_selectable(1, false)

	var dangling := AssetAuditScanner.scan_dangling_ids()
	var op_dangling := dangling.filter(func (d): return _is_my_op_data(d.source_path, op.id))
	_dash_row(issues_root, "Dangling IDs", "%d 件" % op_dangling.size(),
			Color(1, 0.6, 0.4) if op_dangling.size() > 0 else Color(0.4, 1, 0.5))
	for d in op_dangling:
		var r := _dashboard_tree.create_item(issues_root)
		r.set_text(0, "  %s.%s" % [d.source_path.get_file(), d.field])
		r.set_text(1, "%s (要 %s)" % [d.value, d.expected])
		r.set_custom_color(1, Color(1, 0.6, 0.4))
		r.set_metadata(0, {META_KIND: "resource", META_PATH: d.source_path})

	var expr_missing := AssetAuditScanner.scan_missing_expression_keys().filter(
			func (m): return m.op_id == op.id)
	_dash_row(issues_root, "Missing Expressions", "%d 件" % expr_missing.size(),
			Color(1, 0.6, 0.4) if expr_missing.size() > 0 else Color(0.4, 1, 0.5))
	for e in expr_missing:
		var r := _dashboard_tree.create_item(issues_root)
		r.set_text(0, "  %s" % e.expression_key)
		r.set_text(1, e.source_kind)
		r.set_custom_color(0, Color(1, 0.6, 0.4))
		r.set_metadata(0, {META_KIND: "resource", META_PATH: e.source_path})


func _dash_row(parent: TreeItem, key: String, value: String, value_color: Color = Color(1, 1, 1, 1)) -> TreeItem:
	var r := _dashboard_tree.create_item(parent)
	r.set_text(0, key)
	r.set_text(1, value)
	if value_color != Color(1, 1, 1, 1):
		r.set_custom_color(1, value_color)
	return r


func _filter_resources(category_key: String, prop: String, op_id: StringName) -> Array:
	var entry := AssetAuditCategories.find_by_key(category_key)
	if entry.is_empty():
		return []
	var out: Array = []
	for e in AssetAuditScanner.scan_category(entry):
		var v: Variant = e.resource.get(prop)
		if v != null and v == op_id:
			out.append(e)
	return out


# Issue 行が当該オペレータのデータに属するかどうかをパスから推測。
func _is_my_op_data(source_path: String, op_id: StringName) -> bool:
	var res: Resource = load(source_path)
	if res == null:
		return false
	# operator_id プロパティを持つなら一致確認
	if res.get("operator_id") != null:
		return res.operator_id == op_id
	# Operator 自体
	if res.get("id") != null and res is OperatorData:
		return res.id == op_id
	return false


func _on_dashboard_activated() -> void:
	var item := _dashboard_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and meta.has(META_PATH):
		var path: String = meta[META_PATH]
		if ResourceLoader.exists(path):
			EditorInterface.edit_resource(load(path))


func _populate_browse_tree() -> void:
	_browse_tree.clear()
	var root := _browse_tree.create_item()
	var filter := _filter_edit.text.to_lower() if _filter_edit != null else ""
	var total := 0
	for entry in Categories.ENTRIES:
		var entries := Scanner.scan_category(entry)
		var matched: Array[Dictionary] = []
		for e in entries:
			if filter == "":
				matched.append(e)
				continue
			var hay := "%s %s %s" % [str(e.id), e.display, e.file_name]
			if hay.to_lower().find(filter) != -1:
				matched.append(e)
		if matched.is_empty() and filter != "":
			continue
		var cat_item := _browse_tree.create_item(root)
		cat_item.set_text(0, "%s (%d)" % [entry.label, matched.size()])
		cat_item.set_metadata(0, {
			META_KIND: "category",
			META_CATEGORY_KEY: entry.key,
		})
		cat_item.set_selectable(0, false)
		cat_item.set_selectable(1, false)
		for e in matched:
			total += 1
			var ri := _browse_tree.create_item(cat_item)
			var primary := e.display if e.display != "" else String(e.id)
			if primary == "":
				primary = e.file_name
			# 翻訳キーっぽければ訳文を引いて表示。元キーは tooltip に残す。
			var preview_text := primary
			var translated := AssetAuditIndex.translation_lookup(primary, _PREVIEW_LOCALE)
			if translated != primary and translated != "":
				preview_text = "%s  〈%s〉" % [translated, primary]
			ri.set_text(0, preview_text)
			ri.set_tooltip_text(0, "%s\n%s" % [e.path, e.file_name])
			ri.set_metadata(0, {
				META_KIND: "resource",
				META_CATEGORY_KEY: entry.key,
				META_PATH: e.path,
			})
			# CG なら step を子に並べて欠損ステータスも出す
			if entry.has_cg_steps:
				var cg: CGData = e.resource as CGData
				if cg != null:
					var missing_count := 0
					for i in cg.steps.size():
						var step: CGStep = cg.steps[i]
						if step == null:
							continue
						var si := _browse_tree.create_item(ri)
						si.set_text(0, "  step %02d" % (i + 1))
						var mode_label := "PORTRAIT" if step.mode == Enums.CGStepMode.PORTRAIT else "FULL_CG"
						si.set_text(1, mode_label)
						var hint_or_filled := step.image_path_hint
						if step.cg_image != null:
							hint_or_filled = "[配置済み]"
						elif step.image_path_hint != "":
							missing_count += 1
							hint_or_filled = "⚠ " + step.image_path_hint
						si.set_tooltip_text(0, "image_path_hint: %s\n台詞: %s" % [step.image_path_hint, step.dialogue])
						si.set_metadata(0, {
							META_KIND: "step",
							META_CATEGORY_KEY: entry.key,
							META_PATH: e.path,
							META_STEP: i,
							META_OP: cg.operator_id,
							META_CG_ID: cg.id,
							META_HINT: step.image_path_hint,
							META_MODE: step.mode,
						})
						if step.cg_image == null and step.image_path_hint != "":
							si.set_custom_color(0, Color(1, 0.6, 0.4))
					if missing_count > 0:
						ri.set_text(1, "⚠ %d 件" % missing_count)
						ri.set_custom_color(1, Color(1, 0.6, 0.4))
					else:
						ri.set_text(1, "OK")
						ri.set_custom_color(1, Color(0.4, 1, 0.5))
				elif entry.key == "operators":
					_add_operator_slots(ri, e.resource as OperatorData, e.path)
				elif entry.key == "costumes":
					_add_costume_slots(ri, e.resource as CostumeData, e.path)
	_status_label.text = "%d 件のリソースを表示中" % total


# Operator の portrait 系プロパティを子ノードとして並べる。
# 各行は image をドロップすればそのスロットに直接書き込まれる。
func _add_operator_slots(parent: TreeItem, op: OperatorData, op_path: String) -> void:
	if op == null:
		return
	# portrait_idle (単一 Texture)
	var idle_row := _browse_tree.create_item(parent)
	idle_row.set_text(0, "  portrait_idle")
	idle_row.set_text(1, "[配置済み]" if op.portrait_idle != null else "[未設定]")
	if op.portrait_idle == null:
		idle_row.set_custom_color(1, Color(1, 0.6, 0.4))
	idle_row.set_metadata(0, {
		META_KIND: "portrait_slot",
		META_PATH: op_path,
		META_SLOT_PROP: "portrait_idle",
		META_SLOT_KEY: "",
		META_OP: op.id,
	})
	# 全身差し替え（portrait_expressions）
	if op.portrait_expressions.size() > 0:
		var grp1 := _browse_tree.create_item(parent)
		grp1.set_text(0, "  portrait_expressions (全身差し替え)")
		grp1.set_selectable(0, false)
		grp1.set_selectable(1, false)
		for k in op.portrait_expressions.keys():
			var row := _browse_tree.create_item(grp1)
			row.set_text(0, "    %s" % k)
			row.set_text(1, "[配置済み]" if op.portrait_expressions[k] != null else "[未設定]")
			row.set_metadata(0, {
				META_KIND: "portrait_slot",
				META_PATH: op_path,
				META_SLOT_PROP: "portrait_expressions",
				META_SLOT_KEY: String(k),
				META_OP: op.id,
			})
	# 顔差分（portrait_face_overlays）
	if op.portrait_face_overlays.size() > 0:
		var grp2 := _browse_tree.create_item(parent)
		grp2.set_text(0, "  portrait_face_overlays (顔差分)")
		grp2.set_selectable(0, false)
		grp2.set_selectable(1, false)
		for k in op.portrait_face_overlays.keys():
			var row := _browse_tree.create_item(grp2)
			row.set_text(0, "    %s" % k)
			row.set_text(1, "[配置済み]" if op.portrait_face_overlays[k] != null else "[未設定]")
			row.set_metadata(0, {
				META_KIND: "portrait_slot",
				META_PATH: op_path,
				META_SLOT_PROP: "portrait_face_overlays",
				META_SLOT_KEY: String(k),
				META_OP: op.id,
			})


# Costume のスプライト系プロパティを子ノードとして並べる。
func _add_costume_slots(parent: TreeItem, costume: CostumeData, costume_path: String) -> void:
	if costume == null:
		return
	for slot_prop in ["sprite", "sprite_pose_seductive"]:
		var tex: Texture2D = costume.get(slot_prop)
		var row := _browse_tree.create_item(parent)
		row.set_text(0, "  %s" % slot_prop)
		row.set_text(1, "[配置済み]" if tex != null else "[未設定]")
		if tex == null:
			row.set_custom_color(1, Color(1, 0.6, 0.4))
		row.set_metadata(0, {
			META_KIND: "costume_slot",
			META_PATH: costume_path,
			META_SLOT_PROP: slot_prop,
			META_SLOT_KEY: "",
			META_OP: costume.operator_id,
		})
	if costume.sprite_xray_variants.size() > 0:
		var grp := _browse_tree.create_item(parent)
		grp.set_text(0, "  sprite_xray_variants (X-ray 差分)")
		grp.set_selectable(0, false)
		grp.set_selectable(1, false)
		for k in costume.sprite_xray_variants.keys():
			var row := _browse_tree.create_item(grp)
			row.set_text(0, "    %s" % k)
			row.set_text(1, "[配置済み]" if costume.sprite_xray_variants[k] != null else "[未設定]")
			row.set_metadata(0, {
				META_KIND: "costume_slot",
				META_PATH: costume_path,
				META_SLOT_PROP: "sprite_xray_variants",
				META_SLOT_KEY: String(k),
				META_OP: costume.operator_id,
			})


func _populate_missing_cg_tree() -> void:
	_audit_missing_tree.clear()
	var root := _audit_missing_tree.create_item()
	var missing := Scanner.scan_missing_cg_steps()
	# CG 単位でグループ化
	var by_cg: Dictionary = {}
	for m in missing:
		var key: String = m.cg_path
		if not by_cg.has(key):
			by_cg[key] = []
		by_cg[key].append(m)
	for cg_path in by_cg.keys():
		var arr: Array = by_cg[cg_path]
		var parent := _audit_missing_tree.create_item(root)
		parent.set_text(0, "%s  (%d step)" % [cg_path.get_file().get_basename(), arr.size()])
		parent.set_metadata(0, {
			META_KIND: "resource",
			META_CATEGORY_KEY: "cgs",
			META_PATH: cg_path,
		})
		parent.set_tooltip_text(0, cg_path)
		for m in arr:
			var ci := _audit_missing_tree.create_item(parent)
			ci.set_text(0, "step %02d" % (m.step_index + 1))
			var mode_label := "PORTRAIT" if m.mode == Enums.CGStepMode.PORTRAIT else "FULL_CG"
			ci.set_text(1, mode_label)
			ci.set_text(2, m.hint)
			ci.set_custom_color(0, Color(1, 0.6, 0.4))
			ci.set_metadata(0, {
				META_KIND: "step",
				META_CATEGORY_KEY: "cgs",
				META_PATH: m.cg_path,
				META_STEP: m.step_index,
				META_OP: m.op_id,
				META_CG_ID: m.cg_id,
				META_HINT: m.hint,
				META_MODE: m.mode,
			})


func _populate_refs_tree() -> void:
	_audit_refs_tree.clear()
	var root := _audit_refs_tree.create_item()
	var broken := Scanner.scan_broken_refs()
	# ファイル単位でグループ化
	var by_file: Dictionary = {}
	for b in broken:
		if not by_file.has(b.file):
			by_file[b.file] = []
		by_file[b.file].append(b.missing_path)
	for file in by_file.keys():
		var parent := _audit_refs_tree.create_item(root)
		parent.set_text(0, file)
		parent.set_metadata(0, {
			META_KIND: "resource",
			META_PATH: file,
		})
		for p in by_file[file]:
			var ri := _audit_refs_tree.create_item(parent)
			ri.set_text(0, "  ↳")
			ri.set_text(1, p)
			ri.set_custom_color(1, Color(1, 0.6, 0.4))


# -------------------------------------------------------------------------
# Browse: 操作
# -------------------------------------------------------------------------

func _on_browse_activated() -> void:
	_open_selected_in_inspector(_browse_tree)


func _on_browse_mouse_selected(_pos: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_RIGHT:
		return
	var item := _browse_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	# resource / step / portrait_slot / costume_slot 行で開く
	var kind: String = meta.get(META_KIND, "")
	if not (kind in ["resource", "step", "portrait_slot", "costume_slot"]):
		return
	_context_menu.position = DisplayServer.mouse_get_position()
	_context_menu.reset_size()
	_context_menu.popup()


func _on_context_menu_pressed(id: int) -> void:
	var item := _browse_tree.get_selected()
	if item == null:
		return
	match id:
		0: _open_selected_in_inspector(_browse_tree)
		1: _show_references_popup_for_selected()
		2: _on_duplicate_pressed()
		3: _on_delete_pressed()


# 選択中の行（resource / step / portrait_slot 等）に紐付く id を判定し、
# その id を参照しているファイル一覧を別ウィンドウで表示する。
func _show_references_popup_for_selected() -> void:
	var item := _browse_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	var id_to_search: String = ""
	if meta.has(META_PATH):
		var path: String = meta[META_PATH]
		var res: Resource = load(path)
		if res != null and res.get("id") != null:
			var v: Variant = res.get("id")
			if v is StringName:
				id_to_search = String(v)
			elif v is String:
				id_to_search = v
		# 配列格納（reactions / messages）は id を持たないので省略
	if id_to_search == "":
		_status_label.text = "id を持たないリソースなので逆引きできません"
		return
	_open_references_popup(id_to_search)


func _open_references_popup(id: String) -> void:
	var refs := AssetAuditIndex.references_of(id)
	var defined := AssetAuditIndex.defined_in(id)
	var dlg := AcceptDialog.new()
	dlg.title = "id 逆引き: %s" % id
	dlg.min_size = Vector2(600, 420)

	var vb := VBoxContainer.new()
	dlg.add_child(vb)

	var summary := Label.new()
	var def_str := ""
	if defined.size() > 0:
		def_str = " / 定義: %s" % defined[0].path.get_file()
	summary.text = "%d 件の参照%s" % [refs.size(), def_str]
	summary.modulate = Color(1, 1, 1, 0.85)
	vb.add_child(summary)

	var tree := Tree.new()
	tree.size_flags_horizontal = SIZE_EXPAND_FILL
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.columns = 1
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "参照元ファイル（ダブルクリックで開く）")
	var root := tree.create_item()
	for r in refs:
		var ri := tree.create_item(root)
		ri.set_text(0, r.source_path)
		ri.set_metadata(0, r.source_path)
	tree.item_activated.connect(func ():
		var sel := tree.get_selected()
		if sel == null: return
		var p: String = sel.get_metadata(0)
		if ResourceLoader.exists(p):
			EditorInterface.edit_resource(load(p))
	)
	vb.add_child(tree)

	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _on_missing_activated() -> void:
	_open_selected_in_inspector(_audit_missing_tree)


func _on_refs_activated() -> void:
	var item := _audit_refs_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and meta.has(META_PATH):
		var path: String = meta[META_PATH]
		if ResourceLoader.exists(path):
			EditorInterface.edit_resource(load(path))


func _on_expr_activated() -> void:
	var item := _audit_expr_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and meta.has(META_PATH):
		var path: String = meta[META_PATH]
		if ResourceLoader.exists(path):
			EditorInterface.edit_resource(load(path))


func _on_dangling_activated() -> void:
	var item := _audit_dangling_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and meta.has(META_PATH):
		var path: String = meta[META_PATH]
		if ResourceLoader.exists(path):
			EditorInterface.edit_resource(load(path))


func _on_translation_activated() -> void:
	var item := _audit_translation_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and meta.has(META_PATH):
		var path: String = meta[META_PATH]
		if ResourceLoader.exists(path):
			EditorInterface.edit_resource(load(path))


func _populate_translation_tree() -> void:
	if _audit_translation_tree == null:
		return
	_audit_translation_tree.clear()
	var root := _audit_translation_tree.create_item()
	var missing := AssetAuditScanner.scan_missing_translation_keys()
	for m in missing:
		var ri := _audit_translation_tree.create_item(root)
		ri.set_text(0, "%s  (%s)" % [m.source_path.get_file(), m.source_kind])
		ri.set_text(1, m.field)
		ri.set_text(2, m.key)
		ri.set_custom_color(2, Color(1, 0.6, 0.4))
		ri.set_metadata(0, {
			META_KIND: "resource",
			META_PATH: m.source_path,
		})


func _populate_dangling_tree() -> void:
	if _audit_dangling_tree == null:
		return
	_audit_dangling_tree.clear()
	var root := _audit_dangling_tree.create_item()
	var dangling := AssetAuditScanner.scan_dangling_ids()
	for d in dangling:
		var ri := _audit_dangling_tree.create_item(root)
		ri.set_text(0, "%s  (%s)" % [d.source_path.get_file(), d.source_kind])
		ri.set_text(1, d.field)
		ri.set_text(2, d.value)
		ri.set_text(3, d.expected)
		ri.set_custom_color(2, Color(1, 0.6, 0.4))
		ri.set_metadata(0, {
			META_KIND: "resource",
			META_PATH: d.source_path,
		})


func _populate_expr_tree() -> void:
	if _audit_expr_tree == null:
		return
	_audit_expr_tree.clear()
	var root := _audit_expr_tree.create_item()
	var missing := AssetAuditScanner.scan_missing_expression_keys()
	for m in missing:
		var ri := _audit_expr_tree.create_item(root)
		ri.set_text(0, String(m.op_id))
		ri.set_text(1, m.expression_key)
		ri.set_text(2, "%s  (%s)" % [m.source_path.get_file(), m.source_kind])
		ri.set_custom_color(1, Color(1, 0.6, 0.4))
		ri.set_metadata(0, {
			META_KIND: "resource",
			META_PATH: m.source_path,
		})


func _open_selected_in_inspector(tree: Tree) -> void:
	var item := tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	if meta.has(META_PATH):
		var res := load(meta[META_PATH])
		if res != null:
			EditorInterface.edit_resource(res)
			# step が選ばれてた場合は、その配列要素をハイライト出来ないけど
			# 最低限リソース自体は開く。配列内 step は Inspector の steps 配列から辿る。


func _on_open_in_inspector_pressed() -> void:
	_open_selected_in_inspector(_browse_tree)


# 新規追加
func _on_add_pressed() -> void:
	var idx := _category_picker.selected
	if idx < 0 or idx >= Categories.ENTRIES.size():
		return
	var entry: Dictionary = Categories.ENTRIES[idx]
	var new_id := _next_available_id(entry)
	var folder := "%s/%s" % [Scanner.DATA_ROOT, entry.folder]
	DirAccess.make_dir_recursive_absolute(folder)
	var file_name := "%s.tres" % new_id
	var path := "%s/%s" % [folder, file_name]
	var counter := 1
	while FileAccess.file_exists(path):
		counter += 1
		new_id = "%s_%03d" % [entry.id_prefix, counter]
		path = "%s/%s.tres" % [folder, new_id]
	var res: Resource = Categories.instantiate(entry.class_name_)
	if res == null:
		_status_label.text = "雛形作成失敗: %s" % entry.class_name_
		return
	if entry.storage == "dict" and res.get("id") != null:
		res.set("id", StringName(new_id))
	if res.get("display_name") != null and res.get("display_name") == "":
		res.set("display_name", new_id)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		_status_label.text = "保存失敗 err=%d: %s" % [err, path]
		return
	_refresh_filesystem()
	_status_label.text = "作成: %s" % path
	_refresh_all()
	# 保存直後の Resource インスタンスはファイルパスを持たないので、
	# 改めて load してから Inspector に渡す（こうしないと Inspector が無名扱いになる）。
	var loaded := load(path)
	if loaded != null:
		EditorInterface.edit_resource(loaded)


func _next_available_id(entry: Dictionary) -> String:
	var prefix: String = entry.id_prefix
	var folder := "%s/%s" % [Scanner.DATA_ROOT, entry.folder]
	var used := {}
	if DirAccess.dir_exists_absolute(folder):
		var dir := DirAccess.open(folder)
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if n.ends_with(".tres"):
				used[n.get_basename()] = true
			n = dir.get_next()
		dir.list_dir_end()
	var i := 1
	while true:
		var candidate := "%s_%03d" % [prefix, i]
		if not used.has(candidate):
			return candidate
		i += 1
	return "%s_new" % prefix


func _on_duplicate_pressed() -> void:
	var item := _browse_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary) or not meta.has(META_PATH):
		return
	var src: String = meta[META_PATH]
	var dir_path := src.get_base_dir()
	var base := src.get_file().get_basename()
	var i := 2
	var dst := "%s/%s_copy.tres" % [dir_path, base]
	while FileAccess.file_exists(dst):
		dst = "%s/%s_copy%d.tres" % [dir_path, base, i]
		i += 1
	var res: Resource = load(src)
	if res == null:
		return
	var dup: Resource = res.duplicate(true)
	if dup.get("id") != null:
		dup.set("id", StringName(dst.get_file().get_basename()))
	var err := ResourceSaver.save(dup, dst)
	if err != OK:
		_status_label.text = "複製失敗: err=%d" % err
		return
	_refresh_filesystem()
	_status_label.text = "複製: %s" % dst
	_refresh_all()


func _on_delete_pressed() -> void:
	var item := _browse_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary) or not meta.has(META_PATH):
		return
	var path: String = meta[META_PATH]
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "削除: %s\nこの .tres を削除します。元に戻せません。" % path
	dlg.ok_button_text = "削除"
	dlg.confirmed.connect(func ():
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err != OK:
			_status_label.text = "削除失敗 err=%d" % err
		else:
			_status_label.text = "削除: %s" % path
		_refresh_filesystem()
		_refresh_all()
		dlg.queue_free()
	)
	dlg.canceled.connect(func (): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


# -------------------------------------------------------------------------
# Drag & Drop（Tree 内部ドロップ = FileSystem dock からの drag）
# -------------------------------------------------------------------------

const _DROP_KINDS := ["step", "portrait_slot", "costume_slot"]


func _can_drop_browse(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if data.get("type", "") != "files":
		return false
	var files: PackedStringArray = data.get("files", PackedStringArray())
	if files.is_empty():
		return false
	var tree: Tree = _hit_test_tree(at_position)
	if tree == null:
		return false
	var item := tree.get_item_at_position(tree.get_local_mouse_position())
	if item == null:
		return false
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return false
	return meta.get(META_KIND, "") in _DROP_KINDS


func _drop_browse(at_position: Vector2, data: Variant) -> void:
	var tree: Tree = _hit_test_tree(at_position)
	if tree == null:
		return
	var item := tree.get_item_at_position(tree.get_local_mouse_position())
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	var kind: String = meta.get(META_KIND, "")
	var files: PackedStringArray = data.get("files", PackedStringArray())
	if files.is_empty():
		return
	# 内部 D&D の files は res:// パス
	_dispatch_drop(kind, meta, files[0], false)


func _dispatch_drop(kind: String, meta: Dictionary, src_path: String, src_is_os: bool) -> void:
	if kind == "step":
		_show_drop_mode_dialog(meta, src_path, src_is_os)
	elif kind == "portrait_slot" or kind == "costume_slot":
		# slot 直接ドロップは対象が一意なのでダイアログ不要、上書き確認だけ。
		_apply_slot_drop(meta, src_path, src_is_os)


func _hit_test_tree(_at_position: Vector2) -> Tree:
	# どちらの Tree にホバーしてるか判定。
	for t in [_browse_tree, _audit_missing_tree]:
		if t == null:
			continue
		var local := t.get_local_mouse_position()
		if Rect2(Vector2.ZERO, t.size).has_point(local):
			return t
	return null


# OS からのドラッグ（プロジェクト外ファイル）
func _on_window_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	# 現在のマウス位置から、どのターゲット行に落ちたかを決定する。
	var tree: Tree = _hit_test_tree(Vector2.ZERO)
	if tree == null:
		return
	var item := tree.get_item_at_position(tree.get_local_mouse_position())
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	var kind: String = meta.get(META_KIND, "")
	if not (kind in _DROP_KINDS):
		return
	_dispatch_drop(kind, meta, files[0], true)


# -------------------------------------------------------------------------
# 画像差し込み本体（モード選択ダイアログ → 保存 → リソース更新）
# -------------------------------------------------------------------------

func _show_drop_mode_dialog(target_meta: Dictionary, src_path: String, src_is_os: bool) -> void:
	var dlg: DropDialog = DropDialog.new()
	dlg.setup(target_meta, src_path, src_is_os)
	dlg.confirmed_apply.connect(_apply_image_drop)
	add_child(dlg)
	dlg.popup_centered()


func _apply_image_drop(meta: Dictionary, src_path: String, src_is_os: bool,
		mode_choice: int, switch_to_full_cg: bool, expression_key: String) -> void:
	# mode_choice:
	#   0 = FULL_CG として step.cg_image にセット
	#   1 = step を FULL_CG に変えて step.cg_image にセット
	#   2 = OperatorData.portrait_face_overlays[expression] に登録（顔差分）
	var src_name := src_path.get_file()
	var op_id := StringName(meta.get(META_OP, &""))
	var cg_id := StringName(meta.get(META_CG_ID, &""))
	var step_index: int = meta.get(META_STEP, 0)
	var hint: String = meta.get(META_HINT, "")
	var dst := AssetAuditScanner.resolve_cg_save_path(op_id, cg_id, step_index, hint, src_name)

	# 上書き確認
	if FileAccess.file_exists(dst):
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = "上書きしますか？\n%s" % dst
		confirm.ok_button_text = "上書き"
		confirm.confirmed.connect(func ():
			confirm.queue_free()
			_perform_copy_and_assign(meta, src_path, src_is_os, dst, mode_choice, switch_to_full_cg, expression_key)
		)
		confirm.canceled.connect(func (): confirm.queue_free())
		add_child(confirm)
		confirm.popup_centered()
		return
	_perform_copy_and_assign(meta, src_path, src_is_os, dst, mode_choice, switch_to_full_cg, expression_key)


func _perform_copy_and_assign(meta: Dictionary, src_path: String, src_is_os: bool,
		dst: String, mode_choice: int, switch_to_full_cg: bool, expression_key: String) -> void:
	# 1. コピー先ディレクトリ作成
	var dst_dir := dst.get_base_dir()
	var dst_abs := ProjectSettings.globalize_path(dst)
	var dst_dir_abs := ProjectSettings.globalize_path(dst_dir)
	DirAccess.make_dir_recursive_absolute(dst_dir_abs)
	# 2. ファイルコピー
	var src_abs := src_path if src_is_os else ProjectSettings.globalize_path(src_path)
	var err := DirAccess.copy_absolute(src_abs, dst_abs)
	if err != OK:
		_status_label.text = "コピー失敗 err=%d: %s" % [err, dst]
		return
	# 3. EditorFS に新規ファイルを認識させてインポートさせる
	_refresh_filesystem()
	# インポートはフレーム跨ぎなので少し待つ
	await get_tree().process_frame
	await get_tree().process_frame
	# 4. ロード（インポート未完了なら null なので軽くリトライ）
	var tex: Texture2D = null
	for retry in 10:
		if ResourceLoader.exists(dst):
			tex = load(dst) as Texture2D
		if tex != null:
			break
		await get_tree().create_timer(0.1).timeout
	if tex == null:
		_status_label.text = "インポート未完了。エディタ FileSystem で確認後、再度ドロップしてください: %s" % dst
		return
	# 5. 対象リソースを書き換え
	var cg_path: String = meta.get(META_PATH, "")
	var cg: CGData = load(cg_path) as CGData
	if cg == null:
		_status_label.text = "CG ロード失敗: %s" % cg_path
		return
	var step_index: int = meta.get(META_STEP, 0)
	if step_index < 0 or step_index >= cg.steps.size():
		_status_label.text = "step index 範囲外: %d" % step_index
		return
	var step: CGStep = cg.steps[step_index]
	match mode_choice:
		0, 1:
			step.cg_image = tex
			if switch_to_full_cg or mode_choice == 1:
				step.mode = Enums.CGStepMode.FULL_CG
			step.image_path_hint = dst.trim_prefix("res://")
			var err2 := ResourceSaver.save(cg, cg_path)
			if err2 != OK:
				_status_label.text = "CG 保存失敗 err=%d" % err2
				return
			_status_label.text = "差し込み完了: %s -> %s" % [dst, cg_path]
		2, 3:
			# 2 = portrait_expressions（全身まるごと差し替え）
			# 3 = portrait_face_overlays（顔だけ差分）
			var op_path: String = "res://data/operators/%s.tres" % meta.get(META_OP, &"")
			var op: OperatorData = load(op_path) as OperatorData
			if op == null:
				_status_label.text = "Operator ロード失敗: %s" % op_path
				return
			var key := StringName(expression_key)
			if key == &"":
				_status_label.text = "expression キーが空です"
				return
			var dict_name := "portrait_expressions" if mode_choice == 2 else "portrait_face_overlays"
			var d: Dictionary = op.get(dict_name)
			d[key] = tex
			op.set(dict_name, d)
			var err3 := ResourceSaver.save(op, op_path)
			if err3 != OK:
				_status_label.text = "Operator 保存失敗 err=%d" % err3
				return
			_status_label.text = "登録: %s -> %s.%s[%s]" % [dst, op.id, dict_name, key]
	_refresh_filesystem()
	_refresh_all()


# -------------------------------------------------------------------------
# Slot 直接ドロップ（portrait_slot / costume_slot）
# -------------------------------------------------------------------------

func _apply_slot_drop(meta: Dictionary, src_path: String, src_is_os: bool) -> void:
	var src_name := src_path.get_file()
	var dst := AssetAuditScanner.resolve_slot_save_path(meta, src_name)
	if FileAccess.file_exists(dst):
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = "上書きしますか？\n%s" % dst
		confirm.ok_button_text = "上書き"
		confirm.confirmed.connect(func ():
			confirm.queue_free()
			_perform_slot_copy_and_assign(meta, src_path, src_is_os, dst)
		)
		confirm.canceled.connect(func (): confirm.queue_free())
		add_child(confirm)
		confirm.popup_centered()
		return
	_perform_slot_copy_and_assign(meta, src_path, src_is_os, dst)


func _perform_slot_copy_and_assign(meta: Dictionary, src_path: String, src_is_os: bool, dst: String) -> void:
	var dst_dir := dst.get_base_dir()
	var dst_abs := ProjectSettings.globalize_path(dst)
	var dst_dir_abs := ProjectSettings.globalize_path(dst_dir)
	DirAccess.make_dir_recursive_absolute(dst_dir_abs)
	var src_abs := src_path if src_is_os else ProjectSettings.globalize_path(src_path)
	var err := DirAccess.copy_absolute(src_abs, dst_abs)
	if err != OK:
		_status_label.text = "コピー失敗 err=%d: %s" % [err, dst]
		return
	_refresh_filesystem()
	await get_tree().process_frame
	await get_tree().process_frame
	var tex: Texture2D = null
	for retry in 10:
		if ResourceLoader.exists(dst):
			tex = load(dst) as Texture2D
		if tex != null:
			break
		await get_tree().create_timer(0.1).timeout
	if tex == null:
		_status_label.text = "インポート未完了: %s" % dst
		return
	var resource_path: String = meta.get(META_PATH, "")
	var slot_prop: String = meta.get(META_SLOT_PROP, "")
	var slot_key: String = meta.get(META_SLOT_KEY, "")
	var res: Resource = load(resource_path)
	if res == null:
		_status_label.text = "リソース ロード失敗: %s" % resource_path
		return
	var kind: String = meta.get(META_KIND, "")
	if kind == "portrait_slot":
		var op := res as OperatorData
		if op == null:
			_status_label.text = "Operator キャスト失敗"
			return
		if slot_prop == "portrait_idle":
			op.portrait_idle = tex
		else:
			# Dictionary 系。get/set でディクショナリを受け取って書き戻す。
			var d: Dictionary = op.get(slot_prop)
			d[StringName(slot_key)] = tex
			op.set(slot_prop, d)
	elif kind == "costume_slot":
		var costume := res as CostumeData
		if costume == null:
			_status_label.text = "Costume キャスト失敗"
			return
		if slot_prop == "sprite_xray_variants":
			costume.sprite_xray_variants[StringName(slot_key)] = tex
		else:
			costume.set(slot_prop, tex)
	var err2 := ResourceSaver.save(res, resource_path)
	if err2 != OK:
		_status_label.text = "保存失敗 err=%d" % err2
		return
	_status_label.text = "差し込み: %s -> %s.%s%s" % [
		dst, resource_path.get_file(), slot_prop,
		"[%s]" % slot_key if slot_key != "" else "",
	]
	_refresh_filesystem()
	_refresh_all()


func _refresh_filesystem() -> void:
	if editor_plugin != null:
		var fs := editor_plugin.get_editor_interface().get_resource_filesystem()
		if fs != null:
			fs.scan()
	else:
		EditorInterface.get_resource_filesystem().scan()
