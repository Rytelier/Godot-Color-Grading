@tool
extends R_BaseCompositorEffect
## Enhance values of details and entire screen
class_name LocalContrast


## Enhance contrast in details
@export_range(0, 1, 0.01, "or_greater") var detail: float = 0.5:
	set(v):
		detail = v; update_push_constant()
## Soft contrast enhancement on entire screen
@export_range(0, 1, 0.01, "or_greater") var large: float = 1.0:
	set(v):
		large = v; update_push_constant()
## Range of detail contrast
@export var detail_gamma: float = 1.0:
	set(v):
		detail_gamma = v; update_push_constant()
## Range of soft contrast
@export var large_gamma: float = 0.416:
	set(v):
		large_gamma = v; update_push_constant()
## Blur radius for detail contrast
@export_range(0, 4) var detail_radius: int = 4:
	set(v):
		detail_radius = v; update_push_constant()
## Blur radius for soft contrast
@export_range(4, 6) var large_radius: int = 6:
	set(v):
		large_radius = v; update_push_constant()
## Affect bright areas of local contrast
@export var blend_bright: float = 1.0:
	set(v):
		blend_bright = v; update_push_constant()


const shader_path_downscale = "uid://bugiufvjpg41u"
var shader_downscale: RID
var pipeline_downscale: RID

const shader_path_contrast = "uid://ba361s5swhgbr"
var shader_contrast: RID
var pipeline_contrast: RID


var contrast_textures: Array[RID]
var push_constant: PackedByteArray


func _initialize_resource() -> void:
	pass


func _validate_property(property: Dictionary) -> void:
	# Hide properties
	if property.name == "needs_motion_vectors":
		property.usage = 0
	if property.name == "needs_normal_roughness":
		property.usage = 0
	if property.name == "effect_callback_type":
		property.usage = 0


func _initialize_render() -> void:
	shader_downscale = create_shader(shader_path_downscale)
	pipeline_downscale = create_pipeline(shader_downscale)
	
	shader_contrast = create_shader(shader_path_contrast)
	pipeline_contrast = create_pipeline(shader_contrast)
	
	update_push_constant()


func _render_setup() -> void:
	pass


func _render_view(view : int) -> void:
	set_workgroups_resolution(16, render_size_downscaled(1))
	
	run_compute_shader("Local contrast downscale", shader_downscale, pipeline_downscale,
		[[
			get_image_uniform(contrast_textures[0], 0),
			get_color_sampler_uniform(view, linear_sampler, 1)
		]],
		[])
	for i: int in large_radius:
		set_workgroups_resolution(16, render_size_downscaled(i+2))
		
		run_compute_shader("Local contrast downscale", shader_downscale, pipeline_downscale,
			[[
				get_image_uniform(contrast_textures[i+1], 0),
				get_sampler_uniform(contrast_textures[i], linear_sampler, 1),
			]],
			[])
	
	set_workgroups(8)
	
	run_compute_shader("Local contrast", shader_contrast, pipeline_contrast,
		[[
			get_color_image_uniform(view, 0),
			get_sampler_uniform(contrast_textures[detail_radius], linear_sampler, 1),
			get_sampler_uniform(contrast_textures[large_radius], linear_sampler, 2),
		]],
		push_constant)


func _render_size_changed() -> void:
	update_push_constant()
	
	setup_contrast_buffers()


func update_push_constant() -> void:
	push_constant = create_push_constant([Vector2(render_size), 
			Vector2(detail * 0.25, large), 
			Vector4(detail_gamma, large_gamma, blend_bright, 0)])


func setup_contrast_buffers() -> void:
	for t in contrast_textures: 
		if t.is_valid():
			free_rid(t)
	
	contrast_textures.clear()
	
	var x = render_size.x
	var y = render_size.y
	for i in 7:
		x = maxi(1, x >> 1)
		y = maxi(1, y >> 1)
		
		var texture := create_texture(Vector2i(x, y))
		contrast_textures.push_back(texture)
