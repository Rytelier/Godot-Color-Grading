#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D texture_blur_small;
layout(set = 0, binding = 2) uniform sampler2D texture_blur_large;


layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 strength;
	vec4 gamma;
} params;


const vec3 linear_to_luma = vec3(0.299, 0.587, 0.114);


// from http://www.java-gaming.org/index.php?topic=35123.0
vec4 cubic(float v){
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}


vec4 textureBicubic(sampler2D tex, vec2 texCoords){
	vec2 texSize = vec2(textureSize(tex, 0));
	vec2 invTexSize = 1.0 / texSize;

	texCoords = texCoords * texSize - 0.5;

	vec2 fxy = fract(texCoords);
	texCoords -= fxy;

	vec4 xcubic = cubic(fxy.x);
	vec4 ycubic = cubic(fxy.y);

	vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;

	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;

	offset *= invTexSize.xxyy;

	vec4 sample0 = texture(tex, offset.xz);
	vec4 sample1 = texture(tex, offset.yz);
	vec4 sample2 = texture(tex, offset.xw);
	vec4 sample3 = texture(tex, offset.yw);

	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);

	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}


void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (coord.x >= size.x || coord.y >= size.y) {
		return;
	}

	vec2 uv = (vec2(coord) + 0.5) / size;

	vec4 color = imageLoad(color_image, coord);

	vec4 small = textureBicubic(texture_blur_small, uv);
	vec4 large = textureBicubic(texture_blur_large, uv);

	float luma = dot(min(color.rgb, 1.0), linear_to_luma);
	float luma_small = dot(small.rgb, linear_to_luma);
	float luma_large = dot(large.rgb, linear_to_luma);

	luma_large = pow(max(luma_large, 0.0001), params.gamma.y);
	luma_large = mix(luma_large, 0.5, smoothstep(params.gamma.z - 0.2, params.gamma.z, luma_large));

	float diff_s = (luma + 0.001) / (luma_small + 0.001);
	diff_s = pow(diff_s, params.gamma.x);
	diff_s = min(diff_s, 1.0);

	color.rgb *= mix(1, diff_s, params.strength.x);
	color.rgb *= mix(1, luma_large + 0.5, params.strength.y);

	imageStore(color_image, coord, color);
	//imageStore(color_image, coord, vec4(vec3(luma_large), 1.));
}
