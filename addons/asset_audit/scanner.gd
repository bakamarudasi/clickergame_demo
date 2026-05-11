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


# Slot ドロップ時の保存先。規約:
#   portrait_idle           : res://assets/operators/<op>/portrait_idle.<ext>
#   portrait_expressions[k] : res://assets/operators/<op>/portrait_expressions/<k>.<ext>
#   portrait_face_overlays[k]: res://assets/operators/<op>/portrait_face_overlays/<k>.<ext>
#   sprite (Costume)        : res://assets/operators/<op>/<costume_id>/sprite.<ext>
#   sprite_pose_seductive   : res://assets/operators/<op>/<costume_id>/sprite_pose_seductive.<ext>
#   sprite_xray_variants[k] : res://assets/operators/<op>/<costume_id>/sprite_xray_<k>.<ext>
static func resolve_slot_save_path(meta: Dictionary, src_name: String) -> String:
	var ext := src_name.get_extension().to_lower()
	if ext == "":
		ext = "png"
	var kind: String = meta.get("kind", "")
	var op_id: StringName = meta.get("op_id", &"")
	var slot_prop: String = meta.get("slot_prop", "")
	var slot_key: String = meta.get("slot_key", "")
	if kind == "portrait_slot":
		if slot_prop == "portrait_idle":
			return "res://assets/operators/%s/portrait_idle.%s" % [op_id, ext]
		return "res://assets/operators/%s/%s/%s.%s" % [op_id, slot_prop, slot_key, ext]
	# costume_slot
	var costume_path: String = meta.get("res_path", "")
	var costume_id: String = costume_path.get_file().get_basename()
	if slot_prop == "sprite_xray_variants":
		return "res://assets/operators/%s/%s/sprite_xray_%s.%s" % [op_id, costume_id, slot_key, ext]
	return "res://assets/operators/%s/%s/%s.%s" % [op_id, costume_id, slot_prop, ext]


# 各データ型の id 参照プロパティが、実在する id を指してるか検証する。
# .tres / Inspector からタイポした時に「実ゲーム起動して落ちる」のを未然に防ぐ。
# 戻り値: Array[{ source_path, source_kind, field, value, expected }]
static func scan_dangling_ids() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Reactions
	var r_entry := AssetAuditCategories.find_by_key("reactions")
	for r in scan_category(r_entry):
		var rule: ReactionRule = r.resource as ReactionRule
		if rule == null:
			continue
		_check_id(out, r.path, "ReactionRule", "operator_id", rule.operator_id, "operators")
		var trigger_expected := ""
		match rule.trigger_kind:
			Enums.TriggerKind.ITEM: trigger_expected = "items"
			Enums.TriggerKind.TOUCH: trigger_expected = "touch_spots"
			_: trigger_expected = ""
		if trigger_expected != "":
			_check_id(out, r.path, "ReactionRule", "trigger_id", rule.trigger_id, trigger_expected)
		for cg_id in rule.requires_cgs:
			_check_id(out, r.path, "ReactionRule", "requires_cgs[]", cg_id, "cgs")
		for mem_id in rule.requires_memories:
			_check_id(out, r.path, "ReactionRule", "requires_memories[]", mem_id, "memories")
		_check_id(out, r.path, "ReactionRule", "requires_equipped_costume",
				rule.requires_equipped_costume, "costumes")
		for i in rule.side_effects.size():
			var eff: ItemEffect = rule.side_effects[i]
			if eff == null:
				continue
			var exp := _expected_for_effect_kind(eff.kind)
			if exp != "":
				_check_id(out, r.path, "ReactionRule", "side_effects[%d].target_id" % i,
						eff.target_id, exp)
	# Items
	var i_entry := AssetAuditCategories.find_by_key("items")
	for it in scan_category(i_entry):
		var item: ItemData = it.resource as ItemData
		if item == null:
			continue
		_check_id(out, it.path, "ItemData", "requires_meta", item.requires_meta, "meta_upgrades")
		for i in item.effects.size():
			var eff: ItemEffect = item.effects[i]
			if eff == null:
				continue
			var exp := _expected_for_effect_kind(eff.kind)
			if exp != "":
				_check_id(out, it.path, "ItemData", "effects[%d].target_id" % i,
						eff.target_id, exp)
	# CGs
	var cg_entry := AssetAuditCategories.find_by_key("cgs")
	for c in scan_category(cg_entry):
		var cg: CGData = c.resource as CGData
		if cg == null:
			continue
		_check_id(out, c.path, "CGData", "operator_id", cg.operator_id, "operators")
		_check_id(out, c.path, "CGData", "trigger_item_id", cg.trigger_item_id, "items")
	# TouchSpots
	var t_entry := AssetAuditCategories.find_by_key("touch_spots")
	for t in scan_category(t_entry):
		var ts: TouchSpotData = t.resource as TouchSpotData
		if ts == null:
			continue
		_check_id(out, t.path, "TouchSpotData", "operator_id", ts.operator_id, "operators")
	# Costumes
	var co_entry := AssetAuditCategories.find_by_key("costumes")
	for co in scan_category(co_entry):
		var cos: CostumeData = co.resource as CostumeData
		if cos == null:
			continue
		_check_id(out, co.path, "CostumeData", "operator_id", cos.operator_id, "operators")
	# Operators
	var op_entry := AssetAuditCategories.find_by_key("operators")
	for o in scan_category(op_entry):
		var op: OperatorData = o.resource as OperatorData
		if op == null:
			continue
		_check_id(out, o.path, "OperatorData", "default_costume_id",
				op.default_costume_id, "costumes")
		for li in op.liked_items:
			_check_id(out, o.path, "OperatorData", "liked_items[]", li, "items")
		for di in op.disliked_items:
			_check_id(out, o.path, "OperatorData", "disliked_items[]", di, "items")
		for si in op.stages.size():
			var stage: TrustStageData = op.stages[si]
			if stage == null:
				continue
			for cu in stage.costume_unlocks:
				_check_id(out, o.path, "OperatorData",
						"stages[%d].costume_unlocks[]" % si, cu, "costumes")
			for cgu in stage.cg_unlocks:
				_check_id(out, o.path, "OperatorData",
						"stages[%d].cg_unlocks[]" % si, cgu, "cgs")
	# Upgrades
	var u_entry := AssetAuditCategories.find_by_key("upgrades")
	for u in scan_category(u_entry):
		var up: UpgradeData = u.resource as UpgradeData
		if up == null:
			continue
		_check_id(out, u.path, "UpgradeData", "requires_meta",
				up.requires_meta, "meta_upgrades")
	return out


