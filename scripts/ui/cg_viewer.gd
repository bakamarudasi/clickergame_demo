extends Control

# 全画面 CG ビューア。EventBus.cg_unlocked を Main で受けて play(cg_data) で開く。
# Step 列を順番に表示し、クリックで次へ進む。最後を超えるか ✕ で閉じる。
# PORTRAIT モード時は CGImage を隠して立ち絵 + 顔差分を表示。
# FULL_CG モード時は立ち絵を隠して CGImage を全画面表示（画像が null なら
# プレースホルダを出す）。
#
# 台詞はタイプライターで一文字ずつ出る。
#  - 表示中にクリック → 即時全表示（スキップ）
#  - 全表示後にクリック → 次ステップへ進行
# RichTextLabel の visible_ratio を Tween で 0→1 に動かす方式。BBCode を保ったまま使える。

@onready var cg_image: TextureRect = %CGImage
@onready var portrait_area: CenterContainer = %PortraitArea
@onready var portrait_view: TextureRect = %PortraitView
@onready var face_overlay: TextureRect = %FaceOverlay
@onready var placeholder_label: Label = %PlaceholderLabel
@onready var dialogue_panel: PanelContainer = %DialoguePanel
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var next_hint: Label = %NextHint
@onready var close_button: Button = %CloseButton
@onready var bgm_player: AudioStreamPlayer = %BGMPlayer
@onready var sfx_player: AudioStreamPlayer = %SfxPlayer

# タイプライター設定。CHARS_PER_SEC は概ね 30-40 が読みやすい。
const TYPEWRITER_CHARS_PER_SEC := 36.0
# 最短表示時間。短すぎる台詞でも「ピョン」と一瞬で消えないように下限を設ける。
const TYPEWRITER_MIN_SEC := 0.12
# NextHint の点滅周期
const HINT_PULSE_SEC := 0.9

var _cg: CGData = null
var _step_index: int = 0
var _typing_tween: Tween
var _hint_tween: Tween
var _is_typing: bool = false
# CG 中だけ BGMService のタブ BGM を退避しておき、閉じる際に復帰する。
# 復帰先が &"" の場合は BGMService.stop() 相当（=何も鳴らさない）。
var _suspended_track: StringName = &""


func _ready() -> void:
	close_button.pressed.connect(close)
	gui_input.connect(_on_gui_input)
	visible = false


# 外部から呼ぶエントリーポイント。
func play(cg: CGData) -> void:
	if cg == null:
		return
	_cg = cg
	_step_index = 0
	visible = true
	# タブ BGM を退避してフェードアウト。CG 自前の BGM が無くても、
	# 二重再生を避けるためタブ BGM は必ず止める。
	_suspended_track = BGMService.current_track()
	BGMService.stop()
	# BGM 設定（あれば再生、無ければ停止）
	if cg.bgm != null:
		bgm_player.stream = cg.bgm
		bgm_player.play()
	else:
		bgm_player.stop()
	# steps が空なら image + caption だけの簡易表示
	if cg.steps.is_empty():
		_show_simple_image_caption()
		return
	_apply_step(_step_index)


func close() -> void:
	_kill_typing()
	_kill_hint()
	visible = false
	bgm_player.stop()
	_cg = null
	_step_index = 0
	# 退避してたタブ BGM を復帰。トラック未差込でも BGMService 側で無音停止扱い。
	if _suspended_track != &"":
		BGMService.play(_suspended_track)
	_suspended_track = &""


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# タイプライター中は完了させるだけ、次ステップには進まない（誤爆防止）
		if _is_typing:
			_complete_typing()
			return
		_advance()


func _advance() -> void:
	if _cg == null:
		return
	if _cg.steps.is_empty():
		# 簡易表示モードはクリックで閉じる
		close()
		return
	_step_index += 1
	if _step_index >= _cg.steps.size():
		close()
		return
	_apply_step(_step_index)


func _apply_step(idx: int) -> void:
	if _cg == null or idx < 0 or idx >= _cg.steps.size():
		return
	var step: CGStep = _cg.steps[idx]
	# モード切替
	if step.mode == Enums.CGStepMode.FULL_CG:
		portrait_area.visible = false
		_apply_full_cg(step)
	else:
		cg_image.visible = false
		placeholder_label.visible = false
		portrait_area.visible = true
		_apply_portrait(step)
	# 台詞：話者は即時、本文はタイプライターで流す
	if step.speaker == "":
		speaker_label.visible = false
	else:
		speaker_label.visible = true
		speaker_label.text = tr(step.speaker)
	_start_typewriter(tr(step.dialogue))
	# SE 1ショット
	if step.sfx != null:
		sfx_player.stream = step.sfx
		sfx_player.play()


