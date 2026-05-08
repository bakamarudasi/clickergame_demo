extends Control

# Roomタブ。オペ選択 → ギフト/タッチ/メッセージ/メモリー操作を担当。
# 他タブを直接参照しない。GiftService / TouchService 経由でのみ状態を変える。
# 立ち絵は (1) 反応時に rule.expression を一定時間表示、
# (2) 発情度に応じて modulate に桜色 tint をかける、の二重制御。

const MAX_DIALOGUE_ENTRIES := 10
const EXPRESSION_FLASH_SEC := 2.5
const AROUSAL_TINT_COLOR := Color(1.0, 0.85, 0.88)   # 発情MAX時に乗せる桜色
const AROUSAL_TINT_BLEND_MAX := 0.3                   # 桜色をブレンドする最大比率
const INTIMACY_BAR_DISPLAY_MAX := 200                 # 親密度バーの目盛上限（実値はラベルで表示）

@onready var operator_list: VBoxContainer = %OperatorList
@onready var detail_panel: Control = %DetailPanel
@onready var op_name_label: Label = %OpNameLabel
@onready var trust_label: Label = %TrustLabel
@onready var stage_label: Label = %StageLabel
@onready var intimacy_label: Label = %IntimacyLabel
@onready var intimacy_bar: ProgressBar = %IntimacyBar
@onready var arousal_label: Label = %ArousalLabel
@onready var arousal_bar: ProgressBar = %ArousalBar
@onready var gift_select: OptionButton = %GiftSelect
@onready var give_button: Button = %GiveButton
@onready var touch_list: VBoxContainer = %TouchList
@onready var inspection_button: Button = %InspectionButton
@onready var portrait_view: TextureRect = %PortraitView
@onready var face_overlay: TextureRect = %FaceOverlay
@onready var scope_toggle: Button = %ScopeToggle
@onready var battery_bar: ProgressBar = %BatteryBar
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var scope_row: HBoxContainer = %ScopeRow
@onready var dialogue_scroll: ScrollContainer = %DialogueScroll
@onready var dialogue_log: VBoxContainer = %DialogueLog

var _current_op: StringName = &""
var _pose_show_until_unix: float = 0.0
var _expression_show_until_unix: float = 0.0
var _active_expression: StringName = &""
var _portrait_scene_node: Node = null
var _portrait_scene_path: String = ""
var _idle_last_interaction_unix: float = 0.0
var _idle_stage_fired: int = 0