static func _check_id(out: Array[Dictionary], source: String, kind: String,
		field: String, value: Variant, expected_category: String) -> void:
	if value == null:
		return
	var is_empty := false
	if value is StringName:
		is_empty = value == &""
	elif value is String:
		is_empty = value == ""
	if is_empty:
		return
	if not AssetAuditIndex.id_exists(value):
		out.append({
			"source_path": source,
			"source_kind": kind,
			"field": field,
			"value": String(value),
			"expected": expected_category,
		})


static func _expected_for_effect_kind(kind: int) -> String:
	match kind:
		Enums.EffectKind.CG_UNLOCK, Enums.EffectKind.CG_PLAY: return "cgs"
		Enums.EffectKind.OPERATOR_UNLOCK: return "operators"
		Enums.EffectKind.COSTUME_UNLOCK: return "costumes"
		Enums.EffectKind.MEMORY_UNLOCK: return "memories"
		Enums.EffectKind.SCOPE_GRANT: return "scopes"
		_: return ""


# ReactionRule.expression / CGStep.expression が Operator のどちらの辞書にも
# 登録されてないキーを列挙する。
# 戻り値: Array[{ source_path, source_kind, op_id, expression_key }]
static func scan_missing_expression_keys() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Operator ごとの登録済みキー集合をキャッシュ
	var op_entry := AssetAuditCategories.find_by_key("operators")
	var op_keys: Dictionary = {}     # op_id -> Set[String]
	for o in scan_category(op_entry):
		var op: OperatorData = o.resource as OperatorData
		if op == null:
			continue
		var keys := {}
		for k in op.portrait_expressions.keys():
			keys[String(k)] = true
		for k in op.portrait_face_overlays.keys():
			keys[String(k)] = true
		op_keys[op.id] = keys
	# Reactions チェック
	var r_entry := AssetAuditCategories.find_by_key("reactions")
	for r in scan_category(r_entry):
		var rule: ReactionRule = r.resource as ReactionRule
		if rule == null or rule.expression == &"":
			continue
		if rule.operator_id == &"":
			continue
		var keys: Dictionary = op_keys.get(rule.operator_id, {})
		if not keys.has(String(rule.expression)):
			out.append({
				"source_path": r.path,
				"source_kind": "ReactionRule",
				"op_id": rule.operator_id,
				"expression_key": String(rule.expression),
			})
	# CGSteps チェック
	var cg_entry := AssetAuditCategories.find_by_key("cgs")
	for c in scan_category(cg_entry):
		var cg: CGData = c.resource as CGData
		if cg == null or cg.operator_id == &"":
			continue
		var keys: Dictionary = op_keys.get(cg.operator_id, {})
		for i in cg.steps.size():
			var step: CGStep = cg.steps[i]
			if step == null or step.expression == &"":
				continue
			if not keys.has(String(step.expression)):
				out.append({
					"source_path": c.path,
					"source_kind": "CGStep #%d (%s)" % [i + 1, cg.id],
					"op_id": cg.operator_id,
					"expression_key": String(step.expression),
				})
	return out