# --- タイプライター ------------------------------------------------------

func _start_typewriter(full_text: String) -> void:
	_kill_typing()
	_kill_hint()
	dialogue_text.text = full_text
	# 改行や BBCode タグを除いた純粋な可視文字数をベースに所要時間を出す。
	# RichTextLabel.visible_characters は BBCode を含まない可視文字数で数えるので、
	# get_total_character_count() で文字数を取り、CHARS_PER_SEC で割れば良い。
	var char_count := dialogue_text.get_total_character_count()
	var duration := maxf(TYPEWRITER_MIN_SEC, float(char_count) / TYPEWRITER_CHARS_PER_SEC)
	dialogue_text.visible_ratio = 0.0
	# 文字数が 0（空台詞）の場合はそのまま完了状態へ
	if char_count <= 0:
		dialogue_text.visible_ratio = 1.0
		_on_typing_finished()
		return
	_is_typing = true
	next_hint.modulate.a = 0.0  # 表示中はヒント消す
	_typing_tween = create_tween()
	_typing_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	_typing_tween.finished.connect(_on_typing_finished)


func _complete_typing() -> void:
	if not _is_typing:
		return
	_kill_typing()
	dialogue_text.visible_ratio = 1.0
	_on_typing_finished()


func _on_typing_finished() -> void:
	_is_typing = false
	_start_hint_pulse()


func _kill_typing() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	_typing_tween = null
	_is_typing = false


func _start_hint_pulse() -> void:
	_kill_hint()
	next_hint.modulate.a = 1.0
	_hint_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_tween.tween_property(next_hint, "modulate:a", 0.35, HINT_PULSE_SEC * 0.5)
	_hint_tween.tween_property(next_hint, "modulate:a", 1.0, HINT_PULSE_SEC * 0.5)


func _kill_hint() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
	next_hint.modulate.a = 0.0


func _apply_full_cg(step: CGStep) -> void:
	# step.cg_image が null の時は直前の画像を維持（"" hint も無ければプレースホルダ）。
	if step.cg_image != null:
		cg_image.texture = step.cg_image
		cg_image.visible = true
		placeholder_label.visible = false
	elif cg_image.texture != null:
		cg_image.visible = true
		placeholder_label.visible = false
	else:
		cg_image.visible = false
		if step.image_path_hint != "":
			placeholder_label.text = tr("CG_PLACEHOLDER_NO_IMAGE_HINT_FMT") % step.image_path_hint
		else:
			placeholder_label.text = tr("CG_PLACEHOLDER_NO_IMAGE")
		placeholder_label.visible = true


func _apply_portrait(step: CGStep) -> void:
	if _cg == null:
		return
	var op := DataRegistry.get_operator(_cg.operator_id)
	if op == null:
		portrait_view.texture = null
		face_overlay.visible = false
		return
	var costume := DataRegistry.get_costume(op.default_costume_id)
	portrait_view.texture = costume.sprite if costume != null else null
	# 表情解決：face_overlay 優先、無ければ portrait_expressions の全身差し替え。
	face_overlay.visible = false
	if step.expression != &"":
		if op.portrait_face_overlays.has(step.expression):
			face_overlay.texture = op.portrait_face_overlays[step.expression]
			# 顔位置はコスチューム依存
			if costume != null:
				var rect := costume.face_anchor_rect
				face_overlay.anchor_left = rect.position.x
				face_overlay.anchor_top = rect.position.y
				face_overlay.anchor_right = rect.position.x + rect.size.x
				face_overlay.anchor_bottom = rect.position.y + rect.size.y
				face_overlay.offset_left = 0.0
				face_overlay.offset_top = 0.0
				face_overlay.offset_right = 0.0
				face_overlay.offset_bottom = 0.0
			face_overlay.visible = true
		elif op.portrait_expressions.has(step.expression):
			portrait_view.texture = op.portrait_expressions[step.expression]


func _show_simple_image_caption() -> void:
	# 後方互換：steps が空の旧 CG は image + caption をそのまま全画面表示。
	portrait_area.visible = false
	if _cg.image != null:
		cg_image.texture = _cg.image
		cg_image.visible = true
		placeholder_label.visible = false
	else:
		cg_image.visible = false
		placeholder_label.text = tr("CG_PLACEHOLDER_NO_IMAGE")
		placeholder_label.visible = true
	speaker_label.visible = false
	_start_typewriter(tr(_cg.caption))
