@tool
class_name AssetAuditScanner
extends RefCounted

# data/ 配下を走査して Browse/Audit に必要な情報を集める。
# Inspector とは独立に動くので、エディタを再起動せずに新規 .tres を拾える。

const DATA_ROOT := "res://data"
const CG_FOLDER_DEFAULT := "res://assets/cg"


# カテゴリ key -> Array[{ path: String, resource: Resource, id: StringName, display: String }]
static func scan_category(entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir_path := "%s/%s" % [DATA_ROOT, entry.folder]
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full := "%s/%s" % [dir_path, file_name]
			var res: Resource = load(full)
			if res != null:
				var id_value: Variant = res.get("id") if res.get("id") != null else &""
				var display: String = ""
				if res.get("display_name") != null:
					display = res.get("display_name")
				elif entry.storage == "array":
					display = file_name.get_basename()
				out.append({
					"path": full,
					"resource": res,
					"id": id_value,
					"display": display,
					"file_name": file_name,
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return String(a.file_name) < String(b.file_name))
	return out


# 全 CG をスキャンして「画像未配置の step」を返す。
# 戻り値: Array[{ cg_path, cg_id, op_id, step_index, mode, hint }]
static func scan_missing_cg_steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entry := AssetAuditCategories.find_by_key("cgs")
	if entry.is_empty():
		return out
	var cgs := scan_category(entry)
	for c in cgs:
		var cg: CGData = c.resource as CGData
		if cg == null:
			continue
		for i in cg.steps.size():
			var step: CGStep = cg.steps[i]
			if step == null:
				continue
			# FULL_CG モードで cg_image 未設定なら必ず欠損候補。
			# PORTRAIT モードでも image_path_hint があるなら制作予定として拾う。
			var is_full := step.mode == Enums.CGStepMode.FULL_CG
			var has_hint := step.image_path_hint != ""
			var image_missing := step.cg_image == null
			if image_missing and (is_full or has_hint):
				out.append({
					"cg_path": c.path,
					"cg_id": cg.id,
					"op_id": cg.operator_id,
					"step_index": i,
					"mode": step.mode,
					"hint": step.image_path_hint,
				})
	return out


# プロジェクト全 .tres/.tscn から ext_resource の path を拾い、実ファイルが
# 存在しない参照を返す。
# 戻り値: Array[{ file, missing_path, line_hint }]
static func scan_broken_refs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var queue: Array[String] = ["res://"]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		# addons/ と .godot/ はスキャンから除外。
		if current.begins_with("res://.godot") or current.begins_with("res://addons"):
			continue
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.begins_with("."):
				name = dir.get_next()
				continue
			var sub := current.path_join(name)
			if dir.current_is_dir():
				queue.append(sub)
			elif name.ends_with(".tres") or name.ends_with(".tscn"):
				_check_file_refs(sub, out)
			name = dir.get_next()
		dir.list_dir_end()
	return out


static func _check_file_refs(file_path: String, out: Array[Dictionary]) -> void:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	# ext_resource は典型的に `[ext_resource type="Texture2D" path="res://..." id="..."]` 形式。
	var regex := RegEx.new()
	regex.compile('path="(res://[^"]+)"')
	var seen := {}
	while not f.eof_reached():
		var line := f.get_line()
		var matches := regex.search_all(line)
		for m in matches:
			var ref_path: String = m.get_string(1)
			if seen.has(ref_path):
				continue
			seen[ref_path] = true
			if not ResourceLoader.exists(ref_path) and not FileAccess.file_exists(ref_path):
				out.append({
					"file": file_path,
					"missing_path": ref_path,
				})


# 「保存先パス」を一意に決める。規約:
#   res://assets/cg/<operator_id>/<cg_id>/step_<NN>_<basename>.<ext>
# hint があれば basename はそれを採用、無ければ src ファイル名から作る。
static func resolve_cg_save_path(op_id: StringName, cg_id: StringName,
		step_index: int, hint: String, src_name: String) -> String:
	var dir := "%s/%s/%s" % [CG_FOLDER_DEFAULT, op_id, cg_id]
	var base_name := ""
	if hint != "":
		base_name = hint.get_file().get_basename()
	else:
		base_name = src_name.get_basename()
	var ext := src_name.get_extension().to_lower()
	if ext == "":
		ext = "png"
	var step_part := "step_%02d_%s" % [step_index, base_name]
	return "%s/%s.%s" % [dir, step_part, ext]
