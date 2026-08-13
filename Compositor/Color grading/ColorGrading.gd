@tool
extends R_BaseCompositorEffect
## Adjust shadows, midtones and highlights.
## Tint, vibrance, brightness, curves, darkness perception
class_name ColorGrading


const shader_path = "uid://5cmeuha346mk"
var shader: RID
var pipeline: RID
var push_constant: PackedByteArray

const shader_path_downscale = "uid://bugiufvjpg41u"
var shader_downscale: RID
var pipeline_downscale: RID

const shader_path_contrast = "uid://ba361s5swhgbr"
var shader_contrast: RID
var pipeline_contrast: RID


## Color tint, vibrance and brightness for shadows
@export var shadows: Vector4 = Vector4(0,0,1,1):
	set(v):
		shadows = v; update_push_constant()
## Color tint, vibrance and brightness for midtones
@export var midtones: Vector4 = Vector4(0,0,1,1):
	set(v):
		midtones = v; update_push_constant()
## Color tint, vibrance and brightness for highlights
@export var highlights: Vector4 = Vector4(0,0,1,1):
	set(v):
		highlights = v; update_push_constant()

## Defines ranges of shadows, midtones and highlights
@export var sh_ranges: Vector4 = Vector4(0, 0.2, 0.7, 1.0):
	set(v):
		sh_ranges = v; update_push_constant()

## Vibrance after color tint operations
@export var vibrance_post: Vector3 = Vector3(1,1,1):
	set(v):
		vibrance_post = v; update_push_constant()

## Brightness curves for image after previous operations
@export var curves: Texture:
	set(v):
		curves = v; update_texture()


@export_group("Night color")
## Simulates perception of colors in darkness
@export var night_color: float:
	set(v):
		night_color = v; update_push_constant()
## Noise visible in darkness
@export var night_noise: float = 0.5:
	set(v):
		night_noise = v; update_push_constant()
## Delay of noise animation
@export var night_noise_lag: int = 7


var night_frame: int:
	get:
		return snappedi(Engine.get_frames_drawn() % 256, night_noise_lag)

var curve_texture: RID

var contrast_textures: Array[RID]


func _initialize_resource() -> void:
	if !curves:
		var c: CurveTexture = CurveTexture.new()
		c.curve = Curve.new()
		c.curve.add_point(Vector2(0, 0.5))
		c.curve.add_point(Vector2(0.25, 0.5))
		c.curve.add_point(Vector2(0.5, 0.5))
		c.curve.add_point(Vector2(0.75, 0.5))
		c.curve.add_point(Vector2(1.0, 0.5))
		curves = c


func _validate_property(property: Dictionary) -> void:
	# Hide properties
	if property.name == "needs_motion_vectors":
		property.usage = 0
	if property.name == "needs_normal_roughness":
		property.usage = 0
	if property.name == "effect_callback_type":
		property.usage = 0


func _initialize_render() -> void:
	shader = create_shader(shader_path)
	pipeline = create_pipeline(shader)
	
	shader_downscale = create_shader(shader_path_downscale)
	pipeline_downscale = create_pipeline(shader_downscale)
	
	shader_contrast = create_shader(shader_path_contrast)
	pipeline_contrast = create_pipeline(shader_contrast)
	
	update_push_constant()


func _render_setup() -> void:
	pass


func _render_view(view : int) -> void:
	set_workgroups(8)
	
	if night_color > 0 and night_noise > 0:
		push_constant.encode_float(24, night_frame) # night.z
	
	if !rd.texture_is_valid(curve_texture):
		update_texture()
	
	run_compute_shader("Color grading", shader, pipeline,
		[[
			get_color_image_uniform(view, 0),
			get_sampler_uniform(curve_texture, linear_sampler, 1),
		]],
		push_constant)


func _render_size_changed() -> void:
	update_push_constant()


func update_texture() -> void:
	if curves:
		curve_texture = RenderingServer.texture_get_rd_texture(curves.get_rid())


const scale: float = 2.13 # Correct lightness to look same as before grading

func update_push_constant() -> void:
	# SMH parameter values:
	# x - hue, y - tint amount, z - vibrance, w - lightness
	
	var s: Color = Color.from_ok_hsl(shadows.x, shadows.y, 0.5)
	s *= shadows.w * scale
	var m: Color = Color.from_ok_hsl(midtones.x, midtones.y, 0.5)
	m *= midtones.w * scale
	var h: Color = Color.from_ok_hsl(highlights.x, highlights.y, 0.5)
	h *= highlights.w * scale
	
	push_constant = create_push_constant([
		Vector2(render_size),
		Vector2(0, 0),
		Vector4(night_color, night_noise * night_color, night_frame, 0),
		Vector4(s.r, s.g, s.b, shadows.z),
		Vector4(m.r, m.g, m.b, midtones.z),
		Vector4(h.r, h.g, h.b, highlights.z),
		Vector4(sh_ranges.x, sh_ranges.y, sh_ranges.z, sh_ranges.w),
		Vector4(vibrance_post.x, vibrance_post.y, vibrance_post.z, 0),
	])