func _ready() -> void:
	EventBus.operator_unlocked.connect(_on_operator_unlocked)
	EventBus.trust_changed.connect(_on_trust_changed)
	EventBus.intimacy_changed.connect(_on_intimacy_changed)
	EventBus.arousal_changed.connect(_on_arousal_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.reaction_played.connect(_on_reaction_played)
	EventBus.operator_locked.connect(_on_operator_locked)
	EventBus.inspection_performed.connect(_on_inspection_performed)
	EventBus.xray_changed.connect(_on_xray_changed)
	EventBus.scope_battery_changed.connect(_on_scope_battery_changed)
	EventBus.scope_equipped.connect(_on_scope_equipped)
	EventBus.xray_suspicion_changed.connect(_on_xray_suspicion_changed)
	EventBus.xray_caught.connect(_on_xray_caught)
	EventBus.costume_equipped.connect(_on_costume_equipped)
	give_button.pressed.connect(_on_give_pressed)
	inspection_button.pressed.connect(_on_inspection_pressed)
	scope_toggle.toggled.connect(_on_scope_toggled)
	visibility_changed.connect(_on_self_visibility_changed)
	set_process(true)

	_rebuild_operator_list()
	detail_panel.visible = false
	_refresh_scope_ui()
	_refresh_battery_ui()
	_reset_idle_timer()


func _rebuild_operator_list() -> void:
	for child in operator_list.get_children():
		child.queue_free()
	for op_id: StringName in GameState.unlocked_operators:
		var op := DataRegistry.get_operator(op_id)
		if op == null:
			continue
		var b := Button.new()
		b.text = op.display_name
		b.pressed.connect(_select_operator.bind(op_id))
		operator_list.add_child(b)


func _select_operator(op_id: StringName) -> void:
	_current_op = op_id
	_active_expression = &""
	_expression_show_until_unix = 0.0
	_clear_dialogue_log()
	detail_panel.visible = true
	_refresh_detail()
	_rebuild_gift_select()
	_rebuild_touch_list()
	_refresh_inspection_button()
	_refresh_portrait()
	_refresh_suspicion_ui()
	_consume_prestige_greet(op_id)


# プレステージ完了後の最初の選択時に PRESTIGE 反応を 1 度だけ流す。
func _consume_prestige_greet(op_id: StringName) -> void:
	var rt := GameState.get_runtime(op_id)
	if rt == null or not rt.pending_prestige_greet:
		return
	rt.pending_prestige_greet = false
	var rule := ReactionResolver.resolve(
		Enums.TriggerKind.PRESTIGE,
		&"",
		op_id,
		rt.trust,
		1,
		-1
	)
	if rule != null:
		ReactionResolver.apply_side_effects(rule, op_id)
		EventBus.reaction_played.emit(op_id, rule)


# --- アイドルフレーバー ---------------------------------------------------
# Room タブ操作なしで一定時間経つと、IDLE 反応を段階的に発火する。
# 各段階の trigger_id は &"stage_1" / &"stage_2" / &"stage_3" / &"fire"。
# fire 段階では click_power に一時バフを乗せる（狙撃カウントダウンの「演出」役）。

func _on_self_visibility_changed() -> void:
	if visible:
		_reset_idle_timer()


func _reset_idle_timer() -> void:
	_idle_last_interaction_unix = Time.get_unix_time_from_system()
	_idle_stage_fired = 0


func _check_idle() -> void:
	if _current_op == &"":
		return
	if GameState.is_operator_locked(_current_op):
		return
	var elapsed := Time.get_unix_time_from_system() - _idle_last_interaction_unix
	if elapsed >= UIConstants.IDLE_FIRE_SEC and _idle_stage_fired < 4:
		_idle_stage_fired = 4
		_fire_idle(&"fire")
		GameState.apply_click_buff(UIConstants.IDLE_BUFF_MULT, UIConstants.IDLE_BUFF_DURATION_SEC)
		EventBus.toast_requested.emit(
			tr("TOAST_IDLE_BUFF_FMT") % [int(UIConstants.IDLE_BUFF_MULT), int(UIConstants.IDLE_BUFF_DURATION_SEC)]
		)
		_reset_idle_timer()
	elif elapsed >= UIConstants.IDLE_STAGE_3_SEC and _idle_stage_fired < 3:
		_idle_stage_fired = 3
		_fire_idle(&"stage_3")
	elif elapsed >= UIConstants.IDLE_STAGE_2_SEC and _idle_stage_fired < 2:
		_idle_stage_fired = 2
		_fire_idle(&"stage_2")
	elif elapsed >= UIConstants.IDLE_STAGE_1_SEC and _idle_stage_fired < 1:
		_idle_stage_fired = 1
		_fire_idle(&"stage_1")


func _fire_idle(stage: StringName) -> void:
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		return
	var rule := ReactionResolver.resolve(
		Enums.TriggerKind.IDLE,
		stage,
		_current_op,
		rt.trust,
		1,
		-1
	)
	if rule != null:
		ReactionResolver.apply_side_effects(rule, _current_op)
		EventBus.reaction_played.emit(_current_op, rule)


func _process(delta: float) -> void:
	if not visible:
		return
	if GameState.xray_active and _current_op != &"":
		ScopeService.tick(delta, _current_op)
	if _current_op == &"":
		return
	if not InspectionService.can_inspect(_current_op):
		_refresh_inspection_button()
	_check_idle()
	var now := Time.get_unix_time_from_system()
	if _pose_show_until_unix > 0.0 and now >= _pose_show_until_unix:
		_pose_show_until_unix = 0.0
		_refresh_portrait()
	if _expression_show_until_unix > 0.0 and now >= _expression_show_until_unix:
		_expression_show_until_unix = 0.0
		_active_expression = &""
		_refresh_portrait()


func _refresh_inspection_button() -> void:
	if _current_op == &"":
		inspection_button.disabled = true
		inspection_button.text = TranslationServer.translate("ROOM_INSPECTION_BUTTON")
		return
	var remaining := InspectionService.cooldown_remaining_sec(_current_op)
	if remaining <= 0.0:
		inspection_button.disabled = false
		inspection_button.text = TranslationServer.translate("ROOM_INSPECTION_BUTTON")
	else:
		inspection_button.disabled = true
		inspection_button.text = TranslationServer.translate("ROOM_INSPECTION_COOLDOWN_FMT") % int(ceil(remaining))


func _on_inspection_pressed() -> void:
	if _current_op == &"":
		return
	InspectionService.inspect(_current_op)


func _on_inspection_performed(op_id: StringName) -> void:
	if op_id == _current_op:
		_refresh_inspection_button()


func _refresh_detail() -> void:
	if _current_op == &"":
		return
	var op := DataRegistry.get_operator(_current_op)
	var rt := GameState.get_runtime(_current_op)
	if op == null or rt == null:
		return
	op_name_label.text = tr(op.display_name)
	trust_label.text = tr("ROOM_TRUST_FMT") % rt.trust
	var stage_title := ""
	for s in op.stages:
		if s.stage_index == rt.current_stage:
			stage_title = tr(s.title)
			break
	stage_label.text = tr("ROOM_STAGE_FMT") % [rt.current_stage, stage_title]
	_refresh_gauges()


func _refresh_gauges() -> void:
	if _current_op == &"":
		intimacy_label.text = ""
		arousal_label.text = ""
		intimacy_bar.value = 0.0
		arousal_bar.value = 0.0
		return
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		return
	intimacy_label.text = tr("STATUS_INTIMACY_FMT") % rt.intimacy
	intimacy_bar.value = clampf(float(rt.intimacy), 0.0, float(INTIMACY_BAR_DISPLAY_MAX))
	var a := GameState.get_arousal(_current_op)
	arousal_label.text = tr("STATUS_AROUSAL_FMT") % int(a)
	arousal_bar.value = clampf(a, 0.0, UIConstants.AROUSAL_MAX)


func _rebuild_gift_select() -> void:
	gift_select.clear()
	var idx := 0
	for it: ItemData in DataRegistry.items.values():
		if not it.is_consumable:
			continue
		var n := GameState.item_count(it.id)
		if n <= 0:
			continue
		gift_select.add_item(tr("ROOM_GIFT_INV_FMT") % [tr(it.display_name), n], idx)
		gift_select.set_item_metadata(idx, it.id)
		idx += 1


func _rebuild_touch_list() -> void:
	for child in touch_list.get_children():
		child.queue_free()
	if _current_op == &"":
		return
	var rt := GameState.get_runtime(_current_op)
	for spot: TouchSpotData in DataRegistry.get_touch_spots_for(_current_op):
		var b := Button.new()
		var prefix := "⚠ " if spot.is_harassment else ""
		b.text = "%s%s" % [prefix, tr(spot.display_name)]
		b.disabled = rt == null or rt.current_stage < spot.unlock_at_stage
		b.pressed.connect(TouchService.touch.bind(_current_op, spot.id))
		touch_list.add_child(b)


func _on_give_pressed() -> void:
	if _current_op == &"":
		return
	var sel := gift_select.get_selected_id()
	if sel < 0:
		return
	var item_id: StringName = gift_select.get_item_metadata(sel)
	GiftService.give(_current_op, item_id)


func _on_operator_unlocked(_op_id: StringName) -> void:
	_rebuild_operator_list()


func _on_trust_changed(op_id: StringName, _trust: int, _stage: int) -> void:
	if op_id == _current_op:
		_refresh_detail()
		_rebuild_touch_list()


func _on_intimacy_changed(op_id: StringName, _v: int) -> void:
	if op_id == _current_op:
		_refresh_gauges()


func _on_arousal_changed(op_id: StringName, _v: float) -> void:
	if op_id == _current_op:
		_refresh_gauges()
		_apply_arousal_tint()
		if _portrait_scene_node != null:
			_dispatch_portrait_scene_state()


func _on_inventory_changed(_id: StringName, _n: int) -> void:
	_rebuild_gift_select()


func _on_reaction_played(op_id: StringName, rule: ReactionRule) -> void:
	if op_id != _current_op:
		return
	_append_dialogue(tr("ROOM_REACTION_FMT") % [tr(rule.pick_dialogue()), rule.trust_delta])
	_flash_expression(rule.expression)
	# IDLE 反応は「アイドル経過の結果」なのでタイマーをリセットしない
	# （リセットすると stage_1 → 待機 → stage_1 のループになる）。
	# それ以外の反応＝ユーザーの能動的なアクションなのでタイマーを巻き戻す。
	if rule.trigger_kind != Enums.TriggerKind.IDLE:
		_reset_idle_timer()


func _on_operator_locked(op_id: StringName, until_unix: float) -> void:
	if op_id == _current_op:
		var sec := int(until_unix - Time.get_unix_time_from_system())
		_append_dialogue(tr("ROOM_LOCK_FMT") % max(0, sec))


# --- 会話ログ ------------------------------------------------------------

func _clear_dialogue_log() -> void:
	for child in dialogue_log.get_children():
		child.queue_free()


func _append_dialogue(text: String) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.text = text
	dialogue_log.add_child(l)
	while dialogue_log.get_child_count() > MAX_DIALOGUE_ENTRIES:
		dialogue_log.get_child(0).queue_free()
	_scroll_dialogue_to_bottom()


func _scroll_dialogue_to_bottom() -> void:
	# scroll bar の max は次フレームで反映されるので待つ
	await get_tree().process_frame
	if not is_instance_valid(dialogue_scroll):
		return
	var bar := dialogue_scroll.get_v_scroll_bar()
	if bar != null:
		dialogue_scroll.scroll_vertical = int(bar.max_value)


# --- 立ち絵表示 ----------------------------------------------------------

func _refresh_portrait() -> void:
	if _current_op == &"":
		portrait_view.texture = null
		portrait_view.modulate = Color.WHITE
		face_overlay.visible = false
		_clear_portrait_scene()
		return
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		portrait_view.texture = null
		face_overlay.visible = false
		_clear_portrait_scene()
		return
	var costume := DataRegistry.get_costume(rt.equipped_costume)
	if costume == null:
		portrait_view.texture = null
		face_overlay.visible = false
		_clear_portrait_scene()
		return
	# シーン方式（Spine / Live2D / AnimationPlayer 等）が指定されてればそちらを優先。
	# シーンルート側で表情・ポーズ・xray・arousal を全部捌くので、静的 PNG 系の
	# 表示は止める。
	if costume.portrait_scene != null:
		_ensure_portrait_scene(costume.portrait_scene)
		portrait_view.visible = false
		face_overlay.visible = false
		_dispatch_portrait_scene_state()
		return
	_clear_portrait_scene()
	portrait_view.visible = true
	# 表情フラッシュ中はそれを最優先。顔差分（layered）→ 全身差し替え（full swap）の順に解決。
	if _expression_show_until_unix > Time.get_unix_time_from_system() and _active_expression != &"":
		var face_tex := _face_overlay_texture(_active_expression)
		if face_tex != null:
			# 顔レイヤー方式：体は通常 sprite を出して、顔だけ重ねる
			portrait_view.texture = costume.sprite
			face_overlay.texture = face_tex
			_position_face_overlay(costume)
			face_overlay.visible = true
			_apply_arousal_tint()
			return
		var flash_tex := _expression_texture(_active_expression)
		if flash_tex != null:
			# 全差し替え方式
			portrait_view.texture = flash_tex
			face_overlay.visible = false
			_apply_arousal_tint()
			return
	# フラッシュ無し（または該当テクスチャ無し）→ 顔オーバレイは隠す
	face_overlay.visible = false
	if _pose_show_until_unix > Time.get_unix_time_from_system():
		portrait_view.texture = costume.sprite_pose_seductive if costume.sprite_pose_seductive != null else costume.sprite
	elif GameState.xray_active:
		portrait_view.texture = costume.get_xray_sprite(ScopeService.current_view_kind())
	else:
		portrait_view.texture = costume.sprite
	_apply_arousal_tint()


func _flash_expression(expr: StringName) -> void:
	if expr == &"" or _current_op == &"":
		return
	# 顔差分・全身差し替えのどちらか一方でも登録されてたら起動。
	if _face_overlay_texture(expr) == null and _expression_texture(expr) == null:
		# データ未整備でも黙って素通り（既存挙動を壊さない）
		return
	_active_expression = expr
	_expression_show_until_unix = Time.get_unix_time_from_system() + EXPRESSION_FLASH_SEC
	_refresh_portrait()


func _expression_texture(expr: StringName) -> Texture2D:
	if expr == &"" or _current_op == &"":
		return null
	var op := DataRegistry.get_operator(_current_op)
	if op == null or not op.portrait_expressions.has(expr):
		return null
	return op.portrait_expressions[expr]


func _face_overlay_texture(expr: StringName) -> Texture2D:
	if expr == &"" or _current_op == &"":
		return null
	var op := DataRegistry.get_operator(_current_op)
	if op == null or not op.portrait_face_overlays.has(expr):
		return null
	return op.portrait_face_overlays[expr]


# face_overlay は portrait_view の子で、anchor を costume.face_anchor_rect の
# 正規化座標に合わせて貼付け位置を決める。コスチューム差し替えに自動追従する。
func _position_face_overlay(costume: CostumeData) -> void:
	if costume == null:
		return
	var rect := costume.face_anchor_rect
	face_overlay.anchor_left = rect.position.x
	face_overlay.anchor_top = rect.position.y
	face_overlay.anchor_right = rect.position.x + rect.size.x
	face_overlay.anchor_bottom = rect.position.y + rect.size.y
	face_overlay.offset_left = 0.0
	face_overlay.offset_top = 0.0
	face_overlay.offset_right = 0.0
	face_overlay.offset_bottom = 0.0


# --- シーン方式の立ち絵（Spine / Live2D / AnimationPlayer 等の差し替え枠）-------

# costume.portrait_scene が指定されてる時に呼ぶ。既に同じシーンが乗ってれば
# インスタンスを使い回し、違う場合は古いのを free して新規 instantiate。
func _ensure_portrait_scene(scene: PackedScene) -> void:
	var path := scene.resource_path
	if _portrait_scene_node != null and _portrait_scene_path == path:
		return
	_clear_portrait_scene()
	_portrait_scene_node = scene.instantiate()
	# PortraitView の親（PortraitArea）にぶら下げる。PortraitArea が
	# CenterContainer なのでサイズは中央で自動配置される。
	var holder := portrait_view.get_parent()
	holder.add_child(_portrait_scene_node)
	_portrait_scene_path = path


func _clear_portrait_scene() -> void:
	if _portrait_scene_node != null:
		_portrait_scene_node.queue_free()
		_portrait_scene_node = null
		_portrait_scene_path = ""


# シーンルートに状態を投げる。実装されてないメソッドは黙ってスキップ。
func _dispatch_portrait_scene_state() -> void:
	var n := _portrait_scene_node
	if n == null:
		return
	var now := Time.get_unix_time_from_system()
	# 表情：フラッシュ中なら _active_expression、無ければ idle 相当の空文字
	var expr: StringName = _active_expression if _expression_show_until_unix > now else &""
	if n.has_method(&"play_expression"):
		n.call(&"play_expression", expr)
	# ポーズ：高信頼の見せつけ中は seductive、それ以外は idle
	var pose: StringName = &"seductive" if _pose_show_until_unix > now else &"idle"
	if n.has_method(&"play_pose"):
		n.call(&"play_pose", pose)
	# 紳士眼鏡：ON 中は view_kind を流す、OFF なら空文字
	var view_kind: StringName = ScopeService.current_view_kind() if GameState.xray_active else &""
	if n.has_method(&"set_xray_view"):
		n.call(&"set_xray_view", view_kind)
	# 発情度：0..1 正規化値を渡す。tint 演出はシーン側に任せる
	var t := clampf(GameState.get_arousal(_current_op) / UIConstants.AROUSAL_MAX, 0.0, 1.0)
	if n.has_method(&"set_arousal"):
		n.call(&"set_arousal", t)


# 発情度に応じた modulate tint を立ち絵に適用する。
# arousal=0 → 真っ白、arousal=AROUSAL_MAX → AROUSAL_TINT_COLOR を AROUSAL_TINT_BLEND_MAX 比率でブレンド。
func _apply_arousal_tint() -> void:
	if _current_op == &"":
		portrait_view.modulate = Color.WHITE
		return
	var t := clampf(GameState.get_arousal(_current_op) / UIConstants.AROUSAL_MAX, 0.0, 1.0)
	portrait_view.modulate = Color.WHITE.lerp(AROUSAL_TINT_COLOR, t * AROUSAL_TINT_BLEND_MAX)


func _on_costume_equipped(op_id: StringName, _costume_id: StringName) -> void:
	if op_id == _current_op:
		_refresh_portrait()


# --- 紳士眼鏡 UI ---------------------------------------------------------

func _refresh_scope_ui() -> void:
	var has_scope := ScopeService.equipped() != null
	scope_row.visible = has_scope
	suspicion_bar.visible = has_scope
	scope_toggle.set_pressed_no_signal(GameState.xray_active)


func _refresh_battery_ui() -> void:
	var s := ScopeService.equipped()
	if s == null:
		battery_bar.value = 0.0
		return
	battery_bar.value = clamp(GameState.scope_battery_seconds / s.battery_max_sec, 0.0, 1.0)


func _refresh_suspicion_ui() -> void:
	if _current_op == &"":
		suspicion_bar.value = 0.0
		return
	var rt := GameState.get_runtime(_current_op)
	if rt == null:
		suspicion_bar.value = 0.0
		return
	suspicion_bar.value = clamp(rt.xray_suspicion / UIConstants.XRAY_SUSPICION_THRESHOLD, 0.0, 1.0)


func _on_scope_toggled(_pressed: bool) -> void:
	ScopeService.toggle(_current_op)
	_reset_idle_timer()


func _on_xray_changed(_active: bool) -> void:
	scope_toggle.set_pressed_no_signal(GameState.xray_active)
	_refresh_portrait()


func _on_scope_battery_changed(_v: float) -> void:
	_refresh_battery_ui()


func _on_scope_equipped(_id: StringName) -> void:
	_refresh_scope_ui()
	_refresh_battery_ui()


func _on_xray_suspicion_changed(op_id: StringName, _v: float) -> void:
	if op_id == _current_op:
		_refresh_suspicion_ui()


func _on_xray_caught(op_id: StringName) -> void:
	if op_id != _current_op:
		return
	var rt := GameState.get_runtime(op_id)
	if rt != null and rt.trust > 0:
		_pose_show_until_unix = Time.get_unix_time_from_system() + UIConstants.XRAY_POSE_SHOW_SEC
	_refresh_portrait()
	_refresh_suspicion_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild_operator_list()
		_refresh_detail()
		_rebuild_gift_select()
		_rebuild_touch_list()
		_refresh_inspection_button()
		_refresh_scope_ui()
