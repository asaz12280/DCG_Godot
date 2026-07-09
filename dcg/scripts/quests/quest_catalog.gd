class_name QuestCatalog
extends RefCounted

const FIRST_SALVAGE_QUEST := preload("res://data/quests/first_salvage.tres")
const FIRST_SCAVENGER_HUNT_QUEST := preload("res://data/quests/first_scavenger_hunt.tres")
const RADIO_TOWER_SCOUT_QUEST := preload("res://data/quests/radio_tower_scout.tres")


static func first_salvage_quest() -> Resource:
	return FIRST_SALVAGE_QUEST


static func first_scavenger_hunt_quest() -> Resource:
	return FIRST_SCAVENGER_HUNT_QUEST


static func radio_tower_scout_quest() -> Resource:
	return RADIO_TOWER_SCOUT_QUEST


static func quest_defs() -> Array[Resource]:
	return [FIRST_SALVAGE_QUEST, FIRST_SCAVENGER_HUNT_QUEST, RADIO_TOWER_SCOUT_QUEST]
