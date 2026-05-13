class_name PortraitController
extends RefCounted

# Room タブの立ち絵まわり一切。具体的には：
#  - body スプライト切替（costume.sprite / op.portrait_idle / pose / 全身差分）
#  - 表情フラッシュ（顔オーバレイ方式 / 全身差し替え方式）
#  - 紳士眼鏡の窓表示・モザイク・逆紳士枠（base / overlay の役割反転）
#  - 発情度に応じた modulate tint
#  - シーン方式（Spine / Live2D / AnimationPlayer 等）の差し込み
#
# RoomTab からは「現在オペを差し替え／表情を一瞬出す／立ち絵を再描画」だけ依頼する。

const EXPRESSION_FLASH_SEC := 2.5
const AROUSAL_TINT_COLOR := Color(1.0, 0.85, 0.88)   # 発情MAX時に乗せる桜色
const AROUSAL_TINT_BLEND_MAX := 0.3                   # 桜色をブレンドする最大比率

# resolution_level -> モザイクブロックサイズ [px]。
# 1=ガビ、2=粗、3+=素通し。スコープを買い替えると差が出る軸。
const SCOPE_MOSAIC_BLOCK_BY_LEVEL := {
		1: 24.0,
		2: 8.0,
	}
const SCOPE_MOSAIC_SHADER := preload("res://assets/shaders/scope_mosaic.gdshader")

var _portrait_view: TextureRect
var _face_overlay: TextureRect
var _scope_window: ScopeWindow

var _current_op: StringName = &""
var _active_expression: StringName = &""
var _expression_show_until_unix: float = 0.0
var _pose_show_until_unix: float = 0.0

var _scope_mosaic_mat: ShaderMaterial = null
var _portrait_scene_node: Node = null
var _portrait_scene_path: String = ""


func _init(portrait_view: TextureRect, face_overlay: TextureRect, scope_window: ScopeWindow) -> void:
	_portrait_view = portrait_view
	_face_overlay = face_overlay
	_scope_window = scope_window


# 現在オペを切り替える。表情フラッシュ等の一時状態はクリアする。
func set_operator(op_id: StringName) -> void:
	_current_op = op_id
	_active_expression = &""
	_expression_show_until_unix = 0.0
	_pose_show_until_unix = 0.0
	refresh()


# 高信頼での xray バレ時に「見せつけポーズ」を一定時間表示する。
func show_seductive_pose(duration_sec: float) -> void:
	_pose_show_until_unix = Time.get_unix_time_from_system() + duration_sec
	refresh()


# 反応 rule.expression のフラッシュ表示を起動する。テクスチャが未登録なら黙って素通り。
func flash_expression(expr: StringName) -> void:
	if expr == &"" or _current_op == &"":
		return
	if _face_overlay_texture(expr) == null and _expression_texture(expr) == null:
		return
	_active_expression = expr
	_expression_show_until_unix = Time.get_unix_time_from_system() + EXPRESSION_FLASH_SEC
	refresh()


# _process から毎フレ呼ぶ。pose / expression のタイムアウトを処理して必要なら再描画する。
func tick() -> void:
	var now := Time.get_unix_time_from_system()
	var dirty := false
	if _pose_show_until_unix > 0.0 and now >= _pose_show_until_unix:
		_pose_show_until_unix = 0.0
		dirty = true
	if _expression_show_until_unix > 0.0 and now >= _expression_show_until_unix:
		_expression_show_until_unix = 0.0
		_active_expression = &""
		dirty = true
	if dirty:
		refresh()


# 発情度変化時に呼ぶ。tint だけならこちらの軽い経路で済ませる。
func on_arousal_changed() -> void:
	apply_arousal_tint()
	if _portrait_scene_node != null:
		_dispatch_scene_state()


# 発情度に応じた modulate tint を立ち絵に適用する。
# arousal=0 → 真っ白、arousal=AROUSAL_MAX → AROUSAL_TINT_COLOR を AROUSAL_TINT_BLEND_MAX 比率でブレンド。
func apply_arousal_tint() -> void:
	if _current_op == &"":
		_portrait_view.modulate = Color.WHITE
		return
	var t := clampf(GameState.get_arousal(_current_op) / UIConstants.AROUSAL_MAX, 0.0, 1.0)
	_portrait_view.modulate = Color.WHITE.lerp(AROUSAL_TINT_COLOR, t * AROUSAL_TINT_BLEND_MAX)


