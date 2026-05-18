@tool
class_name I18nAuditScanner
extends RefCounted

# 翻訳キーの抽出 / CSV 突合せ。Editor-time only.
#
# 抽出対象:
#   - .gd : tr("KEY") / tr(&"KEY") / TranslationServer.translate("KEY")
#   - .tscn / .tres : text = "KEY" の値が SCREAMING_SNAKE_CASE のとき
#                     placeholder_text = "KEY" も同様
#
# CSV: translations/*.csv の 1 列目 keys, 残りカラムが locale 値。

const SCAN_ROOTS := ["res://scripts", "res://scenes", "res://data"]
const TRANSLATIONS_DIR := "res://translations"

# 正規表現は遅延初期化（静的初期化の評価順序リスクを避けるため）。
static var _re_tr: RegEx = null
static var _re_text: RegEx = null
static var _re_key: RegEx = null


static func _get_re_tr() -> RegEx:
	if _re_tr == null:
		_re_tr = RegEx.new()
		# tr("...") / tr(&"...") / TranslationServer.translate("...")
		# シングル/ダブル両対応、StringName プレフィックス & も許容。
		_re_tr.compile("(?:\\btr\\s*\\(|TranslationServer\\.translate\\s*\\()\\s*&?[\"']([A-Z][A-Z0-9_]{2,})[\"']")
	return _re_tr


static func _get_re_text() -> RegEx:
	if _re_text == null:
		_re_text = RegEx.new()
		# Scene/Resource の text = "KEY" / placeholder_text = "KEY"
		_re_text.compile("(?m)^(?:text|placeholder_text)\\s*=\\s*\"([A-Z][A-Z0-9_]{2,})\"\\s*$")
	return _re_text


static func _get_re_key() -> RegEx:
	if _re_key == null:
		_re_key = RegEx.new()
		# キー判定: 先頭英大文字 + 英大文字/数字/_、3 文字以上
		_re_key.compile("^[A-Z][A-Z0-9_]{2,}$")
	return _re_key


# --- 結果型 -----------------------------------------------------------------

class KeyUsage:
	var key: String
	var locations: Array = []  # [{path, line, kind}]


class CsvTable:
	var path: String
	var locales: Array = []           # Array[String]: ["ja","en","zh_CN"]
	var rows: Dictionary = {}         # key -> {locale: value}


class ScanReport:
	var usages: Dictionary = {}              # key -> KeyUsage
	var tables: Array = []                   # Array[CsvTable]
	var defined_keys: Dictionary = {}        # key -> [table_path, ...]
	var missing: Array = []                  # [{key, locale, table_path, usages}]
	var unused: Array = []                   # [{key, table_path}]
	var undefined: Array = []                # [{key, usages}]


# --- 公開 API ---------------------------------------------------------------

static func scan() -> ScanReport:
	var rep := ScanReport.new()
	# regex はここで使う前に必ず初期化される。
	_get_re_tr()
	_get_re_text()
	_get_re_key()
	for root in SCAN_ROOTS:
		_walk_dir(root, rep.usages)
	rep.tables = _load_csv_tables()
	_compute_diff(rep)
	return rep


# --- 走査 -------------------------------------------------------------------

static func _walk_dir(path: String, usages: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_walk_dir(full, usages)
		else:
			_scan_file(full, usages)
		name = dir.get_next()
	dir.list_dir_end()


static func _scan_file(path: String, usages: Dictionary) -> void:
	var ext := path.get_extension().to_lower()
	if ext == "gd":
		_scan_text(path, "gd", _get_re_tr(), usages)
	elif ext == "tscn" or ext == "tres":
		_scan_text(path, "scene", _get_re_text(), usages)


static func _scan_text(path: String, kind: String, regex: RegEx, usages: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var line_no := 0
	while not f.eof_reached():
		line_no += 1
		var line := f.get_line()
		# 行コメント / 文字列リテラルの厳密検査はしない。多少の誤検出より見落とし
		# を減らす方が運用上嬉しいので、緩めに正規表現でマッチさせる。
		# ただし行コメント "#" 以降は捨てる（gd のみ）。
		var probe := line
		if kind == "gd":
			var hash_pos := line.find("#")
			# 文字列内 # は無視できない簡易処理。tr() 抽出には十分。
			if hash_pos >= 0:
				probe = line.substr(0, hash_pos)
		for m in regex.search_all(probe):
			var key := m.get_string(1)
			if not _get_re_key().search(key):
				continue
			var u: KeyUsage = usages.get(key)
			if u == null:
				u = KeyUsage.new()
				u.key = key
				usages[key] = u
			u.locations.append({"path": path, "line": line_no, "kind": kind})


# --- CSV ロード -------------------------------------------------------------

static func _load_csv_tables() -> Array:
	var out: Array = []
	_collect_csv("%s" % TRANSLATIONS_DIR, out)
	return out


static func _collect_csv(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_collect_csv(full, out)
		elif name.ends_with(".csv"):
			var table := _load_csv(full)
			if table != null:
				out.append(table)
		name = dir.get_next()
	dir.list_dir_end()


static func _load_csv(path: String) -> CsvTable:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var t := CsvTable.new()
	t.path = path
	# 先頭行はヘッダ。1 列目は "keys" 想定だが厳密チェックはしない。
	var header := f.get_csv_line()
	if header.size() < 2:
		return null
	for i in range(1, header.size()):
		t.locales.append(header[i])
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.is_empty() or row[0].strip_edges() == "":
			continue
		var key := row[0]
		var values: Dictionary = {}
		for i in range(t.locales.size()):
			var col := i + 1
			values[t.locales[i]] = row[col] if col < row.size() else ""
		t.rows[key] = values
	return t


# --- 差分計算 ---------------------------------------------------------------

static func _compute_diff(rep: ScanReport) -> void:
	# どの CSV にどのキーがあるか逆引き
	for tbl in rep.tables:
		for key in tbl.rows.keys():
			if not rep.defined_keys.has(key):
				rep.defined_keys[key] = []
			rep.defined_keys[key].append(tbl.path)

	# undefined: 使われてるが CSV に無いキー
	for key in rep.usages.keys():
		if not rep.defined_keys.has(key):
			rep.undefined.append({"key": key, "usages": rep.usages[key].locations})

	# missing: CSV に存在するが locale 値が空。
	# 使用箇所のあるキーのみ対象（dialogue_speaker 等の動的キーまで網羅は別パス）。
	for tbl in rep.tables:
		for key in tbl.rows.keys():
			var values: Dictionary = tbl.rows[key]
			for locale in tbl.locales:
				var v: String = values.get(locale, "")
				if v.strip_edges() == "":
					var usages: Array = []
					if rep.usages.has(key):
						usages = (rep.usages[key] as KeyUsage).locations
					rep.missing.append({
						"key": key,
						"locale": locale,
						"table_path": tbl.path,
						"usages": usages,
					})

	# unused: CSV にあるが誰にも参照されていない
	# ※ dialogue_speaker 等は Resource フィールドから来る動的キーなのでここでは検出不可。
	#   strings.csv 系の UI キーが主対象。dialogue CSV は ReactionRule.dialogue から
	#   引かれるので「行コード上の tr()」では捕まらない → unused 集計からは外す。
	for tbl in rep.tables:
		if "dialogues" in tbl.path:
			continue
		for key in tbl.rows.keys():
			if not rep.usages.has(key):
				rep.unused.append({"key": key, "table_path": tbl.path})
