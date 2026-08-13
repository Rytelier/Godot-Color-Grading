@tool
extends Control
class_name CG_RangesEditor

@onready var panel: Panel = $Panel
@onready var values: BoxContainer = $BoxContainer
@onready var visualizer: TextureRect = $Panel/Visualizer

var value_boxes: Array[EditorSpinSlider]
var value_sliders: Array[Control]
var slider_moving: int = -1

signal changed


func _ready() -> void:
	for c in values.get_children(true):
		value_boxes.append(c)
		c.value_changed.connect(sync_sliders.unbind(1))
		c.value_changed.connect(changed.emit.unbind(1))
	
	for c in visualizer.get_children(true):
		value_sliders.append(c)
	
	for i in value_sliders.size():
		value_sliders[i].gui_input.connect(move_slider.bind(i))
	
	sync_sliders_late()


func _draw() -> void:
	var points_s = sh_line_points(value_boxes[0].value, value_boxes[1].value, false)
	var points_h = sh_line_points(value_boxes[2].value, value_boxes[3].value, true)
	
	draw_polyline(points_s, Color.WHITE, 2, true)
	draw_polyline(points_h, Color.WHITE, 2, true)


func sh_line_points(from: float, to: float, flip: bool) -> PackedVector2Array:
	var points: PackedVector2Array
	var min: Vector2 = Vector2.ONE
	var max: Vector2 = Vector2.ZERO
	for i in range(1, 101):
		var p: Vector2 = sh_line_point(from, to, i/100.0, flip)
		var p2: Vector2 = sh_line_point(from, to, ((i+1)/100.0), flip)
		var p3: Vector2 = sh_line_point(from, to, ((i-1)/100.0), flip)
		if p.y >= 1 and p3.y >= 1:
			continue
		if p.y < min.y:
			min = p
		if p.y > max.y:
			max = p
		p *= visualizer.size
		p += visualizer.position + visualizer.get_parent().position
		points.append(p)
	
	return points


func sh_line_point(from: float, to: float, fac: float, flip: bool) -> Vector2:
	var sm = smoothstep(from, to, fac)
	if flip:
		sm = 1.0 - sm
	return Vector2(fac, sm)


func move_slider(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			slider_moving = idx if event.pressed else -1


func _input(event: InputEvent) -> void:
	if slider_moving != -1:
		if event is InputEventMouseMotion:
			var fac: float = (get_local_mouse_position().x - visualizer.position.x) / visualizer.size.x
			fac = round(fac * 100) / 100
			fac = clamp(fac, 0, 1)
			value_boxes[slider_moving].value = fac
			value_sliders[slider_moving].position.x = fac * visualizer.size.x
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
				slider_moving = -1


func sync_sliders() -> void:
	for s in value_sliders.size():
		value_sliders[s].position.x = value_boxes[s].value * visualizer.size.x

	queue_redraw()


func sync_sliders_late() -> void:
	await get_tree().process_frame
	
	sync_sliders()
