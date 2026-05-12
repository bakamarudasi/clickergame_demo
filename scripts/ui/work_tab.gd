extends Control

# Workタブ。クリックでの通貨生成と強化購入のみを担当。
# 他タブを直接参照しない。EconomyService 経由でのみ状態を変える。

const GOLDEN_TEXTURE := preload("res://assets/paperwork.svg")
const ICON_CLICK := preload("res://assets/ui/icon_click.svg")
const ICON_AUTO := preload("res://assets/ui/icon_auto.svg")
const ICON_MULT := preload("res://assets/ui/icon_mult.svg")
const STAMP_APPROVED := preload("res://assets/ui/stamp_approved.svg")
const PARTICLE_PAPER := preload("res://assets/ui/particle_paper.svg")
const PARTICLE_INK := preload("res://assets/ui/particle_ink.svg")
const PUSHPIN := preload("res://assets/ui/pushpin.svg")

# 強化カードを「コルクボードに留めた書類」風に表示するためのトーン。
# UIConstants の青系背景は使わず、紙色 + 暗い文字 + レア度色リボンで統一する。
const CARD_PAPER_BG := Color(0.96, 0.93, 0.84, 1.0)          # ベース紙色
const CARD_PAPER_BG_DISABLED := Color(0.78, 0.74, 0.66, 1.0) # 買えない時の褪色
const CARD_PAPER_BG_MAXED := Color(0.70, 0.78, 0.68, 1.0)    # MAX時の渋緑（達成感）
const CARD_INK_COLOR := Color(0.18, 0.14, 0.10, 1.0)         # 紙の上の文字色
const CARD_INK_SUB_COLOR := Color(0.28, 0.22, 0.16, 0.85)    # 副次的な文字色
const CARD_PIN_SIZE := 26

const CARD_ICON_SIZE := 28
const PARTICLE_COUNT := 7
const PARTICLE_SPEED_MIN := 140.0
const PARTICLE_SPEED_MAX := 280.0
const PARTICLE_LIFETIME := 0.65
const PARTICLE_SIZE := 24.0
const STAMP_CHANCE := 0.18
const STAMP_SIZE := 180.0
const STAMP_LIFETIME := 0.45

@onready var document_button: TextureButton = %DocumentButton
@onready var upgrade_grid: GridContainer = %UpgradeGrid
@onready var sticky_target_label: Label = %StickyTargetLabel
@onready var prestige_bar: PanelContainer = %PrestigeBar
@onready var prestige_preview: Label = %PrestigePreview
@onready var prestige_button: Button = %PrestigeButton
@onready var prestige_confirm: ConfirmationDialog = %PrestigeConfirm
@onready var title_panel: PanelContainer = %TitlePanel

var _click_tween: Tween

var _golden_timer: Timer
var _golden_active_node: TextureButton = null

# id → カード Dict（再構築せず差分更新するための索引）
var _cards: Dictionary = {}
var _expanded_id: StringName = &""


func _ready() -> void:
	document_button.pressed.connect(_on_click_pressed)
	EventBus.currency_changed.connect(_refresh_all_cards)
	EventBus.currency_changed.connect(_refresh_prestige_bar)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.meta_upgrade_purchased.connect(_on_meta_purchased)
	prestige_button.pressed.connect(_on_prestige_button_pressed)
	prestige_confirm.confirmed.connect(_on_prestige_confirmed)
	_style_title_panel()
	_build_upgrade_cards()
	_refresh_prestige_bar(0)
	_setup_golden_timer()


# 「アップグレード」見出しを木の名札風に。コルクボード上で浮いて見えるよう影付き。
func _style_title_panel() -> void:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.25, 0.16, 0.09, 1.0)
	sbox.border_color = Color(0.55, 0.40, 0.20, 1.0)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 14
	sbox.content_margin_right = 14
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	sbox.shadow_color = Color(0, 0, 0, 0.45)
	sbox.shadow_size = 4
	sbox.shadow_offset = Vector2(1, 2)
	title_panel.add_theme_stylebox_override("panel", sbox)
	var title_label := title_panel.get_child(0) as Label
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.75, 1.0))


