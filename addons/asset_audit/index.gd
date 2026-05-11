@tool
class_name AssetAuditIndex
extends RefCounted

# プロジェクト全体の id ⇄ 参照箇所マップを構築する。
# - 逆引き検索（このリソースを使ってる .tres / .tscn 一覧）
# - ID 整合性チェック（参照してる id が定義済みか）
# - 依存グラフ（id をノード、参照をエッジ）
# - ダッシュボード（オペレータ別のコンテンツ集計）
#
# 参照は data/*/*.tres を走査して各リソースの "id" プロパティを集め、
# 全 .tres / .tscn のテキスト中から &"id_token" パターンを引いて突き合わせる。
# YARD (elliotfontaine/yard-godot) 系のレジストリ方式と同じく、対象ファイルを
# 全部 load せず、テキスト走査で済ませる。
#
# キャッシュは EditorFileSystem.filesystem_changed をフックして無効化する。

# id (String) -> Array[{ path: String, category: String }]
static var _known_ids: Dictionary = {}
# id (String) -> Array[{ source_path: String }]
static var _references: Dictionary = {}
# id (String) -> source_path that defines it（_known_ids の単一エントリ用ヘルパ）
static var _build_state: int = 0  # 0=未構築, 1=構築済


# 走査対象（addons / .godot は除外）
const _SCAN_ROOTS := ["res://data", "res://scenes", "res://scripts"]


static func ensure_built() -> void:
	if _build_state == 1:
		return
	rebuild()


static func rebuild() -> void:
	_known_ids.clear()
	_references.clear()
	_scan_known_ids()
	_scan_references()
	_build_state = 1


static func invalidate() -> void:
	_build_state = 0


# ---- 公開 API -----------------------------------------------------------

# 指定 id を参照しているファイル一覧（定義元自身は除外）。
static func references_of(id: Variant) -> Array:
	ensure_built()
	var key := _norm(id)
	var defining_paths := {}
	for d in _known_ids.get(key, []):
		defining_paths[d.path] = true
	var out: Array = []
	for r in _references.get(key, []):
		if not defining_paths.has(r.source_path):
			out.append(r)
	return out


# id を定義してるファイル（通常 1 件）
static func defined_in(id: Variant) -> Array:
	ensure_built()
	return _known_ids.get(_norm(id), [])


static func id_exists(id: Variant) -> bool:
	ensure_built()
	if id == null:
		return false
	var key := _norm(id)
	if key == "":
		return false
	return _known_ids.has(key)


# 全 known id の一覧。category でフィルタ可。
static func all_ids(category_filter: String = "") -> Array:
	ensure_built()
	var out: Array = []
	for k in _known_ids.keys():
		if category_filter == "":
			out.append(k)
		else:
			for d in _known_ids[k]:
				if d.category == category_filter:
					out.append(k)
					break
	return out


# ---- 内部実装 -----------------------------------------------------------

static func _norm(id: Variant) -> String:
	if id is StringName:
		return String(id)
	if id is String:
		return id
	return str(id)


static func _is_empty(id: Variant) -> bool:
	if id is StringName:
		return id == &""
	if id is String:
		return id == ""
	return id == null


static func _scan_known_ids() -> void:
	for entry in AssetAuditCategories.ENTRIES:
		var dir_path := "res://data/%s" % entry.folder
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".tres"):
				var path := "%s/%s" % [dir_path, name]
				var res: Resource = load(path)
				if res != null:
					var id_value: Variant = null
					if res.get("id") != null:
						id_value = res.get("id")
					if id_value != null and not _is_empty(id_value):
						var key := _norm(id_value)
						if not _known_ids.has(key):
							_known_ids[key] = []
						_known_ids[key].append({
							"path": path,
							"category": entry.key,
						})
			name = dir.get_next()
		dir.list_dir_end()


static func _scan_references() -> void:
	var regex := RegEx.new()
	# StringName リテラル: &"foo_bar" 形式。Godot の .tres で id を表す
	# 標準シリアライズなのでこれだけ追えば property 値の id 参照は拾える。
	regex.compile('&"([A-Za-z_][A-Za-z0-9_]*)"')
	for root in _SCAN_ROOTS:
		_walk_and_scan(root, regex)


static func _walk_and_scan(root: String, regex: RegEx) -> void:
	var queue: Array[String] = [root]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		if current.begins_with("res://addons") or current.begins_with("res://.godot"):
			continue
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not name.begins_with("."):
				var sub := current.path_join(name)
				if dir.current_is_dir():
					queue.append(sub)
				elif name.ends_with(".tres") or name.ends_with(".tscn"):
					_scan_file(sub, regex)
			name = dir.get_next()
		dir.list_dir_end()


