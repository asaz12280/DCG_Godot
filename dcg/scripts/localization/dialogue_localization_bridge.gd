extends Node

const DMConstants := preload("res://addons/dialogue_manager/constants.gd")


func _ready() -> void:
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_warning("DialogueManager autoload is unavailable; dialogue localization was not configured.")
		return
	dialogue_manager.set("translation_source", DMConstants.TranslationSource.CSV)
