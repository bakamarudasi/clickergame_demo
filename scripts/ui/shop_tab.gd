extends Control

# Shopタブ。アイテム購入のみを担当。
# 他タブを直接参照しない。ShopService 経由でのみ購入処理を行う。

@onready var category_select: OptionButton = %CategorySelect
@onready var item_list: VBoxContainer = %ItemList

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


func _ready() -> void:
	EventBus.currency_changed.connect(_refresh_buttons)
	EventBus.item_purchased.connect(_on_item_purchased)
	category_select.item_selected.connect(_on_category_changed)
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
	_rebuild_item_list()


func _rebuild_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()
	for it: ItemData in DataRegistry.get_items_by_category(_selected_category()):
		var b := Button.new()
		b.text = tr("SHOP_ITEM_FMT") % [tr(it.display_name), it.price]
		b.set_meta("item_id", it.id)
		b.pressed.connect(ShopService.buy.bind(it.id))
		item_list.add_child(b)
	_refresh_buttons(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_populate_categories()
		_rebuild_item_list()


func _refresh_buttons(_v: int = 0) -> void:
	for child in item_list.get_children():
		if child is Button:
			var id: StringName = child.get_meta("item_id")
			child.disabled = not ShopService.can_buy(id)


func _on_item_purchased(_id: StringName) -> void:
	_refresh_buttons()
