@tool
extends EditorPlugin

## Packages the local-notification AAR into the Android gradle export.
## Desktop and editor runs never load the Java singleton.

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


	## Godot writes this into src/debug and src/release AndroidManifest.xml, which
	## is the app manifest (xmlns:tools is already on that file). tools:node="remove"
	## drops these two permissions after the ads and billing libraries merge them in.
	## AD_ID is left in place. None of ads, billing, or streak_reminder call startForeground.
	##
	## The portrait lock (screenOrientation) makes Google Play assume the app
	## requires android.hardware.screen.portrait, which hides it from landscape
	## devices (desktops, Play Games on PC, XR). Declaring the feature as not
	## required keeps the lock and removes that assumption.
	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return """<uses-permission android:name="android.permission.READ_BASIC_PHONE_STATE" tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" tools:node="remove" />
<uses-feature android:name="android.hardware.screen.portrait" android:required="false" />"""


	func _get_name() -> String:
		return "StreakReminder"