func _setup_golden_timer() -> void:
	_golden_timer = Timer.new()
	_golden_timer.one_shot = true
	add_child(_golden_timer)
	_golden_timer.timeout.connect(_spawn_golden)
	_restart_golden_timer()


func _on_click_pressed() -> void:
	var gained := GameState.click_power
	EconomyService.click()
	# 押下位置（document_button 上のローカル座標を WorkTab 座標へ変換）
	var btn_rect := document_button.get_global_rect()
	var click_global := document_button.get_global_mouse_position()
	if not btn_rect.has_point(click_global):
		click_global = btn_rect.get_center()
	var click_local := click_global - global_position
	_animate_click_squash()
	_flash_document()
	_spawn_click_popup(gained)
	_spawn_click_particles(click_local)
	if randf() < STAMP_CHANCE:
		_spawn_approved_stamp(click_local)


func _flash_document() -> void:
	# クリックの瞬間に書類を一瞬白くする → 押した感触
	var flash_tw := create_tween()
	document_button.modulate = Color(1.3, 1.3, 1.3, 1.0)
	flash_tw.tween_property(document_button, "modulate", Color(1, 1, 1, 1), 0.12)


func _spawn_click_particles(origin: Vector2) -> void:
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
		add_child(p)
		var angle := randf() * TAU
		var speed := randf_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		var gravity := Vector2(0, 320.0)
		# 終了位置（弾道近似）と回転終了角
		var dur := PARTICLE_LIFETIME * randf_range(0.85, 1.15)
		var end_pos := p.position + velocity * dur + gravity * dur * dur * 0.5
		var end_rot := deg_to_rad(randf_range(-360.0, 360.0))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", end_rot, dur)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "scale", Vector2(0.6, 0.6), dur)
		tw.chain().tween_callback(p.queue_free)


func _spawn_approved_stamp(origin: Vector2) -> void:
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
	add_child(stamp)
	var tw := create_tween().set_parallel(true)
	# スタンプ叩きつけ：大きく出てキュッと縮む + 不透明度立ち上げ
	tw.tween_property(stamp, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.06)
	# 一拍置いてフェードアウト
	tw.chain().tween_property(stamp, "modulate:a", 0.0, STAMP_LIFETIME).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(stamp.queue_free)


func _animate_click_squash() -> void:
	if _click_tween != null and _click_tween.is_valid():
		_click_tween.kill()
	document_button.pivot_offset = document_button.size / 2.0
	document_button.scale = Vector2.ONE
	var dur := UIConstants.PORTRAIT_CLICK_DURATION
	var squashed := Vector2.ONE * (1.0 - UIConstants.PORTRAIT_CLICK_SQUASH)
	var wiggle := deg_to_rad(randf_range(-UIConstants.CLICK_WIGGLE_DEG, UIConstants.CLICK_WIGGLE_DEG))
	_click_tween = create_tween().set_parallel(true)
	_click_tween.tween_property(document_button, "scale", squashed, dur)
	_click_tween.chain().tween_property(document_button, "scale", Vector2.ONE, dur)
	_click_tween.tween_property(document_button, "rotation", wiggle, dur)
	_click_tween.chain().tween_property(document_button, "rotation", 0.0, dur * 1.5)


