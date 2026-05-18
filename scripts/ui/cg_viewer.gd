extends Control

# 全画面 CG ビューア。EventBus.cg_unlocked を Main で受けて play(cg_data) で開く。
# Step 列を順番に表示し、クリックで次へ進む。最後を超えるか ✕ で閉じる。
# PORTRAIT モード時は CGImage を隠して立ち絵 + 顔差分を表示。
# FULL_CG モード時は立ち絵を隠して CGImage を全画面表示（画像が null なら
# プレースホルダ "(画像未登録: hint)" を出す）。

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

var _cg: CGData = null
var _step_index: int = 0


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
	visible = false
	bgm_player.stop()
	_cg = null
	_step_index = 0


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
	# 台詞
	if step.speaker == "":
		speaker_label.visible = false
	else:
		speaker_label.visible = true
		speaker_label.text = tr(step.speaker)
	dialogue_text.text = tr(step.dialogue)
	# SE 1ショット
	if step.sfx != null:
		sfx_player.stream = step.sfx
		sfx_player.play()


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
	dialogue_text.text = tr(_cg.caption)
