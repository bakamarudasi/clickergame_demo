class_name ItemCardFactory
extends RefCounted

# Shop タブの商品カードを構築・更新するファクトリ。
# 「ダーク基調＋カテゴリ色アクセント＋シアン値札」のサイバー寄り意匠。

signal buy_requested(id: StringName, qty: int)

# カテゴリ別アクセント色（カードの左バー／アイコン tint に使用）。
const CATEGORY_ACCENTS := {
	Enums.ItemCategory.DAILY: Color(0.604, 0.647, 0.690, 1.0),
	Enums.ItemCategory.HOBBY: Color(0.416, 0.910, 0.612, 1.0),
	Enums.ItemCategory.BODY_CARE: Color(0.965, 0.700, 0.890, 1.0),
	Enums.ItemCategory.ROMANCE: Color(0.949, 0.451, 0.651, 1.0),
	Enums.ItemCategory.DIRECT_TOY: Color(0.780, 0.478, 0.910, 1.0),
	Enums.ItemCategory.DIRECT_DRUG: Color(0.700, 0.560, 0.980, 1.0),
	Enums.ItemCategory.DIRECT_BIND: Color(1.0, 0.353, 0.431, 1.0),
	Enums.ItemCategory.DIRECT_PROT: Color(0.302, 0.816, 0.882, 1.0),
	Enums.ItemCategory.COS_OUTFIT: Color(1.0, 0.784, 0.341, 1.0),
	Enums.ItemCategory.COS_PARTS: Color(1.0, 0.627, 0.251, 1.0),
	Enums.ItemCategory.INVITATION: Color(0.247, 0.663, 0.961, 1.0),
	Enums.ItemCategory.RULE: Color(0.365, 0.812, 0.969, 1.0),
	Enums.ItemCategory.SCOPE: Color(0.302, 0.816, 0.882, 1.0),
}

# カテゴリ別デフォルトアイコン。ItemData.icon が未設定なら category から引く。
const CATEGORY_ICONS := {
	Enums.ItemCategory.DAILY: preload("res://assets/items/category/cat_daily.svg"),
	Enums.ItemCategory.HOBBY: preload("res://assets/items/category/cat_hobby.svg"),
	Enums.ItemCategory.BODY_CARE: preload("res://assets/items/category/cat_body_care.svg"),
	Enums.ItemCategory.ROMANCE: preload("res://assets/items/category/cat_romance.svg"),
	Enums.ItemCategory.DIRECT_TOY: preload("res://assets/items/category/cat_direct_toy.svg"),
	Enums.ItemCategory.DIRECT_DRUG: preload("res://assets/items/category/cat_direct_drug.svg"),
	Enums.ItemCategory.DIRECT_BIND: preload("res://assets/items/category/cat_direct_bind.svg"),
	Enums.ItemCategory.DIRECT_PROT: preload("res://assets/items/category/cat_direct_prot.svg"),
	Enums.ItemCategory.COS_OUTFIT: preload("res://assets/items/category/cat_cos_outfit.svg"),
	Enums.ItemCategory.COS_PARTS: preload("res://assets/items/category/cat_cos_parts.svg"),
	Enums.ItemCategory.INVITATION: preload("res://assets/items/category/cat_invitation.svg"),
	Enums.ItemCategory.RULE: preload("res://assets/items/category/cat_rule.svg"),
	Enums.ItemCategory.SCOPE: preload("res://assets/items/category/cat_scope.svg"),
}
const CARD_ICON_SIZE := 56
const BUY_BUTTON_HEIGHT := 36
# 値札の高さ。コンパクトに収めつつ金額が読みやすいサイズ。
const PRICE_TAG_HEIGHT := 38
const PRICE_TAG_MIN_WIDTH := 112

var _host: Control


func _init(host: Control) -> void:
	_host = host


