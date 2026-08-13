@tool
extends EditorInspectorPlugin
class_name CG_InspectorPlugin

static var ui_nodes: Control


func _can_handle(object):
	return object is ColorGrading


func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if type == TYPE_VECTOR4 and name != "sh_ranges": # SMH adjust
		add_property_editor(name, SMH.new())
		return true
	elif type == TYPE_VECTOR4: # SMH ranges
		add_property_editor(name, Ranges.new())
		return true
	elif type == TYPE_VECTOR3: # Vibrance
		add_property_editor(name, VibrancePost.new())
		return true
	else:
		return false


class SMH extends EditorProperty:
	var smh: CG_SMH = CG_InspectorPlugin.ui_nodes.get_node("SMH adjust").duplicate()
	var current_value: Vector4
	var updating: bool = false
	
	
	func _init():
		add_child(smh)
		add_focusable(smh)
		set_bottom_editor(smh)
		
		smh.changed.connect(changed)
	
	
	func changed() -> void:
		if updating:
			return
		
		current_value.x = smh.hue.value
		current_value.y = smh.tint.value
		current_value.z = smh.vibrance.value
		current_value.w = smh.lightness.value
		emit_changed(get_edited_property(), current_value)
	
	
	func _update_property():
		var new_value = get_edited_object()[get_edited_property()]
		if new_value == current_value:
			return
		
		updating = true
		current_value = new_value
		smh.lightness.set_value_no_signal(new_value.w)
		smh.vibrance.set_value_no_signal(new_value.z)
		
		smh.hue.set_value_no_signal(new_value.x)
		smh.hue_slider.set_value_no_signal(new_value.x)
		smh.tint.set_value_no_signal(new_value.y)
		smh.tint_slider.set_value_no_signal(new_value.y)
		
		smh.tint_slider_mod(smh.hue.value)
		updating = false


class VibrancePost extends EditorProperty:
	var box: BoxContainer = CG_InspectorPlugin.ui_nodes.get_node("Vibrance post").duplicate()
	var values: Array[EditorSpinSlider]
	var current_value: Vector3
	var updating: bool
	
	
	func _init() -> void:
		add_child(box)
		add_focusable(box)
		set_bottom_editor(box)
		
		var idx: int = 0
		for c in box.get_children():
			if c is EditorSpinSlider:
				c.value_changed.connect(changed.bind(idx))
				values.append(c)
				idx += 1
	
	
	func changed(value, idx) -> void: 
		if updating:
			return
		
		current_value[idx] = value
		emit_changed(get_edited_property(), current_value)
	
	
	func _update_property():
		var new_value = get_edited_object()[get_edited_property()]
		if new_value == current_value:
			return
		
		updating = true
		current_value = new_value
		values[0].value = new_value.x
		values[1].value = new_value.y
		values[2].value = new_value.z
		updating = false


class Ranges extends EditorProperty:
	var smh: CG_RangesEditor = CG_InspectorPlugin.ui_nodes.get_node("SMH ranges").duplicate()
	var current_value: Vector4
	var updating: bool = false
	
	
	func _init():
		add_child(smh)
		add_focusable(smh)
		set_bottom_editor(smh)
		
		smh.changed.connect(changed)
	
	
	func changed() -> void:
		if updating:
			return
		
		current_value.x = smh.value_boxes[0].value
		current_value.y = smh.value_boxes[1].value
		current_value.z = smh.value_boxes[2].value
		current_value.w = smh.value_boxes[3].value
		emit_changed(get_edited_property(), current_value)
	
	
	func _update_property():
		var new_value = get_edited_object()[get_edited_property()]
		if new_value == current_value:
			return
		
		updating = true
		current_value = new_value
		smh.value_boxes[0].set_value_no_signal(new_value.x)
		smh.value_boxes[1].set_value_no_signal(new_value.y)
		smh.value_boxes[2].set_value_no_signal(new_value.z)
		smh.value_boxes[3].set_value_no_signal(new_value.w)
		smh.sync_sliders.call_deferred()
		updating = false
