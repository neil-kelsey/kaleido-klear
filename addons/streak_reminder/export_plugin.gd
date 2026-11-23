@tool
extends EditorPlugin

## Packages the local-notification AAR into the Android gradle export.
## Desktop and editor runs never load the Java singleton.
## Only adds the AAR — no extra gradle or manifest edits, so AdMob stays as-is.

var _export: AndroidExportPlugin


func _enter_tree() -> void:
	_export = AndroidExportPlugin.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
	_export = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/streak_reminder/StreakReminder.release.aar"])


	func _get_name() -> String:
		return "StreakReminder"