func build(it: ItemData) -> PanelContainer:
	var accent: Color = CATEGORY_ACCENTS.get(it.category, UIConstants.COLOR_ACCENT_CYAN)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("item_id", it.id)
	panel.set_meta("accent_color", accent)

	var sbox := PanelStyler.card(accent)
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UIConstants.SEP_SMALL)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vb)

	# 上段：アイコン（左）＋ 商品名（中、伸縮）＋ 値札（右）
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIConstants.SEP_MEDIUM)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.texture = _resolve_icon(it)
	icon_rect.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.modulate = accent
	header.add_child(icon_rect)

	var name_label := Label.new()
	name_label.text = _t(it.display_name)
	name_label.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(name_label)

	var price_panel := _make_price_tag(it.price)
	header.add_child(price_panel)
	var price_label: Label = price_panel.get_node("PriceLabel")

	# 説明文
	var desc_label := Label.new()
	desc_label.text = _t(it.description)
	desc_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(desc_label)

	# 信頼度ゲート（必要時のみ visible）
	var gate_label := Label.new()
	gate_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	gate_label.add_theme_color_override("font_color", UIConstants.COLOR_WARN)
	gate_label.mouse_filter = Control.MOUSE_FILTER_PASS
	gate_label.visible = false
	vb.add_child(gate_label)

	# 所持数表示（消耗品のみ）
	var owned_label := Label.new()
	owned_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owned_label.mouse_filter = Control.MOUSE_FILTER_PASS
	owned_label.visible = it.is_consumable
	vb.add_child(owned_label)

	# 数量セレクタ（消耗品のみ visible）
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", UIConstants.SEP_TIGHT)
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.mouse_filter = Control.MOUSE_FILTER_PASS
	qty_row.visible = it.is_consumable
	vb.add_child(qty_row)

	var qty_selector := QuantitySelector.new()
	if it.is_consumable:
		qty_selector.build_into(qty_row, "SHOP_QTY_MAX", Vector2(52, 28))
		for b in qty_selector.buttons:
			b.theme_type_variation = UIConstants.VAR_PILL_BUTTON
		qty_selector.mode_changed.connect(_on_qty_changed.bind(panel))

	# 購入ボタン
	var buy_button := Button.new()
	buy_button.theme_type_variation = UIConstants.VAR_ACCENT_BUTTON
	buy_button.text = _t("SHOP_BUY_BUTTON")
	buy_button.custom_minimum_size = Vector2(0, BUY_BUTTON_HEIGHT)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.pressed.connect(_on_buy_pressed.bind(panel))
	vb.add_child(buy_button)

	panel.set_meta("name_label", name_label)
	panel.set_meta("desc_label", desc_label)
	panel.set_meta("price_label", price_label)
	panel.set_meta("gate_label", gate_label)
	panel.set_meta("owned_label", owned_label)
	panel.set_meta("qty_selector", qty_selector)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	return panel


# 通貨や購入状態の変化に応じて、値札・購入ボタン・パネル色・所持数を更新する。
func refresh(card: PanelContainer, it: ItemData) -> void:
	var buy_button: Button = card.get_meta("buy_button")
	var price_label: Label = card.get_meta("price_label")
	var gate_label: Label = card.get_meta("gate_label")
	var owned_label: Label = card.get_meta("owned_label")
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")
	var sbox: StyleBoxFlat = card.get_meta("stylebox")

	if it.trust_gate_min > 0:
		gate_label.visible = true
		gate_label.text = _t("SHOP_DETAIL_GATE_FMT") % it.trust_gate_min
	else:
		gate_label.visible = false

	if it.is_consumable:
		owned_label.visible = true
		owned_label.text = _t("SHOP_OWNED_COUNT_FMT") % GameState.item_count(it.id)
	else:
		owned_label.visible = false

	var already_owned := not it.is_consumable and _is_permanent_effect_applied(it)
	if already_owned:
		buy_button.disabled = true
		buy_button.text = _t("SHOP_BUY_BUTTON_OWNED")
		price_label.text = _t("SHOP_PRICE_OWNED")
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_MAXED
		return

	var qty := _resolve_qty(it, qty_selector)
	var total_cost := it.price * qty
	var can_buy := qty > 0 and ShopService.can_buy(it.id, qty)

	price_label.text = _t("SHOP_PRICE_TAG_FMT") % FormatUtils.short(it.price)
	buy_button.disabled = not can_buy

	if it.is_consumable and qty > 1:
		buy_button.text = _t("SHOP_BUY_BUTTON_QTY_FMT") % [qty, FormatUtils.short(total_cost)]
	else:
		buy_button.text = _t("SHOP_BUY_BUTTON")

	if can_buy:
		sbox.bg_color = UIConstants.RARITY_PANEL_BG
	else:
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_DISABLED