func _spawn_click_popup(amount: int) -> void:
	if amount <= 0:
		return
	var popup := Label.new()
	popup.text = "+%s" % FormatUtils.short(amount)
	popup.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	popup.modulate = UIConstants.COLOR_ACCENT
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100
	add_child(popup)
	var btn_rect := document_button.get_global_rect()
	var local_origin := btn_rect.position - global_position
	var jitter := Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 10.0))
	var start_pos := local_origin + Vector2(btn_rect.size.x * 0.5, btn_rect.size.y * 0.35) + jitter
	popup.position = start_pos
	popup.pivot_offset = popup.size * 0.5
	var end_pos := start_pos + Vector2(0, -UIConstants.CLICK_POPUP_RISE_PX)
	var dur := UIConstants.CLICK_POPUP_DURATION
	var tw := create_tween().set_parallel(true)
	tw.tween_property(popup, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(popup, "scale", Vector2(1.25, 1.25), dur * 0.3).from(Vector2.ONE)
	tw.chain().tween_callback(popup.queue_free)


# --- カードビルド -------------------------------------------------------

func _build_upgrade_cards() -> void:
	for child in upgrade_grid.get_children():
		child.queue_free()
	_cards.clear()
	# レア度降順 → コスト昇順で並べる（強いやつが上に来る）
	var upgrades: Array = DataRegistry.upgrades.values()
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.base_cost < b.base_cost)
	for u: UpgradeData in upgrades:
		# メタ強化によるゲート：requires_meta が未解放なら表示しない
		if not GameState.has_meta_unlock(u.requires_meta):
			continue
		var card := _make_card(u)
		upgrade_grid.add_child(card)
		_cards[u.id] = card
	_refresh_all_cards(0)


