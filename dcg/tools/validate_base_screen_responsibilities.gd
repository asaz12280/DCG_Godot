extends SceneTree

const BASE_SCREEN_SCRIPT := "res://scripts/base/base_screen.gd"
const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const BASE_FLOW_VALIDATOR := "res://tools/validate_base_flow.gd"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_base_screen_boundaries()
	_validate_base_scene_boundaries()
	_validate_helper_scripts_exist()
	if _errors.is_empty():
		print("[base_screen_responsibilities] OK display=view_model stash=helper actions=helper base3d=separate")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_base_screen_boundaries() -> void:
	var source := FileAccess.get_file_as_string(BASE_SCREEN_SCRIPT)
	_expect_contains(source, "BaseScreenViewModelScript", "BaseScreen should delegate display text and quest view logic to BaseScreenViewModel.")
	_expect_contains(source, "BaseScreenStashRowsScript", "BaseScreen should delegate dynamic stash rows to BaseScreenStashRows.")
	_expect_contains(source, "BaseScreenActionsScript", "BaseScreen should delegate base actions to BaseScreenActions.")
	if source.contains("StashVendorScript"):
		_errors.append("BaseScreen should not directly depend on StashVendorScript after action extraction.")
	if source.contains("res://scenes/base/base_3d.tscn"):
		_errors.append("BaseScreen should not own the 3D Base scene flow.")
	if not source.contains("GAMEPLAY_SCENE"):
		_errors.append("BaseScreen should still expose the legacy Start Raid action until the 3D Base panel split is complete.")


func _validate_base_scene_boundaries() -> void:
	var scene_text := FileAccess.get_file_as_string(BASE_3D_SCENE)
	if scene_text.contains("base_screen.tscn"):
		_errors.append("Base3D should not embed the old full BaseScreen as the whole Base scene.")
	_expect_contains(scene_text, "BaseInteractionController3D", "Base3D should route player interaction through a Base interaction controller.")
	_expect_contains(scene_text, "BaseInteractionPanel", "Base3D should use a node-first interaction panel for station feedback.")
	var flow_text := FileAccess.get_file_as_string(BASE_FLOW_VALIDATOR)
	_expect_contains(flow_text, "res://scenes/base/base_3d.tscn", "Base flow validation should target the 3D Base scene.")


func _validate_helper_scripts_exist() -> void:
	for path in [
		"res://scripts/base/base_screen_view_model.gd",
		"res://scripts/base/base_screen_stash_rows.gd",
		"res://scripts/base/base_screen_actions.gd",
	]:
		if not FileAccess.file_exists(path):
			_errors.append("Missing BaseScreen responsibility helper: %s" % path)


func _expect_contains(source: String, needle: String, message: String) -> void:
	if not source.contains(needle):
		_errors.append(message)
