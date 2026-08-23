extends RefCounted
class_name LocalePoStore

## Reads and writes gettext .po files used by the project, then refreshes
## TranslationServer so the running game picks up the new copy.

const PO_PATHS := {
	"en": "res://locales/en.po",
	"fr": "res://locales/fr.po",
	"pirate": "res://locales/pirate.po",
}


static func locale_codes() -> PackedStringArray:
	return PackedStringArray(PO_PATHS.keys())


static func read_msgstr(locale_code: String, msgid: String) -> String:
	var translation := TranslationServer.get_translation_object(locale_code)
	if translation != null:
		var live := str(translation.get_message(msgid))
		if not live.is_empty() and live != msgid:
			return live
	var text := _read_text(_path_for(locale_code))
	if text.is_empty():
		return ""
	return _find_msgstr(text, msgid)


static func write_msgstrs(msgid: String, by_locale: Dictionary) -> Error:
	if msgid.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var last_err := OK
	for locale_code in PO_PATHS.keys():
		var value := str(by_locale.get(locale_code, "")).strip_edges()
		if value.is_empty():
			value = str(by_locale.get("en", "")).strip_edges()
		var err := _write_one(str(locale_code), msgid, value)
		if err != OK:
			last_err = err
		_apply_live(str(locale_code), msgid, value)
	return last_err


static func _path_for(locale_code: String) -> String:
	return str(PO_PATHS.get(locale_code, ""))


static func _write_one(locale_code: String, msgid: String, msgstr: String) -> Error:
	var path := _path_for(locale_code)
	if path.is_empty():
		return ERR_FILE_NOT_FOUND
	var text := _read_text(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var updated := _upsert_entry(text, msgid, msgstr)
	var abs_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(updated)
	file.close()
	return OK


static func _apply_live(locale_code: String, msgid: String, msgstr: String) -> void:
	var translation := TranslationServer.get_translation_object(locale_code)
	if translation != null:
		translation.add_message(msgid, msgstr)


static func _read_text(path: String) -> String:
	if path.is_empty():
		return ""
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			return file.get_as_text()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var abs_file := FileAccess.open(abs_path, FileAccess.READ)
		if abs_file != null:
			return abs_file.get_as_text()
	return ""


static func _find_msgstr(text: String, msgid: String) -> String:
	var needle := "msgid \"%s\"" % _escape(msgid)
	var at := text.find(needle)
	if at < 0:
		return ""
	var rest := text.substr(at + needle.length())
	var msg_at := rest.find("msgstr \"")
	if msg_at < 0:
		return ""
	var start := msg_at + "msgstr \"".length()
	var end := rest.find("\"", start)
	if end < 0:
		return ""
	return _unescape(rest.substr(start, end - start))


static func _upsert_entry(text: String, msgid: String, msgstr: String) -> String:
	var needle := "msgid \"%s\"" % _escape(msgid)
	var at := text.find(needle)
	var line := "msgid \"%s\"\nmsgstr \"%s\"\n" % [_escape(msgid), _escape(msgstr)]
	if at < 0:
		var body := text
		if not body.ends_with("\n"):
			body += "\n"
		return body + "\n" + line
	var after := at + needle.length()
	var msg_at := text.find("msgstr \"", after)
	if msg_at < 0 or msg_at > at + 80:
		return text
	var value_start := msg_at + "msgstr \"".length()
	var value_end := text.find("\"", value_start)
	if value_end < 0:
		return text
	return text.substr(0, value_start) + _escape(msgstr) + text.substr(value_end)


static func _escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")


static func _unescape(value: String) -> String:
	return value.replace("\\n", "\n").replace("\\\"", "\"").replace("\\\\", "\\")