func _make_card(u: UpgradeData) -> PanelContainer:
	var rarity_color: Color = UIConstants.RARITY_COLORS.get(u.rarity, UIConstants.RARITY_COLORS[Enums.UpgradeRarity.COMMON])

	# 紙本体（実際のカード）：コルクボードに貼られたメモ風
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("upgrade_id", u.id)
	panel.set_meta("rarity_color", rarity_color)

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = CARD_PAPER_BG
	# 紙のフチは抑え気味、レア度はリボン + 文字色で示す
	sbox.border_color = Color(0.45, 0.35, 0.22, 0.55)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(3)
	sbox.content_margin_left = 14
	sbox.content_margin_right = 14
	# 上部はピン分の余白を確保
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 12
	# 紙の影
	sbox.shadow_color = Color(0, 0, 0, 0.45)
	sbox.shadow_size = 6
	sbox.shadow_offset = Vector2(2, 4)
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vb)

	# 押しピン行（中央配置）
	var pin_row := CenterContainer.new()
	pin_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(pin_row)
	var pin := TextureRect.new()
	pin.texture = PUSHPIN
	pin.custom_minimum_size = Vector2(CARD_PIN_SIZE, CARD_PIN_SIZE)
	pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin_row.add_child(pin)

	# レア度カラーリボン（細い帯）
	var ribbon := ColorRect.new()
	ribbon.color = rarity_color
	ribbon.custom_minimum_size = Vector2(0, 4)
	ribbon.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(ribbon)

	# --- ヘッダ：アイコン + 名前 + Lv --------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(header)

	var icon := TextureRect.new()
	icon.texture = _icon_for_effect(u.effect_kind)
	icon.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	# アイコンは元々ダーク背景向け。紙の上では暗めにトーン調整
	icon.modulate = Color(0.32, 0.26, 0.20, 1.0)
	header.add_child(icon)

	# レア度色は彩度を上げて文字色として読みやすく
	var name_color := _ink_rarity_color(rarity_color)
	var name_label := Label.new()
	name_label.text = tr(u.display_name)
	name_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	name_label.add_theme_color_override("font_color", name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(name_label)

	var lv_label := Label.new()
	lv_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	lv_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	lv_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(lv_label)

	# --- 効果ライン ---------------------------------------------------------
	var effect_label := Label.new()
	effect_label.text = _format_effect(u)
	effect_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	effect_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(effect_label)

	# --- コストライン -------------------------------------------------------
	var cost_label := Label.new()
	cost_label.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)
	cost_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(cost_label)

	# --- 展開領域（リッチ詳細パネル） --------------------------------------
	var expand := VBoxContainer.new()
	expand.visible = false
	expand.add_theme_constant_override("separation", 8)
	expand.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(expand)

	expand.add_child(HSeparator.new())

	# ヘッダ行：大アイコン + レア度バッジ
	var detail_head := HBoxContainer.new()
	detail_head.add_theme_constant_override("separation", 10)
	detail_head.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(detail_head)

	var big_icon := TextureRect.new()
	big_icon.texture = _icon_for_effect(u.effect_kind)
	big_icon.custom_minimum_size = Vector2(56, 56)
	big_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_head.add_child(big_icon)

	var rarity_badge := Label.new()
	rarity_badge.text = _rarity_key(u.rarity)
	rarity_badge.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	rarity_badge.add_theme_color_override("font_color", name_color)
	rarity_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_head.add_child(rarity_badge)

	# 詳細部の大アイコンも紙トーンに揃える
	big_icon.modulate = Color(0.32, 0.26, 0.20, 1.0)

	# 説明文
	var desc_label := Label.new()
	desc_label.text = tr(u.description)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	desc_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(desc_label)

	expand.add_child(HSeparator.new())

	# 統計グリッド（ラベル｜値 の2列）
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", 4)
	stats.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(stats)

	var per_lv_label := _make_stat_key_label("WORK_UPGRADE_STATS_PER_LV")
	var per_lv_value := _make_stat_value_label()
	per_lv_value.text = _format_effect(u)
	stats.add_child(per_lv_label)
	stats.add_child(per_lv_value)

	var total_label := _make_stat_key_label("WORK_UPGRADE_STATS_TOTAL")
	var total_value := _make_stat_value_label()
	stats.add_child(total_label)
	stats.add_child(total_value)

	var invested_label := _make_stat_key_label("WORK_UPGRADE_STATS_INVESTED")
	var invested_value := _make_stat_value_label()
	stats.add_child(invested_label)
	stats.add_child(invested_value)

	var next_label := _make_stat_key_label("WORK_UPGRADE_STATS_NEXT_COST")
	var next_value := _make_stat_value_label()
	stats.add_child(next_label)
	stats.add_child(next_value)

	# 不足額 or 「購入可」のヒント
	var afford_label := Label.new()
	afford_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	afford_label.mouse_filter = Control.MOUSE_FILTER_PASS
	afford_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	afford_label.add_theme_color_override("font_color", CARD_INK_COLOR)
	expand.add_child(afford_label)

	# 購入ボタン（広め・レア度色アクセント）
	var buy_button := Button.new()
	buy_button.text = tr("WORK_UPGRADE_BUY_BUTTON")
	buy_button.custom_minimum_size = Vector2(0, 36)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.add_theme_color_override("font_color", name_color)
	buy_button.pressed.connect(_on_buy_pressed.bind(u.id))
	expand.add_child(buy_button)

	# クリックでアコーディオン展開（buy_button は STOP で食う）
	panel.gui_input.connect(_on_card_gui_input.bind(u.id))

	panel.set_meta("name_label", name_label)
	panel.set_meta("lv_label", lv_label)
	panel.set_meta("effect_label", effect_label)
	panel.set_meta("cost_label", cost_label)
	panel.set_meta("desc_label", desc_label)
	panel.set_meta("expand", expand)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	panel.set_meta("rarity_badge", rarity_badge)
	panel.set_meta("total_value", total_value)
	panel.set_meta("invested_value", invested_value)
	panel.set_meta("next_value", next_value)
	panel.set_meta("afford_label", afford_label)
	panel.set_meta("glow_tween", null)

	return panel


func _make_stat_key_label(key: String) -> Label:
	var l := Label.new()
	# Godot は Label.text に翻訳キーが入っていれば自動で tr する。
	# 静的キーラベルはこの仕組みでロケール切替に追従させる。
	l.text = key
	l.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	l.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _make_stat_value_label() -> Label:
	var l := Label.new()
	l.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	l.add_theme_color_override("font_color", CARD_INK_COLOR)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


