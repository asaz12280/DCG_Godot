class_name ResourceReferenceIndex
extends RefCounted

const CsvDataTableLoaderScript := preload("res://scripts/data/csv_data_table_loader.gd")
const DEFAULT_PATH := "res://data/reference/resource_reference_index.csv"
const REQUIRED_COLUMNS := [
	"id",
	"category",
	"reference_source",
	"reference_name",
	"dcg_target",
	"use",
	"notes",
	"status",
]
const ALLOWED_STATUSES := [
	"active",
	"planned",
	"placeholder",
	"implemented",
	"rejected",
]


static func load_entries(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for row in CsvDataTableLoaderScript.load_records(path):
		var entry := (row as Dictionary).duplicate(true)
		if not entry.is_empty():
			entries.append(entry)
	return entries


static func entries_by_category(category: String, path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in load_entries(path):
		if str(entry.get("category", "")) == category:
			result.append(entry)
	return result


static func entries_by_status(status: String, path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in load_entries(path):
		if str(entry.get("status", "")) == status:
			result.append(entry)
	return result


static func find_by_id(id: String, path: String = DEFAULT_PATH) -> Dictionary:
	for entry in load_entries(path):
		if str(entry.get("id", "")) == id:
			return entry.duplicate(true)
	return {}


static func validate_entries(path: String = DEFAULT_PATH) -> Array[String]:
	var errors: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["Resource reference index CSV is missing: %s" % path]
	var header := file.get_csv_line()
	for column in REQUIRED_COLUMNS:
		if not header.has(column):
			errors.append("Resource reference index missing column: %s" % column)
	var ids := {}
	var line_number := 1
	while not file.eof_reached():
		line_number += 1
		var row := file.get_csv_line()
		if row.is_empty() or _row_is_blank(row):
			continue
		var entry := _entry_from_row(header, row)
		var id := str(entry.get("id", "")).strip_edges()
		if id == "":
			errors.append("Resource reference row %d requires id." % line_number)
		elif ids.has(id):
			errors.append("Resource reference id should be unique: %s." % id)
		else:
			ids[id] = true
		for column in REQUIRED_COLUMNS:
			if str(entry.get(column, "")).strip_edges() == "":
				errors.append("Resource reference row %d requires %s." % [line_number, column])
		var status := str(entry.get("status", "")).strip_edges()
		if status != "" and not ALLOWED_STATUSES.has(status):
			errors.append("Resource reference row %d has unsupported status: %s." % [line_number, status])
		var target := str(entry.get("dcg_target", ""))
		if target.contains("AssetRipper_export") or target.contains("\\ExportedProject\\") or target.contains("/ExportedProject/"):
			errors.append("Resource reference row %d dcg_target must not point to extracted assets." % line_number)
	return errors


static func _entry_from_row(header: PackedStringArray, row: PackedStringArray) -> Dictionary:
	var entry := {}
	for index in range(header.size()):
		var key := str(header[index]).strip_edges()
		if key == "":
			continue
		var value := str(row[index]).strip_edges() if index < row.size() else ""
		entry[key] = value
	return entry


static func _row_is_blank(row: PackedStringArray) -> bool:
	for value in row:
		if str(value).strip_edges() != "":
			return false
	return true