# 立ち絵全体を再描画。set_operator / flash_expression / xray変化 / costume変化 等で呼ぶ。
func refresh() -> void:
	if _current_op == &"":
		_portrait_view.texture = null
		_portrait_view.modulate = Color.WHITE
		_face_overlay.visible = false
		_clear_scope_visuals()
		_clear_scene()
		return
	var op := DataRegistry.get_operator(_current_op)
	var rt := GameState.get_runtime(_current_op)
	if op == null or rt == null:
		_portrait_view.texture = null
		_face_overlay.visible = false
		_clear_scope_visuals()
		_clear_scene()
		return
	var costume := DataRegistry.get_costume(rt.equipped_costume)
	# シーン方式（Spine / Live2D / AnimationPlayer 等）が指定されてればそちらを優先。
	# シーンルート側で表情・ポーズ・xray・arousal を全部捌くので、静的 PNG 系の
	# 表示は止める。
	if costume != null and costume.portrait_scene != null:
		_ensure_scene(costume.portrait_scene)
		_portrait_view.visible = false
		_face_overlay.visible = false
		_clear_scope_visuals()
		_dispatch_scene_state()
		return
	_clear_scene()
	_portrait_view.visible = true
	# 体スプライト：costume.sprite が最優先、未設定なら op.portrait_idle にフォールバック。
	# 衣装を一切組まずに portrait_idle だけ差した運用でも立ち絵が出る。
	var base_sprite: Texture2D = costume.sprite if costume != null and costume.sprite != null else op.portrait_idle
	# 表情フラッシュ中はそれを最優先。顔差分（layered）→ 全身差し替え（full swap）の順に解決。
	if _expression_show_until_unix > Time.get_unix_time_from_system() and _active_expression != &"":
		var face_tex := _face_overlay_texture(_active_expression)
		if face_tex != null:
			# 顔レイヤー方式：体は通常 sprite を出して、顔だけ重ねる
			_portrait_view.texture = base_sprite
			_face_overlay.texture = face_tex
			if costume != null:
				_position_face_overlay(costume)
			_face_overlay.visible = true
			apply_arousal_tint()
			_refresh_scope_window(costume, base_sprite)
			return
		var flash_tex := _expression_texture(_active_expression)
		if flash_tex != null:
			# 全差し替え方式
			_portrait_view.texture = flash_tex
			_face_overlay.visible = false
			apply_arousal_tint()
			_refresh_scope_window(costume, flash_tex)
			return
	# フラッシュ無し（または該当テクスチャ無し）→ 顔オーバレイは隠す
	_face_overlay.visible = false
	if _pose_show_until_unix > Time.get_unix_time_from_system() and costume != null:
		_portrait_view.texture = costume.sprite_pose_seductive if costume.sprite_pose_seductive != null else base_sprite
	else:
		# 紳士枠は ON でも全身は通常スプライトのまま。窓の中だけ差分を見せる。
		_portrait_view.texture = base_sprite
	apply_arousal_tint()
	_refresh_scope_window(costume, _portrait_view.texture)


# --- 紳士眼鏡（スコープ窓）---------------------------------------------

# 装備中スコープの設定にしたがって、PortraitView の上に動かせる窓を貼る。
# base / overlay の組合せ:
#   通常モード (is_inverse=false): base=通常服, window 内=xray 差分
#   逆紳士枠   (is_inverse=true ): base=xray 差分, window 内=通常服
# 全身のテクスチャは呼び出し側で _portrait_view.texture に積んでもらった body_tex を信頼する。
func _refresh_scope_window(costume: CostumeData, body_tex: Texture2D) -> void:
	if not GameState.xray_active or costume == null or body_tex == null:
		_clear_scope_visuals()
		return
	var scope := ScopeService.equipped()
	if scope == null:
		_clear_scope_visuals()
		return
	var xray_tex := costume.get_xray_sprite(scope.view_kind)
	# xray 差分が未登録 → 切替表示しても何も変わらないので枠を出さない
	if xray_tex == null or xray_tex == body_tex:
		_clear_scope_visuals()
		return
	# 逆モードのときは「全身を xray」「窓を通常服」に役割を反転
	var overlay_tex: Texture2D = xray_tex
	if scope.is_inverse:
		_portrait_view.texture = xray_tex
		overlay_tex = body_tex
	# 初回 ON 時は max サイズで中央寄せ、以降はプレイヤーが動かした位置・縮めたサイズを維持
	if not _scope_window.visible:
		_scope_window.size = scope.max_window_size
		_scope_window.center_in_parent()
	# スコープ買い替えで max が変わった場合に縮める（拡大はしない、プレイヤーが意図的に縮めた可能性があるので）
	_scope_window.set_max_size(scope.max_window_size)
	_scope_window.visible = true
	_scope_window.set_overlay(overlay_tex, _portrait_view.size)
	_apply_scope_resolution(scope)


