class_name CsvDataTableLoader
extends RefCounted


static func load_records(path: String) -> Array[Dictionary]:
	if ResourceLoader.exists(path):
		var imported := load(path)
		if imported != null:
			var records: Variant = imported.get("records")
			if records is Array and ((records as Array).is_empty() or (records as Array)[0] is Dictionary):
				return _duplicate_dictionary_records(records as Array)
	return _read_csv_with_headers(path)


static func _read_csv_with_headers(path: String) -> Array[Dictionary]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var header := file.get_csv_line()
	var records: Array[Dictionary] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or _row_is_blank(row):
			continue
		var record: Dictionary = {}
		for column in range(header.size()):
			var key := str(header[column]).strip_edges()
			if key == "":
				continue
			var raw_value := str(row[column]).strip_edges() if column < row.size() else ""
			record[key] = _detect_value(raw_value)
		records.append(record)
	return records


static func _detect_value(value: String) -> Variant:
	if value.nocasecmp_to("true") == 0:
		return true
	if value.nocasecmp_to("false") == 0:
		return false
	if value.is_valid_int():
		return int(value)
	if value.is_valid_float():
		return float(value)
	return value


static func _duplicate_dictionary_records(source: Array) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record in source:
		if record is Dictionary:
			records.append((record as Dictionary).duplicate(true))
	return records


static func _row_is_blank(row: PackedStringArray) -> bool:
	for value in row:
		if str(value).strip_edges() != "":
			return false
	return true