func rebuild_static_text(card: PanelContainer, it: ItemData) -> void:
	(card.get_meta("name_label") as Label).text = _t(it.display_name)
	(card.get_meta("desc_label") as Label).text = _t(it.description)


# 購入成功時にカード全体を弾ませて、シアン寄りにフラッシュさせる。
func play_purchase_feedback(card: PanelContainer, _it: ItemData) -> void:
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE
	var tw := _host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.04, 0.96), 0.08)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)
	var flash := _host.create_tween()
	flash.tween_property(card, "modulate", Color(1.20, 1.30, 1.40, 1.0), 0.08)
	flash.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.32)


# --- 内部ビルダー -------------------------------------------------------

# 値札：シアンの太枠＋黒寄り背景、中央に金額。
func _make_price_tag(price: int) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.custom_minimum_size = Vector2(PRICE_TAG_MIN_WIDTH, PRICE_TAG_HEIGHT)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
	sbox.border_color = UIConstants.COLOR_ACCENT_CYAN
	sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = UIConstants.SEP_MEDIUM
	sbox.content_margin_right = UIConstants.SEP_MEDIUM
	sbox.content_margin_top = UIConstants.SEP_TIGHT
	sbox.content_margin_bottom = UIConstants.SEP_TIGHT
	tag.add_theme_stylebox_override("panel", sbox)

	var label := Label.new()
	label.name = "PriceLabel"
	label.text = _t("SHOP_PRICE_TAG_FMT") % FormatUtils.short(price)
	label.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	label.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_CYAN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(label)
	return tag


func _resolve_icon(it: ItemData) -> Texture2D:
	if it.icon != null:
		return it.icon
	return CATEGORY_ICONS.get(it.category, null)


func _resolve_qty(it: ItemData, qty_selector: QuantitySelector) -> int:
	if not it.is_consumable:
		return 1
	return qty_selector.resolve_qty(func() -> int: return ShopService.max_affordable(it.id))


func _is_permanent_effect_applied(it: ItemData) -> bool:
	if it.effects.is_empty():
		return false
	for eff: ItemEffect in it.effects:
		match eff.kind:
			Enums.EffectKind.OPERATOR_UNLOCK:
				if not GameState.is_operator_unlocked(eff.target_id):
					return false
			Enums.EffectKind.COSTUME_UNLOCK:
				var c := DataRegistry.get_costume(eff.target_id)
				if c == null:
					return false
				var rt := GameState.get_runtime(c.operator_id)
				if rt == null or not (c.id in rt.unlocked_costumes):
					return false
			Enums.EffectKind.RULE_ACTIVATE:
				if not GameState.has_rule(eff.target_id):
					return false
			Enums.EffectKind.SCOPE_GRANT:
				if not (eff.target_id in GameState.owned_scopes):
					return false
			_:
				return false
	return true


func _t(key: String) -> String:
	return TranslationServer.translate(key)


# --- 子→上位への転送 ---------------------------------------------------

func _on_buy_pressed(card: PanelContainer) -> void:
	var id: StringName = card.get_meta("item_id")
	var it := DataRegistry.get_item(id)
	if it == null:
		return
	var qty_selector: QuantitySelector = card.get_meta("qty_selector")
	var qty := _resolve_qty(it, qty_selector)
	if qty <= 0:
		return
	buy_requested.emit(id, qty)


func _on_qty_changed(_mode: int, card: PanelContainer) -> void:
	var id: StringName = card.get_meta("item_id")
	var it := DataRegistry.get_item(id)
	if it != null:
		refresh(card, it)
