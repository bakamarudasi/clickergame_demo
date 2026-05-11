@tool
class_name AssetAuditCategories
extends RefCounted

# Browse / Audit / New で扱うコンテンツの一覧表。
# 新しいデータクラスを足す時はここに 1 行追加すれば自動で反映される。
#
# 各エントリ:
#   key          : DataRegistry のフィールド名（命名規約上ここをそのままフォルダ名に使う）
#   label        : Dock に表示するラベル
#   folder       : res://data/ 直下のサブディレクトリ
#   storage      : "dict" = id 必須・dict 格納 / "array" = id 不要・配列格納
#   class_name_  : Godot の class_name（new() でインスタンス作る時に使う）
#   id_prefix    : 新規 .tres 作成時の id / ファイル名プリフィクス
#   has_cg_steps : CGStep 配列を持つか（CG だけ true）

const ENTRIES: Array[Dictionary] = [
	{
		"key": "operators",
		"label": "Operators",
		"folder": "operators",
		"storage": "dict",
		"class_name_": "OperatorData",
		"id_prefix": "op",
		"has_cg_steps": false,
	},
	{
		"key": "items",
		"label": "Items",
		"folder": "items",
		"storage": "dict",
		"class_name_": "ItemData",
		"id_prefix": "item",
		"has_cg_steps": false,
	},
	{
		"key": "costumes",
		"label": "Costumes",
		"folder": "costumes",
		"storage": "dict",
		"class_name_": "CostumeData",
		"id_prefix": "costume",
		"has_cg_steps": false,
	},
	{
		"key": "cgs",
		"label": "CGs",
		"folder": "cgs",
		"storage": "dict",
		"class_name_": "CGData",
		"id_prefix": "cg",
		"has_cg_steps": true,
	},
	{
		"key": "touch_spots",
		"label": "Touch Spots",
		"folder": "touch_spots",
		"storage": "dict",
		"class_name_": "TouchSpotData",
		"id_prefix": "touch",
		"has_cg_steps": false,
	},
	{
		"key": "reactions",
		"label": "Reactions",
		"folder": "reactions",
		"storage": "array",
		"class_name_": "ReactionRule",
		"id_prefix": "reaction",
		"has_cg_steps": false,
	},
	{
		"key": "upgrades",
		"label": "Upgrades",
		"folder": "upgrades",
		"storage": "dict",
		"class_name_": "UpgradeData",
		"id_prefix": "upgrade",
		"has_cg_steps": false,
	},
	{
		"key": "scopes",
		"label": "Scopes",
		"folder": "scopes",
		"storage": "dict",
		"class_name_": "ScopeData",
		"id_prefix": "scope",
		"has_cg_steps": false,
	},
	{
		"key": "memories",
		"label": "Memories",
		"folder": "memories",
		"storage": "dict",
		"class_name_": "MemorySceneData",
		"id_prefix": "memory",
		"has_cg_steps": false,
	},
	{
		"key": "meta_upgrades",
		"label": "Meta Upgrades",
		"folder": "meta_upgrades",
		"storage": "dict",
		"class_name_": "MetaUpgradeData",
		"id_prefix": "meta",
		"has_cg_steps": false,
	},
	{
		"key": "messages",
		"label": "Messages",
		"folder": "messages",
		"storage": "array",
		"class_name_": "IncomingMessage",
		"id_prefix": "msg",
		"has_cg_steps": false,
	},
]


# class_name から実体クラスを引いて Resource.new() する。
# @tool スクリプトから動的に Resource サブクラスを new するには ClassDB か
# load(script_path).new() のどちらかが必要。class_name で登録されてれば
# ClassDB.instantiate(class_name) で取れる。
static func instantiate(cls_name: String) -> Resource:
	if ClassDB.class_exists(cls_name):
		var obj: Object = ClassDB.instantiate(cls_name)
		if obj is Resource:
			return obj as Resource
	# class_name 登録されてないケースのフォールバック: スクリプトを直接 load
	var script_path := _guess_script_path(cls_name)
	if script_path != "" and ResourceLoader.exists(script_path):
		var script: Script = load(script_path)
		var inst: Variant = script.new()
		if inst is Resource:
			return inst as Resource
	push_warning("AssetAuditCategories: cannot instantiate %s" % cls_name)
	return null


static func _guess_script_path(cls_name: String) -> String:
	# OperatorData -> scripts/data/operator_data.gd の規約
	var snake := ""
	for i in cls_name.length():
		var c := cls_name[i]
		if c == c.to_upper() and c != c.to_lower() and i > 0:
			snake += "_"
		snake += c.to_lower()
	return "res://scripts/data/%s.gd" % snake


static func find_by_key(key: String) -> Dictionary:
	for e in ENTRIES:
		if e.key == key:
			return e
	return {}
