extends Control

# Shopタブ。アイテム購入のみを担当。
# 他タブを直接参照しない。ShopService 経由でのみ購入処理を行う。
# 行クリックは「選択」、購入は詳細パネルの BuyButton から（Workタブと同じ流儀）。

@onready var category_select: OptionButton = %CategorySelect
@onready var item_list: VBoxContainer = %ItemList
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_meta: Label = %DetailMeta
@onready var detail_gate: Label = %DetailGate
@onready var buy_button: Button = %BuyButton
@onready var qty_btn_1: Button = %QtyBtn1
@onready var qty_btn_10: Button = %QtyBtn10
@onready var qty_btn_100: Button = %QtyBtn100
@onready var qty_btn_max: Button = %QtyBtnMax

const CATEGORY_ENTRIES := [
	{ "label_key": "CATEGORY_DAILY", "value": Enums.ItemCategory.DAILY },
	{ "label_key": "CATEGORY_HOBBY", "value": Enums.ItemCategory.HOBBY },
	{ "label_key": "CATEGORY_BODY_CARE", "value": Enums.ItemCategory.BODY_CARE },
	{ "label_key": "CATEGORY_ROMANCE", "value": Enums.ItemCategory.ROMANCE },
	{ "label_key": "CATEGORY_DIRECT_TOY", "value": Enums.ItemCategory.DIRECT_TOY },
	{ "label_key": "CATEGORY_DIRECT_DRUG", "value": Enums.ItemCategory.DIRECT_DRUG },
	{ "label_key": "CATEGORY_DIRECT_BIND", "value": Enums.ItemCategory.DIRECT_BIND },
	{ "label_key": "CATEGORY_DIRECT_PROT", "value": Enums.ItemCategory.DIRECT_PROT },
	{ "label_key": "CATEGORY_COS_OUTFIT", "value": Enums.ItemCategory.COS_OUTFIT },
	{ "label_key": "CATEGORY_COS_PARTS", "value": Enums.ItemCategory.COS_PARTS },
	{ "label_key": "CATEGORY_INVITATION", "value": Enums.ItemCategory.INVITATION },
]

var _selected_id: StringName = &""
var _button_group: ButtonGroup
# 0=×1, 1=×10, 2=×100, 3=×Max
var _qty_mode: int = 0
var _qty_button_group: ButtonGroup


func _ready() -> void:
	_button_group = ButtonGroup.new()
	EventBus.currency_changed.connect(_refresh_buttons)
	EventBus.item_purchased.connect(_on_item_purchased)
	category_select.item_selected.connect(_on_category_changed)
	buy_button.pressed.connect(_on_buy_pressed)
	# 数量セレクタ：4 ボタンを排他選択にしてモードを保持
	_qty_button_group = ButtonGroup.new()
	qty_btn_1.button_group = _qty_button_group
	qty_btn_10.button_group = _qty_button_group
	qty_btn_100.button_group = _qty_button_group
	qty_btn_max.button_group = _qty_button_group
	qty_btn_1.toggled.connect(func(p): if p: _qty_mode = 0; _refresh_detail())
	qty_btn_10.toggled.connect(func(p): if p: _qty_mode = 1; _refresh_detail())
	qty_btn_100.toggled.connect(func(p): if p: _qty_mode = 2; _refresh_detail())
	qty_btn_max.toggled.connect(func(p): if p: _qty_mode = 3; _refresh_detail())
	_populate_categories()
	_rebuild_item_list()


func _populate_categories() -> void:
	category_select.clear()
	for i in CATEGORY_ENTRIES.size():
		category_select.add_item(tr(CATEGORY_ENTRIES[i].label_key), i)


func _selected_category() -> int:
	var idx := category_select.selected
	if idx < 0:
		idx = 0
	return CATEGORY_ENTRIES[idx].value


func _on_category_changed(_idx: int) -> void:
	_selected_id = &""
	_rebuild_item_list()


func _rebuild_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()
	for it: ItemData in DataRegistry.get_items_by_category(_selected_category()):
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _button_group
		b.text = tr("SHOP_ITEM_FMT") % [tr(it.display_name), FormatUtils.short(it.price)]
		b.set_meta("item_id", it.id)
		b.pressed.connect(_on_item_selected.bind(it.id))
		item_list.add_child(b)
	_refresh_buttons(0)
	_refresh_detail()


func _on_item_selected(id: StringName) -> void:
	_selected_id = id
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_id == &"":
		detail_name.text = ""
		detail_desc.text = tr("SHOP_DETAIL_NONE")
		detail_meta.text = ""
		detail_gate.text = ""
		buy_button.disabled = true
		buy_button.text = tr("SHOP_BUY_BUTTON")
		_set_qty_buttons_enabled(false)
		return
	var it := DataRegistry.get_item(_selected_id)
	if it == null:
		_selected_id = &""
		_refresh_detail()
		return
	detail_name.text = tr(it.display_name)
	detail_desc.text = tr(it.description)
	detail_meta.text = tr("SHOP_DETAIL_PRICE_FMT") % FormatUtils.short(it.price)
	if it.trust_gate_min > 0:
		detail_gate.text = tr("SHOP_DETAIL_GATE_FMT") % it.trust_gate_min
	else:
		detail_gate.text = ""
	# 数量セレクタは消耗品のみ有効
	_set_qty_buttons_enabled(it.is_consumable)
	var qty := _resolve_qty()
	buy_button.disabled = qty <= 0 or not ShopService.can_buy(_selected_id, qty)
	if it.is_consumable and qty > 1:
		buy_button.text = tr("SHOP_BUY_BUTTON_QTY_FMT") % [qty, FormatUtils.short(it.price * qty)]
	else:
		buy_button.text = tr("SHOP_BUY_BUTTON")


# 現在の _qty_mode に対応する実購入数を返す。Max モードは選択中アイテムの所持金上限を引く。
func _resolve_qty() -> int:
	if _selected_id == &"":
		return 0
	match _qty_mode:
		0:
			return 1
		1:
			return 10
		2:
			return 100
		3:
			return ShopService.max_affordable(_selected_id)
		_:
			return 1


func _set_qty_buttons_enabled(enabled: bool) -> void:
	qty_btn_1.disabled = not enabled
	qty_btn_10.disabled = not enabled
	qty_btn_100.disabled = not enabled
	qty_btn_max.disabled = not enabled
	if not enabled:
		_qty_mode = 0
		qty_btn_1.set_pressed_no_signal(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_populate_categories()
		_rebuild_item_list()


func _refresh_buttons(_v: int = 0) -> void:
	# 行ボタンは「選択（=詳細表示）」専用なので disabled にしない。
	# 通貨が変動したら BuyButton の表示も全部 _refresh_detail で更新する
	# （Max モード時の数量と金額が変わるので）。
	if _selected_id != &"":
		_refresh_detail()


func _on_buy_pressed() -> void:
	if _selected_id == &"":
		return
	var qty := _resolve_qty()
	if qty <= 0:
		return
	ShopService.buy(_selected_id, qty)


func _on_item_purchased(_id: StringName) -> void:
	_refresh_buttons()
	_refresh_detail()