static func _scan_file(file_path: String, regex: RegEx) -> void:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	var matches := regex.search_all(text)
	var seen := {}
	for m in matches:
		var token: String = m.get_string(1)
		if seen.has(token):
			continue
		# known id でない literal はノイズなので無視。
		if not _known_ids.has(token):
			continue
		seen[token] = true
		if not _references.has(token):
			_references[token] = []
		_references[token].append({"source_path": file_path})


# ---- 翻訳キー -----------------------------------------------------------
# Translation.get_message_list() は GDScript に非公開（Issue #38862）なので、
# 翻訳ソース（.csv / .po）を自前パースして key セットを作る。
# locale -> Dictionary[key -> translated_text]
# locale="" は全 locale を union した key セットだけ持つ（値は ""）。
static var _translation_keys: Dictionary = {}
static var _translation_built: bool = false

const _TRANSLATION_ROOT := "res://translations"


static func ensure_translations_built() -> void:
	if _translation_built:
		return
	rebuild_translations()


static func rebuild_translations() -> void:
	_translation_keys.clear()
	if not DirAccess.dir_exists_absolute(_TRANSLATION_ROOT):
		_translation_built = true
		return
	# translations/ 以下の .csv / .po を全部走査。
	_walk_translations(_TRANSLATION_ROOT)
	_translation_built = true


static func translation_keys(locale: String = "") -> Dictionary:
	ensure_translations_built()
	if locale == "":
		var merged := {}
		for keys: Dictionary in _translation_keys.values():
			for k in keys.keys():
				merged[k] = true
		return merged
	return _translation_keys.get(locale, {})


static func translation_has_key(key: String, locale: String = "") -> bool:
	return translation_keys(locale).has(key)


static func translation_lookup(key: String, locale: String = "") -> String:
	# プレビュー表示用。指定 locale → 任意 locale → key 自身 の順でフォールバック。
	ensure_translations_built()
	if locale != "" and _translation_keys.has(locale):
		var d: Dictionary = _translation_keys[locale]
		if d.has(key) and typeof(d[key]) == TYPE_STRING:
			return d[key]
	for d_any: Dictionary in _translation_keys.values():
		if d_any.has(key) and typeof(d_any[key]) == TYPE_STRING:
			return d_any[key]
	return key


static func _walk_translations(root: String) -> void:
	var queue: Array[String] = [root]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not name.begins_with("."):
				var sub := current.path_join(name)
				if dir.current_is_dir():
					queue.append(sub)
				elif name.ends_with(".csv"):
					_load_csv_keys(sub)
				elif name.ends_with(".po"):
					_load_po_keys(sub)
			name = dir.get_next()
		dir.list_dir_end()


static func _load_csv_keys(csv_path: String) -> void:
	# 1 行目: 「keys,ja,en,zh_CN」みたいな header。Godot CSV translation の規約。
	var f := FileAccess.open(csv_path, FileAccess.READ)
	if f == null:
		return
	var header := f.get_csv_line()
	if header.size() < 2:
		return
	# locale 列のインデックスを記録。先頭の "keys" 列はスキップ。
	var locales: Array[String] = []
	for i in range(1, header.size()):
		locales.append(header[i])
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2:
			continue
		var key := row[0]
		if key == "":
			continue
		for i in locales.size():
			var col := i + 1
			if col >= row.size():
				continue
			var locale := locales[i]
			var d: Dictionary = _translation_keys.get(locale, {})
			d[key] = row[col]
			_translation_keys[locale] = d


static func _load_po_keys(po_path: String) -> void:
	# fallback: .po がもしあれば msgid を拾う（このプロジェクトは現状 csv のみ）。
	var f := FileAccess.open(po_path, FileAccess.READ)
	if f == null:
		return
	var locale := _locale_from_po_filename(po_path)
	var d: Dictionary = _translation_keys.get(locale, {})
	var msgid_re := RegEx.new()
	msgid_re.compile('^msgid\\s+"(.*)"\\s*$')
	while not f.eof_reached():
		var line := f.get_line()
		var m := msgid_re.search(line)
		if m == null:
			continue
		var key := m.get_string(1)
		if key != "":
			d[key] = key  # 値は使わないので key 自身を入れておく
	_translation_keys[locale] = d


static func _locale_from_po_filename(po_path: String) -> String:
	var base := po_path.get_file().get_basename()
	var dot := base.rfind(".")
	if dot == -1:
		return ""
	return base.substr(dot + 1)
