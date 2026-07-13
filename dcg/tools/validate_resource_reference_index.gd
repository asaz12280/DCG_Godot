extends SceneTree

const ResourceReferenceIndexScript := preload("res://scripts/data/resource_reference_index.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_csv_contract()
	_validate_reader()
	_validate_reference_rules()
	if _errors.is_empty():
		print("[resource_reference_index] OK csv=valid reader=works external_reference=analysis_only")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_csv_contract() -> void:
	_errors.append_array(ResourceReferenceIndexScript.validate_entries())
	var entries := ResourceReferenceIndexScript.load_entries()
	if entries.size() < 5:
		_errors.append("Resource reference index should start with representative reference planning rows.")
	var overview := ResourceReferenceIndexScript.find_by_id("duckov_meshindex_overview")
	if overview.is_empty():
		_errors.append("Resource reference index should include the Duckov MeshIndex overview row.")
	elif not str(overview.get("notes", "")).contains("Do not import"):
		_errors.append("Duckov MeshIndex overview should explicitly mark extracted assets as non-importable.")


func _validate_reader() -> void:
	var cover_entries := ResourceReferenceIndexScript.entries_by_category("cover_prop")
	if cover_entries.is_empty():
		_errors.append("ResourceReferenceIndex should filter entries by category.")
	var planned_entries := ResourceReferenceIndexScript.entries_by_status("planned")
	if planned_entries.is_empty():
		_errors.append("ResourceReferenceIndex should filter entries by status.")
	for entry in planned_entries:
		if not str(entry.get("dcg_target", "")).begins_with("dcg_original_"):
			_errors.append("Planned reference targets should describe original DCG replacement assets: %s." % entry.get("id", ""))


func _validate_reference_rules() -> void:
	var short_spec := FileAccess.get_file_as_string("res://docs/architecture/programming_spec_short.md")
	for required in ["resource_reference_index.csv", "MeshIndex_20260706.csv", "analysis only"]:
		if not short_spec.contains(required):
			_errors.append("Short programming spec should mention reference index rule: %s." % required)
	var full_spec := FileAccess.get_file_as_string("res://docs/architecture/programming_spec.md")
	for required in ["resource_reference_index.csv", "Forbidden use", "Allowed use"]:
		if not full_spec.contains(required):
			_errors.append("Full programming spec should document reference index boundary: %s." % required)
