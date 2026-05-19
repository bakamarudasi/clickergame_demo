class_name SaveService
extends Object

# user://save.json を読み書きするだけの薄い静的サービス。
# 状態は持たず、GameState.serialize() / GameState.apply_snapshot() に丸投げ。
# 保存タイミング（quit / 30秒オートセーブ）は main.gd 側で発火する。

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_to_disk() -> bool:
	var snap: Dictionary = GameState.serialize()
	snap["version"] = SAVE_VERSION
	snap["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveService: cannot open save for write (err=%d)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(snap))
	f.close()
	return true


# 失敗時（ファイル無し / 破損 / バージョン不一致）は false を返してデフォルト状態を保つ。
# 破損ケースは push_error を出すが起動自体は止めない。
static func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveService: cannot open save for read (err=%d)" % FileAccess.get_open_error())
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveService: malformed save file (not a dictionary)")
		return false
	var dict: Dictionary = parsed
	var version: int = int(dict.get("version", 0))
	if version != SAVE_VERSION:
		push_warning("SaveService: save version mismatch (file=%d, expected=%d). Loading best-effort." % [version, SAVE_VERSION])
	GameState.apply_snapshot(dict)
	return true


static func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	var d := DirAccess.open("user://")
	if d == null:
		return false
	return d.remove("save.json") == OK
