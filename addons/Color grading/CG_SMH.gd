@tool
extends Control
class_name CG_SMH


@onready var hue: EditorSpinSlider = $"Hue/SpinBox"
@onready var hue_slider: HSlider = $"Hue/Slider"

@onready var tint: EditorSpinSlider = $"Tint/SpinBox"
@onready var tint_slider: HSlider = $"Tint/Slider"

@onready var vibrance: EditorSpinSlider = $"BoxContainer/Vibrance"
@onready var lightness: EditorSpinSlider = $"BoxContainer/Lightness"


var moving_cursor: bool
var s_value: float
var h_value: float


signal changed


func _ready() -> void:
	lightness.value_changed.connect(changed.emit.unbind(1))
	vibrance.value_changed.connect(changed.emit.unbind(1))
	
	hue.value_changed.connect(changed.emit.unbind(1))
	hue.value_changed.connect(hue_slider.set_value_no_signal.bind())
	hue_slider.value_changed.connect(changed.emit.unbind(1))
	hue_slider.value_changed.connect(hue.set_value_no_signal.bind())
	hue.value_changed.connect(tint_slider_mod.bind())
	hue_slider.value_changed.connect(tint_slider_mod.bind())
	
	tint.value_changed.connect(changed.emit.unbind(1))
	tint.value_changed.connect(tint_slider.set_value_no_signal.bind())
	tint_slider.value_changed.connect(changed.emit.unbind(1))
	tint_slider.value_changed.connect(tint.set_value_no_signal.bind())


func tint_slider_mod(v: float) -> void:
	tint_slider.self_modulate = Color.from_ok_hsl(v, 1.0, 0.5)