# レア度色をそのまま紙の上に置くと薄く見えるため、彩度を保ったまま暗めへ補正する。
# Color.darkened(amount) は v=0 寄りに線形補完するので 0.5 程度で十分視認できる。
func _ink_rarity_color(c: Color) -> Color:
	return c.darkened(0.55)


func _rarity_key(r: Enums.UpgradeRarity) -> String:
	match r:
		Enums.UpgradeRarity.LEGENDARY: return "WORK_UPGRADE_RARITY_LEGENDARY"
		Enums.UpgradeRarity.EPIC: return "WORK_UPGRADE_RARITY_EPIC"
		Enums.UpgradeRarity.RARE: return "WORK_UPGRADE_RARITY_RARE"
		_: return "WORK_UPGRADE_RARITY_COMMON"


func _cumulative_invested(u: UpgradeData, level: int) -> int:
	if level <= 0:
		return 0
	var sum := 0.0
	var c := float(u.base_cost)
	for i in level:
		sum += c
		c *= u.cost_growth
	return int(sum)


func _format_total_contribution(u: UpgradeData, level: int) -> String:
	var amt := u.effect_amount * float(level)
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return tr("WORK_UPGRADE_EFFECT_CLICK") % FormatUtils.short(int(round(amt)))
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return tr("WORK_UPGRADE_EFFECT_SEC") % FormatUtils.short(int(round(amt)))
		Enums.UpgradeEffectKind.MULT_CLICK:
			# 倍率は重ねがけ：effect_amount^level
			var mult := pow(u.effect_amount, level)
			return tr("WORK_UPGRADE_EFFECT_MULT") % ("%.1f" % mult)
	return ""


func _icon_for_effect(kind: Enums.UpgradeEffectKind) -> Texture2D:
	match kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return ICON_CLICK
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return ICON_AUTO
		Enums.UpgradeEffectKind.MULT_CLICK:
			return ICON_MULT
	return ICON_CLICK


func _format_effect(u: UpgradeData) -> String:
	var amt := FormatUtils.short(int(round(u.effect_amount)))
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return tr("WORK_UPGRADE_EFFECT_CLICK") % amt
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return tr("WORK_UPGRADE_EFFECT_SEC") % amt
		Enums.UpgradeEffectKind.MULT_CLICK:
			return tr("WORK_UPGRADE_EFFECT_MULT") % ("%.1f" % u.effect_amount)
	return ""


# --- 状態更新 -----------------------------------------------------------

func _refresh_all_cards(_v: int = 0) -> void:
	for id in _cards.keys():
		_refresh_card(id)
	_refresh_sticky_target()


func _refresh_sticky_target() -> void:
	# 「次の目標」付箋：未MAX強化の中で最も安いものを指す。
	var min_cost := -1
	var target_id: StringName = &""
	for id in DataRegistry.upgrades:
		var u := DataRegistry.get_upgrade(id)
		if u == null:
			continue
		var lv := GameState.get_upgrade_level(id)
		if u.max_level > 0 and lv >= u.max_level:
			continue
		var c := EconomyService.current_cost(id)
		if min_cost < 0 or c < min_cost:
			min_cost = c
			target_id = id
	if target_id == &"":
		sticky_target_label.text = tr("WORK_STICKY_ALL_MAX")
		return
	var u := DataRegistry.get_upgrade(target_id)
	sticky_target_label.text = "%s\n%s\n¥ %s" % [
		tr("WORK_STICKY_HEADING"),
		tr(u.display_name),
		FormatUtils.short(min_cost),
	]


