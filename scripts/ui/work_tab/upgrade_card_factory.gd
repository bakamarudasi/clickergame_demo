class_name UpgradeCardFactory
extends RefCounted

# Work タブの強化カードを構築・更新するファクトリ。
# 「ダーク基調＋左端 rarity アクセント＋シアン購入ボタン」のサイバー寄り意匠。
# UI ノードの生成・スタイリング・差分更新を一手に引き受け、WorkTab 本体は
# カードを並べてイベントを束ねるだけになる。

signal expand_requested(id: StringName)
signal buy_requested(id: StringName)
signal qty_mode_changed(mode: int)

const ICON_CLICK := preload("res://assets/ui/icon_click.svg")
const ICON_AUTO := preload("res://assets/ui/icon_auto.svg")
const ICON_MULT := preload("res://assets/ui/icon_mult.svg")

const CARD_ICON_SIZE := 32
const BUY_BUTTON_HEIGHT := 36

var _host: Control


func _init(host: Control) -> void:
	_host = host


# 1 枚分のカードを組み立てる。返した PanelContainer は親に add_child するだけ。
# refresh() で都度参照する子ノードはすべて set_meta で索引化する。
func build(u: UpgradeData, initial_qty_mode: int) -> PanelContainer:
	var rarity_color: Color = UIConstants.RARITY_COLORS.get(
		u.rarity, UIConstants.RARITY_COLORS[Enums.UpgradeRarity.COMMON]
	)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("upgrade_id", u.id)
	panel.set_meta("rarity_color", rarity_color)

	var sbox := PanelStyler.card(rarity_color)
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UIConstants.SEP_SMALL)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vb)

	var name_label := _add_header_row(vb, u, rarity_color)
	var lv_label := name_label.get_meta("lv_label") as Label

	var effect_label := _add_effect_label(vb, u)
	var cost_label := _add_cost_label(vb)

	var expand := _add_expand_section(vb)
	var detail := _add_expand_detail(expand, u, rarity_color)
	var qty_selector := _add_qty_selector(expand, initial_qty_mode)
	var afford_label := _add_afford_label(expand)
	var buy_button := _add_buy_button(expand, u)

	# クリックでアコーディオン展開（buy_button は STOP で食う）
	panel.gui_input.connect(_on_card_gui_input.bind(u.id))

	panel.set_meta("name_label", name_label)
	panel.set_meta("lv_label", lv_label)
	panel.set_meta("effect_label", effect_label)
	panel.set_meta("cost_label", cost_label)
	panel.set_meta("desc_label", detail.desc)
	panel.set_meta("expand", expand)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	panel.set_meta("rarity_badge", detail.rarity_badge)
	panel.set_meta("total_value", detail.total_value)
	panel.set_meta("invested_value", detail.invested_value)
	panel.set_meta("next_value", detail.next_value)
	panel.set_meta("afford_label", afford_label)
	panel.set_meta("qty_selector", qty_selector)
	panel.set_meta("glow_tween", null)

	return panel


# qty_resolver: id を渡すと現モードに対応する qty を返す Callable。
# WorkTab 側で「全カード共有の qty_mode」を解決する。
func refresh(card: PanelContainer, u: UpgradeData, qty_mode: int, qty_resolver: Callable) -> void:
	var lv := GameState.get_upgrade_level(u.id)
	var maxed := u.max_level > 0 and lv >= u.max_level

	var lv_label: Label = card.get_meta("lv_label")
	var cost_label: Label = card.get_meta("cost_label")
	var buy_button: Button = card.get_meta("buy_button")
	var total_value: Label = card.get_meta("total_value")
	var invested_value: Label = card.get_meta("invested_value")
	var next_value: Label = card.get_meta("next_value")
	var afford_label: Label = card.get_meta("afford_label")
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")

	total_value.text = _format_total_contribution(u, lv)
	invested_value.text = _t("WORK_UPGRADE_COST_FMT") % FormatUtils.short(_cumulative_invested(u, lv))

	qty_selector.set_mode_silent(qty_mode)

	var qty := 0
	var total_cost := 0
	if not maxed:
		qty = int(qty_resolver.call(u.id))
		total_cost = EconomyService.cumulative_cost(u.id, qty)

	var can_buy := qty > 0 and GameState.currency >= total_cost
	var single_cost := EconomyService.current_cost(u.id) if not maxed else -1

	if maxed:
		lv_label.text = _t("WORK_UPGRADE_LV_MAX_FMT") % lv
		cost_label.text = _t("WORK_UPGRADE_COST_MAX")
		next_value.text = _t("WORK_UPGRADE_COST_MAX")
		afford_label.text = ""
		buy_button.disabled = true
		buy_button.text = _t("WORK_UPGRADE_BUY_BUTTON")
		qty_selector.set_enabled(false)
	else:
		lv_label.text = _t("WORK_UPGRADE_LV_FMT") % lv
		cost_label.text = _t("WORK_UPGRADE_COST_FMT") % FormatUtils.short(single_cost)
		next_value.text = _t("WORK_UPGRADE_COST_FMT") % FormatUtils.short(total_cost)
		qty_selector.set_enabled(true)
		buy_button.disabled = not can_buy
		if qty > 1:
			buy_button.text = _t("WORK_UPGRADE_BUY_BUTTON_QTY_FMT") % [qty, FormatUtils.short(total_cost)]
		else:
			buy_button.text = _t("WORK_UPGRADE_BUY_BUTTON")
		if can_buy:
			afford_label.text = _t("WORK_UPGRADE_STATS_AFFORD")
			afford_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
		else:
			var ref_cost := total_cost if qty > 0 else single_cost
			var short_by := ref_cost - GameState.currency
			afford_label.text = _t("WORK_UPGRADE_STATS_SHORT") % FormatUtils.short(short_by)
			afford_label.add_theme_color_override("font_color", UIConstants.COLOR_WARN)

	set_glow(card, can_buy)
	var sbox: StyleBoxFlat = card.get_meta("stylebox")
	if maxed:
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_MAXED
	elif can_buy:
		sbox.bg_color = UIConstants.RARITY_PANEL_BG
	else:
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_DISABLED


