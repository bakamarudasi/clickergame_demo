@tool
extends EditorPlugin

# プラグインの役割は autoload を 1 つ登録するだけ。
# 本体は debug_hud.gd（CanvasLayer）が main_scene の上にぶら下がって動く。

const AUTOLOAD_NAME := "DebugHUD"
const AUTOLOAD_PATH := "res://addons/runtime_debug_hud/debug_hud.gd"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