# スコープ非装備／OFF などで枠が出ない時の状態リセット。
# xray 用に焼いたマテリアルを portrait_view に残したままにしないこと。
func _clear_scope_visuals() -> void:
	_scope_window.visible = false
	_portrait_view.material = null
	_scope_window.set_overlay_material(null)


# resolution_level [1..] -> モザイクブロックサイズ。1未満なら素通し（マテリアル外す）。
# マテリアルは「xray を映してる側」だけに乗せる：
#   通常モード   : overlay 側が xray なので overlay にだけ noise
#   逆紳士枠     : portrait_view 側が xray なので portrait_view にだけ noise
# 反対側は素通しにして「鮮明な通常服」を担保する（紳士枠の世界観）。
func _apply_scope_resolution(scope: ScopeData) -> void:
	var block: float = SCOPE_MOSAIC_BLOCK_BY_LEVEL.get(scope.resolution_level, 1.0)
	if block <= 1.0:
		_portrait_view.material = null
		_scope_window.set_overlay_material(null)
		return
	if _scope_mosaic_mat == null:
		_scope_mosaic_mat = ShaderMaterial.new()
		_scope_mosaic_mat.shader = SCOPE_MOSAIC_SHADER
	_scope_mosaic_mat.set_shader_parameter("block_size", block)
	if scope.is_inverse:
		_portrait_view.material = _scope_mosaic_mat
		_scope_window.set_overlay_material(null)
	else:
		_portrait_view.material = null
		_scope_window.set_overlay_material(_scope_mosaic_mat)


# --- テクスチャ参照 -----------------------------------------------------

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
	var rect := costume.face_anchor_rect
	_face_overlay.anchor_left = rect.position.x
	_face_overlay.anchor_top = rect.position.y
	_face_overlay.anchor_right = rect.position.x + rect.size.x
	_face_overlay.anchor_bottom = rect.position.y + rect.size.y
	_face_overlay.offset_left = 0.0
	_face_overlay.offset_top = 0.0
	_face_overlay.offset_right = 0.0
	_face_overlay.offset_bottom = 0.0


# --- シーン方式の立ち絵 -------------------------------------------------

# costume.portrait_scene が指定されてる時に呼ぶ。既に同じシーンが乗ってれば
# インスタンスを使い回し、違う場合は古いのを free して新規 instantiate。
func _ensure_scene(scene: PackedScene) -> void:
	var path := scene.resource_path
	if _portrait_scene_node != null and _portrait_scene_path == path:
		return
	_clear_scene()
	_portrait_scene_node = scene.instantiate()
	# PortraitView の親（PortraitArea）にぶら下げる。PortraitArea は clip_contents 付きの
	# Control なので、子は anchors で自分でサイズを取りに行く必要がある。
	# ルートが Control 系ならフルレクトに引き伸ばす。それ以外は元の挙動に任せる。
	var holder := _portrait_view.get_parent()
	holder.add_child(_portrait_scene_node)
	if _portrait_scene_node is Control:
		var c: Control = _portrait_scene_node
		c.anchor_left = 0.0
		c.anchor_top = 0.0
		c.anchor_right = 1.0
		c.anchor_bottom = 1.0
		c.offset_left = 0.0
		c.offset_top = 0.0
		c.offset_right = 0.0
		c.offset_bottom = 0.0
	_portrait_scene_path = path


func _clear_scene() -> void:
	if _portrait_scene_node != null:
		_portrait_scene_node.queue_free()
		_portrait_scene_node = null
		_portrait_scene_path = ""


# シーンルートに状態を投げる。実装されてないメソッドは黙ってスキップ。
func _dispatch_scene_state() -> void:
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
