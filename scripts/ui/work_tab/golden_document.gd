class_name GoldenDocument
extends RefCounted

# Work タブのランダム出現ボーナス書類「ゴールデン書類」を管理する。
# 一定間隔で画面端から書類が登場し、横断する間にクリックされたら
# 大きめのボーナス通貨を付与する。タブが非表示なら出現は見送る。

const GOLDEN_TEXTURE := preload("res://assets/paperwork.svg")

var _host: Control
var _timer: Timer
var _active_node: TextureButton = null


func _init(host: Control) -> void:
	_host = host
	_timer = Timer.new()
	_timer.one_shot = true
	_host.add_child(_timer)
	_timer.timeout.connect(_spawn)
	_restart_timer()


func _restart_timer() -> void:
	_timer.wait_time = randf_range(
		UIConstants.GOLDEN_INTERVAL_MIN_SEC,
		UIConstants.GOLDEN_INTERVAL_MAX_SEC
	)
	_timer.start()


func _spawn() -> void:
	# Workタブが画面に出てない時はスポーンを見送って次の時刻を引き直す
	if not _host.is_visible_in_tree():
		_restart_timer()
		return
	if _active_node != null and is_instance_valid(_active_node):
		_restart_timer()
		return
	var btn := TextureButton.new()
	btn.texture_normal = GOLDEN_TEXTURE
	btn.modulate = UIConstants.GOLDEN_TINT_COLOR
	btn.ignore_texture_size = true
	btn.stretch_mode = 5
	var sz := UIConstants.GOLDEN_SIZE_PX
	btn.custom_minimum_size = Vector2(sz, sz)
	btn.size = Vector2(sz, sz)
	# WorkTab の中で適当な高さのランダム位置に出す
	var w := _host.size.x
	var h := _host.size.y
	var y := randf_range(h * 0.2, h * 0.7)
	btn.position = Vector2(-sz, y)
	btn.z_index = 50
	_host.add_child(btn)
	_active_node = btn
	btn.pressed.connect(_on_clicked.bind(btn))
	# 横断アニメ + ゆっくり回転で目立たせる
	var dur := UIConstants.GOLDEN_LIFETIME_SEC
	var tw := _host.create_tween().set_parallel(true)
	tw.tween_property(btn, "position:x", w + sz, dur)
	tw.tween_property(btn, "rotation", deg_to_rad(20.0), dur)
	tw.chain().tween_callback(func() -> void: _expire(btn))


func _on_clicked(btn: TextureButton) -> void:
	if not is_instance_valid(btn):
		return
	var bonus := UIConstants.GOLDEN_BONUS_FLOOR
	bonus = max(bonus, GameState.effective_click_power() * UIConstants.GOLDEN_BONUS_PER_CLICK)
	bonus = max(bonus, int(float(GameState.currency) * UIConstants.GOLDEN_BONUS_PCT_OF_PILE))
	GameState.add_currency(bonus)
	EventBus.toast_requested.emit(TranslationServer.translate("TOAST_GOLDEN_BONUS") % FormatUtils.short(bonus))
	_expire(btn)


func _expire(btn: TextureButton) -> void:
	if is_instance_valid(btn):
		btn.queue_free()
	_active_node = null
	_restart_timer()
