extends Node

# .tres マスタデータの一括ロード & idルックアップ。
# 新しいキャラ・アイテム等を追加するときは data/ 以下に .tres を置くだけでよい。

const DATA_ROOT := "res://data"

var operators: Dictionary = {}        # StringName -> OperatorData
var items: Dictionary = {}            # StringName -> ItemData
var costumes: Dictionary = {}         # StringName -> CostumeData
var cgs: Dictionary = {}              # StringName -> CGData
var touch_spots: Dictionary = {}      # StringName -> TouchSpotData
var reactions: Array[ReactionRule] = []
var memories: Dictionary = {}         # StringName -> MemorySceneData
var messages: Array[IncomingMessage] = []
var upgrades: Dictionary = {}         # StringName -> UpgradeData
var scopes: Dictionary = {}           # StringName -> ScopeData
var meta_upgrades: Dictionary = {}    # StringName -> MetaUpgradeData


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	_load_dir("operators", operators, "id")
	_load_dir("items", items, "id")
	_load_dir("costumes", costumes, "id")
	_load_dir("cgs", cgs, "id")
	_load_dir("touch_spots", touch_spots, "id")
	_load_dir("memories", memories, "id")
	_load_dir("upgrades", upgrades, "id")
	_load_dir("scopes", scopes, "id")
	_load_dir("meta_upgrades", meta_upgrades, "id")
	_load_dir_array("reactions", reactions)
	_load_dir_array("messages", messages)


func _load_dir(subdir: String, dict: Dictionary, id_prop: String) -> void:
	var path := "%s/%s" % [DATA_ROOT, subdir]
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [path, file_name])
			if res != null:
				var id_value: Variant = res.get(id_prop)
				if id_value != null and not _is_empty_string_id(id_value):
					dict[id_value] = res
				else:
					push_warning("DataRegistry: %s/%s has empty %s, skipped" % [subdir, file_name, id_prop])
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_dir_array(subdir: String, arr: Array) -> void:
	var path := "%s/%s" % [DATA_ROOT, subdir]
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [path, file_name])
			if res != null:
				arr.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()


static func _is_empty_string_id(v: Variant) -> bool:
	if v is StringName:
		return v == &""
	if v is String:
		return v == ""
	return false


# --- 便利ルックアップ --------------------------------------------------

func get_operator(id: StringName) -> OperatorData:
	return operators.get(id)

func get_item(id: StringName) -> ItemData:
	return items.get(id)

func get_costume(id: StringName) -> CostumeData:
	return costumes.get(id)

func get_cg(id: StringName) -> CGData:
	return cgs.get(id)

func get_touch_spot(id: StringName) -> TouchSpotData:
	return touch_spots.get(id)

func get_memory(id: StringName) -> MemorySceneData:
	return memories.get(id)

func get_upgrade(id: StringName) -> UpgradeData:
	return upgrades.get(id)

func get_scope(id: StringName) -> ScopeData:
	return scopes.get(id)

func get_meta_upgrade(id: StringName) -> MetaUpgradeData:
	return meta_upgrades.get(id)

func get_all_operators() -> Array:
	return operators.values()

func get_items_by_category(cat: int) -> Array:
	var out: Array = []
	for it in items.values():
		if it.category == cat:
			out.append(it)
	return out

func get_touch_spots_for(op_id: StringName) -> Array:
	var out: Array = []
	for ts in touch_spots.values():
		if ts.operator_id == op_id or ts.operator_id == &"":
			out.append(ts)
	return out
