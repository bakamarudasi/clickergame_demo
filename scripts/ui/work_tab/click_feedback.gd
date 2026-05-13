class_name ClickFeedback
extends RefCounted

# Work タブの書類クリック演出。スカッシュ・点滅・+N ポップアップ・紙吹雪・
# スタンプの各エフェクトを 1 つの play() でまとめて再生する。
# WorkTab 本体からは「演出をやって」とだけ言えば良いように責務を切り分ける。

const PARTICLE_PAPER := preload("res://assets/ui/particle_paper.svg")
const PARTICLE_INK := preload("res://assets/ui/particle_ink.svg")
const STAMP_APPROVED := preload("res://assets/ui/stamp_approved.svg")

const PARTICLE_COUNT := 7
const PARTICLE_SPEED_MIN := 140.0
const PARTICLE_SPEED_MAX := 280.0
const PARTICLE_LIFETIME := 0.65
const PARTICLE_SIZE := 24.0
const PARTICLE_GRAVITY := Vector2(0, 320.0)
const STAMP_CHANCE := 0.18
const STAMP_SIZE := 180.0
const STAMP_LIFETIME := 0.45
# クリック瞬間に書類を「白っぽく光らせる」ハイライト色（modulate に乗せる）。
# r/g/b すべて 1.0 超え → ピーク輝度を一瞬上げてフラッシュ感を出す。
const FLASH_COLOR := Color(1.3, 1.3, 1.3, 1.0)
const FLASH_FADE_SEC := 0.12
# スタンプの「叩きつけ」アニメの各タイミング。
const STAMP_HIT_SCALE_SEC := 0.10
const STAMP_HIT_FADE_IN_SEC := 0.06
const STAMP_HOLD_BEFORE_FADE_SEC := 0.18

var _host: Control
var _document: TextureButton
var _click_tween: Tween


func _init(host: Control, document_button: TextureButton) -> void:
	_host = host
	_document = document_button


# 1 クリック分の演出を全部走らせる。gained は +N ポップアップに表示する数値。
func play(gained: int) -> void:
	var origin := _click_origin_local()
	_animate_squash()
	_flash_document()
	_spawn_popup(gained)
	_spawn_particles(origin)
	if randf() < STAMP_CHANCE:
		_spawn_stamp(origin)


# 押下位置を WorkTab ローカル座標で返す。マウスが範囲外（タッチ等）なら中心を使う。
func _click_origin_local() -> Vector2:
	var rect := _document.get_global_rect()
	var click_global := _document.get_global_mouse_position()
	if not rect.has_point(click_global):
		click_global = rect.get_center()
	return click_global - _host.global_position


func _animate_squash() -> void:
	if _click_tween != null and _click_tween.is_valid():
		_click_tween.kill()
	_document.pivot_offset = _document.size / 2.0
	_document.scale = Vector2.ONE
	var dur := UIConstants.PORTRAIT_CLICK_DURATION
	var squashed := Vector2.ONE * (1.0 - UIConstants.PORTRAIT_CLICK_SQUASH)
	var wiggle := deg_to_rad(randf_range(-UIConstants.CLICK_WIGGLE_DEG, UIConstants.CLICK_WIGGLE_DEG))
	_click_tween = _host.create_tween().set_parallel(true)
	_click_tween.tween_property(_document, "scale", squashed, dur)
	_click_tween.chain().tween_property(_document, "scale", Vector2.ONE, dur)
	_click_tween.tween_property(_document, "rotation", wiggle, dur)
	_click_tween.chain().tween_property(_document, "rotation", 0.0, dur * 1.5)


func _flash_document() -> void:
	# クリックの瞬間に書類を一瞬白くする → 押した感触
	var tw := _host.create_tween()
	_document.modulate = FLASH_COLOR
	tw.tween_property(_document, "modulate", Color(1, 1, 1, 1), FLASH_FADE_SEC)


func _spawn_popup(amount: int) -> void:
	if amount <= 0:
		return
	var popup := Label.new()
	popup.text = "+%s" % FormatUtils.short(amount)
	popup.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	popup.modulate = UIConstants.COLOR_ACCENT
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100
	_host.add_child(popup)
	var btn_rect := _document.get_global_rect()
	var local_origin := btn_rect.position - _host.global_position
	var jitter := Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 10.0))
	var start_pos := local_origin + Vector2(btn_rect.size.x * 0.5, btn_rect.size.y * 0.35) + jitter
	popup.position = start_pos
	popup.pivot_offset = popup.size * 0.5
	var end_pos := start_pos + Vector2(0, -UIConstants.CLICK_POPUP_RISE_PX)
	var dur := UIConstants.CLICK_POPUP_DURATION
	var tw := _host.create_tween().set_parallel(true)
	tw.tween_property(popup, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(popup, "scale", Vector2(1.25, 1.25), dur * 0.3).from(Vector2.ONE)
	tw.chain().tween_callback(popup.queue_free)


func _spawn_particles(origin: Vector2) -> void:
	for i in PARTICLE_COUNT:
		var tex: Texture2D = PARTICLE_PAPER if (i % 2 == 0) else PARTICLE_INK
		var p := TextureRect.new()
		p.texture = tex
		p.custom_minimum_size = Vector2(PARTICLE_SIZE, PARTICLE_SIZE)
		p.size = Vector2(PARTICLE_SIZE, PARTICLE_SIZE)
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 90
		p.pivot_offset = Vector2(PARTICLE_SIZE, PARTICLE_SIZE) * 0.5
		p.position = origin - p.pivot_offset
		_host.add_child(p)
		var angle := randf() * TAU
		var speed := randf_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		var dur := PARTICLE_LIFETIME * randf_range(0.85, 1.15)
		var end_pos := p.position + velocity * dur + PARTICLE_GRAVITY * dur * dur * 0.5
		var end_rot := deg_to_rad(randf_range(-360.0, 360.0))
		var tw := _host.create_tween().set_parallel(true)
		tw.tween_property(p, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", end_rot, dur)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "scale", Vector2(0.6, 0.6), dur)
		tw.chain().tween_callback(p.queue_free)


func _spawn_stamp(origin: Vector2) -> void:
	var stamp := TextureRect.new()
	stamp.texture = STAMP_APPROVED
	stamp.custom_minimum_size = Vector2(STAMP_SIZE, STAMP_SIZE)
	stamp.size = Vector2(STAMP_SIZE, STAMP_SIZE)
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 95
	stamp.pivot_offset = Vector2(STAMP_SIZE, STAMP_SIZE) * 0.5
	stamp.position = origin - stamp.pivot_offset
	stamp.scale = Vector2(2.4, 2.4)
	stamp.modulate = Color(1, 1, 1, 0)
	stamp.rotation = deg_to_rad(randf_range(-14.0, 14.0))
	_host.add_child(stamp)
	var tw := _host.create_tween().set_parallel(true)
	# スタンプ叩きつけ：大きく出てキュッと縮む + 不透明度立ち上げ
	tw.tween_property(stamp, "scale", Vector2.ONE, STAMP_HIT_SCALE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "modulate:a", 1.0, STAMP_HIT_FADE_IN_SEC)
	# 一拍置いてフェードアウト
	tw.chain().tween_property(stamp, "modulate:a", 0.0, STAMP_LIFETIME).set_delay(STAMP_HOLD_BEFORE_FADE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(stamp.queue_free)
