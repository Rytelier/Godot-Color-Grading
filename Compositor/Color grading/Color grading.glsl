#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D curves_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 _;
	vec4 night;
	vec4 shadows;
	vec4 midtones;
	vec4 highlights;
	vec4 ranges_sh_hi;
	vec4 vibrance_post;
} params;


/// sRGB ///
const vec3 linear_to_luma = vec3(0.299, 0.587, 0.114);


///--- Color spaces ---///

/// rec2020 ///
const mat3 XYZ_to_RGB = mat3
(
	 vec3( 3.1338561, -1.6168667, -0.4906146),
	 vec3(-0.9787684, +1.9161415, +0.0334540),
	 vec3( 0.0719453, -0.2289914, +1.4052427)
);

const mat3 RGB_to_XYZ = mat3
(
	 vec3(0.4360747, +0.3850649, +0.1430804),
	 vec3(0.2225045, +0.7168786, +0.0606169),
	 vec3(0.0139322, +0.0971045, +0.7141733)
);


const mat3 linear_to_bestRGB = mat3
(
	0.6318944 , 0.20538793, 0.12701335,
	0.22760177, 0.73839465, 0.03400357,
	0.        , 0.01001892, 0.81508568
);

const mat3 bestRGB_to_linear = mat3
(
	1.75737181, -0.48538023, -0.25359913,
	-0.54199672,  1.50475404,  0.02168337,
	0.00666215, -0.01849623,  1.22659836
);


/// OKLAB ///
vec3 oklab_to_linear(vec3 oklab)
{
    const mat3 m1 = mat3(+1.000000000, +1.000000000, +1.000000000,
                         +0.396337777, -0.105561346, -0.089484178,
                         +0.215803757, -0.063854173, -1.291485548);
                       
    const mat3 m2 = mat3(+4.076724529, -1.268143773, -0.004111989,
                         -3.307216883, +2.609332323, -0.703476310,
                         +0.230759054, -0.341134429, +1.706862569);
    vec3 lms = m1 * oklab;
    
    return m2 * (lms * lms * lms);
}

vec3 linear_to_oklab(vec3 linear)
{
    const mat3 im1 = mat3(0.4121656120, 0.2118591070, 0.0883097947,
                          0.5362752080, 0.6807189584, 0.2818474174,
                          0.0514575653, 0.1074065790, 0.6302613616);
                       
    const mat3 im2 = mat3(+0.2104542553, +1.9779984951, +0.0259040371,
                          +0.7936177850, -2.4285922050, +0.7827717662,
                          -0.0040720468, +0.4505937099, -0.8086757660);
                       
    vec3 lms = im1 * linear;
            
    return im2 * (sign(lms) * pow(abs(lms), vec3(1.0/3.0)));
}

/// Night ///
// https://www.shadertoy.com/view/dsccRj
float wavelength_to_scotopic(float lambda)
{
    float t = lambda-507.0;
    t *= mix(0.01650, 0.01919, step(0.0, t));
    return exp(-t * t);
}


float xyz_to_scotopic(vec3 xyz) 
{
	return max(0.0, dot(xyz, vec3(-0.80498,1.18214,0.36169)));
}

vec3 night_filter(vec3 color)
{
    vec3 xyz = color * RGB_to_XYZ;
    float v = xyz_to_scotopic(xyz);
    vec3 night = vec3(0.375, 0.75, 1.0);
    color = v * night;

    return color;
}

/// General ///
uvec3 murmurHash32(uvec2 src) {
	const uint M = 0x5bd1e995u;
	uvec3 h = uvec3(1190494759u, 2147483647u, 3559788179u);
	src *= M; src ^= src>>24u; src *= M;
	h *= M; h ^= src.x; h *= M; h ^= src.y;
	h ^= h>>13u; h *= M; h ^= h>>15u;
	return h;
}

vec3 hash32(vec2 src) {
	uvec3 h = murmurHash32(floatBitsToUint(src));
	return uintBitsToFloat(h & 0x007fffffu | 0x3f800000u) - 1.0;
}

/// Conversion default ///
#define color_convert_to(x) x * linear_to_bestRGB
#define color_convert_from(x) x * bestRGB_to_linear


/// Grade ///
void main() 
{
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (coord.x >= size.x || coord.y >= size.y) {
		return;
	}

	vec4 image = imageLoad(color_image, coord);
	vec3 color = image.rgb;

	float luma = dot(color, linear_to_luma);

	///--- SMH ---///

	// SHM ranges
	float luma_r = pow(luma, 1./1.6);
	vec3 range_values = vec3(
		1. - smoothstep(params.ranges_sh_hi.x, params.ranges_sh_hi.y, luma_r), // Shadows
		0.,
		smoothstep(params.ranges_sh_hi.z, params.ranges_sh_hi.w, luma_r) // Highlights
	);
	range_values.y = 1. - (range_values.x + range_values.z); // Midtones
	
	float vib_fac = 
//		params.shadows.w * range_values.x + 
//		params.midtones.w * range_values.y + 
//		params.highlights.w * range_values.z;
	(fma(params.shadows.w, range_values.x, 
	fma(params.midtones.w, range_values.y, 
	params.highlights.w * range_values.z)));

	///--- Vibrance pre-tint ---///

	float max_c = max(max(color.r, color.g), color.b);
	float min_c = min(min(color.r, color.g), color.b);
	float range = max_c - min_c;

	vec3 color_tmp = color;

	// OKLAB
	color = linear_to_oklab(color);

	float l = length(color.yz);
	vec2 vib = color.yz * (vib_fac-1.0) * (1.0-l);

	color.yz += vib;

	// Linear
	color = oklab_to_linear(color);

	// Vibrance fix
	color = mix(color_tmp, color, clamp(1.0 - range, 0, 1));
	color = mix(vec3(luma), color, vec3(clamp(vib_fac, 0, 1)));


	///--- Night color ---///

	color = mix(color, night_filter(color), range_values.x * params.night.x);

	
	if(params.night.y > 0)
	{
		vec3 noise = hash32(vec2(coord) + params.night.z * 100.) - 0.5;
		color += noise * range_values.x * params.night.y * 0.01;
	}

	///--- Tint and lightness ---///

	color = color_convert_to(color);

	vec3 tint = 
		params.shadows.rgb * range_values.x + 
		params.midtones.rgb * range_values.y + 
		params.highlights.rgb * range_values.z;

	color *= tint;

	color = color_convert_from(color);

	///--- After SMH ---///
	///--- Vibrance post tint ---///

	vib_fac = 
//		params.vibrance_post.x * range_values.x + 
//		params.vibrance_post.y * range_values.y + 
//		params.vibrance_post.z * range_values.z;
	(fma(params.vibrance_post.x, range_values.x, 
	fma(params.vibrance_post.y, range_values.y, 
	params.vibrance_post.z * range_values.z)));

	max_c = max(max(color.r, color.g), color.b);
	min_c = min(min(color.r, color.g), color.b);
	range = (max_c - min_c);

	color_tmp = color;

	// OKLAB
	color = linear_to_oklab(color);

	l = length(color.yz);

	color.yz += color.yz * (vib_fac-1.0) * (1.0-l);

	color = oklab_to_linear(color);

	// Linear
	// Vibrance fix
	color = mix(color_tmp, color, clamp(1.0 - range, 0, 1));
	color = mix(vec3(luma), color, vec3(clamp(vib_fac, 0, 1)));


	///--- Curves ---///
	vec3 curves = texture(curves_texture, vec2(pow(luma, 0.416), 0.)).xyz * 2.;
	color *= curves;

	imageStore(color_image, coord, vec4(color, image.a));
}
