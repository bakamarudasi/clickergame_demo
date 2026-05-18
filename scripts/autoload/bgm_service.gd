extends Node

# グローバル BGM プレイヤー兼音量管理。
#
# 役割:
#  - タブ別 / シーン別の BGM をクロスフェードで切り替える唯一の入口
#  - Master / BGM / SFX / UI バスの音量を一括管理して user:// に永続化
#  - 未登録 ID / 未差し込みのトラックは黙って無音にする（音源未提供でも壊れない）
#
# 音源未提供の現状でも本サービスは初期化される。`set_track_stream(id, stream)` で
# 後から差し込めば即時反映される。実機投入はデータ層で .tres にぶら下げる想定。
#
# 注意:
#  - AudioStreamPlayer を直接持つので、本ノードはツリーに add_child で
#    プレイヤーを生やす（autoload なので Engine が SceneTree に置く）。
#  - クロスフェードは「鳴ってる側を下げつつ新側を上げる」を 1 本の Tween で。
#    既存 Tween は kill() してから新規 Tween を作る。

const SETTINGS_PATH := "user://audio_settings.cfg"
const SETTINGS_SECTION := "audio"

# 音量の保存範囲（dB）。スライダーは 0..1 で受け取り linear→db 変換する。
const MIN_DB := -60.0
const MAX_DB := 6.0
# クロスフェード既定秒数
const DEFAULT_FADE_SEC := 0.8

# バス名（AudioBusLayout と一致させる）
const BUS_MASTER := &"Master"
const BUS_BGM := &"BGM"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

signal volume_changed(bus_name: StringName, linear: float)
signal mute_changed(bus_name: StringName, muted: bool)
signal track_changed(track_id: StringName)


# 既知トラック ID → AudioStream の登録テーブル。
# 「未差し込み」状態で null を入れておくことで、play(id) しても安全に無音になる。
var _tracks: Dictionary[StringName, AudioStream] = {
	&"work": null,
	&"room": null,
	&"shop": null,
	&"meta": null,
	&"prestige": null,
	&"xray_caught": null,
}

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
# 現在「主」になっているプレイヤー。クロスフェード時に裏側へ新音源を仕込み、
# tween 完了で _active を切り替える。
var _active: AudioStreamPlayer
var _fade_tween: Tween
var _current_track: StringName = &""


func _ready() -> void:
	# autoload はシーンルートの直下に置かれるので、ここから add_child で OK。
	_player_a = _make_player()
	_player_b = _make_player()
	add_child(_player_a)
	add_child(_player_b)
	_active = _player_a
	_load_settings()


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS_BGM
	p.autoplay = false
	p.volume_db = MIN_DB  # 出力ゲートはバス側で制御するので、こっちは最初無音に
	return p


# --- 公開 API：再生 ----------------------------------------------------------

# 登録済みトラック ID で切替。未登録 / null は何もしない（停止もしない）。
# 連続で同じ id を投げても再開しない（曲が途中で巻き戻るのを防ぐ）。
func play(track_id: StringName, fade_sec: float = DEFAULT_FADE_SEC) -> void:
	if track_id == _current_track:
		return
	var stream: AudioStream = _tracks.get(track_id, null)
	if stream == null:
		# 未差し込み。今鳴ってる曲をそのまま流し続ける選択肢もあるが、
		# 「タブ毎に明示的に切替えたい」のが主用途なので、stop に倒す。
		_fade_to(null)
		_current_track = track_id
		track_changed.emit(track_id)
		return
	_fade_to(stream, fade_sec)
	_current_track = track_id
	track_changed.emit(track_id)


# 任意の AudioStream で再生（一時 BGM 用。track_id 管理外）。
func play_stream(stream: AudioStream, fade_sec: float = DEFAULT_FADE_SEC) -> void:
	_current_track = &""
	_fade_to(stream, fade_sec)


func stop(fade_sec: float = DEFAULT_FADE_SEC) -> void:
	_current_track = &""
	_fade_to(null, fade_sec)


func current_track() -> StringName:
	return _current_track


# 後からトラックを差し込む / 上書きする。テスト用 / アセット用意完了時の差し替え用。
func set_track_stream(track_id: StringName, stream: AudioStream) -> void:
	_tracks[track_id] = stream
	# 既に該当 ID 再生中なら、その場で stream を当てて再生し直す。
	if _current_track == track_id and stream != null:
		_active.stream = stream
		_active.play()


# --- 公開 API：音量 ----------------------------------------------------------

# linear 0.0〜1.0 を受け取る。内部で dB に変換してバスに適用。
# 0 のときはミュートと等価にするため、AudioServer 側の volume_db は MIN_DB に。
func set_bus_volume_linear(bus_name: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var db: float = MIN_DB if linear <= 0.001 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, clampf(db, MIN_DB, MAX_DB))
	_save_settings()
	volume_changed.emit(bus_name, linear)


func get_bus_volume_linear(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	var db := AudioServer.get_bus_volume_db(idx)
	if db <= MIN_DB + 0.01:
		return 0.0
	return db_to_linear(db)


func set_bus_muted(bus_name: StringName, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)
	_save_settings()
	mute_changed.emit(bus_name, muted)


func is_bus_muted(bus_name: StringName) -> bool:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return false
	return AudioServer.is_bus_mute(idx)


# --- 内部：クロスフェード ------------------------------------------------------

# 「鳴ってる側を下げて、裏側に新音源を載せて上げる」を 1 本の Tween で並列処理。
# stream == null の場合は片側フェードアウトだけ（=停止）。
func _fade_to(stream: AudioStream, fade_sec: float = DEFAULT_FADE_SEC) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var outgoing := _active
	var incoming := _player_b if _active == _player_a else _player_a

	if stream == null:
		# 停止：フェードアウトだけ
		_fade_tween = create_tween()
		_fade_tween.tween_property(outgoing, "volume_db", MIN_DB, fade_sec).set_trans(Tween.TRANS_LINEAR)
		_fade_tween.tween_callback(outgoing.stop)
		return

	# 新音源を裏側プレイヤーに仕込む
	incoming.stream = stream
	incoming.volume_db = MIN_DB
	incoming.play()

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(outgoing, "volume_db", MIN_DB, fade_sec).set_trans(Tween.TRANS_LINEAR)
	_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_sec).set_trans(Tween.TRANS_LINEAR)
	_fade_tween.chain().tween_callback(outgoing.stop)
	_active = incoming


# --- 永続化 ------------------------------------------------------------------

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in [BUS_MASTER, BUS_BGM, BUS_SFX, BUS_UI]:
		cfg.set_value(SETTINGS_SECTION, "%s_linear" % bus, get_bus_volume_linear(bus))
		cfg.set_value(SETTINGS_SECTION, "%s_muted" % bus, is_bus_muted(bus))
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	for bus in [BUS_MASTER, BUS_BGM, BUS_SFX, BUS_UI]:
		var linear: float = cfg.get_value(SETTINGS_SECTION, "%s_linear" % bus, -1.0)
		if linear >= 0.0:
			set_bus_volume_linear(bus, linear)
		var muted: bool = cfg.get_value(SETTINGS_SECTION, "%s_muted" % bus, false)
		if muted:
			set_bus_muted(bus, true)