func _refresh_card(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var u := DataRegistry.get_upgrade(id)
	if u == null:
		return
	var lv := GameState.get_upgrade_level(id)
	var maxed := u.max_level > 0 and lv >= u.max_level
	var can_buy := EconomyService.can_buy_upgrade(id) and not maxed

	var lv_label: Label = card.get_meta("lv_label")
	var cost_label: Label = card.get_meta("cost_label")
	var buy_button: Button = card.get_meta("buy_button")
	var total_value: Label = card.get_meta("total_value")
	var invested_value: Label = card.get_meta("invested_value")
	var next_value: Label = card.get_meta("next_value")
	var afford_label: Label = card.get_meta("afford_label")

	total_value.text = _format_total_contribution(u, lv)
	invested_value.text = tr("WORK_UPGRADE_COST_FMT") % FormatUtils.short(_cumulative_invested(u, lv))

	if maxed:
		lv_label.text = tr("WORK_UPGRADE_LV_MAX_FMT") % lv
		cost_label.text = tr("WORK_UPGRADE_COST_MAX")
		next_value.text = tr("WORK_UPGRADE_COST_MAX")
		afford_label.text = ""
		buy_button.disabled = true
	else:
		lv_label.text = tr("WORK_UPGRADE_LV_FMT") % lv
		var cost := EconomyService.current_cost(id)
		var cost_str := tr("WORK_UPGRADE_COST_FMT") % FormatUtils.short(cost)
		cost_label.text = cost_str
		next_value.text = cost_str
		buy_button.disabled = not can_buy
		if can_buy:
			afford_label.text = tr("WORK_UPGRADE_STATS_AFFORD")
			afford_label.add_theme_color_override("font_color", _ink_rarity_color(UIConstants.RARITY_COLORS[u.rarity]))
		else:
			var short_by := cost - GameState.currency
			afford_label.text = tr("WORK_UPGRADE_STATS_SHORT") % FormatUtils.short(short_by)
			afford_label.add_theme_color_override("font_color", CARD_INK_SUB_COLOR)

	# 買える時だけ脈動。MAX / 買えない時は通常表示で固定。
	_set_glow(card, can_buy)
	# 買えない時は紙が褪色、MAX 時はアーカイブ色（達成感）に切替
	var sbox: StyleBoxFlat = card.get_meta("stylebox")
	if maxed:
		sbox.bg_color = CARD_PAPER_BG_MAXED
	elif can_buy:
		sbox.bg_color = CARD_PAPER_BG
	else:
		sbox.bg_color = CARD_PAPER_BG_DISABLED


func _set_glow(card: PanelContainer, on: bool) -> void:
	var existing: Tween = card.get_meta("glow_tween")
	if existing != null and existing.is_valid():
		existing.kill()
		card.set_meta("glow_tween", null)
	if not on:
		card.modulate = Color(1, 1, 1, 1)
		return
	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half := UIConstants.CARD_GLOW_PERIOD * 0.5
	var hi := Color(UIConstants.CARD_GLOW_MAX, UIConstants.CARD_GLOW_MAX, UIConstants.CARD_GLOW_MAX, 1.0)
	var lo := Color(UIConstants.CARD_GLOW_MIN, UIConstants.CARD_GLOW_MIN, UIConstants.CARD_GLOW_MIN, 1.0)
	tw.tween_property(card, "modulate", hi, half)
	tw.tween_property(card, "modulate", lo, half)
	card.set_meta("glow_tween", tw)


# --- インタラクション ---------------------------------------------------

func _on_card_gui_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_toggle_expand(id)


func _toggle_expand(id: StringName) -> void:
	if _expanded_id == id:
		_set_expanded(id, false)
		_expanded_id = &""
		return
	if _expanded_id != &"":
		_set_expanded(_expanded_id, false)
	_set_expanded(id, true)
	_expanded_id = id


func _set_expanded(id: StringName, on: bool) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var expand: VBoxContainer = card.get_meta("expand")
	expand.visible = on


func _on_buy_pressed(id: StringName) -> void:
	EconomyService.buy_upgrade(id)


func _on_upgrade_purchased(id: StringName, _lv: int) -> void:
	_refresh_card(id)


func _on_meta_purchased(_id: StringName, _lv: int) -> void:
	# メタ強化購入で requires_meta 解放されたカードが増える可能性 → 再構築
	_build_upgrade_cards()


# --- プレステージ -------------------------------------------------------

func _refresh_prestige_bar(_v: int = 0) -> void:
	if not GameState.is_prestige_unlocked():
		prestige_bar.visible = false
		return
	prestige_bar.visible = true
	var gain := GameState.compute_prestige_currency_gained()
	prestige_preview.text = tr("WORK_PRESTIGE_PREVIEW_FMT") % FormatUtils.short(gain)
	prestige_button.disabled = gain <= 0


func _on_prestige_button_pressed() -> void:
	var gain := GameState.compute_prestige_currency_gained()
	var pc := GameState.prestige_count
	var lines := [
		tr("WORK_PRESTIGE_CONFIRM_BODY_LOSS"),
		tr("WORK_PRESTIGE_CONFIRM_BODY_KEEP"),
		"",
		tr("WORK_PRESTIGE_CONFIRM_BODY_GAIN") % FormatUtils.short(gain),
		tr("WORK_PRESTIGE_CONFIRM_BODY_RUN") % [pc, pc + 1],
	]
	prestige_confirm.dialog_text = "\n".join(lines)
	prestige_confirm.popup_centered()


func _on_prestige_confirmed() -> void:
	GameState.do_prestige_reset()
	# 走行リセットされたので強化カードを再構築 + プレステージバーも更新
	_build_upgrade_cards()
	_refresh_prestige_bar(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rebuild_static_text()


func _rebuild_static_text() -> void:
	for id in _cards.keys():
		var card: PanelContainer = _cards[id]
		var u := DataRegistry.get_upgrade(id)
		if u == null:
			continue
		(card.get_meta("name_label") as Label).text = tr(u.display_name)
		(card.get_meta("desc_label") as Label).text = tr(u.description)
		(card.get_meta("effect_label") as Label).text = _format_effect(u)
		(card.get_meta("buy_button") as Button).text = tr("WORK_UPGRADE_BUY_BUTTON")
	_refresh_all_cards(0)


# --- ゴールデン書類 -----------------------------------------------------

func _restart_golden_timer() -> void:
	_golden_timer.wait_time = randf_range(
		UIConstants.GOLDEN_INTERVAL_MIN_SEC,
		UIConstants.GOLDEN_INTERVAL_MAX_SEC
	)
	_golden_timer.start()


func _spawn_golden() -> void:
	# Workタブが画面に出てない時はスポーンを見送って次の時刻を引き直す
	if not is_visible_in_tree():
		_restart_golden_timer()
		return
	if _golden_active_node != null and is_instance_valid(_golden_active_node):
		_restart_golden_timer()
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
	var w := size.x
	var h := size.y
	var y := randf_range(h * 0.2, h * 0.7)
	btn.position = Vector2(-sz, y)
	btn.z_index = 50
	add_child(btn)
	_golden_active_node = btn
	btn.pressed.connect(_on_golden_clicked.bind(btn))
	# 横断アニメ + ゆっくり回転で目立たせる
	var dur := UIConstants.GOLDEN_LIFETIME_SEC
	var tw := create_tween().set_parallel(true)
	tw.tween_property(btn, "position:x", w + sz, dur)
	tw.tween_property(btn, "rotation", deg_to_rad(20.0), dur)
	tw.chain().tween_callback(func() -> void: _expire_golden(btn))


func _on_golden_clicked(btn: TextureButton) -> void:
	if not is_instance_valid(btn):
		return
	var bonus := UIConstants.GOLDEN_BONUS_FLOOR
	bonus = max(bonus, GameState.effective_click_power() * UIConstants.GOLDEN_BONUS_PER_CLICK)
	bonus = max(bonus, int(float(GameState.currency) * UIConstants.GOLDEN_BONUS_PCT_OF_PILE))
	GameState.add_currency(bonus)
	EventBus.toast_requested.emit(tr("TOAST_GOLDEN_BONUS") % FormatUtils.short(bonus))
	_expire_golden(btn)


func _expire_golden(btn: TextureButton) -> void:
	if is_instance_valid(btn):
		btn.queue_free()
	_golden_active_node = null
	_restart_golden_timer()
