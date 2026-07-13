class_name SoundManagerBridge
extends RefCounted

const SOUND_MANAGER_PATH := NodePath("/root/SoundManager")
const UNITY_VOLUME_DB := 0.0


static func sync_from_game_settings(context: Node, master_percent: int, bgm_percent: int, sfx_percent: int) -> Dictionary:
	var state := {
		"available": false,
		"master_percent": clampi(master_percent, 0, 100),
		"bgm_percent": clampi(bgm_percent, 0, 100),
		"sfx_percent": clampi(sfx_percent, 0, 100),
		"bgm_bus": "BGM",
		"bgs_bus": "BGM",
		"sfx_bus": "SFX",
		"mfx_bus": "SFX",
		"manager_gain_db": UNITY_VOLUME_DB,
	}
	if context == null or not context.is_inside_tree():
		return state
	var manager := context.get_node_or_null(SOUND_MANAGER_PATH)
	if manager == null:
		return state
	for method_name in [
		&"set_bgm_volume_db",
		&"set_bgs_volume_db",
		&"set_sfx_volume_db",
		&"set_mfx_volume_db",
	]:
		if not manager.has_method(method_name):
			return state
		manager.call(method_name, UNITY_VOLUME_DB)
	state["available"] = true
	return state