func rebuild_static_text(card: PanelContainer, u: UpgradeData) -> void:
	(card.get_meta("name_label") as Label).text = _t(u.display_name)
	(card.get_meta("desc_label") as Label).text = _t(u.description)
	(card.get_meta("effect_label") as Label).text = _format_effect(u)
	(card.get_meta("buy_button") as Button).text = _t("WORK_UPGRADE_BUY_BUTTON")
	(card.get_meta("rarity_badge") as Label).text = _t(_rarity_key(u.rarity))


func set_expanded(card: PanelContainer, on: bool) -> void:
	var expand: VBoxContainer = card.get_meta("expand")
	expand.visible = on


func set_glow(card: PanelContainer, on: bool) -> void:
	var existing: Tween = card.get_meta("glow_tween")
	if existing != null and existing.is_valid():
		existing.kill()
		card.set_meta("glow_tween", null)
	if not on:
		card.modulate = Color(1, 1, 1, 1)
		return
	var tw := _host.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half := UIConstants.CARD_GLOW_PERIOD * 0.5
	var hi := Color(UIConstants.CARD_GLOW_MAX, UIConstants.CARD_GLOW_MAX, UIConstants.CARD_GLOW_MAX, 1.0)
	var lo := Color(UIConstants.CARD_GLOW_MIN, UIConstants.CARD_GLOW_MIN, UIConstants.CARD_GLOW_MIN, 1.0)
	tw.tween_property(card, "modulate", hi, half)
	tw.tween_property(card, "modulate", lo, half)
	card.set_meta("glow_tween", tw)


static func grid_index_for_effect(kind: Enums.UpgradeEffectKind) -> int:
	match kind:
		Enums.UpgradeEffectKind.ADD_PER_SEC: return 1
		Enums.UpgradeEffectKind.MULT_CLICK: return 2
		_: return 0


# --- 内部ビルダー -------------------------------------------------------

# 名前ラベルを返す（Lv ラベルは meta に格納）。
func _add_header_row(parent: VBoxContainer, u: UpgradeData, rarity_color: Color) -> Label:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIConstants.SEP_DEFAULT)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(header)

	var icon := _make_effect_icon(u.effect_kind, CARD_ICON_SIZE, rarity_color)
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = _t(u.display_name)
	name_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	name_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(name_label)

	var lv_label := Label.new()
	lv_label.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	lv_label.add_theme_color_override("font_color", rarity_color)
	lv_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(lv_label)
	name_label.set_meta("lv_label", lv_label)
	return name_label


func _add_effect_label(parent: VBoxContainer, u: UpgradeData) -> Label:
	var l := Label.new()
	l.text = _format_effect(u)
	l.theme_type_variation = UIConstants.VAR_DIM_LABEL
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(l)
	return l


func _add_cost_label(parent: VBoxContainer) -> Label:
	var l := Label.new()
	l.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	l.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_CYAN)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(l)
	return l


func _add_expand_section(parent: VBoxContainer) -> VBoxContainer:
	var expand := VBoxContainer.new()
	expand.visible = false
	expand.add_theme_constant_override("separation", UIConstants.SEP_DEFAULT)
	expand.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(expand)
	expand.add_child(HSeparator.new())
	return expand


func _add_expand_detail(expand: VBoxContainer, u: UpgradeData, rarity_color: Color) -> Dictionary:
	# ヘッダ行：大アイコン + レア度バッジ
	var detail_head := HBoxContainer.new()
	detail_head.add_theme_constant_override("separation", UIConstants.SEP_MEDIUM)
	detail_head.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(detail_head)

	var big_icon := _make_effect_icon(u.effect_kind, 56, rarity_color)
	detail_head.add_child(big_icon)

	var rarity_badge := Label.new()
	rarity_badge.text = _t(_rarity_key(u.rarity))
	rarity_badge.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	rarity_badge.add_theme_color_override("font_color", rarity_color)
	rarity_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_head.add_child(rarity_badge)

	# 説明文
	var desc_label := Label.new()
	desc_label.text = _t(u.description)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(desc_label)

	expand.add_child(HSeparator.new())

	# 統計グリッド（ラベル｜値 の2列）
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", UIConstants.SEP_MEDIUM)
	stats.add_theme_constant_override("v_separation", UIConstants.SEP_TIGHT)
	stats.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(stats)

	var per_lv_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_PER_LV")
	per_lv_value.text = _format_effect(u)
	var total_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_TOTAL")
	var invested_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_INVESTED")
	var next_value := _add_stat_row(stats, "WORK_UPGRADE_STATS_NEXT_COST")

	return {
		"rarity_badge": rarity_badge,
		"desc": desc_label,
		"total_value": total_value,
		"invested_value": invested_value,
		"next_value": next_value,
	}


