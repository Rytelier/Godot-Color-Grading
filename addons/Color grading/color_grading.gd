@tool
extends EditorPlugin


var inspector: CG_InspectorPlugin


func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	inspector = CG_InspectorPlugin.new()
	add_inspector_plugin(inspector)
	CG_InspectorPlugin.ui_nodes = load("res://addons/Color grading/Resources/UI.tscn").instantiate()


func _exit_tree() -> void:
	remove_inspector_plugin(inspector)
	CG_InspectorPlugin.ui_nodes.queue_free()
