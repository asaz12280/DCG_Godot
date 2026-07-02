class_name BaseScreenActions
extends RefCounted

const StashVendorScript := preload("res://scripts/base/stash_vendor.gd")


static func sell_all_junk(stash_data: Array, starting_money: int = 0) -> Dictionary:
	return StashVendorScript.sell_all_junk(stash_data, starting_money)


static func get_sellable_value(stash_data: Array) -> int:
	return StashVendorScript.get_sellable_value(stash_data)