func _add_stat_row(stats: GridContainer, key: String) -> Label:
	var key_label := Label.new()
	key_label.text = key  # Button/Label.text に翻訳キーがそのまま入れば自動 tr。
	key_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	key_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(key_label)

	var value_label := Label.new()
	value_label.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(value_label)
	return value_label


func _add_qty_selector(expand: VBoxContainer, initial_mode: int) -> QuantitySelector:
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", UIConstants.SEP_TIGHT)
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.mouse_filter = Control.MOUSE_FILTER_PASS
	expand.add_child(qty_row)

	var sel := QuantitySelector.new()
	sel.build_into(qty_row, "WORK_UPGRADE_QTY_MAX", Vector2(56, 28))
	# 数量ボタンは PillButton 変種に揃える
	for b in sel.buttons:
		b.theme_type_variation = UIConstants.VAR_PILL_BUTTON
	sel.set_mode_silent(initial_mode)
	sel.mode_changed.connect(_on_qty_mode_changed)
	return sel


func _add_afford_label(expand: VBoxContainer) -> Label:
	var l := Label.new()
	l.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expand.add_child(l)
	return l


func _add_buy_button(expand: VBoxContainer, u: UpgradeData) -> Button:
	var b := Button.new()
	b.theme_type_variation = UIConstants.VAR_ACCENT_BUTTON
	b.text = _t("WORK_UPGRADE_BUY_BUTTON")
	b.custom_minimum_size = Vector2(0, BUY_BUTTON_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_on_buy_pressed.bind(u.id))
	expand.add_child(b)
	return b


func _make_effect_icon(kind: Enums.UpgradeEffectKind, size: int, tint: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _icon_for_effect(kind)
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = tint
	return icon


# --- 純粋関数 -----------------------------------------------------------

func _rarity_key(r: Enums.UpgradeRarity) -> String:
	match r:
		Enums.UpgradeRarity.LEGENDARY: return "WORK_UPGRADE_RARITY_LEGENDARY"
		Enums.UpgradeRarity.EPIC: return "WORK_UPGRADE_RARITY_EPIC"
		Enums.UpgradeRarity.RARE: return "WORK_UPGRADE_RARITY_RARE"
		_: return "WORK_UPGRADE_RARITY_COMMON"


func _icon_for_effect(kind: Enums.UpgradeEffectKind) -> Texture2D:
	match kind:
		Enums.UpgradeEffectKind.ADD_CLICK: return ICON_CLICK
		Enums.UpgradeEffectKind.ADD_PER_SEC: return ICON_AUTO
		Enums.UpgradeEffectKind.MULT_CLICK: return ICON_MULT
	return ICON_CLICK


func _format_effect(u: UpgradeData) -> String:
	var amt := FormatUtils.short(int(round(u.effect_amount)))
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return _t("WORK_UPGRADE_EFFECT_CLICK") % amt
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return _t("WORK_UPGRADE_EFFECT_SEC") % amt
		Enums.UpgradeEffectKind.MULT_CLICK:
			return _t("WORK_UPGRADE_EFFECT_MULT") % ("%.1f" % u.effect_amount)
	return ""


func _format_total_contribution(u: UpgradeData, level: int) -> String:
	var amt := u.effect_amount * float(level)
	match u.effect_kind:
		Enums.UpgradeEffectKind.ADD_CLICK:
			return _t("WORK_UPGRADE_EFFECT_CLICK") % FormatUtils.short(int(round(amt)))
		Enums.UpgradeEffectKind.ADD_PER_SEC:
			return _t("WORK_UPGRADE_EFFECT_SEC") % FormatUtils.short(int(round(amt)))
		Enums.UpgradeEffectKind.MULT_CLICK:
			var mult := pow(u.effect_amount, level)
			return _t("WORK_UPGRADE_EFFECT_MULT") % ("%.1f" % mult)
	return ""


func _cumulative_invested(u: UpgradeData, level: int) -> int:
	if level <= 0:
		return 0
	var sum := 0.0
	var c := float(u.base_cost)
	for i in level:
		sum += c
		c *= u.cost_growth
	return int(sum)


func _t(key: String) -> String:
	return TranslationServer.translate(key)


# --- 子→上位への転送 ---------------------------------------------------

func _on_card_gui_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			expand_requested.emit(id)


func _on_buy_pressed(id: StringName) -> void:
	buy_requested.emit(id)


func _on_qty_mode_changed(mode: int) -> void:
	qty_mode_changed.emit(mode)
